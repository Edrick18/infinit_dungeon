extends SceneTree
## Headless-Selbsttest für Progression (XP/Level-Ups) und Kampftiefe
## (Verteidigen, Attrition):
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/progression_selftest.gd

var failures := 0


func _init() -> void:
	_test_xp_and_levelup()
	_test_guard()
	_test_attrition()
	_test_turn_preview()
	if failures == 0:
		print("SELFTEST OK — alle Progressions-Tests bestanden")
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


func _hero(agility := 5) -> Combatant:
	var stats := StatBlock.new()
	stats.strength = 5
	stats.vitality = 5
	stats.agility = agility
	return Combatant.create("Held", stats, true)


func _test_xp_and_levelup() -> void:
	print("XP & Level-Up (Statuspunkte, kein Cap):")
	var hero := _hero()
	# Level 1 → 2 braucht 40 XP (25 + 1×15).
	_check(hero.xp_to_next() == 40, "XP-Kurve: Level 1 → 2 kostet 40 XP")
	var str_before := hero.stats.strength
	_check(hero.gain_xp(39) == 0 and hero.level == 1, "39 XP: noch kein Level-Up")
	_check(hero.gain_xp(1) == 1 and hero.level == 2, "40. XP löst Level-Up aus")
	_check(hero.stats.strength == str_before, "Stats steigen NICHT automatisch")
	_check(hero.stat_points == Combatant.POINTS_PER_LEVEL,
		"+%d frei verteilbare Statuspunkte" % Combatant.POINTS_PER_LEVEL)
	_check(hero.hp == hero.max_hp, "Level-Up heilt voll")

	var hp_before := hero.max_hp
	_check(hero.spend_stat_point(&"vitality"), "Punkt in VIT investieren")
	_check(hero.max_hp == hp_before + Combatant.HP_PER_VIT,
		"Max-HP steigt sofort mit dem VIT-Punkt")
	_check(hero.stat_points == Combatant.POINTS_PER_LEVEL - 1, "Punkt wurde abgezogen")
	hero.stat_points = 0
	_check(not hero.spend_stat_point(&"strength"), "ohne Punkte kein Verteilen")

	var big := _hero()
	var gained := big.gain_xp(100000)
	_check(gained >= 20, "kein Level-Cap: riesiger XP-Batzen → %d Level-Ups" % gained)
	_check(big.stat_points == gained * Combatant.POINTS_PER_LEVEL,
		"Punkte für jedes Level gutgeschrieben")

	var slots_hero := _hero()
	slots_hero.level = 4
	_check(slots_hero.skill_slots() == 1, "Level 4: 1 Skill-Slot")
	slots_hero.gain_xp(slots_hero.xp_to_next())
	_check(slots_hero.level == 5 and slots_hero.skill_slots() == 2,
		"Level 5 durch XP → 2. Skill-Slot")

	var enemy := Combatant.create("Gegner", StatBlock.new(), false)
	_check(enemy.gain_xp(1000) == 0 and enemy.level == 1, "Gegner leveln nicht")

	# Alle 4 Helden starten identisch: Level 1, 5 auf jedem Wert.
	var party := TestContent.make_party()
	_check(party.size() == 4, "Party hat 4 Helden")
	var identical := true
	for member in party:
		if member.level != 1:
			identical = false
		for stat in StatBlock.STAT_NAMES:
			if member.stats.get(stat) != 5:
				identical = false
	_check(identical, "alle Helden starten identisch (Level 1, überall 5)")


func _test_guard() -> void:
	print("Verteidigen:")
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = 1
	var attacker := _hero(9)
	var defender := Combatant.create("Verteidiger", StatBlock.new(), false)
	battle.start([attacker], [defender])

	var hp_before := defender.hp
	battle.basic_attack(attacker, defender)
	var normal_damage := hp_before - defender.hp
	_check(normal_damage == 10, "ohne Guard: 5 + 5 STR = 10 Schaden")

	battle.defend(defender)
	hp_before = defender.hp
	battle.basic_attack(attacker, defender)
	_check(hp_before - defender.hp == 5, "mit Guard: Schaden halbiert (10 → 5)")

	# Guard läuft am eigenen nächsten Zugbeginn ab.
	battle.start([attacker], [defender])
	defender.hp = defender.max_hp
	battle.defend(defender)
	battle.next_turn()  # attacker (AGI 9)
	battle.next_turn()  # defender: Guard tickt ab
	_check(not defender.has_status(Enums.Status.GUARD), "Guard nach eigenem Zug abgelaufen")


func _test_attrition() -> void:
	print("Attrition:")
	var hero := _hero()
	hero.hp = 10
	hero.mp = 3
	hero.add_status(Enums.Status.BURN, 2, 3)
	hero.reset_for_battle(false)
	_check(hero.hp == 10 and hero.mp == 3, "reset ohne Heilung: HP/MP bleiben")
	_check(hero.statuses.is_empty(), "Statuseffekte trotzdem entfernt")
	hero.reset_for_battle(true)
	_check(hero.hp == hero.max_hp and hero.mp == hero.max_mp, "voller Reset heilt (Hub)")


func _test_turn_preview() -> void:
	print("Zugreihenfolge-Vorschau:")
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = 1
	var fast := _hero(9)
	fast.display_name = "Schnell"
	var slow := Combatant.create("Langsam", StatBlock.new(), false)
	battle.start([fast], [slow])
	battle.next_turn()  # Schnell ist dran, Rest der Runde: Langsam
	var preview := battle.get_turn_preview()
	_check(preview.size() == 1 and preview[0] == "Langsam",
		"Vorschau zeigt verbleibende Kämpfer der Runde")
