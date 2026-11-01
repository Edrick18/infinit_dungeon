class_name VorratIcons
extends RefCounted
## Icons für Verbrauchsgüter (Tränke, Salben, Verband …), Materialien
## (Kräuter, Erze, Leder, Kristalle, Runen) und Biome (Kartenlager) im
## STIL-3D-Look: kleine Figuren aus Grundkörpern, die PortraitStudio EINMAL
## in eine Textur rendert (wie GegenstandIcons und KlotzIcons).
## Biom-Miniaturen sind Bausatz-Dioramen aus derselben BiomKulisse wie der
## Dungeon (Plattenstück + Wandkrone + Deko) — der Ort ist sofort erkennbar.

## Flüssigkeitsfarbe je Trank (PAL-Namen); unbekannte nach Wirkung.
const TRANK_FARBE := {
	&"heiltrank": "pilz_rot", &"grosser_heiltrank": "pilz_rot",
	&"manatrank": "mana", &"grosser_manatrank": "mana",
	&"belebungselixier": "glut", &"gegengift": "moos", &"weckelixier": "glut",
	&"tempotrunk": "kristall", &"staerkungstonikum": "daemon", &"waermetrank": "flamme",
	&"fluchbrecher": "lila", &"allheilmittel": "seele",
}
## Werkstoff-Farbe je Stufe 1..5 (PAL-Namen) für Erze, Leder, Kristalle.
const ERZ_FARBE := ["eisen", "silber", "kristall", "smaragd", "lila"]
const LEDER_FARBE := ["leder", "braun_hell", "smaragd", "drachenblut", "obsidian"]
const KRISTALL_FARBE := ["weiss", "silber", "gold", "seele", "lila"]


static func _p(name: String) -> Color:
	return Stil3D.farbe(name)


static func trank(studio: PortraitStudio, id: StringName) -> Texture2D:
	return studio.textur("trank|%s" % id, func() -> Node3D: return trank_bauen(id))


static func material(studio: PortraitStudio, id: StringName) -> Texture2D:
	return studio.textur("material|%s" % id, func() -> Node3D: return material_bauen(id))


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
			var gross := String(id).begins_with("grosser") or id == &"allheilmittel"
			if id == &"belebungselixier" or id == &"weckelixier" or id == &"tempotrunk":
				_phiole(n, farbe, id == &"belebungselixier")
			else:
				_flasche(n, farbe, gross)
			if id == &"tempotrunk":
				for seite in [-1.0, 1.0]:
					Stil3D.teil(n, Stil3D.prisma(0.32, 0.16, 0.03), _p("weiss"),
						Vector3(0.2 * seite, 0.52, -0.02), Vector3(0, 0, -60.0 * seite))
			if id == &"allheilmittel":
				Stil3D.teil(n, Stil3D.kugel(0.08), _p("gold"), Vector3(0, 0.36, 0.33), Vector3.ZERO, false,
					_p("glut") * 0.6)
	return n


## Bauchige Flasche: Bauch in Trankfarbe (leicht leuchtend), Glashals,
## Korken, Glanzpunkt; groß = größerer Bauch mit Goldring.
static func _flasche(n: Node3D, farbe: Color, gross: bool) -> void:
	var r := 0.4 if gross else 0.32
	Stil3D.teil(n, Stil3D.kugel(r), farbe, Vector3(0, r, 0), Vector3.ZERO, true, farbe * 0.28)
	Stil3D.teil(n, Stil3D.zylinder(0.11, 0.13, 0.26), _p("weiss") * 0.86, Vector3(0, r * 2.0 + 0.08, 0))
	Stil3D.teil(n, Stil3D.zylinder(0.1, 0.09, 0.14), _p("holz"), Vector3(0, r * 2.0 + 0.26, 0))
	Stil3D.teil(n, Stil3D.kugel(r * 0.22), _p("weiss"), Vector3(-r * 0.42, r * 1.38, r * 0.62),
		Vector3.ZERO, false, _p("weiss") * 0.4)
	if gross:
		Stil3D.teil(n, Stil3D.zylinder(0.15, 0.15, 0.05), _p("gold"), Vector3(0, r * 2.0 + 0.0, 0))


## Schlanke Phiole: hoher Zylinder mit Kuppe, schräg; Elixier mit Flügeln.
static func _phiole(n: Node3D, farbe: Color, fluegel: bool) -> void:
	var k := Node3D.new()
	k.rotation_degrees = Vector3(0, 0, -12)
	n.add_child(k)
	Stil3D.teil(k, Stil3D.kapsel(0.18, 0.8), farbe, Vector3(0, 0.42, 0), Vector3.ZERO, true, farbe * 0.3)
	Stil3D.teil(k, Stil3D.zylinder(0.09, 0.1, 0.18), _p("weiss") * 0.86, Vector3(0, 0.88, 0))
	Stil3D.teil(k, Stil3D.zylinder(0.1, 0.08, 0.12), _p("holz"), Vector3(0, 1.02, 0))
	Stil3D.teil(k, Stil3D.kugel(0.05), _p("weiss"), Vector3(-0.08, 0.6, 0.15), Vector3.ZERO, false, _p("weiss") * 0.4)
	if fluegel:
		for seite in [-1.0, 1.0]:
			Stil3D.teil(k, Stil3D.prisma(0.36, 0.2, 0.03), _p("gold"), Vector3(0.22 * seite, 0.5, -0.03),
				Vector3(0, 0, -64.0 * seite), true, _p("glut") * 0.25)


