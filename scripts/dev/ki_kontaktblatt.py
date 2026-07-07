# -*- coding: utf-8 -*-
"""Kandidaten-Kontaktblatt: jagt ALLE grossen PNGs eines Ordners durch
die Import-Pipeline (Standard 128x128) und baut EIN nummeriertes
Uebersichtsblatt — Aussieben auf einen Blick statt 20 Dateien oeffnen.

Nutzung:
  python scripts/dev/ki_kontaktblatt.py [ordner]
  (Standard: ComfyUI-Output-Ordner)
Ausgabe: <ordner>/_kandidaten.png
"""
import os
import sys

from PIL import Image, ImageDraw

import ki_sprite_import as ksi

DEFAULT_DIR = r"C:\Users\Lutz\Documents\comfy\ComfyUI\output"
ZOOM = max(1, 256 // ksi.SIZE)
CELL = ksi.SIZE * ZOOM
PAD = 10
LABEL_H = 14
COLUMNS = 5


def main():
    ordner = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DIR
    kandidaten = []
    for datei in sorted(os.listdir(ordner)):
        if not datei.lower().endswith(".png") or datei.startswith("_"):
            continue
        pfad = os.path.join(ordner, datei)
        try:
            img = Image.open(pfad)
        except Exception:
            continue
        if img.size[0] < 256:
            continue  # 32er-Fehlversuche und Mini-Bilder ueberspringen
        img = ksi.freistellen(img)
        img = ksi.zuschneiden(img)
        img = ksi.herunterrechnen(img, ksi.SIZE)
        pal = ksi.sprite_palette(img)
        px = img.load()
        for y in range(ksi.SIZE):
            for x in range(ksi.SIZE):
                r, g, b, a = px[x, y]
                if a >= 128:
                    px[x, y] = ksi.naechste(pal, (r, g, b)) + (255,)
        kandidaten.append((datei, img))

    if not kandidaten:
        print("Keine 512er-PNGs in", ordner)
        return

    zeilen = (len(kandidaten) + COLUMNS - 1) // COLUMNS
    blatt = Image.new("RGBA",
        (COLUMNS * (CELL + PAD) + PAD, zeilen * (CELL + LABEL_H + PAD) + PAD),
        (36, 31, 49, 255))
    zeichnen = ImageDraw.Draw(blatt)
    for i, (datei, img) in enumerate(kandidaten):
        x = PAD + (i % COLUMNS) * (CELL + PAD)
        y = PAD + (i // COLUMNS) * (CELL + LABEL_H + PAD)
        blatt.alpha_composite(
            img.resize((CELL, CELL), Image.NEAREST), (x, y))
        # Nummer aus dem Dateinamen (sprite_00013_ » 13) als Label.
        nummer = "".join(ch for ch in datei if ch.isdigit()).lstrip("0") or "0"
        zeichnen.text((x + 2, y + CELL), "#" + nummer + " " + datei[:14],
            fill=(200, 200, 220, 255))
    ziel = os.path.join(ordner, "_kandidaten.png")
    blatt.save(ziel)
    print("OK: %d Kandidaten » %s" % (len(kandidaten), ziel))


if __name__ == "__main__":
    main()
