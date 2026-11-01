class_name BiomKulisse
extends RefCounted
## Biom-Kulisse aus Grundkörpern (STIL-3D.md Abschnitt 5b/7b): Wandkronen
## (Wald Tannen, Höhle Tropfsteine/Kristalle, Ruinen Zinnen/Säulenstümpfe/
## Bruchkanten, Krypta Gruftaufsätze/Kreuze/Grabplatten), die Boden-Deko
## des Dungeons und die Hallen-Säule für die Kampfbühne. Alles als Bausatz
## gebacken (ein Mesh + Kontur-Hülle je Variante), damit der Dungeon jede
## Variante als EIN MultiMesh zeichnen kann. Reine Optik.
##
## Ursprung: Kronen stehen mit y = 0 auf dem Wanddeckel (Zellmitte), Deko
## mit y = 0 auf dem Boden; beide bleiben im Feld (Radius ≤ 0.6 bzw. 0.45).

## Deko-Varianten, die auch in schmalen Gängen stehen dürfen (flach/klein —
## der Weg bleibt frei lesbar).
const FLACH := ["farn", "pilzgruppe", "pfuetze", "kerzen", "knochenhaufen", "truemmer"]
const KRONEN := ["tanne", "tanne_paar", "laubbaum", "tropfsteine", "kristalle", "zinnen",
	"saeulenstumpf", "bruchkante", "gruftaufsatz", "kreuz", "grabplatte"]
const DEKO := ["farn", "pilzgruppe", "wurzel", "felsgruppe", "kristallgruppe", "tropfstein_klein",
	"pfuetze", "knochenhaufen", "saeulentrommel", "kistenstapel", "fassgruppe", "truemmer",
	"sarkophag", "grabstein_schief", "kerzen"]
const SAEULEN := ["baum", "tropfstein", "saeule", "gruftpfeiler"]


static func _p(name: String) -> Color:
	return Stil3D.farbe(name)


static func _zyl(r_oben: float, r_unten: float, hoehe: float, segmente := 10) -> CylinderMesh:
	var m := Stil3D.zylinder(r_oben, r_unten, hoehe)
	m.radial_segments = segmente
	return m


static func _kapsel(r: float, hoehe: float) -> CapsuleMesh:
	var m := Stil3D.kapsel(r, hoehe)
	m.radial_segments = 8
	m.rings = 2
	return m


static func _kugel(r: float, hoehe := -1.0, segmente := 10) -> SphereMesh:
	var m := Stil3D.kugel(r, hoehe)
	m.radial_segments = segmente
	m.rings = maxi(4, segmente / 2)
	return m


# --- Wandkronen ------------------------------------------------------------------

