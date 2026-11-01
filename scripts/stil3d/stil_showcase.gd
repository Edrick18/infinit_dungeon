extends Node3D
## Stil-Showcase für den 3D-Design-Standard (docs/STIL-3D.md).
## F6 in Godot = Dungeon-Ansicht. Screenshot-Modus über User-Args:
##   -- --shot=<pfad.png> [--modus=kampf|geruest|figuren|vierbeiner] [--fern|--nah] [--pose=angriff:0.24]
##      (--pose=heulen|panzer|stachel|segen|woge|ruf:<s> = Sonderpose einer Fähigkeit, STIL-3D.md 7k)
##      [--blick=x,y,z,fov] (Kamera auf einen Punkt, z. B. Nahaufnahme einer Figur)
## figuren: alle Zweibeiner-Gegner (zwei Reihen) und sechs Helden (Figuren 2.0,
## STIL-3D.md 7h), --fern = Ortho-Zoom 16, --boss = Gegner als Boss.
## vierbeiner: Vierbeiner und Schleime (STIL-3D.md 7i) in der Aufstellung des
## Entwurfs (drei Reihen), --fern, --boss, --elite, --pose wie oben
## (--pose=phase:0.6 = Boss-Phasenpose).
## kreaturen: Krabbler, Flieger, Golems, Geist, Mimic (STIL-3D.md 7j) — wie
## vierbeiner (gleiche Kamera und Optionen --fern, --boss, --elite, --nur, --blick).
## varianten: Rang-, Sonder- und Boss-Schmuck aller Gruppen — Spalten normal,
## Elite, Champion, Gülden, Strahlend, Kartenhüter, Boss; Zeilen je eine Figur
## (--ids=bandit,wolf,… ändert die Zeilen), --fern = Ortho-Zoom 16.
## akzente: Varianten- und Element-Akzente (STIL-3D.md 9) — je Zeile eine Art
## mit ihren Klassen-Varianten (Schleim, Stapel, Golem, Geist, Wolf, Bandit),
## letzte Zeile Spinne mit den sechs Element-Schichten; --fern = Ortho-Zoom 16.
## posen: Sonderposen der Fähigkeiten (STIL-3D.md 7k) — je Figur ihre Pose,
## alle bei Sekunde --pose=x:<s> (Standard 0.6, Haltephase); --ruhe = alle in
## Ruhe (Vergleich), --gruppe=0|1 = erste bzw. zweite Hälfte näher.
## kronen: ALLE Gegner-Archetypen als Kampf-Boss (Krone, Siegel) im Raster, Blick
## wie die Kampfkamera (3/4-Drehung je Seite wie auf der Bühne); --seite = Blick
## von rechts (sitzt die Krone vor dem Gesicht?), --nur=<id>, --blick wie oben,
## --oben = Dungeon-Blick (Ortho, Schrägsicht), --gruppe=0..6 = nur fünf Figuren in einer Reihe (näher), --pose=idle:<s>
## friert das Idle aller Figuren bei Sekunde s ein.
## geruest: Figuren-Gerüst (STIL-3D.md 7g) — Gliederpuppe (Troll) mit Rängen,
## Gold und Boss-Schmuck neben Grundkörper-Figuren mit Boss-Krone, Großkrone,
## Strahlend und Kartenhüter. --fern = Ortho-Blick wie Dungeon-Zoom 16,
## --pose = Gliederpuppen fest in einer Angriffs-/Treffer-Pose (Sekunden).


## Verdeckende Wände werden zu Glas (Screen-Door-Deckkraft wie im Dungeon),
## der Sockel bleibt immer fest.
const DECKKRAFT_GLAS := 0.3
const GLAS_TEMPO := 3.0  ## Überblenden pro Sekunde

var _figuren: Array[Node3D] = []
var _fackeln: Array[Node3D] = []
var _waende: Array[Dictionary] = []
var _koerper_mm: MultiMesh
var _deckel_mm: MultiMesh
var _held: Node3D
var _zeit := 0.0
var _pose_art := ""
var _pose_t := -1.0


