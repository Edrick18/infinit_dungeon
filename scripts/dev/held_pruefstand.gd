extends Node3D
## Dev-Werkzeug: Helden-Prüfstand (Waffen- und Kleidungs-Sitz, STIL-3D.md 7h).
## Je Zeile ein Held (Ausrüstung frei wählbar), je Spalte eine Drehung.
##   godot --path . res://scripts/dev/held_pruefstand.tscn -- --shot=<pfad.png>
##     --held=<farbe>/<waffe>/<neben>/<ruestung>/<element>/<haar>[;…]
##        farbe = Stil3D-Farbname (ruestung, obsidian, silber …), waffe/neben = Item-Basis-IDs
##        (schwert, zweihandschwert, dolch, axt, zweihandaxt, knueppel, kriegshammer, bogen,
##        armbrust, turmschild, offensivstab, heiligstab | schild, dolch, koecher, zauberbuch,
##        kristallfokus, relikt, heiligkreuz), ruestung = keine|leder|kette|platte,
##        element = feuer|gift|"", haar = 0..14. Leere Felder = Standard.
##     [--drehungen=0,40,-40,90,180] (Grad je Spalte; 0 = Blick zur Kamera)
##     [--pose=idle:<s>|geh:<s>|angriff:<s>|treffer:<s>|ruhe] (Standard: Ruhe)
##     [--oben] (Dungeon-Blick: Ortho, Schrägsicht wie Zoom 16)
##     [--blick=x,y,z,fov] (Kamera auf einen Punkt, Abstand nach fov)
##     [--seite] (Kamera von rechts statt von vorn, nur mit --blick)
##     [--kampfblick] (Neigung der Kampfkamera, ~30° von oben)
##     [--ohne-namen] (keine Beschriftung)
##     [--portraet] (statt der Bühne: echte Porträts aus PortraitStudio im Raster, 2× groß)

const ABSTAND := 1.15
const REIHE := 3.4

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
		elif arg.begins_with("--held="):
			for s in arg.substr(7).split(";"):
				specs.append(s)
		elif arg.begins_with("--drehungen="):
			drehungen.clear()
			for w in arg.substr(12).split_floats(","):
				drehungen.append(w)
		elif arg.begins_with("--pose="):
			var teile := arg.substr(7).split(":")
			_pose_art = teile[0]
			_pose_t = float(teile[1]) if teile.size() > 1 else 0.2
	if specs.is_empty():
		specs.append("ruestung/schwert/schild/platte//0")
	get_viewport().msaa_3d = Viewport.MSAA_4X
	if "--portraet" in args:
		_portraets(specs, shot)
		return
	_umgebung()
	# Eine Reihe: je Held seine Drehungen nebeneinander (kleine Lücke zwischen Helden).
	var n := specs.size() * drehungen.size()
	var luecke := 0.5
	var breite := n * ABSTAND + (specs.size() - 1) * luecke
	Stil3D.teil(self, Stil3D.box(breite + 3.0, 0.1, 6.0), Stil3D.farbe("stein_dunkel"), Vector3(0, -0.05, 0),
		Vector3.ZERO, false)
	var x := -breite * 0.5 + ABSTAND * 0.5
	for i in specs.size():
		var x0 := x
		for j in drehungen.size():
			var f := _held(specs[i])
			add_child(f)
			f.position = Vector3(x, 0, 0)
			f.rotation_degrees.y = drehungen[j]
			f.set_meta("basis_y", 0.0)
			_figuren.append(f)
			x += ABSTAND
		if not "--ohne-namen" in args:
			var l := Label3D.new()
			l.text = specs[i]
			l.font_size = 18
			l.outline_size = 8
			l.no_depth_test = true
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.position = Vector3((x0 + x - ABSTAND) * 0.5, 0.02, 0.75)
			add_child(l)
		x += luecke
	var zeilen := 1
	var spalten := n + (specs.size() - 1) * luecke / ABSTAND
	_kamera(zeilen, spalten, args)
	_process(0.0)
	if shot != "":
		_foto(shot)


## Spezifikation farbe/waffe/neben/ruestung/element/haar » Held.
func _held(spec: String) -> Node3D:
	var f := spec.split("/")
	var feld := func(i: int, std: String) -> String: return f[i] if f.size() > i and f[i] != "" else std
	var farbe := Stil3D.farbe(feld.call(0, "ruestung"))
	var klasse := {"keine": Enums.ArmorClass.NONE, "leder": Enums.ArmorClass.LEATHER,
		"kette": Enums.ArmorClass.CHAIN, "platte": Enums.ArmorClass.PLATE}
	var a := {"bekannt": true, "waffe": feld.call(1, ""), "neben": feld.call(2, ""),
		"ruestung": int(klasse.get(feld.call(3, "keine"), Enums.ArmorClass.NONE)), "haar": int(feld.call(5, "0"))}
	var element: String = feld.call(4, "")
	if element != "":
		a["element"] = element
	return FigurenBau.held_mit(farbe, a)


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


func _kamera(zeilen: int, spalten: float, args: PackedStringArray) -> void:
	var cam := Camera3D.new()
	add_child(cam)
	var ziel := Vector3(0, 0.62, -(zeilen - 1) * REIHE * 0.5)
	var breite := spalten * ABSTAND
	var seite := "--seite" in args
	for arg in args:
		if arg.begins_with("--blick="):
			var w := arg.substr(8).split_floats(",")
			cam.fov = w[3] if w.size() > 3 else 20.0
			var z := Vector3(w[0], w[1], w[2])
			var weg := Vector3(4.2, 1.4, 0.0) if seite else Vector3(0.0, 1.4, 4.2)
			cam.look_at_from_position(z + weg * cam.fov / 20.0, z)
			return
	if "--oben" in args:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = maxf(breite * 0.46, 2.0)
		cam.look_at_from_position(ziel + Vector3(11, 12.5, 11), ziel)
		return
	var weg2 := Vector3(0, 2.0 + zeilen * 0.5, 6.0 + zeilen * 1.2)
	if "--kampfblick" in args:  # Neigung der Kampfkamera (~30° von oben)
		weg2 = Vector3(0, 5.8, 10.0)
	var dist := weg2.length()
	var aspekt := 1280.0 / 720.0
	var halb := maxf(breite * 0.52 / aspekt, (zeilen * 1.0 + 0.5) * 0.5)
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
			_:
				Gliederpuppe.ruhe(fig)
		fig.position.y = float(fig.get_meta("basis_y", 0.0))
		fig.scale = Vector3.ONE
		Gliederpuppe.hub_anwenden(fig)
		fig.rotation.x = wurzel.x
		fig.rotation.z = wurzel.z


## Echte Porträts (PortraitStudio, 128²) im Raster, doppelt groß gespeichert.
func _portraets(specs: Array[String], shot: String) -> void:
	var studio := PortraitStudio.new()
	add_child(studio)
	var texturen: Array[Texture2D] = []
	for i in specs.size():
		var spec := specs[i]
		texturen.append(studio.textur("pruef|%d|%s" % [i, spec], func() -> Node3D: return _held(spec)))
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
