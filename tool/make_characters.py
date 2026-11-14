#!/usr/bin/env python3
"""Zeichnet Luna und Fuzz im Suona-Stil („Mix 2“: Chibi-Augen, Rock-Cartoon-Konturen)
und schreibt sie nach assets/characters/:

  luna.svg, fuzz.svg            ganze Figur (Seitenverhältnis 3:4)
  luna_face.svg, fuzz_face.svg  nur der Kopf, für runde Profilbilder

Aufbau jeder Figur: Haare hinten, Körper (mit Gitarre und Armen), Kopf.
Der Kopf wird um den Halsansatz vergrössert (HEAD_SCALE), der Körper zu den
Füssen hin verkleinert (BODY_SCALE). Konturen bleiben dabei gleich dick.
Später kommen hier die Shop-Teile dazu (Kleider, Frisuren, Gitarren als Ebenen).

Aufruf:  python3 tool/make_characters.py
"""
import os
import re
import sys

OUT = '#15121F'
W = 4.5
HEAD_SCALE = 1.16
BODY_SCALE = 0.95

class Svg:
    def __init__(s): s.defs=[]; s.body=[]; s.n=0
    def shape(s, tag, attrs, fill, shadow=None, shade=None, stroke=True):
        """tag+attrs = Form; shade = (x,y,w,h) Rechteck, das im Schatten liegt (in derselben Drehung)."""
        s.n+=1; cid=f'c{s.n}'
        a=' '.join(f'{k}="{v}"' for k,v in attrs.items())
        s.body.append(f'<{tag} {a} fill="{fill}"/>')
        if shadow and shade:
            # Schatten als Sichel: Schattenfarbe in der Form, darüber die Grundfarbe leicht verschoben.
            s.defs.append(f'<clipPath id="{cid}"><{tag} {a}/></clipPath>')
            dx,dy=(-9,-5) if len(shade)==4 else shade
            s.body.append(f'<g clip-path="url(#{cid})"><rect x="-50" y="-50" width="400" height="450" fill="{shadow}"/><{tag} {a} fill="{fill}" transform="translate({dx} {dy})"/></g>')
        if stroke:
            s.body.append(f'<{tag} {a} fill="none" stroke="{OUT}" stroke-width="{W}" stroke-linejoin="round"/>')
    def raw(s, t): s.body.append(t)
    def arm(s, d, skin, width=13):
        s.raw(f'<path d="{d}" fill="none" stroke="{OUT}" stroke-width="{width+2*W}" stroke-linecap="round"/>')
        s.raw(f'<path d="{d}" fill="none" stroke="{skin}" stroke-width="{width}" stroke-linecap="round"/>')
    def out(s): return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 240 320"><defs>'+''.join(s.defs)+'</defs>'+'\n'.join(s.body)+'</svg>'


def grp(svg_parts, transform, scale):
    # Konturen gleich dick halten, obwohl die Gruppe vergrössert oder verkleinert wird.
    body = '\n'.join(svg_parts)
    body = re.sub(r'stroke-width="([0-9.]+)"', lambda m: f'stroke-width="{float(m.group(1)) / scale:.2f}"', body)
    return f'<g transform="{transform}">{body}</g>'

def eyes(s, iris, lashes):
    for cx in (101, 139):
        s.raw(f'<ellipse cx="{cx}" cy="95" rx="10.5" ry="13.5" fill="{iris}" stroke="{OUT}" stroke-width="3"/>')
        s.raw(f'<ellipse cx="{cx}" cy="99" rx="6" ry="6.5" fill="{OUT}" opacity=".55"/>')
        s.raw(f'<circle cx="{cx+3.5}" cy="89" r="4" fill="#fff"/><circle cx="{cx-3.5}" cy="101" r="1.8" fill="#fff"/>')
    if lashes:
        s.raw(f'<path d="M89 88 l-6 -4 M151 88 l6 -4" stroke="{OUT}" stroke-width="3" stroke-linecap="round"/>')

