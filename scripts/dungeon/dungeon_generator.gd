class_name DungeonGenerator
extends RefCounted
## Prozedurale Dungeon-Generierung, komplett deterministisch aus dem Seed
## der DungeonCard: gleiche Karte = gleiches Layout, gleiche Gegner- und
## Truhen-Positionen — die Grundlage für wiederholbare, farmbare Karten.
##
## Verfahren: "Drunkard's Walk" — mehrere Läufer graben Boden aus dem Fels.
## Ergebnis ist garantiert zusammenhängend, organisch und höhlenartig.

const FLOOR_RATIO := 0.30       ## Anteil der Karte, der Boden wird
const WALKER_COUNT := 4         ## Läufer für verzweigtere Höhlen
const MIN_ENEMY_SPAWN_DIST := 8 ## Tiles Abstand der Gegner zum Spawn
const MIN_ENEMY_SPACING := 5    ## Tiles Abstand der Gegner zueinander
const MIN_CHEST_DIST := 5
const CHEST_COUNT := 3


## Erzeugt eine Ebene der Karte. Jede Ebene hat einen eigenen, aus dem
## Karten-Seed abgeleiteten Seed. Die unterste Ebene bekommt den Boss,
## alle anderen eine Treppe nach unten (jeweils am entferntesten Punkt).
static func generate(card: DungeonCard, floor_index := 0,
		width := 48, height := 36) -> DungeonMap:
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + floor_index * 31337

	var map := DungeonMap.new()
	map.width = width
	map.height = height
	map.cells.resize(width * height)

	_carve_floor(map, rng)
	map.spawn = Vector2i(width / 2, height / 2)

	var dist := map.distances_from(map.spawn)
	var landmark := _farthest_cell(dist)
	map.has_boss = floor_index >= card.floor_count - 1
	if map.has_boss:
		map.boss_cell = landmark
	else:
		map.stairs_cell = landmark
	_place_enemies(map, rng, dist, card.tier)
	_place_chests(map, rng, dist, card.tier)
	return map


static func _carve_floor(map: DungeonMap, rng: RandomNumberGenerator) -> void:
	var target := int(map.width * map.height * FLOOR_RATIO)
	var center := Vector2i(map.width / 2, map.height / 2)
	var walkers: Array[Vector2i] = []
	for i in WALKER_COUNT:
		walkers.append(center)

	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var carved := 0
	while carved < target:
		for i in walkers.size():
			var pos := walkers[i]
			if not map.is_floor(pos):
				map.set_floor(pos)
				carved += 1
			pos += dirs[rng.randi_range(0, 3)]
			# Rand bleibt Wand, damit niemand aus der Karte läuft.
			pos.x = clampi(pos.x, 1, map.width - 2)
			pos.y = clampi(pos.y, 1, map.height - 2)
			walkers[i] = pos


static func _farthest_cell(dist: Dictionary) -> Vector2i:
	var best := Vector2i.ZERO
	var best_dist := -1
	for cell in dist:
		if dist[cell] > best_dist:
			best_dist = dist[cell]
			best = cell
	return best


static func _place_enemies(map: DungeonMap, rng: RandomNumberGenerator,
		dist: Dictionary, tier: int) -> void:
	var enemy_count := 6 + tier
	var candidates := _shuffled_floor(map, rng)
	var placed: Array[Vector2i] = []
	var next_id := 0
	for cell in candidates:
		if placed.size() >= enemy_count:
			break
		if not dist.has(cell) or dist[cell] < MIN_ENEMY_SPAWN_DIST:
			continue
		if cell == map.boss_cell or cell == map.stairs_cell:
			continue
		var too_close := false
		for other in placed:
			if (cell - other).length() < MIN_ENEMY_SPACING:
				too_close = true
				break
		if too_close:
			continue
		placed.append(cell)
		map.enemies.append({"id": next_id, "cell": cell})
		next_id += 1


static func _place_chests(map: DungeonMap, rng: RandomNumberGenerator,
		dist: Dictionary, tier: int) -> void:
	var used: Array[Vector2i] = [map.boss_cell, map.stairs_cell]
	for enemy in map.enemies:
		used.append(enemy["cell"])
	var candidates := _shuffled_floor(map, rng)
	var next_id := 0
	for cell in candidates:
		if next_id >= CHEST_COUNT:
			break
		if not dist.has(cell) or dist[cell] < MIN_CHEST_DIST or cell in used:
			continue
		used.append(cell)
		map.chests.append({
			"id": next_id, "cell": cell,
			"gold": 20 + tier * 10 + rng.randi_range(0, 15),
		})
		next_id += 1


static func _shuffled_floor(map: DungeonMap, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells := map.floor_cells()
	# Fisher-Yates mit dem Karten-RNG (Array.shuffle() wäre nicht seed-stabil).
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	return cells
