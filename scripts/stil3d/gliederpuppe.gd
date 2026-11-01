class_name Gliederpuppe
extends RefCounted
## Figuren 2.0 (STIL-3D.md 7g): eine gebackene Figur mit Gelenken. Alles
## Statische (Beine, Rumpf, Kopf mit Gesicht, Hut, Umhang) ist EIN Rumpf-
## Bausatz, jedes Gelenk (Pivot) ein eigener Bausatz — Arm samt Hand und
## Waffe, Kopf, Kiefer, Flügel, Schwanz, Orbit. Je Teil zwei Zeichenaufrufe
## (Körper + Hülle) statt 20–50 bei Einzel-Grundkörpern.
##
## - Maße im Mesh (massstab): Pivots werden nur gedreht, nie skaliert — die
##   Kontur bleibt bei jeder Figurgröße 0.022 dick.
## - Mesh-Cache je Schlüssel (gebacken()): gleiche Gegner teilen dieselben
##   Meshes, jede Instanz legt nur Nodes an (Blitz-Material bleibt je Figur).
## - Material: Bausatz.figur_meshes (Toon in Weiß, Farbe aus der Vertexfarbe,
##   Leuchten aus Vertex-Alpha) — Gold, Blitz und Overlays greifen wie bei
##   Grundkörper-Figuren.
## - Animation ohne Skript je Figur: beleben() setzt die Glied-Drehungen aus
##   PROFILE (Idle, Gehen, Angriff, Treffer, Phase) — Dungeon, Kampfbühne,
##   Vorschau und Showcase rufen es je Bild für nahe Figuren auf.
##
## Wurzel-Metas: "glieder" (Name » Node3D), "anim" (Profil), "groesse",
## dazu wippen/schwebt/drehung/quetschen wie bei allen Figuren und die Anker
## für Schmuck: "anker_kopf" (Lage im Kopf-Glied bzw. der Wurzel, Glied in
## "anker_kopf_glied") und "anker_ruecken". Jedes Glied trägt Meta "ruhe".

const MAX_GLIEDER := 5
const GRAD := PI / 180.0

var name := "Figur"
var massstab := 1.0
var rumpf: Bausatz
var metas := {}
var _glieder: Array[Dictionary] = []


func _init(figur_name := "Figur", figur_massstab := 1.0) -> void:
	name = figur_name
	massstab = figur_massstab
	rumpf = _bausatz()


func _bausatz() -> Bausatz:
	var b := Bausatz.new()
	b.massstab = massstab
	b.sparsam = true
	return b


## Neues Glied am Gelenkpunkt (Figurmaße in Ruhe, vor massstab). Die Teile
## des gelieferten Bausatzes stehen RELATIV zum Gelenk; eltern = Name eines
## schon angelegten Glieds (verschachtelt, z. B. Kiefer im Kopf). ruhe =
## Ruhedrehung in Grad — die beste Silhouette (Porträt, ferne Figuren).
func glied(glied_name: String, gelenk: Vector3, ruhe_grad := Vector3.ZERO, eltern := "") -> Bausatz:
	assert(_glieder.size() < MAX_GLIEDER, "Gliederpuppe: höchstens %d Glieder" % MAX_GLIEDER)
	var b := _bausatz()
	_glieder.append({"name": glied_name, "gelenk": gelenk, "ruhe": ruhe_grad, "eltern": eltern, "b": b})
	return b


func meta(schluessel: String, wert: Variant) -> Gliederpuppe:
	metas[schluessel] = wert
	return self


func _gelenk(glied_name: String) -> Vector3:
	for g in _glieder:
		if g["name"] == glied_name:
			return g["gelenk"]
	return Vector3.ZERO


## Backt Rumpf und Glieder zu Meshes (einmal je Schlüssel, siehe gebacken()).
func backen() -> Dictionary:
	var m := massstab
	var daten := {"name": name, "metas": metas.duplicate(), "glieder": [], "dreiecke": rumpf.dreiecke(),
		"rumpf": [rumpf.mesh() if not rumpf.ist_leer() else null, rumpf.huelle()]}
	for g in _glieder:
		var pos: Vector3 = g["gelenk"]
		if g["eltern"] != "":
			pos -= _gelenk(g["eltern"])
		var b: Bausatz = g["b"]
		daten["dreiecke"] += b.dreiecke()
		daten["glieder"].append({"name": g["name"], "pos": pos * m, "eltern": g["eltern"],
			"ruhe": (g["ruhe"] as Vector3) * GRAD, "mesh": b.mesh() if not b.ist_leer() else null,
			"huelle": b.huelle()})
	var mm: Dictionary = daten["metas"]
	for anker in ["anker_kopf", "anker_ruecken"]:
		if mm.has(anker):
			mm[anker] = (mm[anker] as Vector3) * m
	mm["groesse"] = float(mm.get("groesse", 1.0)) * m
	return daten


