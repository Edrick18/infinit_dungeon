extends SceneTree
## Balancing-Simulation: spielt Auto-Kämpfe und komplette Dungeon-Läufe
## (Party Level L vs. Karte Stufe T) und druckt eine Ergebnistabelle.
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/balance_sim.gd
## Kein Test (kein OK/FEHLER) — ein Werkzeug, um Skalierungs-Schrauben zu prüfen.

const RUNS_PER_CELL := 60
const BATTLES_PER_RUN := 6  ## normale Kämpfe vor dem Boss
const MAX_TURNS := 400


func _init() -> void:
	print("Party-Level vs. Kartenstufe — %d Läufe pro Zelle" % RUNS_PER_CELL)
	print("Lauf = %d Kämpfe + Boss, Verschnaufen +25%% nach Siegen, keine Tränke" % BATTLES_PER_RUN)
	print("")
	print("  L=Level T=Tier | Einzelkampf% | Lauf geschafft% | Ø Runden/Kampf")
	for pair in [[1, 1], [3, 3], [5, 5], [8, 8], [12, 12], [5, 3], [5, 8], [10, 13]]:
		_simulate_cell(pair[0], pair[1])
	quit(0)


func _simulate_cell(level: int, tier: int) -> void:
	var battle_wins := 0
	var battle_total := 0
	var runs_completed := 0
	var rounds_total := 0

	for i in RUNS_PER_CELL:
		var rng := RandomNumberGenerator.new()
		rng.seed = 100000 + i * 977 + level * 13 + tier
		var card := CardFactory.make_card(tier, rng)
		# Gear entspricht dem eigenen Fortschritt (Level), nicht der Karte.
		var party := _make_party(level, level)
		var run_alive := true

		for battle_index in BATTLES_PER_RUN + 1:
			var is_boss := battle_index == BATTLES_PER_RUN
			var foes := EnemyFactory.make_encounter(card, rng, is_boss)
			var result := _run_battle(party, foes, rng.randi())
			battle_total += 1
			rounds_total += result["rounds"]
			if result["won"]:
				battle_wins += 1
				for member in party:
					member.statuses.clear()
					member.hp = maxi(member.hp, 1)
					member.heal(roundi(member.max_hp * 0.25))
					member.mp = mini(member.max_mp, member.mp + roundi(member.max_mp * 0.25))
			else:
				run_alive = false
				break
		if run_alive:
			runs_completed += 1

	print("  L%2d vs T%2d    |      %5.1f%%  |         %5.1f%%  |  %5.1f" % [
		level, tier,
		100.0 * battle_wins / battle_total,
		100.0 * runs_completed / RUNS_PER_CELL,
		float(rounds_total) / battle_total,
	])


func _run_battle(party: Array[Combatant], foes: Array[Combatant], seed_value: int) -> Dictionary:
	var battle := Battle.new()
	battle.rng.seed = seed_value
	for member in party:
		member.statuses.clear()
	battle.start(party, foes)
	var turns := 0
	while not battle.is_over and turns < MAX_TURNS:
		var actor := battle.next_turn()
		if actor == null:
			break
		# Gegenspiel wie echte Spieler: kündigt ein Boss seinen Spezialangriff
		# an, geht die Party in Verteidigungshaltung.
		if actor.is_player and _boss_is_charging(battle):
			battle.defend(actor)
		else:
			battle.ai_take_turn(actor)
		turns += 1
	var won := not battle._living(foes).is_empty() == false and battle._living(party).size() > 0
	return {"won": battle._living(foes).is_empty() and not battle._living(party).is_empty(),
		"rounds": battle.round_number}


func _boss_is_charging(battle: Battle) -> bool:
	for enemy in battle.enemies:
		if enemy.is_alive() and enemy.charge_active:
			return true
	return false


