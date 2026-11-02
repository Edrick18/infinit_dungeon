class_name BiomStil
extends RefCounted
## Biom-Stimmung der 3D-Welt (STIL-3D.md, Abschnitt 5b) — EIN Datensatz je
## Biom für Material, Licht und Untergrund. Reine Anzeige: Spiellogik,
## Generator und Balance lesen ihn nie.
##
## Farben stehen als PAL-Namen drin (Hauspalette, Stil3D.PAL) und werden in
## fuer() aufgelöst; Lichtfarben sind reine Lichtwerte (keine Flächenfarben).
## Schlüssel:
##   floor_tint / wall_tint / deco — Tönung + Deko-Arten (auch Kampfbühne)
##   boden / wand / deckel / moos   — Flächenfarben (PAL) der Dungeon-Welt
##   muster   — Mauerwerk: 0 Ziegel, 1 Bruchstein, 2 Gruftquader
##   stein    — Steinmaß (Breite, Höhe) für Ziegel/Quader in Welteinheiten
##   moos_wand / moos_deckel — Bewuchs von unten bzw. auf dem Deckel (0..1)
##   fuge     — Leuchtfarbe der Fugen/Runen (PAL), glimmt in Heldennähe
##   ambient / ambient_energie — Umgebungslicht (Schattenseiten nie schwarz)
##   licht / licht_energie — Hauptlicht (Sonne), laterne — Heldenlaterne
##   tief / nebel — Untergrund (Sternen-Nebel unter der Karte, PAL)
##   partikel — Atmosphäre: gluehwuermchen | tropfen | asche | irrlicht
##   funke    — Partikelfarbe (PAL)
##   kulisse  — Biom-Kulisse (BiomKulisse): "saeule" = Hallen-Säule der
##              Kampfbühne (baum | tropfstein | saeule | gruftpfeiler),
##              "kronen" = Wandkronen-Varianten, "krone_anteil" = Anteil der
##              Wände mit Krone (per Zell-Hash), "deko_varianten" = je
##              Generator-Deko-Art die Modell-Varianten im Dungeon
##   biom     — (nur in fuer()) Enums.Biome des Datensatzes
##   Varianten-Schlüssel (GRUNDWERTE) und Kartenvarianten: fuer_karte()