## Nodes aus gebackenen Daten: Wurzel mit Rumpf-Meshes, Pivots am Gelenk.
static func instanz(daten: Dictionary) -> Node3D:
	var wurzel := Node3D.new()
	wurzel.name = daten["name"]
	var mm: Dictionary = daten["metas"]
	for k in mm:
		wurzel.set_meta(k, mm[k])
	var rumpf_daten: Array = daten["rumpf"]
	if rumpf_daten[0] != null:
		Bausatz.figur_meshes(wurzel, rumpf_daten[0], rumpf_daten[1])
	var glieder := {}
	for g in daten["glieder"]:
		var p := Node3D.new()
		p.name = g["name"]
		p.position = g["pos"]
		p.rotation = g["ruhe"]
		p.set_meta("ruhe", g["ruhe"])
		if g["mesh"] != null:
			Bausatz.figur_meshes(p, g["mesh"], g["huelle"])
		var eltern: Node3D = glieder.get(g["eltern"], wurzel)
		eltern.add_child(p)
		glieder[g["name"]] = p
	wurzel.set_meta("glieder", glieder)
	return wurzel


static var _cache: Dictionary = {}


## Figur aus dem Mesh-Cache; bauen() liefert beim ersten Mal die Puppe.
static func gebacken(schluessel: String, bauen: Callable) -> Node3D:
	if not _cache.has(schluessel):
		var puppe: Gliederpuppe = bauen.call()
		_cache[schluessel] = puppe.backen()
	return instanz(_cache[schluessel])


## Gebackene Daten zu einem Schlüssel (Selbsttest: Dreiecke, geteilte Meshes).
static func cache_daten(schluessel: String) -> Dictionary:
	return _cache.get(schluessel, {})


# --- Gesicht -----------------------------------------------------------------

static func _p(n: String) -> Color:
	return Stil3D.farbe(n)


## Cartoon-Auge: Augapfel (leicht hochoval), optional Iris in Palettenfarbe,
## Pupille in Blickrichtung und Glanzpunkt oben außen — alles ohne Hülle.
## Optionen: iris (Color), iris_leuchten (0..1), pupille ("rund"/"schlitz"/
## "keine"), hohl (dunkle Höhle mit leuchtender Pupille: Untote, Konstrukte,
## Kapuzenlöcher), weiss, blick, seite (-1 links / +1 rechts, Glanz nach
## außen), hoch (Höhenfaktor, < 1 = schmale Augen), glanz (false = ohne).
static func auge(b: Bausatz, pos: Vector3, r: float, o := {}) -> void:
	var blick: Vector3 = (o.get("blick", Vector3(0, 0, 1)) as Vector3).normalized()
	var seite: float = o.get("seite", 1.0)
	var hoch: float = o.get("hoch", 1.12)
	var quer := Vector3.UP.cross(blick).normalized()
	var iris: Variant = o.get("iris", null)
	var art: String = o.get("pupille", "rund")
	var flach := minf(1.0, hoch)
	if o.get("hohl", false):
		b.teil(Stil3D.kugel(r, r * 2.0 * hoch, 10), _p("schwarz"), pos, Vector3.ZERO, false)
		var glut: Color = iris if iris != null else _p("seele")
		var rg := r * 0.5
		b.teil(Stil3D.kugel(rg, rg * 2.0 * flach, 10), glut, pos + blick * r * 0.62, Vector3.ZERO, false,
			float(o.get("iris_leuchten", 0.9)))
		if art == "schlitz":
			b.teil(Stil3D.box(rg * 0.35, rg * 1.8 * flach, rg * 0.4), _p("schwarz"), pos + blick * r * 1.08,
				Vector3.ZERO, false)
	else:
		b.teil(Stil3D.kugel(r, r * 2.0 * hoch, 10), o.get("weiss", _p("weiss")), pos, Vector3.ZERO,
			bool(o.get("kontur", false)))
		var rp := r * 0.56
		var tiefe_p := 1.1 * r - rp
		if iris != null:
			var ri := r * 0.66
			b.teil(Stil3D.kugel(ri, ri * 2.0 * flach, 8), iris, pos + blick * (1.06 * r - ri), Vector3.ZERO,
				false, float(o.get("iris_leuchten", 0.0)))
			rp = r * 0.34
			tiefe_p = 1.13 * r - rp
		if art == "schlitz":
			b.teil(Stil3D.box(rp * 0.5, rp * 2.4 * flach, rp * 0.6), _p("schwarz"), pos + blick * (tiefe_p + rp * 0.5),
				Vector3.ZERO, false)
		elif art != "keine":
			b.teil(Stil3D.kugel(rp, rp * 2.0 * flach, 8), _p("schwarz"), pos + blick * tiefe_p, Vector3.ZERO, false)
	if o.get("glanz", true):
		var rg := r * 0.25
		b.teil(Stil3D.kugel(rg, -1.0, 6), _p("weiss"),
			pos + blick * r * 0.96 + Vector3.UP * r * 0.28 * flach + quer * r * 0.26 * seite,
			Vector3.ZERO, false, 0.5)


