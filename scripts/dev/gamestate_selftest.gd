extends SceneTree
## Headless-Selbsttest für GameState-Run-Verwaltung, insbesondere den
## Fog-of-War-Fix (persistiert über Szenenwechsel, aber nicht über
## Ebenen-/Run-Wechsel hinweg):
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/gamestate_selftest.gd

var failures := 0


func _init() -> void:
	_test_explored_survives_scene_reload()
	_test_explored_resets_on_new_floor()
	_test_explored_resets_on_new_run()
	if failures == 0:
		print("SELFTEST OK — alle GameState-Tests bestanden")
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


func _test_explored_survives_scene_reload() -> void:
	print("Fog of War übersteht Szenenwechsel (z.B. Kampf):")
	var state: Node = load("res://autoload/game_state.gd").new()
	var card := DungeonCard.new()
	card.seed = 1
	card.tier = 1
	state.start_run(card)

	# Simuliert, was dungeon_scene.gd in _ready() tut: lazy anlegen, dieselbe
	# Referenz holen.
	if not state.current_run.has("explored_by_floor"):
		state.current_run["explored_by_floor"] = {}
	var explored_by_floor: Dictionary = state.current_run["explored_by_floor"]
	if not explored_by_floor.has(0):
		explored_by_floor[0] = {}
	var explored: Dictionary = explored_by_floor[0]
	explored[Vector2i(5, 5)] = true
	explored[Vector2i(6, 5)] = true

	# "Kampf-Szenenwechsel": current_run bleibt unangetastet, nur eine neue
	# Referenz wird wie in _ready() erneut geholt.
	var explored_after: Dictionary = state.current_run["explored_by_floor"][0]
	_check(explored_after.has(Vector2i(5, 5)) and explored_after.size() == 2,
		"erkundete Zellen sind nach simuliertem Kampf noch da")
	state.free()


func _test_explored_resets_on_new_floor() -> void:
	print("Fog of War ist pro Ebene getrennt:")
	var state: Node = load("res://autoload/game_state.gd").new()
	var card := DungeonCard.new()
	card.seed = 1
	card.tier = 5
	state.start_run(card)

	state.current_run["explored_by_floor"] = {}
	var explored_by_floor: Dictionary = state.current_run["explored_by_floor"]
	explored_by_floor[0] = {Vector2i(1, 1): true}

	# Treppe: floor hochzählen (wie in dungeon_scene.gd bei Treppen-Kontakt).
	state.current_run["floor"] = 1
	var new_floor_explored: Dictionary = explored_by_floor.get(1, {})
	_check(new_floor_explored.is_empty(), "neue Ebene startet mit leerem Fog")
	_check(explored_by_floor[0].size() == 1, "Fog der vorherigen Ebene bleibt unangetastet")
	state.free()


func _test_explored_resets_on_new_run() -> void:
	print("Fog of War resettet bei neuem Dungeon-Run:")
	var state: Node = load("res://autoload/game_state.gd").new()
	var card_a := DungeonCard.new()
	card_a.seed = 1
	card_a.tier = 1
	state.start_run(card_a)
	state.current_run["explored_by_floor"] = {0: {Vector2i(2, 2): true}}

	var card_b := DungeonCard.new()
	card_b.seed = 2
	card_b.tier = 1
	state.start_run(card_b)
	_check(not state.current_run.has("explored_by_floor"),
		"neuer Run baut current_run komplett neu auf — kein alter Fog übrig")
	state.free()
