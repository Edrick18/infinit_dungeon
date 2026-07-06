class_name EnemyFactory
extends RefCounted
## Baut aus Archetyp + Kartenstufe + Elite-Modifikatoren konkrete Gegner —
## das gleiche Baukasten-Prinzip wie bei Items (Basis + Affixe) und
## Skills (Bausteine). Alles deterministisch aus dem übergebenen RNG.

const ELITE_CHANCE := 0.25
const BOSS_HP_MULT := 2.2
const BOSS_DMG_MULT := 1.25

## Signature-Mechanik pro Boss-Archetyp (ausgewertet in Battle):
## Wut (Bär), Steinpanzer (Golem), Regeneration (Troll), Adds (Kultist/
## Nekromant), Haltungswechsel (Schattenbestie).
const BOSS_SIGNATURES := {
	&"baer": &"wut",
	&"golem": &"steinpanzer",
	&"troll": &"regeneration",
	&"kultist": &"adds",
	&"nekromant": &"adds",
	&"schattenbestie": &"haltung",
	&"schleimgott": &"verschlingen",  # ruft Schleime und frisst sie
}
const STONE_ARMOR_BONUS := 8  ## Golem-Steinpanzer, bis Stumpf ihn bricht
## Ab dieser Kartenstufe haben Bosse ihre Mechaniken (Stufe 1-2: sanfter Einstieg).
const BOSS_MECHANICS_MIN_TIER := 3

## Champion-Rarität: seltene, deutlich stärkere Einzelgegner mit
## zwei Modifikatoren und fetter Beute (ab Stufe 5).
const CHAMPION_CHANCE := 0.08
const CHAMPION_MIN_TIER := 5
const CHAMPION_HP_MULT := 1.5
const CHAMPION_LOOT_MULT := 2.0

## Region-Variante: das Biom der Karte prägt jeden Gegner (Namens-Präfix +
## Stat-Akzent) — ein Wald-Wolf spielt sich anders als ein Krypta-Wolf.
const BIOME_VARIANTS := {
	Enums.Biome.FOREST: {"prefix": "Wald-", "agi": 1.1, "hp": 1.0, "int": 1.0, "armor": 0},
	Enums.Biome.CAVE: {"prefix": "Höhlen-", "agi": 1.0, "hp": 1.12, "int": 1.0, "armor": 0},
	Enums.Biome.RUINS: {"prefix": "Ruinen-", "agi": 1.0, "hp": 1.0, "int": 1.0, "armor": 2},
	Enums.Biome.CRYPT: {"prefix": "Krypta-", "agi": 1.0, "hp": 1.0, "int": 1.15, "armor": 0},
}

## Element-Schicht: Gegner können einen Element-Typ tragen (Elementangriff +
## Resistenz + Namenszusatz). Höhere Stufen schalten mehr Elemente frei.
const ELEMENT_LAYER_UNLOCK := {
	Enums.Element.FIRE: 2,
	Enums.Element.POISON: 3,
	Enums.Element.ICE: 5,
	Enums.Element.LIGHTNING: 7,
	Enums.Element.DARK: 9,
}
const ELEMENT_LAYER_BASE_CHANCE := 0.15  ## + 2% pro Stufe, max 50%