## Augenbraue über einem Auge: winkel > 0 = böse (innen tief), < 0 =
## besorgt (innen hoch); seite -1 = linkes Auge (x < 0), +1 = rechtes.
static func braue(b: Bausatz, pos: Vector3, breite: float, seite: float, winkel := 22.0,
		farbe := Color("1b1a24"), kontur := false) -> void:
	b.teil(Stil3D.box(breite, breite * 0.26, breite * 0.32), farbe, pos, Vector3(0, 0, winkel * seite), kontur)


## Mund: "strich", "laecheln" (drei Boxen), "o" (offen), "grinsen" (breit,
## Zahnreihe oben), "fies" (Zahnreihe aus Knochen-Boxen), "unterbiss"
## (zwei Hauer nach oben). Optionen: farbe, zaehne (Anzahl), zahn
## (Farbe), hauer (Länge), hauer_farbe, hauer_leuchten.
static func mund(b: Bausatz, pos: Vector3, breite: float, art := "strich", o := {}) -> void:
	var farbe: Color = o.get("farbe", _p("mund"))
	var h := breite * 0.24
	match art:
		"laecheln":
			b.teil(Stil3D.box(breite * 0.56, h, h), farbe, pos, Vector3.ZERO, false)
			for s in [-1.0, 1.0]:
				b.teil(Stil3D.box(breite * 0.3, h, h), farbe, pos + Vector3(breite * 0.36 * s, breite * 0.07, 0),
					Vector3(0, 0, 28.0 * s), false)
		"o":
			b.teil(Stil3D.kugel(breite * 0.45, breite * 0.7, 12), farbe, pos, Vector3.ZERO, false)
		"grinsen", "fies":
			b.teil(Stil3D.box(breite, h * 1.6, h), farbe, pos, Vector3.ZERO, false)
			var n: int = o.get("zaehne", 5 if art == "grinsen" else 4)
			var zahn: Color = o.get("zahn", _p("weiss") if art == "grinsen" else _p("knochen"))
			for i in n:
				var x := (float(i) - (n - 1) * 0.5) * breite / n
				b.teil(Stil3D.box(breite / n * 0.7, h * 0.7, h * 0.5), zahn,
					pos + Vector3(x, h * 0.45, h * 0.3), Vector3.ZERO, false)
		"unterbiss":
			b.teil(Stil3D.box(breite, h, h), farbe, pos, Vector3.ZERO, false)
		_:
			b.teil(Stil3D.box(breite, h, h), farbe, pos, Vector3.ZERO, false)
	if o.has("hauer"):
		var l: float = o["hauer"]
		for s in [-1.0, 1.0]:
			b.teil(Stil3D.kegel(l * 0.32, l, 6), o.get("hauer_farbe", _p("knochen")),
				pos + Vector3(breite * 0.36 * s, l * 0.45, h * 0.4), Vector3(0, 0, -8.0 * s), false,
				float(o.get("hauer_leuchten", 0.0)))


