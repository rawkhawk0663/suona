#!/usr/bin/env python3
"""Zeichnet Luna und Fuzz im Suona-Stil („Mix 2“: Chibi-Augen, Rock-Cartoon-Konturen).

Ausgabe nach assets/characters/:

  luna.svg, fuzz.svg                 fertige Figur mit Grundfarben (Vorschau, Download-Bild)
  luna_template.svg, fuzz_template.svg
                                     Vorlage für die App: Farben als Platzhalter
                                     ({{skin}}, {{hair}} …) und Stellen für Shop-Teile
                                     (<!--slot:hat--> …). Die App setzt beides zur Laufzeit ein.
  items.json                         Shop-Teile als SVG-Stücke, pro Figur

Aufbau jeder Figur: Haare hinten, Körper (mit Gitarre und Armen), Kopf.
Der Kopf wird um den Halsansatz vergrössert (HEAD_SCALE), der Körper zu den
Füssen hin verkleinert (BODY_SCALE). Konturen bleiben dabei gleich dick.
Shop-Teile werden in diese Gruppen eingesetzt, ihre Konturen deshalb gleich
umgerechnet.

Aufruf:  python3 tool/make_characters.py
"""
import json
import os
import re
import sys

OUT = '#15121F'
W = 4.5
HEAD_SCALE = 1.16
BODY_SCALE = 0.95
NECK = {'luna': 132, 'fuzz': 134}
GUITAR_ROTATION = {'luna': -32, 'fuzz': -34}

# Gemeinsamer Ausschnitt für beide ganzen Figuren: gleich gross dargestellt,
# Fuzz' Haarspitzen oben, Kopfbedeckungen und die Gitarrenköpfe rechts haben Platz.
FULL_BOX = '16 -42 256 342'
# Ausschnitte für die runden Profilbilder (in den Koordinaten der fertigen Figur)
FACE_BOX = {'luna': '58 24 124 124', 'fuzz': '56 22 128 128'}

# Grundfarben (die App kennt dieselben Werte als Standard-Look)
DEFAULTS = {
    'luna': {'skin': '#F3BE98', 'skinS': '#D99A72', 'hair': '#3D2263', 'hairS': '#2A1747', 'hairL': '#7A4FC2',
             'eyes': '#5B3F8C', 'shirt': '#8E6CEF', 'shirtS': '#6A48C9'},
    'fuzz': {'skin': '#F4C7A1', 'skinS': '#D9A27A', 'hair': '#4A2A16', 'hairS': '#33190A', 'hairL': '#7A4A2A',
             'eyes': '#3A2416', 'shirt': '#23A89C', 'shirtS': '#167F75'},
}
DEFAULT_GUITAR = {'luna': 'g_pointy', 'fuzz': 'g_double'}

T = {k: '{{' + k + '}}' for k in DEFAULTS['luna']}


class Svg:
    def __init__(s, prefix='c'):
        s.defs = []
        s.body = []
        s.n = 0
        s.prefix = prefix

    def shape(s, tag, attrs, fill, shadow=None, shade=None, stroke=True):
        """Form mit Füllung, Schatten als Sichel (shade = Verschiebung) und Kontur."""
        s.n += 1
        cid = f'{s.prefix}{s.n}'
        a = ' '.join(f'{k}="{v}"' for k, v in attrs.items())
        s.body.append(f'<{tag} {a} fill="{fill}"/>')
        if shadow and shade:
            s.defs.append(f'<clipPath id="{cid}"><{tag} {a}/></clipPath>')
            dx, dy = shade
            s.body.append(f'<g clip-path="url(#{cid})"><rect x="-50" y="-50" width="400" height="450" fill="{shadow}"/>'
                          f'<{tag} {a} fill="{fill}" transform="translate({dx} {dy})"/></g>')
        if stroke:
            s.body.append(f'<{tag} {a} fill="none" stroke="{OUT}" stroke-width="{W}" stroke-linejoin="round"/>')

    def raw(s, t):
        s.body.append(t)

    def arm(s, d, skin, width=13):
        s.raw(f'<path d="{d}" fill="none" stroke="{OUT}" stroke-width="{width + 2 * W}" stroke-linecap="round"/>')
        s.raw(f'<path d="{d}" fill="none" stroke="{skin}" stroke-width="{width}" stroke-linecap="round"/>')


def scaled(parts, scale):
    # Konturen gleich dick halten, obwohl die Gruppe vergrössert oder verkleinert wird.
    body = '\n'.join(parts)
    return re.sub(r'stroke-width="([0-9.]+)"', lambda m: f'stroke-width="{float(m.group(1)) / scale:.2f}"', body)


def eyes(s, iris, lashes):
    for cx in (101, 139):
        s.raw(f'<ellipse cx="{cx}" cy="95" rx="10.5" ry="13.5" fill="{iris}" stroke="{OUT}" stroke-width="3"/>')
        s.raw(f'<ellipse cx="{cx}" cy="99" rx="6" ry="6.5" fill="{OUT}" opacity=".55"/>')
        s.raw(f'<circle cx="{cx + 3.5}" cy="89" r="4" fill="#fff"/><circle cx="{cx - 3.5}" cy="101" r="1.8" fill="#fff"/>')
    if lashes:
        s.raw(f'<path d="M89 88 l-6 -4 M151 88 l6 -4" stroke="{OUT}" stroke-width="3" stroke-linecap="round"/>')


# ---------------------------------------------------------------- Figuren

def luna_parts():
    back, body, head = Svg('lb'), Svg('ly'), Svg('lh')
    back.shape('path', {'d': 'M74 72 C66 108 66 136 54 160 C76 164 90 154 96 142 L148 142 C154 154 168 164 190 160 C178 136 178 108 168 70 C160 40 136 28 116 30 C96 32 80 46 74 72 Z'}, T['hair'], T['hairS'], (9, 0))
    back.raw(f'<path d="M170 92 C174 116 174 136 182 152" stroke="{T["hairL"]}" stroke-width="4" fill="none" stroke-linecap="round"/>')
    b = body
    for x in (98, 128):
        b.shape('rect', {'x': x, 'y': 220, 'width': 16, 'height': 52, 'rx': 4}, '#2A2340')
        for y in range(228, 270, 9):
            b.raw(f'<rect x="{x + 2}" y="{y}" width="12" height="4" fill="#8E6CEF"/>')
    b.shape('path', {'d': 'M92 266 L116 266 L118 292 L84 292 Q84 280 92 278 Z'}, '#1E1A2E')
    b.shape('path', {'d': 'M126 266 L150 266 L156 278 Q164 280 164 292 L126 292 Z'}, '#1E1A2E')
    b.raw('<path d="M84 288 L118 288 M126 288 L164 288" stroke="#FFC233" stroke-width="3"/>')
    b.shape('path', {'d': 'M80 192 L160 192 L174 226 L66 226 Z'}, '#FF6B78', '#D94A5B', (-9, -5))
    b.raw(''.join(f'<rect x="{x}" y="215" width="6" height="2.5" fill="#15121F"/>' for x in range(74, 166, 11)))
    b.shape('path', {'d': 'M92 136 Q120 128 148 136 L154 196 L86 196 Z'}, T['shirt'], T['shirtS'], (-9, -5))
    b.raw('<path d="M110 162 l4 9 10 1 -8 6 3 10 -9 -5 -9 5 3 -10 -8 -6 10 -1 z" fill="#FFC233" stroke="#15121F" stroke-width="2.5" stroke-linejoin="round"/>')
    b.raw('<!--slot:vest--><!--slot:neck-->')
    b.arm('M148 146 Q170 164 182 146', T['skin'])
    b.raw(f'<g transform="rotate({GUITAR_ROTATION["luna"]} 110 211)"><!--slot:guitar--></g>')
    b.arm('M94 146 Q70 182 102 206', T['skin'])
    b.shape('circle', {'cx': 104, 'cy': 206, 'r': 9}, T['skin'])
    b.shape('circle', {'cx': 180, 'cy': 146, 'r': 8}, T['skin'])
    b.raw('<rect x="88" y="190" width="14" height="9" rx="2" fill="#FFC233" stroke="#15121F" stroke-width="3" transform="rotate(30 95 194)"/>')
    b.shape('rect', {'x': 110, 'y': 122, 'width': 20, 'height': 18}, T['skin'], T['skinS'], (0, -8))
    h = head
    h.shape('ellipse', {'cx': 120, 'cy': 88, 'rx': 46, 'ry': 46}, T['skin'], T['skinS'], (-8, -5))
    h.shape('path', {'d': 'M72 92 C68 52 94 34 124 36 C154 38 174 58 170 90 C158 70 136 62 110 70 C96 76 84 84 72 92 Z'}, T['hair'], T['hairS'], (-6, 4))
    h.raw('<!--slot:hairclip--><path d="M156 44 l4 9 10 1 -8 6 3 10 -9 -5 -9 5 3 -10 -8 -6 10 -1 z" fill="#FFC233" stroke="#15121F" stroke-width="3" stroke-linejoin="round"/><!--/slot:hairclip-->')
    eyes(h, T['eyes'], True)
    h.raw('<path d="M89 78 Q100 72 111 77 M129 77 Q140 72 151 78" stroke="#15121F" stroke-width="4" stroke-linecap="round" fill="none"/>')
    h.raw('<ellipse cx="86" cy="112" rx="8" ry="5" fill="#FF8A9A" opacity=".6"/><ellipse cx="154" cy="112" rx="8" ry="5" fill="#FF8A9A" opacity=".6"/>')
    h.raw('<path d="M108 114 Q121 128 134 113 Q121 118 108 114 Z" fill="#7E1F2E" stroke="#15121F" stroke-width="3" stroke-linejoin="round"/>')
    h.raw('<path d="M112 115 L130 114.5 L128 118 L114 118.5 Z" fill="#fff"/>')
    h.raw('<!--slot:glasses--><!--slot:hat-->')
    return back, body, head


