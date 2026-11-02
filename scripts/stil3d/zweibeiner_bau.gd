class_name ZweibeinerBau
extends RefCounted
## Figuren 2.0 für Helden und Zweibeiner (STIL-3D.md 7g/7h): jede Figur ist
## eine Gliederpuppe — Beine, Rumpf, Kopf mit Gesicht, Hut und Zubehör sind
## EIN gebackener Rumpf, Arme (samt Hand und Waffe), Kopf, Kiefer, Flügel,
## Schwanz, Orbit und Kristall eigene Glieder. Gleiche Figuren teilen ihre
## Meshes (Gliederpuppe.gebacken), Pivots werden nur gedreht.
##
## Formensprache „Zweibeiner 2.0“ (Chibi-Diorama, Höhe 1.0 ohne Hut, Blick
## +Z): Kopf r 0.21 bei y 0.86, Rumpf 0.33–0.63, Schultern (±0.22, 0.6),
## Hand-Kugel am Armende — Waffengriffe gehen immer DURCH die Hand. Je Figur
## EIN Silhouetten-Merkmal über den Schultern und eines auf Handhöhe; die
## Leuchtfarbe sitzt an Augen UND Waffe/Fokus (Lichtpunkt im Dungeon).
##
## Körperbau (Parameter "bau"): normal, keil (Tank, Ritter), schmal (Schurke,
## Bandit), glocke (Robe ohne Beine), schwebend (Robe läuft spitz aus),
## knochen (Skelett) und massig (Dämonenfürst; Troll in FigurenBau).

const GRAD := PI / 180.0

## Archetypen dieses Baukastens (FigurenBau.fuer_archetyp leitet sie hierher).
const ARTEN := [&"bandit", &"kultist", &"nekromant", &"skelett", &"toddiener", &"schattenkrieger",
	&"todesmeister", &"kleindaemon", &"demonenbeschwoerer", &"demonenkonig", &"pilzhexe",
	&"hexenmeisterin"]

## Eigengröße je Archetyp (ins Mesh gebacken, die Kontur bleibt gleich dick).
const GROESSE := {&"schattenkrieger": 1.1, &"todesmeister": 1.3, &"kleindaemon": 0.75,
	&"demonenkonig": 1.5, &"pilzhexe": 0.9, &"hexenmeisterin": 1.15}

## Haarfarben der Helden (a["haar"] / 3 % 5), Frisur = a["haar"] % 3.
const HAARFARBEN := ["braun", "braun_hell", "gold", "schwarz", "maehne"]


static func _p(n: String) -> Color:
	return Stil3D.farbe(n)


static func _t(pos: Vector3, rot_grad := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot_grad * GRAD), pos)


static func _at(t: Transform3D, pos: Vector3, rot_grad := Vector3.ZERO) -> Transform3D:
	return t * _t(pos, rot_grad)


## Basis mit +Y entlang dir und +X möglichst entlang quer (+Z = X × Y).
static func _ausrichtung(dir: Vector3, quer := Vector3.RIGHT) -> Basis:
	var y := dir.normalized()
	var x := quer - y * quer.dot(y)
	if x.length_squared() < 0.0001:
		x = Vector3.BACK.cross(y)
	x = x.normalized()
	return Basis(x, y, x.cross(y))


## Kapsel bzw. Zylinder von a nach z (Knochen, Strähnen, Bogenarme, Finger).
static func _strebe(b: Bausatz, a: Vector3, z: Vector3, r: float, farbe: Color, kontur := true,
		zylinder := false, leuchten := 0.0) -> void:
	var d := z - a
	var l := d.length()
	var m: PrimitiveMesh = Stil3D.zylinder(r, r, l, 8) if zylinder else Stil3D.kapsel(r, l + r * 2.0)
	b.teil_t(m, farbe, Transform3D(_ausrichtung(d), (a + z) * 0.5), kontur, leuchten)


## Kuppel (obere Halbkugel, Ursprung = Grundfläche): hoehe = Kuppelhöhe.
static func _halbkugel(r: float, hoehe: float) -> SphereMesh:
	var m := Stil3D.kugel(r, hoehe)
	m.is_hemisphere = true
	return m


static func _ring(innen: float, aussen: float, ringe := 24, seiten := 6) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = innen
	t.outer_radius = aussen
	t.rings = ringe
	t.ring_segments = seiten
	return t


## Leuchtfarbe einer Figur: Boss = Siegelrot, Akzent (Elite lila), sonst c.
static func _glut(k: Dictionary, c: Color) -> Color:
	if k.get("boss", false):
		return _p("boss_siegel")
	var akzent: Variant = k.get("akzent", null)
	return akzent if akzent != null else c


# --- Grundgerüst ------------------------------------------------------------------

## Beine, Gürtel, Rumpf (nach Bau) und Kopfkugel. Optionen: bau, beine
## (Längenfaktor), neigung/seitlich (Grad, Oberkörper kippt um die Hüfte),
## haut, rumpf, hose, stiefel, guertel, schnalle, stulpe, kopf_r, kopf_h,
## kopf_glied (Kopf als eigenes Glied), robe_oben/robe_unten/robe_h, saum,
## saum_leuchten. Liefert kb: ob (Oberkörper-Bausatz), t (seine Lage), kb
## (Bausatz für Kopfteile), kz (Kopfmitte darin), sx/sy (Schulter).
static func _koerper(pu: Gliederpuppe, o: Dictionary) -> Dictionary:
	var bau: String = o.get("bau", "normal")
	var b := pu.rumpf
	var ob := pu.teilsatz()
	var haut: Color = o.get("haut", _p("haut"))
	var rumpf: Color = o.get("rumpf", _p("ruestung"))
	var f: float = o.get("beine", 1.0)
	var hueft := 0.06 + 0.26 * f if bau in ["normal", "keil", "schmal"] else 0.32
	var rot := Basis.from_euler(Vector3(float(o.get("neigung", 0.0)), 0, float(o.get("seitlich", 0.0))) * GRAD)
	var dreh := Vector3(0, 0.32, 0)
	var t := Transform3D(rot, Vector3(0, hueft - 0.32, 0) + dreh - rot * dreh)
	var sx := 0.22
	match bau:
		"normal", "keil", "schmal":
			var spur := 0.085 if bau == "keil" else (0.065 if bau == "schmal" else 0.075)
			var hose: Color = o.get("hose", rumpf * 0.7)
			var stiefel: Color = o.get("stiefel", _p("leder") * 0.8)
			for s in [-1.0, 1.0]:
				b.teil(Stil3D.kapsel(0.058, hueft), hose, Vector3(spur * s, (hueft + 0.07) * 0.5, 0))
				b.teil(Stil3D.kapsel(0.066, 0.2), stiefel, Vector3(spur * s, 0.066, 0.03), Vector3(90, 0, 0))
				if o.get("stulpe", false):
					b.teil(Stil3D.zylinder(0.078, 0.07, 0.05, 10), stiefel * 1.15, Vector3(spur * s, 0.17 * f, 0))
			var r_oben := 0.25 if bau == "keil" else (0.165 if bau == "schmal" else 0.2)
			var r_unten := 0.18 if bau == "keil" else (0.15 if bau == "schmal" else 0.17)
			sx = 0.26 if bau == "keil" else (0.19 if bau == "schmal" else 0.22)
			ob.teil(Stil3D.zylinder(r_oben, r_unten, 0.31), rumpf, Vector3(0, 0.48, 0))
			var guertel: Variant = o.get("guertel", _p("leder") * 0.75)
			if guertel != null:
				ob.teil(Stil3D.zylinder(r_unten + 0.012, r_unten + 0.012, 0.065), guertel, Vector3(0, 0.335, 0))
				ob.teil(Stil3D.box(0.055, 0.045, 0.02), o.get("schnalle", _p("messing")),
					Vector3(0, 0.335, r_unten + 0.02), Vector3.ZERO, false)
				if _mal != null:  # Gürtelstein in der Farbe der Variante/Element-Schicht
					ob.teil(Stil3D.kugel(0.03, -1.0, 6), _mal, Vector3(0, 0.335, r_unten + 0.034), Vector3.ZERO,
						false, 0.5)
		"glocke", "schwebend":
			var ro: float = o.get("robe_oben", 0.19)
			var ru: float = o.get("robe_unten", 0.33)
			var h: float = o.get("robe_h", 0.56)
			if bau == "glocke":
				b.teil(Stil3D.zylinder(ro, ru, h), rumpf * 0.92, Vector3(0, h * 0.5, 0))
				if o.has("saum"):
					b.teil(Stil3D.zylinder(ru + 0.012, ru + 0.018, 0.05, 16), o["saum"], Vector3(0, 0.03, 0),
						Vector3.ZERO, false, float(o.get("saum_leuchten", 0.0)))
			else:
				b.teil(Stil3D.zylinder(0.25, 0.02, 0.6), rumpf * 0.92, Vector3(0, 0.32, 0))
			ob.teil(Stil3D.zylinder(0.2, ro, 0.15), rumpf, Vector3(0, 0.6, 0))
			if _mal != null:  # Robenstein in der Farbe der Variante/Element-Schicht
				ob.teil(Stil3D.kugel(0.036, -1.0, 6), _mal, Vector3(0, 0.6, maxf(0.2, ro) + 0.012), Vector3.ZERO, false,
					0.5)
	var kopf := Vector3(0, 0.86, 0)
	var kr: float = o.get("kopf_r", 0.21)
	var kb := {"ob": ob, "t": t, "kz": kopf, "kb": ob, "sx": sx, "sy": 0.6, "kr": kr, "hueft": hueft}
	if o.get("kopf_glied", false):
		var hals := Vector3(0, 0.66, 0)
		var kopf_b := pu.glied("kopf", t * hals, Vector3(float(o.get("kopf_neigung", o.get("neigung", 0.0))), 0,
			float(o.get("seitlich", 0.0))))
		kb["kb"] = kopf_b
		kb["kz"] = kopf - hals
		kb["hals"] = hals
	(kb["kb"] as Bausatz).teil(Stil3D.kugel(kr, float(o.get("kopf_h", kr * 2.0))), haut, kb["kz"])
	return kb


## Punkt im Oberkörper (kb.ob-Maße) in Figurmaßen.
static func _w(kb: Dictionary, v: Vector3) -> Vector3:
	return (kb["t"] as Transform3D) * v


## Oberkörper in den Rumpf übernehmen, Anker und Porträt-Metas setzen.
## kopf_oben = Scheitelhöhe über der Kopfmitte (Hut, Helm, Kapuze).
static func _fertig(pu: Gliederpuppe, kb: Dictionary, kopf_oben := 0.24) -> void:
	pu.uebernehmen(kb["ob"], kb["t"])
	var kz: Vector3 = kb["kz"]
	if kb.has("hals"):
		pu.meta("anker_kopf", kz + Vector3(0, kopf_oben, 0)).meta("anker_kopf_glied", "kopf")
	else:
		pu.meta("anker_kopf", _w(kb, kz + Vector3(0, kopf_oben, 0)))
	pu.meta("anker_ruecken", _w(kb, Vector3(0, 0.5, -0.24)))
	pu.meta("brust_y", _w(kb, Vector3(0, 0.36, 0)).y)  # Porträt: Brustbild ab Gürtelhöhe


## Arm-Glied am Schultergelenk (Figurmaße) mit Ruhe (Grad). o: farbe, hand,
## laenge, r, hand_r. Liefert {b, hand, ruhe} für _lage().
static func _arm(pu: Gliederpuppe, glied_name: String, gelenk: Vector3, ruhe: Vector3, o: Dictionary) -> Dictionary:
	var b := pu.glied(glied_name, gelenk, ruhe)
	var hand := Gliederpuppe.arm(b, float(o.get("laenge", 0.26)), float(o.get("r", 0.055)), o.get("farbe"),
		o.get("hand"), float(o.get("hand_r", 0.06)))
	return {"b": b, "hand": hand, "ruhe": ruhe, "gelenk": gelenk}


## Beide Arme an den Schultern des Grundgerüsts (o.laenge_l: eigene Länge
## des linken Arms, z. B. Nebenhand am Zweihandgriff).
static func _arme(pu: Gliederpuppe, kb: Dictionary, ruhe_r: Vector3, ruhe_l: Vector3, o: Dictionary) -> Array:
	var sx: float = kb["sx"]
	var sy: float = kb["sy"]
	var ol := o
	if o.has("laenge_l"):
		ol = o.duplicate()
		ol["laenge"] = o["laenge_l"]
	return [_arm(pu, "arm_r", _w(kb, Vector3(sx, sy, 0)), ruhe_r, o),
		_arm(pu, "arm_l", _w(kb, Vector3(-sx, sy, 0)), ruhe_l, ol)]


## Lage an der Hand eines Arm-Glieds: +Y zeigt in Ruhe nach dir (Welt),
## +X möglichst nach quer; versatz in Weltrichtung ab Handmitte.
static func _lage(arm: Dictionary, dir: Vector3, quer := Vector3.RIGHT, versatz := Vector3.ZERO) -> Transform3D:
	var ri := Basis.from_euler((arm["ruhe"] as Vector3) * GRAD).inverse()
	return Transform3D(ri * _ausrichtung(dir, quer), (arm["hand"] as Vector3) + ri * versatz)


## Ruhedrehung (Grad, ohne Y-Anteil) eines Arms am gelenk, dessen Hand in
## Richtung ziel zeigt (Figurmaße): Rx(a)·Rz(c) bildet −Y auf die Richtung ab.
## Ohne Y-Anteil drehen Profil-Zusätze um X beide Arme um dieselbe
## Schulterachse — Zweihandgriffe bleiben geschlossen.
static func _ruhe_zu(gelenk: Vector3, ziel: Vector3) -> Vector3:
	var d := (ziel - gelenk).normalized()
	return Vector3(atan2(-d.z, -d.y), 0.0, asin(clampf(d.x, -1.0, 1.0))) / GRAD


## Handmitte eines Arms in Figurmaßen (Ruhepose).
static func _hand_welt(arm: Dictionary) -> Vector3:
	return (arm["gelenk"] as Vector3) + Basis.from_euler((arm["ruhe"] as Vector3) * GRAD) * (arm["hand"] as Vector3)


## Messpunkte der zuletzt gebauten Figur (Selbsttest, Prüfstände): Name »
## {"glied": Gliedname ("" = Rumpf), "t": Lage im Glied — Ursprung = Griff
## bzw. Mitte, +Y = Waffenrichtung —, optional "r"}; Figurmaße vor
## massstab. Wird nur beim Backen geschrieben (Mesh-Cache), kostet im Spiel
## nichts.
static var messpunkte := {}


static func _messen(name: String, glied: String, t: Variant, r := 0.0) -> void:
	messpunkte[name] = {"glied": glied, "t": t if t is Transform3D else Transform3D(Basis(), t as Vector3), "r": r}


# --- Gesichter --------------------------------------------------------------------

## Helden-Gesicht: große Augen mit Glanz, Brauen (winkel: mutig 8, freundlich
## -5; brauen = false unter einem Helmrand), kleiner Mund bzw. Lächeln,
## Wangen-Tupfer.
static func _gesicht_held(b: Bausatz, kz: Vector3, winkel := 8.0, mund := "laecheln", tuch := false,
		brauen := true) -> void:
	for s in [-1.0, 1.0]:
		Gliederpuppe.auge(b, kz + Vector3(0.075 * s, 0.01, 0.168), 0.05, {"seite": s, "hoch": 1.1})
		if brauen:
			Gliederpuppe.braue(b, kz + Vector3(0.078 * s, 0.083, 0.19), 0.07, s, winkel, _p("braun") * 0.6)
	if tuch:
		return
	Gliederpuppe.mund(b, kz + Vector3(0, -0.085, 0.192), 0.06, mund)
	Gliederpuppe.wangen(b, kz + Vector3(0, -0.045, 0.165), 0.118)


