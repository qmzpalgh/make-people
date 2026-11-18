"""Bake MakeHuman geometry + fitting coordinates to compact Godot mesh resources.
Usage: python build_meshes.py MAKEHUMAN_DATA SYSTEM_ASSETS STAGING_DIRECTORY
Requires NumPy. Follow with godot --headless -s tools/bake.gd -- STAGING_DIRECTORY.
"""
import json
import re
import sys
import subprocess
import struct
from pathlib import Path

import numpy as np

data, assets, stage = map(Path, sys.argv[1:])
stage.mkdir(parents=True, exist_ok=True)


def obj(path, group=None):
    vertices, texcoords, faces, texfaces = [], [], [], []
    active = None
    for line in path.read_text().splitlines():
        a = line.split()
        if not a:
            continue
        if a[0] == "v":
            vertices.append([float(x) for x in a[1:4]])
        elif a[0] == "vt":
            texcoords.append([float(x) for x in a[1:3]])
        elif a[0] == "g":
            active = a[1]
        elif a[0] == "f" and (group is None or active == group):
            corners = [x.split("/") for x in a[1:]]
            faces.append([int(x[0])-1 for x in corners])
            texfaces.append([int(x[1])-1 if len(x)>1 and x[1] else 0 for x in corners])
    return np.array(vertices), np.array(texcoords or [[0,0]]), faces, texfaces


base, base_uv, body_faces, body_uv = obj(data/"3dobjs/base.obj", "body")


def target(path):
    delta = np.zeros_like(base)
    if not any(line[:1].isdigit() for line in (data/"targets"/(path+".target")).read_text().splitlines()): return delta
    rows = np.loadtxt(data/"targets"/(path+".target"), ndmin=2)
    if not rows.size: return delta
    delta[rows[:,0].astype(int)] = rows[:,1:]
    return delta


def macro(key):
    return target("macrodetails/"+key)


def average_frame(sex):
    return sum(macro(f"{region}-{sex}-young")*w for region,w in
               [("african",0.24),("asian",0.18),("caucasian",0.58)]) + macro(
                   f"universal-{sex}-young-averagemuscle-averageweight")


female = average_frame("female")
male = average_frame("male")
# Small authored expression offsets soften the neutral resting gaze.
female += target("mouth/mouth-angles-up")*.28
female += target("expression/units/caucasian/mouth-compression")*.33
# Close the neutral lip seam while preserving the vermilion outline and Cupid's bow.
x,y,z=base.T
lip_band=np.exp(-((x/.23)**4))*np.clip((z-1.30)/.14,0,1)
female[:,1]+=lip_band*np.where(y<6.607,.012*np.exp(-((y-6.59)/.075)**2),-.007*np.exp(-((y-6.63)/.065)**2))
for side in "lr":
    female -= target(f"eyes/{side}-eye-height2-incr")*.23
blink=sum(target("expression/units/caucasian/eye-"+side+"-closure") for side in ("left","right"))
female+=blink*.10
reference = base + female
shapes = {
    "blink": blink*.90,
    "frame": (male-female)*0.85,
    "weight": (macro("universal-female-young-averagemuscle-maxweight") -
               macro("universal-female-young-averagemuscle-averageweight"))*0.75,
    "muscle": (macro("universal-female-young-maxmuscle-averageweight") -
               macro("universal-female-young-averagemuscle-averageweight"))*0.8,
    "hips": target("hip/hip-scale-horiz-incr")*0.8,
    "jaw": target("chin/chin-width-incr")*0.8,
    "cheeks": sum(target(f"cheek/{s}-cheek-bones-incr") for s in "lr")*0.8,
    "nose": target("nose/nose-scale-horiz-incr")*0.85,
    "lips": target("mouth/mouth-scale-horiz-incr")*0.8,
    "eyes": sum(target(f"eyes/{s}-eye-height2-incr") for s in "lr")*0.65,
}
ground = reference[np.unique([i for f in body_faces for i in f]),1].min()
def smoothstep(low, high, values):
    t=np.clip((values-low)/(high-low),0,1)
    return t*t*(3-2*t)

height_above_floor=(reference[:,1]-ground)*.1
inseam=np.zeros_like(base)
inseam[:,1]=.79*smoothstep(.12,.85,height_above_floor)*(1-smoothstep(.94,1.38,height_above_floor))
shapes["inseam"]=inseam


