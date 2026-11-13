# Zeichnet das Suona-Symbol: Bühne, Scheinwerfer, rotes Plektrum, zwei Achtelnoten.
import math, os
from PIL import Image, ImageDraw
S=1024
base=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def icon(size):
    im=Image.new('RGBA',(S,S),(0,0,0,0)); d=ImageDraw.Draw(im)
    d.rounded_rectangle([0,0,S-1,S-1],radius=220,fill=(27,26,58,255))
    beam=Image.new('RGBA',(S,S),(0,0,0,0)); bd=ImageDraw.Draw(beam)
    bd.polygon([(470,0),(554,0),(900,S),(124,S)],fill=(255,233,168,34))
    im=Image.alpha_composite(im,beam); d=ImageDraw.Draw(im)
    cx,top,bot,w=512,200,890,600
    path=[]
    for i in range(0,181):
        t=math.pi-i/180*math.pi
        path.append((cx+w/2*math.cos(t), top+70-80*math.sin(t)))
    n=80
    for i in range(1,n+1):
        f=i/n
        path.append((cx+w/2*math.sqrt(max(0,1-f**1.7)), top+70+(bot-top-70)*f))
    for i in range(n,0,-1):
        f=i/n
        path.append((cx-w/2*math.sqrt(max(0,1-f**1.7)), top+70+(bot-top-70)*f))
    d.polygon(path,fill=(214,58,74,255))
    white=(255,253,248,255)
    for (x,y) in [(410,640),(610,590)]:
        h=Image.new('RGBA',(S,S),(0,0,0,0)); hd=ImageDraw.Draw(h)
        hd.ellipse([x-66,y-46,x+66,y+46],fill=white)
        im=Image.alpha_composite(im,h.rotate(20,center=(x,y)))
    d=ImageDraw.Draw(im)
    d.rectangle([452,350,478,632],fill=white)
    d.rectangle([652,300,678,582],fill=white)
    d.polygon([(452,350),(678,300),(678,366),(452,416)],fill=(255,194,51,255))
    return im.resize((size,size),Image.LANCZOS)
icon(1024).save(base+'/build/icon-preview.png')
icon(256).save(base+'/windows/runner/resources/app_icon.ico',sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
for name,px in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    icon(px).save(f'{base}/android/app/src/main/res/mipmap-{name}/ic_launcher.png')
icon(512).save(base+'/assets/brand/suona_icon.png')
