class_name GegenstandIcons
extends RefCounted
## 3D-Icons für Ausrüstung (Inventar-Raster, Slots) im STIL-3D-Look: je
## Basis-Item eine kleine Figur aus Grundkörpern, die PortraitStudio einmal
## in eine Textur rendert. Die Rarität zeigt der Rahmen in der UI, nicht das
## Icon — so reicht ein Icon pro Basis.
##
## Icon-Pass (Befund I1–I13): ähnliche Items unterscheiden sich über die
## SILHOUETTE, nicht über die Größe (PortraitStudio rahmt jedes Icon auf
## seine Ausdehnung im Kamerablick ein, Meta "icon_rand"): Zweihandschwert
## mit langem Griff, breiter Parierstange und Parierhaken, Dolch mit
## Blattklinge und kleinerem Maßstab; Zweihandaxt mit Doppelblatt wie die
## Figur; Stäbe mit großem Kopf nach den Figurenstäben (Kristallgabel bzw.
## Goldring mit Perlen). Waffen liegen diagonal (−40…−45°), flache Teile
## (Schild, Buch, Rüstung, Helm) leicht gedreht. Griffe in etwas dunklerem
## Holz (HOLZ) — auf Selten/Legendär-Glanz trägt sonst nur die Kontur.


static func schluessel(base: ItemBase) -> String:
	return "item|%s" % base.id


static func textur(studio: PortraitStudio, base: ItemBase) -> Texture2D:
	return studio.textur(schluessel(base), func() -> Node3D: return bauen(base))


static func _p(name: String) -> Color:
	return Stil3D.farbe(name)


## Griff-/Schaftholz: etwas dunkler und röter als "holz" (Kontrast auf dem
## warmen Glanz der Selten-/Legendär-Kacheln).
static func _holz() -> Color:
	return _p("holz").darkened(0.18)


static func bauen(base: ItemBase) -> Node3D:
	var n := Node3D.new()
	var rand := PortraitStudio.ICON_RAND
	match base.id:
		&"schwert": _schwert(n, 0.66, 0.12, 0.2, 0.38, false)
		&"zweihandschwert": _schwert(n, 0.8, 0.16, 0.44, 0.58, true)
		&"dolch":
			_dolch(n)
			rand *= 1.16  # kurze Waffe: sichtbar kleiner in der Kachel
		&"axt": _axt(n, false)
		&"zweihandaxt": _axt(n, true)
		&"knueppel": _knueppel(n)
		&"kriegshammer": _hammer(n)
		&"bogen": _bogen(n)
		&"armbrust": _armbrust(n)
		&"offensivstab": _kristallstab(n)
		&"heiligstab": _ringstab(n)
		&"schild": _schild_rund(n)
		&"turmschild": _turmschild(n)
		&"zauberbuch": _buch(n)
		&"kristallfokus": _fokus(n)
		&"relikt": _relikt(n)
		&"heiligkreuz": _kreuz(n)
		&"koecher": _koecher(n)
		&"ruestung_leicht": _ruestung(n, 0)
		&"ruestung_mittel": _ruestung(n, 1)
		&"ruestung_schwer": _ruestung(n, 2)
		&"robe_schaden": _robe(n, _p("robe_lila").lightened(0.12), _p("gold"))
		&"robe_heil": _robe(n, _p("weiss"), _p("gold"))
		&"robe_kampf": _robe(n, _p("ruestung"), _p("leder"))
		&"helm_leicht": _helm_leicht(n)
		&"helm_schwer": _helm_schwer(n)
		&"handschuhe_leicht": _handschuh(n, _p("leder"), false)
		&"handschuhe_schwer": _handschuh(n, _p("silber"), true)
		&"stiefel_leicht": _stiefel(n, _p("leder"), false)
		&"stiefel_schwer": _stiefel(n, _p("silber"), true)
		&"ring": _ring(n)
		&"amulett": _amulett(n)
		_:
			Stil3D.teil(n, Stil3D.box(0.5, 0.5, 0.5), _p("eisen"), Vector3(0, 0.3, 0))
	n.set_meta("icon_rand", rand)
	return n


# --- Hilfen ------------------------------------------------------------------

## Drehgelenk (Grad) unter n: Waffen kippen diagonal, Flaches dreht sich.
static func _gelenk(n: Node3D, rot_grad: Vector3, pos := Vector3.ZERO) -> Node3D:
	var k := Node3D.new()
	k.rotation_degrees = rot_grad
	k.position = pos
	n.add_child(k)
	return k


static func _gekippt(n: Node3D, winkel: float) -> Node3D:
	return _gelenk(n, Vector3(0, 0, winkel))


## Kapsel von a nach z (Bogenarme, Gabeln, Krallen, Sehnen).
static func _strebe(k: Node3D, a: Vector3, z: Vector3, r: float, farbe: Color, kontur := true,
		leuchten := Color.BLACK) -> void:
	var d := z - a
	var mi := Stil3D.teil(k, Stil3D.kapsel(r, d.length() + r * 2.0, 12), farbe, (a + z) * 0.5,
		Vector3.ZERO, kontur, leuchten)
	var y := d.normalized()
	var x := Vector3.BACK.cross(y)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT
	x = x.normalized()
	mi.basis = Basis(x, y, x.cross(y))


