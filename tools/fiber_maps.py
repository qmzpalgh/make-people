"""Draw original strand opacity maps for the fitted lash and brow ribbons (Pillow)."""
import math
import random
from pathlib import Path
from PIL import Image,ImageDraw
rng=random.Random(8451)
for mode in ["brow","lash"]:
    scale=3
    width,height=768,160
    image=Image.new("RGBA",(width*scale,height*scale))
    draw=ImageDraw.Draw(image)
    strands=750 if mode=="brow" else 64
    for i in range(strands):
        x=rng.random()
        if mode=="brow":
            center=.54+.09*math.sin(x*4)
            spread=(.31+.16*math.sin(math.pi*x))*(1-x**2.5)*min(1,(x+.01)*13)
            y=center+rng.uniform(-1,1)*spread
            dx=(.016+.093*x)*rng.uniform(.65,1.3)
            dy=-rng.uniform(.10,.29)*(1-.73*x)
            thickness=rng.uniform(.52,1.18)
        else:
            y=.98+rng.uniform(-.02,.05)
            dx=rng.uniform(.005,.036)*(.4+x)
            dy=-rng.uniform(.6,1.0)*(.4+.6*math.sin(math.pi*x*.79))
            thickness=rng.uniform(.7,1.20)
        pigment=rng.randint(115,230)
        left=[];right=[]
        for j in range(11):
            t=j/10
            px=(x+dx*t**1.15)*width
            py=(y+dy*(t+.15*math.sin(math.pi*t)))*height
            radius=thickness*(.22+.78*math.sin(math.pi*(.17+.83*t))**.65)
            angle=math.atan2(dy*height,dx*width)
            offset=(-math.sin(angle)*radius,math.cos(angle)*radius)
            left.append(((px+offset[0])*scale,(py+offset[1])*scale))
            right.append(((px-offset[0])*scale,(py-offset[1])*scale))
        draw.polygon(left+right[::-1],fill=(pigment,pigment,pigment,245))
    image.resize((width,height),Image.Resampling.LANCZOS).save(Path(__file__).resolve().parents[1]/"art"/(mode+".png"))