## Klassen-Schicht: Humanoide nutzen die Waffenarten des Spiels (Krieger/
## Bogenschütze/Magier/Beschwörer), Schleime kommen als Metall-/Gift-/
## Heilschleim daher. "sep" steuert den Namen: "-" » "Skelett-Krieger",
## "" » "Metallschleim" (Variante + kleingeschriebener Grundname).
const VARIANT_CHANCE := 0.75
const VARIANT_GROUPS := {
	&"humanoid": [
		{"name": "Krieger", "sep": "-", "str": 1.2, "vit": 1.1, "armor": 2,
			"skill_name": "Schwerthieb", "blocks": [&"src_weapon"]},
		{"name": "Bogenschütze", "sep": "-", "agi": 1.25, "dmg": 0.75, "hits": 2,
			"skill_name": "Doppelschuss", "blocks": [&"src_weapon"]},
		{"name": "Magier", "sep": "-", "int": 1.35, "spi": 1.15, "armor": -1,
			"skill_name": "Arkanblitz", "blocks": [&"src_spell"]},
		{"name": "Beschwörer", "sep": "-", "int": 1.2, "spi": 1.25,
			"skill_name": "Totenruf", "blocks": [&"src_spell", &"elem_dark", &"form_summon"]},
	],
	&"bestie": [  # Wolf, Bär, Fledermaus, Riesenspinne
		{"name": "Alpha", "sep": "-", "str": 1.25, "vit": 1.2, "min_tier": 3},
		{"name": "Gift", "sep": "-", "min_tier": 2,
			"skill_name": "Giftbiss", "blocks": [&"src_spell", &"elem_poison"]},
		{"name": "Blut", "sep": "-", "str": 1.15,
			"skill_name": "Aderlass", "blocks": [&"src_weapon", &"eff_lifesteal"]},
		{"name": "Ur", "sep": "-", "vit": 1.4, "armor": 2, "min_tier": 6},
	],
	&"geist": [  # Ruhelose Seele
		{"name": "Zorn", "sep": "-", "int": 1.3,
			"skill_name": "Seelenriss", "blocks": [&"src_spell", &"elem_dark"]},
		{"name": "Frost", "sep": "-", "min_tier": 3,
			"skill_name": "Frosthauch", "blocks": [&"src_spell", &"elem_ice"]},
		{"name": "Polter", "sep": "-", "agi": 1.3, "str": 1.2,
			"skill_name": "Wurfgeschoss", "blocks": [&"src_weapon"]},
	],
	&"konstrukt": [  # Golem
		{"name": "Rost", "sep": "-", "armor": -2, "str": 1.25},
		{"name": "Kristall", "sep": "-", "int": 1.35, "min_tier": 4,
			"skill_name": "Splitterstrahl", "blocks": [&"src_spell", &"elem_lightning"]},
		{"name": "Obsidian", "sep": "-", "armor": 4, "vit": 1.2, "min_tier": 6},
	],
	&"schleim": [
		# Metallschleim (DQ-Jackpot): fast unverwundbar, flüchtet gern —
		# aber wer ihn erwischt, kassiert das 8-fache an Erfahrung.
		# Erst ab Stufe 4 (auf Stufe 1 wäre er nur eine unkaputtbare Bremse).
		{"name": "Metall", "sep": "", "agi": 1.5, "armor": 35,
			"xp": 8.0, "flee": 0.5, "hp_set": 8, "min_tier": 4},
		{"name": "Gift", "sep": "",
			"skill_name": "Giftspritzer", "blocks": [&"src_spell", &"elem_poison"]},
		{"name": "Heil", "sep": "", "spi": 1.3, "min_tier": 3,
			"skill_name": "Heilende Aura", "blocks": [&"src_spell", &"form_aura", &"eff_regen"]},
	],
}

## Globale Tier-Skalierung zusätzlich zum Archetyp-Wachstum: hält Gegner
## gegenüber Party-Statuspunkten + Gear auf allen Stufen gefährlich
## (Balancing-Sim 2026-07-02: ohne das gewinnt die Party alles zu 100%).
## Seit der geschichteten Generierung tragen Region/Element/Rarität selbst
## zur Schwierigkeit bei — die globale Skalierung ist entsprechend flacher.
const TIER_HP_SCALE := 0.02
const TIER_DMG_SCALE := 0.01


