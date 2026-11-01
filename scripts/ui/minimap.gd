class_name Minimap
extends Control
## Ecken-Minimap im Dungeon: zeigt die ERKUNDETEN Zellen (= schon mal im
## Bild gewesen), den Spieler als Pfeil, Symbole für Treppe, Boss, Truhen,
## Schreine, Opferstein und Tresor sowie die gerade sichtbaren Gegner.
## Liest direkt aus der Dungeon-Szene — reine Anzeige, kein Gameplay.
## Gedreht wie die 3D-Ansicht: Laufen nach oben = auf der Minimap nach oben.
##
## Die Karte ist EIN Bild (ImageTexture): Boden als Fläche, Wände als
## Konturlinien; neu erkundete Zellen werden nur dazugemalt, wenn sich die
## Zahl der erkundeten Zellen ändert. Größere Karten zeigen einen Ausschnitt,
## der dem Spieler folgt (Verschieben = nur Position, kein Neuzeichnen).
## Die Marker liegen in einer eigenen Ebene darüber, neu nur, wenn sich eine
## Marker-Zelle ändert. Liegt ein Held, Gegner oder Ziel unter der Minimap,
## blendet sie sich aus (die Welt bleibt lesbar).

## Bildschirm-Pixel je Zelle (entlang der gedrehten Achsen).
const ZELLE := 4.0
## Bildpunkte je Zelle im Kartenbild (Wandlinien 2 Bildpunkte dick).
const BILD_ZELLE := 6
## Größte Kantenlänge des Minimap-Fensters in Pixeln.
const MAX_GROESSE := 220.0
const DECKKRAFT_VERDECKT := 0.4

## Farben aus Stil3D.PAL (Rest Paket 5: eine Farbquelle).
const COLOR_BG := Color(Stil3D.PAL["ui_kerbe"], 0.86)
const COLOR_FLOOR := Color(Stil3D.PAL["stein_dunkel"], 0.95)
const COLOR_WALL := Color(Stil3D.PAL["messing_hell"], 0.95)
const COLOR_MESSING: Color = Stil3D.PAL["messing"]
const COLOR_MESSING_HELL: Color = Stil3D.PAL["messing_hell"]
const COLOR_KONTUR: Color = Stil3D.PAL["nacht"]
const COLOR_PLAYER: Color = Stil3D.PAL["weiss"]
const COLOR_STAIRS: Color = Stil3D.PAL["treppe_licht"]
const COLOR_BOSS: Color = Stil3D.PAL["boss_siegel"]
const COLOR_ENEMY: Color = Stil3D.PAL["warnrot"]
const EVENT_FARBEN := {
	DungeonGenerator.EventType.SHRINE_HEAL: Stil3D.PAL["ui_gut"],
	DungeonGenerator.EventType.SHRINE_MANA: Stil3D.PAL["mana"],
	DungeonGenerator.EventType.SHRINE_POWER: Stil3D.PAL["flamme"],
	DungeonGenerator.EventType.SHRINE_WARD: Stil3D.PAL["glut"],
	DungeonGenerator.EventType.SACRIFICE: Stil3D.PAL["daemon"],
	DungeonGenerator.EventType.RISK_CHEST: Stil3D.PAL["gold"],
}

var dungeon: Node2D  ## die Dungeon-Szene (liefert map/explored/…)

var _karte: Control          ## trägt das Kartenbild, wird zum Scrollen verschoben
var _marker_ebene: Control   ## Kind der Karte: Symbole und Spieler
var _rahmen: Control         ## Messingrahmen über allem (einmal gezeichnet)
var _bild: Image
var _textur: ImageTexture
var _gemalt: Dictionary = {}  ## schon ins Bild gemalte Zellen
var _gelesen := 0             ## so viele erkundete Zellen sind schon gelesen
var _gelesen_aus: Dictionary  ## ... aus diesem Dictionary (Referenz)
## Zuletzt gezeichneter Stand: Anzahl erkundeter Zellen (wächst nur) bzw.
## die Marker-Zellen — gleich geblieben » kein Neuzeichnen.
var _boden_stand := -1
var _marker_stand: Array = []
## Blickrichtung des Pfeils: letzter Zellschritt (Karten-Achsen).
var _richtung := Vector2i(-1, -1)
var _letzte_zelle := Vector2i(-99999, -99999)
## Maße und Transform der Karte (ändern sich mit der Karte nie).
var _masse: Dictionary = {}
var _t := Transform2D()
var _bild_nr := 0
var _verdeckt := false  ## liegt gerade ein Held/Gegner/Ziel unter der Minimap?
## Zähler fürs Neuzeichnen (Selbsttest).
var boden_gezeichnet := 0
var marker_gezeichnet := 0