def posed(v, rest):
    # Feather shoulder adduction across the deltoid, with fixed bind-space weights.
    side = np.sign(rest[:,0])
    w = np.clip((abs(rest[:,0])-1.25)/1.1,0,1)
    w *= np.clip((rest[:,1]+0.3)/1.1,0,1)
    angle = -side * 0.55 * w*w*(3-2*w)
    x, y = v[:,0]-side*1.48, v[:,1]-4.9
    out = v.copy()
    out[:,0] = side*1.48 + x*np.cos(angle)-y*np.sin(angle)
    out[:,1] = 4.9 + x*np.sin(angle)+y*np.cos(angle)-ground
    return out * 0.1


def fitting(path):
    text = path.read_text()
    assert "CC0" in text, path
    body = text.split("verts 0",1)[1].split("delete_verts",1)
    rows = []
    for line in body[0].strip().splitlines():
        a = line.split()
        if not a or not a[0].isdigit(): continue
        rows.append(list(map(float,a)) if len(a)>1 else [int(a[0])]*3+[1,0,0,0,0,0])
    rows = np.array(rows)
    mask = set()
    if len(body)>1:
        for lo, hi in re.findall(r"(\d+)(?:\s+-\s+(\d+))?",body[1]):
            mask.update(range(int(lo),int(hi or lo)+1))
    idx=rows[:,:3].astype(int)
    weights=rows[:,3:6,None]
    offset=rows[:,6:9]
    scales=[re.search(axis+r"_scale\s+(\d+)\s+(\d+)\s+([\d.]+)",text) for axis in "xyz"]
    def fitted(v):
        ratio=[abs(v[int(m[1]),axis]-v[int(m[2]),axis])/float(m[3]) if m else 1.0 for axis,m in enumerate(scales)]
        return (v[idx]*weights).sum(axis=1)+offset*np.array(ratio)
    return fitted, mask


def normalize(x):
    return x / np.maximum(np.linalg.norm(x,axis=1,keepdims=True),1e-12)


def bake(name, rest, neutral, deltas, uv, faces, texfaces, tint=None, smooth=False):
    # A single topological refinement smooths skin silhouettes without splitting UV seams.
    polys=[list(f) for f in faces]
    textures=[list(f) for f in texfaces]
    if smooth:
        edges={}; adjacent=[]; rings=[[] for _ in rest]
        for fi,f in enumerate(polys):
            for j,i in enumerate(f):
                rings[i].append(fi)
                edge=tuple(sorted((i,f[(j+1)%len(f)])))
                if edge not in edges:
                    edges[edge]=len(edges); adjacent.append([])
                adjacent[edges[edge]].append(fi)
        edge_v=np.array(list(edges))
        lengths=np.array([len(f) for f in polys]); flat=np.concatenate(polys)
        starts=np.cumsum(lengths)-lengths
        edge_f=np.array([[a[0],a[-1]] for a in adjacent])
        border=np.array([len(a)==1 for a in adjacent])
        degree=np.bincount(flat,minlength=len(rest)).clip(1)
        def refine(v):
            centers=np.add.reduceat(v[flat],starts,axis=0)/lengths[:,None]
            mid=v[edge_v].mean(axis=1)
            ep=(2*mid+centers[edge_f].sum(axis=1))/4
            ep[border]=mid[border]
            sums=np.zeros_like(v); mids=np.zeros_like(v)
            np.add.at(sums,flat,np.repeat(centers,lengths,axis=0))
            for col in edge_v.T: np.add.at(mids,col,mid)
            old=(sums+2*mids)/degree[:,None]**2+(1-3/degree[:,None])*v
            old[np.unique(edge_v[border])]=v[np.unique(edge_v[border])]
            return np.concatenate([old,ep,centers])
        newf=[]; newt=[]; tex=list(uv)
        for fi,(f,t) in enumerate(zip(polys,textures)):
            ec=[len(rest)+edges[tuple(sorted((v,f[(j+1)%len(f)])))] for j,v in enumerate(f)]
            ti=len(tex); tex.extend((uv[t]+np.roll(uv[t],-1,axis=0))/2); tex.append(uv[t].mean(axis=0))
            for j,v in enumerate(f):
                newf.append([v,ec[j],len(rest)+len(edges)+fi,ec[j-1]])
                newt.append([t[j],ti+j,ti+len(f),ti+(j-1)%len(f)])
        neutral=refine(neutral); deltas={k:refine(x) for k,x in deltas.items()}
        if tint is not None: tint=refine(tint)
        rest=refine(rest); polys=newf; textures=newt; uv=np.array(tex)
    # Compact duplicate positions only at texture seams; smooth normals across those seams.
    pairs={}; tri=[]
    uv, remap=np.unique(uv.round(6),axis=0,return_inverse=True)
    for f,t in zip(polys,textures):
        ids=[]
        for pair in zip(f,remap[t]):
            if pair not in pairs:pairs[pair]=len(pairs)
            ids.append(pairs[pair])
        tri.extend([[ids[0],ids[j],ids[j+1]] for j in range(1,len(ids)-1)])
    vi,ui=np.array(list(pairs)).T
    tri=np.array(tri); faces3=vi[tri]
    def normals(v):
        n=np.zeros_like(v)
        fn=np.cross(v[faces3[:,1]]-v[faces3[:,0]],v[faces3[:,2]]-v[faces3[:,0]])
        for col in faces3.T: np.add.at(n,col,fn)
        return normalize(n)[vi]
    p=posed(neutral,rest); n=normals(p)
    coords=uv[ui].copy(); coords[:,1]=1-coords[:,1]
    colors=np.ones((len(vi),4)) if tint is None else tint[vi]
    with (stage/(name+".bin")).open("wb") as stream:
        def put(x,dtype="<f4"): np.asarray(x,dtype=dtype).tofile(stream)
        put([len(vi),tri.size],"<i4"); put(p[vi]); put(n); put(coords); put(colors)
        put(tri[:,::-1],"<i4")
        keys=[]
        for key,d in deltas.items():
            if abs(d[vi]).max()<0.0002:continue
            pp=posed(neutral+d,rest)
            put((pp-p)[vi]); put(normals(pp)-n); keys.append(key)
    (stage/(name+".json")).write_text(json.dumps(keys))
    print(name,len(vi),flush=True)