## Haare der Helden: art 0 Strubbel, 1 Zopf, 2 Kurzhaar mit Stirnband;
## nur_seiten = Strähnen unter Hut/Haube.
static func _haare(b: Bausatz, kz: Vector3, farbe: Color, art: int, nur_seiten := false, band := Color.BLACK) -> void:
	if nur_seiten:
		for s in [-1.0, 1.0]:
			_strebe(b, kz + Vector3(0.17 * s, 0.08, 0.02), kz + Vector3(0.2 * s, -0.12, -0.02), 0.04, farbe)
		b.teil(Stil3D.kugel(0.2, 0.26), farbe, kz + Vector3(0, 0.02, -0.07))
		return
	b.teil(_halbkugel(0.226, 0.19), farbe, kz + Vector3(0, 0.05, -0.03), Vector3(-24, 0, 0))
	b.teil(Stil3D.kugel(0.2, 0.3), farbe, kz + Vector3(0, -0.01, -0.07))
	match art:
		0:
			for v in [Vector3(-0.1, 0.17, 0.12), Vector3(0.0, 0.2, 0.13), Vector3(0.1, 0.17, 0.12)]:
				b.teil(Stil3D.kegel(0.05, 0.12, 8), farbe, kz + v, Vector3(70, 0, -v.x * 200.0))
			b.teil(Stil3D.kegel(0.05, 0.12, 8), farbe, kz + Vector3(0.03, 0.24, -0.02), Vector3(-15, 0, -20))
		1:
			_strebe(b, kz + Vector3(0, -0.02, -0.2), kz + Vector3(0, -0.24, -0.25), 0.05, farbe)
			b.teil(Stil3D.kugel(0.04, -1, 8), _p("umhang"), kz + Vector3(0, -0.05, -0.22), Vector3.ZERO, false)
			b.teil(Stil3D.kugel(0.06, 0.09), farbe, kz + Vector3(0, -0.29, -0.26))
		_:
			b.teil(Stil3D.zylinder(0.214, 0.214, 0.045, 16), band, kz + Vector3(0, 0.1, -0.01), Vector3(-14, 0, 0))


## Kapuze: Kugel hinter dem Kopf (Gesichtsöffnung frei), optional Rand,
## Zipfel (Segmentkette) nach hinten-unten.
static func _kapuze(b: Bausatz, kz: Vector3, farbe: Color, o := {}) -> void:
	var r: float = o.get("r", 0.235)
	b.teil(Stil3D.kugel(r, r * 2.08), farbe, kz + Vector3(0, 0.03, -0.075))
	if o.has("rand"):
		b.teil(_ring(0.15, 0.185, 16, 6), o["rand"], kz + Vector3(0, 0.0, 0.1), Vector3(78, 0, 0))
	if o.get("kragen", false):
		b.teil(Stil3D.zylinder(0.17, 0.25, 0.1, 14), farbe, kz + Vector3(0, -0.2, -0.02))
	if o.get("zipfel", 0.0) > 0.0:
		var l: float = o["zipfel"]
		Gliederpuppe.kette(b, _t(kz + Vector3(0, 0.12, -0.22), Vector3(-120, 0, 0)), 3, l, 0.085, 0.015,
			Vector3(18, 0, 6), farbe)


# --- Waffen und Zubehör (Lage t: Ursprung = Handmitte, +Y = Waffenrichtung) --------

## Schwert ab Griffmitte; o.griff = zusätzliche Grifflänge (Zweihänder: der
## Abstand der Hände, Parierstange und Klinge rücken so weit vor).
static func _schwert(b: Bausatz, t: Transform3D, l := 0.48, klinge := Color.WHITE, o := {}) -> void:
	var parier: Color = o.get("parier", _p("gold"))
	var kl: Color = klinge if klinge != Color.WHITE else _p("weiss")
	var griff: float = o.get("griff", 0.0)
	if griff > 0.0:
		b.teil_t(Stil3D.zylinder(0.022, 0.024, 0.13 + griff, 8), _p("leder"), _at(t, Vector3(0, griff * 0.5, 0)))
		t = _at(t, Vector3(0, griff, 0))
	else:
		b.teil_t(Stil3D.zylinder(0.022, 0.024, 0.13, 8), _p("leder"), t)
	b.teil_t(Stil3D.kugel(0.03, -1, 8), parier, _at(t, Vector3(0, -0.08 - griff, 0)), false)
	b.teil_t(Stil3D.box(0.17, 0.032, 0.05), parier, _at(t, Vector3(0, 0.075, 0)))
	for s in [-1.0, 1.0]:
		b.teil_t(Stil3D.kugel(0.022, -1, 6), parier, _at(t, Vector3(0.09 * s, 0.075, 0)), false)
	b.teil_t(Stil3D.box(0.056, l, 0.018), kl, _at(t, Vector3(0, 0.09 + l * 0.5, 0)))
	b.teil_t(Stil3D.prisma(0.056, 0.08, 0.018), kl, _at(t, Vector3(0, 0.09 + l + 0.04, 0)))
	b.teil_t(Stil3D.box(0.014, l * 0.86, 0.024), o.get("grat", _p("eisen") * 1.2),
		_at(t, Vector3(0, 0.09 + l * 0.46, 0)), false, float(o.get("grat_leuchten", 0.0)))


static func _dolch(b: Bausatz, t: Transform3D, krumm := false) -> void:
	b.teil_t(Stil3D.zylinder(0.018, 0.02, 0.09, 8), _p("leder"), t)
	b.teil_t(Stil3D.box(0.08, 0.024, 0.036), _p("messing"), _at(t, Vector3(0, 0.055, 0)))
	var klinge := _p("eisen") * 1.2 if krumm else _p("weiss")
	if krumm:
		b.teil_t(Stil3D.box(0.038, 0.11, 0.014), klinge, _at(t, Vector3(0, 0.12, 0)))
		b.teil_t(Stil3D.prisma(0.038, 0.13, 0.014), klinge, _at(t, Vector3(0.012, 0.23, 0), Vector3(0, 0, -20)))
	else:
		b.teil_t(Stil3D.box(0.036, 0.15, 0.014), klinge, _at(t, Vector3(0, 0.14, 0)))
		b.teil_t(Stil3D.prisma(0.036, 0.06, 0.014), klinge, _at(t, Vector3(0, 0.245, 0)))
		b.teil_t(Stil3D.box(0.01, 0.15, 0.02), _p("eisen") * 1.2, _at(t, Vector3(0, 0.15, 0)), false)


static func _axt(b: Bausatz, t: Transform3D, gross := false) -> void:
	var l := 0.86 if gross else 0.62
	var kopf_y := l * 0.62
	var f := 1.35 if gross else 1.0
	b.teil_t(Stil3D.zylinder(0.024, 0.028, l, 8), _p("holz"), _at(t, Vector3(0, l * 0.5 - 0.14, 0)))
	b.teil_t(Stil3D.box(0.06, 0.12 * f, 0.06), _p("eisen") * 0.9, _at(t, Vector3(0, kopf_y, 0)))
	var seiten := [1.0, -1.0] if gross else [1.0]
	for s in seiten:
		b.teil_t(Stil3D.prisma(0.2 * f, 0.15 * f, 0.034), _p("eisen"),
			_at(t, Vector3(0.1 * f * s, kopf_y, 0), Vector3(0, 0, 90 * s)))
		b.teil_t(Stil3D.box(0.014, 0.2 * f, 0.04), _p("eisen") * 1.4, _at(t, Vector3(0.19 * f * s, kopf_y, 0)), false)
	if not gross:
		b.teil_t(Stil3D.kegel(0.025, 0.08, 6), _p("eisen") * 0.9, _at(t, Vector3(-0.07, kopf_y, 0), Vector3(0, 0, 90)))


static func _keule(b: Bausatz, t: Transform3D, hammer := false) -> void:
	if hammer:
		b.teil_t(Stil3D.zylinder(0.028, 0.03, 0.82, 8), _p("holz"), _at(t, Vector3(0, 0.24, 0)))
		b.teil_t(Stil3D.box(0.27, 0.14, 0.14), _p("eisen"), _at(t, Vector3(0, 0.62, 0)))
		b.teil_t(Stil3D.box(0.28, 0.03, 0.15), _p("eisen") * 1.3, _at(t, Vector3(0, 0.62, 0)), false)
		for s in [-1.0, 1.0]:
			b.teil_t(Stil3D.zylinder(0.075, 0.075, 0.03, 10), _p("eisen") * 0.8,
				_at(t, Vector3(0.145 * s, 0.62, 0), Vector3(0, 0, 90)), false)
		return
	b.teil_t(Stil3D.zylinder(0.075, 0.032, 0.44, 10), _p("holz"), _at(t, Vector3(0, 0.17, 0)))
	b.teil_t(Stil3D.zylinder(0.072, 0.07, 0.04, 10), _p("eisen"), _at(t, Vector3(0, 0.27, 0)), false)
	for i in 4:
		var w := TAU * i / 4.0 + 0.4
		b.teil_t(Stil3D.kugel(0.022, -1, 6), _p("eisen") * 1.2,
			_at(t, Vector3(sin(w) * 0.075, 0.33, cos(w) * 0.075)), false)


static func _kristallstab(b: Bausatz, t: Transform3D, licht: Color, band: Color) -> void:
	b.teil_t(Stil3D.zylinder(0.022, 0.026, 1.0, 8), _p("holz"), _at(t, Vector3(0, 0.22, 0)))
	for y in [0.1, 0.5]:
		b.teil_t(Stil3D.zylinder(0.031, 0.031, 0.04, 8), band, _at(t, Vector3(0, y, 0)), false)
	for s in [-1.0, 1.0]:
		_strebe(b, (t * Vector3(0, 0.7, 0)), t * Vector3(0.07 * s, 0.82, 0), 0.02, _p("holz"))
		_strebe(b, (t * Vector3(0.07 * s, 0.82, 0)), t * Vector3(0.035 * s, 0.93, 0), 0.018, _p("holz"))
	b.teil_t(Stil3D.prisma(0.09, 0.11, 0.07), licht, _at(t, Vector3(0, 0.875, 0)), true, 0.8)
	b.teil_t(Stil3D.prisma(0.09, 0.07, 0.07), licht, _at(t, Vector3(0, 0.785, 0), Vector3(180, 0, 0)), true, 0.8)


static func _ringstab(b: Bausatz, t: Transform3D) -> void:
	var gold := _p("gold")
	b.teil_t(Stil3D.zylinder(0.022, 0.026, 1.0, 8), _p("holz_hell"), _at(t, Vector3(0, 0.22, 0)))
	b.teil_t(Stil3D.zylinder(0.03, 0.03, 0.04, 8), gold, _at(t, Vector3(0, 0.7, 0)), false)
	for i in 8:
		var w := TAU * i / 8.0
		b.teil_t(Stil3D.kugel(0.027, -1, 6), gold, _at(t, Vector3(sin(w) * 0.1, 0.84 + cos(w) * 0.1, 0)))
	b.teil_t(Stil3D.kugel(0.045, -1, 10), gold, _at(t, Vector3(0, 0.84, 0)), true, 0.8)


static func _schild_rund(b: Bausatz, t: Transform3D, farbe: Color, wappen: Color, r := 0.2) -> void:
	var scheibe := _at(t, Vector3.ZERO, Vector3(90, 0, 0))
	b.teil_t(Stil3D.zylinder(r, r, 0.04, 18), farbe, scheibe)
	b.teil_t(_ring(r - 0.012, r + 0.014, 24, 6), _p("messing"), _at(t, Vector3(0, 0, 0.012), Vector3(90, 0, 0)))
	b.teil_t(Stil3D.box(0.075, r * 1.9, 0.01), wappen, _at(t, Vector3(0, 0, 0.022), Vector3(0, 0, 40)), false)
	b.teil_t(Stil3D.kugel(0.045, 0.05, 10), _p("gold"), _at(t, Vector3(0, 0, 0.026)), false)


static func _turmschild(b: Bausatz, t: Transform3D, farbe: Color) -> void:
	b.teil_t(Stil3D.box(0.42, 0.68, 0.05), farbe, t)
	b.teil_t(Stil3D.box(0.44, 0.7, 0.03), _p("messing"), _at(t, Vector3(0, 0, -0.012)), false)
	b.teil_t(Stil3D.box(0.06, 0.44, 0.012), _p("gold"), _at(t, Vector3(0, 0.04, 0.03)), false)
	b.teil_t(Stil3D.box(0.26, 0.06, 0.012), _p("gold"), _at(t, Vector3(0, 0.12, 0.03)), false)


static func _bogen(b: Bausatz, t: Transform3D, wicklung: Color) -> void:
	var holz := _p("holz_hell")
	var oben := t * Vector3(0, 0.5, -0.16)
	var unten := t * Vector3(0, -0.5, -0.16)
	_strebe(b, t * Vector3(0, -0.14, 0.02), t * Vector3(0, 0.14, 0.02), 0.026, holz)
	_strebe(b, t * Vector3(0, 0.14, 0.02), t * Vector3(0, 0.34, -0.05), 0.022, holz)
	_strebe(b, t * Vector3(0, 0.34, -0.05), oben, 0.018, holz)
	_strebe(b, t * Vector3(0, -0.14, 0.02), t * Vector3(0, -0.34, -0.05), 0.022, holz)
	_strebe(b, t * Vector3(0, -0.34, -0.05), unten, 0.018, holz)
	b.teil_t(Stil3D.zylinder(0.03, 0.03, 0.09, 8), wicklung, t, false)
	_strebe(b, oben, unten, 0.006, _p("weiss"), false, true)


static func _armbrust(b: Bausatz, t: Transform3D) -> void:
	b.teil_t(Stil3D.box(0.07, 0.46, 0.07), _p("holz"), _at(t, Vector3(0, 0.1, 0)))
	b.teil_t(Stil3D.box(0.5, 0.05, 0.04), _p("eisen"), _at(t, Vector3(0, 0.3, 0.01)))
	_strebe(b, t * Vector3(-0.24, 0.29, 0.01), t * Vector3(0, 0.12, 0.04), 0.005, _p("weiss"), false, true)
	_strebe(b, t * Vector3(0.24, 0.29, 0.01), t * Vector3(0, 0.12, 0.04), 0.005, _p("weiss"), false, true)
	b.teil_t(Stil3D.box(0.02, 0.3, 0.02), _p("eisen") * 1.2, _at(t, Vector3(0, 0.26, 0.045)), false)


## Köcher am Rücken; neigung (Grad) so, dass er am Rücken bzw. Umhang anliegt.
static func _koecher(b: Bausatz, pos: Vector3, federn: Color, neigung := Vector3(-12, 0, -28)) -> void:
	var t := _t(pos, neigung)
	b.teil_t(Stil3D.zylinder(0.07, 0.06, 0.38, 10), _p("leder"), t)
	b.teil_t(Stil3D.zylinder(0.074, 0.074, 0.03, 10), _p("messing"), _at(t, Vector3(0, 0.15, 0)), false)
	for i in 3:
		b.teil_t(Stil3D.prisma(0.05, 0.1, 0.012), federn, _at(t, Vector3(-0.03 + i * 0.03, 0.25, 0), Vector3(0, i * 60, 0)))


# --- Helden -----------------------------------------------------------------------

## Was der Held trägt: rolle (tank, krieger, schurke, magier, heiler,
## abenteurer), waffe, neben, licht (Stab-Kristall), haar.
static func held_info(a: Dictionary) -> Dictionary:
	var info := {"waffe": "schwert", "neben": "schild", "rolle": "tank", "haar": int(a.get("haar", 0))}
	if not a.get("bekannt", false):
		return info
	info["neben"] = ""
	var stab := false
	var heilig := false
	var waffe_base := ItemLibrary.get_base(StringName(a.get("waffe", "")))
	info["waffe"] = ""
	if waffe_base != null:
		match waffe_base.family:
			&"schwert":
				info["waffe"] = "grossschwert" if waffe_base.two_handed else "schwert"
			&"dolch":
				info["waffe"] = "dolch"
			&"axt":
				info["waffe"] = "grossaxt" if waffe_base.two_handed else "axt"
			&"stumpf":
				info["waffe"] = "hammer" if waffe_base.two_handed else "keule"
			&"bogen":
				info["waffe"] = "bogen"
			&"armbrust":
				info["waffe"] = "armbrust"
			&"schild":
				info["waffe"] = "turmschild"
			_:
				if waffe_base.spell_damage > 0:
					stab = true
					heilig = "heilig" in String(waffe_base.id)
					info["waffe"] = "ringstab" if heilig else "kristallstab"
	var neben_base := ItemLibrary.get_base(StringName(a.get("neben", "")))
	if neben_base != null:
		if neben_base.family == &"schild":
			info["neben"] = "schild"
		elif neben_base.quiver:
			info["neben"] = "koecher"
		elif neben_base.family == &"dolch":
			info["neben"] = "dolch"
		elif neben_base.id == &"zauberbuch":
			info["neben"] = "buch"
		elif neben_base.id == &"heiligkreuz":
			info["neben"] = "kreuz"
			heilig = heilig or not stab
		else:
			info["neben"] = "fokus"
	var element := String(a.get("element", ""))
	info["licht"] = _p("flamme") if element == "feuer" else (_p("moos") if element == "gift" else _p("kristall"))
	var ruestung := int(a.get("ruestung", Enums.ArmorClass.NONE))
	if stab and ruestung != Enums.ArmorClass.PLATE:
		info["rolle"] = "heiler" if heilig else "magier"
	elif ruestung == Enums.ArmorClass.PLATE:
		info["rolle"] = "tank"
	elif ruestung == Enums.ArmorClass.CHAIN:
		info["rolle"] = "krieger"
	elif ruestung == Enums.ArmorClass.LEATHER:
		info["rolle"] = "schurke"
	else:
		info["rolle"] = "abenteurer"
	return info