func _ready() -> void:
	var modus := "dungeon"
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.substr(7)
		elif arg.begins_with("--modus="):
			modus = arg.substr(8)
		elif arg.begins_with("--pose="):
			var teile := arg.substr(7).split(":")
			_pose_art = teile[0]
			_pose_t = float(teile[1]) if teile.size() > 1 else 0.2
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_umgebung()
	if modus == "kampf":
		_kampf_bauen()
	elif modus == "geruest":
		_geruest_bauen("--fern" in OS.get_cmdline_user_args())
	elif modus == "figuren":
		_figuren_bauen("--fern" in OS.get_cmdline_user_args())
	elif modus == "vierbeiner":
		_vierbeiner_bauen("--fern" in OS.get_cmdline_user_args())
	elif modus == "kreaturen":
		_vierbeiner_bauen("--fern" in OS.get_cmdline_user_args(), KreaturenBau.ARTEN)
	elif modus == "varianten":
		_varianten_bauen("--fern" in OS.get_cmdline_user_args())
	elif modus == "kronen":
		_kronen_bauen()
	elif modus == "akzente":
		_akzente_bauen("--fern" in OS.get_cmdline_user_args())
	elif modus == "posen":
		_posen_bauen()
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
		FigurenBau.boden_halten(fig, fig.position.y)
		var quetsch := float(fig.get_meta("quetschen", 0.0))
		if quetsch > 0.0:
			var s := sin(_zeit * 3.0 + phase) * quetsch
			fig.scale = Vector3(1.0 - s * 0.5, 1.0 + s, 1.0 - s * 0.5)
		if fig.has_meta("glieder"):
			var wurzel: Vector3
			if quetsch <= 0.0:
				fig.scale = Vector3.ONE
			if fig.has_meta("showcase_pose"):  # Modus posen: je Figur ihre Sonderpose
				wurzel = Gliederpuppe.beleben(fig, -1.0, -1.0, -1.0, false, -1.0, _pose_t,
					String(fig.get_meta("showcase_pose")))
			elif _pose_art == "angriff":
				wurzel = Gliederpuppe.beleben(fig, -1.0, _pose_t)
			elif _pose_art == "treffer":
				wurzel = Gliederpuppe.beleben(fig, -1.0, -1.0, _pose_t)
			elif _pose_art == "phase":
				wurzel = Gliederpuppe.beleben(fig, -1.0, -1.0, -1.0, false, _pose_t)
			elif _pose_art == "idle":  # Idle fest bei Sekunde _pose_t (alle Figuren gleich)
				wurzel = Gliederpuppe.beleben(fig, _pose_t)
			elif _pose_art in ["heulen", "panzer", "stachel", "segen", "woge", "ruf"]:
				# Sonderpose einer Fähigkeit (Figuren ohne diese Pose: Ruhe)
				wurzel = Gliederpuppe.beleben(fig, -1.0, -1.0, -1.0, false, -1.0, _pose_t, _pose_art)
			else:
				wurzel = Gliederpuppe.beleben(fig, _zeit + phase)
			Gliederpuppe.hub_anwenden(fig)  # Sprung/Stretch wie auf der Kampfbühne
			fig.rotation.x = wurzel.x
			fig.rotation.z = wurzel.z
	for i in _fackeln.size():
		var licht: OmniLight3D = _fackeln[i].get_meta("licht")
		licht.light_energy = 0.7 * Stil3D.PUNKTLICHT_AUSGLEICH \
			* (0.88 + 0.12 * sin(_zeit * 13.0 + i) * sin(_zeit * 7.3 + i * 2.0))
	_waende_aktualisieren(delta)


func _umgebung() -> void:
	var welt := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Stil3D.farbe("nacht").srgb_to_linear()  # BG-Farbe erwartet linear
	Stil3D.umgebung(env, Color(0.46, 0.42, 0.68), 0.42)
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
	Stil3D.teil(self, Stil3D.box(11.0, 0.5, 11.0), Stil3D.farbe("fuge"), Vector3(-1.0, -0.27, -1.0), Vector3.ZERO, false)
	for gx in range(-5, 4):
		for gz in range(-5, 4):
			if Vector2i(gx, gz) == treppe:
				continue
			var hell := 0.96 + rng.randf() * 0.08
			var grund: Color = Stil3D.farbe("stein") * (1.0 if (gx + gz) % 2 == 0 else 0.93)
			Stil3D.teil(self, Stil3D.box(0.94, 0.16, 0.94), grund * hell, Vector3(gx, -0.08, gz), Vector3.ZERO, false)
	# Rundum Wände; die vor dem Helden werden zu Glas (siehe _waende_aktualisieren)
	for i in range(-6, 5):
		_wandblock(Vector3(i, 0, -6), rng)
		_wandblock(Vector3(i, 0, 4), rng)
	for i in range(-5, 4):
		_wandblock(Vector3(-6, 0, i), rng)
		_wandblock(Vector3(4, 0, i), rng)
	# Trennwand mit Durchgang (Gang-Situation)
	for x in [1, 2, 3]:
		_wandblock(Vector3(x, 0, 0), rng)
	_waende_bauen()
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
	_held = _figur(FigurenBau.held(), Vector3(-1.0, 0, 1.8), 45)
	_waende_aktualisieren(0.0, true)
	# Kamera: orthografisch, 45° Diorama-Blick
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 8.8
	add_child(cam)
	cam.position = Vector3(11, 12.5, 11)
	cam.look_at(Vector3(-0.9, 0.1, -1.0))


