class_name KampfHalle
extends RefCounted
## Kampfhalle (STIL-3D.md 7c, Grafik-Paket 3): Rundhalle im Biom-Stil hinter
## der Kampf-UI — Hallen-Säulen der Biom-Kulisse auf einem HINTEREN Bogen,
## Fackeln an Haltern, dahinter ein Ring großer Biom-Stücke, Boden aus
## radialen Platten mit der Steinbemalung des Dungeons, glimmende Fugen und
## ein Runenkreis in der Mitte, Sternen-Nebel statt schwarzer Leere.
## Licht: Filmic (Stil3D.umgebung), Sonne + Spot als Lichtinsel auf der
## Arena, Fackeln, ein roter Boss-Spot und zwei Effekt-Lichter — zusammen
## höchstens 8 (Compatibility: 8 Punkt-/Spotlichter je Objekt).
##
## Reine Funktionen (Stellen, Stimmung, Licht-Budget) brauchen keine
## Autoloads und sind headless testbar (grafik_selftest.gd). Die Bühne
## (KampfBuehne3D) baut die Halle über bauen() und tweent die Stimmung.

## Mitte des Kampfkreises (dort stehen die Gegner-Figuren).
const MITTE := Vector3(0, 0, -2.6)
const SAEULEN_RADIUS := 9.0
## Nur ein hinterer Bogen: vorn läge eine Säule hinter dem Befehlsmenü bzw.
## außerhalb des Bilds (alle Säulen liegen bei z < -4).
const SAEULEN_WINKEL := [-76.0, -50.0, -25.0, 0.0, 25.0, 50.0, 76.0]
const SAEULEN_HOEHE := 4.4
## Säulen mit Fackel (Index in SAEULEN_WINKEL) — vier warme Lichtpunkte.
const FACKEL_SAEULEN := [1, 2, 4, 5]
const FACKEL_HOEHE := 2.1
const FACKEL_REICHWEITE := 5.0
## Kampfkreis: Ringe aus gefasten Platten, der äußerste als Randstein.
const PLATTEN_RINGE := 7
const PLATTE := 0.88
## Biom-Deko am Arenarand (links/rechts, außerhalb der Gegnerreihe).
const DEKO_STELLEN := [Vector3(-6.6, 0, -4.2), Vector3(7.0, 0, -3.6), Vector3(-8.0, 0, -0.8),
	Vector3(8.2, 0, -1.2), Vector3(-5.6, 0, -7.4), Vector3(5.8, 0, -7.2)]
## Streu-Deko der Karten-Variante (BiomStil "streu"): Stellen am Arenarand,
## je nach streu_anteil die ersten N davon (außerhalb der Gegnerreihe).
const STREU_STELLEN := [Vector3(-7.4, 0, -2.6), Vector3(7.6, 0, -2.4), Vector3(-6.0, 0, -6.0),
	Vector3(6.4, 0, -5.6), Vector3(-8.6, 0, -4.6), Vector3(8.8, 0, -4.2), Vector3(-3.6, 0, -8.6),
	Vector3(3.8, 0, -8.4)]
## Höchstens so viele gebackene Hallen-Varianten im Speicher.
const BACK_CACHE_MAX := 12
## Kulissen-Ring hinter den Säulen.
const KULISSE_ANZAHL := 24
const KULISSE_RADIUS := Vector2(11.4, 14.3)
## Lichter je Objekt (der Boden ist EIN Objekt, alle treffen ihn).
const LICHT_BUDGET := {"spot": 1, "fackeln": 4, "boss_spot": 1, "effekte": 2}
const MAX_LICHTER := 8
## Render-Ebenen (Bitmasken): die Bühne legt alle Figurteile auf FIGUR_EBENE.
## Der rote Boss-Spot trifft nur die Halle (Boden rot, der Boss behält seine
## Eigenfarben), das rote Randlicht nur die Figuren — so zählt jedes der
## beiden nur für eine Seite, und Boden wie Figur bleiben bei 8 Lichtern.
const HALLE_EBENE := 1
const FIGUR_EBENE := 2
const FIGUR_LICHT_BUDGET := {"spot": 1, "fackeln": 4, "boss_rand": 1, "effekte": 2}
## Untergrenze der Umgebungshelligkeit: auch im Bosskampf versinkt nichts
## im Dunkeln (kein Fog of War, Gegner und Ziele bleiben lesbar).
const MIN_UMGEBUNG := 0.36
## Boss-Stimmung: rot-violettes Umgebungslicht, roter Spot, rotes Siegel.
const BOSS_UMGEBUNG := Color(0.6, 0.32, 0.44)
const BOSS_SPOT := Color(1.0, 0.24, 0.16)
const BOSS_RAND := Color(1.0, 0.2, 0.12)
const SPOT_FARBE := Color(1.0, 0.9, 0.74)