## Wandkrone einer Art; stil = BiomStil.fuer(biom) (Steinfarben des Bioms).
static func krone(art: String, stil: Dictionary) -> Bausatz:
	var b := Bausatz.new()
	var stein: Color = stil.get("wand", _p("stein"))
	var deckel: Color = stil.get("deckel", _p("stein"))
	match art:
		"tanne":
			_tanne(b, Vector3.ZERO, 1.0)
		"tanne_paar":
			_tanne(b, Vector3(-0.2, 0, -0.12), 0.82)
			_tanne(b, Vector3(0.22, 0, 0.16), 0.66)
		"laubbaum":
			b.teil(_zyl(0.07, 0.1, 0.5, 8), _p("braun"), Vector3(0, 0.25, 0))
			b.teil(_kugel(0.36, 0.56), _p("tanne"), Vector3(0, 0.72, 0))
			b.teil(_kugel(0.26, 0.42), _p("tanne_hell"), Vector3(0.2, 0.86, 0.12))
			b.teil(_kugel(0.24, 0.38), _p("moos"), Vector3(-0.18, 0.62, 0.16))
		"tropfsteine":
			var s := stein.lerp(_p("stein_hell"), 0.45)
			b.teil(_zyl(0.0, 0.2, 0.78, 7), s, Vector3(0, 0.39, 0))
			b.teil(_zyl(0.0, 0.14, 0.48, 7), s * 0.92, Vector3(0.24, 0.24, 0.14))
			b.teil(_zyl(0.0, 0.12, 0.36, 7), s * 1.05, Vector3(-0.2, 0.18, -0.12))
			b.teil(_zyl(0.0, 0.09, 0.26, 6), s, Vector3(-0.08, 0.13, 0.27))
		"kristalle":
			b.teil(_kugel(0.3, 0.2, 8), stein, Vector3(0, 0.07, 0))
			_kristall(b, Vector3(0, 0.05, 0), Vector3(8, 0, -6), 0.11, 0.7, _p("kristall"))
			_kristall(b, Vector3(0.17, 0.04, 0.08), Vector3(-10, 30, 28), 0.08, 0.46, _p("kristall"))
			_kristall(b, Vector3(-0.16, 0.04, 0.1), Vector3(14, 0, -30), 0.07, 0.38, _p("kristall") * 0.9)
			_kristall(b, Vector3(-0.05, 0.03, -0.18), Vector3(-26, 0, 8), 0.06, 0.3, _p("lila"))
		"zinnen":
			var z := stein.lerp(_p("stein_hell"), 0.3)
			b.teil(Stil3D.box(1.0, 0.1, 0.34), z * 0.92, Vector3(0, 0.05, 0))
			for x in [-0.3, 0.3]:
				b.teil(Stil3D.box(0.3, 0.26, 0.34), z, Vector3(x, 0.23, 0))
				b.teil(Stil3D.box(0.34, 0.05, 0.38), z * 1.08, Vector3(x, 0.385, 0))
		"saeulenstumpf":
			var m := _p("marmor").lerp(stein, 0.15)
			b.teil(Stil3D.box(0.56, 0.12, 0.56), m * 0.88, Vector3(0, 0.06, 0))
			b.teil(_zyl(0.24, 0.26, 0.08, 12), m * 0.95, Vector3(0, 0.16, 0))
			b.teil(_zyl(0.19, 0.21, 0.66, 8), m, Vector3(0, 0.53, 0))
			b.teil(_zyl(0.17, 0.19, 0.16, 8), m * 0.95, Vector3(0.03, 0.93, 0.0), Vector3(0, 0, 10))
			b.teil(Stil3D.box(0.3, 0.12, 0.3), m * 1.02, Vector3(0.24, 0.12, 0.22), Vector3(10, 30, 6))
		"bruchkante":
			var r := deckel * 1.1
			b.teil(Stil3D.box(0.36, 0.34, 0.38), r, Vector3(-0.22, 0.17, 0.04), Vector3(0, 8, 4))
			b.teil(Stil3D.box(0.3, 0.2, 0.32), r * 0.92, Vector3(0.18, 0.1, -0.1), Vector3(0, -12, -6))
			b.teil(Stil3D.box(0.22, 0.14, 0.2), r * 1.05, Vector3(-0.18, 0.4, 0.0), Vector3(10, 25, 14))
			b.teil(Stil3D.box(0.16, 0.1, 0.16), r * 0.95, Vector3(0.26, 0.05, 0.24), Vector3(0, 40, 0))
		"gruftaufsatz":
			var g := deckel.lerp(_p("stein_hell"), 0.35)
			b.teil(Stil3D.box(0.62, 0.08, 0.54), g * 0.9, Vector3(0, 0.04, 0))
			b.teil(Stil3D.box(0.5, 0.42, 0.44), g, Vector3(0, 0.29, 0))
			b.teil(Stil3D.prisma(0.62, 0.24, 0.54), g * 1.08, Vector3(0, 0.62, 0))
			b.teil(Stil3D.box(0.18, 0.28, 0.04), _p("nacht"), Vector3(0, 0.22, 0.225), Vector3.ZERO, false)
			b.teil(_kugel(0.035, -1.0, 6), _p("seele"), Vector3(0, 0.42, 0.24), Vector3.ZERO, false, 0.9)
			b.teil(Stil3D.box(0.06, 0.18, 0.06), g * 1.15, Vector3(0, 0.82, 0))
			b.teil(Stil3D.box(0.16, 0.05, 0.06), g * 1.15, Vector3(0, 0.86, 0))
		"kreuz":
			var k := deckel.lerp(_p("stein_hell"), 0.4)
			b.teil(Stil3D.box(0.3, 0.12, 0.3), k * 0.88, Vector3(0, 0.06, 0))
			b.teil(Stil3D.box(0.1, 0.66, 0.1), k, Vector3(0, 0.45, 0))
			b.teil(Stil3D.box(0.38, 0.1, 0.1), k, Vector3(0, 0.6, 0))
		"grabplatte":
			var gp := deckel.lerp(_p("stein_hell"), 0.35)
			b.teil(Stil3D.box(0.42, 0.56, 0.09), gp, Vector3(0.05, 0.27, 0), Vector3(-14, 10, 6))
			b.teil(Stil3D.box(0.3, 0.42, 0.08), gp * 0.9, Vector3(-0.2, 0.2, 0.18), Vector3(10, -24, -8))
			b.teil(Stil3D.box(0.14, 0.03, 0.02), _p("seele"), Vector3(0.05, 0.36, 0.06), Vector3(-14, 10, 6),
				false, 0.7)
		_:
			push_error("BiomKulisse: unbekannte Krone " + art)
	return b


