// Deterministic object-space ambient visibility, sampled with orthographic depth maps.
// stdin: vertex count, triangle count, float XYZ, uint32 indices. stdout: float visibility.
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <vector>
using V = std::array<float, 3>;
float dot(V a, V b) { return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]; }
V sub(V a,V b) { return {a[0]-b[0], a[1]-b[1], a[2]-b[2]}; }
V cross(V a,V b) { return {a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]}; }
V unit(V a) {float l=std::sqrt(dot(a,a)); for(float& x:a)x/=std::max(l,1e-15f);return a;}
int main(){
    int n,t; if(fread(&n,4,1,stdin)!=1 || fread(&t,4,1,stdin)!=1)return 1;
    std::vector<V> v(n),p(n),normal(n);
    std::vector<std::array<int,3>> faces(t);
    if(fread(v.data(),12,n,stdin)!=(unsigned)n||fread(faces.data(),12,t,stdin)!=(unsigned)t)return 1;
    for(auto f:faces){V fn=cross(sub(v[f[1]],v[f[0]]),sub(v[f[2]],v[f[0]]));for(int i:f)for(int j=0;j<3;j++)normal[i][j]+=fn[j];}
    for(auto& a:normal)a=unit(a);
    constexpr int R=1024, samples=100;
    std::vector<float> depth(R*R),occ(n),total(n);
    for(int s=0;s<samples;s++){
        float z=1-2*(s+.5f)/samples, r=std::sqrt(1-z*z),phi=s*2.39996323f;
        V dir={r*std::cos(phi),z,r*std::sin(phi)},u=unit(cross(dir,{0,1,0})),w=cross(dir,u);
        float xmin=1e9,ymin=1e9,xmax=-1e9,ymax=-1e9;
        for(int i=0;i<n;i++){p[i]={dot(v[i],u),dot(v[i],w),dot(v[i],dir)};
            xmin=std::min(xmin,p[i][0]);ymin=std::min(ymin,p[i][1]);xmax=std::max(xmax,p[i][0]);ymax=std::max(ymax,p[i][1]);}
        for(V& a:p){a[0]=2+(R-5)*(a[0]-xmin)/(xmax-xmin);a[1]=2+(R-5)*(a[1]-ymin)/(ymax-ymin);}
        std::fill(depth.begin(),depth.end(),-1e9);
        for(auto f:faces){
            auto a=p[f[0]],b=p[f[1]],c=p[f[2]];
            float det=(b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]); if(std::abs(det)<1e-8)continue;
            for(int y=std::ceil(std::min({a[1],b[1],c[1]}));y<=std::max({a[1],b[1],c[1]});y++)
            for(int x=std::ceil(std::min({a[0],b[0],c[0]}));x<=std::max({a[0],b[0],c[0]});x++){
                float i=((x-a[0])*(c[1]-a[1])-(y-a[1])*(c[0]-a[0]))/det;
                float j=((b[0]-a[0])*(y-a[1])-(b[1]-a[1])*(x-a[0]))/det;
                if(i>=0 && j>=0 && i+j<=1)depth[y*R+x]=std::max(depth[y*R+x],a[2]+i*(b[2]-a[2])+j*(c[2]-a[2]));
            }
        }
        for(int i=0;i<n;i++){float weight=std::max(0.f,dot(dir,normal[i])); if(weight==0)continue;
            int x=std::round(p[i][0]),y=std::round(p[i][1]);float gap=depth[y*R+x]-p[i][2];
            if(gap>.024f)occ[i]+=weight*std::clamp((gap-.024f)/.045f,0.f,1.f);
            total[i]+=weight;}
    }
    for(int i=0;i<n;i++)occ[i]=1-occ[i]/std::max(.01f,total[i]);
    return fwrite(occ.data(),4,n,stdout)==(unsigned)n?0:1;
}
