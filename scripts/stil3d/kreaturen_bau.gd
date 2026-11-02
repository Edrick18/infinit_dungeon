class_name KreaturenBau
extends RefCounted
## Figuren 2.0 für Krabbler, Flieger, Konstrukte, Geist und Mimic (STIL-3D.md
## 7j): jede Figur ist eine Gliederpuppe — gebacken je Glied (Körper +
## Hülle), gleiche Gegner teilen ihre Meshes (Gliederpuppe.gebacken), Glieder
## werden nur gedreht (höchstens drei je Figur).
##
## „Kreaturen-Diorama": jede Art trägt EIN Silhouetten-Zeichen, das in der
## 45°-Draufsicht (Dungeon, Zoom 16) und im Porträt trägt —
##   Spinne = flaches X mit hochgestellten Knien + leuchtende Sanduhr,
##   Pilzkrabbel = rote Kuppel mit erhobenen Scheren und Stielaugen,
##   Fledermaus = gezacktes M aus Fingerknochen-Flügeln,
##   Geist = Tropfen mit gekringeltem Leuchtschweif und Klauenarmen,
##   Golem = Gorilla-Trapez aus gefasten Steinblöcken mit Kristallgrat,
##   Pilzstamm = Schirm auf Baumstumpf mit Wurzelfüßen und Schwammschild,
##   Mimic = aufgerissene Risiko-Truhe auf Krallenbeinen,
##   Kristallkäfer = Kuppelpanzer mit leuchtenden Kristalldrusen und Horn,
##   Kristallkönigin = derselbe Käfer, größer, mit Drusenkranz und Eiersack.
## Rund = flink, kantig = schwer, spitz = gefährlich. Die Ruheposen sind auf
## die beste Silhouette ausgelegt (Porträt, ferne Figuren im Dungeon).

const GRAD := PI / 180.0

## Archetypen dieses Baukastens (FigurenBau.fuer_archetyp leitet sie hierher).
const ARTEN := [&"spinne", &"pilzkrabbel", &"fledermaus", &"geist", &"golem", &"pilzstamm", &"mimic",
	&"kristallkaefer", &"kristallkoenigin", &"aschekoloss"]

## Eigengröße je Archetyp (ins Mesh gebacken, die Kontur bleibt gleich dick).
const GROESSE := {&"pilzkrabbel": 0.8, &"kristallkaefer": 0.9, &"kristallkoenigin": 1.35, &"aschekoloss": 1.15}

## Animationsprofil je Archetyp (Gliederpuppe.PROFILE).
const ANIM := {&"spinne": "spinne", &"pilzkrabbel": "krabbe", &"fledermaus": "fledermaus", &"geist": "geist",
	&"golem": "golem", &"pilzstamm": "pilzstamm", &"mimic": "mimic", &"kristallkaefer": "spinne",
	&"kristallkoenigin": "spinne", &"aschekoloss": "golem"}


static func _p(n: String) -> Color:
	return Stil3D.farbe(n)


## Teile eines Glied-Bausatzes in Figurmaßen: o = Gelenk des Glieds (die
## Teile stehen relativ dazu), im Rumpf Null.
class S:
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

	## Zylinder (verjüngt: r0 bei a, r1 bei z) bzw. Kapsel (r0) von a nach z.
	func strebe(a: Vector3, z: Vector3, r0: float, r1: float, farbe: Color, kontur := true, kapsel := false,
			leuchten := 0.0) -> void:
		var d := z - a
		var seg := 8 if maxf(r0, r1) > 0.03 else 6
		var m: PrimitiveMesh = Stil3D.kapsel(r0, d.length() + r0 * 2.0, 8) if kapsel \
			else Stil3D.zylinder(r1, r0, d.length(), seg)
		tb(m, farbe, KreaturenBau._zu(d), (a + z) * 0.5, kontur, leuchten)

	func fasen(groesse: Vector3, farbe: Color, pos: Vector3, rot := Vector3.ZERO, kontur := true,
			leuchten := 0.0, fase := 0.035) -> void:
		b.fasenbox(groesse, fase, farbe, Transform3D(Basis.from_euler(rot * KreaturenBau.GRAD), pos - o), kontur,
			leuchten)

	func dreieck(p: Vector3, q: Vector3, r: Vector3, dicke: float, farbe: Color, kontur := true) -> void:
		b.dreieck(p - o, q - o, r - o, dicke, farbe, kontur)

	func auge(pos: Vector3, r: float, opt := {}) -> void:
		Gliederpuppe.auge(b, pos - o, r, opt)

	func braue(pos: Vector3, breite: float, seite: float, winkel := 22.0, farbe := Color("1b1a24")) -> void:
		Gliederpuppe.braue(b, pos - o, breite, seite, winkel, farbe)

	## Ring (Torus) mit Achse entlang achse — Fellringe, Schellen, Kettenglieder.
	func ring(r: float, rohr: float, farbe: Color, pos: Vector3, achse := Vector3.UP, kontur := false,
			leuchten := 0.0, quetsch := 1.0) -> void:
		var tor := TorusMesh.new()
		tor.inner_radius = r - rohr
		tor.outer_radius = r + rohr
		tor.rings = 16 if r > 0.1 else 8
		tor.ring_segments = 5 if r > 0.1 else 4
		var basis := KreaturenBau._zu(achse)
		if not is_equal_approx(quetsch, 1.0):
			basis = Basis.from_scale(Vector3(1, quetsch, 1)) * basis
		tb(tor, farbe, basis, pos, kontur, leuchten)


## Basis, deren +Y entlang d zeigt (Beine, Stacheln, Stielaugen).
static func _zu(d: Vector3) -> Basis:
	var n := d.normalized()
	if n.dot(Vector3.UP) < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, n))


## Leuchtfarbe (Augen, Akzente): Boss = Siegelrot, Akzent (Elite lila), sonst
## c — dazu die Leuchtstärke.
static func _glut(k: Dictionary, c: Color, leuchten := 0.0) -> Array:
	if k.get("boss", false):
		return [_p("boss_siegel"), 0.8]
	var akzent: Variant = k.get("akzent", null)
	if akzent != null:
		return [akzent, maxf(leuchten, 0.7)]
	return [c, leuchten]


## Augen-Optionen: Iris nur, wenn Boss/Elite sie färben (sonst Cartoon-Auge
## mit schwarzer Pupille) oder die Art eine eigene Irisfarbe hat.
static func _augen_opt(k: Dictionary, s: float, iris: Variant = null, blick := Vector3(0, 0, 1)) -> Dictionary:
	var o := {"seite": s, "blick": blick}
	if k.get("boss", false) or k.get("akzent", null) != null:
		var g := _glut(k, Color.WHITE)
		o["iris"] = g[0]
		o["iris_leuchten"] = g[1]
	elif iris != null:
		o["iris"] = iris
	return o


static func _horn(k: Dictionary) -> float:
	return 1.3 if k.get("boss", false) else 1.0


## Golem-Varianten (EnemyFactory, Gruppe "konstrukt"): Steinfarben und
## kleine Teile — Rost = rostbrauner Stein mit Roststellen statt Moos,
## Kristall = kühler Blaustein mit leuchtenden Kristallkissen und hellerem
## Grat, Obsidian = schwarzes Glas mit glühenden Lavarissen.
const GOLEM_VARIANTEN := {
	"rost": {"stein": Color("a3735a"), "dunkel": Color("74483a"), "hell": Color("c4906c"), "moos": Color("c0602a"),
		"halm": Color("8a4a2a"), "fuge": Color("3a1e14")},
	"kristall": {"stein": Color("8e9ab6"), "dunkel": Color("66708e"), "hell": Color("b6c2dc"), "moos": Color("8ff0ff"),
		"moos_leuchten": 0.55, "halm": Color("6fe3f0"), "grat_leuchten": 0.9},
	"obsidian": {"stein": Color("3e3850"), "dunkel": Color("27232f"), "hell": Color("5a5474"), "moos": Color("4a4458"),
		"halm": Color("ff7a3a"), "fuge": Color("ff6a2a"), "fuge_leuchten": 0.9, "grat": Color("6a5a96"),
		"grat_leuchten": 0.35},
}

## Geist-Varianten (EnemyFactory, Gruppe "geist"): Seelenleib und Schweif-
## Ende (geist » tief) — Zorn = glühend rot mit bösen Brauen, Frost =
## eisblau mit Eissplittern am Kopf, Polter = verblichenes Sepia.
const GEIST_VARIANTEN := {
	"zorn": {"geist": Color("f6dcd8"), "tief": Color("d8645a"), "brauen": 24.0},
	"frost": {"geist": Color("e4f6ff"), "tief": Color("78c4f0"), "eis": true},
	"polter": {"geist": Color("f0e6d2"), "tief": Color("b8986a")},
}


# --- Einstieg ----------------------------------------------------------------------

