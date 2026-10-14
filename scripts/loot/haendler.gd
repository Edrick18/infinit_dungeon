class_name Haendler
extends RefCounted
## Händler-Logik (Lutz 2026-10-14): Kräuter und einfache Werkstoffe für Gold,
## dazu Ausrüstung — zufällig wie beim Schmieden, aber NUR für Gold, deshalb
## deutlich teurer, und ohne jede Einflussnahme: das Level liegt etwa beim
## Party-Schnitt, Basis und Rarität entscheidet der Zufall.

## Kaufpreise der Materialien (Kräuter + Werkstoffe Stufe 1). Edlere
## Werkstoffe und Runen gibt es nur als Beute.
const MATERIAL_PREIS := {
	&"heilkraut": 12, &"manabluete": 12, &"reinigungssalz": 15,
	&"eisenerz": 25, &"lederreste": 25, &"kristallstaub": 35,
}
## Abweichung des Item-Levels vom Party-Schnitt (±).
const LEVEL_STREUUNG := 1


## Preis eines Ausrüstungs-Kaufs auf diesem Level — rund das Vier- bis
## Fünffache des Schmiede-Golds (dafür ohne Materialien).
static func ausruestung_preis(level: int) -> int:
	return roundi((150 + level * 40) * Scaling.factor(level))


## Zufälliger Gegenstand der Kategorie (Smith.KATEGORIEN) um den Party-Schnitt.
## Mindestens Magisch — für so viel Gold gibt es keinen grauen Ramsch.
static func ausruestung_kaufen(kategorie_id: StringName, party_schnitt: int,
		rng: RandomNumberGenerator) -> ItemInstance:
	var level := maxi(1, party_schnitt + rng.randi_range(-LEVEL_STREUUNG, LEVEL_STREUUNG))
	var basen := Smith.moegliche_basen(kategorie_id, level)
	if basen.is_empty():
		return null
	var item := ItemInstance.new()
	item.base = basen[rng.randi_range(0, basen.size() - 1)]
	item.item_level = level
	item.rarity = maxi(int(LootGenerator.roll_rarity(rng)), int(Enums.Rarity.MAGIC)) as Enums.Rarity
	LootGenerator.apply_random_affixes(item, rng)
	return item
