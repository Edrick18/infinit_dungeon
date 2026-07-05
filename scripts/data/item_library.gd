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


## Alt-IDs aus früheren Katalog-Versionen » heutige Basis (alte Spielstände
## behalten ihre Items, statt sie beim Laden still zu verlieren).
const LEGACY_ALIASES := {
	&"kurzschwert": &"schwert", &"langschwert": &"schwert", &"rapier": &"schwert",
	&"runenklinge": &"schwert", &"daemonenklinge": &"zweihandschwert",
	&"stilett": &"dolch", &"schattenklinge": &"dolch",
	&"streitkolben": &"knueppel", &"morgenstern": &"knueppel",
	&"kriegssense": &"zweihandaxt",
	&"lehrlingsstab": &"offensivstab", &"kriegsstab": &"offensivstab",
	&"erzstab": &"offensivstab", &"nekrostab": &"offensivstab",
	&"seelenstab": &"heiligstab",
	&"holzschild": &"schild", &"turmschild": &"schild", &"spiegelschild": &"schild",
	&"jagdkoecher": &"koecher", &"kriegskoecher": &"koecher",
	&"lederharnisch": &"ruestung_leicht", &"kettenhemd": &"ruestung_mittel",
	&"schuppenpanzer": &"ruestung_mittel", &"plattenpanzer": &"ruestung_schwer",
	&"drachenharnisch": &"ruestung_schwer",
	&"lederkappe": &"helm_leicht", &"eisenhelm": &"helm_schwer",
	&"ritterhelm": &"helm_schwer",
	&"lederhandschuhe": &"handschuhe_leicht", &"kettenhandschuhe": &"handschuhe_schwer",
	&"plattenhandschuhe": &"handschuhe_schwer",
	&"lederstiefel": &"stiefel_leicht", &"reisestiefel": &"stiefel_leicht",
	&"plattenstiefel": &"stiefel_schwer",
	&"silberring": &"ring", &"goldring": &"ring", &"rubinring": &"ring",
	&"siegelring": &"ring",
	&"knochenamulett": &"amulett", &"jadeamulett": &"amulett",
	&"sternenamulett": &"amulett",
}


