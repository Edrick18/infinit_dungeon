class_name StadtKulisse
extends MenueKulisse
## Begehbare Stadt (Paket 6a): derselbe schwebende Spielbrett-Stil wie das
## Lager-Diorama des Hauptmenüs (Sternen-Nebel, Glühwürmchen, Schleier,
## Vignette — alles aus MenueKulisse geerbt), nur größer: ein gepflasterter
## Platz mit Brunnen, drei erkennbar verschiedenen Gebäuden und einem Steg
## als Ausgang. Der erste Held der Party läuft darauf; die Kamera folgt ihm
## schräg von vorn (Blick nach -Z: „W“ heißt nach oben im Bild).
##
## Nur Darstellung — Laufen, Kollision und Türen regelt StadtSzene über
## ORTE und held_pos. Anders als die Menü-Kulisse rendert die Stadt jedes
## Bild (sie wird gesteuert, nicht nur angeschaut).

## Orte am Platz: Mitte (x, z), Drehung um Y in Grad (die Front zeigt nach
## lokal +Z), halbe Grundfläche (x, z) und ob sie den Weg versperren.
const ORTE := {
	&"taverne": {"pos": Vector2(0.0, -4.6), "dreh": 0.0, "halb": Vector2(2.35, 1.65), "fest": true},
	&"haendler": {"pos": Vector2(-4.6, -1.2), "dreh": 60.0, "halb": Vector2(2.3, 1.15), "fest": true},
	&"schmiede": {"pos": Vector2(4.6, -1.2), "dreh": -60.0, "halb": Vector2(1.85, 1.5), "fest": true},
	&"ausgang": {"pos": Vector2(0.0, 7.6), "dreh": 180.0, "halb": Vector2(0.9, 0.3), "fest": false},
}
## Abstand des Türpunkts vor der Front.
const TUER_ABSTAND := 0.8
const BRUNNEN := Vector2(0.0, 1.4)
const BRUNNEN_RADIUS := 1.0
const PLATZ_RADIUS := 8.3
const STADT_KAMERA := Vector3(0.0, 6.4, 8.8)   ## Kamera relativ zum Helden
const STADT_BLICK := Vector3(0.0, 0.8, -0.6)   ## Blickpunkt relativ zum Helden

## Bodenposition des Helden (x, z) — setzt StadtSzene jedes Bild.
var held_pos := Vector2.ZERO
var _held: Node3D
var _letzte := Vector2.ZERO
var _hopser := 0.0
var _blick := Vector3.ZERO


func _init() -> void:
	super(&"stadt", false)


## Türpunkt eines Ortes: mittig vor der Front.
static func tuer(id: StringName) -> Vector2:
	var o: Dictionary = ORTE[id]
	return (o["pos"] as Vector2) + front(id) * ((o["halb"] as Vector2).y + TUER_ABSTAND)


## Blickrichtung der Front (x, z).
static func front(id: StringName) -> Vector2:
	var winkel := deg_to_rad(float(ORTE[id]["dreh"]))
	return Vector2(sin(winkel), cos(winkel))


## Held sofort an eine Stelle setzen (Betreten der Stadt), Blick nach `blick`.
func springen(pos: Vector2, blick: Vector2) -> void:
	held_pos = pos
	_letzte = pos
	if _held != null:
		_held.position = Vector3(pos.x, 0.0, pos.y)
		_held.rotation.y = atan2(blick.x, blick.y)
	_blick = Vector3(pos.x, 0.0, pos.y)
	_kamera_folgen(1.0)


## Bodenpunkt (x, z) unter einem Bildschirmpunkt — null, wenn der Strahl
## den Boden nicht trifft.
func boden_punkt(bildschirm: Vector2) -> Variant:
	if _kamera == null or not is_inside_tree():
		return null
	var start := _kamera.project_ray_origin(bildschirm)
	var richtung := _kamera.project_ray_normal(bildschirm)
	if richtung.y > -0.01:
		return null
	var t := -start.y / richtung.y
	var treffer := start + richtung * t
	return Vector2(treffer.x, treffer.z)


