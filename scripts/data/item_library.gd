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


static func get_base(id: StringName) -> ItemBase:
	_ensure_built()
	for base in _bases:
		if base.id == id:
			return base
	return null


## Fertiges, affixfreies Item aus einer Basis-ID (z.B. Startwaffen).
static func make_item(id: StringName, item_level := 1) -> ItemInstance:
	var base := get_base(id)
	if base == null:
		return null
	var item := ItemInstance.new()
	item.base = base
	item.item_level = item_level
	return item


static func get_affix(id: StringName) -> Affix:
	_ensure_built()
	for affix in _affixes:
		if affix.id == id:
			return affix
	return null


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
	# --- Waffen: Einhand (physischer Waffenschaden) ---------------------------
	_weapon(&"kurzschwert", "Kurzschwert", 6, [S.PIERCE, S.SLASH], false, null, 1)
	_weapon(&"dolch", "Dolch", 4, [S.PIERCE], false, _stats(0, 0, 0, 0, 1, 0), 1)
	_weapon(&"knueppel", "Knüppel", 5, [S.BLUNT], false, null, 1)
	_weapon(&"axt", "Axt", 8, [S.SLASH], false, null, 2)
	_weapon(&"streitkolben", "Streitkolben", 9, [S.BLUNT], false, null, 2)
	_weapon(&"langschwert", "Langschwert", 10, [S.PIERCE, S.SLASH], false, null, 3)
	_weapon(&"rapier", "Rapier", 11, [S.PIERCE], false, _stats(0, 0, 0, 0, 2, 0), 4)
	_weapon(&"morgenstern", "Morgenstern", 13, [S.BLUNT, S.PIERCE], false, null, 5)
	_weapon(&"runenklinge", "Runenklinge", 12, [S.PIERCE, S.SLASH], false,
		_stats(0, 2, 0, 0, 0, 0), 6)
	# --- Stäbe/Foki (Zauberschaden für die Zauber-Quelle) ---------------------
	_staff(&"lehrlingsstab", "Lehrlingsstab", 6, false, null, 1)
	_staff(&"offensivstab", "Arkanstab", 9, false, _stats(0, 2, 0, 0, 0, 0), 2)
	_staff(&"heiligstab", "Heiligstab", 8, false, _stats(0, 0, 0, 2, 0, 0), 2)
	_staff(&"kriegsstab", "Kriegsstab", 12, true, _stats(0, 4, 0, 0, 0, 0), 3)
	_staff(&"nekrostab", "Nekrostab", 11, false, _stats(0, 2, 0, 1, 0, 0), 4)
	_staff(&"erzstab", "Erzstab", 16, true, _stats(0, 3, 0, 0, 0, 0), 5)
	_staff(&"seelenstab", "Seelenstab", 14, false, _stats(0, 2, 0, 2, 0, 0), 7)
	# --- Waffen: Zweihand (blockieren die Nebenhand) --------------------------
	_weapon(&"bogen", "Bogen", 11, [S.PIERCE], true, null, 2)
	_weapon(&"zweihandschwert", "Zweihandschwert", 16, [S.PIERCE, S.SLASH], true, null, 3)
	_weapon(&"zweihandaxt", "Zweihandaxt", 15, [S.SLASH], true, null, 3)
	_weapon(&"kriegshammer", "Kriegshammer", 17, [S.BLUNT], true, null, 4)
	_weapon(&"armbrust", "Armbrust", 19, [S.PIERCE], true, null, 5)
	_weapon(&"kriegssense", "Kriegssense", 21, [S.SLASH], true, null, 6)
	_weapon(&"daemonenklinge", "Dämonenklinge", 24, [S.PIERCE, S.SLASH], true,
		_stats(2, 0, 0, 0, 0, 0), 8)
	# --- Nebenhand -------------------------------------------------------------
	_armor(&"holzschild", "Holzschild", Enums.EquipSlot.OFF_HAND, 2,
		Enums.ArmorClass.LEATHER, null, 1)
	_base(&"zauberbuch", "Zauberbuch", Enums.EquipSlot.OFF_HAND, 0, 0, _stats(0, 2, 0, 1, 0, 0), 2)
	_armor(&"turmschild", "Turmschild", Enums.EquipSlot.OFF_HAND, 4,
		Enums.ArmorClass.PLATE, null, 3)
	var focus := _base(&"kristallfokus", "Kristallfokus", Enums.EquipSlot.OFF_HAND, 0, 0,
		_stats(0, 1, 0, 1, 0, 0), 4)
	focus.spell_damage = 4
	_armor(&"spiegelschild", "Spiegelschild", Enums.EquipSlot.OFF_HAND, 3,
		Enums.ArmorClass.CHAIN, _stats(0, 0, 0, 1, 0, 0), 6)
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
	_armor(&"schuppenpanzer", "Schuppenpanzer", Enums.EquipSlot.ARMOR, 5,
		Enums.ArmorClass.CHAIN, _stats(0, 0, 1, 0, 0, 0), 5)
	_armor(&"ritterhelm", "Ritterhelm", Enums.EquipSlot.HELMET, 4,
		Enums.ArmorClass.PLATE, null, 5)
	_armor(&"drachenharnisch", "Drachenschuppenharnisch", Enums.EquipSlot.ARMOR, 8,
		Enums.ArmorClass.PLATE, _stats(0, 0, 2, 0, 0, 0), 8)
	_armor(&"lederhandschuhe", "Lederhandschuhe", Enums.EquipSlot.GLOVES, 1,
		Enums.ArmorClass.LEATHER, null, 1)
	_armor(&"kettenhandschuhe", "Kettenhandschuhe", Enums.EquipSlot.GLOVES, 2,
		Enums.ArmorClass.CHAIN, _stats(1, 0, 0, 0, 0, 0), 2)
	_armor(&"lederstiefel", "Lederstiefel", Enums.EquipSlot.BOOTS, 1,
		Enums.ArmorClass.LEATHER, _stats(0, 0, 0, 0, 1, 0), 1)
	_armor(&"reisestiefel", "Reisestiefel", Enums.EquipSlot.BOOTS, 1,
		Enums.ArmorClass.LEATHER, _stats(0, 0, 0, 0, 3, 0), 3)
	_armor(&"plattenstiefel", "Plattenstiefel", Enums.EquipSlot.BOOTS, 2,
		Enums.ArmorClass.PLATE, _stats(0, 0, 1, 0, 0, 0), 6)
	_armor(&"plattenhandschuhe", "Plattenhandschuhe", Enums.EquipSlot.GLOVES, 3,
		Enums.ArmorClass.PLATE, null, 6)
	# --- Schmuck ----------------------------------------------------------------
	_base(&"silberring", "Silberring", Enums.EquipSlot.RING_1, 0, 0, null, 1)
	_base(&"goldring", "Goldring", Enums.EquipSlot.RING_1, 0, 0, _stats(0, 0, 0, 0, 0, 1), 2)
	_base(&"knochenamulett", "Knochenamulett", Enums.EquipSlot.AMULET, 0, 0,
		_stats(0, 0, 0, 2, 0, 0), 1)
	_base(&"jadeamulett", "Jadeamulett", Enums.EquipSlot.AMULET, 0, 0,
		_stats(0, 2, 1, 0, 0, 0), 2)
	_base(&"rubinring", "Rubinring", Enums.EquipSlot.RING_1, 0, 0,
		_stats(0, 2, 0, 0, 0, 0), 4)
	_base(&"siegelring", "Siegelring", Enums.EquipSlot.RING_1, 0, 0,
		_stats(2, 0, 2, 0, 0, 0), 6)
	_base(&"sternenamulett", "Sternenamulett", Enums.EquipSlot.AMULET, 0, 0,
		_stats(0, 2, 0, 2, 0, 1), 7)

	# --- Affixe: Prefixe -----------------------------------------------------
	_affix(&"flammend", true, "Flammendes", null, 3, 0, 1)
	_affix(&"robust", true, "Robustes", null, 0, 2, 1)
	_affix(&"flink", true, "Flinkes", _stats(0, 0, 0, 0, 2, 0), 0, 0, 1)
	_affix(&"gesegnet", true, "Gesegnetes", _stats(0, 0, 0, 2, 0, 0), 0, 0, 1)
	_affix(&"grausam", true, "Grausames", null, 6, 0, 2)
	_affix(&"gehaertet", true, "Gehärtetes", null, 0, 4, 2)
	_affix(&"brutal", true, "Brutales", null, 10, 0, 3)

	# --- Affixe: Prefixe für Caster (Zauberkraft, nur Waffe/Nebenhand) --------
	_spell_affix(&"arkan", "Arkanes", 3, 2)
	_spell_affix(&"verzaubert", "Verzaubertes", 6, 4)
	_spell_affix(&"transzendent", "Transzendentes", 10, 6)

	# --- Affixe: Element-Rider (nur Waffen) — Waffennutzung trägt das Element --
	_rider_affix(&"lodernd", "Loderndes", Enums.Element.FIRE, 4, 3)
	_rider_affix(&"giftgetraenkt", "Giftgetränktes", Enums.Element.POISON, 3, 4)
	_rider_affix(&"frostig", "Frostiges", Enums.Element.ICE, 5, 5)
	_rider_affix(&"knisternd", "Knisterndes", Enums.Element.LIGHTNING, 5, 6)
	_rider_affix(&"geweiht", "Geweihtes", Enums.Element.HOLY, 5, 7)
	_rider_affix(&"schattenhaft", "Schattenhaftes", Enums.Element.DARK, 5, 8)

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

	# --- Affixe: Element-Resistenzen (Rüstung/Schild/Schmuck) — das Gegenmittel
	# zu den Element-Gegnern hoher Kartenstufen.
	_resist_affix(&"feuerabwehr", "der Feuerabwehr", Enums.Element.FIRE, 4, 3)
	_resist_affix(&"giftabwehr", "der Giftabwehr", Enums.Element.POISON, 4, 4)
	_resist_affix(&"frostabwehr", "der Frostabwehr", Enums.Element.ICE, 4, 5)
	_resist_affix(&"blitzabwehr", "der Blitzabwehr", Enums.Element.LIGHTNING, 4, 6)
	_resist_affix(&"schattenabwehr", "der Schattenabwehr", Enums.Element.DARK, 4, 8)
	_resist_affix(&"bannung", "der Bannung", Enums.Element.NONE, 3, 9)  # alle Elemente

	# --- Affixe: Skill-Suffixe (MP-Kosten, Waffe/Nebenhand/Schmuck) ------------
	_skill_affix(&"fokus", "des Fokus", 2, 2)
	_skill_affix(&"klarheit", "der Klarheit", 4, 5)
	_skill_affix(&"erzmagier", "des Erzmagiers", 6, 8)


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


