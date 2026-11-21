"""Erzeugt das Suona-Symbol wie bei Volti und Conti: Quadrat mit runden Ecken
(aussen durchsichtig) im Markenverlauf Pink → Violett, darauf die weisse
Bildmarke. Die Marke ist ein Plektrum, aus dem zwei Achtelnoten ausgeschnitten
sind (dort scheint der Verlauf durch).

Aufruf (im Projektordner):  python3 tool/make_icon.py
Schreibt: assets/brand/suona_mark.png, assets/brand/suona_icon.png (512),
assets/brand/suona_icon_1024.png, das Windows-Icon und die Android-Symbole.
"""
import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Rundung der Ecken (Anteil der Kantenlänge), Grösse der Marke im Quadrat.
RADIUS = 0.22
SCALE = 0.66
ICO_SIZES = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]


def mark(size=1024):
    """Weisse Bildmarke auf durchsichtigem Grund (4-fach gerechnet)."""
    S = size * 4
    k = S / 1024
    pick = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(pick)
    # Plektrum: oben breit und rund, unten spitz (wie das frühere Symbol).
    cx, top, bot, w = 512, 120, 930, 720
    path = []
    for i in range(181):
        t = math.pi - i / 180 * math.pi
        path.append((cx + w / 2 * math.cos(t), top + 90 - 100 * math.sin(t)))
    n = 90
    for i in range(1, n + 1):
        f = i / n
        path.append((cx + w / 2 * math.sqrt(max(0, 1 - f ** 1.7)), top + 90 + (bot - top - 90) * f))
    for i in range(n, 0, -1):
        f = i / n
        path.append((cx - w / 2 * math.sqrt(max(0, 1 - f ** 1.7)), top + 90 + (bot - top - 90) * f))
    d.polygon([(x * k, y * k) for x, y in path], fill=255)
    # Zwei Achtelnoten mit Balken, ausgeschnitten.
    notes = Image.new("L", (S, S), 0)
    nd = ImageDraw.Draw(notes)
    for (x, y) in [(418, 640), (622, 590)]:
        head = Image.new("L", (S, S), 0)
        ImageDraw.Draw(head).ellipse([(x - 70) * k, (y - 48) * k, (x + 70) * k, (y + 48) * k], fill=255)
        notes = ImageChops.lighter(notes, head.rotate(20, center=(x * k, y * k), resample=Image.BICUBIC))
    nd = ImageDraw.Draw(notes)
    nd.rectangle([462 * k, 330 * k, 490 * k, 630 * k], fill=255)
    nd.rectangle([666 * k, 280 * k, 694 * k, 580 * k], fill=255)
    nd.polygon([(462 * k, 300 * k), (694 * k, 248 * k), (694 * k, 322 * k), (462 * k, 374 * k)], fill=255)
    alpha = ImageChops.subtract(pick, notes)
    alpha = alpha.resize((size, size), Image.LANCZOS)
    white = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    white.putalpha(alpha)
    return white


def _rounded_mask(size):
    big = size * 4
    m = Image.new("L", (big, big), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, big - 1, big - 1), radius=round(big * RADIUS), fill=255)
    return m.resize((size, size), Image.LANCZOS)


def icon(size, the_mark):
    """Markenverlauf (Pink oben links → Violett unten rechts) mit weichem Glanz."""
    yy, xx = np.mgrid[0:size, 0:size] / max(size - 1, 1)
    t = ((xx + yy) / 2)[..., None]
    pink, violet = np.array((240, 71, 156), np.float32), np.array((122, 60, 240), np.float32)
    bg = pink * (1 - t) + violet * t
    glow = np.exp(-(((xx - 0.18) ** 2 + (yy - 0.12) ** 2) / 0.12))[..., None]
    bg = np.clip(bg + glow * 38, 0, 255).round().astype(np.uint8)
    canvas = Image.fromarray(np.dstack([bg, np.full((size, size), 255, np.uint8)]), "RGBA")
    m = the_mark.resize((max(1, round(size * SCALE)),) * 2, Image.LANCZOS)
    canvas.alpha_composite(m, ((size - m.width) // 2, (size - m.height) // 2 + round(size * 0.01)))
    canvas.putalpha(ImageChops.multiply(canvas.getchannel("A"), _rounded_mask(size)))
    return canvas


def main():
    m = mark(1024)
    os.makedirs(f"{BASE}/assets/brand", exist_ok=True)
    m.save(f"{BASE}/assets/brand/suona_mark.png")
    icon(1024, m).save(f"{BASE}/assets/brand/suona_icon_1024.png")
    icon(512, m).save(f"{BASE}/assets/brand/suona_icon.png")
    images = [icon(s, m) for s in ICO_SIZES]
    images[-1].save(
        f"{BASE}/windows/runner/resources/app_icon.ico",
        sizes=[(s, s) for s in ICO_SIZES],
        append_images=images[:-1],
    )
    for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        icon(px, m).save(f"{BASE}/android/app/src/main/res/mipmap-{name}/ic_launcher.png")


if __name__ == "__main__":
    main()