## Rosige Wangen-Tupfer (Helden, Niedliche): flach, ohne Hülle.
static func wangen(b: Bausatz, mitte: Vector3, abstand: float, r := 0.025) -> void:
	for s in [-1.0, 1.0]:
		b.teil(Stil3D.kugel(r, r * 0.9, 8), _p("rosenquarz"), mitte + Vector3(abstand * s, 0, 0), Vector3.ZERO, false)


# --- Gliedmaßen, Waffen, Ketten, Kronen ----------------------------------------

## Arm im Glied-Bausatz (Ursprung = Schultergelenk), hängt in Ruhe nach -Y:
## Kapsel plus Hand-Kugel am Ende. Liefert die Handmitte (relativ zum Gelenk)
## — Waffengriffe gehen immer DURCH diese Kugel.
static func arm(b: Bausatz, laenge: float, r: float, farbe: Color, hand_farbe: Color, hand_r: float) -> Vector3:
	b.teil(Stil3D.kapsel(r, laenge, 8), farbe, Vector3(0, -laenge * 0.5 + r * 0.6, 0))
	var hand := Vector3(0, -laenge + r * 0.4, 0)
	b.teil(Stil3D.kugel(hand_r, -1.0, 10), hand_farbe, hand)
	return hand


## Bein im Glied-Bausatz (Ursprung = Hüftgelenk) bzw. gebacken im Rumpf
## (ursprung = Hüfte in Figurmaßen): Kapsel nach -Y plus Stiefel/Fuß (Kapsel
## liegend, Spitze nach +Z). Beine sind normalerweise gebacken — Gehen zeigen
## Wurzel-Rollen und Armschwung; ein Glied "bein_l"/"bein_r" lohnt nur bei
## Sonderbau (Hufbeine, Krallenfüße), PROFILE kennt sie trotzdem.
static func bein(b: Bausatz, ursprung: Vector3, laenge: float, r: float, farbe: Color, fuss_farbe: Color,
		fuss_r := -1.0) -> Vector3:
	b.teil(Stil3D.kapsel(r, laenge, 10), farbe, ursprung + Vector3(0, -laenge * 0.5 + r * 0.5, 0))
	var fr := fuss_r if fuss_r > 0.0 else r * 1.1
	var fuss := ursprung + Vector3(0, -laenge + fr * 0.6, fr * 0.5)
	b.teil(Stil3D.kapsel(fr, fr * 3.2, 10), fuss_farbe, fuss, Vector3(90, 0, 0))
	return fuss


## Lage eines Griffs in der Hand: Ursprung = Handmitte, +Y = Richtung der
## Waffe (Klinge, Stab, Keulenkopf), neigung in Grad (x vor, z seitlich).
static func griff(hand: Vector3, neigung_grad: Vector3) -> Transform3D:
	return Transform3D(Basis.from_euler(neigung_grad * GRAD), hand)