## Wandblock = fester Sockel (zeigt IMMER, wo die Wand steht) + Körper und
## Deckel, die per Screen-Door durchsichtig werden, wenn sie den Helden
## verdecken. Gebaut wird gesammelt in _waende_bauen (MultiMesh wie im Dungeon).
func _wandblock(pos: Vector3, rng: RandomNumberGenerator) -> void:
	_waende.append({"pos": pos, "alpha": 1.0, "h": 1.2 + (0.12 if rng.randf() < 0.2 else 0.0),
		"hell": 0.94 + rng.randf() * 0.08})


func _waende_bauen() -> void:
	var stil := BiomStil.fuer(Enums.Biome.FOREST)
	var werte := {"moos_farbe": stil["moos"], "moos": stil["moos_wand"], "stein": stil["stein"],
		"fuge_farbe": stil["fuge"], "held_pos": Vector3(-1.0, 0, 1.8)}
	var deckel_werte := werte.duplicate()
	deckel_werte["halb"] = Vector3(0.5, 0.06, 0.5)
	var sockel := _mm(Stil3D.box(1.0, 0.3, 1.0), WeltMaterial.material("wand", werte, 1))
	_koerper_mm = _mm(Stil3D.box(1.0, 1.0, 1.0), WeltMaterial.material("wand", werte, 1))
	_deckel_mm = _mm(WeltMaterial.fasen_box(Vector3(1.0, 0.12, 1.0), 0.035),
		WeltMaterial.material("wand", deckel_werte))
	for i in _waende.size():
		var w := _waende[i]
		var pos: Vector3 = w["pos"]
		var h: float = w["h"]
		var farbe: Color = stil["wand"] * float(w["hell"])
		sockel.set_instance_transform(i, Transform3D(Basis(), pos + Vector3(0, -0.01, 0)))
		sockel.set_instance_color(i, farbe * 0.8)
		sockel.set_instance_custom_data(i, Color(0, 0, 0, 1))
		_koerper_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(1, h, 1)),
			pos + Vector3(0, 0.14 + h * 0.5, 0)))
		_koerper_mm.set_instance_color(i, farbe)
		_deckel_mm.set_instance_transform(i, Transform3D(Basis(), pos + Vector3(0, 0.2 + h, 0)))
		_deckel_mm.set_instance_color(i, stil["deckel"])
		w["i"] = i


func _mm(mesh: Mesh, mat: Material) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = _waende.size()
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mm


## Wände, die im 45°-Blick VOR dem Helden liegen (größere x+z-Diagonale) und
## seitlich in seiner Nähe, werden durchsichtig; alle anderen bleiben fest.
func _waende_aktualisieren(delta: float, sofort := false) -> void:
	if _held == null or _koerper_mm == null:
		return
	var held_diag := _held.position.x + _held.position.z
	var held_quer := _held.position.x - _held.position.z
	for w in _waende:
		var p: Vector3 = w["pos"]
		var vor := (p.x + p.z) - held_diag
		var quer := absf((p.x - p.z) - held_quer)
		var ziel := DECKKRAFT_GLAS if vor > -0.5 and vor < 8.0 and quer < 5.0 else 1.0
		var alt: float = w["alpha"]
		var neu := ziel if sofort else move_toward(alt, ziel, delta * GLAS_TEMPO)
		if neu == alt and not sofort:
			continue
		w["alpha"] = neu
		var deck := Color(0, 0, 0, neu)
		_koerper_mm.set_instance_custom_data(w["i"], deck)
		_deckel_mm.set_instance_custom_data(w["i"], deck)


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


# --- Ansicht 3: Figuren-Gerüst (Gliederpuppe, Rang- und Boss-Schmuck) -----------

