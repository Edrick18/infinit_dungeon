extends SceneTree
## Headless-Selbsttest fürs Kampfsystem:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/combat_selftest.gd
## Alle Tests laufen mit deaktivierten Krits und festem RNG-Seed (deterministisch).

var failures := 0


func _init() -> void:
	_test_derived_values()
	_test_turn_order()
	_test_basic_attack()
	_test_skill_damage_and_dot()
	_test_dot_tick_and_expiry()
	_test_stun_skips_turn()
	_test_aoe_hits_all()
	_test_aura_regen()
	_test_battle_end()
	if failures == 0:
		print("SELFTEST OK — alle Kampfsystem-Tests bestanden")
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


func _make_battle() -> Battle:
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = 42
	return battle


func _fighter(name: String, agility: int, is_player: bool, strength := 5,
		vitality := 5, spirit := 4) -> Combatant:
	var stats := StatBlock.new()
	stats.strength = strength
	stats.agility = agility
	stats.vitality = vitality
	stats.spirit = spirit
	return Combatant.create(name, stats, is_player)


func _test_derived_values() -> void:
	print("Abgeleitete Werte:")
	var c := _fighter("Test", 5, true, 5, 5, 4)
	_check(c.max_hp == 60, "HP: 20 + 5 VIT × 8 = 60")
	_check(c.max_mp == 30, "MP: 10 + 4 SPI × 5 = 30")


func _test_turn_order() -> void:
	print("Zugreihenfolge:")
	var battle := _make_battle()
	var fast := _fighter("Schnell", 9, true)
	var mid := _fighter("Mittel", 5, false)
	var slow := _fighter("Langsam", 2, true)
	battle.start([fast, slow], [mid])
	_check(battle.next_turn() == fast, "schnellster Kämpfer zuerst")
	_check(battle.next_turn() == mid, "dann der mittlere")
	_check(battle.next_turn() == slow, "dann der langsamste")
	_check(battle.round_number == 1, "alles in Runde 1")
	_check(battle.next_turn() == fast, "Runde 2 beginnt wieder beim schnellsten")


func _test_basic_attack() -> void:
	print("Basisangriff:")
	var battle := _make_battle()
	var attacker := _fighter("Angreifer", 5, true, 10)
	var target := _fighter("Ziel", 3, false)
	target.armor = 2
	battle.start([attacker], [target])
	var hp_before := target.hp
	battle.basic_attack(attacker, target)
	_check(hp_before - target.hp == 13, "Schaden: 5 Basis + 10 STR - 2 Rüstung = 13")


func _test_skill_damage_and_dot() -> void:
	print("Skill: Magie + Elementar-DoT kombiniert:")
	var battle := _make_battle()
	var caster := _fighter("Magier", 5, true)
	caster.stats.intelligence = 5
	var target := _fighter("Ziel", 3, false)
	target.magic_resist = 3

	var magic := DamageBlock.new()
	magic.axis = Enums.DamageAxis.MAGICAL
	magic.base_amount = 10
	magic.scaling_stat = &"intelligence"
	magic.scaling_per_point = 1.0
	magic.mp_cost = 5

	var burn := DamageBlock.new()
	burn.axis = Enums.DamageAxis.ELEMENTAL
	burn.element = Enums.Element.FIRE
	burn.base_amount = 6
	burn.scaling_per_point = 0.0
	burn.dot_turns = 3
	burn.mp_cost = 3

	var carrier := CarrierBlock.new()
	carrier.carrier = Enums.Carrier.PROJECTILE

	var skill := Skill.new()
	skill.display_name = "Testfeuer"
	skill.blocks = [magic, burn, carrier]

	battle.start([caster], [target])
	var hp_before := target.hp
	var mp_before := caster.mp
	_check(battle.use_skill(caster, skill, target), "Skill wird ausgeführt")
	_check(mp_before - caster.mp == 8, "MP-Kosten 8 abgezogen")
	_check(hp_before - target.hp == 12, "Magieschaden: 10 + 5 INT - 3 Resist = 12")
	var dot := target.get_status(Enums.Status.BURN)
	_check(not dot.is_empty() and dot["potency"] == 2 and dot["turns"] == 3,
		"Brand-DoT: 6 Schaden über 3 Runden = 2 pro Tick")