func _szene_bauen() -> void:
	var welt := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Stil3D.farbe("hoehle_tief").srgb_to_linear()
	Stil3D.umgebung(env, Stil3D.farbe("stern").lerp(Stil3D.farbe("lila"), 0.35), 0.4)
	welt.environment = env
	_vp.add_child(welt)
	_nebel()
	var mond := DirectionalLight3D.new()
	mond.rotation_degrees = Vector3(-50, 35, 0)
	mond.light_color = Stil3D.farbe("stern")
	mond.light_energy = 0.34
	mond.shadow_enabled = true
	mond.directional_shadow_max_distance = 30.0
	_vp.add_child(mond)
	var aufheller := DirectionalLight3D.new()
	aufheller.rotation_degrees = Vector3(-25, 0, 0)
	aufheller.light_color = Stil3D.farbe("laterne")
	aufheller.light_energy = 0.28
	_vp.add_child(aufheller)

	var w := Node3D.new()
	_vp.add_child(w)
	_platz(w)
	_brunnen(w)
	_taverne_haus(_ort_knoten(w, &"taverne"))
	_haendler_stand(_ort_knoten(w, &"haendler"))
	_schmiede_haus(_ort_knoten(w, &"schmiede"))
	_ausgang(_ort_knoten(w, &"ausgang"))

	var helden: Array = GameState.party
	_held = FigurenBau.held_aus(helden[0]) if not helden.is_empty() else FigurenBau.held()
	w.add_child(_held)

	_kamera = Camera3D.new()
	_kamera.fov = 38.0
	_kamera.far = 260.0
	_vp.add_child(_kamera)
	springen(tuer(&"ausgang"), Vector2(0, -1))
	# Gesteuerte Szene: jedes Bild rendern statt gedrosselt.
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Knoten eines Ortes: an seiner Mitte, Front gedreht.
func _ort_knoten(w: Node3D, id: StringName) -> Node3D:
	var o: Dictionary = ORTE[id]
	var n := Node3D.new()
	n.name = String(id)
	var pos: Vector2 = o["pos"]
	n.position = Vector3(pos.x, 0.0, pos.y)
	n.rotation_degrees.y = float(o["dreh"])
	w.add_child(n)
	return n


## Flackerndes Punktlicht (ohne Schatten — die Esse hat den einzigen).
func _licht(eltern: Node3D, pos: Vector3, energie: float, reichweite: float) -> OmniLight3D:
	var licht := OmniLight3D.new()
	licht.light_color = Stil3D.farbe("laterne")
	licht.light_energy = energie
	licht.omni_range = reichweite
	licht.omni_attenuation = Stil3D.PUNKTLICHT_ABFALL
	licht.position = pos
	licht.set_meta("basis", energie)
	eltern.add_child(licht)
	_flackern.append(licht)
	return licht


## Runder Stadtplatz: Pflaster in Ringen wie die Lager-Insel, Poller am Rand
## (Lücke im Süden für den Steg), etwas Kleinkram außerhalb der Laufwege.
func _platz(w: Node3D) -> void:
	Stil3D.teil(w, Stil3D.zylinder(PLATZ_RADIUS, PLATZ_RADIUS - 0.4, 0.7), Stil3D.farbe("fuge"), Vector3(0, -0.42, 0))
	Stil3D.teil(w, Stil3D.zylinder(PLATZ_RADIUS - 0.5, 2.6, 3.2), Stil3D.farbe("hoehle_tief").lerp(
		Stil3D.farbe("stein_dunkel"), 0.4), Vector3(0, -2.35, 0), Vector3.ZERO, false)
	for ring in 9:
		var anzahl := 1 if ring == 0 else ring * 6
		for i in anzahl:
			var winkel := TAU * i / anzahl + ring * 0.37
			var r := ring * 0.95
			var hell := 0.82 + float((ring * 5 + i * 3) % 7) * 0.025
			Stil3D.teil(w, Stil3D.box(0.92, 0.14, 0.92), Stil3D.farbe("ruinen_boden") * hell * 0.9,
				Vector3(cos(winkel) * r, -0.07, sin(winkel) * r), Vector3(0, -rad_to_deg(winkel), 0), false)
	for i in 24:
		var winkel := TAU * i / 24.0
		if absf(wrapf(winkel - PI * 0.5, -PI, PI)) < 0.35:
			continue  # Süden: Steg zum Ausgang
		Stil3D.teil(w, Stil3D.box(0.3, 0.5, 0.3), Stil3D.farbe("stein_dunkel"),
			Vector3(cos(winkel) * (PLATZ_RADIUS - 0.3), 0.25, sin(winkel) * (PLATZ_RADIUS - 0.3)),
			Vector3(0, -rad_to_deg(winkel), 0))
	_deko(w, [["felsbrocken", Vector3(-7.4, 0, 2.6)], ["pilz", Vector3(7.3, 0, 2.9)],
		["fass", Vector3(-3.0, 0, -6.9)], ["felsbrocken", Vector3(3.4, 0, -6.8)],
		["pilz", Vector3(-5.6, 0, 5.0)], ["fass", Vector3(5.8, 0, 4.6)]])


