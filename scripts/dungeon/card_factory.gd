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


static func make_card(tier: int, rng: RandomNumberGenerator) -> DungeonCard:
	var card := DungeonCard.new()
	card.tier = maxi(1, tier)
	card.seed = rng.randi()
	card.biome = [Enums.Biome.FOREST, Enums.Biome.CAVE, Enums.Biome.RUINS,
		Enums.Biome.CRYPT][rng.randi_range(0, 3)] as Enums.Biome
	card.display_name = "%s %s" % [
		NAME_PREFIXES[rng.randi_range(0, NAME_PREFIXES.size() - 1)],
		BIOME_CARD_NAMES[card.biome]]
	# Elite-/Boss-Modifikatoren fix bei Erstellung (siehe Design).
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
