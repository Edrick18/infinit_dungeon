class_name VierbeinerBau
extends RefCounted
## Figuren 2.0 für Vierbeiner und Schleime (STIL-3D.md 7i): jede Figur ist
## eine Gliederpuppe — gebacken je Glied (Körper + Hülle), gleiche Gegner
## teilen ihre Meshes (Gliederpuppe.gebacken), Glieder werden nur gedreht.
##
## Chibi-Vierbeiner statt Kasten: der Kopf (Kugel r 0.14–0.23, ~40 % der
## Figurhöhe) ist das größte, hellste Element, Schnauze "lang" (Hunde),
## "kurz" (Bär), "kegel" (Dachs) oder "katze"; der Rumpf ist eine geneigte
## Kapsel mit Brust-, Schulter- und Keulenkugeln, die Beine kurze konische
## Zylinder mit Pfote bzw. Huf. Jede Art trägt EIN Kennzeichen außen an der
## Silhouette (Ohren + Buschschwanz, Schulterbuckel, Rückenkamm, Geweih,
## Stachelkranz, Krone, Schein) — es trägt bei Zoom 16 und im Porträt.
##
## Glieder: "koerper" (Beine + Rumpf, Gelenk an den Hinterpfoten: Ducken,
## Aufbäumen), darin "kopf" (Gelenk am Hals) mit "kiefer" und "schwanz" am
## Steiß. Schleime: Körper im Rumpf, dazu Zipfel, Lagen, Krone, Zepter,
## Schein oder Orbit. Je Glied 2 Zeichenaufrufe (Wolf 8 statt ~39).

const GRAD := PI / 180.0

## Archetypen dieses Baukastens (FigurenBau.fuer_archetyp leitet sie hierher);
## "igel" = künftiger gewöhnlicher Igel (gleiches Modell, ohne Fluch-Leuchten).
const ARTEN := [&"wolf", &"baer", &"schattenbestie", &"leichenfresser", &"demonenjager", &"verfluchtkatz",
	&"verfluchtdachs", &"verfluchtbock", &"verfluchtigel", &"igel", &"schleim", &"schleimstapel",
	&"koenigschleim", &"schleimgott"]

## Eigengröße je Archetyp (ins Mesh gebacken, die Kontur bleibt gleich dick).
const GROESSE := {&"baer": 1.3, &"schattenbestie": 1.15, &"verfluchtkatz": 0.8, &"verfluchtdachs": 0.85,
	&"verfluchtbock": 1.25, &"koenigschleim": 1.3, &"schleimgott": 1.6}

## Animationsprofil je Archetyp (Gliederpuppe.PROFILE).
const ANIM := {&"wolf": "hund", &"baer": "baer", &"schattenbestie": "panther", &"leichenfresser": "ghul",
	&"demonenjager": "hoellenhund", &"verfluchtkatz": "katze", &"verfluchtdachs": "dachs", &"verfluchtbock": "bock",
	&"verfluchtigel": "igel", &"igel": "igel", &"schleim": "schleim", &"schleimstapel": "stapel",
	&"koenigschleim": "koenig", &"schleimgott": "gott"}


static func _p(n: String) -> Color:
	return Stil3D.farbe(n)


## Teile eines Glied-Bausatzes in Figurmaßen: o = Gelenk des Glieds (die
## Teile stehen relativ dazu), bei lokalen Maßen (Kopf, Kiefer) Null.
class Satz:
	var b: Bausatz
	var o: Vector3

	func _init(bausatz: Bausatz, ursprung := Vector3.ZERO) -> void:
		b = bausatz
		o = ursprung

	func t(mesh: PrimitiveMesh, farbe: Color, pos: Vector3, rot := Vector3.ZERO, kontur := true,
			leuchten := 0.0) -> void:
		b.teil(mesh, farbe, pos - o, rot, kontur, leuchten)

	## Teil mit vorgegebener Ausrichtung (Basis), z. B. entlang einer Richtung.
	func tb(mesh: PrimitiveMesh, farbe: Color, basis: Basis, pos: Vector3, kontur := true, leuchten := 0.0) -> void:
		b.teil_t(mesh, farbe, Transform3D(basis, pos - o), kontur, leuchten)

	func auge(pos: Vector3, r: float, opt := {}) -> void:
		Gliederpuppe.auge(b, pos - o, r, opt)

	func braue(pos: Vector3, breite: float, seite: float, winkel := 22.0, farbe := Color("1b1a24")) -> void:
		Gliederpuppe.braue(b, pos - o, breite, seite, winkel, farbe)


## Basis, deren +Y entlang d zeigt (Stacheln, Krausen-Zacken, Schwanzglieder).
static func _zu(d: Vector3) -> Basis:
	var n := d.normalized()
	if n.dot(Vector3.UP) < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, n))


## Leuchtfarbe (Augen, Fluch-Akzente): Boss = Siegelrot, Akzent (Elite lila),
## sonst c — dazu die Leuchtstärke.
static func _glut(k: Dictionary, c: Color, leuchten := 0.0) -> Array:
	if k.get("boss", false):
		return [_p("boss_siegel"), 0.8]
	var akzent: Variant = k.get("akzent", null)
	if akzent != null:
		return [akzent, maxf(leuchten, 0.7)]
	return [c, leuchten]


static func _horn(k: Dictionary) -> float:
	return 1.3 if k.get("boss", false) else 1.0


## Ein vorbereiteter Teil-Bausatz (lokale Maße) mit Lage t in ziel — t in
## Figurmaßen (der Maßstab der Puppe wird auf die Verschiebung angewandt).
static func _einfuegen(pu: Gliederpuppe, ziel: Bausatz, quelle: Bausatz, t: Transform3D) -> void:
	ziel.bausatz(quelle, Transform3D(t.basis, t.origin * pu.massstab))


# --- Einstieg ----------------------------------------------------------------------

## Figur aus dem Mesh-Cache (Schlüssel Art | Größe | Boss | Akzent | Farbe).
## farbe: nur Schleim (Beschwörung, bunter Fallback-Schleim).
static func gegner(id: StringName, massstab := 1.0, boss := false, akzent: Variant = null,
		farbe: Variant = null) -> Node3D:
	var g := float(GROESSE.get(id, 1.0)) * massstab
	var key := "vb|%s|%.3f|%s|%s|%s" % [id, g, boss, (akzent as Color).to_html(false) if akzent != null else "-",
		(farbe as Color).to_html(false) if farbe != null else "-"]
	var k := {"boss": boss, "akzent": akzent, "farbe": farbe}
	var fig := Gliederpuppe.gebacken(key, func() -> Gliederpuppe: return puppe(id, g, k))
	if id == &"schleimgott":
		FigurenBau.boden_schmuck(fig, "gott_ring")  # Glutscheibe mit Runen, bleibt am Boden
	return fig


static func puppe(id: StringName, g: float, k: Dictionary) -> Gliederpuppe:
	var pu := Gliederpuppe.new(String(id).capitalize(), g)
	pu.meta("anim", String(ANIM.get(id, "hund"))).meta("wippen", 0.02).meta("drehung", 38.0)
	match id:
		&"wolf":
			_wolf(pu, k)
		&"baer":
			_baer(pu, k)
		&"schattenbestie":
			_schattenbestie(pu, k)
		&"leichenfresser":
			_leichenfresser(pu, k)
		&"demonenjager":
			_demonenjager(pu, k)
		&"verfluchtkatz":
			_katze(pu, k)
		&"verfluchtdachs":
			_dachs(pu, k)
		&"verfluchtbock":
			_bock(pu, k)
		&"verfluchtigel", &"igel":
			_igel(pu, k, id == &"verfluchtigel")
		&"schleim":
			_schleim(pu, k)
		&"schleimstapel":
			_stapel(pu, k)
		&"koenigschleim":
			_koenig(pu, k)
		&"schleimgott":
			_gott(pu, k)
	return pu


# --- Vierbeiner-Gerüst ---------------------------------------------------------------

