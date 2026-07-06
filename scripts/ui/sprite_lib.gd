class_name SpriteLib
extends RefCounted
## Lädt und cached die Kenney-Tiny-Dungeon-Tiles (CC0, 16×16 Pixel-Art).
## Zuordnung der Tile-Indizes siehe assets/kenney_tiny_dungeon/contact_sheet.png
## (Index = Zeile × 12 + Spalte).

const TILE_DIR := "res://assets/kenney_tiny_dungeon/Tiles"

# Umgebung
const TILE_FLOOR := 48       ## Sandboden
const TILE_WALL := 57        ## Ziegelwand
const TILE_STAIRS := 63      ## Leiter nach unten
const TILE_CHEST := 89       ## Verschlossene Truhe

# Helden
const HERO_TILES := {
	"Aldric": 96,   ## Ritter
	"Mira": 84,     ## Magierin
	"Talin": 100,   ## Gelehrter
	"Runa": 98,     ## Kämpferin
	"Edda": 85,     ## Dorfbewohnerin
	"Björn": 111,   ## Bärtiger mit Hut
	"Liora": 87,    ## Grauhaarige
	"Kaspar": 88,   ## Rotschopf
	"Selma": 99,    ## Edeldame
	"Dorn": 112,    ## Grüne Kapuze
}

# Gegner-Archetypen (id » Tile)
const ENEMY_TILES := {
	&"wolf": 124,           ## Graues Biest
	&"baer": 123,           ## Brauner Brocken
	&"schleim": 108,        ## Grüner Schleim
	&"fledermaus": 120,     ## Fledermaus
	&"golem": 102,          ## Steinkugel
	&"skelett": 97,         ## Gepanzerter Untoter
	&"kultist": 112,        ## Kuttenträger
	&"spinne": 122,         ## Spinne
	&"troll": 109,          ## Orangefarbener Brocken
	&"geist": 121,          ## Geist
	&"nekromant": 86,       ## Kahler Beschwörer
	&"schattenbestie": 110, ## Roter Dämon
	&"mimic": 92,           ## Truhe mit rotem Juwel (die Verkleidung selbst)
	&"schleimstapel": 108,  ## Schleim-Familie teilt sich den Schleim-Tile
	&"koenigschleim": 108,
	&"schleimgott": 108,
}
const TILE_ENEMY_MARKER := 110  ## Generischer Gegner-Marker im Dungeon

## Wählbare Helden-Porträts für die Charakter-Erstellung — ausschließlich
## Charakter-Tiles (Zeilen 8/9 des Kontaktblatts), keine Items!
const HERO_PORTRAITS: Array[int] = [96, 84, 100, 98, 85, 99, 87, 88, 111, 112]

# Dungeon-Events
const TILE_RISK_CHEST := 92  ## Juwelen-Truhe (Risiko-Truhe/Mimic)
const TILE_SHRINE := 33      ## Becken — Schreine werden je Typ eingefärbt
const TILE_SACRIFICE := 41   ## Dunkler Altar (Opferstein)

static var _cache: Dictionary = {}


static func tile(index: int) -> Texture2D:
	if _cache.has(index):
		return _cache[index]
	var path := "%s/tile_%04d.png" % [TILE_DIR, index]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		# Regulär importierte Textur (funktioniert auch im Export).
		texture = load(path)
	elif FileAccess.file_exists(path):
		# Fallback für Headless-Läufe ohne Import-Cache.
		var image := Image.load_from_file(path)
		if image != null:
			texture = ImageTexture.create_from_image(image)
	_cache[index] = texture
	return texture


static func hero(name: String) -> Texture2D:
	if HERO_TILES.has(name):
		return tile(HERO_TILES[name])
	return null


static func enemy(archetype_id: StringName) -> Texture2D:
	if ENEMY_TILES.has(archetype_id):
		return tile(ENEMY_TILES[archetype_id])
	return null
