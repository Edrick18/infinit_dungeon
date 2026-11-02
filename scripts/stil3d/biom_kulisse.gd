class_name BiomKulisse
extends RefCounted
## Biom-Kulisse aus Grundkörpern (STIL-3D.md Abschnitt 5b/7b): Wandkronen
## (Wald Tannen, Höhle Tropfsteine/Kristalle, Ruinen Zinnen/Säulenstümpfe/
## Bruchkanten, Krypta Gruftaufsätze/Kreuze/Grabplatten, Höllenschlund
## Obsidianzacken/Hörnerpaare/Glutschlote), die Boden-Deko
## des Dungeons und die Hallen-Säule für die Kampfbühne. Alles als Bausatz
## gebacken (ein Mesh + Kontur-Hülle je Variante), damit der Dungeon jede
## Variante als EIN MultiMesh zeichnen kann. Reine Optik.
##
## Ursprung: Kronen stehen mit y = 0 auf dem Wanddeckel (Zellmitte), Deko
## mit y = 0 auf dem Boden; beide bleiben im Feld (Radius ≤ 0.6 bzw. 0.45).

## Deko-Varianten, die auch in schmalen Gängen stehen dürfen (flach/klein —
## der Weg bleibt frei lesbar).
const FLACH := ["farn", "pilzgruppe", "pfuetze", "kerzen", "knochenhaufen", "truemmer", "blutlache", "muenzen",
	"lavaspalt"]
const KRONEN := ["tanne", "tanne_paar", "laubbaum", "tropfsteine", "kristalle", "zinnen",
	"saeulenstumpf", "bruchkante", "gruftaufsatz", "kreuz", "grabplatte", "obsidianzacken", "hoernerpaar",
	"glutschlot"]
const DEKO := ["farn", "pilzgruppe", "wurzel", "felsgruppe", "kristallgruppe", "tropfstein_klein",
	"pfuetze", "knochenhaufen", "saeulentrommel", "kistenstapel", "fassgruppe", "truemmer",
	"sarkophag", "grabstein_schief", "kerzen", "spinnweben", "blutlache", "muenzen", "obsidiangruppe",
	"lavaspalt"]
const SAEULEN := ["baum", "tropfstein", "saeule", "gruftpfeiler", "hoellenpfeiler"]


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
		"obsidianzacken":
			b.teil(_kugel(0.3, 0.2, 8), stein.lerp(_p("nacht"), 0.25), Vector3(0, 0.07, 0))
			_kristall(b, Vector3(0, 0.05, 0), Vector3(6, 0, -8), 0.11, 0.66, _p("obsidian"))
			_kristall(b, Vector3(0.17, 0.04, 0.09), Vector3(-12, 30, 26), 0.08, 0.42, _p("obsidian") * 1.2)
			_kristall(b, Vector3(-0.16, 0.04, 0.1), Vector3(16, 0, -28), 0.07, 0.36, _p("obsidian"))
			b.teil(_kugel(0.05, -1.0, 6), _p("flamme"), Vector3(0.02, 0.12, 0.2), Vector3.ZERO, false, 0.9)
		"hoernerpaar":
			b.teil(Stil3D.box(0.5, 0.12, 0.4), stein * 0.9, Vector3(0, 0.06, 0))
			for seite in [-1.0, 1.0]:
				_horn(b, Vector3(0.14 * seite, 0.1, 0), seite, 0.7, 0.09)
		"glutschlot":
			var basalt := stein * 0.85
			b.teil(_zyl(0.17, 0.24, 0.42, 9), basalt, Vector3(0, 0.21, 0))
			b.teil(_zyl(0.21, 0.17, 0.08, 9), basalt * 1.1, Vector3(0, 0.44, 0))
			b.teil(_zyl(0.13, 0.13, 0.02, 9), _p("flamme"), Vector3(0, 0.485, 0), Vector3.ZERO, false, 1.0)
			b.teil(_kugel(0.07, 0.08, 6), _p("glut"), Vector3(0, 0.5, 0), Vector3.ZERO, false, 1.0)
			for i in 3:
				var w := TAU * i / 3.0 + 0.4
				b.teil(Stil3D.box(0.03, 0.18, 0.02), _p("flamme"), Vector3(sin(w) * 0.2, 0.32, cos(w) * 0.2),
					Vector3(0, rad_to_deg(w), 0), false, 0.8)
		_:
			push_error("BiomKulisse: unbekannte Krone " + art)
	return b