## Waffe an der Hand (t aus griff()): "schwert", "dolch", "stab", "keule",
## "baumkeule", "axt", "schild_rund" (Schild vor dem Unterarm, +Z = außen).
## Optionen: farbe (Klinge/Kopf), licht (Stablicht), leuchten, boss.
static func waffe(b: Bausatz, art: String, t: Transform3D, o := {}) -> void:
	var gold := _p("gold")
	match art:
		"schwert", "dolch":
			var l := 0.46 if art == "schwert" else 0.2
			var klinge: Color = o.get("farbe", _p("weiss"))
			b.teil_t(Stil3D.zylinder(0.022, 0.022, 0.13, 8), _p("leder"), t)
			b.teil_t(Stil3D.box(0.16 if art == "schwert" else 0.08, 0.035, 0.05), gold,
				t * Transform3D(Basis(), Vector3(0, 0.08, 0)))
			b.teil_t(Stil3D.box(0.05, l, 0.018), klinge, t * Transform3D(Basis(), Vector3(0, 0.1 + l * 0.5, 0)))
			b.teil_t(Stil3D.box(0.012, l * 0.9, 0.022), klinge * 0.82,
				t * Transform3D(Basis(), Vector3(0, 0.1 + l * 0.48, 0)), false)
			b.teil_t(Stil3D.kugel(0.03, -1.0, 10), gold, t * Transform3D(Basis(), Vector3(0, -0.08, 0)))
		"stab":
			var licht: Color = o.get("licht", _p("kristall"))
			b.teil_t(Stil3D.zylinder(0.022, 0.026, 1.0, 8), _p("holz"), t * Transform3D(Basis(), Vector3(0, 0.25, 0)))
			b.teil_t(Stil3D.kugel(0.07, -1.0, 14), licht, t * Transform3D(Basis(), Vector3(0, 0.8, 0)), true,
				float(o.get("leuchten", 0.8)))
		"keule", "baumkeule":
			var dick := 0.11 if art == "baumkeule" else 0.08
			var l := 0.7 if art == "baumkeule" else 0.5
			var unten := -0.05  # Griffende bleibt in der Faust (ragt nicht unten heraus)
			b.teil_t(Stil3D.zylinder(dick, dick * 0.55, l, 10), _p("holz"),
				t * Transform3D(Basis(), Vector3(0, l * 0.5 + unten, 0)))
			var ring_y := l * 0.62 + unten
			b.teil_t(Stil3D.zylinder(dick * 0.96, dick * 0.92, 0.045, 10), _p("eisen"),
				t * Transform3D(Basis(), Vector3(0, ring_y, 0)), false)
			for i in 5:
				var w := TAU * i / 5.0
				var r_kopf := dick * 0.95
				b.teil_t(Stil3D.kugel(0.026, -1.0, 6), _p("eisen") * 1.15, t * Transform3D(Basis(),
					Vector3(sin(w) * r_kopf, l * 0.82 + unten + (i % 2) * 0.06, cos(w) * r_kopf)), false)
		"axt":
			b.teil_t(Stil3D.zylinder(0.024, 0.028, 0.62, 8), _p("holz"), t * Transform3D(Basis(), Vector3(0, 0.2, 0)))
			b.teil_t(Stil3D.prisma(0.22, 0.18, 0.04), _p("eisen"),
				t * Transform3D(Basis.from_euler(Vector3(0, 0, -90) * GRAD), Vector3(0.1, 0.42, 0)))
		"schild_rund":
			var farbe: Color = o.get("farbe", _p("ruestung_dunkel"))
			var scheibe := t * Transform3D(Basis.from_euler(Vector3(90, 0, 0) * GRAD), Vector3.ZERO)
			b.teil_t(Stil3D.zylinder(0.2, 0.2, 0.045, 18), farbe, scheibe)
			b.teil_t(Stil3D.zylinder(0.215, 0.215, 0.035, 18), _p("messing"),
				scheibe * Transform3D(Basis(), Vector3(0, -0.006, 0)), false)
			b.teil_t(Stil3D.kugel(0.05, -1.0, 10), gold, t * Transform3D(Basis(), Vector3(0, 0, 0.03)), false)


## Gebogene Kette aus Kegelstumpf-Segmenten (Hörner, Geweihstangen, Kamm-
## Zacken, Kronenspitzen): beginnt bei t (Ursprung, +Y = Startrichtung),
## jedes Segment knickt um biegung (Grad) gegenüber dem vorigen. Das letzte
## Segment läuft spitz aus und trägt optional spitze (Farbe) + Leuchten.
static func kette(b: Bausatz, t: Transform3D, segmente: int, laenge: float, r0: float, r1: float,
		biegung_grad: Vector3, farbe: Color, spitze: Variant = null, spitze_leuchten := 0.0,
		kontur := true) -> void:
	var lage := t
	var seg := laenge / segmente
	var knick := Basis.from_euler(biegung_grad * GRAD)
	for i in segmente:
		var ra := lerpf(r0, r1, float(i) / segmente)
		var rb := lerpf(r0, r1, float(i + 1) / segmente)
		var letzte := i == segmente - 1
		var m := Stil3D.zylinder(0.0 if letzte else rb, ra, seg * 1.12, 10)
		var c: Color = spitze if letzte and spitze != null else farbe
		b.teil_t(m, c, lage * Transform3D(Basis(), Vector3(0, seg * 0.5, 0)), kontur,
			spitze_leuchten if letzte else 0.0)
		lage = lage * Transform3D(knick, Vector3(0, seg, 0))


