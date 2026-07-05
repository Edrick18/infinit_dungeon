class_name Smith
extends RefCounted
## Schmiede-Logik: Du wählst WAS du craftest (Kategorie = genau EIN Basis-Item:
## "Dolch ist Dolch") — zufällig sind Item-Level (Party-Schnitt ± Streuung),
## Rarität, Affixe und damit auch der Name.
## Dazu: Affixe eines Items neu würfeln (der Material-/Gold-Sink fürs Endgame).

## Wie weit das Item-Level vom Party-Schnitt abweichen darf (±).
const LEVEL_DEVIATION := 2

## Schmiede-Angebot, gruppiert fürs UI. Jede Kategorie ist genau ein Basis-Item.
const SECTIONS := [
	{"name": "Waffen", "name_en": "Weapons",
		"bases": [&"schwert", &"zweihandschwert", &"dolch", &"axt",
		&"zweihandaxt", &"knueppel", &"kriegshammer", &"bogen", &"armbrust",
		&"offensivstab", &"heiligstab"]},
	{"name": "Nebenhand", "name_en": "Off-hand",
		"bases": [&"schild", &"zauberbuch", &"kristallfokus", &"koecher"]},
	{"name": "Rüstung", "name_en": "Armor",
		"bases": [&"ruestung_leicht", &"ruestung_mittel", &"ruestung_schwer",
		&"robe_schaden", &"robe_heil", &"robe_kampf",
		&"helm_leicht", &"helm_schwer", &"handschuhe_leicht", &"handschuhe_schwer",
		&"stiefel_leicht", &"stiefel_schwer"]},
	{"name": "Schmuck", "name_en": "Jewelry", "bases": [&"ring", &"amulett"]},
]


## Item-Level: Party-Schnitt mit leichter Streuung (nie unter 1).
static func roll_level(avg_level: int, rng: RandomNumberGenerator) -> int:
	return maxi(1, avg_level + rng.randi_range(-LEVEL_DEVIATION, LEVEL_DEVIATION))


## Freigeschaltet, sobald die Basis im Level-Band erreichbar ist
## (Armbrust ab Stufe 5 → craftbar ab Party-Schnitt 3).
static func can_craft(base_id: StringName, avg_level: int) -> bool:
	var base := ItemLibrary.get_base(base_id)
	return base != null and base.min_tier <= avg_level + LEVEL_DEVIATION


## Craftet das gewählte Basis-Item: Level streut um den Party-Schnitt,
## mindestens MAGIC (die Schmiede liefert keinen grauen Schrott), Affixe random.
static func craft(base_id: StringName, avg_level: int,
		rng: RandomNumberGenerator) -> ItemInstance:
	var base := ItemLibrary.get_base(base_id)
	if base == null or not can_craft(base_id, avg_level):
		return null
	var item := ItemInstance.new()
	item.base = base
	# Streuung nach unten darf nicht unter die Einstiegs-Stufe der Basis fallen.
	item.item_level = maxi(roll_level(avg_level, rng), base.min_tier)
	item.rarity = LootGenerator.roll_rarity(rng)
	if item.rarity == Enums.Rarity.COMMON:
		item.rarity = Enums.Rarity.MAGIC
	LootGenerator.apply_random_affixes(item, rng)
	return item


## Kosten fürs Craften: Material-Profil des Items + Gold nach Party-Level.
static func craft_cost(base_id: StringName, avg_level: int) -> Dictionary:
	return {
		"gold": 25 + avg_level * 10,
		"materials": _materials_for(ItemLibrary.get_base(base_id)),
	}


## Material-Profil aus den Item-Eigenschaften: Metall für Klingen und Panzer,
## Leder für Leichtes und Fernkampf, Kristall für alles Magische.
static func _materials_for(base: ItemBase) -> Dictionary:
	if base == null:
		return {}
	match base.slot:
		Enums.EquipSlot.WEAPON:
			if base.spell_damage > 0:
				return {&"kristallstaub": 2, &"eisenerz": 1}
			if base.ranged:
				return {&"lederreste": 2, &"eisenerz": 1}
			if base.light:
				return {&"eisenerz": 1, &"lederreste": 1}
			return {&"eisenerz": 2, &"lederreste": 1}
		Enums.EquipSlot.OFF_HAND:
			if base.quiver:
				return {&"lederreste": 2}
			if base.spell_damage > 0 or base.base_armor == 0:
				return {&"kristallstaub": 2}
			return {&"eisenerz": 2, &"lederreste": 1}
		Enums.EquipSlot.RING_1, Enums.EquipSlot.RING_2, Enums.EquipSlot.AMULET:
			return {&"kristallstaub": 2}
	# Rüstungsteile nach Gewichtsklasse; Roben (ohne Klasse) brauchen Kristall.
	match base.armor_class:
		Enums.ArmorClass.LEATHER:
			return {&"lederreste": 2}
		Enums.ArmorClass.CHAIN:
			return {&"eisenerz": 1, &"lederreste": 1}
		Enums.ArmorClass.PLATE:
			return {&"eisenerz": 2}
	return {&"kristallstaub": 1, &"lederreste": 1}


## Kosten fürs Neuwürfeln der Affixe (skaliert mit dem Item-Level).
static func reroll_cost(item: ItemInstance) -> Dictionary:
	return {
		"gold": 15 + item.item_level * 5,
		"materials": {&"kristallstaub": 1},
	}


## Würfelt die Affixe eines Items neu — Basis, Level und Rarity bleiben.
## Auch die Qualitäts-Rolls werden neu gewürfelt (der eigentliche Jackpot).
static func reroll(item: ItemInstance, rng: RandomNumberGenerator) -> void:
	var empty: Array[Affix] = []
	var empty_rolls: Array[float] = []
	item.affixes = empty
	item.affix_rolls = empty_rolls
	LootGenerator.apply_random_affixes(item, rng)