func _ready() -> void:
	clip_contents = true
	_karte = Control.new()
	_karte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_karte.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_karte)
	_karte.draw.connect(_karte_zeichnen)
	_marker_ebene = Control.new()
	_marker_ebene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_karte.add_child(_marker_ebene)
	_marker_ebene.draw.connect(_marker_zeichnen)
	_rahmen = Control.new()
	_rahmen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rahmen.set_anchors_preset(Control.PRESET_FULL_RECT)  # vor add_child
	add_child(_rahmen)
	_rahmen.draw.connect(_rahmen_zeichnen)


## Pro Bild aus der Dungeon-Szene: malt nur, was sich geändert hat.
func aktualisieren() -> void:
	if dungeon == null or dungeon.map == null:
		return
	if _masse.is_empty():
		_masse = masse(dungeon.map)
		_t = _transform(dungeon.map)
		_karte.size = _masse["karte"]
		_marker_ebene.size = _masse["karte"]  # Größe 0 würde nie gezeichnet
	_bild_nr += 1
	var zelle: Vector2i = dungeon._pos_to_cell(dungeon.player_pos)
	if zelle != _letzte_zelle:
		var schritt := zelle - _letzte_zelle
		if _letzte_zelle.x > -99999 and schritt != Vector2i.ZERO and absi(schritt.x) <= 1 and absi(schritt.y) <= 1:
			_richtung = schritt
		_letzte_zelle = zelle
	var stand: int = dungeon._explored_cells.size()
	if stand != _boden_stand:
		_boden_stand = stand
		_bild_nachmalen()
	var marker := marker_zellen()
	if marker != _marker_stand:
		_marker_stand = marker
		_marker_ebene.queue_redraw()
	_ausschnitt_folgen(zelle)
	if _bild_nr % 4 == 0:
		_abstand_halten()


## Alles, wovon die Marker-Ebene abhängt: Spielerzelle und Blickrichtung,
## erkundete Zellen (Marker erscheinen erst erkundet), Boss, Truhen/
## Ereignisse/Tresor und die Zellen der gerade sichtbaren Gegner.
func marker_zellen() -> Array:
	var zellen: Array = [dungeon._pos_to_cell(dungeon.player_pos), _richtung, dungeon._explored_cells.size(),
		dungeon._boss_alive, dungeon._chests.size(), dungeon._events.size(), dungeon._tresor.is_empty()]
	for enemy in dungeon._enemies:
		var cell: Vector2i = dungeon._pos_to_cell(enemy["pos"])
		if dungeon._visible_cells.has(cell):
			zellen.append(cell)
	return zellen


## Bild einer Karten-Einheit in x bzw. y auf der Minimap — dieselben Achsen
## wie die Bildschirm-Steuerung (oben = Blickrichtung der Kamera).
static func _achsen() -> Array[Vector2]:
	var k := DungeonWelt3D.KAMERA_RICHTUNG
	var vor := Vector2(-k.x, -k.z).normalized()
	var rechts := Vector2(-vor.y, vor.x)
	return [Vector2(rechts.x, -vor.x), Vector2(rechts.y, -vor.y)]


## Zellgröße, Fenstergröße, Größe der ganzen gedrehten Karte und Ursprung
## (Raute im Feld). Passt die Karte nicht ins Fenster, scrollt ein Ausschnitt.
static func masse(map: DungeonMap) -> Dictionary:
	var achsen := _achsen()
	var ecken: Array[Vector2] = [Vector2.ZERO, achsen[0] * map.width, achsen[1] * map.height,
		achsen[0] * map.width + achsen[1] * map.height]
	var lo := ecken[0]
	var hi := ecken[0]
	for e in ecken:
		lo = lo.min(e)
		hi = hi.max(e)
	var karte := (hi - lo) * ZELLE + Vector2(16, 16)
	return {"zelle": ZELLE, "groesse": karte.min(Vector2(MAX_GROESSE, MAX_GROESSE)), "karte": karte,
		"ursprung": -lo * ZELLE + Vector2(8, 8)}


