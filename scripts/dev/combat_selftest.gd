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
	_test_weapon_techniques()
	_test_weapon_training()
	_test_weapon_element()
	_test_training_passives_and_rebirth()
	_test_weapon_sets()
	_test_new_ingredients()
	_test_flee()
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


func _block(id: StringName) -> SkillBlock:
	return BlockLibrary.get_block(id)


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
	print("Zauber (waffengetrieben): roher Magieschaden + Feuer-DoT:")
	var battle := _make_battle()
	var caster := _fighter("Magier", 5, true)
	caster.stats.intelligence = 5
	caster.innate_spell_damage = 10  # ohne Waffe: innewohnender Zauberschaden
	var target := _fighter("Ziel", 3, false)
	target.magic_resist = 3

	# Roher Zauber (ohne Element) = direkter Magieschaden.
	var bolt := Skill.new()
	bolt.blocks = [_block(&"src_spell")]
	battle.start([caster], [target])
	var hp_before := target.hp
	_check(battle.use_skill(caster, bolt, target), "Zauber wird ausgeführt")
	_check(hp_before - target.hp == 12, "Magieschaden: 10 Zauber + 5 INT - 3 Resist = 12")

	# Feuer-Zauber = Brand-Stacks (aufbauend, halbieren sich pro Tick).
	target.hp = target.max_hp
	var fire := Skill.new()
	fire.blocks = [_block(&"src_spell"), _block(&"elem_fire")]
	_check(battle.use_skill(caster, fire, target), "Feuer-Zauber wird ausgeführt")
	var dot := target.get_status(Enums.Status.BURN)
	_check(not dot.is_empty() and int(dot["potency"]) >= 1,
		"Feuer legt Brand-Stacks aus dem Zauberschaden an")
	var stacks_before: int = dot["potency"]
	battle.use_skill(caster, fire, target)
	_check(int(target.get_status(Enums.Status.BURN)["potency"]) > stacks_before,
		"zweiter Treffer ADDIERT Brand-Stacks")


func _test_dot_tick_and_expiry() -> void:
	print("Brand-Stacks: ticken, halbieren sich, klingen ab:")
	var battle := _make_battle()
	var victim := _fighter("Opfer", 9, false)
	var other := _fighter("Anderer", 1, true)
	victim.add_status(Enums.Status.BURN, -1, 4)  # 4 Brand-Stacks
	battle.start([other], [victim])
	var hp_before := victim.hp
	_check(battle.next_turn() == victim, "Opfer ist zuerst dran (AGI 9)")
	_check(hp_before - victim.hp == 4, "Tick 1: 4 Schaden (= Stacks)")
	_check(int(victim.get_status(Enums.Status.BURN)["potency"]) == 2,
		"Stacks nach Tick halbiert: 4 » 2")
	battle.next_turn()  # other
	battle.next_turn()  # victim: Tick 2 (2 Schaden, Stacks 2 » 1)
	_check(hp_before - victim.hp == 6, "Tick 2: +2 Schaden (insgesamt 6)")
	battle.next_turn()  # other
	battle.next_turn()  # victim: Tick 3 (1 Schaden, Stacks 1 » 0 » weg)
	_check(hp_before - victim.hp == 7, "Tick 3: +1 Schaden (insgesamt 7)")
	_check(not victim.has_status(Enums.Status.BURN), "Brand nach dem Abklingen der Stacks weg")


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

	caster.innate_spell_damage = 12
	var skill := Skill.new()
	skill.blocks = [_block(&"src_spell"), _block(&"form_aoe")]

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
	var skill := Skill.new()
	skill.blocks = [_block(&"src_spell"), _block(&"form_aura"), regen]

	battle.start([healer, ally], [enemy])
	battle.use_skill(healer, skill, null)
	_check(ally.has_status(Enums.Status.REGEN) and healer.has_status(Enums.Status.REGEN),
		"Aura liegt auf der ganzen Party")
	battle.next_turn()  # ally (AGI 8) » Regen-Tick
	var prozent := roundi(5 * Battle.geist_prozent_faktor(healer))
	var regen_tick := maxi(1, roundi(ally.max_hp * prozent / 100.0))
	_check(ally.hp == 10 + regen_tick and prozent >= 5,
		"Verbündeter regeneriert %d %% der Max-HP = %d HP am Zugbeginn" % [prozent, regen_tick])


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