## Brunnen in der Platzmitte: Steinring mit Wasser, Holzgestell mit Dach.
func _brunnen(w: Node3D) -> void:
	var n := Node3D.new()
	n.position = Vector3(BRUNNEN.x, 0, BRUNNEN.y)
	w.add_child(n)
	Stil3D.teil(n, Stil3D.zylinder(0.95, 1.0, 0.6), Stil3D.farbe("stein"), Vector3(0, 0.3, 0))
	Stil3D.teil(n, Stil3D.zylinder(0.98, 0.98, 0.08), Stil3D.farbe("stein_hell"), Vector3(0, 0.62, 0))
	Stil3D.teil(n, Stil3D.zylinder(0.78, 0.78, 0.04), Stil3D.farbe("wasser"), Vector3(0, 0.55, 0),
		Vector3.ZERO, false, Stil3D.farbe("wasser") * 0.25)
	for x in [-0.8, 0.8]:
		Stil3D.teil(n, Stil3D.box(0.12, 1.5, 0.12), Stil3D.farbe("holz"), Vector3(x, 1.15, 0))
	Stil3D.teil(n, Stil3D.prisma(0.9, 0.45, 2.0), Stil3D.farbe("braun"), Vector3(0, 2.1, 0), Vector3(0, 90, 0))
	Stil3D.teil(n, Stil3D.zylinder(0.05, 0.05, 1.6), Stil3D.farbe("holz_hell"), Vector3(0, 1.6, 0), Vector3(0, 0, 90))
	Stil3D.teil(n, Stil3D.zylinder(0.13, 0.11, 0.2), Stil3D.farbe("holz_hell"), Vector3(0.25, 1.2, 0))
	Stil3D.teil(n, Stil3D.zylinder(0.14, 0.14, 0.03), Stil3D.farbe("eisen"), Vector3(0.25, 1.28, 0),
		Vector3.ZERO, false)


