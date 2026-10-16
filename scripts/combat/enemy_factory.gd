class_name EnemyFactory
extends RefCounted
## Baut aus Archetyp + Kartenstufe + Elite-Modifikatoren konkrete Gegner —
## das gleiche Baukasten-Prinzip wie bei Items (Basis + Affixe) und
## Skills (Bausteine). Alles deterministisch aus dem übergebenen RNG.

const ELITE_CHANCE := 0.25
## Boss-HP (Lutz: Bosskämpfe sollen ~10 Runden dauern, damit Buffs, Debuffs
## und Taktik zählen — nicht in 5 Runden umfallen; schwerer = gerne länger).
const BOSS_HP_MULT := 6.0
## Ab Stufe 10 bis 60 wächst die Boss-HP zusätzlich (bis ×1,6): dort kommen
## Baum-Boni, Sockel und Meisterschaften rein — ohne Rampe fielen Bosse auf
## Stufe 30-50 nach 5-7 Runden (Balance-Sim mit Spieler-Builds).
const BOSS_HP_RAMPE := 0.012
const BOSS_HP_RAMPE_START := 10
const BOSS_HP_RAMPE_ENDE := 60
## Boss-Schaden (Lutz 2026-10-16): in Bosskämpfen sollen ALLE in Gefahr
## geraten können — Magier und Heiler auch auf gleichem Level mal mit einem
## Schlag (vernichtende Treffer, Battle.BOSS_KRIT_*), der Tank schützt per
## Schutzwall (mit Abklingzeit). Wächst mit der Stufe: sanfter Einstieg (der
## Heiler kann erst ab ~Level 26 wiederbeleben), ab Stufe 60 voll (×2,5).
const BOSS_DMG_MULT := 1.9
const BOSS_DMG_RAMPE := 0.012
const BOSS_DMG_RAMPE_START := 10
const BOSS_DMG_RAMPE_ENDE := 60