func _test_weapon_techniques() -> void:
	print("Waffentechniken (gattungs-gebundene Bausteine, DQ-Stil):")
	var falkenschlag := Skill.new()
	falkenschlag.display_name = "Doppelhieb"
	falkenschlag.blocks.append(_block(&"src_weapon"))
	falkenschlag.blocks.append(_block(&"tech_duellstoss"))
	_check(falkenschlag.is_valid(), "Waffennutzung + Technik ist ein gültiger Skill")
	_check(falkenschlag.has_technique() and &"schwert" in falkenschlag.required_weapon_families(),
		"Duellstoß verlangt die Schwert-Gattung")

	var swordsman := HeroLibrary.create_hero("Klingenhand", &"schwert_schild")
	var rogue := HeroLibrary.create_hero("Schleicher", &"dolche")
	_check(falkenschlag.usable_with_weapon(swordsman),
		"mit Schwert ist die Technik einsetzbar")
	_check(not falkenschlag.usable_with_weapon(rogue),
		"mit Dolchen ist die Schwert-Technik gesperrt")

	# Kampf-Guard: der Skill wird ohne passende Waffe abgewiesen (kein MP-Verlust).
	var battle := _make_battle()
	var foe := _fighter("Übungspuppe", 3, false)
	battle.start([rogue] as Array[Combatant], [foe] as Array[Combatant])
	rogue.reset_for_battle(true)
	var mp_before := rogue.mp
	_check(not battle.use_skill(rogue, falkenschlag, foe),
		"use_skill weist die Technik ohne passende Waffe ab")
	_check(rogue.mp == mp_before, "die Abweisung kostet keine MP")

	# Widersprüchliche Techniken (Schwert vs. Bogen) machen den Skill ungültig.
	var unsinn := Skill.new()
	unsinn.blocks.append(_block(&"src_weapon"))
	unsinn.blocks.append(_block(&"tech_duellstoss"))
	unsinn.blocks.append(_block(&"tech_zielen"))
	_check(not unsinn.is_valid(), "Schwert-Technik + Bogen-Technik = ungültig")

	# Stab-Techniken verstärken auch ZAUBER (Quelle egal, Gattung zählt).
	var zaubertrick := Skill.new()
	zaubertrick.blocks.append(_block(&"src_spell"))
	zaubertrick.blocks.append(_block(&"tech_echo"))
	_check(zaubertrick.is_valid(), "Zauber + Stab-Technik ist gültig")
	var mage := HeroLibrary.create_hero("Stabschwinger", &"feuerstab")
	_check(zaubertrick.usable_with_weapon(mage), "mit Stab einsetzbar")
	_check(not zaubertrick.usable_with_weapon(rogue), "ohne Stab gesperrt")

	# Schild-Techniken zählen über die NEBENHAND.
	var schildstoss := Skill.new()
	schildstoss.blocks.append(_block(&"src_weapon"))
	schildstoss.blocks.append(_block(&"tech_sh_stun2"))
	_check(schildstoss.usable_with_weapon(swordsman),
		"Schild-Technik zählt über die Nebenhand (Schwert & Schild)")
	_check(not schildstoss.usable_with_weapon(rogue), "ohne Schild gesperrt")