## Erzeugt einen einzelnen Gegner aus dem geschichteten Baukasten:
## Grundtyp + Region-Variante (Biom) + Element-Typ + Elite-Modifikatoren.
static func build(archetype: EnemyArchetype, tier: int, rng: RandomNumberGenerator,
		modifiers: Array[EnemyModifier] = [], biome := -1,
		element := Enums.Element.NONE, with_variant := true) -> Combatant:
	var stats := archetype.base_stats.duplicated()
	stats.add_scaled(archetype.stats_per_tier, maxi(0, tier - 1))

	# Lineare Feinabstimmung × zentrale Exponential-Kurve (Scaling) — Items
	# wachsen mit demselben Faktor, die Balance Held↔Welt bleibt pro Stufe.
	var world_growth := Scaling.factor(tier)
	var hp_mult := (1.0 + TIER_HP_SCALE * (tier - 1)) * world_growth
	var dmg_mult := (1.0 + TIER_DMG_SCALE * (tier - 1)) * world_growth
	var speed_mult := 1.0
	var armor_bonus := 0
	for modifier in modifiers:
		hp_mult *= modifier.hp_multiplier
		dmg_mult *= modifier.damage_multiplier
		speed_mult *= modifier.speed_multiplier
		armor_bonus += modifier.armor_bonus

	# Region-Variante: das Biom prägt den Gegner.
	var region: Dictionary = BIOME_VARIANTS.get(biome, {})
	if not region.is_empty():
		hp_mult *= region["hp"]
		speed_mult *= region["agi"]
		armor_bonus += region["armor"]
		stats.intelligence = roundi(stats.intelligence * region["int"])
		stats.spirit = roundi(stats.spirit * region["int"])

	# Klassen-Variante (Humanoide/Schleime): Rolle + Stat-Akzent + Skill.
	var variant := _roll_variant(archetype, tier, rng) if with_variant else {}
	if not variant.is_empty():
		stats.strength = roundi(stats.strength * variant.get("str", 1.0))
		stats.intelligence = roundi(stats.intelligence * variant.get("int", 1.0))
		stats.spirit = roundi(stats.spirit * variant.get("spi", 1.0))
		stats.vitality = roundi(stats.vitality * variant.get("vit", 1.0))
		speed_mult *= variant.get("agi", 1.0)
		armor_bonus += variant.get("armor", 0)

	# Schaden skaliert über die Angriffs-Stats, Tempo über AGI.
	stats.strength = roundi(stats.strength * dmg_mult)
	stats.intelligence = roundi(stats.intelligence * dmg_mult)
	stats.spirit = roundi(stats.spirit * dmg_mult)
	stats.agility = roundi(stats.agility * speed_mult)

	var enemy := Combatant.create(
		_compose_name(archetype, modifiers, region.get("prefix", ""), element, variant),
		stats, false)
	enemy.sprite = SpriteLib.enemy(archetype.id)
	enemy.archetype_id = archetype.id
	enemy.level = tier
	enemy.max_hp = maxi(1, roundi(enemy.max_hp * hp_mult))
	enemy.hp = enemy.max_hp
	# Rüstung/Resistenz wachsen mit — sonst durchschlägt exponentielles
	# Helden-Gear die flachen Werte und Mitigation wird bedeutungslos.
	enemy.armor = roundi((archetype.armor + armor_bonus) * world_growth)
	enemy.magic_resist = roundi(archetype.magic_resist * world_growth)
	enemy.is_undead = archetype.undead
	# Gegner tragen keine Items » innewohnende Waffen-/Zauberwerte aus den Stats
	# (Phase-3-Rework: Schaden kommt aus der "Waffe", auch bei Gegnern).
	# Bewusst moderat, da der Angriffs-Stat im Kampf nochmal obendrauf kommt.
	enemy.innate_weapon_damage = 1 + roundi(stats.strength * 0.5)
	enemy.innate_spell_damage = 1 + roundi((stats.intelligence + stats.spirit) * 0.5)
	for modifier in modifiers:
		enemy.loot_mult *= modifier.loot_multiplier

	enemy.skills = _pick_skills(archetype, rng)
	for modifier in modifiers:
		if modifier.granted_skill != null:
			enemy.skills.append(modifier.granted_skill)

	# Klassen-Variante: Bogenschützen feuern doppelt (schwächer pro Pfeil),
	# und die Klasse bringt ihren eigenen Skill mit (Waffenart/Zauber/Beschwörung).
	if not variant.is_empty():
		enemy.innate_hit_count = variant.get("hits", 1)
		enemy.innate_weapon_damage = maxi(1,
			roundi(enemy.innate_weapon_damage * variant.get("dmg", 1.0)))
		enemy.xp_mult = variant.get("xp", 1.0)
		enemy.flee_chance = variant.get("flee", 0.0)
		if variant.has("hp_set"):  # Metallschleim: hauchdünne HP, fixe Zahl
			enemy.max_hp = int(variant["hp_set"])
			enemy.hp = enemy.max_hp
		if variant.has("blocks"):
			var variant_skill := Skill.new()
			variant_skill.display_name = variant["skill_name"]
			for block_id in variant["blocks"]:
				var block := BlockLibrary.get_block(block_id)
				if block != null:
					variant_skill.blocks.append(block)
			enemy.skills.append(variant_skill)
	enemy.can_call_reinforcements = archetype.calls_reinforcements

	# Element-Schicht: Elementangriff + Resistenz + etwas mehr Beute.
	if element != Enums.Element.NONE:
		var element_block := _element_block_for(element)
		if element_block != null:
			var elemental_skill := Skill.new()
			elemental_skill.display_name = "%s-Angriff" % element_block.display_name
			elemental_skill.blocks.append(BlockLibrary.get_block(&"src_spell"))
			elemental_skill.blocks.append(element_block)
			enemy.skills.append(elemental_skill)
			enemy.magic_resist += 3
			enemy.loot_mult *= 1.15
	return enemy


static func _element_block_for(element: Enums.Element) -> ElementBlock:
	for block in BlockLibrary.all_blocks():
		if block is ElementBlock and block.element == element:
			return block
	return null


