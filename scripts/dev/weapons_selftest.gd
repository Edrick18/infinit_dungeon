extends SceneTree
## Headless-Selbsttest für Schadensarten, Rüstungstypen, Zweihänder und
## Support-Magie (Buffs, Reinigen, Schutzwall):
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/weapons_selftest.gd

var failures := 0


func _init() -> void:
	_test_weapon_profiles()
	_test_two_handed()
	_test_armor_classes()
	_test_support_blocks()
	_test_protection()
	_test_revive_and_costs()
	if failures == 0:
		print("SELFTEST OK — alle Waffen-/Support-Tests bestanden")
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


func _fighter(name := "Test", strength := 5, is_player := true) -> Combatant:
	var stats := StatBlock.new()
	stats.strength = strength
	stats.vitality = 10
	stats.spirit = 5
	return Combatant.create(name, stats, is_player)


func _battle() -> Battle:
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = 1
	return battle


func _item(id: StringName) -> ItemInstance:
	var instance := ItemInstance.new()
	for base in ItemLibrary.bases_for_tier(99):
		if base.id == id:
			instance.base = base
			return instance
	assert(false, "Basis-Item nicht gefunden: %s" % id)
	return null


func _test_weapon_profiles() -> void:
	print("Waffen-Schadensprofile:")
	var S := Enums.PhysicalSubtype
	var expected := {
		&"kurzschwert": [S.PIERCE, S.SLASH],
		&"zweihandschwert": [S.PIERCE, S.SLASH],
		&"bogen": [S.PIERCE],
		&"dolch": [S.PIERCE],
		&"axt": [S.SLASH],
		&"zweihandaxt": [S.SLASH],
		&"knueppel": [S.BLUNT],
		&"kriegshammer": [S.BLUNT],
		&"streitkolben": [S.BLUNT],
	}
	var all_ok := true
	for id in expected:
		var item := _item(id)
		if Array(item.base.weapon_subtypes) != expected[id]:
			all_ok = false
			printerr("    Profil falsch: %s" % id)
	_check(all_ok, "Schwert=Stich+Schnitt, Bogen/Dolch=Stich, Axt=Schnitt, Knüppel/Hammer=Stumpf")

	var hero := _fighter()
	var unarmed := hero.weapon_subtypes()
	_check(unarmed.size() == 1 and unarmed[0] == Enums.PhysicalSubtype.BLUNT,
		"unbewaffnet = Stumpf (Faust)")


func _test_two_handed() -> void:
	print("Einhand/Zweihand:")
	_check(not _item(&"kurzschwert").base.two_handed, "Kurzschwert ist einhändig")
	_check(_item(&"zweihandschwert").base.two_handed, "Zweihandschwert ist zweihändig")
	_check(_item(&"bogen").base.two_handed, "Bogen ist zweihändig")

	var hero := _fighter()
	hero.equip(_item(&"kurzschwert"))
	hero.equip(_item(&"holzschild"))
	var displaced := hero.equip(_item(&"zweihandschwert"))
	_check(displaced.size() == 2, "Zweihänder verdrängt Waffe UND Schild")
	_check(not hero.equipment.has(Enums.EquipSlot.OFF_HAND), "Nebenhand ist blockiert")

	var displaced_2h := hero.equip(_item(&"holzschild"))
	_check(displaced_2h.size() == 1 and displaced_2h[0].base.id == &"zweihandschwert",
		"Schild anlegen verdrängt den Zweihänder")


func _test_armor_classes() -> void:
	print("Rüstungstypen vs. Schadensarten:")
	var target := _fighter("Ziel", 5, false)
	target.equip(_item(&"plattenpanzer"))  # 6 Rüstung, Platte

	var slash_armor := target.armor_against(Enums.PhysicalSubtype.SLASH)
	var pierce_armor := target.armor_against(Enums.PhysicalSubtype.PIERCE)
	var blunt_armor := target.armor_against(Enums.PhysicalSubtype.BLUNT)
	_check(slash_armor == 9, "Platte vs. Schnitt: 6 × 1,5 = 9")
	_check(pierce_armor == 8, "Platte vs. Stich: 6 × 1,25 = 8 (gerundet)")
	_check(blunt_armor == 3, "Platte vs. Stumpf: 6 × 0,5 = 3 — Hämmer knacken Platte")

	# Im Kampf: Hammer trifft Plattenträger härter als Axt.
	var battle := _battle()
	var axeman := _fighter("Axt", 5)
	axeman.equip(_item(&"axt"))          # 8 Schaden, Schnitt
	var hammerman := _fighter("Hammer", 5)
	hammerman.equip(_item(&"knueppel"))  # 5 Schaden, Stumpf (weniger Basis!)
	battle.start([axeman, hammerman], [target])
	target.hp = target.max_hp
	battle.basic_attack(axeman, target)
	var axe_damage := target.max_hp - target.hp
	target.hp = target.max_hp
	battle.basic_attack(hammerman, target)
	var hammer_damage := target.max_hp - target.hp
	_check(hammer_damage > axe_damage,
		"Knüppel (%d) schlägt Axt (%d) gegen Platte trotz weniger Waffenschaden"
		% [hammer_damage, axe_damage])


