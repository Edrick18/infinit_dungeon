class_name EnemyFactory
extends RefCounted
## Baut aus Archetyp + Kartenstufe + Elite-Modifikatoren konkrete Gegner —
## das gleiche Baukasten-Prinzip wie bei Items (Basis + Affixe) und
## Skills (Bausteine). Alles deterministisch aus dem übergebenen RNG.

const ELITE_CHANCE := 0.25
const BOSS_HP_MULT := 2.2
const BOSS_DMG_MULT := 1.25


## Erzeugt einen einzelnen Gegner aus dem Baukasten.
static func build(archetype: EnemyArchetype, tier: int, rng: RandomNumberGenerator,
		modifiers: Array[EnemyModifier] = []) -> Combatant:
	var stats := archetype.base_stats.duplicated()
	stats.add_scaled(archetype.stats_per_tier, maxi(0, tier - 1))

	var hp_mult := 1.0
	var dmg_mult := 1.0
	var speed_mult := 1.0
	var armor_bonus := 0
	for modifier in modifiers:
		hp_mult *= modifier.hp_multiplier
		dmg_mult *= modifier.damage_multiplier
		speed_mult *= modifier.speed_multiplier
		armor_bonus += modifier.armor_bonus

	# Schaden skaliert über die Angriffs-Stats, Tempo über AGI.
	stats.strength = roundi(stats.strength * dmg_mult)
	stats.intelligence = roundi(stats.intelligence * dmg_mult)
	stats.spirit = roundi(stats.spirit * dmg_mult)
	stats.agility = roundi(stats.agility * speed_mult)

	var enemy := Combatant.create(_compose_name(archetype, modifiers), stats, false)
	enemy.level = tier
	enemy.max_hp = maxi(1, roundi(enemy.max_hp * hp_mult))
	enemy.hp = enemy.max_hp
	enemy.armor = archetype.armor + armor_bonus
	enemy.magic_resist = archetype.magic_resist
	for modifier in modifiers:
		enemy.loot_mult *= modifier.loot_multiplier

	enemy.skills = _pick_skills(archetype, rng)
	for modifier in modifiers:
		if modifier.granted_skill != null:
			enemy.skills.append(modifier.granted_skill)
	return enemy


## Erzeugt eine komplette Gegnergruppe für einen Dungeon-Encounter.
## Elite-Gegner (25% Chance) tragen einen der fix auf der Karte
## festgelegten Modifikatoren; der Boss trägt alle.
static func make_encounter(card: DungeonCard, rng: RandomNumberGenerator,
		is_boss := false) -> Array[Combatant]:
	var card_modifiers := _resolve_modifiers(card.modifier_ids)

	if is_boss:
		var pool := EnemyLibrary.archetypes_for_biome(card.biome, true)
		assert(not pool.is_empty(), "Kein Boss-Archetyp für Biom %d" % card.biome)
		var archetype := pool[rng.randi_range(0, pool.size() - 1)]
		var boss := build(archetype, card.tier, rng, card_modifiers)
		boss.display_name = "Boss: " + boss.display_name
		boss.max_hp = roundi(boss.max_hp * BOSS_HP_MULT)
		boss.hp = boss.max_hp
		boss.loot_mult *= 1.5
		boss.stats.strength = roundi(boss.stats.strength * BOSS_DMG_MULT)
		boss.stats.intelligence = roundi(boss.stats.intelligence * BOSS_DMG_MULT)
		return [boss]

	var pool := EnemyLibrary.archetypes_for_biome(card.biome, false)
	assert(not pool.is_empty(), "Keine Archetypen für Biom %d" % card.biome)
	var group: Array[Combatant] = []
	var count := rng.randi_range(1, 3)
	for i in count:
		var archetype := pool[rng.randi_range(0, pool.size() - 1)]
		var modifiers: Array[EnemyModifier] = []
		if not card_modifiers.is_empty() and rng.randf() < ELITE_CHANCE:
			modifiers.append(card_modifiers[rng.randi_range(0, card_modifiers.size() - 1)])
		group.append(build(archetype, card.tier, rng, modifiers))
	return group


static func _pick_skills(archetype: EnemyArchetype, rng: RandomNumberGenerator) -> Array[Skill]:
	var pool := archetype.skill_pool.duplicate()
	var picked: Array[Skill] = []
	while picked.size() < archetype.skill_count and not pool.is_empty():
		var index := rng.randi_range(0, pool.size() - 1)
		picked.append(pool[index])
		pool.remove_at(index)
	return picked


static func _resolve_modifiers(ids: Array[StringName]) -> Array[EnemyModifier]:
	var result: Array[EnemyModifier] = []
	for id in ids:
		var modifier := EnemyLibrary.get_modifier(id)
		if modifier != null:
			result.append(modifier)
	return result


static func _compose_name(archetype: EnemyArchetype, modifiers: Array[EnemyModifier]) -> String:
	if modifiers.is_empty():
		return archetype.display_name
	var names: Array[String] = []
	for modifier in modifiers:
		names.append(modifier.display_name)
	return "%s [%s]" % [archetype.display_name, ", ".join(names)]
