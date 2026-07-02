class_name EnemyLibrary
extends RefCounted
## Katalog der Gegner-Archetypen und Elite-Modifikatoren für den Baukasten.
## Gegner-Skills werden aus denselben Bausteinen gebaut wie Spieler-Skills
## (BlockLibrary) — ein System für alles. Vorerst im Code, später .tres.

static var _archetypes: Dictionary = {}
static var _modifiers: Dictionary = {}


static func all_archetypes() -> Array[EnemyArchetype]:
	_ensure_built()
	var result: Array[EnemyArchetype] = []
	for id in _archetypes:
		result.append(_archetypes[id])
	return result


static func archetypes_for_biome(biome: Enums.Biome, boss_only := false) -> Array[EnemyArchetype]:
	var result: Array[EnemyArchetype] = []
	for archetype in all_archetypes():
		if biome not in archetype.biomes:
			continue
		if boss_only and not archetype.is_boss_capable:
			continue
		result.append(archetype)
	return result


static func get_modifier(id: StringName) -> EnemyModifier:
	_ensure_built()
	return _modifiers.get(id)


static func all_modifiers() -> Array[EnemyModifier]:
	_ensure_built()
	var result: Array[EnemyModifier] = []
	for id in _modifiers:
		result.append(_modifiers[id])
	return result