static func get_base(id: StringName) -> ItemBase:
	_ensure_built()
	var lookup: StringName = LEGACY_ALIASES.get(id, id)
	for base in _bases:
		if base.id == lookup:
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
	# =========================================================================
	# EIN Basis-Item pro Kategorie (Design-Entscheidung): "Dolch ist Dolch".
	# Die ganze Item-Vielfalt entsteht aus Affixen, Raritäten, Namen und dem
	# endlos skalierenden Item-Level — nicht aus Basis-Duplikaten.
	# =========================================================================
	# --- Waffen ----------------------------------------------------------------
	_weapon(&"schwert", "Schwert", 8, [S.PIERCE, S.SLASH], false, null, 1, &"schwert")
	_weapon(&"zweihandschwert", "Zweihandschwert", 16, [S.PIERCE, S.SLASH], true, null, 3,
		&"schwert")
	var dolch := _weapon(&"dolch", "Dolch", 5, [S.PIERCE], false,
		_stats(0, 0, 0, 0, 1, 0), 1, &"dolch")
	dolch.light = true  # Dual Wield: zweiter Dolch in die Nebenhand
	_weapon(&"axt", "Axt", 9, [S.SLASH], false, null, 2, &"axt")
	_weapon(&"zweihandaxt", "Zweihandaxt", 15, [S.SLASH], true, null, 3, &"axt")
	_weapon(&"knueppel", "Knüppel", 6, [S.BLUNT], false, null, 1, &"stumpf")
	_weapon(&"kriegshammer", "Kriegshammer", 17, [S.BLUNT], true, null, 4, &"stumpf")
	# Fernkampf: zweihändig, aber ein KÖCHER darf in die Nebenhand.
	# Bogen: 2 Pfeile pro Waffennutzung (Mitigation greift pro Pfeil).
	# Armbrust: ein schwerer Bolzen mit Rüstungsdurchdringung.
	var bogen := _weapon(&"bogen", "Bogen", 7, [S.PIERCE], true, null, 2, &"bogen")
	bogen.ranged = true
	bogen.hit_count = 2
	var armbrust := _weapon(&"armbrust", "Armbrust", 20, [S.PIERCE], true, null, 5, &"armbrust")
	armbrust.ranged = true
	armbrust.armor_pierce = 0.2
	# Zwei Zauberstab-Arten (Design): offensiv (INT) und heilig (SPI).
	_staff(&"offensivstab", "Offensivstab", 9, false, _stats(0, 2, 0, 0, 0, 0), 1)
	_staff(&"heiligstab", "Heiligstab", 8, false, _stats(0, 0, 0, 2, 0, 0), 1)
	# --- Nebenhand ---------------------------------------------------------------
	_armor(&"schild", "Schild", Enums.EquipSlot.OFF_HAND, 3,
		Enums.ArmorClass.CHAIN, null, 1)
	_base(&"zauberbuch", "Zauberbuch", Enums.EquipSlot.OFF_HAND, 0, 0, _stats(0, 2, 0, 1, 0, 0), 2)
	var focus := _base(&"kristallfokus", "Kristallfokus", Enums.EquipSlot.OFF_HAND, 0, 0,
		_stats(0, 1, 0, 1, 0, 0), 4)
	focus.spell_damage = 4
	# Zauber-Nebenhände nach Zweck: Relikt für Schadensmagie (INT),
	# Heiliges Kreuz für Heilmagie (GEIST) — die Stäbe sind einhändig,
	# die Nebenhand verstärkt die gewählte Richtung schon ab Stufe 1.
	var relikt := _base(&"relikt", "Relikt", Enums.EquipSlot.OFF_HAND, 0, 0,
		_stats(0, 1, 0, 0, 0, 0), 1)
	relikt.spell_damage = 2
	var heiligkreuz := _base(&"heiligkreuz", "Heiliges Kreuz", Enums.EquipSlot.OFF_HAND, 0, 0,
		_stats(0, 0, 0, 1, 0, 0), 1)
	heiligkreuz.spell_damage = 2
	_quiver(&"koecher", "Köcher", 3, null, 2)
	# --- Rüstung (Brust): Gewichtsklassen + Roben nach Zweck ---------------------
	_armor(&"ruestung_leicht", "Leichte Rüstung", Enums.EquipSlot.ARMOR, 3,
		Enums.ArmorClass.LEATHER, _stats(0, 0, 0, 0, 1, 0), 1)
	_armor(&"ruestung_mittel", "Mittlere Rüstung", Enums.EquipSlot.ARMOR, 5,
		Enums.ArmorClass.CHAIN, null, 2)
	_armor(&"ruestung_schwer", "Schwere Rüstung", Enums.EquipSlot.ARMOR, 6,
		Enums.ArmorClass.PLATE, _stats(0, 0, 1, 0, 0, 0), 3)
	# Roben: kaum Rüstung, dafür Zauberkraft — Schaden (INT), Heilung (SPI),
	# und die Kampfrobe dazwischen.
	var robe_schaden := _armor(&"robe_schaden", "Schadensrobe", Enums.EquipSlot.ARMOR, 1,
		Enums.ArmorClass.NONE, _stats(0, 2, 0, 0, 0, 0), 2)
	robe_schaden.spell_damage = 4
	var robe_heil := _armor(&"robe_heil", "Heilrobe", Enums.EquipSlot.ARMOR, 1,
		Enums.ArmorClass.NONE, _stats(0, 0, 0, 3, 0, 0), 2)
	robe_heil.spell_damage = 2
	var robe_kampf := _armor(&"robe_kampf", "Kampfrobe", Enums.EquipSlot.ARMOR, 2,
		Enums.ArmorClass.NONE, _stats(0, 1, 0, 1, 0, 0), 3)
	robe_kampf.spell_damage = 3
	# --- Rüstung (Kopf/Hände/Füße): leicht oder schwer ---------------------------
	_armor(&"helm_leicht", "Leichter Helm", Enums.EquipSlot.HELMET, 2,
		Enums.ArmorClass.LEATHER, null, 1)
	_armor(&"helm_schwer", "Schwerer Helm", Enums.EquipSlot.HELMET, 4,
		Enums.ArmorClass.PLATE, null, 3)
	_armor(&"handschuhe_leicht", "Leichte Handschuhe", Enums.EquipSlot.GLOVES, 1,
		Enums.ArmorClass.LEATHER, _stats(0, 0, 0, 0, 1, 0), 1)
	_armor(&"handschuhe_schwer", "Panzerhandschuhe", Enums.EquipSlot.GLOVES, 3,
		Enums.ArmorClass.PLATE, _stats(1, 0, 0, 0, 0, 0), 3)
	_armor(&"stiefel_leicht", "Leichte Stiefel", Enums.EquipSlot.BOOTS, 1,
		Enums.ArmorClass.LEATHER, _stats(0, 0, 0, 0, 2, 0), 1)
	_armor(&"stiefel_schwer", "Panzerstiefel", Enums.EquipSlot.BOOTS, 3,
		Enums.ArmorClass.PLATE, _stats(0, 0, 1, 0, 0, 0), 3)
	# --- Schmuck ----------------------------------------------------------------
	_base(&"ring", "Ring", Enums.EquipSlot.RING_1, 0, 0, null, 1)
	_base(&"amulett", "Amulett", Enums.EquipSlot.AMULET, 0, 0, null, 1)

	# Affix-Raritäten: bestimmen die Zieh-Wahrscheinlichkeit im Pool —
	# Basis-Stats häufig, Element-Rider selten, Skill-Affixe der Jackpot.
	var R := Enums.Rarity

	# --- Affixe: Prefixe -----------------------------------------------------
	_affix(&"flammend", true, "Flammendes", null, 3, 0, 1, R.COMMON)
	_affix(&"robust", true, "Robustes", null, 0, 2, 1, R.COMMON)
	_affix(&"flink", true, "Flinkes", _stats(0, 0, 0, 0, 2, 0), 0, 0, 1, R.COMMON)
	_affix(&"gesegnet", true, "Gesegnetes", _stats(0, 0, 0, 2, 0, 0), 0, 0, 1, R.MAGIC)
	_affix(&"grausam", true, "Grausames", null, 6, 0, 2, R.MAGIC)
	_affix(&"gehaertet", true, "Gehärtetes", null, 0, 4, 2, R.MAGIC)
	_affix(&"brutal", true, "Brutales", null, 10, 0, 3, R.RARE)

	# --- Affixe: Prefixe für Caster (Zauberkraft, nur Waffe/Nebenhand) --------
	_spell_affix(&"arkan", "Arkanes", 3, 2, R.MAGIC)
	_spell_affix(&"verzaubert", "Verzaubertes", 6, 4, R.RARE)
	_spell_affix(&"transzendent", "Transzendentes", 10, 6, R.EPIC)

	# --- Affixe: Element-Rider (nur Waffen) — Waffennutzung trägt das Element --
	_rider_affix(&"lodernd", "Loderndes", Enums.Element.FIRE, 4, 3, R.RARE)
	_rider_affix(&"giftgetraenkt", "Giftgetränktes", Enums.Element.POISON, 3, 4, R.RARE)
	_rider_affix(&"frostig", "Frostiges", Enums.Element.ICE, 5, 5, R.RARE)
	_rider_affix(&"knisternd", "Knisterndes", Enums.Element.LIGHTNING, 5, 6, R.RARE)
	_rider_affix(&"geweiht", "Geweihtes", Enums.Element.HOLY, 5, 7, R.EPIC)
	_rider_affix(&"schattenhaft", "Schattenhaftes", Enums.Element.DARK, 5, 8, R.EPIC)

	# --- Affixe: Suffixe -----------------------------------------------------
	_affix(&"staerke", false, "der Stärke", _stats(3, 0, 0, 0, 0, 0), 0, 0, 1, R.COMMON)
	_affix(&"geist", false, "des Geistes", _stats(0, 3, 0, 0, 0, 0), 0, 0, 1, R.COMMON)
	_affix(&"vitalitaet", false, "der Vitalität", _stats(0, 0, 3, 0, 0, 0), 0, 0, 1, R.COMMON)
	_affix(&"sturm", false, "des Sturms", _stats(0, 0, 0, 0, 3, 0), 0, 0, 1, R.COMMON)
	_affix(&"glueck", false, "des Glücks", _stats(0, 0, 0, 0, 0, 3), 0, 0, 1, R.COMMON)
	_affix(&"abwehr", false, "der Abwehr", null, 0, 3, 2, R.MAGIC)
	_affix(&"verwuestung", false, "der Verwüstung", null, 5, 0, 2, R.RARE)
	_affix(&"titanen", false, "der Titanen", _stats(3, 0, 3, 0, 0, 0), 0, 0, 3, R.RARE)
	_affix(&"weisheit", false, "der Weisheit", _stats(0, 3, 0, 3, 0, 0), 0, 0, 3, R.RARE)

	# --- Affixe: Element-Resistenzen (Rüstung/Schild/Schmuck) — das Gegenmittel
	# zu den Element-Gegnern hoher Kartenstufen.
	_resist_affix(&"feuerabwehr", "der Feuerabwehr", Enums.Element.FIRE, 4, 3, R.MAGIC)
	_resist_affix(&"giftabwehr", "der Giftabwehr", Enums.Element.POISON, 4, 4, R.MAGIC)
	_resist_affix(&"frostabwehr", "der Frostabwehr", Enums.Element.ICE, 4, 5, R.RARE)
	_resist_affix(&"blitzabwehr", "der Blitzabwehr", Enums.Element.LIGHTNING, 4, 6, R.RARE)
	_resist_affix(&"schattenabwehr", "der Schattenabwehr", Enums.Element.DARK, 4, 8, R.RARE)
	_resist_affix(&"bannung", "der Bannung", Enums.Element.NONE, 3, 9, R.EPIC)  # alle Elemente

	# --- Affixe: Skill-Suffixe (MP-Kosten, Waffe/Nebenhand/Schmuck) ------------
	_skill_affix(&"fokus", "des Fokus", 2, 2, R.RARE)
	_skill_affix(&"klarheit", "der Klarheit", 4, 5, R.EPIC)
	_skill_affix(&"erzmagier", "des Erzmagiers", 6, 8, R.LEGENDARY)


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
		stat_bonus: StatBlock, min_tier: int, family: StringName = &"") -> ItemBase:
	var base := _base(id, name, Enums.EquipSlot.WEAPON, damage, 0, stat_bonus, min_tier)
	var typed: Array[Enums.PhysicalSubtype] = []
	for subtype in subtypes:
		typed.append(subtype)
	base.weapon_subtypes = typed
	base.two_handed = two_handed
	base.family = family
	return base