def luna_parts():
    skin, skinS = '#F3BE98', '#D99A72'
    back = Svg(); body = Svg(); head = Svg()
    for x in (back, body, head): x.n = {'back': 0, 'body': 200, 'head': 400}[['back', 'body', 'head'][[back, body, head].index(x)]]
    back.shape('path', {'d': 'M74 72 C66 108 66 136 54 160 C76 164 90 154 96 142 L148 142 C154 154 168 164 190 160 C178 136 178 108 168 70 C160 40 136 28 116 30 C96 32 80 46 74 72 Z'}, '#3D2263', '#2A1747', (9, 0))
    back.raw('<path d="M170 92 C174 116 174 136 182 152" stroke="#7A4FC2" stroke-width="4" fill="none" stroke-linecap="round"/>')
    b = body
    for x in (98, 128):
        b.shape('rect', {'x': x, 'y': 220, 'width': 16, 'height': 52, 'rx': 4}, '#2A2340')
        for y in range(228, 270, 9):
            b.raw(f'<rect x="{x+2}" y="{y}" width="12" height="4" fill="#8E6CEF"/>')
    b.shape('path', {'d': 'M92 266 L116 266 L118 292 L84 292 Q84 280 92 278 Z'}, '#1E1A2E')
    b.shape('path', {'d': 'M126 266 L150 266 L156 278 Q164 280 164 292 L126 292 Z'}, '#1E1A2E')
    b.raw('<path d="M84 288 L118 288 M126 288 L164 288" stroke="#FFC233" stroke-width="3"/>')
    b.shape('path', {'d': 'M80 192 L160 192 L174 226 L66 226 Z'}, '#FF6B78', '#D94A5B', (-9, -5))
    b.raw(''.join(f'<rect x="{x}" y="215" width="6" height="2.5" fill="#15121F"/>' for x in range(74, 166, 11)))
    b.shape('path', {'d': 'M92 136 Q120 128 148 136 L154 196 L86 196 Z'}, '#8E6CEF', '#6A48C9', (-9, -5))
    b.raw('<path d="M110 162 l4 9 10 1 -8 6 3 10 -9 -5 -9 5 3 -10 -8 -6 10 -1 z" fill="#FFC233" stroke="#15121F" stroke-width="2.5" stroke-linejoin="round"/>')
    b.arm('M148 146 Q170 164 182 146', skin)
    g = Svg(); g.n = 300
    g.shape('rect', {'x': 128, 'y': 206, 'width': 86, 'height': 10, 'rx': 2}, '#B9773F')
    g.shape('path', {'d': 'M212 202 L236 196 L230 211 L236 226 L212 220 Z'}, '#F4F2FF')
    g.shape('path', {'d': 'M60 190 L122 198 L140 211 L122 224 L60 232 L78 211 Z'}, '#22B8A8', '#16897D', (-8, -6))
    g.raw('<rect x="100" y="203" width="9" height="16" rx="2" fill="#15121F"/><rect x="116" y="203" width="9" height="16" rx="2" fill="#15121F"/>')
    g.raw('<path d="M84 209 L232 209 M84 213 L232 213" stroke="#F4F2FF" stroke-width="1.2"/>')
    b.defs += g.defs
    b.raw('<g transform="rotate(-32 110 211)">' + '\n'.join(g.body) + '</g>')
    b.arm('M94 146 Q70 182 102 206', skin)
    b.shape('circle', {'cx': 104, 'cy': 206, 'r': 9}, skin)
    b.shape('circle', {'cx': 180, 'cy': 146, 'r': 8}, skin)
    b.raw('<rect x="88" y="190" width="14" height="9" rx="2" fill="#FFC233" stroke="#15121F" stroke-width="3" transform="rotate(30 95 194)"/>')
    b.shape('rect', {'x': 110, 'y': 122, 'width': 20, 'height': 18}, skin, skinS, (0, -8))
    h = head
    h.shape('ellipse', {'cx': 120, 'cy': 88, 'rx': 46, 'ry': 46}, skin, skinS, (-8, -5))
    h.shape('path', {'d': 'M72 92 C68 52 94 34 124 36 C154 38 174 58 170 90 C158 70 136 62 110 70 C96 76 84 84 72 92 Z'}, '#3D2263', '#2A1747', (-6, 4))
    h.raw('<path d="M156 44 l4 9 10 1 -8 6 3 10 -9 -5 -9 5 3 -10 -8 -6 10 -1 z" fill="#FFC233" stroke="#15121F" stroke-width="3" stroke-linejoin="round"/>')
    eyes(h, '#5B3F8C', True)
    h.raw('<path d="M89 78 Q100 72 111 77 M129 77 Q140 72 151 78" stroke="#15121F" stroke-width="4" stroke-linecap="round" fill="none"/>')
    h.raw('<ellipse cx="86" cy="112" rx="8" ry="5" fill="#FF8A9A" opacity=".6"/><ellipse cx="154" cy="112" rx="8" ry="5" fill="#FF8A9A" opacity=".6"/>')
    h.raw('<path d="M108 114 Q121 128 134 113 Q121 118 108 114 Z" fill="#7E1F2E" stroke="#15121F" stroke-width="3" stroke-linejoin="round"/>')
    h.raw('<path d="M112 115 L130 114.5 L128 118 L114 118.5 Z" fill="#fff"/>')
    return back, body, head