static func _tanne(b: Bausatz, pos: Vector3, s: float) -> void:
	b.teil(_zyl(0.06 * s, 0.09 * s, 0.36 * s, 7), _p("braun"), pos + Vector3(0, 0.18 * s, 0))
	var lagen := [[0.5, 0.56, 0.5, 1.0], [0.4, 0.5, 0.82, 1.08], [0.28, 0.44, 1.1, 1.18]]
	for l in lagen:
		var farbe: Color = _p("tanne") * float(l[3]) if l[3] < 1.1 else _p("tanne_hell")
		b.teil(_zyl(0.0, float(l[0]) * s, float(l[1]) * s, 9), farbe, pos + Vector3(0, float(l[2]) * s, 0))


## Gebogenes Horn (Höllenschlund): Kegelkette, zuerst nach außen geneigt,
## dann zur Mitte zurück, mit glühender Spitze.
static func _horn(b: Bausatz, fuss: Vector3, seite: float, laenge: float, r: float) -> void:
	var lage := Transform3D(Basis.from_euler(Vector3(0, 0, deg_to_rad(-25.0 * seite))), fuss)
	Gliederpuppe.kette(b, lage, 4, laenge, r, r * 0.22, Vector3(0, 0, 12.0 * seite), _p("knochen") * 0.75,
		_p("flamme"), 0.6)


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
		"obsidiangruppe":
			b.teil(_kugel(0.24, 0.14, 8), stein.lerp(_p("nacht"), 0.25), Vector3(0, 0.03, 0))
			_kristall(b, Vector3(0, 0.03, 0), Vector3(6, 0, -8), 0.09, 0.4, _p("obsidian"))
			_kristall(b, Vector3(0.14, 0.02, 0.08), Vector3(-12, 0, 30), 0.065, 0.26, _p("obsidian") * 1.2)
			_kristall(b, Vector3(-0.13, 0.02, 0.07), Vector3(18, 0, -26), 0.06, 0.22, _p("obsidian"))
			b.teil(_kugel(0.04, -1.0, 6), _p("flamme"), Vector3(0.05, 0.05, 0.16), Vector3.ZERO, false, 0.9)
		"lavaspalt":
			# Aufgerissene Basaltplatte mit glühenden Spalten (flach, begehbar).
			b.teil(_zyl(0.36, 0.38, 0.03, 12), stein * 0.6, Vector3(0, 0.015, 0), Vector3.ZERO, false)
			for t in [[Vector3(0, 0.032, 0), 0.5, 20.0], [Vector3(0.1, 0.032, 0.12), 0.28, -40.0],
					[Vector3(-0.12, 0.032, -0.08), 0.24, 70.0]]:
				b.teil(Stil3D.box(float(t[1]), 0.012, 0.035), _p("flamme"), t[0], Vector3(0, float(t[2]), 0), false, 1.0)
		"spinnweben":
			# Netz in der Wandecke: Speichen und Ringfäden, an die Wand gelehnt
			# (Rückseite lokal -z), dazu Staubflocken am Boden (Karten-Variante
			# „Vergessener“). Steht nur in breiten Zellen (nicht FLACH).
			var faden := _p("geist")
			var mitte := Vector3(0, 0.38, -0.3)
			var kipp := Basis(Vector3.RIGHT, deg_to_rad(-18.0))
			for i in 7:
				var w := -1.35 + float(i) * 0.45
				var richtung := kipp * Vector3(sin(w), cos(w), 0.0)
				b.teil_t(Stil3D.box(0.022, 0.36, 0.022), faden, Transform3D(kipp * Basis(Vector3.BACK, -w),
					mitte + richtung * 0.18), false, 0.3)
			for r in [0.09, 0.18, 0.27]:
				for i in 6:
					var w := -1.35 + float(i) * 0.45
					var a: Vector3 = Vector3(sin(w), cos(w), 0.0) * r
					var z: Vector3 = Vector3(sin(w + 0.45), cos(w + 0.45), 0.0) * r
					var winkel := atan2(z.y - a.y, z.x - a.x)
					b.teil_t(Stil3D.box(a.distance_to(z) + 0.01, 0.018, 0.018), faden,
						Transform3D(kipp * Basis(Vector3.BACK, winkel), mitte + kipp * ((a + z) * 0.5)), false, 0.3)
			for v in [Vector3(0.12, 0.01, -0.12), Vector3(-0.16, 0.01, -0.05), Vector3(0.02, 0.01, 0.1)]:
				b.teil(_kugel(0.07, 0.025, 6), _p("stein_hell") * 0.85, v, Vector3.ZERO, false)
		"blutlache":
			var blut := _p("drachenblut") * 0.7
			b.teil(_zyl(0.3, 0.3, 0.014, 14), blut, Vector3(0, 0.007, 0), Vector3.ZERO, false)
			b.teil(_zyl(0.14, 0.14, 0.016, 12), blut * 0.85, Vector3(0.24, 0.008, 0.14), Vector3.ZERO, false)
			b.teil(_zyl(0.07, 0.07, 0.016, 10), blut * 0.9, Vector3(-0.22, 0.008, -0.16), Vector3.ZERO, false)
		"muenzen":
			# Verstreute Münzen und ein kleiner Haufen (Karten-Variante „der Gier“).
			b.teil(_kugel(0.12, 0.08, 10), _p("gold") * 0.9, Vector3(0, 0.02, 0))
			for t in [[Vector3(0.18, 0.006, 0.08), 10.0], [Vector3(-0.15, 0.006, 0.12), -20.0],
					[Vector3(0.05, 0.006, -0.2), 35.0], [Vector3(-0.2, 0.006, -0.1), 0.0],
					[Vector3(0.22, 0.03, -0.12), 70.0]]:
				b.teil(_zyl(0.045, 0.045, 0.012, 10), _p("gold"), t[0], Vector3(float(t[1]) * 0.3, 0, float(t[1])),
					true, 0.15)
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