## Animations-Profil nach Waffe (Gliederpuppe.PROFILE); mit Rundschild die
## Schild-Fassung (Schildarm hebt nur wenig).
static func _held_anim(info: Dictionary) -> String:
	var anim := _held_anim_waffe(info)
	if info["neben"] == "schild":
		match anim:
			"held_einhand":
				return "held_schild"
			"held_stab", "held_heiler":
				return anim + "_schild"
	return anim


static func _held_anim_waffe(info: Dictionary) -> String:
	match String(info["waffe"]):
		"grossschwert", "grossaxt", "hammer":
			return "held_zweihand"
		"dolch":
			return "held_dolche" if info["neben"] == "dolch" else "held_einhand"
		"bogen":
			return "held_bogen"
		"armbrust":
			return "held_armbrust"
		"turmschild":
			return "held_turm"
		"kristallstab":
			return "held_stab"
		"ringstab":
			return "held_heiler"
	return "held_einhand"


## Sekundärfarbe der Rüstung: × 0.65, bei dunklen Farben (Obsidian,
## Mitternacht, Drachenblut) aufgehellt — sonst wird die Figur ein Klecks.
static func sekundaer(farbe: Color) -> Color:
	return farbe.lightened(0.25) if farbe.get_luminance() < 0.3 else farbe * 0.65


## Held als Gliederpuppe (gecacht je Farbe + Ausrüstung).
static func held(farbe: Color, a := {}) -> Node3D:
	var key := "held:%s|%s" % [farbe.to_html(false), str(a)]
	return Gliederpuppe.gebacken(key, func() -> Gliederpuppe: return held_puppe(farbe, a))


static func held_puppe(farbe: Color, a := {}) -> Gliederpuppe:
	var info := held_info(a)
	messpunkte = {}
	var pu := Gliederpuppe.new("Held")
	pu.meta("wippen", 0.012).meta("drehung", 12.0).meta("anim", _held_anim(info)).meta("rolle", info["rolle"])
	var sek := sekundaer(farbe)
	var haar := _p(HAARFARBEN[(int(info["haar"]) / 3) % HAARFARBEN.size()])
	var frisur := int(info["haar"]) % 3
	var kb: Dictionary
	var arm_farbe := farbe
	var hand := _p("haut")
	var kopf_oben := 0.24
	match String(info["rolle"]):
		"tank":
			kb = _tank(pu, farbe, sek)
			arm_farbe = farbe
			hand = _p("eisen") * 1.1
			kopf_oben = 0.36
		"krieger":
			kb = _krieger(pu, farbe, sek)
			arm_farbe = _p("eisen") * 1.2
			hand = _p("leder")
			kopf_oben = 0.25
		"schurke":
			kb = _schurke(pu, farbe, sek, info)
			arm_farbe = farbe * 0.85
			hand = _p("leder") * 0.9
			kopf_oben = 0.26
		"magier":
			kb = _magier(pu, farbe, sek, haar)
			kopf_oben = 0.55
		"heiler":
			kb = _heiler(pu, farbe, sek, haar)
			kopf_oben = 0.3
		_:
			kb = _abenteurer(pu, farbe, sek, haar, frisur)
			kopf_oben = 0.26
	# Köcher am Rücken für jede Rolle mit Köcher (der Schurke trägt ihn schon):
	# auf Umhang (Tank), Wappenrock/Rücken bzw. Robe, oben vorgeneigt wie
	# Umhang und Glockenrobe — liegt an, ohne einzusinken.
	if info["neben"] == "koecher" and info["rolle"] != "schurke":
		var ruecken: float = {"tank": -0.3, "krieger": -0.27, "magier": -0.27, "heiler": -0.27}.get(
			info["rolle"], -0.25)
		_koecher(kb["ob"], Vector3(0.06, 0.6, ruecken), farbe, Vector3(12, 0, -28))
		_messen("koecher", "", Transform3D(Basis.from_euler(Vector3(12, 0, -28) * GRAD), Vector3(0.06, 0.6, ruecken)),
			0.07)
	_messen("kopf", "", _w(kb, kb["kz"]), kb["kr"])
	_held_bewaffnen(pu, kb, farbe, sek, info, arm_farbe, hand)
	_fertig(pu, kb, kopf_oben)
	return pu


## Tank: Keil-Rumpf, Brustplatte mit Grat und Nieten, Schulterplatten mit
## Goldrand, Nasalhelm mit Helmkamm, Umhang. Sonderfarben bekommen Schmuck.
static func _tank(pu: Gliederpuppe, farbe: Color, sek: Color) -> Dictionary:
	var kb := _koerper(pu, {"bau": "keil", "rumpf": farbe, "hose": _p("eisen"), "stiefel": _p("eisen") * 0.7,
		"guertel": _p("leder") * 0.7})
	var ob: Bausatz = kb["ob"]
	var kz: Vector3 = kb["kz"]
	var kamm := _p("umhang")
	var umhang := _p("umhang")
	var niete := _p("messing")
	if farbe.is_equal_approx(_p("obsidian")):
		kamm = _p("glut")
	elif farbe.is_equal_approx(_p("silber")):
		kamm = _p("weiss")
	elif farbe.is_equal_approx(_p("bernstein")):
		niete = _p("gold")
	for name in ["smaragd", "rosenquarz", "mitternacht", "drachenblut"]:
		if farbe.is_equal_approx(_p(name)):
			umhang = _p(name) * 0.75
	# Brustplatte, Bauchschienen, Plattenrock
	ob.teil(Stil3D.box(0.32, 0.22, 0.06), farbe * 1.06, Vector3(0, 0.51, 0.205), Vector3(-12, 0, 0))
	ob.teil(Stil3D.box(0.035, 0.2, 0.07), farbe * 1.18, Vector3(0, 0.51, 0.22), Vector3(-12, 0, 0), false)
	# Messpunkt Brustplatte (Halbmaße 0.16/0.11/0.03, mit Grat vorn bis +0.05)
	_messen("brust", "", Transform3D(Basis.from_euler(Vector3(-12, 0, 0) * GRAD), _w(kb, Vector3(0, 0.51, 0.205))))
	for v in [Vector3(-0.12, 0.6, 0.22), Vector3(0.12, 0.6, 0.22), Vector3(-0.12, 0.43, 0.2), Vector3(0.12, 0.43, 0.2)]:
		ob.teil(Stil3D.kugel(0.016, -1, 6), niete, v, Vector3.ZERO, false)
	for i in 2:
		ob.teil(Stil3D.zylinder(0.198 + i * 0.006, 0.196 + i * 0.006, 0.035, 16), farbe * 0.8,
			Vector3(0, 0.39 - i * 0.04, 0), Vector3.ZERO, false)
	ob.teil(Stil3D.zylinder(0.2, 0.245, 0.1), farbe * 0.8, Vector3(0, 0.27, 0))
	# Schulterplatten (Breiten-Merkmal) mit Goldrand und Nieten
	for s in [-1.0, 1.0]:
		ob.teil(Stil3D.kugel(0.125, 0.15), farbe, Vector3(0.27 * s, 0.645, 0))
		ob.teil(Stil3D.zylinder(0.128, 0.128, 0.025, 14), _p("gold"), Vector3(0.27 * s, 0.6, 0), Vector3.ZERO, false)
		for z in [-0.05, 0.05]:
			ob.teil(Stil3D.kugel(0.016, -1, 6), niete, Vector3(0.3 * s, 0.7, z), Vector3.ZERO, false)
	# Umhang (Bahn + spitzer Saum), leicht ausgestellt
	ob.teil(Stil3D.box(0.42, 0.42, 0.03), umhang, Vector3(0, 0.42, -0.25), Vector3(12, 0, 0))
	ob.teil(Stil3D.prisma(0.42, 0.16, 0.03), umhang, Vector3(0, 0.13, -0.31), Vector3(192, 0, 0))
	# Gesicht frei, darüber der Nasalhelm mit Helmkamm. Der Helmrand deckt die
	# Stirn: keine Brauen darunter; Rand 0.02 höher, damit seine Hülle nicht
	# über die Augen-Oberkante (kz+0.065) läuft; Nasenschutz ohne Hülle (kein
	# Konturrahmen auf Auge und Wange), oben am Rand angesetzt.
	_gesicht_held(ob, kz, 8.0, "strich", false, false)
	var eisen := _p("eisen") * 1.1
	ob.teil(_halbkugel(0.232, 0.19), eisen, kz + Vector3(0, 0.115, -0.01))
	ob.teil(Stil3D.zylinder(0.236, 0.236, 0.05, 18), farbe, kz + Vector3(0, 0.12, -0.01))
	ob.teil(Stil3D.box(0.032, 0.11, 0.03), eisen, kz + Vector3(0, 0.05, 0.215), Vector3(-8, 0, 0), false)
	for s in [-1.0, 1.0]:
		ob.teil(Stil3D.prisma(0.1, 0.16, 0.03), eisen, kz + Vector3(0.2 * s, -0.01, 0.05), Vector3(180, -75 * s, 0))
	for i in 5:
		var w := (-55.0 + i * 27.0) * GRAD
		var fuss := kz + Vector3(0, 0.12 + cos(w) * 0.2, sin(w) * 0.2)
		ob.teil_t(Stil3D.kegel(0.036, 0.12 + 0.03 * float(i % 2), 8), kamm,
			Transform3D(Basis.from_euler(Vector3(w, 0, 0)), fuss + Basis.from_euler(Vector3(w, 0, 0)) * Vector3(0, 0.05, 0)))
	return kb


## Krieger: Kettenhemd mit Saum-Ringen, Wappenrock mit Goldsaum, Ketten-
## haube um das Gesicht, kleine Schulterkugeln.
static func _krieger(pu: Gliederpuppe, farbe: Color, sek: Color) -> Dictionary:
	var kette := _p("eisen") * 1.2
	var kb := _koerper(pu, {"rumpf": kette, "hose": _p("leder"), "stiefel": _p("leder") * 0.75,
		"guertel": _p("leder") * 0.7})
	var ob: Bausatz = kb["ob"]
	var kz: Vector3 = kb["kz"]
	for i in 10:
		var w := TAU * i / 10.0
		ob.teil(Stil3D.kugel(0.016, -1, 6), kette * 1.15, Vector3(sin(w) * 0.172, 0.3, cos(w) * 0.172), Vector3.ZERO, false)
	for z in [0.185, -0.185]:
		ob.teil(Stil3D.box(0.26, 0.38, 0.03), farbe, Vector3(0, 0.44, z), Vector3(-6.0 * signf(z), 0, 0))
		ob.teil(Stil3D.box(0.27, 0.035, 0.035), _p("gold"), Vector3(0, 0.26, z * 1.07), Vector3.ZERO, false)
	ob.teil(Stil3D.box(0.09, 0.09, 0.012), sek, Vector3(0, 0.5, 0.205), Vector3(0, 0, 45), false)
	for s in [-1.0, 1.0]:
		ob.teil(Stil3D.kugel(0.075), kette, Vector3(0.23 * s, 0.62, 0))
	# Kettenhaube: Kugel hinter dem Gesicht, Kragen bis zu den Schultern
	ob.teil(Stil3D.kugel(0.238, 0.5), kette * 1.04, kz + Vector3(0, 0.03, -0.075))
	ob.teil(Stil3D.zylinder(0.17, 0.25, 0.1), kette * 1.04, Vector3(0, 0.67, -0.01))
	ob.teil(_ring(0.15, 0.185, 20, 6), kette * 0.9, kz + Vector3(0, 0.0, 0.11), Vector3(80, 0, 0))
	_gesicht_held(ob, kz, 12.0, "strich")
	return kb


## Schurke/Jäger: schmal und vorgebeugt, Zipfelkapuze, Kreuzgurte mit
## Schnallen, Gürteltasche und Geldbeutel, Halstuch bei Dolchen, Köcher.
static func _schurke(pu: Gliederpuppe, farbe: Color, sek: Color, info: Dictionary) -> Dictionary:
	var wams := farbe * 0.85
	var kb := _koerper(pu, {"bau": "schmal", "neigung": 6.0, "rumpf": wams, "hose": _p("leder") * 0.8,
		"stiefel": _p("leder") * 0.6, "stulpe": true, "guertel": _p("leder") * 0.65})
	var ob: Bausatz = kb["ob"]
	var kz: Vector3 = kb["kz"]
	for s in [-1.0, 1.0]:
		ob.teil(Stil3D.box(0.032, 0.36, 0.02), _p("leder") * 0.7, Vector3(0.0, 0.48, 0.163), Vector3(0, 0, 36 * s), false)
	ob.teil(Stil3D.box(0.045, 0.045, 0.02), _p("messing"), Vector3(0, 0.48, 0.178), Vector3.ZERO, false)
	ob.teil(Stil3D.box(0.09, 0.08, 0.05), _p("leder") * 0.8, Vector3(0.12, 0.3, 0.1), Vector3(0, 30, 0))
	ob.teil(Stil3D.kugel(0.045, 0.07), _p("braun_hell"), Vector3(-0.12, 0.28, 0.11))
	var dolche: bool = info["waffe"] == "dolch"
	_gesicht_held(ob, kz, 14.0, "strich", dolche)
	if dolche:
		ob.teil(Stil3D.kugel(0.18, 0.2), farbe, kz + Vector3(0, -0.1, 0.06))
	_kapuze(ob, kz, _p("leder"), {"rand": farbe, "zipfel": 0.28})
	if info["waffe"] in ["bogen", "armbrust"] or info["neben"] == "koecher":
		_koecher(ob, Vector3(0.06, 0.6, -0.2), farbe)
	return kb


## Magier: Glockenrobe mit leuchtendem Goldsaum und Schärpe, Zauberhut mit
## nach hinten geknickter Spitze, Hutband mit Kristall, Haarsträhnen.
static func _magier(pu: Gliederpuppe, farbe: Color, sek: Color, haar: Color) -> Dictionary:
	var kb := _koerper(pu, {"bau": "glocke", "rumpf": farbe, "saum": _p("gold"), "saum_leuchten": 0.15})
	var ob: Bausatz = kb["ob"]
	var kz: Vector3 = kb["kz"]
	pu.rumpf.teil(Stil3D.zylinder(0.25, 0.26, 0.06, 16), sek, Vector3(0, 0.4, 0))
	pu.rumpf.teil(Stil3D.box(0.06, 0.2, 0.025), sek, Vector3(0.1, 0.28, 0.27), Vector3(-14, 0, 8))
	_gesicht_held(ob, kz, 4.0, "laecheln")
	_haare(ob, kz, haar, 0, true)
	ob.teil(Stil3D.zylinder(0.3, 0.3, 0.03, 20), farbe * 0.85, kz + Vector3(0, 0.15, 0))
	var hut := _t(kz + Vector3(0, 0.16, -0.01))
	ob.teil_t(Stil3D.zylinder(0.13, 0.18, 0.2, 14), farbe * 0.85, _at(hut, Vector3(0, 0.1, 0)))
	ob.teil_t(Stil3D.zylinder(0.185, 0.185, 0.04, 14), _p("gold"), _at(hut, Vector3(0, 0.03, 0)), false)
	ob.teil_t(Stil3D.prisma(0.05, 0.07, 0.03), _p("kristall"), _at(hut, Vector3(0, 0.04, 0.18)), false, 0.6)
	Gliederpuppe.kette(ob, _at(hut, Vector3(0, 0.19, 0)), 2, 0.3, 0.13, 0.01, Vector3(-32, 0, 0), farbe * 0.85)
	return kb


## Heiler: Glockenrobe mit weißer Stola und Goldkreuz, Haube, schwebender
## leuchtender Goldreif über dem Kopf, freundliche Brauen, Lächeln.
static func _heiler(pu: Gliederpuppe, farbe: Color, sek: Color, haar: Color) -> Dictionary:
	var kb := _koerper(pu, {"bau": "glocke", "rumpf": farbe, "saum": _p("weiss"), "saum_leuchten": 0.1})
	var ob: Bausatz = kb["ob"]
	var kz: Vector3 = kb["kz"]
	var b := pu.rumpf
	for s in [-1.0, 1.0]:
		b.teil(Stil3D.box(0.06, 0.56, 0.02), _p("weiss"), Vector3(0.05 * s, 0.29, 0.262), Vector3(-14, 0, 0), false)
		ob.teil(Stil3D.box(0.06, 0.14, 0.02), _p("weiss"), Vector3(0.05 * s, 0.6, 0.198), Vector3(-3, 0, 0), false)
	b.teil(Stil3D.box(0.035, 0.12, 0.012), _p("gold"), Vector3(0, 0.28, 0.275), Vector3(-14, 0, 0), false, 0.2)
	b.teil(Stil3D.box(0.09, 0.03, 0.012), _p("gold"), Vector3(0, 0.3, 0.27), Vector3(-14, 0, 0), false, 0.2)
	pu.rumpf.teil(Stil3D.zylinder(0.25, 0.26, 0.05, 16), sek, Vector3(0, 0.4, 0))
	_gesicht_held(ob, kz, -6.0, "laecheln")
	_haare(ob, kz, haar, 0, true)
	ob.teil(Stil3D.zylinder(0.218, 0.222, 0.08, 18), _p("weiss"), kz + Vector3(0, 0.1, -0.02), Vector3(-12, 0, 0))
	ob.teil(_halbkugel(0.21, 0.16), _p("weiss") * 0.94, kz + Vector3(0, 0.12, -0.03), Vector3(-12, 0, 0))
	ob.teil(_ring(0.15, 0.185, 28, 6), _p("gold"), kz + Vector3(0, 0.36, -0.02), Vector3(-10, 0, 0), false, 0.4)
	return kb