## Würfelt die Element-Schicht eines Gegners (oder NONE).
static func _roll_element_layer(tier: int, rng: RandomNumberGenerator) -> Enums.Element:
	var chance := minf(0.5, ELEMENT_LAYER_BASE_CHANCE + tier * 0.02)
	if rng.randf() > chance:
		return Enums.Element.NONE
	var available: Array = []
	for element in ELEMENT_LAYER_UNLOCK:
		if ELEMENT_LAYER_UNLOCK[element] <= tier:
			available.append(element)
	if available.is_empty():
		return Enums.Element.NONE
	return available[rng.randi_range(0, available.size() - 1)]


## Erzeugt eine komplette Gegnergruppe für einen Dungeon-Encounter.
## Elite-Gegner (25% Chance) tragen einen der fix auf der Karte
## festgelegten Modifikatoren; der Boss trägt alle.
## tier_bonus: tiefere Ebenen sind stärker (DQ9-Prinzip — +1 pro Ebene).
static func make_encounter(card: DungeonCard, rng: RandomNumberGenerator,
		is_boss := false, tier_bonus := 0) -> Array[Combatant]:
	var card_modifiers := _resolve_modifiers(card.modifier_ids)
	# Karten-Rarität: Bonus-Stufen für ALLE Gegner dieser Karte.
	var tier := card.tier + tier_bonus + card.rarity_level_bonus()

	if is_boss:
		# Legendäre Karte: der Legacy-Boss levelt mit jedem Abschluss (+2).
		tier += card.legacy_boss_bonus()
		var pool := EnemyLibrary.archetypes_for_biome(card.biome, true, tier)
		if pool.is_empty():
			# Fallback: auf sehr niedrigen Stufen den am FRÜHESTEN
			# freigeschalteten Boss nehmen — niemals den Schleimgott auf Stufe 1.
			var all_bosses := EnemyLibrary.archetypes_for_biome(card.biome, true)
			var min_unlock := 9999
			for archetype in all_bosses:
				min_unlock = mini(min_unlock, archetype.unlock_tier)
			for archetype in all_bosses:
				if archetype.unlock_tier == min_unlock:
					pool.append(archetype)
		assert(not pool.is_empty(), "Kein Boss-Archetyp für Biom %d" % card.biome)
		var archetype := pool[rng.randi_range(0, pool.size() - 1)]
		var boss_element := _roll_element_layer(tier, rng)
		var boss := build(archetype, tier, rng, card_modifiers, card.biome, boss_element)
		boss.display_name = "Boss: " + boss.display_name
		boss.max_hp = roundi(boss.max_hp * BOSS_HP_MULT)
		boss.hp = boss.max_hp
		boss.loot_mult *= 1.5
		# Legacy-Boss: pro bisherigem Abschluss +20% Beute obendrauf.
		if card.legendary:
			boss.loot_mult *= 1.0 + 0.2 * card.times_completed
			boss.xp_mult *= 1.0 + 0.15 * card.times_completed
		boss.stats.strength = roundi(boss.stats.strength * BOSS_DMG_MULT)
		boss.stats.intelligence = roundi(boss.stats.intelligence * BOSS_DMG_MULT)
		var escort_pool := EnemyLibrary.archetypes_for_biome(card.biome, false, tier)
		# Boss-Mechaniken (ab Stufe 3): Phasen + Aufladung + Signature + Adds.
		if tier >= BOSS_MECHANICS_MIN_TIER:
			boss.is_boss = true
			boss.boss_signature = BOSS_SIGNATURES.get(archetype.id, &"")
			boss.charge_cooldown = 4  # erster Spezialangriff nach ein paar Zügen
			boss.boss_add_id = escort_pool[rng.randi_range(0, escort_pool.size() - 1)].id
			if boss.boss_signature == &"verschlingen":
				boss.boss_add_id = &"schleim"  # der Schleimgott ruft seine Kinder
			if boss.boss_signature == &"steinpanzer":
				boss.armor += STONE_ARMOR_BONUS
			elif boss.boss_signature == &"haltung":
				boss.armor += 8  # startet in der physischen Haltung
				boss.magic_resist = maxi(0, boss.magic_resist - 3)
		var bosses: Array[Combatant] = [boss]
		# Ab Stufe 6 bringt der Boss Begleiter mit (max. 2 ab Stufe 12).
		for i in mini(2, tier / 6):
			bosses.append(build(escort_pool[rng.randi_range(0, escort_pool.size() - 1)],
				tier, rng, [], card.biome))
		_apply_dangerous_affix(bosses, card)
		_apply_card_rarity(bosses, card)
		return bosses

	var pool := EnemyLibrary.archetypes_for_biome(card.biome, false, tier)
	assert(not pool.is_empty(), "Keine Archetypen für Biom %d" % card.biome)
	var group: Array[Combatant] = []
	# Höhere Stufen bringen größere Gruppen (Action-Economy vs. 4 Helden);
	# die ersten Stufen bleiben bewusst klein (sanfter Einstieg, Balance-Sim).
	var base_max := 2 if tier <= 2 else 3
	var count := clampi(rng.randi_range(1, base_max) + tier / 8, 1, 5)
	# Karten-Affix "Elitär": doppelte Elite-Chance.
	var elite_chance := ELITE_CHANCE
	if &"elitaer" in card.card_affix_ids:
		elite_chance *= 2.0
	for i in count:
		var archetype := pool[rng.randi_range(0, pool.size() - 1)]
		var element := _roll_element_layer(tier, rng)
		# Rarität: Normal » Elite (1 Modifikator) » Champion (2 + Stat-Schub).
		var modifiers: Array[EnemyModifier] = []
		var is_champion := tier >= CHAMPION_MIN_TIER \
			and card_modifiers.size() >= 2 and rng.randf() < CHAMPION_CHANCE
		if is_champion:
			modifiers = card_modifiers.slice(0, 2)
		elif not card_modifiers.is_empty() and rng.randf() < elite_chance:
			modifiers.append(card_modifiers[rng.randi_range(0, card_modifiers.size() - 1)])
		var enemy := build(archetype, tier, rng, modifiers, card.biome, element)
		if is_champion:
			enemy.display_name = "Champion: " + enemy.display_name
			enemy.max_hp = roundi(enemy.max_hp * CHAMPION_HP_MULT)
			enemy.hp = enemy.max_hp
			enemy.loot_mult *= CHAMPION_LOOT_MULT
		group.append(enemy)
	_apply_dangerous_affix(group, card)
	_apply_card_rarity(group, card)
	return group