func _test_support_blocks() -> void:
	print("Support-Magie:")
	var battle := _battle()
	var support := _fighter("Support")
	var ally := _fighter("Verbündeter")
	var enemy := _fighter("Gegner", 10, false)
	battle.start([support, ally], [enemy])
	support.mp = 999  # der Test wirkt viele Zauber; MP soll nicht limitieren

	# Stärken (+25% Schaden): Aura auf die Party.
	var atk_up := _skill([_b(&"src_spell"), _b(&"form_aura"), _b(&"eff_atk_up")])
	battle.use_skill(support, atk_up, null)
	_check(ally.has_status(Enums.Status.ATK_UP), "Stärken liegt auf der Party")
	var hp_before := enemy.hp
	battle.basic_attack(ally, enemy)
	_check(hp_before - enemy.hp == 13, "gebuffter Angriff: (5+5) × 1,25 = 13 (statt 10)")

	# Wappnen (+5 Rüstung flach).
	var def_up := _skill([_b(&"src_spell"), _b(&"form_aura"), _b(&"eff_def_up")])
	battle.use_skill(support, def_up, null)
	_check(ally.armor_against(Enums.PhysicalSubtype.SLASH) == 5,
		"Wappnen: +5 Rüstung gegen alles")

	# Mana-Fluss: +6 MP am Zugbeginn.
	var mana_regen := _skill([_b(&"src_spell"), _b(&"form_aura"), _b(&"eff_mana_regen")])
	battle.use_skill(support, mana_regen, null)
	ally.mp = 0
	while battle.next_turn() != ally:
		pass
	_check(ally.mp == 6, "Mana-Fluss regeneriert 6 MP am Zugbeginn")

	# Reinigen: entfernt alle Leiden, ohne Buffs anzutasten.
	ally.add_status(Enums.Status.BURN, 3, 4)
	ally.add_status(Enums.Status.SLOW, 2, 30)
	var cleanse := _skill([_b(&"src_spell"), _b(&"form_aura"), _b(&"eff_cleanse")])
	battle.use_skill(support, cleanse, null)
	_check(not ally.has_status(Enums.Status.BURN) and not ally.has_status(Enums.Status.SLOW),
		"Reinigen entfernt Brand und Verlangsamung")
	_check(ally.has_status(Enums.Status.ATK_UP), "Buffs bleiben beim Reinigen erhalten")


func _test_protection() -> void:
	print("Schutzwall (Beschützer):")
	var battle := _battle()
	var tank := _fighter("Tank")
	var squishy := _fighter("Magierin")
	var enemy := _fighter("Gegner", 10, false)
	battle.start([tank, squishy], [enemy])

	# Schutzwall auf sich selbst (Selbst-Träger).
	var protect := _skill([_b(&"src_spell"), _b(&"form_self"), _b(&"eff_protect")])
	battle.use_skill(tank, protect, null)
	_check(tank.has_status(Enums.Status.PROTECT), "Schutzwall liegt nur auf dem Anwender")
	_check(not squishy.has_status(Enums.Status.PROTECT), "… nicht auf der Party")

	var tank_hp := tank.hp
	var squishy_hp := squishy.hp
	battle.basic_attack(enemy, squishy)
	_check(squishy.hp == squishy_hp and tank.hp < tank_hp,
		"Angriff auf die Magierin trifft stattdessen den Tank")

	# Flächenangriffe werden AUCH abgefangen: Der Beschützer frisst jeden
	# Treffer, der ein Teammitglied treffen würde — und kann daran sterben.
	var aoe := _skill([_b(&"src_spell"), _b(&"form_aoe")])
	enemy.stats.intelligence = 5
	enemy.innate_spell_damage = 20
	tank.hp = tank.max_hp
	var single_hit_hp := tank.hp
	battle.use_skill(enemy, aoe, null)
	var aoe_damage := single_hit_hp - tank.hp
	_check(squishy.hp == squishy_hp, "Team bleibt bei Flächenangriff verschont")
	_check(aoe_damage >= 15, "Tank frisst beide Flächen-Treffer (%d Schaden)" % aoe_damage)


func _test_revive_and_costs() -> void:
	print("Wiederbeleben & skalierende Mana-Kosten:")
	var battle := _battle()
	var healer := _fighter("Heiler")
	var fallen := _fighter("Gefallener")
	var enemy := _fighter("Gegner", 5, false)
	battle.start([healer, fallen], [enemy])

	fallen.hp = 0
	var revive := _skill([_b(&"src_spell"), _b(&"form_aura"), _b(&"eff_revive")])
	_check(battle.use_skill(healer, revive, null), "Wiederbelebungs-Skill wird gewirkt")
	_check(fallen.is_alive() and fallen.hp == roundi(fallen.max_hp * 0.4),
		"Gefallener kehrt mit 40% HP zurück")

	# Mana-Kosten wachsen mit dem Stat, der den Skill stark macht:
	# starke Spells bleiben teuer, egal wie hoch das Level ist.
	var bolt := _skill([_b(&"src_spell")])
	var novice := _fighter("Novize")
	novice.stats.intelligence = 5
	var archmage := _fighter("Erzmagier")
	archmage.stats.intelligence = 100
	var novice_cost := bolt.get_mp_cost(novice)
	var archmage_cost := bolt.get_mp_cost(archmage)
	_check(archmage_cost > novice_cost * 4,
		"Erzmagier zahlt deutlich mehr: %d MP vs. %d MP" % [archmage_cost, novice_cost])
	_check(bolt.get_mp_cost() == 3, "ohne Anwender: statische Basiskosten (Werkstatt-Anzeige)")


static func _skill(blocks: Array) -> Skill:
	var skill := Skill.new()
	skill.display_name = "Testskill"
	for block in blocks:
		skill.blocks.append(block)
	return skill


static func _b(id: StringName) -> SkillBlock:
	return BlockLibrary.get_block(id)