## Krone bei t (Ursprung = Unterkante, +Y = oben): Reif, zacken Spitzen mit
## Steinen (stein, leuchten), optional ein großer Mittelstein vorn.
static func krone(b: Bausatz, t: Transform3D, r: float, zacken := 5, farbe := Color("e8b44a"),
		stein := Color("9a1f2c"), stein_leuchten := 0.3, mittelstein: Variant = null) -> void:
	var reif_h := r * 0.55
	b.teil_t(Stil3D.zylinder(r, r * 0.92, reif_h, 16), farbe, t * Transform3D(Basis(), Vector3(0, reif_h * 0.5, 0)))
	for i in zacken:
		var w := TAU * i / zacken
		var fuss := Vector3(sin(w) * r * 0.82, reif_h, cos(w) * r * 0.82)
		var neig := Basis.from_euler(Vector3(cos(w) * 8.0, 0, -sin(w) * 8.0) * GRAD)
		var spitze_h := r * 0.8
		b.teil_t(Stil3D.kegel(r * 0.28, spitze_h, 8), farbe,
			t * Transform3D(neig, fuss + neig * Vector3(0, spitze_h * 0.42, 0)), false)
		b.teil_t(Stil3D.kugel(r * 0.13, -1.0, 8), stein,
			t * Transform3D(Basis(), fuss + neig * Vector3(0, spitze_h * 0.98, 0)), false, stein_leuchten)
	if mittelstein != null:
		b.teil_t(Stil3D.kugel(r * 0.2, r * 0.26, 10), mittelstein, t * Transform3D(Basis(),
			Vector3(0, reif_h * 0.5, r * 0.95)), false, maxf(stein_leuchten, 0.4))


# --- Animation -----------------------------------------------------------------