## Beine, Rumpf und Brust im Glied "koerper" (Gelenk an den Hinterpfoten).
## p: fell, pfote, bein_v/bein_h (Länge vorn/hinten), bein_r, rumpf_r,
## laenge, breite, hufe, bauch, kopf_versatz. Liefert Maße für die Extras.
static func _chassis(pu: Gliederpuppe, p: Dictionary) -> Dictionary:
	var fell: Color = p["fell"]
	var pfote: Color = p.get("pfote", fell * 0.8)
	var bv: float = p.get("bein_v", 0.26)
	var bh: float = p.get("bein_h", 0.26)
	var br: float = p.get("bein_r", 0.05)
	var rr: float = p.get("rumpf_r", 0.19)
	var lang: float = p.get("laenge", 1.0)
	var bx := 0.12 * float(p.get("breite", 1.0))
	var zf := 0.18 * lang
	var zb := -0.2 * lang
	var gelenk := Vector3(0, 0.04, zb)
	var k := Satz.new(pu.glied("koerper", gelenk), gelenk)
	for s: float in [-1.0, 1.0]:
		var x := bx * s
		for vorn: bool in [true, false]:
			var z := zf if vorn else zb
			var bl := bv if vorn else bh
			k.t(Stil3D.zylinder(br, br * 1.12, bl, 8), fell, Vector3(x, bl * 0.5 + 0.04, z))
			if p.get("hufe", false):
				k.t(Stil3D.zylinder(br * 1.05, br * 1.3, 0.07), pfote, Vector3(x, 0.035, z))
			else:
				k.t(Stil3D.kugel(br * 1.45, br * 1.3), pfote, Vector3(x, 0.045, z + 0.025))
		k.t(Stil3D.kugel(rr * 0.62, -1.0, 8), fell, Vector3(x * 1.05, bh + 0.06, zb + 0.01))  # Keule
		k.t(Stil3D.kugel(rr * 0.55, -1.0, 8), fell, Vector3(x, bv + 0.06, zf))  # Schulter
	var yv := bv + 0.04 + rr * 0.75
	var yh := bh + 0.04 + rr * 0.75
	var neig := rad_to_deg(atan2(yv - yh, zf - zb))
	var mitte := Vector3(0, (yv + yh) * 0.5, (zf + zb) * 0.5)
	k.t(Stil3D.kapsel(rr, (zf - zb) + rr * 2.0), fell, mitte, Vector3(90.0 - neig, 0, 0))
	k.t(Stil3D.kugel(rr * 1.06), fell, Vector3(0, yv + 0.01, zf + 0.04))  # Brust
	if p.has("bauch"):
		k.t(Stil3D.kugel(rr * 0.72, rr * 1.15), p["bauch"], Vector3(0, yv - rr * 0.18, zf + rr * 0.72),
			Vector3.ZERO, false)
	var hals := Vector3(0, yv + rr * 0.55, zf + rr * 0.55) + (p.get("kopf_versatz", Vector3.ZERO) as Vector3)
	pu.meta("anker_ruecken", Vector3(0, mitte.y + rr * 0.9, mitte.z))
	# Porträt als Brustbild ab Bauchhöhe: der Kopf füllt das Bild, Ringe und
	# lange Schwänze machen die Figur nicht klein (PortraitStudio._einrahmen).
	pu.meta("brust_y", mitte.y - rr * 0.35)
	return {"k": k, "yv": yv, "yh": yh, "zf": zf, "zb": zb, "rr": rr, "mitte": mitte, "neig": neig, "hals": hals,
		"steiss": Vector3(0, yh + rr * 0.35, zb - rr * 0.85), "bx": bx}