## Karten-Transform (Raute, gedreht wie die 3D-Ansicht) im Kartenbild.
static func _transform(map: DungeonMap) -> Transform2D:
	var m := masse(map)
	var achsen := _achsen()
	return Transform2D(achsen[0] * ZELLE, achsen[1] * ZELLE, m["ursprung"])


## Ausschnitt: die Karte so verschieben, dass der Spieler mittig steht
## (am Kartenrand angeschlagen); bei kleinen Karten mittig, ohne Scrollen.
func _ausschnitt_folgen(zelle: Vector2i) -> void:
	var karte: Vector2 = _masse["karte"]
	var fenster := size
	var ziel := (fenster - karte) * 0.5
	if karte.x > fenster.x + 0.5 or karte.y > fenster.y + 0.5:
		var spieler := _t * (Vector2(zelle) + Vector2(0.5, 0.5))
		ziel = (fenster * 0.5 - spieler).clamp(fenster - karte, Vector2.ZERO)
	if _karte.position.distance_to(ziel) > 40.0:
		_karte.position = ziel
	elif _karte.position.distance_squared_to(ziel) > 0.01:
		_karte.position = _karte.position.lerp(ziel, minf(1.0, get_process_delta_time() * 8.0))


## Über Held, Gegner oder Zielen unter der Minimap blendet sie sich aus.
func _abstand_halten() -> void:
	var welt: Node = dungeon.get("_welt") if "_welt" in dungeon else null
	if welt == null or not welt.has_method("bildschirm_punkt"):
		return
	var feld := get_global_rect().grow(14.0)
	var orte: Array[Vector2] = [dungeon.player_pos]
	for liste in [dungeon._chests, dungeon._events, dungeon._enemies]:
		for eintrag in liste:
			orte.append(eintrag["pos"])
	if not dungeon._tresor.is_empty():
		orte.append(dungeon._tresor["pos"])
	var verdeckt := false
	for px in orte:
		var p: Vector2 = welt.bildschirm_punkt(Vector3(px.x / DungeonMap.TILE_SIZE, 0.4, px.y / DungeonMap.TILE_SIZE))
		if feld.has_point(p):
			verdeckt = true
			break
	_verdeckt = verdeckt


func _process(delta: float) -> void:
	var ziel := DECKKRAFT_VERDECKT if _verdeckt else 1.0
	if not is_equal_approx(modulate.a, ziel):
		modulate.a = move_toward(modulate.a, ziel, delta * 4.0)


# --- Kartenbild ----------------------------------------------------------------

## Neu erkundete Zellen ins Bild malen: Boden als Fläche, an Wandseiten eine
## Konturlinie (auch Innenecken), dann die Textur hochladen. Erkundete
## Zellen kommen nur hinten dazu (Dictionary behält die Einfügereihenfolge):
## gelesen wird ab dem letzten Stand, nicht jedes Mal die ganze Karte
## (88×76 voll erkundet sonst ~2 ms je Bild beim Laufen).
func _bild_nachmalen() -> void:
	var map: DungeonMap = dungeon.map
	var p := BILD_ZELLE
	if _bild == null:
		_bild = Image.create(map.width * p, map.height * p, false, Image.FORMAT_RGBA8)
		_bild.fill(Color(0, 0, 0, 0))
	var erkundet: Dictionary = dungeon._explored_cells
	if not is_same(erkundet, _gelesen_aus) or erkundet.size() < _gelesen:
		_gelesen_aus = erkundet  # andere Quelle (z. B. Co-op-Stand): von vorn, _gemalt bleibt
		_gelesen = 0
	var zellen: Array = erkundet.keys()
	var neue: Array = zellen.slice(_gelesen)
	_gelesen = zellen.size()
	for cell in neue:
		if _gemalt.has(cell) or not map.is_floor(cell):
			continue
		_gemalt[cell] = true
		var x0: int = cell.x * p
		var y0: int = cell.y * p
		_bild.fill_rect(Rect2i(x0, y0, p, p), COLOR_FLOOR)
		if not map.is_floor(cell + Vector2i(0, -1)):
			_bild.fill_rect(Rect2i(x0, y0, p, 2), COLOR_WALL)
		if not map.is_floor(cell + Vector2i(0, 1)):
			_bild.fill_rect(Rect2i(x0, y0 + p - 2, p, 2), COLOR_WALL)
		if not map.is_floor(cell + Vector2i(-1, 0)):
			_bild.fill_rect(Rect2i(x0, y0, 2, p), COLOR_WALL)
		if not map.is_floor(cell + Vector2i(1, 0)):
			_bild.fill_rect(Rect2i(x0 + p - 2, y0, 2, p), COLOR_WALL)
		for ecke in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			if not map.is_floor(cell + ecke):
				var ex := x0 if ecke.x < 0 else x0 + p - 2
				var ey := y0 if ecke.y < 0 else y0 + p - 2
				_bild.fill_rect(Rect2i(ex, ey, 2, 2), COLOR_WALL)
	if _textur == null:
		_textur = ImageTexture.create_from_image(_bild)
	else:
		_textur.update(_bild)
	boden_gezeichnet += 1
	_karte.queue_redraw()