def visibility(v, faces):
    binary=stage/"occlusion"
    if not binary.exists():
        subprocess.run(["c++","-O3","-std=c++17",str(Path(__file__).with_name("occlusion.cpp")),"-o",str(binary)],check=True)
    tris=np.array([[f[0], f[j], f[j+1]] for f in faces for j in range(1,len(f)-1)], dtype="<i4")
    stream=struct.pack("<II",len(v),len(tris))+v.astype("<f4").tobytes()+tris.tobytes()
    return np.frombuffer(subprocess.check_output([str(binary)],input=stream),dtype="<f4")


def strip_uv(uv, faces, texfaces, vertices):
    # Reparameterize each lash or eyebrow island along and across the mesh ribbon.
    import collections
    graph=collections.defaultdict(set)
    for f in texfaces:
        for i in f: graph[i].update(f)
    result=uv.copy()
    lookup={u:v for face,tex in zip(faces,texfaces) for v,u in zip(face,tex)}
    todo=set(graph)
    while todo:
        queue=[todo.pop()]; island=set(queue)
        while queue:
            new=graph[queue.pop()] & todo
            todo-=new; island.update(new); queue.extend(new)
        ids=np.array(sorted(island)); edges=collections.Counter()
        for f in texfaces:
            if f[0] in island:
                edges.update(tuple(sorted((a,b))) for a,b in zip(f,f[1:]+f[:1]))
        border=[(uv[a],uv[b]) for (a,b),k in edges.items() if k==1]
        x=uv[ids,0]; start=x.min(); end=x.max()
        for idx in ids:
            px,py=uv[idx]; section=np.clip(px,start+.00001,end-.00001)
            ys=[a[1]+(b[1]-a[1])*(section-a[0])/(b[0]-a[0]) for a,b in border if min(a[0],b[0])<=section<=max(a[0],b[0]) and abs(a[0]-b[0])>1e-9]
            t=np.clip((py-min(ys))/max(max(ys)-min(ys),.00001),0,1) if ys else .5
            result[idx]=[(px-start)/(end-start),t]
        # Geometric outer corners have greater |x|. The row farthest forward is the lash tip.
        verts=vertices[[lookup[k] for k in ids]]
        if np.corrcoef(abs(verts[:,0]),result[ids,0])[0,1]<0:result[ids,0]=1-result[ids,0]
        if np.corrcoef(verts[:,2],result[ids,1])[0,1]<0:result[ids,1]=1-result[ids,1]
    return result


from groom import swept_groom
swept_groom(reference,body_faces,shapes,bake)

