class_name MenueKulisse
extends Control
## 3D-Hintergrund aller Menüs (ersetzt den alten 2D-Funkenhintergrund):
## ein kleines Diorama mit der eigenen Party, die Kamera pendelt langsam.
## Je Ort ein anderes Herzstück — Lagerfeuer (Standard), Tavernentisch,
## Schmiede-Esse, Händlertresen. Eigene SubViewport-Welt + Schleier und
## Vignette, damit die UI davor immer lesbar bleibt (STIL-3D.md 7e).

const PENDEL_TEMPO := 0.11
const PENDEL_WEITE := 0.55
const KAMERA_ABSTAND := 9.8
const KAMERA_HOEHE := 4.6
const ZIEL := Vector3(0, 1.1, -0.4)

var ort: StringName
var _vp: SubViewport
var _kamera: Camera3D
var _flackern: Array[OmniLight3D] = []
var _helden: Array[Node3D] = []
var _zeit := 0.0


## ruhig: dunklerer Schleier für textlastige Bildschirme (Inventar, Lexikon …).
func _init(p_ort: StringName = &"lager", ruhig := false) -> void:
	ort = p_ort
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var behaelter := SubViewportContainer.new()
	behaelter.stretch = true
	behaelter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	behaelter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(behaelter)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	behaelter.add_child(_vp)
	_szene_bauen()

	# Schleier + Vignette: die Kulisse liefert Stimmung, die UI bleibt Star.
	var schleier := ColorRect.new()
	schleier.color = Color(0.05, 0.05, 0.11, 0.68 if ruhig else 0.30)
	schleier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	schleier.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(schleier)
	var verlauf := Gradient.new()
	verlauf.set_color(0, Color(0, 0, 0, 0))
	verlauf.set_color(1, Color(0.02, 0.02, 0.05, 0.9))
	verlauf.add_point(0.55, Color(0.02, 0.02, 0.05, 0.25))
	var tex := GradientTexture2D.new()
	tex.gradient = verlauf
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.42)
	tex.fill_to = Vector2(1.2, 1.15)
	var vignette := TextureRect.new()
	vignette.texture = tex
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vignette)


func _ready() -> void:
	UiTheme.szene_einblenden(get_parent())


func _szene_bauen() -> void:
	var welt := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Stil3D.farbe("nacht").srgb_to_linear()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.36, 0.62)
	env.ambient_light_energy = 0.34
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_hdr_threshold = 0.8
	welt.environment = env
	_vp.add_child(welt)
	var mond := DirectionalLight3D.new()
	mond.rotation_degrees = Vector3(-50, 35, 0)
	mond.light_color = Color(0.62, 0.66, 1.0)
	mond.light_energy = 0.4
	mond.shadow_enabled = true
	mond.directional_shadow_max_distance = 20.0
	_vp.add_child(mond)
	# Weicher Aufheller von vorn: Gesichter der Party bleiben lesbar, obwohl
	# Feuer und Fackeln von hinten leuchten.
	var aufheller := DirectionalLight3D.new()
	aufheller.rotation_degrees = Vector3(-25, 0, 0)
	aufheller.light_color = Color(1.0, 0.86, 0.72)
	aufheller.light_energy = 0.35
	_vp.add_child(aufheller)

	var w := Node3D.new()
	_vp.add_child(w)
	_insel(w)
	match ort:
		&"taverne": _taverne(w)
		&"schmiede": _schmiede(w)
		&"laden": _laden(w)
		_: _lager(w)
	_party(w)

	_kamera = Camera3D.new()
	_kamera.fov = 34.0
	_vp.add_child(_kamera)
	_kamera_setzen()