func _karte_zeichnen() -> void:
	if _textur == null or dungeon == null or dungeon.map == null:
		return
	var map: DungeonMap = dungeon.map
	_karte.draw_set_transform_matrix(_t)
	_karte.draw_texture_rect(_textur, Rect2(Vector2.ZERO, Vector2(map.width, map.height)), false)


## Hintergrund: dunkle Tafel unter der Karte.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)


## Messingrahmen mit Innenkante und Nieten (über der Karte).
func _rahmen_zeichnen() -> void:
	var r := Rect2(Vector2.ZERO, size)
	_rahmen.draw_rect(r.grow(-1.5), COLOR_KONTUR, false, 3.0)
	_rahmen.draw_rect(r.grow(-3.5), COLOR_MESSING, false, 2.0)
	_rahmen.draw_rect(r.grow(-5.0), Color(COLOR_MESSING_HELL, 0.5), false, 1.0)
	for ecke in [Vector2(7, 7), Vector2(size.x - 7, 7), Vector2(7, size.y - 7), size - Vector2(7, 7)]:
		_rahmen.draw_circle(ecke, 3.6, COLOR_KONTUR)
		_rahmen.draw_circle(ecke, 2.6, COLOR_MESSING_HELL)


# --- Marker ------------------------------------------------------------------------

## Marker-Ebene (Kind der Karte): Treppe, Boss, Truhen, Tresor, Ereignisse,
## sichtbare Gegner und der Spieler — aufrechte Symbole an der Kartenstelle.
func _marker_zeichnen() -> void:
	if dungeon == null or dungeon.map == null:
		return
	marker_gezeichnet += 1
	var map: DungeonMap = dungeon.map
	var t := _t
	var ort := func(cell: Vector2i) -> Vector2: return t * (Vector2(cell) + Vector2(0.5, 0.5))
	# Treppe/Boss nur, wenn schon gesehen — die Minimap verrät nichts Neues.
	if map.stairs_cell.x >= 0 and dungeon._explored_cells.has(map.stairs_cell):
		_symbol_treppe(ort.call(map.stairs_cell))
	if map.has_boss and dungeon._boss_alive and dungeon._explored_cells.has(map.boss_cell):
		_symbol_boss(ort.call(map.boss_cell))
	for chest in dungeon._chests:
		var cell: Vector2i = dungeon._pos_to_cell(chest["pos"])
		if dungeon._explored_cells.has(cell):
			_symbol_truhe(ort.call(cell), LootGenerator.RARITY_COLORS.get(chest["rarity"], Color.WHITE))
	if not dungeon._tresor.is_empty():
		var tresor_zelle: Vector2i = dungeon._pos_to_cell(dungeon._tresor["pos"])
		if dungeon._explored_cells.has(tresor_zelle):
			_symbol_tresor(ort.call(tresor_zelle))
	for event in dungeon._events:
		var cell: Vector2i = dungeon._pos_to_cell(event["pos"])
		if dungeon._explored_cells.has(cell):
			_symbol_ereignis(ort.call(cell), event["type"])
	# Gegner nur, wenn gerade im Bild.
	for enemy in dungeon._enemies:
		var cell: Vector2i = dungeon._pos_to_cell(enemy["pos"])
		if dungeon._visible_cells.has(cell):
			_marker_ebene.draw_circle(ort.call(cell), 3.4, COLOR_KONTUR)
			_marker_ebene.draw_circle(ort.call(cell), 2.4, COLOR_ENEMY)
	var blick := (t.basis_xform(Vector2(_richtung))).normalized()
	_symbol_spieler(ort.call(dungeon._pos_to_cell(dungeon.player_pos)), blick)