static func _tanne(b: Bausatz, pos: Vector3, s: float) -> void:
	b.teil(_zyl(0.06 * s, 0.09 * s, 0.36 * s, 7), _p("braun"), pos + Vector3(0, 0.18 * s, 0))
	var lagen := [[0.5, 0.56, 0.5, 1.0], [0.4, 0.5, 0.82, 1.08], [0.28, 0.44, 1.1, 1.18]]
	for l in lagen:
		var farbe: Color = _p("tanne") * float(l[3]) if l[3] < 1.1 else _p("tanne_hell")
		b.teil(_zyl(0.0, float(l[0]) * s, float(l[1]) * s, 9), farbe, pos + Vector3(0, float(l[2]) * s, 0))


static func _kristall(b: Bausatz, fuss: Vector3, rot: Vector3, r: float, h: float, farbe: Color) -> void:
	var basis := Basis.from_euler(rot * (PI / 180.0))
	b.teil(_zyl(r * 0.85, r, h, 6), farbe, fuss + basis * Vector3(0, h * 0.5, 0), rot, true, 0.45)
	b.teil(_zyl(0.0, r * 0.85, r * 1.6, 6), farbe * 1.15, fuss + basis * Vector3(0, h + r * 0.8, 0), rot, true, 0.6)


# --- Boden-Deko --------------------------------------------------------------------