func _test_flee() -> void:
	print("Fliehen (nie bei Bossen, Geschick entscheidet):")
	var runner := _fighter("Hasenfuß", 30, true)  # riesiger Geschick-Vorsprung
	var slowpoke := _fighter("Schnecke", 1, false)
	var battle := _make_battle()
	battle.start([runner] as Array[Combatant], [slowpoke] as Array[Combatant])
	var fled := {"done": false}
	battle.battle_fled.connect(func() -> void: fled["done"] = true)
	# Chance ist auf 95% gedeckelt — ein paar Versuche erlauben (Fehlversuch
	# verbraucht im echten Spiel den Zug, hier zählt nur die Mechanik).
	var success := false
	for i in 50:
		if battle.attempt_flee(runner):
			success = true
			break
	_check(success and fled["done"] and battle.is_over,
		"Flucht gelingt und beendet den Kampf über battle_fled")

	# Boss-Kampf: Fliehen ist grundsätzlich unmöglich.
	var boss := _fighter("Endgegner", 1, false)
	boss.is_boss = true
	var boss_battle := _make_battle()
	boss_battle.start([runner] as Array[Combatant], [boss] as Array[Combatant])
	var blocked := true
	for i in 20:
		if boss_battle.attempt_flee(runner):
			blocked = false
	_check(blocked and not boss_battle.is_over, "vor Bossen gibt es kein Entkommen")
	_check(boss_battle.has_boss(), "has_boss erkennt den Boss")

func _test_weapon_training() -> void:
	print("Waffen-Training (Skillpunkte, DQ9-Stil):")
	var hero := HeroLibrary.create_hero("Lehrling", &"schwert_schild")
	_check(hero.skill_points == 0, "Level 1 startet ohne Skillpunkte")
	hero.gain_xp(10000)  # einige Level-Ups
	_check(hero.level > 1 and hero.skill_points
		== Combatant.skill_punkte_bis(hero.level),
		"+%d Skillpunkte pro Level-Up" % Combatant.SKILL_POINTS_PER_LEVEL)
	var konter := _block(&"tech_konter")
	_check(not BlockLibrary.is_unlocked(konter, hero.level, [], hero),
		"Waffen-Klotz ohne Training gesperrt (auch auf hohem Level)")
	_check(hero.invest_point(&"schwert", 4), "4 Punkte in Schwert investieren")
	_check(BlockLibrary.is_unlocked(konter, hero.level, [], hero),
		"Schwelle 3 schaltet Klingenwall frei")
	_check(not BlockLibrary.is_unlocked(_block(&"tech_entwaffnen"), hero.level, [], hero),
		"Schwelle 10 (Entwaffnen) bleibt gesperrt")
	_check(not hero.invest_point(&"axt", 9999),
		"mehr investieren als vorhanden geht nicht")
	_check(BlockLibrary.is_unlocked(_block(&"eff_protect"), 1, [&"eff_protect"], hero),
		"früher erforschter Schutzwall bleibt frei (Migration)")
	_check(BlockLibrary.tree_blocks(&"schwert").size() >= 10
		and BlockLibrary.tree_blocks(&"schild").size() >= 7,
		"jeder Baum hat viele Waffen-Klötze (Schwert %d, Schild %d)"
		% [BlockLibrary.tree_blocks(&"schwert").size(), BlockLibrary.tree_blocks(&"schild").size()])

	var restored := Combatant.from_dict(hero.to_dict())
	_check(restored.skill_points == hero.skill_points
		and restored.invested(&"schwert") == 4,
		"Training übersteht den Speicher-Rundweg")
	var old_data := hero.to_dict()
	old_data.erase("skill_points")
	old_data.erase("weapon_invest")
	var migrated := Combatant.from_dict(old_data)
	_check(migrated.skill_points
		== Combatant.skill_punkte_bis(migrated.level),
		"Altbestand bekommt Punkte rückwirkend gutgeschrieben")


func _test_weapon_element() -> void:
	print("Elemente auf Waffenangriffen:")
	var battle := _make_battle()
	var knight := HeroLibrary.create_hero("Flammenritter", &"schwert_schild")
	var foe := _fighter("Ziel", 3, false)
	var flame_slash := Skill.new()
	flame_slash.blocks.append(_block(&"src_weapon"))
	flame_slash.blocks.append(_block(&"elem_fire"))
	_check(flame_slash.is_valid(), "Waffennutzung + Feuer ist ein gültiger Skill")
	battle.start([knight] as Array[Combatant], [foe] as Array[Combatant])
	knight.reset_for_battle(true)
	knight.mp = 99
	battle.use_skill(knight, flame_slash, foe)
	_check(foe.has_status(Enums.Status.BURN),
		"Flammenklinge legt Brand-Stacks an (Element wirkt auf dem Waffenangriff)")


