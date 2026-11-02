class_name VorratIcons
extends RefCounted
## Icons für Verbrauchsgüter (Tränke, Salben, Verband …), Materialien
## (Kräuter, Erze, Leder, Kristalle, Runen) und Biome (Kartenlager) im
## STIL-3D-Look: kleine Figuren aus Grundkörpern, die PortraitStudio EINMAL
## in eine Textur rendert (wie GegenstandIcons und KlotzIcons).
## Biom-Miniaturen sind Bausatz-Dioramen aus derselben BiomKulisse wie der
## Dungeon (Plattenstück + Wandkrone + Deko) — der Ort ist sofort erkennbar.

## Flüssigkeitsfarbe je Trank (PAL-Namen); unbekannte nach Wirkung.
## Stärkungstonikum in Bernstein (war Dämonenrot ≈ Heiltrank-Rot).
const TRANK_FARBE := {
	&"heiltrank": "pilz_rot", &"grosser_heiltrank": "pilz_rot",
	&"manatrank": "mana", &"grosser_manatrank": "mana",
	&"belebungselixier": "glut", &"gegengift": "moos", &"weckelixier": "glut",
	&"tempotrunk": "kristall", &"staerkungstonikum": "bernstein", &"waermetrank": "flamme",
	&"fluchbrecher": "lila", &"allheilmittel": "seele",
}
## Erzader-Farbe je Stufe 1..5 (PAL-Namen): Eisen rostorange, Stahl
## blaugrau-hell, Mithril hellblau, Adamant grün, Sternenmetall violett.
const ERZ_FARBE := ["bernstein", "silber", "kristall", "smaragd", "lila"]
const LEDER_FARBE := ["leder", "braun_hell", "smaragd", "drachenblut", "obsidian"]
## Kristallfarbe je Stufe; Mondkristall bleich-blau ("stern") statt Silber
## (vorher kaum von Kristallstaub zu unterscheiden).
const KRISTALL_FARBE := ["weiss", "stern", "gold", "seele", "lila"]
## Luft um Vorrats-Icons (kleiner als bei Ausrüstung: kein Level-Chip,
## Anzeige 26–40 px).
const RAND := 1.18
## Blick von schräg oben für flache Haufen (Lederreste, Kristallstaub).
const BLICK_OBEN := Vector3(1.2, 2.2, 3.6)
## Erze und Leder (breite, flache Formen) wirkten bei 32 px zu klein: das
## Einrahmen nach der größeren Seite ließ oben und unten viel Luft. Engerer
## Rand (die Kontur steckt schon im Rahmen, nichts ragt aus der Kachel) und —
## beim Lederstapel — ein steilerer Blick, der die Fläche statt der Kante
## zeigt. Der Erzbrocken war fast doppelt so breit wie hoch (füllte die
## Kachel nur zu ≈ 74 %; der Rahmen maß ihn schon richtig): jetzt ein
## höherer, etwas schmalerer Brocken (ERZ_HOEHE), der die Kachel zu ≈ 90 %
## füllt, mit 1–2 px Luft (RAND_ERZ) statt Kante an Kante.
const RAND_ERZ := 1.04
const RAND_LEDER := 1.04
const BLICK_ERZ := Vector3(1.2, 1.3, 3.8)
const ERZ_HOEHE := 0.68
## Stern des Sternenmetalls: sitzt auf der Kuppe (ragt nur wenig darüber).
const ERZ_STERN := Vector3(-0.04, 0.78, 0.12)
const BLICK_LEDER := Vector3(0.8, 3.0, 3.0)


static func _p(name: String) -> Color:
	return Stil3D.farbe(name)


static func trank(studio: PortraitStudio, id: StringName) -> Texture2D:
	return studio.textur("trank|%s" % id, func() -> Node3D: return trank_bauen(id))


static func material(studio: PortraitStudio, id: StringName) -> Texture2D:
	return studio.textur("material|%s" % id, func() -> Node3D: return material_bauen(id))


## Gold, Mini-Medaille, Schatzkarte (Sieg-Fenster, Truhen …).
static func symbol(studio: PortraitStudio, id: StringName) -> Texture2D:
	return studio.textur("symbol|%s" % id, func() -> Node3D: return symbol_bauen(id))


static func biom(studio: PortraitStudio, biome: int) -> Texture2D:
	return studio.textur("biom|%d" % biome, func() -> Node3D: return biom_bauen(biome))


# --- Tränke und Verbrauchsgüter ----------------------------------------------------

