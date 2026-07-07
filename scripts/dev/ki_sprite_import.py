# -*- coding: utf-8 -*-
"""KI-Sprite-Import: macht aus ComfyUI-Ausgaben spielfertige Sprites
(Standard 128x128, per KI_SIZE-Umgebungsvariable aenderbar).

Schritte pro Bild:
  1. Hintergrund freistellen (Flood-Fill + Saum/Despill/Taschen-Filter).
  2. Auf den Inhalt zuschneiden (Quadrat, zentriert).
  3. Herunterrechnen — nur deckende Pixel mitteln (kein Farbsaum).
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
# Vom letzten freistellen() erkannte Hintergrundfarben (fuer Sprenkel-Filter).
HINTERGRUND_FARBEN = []
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "eigene_sprites")
# Zielgroesse per Umgebungsvariable KI_SIZE (Standard 128 = Spielgroesse).
SIZE = int(os.environ.get("KI_SIZE", "128"))


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
    global HINTERGRUND_FARBEN
    HINTERGRUND_FARBEN = [(k[0] * 24 + 12, k[1] * 24 + 12, k[2] * 24 + 12)
        for k in dominant]

    def ist_hintergrund(farbe, locker=False):
        toleranz = 2 if locker else 1
        key = (farbe[0] // 24, farbe[1] // 24, farbe[2] // 24)
        return any(abs(key[0] - d[0]) <= toleranz and abs(key[1] - d[1]) <= toleranz
                   and abs(key[2] - d[2]) <= toleranz for d in dominant)

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
    # Saum-Reinigung: Halo-Pixel (halb Monster, halb Hintergrund) an der
    # Transparenz-Kante abtragen. Frontier, aber HART auf 8 Runden
    # begrenzt: unbegrenzt frisst sie sich durch Monster, deren Farbe
    # dem Hintergrund aehnelt (gruener Schleim auf gruenem BG).
    front = set()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0:
                    front.add((nx, ny))
    for _ in range(8):
        if not front:
            break
        abtragen = [p for p in front
                    if px[p][3] > 0 and ist_hintergrund(px[p][:3], locker=True)]
        for x, y in abtragen:
            px[x, y] = (0, 0, 0, 0)
        front = set()
        for x, y in abtragen:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0:
                    front.add((nx, ny))
    # Despill: hintergrundfarbige Pixel MITTEN im Motiv (eingeblutete
    # Hintergrundfarbe) aus den Nachbarfarben uebermalen.
    from collections import Counter as _Counter
    for _ in range(2):
        ersetzen = []
        for y in range(h):
            for x in range(w):
                if px[x, y][3] == 0 or not ist_hintergrund(px[x, y][:3]):
                    continue
                nachbarn = []
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if (dx or dy) and 0 <= nx < w and 0 <= ny < h:
                            farbe = px[nx, ny]
                            if farbe[3] > 0 and not ist_hintergrund(farbe[:3]):
                                nachbarn.append(farbe[:3])
                if nachbarn:
                    ersetzen.append((x, y, _Counter(nachbarn).most_common(1)[0][0]))
        if not ersetzen:
            break
        for x, y, farbe in ersetzen:
            px[x, y] = farbe + (255,)
    # Eingeschlossene Hintergrund-Taschen: grosse zusammenhaengende
    # bg-farbige Inseln IM Motiv (z. B. zwischen den Beinen), die keine
    # Verbindung zur Kante haben. Augen bleiben unter der Schwelle.
    from collections import deque as _dq
    schwelle = max(100, (w * h) // 10000)
    gesehen = set()
    for sy in range(h):
        for sx in range(w):
            if ((sx, sy) in gesehen or px[sx, sy][3] == 0
                    or not ist_hintergrund(px[sx, sy][:3])):
                continue
            komp = []
            rand = []
            q = _dq([(sx, sy)])
            gesehen.add((sx, sy))
            while q:
                x, y = q.popleft()
                komp.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h):
                        continue
                    nf = px[nx, ny]
                    if nf[3] > 0 and ist_hintergrund(nf[:3]):
                        if (nx, ny) not in gesehen:
                            gesehen.add((nx, ny))
                            q.append((nx, ny))
                    elif nf[3] > 0:
                        rand.append(nf[:3])
            if len(komp) >= schwelle and rand:
                fuellung = _Counter(rand).most_common(1)[0][0]
                for x, y in komp:
                    px[x, y] = fuellung + (255,)
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


def herunterrechnen(img, size):
    """Eigener BOX-Downscale, der NUR deckende Pixel mittelt.

    PILs resize mischt die RGB-Werte transparenter (= freigestellter)
    Pixel mit in den Durchschnitt — der alte Hintergrund faerbt dann
    saemtliche Randzellen (Gruensaum!). Hier zaehlt pro Zielzelle nur,
    was wirklich zum Monster gehoert; Zellen mit weniger als halber
    Deckung werden transparent."""
    w, h = img.size
    px = img.load()
    summen = [[[0, 0, 0, 0] for _ in range(size)] for _ in range(size)]
    gesamt = [[0] * size for _ in range(size)]
    for y in range(h):
        ty = y * size // h
        zeile_s, zeile_g = summen[ty], gesamt[ty]
        for x in range(w):
            tx = x * size // w
            r, g, b, a = px[x, y]
            zeile_g[tx] += 1
            if a >= 128:
                zelle = zeile_s[tx]
                zelle[0] += r
                zelle[1] += g
                zelle[2] += b
                zelle[3] += 1
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    opx = out.load()
    for ty in range(size):
        for tx in range(size):
            deckend = summen[ty][tx][3]
            if deckend * 2 <= gesamt[ty][tx]:
                continue
            r, g, b, _ = summen[ty][tx]
            opx[tx, ty] = (r // deckend, g // deckend, b // deckend, 255)
    return out


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
    # Mitteln statt NEAREST: Details (Augen!) ueberleben das
    # Herunterrechnen — aber nur deckende Pixel zaehlen (kein Gruensaum).
    img = herunterrechnen(img, SIZE)
    px = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = px[x, y]
            if a >= 128:
                px[x, y] = nearest((r, g, b)) + (255,)
    # Ausreisser-Filter: NUR einsame Pixel in Hintergrund-Farbtoenen
    # (uebrig gebliebene Sprenkel) aus der Umgebung uebermalen — echte
    # 1-Pixel-Details (Augen-Glanzpunkte!) bleiben unangetastet.
    from collections import Counter as _C
    bg_palette = {nearest(f) for f in HINTERGRUND_FARBEN}

    # Farbton-Verwandte dazunehmen: dunkler abgemischte Reste des
    # Hintergrunds (z. B. Dunkelgruen bei gruenem BG) landen nach der
    # Quantisierung auf ANDEREN Palettenfarben mit gleichem Farbton.
    # Nur fuer satte Hintergruende — Grau wuerde halbe Palette treffen.
    def _gleicher_ton(c, d):
        la = (c[0] * c[0] + c[1] * c[1] + c[2] * c[2]) ** 0.5 or 1.0
        lb = (d[0] * d[0] + d[1] * d[1] + d[2] * d[2]) ** 0.5 or 1.0
        return (c[0] * d[0] + c[1] * d[1] + c[2] * d[2]) / (la * lb) > 0.99
    for f in HINTERGRUND_FARBEN:
        if max(f) - min(f) > 60:
            for p in RGB:
                if _gleicher_ton(p, f):
                    bg_palette.add(p)

    def kantennah(x, y, radius=2):
        # Sitzt der Pixel dicht an der Transparenz-Kante?
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < SIZE and 0 <= ny < SIZE):
                    return True
                if px[nx, ny][3] == 0:
                    return True
        return False

    for _ in range(3):
        ersetzen = []
        for y in range(SIZE):
            for x in range(SIZE):
                farbe = px[x, y]
                if farbe[3] == 0 or farbe[:3] not in bg_palette:
                    continue
                nachbarn = []
                gleich = 0
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if (dx or dy) and 0 <= nx < SIZE and 0 <= ny < SIZE:
                            nf = px[nx, ny]
                            if nf[3] > 0 and nf[:3] not in bg_palette:
                                nachbarn.append(nf[:3])
                            if nf[3] > 0 and nf[:3] == farbe[:3]:
                                gleich += 1
                # Weg damit, wenn einsam ODER dicht an der Kante (Gruenreste
                # kleben immer am Rand — Augen sitzen tief im Inneren).
                if gleich <= 1 or kantennah(x, y):
                    if nachbarn:
                        ersetzen.append((x, y, _C(nachbarn).most_common(1)[0][0]))
                    else:
                        ersetzen.append((x, y, None))
        if not ersetzen:
            break
        for x, y, farbe in ersetzen:
            px[x, y] = (0, 0, 0, 0) if farbe is None else farbe + (255,)
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