## Figur aus dem Mesh-Cache (Schlüssel Art | Größe | Boss | Akzent |
## Variante). variante: Golem (rost, kristall, obsidian) und Geist (zorn,
## frost, polter) färben Stein bzw. Seelenleib und tragen kleine Teile; alle
## anderen Varianten wirken nur über den Akzent (FigurenBau.fuer_archetyp).
static func gegner(id: StringName, massstab := 1.0, boss := false, akzent: Variant = null,
		variante := "") -> Node3D:
	var g := float(GROESSE.get(id, 1.0)) * massstab
	# Fledermaus: Leuchtmal auf der Stirn (sonst leuchten nur die Augen);
	# Spinne, Krabbel, Pilzstamm und Mimic tragen den Akzent an Sanduhr,
	# Sporen, Leuchtpilzen bzw. Augen.
	var mal: Variant = FigurenBau.kennung_farbe(variante) if id == &"fledermaus" else null
	var eigen := (id == &"golem" and GOLEM_VARIANTEN.has(variante)) or (id == &"geist" and GEIST_VARIANTEN.has(variante))
	if not eigen:
		variante = ""  # ändert das Mesh nicht — gleicher Cache wie ohne Variante
	if id == &"aschekoloss":
		variante = "asche"  # Aschekoloss: immer der Basalt-Golem mit Glut und Hörnern
	var key := "kb|%s|%.3f|%s|%s|%s|%s" % [id, g, boss, (akzent as Color).to_html(false) if akzent != null else "-",
		variante, (mal as Color).to_html(false) if mal != null else "-"]
	var k := {"boss": boss, "akzent": akzent, "variante": variante, "mal": mal}
	return Gliederpuppe.gebacken(key, func() -> Gliederpuppe: return puppe(id, g, k))


static func puppe(id: StringName, g: float, k: Dictionary) -> Gliederpuppe:
	var pu := Gliederpuppe.new(String(id).capitalize(), g)
	pu.meta("anim", String(ANIM.get(id, "spinne"))).meta("wippen", 0.015).meta("drehung", 0.0)
	match id:
		&"spinne":
			_spinne(pu, k)
		&"pilzkrabbel":
			_pilzkrabbel(pu, k)
		&"fledermaus":
			_fledermaus(pu, k)
		&"geist":
			_geist(pu, k)
		&"golem", &"aschekoloss":
			_golem(pu, k)
		&"pilzstamm":
			_pilzstamm(pu, k)
		&"mimic":
			_mimic(pu, k)
		&"kristallkaefer", &"kristallkoenigin":
			_kaefer(pu, k, id == &"kristallkoenigin")
	return pu


# --- Riesenspinne ------------------------------------------------------------------

const _SPINNE_HUEFTE := [0.16, 0.11, 0.05, 0.0]
const _SPINNE_KNIE := [[0.34, 0.44, 0.32], [0.38, 0.5, 0.12], [0.38, 0.5, -0.1], [0.34, 0.44, -0.3]]
const _SPINNE_SPITZE := [[0.5, 0.0, 0.52], [0.57, 0.0, 0.2], [0.57, 0.0, -0.18], [0.5, 0.0, -0.5]]


## Riesenspinne (Wald/Höhle, scheuer Giftbeißer): praller Hinterleib mit
## leuchtender Sanduhr und Fellringen, Brustteil mit Borsten, Kopf mit zwei
## großen Augen, vier glimmenden Nebenaugen, bösen Brauen und Kieferklauen
## mit Giftzähnen. Acht Beine mit hochgestellten Knien in zwei Gliedern
## (beine_a/beine_b: abwechselnd links/rechts — nervöses Trippeln).
static func _spinne(pu: Gliederpuppe, k: Dictionary) -> void:
	pu.meta("wippen", 0.012).meta("drehung", 25.0)
	var dunkel := _p("schatten")
	var akz := _glut(k, _p("daemon"), 0.45)
	var horn := _horn(k)
	var kg := Vector3(0, 0.26, -0.02)
	var kk := S.new(pu.glied("koerper", kg), kg)
	# Hinterleib mit Fellringen und Sanduhr
	var hl := Vector3(0, 0.3, -0.25)
	kk.t(Stil3D.kugel(0.27, 0.36), dunkel, hl)
	for dz: float in [-0.08, 0.07]:
		var rr := 0.27 * sqrt(1.0 - pow(dz / 0.27, 2.0)) + 0.004
		kk.ring(rr, 0.014, dunkel.lightened(0.22), hl + Vector3(0, 0, dz), Vector3.BACK, false, 0.0, 0.67)
	for sz: float in [-1.0, 1.0]:
		var kegel_b := Basis.from_scale(Vector3(1, 0.4, 1)) * _zu(Vector3(0, 0, -sz))
		kk.tb(Stil3D.kegel(0.085, 0.1, 10), akz[0], kegel_b, hl + Vector3(0, 0.178, 0.05 * sz), false,
			maxf(0.45, akz[1]))
	# Brustteil mit Borsten, Kopf
	var br := Vector3(0, 0.27, 0.08)
	kk.t(Stil3D.kugel(0.17, 0.26), dunkel * 1.15, br)
	for v in [Vector3(-0.07, 0.37, 0.04), Vector3(0.07, 0.37, 0.04), Vector3(-0.04, 0.39, 0.1),
			Vector3(0.04, 0.39, 0.1), Vector3(-0.09, 0.35, -0.02), Vector3(0.09, 0.35, -0.02)]:
		kk.tb(Stil3D.kegel(0.02, 0.06, 6), dunkel * 1.4, _zu(v - br), v, false)
	var kopf := Vector3(0, 0.28, 0.24)
	kk.t(Stil3D.kugel(0.13), dunkel * 1.2, kopf)
	for s: float in [-1.0, 1.0]:
		kk.auge(Vector3(0.052 * s, 0.315, 0.335), 0.056, _augen_opt(k, s, _p("daemon"), Vector3(0.15 * s, 0, 1)))
		kk.braue(Vector3(0.056 * s, 0.382, 0.35), 0.075, s, 24.0)
		for v in [Vector3(0.026 * s, 0.405, 0.3), Vector3(0.078 * s, 0.39, 0.285)]:
			kk.t(Stil3D.kugel(0.02, -1.0, 8), akz[0], v, Vector3.ZERO, false, maxf(0.6, akz[1]))
		# Kieferklaue mit Giftzahn (nach innen gebogen)
		var oben := Vector3(0.05 * s, 0.24, 0.33)
		var unten := Vector3(0.055 * s, 0.16, 0.37)
		kk.strebe(oben, unten, 0.03, 0.03, dunkel * 1.35, true, true)
		var zahn_d := Vector3(-0.35 * s, -1.0, 0.2)
		var zahn := unten + zahn_d.normalized() * 0.04 * horn
		kk.tb(Stil3D.kegel(0.022, 0.07 * horn, 8), _p("knochen"), _zu(zahn_d), zahn, false,
			0.5 if k.get("boss", false) else 0.0)
		if s > 0.0:
			kk.t(Stil3D.kugel(0.018, -1.0, 6), _p("moos"), zahn + zahn_d.normalized() * 0.045, Vector3.ZERO, false,
				0.5)
	# Acht Beine: Oberschenkel hoch zum Knie, Unterschenkel hinab zur Spitze,
	# Knie-Kugel, Ringel in der Akzentfarbe.
	var bg := Vector3(0, 0.3, 0.05)
	var beine_a := S.new(pu.glied("beine_a", bg), bg)
	var beine_b := S.new(pu.glied("beine_b", bg), bg)
	for s: float in [-1.0, 1.0]:
		for i in 4:
			var ziel := beine_a if (i % 2 == 0) == (s < 0.0) else beine_b
			var huefte := Vector3(0.12 * s, 0.28, 0.08 + float(_SPINNE_HUEFTE[i]) - 0.08)
			var kn: Array = _SPINNE_KNIE[i]
			var sp: Array = _SPINNE_SPITZE[i]
			var knie := Vector3(float(kn[0]) * s, kn[1], kn[2])
			var spitze := Vector3(float(sp[0]) * s, sp[1], sp[2])
			ziel.strebe(huefte, knie, 0.032, 0.026, dunkel)
			ziel.t(Stil3D.kugel(0.036, -1.0, 6), dunkel * 0.8, knie)
			ziel.strebe(knie, spitze, 0.026, 0.008, dunkel)
			ziel.ring(0.03, 0.009, akz[0], knie.lerp(spitze, 0.32), spitze - knie, false, akz[1] * 0.6)
	pu.meta("anker_kopf", Vector3(0, 0.4, 0.24) - kg).meta("anker_kopf_glied", "koerper")
	pu.meta("anker_ruecken", hl + Vector3(0, 0.2, 0) - kg).meta("anker_ruecken_glied", "koerper")
	pu.meta("brust_y", 0.1)


# --- Pilzkrabbel -------------------------------------------------------------------