## Gebackene Säulen/Kulisse je Biom (Meshes), damit der nächste Kampf nicht
## neu backt.
static var _gebacken: Dictionary = {}


static func licht_summe(budget: Dictionary = LICHT_BUDGET) -> int:
	var summe := 0
	for v in budget.values():
		summe += int(v)
	return summe


## Fußpunkte der Hallen-Säulen auf dem hinteren Bogen.
static func saeulen_stellen() -> Array[Vector3]:
	var stellen: Array[Vector3] = []
	for grad: float in SAEULEN_WINKEL:
		var w := deg_to_rad(grad)
		stellen.append(MITTE + Vector3(sin(w), 0.0, -cos(w)) * SAEULEN_RADIUS)
	return stellen


## Drehung (um y), mit der ein Teil an stelle zur Hallenmitte blickt (+z).
static func zur_mitte(stelle: Vector3) -> float:
	return atan2(MITTE.x - stelle.x, MITTE.z - stelle.z)


## Stellen der Kulissen-Stücke: Ring hinter den Säulen, per Hash gestreut
## (immer gleich), Größe s skaliert die Grundkörper (nicht den Knoten).
static func kulisse_stellen() -> Array[Dictionary]:
	var stellen: Array[Dictionary] = []
	for i in KULISSE_ANZAHL:
		var h := absi(hash(Vector2i(i, 71)))
		var grad := -98.0 + 196.0 * float(i) / float(KULISSE_ANZAHL - 1) + float(h % 7) - 3.0
		var w := deg_to_rad(grad)
		var r := lerpf(KULISSE_RADIUS.x, KULISSE_RADIUS.y, float((h / 7) % 31) / 30.0)
		var pos := MITTE + Vector3(sin(w), 0.0, -cos(w)) * r
		# Zur Mitte gewandt (Gruft-Türen, Mauerreste), leicht verdreht.
		stellen.append({"pos": pos, "dreh": zur_mitte(pos) + float((h / 217) % 100) / 100.0 - 0.5,
			"s": 1.7 + float((h / 13) % 9) * 0.15, "nr": i})
	return stellen


## Licht-Stimmung der Halle. phase 0 = normaler Kampf, 1 = Boss-Auftritt,
## 2/3 = Boss-Phasen (jede röter). Die Halle dunkelt im Bosskampf ab
## (Sonne, Spot, Fackeln), die Umgebung bleibt aber über MIN_UMGEBUNG.
static func stimmung(stil: Dictionary, phase: int) -> Dictionary:
	var ambient: Color = stil.get("ambient", Color(0.48, 0.47, 0.66))
	var ambient_e := float(stil.get("ambient_energie", 0.5))
	var sonne: Color = stil.get("licht", Color(1.0, 0.92, 0.8))
	var sonne_e := float(stil.get("licht_energie", 0.8))
	var fuge: Color = stil.get("fuge", Color(0.6, 0.9, 0.4))
	var werte := {
		"ambient": ambient, "ambient_energie": maxf(MIN_UMGEBUNG, ambient_e * 0.9),
		"sonne": sonne, "sonne_energie": sonne_e * 0.5,
		"spot": SPOT_FARBE, "spot_energie": 2.9, "fackeln": 1.0,
		"siegel": fuge, "siegel_staerke": 0.14, "schimmer": fuge, "boss_spot": 0.0, "boss_rand": 0.0,
	}
	if phase <= 0:
		return werte
	var stufe := clampf(float(phase - 1) / 2.0, 0.0, 1.0)  # 0 Auftritt … 1 Phase 3
	werte["ambient"] = ambient.lerp(BOSS_UMGEBUNG, 0.4 + 0.2 * stufe)
	werte["ambient_energie"] = maxf(MIN_UMGEBUNG, ambient_e * 0.74)
	werte["sonne"] = sonne.lerp(Color(1.0, 0.55, 0.5), 0.5 + 0.3 * stufe)
	werte["sonne_energie"] = sonne_e * (0.22 - 0.05 * stufe)
	# Der Spot von oben ist das Führungslicht der Figuren: nur leicht wärmer,
	# nicht rosa — sonst färbt er den Boss um (Troll gelblich, Golem rosa).
	# Das Rot kommt vom Boss-Spot (nur Halle) und vom Randlicht (nur Figuren).
	werte["spot"] = SPOT_FARBE.lerp(Color(1.0, 0.78, 0.7), 0.25 + 0.25 * stufe)
	werte["spot_energie"] = 1.6 - 0.2 * stufe
	werte["fackeln"] = 0.42 - 0.12 * stufe
	werte["siegel"] = Color(1.0, 0.3, 0.24).lerp(Color(1.0, 0.16, 0.3), stufe)
	# Siegel gedämpft (Review): es liegt genau unter Namen und Werten der
	# Gegner. Der Boss-Spot färbt nur noch den Boden um den Boss rot (Ebene
	# HALLE_EBENE); auf der Figur liegt ein rotes Randlicht von hinten — der
	# Boss bleibt in seinen Eigenfarben lesbar (ein grauer Golem bleibt Stein).
	werte["siegel_staerke"] = 0.4 + 0.15 * stufe
	werte["schimmer"] = Color(1.0, 0.3, 0.3)
	werte["boss_spot"] = 2.2 + 0.8 * stufe
	werte["boss_rand"] = 4.2 + 0.8 * stufe
	return werte