func _geruest_bauen(fern: bool) -> void:
	_sonne(Vector3(-50, 35, 0))
	Stil3D.teil(self, Stil3D.box(16, 0.1, 8), Stil3D.farbe("stein_dunkel"), Vector3(0, -0.05, 0.4),
		Vector3.ZERO, false)
	var lila := Stil3D.farbe("lila")
	var hinten: Array[Node3D] = [
		FigurenBau.fuer_archetyp(&"troll"),
		FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"troll", {"akzent": lila}), "elite", false),
		FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"troll"), "champion", false),
		FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"troll"), "", true),
		FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"troll",
			{"boss": true, "massstab": FigurenBau.KAMPF_BOSS_MASSSTAB}), "", false, "", true),
	]
	var vorn: Array[Node3D] = [
		FigurenBau.fuer_archetyp(&"baer"),
		FigurenBau.fuer_archetyp(&"baer", {"boss": true, "massstab": 1.5}),
		FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"koenigschleim",
			{"boss": true, "massstab": FigurenBau.KAMPF_BOSS_MASSSTAB}), "", false, "", true),
		FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"wolf"), "", false, "strahlend"),
		FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"golem"), "", false, "karte"),
		FigurenBau.schmuecken(FigurenBau.fuer_archetyp(&"fledermaus"), "champion", false),
	]
	for i in hinten.size():
		_figur(hinten[i], Vector3(-5.6 + i * 2.8, 0, -1.4), 15)
	for i in vorn.size():
		var f := vorn[i]
		_figur(f, Vector3(-6.0 + i * 2.4, float(f.get_meta("schwebt", 0.0)), 1.9), 20)
	var cam := Camera3D.new()
	add_child(cam)
	if fern:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 16.0 * 1.1
		cam.look_at_from_position(Vector3(11, 12.5, 11), Vector3(0, 0.3, 0.3))
	elif "--nah" in OS.get_cmdline_user_args():
		# Nahaufnahme der ersten Gliederpuppen (Gesicht, Hand, Waffe).
		cam.fov = 22.0
		cam.look_at_from_position(Vector3(-3.6, 2.4, 4.6), Vector3(-4.2, 0.75, -1.4))
	else:
		cam.fov = 38.0
		cam.look_at_from_position(Vector3(0, 5.4, 12.0), Vector3(0, 0.7, 0.2))


# --- Ansicht 4: Figuren 2.0 — Zweibeiner und Helden ------------------------------

