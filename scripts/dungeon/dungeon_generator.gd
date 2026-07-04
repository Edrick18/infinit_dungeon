class_name DungeonGenerator
extends RefCounted
## Prozedurale Dungeon-Generierung, komplett deterministisch aus dem Seed
## der DungeonCard: gleiche Karte = gleiches Layout, gleiche Gegner- und
## Truhen-Positionen — die Grundlage für wiederholbare, farmbare Karten.
##
## Drei Layout-Stile, pro Ebene deterministisch gewählt (Abwechslung!):
##   CAVES   — organische Höhlen (Drunkard's Walk)
##   ROOMS   — klassischer Dungeon: rechteckige Räume + Korridore
##   TUNNELS — langgezogenes, verwinkeltes Ganggeflecht

enum Layout { CAVES, ROOMS, TUNNELS }

## Dungeon-Events (KEINE Fallen — Design-Entscheidung): Schreine helfen,
## Opfersteine tauschen HP gegen Schätze, Risiko-Truhen locken mit dicker
## Beute — oder einem Mimic.
enum EventType { SHRINE_HEAL, SHRINE_MANA, SHRINE_POWER, SHRINE_WARD, SACRIFICE, RISK_CHEST }

const FLOOR_RATIO := 0.30       ## Zielanteil Boden (CAVES)
const TUNNEL_RATIO := 0.22      ## Zielanteil Boden (TUNNELS — enger)
const WALKER_COUNT := 4
const MIN_ENEMY_SPAWN_DIST := 8
const MIN_ENEMY_SPACING := 5
const MIN_CHEST_DIST := 5
const CHEST_COUNT := 3
const EVENT_COUNT := 2
const MIN_EVENT_DIST := 6


## Welcher Layout-Stil auf dieser Ebene liegt — deterministisch aus dem
## Karten-Seed, damit die Ebenen einer Karte abwechslungsreich, aber bei
## jedem Besuch identisch sind.
static func layout_for(card: DungeonCard, floor_index: int) -> Layout:
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + floor_index * 911
	return rng.randi_range(0, 2) as Layout


static func generate(card: DungeonCard, floor_index := 0,
		width := 48, height := 36) -> DungeonMap:
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + floor_index * 31337

	var map := DungeonMap.new()
	map.width = width
	map.height = height
	map.cells.resize(width * height)

	match layout_for(card, floor_index):
		Layout.CAVES:
			_carve_caves(map, rng)
		Layout.ROOMS:
			_carve_rooms(map, rng)
		Layout.TUNNELS:
			_carve_tunnels(map, rng)

	map.spawn = Vector2i(width / 2, height / 2)
	map.set_floor(map.spawn)
	# Vom Spawn aus unerreichbare Bodenzellen wieder zumauern — dort dürfen
	# nie Gegner, Truhen oder der Boss landen.
	_prune_unreachable(map)

	var dist := map.distances_from(map.spawn)
	var landmark := _farthest_cell(dist)
	map.has_boss = floor_index >= card.floor_count - 1
	if map.has_boss:
		map.boss_cell = landmark
	else:
		map.stairs_cell = landmark

	# Karten-Affixe verändern die Bevölkerung der Ebene.
	var enemy_count := 6 + card.tier
	if &"bevoelkert" in card.card_affix_ids:
		enemy_count += 3
	var chest_count := CHEST_COUNT
	if &"schatz" in card.card_affix_ids:
		chest_count += 2

	var event_count := EVENT_COUNT
	if card.tier >= 5:
		event_count += 1

	_place_enemies(map, rng, dist, enemy_count)
	_place_chests(map, rng, dist, card.tier, chest_count)
	_place_events(map, rng, dist, event_count)
	return map


# --- Layout-Stile --------------------------------------------------------------

## Organische Höhlen: mehrere Läufer graben sich durch den Fels.
static func _carve_caves(map: DungeonMap, rng: RandomNumberGenerator) -> void:
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
			pos.x = clampi(pos.x, 1, map.width - 2)
			pos.y = clampi(pos.y, 1, map.height - 2)
			walkers[i] = pos


## Klassischer Dungeon: rechteckige Räume, nacheinander mit L-förmigen
## Korridoren verbunden (plus Ringschluss für Schleifen im Layout).
static func _carve_rooms(map: DungeonMap, rng: RandomNumberGenerator) -> void:
	var centers: Array[Vector2i] = []
	var room_count := rng.randi_range(6, 9)

	# Erster Raum liegt immer um den Spawn in der Kartenmitte.
	var center := Vector2i(map.width / 2, map.height / 2)
	_carve_room(map, center, rng.randi_range(4, 7), rng.randi_range(4, 6))
	centers.append(center)

	for i in room_count - 1:
		var w := rng.randi_range(4, 8)
		var h := rng.randi_range(4, 7)
		var pos := Vector2i(
			rng.randi_range(2 + w / 2, map.width - 3 - w / 2),
			rng.randi_range(2 + h / 2, map.height - 3 - h / 2))
		_carve_room(map, pos, w, h)
		centers.append(pos)

	for i in centers.size() - 1:
		_carve_corridor(map, centers[i], centers[i + 1])
	# Ringschluss: letzter Raum zurück zum ersten → Schleifen statt Sackgassen-Baum.
	_carve_corridor(map, centers[centers.size() - 1], centers[0])


static func _carve_room(map: DungeonMap, center: Vector2i, w: int, h: int) -> void:
	for y in range(center.y - h / 2, center.y + (h + 1) / 2):
		for x in range(center.x - w / 2, center.x + (w + 1) / 2):
			var cell := Vector2i(clampi(x, 1, map.width - 2), clampi(y, 1, map.height - 2))
			map.set_floor(cell)