def fuzz_parts():
    skin, skinS = '#F4C7A1', '#D9A27A'
    back = Svg(); body = Svg(); head = Svg()
    back.n, body.n, head.n = 500, 600, 700
    b = body
    b.shape('path', {'d': 'M98 222 L116 222 L110 278 L92 278 Z'}, '#3557A8', '#24407F', (-6, 0))
    b.shape('path', {'d': 'M124 222 L142 222 L150 278 L132 278 Z'}, '#3557A8', '#24407F', (-6, 0))
    b.raw('<path d="M96 250 l10 2 M100 256 l8 -1" stroke="#9DB4EA" stroke-width="2.5" stroke-linecap="round"/>')
    b.shape('path', {'d': 'M88 274 L114 274 L118 292 L78 292 Q78 280 88 278 Z'}, '#F4F2FF', '#C9C6E0', (-6, -4))
    b.shape('path', {'d': 'M128 274 L152 274 Q162 278 164 292 L126 292 Z'}, '#F4F2FF', '#C9C6E0', (-6, -4))
    b.raw('<path d="M78 288 L118 288 M126 288 L164 288" stroke="#E23D3D" stroke-width="3.5"/>')
    b.shape('path', {'d': 'M88 136 Q120 126 152 136 L158 226 L82 226 Z'}, '#23A89C', '#167F75', (-9, -5))
    b.raw('<path d="M128 150 L114 178 L124 178 L116 204 L138 170 L128 170 L136 150 Z" fill="#FFC233" stroke="#15121F" stroke-width="3" stroke-linejoin="round"/>')
    b.arm('M150 146 Q174 164 186 144', skin)
    g = Svg(); g.n = 800
    g.shape('rect', {'x': 130, 'y': 206, 'width': 86, 'height': 10, 'rx': 2}, '#B9773F')
    g.shape('rect', {'x': 212, 'y': 200, 'width': 24, 'height': 22, 'rx': 5}, '#15121F')
    g.shape('path', {'d': 'M64 211 C64 188 86 184 100 192 C108 186 120 184 132 192 L140 196 L132 202 C140 206 140 216 132 220 L140 226 L132 230 C120 238 108 236 100 230 C86 238 64 234 64 211 Z'}, '#E23D3D', '#B52530', (-8, -6))
    g.raw('<path d="M74 214 C84 222 100 226 112 220 L106 208 C96 214 84 214 74 214 Z" fill="#F4F2FF" stroke="#15121F" stroke-width="2.5"/>')
    g.raw('<rect x="100" y="203" width="9" height="16" rx="2" fill="#15121F"/><rect x="116" y="203" width="9" height="16" rx="2" fill="#15121F"/>')
    g.raw('<path d="M84 209 L232 209 M84 213 L232 213" stroke="#F4F2FF" stroke-width="1.2"/>')
    b.defs += g.defs
    b.raw('<g transform="rotate(-34 110 211)">' + '\n'.join(g.body) + '</g>')
    b.arm('M92 146 Q66 182 100 206', skin)
    b.shape('circle', {'cx': 102, 'cy': 206, 'r': 9}, skin)
    b.shape('circle', {'cx': 184, 'cy': 144, 'r': 8}, skin)
    b.raw('<rect x="84" y="186" width="16" height="10" rx="2" fill="#15121F" transform="rotate(35 92 191)"/>')
    b.shape('rect', {'x': 110, 'y': 124, 'width': 20, 'height': 16}, skin, skinS, (0, -8))
    h = head
    h.shape('ellipse', {'cx': 74, 'cy': 96, 'rx': 9, 'ry': 11}, skin)
    h.shape('ellipse', {'cx': 166, 'cy': 96, 'rx': 9, 'ry': 11}, skin, skinS, (-4, 0))
    h.shape('ellipse', {'cx': 120, 'cy': 90, 'rx': 46, 'ry': 46}, skin, skinS, (-8, -5))
    h.shape('path', {'d': 'M76 84 C72 62 78 50 88 42 L74 18 L100 26 L102 2 L120 22 L136 -2 L142 22 L164 6 L162 30 L186 24 L172 48 C180 60 170 68 166 84 L160 70 L150 78 L144 62 L132 74 L124 58 L114 72 L104 60 L96 72 L88 64 Z'}, '#4A2A16', '#33190A', (-8, 4))
    h.raw('<path d="M106 14 L112 36 M138 8 L138 32 M162 20 L154 40" stroke="#7A4A2A" stroke-width="3" stroke-linecap="round"/>')
    eyes(h, '#3A2416', False)
    h.raw('<path d="M88 78 L112 82 M128 81 Q140 71 152 79" stroke="#15121F" stroke-width="5" stroke-linecap="round" fill="none"/>')
    h.raw('<ellipse cx="85" cy="113" rx="8" ry="5" fill="#FF8A9A" opacity=".5"/><ellipse cx="155" cy="113" rx="8" ry="5" fill="#FF8A9A" opacity=".5"/>')
    h.raw('<g fill="#C98E62"><circle cx="84" cy="108" r="1.3"/><circle cx="89" cy="106" r="1.3"/><circle cx="156" cy="108" r="1.3"/><circle cx="151" cy="106" r="1.3"/></g>')
    h.raw('<path d="M104 114 Q124 132 140 111 Q122 119 104 114 Z" fill="#7E1F2E" stroke="#15121F" stroke-width="3" stroke-linejoin="round"/>')
    h.raw('<path d="M108 115 L136 113 L133 118 L111 119 Z" fill="#fff"/>')
    return back, body, head


