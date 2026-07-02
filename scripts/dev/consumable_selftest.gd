extends SceneTree
## Headless-Selbsttest für Verbrauchsgegenstände:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/consumable_selftest.gd

var failures := 0


func _init() -> void:
	_test_library()
	_test_effects()
	_test_stock()
	_test_battle_loot_consumables()
	if failures == 0:
		print("SELFTEST OK — alle Consumable-Tests bestanden")
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


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _fighter(hp_stat := 5) -> Combatant:
	var stats := StatBlock.new()
	stats.vitality = hp_stat
	stats.spirit = 4
	return Combatant.create("Test", stats, true)


func _test_library() -> void:
	print("Katalog:")
	_check(ConsumableLibrary.all_defs().size() >= 6, "mindestens 6 Consumables")
	_check(ConsumableLibrary.get_def(&"heiltrank") != null, "Zugriff per ID")
	var tier1_ok := true
	for i in 100:
		var def := ConsumableLibrary.roll(1, _rng(i))
		if def == null or def.min_tier > 1:
			tier1_ok = false
	_check(tier1_ok, "Tier-1-Rolls respektieren min_tier (kein Belebungselixier)")
	var high_found := false
	for i in 100:
		if ConsumableLibrary.roll(4, _rng(i)).min_tier >= 3:
			high_found = true
	_check(high_found, "höhere Stufen droppen auch große Tränke")


func _test_effects() -> void:
	print("Effekte im Kampf:")
	var battle := Battle.new()
	battle.crit_enabled = false
	var actor := _fighter()
	var target := _fighter()
	battle.start([actor, target], [_fighter()])

	target.hp = 10
	var heal := ConsumableLibrary.get_def(&"heiltrank")
	_check(battle.use_consumable(actor, heal, target) and target.hp == 40,
		"Heiltrank: 10 → 40 HP")

	target.mp = 0
	var mana := ConsumableLibrary.get_def(&"manatrank")
	_check(battle.use_consumable(actor, mana, target) and target.mp == 20,
		"Manatrank: 0 → 20 MP")

	target.add_status(Enums.Status.BURN, 3, 5)
	target.add_status(Enums.Status.SHIELD, 3, 10)
	var cure := ConsumableLibrary.get_def(&"gegenmittel")
	battle.use_consumable(actor, cure, target)
	_check(not target.has_status(Enums.Status.BURN), "Gegenmittel entfernt Brand")
	_check(target.has_status(Enums.Status.SHIELD), "positive Effekte (Schild) bleiben")

	target.hp = 0
	var revive := ConsumableLibrary.get_def(&"belebungselixier")
	_check(not battle.use_consumable(actor, heal, target), "Heiltrank auf Gefallene: ungültig")
	_check(battle.use_consumable(actor, revive, target) and target.hp == target.max_hp / 2,
		"Belebungselixier: 50% Max-HP")
	_check(not battle.use_consumable(actor, revive, target), "Revive auf Lebende: ungültig")


func _test_stock() -> void:
	print("Bestandsverwaltung:")
	var state: Node = load("res://autoload/game_state.gd").new()
	state.add_consumable(&"heiltrank", 2)
	_check(state.consumable_count(&"heiltrank") == 2, "add_consumable stapelt")
	_check(state.consume(&"heiltrank") and state.consumable_count(&"heiltrank") == 1,
		"consume reduziert")
	state.consume(&"heiltrank")
	_check(not state.consume(&"heiltrank"), "consume bei 0 schlägt fehl")
	_check(not state.consumables.has(&"heiltrank"), "leere Stacks werden entfernt")
	state.free()


func _test_battle_loot_consumables() -> void:
	print("Drops:")
	var enemy := _fighter()
	var found := false
	for i in 40:
		var loot := LootGenerator.roll_battle_loot([enemy], 1, false, _rng(i))
		if not loot["consumables"].is_empty():
			found = true
	_check(found, "Consumables droppen aus normalen Kämpfen")
	var boss_loot := LootGenerator.roll_battle_loot([enemy], 1, true, _rng(1))
	_check(boss_loot["consumables"].size() >= 1, "Boss droppt garantiert einen Trank")
