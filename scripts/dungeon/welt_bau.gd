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
static func wand_hoehe(c: Vector2i) -> float:
	var h := 0.86 + float(absi(hash(c * 31 + Vector2i(3, 21))) % 7) * 0.025
	if absi(hash(c * 31 + Vector2i(5, 35))) % 19 == 0:
		h += 0.24
	return h


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
