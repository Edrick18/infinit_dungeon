class_name FigurenBau
extends RefCounted
## Baut Monster, Helden und Objekte aus Stil3D-Grundkörpern (STIL-3D.md).
## Konventionen: Boden bei y = 0, Blick nach +Z, 1 Einheit = 1 Dungeon-Feld,
## normale Gegner 0.6–1.0 hoch, große 1.2–1.5. Jede Figur ist ein Node3D
## mit Meta "wippen" (Idle-Amplitude), optional "quetschen" (Schleime) und
## "schwebt" (Höhe über dem Boden).
##
## Wenige Baukästen (zweibeiner, vierbeiner, schleim, krabbler, …) mit
## Parametern statt 33 Einzelmodellen — neue Gegner sind eine Zeile in
## fuer_archetyp().


static func _p(name: String) -> Color:
	return Stil3D.farbe(name)


static func _wurzel(name: String, wippen := 0.03) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.set_meta("wippen", wippen)
	return n


static func _skaliert(n: Node3D, groesse: float) -> Node3D:
	if not is_equal_approx(groesse, 1.0):
		n.scale = Vector3.ONE * groesse
	return n


## Die 3D-Figur zu einem Gegner-Archetyp.
static func fuer_archetyp(id: StringName) -> Node3D:
	match id:
		&"schleim":
			return schleim()
		&"schleimstapel":
			return schleimstapel()
		&"koenigschleim":
			return schleim({"farbe": _p("ruestung"), "krone": true, "groesse": 1.3})
		&"schleimgott":
			return schleim({"farbe": _p("gold"), "krone": true, "groesse": 1.6,
				"leuchten": _p("glut") * 0.25, "runen": true})
		&"wolf":
			return wolf()
		&"baer":
			return vierbeiner({"fell": _p("braun"), "schnauze": _p("braun_hell"), "maehne": null,
				"ohren": "rund", "groesse": 1.3, "laenge": 0.85, "augen": _p("schwarz")})
		&"schattenbestie":
			return vierbeiner({"fell": _p("schatten"), "maehne": _p("robe_lila"),
				"augen": _p("glut"), "groesse": 1.15})
		&"leichenfresser":
			return vierbeiner({"fell": _p("fahl"), "maehne": _p("knochen"), "augen": _p("seele")})
		&"demonenjager":
			return vierbeiner({"fell": _p("daemon"), "maehne": _p("schwarz"), "hoerner": true,
				"augen": _p("glut")})
		&"verfluchtkatz":
			return vierbeiner({"fell": _p("schwarz"), "maehne": null, "groesse": 0.8,
				"augen": _p("lila"), "schwanz": _p("lila")})
		&"verfluchtdachs":
			return vierbeiner({"fell": _p("eisen"), "maehne": _p("weiss"), "ohren": "rund",
				"groesse": 0.85, "laenge": 0.95, "augen": _p("lila")})
		&"verfluchtbock":
			return vierbeiner({"fell": _p("braun"), "maehne": null, "geweih": true,
				"groesse": 1.25, "augen": _p("lila")})
		&"verfluchtigel":
			return igel()
		&"fledermaus":
			return fledermaus()
		&"spinne":
			return krabbler({"koerper": _p("schatten"), "muster": _p("daemon")})
		&"pilzkrabbel":
			return krabbler({"koerper": _p("braun"), "pilzhut": true, "groesse": 0.8})
		&"golem":
			return golem()
		&"pilzstamm":
			return golem({"stein": _p("braun"), "moos": _p("pilz_rot"), "auge": _p("seele"),
				"kristall": false})
		&"troll":
			return zweibeiner({"koerper": _p("troll"), "haut": _p("troll"), "beine": _p("leder"),
				"waffe": "keule", "hauer": true, "groesse": 1.4})
		&"bandit":
			return zweibeiner({"koerper": _p("leder"), "beine": _p("braun"), "maske": true,
				"kopf": "kapuze", "kapuze": _p("braun"), "waffe": "dolche"})
		&"kultist":
			return zweibeiner({"koerper": _p("robe_lila"), "robe": true, "kopf": "kapuze",
				"kapuze": _p("robe_lila"), "haut": _p("schwarz"), "augen": _p("daemon")})
		&"nekromant":
			return zweibeiner({"koerper": _p("robe_schwarz"), "robe": true, "haut": _p("fahl"),
				"waffe": "stab", "stablicht": _p("seele"), "kopf": "kapuze",
				"kapuze": _p("robe_schwarz")})
		&"skelett":
			return zweibeiner({"koerper": _p("knochen"), "haut": _p("knochen"), "beine": _p("knochen"),
				"kopf": "schaedel", "augen": _p("daemon"), "waffe": "schwert", "schild": true})
		&"toddiener":
			return zweibeiner({"koerper": _p("leder"), "haut": _p("fahl"), "beine": _p("schwarz"),
				"augen": _p("seele"), "gebeugt": true})
		&"schattenkrieger":
			return zweibeiner({"koerper": _p("schatten"), "haut": _p("schatten"),
				"beine": _p("robe_schwarz"), "kopf": "helm", "helm": _p("schatten"),
				"augen": _p("lila"), "waffe": "schwert", "schild": true, "groesse": 1.1})
		&"todesmeister":
			return zweibeiner({"koerper": _p("robe_schwarz"), "robe": true, "kopf": "schaedel",
				"haut": _p("knochen"), "augen": _p("seele"), "waffe": "stab",
				"stablicht": _p("seele"), "hut": "krone", "schwebt": 0.25, "groesse": 1.3})
		&"kleindaemon":
			return zweibeiner({"koerper": _p("daemon"), "haut": _p("daemon"),
				"beine": _p("daemon_dunkel"), "hoerner": true, "fluegel": true,
				"augen": _p("glut"), "groesse": 0.75})
		&"demonenbeschwoerer":
			return zweibeiner({"koerper": _p("daemon_dunkel"), "robe": true, "haut": _p("daemon"),
				"hoerner": true, "waffe": "stab", "stablicht": _p("flamme"), "augen": _p("glut")})
		&"demonenkonig":
			return zweibeiner({"koerper": _p("daemon"), "haut": _p("daemon"),
				"beine": _p("daemon_dunkel"), "hoerner": true, "hut": "krone",
				"umhang": _p("schwarz"), "waffe": "schwert", "augen": _p("glut"), "groesse": 1.5})
		&"pilzhexe":
			return zweibeiner({"koerper": _p("moos_dunkel"), "robe": true, "hut": "pilz",
				"waffe": "stab", "stablicht": _p("moos")})
		&"hexenmeisterin":
			return zweibeiner({"koerper": _p("robe_lila"), "robe": true, "hut": "spitz",
				"waffe": "stab", "stablicht": _p("lila"), "groesse": 1.15})
		&"geist":
			return geist()
		&"mimic":
			return mimic()
	# Unbekannter Archetyp (neu generiert, noch ohne Eintrag): bunter Schleim.
	var farbe := Color.from_hsv(float(absi(hash(id)) % 360) / 360.0, 0.55, 0.85)
	return schleim({"farbe": farbe})