def fuzz_parts():
    back, body, head = Svg('fb'), Svg('fy'), Svg('fh')
    b = body
    b.shape('path', {'d': 'M98 222 L116 222 L110 278 L92 278 Z'}, '#3557A8', '#24407F', (-6, 0))
    b.shape('path', {'d': 'M124 222 L142 222 L150 278 L132 278 Z'}, '#3557A8', '#24407F', (-6, 0))
    b.raw('<path d="M96 250 l10 2 M100 256 l8 -1" stroke="#9DB4EA" stroke-width="2.5" stroke-linecap="round"/>')
    b.shape('path', {'d': 'M88 274 L114 274 L118 292 L78 292 Q78 280 88 278 Z'}, '#F4F2FF', '#C9C6E0', (-6, -4))
    b.shape('path', {'d': 'M128 274 L152 274 Q162 278 164 292 L126 292 Z'}, '#F4F2FF', '#C9C6E0', (-6, -4))
    b.raw('<path d="M78 288 L118 288 M126 288 L164 288" stroke="#E23D3D" stroke-width="3.5"/>')
    b.shape('path', {'d': 'M88 136 Q120 126 152 136 L158 226 L82 226 Z'}, T['shirt'], T['shirtS'], (-9, -5))
    b.raw('<path d="M128 150 L114 178 L124 178 L116 204 L138 170 L128 170 L136 150 Z" fill="#FFC233" stroke="#15121F" stroke-width="3" stroke-linejoin="round"/>')
    b.raw('<!--slot:vest--><!--slot:neck-->')
    b.arm('M150 146 Q174 164 186 144', T['skin'])
    b.raw(f'<g transform="rotate({GUITAR_ROTATION["fuzz"]} 110 211)"><!--slot:guitar--></g>')
    b.arm('M92 146 Q66 182 100 206', T['skin'])
    b.shape('circle', {'cx': 102, 'cy': 206, 'r': 9}, T['skin'])
    b.shape('circle', {'cx': 184, 'cy': 144, 'r': 8}, T['skin'])
    b.raw('<rect x="84" y="186" width="16" height="10" rx="2" fill="#15121F" transform="rotate(35 92 191)"/>')
    b.shape('rect', {'x': 110, 'y': 124, 'width': 20, 'height': 16}, T['skin'], T['skinS'], (0, -8))
    h = head
    h.shape('ellipse', {'cx': 74, 'cy': 96, 'rx': 9, 'ry': 11}, T['skin'])
    h.shape('ellipse', {'cx': 166, 'cy': 96, 'rx': 9, 'ry': 11}, T['skin'], T['skinS'], (-4, 0))
    h.shape('ellipse', {'cx': 120, 'cy': 90, 'rx': 46, 'ry': 46}, T['skin'], T['skinS'], (-8, -5))
    h.shape('path', {'d': 'M76 84 C72 62 78 50 88 42 L74 18 L100 26 L102 2 L120 22 L136 -2 L142 22 L164 6 L162 30 L186 24 L172 48 C180 60 170 68 166 84 L160 70 L150 78 L144 62 L132 74 L124 58 L114 72 L104 60 L96 72 L88 64 Z'}, T['hair'], T['hairS'], (-8, 4))
    h.raw(f'<path d="M106 14 L112 36 M138 8 L138 32 M162 20 L154 40" stroke="{T["hairL"]}" stroke-width="3" stroke-linecap="round"/>')
    eyes(h, T['eyes'], False)
    h.raw('<path d="M88 78 L112 82 M128 81 Q140 71 152 79" stroke="#15121F" stroke-width="5" stroke-linecap="round" fill="none"/>')
    h.raw('<ellipse cx="85" cy="113" rx="8" ry="5" fill="#FF8A9A" opacity=".5"/><ellipse cx="155" cy="113" rx="8" ry="5" fill="#FF8A9A" opacity=".5"/>')
    h.raw('<g fill="#C98E62"><circle cx="84" cy="108" r="1.3"/><circle cx="89" cy="106" r="1.3"/><circle cx="156" cy="108" r="1.3"/><circle cx="151" cy="106" r="1.3"/></g>')
    h.raw('<path d="M104 114 Q124 132 140 111 Q122 119 104 114 Z" fill="#7E1F2E" stroke="#15121F" stroke-width="3" stroke-linejoin="round"/>')
    h.raw('<path d="M108 115 L136 113 L133 118 L111 119 Z" fill="#fff"/>')
    h.raw('<!--slot:glasses--><!--slot:hat-->')
    return back, body, head


# ---------------------------------------------------------------- Gitarren
# Alle Gitarren in denselben Koordinaten (unverdreht, Korpus um x 60–140,
# Hals bis x 214, Kopfplatte bis x 236). Die Figur dreht sie selbst.

def neck(s, head_fill='#F4F2FF', pointy=False):
    s.shape('rect', {'x': 128, 'y': 206, 'width': 86, 'height': 10, 'rx': 2}, '#B9773F')
    s.raw(''.join(f'<rect x="{x}" y="206" width="1.4" height="10" fill="#E8D9B8"/>' for x in (146, 162, 176, 189, 200, 210)))
    if pointy:
        s.shape('path', {'d': 'M212 202 L236 196 L230 211 L236 226 L212 220 Z'}, head_fill)
    else:
        s.shape('rect', {'x': 212, 'y': 200, 'width': 24, 'height': 22, 'rx': 5}, head_fill)


def strings(s):
    s.raw('<path d="M84 209 L232 209 M84 213 L232 213" stroke="#F4F2FF" stroke-width="1.2"/>')


def pickups(s):
    s.raw('<rect x="100" y="203" width="9" height="16" rx="2" fill="#15121F"/><rect x="116" y="203" width="9" height="16" rx="2" fill="#15121F"/>')


POINTY = 'M60 190 L122 198 L140 211 L122 224 L60 232 L78 211 Z'
DOUBLE = 'M64 211 C64 188 86 184 100 192 C108 186 120 184 132 192 L140 196 L132 202 C140 206 140 216 132 220 L140 226 L132 230 C120 238 108 236 100 230 C86 238 64 234 64 211 Z'


def guitar_pointy(prefix, color, shade, head='#F4F2FF'):
    s = Svg(prefix)
    neck(s, head, pointy=True)
    s.shape('path', {'d': POINTY}, color, shade, (-8, -6))
    pickups(s)
    strings(s)
    return s


def guitar_double(prefix, color, shade, guard='#F4F2FF', head='#15121F'):
    s = Svg(prefix)
    neck(s, head)
    s.shape('path', {'d': DOUBLE}, color, shade, (-8, -6))
    s.raw(f'<path d="M74 214 C84 222 100 226 112 220 L106 208 C96 214 84 214 74 214 Z" fill="{guard}" stroke="#15121F" stroke-width="2.5"/>')
    pickups(s)
    strings(s)
    return s


def guitar_acoustic(prefix):
    s = Svg(prefix)
    neck(s, '#7A4A2A')
    s.shape('path', {'d': 'M58 211 C58 186 82 182 96 194 C104 188 120 186 130 196 C142 204 142 218 130 226 C120 236 104 234 96 228 C82 240 58 236 58 211 Z'}, '#E0A863', '#B57B3A', (-8, -6))
    s.raw('<circle cx="104" cy="211" r="9" fill="#2B1A10" stroke="#15121F" stroke-width="2.5"/>')
    s.raw('<circle cx="104" cy="211" r="12.5" fill="none" stroke="#7A4A2A" stroke-width="2"/>')
    s.raw('<rect x="72" y="204" width="6" height="14" rx="2" fill="#2B1A10"/>')
    strings(s)
    return s