func _umrandet(punkte: PackedVector2Array, farbe: Color) -> void:
	_marker_ebene.draw_colored_polygon(punkte, farbe)
	var zu := punkte.duplicate()
	zu.append(punkte[0])
	_marker_ebene.draw_polyline(zu, COLOR_KONTUR, 1.2, true)


func _symbol_spieler(p: Vector2, blick: Vector2) -> void:
	var quer := Vector2(-blick.y, blick.x)
	var spitze := p + blick * 6.0
	var punkte := PackedVector2Array([spitze, p - blick * 4.0 + quer * 4.5, p - blick * 1.8,
		p - blick * 4.0 - quer * 4.5])
	_marker_ebene.draw_circle(p, 7.0, Color(Stil3D.PAL["gold"], 0.28))
	_umrandet(punkte, COLOR_PLAYER)


func _symbol_treppe(p: Vector2) -> void:
	_marker_ebene.draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), COLOR_KONTUR)
	for i in 3:
		var breite := 4.0 + i * 3.0
		_marker_ebene.draw_rect(Rect2(p + Vector2(-5, -4.5 + i * 3.4), Vector2(breite, 2.4)), COLOR_STAIRS)


func _symbol_boss(p: Vector2) -> void:
	_marker_ebene.draw_circle(p + Vector2(0, -1), 6.2, COLOR_KONTUR)
	_marker_ebene.draw_rect(Rect2(p + Vector2(-3.6, 1), Vector2(7.2, 5)), COLOR_KONTUR)
	_marker_ebene.draw_circle(p + Vector2(0, -1), 5.0, COLOR_BOSS)
	_marker_ebene.draw_rect(Rect2(p + Vector2(-2.6, 1.5), Vector2(5.2, 3.6)), COLOR_BOSS)
	for x in [-2.0, 2.0]:
		_marker_ebene.draw_circle(p + Vector2(x, -1.2), 1.4, COLOR_KONTUR)


func _symbol_truhe(p: Vector2, farbe: Color) -> void:
	_marker_ebene.draw_rect(Rect2(p - Vector2(5.5, 4.5), Vector2(11, 9)), COLOR_KONTUR)
	_marker_ebene.draw_rect(Rect2(p - Vector2(4.5, 3.5), Vector2(9, 7)), farbe)
	_marker_ebene.draw_line(p + Vector2(-4.5, -0.6), p + Vector2(4.5, -0.6), COLOR_KONTUR, 1.2)
	_marker_ebene.draw_rect(Rect2(p + Vector2(-1, -1), Vector2(2, 2.4)), COLOR_MESSING_HELL)


func _symbol_tresor(p: Vector2) -> void:
	_marker_ebene.draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), COLOR_KONTUR)
	_marker_ebene.draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), UiTheme.GOLD)
	_marker_ebene.draw_circle(p, 2.6, COLOR_KONTUR)


func _symbol_ereignis(p: Vector2, typ: int) -> void:
	var farbe: Color = EVENT_FARBEN.get(typ, Color.WHITE)
	match typ:
		DungeonGenerator.EventType.SACRIFICE:
			_umrandet(PackedVector2Array([p + Vector2(-5, -4), p + Vector2(5, -4), p + Vector2(0, 5)]), farbe)
		DungeonGenerator.EventType.RISK_CHEST:
			_symbol_truhe(p, farbe)
			_marker_ebene.draw_circle(p + Vector2(0, -5), 2.0, COLOR_BOSS)
		_:
			_umrandet(PackedVector2Array([p + Vector2(0, -6), p + Vector2(5, 0), p + Vector2(0, 6),
				p + Vector2(-5, 0)]), farbe)