## Taverne: Fachwerkhaus mit rotem Satteldach, warm leuchtenden Fenstern,
## Krug-Schild über der Tür, Fackeln, Fässern und einer Bank.
func _taverne_haus(t: Node3D) -> void:
	var holz := Stil3D.farbe("holz")
	var balken := holz * 0.7
	var putz := Stil3D.farbe("weiss") * 0.84
	Stil3D.teil(t, Stil3D.box(4.8, 0.3, 3.4), Stil3D.farbe("stein_dunkel"), Vector3(0, 0.15, 0))
	Stil3D.teil(t, Stil3D.box(4.5, 1.8, 3.1), putz, Vector3(0, 1.2, 0))
	# Fachwerk der Front: Ständer, Riegel, Streben.
	for x in [-2.2, -0.62, 0.62, 2.2]:
		Stil3D.teil(t, Stil3D.box(0.14, 1.8, 0.08), balken, Vector3(x, 1.2, 1.57))
	for y in [0.36, 2.04]:
		Stil3D.teil(t, Stil3D.box(4.5, 0.14, 0.08), balken, Vector3(0, y, 1.58))
	for seite in [-1.0, 1.0]:
		Stil3D.teil(t, Stil3D.box(0.1, 1.15, 0.06), balken, Vector3(1.85 * seite, 1.2, 1.59), Vector3(0, 0, 38 * seite))
		Stil3D.teil(t, Stil3D.box(0.08, 1.8, 3.1), balken, Vector3(2.26 * seite, 1.2, 0))
	Stil3D.teil(t, Stil3D.prisma(3.7, 1.5, 5.1), Stil3D.farbe("umhang") * 0.75, Vector3(0, 2.86, 0), Vector3(0, 90, 0))
	Stil3D.teil(t, Stil3D.box(0.45, 1.1, 0.45), Stil3D.farbe("stein"), Vector3(1.4, 3.3, -0.6))
	# Tür, Fenster, Schild
	Stil3D.teil(t, Stil3D.box(0.9, 1.35, 0.06), holz * 0.55, Vector3(0, 0.98, 1.58))
	Stil3D.teil(t, Stil3D.kugel(0.04), Stil3D.farbe("messing"), Vector3(0.3, 0.95, 1.62))
	for x in [-1.42, 1.42]:
		Stil3D.teil(t, Stil3D.box(0.72, 0.56, 0.05), Stil3D.farbe("glut"), Vector3(x, 1.22, 1.57),
			Vector3.ZERO, false, Stil3D.farbe("flamme") * 0.9)
		Stil3D.teil(t, Stil3D.box(0.05, 0.56, 0.07), balken, Vector3(x, 1.22, 1.59), Vector3.ZERO, false)
		Stil3D.teil(t, Stil3D.box(0.72, 0.05, 0.07), balken, Vector3(x, 1.22, 1.59), Vector3.ZERO, false)
	Stil3D.teil(t, Stil3D.box(1.3, 0.42, 0.06), Stil3D.farbe("holz_hell"), Vector3(0, 2.3, 1.62))
	Stil3D.teil(t, Stil3D.zylinder(0.09, 0.08, 0.22), Stil3D.farbe("messing"), Vector3(-0.05, 2.3, 1.72))
	Stil3D.teil(t, Stil3D.box(0.05, 0.13, 0.04), Stil3D.farbe("messing"), Vector3(0.08, 2.3, 1.72), Vector3.ZERO, false)
	Stil3D.teil(t, Stil3D.zylinder(0.075, 0.075, 0.03), Stil3D.farbe("weiss"), Vector3(-0.05, 2.42, 1.72),
		Vector3.ZERO, false)
	for seite in [-1.0, 1.0]:
		var fackel := FigurenBau.fackel(true, true)
		t.add_child(fackel)
		fackel.position = Vector3(0.82 * seite, 1.55, 1.66)
		var licht: OmniLight3D = fackel.get_meta("licht")
		licht.light_energy = 0.6
		licht.set_meta("basis", 0.6)
		_flackern.append(licht)
	# Bank und Fässer vor dem Haus
	Stil3D.teil(t, Stil3D.box(1.2, 0.08, 0.34), Stil3D.farbe("holz_hell"), Vector3(1.55, 0.42, 1.95))
	for x in [1.05, 2.05]:
		Stil3D.teil(t, Stil3D.box(0.08, 0.4, 0.3), holz, Vector3(x, 0.2, 1.95))
	_deko(t, [["fass", Vector3(-1.75, 0, 1.95)], ["fass", Vector3(-2.15, 0, 1.75)], ["fass", Vector3(-1.95, 0.4, 1.85)]])


