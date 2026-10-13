class_name KampfBuehne3D
extends Node3D
## 3D-Arena hinter der Kampf-Oberfläche (STIL-3D.md, Abschnitt 7c).
## Die UI bleibt Herr über Layout, Klicks und Tooltips: Jeder Gegner hat im
## Panel einen unsichtbaren Platzhalter. Seine 3D-Figur stellt sich jedes
## Bild genau darauf — Strahl durch den Fußpunkt des Platzhalters auf den
## Arena-Boden, Höhe = Platzhalterhöhe — und übernimmt dessen Animationen:
## scale-Puls » Ausfallschritt Richtung Kamera, rotation » Taumeln.

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


func aufbauen(boden_tint := Color.WHITE, wand_tint := Color.WHITE) -> void:
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

	# Arena: dunkle Steinscheibe, heller Kampfkreis, Säulenreihe mit Fackeln.
	var stein := Stil3D.farbe("stein") * boden_tint
	Stil3D.teil(self, Stil3D.zylinder(15.0, 15.0, 0.3), Stil3D.farbe("stein_dunkel") * boden_tint * 0.75,
		Vector3(0, -0.15, -2.0), Vector3.ZERO, false)
	Stil3D.teil(self, Stil3D.zylinder(6.5, 6.5, 0.04), stein * 0.85, Vector3(0, 0.0, -2.6), Vector3.ZERO, false)
	Stil3D.teil(self, Stil3D.zylinder(6.7, 6.7, 0.03), Stil3D.farbe("fuge"), Vector3(0, -0.005, -2.6),
		Vector3.ZERO, false)
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


## Figur an einen UI-Platzhalter binden. lebt() entscheidet über Verpuffen.
func anmelden(schluessel: Variant, platzhalter: Control, figur: Node3D, lebt: Callable) -> void:
	abmelden(schluessel)
	add_child(figur)
	figur.visible = false  # erst zeigen, wenn der Platzhalter Layout hat
	_eintraege[schluessel] = {"ph": platzhalter, "fig": figur,
		"basis": figur.scale, "lebt": lebt, "tot": 0.0,
		"phase": float(absi(hash(str(schluessel))) % 628) / 100.0}


func abmelden(schluessel: Variant) -> void:
	if _eintraege.has(schluessel):
		_eintraege[schluessel]["fig"].queue_free()
		_eintraege.erase(schluessel)


func hat(schluessel: Variant) -> bool:
	return _eintraege.has(schluessel)


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
	for mi in figur.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = mat
	var setzen := func(a: float) -> void:
		mat.set_shader_parameter("farbe", Color(grund.r, grund.g, grund.b, a))
	var aufraeumen := func() -> void:
		if is_instance_valid(figur):
			for mi in figur.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_overlay = null
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

		# Animationen des Platzhalters übernehmen.
		var puls := ph.scale.x
		var zur_kamera := Vector3(kamera_pos.x - boden.x, 0.0, kamera_pos.z - boden.z).normalized()
		var pos := boden + zur_kamera * (puls - 1.0) * 2.4
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
		figur.rotation = Vector3(0.0,
			atan2(kamera_pos.x - boden.x, kamera_pos.z - boden.z) + drehung + (1.0 - rest) * 6.0,
			-ph.rotation * 1.4)
	for i in _fackeln.size():
		var licht: OmniLight3D = _fackeln[i].get_meta("licht")
		licht.light_energy = 0.5 * (0.88 + 0.12 * sin(_zeit * 13.0 + i) * sin(_zeit * 7.3 + i * 2.0))
