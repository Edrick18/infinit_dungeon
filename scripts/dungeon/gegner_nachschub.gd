class_name GegnerNachschub
extends RefCounted
## Dynamische Gegner (Lutz 2026-10-14): Jede Ebene hat eine Höchstzahl
## gleichzeitiger Gegner (= so viele, wie der Generator anfangs verteilt).
## Gegner verschwinden nach einer Weile wieder (nicht, solange sie jagen
## oder in Sichtweite sind), und wird ein Platz frei — besiegt oder
## verschwunden —, taucht nach kurzer Zeit irgendwo weit weg ein neuer auf.
## So wird der Dungeon nie überfüllt und nie leergefegt.
##
## Der Bestand pro Ebene liegt im Run: run["gegner_by_floor"][str(ebene)] =
## [[id, zelle_x, zelle_y], …] — speicherbar und an Co-op-Gäste sendbar.

const LEBENSZEIT_MIN := 120.0     ## Sekunden, bis ein Gegner gehen darf
const LEBENSZEIT_MAX := 240.0
const NACHSCHUB_MIN := 8.0        ## Sekunden bis zum Nachrücken
const NACHSCHUB_MAX := 16.0
const MIN_ABSTAND_ZELLEN := 12    ## so weit weg vom Spieler tauchen neue auf
const VERSUCHE := 80


## Bestand dieser Ebene (legt ihn beim ersten Betreten aus dem Generator an).
## Besiegte (in `defeated`, als Ebenen-IDs) fliegen raus.
static func bestand(run: Dictionary, map: DungeonMap, floor_index: int, offset: int) -> Array:
	if not run.has("gegner_by_floor"):
		run["gegner_by_floor"] = {}
	var alle: Dictionary = run["gegner_by_floor"]
	var schluessel := str(floor_index)
	if not alle.has(schluessel):
		var liste := []
		for enemy in map.enemies:
			var cell: Vector2i = enemy["cell"]
			liste.append([int(enemy["id"]), cell.x, cell.y])
		alle[schluessel] = liste
	var defeated: Array = run.get("defeated", [])
	var bereinigt := []
	for eintrag in alle[schluessel]:
		if not (floor_index * offset + int(eintrag[0])) in defeated:
			bereinigt.append([int(eintrag[0]), int(eintrag[1]), int(eintrag[2])])
	alle[schluessel] = bereinigt
	return bereinigt


## Freie ID für einen neuen Gegner: über den Generator-IDs, nicht im
## Bestand und nicht als besiegt markiert; unter `offset` (Ebenen-Trennung).
## Ist alles verbraucht, werden alte Besiegt-Einträge dynamischer Gegner
## dieser Ebene aufgeräumt und von vorn begonnen.
static func neue_id(liste: Array, defeated: Array, floor_index: int,
		start_id: int, offset: int) -> int:
	var belegt := {}
	for eintrag in liste:
		belegt[int(eintrag[0])] = true
	for runde in 2:
		for id in range(start_id, offset):
			if not belegt.has(id) and not (floor_index * offset + id) in defeated:
				return id
		# Aufräumen: besiegte dynamische Gegner dieser Ebene vergessen.
		for id in range(start_id, offset):
			defeated.erase(floor_index * offset + id)
	return -1


## Zufällige Bodenzelle weit weg vom Spieler (und von belegten Zellen).
## Vector2i(-1, -1), wenn nichts passt.
static func spawn_zelle(map: DungeonMap, rng: RandomNumberGenerator,
		spieler_zelle: Vector2i, belegt: Array) -> Vector2i:
	for versuch in VERSUCHE:
		var cell := Vector2i(rng.randi_range(1, map.width - 2), rng.randi_range(1, map.height - 2))
		if not map.is_floor(cell):
			continue
		if absi(cell.x - spieler_zelle.x) + absi(cell.y - spieler_zelle.y) < MIN_ABSTAND_ZELLEN:
			continue
		if cell == map.stairs_cell or cell == map.boss_cell or cell == map.spawn or cell in belegt:
			continue
		return cell
	return Vector2i(-1, -1)


static func lebenszeit(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(LEBENSZEIT_MIN, LEBENSZEIT_MAX)


static func nachschub_zeit(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(NACHSCHUB_MIN, NACHSCHUB_MAX)