## L-förmiger, 2 Zellen breiter Korridor zwischen zwei Punkten.
static func _carve_corridor(map: DungeonMap, from: Vector2i, to: Vector2i) -> void:
	var pos := from
	while pos.x != to.x:
		pos.x += signi(to.x - pos.x)
		map.set_floor(Vector2i(clampi(pos.x, 1, map.width - 2), clampi(pos.y, 1, map.height - 2)))
		map.set_floor(Vector2i(clampi(pos.x, 1, map.width - 2), clampi(pos.y + 1, 1, map.height - 2)))
	while pos.y != to.y:
		pos.y += signi(to.y - pos.y)
		map.set_floor(Vector2i(clampi(pos.x, 1, map.width - 2), clampi(pos.y, 1, map.height - 2)))
		map.set_floor(Vector2i(clampi(pos.x + 1, 1, map.width - 2), clampi(pos.y, 1, map.height - 2)))


## Verwinkeltes Ganggeflecht: Läufer mit Richtungs-Trägheit graben lange,
## gewundene Gänge (~2 Zellen breit).
static func _carve_tunnels(map: DungeonMap, rng: RandomNumberGenerator) -> void:
	var target := int(map.width * map.height * TUNNEL_RATIO)
	var center := Vector2i(map.width / 2, map.height / 2)
	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

	var walkers: Array[Vector2i] = []
	var headings: Array[Vector2i] = []
	for i in 3:
		walkers.append(center)
		headings.append(dirs[rng.randi_range(0, 3)])

	var carved := 0
	while carved < target:
		for i in walkers.size():
			var pos := walkers[i]
			if not map.is_floor(pos):
				map.set_floor(pos)
				carved += 1
			# Gang verbreitern: eine Nachbarzelle quer zur Laufrichtung.
			var side := Vector2i(headings[i].y, headings[i].x)
			var widen := pos + side
			widen.x = clampi(widen.x, 1, map.width - 2)
			widen.y = clampi(widen.y, 1, map.height - 2)
			if not map.is_floor(widen):
				map.set_floor(widen)
				carved += 1
			# Trägheit: meist geradeaus, gelegentlich abbiegen.
			if rng.randf() < 0.25:
				headings[i] = dirs[rng.randi_range(0, 3)]
			pos += headings[i]
			if pos.x <= 1 or pos.x >= map.width - 2 or pos.y <= 1 or pos.y >= map.height - 2:
				headings[i] = dirs[rng.randi_range(0, 3)]
			pos.x = clampi(pos.x, 1, map.width - 2)
			pos.y = clampi(pos.y, 1, map.height - 2)
			walkers[i] = pos


## Alles, was vom Spawn aus nicht erreichbar ist, wird wieder Wand.
static func _prune_unreachable(map: DungeonMap) -> void:
	var dist := map.distances_from(map.spawn)
	for cell in map.floor_cells():
		if not dist.has(cell):
			map.cells[cell.y * map.width + cell.x] = 0


static func _farthest_cell(dist: Dictionary) -> Vector2i:
	var best := Vector2i.ZERO
	var best_dist := -1
	for cell in dist:
		if dist[cell] > best_dist:
			best_dist = dist[cell]
			best = cell
	return best


static func _place_enemies(map: DungeonMap, rng: RandomNumberGenerator,
		dist: Dictionary, enemy_count: int) -> void:
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
		dist: Dictionary, tier: int, chest_count: int) -> void:
	var used: Array[Vector2i] = [map.boss_cell, map.stairs_cell]
	for enemy in map.enemies:
		used.append(enemy["cell"])
	var candidates := _shuffled_floor(map, rng)
	var next_id := 0
	for cell in candidates:
		if next_id >= chest_count:
			break
		if not dist.has(cell) or dist[cell] < MIN_CHEST_DIST or cell in used:
			continue
		used.append(cell)
		map.chests.append({
			"id": next_id, "cell": cell,
			"gold": 20 + tier * 10 + rng.randi_range(0, 15),
		})
		next_id += 1


## Events deterministisch platzieren (gleiche Karte = gleiche Events an
## gleichen Orten). Gewichtung: Schreine häufig, Risiko-Truhen und
## Opfersteine seltener.
static func _place_events(map: DungeonMap, rng: RandomNumberGenerator,
		dist: Dictionary, event_count: int) -> void:
	var used: Array[Vector2i] = [map.boss_cell, map.stairs_cell]
	for enemy in map.enemies:
		used.append(enemy["cell"])
	for chest in map.chests:
		used.append(chest["cell"])
	var candidates := _shuffled_floor(map, rng)
	var next_id := 0
	for cell in candidates:
		if next_id >= event_count:
			break
		if not dist.has(cell) or dist[cell] < MIN_EVENT_DIST or cell in used:
			continue
		used.append(cell)
		map.events.append({"id": next_id, "cell": cell, "type": _roll_event_type(rng)})
		next_id += 1


static func _roll_event_type(rng: RandomNumberGenerator) -> EventType:
	var roll := rng.randf()
	if roll < 0.5:
		return [EventType.SHRINE_HEAL, EventType.SHRINE_MANA,
			EventType.SHRINE_POWER, EventType.SHRINE_WARD][rng.randi_range(0, 3)]
	if roll < 0.8:
		return EventType.RISK_CHEST
	return EventType.SACRIFICE


static func _shuffled_floor(map: DungeonMap, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells := map.floor_cells()
	# Fisher-Yates mit dem Karten-RNG (Array.shuffle() wäre nicht seed-stabil).
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	return cells
