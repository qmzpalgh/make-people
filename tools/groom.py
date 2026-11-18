"""Construct a swept, tied groom on the neutral MakeHuman scalp.
Called from build_meshes with its neutral mesh and blend-shape baker.
"""
import numpy as np


def swept_groom(reference, body_faces, shapes, bake):
    rng=np.random.default_rng(47)
    ids=np.unique(np.concatenate(body_faces))
    ids=ids[(reference[ids,1]>6.05)&(abs(reference[ids,0])<.76)]
    center=np.array([0,6.89,.45])
    radii=np.array([.72,.96,.99])
    directions=(reference[ids]-center)/radii
    radius=np.linalg.norm(directions,axis=1)
    directions/=radius[:,None]
    a=np.linspace(0,2*np.pi,513)
    t=np.linspace(0,1,65)
    front=np.cos(a)
    # Widow's peak, temporal recession, sideburn, ear clearance, and nape.
    hairline=np.interp(front,[-1,-.78,-.38,-.08,.12,.25,.5,.78,1],
        [6.18,6.31,6.68,6.89,6.84,6.69,6.98,7.18,7.27])
    hairline+=.025*np.sin(5*a+.6)+.014*np.sin(15*a+.3)+.009*np.sin(37*a)
    elev=np.arcsin(np.clip((hairline-center[1])/radii[1],-.95,.95))
    roots=np.stack([np.sin(a)*np.cos(elev),np.sin(elev),front*np.cos(elev)],axis=-1)
    pole=np.array([.016,.38,-.925]);pole/=np.linalg.norm(pole)
    ang=np.arccos(np.clip(roots@pole,-1,1))
    u=(t*.963)[None,:]
    d=(np.sin((1-u)*ang[:,None])[:,:,None]*roots[:,None,:]+np.sin(u*ang[:,None])[:,:,None]*pole)/np.sin(ang)[:,None,None]
    # A slight directional sweep prevents mechanically straight meridians.
    drift=.045*np.sin(t*np.pi)[None,:]*(.6+.4*np.sin(a[:,None]*2))
    x=d[:,:,0].copy();z=d[:,:,2].copy()
    d[:,:,0]=x*np.cos(drift)+z*np.sin(drift)
    d[:,:,2]=z*np.cos(drift)-x*np.sin(drift)
    flat=d.reshape(-1,3)
    pos=[]; morph=[]
    for start in range(0,len(flat),96):
        dot=flat[start:start+96]@directions.T
        near=np.argpartition(dot,-7,axis=1)[:,-7:]
        weight=1/np.maximum(1-np.take_along_axis(dot,near,axis=1),.0001)**1.3
        weight/=weight.sum(axis=1,keepdims=True)
        r=(weight*radius[near]).sum(axis=1)
        pos.extend(center+flat[start:start+96]*r[:,None]*radii)
        morph.extend((shapes["frame"][ids[near]]*weight[:,:,None]).sum(axis=1))
    pos=np.array(pos).reshape(d.shape);morph=np.array(morph).reshape(d.shape)
    lift=.022+.086*np.sin(np.pi*t)**.7+.04*t
    pos+=d*lift[None,:,None]
    vertices=[]; shifts=[]; length=[]; tex=[]; faces=[]; tint=[]
    def point(p,m,uv,brightness,dl=None):
        vertices.append(p);shifts.append(m);tex.append(uv);tint.append([brightness,.5,0,1])
        length.append([0,0,0] if dl is None else dl)
    # One continuous scalp surface with longitudinal UVs; texture follows the comb direction.
    for i in range(0,513,4):
        for j in range(0,65,2):
            point(pos[i,j],morph[i,j],[i/512,j/64],.55)
            k=len(vertices)-1
            if i and j:faces.append([k-34,k-33,k,k-1])
    # Fine geometry at the silhouette, with offset variation, tapered tips and escape hairs.
    for strand in range(2100):
        s=rng.uniform(0,512)
        offset=rng.uniform(.001,.014)
        fly=strand<145
        width=rng.uniform(.0012,.0035)
        begin=rng.uniform(-.058,.035);end=rng.uniform(.82,1) if not fly else rng.uniform(.25,.85)
        phase=rng.uniform(0,6.28);vivid=rng.uniform(.25,.92)
        for j,tau in enumerate(np.linspace(begin,end,22)):
            f=j/21
            h=s+1.45*np.sin(phase+f*7)+(.45 if not fly else 2.8)*np.sin(f*12+phase)
            i=int(h)%512; frac=h-np.floor(h)
            q=np.clip(tau*64,0,63.999);k=int(q);v=q-k
            def sample(g):
                return (1-frac)*((1-v)*g[i,k]+v*g[i,k+1])+frac*((1-v)*g[i+1,k]+v*g[i+1,k+1])
            normal=sample(d)
            lift=offset*np.sin(np.pi*f)+(.032*np.sin(np.pi*f)**2 if fly else 0)
            p=sample(pos)+normal*lift
            if tau<0:p=p+(pos[i,1]-pos[i,0])*tau*64
            widthdir=pos[i+1,k]-pos[i,k];widthdir/=max(np.linalg.norm(widthdir),1e-7)
            side=widthdir*width*(.1+.9*np.sin(np.pi*f)**.36)
            m=sample(morph)
            point(p-side,m,[s/512,tau],vivid)
            point(p+side,m,[(s+.06)/512,tau],vivid)
            n=len(vertices)
            if j:faces.append([n-4,n-2,n-1,n-3])
    anchor=pos[0,-1]*.4+pos[256,-1]*.6
    move=morph[256,-1]
    # Layer tapered, irregular locks along a curved tail; continuous length sculpt affects the fall.
    for lock in range(17):
        angle=2*np.pi*lock/17
        phase=rng.uniform(0,6.28);reach=rng.uniform(1.67,2.12)
        for j,f in enumerate(np.linspace(0,1,27)):
            ctr=anchor+np.array([.19*np.sin(f*5)*f+.10*f,-reach*f**1.42,-.68*np.sin(f*2.35)-.22*f])
            radius=(.042+.18*np.sin(np.pi*f)**.62)*(1-.5*f)
            ctr+=np.array([np.cos(angle+.8*f)*radius,.04*np.sin(angle)*np.sin(np.pi*f),np.sin(angle+.8*f)*radius])
            thick=(.048+.10*np.sin(np.pi*f)**.6)*(1-f)**.6+.002
            for col,phi in enumerate(np.linspace(0,2*np.pi,9)):
                p=ctr+np.array([np.cos(phi)*thick,.07*np.sin(phi)*(1-f),np.sin(phi)*thick])
                point(p,move,[lock*.12+col*.014,f],.48+.12*np.sin(angle),[0,-f*.9,-.1*f])
                k=len(vertices)-1
                if j and col:faces.append([k-10,k-1,k,k-9])
    v=np.array(vertices)
    bake("swept",v,v,{"frame":np.array(shifts),"length":np.array(length)},np.array(tex),faces,faces,np.array(tint))
