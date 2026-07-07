# -*- coding: utf-8 -*-
"""KI-Sprite-Import: macht aus ComfyUI-Ausgaben spielfertige 32x32-Sprites.

Schritte pro Bild:
  1. Hintergrund freistellen (einfarbige Ecken-Farbe wird transparent).
  2. Auf den Inhalt zuschneiden (Quadrat, zentriert).
  3. Auf 32x32 herunterrechnen (Nearest fuer harte Pixel).
  4. Farben auf die Hauspalette quantisieren » einheitlicher Look,
     egal was die KI liefert.

Nutzung:
  python scripts/dev/ki_sprite_import.py <eingabe.png|ordner> [name]
Ausgabe: assets/eigene_sprites/<name>.png (+ _vorschau_ki.png Blatt)
"""
import os
import sys

try:
    from PIL import Image
except ImportError:
    print("Pillow fehlt — einmalig installieren:  pip install pillow")
    sys.exit(1)

# Hauspalette „Infinit Dungeon“ (identisch zu make_own_sprites.gd).
PALETTE = [
    "14141f", "262634", "3a3a4e", "6a6a84", "9a9ab4", "e8e8f4",
    "a87c2a", "e8b44a", "f4e04a",
    "8a2733", "d84654", "f47a84",
    "2a4a8a", "4a7ad8", "7aa4f4",
    "1f7a6a", "3ec8b0", "8af4dc",
    "5a2a8a", "9a5ad8", "c48af4",
    "2a7a30", "5ac858", "8ae87a",
    "9a4a1f", "e87c3a",
    "b0785a", "e8b48a", "f4d4b0",
    "4e3a26", "7a5a3a", "a87c50",
]
RGB = [(int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)) for h in PALETTE]
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "eigene_sprites")
# Zielgroesse per Umgebungsvariable KI_SIZE (Standard 32; 64 fuer Kampf-Sprites).
SIZE = int(os.environ.get("KI_SIZE", "32"))


def nearest(color):
    r, g, b = color
    return min(RGB, key=lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2)


def freistellen(img):
    """Hintergrund per FLUTFUELLUNG vom Rand entfernen — verkraftet auch
    gemusterte Hintergruende (Streifen!): alles, was mit dem Bildrand
    zusammenhaengt und einer der dominanten Randfarben aehnelt, wird
    transparent; das Innere des Motivs bleibt unangetastet."""
    from collections import Counter, deque
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    rand = [px[x, 0][:3] for x in range(w)] + [px[x, h - 1][:3] for x in range(w)]          + [px[0, y][:3] for y in range(h)] + [px[w - 1, y][:3] for y in range(h)]
    # Dominante Randfarben (grob gerastert, damit Rauschen zusammenfaellt).
    grob = Counter(((r // 24, g // 24, b // 24) for r, g, b in rand))
    dominant = [k for k, n in grob.most_common(4) if n > len(rand) * 0.04]

    def ist_hintergrund(farbe):
        key = (farbe[0] // 24, farbe[1] // 24, farbe[2] // 24)
        return any(abs(key[0] - d[0]) <= 1 and abs(key[1] - d[1]) <= 1
                   and abs(key[2] - d[2]) <= 1 for d in dominant)

    gesehen = bytearray(w * h)
    schlange = deque()
    for x in range(w):
        schlange.append((x, 0)); schlange.append((x, h - 1))
    for y in range(h):
        schlange.append((0, y)); schlange.append((w - 1, y))
    while schlange:
        x, y = schlange.popleft()
        idx = y * w + x
        if gesehen[idx]:
            continue
        gesehen[idx] = 1
        if not ist_hintergrund(px[x, y][:3]):
            continue
        px[x, y] = (0, 0, 0, 0)
        if x > 0: schlange.append((x - 1, y))
        if x < w - 1: schlange.append((x + 1, y))
        if y > 0: schlange.append((x, y - 1))
        if y < h - 1: schlange.append((x, y + 1))
    return img


def entsprenkeln(img):
    """Nur die groesste zusammenhaengende Pixelinsel behalten — entfernt
    versprengte Hintergrund-Reste (Anti-Aliasing-Sprenkel)."""
    from collections import deque
    px = img.load()
    w, h = img.size
    labels = [[0] * w for _ in range(h)]
    inseln = []
    for sy in range(h):
        for sx in range(w):
            if labels[sy][sx] or px[sx, sy][3] < 128:
                continue
            insel = []
            schlange = deque([(sx, sy)])
            labels[sy][sx] = 1
            while schlange:
                x, y = schlange.popleft()
                insel.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not labels[ny][nx]                             and px[nx, ny][3] >= 128:
                        labels[ny][nx] = 1
                        schlange.append((nx, ny))
            inseln.append(insel)
    if not inseln:
        return img
    groesste = max(inseln, key=len)
    behalten = set(groesste)
    for insel in inseln:
        if insel is groesste:
            continue
        for x, y in insel:
            px[x, y] = (0, 0, 0, 0)
    return img


def zuschneiden(img):
    box = img.getbbox()
    if box is None:
        return img
    left, top, right, bottom = box
    w, h = right - left, bottom - top
    side = max(w, h)
    cx, cy = left + w // 2, top + h // 2
    return img.crop((cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2))


def verarbeiten(path, name):
    img = Image.open(path)
    img = freistellen(img)
    img = entsprenkeln(img)
    img = zuschneiden(img)
    # BOX statt NEAREST: mittelt die KI-Pixelbloecke » Details (Augen!)
    # ueberleben das Herunterrechnen, die Quantisierung schaerft danach.
    img = img.resize((SIZE, SIZE), Image.BOX)
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = (0, 0, 0, 0)
            else:
                nr, ng, nb = nearest((r, g, b))
                px[x, y] = (nr, ng, nb, 255)
    out = os.path.join(OUT_DIR, "%s.png" % name)
    img.save(out)
    print("OK:", out)
    return img


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    src = sys.argv[1]
    if os.path.isdir(src):
        for datei in sorted(os.listdir(src)):
            if datei.lower().endswith(".png"):
                name = sys.argv[2] + "_" + os.path.splitext(datei)[0] \
                    if len(sys.argv) > 2 else os.path.splitext(datei)[0]
                verarbeiten(os.path.join(src, datei), name)
    else:
        name = sys.argv[2] if len(sys.argv) > 2 else \
            os.path.splitext(os.path.basename(src))[0]
        verarbeiten(src, name)


if __name__ == "__main__":
    main()
