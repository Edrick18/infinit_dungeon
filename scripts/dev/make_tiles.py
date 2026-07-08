# -*- coding: utf-8 -*-
"""Konstruiertes Tile-Set: Objekte fuer den Dungeon (32x32, transparent,
mit Outline) — im selben ruhigen Stil wie Boden/Wand. Aenderungen hier
sind Zahlen, kein Wuerfeln: einfach anpassen und neu laufen lassen.

Nutzung:  python scripts/dev/make_tiles.py
Ausgabe:  assets/eigene_sprites/tile_*.png + _tiles_vorschau.png
"""
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "eigene_sprites")
OUTLINE = (20, 20, 31, 255)


def neu():
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def umranden(img):
    """1px-Outline um alle deckenden Flaechen (wie die Monster-Pipeline)."""
    px = img.load()
    kontur = []
    for y in range(32):
        for x in range(32):
            if px[x, y][3] == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < 32 and 0 <= ny < 32) or px[nx, ny][3] == 0:
                    kontur.append((x, y))
                    break
    for x, y in kontur:
        px[x, y] = OUTLINE
    return img


def treppe():
    """Abgang nach unten: dunkler Schacht mit drei Stufen."""
    img, d = neu()
    d.rectangle([4, 4, 27, 27], fill=(24, 22, 32, 255))          # Schacht
    d.rectangle([6, 6, 25, 11], fill=(120, 116, 124, 255))       # Stufe 1
    d.rectangle([6, 11, 25, 12], fill=(70, 67, 78, 255))
    d.rectangle([8, 13, 23, 17], fill=(96, 92, 100, 255))        # Stufe 2
    d.rectangle([8, 17, 23, 18], fill=(56, 53, 64, 255))
    d.rectangle([10, 19, 21, 22], fill=(72, 69, 78, 255))        # Stufe 3
    d.rectangle([12, 23, 19, 25], fill=(44, 42, 52, 255))        # tiefste Stufe
    return umranden(img)


def _truhe(holz, holz_hell, band, schloss):
    img, d = neu()
    d.rectangle([5, 12, 26, 26], fill=holz)                       # Korpus
    d.rectangle([5, 8, 26, 14], fill=holz_hell)                   # Deckel
    d.rectangle([5, 14, 26, 15], fill=(0, 0, 0, 60))              # Deckelfuge
    d.rectangle([8, 8, 10, 26], fill=band)                        # Band links
    d.rectangle([21, 8, 23, 26], fill=band)                       # Band rechts
    d.rectangle([14, 14, 17, 19], fill=schloss)                   # Schloss
    d.point((15, 17), fill=(20, 20, 31, 255))                     # Schluesselloch
    return umranden(img)


def truhe():
    return _truhe((122, 86, 52, 255), (140, 102, 62, 255),
                  (88, 88, 100, 255), (208, 172, 92, 255))


def risikotruhe():
    img = _truhe((150, 118, 48, 255), (176, 142, 60, 255),
                 (208, 172, 92, 255), (216, 70, 84, 255))
    px = img.load()
    px[15, 16] = (244, 122, 132, 255)  # Glanzpunkt auf dem Juwel
    return img


def schrein():
    """Steinbecken mit leuchtendem Wasser."""
    img, d = neu()
    d.rectangle([10, 20, 21, 27], fill=(96, 92, 100, 255))        # Sockel
    d.rectangle([8, 26, 23, 27], fill=(112, 108, 116, 255))       # Fuss
    d.ellipse([5, 8, 26, 20], fill=(120, 116, 124, 255))          # Becken
    d.ellipse([8, 10, 23, 17], fill=(62, 200, 176, 255))          # Wasser
    d.ellipse([11, 11, 16, 13], fill=(138, 244, 220, 255))        # Glanz
    return umranden(img)


def altar():
    """Dunkler Opferstein mit Runen und Flecken."""
    img, d = neu()
    d.rectangle([7, 16, 24, 26], fill=(58, 56, 66, 255))          # Block
    d.rectangle([5, 12, 26, 17], fill=(74, 71, 82, 255))          # Platte
    d.rectangle([5, 17, 26, 18], fill=(38, 36, 46, 255))          # Plattenschatten
    for rx in (9, 15, 21):                                        # Runen
        d.point((rx, 21), fill=(216, 70, 84, 255))
        d.point((rx, 22), fill=(216, 70, 84, 255))
        d.point((rx + 1, 21), fill=(216, 70, 84, 255))
    d.ellipse([8, 13, 12, 15], fill=(96, 39, 51, 255))            # Fleck
    d.ellipse([18, 14, 21, 16], fill=(96, 39, 51, 255))
    return umranden(img)