def compose(parts, head_scale, body_scale, neck_y):
    back, body, head = parts
    # Körper zu den Füssen (y 292) hin skalieren, dann den Kopf auf den neuen Hals setzen.
    new_neck = 292 - (292 - neck_y) * body_scale
    body_t = f'translate(120 292) scale({body_scale}) translate(-120 -292)'
    head_t = f'translate(120 {new_neck}) scale({head_scale}) translate(-120 -{neck_y})'
    top = new_neck - (neck_y - (-4)) * head_scale
    vb_top = min(-4, top - 6)
    height = 300 - vb_top
    width = height * 0.75
    vb_left = 120 - width / 2
    defs = back.defs + body.defs + head.defs
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb_left:.1f} {vb_top:.1f} {width:.1f} {height:.1f}"><defs>' + ''.join(defs) + '</defs>'
            + grp(back.body, head_t, head_scale) + grp(body.body, body_t, body_scale) + grp(head.body, head_t, head_scale) + '</svg>')


# Gemeinsamer Ausschnitt für beide ganzen Figuren: gleich gross dargestellt,
# Fuzz' Haarspitzen oben und die Gitarrenköpfe rechts haben Platz.
FULL_BOX = '22 -20 240 320'

# Ausschnitte für die runden Profilbilder (in den Koordinaten der fertigen Figur)
FACE_BOX = {'luna': '58 24 124 124', 'fuzz': '56 22 128 128'}


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, 'assets', 'characters')
    for name, fn, neck in (('luna', luna_parts, 132), ('fuzz', fuzz_parts, 134)):
        full = compose(fn(), HEAD_SCALE, BODY_SCALE, neck)
        full = re.sub(r'viewBox="[^"]+"', f'viewBox="{FULL_BOX}"', full, count=1)
        open(os.path.join(out, f'{name}.svg'), 'w').write(full)
        face = re.sub(r'viewBox="[^"]+"', f'viewBox="{FACE_BOX[name]}"', full, count=1)
        open(os.path.join(out, f'{name}_face.svg'), 'w').write(face)


if __name__ == '__main__':
    main()