## Pilzkrabbel (Wald, aggressiv): eine Krabbe unter einer roten Pilzkuppel —
## Hutrand-Lippe, weiße Tupfen, Lamellen-Unterseite, heller Stielkörper mit
## Mooskissen, Sporen über dem Hut, Stielaugen vor dem Hutrand und breiter
## Krabbenmund. Glieder: zwei erhobene Scheren (V) und die sechs Beine.
static func _pilzkrabbel(pu: Gliederpuppe, k: Dictionary) -> void:
	pu.meta("wippen", 0.015).meta("drehung", 25.0)
	var r := S.new(pu.rumpf)
	var rot := _p("pilz_rot")
	var hell := _p("braun_hell")
	var horn := _horn(k)
	r.t(Stil3D.kugel(0.2, 0.22), _p("knochen") * 0.9, Vector3(0, 0.22, 0.02))
	for v in [Vector3(0, 0.26, -0.17), Vector3(0.09, 0.22, -0.15), Vector3(-0.08, 0.21, -0.16)]:
		r.t(Stil3D.kugel(0.06, 0.05), _p("moos"), v, Vector3(-40, 0, 0), v.x == 0.0)
	# Pilzkuppel: Kuppel, dicke Lippe, Lamellen, Tupfen
	var c := Vector3(0, 0.33, -0.04)
	var kuppel := Stil3D.kugel(0.4, 0.25)
	kuppel.is_hemisphere = true
	r.t(kuppel, rot, c)
	r.ring(0.38, 0.036, rot * 0.85, c + Vector3(0, 0.004, 0), Vector3.UP, true)
	r.t(Stil3D.zylinder(0.37, 0.37, 0.035, 18), _p("knochen") * 0.85, c + Vector3(0, -0.018, 0))
	for i in 12:
		var w := TAU * i / 12.0
		r.t(Stil3D.box(0.012, 0.01, 0.28), hell * 0.8, c + Vector3(sin(w) * 0.2, -0.037, cos(w) * 0.2),
			Vector3(0, rad_to_deg(w), 0), false)
	for tupf in [[0.0, 38.0, 0.075], [62.0, 52.0, 0.055], [-68.0, 48.0, 0.065], [150.0, 44.0, 0.06],
			[-140.0, 34.0, 0.05], [18.0, 74.0, 0.05]]:
		var az := float(tupf[0]) * GRAD
		var el := float(tupf[1]) * GRAD
		var p := c + Vector3(sin(az) * cos(el) * 0.4, sin(el) * 0.25, cos(az) * cos(el) * 0.4)
		var n := Vector3(sin(az) * cos(el) / 0.4, sin(el) / 0.25, cos(az) * cos(el) / 0.4)
		r.tb(Stil3D.kugel(float(tupf[2]), float(tupf[2]) * 0.5, 8), _p("weiss"), _zu(n), p, false)
	var spore := _glut(k, _p("moos"), 0.5)
	for v in [Vector3(0.13, 0.66, -0.02), Vector3(-0.11, 0.71, -0.1), Vector3(0.02, 0.77, 0.06)]:
		r.t(Stil3D.kugel(0.026, -1.0, 6), spore[0], v, Vector3.ZERO, false, maxf(0.5, spore[1]))
	# Stielaugen (vor dem Hutrand, auch von oben sichtbar), Krabbenmund
	for s: float in [-1.0, 1.0]:
		var auge := Vector3(0.125 * s, 0.48, 0.42)
		r.strebe(Vector3(0.07 * s, 0.25, 0.2), auge - Vector3(0, 0.04, 0.0), 0.022, 0.018, _p("knochen"))
		r.t(Stil3D.kugel(0.062, 0.07), _p("knochen"), auge + Vector3(0, -0.005, -0.012))
		r.auge(auge + Vector3(0, 0.0, 0.012), 0.056, _augen_opt(k, s, null, Vector3(0.12 * s, -0.1, 1)))
		r.braue(auge + Vector3(0.0, 0.068, 0.03), 0.075, s, 24.0)
	r.t(Stil3D.box(0.13, 0.032, 0.03), _p("mund"), Vector3(0, 0.165, 0.205), Vector3.ZERO, false)
	for i in 4:
		r.t(Stil3D.box(0.018, 0.02, 0.012), _p("weiss"), Vector3(-0.045 + i * 0.03, 0.175, 0.218), Vector3.ZERO, false)
	# Scheren: Oberarm, Scherenballen mit Tupfen, offene Zange mit Knochenspitzen
	for s: float in [-1.0, 1.0]:
		var gel := Vector3(0.2 * s, 0.24, 0.14)
		var sch := S.new(pu.glied("schere_l" if s < 0.0 else "schere_r", gel), gel)
		var ballen := gel + Vector3(0.25 * s, 0.16, 0.06)
		sch.strebe(gel, ballen, 0.042, 0.042, hell, true, true)
		sch.t(Stil3D.kugel(0.085, 0.13), rot * 0.92, ballen)
		for v in [Vector3(0.05 * s, 0.03, 0.06), Vector3(0.075 * s, -0.02, 0.0)]:
			sch.tb(Stil3D.kugel(0.022, 0.011, 8), _p("weiss"), _zu(v), ballen + v.normalized() * 0.083, false)
		for finger in [[-14.0, 0.065, 0.17, 0.055, 0.03], [16.0, 0.05, 0.13, 0.045, -0.03]]:
			var neig := Basis.from_euler(Vector3(-8, 0, float(finger[0]) * s) * GRAD)
			var fuss := ballen + Vector3(float(finger[4]) * s, 0.05, 0.0)
			var h := float(finger[2]) * horn
			sch.tb(Stil3D.prisma(finger[1], h, finger[3]), rot * 0.92, neig, fuss + neig * Vector3(0, h * 0.5, 0))
			sch.tb(Stil3D.kegel(0.016, 0.045, 6), _p("knochen"), neig, fuss + neig * Vector3(0, h + 0.005, 0), false,
				0.5 if k.get("boss", false) else 0.0)
	# Sechs kurze, nach außen geknickte Beine
	var bg := Vector3(0, 0.12, 0)
	var beine := S.new(pu.glied("beine", bg), bg)
	for s: float in [-1.0, 1.0]:
		for z: float in [0.09, -0.02, -0.13]:
			var huefte := Vector3(0.14 * s, 0.16, z)
			var knie := Vector3(0.28 * s, 0.2, z * 1.3)
			var spitze := Vector3(0.37 * s, 0.0, z * 1.6)
			beine.strebe(huefte, knie, 0.026, 0.024, hell)
			beine.strebe(knie, spitze, 0.024, 0.008, hell)
	pu.meta("anker_kopf", Vector3(0, 0.6, -0.04)).meta("anker_ruecken", Vector3(0, 0.5, -0.25))
	pu.meta("hoerner", true).meta("brust_y", 0.12)


# --- Kristallkäfer / Kristallkönigin -----------------------------------------------