func _test_training_passives_and_rebirth() -> void:
	print("Trainings-Passive + Wiedergeburt (Endlos-Progression):")
	var hero := HeroLibrary.create_hero("Veteran", &"schwert_schild")
	hero.skill_points = 200
	var base_mult := hero.training_weapon_mult()
	_check(is_equal_approx(base_mult, 1.0), "ohne Training kein Schadensbonus")
	hero.invest_point(&"schwert", 7)
	_check(is_equal_approx(hero.training_weapon_mult(), 1.1),
		"Schwelle 7: +10% Waffenschaden mit geführtem Schwert")
	hero.invest_point(&"schwert", 15)  # 22 gesamt
	_check(is_equal_approx(hero.training_weapon_mult(), 1.2),
		"Schwelle 22: +20% gesamt")
	_check(hero.training_crit_bonus() == 5, "Schwelle 14: +5% Kritchance")
	var armor_before := hero.total_armor()
	hero.invest_point(&"schild", 7)
	_check(hero.training_armor_percent() == 5, "Schild-Schwelle 7: +5% Rüstung")
	hero.invest_point(&"schild", 43)  # 50 gesamt » +30%
	_check(hero.training_armor_percent() == 30 and hero.total_armor() > armor_before,
		"Rüstungs-Passive erhöhen die Gesamt-Rüstung prozentual")

	# Passive gelten nur mit passender Waffe in der Hand.
	var dagger_hero := HeroLibrary.create_hero("Falschhand", &"dolche")
	dagger_hero.skill_points = 50
	dagger_hero.invest_point(&"schwert", 22)
	_check(is_equal_approx(dagger_hero.training_weapon_mult(), 1.0),
		"Schwert-Passive wirken NICHT mit Dolchen")

	# Stab: Zauberkraft + MP-Ersparnis.
	var mage := HeroLibrary.create_hero("Weise", &"feuerstab")
	mage.skill_points = 50
	mage.invest_point(&"offensivstab", 14)
	_check(is_equal_approx(mage.training_spell_mult(), 1.1),
		"Offensivstab-Schwelle 7: +10% Zauberkraft")
	_check(mage.training_mp_percent() == 5, "Offensivstab-Schwelle 14: −5% MP-Kosten")

	# Bäume reichen bis 100 (12 Waffen-Klötze + 7 Passive beim Schwert).
	_check(BlockLibrary.tree_blocks(&"schwert").size() == 12
		and BlockLibrary.tree_blocks(&"schwert").back().tree_points == 100,
		"Schwert-Baum hat 12 Waffen-Klötze bis Schwelle 100")
	_check(BlockLibrary.passives_for(&"schwert").size() == 7,
		"7 Passiv-Boni pro Baum")

	# Wiedergeburt: Level zurück, Training bleibt.
	var elder := HeroLibrary.create_hero("Uralt", &"schwert_schild")
	elder.skill_points = 40
	elder.invest_point(&"schwert", 28)
	_check(not elder.can_rebirth(), "unter Level 100 keine Wiedergeburt")
	elder.level = Combatant.REBIRTH_LEVEL
	elder.stats.strength = 90
	_check(elder.can_rebirth() and elder.rebirth(), "ab Level 100 klappt sie")
	_check(elder.level == 1 and elder.stats.strength == 5,
		"Level und Stats sind zurückgesetzt")
	_check(elder.invested(&"schwert") == 28 and elder.skill_points == 12,
		"Waffen-Training und freie Punkte BLEIBEN")
	_check(elder.rebirths == 1, "Wiedergeburts-Zähler zählt")
	_check(elder.skills.size() == 1
		and elder.equipment.has(Enums.EquipSlot.WEAPON),
		"Skills und Ausrüstung bleiben erhalten")
	var reloaded := Combatant.from_dict(elder.to_dict())
	_check(reloaded.rebirths == 1, "Wiedergeburt übersteht den Rundweg")

