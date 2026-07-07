extends SceneTree
## Eigene Pixel-Art aus handgesetzten Zeichen-Grids (16×16) — jedes Zeichen
## eine Farbe der Hauspalette. Rendert Einzel-PNGs nach
## assets/eigene_sprites/ und ein 8×-vergrößertes Vorschau-Blatt.
##   godot --headless -s scripts/dev/make_own_sprites.gd

const OUT_DIR := "res://assets/eigene_sprites"
const PREVIEW := "res://assets/eigene_sprites/_vorschau.png"
const SCALE := 8

## Hauspalette „Infinit Dungeon“: tiefe Nachtblau-Basis, Gold-Akzent.
const PALETTE := {
	"#": Color("14141f"),  # Outline
	"K": Color("3a3a4e"), "k": Color("6a6a84"), "L": Color("9a9ab4"),
	"W": Color("e8e8f4"),
	"G": Color("e8b44a"), "g": Color("a87c2a"),
	"R": Color("d84654"), "r": Color("8a2733"),
	"B": Color("4a7ad8"), "b": Color("2a4a8a"),
	"C": Color("3ec8b0"), "c": Color("1f7a6a"),
	"P": Color("9a5ad8"), "p": Color("5a2a8a"),
	"N": Color("5ac858"), "n": Color("2a7a30"),
	"O": Color("e87c3a"), "o": Color("9a4a1f"),
	"S": Color("e8b48a"), "s": Color("b0785a"),
	"H": Color("7a5a3a"), "h": Color("4e3a26"),
	"Y": Color("f4e04a"),
}

## --- Handgesetzte Sprites (16 Zeilen à 16 Zeichen, '.' = transparent) -------

