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
SIZE = 32


def nearest(color):
    r, g, b = color
    return min(RGB, key=lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2)


def freistellen(img):
    """Ecken-Farbe (Hintergrund) transparent machen — mit Toleranz."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    bg = max(set(corners), key=corners.count)[:3]
    tol = 40
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if abs(r - bg[0]) <= tol and abs(g - bg[1]) <= tol and abs(b - bg[2]) <= tol:
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