func _test_weapon_sets() -> void:
	print("Zweites Waffenset (freier Wechsel):")
	var hero := HeroLibrary.create_hero("Wechsler", &"schwert_schild")
	_check(not hero.has_second_weapon_set(), "Set B startet leer")
	hero.swap_weapon_set()  # auf leeres Set B — Hände frei zum Bestücken
	_check(hero.weapon_family() == &"" and hero.active_weapon_set == 1,
		"Wechsel auf leeres Set B entwaffnet (zum Bestücken)")
	hero.equip(ItemLibrary.make_item(&"bogen"))
	hero.equip(ItemLibrary.make_item(&"koecher"))
	hero.swap_weapon_set()
	_check(hero.weapon_family() == &"schwert" and hero.active_weapon_set == 0,
		"zurück auf Set A: Schwert & Schild wieder in der Hand")
	_check(hero.has_second_weapon_set(), "Set B (Bogen & Köcher) ist gemerkt")
	hero.swap_weapon_set()
	_check(hero.weapon_family() == &"bogen"
		and hero.equipment[Enums.EquipSlot.OFF_HAND].base.quiver,
		"Set B: Bogen & Köcher komplett in der Hand")
	var falken := Skill.new()
	falken.blocks.append(_block(&"src_weapon"))
	falken.blocks.append(_block(&"tech_duellstoss"))
	_check(not falken.usable_with_weapon(hero),
		"Schwert-Technik ist mit dem Bogen-Set gesperrt")
	hero.swap_weapon_set()
	_check(falken.usable_with_weapon(hero), "… und mit dem Schwert-Set wieder frei")
	var restored := Combatant.from_dict(hero.to_dict())
	_check(restored.has_second_weapon_set()
		and restored.weapon_set_b[Enums.EquipSlot.WEAPON].base.id == &"bogen",
		"Set B übersteht den Speicher-Rundweg")


