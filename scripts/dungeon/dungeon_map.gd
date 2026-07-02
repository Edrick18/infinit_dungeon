class_name DungeonMap
extends RefCounted
## Das Ergebnis der Dungeon-Generierung: begehbares Tile-Grid plus
## Spawn, Boss-Position, Gegner- und Truhen-Platzierungen.
## Wird nicht gespeichert — die DungeonCard (Seed) reicht, um exakt
## dieselbe Karte jederzeit wieder zu erzeugen.

const TILE_SIZE := 32

var width := 0
var height := 0
var cells := PackedByteArray()  ## 0 = Wand, 1 = Boden

var spawn := Vector2i.ZERO

## Nur auf der untersten Ebene gesetzt — der Boss wartet immer ganz unten.
var has_boss := false
var boss_cell := Vector2i(-1, -1)

## Auf allen anderen Ebenen: Treppe zur nächsttieferen Ebene.
var stairs_cell := Vector2i(-1, -1)

var enemies: Array[Dictionary] = []  ## {"id": int, "cell": Vector2i}
var chests: Array[Dictionary] = []   ## {"id": int, "cell": Vector2i, "gold": int}


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_floor(cell: Vector2i) -> bool:
	return in_bounds(cell) and cells[cell.y * width + cell.x] == 1


func set_floor(cell: Vector2i) -> void:
	cells[cell.y * width + cell.x] = 1


func is_walkable_px(point: Vector2) -> bool:
	return is_floor(Vector2i(floori(point.x / TILE_SIZE), floori(point.y / TILE_SIZE)))


static func cell_center_px(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE, TILE_SIZE) * 0.5


func floor_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in height:
		for x in width:
			if cells[y * width + x] == 1:
				result.append(Vector2i(x, y))
	return result


## Sichtlinie zwischen zwei Zellen per Bresenham: blockiert, sobald eine
## Zelle DAZWISCHEN eine Wand ist (Start/Ziel selbst zählen nicht als
## Blocker). Grundlage für Gegner-Wahrnehmung und Fog-of-War.
func has_line_of_sight(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var x0 := from_cell.x
	var y0 := from_cell.y
	var x1 := to_cell.x
	var y1 := to_cell.y
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var step_x := 1 if x0 < x1 else -1
	var step_y := 1 if y0 < y1 else -1
	var err := dx + dy
	# Obergrenze statt "while true", damit GDScript einen garantierten
	# Rückgabewert erkennt (die Linie erreicht das Ziel immer deutlich früher).
	var steps := (absi(dx) + absi(dy)) * 2 + 4
	for i in steps:
		var cell := Vector2i(x0, y0)
		if cell != from_cell and cell != to_cell and not is_floor(cell):
			return false
		if x0 == x1 and y0 == y1:
			return true
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += step_x
		if e2 <= dx:
			err += dx
			y0 += step_y
	return true


## BFS-Distanzen (in Tiles) von einer Startzelle über den Boden.
func distances_from(start: Vector2i) -> Dictionary:
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + dir
			if is_floor(next) and not dist.has(next):
				dist[next] = dist[current] + 1
				queue.append(next)
	return dist
