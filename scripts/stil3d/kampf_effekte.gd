class_name KampfEffekte
extends Node3D
## Kampf-Effekte im STIL-3D-Look (STIL-3D.md 7f): Elemente, Waffentreffer,
## Heilung, Buffs, Krits — alles aus Grundkörpern + leuchtendem Additiv-
## Shader, kurzlebig und selbst-aufräumend.
## Gegner stehen als 3D-Figuren in der Arena (Effekt in 3D), Helden sind die
## Party-Karten unten (Effekt in 2D über der Karte, sonst läge er HINTER der
## UI). Projektile fliegen in 3D vom Werfer zum Ziel.
##
## Ereignisse kommen von Battle.effekt (Dictionary mit "art", "von", "an",
## optional "element", "faktor", "status", "fern"); `ort_fuer(schluessel)`
## liefert {"welt": Vector3} für Arena-Figuren oder {"rect": Rect2} für Karten.

const FLUGZEIT := 0.22
const VFX_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;
uniform vec4 farbe : source_color = vec4(1.0);
uniform float staerke = 1.0;
void fragment() {
	// Satter Kern, heller Rand (Fresnel) — bleibt farbig auch auf hellem Boden.
	float rand = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = mix(farbe.rgb, vec3(1.0), rand * rand * 0.35) * 1.15;
	ALPHA = clamp(farbe.a * staerke * (0.55 + rand * 0.45), 0.0, 1.0);
}
"""

const ELEMENT_FARBEN := {
	Enums.Element.FIRE: Color("ff8a2a"), Enums.Element.ICE: Color("7fe8ff"),
	Enums.Element.LIGHTNING: Color("ffe45a"), Enums.Element.POISON: Color("8fe04a"),
	Enums.Element.HOLY: Color("fff2b0"), Enums.Element.DARK: Color("a066f0"),
}
const MAGIE_FARBE := Color("c08cff")
const WAFFEN_FARBE := Color("f4f1ea")
const HEIL_FARBE := Color("7dffa0")
const BLUT_FARBE := Color("e0505e")
## Buffs (gut, blau/grün) und Debuffs (lila) als aufsteigende Ringe.
const STATUS_FARBEN := {
	Enums.Status.SHIELD: Color("7fb8ff"), Enums.Status.PROTECT: Color("7fb8ff"),
	Enums.Status.DEF_UP: Color("9fb0d0"), Enums.Status.ATK_UP: Color("ff9a3a"),
	Enums.Status.REGEN: HEIL_FARBE, Enums.Status.MANA_REGEN: Color("6f9fff"),
	Enums.Status.COUNTER: Color("ffd25a"), Enums.Status.THORNS: Color("ffd25a"),
	Enums.Status.FIRST_STRIKE: Color("ffd25a"), Enums.Status.CLEANSE: Color("ffffff"),
	Enums.Status.WEAKEN: Color("8f5fd8"), Enums.Status.SLOW: Color("6f7fd0"),
	Enums.Status.MARKED: Color("ff5a5a"), Enums.Status.ARMOR_BREAK: Color("c08060"),
	Enums.Status.STUN: Color("ffe45a"), Enums.Status.CURSED: Color("8f5fd8"),
	Enums.Status.MAGIE_SCHUTZ: Color("b48cff"), Enums.Status.ELEMENT_SCHUTZ: Color("ffd27a"),
	Enums.Status.MAGIE_BRUCH: Color("8f5fd8"), Enums.Status.ELEMENT_SCHWAECHE: Color("e07a3a"),
	Enums.Status.ENTZAUBERN: Color("ffffff"),
}

static var _shader: Shader
static var _punkt_tex: GradientTexture2D

var kamera: Camera3D
var ui: Control  ## Ebene für 2D-Effekte, Zahlen und Popups
var buehne: KampfBuehne3D  ## für Rückstoß der getroffenen Figur


static func element_farbe(element: int) -> Color:
	return ELEMENT_FARBEN.get(element, MAGIE_FARBE)


## Spielt alle Ereignisse einer Aktion: erst die Projektile (parallel),
## dann Einschläge und Popups. Kehrt nach der Flugzeit zurück.
func abspielen(ereignisse: Array, ort_fuer: Callable) -> void:
	var flug := false
	var geflogen := {}
	for e in ereignisse:
		e["art"] = StringName(str(e.get("art", "")))  # übers Netz kommt String
	for e in ereignisse:
		if not _hat_projektil(e):
			continue
		var paar := "%s>%s" % [str(e.get("von")), str(e.get("an"))]
		if geflogen.has(paar):
			continue
		geflogen[paar] = true
		var von: Variant = _punkt(ort_fuer.call(e["von"]))
		var an: Variant = _punkt(ort_fuer.call(e["an"]))
		if von == null or an == null:
			continue
		_kugel(von, _farbe_von(e), 0.55, 0.15)  # Mündungsblitz beim Werfer
		_projektil(von, an, _farbe_von(e), e.get("art") == &"waffe")
		flug = true
	if flug:
		await get_tree().create_timer(FLUGZEIT).timeout
	# Mehrere Popups auf demselben Ziel stapeln (Krit + sehr effektiv …).
	var stapel := {}
	for e in ereignisse:
		var ziel := str(e.get("an"))
		var hoehe: int = stapel.get(ziel, 0)
		if _hat_popup(e):
			stapel[ziel] = hoehe + 1
		_einschlag(e, ort_fuer.call(e.get("an")), hoehe)


func _hat_popup(e: Dictionary) -> bool:
	match e.get("art"):
		&"krit", &"block":
			return true
		&"element":
			return not is_equal_approx(float(e.get("faktor", 1.0)), 1.0)
	return false


func _hat_projektil(e: Dictionary) -> bool:
	if e.get("von") == null or e.get("von") == e.get("an"):
		return false
	match e.get("art"):
		&"element", &"magie":
			return true
		&"waffe":
			return bool(e.get("fern", false))
	return false


func _farbe_von(e: Dictionary) -> Color:
	match e.get("art"):
		&"element", &"dot":
			return element_farbe(int(e.get("element", -1))) if int(e.get("element", -1)) >= 0 else BLUT_FARBE
		&"magie":
			return MAGIE_FARBE
		&"heilung":
			return HEIL_FARBE
		&"status":
			return STATUS_FARBEN.get(int(e.get("status", -1)), MAGIE_FARBE)
	return WAFFEN_FARBE


## Weltpunkt eines Orts: Figuren direkt, Karten über den Boden unter ihnen
## (Projektile starten/landen dort sichtbar vor der Party).
func _punkt(ort: Variant) -> Variant:
	if ort is Dictionary:
		if ort.has("welt"):
			return ort["welt"]
		if ort.has("rect") and kamera != null:
			var r: Rect2 = ort["rect"]
			var px := Vector2(r.get_center().x, r.position.y - 10.0)
			var o := kamera.project_ray_origin(px)
			var n := kamera.project_ray_normal(px)
			if n.y < -0.001:
				return o + n * ((0.6 - o.y) / n.y)
	return null


# --- Einschläge ------------------------------------------------------------------

## Schadensarten, die das Ziel zurückstoßen und die Karte wackeln lassen.
const SCHADEN_ARTEN: Array[StringName] = [&"element", &"waffe", &"magie", &"krit"]


func _einschlag(e: Dictionary, ort: Variant, stufe := 0) -> void:
	if not (ort is Dictionary):
		return
	var art: StringName = e.get("art", &"")
	var farbe := _farbe_von(e)
	var heilt: bool = art == &"element" and int(e.get("element", -1)) == Enums.Element.HOLY \
		and e.get("heilt", false)
	if ort.has("rect"):
		_karten_effekt(ort, e, farbe, stufe)
		return
	var pos: Vector3 = ort["welt"]
	var boden := Vector3(pos.x, 0.05, pos.z)
	# Treffer stoßen die Figur kurz zurück (Krit stärker).
	if art in SCHADEN_ARTEN and not heilt and buehne != null and ort.has("schluessel"):
		buehne.rueckstoss(ort["schluessel"], 1.8 if art == &"krit" else 1.0)
	match art:
		&"element":
			_element_3d(int(e.get("element", -1)), pos, boden, float(e.get("faktor", 1.0)))
		&"magie":
			_licht(pos, farbe, 2.5)
			_kugel(pos, farbe, 0.9, 0.35)
			_funken(pos, farbe, 16, 2.5)
		&"waffe":
			if e.get("fern", false):
				_kugel(pos, farbe, 0.45, 0.2)
				_funken(pos, Color("ffe8b0"), 12, 3.0)
			else:
				_schnitt(pos)
				_funken(pos, Color("ffe8b0"), 12, 3.5)
			_licht(pos, Color("ffe8b0"), 1.2, 0.15)
		&"heilung":
			_licht(pos, HEIL_FARBE, 1.8, 0.4)
			_funken(pos, HEIL_FARBE, 22, 1.2, Vector3(0, 2.2, 0))
			_ring(boden, HEIL_FARBE, 1.3)
			_ring(boden, HEIL_FARBE, 0.8, true)
		&"status":
			_ring(boden, farbe, 1.0, true)
			_funken(pos, farbe, 8, 1.0, Vector3(0, 1.5, 0))
		&"dot":
			_kugel(pos, farbe, 0.4, 0.25)
			_funken(pos, farbe, 6, 1.0, Vector3(0, 1.0, 0))
		&"krit":
			_licht(pos, Color(1.0, 0.85, 0.6), 4.0, 0.2)
			_kugel(pos, Color(1.0, 0.95, 0.8), 1.4, 0.18)
			_bodenwelle(boden, Color(1.0, 0.85, 0.6))
		&"beschwoerung":
			_saeule(boden, MAGIE_FARBE, 0.8)
			_funken(pos, MAGIE_FARBE, 20, 2.0, Vector3(0, 1.5, 0))
	_popup(e, _bildpunkt(pos) - Vector2(0, 30 * stufe))


## Element-Signaturen in der Arena. Schwäche (faktor > 1) = größer + Bodenwelle.
func _element_3d(element: int, pos: Vector3, boden: Vector3, faktor := 1.0) -> void:
	var farbe := element_farbe(element)
	var gross := 1.25 if faktor > 1.0 else (0.75 if faktor < 1.0 else 1.0)
	_licht(pos, farbe, 3.0 * gross)
	if faktor > 1.0:
		_bodenwelle(boden, farbe)
	match element:
		Enums.Element.FIRE:
			_kugel(pos, farbe, 1.2 * gross, 0.4)
			_kugel(pos, Color("ffe08a"), 0.65 * gross, 0.25)
			_flammen(boden, farbe, gross)
			_funken(pos, farbe, 28, 3.2, Vector3(0, 2.5, 0))
		Enums.Element.ICE:
			_splitter(pos, farbe, roundi(7 * gross))
			_kugel(pos, Color("e8fbff"), 0.75 * gross, 0.3)
			_ring(boden, farbe, 1.1 * gross)
		Enums.Element.LIGHTNING:
			_blitzstrahl(pos + Vector3(0.4, 4.5, 0.3), pos, farbe)
			_blitzstrahl(pos + Vector3(-0.5, 4.2, -0.2), pos, Color("fff6c0"))
			_kugel(pos, farbe, 0.9 * gross, 0.2)
			_funken(pos, farbe, 20, 4.5)
		Enums.Element.POISON:
			_kugel(pos, farbe, 0.85 * gross, 0.35)
			_funken(pos, farbe, 22, 0.8, Vector3(0, 1.4, 0), 0.07)
			_ring(boden, Color("5a7a2c"), 1.2 * gross)
		Enums.Element.HOLY:
			_saeule(boden, farbe, 1.0 * gross)
			_saeule(boden, Color("ffffff"), 0.45 * gross)
			_funken(pos, farbe, 22, 1.0, Vector3(0, 2.5, 0))
		Enums.Element.DARK:
			_implosion(pos, farbe)
			_ring(boden, Color("3a2f4f"), 1.4 * gross)
			_funken(pos, farbe, 16, 1.8)
		_:
			_kugel(pos, farbe, 0.8, 0.3)


## Rauchwolke + Funken, wenn ein Gegner fällt.
func tod(pos: Vector3) -> void:
	for i in 6:
		var versatz := Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.6), randf_range(-0.4, 0.4))
		var mi := _teil(Stil3D.kugel(0.3), Color(0.55, 0.52, 0.62), pos + versatz)
		mi.scale = Vector3.ONE * 0.4
		var tween := create_tween().set_parallel(true)
		tween.tween_property(mi, "scale", Vector3.ONE * randf_range(1.4, 2.0), 0.6).set_ease(Tween.EASE_OUT)
		tween.tween_property(mi, "global_position", pos + versatz + Vector3(0, 0.8, 0), 0.6)
		_verblassen(mi, 0.6)
	_funken(pos, Color("ffd25a"), 14, 2.5)

# --- Bausteine (alle selbst-aufräumend) -------------------------------------------

func _material(farbe: Color) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = VFX_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("farbe", farbe)
	return mat


func _teil(mesh: Mesh, farbe: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(farbe)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	return mi


## Ausblenden + Aufräumen eines Effekt-Teils.
func _verblassen(mi: MeshInstance3D, dauer: float, verzoegerung := 0.0) -> Tween:
	var mat: ShaderMaterial = mi.material_override
	var tween := create_tween()
	tween.tween_interval(verzoegerung)
	tween.tween_method(func(a: float) -> void: mat.set_shader_parameter("staerke", a), 1.0, 0.0, dauer)
	tween.tween_callback(mi.queue_free)
	return tween


func _kugel(pos: Vector3, farbe: Color, groesse: float, dauer: float) -> void:
	var mi := _teil(Stil3D.kugel(0.5), farbe, pos)
	mi.scale = Vector3.ONE * 0.2
	var wachsen := create_tween()
	wachsen.tween_property(mi, "scale", Vector3.ONE * groesse, dauer).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_verblassen(mi, dauer)


func _implosion(pos: Vector3, farbe: Color) -> void:
	var mi := _teil(Stil3D.kugel(0.5), farbe, pos)
	mi.scale = Vector3.ONE * 1.6
	var schrumpfen := create_tween()
	schrumpfen.tween_property(mi, "scale", Vector3.ONE * 0.1, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_verblassen(mi, 0.2, 0.2)


func _ring(boden: Vector3, farbe: Color, groesse: float, aufsteigend := false) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	var mi := _teil(torus, farbe, boden)
	mi.scale = Vector3.ONE * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(mi, "scale", Vector3.ONE * groesse * 1.4, 0.5)
	if aufsteigend:
		tween.tween_property(mi, "global_position", boden + Vector3(0, 1.3, 0), 0.5)
	_verblassen(mi, 0.5)


func _saeule(boden: Vector3, farbe: Color, breite: float) -> void:
	var mi := _teil(Stil3D.zylinder(0.35 * breite, 0.45 * breite, 5.0), farbe, boden + Vector3(0, 2.5, 0))
	mi.scale = Vector3(0.2, 1.0, 0.2)
	var tween := create_tween()
	tween.tween_property(mi, "scale", Vector3.ONE, 0.12)
	_verblassen(mi, 0.45, 0.1)


func _schnitt(pos: Vector3) -> void:
	var mi := _teil(Stil3D.box(1.6, 0.06, 0.02), WAFFEN_FARBE, pos)
	mi.look_at(kamera.global_position if kamera != null else pos + Vector3.BACK)
	mi.rotate_object_local(Vector3.FORWARD, deg_to_rad(randf_range(25.0, 55.0) * (1 if randf() < 0.5 else -1)))
	mi.scale = Vector3(0.1, 1.0, 1.0)
	var tween := create_tween()
	tween.tween_property(mi, "scale", Vector3(1.0, 1.0, 1.0), 0.08)
	_verblassen(mi, 0.18, 0.06)


func _splitter(pos: Vector3, farbe: Color, anzahl := 7) -> void:
	for i in anzahl:
		var richtung := Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized()
		var mi := _teil(Stil3D.prisma(0.12, 0.45, 0.12), farbe, pos)
		mi.look_at(pos + richtung, Vector3.UP if absf(richtung.y) < 0.95 else Vector3.RIGHT)
		mi.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
		var tween := create_tween()
		tween.tween_property(mi, "global_position", pos + richtung * 1.1, 0.32).set_ease(Tween.EASE_OUT)
		_verblassen(mi, 0.32, 0.05)


## Aufleuchten: färbt Figur und Boden kurz in der Effektfarbe.
func _licht(pos: Vector3, farbe: Color, energie: float, dauer := 0.3) -> void:
	var licht := OmniLight3D.new()
	licht.light_color = farbe
	licht.light_energy = energie * 0.22  # Akzent, kein Flutlicht
	licht.omni_range = 3.0
	add_child(licht)
	licht.global_position = pos + Vector3(0, 0.6, 0.6)
	var tween := create_tween()
	tween.tween_property(licht, "light_energy", 0.0, dauer).set_ease(Tween.EASE_IN)
	tween.tween_callback(licht.queue_free)


## Flache Druckwelle über den Boden (Krits, Schwächen).
func _bodenwelle(boden: Vector3, farbe: Color) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.46
	torus.outer_radius = 0.5
	var mi := _teil(torus, farbe, boden)
	mi.scale = Vector3(0.6, 0.2, 0.6)
	var tween := create_tween()
	tween.tween_property(mi, "scale", Vector3(4.0, 0.2, 4.0), 0.45).set_ease(Tween.EASE_OUT)
	_verblassen(mi, 0.45)


## Flammenzungen, die aus dem Boden schlagen (Feuer).
func _flammen(boden: Vector3, farbe: Color, gross := 1.0) -> void:
	for i in 6:
		var winkel := TAU * i / 6.0 + randf() * 0.5
		var stelle := boden + Vector3(cos(winkel), 0, sin(winkel)) * 0.45 * gross
		var mi := _teil(Stil3D.kegel(0.16 * gross, 0.6 * gross), farbe if i % 2 else Color("ffd25a"), stelle)
		mi.scale = Vector3(1.0, 0.1, 1.0)
		var tween := create_tween()
		tween.tween_interval(randf() * 0.08)
		tween.tween_property(mi, "scale", Vector3(1.0, randf_range(1.0, 1.6), 1.0), 0.14).set_ease(Tween.EASE_OUT)
		_verblassen(mi, 0.3, 0.12)


func _blitzstrahl(von: Vector3, nach: Vector3, farbe: Color) -> void:
	var punkte: Array[Vector3] = [von]
	for i in range(1, 6):
		var t := i / 6.0
		punkte.append(von.lerp(nach, t) + Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.35, 0.35)))
	punkte.append(nach)
	for i in punkte.size() - 1:
		var a := punkte[i]
		var b := punkte[i + 1]
		var mi := _teil(Stil3D.box(0.11, 0.11, a.distance_to(b)), farbe, (a + b) * 0.5)
		mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT)
		_verblassen(mi, 0.25)


func _funken(pos: Vector3, farbe: Color, menge: int, tempo: float, schwerkraft := Vector3(0, -6, 0),
		groesse := 0.045) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = menge
	p.lifetime = 0.6
	var mesh := SphereMesh.new()
	mesh.radius = groesse
	mesh.height = groesse * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh
	p.material_override = _material(farbe)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = tempo * 0.5
	p.initial_velocity_max = tempo
	p.gravity = schwerkraft
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var kurve := Curve.new()
	kurve.add_point(Vector2(0, 1))
	kurve.add_point(Vector2(1, 0))
	p.scale_amount_curve = kurve
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)


func _projektil(von: Vector3, nach: Vector3, farbe: Color, pfeil: bool) -> void:
	var mi := _teil(Stil3D.box(0.05, 0.05, 0.7) if pfeil else Stil3D.kugel(0.22), farbe, von)
	if pfeil:
		mi.look_at(nach, Vector3.UP)
	var spur := CPUParticles3D.new()
	spur.amount = 40
	spur.lifetime = 0.3
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	mesh.radial_segments = 6
	mesh.rings = 3
	spur.mesh = mesh
	spur.material_override = _material(farbe)
	spur.local_coords = false
	spur.gravity = Vector3.ZERO
	spur.spread = 20.0
	spur.initial_velocity_max = 0.3
	var kurve := Curve.new()
	kurve.add_point(Vector2(0, 1))
	kurve.add_point(Vector2(1, 0))
	spur.scale_amount_curve = kurve
	mi.add_child(spur)
	var bogen := von.lerp(nach, 0.5) + Vector3(0, 0.0 if pfeil else 0.8, 0)
	var fliegen := func(t: float) -> void:
		if is_instance_valid(mi):
			mi.global_position = von.lerp(bogen, t).lerp(bogen.lerp(nach, t), t)
	var tween := create_tween()
	tween.tween_method(fliegen, 0.0, 1.0, FLUGZEIT)
	tween.tween_callback(mi.queue_free)


# --- 2D: Party-Karten und Popups --------------------------------------------------

func _karten_effekt(ort: Dictionary, e: Dictionary, farbe: Color, stufe := 0) -> void:
	if ui == null:
		return
	var rect: Rect2 = ort["rect"]
	var art: StringName = e.get("art", &"")
	if art in SCHADEN_ARTEN:
		if art == &"waffe" and not e.get("fern", false):
			_krallen(rect)
		var karte: Control = ort.get("karte")
		if karte != null and is_instance_valid(karte):
			_karte_wackeln(karte, 1.6 if art == &"krit" else 1.0)
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 22
	p.lifetime = 0.55
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = rect.size * Vector2(0.4, 0.25)
	p.direction = Vector2.UP
	p.spread = 70.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 220) if e.get("art") != &"heilung" else Vector2(0, -60)
	p.texture = _punkt_textur()
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.5
	var verlauf := Gradient.new()
	verlauf.set_color(0, Color(farbe, 1.0))
	verlauf.set_color(1, Color(farbe, 0.0))
	p.color_ramp = verlauf
	p.z_index = 40
	ui.add_child(p)
	p.global_position = rect.get_center()
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)
	var blitz := ColorRect.new()
	blitz.color = Color(farbe, 0.28)
	blitz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blitz.z_index = 39
	ui.add_child(blitz)
	blitz.global_position = rect.position
	blitz.size = rect.size
	var tween := blitz.create_tween()
	tween.tween_property(blitz, "color:a", 0.0, 0.3)
	tween.tween_callback(blitz.queue_free)
	_popup(e, rect.get_center() - Vector2(0, rect.size.y * 0.5 + 30 * stufe))


## Drei Krallenspuren quer über die Karte (Nahkampftreffer auf Helden).
func _krallen(rect: Rect2) -> void:
	var mitte := rect.get_center()
	for i in 3:
		var linie := Line2D.new()
		linie.width = 5.0
		linie.default_color = Color(1.0, 0.92, 0.85)
		linie.begin_cap_mode = Line2D.LINE_CAP_ROUND
		linie.end_cap_mode = Line2D.LINE_CAP_ROUND
		var versatz := Vector2((i - 1) * 22.0, 0)
		linie.add_point(mitte + versatz + Vector2(-38, -30))
		linie.add_point(mitte + versatz + Vector2(26, 30))
		linie.z_index = 41
		ui.add_child(linie)
		linie.scale = Vector2.ONE
		var tween := linie.create_tween()
		tween.tween_property(linie, "width", 1.0, 0.3).set_delay(0.05 + i * 0.03)
		tween.parallel().tween_property(linie, "modulate:a", 0.0, 0.3).set_delay(0.05 + i * 0.03)
		tween.tween_callback(linie.queue_free)


## Karte kurz schütteln (Rotation — Container setzen die Position zurück).
func _karte_wackeln(karte: Control, staerke := 1.0) -> void:
	karte.pivot_offset = karte.size * 0.5
	var tween := karte.create_tween()
	for winkel in [3.0, -3.0, 2.0, -1.0, 0.0]:
		tween.tween_property(karte, "rotation", deg_to_rad(winkel * staerke), 0.04)


## Weicher runder Lichtpunkt für 2D-Partikel (statt harter Quadrate).
static func _punkt_textur() -> GradientTexture2D:
	if _punkt_tex == null:
		var verlauf := Gradient.new()
		verlauf.set_color(0, Color(1, 1, 1, 1))
		verlauf.set_color(1, Color(1, 1, 1, 0))
		verlauf.add_point(0.45, Color(1, 1, 1, 0.85))
		_punkt_tex = GradientTexture2D.new()
		_punkt_tex.gradient = verlauf
		_punkt_tex.fill = GradientTexture2D.FILL_RADIAL
		_punkt_tex.fill_from = Vector2(0.5, 0.5)
		_punkt_tex.fill_to = Vector2(1.0, 0.5)
		_punkt_tex.width = 32
		_punkt_tex.height = 32
	return _punkt_tex


func _bildpunkt(pos: Vector3) -> Vector2:
	if kamera == null:
		return Vector2.ZERO
	return kamera.unproject_position(pos + Vector3(0, 0.7, 0))


## Große Texte über dem Ziel: „SEHR EFFEKTIV!“, „kaum Wirkung …“, „KRITISCH!“, „Block!“.
func _popup(e: Dictionary, punkt: Vector2) -> void:
	var text := ""
	var farbe := Color.WHITE
	var groesse := 20
	match e.get("art"):
		&"element":
			var faktor := float(e.get("faktor", 1.0))
			if faktor > 1.0:
				text = Loc.pick("SEHR EFFEKTIV!", "SUPER EFFECTIVE!")
				farbe = UiTheme.GOLD
				groesse = 26
			elif faktor < 1.0:
				text = Loc.pick("kaum Wirkung …", "barely any effect …")
				farbe = Color(0.7, 0.72, 0.82)
				groesse = 18
		&"krit":
			if e.get("voll", false):
				text = Loc.pick("VOLLTREFFER!", "BULLSEYE!")
				farbe = UiTheme.GOLD
				groesse = 32
			elif e.get("schwach", false):
				text = Loc.pick("SCHWACHSTELLE!", "WEAK SPOT!")
				farbe = Color("7fe8ff")
				groesse = 24
			else:
				text = Loc.pick("KRITISCH!", "CRITICAL!")
				farbe = Color("ff9a3a")
				groesse = 26
		&"block":
			text = Loc.pick("Block!", "Block!")
			farbe = Color("9fc0ff")
	if text.is_empty() or ui == null:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", groesse)
	label.add_theme_color_override("font_color", farbe)
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.08, 0.95))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 45
	ui.add_child(label)
	label.reset_size()
	label.pivot_offset = label.size * 0.5
	var start := punkt - label.size * 0.5 - Vector2(0, 24)
	label.global_position = start
	label.scale = Vector2.ONE * 0.4
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.08)
	tween.tween_interval(0.5)
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", start + Vector2(0, -28), 0.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(label.queue_free)