## Kopf-Glied am Hals (lokale Maße, Kopfmitte c): Schädel, Schnauze,
## Augen mit Iris/Pupille/Glanz, Brauen, Ohren; Kiefer als eigenes Glied.
## p zusätzlich: kopf_r, kopf_fell, schnauze, schnauze_art (lang/kurz/
## kegel/katze), kiefer (false = gebacken), kiefer_ruhe, maul, maul_leuchten,
## zaehne, iris, iris_leuchten, pupille, hohl, auge_r/auge_x/auge_y,
## auge_links (Faktor), brauen (Winkel, 0 = keine), braue_farbe, ohren
## (spitz/katze/rund/blatt), ohr_innen, ohr_knick (linkes Ohr abgeknickt).
static func _kopf(pu: Gliederpuppe, ch: Dictionary, p: Dictionary, k: Dictionary) -> Dictionary:
	var hals: Vector3 = ch["hals"]
	var h := Satz.new(pu.glied("kopf", hals, Vector3.ZERO, "koerper"))
	var kr: float = p.get("kopf_r", 0.17)
	var fell: Color = p.get("kopf_fell", p["fell"])
	var sn: Color = p.get("schnauze", fell * 1.15)
	var c := Vector3(0, kr * 0.55, kr * 0.3)
	h.t(Stil3D.kugel(kr, kr * 1.85), fell, c)
	var kiefer: Satz = null
	var mit_kiefer: bool = p.get("kiefer", true)
	var maul: Color = p.get("maul", _p("mund"))
	var maul_l: float = p.get("maul_leuchten", 0.0)
	match String(p.get("schnauze_art", "lang")):
		"lang":
			h.t(Stil3D.kapsel(kr * 0.42, kr * 1.35), sn, c + Vector3(0, -kr * 0.22, kr * 0.92), Vector3(84, 0, 0))
			h.t(Stil3D.kugel(kr * 0.2, kr * 0.16), _p("schwarz"), c + Vector3(0, -kr * 0.02, kr * 1.6))
			var kl := c + Vector3(0, -kr * 0.52, kr * 0.45)
			var kb: Satz = h
			if mit_kiefer:
				kiefer = Satz.new(pu.glied("kiefer", hals + kl, p.get("kiefer_ruhe", Vector3.ZERO), "kopf"))
				kb = kiefer
			else:
				kb = Satz.new(h.b, -kl)
			kb.t(Stil3D.kapsel(kr * 0.28, kr * 1.05), sn * 0.88, Vector3(0, 0, kr * 0.5), Vector3(90, 0, 0))
			kb.t(Stil3D.kugel(kr * 0.22, kr * 0.12), maul, Vector3(0, kr * 0.16, kr * 0.55), Vector3.ZERO, false, maul_l)
			if p.get("zaehne", true):
				for s: float in [-1.0, 1.0]:
					h.t(Stil3D.kegel(kr * 0.09, kr * 0.28), _p("weiss"), c + Vector3(kr * 0.2 * s, -kr * 0.5, kr * 1.3),
						Vector3(180, 0, 0), false)
		"kurz":
			h.t(Stil3D.kugel(kr * 0.5, kr * 0.78), sn, c + Vector3(0, -kr * 0.32, kr * 0.82))
			h.t(Stil3D.kugel(kr * 0.22, kr * 0.16), _p("schwarz"), c + Vector3(0, -kr * 0.16, kr * 1.28))
			var kl := c + Vector3(0, -kr * 0.62, kr * 0.6)
			kiefer = Satz.new(pu.glied("kiefer", hals + kl, Vector3.ZERO, "kopf"))
			kiefer.t(Stil3D.kugel(kr * 0.34, kr * 0.3), sn * 0.85, Vector3(0, 0, kr * 0.25))
			kiefer.t(Stil3D.kugel(kr * 0.22, kr * 0.1), maul, Vector3(0, kr * 0.1, kr * 0.38), Vector3.ZERO, false)
			for s: float in [-1.0, 1.0]:
				h.t(Stil3D.kegel(kr * 0.07, kr * 0.2), _p("weiss"), c + Vector3(kr * 0.16 * s, -kr * 0.6, kr * 1.02),
					Vector3(180, 0, 0), false)
		"kegel":
			h.t(Stil3D.kegel(kr * 0.5, kr * 1.15), sn, c + Vector3(0, -kr * 0.2, kr * 1.0), Vector3(90, 0, 0))
			h.t(Stil3D.kugel(kr * 0.19), _p("schwarz"), c + Vector3(0, -kr * 0.2, kr * 1.6))
			if mit_kiefer:
				var kl := c + Vector3(0, -kr * 0.48, kr * 0.62)
				kiefer = Satz.new(pu.glied("kiefer", hals + kl, Vector3.ZERO, "kopf"))
				kiefer.t(Stil3D.kapsel(kr * 0.2, kr * 0.75), sn * 0.85, Vector3(0, 0, kr * 0.3), Vector3(90, 0, 0))
				kiefer.t(Stil3D.kugel(kr * 0.16, kr * 0.09), maul, Vector3(0, kr * 0.12, kr * 0.36), Vector3.ZERO, false)
		"katze":
			for s: float in [-1.0, 1.0]:
				h.t(Stil3D.kugel(kr * 0.3, kr * 0.26), sn, c + Vector3(kr * 0.17 * s, -kr * 0.42, kr * 0.84))
				for i in 3:
					h.t(Stil3D.box(kr * 0.75, kr * 0.025, kr * 0.025), _p("weiss"),
						c + Vector3(kr * 0.62 * s, -kr * (0.36 + i * 0.09), kr * 0.82), Vector3(0, 0, (8.0 - i * 9.0) * s),
						false)
			h.t(Stil3D.kugel(kr * 0.12, kr * 0.09), _p("rosenquarz"), c + Vector3(0, -kr * 0.27, kr * 0.99),
				Vector3.ZERO, false)
			h.t(Stil3D.box(kr * 0.16, kr * 0.04, kr * 0.04), maul, c + Vector3(0, -kr * 0.58, kr * 0.9), Vector3.ZERO,
				false)
	# Augen: Weiß (bzw. Höhle) + Iris + Pupille + Glanz, Brauen darüber
	var glut := _glut(k, p.get("iris", _p("glut")), float(p.get("iris_leuchten", 0.0)))
	var ar: float = kr * float(p.get("auge_r", 0.27))
	var ax: float = p.get("auge_x", 0.42)
	var ay: float = p.get("auge_y", 0.2)
	var brauen: float = p.get("brauen", 22.0)
	for s: float in [-1.0, 1.0]:
		var r_s := ar * (float(p.get("auge_links", 1.0)) if s < 0.0 else 1.0)
		var ap := c + Vector3(kr * ax * s, kr * ay, kr * 0.78)
		h.auge(ap, r_s, {"seite": s, "iris": glut[0], "iris_leuchten": glut[1],
			"pupille": p.get("pupille", "rund"), "hohl": p.get("hohl", false),
			"blick": Vector3(0.18 * s, 0, 1)})
		if not is_zero_approx(brauen):
			h.braue(ap + Vector3(0, r_s * 1.05, r_s * 0.35), r_s * 1.7, s, brauen,
				p.get("braue_farbe", Color("1b1a24")))
	# Ohren
	var ohr_innen: Color = p.get("ohr_innen", _p("rosenquarz") * 0.8)
	for s: float in [-1.0, 1.0]:
		match String(p.get("ohren", "spitz")):
			"spitz":
				var rot := Vector3(-8, 0, -16 * s)
				var pos := c + Vector3(kr * 0.55 * s, kr * 0.95, -kr * 0.12)
				if s < 0.0 and p.get("ohr_knick", false):
					rot = Vector3(-20, 0, 70)  # abgeknickt, hängt seitlich
					pos = c + Vector3(-kr * 0.85, kr * 0.62, -kr * 0.1)
				h.t(Stil3D.kegel(kr * 0.4, kr * 1.15), fell, pos, rot)
				h.tb(Stil3D.kegel(kr * 0.22, kr * 0.7), ohr_innen, Basis.from_euler(rot * GRAD),
					pos + Basis.from_euler(rot * GRAD) * Vector3(0, -kr * 0.07, kr * 0.15), false)
			"katze":
				var rot := Vector3(-5, 0, -22 * s)
				h.t(Stil3D.kegel(kr * 0.42, kr * 0.95), fell, c + Vector3(kr * 0.6 * s, kr * 0.8, -kr * 0.05), rot)
				h.t(Stil3D.kegel(kr * 0.24, kr * 0.6), ohr_innen, c + Vector3(kr * 0.6 * s, kr * 0.75, kr * 0.12), rot,
					false, float(p.get("ohr_leuchten", 0.0)))
			"rund":
				h.t(Stil3D.kugel(kr * 0.36, kr * 0.3), p.get("ohr_fell", fell), c + Vector3(kr * 0.7 * s, kr * 0.75, -kr * 0.1))
				h.t(Stil3D.kugel(kr * 0.2, kr * 0.12), ohr_innen, c + Vector3(kr * 0.7 * s, kr * 0.75, kr * 0.12),
					Vector3.ZERO, false)
			"blatt":
				h.t(Stil3D.kapsel(kr * 0.22, kr * 1.0), fell, c + Vector3(kr * 1.05 * s, kr * 0.55, -kr * 0.15),
					Vector3(0, 0, -70 * s))
				h.t(Stil3D.kapsel(kr * 0.12, kr * 0.65), ohr_innen, c + Vector3(kr * 1.08 * s, kr * 0.55, -kr * 0.05),
					Vector3(0, 0, -70 * s), false)
	pu.meta("anker_kopf", c + Vector3(0, kr * 0.9, -kr * 0.1)).meta("anker_kopf_glied", "kopf")
	return {"h": h, "c": c, "kr": kr, "kiefer": kiefer}


## Schwanz-Glied am Steiß (lokale Maße).
static func _schwanz(pu: Gliederpuppe, ch: Dictionary) -> Satz:
	return Satz.new(pu.glied("schwanz", ch["steiss"], Vector3.ZERO, "koerper"))


## Kegelstumpf von a (Radius ra) nach z (Radius rz), ohne Hülle — Streifen,
## die der Kopfform folgen (Dachsmaske).
static func _strebe(s: Satz, a: Vector3, z: Vector3, ra: float, rz: float, farbe: Color, kontur := false) -> void:
	s.tb(Stil3D.zylinder(rz, ra, a.distance_to(z) + (ra + rz) * 0.5), farbe, _zu(z - a), (a + z) * 0.5, kontur)


## Kugelkette entlang d (Busch-, Peitschen- und Flammenschwänze).
static func _kette(s: Satz, start: Vector3, d: Vector3, glieder: Array) -> void:
	for g in glieder:
		var abstand: float = g[0]
		var r: float = g[1]
		s.tb(Stil3D.kugel(r, r * float(g[3]) if g.size() > 3 else r * 2.0), g[2], _zu(d), start + d.normalized() * abstand)


# --- Vierbeiner ------------------------------------------------------------------------

## Grauwolf: Spitzohren, buschiger Schwanz schräg nach oben, helle Halskrause
## statt roter Mähne, dunkler Sattel, gelbe Wolfsaugen.
static func _wolf(pu: Gliederpuppe, k: Dictionary) -> void:
	var fell := _p("fell")
	var hell := _p("fell_hell")
	var p := {"fell": fell, "bauch": hell, "pfote": fell * 0.75, "schnauze": hell, "kopf_r": 0.17,
		"iris": _p("glut"), "iris_leuchten": 0.25}
	var ch := _chassis(pu, p)
	var kk: Satz = ch["k"]
	var neig: float = ch["neig"]
	kk.t(Stil3D.kugel(0.17, 0.12), fell * 0.7, (ch["mitte"] as Vector3) + Vector3(0, 0.165, -0.03),
		Vector3(-neig, 0, 0), false)  # Sattel
	var krause := Vector3(0, float(ch["yv"]) + 0.1, float(ch["zf"]) + 0.06)
	for i in 7:
		var w := deg_to_rad(-75.0 + i * 25.0)
		var d := Vector3(sin(w), 0.35, -0.55 + cos(w) * 0.2)
		kk.tb(Stil3D.kegel(0.07, 0.2, 6), hell, _zu(d), krause + Vector3(sin(w) * 0.17, 0.02, 0))
	_kopf(pu, ch, p, k)
	var sw := _schwanz(pu, ch)
	var d := Vector3(0, sin(25.0 * GRAD), -cos(25.0 * GRAD))
	_kette(sw, Vector3.ZERO, d, [[0.07, 0.07, fell, 2.3], [0.17, 0.09, fell, 2.3], [0.28, 0.08, hell, 2.2]])