func _figuren_bauen(fern: bool) -> void:
	_sonne(Vector3(-50, 35, 0))
	Stil3D.teil(self, Stil3D.box(30, 0.1, 12), Stil3D.farbe("stein_dunkel"), Vector3(0, -0.05, 0), Vector3.ZERO, false)
	var boss := "--boss" in OS.get_cmdline_user_args()
	var gegner := [&"troll", &"bandit", &"kultist", &"nekromant", &"skelett", &"toddiener",
		&"schattenkrieger", &"todesmeister", &"kleindaemon", &"demonenbeschwoerer", &"demonenkonig",
		&"pilzhexe", &"hexenmeisterin"]
	for i in gegner.size():
		var f := FigurenBau.fuer_archetyp(gegner[i], {"boss": boss, "massstab": FigurenBau.KAMPF_BOSS_MASSSTAB if boss else 1.0})
		var reihe := 0 if i < 7 else 1
		var spalte := i if i < 7 else i - 7
		_figur(f, Vector3(-6.0 + spalte * 2.0, float(f.get_meta("schwebt", 0.0)), -2.2 + reihe * 2.4), 15)
	var helden: Array[Node3D] = [
		FigurenBau.held_mit(Stil3D.farbe("ruestung")),
		FigurenBau.starter_held(SpriteLib.HERO_PORTRAITS[1], &"dolche"),
		FigurenBau.starter_held(SpriteLib.HERO_PORTRAITS[2], &"bogen"),
		FigurenBau.starter_held(SpriteLib.HERO_PORTRAITS[3], &"feuerstab"),
		FigurenBau.starter_held(SpriteLib.HERO_PORTRAITS[4], &"heiligstab"),
		FigurenBau.held_mit(Stil3D.farbe("silber"), {"bekannt": true, "waffe": "axt", "neben": "schild",
			"ruestung": Enums.ArmorClass.CHAIN}),
	]
	if "--ruestung" in OS.get_cmdline_user_args():
		# Rollen mit Rüstung: Schurke (Dolche/Bogen), Magier, Heiler, Großhammer, Turmschild.
		helden = [
			FigurenBau.held_mit(Stil3D.farbe("umhang"), {"bekannt": true, "waffe": "dolch", "neben": "dolch",
				"ruestung": Enums.ArmorClass.LEATHER}),
			FigurenBau.held_mit(Stil3D.farbe("moos"), {"bekannt": true, "waffe": "bogen", "neben": "koecher",
				"ruestung": Enums.ArmorClass.LEATHER}),
			FigurenBau.held_mit(Stil3D.farbe("lila"), {"bekannt": true, "waffe": "offensivstab", "neben": "zauberbuch",
				"element": "gift", "ruestung": Enums.ArmorClass.NONE}),
			FigurenBau.held_mit(Stil3D.farbe("gold"), {"bekannt": true, "waffe": "heiligstab", "neben": "heiligkreuz"}),
			FigurenBau.held_mit(Stil3D.farbe("obsidian"), {"bekannt": true, "waffe": "kriegshammer",
				"ruestung": Enums.ArmorClass.PLATE}),
			FigurenBau.held_mit(Stil3D.farbe("drachenblut"), {"bekannt": true, "waffe": "turmschild",
				"ruestung": Enums.ArmorClass.PLATE}),
		]
	for j in helden.size():
		_figur(helden[j], Vector3(-5.0 + j * 2.0, 0, 2.8), 20)
	var cam := Camera3D.new()
	add_child(cam)
	var blick := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--blick="):
			blick = arg.substr(8)
	if blick != "":
		var w := blick.split_floats(",")
		cam.fov = w[3] if w.size() > 3 else 20.0
		var ziel := Vector3(w[0], w[1], w[2])
		cam.look_at_from_position(ziel + Vector3(0.6, 1.4, 4.2) * cam.fov / 20.0, ziel)
	elif fern:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 16.0 * 1.1
		cam.look_at_from_position(Vector3(11, 12.5, 11), Vector3(0, 0.3, 0.4))
	else:
		cam.fov = 38.0
		cam.look_at_from_position(Vector3(0, 6.2, 12.5), Vector3(0, 0.6, 0.3))


# --- Ansicht 5: Figuren 2.0 — Vierbeiner und Schleime ----------------------------

## Aufstellung wie der Entwurf (fünf Spalten, drei Reihen, 3/4-Ansicht wie im
## Kampf: Vierbeiner 38°, Igel 30°, Schleime 20° zur Bildmitte).
func _vierbeiner_bauen(fern: bool, arten: Array = []) -> void:
	_sonne(Vector3(-40, -25, 0))
	Stil3D.teil(self, Stil3D.box(14.0, 0.1, 9.0), Stil3D.farbe("stein") * 0.8, Vector3(0, -0.05, -1.5), Vector3.ZERO,
		false)
	var args := OS.get_cmdline_user_args()
	var boss := "--boss" in args
	var opt := {"boss": boss, "massstab": FigurenBau.KAMPF_BOSS_MASSSTAB} if boss else {}
	if "--elite" in args:
		opt = {"akzent": Stil3D.farbe("lila")}
	var ids := [&"wolf", &"baer", &"schattenbestie", &"leichenfresser", &"demonenjager", &"verfluchtkatz",
		&"verfluchtdachs", &"verfluchtbock", &"verfluchtigel", &"schleim", &"schleimstapel", &"koenigschleim",
		&"schleimgott"]
	if not arten.is_empty():
		ids = arten.duplicate()
	for arg in args:
		if arg.begins_with("--nur="):  # eine Figur allein in der Mitte (Nahaufnahme)
			ids = [StringName(arg.substr(6))]
	for i in ids.size():
		var f := FigurenBau.fuer_archetyp(ids[i], opt)
		if boss:
			f = FigurenBau.schmuecken(f, "", false, "", true)
		elif "--elite" in args:
			f = FigurenBau.schmuecken(f, "elite", false)
		var pos := Vector3((i % 5 - 2) * 2.3, float(f.get_meta("schwebt", 0.0)), -(i / 5) * 2.4 + 0.6)
		if ids.size() == 1:
			pos.x = -0.01
		var seite := -1.0 if pos.x > 0.0 else 1.0
		var schleim := String(ids[i]).contains("schleim")
		_figur(f, pos, (20.0 if schleim else float(f.get_meta("drehung", 0.0))) * seite)
		if "--ohne-namen" in args:
			continue
		var l := Label3D.new()
		l.text = String(ids[i])
		l.font_size = 36
		l.outline_size = 10
		l.no_depth_test = true
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(pos.x, 0.1, pos.z + 0.85)
		add_child(l)
	var cam := Camera3D.new()
	add_child(cam)
	var blick := ""
	for arg in args:
		if arg.begins_with("--blick="):
			blick = arg.substr(8)
	if blick != "":
		var w := blick.split_floats(",")
		cam.fov = w[3] if w.size() > 3 else 20.0
		var ziel := Vector3(w[0], w[1], w[2])
		cam.look_at_from_position(ziel + Vector3(0.0, 1.6, 4.2) * cam.fov / 20.0, ziel)
	elif fern:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 16.0 * 1.1
		cam.look_at_from_position(Vector3(11, 12.5, 11), Vector3(0, 0.3, -1.0))
	else:
		cam.fov = 38.0
		cam.look_at_from_position(Vector3(0, 6.2, 9.6), Vector3(0, 0.5, -1.6))


