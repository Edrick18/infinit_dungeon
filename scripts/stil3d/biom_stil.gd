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
##   biom     — (nur in fuer()) Enums.Biome des Datensatzes

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
	},
}

## Schlüssel, deren Wert ein PAL-Name ist (in fuer() zu Color aufgelöst).
const PAL_SCHLUESSEL := ["boden", "wand", "deckel", "moos", "fuge", "laterne", "tief", "nebel", "funke"]
const PARTIKEL_ARTEN := ["gluehwuermchen", "tropfen", "asche", "irrlicht"]


## Datensatz des Bioms mit aufgelösten Farben (unbekannt » Wald).
static func fuer(biome: int) -> Dictionary:
	var schluessel_biom: int = biome if DATEN.has(biome) else Enums.Biome.FOREST
	var roh: Dictionary = DATEN[schluessel_biom]
	var stil := roh.duplicate()
	stil["biom"] = schluessel_biom  # für die Biom-Zweige im Boden-Shader
	for schluessel in PAL_SCHLUESSEL:
		stil[schluessel] = Stil3D.farbe(roh[schluessel])
	return stil