outfits=["female_casualsuit01","female_casualsuit02","female_elegantsuit01"]
parts=outfits+["shoes01","short02","bob01","high-poly","eyebrow001","eyelashes01","teeth_base","fedora01"]
masks={}
for part in parts:
    folder=next(assets.glob("*/"+part))
    v,uv,f,t=obj(next(folder.glob("*.obj")))
    fit, masks[part]=fitting(next(folder.glob("*.mhclo")))
    v=fit(base)
    neutral=fit(reference)
    tint=np.ones((len(v),4))
    if part in ["eyelashes01","eyebrow001"]:
        uv=strip_uv(uv,f,t,neutral)
    if part in ["short02","bob01"]:
        from collections import Counter
        edges=Counter(tuple(sorted((a,b))) for face in f for a,b in zip(face,face[1:]+face[:1]))
        boundaries=np.unique([k for edge,n in edges.items() if n==1 for k in edge])
        if len(boundaries):
            for k in range(0,len(v),64):
                dist=np.linalg.norm(neutral[k:k+64,None,:]-neutral[boundaries],axis=2).min(axis=1)
                tint[k:k+64,1]=np.clip(dist/.062,0,1)
    if part=="high-poly":
        # Use spherical eye-local coordinates for the procedural iris, independent of UV islands.
        for sign in [-1,1]:
            ix=v[:,0]*sign>0
            center=(v[ix].min(axis=0)+v[ix].max(axis=0))/2
            tint[ix,0]=(v[ix,0]-center[0])/0.36+0.5
            tint[ix,1]=(v[ix,1]-center[1])/0.36+0.5
    if part in outfits:
        tint[:,3]=visibility(neutral,f)
        from collections import Counter
        edge_count=Counter(tuple(sorted((a,b))) for face in f for a,b in zip(face,face[1:]+face[:1]))
        border=np.unique([v for edge,c in edge_count.items() if c==1 for v in edge])
        if len(border):
            for k in range(0,len(v),64):
                dist=np.linalg.norm(neutral[k:k+64,None,:]-neutral[border],axis=2).min(axis=1)
                tint[k:k+64,1]=np.clip(dist/.16,0,1)
        # Connected pieces (shirt, trousers, buttons) retain independent dye zones.
        parent=list(range(len(v)))
        def root(i):
            while parent[i]!=i:
                parent[i]=parent[parent[i]]; i=parent[i]
            return i
        for face in f:
            for j in face[1:]: parent[root(j)]=root(face[0])
        groups={}
        for i in range(len(v)):groups.setdefault(root(i),[]).append(i)
        for ids in groups.values():
            tint[ids,0]=0.25 if v[ids,1].mean()<0.65 else 0.8
        print(part,[(len(ids),round(v[ids,1].mean(),1)) for ids in groups.values() if len(ids)>50])
    appearance_deltas={k:fit(reference+d)-neutral for k,d in shapes.items()}
    if part in outfits:
        tris=np.array([[face[0],face[j],face[j+1]] for face in f for j in range(1,len(face)-1)])
        outward=np.zeros_like(neutral)
        normals=np.cross(neutral[tris[:,1]]-neutral[tris[:,0]],neutral[tris[:,2]]-neutral[tris[:,0]])
        for col in tris.T: np.add.at(outward,col,normals)
        outward=normalize(outward)
        neutral+=outward*.034
        for key in ["frame","weight","muscle"]:
            appearance_deltas[key]+=outward*.038
    bake(part,v,neutral,appearance_deltas,uv,f,t,tint,part in outfits)
# Use the authored garment occlusion masks on the original body topology.
skin_visibility=visibility(reference,body_faces)
for index,outfit in enumerate(outfits):
    mask=masks[outfit]|masks["shoes01"]
    keep=[i for i,f in enumerate(body_faces) if sum(v in mask for v in f)<len(f)*.70]
    # Anatomical masks in bind space remain attached when morphs move the face.
    x,y,z=base.T
    tint=np.ones((len(base),4))
    # Lip borders follow the anatomical rings around the mouth (refined below during bake).
    mouth=np.exp(-((x/.268)**4+((y-6.60)/.105)**2))*np.clip((z-1.28)*7,0,1)
    tint[:,3]=skin_visibility
    tint[:,0]=mouth
    tint[:,1]=np.exp(-(((abs(x)-.47)/.28)**2+((y-6.94)/.24)**2))*np.clip((z-1)*3,0,1)
    tint[:,2]=np.clip(y-0.1,0,1)
    bake("body"+str(index),base,reference,shapes,base_uv,[body_faces[i] for i in keep],[body_uv[i] for i in keep],tint,True)