## Animations-Profile je Archetyp-Typ (Meta "anim" der Figur), je Glied:
##   "idle"/"geh": [achse (0 x, 1 y, 2 z), Amplitude °, Hz, Phase rad, Form 0 sin / 1 |sin|]
##   "angriff"/"treffer"/"phase": Schlüsselbilder [[t s, Vector3 °], …] relativ
##   zur Ruhe — erstes und letztes Bild 0 (die Pose kehrt in die Ruhe zurück).
## Glied "wurzel" wird nicht gesetzt, sondern zurückgegeben (Euler-Versatz,
## den Bühne bzw. Dungeon auf die Wurzel-Drehung legen). Drehsinn x: negativ
## = Arm nach vorn/oben (−90° waagrecht nach vorn), positiv = nach hinten.
## Neue Gruppen tragen hier ihr Profil ein (z. B. "vierbeiner", "schleim").
const PROFILE := {
	"zweibeiner": {
		"arm_r": {"idle": [0, 4.0, 0.9, 0.0, 0], "geh": [0, 18.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.18, Vector3(-110, 0, 0)], [0.26, Vector3(30, 0, 0)],
				[0.45, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-25, 0, 12)], [0.4, Vector3.ZERO]]},
		"arm_l": {"idle": [0, 3.0, 0.9, PI, 0], "geh": [0, 18.0, 2.2, PI, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-25, 0, 0)], [0.45, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-60, 0, 0)], [0.4, Vector3.ZERO]]},
		"kopf": {"idle": [1, 6.0, 0.3, 0.0, 0],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, 0)], [0.4, Vector3.ZERO]]},
		"kiefer": {"idle": [0, 6.0, 1.5, 0.0, 1],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(25, 0, 0)], [0.45, Vector3.ZERO]]},
		# Optionale Glieder (nur wirksam, wenn die Figur sie hat): Sonderbeine,
		# Schwanz (Imp, Dämonenfürst), Flügel (gefaltet zucken, Phase: spreizen).
		"bein_l": {"geh": [0, 22.0, 2.2, PI, 0]},
		"bein_r": {"geh": [0, 22.0, 2.2, 0.0, 0]},
		"schwanz": {"idle": [1, 20.0, 1.2, 0.0, 0]},
		"fluegel_l": {"idle": [2, 4.0, 0.8, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(0, 0, 45)], [0.45, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(0, 0, 55)], [0.9, Vector3(0, 0, 55)], [1.3, Vector3.ZERO]]},
		"fluegel_r": {"idle": [2, -4.0, 0.8, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(0, 0, -45)], [0.45, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(0, 0, -55)], [0.9, Vector3(0, 0, -55)], [1.3, Vector3.ZERO]]},
		"wurzel": {"geh": [2, 4.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.22, Vector3(8, 0, 0)], [0.45, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-10, 0, 0)], [0.9, Vector3(-10, 0, 0)], [1.3, Vector3.ZERO]]},
	},
	# Troll: Baumkeule aufrecht vor der Schulter (Ruhe arm_r −108°), Überkopfschlag
	# auf den Boden, schweres Atmen; die freie Faust pendelt.
	"troll": {
		"arm_r": {"idle": [0, 3.0, 0.7, 0.0, 0], "geh": [0, 8.0, 1.8, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.24, Vector3(-77, 0, 6)], [0.3, Vector3(-77, 0, 6)],
				[0.38, Vector3(78, 0, 0)], [0.6, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-12, 0, 0)], [0.4, Vector3.ZERO]]},
		"arm_l": {"idle": [0, 6.0, 0.7, PI, 0], "geh": [0, 16.0, 1.8, PI, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.24, Vector3(-30, 0, -10)], [0.38, Vector3(-60, 0, 0)],
				[0.6, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-70, 0, 10)], [0.45, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-120, 0, -25)], [0.9, Vector3(-120, 0, -25)],
				[1.3, Vector3.ZERO]]},
		"wurzel": {"idle": [0, 2.0, 0.7, 0.0, 0], "geh": [2, 5.0, 1.8, 0.0, 0],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-12, 0, 0)], [0.9, Vector3(-12, 0, 0)], [1.3, Vector3.ZERO]],
			"angriff": [[0.0, Vector3.ZERO], [0.24, Vector3(-6, 0, 0)], [0.38, Vector3(10, 0, 0)],
				[0.6, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.06, Vector3(-6, 0, 5)], [0.16, Vector3(-3, 0, -5)],
				[0.4, Vector3.ZERO]]},
	},
	"vierbeiner": {
		"kopf": {"idle": [1, 12.0, 0.35, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.1, Vector3(-10, 0, 0)], [0.2, Vector3(15, 0, 0)],
				[0.4, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-20, 0, 0)], [0.4, Vector3.ZERO]]},
		"kiefer": {"idle": [0, 6.0, 2.0, 0.0, 1],
			"angriff": [[0.0, Vector3.ZERO], [0.12, Vector3(30, 0, 0)], [0.2, Vector3.ZERO], [0.4, Vector3.ZERO]]},
		"schwanz": {"idle": [1, 10.0, 1.5, 0.0, 0], "geh": [1, 18.0, 3.0, 0.0, 0]},
		"wurzel": {"angriff": [[0.0, Vector3.ZERO], [0.1, Vector3(-8, 0, 0)], [0.2, Vector3(6, 0, 0)],
			[0.4, Vector3.ZERO]]},
	},
	"schleim": {
		"zipfel": {"idle": [2, 12.0, 0.48, 0.6, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(30, 0, 0)], [0.4, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.06, Vector3(0, 0, 20)], [0.14, Vector3(0, 0, -15)],
				[0.4, Vector3.ZERO]]},
	},
	"flieger": {
		"fluegel_l": {"idle": [2, 32.0, 6.0, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.12, Vector3(0, 50, -10)], [0.24, Vector3(0, 0, 40)],
				[0.4, Vector3.ZERO]]},
		"fluegel_r": {"idle": [2, -32.0, 6.0, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.12, Vector3(0, -50, 10)], [0.24, Vector3(0, 0, -40)],
				[0.4, Vector3.ZERO]]},
	},
	"krabbler": {
		"beine_a": {"idle": [1, 4.0, 3.2, 0.0, 0]},
		"beine_b": {"idle": [1, -4.0, 3.2, 0.0, 0]},
		"koerper": {"idle": [0, 3.0, 1.1, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(-28, 0, 0)], [0.25, Vector3(18, 0, 0)],
				[0.4, Vector3.ZERO]]},
	},
}