## Abenteurer (ohne Rüstung): Hemd in der Rüstungsfarbe, Weste, Halstuch,
## eine von drei Frisuren.
static func _abenteurer(pu: Gliederpuppe, farbe: Color, sek: Color, haar: Color, frisur: int) -> Dictionary:
	var kb := _koerper(pu, {"rumpf": farbe, "hose": _p("braun"), "stiefel": _p("leder") * 0.7})
	var ob: Bausatz = kb["ob"]
	var kz: Vector3 = kb["kz"]
	for s in [-1.0, 1.0]:
		ob.teil(Stil3D.box(0.11, 0.27, 0.03), sek, Vector3(0.085 * s, 0.49, 0.188), Vector3(-5, 0, 0))
	ob.teil(Stil3D.prisma(0.16, 0.09, 0.04), _p("umhang"), Vector3(0, 0.6, 0.2), Vector3(180, 0, 0))
	_gesicht_held(ob, kz, 8.0, "laecheln")
	_haare(ob, kz, haar, frisur, false, _p("umhang"))
	return kb


## Handziele (Oberkörper-Maße) je Körperbau: Zweihand-Querhaltung (rechte
## Hand am Griffende, linke höher am Griff), Rundschild- und Turmschild-Hand.
## Die Arme zeigen per _ruhe_zu darauf, die Hände liegen auf Armlänge.
const HAND_ZIELE := {
	"normal": {"zh_r": Vector3(0.15, 0.46, 0.2), "zh_l": Vector3(-0.08, 0.6, 0.25),
		"schild": Vector3(-0.25, 0.47, 0.2)},
	# Keil (Tank): Hände weit vorn, der Griff läuft VOR Brustplatte, Grat und
	# Rumpf (Brustplatte vorn bis z 0.257, Rumpf oben r 0.25), flacher steigend.
	"keil": {"zh_r": Vector3(0.17, 0.548, 0.258), "zh_l": Vector3(-0.118, 0.628, 0.283),
		"schild": Vector3(-0.29, 0.52, 0.22)},
	"schmal": {"zh_r": Vector3(0.13, 0.46, 0.18), "zh_l": Vector3(-0.07, 0.55, 0.22),
		"schild": Vector3(-0.22, 0.47, 0.19)},
	"glocke": {"zh_r": Vector3(0.15, 0.46, 0.2), "zh_l": Vector3(-0.08, 0.6, 0.25),
		"schild": Vector3(-0.25, 0.52, 0.22)},
}

## Länge des Nebenarms am Zweihandgriff (sonst 0.26): erst so reicht die
## linke Hand vor der Brust an den Griff (Schultern ±0.22, Brust r 0.2).
const ZWEIHAND_ARM_L := 0.3
## Keil-Rumpf (Tank, Schultern ±0.26, Brustplatte bis z 0.257): beide Arme
## länger [rechts, links], sonst liegt der Griff in der Brustplatte.
const ZWEIHAND_ARME_KEIL := [0.3, 0.34]

## Stabrichtung beim Keil-Rumpf (Tank mit Stab): nach vorn und außen
## geneigt, an Schulterplatte und Goldrand vorbei (Ruhe −32/0/24).
const STAB_KEIL := Vector3(0.06, 1, 0.16)


## Arme und Waffen der Helden nach Ausrüstung.
static func _held_bewaffnen(pu: Gliederpuppe, kb: Dictionary, farbe: Color, sek: Color, info: Dictionary,
		arm_farbe: Color, hand: Color) -> void:
	var waffe := String(info["waffe"])
	var neben := String(info["neben"])
	var bau: String = {"tank": "keil", "schurke": "schmal", "magier": "glocke", "heiler": "glocke"}.get(
		info["rolle"], "normal")
	var ziele: Dictionary = HAND_ZIELE[bau]
	var schulter_r := _w(kb, Vector3(kb["sx"], kb["sy"], 0))
	var schulter_l := _w(kb, Vector3(-kb["sx"], kb["sy"], 0))
	var zweihand := waffe in ["grossschwert", "grossaxt", "hammer"]
	var ruhe_r := Vector3(-22, 0, 12)
	var ruhe_l := Vector3(-8, 0, -12)
	match waffe:
		"grossschwert", "grossaxt", "hammer":
			ruhe_r = _ruhe_zu(schulter_r, _w(kb, ziele["zh_r"]))
			ruhe_l = _ruhe_zu(schulter_l, _w(kb, ziele["zh_l"]))
		"dolch":
			ruhe_r = Vector3(-30, 0, 16)
		"bogen":
			ruhe_l = Vector3(-38, 0, -14)
			ruhe_r = Vector3(-6, 0, 12)
		"armbrust":  # Pistolengriff rechts, linke Hand frei neben dem Körper
			ruhe_r = Vector3(-58, 0, -4)
		"kristallstab", "ringstab":
			# Keil-Rumpf: Hand weiter außen und vorn, Stab an der Schulterplatte vorbei
			ruhe_r = Vector3(-32, 0, 24) if bau == "keil" else Vector3(-12, 0, 14)
		"turmschild":
			ruhe_l = Vector3(-66, 0, -2)
			ruhe_r = Vector3(-8, 0, 12)
	match neben:
		"schild":
			ruhe_l = _ruhe_zu(schulter_l, _w(kb, ziele["schild"]))
		"dolch":
			ruhe_l = Vector3(-30, 0, -16)
		"buch", "kreuz":
			ruhe_l = Vector3(-50, 0, -8)
		"fokus":
			ruhe_l = Vector3(-58, 0, -12)
	if neben == "" and info["rolle"] == "heiler":
		ruhe_l = Vector3(-52, 0, -10)
	var o := {"farbe": arm_farbe, "hand": hand}
	if zweihand:
		o["laenge_l"] = ZWEIHAND_ARM_L
		if bau == "keil":
			o["laenge"] = ZWEIHAND_ARME_KEIL[0]
			o["laenge_l"] = ZWEIHAND_ARME_KEIL[1]
	var robe: bool = info["rolle"] in ["magier", "heiler"]
	var arme := _arme(pu, kb, ruhe_r, ruhe_l, o)
	var ar: Dictionary = arme[0]
	var al: Dictionary = arme[1]
	for arm in arme:
		var b: Bausatz = arm["b"]
		if robe:  # Trompeten-Ärmel: eng an der Schulter, weit zur Hand hin, Saum am weiten Ende
			b.teil(Stil3D.zylinder(0.06, 0.105, 0.2, 12), farbe, Vector3(0, -0.15, 0))
			b.teil(Stil3D.zylinder(0.11, 0.11, 0.025, 12), _p("gold") if info["rolle"] == "magier" else _p("weiss"),
				Vector3(0, -0.245, 0), Vector3.ZERO, false)
		elif info["rolle"] == "schurke":
			b.teil(Stil3D.zylinder(0.066, 0.07, 0.1, 10), _p("leder"), Vector3(0, -0.17, 0))
		elif info["rolle"] == "tank":
			b.teil(Stil3D.zylinder(0.07, 0.072, 0.08, 10), _p("eisen") * 1.1, Vector3(0, -0.18, 0))
	_messen("hand_r", "arm_r", ar["hand"], 0.06)
	_messen("hand_l", "arm_l", al["hand"], 0.06)
	var vorn := Vector3(0.12, 0.8, 0.58)
	var rb: Bausatz = ar["b"]
	var lb: Bausatz = al["b"]
	# Zweihandgriff: Achse von der rechten durch die linke Handmitte.
	var griff := _hand_welt(al) - _hand_welt(ar)
	var wt := Transform3D()
	match waffe:
		"schwert":
			wt = _lage(ar, vorn)
			_schwert(rb, wt, 0.48)
		"grossschwert":
			wt = _lage(ar, griff)
			_schwert(rb, wt, 0.6, Color.WHITE, {"griff": griff.length()})
		"dolch":
			wt = _lage(ar, Vector3(0.12, -0.45, 0.88))
			_dolch(rb, wt)
		"axt":
			wt = _lage(ar, vorn)
			_axt(rb, wt)
		"grossaxt":  # Griff 0.1 tiefer gefasst: das Doppelblatt bleibt neben dem Gesicht
			wt = _lage(ar, griff)
			_axt(rb, _at(wt, Vector3(0, 0.1, 0)), true)
		"keule":
			wt = _lage(ar, vorn)
			_keule(rb, wt)
		"hammer":
			wt = _lage(ar, griff)
			_keule(rb, wt, true)
		"bogen":
			wt = _lage(al, Vector3(0, 0.9, 0.4), Vector3.RIGHT)
			_bogen(lb, wt, farbe)  # vorgeneigt: beim Spannen senkrecht
		"armbrust":  # quer = links: Bolzenschiene und Sehne oben, Schaft durch die Hand
			wt = _lage(ar, Vector3(-0.1, 0.05, 1.0), Vector3.LEFT, Vector3(0, 0.01, -0.04))
			_armbrust(rb, wt)
		"turmschild":  # flach vor der Brust, Hand direkt hinter dem Schild
			wt = _lage(al, Vector3(0, 1, 0), Vector3(1, 0, -0.06), Vector3(0.03, -0.1, 0.105))
			_turmschild(lb, wt, sek)
		"kristallstab":
			wt = _lage(ar, STAB_KEIL if bau == "keil" else Vector3(0, 1, 0.06))
			_kristallstab(rb, wt, info["licht"], farbe)
		"ringstab":
			wt = _lage(ar, STAB_KEIL if bau == "keil" else Vector3(0, 1, 0.06))
			_ringstab(rb, wt)
	if waffe != "":
		_messen("waffe", "arm_l" if waffe in ["bogen", "turmschild"] else "arm_r", wt)
	match neben:
		"schild":  # Scheibe vor der Kleidung, Hand direkt dahinter
			var st := _lage(al, Vector3(0, 1, 0), Vector3(0.985, 0, -0.17), Vector3(0, 0.02, 0.09))
			_messen("schild", "arm_l", st, 0.2)
			_schild_rund(lb, st, farbe * 1.08 if farbe.get_luminance() < 0.6 else farbe, sek)
		"dolch":
			_dolch(lb, _lage(al, Vector3(-0.12, -0.45, 0.88)))
		"buch":  # quer = links: Seiten oben, Deckel als V
			var t := _lage(al, Vector3(0, 0.3, 1), Vector3.LEFT, Vector3(0, 0.05, 0.06))
			_messen("buch", "arm_l", t)
			for s in [-1.0, 1.0]:
				lb.teil_t(Stil3D.box(0.12, 0.17, 0.02), _p("daemon_dunkel"), _at(t, Vector3(0.06 * s, 0, 0), Vector3(0, -25 * s, 0)))
				lb.teil_t(Stil3D.box(0.1, 0.15, 0.012), _p("weiss"), _at(t, Vector3(0.055 * s, 0, 0.018), Vector3(0, -25 * s, 0)), false)
			lb.teil_t(Stil3D.box(0.02, 0.16, 0.03), _p("gold"), t, false)
		"fokus":
			lb.teil(Stil3D.kugel(0.065, -1, 12), info["licht"], (al["hand"] as Vector3) + Basis.from_euler(ruhe_l * GRAD).inverse()
				* Vector3(0, 0.14, 0.02), Vector3.ZERO, true, 0.8)
		"kreuz":  # hängt lotrecht unter der Hand (Gegendrehung ri wie die Perlen)
			var h: Vector3 = al["hand"]
			var ri := Basis.from_euler(ruhe_l * GRAD).inverse()
			for i in 3:
				lb.teil(Stil3D.kugel(0.014, -1, 6), _p("gold"), h + ri * Vector3(0, -0.05 - i * 0.03, 0.02), Vector3.ZERO, false)
			var kreuz := h + ri * Vector3(0, -0.18, 0.02)
			_messen("kreuz", "arm_l", Transform3D(ri, kreuz))
			lb.teil_t(Stil3D.box(0.025, 0.11, 0.02), _p("gold"), Transform3D(ri, kreuz), true, 0.3)
			lb.teil_t(Stil3D.box(0.07, 0.025, 0.02), _p("gold"), Transform3D(ri, kreuz + ri * Vector3(0, 0.025, 0)), true, 0.3)


# --- Gegner -----------------------------------------------------------------------

## Gegner-Figur aus dem Mesh-Cache (Schlüssel Art | Größe | Boss | Akzent |
## Mal). variante = Akzent-Kennung (FigurenBau.akzent_kennung): Klassen-
## Variante bzw. Element-Schicht leuchten als Gürtelstein bzw. Robenstein
## (_koerper) in ihrer Farbe — auch wenn Elite die Augen lila färbt.
static func gegner(id: StringName, massstab := 1.0, boss := false, akzent: Variant = null,
		variante := "") -> Node3D:
	var g := float(GROESSE.get(id, 1.0)) * massstab
	var mal: Variant = FigurenBau.kennung_farbe(variante)
	var key := "zb|%s|%.3f|%s|%s|%s" % [id, g, boss, (akzent as Color).to_html(false) if akzent != null else "-",
		(mal as Color).to_html(false) if mal != null else "-"]
	var k := {"boss": boss, "akzent": akzent, "mal": mal}
	return Gliederpuppe.gebacken(key, func() -> Gliederpuppe: return gegner_puppe(id, g, k))


static func gegner_puppe(id: StringName, g: float, k: Dictionary) -> Gliederpuppe:
	var pu := Gliederpuppe.new(String(id).capitalize(), g)
	pu.meta("wippen", 0.012).meta("drehung", 12.0).meta("anim", String(id))
	messpunkte = {}
	_mal = k.get("mal")  # liest _koerper beim Bau dieser Figur
	_gegner_bauen(pu, id, k)
	_mal = null
	return pu


## Leuchtmal (Farbe) der Figur, die gerade gebaut wird (gegner_puppe).
static var _mal: Variant = null


static func _gegner_bauen(pu: Gliederpuppe, id: StringName, k: Dictionary) -> void:
	match id:
		&"bandit":
			_bandit(pu, k)
		&"kultist":
			_kultist(pu, k)
		&"nekromant":
			_nekromant(pu, k)
		&"skelett":
			_skelett(pu, k)
		&"toddiener":
			_toddiener(pu, k)
		&"schattenkrieger":
			_schattenkrieger(pu, k)
		&"todesmeister":
			_todesmeister(pu, k)
		&"kleindaemon":
			_kleindaemon(pu, k)
		&"demonenbeschwoerer":
			_beschwoerer(pu, k)
		&"demonenkonig":
			_daemonenfuerst(pu, k)
		&"pilzhexe":
			_pilzhexe(pu, k)
		&"hexenmeisterin":
			_hexe(pu, k)


## Bandit: geduckter Strauchdieb, Kapuze mit langem Zipfel, wehender Schal,
## Gesichtstuch bis unter die schmalen bösen Augen, krumme Dolche.
static func _bandit(pu: Gliederpuppe, k: Dictionary) -> void:
	var kb := _koerper(pu, {"bau": "schmal", "beine": 0.85, "neigung": 10.0, "rumpf": _p("leder"),
		"hose": _p("braun") * 0.8, "stiefel": _p("leder") * 0.55, "stulpe": true, "guertel": _p("leder") * 0.6})
	var ob: Bausatz = kb["ob"]
	var kz: Vector3 = kb["kz"]
	ob.teil(Stil3D.box(0.035, 0.38, 0.02), _p("leder") * 0.65, Vector3(0, 0.48, 0.165), Vector3(0, 0, 34), false)
	ob.teil(Stil3D.box(0.045, 0.045, 0.02), _p("messing"), Vector3(-0.03, 0.52, 0.178), Vector3.ZERO, false)
	ob.teil(Stil3D.kugel(0.06, 0.09), _p("braun_hell"), Vector3(-0.13, 0.28, 0.1))
	ob.teil(Stil3D.zylinder(0.035, 0.035, 0.012, 10), _p("gold"), Vector3(-0.13, 0.27, 0.165), Vector3(90, 0, 0), false, 0.2)
	var auge := _glut(k, Color.TRANSPARENT)
	for s in [-1.0, 1.0]:
		var o := {"seite": s, "hoch": 0.62}
		if auge.a > 0.0:
			o["iris"] = auge
			o["iris_leuchten"] = 0.8
		Gliederpuppe.auge(ob, kz + Vector3(0.072 * s, 0.03, 0.172), 0.048, o)
		Gliederpuppe.braue(ob, kz + Vector3(0.072 * s, 0.083, 0.193), 0.075, s, 25.0)
	ob.teil(Stil3D.kugel(0.19, 0.22), _p("schwarz") * 1.3, kz + Vector3(0, -0.085, 0.05))
	_kapuze(ob, kz, _p("braun"), {"zipfel": 0.34, "rand": _p("braun") * 0.75, "kragen": true})
	var schal := _p("umhang") * 0.7
	ob.teil(Stil3D.zylinder(0.2, 0.17, 0.08, 10), schal, Vector3(0, 0.66, 0))
	ob.teil(Stil3D.prisma(0.1, 0.32, 0.025), schal, Vector3(0.2, 0.52, -0.14), Vector3(170, 30, 35))
	ob.teil(Stil3D.prisma(0.08, 0.22, 0.025), schal, Vector3(0.24, 0.6, -0.1), Vector3(160, 50, 70))
	var arme := _arme(pu, kb, Vector3(-38, 0, 16), Vector3(-38, 0, -16), {"farbe": _p("leder") * 1.1,
		"hand": _p("leder") * 0.6, "r": 0.05})
	_dolch(arme[0]["b"], _lage(arme[0], Vector3(0.15, -0.4, 0.9)), true)
	_dolch(arme[1]["b"], _lage(arme[1], Vector3(-0.15, -0.4, 0.9)), true)
	_fertig(pu, kb, 0.27)