static func boss_schaden_faktor(tier: int) -> float:
	var stufen := clampi(tier - BOSS_DMG_RAMPE_START, 0, BOSS_DMG_RAMPE_ENDE - BOSS_DMG_RAMPE_START)
	return BOSS_DMG_MULT + BOSS_DMG_RAMPE * stufen

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
	Enums.Biome.FOREST: {"prefix": "Wald-", "prefix_en": "Forest ", "agi": 1.1, "hp": 1.0, "int": 1.0, "armor": 0},
	Enums.Biome.CAVE: {"prefix": "Höhlen-", "prefix_en": "Cave ", "agi": 1.0, "hp": 1.12, "int": 1.0, "armor": 0},
	Enums.Biome.RUINS: {"prefix": "Ruinen-", "prefix_en": "Ruin ", "agi": 1.0, "hp": 1.0, "int": 1.0, "armor": 2},
	Enums.Biome.CRYPT: {"prefix": "Krypta-", "prefix_en": "Crypt ", "agi": 1.0, "hp": 1.0, "int": 1.15, "armor": 0},
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
## So oft bekommt ein normaler Gegner einen Kombo-Skill (EnemyLibrary.KOMBOS).
const KOMBO_CHANCE := 0.7
const VARIANT_GROUPS := {
	&"humanoid": [
		{"name": "Krieger", "name_en": "Warrior", "sep": "-", "str": 1.2, "vit": 1.1, "armor": 2,
			"klasse": Enums.ArmorClass.CHAIN,
			"skill_name": "Wuchthieb", "skill_name_en": "Heavy Slash", "blocks": [&"src_weapon", &"mod_wucht"]},
		{"name": "Bogenschütze", "name_en": "Archer", "sep": "-", "agi": 1.25, "dmg": 0.75, "hits": 2,
			"skill_name": "Pfeilhagel", "skill_name_en": "Arrow Hail", "blocks": [&"src_weapon", &"mod_treffer", &"mod_ziel_zufall"]},
		{"name": "Magier", "name_en": "Mage", "sep": "-", "int": 1.35, "spi": 1.15, "armor": -1,
			"skill_name": "Arkanblitz", "skill_name_en": "Arcane Bolt", "blocks": [&"src_spell"]},
		{"name": "Beschwörer", "name_en": "Summoner", "sep": "-", "int": 1.2, "spi": 1.25,
			"skill_name": "Totenruf", "skill_name_en": "Call of the Dead", "blocks": [&"src_spell", &"elem_dark", &"form_summon"]},
	],
	&"bestie": [  # Wolf, Bär, Fledermaus, Riesenspinne
		{"name": "Alpha", "sep": "-", "str": 1.25, "vit": 1.2, "min_tier": 3},
		{"name": "Gift", "name_en": "Venom", "sep": "-", "min_tier": 2,
			"skill_name": "Giftbiss", "skill_name_en": "Venom Bite", "blocks": [&"src_spell", &"elem_poison"]},
		{"name": "Blut", "name_en": "Blood", "sep": "-", "str": 1.15,
			"skill_name": "Aderlass", "skill_name_en": "Bloodletting", "blocks": [&"src_weapon", &"eff_lifesteal"]},
		{"name": "Ur", "name_en": "Primal", "sep": "-", "vit": 1.4, "armor": 2, "min_tier": 6},
	],
	&"geist": [  # Ruhelose Seele
		{"name": "Zorn", "name_en": "Wrath", "sep": "-", "int": 1.3,
			"skill_name": "Seelenriss", "skill_name_en": "Soul Rend", "blocks": [&"src_spell", &"elem_dark"]},
		{"name": "Frost", "sep": "-", "min_tier": 3,
			"skill_name": "Frosthauch", "skill_name_en": "Frost Breath", "blocks": [&"src_spell", &"elem_ice"]},
		{"name": "Polter", "sep": "-", "agi": 1.3, "str": 1.2,
			"skill_name": "Wurfgeschoss", "skill_name_en": "Projectile", "blocks": [&"src_weapon"]},
	],
	&"konstrukt": [  # Golem
		{"name": "Rost", "name_en": "Rust", "sep": "-", "armor": -2, "str": 1.25},
		{"name": "Kristall", "name_en": "Crystal", "sep": "-", "int": 1.35, "min_tier": 4,
			"skill_name": "Splitterstrahl", "skill_name_en": "Shard Beam", "blocks": [&"src_spell", &"elem_lightning"]},
		{"name": "Obsidian", "sep": "-", "armor": 4, "vit": 1.2, "min_tier": 6},
	],
	&"schleim": [
		# Metallschleim (DQ-Jackpot): fast unverwundbar, flüchtet gern —
		# aber wer ihn erwischt, kassiert das 8-fache an Erfahrung.
		# Erst ab Stufe 4 (auf Stufe 1 wäre er nur eine unkaputtbare Bremse).
		{"name": "Metall", "name_en": "Metal", "sep": "", "agi": 1.5, "armor": 120,
			"klasse": Enums.ArmorClass.PLATE,
			"xp": 8.0, "flee": 0.5, "hp_set": 8, "min_tier": 4},
		{"name": "Gift", "name_en": "Venom", "sep": "",
			"skill_name": "Giftspritzer", "skill_name_en": "Poison Splash", "blocks": [&"src_spell", &"elem_poison"]},
		{"name": "Heil", "name_en": "Healing", "sep": "", "spi": 1.3, "min_tier": 3,
			"skill_name": "Heilende Aura", "skill_name_en": "Healing Aura", "blocks": [&"src_spell", &"form_aura", &"eff_regen"]},
	],
}

## Gegen-Elemente für Element-Schichten: ein Feuer-Gegner ist eisschwach usw.
const GEGEN_ELEMENT := {
	Enums.Element.FIRE: Enums.Element.ICE, Enums.Element.ICE: Enums.Element.FIRE,
	Enums.Element.LIGHTNING: Enums.Element.POISON, Enums.Element.POISON: Enums.Element.LIGHTNING,
	Enums.Element.HOLY: Enums.Element.DARK, Enums.Element.DARK: Enums.Element.HOLY,
}

## Globale Tier-Skalierung zusätzlich zum Archetyp-Wachstum: hält Gegner
## gegenüber Party-Statuspunkten + Gear auf allen Stufen gefährlich
## (Balancing-Sim 2026-07-02: ohne das gewinnt die Party alles zu 100%).
## Seit der geschichteten Generierung tragen Region/Element/Rarität selbst
## zur Schwierigkeit bei — die globale Skalierung ist entsprechend flacher.
## Seit der zentralen Exponential-Kurve (Scaling) auf 0: Die Kurve übernimmt
## genau diesen Job. Obendrauf gestapelt drifteten Gegner quadratisch davon —
## Balance-Sim: T200-Treffer fraß 48% der Held-HP statt konstant ~20%.
const TIER_HP_SCALE := 0.0
const TIER_DMG_SCALE := 0.0