static func trank_bauen(id: StringName) -> Node3D:
	var n := Node3D.new()
	match id:
		&"verbandszeug":
			Stil3D.teil(n, Stil3D.zylinder(0.26, 0.26, 0.5), _p("weiss"), Vector3(0, 0.3, 0), Vector3(0, 30, 90))
			Stil3D.teil(n, Stil3D.zylinder(0.1, 0.1, 0.52), _p("knochen"), Vector3(0, 0.3, 0), Vector3(0, 30, 90))
			Stil3D.teil(n, Stil3D.box(0.5, 0.04, 0.24), _p("weiss") * 0.94, Vector3(0.36, 0.04, 0.24), Vector3(0, 30, 0))
			Stil3D.teil(n, Stil3D.box(0.06, 0.2, 0.2), _p("umhang"), Vector3(-0.02, 0.32, 0.03), Vector3(0, 30, 0), false)
		&"tarnpuder":
			Stil3D.teil(n, Stil3D.kugel(0.32, 0.5), _p("leder"), Vector3(0, 0.28, 0))
			Stil3D.teil(n, Stil3D.zylinder(0.1, 0.16, 0.18), _p("leder") * 0.85, Vector3(0, 0.58, 0))
			Stil3D.teil(n, Stil3D.zylinder(0.13, 0.13, 0.04), _p("gold"), Vector3(0, 0.55, 0))
			Stil3D.teil(n, Stil3D.kugel(0.12, 0.06), _p("schatten").lightened(0.3), Vector3(0.3, 0.03, 0.18),
				Vector3.ZERO, false)
		&"schmiedepaste":
			Stil3D.teil(n, Stil3D.zylinder(0.32, 0.32, 0.3), _p("eisen"), Vector3(0, 0.15, 0))
			Stil3D.teil(n, Stil3D.zylinder(0.28, 0.28, 0.04), _p("stein_hell"), Vector3(0, 0.31, 0), Vector3.ZERO, false)
			Stil3D.teil(n, Stil3D.zylinder(0.34, 0.34, 0.06), _p("gold") * 0.85, Vector3(0.12, 0.42, -0.1),
				Vector3(-28, 0, 20))
		&"brandsalbe":
			Stil3D.teil(n, Stil3D.zylinder(0.3, 0.28, 0.36), _p("kerze"), Vector3(0, 0.18, 0))
			Stil3D.teil(n, Stil3D.kugel(0.26, 0.16), _p("flamme"), Vector3(0, 0.37, 0), Vector3.ZERO, false,
				_p("flamme") * 0.35)
			Stil3D.teil(n, Stil3D.box(0.62, 0.14, 0.02), _p("braun"), Vector3(0, 0.18, 0.29), Vector3.ZERO, false)
		_:
			var farbe := _p(TRANK_FARBE.get(id, "pilz_rot"))
			var gross := String(id).begins_with("grosser")
			# Jeder Trank auch ohne Farbe erkennbar (Form, Stopfen, Symbol):
			# Mana mit Kristallstopfen statt Korken, Gegengift als Kolben,
			# Wärmetrank als Kürbisflasche mit Flamme, Fluchbrecher als
			# Sechskantflasche mit Silberkreuz, Allheilmittel mit Goldkrone.
			match id:
				&"belebungselixier": _phiole(n, farbe, "belebung")
				&"tempotrunk": _phiole(n, farbe, "tempo")
				&"weckelixier": _weckphiole(n, farbe)
				&"staerkungstonikum": _eckflasche(n, farbe)
				&"gegengift": _kolben(n, farbe)
				&"waermetrank": _kalebasse(n, farbe)
				&"fluchbrecher": _fluchflasche(n, farbe)
				&"allheilmittel": _grossflasche(n, farbe, "krone")
				_:
					var stopfen := "kristall" if String(id).ends_with("manatrank") else "kork"
					if gross:
						_grossflasche(n, farbe, stopfen)
					else:
						_flasche(n, farbe, stopfen)
			if id == &"allheilmittel":
				Stil3D.teil(n, Stil3D.kugel(0.09), _p("gold"), Vector3(0, 0.2, 0.38), Vector3.ZERO, false,
					_p("glut") * 0.6)
	n.set_meta("icon_rand", RAND)
	return n


static func _halbkugel(r: float, hoehe: float) -> SphereMesh:
	var m := Stil3D.kugel(r, hoehe)
	m.is_hemisphere = true
	return m


## Glanzpunkt auf Glas (leuchtend, ohne Kontur).
static func _glanz(n: Node3D, r: float, pos: Vector3) -> void:
	Stil3D.teil(n, Stil3D.kugel(r, -1, 10), _p("weiss"), pos, Vector3.ZERO, false, _p("weiss") * 0.4)


## Runde Flasche (Heil-, Manatrank): Bauch in Trankfarbe (leicht
## leuchtend), Glashals, Stopfen, Glanzpunkt.
static func _flasche(n: Node3D, farbe: Color, stopfen := "kork") -> void:
	var r := 0.32
	Stil3D.teil(n, Stil3D.kugel(r), farbe, Vector3(0, r, 0), Vector3.ZERO, true, farbe * 0.28)
	Stil3D.teil(n, Stil3D.zylinder(0.11, 0.13, 0.26), _p("weiss") * 0.86, Vector3(0, r * 2.0 + 0.08, 0))
	_stopfen(n, stopfen, r * 2.0 + 0.21)
	_glanz(n, r * 0.22, Vector3(-r * 0.42, r * 1.38, r * 0.62))


