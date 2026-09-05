"""Deterministic, dependency-free hard-surface racer mesh generator.
Run with Python 3. Writes standard glTF 2.0 GLB assets and Godot wrappers.
Axes: +Y up, -Z nose, meters. Individual named parts remain editable.
"""
import json, math, struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def sub(a,b): return [a[i]-b[i] for i in range(3)]
def cross(a,b): return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
def dot(a,b): return sum(x*y for x,y in zip(a,b))
def norm(a):
    d=math.sqrt(dot(a,a)); return [x/d for x in a] if d else [0,1,0]
def rgb(h):
    c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return [v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]

class Ship:
    def __init__(self,name,color,secondary):
        self.name=name; self.parts=[]; self.mounts=[]
        def mat(n,h,metal=.4,rough=.36,emit=False):
            d={'name':n,'pbrMetallicRoughness':{'baseColorFactor':rgb(h)+[1], 'metallicFactor':metal,'roughnessFactor':rough}}
            if emit: d['emissiveFactor']=rgb(h)
            return d
        self.mats=[mat('Team paint',color),mat('Secondary paint',secondary),mat('Graphite chassis','252C35',.7),mat('Titanium edges','8E9BA5',.8,.27),mat('Smoked canopy','092330',.65,.13),mat('Thruster cyan','51E3FF',.1,.23,True),mat('Intake darkness','090E15',.2),mat('Identification white','F0F4F5',.2)]
    def poly(self,name,verts,faces,mat):
        center=[sum(v[i] for v in verts)/len(verts) for i in range(3)]
        p=[]; n=[]; uv=[]
        for face in faces:
            for j in range(1,len(face)-1):
                tri=[verts[face[k]] for k in (0,j,j+1)]
                normal=cross(sub(tri[1],tri[0]),sub(tri[2],tri[0]))
                if dot(normal,normal)<1e-14: continue
                midpoint=[sum(v[i] for v in tri)/3 for i in range(3)]
                if dot(normal,sub(midpoint,center))<0:
                    tri.reverse(); normal=[-v for v in normal]
                normal=norm(normal)
                # Planar per-face UVs in meter scale, suitable for tiled detail.
                axis=max(range(3),key=lambda i:abs(normal[i])); axes=[i for i in range(3) if i!=axis]
                for v in tri: p.extend(v); n.extend(normal); uv.extend([v[axes[0]],v[axes[1]]])
        self.parts.append((name,p,n,uv,mat))
    def loft(self,name,sections,mat=0,x=0):
        # section = z, half width, center y, half height; chamfered octagon
        verts=[]
        for z,w,y,h in sections:
            verts.extend([(x+a*w,y+b*h,z) for a,b in [(1,.48),(.76,1),(-.76,1),(-1,.48),(-1,-.48),(-.76,-1),(.76,-1),(1,-.48)]])
        faces=[list(range(7,-1,-1)),list(range((len(sections)-1)*8,len(sections)*8))]
        for i in range(len(sections)-1):
            for j in range(8): faces.append([i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j])
        self.poly(name,verts,faces,mat)
    def box(self,name,c,s,mat=2):
        x,y,z=c; w,h,d=s
        self.loft(name,[(z-d/2,w/2,y,h/2),(z+d/2,w/2,y,h/2)],mat,x)
    def panel(self,name,points,y,thick=.09,mat=0):
        count=len(points)
        v=[(x,y+dy,z) for dy in (-thick/2,thick/2) for x,z in points]
        f=[list(range(count)),list(range(count,2*count))]
        f += [[i,(i+1)%count,(i+1)%count+count,i+count] for i in range(count)]
        self.poly(name,v,f,mat)
    def cockpit(self,z=-.15,w=.47,length=2.1,y=.52):
        self.loft('Canopy titanium gasket',[(z-length*.56,.12,y,.035),(z-length*.23,w*1.1,y+.17,.21),(z+length*.27,w*1.1,y+.16,.22),(z+length*.5,w*.73,y,.075)],3)
        self.loft('Smoked cockpit glass',[(z-length*.52,.11,y+.06,.035),(z-length*.22,w,y+.23,.23),(z+length*.26,w,y+.22,.24),(z+length*.46,w*.7,y+.08,.06)],4)
        self.loft('Cockpit dorsal frame',[(z+length*.29,w*1.03,y+.2,.25),(z+length*.39,w*.87,y+.13,.2),(z+length*.49,w*.76,y+.02,.13)],1)
    def engine(self,x,z,w=.48,h=.34,y=.05):
        self.loft('Exhaust titanium collar',[(z-.2,w,y,h),(z+.18,w*.95,y,h*.91)],3,x)
        self.loft('Exhaust black aperture',[(z+.181,w*.8,y,h*.74),(z+.195,w*.8,y,h*.74)],6,x)
        self.loft('Ion exhaust core',[(z+.196,w*.59,y,h*.42),(z+.207,w*.59,y,h*.42)],5,x)
        for i in [-1,0,1]: self.box('Exhaust vane',(x+i*w*.35,y,z+.222),(.045,h*.95,.04),2)
        self.mounts.append((f'Thruster_{len(self.mounts)+1}',[x,y,z+.25]))
    def vents(self,x,z,y,width=.45,count=5):
        self.box('Vent recess',(x,y,z),(width+.12,.045,count*.145+.14),6)
        for i in range(count): self.box('Cooling louver',(x,y+.035,z+(i-(count-1)/2)*.145),(width,.045,.055),3)
    def skid(self,x,z,length=2):
        self.loft('Antigravity rail',[(z-length/2,.11,-.36,.075),(z+length/2,.16,-.36,.075)],2,x)
        self.box('Antigravity emitter',(x,-.44,z),(.13,.025,length*.76),5)
    def stripe(self,x,z,y,length,width=.07,mat=1): self.box('Livery stripe',(x,y,z),(width,.028,length),mat)
    def save(self):
        buf=bytearray(); views=[]; acc=[]; meshes=[]; nodes=[]
        def accessor(data,width):
            while len(buf)%4:buf.append(0)
            off=len(buf); buf.extend(struct.pack('<'+'f'*len(data),*data))
            views.append({'buffer':0,'byteOffset':off,'byteLength':len(data)*4,'target':34962})
            a={'bufferView':len(views)-1,'componentType':5126,'count':len(data)//width,'type':f'VEC{width}'}
            if width==3:a.update(min=[min(data[i::3]) for i in range(3)],max=[max(data[i::3]) for i in range(3)])
            acc.append(a);return len(acc)-1
        for name,p,n,uv,mat in self.parts:
            attrs={'POSITION':accessor(p,3),'NORMAL':accessor(n,3),'TEXCOORD_0':accessor(uv,2)}
            meshes.append({'name':name,'primitives':[{'attributes':attrs,'material':mat,'mode':4}]})
            nodes.append({'name':f'{name.replace(" ","_")}_{len(nodes):03}','mesh':len(meshes)-1})
        nodes.extend({'name':name,'translation':pos} for name,pos in self.mounts)
        nodes.append({'name':'CameraMount','translation':[0,2.2,5.8]})
        children=list(range(len(nodes)));nodes.append({'name':self.name,'children':children})
        doc={'asset':{'version':'2.0','generator':'Original anti-gravity racer mesh builder'},'scene':0,'scenes':[{'nodes':[len(nodes)-1]}],'nodes':nodes,'meshes':meshes,'materials':self.mats,'buffers':[{'byteLength':len(buf)}],'bufferViews':views,'accessors':acc}
        js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
        buf+=b'\0'*((-len(buf))%4)
        out=struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(buf))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(buf),0x004E4942)+buf
        (ROOT/'models'/f'{self.name.lower()}.glb').write_bytes(out)
        coords=[p for _,p,_,_,_ in self.parts]
        lo=[min(min(p[i::3]) for p in coords) for i in range(3)]
        hi=[max(max(p[i::3]) for p in coords) for i in range(3)]
        return {'name':self.name,'triangles':sum(len(p)//9 for _,p,_,_,_ in self.parts),'parts':len(self.parts),'bounds_min':lo,'bounds_max':hi,'thrusters':len(self.mounts)}

def needle():
    s=Ship('Needle','E8E8E0','D93626')
    s.loft('Lower monocoque',[(-4.6,.035,-.02,.065),(-1.3,.56,-.04,.23),(1.7,.66,-.02,.3),(2.8,.45,.01,.24)],2)
    s.loft('Spear shell',[(-4.6,.025,.075,.025),(-1.1,.53,.2,.19),(1.3,.59,.22,.25),(2.6,.42,.18,.19)],0)
    s.loft('Scarlet spine',[(-4.25,.035,.115,.02),(-1.05,.115,.405,.016),(-.65,.115,.425,.016)],1)
    s.cockpit(.0,.39,2.05,.44)
    for sign in [-1,1]:
        s.loft('Engine shoulder',[(.5,.19,.05,.24),(1.2,.35,.06,.38),(2.5,.31,.04,.31)],0,sign*.71)
        s.panel('Swept stabilizer',[(sign*.62,1.35),(sign*1.64,2.64),(sign*.71,2.38)],.18,.12,0)
        s.panel('Stabilizer red tip',[(sign*1.27,2.2),(sign*1.64,2.64),(sign*1.28,2.54)],.255,.028,1)
        s.engine(sign*.71,2.56,.27,.27)
        s.vents(sign*.74,1.62,.46,.3,4);s.skid(sign*.36,-.5,2.7)
    s.loft('Tail fin',[(1.65,.065,.54,.26),(2.65,.06,.79,.66),(2.95,.045,.65,.48)],1)
    return s

def fork():
    s=Ship('Fork','EDB72C','353D49')
    s.loft('Recessed bridge',[(-.9,.53,.03,.19),(1.45,.74,.06,.28),(2.7,.6,.04,.25)],2)
    s.cockpit(.5,.43,1.85,.3)
    s.box('Rear transverse structure',(0,.04,1.92),(3.05,.33,.48),3)
    for sign in [-1,1]:
        x=sign*1.08
        s.loft('Twin prong chassis',[(-3.5,.14,-.08,.16),(-2.2,.35,-.06,.22),(.4,.48,0,.36),(2.65,.48,.02,.38)],2,x)
        s.loft('Yellow fork armor',[(-3.45,.135,.075,.08),(-1.9,.31,.16,.15),(.4,.43,.23,.25),(2.5,.43,.25,.24)],0,x)
        s.loft('Prong inset',[(-2.75,.09,.2,.025),(-.4,.18,.42,.035),(.5,.23,.51,.03)],1,x)
        s.box('Inner rail',(x-sign*.39,-.03,-.5),(.08,.13,2.7),3)
        s.loft('Raised aft cowl',[(1,.5,.3,.27),(1.35,.52,.4,.32),(2.45,.48,.35,.29)],0,x)
        s.vents(x,1.8,.735,.61,5);s.engine(x,2.72,.4,.32);s.skid(x,-.7,3.7)
        s.stripe(x+sign*.24,-1.3,.348,1.1,.06,7)
    return s

def manta():
    s=Ship('Manta','258D92','E2E6DE')
    s.loft('Central keel',[(-3.5,.19,-.02,.14),(-.9,.8,.02,.3),(1.8,.79,.01,.27),(2.55,.62,0,.21)],2)
    s.loft('Center fairing',[(-3.5,.16,.12,.07),(-.7,.65,.28,.25),(1.6,.68,.27,.23),(2.55,.52,.15,.14)],0)
    for sign in [-1,1]:
        s.panel('Delta lower wing',[(sign*.15,-2.95),(sign*2.8,.95),(sign*2.65,2.46),(sign*.56,1.73)],-.015,.34,2)
        s.panel('Delta upper shell',[(sign*.34,-2.85),(sign*2.69,1),(sign*2.56,2.4),(sign*.61,1.7)],.19,.2,0)
        s.panel('Ivory outer flash',[(sign*1.18,-1.4),(sign*2.69,1),(sign*2.56,2.4),(sign*1.96,1.64)],.304,.035,1)
        s.panel('Leading titanium edge',[(sign*.37,-2.86),(sign*2.7,.98),(sign*2.65,1.12),(sign*.39,-2.66)],.225,.08,3)
        s.vents(sign*1.18,1.32,.315,.56,6);s.engine(sign*1.0,2.05,.46,.21,-.03)
        s.skid(sign*1.42,.2,2.2)
        s.stripe(sign*.38,-1.84,.44,.67,.055,1)
    s.cockpit(-.15,.45,2.05,.49)
    s.loft('Rear dorsal fairing',[(.95,.31,.57,.15),(2.32,.22,.43,.18)],1)
    return s

def brute():
    s=Ship('Brute','D76526','313943')
    s.box('Heavy cross frame',(0,-.04,.1),(3.6,.37,3.7),2)
    s.loft('Cockpit armored tub',[(-2.3,.44,.06,.3),(-1.5,.62,.13,.42),(1.8,.64,.13,.43),(2.45,.48,.1,.32)],0)
    s.cockpit(-.4,.44,1.85,.55)
    for sign in [-1,1]:
        x=sign*1.38
        s.loft('Massive engine housing',[(-2.65,.48,.03,.38),(-2.2,.63,.08,.52),(1.85,.65,.1,.55),(2.6,.5,.07,.43)],2,x)
        s.loft('Armored pod crown',[(-2.4,.44,.37,.13),(-1.75,.56,.49,.16),(1.35,.57,.51,.17),(2.2,.44,.41,.12)],0,x)
        for z in [-1.48,-.52,.44,1.4]:
            s.box('Pod armor seam',(x,.679,z),(1.01,.023,.038),2)
            s.box('Outer shoulder armor',(x+sign*.58,.13,z),(.13,.39,.72),0)
        s.loft('Forward intake surround',[(-2.7,.42,.025,.32),(-2.64,.45,.025,.35)],3,x)
        s.loft('Forward intake shadow',[(-2.708,.34,.025,.25),(-2.703,.34,.025,.25)],6,x)
        for offset in [-.18,0,.18]:s.box('Intake vertical bars',(x+offset,.025,-2.72),(.035,.4,.025),3)
        s.vents(x,1.01,.705,.7,5);s.engine(x,2.62,.45,.37);s.skid(x,-.1,3.5)
        s.stripe(x-sign*.19,-1.16,.678,1.22,.17,1)
    s.vents(0,1.57,.59,.72,6)
    return s

def wraith():
    s=Ship('Wraith','734FA8','C8D1D8')
    s.loft('Suspended central spine',[(-3.5,.04,.02,.06),(-1.2,.45,.14,.2),(.9,.47,.15,.22),(2.7,.18,.06,.17)],1)
    s.loft('Violet dorsal shell',[(-3.1,.065,.11,.035),(-.9,.38,.33,.13),(1.25,.39,.34,.13),(2.45,.14,.2,.09)],0)
    s.cockpit(-.1,.35,1.95,.43)
    for sign in [-1,1]:
        x=sign*1.55
        for z in [-.85,1.65]:
            s.panel('Outrigger structural bridge',[(sign*.3,z-.13),(x,z+.23),(x,z+.47),(sign*.3,z+.11)],-.015,.17,2)
            s.panel('Bridge titanium spine',[(sign*.37,z-.08),(x,z+.28),(x,z+.34),(sign*.37,z-.015)],.08,.045,3)
        s.loft('Outrigger keel',[(-3.65,.03,-.035,.06),(-1.8,.31,-.03,.2),(1.7,.33,-.01,.25),(2.75,.17,.07,.2)],2,x)
        s.loft('Outrigger purple armor',[(-3.55,.035,.045,.03),(-1.65,.29,.16,.13),(1.65,.3,.21,.14),(2.72,.14,.2,.08)],0,x)
        s.loft('Silver spear tip',[(-3.64,.025,.02,.045),(-2.1,.21,.12,.1),(-1.82,.255,.14,.1)],1,x)
        s.vents(x,.85,.38,.35,5);s.engine(x,2.66,.185,.19,.055);s.skid(x,-.2,3.3)
        s.loft('Reverse swept tail blade',[(1.1,.045,.38,.1),(2.8,.045,.63,.44),(3.0,.025,.59,.34)],0,sign*.55)
        s.stripe(x, -.5,.309,.85,.06,1)
    return s

def wrapper(s,stats):
    name=s.name.lower()
    # Multiple coarse convex boxes retain the empty spaces between prongs.
    shapes={'needle':[(0,0,-.75,1.15,.8,6.4),(-.72,0,1.55,.75,.85,2.25),(.72,0,1.55,.75,.85,2.25)],
    'fork':[(-1.08,0,-.3,1,1,6.2),(1.08,0,-.3,1,1,6.2),(0,.1,1,1.1,.9,3.4)],
    'manta':[(0,0,-.45,1.4,1,6),(-1.45,0,.7,1.9,.6,3.5),(1.45,0,.7,1.9,.6,3.5)],
    'brute':[(0,.1,0,1.2,1.2,4.8),(-1.38,0,0,1.3,1.1,5.5),(1.38,0,0,1.3,1.1,5.5)],
    'wraith':[(0,.1,-.1,.9,.9,6.5),(-1.55,0,-.45,.65,.6,6.4),(1.55,0,-.45,.65,.6,6.4)]}[name]
    lines=[f'[gd_scene load_steps={2+len(shapes)} format=3]',f'[ext_resource type="PackedScene" path="res://models/{name}.glb" id="1"]']
    for i,(_,_,_,w,h,d) in enumerate(shapes):lines.extend([f'[sub_resource type="BoxShape3D" id="Shape{i}"]',f'size = Vector3({w}, {h}, {d})'])
    lines.extend([f'[node name="{s.name}" type="CharacterBody3D"]','collision_layer = 2','collision_mask = 1',f'metadata/model_triangles = {stats["triangles"]}','[node name="Visual" parent="." instance=ExtResource("1")]'])
    for i,(x,y,z,*_) in enumerate(shapes):lines.extend([f'[node name="Collision{i+1}" type="CollisionShape3D" parent="."]',f'position = Vector3({x}, {y}, {z})',f'shape = SubResource("Shape{i}")'])
    for name,pos in s.mounts:lines.extend([f'[node name="{name}" type="Marker3D" parent="."]',f'position = Vector3({", ".join(map(str,pos))})'])
    lines.extend(['[node name="CameraMount" type="Marker3D" parent="."]','position = Vector3(0, 2.2, 5.8)'])
    (ROOT/'scenes'/f'{s.name.lower()}.tscn').write_text('\n\n'.join(lines)+'\n')

if __name__=='__main__':
    (ROOT/'models').mkdir(exist_ok=True);(ROOT/'scenes').mkdir(exist_ok=True)
    stats=[]
    for builder in [needle,fork,manta,brute,wraith]:
        s=builder(); item=s.save();wrapper(s,item);stats.append(item)
    (ROOT/'models'/'manifest.json').write_text(json.dumps(stats,indent=2))
    print(json.dumps(stats,indent=2))