## Stab/Fokus: Zauberschaden (spell_damage) statt physischem Waffenschaden.
static func _staff(id: StringName, name: String, spell_dmg: int, two_handed: bool,
		stat_bonus: StatBlock, min_tier: int) -> void:
	var base := _base(id, name, Enums.EquipSlot.WEAPON, 0, 0, stat_bonus, min_tier)
	base.spell_damage = spell_dmg
	base.two_handed = two_handed
	# Stäbe können notfalls stumpf zuschlagen (falls jemand Waffennutzung wählt).
	base.weapon_subtypes = [Enums.PhysicalSubtype.BLUNT] as Array[Enums.PhysicalSubtype]


static func _armor(id: StringName, name: String, slot: Enums.EquipSlot, armor: int,
		armor_class: Enums.ArmorClass, stat_bonus: StatBlock, min_tier: int) -> void:
	var base := _base(id, name, slot, 0, armor, stat_bonus, min_tier)
	base.armor_class = armor_class


static func _affix(id: StringName, is_prefix: bool, name_part: String,
		stat_bonus: StatBlock, damage: int, armor: int, tier: int) -> Affix:
	var affix := Affix.new()
	affix.id = id
	affix.is_prefix = is_prefix
	affix.name_part = name_part
	affix.stat_bonus = stat_bonus
	affix.bonus_damage = damage
	affix.bonus_armor = armor
	affix.tier = tier
	_affixes.append(affix)
	return affix


