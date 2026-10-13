class_name DungeonWelt3D
extends Node3D
## 3D-Darstellung des begehbaren Dungeons nach STIL-3D.md — reine Anzeige.
## Die Spiellogik (dungeon_scene.gd) rechnet unverändert in Karten-Pixeln;
## 32 px = 1 Feld = 1 Welteinheit (Karten-y wird Welt-z). Jedes Bild ruft
## sie aktualisieren() auf, diese Klasse spiegelt den Zustand in 3D.
##
## Boden und Wände sind MultiMeshes (Karten bis 88×76 Felder). Verdeckt
## eine Wand etwas, wird ihre Instanz versteckt und durch einen Glas-Block
## ersetzt, der überblendet (Glas-Regel, STIL-3D.md Abschnitt 7).

const PX := 32.0  ## muss DungeonMap.TILE_SIZE entsprechen
const KAMERA_RICHTUNG := Vector3(11.0, 12.5, 11.0)  ## 45°-Diorama-Blick
## Kameraabstand klein halten: die Schattenreichweite zählt ab der Kamera.
const KAMERA_ABSTAND := 1.2
const ZOOM_START := 10.5
const ZOOM_MIN := 6.5
const ZOOM_MAX := 16.0
const KOERPER_HOEHE := 1.2
const DECKKRAFT_GLAS := 0.22
const GLAS_TEMPO := 3.0
const FACKEL_CHANCE := 0.05
const VERSTECKT := Vector3(0, -100, 0)
## Glas-Regel: Wand liegt "vor" einem Ziel (Richtung Kamera) und seitlich nah.
const HELD_VOR_MAX := 5.0
const HELD_QUER_MAX := 3.0
const ZIEL_VOR_MAX := 2.6
const ZIEL_QUER_MAX := 1.1

## Biom-Stile: Farbstimmung (tönt Boden und Wände der 3D-Welt) und
## Deko-Arten (FigurenBau.deko) — Wald, Höhle, Ruinen und Krypta sehen
## spürbar unterschiedlich aus.
const BIOM_STILE := {
	Enums.Biome.FOREST: {
		"floor_tint": Color(0.88, 1.0, 0.82), "wall_tint": Color(0.85, 1.0, 0.88),
		"deco": ["pilz", "felsbrocken"],
	},
	Enums.Biome.CAVE: {
		"floor_tint": Color(0.68, 0.74, 0.9), "wall_tint": Color(0.6, 0.66, 0.85),
		"deco": ["felsbrocken", "knochen"],
	},
	Enums.Biome.RUINS: {
		"floor_tint": Color(0.85, 0.85, 0.82), "wall_tint": Color(0.95, 0.95, 0.92),
		"deco": ["amboss", "fass"],
	},
	Enums.Biome.CRYPT: {
		"floor_tint": Color(0.72, 0.62, 0.82), "wall_tint": Color(0.62, 0.52, 0.75),
		"deco": ["grabstein", "knochen"],
	},
}

static func biom_stil(biome: Enums.Biome) -> Dictionary:
	return BIOM_STILE.get(biome, BIOM_STILE[Enums.Biome.FOREST])


const SCHREIN_FARBEN := {
	DungeonGenerator.EventType.SHRINE_HEAL: Color("6fe08a"),
	DungeonGenerator.EventType.SHRINE_MANA: Color("6fb0f0"),
	DungeonGenerator.EventType.SHRINE_POWER: Color("ff9a3a"),
	DungeonGenerator.EventType.SHRINE_WARD: Color("ffe07a"),
}

var _map: DungeonMap
var _kamera: Camera3D
var _zoom := ZOOM_START
var _blickpunkt := Vector3.ZERO
var _vor := Vector2(-1, -1).normalized()   ## Bodenrichtung "von der Kamera weg"
var _rechts := Vector2(1, -1).normalized()  ## Bodenrichtung "Bildschirm rechts"
var _koerper_mm: MultiMesh
var _deckel_mm: MultiMesh
## Vector2i » {"i": Instanz-Index, "farbe": Color, "alpha": float, "glas": Array}
var _waende: Dictionary = {}
var _figuren: Dictionary = {}  ## Schlüssel » Node3D
var _labels: Dictionary = {}   ## Schlüssel » Label3D
var _fackeln: Array[Node3D] = []
var _laterne: OmniLight3D
var _letzte_spielerpos := Vector3.ZERO
var _zeit := 0.0


