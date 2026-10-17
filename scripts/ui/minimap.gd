class_name Minimap
extends Control
## Ecken-Minimap im Dungeon: zeichnet die ERKUNDETEN Zellen (= schon mal im
## Bild gewesen), den Spieler, Treppe/Boss und ungeöffnete Truhen/Events.
## Liest direkt aus der Dungeon-Szene — reine Anzeige, kein Gameplay.
## Gedreht wie die 3D-Ansicht: Laufen nach oben = auf der Minimap nach oben.

const CELL := 2.0
## Größte Kantenlänge der gedrehten Karte in Pixeln.
const MAX_GROESSE := 210.0

const COLOR_BG := Color(0.04, 0.04, 0.1, 0.78)
const COLOR_RAND := Color(0.91, 0.71, 0.29, 0.7)
const COLOR_FLOOR := Color(0.55, 0.55, 0.72, 0.9)
const COLOR_WALL := Color(0.16, 0.16, 0.26, 0.9)
const COLOR_PLAYER := Color(1.0, 1.0, 1.0)
const COLOR_STAIRS := Color(0.3, 0.85, 0.9)
const COLOR_BOSS := Color(0.75, 0.35, 0.95)
const COLOR_ENEMY := Color(0.9, 0.35, 0.3)
const EVENT_FARBEN := {
	DungeonGenerator.EventType.SHRINE_HEAL: Color(0.7, 1.0, 0.7),
	DungeonGenerator.EventType.SHRINE_MANA: Color(0.6, 0.8, 1.0),
	DungeonGenerator.EventType.SHRINE_POWER: Color(1.0, 0.7, 0.5),
	DungeonGenerator.EventType.SHRINE_WARD: Color(1.0, 0.95, 0.6),
	DungeonGenerator.EventType.SACRIFICE: Color(1.0, 0.6, 0.6),
	DungeonGenerator.EventType.RISK_CHEST: Color.WHITE,
}

var dungeon: Node2D  ## die Dungeon-Szene (liefert map/explored/…)


## Bild einer Karten-Einheit in x bzw. y auf der Minimap — dieselben Achsen
## wie die Bildschirm-Steuerung (oben = Blickrichtung der Kamera).
static func _achsen() -> Array[Vector2]:
	var k := DungeonWelt3D.KAMERA_RICHTUNG
	var vor := Vector2(-k.x, -k.z).normalized()
	var rechts := Vector2(-vor.y, vor.x)
	return [Vector2(rechts.x, -vor.x), Vector2(rechts.y, -vor.y)]


## Zellgröße, Bildgröße und Ursprung der gedrehten Karte (Raute im Feld).
static func masse(map: DungeonMap) -> Dictionary:
	var achsen := _achsen()
	var ecken: Array[Vector2] = [Vector2.ZERO, achsen[0] * map.width, achsen[1] * map.height,
		achsen[0] * map.width + achsen[1] * map.height]
	var lo := ecken[0]
	var hi := ecken[0]
	for e in ecken:
		lo = lo.min(e)
		hi = hi.max(e)
	var zelle := minf(CELL, MAX_GROESSE / maxf(hi.x - lo.x, hi.y - lo.y))
	return {"zelle": zelle, "groesse": (hi - lo) * zelle, "ursprung": -lo * zelle}


func _draw() -> void:
	if dungeon == null or dungeon.map == null:
		return
	var map: DungeonMap = dungeon.map
	var m := masse(map)
	var achsen := _achsen()
	var zelle: float = m["zelle"]
	draw_set_transform_matrix(Transform2D(achsen[0] * zelle, achsen[1] * zelle, m["ursprung"]))
	draw_rect(Rect2(Vector2.ZERO, Vector2(map.width, map.height)), COLOR_BG)
	draw_rect(Rect2(Vector2.ZERO, Vector2(map.width, map.height)), COLOR_RAND, false, 1.0 / zelle)

	for cell in dungeon._explored_cells:
		var color := COLOR_FLOOR if map.is_floor(cell) else COLOR_WALL
		draw_rect(Rect2(Vector2(cell), Vector2.ONE), color)

	# Treppe/Boss nur, wenn schon gesehen — die Minimap verrät nichts Neues.
	if map.stairs_cell.x >= 0 and dungeon._explored_cells.has(map.stairs_cell):
		_marker(map.stairs_cell, COLOR_STAIRS)
	if map.has_boss and dungeon._boss_alive and dungeon._explored_cells.has(map.boss_cell):
		_marker(map.boss_cell, COLOR_BOSS)

	for chest in dungeon._chests:
		var cell: Vector2i = dungeon._pos_to_cell(chest["pos"])
		if dungeon._explored_cells.has(cell):
			_marker(cell, LootGenerator.RARITY_COLORS.get(chest["rarity"], Color.WHITE))
	if not dungeon._tresor.is_empty():
		var tresor_zelle: Vector2i = dungeon._pos_to_cell(dungeon._tresor["pos"])
		if dungeon._explored_cells.has(tresor_zelle):
			_marker(tresor_zelle, UiTheme.GOLD, 0.9)
	for event in dungeon._events:
		var cell: Vector2i = dungeon._pos_to_cell(event["pos"])
		if dungeon._explored_cells.has(cell):
			_marker(cell, EVENT_FARBEN.get(event["type"], Color.WHITE))
	# Gegner nur, wenn gerade im Bild.
	for enemy in dungeon._enemies:
		var cell: Vector2i = dungeon._pos_to_cell(enemy["pos"])
		if dungeon._visible_cells.has(cell):
			_marker(cell, COLOR_ENEMY)

	_marker(dungeon._pos_to_cell(dungeon.player_pos), COLOR_PLAYER, 1.0)


## Etwas größerer Punkt für wichtige Marker (überzeichnet die Bodenzelle).
func _marker(cell: Vector2i, color: Color, rand := 0.6) -> void:
	draw_rect(Rect2(Vector2(cell) - Vector2(rand, rand), Vector2.ONE * (1.0 + rand * 2.0)), color)