## Braunbär (Tank): Schulterbuckel, tief hängender Kopf, Rundohren, kleine
## Knopfaugen, helle Mondsichel auf der Brust, Krallen.
static func _baer(pu: Gliederpuppe, k: Dictionary) -> void:
	var braun := _p("braun")
	var p := {"fell": braun, "pfote": braun * 0.7, "schnauze": _p("braun_hell"), "schnauze_art": "kurz",
		"ohren": "rund", "ohr_innen": _p("braun_hell"), "iris": _p("schwarz"), "auge_r": 0.2, "kopf_r": 0.2,
		"rumpf_r": 0.25, "bein_r": 0.075, "bein_v": 0.24, "bein_h": 0.22, "breite": 1.25, "laenge": 0.95,
		"auge_y": 0.25, "brauen": 26.0, "kopf_versatz": Vector3(0, -0.05, 0.03)}
	var ch := _chassis(pu, p)
	var kk: Satz = ch["k"]
	var yv: float = ch["yv"]
	var zf: float = ch["zf"]
	kk.t(Stil3D.kugel(0.24, 0.3), braun, Vector3(0, yv + 0.18, zf - 0.06))  # Schulterbuckel
	for s: float in [-1.0, 1.0]:
		kk.t(Stil3D.kapsel(0.03, 0.2), _p("knochen"), Vector3(0.06 * s, yv - 0.03, zf + 0.27), Vector3(0, 0, 52 * s),
			false)  # Mondsichel
		for i in 3:
			kk.t(Stil3D.kegel(0.018, 0.07), _p("knochen"), Vector3(0.15 * s + (i - 1) * 0.03, 0.03, zf + 0.13),
				Vector3(90, 0, 0), false)
	kk.t(Stil3D.kugel(0.07), braun, ch["steiss"])  # Stummelschwanz
	_kopf(pu, ch, p, k)


## Schattenpanther: lang und niedrig, Rückenkamm aus Flossen mit glimmenden
## Spitzen, Hörner nach hinten, Höhlenaugen mit Schlitz, drittes Stirnauge,
## glühendes Maul (Dunkler Odem), Peitschenschwanz mit Pfeilspitze.
static func _schattenbestie(pu: Gliederpuppe, k: Dictionary) -> void:
	var fell := _p("schatten")
	var lila := _p("lila")
	var horn := _horn(k)
	var akz := _glut(k, lila, 1.0)
	var p := {"fell": fell, "pfote": fell * 0.7, "schnauze": fell * 1.15, "iris": _p("glut"), "iris_leuchten": 0.9,
		"pupille": "schlitz", "hohl": true, "kopf_r": 0.16, "rumpf_r": 0.17, "laenge": 1.25, "bein_r": 0.045,
		"bein_v": 0.29, "bein_h": 0.27, "ohr_innen": lila, "maul": _p("glut") * 0.6, "maul_leuchten": 0.6,
		"braue_farbe": _p("lila_dunkel")}
	var ch := _chassis(pu, p)
	var kk: Satz = ch["k"]
	var yv: float = ch["yv"]
	var yh: float = ch["yh"]
	for i in 6:
		var t := float(i) / 5.0
		var z := lerpf(float(ch["zf"]) + 0.05, float(ch["zb"]) - 0.02, t)
		var hoch := (0.12 + sin(t * PI) * 0.12) * horn
		var y := lerpf(yv, yh, t) + 0.15
		kk.t(Stil3D.prisma(0.05, hoch, 0.12), _p("robe_lila"), Vector3(0, y + hoch * 0.4, z), Vector3(-15, 0, 0))
		kk.t(Stil3D.kegel(0.02, 0.06), akz[0], Vector3(0, y + hoch * 0.92, z - 0.02), Vector3(-15, 0, 0), false, akz[1])
	var kp := _kopf(pu, ch, p, k)
	var h: Satz = kp["h"]
	var c: Vector3 = kp["c"]
	for s: float in [-1.0, 1.0]:
		Gliederpuppe.kette(h.b, Transform3D(Basis.from_euler(Vector3(-62, 0, -14 * s) * GRAD), c + Vector3(0.08 * s, 0.11, -0.06)),
			3, 0.22 * horn, 0.04, 0.008, Vector3(-10, 0, 0), _p("lila_dunkel"),
			_p("boss_siegel") if horn > 1.0 else null, 0.6 if horn > 1.0 else 0.0)
	h.t(Stil3D.kugel(0.026), akz[0], c + Vector3(0, 0.115, 0.135), Vector3.ZERO, false, akz[1])  # drittes Auge
	# Boss-Krone tiefer: der runde Schädel ist oben schmal, am Anker schwebte sie.
	pu.meta("krone_sitz", {"versatz": Vector3(0, -0.04, 0)})
	var sw := _schwanz(pu, ch)
	for i in 3:
		sw.t(Stil3D.kugel(0.06 - i * 0.012), fell, Vector3(0, 0.05 + i * 0.1, -0.06 - i * 0.07))
	sw.t(Stil3D.prisma(0.14, 0.12, 0.03), akz[0], Vector3(0, 0.36, -0.27), Vector3(-30, 0, 0), true, 0.6)


## Krypta-Ghul-Hyäne: abfallender Rücken, Kopf tief vor der Brust, Wirbel
## und Rippen außen, Lederfetzen-Mähne, ein Ohr abgeknickt, ungleiche
## Höhlenaugen, offener Kiefer mit Zunge und Knochen, Rattenschwanz.
static func _leichenfresser(pu: Gliederpuppe, k: Dictionary) -> void:
	var fahl := _p("fahl")
	var knochen := _p("knochen")
	var p := {"fell": fahl, "pfote": fahl * 0.7, "schnauze": fahl * 0.92, "iris": _p("seele"), "iris_leuchten": 0.9,
		"hohl": true, "kopf_r": 0.16, "rumpf_r": 0.17, "bein_v": 0.34, "bein_h": 0.18, "laenge": 0.95,
		"kopf_versatz": Vector3(0, -0.1, 0.05), "ohr_innen": _p("mund"), "ohr_knick": true, "auge_links": 1.25,
		"kiefer_ruhe": Vector3(22, 0, 0)}
	var ch := _chassis(pu, p)
	var kk: Satz = ch["k"]
	var yv: float = ch["yv"]
	var yh: float = ch["yh"]
	var zf: float = ch["zf"]
	var zb: float = ch["zb"]
	var mitte: Vector3 = ch["mitte"]
	for i in 5:
		var t := float(i) / 4.0
		kk.t(Stil3D.kugel(0.036), knochen, Vector3(0, lerpf(yv, yh, t) + 0.17, lerpf(zf, zb, t)))  # Wirbel
	for s: float in [-1.0, 1.0]:
		for i in 3:
			kk.t(Stil3D.kapsel(0.016, 0.16), knochen, Vector3(0.165 * s, mitte.y, mitte.z + 0.08 - i * 0.07),
				Vector3(0, 0, 18 * s), false)
	for i in 4:  # zerzauste Lederfetzen im Nacken, flach nach hinten gelegt
		var s := -1.0 if i % 2 == 0 else 1.0
		kk.t(Stil3D.prisma(0.07, 0.12 - i * 0.012, 0.025), _p("leder") * (0.85 + (i % 2) * 0.15),
			Vector3(0.025 * s, yv + 0.2 - i * 0.03, zf + 0.02 - i * 0.07), Vector3(-62, 0, 18 * s))
	var kp := _kopf(pu, ch, p, k)
	# Boss-Krone auf den Hinterkopf gerutscht und kleiner: der Kopf hängt tief
	# und nickt (Idle-Zucken, Schnüffeln) — von oben lag sie sonst vor dem Gesicht.
	pu.meta("krone_sitz", {"versatz": Vector3(0, -0.035, -0.05), "neigung": Vector3(-30, 0, 0), "groesse": 0.85})
	var kiefer: Satz = kp["kiefer"]
	kiefer.t(Stil3D.kapsel(0.03, 0.14), _p("pilz_rot"), Vector3(0.02, -0.02, 0.15), Vector3(70, 0, 0), false)  # Zunge
	kiefer.t(Stil3D.kapsel(0.018, 0.2), knochen * 0.9, Vector3(0, 0.035, 0.07), Vector3(0, 0, 90))  # Knochen quer
	for s: float in [-1.0, 1.0]:
		kiefer.t(Stil3D.kugel(0.025), knochen * 0.9, Vector3(0.1 * s, 0.035, 0.07))
	var sw := _schwanz(pu, ch)
	sw.t(Stil3D.zylinder(0.012, 0.03, 0.3), fahl, Vector3(0, -0.08, -0.12), Vector3(-130, 0, 0))