## Biomtypische Deko-Gruppe (größer und dichter als ein Einzelstück).
static func deko(art: String, stil: Dictionary) -> Bausatz:
	var b := Bausatz.new()
	var stein: Color = stil.get("wand", _p("stein"))
	match art:
		"farn":
			for i in 7:
				var w := TAU * i / 7.0 + 0.3
				var l := 0.34 + float(i % 3) * 0.05
				b.teil(Stil3D.box(0.09, 0.02, l), _p("farn") * (0.9 + float(i % 2) * 0.15),
					Vector3(sin(w) * l * 0.42, 0.1 + float(i % 2) * 0.03, cos(w) * l * 0.42),
					Vector3(-32, rad_to_deg(w), 0))
			b.teil(_kugel(0.07, 0.08, 6), _p("moos_dunkel"), Vector3(0, 0.03, 0), Vector3.ZERO, false)
		"pilzgruppe":
			for t in [[Vector3(0, 0, 0), 1.0], [Vector3(0.2, 0, 0.12), 0.65], [Vector3(-0.16, 0, 0.17), 0.5],
					[Vector3(-0.12, 0, -0.2), 0.75]]:
				var p: Vector3 = t[0]
				var s: float = t[1]
				b.teil(_zyl(0.045 * s, 0.06 * s, 0.22 * s, 8), _p("knochen"), p + Vector3(0, 0.11 * s, 0))
				b.teil(_kugel(0.16 * s, 0.13 * s), _p("pilz_rot"), p + Vector3(0, 0.24 * s, 0))
				b.teil(_kugel(0.025 * s, -1.0, 6), _p("weiss"), p + Vector3(0.07 * s, 0.29 * s, 0.05 * s),
					Vector3.ZERO, false)
		"wurzel":
			b.teil(_zyl(0.17, 0.21, 0.26, 10), _p("braun"), Vector3(0, 0.13, 0))
			b.teil(_zyl(0.15, 0.15, 0.02, 10), _p("holz_hell"), Vector3(0, 0.265, 0), Vector3.ZERO, false)
			for i in 4:
				var w := TAU * i / 4.0 + 0.5
				b.teil(_kapsel(0.045, 0.36), _p("braun") * 0.9, Vector3(sin(w) * 0.24, 0.05, cos(w) * 0.24),
					Vector3(78, rad_to_deg(w), 0))
		"felsgruppe":
			b.teil(_kugel(0.24, 0.3), stein * 0.9, Vector3(0, 0.13, 0))
			b.teil(_kugel(0.15, 0.17), stein, Vector3(0.24, 0.07, 0.1))
			b.teil(_kugel(0.1, 0.12), stein * 1.05, Vector3(-0.2, 0.05, 0.2))
			b.teil(_kugel(0.16, 0.06), _p("moos"), Vector3(-0.03, 0.27, 0.02), Vector3.ZERO, false)
		"kristallgruppe":
			b.teil(_kugel(0.24, 0.16, 8), stein, Vector3(0, 0.03, 0))
			_kristall(b, Vector3(0, 0.03, 0), Vector3(6, 0, -8), 0.09, 0.42, _p("kristall"))
			_kristall(b, Vector3(0.14, 0.02, 0.08), Vector3(-12, 0, 30), 0.065, 0.28, _p("kristall"))
			_kristall(b, Vector3(-0.13, 0.02, 0.07), Vector3(18, 0, -26), 0.06, 0.24, _p("lila"))
			_kristall(b, Vector3(0.02, 0.02, -0.16), Vector3(-28, 0, 4), 0.05, 0.2, _p("kristall") * 0.9)
		"tropfstein_klein":
			b.teil(_zyl(0.0, 0.14, 0.5, 7), stein * 1.1, Vector3(0, 0.25, 0))
			b.teil(_zyl(0.0, 0.1, 0.32, 7), stein, Vector3(0.18, 0.16, 0.1))
			b.teil(_zyl(0.0, 0.08, 0.22, 7), stein * 1.05, Vector3(-0.14, 0.11, 0.14))
		"pfuetze":
			b.teil(_zyl(0.36, 0.36, 0.015, 14), _p("wasser"), Vector3(0, 0.008, 0), Vector3.ZERO, false, 0.15)
			b.teil(_zyl(0.17, 0.17, 0.017, 12), _p("wasser") * 1.1, Vector3(0.26, 0.009, 0.16), Vector3.ZERO,
				false, 0.15)
			b.teil(_kugel(0.07, 0.07, 6), stein, Vector3(-0.3, 0.03, 0.1))
			b.teil(_kugel(0.05, 0.05, 6), stein * 1.1, Vector3(0.05, 0.02, -0.33))
		"knochenhaufen":
			b.teil(_kugel(0.11, 0.12), _p("knochen"), Vector3(0, 0.07, 0))
			for x in [-0.04, 0.04]:
				b.teil(_kugel(0.024, -1.0, 6), _p("schwarz"), Vector3(x, 0.09, 0.095), Vector3.ZERO, false)
			b.teil(_kugel(0.08, 0.09), _p("knochen") * 0.95, Vector3(-0.2, 0.05, 0.14), Vector3(0, 0, 0))
			for t in [[Vector3(0.18, 0.03, -0.04), Vector3(90, 40, 0)], [Vector3(-0.08, 0.03, -0.18), Vector3(90, -60, 0)],
					[Vector3(0.1, 0.07, 0.16), Vector3(70, 10, 0)]]:
				b.teil(_kapsel(0.025, 0.3), _p("knochen"), t[0], t[1])
		"saeulentrommel":
			var m := _p("marmor") * 0.92
			b.teil(_zyl(0.22, 0.22, 0.36, 10), m, Vector3(0.05, 0.22, 0.02), Vector3(0, 0, 90))
			b.teil(_zyl(0.22, 0.24, 0.26, 10), m * 1.04, Vector3(-0.18, 0.13, -0.2))
			b.teil(Stil3D.box(0.16, 0.1, 0.14), m * 0.9, Vector3(0.28, 0.05, -0.22), Vector3(0, 30, 0))
		"kistenstapel":
			_kiste(b, Vector3(0, 0, 0), 0.32, 12.0)
			_kiste(b, Vector3(-0.02, 0.32, 0.02), 0.24, -18.0)
			_kiste(b, Vector3(0.26, 0, -0.2), 0.2, 35.0)
		"fassgruppe":
			_fass(b, Vector3(-0.1, 0, -0.05), 1.0)
			_fass(b, Vector3(0.2, 0, 0.14), 0.75)
			b.teil(_zyl(0.12, 0.12, 0.3, 10), _p("braun_hell") * 0.9, Vector3(-0.12, 0.12, 0.26), Vector3(0, 30, 90))
		"truemmer":
			var t := stein * 1.05
			b.teil(Stil3D.box(0.22, 0.12, 0.18), t, Vector3(0, 0.06, 0), Vector3(0, 20, 6))
			b.teil(Stil3D.box(0.14, 0.09, 0.16), t * 0.9, Vector3(0.2, 0.045, 0.14), Vector3(0, -30, 0))
			b.teil(Stil3D.box(0.12, 0.07, 0.1), t * 1.1, Vector3(-0.2, 0.035, 0.12), Vector3(0, 50, -8))
			b.teil(Stil3D.box(0.09, 0.06, 0.09), t, Vector3(-0.05, 0.03, -0.22), Vector3(0, 10, 0))
		"sarkophag":
			var g := stein * 1.25
			b.teil(Stil3D.box(0.46, 0.28, 0.84), g * 0.88, Vector3(0, 0.14, 0))
			b.teil(Stil3D.box(0.52, 0.09, 0.9), g, Vector3(0, 0.325, 0))
			b.teil(Stil3D.box(0.36, 0.05, 0.7), g * 1.08, Vector3(0, 0.39, 0))
			b.teil(Stil3D.box(0.05, 0.02, 0.44), _p("seele"), Vector3(0, 0.42, 0.02), Vector3.ZERO, false, 0.55)
			b.teil(Stil3D.box(0.24, 0.02, 0.05), _p("seele"), Vector3(0, 0.42, -0.1), Vector3.ZERO, false, 0.55)
		"grabstein_schief":
			b.teil(Stil3D.box(0.34, 0.42, 0.1), stein * 1.2, Vector3(0, 0.2, -0.1), Vector3(-10, 0, 7))
			b.teil(_zyl(0.17, 0.17, 0.1, 12), stein * 1.2, Vector3(-0.026, 0.41, -0.065), Vector3(80, 0, 7))
			b.teil(_kugel(0.3, 0.12, 10), stein * 0.95, Vector3(0, 0.02, 0.16))
			b.teil(Stil3D.box(0.12, 0.03, 0.02), _p("nacht"), Vector3(0, 0.28, -0.04), Vector3(-10, 0, 7), false)
		"kerzen":
			for t in [[Vector3(0, 0, 0), 0.26], [Vector3(0.14, 0, 0.09), 0.17], [Vector3(-0.12, 0, 0.12), 0.13],
					[Vector3(-0.06, 0, -0.15), 0.2], [Vector3(0.17, 0, -0.1), 0.1]]:
				var p: Vector3 = t[0]
				var h: float = t[1]
				b.teil(_zyl(0.035, 0.04, h, 8), _p("kerze"), p + Vector3(0, h * 0.5, 0))
				b.teil(_kugel(0.03, 0.06, 6), _p("flamme"), p + Vector3(0, h + 0.035, 0), Vector3.ZERO, false, 1.0)
			b.teil(_zyl(0.2, 0.24, 0.02, 12), _p("kerze") * 0.85, Vector3(0, 0.01, 0), Vector3.ZERO, false)
		_:
			push_error("BiomKulisse: unbekannte Deko " + art)
	return b