## Runde Steininsel im Nachtschwarz + Ruinenbogen mit zwei Fackeln dahinter.
func _insel(w: Node3D) -> void:
	Stil3D.teil(w, Stil3D.zylinder(4.6, 4.3, 0.7), Stil3D.farbe("fuge"), Vector3(0, -0.42, 0))
	for ring in 5:
		var anzahl := 1 if ring == 0 else ring * 7
		for i in anzahl:
			var winkel := TAU * i / anzahl + ring * 0.37
			var r := ring * 0.92
			var hell := 0.82 + float((ring * 5 + i * 3) % 7) * 0.025
			Stil3D.teil(w, Stil3D.box(0.8, 0.14, 0.8), Stil3D.farbe("stein_dunkel") * hell,
				Vector3(cos(winkel) * r, -0.07, sin(winkel) * r), Vector3(0, -rad_to_deg(winkel), 0), false)
	for seite in [-1.0, 1.0]:
		for stock in 3:
			Stil3D.teil(w, Stil3D.box(0.8, 0.7, 0.8), Stil3D.farbe("stein_dunkel") * (1.0 - stock * 0.06),
				Vector3(1.75 * seite, 0.35 + stock * 0.7, -3.2))
		var fackel := FigurenBau.fackel()
		w.add_child(fackel)
		fackel.position = Vector3(1.25 * seite, 1.25, -2.75)
		var licht: OmniLight3D = fackel.get_meta("licht")
		licht.light_energy = 0.55
		_flackern.append(licht)
	Stil3D.teil(w, Stil3D.box(4.3, 0.55, 0.8), Stil3D.farbe("stein_dunkel"), Vector3(0, 2.38, -3.2))
	Stil3D.teil(w, Stil3D.box(4.5, 0.12, 0.95), Stil3D.farbe("stein_hell"), Vector3(0, 2.72, -3.2))


func _deko(w: Node3D, liste: Array) -> void:
	for d in liste:
		var deko := FigurenBau.deko(d[0])
		w.add_child(deko)
		deko.position = d[1]
		deko.rotation.y = float(absi(hash(str(d[1]))) % 628) / 100.0


func _feuer(w: Node3D, pos: Vector3, groesse: float, energie: float) -> OmniLight3D:
	Stil3D.teil(w, Stil3D.kegel(0.2 * groesse, 0.55 * groesse), Stil3D.farbe("flamme"), pos,
		Vector3.ZERO, false, Stil3D.farbe("flamme") * 1.4)
	Stil3D.teil(w, Stil3D.kegel(0.11 * groesse, 0.38 * groesse), Stil3D.farbe("glut"),
		pos + Vector3(0.02, -0.02, 0.02), Vector3.ZERO, false, Stil3D.farbe("glut") * 1.6)
	var licht := OmniLight3D.new()
	licht.light_color = Color(1.0, 0.58, 0.25)
	licht.light_energy = energie
	licht.omni_range = 5.0
	licht.shadow_enabled = true
	licht.position = pos + Vector3(0, 0.35, 0)
	licht.set_meta("basis", energie)
	w.add_child(licht)
	_flackern.append(licht)
	var funken := CPUParticles3D.new()
	funken.amount = 24
	funken.lifetime = 2.0
	funken.mesh = Stil3D.kugel(0.022)
	funken.material_override = Stil3D.material(Stil3D.farbe("glut"), -1, Stil3D.farbe("glut") * 2.2)
	funken.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	funken.emission_sphere_radius = 0.14 * groesse
	funken.direction = Vector3.UP
	funken.spread = 20.0
	funken.initial_velocity_min = 0.5
	funken.initial_velocity_max = 1.1
	funken.gravity = Vector3(0, 0.1, 0)
	funken.scale_amount_min = 0.5
	funken.scale_amount_max = 1.3
	funken.position = pos + Vector3(0, 0.15, 0)
	w.add_child(funken)
	return licht


func _lager(w: Node3D) -> void:
	for i in 7:
		var winkel := TAU * i / 7.0
		Stil3D.teil(w, Stil3D.kugel(0.13, 0.17), Stil3D.farbe("stein_dunkel"),
			Vector3(cos(winkel) * 0.42, 0.06, sin(winkel) * 0.42))
	for i in 3:
		Stil3D.teil(w, Stil3D.zylinder(0.055, 0.065, 0.7), Stil3D.farbe("holz"),
			Vector3(0, 0.12, 0), Vector3(72, i * 60.0, 0))
	_feuer(w, Vector3(0, 0.36, 0), 1.0, 1.15)
	_deko(w, [["fass", Vector3(-3.0, 0, 1.2)], ["felsbrocken", Vector3(3.1, 0, 0.9)],
		["pilz", Vector3(2.3, 0, -2.0)], ["knochen", Vector3(-2.1, 0, 2.4)],
		["fass", Vector3(-3.4, 0, 0.3)], ["pilz", Vector3(-1.5, 0, -2.4)]])


