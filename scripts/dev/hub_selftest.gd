extends SceneTree
## Headless-Selbsttest für Kartenfabrik und Kartenlager:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/hub_selftest.gd

var failures := 0


func _init() -> void:
	_test_card_factory()
	_test_reward_tiers()
	_test_storage()
	if failures == 0:
		print("SELFTEST OK — alle Hub-/Kartensystem-Tests bestanden")
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


func _test_card_factory() -> void:
	print("Kartenfabrik:")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var all_ok := true
	var biomes := {}
	for i in 50:
		var card := CardFactory.make_card(3, rng)
		biomes[card.biome] = true
		if card.display_name.is_empty() or card.tier != 3 or card.modifier_ids.is_empty():
			all_ok = false
		for id in card.modifier_ids:
			var modifier := EnemyLibrary.get_modifier(id)
			if modifier == null or modifier.min_tier > 3:
				all_ok = false
	_check(all_ok, "50 Karten: Name, Stufe und gültige Modifikatoren (min_tier ok)")
	_check(biomes.size() == 2, "Stufe 3: genau zwei Biome freigeschaltet (Wald + Höhle)")

	var starter := CardFactory.make_starter_card()
	_check(starter.tier == 1 and starter.biome == Enums.Biome.FOREST,
		"Startkarte: Stufe 1, Wald")


func _test_reward_tiers() -> void:
	print("Belohnungskarte (±3):")
	var base := DungeonCard.new()
	base.tier = 5
	var in_range := true
	var varied := {}
	for i in 100:
		var reward := CardFactory.make_reward(base)
		varied[reward.tier] = true
		if reward.tier < 2 or reward.tier > 8:
			in_range = false
	_check(in_range, "100 Belohnungen: immer im Bereich Stufe 2-8 (5 ± 3)")
	_check(varied.size() >= 4, "Stufen streuen (%d verschiedene)" % varied.size())

	var low := DungeonCard.new()
	low.tier = 1
	var min_ok := true
	for i in 50:
		if CardFactory.make_reward(low).tier < 1:
			min_ok = false
	_check(min_ok, "Stufe fällt nie unter 1")


func _test_storage() -> void:
	print("Kartenlager:")
	# GameState außerhalb des Baums instanziieren (ohne _ready/Startkarten).
	var state: Node = load("res://autoload/game_state.gd").new()
	state.card_capacity = 3

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var cards: Array[DungeonCard] = []
	for i in 4:
		cards.append(CardFactory.make_card(1, rng))

	_check(state.add_card(cards[0]) and state.add_card(cards[1]) and state.add_card(cards[2]),
		"3 Karten passen ins Lager (Kapazität 3)")
	_check(not state.add_card(cards[3]), "4. Karte wird abgelehnt — Lager voll")

	state.delete_card(cards[1])
	_check(state.cards.size() == 2 and state.add_card(cards[3]),
		"nach Löschen ist wieder Platz")

	state.gold = 90
	_check(not state.can_expand_storage(), "Erweiterung mit 90 G nicht leistbar (kostet 100)")
	state.gold = 150
	var cost_before: int = state.storage_expansion_cost()
	_check(state.expand_storage(), "Erweiterung klappt mit genug Gold")
	_check(state.card_capacity == 8, "Kapazität 3 → 8 (+5 Slots)")
	_check(state.gold == 150 - cost_before, "Gold wurde abgezogen")
	_check(state.storage_expansion_cost() > cost_before, "nächste Erweiterung wird teurer")
	state.free()