const DATEN := {
	Enums.Biome.FOREST: {
		"floor_tint": Color(0.88, 1.0, 0.82), "wall_tint": Color(0.85, 1.0, 0.88),
		"deco": ["pilz", "felsbrocken"],
		"boden": "wald_boden", "wand": "wald_wand", "deckel": "wald_deckel", "moos": "wald_moos",
		"muster": 0, "stein": Vector2(0.40, 0.19), "moos_wand": 0.5, "moos_deckel": 0.55,
		"fuge": "wald_fuge",
		"ambient": Color(0.48, 0.47, 0.66), "ambient_energie": 0.5,
		"licht": Color(1.0, 0.9, 0.74), "licht_energie": 0.82, "laterne": "laterne",
		"tief": "wald_tief", "nebel": "wald_nebel", "partikel": "gluehwuermchen", "funke": "wald_funke",
		"kulisse": {"saeule": "baum", "kronen": ["tanne", "tanne", "tanne_paar", "laubbaum"], "krone_anteil": 0.36,
			"deko_varianten": {"pilz": ["pilzgruppe", "farn"], "felsbrocken": ["felsgruppe", "wurzel", "farn"]}},
	},
	Enums.Biome.CAVE: {
		"floor_tint": Color(0.68, 0.74, 0.9), "wall_tint": Color(0.6, 0.66, 0.85),
		"deco": ["felsbrocken", "knochen"],
		"boden": "hoehle_boden", "wand": "hoehle_wand", "deckel": "hoehle_deckel", "moos": "hoehle_moos",
		"muster": 1, "stein": Vector2(0.40, 0.19), "moos_wand": 0.35, "moos_deckel": 0.0,
		"fuge": "hoehle_fuge",
		"ambient": Color(0.44, 0.47, 0.66), "ambient_energie": 0.5,
		"licht": Color(0.92, 0.94, 1.0), "licht_energie": 0.8, "laterne": "laterne",
		"tief": "hoehle_tief", "nebel": "hoehle_nebel", "partikel": "tropfen", "funke": "hoehle_funke",
		"kulisse": {"saeule": "tropfstein", "kronen": ["tropfsteine", "tropfsteine", "kristalle"], "krone_anteil": 0.3,
			"deko_varianten": {"felsbrocken": ["kristallgruppe", "tropfstein_klein", "pfuetze"],
				"knochen": ["knochenhaufen", "pfuetze"]}},
	},
	Enums.Biome.RUINS: {
		"floor_tint": Color(0.85, 0.85, 0.82), "wall_tint": Color(0.95, 0.95, 0.92),
		"deco": ["amboss", "fass"],
		"boden": "ruinen_boden", "wand": "ruinen_wand", "deckel": "ruinen_deckel", "moos": "ruinen_moos",
		"muster": 0, "stein": Vector2(0.52, 0.24), "moos_wand": 0.0, "moos_deckel": 0.25,
		"fuge": "ruinen_fuge",
		"ambient": Color(0.52, 0.46, 0.62), "ambient_energie": 0.5,
		"licht": Color(1.0, 0.88, 0.72), "licht_energie": 0.8, "laterne": "laterne",
		"tief": "ruinen_tief", "nebel": "ruinen_nebel", "partikel": "asche", "funke": "ruinen_funke",
		"kulisse": {"saeule": "saeule", "kronen": ["zinnen", "zinnen", "saeulenstumpf", "bruchkante"], "krone_anteil": 0.34,
			"deko_varianten": {"amboss": ["saeulentrommel", "kistenstapel"], "fass": ["fassgruppe", "kistenstapel", "truemmer"]}},
	},
	Enums.Biome.CRYPT: {
		"floor_tint": Color(0.72, 0.62, 0.82), "wall_tint": Color(0.62, 0.52, 0.75),
		"deco": ["grabstein", "knochen"],
		"boden": "krypta_boden", "wand": "krypta_wand", "deckel": "krypta_deckel", "moos": "krypta_moos",
		"muster": 2, "stein": Vector2(0.66, 0.30), "moos_wand": 0.0, "moos_deckel": 0.0,
		"fuge": "krypta_fuge",
		"ambient": Color(0.44, 0.43, 0.62), "ambient_energie": 0.5,
		"licht": Color(0.92, 0.94, 1.0), "licht_energie": 0.8, "laterne": "laterne",
		"tief": "krypta_tief", "nebel": "krypta_nebel", "partikel": "irrlicht", "funke": "krypta_funke",
		"kulisse": {"saeule": "gruftpfeiler", "kronen": ["gruftaufsatz", "kreuz", "kreuz", "grabplatte"], "krone_anteil": 0.26,
			"deko_varianten": {"grabstein": ["sarkophag", "grabstein_schief", "kerzen"], "knochen": ["knochenhaufen", "kerzen"]}},
	},
}

## Schlüssel, deren Wert ein PAL-Name ist (in fuer() zu Color aufgelöst).
const PAL_SCHLUESSEL := ["boden", "wand", "deckel", "moos", "fuge", "laterne", "tief", "nebel", "funke"]
const PARTIKEL_ARTEN := ["gluehwuermchen", "tropfen", "asche", "irrlicht", "glut", "staub"]

## Grundwerte der Varianten-Schlüssel (fuer() setzt sie, Varianten verschieben
## sie): risse = Anteil gerissener Bodenplatten (Boden-Shader), bewuchs =
## Moosflecken auf dem Boden in jedem Biom, pfuetzen + pfuetze_farbe (PAL) =
## Lachen auf dem Boden, partikel_menge = Faktor der Partikelzahl,
## fackel_anteil = Faktor der Wandfackeln, laterne_energie = Faktor der
## Heldenlaterne, laterne_flackern = 0 ruhig … 1 unruhig, wand_zacken =
## Streuung der Wandhöhen, streu/streu_anteil = zusätzliche flache Deko
## (BiomKulisse.DEKO) an Wandrändern (nur Optik, kein Hindernis),
## belichtung = Faktor der Tonemap-Belichtung, vignette_plus = stärkerer
## Bildrand.
const GRUNDWERTE := {
	"risse": 0.28, "bewuchs": 0.0, "pfuetzen": 0.0, "pfuetze_farbe": "wasser",
	"partikel_menge": 1.0, "fackel_anteil": 1.0, "laterne_energie": 1.0, "laterne_flackern": 0.0,
	"wand_zacken": 0.0, "streu": [], "streu_anteil": 0.0, "belichtung": 1.0, "vignette_plus": 0.0,
}