# --- Materialien -------------------------------------------------------------------

static func material_bauen(id: StringName) -> Node3D:
	var n := Node3D.new()
	var stufe := clampi(MaterialLibrary.stufe(id), 1, 5) - 1
	match MaterialLibrary.art(id):
		&"kraut": _kraut(n, id)
		&"erz": _erz(n, _p(ERZ_FARBE[stufe]), stufe)
		&"leder": _leder(n, _p(LEDER_FARBE[stufe]))
		&"kristall": _kristalle(n, _p(KRISTALL_FARBE[stufe]), stufe)
		&"rune": _rune(n, id)
		_: Stil3D.teil(n, Stil3D.kugel(0.3), _p("stein"), Vector3(0, 0.3, 0))
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


static func _erz(n: Node3D, ader: Color, stufe: int) -> void:
	Stil3D.teil(n, Stil3D.kugel(0.38, 0.5), _p("stein_dunkel"), Vector3(0, 0.25, 0))
	Stil3D.teil(n, Stil3D.box(0.3, 0.28, 0.28), _p("stein_dunkel") * 0.92, Vector3(0.26, 0.18, 0.08),
		Vector3(10, 30, 15))
	var leuchten := ader * (0.15 + 0.12 * stufe)
	for p in [Vector3(-0.12, 0.38, 0.28), Vector3(0.14, 0.44, 0.2), Vector3(0.32, 0.28, 0.2), Vector3(-0.26, 0.24, 0.2)]:
		Stil3D.teil(n, Stil3D.prisma(0.13, 0.16, 0.13), ader, p, Vector3(25, 40, 15), false, leuchten)
	if stufe == 4:  # Sternenmetall: kleiner Stern
		Stil3D.teil(n, Stil3D.kugel(0.07), _p("stern"), Vector3(0.05, 0.62, 0.15), Vector3.ZERO, false, _p("stern"))


static func _leder(n: Node3D, farbe: Color) -> void:
	Stil3D.teil(n, Stil3D.box(0.7, 0.07, 0.5), farbe, Vector3(0, 0.04, 0), Vector3(0, 18, 0))
	Stil3D.teil(n, Stil3D.box(0.62, 0.07, 0.44), farbe * 1.12, Vector3(0.04, 0.12, 0.02), Vector3(0, -8, 4))
	Stil3D.teil(n, Stil3D.zylinder(0.13, 0.13, 0.6), farbe * 0.9, Vector3(-0.05, 0.28, -0.1), Vector3(0, 30, 90))
	Stil3D.teil(n, Stil3D.box(0.06, 0.3, 0.3), _p("braun"), Vector3(-0.05, 0.28, -0.1), Vector3(0, 30, 0), false)


static func _kristalle(n: Node3D, farbe: Color, stufe: int) -> void:
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


static func _rune(n: Node3D, id: StringName) -> void:
	var farbe: Color = _p("glut") if id == &"rune_regel" \
		else LootGenerator.RARITY_COLORS.get(MaterialLibrary.RUNEN_RARITAET.get(id, Enums.Rarity.RARE), _p("gold"))
	Stil3D.teil(n, Stil3D.box(0.62, 0.74, 0.16), _p("stein_dunkel"), Vector3(0, 0.4, 0), Vector3(0, 12, 0))
	var k := Node3D.new()
	k.rotation_degrees = Vector3(0, 12, 0)
	k.position = Vector3(0, 0.4, 0.085)
	n.add_child(k)
	Stil3D.teil(k, Stil3D.box(0.07, 0.48, 0.02), farbe, Vector3(0, 0, 0), Vector3.ZERO, false, farbe * 0.9)
	Stil3D.teil(k, Stil3D.box(0.3, 0.06, 0.02), farbe, Vector3(0.06, 0.12, 0), Vector3(0, 0, 32), false, farbe * 0.9)
	Stil3D.teil(k, Stil3D.box(0.24, 0.06, 0.02), farbe, Vector3(-0.06, -0.1, 0), Vector3(0, 0, -32), false, farbe * 0.9)


# --- Biom-Miniaturen (Kartenlager) -------------------------------------------------

## Wandkrone und Deko je Biom für die Miniatur (aus BiomKulisse).
const BIOM_TEILE := {
	Enums.Biome.FOREST: [["tanne_paar", "laubbaum"], ["pilzgruppe", "farn"]],
	Enums.Biome.CAVE: [["tropfsteine", "kristalle"], ["kristallgruppe", "knochenhaufen"]],
	Enums.Biome.RUINS: [["zinnen", "saeulenstumpf"], ["saeulentrommel", "truemmer"]],
	Enums.Biome.CRYPT: [["gruftaufsatz", "kreuz"], ["grabstein_schief", "kerzen"]],
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