## Stopfen auf dem Flaschenhals (y = Halsende): Korken; Kristall (Mana:
## spitzer Doppelkegel, ragt deutlich auf); Krone (Allheilmittel: Goldreif
## mit fünf Zacken).
static func _stopfen(n: Node3D, art: String, y: float) -> void:
	match art:
		"kristall":
			var hell := _p("stern")
			Stil3D.teil(n, Stil3D.kegel(0.12, 0.08, 4), hell, Vector3(0, y + 0.03, 0), Vector3(180, 45, 0), true,
				hell * 0.3)
			Stil3D.teil(n, Stil3D.kegel(0.12, 0.26, 4), hell, Vector3(0, y + 0.2, 0), Vector3(0, 45, 0), true,
				hell * 0.3)
		"krone":
			var gold := _p("gold")
			Stil3D.teil(n, Stil3D.zylinder(0.14, 0.12, 0.1), gold, Vector3(0, y + 0.04, 0))
			for i in 5:
				var w := TAU * i / 5.0 + 0.3
				Stil3D.teil(n, Stil3D.kegel(0.045, 0.14, 6), gold, Vector3(cos(w) * 0.11, y + 0.15, sin(w) * 0.11),
					Vector3.ZERO, true, _p("glut") * 0.3)
		_:
			Stil3D.teil(n, Stil3D.zylinder(0.1, 0.09, 0.14), _p("holz"), Vector3(0, y + 0.05, 0))


## Gegengift: Kolben (Kegelbauch, enger Hals), helles Etikett mit Blatt.
static func _kolben(n: Node3D, farbe: Color) -> void:
	Stil3D.teil(n, Stil3D.zylinder(0.13, 0.37, 0.52), farbe, Vector3(0, 0.26, 0), Vector3.ZERO, true, farbe * 0.28)
	Stil3D.teil(n, Stil3D.zylinder(0.1, 0.12, 0.2), _p("weiss") * 0.86, Vector3(0, 0.62, 0))
	_stopfen(n, "kork", 0.72)
	# Etikett auf der Schräge (Neigung wie die Kegelwand), Blatt darauf.
	Stil3D.teil(n, Stil3D.box(0.26, 0.15, 0.02), _p("pergament"), Vector3(0, 0.2, 0.28), Vector3(-25, 0, 0), false)
	Stil3D.teil(n, Stil3D.kugel(0.075, 0.05, 10), _p("moos_dunkel"), Vector3(0, 0.2, 0.3), Vector3(-25, 0, 40), false)
	_glanz(n, 0.05, Vector3(-0.15, 0.3, 0.22))


## Wärmetrank: Kürbisflasche (zwei Bäuche übereinander, Schnur um die
## Taille), Messinghals, Flammen-Zeichen auf dem unteren Bauch.
static func _kalebasse(n: Node3D, farbe: Color) -> void:
	Stil3D.teil(n, Stil3D.kugel(0.3), farbe, Vector3(0, 0.3, 0), Vector3.ZERO, true, farbe * 0.28)
	Stil3D.teil(n, Stil3D.kugel(0.2), farbe, Vector3(0, 0.7, 0), Vector3.ZERO, true, farbe * 0.28)
	Stil3D.teil(n, _ring(0.13, 0.19), _p("leder"), Vector3(0, 0.55, 0))
	Stil3D.teil(n, Stil3D.zylinder(0.08, 0.1, 0.12), _p("messing"), Vector3(0, 0.93, 0))
	_stopfen(n, "kork", 0.99)
	Stil3D.teil(n, Stil3D.kegel(0.08, 0.2, 8), _p("glut"), Vector3(0, 0.3, 0.27), Vector3(16, 0, 0), false,
		_p("glut") * 0.5)
	Stil3D.teil(n, Stil3D.kugel(0.08, 0.1), _p("glut"), Vector3(0, 0.22, 0.27), Vector3.ZERO, false, _p("glut") * 0.5)
	_glanz(n, 0.05, Vector3(-0.1, 0.8, 0.14))


## Fluchbrecher: hohe Sechskantflasche mit Schulter, Silberkreuz als Stopfen.
static func _fluchflasche(n: Node3D, farbe: Color) -> void:
	Stil3D.teil(n, Stil3D.zylinder(0.24, 0.27, 0.5, 6), farbe, Vector3(0, 0.25, 0), Vector3.ZERO, true, farbe * 0.28)
	Stil3D.teil(n, Stil3D.zylinder(0.1, 0.24, 0.12, 6), farbe, Vector3(0, 0.56, 0), Vector3.ZERO, true, farbe * 0.28)
	Stil3D.teil(n, Stil3D.zylinder(0.08, 0.1, 0.14), _p("weiss") * 0.86, Vector3(0, 0.68, 0))
	var silber := _p("silber")
	Stil3D.teil(n, Stil3D.box(0.08, 0.34, 0.07), silber, Vector3(0, 0.9, 0))
	Stil3D.teil(n, Stil3D.box(0.24, 0.08, 0.07), silber, Vector3(0, 0.95, 0))
	_glanz(n, 0.05, Vector3(-0.13, 0.36, 0.22))