## Endgame-Schere (DQ-Grotten-Gefühl, User-Design): Gegner legen ZUSÄTZLICH
## zum Welt-Wachstum linear zu — Stufe 50 ≈ ×1,9, Stufe 100 ≈ ×2,3,
## Stufe 150 ≈ ×2,9, Stufe 200 ≈ ×3,6. Die Lücke schließt nur, wer ALLES
## auskitzelt: Punkte-Kurve ab Level 100, Waffen-Training, Affix-Gear,
## Wiedergeburten und Taktik.
## Die erste Rampe (Stufe 25-50) spiegelt die Baum-Boni der Helden, die
## genau dort reinkommen (+50 % Waffenschaden, +20 % Krit bis Level ~50) —
## vorher startete die Schere erst auf 50 und Stufe 40-65 war ein
## Boss-Spaziergang (Balance-Sim: 85-98 % Sieg gegenüber 70 % auf Stufe 30).
## Steil (3,5 %/Stufe), seit die Sim-Party wie ein Spieler baut und spielt.
## [ab Stufe, +x je Stufe] — die Abschnitte addieren sich.
const BRUTAL_RAMPEN := [[25, 0.035], [50, 0.008], [100, 0.005]]
## Anteil der Schere, der auf den SCHADEN wirkt (HP: voll).
const BRUTAL_SCHADEN_ANTEIL := 0.5
## Die erste Rampe endet auf 50 (die Baum-Boni sind dann voll).
const BRUTAL_RAMPE1_ENDE := 50


## HP-Faktor eines Bosses auf einer Kartenstufe.
static func boss_hp_faktor(tier: int) -> float:
	var rampe := clampi(tier - BOSS_HP_RAMPE_START, 0, BOSS_HP_RAMPE_ENDE - BOSS_HP_RAMPE_START)
	return BOSS_HP_MULT * (1.0 + BOSS_HP_RAMPE * rampe)


## Endgame-Schere als Faktor für eine Kartenstufe (1.0 bis Stufe 25).
static func brutal_faktor(tier: int) -> float:
	var faktor := 1.0
	for i in BRUTAL_RAMPEN.size():
		var ab: int = BRUTAL_RAMPEN[i][0]
		var stufen := maxi(0, tier - ab)
		if i == 0:
			stufen = mini(stufen, BRUTAL_RAMPE1_ENDE - ab)
		faktor += float(BRUTAL_RAMPEN[i][1]) * stufen
	return faktor