## Kultist: kurze breite Robe mit Glut-Runen im Saum, tiefe Kapuze mit
## schwarzem Loch und Glühaugen, Kordelgürtel mit Augen-Amulett, Kerze.
static func _kultist(pu: Gliederpuppe, k: Dictionary) -> void:
	var kb := _koerper(pu, {"bau": "glocke", "robe_unten": 0.3, "robe_h": 0.52, "rumpf": _p("robe_lila"),
		"saum": _p("lila_dunkel"), "haut": _p("schwarz"), "kopf_r": 0.19})
	var b := pu.rumpf
	var ob: Bausatz = kb["ob"]
	var kz: Vector3 = kb["kz"]
	for i in 7:
		var w := (-60.0 + i * 20.0) * GRAD
		b.teil(Stil3D.box(0.035, 0.05, 0.015), _p("daemon"), Vector3(sin(w) * 0.31, 0.06, cos(w) * 0.31),
			Vector3(-6, rad_to_deg(w), 0), false, 0.5)
	for s in [-1.0, 1.0]:
		_strebe(b, Vector3(0, 0.42, 0.25), Vector3(0.24 * s, 0.4, 0.04), 0.018, _p("gold") * 0.8)
	b.teil(_ring(0.03, 0.045, 12, 4), _p("messing"), Vector3(0, 0.38, 0.265), Vector3(80, 0, 0), false)
	b.teil(Stil3D.kugel(0.032, -1, 8), _p("glut"), Vector3(0, 0.38, 0.268), Vector3.ZERO, false, 0.6)
	ob.teil(Stil3D.kugel(0.25, 0.52), _p("robe_lila"), kz + Vector3(0, 0.03, -0.08))
	_strebe(ob, kz + Vector3(0, 0.08, -0.28), kz + Vector3(0, -0.12, -0.35), 0.075, _p("robe_lila"))
	ob.teil(_ring(0.13, 0.175, 20, 6), _p("robe_lila") * 1.12, kz + Vector3(0, 0, 0.16), Vector3(84, 0, 0))
	ob.teil_t(Stil3D.kugel(0.135), _p("schwarz"), Transform3D(Basis.from_scale(Vector3(1, 1.15, 0.45)),
		kz + Vector3(0, -0.01, 0.135)), false)
	var glut := _glut(k, _p("daemon"))
	for s in [-1.0, 1.0]:
		ob.teil(Stil3D.kugel(0.034, 0.05, 8), glut, kz + Vector3(0.06 * s, 0.01, 0.19), Vector3(0, 0, -20 * s),
			false, 0.9)
	var arme := _arme(pu, kb, Vector3(-50, -25, 4), Vector3(-50, 25, -4), {"farbe": _p("robe_lila"),
		"hand": _p("fahl")})
	for arm in arme:
		(arm["b"] as Bausatz).teil(Stil3D.zylinder(0.095, 0.06, 0.18, 10), _p("robe_lila"), Vector3(0, -0.15, 0))
	var t := _lage(arme[0], Vector3.UP, Vector3.RIGHT, Vector3(-0.03, 0.05, 0.02))
	_messen("waffe", "arm_r", t)
	_messen("kopf", "", kz + Vector3(0, 0.03, -0.08), 0.25)  # Kapuzenkugel
	(arme[0]["b"] as Bausatz).teil_t(Stil3D.zylinder(0.03, 0.032, 0.13, 10), _p("kerze"), _at(t, Vector3(0, 0.03, 0)))
	(arme[0]["b"] as Bausatz).teil_t(Stil3D.kugel(0.03, 0.08, 8), _p("flamme"), _at(t, Vector3(0, 0.14, 0)), false, 1.0)
	(arme[0]["b"] as Bausatz).teil_t(Stil3D.kugel(0.016, 0.04, 6), _p("glut"), _at(t, Vector3(0, 0.13, 0.012)), false, 1.0)
	_fertig(pu, kb, 0.27)


## Nekromant: hohe schmale Robe mit Seelen-Saum, Stehkragen-Fächer, Rippen
## auf den Schultern, hageres Gesicht mit Glühaugen, Schädelstab, Krallen.
static func _nekromant(pu: Gliederpuppe, k: Dictionary) -> void:
	var seele := _glut(k, _p("seele"))
	var kb := _koerper(pu, {"bau": "glocke", "robe_unten": 0.27, "robe_h": 0.62, "rumpf": _p("robe_schwarz"),
		"saum": seele, "saum_leuchten": 0.3, "haut": _p("fahl"), "kopf_r": 0.175, "kopf_h": 0.42})
	var b := pu.rumpf
	var ob: Bausatz = kb["ob"]
	var kz: Vector3 = kb["kz"]
	for i in 5:
		var w := (-60.0 + i * 30.0)
		ob.teil(Stil3D.prisma(0.12, 0.34 - absf(w) * 0.0015, 0.025), _p("robe_schwarz") * 1.25,
			Vector3(sin(w * GRAD) * 0.16, 0.86, -0.15), Vector3(-15, 0, -w))
	for s in [-1.0, 1.0]:
		for i in 3:
			_strebe(ob, Vector3(0.1 * s, 0.66 - i * 0.012, 0.07 - i * 0.07), Vector3(0.27 * s, 0.6 - i * 0.012, 0.05 - i * 0.07),
				0.018, _p("knochen"))
	ob.teil(Stil3D.kugel(0.17, 0.12), _p("robe_schwarz") * 1.1, kz + Vector3(0, -0.08, -0.16))
	var o := {"hohl": true, "iris": seele, "iris_leuchten": 0.9}
	for s in [-1.0, 1.0]:
		o["seite"] = s
		Gliederpuppe.auge(ob, kz + Vector3(0.062 * s, 0.04, 0.14), 0.042, o)
		Gliederpuppe.braue(ob, kz + Vector3(0.065 * s, 0.1, 0.155), 0.06, s, 25.0)
	ob.teil(Stil3D.kegel(0.07, 0.12, 10), _p("fahl"), kz + Vector3(0, -0.2, 0.06), Vector3(160, 0, 0))
	Gliederpuppe.mund(ob, kz + Vector3(0, -0.1, 0.16), 0.05, "strich")
	for s in [-1.0, 1.0]:
		var schaedel := Vector3(0.11 * s, 0.38, 0.235)
		b.teil(Stil3D.kugel(0.042, -1, 8), _p("knochen"), schaedel)
		for x in [-0.014, 0.014]:
			b.teil(Stil3D.kugel(0.011, -1, 6), _p("schwarz"), schaedel + Vector3(x, 0.006, 0.036), Vector3.ZERO, false)
	b.teil(Stil3D.zylinder(0.24, 0.245, 0.05, 16), _p("robe_schwarz") * 1.4, Vector3(0, 0.4, 0))
	var arme := _arme(pu, kb, Vector3(-14, 0, 14), Vector3(-45, 10, -16), {"farbe": _p("robe_schwarz") * 1.15,
		"hand": _p("fahl"), "r": 0.05, "hand_r": 0.05})
	var rb: Bausatz = arme[0]["b"]
	var t := _lage(arme[0], Vector3(0, 1, 0.05))
	_messen("waffe", "arm_r", t)
	_messen("kopf", "", kz, 0.175)
	_strebe(rb, t * Vector3(0.0, -0.3, 0), t * Vector3(0.02, 0.35, 0), 0.026, _p("holz") * 0.7, true, true)
	_strebe(rb, t * Vector3(0.02, 0.35, 0), t * Vector3(-0.02, 0.72, 0), 0.024, _p("holz") * 0.7, true, true)
	rb.teil_t(Stil3D.kugel(0.075, 0.13), _p("knochen"), _at(t, Vector3(-0.02, 0.8, 0)))
	for x in [-0.03, 0.03]:
		rb.teil_t(Stil3D.kugel(0.018, -1, 6), seele, _at(t, Vector3(-0.02 + x, 0.81, 0.06)), false, 0.9)
	rb.teil_t(Stil3D.prisma(0.06, 0.1, 0.06), seele, _at(t, Vector3(-0.02, 0.98, 0)), false, 0.9)
	var lb: Bausatz = arme[1]["b"]
	var h: Vector3 = arme[1]["hand"]
	for i in 3:
		var w := (-30.0 + i * 30.0) * GRAD
		_strebe(lb, h, h + Vector3(sin(w) * 0.08, -0.07, 0.03), 0.012, _p("fahl"))
	_fertig(pu, kb, 0.24)


## Skelett: durchbrochene Silhouette (Wirbelsäule, Rippenbögen, Becken,
## dünne Knochen mit Gelenkkugeln), großer Schädel mit Glühaugen und
## separatem Kiefer, Lendenschurz, rostiges Schwert, Plankenschild.
static func _skelett(pu: Gliederpuppe, k: Dictionary) -> void:
	var kn := _p("knochen")
	var b := pu.rumpf
	for s in [-1.0, 1.0]:
		var x: float = 0.08 * s
		_strebe(b, Vector3(x, 0.32, 0), Vector3(x, 0.18, 0.01), 0.03, kn)
		b.teil(Stil3D.kugel(0.038, -1, 8), kn, Vector3(x, 0.18, 0.01))
		_strebe(b, Vector3(x, 0.18, 0.01), Vector3(x, 0.05, 0), 0.026, kn)
		b.teil(Stil3D.box(0.07, 0.04, 0.12), kn * 0.95, Vector3(x, 0.025, 0.03))
	b.teil(Stil3D.box(0.24, 0.08, 0.12), kn * 0.92, Vector3(0, 0.33, 0))
	b.teil(Stil3D.prisma(0.16, 0.18, 0.02), _p("robe_schwarz"), Vector3(0.04, 0.22, 0.07), Vector3(180, 0, 6))
	b.teil(Stil3D.prisma(0.12, 0.14, 0.02), _p("robe_schwarz"), Vector3(-0.07, 0.24, 0.068), Vector3(180, 0, -10))
	for i in 4:
		b.teil(Stil3D.kugel(0.036, -1, 8), kn, Vector3(0, 0.39 + i * 0.065, -0.05))
	for i in 3:
		var r := 0.16 - i * 0.022
		b.teil_t(_ring(r - 0.026, r, 16, 4), kn, Transform3D(Basis.from_scale(Vector3(1, 1, 0.75)),
			Vector3(0, 0.6 - i * 0.07, 0)))
	b.teil(Stil3D.zylinder(0.03, 0.03, 0.26, 8), kn, Vector3(0, 0.64, 0), Vector3(0, 0, 90))
	# Schädel mit Wangenbein, Höhlen, Nasenloch, Zahnreihe; Kiefer separat
	var kz := Vector3(0, 0.88, 0)
	b.teil(Stil3D.kugel(0.21, 0.4), kn, kz)
	b.teil(Stil3D.box(0.3, 0.07, 0.14), kn * 0.96, kz + Vector3(0, -0.07, 0.08))
	var glut := _glut(k, _p("daemon"))
	for s in [-1.0, 1.0]:
		Gliederpuppe.auge(b, kz + Vector3(0.075 * s, 0.0, 0.15), 0.06, {"hohl": true, "iris": glut, "seite": s})
	b.teil(Stil3D.prisma(0.04, 0.05, 0.02), _p("schwarz"), kz + Vector3(0, -0.06, 0.205), Vector3.ZERO, false)
	for i in 6:
		b.teil(Stil3D.box(0.024, 0.032, 0.02), kn * 1.05, kz + Vector3(-0.06 + i * 0.024, -0.12, 0.168), Vector3.ZERO, false)
	var kiefer := pu.glied("kiefer", kz + Vector3(0, -0.11, -0.04))
	kiefer.teil(Stil3D.box(0.22, 0.06, 0.2), kn * 0.94, Vector3(0, -0.04, 0.1))
	for i in 5:
		kiefer.teil(Stil3D.box(0.024, 0.028, 0.02), kn * 1.05, Vector3(-0.048 + i * 0.024, -0.005, 0.19), Vector3.ZERO, false)
	pu.meta("anker_kopf", kz + Vector3(0, 0.22, 0)).meta("anker_ruecken", Vector3(0, 0.55, -0.15))
	pu.meta("brust_y", 0.36)
	# Arme dünn mit Ellbogen und Knochenhand
	var arme := []
	for s in [1.0, -1.0]:
		var arm := pu.glied("arm_r" if s > 0 else "arm_l", Vector3(0.15 * s, 0.64, 0), Vector3(-20, 0, 10 * s))
		_strebe(arm, Vector3(0, 0, 0), Vector3(0, -0.13, 0), 0.026, kn)
		arm.teil(Stil3D.kugel(0.034, -1, 8), kn, Vector3(0, -0.13, 0))
		_strebe(arm, Vector3(0, -0.13, 0), Vector3(0, -0.25, 0.02), 0.022, kn)
		arm.teil(Stil3D.kugel(0.045, -1, 8), kn, Vector3(0, -0.27, 0.02))
		arme.append({"b": arm, "hand": Vector3(0, -0.27, 0.02), "ruhe": Vector3(-20, 0, 10 * s)})
	var rost := _p("eisen") * 0.85
	var t := _lage(arme[0], Vector3(0.1, 0.8, 0.6))
	_messen("waffe", "arm_r", t)
	_messen("kopf", "", kz, 0.21)
	_schwert(arme[0]["b"], t, 0.44, rost, {"parier": _p("eisen") * 0.7, "grat": rost * 0.8})
	for v in [Vector3(0.028, 0.3, 0), Vector3(-0.028, 0.42, 0)]:
		(arme[0]["b"] as Bausatz).teil_t(Stil3D.prisma(0.02, 0.03, 0.022), _p("schwarz"), _at(t, v, Vector3(0, 0, 90 * signf(v.x))), false)
	(arme[0]["b"] as Bausatz).teil_t(Stil3D.box(0.04, 0.06, 0.021), _p("braun"), _at(t, Vector3(0.006, 0.22, 0)), false)
	var ts := _lage(arme[1], Vector3.UP, Vector3(0.94, 0, -0.34), Vector3(0.02, 0.03, 0.08))
	_messen("schild", "arm_l", ts)
	var lb: Bausatz = arme[1]["b"]
	for i in 3:
		var hoch := 0.38 if i < 2 else 0.28
		lb.teil_t(Stil3D.box(0.12, hoch, 0.035), _p("holz") * (1.0 if i % 2 == 0 else 0.88),
			_at(ts, Vector3(-0.12 + i * 0.12, (0.38 - hoch) * 0.5 if i == 2 else 0.0, 0)))
	lb.teil_t(Stil3D.kugel(0.05, 0.05, 10), _p("eisen"), _at(ts, Vector3(0, 0, 0.02)))