# --- Aufbau ------------------------------------------------------------------

func aufbauen(map: DungeonMap, boden_tint: Color, wand_tint: Color, deko: Array[Dictionary],
		start_px: Vector2) -> void:
	_map = map
	_umgebung()
	_boden_bauen(boden_tint)
	_waende_bauen(wand_tint)
	_treppe_bauen()
	for eintrag in deko:
		var cell: Vector2i = eintrag["cell"]
		var d := FigurenBau.deko(eintrag["art"])
		add_child(d)
		d.position = Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)
		d.rotation.y = float(absi(hash(cell)) % 360)
	_kamera = Camera3D.new()
	_kamera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_kamera.size = _zoom
	_kamera.far = 120.0
	add_child(_kamera)
	_kamera.look_at_from_position(KAMERA_RICHTUNG * KAMERA_ABSTAND, Vector3.ZERO)
	_kamera.make_current()
	var b := _kamera.global_transform.basis
	_rechts = Vector2(b.x.x, b.x.z).normalized()
	_vor = Vector2(-b.z.x, -b.z.z).normalized()
	_blickpunkt = _welt(start_px)
	_kamera.position = _blickpunkt + KAMERA_RICHTUNG * KAMERA_ABSTAND
	_letzte_spielerpos = _blickpunkt
	_laterne = OmniLight3D.new()
	_laterne.light_color = Color(1.0, 0.8, 0.55)
	_laterne.light_energy = 0.55
	_laterne.omni_range = 5.0
	add_child(_laterne)


func _umgebung() -> void:
	var welt := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Stil3D.farbe("nacht").srgb_to_linear()  # BG-Farbe erwartet linear
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.42, 0.68)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 0.85
	welt.environment = env
	add_child(welt)
	var sonne := DirectionalLight3D.new()
	sonne.rotation_degrees = Vector3(-52, 110, 0)
	sonne.light_color = Color(1.0, 0.95, 0.86)
	sonne.light_energy = 0.78
	sonne.shadow_enabled = true
	sonne.directional_shadow_max_distance = 40.0
	add_child(sonne)
	get_viewport().msaa_3d = Viewport.MSAA_4X