## Stab/Fokus: Zauberschaden (spell_damage) statt physischem Waffenschaden.
static func _staff(id: StringName, name: String, spell_dmg: int, two_handed: bool,
		stat_bonus: StatBlock, min_tier: int) -> void:
	var base := _base(id, name, Enums.EquipSlot.WEAPON, 0, 0, stat_bonus, min_tier)
	base.spell_damage = spell_dmg
	base.two_handed = two_handed
	base.family = &"stab"
	# Stäbe können notfalls stumpf zuschlagen (falls jemand Waffennutzung wählt).
	base.weapon_subtypes = [Enums.PhysicalSubtype.BLUNT] as Array[Enums.PhysicalSubtype]


## Köcher: Nebenhand-Ergänzung zu Fernkampfwaffen (Bonus zählt nur mit Bogen/Armbrust).
static func _quiver(id: StringName, name: String, damage: int,
		stat_bonus: StatBlock, min_tier: int) -> void:
	var base := _base(id, name, Enums.EquipSlot.OFF_HAND, damage, 0, stat_bonus, min_tier)
	base.quiver = true


static func _armor(id: StringName, name: String, slot: Enums.EquipSlot, armor: int,
		armor_class: Enums.ArmorClass, stat_bonus: StatBlock, min_tier: int) -> ItemBase:
	var base := _base(id, name, slot, 0, armor, stat_bonus, min_tier)
	base.armor_class = armor_class
	return base


