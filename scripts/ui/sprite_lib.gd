class_name SpriteLib
extends RefCounted
## Sprite-Quelle des Spiels. EIGENE Sprites (KI-Pipeline, 128er Pixel-Art
## in assets/eigene_sprites, benannt nach Archetyp-ID) haben Vorrang;
## fuer alles, was dort (noch) fehlt, bleiben die Kenney-Tiny-Dungeon-
## Tiles (CC0, 16×16) der Fallback. Kenney-Indizes: siehe
## assets/kenney_tiny_dungeon/contact_sheet.png (Index = Zeile×12+Spalte).

const TILE_DIR := "res://assets/kenney_tiny_dungeon/Tiles"
const EIGENE_DIR := "res://assets/eigene_sprites"

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
	&"bandit": 111,         ## Räuber mit Hut
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


## Eigenes Sprite aus assets/eigene_sprites (oder null, wenn keins da ist).
static func eigene(name: String) -> Texture2D:
	var key := "eigene:" + name
	if _cache.has(key):
		return _cache[key]
	var path := "%s/%s.png" % [EIGENE_DIR, name]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path)
	elif FileAccess.file_exists(path):
		# Fallback für Headless-Läufe ohne Import-Cache.
		var image := Image.load_from_file(path)
		if image != null:
			texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func hero(name: String) -> Texture2D:
	if HERO_TILES.has(name):
		return tile(HERO_TILES[name])
	return null


static func enemy(archetype_id: StringName) -> Texture2D:
	var eigen := eigene(String(archetype_id))
	if eigen != null:
		return eigen
	if ENEMY_TILES.has(archetype_id):
		return tile(ENEMY_TILES[archetype_id])
	return null


## Welt-Mini (40px, pixelperfekt fuer die Dungeon-Ansicht): <id>_mini.png.
## Faellt auf das Kampf-Sprite zurueck, wenn kein Mini existiert.
static func enemy_mini(archetype_id: StringName) -> Texture2D:
	var mini := eigene(String(archetype_id) + "_mini")
	if mini != null:
		return mini
	return enemy(archetype_id)


## Boden-Varianten: eigene tile_boden_1..5, sonst die Kenney-Sandböden.
static func floor_variants() -> Array[Texture2D]:
	var eigene_tiles: Array[Texture2D] = []
	for i in range(1, 6):
		var t := eigene("tile_boden_%d" % i)
		if t != null:
			eigene_tiles.append(t)
	if not eigene_tiles.is_empty():
		return eigene_tiles
	var kenney: Array[Texture2D] = []
	for index in [48, 49, 50, 51, 52]:
		kenney.append(tile(index))
	return kenney


## Objekt-Tile: eigenes Sprite zuerst, sonst der Kenney-Index.
static func objekt(name: String, kenney_index: int) -> Texture2D:
	var eigen := eigene(name)
	return eigen if eigen != null else tile(kenney_index)


## Wand: eigene tile_wand, sonst der Kenney-Index des Biom-Stils.
static func wall(kenney_index: int) -> Texture2D:
	var eigen := eigene("tile_wand")
	return eigen if eigen != null else tile(kenney_index)