func _multimesh(mesh: Mesh, anzahl: int, kontur_modus: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = anzahl
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Stil3D.material(Color.WHITE, kontur_modus)
	add_child(mmi)
	return mm


func _boden_bauen(tint: Color) -> void:
	var zellen := _map.floor_cells()
	var platten := _multimesh(Stil3D.box(0.94, 0.16, 0.94), zellen.size(), -1)
	var sockel := _multimesh(Stil3D.box(1.0, 0.5, 1.0), zellen.size(), -1)
	var stein := Stil3D.farbe("stein") * tint
	var fuge := Stil3D.farbe("fuge")
	for i in zellen.size():
		var c := zellen[i]
		var mitte := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
		var platte := mitte + Vector3(0, -0.08, 0)
		if c == _map.stairs_cell:
			platte = VERSTECKT  # Treppe hat ihr eigenes Loch
		var hell := 0.96 + float(absi(hash(c)) % 9) * 0.01
		var schach := 1.0 if (c.x + c.y) % 2 == 0 else 0.93
		platten.set_instance_transform(i, Transform3D(Basis(), platte))
		platten.set_instance_color(i, stein * (hell * schach))
		sockel.set_instance_transform(i, Transform3D(Basis(), mitte + Vector3(0, -0.27, 0)))
		sockel.set_instance_color(i, fuge)


## Nur Wandzellen, die an Boden grenzen, werden gebaut — der Rest bleibt
## Nachtschwarz (Räume schweben wie Dioramen im Dunkel).
func _waende_bauen(tint: Color) -> void:
	var zellen: Array[Vector2i] = []
	for y in _map.height:
		for x in _map.width:
			var c := Vector2i(x, y)
			if not _map.is_floor(c) and _grenzt_an_boden(c):
				zellen.append(c)
	var sockel := _multimesh(Stil3D.box(1.0, 0.3, 1.0), zellen.size(), 1)
	_koerper_mm = _multimesh(Stil3D.box(1.0, KOERPER_HOEHE, 1.0), zellen.size(), 1)
	_deckel_mm = _multimesh(Stil3D.box(1.0, 0.1, 1.0), zellen.size(), -1)
	var dunkel := Stil3D.farbe("stein_dunkel") * tint
	var hell := Stil3D.farbe("stein_hell") * tint
	for i in zellen.size():
		var c := zellen[i]
		var mitte := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
		var farbe := dunkel * (0.94 + float(absi(hash(c)) % 9) * 0.01)
		sockel.set_instance_transform(i, Transform3D(Basis(), mitte + Vector3(0, -0.01, 0)))
		sockel.set_instance_color(i, farbe * 0.82)
		_koerper_mm.set_instance_transform(i, Transform3D(Basis(), mitte + Vector3(0, 0.14 + KOERPER_HOEHE * 0.5, 0)))
		_koerper_mm.set_instance_color(i, farbe)
		_deckel_mm.set_instance_transform(i, Transform3D(Basis(), mitte + Vector3(0, 0.14 + KOERPER_HOEHE + 0.05, 0)))
		_deckel_mm.set_instance_color(i, hell)
		_waende[c] = {"i": i, "farbe": farbe, "hell": hell, "alpha": 1.0, "glas": []}
		_fackel_pruefen(c)


func _grenzt_an_boden(c: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if (dx != 0 or dy != 0) and _map.is_floor(c + Vector2i(dx, dy)):
				return true
	return false


## Vereinzelte Fackeln an Wänden, die direkt an Boden grenzen (deterministisch).
func _fackel_pruefen(c: Vector2i) -> void:
	if float(absi(hash(c * 7 + Vector2i(13, 29))) % 1000) / 1000.0 > FACKEL_CHANCE:
		return
	for richtung in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		if _map.is_floor(c + richtung):
			var f := FigurenBau.fackel()
			add_child(f)
			f.position = Vector3(c.x + 0.5 + richtung.x * 0.53, 1.0, c.y + 0.5 + richtung.y * 0.53)
			f.rotation.y = atan2(float(richtung.x), float(richtung.y))
			_fackeln.append(f)
			return


func _treppe_bauen() -> void:
	var t := _map.stairs_cell
	if t.x < 0:
		return
	var mitte := Vector3(t.x + 0.5, 0.0, t.y + 0.5)
	Stil3D.teil(self, Stil3D.box(0.94, 0.6, 0.94), Stil3D.farbe("nacht"), mitte + Vector3(0, -0.3, 0),
		Vector3.ZERO, false)
	for s in 3:
		Stil3D.teil(self, Stil3D.box(0.94, 0.12, 0.3), Stil3D.farbe("stein_hell") * (1.0 - s * 0.22),
			mitte + Vector3(0, -0.1 - s * 0.16, -0.32 + s * 0.31), Vector3.ZERO, false)


# --- Laufende Aktualisierung --------------------------------------------------

func aktualisieren(delta: float, szene: Node) -> void:
	_zeit += delta
	var spieler := _welt(szene.player_pos)
	var gesehen := {}
	var ziele: Array[Vector2] = []

	# Held des Spielers: Blickrichtung aus der eigenen Bewegung.
	var held_name: String = szene.held_name()
	var held := _figur("spieler",
		func() -> Node3D: return FigurenBau.held(FigurenBau.held_farbe(held_name)), spieler, gesehen)
	var schritt := spieler - _letzte_spielerpos
	if schritt.length() > 0.002:
		held.rotation.y = lerp_angle(held.rotation.y, atan2(schritt.x, schritt.z), minf(1.0, delta * 14.0))
	_letzte_spielerpos = spieler

	for gegner in szene._enemies:
		var arch: EnemyArchetype = gegner.get("archetype")
		var id := StringName(arch.id) if arch != null else &"?"
		var key := "e%d" % gegner["id"]
		var pos := _welt(gegner["pos"])
		var fig := _figur(key, func() -> Node3D: return FigurenBau.fuer_archetyp(id), pos, gesehen)
		var kurs: Vector2 = gegner.get("kurs", Vector2.ZERO)
		if kurs != Vector2.ZERO:
			fig.rotation.y = lerp_angle(fig.rotation.y, atan2(kurs.x, kurs.y), minf(1.0, delta * 10.0))
		ziele.append(Vector2(pos.x, pos.z))
		var marker_zeit: float = gegner.get("marker_zeit", 0.0)
		if marker_zeit > 0.0:
			var gelb: bool = gegner.get("marker", "") == "!"
			var farbe := Color(1.0, 0.85, 0.3) if gelb else Color(0.75, 0.85, 1.0)
			farbe.a = clampf(marker_zeit / 0.3, 0.0, 1.0)
			_label(key, gegner["marker"], pos + Vector3(0, 1.55, 0), farbe, 96, gesehen)

	for truhe in szene._chests:
		var key := "c%d" % truhe["id"]
		var band: Color = LootGenerator.RARITY_COLORS.get(truhe["rarity"], Stil3D.farbe("eisen"))
		var pos := _welt(truhe["pos"])
		_figur(key, func() -> Node3D: return FigurenBau.truhe(band), pos, gesehen)
		ziele.append(Vector2(pos.x, pos.z))

	for ev in szene._events:
		var key := "v%d" % ev["id"]
		var typ: DungeonGenerator.EventType = ev["type"]
		var pos := _welt(ev["pos"])
		_figur(key, func() -> Node3D: return _event_figur(typ), pos, gesehen)
		ziele.append(Vector2(pos.x, pos.z))

	if szene._boss_alive:
		var zelle: Vector2i = szene.map.boss_cell
		var pos := Vector3(zelle.x + 0.5, 0.0, zelle.y + 0.5)
		var boss_id: StringName = szene._boss_archetyp_id()
		var boss_bauen := func() -> Node3D:
			var b := FigurenBau.fuer_archetyp(boss_id)
			b.scale *= 1.5
			return b
		var boss := _figur("boss", boss_bauen, pos, gesehen)
		boss.rotation.y = atan2(spieler.x - pos.x, spieler.z - pos.z)
		ziele.append(Vector2(pos.x, pos.z))

	if _map.stairs_cell.x >= 0:
		ziele.append(Vector2(_map.stairs_cell.x + 0.5, _map.stairs_cell.y + 0.5))

	# Co-op-Mitspieler auf derselben Ebene (geglättete Anzeigeposition).
	for wer in Net.remote_players:
		var info: Dictionary = Net.remote_players[wer]
		if int(info["floor"]) != szene.floor_index:
			continue
		var key := "m:" + String(wer)
		var pos := _welt(szene._remote_display.get(wer, info["pos"]))
		var ruestung := FigurenBau.held_farbe(String(wer))
		_figur(key, func() -> Node3D: return FigurenBau.held(ruestung), pos, gesehen)
		_label(key, String(wer), pos + Vector3(0, 1.45, 0), Color(0.75, 0.9, 1.0), 48, gesehen)
		ziele.append(Vector2(pos.x, pos.z))

	# Verschwundenes (besiegt, geöffnet, benutzt, Mitspieler weg) aufräumen.
	for key in _figuren.keys():
		if not gesehen.has(key):
			_figuren[key].queue_free()
			_figuren.erase(key)
	for key in _labels.keys():
		if not gesehen.has("L" + key):
			_labels[key].queue_free()
			_labels.erase(key)

	_lebendigkeit()
	_kamera_folgen(delta, spieler)
	_glas_aktualisieren(delta, Vector2(spieler.x, spieler.z), ziele)


func _welt(px: Vector2) -> Vector3:
	return Vector3(px.x / PX, 0.0, px.y / PX)


func _figur(key: String, bauen: Callable, pos: Vector3, gesehen: Dictionary) -> Node3D:
	gesehen[key] = true
	var fig: Node3D = _figuren.get(key)
	if fig == null:
		fig = bauen.call()
		add_child(fig)
		_figuren[key] = fig
		fig.set_meta("phase", float(absi(hash(key)) % 628) / 100.0)
	fig.set_meta("boden", pos)
	return fig


func _label(key: String, text: String, pos: Vector3, farbe: Color, groesse: int, gesehen: Dictionary) -> void:
	gesehen["L" + key] = true
	var l: Label3D = _labels.get(key)
	if l == null:
		l = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.pixel_size = 0.005
		l.outline_size = 14
		l.outline_modulate = Stil3D.farbe("nacht")
		add_child(l)
		_labels[key] = l
	l.text = text
	l.font_size = groesse
	l.modulate = farbe
	l.outline_modulate.a = farbe.a
	l.position = pos


func _event_figur(typ: DungeonGenerator.EventType) -> Node3D:
	match typ:
		DungeonGenerator.EventType.SACRIFICE:
			return FigurenBau.altar()
		DungeonGenerator.EventType.RISK_CHEST:
			return FigurenBau.risikotruhe()
	return FigurenBau.schrein(SCHREIN_FARBEN.get(typ, Color.WHITE))


## Idle-Wippen, Schleim-Quetschen, Schweben, Fackel-Flackern.
func _lebendigkeit() -> void:
	for fig in _figuren.values():
		var boden: Vector3 = fig.get_meta("boden", fig.position)
		var phase: float = fig.get_meta("phase", 0.0)
		var hoehe := float(fig.get_meta("schwebt", 0.0)) \
			+ sin(_zeit * 2.2 + phase) * float(fig.get_meta("wippen", 0.0))
		fig.position = boden + Vector3(0, hoehe, 0)
		var quetsch := float(fig.get_meta("quetschen", 0.0))
		if quetsch > 0.0:
			var basis_skala: float = fig.get_meta("basis_skala", fig.scale.x)
			fig.set_meta("basis_skala", basis_skala)
			var s := sin(_zeit * 3.0 + phase) * quetsch
			fig.scale = Vector3(1.0 - s * 0.5, 1.0 + s, 1.0 - s * 0.5) * basis_skala
	for i in _fackeln.size():
		var licht: OmniLight3D = _fackeln[i].get_meta("licht")
		licht.light_energy = 0.7 * (0.88 + 0.12 * sin(_zeit * 13.0 + i) * sin(_zeit * 7.3 + i * 2.0))


func _kamera_folgen(delta: float, spieler: Vector3) -> void:
	_blickpunkt = _blickpunkt.lerp(spieler, minf(1.0, delta * 8.0))
	_kamera.position = _blickpunkt + KAMERA_RICHTUNG * KAMERA_ABSTAND
	_kamera.size = lerpf(_kamera.size, _zoom, minf(1.0, delta * 10.0))
	_laterne.position = spieler + Vector3(0, 1.6, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(ZOOM_MIN, _zoom - 0.8)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(ZOOM_MAX, _zoom + 0.8)


# --- Glas-Regel ----------------------------------------------------------------

func _glas_aktualisieren(delta: float, held: Vector2, ziele: Array[Vector2]) -> void:
	var bereich := sichtbarer_bereich(2)
	for y in range(bereich[1], bereich[3]):
		for x in range(bereich[0], bereich[2]):
			var c := Vector2i(x, y)
			var w: Dictionary = _waende.get(c, {})
			if w.is_empty():
				continue
			var p := Vector2(x + 0.5, y + 0.5)
			var ziel_alpha := DECKKRAFT_GLAS if _verdeckt(p, held, ziele) else 1.0
			var alt: float = w["alpha"]
			if is_equal_approx(alt, ziel_alpha):
				continue
			var neu := move_toward(alt, ziel_alpha, delta * GLAS_TEMPO)
			w["alpha"] = neu
			_glas_setzen(c, w, neu)


func _verdeckt(p: Vector2, held: Vector2, ziele: Array[Vector2]) -> bool:
	if _liegt_vor(p, held, HELD_VOR_MAX, HELD_QUER_MAX):
		return true
	for z in ziele:
		if _liegt_vor(p, z, ZIEL_VOR_MAX, ZIEL_QUER_MAX):
			return true
	return false


func _liegt_vor(p: Vector2, ziel: Vector2, vor_max: float, quer_max: float) -> bool:
	var d := p - ziel
	var vor := -d.dot(_vor)  # > 0: Wand steht zwischen Kamera und Ziel
	return vor > 0.3 and vor < vor_max and absf(d.dot(_rechts)) < quer_max


func _glas_setzen(c: Vector2i, w: Dictionary, alpha: float) -> void:
	var i: int = w["i"]
	var glas: Array = w["glas"]
	var mitte := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
	if alpha >= 0.999:
		for teil in glas:
			teil.queue_free()
		glas.clear()
		_koerper_mm.set_instance_transform(i, Transform3D(Basis(), mitte + Vector3(0, 0.14 + KOERPER_HOEHE * 0.5, 0)))
		_deckel_mm.set_instance_transform(i, Transform3D(Basis(), mitte + Vector3(0, 0.14 + KOERPER_HOEHE + 0.05, 0)))
		return
	if glas.is_empty():
		_koerper_mm.set_instance_transform(i, Transform3D(Basis(), VERSTECKT))
		_deckel_mm.set_instance_transform(i, Transform3D(Basis(), VERSTECKT))
		var koerper := _glas_block(Vector3(1.0, KOERPER_HOEHE, 1.0), w["farbe"],
			mitte + Vector3(0, 0.14 + KOERPER_HOEHE * 0.5, 0))
		var deckel := _glas_block(Vector3(1.0, 0.1, 1.0), w["hell"],
			mitte + Vector3(0, 0.14 + KOERPER_HOEHE + 0.05, 0))
		glas.append(koerper)
		glas.append(deckel)
	(glas[0].material_override as ShaderMaterial).set_shader_parameter("deckkraft", alpha)
	(glas[1].material_override as ShaderMaterial).set_shader_parameter("deckkraft", minf(1.0, alpha + 0.25))


func _glas_block(groesse: Vector3, farbe: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Stil3D.box(groesse.x, groesse.y, groesse.z)
	mi.material_override = Stil3D.material_glas(farbe)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # Glas wirft keinen Schatten
	mi.position = pos
	add_child(mi)
	return mi


# --- Abfragen für die Spiellogik ------------------------------------------------

## Zellbereich im Bild (+Rand) als [x0, y0, x1, y1) — aus den vier
## Bildecken auf die Bodenebene projiziert.
func sichtbarer_bereich(rand: int) -> Array[int]:
	if _kamera == null:
		return [0, 0, 0, 0]
	var groesse := get_viewport().get_visible_rect().size
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for ecke in [Vector2.ZERO, Vector2(groesse.x, 0), Vector2(0, groesse.y), groesse]:
		var o := _kamera.project_ray_origin(ecke)
		var n := _kamera.project_ray_normal(ecke)
		if absf(n.y) < 0.0001:
			continue
		var t := -o.y / n.y
		var p := o + n * t
		min_p = min_p.min(Vector2(p.x, p.z))
		max_p = max_p.max(Vector2(p.x, p.z))
	return [maxi(0, floori(min_p.x) - rand), maxi(0, floori(min_p.y) - rand),
		mini(_map.width, ceili(max_p.x) + rand), mini(_map.height, ceili(max_p.y) + rand)]


## WASD/Pfeile sind Bildschirm-Richtungen ("W" = nach oben im Bild) —
## umgerechnet auf Karten-Achsen (x = Welt-x, y = Welt-z).
func bildschirm_zu_karte(eingabe: Vector2) -> Vector2:
	return _rechts * eingabe.x + _vor * (-eingabe.y)