def fass():
    img, d = neu()
    d.rectangle([8, 8, 23, 26], fill=(122, 86, 52, 255))
    d.rectangle([9, 8, 12, 26], fill=(140, 102, 62, 255))         # Lichtseite
    d.rectangle([8, 11, 23, 12], fill=(88, 88, 100, 255))         # Ring oben
    d.rectangle([8, 21, 23, 22], fill=(88, 88, 100, 255))         # Ring unten
    d.rectangle([8, 8, 23, 9], fill=(96, 66, 40, 255))            # Deckelrand
    return umranden(img)


def felsbrocken():
    img, d = neu()
    d.polygon([(8, 25), (5, 18), (9, 10), (17, 7), (25, 12), (26, 21),
               (20, 26)], fill=(108, 104, 112, 255))
    d.polygon([(9, 12), (16, 8), (22, 12), (14, 15)], fill=(130, 126, 132, 255))
    d.line([(12, 18), (17, 22)], fill=(84, 81, 90, 255))
    return umranden(img)


def knochen():
    img, d = neu()
    d.ellipse([8, 14, 17, 22], fill=(222, 216, 202, 255))         # Schaedel
    d.rectangle([10, 20, 15, 23], fill=(222, 216, 202, 255))      # Kiefer
    d.point((11, 17), fill=(20, 20, 31, 255))                     # Augen
    d.point((14, 17), fill=(20, 20, 31, 255))
    d.line([(19, 24), (26, 20)], fill=(222, 216, 202, 255), width=2)  # Knochen
    d.ellipse([17, 22, 20, 25], fill=(222, 216, 202, 255))
    d.ellipse([25, 18, 28, 21], fill=(222, 216, 202, 255))
    return umranden(img)


def amboss():
    img, d = neu()
    d.rectangle([11, 22, 20, 26], fill=(58, 56, 66, 255))         # Fuss
    d.rectangle([8, 19, 23, 22], fill=(74, 71, 82, 255))          # Taille
    d.rectangle([5, 13, 26, 19], fill=(96, 92, 100, 255))         # Koerper
    d.polygon([(5, 13), (5, 18), (2, 16)], fill=(96, 92, 100, 255))  # Horn
    d.rectangle([5, 13, 26, 14], fill=(120, 116, 124, 255))       # Lichtkante
    return umranden(img)


def pilz():
    img, d = neu()
    d.rectangle([13, 18, 18, 26], fill=(222, 216, 202, 255))      # Stiel
    d.ellipse([8, 9, 23, 20], fill=(216, 70, 84, 255))            # Hut
    d.ellipse([11, 11, 14, 13], fill=(244, 212, 176, 255))        # Punkte
    d.ellipse([17, 13, 20, 15], fill=(244, 212, 176, 255))
    return umranden(img)


def grabstein():
    img, d = neu()
    d.rectangle([10, 12, 21, 26], fill=(108, 104, 112, 255))
    d.ellipse([10, 7, 21, 17], fill=(108, 104, 112, 255))
    d.rectangle([10, 12, 12, 26], fill=(126, 122, 130, 255))      # Lichtseite
    d.line([(14, 13), (17, 13)], fill=(58, 56, 66, 255))          # Inschrift
    d.line([(13, 16), (18, 16)], fill=(58, 56, 66, 255))
    d.line([(14, 19), (17, 19)], fill=(58, 56, 66, 255))
    return umranden(img)


ALLE = {
    "tile_treppe": treppe, "tile_truhe": truhe, "tile_risikotruhe": risikotruhe,
    "tile_schrein": schrein, "tile_altar": altar, "tile_fass": fass,
    "tile_felsbrocken": felsbrocken, "tile_knochen": knochen,
    "tile_amboss": amboss, "tile_pilz": pilz, "tile_grabstein": grabstein,
}

if __name__ == "__main__":
    fertig = {}
    for name, bauen in ALLE.items():
        img = bauen()
        img.save(os.path.join(OUT, name + ".png"))
        fertig[name] = img
        print(name)
    # Vorschau-Blatt auf Bodenkacheln, 3x vergroessert
    boden = Image.open(os.path.join(OUT, "tile_boden_1.png")).convert("RGBA")
    n = len(fertig)
    blatt = Image.new("RGBA", (n * 100 + 4, 104), (36, 31, 49, 255))
    for i, (name, img) in enumerate(fertig.items()):
        zelle = Image.new("RGBA", (32, 32))
        zelle.alpha_composite(boden)
        zelle.alpha_composite(img)
        blatt.alpha_composite(zelle.resize((96, 96), Image.NEAREST), (4 + i * 100, 4))
    blatt.save(os.path.join(OUT, "_tiles_vorschau.png"))
    print("vorschau ok")
