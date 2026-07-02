extends SceneTree
## Headless-Selbsttest für Baustein-Bibliothek und Freischalt-Logik:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/crafting_selftest.gd

var failures := 0


func _init() -> void:
	_test_library_integrity()
	_test_unlock_rules()
	_test_crafted_skill_works_in_battle()
	if failures == 0:
		print("SELFTEST OK — alle Crafting-Tests bestanden")
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


func _test_library_integrity() -> void:
	print("Bibliothek:")
	var blocks := BlockLibrary.all_blocks()
	_check(blocks.size() >= 15, "mindestens 15 Bausteine vorhanden (%d)" % blocks.size())

	var has_damage := false
	var has_carrier := false
	var has_effect := false
	var has_modifier := false
	var all_named := true
	for block in blocks:
		if block is DamageBlock: has_damage = true
		elif block is CarrierBlock: has_carrier = true
		elif block is EffectBlock: has_effect = true
		elif block is ModifierBlock: has_modifier = true
		if block.display_name.is_empty() or block.id == StringName():
			all_named = false
	_check(has_damage and has_carrier and has_effect and has_modifier,
		"alle vier Kategorien vertreten")
	_check(all_named, "alle Bausteine haben ID und Namen")
	_check(BlockLibrary.get_block(&"dmg_schnitt") != null, "Zugriff per ID funktioniert")

	var axes := {}
	for block in blocks:
		if block is DamageBlock:
			axes[block.axis] = true
	_check(axes.size() == 3, "alle drei Schadensachsen craftbar")


func _test_unlock_rules() -> void:
	print("Freischaltung:")
	var level_block := BlockLibrary.get_block(&"dmg_wucht")   # Level 4
	var research_block := BlockLibrary.get_block(&"eff_stun") # Forschung 80 G

	_check(not BlockLibrary.is_unlocked(level_block, 3, []), "Level-Baustein unter Level gesperrt")
	_check(BlockLibrary.is_unlocked(level_block, 4, []), "Level-Baustein ab Level frei")
	_check(not BlockLibrary.is_unlocked(research_block, 99, []),
		"Forschungs-Baustein trotz hohem Level gesperrt")
	_check(BlockLibrary.is_unlocked(research_block, 1, [&"eff_stun"]),
		"Forschungs-Baustein nach Forschung frei")


## Der Kern des Ganzen: ein rein aus Bibliotheks-Bausteinen gebauter Skill
## funktioniert unverändert im Kampfsystem.
func _test_crafted_skill_works_in_battle() -> void:
	print("Gecrafteter Skill im Kampf:")
	var skill := Skill.new()
	skill.display_name = "Werkstatt-Test"
	skill.blocks = [
		BlockLibrary.get_block(&"dmg_arkan"),
		BlockLibrary.get_block(&"dmg_brand"),
		BlockLibrary.get_block(&"car_projectile"),
	]
	_check(skill.is_valid(), "Skill aus Bibliotheks-Bausteinen ist gültig")

	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = 7
	var stats := StatBlock.new()
	stats.intelligence = 5
	stats.spirit = 10
	stats.agility = 5
	var caster := Combatant.create("Crafter", stats, true)
	var target_stats := StatBlock.new()
	target_stats.vitality = 10
	var target := Combatant.create("Ziel", target_stats, false)
	battle.start([caster], [target])

	var hp_before := target.hp
	_check(battle.use_skill(caster, skill, target), "Skill wird im Kampf ausgeführt")
	_check(target.hp < hp_before, "Magieschaden angekommen")
	_check(target.has_status(Enums.Status.BURN), "Brand-DoT aus Baustein angewendet")
