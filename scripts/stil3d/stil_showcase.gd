extends Node3D
## Stil-Showcase für den 3D-Design-Standard (docs/STIL-3D.md).
## F6 in Godot = Dungeon-Ansicht. Screenshot-Modus über User-Args:
##   -- --shot=<pfad.png> [--modus=kampf]


var _figuren: Array[Node3D] = []
var _fackeln: Array[Node3D] = []
var _zeit := 0.0


func _ready() -> void:
	var modus := "dungeon"
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.substr(7)
		elif arg.begins_with("--modus="):
			modus = arg.substr(8)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_umgebung()
	if modus == "kampf":
		_kampf_bauen()
	else:
		_dungeon_bauen()
	if shot != "":
		_foto(shot)


func _process(delta: float) -> void:
	_zeit += delta
	for i in _figuren.size():
		var fig := _figuren[i]
		var basis: float = fig.get_meta("basis_y", 0.0)
		var phase := i * 1.7
		fig.position.y = basis + sin(_zeit * 2.2 + phase) * float(fig.get_meta("wippen", 0.0))
		var quetsch := float(fig.get_meta("quetschen", 0.0))
		if quetsch > 0.0:
			var s := sin(_zeit * 3.0 + phase) * quetsch
			fig.scale = Vector3(1.0 - s * 0.5, 1.0 + s, 1.0 - s * 0.5)
	for i in _fackeln.size():
		var licht: OmniLight3D = _fackeln[i].get_meta("licht")
		licht.light_energy = 0.7 * (0.88 + 0.12 * sin(_zeit * 13.0 + i) * sin(_zeit * 7.3 + i * 2.0))


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


func _sonne(rot: Vector3) -> void:
	var sonne := DirectionalLight3D.new()
	sonne.rotation_degrees = rot
	sonne.light_color = Color(1.0, 0.95, 0.86)
	sonne.light_energy = 0.78
	sonne.shadow_enabled = true
	sonne.directional_shadow_max_distance = 30.0
	add_child(sonne)


func _figur(fig: Node3D, pos: Vector3, blick_grad: float) -> Node3D:
	add_child(fig)
	fig.position = pos
	fig.rotation_degrees.y = blick_grad
	fig.set_meta("basis_y", pos.y)
	_figuren.append(fig)
	return fig


# --- Ansicht 1: Dungeon-Diorama (Erkunden) -------------------------------------