## Toddiener: schiefer Gruft-Laternenträger mit Buckel, zerlumpter Livree,
## asymmetrischem Gesicht (ein großes Glühauge), Zombie-Griff und Laterne.
static func _toddiener(pu: Gliederpuppe, k: Dictionary) -> void:
	var seele := _glut(k, _p("seele"))
	var kb := _koerper(pu, {"rumpf": _p("leder"), "hose": _p("schwarz") * 1.4, "stiefel": _p("leder") * 0.6,
		"haut": _p("fahl"), "neigung": 18.0, "seitlich": -8.0, "kopf_glied": true, "guertel": _p("braun")})
	var ob: Bausatz = kb["ob"]
	var b := pu.rumpf
	var kopf: Bausatz = kb["kb"]
	var kz: Vector3 = kb["kz"]
	ob.teil(Stil3D.kugel(0.15, 0.2), _p("leder") * 0.9, Vector3(0.04, 0.6, -0.12))
	ob.teil(Stil3D.box(0.08, 0.08, 0.02), _p("robe_lila") * 0.8, Vector3(0.08, 0.48, 0.18), Vector3(0, 0, 12), false)
	ob.teil(Stil3D.box(0.06, 0.07, 0.02), _p("braun_hell"), Vector3(-0.1, 0.4, 0.17), Vector3(0, 0, -20), false)
	for i in 5:
		var w := TAU * i / 5.0
		ob.teil(Stil3D.prisma(0.07, 0.08, 0.02), _p("leder"), Vector3(sin(w) * 0.17, 0.3, cos(w) * 0.17),
			Vector3(180, rad_to_deg(w), 0))
	b.teil(Stil3D.zylinder(0.065, 0.062, 0.06, 8), _p("weiss") * 0.85, Vector3(0.075, 0.11, 0))
	# Gesicht: großes Glühauge, kleines Auge, offener Mund, Stirnnaht, Strähnen
	Gliederpuppe.auge(kopf, kz + Vector3(-0.07, 0.03, 0.15), 0.06, {"hohl": true, "iris": seele, "seite": -1.0})
	Gliederpuppe.auge(kopf, kz + Vector3(0.08, 0.0, 0.17), 0.032, {"hohl": true, "iris": seele, "seite": 1.0})
	kopf.teil(Stil3D.box(0.08, 0.05, 0.03), _p("schwarz"), kz + Vector3(0.01, -0.1, 0.18), Vector3(0, 0, -8), false)
	kopf.teil(Stil3D.box(0.02, 0.03, 0.02), _p("knochen"), kz + Vector3(-0.015, -0.083, 0.192), Vector3(0, 0, 12), false)
	kopf.teil(Stil3D.box(0.02, 0.025, 0.02), _p("knochen"), kz + Vector3(0.03, -0.085, 0.19), Vector3(0, 0, -10), false)
	for i in 5:
		kopf.teil(Stil3D.box(0.012, 0.04, 0.015), _p("schwarz"), kz + Vector3(-0.08 + i * 0.04, 0.12, 0.17 - absf(i - 2) * 0.01),
			Vector3(-30, 0, 0), false)
	kopf.teil(Stil3D.box(0.17, 0.008, 0.012), _p("schwarz"), kz + Vector3(0, 0.12, 0.172), Vector3(-30, 0, 0), false)
	for x in [-0.06, 0.02, 0.09]:
		_strebe(kopf, kz + Vector3(x, 0.19, 0.0), kz + Vector3(x * 1.6, 0.06, 0.09 - absf(x)), 0.012, _p("stein_dunkel"))
	var arme := _arme(pu, kb, Vector3(-75, 0, 8), Vector3(8, 0, -6), {"farbe": _p("leder") * 1.1, "hand": _p("fahl")})
	var h: Vector3 = arme[0]["hand"]
	for i in 3:
		var w := (-25.0 + i * 25.0) * GRAD
		_strebe(arme[0]["b"], h, h + Vector3(sin(w) * 0.07, -0.08, 0.02), 0.012, _p("fahl"))
	# Laterne in der tief hängenden linken Hand
	var lb: Bausatz = arme[1]["b"]
	var lt := _lage(arme[1], Vector3.UP, Vector3.RIGHT, Vector3(0, -0.04, 0.02))
	_messen("waffe", "arm_l", lt)
	_messen("kopf", "kopf", kz, 0.21)
	lb.teil_t(Stil3D.zylinder(0.006, 0.006, 0.07, 6), _p("eisen"), _at(lt, Vector3(0, -0.03, 0)), false)
	var mitte := _at(lt, Vector3(0, -0.17, 0))
	for i in 4:
		var w := TAU * i / 4.0 + PI / 4.0
		lb.teil_t(Stil3D.zylinder(0.01, 0.01, 0.13, 6), _p("eisen"), _at(mitte, Vector3(sin(w) * 0.055, 0, cos(w) * 0.055)))
	lb.teil_t(Stil3D.kegel(0.08, 0.06, 8), _p("eisen") * 0.8, _at(mitte, Vector3(0, 0.09, 0)))
	lb.teil_t(Stil3D.zylinder(0.07, 0.07, 0.02, 8), _p("eisen") * 0.8, _at(mitte, Vector3(0, -0.07, 0)))
	lb.teil_t(Stil3D.kugel(0.045, -1, 10), seele, mitte, false, 1.0)
	_fertig(pu, kb, 0.23)


## Schattenkrieger: Rabenritter in Schattenfarbe, spitze Zacken-Schulter-
## platten mit lila Leuchtkante, Topfhelm mit glühendem Visier und Hörnern,
## zerfetzter Umhang mit Rauchkugeln, Langschwert, Drachenschild mit Auge.
static func _schattenkrieger(pu: Gliederpuppe, k: Dictionary) -> void:
	var lila := _glut(k, _p("lila"))
	var schatten := _p("schatten")
	pu.meta("hoerner", true)  # Hornkamm: kein Champion-Hörnchen dazu
	var kb := _koerper(pu, {"bau": "keil", "rumpf": schatten, "hose": _p("robe_schwarz"),
		"stiefel": _p("eisen") * 0.5, "guertel": _p("robe_schwarz")})
	var ob: Bausatz = kb["ob"]
	var kz: Vector3 = kb["kz"]
	var dunkel := _p("eisen") * 0.6
	ob.teil(Stil3D.box(0.3, 0.22, 0.06), schatten * 1.15, Vector3(0, 0.51, 0.2), Vector3(-12, 0, 0))
	ob.teil(Stil3D.box(0.03, 0.2, 0.07), schatten * 1.4, Vector3(0, 0.51, 0.215), Vector3(-12, 0, 0), false)
	for v in [Vector3(-0.11, 0.6, 0.22), Vector3(0.11, 0.6, 0.22), Vector3(-0.12, 0.51, 0.23), Vector3(0.12, 0.51, 0.23),
			Vector3(-0.11, 0.43, 0.21), Vector3(0.11, 0.43, 0.21)]:
		ob.teil(Stil3D.kugel(0.015, -1, 6), dunkel, v, Vector3.ZERO, false)
	var horn := 1.3 if k.get("boss", false) else 1.0
	for s in [-1.0, 1.0]:
		ob.teil(Stil3D.kugel(0.12, 0.13, 8), dunkel, Vector3(0.27 * s, 0.64, 0))
		for i in 3:
			ob.teil(Stil3D.prisma(0.07, 0.17 * horn, 0.05), dunkel, Vector3((0.24 + i * 0.05) * s, 0.72, -0.05 + i * 0.05),
				Vector3(0, 0, -(20 + i * 15) * s))
		ob.teil(Stil3D.box(0.2, 0.012, 0.012), lila, Vector3(0.28 * s, 0.6, 0.11), Vector3.ZERO, false, 0.6)
	# Topfhelm mit Visierschlitz und Hornkamm
	ob.teil(Stil3D.zylinder(0.2, 0.21, 0.3, 16), schatten * 1.2, kz + Vector3(0, 0.02, 0))
	ob.teil(Stil3D.zylinder(0.15, 0.2, 0.06, 16), schatten * 1.3, kz + Vector3(0, 0.2, 0))
	ob.teil(Stil3D.box(0.24, 0.045, 0.03), lila, kz + Vector3(0, 0.03, 0.2), Vector3.ZERO, false, 0.9)
	for s in [-1.0, 1.0]:
		ob.teil(Stil3D.kugel(0.022, -1, 6), _glut(k, _p("lila")).lightened(0.3), kz + Vector3(0.06 * s, 0.03, 0.215),
			Vector3.ZERO, false, 1.0)
		Gliederpuppe.kette(ob, _t(kz + Vector3(0.12 * s, 0.18, -0.02), Vector3(-30, 0, -30 * s)), 3, 0.3 * horn, 0.05, 0.01,
			Vector3(-25, 0, 8 * s), schatten * 0.8, lila if horn > 1.0 else null, 0.6 if horn > 1.0 else 0.0)
	# Zerfetzter Umhang mit Zacken-Saum und Rauchkugeln
	ob.teil(Stil3D.box(0.44, 0.4, 0.03), _p("robe_schwarz"), Vector3(0, 0.44, -0.25), Vector3(12, 0, 0))
	for i in 4:
		ob.teil(Stil3D.prisma(0.11, 0.12 + (i % 2) * 0.08, 0.03), _p("robe_schwarz"),
			Vector3(-0.165 + i * 0.11, 0.18 - (i % 2) * 0.04, -0.3), Vector3(192, 0, 0))
	for v in [Vector3(-0.15, 0.12, -0.3), Vector3(0.05, 0.08, -0.31), Vector3(0.17, 0.15, -0.29)]:
		ob.teil(Stil3D.kugel(0.035, -1, 8), lila, v, Vector3.ZERO, false, 0.4)
	var arme := _arme(pu, kb, Vector3(-24, 0, 12), Vector3(-30, 0, -12), {"farbe": schatten, "hand": dunkel})
	_schwert(arme[0]["b"], _lage(arme[0], Vector3(0.12, 0.8, 0.58)), 0.6, schatten * 1.2,
		{"parier": dunkel, "grat": lila, "grat_leuchten": 0.7})
	var ts := _lage(arme[1], Vector3.UP, Vector3(0.94, 0, -0.34), Vector3(0.02, 0.0, 0.09))
	_messen("waffe", "arm_r", _lage(arme[0], Vector3(0.12, 0.8, 0.58)))
	_messen("schild", "arm_l", ts)
	_messen("kopf", "", kz, 0.21)
	var lb: Bausatz = arme[1]["b"]
	lb.teil_t(Stil3D.prisma(0.36, 0.34, 0.05), _p("robe_schwarz") * 1.3, _at(ts, Vector3(0, -0.08, 0), Vector3(0, 0, 180)))
	lb.teil_t(Stil3D.zylinder(0.18, 0.18, 0.05, 14), _p("robe_schwarz") * 1.3, _at(ts, Vector3(0, 0.08, 0), Vector3(90, 0, 0)))
	lb.teil_t(Stil3D.kugel(0.06, 0.06, 10), lila, _at(ts, Vector3(0, 0.04, 0.03)), false, 0.7)
	lb.teil_t(Stil3D.box(0.016, 0.07, 0.02), _p("schwarz"), _at(ts, Vector3(0, 0.04, 0.06)), false)
	_fertig(pu, kb, 0.26)


## Todesmeister (Boss): schwebender Lich mit spitz auslaufender Robe,
## Riesenkragen, Rippen mit Herz-Kristall, Knochenkrone, Sense,
## Phylakterium im Knochenkäfig und drei Seelenlichter im Orbit.
static func _todesmeister(pu: Gliederpuppe, k: Dictionary) -> void:
	var boss: bool = k.get("boss", false)
	var seele := _glut(k, _p("seele"))
	pu.meta("schwebt", 0.25).meta("wippen", 0.05).meta("hat_krone", true)
	var kb := _koerper(pu, {"bau": "schwebend", "rumpf": _p("robe_schwarz"), "haut": _p("knochen"), "kopf_glied": true})
	var b := pu.rumpf
	var ob: Bausatz = kb["ob"]
	var kopf: Bausatz = kb["kb"]
	var kz: Vector3 = kb["kz"]
	var kn := _p("knochen")
	for i in 6:
		var w := TAU * i / 6.0 + 0.3
		var lang := 0.2 + 0.08 * float(i % 2)
		b.teil(Stil3D.prisma(0.12, lang, 0.025), _p("robe_schwarz") * 1.1,
			Vector3(sin(w) * 0.165, 0.42 - lang * 0.5, cos(w) * 0.165), Vector3(180 - 20, rad_to_deg(w), 0))
		b.teil(Stil3D.box(0.1, 0.014, 0.014), seele, Vector3(sin(w) * 0.19, 0.44, cos(w) * 0.19),
			Vector3(0, rad_to_deg(w), 0), false, 0.4)
	for i in 7:
		var w := (-75.0 + i * 25.0)
		var hoch := 0.42 - absf(w) * 0.002
		ob.teil(Stil3D.prisma(0.15, hoch, 0.03), _p("robe_schwarz") * 1.3,
			Vector3(sin(w * GRAD) * 0.2, 0.74, -0.12 + absf(w) * 0.0008), Vector3(-18, 0, -w * 0.9))
		ob.teil(Stil3D.prisma(0.11, hoch * 0.8, 0.02), _p("daemon_dunkel"),
			Vector3(sin(w * GRAD) * 0.19, 0.72, -0.098 + absf(w) * 0.0008), Vector3(-18, 0, -w * 0.9), false)
	for i in 3:
		var r := 0.12 - i * 0.018
		ob.teil_t(_ring(r - 0.022, r, 14, 4), kn, Transform3D(Basis.from_scale(Vector3(1, 1, 0.6)),
			Vector3(0, 0.6 - i * 0.055, 0.12)))
	ob.teil(Stil3D.prisma(0.07, 0.1, 0.05), seele, Vector3(0, 0.56, 0.13), Vector3.ZERO, false, 1.0)
	ob.teil(Stil3D.prisma(0.07, 0.07, 0.05), seele, Vector3(0, 0.475, 0.13), Vector3(180, 0, 0), false, 1.0)
	for s in [-1.0, 1.0]:
		var sch := Vector3(0.23 * s, 0.67, 0)
		ob.teil(Stil3D.kugel(0.08, 0.13), kn, sch)
		for x in [-0.025, 0.025]:
			ob.teil(Stil3D.kugel(0.016, -1, 6), _p("schwarz"), sch + Vector3(x, 0.01, 0.07), Vector3.ZERO, false)
	# Schädel (Kopf-Glied) mit Glut-Höhlen, Zähnen und Knochenkrone
	kopf.teil(Stil3D.box(0.24, 0.07, 0.12), kn * 0.95, kz + Vector3(0, -0.12, 0.08))
	for s in [-1.0, 1.0]:
		Gliederpuppe.auge(kopf, kz + Vector3(0.075 * s, 0.0, 0.15), 0.06, {"hohl": true, "iris": seele, "seite": s})
	kopf.teil(Stil3D.prisma(0.04, 0.05, 0.02), _p("schwarz"), kz + Vector3(0, -0.06, 0.205), Vector3.ZERO, false)
	for i in 6:
		kopf.teil(Stil3D.box(0.024, 0.032, 0.02), kn * 1.05, kz + Vector3(-0.06 + i * 0.024, -0.12, 0.15), Vector3.ZERO, false)
	if boss:
		Gliederpuppe.krone(kopf, _t(kz + Vector3(0, 0.13, -0.01), Vector3(0, 0, 8)), 0.17, 7, _p("gold"),
			_p("drachenblut"), 0.35, _p("umhang"))
	else:
		Gliederpuppe.krone(kopf, _t(kz + Vector3(0, 0.13, -0.01)), 0.15, 5, _p("eisen") * 0.8, seele, 0.5)
	# Arme: Sense rechts, Phylakterium links
	var arme := _arme(pu, kb, Vector3(-30, 0, 14), Vector3(-55, 0, -14), {"farbe": _p("robe_schwarz") * 1.15,
		"hand": kn, "hand_r": 0.05})
	for arm in arme:
		(arm["b"] as Bausatz).teil(Stil3D.zylinder(0.1, 0.06, 0.18, 10), _p("robe_schwarz") * 1.15, Vector3(0, -0.15, 0))
	var rb: Bausatz = arme[0]["b"]
	var t := _lage(arme[0], Vector3(0.02, 1, 0.1))
	_strebe(rb, t * Vector3(0, -0.42, 0), t * Vector3(0, 0.95, 0), 0.024, _p("holz") * 0.6, true, true)
	# Sensenblatt zeigt nach außen (über die rechte Schulter), nie über die
	# Krone: Prismen und Seelen-Schneide bei Klingen-x +0.1 … +0.42.
	var klinge := _at(t, Vector3(0, 0.92, 0))
	for i in 3:
		rb.teil_t(Stil3D.prisma(0.12, 0.2, 0.025), _p("eisen") * 1.2, _at(klinge, Vector3(0.1 + i * 0.15, -0.02 - i * 0.05, 0.0),
			Vector3(0, 0, -(100 + i * 14))))
	_strebe(rb, klinge * Vector3(0.05, -0.06, 0.01), klinge * Vector3(0.42, -0.2, 0.01), 0.008, seele, false, true, 0.6)
	_messen("waffe", "arm_r", t)
	_messen("klinge", "arm_r", klinge)
	_messen("kopf", "kopf", kz, 0.21)
	var lb: Bausatz = arme[1]["b"]
	var ph := (arme[1]["hand"] as Vector3) + Basis.from_euler(Vector3(-55, 0, -14) * GRAD).inverse() * Vector3(0, 0.13, 0.03)
	lb.teil(Stil3D.prisma(0.06, 0.09, 0.05), seele, ph + Vector3(0, 0.03, 0), Vector3.ZERO, false, 1.0)
	lb.teil(Stil3D.prisma(0.06, 0.06, 0.05), seele, ph - Vector3(0, 0.04, 0), Vector3(180, 0, 0), false, 1.0)
	for i in 4:
		var w := TAU * i / 4.0
		_strebe(lb, ph + Vector3(sin(w) * 0.07, -0.08, cos(w) * 0.07), ph + Vector3(sin(w) * 0.05, 0.1, cos(w) * 0.05), 0.012, kn)
	# Orbit: drei Seelenlichter auf einem Ring um den Rumpf
	var orbit := pu.glied("orbit", Vector3(0, 0.55, 0))
	for i in 3:
		var w := TAU * i / 3.0
		orbit.teil(Stil3D.kugel(0.05, -1, 10), seele, Vector3(sin(w) * 0.45, 0.05 * sin(w * 2.0), cos(w) * 0.45),
			Vector3.ZERO, false, 1.0)
	_fertig(pu, kb, 0.3)