def guitar_star(prefix):
    s = Svg(prefix)
    neck(s, '#FFC233', pointy=True)
    import math
    cx, cy, ro, ri = 98, 211, 40, 19
    pts = []
    for i in range(10):
        r = ro if i % 2 == 0 else ri
        a = math.radians(-90 + i * 36 + 18)
        pts.append(f'{cx + r * math.cos(a):.1f} {cy + r * math.sin(a):.1f}')
    s.shape('path', {'d': 'M' + ' L'.join(pts) + ' Z'}, '#8E6CEF', '#6A48C9', (-8, -6))
    s.raw('<circle cx="98" cy="211" r="5" fill="#FFC233" stroke="#15121F" stroke-width="2"/>')
    pickups(s)
    strings(s)
    return s


GUITARS = {
    'g_pointy': lambda: guitar_pointy('gp', '#22B8A8', '#16897D'),
    'g_double': lambda: guitar_double('gd', '#E23D3D', '#B52530'),
    'g_pointy_gold': lambda: guitar_pointy('gpg', '#FFC233', '#C8901A', head='#15121F'),
    'g_double_black': lambda: guitar_double('gdb', '#2B2340', '#1A1428', guard='#E23D3D', head='#F4F2FF'),
    'g_acoustic': lambda: guitar_acoustic('ga'),
    'g_star': lambda: guitar_star('gs'),
}


# ---------------------------------------------------------------- Kopfteile
# Koordinaten des Kopfes (vor der Vergrösserung). Luna: Kopf um (120, 88),
# Fuzz: um (120, 90), seine Haarspitzen reichen bis y = -2.

HEAD_Y = {'luna': 0, 'fuzz': -8}   # Fuzz' Kopfteile sitzen etwas höher (Frisur)


def beanie(prefix, who):
    s = Svg(prefix)
    dy = HEAD_Y[who] - (14 if who == 'fuzz' else 0)
    s.shape('path', {'d': f'M70 {66 + dy} C66 {12 + dy} 174 {12 + dy} 170 {66 + dy} Z'}, '#E23D3D', '#B52530', (-7, 5))
    s.shape('path', {'d': f'M64 {58 + dy} Q120 {46 + dy} 176 {58 + dy} L176 {74 + dy} Q120 {62 + dy} 64 {74 + dy} Z'}, '#B52530')
    s.raw(''.join(f'<rect x="{x}" y="{58 + dy}" width="3" height="12" rx="1.5" fill="#8A1C25"/>' for x in range(74, 170, 10)))
    s.shape('circle', {'cx': 120, 'cy': 14 + dy, 'r': 10}, '#F4F2FF', '#C9C6E0', (-3, -3))
    return s


def bandana(prefix, who):
    s = Svg(prefix)
    y = 60 if who == 'luna' else 58
    s.shape('path', {'d': f'M70 {y + 6} Q120 {y - 10} 170 {y + 6} L170 {y + 18} Q120 {y + 2} 70 {y + 18} Z'}, '#E23D3D', '#B52530', (0, 4))
    s.raw(''.join(f'<circle cx="{x}" cy="{y + 7 - (2 if 100 < x < 140 else 0)}" r="2" fill="#F4F2FF"/>' for x in range(82, 162, 14)))
    s.shape('path', {'d': f'M168 {y + 8} L190 {y} L186 {y + 14} L196 {y + 24} L172 {y + 20} Z'}, '#E23D3D', '#B52530', (-3, 2))
    return s


def headphones(prefix, who):
    s = Svg(prefix)
    top = 18 if who == 'luna' else 4
    s.raw(f'<path d="M70 98 C64 {top} 176 {top} 170 98" fill="none" stroke="{OUT}" stroke-width="13" stroke-linecap="round"/>')
    s.raw(f'<path d="M70 98 C64 {top} 176 {top} 170 98" fill="none" stroke="#2B2340" stroke-width="6" stroke-linecap="round"/>')
    for cx in (68, 172):
        s.shape('rect', {'x': cx - 11, 'y': 84, 'width': 22, 'height': 32, 'rx': 9}, '#22B8A8', '#16897D', (-3, -3))
        s.raw(f'<rect x="{cx - 4}" y="92" width="8" height="16" rx="3" fill="#F4F2FF"/>')
    return s


def crown(prefix, who):
    s = Svg(prefix)
    y = 24 if who == 'luna' else -22
    s.shape('path', {'d': f'M92 {y + 26} L88 {y} L104 {y + 12} L120 {y - 6} L136 {y + 12} L152 {y} L148 {y + 26} Z'}, '#FFC233', '#C8901A', (-5, 3))
    for cx, cy, col in ((104, y + 19, '#E23D3D'), (120, y + 17, '#22B8A8'), (136, y + 19, '#8E6CEF')):
        s.raw(f'<circle cx="{cx}" cy="{cy}" r="3.2" fill="{col}" stroke="{OUT}" stroke-width="1.8"/>')
    return s


def sunglasses(prefix, who):
    s = Svg(prefix)
    for cx in (101, 139):
        s.shape('rect', {'x': cx - 16, 'y': 85, 'width': 32, 'height': 22, 'rx': 9}, '#15121F')
        s.raw(f'<path d="M{cx - 9} 90 L{cx - 2} 90" stroke="#6E6A8F" stroke-width="3" stroke-linecap="round"/>')
    s.raw(f'<path d="M117 92 Q120 89 123 92" stroke="{OUT}" stroke-width="4" fill="none"/>')
    s.raw(f'<path d="M85 92 L72 88 M155 92 L168 88" stroke="{OUT}" stroke-width="4" stroke-linecap="round"/>')
    return s


def starglasses(prefix, who):
    import math
    s = Svg(prefix)
    for cx in (101, 139):
        pts = []
        for i in range(10):
            r = 19 if i % 2 == 0 else 10
            a = math.radians(-90 + i * 36)
            pts.append(f'{cx + r * math.cos(a):.1f} {95 + r * math.sin(a):.1f}')
        s.raw(f'<path d="M{" L".join(pts)} Z" fill="#FF7AB2" fill-opacity=".38" stroke="#E0569A" stroke-width="4.5" stroke-linejoin="round"/>')
    s.raw('<path d="M117 93 Q120 90 123 93" stroke="#E0569A" stroke-width="4" fill="none"/>')
    return s


# ---------------------------------------------------------------- Westen

VEST_PANELS = {
    'luna': ('M92 136 Q102 132 110 132 L104 196 L86 196 Z', 'M148 136 Q138 132 130 132 L136 196 L154 196 Z', 196),
    'fuzz': ('M88 136 Q100 131 110 131 L106 226 L82 226 Z', 'M152 136 Q140 131 130 131 L134 226 L158 226 Z', 226),
}


def vest(prefix, who, color, shade, studs):
    s = Svg(prefix)
    left, right, bottom = VEST_PANELS[who]
    s.shape('path', {'d': left}, color, shade, (5, -4))
    s.shape('path', {'d': right}, color, shade, (-5, -4))
    if studs:
        for y in range(142, bottom - 6, 12):
            s.raw(f'<circle cx="{103 - (y - 132) * 0.08:.1f}" cy="{y}" r="1.9" fill="#C9CAD8"/>')
            s.raw(f'<circle cx="{137 + (y - 132) * 0.08:.1f}" cy="{y}" r="1.9" fill="#C9CAD8"/>')
    else:
        s.raw(''.join(f'<rect x="{100 - (y - 132) * 0.08:.1f}" y="{y}" width="1.6" height="5" fill="#F2C94C"/>' for y in range(140, bottom - 6, 9)))
        s.raw(''.join(f'<rect x="{139 + (y - 132) * 0.08:.1f}" y="{y}" width="1.6" height="5" fill="#F2C94C"/>' for y in range(140, bottom - 6, 9)))
        s.raw(f'<rect x="139" y="{bottom - 40}" width="10" height="9" rx="1.5" fill="none" stroke="#F2C94C" stroke-width="1.5"/>')
    return s


HEAD_ITEMS = {
    'hat_beanie': ('hat', beanie),
    'hat_bandana': ('hat', bandana),
    'hat_headphones': ('hat', headphones),
    'hat_crown': ('hat', crown),
    'glasses_sun': ('glasses', sunglasses),
    'glasses_star': ('glasses', starglasses),
}
BODY_ITEMS = {
    'vest_leather': ('vest', lambda p, w: vest(p, w, '#2B2340', '#1A1428', True)),
    'vest_jeans': ('vest', lambda p, w: vest(p, w, '#4A6FD8', '#36539F', False)),
}


# ================================================================ Erweiterung: mehr Teile
# (Kopfteile in Kopf-Koordinaten, Halsschmuck und Westen in Körper-Koordinaten,
# Amps in den Koordinaten der fertigen Figur rechts neben den Füssen.)