## Große Flasche (Großer Heil-/Manatrank, Allheilmittel): andere FORM statt
## nur größer — flacher Boden, walzenförmiger Bauch mit breitem Goldband,
## Kuppelschulter und langer Hals mit Goldkragen; Stopfen wie die kleine
## Flasche (Mana: Kristall), Allheilmittel mit Krone.
static func _grossflasche(n: Node3D, farbe: Color, stopfen := "kork") -> void:
	Stil3D.teil(n, Stil3D.zylinder(0.37, 0.35, 0.36), farbe, Vector3(0, 0.18, 0), Vector3.ZERO, true, farbe * 0.28)
	Stil3D.teil(n, _halbkugel(0.37, 0.22), farbe, Vector3(0, 0.36, 0), Vector3.ZERO, true, farbe * 0.28)
	Stil3D.teil(n, Stil3D.zylinder(0.385, 0.375, 0.1), _p("gold"), Vector3(0, 0.19, 0), Vector3.ZERO, false)
	Stil3D.teil(n, Stil3D.zylinder(0.1, 0.12, 0.34), _p("weiss") * 0.86, Vector3(0, 0.72, 0))
	Stil3D.teil(n, Stil3D.zylinder(0.15, 0.15, 0.05), _p("gold"), Vector3(0, 0.58, 0))
	_stopfen(n, stopfen, 0.9)
	_glanz(n, 0.07, Vector3(-0.17, 0.46, 0.27))


## Eckige Flasche (Stärkungstonikum): Bernstein, Lederband, rotes Siegel.
static func _eckflasche(n: Node3D, farbe: Color) -> void:
	var k := Node3D.new()
	k.rotation_degrees = Vector3(0, -24, 0)
	n.add_child(k)
	Stil3D.teil(k, Stil3D.box(0.46, 0.5, 0.34), farbe, Vector3(0, 0.25, 0), Vector3.ZERO, true, farbe * 0.28)
	Stil3D.teil(k, Stil3D.prisma(0.46, 0.12, 0.34), farbe, Vector3(0, 0.56, 0), Vector3.ZERO, true, farbe * 0.28)
	Stil3D.teil(k, Stil3D.box(0.47, 0.1, 0.35), _p("leder"), Vector3(0, 0.3, 0), Vector3.ZERO, false)
	Stil3D.teil(k, Stil3D.zylinder(0.09, 0.11, 0.2), _p("weiss") * 0.86, Vector3(0, 0.68, 0))
	Stil3D.teil(k, Stil3D.zylinder(0.095, 0.085, 0.12), _p("holz"), Vector3(0, 0.82, 0))
	Stil3D.teil(k, Stil3D.kugel(0.11, 0.09), _p("daemon"), Vector3(0, 0.89, 0))
	_glanz(k, 0.06, Vector3(-0.14, 0.42, 0.18))


## Schlanke Phiole mit Flügeln. Belebungselixier: weiße Engelsflügel oben
## und goldener Heiligenschein; Tempotrunk: stark nach vorn geneigt,
## Flügel nach hinten gestrichen (Tempo) — andere Silhouette.
static func _phiole(n: Node3D, farbe: Color, art: String) -> void:
	var tempo := art == "tempo"
	var k := Node3D.new()
	k.rotation_degrees = Vector3(0, 0, -32 if tempo else -8)
	n.add_child(k)
	Stil3D.teil(k, Stil3D.kapsel(0.18, 0.8), farbe, Vector3(0, 0.42, 0), Vector3.ZERO, true, farbe * 0.3)
	Stil3D.teil(k, Stil3D.zylinder(0.09, 0.1, 0.18), _p("weiss") * 0.86, Vector3(0, 0.88, 0))
	Stil3D.teil(k, Stil3D.zylinder(0.1, 0.08, 0.12), _p("holz"), Vector3(0, 1.02, 0))
	_glanz(k, 0.05, Vector3(-0.08, 0.6, 0.15))
	var weiss := _p("weiss")
	if tempo:
		for nr in 3:  # Flügel an der Rückseite (links), nach hinten gestrichen
			Stil3D.teil(k, Stil3D.prisma(0.13, 0.44 - nr * 0.09, 0.03), weiss,
				Vector3(-0.3 - nr * 0.02, 0.66 - nr * 0.11, 0.06), Vector3(0, 0, 70.0 + nr * 16.0))
		return
	for seite in [-1.0, 1.0]:
		Stil3D.teil(k, Stil3D.prisma(0.5, 0.26, 0.03), weiss, Vector3(0.28 * seite, 0.62, 0.04),
			Vector3(0, 18.0 * seite, -62.0 * seite))
		Stil3D.teil(k, Stil3D.prisma(0.36, 0.2, 0.03), weiss, Vector3(0.25 * seite, 0.46, 0.05),
			Vector3(0, 18.0 * seite, -80.0 * seite))
	Stil3D.teil(k, _ring(0.12, 0.16), _p("gold"), Vector3(0, 1.2, 0), Vector3(-20, 0, 0), true, _p("glut") * 0.5)


