extends SceneTree
## Headless-Selbsttest fürs Datenmodell:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/data_selftest.gd
## Baut je ein Beispiel jeder Kern-Resource und prüft die Rechenlogik.

var failures := 0


func _init() -> void:
	_test_stat_block()
	_test_skill()
	_test_item()
	_test_character()
	_test_dungeon_card()
	if failures == 0:
		print("SELFTEST OK — alle Datenmodell-Tests bestanden")
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


func _test_stat_block() -> void:
	print("StatBlock:")
	var a := StatBlock.new()
	a.strength = 5
	a.vitality = 10
	var b := StatBlock.new()
	b.strength = 3
	a.add(b)
	_check(a.strength == 8 and a.vitality == 10, "add() addiert korrekt")
	var c := StatBlock.new()
	c.agility = 2
	a.add_scaled(c, 4)
	_check(a.agility == 8, "add_scaled() multipliziert korrekt")


func _test_skill() -> void:
	print("Skill (Bauklötze):")
	var slash := DamageBlock.new()
	slash.axis = Enums.DamageAxis.PHYSICAL
	slash.base_amount = 12
	slash.mp_cost = 4

	var burn := DamageBlock.new()
	burn.axis = Enums.DamageAxis.ELEMENTAL
	burn.element = Enums.Element.FIRE
	burn.base_amount = 6
	burn.dot_turns = 3
	burn.mp_cost = 6

	var melee := CarrierBlock.new()
	melee.carrier = Enums.Carrier.MELEE
	melee.cost_multiplier = 1.0

	var skill := Skill.new()
	skill.display_name = "Flammenhieb"
	skill.blocks = [slash, burn, melee]

	_check(skill.is_valid(), "Skill mit 1 Träger + Schaden ist gültig")
	_check(skill.get_damage_blocks().size() == 2, "zwei Schadensachsen kombiniert")
	_check(skill.get_mp_cost() == 10, "MP-Kosten: 4+6 × 1.0 = 10")

	var cheaper := ModifierBlock.new()
	cheaper.modifier = Enums.SkillModifier.COST_REDUCTION
	cheaper.magnitude = 50
	skill.blocks.append(cheaper)
	_check(skill.get_mp_cost() == 5, "COST_REDUCTION 50%: 10 → 5")

	var invalid := Skill.new()
	invalid.blocks = [slash]
	_check(not invalid.is_valid(), "Skill ohne Träger ist ungültig")


func _test_item() -> void:
	print("Item (Basis + Affixe):")
	var sword := ItemBase.new()
	sword.display_name = "Kurzschwert"
	sword.slot = Enums.EquipSlot.WEAPON
	sword.base_damage = 8

	var flaming := Affix.new()
	flaming.is_prefix = true
	flaming.name_part = "Flammendes"
	flaming.bonus_damage = 4

	var of_storm := Affix.new()
	of_storm.is_prefix = false
	of_storm.name_part = "des Sturms"
	of_storm.stat_bonus = StatBlock.new()
	of_storm.stat_bonus.agility = 3

	var item := ItemInstance.new()
	item.base = sword
	item.affixes = [flaming, of_storm]

	_check(item.get_display_name() == "Flammendes Kurzschwert des Sturms",
		"Namensbildung Prefix + Basis + Suffix")
	_check(item.get_total_damage() == 12, "Schaden: 8 Basis + 4 Affix = 12")
	_check(item.get_total_stat_bonus().agility == 3, "Stat-Boni aus Affixen summiert")


func _test_character() -> void:
	print("CharacterDef:")
	var hero := CharacterDef.new()
	hero.base_stats = StatBlock.new()
	hero.base_stats.strength = 5
	hero.growth_per_level = StatBlock.new()
	hero.growth_per_level.strength = 2

	_check(hero.stats_at_level(1).strength == 5, "Level 1 = Basiswerte")
	_check(hero.stats_at_level(10).strength == 23, "Level 10: 5 + 9×2 = 23")
	_check(CharacterDef.skill_slots_for_level(1) == 1, "Level 1: 1 Skill-Slot")
	_check(CharacterDef.skill_slots_for_level(5) == 2, "Level 5: 2 Slots")
	_check(CharacterDef.skill_slots_for_level(23) == 5, "Level 23: 5 Slots")


func _test_dungeon_card() -> void:
	print("DungeonCard:")
	var card := DungeonCard.new()
	card.display_name = "Verwitterte Waldkarte"
	card.seed = 123456
	card.tier = 4
	card.modifier_ids = [&"burning", &"armored"]
	_check(card.modifier_ids.size() == 2, "Modifikatoren fix auf der Karte gespeichert")
