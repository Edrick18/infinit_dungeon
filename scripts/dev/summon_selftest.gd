extends SceneTree
## Headless-Selbsttest für Beschwörungen (Phase 3, Schritt 3):
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/summon_selftest.gd

var failures := 0


func _init() -> void:
	_test_summon_appears()
	_test_summon_variants()
	_test_summon_acts_and_expires()
	_test_summon_replacement()
	_test_summon_guardian()
	_test_summon_excluded_from_outcome()
	if failures == 0:
		print("SELFTEST OK — alle Beschwörungs-Tests bestanden")
		quit(0)
	else:
		print("SELFTEST FEHLGESCHLAGEN — %d Fehler" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		printerr("  FEHLER: " + label)


func _battle(seed_value := 1) -> Battle:
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = seed_value
	return battle


func _caster(spirit := 8) -> Combatant:
	var stats := StatBlock.new()
	stats.vitality = 10
	stats.spirit = spirit
	stats.intelligence = 10
	var caster := Combatant.create("Beschwörer", stats, true)
	caster.innate_spell_damage = 10
	caster.mp = 999
	return caster


func _enemy(vitality := 50) -> Combatant:
	var stats := StatBlock.new()
	stats.vitality = vitality
	return Combatant.create("Gegner", stats, false)


func _summon_skill(extra_ids: Array = []) -> Skill:
	var skill := Skill.new()
	skill.display_name = "Ruf"
	skill.blocks.append(BlockLibrary.get_block(&"src_spell"))
	skill.blocks.append(BlockLibrary.get_block(&"form_summon"))
	for id in extra_ids:
		skill.blocks.append(BlockLibrary.get_block(id))
	return skill


func _find_summon(battle: Battle) -> Combatant:
	for ally in battle.players:
		if ally.is_summon:
			return ally
	return null


func _test_summon_appears() -> void:
	print("Beschwörung erscheint:")
	var battle := _battle()
	var caster := _caster()
	var party_ref: Array[Combatant] = [caster]
	battle.start(party_ref, [_enemy()])

	var added: Array = []
	battle.combatant_added.connect(func(c: Combatant) -> void: added.append(c))
	_check(battle.use_skill(caster, _summon_skill(), null), "Beschwörungs-Skill wird gewirkt")
	var summon := _find_summon(battle)
	_check(summon != null, "Beschwörung steht auf der Spielerseite")
	_check(added.size() == 1, "combatant_added-Signal gefeuert (UI-Panel)")
	_check(summon.summoner == caster, "Beschwörung kennt ihren Beschwörer")
	_check(summon.max_hp == 15 + caster.stat(&"spirit") * Battle.SUMMON_HP_PER_SPIRIT,
		"HP skalieren mit SPI des Beschwörers")
	_check(not party_ref.has(summon),
		"GameState-Party-Array bleibt unangetastet (Battle nutzt Kopien)")


func _test_summon_variants() -> void:
	print("Varianten (Bausteine bestimmen die Kreatur):")
	var battle := _battle()
	var caster := _caster()
	battle.start([caster], [_enemy()])

	battle.use_skill(caster, _summon_skill(), null)
	var wolf := _find_summon(battle)
	_check(wolf.display_name == "Beschworener Wolf" and wolf.innate_weapon_damage > 0,
		"ohne Element: Wolf (physischer Angreifer)")

	battle.use_skill(caster, _summon_skill([&"elem_fire"]), null)
	var elemental := _find_summon(battle)
	_check(elemental.display_name == "Feuer-Elementar" and elemental.innate_spell_damage > 0,
		"mit Feuer: Feuer-Elementar (Zauber-Angreifer)")
	_check(elemental.skills.size() == 1 and elemental.skills[0].get_element() != null,
		"Elementar trägt einen Element-Zauber")


func _test_summon_acts_and_expires() -> void:
	print("Beschwörung handelt und läuft ab:")
	var battle := _battle(7)
	var caster := _caster()
	var enemy := _enemy(200)
	battle.start([caster], [enemy])
	battle.use_skill(caster, _summon_skill(), null)
	var summon := _find_summon(battle)

	var removed: Array = []
	battle.combatant_removed.connect(func(c: Combatant) -> void: removed.append(c))

	# Kampfschleife: Beschwörung agiert per KI, bis sie abläuft.
	var enemy_hp_before := enemy.hp
	var safety := 0
	while _find_summon(battle) != null and safety < 60:
		var actor := battle.next_turn()
		if actor == null:
			break
		if actor == summon or not actor.is_player:
			# Gegner schlagen absichtlich nur den Beschwörer nicht (Fokus Test).
			if actor == summon:
				battle.ai_take_turn(actor)
		safety += 1
	_check(enemy.hp < enemy_hp_before, "Beschwörung hat den Gegner per KI angegriffen")
	_check(removed.size() == 1 and removed[0] == summon,
		"Beschwörung läuft nach %d Zügen ab (combatant_removed)" % Battle.SUMMON_DURATION)
	_check(not battle.players.has(summon), "abgelaufene Beschwörung ist aus dem Kampf entfernt")


func _test_summon_replacement() -> void:
	print("Nur eine Beschwörung pro Beschwörer:")
	var battle := _battle()
	var caster := _caster()
	battle.start([caster], [_enemy()])
	battle.use_skill(caster, _summon_skill(), null)
	var first := _find_summon(battle)
	battle.use_skill(caster, _summon_skill([&"elem_fire"]), null)
	var second := _find_summon(battle)
	var summon_count := 0
	for ally in battle.players:
		if ally.is_summon:
			summon_count += 1
	_check(summon_count == 1, "zweite Beschwörung ersetzt die erste")
	_check(second != first and second.display_name == "Feuer-Elementar",
		"die neue Beschwörung ist aktiv")


func _test_summon_guardian() -> void:
	print("Wächter-Kombo (Beschwörung + Schutzwall):")
	var battle := _battle()
	var caster := _caster()
	var enemy := _enemy()
	enemy.stats.strength = 10
	battle.start([caster], [enemy])
	battle.use_skill(caster, _summon_skill([&"eff_protect"]), null)
	var guardian := _find_summon(battle)
	_check(guardian.has_status(Enums.Status.PROTECT),
		"Schutzwall-Baustein wirkt auf die Beschwörung")

	var caster_hp := caster.hp
	battle.basic_attack(enemy, caster)
	_check(caster.hp == caster_hp and guardian.hp < guardian.max_hp,
		"der Wächter fängt den Angriff auf den Beschwörer ab")


func _test_summon_excluded_from_outcome() -> void:
	print("Beschwörungen zählen nicht für Sieg/Niederlage:")
	var battle := _battle()
	var caster := _caster()
	var enemy := _enemy(5)
	enemy.hp = 5
	battle.start([caster], [enemy])
	battle.use_skill(caster, _summon_skill(), null)

	var results: Array = []
	battle.battle_ended.connect(func(v: bool) -> void: results.append(v))
	# Der echte Held fällt — die lebende Beschwörung darf das nicht aufhalten.
	caster.hp = 0
	battle.basic_attack(enemy, _find_summon(battle))
	_check(results == [false], "Niederlage trotz lebender Beschwörung")
