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

# Englische Namens-Pools — GLEICHE Laengen und Reihenfolge wie die deutschen:
# die Karte speichert nur die Indizes (DungeonCard.name_teile), der Name wird
# beim Anzeigen in der aktuellen Sprache gebaut (karten_name).
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
	&"reich": {"name": "Reich", "name_en": "Rich",
		"desc": "+60% Gold aus Kämpfen", "desc_en": "+60% gold from battles"},
	&"bevoelkert": {"name": "Bevölkert", "name_en": "Crowded",
		"desc": "+3 Gegnergruppen pro Ebene", "desc_en": "+3 enemy groups per floor"},
	&"schatz": {"name": "Schatzkammer", "name_en": "Treasury",
		"desc": "+2 Truhen pro Ebene", "desc_en": "+2 chests per floor"},
	&"elitaer": {"name": "Elitär", "name_en": "Elitist",
		"desc": "Doppelte Elite-Chance", "desc_en": "Double elite chance"},
	&"uralt": {"name": "Uralt", "name_en": "Ancient",
		"desc": "+25% Erfahrung", "desc_en": "+25% experience"},
	&"gefaehrlich": {"name": "Gefährlich", "name_en": "Dangerous",
		"desc": "Gegner +15% stärker, dafür +30% Beute", "desc_en": "Enemies +15% stronger, +30% loot"},
}


static func card_affix_name(id: StringName) -> String:
	if CARD_AFFIXES.has(id):
		return Loc.pick(CARD_AFFIXES[id]["name"], CARD_AFFIXES[id]["name_en"])
	return str(id)


static func card_affix_desc(id: StringName) -> String:
	if CARD_AFFIXES.has(id):
		return Loc.pick(CARD_AFFIXES[id]["desc"], CARD_AFFIXES[id]["desc_en"])
	return ""


## Kartenkopf für Lager und Belohnungswahl: „[LEGACY] [Episch] Name“.
## Legacy (Boss wächst mit jedem Abschluss) ist nicht dasselbe wie die
## Seltenheit „Legendär“ (Spieltest 2026-10-23: doppeltes Etikett).
static func karten_kopf(card: DungeonCard) -> String:
	var text := card.display_name
	if card.card_rarity != Enums.Rarity.COMMON:
		text = "[%s] %s" % [LootGenerator.rarity_name(card.card_rarity), text]
	if card.legendary:
		text = "[LEGACY] " + text
	return text


## Echtes Boss-Level einer Legacy-Karte: Kartenstufe + tiefste Ebene +
## Karten-Rarität + Legacy (Spieltest 2026-10-23: „Boss-Stufe 19“, er war Lv25).
static func legacy_boss_level(card: DungeonCard) -> int:
	return card.tier + card.floor_count - 1 + card.rarity_level_bonus() + card.legacy_boss_bonus()


## Karten-Affixe mit Wirkung: ["Reich (+60% Gold)", …].
static func affix_texte(card: DungeonCard) -> Array[String]:
	var teile: Array[String] = []
	for id in card.card_affix_ids:
		teile.append("%s (%s)" % [card_affix_name(id), card_affix_desc(id)])
	return teile


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


## Einstiegsstufen der Biome: ab dieser Kartenstufe kommt ein Biom in den
## Pool und bleibt dort (siehe BIOME_RETIRE_TIER).
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


## Neue Karten neigen ihren Grundriss nach dem Ort (DungeonGenerator.ORT_GRUNDRISS).
const GRUNDRISS_VERSION := 1


## forced_biome >= 0 erzwingt ein Biom (Wunsch-Karten aus Händler-Aufträgen —
## bewusst auch unterhalb der Einstiegsstufe des Bioms, das ist die Belohnung).
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

	# Nur die Indizes speichern — der Name folgt der Sprache (karten_name).
	# Die Würfe bleiben in derselben Reihenfolge wie früher.
	var praefix := rng.randi_range(0, NAME_PREFIXES.size() - 1)
	var ort := rng.randi_range(0, BIOME_PLACES[card.biome].size() - 1)
	var suffix := rng.randi_range(0, NAME_SUFFIXES.size() - 1)
	card.name_teile = [praefix, ort, suffix]
	card.grundriss_version = GRUNDRISS_VERSION

	# Karten-Rarität: seltene Karten = stärkere, lukrativere Gegner.
	# LEGENDÄR (nur ab Stufe 4) trägt zusätzlich den Legacy-Boss, der mit
	# jedem Abschluss weiterlevelt — im Kartenlager orange markiert.
	card.card_rarity = _roll_card_rarity(card.tier, rng)
	if card.card_rarity == Enums.Rarity.LEGENDARY:
		card.legendary = true
	# Elite-/Boss-Modifikatoren fix bei Erstellung (siehe Design);
	# höhere Stufen können mehr Modifikatoren gleichzeitig tragen.
	card.modifier_ids = EnemyLibrary.roll_modifiers(card.tier, rng)
	if card.tier < EnemyFactory.ELITE_AB_STUFE:
		card.modifier_ids.clear()  # erste Karten ohne Eliten
	card.card_affix_ids = roll_card_affixes(card.tier, rng)
	Sonderregeln.wuerfeln(card, rng)
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