## Händler & Alchemist: offener Marktstand mit gestreifter Markise,
## Trankregal, Tresen mit Münzen, Truhe, Kisten und einem dampfenden Kessel.
func _haendler_stand(h: Node3D) -> void:
	var holz := Stil3D.farbe("holz")
	Stil3D.teil(h, Stil3D.box(3.3, 0.12, 2.3), holz * 0.8, Vector3(0, 0.06, 0))
	for x in [-1.5, 1.5]:
		Stil3D.teil(h, Stil3D.zylinder(0.07, 0.08, 2.0), holz, Vector3(x, 1.0, 1.0))
		Stil3D.teil(h, Stil3D.zylinder(0.07, 0.08, 2.5), holz, Vector3(x, 1.25, -1.0))
	for i in 6:
		var farbe: Color = Stil3D.farbe("umhang") if i % 2 == 0 else Stil3D.farbe("weiss") * 0.92
		Stil3D.teil(h, Stil3D.box(0.56, 0.06, 2.45), farbe, Vector3(-1.4 + i * 0.56, 2.28, 0.05), Vector3(11, 0, 0))
	for i in 6:
		Stil3D.teil(h, Stil3D.prisma(0.5, 0.2, 0.04), Stil3D.farbe("umhang") if i % 2 == 0 else Stil3D.farbe("weiss") * 0.92,
			Vector3(-1.4 + i * 0.56, 1.92, 1.27), Vector3(180, 0, 0), false)
	# Rückwand mit Trankregal (wie der Händlertresen im Menü)
	Stil3D.teil(h, Stil3D.box(3.0, 1.9, 0.12), holz * 0.75, Vector3(0, 1.05, -1.0))
	var farben := ["umhang", "schleim", "kristall", "lila", "moos", "gold", "pilz_rot"]
	for reihe in 2:
		var y := 0.95 + reihe * 0.6
		Stil3D.teil(h, Stil3D.box(3.0, 0.06, 0.35), holz, Vector3(0, y, -0.85))
		for i in 5:
			var f: Color = Stil3D.farbe(farben[(i + reihe * 3) % farben.size()])
			var p := Vector3(-1.1 + i * 0.55, y + 0.15, -0.82)
			Stil3D.teil(h, Stil3D.kugel(0.11, 0.2), f, p, Vector3.ZERO, true, f * 0.35)
			Stil3D.teil(h, Stil3D.zylinder(0.035, 0.045, 0.1), Stil3D.farbe("weiss") * 0.9, p + Vector3(0, 0.14, 0))
	# Tresen mit Münzstapeln
	Stil3D.teil(h, Stil3D.box(2.6, 0.82, 0.55), holz * 0.9, Vector3(0, 0.47, 0.72))
	Stil3D.teil(h, Stil3D.box(2.8, 0.08, 0.66), Stil3D.farbe("holz_hell"), Vector3(0, 0.92, 0.72))
	for i in 3:
		for hoehe in 3 - i:
			Stil3D.teil(h, Stil3D.zylinder(0.09, 0.09, 0.035), Stil3D.farbe("gold"),
				Vector3(-0.9 + i * 0.25, 0.98 + hoehe * 0.04, 0.75), Vector3.ZERO, false, Stil3D.farbe("gold") * 0.25)
	var truhe := FigurenBau.truhe(Stil3D.farbe("gold"))
	h.add_child(truhe)
	truhe.position = Vector3(1.85, 0, 0.55)
	truhe.rotation.y = -0.4
	Stil3D.teil(h, Stil3D.box(0.5, 0.5, 0.5), Stil3D.farbe("holz_hell"), Vector3(1.9, 0.25, -0.45), Vector3(0, 12, 0))
	# Alchemie-Kessel neben dem Stand
	Stil3D.teil(h, Stil3D.zylinder(0.34, 0.27, 0.42), Stil3D.farbe("eisen") * 0.6, Vector3(-1.95, 0.32, 0.5))
	Stil3D.teil(h, Stil3D.zylinder(0.3, 0.3, 0.04), Stil3D.farbe("schleim"), Vector3(-1.95, 0.52, 0.5),
		Vector3.ZERO, false, Stil3D.farbe("schleim") * 0.8)
	for winkel in [0.0, 2.1, 4.2]:
		Stil3D.teil(h, Stil3D.box(0.06, 0.14, 0.06), Stil3D.farbe("stein_dunkel"),
			Vector3(-1.95 + cos(winkel) * 0.22, 0.07, 0.5 + sin(winkel) * 0.22))
	var dampf := CPUParticles3D.new()
	dampf.amount = 14
	dampf.lifetime = 2.2
	dampf.mesh = Stil3D.kugel(0.05)
	dampf.material_override = Stil3D.material(Stil3D.farbe("schleim_hell"), -1, Stil3D.farbe("schleim") * 0.6)
	dampf.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dampf.emission_sphere_radius = 0.18
	dampf.direction = Vector3.UP
	dampf.spread = 12.0
	dampf.initial_velocity_min = 0.25
	dampf.initial_velocity_max = 0.45
	dampf.gravity = Vector3.ZERO
	dampf.scale_amount_min = 0.6
	dampf.scale_amount_max = 1.4
	dampf.position = Vector3(-1.95, 0.6, 0.5)
	h.add_child(dampf)
	# Laterne unter der Markise
	Stil3D.teil(h, Stil3D.kugel(0.1), Stil3D.farbe("glut"), Vector3(0, 1.85, 1.0), Vector3.ZERO, true,
		Stil3D.farbe("glut") * 1.5)
	_licht(h, Vector3(0, 1.7, 1.3), 1.1, 5.0)
	# Abholbare Belohnungen (Aufträge, Medaillen, Bestiarium): Zeichen über dem Stand.
	if GameState.abholbar_anzahl() > 0:
		var zeichen := Label3D.new()
		zeichen.name = "Abholbar"
		zeichen.text = "!"
		zeichen.font_size = 120
		zeichen.pixel_size = 0.006
		zeichen.outline_size = 24
		zeichen.modulate = Stil3D.farbe("gold")
		zeichen.outline_modulate = Stil3D.farbe("nacht")
		zeichen.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		zeichen.position = Vector3(0, 3.0, 0.2)
		h.add_child(zeichen)