func _taverne(w: Node3D) -> void:
	var holz := Stil3D.farbe("holz")
	Stil3D.teil(w, Stil3D.box(2.4, 0.12, 1.1), holz, Vector3(0, 0.66, -0.2))
	for x in [-1.05, 1.05]:
		for z in [-0.62, 0.22]:
			Stil3D.teil(w, Stil3D.box(0.1, 0.6, 0.1), holz * 0.85, Vector3(x, 0.3, z))
	for z in [-1.05, 0.65]:
		Stil3D.teil(w, Stil3D.box(2.2, 0.08, 0.32), Stil3D.farbe("holz_hell"), Vector3(0, 0.38, z))
	# Krüge, Teller, Kerze
	for p in [Vector3(-0.8, 0.8, -0.05), Vector3(-0.3, 0.8, -0.45), Vector3(0.45, 0.8, 0.0), Vector3(0.9, 0.8, -0.4)]:
		Stil3D.teil(w, Stil3D.zylinder(0.075, 0.07, 0.18), Stil3D.farbe("eisen"), p)
		Stil3D.teil(w, Stil3D.zylinder(0.06, 0.06, 0.02), Stil3D.farbe("weiss"), p + Vector3(0, 0.09, 0),
			Vector3.ZERO, false)
	Stil3D.teil(w, Stil3D.zylinder(0.2, 0.2, 0.03), Stil3D.farbe("weiss") * 0.9, Vector3(0.05, 0.73, -0.25))
	Stil3D.teil(w, Stil3D.kugel(0.11, 0.14), Stil3D.farbe("braun_hell"), Vector3(0.05, 0.8, -0.25))
	Stil3D.teil(w, Stil3D.zylinder(0.045, 0.05, 0.22), Stil3D.farbe("weiss"), Vector3(-0.05, 0.83, 0.15))
	_feuer(w, Vector3(-0.05, 0.98, 0.15), 0.28, 1.2)
	_deko(w, [["fass", Vector3(-2.7, 0, -1.3)], ["fass", Vector3(-3.2, 0, -0.5)], ["fass", Vector3(-2.9, 0.62, -0.9)],
		["fass", Vector3(2.9, 0, -1.2)], ["felsbrocken", Vector3(3.2, 0, 1.2)]])


func _schmiede(w: Node3D) -> void:
	var stein := Stil3D.farbe("stein_dunkel")
	Stil3D.teil(w, Stil3D.box(1.5, 1.1, 1.1), stein, Vector3(-1.0, 0.55, -1.25))
	Stil3D.teil(w, Stil3D.box(1.65, 0.14, 1.25), Stil3D.farbe("stein_hell"), Vector3(-1.0, 1.15, -1.25))
	Stil3D.teil(w, Stil3D.zylinder(0.32, 0.42, 1.2), stein * 0.9, Vector3(-1.0, 1.8, -1.35))
	Stil3D.teil(w, Stil3D.box(0.75, 0.42, 0.06), Stil3D.farbe("glut"), Vector3(-1.0, 0.55, -0.69),
		Vector3.ZERO, false, Stil3D.farbe("flamme") * 1.8)
	var esse := _feuer(w, Vector3(-1.0, 0.4, -0.55), 0.6, 2.2)
	esse.light_color = Color(1.0, 0.5, 0.2)
	_deko(w, [["amboss", Vector3(0.75, 0, -0.35)], ["fass", Vector3(2.6, 0, -1.4)], ["felsbrocken", Vector3(-3.0, 0, 1.0)]])
	# Waffenständer mit drei Klingen
	Stil3D.teil(w, Stil3D.box(1.2, 0.08, 0.2), Stil3D.farbe("holz"), Vector3(1.9, 0.9, -1.7))
	for i in 3:
		var x := 1.5 + i * 0.4
		Stil3D.teil(w, Stil3D.box(0.08, 0.95, 0.03), Stil3D.farbe("eisen") * 1.25, Vector3(x, 0.6, -1.62), Vector3(0, 0, 6))
		Stil3D.teil(w, Stil3D.box(0.22, 0.05, 0.06), Stil3D.farbe("gold"), Vector3(x + 0.02, 1.08, -1.62))


