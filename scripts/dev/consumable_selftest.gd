extends SceneTree
## Headless-Selbsttest für Verbrauchsgegenstände, Kaufen & Alchemie:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/consumable_selftest.gd

var failures := 0


func _init() -> void:
	_test_library()
	_test_percent_healing()
	_test_cures()
	_test_shop_and_crafting()
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


func _fighter(vitality: int) -> Combatant:
	var stats := StatBlock.new()
	stats.vitality = vitality
	stats.spirit = 4
	return Combatant.create("Test", stats, true)


func _test_library() -> void:
	print("Katalog:")
	_check(ConsumableLibrary.all_defs().size() >= 11, "mindestens 11 Consumables")
	_check(ConsumableLibrary.buyable_defs().size() >= 2,
		"einfache Tränke sind kaufbar (Heil-/Manatrank)")
	var all_craftable := true
	for def in ConsumableLibrary.all_defs():
		if not def.is_craftable():
			all_craftable = false
	_check(all_craftable, "ALLE Tränke sind craftbar")

	# Ein Kur-Trank pro Statuseffekt + Allheilmittel aus allen zusammen.
	var covered := {}
	for def in ConsumableLibrary.all_defs():
		if def.effect == Enums.ConsumableEffect.CURE_AILMENTS and def.cures.size() == 1:
			covered[def.cures[0]] = true
	_check(covered.size() == Battle.CURABLE_STATUSES.size(),
		"pro heilbarem Statuseffekt genau ein eigener Kur-Trank (%d)" % covered.size())
	var panacea := ConsumableLibrary.get_def(&"allheilmittel")
	_check(panacea.cures.size() == Battle.CURABLE_STATUSES.size(),
		"Allheilmittel entfernt alle Statuseffekte")
	_check(panacea.craft_consumables.size() == 5,
		"Allheilmittel wird aus den 5 Kur-Tränken gecraftet")


func _test_percent_healing() -> void:
	print("Prozent-Heilung (Skalierung bis Level 100):")
	var battle := Battle.new()
	var actor := _fighter(5)
	var small := _fighter(5)     # 60 Max-HP → Flat 30 greift (20% wären nur 12)
	var big := _fighter(100)     # 820 Max-HP → 20% = 164 schlägt Flat 30
	battle.start([actor, small, big], [_fighter(1)])

	var heal := ConsumableLibrary.get_def(&"heiltrank")
	small.hp = 1
	battle.use_consumable(actor, heal, small)
	_check(small.hp == 31, "kleiner Charakter: Flat-Wert greift (1 + 30)")
	big.hp = 1
	battle.use_consumable(actor, heal, big)
	_check(big.hp == 1 + roundi(big.max_hp * 0.2),
		"großer Charakter: Prozent-Wert greift (+%d HP)" % roundi(big.max_hp * 0.2))

	var mana := ConsumableLibrary.get_def(&"manatrank")
	big.stats.spirit = 100
	big.recompute_derived()
	big.mp = 0
	battle.use_consumable(actor, mana, big)
	_check(big.mp == roundi(big.max_mp * 0.2), "Manatrank skaliert ebenfalls prozentual")


func _test_cures() -> void:
	print("Kur-Tränke:")
	var battle := Battle.new()
	var actor := _fighter(5)
	var target := _fighter(5)
	battle.start([actor, target], [_fighter(1)])

	target.add_status(Enums.Status.BURN, 3, 5)
	target.add_status(Enums.Status.POISON_DOT, 3, 5)
	battle.use_consumable(actor, ConsumableLibrary.get_def(&"brandsalbe"), target)
	_check(not target.has_status(Enums.Status.BURN), "Brandsalbe entfernt Brand")
	_check(target.has_status(Enums.Status.POISON_DOT), "… aber nicht Gift (spezifisch!)")

	target.add_status(Enums.Status.STUN, 1, 0)
	target.add_status(Enums.Status.SLOW, 2, 30)
	target.add_status(Enums.Status.SHIELD, 3, 10)
	battle.use_consumable(actor, ConsumableLibrary.get_def(&"allheilmittel"), target)
	_check(not target.has_status(Enums.Status.POISON_DOT)
		and not target.has_status(Enums.Status.STUN)
		and not target.has_status(Enums.Status.SLOW),
		"Allheilmittel entfernt alle Leiden")
	_check(target.has_status(Enums.Status.SHIELD), "positive Effekte (Schild) bleiben")


func _test_shop_and_crafting() -> void:
	print("Kaufen & Alchemie:")
	var state: Node = load("res://autoload/game_state.gd").new()
	state.gold = 30

	var heal := ConsumableLibrary.get_def(&"heiltrank")
	_check(state.buy(heal) and state.consumable_count(&"heiltrank") == 1
		and state.gold == 5, "Heiltrank kaufen: Gold runter, Bestand hoch")
	_check(not state.buy(heal), "zu wenig Gold → Kauf abgelehnt")
	var revive := ConsumableLibrary.get_def(&"belebungselixier")
	state.gold = 9999
	_check(not state.buy(revive), "nicht-kaufbare Tränke kann man nicht kaufen")

	# Heiltrank craften: 2× Heilkraut.
	_check(not state.can_craft(heal), "ohne Materialien kein Craften")
	state.add_material(&"heilkraut", 2)
	_check(state.craft(heal) and state.consumable_count(&"heiltrank") == 2
		and state.material_count(&"heilkraut") == 0,
		"Heiltrank gecraftet, Materialien verbraucht")

	# Allheilmittel: erst die 5 Kur-Tränke craften, dann kombinieren.
	var panacea := ConsumableLibrary.get_def(&"allheilmittel")
	state.add_material(&"reinigungssalz", 10)
	for id in [&"brandsalbe", &"gegengift", &"weckelixier", &"tempotrunk", &"staerkungstonikum"]:
		state.craft(ConsumableLibrary.get_def(id))
	_check(state.can_craft(panacea), "5 Kur-Tränke vorhanden → Allheilmittel craftbar")
	_check(state.craft(panacea) and state.consumable_count(&"allheilmittel") == 1,
		"Allheilmittel gecraftet")
	_check(state.consumable_count(&"brandsalbe") == 0,
		"Zutaten-Tränke wurden dabei verbraucht")
	state.free()
