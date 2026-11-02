extends Node3D
## Dev-Werkzeug: Gegner-Prüfstand (Waffen- und Kleidungs-Sitz der Gegner,
## STIL-3D.md 7h-7k). Je Gegner seine Drehungen nebeneinander.
##   godot --path . res://scripts/dev/gegner_pruefstand.tscn -- --shot=<pfad.png>
##     --gegner=<id>[:boss|:elite][;…]   (Archetyp-IDs wie FigurenBau.fuer_archetyp)
##     [--drehungen=0,40,-40,90,180] (Grad je Spalte; 0 = Blick zur Kamera)
##     [--pose=idle:<s>|geh:<s>|angriff:<s>|treffer:<s>|phase:<s>|panzer|segen|ruf|woge|heulen|stachel:<s>|ruhe]
##     [--abstand=1.3] (Spaltenabstand)
##     [--oben] (Dungeon-Blick: Ortho, Schrägsicht wie Zoom 16)
##     [--blick=x,y,z,fov] (Kamera auf einen Punkt) [--seite] (von rechts, nur mit --blick)
##     [--steil] (mit --blick: fast senkrecht von oben)
##     [--kampfblick] (Neigung der Kampfkamera, ~30° von oben) [--ohne-namen]
##     [--portraet] (echte Porträts aus PortraitStudio im Raster)

const REIHE := 3.4
const SONDERPOSEN := ["panzer", "segen", "ruf", "woge", "heulen", "stachel"]

var _abstand := 1.3
var _figuren: Array[Node3D] = []
var _pose_art := "ruhe"
var _pose_t := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := ""
	var specs: Array[String] = []
	var drehungen: Array[float] = [0.0, 40.0, -40.0, 90.0, 180.0]
	for arg in args:
		if arg.begins_with("--shot="):
			shot = arg.substr(7)
		elif arg.begins_with("--gegner="):
			for s in arg.substr(9).split(";"):
				specs.append(s)
		elif arg.begins_with("--drehungen="):
			drehungen.clear()
			for w in arg.substr(12).split_floats(","):
				drehungen.append(w)
		elif arg.begins_with("--abstand="):
			_abstand = float(arg.substr(10))
		elif arg.begins_with("--pose="):
			var teile := arg.substr(7).split(":")
			_pose_art = teile[0]
			_pose_t = float(teile[1]) if teile.size() > 1 else 0.6
	if specs.is_empty():
		specs.append("bandit")
	get_viewport().msaa_3d = Viewport.MSAA_4X
	if "--portraet" in args:
		_portraets(specs, shot)
		return
	_umgebung()
	var n := specs.size() * drehungen.size()
	var luecke := 0.4
	var breite := n * _abstand + (specs.size() - 1) * luecke
	Stil3D.teil(self, Stil3D.box(breite + 3.0, 0.1, 6.0), Stil3D.farbe("stein_dunkel"), Vector3(0, -0.05, 0),
		Vector3.ZERO, false)
	var x := -breite * 0.5 + _abstand * 0.5
	for i in specs.size():
		var x0 := x
		for j in drehungen.size():
			var f := _gegner(specs[i])
			add_child(f)
			f.position = Vector3(x, 0, 0)
			f.rotation_degrees.y = drehungen[j]
			f.set_meta("basis_y", 0.0)
			_figuren.append(f)
			x += _abstand
		if not "--ohne-namen" in args:
			var l := Label3D.new()
			l.text = specs[i]
			l.font_size = 18
			l.outline_size = 8
			l.no_depth_test = true
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.position = Vector3((x0 + x - _abstand) * 0.5, 0.02, 0.85)
			add_child(l)
		x += luecke
	_kamera(n + (specs.size() - 1) * luecke / _abstand, args)
	_process(0.0)
	if shot != "":
		_foto(shot)


func _gegner(spec: String) -> Node3D:
	var f := spec.split(":")
	var opt := {}
	if f.size() > 1 and f[1] == "boss":
		opt = {"boss": true, "massstab": FigurenBau.KAMPF_BOSS_MASSSTAB}
	elif f.size() > 1 and f[1] == "elite":
		opt = {"akzent": Stil3D.farbe("lila")}
	return FigurenBau.fuer_archetyp(StringName(f[0]), opt)