## Höllenhund-Jäger: Sichelhörner, Flammenmähne, Tigerstreifen, Halsband
## mit Dornen, Schlitzaugen, Flammenschwanz mit Glutkern.
static func _demonenjager(pu: Gliederpuppe, k: Dictionary) -> void:
	var fell := _p("daemon")
	var dunkel := _p("daemon_dunkel")
	var horn := _horn(k)
	var p := {"fell": fell, "pfote": dunkel, "schnauze": fell * 0.85, "iris": _p("glut"), "iris_leuchten": 0.8,
		"pupille": "schlitz", "kopf_r": 0.17, "rumpf_r": 0.19, "bein_r": 0.052, "ohr_innen": _p("schwarz")}
	var ch := _chassis(pu, p)
	var kk: Satz = ch["k"]
	var mitte: Vector3 = ch["mitte"]
	var neig: float = ch["neig"]
	var yv: float = ch["yv"]
	var zf: float = ch["zf"]
	var steig := tan(neig * GRAD)
	for i in 3:  # Tigerstreifen: je zwei flache Leisten als Dach quer über den Rücken
		var dz := 0.13 - i * 0.12
		for s: float in [-1.0, 1.0]:
			kk.t(Stil3D.box(0.04, 0.2, 0.055), dunkel, mitte + Vector3(0.075 * s, 0.17 + dz * steig, dz),
				Vector3(-neig, 0, 58 * s), false)
	var hals := Vector3(0, yv + 0.1, zf + 0.1)
	kk.t(Stil3D.zylinder(0.17, 0.19, 0.07, 10), _p("schwarz") * 1.4, hals, Vector3(55, 0, 0))  # Halsband
	var quer := Vector3(0, cos(35.0 * GRAD), -sin(35.0 * GRAD))  # in der Halsband-Ebene, nach oben-hinten
	for i in 6:  # Dornen radial in der Ebene des Halsbands (keiner sticht in den Kopf)
		var w := deg_to_rad(30.0 + i * 60.0)
		var d := Vector3.RIGHT * cos(w) + quer * sin(w)
		kk.tb(Stil3D.kegel(0.025, 0.08, 6), _p("eisen") * 1.3, _zu(d), hals + d.normalized() * 0.19, false)
	for i in 4:  # Flammenmähne: hinter dem Kopf den Nacken entlang, lang/kurz im Wechsel
		var hoch := 0.2 + (1 - i % 2) * 0.08 - i * 0.015
		kk.t(Stil3D.kegel(0.055, hoch, 7), _p("flamme"), Vector3(0, yv + 0.2 - i * 0.03 + hoch * 0.3, zf - 0.08 - i * 0.075),
			Vector3(-40, 0, 0), true, 0.8)
	var kp := _kopf(pu, ch, p, k)
	var h: Satz = kp["h"]
	var c: Vector3 = kp["c"]
	for s: float in [-1.0, 1.0]:  # zweiteilige Sichelhörner nach oben-außen
		Gliederpuppe.kette(h.b, Transform3D(Basis.from_euler(Vector3(-12, 0, -55 * s) * GRAD), c + Vector3(0.11 * s, 0.12, 0.02)),
			2, 0.28 * horn, 0.045, 0.01, Vector3(-28, 0, 38 * s), _p("knochen"),
			_p("boss_siegel") if horn > 1.0 else null, 0.6 if horn > 1.0 else 0.0)
	var sw := _schwanz(pu, ch)
	sw.t(Stil3D.kapsel(0.035, 0.32), dunkel, Vector3(0, 0.1, -0.1), Vector3(-30, 0, 0))
	sw.t(Stil3D.kegel(0.07, 0.2, 8), _p("flamme"), Vector3(0, 0.28, -0.2), Vector3(-20, 0, 0), true, 0.85)
	sw.t(Stil3D.kugel(0.04), _p("glut"), Vector3(0, 0.24, -0.19), Vector3.ZERO, false, 1.0)


## Verfluchte Hexenkatze: Riesenkopf mit Dreiecksohren (lila innen), Buckel,
## Fragezeichen-Schwanz mit Fluchflamme, übergroße lila Schlitzaugen ohne
## böse Brauen, Schnurrhaare, Fluchzeichen, Halsband mit Glöckchen.
static func _katze(pu: Gliederpuppe, k: Dictionary) -> void:
	var fell := _p("obsidian")
	var akz := _glut(k, _p("lila"), 0.8)
	var p := {"fell": fell, "pfote": fell * 1.3, "schnauze": fell * 1.6, "schnauze_art": "katze", "ohren": "katze",
		"ohr_innen": _p("lila"), "iris": _p("lila"), "iris_leuchten": 0.7, "pupille": "schlitz", "kopf_r": 0.23,
		"auge_r": 0.34, "auge_x": 0.4, "auge_y": 0.12, "rumpf_r": 0.15, "bein_r": 0.04, "bein_v": 0.22,
		"bein_h": 0.22, "laenge": 0.85, "brauen": 0.0, "kiefer": false}
	var ch := _chassis(pu, p)
	var kk: Satz = ch["k"]
	kk.t(Stil3D.kugel(0.16), fell, (ch["mitte"] as Vector3) + Vector3(0, 0.06, -0.02))  # Buckel
	var hals := Vector3(0, float(ch["yv"]) + 0.08, float(ch["zf"]) + 0.1)
	kk.t(Stil3D.zylinder(0.13, 0.14, 0.035), akz[0], hals, Vector3(50, 0, 0), false, 0.3)
	kk.t(Stil3D.kugel(0.04), _p("gold"), hals + Vector3(0, -0.1, 0.09))  # Glöckchen
	var kp := _kopf(pu, ch, p, k)
	var h: Satz = kp["h"]
	h.t(Stil3D.prisma(0.05, 0.05, 0.01), akz[0], (kp["c"] as Vector3) + Vector3(0, 0.19, 0.19), Vector3(-20, 0, 180),
		false, 0.9)  # Fluchzeichen
	var sw := _schwanz(pu, ch)
	sw.t(Stil3D.kapsel(0.04, 0.3), fell, Vector3(0, 0.14, -0.04), Vector3(-12, 0, 0))
	sw.t(Stil3D.kapsel(0.04, 0.2), fell, Vector3(0, 0.33, 0.02), Vector3(40, 0, 0))
	sw.t(Stil3D.kugel(0.05, 0.08), akz[0], Vector3(0, 0.41, 0.08), Vector3(30, 0, 0), true, 0.8)