static func _ring(innen: float, aussen: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = innen
	t.outer_radius = aussen
	t.rings = 24
	t.ring_segments = 6
	return t


## Weckelixier: bauchige kurze Phiole mit goldenem Glocken-Stopfen.
static func _weckphiole(n: Node3D, farbe: Color) -> void:
	Stil3D.teil(n, Stil3D.kapsel(0.25, 0.62), farbe, Vector3(0, 0.31, 0), Vector3.ZERO, true, farbe * 0.3)
	Stil3D.teil(n, Stil3D.zylinder(0.09, 0.11, 0.14), _p("weiss") * 0.86, Vector3(0, 0.67, 0))
	Stil3D.teil(n, _halbkugel(0.19, 0.24), _p("gold"), Vector3(0, 0.72, 0))
	Stil3D.teil(n, Stil3D.zylinder(0.21, 0.21, 0.04), _p("gold") * 0.85, Vector3(0, 0.73, 0), Vector3.ZERO, false)
	Stil3D.teil(n, Stil3D.kugel(0.06, -1, 10), _p("gold"), Vector3(0, 0.99, 0))
	_glanz(n, 0.06, Vector3(-0.1, 0.42, 0.2))


# --- Materialien -------------------------------------------------------------------

static func material_bauen(id: StringName) -> Node3D:
	var n := Node3D.new()
	var stufe := clampi(MaterialLibrary.stufe(id), 1, 5) - 1
	match MaterialLibrary.art(id):
		&"kraut": _kraut(n, id)
		&"erz": _erz(n, _p(ERZ_FARBE[stufe]), stufe)
		&"leder": _leder(n, _p(LEDER_FARBE[stufe]), stufe)
		&"kristall": _kristalle(n, _p(KRISTALL_FARBE[stufe]), stufe)
		&"rune": _rune(n, id)
		_: Stil3D.teil(n, Stil3D.kugel(0.3), _p("stein"), Vector3(0, 0.3, 0))
	match MaterialLibrary.art(id):
		&"erz":
			n.set_meta("icon_rand", RAND_ERZ)
			n.set_meta("icon_blick", BLICK_ERZ)
		&"leder":
			n.set_meta("icon_rand", RAND_LEDER)
		_:
			n.set_meta("icon_rand", RAND)
	return n


static func _kraut(n: Node3D, id: StringName) -> void:
	match id:
		&"manabluete":
			Stil3D.teil(n, Stil3D.zylinder(0.03, 0.035, 0.5), _p("farn"), Vector3(0, 0.25, 0))
			for i in 6:
				var w := TAU * i / 6.0
				Stil3D.teil(n, Stil3D.kugel(0.13, 0.08), _p("mana"), Vector3(cos(w) * 0.17, 0.58, sin(w) * 0.17),
					Vector3(0, -rad_to_deg(w), 25), true, _p("mana") * 0.25)
			Stil3D.teil(n, Stil3D.kugel(0.08), _p("glut"), Vector3(0, 0.6, 0), Vector3.ZERO, false, _p("glut") * 0.5)
		&"reinigungssalz":
			Stil3D.teil(n, Stil3D.kugel(0.3, 0.42), _p("leder"), Vector3(-0.1, 0.22, -0.05))
			for p in [Vector3(0.2, 0.08, 0.18), Vector3(0.32, 0.06, 0.02), Vector3(0.12, 0.05, 0.3),
					Vector3(0.26, 0.15, 0.12)]:
				Stil3D.teil(n, Stil3D.box(0.12, 0.12, 0.12), _p("weiss"), p, Vector3(20, 35, 10))
		_:  # Heilkraut: Blätterbüschel
			for i in 5:
				var w := -0.9 + i * 0.45
				Stil3D.teil(n, Stil3D.kugel(0.12, 0.5), _p("farn") * (0.9 + float(i % 2) * 0.18),
					Vector3(sin(w) * 0.18, 0.32, cos(w) * 0.05), Vector3(0, 0, -rad_to_deg(w) * 0.8))
			Stil3D.teil(n, Stil3D.box(0.3, 0.06, 0.1), _p("pilz_rot"), Vector3(0, 0.08, 0.04), Vector3.ZERO, false)


## Erzbrocken: Gestein leicht in der Stufenfarbe getönt, fünf große Adern-
## Kristalle in kräftiger Stufenfarbe (mit Kontur — bei 32 px sichtbar);
## Sternenmetall zusätzlich mit leuchtendem Stern.
static func _erz(n: Node3D, ader: Color, stufe: int) -> void:
	var stein := _p("stein_dunkel").lerp(ader, 0.12)
	Stil3D.teil(n, Stil3D.kugel(0.38, ERZ_HOEHE), stein, Vector3(0, ERZ_HOEHE * 0.5, 0))
	Stil3D.teil(n, Stil3D.box(0.3, 0.36, 0.3), stein * 0.9, Vector3(0.25, 0.2, 0.06), Vector3(10, 30, 15))
	Stil3D.teil(n, Stil3D.box(0.24, 0.28, 0.24), stein * 0.95, Vector3(-0.27, 0.15, 0.08), Vector3(-8, 20, -12))
	var leuchten := ader * (0.12 + 0.08 * stufe)
	for p in [Vector3(-0.13, 0.56, 0.22), Vector3(0.11, 0.66, 0.1), Vector3(0.27, 0.4, 0.2),
			Vector3(-0.27, 0.36, 0.18), Vector3(0.02, 0.3, 0.34)]:
		Stil3D.teil(n, Stil3D.prisma(0.19, 0.22, 0.17), ader, p, Vector3(25, 40, 15), true, leuchten)
	if stufe == 4:  # Sternenmetall: Stern über dem Brocken
		Stil3D.teil(n, Stil3D.kugel(0.08), _p("stern"), ERZ_STERN, Vector3.ZERO, false, _p("stern"))
		for w in [0.0, 90.0]:
			Stil3D.teil(n, Stil3D.box(0.3, 0.05, 0.03), _p("stern"), ERZ_STERN, Vector3(0, 0, w + 45.0),
				false, _p("stern"))


## Leder: Stufe 1 (Reste) als loser Haufen ungleicher Fetzen, ab Stufe 2
## als ordentlicher Stapel mit verschnürter Rolle (Farbe je Stufe).
static func _leder(n: Node3D, farbe: Color, stufe: int) -> void:
	if stufe == 0:  # flache, unregelmäßige Fetzen, mit Faden zusammengehalten
		for f in [[0.3, Vector3(-0.08, 0.03, 0.0), Vector3(0, 0, 0)],
				[0.24, Vector3(0.16, 0.09, 0.08), Vector3(14, 0, -10)],
				[0.2, Vector3(-0.16, 0.15, 0.12), Vector3(-10, 0, 16)],
				[0.15, Vector3(0.08, 0.2, -0.04), Vector3(8, 0, 6)]]:
			var r: float = f[0]
			Stil3D.teil(n, Stil3D.kugel(r, 0.07, 10), farbe * (0.92 + r * 0.6), f[1], f[2])
		Stil3D.teil(n, Stil3D.zylinder(0.025, 0.025, 0.42, 8), _p("braun_hell"), Vector3(0.0, 0.14, 0.06),
			Vector3(70, 0, 30))
		n.set_meta("icon_blick", BLICK_OBEN)  # flacher Haufen: von schräg oben
		return
	n.set_meta("icon_blick", BLICK_LEDER)  # Stapel von oben: Fläche statt Kante
	Stil3D.teil(n, Stil3D.box(0.7, 0.07, 0.5), farbe, Vector3(0, 0.04, 0), Vector3(0, 18, 0))
	Stil3D.teil(n, Stil3D.box(0.62, 0.07, 0.44), farbe * 1.12, Vector3(0.04, 0.12, 0.02), Vector3(0, -8, 4))
	Stil3D.teil(n, Stil3D.zylinder(0.13, 0.13, 0.6), farbe * 0.9, Vector3(-0.05, 0.28, -0.1), Vector3(0, 30, 90))
	Stil3D.teil(n, Stil3D.box(0.06, 0.3, 0.3), _p("braun"), Vector3(-0.05, 0.28, -0.1), Vector3(0, 30, 0), false)


## Kristalle: Stufe 1 (Kristallstaub) als glitzerndes Pulverhäufchen mit
## zwei Splittern, ab Stufe 2 als gefächerte Spitzen auf Gestein.
static func _kristalle(n: Node3D, farbe: Color, stufe: int) -> void:
	if stufe == 0:
		n.set_meta("icon_blick", BLICK_OBEN)
		Stil3D.teil(n, Stil3D.zylinder(0.48, 0.4, 0.1, 20), _p("holz"), Vector3(0, -0.04, 0))
		Stil3D.teil(n, Stil3D.kegel(0.4, 0.4, 18), farbe * 0.92, Vector3(0, 0.2, 0), Vector3.ZERO, true, farbe * 0.12)
		for p in [Vector3(-0.16, 0.14, 0.24), Vector3(0.12, 0.24, 0.16), Vector3(0.24, 0.1, 0.26), Vector3(-0.02, 0.32, 0.08),
				Vector3(-0.28, 0.06, 0.18)]:
			Stil3D.teil(n, Stil3D.box(0.06, 0.06, 0.06), _p("kristall"), p, Vector3(30, 45, 0), false, _p("kristall") * 0.6)
		for l in [[Vector3(0.08, 0.4, 0.02), -18.0, 0.07], [Vector3(-0.1, 0.34, 0.0), 24.0, 0.055]]:
			Stil3D.teil(n, Stil3D.kegel(l[2], 0.3, 6), farbe, l[0], Vector3(0, 0, l[1]), true, farbe * 0.2)
		return
	Stil3D.teil(n, Stil3D.zylinder(0.36, 0.42, 0.12, 10), _p("stein_dunkel"), Vector3(0, 0.06, 0))
	var leuchten := farbe * (0.2 + 0.1 * stufe)
	# Drei schlanke Sechskant-Spitzen, gefächert (Fuß, Neigung, Radius, Länge).
	var lagen := [[Vector3(0, 0.1, 0), Vector3(0, 0, -4), 0.1, 0.95],
		[Vector3(0.2, 0.1, 0.05), Vector3(0, 0, -34), 0.075, 0.62],
		[Vector3(-0.2, 0.1, 0.06), Vector3(0, 0, 30), 0.07, 0.55]]
	for l in lagen:
		var k := Node3D.new()
		k.position = l[0]
		k.rotation_degrees = l[1]
		n.add_child(k)
		var r: float = l[2]
		var laenge: float = l[3]
		Stil3D.teil(k, Stil3D.zylinder(r, r, laenge * 0.72, 6), farbe, Vector3(0, laenge * 0.36, 0),
			Vector3.ZERO, true, leuchten)
		Stil3D.teil(k, Stil3D.kegel(r, laenge * 0.28, 6), farbe.lightened(0.15), Vector3(0, laenge * 0.86, 0),
			Vector3.ZERO, true, leuchten)


## Runen: je Rune eigene Tafelform, Steinfarbe und Glyphe; Glyphe in der
## Seltenheitsfarbe nur schwach leuchtend (Orange bleibt Orange):
## Seltenheit = runder Stein mit Fehu, Pracht = Spitztafel (dunkel) mit
## Algiz, Legenden = hohe Tafel mit Goldrand und Othala, Regelbrecher =
## zerbrochene rötliche Tafel mit rotem Gebo-Kreuz.
static func _rune(n: Node3D, id: StringName) -> void:
	var farbe: Color = LootGenerator.RARITY_COLORS.get(MaterialLibrary.RUNEN_RARITAET.get(id, Enums.Rarity.RARE),
		_p("gold"))
	var k := Node3D.new()
	k.rotation_degrees = Vector3(0, -18, 0)
	k.position = Vector3(0, 0.42, 0)
	n.add_child(k)
	var vorn := 0.08
	var striche: Array = []
	match id:
		&"rune_episch":
			Stil3D.teil(k, Stil3D.box(0.56, 0.56, 0.14), _p("schatten"), Vector3(0, -0.08, 0))
			Stil3D.teil(k, Stil3D.prisma(0.56, 0.24, 0.14), _p("schatten"), Vector3(0, 0.32, 0))
			striche = [[Vector2(0, -0.26), Vector2(0, 0.24)], [Vector2(0, 0.02), Vector2(-0.16, 0.22)],
				[Vector2(0, 0.02), Vector2(0.16, 0.22)]]
		&"rune_legendaer":
			Stil3D.teil(k, Stil3D.box(0.6, 0.86, 0.1), _p("gold") * 0.8, Vector3(0, 0, -0.04))
			Stil3D.teil(k, Stil3D.box(0.5, 0.76, 0.14), _p("stein_dunkel"), Vector3.ZERO)
			striche = [[Vector2(0, 0.3), Vector2(0.15, 0.13)], [Vector2(0.15, 0.13), Vector2(0, -0.04)],
				[Vector2(0, -0.04), Vector2(-0.15, 0.13)], [Vector2(-0.15, 0.13), Vector2(0, 0.3)],
				[Vector2(0, -0.04), Vector2(0.16, -0.28)], [Vector2(0, -0.04), Vector2(-0.16, -0.28)]]
		&"rune_regel":
			farbe = _p("boss_siegel")
			var stein := _p("stein_dunkel").lerp(_p("daemon"), 0.35)
			Stil3D.teil(k, Stil3D.box(0.3, 0.74, 0.14), stein, Vector3(-0.17, 0.0, 0), Vector3(0, 0, 5))
			Stil3D.teil(k, Stil3D.box(0.28, 0.7, 0.14), stein * 0.92, Vector3(0.18, -0.03, 0), Vector3(0, 0, -6))
			striche = [[Vector2(-0.2, -0.24), Vector2(0.2, 0.24)], [Vector2(-0.2, 0.24), Vector2(0.2, -0.24)]]
		_:  # rune_selten
			Stil3D.teil(k, Stil3D.zylinder(0.36, 0.36, 0.14, 24), _p("stein"), Vector3.ZERO, Vector3(90, 0, 0))
			striche = [[Vector2(-0.07, -0.24), Vector2(-0.07, 0.24)], [Vector2(-0.07, 0.04), Vector2(0.13, 0.17)],
				[Vector2(-0.07, -0.1), Vector2(0.13, 0.03)]]
	for st in striche:
		var a: Vector2 = st[0]
		var z: Vector2 = st[1]
		var d := z - a
		Stil3D.teil(k, Stil3D.box(0.075, d.length() + 0.07, 0.03), farbe, Vector3((a.x + z.x) * 0.5, (a.y + z.y) * 0.5,
			vorn), Vector3(0, 0, rad_to_deg(atan2(-d.x, d.y))), false, farbe * 0.35)


# --- Symbole: Gold, Mini-Medaille, Schatzkarte ---------------------------------------

const SYMBOLE: Array[StringName] = [&"gold", &"medaille", &"schatzkarte"]


static func symbol_bauen(id: StringName) -> Node3D:
	var n := Node3D.new()
	match id:
		&"medaille": _medaille(n)
		&"schatzkarte": _schatzkarte(n)
		_: _muenzen(n)
	n.set_meta("icon_rand", RAND)
	return n


## Gold: Münzstapel, davor eine stehende Münze mit Prägung.
static func _muenzen(n: Node3D) -> void:
	var gold := _p("gold")
	for i in 4:
		Stil3D.teil(n, Stil3D.zylinder(0.27, 0.27, 0.075, 24), gold * (0.92 + 0.04 * (i % 2)),
			Vector3(-0.12 + 0.025 * (i % 2), 0.04 + i * 0.08, -0.06))
	var k := Node3D.new()
	k.position = Vector3(0.2, 0.27, 0.16)
	k.rotation_degrees = Vector3(80, -18, 0)
	n.add_child(k)
	Stil3D.teil(k, Stil3D.zylinder(0.26, 0.26, 0.075, 24), gold, Vector3.ZERO)
	Stil3D.teil(k, Stil3D.zylinder(0.15, 0.15, 0.09, 20), _p("messing"), Vector3.ZERO, Vector3.ZERO, false)
	_glanz(n, 0.04, Vector3(0.1, 0.42, 0.24))


## Mini-Medaille: Goldscheibe mit Stern, zweifarbiges Band darüber.
static func _medaille(n: Node3D) -> void:
	var gold := _p("gold")
	var mitte := Vector3(0, 0.32, 0)
	Stil3D.teil(n, Stil3D.box(0.13, 0.34, 0.03), _p("umhang"), Vector3(-0.08, 0.66, -0.04), Vector3(0, 0, 18))
	Stil3D.teil(n, Stil3D.box(0.13, 0.34, 0.03), _p("mana"), Vector3(0.08, 0.66, -0.04), Vector3(0, 0, -18))
	Stil3D.teil(n, Stil3D.zylinder(0.32, 0.32, 0.07, 28), gold, mitte, Vector3(90, 0, 0))
	Stil3D.teil(n, Stil3D.zylinder(0.24, 0.24, 0.08, 28), _p("messing"), mitte, Vector3(90, 0, 0), false)
	for i in 5:  # fünfzackiger Stern aus Prismen
		var w := TAU * i / 5.0
		var d := Vector3(sin(w), cos(w), 0)
		Stil3D.teil(n, Stil3D.prisma(0.1, 0.15, 0.03), _p("messing_hell"), mitte + d * 0.09 + Vector3(0, 0, 0.05),
			Vector3(0, 0, -rad_to_deg(w)), false, _p("glut") * 0.25)
	Stil3D.teil(n, Stil3D.kugel(0.06, 0.04, 10), _p("messing_hell"), mitte + Vector3(0, 0, 0.05), Vector3(90, 0, 0),
		false)


## Schatzkarte: Pergament mit eingerollten Rändern, rotes Kreuz, Wegpunkte.
static func _schatzkarte(n: Node3D) -> void:
	var k := Node3D.new()
	k.position = Vector3(0, 0.34, 0)
	k.rotation_degrees = Vector3(-12, -14, 0)
	n.add_child(k)
	Stil3D.teil(k, Stil3D.box(0.66, 0.5, 0.02), _p("pergament"), Vector3.ZERO)
	for seite in [-1.0, 1.0]:
		Stil3D.teil(k, Stil3D.zylinder(0.06, 0.06, 0.54, 12), _p("pergament_dunkel"), Vector3(0.36 * seite, 0, 0.02))
	var rot := _p("umhang")
	for w in [45.0, -45.0]:
		Stil3D.teil(k, Stil3D.box(0.05, 0.2, 0.02), rot, Vector3(0.14, 0.08, 0.02), Vector3(0, 0, w), false)
	for p in [Vector2(-0.22, -0.16), Vector2(-0.12, -0.1), Vector2(-0.03, -0.03), Vector2(0.05, 0.03)]:
		Stil3D.teil(k, Stil3D.box(0.045, 0.045, 0.02), _p("tinte"), Vector3(p.x, p.y, 0.02), Vector3.ZERO, false)


# --- Biom-Miniaturen (Kartenlager) -------------------------------------------------

## Wandkrone und Deko je Biom für die Miniatur (aus BiomKulisse).
const BIOM_TEILE := {
	Enums.Biome.FOREST: [["tanne_paar", "laubbaum"], ["pilzgruppe", "farn"]],
	Enums.Biome.CAVE: [["tropfsteine", "kristalle"], ["kristallgruppe", "knochenhaufen"]],
	Enums.Biome.RUINS: [["zinnen", "saeulenstumpf"], ["saeulentrommel", "truemmer"]],
	Enums.Biome.CRYPT: [["gruftaufsatz", "kreuz"], ["grabstein_schief", "kerzen"]],
	Enums.Biome.INFERNAL: [["obsidianzacken", "hoernerpaar"], ["obsidiangruppe", "lavaspalt"]],
}


static func biom_bauen(biome: int) -> Node3D:
	var stil := BiomStil.fuer(biome)
	var teile: Array = BIOM_TEILE.get(int(stil["biom"]), BIOM_TEILE[Enums.Biome.FOREST])
	var b := Bausatz.new()
	# Plattenstück mit Wandstück dahinter (Bodenfarbe, Wandfarbe des Bioms).
	b.fasenbox(Vector3(1.5, 0.16, 1.2), 0.04, stil["boden"], Transform3D(Basis(), Vector3(0, -0.08, 0)))
	b.fasenbox(Vector3(1.5, 0.42, 0.42), 0.04, stil["wand"], Transform3D(Basis(), Vector3(0, 0.21, -0.39)))
	b.fasenbox(Vector3(1.52, 0.06, 0.44), 0.02, stil["deckel"], Transform3D(Basis(), Vector3(0, 0.45, -0.39)))
	var kronen: Array = teile[0]
	b.bausatz(BiomKulisse.krone(kronen[0], stil), Transform3D(Basis(), Vector3(-0.38, 0.48, -0.39)))
	b.bausatz(BiomKulisse.krone(kronen[1], stil), Transform3D(Basis(), Vector3(0.38, 0.48, -0.39)))
	var deko: Array = teile[1]
	b.bausatz(BiomKulisse.deko(deko[0], stil), Transform3D(Basis(), Vector3(-0.3, 0.0, 0.22)))
	b.bausatz(BiomKulisse.deko(deko[1], stil), Transform3D(Basis(), Vector3(0.36, 0.0, 0.28)))
	var n := b.knoten("Biom")
	n.set_meta("icon_blick", Vector3(1.6, 2.4, 3.6))
	return n