## Kristallkäfer (Höhle, territorial): flache Panzerkuppel aus dunklem
## Höhlenstein mit Mittelnaht, auf dem Rücken leuchtende Kristalldrusen (das
## Kennzeichen, schräg nach hinten), kurzer Kopf mit Kristallhorn, zwei
## Augen unter bösen Brauen und Beißzangen. Sechs Beine in zwei Gliedern
## (beine_a/beine_b wie die Spinne: Trippeln). Königin: größer, ein Kranz
## aus sieben Drusen, dazu ein leuchtender Eiersack hinter dem Panzer.
static func _kaefer(pu: Gliederpuppe, k: Dictionary, koenigin: bool) -> void:
	pu.meta("wippen", 0.012).meta("drehung", 25.0)
	var panzer := _p("mitternacht")
	var dunkel := _p("stein_dunkel")
	var kris := _glut(k, _p("kristall"), 0.45)
	var horn := _horn(k)
	var kg := Vector3(0, 0.2, 0)
	var kk := S.new(pu.glied("koerper", kg), kg)
	# Unterleib, Panzerkuppel mit Naht und Saum
	kk.t(Stil3D.kugel(0.24, 0.24), dunkel, Vector3(0, 0.18, -0.04))
	var kuppel := Vector3(0, 0.25, -0.06)
	kk.t(Stil3D.kugel(0.27, 0.3), panzer, kuppel)
	kk.t(Stil3D.box(0.016, 0.05, 0.42), panzer * 0.6, kuppel + Vector3(0, 0.135, -0.01), Vector3(4, 0, 0), false)
	kk.ring(0.265, 0.016, panzer * 0.75, kuppel + Vector3(0, -0.035, 0), Vector3.UP, false)
	if koenigin:
		var sack := Vector3(0, 0.22, -0.36)
		kk.t(Stil3D.kugel(0.2, 0.26), kris[0] * 0.75, sack, Vector3(-60, 0, 0), true, maxf(0.25, kris[1] * 0.5))
		for i in 3:
			kk.ring(0.15 - i * 0.03, 0.012, panzer * 0.8, sack + Vector3(0, 0.0, -0.06 - i * 0.05), Vector3.BACK, false)
	# Kristalldrusen: schräg nach hinten, die mittlere am höchsten
	var drusen: Array = [[0.0, 0.0, 0.2, 0.0], [-0.11, -0.05, 0.13, -18.0], [0.11, -0.05, 0.13, 18.0],
		[-0.05, -0.15, 0.1, -10.0], [0.06, -0.14, 0.09, 12.0]]
	if koenigin:
		drusen = [[0.0, 0.04, 0.26, 0.0], [-0.12, 0.0, 0.2, -22.0], [0.12, 0.0, 0.2, 22.0], [-0.19, -0.1, 0.15, -34.0],
			[0.19, -0.1, 0.15, 34.0], [-0.09, -0.18, 0.13, -14.0], [0.09, -0.18, 0.13, 14.0]]
	for dr in drusen:
		var fuss := kuppel + Vector3(float(dr[0]), 0.21 - absf(float(dr[0])) * 0.25, float(dr[1]))
		var rot := Vector3(-28, 0, -float(dr[3]))
		var h := float(dr[2]) * horn
		kk.tb(Stil3D.prisma(0.07, h, 0.06), kris[0], Basis.from_euler(rot * GRAD), fuss + Basis.from_euler(rot * GRAD)
			* Vector3(0, h * 0.5, 0), true, maxf(0.4, kris[1]))
	# Kopf mit Horn, Augen, Brauen, Beißzangen
	var kopf := Vector3(0, 0.2, 0.24)
	kk.t(Stil3D.kugel(0.13, 0.2), dunkel * 1.25, kopf)
	var horn_d := Vector3(0, 0.8, 0.6).normalized()
	kk.tb(Stil3D.kegel(0.045, 0.2 * horn, 8), kris[0], _zu(horn_d), kopf + Vector3(0, 0.08, 0.06) + horn_d * 0.1 * horn,
		true, maxf(0.35, kris[1]))
	for sd: float in [-1.0, 1.0]:
		kk.auge(Vector3(0.06 * sd, 0.23, 0.335), 0.05, _augen_opt(k, sd, _p("kristall"), Vector3(0.15 * sd, 0, 1)))
		kk.braue(Vector3(0.064 * sd, 0.29, 0.35), 0.07, sd, 26.0)
		var zange_d := Vector3(-0.45 * sd, -0.25, 1.0).normalized()
		kk.tb(Stil3D.kegel(0.025, 0.11 * horn, 6), _p("knochen") * 0.9, _zu(zange_d),
			Vector3(0.07 * sd, 0.13, 0.33) + zange_d * 0.05 * horn, false)
	# Sechs Beine, abwechselnd links/rechts in zwei Gliedern
	var bg := Vector3(0, 0.2, 0.0)
	var beine_a := S.new(pu.glied("beine_a", bg), bg)
	var beine_b := S.new(pu.glied("beine_b", bg), bg)
	var z_beine: Array[float] = [0.12, -0.02, -0.16]
	for sd: float in [-1.0, 1.0]:
		for i in 3:
			var ziel := beine_a if (i % 2 == 0) == (sd < 0.0) else beine_b
			var z := z_beine[i]
			var huefte := Vector3(0.17 * sd, 0.16, z)
			var knie := Vector3(0.32 * sd, 0.24, z * 1.25)
			var spitze := Vector3(0.42 * sd, 0.0, z * 1.6)
			ziel.strebe(huefte, knie, 0.03, 0.026, dunkel)
			ziel.t(Stil3D.kugel(0.032, -1.0, 6), panzer * 0.9, knie)
			ziel.strebe(knie, spitze, 0.026, 0.009, dunkel)
	pu.meta("anker_kopf", Vector3(0, 0.36, 0.22) - kg).meta("anker_kopf_glied", "koerper")
	pu.meta("anker_ruecken", kuppel + Vector3(0, 0.3, 0) - kg).meta("anker_ruecken_glied", "koerper")
	pu.meta("brust_y", 0.08).meta("hoerner", true)
	# Boss-Krone hinter dem Horn auf dem Panzerrand, nicht vor den Augen.
	pu.meta("krone_sitz", {"versatz": Vector3(0, 0.02, -0.13), "neigung": Vector3(-12, 0, 0), "groesse": 0.85})


# --- Fledermaus -------------------------------------------------------------------