static func _kiste(b: Bausatz, fuss: Vector3, g: float, dreh: float) -> void:
	var rot := Vector3(0, dreh, 0)
	var basis := Basis.from_euler(rot * (PI / 180.0))
	b.teil(Stil3D.box(g, g, g), _p("braun_hell"), fuss + Vector3(0, g * 0.5, 0), rot)
	for s in [-1.0, 1.0]:
		b.teil(Stil3D.box(g * 0.12, g * 1.06, g * 1.06), _p("braun"), fuss + basis * Vector3(s * g * 0.4, g * 0.5, 0),
			rot, false)
	b.teil(Stil3D.box(g * 1.06, g * 0.1, g * 1.06), _p("braun"), fuss + Vector3(0, g * 0.5, 0), rot, false)


static func _fass(b: Bausatz, fuss: Vector3, s: float) -> void:
	b.teil(_zyl(0.14 * s, 0.14 * s, 0.4 * s, 12), _p("braun_hell"), fuss + Vector3(0, 0.2 * s, 0))
	b.teil(_zyl(0.16 * s, 0.16 * s, 0.2 * s, 12), _p("braun_hell") * 1.05, fuss + Vector3(0, 0.2 * s, 0))
	for y in [0.07, 0.33]:
		b.teil(_zyl(0.148 * s, 0.148 * s, 0.03 * s, 12), _p("eisen") * 0.8, fuss + Vector3(0, y * s, 0), Vector3.ZERO, false)
	b.teil(_zyl(0.12 * s, 0.12 * s, 0.01, 12), _p("knochen") * 0.8, fuss + Vector3(0, 0.4 * s + 0.005, 0), Vector3.ZERO, false)


