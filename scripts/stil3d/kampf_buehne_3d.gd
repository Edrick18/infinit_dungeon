class_name KampfBuehne3D
extends Node3D
## 3D-Arena hinter der Kampf-Oberfläche (STIL-3D.md, Abschnitt 7c).
## Die UI bleibt Herr über Layout, Klicks und Tooltips: Jeder Gegner hat im
## Panel einen unsichtbaren Platzhalter. Seine 3D-Figur stellt sich jedes
## Bild genau darauf — Strahl durch den Fußpunkt des Platzhalters auf den
## Arena-Boden, Höhe = Platzhalterhöhe — und übernimmt dessen Animationen:
## scale-Puls » Ausfallschritt Richtung Kamera, rotation » Taumeln.
## Die Halle selbst (Säulen, Kulisse, Boden, Licht) baut KampfHalle; die
## Bühne tweent ihre Stimmung (Boss-Auftritt, Phasen) und spielt das
## Treffer-Feedback (Fresnel-Blitz, Squash, Hit-Stop, Kamera-Ruck).

const FOV := 38.0
## Steil genug, dass die Gegner-Panels (oberes Bilddrittel) den Boden VOR
## den Säulen treffen — sonst stehen die Figuren dahinter.
const KAMERA_POS := Vector3(0.0, 6.0, 8.5)
const KAMERA_ZIEL := Vector3(0.0, 0.2, -1.5)
## Treffer: kurzer Hit-Stop (nur Krit/Volltreffer) und Squash der Figur.
const HIT_STOP := 0.06
const QUETSCH_DAUER := 0.4