# --- Varianten je Karte (Lutz 2026-11-02) --------------------------------------
# Jede Karte wandelt den Biom-Stil sichtbar ab, abgeleitet aus ihren
# Namensteilen und dem Seed — deterministisch, reine Anzeige (Generator,
# Spiellogik und Balance lesen das nie). Eine Wirkung ist ein Dictionary:
#   "misch": {Schlüssel: [PAL-Name, Anteil]} — Farbe zum PAL-Ton ziehen
#   "mal":   {Schlüssel: Faktor}             — Zahlwert multiplizieren
#   "plus":  {Schlüssel: Wert}               — Zahlwert addieren (geklemmt)
#   "setze": {Schlüssel: Wert}               — ersetzen (Partikel-Art, PAL-Name)
#   "kronen": [Krone, …] — weitere Wandkronen-Varianten (mischen sich ein)
#   "streu":  [Deko, …]  — Streu-Deko an Wandrändern (streu_anteil über "plus")

## Präfix (CardFactory.NAME_PREFIXES, gleiche Reihenfolge) » Stimmung.
const PRAEFIX_STIMMUNG := [
	# Verwitterter: Risse, abgebrochene Kronen, Trümmer, graue Steine
	{"plus": {"risse": 0.32, "streu_anteil": 0.06, "moos_deckel": 0.1}, "mal": {"krone_anteil": 0.85},
		"misch": {"wand": ["stein", 0.18], "deckel": ["stein", 0.18]},
		"kronen": ["bruchkante", "bruchkante"], "streu": ["truemmer"]},
	# Zerklüfteter: zerrissene Platten, zackige Wandhöhen, Felsbrocken
	{"plus": {"risse": 0.5, "wand_zacken": 0.45, "streu_anteil": 0.08},
		"misch": {"deckel": ["stein_dunkel", 0.22]},
		"kronen": ["bruchkante", "bruchkante", "bruchkante"], "streu": ["truemmer", "felsgruppe"]},
	# Alter: ausgeblichene Farben, Knochenton in den Fugen
	{"plus": {"risse": 0.12, "streu_anteil": 0.03},
		"misch": {"boden": ["stein_hell", 0.24], "wand": ["stein_hell", 0.24], "deckel": ["stein_hell", 0.24],
			"moos": ["stein_hell", 0.35], "fuge": ["knochen", 0.35]},
		"mal": {"ambient_energie": 1.08}, "streu": ["truemmer"]},
	# Blutiger: rote Fugen und Lachen
	{"plus": {"pfuetzen": 0.55, "streu_anteil": 0.05}, "setze": {"pfuetze_farbe": "drachenblut"},
		"misch": {"fuge": ["drachenblut", 0.75], "moos": ["daemon_dunkel", 0.4], "funke": ["maehne", 0.45]},
		"streu": ["blutlache"]},
	# Vergessener: Spinnweben, Staub, gedämpftes Licht
	{"plus": {"streu_anteil": 0.1}, "setze": {"partikel": "staub"},
		"mal": {"licht_energie": 0.85, "ambient_energie": 0.9, "laterne_energie": 0.9, "belichtung": 0.92},
		"misch": {"boden": ["stein", 0.14], "deckel": ["stein", 0.14], "funke": ["stein_hell", 0.7]},
		"streu": ["spinnweben", "spinnweben", "knochenhaufen"]},
	# Moosiger: Bewuchs auf Wänden, Deckeln und Boden
	{"plus": {"moos_wand": 0.4, "moos_deckel": 0.4, "bewuchs": 0.6, "streu_anteil": 0.08},
		"misch": {"moos": ["moos", 0.35]}, "streu": ["farn", "pilzgruppe"]},
	# Stiller: kaum Partikel, wenige Fackeln, kühles ruhiges Licht
	{"mal": {"partikel_menge": 0.45, "fackel_anteil": 0.5}, "setze": {"laterne_flackern": 0.0},
		"misch": {"licht": ["stern", 0.25]}},
	# Verfluchter: violette Fugen und Irrlichter
	{"setze": {"partikel": "irrlicht"},
		"misch": {"fuge": ["lila", 0.7], "nebel": ["lila_dunkel", 0.35], "funke": ["lila", 0.7],
			"moos": ["robe_lila", 0.3]}},
]