const SPRITES := {
	# ============ HELDEN (Chibi: großer Kopf, kompakter Körper) ============
	"held_ritter": [
		"................",
		".....######.....",
		"....#KkkkkK#....",
		"...#kLLLLLLk#...",
		"...#kL#LL#Lk#...",
		"...#kLLLLLLk#...",
		"...#SkSSSSkS#...",
		"....#SSssSS#....",
		".....#KKKK#.....",
		"...##KGGGGK##...",
		"..#kK#GggG#Kk#..",
		"..#S#KGGGGK#S#..",
		"....#KK##KK#....",
		"....#kK##Kk#....",
		"...##kk##kk##...",
		"...############.",
	],
	"held_magier": [
		"................",
		".......##.......",
		"......#PP#......",
		".....#PPPP#.....",
		"....#PpPPpP#....",
		"...##PPPPPP##...",
		"..#PPpSSSSpPP#..",
		".....#S##S#.....",
		".....#SSSS#.....",
		"....##pPPp##....",
		"...#G#PPPP#Y#...",
		"...#G#pPPp#Y#...",
		"...#G#PPPP##....",
		"....#pppppp#....",
		"....#PP##PP#....",
		"....########....",
	],
	"held_jaegerin": [
		"................",
		".....######.....",
		"....#nNNNNn#....",
		"...#nNNNNNNn#...",
		"...#NSSSSSSN#...",
		"...#NS#SS#SN#...",
		"...#NSSSSSSN#...",
		"....#SssssS#....",
		".....#NNNN#.....",
		"...##NnnnnN##...",
		"..#H#NNNNNN#h#..",
		"..#H#nNNNNn#h#..",
		"..###NNNNNN###..",
		"....#nn##nn#....",
		"...##HH##HH##...",
		"...############.",
	],
	"held_klerikerin": [
		"................",
		".....######.....",
		"....#WWWWWW#....",
		"...#WWGGGGWW#...",
		"...#WSSSSSSW#...",
		"...#WS#SS#SW#...",
		"...#WSSSSSSW#...",
		"....#SssssS#....",
		".....#WWWW#.....",
		"...##WGGGGW##...",
		"..#W#WWWWWW#W#..",
		"..#G#WWGGWW#G#..",
		"..###WWWWWW###..",
		"....#WW##WW#....",
		"...##LL##LL##...",
		"...############.",
	],
	# ============ GEGNER ============
	"gegner_schleim": [
		"................",
		"................",
		"................",
		"......####......",
		"....##NNNN##....",
		"...#NNNNNNNN#...",
		"..#NNWNNNNWN#...",
		"..#NN##NN##NN#..",
		"..#NNNNNNNNNN#..",
		".#NNNnnNNnnNNN#.",
		".#NnNNNNNNNNnN#.",
		".#nNNNNNNNNNNn#.",
		"..#nnNNNNNNnn#..",
		"...##nnnnnn##...",
		".....######.....",
		"................",
	],
	"gegner_wolf": [
		"................",
		"..##........##..",
		".#kK#......#Kk#.",
		".#KkK######KkK#.",
		".#kKKKKKKKKKKk#.",
		"..#KKKKKKKKKK#..",
		".#KKRKKKKKKRKK#.",
		".#KK##KKKK##KK#.",
		"..#KKKKKKKKKK#..",
		"..#KkkKKKKkkK#..",
		"...#KWWWWWWK#...",
		"....#K####K#....",
		"....#KKKKKK#....",
		"...##KK##KK##...",
		"...#kk#..#kk#...",
		"...####..####...",
	],
	"gegner_skelett": [
		"................",
		".....######.....",
		"....#WWWWWW#....",
		"...#WWWWWWWW#...",
		"...#W##WW##W#...",
		"...#WWWWWWWW#...",
		"....#W####W#....",
		".....#WWWW#.....",
		"....##LWWL##....",
		"...#W#WWWW#W#...",
		"...#W#LWWL#W#...",
		"...###WWWW###...",
		".....#L##L#.....",
		".....#W##W#.....",
		"....##W##W##....",
		"....########....",
	],
	"gegner_fledermaus": [
		"................",
		"................",
		"..##........##..",
		".#pP#......#Pp#.",
		"#pPPP#....#PPPp#",
		"#PPPPP####PPPPP#",
		"#PpPPPPPPPPPPpP#",
		".#PPP#PPPP#PPP#.",
		".#PP#RPPPPR#PP#.",
		"..##PP####PP##..",
		"....#PPPPPP#....",
		".....#PPPP#.....",
		"......#WW#......",
		".......##.......",
		"................",
		"................",
	],
	"gegner_golem": [
		"................",
		"....########....",
		"...#KkkkkkkK#...",
		"...#kCkkkkCk#...",
		"...#k##kk##k#...",
		"...#kkkkkkkk#...",
		"..##KkkKKkkK##..",
		".#kK#kKKKKk#Kk#.",
		".#kk#KkkkkK#kk#.",
		".#kk#kKCCKk#kk#.",
		".###.#kkkk#.###.",
		".....#KkkK#.....",
		"....#kk##kk#....",
		"....#kK##Kk#....",
		"...##kk##kk##...",
		"...####..####...",
	],
	# ============ UMGEBUNG ============
	"tile_boden": [
		"KKKKKKKKKKKKKKKK",
		"K#KKKKKKKKKKKK#K",
		"KKKKKKKKKKKKKKKK",
		"KKKKKKK#KKKKKKKK",
		"KKKKKKKKKKKKKKKK",
		"KKKKKKKKKKKKKKKK",
		"KK#KKKKKKKKK#KKK",
		"KKKKKKKKKKKKKKKK",
		"KKKKKKKKKKKKKKKK",
		"KKKKKKKK#KKKKKKK",
		"KKKKKKKKKKKKKKKK",
		"K#KKKKKKKKKKKKKK",
		"KKKKKKKKKKKK#KKK",
		"KKKKKKKKKKKKKKKK",
		"KKKK#KKKKKKKKKKK",
		"KKKKKKKKKKKKKKKK",
	],
	"tile_wand": [
		"################",
		"#kkkkkk##kkkkkk#",
		"#kKKKKk##kKKKKk#",
		"#kKKKKk##kKKKKk#",
		"#kkkkkk##kkkkkk#",
		"################",
		"##kkkkkk##kkkkk#",
		"##kKKKKk##kKKKk#",
		"##kKKKKk##kKKKk#",
		"##kkkkkk##kkkkk#",
		"################",
		"#kkkkkk##kkkkkk#",
		"#kKKKKk##kKKKKk#",
		"#kKKKKk##kKKKKk#",
		"#kkkkkk##kkkkkk#",
		"################",
	],
	"tile_truhe": [
		"................",
		"................",
		"...##########...",
		"..#GggggggggG#..",
		".#GgGGGGGGGGgG#.",
		".#gGGGGGGGGGGg#.",
		".#############..",
		".#HhhhhhhhhhhH#.",
		".#Hhhhh##hhhhH#.",
		".#Hhhh#GG#hhhH#.",
		".#Hhhh#GG#hhhH#.",
		".#Hhhhh##hhhhH#.",
		".#HhhhhhhhhhhH#.",
		".#HHHHHHHHHHHH#.",
		"..############..",
		"................",
	],
	"tile_treppe": [
		"################",
		"#KKKKKKKKKKKKKK#",
		"#K############K#",
		"#K#kkkkkkkkkk#K#",
		"#K#k########k#K#",
		"#K#k#LLLLLL#k#K#",
		"#K#k#L####L#k#K#",
		"#K#k#L#KK#L#k#K#",
		"#K#k#L#KK#L#k#K#",
		"#K#k#L####L#k#K#",
		"#K#k#LLLLLL#k#K#",
		"#K#k########k#K#",
		"#K#kkkkkkkkkk#K#",
		"#K############K#",
		"#KKKKKKKKKKKKKK#",
		"################",
	],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var names := SPRITES.keys()
	var columns := 4
	var rows := int(ceil(names.size() / float(columns)))
	var sheet := Image.create(columns * 16 * SCALE + (columns + 1) * 8,
		rows * (16 * SCALE + 20) + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("241f31"))

	for index in names.size():
		var sprite_name: String = names[index]
		var image := _render(SPRITES[sprite_name])
		image.save_png("%s/%s.png" % [OUT_DIR, sprite_name])
		# In die Vorschau (8×) einblitten.
		var big := image.duplicate()
		big.resize(16 * SCALE, 16 * SCALE, Image.INTERPOLATE_NEAREST)
		var x := 8 + (index % columns) * (16 * SCALE + 8)
		var y := 8 + (index / columns) * (16 * SCALE + 20)
		sheet.blend_rect(big, Rect2i(0, 0, 16 * SCALE, 16 * SCALE), Vector2i(x, y))
	sheet.save_png(PREVIEW)
	print("OK: %d Sprites » %s (+ Vorschau %s)" % [names.size(), OUT_DIR, PREVIEW])
	quit(0)


func _render(grid: Array) -> Image:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in grid.size():
		var row: String = grid[y]
		for x in row.length():
			var symbol := row[x]
			if symbol == ".":
				continue
			image.set_pixel(x, y, PALETTE.get(symbol, Color.MAGENTA))
	return image
