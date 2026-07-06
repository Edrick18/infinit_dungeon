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
	# Level 1 » 2 braucht 63 XP (40 + 20×1 + 3×1²) — quadratische DQ-Kurve.
	_check(hero.xp_to_next() == 63, "XP-Kurve: Level 1 » 2 kostet 63 XP")
	var str_before := hero.stats.strength
	_check(hero.gain_xp(62) == 0 and hero.level == 1, "62 XP: noch kein Level-Up")
	_check(hero.gain_xp(1) == 1 and hero.level == 2, "63. XP löst Level-Up aus")
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
	_check(gained >= 20, "kein Level-Cap: riesiger XP-Batzen » %d Level-Ups" % gained)
	_check(big.stat_points == gained * Combatant.POINTS_PER_LEVEL,
		"Punkte für jedes Level gutgeschrieben")

	var slots_hero := _hero()
	slots_hero.level = 4
	_check(slots_hero.skill_slots() == 1, "Level 4: 1 Skill-Slot")
	slots_hero.gain_xp(slots_hero.xp_to_next())
	_check(slots_hero.level == 5 and slots_hero.skill_slots() == 2,
		"Level 5 durch XP » 2. Skill-Slot")

	# Quadratische Kurve: Level 50 kostet mehr als 20× Level 1 (Soft-Cap).
	var late := _hero()
	late.level = 50
	_check(late.xp_to_next() > 20 * 63,
		"Kurve wächst überproportional (Level 50 braucht %d XP)" % late.xp_to_next())

	var enemy := Combatant.create("Gegner", StatBlock.new(), false)
	_check(enemy.gain_xp(1000) == 0 and enemy.level == 1, "Gegner leveln nicht")

	# Wiedergeburt: Slots bleiben (peak_level), +10% XP, +1 Statuspunkt/Level.
	var reborn := _hero()
	reborn.level = Combatant.REBIRTH_LEVEL
	reborn.peak_level = Combatant.REBIRTH_LEVEL
	var slots_before_rebirth := reborn.skill_slots()
	_check(reborn.rebirth() and reborn.level == 1, "Wiedergeburt setzt auf Level 1")
	_check(reborn.skill_slots() == slots_before_rebirth,
		"Skill-Slots bleiben nach der Wiedergeburt (Lebenszeit-Maximum)")
	_check(reborn.stat_points_per_level() == Combatant.POINTS_PER_LEVEL + 1,
		"+1 Statuspunkt pro Level je Wiedergeburt")
	reborn.gain_xp(reborn.xp_to_next())  # intern +10% » Level-Up sicher
	_check(reborn.level >= 2 and reborn.stat_points >= Combatant.POINTS_PER_LEVEL + 1,
		"Level-Up nach Wiedergeburt schreibt Bonus-Punkte gut")

	# Glück: abnehmender Ertrag statt 100%-Krit bei 95 Punkten.
	_check(Combatant.luck_crit_bonus(95) < 45 and Combatant.luck_crit_bonus(1000) < 45,
		"Glück-Kritbonus bleibt unter der 45%%-Asymptote (95 » +%d%%)"
		% Combatant.luck_crit_bonus(95))
	_check(Combatant.luck_crit_bonus(60) > Combatant.luck_crit_bonus(30),
		"mehr Glück bleibt trotzdem besser")

	# Umskillen: verteilte Punkte kommen vollständig zurück, Basis 5.
	var respecced := _hero()
	for stat in StatBlock.STAT_NAMES:
		respecced.stats.set(stat, 5)  # Helden-Basis (echte Helden starten so)
	respecced.stat_points = 10
	respecced.spend_stat_point(&"strength")
	respecced.spend_stat_point(&"strength")
	respecced.spend_stat_point(&"luck")
	_check(respecced.respec() == 3 and respecced.stat_points == 10,
		"Respec erstattet alle 3 Punkte")
	_check(respecced.stats.strength == 5 and respecced.stats.luck == 5,
		"Attribute zurück auf Basis 5")

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
	_check(hp_before - defender.hp == 5, "mit Guard: Schaden halbiert (10 » 5)")

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
	_check(preview.size() >= 2 and preview[0] == "Langsam" and preview[1] == "Schnell",
		"Vorschau: Rest der Runde, dann die Folgerunde (nach Tempo sortiert)")