## Schmiede: gedrungenes Steinhaus, vorn offen, Pultdach, rauchender
## Schornstein, glühende Esse innen, Amboss, Klingenständer und Banner.
func _schmiede_haus(s: Node3D) -> void:
	var stein := Stil3D.farbe("stein")
	var dunkel := Stil3D.farbe("stein_dunkel")
	Stil3D.teil(s, Stil3D.box(3.7, 0.2, 3.0), dunkel, Vector3(0, 0.1, 0))
	Stil3D.teil(s, Stil3D.box(3.6, 2.2, 0.35), stein, Vector3(0, 1.3, -1.3))
	for seite in [-1.0, 1.0]:
		Stil3D.teil(s, Stil3D.box(0.35, 2.2, 2.8), stein, Vector3(1.65 * seite, 1.3, -0.05))
		for stock in 3:
			Stil3D.teil(s, Stil3D.box(0.42, 0.32, 0.42), Stil3D.farbe("stein_hell"),
				Vector3(1.65 * seite, 0.45 + stock * 0.72, 1.2))
	Stil3D.teil(s, Stil3D.box(4.0, 0.16, 3.3), dunkel * 0.75, Vector3(0, 2.55, 0.05), Vector3(10, 0, 0))
	# Schornstein mit Rauch
	Stil3D.teil(s, Stil3D.zylinder(0.3, 0.38, 1.7), dunkel, Vector3(-1.1, 3.1, -1.1))
	var rauch := CPUParticles3D.new()
	rauch.amount = 16
	rauch.lifetime = 3.0
	rauch.mesh = Stil3D.kugel(0.12)
	rauch.material_override = Stil3D.material(Stil3D.farbe("stein_dunkel"))
	rauch.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	rauch.emission_sphere_radius = 0.15
	rauch.direction = Vector3.UP
	rauch.spread = 14.0
	rauch.initial_velocity_min = 0.35
	rauch.initial_velocity_max = 0.6
	rauch.gravity = Vector3(0.05, 0, 0)
	rauch.scale_amount_min = 0.7
	rauch.scale_amount_max = 1.8
	rauch.position = Vector3(-1.1, 4.0, -1.1)
	s.add_child(rauch)
	# Esse mit Glut (wie im Schmiede-Menü), Amboss davor
	Stil3D.teil(s, Stil3D.box(1.2, 0.85, 0.9), dunkel, Vector3(-0.75, 0.62, -0.65))
	Stil3D.teil(s, Stil3D.box(1.3, 0.1, 1.0), Stil3D.farbe("stein_hell"), Vector3(-0.75, 1.08, -0.65))
	Stil3D.teil(s, Stil3D.box(0.7, 0.32, 0.06), Stil3D.farbe("glut"), Vector3(-0.75, 0.6, -0.19),
		Vector3.ZERO, false, Stil3D.farbe("flamme") * 1.8)
	_feuer(s, Vector3(-0.75, 1.18, -0.65), 0.5, 2.0)
	var amboss := FigurenBau.deko("amboss")
	s.add_child(amboss)
	amboss.position = Vector3(0.45, 0.2, 0.45)
	amboss.rotation.y = 0.4
	# Klingenständer an der Rückwand
	Stil3D.teil(s, Stil3D.box(1.2, 0.08, 0.2), Stil3D.farbe("holz"), Vector3(0.75, 1.35, -1.0))
	for i in 3:
		var x := 0.35 + i * 0.4
		Stil3D.teil(s, Stil3D.box(0.08, 0.95, 0.03), Stil3D.farbe("eisen") * 1.25, Vector3(x, 1.0, -0.98), Vector3(0, 0, 6))
		Stil3D.teil(s, Stil3D.box(0.22, 0.05, 0.06), Stil3D.farbe("gold"), Vector3(x + 0.02, 1.5, -0.98))
	var banner := FigurenBau.banner(Stil3D.farbe("banner"))
	s.add_child(banner)
	banner.position = Vector3(1.65, 2.15, 1.43)
	_deko(s, [["fass", Vector3(-1.1, 0.2, 0.95)]])