# --- Schleim-Familie ----------------------------------------------------------

static func schleim(p := {}) -> Node3D:
	var n := _wurzel("Schleim", 0.0)
	n.set_meta("quetschen", 0.06)
	var c: Color = p.get("farbe", _p("schleim"))
	var leuchten: Color = p.get("leuchten", Color.BLACK)
	Stil3D.teil(n, Stil3D.zylinder(0.46, 0.5, 0.05), c, Vector3(0, 0.025, 0))         # Pfütze
	Stil3D.teil(n, Stil3D.kugel(0.42, 0.66), c, Vector3(0, 0.33, 0), Vector3.ZERO, true, leuchten)
	Stil3D.teil(n, Stil3D.kegel(0.13, 0.26), c, Vector3(0.04, 0.72, -0.02), Vector3(0, 0, -14))
	Stil3D.teil(n, Stil3D.kugel(0.07), c.lightened(0.45), Vector3(-0.2, 0.5, 0.22), Vector3.ZERO, false)
	Stil3D.auge(n, Vector3(0, 0.47, 0.31), 0.11)
	Stil3D.auge(n, Vector3(-0.13, 0.33, 0.35), 0.06)
	Stil3D.auge(n, Vector3(0.13, 0.33, 0.35), 0.06)
	Stil3D.braue(n, Vector3(-0.13, 0.4, 0.38), 0.12, -1.0)
	Stil3D.braue(n, Vector3(0.13, 0.4, 0.38), 0.12, 1.0)
	Stil3D.teil(n, Stil3D.kugel(0.1, 0.07), _p("mund"), Vector3(0, 0.2, 0.38))
	for x in [-0.05, 0.05]:
		Stil3D.teil(n, Stil3D.kegel(0.025, 0.06), _p("weiss"), Vector3(x, 0.2, 0.42), Vector3(180, 0, 0), false)
	if p.get("krone", false):
		_krone(n, Vector3(-0.12, 0.66, 0.0), 0.14)
	if p.get("runen", false):
		Stil3D.teil(n, Stil3D.zylinder(0.6, 0.6, 0.03), _p("glut"), Vector3(0, 0.06, 0), Vector3.ZERO,
			false, _p("glut") * 0.6)
	return _skaliert(n, p.get("groesse", 1.0))


static func schleimstapel() -> Node3D:
	var n := _wurzel("Schleimstapel", 0.0)
	n.set_meta("quetschen", 0.05)
	var c := _p("schleim")
	for i in 3:
		var r := 0.38 - i * 0.08
		var y := 0.24 + i * 0.4 - i * i * 0.03
		Stil3D.teil(n, Stil3D.kugel(r, r * 1.5), c, Vector3(0.03 * (i % 2), y, 0))
		Stil3D.auge(n, Vector3(-0.08, y + 0.05, r * 0.82), 0.05)
		Stil3D.auge(n, Vector3(0.08, y + 0.05, r * 0.82), 0.05)
	Stil3D.teil(n, Stil3D.zylinder(0.42, 0.46, 0.05), c, Vector3(0, 0.025, 0))
	return n


# --- Vierbeiner ---------------------------------------------------------------

