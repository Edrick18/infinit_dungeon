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