## Panzer-Dachs (Tank): flacher breiter Keil, Kegelkopf mit breiten
## schwarzen Längsstreifen über den Augen und hellem Mittelstreifen,
## drei überlappende Panzerplatten mit Fluchrunen, Grabkrallen.
static func _dachs(pu: Gliederpuppe, k: Dictionary) -> void:
	var fell := _p("eisen")
	var akz := _glut(k, _p("lila"), 0.9)
	var p := {"fell": fell, "pfote": _p("schwarz") * 1.5, "kopf_fell": _p("fell_hell"), "schnauze": _p("fell_hell") * 0.95,
		"schnauze_art": "kegel", "ohren": "rund", "ohr_fell": _p("schwarz") * 1.3, "ohr_innen": _p("fell_hell"),
		"iris": _p("lila"), "iris_leuchten": 0.7, "auge_r": 0.22, "auge_y": 0.15, "kopf_r": 0.16, "rumpf_r": 0.22,
		"bein_r": 0.06, "bein_v": 0.13, "bein_h": 0.13, "breite": 1.35, "laenge": 1.0, "brauen": 28.0,
		"kopf_versatz": Vector3(0, -0.06, 0.02)}
	var ch := _chassis(pu, p)
	var kk: Satz = ch["k"]
	var mitte: Vector3 = ch["mitte"]
	var zf: float = ch["zf"]
	kk.t(Stil3D.kugel(0.3, 0.3), fell, mitte + Vector3(0, 0.02, 0))  # breiter Keil
	for i in 3:  # Panzerplatten wie Dachziegel, je mit leuchtender Raute
		var pos := mitte + Vector3(0, 0.18 + (1 - absi(i - 1)) * 0.02, 0.14 - i * 0.135)
		kk.t(Stil3D.box(0.34, 0.07, 0.17), _p("stein_dunkel") * 1.15, pos, Vector3(-12, 0, 0))
		kk.t(Stil3D.box(0.075, 0.012, 0.075), akz[0], pos + Vector3(0, 0.04, 0.008), Vector3(-12, 45, 0), false, akz[1])
	for s: float in [-1.0, 1.0]:
		for i in 3:
			kk.t(Stil3D.kegel(0.018, 0.09), _p("knochen"), Vector3(0.162 * s + (i - 1) * 0.03, 0.03, zf + 0.1),
				Vector3(90, 0, 0), false)
	kk.t(Stil3D.kugel(0.06, 0.09), fell * 0.9, ch["steiss"])  # Stummelschwanz
	var kp := _kopf(pu, ch, p, k)
	var h: Satz = kp["h"]
	var c: Vector3 = kp["c"]
	var kr: float = kp["kr"]
	var maske := _p("schwarz") * 1.3
	for s: float in [-1.0, 1.0]:  # breite Längsstreifen: hinter den Ohren über die Augen spitz bis auf die Schnauze
		var hinten := c + Vector3(0.078 * s, 0.075, -0.13)
		var auge := c + Vector3(0.062 * s, 0.04, 0.1)
		var nase := c + Vector3(0.014 * s, -kr * 0.2 + 0.028, kr * 1.36)
		_strebe(h, hinten, auge, 0.056, 0.05, maske)
		_strebe(h, auge, nase, 0.046, 0.013, maske)
	h.t(Stil3D.kapsel(0.035, 0.3), _p("weiss") * 0.97, c + Vector3(0, kr * 0.8, -0.01), Vector3(75, 0, 0))  # Mittelstreifen


## Verfluchter Hirschbock: Geweihkrone mit Fluchkristallen und Moos, langer
## Hals mit Nackenmähne, schmaler Kopf mit Blattohren und Ziegenbart,
## kräftiger Rumpf mit hellem Bauch und weißem Spiegel, schwarze Hufe.
static func _bock(pu: Gliederpuppe, k: Dictionary) -> void:
	var braun := _p("braun")
	var horn := _horn(k)
	var akz := _glut(k, _p("lila"), 0.85)
	var p := {"fell": braun, "pfote": _p("schwarz") * 1.4, "hufe": true, "schnauze": _p("braun_hell"),
		"bauch": _p("braun_hell"), "iris": _p("lila"), "iris_leuchten": 0.7, "kopf_r": 0.14, "rumpf_r": 0.21,
		"bein_r": 0.05, "bein_v": 0.34, "bein_h": 0.32, "laenge": 1.05, "ohren": "blatt", "ohr_innen": _p("braun_hell"),
		"kopf_versatz": Vector3(0, 0.2, 0.08), "kiefer": false, "zaehne": false}
	var ch := _chassis(pu, p)
	var kk: Satz = ch["k"]
	var yv: float = ch["yv"]
	var zf: float = ch["zf"]
	kk.t(Stil3D.kapsel(0.1, 0.36), braun, Vector3(0, yv + 0.16, zf + 0.1), Vector3(32, 0, 0))  # Hals
	for i in 3:
		kk.t(Stil3D.prisma(0.06, 0.12, 0.08), _p("leder") * 0.8, Vector3(0, yv + 0.22 + i * 0.05, zf + 0.02 + i * 0.03),
			Vector3(-40, 0, 0))
	var steiss: Vector3 = ch["steiss"]
	kk.t(Stil3D.kugel(0.1, 0.12), _p("weiss"), steiss + Vector3(0, -0.02, 0.04), Vector3(-30, 0, 0), false)  # Spiegel
	var kp := _kopf(pu, ch, p, k)
	var h: Satz = kp["h"]
	var c: Vector3 = kp["c"]
	h.t(Stil3D.prisma(0.05, 0.1, 0.035), _p("schwarz") * 1.4, c + Vector3(0, -0.15, 0.115), Vector3(170, 0, 0))  # Bart
	h.t(Stil3D.box(0.04, 0.04, 0.01), akz[0], c + Vector3(0, 0.1, 0.135), Vector3(0, 0, 45), false, akz[1])  # Stirnrune
	for s: float in [-1.0, 1.0]:
		var basis := c + Vector3(0.07 * s, 0.12, -0.02)
		var stange := Vector3(0.35 * s, 1.0, -0.25).normalized()
		var l := 0.46 * horn
		h.tb(Stil3D.zylinder(0.018, 0.028, l, 7), _p("knochen"), _zu(stange), basis + stange * l * 0.5)
		for i in 3:
			var ast_pos := basis + stange * (0.14 + i * 0.12) * horn
			var ast := Vector3((0.9 - i * 0.3) * s, 0.8, 0.35).normalized()
			h.tb(Stil3D.zylinder(0.012, 0.018, 0.16 * horn, 6), _p("knochen"), _zu(ast), ast_pos + ast * 0.08 * horn)
			if i == 1:
				h.t(Stil3D.kegel(0.025, 0.1), _p("moos"), ast_pos + Vector3(0, -0.05, 0), Vector3(180, 0, 0), false)
		h.tb(Stil3D.prisma(0.05, 0.09, 0.05), akz[0], _zu(stange), basis + stange * (l + 0.03), true, akz[1])
	var sw := _schwanz(pu, ch)
	sw.t(Stil3D.kugel(0.05, 0.08), _p("weiss"), Vector3(0, 0.02, 0), Vector3(-40, 0, 0))


## Stachelkugel-Igel: voller Stachelkranz (drei Reihen + Schopf; Fluch:
## oberste Reihe leuchtet), Bauchkugel, Kopf vorn mit Kegelschnauze,
## Knopfnase, roten Augen und Bäckchen. Koerper-Gelenk in der Kugelmitte
## (Vorwärtsrolle), der Kopf hängt daran.
static func _igel(pu: Gliederpuppe, k: Dictionary, verflucht: bool) -> void:
	pu.meta("drehung", 30.0).meta("wippen", 0.01).meta("hoerner", true)
	var braun := _p("braun")
	var hell := _p("braun_hell")
	var horn := _horn(k)
	for x: float in [-0.12, 0.12]:
		for z: float in [-0.1, 0.12]:
			pu.rumpf.teil(Stil3D.kugel(0.05, 0.04), braun, Vector3(x, 0.02, z))
	var gelenk := Vector3(0, 0.22, 0)
	var kk := Satz.new(pu.glied("koerper", gelenk), gelenk)
	kk.t(Stil3D.kugel(0.28, 0.36), hell, Vector3(0, 0.2, 0.02))
	var schale := Vector3(0, 0.24, -0.05)
	kk.t(Stil3D.kugel(0.28, 0.38), braun, schale)
	var spitze := _glut(k, _p("lila") if verflucht else _p("robe_lila"), 0.5 if verflucht else 0.0)
	for reihe in 3:
		var hoch := deg_to_rad(15.0 + reihe * 28.0)
		var anzahl := 9 - reihe * 2
		for i in anzahl:
			var az := deg_to_rad(-105.0 + 210.0 * float(i) / float(anzahl - 1) + reihe * 7.0)
			var d := Vector3(sin(az) * cos(hoch), sin(hoch), -cos(az) * cos(hoch))
			var oben := reihe == 2
			kk.tb(Stil3D.kegel(0.055, 0.22 * horn), spitze[0] if oben else _p("robe_lila"), _zu(d),
				schale + d * (0.25 + 0.11 * (horn - 1.0)), true, spitze[1] if oben else 0.0)
	kk.t(Stil3D.kegel(0.06, 0.2 * horn), spitze[0], schale + Vector3(0, 0.3, 0.02), Vector3(-10, 0, 0), true, spitze[1])
	var kg := Vector3(0, 0.18, 0.18)
	var h := Satz.new(pu.glied("kopf", kg, Vector3.ZERO, "koerper"))
	h.t(Stil3D.kugel(0.13), hell, Vector3(0, 0.04, 0.04))
	h.t(Stil3D.kegel(0.11, 0.2), hell, Vector3(0, 0.0, 0.14), Vector3(90, 0, 0))
	h.t(Stil3D.kugel(0.042), _p("schwarz"), Vector3(0, 0.0, 0.25))
	var glut := _glut(k, _p("daemon"), 0.6 if verflucht else 0.0)
	for s: float in [-1.0, 1.0]:
		h.auge(Vector3(0.07 * s, 0.085, 0.13), 0.05, {"seite": s, "iris": glut[0], "iris_leuchten": glut[1],
			"blick": Vector3(0.2 * s, 0, 1)})
		h.braue(Vector3(0.072 * s, 0.14, 0.15), 0.08, s, 24.0)
		h.t(Stil3D.kugel(0.03, 0.015), _p("rosenquarz"), Vector3(0.105 * s, 0.0, 0.12), Vector3(0, 30 * s, 0), false)
	h.t(Stil3D.box(0.04, 0.012, 0.012), _p("mund"), Vector3(0, -0.045, 0.2), Vector3.ZERO, false)
	pu.meta("anker_kopf", Vector3(0, 0.17, 0.02)).meta("anker_kopf_glied", "kopf")
	pu.meta("anker_ruecken", Vector3(0, 0.46, -0.12)).meta("brust_y", 0.04)
	# Boss-Krone kleiner und weiter hinten: der Kopf ist kaum größer als sie
	# und saß sonst wie ein Hut über den Brauen.
	pu.meta("krone_sitz", {"versatz": Vector3(0, -0.01, -0.03), "neigung": Vector3(-15, 0, 0), "groesse": 0.7})