## Erzeugt einen einzelnen Gegner aus dem geschichteten Baukasten:
## Grundtyp + Region-Variante (Biom) + Element-Typ + Elite-Modifikatoren.
static func build(archetype: EnemyArchetype, tier: int, rng: RandomNumberGenerator,
		modifiers: Array[EnemyModifier] = [], biome := -1,
		element := Enums.Element.NONE, with_variant := true) -> Combatant:
	var stats := archetype.base_stats.duplicated()
	stats.add_scaled(archetype.stats_per_tier, maxi(0, tier - 1))

	# Lineare Feinabstimmung × zentrale Exponential-Kurve (Scaling) — Items
	# wachsen mit demselben Faktor, die Balance Held↔Welt bleibt pro Stufe.
	# Obendrauf die Endgame-Schere: hohe Karten verlangen volle Vorbereitung.
	var world_growth := Scaling.factor(tier)
	var brutal := brutal_faktor(tier)
	# Die Schere wirkt voll auf die HP, nur zur Hälfte auf den Schaden: der
	# weiche Deckel soll über Ausdauer kommen, nicht über One-Shots (Balance-
	# Check 2026-10-16: Magier fielen auf Stufe 50-150 mit voller HP auf einen Schlag).
	var brutal_schaden := 1.0 + (brutal - 1.0) * BRUTAL_SCHADEN_ANTEIL
	var hp_mult := (1.0 + TIER_HP_SCALE * (tier - 1)) * world_growth * brutal
	var dmg_mult := (1.0 + TIER_DMG_SCALE * (tier - 1)) * world_growth * brutal_schaden
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
		_compose_name(archetype, modifiers,
			region.get("prefix_en" if Loc.language == "en" else "prefix", ""),
			element, variant),
		stats, false)
	enemy.sprite = SpriteLib.enemy(archetype.id)
	enemy.sprite_scale = archetype.sprite_scale
	enemy.archetype_id = archetype.id
	enemy.level = tier
	enemy.max_hp = maxi(1, roundi(enemy.max_hp * hp_mult))
	enemy.hp = enemy.max_hp
	# Rüstung/Resistenz wachsen mit — sonst durchschlägt exponentielles
	# Helden-Gear die flachen Werte und Mitigation wird bedeutungslos.
	# Rüstung/Resistenz bleiben PUNKTE — sie wachsen im Kampf mit dem Level
	# (Combatant.natuerliche_einheit) und mindern prozentual.
	enemy.armor = archetype.armor + armor_bonus
	enemy.magic_resist = archetype.magic_resist
	enemy.natur_klasse = variant.get("klasse", archetype.armor_class)
	enemy.is_undead = archetype.undead
	enemy.element_faktoren = archetype.element_faktoren.duplicate()
	# Element-Schicht (Feuer-Wolf …): eigenes Element resistent, Gegenteil schwach.
	if element != Enums.Element.NONE:
		enemy.set_meta(&"element_schicht", int(element))
		enemy.element_faktoren[element] = 0.5
		var gegen: int = GEGEN_ELEMENT.get(element, -1)
		# Untote nehmen Heilig ohnehin ×1.5 — nicht doppelt schwächen.
		if gegen >= 0 and not (gegen == Enums.Element.HOLY and archetype.undead):
			enemy.element_faktoren[gegen] = 1.5
	# Gegner tragen keine Items » innewohnende Waffen-/Zauberwerte aus den Stats
	# (Phase-3-Rework: Schaden kommt aus der "Waffe", auch bei Gegnern).
	# Bewusst moderat, da der Angriffs-Stat im Kampf nochmal obendrauf kommt.
	enemy.innate_weapon_damage = 1 + roundi(stats.strength * 0.5)
	enemy.innate_spell_damage = 1 + roundi((stats.intelligence + stats.spirit) * 0.5)
	for modifier in modifiers:
		enemy.loot_mult *= modifier.loot_multiplier
		enemy.xp_mult *= modifier.xp_multiplier
		if modifier.aura_status >= 0:
			var auren: Array = enemy.get_meta(&"auren", [])
			auren.append([modifier.aura_status, modifier.aura_potency, modifier.display_name])
			enemy.set_meta(&"auren", auren)

	enemy.skills = _pick_skills(archetype, rng)
	# Kombo-Skill (Skillbau 3.0): meist einer der freigeschalteten. Eigener
	# Würfel aus dem Zustand des Haupt-Würfels — zieht dort nichts ab, die
	# Gruppen bestehender Karten bleiben also dieselben.
	var kombos := EnemyLibrary.kombos_fuer(archetype.id, tier)
	if not kombos.is_empty():
		var kombo_rng := RandomNumberGenerator.new()
		kombo_rng.seed = hash([rng.state, archetype.id])
		if kombo_rng.randf() < KOMBO_CHANCE:
			enemy.skills.append(kombos[kombo_rng.randi_range(0, kombos.size() - 1)])
	for modifier in modifiers:
		if modifier.granted_skill != null:
			enemy.skills.append(modifier.granted_skill)

	# Klassen-Variante: Bogenschützen feuern doppelt (schwächer pro Pfeil),
	# und die Klasse bringt ihren eigenen Skill mit (Waffenart/Zauber/Beschwörung).
	if not variant.is_empty():
		enemy.innate_hit_count = variant.get("hits", 1)
		enemy.innate_weapon_damage = maxi(1,
			roundi(enemy.innate_weapon_damage * variant.get("dmg", 1.0)))
		enemy.xp_mult *= variant.get("xp", 1.0)
		enemy.flee_chance = variant.get("flee", 0.0)
		if variant.has("hp_set"):  # Metallschleim: hauchdünne HP, fixe Zahl
			enemy.max_hp = int(variant["hp_set"])
			enemy.hp = enemy.max_hp
		if variant.has("blocks"):
			var variant_skill := Skill.new()
			variant_skill.display_name = Loc.pick(variant["skill_name"],
				variant.get("skill_name_en", variant["skill_name"]))
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
			elemental_skill.display_name = Loc.pick("%s-Angriff", "%s Attack") \
				% element_block.display_name
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
		# Anführer-Auren nur für Elite-Gegner: ein Boss mit Aura stärkte sich jeden
		# Zug selbst auf Stufe 2 (Schutzherr + Bannwirker = doppelte Rüstung und
		# −50 % Magie) und wurde unbesiegbar (Balance-Spur Schleimgott Stufe 60).
		var boss_modifiers: Array[EnemyModifier] = []
		for modifier in card_modifiers:
			if modifier.aura_status < 0:
				boss_modifiers.append(modifier)
		var boss := build(archetype, tier, rng, boss_modifiers, card.biome, boss_element)
		boss.display_name = "Boss: " + boss.display_name
		boss.max_hp = roundi(boss.max_hp * boss_hp_faktor(tier))
		boss.hp = boss.max_hp
		boss.loot_mult *= 1.5
		# Legacy-Boss: pro bisherigem Abschluss +20% Beute obendrauf.
		if card.legendary:
			boss.loot_mult *= 1.0 + 0.2 * card.times_completed
			boss.xp_mult *= 1.0 + 0.15 * card.times_completed
		boss.stats.strength = roundi(boss.stats.strength * boss_schaden_faktor(tier))
		boss.stats.intelligence = roundi(boss.stats.intelligence * boss_schaden_faktor(tier))
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
		# Bosse beherrschen ALLE Kombos ihres Grundtyps.
		for kombo in EnemyLibrary.kombos_fuer(archetype.id, tier):
			var schon := false
			for skill in boss.skills:
				if skill.display_name == kombo.display_name:
					schon = true
			if not schon:
				boss.skills.append(kombo)
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
	# ERSTER Wurf = Anführer. Der Dungeon-Marker (_archetype_for_enemy)
	# würfelt mit derselben Seed-Formel denselben Archetyp — das Monster,
	# das man in der Welt sieht, führt auch die Kampfgruppe an!
	var leader := pool[rng.randi_range(0, pool.size() - 1)]
	var group: Array[Combatant] = []
	# Höhere Stufen bringen größere Gruppen (Action-Economy vs. 4 Helden);
	# die ersten Stufen bleiben bewusst klein (sanfter Einstieg, Balance-Sim).
	var base_max := 2 if tier <= 2 else 3
	# Der Stufen-Bonus ist ein WÜRFEL (0..2), kein Fixwert — sonst wären ab
	# Stufe ~16 ALLE Gruppen 5er-Packs (Action-Economy erschlägt die Party;
	# Balance-Sim). So bleiben auch im Endgame kleine Gruppen im Mix.
	var count := clampi(rng.randi_range(1, base_max)
		+ rng.randi_range(0, mini(2, tier / 8)), 1, 5)
	# Karten-Affix "Elitär": doppelte Elite-Chance.
	var elite_chance := ELITE_CHANCE
	if &"elitaer" in card.card_affix_ids:
		elite_chance *= 2.0
	for i in count:
		var archetype := leader if i == 0 else pool[rng.randi_range(0, pool.size() - 1)]
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
			enemy.set_meta(&"rang", "champion")  # 3D-Schmuck (FigurenBau.schmuecken)
			enemy.display_name = "Champion: " + enemy.display_name
			enemy.max_hp = roundi(enemy.max_hp * CHAMPION_HP_MULT)
			enemy.hp = enemy.max_hp
			enemy.loot_mult *= CHAMPION_LOOT_MULT
		elif not modifiers.is_empty():
			enemy.set_meta(&"rang", "elite")
		group.append(enemy)
	# Güldene Gegner (Metallschleim-Prinzip für JEDE Art): selten, zäh,
	# flüchtig — und ein XP-/Beute-Jackpot. DAS Farm-Ziel beim Grinden.
	for enemy in group:
		var wurf := rng.randf()
		if wurf < GOLDEN_CHANCE:
			_gild(enemy)
		elif wurf < GOLDEN_CHANCE + STRAHLEND_CHANCE:
			_strahlen(enemy)
		elif wurf < GOLDEN_CHANCE + STRAHLEND_CHANCE + KARTENHUETER_CHANCE and tier >= KARTENHUETER_AB_STUFE:
			_kartenhueter(enemy)
	_normale_gruppe_daempfen(group)
	_apply_dangerous_affix(group, card)
	_apply_card_rarity(group, card)
	return group