## Suffix (CardFactory.NAME_SUFFIXES, gleiche Reihenfolge) » Licht und Partikel.
const SUFFIX_STIMMUNG := [
	# des Unheils: rötlicher Nebel, etwas dunkler
	{"misch": {"nebel": ["daemon_dunkel", 0.3], "ambient": ["lila_dunkel", 0.15]}, "mal": {"licht_energie": 0.92}},
	# der Qual: rostrote Fugen, Knochen
	{"misch": {"fuge": ["maehne", 0.3], "laterne": ["flamme", 0.2]}, "plus": {"streu_anteil": 0.03},
		"streu": ["knochenhaufen"]},
	# des Zorns: rotes Licht, Glut, mehr Fackeln
	{"misch": {"licht": ["flamme", 0.25]}, "setze": {"partikel": "glut"},
		"mal": {"partikel_menge": 0.7, "fackel_anteil": 1.6}},
	# der Gier: Goldglanz in den Fugen, Münzen
	{"misch": {"fuge": ["gold", 0.85], "funke": ["gold", 0.6]}, "plus": {"streu_anteil": 0.04},
		"streu": ["muenzen"]},
	# der Stille: kaum Partikel, ruhige Laterne
	{"mal": {"partikel_menge": 0.25}, "setze": {"laterne_flackern": 0.0}},
	# des Verderbens: giftgrüne Lachen und Bewuchs
	{"misch": {"moos": ["gift", 0.5], "funke": ["gift", 0.5]}, "plus": {"pfuetzen": 0.35},
		"setze": {"pfuetze_farbe": "gift"}},
	# der Angst: flackernde Laterne, weniger Licht
	{"plus": {"laterne_flackern": 1.0, "vignette_plus": 0.1}, "mal": {"licht_energie": 0.85, "ambient_energie": 0.9,
		"belichtung": 0.9}},
	# der Finsternis: dunkler, schwarzer Untergrund, hellere Laterne
	{"mal": {"licht_energie": 0.5, "ambient_energie": 0.75, "laterne_energie": 1.2, "partikel_menge": 0.7,
		"belichtung": 0.74}, "plus": {"vignette_plus": 0.22},
		"misch": {"tief": ["nacht", 0.6], "nebel": ["nacht", 0.45]}},
	# der Glut: warmes Licht, Funken, mehr Fackeln
	{"misch": {"licht": ["glut", 0.3], "laterne": ["flamme", 0.25], "funke": ["flamme", 0.8], "fuge": ["flamme", 0.3]},
		"setze": {"partikel": "glut"}, "mal": {"fackel_anteil": 1.5}},
	# des Hungers: Knochen, fahler Bewuchs
	{"misch": {"deckel": ["knochen", 0.1], "moos": ["fahl", 0.3]}, "plus": {"streu_anteil": 0.06},
		"streu": ["knochenhaufen"]},
]

## Seed-Farbversatz: Boden, Wand und Deckel ziehen leicht zu einem dieser
## PAL-Töne (3–8 %) — zwei Karten mit gleichen Namensteilen bleiben
## unterscheidbar, ohne neue Rohfarben.
const SEED_TOENE := ["stein_hell", "braun_hell", "moos", "lila", "kristall", "glut", "stein_dunkel"]
const SEED_ANTEIL := Vector2(0.03, 0.08)
## Grenzen der Zahlwerte nach "plus" (Rest ist frei).
const GRENZEN := {"risse": Vector2(0.0, 0.85), "bewuchs": Vector2(0.0, 1.0), "pfuetzen": Vector2(0.0, 1.0),
	"moos_wand": Vector2(0.0, 0.95), "moos_deckel": Vector2(0.0, 0.95), "laterne_flackern": Vector2(0.0, 1.0),
	"wand_zacken": Vector2(0.0, 0.6), "streu_anteil": Vector2(0.0, 0.2)}


