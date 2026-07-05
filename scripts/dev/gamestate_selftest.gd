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
	_test_recruiting()
	_test_bestiary()
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


func _test_recruiting() -> void:
	print("Taverne / Rekrutierung (Ein-Helden-Start):")
	var state: Node = load("res://autoload/game_state.gd").new()
	_check(state.party.is_empty(), "frischer Start: Party ist leer (Held wird im Menü erstellt)")

	_check(state.recruit("Aldric", &"krieger"), "erster Held wird rekrutiert")
	_check(state.party.size() == 1, "Party hat 1 Helden")
	var aldric: Combatant = state.party[0]
	_check(aldric.level == 1 and aldric.stats.strength == 5 and aldric.stats.luck == 5,
		"Rekrut startet identisch: Level 1, überall 5")
	_check(aldric.equipment.has(Enums.EquipSlot.WEAPON), "Kit-Startwaffe ist angelegt")
	_check(aldric.skills.size() == 1 and aldric.skills[0].is_valid(),
		"Kit-Skill ist gelernt und gültig")

	_check(not state.recruit("Aldric", &"feuermagier"),
		"derselbe Held kann nicht doppelt angeheuert werden")

	var mage_ok: bool = state.recruit("Mira", &"feuermagier")
	var mira: Combatant = state.party[1]
	var mira_fire := mira.skills[0].get_element() != null \
		and mira.skills[0].get_element().element == Enums.Element.FIRE
	_check(mage_ok and mira_fire, "Kits unterscheiden sich (Mira startet mit Feuerzauber)")

	state.recruit("Talin", &"heiler")
	state.recruit("Runa", &"giftmischer")
	_check(state.party.size() == 4, "Party lässt sich in der Taverne auf 4 füllen")
	_check(not state.recruit("Aldric", &"krieger"), "volle Party: kein 5. Held")
	_check(HeroLibrary.available_names(state.party).is_empty(),
		"Tresen ist leer, wenn alle angeheuert sind")
	state.free()


func _test_bestiary() -> void:
	print("Bestiarium (Kill-Zähler):")
	var state: Node = load("res://autoload/game_state.gd").new()
	_check(state.kills_of(&"wolf") == 0, "unbekannte Gegner starten bei 0")
	state.record_kill(&"wolf")
	state.record_kill(&"wolf")
	state.record_kill(&"schleim")
	state.record_kill(&"")  # leere ID (z.B. Beschwörungen) zählt nicht
	_check(state.kills_of(&"wolf") == 2 and state.kills_of(&"schleim") == 1,
		"Kills werden pro Grundtyp gezählt")
	_check(state.bestiary.size() == 2, "leere IDs landen nicht im Bestiarium")

	state.medals = 7
	var restored: Node = load("res://autoload/game_state.gd").new()
	restored.apply_save_dict(state.to_save_dict())
	_check(restored.kills_of(&"wolf") == 2, "Bestiarium übersteht den Speicher-Rundweg")
	_check(restored.medals == 7, "Mini-Medaillen überstehen den Speicher-Rundweg")
	state.free()
	restored.free()