## Fledermaus (Wald/Höhle, scheu): großer Ohrenkopf mit Innenohren,
## Nasenblatt, Fangzähnen, Fellkragen und hängenden Krallenfüßen. Die Flügel
## (fluegel_l/r) sind Fingerknochen mit Daumenkralle und dünnen Flughäuten,
## deren Saum zwischen den Fingern bogig einspringt (gezacktes M).
static func _fledermaus(pu: Gliederpuppe, k: Dictionary) -> void:
	pu.meta("wippen", 0.08).meta("schwebt", 0.2).meta("drehung", 0.0)
	var r := S.new(pu.rumpf)
	var lila := _p("lila")
	var kopf := Vector3(0, 1.04, 0.02)
	r.t(Stil3D.kugel(0.17), lila, kopf)
	r.t(Stil3D.kugel(0.14, 0.24), lila * 0.85, Vector3(0, 0.84, -0.02))
	r.t(Stil3D.kugel(0.09, 0.14), lila.lightened(0.25), Vector3(0, 0.83, 0.07), Vector3.ZERO, false)  # Bauchfleck
	r.t(Stil3D.kugel(0.13, 0.1), lila * 1.25, Vector3(0, 0.92, -0.03))  # Fellkragen
	if k.get("mal") != null:  # Leuchtmal der Variante bzw. Element-Schicht auf der Stirn
		r.t(Stil3D.kugel(0.032, 0.056, 8), k["mal"], kopf + Vector3(0, 0.1, 0.13), Vector3(-40, 0, 0), true, 0.5)
	for x: float in [-0.07, 0.0, 0.07]:
		r.t(Stil3D.kegel(0.03, 0.08, 6), lila * 1.25, Vector3(x, 0.87, 0.07 - absf(x) * 0.3), Vector3(160, 0, x * 200.0),
			false)
	for s: float in [-1.0, 1.0]:
		r.t(Stil3D.kegel(0.08, 0.24), lila, Vector3(0.1 * s, 1.22, 0), Vector3(-6, 0, -18.0 * s))
		r.t(Stil3D.kegel(0.05, 0.16, 8), _p("rosenquarz"), Vector3(0.1 * s, 1.2, 0.035), Vector3(-6, 0, -18.0 * s), false)
		r.auge(Vector3(0.066 * s, 1.07, 0.15), 0.062, _augen_opt(k, s, null, Vector3(0.1 * s, 0, 1)))
		r.braue(Vector3(0.066 * s, 1.14, 0.17), 0.08, s, 20.0)
		# Hängende Füße mit Krallen
		var fuss := Vector3(0.05 * s, 0.68, -0.03)
		r.t(Stil3D.kapsel(0.025, 0.09, 6), lila * 0.8, fuss + Vector3(0, 0.03, 0))
		for i in 3:
			r.t(Stil3D.kegel(0.009, 0.035, 5), _p("knochen"), fuss + Vector3((i - 1) * 0.016, -0.02, 0.006),
				Vector3(180, 0, 0), false)
	var schnauze := Vector3(0, 0.99, 0.18)
	r.t(Stil3D.kugel(0.05, 0.045), lila * 1.2, schnauze)
	r.t(Stil3D.prisma(0.05, 0.05, 0.02), _p("rosenquarz"), schnauze + Vector3(0, 0.035, 0.03), Vector3.ZERO, false)
	r.t(Stil3D.kugel(0.048, 0.028, 8), _p("mund"), Vector3(0, 0.95, 0.175), Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		r.t(Stil3D.kegel(0.012, 0.04, 5), _p("weiss"), Vector3(0.022 * s, 0.93, 0.2), Vector3(180, 0, 0), false)
	# Flügel: Armknochen bis zum Handgelenk, drei gefächerte Finger, dazwischen
	# Flughäute mit eingebuchtetem Saum, Daumenkralle.
	var knochen := _p("schatten")
	var haut := _p("lila_dunkel")
	for s: float in [-1.0, 1.0]:
		var gel := Vector3(0.12 * s, 1.0, -0.02)
		# Ruhe: Flughaut 45° nach hinten gekippt — in der 45°-Draufsicht des
		# Dungeons breit statt eines schmalen Strichs, von vorn noch offen.
		var f := S.new(pu.glied("fluegel_l" if s < 0.0 else "fluegel_r", gel, Vector3(-45, 0, 0)), gel)
		var hand := gel + Vector3(0.26 * s, 0.13, -0.01)
		f.strebe(gel, hand, 0.026, 0.026, knochen, true, true)
		var spitzen: Array[Vector3] = []
		for finger in [[20.0, 0.42], [-10.0, 0.37], [-40.0, 0.3]]:
			var w := float(finger[0]) * GRAD
			var spitze := hand + Vector3(cos(w) * s, sin(w), 0.0) * float(finger[1]) + Vector3(0, 0, -0.01)
			f.strebe(hand, spitze, 0.016, 0.007, knochen)
			spitzen.append(spitze)
		spitzen.append(gel + Vector3(0.03 * s, -0.2, -0.02))  # Flanke am Körper
		var z := Vector3(0, 0, -0.012)
		for i in 3:
			var p := spitzen[i]
			var q := spitzen[i + 1]
			var kerbe := hand + ((p + q) * 0.5 - hand) * (0.66 if i < 2 else 0.74)
			f.dreieck(hand + z, p + z, kerbe + z, 0.014, haut)
			f.dreieck(hand + z, kerbe + z, q + z, 0.014, haut)
		f.dreieck(gel + z, hand + z, spitzen[3] + z, 0.014, haut)
		f.tb(Stil3D.kegel(0.02, 0.065, 6), _p("knochen"), _zu(Vector3(-0.3 * s, 1, 0.2)),
			hand + Vector3(-0.012 * s, 0.04, 0.01), false)
	pu.meta("anker_kopf", Vector3(0, 1.22, 0.02)).meta("anker_ruecken", Vector3(0, 0.92, -0.15))
	pu.meta("brust_y", 0.74)


# --- Ruhelose Seele ----------------------------------------------------------------

## Geist (Ruinen/Krypta): Tropfen mit Seelen-Zipfeln, hohlen Augen mit
## leuchtenden Pupillen, gekränkten Brauen und Klage-Mund; leuchtet weich
## von innen (Vertex-Alpha, keine Transparenz). Glieder: der S-förmig
## gekringelte Schweif (geist » geist_tief, das Ende glimmt) und zwei
## greifende Klauenarme — rechts eine Eisenschelle mit zerrissener Kette.
static func _geist(pu: Gliederpuppe, k: Dictionary) -> void:
	pu.meta("wippen", 0.07).meta("schwebt", 0.25).meta("drehung", 0.0)
	var r := S.new(pu.rumpf)
	var gv: Dictionary = GEIST_VARIANTEN.get(k.get("variante", ""), {})
	var geist: Color = gv.get("geist", _p("geist"))
	var tief: Color = gv.get("tief", _p("geist_tief"))
	r.t(Stil3D.kugel(0.3, 0.46), geist, Vector3(0, 0.78, 0), Vector3.ZERO, true, 0.15)
	# Seelen-Zipfel: eine große, nach hinten gekringelte Locke, zwei kleine
	# daneben weiter hinten (Flammen-Schopf, keine Ohren-Silhouette).
	for zipfel in [[0.0, 0.0, 0.0, 0.24, 0.075, 3], [-0.09, -0.07, 24.0, 0.12, 0.04, 2],
			[0.09, -0.07, -24.0, 0.12, 0.04, 2]]:
		var fuss := Vector3(float(zipfel[0]), 0.97, -0.03 + float(zipfel[1]))
		Gliederpuppe.kette(r.b, Transform3D(Basis.from_euler(Vector3(-28, 0, float(zipfel[2])) * GRAD), fuss),
			int(zipfel[5]), float(zipfel[3]), float(zipfel[4]), 0.012, Vector3(-46, 0, 0), geist, null, 0.0)
	var glut := _glut(k, _p("seele"), 1.0)
	for s: float in [-1.0, 1.0]:
		r.auge(Vector3(0.1 * s, 0.84, 0.25), 0.075, {"hohl": true, "iris": glut[0], "iris_leuchten": maxf(0.9, glut[1]),
			"seite": s, "hoch": 0.68})
		r.braue(Vector3(0.1 * s, 0.94, 0.26), 0.1, s, float(gv.get("brauen", -18.0)))
		if gv.get("eis", false):  # Frost: zwei Eissplitter seitlich am Kopf
			r.tb(Stil3D.kegel(0.035, 0.13, 6), _p("kristall"), _zu(Vector3(0.7 * s, 1.0, -0.2)),
				Vector3(0.21 * s, 0.98, -0.04), true, 0.45)
	r.t(Stil3D.kugel(0.06, 0.1, 10), _p("schwarz"), Vector3(0, 0.67, 0.265), Vector3.ZERO, false)
	# Schweif: Kugeln von geist zu geist_tief, gekringelte Spitze glimmt
	var sg := Vector3(0, 0.6, -0.02)
	var sw := S.new(pu.glied("schweif", sg), sg)
	# Ein durchgehender, sich verjüngender Schlauch (Kegelstumpf-Kette): keine
	# Konturringe zwischen Kugeln, Farbe und Glühen steigen zum Ende an. Die
	# Abschnitte sind offene Röhren (ohne Deckel), die Gelenkkugeln tragen die
	# Hülle: vorher stachen die aufgeblähten Deckel-Ränder aus dem Nachbar-
	# abschnitt und zogen feine Linien quer über Bauch und Schweif (Rest Paket 4)
	# — eine Kugel-Hülle zeigt nur ihre Silhouette, die mit der Röhre abschließt.
	var lage := Transform3D(Basis.from_euler(Vector3(-12, 0, 172) * GRAD), Vector3(0.0, 0.66, -0.04) - sg)
	var knick := Basis.from_euler(Vector3(6, 0, 34) * GRAD)
	var radien := [0.26, 0.2, 0.14, 0.085, 0.04, 0.0]
	var laengen := [0.2, 0.17, 0.14, 0.12, 0.1]
	for i in 5:
		var u := float(i) / 4.0
		var seg: float = laengen[i]
		var m := Stil3D.zylinder(radien[i + 1], radien[i], seg * 1.15, 12)
		m.cap_top = false
		m.cap_bottom = false
		sw.b.teil_t(m, geist.lerp(tief, u), lage * Transform3D(Basis(), Vector3(0, seg * 0.5, 0)), true,
			lerpf(0.15, 0.4, u))
		if i < 4:
			sw.b.teil_t(Stil3D.kugel(radien[i + 1], -1.0, 12), geist.lerp(tief, u + 0.12),
				lage * Transform3D(Basis(), Vector3(0, seg, 0)), true, lerpf(0.15, 0.4, u))
		lage = lage * Transform3D(knick, Vector3(0, seg, 0))
	# Klauenarme greifen nach vorn
	for s: float in [-1.0, 1.0]:
		var gel := Vector3(0.26 * s, 0.74, 0.04)
		var arm := S.new(pu.glied("arm_l" if s < 0.0 else "arm_r", gel), gel)
		var hand := gel + Vector3(0.11 * s, -0.1, 0.25)
		arm.strebe(gel, hand, 0.062, 0.062, geist, true, true, 0.15)
		var d := (hand - gel).normalized()
		for i in 3:
			var w := (float(i) - 1.0) * 0.35
			var kd := (d + Vector3(sin(w) * 0.6, -0.25 + absf(w) * 0.2, 0)).normalized()
			arm.tb(Stil3D.kegel(0.024, 0.1, 6), geist, _zu(kd), hand + d * 0.04 + kd * 0.05, true, 0.15)
		if s > 0.0:
			var schelle := gel.lerp(hand, 0.72)
			arm.ring(0.07, 0.018, _p("eisen"), schelle, d, true)
			arm.ring(0.034, 0.011, _p("eisen") * 0.9, schelle + Vector3(0, -0.09, 0.0), Vector3.RIGHT, true)
			arm.ring(0.034, 0.011, _p("eisen") * 0.9, schelle + Vector3(0, -0.15, 0.01), Vector3.BACK, true)
	pu.meta("anker_kopf", Vector3(0, 1.04, 0)).meta("anker_ruecken", Vector3(0, 0.8, -0.26))
	pu.meta("brust_y", 0.44)


# --- Golem -------------------------------------------------------------------------

## Golem (Höhle/Ruinen, territorialer Tank, bossfähig): Gorilla-Trapez aus
## gefasten Steinblöcken — Säulenbeine mit Kiesel-Zehen, vorgeneigter Rumpf
## mit Brustplatte und leuchtendem Lebenskern (Y-Rune), Risse, Schulter-
## blöcke mit Mooskissen und Grashalmen, Kristallgrat auf dem Rücken. Kopf
## (Glied) mit Stirnwulst, Visierschlitz und Zyklopenauge; überlange Arme
## mit Ellbogenkugel und Riesenfaust. Boss (Urgolem): Kristallkrone,
## Schulterdornen, Runen auf den Fäusten, Kern im Siegelrot.
static func _golem(pu: Gliederpuppe, k: Dictionary) -> void:
	pu.meta("wippen", 0.012).meta("drehung", 0.0)
	var boss: bool = k.get("boss", false)
	var r := S.new(pu.rumpf)
	var asche: bool = k.get("variante", "") == "asche"
	var gv: Dictionary = _asche_golem() if asche else GOLEM_VARIANTEN.get(k.get("variante", ""), {})
	var stein: Color = gv.get("stein", _p("stein"))
	var stein_dunkel: Color = gv.get("dunkel", _p("stein_dunkel"))
	var stein_hell: Color = gv.get("hell", _p("stein_hell"))
	var moos: Color = gv.get("moos", _p("moos"))
	var moos_leuchten: float = gv.get("moos_leuchten", 0.0)
	var halm: Color = gv.get("halm", _p("moos_dunkel").lightened(0.15))
	var fuge: Color = gv.get("fuge", _p("fuge"))
	var fuge_leuchten: float = gv.get("fuge_leuchten", 0.0)
	var kern := _glut(k, _p("glut"), 0.8)
	# Becken, Säulenbeine, Füße mit Kiesel-Zehen
	r.fasen(Vector3(0.5, 0.22, 0.34), stein_dunkel, Vector3(0, 0.42, 0))
	for s: float in [-1.0, 1.0]:
		r.fasen(Vector3(0.22, 0.34, 0.24), stein * 0.9, Vector3(0.16 * s, 0.17, 0))
		r.fasen(Vector3(0.28, 0.1, 0.32), stein * 0.82, Vector3(0.17 * s, 0.05, 0.04))
		for i in 3:
			r.t(Stil3D.kugel(0.04, 0.05, 8), stein_hell * 0.9, Vector3(0.17 * s + (i - 1) * 0.08, 0.04, 0.21))
	# Rumpf 8° vorgeneigt (Teilsatz um die Rumpfmitte gekippt)
	var oben := pu.teilsatz()
	var ob := S.new(oben)
	ob.fasen(Vector3(0.78, 0.52, 0.48), stein, Vector3.ZERO, Vector3.ZERO, true, 0.0, 0.05)
	ob.fasen(Vector3(0.5, 0.3, 0.06), stein_hell, Vector3(0, 0.02, 0.25))
	for v in [Vector3(0, -0.055, 0.285), Vector3(-0.045, 0.05, 0.285), Vector3(0.045, 0.05, 0.285)]:
		var w := 0.0 if v.x == 0.0 else (-35.0 if v.x > 0.0 else 35.0)
		ob.t(Stil3D.box(0.024, 0.14, 0.012), kern[0], v, Vector3(0, 0, w), false, maxf(0.8, kern[1]))
	ob.t(Stil3D.kugel(0.03, -1.0, 8), kern[0], Vector3(0, 0.0, 0.285), Vector3.ZERO, false, 1.0)
	for riss in [[Vector3(0.392, 0.06, 0.08), 25.0], [Vector3(0.392, -0.12, -0.08), -30.0],
			[Vector3(-0.392, 0.1, -0.05), -20.0], [Vector3(-0.392, -0.1, 0.1), 35.0]]:
		var p: Vector3 = riss[0]
		ob.t(Stil3D.box(0.01, 0.2, 0.02), fuge, p, Vector3(float(riss[1]), 0, 0), false, fuge_leuchten)
	for v in [Vector3(-0.12, 0.2, 0.245), Vector3(0.14, -0.18, 0.245)]:
		ob.t(Stil3D.box(0.12, 0.012, 0.01), fuge, v, Vector3(0, 0, 20), false, fuge_leuchten)
	pu.uebernehmen(oben, Transform3D(Basis(Vector3.RIGHT, 8.0 * GRAD), Vector3(0, 0.78, 0)))
	# Schulterblöcke mit Mooskissen und Grashalmen
	for s: float in [-1.0, 1.0]:
		var sch := Vector3(0.46 * s, 0.98, 0.0)
		r.fasen(Vector3(0.3, 0.28, 0.34), stein_hell, sch, Vector3(0, 0, -6.0 * s))
		for v in [Vector3(0.0, 0.15, -0.02), Vector3(0.07 * s, 0.13, 0.08), Vector3(-0.06 * s, 0.13, -0.09)]:
			r.t(Stil3D.kugel(0.1 if v.x == 0.0 else 0.075, 0.07), moos, sch + v, Vector3.ZERO, v.x == 0.0, moos_leuchten)
		for g in [Vector3(0.05 * s, 0.17, 0.0), Vector3(-0.03 * s, 0.17, 0.04)]:
			r.t(Stil3D.kegel(0.014, 0.1, 5), halm, sch + g + Vector3(0, 0.04, 0),
				Vector3(10, 0, -20.0 * s), false)
		if boss:
			for i in 2:
				Gliederpuppe.kette(r.b, Transform3D(Basis.from_euler(Vector3(-20 + i * 30, 0, -30.0 * s) * GRAD),
					sch + Vector3(0.06 * s, 0.12, -0.08 + i * 0.12)), 2, 0.2, 0.045, 0.01, Vector3(0, 0, -10.0 * s),
					stein_dunkel, _p("boss_siegel"), 0.6)
	# Kristallgrat auf dem Rücken (nach außen gefächert)
	var grat := _glut(k, _p("kristall"), 0.5) if boss else [gv.get("grat", _p("kristall")), gv.get("grat_leuchten", 0.5)]
	for kr in [[Vector3(0, 1.02, -0.22), Vector3(-30, 0, 0), 0.38, 0.075], [Vector3(0.15, 0.98, -0.2),
			Vector3(-28, 0, -24), 0.3, 0.06], [Vector3(-0.15, 0.98, -0.2), Vector3(-28, 0, 24), 0.25, 0.055]]:
		var basis := Basis.from_euler((kr[1] as Vector3) * GRAD)
		var h := float(kr[2])
		r.tb(Stil3D.kegel(kr[3], h, 6), grat[0], basis, (kr[0] as Vector3) + basis * Vector3(0, h * 0.5, 0), true,
			grat[1])
	# Kopf: Block, Stirnwulst (grimmig), Visierschlitz, Zyklopenauge, Kieferkante
	var kg := Vector3(0, 1.06, 0.08)
	var kopf := S.new(pu.glied("kopf", kg), kg)
	var kc := kg + Vector3(0, 0.06, 0.03)
	kopf.fasen(Vector3(0.28, 0.22, 0.26), stein, kc)
	kopf.fasen(Vector3(0.32, 0.07, 0.1), stein_dunkel, kc + Vector3(0, 0.08, 0.1), Vector3(10, 0, 0), true, 0.0,
		0.02)
	kopf.t(Stil3D.box(0.2, 0.05, 0.02), _p("schwarz"), kc + Vector3(0, 0.01, 0.132), Vector3.ZERO, false)
	var auge := _glut(k, _p("glut"), 1.0)
	kopf.t(Stil3D.kugel(0.048, -1.0, 10), auge[0], kc + Vector3(0, 0.012, 0.135), Vector3.ZERO, false, 1.0)
	kopf.t(Stil3D.kugel(0.013, -1.0, 6), _p("weiss"), kc + Vector3(0.016, 0.03, 0.178), Vector3.ZERO, false, 0.5)
	kopf.fasen(Vector3(0.24, 0.06, 0.08), stein_dunkel, kc + Vector3(0, -0.085, 0.09), Vector3.ZERO, true, 0.0,
		0.02)
	if asche:
		# Aschekoloss: gebogene Hörner und eine glühende Brustspalte.
		for s: float in [-1.0, 1.0]:
			Gliederpuppe.kette(kopf.b, Transform3D(Basis.from_euler(Vector3(-10, 0, -50.0 * s) * GRAD),
				kc + Vector3(0.12 * s, 0.1, -0.02) - kg), 3, 0.3, 0.06, 0.015, Vector3(-20, 0, 25.0 * s),
				_p("knochen") * 0.75, _p("flamme"), 0.6)
	if boss and not asche:
		_kristallkrone(kopf, kc + Vector3(0, 0.11, -0.01))
		pu.meta("hat_krone", true)
	# Arme: Oberarm, sichtbares Ellbogengelenk, Unterarm, Riesenfaust
	for s: float in [-1.0, 1.0]:
		var gel := Vector3(0.46 * s, 0.96, 0.0)
		var arm := S.new(pu.glied("arm_l" if s < 0.0 else "arm_r", gel, Vector3(-6, 0, 5.0 * s)), gel)
		arm.fasen(Vector3(0.18, 0.34, 0.2), stein, gel + Vector3(0, -0.2, 0))
		arm.t(Stil3D.kugel(0.09, -1.0, 10), stein_dunkel, gel + Vector3(0, -0.4, 0))
		arm.fasen(Vector3(0.22, 0.28, 0.24), stein * 0.95, gel + Vector3(0, -0.53, 0.01))
		var faust := gel + Vector3(0, -0.76, 0.03)
		arm.fasen(Vector3(0.34, 0.3, 0.34), stein_hell, faust, Vector3.ZERO, true, 0.0, 0.05)
		for i in 4:
			arm.fasen(Vector3(0.07, 0.06, 0.08), stein_hell * 0.92,
				faust + Vector3((-0.105 + i * 0.07) * s, 0.06, 0.17), Vector3.ZERO, true, 0.0, 0.015)
		arm.fasen(Vector3(0.08, 0.12, 0.09), stein_hell * 0.92, faust + Vector3(-0.17 * s, 0.05, 0.08),
			Vector3(0, 0, 20.0 * s), true, 0.0, 0.015)
		if boss:
			for i in 2:
				arm.t(Stil3D.box(0.025, 0.14, 0.01), _p("boss_siegel"), faust + Vector3((-0.05 + i * 0.1) * s, -0.02,
					0.174), Vector3(0, 0, 25.0 - i * 50.0), false, 0.7)
	pu.meta("anker_kopf", kc + Vector3(0, 0.12, -0.01) - kg).meta("anker_kopf_glied", "kopf")
	pu.meta("anker_ruecken", Vector3(0, 0.98, -0.28)).meta("brust_y", 0.5).meta("hoerner", boss or asche)
	pu.meta("ring_faktor", 1.25)


## Aschekoloss (Höllenschlund): Golem-Bau aus Basalt mit Glutfugen,
## glühenden Graten und Ascheschultern — Farben aus der Hauspalette.
static func _asche_golem() -> Dictionary:
	return {"stein": _p("hoelle_wand"), "dunkel": _p("hoelle_deckel") * 0.8, "hell": _p("hoelle_boden"),
		"moos": _p("hoelle_moos"), "halm": _p("flamme"), "fuge": _p("hoelle_fuge"), "fuge_leuchten": 1.0,
		"grat": _p("flamme"), "grat_leuchten": 0.8}


## Urgolem-Krone: goldener Reif mit fünf leuchtenden Kristall-Zacken und
## rotem Stein vorn (ersetzt die Boss-Krone).
static func _kristallkrone(b: S, fuss: Vector3) -> void:
	var gold := _p("gold")
	b.t(Stil3D.zylinder(0.15, 0.14, 0.07, 14), gold, fuss + Vector3(0, 0.035, 0), Vector3(0, 0, 6))
	for i in 5:
		var w := TAU * i / 5.0
		var neig := Basis.from_euler(Vector3(cos(w) * 14.0, 0, -sin(w) * 14.0) * GRAD)
		var h := 0.16 if i == 0 else 0.12
		b.tb(Stil3D.kegel(0.04, h, 6), _p("kristall"), neig,
			fuss + Vector3(sin(w) * 0.12, 0.07, cos(w) * 0.12) + neig * Vector3(0, h * 0.45, 0), true, 0.6)
	b.t(Stil3D.kugel(0.03, -1.0, 8), _p("drachenblut"), fuss + Vector3(0, 0.04, 0.15), Vector3.ZERO, false, 0.4)


# --- Pilzstamm ---------------------------------------------------------------------

## Pilzstamm (Wald, Tank mit Selbstheilung): breiter roter Pilzhut auf einem
## dicken Baumstumpf mit Rindenleisten, Gesicht im Stamm (hohle Augen mit
## Seelenlicht, Moosbrauen, Astnase, Astloch-Mund mit Splitterzähnen,
## Moosbart), Leuchtpilze als Heiler-Zeichen. Wurzelfüße bleiben am Boden;
## das Glied "rumpf" wiegt wie ein Baum im Wind, darin die Astarme — links
## der Baumschwamm-Schild (Pilzpanzer).
static func _pilzstamm(pu: Gliederpuppe, k: Dictionary) -> void:
	pu.meta("wippen", 0.01).meta("drehung", 10.0)
	var braun := _p("braun")
	for i in 5:
		var w := deg_to_rad(-90.0 + i * 72.0 + 36.0)
		var d := Vector3(sin(w), -0.12, cos(w))
		var basis := _zu(d)
		pu.rumpf.teil_t(Stil3D.kegel(0.075, 0.34, 8), braun * 0.85, Transform3D(basis,
			Vector3(sin(w) * 0.3, 0.07, cos(w) * 0.3)))
	var rg := Vector3(0, 0.1, 0)
	var r := S.new(pu.glied("rumpf", rg), rg)
	r.t(Stil3D.zylinder(0.26, 0.32, 0.62, 12), braun, Vector3(0, 0.42, 0))
	for i in 7:
		var w := TAU * (float(i) + 0.5) / 7.0
		if absf(wrapf(w, -PI, PI)) < 0.5:
			continue  # vorn bleibt das Gesicht frei
		r.t(Stil3D.box(0.05, 0.5, 0.03), braun * 0.72, Vector3(sin(w) * 0.29, 0.42, cos(w) * 0.29),
			Vector3(-5.5 * cos(w), rad_to_deg(w), 5.5 * sin(w)), false)
	# Pilzhut mit Lippe, Tupfen, Lamellen und Leuchtpilzen
	var rot := _p("pilz_rot")
	r.t(Stil3D.kugel(0.55, 0.34), rot, Vector3(0, 0.86, 0))
	r.ring(0.52, 0.04, rot * 0.85, Vector3(0, 0.78, 0), Vector3.UP, true)
	r.t(Stil3D.zylinder(0.5, 0.5, 0.03, 14), _p("knochen") * 0.85, Vector3(0, 0.745, 0))
	for i in 12:
		var w := TAU * i / 12.0
		r.t(Stil3D.box(0.012, 0.008, 0.24), _p("braun_hell") * 0.8, Vector3(sin(w) * 0.37, 0.728, cos(w) * 0.37),
			Vector3(0, rad_to_deg(w), 0), false)
	for tupf in [[0.0, 40.0, 0.08], [55.0, 55.0, 0.06], [-60.0, 50.0, 0.07], [130.0, 42.0, 0.075],
			[-125.0, 38.0, 0.06], [180.0, 60.0, 0.055], [15.0, 78.0, 0.06]]:
		var az := float(tupf[0]) * GRAD
		var el := float(tupf[1]) * GRAD
		var p := Vector3(sin(az) * cos(el) * 0.55, 0.86 + sin(el) * 0.17, cos(az) * cos(el) * 0.55)
		var n := Vector3(sin(az) * cos(el) / 0.55, sin(el) / 0.17, cos(az) * cos(el) / 0.55)
		r.tb(Stil3D.kugel(float(tupf[2]), float(tupf[2]) * 0.45, 8), _p("weiss"), _zu(n), p, false)
	var licht := _glut(k, _p("seele"), 0.6)
	for lp in [Vector3(0.36, 0.83, 0.33), Vector3(-0.44, 0.84, 0.14), Vector3(0.18, 0.62, -0.25)]:
		r.t(Stil3D.zylinder(0.018, 0.022, 0.06, 6), _p("knochen"), lp)
		r.t(Stil3D.kugel(0.042, 0.032, 8), licht[0], lp + Vector3(0, 0.04, 0), Vector3.ZERO, true,
			maxf(0.6, licht[1]))
	# Gesicht im Stamm
	var glut := _glut(k, _p("seele"), 0.8)
	for s: float in [-1.0, 1.0]:
		r.auge(Vector3(0.1 * s, 0.56, 0.255), 0.07, {"hohl": true, "iris": glut[0], "iris_leuchten": maxf(0.8, glut[1]),
			"seite": s, "hoch": 0.64})
		r.t(Stil3D.box(0.13, 0.036, 0.04), _p("moos"), Vector3(0.1 * s, 0.645, 0.27), Vector3(0, 0, 22.0 * s))
	r.t(Stil3D.kegel(0.042, 0.09, 8), _p("braun_hell"), Vector3(0, 0.48, 0.31), Vector3(90, 0, 0))
	r.t(Stil3D.kugel(0.075, 0.055, 10), _p("schwarz"), Vector3(0, 0.37, 0.27), Vector3.ZERO, false)
	for s: float in [-1.0, 1.0]:
		r.t(Stil3D.kegel(0.014, 0.035, 5), _p("holz_hell"), Vector3(0.025 * s, 0.388, 0.322), Vector3(180, 0, 0), false)
	for i in 3:
		r.t(Stil3D.kegel(0.03, 0.1 - absf(i - 1) * 0.025, 5), _p("moos"), Vector3((i - 1) * 0.05, 0.29, 0.28),
			Vector3(180 - 10, 0, 0), false)
	# Astarme (im Rumpf-Glied): Ast, Unterarm, Wurzelfinger, Zweig mit Blatt;
	# links der Baumschwamm-Schild.
	for s: float in [-1.0, 1.0]:
		var gel := Vector3(0.26 * s, 0.6, 0.0)
		var arm := S.new(pu.glied("arm_l" if s < 0.0 else "arm_r", gel, Vector3.ZERO, "rumpf"), gel)
		var ellbogen := gel + Vector3(0.15 * s, -0.24, 0.04)
		var hand := gel + Vector3(0.19 * s, -0.48, 0.12)
		arm.strebe(gel, ellbogen, 0.07, 0.07, _p("holz"), true, true)
		arm.strebe(ellbogen, hand, 0.06, 0.06, _p("holz"), true, true)
		for i in 3:
			var fd := Vector3((float(i) - 1.0) * 0.4 + 0.15 * s, -1.0, 0.25).normalized()
			arm.tb(Stil3D.kegel(0.028, 0.12, 6), _p("holz_hell"), _zu(fd), hand + fd * 0.07)
		var zweig := gel.lerp(ellbogen, 0.5)
		arm.strebe(zweig, zweig + Vector3(0.1 * s, 0.08, -0.02), 0.012, 0.008, _p("holz"), false)
		arm.tb(Stil3D.kugel(0.04, 0.015, 8), _p("moos"), _zu(Vector3(0.4 * s, 1, 0.3)),
			zweig + Vector3(0.13 * s, 0.11, -0.02), false)
		if s < 0.0:
			var schild := ellbogen.lerp(hand, 0.55) + Vector3(-0.08, 0.0, 0.08)
			var sb := _zu(Vector3(-0.7, 0.0, 1.0))
			arm.tb(Stil3D.kugel(0.2, 0.08, 10), _p("braun_hell"), sb, schild)
			for rr: float in [0.14, 0.08]:
				arm.ring(rr, 0.01, braun, schild + sb * Vector3(0, 0.038, 0), sb * Vector3.UP, false)
	pu.meta("anker_kopf", Vector3(0, 1.04, 0) - rg).meta("anker_kopf_glied", "rumpf")
	pu.meta("anker_ruecken", Vector3(0, 0.6, -0.3) - rg).meta("anker_ruecken_glied", "rumpf")
	pu.meta("brust_y", 0.3).meta("ring_faktor", 1.1)


# --- Mimic -------------------------------------------------------------------------

## Mimic (nur aus Risiko-Truhen): die Risiko-Truhe erwacht — Holzkasten mit
## Goldreifen, Messing-Ecken und -Nieten, Goldschloss, auf vier krummen
## Krallenbeinen; im Maul Zahnreihe, Goldmünzen und ein Edelstein. Glieder:
## der Deckel als Oberkiefer (Ruhe 55° offen) mit Zähnen, Dämonenhörnern,
## Augen und eisernen Brauen-Beschlägen, die heraushängende Zunge.
static func _mimic(pu: Gliederpuppe, k: Dictionary) -> void:
	pu.meta("wippen", 0.02).meta("quetschen", 0.015).meta("drehung", 20.0).meta("hoerner", true)
	var r := S.new(pu.rumpf)
	var gold := _p("gold")
	var horn := _horn(k)
	var boden := 0.14
	var mitte := Vector3(0, boden + 0.16, 0)
	r.t(Stil3D.box(0.62, 0.32, 0.42), _p("holz"), mitte)
	r.t(Stil3D.box(0.64, 0.05, 0.44), _p("holz_hell"), Vector3(0, boden + 0.03, 0), Vector3.ZERO, false)
	for x: float in [-0.2, 0.2]:
		r.t(Stil3D.box(0.065, 0.32, 0.445), gold, Vector3(x, mitte.y, 0), Vector3.ZERO, false)
		for y: float in [0.06, -0.08]:
			r.t(Stil3D.kugel(0.015, -1.0, 6), _p("messing"), Vector3(x, mitte.y + y, 0.226), Vector3.ZERO, false)
	for x: float in [-0.3, 0.3]:
		for z: float in [-0.2, 0.2]:
			r.t(Stil3D.box(0.055, 0.1, 0.055), _p("messing"), Vector3(x, mitte.y + 0.11, z), Vector3.ZERO, false)
	r.t(Stil3D.box(0.14, 0.16, 0.04), gold, Vector3(0, mitte.y - 0.02, 0.225))
	r.t(Stil3D.box(0.03, 0.06, 0.01), _p("nacht"), Vector3(0, mitte.y - 0.03, 0.247), Vector3.ZERO, false)
	# Maul: Boden, untere Zahnreihe, Köder (Münzen, Edelstein)
	var oben := boden + 0.32
	r.t(Stil3D.box(0.56, 0.04, 0.36), _p("mund"), Vector3(0, oben + 0.005, 0), Vector3.ZERO, false)
	for i in 6:
		r.t(Stil3D.kegel(0.03, 0.09, 5), _p("weiss"), Vector3(-0.24 + i * 0.096, oben + 0.05, 0.185), Vector3.ZERO,
			false)
	for s: float in [-1.0, 1.0]:
		for i in 3:
			r.t(Stil3D.kegel(0.026, 0.075, 5), _p("weiss"), Vector3(0.275 * s, oben + 0.045, 0.1 - i * 0.1),
				Vector3.ZERO, false)
	for m in [Vector3(-0.15, 0.03, 0.06), Vector3(-0.08, 0.035, 0.1), Vector3(0.13, 0.03, -0.02),
			Vector3(0.17, 0.035, 0.08)]:
		r.t(Stil3D.zylinder(0.05, 0.05, 0.015, 8), gold, Vector3(m.x, oben + m.y, m.z), Vector3(8, 0, m.x * 60.0),
			false, 0.2)
	r.t(Stil3D.kugel(0.04, 0.05, 8), _p("rosenquarz"), Vector3(0.02, oben + 0.05, -0.08), Vector3(0, 45, 0), false, 0.25)
	# Vier krumme Krallenbeine an den Ecken
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var huefte := Vector3(0.24 * sx, boden + 0.04, 0.15 * sz)
			var knie := Vector3(0.33 * sx, boden + 0.02, 0.22 * sz)
			var fuss := Vector3(0.34 * sx, 0.03, 0.25 * sz)
			r.strebe(huefte, knie, 0.04, 0.04, _p("holz_hell"), true, true)
			r.strebe(knie, fuss, 0.036, 0.036, _p("holz_hell"), true, true)
			for i in 3:
				var kd := Vector3(sx * 0.4 + (i - 1) * 0.45, -0.3, sz * 0.7 + 0.25).normalized()
				r.tb(Stil3D.kegel(0.013, 0.05, 4), _p("knochen"), _zu(kd), fuss + kd * 0.04, false)
	# Deckel = Oberkiefer (Gelenk am Scharnier, Ruhe 55° offen)
	var dg := Vector3(0, oben, -0.21)
	var d := S.new(pu.glied("deckel", dg, Vector3(-55, 0, 0)), dg)
	var achse := Transform3D(Basis(), Vector3(0, oben, 0) - dg)
	d.b.halbzylinder(0.21, 0.62, 10, _p("holz_hell"), achse)
	d.t(Stil3D.box(0.6, 0.02, 0.4), _p("mund") * 0.85, Vector3(0, oben + 0.008, 0), Vector3.ZERO, false)
	for x: float in [-0.2, 0.2]:
		d.b.halbzylinder(0.222, 0.065, 10, gold, achse * Transform3D(Basis(), Vector3(x, 0, 0)), false)
	for i in 6:
		d.t(Stil3D.kegel(0.03, 0.09, 5), _p("weiss"), Vector3(-0.24 + i * 0.096, oben - 0.035, 0.18),
			Vector3(180, 0, 0), false)
	# Hörner (wie die Risiko-Truhe), Augen auf der Vorderkante, Eisenbrauen
	var spitze: Variant = _p("boss_siegel") if k.get("boss", false) else null
	for s: float in [-1.0, 1.0]:
		Gliederpuppe.kette(d.b, Transform3D(Basis.from_euler(Vector3(40, 0, -28.0 * s) * GRAD),
			Vector3(0.17 * s, oben + 0.15, 0.06) - dg), 3, 0.17 * horn, 0.045, 0.012, Vector3(-16, 0, 10.0 * s),
			_p("daemon_dunkel"), spitze, 0.6)
	var blick := Vector3(0, -0.82, 0.57)
	for s: float in [-1.0, 1.0]:
		var ap := Vector3(0.13 * s, oben + 0.05, 0.19)
		d.auge(ap, 0.07, _augen_opt(k, s, _p("glut"), (blick + Vector3(0.12 * s, 0, 0)).normalized()))
		d.t(Stil3D.box(0.12, 0.03, 0.025), _p("eisen"), ap + Vector3(0.0, 0.075, 0.04), Vector3(-30, 0, 22.0 * s))
		d.t(Stil3D.kugel(0.012, -1.0, 6), _p("messing"), ap + Vector3(0.04 * s, 0.063, 0.065), Vector3.ZERO, false)
	# Zunge hängt über die Vorderkante, Sabbertropfen an der Spitze
	var zg := Vector3(0, oben + 0.03, -0.04)
	var zunge := S.new(pu.glied("zunge", zg), zg)
	var zm := Vector3(0, oben + 0.05, 0.16)
	var zende := Vector3(0.02, oben - 0.12, 0.3)
	zunge.strebe(zg, zm, 0.068, 0.068, _p("maehne"), true, true)
	zunge.strebe(zm, zende, 0.062, 0.062, _p("maehne"), true, true)
	zunge.t(Stil3D.box(0.01, 0.006, 0.16), _p("mund"), zg.lerp(zm, 0.5) + Vector3(0, 0.066, 0), Vector3(-10, 0, 0),
		false)
	zunge.t(Stil3D.kugel(0.03, 0.04, 6), _p("schleim_hell"), zende + Vector3(0, -0.075, 0.01), Vector3.ZERO, false, 0.2)
	# Kopf-Anker vor der Deckelkante, gegen die Ruhe-Öffnung gedreht: die
	# Boss-Krone sitzt in Ruhe aufrecht über den Augen und schnappt mit.
	pu.meta("anker_kopf", Vector3(0, 0.14, 0.46)).meta("anker_kopf_glied", "deckel")
	pu.meta("anker_kopf_drehung", Vector3(55, 0, 0))
	pu.meta("anker_ruecken", Vector3(0, mitte.y + 0.06, -0.23))