## Datensatz des Bioms mit aufgelösten Farben (unbekannt » Wald).
static func fuer(biome: int) -> Dictionary:
	var schluessel_biom: int = biome if DATEN.has(biome) else Enums.Biome.FOREST
	var roh: Dictionary = DATEN[schluessel_biom]
	var stil := roh.duplicate()
	stil["biom"] = schluessel_biom  # für die Biom-Zweige im Boden-Shader
	for schluessel in PAL_SCHLUESSEL:
		stil[schluessel] = Stil3D.farbe(roh[schluessel])
	for schluessel in GRUNDWERTE:
		if not stil.has(schluessel):
			stil[schluessel] = GRUNDWERTE[schluessel]
	stil["kulisse"] = (roh.get("kulisse", {}) as Dictionary).duplicate(true)
	stil["streu"] = (stil["streu"] as Array).duplicate()
	stil["pfuetze_farbe"] = Stil3D.farbe(String(stil["pfuetze_farbe"]))
	return stil


## Stil einer Karte: Biom-Stil plus Varianten-Abwandlung aus Präfix, Suffix
## und Seed (siehe PRAEFIX_STIMMUNG). Karten ohne Namensteile (Startkarte,
## feste Namen) bekommen nur den Seed-Farbversatz.
static func fuer_karte(card: DungeonCard) -> Dictionary:
	if card == null:
		return fuer(Enums.Biome.FOREST)
	return variante(card.biome, card.name_teile, card.seed)


static func variante(biome: int, name_teile: Array, karten_seed: int) -> Dictionary:
	var stil := fuer(biome)
	stil["pfuetze_farbe"] = "wasser"  # Varianten setzen PAL-Namen, aufgelöst am Ende
	if name_teile.size() == 3:
		var p := int(name_teile[0])
		var s := int(name_teile[2])
		if p >= 0 and p < PRAEFIX_STIMMUNG.size():
			_anwenden(stil, PRAEFIX_STIMMUNG[p])
		if s >= 0 and s < SUFFIX_STIMMUNG.size():
			_anwenden(stil, SUFFIX_STIMMUNG[s])
	var h := absi(hash([karten_seed, "farbton"]))
	var ton: String = SEED_TOENE[h % SEED_TOENE.size()]
	var anteil := lerpf(SEED_ANTEIL.x, SEED_ANTEIL.y, float((h / 7) % 11) / 10.0)
	for schluessel in ["boden", "wand", "deckel"]:
		stil[schluessel] = (stil[schluessel] as Color).lerp(Stil3D.farbe(ton), anteil)
	stil["pfuetze_farbe"] = Stil3D.farbe(String(stil["pfuetze_farbe"]))
	stil["variante"] = [biome, name_teile.duplicate(), karten_seed]
	return stil


static func _anwenden(stil: Dictionary, wirkung: Dictionary) -> void:
	var kulisse: Dictionary = stil["kulisse"]
	var misch: Dictionary = wirkung.get("misch", {})
	for k in misch:
		stil[k] = (stil[k] as Color).lerp(Stil3D.farbe(misch[k][0]), float(misch[k][1]))
	var mal: Dictionary = wirkung.get("mal", {})
	for k in mal:
		var ziel: Dictionary = kulisse if k == "krone_anteil" else stil
		ziel[k] = float(ziel.get(k, 0.0)) * float(mal[k])
	var plus: Dictionary = wirkung.get("plus", {})
	for k in plus:
		var grenze: Vector2 = GRENZEN.get(k, Vector2(-INF, INF))
		stil[k] = clampf(float(stil.get(k, 0.0)) + float(plus[k]), grenze.x, grenze.y)
	var setze: Dictionary = wirkung.get("setze", {})
	for k in setze:
		stil[k] = setze[k]
	if wirkung.has("kronen") and not (kulisse.get("kronen", []) as Array).is_empty():
		var kronen: Array = (kulisse["kronen"] as Array).duplicate()
		kronen.append_array(wirkung["kronen"])
		kulisse["kronen"] = kronen
	if wirkung.has("streu"):
		(stil["streu"] as Array).append_array(wirkung["streu"])