## Sondergegner (Lutz 2026-10-16), EIN Wurf pro Gegner (gleiche Zufallsfolge
## wie früher — Karten bleiben bei jedem Besuch identisch), nicht bei Bossen:
## Güldene = Gold-Jackpot, Strahlende = XP-Jackpot, Kartenhüter tragen eine
## seltene Schatzkarte (episch/legendär, 1-5 Stufen über der Karte).
const GOLDEN_CHANCE := 0.03
const STRAHLEND_CHANCE := 0.03
const KARTENHUETER_CHANCE := 0.01
const KARTENHUETER_AB_STUFE := 4


## Vergoldet einen Gegner — der GOLD-Jackpot: ×6 Beute (Gold und Item-
## Chance), ×1,5 XP, dick gepanzert, flüchtet gern.
static func _gild(enemy: Combatant) -> void:
	enemy.set_meta(&"gulden", true)  # glänzt golden (FigurenBau.schmuecken)
	enemy.display_name = Loc.pick("Güldener ", "Gilded ") + enemy.display_name
	enemy.xp_mult *= 1.5
	enemy.loot_mult *= 6.0
	enemy.armor = roundi(enemy.armor * 1.5) + 5
	enemy.magic_resist = roundi(enemy.magic_resist * 1.5) + 5
	enemy.flee_chance = maxf(enemy.flee_chance, 0.3)


