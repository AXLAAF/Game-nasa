from pathlib import Path
import random, subprocess, re, json
R=Path('/tmp/mz_trailer'); A=R/'assets'
random.seed(240)
head='<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">'
s=[head,'''<defs><radialGradient id="glow"><stop stop-color="#122c3e"/><stop offset="1" stop-color="#080c16"/></radialGradient></defs><rect width="1920" height="1080" fill="#080c16"/><ellipse cx="1480" cy="460" rx="1100" ry="850" fill="url(#glow)"/>''']
for i in range(230):
 x=random.uniform(0,1920);y=random.uniform(0,1080);r=random.choice([.6,.8,1,1.5]);opacity=random.uniform(.15,.6)
 s.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="#b3c9d3" opacity="{opacity:.2f}"/>')
for rx,ry,op in [(480,480,.12),(620,260,.28),(760,330,.10)]:
 s.append(f'<ellipse cx="1480" cy="470" rx="{rx}" ry="{ry}" transform="rotate(-28 1480 470)" fill="none" stroke="#8b9bb4" stroke-width="1" opacity="{op}"/>')
s+=['<path d="M0 980H1920 M80 0V1080" fill="none" stroke="#8b9bb4" opacity=".07"/>','</svg>']
(A/'space.svg').write_text(''.join(s));subprocess.run(['rsvg-convert',str(A/'space.svg'),'-o',str(A/'space.png')],check=True)
# Keep the original emblem geometry; remove only its opaque SVG background.
logo=Path('/home/alexykk/Game-nasa/docs/art/logo_orbita.svg').read_text()
logo=re.sub(r'<path[^>]+fill="rgb\(0%, 0%, 0%\)"[^>]*/>','',logo,count=1)
logo=logo.replace('width="800pt" height="800pt" viewBox="0 0 800 800"','width="1200" height="740" viewBox="110 210 600 370"')
(A/'logo_transparent.svg').write_text(logo)
subprocess.run(['rsvg-convert',str(A/'logo_transparent.svg'),'-o',str(A/'logo_orbita.png')],check=True)
# Transparent screen vignette, applied in the editor over gameplay.
(A/'vignette.svg').write_text(head+'<defs><radialGradient id="v"><stop offset=".55" stop-color="#080c16" stop-opacity="0"/><stop offset="1" stop-color="#080c16" stop-opacity=".55"/></radialGradient></defs><rect width="1920" height="1080" fill="url(#v)"/></svg>')
subprocess.run(['rsvg-convert',str(A/'vignette.svg'),'-o',str(A/'vignette.png')],check=True)
print('Prepared vector assets and transparent emblem')