# --- Ansicht 6: Rang-, Sonder- und Boss-Schmuck aller Gruppen --------------------

const VARIANTEN := ["normal", "elite", "champion", "gulden", "strahlend", "karte", "boss"]


func _varianten_bauen(fern: bool) -> void:
	_sonne(Vector3(-50, 35, 0))
	var args := OS.get_cmdline_user_args()
	var ids: Array = ["bandit", "wolf", "koenigschleim", "spinne", "golem", "geist"]
	for arg in args:
		if arg.begins_with("--ids="):
			ids = Array(arg.substr(6).split(","))
	var breite := VARIANTEN.size() * 2.0
	Stil3D.teil(self, Stil3D.box(breite + 2.0, 0.1, ids.size() * 2.2 + 2.0), Stil3D.farbe("stein_dunkel"),
		Vector3(0, -0.05, 0), Vector3.ZERO, false)
	for zeile in ids.size():
		var id := StringName(ids[zeile])
		for spalte in VARIANTEN.size():
			var v: String = VARIANTEN[spalte]
			var opt := {}
			if v == "elite":
				opt = {"akzent": Stil3D.farbe("lila")}
			elif v == "boss":
				opt = {"boss": true, "massstab": FigurenBau.KAMPF_BOSS_MASSSTAB}
			var f := FigurenBau.fuer_archetyp(id, opt)
			f = FigurenBau.schmuecken(f, v if v in ["elite", "champion"] else "", v == "gulden",
				v if v in ["strahlend", "karte"] else "", v == "boss")
			var pos := Vector3(-breite * 0.5 + 1.0 + spalte * 2.0, float(f.get_meta("schwebt", 0.0)),
				-ids.size() * 1.1 + 1.1 + zeile * 2.2)
			_figur(f, pos, float(f.get_meta("drehung", 0.0)) * 0.5)
	var cam := Camera3D.new()
	add_child(cam)
	if fern:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 16.0 * 1.1
		cam.look_at_from_position(Vector3(11, 12.5, 11), Vector3(0, 0.3, 0))
	else:
		cam.fov = 40.0
		cam.look_at_from_position(Vector3(0, 9.5, 13.5 + ids.size() * 0.6), Vector3(0, 0.4, 0.4))


# --- Ansicht 8: Varianten- und Element-Akzente ------------------------------------

const AKZENT_ZEILEN := [
	[&"schleim", ["", "metall", "gift", "heil"]],
	[&"schleimstapel", ["", "metall", "gift", "heil"]],
	[&"golem", ["", "rost", "kristall", "obsidian"]],
	[&"geist", ["", "zorn", "frost", "polter"]],
	[&"wolf", ["", "alpha", "gift", "blut", "ur"]],
	[&"bandit", ["", "krieger", "bogenschütze", "magier", "beschwörer"]],
]


