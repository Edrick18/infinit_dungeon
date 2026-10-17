class_name KampfBuehne3D
extends Node3D
## 3D-Arena hinter der Kampf-Oberfläche (STIL-3D.md, Abschnitt 7c).
## Die UI bleibt Herr über Layout, Klicks und Tooltips: Jeder Gegner hat im
## Panel einen unsichtbaren Platzhalter. Seine 3D-Figur stellt sich jedes
## Bild genau darauf — Strahl durch den Fußpunkt des Platzhalters auf den
## Arena-Boden, Höhe = Platzhalterhöhe — und übernimmt dessen Animationen:
## scale-Puls » Ausfallschritt Richtung Kamera, rotation » Taumeln.

## Biom-Deko am Arenarand (links/rechts, außerhalb der Gegnerreihe).
const DEKO_STELLEN := [Vector3(-6.6, 0, -4.2), Vector3(7.0, 0, -3.6), Vector3(-8.0, 0, -0.8),
	Vector3(8.2, 0, -1.2), Vector3(-5.6, 0, -7.4), Vector3(5.8, 0, -7.2)]
const FOV := 38.0
## Steil genug, dass die Gegner-Panels (oberes Bilddrittel) den Boden VOR
## den Säulen treffen — sonst stehen die Figuren dahinter.
const KAMERA_POS := Vector3(0.0, 6.0, 8.5)
const KAMERA_ZIEL := Vector3(0.0, 0.2, -1.5)