## Kleindämon (Imp): extrem chibi, Riesenkopf mit spitzen Ohren und kurzen
## Hörnern (W-Silhouette), Kugelbauch, Krallenfüße, Fledermausflügel,
## Pfeilschwanz, freches Grinsen, Feuerball in der rechten Hand.
static func _kleindaemon(pu: Gliederpuppe, k: Dictionary) -> void:
	var d := _p("daemon")
	var dd := _p("daemon_dunkel")
	var glut := _glut(k, _p("glut"))
	var horn := 1.3 if k.get("boss", false) else 1.0
	var b := pu.rumpf
	pu.meta("wippen", 0.05).meta("hoerner", true)
	for s in [-1.0, 1.0]:
		b.teil(Stil3D.kapsel(0.05, 0.16), dd, Vector3(0.08 * s, 0.11, 0))
		for i in 3:
			b.teil(Stil3D.kegel(0.018, 0.06, 6), _p("knochen"), Vector3(0.08 * s + (i - 1) * 0.028, 0.02, 0.07),
				Vector3(90, 0, 0), false)
		b.teil(Stil3D.kugel(0.055, 0.05), dd, Vector3(0.08 * s, 0.03, 0.02))
	b.teil(Stil3D.kugel(0.2, 0.36), d * 1.1, Vector3(0, 0.33, 0.01))
	b.teil(Stil3D.kugel(0.13, 0.2), d * 1.3, Vector3(0, 0.3, 0.1), Vector3.ZERO, false)
	var kz := Vector3(0, 0.7, 0.02)
	b.teil(Stil3D.kugel(0.26, 0.48), d, kz)
	for s in [-1.0, 1.0]:
		b.teil(Stil3D.prisma(0.14, 0.24, 0.035), d, kz + Vector3(0.25 * s, 0.06, -0.02), Vector3(0, 0, -62 * s))
		b.teil(Stil3D.prisma(0.08, 0.15, 0.02), dd, kz + Vector3(0.25 * s, 0.06, 0.0), Vector3(0, 0, -62 * s), false)
		Gliederpuppe.kette(b, _t(kz + Vector3(0.1 * s, 0.2, 0.0), Vector3(0, 0, -18 * s)), 2, 0.13 * horn, 0.04, 0.008,
			Vector3(-10, 0, 10 * s), _p("knochen"), _p("boss_siegel") if horn > 1.0 else null, 0.6 if horn > 1.0 else 0.0)
		Gliederpuppe.auge(b, kz + Vector3(0.095 * s, 0.03, 0.2), 0.072, {"iris": glut, "iris_leuchten": 0.7,
			"pupille": "schlitz", "seite": s})
		Gliederpuppe.braue(b, kz + Vector3(0.1 * s, 0.12, 0.22), 0.09, s, 24.0)
	Gliederpuppe.mund(b, kz + Vector3(0, -0.12, 0.2), 0.16, "grinsen", {"farbe": _p("schwarz"), "zaehne": 5})
	pu.meta("anker_kopf", kz + Vector3(0, 0.27, 0)).meta("anker_ruecken", Vector3(0, 0.42, -0.18)).meta("brust_y", 0.2)
	# Flügel, Schwanz, Feuerball-Arm; linker Arm gebacken
	for s in [-1.0, 1.0]:
		var fl := pu.glied("fluegel_r" if s > 0 else "fluegel_l", Vector3(0.1 * s, 0.45, -0.14), Vector3(0, 25 * s, 0))
		for i in 3:
			var w := (35.0 - i * 30.0) * GRAD
			_strebe(fl, Vector3.ZERO, Vector3(cos(w) * 0.3 * s, sin(w) * 0.3 + 0.05, -0.04), 0.018, dd)
		for i in 2:
			var w := (20.0 - i * 30.0) * GRAD
			fl.teil(Stil3D.prisma(0.12, 0.26, 0.012), dd * 1.2, Vector3(cos(w) * 0.15 * s, sin(w) * 0.15 + 0.0, -0.04),
				Vector3(0, 0, -90 * s + rad_to_deg(w) * s))
	var sw := pu.glied("schwanz", Vector3(0, 0.22, -0.17))
	_strebe(sw, Vector3.ZERO, Vector3(0, -0.05, -0.14), 0.022, d)
	_strebe(sw, Vector3(0, -0.05, -0.14), Vector3(0.05, 0.05, -0.26), 0.018, d)
	_strebe(sw, Vector3(0.05, 0.05, -0.26), Vector3(0.06, 0.18, -0.3), 0.016, d)
	sw.teil(Stil3D.prisma(0.1, 0.1, 0.02), dd, Vector3(0.06, 0.23, -0.3), Vector3(0, 90, 0))
	var links := pu.teilsatz()
	Gliederpuppe.arm(links, 0.18, 0.035, d, d, 0.045)
	pu.uebernehmen(links, _t(Vector3(-0.17, 0.43, 0), Vector3(-30, 0, -30)))
	var arm_r := _arm(pu, "arm_r", Vector3(0.17, 0.43, 0), Vector3(-60, 0, 25), {"farbe": d, "hand": d,
		"laenge": 0.18, "r": 0.035, "hand_r": 0.045})
	var fb := (arm_r["hand"] as Vector3) + Basis.from_euler(Vector3(-60, 0, 25) * GRAD).inverse() * Vector3(0, 0.08, 0.02)
	(arm_r["b"] as Bausatz).teil(Stil3D.kugel(0.065, -1, 12), _p("flamme"), fb, Vector3.ZERO, false, 1.0)
	(arm_r["b"] as Bausatz).teil(Stil3D.kegel(0.04, 0.08, 8), glut, fb + Vector3(0, 0.06, 0), Vector3.ZERO, false, 1.0)


## Dämonenbeschwörer: Widder-Hohepriester — Robe mit glühenden Runen,
## schwarze Stola mit Goldkante, Zackenkragen, Widderhörner, Ziegenbart,
## schwebendes Zauberbuch, Dreizack mit Feuerkugel.
static func _beschwoerer(pu: Gliederpuppe, k: Dictionary) -> void:
	var glut := _glut(k, _p("glut"))
	var horn := 1.3 if k.get("boss", false) else 1.0
	pu.meta("hoerner", true)
	var kb := _koerper(pu, {"bau": "glocke", "rumpf": _p("daemon_dunkel"), "haut": _p("daemon"),
		"saum": _p("schwarz") * 1.3})
	var b := pu.rumpf
	var ob: Bausatz = kb["ob"]
	var kz: Vector3 = kb["kz"]
	for i in 9:
		var w := (-80.0 + i * 20.0) * GRAD
		b.teil(Stil3D.box(0.04, 0.06, 0.015), _p("glut"), Vector3(sin(w) * 0.32, 0.1, cos(w) * 0.32),
			Vector3(-14, rad_to_deg(w), 45 if i % 2 == 0 else 0), false, 0.6)
	for s in [-1.0, 1.0]:
		b.teil(Stil3D.box(0.07, 0.56, 0.02), _p("schwarz") * 1.2, Vector3(0.06 * s, 0.29, 0.262), Vector3(-14, 0, 0))
		b.teil(Stil3D.box(0.012, 0.56, 0.024), _p("gold"), Vector3(0.098 * s, 0.29, 0.262), Vector3(-14, 0, 0), false)
	for i in 4:
		var w := (-45.0 + i * 30.0)
		ob.teil(Stil3D.prisma(0.12, 0.18, 0.03), _p("daemon"), Vector3(sin(w * GRAD) * 0.2, 0.7, -0.08 + absf(w) * 0.001),
			Vector3(-20, 0, -w))
	for s in [-1.0, 1.0]:
		# Widderhorn: erst nach oben-außen, dann in einer Schnecke nach unten
		# und wieder nach vorn um das Ohr (von vorn ein breites „C“).
		Gliederpuppe.kette(ob, _t(kz + Vector3(0.15 * s, 0.12, -0.03), Vector3(-15, 0, -35 * s)), 5, 0.46 * horn, 0.065, 0.02,
			Vector3(-18, 0, -52 * s), _p("knochen") * 0.85, _p("boss_siegel") if horn > 1.0 else null, 0.6 if horn > 1.0 else 0.0)
		Gliederpuppe.auge(ob, kz + Vector3(0.075 * s, 0.02, 0.17), 0.05, {"iris": glut, "iris_leuchten": 0.7,
			"pupille": "schlitz", "seite": s})
		Gliederpuppe.braue(ob, kz + Vector3(0.078 * s, 0.09, 0.19), 0.075, s, 26.0, _p("schwarz"))
	ob.teil(Stil3D.kegel(0.055, 0.14, 8), _p("schwarz"), kz + Vector3(0, -0.22, 0.13), Vector3(160, 0, 0))
	Gliederpuppe.mund(ob, kz + Vector3(0, -0.09, 0.19), 0.07, "strich")
	for s in [-1.0, 1.0]:
		ob.teil(Stil3D.kegel(0.012, 0.04, 6), _p("weiss"), kz + Vector3(0.022 * s, -0.105, 0.195), Vector3(180, 0, 0), false)
	var arme := _arme(pu, kb, Vector3(-16, 0, 16), Vector3(-50, 0, -10), {"farbe": _p("daemon_dunkel"), "hand": _p("daemon")})
	for arm in arme:
		(arm["b"] as Bausatz).teil(Stil3D.zylinder(0.1, 0.06, 0.19, 10), _p("daemon_dunkel"), Vector3(0, -0.15, 0))
	var rb: Bausatz = arme[0]["b"]
	var t := _lage(arme[0], Vector3(0.12, 1, 0.05))
	_messen("waffe", "arm_r", t)
	_messen("kopf", "", kz, 0.21)
	_strebe(rb, t * Vector3(0, -0.32, 0), t * Vector3(0, 0.78, 0), 0.022, _p("schwarz") * 1.3, true, true)
	for s in [-1.0, 0.0, 1.0]:
		rb.teil_t(Stil3D.kegel(0.025, 0.16 if s == 0.0 else 0.12, 6), _p("eisen"), _at(t, Vector3(0.07 * s, 0.86, 0)))
	rb.teil_t(Stil3D.box(0.17, 0.03, 0.03), _p("eisen"), _at(t, Vector3(0, 0.79, 0)))
	rb.teil_t(Stil3D.kugel(0.04, -1, 10), _p("flamme"), _at(t, Vector3(0, 0.86, 0)), false, 1.0)
	var lb: Bausatz = arme[1]["b"]
	# quer = links wie beim Helden-Zauberbuch: Seiten oben, Deckel als V
	var bt := _lage(arme[1], Vector3(0, 0.4, 1), Vector3.LEFT, Vector3(0, 0.1, 0.07))
	_messen("buch", "arm_l", bt)
	for s in [-1.0, 1.0]:
		lb.teil_t(Stil3D.box(0.13, 0.18, 0.02), _p("daemon_dunkel") * 0.8, _at(bt, Vector3(0.065 * s, 0, 0), Vector3(0, -25 * s, 0)))
		lb.teil_t(Stil3D.box(0.11, 0.16, 0.012), _p("weiss"), _at(bt, Vector3(0.06 * s, 0, 0.018), Vector3(0, -25 * s, 0)), false)
	lb.teil_t(Stil3D.box(0.05, 0.05, 0.01), glut, _at(bt, Vector3(0.06, 0, 0.03), Vector3(0, -25, 45)), false, 0.8)
	_fertig(pu, kb, 0.28)