func _akzente_bauen(fern: bool) -> void:
	_sonne(Vector3(-50, 35, 0))
	var zeilen := AKZENT_ZEILEN.duplicate()
	var elemente: Array = [&"spinne", []]
	for element in [Enums.Element.NONE, Enums.Element.FIRE, Enums.Element.ICE, Enums.Element.LIGHTNING,
			Enums.Element.POISON, Enums.Element.HOLY, Enums.Element.DARK]:
		elemente[1].append(element)
	zeilen.append(elemente)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--zeile="):  # nur eine Zeile, näher (Nahblick)
			zeilen = [zeilen[int(arg.substr(8))]]
	var spalten := 7
	Stil3D.teil(self, Stil3D.box(spalten * 2.0 + 2.0, 0.1, zeilen.size() * 2.2 + 2.0), Stil3D.farbe("stein_dunkel"),
		Vector3(0, -0.05, 0), Vector3.ZERO, false)
	for zeile in zeilen.size():
		var id: StringName = zeilen[zeile][0]
		var liste: Array = zeilen[zeile][1]
		for spalte in liste.size():
			var opt := {"element": liste[spalte]} if liste[spalte] is int else {"variante": liste[spalte]}
			var f := FigurenBau.fuer_archetyp(id, opt)
			var pos := Vector3(-spalten + 1.0 + spalte * 2.0, float(f.get_meta("schwebt", 0.0)),
				-zeilen.size() * 1.1 + 1.1 + zeile * 2.2)
			_figur(f, pos, float(f.get_meta("drehung", 0.0)) * 0.5)
	var cam := Camera3D.new()
	add_child(cam)
	if fern:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 16.0 * 1.1
		cam.look_at_from_position(Vector3(11, 12.5, 11), Vector3(0, 0.3, 0))
	elif zeilen.size() == 1:
		cam.fov = 30.0
		var breite := float((zeilen[0][1] as Array).size())
		cam.look_at_from_position(Vector3(-spalten + breite, 1.8 + breite * 0.4, 4.5 + breite * 1.2),
			Vector3(-spalten + breite, 0.6, 0.0))
	else:
		cam.fov = 40.0
		cam.look_at_from_position(Vector3(0, 9.5, 13.5 + zeilen.size() * 0.6), Vector3(0, 0.4, 0.4))


# --- Ansicht 9: Sonderposen der Fähigkeiten ---------------------------------------

const POSEN_FIGUREN := [
	[&"baer", "heulen"], [&"geist", "heulen"], [&"verfluchtigel", "stachel"], [&"verfluchtdachs", "panzer"],
	[&"golem", "panzer"], [&"koenigschleim", "segen"], [&"koenigschleim", "woge"], [&"schleimstapel", "woge"],
	[&"schleim", "segen"], [&"schattenkrieger", "panzer"], [&"kultist", "segen"], [&"nekromant", "ruf"],
	[&"pilzhexe", "woge"], [&"pilzstamm", "segen"], [&"pilzkrabbel", "woge"], [&"schleimgott", "segen"],
]


func _posen_bauen() -> void:
	_sonne(Vector3(-50, 35, 0))
	var args := OS.get_cmdline_user_args()
	if _pose_t < 0.0:
		_pose_t = 0.6
	var liste := POSEN_FIGUREN.duplicate()
	for arg in args:
		if arg.begins_with("--gruppe="):
			var g := int(arg.substr(9))
			liste = liste.slice(g * 8, g * 8 + 8)
	var spalten := 4
	var zeilen := ceili(float(liste.size()) / spalten)
	Stil3D.teil(self, Stil3D.box(spalten * 2.6 + 2.0, 0.1, zeilen * 2.6 + 2.0), Stil3D.farbe("stein_dunkel"),
		Vector3(0, -0.05, 0), Vector3.ZERO, false)
	for i in liste.size():
		var f := FigurenBau.fuer_archetyp(liste[i][0])
		if not "--ruhe" in args:
			f.set_meta("showcase_pose", liste[i][1])
		var pos := Vector3((i % spalten - (spalten - 1) * 0.5) * 2.6, float(f.get_meta("schwebt", 0.0)),
			(i / spalten - (zeilen - 1) * 0.5) * 2.6)
		var seite := -1.0 if pos.x > 0.0 else 1.0
		_figur(f, pos, float(f.get_meta("drehung", 0.0)) * seite)
		var l := Label3D.new()
		l.text = "%s: %s" % [liste[i][0], liste[i][1]]
		l.font_size = 28
		l.outline_size = 10
		l.no_depth_test = true
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(pos.x, 0.05, pos.z + 1.0)
		add_child(l)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 34.0
	cam.look_at_from_position(Vector3(0, 7.0 + zeilen * 1.2, 7.5 + zeilen * 2.2), Vector3(0, 0.6, 0.3))


# --- Ansicht 7: Boss-Kronen aller Gegner ------------------------------------------