# --- Schleime ----------------------------------------------------------------------------

## Schleimkörper (Rumpf): Tropfen mit Glanzfleck, Glanzpunkt und Bläschen,
## zwei großen Augen, Brauen und offenem Mund. o: farbe, hell (Bläschen),
## glanz, brauen (Winkel), mund ("laecheln"/"o"/"grinsen"), pfuetze.
static func _schleim_koerper(b: Bausatz, o: Dictionary) -> void:
	var c: Color = o.get("farbe", _p("schleim"))
	var hell: Color = o.get("hell", c.lightened(0.45))
	if o.get("pfuetze", true):
		b.teil(Stil3D.zylinder(0.46, 0.5, 0.05), c * 0.85, Vector3(0, 0.025, 0))
	b.teil(Stil3D.kugel(0.42, 0.62), c, Vector3(0, 0.31, 0))
	var glanz: Color = o.get("glanz", _p("weiss"))
	b.teil(Stil3D.kapsel(0.045, 0.17), glanz, Vector3(-0.24, 0.46, 0.25), Vector3(0, 30, 35), false, 0.3)
	b.teil(Stil3D.kugel(0.03), glanz, Vector3(-0.15, 0.56, 0.24), Vector3.ZERO, false, 0.3)
	for v in [Vector3(0.28, 0.2, 0.27), Vector3(0.33, 0.36, 0.14), Vector3(-0.3, 0.16, 0.26)]:
		b.teil(Stil3D.kugel(0.03), hell, v, Vector3.ZERO, false, 0.15)
	var iris: Array = o.get("iris", [_p("schwarz"), 0.0])
	var brauen: float = o.get("brauen", -20.0)
	for s: float in [-1.0, 1.0]:
		Gliederpuppe.auge(b, Vector3(0.13 * s, 0.38, 0.33), 0.1, {"seite": s, "iris": iris[0], "iris_leuchten": iris[1]})
		if not is_zero_approx(brauen):
			Gliederpuppe.braue(b, Vector3(0.13 * s, 0.5, 0.37), 0.12, s, brauen)
	b.teil(Stil3D.kugel(0.1, 0.09), _p("mund"), Vector3(0, 0.22, 0.385), Vector3.ZERO, false)
	b.teil(Stil3D.kugel(0.05, 0.03), _p("pilz_rot"), Vector3(0, 0.2, 0.43), Vector3.ZERO, false)
	b.teil(Stil3D.box(0.03, 0.035, 0.02), _p("weiss"), Vector3(-0.03, 0.255, 0.44), Vector3.ZERO, false)


## Tropfenschleim: zwei große Augen mit besorgten Brauen, offenes Lächeln mit
## Zunge und einem Zahn, gebogener Zipfel als Glied. farbe (k) = Beschwörung
## bzw. bunter Fallback-Schleim, Bläschen dann aus farbe.lightened(0.45).
static func _schleim(pu: Gliederpuppe, k: Dictionary) -> void:
	pu.meta("wippen", 0.0).meta("quetschen", 0.06).meta("drehung", 0.0)
	var c: Color = k["farbe"] if k.get("farbe") != null else _p("schleim")
	var hell: Color = _p("schleim_hell") if k.get("farbe") == null else c.lightened(0.45)
	_schleim_koerper(pu.rumpf, {"farbe": c, "hell": hell, "iris": _glut(k, _p("schwarz"))})
	var z := pu.glied("zipfel", Vector3(0, 0.58, -0.02))
	z.teil(Stil3D.kegel(0.13, 0.26), c, Vector3(0.03, 0.1, 0), Vector3(0, 0, -18))
	z.teil(Stil3D.kugel(0.045), c, Vector3(0.09, 0.22, 0))
	pu.meta("anker_kopf", Vector3(-0.08, 0.62, 0.02)).meta("anker_ruecken", Vector3(0, 0.42, -0.36))
	pu.meta("brust_y", 0.0)


## Eine Lage des Schleimstapels (lokal um ihre Mitte, Gesicht nach +Z):
## gesicht 0 grimmig (böse Brauen, Strichmund), 1 überrascht (O-Mund),
## 2 grinsend (breiter Mund, eigener kleiner Zipfel).
static func _lage(pu: Gliederpuppe, r: float, h: float, c: Color, gesicht: int, iris: Array) -> Bausatz:
	var b := pu.teilsatz()
	b.teil(Stil3D.kugel(r, h), c, Vector3.ZERO)
	b.teil(Stil3D.kugel(r * 0.1), _p("weiss"), Vector3(-r * 0.55, h * 0.26, r * 0.6), Vector3.ZERO, false, 0.3)
	for s: float in [-1.0, 1.0]:
		var ap := Vector3(r * 0.32 * s, h * 0.1, r * 0.82)
		Gliederpuppe.auge(b, ap, r * 0.22, {"seite": s, "iris": iris[0], "iris_leuchten": iris[1]})
		if gesicht == 0:
			Gliederpuppe.braue(b, ap + Vector3(0, r * 0.28, r * 0.08), r * 0.34, s, 24.0)
		elif gesicht == 1:
			Gliederpuppe.braue(b, ap + Vector3(0, r * 0.36, r * 0.04), r * 0.3, s, -18.0)
	match gesicht:
		0:
			b.teil(Stil3D.box(r * 0.4, r * 0.06, r * 0.1), _p("mund"), Vector3(0, -h * 0.17, r * 0.93), Vector3.ZERO, false)
		1:
			b.teil(Stil3D.kugel(r * 0.12, r * 0.18), _p("mund"), Vector3(0, -h * 0.16, r * 0.92), Vector3.ZERO, false)
		2:
			Gliederpuppe.mund(b, Vector3(0, -h * 0.13, r * 0.9), r * 0.6, "grinsen", {"zaehne": 4})
			b.teil(Stil3D.kegel(0.08, 0.16), c, Vector3(-0.02, h * 0.5 + 0.04, -0.02), Vector3(0, 0, 15))
	if gesicht > 0:  # Tropfnase über den Rand der Lage darunter
		b.teil(Stil3D.kegel(0.04, 0.12), c, Vector3(r * 0.55, -h * 0.42, r * 0.5), Vector3(180, 0, 0))
	return b


