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

	var S := Enums.PhysicalSubtype
	# --- Waffen: Einhand ------------------------------------------------------
	_weapon(&"kurzschwert", "Kurzschwert", 6, [S.PIERCE, S.SLASH], false, null, 1)
	_weapon(&"dolch", "Dolch", 4, [S.PIERCE], false, _stats(0, 0, 0, 0, 1, 0), 1)
	_weapon(&"knueppel", "Knüppel", 5, [S.BLUNT], false, null, 1)
	_weapon(&"zauberstab", "Zauberstab", 4, [S.BLUNT], false, _stats(0, 2, 0, 0, 0, 0), 1)
	_weapon(&"axt", "Axt", 8, [S.SLASH], false, null, 2)
	_weapon(&"streitkolben", "Streitkolben", 9, [S.BLUNT], false, null, 2)
	_weapon(&"langschwert", "Langschwert", 10, [S.PIERCE, S.SLASH], false, null, 3)
	# --- Waffen: Zweihand (blockieren die Nebenhand) --------------------------
	_weapon(&"bogen", "Bogen", 11, [S.PIERCE], true, null, 2)
	_weapon(&"zweihandschwert", "Zweihandschwert", 16, [S.PIERCE, S.SLASH], true, null, 3)
	_weapon(&"zweihandaxt", "Zweihandaxt", 15, [S.SLASH], true, null, 3)
	_weapon(&"kriegsstab", "Kriegsstab", 7, [S.BLUNT], true, _stats(0, 4, 0, 0, 0, 0), 3)
	_weapon(&"kriegshammer", "Kriegshammer", 17, [S.BLUNT], true, null, 4)
	# --- Nebenhand -------------------------------------------------------------
	_armor(&"holzschild", "Holzschild", Enums.EquipSlot.OFF_HAND, 2,
		Enums.ArmorClass.LEATHER, null, 1)
	_base(&"zauberbuch", "Zauberbuch", Enums.EquipSlot.OFF_HAND, 0, 0, _stats(0, 2, 0, 1, 0, 0), 2)
	_armor(&"turmschild", "Turmschild", Enums.EquipSlot.OFF_HAND, 4,
		Enums.ArmorClass.PLATE, null, 3)
	# --- Rüstungsteile (Rüstungstyp bestimmt Schutz vs. Stich/Schnitt/Stumpf) --
	_armor(&"lederkappe", "Lederkappe", Enums.EquipSlot.HELMET, 1,
		Enums.ArmorClass.LEATHER, null, 1)
	_armor(&"eisenhelm", "Eisenhelm", Enums.EquipSlot.HELMET, 3,
		Enums.ArmorClass.CHAIN, null, 2)
	_armor(&"lederharnisch", "Lederharnisch", Enums.EquipSlot.ARMOR, 2,
		Enums.ArmorClass.LEATHER, null, 1)
	_armor(&"kettenhemd", "Kettenhemd", Enums.EquipSlot.ARMOR, 4,
		Enums.ArmorClass.CHAIN, null, 2)
	_armor(&"plattenpanzer", "Plattenpanzer", Enums.EquipSlot.ARMOR, 6,
		Enums.ArmorClass.PLATE, null, 4)
	_armor(&"lederhandschuhe", "Lederhandschuhe", Enums.EquipSlot.GLOVES, 1,
		Enums.ArmorClass.LEATHER, null, 1)
	_armor(&"kettenhandschuhe", "Kettenhandschuhe", Enums.EquipSlot.GLOVES, 2,
		Enums.ArmorClass.CHAIN, _stats(1, 0, 0, 0, 0, 0), 2)
	_armor(&"lederstiefel", "Lederstiefel", Enums.EquipSlot.BOOTS, 1,
		Enums.ArmorClass.LEATHER, _stats(0, 0, 0, 0, 1, 0), 1)
	_armor(&"reisestiefel", "Reisestiefel", Enums.EquipSlot.BOOTS, 1,
		Enums.ArmorClass.LEATHER, _stats(0, 0, 0, 0, 3, 0), 3)
	# --- Schmuck ----------------------------------------------------------------
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
		armor: int, stat_bonus: StatBlock, min_tier: int) -> ItemBase:
	var base := ItemBase.new()
	base.id = id
	base.display_name = name
	base.slot = slot
	base.base_damage = damage
	base.base_armor = armor
	base.stat_bonus = stat_bonus
	base.min_tier = min_tier
	_bases.append(base)
	return base


static func _weapon(id: StringName, name: String, damage: int,
		subtypes: Array, two_handed: bool,
		stat_bonus: StatBlock, min_tier: int) -> void:
	var base := _base(id, name, Enums.EquipSlot.WEAPON, damage, 0, stat_bonus, min_tier)
	var typed: Array[Enums.PhysicalSubtype] = []
	for subtype in subtypes:
		typed.append(subtype)
	base.weapon_subtypes = typed
	base.two_handed = two_handed


static func _armor(id: StringName, name: String, slot: Enums.EquipSlot, armor: int,
		armor_class: Enums.ArmorClass, stat_bonus: StatBlock, min_tier: int) -> void:
	var base := _base(id, name, slot, 0, armor, stat_bonus, min_tier)
	base.armor_class = armor_class


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