func _kronen_bauen() -> void:
	_sonne(Vector3(-50, 35, 0))
	var args := OS.get_cmdline_user_args()
	var ids: Array = [&"troll"]
	ids.append_array(ZweibeinerBau.ARTEN)
	ids.append_array(VierbeinerBau.ARTEN)
	ids.append_array(KreaturenBau.ARTEN)
	var gruppe := -1  # --gruppe=N: nur die N-te Fünfergruppe, in einer Reihe (Nahblick)
	for arg in args:
		if arg.begins_with("--nur="):
			ids = [StringName(arg.substr(6))]
		elif arg.begins_with("--gruppe="):
			gruppe = int(arg.substr(9))
	if gruppe >= 0:
		ids = ids.slice(gruppe * 5, gruppe * 5 + 5)
	var spalten := 5 if gruppe >= 0 else 7
	var abstand := Vector2(2.25, 2.9) if gruppe >= 0 else Vector2(2.6, 2.9)
	var zeilen := ceili(float(ids.size()) / spalten)
	Stil3D.teil(self, Stil3D.box(spalten * abstand.x + 4.0, 0.1, spalten * abstand.x + 4.0),
		Stil3D.farbe("stein_dunkel"), Vector3(0, -0.05, 0), Vector3.ZERO, false)
	var seite_blick := "--seite" in args
	for i in ids.size():
		var f := FigurenBau.fuer_archetyp(ids[i], {"boss": true, "massstab": FigurenBau.KAMPF_BOSS_MASSSTAB})
		f = FigurenBau.schmuecken(f, "", false, "", true)
		var spalte := i % spalten
		var zeile := i / spalten
		var pos := Vector3((spalte - (spalten - 1) * 0.5) * abstand.x, float(f.get_meta("schwebt", 0.0)),
			(zeile - (zeilen - 1) * 0.5) * abstand.y)
		if ids.size() == 1:
			pos = Vector3(0, pos.y, 0)
		elif seite_blick:  # Reihe in die Tiefe, Blick von rechts auf die Profile
			pos = Vector3(-pos.z, pos.y, pos.x)
		# Wie auf der Kampfbühne: zur Kamera, Vierbeiner & Co. in 3/4-Drehung.
		var seite := -1.0 if pos.x > 0.0 else 1.0
		var blick := 0.0 if seite_blick else float(f.get_meta("drehung", 0.0)) * seite
		_figur(f, pos, blick)
		if "--ohne-namen" in args:
			continue
		var l := Label3D.new()
		l.text = String(ids[i])
		l.font_size = 30
		l.outline_size = 10
		l.no_depth_test = true
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(pos.x, 0.05, pos.z + 0.9)
		add_child(l)
	var cam := Camera3D.new()
	add_child(cam)
	var blick_arg := ""
	for arg in args:
		if arg.begins_with("--blick="):
			blick_arg = arg.substr(8)
	if blick_arg != "":
		var w := blick_arg.split_floats(",")
		cam.fov = w[3] if w.size() > 3 else 20.0
		var ziel := Vector3(w[0], w[1], w[2])
		var weg := Vector3(4.2, 1.6, 0.0) if seite_blick else Vector3(0.0, 2.4, 4.2)
		cam.look_at_from_position(ziel + weg * cam.fov / 20.0, ziel)
	elif "--oben" in args:  # Dungeon-Blick (Ortho, Schrägsicht wie Zoom 16), nah
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 3.2 if ids.size() == 1 else 13.0
		cam.look_at_from_position(Vector3(11, 12.5, 11), Vector3(0, 0.6, 0))
	elif gruppe >= 0:
		cam.fov = 30.0
		var weg5 := Vector3(10.5, 3.4, 0.0) if seite_blick else Vector3(0.0, 5.2, 9.0)
		cam.look_at_from_position(Vector3(0, 0.8, 0) + weg5, Vector3(0, 0.8, 0))
	elif ids.size() == 1:
		cam.fov = 26.0
		var weg1 := Vector3(5.5, 2.6, 0.0) if seite_blick else Vector3(0.0, 3.2, 5.5)
		cam.look_at_from_position(Vector3(0, 0.9, 0) + weg1, Vector3(0, 0.9, 0))
	else:
		# Neigung wie die Kampfkamera (KampfBuehne3D: ~30° von oben).
		cam.fov = 40.0
		cam.look_at_from_position(Vector3(0, 13.0, 19.5), Vector3(0, 0.5, 0.6))


# --- Screenshot ---------------------------------------------------------------

func _foto(pfad: String) -> void:
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(pfad)
	get_tree().quit()