## Schleimstapel: Wackelturm aus drei Schleimen, jede Lage mit eigenem
## Gesicht; die Mitte hält die Spitze mit zwei Stummelärmchen.
static func _stapel(pu: Gliederpuppe, k: Dictionary) -> void:
	pu.meta("wippen", 0.0).meta("quetschen", 0.05).meta("drehung", 0.0)
	var c := _p("schleim")
	var iris := _glut(k, _p("schwarz"))
	pu.rumpf.teil(Stil3D.zylinder(0.42, 0.46, 0.05), c * 0.8, Vector3(0, 0.025, 0))
	_einfuegen(pu, pu.rumpf, _lage(pu, 0.38, 0.5, c * 0.92, 0, iris), Transform3D(Basis(Vector3.UP, -12.0 * GRAD),
		Vector3(0, 0.25, 0)))
	var g1 := Vector3(0.03, 0.47, 0)
	var l1 := pu.glied("lage1", g1)
	_einfuegen(pu, l1, _lage(pu, 0.3, 0.42, c, 1, iris), Transform3D(Basis(), Vector3(0.03, 0.62, 0) - g1))
	for s: float in [-1.0, 1.0]:  # Stummelärmchen halten die Spitze
		l1.teil(Stil3D.kapsel(0.045, 0.17), c, Vector3(0.25 * s, 0.75, 0.05) - g1, Vector3(0, 0, -55 * s))
	var g2 := Vector3(0.0, 0.8, 0)
	var l2 := pu.glied("lage2", g2, Vector3.ZERO, "lage1")
	_einfuegen(pu, l2, _lage(pu, 0.23, 0.34, c * 1.08, 2, iris), Transform3D(Basis(Vector3.UP, 12.0 * GRAD),
		Vector3(-0.02, 0.93, 0) - g2))
	pu.meta("anker_kopf", Vector3(-0.02, 0.93 + 0.22, 0) - g2).meta("anker_kopf_glied", "lage2")
	pu.meta("anker_ruecken", Vector3(0, 0.62, -0.3)).meta("brust_y", 0.0)


## König-Schleim (DQ-Hommage): blau mit Kristall-Glanz, schwere Lider,
## Schnurrbart, Hermelin-Umhang als Sockel, Krone und Zepter als Glieder.
## Boss: Großkrone (sieben Zacken, roter Mittelstein) statt Zusatzkrone.
static func _koenig(pu: Gliederpuppe, k: Dictionary) -> void:
	pu.meta("wippen", 0.0).meta("quetschen", 0.05).meta("drehung", 0.0).meta("hat_krone", true)
	var c := _p("ruestung")
	var b := pu.rumpf
	b.teil(Stil3D.zylinder(0.53, 0.55, 0.05), _p("weiss"), Vector3(0, 0.025, 0))  # Hermelin-Saum
	for i in 10:
		var w := deg_to_rad(i * 36.0)
		b.teil(Stil3D.kugel(0.024), _p("schwarz"), Vector3(sin(w) * 0.545, 0.03, cos(w) * 0.545), Vector3.ZERO, false)
	b.teil(Stil3D.zylinder(0.47, 0.51, 0.1), _p("umhang"), Vector3(0, 0.09, 0))  # Umhang
	_schleim_koerper(b, {"farbe": c, "hell": _p("kristall"), "pfuetze": false, "brauen": 0.0,
		"iris": _glut(k, _p("schwarz"))})
	for s: float in [-1.0, 1.0]:
		b.teil(Stil3D.kugel(0.105, 0.075), c * 0.85, Vector3(0.13 * s, 0.445, 0.355), Vector3(-12, 0, 0))  # Lider
		b.teil(Stil3D.kapsel(0.03, 0.17), _p("schwarz") * 1.5, Vector3(0.085 * s, 0.29, 0.415), Vector3(0, 0, 72 * s))
		b.teil(Stil3D.kugel(0.032), _p("schwarz") * 1.5, Vector3(0.17 * s, 0.315, 0.39))
	var kr := pu.glied("krone", Vector3(0, 0.6, -0.02))
	if k.get("boss", false):
		Gliederpuppe.krone(kr, Transform3D(Basis.from_euler(Vector3(0, 0, -6) * GRAD), Vector3(0, -0.03, 0)), 0.16, 7,
			_p("gold"), _p("drachenblut"), 0.3, _p("umhang"))
	else:
		kr.teil(Stil3D.zylinder(0.15, 0.14, 0.12), _p("gold"), Vector3.ZERO)
		for i in 5:
			var w := deg_to_rad(i * 72.0)
			kr.teil(Stil3D.kegel(0.04, 0.12), _p("gold"), Vector3(sin(w) * 0.12, 0.11, cos(w) * 0.12))
		kr.teil(Stil3D.kugel(0.035), _p("umhang"), Vector3(0, 0.0, 0.15), Vector3.ZERO, false, 0.3)
	var zg := Vector3(0.36, 0.3, 0.1)
	var z := pu.glied("zepter", zg)
	z.teil(Stil3D.kapsel(0.06, 0.18), c, Vector3(0.05, 0.03, 0), Vector3(0, 0, -50))
	z.teil(Stil3D.zylinder(0.018, 0.018, 0.42), _p("gold"), Vector3(0.12, 0.17, 0.02))
	z.teil(Stil3D.kugel(0.05), _p("kristall"), Vector3(0.12, 0.4, 0.02), Vector3.ZERO, true, 0.6)
	pu.meta("anker_kopf", Vector3(0, 0.62, 0.04)).meta("anker_ruecken", Vector3(0, 0.42, -0.36)).meta("brust_y", 0.0)


## Gottschleim (nur Boss): golden, Glanz und Bläschen in Glut, Stirnauge
## (Dreigestirn), Heiligenschein knapp über dem Scheitel (geneigt), Orbit mit
## vier Trabanten-Schleimen. Die Glutscheibe mit Runen liegt als Bodenteil
## (gegner()), der Schein ersetzt die Krone.
static func _gott(pu: Gliederpuppe, k: Dictionary) -> void:
	pu.meta("wippen", 0.04).meta("quetschen", 0.04).meta("schwebt", 0.05).meta("drehung", 0.0)
	pu.meta("hat_krone", true).meta("hoerner", true)
	var b := pu.rumpf
	var iris := _glut(k, _p("schwarz"))
	_schleim_koerper(b, {"farbe": _p("gold"), "hell": _p("glut"), "glanz": _p("glut").lightened(0.45), "pfuetze": false,
		"brauen": 18.0, "iris": iris})
	Gliederpuppe.auge(b, Vector3(0, 0.555, 0.27), 0.065, {"iris": _p("kristall"), "iris_leuchten": 0.9})
	var schein := pu.glied("schein", Vector3(0, 0.74, -0.08), Vector3(-15, 0, 0))
	var tor := TorusMesh.new()
	tor.inner_radius = 0.2
	tor.outer_radius = 0.25
	tor.rings = 32
	tor.ring_segments = 8
	schein.teil(tor, _p("glut"), Vector3.ZERO, Vector3.ZERO, false, 0.7)
	var orbit := pu.glied("orbit", Vector3(0, 0.42, 0))
	var farben := [_p("schleim"), _p("lila"), _p("ruestung"), _p("moos")]
	for i in 4:
		var w := deg_to_rad(i * 90.0 + 45.0)
		var pos := Vector3(sin(w) * 0.62, 0.0, cos(w) * 0.62)
		orbit.teil(Stil3D.kugel(0.09, 0.12), farben[i], pos)
		orbit.teil(Stil3D.kugel(0.018), _p("weiss"), pos + Vector3(-0.04, 0.035, 0.05), Vector3.ZERO, false, 0.3)
		var aussen := pos.normalized()
		var quer := Vector3.UP.cross(aussen)
		for s: float in [-1.0, 1.0]:
			orbit.teil(Stil3D.kugel(0.017), _p("schwarz"), pos + aussen * 0.085 + quer * 0.03 * s + Vector3(0, 0.015, 0),
				Vector3.ZERO, false)
	pu.meta("anker_kopf", Vector3(0, 0.66, 0.0)).meta("anker_ruecken", Vector3(0, 0.42, -0.36)).meta("brust_y", 0.0)