## Baut Umgebung, Licht, Boden, Säulen, Fackeln, Kulisse, Untergrund und
## Partikel unter eltern. Liefert die Teile, die die Bühne später ändert:
## env, sonne, spot, boss_spot, fackeln, siegel (Material), untergrund
## (Material).
static func bauen(eltern: Node3D, stil: Dictionary) -> Dictionary:
	var teile := {}
	var start := stimmung(stil, 0)
	# Umgebung: Filmic wie im Dungeon, Hintergrund = Biom-Tiefe (linear!).
	var welt := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = (stil["tief"] as Color).srgb_to_linear()
	Stil3D.umgebung(env, start["ambient"], start["ambient_energie"])
	env.tonemap_exposure *= float(stil.get("belichtung", 1.0))
	welt.environment = env
	eltern.add_child(welt)
	teile["env"] = env
	var sonne := DirectionalLight3D.new()
	sonne.rotation_degrees = Vector3(-42, -28, 0)
	sonne.light_color = start["sonne"]
	sonne.light_energy = start["sonne_energie"]
	sonne.shadow_enabled = true
	sonne.shadow_blur = 1.5
	sonne.directional_shadow_max_distance = 30.0
	eltern.add_child(sonne)
	teile["sonne"] = sonne
	# Lichtinsel: Spot von oben auf den Kampfkreis (ohne Schatten — Spot-
	# Schatten streifen in Compatibility).
	var spot := SpotLight3D.new()
	spot.light_color = start["spot"]
	spot.light_energy = start["spot_energie"]
	spot.spot_range = 22.0
	spot.spot_angle = 31.0
	spot.spot_angle_attenuation = 1.4
	eltern.add_child(spot)
	spot.look_at_from_position(MITTE + Vector3(0, 11.0, 2.2), MITTE + Vector3(0, 0, 0.5))
	teile["spot"] = spot
	# Roter Boss-Spot: von Anfang an da (Energie 0), damit der Boss-Auftritt
	# keine neue Shader-Variante übersetzen muss; die Bühne richtet ihn aus.
	var boss_spot := SpotLight3D.new()
	boss_spot.light_color = BOSS_SPOT
	boss_spot.light_energy = 0.0
	boss_spot.spot_range = 16.0
	boss_spot.spot_angle = 13.0
	boss_spot.spot_angle_attenuation = 0.8
	eltern.add_child(boss_spot)
	boss_spot.look_at_from_position(MITTE + Vector3(0, 9.0, 3.5), MITTE)
	boss_spot.light_cull_mask = HALLE_EBENE
	teile["boss_spot"] = boss_spot
	# Rotes Randlicht von hinten, nur auf Figuren (die Bühne richtet es auf
	# den Boss): Kanten und Rücken glühen rot, die Vorderseite bleibt im
	# neutralen Licht.
	var boss_rand := SpotLight3D.new()
	boss_rand.light_color = BOSS_RAND
	boss_rand.light_energy = 0.0
	boss_rand.spot_range = 8.0
	boss_rand.spot_angle = 34.0
	boss_rand.spot_angle_attenuation = 0.6
	boss_rand.light_cull_mask = FIGUR_EBENE
	eltern.add_child(boss_rand)
	boss_rand.look_at_from_position(MITTE + Vector3(1.8, 2.3, -2.6), MITTE + Vector3(0, 0.8, 0))
	teile["boss_rand"] = boss_rand

	_boden(eltern, stil, teile)
	var gebacken := _backen(stil)
	eltern.add_child(Bausatz.knoten_aus("Hallensaeulen", gebacken["saeulen"][0], gebacken["saeulen"][1]))
	eltern.add_child(Bausatz.knoten_aus("Hallenkulisse", gebacken["kulisse"][0], gebacken["kulisse"][1]))
	teile["fackeln"] = _fackeln(eltern, stil)

	# Untergrund: Sternen-Nebel in Biomfarbe unter und hinter der Halle.
	var ebene := PlaneMesh.new()
	ebene.size = Vector2(150, 150)
	var nebel := MeshInstance3D.new()
	nebel.mesh = ebene
	var untergrund := WeltMaterial.material("untergrund", {"tief": stil["tief"], "nebel": stil["nebel"],
		"schimmer": stil["fuge"], "stern": Stil3D.farbe("stern")})
	nebel.material_override = untergrund
	nebel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nebel.position = Vector3(0, -3.0, -25.0)
	eltern.add_child(nebel)
	teile["untergrund"] = untergrund
	# Unterseite der schwebenden Scholle (dunkler Fels, zeigt sich am Horizont).
	Stil3D.teil(eltern, Stil3D.zylinder(16.0, 11.0, 2.6), (stil["tief"] as Color).lerp(stil["wand"], 0.35),
		Vector3(0, -1.6, -2.0), Vector3.ZERO, false)
	# Atmosphäre: Biom-Partikel über der Arena.
	var partikel := WeltMaterial.partikel(stil["partikel"], stil["funke"], float(stil.get("partikel_menge", 1.0)))
	partikel.position = MITTE + Vector3(0, 1.0, -1.0)
	eltern.add_child(partikel)
	return teile