static func wolf() -> Node3D:
	return vierbeiner({})


## Parameter: fell, schnauze, maehne (Color oder null), schwanz, augen,
## ohren ("spitz"/"rund"), hoerner, geweih, groesse, laenge.
static func vierbeiner(p: Dictionary) -> Node3D:
	var n := _wurzel("Vierbeiner", 0.02)
	n.set_meta("drehung", 38.0)  # frontal wirken Schnauzen wie Masken » 3/4-Ansicht
	var fell: Color = p.get("fell", _p("fell"))
	var maehne = p.get("maehne", _p("maehne"))
	var schwanz: Color = p.get("schwanz", maehne if maehne != null else fell)
	var augen: Color = p.get("augen", _p("glut"))
	var laenge: float = p.get("laenge", 1.0)
	for x in [-0.12, 0.12]:
		for z in [-0.24 * laenge, 0.22 * laenge]:
			Stil3D.teil(n, Stil3D.zylinder(0.055, 0.065, 0.34), fell, Vector3(x, 0.17, z))
	Stil3D.teil(n, Stil3D.kapsel(0.2, 0.78 * laenge), fell, Vector3(0, 0.44, -0.02), Vector3(90, 0, 0))
	Stil3D.teil(n, Stil3D.kapsel(0.06, 0.42), schwanz, Vector3(0, 0.56, -0.48 * laenge), Vector3(-55, 0, 0))
	if maehne != null:
		Stil3D.teil(n, Stil3D.kugel(0.25, 0.42), maehne, Vector3(0, 0.56, 0.24))
		for i in 5:
			var w := -50.0 + i * 25.0
			Stil3D.teil(n, Stil3D.kegel(0.07, 0.24), maehne,
				Vector3(sin(deg_to_rad(w)) * 0.2, 0.72, 0.18 - cos(deg_to_rad(w)) * 0.06),
				Vector3(-35, 0, -w * 0.8))
	var kz := 0.42 * laenge
	Stil3D.teil(n, Stil3D.box(0.3, 0.26, 0.28), fell, Vector3(0, 0.64, kz))
	Stil3D.teil(n, Stil3D.box(0.15, 0.11, 0.17), p.get("schnauze", fell * 1.12), Vector3(0, 0.58, kz + 0.2))
	Stil3D.teil(n, Stil3D.box(0.08, 0.06, 0.05), _p("schwarz"), Vector3(0, 0.62, kz + 0.29), Vector3.ZERO, false)
	if p.get("ohren", "spitz") == "rund":
		for x in [-0.12, 0.12]:
			Stil3D.teil(n, Stil3D.kugel(0.065), fell, Vector3(x, 0.8, kz - 0.04))
	else:
		Stil3D.teil(n, Stil3D.kegel(0.07, 0.17), fell, Vector3(-0.1, 0.84, kz - 0.04), Vector3(0, 0, 12))
		Stil3D.teil(n, Stil3D.kegel(0.07, 0.17), fell, Vector3(0.1, 0.84, kz - 0.04), Vector3(0, 0, -12))
	if p.get("hoerner", false):
		for s in [-1.0, 1.0]:
			Stil3D.teil(n, Stil3D.kegel(0.05, 0.22), _p("knochen"), Vector3(0.09 * s, 0.86, kz + 0.02),
				Vector3(-20, 0, -25 * s))
	if p.get("geweih", false):
		for s in [-1.0, 1.0]:
			Stil3D.teil(n, Stil3D.zylinder(0.025, 0.03, 0.34), _p("knochen"), Vector3(0.12 * s, 0.95, kz - 0.05),
				Vector3(0, 0, -30 * s))
			Stil3D.teil(n, Stil3D.zylinder(0.02, 0.025, 0.18), _p("knochen"), Vector3(0.24 * s, 1.08, kz - 0.05),
				Vector3(0, 0, 30 * s))
	for x in [-0.08, 0.08]:
		Stil3D.teil(n, Stil3D.kugel(0.035), augen, Vector3(x, 0.69, kz + 0.14), Vector3.ZERO, false,
			augen * 0.9)
	for x in [-0.05, 0.05]:
		Stil3D.teil(n, Stil3D.kegel(0.022, 0.06), _p("weiss"), Vector3(x, 0.5, kz + 0.25), Vector3(180, 0, 0), false)
	return _skaliert(n, p.get("groesse", 1.0))


static func igel() -> Node3D:
	var n := _wurzel("Igel", 0.01)
	n.set_meta("drehung", 30.0)
	Stil3D.teil(n, Stil3D.kugel(0.3, 0.42), _p("braun"), Vector3(0, 0.22, 0))
	for i in 9:
		var w := -80.0 + i * 20.0
		for reihe in 2:
			Stil3D.teil(n, Stil3D.kegel(0.05, 0.24), _p("robe_lila"),
				Vector3(sin(deg_to_rad(w)) * 0.22, 0.32 + reihe * 0.08, -0.06 - reihe * 0.08),
				Vector3(-40 - reihe * 25, 0, -w))
	Stil3D.teil(n, Stil3D.kugel(0.12, 0.14), _p("braun_hell"), Vector3(0, 0.2, 0.27))
	Stil3D.teil(n, Stil3D.kugel(0.03), _p("schwarz"), Vector3(0, 0.2, 0.39), Vector3.ZERO, false)
	for x in [-0.08, 0.08]:
		Stil3D.teil(n, Stil3D.kugel(0.03), _p("daemon"), Vector3(x, 0.28, 0.3), Vector3.ZERO, false,
			_p("daemon"))
	return n


