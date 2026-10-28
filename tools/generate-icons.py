"""Render the supplied original wordmark onto opaque native launcher canvases."""
from pathlib import Path
import subprocess,json
r=Path(__file__).resolve().parents[1]
eps=r/'shared/logos/crisis_logo_midnightblue_rgb.eps'
icon=r/'ios/CRISIS/Resources/Assets.xcassets/AppIcon.appiconset';icon.mkdir(parents=True,exist_ok=True)
outputs=[(1024,icon/'AppIcon.png')]
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
 p=r/f'android/app/src/main/res/mipmap-{density}/ic_launcher.png';p.parent.mkdir(parents=True,exist_ok=True);outputs.append((size,p))
for size,p in outputs:
 subprocess.run(['gs','-dSAFER','-dBATCH','-dNOPAUSE','-sDEVICE='+('png16m' if size==1024 else 'pngalpha'),f'-r{size/1024*72}',f'-g{size}x{size}','-sOutputFile='+str(p),'-c','<</PageSize [1024 1024]>> setpagedevice 1 1 1 setrgbcolor '+('clippath fill' if size==1024 else 'newpath 512 512 500 0 360 arc closepath fill')+' 143 408 translate 6 6 scale','-f',str(eps)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
(icon/'Contents.json').write_text(json.dumps({'images':[{'filename':'AppIcon.png','idiom':'universal','platform':'ios','size':'1024x1024'}],'info':{'author':'xcode','version':1}},indent=2)+'\n')
(icon.parent/'Contents.json').write_text('{"info":{"author":"xcode","version":1}}\n')
