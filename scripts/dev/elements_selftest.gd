extends SceneTree
## Headless-Selbsttest für Element-Signaturen (Phase 3, Schritt 2) und die
## neuen Modifikatoren:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/elements_selftest.gd

var failures := 0


func _init() -> void:
	_test_burn_stacks()
	_test_poison_stacks()
	_test_ice()
	_test_lightning()
	_test_holy()
	_test_dark()
	_test_new_modifiers()
	if failures == 0:
		print("SELFTEST OK — alle Element-/Modifikator-Tests bestanden")
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


func _fighter(name: String, is_player := true, vitality := 50) -> Combatant:
	var stats := StatBlock.new()
	stats.vitality = vitality
	stats.spirit = 10
	var fighter := Combatant.create(name, stats, is_player)
	fighter.mp = 999
	return fighter


func _caster(spell_damage := 20) -> Combatant:
	var caster := _fighter("Zauberer")
	caster.innate_spell_damage = spell_damage
	caster.mp = 999
	return caster


func _spell(element_id: StringName, extra_ids: Array = []) -> Skill:
	var skill := Skill.new()
	skill.display_name = "Test"
	skill.blocks.append(BlockLibrary.get_block(&"src_spell"))
	if element_id != StringName():
		skill.blocks.append(BlockLibrary.get_block(element_id))
	for id in extra_ids:
		skill.blocks.append(BlockLibrary.get_block(id))
	return skill


func _test_burn_stacks() -> void:
	print("Brand (aufbauend, abklingend):")
	var battle := _battle()
	var caster := _caster(20)
	var target := _fighter("Ziel", false)
	battle.start([caster], [target])

	battle.use_skill(caster, _spell(&"elem_fire"), target)
	var stacks_1: int = target.get_status(Enums.Status.BURN)["potency"]
	_check(stacks_1 >= 15, "Stacks basieren auf dem Zauberschaden (%d)" % stacks_1)
	battle.use_skill(caster, _spell(&"elem_fire"), target)
	var stacks_2: int = target.get_status(Enums.Status.BURN)["potency"]
	_check(stacks_2 == stacks_1 * 2, "zweiter Treffer addiert Stacks (%d » %d)" % [stacks_1, stacks_2])

	# Tick: Schaden = Stacks, danach halbiert.
	var hp_before := target.hp
	battle.next_turn()  # Zauberer (AGI 0 vs 0 — Reihenfolge egal, wir suchen das Ziel)
	while battle.get_turn_preview().size() > 0 and target.hp == hp_before:
		battle.next_turn()
	_check(hp_before - target.hp == stacks_2, "Tick-Schaden = Stacks (%d)" % stacks_2)
	_check(int(target.get_status(Enums.Status.BURN)["potency"]) == int(stacks_2 / 2.0),
		"Stacks nach Tick halbiert")


func _test_poison_stacks() -> void:
	print("Gift (weniger Stacks, permanent):")
	var battle := _battle()
	var caster := _caster(20)
	var target := _fighter("Ziel", false)
	battle.start([caster], [target])

	battle.use_skill(caster, _spell(&"elem_fire"), target)
	var burn_stacks: int = target.get_status(Enums.Status.BURN)["potency"]
	battle.use_skill(caster, _spell(&"elem_poison"), target)
	var poison_stacks: int = target.get_status(Enums.Status.POISON_DOT)["potency"]
	_check(poison_stacks < burn_stacks,
		"Gift gibt weniger Stacks als Brand (%d < %d)" % [poison_stacks, burn_stacks])

	# Zwei Ticks: Gift bleibt konstant, klingt nie ab.
	for i in 4:
		battle.next_turn()
	var after_ticks: int = target.get_status(Enums.Status.POISON_DOT)["potency"]
	_check(after_ticks == poison_stacks, "Gift-Stacks bleiben nach Ticks unverändert")
	_check(target.has_status(Enums.Status.POISON_DOT), "Gift läuft nie von selbst ab")

	# Nur Kurieren entfernt Gift.
	var cure := ConsumableLibrary.get_def(&"gegengift")
	battle.use_consumable(caster, cure, target)
	_check(not target.has_status(Enums.Status.POISON_DOT), "Gegengift entfernt Gift-Stacks")


func _test_ice() -> void:
	print("Eis (Einfrieren + Zerschmettern):")
	var battle := _battle(3)
	var caster := _caster(20)
	var attacker := _fighter("Nahkämpfer")
	attacker.stats.strength = 10
	attacker.innate_weapon_damage = 10
	var target := _fighter("Ziel", false, 80)
	battle.start([caster, attacker], [target])

	# Einfrieren erzwingen (Chance): so oft wirken, bis FROZEN liegt.
	var frozen := false
	for i in 20:
		battle.use_skill(caster, _spell(&"elem_ice"), target)
		if target.has_status(Enums.Status.FROZEN):
			frozen = true
			break
	_check(frozen, "Eis friert das Ziel ein (über mehrere Versuche)")

	# Physischer Treffer zerschmettert: Bonusschaden + Eis weg.
	target.hp = target.max_hp
	var hp_before := target.hp
	battle.basic_attack(attacker, target)
	var shatter_damage := hp_before - target.hp
	_check(not target.has_status(Enums.Status.FROZEN), "physischer Treffer bricht das Eis")

	target.statuses.clear()
	target.hp = target.max_hp
	hp_before = target.hp
	battle.basic_attack(attacker, target)
	var normal_damage := hp_before - target.hp
	_check(shatter_damage > normal_damage,
		"Zerschmettern macht Bonusschaden (%d > %d)" % [shatter_damage, normal_damage])