## Treffer-Blitz: farbiger Fresnel-Rand statt Vollfarbe (die Figur bleibt
## lesbar), dazu ein schwacher Kern. Ein Material je Figur, wiederverwendet.
const BLITZ_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, shadows_disabled, depth_draw_never;
uniform vec4 farbe : source_color = vec4(1.0, 0.3, 0.3, 0.0);
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rand = smoothstep(0.2, 0.85, f);
	ALBEDO = farbe.rgb * farbe.a * (0.14 + rand * 1.9);
}
"""

static var _blitz_shader: Shader

var _kamera: Camera3D
## Schlüssel » {"ph": Control, "fig": Node3D, "basis": Vector3, "lebt": Callable,
##             "tot": float, "phase": float, "teile": Array (Meshes ohne Hüllen),
##             "blitz_mat", "blitz_tween", "stopp", "quetsch"}
var _eintraege: Dictionary = {}
var _fackeln: Array[Node3D] = []
var _zeit := 0.0
## Optional: Figuren ragen nie über die Unterkante dieses Controls (Zugleiste).
var deckel: Control
## Kampf-Effekte (Elemente, Treffer, Projektile) — siehe KampfEffekte.
var effekte: KampfEffekte
var _stoss := 0.0
var _ruck := Vector2.ZERO
## Halle (KampfHalle.bauen): Umgebung, Lichter, Siegel, Untergrund.
var _halle: Dictionary = {}
var _stil: Dictionary = {}
var _fackel_faktor := 1.0
var _boss_schluessel: Variant = null
var _boss_phase := 0
var _stimmung_tween: Tween
var _proben: Array[Node] = []


## stil = BiomStil.fuer(biom) (leer = Wald).
func aufbauen(stil: Dictionary = {}) -> void:
	_stil = stil if not stil.is_empty() else BiomStil.fuer(Enums.Biome.FOREST)
	_halle = KampfHalle.bauen(self, _stil)
	_fackeln = _halle["fackeln"]
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().use_debanding = true  # dunkle Verläufe (Nebel, Lichtinsel) ohne Treppen
	WeltMaterial.vignette(self, 0.4)

	_kamera = Camera3D.new()
	_kamera.fov = FOV
	add_child(_kamera)
	_kamera.look_at_from_position(KAMERA_POS, KAMERA_ZIEL)
	_kamera.make_current()
	effekte = KampfEffekte.new()
	effekte.kamera = _kamera
	effekte.buehne = self
	add_child(effekte)
	_vorwaermen()


## Shader vorwärmen: Compatibility übersetzt einen Shader erst beim ersten
## Zeichnen — der erste Zauber, Treffer-Blitz, Schweif oder Goldglanz kostete
## sonst einen Hänger. Winzige Proben unter dem Arenaboden (verdeckt, aber
## gezeichnet), nach ein paar Bildern wieder weg.
func _vorwaermen() -> void:
	var ort := KampfHalle.MITTE + Vector3(0, -0.2, 0)
	if _blitz_shader == null:
		_blitz_shader = Shader.new()
		_blitz_shader.code = BLITZ_CODE
	var blitz_mat := ShaderMaterial.new()
	blitz_mat.shader = _blitz_shader
	var mats: Array[Material] = [Stil3D.gold(Stil3D.material(Stil3D.farbe("stein"), 0)),
		Schweif.material(Color.WHITE), WeltMaterial.material("funke"), WeltMaterial.material("saeule"),
		WeltMaterial.material("lichtfleck")]
	for mat in mats:
		var probe := MeshInstance3D.new()
		probe.mesh = Stil3D.box(0.02, 0.02, 0.02)
		probe.material_override = mat
		probe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(probe)
		probe.position = ort
		_proben.append(probe)
	_proben[0].material_overlay = blitz_mat
	_proben.append_array(effekte.vorwaermen(ort))
	# Boss-Spot ebenso kurz gezählt (Energie 0 zählt nicht, s. vorwaermen).
	var boss_spot: SpotLight3D = _halle["boss_spot"]
	if boss_spot.light_energy <= 0.0:
		boss_spot.light_energy = KampfEffekte.VORWAERM_ENERGIE
	var aufraeumen := create_tween()
	aufraeumen.tween_interval(0.4)
	aufraeumen.tween_callback(func() -> void:
		for probe in _proben:
			if is_instance_valid(probe):
				probe.queue_free()
		_proben.clear()
		effekte.vorwaermen_ende()
		if _boss_phase == 0:  # Boss-Auftritt hat den Spot schon übernommen
			boss_spot.light_energy = 0.0)


## Figur an einen UI-Platzhalter binden. lebt() entscheidet über Verpuffen.
func anmelden(schluessel: Variant, platzhalter: Control, figur: Node3D, lebt: Callable) -> void:
	abmelden(schluessel)
	add_child(figur)
	var hoehe := maxf(0.3, PortraitStudio._umriss(figur).end.y)  # bei Skala 1
	figur.visible = false  # erst zeigen, wenn der Platzhalter Layout hat
	# Teile für den Treffer-Blitz einmal merken (ohne Kontur-Hüllen; Status-
	# Teile kommen später dazu und blitzen nicht mit).
	var teile: Array[MeshInstance3D] = []
	var vorher: Array[Material] = []
	for mi in figur.find_children("*", "MeshInstance3D", true, false):
		if not Stil3D.ist_kontur((mi as MeshInstance3D).material_override):
			teile.append(mi)
			vorher.append((mi as MeshInstance3D).material_overlay)
	_eintraege[schluessel] = {"ph": platzhalter, "fig": figur, "hoehe": hoehe,
		"basis": figur.scale, "lebt": lebt, "tot": 0.0, "rueck": 0.0, "status": {},
		"phase": float(absi(hash(str(schluessel))) % 628) / 100.0, "teile": teile, "overlay": vorher,
		"blitz_mat": null, "blitz_tween": null, "stopp": 0.0, "quetsch": QUETSCH_DAUER}


func abmelden(schluessel: Variant) -> void:
	if _eintraege.has(schluessel):
		var fig: Variant = _eintraege[schluessel]["fig"]
		if is_instance_valid(fig):
			(fig as Node).queue_free()
		_eintraege.erase(schluessel)


func hat(schluessel: Variant) -> bool:
	return _eintraege.has(schluessel)


## Boss-Auftritt: die Halle dunkelt ab, Fackeln flackern herunter, rot-
## violettes Umgebungslicht, roter Spot auf den Boss — dazu Beben und
## zweimaliges Aufglühen. (Eine Kamerafahrt passt nicht: die Figuren stehen
## jedes Bild unter ihren UI-Plätzen, nur die Arena würde zoomen.)
func boss_intro(schluessel: Variant) -> void:
	if not _eintraege.has(schluessel):
		return
	_boss_schluessel = schluessel
	_boss_phase = maxi(_boss_phase, 1)
	_stimmung(KampfHalle.stimmung(_stil, _boss_phase), 1.3)
	_aufgluehen(schluessel)


## Boss-Phasenwechsel: kurzer Lichtblitz (Spot und Umgebung schlagen hell-
## rot auf), dann färbt sich die Halle dauerhaft röter; Beben + Aufglühen
## wie beim Auftritt. Zeigt nur die Phase, nie eine Absicht.
func boss_phase(schluessel: Variant, phase: int) -> void:
	if not _eintraege.has(schluessel):
		return
	_boss_schluessel = schluessel
	_boss_phase = maxi(_boss_phase, maxi(2, phase))
	if not _halle.is_empty():
		var env: Environment = _halle["env"]
		var spot: SpotLight3D = _halle["spot"]
		if _stimmung_tween != null and _stimmung_tween.is_valid():
			_stimmung_tween.kill()
		var aufschlag := create_tween().set_parallel(true)
		aufschlag.tween_property(spot, "light_energy", 5.5, 0.06)
		aufschlag.tween_property(spot, "light_color", Color(1.0, 0.8, 0.75), 0.06)
		aufschlag.tween_property(env, "ambient_light_energy", 1.0, 0.06)
		aufschlag.chain().tween_callback(func() -> void:
			_stimmung(KampfHalle.stimmung(_stil, _boss_phase), 0.8))
	_aufgluehen(schluessel)


## Zurück zur normalen Hallen-Stimmung (Co-op: neuer Kampf in derselben Szene).
func stimmung_normal() -> void:
	_boss_schluessel = null
	_boss_phase = 0
	_stimmung(KampfHalle.stimmung(_stil, 0), 0.6)


## Stimmung der Halle weich überblenden (Werte aus KampfHalle.stimmung).
func _stimmung(werte: Dictionary, dauer: float) -> void:
	if _halle.is_empty():
		return
	if _stimmung_tween != null and _stimmung_tween.is_valid():
		_stimmung_tween.kill()
	var env: Environment = _halle["env"]
	var sonne: DirectionalLight3D = _halle["sonne"]
	var spot: SpotLight3D = _halle["spot"]
	var siegel: ShaderMaterial = _halle["siegel"]
	var untergrund: ShaderMaterial = _halle["untergrund"]
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	t.tween_property(env, "ambient_light_color", werte["ambient"], dauer)
	t.tween_property(env, "ambient_light_energy", werte["ambient_energie"], dauer)
	t.tween_property(sonne, "light_color", werte["sonne"], dauer)
	t.tween_property(sonne, "light_energy", werte["sonne_energie"], dauer)
	t.tween_property(spot, "light_color", werte["spot"], dauer)
	t.tween_property(spot, "light_energy", werte["spot_energie"], dauer)
	t.tween_property(self, "_fackel_faktor", werte["fackeln"], dauer)
	t.tween_property(_halle["boss_spot"], "light_energy", werte["boss_spot"], dauer * 0.7)
	t.tween_method(func(c: Color) -> void: siegel.set_shader_parameter("farbe", c),
		siegel.get_shader_parameter("farbe"), werte["siegel"], dauer)
	t.tween_method(func(k: float) -> void: siegel.set_shader_parameter("staerke", k),
		float(siegel.get_shader_parameter("staerke")), werte["siegel_staerke"], dauer)
	t.tween_method(func(c: Color) -> void: untergrund.set_shader_parameter("schimmer", c),
		untergrund.get_shader_parameter("schimmer"), werte["schimmer"], dauer)
	_stimmung_tween = t


## Beben und zweimaliges Aufglühen des Bosses (Auftritt und Phasen).
func _aufgluehen(schluessel: Variant) -> void:
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


## Treffer: Figur weicht kurz von der Kamera weg (klingt in ~0.25 s ab) und
## wird gestaucht (Squash, federt in QUETSCH_DAUER aus).
func rueckstoss(schluessel: Variant, staerke := 1.0) -> void:
	if _eintraege.has(schluessel):
		_eintraege[schluessel]["rueck"] = maxf(float(_eintraege[schluessel]["rueck"]), staerke)
		_eintraege[schluessel]["quetsch"] = 0.0


## Hit-Stop (nur Krit/Volltreffer): die getroffene Figur friert ~60 ms ein —
## lokal, nicht über Engine.time_scale (Netz-Timer und Tweens laufen weiter).
func trefferstopp(schluessel: Variant) -> void:
	if _eintraege.has(schluessel):
		_eintraege[schluessel]["stopp"] = HIT_STOP


## Leichter Kamera-Ruck (Krit/Volltreffer): ein kurzer Stoß nach unten,
## federt sofort zurück — kein Wackeln.
func ruck(staerke := 1.0) -> void:
	if not Settings.bildschirm_wackeln:
		return
	_ruck = Vector2(randf_range(-0.35, 0.35), -1.0).normalized() * 0.07 * staerke


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
			var blase := _vfx_teil(n, Stil3D.kugel(maxf(0.55, hoehe * 0.6)),
				Color(0.5, 0.75, 1.0, 0.3 if id == Enums.Status.SHIELD else 0.18), Vector3(0, hoehe * 0.5, 0))
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


## Treffer (rot) oder Heilung (grün): farbiger Fresnel-Rand um die Figur.
## Ein Material je Figur (beim ersten Blitz angelegt, danach wiederverwendet);
## Kontur-Hüllen blitzen nicht mit, eigene Overlays (Glanz der Strahlenden)
## kommen danach zurück — auch wenn Treffer schnell aufeinander folgen.
func blitz(schluessel: Variant, heilung: bool) -> void:
	if not _eintraege.has(schluessel):
		return
	var e: Dictionary = _eintraege[schluessel]
	if e["blitz_mat"] == null:
		if _blitz_shader == null:
			_blitz_shader = Shader.new()
			_blitz_shader.code = BLITZ_CODE
		var neu := ShaderMaterial.new()
		neu.shader = _blitz_shader
		e["blitz_mat"] = neu
	var mat: ShaderMaterial = e["blitz_mat"]
	var alt: Variant = e["blitz_tween"]
	if alt != null and (alt as Tween).is_valid():
		(alt as Tween).kill()
	var teile: Array[MeshInstance3D] = e["teile"]
	for mi in teile:
		if is_instance_valid(mi):
			mi.material_overlay = mat
	var grund := Color(0.45, 1.0, 0.55) if heilung else Color(1.0, 0.36, 0.24)
	var setzen := func(a: float) -> void:
		mat.set_shader_parameter("farbe", Color(grund.r, grund.g, grund.b, a))
	var vorher: Array[Material] = e["overlay"]
	var aufraeumen := func() -> void:
		for i in teile.size():
			if is_instance_valid(teile[i]):
				teile[i].material_overlay = vorher[i]
	setzen.call(1.0)
	var tween := create_tween()
	tween.tween_interval(maxf(0.0, float(e["stopp"])))  # hält während des Hit-Stops
	tween.tween_method(setzen, 1.0, 0.0, 0.34)
	tween.tween_callback(aufraeumen)
	e["blitz_tween"] = tween


func _process(delta: float) -> void:
	_zeit += delta
	var bild_h := get_viewport().get_visible_rect().size.y
	var halb_fov := tan(deg_to_rad(FOV * 0.5))
	var kamera_pos := _kamera.global_position
	var blick := -_kamera.global_transform.basis.z
	for schluessel in _eintraege.keys():
		var e: Dictionary = _eintraege[schluessel]
		# Erst untypisiert prüfen: eine typisierte Zuweisung einer schon
		# freigegebenen Instanz bricht _process ab (Fackeln, Kamerastoß, alle
		# späteren Figuren blieben stehen).
		if not is_instance_valid(e["ph"]) or not is_instance_valid(e["fig"]):
			abmelden(schluessel)
			continue
		var ph: Control = e["ph"]
		var figur: Node3D = e["fig"]
		if float(e["stopp"]) > 0.0:
			e["stopp"] = float(e["stopp"]) - delta  # Hit-Stop: Figur steht still
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
		# Treffer-Squash: erst gestaucht, dann federnd zurück.
		if float(e["quetsch"]) < QUETSCH_DAUER:
			e["quetsch"] = float(e["quetsch"]) + delta
			var t := float(e["quetsch"])
			var qs := exp(-t * 9.0) * cos(t * 26.0) * 0.2
			s *= Vector3(1.0 + qs * 0.8, 1.0 - qs, 1.0 + qs * 0.8)
		figur.scale = s
		# Zur Kamera blicken; Figuren mit Meta "drehung" (Vierbeiner & Co.)
		# stehen in 3/4-Ansicht, jeweils zur Bildmitte gewandt.
		var seite := -1.0 if boden.x > 0.0 else 1.0
		var drehung := deg_to_rad(float(figur.get_meta("drehung", 0.0))) * seite
		_status_beleben(e, skala)
		figur.rotation = Vector3(0.0,
			atan2(kamera_pos.x - boden.x, kamera_pos.z - boden.z) + drehung + (1.0 - rest) * 6.0,
			-ph.rotation * 1.4)
	var wackeln := Vector2.ZERO
	if _stoss > 0.0:
		_stoss = maxf(0.0, _stoss - delta)
		wackeln = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _stoss * 0.35
	_ruck *= exp(-delta * 22.0)
	_kamera.h_offset = wackeln.x + _ruck.x
	_kamera.v_offset = wackeln.y + _ruck.y
	# Fackeln: im Bosskampf heruntergeflackert (Faktor < 1, unruhiger).
	var unruhe := 0.12 + 0.3 * (1.0 - clampf(_fackel_faktor, 0.0, 1.0))
	for i in _fackeln.size():
		var licht: OmniLight3D = _fackeln[i].get_meta("licht")
		licht.light_energy = 0.55 * Stil3D.PUNKTLICHT_AUSGLEICH * _fackel_faktor \
			* (1.0 - unruhe + unruhe * sin(_zeit * 13.0 + i) * sin(_zeit * 7.3 + i * 2.0))
	_boss_spot_folgen(delta)


## Der rote Boss-Spot folgt der Boss-Figur (sie steht jedes Bild unter ihrem
## UI-Platz); fällt der Boss, erlischt er.
func _boss_spot_folgen(delta: float) -> void:
	if _boss_schluessel == null or _halle.is_empty():
		return
	var spot: SpotLight3D = _halle["boss_spot"]
	if not _eintraege.has(_boss_schluessel):
		spot.light_energy = 0.0
		return
	var e: Dictionary = _eintraege[_boss_schluessel]
	var figur: Node3D = e["fig"]
	if float(e["tot"]) > 0.0 or not figur.visible:
		spot.light_energy = maxf(0.0, spot.light_energy - delta * 8.0)
		return
	spot.look_at_from_position(figur.global_position + Vector3(0, 9.0, 3.5),
		figur.global_position + Vector3(0, 0.5, 0))