## Belebt eine Gliederpuppe: setzt jedes Glied auf Ruhe + Idle/Gehen +
## Angriff + Treffer + Phase und liefert den Euler-Versatz der Wurzel
## (Bogenmaß). zeit < 0 = ohne Idle; aktion_t/treffer_t/phase_t = Sekunden
## seit Beginn (< 0 = aus). Reine Funktion ohne Allokation je Bild.
static func beleben(fig: Node3D, zeit: float, aktion_t := -1.0, treffer_t := -1.0, geht := false,
		phase_t := -1.0) -> Vector3:
	var profil: Dictionary = PROFILE.get(String(fig.get_meta("anim", "")), {})
	var glieder: Dictionary = fig.get_meta("glieder", {})
	var wurzel := Vector3.ZERO
	for glied_name in profil:
		var grad := _versatz(profil[glied_name], zeit, aktion_t, treffer_t, geht, phase_t)
		if glied_name == "wurzel":
			wurzel = grad * GRAD
			continue
		var g: Node3D = glieder.get(glied_name)
		if g != null:
			g.rotation = (g.get_meta("ruhe") as Vector3) + grad * GRAD
	return wurzel


## Ein Bild Kampfbühne (und Koop-Gast, gleiche Bühne): e = Eintrag mit
## "aktion", "treffer_t", "phase_t" (Sekunden seit Start, < 0 = aus) und
## "puls_alt". Der Angriff startet an der steigenden Flanke des Platzhalter-
## Pulses (puls > 1.02), Treffer/Phase setzt die Bühne auf 0. Nach 3 s
## erlischt ein Ereignis. Liefert den Euler-Versatz der Wurzel.
static func kampf_takt(e: Dictionary, fig: Node3D, zeit: float, puls: float, delta: float) -> Vector3:
	if puls > 1.02 and float(e.get("puls_alt", 1.0)) <= 1.02:
		e["aktion"] = 0.0
	e["puls_alt"] = puls
	return beleben(fig, zeit, _uhr(e, "aktion", delta), _uhr(e, "treffer_t", delta), false,
		_uhr(e, "phase_t", delta))


static func _uhr(e: Dictionary, art: String, delta: float) -> float:
	var t := float(e.get(art, -1.0))
	if t < 0.0:
		return -1.0
	t += delta
	e[art] = t if t < 3.0 else -1.0
	return t


## Alle Glieder zurück in die Ruhepose (ferne Figuren, Porträt).
static func ruhe(fig: Node3D) -> void:
	var glieder: Dictionary = fig.get_meta("glieder", {})
	for glied_name in glieder:
		var g: Node3D = glieder[glied_name]
		g.rotation = g.get_meta("ruhe")


## Dauer der Angriffs-Animation eines Profils (längstes Glied).
static func dauer(anim: String, art := "angriff") -> float:
	var ende := 0.0
	var profil: Dictionary = PROFILE.get(anim, {})
	for glied_name in profil:
		var eintrag: Dictionary = profil[glied_name]
		if eintrag.has(art):
			var keys: Array = eintrag[art]
			ende = maxf(ende, float(keys[keys.size() - 1][0]))
	return ende


static func _versatz(eintrag: Dictionary, zeit: float, aktion_t: float, treffer_t: float, geht: bool,
		phase_t: float) -> Vector3:
	var v := Vector3.ZERO
	if zeit >= 0.0:
		var welle: Variant = eintrag.get("geh") if geht and eintrag.has("geh") else eintrag.get("idle")
		if welle != null:
			var w: Array = welle
			var s := sin(zeit * TAU * float(w[2]) + float(w[3]))
			if int(w[4]) == 1:
				s = absf(s)
			v[int(w[0])] = s * float(w[1])
	if aktion_t >= 0.0 and eintrag.has("angriff"):
		v += _schluessel(eintrag["angriff"], aktion_t)
	if treffer_t >= 0.0 and eintrag.has("treffer"):
		v += _schluessel(eintrag["treffer"], treffer_t)
	if phase_t >= 0.0 and eintrag.has("phase"):
		v += _schluessel(eintrag["phase"], phase_t)
	return v


## Schlüsselbild-Interpolation (smoothstep zwischen zwei Bildern).
static func _schluessel(keys: Array, t: float) -> Vector3:
	var n := keys.size()
	if n == 0 or t >= float(keys[n - 1][0]):
		return Vector3.ZERO
	for i in n - 1:
		var a: float = keys[i][0]
		var b: float = keys[i + 1][0]
		if t < b:
			var u := smoothstep(0.0, 1.0, (t - a) / maxf(0.0001, b - a))
			return (keys[i][1] as Vector3).lerp(keys[i + 1][1], u)
	return Vector3.ZERO
