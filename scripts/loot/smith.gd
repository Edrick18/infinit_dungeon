class_name Smith
extends RefCounted
## Schmiede-Logik: Gear gezielt nach TYP craften — welche Basis es wird, ist
## zufällig, das Item-Level streut leicht um das Durchschnittslevel der Party.
## Dazu: Affixe eines Items neu würfeln (der Material-/Gold-Sink fürs Endgame).

## Wie weit das Item-Level vom Party-Schnitt abweichen darf (±).
const LEVEL_DEVIATION := 2

## Craft-Kategorien: Typ ist wählbar, die konkrete Basis ist zufällig.
## "mats" = Material-Profil (Metall vs. Arkan), Gold skaliert mit dem Level.
const CATEGORY_ORDER: Array[StringName] = [&"einhand", &"zweihand", &"stab",
	&"nebenhand", &"ruestung", &"helm", &"handschuhe", &"stiefel", &"ring", &"amulett"]
const CATEGORIES := {
	&"einhand": {"name": "Einhandwaffe", "mats": {&"eisenerz": 2, &"lederreste": 1}},
	&"zweihand": {"name": "Zweihandwaffe", "mats": {&"eisenerz": 3, &"lederreste": 1}},
	&"stab": {"name": "Stab / Fokus", "mats": {&"kristallstaub": 2, &"eisenerz": 1}},
	&"nebenhand": {"name": "Schild / Nebenhand", "mats": {&"eisenerz": 2, &"lederreste": 1}},
	&"ruestung": {"name": "Rüstung", "mats": {&"eisenerz": 2, &"lederreste": 2}},
	&"helm": {"name": "Helm", "mats": {&"eisenerz": 1, &"lederreste": 1}},
	&"handschuhe": {"name": "Handschuhe", "mats": {&"lederreste": 2}},
	&"stiefel": {"name": "Stiefel", "mats": {&"lederreste": 2}},
	&"ring": {"name": "Ring", "mats": {&"kristallstaub": 1, &"eisenerz": 1}},
	&"amulett": {"name": "Amulett", "mats": {&"kristallstaub": 2}},
}


static func category_name(id: StringName) -> String:
	return CATEGORIES[id]["name"]


## Item-Level: Party-Schnitt mit leichter Streuung (nie unter 1).
static func roll_level(avg_level: int, rng: RandomNumberGenerator) -> int:
	return maxi(1, avg_level + rng.randi_range(-LEVEL_DEVIATION, LEVEL_DEVIATION))


static func _matches(category: StringName, base: ItemBase) -> bool:
	match category:
		&"einhand":
			return base.slot == Enums.EquipSlot.WEAPON and base.base_damage > 0 \
				and not base.two_handed
		&"zweihand":
			return base.slot == Enums.EquipSlot.WEAPON and base.base_damage > 0 \
				and base.two_handed
		&"stab":
			return base.slot == Enums.EquipSlot.WEAPON and base.spell_damage > 0
		&"nebenhand":
			return base.slot == Enums.EquipSlot.OFF_HAND
		&"ruestung":
			return base.slot == Enums.EquipSlot.ARMOR
		&"helm":
			return base.slot == Enums.EquipSlot.HELMET
		&"handschuhe":
			return base.slot == Enums.EquipSlot.GLOVES
		&"stiefel":
			return base.slot == Enums.EquipSlot.BOOTS
		&"ring":
			return base.slot == Enums.EquipSlot.RING_1
		&"amulett":
			return base.slot == Enums.EquipSlot.AMULET
	return false


static func _pool(category: StringName, item_level: int) -> Array[ItemBase]:
	var result: Array[ItemBase] = []
	for base in ItemLibrary.bases_for_tier(item_level):
		if _matches(category, base):
			result.append(base)
	return result


## Gibt es auf diesem Level überhaupt Basen dieser Kategorie?
## (Zweihänder z.B. erst ab Stufe 2 — der Button ist vorher gesperrt.)
static func can_craft(category: StringName, avg_level: int) -> bool:
	return not _pool(category, avg_level + LEVEL_DEVIATION).is_empty()


## Craftet ein Item der Kategorie: zufällige Basis, Level um den Party-Schnitt,
## mindestens MAGIC (die Schmiede liefert keinen grauen Schrott), Affixe random.
static func craft(category: StringName, avg_level: int,
		rng: RandomNumberGenerator) -> ItemInstance:
	var item_level := roll_level(avg_level, rng)
	var pool := _pool(category, item_level)
	if pool.is_empty():
		# Streuung nach unten kann seltene Kategorien leeren — nach oben öffnen.
		item_level = avg_level + LEVEL_DEVIATION
		pool = _pool(category, item_level)
	if pool.is_empty():
		return null
	var item := ItemInstance.new()
	item.base = pool[rng.randi_range(0, pool.size() - 1)]
	item.item_level = item_level
	item.rarity = LootGenerator.roll_rarity(rng)
	if item.rarity == Enums.Rarity.COMMON:
		item.rarity = Enums.Rarity.MAGIC
	LootGenerator.apply_random_affixes(item, rng)
	return item


## Kosten fürs Craften: Material-Profil der Kategorie + Gold nach Party-Level.
static func craft_cost(category: StringName, avg_level: int) -> Dictionary:
	return {
		"gold": 25 + avg_level * 10,
		"materials": CATEGORIES[category]["mats"],
	}


## Kosten fürs Neuwürfeln der Affixe (skaliert mit dem Item-Level).
static func reroll_cost(item: ItemInstance) -> Dictionary:
	return {
		"gold": 15 + item.item_level * 5,
		"materials": {&"kristallstaub": 1},
	}


## Würfelt die Affixe eines Items neu — Basis, Level und Rarity bleiben.
static func reroll(item: ItemInstance, rng: RandomNumberGenerator) -> void:
	var empty: Array[Affix] = []
	item.affixes = empty
	LootGenerator.apply_random_affixes(item, rng)