## Karten-Affix "Gefährlich": stärkere Gegner, dafür mehr Beute.
static func _apply_dangerous_affix(group: Array[Combatant], card: DungeonCard) -> void:
	if &"gefaehrlich" not in card.card_affix_ids:
		return
	for enemy in group:
		enemy.stats.strength = roundi(enemy.stats.strength * 1.15)
		enemy.stats.intelligence = roundi(enemy.stats.intelligence * 1.15)
		enemy.stats.spirit = roundi(enemy.stats.spirit * 1.15)
		enemy.innate_weapon_damage = roundi(enemy.innate_weapon_damage * 1.15)
		enemy.innate_spell_damage = roundi(enemy.innate_spell_damage * 1.15)
		enemy.loot_mult *= 1.3


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


## Würfelt die Klassen-Variante eines Archetyps (leer = keine/Basisform).
## Stufe 1 bleibt varianten-frei (sanfter Einstieg, wie die Element-Schicht);
## einzelne Varianten haben eigene Mindest-Stufen (Metallschleim erst ab 4).
static func _roll_variant(archetype: EnemyArchetype, tier: int,
		rng: RandomNumberGenerator) -> Dictionary:
	if tier < 2 or archetype.variant_group == &"" \
			or not VARIANT_GROUPS.has(archetype.variant_group) \
			or rng.randf() > VARIANT_CHANCE:
		return {}
	var pool: Array = []
	for entry in VARIANT_GROUPS[archetype.variant_group]:
		if entry.get("min_tier", 1) <= tier:
			pool.append(entry)
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]


## Name aus allen Schichten:
## "Krypta-Skelett-Krieger (Feuer) [Gepanzert, Schnell]" / "Metallschleim".
static func _compose_name(archetype: EnemyArchetype, modifiers: Array[EnemyModifier],
		region_prefix := "", element := Enums.Element.NONE,
		variant: Dictionary = {}) -> String:
	var base_name := archetype.display_name
	if not variant.is_empty():
		if variant.get("sep", "-") == "-":
			base_name = "%s-%s" % [base_name, variant["name"]]
		else:
			base_name = variant["name"] + base_name.to_lower()
	var name := region_prefix + base_name
	if element != Enums.Element.NONE:
		var element_block := _element_block_for(element)
		if element_block != null:
			name += " (%s)" % element_block.display_name
	if modifiers.is_empty():
		return name
	var names: Array[String] = []
	for modifier in modifiers:
		names.append(modifier.display_name)
	return "%s [%s]" % [name, ", ".join(names)]


## Karten-Rarität: seltene Karten zahlen besser (Beute + XP auf allen Gegnern).
static func _apply_card_rarity(foes: Array[Combatant], card: DungeonCard) -> void:
	for foe in foes:
		foe.loot_mult *= card.rarity_loot_mult()
		foe.xp_mult *= card.rarity_xp_mult()