func _test_lightning() -> void:
	print("Blitz (Kette + Betäubungs-Chance):")
	var battle := _battle(2)
	var caster := _caster(20)
	var target_a := _fighter("A", false, 60)
	var target_b := _fighter("B", false, 60)
	battle.start([caster], [target_a, target_b])

	var b_before := target_b.hp
	battle.use_skill(caster, _spell(&"elem_lightning"), target_a)
	_check(target_b.hp < b_before, "Blitz springt auf das zweite Ziel über")
	_check(b_before - target_b.hp < target_a.max_hp - target_a.hp,
		"Ketten-Sprung macht weniger Schaden als der Haupttreffer")

	var stunned := false
	for i in 30:
		target_a.statuses.clear()
		battle.use_skill(caster, _spell(&"elem_lightning"), target_a)
		if target_a.has_status(Enums.Status.STUN):
			stunned = true
			break
	_check(stunned, "Blitz betäubt gelegentlich (über mehrere Versuche)")


func _test_holy() -> void:
	print("Heilig (Anti-Untot + Heilung):")
	var battle := _battle()
	var caster := _caster(20)
	var ally := _fighter("Verbündeter")
	var mortal := _fighter("Sterblicher", false, 80)
	var undead := _fighter("Untoter", false, 80)
	undead.is_undead = true
	battle.start([caster, ally], [mortal, undead])

	battle.use_skill(caster, _spell(&"elem_holy"), mortal)
	var mortal_damage := mortal.max_hp - mortal.hp
	battle.use_skill(caster, _spell(&"elem_holy"), undead)
	var undead_damage := undead.max_hp - undead.hp
	_check(undead_damage > mortal_damage,
		"Heilig macht Bonusschaden gegen Untote (%d > %d)" % [undead_damage, mortal_damage])

	# Heilig + Form „Verbündeter" = gezielte Einzelheilung.
	ally.hp = 10
	battle.use_skill(caster, _spell(&"elem_holy", [&"form_ally"]), ally)
	_check(ally.hp > 10, "Heilig-Zauber auf Verbündeten heilt statt zu schaden (+%d HP)" % (ally.hp - 10))


func _test_dark() -> void:
	print("Dunkel (Lebensraub + Fluch):")
	var battle := _battle()
	var caster := _caster(20)
	var target := _fighter("Ziel", false, 80)
	battle.start([caster], [target])

	caster.hp = 30
	battle.use_skill(caster, _spell(&"elem_dark"), target)
	_check(caster.hp > 30, "Dunkel raubt Leben (+%d HP)" % (caster.hp - 30))
	_check(target.has_status(Enums.Status.CURSED), "Ziel ist verflucht")

	# Fluch: Ziel nimmt mehr Schaden.
	target.hp = target.max_hp
	var cursed_before := target.hp
	battle.use_skill(caster, _spell(StringName()), target)  # roher Zauber
	var cursed_damage := cursed_before - target.hp
	target.statuses.clear()
	target.hp = target.max_hp
	battle.use_skill(caster, _spell(StringName()), target)
	var clean_damage := target.max_hp - target.hp
	_check(cursed_damage > clean_damage,
		"Verfluchte nehmen mehr Schaden (%d > %d)" % [cursed_damage, clean_damage])


func _test_new_modifiers() -> void:
	print("Neue Modifikatoren:")
	# Durchdringung: ignoriert Teil der Resistenz.
	var battle := _battle()
	var caster := _caster(20)
	var armored := _fighter("Gepanzert", false, 80)
	armored.magic_resist = 15
	battle.start([caster], [armored])
	battle.use_skill(caster, _spell(StringName()), armored)
	var without_pierce := armored.max_hp - armored.hp
	armored.hp = armored.max_hp
	battle.use_skill(caster, _spell(StringName(), [&"mod_pierce"]), armored)
	var with_pierce := armored.max_hp - armored.hp
	_check(with_pierce > without_pierce,
		"Durchdringung erhöht Schaden gegen Resistenz (%d > %d)" % [with_pierce, without_pierce])

	# Hinrichtung: Bonus unter 30% HP.
	var victim := _fighter("Opfer", false, 80)
	var battle_2 := _battle()
	battle_2.start([caster], [victim])
	victim.hp = roundi(victim.max_hp * 0.2)
	var low_before := victim.hp
	battle_2.use_skill(caster, _spell(StringName(), [&"mod_execute"]), victim)
	var execute_low := low_before - victim.hp
	victim.hp = victim.max_hp
	battle_2.use_skill(caster, _spell(StringName(), [&"mod_execute"]), victim)
	var execute_high := victim.max_hp - victim.hp
	_check(execute_low > execute_high,
		"Hinrichtung: mehr Schaden unter 30%% HP (%d > %d)" % [execute_low, execute_high])

	# Überladung: mehr Schaden, mehr Kosten.
	var plain := _spell(StringName())
	var overloaded := _spell(StringName(), [&"mod_overload"])
	_check(overloaded.get_mp_cost(caster) > plain.get_mp_cost(caster),
		"Überladung erhöht die MP-Kosten")