# --- Kampfhalle (Paket 3) ------------------------------------------------------------

## Säule/Baum/Tropfstein/Gruftpfeiler der Biom-Kulisse in voller Höhe
## (Fuß bei y = 0) — BiomStil "kulisse"/"saeule" wählt die Art.
static func saeule(stil: Dictionary, hoehe := 4.4) -> Node3D:
	var kulisse: Dictionary = stil.get("kulisse", {})
	return saeule_bausatz(stil, hoehe).knoten("Saeule_" + String(kulisse.get("saeule", "saeule")))


## Die Hallen-Säule als Bausatz (die Kampfhalle backt alle Säulen in EIN Mesh).
static func saeule_bausatz(stil: Dictionary, hoehe := 4.4) -> Bausatz:
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
		"hoellenpfeiler":
			var basalt := stein * 0.9
			b.teil(Stil3D.box(1.0, 0.3, 1.0), basalt * 0.85, Vector3(0, 0.15, 0))
			b.teil(_zyl(0.36, 0.44, hoehe - 0.6, 6), basalt, Vector3(0, hoehe * 0.5, 0))
			b.teil(Stil3D.box(1.0, 0.3, 1.0), basalt * 0.95, Vector3(0, hoehe - 0.15, 0))
			for i in 3:
				b.teil(Stil3D.box(0.03, 0.5, 0.02), _p("flamme"), Vector3(-0.1 + i * 0.1, hoehe * (0.3 + 0.15 * i), 0.38),
					Vector3(0, 0, 15.0 - i * 15.0), false, 1.0)
			for seite in [-1.0, 1.0]:
				_horn(b, Vector3(0.36 * seite, hoehe - 0.05, 0), seite, 0.9, 0.12)
		_:
			var m := _p("marmor") * 0.92
			b.teil(Stil3D.box(1.0, 0.28, 1.0), m * 0.85, Vector3(0, 0.14, 0))
			b.teil(_zyl(0.42, 0.48, hoehe - 0.56, 12), m, Vector3(0, hoehe * 0.5, 0))
			b.teil(Stil3D.box(1.1, 0.28, 1.1), m * 1.05, Vector3(0, hoehe - 0.14, 0))
	return b


## Halbe Dicke der Hallen-Säule auf Fackelhöhe (Fackelhalter sitzt davor).
const SAEULE_RADIUS := {"baum": 0.36, "tropfstein": 0.24, "gruftpfeiler": 0.4, "saeule": 0.46,
	"hoellenpfeiler": 0.42}


