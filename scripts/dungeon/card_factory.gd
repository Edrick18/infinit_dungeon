class_name CardFactory
extends RefCounted
## Erzeugt Dungeon-Karten: Startkarten, Zufallskarten und die
## Belohnungskarte nach einem Dungeon-Abschluss (Stufe ±3, min. 1).
## Alle Karten-Eigenschaften inkl. Modifikatoren werden hier fix gewürfelt.

const NAME_PREFIXES: Array[String] = [
	"Verwitterte", "Zerfledderte", "Alte", "Blutige", "Vergilbte", "Moosige",
]

const BIOME_CARD_NAMES := {
	Enums.Biome.FOREST: "Waldkarte",
	Enums.Biome.CAVE: "Höhlenkarte",
	Enums.Biome.RUINS: "Ruinenkarte",
	Enums.Biome.CRYPT: "Kryptakarte",
}

const BIOME_NAMES := {
	Enums.Biome.FOREST: "Wald",
	Enums.Biome.CAVE: "Höhle",
	Enums.Biome.RUINS: "Ruinen",
	Enums.Biome.CRYPT: "Krypta",
}

## Belohnung nach Abschluss: neue Karte auf Stufe ±3 der abgeschlossenen.
const REWARD_TIER_SPREAD := 3


## Ab welcher Kartenstufe ein Biom in den Karten-Pool kommt —
## höhere Stufen schalten mehr Dungeon-Varianten frei.
const BIOME_UNLOCK_TIER := {
	Enums.Biome.FOREST: 1,
	Enums.Biome.CAVE: 3,
	Enums.Biome.RUINS: 5,
	Enums.Biome.CRYPT: 7,
}


static func make_card(tier: int, rng: RandomNumberGenerator) -> DungeonCard:
	var card := DungeonCard.new()
	card.tier = maxi(1, tier)
	card.seed = rng.randi()

	var biome_pool: Array[Enums.Biome] = []
	for biome in BIOME_UNLOCK_TIER:
		if card.tier >= BIOME_UNLOCK_TIER[biome]:
			biome_pool.append(biome)
	card.biome = biome_pool[rng.randi_range(0, biome_pool.size() - 1)]

	# Ebenen: Stufe 1-4 → 1, 5-8 → 2, 9-12 → 3, ... (max. 5).
	# Der Boss wartet immer nur auf der untersten Ebene.
	card.floor_count = clampi(1 + (card.tier - 1) / 4, 1, 5)

	card.display_name = "%s %s" % [
		NAME_PREFIXES[rng.randi_range(0, NAME_PREFIXES.size() - 1)],
		BIOME_CARD_NAMES[card.biome]]
	# Elite-/Boss-Modifikatoren fix bei Erstellung (siehe Design);
	# höhere Stufen können mehr Modifikatoren gleichzeitig tragen.
	card.modifier_ids = EnemyLibrary.roll_modifiers(card.tier, rng)
	return card


static func make_reward(completed: DungeonCard) -> DungeonCard:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tier := completed.tier + rng.randi_range(-REWARD_TIER_SPREAD, REWARD_TIER_SPREAD)
	return make_card(tier, rng)


static func make_starter_card() -> DungeonCard:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var card := make_card(1, rng)
	card.biome = Enums.Biome.FOREST
	card.display_name = "%s Waldkarte" % NAME_PREFIXES[rng.randi_range(0, NAME_PREFIXES.size() - 1)]
	return card
