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

## Karten-Affixe: verändern die GANZE Karte (fix bei Erstellung) — jede
## Karte wird damit ein eigenes Risiko/Belohnungs-Angebot, wie Map-Mods
## in Path of Exile. Ausgewertet in Generator, EnemyFactory und Kampf-Beute.
const CARD_AFFIXES := {
	&"reich": {"name": "Reich", "desc": "+60% Gold aus Kämpfen"},
	&"bevoelkert": {"name": "Bevölkert", "desc": "Deutlich mehr Gegner pro Ebene"},
	&"schatz": {"name": "Schatzkammer", "desc": "+2 Truhen pro Ebene"},
	&"elitaer": {"name": "Elitär", "desc": "Doppelte Elite-Chance"},
	&"uralt": {"name": "Uralt", "desc": "+25% Erfahrung"},
	&"gefaehrlich": {"name": "Gefährlich", "desc": "Gegner +15% stärker, dafür +30% Beute"},
}


static func card_affix_name(id: StringName) -> String:
	if CARD_AFFIXES.has(id):
		return CARD_AFFIXES[id]["name"]
	return str(id)


static func card_affix_desc(id: StringName) -> String:
	if CARD_AFFIXES.has(id):
		return CARD_AFFIXES[id]["desc"]
	return ""


## 0-2 Karten-Affixe würfeln; höhere Stufen haben öfter welche.
static func roll_card_affixes(tier: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var pool := CARD_AFFIXES.keys()
	var result: Array[StringName] = []
	var max_count := mini(2, 1 + tier / 5)
	var count := rng.randi_range(0, max_count)
	for i in count:
		if pool.is_empty():
			break
		var pick := rng.randi_range(0, pool.size() - 1)
		result.append(pool[pick])
		pool.remove_at(pick)
	return result


## Biom-Level-Fenster: Biome haben eine Einstiegs- UND eine Ausstiegs-Stufe.
## Wald und Höhle findet man früh häufig — ab höheren Stufen verschwinden sie
## und machen Platz für die dunkleren Biome. So bleibt der Karten-Pool frisch.
const BIOME_UNLOCK_TIER := {
	Enums.Biome.FOREST: 1,
	Enums.Biome.CAVE: 3,
	Enums.Biome.RUINS: 5,
	Enums.Biome.CRYPT: 7,
}
const BIOME_RETIRE_TIER := {
	Enums.Biome.FOREST: 9,
	Enums.Biome.CAVE: 13,
	Enums.Biome.RUINS: 17,
	Enums.Biome.CRYPT: 9999,  # Die Krypta bleibt für immer
}


## forced_biome >= 0 erzwingt ein Biom (Wunsch-Karten aus Händler-Aufträgen —
## bewusst auch außerhalb des Biom-Level-Fensters, das ist die Belohnung).
static func make_card(tier: int, rng: RandomNumberGenerator,
		forced_biome := -1) -> DungeonCard:
	var card := DungeonCard.new()
	card.tier = maxi(1, tier)
	card.seed = rng.randi()

	if forced_biome >= 0:
		card.biome = forced_biome as Enums.Biome
	else:
		var biome_pool: Array[Enums.Biome] = []
		for biome in BIOME_UNLOCK_TIER:
			if card.tier >= BIOME_UNLOCK_TIER[biome] and card.tier <= BIOME_RETIRE_TIER[biome]:
				biome_pool.append(biome)
		if biome_pool.is_empty():
			biome_pool.append(Enums.Biome.CRYPT)
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
	card.card_affix_ids = roll_card_affixes(card.tier, rng)
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
	card.card_affix_ids = []  # Startkarten ohne Affixe — sanfter Einstieg
	return card
