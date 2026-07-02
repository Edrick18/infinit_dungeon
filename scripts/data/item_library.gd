class_name ItemLibrary
extends RefCounted
## Katalog der Basis-Items und Affixe fürs Loot-System (Diablo-Prinzip:
## Basis-Item + zufällige Prefix/Suffix-Affixe = konkretes Item).
## Vorerst im Code definiert, später .tres-Dateien in data/.

static var _bases: Array[ItemBase] = []
static var _affixes: Array[Affix] = []


static func bases_for_tier(tier: int) -> Array[ItemBase]:
	_ensure_built()
	var result: Array[ItemBase] = []
	for base in _bases:
		if base.min_tier <= tier:
			result.append(base)
	return result


static func affixes_for_tier(tier: int, prefixes: bool) -> Array[Affix]:
	_ensure_built()
	var result: Array[Affix] = []
	for affix in _affixes:
		if affix.tier <= tier and affix.is_prefix == prefixes:
			result.append(affix)
	return result


static func _ensure_built() -> void:
	if not _bases.is_empty():
		return

	# --- Basis-Items -------------------------------------------------------
	# Waffen
	_base(&"kurzschwert", "Kurzschwert", Enums.EquipSlot.WEAPON, 6, 0, null, 1)
	_base(&"zauberstab", "Zauberstab", Enums.EquipSlot.WEAPON, 4, 0, _stats(0, 2, 0, 0, 0, 0), 1)
	_base(&"streitkolben", "Streitkolben", Enums.EquipSlot.WEAPON, 9, 0, null, 2)
	_base(&"langschwert", "Langschwert", Enums.EquipSlot.WEAPON, 12, 0, null, 3)
	_base(&"kriegsstab", "Kriegsstab", Enums.EquipSlot.WEAPON, 7, 0, _stats(0, 4, 0, 0, 0, 0), 3)
	# Nebenhand
	_base(&"holzschild", "Holzschild", Enums.EquipSlot.OFF_HAND, 0, 2, null, 1)
	_base(&"zauberbuch", "Zauberbuch", Enums.EquipSlot.OFF_HAND, 0, 0, _stats(0, 2, 0, 1, 0, 0), 2)
	_base(&"turmschild", "Turmschild", Enums.EquipSlot.OFF_HAND, 0, 4, null, 3)
	# Rüstungsteile
	_base(&"lederkappe", "Lederkappe", Enums.EquipSlot.HELMET, 0, 1, null, 1)
	_base(&"eisenhelm", "Eisenhelm", Enums.EquipSlot.HELMET, 0, 3, null, 2)
	_base(&"lederharnisch", "Lederharnisch", Enums.EquipSlot.ARMOR, 0, 2, null, 1)
	_base(&"kettenhemd", "Kettenhemd", Enums.EquipSlot.ARMOR, 0, 4, null, 2)
	_base(&"plattenpanzer", "Plattenpanzer", Enums.EquipSlot.ARMOR, 0, 6, null, 4)
	_base(&"lederhandschuhe", "Lederhandschuhe", Enums.EquipSlot.GLOVES, 0, 1, null, 1)
	_base(&"kettenhandschuhe", "Kettenhandschuhe", Enums.EquipSlot.GLOVES, 0, 2,
		_stats(1, 0, 0, 0, 0, 0), 2)
	_base(&"lederstiefel", "Lederstiefel", Enums.EquipSlot.BOOTS, 0, 1,
		_stats(0, 0, 0, 0, 1, 0), 1)
	_base(&"reisestiefel", "Reisestiefel", Enums.EquipSlot.BOOTS, 0, 1,
		_stats(0, 0, 0, 0, 3, 0), 3)
	# Schmuck
	_base(&"silberring", "Silberring", Enums.EquipSlot.RING_1, 0, 0, null, 1)
	_base(&"goldring", "Goldring", Enums.EquipSlot.RING_1, 0, 0, _stats(0, 0, 0, 0, 0, 1), 2)
	_base(&"knochenamulett", "Knochenamulett", Enums.EquipSlot.AMULET, 0, 0,
		_stats(0, 0, 0, 2, 0, 0), 1)
	_base(&"jadeamulett", "Jadeamulett", Enums.EquipSlot.AMULET, 0, 0,
		_stats(0, 2, 1, 0, 0, 0), 2)

	# --- Affixe: Prefixe -----------------------------------------------------
	_affix(&"flammend", true, "Flammendes", null, 3, 0, 1)
	_affix(&"robust", true, "Robustes", null, 0, 2, 1)
	_affix(&"flink", true, "Flinkes", _stats(0, 0, 0, 0, 2, 0), 0, 0, 1)
	_affix(&"gesegnet", true, "Gesegnetes", _stats(0, 0, 0, 2, 0, 0), 0, 0, 1)
	_affix(&"grausam", true, "Grausames", null, 6, 0, 2)
	_affix(&"gehaertet", true, "Gehärtetes", null, 0, 4, 2)
	_affix(&"brutal", true, "Brutales", null, 10, 0, 3)

	# --- Affixe: Suffixe -----------------------------------------------------
	_affix(&"staerke", false, "der Stärke", _stats(3, 0, 0, 0, 0, 0), 0, 0, 1)
	_affix(&"geist", false, "des Geistes", _stats(0, 3, 0, 0, 0, 0), 0, 0, 1)
	_affix(&"vitalitaet", false, "der Vitalität", _stats(0, 0, 3, 0, 0, 0), 0, 0, 1)
	_affix(&"sturm", false, "des Sturms", _stats(0, 0, 0, 0, 3, 0), 0, 0, 1)
	_affix(&"glueck", false, "des Glücks", _stats(0, 0, 0, 0, 0, 3), 0, 0, 1)
	_affix(&"abwehr", false, "der Abwehr", null, 0, 3, 2)
	_affix(&"verwuestung", false, "der Verwüstung", null, 5, 0, 2)
	_affix(&"titanen", false, "der Titanen", _stats(3, 0, 3, 0, 0, 0), 0, 0, 3)
	_affix(&"weisheit", false, "der Weisheit", _stats(0, 3, 0, 3, 0, 0), 0, 0, 3)


static func _base(id: StringName, name: String, slot: Enums.EquipSlot, damage: int,
		armor: int, stat_bonus: StatBlock, min_tier: int) -> void:
	var base := ItemBase.new()
	base.id = id
	base.display_name = name
	base.slot = slot
	base.base_damage = damage
	base.base_armor = armor
	base.stat_bonus = stat_bonus
	base.min_tier = min_tier
	_bases.append(base)


static func _affix(id: StringName, is_prefix: bool, name_part: String,
		stat_bonus: StatBlock, damage: int, armor: int, tier: int) -> void:
	var affix := Affix.new()
	affix.id = id
	affix.is_prefix = is_prefix
	affix.name_part = name_part
	affix.stat_bonus = stat_bonus
	affix.bonus_damage = damage
	affix.bonus_armor = armor
	affix.tier = tier
	_affixes.append(affix)


static func _stats(strength: int, intelligence: int, vitality: int,
		spirit: int, agility: int, luck: int) -> StatBlock:
	var stats := StatBlock.new()
	stats.strength = strength
	stats.intelligence = intelligence
	stats.vitality = vitality
	stats.spirit = spirit
	stats.agility = agility
	stats.luck = luck
	return stats