const BLITZ_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, shadows_disabled;
uniform vec4 farbe : source_color = vec4(1.0, 0.3, 0.3, 0.0);
void fragment() {
	ALBEDO = farbe.rgb * farbe.a;
	ALPHA = farbe.a;
}
"""

static var _blitz_shader: Shader

var _kamera: Camera3D
## Schlüssel » {"ph": Control, "fig": Node3D, "basis": Vector3, "lebt": Callable,
##             "tot": float, "phase": float}
var _eintraege: Dictionary = {}
var _fackeln: Array[Node3D] = []
var _zeit := 0.0
## Optional: Figuren ragen nie über die Unterkante dieses Controls (Zugleiste).
var deckel: Control
## Kampf-Effekte (Elemente, Treffer, Projektile) — siehe KampfEffekte.
var effekte: KampfEffekte
var _stoss := 0.0


func aufbauen(boden_tint := Color.WHITE, wand_tint := Color.WHITE, deko: Array = []) -> void:
	var welt := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Stil3D.farbe("nacht").srgb_to_linear()  # BG-Farbe erwartet linear
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.42, 0.68)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 0.85
	welt.environment = env
	add_child(welt)
	var sonne := DirectionalLight3D.new()
	sonne.rotation_degrees = Vector3(-42, -28, 0)
	sonne.light_color = Color(1.0, 0.95, 0.86)
	sonne.light_energy = 0.8
	sonne.shadow_enabled = true
	sonne.directional_shadow_max_distance = 30.0
	add_child(sonne)
	get_viewport().msaa_3d = Viewport.MSAA_4X

	# Arena: dunkle Grundscheibe, darauf ein Kampfkreis aus Steinplatten in
	# Ringen (die Fugen zeichnen das Muster), Säulenreihe mit Fackeln.
	Stil3D.teil(self, Stil3D.zylinder(15.0, 15.0, 0.3), Stil3D.farbe("stein_dunkel") * boden_tint * 0.6,
		Vector3(0, -0.15, -2.0), Vector3.ZERO, false)
	Stil3D.teil(self, Stil3D.zylinder(7.25, 7.25, 0.05), Stil3D.farbe("fuge"), Vector3(0, -0.01, -2.6),
		Vector3.ZERO, false)
	_plattenkreis(Vector3(0, 0, -2.6), 7, boden_tint)
	for i in DEKO_STELLEN.size() if not deko.is_empty() else 0:
		var stelle: Vector3 = DEKO_STELLEN[i]
		var stueck := FigurenBau.deko(deko[i % deko.size()])
		add_child(stueck)
		stueck.position = stelle
		stueck.rotation.y = float(i) * 1.7
	for x in [-9.0, -4.5, 0.0, 4.5, 9.0]:
		Stil3D.teil(self, Stil3D.zylinder(0.42, 0.48, 4.4), Stil3D.farbe("stein_dunkel") * wand_tint,
			Vector3(x, 2.2, -9.0))
		Stil3D.teil(self, Stil3D.box(1.1, 0.28, 1.1), Stil3D.farbe("stein") * wand_tint, Vector3(x, 4.45, -9.0))
	for x in [-6.75, -2.25, 2.25, 6.75]:
		var f := FigurenBau.fackel()
		add_child(f)
		f.position = Vector3(x, 2.0, -8.7)
		(f.get_meta("licht") as OmniLight3D).omni_range = 4.0
		_fackeln.append(f)

	_kamera = Camera3D.new()
	_kamera.fov = FOV
	add_child(_kamera)
	_kamera.look_at_from_position(KAMERA_POS, KAMERA_ZIEL)
	_kamera.make_current()
	effekte = KampfEffekte.new()
	effekte.kamera = _kamera
	effekte.buehne = self
	add_child(effekte)


## Kampfkreis aus Steinplatten: Ringe um die Mitte, jede Platte leicht
## anders hell, der äußerste Ring als heller Randstein.
func _plattenkreis(mitte: Vector3, ringe: int, tint: Color) -> void:
	var lagen: Array[Transform3D] = []
	var farben: Array[Color] = []
	for ring in ringe + 1:
		var anzahl := 1 if ring == 0 else roundi(TAU * ring)
		for i in anzahl:
			var winkel := TAU * i / anzahl + ring * 0.41
			var pos := mitte + Vector3(cos(winkel), 0, sin(winkel)) * ring * 0.98
			var rand := ring == ringe
			pos.y = 0.05 if rand else 0.03
			lagen.append(Transform3D(Basis(Vector3.UP, -winkel), pos))
			var hell := 0.8 + float(absi(hash(Vector2i(ring, i))) % 9) * 0.022
			var grund := Stil3D.farbe("stein_hell") if rand else Stil3D.farbe("stein") * (0.94 if ring % 2 else 1.0)
			farben.append(grund * tint * hell)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Stil3D.box(0.86, 0.12, 0.86)
	mm.instance_count = lagen.size()
	for i in lagen.size():
		mm.set_instance_transform(i, lagen[i])
		mm.set_instance_color(i, farben[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Stil3D.material(Color.WHITE)
	add_child(mmi)


## Figur an einen UI-Platzhalter binden. lebt() entscheidet über Verpuffen.
func anmelden(schluessel: Variant, platzhalter: Control, figur: Node3D, lebt: Callable) -> void:
	abmelden(schluessel)
	add_child(figur)
	var hoehe := maxf(0.3, PortraitStudio._umriss(figur).end.y)  # bei Skala 1
	figur.visible = false  # erst zeigen, wenn der Platzhalter Layout hat
	_eintraege[schluessel] = {"ph": platzhalter, "fig": figur, "hoehe": hoehe,
		"basis": figur.scale, "lebt": lebt, "tot": 0.0, "rueck": 0.0, "status": {},
		"phase": float(absi(hash(str(schluessel))) % 628) / 100.0}


func abmelden(schluessel: Variant) -> void:
	if _eintraege.has(schluessel):
		_eintraege[schluessel]["fig"].queue_free()
		_eintraege.erase(schluessel)


func hat(schluessel: Variant) -> bool:
	return _eintraege.has(schluessel)


## Boss-Auftritt: Beben und zweimaliges Aufglühen des Bosses. (Eine Kamera-
## fahrt passt nicht: die Figuren stehen jedes Bild unter ihren UI-Plätzen,
## nur die Arena würde zoomen.)
func boss_intro(schluessel: Variant) -> void:
	if not _eintraege.has(schluessel):
		return
	stoss(2.2)
	blitz(schluessel, false)
	var tween := create_tween()
	tween.tween_interval(0.55)
	tween.tween_callback(func() -> void:
		stoss(1.4)
		blitz(schluessel, false))


## Körpermitte einer Figur in der Welt (Ziel für Effekte und Projektile).
func figur_mitte(schluessel: Variant) -> Variant:
	if not _eintraege.has(schluessel):
		return null
	var figur: Node3D = _eintraege[schluessel]["fig"]
	if not figur.visible:
		return null
	return figur.global_position + Vector3(0, float(_eintraege[schluessel]["hoehe"]) * figur.scale.y * 0.5, 0)


## Treffer: Figur weicht kurz von der Kamera weg (klingt in ~0.25 s ab).
func rueckstoss(schluessel: Variant, staerke := 1.0) -> void:
	if _eintraege.has(schluessel):
		_eintraege[schluessel]["rueck"] = maxf(float(_eintraege[schluessel]["rueck"]), staerke)


# --- Status-Anzeige an den Figuren ------------------------------------------------
# Solange ein Zustand wirkt, sieht man ihn: Flammen (Brand), Blasen (Gift),
# Tropfen (Blutung), Eispanzer (gefroren), Sterne (betäubt), Blase (Schild/
# Schutzwall), Ringe am Boden (gestärkt, gewappnet, verlangsamt), Zeichen über
# dem Kopf (markiert, verflucht). Teile hängen an der Figur (wachsen mit).

## Setzt die sichtbaren Zustände einer Figur (Liste von Enums.Status).
func status_setzen(schluessel: Variant, ids: Array) -> void:
	if not _eintraege.has(schluessel):
		return
	var e: Dictionary = _eintraege[schluessel]
	var aktiv: Dictionary = e["status"]
	var gewuenscht := {}
	for id in ids:
		gewuenscht[int(id)] = true
	for id in aktiv.keys():
		if not gewuenscht.has(id):
			(aktiv[id] as Node3D).queue_free()
			aktiv.erase(id)
	for id in gewuenscht:
		if not aktiv.has(id):
			# Teile hängen an der Figur: Höhe in IHREN Maßstab umrechnen (große
			# Figuren tragen schon eine Eigen-Skalierung).
			var basis: Vector3 = e["basis"]
			var knoten := _status_knoten(id, float(e["hoehe"]) / maxf(0.01, basis.y))
			if knoten != null:
				(e["fig"] as Node3D).add_child(knoten)
				aktiv[id] = knoten


func _status_knoten(id: int, hoehe: float) -> Node3D:
	var n := Node3D.new()
	n.set_meta("art", id)
	match id:
		Enums.Status.BURN:
			for i in 3:
				var w := TAU * i / 3.0
				var flamme := _vfx_teil(n, Stil3D.kegel(0.09, 0.32), Color("ff8a2a"),
					Vector3(cos(w) * 0.32, 0.16, sin(w) * 0.32))
				flamme.set_meta("flackern", float(i))
		Enums.Status.POISON_DOT:
			n.add_child(_dauer_partikel(Color("8fe04a"), Vector3(0, hoehe * 0.5, 0), Vector3(0, 0.6, 0)))
		Enums.Status.BLEED:
			n.add_child(_dauer_partikel(Color("e0505e"), Vector3(0, hoehe * 0.6, 0), Vector3(0, -2.0, 0)))
		Enums.Status.REGEN:
			n.add_child(_dauer_partikel(Color("7dffa0"), Vector3(0, 0.1, 0), Vector3(0, 0.8, 0)))
		Enums.Status.FROZEN:
			for i in 6:
				var w := TAU * i / 6.0
				var kristall := _vfx_teil(n, Stil3D.prisma(0.16, hoehe * 0.7, 0.16), Color("7fe8ff"),
					Vector3(cos(w) * 0.3, hoehe * 0.3, sin(w) * 0.3))
				kristall.rotation = Vector3(sin(w) * 0.3, w, cos(w) * 0.3)
		Enums.Status.STUN:
			for i in 3:
				var w := TAU * i / 3.0
				_vfx_teil(n, Stil3D.kugel(0.06), Color("ffe45a"),
					Vector3(cos(w) * 0.28, hoehe * 0.9, sin(w) * 0.28))
			n.set_meta("kreisen", true)
		Enums.Status.SHIELD, Enums.Status.PROTECT:
			var blase := _vfx_teil(n, Stil3D.kugel(maxf(0.55, hoehe * 0.6)), Color(0.5, 0.75, 1.0, 0.18),
				Vector3(0, hoehe * 0.5, 0))
			blase.set_meta("pulsieren", true)
		Enums.Status.ATK_UP, Enums.Status.DEF_UP, Enums.Status.SLOW:
			var farbe: Color = {Enums.Status.ATK_UP: Color("ff9a3a"), Enums.Status.DEF_UP: Color("9fb0d0"),
				Enums.Status.SLOW: Color("6f7fd0")}[id]
			var torus := TorusMesh.new()
			torus.inner_radius = 0.42
			torus.outer_radius = 0.48
			var ring := _vfx_teil(n, torus, farbe, Vector3(0, 0.04 + 0.03 * (id % 3), 0))
			ring.set_meta("pulsieren", true)
		Enums.Status.MARKED, Enums.Status.CURSED:
			var zeichen := _vfx_teil(n, Stil3D.prisma(0.18, 0.22, 0.05),
				Color("ff5a5a") if id == Enums.Status.MARKED else Color("a066f0"),
				Vector3(0, hoehe + 0.05, 0))
			zeichen.rotation.x = PI
			zeichen.set_meta("drehen", true)
		_:
			n.free()
			return null
	return n


func _vfx_teil(eltern: Node3D, mesh: Mesh, farbe: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = effekte._material(farbe)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	eltern.add_child(mi)
	return mi


func _dauer_partikel(farbe: Color, pos: Vector3, schwerkraft: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.9
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh
	p.material_override = effekte._material(farbe)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.gravity = schwerkraft
	var kurve := Curve.new()
	kurve.add_point(Vector2(0, 1))
	kurve.add_point(Vector2(1, 0))
	p.scale_amount_curve = kurve
	p.position = pos
	return p


## Status-Teile animieren: Flammen flackern, Sterne kreisen, Blasen pulsieren.
func _status_beleben(e: Dictionary, _skala: float) -> void:
	for knoten: Node3D in e["status"].values():
		if knoten.get_meta("kreisen", false):
			knoten.rotation.y = _zeit * 3.0
		for kind in knoten.get_children():
			if kind is MeshInstance3D:
				if kind.has_meta("flackern"):
					var f := float(kind.get_meta("flackern"))
					kind.scale = Vector3(1.0, 0.8 + 0.35 * absf(sin(_zeit * 9.0 + f * 2.1)), 1.0)
				elif kind.get_meta("pulsieren", false):
					kind.scale = Vector3.ONE * (1.0 + 0.06 * sin(_zeit * 4.0))
				elif kind.get_meta("drehen", false):
					kind.rotation.y = _zeit * 2.0


## Kurzer Kamerastoß (Krits, schwere Treffer).
func stoss(staerke := 1.0) -> void:
	if not Settings.bildschirm_wackeln:
		return
	_stoss = maxf(_stoss, 0.18 * staerke)


## Treffer (rot) oder Heilung (grün) lässt die ganze Figur aufleuchten.
func blitz(schluessel: Variant, heilung: bool) -> void:
	if not _eintraege.has(schluessel):
		return
	if _blitz_shader == null:
		_blitz_shader = Shader.new()
		_blitz_shader.code = BLITZ_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _blitz_shader
	var grund := Color(0.4, 1.0, 0.5) if heilung else Color(1.0, 0.25, 0.2)
	var figur: Node3D = _eintraege[schluessel]["fig"]
	var vorher := {}  # bestehende Overlays (Goldglanz!) merken und zurückgeben
	for mi in figur.find_children("*", "MeshInstance3D", true, false):
		vorher[mi] = (mi as MeshInstance3D).material_overlay
		(mi as MeshInstance3D).material_overlay = mat
	var setzen := func(a: float) -> void:
		mat.set_shader_parameter("farbe", Color(grund.r, grund.g, grund.b, a))
	var aufraeumen := func() -> void:
		for mi in vorher:
			if is_instance_valid(mi):
				(mi as MeshInstance3D).material_overlay = vorher[mi]
	var tween := create_tween()
	tween.tween_method(setzen, 0.9, 0.0, 0.35)
	tween.tween_callback(aufraeumen)


func _process(delta: float) -> void:
	_zeit += delta
	var bild_h := get_viewport().get_visible_rect().size.y
	var halb_fov := tan(deg_to_rad(FOV * 0.5))
	var kamera_pos := _kamera.global_position
	var blick := -_kamera.global_transform.basis.z
	for schluessel in _eintraege.keys():
		var e: Dictionary = _eintraege[schluessel]
		var ph: Control = e["ph"]
		var figur: Node3D = e["fig"]
		if not is_instance_valid(ph):
			abmelden(schluessel)
			continue
		var rect := ph.get_global_rect()
		if rect.size.y < 2.0 or not ph.is_visible_in_tree():
			figur.visible = false
			continue
		# Fußpunkt des Platzhalters » Strahl » Arena-Boden.
		var fuss := Vector2(rect.get_center().x, rect.end.y)
		var o := _kamera.project_ray_origin(fuss)
		var n := _kamera.project_ray_normal(fuss)
		if n.y > -0.001:
			figur.visible = false
			continue
		var boden := o + n * (-o.y / n.y)
		var tiefe := (boden - kamera_pos).dot(blick)
		var welt_pro_px := 2.0 * tiefe * halb_fov / bild_h
		# Eine Standardfigur (1 Einheit hoch) füllt den Platzhalter; die
		# Eigengröße der Figur (Troll 1.4, Katze 0.8) wirkt zusätzlich.
		var skala := rect.size.y * welt_pro_px * 1.0
		# Deckel: Riesen (Bosse) dürfen nicht in die Zugleiste ragen.
		if deckel != null and is_instance_valid(deckel):
			var platz_px := fuss.y - deckel.get_global_rect().end.y - 6.0
			var figur_px := skala * float(e["hoehe"]) / welt_pro_px
			if platz_px > 24.0 and figur_px > platz_px:
				skala *= platz_px / figur_px

		# Animationen des Platzhalters übernehmen.
		var puls := ph.scale.x
		var zur_kamera := Vector3(kamera_pos.x - boden.x, 0.0, kamera_pos.z - boden.z).normalized()
		e["rueck"] = maxf(0.0, float(e["rueck"]) - delta * 4.0)
		var pos := boden + zur_kamera * ((puls - 1.0) * 2.4 - float(e["rueck"]) * 0.35)
		var lebendig: bool = e["lebt"].call()
		e["tot"] = 0.0 if lebendig else minf(1.0, float(e["tot"]) + delta * 3.0)
		var rest := 1.0 - float(e["tot"])
		figur.visible = rest > 0.01
		var phase: float = e["phase"]
		var hoehe := (float(figur.get_meta("schwebt", 0.0))
			+ sin(_zeit * 2.2 + phase) * float(figur.get_meta("wippen", 0.0))) * skala
		figur.position = pos + Vector3(0, hoehe, 0)
		var basis: Vector3 = e["basis"]
		var s := basis * skala * puls * rest
		var quetsch := float(figur.get_meta("quetschen", 0.0))
		if quetsch > 0.0 and lebendig:
			var q := sin(_zeit * 3.0 + phase) * quetsch
			s *= Vector3(1.0 - q * 0.5, 1.0 + q, 1.0 - q * 0.5)
		figur.scale = s
		# Zur Kamera blicken; Figuren mit Meta "drehung" (Vierbeiner & Co.)
		# stehen in 3/4-Ansicht, jeweils zur Bildmitte gewandt.
		var seite := -1.0 if boden.x > 0.0 else 1.0
		var drehung := deg_to_rad(float(figur.get_meta("drehung", 0.0))) * seite
		_status_beleben(e, skala)
		figur.rotation = Vector3(0.0,
			atan2(kamera_pos.x - boden.x, kamera_pos.z - boden.z) + drehung + (1.0 - rest) * 6.0,
			-ph.rotation * 1.4)
	if _stoss > 0.0:
		_stoss = maxf(0.0, _stoss - delta)
		_kamera.h_offset = randf_range(-1.0, 1.0) * _stoss * 0.35
		_kamera.v_offset = randf_range(-1.0, 1.0) * _stoss * 0.35
	for i in _fackeln.size():
		var licht: OmniLight3D = _fackeln[i].get_meta("licht")
		licht.light_energy = 0.5 * (0.88 + 0.12 * sin(_zeit * 13.0 + i) * sin(_zeit * 7.3 + i * 2.0))