func _test_dot_tick_and_expiry() -> void:
	print("DoT tickt am Zugbeginn und läuft aus:")
	var battle := _make_battle()
	var victim := _fighter("Opfer", 9, false)
	var other := _fighter("Anderer", 1, true)
	victim.add_status(Enums.Status.BURN, 2, 3)
	battle.start([other], [victim])
	var hp_before := victim.hp
	_check(battle.next_turn() == victim, "Opfer ist zuerst dran (AGI 9)")
	_check(hp_before - victim.hp == 3, "Brand tickt 3 Schaden am Zugbeginn")
	battle.next_turn()  # other
	battle.next_turn()  # victim, Runde 2: zweiter Tick, danach abgelaufen
	_check(hp_before - victim.hp == 6, "zweiter Tick in Runde 2")
	_check(not victim.has_status(Enums.Status.BURN), "Brand nach 2 Runden abgelaufen")


func _test_stun_skips_turn() -> void:
	print("Betäubung:")
	var battle := _make_battle()
	var stunned := _fighter("Betäubt", 9, true)
	var other := _fighter("Wach", 2, false)
	stunned.add_status(Enums.Status.STUN, 1, 0)
	battle.start([stunned], [other])
	_check(battle.next_turn() == other, "betäubter Kämpfer wird übersprungen")
	_check(not stunned.has_status(Enums.Status.STUN), "Betäubung danach abgelaufen")
	_check(battle.next_turn() == stunned, "nächste Runde ist er wieder dran")


func _test_aoe_hits_all() -> void:
	print("Flächenschaden:")
	var battle := _make_battle()
	var caster := _fighter("Magier", 5, true)
	var enemy_a := _fighter("A", 3, false)
	var enemy_b := _fighter("B", 2, false)

	var dmg := DamageBlock.new()
	dmg.axis = Enums.DamageAxis.MAGICAL
	dmg.base_amount = 10
	dmg.scaling_per_point = 0.0
	dmg.mp_cost = 4
	var carrier := CarrierBlock.new()
	carrier.carrier = Enums.Carrier.AOE
	var skill := Skill.new()
	skill.blocks = [dmg, carrier]

	battle.start([caster], [enemy_a, enemy_b])
	var a_before := enemy_a.hp
	var b_before := enemy_b.hp
	battle.use_skill(caster, skill, null)
	_check(enemy_a.hp < a_before and enemy_b.hp < b_before, "AoE trifft beide Gegner")


func _test_aura_regen() -> void:
	print("Aura (Regeneration auf Party):")
	var battle := _make_battle()
	var healer := _fighter("Heiler", 5, true)
	var ally := _fighter("Verbündeter", 8, true)
	var enemy := _fighter("Gegner", 1, false)
	ally.hp = 10

	var regen := EffectBlock.new()
	regen.status = Enums.Status.REGEN
	regen.chance_percent = 100
	regen.duration_turns = 2
	regen.potency = 5
	regen.mp_cost = 4
	var carrier := CarrierBlock.new()
	carrier.carrier = Enums.Carrier.AURA
	var skill := Skill.new()
	skill.blocks = [regen, carrier]

	battle.start([healer, ally], [enemy])
	battle.use_skill(healer, skill, null)
	_check(ally.has_status(Enums.Status.REGEN) and healer.has_status(Enums.Status.REGEN),
		"Aura liegt auf der ganzen Party")
	battle.next_turn()  # ally (AGI 8) → Regen-Tick
	_check(ally.hp == 15, "Verbündeter regeneriert 5 HP am Zugbeginn")


func _test_battle_end() -> void:
	print("Kampfende:")
	var battle := _make_battle()
	var attacker := _fighter("Held", 5, true, 20)
	var target := _fighter("Letzter Gegner", 3, false)
	target.hp = 5
	battle.start([attacker], [target])

	var results: Array = []
	battle.battle_ended.connect(func(victory: bool) -> void: results.append(victory))
	battle.basic_attack(attacker, target)
	_check(not target.is_alive(), "Gegner besiegt")
	_check(results == [true], "battle_ended mit Sieg gefeuert")
	_check(battle.next_turn() == null, "next_turn liefert null nach Kampfende")