def clipped(s, d, inner, cid):
    """Muster nur innerhalb einer Form malen (z. B. Blumen auf einer Weste)."""
    s.defs.append(f'<clipPath id="{cid}"><path d="{d}"/></clipPath>')
    s.raw(f'<g clip-path="url(#{cid})">{inner}</g>')


def flower(cx, cy, r, petal, center='#FFC233', sw=1.6):
    import math
    out = []
    for i in range(5):
        a = math.radians(i * 72 - 90)
        out.append(f'<circle cx="{cx + r * math.cos(a):.1f}" cy="{cy + r * math.sin(a):.1f}" r="{r * 0.72:.1f}" fill="{petal}" stroke="{OUT}" stroke-width="{sw}"/>')
    out.append(f'<circle cx="{cx}" cy="{cy}" r="{r * 0.55:.1f}" fill="{center}" stroke="{OUT}" stroke-width="{sw}"/>')
    return ''.join(out)


# Unterkante (Krempe) grosser Hüte: Fuzz trägt sie über seinen Stacheln.
BRIM = {'luna': 62, 'fuzz': 40}


def cap(prefix, who):
    s = Svg(prefix)
    b = BRIM[who] + 2
    s.shape('path', {'d': f'M72 {b} C70 {b - 50} 170 {b - 50} 168 {b} Z'}, '#2F6FCB', '#1F4E99', (-7, 5))
    s.shape('path', {'d': f'M150 {b - 8} C176 {b - 14} 200 {b - 8} 206 {b + 4} C186 {b + 8} 166 {b + 6} 148 {b + 4} Z'}, '#1F4E99')
    s.raw(f'<path d="M66 {b} Q120 {b - 10} 174 {b}" stroke="{OUT}" stroke-width="{W}" fill="none"/>')
    s.shape('circle', {'cx': 120, 'cy': b - 37, 'r': 5}, '#F4F2FF')
    s.raw(f'<path d="M108 {b - 22} l4 8 9 1 -7 6 2 9 -8 -5 -8 5 2 -9 -7 -6 9 -1 z" transform="translate(6 0)" fill="#F4F2FF" stroke="{OUT}" stroke-width="2" stroke-linejoin="round"/>')
    return s


def cowboy(prefix, who, color='#A0612F', shade='#7A4520', band='#3A2416'):
    s = Svg(prefix)
    b = BRIM[who] + 4
    s.shape('path', {'d': f'M84 {b + 4} L90 {b - 38} Q105 {b - 46} 120 {b - 36} Q135 {b - 46} 150 {b - 38} L156 {b + 4} Z'}, color, shade, (-7, 4))
    s.shape('path', {'d': f'M87 {b - 10} L153 {b - 10} L155 {b + 4} L85 {b + 4} Z'}, band)
    s.raw(f'<circle cx="140" cy="{b - 3}" r="3" fill="#FFC233" stroke="{OUT}" stroke-width="1.6"/>')
    s.shape('path', {'d': f'M42 {b - 10} Q58 {b + 8} 120 {b + 6} Q182 {b + 8} 198 {b - 10} Q194 {b + 16} 120 {b + 18} Q46 {b + 16} 42 {b - 10} Z'}, color, shade, (0, -5))
    return s


def tophat(prefix, who):
    s = Svg(prefix)
    b = BRIM[who] - 2
    s.shape('path', {'d': f'M92 {b} L94 {b - 54} L146 {b - 54} L148 {b} Z'}, '#2B2340', '#1A1428', (-7, 0))
    s.shape('path', {'d': f'M93 {b - 16} L147 {b - 16} L148 {b - 4} L92 {b - 4} Z'}, '#D7263D')
    s.raw(f'<path d="M102 {b - 46} L102 {b - 24}" stroke="#4A4060" stroke-width="4" stroke-linecap="round"/>')
    s.shape('ellipse', {'cx': 120, 'cy': b, 'rx': 42, 'ry': 7}, '#2B2340')
    return s


def viking(prefix, who):
    s = Svg(prefix)
    b = BRIM[who] + 2
    horns = (f'M78 {b - 14} C58 {b - 20} 46 {b - 40} 54 {b - 64} C62 {b - 46} 74 {b - 38} 88 {b - 32} Z',
             f'M162 {b - 14} C182 {b - 20} 194 {b - 40} 186 {b - 64} C178 {b - 46} 166 {b - 38} 152 {b - 32} Z')
    s.shape('path', {'d': horns[0]}, '#F2E6C8', '#CDBE96', (-4, 3))
    s.shape('path', {'d': horns[1]}, '#F2E6C8', '#CDBE96', (4, 3))
    s.shape('path', {'d': f'M72 {b} C70 {b - 54} 170 {b - 54} 168 {b} Z'}, '#9AA0B5', '#6E7489', (-7, 5))
    s.raw(f'<path d="M120 {b - 40} L120 {b - 4}" stroke="#C8901A" stroke-width="7"/><path d="M120 {b - 40} L120 {b - 4}" stroke="{OUT}" stroke-width="2" fill="none"/>')
    s.shape('path', {'d': f'M66 {b - 8} Q120 {b - 20} 174 {b - 8} L174 {b + 6} Q120 {b - 6} 66 {b + 6} Z'}, '#C8901A', '#9A6C10', (0, 3))
    s.raw(''.join(f'<circle cx="{x}" cy="{b - 1 - (4 if 96 < x < 144 else 0)}" r="2.2" fill="#F2E6C8" stroke="{OUT}" stroke-width="1.4"/>' for x in range(80, 166, 14)))
    return s


def flower_crown(prefix, who):
    s = Svg(prefix)
    b = 70 if who == 'luna' else 58
    path = f'M74 {b} Q120 {b - 52} 166 {b}'
    s.raw(f'<path d="{path}" stroke="{OUT}" stroke-width="9" fill="none" stroke-linecap="round"/>')
    s.raw(f'<path d="{path}" stroke="#2BA36B" stroke-width="4" fill="none" stroke-linecap="round"/>')
    cols = ['#FF7AB2', '#FFC233', '#F4F2FF', '#FF9A3D', '#B48CFF']
    for i, t in enumerate((0.08, 0.29, 0.5, 0.71, 0.92)):
        x = (1 - t) ** 2 * 74 + 2 * (1 - t) * t * 120 + t * t * 166
        y = (1 - t) ** 2 * b + 2 * (1 - t) * t * (b - 52) + t * t * b
        if i < 4:
            lx = x + 11
            ly = y - 2 + (3 if t > 0.5 else -3)
            s.raw(f'<ellipse cx="{lx:.1f}" cy="{ly:.1f}" rx="6" ry="3.2" fill="#2BA36B" stroke="{OUT}" stroke-width="1.6" transform="rotate({-30 + 60 * t:.0f} {lx:.1f} {ly:.1f})"/>')
        s.raw(flower(round(x, 1), round(y, 1), 6.5, cols[i]))
    return s


def straw(prefix, who):
    s = Svg(prefix)
    b = BRIM[who] + 2
    s.shape('ellipse', {'cx': 120, 'cy': b, 'rx': 64, 'ry': 13}, '#F2CF6B', '#C9A443', (0, -5))
    s.raw(''.join(f'<path d="M{120 + k} {b - 9 + abs(k) / 9:.1f} L{120 + k * 1.25:.1f} {b + 10 - abs(k) / 10:.1f}" stroke="#C9A443" stroke-width="1.5"/>' for k in range(-48, 50, 12)))
    s.shape('path', {'d': f'M86 {b + 2} C84 {b - 42} 156 {b - 42} 154 {b + 2} Z'}, '#F2CF6B', '#C9A443', (-6, 4))
    s.shape('path', {'d': f'M87 {b - 10} Q120 {b - 16} 153 {b - 10} L154 {b + 1} Q120 {b - 5} 86 {b + 1} Z'}, '#22B8C8')
    s.raw(flower(146, b - 6, 4.5, '#FF7AB2', sw=1.4))
    return s


def roundglasses(prefix, who):
    s = Svg(prefix)
    for cx in (101, 139):
        s.raw(f'<circle cx="{cx}" cy="95" r="14" fill="#FF9A3D" fill-opacity=".35" stroke="{OUT}" stroke-width="7"/>')
        s.raw(f'<circle cx="{cx}" cy="95" r="14" fill="none" stroke="#E0A82E" stroke-width="3.2"/>')
        s.raw(f'<path d="M{cx - 7} 88 Q{cx - 3} 85 {cx + 1} 86" stroke="#fff" stroke-width="2.5" fill="none" stroke-linecap="round"/>')
    s.raw(f'<path d="M115 93 Q120 88 125 93" stroke="{OUT}" stroke-width="6" fill="none"/><path d="M115 93 Q120 88 125 93" stroke="#E0A82E" stroke-width="2.6" fill="none"/>')
    s.raw(f'<path d="M87 92 L72 88 M153 92 L168 88" stroke="{OUT}" stroke-width="4" stroke-linecap="round"/>')
    return s