## Schatzkarte eines Kartenhüters: 1-5 Stufen über der aktuellen Karte,
## episch (70 %) oder legendär (30 %, ab Stufe 4) — mit Legacy-Boss.
const SCHATZKARTE_LEGENDAER := 0.3


static func make_schatzkarte(tier: int) -> DungeonCard:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var card := make_card(tier + rng.randi_range(1, 5), rng)
	if card.tier >= LEGENDARY_MIN_TIER and rng.randf() < SCHATZKARTE_LEGENDAER:
		card.card_rarity = Enums.Rarity.LEGENDARY
		card.legendary = true
	else:
		card.card_rarity = Enums.Rarity.EPIC
		card.legendary = false
	return card


static func make_starter_card() -> DungeonCard:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var card := make_card(1, rng)
	card.biome = Enums.Biome.FOREST
	card.name_teile = []
	card.name_key = START_NAME_KEY
	card.card_affix_ids = []  # Startkarten ohne Affixe — sanfter Einstieg
	card.sonderregel = &""
	return card


# --- Kartennamen DE/EN -------------------------------------------------------------

## Eigener Name der Startkarte (name_key statt Pool-Indizes).
const START_NAME_KEY := "start"
const START_NAME := ["Stiller Hain der Anfänge", "Silent Grove of Beginnings"]


## Name aus den gespeicherten Teilen in der aktuellen Sprache; "" = die Karte
## hat keine (eigener oder nicht zerlegbarer Alt-Name, dann gilt der Text).
static func karten_name(card: DungeonCard) -> String:
	if card.name_key == START_NAME_KEY:
		return Loc.pick(START_NAME[0], START_NAME[1])
	if card.name_teile.size() != 3 or not BIOME_PLACES.has(card.biome):
		return ""
	var english := Loc.language == "en"
	var prefixes: Array = NAME_PREFIXES_EN if english else NAME_PREFIXES
	var suffixes: Array = NAME_SUFFIXES_EN if english else NAME_SUFFIXES
	var places: Array = (BIOME_PLACES_EN if english else BIOME_PLACES)[card.biome]
	var p: int = card.name_teile[0]
	var o: int = card.name_teile[1]
	var s: int = card.name_teile[2]
	if p < 0 or p >= prefixes.size() or o < 0 or o >= places.size() \
			or s < 0 or s >= suffixes.size():
		return ""
	return "%s %s %s" % [prefixes[p], places[o], suffixes[s]]


## Migration alter Spielstände: zerlegt einen gespeicherten Namen gegen die
## DE- und EN-Pools des Bioms. Ergebnis [Präfix, Ort, Suffix] nur bei genau
## einem Treffer, sonst [] (der Text bleibt dann, wie er ist).
static func name_zerlegen(text: String, biome: int) -> Array[int]:
	var treffer: Array = []
	if not BIOME_PLACES.has(biome):
		return [] as Array[int]
	for pools in [[NAME_PREFIXES, BIOME_PLACES[biome], NAME_SUFFIXES],
			[NAME_PREFIXES_EN, BIOME_PLACES_EN[biome], NAME_SUFFIXES_EN]]:
		for p in pools[0].size():
			var vorne: String = pools[0][p] + " "
			if not text.begins_with(vorne):
				continue
			for s in pools[2].size():
				var hinten: String = " " + pools[2][s]
				if not text.ends_with(hinten) or text.length() < vorne.length() + hinten.length():
					continue
				var mitte := text.substr(vorne.length(), text.length() - vorne.length() - hinten.length())
				var o: int = pools[1].find(mitte)
				if o >= 0 and not [p, o, s] in treffer:
					treffer.append([p, o, s])
	if treffer.size() != 1:
		return [] as Array[int]
	var teile: Array[int] = []
	teile.assign(treffer[0])
	return teile