## Dämonenfürst (Boss): massige Keilbrust mit glühendem Kern, Obsidian-
## Pauldrons mit Glutrissen, Stierhörner um eine goldene Zackenkrone,
## Hufbeine, gefaltete Fledermausflügel, Flammenschwert einhändig.
static func _daemonenfuerst(pu: Gliederpuppe, k: Dictionary) -> void:
	var boss: bool = k.get("boss", false)
	var d := _p("daemon")
	var dd := _p("daemon_dunkel")
	var glut := _glut(k, _p("glut"))
	var horn := 1.3 if boss else 1.0
	pu.meta("hat_krone", true).meta("hoerner", true).meta("wippen", 0.01)
	var b := pu.rumpf
	# Hufbeine: Oberschenkel vor, Unterschenkel zurück, Hufe
	for s in [-1.0, 1.0]:
		var x: float = 0.12 * s
		_strebe(b, Vector3(x, 0.36, 0), Vector3(x, 0.22, 0.08), 0.075, dd)
		_strebe(b, Vector3(x, 0.22, 0.08), Vector3(x, 0.07, -0.02), 0.055, dd)
		b.teil(Stil3D.zylinder(0.06, 0.075, 0.07, 10), _p("schwarz") * 1.3, Vector3(x, 0.035, 0.0))
	b.teil(Stil3D.zylinder(0.26, 0.22, 0.12), _p("schwarz") * 1.3, Vector3(0, 0.38, 0))
	var ob := pu.teilsatz()
	ob.teil(Stil3D.zylinder(0.32, 0.22, 0.36), d, Vector3(0, 0.6, 0))
	ob.teil(Stil3D.box(0.3, 0.2, 0.05), d * 0.8, Vector3(0, 0.5, 0.22), Vector3(-10, 0, 0))
	ob.teil(Stil3D.box(0.31, 0.03, 0.055), _p("gold"), Vector3(0, 0.4, 0.21), Vector3(-10, 0, 0), false)
	ob.teil(Stil3D.kugel(0.05, -1, 10), glut, Vector3(0, 0.64, 0.275), Vector3.ZERO, false, 0.75)
	ob.teil(_ring(0.05, 0.075, 16, 4), _p("gold") * 0.85, Vector3(0, 0.64, 0.265), Vector3(78, 0, 0), false)
	for s in [-1.0, 1.0]:
		var sch := Vector3(0.34 * s, 0.76, 0)
		ob.teil(Stil3D.kugel(0.16, 0.18), _p("obsidian"), sch)
		for i in 3:
			ob.teil(Stil3D.box(0.012, 0.08, 0.012), glut, sch + Vector3(0.04 * s - i * 0.04 * s, 0.03, 0.14 - i * 0.03),
				Vector3(-30, 0, 20 * s), false, 0.7)
		for i in 2:
			ob.teil(Stil3D.kegel(0.035, 0.15 * horn, 8), _p("obsidian") * 1.2, sch + Vector3(0.05 * s, 0.08, -0.05 + i * 0.09),
				Vector3(0, 0, -35 * s))
	# Umhang mit Futter, Pfeilschwanz
	ob.teil(Stil3D.box(0.56, 0.62, 0.035), _p("schwarz") * 1.2, Vector3(0, 0.46, -0.27), Vector3(10, 0, 0))
	ob.teil(Stil3D.box(0.5, 0.56, 0.01), dd, Vector3(0, 0.47, -0.25), Vector3(10, 0, 0), false)
	_strebe(b, Vector3(0, 0.3, -0.2), Vector3(0.1, 0.12, -0.42), 0.025, d)
	b.teil(Stil3D.prisma(0.1, 0.1, 0.02), dd, Vector3(0.13, 0.08, -0.47), Vector3(0, 90, 120))
	var kb := {"ob": ob, "t": Transform3D(), "kz": Vector3.ZERO, "kb": ob, "sx": 0.38, "sy": 0.74, "kr": 0.2}
	# Kopf-Glied: breiter Kiefer, Unterbiss mit Fängen, Glutaugen, Brauen-
	# wulst, Spitzbart, Stierhörner um die goldene Zackenkrone
	var hals := Vector3(0, 0.84, 0.04)
	var kopf := pu.glied("kopf", hals)
	kb["kb"] = kopf
	kb["hals"] = hals
	var kz := Vector3(0, 0.16, 0.04)
	kb["kz"] = kz
	kopf.teil(Stil3D.kugel(0.2, 0.38), d, kz)
	kopf.teil(Stil3D.kugel(0.17, 0.2), d * 0.92, kz + Vector3(0, -0.11, 0.07))
	kopf.teil(Stil3D.box(0.26, 0.05, 0.07), dd, kz + Vector3(0, 0.075, 0.15), Vector3(14, 0, 0), false)
	for s in [-1.0, 1.0]:
		Gliederpuppe.auge(kopf, kz + Vector3(0.075 * s, 0.025, 0.155), 0.045, {"iris": glut, "iris_leuchten": 0.8,
			"pupille": "schlitz", "seite": s})
		Gliederpuppe.kette(kopf, _t(kz + Vector3(0.16 * s, 0.1, 0.0), Vector3(0, 0, -80 * s)), 3, 0.32 * horn, 0.06, 0.015,
			Vector3(-25, 0, 32 * s), _p("knochen") * 0.9, _p("boss_siegel") if boss else null, 0.6 if boss else 0.0)
	Gliederpuppe.mund(kopf, kz + Vector3(0, -0.13, 0.17), 0.14, "unterbiss", {"hauer": 0.07})
	kopf.teil(Stil3D.kegel(0.05, 0.12, 8), _p("schwarz"), kz + Vector3(0, -0.24, 0.12), Vector3(165, 0, 0))
	if boss:
		Gliederpuppe.krone(kopf, _t(kz + Vector3(0, 0.15, -0.02)), 0.15, 7, _p("gold"), _p("drachenblut"), 0.35, _p("umhang"))
	else:
		Gliederpuppe.krone(kopf, _t(kz + Vector3(0, 0.15, -0.02)), 0.14, 5, _p("gold"), d, 0.3)
	# Flügel gefaltet hinten
	for s in [-1.0, 1.0]:
		var fl := pu.glied("fluegel_r" if s > 0 else "fluegel_l", Vector3(0.14 * s, 0.76, -0.2), Vector3(0, 30 * s, 0))
		for i in 4:
			var w := (70.0 - i * 28.0) * GRAD
			_strebe(fl, Vector3.ZERO, Vector3(cos(w) * 0.42 * s, sin(w) * 0.42, -0.05), 0.022, dd)
		for i in 3:
			var w := (56.0 - i * 28.0) * GRAD
			fl.teil(Stil3D.prisma(0.16, 0.38, 0.015), dd * 1.25, Vector3(cos(w) * 0.2 * s, sin(w) * 0.2, -0.05),
				Vector3(0, 0, -90 * s + rad_to_deg(w) * s))
	# Flammenschwert einhändig rechts, steil neben dem Kopf (Gesicht, Augen und
	# Krone frei); die linke Faust hängt frei seitlich.
	var arme := _arme(pu, kb, Vector3(-28, -20, 14), Vector3(-20, 0, -14), {"farbe": d, "hand": dd, "laenge": 0.36,
		"r": 0.085, "hand_r": 0.085})
	var rb: Bausatz = arme[0]["b"]
	var t := _lage(arme[0], Vector3(0.15, 0.9, 0.35))
	_messen("waffe", "arm_r", t)
	_messen("kopf", "kopf", kz, 0.2)
	_messen("hand_l", "arm_l", arme[1]["hand"], 0.085)
	rb.teil_t(Stil3D.zylinder(0.03, 0.03, 0.2, 8), _p("schwarz") * 1.3, t)
	for s in [-1.0, 1.0]:
		Gliederpuppe.kette(rb, _at(t, Vector3(0.04 * s, 0.11, 0), Vector3(0, 0, -70 * s)), 2, 0.14, 0.03, 0.008, Vector3(0, 0, 40 * s),
			_p("obsidian") * 1.2)
	for i in 4:
		rb.teil_t(Stil3D.box(0.11 - i * 0.012, 0.2, 0.03), _p("obsidian"), _at(t, Vector3(0.012 * (i % 2), 0.2 + i * 0.18, 0)))
		rb.teil_t(Stil3D.box(0.016, 0.19, 0.036), glut, _at(t, Vector3(0.06 - i * 0.006 + 0.012 * (i % 2), 0.2 + i * 0.18, 0)),
			false, 0.8)
	rb.teil_t(Stil3D.prisma(0.07, 0.14, 0.03), _p("obsidian"), _at(t, Vector3(0, 0.9, 0)))
	pu.meta("anker_ruecken", Vector3(0, 0.66, -0.3)).meta("brust_y", 0.42)
	pu.uebernehmen(ob, Transform3D())
	pu.meta("anker_kopf", kz + Vector3(0, 0.3, 0)).meta("anker_kopf_glied", "kopf")


## Pilzhexe: bucklige kleine Pilzfrau, Flechtenumhang mit Fransen, riesiger
## Fliegenpilz-Hut, Knollennase mit Warze, Ein-Zahn-Grinsen, Wurzelstock
## mit Leuchtpilz. Kopf mit Hut als Glied (wippt nach).
static func _pilzhexe(pu: Gliederpuppe, k: Dictionary) -> void:
	var moos := _glut(k, _p("moos"))
	var kb := _koerper(pu, {"bau": "glocke", "robe_unten": 0.3, "robe_h": 0.5, "rumpf": _p("moos_dunkel"),
		"haut": _p("fahl"), "neigung": 20.0, "kopf_neigung": -4.0, "kopf_glied": true})
	var b := pu.rumpf
	var ob: Bausatz = kb["ob"]
	var kopf: Bausatz = kb["kb"]
	var kz: Vector3 = kb["kz"]
	ob.teil(Stil3D.zylinder(0.2, 0.3, 0.26), _p("moos") * 0.8, Vector3(0, 0.55, -0.01))
	for i in 8:
		var w := TAU * i / 8.0
		ob.teil(Stil3D.prisma(0.07, 0.09, 0.02), _p("moos") * 0.85, Vector3(sin(w) * 0.29, 0.39, cos(w) * 0.29),
			Vector3(180 - 10, rad_to_deg(w), 0))
	for v in [Vector3(-0.17, 0.68, 0.02), Vector3(-0.12, 0.7, -0.08)]:
		ob.teil(Stil3D.zylinder(0.012, 0.014, 0.05, 6), _p("knochen"), v, Vector3.ZERO, false)
		ob.teil(Stil3D.kugel(0.035, 0.03, 8), _p("pilz_rot"), v + Vector3(0, 0.03, 0))
	b.teil(Stil3D.zylinder(0.3, 0.31, 0.04, 16), _p("moos_dunkel") * 0.8, Vector3(0, 0.02, 0), Vector3.ZERO, false)
	# Gesicht: Knollennase mit Warze, glitzernde Augen, Ein-Zahn-Grinsen
	for s in [-1.0, 1.0]:
		Gliederpuppe.auge(kopf, kz + Vector3(0.07 * s, 0.03, 0.17), 0.036, {"iris": moos, "iris_leuchten": 0.7, "seite": s})
		Gliederpuppe.braue(kopf, kz + Vector3(0.075 * s, 0.085, 0.19), 0.06, s, -18.0, _p("stein_hell") * 0.8)
	kopf.teil(Stil3D.kugel(0.065, 0.075), _p("fahl") * 0.9, kz + Vector3(0, -0.03, 0.22))
	kopf.teil(Stil3D.kugel(0.016, -1, 6), _p("fahl") * 0.7, kz + Vector3(0.04, -0.01, 0.27), Vector3.ZERO, false)
	Gliederpuppe.mund(kopf, kz + Vector3(0, -0.12, 0.17), 0.1, "laecheln")
	kopf.teil(Stil3D.box(0.018, 0.022, 0.012), _p("knochen"), kz + Vector3(0.018, -0.11, 0.185), Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		_strebe(kopf, kz + Vector3(0.17 * s, 0.08, -0.02), kz + Vector3(0.22 * s, -0.16, -0.04), 0.026, _p("stein_hell"))
	# Riesiger Fliegenpilz-Hut mit Tupfen und Lamellen
	var hut := kz + Vector3(0, 0.22, -0.04)
	kopf.teil(Stil3D.kugel(0.36, 0.3), _p("pilz_rot"), hut + Vector3(0, 0.03, 0), Vector3(-8, 0, 0))
	kopf.teil(Stil3D.zylinder(0.34, 0.3, 0.03, 18), _p("knochen"), hut + Vector3(0, -0.01, 0), Vector3(-8, 0, 0), false)
	for v in [Vector3(0.0, 0.2, 0.05), Vector3(-0.18, 0.12, 0.17), Vector3(0.2, 0.11, 0.14), Vector3(0.12, 0.16, -0.17),
			Vector3(-0.2, 0.13, -0.12), Vector3(0.28, 0.06, -0.02)]:
		var r := 0.05 - absf(v.x) * 0.06
		kopf.teil(Stil3D.kugel(r, r * 0.6, 8), _p("weiss"), hut + v, Vector3.ZERO, false)
	var arme := _arme(pu, kb, Vector3(-40, 0, 20), Vector3(-55, 20, -14), {"farbe": _p("moos_dunkel"), "hand": _p("fahl")})
	var rb: Bausatz = arme[0]["b"]
	var t := _lage(arme[0], Vector3(0.05, 1, 0.12))
	_messen("waffe", "arm_r", t)
	_messen("kopf", "kopf", kz, 0.21)
	_strebe(rb, t * Vector3(0, -0.5, 0), t * Vector3(0.03, -0.1, 0), 0.026, _p("holz") * 0.8)
	_strebe(rb, t * Vector3(0.03, -0.1, 0), t * Vector3(-0.02, 0.22, 0), 0.026, _p("holz") * 0.8)
	_strebe(rb, t * Vector3(-0.02, 0.22, 0), t * Vector3(0.02, 0.36, 0), 0.022, _p("holz") * 0.8)
	rb.teil_t(Stil3D.kugel(0.075, 0.07, 10), moos, _at(t, Vector3(0.02, 0.4, 0)), true, 0.8)
	_fertig(pu, kb, 0.42)


## Hexenmeisterin: groß und schlank, Robe mit schwarzem Mieder und lila
## Schnürung, Trompetenärmel, sehr hoher geknickter Hut mit Pilz-Brosche,
## lange Haare, Krähe auf der Schulter, Krummstab mit drehendem Kristall.
static func _hexe(pu: Gliederpuppe, k: Dictionary) -> void:
	var lila := _glut(k, _p("lila"))
	var kb := _koerper(pu, {"bau": "glocke", "robe_unten": 0.3, "robe_h": 0.6, "rumpf": _p("robe_lila"),
		"haut": _p("haut") * 0.92, "saum": _p("schwarz") * 1.3})
	var b := pu.rumpf
	var ob: Bausatz = kb["ob"]
	var kz: Vector3 = kb["kz"]
	ob.teil(Stil3D.box(0.26, 0.2, 0.05), _p("schwarz") * 1.2, Vector3(0, 0.56, 0.17), Vector3(-6, 0, 0))
	for i in 3:
		ob.teil(Stil3D.box(0.1, 0.012, 0.012), _p("lila"), Vector3(0, 0.5 + i * 0.05, 0.198), Vector3(0, 0, 20 if i % 2 == 0 else -20), false)
	for i in 3:
		var x := -0.16 + i * 0.16
		_strebe(ob, kz + Vector3(x, 0.05, -0.12 - absf(x) * 0.2), Vector3(x * 1.3, 0.38, -0.2 - absf(x) * 0.1), 0.04, _p("lila_dunkel"))
	ob.teil(Stil3D.kugel(0.21, 0.3), _p("lila_dunkel"), kz + Vector3(0, 0.04, -0.06))
	for s in [-1.0, 1.0]:
		Gliederpuppe.auge(ob, kz + Vector3(0.072 * s, 0.015, 0.17), 0.045, {"iris": lila, "iris_leuchten": 0.4,
			"hoch": 0.8, "seite": s})
		Gliederpuppe.braue(ob, kz + Vector3(0.075 * s, 0.075, 0.19), 0.07, s, 18.0, _p("lila_dunkel") * 0.7)
	Gliederpuppe.mund(ob, kz + Vector3(0, -0.095, 0.185), 0.055, "strich", {"farbe": _p("mund") * 0.7})
	ob.teil(Stil3D.kegel(0.07, 0.1, 10), _p("haut") * 0.92, kz + Vector3(0, -0.2, 0.06), Vector3(165, 0, 0))
	# Sehr hoher, geknickter Hut mit Hutband und Pilz-Brosche
	var hut := _t(kz + Vector3(0, 0.14, -0.01), Vector3(-6, 0, 0))
	ob.teil_t(Stil3D.zylinder(0.34, 0.34, 0.03, 16), _p("schwarz") * 1.2, hut)
	ob.teil_t(Stil3D.zylinder(0.15, 0.19, 0.2, 14), _p("schwarz") * 1.2, _at(hut, Vector3(0, 0.1, 0)))
	ob.teil_t(Stil3D.zylinder(0.192, 0.192, 0.045, 14), lila, _at(hut, Vector3(0, 0.04, 0)), false, 0.2)
	ob.teil_t(Stil3D.kugel(0.04, 0.03, 8), _p("pilz_rot"), _at(hut, Vector3(0.1, 0.06, 0.17)), false)
	Gliederpuppe.kette(ob, _at(hut, Vector3(0, 0.19, 0)), 3, 0.42, 0.15, 0.01, Vector3(-22, 0, 4), _p("schwarz") * 1.2)
	# Krähe auf der linken Schulter
	var kr := Vector3(-0.22, 0.72, -0.02)
	ob.teil(Stil3D.kugel(0.07, 0.11), _p("schwarz") * 1.3, kr, Vector3(30, 0, 0))
	ob.teil(Stil3D.kugel(0.05), _p("schwarz") * 1.3, kr + Vector3(0, 0.08, 0.05))
	ob.teil(Stil3D.kegel(0.02, 0.07, 6), _p("gold"), kr + Vector3(0, 0.075, 0.12), Vector3(90, 0, 0))
	ob.teil(Stil3D.kugel(0.012, -1, 6), _p("glut"), kr + Vector3(-0.04, 0.095, 0.075), Vector3.ZERO, false, 0.8)
	ob.teil(Stil3D.prisma(0.08, 0.1, 0.02), _p("schwarz") * 1.3, kr + Vector3(0, -0.02, -0.09), Vector3(-110, 0, 0))
	var arme := _arme(pu, kb, Vector3(-14, 0, 14), Vector3(-40, 0, -24), {"farbe": _p("robe_lila"), "hand": _p("haut") * 0.92})
	for arm in arme:
		(arm["b"] as Bausatz).teil(Stil3D.zylinder(0.11, 0.06, 0.19, 10), _p("robe_lila"), Vector3(0, -0.15, 0))
	var h: Vector3 = arme[1]["hand"]
	for i in 3:
		var w := (-30.0 + i * 30.0) * GRAD
		_strebe(arme[1]["b"], h, h + Vector3(sin(w) * 0.07, -0.07, 0.03), 0.011, _p("haut") * 0.92)
	var rb: Bausatz = arme[0]["b"]
	var ruhe_r := Vector3(-14, 0, 14)
	var t := _lage(arme[0], Vector3(0, 1, 0.04))
	_messen("waffe", "arm_r", t)
	_messen("kopf", "", kz, 0.21)
	var holz := _p("holz") * 0.7
	_strebe(rb, t * Vector3(0, -0.34, 0), t * Vector3(0, 0.72, 0), 0.022, holz, true, true)
	_strebe(rb, t * Vector3(0, 0.72, 0), t * Vector3(0.08, 0.86, 0), 0.022, holz)
	_strebe(rb, t * Vector3(0.08, 0.86, 0), t * Vector3(0.17, 0.82, 0), 0.02, holz)
	_strebe(rb, t * Vector3(0.17, 0.82, 0), t * Vector3(0.18, 0.72, 0), 0.018, holz)
	# Kristall im Haken: eigenes Glied (dreht frei), Kind des Stab-Arms
	var arm_gelenk := _w(kb, Vector3(kb["sx"], kb["sy"], 0))
	var ruhe_basis := Basis.from_euler(ruhe_r * GRAD)
	var kristall_ort := arm_gelenk + ruhe_basis * (t * Vector3(0.09, 0.73, 0))
	var kristall := pu.glied("kristall", kristall_ort, Vector3.ZERO, "arm_r")
	kristall.teil(Stil3D.prisma(0.07, 0.09, 0.05), lila, Vector3(0, 0.035, 0), Vector3.ZERO, true, 0.9)
	kristall.teil(Stil3D.prisma(0.07, 0.07, 0.05), lila, Vector3(0, -0.045, 0), Vector3(180, 0, 0), true, 0.9)
	# Boss-Krone um den Hut statt auf der geknickten Spitze (schwebte dort).
	pu.meta("krone_sitz", {"versatz": Vector3(0, -0.26, -0.03), "neigung": Vector3(-6, 0, 0), "schraeg": 0.0,
		"groesse": 1.05})
	_fertig(pu, kb, 0.66)