func _laden(w: Node3D) -> void:
	var holz := Stil3D.farbe("holz")
	Stil3D.teil(w, Stil3D.box(2.8, 0.8, 0.7), holz * 0.9, Vector3(0, 0.4, -0.9))
	Stil3D.teil(w, Stil3D.box(3.0, 0.1, 0.85), Stil3D.farbe("holz_hell"), Vector3(0, 0.85, -0.9))
	# Regal mit Tränken
	for x in [-1.5, 1.5]:
		Stil3D.teil(w, Stil3D.box(0.12, 2.0, 0.45), holz * 0.8, Vector3(x, 1.0, -2.2))
	var farben := ["umhang", "schleim", "kristall", "lila", "moos", "gold", "pilz_rot"]
	for reihe in 2:
		var y := 0.9 + reihe * 0.7
		Stil3D.teil(w, Stil3D.box(3.0, 0.07, 0.45), holz, Vector3(0, y, -2.2))
		for i in 6:
			var f: Color = Stil3D.farbe(farben[(i + reihe * 3) % farben.size()])
			var p := Vector3(-1.15 + i * 0.46, y + 0.16, -2.15)
			Stil3D.teil(w, Stil3D.kugel(0.13, 0.24), f, p, Vector3.ZERO, true, f * 0.35)
			Stil3D.teil(w, Stil3D.zylinder(0.04, 0.05, 0.12), Stil3D.farbe("weiss") * 0.9, p + Vector3(0, 0.16, 0))
	# Münzstapel + Truhe auf/vor dem Tresen
	for i in 3:
		for h in 3 - i:
			Stil3D.teil(w, Stil3D.zylinder(0.09, 0.09, 0.035), Stil3D.farbe("gold"),
				Vector3(-0.9 + i * 0.25, 0.92 + h * 0.04, -0.75), Vector3.ZERO, false, Stil3D.farbe("gold") * 0.25)
	var truhe := FigurenBau.truhe(Stil3D.farbe("gold"))
	w.add_child(truhe)
	truhe.position = Vector3(2.3, 0, -0.3)
	truhe.rotation.y = -0.5
	var laterne := OmniLight3D.new()
	laterne.light_color = Color(1.0, 0.75, 0.4)
	laterne.light_energy = 1.3
	laterne.omni_range = 6.0
	laterne.shadow_enabled = true
	laterne.position = Vector3(0.4, 1.9, -0.3)
	laterne.set_meta("basis", 1.3)
	w.add_child(laterne)
	_flackern.append(laterne)
	Stil3D.teil(w, Stil3D.kugel(0.12), Stil3D.farbe("glut"), Vector3(0.4, 1.78, -0.9), Vector3.ZERO, true,
		Stil3D.farbe("glut") * 1.5)
	_deko(w, [["fass", Vector3(-2.7, 0, -1.0)], ["pilz", Vector3(3.0, 0, 1.0)]])


## Die eigene Party (bis zu 4): ums Lagerfeuer im Kreis, sonst im Bogen
## vor dem Herzstück, leicht zur Mitte gedreht.
func _party(w: Node3D) -> void:
	var helden: Array = GameState.party.slice(0, 4)
	var anzahl := helden.size()
	if anzahl == 0:
		var schleim := FigurenBau.schleim()
		w.add_child(schleim)
		schleim.position = Vector3(1.3, 0, 0.6)
		schleim.rotation.y = -0.6
		return
	for i in anzahl:
		var figur := FigurenBau.held_aus(helden[i])
		w.add_child(figur)
		if ort == &"lager":
			var winkel := -PI * 0.5 + (float(i) - (anzahl - 1) * 0.5) * 0.85
			figur.position = Vector3(cos(winkel) * 1.45, 0, sin(winkel) * 1.45)
			figur.rotation.y = atan2(-figur.position.x, -figur.position.z) * 0.6
		else:
			var x := (float(i) - (anzahl - 1) * 0.5) * 1.05
			figur.position = Vector3(x, 0, 1.45 - absf(x) * 0.3)
			figur.rotation.y = -x * 0.3
		figur.set_meta("phase", float(i) * 1.7)
		figur.set_meta("skala", figur.scale)
		_helden.append(figur)


func _kamera_setzen() -> void:
	var winkel := sin(_zeit * PENDEL_TEMPO) * PENDEL_WEITE
	var pos := Vector3(sin(winkel) * KAMERA_ABSTAND, KAMERA_HOEHE, cos(winkel) * KAMERA_ABSTAND)
	_kamera.transform = Transform3D(Basis.looking_at(ZIEL - pos, Vector3.UP), pos)


func _process(delta: float) -> void:
	_zeit += delta
	_kamera_setzen()
	for i in _flackern.size():
		var licht := _flackern[i]
		var basis: float = licht.get_meta("basis", 0.55)
		licht.light_energy = basis * (0.86 + 0.14 * sin(_zeit * 11.0 + i * 2.1) * sin(_zeit * 6.7 + i))
	# Leichtes Atmen der Helden (Idle-Wippen wie im Dungeon).
	for held in _helden:
		var s: Vector3 = held.get_meta("skala")
		held.scale = s * Vector3(1.0, 1.0 + 0.018 * sin(_zeit * 2.2 + float(held.get_meta("phase"))), 1.0)