static func _ringmesh(innen: float, aussen: float, ringe := 32, seiten := 8) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = innen
	t.outer_radius = aussen
	t.rings = ringe
	t.ring_segments = seiten
	return t


static func _halbkugel(r: float, hoehe: float) -> SphereMesh:
	var m := Stil3D.kugel(r, hoehe)
	m.is_hemisphere = true
	return m


# --- Klingen -------------------------------------------------------------------

## Schwert wie ZweibeinerBau._schwert (weiße/silberne Klinge mit Grat,
## Gold-Parier mit Kugelenden, Ledergriff, Knauf). Zweihänder: langer
## Griff mit Goldringen, breite Parierstange, lederumwickelte Fehlschärfe
## mit Parierhaken — zweites dunkles Band auf der Klinge, auch bei 58 px.
static func _schwert(n: Node3D, l: float, b: float, griff: float, parier: float, zweihand: bool) -> void:
	var k := _gekippt(n, -40.0 if zweihand else -45.0)
	var gold := _p("gold")
	Stil3D.teil(k, Stil3D.zylinder(0.045, 0.05, griff), _p("leder"), Vector3(0, -griff * 0.5, 0))
	Stil3D.teil(k, Stil3D.kugel(0.08 if zweihand else 0.065), gold, Vector3(0, -griff - 0.04, 0))
	if zweihand:
		for y in [-0.15, -0.3]:
			Stil3D.teil(k, Stil3D.zylinder(0.06, 0.06, 0.045), gold, Vector3(0, y, 0), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.box(parier, 0.07, 0.1), gold, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		Stil3D.teil(k, Stil3D.kugel(0.055 if zweihand else 0.045), gold, Vector3(parier * 0.5 * s, 0, 0))
	var klinge := _p("silber")
	var fuss := 0.035
	if zweihand:  # Fehlschärfe mit Lederwicklung und Parierhaken
		Stil3D.teil(k, Stil3D.box(b * 0.8, 0.2, 0.07), _p("leder"), Vector3(0, fuss + 0.1, 0))
		for s in [-1.0, 1.0]:
			Stil3D.teil(k, Stil3D.prisma(0.13, 0.1, 0.05), gold, Vector3((b * 0.5 + 0.045) * s, fuss + 0.22, 0),
				Vector3(0, 0, -90.0 * s))
	Stil3D.teil(k, Stil3D.box(b, l, 0.045), klinge, Vector3(0, fuss + l * 0.5, 0))
	Stil3D.teil(k, Stil3D.prisma(b, b * 1.3, 0.045), klinge, Vector3(0, fuss + l + b * 0.65, 0))
	Stil3D.teil(k, Stil3D.box(b * 0.22, l * 0.88, 0.06), _p("eisen") * 1.15, Vector3(0, fuss + l * 0.47, 0),
		Vector3.ZERO, false)


## Dolch wie ZweibeinerBau._dolch: kurze breite Blattklinge, Messing-Parier.
static func _dolch(n: Node3D) -> void:
	var k := _gekippt(n, -50.0)
	Stil3D.teil(k, Stil3D.zylinder(0.045, 0.05, 0.17), _p("leder"), Vector3(0, -0.085, 0))
	Stil3D.teil(k, Stil3D.kugel(0.06), _p("messing"), Vector3(0, -0.2, 0))
	Stil3D.teil(k, Stil3D.box(0.24, 0.065, 0.09), _p("messing"), Vector3.ZERO)
	var klinge := _p("silber")
	Stil3D.teil(k, Stil3D.box(0.14, 0.2, 0.045), klinge, Vector3(0, 0.13, 0))
	Stil3D.teil(k, Stil3D.prisma(0.14, 0.26, 0.045), klinge, Vector3(0, 0.36, 0))
	Stil3D.teil(k, Stil3D.box(0.028, 0.34, 0.06), _p("eisen") * 1.15, Vector3(0, 0.2, 0), Vector3.ZERO, false)


## Axt wie ZweibeinerBau._axt: Eisenblatt mit heller Schneide, Dorn hinten;
## Zweihandaxt mit DOPPELblatt, längerem Stiel und Spitze oben.
static func _axt(n: Node3D, gross: bool) -> void:
	var k := _gekippt(n, -40.0)
	var l := 1.15 if gross else 0.95
	var f := 1.18 if gross else 1.0
	var kopf := l - 0.2
	Stil3D.teil(k, Stil3D.zylinder(0.045, 0.05, l), _holz(), Vector3(0, l * 0.5, 0))
	Stil3D.teil(k, Stil3D.zylinder(0.055, 0.055, 0.16), _p("leder"), Vector3(0, 0.12, 0), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.box(0.13, 0.26 * f, 0.12), _p("eisen") * 0.9, Vector3(0, kopf, 0))
	var seiten := [1.0, -1.0] if gross else [1.0]
	for s in seiten:
		Stil3D.teil(k, Stil3D.prisma(0.46 * f, 0.34 * f, 0.07), _p("eisen"), Vector3(0.21 * f * s, kopf, 0),
			Vector3(0, 0, 90.0 * s))
		Stil3D.teil(k, Stil3D.box(0.04, 0.46 * f, 0.085), _p("eisen") * 1.45, Vector3(0.38 * f * s, kopf, 0),
			Vector3.ZERO, false)
	if gross:
		Stil3D.teil(k, Stil3D.kegel(0.05, 0.18), _p("eisen") * 0.9, Vector3(0, l + 0.08, 0))
	else:
		Stil3D.teil(k, Stil3D.kegel(0.05, 0.17), _p("eisen") * 0.9, Vector3(-0.14, kopf, 0), Vector3(0, 0, 90))


## Knüppel wie ZweibeinerBau._keule: dicker Holzkolben, Eisenband, Nieten.
static func _knueppel(n: Node3D) -> void:
	var k := _gekippt(n, -40.0)
	Stil3D.teil(k, Stil3D.zylinder(0.17, 0.065, 0.95), _holz(), Vector3(0, 0.475, 0))
	Stil3D.teil(k, Stil3D.zylinder(0.07, 0.07, 0.2), _p("leder"), Vector3(0, 0.12, 0), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.zylinder(0.165, 0.16, 0.08), _p("eisen"), Vector3(0, 0.74, 0))
	for i in 5:
		var w := TAU * i / 5.0 + 0.3
		Stil3D.teil(k, Stil3D.kegel(0.05, 0.11), _p("eisen") * 1.2, Vector3(sin(w) * 0.17, 0.86, cos(w) * 0.17),
			Vector3(rad_to_deg(cos(w)) * 1.5, 0, -rad_to_deg(sin(w)) * 1.5))
	Stil3D.teil(k, Stil3D.kugel(0.17, 0.12), _holz(), Vector3(0, 0.95, 0))


## Kriegshammer wie ZweibeinerBau._keule(hammer): Eisenkopf mit hellem
## Band und runden Schlagflächen.
static func _hammer(n: Node3D) -> void:
	var k := _gekippt(n, -40.0)
	Stil3D.teil(k, Stil3D.zylinder(0.045, 0.05, 1.08), _holz(), Vector3(0, 0.54, 0))
	Stil3D.teil(k, Stil3D.zylinder(0.056, 0.056, 0.2), _p("leder"), Vector3(0, 0.12, 0), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.box(0.54, 0.28, 0.28), _p("eisen"), Vector3(0, 1.0, 0))
	Stil3D.teil(k, Stil3D.box(0.56, 0.06, 0.3), _p("eisen") * 1.35, Vector3(0, 1.0, 0), Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		Stil3D.teil(k, Stil3D.zylinder(0.15, 0.15, 0.06), _p("eisen") * 0.8, Vector3(0.29 * s, 1.0, 0),
			Vector3(0, 0, 90))


# --- Fernkampf -------------------------------------------------------------------

## Reflexbogen wie ZweibeinerBau._bogen: geschwungene Arme mit nach vorn
## gebogenen Spitzen, Griffwicklung, gut sichtbare Sehne.
static func _bogen(n: Node3D) -> void:
	var k := _gekippt(n, -40.0)
	var holz := _p("holz_hell").darkened(0.12)
	for s in [-1.0, 1.0]:
		var p0 := Vector3(0, 0.14 * s, 0)
		var p1 := Vector3(-0.11, 0.44 * s, 0)
		var p2 := Vector3(-0.22, 0.64 * s, 0)
		var p3 := Vector3(-0.17, 0.77 * s, 0)
		_strebe(k, p0, p1, 0.058, holz)
		_strebe(k, p1, p2, 0.05, holz)
		_strebe(k, p2, p3, 0.04, holz)
	Stil3D.teil(k, Stil3D.zylinder(0.072, 0.072, 0.3), _p("leder"), Vector3.ZERO)
	_strebe(k, Vector3(-0.215, 0.66, 0), Vector3(-0.215, -0.66, 0), 0.02, _p("weiss"), false)


## Armbrust wie ZweibeinerBau._armbrust: Schaft schräg, Querbogen aus Eisen
## mit weißer Sehne zur Nuss, Bolzen in der Schiene, Abzug unten.
static func _armbrust(n: Node3D) -> void:
	var k := _gekippt(n, -40.0)
	Stil3D.teil(k, Stil3D.box(0.13, 0.86, 0.1), _holz(), Vector3(0, -0.08, 0))
	Stil3D.teil(k, Stil3D.box(0.18, 0.26, 0.12), _holz(), Vector3(0, -0.5, 0))
	Stil3D.teil(k, Stil3D.box(0.04, 0.12, 0.05), _p("eisen"), Vector3(0.09, -0.26, 0))
	var bogen := _p("eisen")
	for s in [-1.0, 1.0]:
		_strebe(k, Vector3(0, 0.3, 0.02), Vector3(0.3 * s, 0.24, 0.02), 0.045, bogen)
		_strebe(k, Vector3(0.3 * s, 0.24, 0.02), Vector3(0.5 * s, 0.12, 0.02), 0.038, bogen)
		_strebe(k, Vector3(0.5 * s, 0.12, 0.04), Vector3(0, -0.06, 0.07), 0.014, _p("weiss"), false)
	Stil3D.teil(k, Stil3D.box(0.05, 0.66, 0.05), _p("eisen") * 1.25, Vector3(0, 0.17, 0.07), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.prisma(0.09, 0.12, 0.05), _p("silber"), Vector3(0, 0.56, 0.07))
	Stil3D.teil(k, Stil3D.box(0.12, 0.06, 0.06), _p("messing"), Vector3(0, 0.3, 0.06), Vector3.ZERO, false)


# --- Stäbe -----------------------------------------------------------------------

## Offensivstab wie ZweibeinerBau._kristallstab: Holzgabel, die ein
## leuchtendes Doppelprisma hält; Kopf groß im Verhältnis zum Schaft.
static func _kristallstab(n: Node3D) -> void:
	var k := _gekippt(n, -35.0)
	var holz := _holz()
	Stil3D.teil(k, Stil3D.zylinder(0.05, 0.058, 1.0), holz, Vector3(0, 0.5, 0))
	for y in [0.26, 0.84]:
		Stil3D.teil(k, Stil3D.zylinder(0.064, 0.064, 0.05), _p("gold"), Vector3(0, y, 0), Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		_strebe(k, Vector3(0, 0.98, 0), Vector3(0.2 * s, 1.2, 0), 0.045, holz)
		_strebe(k, Vector3(0.2 * s, 1.2, 0), Vector3(0.11 * s, 1.47, 0), 0.038, holz)
	var licht := _p("kristall")
	Stil3D.teil(k, Stil3D.prisma(0.28, 0.34, 0.2), licht, Vector3(0, 1.43, 0), Vector3(0, 30, 0), true,
		licht * 0.55)
	Stil3D.teil(k, Stil3D.prisma(0.28, 0.22, 0.2), licht, Vector3(0, 1.15, 0), Vector3(180, -30, 0), true,
		licht * 0.55)


## Heiligstab wie ZweibeinerBau._ringstab: helles Holz, Goldring mit acht
## Perlen um eine leuchtende Kugel.
static func _ringstab(n: Node3D) -> void:
	var k := _gekippt(n, -35.0)
	var gold := _p("gold")
	Stil3D.teil(k, Stil3D.zylinder(0.05, 0.058, 1.0), _p("holz_hell").darkened(0.1), Vector3(0, 0.5, 0))
	Stil3D.teil(k, Stil3D.zylinder(0.066, 0.066, 0.06), gold, Vector3(0, 1.0, 0), Vector3.ZERO, false)
	var mitte := Vector3(0, 1.31, 0)
	Stil3D.teil(k, _ringmesh(0.23, 0.29), gold, mitte, Vector3(90, 0, 0))
	for i in 8:
		var w := TAU * i / 8.0
		Stil3D.teil(k, Stil3D.kugel(0.07, -1, 12), gold, mitte + Vector3(sin(w) * 0.26, cos(w) * 0.26, 0.01))
	Stil3D.teil(k, Stil3D.kugel(0.13), gold.lightened(0.2), mitte, Vector3.ZERO, true, _p("glut") * 0.6)


# --- Schilde und Nebenhand -------------------------------------------------------

## Rundschild wie ZweibeinerBau._schild_rund: Holzscheibe mit Messingring,
## Diagonal-Wappen und Goldbuckel, leicht gedreht (Dicke sichtbar).
static func _schild_rund(n: Node3D) -> void:
	var k := _gelenk(n, Vector3(0, -28, 0))
	Stil3D.teil(k, Stil3D.zylinder(0.5, 0.5, 0.08, 28), _p("braun"), Vector3.ZERO, Vector3(90, 0, 0))
	Stil3D.teil(k, _ringmesh(0.45, 0.54, 40, 8), _p("messing"), Vector3(0, 0, 0.02), Vector3(90, 0, 0))
	Stil3D.teil(k, Stil3D.box(0.17, 0.88, 0.02), _p("umhang"), Vector3(0, 0, 0.045), Vector3(0, 0, 40), false)
	Stil3D.teil(k, Stil3D.kugel(0.14, 0.12), _p("gold"), Vector3(0, 0, 0.05))


## Turmschild wie ZweibeinerBau._turmschild: Fläche mit Messingrand,
## Goldkreuz und Nieten, leicht gedreht.
static func _turmschild(n: Node3D) -> void:
	var k := _gelenk(n, Vector3(0, -24, 0))
	Stil3D.teil(k, Stil3D.box(0.66, 1.0, 0.08), _p("ruestung_dunkel"), Vector3.ZERO)
	Stil3D.teil(k, Stil3D.box(0.74, 1.08, 0.05), _p("messing"), Vector3(0, 0, -0.03))
	Stil3D.teil(k, Stil3D.box(0.1, 0.74, 0.03), _p("gold"), Vector3(0, -0.02, 0.05), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.box(0.46, 0.1, 0.03), _p("gold"), Vector3(0, 0.14, 0.05), Vector3.ZERO, false)
	for x in [-0.27, 0.27]:
		for y in [-0.43, 0.43]:
			Stil3D.teil(k, Stil3D.kugel(0.04, -1, 10), _p("messing_hell"), Vector3(x, y, 0.045), Vector3.ZERO, false)


## Zauberbuch: dicker Band schräg — Rücken, heller Seitenschnitt,
## Goldecken und leuchtender Stein auf dem Deckel.
static func _buch(n: Node3D) -> void:
	var k := _gelenk(n, Vector3(8, -32, 0))
	var deckel := _p("daemon_dunkel")
	for z in [-0.13, 0.13]:
		Stil3D.teil(k, Stil3D.box(0.58, 0.76, 0.05), deckel, Vector3(0, 0, z))
	Stil3D.teil(k, Stil3D.box(0.53, 0.7, 0.22), _p("knochen"), Vector3(0.02, 0, 0))
	Stil3D.teil(k, Stil3D.zylinder(0.15, 0.15, 0.76, 16), deckel, Vector3(-0.27, 0, 0))
	for y in [-0.24, 0.24]:
		Stil3D.teil(k, Stil3D.zylinder(0.16, 0.16, 0.05, 16), _p("gold"), Vector3(-0.27, y, 0), Vector3.ZERO, false)
	for x in [-0.2, 0.22]:
		for y in [-0.31, 0.31]:
			Stil3D.teil(k, Stil3D.box(0.12, 0.12, 0.02), _p("gold"), Vector3(x + 0.02 * signf(x), y, 0.16),
				Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.zylinder(0.12, 0.12, 0.03, 16), _p("gold"), Vector3(0.02, 0, 0.165), Vector3(90, 0, 0))
	Stil3D.teil(k, Stil3D.kugel(0.085), _p("kristall"), Vector3(0.02, 0, 0.19), Vector3.ZERO, true,
		_p("kristall") * 0.6)


## Kristallfokus wie die Figur: leuchtende Kugel in einer Goldkralle auf
## kurzem Griff.
static func _fokus(n: Node3D) -> void:
	var k := _gekippt(n, -12.0)
	Stil3D.teil(k, Stil3D.zylinder(0.055, 0.065, 0.34), _holz(), Vector3(0, 0.17, 0))
	Stil3D.teil(k, Stil3D.zylinder(0.17, 0.07, 0.14), _p("gold"), Vector3(0, 0.38, 0))
	var licht := _p("kristall")
	Stil3D.teil(k, Stil3D.kugel(0.25), licht, Vector3(0, 0.66, 0), Vector3.ZERO, true, licht * 0.45)
	for i in 3:
		var w := TAU * i / 3.0 + 0.5
		var aussen := Vector3(sin(w) * 0.24, 0.6, cos(w) * 0.24)
		_strebe(k, Vector3(sin(w) * 0.15, 0.44, cos(w) * 0.15), aussen, 0.035, _p("gold"))
		_strebe(k, aussen, Vector3(sin(w) * 0.17, 0.8, cos(w) * 0.17), 0.03, _p("gold"))
	Stil3D.teil(k, Stil3D.kugel(0.055, -1, 10), _p("weiss"), Vector3(-0.08, 0.76, 0.18), Vector3.ZERO, false,
		_p("weiss") * 0.5)


## Relikt: Reliquiar — Messingschrein mit Giebeldach, rot leuchtendem
## Fenster und Kreuz auf dem First.
static func _relikt(n: Node3D) -> void:
	var k := _gelenk(n, Vector3(0, -30, 0))
	Stil3D.teil(k, Stil3D.box(0.68, 0.1, 0.44), _p("messing_dunkel"), Vector3(0, 0.05, 0))
	Stil3D.teil(k, Stil3D.box(0.54, 0.36, 0.34), _p("messing"), Vector3(0, 0.28, 0))
	Stil3D.teil(k, Stil3D.box(0.22, 0.22, 0.02), _p("daemon"), Vector3(0, 0.28, 0.175), Vector3.ZERO, false,
		_p("daemon") * 0.7)
	Stil3D.teil(k, Stil3D.box(0.3, 0.04, 0.03), _p("gold"), Vector3(0, 0.41, 0.175), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.box(0.3, 0.04, 0.03), _p("gold"), Vector3(0, 0.15, 0.175), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.prisma(0.64, 0.24, 0.42), _p("gold"), Vector3(0, 0.58, 0))
	Stil3D.teil(k, Stil3D.box(0.06, 0.24, 0.06), _p("gold"), Vector3(0, 0.82, 0))
	Stil3D.teil(k, Stil3D.box(0.16, 0.06, 0.06), _p("gold"), Vector3(0, 0.86, 0))


## Heiliges Kreuz (gold, leicht leuchtend) mit Stein in der Mitte.
static func _kreuz(n: Node3D) -> void:
	var k := _gelenk(n, Vector3(0, -22, 0))
	var glanz := _p("glut") * 0.2
	Stil3D.teil(k, Stil3D.box(0.15, 0.9, 0.1), _p("gold"), Vector3(0, 0.45, 0), Vector3.ZERO, true, glanz)
	Stil3D.teil(k, Stil3D.box(0.58, 0.15, 0.1), _p("gold"), Vector3(0, 0.62, 0), Vector3.ZERO, true, glanz)
	Stil3D.teil(k, Stil3D.kugel(0.075), _p("umhang"), Vector3(0, 0.62, 0.06), Vector3.ZERO, true, _p("umhang") * 0.4)


## Köcher wie ZweibeinerBau._koecher: Lederröhre, Messingbänder, Pfeile.
static func _koecher(n: Node3D) -> void:
	var k := _gekippt(n, -18.0)
	Stil3D.teil(k, Stil3D.zylinder(0.17, 0.14, 0.78), _p("leder"), Vector3(0, 0.39, 0))
	for y in [0.16, 0.66]:
		Stil3D.teil(k, Stil3D.zylinder(0.178, 0.17, 0.05), _p("messing"), Vector3(0, y, 0), Vector3.ZERO, false)
	for i in 3:
		var x := -0.08 + i * 0.08
		Stil3D.teil(k, Stil3D.zylinder(0.017, 0.017, 0.3), _holz(), Vector3(x, 0.9, 0.02))
		Stil3D.teil(k, Stil3D.prisma(0.11, 0.17, 0.02), _p("weiss"), Vector3(x, 1.07, 0.02), Vector3(0, 20 - i * 20, 0))


# --- Rüstungen -----------------------------------------------------------------------

## Brustpanzer mit Halsausschnitt, Taille, Schulterstücken und Gürtel.
## art 0 = Leder (braun, Nähte, Schnallen), 1 = Kette (dunkles Eisen mit
## Ringraster, Lederkragen), 2 = Platte (hell, Brustgrat, große
## Schulterplatten, Goldkanten).
static func _ruestung(n: Node3D, art: int) -> void:
	var k := _gelenk(n, Vector3(0, -22, 0))
	var farbe: Color = [_p("leder"), _p("eisen"), _p("silber")][art]
	var schulter := [0.15, 0.17, 0.22][art] as float
	Stil3D.teil(k, Stil3D.box(0.66, 0.44, 0.34), farbe, Vector3(0, 0.66, 0))
	Stil3D.teil(k, Stil3D.box(0.54, 0.32, 0.3), farbe * 0.9, Vector3(0, 0.34, 0))
	for s in [-1.0, 1.0]:
		Stil3D.teil(k, Stil3D.kugel(schulter), farbe * 0.95, Vector3(0.36 * s, 0.84, 0))
	# Halsausschnitt (dunkles V vorn oben).
	if art == 2:
		Stil3D.teil(k, Stil3D.prisma(0.34, 0.25, 0.02), _p("gold"), Vector3(0, 0.765, 0.172), Vector3(180, 0, 0), false)
	Stil3D.teil(k, Stil3D.prisma(0.26, 0.2, 0.02), _p("schatten"), Vector3(0, 0.79, 0.178), Vector3(180, 0, 0), false)
	var guertel: Color = [_p("braun"), _p("leder"), _p("gold")][art]
	Stil3D.teil(k, Stil3D.box(0.56, 0.08, 0.32), guertel, Vector3(0, 0.22, 0))
	Stil3D.teil(k, Stil3D.box(0.1, 0.1, 0.03), _p("messing_hell"), Vector3(0, 0.22, 0.16), Vector3.ZERO, false)
	match art:
		0:  # Leder: Nähte und Schulterschnallen
			for x in [-0.17, 0.17]:
				Stil3D.teil(k, Stil3D.box(0.025, 0.36, 0.01), _p("braun_hell"), Vector3(x, 0.62, 0.172),
					Vector3.ZERO, false)
			for x in [-0.22, 0.22]:
				Stil3D.teil(k, Stil3D.box(0.08, 0.14, 0.36), _p("braun"), Vector3(x, 0.84, 0), Vector3.ZERO, false)
				Stil3D.teil(k, Stil3D.box(0.07, 0.06, 0.02), _p("messing_hell"), Vector3(x, 0.82, 0.18),
					Vector3.ZERO, false)
		1:  # Kette: Ringraster, Lederkragen
			var ring := _ringmesh(0.026, 0.05, 12, 4)
			for reihe in 3:
				var y := 0.5 + reihe * 0.12
				var anzahl := 5 if reihe > 0 else 4
				for i in anzahl:
					var x := (i - (anzahl - 1) * 0.5) * 0.12 + (0.0 if reihe != 1 else 0.0)
					Stil3D.teil(k, ring, _p("silber"), Vector3(x, y, 0.172), Vector3(90, 0, 0), false)
			for i in 4:
				Stil3D.teil(k, ring, _p("silber") * 0.9, Vector3((i - 1.5) * 0.12, 0.33, 0.152), Vector3(90, 0, 0), false)
			Stil3D.teil(k, Stil3D.box(0.4, 0.07, 0.3), _p("leder"), Vector3(0, 0.9, 0))
		2:  # Platte: Brustgrat, Bauchreifen, Goldkante
			Stil3D.teil(k, Stil3D.box(0.06, 0.34, 0.05), _p("weiss"), Vector3(0, 0.6, 0.17))
			Stil3D.teil(k, Stil3D.box(0.68, 0.04, 0.36), _p("gold"), Vector3(0, 0.45, 0), Vector3.ZERO, false)
			Stil3D.teil(k, Stil3D.box(0.56, 0.04, 0.32), _p("eisen") * 1.3, Vector3(0, 0.34, 0), Vector3.ZERO, false)
			for s in [-1.0, 1.0]:
				Stil3D.teil(k, Stil3D.zylinder(0.2, 0.24, 0.05), _p("gold"), Vector3(0.36 * s, 0.76, 0), Vector3.ZERO,
					false)


## Robe: ausgestellter Rock, Schulterpartie, Kapuze hinten, Trompeten-Ärmel
## (wie die Figuren), Saum, Gürtel und Mittelband in der Saumfarbe.
static func _robe(n: Node3D, farbe: Color, saum: Color) -> void:
	var k := _gelenk(n, Vector3(0, -18, 0))
	Stil3D.teil(k, Stil3D.zylinder(0.2, 0.42, 0.86), farbe, Vector3(0, 0.43, 0))
	Stil3D.teil(k, Stil3D.kugel(0.25, 0.32), farbe, Vector3(0, 0.86, 0))
	Stil3D.teil(k, Stil3D.kugel(0.18), farbe * 0.8, Vector3(0, 0.98, -0.1))
	for s in [-1.0, 1.0]:
		Stil3D.teil(k, Stil3D.zylinder(0.07, 0.13, 0.42), farbe, Vector3(0.29 * s, 0.68, 0.02), Vector3(0, 0, 24 * s))
		Stil3D.teil(k, Stil3D.zylinder(0.135, 0.135, 0.04), saum, Vector3(0.375 * s, 0.49, 0.02), Vector3(0, 0, 24 * s),
			false)
	Stil3D.teil(k, Stil3D.zylinder(0.43, 0.43, 0.05), saum, Vector3(0, 0.03, 0), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.zylinder(0.305, 0.305, 0.06), saum, Vector3(0, 0.48, 0), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.box(0.08, 0.84, 0.02), saum, Vector3(0, 0.44, 0.315), Vector3(-14.5, 0, 0), false)


# --- Kopf, Hände, Füße, Schmuck ---------------------------------------------------

## Leichter Helm: Lederkappe mit Randband, Wangenklappen, Nackenschutz.
static func _helm_leicht(n: Node3D) -> void:
	var k := _gelenk(n, Vector3(0, -40, 0))
	var leder := _p("leder")
	Stil3D.teil(k, _halbkugel(0.34, 0.36), leder, Vector3(0, 0.2, 0))
	Stil3D.teil(k, Stil3D.zylinder(0.345, 0.345, 0.06), _p("braun"), Vector3(0, 0.22, 0), Vector3.ZERO, false)
	for s in [-1.0, 1.0]:
		_strebe(k, Vector3(0.3 * s, 0.2, 0.08), Vector3(0.27 * s, -0.08, 0.14), 0.07, leder * 0.9)
	Stil3D.teil(k, Stil3D.box(0.46, 0.22, 0.07), leder * 0.9, Vector3(0, 0.1, -0.3), Vector3(-14, 0, 0))
	Stil3D.teil(k, Stil3D.box(0.05, 0.04, 0.62), _p("braun_hell"), Vector3(0, 0.555, 0.0), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.kugel(0.045, -1, 10), _p("messing_hell"), Vector3(0, 0.57, 0), Vector3.ZERO, false)


## Schwerer Helm: Topfhelm mit Sehschlitz, Nasengrat, Goldband und rotem
## Federkamm (wie die Tank-Figur), in 3/4-Ansicht.
static func _helm_schwer(n: Node3D) -> void:
	var k := _gelenk(n, Vector3(0, -34, 0))
	var stahl := _p("silber")
	Stil3D.teil(k, Stil3D.zylinder(0.32, 0.33, 0.48), stahl, Vector3(0, 0.3, 0))
	Stil3D.teil(k, _halbkugel(0.32, 0.15), stahl, Vector3(0, 0.54, 0))
	Stil3D.teil(k, Stil3D.zylinder(0.335, 0.34, 0.05), _p("gold"), Vector3(0, 0.08, 0), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.box(0.46, 0.055, 0.06), _p("nacht"), Vector3(0, 0.38, 0.3), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.box(0.06, 0.34, 0.05), stahl * 1.08, Vector3(0, 0.27, 0.325))
	for x in [-0.12, 0.12]:
		for y in [0.17, 0.24]:
			Stil3D.teil(k, Stil3D.kugel(0.018, -1, 8), _p("nacht"), Vector3(x, y, 0.32), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.box(0.08, 0.16, 0.58), _p("umhang"), Vector3(0, 0.74, -0.02))


## Handschuh: Handrücken, Finger, Daumen, ausgestellte Stulpe; schwer =
## Stahl mit Goldknöchel und Goldrand, leicht = Leder mit Naht.
static func _handschuh(n: Node3D, farbe: Color, schwer: bool) -> void:
	var k := _gelenk(n, Vector3(0, -20, 0))
	Stil3D.teil(k, Stil3D.box(0.42, 0.4, 0.18), farbe, Vector3(0, 0.46, 0))
	for i in 4:
		Stil3D.teil(k, Stil3D.box(0.085, 0.24, 0.13), farbe, Vector3(-0.155 + i * 0.103, 0.77, 0))
	Stil3D.teil(k, Stil3D.box(0.11, 0.22, 0.13), farbe, Vector3(0.27, 0.5, 0), Vector3(0, 0, -40))
	Stil3D.teil(k, Stil3D.zylinder(0.25, 0.2, 0.22), farbe * 0.85, Vector3(0, 0.16, 0))
	if schwer:
		Stil3D.teil(k, Stil3D.box(0.44, 0.08, 0.2), _p("gold"), Vector3(0, 0.64, 0), Vector3.ZERO, false)
		Stil3D.teil(k, Stil3D.zylinder(0.255, 0.255, 0.04), _p("gold"), Vector3(0, 0.26, 0), Vector3.ZERO, false)
	else:
		Stil3D.teil(k, Stil3D.box(0.3, 0.025, 0.01), _p("braun_hell"), Vector3(0, 0.36, 0.092), Vector3.ZERO, false)
		Stil3D.teil(k, Stil3D.zylinder(0.255, 0.255, 0.03), _p("braun"), Vector3(0, 0.26, 0), Vector3.ZERO, false)


## Stiefelpaar im Profil: Schaft, Fuß, Sohle, Umschlag; schwer = Stahl
## mit Kniebuckel und Goldrand.
static func _stiefel(n: Node3D, farbe: Color, schwer: bool) -> void:
	var paar := _gelenk(n, Vector3(0, -62, 0))
	for nr in 2:
		var k := _gelenk(paar, Vector3.ZERO, Vector3(0.3, 0, -0.12) * nr)
		var f := farbe * (1.0 if nr == 0 else 0.86)
		Stil3D.teil(k, Stil3D.box(0.26, 0.5, 0.28), f, Vector3(0, 0.42, 0))
		Stil3D.teil(k, Stil3D.box(0.27, 0.18, 0.4), f, Vector3(0, 0.12, 0.12))
		Stil3D.teil(k, Stil3D.kugel(0.135, 0.18), f, Vector3(0, 0.12, 0.3))
		Stil3D.teil(k, Stil3D.box(0.29, 0.05, 0.56), _p("braun") * 0.7, Vector3(0, 0.02, 0.1))
		if schwer:
			Stil3D.teil(k, Stil3D.box(0.3, 0.06, 0.31), _p("gold"), Vector3(0, 0.66, 0), Vector3.ZERO, false)
			Stil3D.teil(k, Stil3D.kugel(0.1, 0.12), f * 1.08, Vector3(0, 0.5, 0.14))
		else:
			Stil3D.teil(k, Stil3D.box(0.3, 0.12, 0.31), _p("braun_hell"), Vector3(0, 0.66, 0))


static func _ring(n: Node3D) -> void:
	Stil3D.teil(n, _ringmesh(0.24, 0.35), _p("gold"), Vector3(0, 0.35, 0), Vector3(70, 0, 0))
	Stil3D.teil(n, Stil3D.zylinder(0.12, 0.08, 0.1), _p("gold"), Vector3(0, 0.68, 0.06), Vector3(-20, 0, 0))
	Stil3D.teil(n, Stil3D.kugel(0.12), _p("daemon"), Vector3(0, 0.77, 0.08), Vector3.ZERO, true, _p("daemon") * 0.5)


## Amulett: großer Anhänger (Stein in Goldfassung) mittig, Kette nur als
## kurzer Perlenbogen oben.
static func _amulett(n: Node3D) -> void:
	var gold := _p("gold")
	Stil3D.teil(n, Stil3D.zylinder(0.24, 0.24, 0.07, 28), gold, Vector3(0, 0.36, 0), Vector3(90, 0, 0))
	Stil3D.teil(n, Stil3D.kugel(0.155), _p("kristall"), Vector3(0, 0.36, 0.07), Vector3.ZERO, true,
		_p("kristall") * 0.5)
	Stil3D.teil(n, Stil3D.prisma(0.14, 0.16, 0.06), gold, Vector3(0, 0.07, 0), Vector3(180, 0, 0))
	Stil3D.teil(n, _ringmesh(0.035, 0.07, 16, 6), gold, Vector3(0, 0.64, 0), Vector3(0, 90, 0))
	for s in [-1.0, 1.0]:
		for i in 4:
			var x: float = (0.09 + i * 0.085) * s
			var y := 0.7 + pow(absf(x) / 0.36, 0.75) * 0.34
			Stil3D.teil(n, Stil3D.kugel(0.042, -1, 10), gold, Vector3(x, y, 0))