func _umgebung() -> void:
	var welt := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Stil3D.farbe("nacht").srgb_to_linear()
	Stil3D.umgebung(env, Color(0.46, 0.42, 0.68), 0.42)
	welt.environment = env
	add_child(welt)
	var sonne := DirectionalLight3D.new()
	sonne.rotation_degrees = Vector3(-50, 35, 0)
	sonne.light_color = Color(1.0, 0.95, 0.86)
	sonne.light_energy = 0.78
	sonne.shadow_enabled = true
	sonne.directional_shadow_max_distance = 30.0
	add_child(sonne)


func _kamera(spalten: float, args: PackedStringArray) -> void:
	var cam := Camera3D.new()
	add_child(cam)
	var ziel := Vector3(0, 0.7, 0)
	var breite := spalten * _abstand
	for arg in args:
		if arg.begins_with("--blick="):
			var w := arg.substr(8).split_floats(",")
			cam.fov = w[3] if w.size() > 3 else 20.0
			var z := Vector3(w[0], w[1], w[2])
			var weg := Vector3(4.2, 1.4, 0.0) if "--seite" in args else Vector3(0.0, 1.4, 4.2)
			if "--steil" in args:  # fast senkrecht von oben (Dungeon-Neigung, nah)
				weg = Vector3(0.0, 4.0, 1.6)
			cam.look_at_from_position(z + weg * cam.fov / 20.0, z)
			return
	if "--oben" in args:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = maxf(breite * 0.46, 2.0)
		cam.look_at_from_position(ziel + Vector3(11, 12.5, 11), ziel)
		return
	var weg2 := Vector3(0, 2.5, 7.2)
	if "--kampfblick" in args:
		weg2 = Vector3(0, 5.8, 10.0)
	var dist := weg2.length()
	var halb := maxf(breite * 0.52 / (1280.0 / 720.0), 0.9)
	cam.fov = rad_to_deg(2.0 * atan(halb / dist))
	cam.look_at_from_position(ziel + weg2, ziel)


func _process(_delta: float) -> void:
	for fig in _figuren:
		if not fig.has_meta("glieder"):
			continue
		var wurzel := Vector3.ZERO
		match _pose_art:
			"idle":
				wurzel = Gliederpuppe.beleben(fig, _pose_t)
			"geh":
				wurzel = Gliederpuppe.beleben(fig, _pose_t, -1.0, -1.0, true)
			"angriff":
				wurzel = Gliederpuppe.beleben(fig, -1.0, _pose_t)
			"treffer":
				wurzel = Gliederpuppe.beleben(fig, -1.0, -1.0, _pose_t)
			"phase":
				wurzel = Gliederpuppe.beleben(fig, -1.0, -1.0, -1.0, false, _pose_t)
			_:
				if _pose_art in SONDERPOSEN:
					wurzel = Gliederpuppe.beleben(fig, -1.0, -1.0, -1.0, false, -1.0, _pose_t, _pose_art)
				else:
					Gliederpuppe.ruhe(fig)
		fig.position.y = float(fig.get_meta("basis_y", 0.0)) + float(fig.get_meta("schwebt", 0.0))
		fig.scale = Vector3.ONE
		Gliederpuppe.hub_anwenden(fig)
		fig.rotation.x = wurzel.x
		fig.rotation.z = wurzel.z


func _portraets(specs: Array[String], shot: String) -> void:
	var studio := PortraitStudio.new()
	add_child(studio)
	var texturen: Array[Texture2D] = []
	for i in specs.size():
		var spec := specs[i]
		texturen.append(studio.textur("gpruef|%d|%s" % [i, spec], func() -> Node3D: return _gegner(spec)))
	for n in 60:
		await get_tree().process_frame
		if studio.ausstehend() == 0:
			break
	for n in 4:
		await get_tree().process_frame
	var g := PortraitStudio.GROESSE * 2
	var spalten := mini(6, specs.size())
	var zeilen := ceili(float(specs.size()) / spalten)
	var bild := Image.create(spalten * g, zeilen * g, false, Image.FORMAT_RGBA8)
	bild.fill(Color(0.1, 0.1, 0.14))
	for i in texturen.size():
		var img := texturen[i].get_image()
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		img.resize(g, g, Image.INTERPOLATE_NEAREST)
		bild.blit_rect(img, Rect2i(0, 0, g, g), Vector2i((i % spalten) * g, (i / spalten) * g))
	if shot != "":
		bild.save_png(shot)
	get_tree().quit()


func _foto(pfad: String) -> void:
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pfad)
	get_tree().quit()
