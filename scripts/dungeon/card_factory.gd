class_name CardFactory
extends RefCounted
## Erzeugt Dungeon-Karten: Startkarten, Zufallskarten und die
## Belohnungskarte nach einem Dungeon-Abschluss (Stufe −2..+5, min. 1).
## Alle Karten-Eigenschaften inkl. Modifikatoren werden hier fix gewürfelt.

## Grotten-Namen im DQ9-Stil: "<Adjektiv> <Ort> <des/der …>" —
## z.B. "Verwitterter Stollen des Unheils". Alle Orte sind maskulin,
## damit die Adjektive grammatisch passen.
const NAME_PREFIXES: Array[String] = [
	"Verwitterter", "Zerklüfteter", "Alter", "Blutiger", "Vergessener",
	"Moosiger", "Stiller", "Verfluchter",
]

const BIOME_PLACES := {
	Enums.Biome.FOREST: ["Hain", "Forst", "Pfad"],
	Enums.Biome.CAVE: ["Stollen", "Schacht", "Spalt"],
	Enums.Biome.RUINS: ["Tempel", "Turm", "Hof"],
	Enums.Biome.CRYPT: ["Totengang", "Knochenkeller", "Seelenschacht"],
}

const NAME_SUFFIXES: Array[String] = [
	"des Unheils", "der Qual", "des Zorns", "der Gier", "der Stille",
	"des Verderbens", "der Angst", "der Finsternis", "der Glut", "des Hungers",
]

# Englische Namens-Pools — GLEICHE Laengen wie die deutschen, damit der
# deterministische Seed dieselben Indizes zieht (Sprache aendert nur Text).
const NAME_PREFIXES_EN: Array[String] = [
	"Weathered", "Jagged", "Ancient", "Bloody", "Forgotten",
	"Mossy", "Silent", "Cursed",
]

const BIOME_PLACES_EN := {
	Enums.Biome.FOREST: ["Grove", "Forest", "Path"],
	Enums.Biome.CAVE: ["Shaft", "Pit", "Crevice"],
	Enums.Biome.RUINS: ["Temple", "Tower", "Courtyard"],
	Enums.Biome.CRYPT: ["Deadwalk", "Bone Cellar", "Soul Shaft"],
}

const NAME_SUFFIXES_EN: Array[String] = [
	"of Doom", "of Torment", "of Wrath", "of Greed", "of Silence",
	"of Ruin", "of Fear", "of Darkness", "of Embers", "of Hunger",
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

const BIOME_NAMES_EN := {
	Enums.Biome.FOREST: "Forest",
	Enums.Biome.CAVE: "Cave",
	Enums.Biome.RUINS: "Ruins",
	Enums.Biome.CRYPT: "Crypt",
}


## Biom-Name in der aktuellen Sprache.
static func biome_name(biome: Enums.Biome) -> String:
	return Loc.pick(BIOME_NAMES[biome], BIOME_NAMES_EN[biome])

## Belohnungs-Gewichtung: −2 bis +5 Stufen um die abgeschlossene Karte —
## Erwartungswert +1,5, auf Dauer geht es also garantiert bergauf
## (dazu wählt man am Kampfende aus ZWEI Karten).
const REWARD_TIER_MIN := -2
const REWARD_TIER_MAX := 5

## Legendäre Karten (DQ9-Legacy-Boss): selten, ab Stufe 4.
const LEGENDARY_CHANCE := 0.07
const LEGENDARY_MIN_TIER := 4

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
## Biome gehen NIE mehr in Rente (vorher: ab Stufe 17 nur noch Krypta) —
## auf einem Spielstand mit hunderten Stunden wäre Krypta-only tödlich
## repetitiv. Alle freigeschalteten Biome bleiben im Pool.
const BIOME_RETIRE_TIER := {
	Enums.Biome.FOREST: 9999,
	Enums.Biome.CAVE: 9999,
	Enums.Biome.RUINS: 9999,
	Enums.Biome.CRYPT: 9999,
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

	# Ebenen: Stufe 1-4 » 1, 5-8 » 2, 9-12 » 3, ... (max. 5).
	# Der Boss wartet immer nur auf der untersten Ebene.
	card.floor_count = clampi(1 + (card.tier - 1) / 4, 1, 5)

	var english := Loc.language == "en"
	var prefixes: Array = NAME_PREFIXES_EN if english else NAME_PREFIXES
	var suffixes: Array = NAME_SUFFIXES_EN if english else NAME_SUFFIXES
	var places: Array = (BIOME_PLACES_EN if english else BIOME_PLACES)[card.biome]
	card.display_name = "%s %s %s" % [
		prefixes[rng.randi_range(0, prefixes.size() - 1)],
		places[rng.randi_range(0, places.size() - 1)],
		suffixes[rng.randi_range(0, suffixes.size() - 1)]]

	# Karten-Rarität: seltene Karten = stärkere, lukrativere Gegner.
	# LEGENDÄR (nur ab Stufe 4) trägt zusätzlich den Legacy-Boss, der mit
	# jedem Abschluss weiterlevelt — im Kartenlager orange markiert.
	card.card_rarity = _roll_card_rarity(card.tier, rng)
	if card.card_rarity == Enums.Rarity.LEGENDARY:
		card.legendary = true
	# Elite-/Boss-Modifikatoren fix bei Erstellung (siehe Design);
	# höhere Stufen können mehr Modifikatoren gleichzeitig tragen.
	card.modifier_ids = EnemyLibrary.roll_modifiers(card.tier, rng)
	card.card_affix_ids = roll_card_affixes(card.tier, rng)
	return card


## Gewichte wie bei Items: Häufig dominiert, Legendär bleibt das Ereignis.
static func _roll_card_rarity(tier: int, rng: RandomNumberGenerator) -> Enums.Rarity:
	var weights := {
		Enums.Rarity.COMMON: 100, Enums.Rarity.MAGIC: 45,
		Enums.Rarity.RARE: 18, Enums.Rarity.EPIC: 6,
	}
	if tier >= LEGENDARY_MIN_TIER:
		weights[Enums.Rarity.LEGENDARY] = 7
	var total := 0
	for rarity in weights:
		total += weights[rarity]
	var roll := rng.randi_range(1, total)
	for rarity in weights:
		roll -= weights[rarity]
		if roll <= 0:
			return rarity
	return Enums.Rarity.COMMON


static func make_reward(completed: DungeonCard) -> DungeonCard:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var tier := completed.tier + rng.randi_range(REWARD_TIER_MIN, REWARD_TIER_MAX)
	return make_card(tier, rng)


static func make_starter_card() -> DungeonCard:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var card := make_card(1, rng)
	card.biome = Enums.Biome.FOREST
	card.display_name = Loc.pick("Stiller Hain der Anfänge", "Silent Grove of Beginnings")
	card.card_affix_ids = []  # Startkarten ohne Affixe — sanfter Einstieg
	return card