## Boden: Grundscheibe mit Dungeon-Platten, Fugenscheibe (glimmt zur Mitte
## hin), radiale Platten mit Randsteinen, Runenkreis (Siegel) in der Mitte.
static func _boden(eltern: Node3D, stil: Dictionary, teile: Dictionary) -> void:
	var grund := MeshInstance3D.new()
	grund.mesh = Stil3D.zylinder(16.0, 16.0, 0.3)
	grund.material_override = WeltMaterial.material("boden", {"farbe": (stil["boden"] as Color) * 0.82,
		"moos_farbe": stil["moos"], "rune_farbe": stil["fuge"], "biom": int(stil["biom"]),
		"held_pos": Vector3(0, -50, 0), "risse": float(stil.get("risse", 0.28)),
		"bewuchs": float(stil.get("bewuchs", 0.0)), "pfuetzen": float(stil.get("pfuetzen", 0.0)),
		"pfuetze_farbe": stil.get("pfuetze_farbe", Stil3D.farbe("wasser"))})
	grund.position = Vector3(0, -0.15, -2.0)
	eltern.add_child(grund)
	var fugen := MeshInstance3D.new()
	fugen.mesh = Stil3D.zylinder(7.3, 7.3, 0.05)
	fugen.material_override = WeltMaterial.material("fuge", {"dunkel": Stil3D.farbe("fuge"),
		"farbe": (stil["fuge"] as Color) * 0.55, "held_pos": MITTE})
	fugen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fugen.position = MITTE + Vector3(0, 0.0, 0)
	eltern.add_child(fugen)
	var lagen: Array[Transform3D] = []
	var farben: Array[Color] = []
	var boden: Color = stil["boden"]
	var rand_farbe: Color = (stil["deckel"] as Color).lerp(Stil3D.farbe("stein_hell"), 0.35)
	for ring in PLATTEN_RINGE + 1:
		var anzahl := 1 if ring == 0 else roundi(TAU * ring)
		for i in anzahl:
			var winkel := TAU * i / anzahl + ring * 0.41
			var pos := MITTE + Vector3(cos(winkel), 0, sin(winkel)) * ring * 0.98
			var rand := ring == PLATTEN_RINGE
			var h := absi(hash(Vector2i(ring, i)))
			pos.y = 0.06 if rand else 0.03 + float(h % 4) * 0.005
			lagen.append(Transform3D(Basis(Vector3.UP, -winkel), pos))
			var hell := 0.86 + float(h % 9) * 0.02
			farben.append((rand_farbe if rand else boden * (0.95 if ring % 2 else 1.0)) * hell)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = WeltMaterial.fasen_box(Vector3(PLATTE, 0.14, PLATTE), 0.035)
	mm.instance_count = lagen.size()
	for i in lagen.size():
		mm.set_instance_transform(i, lagen[i])
		mm.set_instance_color(i, farben[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = WeltMaterial.material("arena", {"moos_farbe": stil["moos"],
		"biom": int(stil["biom"]), "mitte": MITTE, "radius": PLATTEN_RINGE + 0.4,
		"bewuchs": float(stil.get("bewuchs", 0.0)), "pfuetzen": float(stil.get("pfuetzen", 0.0)),
		"pfuetze_farbe": stil.get("pfuetze_farbe", Stil3D.farbe("wasser"))})
	eltern.add_child(mmi)
	var siegel := WeltMaterial.bodenbild("siegel", 4.8, {"farbe": stil["fuge"], "staerke": 0.14, "zacken": 5.0})
	siegel.position = MITTE + Vector3(0, 0.115, 0)
	eltern.add_child(siegel)
	teile["siegel"] = siegel.material_override


## Säulen und Kulisse je Biom-Variante einmal backen (Meshes
## zwischengespeichert; Schlüssel = alles, was in die Meshes eingeht).
static func _backen(stil: Dictionary) -> Dictionary:
	var schluessel := hash([int(stil.get("biom", 0)), stil.get("wand"), stil.get("deckel"), stil.get("kulisse"),
		stil.get("streu", []), snappedf(float(stil.get("streu_anteil", 0.0)), 0.001)])
	if _gebacken.has(schluessel):
		return _gebacken[schluessel]
	if _gebacken.size() >= BACK_CACHE_MAX:
		_gebacken.clear()
	var saeule := BiomKulisse.saeule_bausatz(stil, SAEULEN_HOEHE)
	var saeulen := Bausatz.new()
	for stelle in saeulen_stellen():
		saeulen.bausatz(saeule, Transform3D(Basis(Vector3.UP, zur_mitte(stelle)), stelle))
	var kulisse := BiomKulisse.hallen_kulisse(stil, kulisse_stellen())
	# Biom-Deko am Arenarand (Varianten wie im Dungeon).
	var arten: Array = stil.get("deco", [])
	var varianten: Dictionary = (stil.get("kulisse", {}) as Dictionary).get("deko_varianten", {})
	for i in DEKO_STELLEN.size() if not arten.is_empty() else 0:
		var liste: Array = varianten.get(arten[i % arten.size()], [])
		if liste.is_empty():
			continue
		var deko := BiomKulisse.deko(String(liste[i % liste.size()]), stil)
		kulisse.bausatz(deko, Transform3D(Basis(Vector3.UP, float(i) * 1.7).scaled(Vector3.ONE * 1.35),
			DEKO_STELLEN[i]))
	var streu: Array = stil.get("streu", [])
	var anzahl := mini(STREU_STELLEN.size(), roundi(float(stil.get("streu_anteil", 0.0)) * 60.0))
	for i in anzahl if not streu.is_empty() else 0:
		var stueck := BiomKulisse.deko(String(streu[i % streu.size()]), stil)
		var stelle: Vector3 = STREU_STELLEN[i]
		kulisse.bausatz(stueck, Transform3D(Basis(Vector3.UP, zur_mitte(stelle)).scaled(Vector3.ONE * 1.3),
			stelle))
	var fertig := {"saeulen": [saeulen.mesh(), saeulen.huelle()], "kulisse": [kulisse.mesh(), kulisse.huelle()]}
	_gebacken[schluessel] = fertig
	return fertig


## Fackeln an Haltern vorn an den Säulen, zur Mitte gewandt (je ein Licht).
static func _fackeln(eltern: Node3D, stil: Dictionary) -> Array[Node3D]:
	var liste: Array[Node3D] = []
	var stellen := saeulen_stellen()
	var art: String = (stil.get("kulisse", {}) as Dictionary).get("saeule", "saeule")
	var abstand := float(BiomKulisse.SAEULE_RADIUS.get(art, 0.45)) + 0.1
	for nr: int in FACKEL_SAEULEN:
		var stelle: Vector3 = stellen[nr]
		var richtung := (MITTE - stelle).normalized()
		var f := FigurenBau.fackel(true, true)
		eltern.add_child(f)
		f.position = stelle + richtung * abstand + Vector3(0, FACKEL_HOEHE, 0)
		f.rotation.y = zur_mitte(stelle)
		(f.get_meta("licht") as OmniLight3D).omni_range = FACKEL_REICHWEITE
		liste.append(f)
	return liste