## Würfelt Modifikatoren für eine neue Dungeon-Karte (fix bei Erstellung,
## siehe DungeonCard). Nur Modifikatoren, deren min_tier zur Stufe passt;
## höhere Stufen können mehr Modifikatoren gleichzeitig tragen (bis zu 4).
static func roll_modifiers(tier: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var eligible: Array[EnemyModifier] = []
	for modifier in all_modifiers():
		if modifier.min_tier <= tier:
			eligible.append(modifier)
	var result: Array[StringName] = []
	var max_count := clampi(1 + tier / 5, 1, 4)
	var count := rng.randi_range(1, max_count)
	for i in count:
		if eligible.is_empty():
			break
		var pick := rng.randi_range(0, eligible.size() - 1)
		result.append(eligible[pick].id)
		eligible.remove_at(pick)
	return result


static func _ensure_built() -> void:
	if not _archetypes.is_empty():
		return
	_build_archetypes()
	_build_modifiers()


static func _build_archetypes() -> void:
	var list: Array[EnemyArchetype] = []

	list.append(_archetype(&"wolf", "Waldwolf",
		[Enums.Biome.FOREST],
		_stats(6, 0, 4, 0, 9, 2), _stats(1, 0, 1, 0, 1, 0), 0, 0,
		[_skill("Biss", [&"dmg_schnitt", &"car_melee"])], 1, false,
		Enums.Temperament.AGGRESSIVE))

	list.append(_archetype(&"baer", "Urwaldbär",
		[Enums.Biome.FOREST],
		_stats(9, 0, 9, 0, 4, 1), _stats(1, 0, 2, 0, 0, 0), 2, 0,
		[_skill("Prankenhieb", [&"dmg_wucht", &"car_melee"])], 1, true,
		Enums.Temperament.TERRITORIAL))

	list.append(_archetype(&"schleim", "Giftschleim",
		[Enums.Biome.FOREST, Enums.Biome.CAVE],
		_stats(3, 0, 7, 4, 3, 0), _stats(0, 0, 1, 1, 0, 0), 0, 2,
		[_skill("Säurespucke", [&"dmg_gift", &"car_projectile"])], 1, false,
		Enums.Temperament.SKITTISH))

	list.append(_archetype(&"fledermaus", "Höhlenflatterer",
		[Enums.Biome.CAVE],
		_stats(4, 0, 3, 0, 11, 3), _stats(1, 0, 1, 0, 1, 0), 0, 0,
		[_skill("Sturzflug", [&"dmg_schnitt", &"car_melee"])], 1, false,
		Enums.Temperament.SKITTISH))

	list.append(_archetype(&"golem", "Steingolem",
		[Enums.Biome.CAVE, Enums.Biome.RUINS],
		_stats(8, 0, 10, 0, 2, 0), _stats(1, 0, 2, 0, 0, 0), 5, 2,
		[_skill("Steinwurf", [&"dmg_wucht", &"car_projectile"]),
			_skill("Beben", [&"dmg_wucht", &"car_aoe"])], 1, true,
		Enums.Temperament.TERRITORIAL))

	list.append(_archetype(&"skelett", "Skelettkrieger",
		[Enums.Biome.RUINS, Enums.Biome.CRYPT],
		_stats(7, 0, 6, 0, 4, 1), _stats(1, 0, 1, 0, 1, 0), 3, 0,
		[_skill("Knochenhieb", [&"dmg_schnitt", &"car_melee"])], 1, false,
		Enums.Temperament.AGGRESSIVE))

	list.append(_archetype(&"kultist", "Kultist",
		[Enums.Biome.RUINS, Enums.Biome.CRYPT],
		_stats(2, 8, 4, 6, 5, 2), _stats(0, 1, 1, 1, 0, 0), 0, 3,
		[_skill("Schattenblitz", [&"dmg_arkan", &"car_projectile"]),
			_skill("Feuerodem", [&"dmg_brand", &"car_projectile"])], 2, true,
		Enums.Temperament.TERRITORIAL))

	for archetype in list:
		assert(not _archetypes.has(archetype.id), "Doppelte Archetyp-ID: %s" % archetype.id)
		_archetypes[archetype.id] = archetype


static func _build_modifiers() -> void:
	var list: Array[EnemyModifier] = []

	list.append(_modifier(&"brennend", "Brennend", 1.0, 1.0, 1.0, 0, 1.3, 1,
		_skill("Feuerhauch", [&"dmg_brand", &"car_projectile"])))
	list.append(_modifier(&"gepanzert", "Gepanzert", 1.2, 1.0, 1.0, 4, 1.3, 1, null))
	list.append(_modifier(&"schnell", "Schnell", 1.0, 1.1, 1.5, 0, 1.2, 1, null))
	list.append(_modifier(&"wuetend", "Wütend", 0.9, 1.4, 1.0, 0, 1.4, 2, null))
	list.append(_modifier(&"vampirisch", "Vampirisch", 1.0, 1.0, 1.0, 0, 1.5, 2,
		_skill("Vampirbiss", [&"dmg_schnitt", &"eff_lifesteal", &"car_melee"])))
	list.append(_modifier(&"kolossal", "Kolossal", 1.8, 1.0, 0.8, 0, 1.6, 3, null))

	for modifier in list:
		assert(not _modifiers.has(modifier.id), "Doppelte Modifikator-ID: %s" % modifier.id)
		_modifiers[modifier.id] = modifier


# --- Fabrik-Helfer -------------------------------------------------------------

static func _archetype(id: StringName, name: String, biomes: Array[Enums.Biome],
		base_stats: StatBlock, per_tier: StatBlock, armor: int, resist: int,
		skills: Array[Skill], skill_count: int, boss: bool,
		temperament: Enums.Temperament = Enums.Temperament.AGGRESSIVE) -> EnemyArchetype:
	var archetype := EnemyArchetype.new()
	archetype.id = id
	archetype.display_name = name
	archetype.biomes = biomes
	archetype.base_stats = base_stats
	archetype.stats_per_tier = per_tier
	archetype.armor = armor
	archetype.magic_resist = resist
	archetype.skill_pool = skills
	archetype.skill_count = skill_count
	archetype.is_boss_capable = boss
	archetype.temperament = temperament
	return archetype


static func _modifier(id: StringName, name: String, hp_mult: float, dmg_mult: float,
		speed_mult: float, armor_bonus: int, loot_mult: float, min_tier: int,
		granted_skill: Skill) -> EnemyModifier:
	var modifier := EnemyModifier.new()
	modifier.id = id
	modifier.display_name = name
	modifier.hp_multiplier = hp_mult
	modifier.damage_multiplier = dmg_mult
	modifier.speed_multiplier = speed_mult
	modifier.armor_bonus = armor_bonus
	modifier.loot_multiplier = loot_mult
	modifier.min_tier = min_tier
	modifier.granted_skill = granted_skill
	return modifier


static func _skill(name: String, block_ids: Array) -> Skill:
	var skill := Skill.new()
	skill.display_name = name
	for id in block_ids:
		var block := BlockLibrary.get_block(id)
		assert(block != null, "Unbekannter Baustein: %s" % id)
		skill.blocks.append(block)
	return skill


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