func _dungeon_bauen() -> void:
	_sonne(Vector3(-52, 110, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var treppe := Vector2i(-3, 2)
	# Fugen-Sockel unter allen Platten = dunkle Fugen + Diorama-Kante
	Stil3D.teil(self, Stil3D.box(9.0, 0.5, 9.0), Stil3D.farbe("fuge"), Vector3(-0.5, -0.27, -0.5), Vector3.ZERO, false)
	for gx in range(-5, 4):
		for gz in range(-5, 4):
			if Vector2i(gx, gz) == treppe:
				continue
			var hell := 0.96 + rng.randf() * 0.08
			var grund: Color = Stil3D.farbe("stein") * (1.0 if (gx + gz) % 2 == 0 else 0.93)
			Stil3D.teil(self, Stil3D.box(0.94, 0.16, 0.94), grund * hell, Vector3(gx, -0.08, gz), Vector3.ZERO, false)
	# Wände nur auf der Kamera-abgewandten Seite (Diorama-Schnitt)
	for i in range(-5, 4):
		_wandblock(Vector3(i, 0, -6), rng)
		_wandblock(Vector3(-6, 0, i), rng)
	_wandblock(Vector3(-6, 0, -6), rng)
	# Treppe nach unten
	Stil3D.teil(self, Stil3D.box(0.94, 0.6, 0.94), Stil3D.farbe("nacht"), Vector3(treppe.x, -0.3, treppe.y), Vector3.ZERO, false)
	for s in 3:
		Stil3D.teil(self, Stil3D.box(0.94, 0.12, 0.3), Stil3D.farbe("stein_hell") * (1.0 - s * 0.22),
			Vector3(treppe.x, -0.1 - s * 0.16, treppe.y - 0.32 + s * 0.31), Vector3.ZERO, false)
	# Fackeln an der Rückwand
	for pos in [Vector3(-3, 1.0, -5.42), Vector3(1, 1.0, -5.42)]:
		var f := FigurenBau.fackel()
		add_child(f)
		f.position = pos
		_fackeln.append(f)
	var f2 := FigurenBau.fackel()
	add_child(f2)
	f2.position = Vector3(-5.42, 1.0, -1)
	f2.rotation_degrees.y = 90
	_fackeln.append(f2)
	# Bewohner
	var truhe := FigurenBau.truhe()
	add_child(truhe)
	truhe.position = Vector3(1.6, 0, -4)
	truhe.rotation_degrees.y = 20
	_figur(FigurenBau.golem(), Vector3(-3.6, 0, -3.4), 30)
	_figur(FigurenBau.schleim(), Vector3(-1.2, 0, -1.6), 40)
	_figur(FigurenBau.fledermaus(), Vector3(1.4, 0.15, -1.6), 50)
	_figur(FigurenBau.wolf(), Vector3(0.9, 0, 0.9), 70)
	_figur(FigurenBau.held(), Vector3(-1.0, 0, 1.8), 45)
	# Kamera: orthografisch, 45° Diorama-Blick
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 7.6
	add_child(cam)
	cam.position = Vector3(11, 12.5, 11)
	cam.look_at(Vector3(-0.9, 0.1, -1.0))


func _wandblock(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var h := 1.5 + (0.12 if rng.randf() < 0.2 else 0.0)
	var dunkel := Stil3D.farbe("stein_dunkel") * (0.94 + rng.randf() * 0.08)
	Stil3D.teil(self, Stil3D.box(1.0, h, 1.0), dunkel, pos + Vector3(0, h * 0.5 - 0.16, 0))
	Stil3D.teil(self, Stil3D.box(1.0, 0.1, 1.0), Stil3D.farbe("stein_hell"), pos + Vector3(0, h - 0.11, 0), Vector3.ZERO, false)


# --- Ansicht 2: Kampf (DQ-Frontalblick) ------------------------------------------

func _kampf_bauen() -> void:
	_sonne(Vector3(-40, -25, 0))
	Stil3D.teil(self, Stil3D.zylinder(4.6, 4.8, 0.3), Stil3D.farbe("stein_dunkel"), Vector3(0, -0.15, -0.6))
	Stil3D.teil(self, Stil3D.zylinder(3.6, 3.6, 0.06), Stil3D.farbe("stein"), Vector3(0, 0.0, -0.6), Vector3.ZERO, false)
	for x in [-4.2, -1.5, 1.5, 4.2]:
		Stil3D.teil(self, Stil3D.zylinder(0.32, 0.36, 3.4), Stil3D.farbe("stein_dunkel"), Vector3(x, 1.6, -4.6))
		Stil3D.teil(self, Stil3D.box(0.86, 0.22, 0.86), Stil3D.farbe("stein"), Vector3(x, 3.35, -4.6))
	for x in [-2.85, 2.85]:
		var f := FigurenBau.fackel()
		add_child(f)
		f.position = Vector3(x, 1.7, -4.3)
		_fackeln.append(f)
	# Monster in leichter 3/4-Ansicht (JRPG-Klassiker), zur Mitte gedreht
	_figur(FigurenBau.fledermaus(), Vector3(-2.6, 0.3, 0.2), 30)
	_figur(FigurenBau.wolf(), Vector3(-1.0, 0, 0.35), 32)
	_figur(FigurenBau.golem(), Vector3(0.8, 0, -0.35), -18)
	_figur(FigurenBau.schleim(), Vector3(2.5, 0, 0.4), -30)
	var cam := Camera3D.new()
	cam.fov = 36.0
	add_child(cam)
	cam.position = Vector3(0, 2.0, 7.4)
	cam.look_at(Vector3(0, 0.7, 0))


# --- Screenshot ---------------------------------------------------------------

func _foto(pfad: String) -> void:
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pfad)
	get_tree().quit()