func _test_new_ingredients() -> void:
	print("Neue Trainings-Zutaten (Blutung/Konter/Markieren/Riss/Wut/Echo/…):")
	var battle := _make_battle()
	var hero := HeroLibrary.create_hero("Prüfer", &"schwert_schild")
	var foe := _fighter("Ziel", 3, false, 5, 30)
	battle.start([hero] as Array[Combatant], [foe] as Array[Combatant])
	hero.reset_for_battle(true)
	hero.mp = 99

	# Blutung: Stacks aus dem Schaden, ticken wie Gift, kurierbar.
	var bleed_skill := Skill.new()
	bleed_skill.blocks.append(_block(&"src_weapon"))
	bleed_skill.blocks.append(_block(&"tech_blutung"))
	hero.equip(ItemLibrary.make_item(&"dolch"))  # Blutung ist Dolch-gebunden
	battle.use_skill(hero, bleed_skill, foe)
	_check(foe.has_status(Enums.Status.BLEED), "Blutung legt Stacks an")
	_check(Enums.Status.BLEED in Battle.CURABLE_STATUSES, "Blutung ist kurierbar")

	# Markiert: Ziel nimmt von allen mehr Schaden.
	foe.hp = foe.max_hp
	var plain := battle.preview_mitigated(hero, foe, 40.0, Enums.DamageAxis.MAGICAL)
	foe.add_status(Enums.Status.MARKED, 2, 25)
	var marked := battle.preview_mitigated(hero, foe, 40.0, Enums.DamageAxis.MAGICAL)
	_check(marked > plain, "Markiert erhöht den erlittenen Schaden (+25%)")

	# Rüstungsriss: senkt die effektive Rüstung prozentual.
	foe.armor = 20
	var armor_before := foe.total_armor()
	foe.add_status(Enums.Status.ARMOR_BREAK, 2, 40)
	_check(foe.total_armor() < armor_before, "Rüstungsriss senkt die Rüstung")

	# Konter-Haltung: physische Angreifer kassieren zurück.
	hero.add_status(Enums.Status.COUNTER, 2, 60)
	var foe_hp := foe.hp
	battle._deal_damage(foe, hero, 10.0, Enums.DamageAxis.PHYSICAL)
	_check(foe.hp < foe_hp, "Konter-Haltung schlägt zurück")

	# Besonderheiten (Rest siehe skillbau_selftest): Turmschild, Gnade.
	var tower := HeroLibrary.create_hero("Wall", &"schwert_schild")
	tower.equip(ItemLibrary.make_item(&"turmschild"))
	_check(tower.wields_tower_shield() and tower.weapon_damage() > 2,
		"Turmschild: Angriffe nutzen die Rüstung als Waffe")
	var priest := HeroLibrary.create_hero("Gnade", &"heiligstab")
	priest.take_damage(99999)
	_check(priest.hp == 1 and priest.mercy_used,
		"Gnade (Heiligstab): tödlicher Schaden lässt 1 HP übrig")
	priest.take_damage(99999)
	_check(not priest.is_alive(), "… aber nur einmal pro Kampf")

	# Erstschlag: handelt nächste Runde zuerst (trotz weniger Tempo).
	var slow_hero := _fighter("Langsam", 1, true)
	var fast_foe := _fighter("Flink", 20, false)
	var battle2 := _make_battle()
	battle2.start([slow_hero] as Array[Combatant], [fast_foe] as Array[Combatant])
	slow_hero.add_status(Enums.Status.FIRST_STRIKE, 1, 0)
	_check(battle2.next_turn() == slow_hero, "Erstschlag: der Langsame ist zuerst dran")
	_check(not slow_hero.has_status(Enums.Status.FIRST_STRIKE),
		"Erstschlag wird dabei verbraucht")

	# Echo: der Zauber wiederholt sich beim nächsten eigenen Zug.
	var mage := HeroLibrary.create_hero("Hallende", &"feuerstab")
	var dummy := _fighter("Puppe", 1, false, 5, 50)
	var battle3 := _make_battle()
	battle3.start([mage] as Array[Combatant], [dummy] as Array[Combatant])
	mage.reset_for_battle(true)
	mage.mp = 99
	var echo_skill := Skill.new()
	echo_skill.blocks.append(_block(&"src_spell"))
	echo_skill.blocks.append(_block(&"tech_echo"))
	battle3.use_skill(mage, echo_skill, dummy)
	var after_cast := dummy.hp
	battle3.next_turn()  # Puppe (AGI 1) … Reihenfolge egal:
	battle3.next_turn()  # spätestens jetzt war der Magier dran » Echo zündet
	_check(dummy.hp < after_cast, "Echo wiederholt den Zauber automatisch")

	# Überheilung: Überschuss der Heilig-Heilung wird zu Schild-HP.
	var healer := HeroLibrary.create_hero("Barmherz", &"heiligstab")
	var patient := _fighter("Patient", 5, true)
	var battle4 := _make_battle()
	battle4.start([healer, patient] as Array[Combatant],
		[_fighter("Nichts", 1, false)] as Array[Combatant])
	healer.reset_for_battle(true)
	healer.mp = 99
	healer.peak_level = 8  # 4 Klötze brauchen 4 Sockel (ab Level 8)
	patient.hp = patient.max_hp - 1  # fast voll » fette Überheilung
	var overheal := Skill.new()
	overheal.blocks.append(_block(&"src_spell"))
	overheal.blocks.append(_block(&"elem_holy"))
	overheal.blocks.append(_block(&"form_ally"))
	overheal.blocks.append(_block(&"tech_ueberheilung"))
	battle4.use_skill(healer, overheal, patient)
	_check(patient.has_status(Enums.Status.SHIELD),
		"Überheilung: Überschuss wird zu Schild-HP")
