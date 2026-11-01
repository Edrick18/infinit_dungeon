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


## Leerer Bausatz mit Maßstab und Sparsamkeit der Puppe (z. B. Oberkörper,
## der erst gekippt in den Rumpf kommt, siehe uebernehmen).
func teilsatz() -> Bausatz:
	return _bausatz()


## Einen Teil-Bausatz (Figurmaße) mit Lage t in den Rumpf übernehmen — so
## kippt ein vorgebeugter Oberkörper um die Hüfte, ohne Node-Drehung.
func uebernehmen(quelle: Bausatz, t: Transform3D) -> void:
	rumpf.bausatz(quelle, Transform3D(t.basis, t.origin * massstab))


func meta(schluessel: String, wert: Variant) -> Gliederpuppe:
	metas[schluessel] = wert
	return self


func _gelenk(glied_name: String) -> Vector3:
	for g in _glieder:
		if g["name"] == glied_name:
			return g["gelenk"]
	return Vector3.ZERO


func _ruhe(glied_name: String) -> Vector3:
	for g in _glieder:
		if g["name"] == glied_name:
			return g["ruhe"]
	return Vector3.ZERO


## Backt Rumpf und Glieder zu Meshes (einmal je Schlüssel, siehe gebacken()).
func backen() -> Dictionary:
	var m := massstab
	var daten := {"name": name, "metas": metas.duplicate(), "glieder": [], "dreiecke": rumpf.dreiecke(),
		"rumpf": [rumpf.mesh() if not rumpf.ist_leer() else null, rumpf.huelle()]}
	for g in _glieder:
		var pos: Vector3 = g["gelenk"]
		if g["eltern"] != "":
			# Lage im (in Ruhe gedrehten) Eltern-Glied: Kristall im Haken des
			# Krummstabs sitzt so auch bei gehobenem Arm am richtigen Fleck.
			pos = Basis.from_euler(_ruhe(g["eltern"]) * GRAD).inverse() * (pos - _gelenk(g["eltern"]))
		var b: Bausatz = g["b"]
		daten["dreiecke"] += b.dreiecke()
		daten["glieder"].append({"name": g["name"], "pos": pos * m, "eltern": g["eltern"],
			"ruhe": (g["ruhe"] as Vector3) * GRAD, "mesh": b.mesh() if not b.ist_leer() else null,
			"huelle": b.huelle()})
	var mm: Dictionary = daten["metas"]
	for anker in ["anker_kopf", "anker_ruecken", "brust_y"]:
		if mm.has(anker):
			mm[anker] = mm[anker] * m
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
##   "idle"/"geh": [achse (0 x, 1 y, 2 z), Amplitude °, Hz, Phase rad, Form 0 sin / 1 |sin|
##   / 2 Dauerdrehung (Amplitude = Grad je Sekunde: Orbit, Kristall) / 3 Stoß
##   (alle w[5] s für w[6] s eine Welle mit Hüllkurve: Schnüffeln, Scharren;
##   Phase = Zeitversatz in s) / 4 Ruck-Scan (−1, 0, +1, 0 je 1/Hz s: Jagdblick)]
##   "angriff"/"treffer"/"phase": Schlüsselbilder [[t s, Vector3 °], …] relativ
##   zur Ruhe — erstes und letztes Bild 0 (die Pose kehrt in die Ruhe zurück).
## Glied "wurzel" wird nicht gesetzt, sondern zurückgegeben (Euler-Versatz,
## den Bühne bzw. Dungeon auf die Wurzel-Drehung legen); "hub" = [Anheben,
## Quer-, Hoch-Skalierung] der Wurzel (hub_anwenden, nur Kampf und Showcase).
## Drehsinn x: negativ = Arm nach vorn/oben (−90° waagrecht nach vorn),
## positiv = nach hinten. Neue Gruppen tragen hier ihr Profil ein.
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
	# --- Helden (ZweibeinerBau, Profil nach Waffe) --------------------------------
	# Einhand (Schwert, Axt, Keule; Tank mit Schild): Ausholen über die
	# Schulter, Diagonalschlag nach vorn-unten, der Schild stößt mit vor.
	"held_einhand": {
		"arm_r": {"idle": [0, 4.0, 0.9, 0.0, 0], "geh": [0, 18.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.18, Vector3(-125, 0, -10)], [0.26, Vector3(68, 0, 10)],
				[0.45, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-20, 0, 12)], [0.4, Vector3.ZERO]]},
		"arm_l": {"idle": [0, 2.0, 0.9, PI, 0], "geh": [0, 18.0, 2.2, PI, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-12, 0, 0)], [0.45, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-55, 0, 0)], [0.4, Vector3.ZERO]]},
		"wurzel": {"geh": [2, 4.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.18, Vector3(-4, 0, 0)], [0.26, Vector3(8, 0, 0)], [0.45, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	# Zweihand (Großschwert, Großaxt, Hammer): weiter Überkopfschwung mit
	# kurzem Halten oben, beide Arme gemeinsam.
	"held_zweihand": {
		"arm_r": {"idle": [0, 3.0, 0.8, 0.0, 0], "geh": [0, 10.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-120, 0, 0)], [0.27, Vector3(-120, 0, 0)],
				[0.36, Vector3(55, 0, 0)], [0.6, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, 10)], [0.4, Vector3.ZERO]]},
		"arm_l": {"idle": [0, 3.0, 0.8, 0.0, 0], "geh": [0, 10.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-110, 0, 0)], [0.27, Vector3(-110, 0, 0)],
				[0.36, Vector3(50, 0, 0)], [0.6, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, -10)], [0.4, Vector3.ZERO]]},
		"wurzel": {"geh": [2, 4.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.22, Vector3(-6, 0, 0)], [0.36, Vector3(10, 0, 0)], [0.6, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	# Zwei Dolche: Tänzeln, Doppelstich links-rechts.
	"held_dolche": {
		"arm_r": {"idle": [1, 10.0, 1.6, 0.0, 0], "geh": [0, 18.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.12, Vector3(12, 0, 0)], [0.24, Vector3(-78, 0, -8)], [0.38, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-30, 0, 15)], [0.4, Vector3.ZERO]]},
		"arm_l": {"idle": [1, -10.0, 1.6, 0.0, 0], "geh": [0, 18.0, 2.2, PI, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.12, Vector3(-78, 0, 8)], [0.24, Vector3(10, 0, 0)], [0.38, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-30, 0, -15)], [0.4, Vector3.ZERO]]},
		"wurzel": {"idle": [2, 4.0, 1.6, 0.0, 0], "geh": [2, 5.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.12, Vector3(6, 0, 0)], [0.38, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	# Bogen: Bogenarm streckt nach vorn, Zugarm zieht zurück und lässt los.
	"held_bogen": {
		"arm_l": {"idle": [0, 3.0, 0.8, 0.0, 0], "geh": [0, 12.0, 2.2, PI, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(-32, 0, 8)], [0.42, Vector3(-32, 0, 8)], [0.6, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-25, 0, 0)], [0.4, Vector3.ZERO]]},
		"arm_r": {"idle": [0, 3.0, 0.8, PI, 0], "geh": [0, 18.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(-80, 45, 0)], [0.3, Vector3(-80, 45, 0)],
				[0.34, Vector3(-70, 60, 10)], [0.6, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-20, 0, 12)], [0.4, Vector3.ZERO]]},
		"wurzel": {"geh": [2, 4.0, 2.2, 0.0, 0],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	# Armbrust: beidhändig anlegen, kurzer Rückstoß.
	"held_armbrust": {
		"arm_r": {"idle": [0, 2.0, 0.8, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.14, Vector3(-14, 0, 0)], [0.3, Vector3(-14, 0, 0)],
				[0.34, Vector3(-2, 0, 0)], [0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, 10)], [0.4, Vector3.ZERO]]},
		"arm_l": {"idle": [0, 2.0, 0.8, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.14, Vector3(-14, 0, 0)], [0.3, Vector3(-14, 0, 0)],
				[0.34, Vector3(-2, 0, 0)], [0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, -10)], [0.4, Vector3.ZERO]]},
		"wurzel": {"geh": [2, 4.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.3, Vector3.ZERO], [0.34, Vector3(-6, 0, 0)], [0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	# Turmschild: Schild-Ramme nach vorn.
	"held_turm": {
		"arm_l": {"idle": [0, 2.0, 0.8, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(12, 0, 0)], [0.25, Vector3(-32, 0, 0)], [0.45, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-18, 0, 0)], [0.4, Vector3.ZERO]]},
		"arm_r": {"idle": [0, 4.0, 0.9, 0.0, 0], "geh": [0, 18.0, 2.2, 0.0, 0]},
		"wurzel": {"geh": [2, 4.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(-4, 0, 0)], [0.25, Vector3(10, 0, 0)], [0.45, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-5, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	# Magier: Fokus-Hand kreist, Stab über den Kopf und Stoß nach vorn.
	"held_stab": {
		"arm_l": {"idle": [0, 8.0, 0.7, 0.0, 0], "geh": [0, 14.0, 2.2, PI, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-20, 0, 0)], [0.28, Vector3(-50, 0, 10)], [0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-30, 0, 0)], [0.4, Vector3.ZERO]]},
		"arm_r": {"idle": [2, 3.0, 0.5, 0.0, 0], "geh": [0, 10.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-15, 0, 45)], [0.28, Vector3(30, 0, 5)], [0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, 12)], [0.4, Vector3.ZERO]]},
		"wurzel": {"geh": [2, 4.0, 2.2, 0.0, 0],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	# Heiler: segnende Hand, sanftes Wiegen; Zauber = beide Arme hoch, halten.
	"held_heiler": {
		"arm_l": {"idle": [2, 4.0, 0.5, 0.0, 0], "geh": [0, 10.0, 2.2, PI, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.22, Vector3(-100, 0, -10)], [0.34, Vector3(-100, 0, -10)], [0.62, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-20, 0, 0)], [0.4, Vector3.ZERO]]},
		"arm_r": {"idle": [2, 3.0, 0.5, PI, 0], "geh": [0, 10.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.22, Vector3(-10, 0, 42)], [0.34, Vector3(-10, 0, 42)], [0.62, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, 12)], [0.4, Vector3.ZERO]]},
		"wurzel": {"idle": [2, 3.0, 0.5, 0.0, 0], "geh": [2, 4.0, 2.2, 0.0, 0],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	# --- Zweibeiner-Gegner (ZweibeinerBau) ---------------------------------------
	"bandit": {
		"arm_r": {"idle": [1, 15.0, 1.8, 0.0, 0], "geh": [0, 18.0, 2.4, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(10, 0, 50)], [0.25, Vector3(-60, 0, -25)], [0.4, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-25, 0, 12)], [0.4, Vector3.ZERO]]},
		"arm_l": {"idle": [1, -15.0, 1.8, 0.0, 0], "geh": [0, 18.0, 2.4, PI, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(10, 0, -50)], [0.25, Vector3(-60, 0, 25)], [0.4, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-25, 0, -12)], [0.4, Vector3.ZERO]]},
		"wurzel": {"idle": [2, 5.0, 1.8, 0.0, 0], "geh": [2, 5.0, 2.4, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(-6, 0, 0)], [0.25, Vector3(8, 0, 0)], [0.4, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	"kultist": {
		"arm_r": {"idle": [2, 4.0, 0.5, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-95, 25, 25)], [0.3, Vector3(-95, 25, 25)], [0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-20, 0, 12)], [0.4, Vector3.ZERO]]},
		"arm_l": {"idle": [2, 4.0, 0.5, PI, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-95, -25, -25)], [0.3, Vector3(-95, -25, -25)], [0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-20, 0, -12)], [0.4, Vector3.ZERO]]},
		"wurzel": {"idle": [2, 3.0, 0.5, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-6, 0, 0)], [0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	"nekromant": {
		"arm_l": {"idle": [0, 10.0, 0.6, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-50, 0, 10)], [0.3, Vector3(-50, 0, 10)], [0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-20, 0, 0)], [0.4, Vector3.ZERO]]},
		"arm_r": {"idle": [2, 2.0, 0.4, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(28, 0, 8)], [0.45, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, 12)], [0.4, Vector3.ZERO]]},
		"wurzel": {"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(5, 0, 0)], [0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	# Skelett: Klappern (Kiefer in Stößen, Wurzel zittert), steifer Hieb.
	"skelett": {
		"arm_r": {"idle": [0, 3.0, 0.9, 0.0, 0], "geh": [0, 18.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.18, Vector3(-130, 0, 0)], [0.27, Vector3(60, 0, 0)], [0.45, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-20, 0, 12)], [0.4, Vector3.ZERO]]},
		"arm_l": {"idle": [0, 2.0, 0.9, PI, 0], "geh": [0, 18.0, 2.2, PI, 0],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-50, 0, 0)], [0.4, Vector3.ZERO]]},
		"kiefer": {"idle": [0, 14.0, 1.5, 0.0, 1],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(25, 0, 0)], [0.45, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.06, Vector3(22, 0, 0)], [0.35, Vector3.ZERO]]},
		"wurzel": {"idle": [2, 1.5, 9.0, 0.0, 0], "geh": [2, 4.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.27, Vector3(4, 0, 0)], [0.45, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.06, Vector3(0, 0, 6)], [0.14, Vector3(0, 0, -5)], [0.24, Vector3(0, 0, 3)],
				[0.4, Vector3.ZERO]]},
	},
	# Toddiener: schweres Schwanken, zitternder Greifarm, pendelnde Laterne,
	# nachwackelnder Kopf; Ruck-Griff.
	"toddiener": {
		"arm_r": {"idle": [0, 2.0, 7.0, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-30, 0, 0)], [0.32, Vector3(45, 0, 0)], [0.55, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-20, 0, 12)], [0.4, Vector3.ZERO]]},
		"arm_l": {"idle": [2, 10.0, 0.45, PI, 0], "geh": [2, 14.0, 1.6, PI, 0]},
		"kopf": {"idle": [2, 8.0, 0.45, 1.2, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(20, 0, 0)], [0.35, Vector3(20, 0, 0)], [0.55, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(0, 0, 30)], [0.45, Vector3.ZERO]]},
		"wurzel": {"idle": [2, 6.0, 0.45, 0.0, 0], "geh": [2, 7.0, 1.6, 0.0, 0],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-6, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	# Schattenkrieger: unheimlich still, horizontaler Rundhieb.
	"schattenkrieger": {
		"arm_r": {"idle": [1, 5.0, 0.4, 0.0, 0], "geh": [0, 14.0, 2.0, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.18, Vector3(-55, -70, 0)], [0.3, Vector3(-55, 70, 0)], [0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, 10)], [0.4, Vector3.ZERO]]},
		"arm_l": {"geh": [0, 14.0, 2.0, PI, 0],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-55, 0, 0)], [0.4, Vector3.ZERO]]},
		"wurzel": {"geh": [2, 3.0, 2.0, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.3, Vector3(6, 0, 0)], [0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-6, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	# Todesmeister (Boss): Orbit dreht (Dauerdrehung), Sensenhieb im Bogen,
	# Phasenwechsel = Orbit schneller (nur Optik).
	"todesmeister": {
		"orbit": {"idle": [1, 34.0, 0.0, 0.0, 2],
			"angriff": [[0.0, Vector3.ZERO], [0.7, Vector3(0, 120, 0)]],
			"phase": [[0.0, Vector3.ZERO], [1.3, Vector3(0, 240, 0)]]},
		"kopf": {"idle": [0, 5.0, 0.25, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.3, Vector3(-8, 0, 0)], [0.38, Vector3(15, 0, 0)], [0.7, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, 0)], [0.4, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-15, 0, 0)], [0.9, Vector3(-15, 0, 0)], [1.3, Vector3.ZERO]]},
		"arm_r": {"idle": [2, 3.0, 0.4, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.3, Vector3(-120, 35, 0)], [0.38, Vector3(55, -45, 0)], [0.7, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, 12)], [0.4, Vector3.ZERO]]},
		"arm_l": {"idle": [0, 6.0, 0.8, 0.0, 0],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-60, 0, -10)], [0.9, Vector3(-60, 0, -10)], [1.3, Vector3.ZERO]]},
	},
	# Kleindämon: schneller Flügelschlag, Pendelschwanz, Feuerball-Wurf.
	"kleindaemon": {
		"fluegel_l": {"idle": [2, -25.0, 8.0, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(0, 0, -30)], [0.4, Vector3.ZERO]]},
		"fluegel_r": {"idle": [2, 25.0, 8.0, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(0, 0, 30)], [0.4, Vector3.ZERO]]},
		"schwanz": {"idle": [1, 20.0, 1.2, 0.0, 0]},
		"arm_r": {"idle": [0, 15.0, 1.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(-110, 0, 0)], [0.25, Vector3(10, 0, 0)], [0.4, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-20, 0, 12)], [0.4, Vector3.ZERO]]},
		"wurzel": {"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-10, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	"demonenbeschwoerer": {
		"arm_l": {"idle": [0, 5.0, 0.8, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-30, 0, 0)], [0.55, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-20, 0, 0)], [0.4, Vector3.ZERO]]},
		"arm_r": {"idle": [2, 2.0, 0.4, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-15, 0, 45)], [0.3, Vector3(30, 0, 5)], [0.55, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, 12)], [0.4, Vector3.ZERO]]},
		"wurzel": {"idle": [0, 2.0, 0.3, 0.0, 0],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	# Dämonenfürst (Boss): gefaltete Flügel zucken, Kopf mustert; Angriff =
	# Flügel spreizen + Zweihand-Überkopfschlag; Phase = Flügel auf, Kopf hoch.
	"demonenkonig": {
		"arm_r": {"idle": [0, 2.0, 0.6, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.25, Vector3(-125, 0, 0)], [0.32, Vector3(-125, 0, 0)],
				[0.45, Vector3(48, 0, 0)], [0.8, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, 10)], [0.4, Vector3.ZERO]]},
		"arm_l": {"idle": [0, 2.0, 0.6, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.25, Vector3(-115, 0, 0)], [0.32, Vector3(-115, 0, 0)],
				[0.45, Vector3(42, 0, 0)], [0.8, Vector3.ZERO]]},
		"kopf": {"idle": [1, 10.0, 0.15, 0.0, 0],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-12, 0, 0)], [0.4, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-25, 0, 0)], [0.9, Vector3(-25, 0, 0)], [1.3, Vector3.ZERO]]},
		"fluegel_l": {"idle": [2, -4.0, 0.5, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.25, Vector3(0, 45, -15)], [0.55, Vector3(0, 45, -15)], [0.8, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(0, 50, -20)], [0.9, Vector3(0, 50, -20)], [1.3, Vector3.ZERO]]},
		"fluegel_r": {"idle": [2, 4.0, 0.5, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.25, Vector3(0, -45, 15)], [0.55, Vector3(0, -45, 15)], [0.8, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(0, -50, 20)], [0.9, Vector3(0, -50, 20)], [1.3, Vector3.ZERO]]},
		"wurzel": {"angriff": [[0.0, Vector3.ZERO], [0.3, Vector3(-6, 0, 0)], [0.45, Vector3(8, 0, 0)], [0.8, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-5, 0, 0)], [0.4, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-8, 0, 0)], [0.9, Vector3(-8, 0, 0)], [1.3, Vector3.ZERO]]},
	},
	# Pilzhexe: kichert in Stößen, der Hut wippt nach, Stock schütteln.
	"pilzhexe": {
		"kopf": {"idle": [0, 6.0, 2.5, -0.6, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(20, 0, 0)], [0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, 10)], [0.4, Vector3.ZERO]]},
		"arm_r": {"idle": [2, 2.0, 0.6, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(-10, 0, 40)], [0.22, Vector3(-10, 0, 28)],
				[0.29, Vector3(-10, 0, 48)], [0.36, Vector3(-10, 0, 30)], [0.5, Vector3.ZERO]]},
		"arm_l": {"idle": [2, 8.0, 1.2, 0.0, 0]},
		"wurzel": {"idle": [2, 3.0, 2.5, 0.0, 1],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	# Hexenmeisterin: Kristall dreht frei im Haken, die Robe wiegt.
	"hexenmeisterin": {
		"kristall": {"idle": [1, 69.0, 0.0, 0.0, 2], "angriff": [[0.0, Vector3.ZERO], [0.55, Vector3(0, 360, 0)]]},
		"arm_r": {"idle": [2, 2.0, 0.4, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(30, 0, 6)], [0.35, Vector3(30, 0, 6)], [0.55, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-15, 0, 12)], [0.4, Vector3.ZERO]]},
		"arm_l": {"idle": [0, 10.0, 0.7, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-50, 0, 10)], [0.35, Vector3(-50, 0, 10)], [0.55, Vector3.ZERO]]},
		"wurzel": {"idle": [2, 3.0, 0.4, 0.0, 0],
			"treffer": [[0.0, Vector3.ZERO], [0.08, Vector3(-8, 0, 0)], [0.4, Vector3.ZERO]]},
	},
	# --- Vierbeiner und Schleime (VierbeinerBau, STIL-3D.md 7i) ---------------------
	# Glied "koerper" (Beine + Rumpf) dreht um die Hinterpfoten: x > 0 = vorn
	# runter (Ducken), x < 0 = vorn hoch (Aufbäumen). Kopf x > 0 = Schnauze
	# runter, Kiefer x > 0 = Maul auf, Schwanz x > 0 = Schwanz hoch. "hub" =
	# [Anheben, Quer-, Hoch-Skalierung] der Wurzel (nur Kampfbühne/Showcase,
	# hub_anwenden): Sprung, Stretch und Platsch ohne Glied-Skalierung.
	# Grauwolf: Kopf schaut umher, Schwanz wedelt, Hecheln; Sprungbiss.
	"hund": {
		"koerper": {"geh": [0, 3.0, 2.4, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.1, Vector3(7, 0, 0)], [0.2, Vector3(-7, 0, 0)], [0.32, Vector3(3, 0, 0)],
				[0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.07, Vector3(-7, 0, 0)], [0.4, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-12, 0, 0)], [0.9, Vector3(-12, 0, 0)], [1.3, Vector3.ZERO]]},
		"kopf": {"idle": [1, 12.0, 0.35, 0.0, 0], "geh": [0, 4.0, 2.4, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.1, Vector3(10, 0, 0)], [0.2, Vector3(16, 0, 0)], [0.32, Vector3(12, 0, 0)],
				[0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.07, Vector3(-20, 0, 0)], [0.4, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-40, 0, 0)], [0.9, Vector3(-40, 0, 0)], [1.3, Vector3.ZERO]]},
		"kiefer": {"idle": [0, 6.0, 2.0, 0.0, 1],
			"angriff": [[0.0, Vector3.ZERO], [0.12, Vector3(32, 0, 0)], [0.2, Vector3(2, 0, 0)], [0.26, Vector3(6, 0, 0)],
				[0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.07, Vector3(14, 0, 0)], [0.35, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(30, 0, 0)], [0.9, Vector3(30, 0, 0)], [1.3, Vector3.ZERO]]},
		"schwanz": {"idle": [1, 10.0, 1.5, 0.0, 0], "geh": [1, 18.0, 3.0, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.1, Vector3(25, 0, 0)], [0.36, Vector3(25, 0, 0)], [0.5, Vector3.ZERO]]},
		"wurzel": {"geh": [2, 3.0, 2.4, 0.0, 0]},
		"hub": {"angriff": [[0.0, Vector3.ZERO], [0.1, Vector3(-0.02, 0.05, -0.07)], [0.2, Vector3(0.08, -0.03, 0.06)],
			[0.32, Vector3(0, 0.04, -0.04)], [0.5, Vector3.ZERO]]},
	},
	# Braunbär: schweres Atmen, Schnüffeln alle 4 s; Prankenhieb = Aufrichten
	# auf den Hinterbeinen, Halten, Schlag mit Stampf-Platsch; Phase = Brüllen.
	"baer": {
		"koerper": {"idle": [0, 1.5, 0.5, 0.0, 0], "geh": [2, 3.0, 1.8, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-30, 0, 0)], [0.32, Vector3(-30, 0, 0)], [0.42, Vector3(8, 0, 0)],
				[0.7, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.07, Vector3(-4, 0, 0)], [0.4, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-26, 0, 0)], [0.9, Vector3(-26, 0, 0)], [1.3, Vector3.ZERO]]},
		"kopf": {"idle": [0, 15.0, 0.4, 0.0, 3, 4.0, 1.25], "geh": [1, 6.0, 1.8, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-14, 0, 0)], [0.32, Vector3(-14, 0, 0)], [0.42, Vector3(16, 0, 0)],
				[0.7, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.06, Vector3(0, 10, 0)], [0.14, Vector3(0, -10, 0)], [0.22, Vector3(0, 8, 0)],
				[0.3, Vector3(0, -6, 0)], [0.45, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-22, 0, 0)], [0.9, Vector3(-22, 0, 0)], [1.3, Vector3.ZERO]]},
		"kiefer": {"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(34, 0, 0)], [0.36, Vector3(34, 0, 0)], [0.45, Vector3(4, 0, 0)],
				[0.7, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(36, 0, 0)], [0.9, Vector3(36, 0, 0)], [1.3, Vector3.ZERO]]},
		"hub": {"angriff": [[0.0, Vector3.ZERO], [0.42, Vector3.ZERO], [0.48, Vector3(-0.02, 0.12, -0.12)], [0.7, Vector3.ZERO]]},
	},
	# Schattenpanther: geduckt lauernd, Schwanz peitscht; Sprung im Bogen mit
	# offenem Maul; Phase = Dunkler Odem (Kopf hoch, glühendes Maul auf).
	"panther": {
		"koerper": {"idle": [0, 3.0, 0.3, 0.0, 0], "geh": [0, 3.0, 2.6, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.1, Vector3(9, 0, 0)], [0.22, Vector3(-12, 0, 0)], [0.34, Vector3(6, 0, 0)],
				[0.5, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-8, 0, 0)], [0.9, Vector3(-8, 0, 0)], [1.3, Vector3.ZERO]]},
		"kopf": {"idle": [1, 4.0, 0.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.1, Vector3(10, 0, 0)], [0.22, Vector3(-6, 0, 0)], [0.34, Vector3(12, 0, 0)],
				[0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.07, Vector3(-12, 0, 0)], [0.4, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-24, 0, 0)], [0.9, Vector3(-24, 0, 0)], [1.3, Vector3.ZERO]]},
		"kiefer": {"idle": [0, 4.0, 0.5, 0.0, 1],
			"angriff": [[0.0, Vector3.ZERO], [0.16, Vector3(34, 0, 0)], [0.3, Vector3(30, 0, 0)], [0.36, Vector3.ZERO],
				[0.5, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(36, 0, 0)], [0.9, Vector3(36, 0, 0)], [1.3, Vector3.ZERO]]},
		"schwanz": {"idle": [1, 25.0, 0.9, 0.0, 0], "geh": [1, 30.0, 2.6, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.22, Vector3(20, 0, 0)], [0.5, Vector3.ZERO]]},
		"wurzel": {"geh": [2, 3.0, 2.6, 0.0, 0],
			"treffer": [[0.0, Vector3.ZERO], [0.07, Vector3(0, 0, 12)], [0.18, Vector3(0, 0, -5)], [0.4, Vector3.ZERO]]},
		"hub": {"angriff": [[0.0, Vector3.ZERO], [0.1, Vector3(-0.03, 0.05, -0.08)], [0.24, Vector3(0.25, -0.03, 0.06)],
			[0.36, Vector3(0, 0.08, -0.1)], [0.5, Vector3.ZERO]]},
	},
	# Ghul-Hyäne: pickt schnüffelnd zum Boden, Kiefer klappert; Ausfall mit
	# Kopfschütteln (Reißen); Phase = Heulen.
	"ghul": {
		"koerper": {"geh": [0, 3.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.12, Vector3(6, 0, 0)], [0.22, Vector3(-4, 0, 0)], [0.55, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.07, Vector3(7, 0, 0)], [0.4, Vector3.ZERO]]},
		"kopf": {"idle": [0, 22.0, 0.5, 0.0, 3, 2.5, 1.0], "geh": [1, 6.0, 2.2, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.12, Vector3(10, 0, 0)], [0.2, Vector3(10, 20, 0)], [0.28, Vector3(10, -20, 0)],
				[0.36, Vector3(10, 18, 0)], [0.44, Vector3(10, -12, 0)], [0.55, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.07, Vector3(0, 0, 15)], [0.4, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-38, 0, 0)], [0.9, Vector3(-38, 0, 0)], [1.3, Vector3.ZERO]]},
		"kiefer": {"idle": [0, 8.0, 4.0, 0.0, 1],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(16, 0, 0)], [0.45, Vector3(16, 0, 0)], [0.55, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(14, 0, 0)], [0.9, Vector3(14, 0, 0)], [1.3, Vector3.ZERO]]},
		"schwanz": {"idle": [1, 8.0, 0.6, 0.0, 0], "geh": [1, 14.0, 2.2, 0.0, 0]},
		"wurzel": {"geh": [2, 3.0, 2.2, 0.0, 0]},
		"hub": {"angriff": [[0.0, Vector3.ZERO], [0.12, Vector3(-0.02, 0.04, -0.05)], [0.22, Vector3(0.04, 0, 0)],
			[0.55, Vector3.ZERO]]},
	},
	# Höllenhund-Jäger: Kopf scannt ruckartig, Schwanzflamme flackert; Zielen
	# (still), dann gerader schneller Ausfall mit Zuschnappen.
	"hoellenhund": {
		"koerper": {"geh": [0, 3.0, 2.6, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.14, Vector3(6, 0, 0)], [0.2, Vector3(-6, 0, 0)], [0.42, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-12, 0, 0)], [0.9, Vector3(-12, 0, 0)], [1.3, Vector3.ZERO]]},
		"kopf": {"idle": [1, 20.0, 1.6, 0.0, 4], "geh": [0, 4.0, 2.6, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.14, Vector3(5, 0, 0)], [0.2, Vector3(15, 0, 0)], [0.42, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.07, Vector3(-18, 0, 0)], [0.4, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-30, 0, 0)], [0.9, Vector3(-30, 0, 0)], [1.3, Vector3.ZERO]]},
		"kiefer": {"idle": [0, 4.0, 1.5, 0.0, 1],
			"angriff": [[0.0, Vector3.ZERO], [0.16, Vector3(34, 0, 0)], [0.22, Vector3(2, 0, 0)], [0.42, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(30, 0, 0)], [0.9, Vector3(30, 0, 0)], [1.3, Vector3.ZERO]]},
		"schwanz": {"idle": [0, 8.0, 3.0, 0.0, 0],
			"treffer": [[0.0, Vector3.ZERO], [0.06, Vector3(0, 30, 0)], [0.16, Vector3(0, -20, 0)], [0.4, Vector3.ZERO]]},
		"wurzel": {"geh": [2, 3.0, 2.6, 0.0, 0]},
		"hub": {"angriff": [[0.0, Vector3.ZERO], [0.14, Vector3(-0.02, 0.04, -0.05)], [0.2, Vector3(0.05, -0.04, 0.05)],
			[0.42, Vector3.ZERO]]},
	},
	# Hexenkatze: Fragezeichen-Schwanz schwingt, Kopf neigt sich; Angriff =
	# Hüpfer und drei schnelle Krallen-Rucke (Mehrfachtreffer).
	"katze": {
		"koerper": {"geh": [0, 3.0, 2.8, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.1, Vector3(-6, 0, 0)], [0.16, Vector3(6, 0, 0)], [0.22, Vector3.ZERO],
				[0.28, Vector3(6, 0, 0)], [0.34, Vector3.ZERO], [0.4, Vector3(6, 0, 0)], [0.52, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(8, 0, 0)], [0.9, Vector3(8, 0, 0)], [1.3, Vector3.ZERO]]},
		"kopf": {"idle": [2, 10.0, 0.35, 0.0, 3, 3.0, 1.4], "geh": [0, 4.0, 2.8, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.1, Vector3(-4, 0, 0)], [0.16, Vector3(12, 0, 0)], [0.22, Vector3.ZERO],
				[0.28, Vector3(12, 0, 0)], [0.34, Vector3.ZERO], [0.4, Vector3(12, 0, 0)], [0.52, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.07, Vector3(-18, 0, 8)], [0.4, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(14, 0, 0)], [0.9, Vector3(14, 0, 0)], [1.3, Vector3.ZERO]]},
		"schwanz": {"idle": [1, 20.0, 0.4, 0.0, 0], "geh": [1, 14.0, 1.4, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.1, Vector3(-12, 0, 0)], [0.42, Vector3(-12, 0, 0)], [0.52, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.06, Vector3(0, 25, 0)], [0.4, Vector3.ZERO]]},
		"wurzel": {"geh": [2, 3.0, 2.8, 0.0, 0]},
		"hub": {"angriff": [[0.0, Vector3.ZERO], [0.06, Vector3(-0.01, 0.06, -0.08)], [0.12, Vector3(0.12, -0.03, 0.06)],
			[0.2, Vector3(0, 0.05, -0.06)], [0.3, Vector3.ZERO]]},
	},
	# Panzer-Dachs: Grab-Nicken, Schnüffeln am Boden; Wühlbiss = tiefes
	# Abtauchen mit Kopfschütteln; Treffer = nur ein kurzer Ruck (Tank).
	"dachs": {
		"koerper": {"idle": [0, 4.0, 1.0, 0.0, 0], "geh": [0, 3.0, 2.4, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(12, 0, 0)], [0.32, Vector3(12, 0, 0)], [0.5, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.05, Vector3(-3, 0, 0)], [0.2, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(6, 0, 0)], [0.9, Vector3(6, 0, 0)], [1.3, Vector3.ZERO]]},
		"kopf": {"idle": [0, 12.0, 1.5, 0.0, 3, 2.2, 1.2], "geh": [1, 6.0, 2.4, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(10, 0, 0)], [0.22, Vector3(10, 18, 0)], [0.3, Vector3(10, -18, 0)],
				[0.38, Vector3(10, 12, 0)], [0.5, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(16, 0, 0)], [0.9, Vector3(16, 0, 0)], [1.3, Vector3.ZERO]]},
		"kiefer": {"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(28, 0, 0)], [0.38, Vector3(20, 0, 0)], [0.5, Vector3.ZERO]]},
		"wurzel": {"geh": [2, 3.0, 2.4, 0.0, 0]},
		"hub": {"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(-0.03, 0.06, -0.06)], [0.32, Vector3(-0.03, 0.06, -0.06)],
			[0.5, Vector3.ZERO]]},
	},
	# Hirschbock: hebt und senkt den Kopf, Hufscharren; Sturmangriff mit
	# gesenktem Geweih; Phase = Aufsteigen und Hufstampfer.
	"bock": {
		"koerper": {"idle": [0, 3.0, 0.8, 0.0, 3, 3.5, 1.2], "geh": [0, 3.0, 2.0, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(8, 0, 0)], [0.4, Vector3(8, 0, 0)], [0.6, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-24, 0, 0)], [0.62, Vector3(-24, 0, 0)], [0.74, Vector3(4, 0, 0)],
				[1.3, Vector3.ZERO]]},
		"kopf": {"idle": [0, 7.0, 0.25, 0.0, 0], "geh": [0, 5.0, 2.0, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(34, 0, 0)], [0.4, Vector3(34, 0, 0)], [0.6, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.07, Vector3(0, 15, 0)], [0.18, Vector3(0, -8, 0)], [0.4, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-16, 0, 0)], [0.62, Vector3(-16, 0, 0)], [0.74, Vector3(10, 0, 0)],
				[1.3, Vector3.ZERO]]},
		"schwanz": {"idle": [1, 14.0, 1.6, 0.0, 0], "geh": [0, 15.0, 2.0, 0.0, 0]},
		"wurzel": {"geh": [2, 2.5, 2.0, 0.0, 0]},
		"hub": {"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(-0.02, 0.04, -0.05)], [0.4, Vector3(0.03, 0, 0)],
			[0.6, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.62, Vector3.ZERO], [0.76, Vector3(-0.02, 0.12, -0.12)], [1.0, Vector3.ZERO]]},
	},
	# Stachel-Igel: schnelles Schnüffeln in Stößen; Angriff = Einrollen und
	# Vorwärtsrolle (Koerper 360°), dann Aufspringen.
	"igel": {
		"koerper": {"idle": [0, 2.0, 0.5, 0.0, 0], "geh": [2, 6.0, 3.0, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.08, Vector3(-10, 0, 0)], [0.33, Vector3(360, 0, 0)]],
			"treffer": [[0.0, Vector3.ZERO], [0.06, Vector3(0, 0, 8)], [0.14, Vector3(0, 0, -6)], [0.3, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-18, 0, 0)], [0.9, Vector3(-18, 0, 0)], [1.3, Vector3.ZERO]]},
		"kopf": {"idle": [0, 6.0, 2.5, 0.0, 3, 3.0, 1.0],
			"angriff": [[0.0, Vector3.ZERO], [0.08, Vector3(45, 0, 0)], [0.33, Vector3(45, 0, 0)], [0.45, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.06, Vector3(35, 0, 0)], [0.4, Vector3.ZERO]]},
		"hub": {"angriff": [[0.0, Vector3.ZERO], [0.08, Vector3(0, 0.05, -0.08)], [0.2, Vector3(0.08, 0, 0)],
			[0.33, Vector3.ZERO], [0.4, Vector3(0.06, -0.03, 0.05)], [0.5, Vector3.ZERO]]},
	},
	# Tropfenschleim: Zipfel wackelt gegenphasig zum Quetschen; Angriff =
	# Stretch nach oben, Platsch nach vorn, Zipfel schnalzt.
	"schleim": {
		"zipfel": {"idle": [2, 12.0, 0.48, 0.6, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.12, Vector3(-15, 0, 0)], [0.24, Vector3(30, 0, 0)], [0.45, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.06, Vector3(0, 0, 20)], [0.14, Vector3(0, 0, -15)], [0.24, Vector3(0, 0, 8)],
				[0.4, Vector3.ZERO]]},
		"hub": {"angriff": [[0.0, Vector3.ZERO], [0.12, Vector3(0.03, -0.15, 0.25)], [0.24, Vector3(0, 0.25, -0.3)],
			[0.45, Vector3.ZERO]]},
	},
	# Schleimstapel: Welle von unten nach oben (Lagen pendeln versetzt);
	# Angriff = die Spitze kippt nach vorn und klatscht zurück.
	"stapel": {
		"lage1": {"idle": [2, 4.0, 0.5, 0.8, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.2, Vector3(-6, 0, 0)], [0.32, Vector3(16, 0, 0)], [0.55, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.06, Vector3(0, 0, 10)], [0.16, Vector3(0, 0, -8)], [0.28, Vector3(0, 0, 5)],
				[0.5, Vector3.ZERO]]},
		"lage2": {"idle": [2, 5.0, 0.5, 1.6, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(-12, 0, 0)], [0.27, Vector3(40, 0, 0)], [0.38, Vector3(-8, 0, 0)],
				[0.55, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.06, Vector3(0, 0, -12)], [0.16, Vector3(0, 0, 10)], [0.28, Vector3(0, 0, -5)],
				[0.5, Vector3.ZERO]]},
		"wurzel": {"idle": [2, 2.5, 0.5, 0.0, 0],
			"treffer": [[0.0, Vector3.ZERO], [0.06, Vector3(0, 0, 5)], [0.16, Vector3(0, 0, -4)], [0.5, Vector3.ZERO]]},
		"hub": {"angriff": [[0.0, Vector3.ZERO], [0.15, Vector3(0, -0.06, 0.1)], [0.3, Vector3(0, 0.12, -0.14)],
			[0.55, Vector3.ZERO]]},
	},
	# König-Schleim: würdevolles Wiegen, Krone wackelt nach; Königsplatscher
	# (großer Hüpfer, Bauchklatscher); Phase = Zepter hoch (Königliche Gnade).
	"koenig": {
		"krone": {"idle": [2, 6.0, 0.3, -0.9, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.3, Vector3(-12, 0, 0)], [0.42, Vector3(10, 0, 8)], [0.65, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.07, Vector3(0, 0, 15)], [0.2, Vector3(0, 0, 10)], [0.45, Vector3.ZERO]]},
		"zepter": {"idle": [0, 5.0, 0.6, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.3, Vector3(-30, 0, 0)], [0.42, Vector3(15, 0, 0)], [0.65, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(-60, 0, 0)], [0.9, Vector3(-60, 0, 0)], [1.3, Vector3.ZERO]]},
		"wurzel": {"idle": [2, 3.0, 0.3, 0.0, 0]},
		"hub": {"angriff": [[0.0, Vector3.ZERO], [0.12, Vector3(-0.02, 0.1, -0.12)], [0.3, Vector3(0.3, -0.1, 0.15)],
			[0.42, Vector3(0, 0.28, -0.3)], [0.65, Vector3.ZERO]]},
	},
	# Gottschleim: Orbit der Trabanten dreht, Schein kreist; Götterplatscher;
	# Phase = Urschleim-Flut (Orbit wirbelt), nur Optik.
	"gott": {
		"orbit": {"idle": [1, 23.0, 0.0, 0.0, 2],
			"angriff": [[0.0, Vector3.ZERO], [0.7, Vector3(0, 90, 0)]],
			"treffer": [[0.0, Vector3.ZERO], [0.06, Vector3(0, 0, 8)], [0.16, Vector3(0, 0, -6)], [0.4, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [1.3, Vector3(0, 225, 0)]]},
		"schein": {"idle": [2, 5.0, 0.3, 0.0, 0],
			"angriff": [[0.0, Vector3.ZERO], [0.3, Vector3(12, 0, 0)], [0.45, Vector3(-6, 0, 0)], [0.7, Vector3.ZERO]],
			"phase": [[0.0, Vector3.ZERO], [0.3, Vector3(14, 0, 0)], [0.9, Vector3(14, 0, 0)], [1.3, Vector3.ZERO]]},
		"hub": {"angriff": [[0.0, Vector3.ZERO], [0.3, Vector3(0.35, -0.1, 0.15)], [0.45, Vector3(0, 0.3, -0.3)],
			[0.7, Vector3.ZERO]],
			"treffer": [[0.0, Vector3.ZERO], [0.05, Vector3(0, 0.04, -0.05)], [0.12, Vector3(0, -0.03, 0.04)],
				[0.3, Vector3.ZERO]]},
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


static var _hub := Vector3.ZERO


## Hub des letzten beleben()-Aufrufs: [Anheben (Figurmaße), Quer-, Hoch-
## Skalierung] — Sprung, Stretch und Platsch der Wurzel (Profil-Glied "hub").
static func hub() -> Vector3:
	return _hub


## Den Hub des letzten beleben() auf die Wurzel legen (nach Position und
## Skalierung des Bilds): Anheben × Wurzel-Skala, Skalierung multipliziert;
## Bodenteile (Ringe, Siegel) bleiben am Boden. Glieder bleiben unskaliert.
static func hub_anwenden(fig: Node3D) -> void:
	if _hub.is_zero_approx():
		return
	var alt_y := fig.scale.y
	fig.scale *= Vector3(1.0 + _hub.y, 1.0 + _hub.z, 1.0 + _hub.y)
	var hub_welt := _hub.x * alt_y
	fig.position.y += hub_welt
	var neu_y := maxf(0.01, fig.scale.y)
	for teil in fig.get_meta("boden_teile", []):
		if is_instance_valid(teil):
			var n := teil as Node3D
			n.position.y = (n.position.y * alt_y - hub_welt) / neu_y


## Belebt eine Gliederpuppe: setzt jedes Glied auf Ruhe + Idle/Gehen +
## Angriff + Treffer + Phase und liefert den Euler-Versatz der Wurzel
## (Bogenmaß). zeit < 0 = ohne Idle; aktion_t/treffer_t/phase_t = Sekunden
## seit Beginn (< 0 = aus). Reine Funktion ohne Allokation je Bild.
static func beleben(fig: Node3D, zeit: float, aktion_t := -1.0, treffer_t := -1.0, geht := false,
		phase_t := -1.0) -> Vector3:
	var profil: Dictionary = PROFILE.get(String(fig.get_meta("anim", "")), {})
	var glieder: Dictionary = fig.get_meta("glieder", {})
	var wurzel := Vector3.ZERO
	_hub = Vector3.ZERO
	for glied_name in profil:
		var grad := _versatz(profil[glied_name], zeit, aktion_t, treffer_t, geht, phase_t)
		if glied_name == "wurzel":
			wurzel = grad * GRAD
			continue
		if glied_name == "hub":
			_hub = grad
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
	var wurzel := beleben(fig, zeit, _uhr(e, "aktion", delta), _uhr(e, "treffer_t", delta), false,
		_uhr(e, "phase_t", delta))
	hub_anwenden(fig)  # Sprung/Stretch/Platsch (Vierbeiner, Schleime)
	return wurzel


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


const _SCAN := [-1.0, 0.0, 1.0, 0.0]


static func _versatz(eintrag: Dictionary, zeit: float, aktion_t: float, treffer_t: float, geht: bool,
		phase_t: float) -> Vector3:
	var v := Vector3.ZERO
	if zeit >= 0.0:
		var welle: Variant = eintrag.get("geh") if geht and eintrag.has("geh") else eintrag.get("idle")
		if welle != null:
			var w: Array = welle
			var form := int(w[4])
			if form == 2:
				v[int(w[0])] = fmod(zeit * float(w[1]) + float(w[3]), 360.0)
			elif form == 3:
				var dauer_s := float(w[6])
				var tt := fposmod(zeit + float(w[3]), float(w[5]))
				if tt < dauer_s:
					v[int(w[0])] = sin(tt * TAU * float(w[2])) * sin(PI * tt / dauer_s) * float(w[1])
			elif form == 4:
				var x := zeit * float(w[2]) + float(w[3])
				var i := int(floor(x))
				var von: float = _SCAN[posmod(i - 1, 4)]
				var nach: float = _SCAN[posmod(i, 4)]
				v[int(w[0])] = lerpf(von, nach, smoothstep(0.0, 0.18, x - floor(x))) * float(w[1])
			else:
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
