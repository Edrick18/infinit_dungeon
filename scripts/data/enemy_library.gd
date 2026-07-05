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


static func get_archetype(id: StringName) -> EnemyArchetype:
	_ensure_built()
	return _archetypes.get(id)


## tier filtert nach unlock_tier: der Grundtyp-Pool wächst mit den Stufen.
static func archetypes_for_biome(biome: Enums.Biome, boss_only := false,
		tier := 999) -> Array[EnemyArchetype]:
	var result: Array[EnemyArchetype] = []
	for archetype in all_archetypes():
		if biome not in archetype.biomes:
			continue
		if boss_only and not archetype.is_boss_capable:
			continue
		if not boss_only and archetype.boss_only:
			continue  # z.B. Schleimgott: nur als Boss, nie als Trash-Mob
		if archetype.unlock_tier > tier:
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

	# Basisnamen ohne Region — die Region-Variante ("Wald-", "Krypta-", …)
	# legt die EnemyFactory als Schicht obendrauf.
	var wolf := _archetype(&"wolf", "Wolf",
		[Enums.Biome.FOREST],
		_stats(6, 0, 4, 0, 9, 2), _stats(1, 0, 1, 0, 1, 0), 0, 0,
		[_skill("Biss", [&"src_weapon"])], 1, false,
		Enums.Temperament.AGGRESSIVE, 1)
	wolf.calls_reinforcements = true  # heult das Rudel herbei
	list.append(wolf)

	# Mimic: taucht in KEINEM Biom-Pool auf (leere Biom-Liste) — er lauert
	# ausschließlich in Risiko-Truhen (Dungeon-Events).
	list.append(_archetype(&"mimic", "Mimic",
		[] as Array[Enums.Biome],
		_stats(9, 0, 10, 0, 6, 4), _stats(2, 0, 2, 0, 1, 0), 3, 2,
		[_skill("Zuschnappen", [&"src_weapon"])], 1, false,
		Enums.Temperament.AGGRESSIVE, 1))

	list.append(_archetype(&"baer", "Bär",
		[Enums.Biome.FOREST],
		_stats(9, 0, 9, 0, 4, 1), _stats(1, 0, 2, 0, 0, 0), 2, 0,
		[_skill("Prankenhieb", [&"src_weapon"])], 1, true,
		Enums.Temperament.TERRITORIAL, 2))

	# --- Die Schleim-Familie (DQ-Prinzip): Schleim → Schleimstapel →
	# König-Schleim → SCHLEIMGOTT. Alle Stufen spawnen natürlich (steigende
	# Freischalt-Stufen) UND entstehen im Kampf durchs Stapeln (Battle).
	var slime := _archetype(&"schleim", "Schleim",
		[Enums.Biome.FOREST, Enums.Biome.CAVE],
		_stats(3, 0, 7, 4, 3, 0), _stats(0, 0, 1, 1, 0, 0), 0, 2,
		[_skill("Säurespucke", [&"src_spell", &"elem_poison"])], 1, false,
		Enums.Temperament.SKITTISH, 1)
	slime.variant_group = &"schleim"  # Metall-/Gift-/Heilschleim
	list.append(slime)

	var slime_stack := _archetype(&"schleimstapel", "Schleimstapel",
		[Enums.Biome.FOREST, Enums.Biome.CAVE],
		_stats(6, 0, 12, 6, 4, 1), _stats(1, 0, 1, 1, 0, 0), 1, 3,
		[_skill("Wabernder Schlag", [&"src_weapon"]),
			_skill("Säureschwall", [&"src_spell", &"elem_poison"])], 1, false,
		Enums.Temperament.TERRITORIAL, 4)
	slime_stack.variant_group = &"schleim"
	list.append(slime_stack)

	list.append(_archetype(&"koenigschleim", "König-Schleim",
		[Enums.Biome.FOREST, Enums.Biome.CAVE],
		_stats(10, 0, 20, 10, 5, 2), _stats(2, 0, 2, 1, 0, 0), 2, 4,
		[_skill("Königsplatscher", [&"src_weapon"]),
			_skill("Schleimwoge", [&"src_spell", &"form_aoe"])], 2, false,
		Enums.Temperament.AGGRESSIVE, 8))

	# Schleimgott: NUR als Boss — ruft Schleime und verschlingt sie (Battle).
	var slime_god := _archetype(&"schleimgott", "Schleimgott",
		[Enums.Biome.FOREST, Enums.Biome.CAVE],
		_stats(14, 8, 26, 14, 6, 3), _stats(2, 1, 3, 2, 0, 0), 3, 6,
		[_skill("Götterplatscher", [&"src_weapon"]),
			_skill("Urschleim-Flut", [&"src_spell", &"elem_poison", &"form_aoe"])], 2, true,
		Enums.Temperament.AGGRESSIVE, 10)
	slime_god.boss_only = true
	list.append(slime_god)

	list.append(_archetype(&"fledermaus", "Fledermaus",
		[Enums.Biome.FOREST, Enums.Biome.CAVE],
		_stats(4, 0, 3, 0, 11, 3), _stats(1, 0, 1, 0, 1, 0), 0, 0,
		[_skill("Sturzflug", [&"src_weapon"])], 1, false,
		Enums.Temperament.SKITTISH, 1))

	list.append(_archetype(&"spinne", "Riesenspinne",
		[Enums.Biome.FOREST, Enums.Biome.CAVE],
		_stats(5, 0, 5, 3, 8, 1), _stats(1, 0, 1, 1, 1, 0), 1, 1,
		[_skill("Giftbiss", [&"src_spell", &"elem_poison"])], 1, false,
		Enums.Temperament.SKITTISH, 3))

	list.append(_archetype(&"golem", "Golem",
		[Enums.Biome.CAVE, Enums.Biome.RUINS],
		_stats(8, 0, 10, 0, 2, 0), _stats(1, 0, 2, 0, 0, 0), 5, 2,
		[_skill("Steinwurf", [&"src_weapon"]),
			_skill("Beben", [&"src_spell", &"form_aoe"])], 1, true,
		Enums.Temperament.TERRITORIAL, 3))

	list.append(_archetype(&"troll", "Troll",
		[Enums.Biome.CAVE, Enums.Biome.RUINS],
		_stats(11, 0, 12, 0, 3, 0), _stats(2, 0, 2, 0, 0, 0), 3, 1,
		[_skill("Keulenschlag", [&"src_weapon"])], 1, true,
		Enums.Temperament.TERRITORIAL, 5))

	var skeleton := _archetype(&"skelett", "Skelett",
		[Enums.Biome.RUINS, Enums.Biome.CRYPT],
		_stats(7, 0, 6, 0, 4, 1), _stats(1, 0, 1, 0, 1, 0), 3, 0,
		[_skill("Knochenhieb", [&"src_weapon"])], 1, false,
		Enums.Temperament.AGGRESSIVE, 1)
	skeleton.undead = true
	skeleton.variant_group = &"humanoid"  # Skelett-Krieger/-Bogenschütze/…
	list.append(skeleton)

	var cultist := _archetype(&"kultist", "Kultist",
		[Enums.Biome.RUINS, Enums.Biome.CRYPT],
		_stats(2, 8, 4, 6, 5, 2), _stats(0, 1, 1, 1, 0, 0), 0, 3,
		[_skill("Schattenblitz", [&"src_spell"]),
			_skill("Feuerodem", [&"src_spell", &"elem_fire"])], 2, true,
		Enums.Temperament.TERRITORIAL, 4)
	cultist.undead = true
	cultist.variant_group = &"humanoid"
	cultist.calls_reinforcements = true  # ruft Glaubensbrüder
	list.append(cultist)

	var ghost := _archetype(&"geist", "Ruhelose Seele",
		[Enums.Biome.RUINS, Enums.Biome.CRYPT],
		_stats(2, 9, 5, 7, 8, 2), _stats(0, 1, 1, 1, 1, 0), 0, 5,
		[_skill("Seelengriff", [&"src_spell"])], 1, false,
		Enums.Temperament.AGGRESSIVE, 7)
	ghost.undead = true
	list.append(ghost)

	# Nekromant: nutzt das Beschwörungs-System — ruft Dunkel-Elementare!
	var necromancer := _archetype(&"nekromant", "Nekromant",
		[Enums.Biome.CRYPT],
		_stats(3, 11, 7, 9, 4, 2), _stats(0, 1, 1, 1, 0, 0), 1, 4,
		[_skill("Schattenlanze", [&"src_spell", &"elem_dark"]),
			_skill("Totenruf", [&"src_spell", &"elem_dark", &"form_summon"])], 2, true,
		Enums.Temperament.TERRITORIAL, 9)
	necromancer.undead = true
	list.append(necromancer)

	list.append(_archetype(&"schattenbestie", "Schattenbestie",
		[Enums.Biome.RUINS, Enums.Biome.CRYPT],
		_stats(12, 6, 10, 4, 9, 3), _stats(2, 1, 2, 1, 1, 0), 2, 3,
		[_skill("Schattenklauen", [&"src_weapon"]),
			_skill("Dunkler Odem", [&"src_spell", &"elem_dark"])], 2, true,
		Enums.Temperament.AGGRESSIVE, 12))

	for archetype in list:
		assert(not _archetypes.has(archetype.id), "Doppelte Archetyp-ID: %s" % archetype.id)
		_archetypes[archetype.id] = archetype