# --- Krabbler (Spinne & Co.) ----------------------------------------------------

static func krabbler(p: Dictionary) -> Node3D:
	var n := _wurzel("Krabbler", 0.015)
	n.set_meta("drehung", 25.0)
	var k: Color = p.get("koerper", _p("schatten"))
	Stil3D.teil(n, Stil3D.kugel(0.26, 0.4), k, Vector3(0, 0.34, -0.18))                 # Hinterleib
	Stil3D.teil(n, Stil3D.kugel(0.16), k, Vector3(0, 0.3, 0.14))                          # Kopf
	if p.has("muster"):
		Stil3D.teil(n, Stil3D.kugel(0.09, 0.05), p["muster"], Vector3(0, 0.53, -0.2), Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		for i in 4:
			var z := 0.12 - i * 0.12
			Stil3D.teil(n, Stil3D.zylinder(0.025, 0.03, 0.36), k, Vector3(0.22 * s, 0.3, z),
				Vector3(0, -15 + i * 10, 60 * s))
			Stil3D.teil(n, Stil3D.zylinder(0.02, 0.025, 0.3), k, Vector3(0.4 * s, 0.14, z),
				Vector3(0, 0, -20 * s))
	for i in 4:
		var x := -0.06 + (i % 2) * 0.12
		Stil3D.teil(n, Stil3D.kugel(0.03 if i < 2 else 0.022), _p("daemon"),
			Vector3(x, 0.36 + (i / 2) * 0.05, 0.28), Vector3.ZERO, false, _p("daemon"))
	if p.get("pilzhut", false):
		Stil3D.teil(n, Stil3D.kugel(0.32, 0.22), _p("pilz_rot"), Vector3(0, 0.56, -0.12))
		for v in [Vector3(-0.12, 0.65, -0.05), Vector3(0.1, 0.64, -0.2)]:
			Stil3D.teil(n, Stil3D.kugel(0.04), _p("weiss"), v, Vector3.ZERO, false)
	return _skaliert(n, p.get("groesse", 1.0))


# --- Konstrukte ---------------------------------------------------------------

static func golem(p := {}) -> Node3D:
	var n := _wurzel("Golem", 0.015)
	var stein: Color = p.get("stein", _p("stein"))
	var moos: Color = p.get("moos", _p("moos"))
	var auge: Color = p.get("auge", _p("glut"))
	Stil3D.teil(n, Stil3D.box(0.26, 0.36, 0.28), stein * 0.78, Vector3(-0.19, 0.18, 0))
	Stil3D.teil(n, Stil3D.box(0.26, 0.36, 0.28), stein * 0.78, Vector3(0.19, 0.18, 0))
	Stil3D.teil(n, Stil3D.box(0.72, 0.56, 0.46), stein, Vector3(0, 0.66, 0))
	Stil3D.teil(n, Stil3D.box(0.34, 0.28, 0.32), stein, Vector3(0, 1.08, 0.04))
	Stil3D.teil(n, Stil3D.kugel(0.075), auge, Vector3(0, 1.1, 0.2), Vector3.ZERO, true, auge)
	for seite in [-1.0, 1.0]:
		Stil3D.teil(n, Stil3D.box(0.24, 0.52, 0.26), stein, Vector3(0.5 * seite, 0.62, 0), Vector3(0, 0, 6 * seite))
		Stil3D.teil(n, Stil3D.box(0.32, 0.3, 0.32), stein * 1.2, Vector3(0.54 * seite, 0.26, 0.05))
		Stil3D.teil(n, Stil3D.kugel(0.21, 0.15), moos, Vector3(0.3 * seite, 0.95, 0))
	if p.get("kristall", true):
		Stil3D.teil(n, Stil3D.kegel(0.07, 0.3), _p("kristall"), Vector3(0.14, 1.02, -0.22),
			Vector3(-25, 0, -15), true, _p("kristall") * 0.5)
		Stil3D.teil(n, Stil3D.kegel(0.05, 0.22), _p("kristall"), Vector3(-0.12, 0.98, -0.24),
			Vector3(-30, 0, 20), true, _p("kristall") * 0.5)
	return n


# --- Flieger & Geister --------------------------------------------------------

static func fledermaus() -> Node3D:
	var n := _wurzel("Fledermaus", 0.08)
	n.set_meta("schwebt", 0.2)
	var lila := _p("lila")
	Stil3D.teil(n, Stil3D.kugel(0.2, 0.36), lila, Vector3(0, 0.95, 0))
	Stil3D.teil(n, Stil3D.kegel(0.07, 0.2), lila, Vector3(-0.1, 1.17, 0), Vector3(0, 0, 15))
	Stil3D.teil(n, Stil3D.kegel(0.07, 0.2), lila, Vector3(0.1, 1.17, 0), Vector3(0, 0, -15))
	for seite in [-1.0, 1.0]:
		Stil3D.teil(n, Stil3D.prisma(0.5, 0.3, 0.03), _p("lila_dunkel"),
			Vector3(0.4 * seite, 1.0, -0.04), Vector3(0, 0, -100 * seite))
	Stil3D.auge(n, Vector3(-0.075, 1.0, 0.15), 0.065)
	Stil3D.auge(n, Vector3(0.075, 1.0, 0.15), 0.065)
	Stil3D.teil(n, Stil3D.kegel(0.03, 0.08), _p("weiss"), Vector3(0.05, 0.86, 0.15), Vector3(180, 0, 0), false)
	return n


static func geist() -> Node3D:
	var n := _wurzel("Geist", 0.07)
	n.set_meta("schwebt", 0.25)
	var c := Color("dfe8f4")
	Stil3D.teil(n, Stil3D.kugel(0.3, 0.5), c, Vector3(0, 0.75, 0))
	Stil3D.teil(n, Stil3D.kegel(0.28, 0.5), c, Vector3(0, 0.38, -0.06), Vector3(200, 0, 0))   # Schweif
	for s in [-1.0, 1.0]:
		Stil3D.teil(n, Stil3D.kapsel(0.06, 0.3), c, Vector3(0.3 * s, 0.68, 0.06), Vector3(0, 0, 50 * s))
	for x in [-0.1, 0.1]:
		Stil3D.teil(n, Stil3D.kugel(0.06, 0.09), _p("schwarz"), Vector3(x, 0.8, 0.26), Vector3.ZERO, false)
	Stil3D.teil(n, Stil3D.kugel(0.07, 0.11), _p("schwarz"), Vector3(0, 0.64, 0.27), Vector3.ZERO, false)
	return n


static func mimic() -> Node3D:
	var n := _wurzel("Mimic", 0.02)
	Stil3D.teil(n, Stil3D.box(0.66, 0.36, 0.46), _p("holz"), Vector3(0, 0.18, 0))
	Stil3D.teil(n, Stil3D.box(0.66, 0.14, 0.46), _p("holz_hell"), Vector3(0, 0.5, -0.12), Vector3(-35, 0, 0))
	Stil3D.teil(n, Stil3D.box(0.56, 0.06, 0.36), _p("mund"), Vector3(0, 0.37, 0.0), Vector3.ZERO, false)
	for i in 6:
		var x := -0.24 + i * 0.096
		Stil3D.teil(n, Stil3D.kegel(0.03, 0.09), _p("weiss"), Vector3(x, 0.4, 0.21), Vector3.ZERO, false)
		Stil3D.teil(n, Stil3D.kegel(0.03, 0.09), _p("weiss"), Vector3(x, 0.46, 0.15), Vector3(180, 0, 0), false)
	Stil3D.teil(n, Stil3D.kapsel(0.06, 0.34), _p("maehne"), Vector3(0, 0.36, 0.3), Vector3(75, 0, 0))  # Zunge
	for x in [-0.15, 0.15]:
		Stil3D.teil(n, Stil3D.kugel(0.04), _p("glut"), Vector3(x, 0.62, 0.02), Vector3.ZERO, false, _p("glut"))
	return n


# --- Zweibeiner (Helden, Humanoide, Untote, Dämonen) ----------------------------

## Parameter: koerper, beine, haut, robe, kopf ("normal"/"kapuze"/"schaedel"/
## "helm"), kapuze, helm, hut ("spitz"/"pilz"/"krone"), hoerner, hauer, maske,
## waffe ("schwert"/"keule"/"stab"/"dolche"), stablicht, schild, umhang,
## fluegel, augen (Leuchtfarbe, sonst Punktaugen), gebeugt, schwebt, groesse.
static func zweibeiner(p: Dictionary) -> Node3D:
	var n := _wurzel("Zweibeiner", 0.012)
	var k: Color = p.get("koerper", _p("ruestung"))
	var haut: Color = p.get("haut", _p("haut"))
	var neigung := 12.0 if p.get("gebeugt", false) else 0.0
	if p.has("schwebt"):
		n.set_meta("schwebt", p["schwebt"])
		n.set_meta("wippen", 0.05)
	if p.get("robe", false):
		Stil3D.teil(n, Stil3D.zylinder(0.17, 0.3, 0.56), k * 0.9, Vector3(0, 0.28, 0))
	else:
		var beine: Color = p.get("beine", k * 0.7)
		Stil3D.teil(n, Stil3D.box(0.13, 0.3, 0.15), beine, Vector3(-0.08, 0.15, 0))
		Stil3D.teil(n, Stil3D.box(0.13, 0.3, 0.15), beine, Vector3(0.08, 0.15, 0))
	if p.has("umhang"):
		Stil3D.teil(n, Stil3D.box(0.42, 0.56, 0.05), p["umhang"], Vector3(0, 0.55, -0.17), Vector3(12, 0, 0))
	var oben := Node3D.new()  # Oberkörper (kippt bei "gebeugt")
	oben.rotation_degrees.x = neigung
	oben.position = Vector3(0, 0.36, 0)
	n.add_child(oben)
	Stil3D.teil(oben, Stil3D.zylinder(0.19, 0.23, 0.44), k, Vector3(0, 0.16, 0))
	Stil3D.teil(oben, Stil3D.kapsel(0.06, 0.32), k, Vector3(-0.27, 0.2, 0.02), Vector3(0, 0, 12))
	Stil3D.teil(oben, Stil3D.kapsel(0.06, 0.32), k, Vector3(0.27, 0.2, 0.02), Vector3(0, 0, -12))
	if p.get("fluegel", false):
		for s in [-1.0, 1.0]:
			Stil3D.teil(oben, Stil3D.prisma(0.42, 0.26, 0.03), _p("daemon_dunkel"),
				Vector3(0.3 * s, 0.34, -0.16), Vector3(0, 0, -100 * s))
	_kopf(oben, p, haut)
	_waffe(oben, p)
	return _skaliert(n, p.get("groesse", 1.0))


static func _kopf(n: Node3D, p: Dictionary, haut: Color) -> void:
	var kopf_y := 0.52
	var art: String = p.get("kopf", "normal")
	Stil3D.teil(n, Stil3D.kugel(0.17), haut, Vector3(0, kopf_y, 0))
	if p.has("augen"):
		var a: Color = p["augen"]
		var augen_r := 0.04 if art == "schaedel" else 0.03
		if art == "schaedel":
			for x in [-0.065, 0.065]:
				Stil3D.teil(n, Stil3D.kugel(0.055), _p("schwarz"), Vector3(x, kopf_y + 0.01, 0.12), Vector3.ZERO, false)
		for x in [-0.065, 0.065]:
			Stil3D.teil(n, Stil3D.kugel(augen_r), a, Vector3(x, kopf_y + 0.01, 0.155), Vector3.ZERO, false, a)
	else:
		for x in [-0.06, 0.06]:
			Stil3D.teil(n, Stil3D.kugel(0.028), _p("schwarz"), Vector3(x, kopf_y, 0.155), Vector3.ZERO, false)
	if p.get("maske", false):
		Stil3D.teil(n, Stil3D.box(0.3, 0.09, 0.08), _p("schwarz"), Vector3(0, kopf_y - 0.07, 0.12), Vector3.ZERO, false)
	if p.get("hauer", false):
		for x in [-0.07, 0.07]:
			Stil3D.teil(n, Stil3D.kegel(0.025, 0.09), _p("knochen"), Vector3(x, kopf_y - 0.06, 0.14), Vector3.ZERO, false)
	match art:
		"kapuze":
			var kap: Color = p.get("kapuze", _p("robe_lila"))
			Stil3D.teil(n, Stil3D.kugel(0.2, 0.26), kap, Vector3(0, kopf_y + 0.07, -0.04))
			Stil3D.teil(n, Stil3D.kegel(0.1, 0.18), kap, Vector3(0, kopf_y + 0.12, -0.18), Vector3(-70, 0, 0))
		"helm":
			var h: Color = p.get("helm", _p("eisen"))
			Stil3D.teil(n, Stil3D.kugel(0.2, 0.24), h, Vector3(0, kopf_y + 0.05, 0))
			Stil3D.teil(n, Stil3D.box(0.24, 0.04, 0.05), _p("schwarz"), Vector3(0, kopf_y + 0.0, 0.17), Vector3.ZERO, false)
		"schaedel":
			Stil3D.teil(n, Stil3D.box(0.18, 0.07, 0.12), haut * 0.92, Vector3(0, kopf_y - 0.13, 0.06))
	match p.get("hut", ""):
		"spitz":
			Stil3D.teil(n, Stil3D.zylinder(0.3, 0.3, 0.03), _p("robe_schwarz"), Vector3(0, kopf_y + 0.13, 0))
			Stil3D.teil(n, Stil3D.kegel(0.19, 0.42), _p("robe_schwarz"), Vector3(0, kopf_y + 0.35, -0.03),
				Vector3(-10, 0, 0))
		"pilz":
			Stil3D.teil(n, Stil3D.kugel(0.3, 0.22), _p("pilz_rot"), Vector3(0, kopf_y + 0.17, 0))
			for v in [Vector3(-0.13, 0.29, 0.06), Vector3(0.12, 0.28, -0.05), Vector3(0.0, 0.3, 0.15)]:
				Stil3D.teil(n, Stil3D.kugel(0.04), _p("weiss"), Vector3(v.x, kopf_y + v.y - 0.02, v.z), Vector3.ZERO, false)
		"krone":
			_krone(n, Vector3(0, kopf_y + 0.15, 0), 0.13)
	if p.get("hoerner", false):
		for s in [-1.0, 1.0]:
			Stil3D.teil(n, Stil3D.kegel(0.05, 0.22), _p("knochen"), Vector3(0.13 * s, kopf_y + 0.16, 0),
				Vector3(0, 0, -28 * s))


static func _waffe(n: Node3D, p: Dictionary) -> void:
	match p.get("waffe", ""):
		"schwert":
			Stil3D.teil(n, Stil3D.box(0.05, 0.6, 0.025), _p("weiss"), Vector3(0.32, 0.36, 0.1))
			Stil3D.teil(n, Stil3D.box(0.18, 0.04, 0.05), _p("gold"), Vector3(0.32, 0.08, 0.1))
		"keule":
			Stil3D.teil(n, Stil3D.zylinder(0.09, 0.04, 0.62), _p("holz"), Vector3(0.34, 0.3, 0.12), Vector3(0, 0, -10))
		"stab":
			var licht: Color = p.get("stablicht", _p("kristall"))
			Stil3D.teil(n, Stil3D.zylinder(0.025, 0.03, 1.0), _p("holz"), Vector3(0.32, 0.3, 0.08))
			Stil3D.teil(n, Stil3D.kugel(0.07), licht, Vector3(0.32, 0.84, 0.08), Vector3.ZERO, true, licht)
		"dolche":
			for s in [-1.0, 1.0]:
				Stil3D.teil(n, Stil3D.box(0.035, 0.24, 0.02), _p("weiss"), Vector3(0.31 * s, 0.02, 0.12),
					Vector3(20, 0, 0))
	if p.get("schild", false):
		Stil3D.teil(n, Stil3D.zylinder(0.18, 0.18, 0.05), p.get("schildfarbe", _p("ruestung_dunkel")),
			Vector3(-0.33, 0.19, 0.1), Vector3(90, 0, 0))
		Stil3D.teil(n, Stil3D.kugel(0.05), _p("gold"), Vector3(-0.33, 0.19, 0.14), Vector3.ZERO, false)


static func _krone(n: Node3D, pos: Vector3, r: float) -> void:
	Stil3D.teil(n, Stil3D.zylinder(r, r * 0.92, r * 0.8), _p("gold"), pos)
	for i in 5:
		var w := deg_to_rad(i * 72.0)
		Stil3D.teil(n, Stil3D.kegel(r * 0.25, r * 0.7), _p("gold"),
			pos + Vector3(sin(w) * r * 0.8, r * 0.7, cos(w) * r * 0.8), Vector3.ZERO, false)


## Feste Rüstungsfarbe pro Heldenname — derselbe Held sieht im Dungeon,
## im Kampf und in jeder Porträtleiste gleich aus (auch beim Co-op-Gast).
static func held_farbe(name: String) -> Color:
	var farben := ["ruestung", "umhang", "moos", "lila", "gold", "kristall", "braun_hell"]
	return _p(farben[absi(hash(name)) % farben.size()])


## Die Figur zu einem Kämpfer: Helden nach Namen, Gegner nach Archetyp.
static func fuer_kaempfer(c: Combatant) -> Node3D:
	if c.is_player and c.archetype_id == &"":
		return held(held_farbe(c.display_name))
	if c.archetype_id != &"":
		return fuer_archetyp(c.archetype_id)
	return schleim({"farbe": Color.from_hsv(float(absi(hash(c.display_name)) % 360) / 360.0, 0.55, 0.85)})


## Schlüssel für Porträt-Caches: gleiche Figur = gleicher Schlüssel.
static func schluessel_fuer(c: Combatant) -> String:
	if c.is_player and c.archetype_id == &"":
		return "held:" + c.display_name
	if c.archetype_id != &"":
		return "arch:" + String(c.archetype_id)
	return "name:" + c.display_name


## Der Held des Spielers (Rüstungsfarbe = Unterscheidung im Co-op).
static func held(ruestung := Color("4a7ad8")) -> Node3D:
	return zweibeiner({"koerper": ruestung, "beine": ruestung * 0.65, "kopf": "helm",
		"umhang": _p("umhang"), "waffe": "schwert", "schild": true,
		"schildfarbe": ruestung * 0.65})


# --- Objekte -----------------------------------------------------------------

static func truhe(band := Color("6e7385")) -> Node3D:
	var n := _wurzel("Truhe", 0.0)
	Stil3D.teil(n, Stil3D.box(0.62, 0.36, 0.42), _p("holz"), Vector3(0, 0.18, 0))
	Stil3D.teil(n, Stil3D.box(0.64, 0.16, 0.44), _p("holz_hell"), Vector3(0, 0.44, 0))
	for x in [-0.2, 0.2]:
		Stil3D.teil(n, Stil3D.box(0.06, 0.54, 0.45), band, Vector3(x, 0.27, 0), Vector3.ZERO, false)
	Stil3D.teil(n, Stil3D.box(0.12, 0.14, 0.05), _p("gold"), Vector3(0, 0.33, 0.23))
	return n


static func risikotruhe() -> Node3D:
	var n := truhe(_p("gold"))
	Stil3D.teil(n, Stil3D.kugel(0.07), _p("daemon"), Vector3(0, 0.55, 0.12), Vector3.ZERO, true,
		_p("daemon") * 0.6)
	return n


static func schrein(wasser: Color) -> Node3D:
	var n := _wurzel("Schrein", 0.0)
	Stil3D.teil(n, Stil3D.zylinder(0.16, 0.2, 0.36), _p("stein_dunkel"), Vector3(0, 0.18, 0))
	Stil3D.teil(n, Stil3D.zylinder(0.36, 0.3, 0.16), _p("stein"), Vector3(0, 0.44, 0))
	Stil3D.teil(n, Stil3D.zylinder(0.28, 0.28, 0.03), wasser, Vector3(0, 0.52, 0), Vector3.ZERO, false,
		wasser * 0.55)
	return n


static func altar() -> Node3D:
	var n := _wurzel("Altar", 0.0)
	Stil3D.teil(n, Stil3D.box(0.56, 0.36, 0.42), _p("robe_schwarz"), Vector3(0, 0.18, 0))
	Stil3D.teil(n, Stil3D.box(0.72, 0.1, 0.52), _p("stein_dunkel"), Vector3(0, 0.41, 0))
	for x in [-0.16, 0.0, 0.16]:
		Stil3D.teil(n, Stil3D.box(0.06, 0.08, 0.02), _p("daemon"), Vector3(x, 0.2, 0.22), Vector3.ZERO, false,
			_p("daemon") * 0.8)
	Stil3D.teil(n, Stil3D.kugel(0.08, 0.03), _p("daemon_dunkel"), Vector3(0.12, 0.47, 0.05), Vector3.ZERO, false)
	return n


static func fackel() -> Node3D:
	var n := _wurzel("Fackel", 0.0)
	Stil3D.teil(n, Stil3D.zylinder(0.05, 0.035, 0.3), _p("holz"), Vector3(0, 0, 0), Vector3(-20, 0, 0))
	Stil3D.teil(n, Stil3D.kugel(0.08, 0.14), _p("flamme"), Vector3(0, 0.18, 0.05), Vector3.ZERO, false,
		_p("flamme"))
	Stil3D.teil(n, Stil3D.kugel(0.045, 0.09), _p("glut"), Vector3(0, 0.2, 0.07), Vector3.ZERO, false,
		_p("glut"))
	var licht := OmniLight3D.new()
	licht.light_color = Color(1.0, 0.55, 0.22)
	licht.light_energy = 0.7
	licht.omni_range = 3.2
	licht.position = Vector3(0, 0.25, 0.3)
	n.add_child(licht)
	n.set_meta("licht", licht)
	return n


# --- Deko (rein optisch, Biom-typisch) ----------------------------------------

static func deko(art: String) -> Node3D:
	var n := _wurzel("Deko_" + art, 0.0)
	match art:
		"pilz":
			Stil3D.teil(n, Stil3D.zylinder(0.05, 0.06, 0.18), _p("knochen"), Vector3(0, 0.09, 0))
			Stil3D.teil(n, Stil3D.kugel(0.15, 0.12), _p("pilz_rot"), Vector3(0, 0.2, 0))
			Stil3D.teil(n, Stil3D.zylinder(0.03, 0.04, 0.1), _p("knochen"), Vector3(0.15, 0.05, 0.08))
			Stil3D.teil(n, Stil3D.kugel(0.08, 0.07), _p("pilz_rot"), Vector3(0.15, 0.11, 0.08))
		"felsbrocken":
			Stil3D.teil(n, Stil3D.kugel(0.26, 0.3), _p("stein_dunkel"), Vector3(0, 0.14, 0))
			Stil3D.teil(n, Stil3D.kugel(0.15, 0.16), _p("stein"), Vector3(0.2, 0.08, 0.12))
			Stil3D.teil(n, Stil3D.kugel(0.14, 0.06), _p("moos"), Vector3(-0.05, 0.27, 0.02), Vector3.ZERO, false)
		"knochen":
			Stil3D.teil(n, Stil3D.kugel(0.11, 0.12), _p("knochen"), Vector3(0, 0.06, 0))
			for x in [-0.04, 0.04]:
				Stil3D.teil(n, Stil3D.kugel(0.025), _p("schwarz"), Vector3(x, 0.08, 0.09), Vector3.ZERO, false)
			Stil3D.teil(n, Stil3D.kapsel(0.025, 0.3), _p("knochen"), Vector3(0.18, 0.03, -0.05), Vector3(90, 40, 0))
		"amboss":
			Stil3D.teil(n, Stil3D.box(0.16, 0.16, 0.16), _p("eisen") * 0.7, Vector3(0, 0.08, 0))
			Stil3D.teil(n, Stil3D.box(0.4, 0.12, 0.2), _p("eisen"), Vector3(0, 0.22, 0))
		"fass":
			Stil3D.teil(n, Stil3D.zylinder(0.18, 0.18, 0.4), _p("holz"), Vector3(0, 0.2, 0))
			for y in [0.08, 0.32]:
				Stil3D.teil(n, Stil3D.zylinder(0.19, 0.19, 0.03), _p("eisen"), Vector3(0, y, 0), Vector3.ZERO, false)
		"grabstein":
			Stil3D.teil(n, Stil3D.box(0.34, 0.4, 0.1), _p("stein"), Vector3(0, 0.2, 0))
			Stil3D.teil(n, Stil3D.zylinder(0.17, 0.17, 0.1), _p("stein"), Vector3(0, 0.4, 0), Vector3(90, 0, 0))
			Stil3D.teil(n, Stil3D.box(0.12, 0.03, 0.02), _p("stein_dunkel"), Vector3(0, 0.3, 0.06), Vector3.ZERO, false)
	return n
