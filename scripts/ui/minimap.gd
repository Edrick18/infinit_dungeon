class_name Minimap
extends Control
## Ecken-Minimap im Dungeon: zeichnet die ERKUNDETEN Zellen (= schon mal im
## Bild gewesen), den Spieler, Treppe/Boss und ungeöffnete Truhen/Events.
## Liest direkt aus der Dungeon-Szene — reine Anzeige, kein Gameplay.

const CELL := 2.0

const COLOR_BG := Color(0.0, 0.0, 0.0, 0.4)
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


func _draw() -> void:
	if dungeon == null or dungeon.map == null:
		return
	var map: DungeonMap = dungeon.map
	draw_rect(Rect2(Vector2.ZERO, Vector2(map.width, map.height) * CELL), COLOR_BG)

	for cell in dungeon._explored_cells:
		var color := COLOR_FLOOR if map.is_floor(cell) else COLOR_WALL
		draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)), color)

	# Treppe/Boss nur, wenn schon gesehen — die Minimap verrät nichts Neues.
	if map.stairs_cell.x >= 0 and dungeon._explored_cells.has(map.stairs_cell):
		_marker(map.stairs_cell, COLOR_STAIRS)
	if map.has_boss and dungeon._boss_alive and dungeon._explored_cells.has(map.boss_cell):
		_marker(map.boss_cell, COLOR_BOSS)

	for chest in dungeon._chests:
		var cell: Vector2i = dungeon._pos_to_cell(chest["pos"])
		if dungeon._explored_cells.has(cell):
			_marker(cell, LootGenerator.RARITY_COLORS.get(chest["rarity"], Color.WHITE))
	for event in dungeon._events:
		var cell: Vector2i = dungeon._pos_to_cell(event["pos"])
		if dungeon._explored_cells.has(cell):
			_marker(cell, EVENT_FARBEN.get(event["type"], Color.WHITE))
	# Gegner nur, wenn gerade im Bild.
	for enemy in dungeon._enemies:
		var cell: Vector2i = dungeon._pos_to_cell(enemy["pos"])
		if dungeon._visible_cells.has(cell):
			_marker(cell, COLOR_ENEMY)

	_marker(dungeon._pos_to_cell(dungeon.player_pos), COLOR_PLAYER)


## Etwas größerer Punkt für wichtige Marker (überzeichnet die Bodenzelle).
func _marker(cell: Vector2i, color: Color) -> void:
	draw_rect(Rect2(Vector2(cell) * CELL - Vector2(1, 1),
		Vector2(CELL + 2, CELL + 2)), color)