static func _build_modifiers() -> void:
	var list: Array[EnemyModifier] = []

	list.append(_modifier(&"brennend", "Brennend", 1.0, 1.0, 1.0, 0, 1.3, 1,
		_skill("Feuerhauch", [&"src_spell", &"elem_fire"])))
	list.append(_modifier(&"gepanzert", "Gepanzert", 1.2, 1.0, 1.0, 4, 1.3, 1, null))
	list.append(_modifier(&"schnell", "Schnell", 1.0, 1.1, 1.5, 0, 1.2, 1, null))
	list.append(_modifier(&"wuetend", "Wütend", 0.9, 1.4, 1.0, 0, 1.4, 2, null))
	list.append(_modifier(&"vampirisch", "Vampirisch", 1.0, 1.0, 1.0, 0, 1.5, 2,
		_skill("Vampirbiss", [&"src_weapon", &"eff_lifesteal"])))
	list.append(_modifier(&"kolossal", "Kolossal", 1.8, 1.0, 0.8, 0, 1.6, 3, null))

	for modifier in list:
		assert(not _modifiers.has(modifier.id), "Doppelte Modifikator-ID: %s" % modifier.id)
		_modifiers[modifier.id] = modifier


# --- Fabrik-Helfer -------------------------------------------------------------

static func _archetype(id: StringName, name: String, biomes: Array[Enums.Biome],
		base_stats: StatBlock, per_tier: StatBlock, armor: int, resist: int,
		skills: Array[Skill], skill_count: int, boss: bool,
		temperament: Enums.Temperament = Enums.Temperament.AGGRESSIVE,
		unlock_tier := 1) -> EnemyArchetype:
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
	archetype.unlock_tier = unlock_tier
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