def visor(prefix, who):
    s = Svg(prefix)
    d = 'M74 84 Q120 74 166 84 L163 106 Q120 114 77 106 Z'
    s.raw(f'<path d="{d}" fill="#3FE0E0" fill-opacity=".45" stroke="{OUT}" stroke-width="{W}" stroke-linejoin="round"/>')
    s.raw('<path d="M84 88 Q104 82 124 83" stroke="#fff" stroke-width="3" fill="none" stroke-linecap="round" opacity=".9"/>')
    s.raw(f'<path d="M74 84 Q120 74 166 84" stroke="#C9CFE0" stroke-width="3" fill="none"/>')
    s.raw(f'<circle cx="72" cy="95" r="5" fill="#C9CFE0" stroke="{OUT}" stroke-width="2.5"/><circle cx="168" cy="95" r="5" fill="#C9CFE0" stroke="{OUT}" stroke-width="2.5"/>')
    return s


def heartglasses(prefix, who):
    s = Svg(prefix)
    for cx in (101, 139):
        y = 96
        d = f'M{cx} {y + 12} C{cx - 24} {y - 1} {cx - 15} {y - 21} {cx} {y - 9} C{cx + 15} {y - 21} {cx + 24} {y - 1} {cx} {y + 12} Z'
        s.raw(f'<path d="{d}" fill="#FF5C8A" fill-opacity=".45" stroke="{OUT}" stroke-width="7" stroke-linejoin="round"/>')
        s.raw(f'<path d="{d}" fill="none" stroke="#FF5C8A" stroke-width="3.2" stroke-linejoin="round"/>')
    s.raw(f'<path d="M115 92 Q120 89 125 92" stroke="{OUT}" stroke-width="4" fill="none"/>')
    s.raw(f'<path d="M83 92 L72 88 M157 92 L168 88" stroke="{OUT}" stroke-width="4" stroke-linecap="round"/>')
    return s


def nerdglasses(prefix, who):
    s = Svg(prefix)
    for cx in (101, 139):
        s.raw(f'<rect x="{cx - 16}" y="84" width="32" height="24" rx="5" fill="#F4F2FF" fill-opacity=".18" stroke="{OUT}" stroke-width="6"/>')
        s.raw(f'<path d="M{cx - 10} 90 L{cx - 4} 90" stroke="#fff" stroke-width="2.5" stroke-linecap="round"/>')
    s.raw(f'<path d="M117 92 L123 92" stroke="{OUT}" stroke-width="6"/>')
    s.raw(f'<path d="M85 90 L72 87 M155 90 L168 87" stroke="{OUT}" stroke-width="5" stroke-linecap="round"/>')
    return s


# ---------------------------------------------------------------- Halsschmuck
# Körper-Koordinaten, sitzt unter dem Kinn auf dem Shirt (für beide Figuren gleich).

def neckscarf(prefix, who):
    s = Svg(prefix)
    s.shape('path', {'d': 'M98 135 Q120 143 142 135 L125 170 Q120 175 115 170 Z'}, '#E23D3D', '#B52530', (-5, -3))
    s.raw(''.join(f'<circle cx="{x}" cy="{y}" r="1.8" fill="#F4F2FF"/>' for x, y in ((112, 146), (128, 146), (120, 156), (120, 166 - 4))))
    s.shape('ellipse', {'cx': 120, 'cy': 139, 'rx': 7, 'ry': 5}, '#B52530')
    return s


def peace(prefix, who):
    s = Svg(prefix)
    s.raw(f'<path d="M106 135 Q120 162 134 135" stroke="#7A4A2A" stroke-width="2.6" fill="none"/>')
    s.shape('circle', {'cx': 120, 'cy': 160, 'r': 8.5}, '#F4F2FF')
    s.raw(f'<path d="M120 152.5 L120 167.5 M120 160 L114.7 165.3 M120 160 L125.3 165.3" stroke="{OUT}" stroke-width="2" stroke-linecap="round"/>')
    s.raw(f'<circle cx="120" cy="160" r="6" fill="none" stroke="{OUT}" stroke-width="1.6"/>')
    return s


def bowtie(prefix, who):
    s = Svg(prefix)
    s.shape('path', {'d': 'M120 148 L103 139 L103 157 Z'}, '#D7263D', '#A01828', (3, 0))
    s.shape('path', {'d': 'M120 148 L137 139 L137 157 Z'}, '#D7263D', '#A01828', (-3, 0))
    s.shape('rect', {'x': 114.5, 'y': 142.5, 'width': 11, 'height': 11, 'rx': 2.5}, '#A01828')
    return s