## Ausgang im Süden: Holzsteg über den Rand, zwei Feuerschalen, Wegweiser.
## (Der Knoten ist um 180° gedreht: lokal -Z zeigt vom Platz weg.)
func _ausgang(a: Node3D) -> void:
	for i in 5:
		Stil3D.teil(a, Stil3D.box(1.7, 0.08, 0.5), Stil3D.farbe("holz") * (0.85 + (i % 2) * 0.1),
			Vector3(0, -0.02, -2.0 + i * 0.56))
	for x in [-0.95, 0.95]:
		Stil3D.teil(a, Stil3D.box(0.1, 0.5, 2.6), Stil3D.farbe("holz") * 0.7, Vector3(x, -0.12, -0.9))
	for x in [-1.35, 1.35]:
		var schale := FigurenBau.feuerschale()
		a.add_child(schale)
		schale.position = Vector3(x, 0, 0.3)
		_licht(a, Vector3(x, 1.2, 0.3), 0.6, 3.5)
	Stil3D.teil(a, Stil3D.zylinder(0.06, 0.06, 1.6), Stil3D.farbe("holz"), Vector3(-2.0, 0.8, 0.4))
	Stil3D.teil(a, Stil3D.box(0.9, 0.26, 0.05), Stil3D.farbe("holz_hell"), Vector3(-1.85, 1.35, 0.4))
	Stil3D.teil(a, Stil3D.prisma(0.26, 0.2, 0.05), Stil3D.farbe("holz_hell"), Vector3(-1.3, 1.35, 0.4), Vector3(0, 0, -90))


func _kamera_folgen(gewicht: float) -> void:
	var ziel := Vector3(held_pos.x, 0.0, held_pos.y)
	_blick = _blick.lerp(ziel, clampf(gewicht, 0.0, 1.0))
	var pos := _blick + STADT_KAMERA
	_kamera.transform = Transform3D(Basis.looking_at(_blick + STADT_BLICK - pos, Vector3.UP), pos)


func _process(delta: float) -> void:
	_zeit += delta
	if _held != null:
		var schritt := held_pos - _letzte
		var laeuft := schritt.length() > 0.0005
		if laeuft:
			_held.rotation.y = lerp_angle(_held.rotation.y, atan2(schritt.x, schritt.y), minf(1.0, delta * 14.0))
		_hopser = WeltBau.naechster_hopser(_hopser, laeuft, delta)
		_held.position = Vector3(held_pos.x, absf(sin(_hopser * PI)) * WeltBau.HOPSER_HOEHE, held_pos.y)
		if _held.has_meta("glieder"):  # Figuren 2.0: Gehen bzw. Idle der Glieder
			var wurzel := Gliederpuppe.beleben(_held, _zeit, -1.0, -1.0, laeuft)
			_held.rotation.x = wurzel.x
			_held.rotation.z = wurzel.z
		_letzte = held_pos
	_kamera_folgen(delta * 6.0)
	for i in _flackern.size():
		var licht := _flackern[i]
		var basis: float = licht.get_meta("basis", 0.55)
		licht.light_energy = basis * Stil3D.PUNKTLICHT_AUSGLEICH \
			* (0.86 + 0.14 * sin(_zeit * 11.0 + i * 2.1) * sin(_zeit * 6.7 + i))