## Biom-Kulisse HINTER der Kampfhalle: ein Ring großer Biom-Stücke (Wald
## Tannen/Laubbäume/Felsen, Höhle Stalagmiten/Kristallgruppen, Ruinen
## Mauerreste/Säulen/Trommeln, Krypta Grüfte/Kreuze/Grabplatten). stellen =
## KampfHalle.kulisse_stellen() ({"pos", "dreh", "s", "nr"}). Maße stehen im
## Mesh (s skaliert die Grundkörper, nie den Knoten) — EIN Bausatz.
static func hallen_kulisse(stil: Dictionary, stellen: Array) -> Bausatz:
	var b := Bausatz.new()
	var kulisse: Dictionary = stil.get("kulisse", {})
	var art: String = kulisse.get("saeule", "saeule")
	var stein: Color = stil.get("wand", _p("stein"))
	var deckel: Color = stil.get("deckel", _p("stein"))
	for stelle: Dictionary in stellen:
		var g := Bausatz.new()
		var s: float = stelle["s"]
		var nr: int = stelle["nr"]
		match art:
			"baum":
				if nr % 5 == 3:
					g.teil(_zyl(0.12 * s, 0.17 * s, 0.9 * s, 8), _p("braun"), Vector3(0, 0.45 * s, 0))
					g.teil(_kugel(0.6 * s, 0.9 * s), _p("tanne"), Vector3(0, 1.2 * s, 0))
					g.teil(_kugel(0.42 * s, 0.66 * s), _p("tanne_hell"), Vector3(0.3 * s, 1.42 * s, 0.18 * s))
				elif nr % 7 == 5:
					g.teil(_kugel(0.5 * s, 0.6 * s), stein * 0.9, Vector3(0, 0.25 * s, 0))
					g.teil(_kugel(0.3 * s, 0.34 * s), stein, Vector3(0.45 * s, 0.14 * s, 0.2 * s))
					g.teil(_kugel(0.36 * s, 0.12 * s), _p("moos"), Vector3(-0.05 * s, 0.53 * s, 0.03 * s),
						Vector3.ZERO, false)
				else:
					_tanne(g, Vector3.ZERO, s)
					if nr % 3 == 0:
						_tanne(g, Vector3(0.5 * s, 0, 0.3 * s), s * 0.6)
			"tropfstein":
				var t := stein.lerp(_p("stein_hell"), 0.3)
				g.teil(_zyl(0.0, 0.45 * s, 1.9 * s, 8), t * (0.95 + float(nr % 3) * 0.05), Vector3(0, 0.95 * s, 0))
				g.teil(_zyl(0.0, 0.26 * s, 1.0 * s, 7), t * 0.9, Vector3(0.45 * s, 0.5 * s, 0.15 * s))
				if nr % 3 == 0:
					_kristall(g, Vector3(-0.4 * s, 0.02, 0.2 * s), Vector3(10, 0, -24), 0.14 * s, 0.8 * s,
						_p("kristall"))
					_kristall(g, Vector3(-0.2 * s, 0.02, 0.4 * s), Vector3(-16, 0, 12), 0.09 * s, 0.5 * s, _p("lila"))
			"saeule":
				var m := _p("marmor").lerp(stein, 0.25)
				if nr % 3 == 0:
					var h := (1.0 + float(nr % 4) * 0.35) * s
					g.teil(Stil3D.box(0.8 * s, 0.2 * s, 0.8 * s), m * 0.85, Vector3(0, 0.1 * s, 0))
					g.teil(_zyl(0.3 * s, 0.33 * s, h, 10), m, Vector3(0, 0.2 * s + h * 0.5, 0))
					g.teil(Stil3D.box(0.5 * s, 0.24 * s, 0.4 * s), m * 0.92, Vector3(0.5 * s, 0.12 * s, 0.3 * s),
						Vector3(0, 30, 10))
				else:
					# Mauerrest: gestaffelte Quader mit gebrochener Oberkante.
					for i in 4:
						var hoehe := (0.6 + float((nr * 3 + i * 5) % 7) * 0.22) * s
						g.teil(Stil3D.box(0.62 * s, hoehe, 0.42 * s), deckel * (1.0 + float(i % 2) * 0.08),
							Vector3((float(i) - 1.5) * 0.6 * s, hoehe * 0.5, 0))
					g.teil(Stil3D.box(0.4 * s, 0.26 * s, 0.34 * s), deckel * 1.05, Vector3(0.3 * s, 0.13 * s, 0.5 * s),
						Vector3(0, 25, 8))
			"gruftpfeiler":
				var k := deckel.lerp(_p("stein_hell"), 0.3)
				if nr % 3 == 0:
					# Gruft: Kasten, Satteldach, dunkle Tür mit Seelenlicht.
					g.teil(Stil3D.box(1.2 * s, 0.9 * s, 0.9 * s), k * 0.9, Vector3(0, 0.45 * s, 0))
					g.teil(Stil3D.prisma(1.4 * s, 0.5 * s, 1.0 * s), k, Vector3(0, 1.15 * s, 0))
					g.teil(Stil3D.box(0.36 * s, 0.56 * s, 0.04), _p("nacht"), Vector3(0, 0.3 * s, 0.46 * s),
						Vector3.ZERO, false)
					g.teil(_kugel(0.05 * s, -1.0, 6), _p("seele"), Vector3(0, 0.62 * s, 0.47 * s), Vector3.ZERO,
						false, 0.9)
				elif nr % 3 == 1:
					g.teil(Stil3D.box(0.42 * s, 0.16 * s, 0.42 * s), k * 0.85, Vector3(0, 0.08 * s, 0))
					g.teil(Stil3D.box(0.14 * s, 1.2 * s, 0.14 * s), k, Vector3(0, 0.76 * s, 0))
					g.teil(Stil3D.box(0.6 * s, 0.14 * s, 0.14 * s), k, Vector3(0, 1.0 * s, 0))
				else:
					g.teil(Stil3D.box(0.6 * s, 0.8 * s, 0.12 * s), k, Vector3(0, 0.38 * s, 0), Vector3(-10, 0, 6))
					g.teil(Stil3D.box(0.5 * s, 0.6 * s, 0.11 * s), k * 0.9, Vector3(0.6 * s, 0.28 * s, 0.25 * s),
						Vector3(8, -20, -8))
			"hoellenpfeiler":
				var basalt := stein * 0.9
				if nr % 3 == 0:
					# Obsidian-Zacken auf einem Basaltbuckel.
					g.teil(_kugel(0.6 * s, 0.4 * s, 8), basalt, Vector3(0, 0.2 * s, 0))
					_kristall(g, Vector3(0, 0.05, 0), Vector3(6, 0, -8), 0.22 * s, 1.5 * s, _p("obsidian"))
					_kristall(g, Vector3(0.4 * s, 0.03, 0.2 * s), Vector3(-14, 0, 26), 0.15 * s, 0.9 * s,
						_p("obsidian") * 1.2)
					_kristall(g, Vector3(-0.35 * s, 0.03, 0.25 * s), Vector3(16, 0, -24), 0.13 * s, 0.7 * s, _p("obsidian"))
				elif nr % 3 == 1:
					# Hörnerbogen: zwei riesige Hörner aus einem Sockel.
					g.teil(Stil3D.box(1.0 * s, 0.25 * s, 0.6 * s), basalt * 0.85, Vector3(0, 0.12 * s, 0))
					for seite in [-1.0, 1.0]:
						_horn(g, Vector3(0.3 * s * seite, 0.2 * s, 0), seite, 1.7 * s, 0.18 * s)
				else:
					# Glutschlot: dicker Kamin mit glühendem Rand.
					g.teil(_zyl(0.35 * s, 0.55 * s, 1.1 * s, 9), basalt, Vector3(0, 0.55 * s, 0))
					g.teil(_zyl(0.4 * s, 0.35 * s, 0.16 * s, 9), basalt * 1.1, Vector3(0, 1.15 * s, 0))
					g.teil(_zyl(0.26 * s, 0.26 * s, 0.03 * s, 9), _p("flamme"), Vector3(0, 1.24 * s, 0), Vector3.ZERO,
						false, 1.0)
		b.bausatz(g, Transform3D(Basis(Vector3.UP, float(stelle["dreh"])), stelle["pos"]))
	return b
