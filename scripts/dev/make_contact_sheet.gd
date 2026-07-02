extends SceneTree
## Dev-Werkzeug: baut einen 4x vergrößerten Kontaktbogen aller Kenney-Tiles
## mit Rasterlinien, um Tile-Indizes visuell zuzuordnen.

const TILE_DIR := "res://assets/kenney_tiny_dungeon/Tiles"
const OUT := "res://assets/kenney_tiny_dungeon/contact_sheet.png"
const COLS := 12
const SCALE := 4


func _init() -> void:
	var dir := DirAccess.open(TILE_DIR)
	var names: Array[String] = []
	for file in dir.get_files():
		if file.ends_with(".png"):
			names.append(file)
	names.sort()
	var rows := (names.size() + COLS - 1) / COLS
	var cell := 16 * SCALE + 2
	var sheet := Image.create(COLS * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.18))
	for i in names.size():
		var tile := Image.load_from_file(TILE_DIR + "/" + names[i])
		tile.convert(Image.FORMAT_RGBA8)
		tile.resize(16 * SCALE, 16 * SCALE, Image.INTERPOLATE_NEAREST)
		sheet.blend_rect(tile, Rect2i(0, 0, 16 * SCALE, 16 * SCALE),
			Vector2i((i % COLS) * cell + 1, (i / COLS) * cell + 1))
	sheet.save_png(OUT)
	print("OK: %d Tiles, %d Zeilen" % [names.size(), rows])
	quit(0)