## Die Dungeon-Deko-Variante einer Zelle: der Generator wählt die Art
## (Platzierung unverändert), die Kulisse daraus eine Biom-Variante nach
## Zell-Hash; schmal = in Gängen nur flache Varianten (Weg bleibt frei).
static func deko_variante(stil: Dictionary, art: String, zelle: Vector2i, schmal: bool) -> String:
	var kulisse: Dictionary = stil.get("kulisse", {})
	var varianten: Dictionary = kulisse.get("deko_varianten", {})
	var liste: Array = varianten.get(art, [])
	if liste.is_empty():
		return ""
	if schmal:
		var flach := liste.filter(func(v: String) -> bool: return v in FLACH)
		if not flach.is_empty():
			liste = flach
	return String(liste[absi(hash(zelle * 17 + Vector2i(5, 3))) % liste.size()])


# --- Hallen-Säule (Kampfbühne, Paket 3) ---------------------------------------------

## Säule/Baum/Tropfstein/Gruftpfeiler der Biom-Kulisse in voller Höhe
## (Fuß bei y = 0) — BiomStil "kulisse"/"saeule" wählt die Art.
static func saeule(stil: Dictionary, hoehe := 4.4) -> Node3D:
	var kulisse: Dictionary = stil.get("kulisse", {})
	var art: String = kulisse.get("saeule", "saeule")
	var stein: Color = stil.get("wand", _p("stein"))
	var b := Bausatz.new()
	match art:
		"baum":
			b.teil(_zyl(0.3, 0.42, hoehe * 0.7, 10), _p("braun"), Vector3(0, hoehe * 0.35, 0))
			for i in 3:
				var w := TAU * i / 3.0
				b.teil(_kapsel(0.1, 0.7), _p("braun") * 0.9, Vector3(sin(w) * 0.4, 0.14, cos(w) * 0.4),
					Vector3(75, rad_to_deg(w), 0))
			for l in 3:
				b.teil(_zyl(0.0, 1.3 - l * 0.32, 1.3, 10), _p("tanne") * (1.0 + l * 0.06),
					Vector3(0, hoehe * 0.6 + l * 0.75, 0))
		"tropfstein":
			b.teil(_zyl(0.0, 0.62, hoehe * 0.58, 8), stein * 1.1, Vector3(0, hoehe * 0.29, 0))
			b.teil(_zyl(0.62, 0.0, hoehe * 0.48, 8), stein, Vector3(0, hoehe - hoehe * 0.24, 0))
			_kristall(b, Vector3(0.45, 0.08, 0.2), Vector3(-8, 0, 24), 0.14, 0.7, _p("kristall"))
			_kristall(b, Vector3(-0.42, 0.08, 0.26), Vector3(10, 0, -22), 0.11, 0.5, _p("kristall"))
		"gruftpfeiler":
			b.teil(Stil3D.box(1.0, 0.3, 1.0), stein * 0.9, Vector3(0, 0.15, 0))
			b.teil(Stil3D.box(0.76, hoehe - 0.6, 0.76), stein * 1.1, Vector3(0, hoehe * 0.5, 0))
			b.teil(Stil3D.box(1.0, 0.3, 1.0), stein * 0.95, Vector3(0, hoehe - 0.15, 0))
			b.teil(Stil3D.box(0.34, 0.5, 0.06), _p("nacht"), Vector3(0, hoehe * 0.55, 0.39), Vector3.ZERO, false)
			b.teil(_kugel(0.08, -1.0, 8), _p("seele"), Vector3(0, hoehe * 0.53, 0.38), Vector3.ZERO, false, 0.9)
		_:
			var m := _p("marmor") * 0.92
			b.teil(Stil3D.box(1.0, 0.28, 1.0), m * 0.85, Vector3(0, 0.14, 0))
			b.teil(_zyl(0.42, 0.48, hoehe - 0.56, 12), m, Vector3(0, hoehe * 0.5, 0))
			b.teil(Stil3D.box(1.1, 0.28, 1.1), m * 1.05, Vector3(0, hoehe - 0.14, 0))
	return b.knoten("Saeule_" + art)