## Strahlender Gegner — der XP-Jackpot: ×8 XP, gepanzert, flüchtet gern.
static func _strahlen(enemy: Combatant) -> void:
	enemy.set_meta(&"sonder", "strahlend")  # leuchtet (FigurenBau.schmuecken)
	enemy.display_name = Loc.pick("Strahlender ", "Radiant ") + enemy.display_name
	enemy.xp_mult *= 8.0
	enemy.armor = roundi(enemy.armor * 1.5) + 5
	enemy.magic_resist = roundi(enemy.magic_resist * 1.5) + 5
	enemy.flee_chance = maxf(enemy.flee_chance, 0.3)


## Kartenhüter: trägt eine seltene Schatzkarte, flieht NICHT, ist zäher.
static func _kartenhueter(enemy: Combatant) -> void:
	enemy.set_meta(&"sonder", "karte")
	enemy.set_meta(&"schatzkarte", true)
	enemy.display_name = Loc.pick("Kartenhüter: ", "Map keeper: ") + enemy.display_name
	enemy.max_hp = roundi(enemy.max_hp * 1.5)
	enemy.hp = enemy.max_hp
	enemy.loot_mult *= 1.5
	enemy.flee_chance = 0.0


## DQ9-Prinzip (Lutz 2026-10-15): normale Gegner sind Alltag, der Boss ist
## die Hürde. Normale Gruppen machen weniger Schaden und halten etwas weniger
## aus — Bosse und ihre Begleiter bleiben unverändert.
const NORMAL_SCHADEN := 0.8
const NORMAL_HP := 0.9


static func _normale_gruppe_daempfen(group: Array[Combatant]) -> void:
	for enemy in group:
		enemy.stats.strength = roundi(enemy.stats.strength * NORMAL_SCHADEN)
		enemy.stats.intelligence = roundi(enemy.stats.intelligence * NORMAL_SCHADEN)
		enemy.innate_weapon_damage = maxi(1, roundi(enemy.innate_weapon_damage * NORMAL_SCHADEN))
		enemy.innate_spell_damage = maxi(1, roundi(enemy.innate_spell_damage * NORMAL_SCHADEN))
		enemy.max_hp = maxi(1, roundi(enemy.max_hp * NORMAL_HP))
		enemy.hp = enemy.max_hp


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
		if Loc.language == "en":
			# Englisch: Variante als vorangestelltes Wort ("Alpha Wolf").
			base_name = "%s %s" % [variant.get("name_en", variant["name"]), base_name]
		elif variant.get("sep", "-") == "-":
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