## Slots, auf denen Rüstungs-/Schmuck-Affixe (Resistenzen, …) rollen dürfen.
static func _defensive_slots() -> Array[Enums.EquipSlot]:
	return [Enums.EquipSlot.HELMET, Enums.EquipSlot.ARMOR, Enums.EquipSlot.GLOVES,
		Enums.EquipSlot.BOOTS, Enums.EquipSlot.OFF_HAND, Enums.EquipSlot.RING_1,
		Enums.EquipSlot.AMULET] as Array[Enums.EquipSlot]


## Element-Rider-Prefix: Waffennutzung trägt zusätzlichen Elementschaden.
static func _rider_affix(id: StringName, name_part: String, element: Enums.Element,
		damage: int, tier: int) -> void:
	var affix := _affix(id, true, name_part, null, 0, 0, tier)
	affix.element = element
	affix.element_damage = damage
	affix.allowed_slots = [Enums.EquipSlot.WEAPON] as Array[Enums.EquipSlot]


## Resistenz-Suffix: flache Minderung gegen ein Element (NONE = alle).
static func _resist_affix(id: StringName, name_part: String, element: Enums.Element,
		resist: int, tier: int) -> void:
	var affix := _affix(id, false, name_part, null, 0, 0, tier)
	affix.element = element
	affix.element_resist = resist
	affix.allowed_slots = _defensive_slots()


## Zauberkraft-Prefix für Stäbe/Foki.
static func _spell_affix(id: StringName, name_part: String, spell_damage: int,
		tier: int) -> void:
	var affix := _affix(id, true, name_part, null, 0, 0, tier)
	affix.bonus_spell_damage = spell_damage
	affix.allowed_slots = [Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND] \
		as Array[Enums.EquipSlot]


## Skill-Suffix: senkt die MP-Kosten aller Skills des Trägers flach.
static func _skill_affix(id: StringName, name_part: String, reduction: int,
		tier: int) -> void:
	var affix := _affix(id, false, name_part, null, 0, 0, tier)
	affix.mp_cost_reduction = reduction
	affix.allowed_slots = [Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND,
		Enums.EquipSlot.RING_1, Enums.EquipSlot.AMULET] as Array[Enums.EquipSlot]


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
