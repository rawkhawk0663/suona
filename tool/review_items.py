#!/usr/bin/env python3
"""Prüfbild für Shop-Teile: schreibt jedes Teil als SVG-Nahansicht an beiden Figuren.

Aufruf:  python3 tool/review_items.py <ordner> [teil1,teil2,…]
Die SVGs dann z. B. mit Chromium/Playwright als Kacheln nebeneinander ansehen.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_characters as mc  # noqa: E402

out = sys.argv[1]; only = sys.argv[2].split(',') if len(sys.argv) > 2 else None
os.makedirs(out, exist_ok=True)
for f in os.listdir(out):
    os.remove(os.path.join(out, f))
its = mc.items()
BOX = {'hat': ('40 -50 160 170', '30 -60 180 180'), 'glasses': ('60 40 120 110', '60 40 120 110'),
       'neck': ('60 100 120 120', '60 100 120 120'), 'vest': ('50 110 140 140', '50 110 140 140')}
for who in ('luna', 'fuzz'):
    tpl = mc.template(who)
    for iid, it in its[who].items():
        if only and iid not in only: continue
        svg = mc.render(who, tpl, its, {it['slot']: iid})
        box = BOX[it['slot']][0 if who == 'luna' else 1]
        open(f'{out}/{iid}__{who}.svg', 'w').write(re.sub(r'viewBox="[^"]+"', f'viewBox="{box}"', svg, count=1))
    if who == 'luna':
        for g in its['guitars']:
            if only and g not in only: continue
            svg = mc.render(who, tpl, its, {'guitar': g})
            open(f'{out}/{g}.svg', 'w').write(re.sub(r'viewBox="[^"]+"', 'viewBox="40 104 216 176"', svg, count=1))
        for a in its['amps']:
            if only and a not in only: continue
            svg = mc.render(who, tpl, its, {'amp': a})
            open(f'{out}/{a}.svg', 'w').write(re.sub(r'viewBox="[^"]+"', 'viewBox="150 180 130 125"', svg, count=1))
