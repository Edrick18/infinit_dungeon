class_name WeltBau
extends RefCounted
## Reine Funktionen der Dungeon-Darstellung (DungeonWelt3D) — ohne Szene und
## ohne Autoloads, damit die Selbsttests sie headless prüfen können.

## Licht-Pool: Laterne + POOL_GROESSE Fackellichter bleiben unter
## max_lights_per_object = 8 (Compatibility; der Boden-MultiMesh ist EIN
## Objekt mit dem AABB der ganzen Karte) und weit unter
## max_renderable_lights = 32 — egal, wie viele Fackeln die Karte hat.
const POOL_GROESSE := 6
const POOL_REICHWEITE := 13.0  ## weiter vom Kamera-Ziel entfernt bleibt eine Fackel dunkel
## Lauf-Hopser des Helden: Sprünge pro Sekunde und Höhe.
const HOPSER_TEMPO := 3.4
const HOPSER_HOEHE := 0.06

## Wandhöhe je Zelle (Körper ohne Sockel/Deckel): leichter Jitter,
## vereinzelt ein höherer Mauerzahn — deterministisch aus der Zelle.
## zacken (BiomStil "wand_zacken", Karten-Variante „Zerklüfteter“) streut
## die Höhen zusätzlich: 0 = wie bisher.
static func wand_hoehe(c: Vector2i, zacken := 0.0) -> float:
	var h := 0.86 + float(absi(hash(c * 31 + Vector2i(3, 21))) % 7) * 0.025
	if absi(hash(c * 31 + Vector2i(5, 35))) % 19 == 0:
		h += 0.24
	if zacken > 0.0:
		h += (float(absi(hash(c * 29 + Vector2i(11, 2))) % 9) / 8.0 - 0.35) * zacken
	return maxf(0.6, h)


## Licht-Pool: Indizes der höchstens `anzahl` nächsten Orte zur Mitte
## (aufsteigend nach Abstand), nur innerhalb der Reichweite.
static func pool_auswahl(orte: Array[Vector3], mitte: Vector3, anzahl: int, reichweite: float) -> Array[int]:
	var kandidaten: Array[Vector2] = []  # (Abstand², Index)
	for i in orte.size():
		var d2 := orte[i].distance_squared_to(mitte)
		if d2 <= reichweite * reichweite:
			kandidaten.append(Vector2(d2, i))
	kandidaten.sort()
	var auswahl: Array[int] = []
	for k in mini(anzahl, kandidaten.size()):
		auswahl.append(int(kandidaten[k].y))
	return auswahl


## Phase des Lauf-Hopsers: läuft beim Gehen weiter, beim Stehen wird der
## angefangene Sprung zu Ende gebracht (Ganzzahl = am Boden).
static func naechster_hopser(phase: float, laeuft: bool, delta: float) -> float:
	if laeuft:
		return phase + delta * HOPSER_TEMPO
	var ziel := ceilf(phase - 0.0001)
	return minf(ziel, phase + delta * HOPSER_TEMPO)


## Wandkrone (Biom-Kulisse) nur auf einem Teil der Wände — per Zell-Hash.
static func hat_krone(c: Vector2i, anteil: float) -> bool:
	return float(absi(hash(c * 29 + Vector2i(17, 3))) % 1000) / 1000.0 < anteil


## Kronen-Variante einer Wand (Index in der Liste des Bioms).
static func kronen_variante(c: Vector2i, anzahl: int) -> int:
	return absi(hash(c * 7 + Vector2i(31, 11))) % maxi(1, anzahl)


## Boss-Raum aus dem Grundriss gelesen (nicht aus Generator-Konstanten): der
## zusammenhängende Bodenblock um die Boss-Zelle — oben/unten über die
## Boss-Spalte, rechts über die Boss-Zeile, links entlang der obersten Reihe
## (der Gang mündet mittig, nie in der obersten Reihe). Leer ohne Boss.
static func boss_raum(map: DungeonMap) -> Rect2i:
	if not map.has_boss or not map.is_floor(map.boss_cell):
		return Rect2i()
	var b := map.boss_cell
	var x1 := b.x
	while map.is_floor(Vector2i(x1 + 1, b.y)):
		x1 += 1
	var y0 := b.y
	while map.is_floor(Vector2i(b.x, y0 - 1)):
		y0 -= 1
	var y1 := b.y
	while map.is_floor(Vector2i(b.x, y1 + 1)):
		y1 += 1
	var x0 := b.x
	while map.is_floor(Vector2i(x0 - 1, y0)):
		x0 -= 1
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


## Zeilen, in denen der Gang links in den Raum mündet ([min, max], leer ohne).
static func _gang_zeilen(map: DungeonMap, raum: Rect2i) -> Array[int]:
	var zeilen: Array[int] = []
	for y in range(raum.position.y, raum.end.y):
		if map.is_floor(Vector2i(raum.position.x - 1, y)):
			zeilen.append(y)
	return zeilen


## Feuerschalen der Boss-Arena: vier Raumecken und je eine links und rechts
## neben der Gangmündung — nie auf der Boss-Zelle oder in der Mündung.
static func boss_schalen(map: DungeonMap, raum: Rect2i) -> Array[Vector2i]:
	var zellen: Array[Vector2i] = []
	if raum.size.x <= 0:
		return zellen
	var x0 := raum.position.x
	var x1 := raum.end.x - 1
	var y0 := raum.position.y
	var y1 := raum.end.y - 1
	for z in [Vector2i(x0, y0), Vector2i(x1, y0), Vector2i(x0, y1), Vector2i(x1, y1)]:
		zellen.append(z)
	var gang := _gang_zeilen(map, raum)
	if not gang.is_empty():
		for z in [Vector2i(x0, gang.min() - 1), Vector2i(x0, gang.max() + 1)]:
			if raum.has_point(z) and not zellen.has(z):
				zellen.append(z)
	var frei: Array[Vector2i] = []
	for z in zellen:
		if z != map.boss_cell and map.is_floor(z):
			frei.append(z)
	return frei


## Gangzelle direkt vor der Raummündung (Mitte), sonst (-1, -1).
static func boss_eingang(map: DungeonMap, raum: Rect2i) -> Vector2i:
	var gang := _gang_zeilen(map, raum)
	if gang.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(raum.position.x - 1, (gang.min() + gang.max()) / 2)