static func _affix(id: StringName, is_prefix: bool, name_part: String,
		stat_bonus: StatBlock, damage: int, armor: int, tier: int,
		rarity: Enums.Rarity = Enums.Rarity.COMMON) -> Affix:
	var affix := Affix.new()
	affix.id = id
	affix.is_prefix = is_prefix
	affix.name_part = name_part
	affix.stat_bonus = stat_bonus
	affix.bonus_damage = damage
	affix.bonus_armor = armor
	affix.tier = tier
	affix.rarity = rarity
	_affixes.append(affix)
	return affix


## Slots, auf denen Rüstungs-/Schmuck-Affixe (Resistenzen, …) rollen dürfen.
static func _defensive_slots() -> Array[Enums.EquipSlot]:
	return [Enums.EquipSlot.HELMET, Enums.EquipSlot.ARMOR, Enums.EquipSlot.GLOVES,
		Enums.EquipSlot.BOOTS, Enums.EquipSlot.OFF_HAND, Enums.EquipSlot.RING_1,
		Enums.EquipSlot.AMULET] as Array[Enums.EquipSlot]


## Element-Rider-Prefix: Waffennutzung trägt zusätzlichen Elementschaden.
static func _rider_affix(id: StringName, name_part: String, element: Enums.Element,
		damage: int, tier: int, rarity: Enums.Rarity = Enums.Rarity.RARE) -> void:
	var affix := _affix(id, true, name_part, null, 0, 0, tier, rarity)
	affix.element = element
	affix.element_damage = damage
	affix.allowed_slots = [Enums.EquipSlot.WEAPON] as Array[Enums.EquipSlot]


## Resistenz-Suffix: flache Minderung gegen ein Element (NONE = alle).
static func _resist_affix(id: StringName, name_part: String, element: Enums.Element,
		resist: int, tier: int, rarity: Enums.Rarity = Enums.Rarity.MAGIC) -> void:
	var affix := _affix(id, false, name_part, null, 0, 0, tier, rarity)
	affix.element = element
	affix.element_resist = resist
	affix.allowed_slots = _defensive_slots()


## Zauberkraft-Prefix für Stäbe/Foki.
static func _spell_affix(id: StringName, name_part: String, spell_damage: int,
		tier: int, rarity: Enums.Rarity = Enums.Rarity.MAGIC) -> void:
	var affix := _affix(id, true, name_part, null, 0, 0, tier, rarity)
	affix.bonus_spell_damage = spell_damage
	affix.allowed_slots = [Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND] \
		as Array[Enums.EquipSlot]


## Skill-Suffix: senkt die MP-Kosten aller Skills des Trägers flach.
static func _skill_affix(id: StringName, name_part: String, reduction: int,
		tier: int, rarity: Enums.Rarity = Enums.Rarity.RARE) -> void:
	var affix := _affix(id, false, name_part, null, 0, 0, tier, rarity)
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