def chain(prefix, who):
    s = Svg(prefix)
    d = 'M102 134 Q120 176 138 134'
    s.raw(f'<path d="{d}" stroke="{OUT}" stroke-width="7.5" fill="none" stroke-linecap="round"/>')
    s.raw(f'<path d="{d}" stroke="#C9CAD8" stroke-width="3.5" fill="none" stroke-linecap="round"/>')
    for t in (0.15, 0.32, 0.68, 0.85):
        x = (1 - t) ** 2 * 102 + 2 * (1 - t) * t * 120 + t * t * 138
        y = (1 - t) ** 2 * 134 + 2 * (1 - t) * t * 176 + t * t * 134
        s.raw(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="1.3" fill="{OUT}"/>')
    s.shape('path', {'d': 'M110 158 Q120 152 130 158 Q128 170 120 178 Q112 170 110 158 Z'}, '#C9CAD8', '#9A9CB0', (-3, -2))
    s.raw(f'<path d="M122 158 L115 168 L121 168 L117 175 L126 164 L120 164 Z" fill="#FFC233" stroke="{OUT}" stroke-width="1.2" stroke-linejoin="round"/>')
    return s


def lei(prefix, who):
    s = Svg(prefix)
    cols = ['#FF7AB2', '#FFC233', '#F4F2FF', '#FF9A3D']
    out = []
    n = 9
    for i in range(n):
        t = i / (n - 1)
        x = (1 - t) ** 2 * 100 + 2 * (1 - t) * t * 120 + t * t * 140
        y = (1 - t) ** 2 * 135 + 2 * (1 - t) * t * 176 + t * t * 135
        out.append(flower(round(x, 1), round(y, 1), 4.2, cols[i % 4], sw=1.4))
    s.raw(''.join(out))
    return s


# ---------------------------------------------------------------- weitere Westen

def vest_pattern(prefix, who, color, shade, pattern):
    """Weste mit Muster (pattern bekommt die Svg, linke und rechte Form, Unterkante)."""
    s = Svg(prefix)
    left, right, bottom = VEST_PANELS[who]
    s.shape('path', {'d': left}, color, shade, (5, -4))
    s.shape('path', {'d': right}, color, shade, (-5, -4))
    pattern(s, left, right, bottom)
    return s


def fringe_pattern(s, left, right, bottom):
    for x0, x1 in ((88, 104), (136, 152)):
        s.raw(''.join(f'<path d="M{x} {bottom - 1} L{x - 1} {bottom + 9}" stroke="{OUT}" stroke-width="4.2" stroke-linecap="round"/>'
                      f'<path d="M{x} {bottom - 1} L{x - 1} {bottom + 9}" stroke="#C47A3E" stroke-width="2" stroke-linecap="round"/>' for x in range(x0, x1 + 1, 4)))
    s.raw(f'<path d="M95 150 L104 150 M136 150 L145 150" stroke="#F2E6C8" stroke-width="2"/>')
    s.raw(f'<path d="M137 {bottom - 34} l5 -6 5 6 -5 6 z" fill="#C0C4D6" stroke="{OUT}" stroke-width="1.6"/>')


def space_pattern(s, left, right, bottom):
    for i, d in enumerate((left, right)):
        clipped(s, d, f'<path d="M80 {bottom - 22} L160 {bottom - 22} M80 {bottom - 14} L160 {bottom - 14}" stroke="#3FE0E0" stroke-width="2.4"/>', f'{s.prefix}cl{i}')
    s.raw(f'<path d="M98 150 l2 5 5 0 -4 3 2 5 -5 -3 -5 3 2 -5 -4 -3 5 0 z" fill="#FFC233" stroke="{OUT}" stroke-width="1.4" stroke-linejoin="round"/>')
    s.raw(f'<circle cx="141" cy="152" r="3" fill="#3FE0E0" stroke="{OUT}" stroke-width="1.4"/>')


def tux_pattern(s, left, right, bottom):
    s.raw(f'<path d="M110 133 L100 160 L104 133 Z M130 133 L140 160 L136 133 Z" fill="#4A4060" stroke="{OUT}" stroke-width="2" stroke-linejoin="round"/>')
    s.raw(f'<circle cx="104" cy="{bottom - 30}" r="2.2" fill="#C9CAD8"/><circle cx="104" cy="{bottom - 18}" r="2.2" fill="#C9CAD8"/>')
    s.raw(f'<path d="M140 150 L146 148 L146 154 Z" fill="#F4F2FF" stroke="{OUT}" stroke-width="1.2"/>')


def studded_pattern(s, left, right, bottom):
    for x in (90, 98, 106):
        s.raw(f'<path d="M{x - 3} 138 L{x} 128 L{x + 3} 138 Z" fill="#C9CAD8" stroke="{OUT}" stroke-width="1.6" stroke-linejoin="round"/>')
        s.raw(f'<path d="M{240 - x - 3} 138 L{240 - x} 128 L{240 - x + 3} 138 Z" fill="#C9CAD8" stroke="{OUT}" stroke-width="1.6" stroke-linejoin="round"/>')
    for y in range(146, bottom - 6, 10):
        s.raw(f'<circle cx="{98 - (y - 132) * 0.08:.1f}" cy="{y}" r="1.7" fill="#C9CAD8"/><circle cx="{142 + (y - 132) * 0.08:.1f}" cy="{y}" r="1.7" fill="#C9CAD8"/>')
    s.raw(f'<rect x="137" y="{bottom - 30}" width="12" height="12" rx="2" fill="#E23D3D" stroke="{OUT}" stroke-width="1.6"/>')
    s.raw(f'<path d="M140 {bottom - 27} L146 {bottom - 21} M146 {bottom - 27} L140 {bottom - 21}" stroke="{OUT}" stroke-width="1.6"/>')


def hawaii_pattern(s, left, right, bottom):
    for i, d in enumerate((left, right)):
        inner = ''.join(flower(x, y, 4.6, c, sw=1.3) for x, y, c in
                        ((92, 146, '#F4F2FF'), (104, 162, '#FF7AB2'), (90, 178, '#FFC233'), (102, 192, '#F4F2FF'), (95, 210, '#FF7AB2'),
                         (148, 146, '#FF7AB2'), (136, 160, '#F4F2FF'), (150, 176, '#FFC233'), (138, 192, '#FF7AB2'), (147, 210, '#F4F2FF')))
        inner += ''.join(f'<ellipse cx="{x}" cy="{y}" rx="5" ry="2.5" fill="#1C7A4E" transform="rotate(35 {x} {y})"/>' for x, y in ((98, 154), (95, 186), (142, 168), (144, 200)))
        clipped(s, d, inner, f'{s.prefix}cl{i}')
        s.raw(f'<path d="{d}" fill="none" stroke="{OUT}" stroke-width="{W}" stroke-linejoin="round"/>')


# ---------------------------------------------------------------- weitere Gitarren

ACOUSTIC_BODY = 'M58 211 C58 186 82 182 96 194 C104 188 120 186 130 196 C142 204 142 218 130 226 C120 236 104 234 96 228 C82 240 58 236 58 211 Z'
BIG_BODY = 'M54 211 C54 182 80 178 95 192 C104 186 122 184 133 195 C146 203 146 219 133 227 C122 238 104 236 95 230 C80 244 54 240 54 211 Z'


def acoustic_generic(prefix, color, shade, ring, head='#7A4A2A', body=ACOUSTIC_BODY, guard=None, inner=None, extra=''):
    s = Svg(prefix)
    neck(s, head)
    s.shape('path', {'d': body}, color, shade, (-8, -6))
    if inner:
        s.raw(f'<g transform="translate(100 211) scale(.72 .62) translate(-100 -211)"><path d="{body}" fill="{inner}"/></g>')
    if guard:
        s.raw(f'<path d="M110 218 C122 222 128 214 124 204 L112 206 Z" fill="{guard}" stroke="{OUT}" stroke-width="2"/>')
    s.raw(extra)
    s.raw(f'<circle cx="104" cy="211" r="9" fill="#2B1A10" stroke="{OUT}" stroke-width="2.5"/>')
    s.raw(f'<circle cx="104" cy="211" r="12.5" fill="none" stroke="{ring}" stroke-width="2"/>')
    s.raw('<rect x="72" y="204" width="6" height="14" rx="2" fill="#2B1A10"/>')
    strings(s)
    return s


def guitar_classic(prefix):
    s = Svg(prefix)
    neck(s, '#7A4A2A')
    s.raw('<rect x="216" y="204" width="15" height="4" rx="2" fill="#2B1A10"/><rect x="216" y="214" width="15" height="4" rx="2" fill="#2B1A10"/>')
    s.shape('path', {'d': BIG_BODY}, '#F1D49A', '#C9A86A', (-8, -6))
    s.raw(f'<circle cx="106" cy="211" r="9.5" fill="#2B1A10" stroke="{OUT}" stroke-width="2.5"/>')
    s.raw('<circle cx="106" cy="211" r="12.5" fill="none" stroke="#2E8B57" stroke-width="2.2"/><circle cx="106" cy="211" r="15" fill="none" stroke="#C2452D" stroke-width="1.6"/>')
    s.raw(f'<rect x="68" y="202" width="8" height="18" rx="2" fill="#5A2E14" stroke="{OUT}" stroke-width="1.6"/>')
    s.raw('<path d="M72 208 L232 208 M72 211 L232 211 M72 214 L232 214" stroke="#F4F2FF" stroke-width="1"/>')
    return s


def guitar_flower(prefix):
    deco = (flower(80, 198, 5, '#FF7AB2', sw=1.4) + flower(86, 224, 4.5, '#FFC233', sw=1.4) + flower(122, 222, 4, '#22B8C8', sw=1.4)
            + flower(70, 212, 3.6, '#B48CFF', sw=1.2))
    return acoustic_generic(prefix, '#F4F2FF', '#C9C6E0', '#22B8C8', extra=deco)


def guitar_archtop(prefix):
    s = Svg(prefix)
    neck(s, '#2B1A10')
    s.shape('path', {'d': BIG_BODY}, '#6B2E12', '#4A1E0A', (-8, -6))
    s.raw(f'<g transform="translate(100 211) scale(.74 .64) translate(-100 -211)"><path d="{BIG_BODY}" fill="#E8932E"/></g>')
    for y in (199, 223):
        s.raw(f'<path d="M84 {y} C90 {y - 4} 100 {y + 4} 108 {y}" stroke="{OUT}" stroke-width="2.6" fill="none" stroke-linecap="round"/>'
              f'<circle cx="84" cy="{y}" r="1.8" fill="{OUT}"/><circle cx="108" cy="{y}" r="1.8" fill="{OUT}"/>')
    s.raw(f'<path d="M56 205 L70 207 L70 215 L56 217 Z" fill="#C9CAD8" stroke="{OUT}" stroke-width="1.8"/>')
    s.raw(f'<rect x="118" y="203" width="8" height="16" rx="2" fill="{OUT}"/>')
    s.raw(f'<path d="M110 222 C124 228 132 220 128 212" stroke="#F4F2FF" stroke-width="3" fill="none"/>')
    s.raw('<path d="M64 209 L232 209 M64 213 L232 213" stroke="#F4F2FF" stroke-width="1.2"/>')
    return s


def guitar_vshape(prefix):
    s = Svg(prefix)
    neck(s, '#15121F', pointy=True)
    d = 'M142 203 L62 178 L54 193 L104 211 L54 229 L62 244 L142 219 Z'
    s.shape('path', {'d': d}, '#2B2340', '#1A1428', (-6, -6))
    s.raw(f'<path d="M66 186 L120 204 M66 236 L120 218" stroke="#C9CAD8" stroke-width="3"/>')
    s.raw(f'<path d="M128 199 L118 211 L126 211 L118 223 L134 208 L126 208 Z" fill="#FFC233" stroke="{OUT}" stroke-width="1.5" stroke-linejoin="round"/>')
    s.raw(f'<rect x="108" y="204" width="7" height="14" rx="2" fill="{OUT}"/>')
    s.raw('<path d="M108 209 L232 209 M108 213 L232 213" stroke="#F4F2FF" stroke-width="1.2"/>')
    return s


def guitar_galaxy(prefix):
    s = Svg(prefix)
    neck(s, '#15121F')
    s.shape('path', {'d': DOUBLE}, '#1B1F5E', '#10123D', (-8, -6))
    inner = ('<ellipse cx="92" cy="206" rx="26" ry="12" fill="#8E6CEF" opacity=".75" transform="rotate(-20 92 206)"/>'
             '<ellipse cx="96" cy="216" rx="18" ry="7" fill="#FF7AB2" opacity=".55" transform="rotate(-20 96 216)"/>'
             + ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#fff"/>' for x, y, r in ((74, 200, 1.4), (84, 226, 1.2), (118, 196, 1.3), (124, 224, 1.5), (70, 216, 1), (108, 230, 1.1))))
    clipped(s, DOUBLE, inner, f'{prefix}cl')
    s.raw(f'<path d="{DOUBLE}" fill="none" stroke="{OUT}" stroke-width="{W}" stroke-linejoin="round"/>')
    s.raw(f'<circle cx="80" cy="208" r="6" fill="#FFC233" stroke="{OUT}" stroke-width="1.6"/><ellipse cx="80" cy="208" rx="11" ry="3" fill="none" stroke="#3FE0E0" stroke-width="1.8" transform="rotate(-20 80 208)"/>')
    pickups(s)
    strings(s)
    return s


def guitar_flame(prefix):
    s = Svg(prefix)
    neck(s, '#15121F', pointy=True)
    s.shape('path', {'d': POINTY}, '#2B2340', '#1A1428', (-8, -6))
    flames = ('<path d="M56 186 C86 196 78 200 104 201 C88 206 112 210 96 213 C114 216 86 220 104 223 C80 224 86 228 56 236 Z" fill="#FF6B2C"/>'
              '<path d="M56 194 C76 200 72 204 90 205 C78 209 94 211 84 214 C96 217 78 219 88 221 C72 223 74 226 56 230 Z" fill="#FFC233"/>')
    clipped(s, POINTY, flames, f'{prefix}cl')
    s.raw(f'<path d="{POINTY}" fill="none" stroke="{OUT}" stroke-width="{W}" stroke-linejoin="round"/>')
    pickups(s)
    strings(s)
    return s


# Welche Gitarren akustisch sind (mit ihnen bleibt der Amp weg).
ACOUSTIC_GUITARS = {'g_acoustic', 'g_classic', 'g_jumbo', 'g_flower', 'g_acoustic_black'}

GUITARS.update({
    'g_classic': lambda: guitar_classic('gc'),
    'g_acoustic_black': lambda: acoustic_generic('gab', '#2B2340', '#1A1428', '#E23D3D', head='#15121F',
                                                  extra=flower(80, 222, 4.5, '#E23D3D', sw=1.4) + flower(122, 200, 3.6, '#E23D3D', sw=1.2)),
    'g_jumbo': lambda: acoustic_generic('gj', '#5A2A12', '#3E1C0A', '#F2E6C8', body=BIG_BODY, inner='#E8932E', guard='#2B1A10'),
    'g_flower': lambda: guitar_flower('gf'),
    'g_archtop': lambda: guitar_archtop('gat'),
    'g_vshape': lambda: guitar_vshape('gv'),
    'g_galaxy': lambda: guitar_galaxy('gg'),
    'g_flame': lambda: guitar_flame('gfl'),
    'g_double_blue': lambda: guitar_double('gdbl', '#5BB8F0', '#3A8FC4', guard='#F4F2FF', head='#F4F2FF'),
    'g_pointy_pink': lambda: guitar_pointy('gpp', '#FF7AB2', '#D94F8C'),
})

HEAD_ITEMS.update({
    'hat_cap': ('hat', cap),
    'hat_cowboy': ('hat', cowboy),
    'hat_tophat': ('hat', tophat),
    'hat_viking': ('hat', viking),
    'hat_flowers': ('hat', flower_crown),
    'hat_straw': ('hat', straw),
    'glasses_round': ('glasses', roundglasses),
    'glasses_visor': ('glasses', visor),
    'glasses_heart': ('glasses', heartglasses),
    'glasses_nerd': ('glasses', nerdglasses),
})

BODY_ITEMS.update({
    'neck_scarf': ('neck', neckscarf),
    'neck_peace': ('neck', peace),
    'neck_bowtie': ('neck', bowtie),
    'neck_chain': ('neck', chain),
    'neck_lei': ('neck', lei),
    'vest_fringe': ('vest', lambda p, w: vest_pattern(p, w, '#A0612F', '#7A4520', fringe_pattern)),
    'vest_space': ('vest', lambda p, w: vest_pattern(p, w, '#C9CFE0', '#9AA2BA', space_pattern)),
    'vest_tux': ('vest', lambda p, w: vest_pattern(p, w, '#2B2340', '#1A1428', tux_pattern)),
    'vest_studded': ('vest', lambda p, w: vest_pattern(p, w, '#1E1A26', '#0E0B14', studded_pattern)),
    'vest_hawaii': ('vest', lambda p, w: vest_pattern(p, w, '#22B8C8', '#178A96', hawaii_pattern)),
})


# ---------------------------------------------------------------- Amps
# Koordinaten der fertigen Figur: rechts neben den Füssen (Boden bei y = 296).

def amp_mini(prefix):
    s = Svg(prefix)
    s.shape('rect', {'x': 190, 'y': 246, 'width': 58, 'height': 50, 'rx': 6}, '#2B2340', '#1A1428', (-5, -4))
    s.shape('rect', {'x': 194, 'y': 250, 'width': 50, 'height': 10, 'rx': 2}, '#F2E6C8')
    s.raw(''.join(f'<circle cx="{x}" cy="255" r="2.4" fill="{OUT}"/>' for x in (202, 212, 222)))
    s.raw('<circle cx="236" cy="255" r="2" fill="#E23D3D"/>')
    s.shape('rect', {'x': 197, 'y': 264, 'width': 44, 'height': 26, 'rx': 3}, '#4A4458')
    s.raw(''.join(f'<path d="M199 {y} L239 {y}" stroke="#2B2340" stroke-width="1.5"/>' for y in range(269, 289, 5)))
    return s


def amp_combo(prefix):
    s = Svg(prefix)
    s.raw(f'<path d="M206 222 Q221 208 236 222" stroke="{OUT}" stroke-width="8" fill="none"/><path d="M206 222 Q221 208 236 222" stroke="#3A2416" stroke-width="4" fill="none"/>')
    body = 'M178 296 L178 228 Q178 220 186 220 L256 220 Q264 220 264 228 L264 296 Z'
    s.shape('path', {'d': body}, '#D9B977', '#B8954F', (-6, -4))
    clipped(s, body, ''.join(f'<path d="M{x} 220 L{x + 60} 296" stroke="#A0612F" stroke-width="2.5" opacity=".45"/>' for x in range(130, 270, 9)), f'{prefix}cl')
    s.raw(f'<path d="{body}" fill="none" stroke="{OUT}" stroke-width="{W}" stroke-linejoin="round"/>')
    s.shape('rect', {'x': 184, 'y': 226, 'width': 74, 'height': 12, 'rx': 2}, '#3A2416')
    s.raw(''.join(f'<circle cx="{x}" cy="232" r="2.8" fill="#F2E6C8" stroke="{OUT}" stroke-width="1.2"/>' for x in (192, 202, 212, 222, 232)))
    s.raw('<circle cx="248" cy="232" r="2.6" fill="#E23D3D"/>')
    s.shape('rect', {'x': 188, 'y': 244, 'width': 66, 'height': 44, 'rx': 4}, '#7A5A3A')
    s.raw(''.join(f'<path d="M190 {y} L252 {y}" stroke="#9A7A52" stroke-width="1.2"/>' for y in range(249, 286, 5)))
    s.raw(f'<rect x="212" y="262" width="18" height="6" rx="2" fill="#F2E6C8" stroke="{OUT}" stroke-width="1.2"/>')
    return s


def amp_stack(prefix):
    s = Svg(prefix)
    s.shape('rect', {'x': 180, 'y': 232, 'width': 86, 'height': 64, 'rx': 4}, '#2A2433', '#16121C', (-5, -4))
    s.shape('rect', {'x': 186, 'y': 238, 'width': 74, 'height': 52, 'rx': 2}, '#3A3448')
    for cx in (205, 241):
        for cy in (251, 277):
            s.raw(f'<circle cx="{cx}" cy="{cy}" r="10.5" fill="#1E1A26" stroke="{OUT}" stroke-width="2"/><circle cx="{cx}" cy="{cy}" r="4" fill="#4A4458"/>')
    s.shape('rect', {'x': 182, 'y': 200, 'width': 82, 'height': 30, 'rx': 4}, '#2A2433', '#16121C', (-4, -3))
    s.shape('rect', {'x': 187, 'y': 206, 'width': 72, 'height': 11, 'rx': 2}, '#E0B84A')
    s.raw(''.join(f'<circle cx="{x}" cy="211.5" r="2.6" fill="{OUT}"/>' for x in (194, 203, 212, 221, 230, 239)))
    s.raw('<circle cx="251" cy="211.5" r="2.4" fill="#E23D3D"/>')
    s.raw(f'<path d="M210 224 L236 224" stroke="#F4F2FF" stroke-width="2.5" stroke-linecap="round"/>')
    return s


def amp_space(prefix):
    s = Svg(prefix)
    s.raw(f'<path d="M240 232 L252 208" stroke="{OUT}" stroke-width="3.5"/><circle cx="253" cy="206" r="4.5" fill="#3FE0E0" stroke="{OUT}" stroke-width="2"/>')
    body = 'M180 296 L184 240 Q222 214 260 240 L264 296 Z'
    s.shape('path', {'d': body}, '#6A48C9', '#4A2E9A', (-6, -4))
    s.raw(f'<circle cx="222" cy="270" r="19" fill="#1B1F5E" stroke="{OUT}" stroke-width="2.5"/>')
    s.raw('<circle cx="222" cy="270" r="13" fill="none" stroke="#3FE0E0" stroke-width="3.5"/><circle cx="222" cy="270" r="4" fill="#3FE0E0"/>')
    s.raw(''.join(f'<circle cx="{x}" cy="{y}" r="2.6" fill="{c}" stroke="{OUT}" stroke-width="1.2"/>' for x, y, c in ((204, 242, '#FFC233'), (222, 236, '#FF7AB2'), (240, 242, '#3FE0E0'))))
    return s


def amp_retro(prefix):
    s = Svg(prefix)
    body = 'M182 296 L182 240 Q182 228 194 228 L250 228 Q262 228 262 240 L262 296 Z'
    s.shape('path', {'d': body}, '#E23D3D', '#B52530', (-6, -4))
    clipped(s, body, '<rect x="170" y="220" width="110" height="24" fill="#F2E6C8"/>', f'{prefix}cl')
    s.raw(f'<path d="M182 244 L262 244" stroke="{OUT}" stroke-width="2.5"/>')
    s.raw(f'<path d="{body}" fill="none" stroke="{OUT}" stroke-width="{W}" stroke-linejoin="round"/>')
    s.raw(''.join(f'<circle cx="{x}" cy="236" r="3" fill="#C9CAD8" stroke="{OUT}" stroke-width="1.3"/>' for x in (196, 208, 220)))
    s.shape('rect', {'x': 192, 'y': 252, 'width': 60, 'height': 36, 'rx': 8}, '#F2E6C8')
    s.raw(''.join(f'<path d="M196 {y} L248 {y}" stroke="#C9B48A" stroke-width="1.6"/>' for y in range(258, 286, 5)))
    s.raw(f'<circle cx="244" cy="236" r="3.6" fill="#FFC233" stroke="{OUT}" stroke-width="1.3"/>')
    return s


AMPS = {
    'amp_mini': lambda: amp_mini('am'),
    'amp_retro': lambda: amp_retro('ar'),
    'amp_combo': lambda: amp_combo('ac'),
    'amp_stack': lambda: amp_stack('ast'),
    'amp_space': lambda: amp_space('asp'),
}


# ---------------------------------------------------------------- Zusammensetzen

def transforms(who):
    neck_y = NECK[who]
    new_neck = 292 - (292 - neck_y) * BODY_SCALE
    body_t = f'translate(120 292) scale({BODY_SCALE}) translate(-120 -292)'
    head_t = f'translate(120 {new_neck}) scale({HEAD_SCALE}) translate(-120 -{neck_y})'
    return body_t, head_t


def template(who):
    back, body, head = luna_parts() if who == 'luna' else fuzz_parts()
    body_t, head_t = transforms(who)
    defs = back.defs + body.defs + head.defs
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{FULL_BOX}"><defs>' + ''.join(defs) + '<!--defs--></defs>'
            + '<!--slot:amp-->'
            + f'<g transform="{head_t}">{scaled(back.body, HEAD_SCALE)}</g>'
            + f'<g transform="{body_t}">{scaled(body.body, BODY_SCALE)}</g>'
            + f'<g transform="{head_t}">{scaled(head.body, HEAD_SCALE)}</g></svg>')


def items():
    out = {'guitars': {}, 'amps': {}, 'luna': {}, 'fuzz': {}}
    for gid, fn in GUITARS.items():
        s = fn()
        out['guitars'][gid] = {'defs': ''.join(s.defs), 'svg': scaled(s.body, BODY_SCALE),
                               'kind': 'acoustic' if gid in ACOUSTIC_GUITARS else 'electric'}
    for aid, fn in AMPS.items():
        s = fn()
        out['amps'][aid] = {'defs': ''.join(s.defs), 'svg': '\n'.join(s.body)}
    for who in ('luna', 'fuzz'):
        for iid, (slot, fn) in HEAD_ITEMS.items():
            s = fn(f'{iid}_{who[0]}_', who)
            out[who][iid] = {'slot': slot, 'defs': ''.join(s.defs), 'svg': scaled(s.body, HEAD_SCALE)}
        for iid, (slot, fn) in BODY_ITEMS.items():
            s = fn(f'{iid}_{who[0]}_', who)
            out[who][iid] = {'slot': slot, 'defs': ''.join(s.defs), 'svg': scaled(s.body, BODY_SCALE)}
    return out


def render(who, tpl, its, look=None):
    """Fertige Figur wie in der App (für Vorschau und Download-Bild)."""
    look = look or {}
    colors = dict(DEFAULTS[who])
    colors.update(look.get('colors', {}))
    svg = tpl
    for k, v in colors.items():
        svg = svg.replace('{{' + k + '}}', v)
    defs = []
    g = its['guitars'][look.get('guitar', DEFAULT_GUITAR[who])]
    defs.append(g['defs'])
    svg = svg.replace('<!--slot:guitar-->', g['svg'])
    amp = look.get('amp')
    if amp and g['kind'] == 'electric':
        defs.append(its['amps'][amp]['defs'])
        svg = svg.replace('<!--slot:amp-->', its['amps'][amp]['svg'])
    for slot in ('vest', 'neck', 'glasses', 'hat'):
        iid = look.get(slot)
        if iid:
            it = its[who][iid]
            defs.append(it['defs'])
            svg = svg.replace(f'<!--slot:{slot}-->', it['svg'])
            if slot == 'hat':
                svg = re.sub(r'<!--slot:hairclip-->.*?<!--/slot:hairclip-->', '', svg, flags=re.S)
    return svg.replace('<!--defs-->', ''.join(defs))


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, 'assets', 'characters')
    its = items()
    with open(os.path.join(out, 'items.json'), 'w') as f:
        json.dump(its, f, ensure_ascii=False, separators=(',', ':'))
    for who in ('luna', 'fuzz'):
        tpl = template(who)
        open(os.path.join(out, f'{who}_template.svg'), 'w').write(tpl)
        full = render(who, tpl, its)
        open(os.path.join(out, f'{who}.svg'), 'w').write(full)
        face = re.sub(r'viewBox="[^"]+"', f'viewBox="{FACE_BOX[who]}"', full, count=1)
        open(os.path.join(out, f'{who}_face.svg'), 'w').write(face)
    # Vorschau aller Teile (nur zum Anschauen, nicht für die App)
    if len(sys.argv) > 2:
        prev = sys.argv[2]
        os.makedirs(prev, exist_ok=True)
        looks = [
            {},
            {'guitar': 'g_classic'},
            {'hat': 'hat_cowboy', 'vest': 'vest_fringe', 'neck': 'neck_scarf', 'guitar': 'g_jumbo'},
            {'hat': 'hat_flowers', 'glasses': 'glasses_round', 'neck': 'neck_peace', 'guitar': 'g_flower'},
            {'glasses': 'glasses_visor', 'vest': 'vest_space', 'guitar': 'g_galaxy', 'amp': 'amp_space'},
            {'hat': 'hat_tophat', 'neck': 'neck_bowtie', 'vest': 'vest_tux', 'guitar': 'g_archtop', 'amp': 'amp_combo'},
            {'hat': 'hat_viking', 'vest': 'vest_studded', 'neck': 'neck_chain', 'guitar': 'g_vshape', 'amp': 'amp_stack'},
            {'hat': 'hat_straw', 'glasses': 'glasses_heart', 'neck': 'neck_lei', 'vest': 'vest_hawaii', 'guitar': 'g_acoustic_black'},
            {'hat': 'hat_cap', 'glasses': 'glasses_nerd', 'vest': 'vest_jeans', 'guitar': 'g_flame', 'amp': 'amp_retro'},
            {'guitar': 'g_double_blue', 'amp': 'amp_mini'},
            {'guitar': 'g_pointy_pink', 'hat': 'hat_crown', 'glasses': 'glasses_star', 'vest': 'vest_leather'},
        ]
        for who in ('luna', 'fuzz'):
            tpl = template(who)
            for i, lk in enumerate(looks):
                open(os.path.join(prev, f'{who}_{i:02d}.svg'), 'w').write(render(who, tpl, its, lk))


if __name__ == '__main__':
    main()