## Typische 4er-Party auf Level L mit Tier-Gear: Tank, Nahkämpfer, Magier, Support.
func _make_party(level: int, tier: int) -> Array[Combatant]:
	# Builds spiegeln die Level-Freischaltungen wider: höhere Level nutzen
	# Elemente, Buffs und Verstärker — wie echte Spieler auch.
	var tank := _hero("Tank", level, {&"vitality": 0.5, &"strength": 0.3, &"agility": 0.2})
	tank.skills = [_skill([&"src_spell", &"form_self", &"eff_protect"]), _skill([&"src_weapon"])]
	_equip_best(tank, tier, false, true)

	var damage_dealer := _hero("DD", level, {&"strength": 0.5, &"agility": 0.3, &"vitality": 0.2})
	var dd_strike := [&"src_weapon", &"src_spell", &"elem_fire"]
	if level >= 8:
		dd_strike.append(&"mod_overload")
	damage_dealer.skills = [_skill([&"src_weapon"]), _skill(dd_strike)]
	_equip_best(damage_dealer, tier, false, false)

	var mage := _hero("Magier", level, {&"intelligence": 0.5, &"spirit": 0.3, &"vitality": 0.2})
	var mage_aoe := [&"src_spell", &"form_aoe"]
	if level >= 6:
		mage_aoe.append(&"elem_fire")  # Flächen-Brand: Stacks auf alle
	if level >= 5:
		mage_aoe.append(&"mod_power")
	mage.skills = [_skill([&"src_spell", &"elem_fire"]), _skill(mage_aoe)]
	_equip_best(mage, tier, true, false)

	var support := _hero("Support", level, {&"spirit": 0.4, &"vitality": 0.3, &"intelligence": 0.3})
	var support_aura := [&"src_spell", &"form_aura", &"eff_regen", &"eff_def_up"]
	if level >= 4:
		support_aura.append(&"eff_atk_up")
	support.skills = [_skill(support_aura), _skill([&"src_spell", &"elem_poison"])]
	_equip_best(support, tier, true, false)

	return [tank, damage_dealer, mage, support]


func _hero(name: String, level: int, weights: Dictionary) -> Combatant:
	var stats := StatBlock.new()
	for stat in StatBlock.STAT_NAMES:
		stats.set(stat, 5)
	var points := Combatant.POINTS_PER_LEVEL * (level - 1)
	var spent := 0
	for stat in weights:
		var share := int(points * weights[stat])
		stats.set(stat, stats.get(stat) + share)
		spent += share
	# Rest in den ersten Gewichts-Stat.
	if spent < points:
		var first: StringName = weights.keys()[0]
		stats.set(first, stats.get(first) + points - spent)
	var hero := Combatant.create(name, stats, true)
	hero.level = level
	return hero


## Bestes Tier-Gear ohne Affixe (konservativ): Waffe, Rüstung, ggf. Schild/Helm.
func _equip_best(hero: Combatant, tier: int, caster: bool, with_shield: bool) -> void:
	var best_weapon: ItemBase = null
	var best_armor: ItemBase = null
	var best_shield: ItemBase = null
	var best_helmet: ItemBase = null
	for base in ItemLibrary.bases_for_tier(tier):
		match base.slot:
			Enums.EquipSlot.WEAPON:
				if with_shield and base.two_handed:
					continue
				# Caster wollen Zauberschaden (Stäbe), Nahkämpfer physischen Waffenschaden.
				if _weapon_score(base, caster) > _weapon_score(best_weapon, caster):
					best_weapon = base
			Enums.EquipSlot.ARMOR:
				# Caster tragen Roben (Zauberkraft), Kämpfer den besten Panzer.
				if caster:
					if best_armor == null or base.spell_damage > best_armor.spell_damage:
						best_armor = base
				elif best_armor == null or base.base_armor > best_armor.base_armor:
					best_armor = base
			Enums.EquipSlot.OFF_HAND:
				if base.base_armor > 0 and (best_shield == null
						or base.base_armor > best_shield.base_armor):
					best_shield = base
			Enums.EquipSlot.HELMET:
				if best_helmet == null or base.base_armor > best_helmet.base_armor:
					best_helmet = base
	for base in [best_weapon, best_armor, best_helmet]:
		if base != null:
			hero.equip(_instance(base, tier))
	if with_shield and best_shield != null:
		hero.equip(_instance(best_shield, tier))


func _weapon_score(base: ItemBase, caster: bool) -> int:
	if base == null:
		return -1
	return base.spell_damage if caster else base.base_damage


func _instance(base: ItemBase, item_level: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.base = base
	item.item_level = item_level
	return item


func _skill(block_ids: Array) -> Skill:
	var skill := Skill.new()
	skill.display_name = "Sim"
	for id in block_ids:
		skill.blocks.append(BlockLibrary.get_block(id))
	return skill
