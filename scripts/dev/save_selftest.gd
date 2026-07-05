extends SceneTree
## Headless-Selbsttest für das Speichersystem: Serialisierungs-Rundwege und
## echte Datei-I/O (auf einem eigenen Testpfad — NIE dem echten Spielstand).
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/save_selftest.gd

const TEST_SAVE_PATH := "user://selftest_savegame.json"

var failures := 0


func _init() -> void:
	_test_stat_block_roundtrip()
	_test_skill_roundtrip()
	_test_item_instance_roundtrip()
	_test_dungeon_card_roundtrip()
	_test_combatant_roundtrip()
	_test_gamestate_roundtrip()
	_test_file_io()
	if failures == 0:
		print("SELFTEST OK — alle Speichersystem-Tests bestanden")
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


func _test_stat_block_roundtrip() -> void:
	print("StatBlock-Rundweg:")
	var stats := StatBlock.new()
	stats.strength = 12
	stats.vitality = 7
	stats.luck = 3
	var restored := StatBlock.from_dict(stats.to_dict())
	_check(restored.strength == 12 and restored.vitality == 7 and restored.luck == 3,
		"alle Attribute überstehen den Rundweg")


func _test_skill_roundtrip() -> void:
	print("Skill-Rundweg:")
	var skill := Skill.new()
	skill.display_name = "Feuerball"
	skill.blocks = [
		BlockLibrary.get_block(&"src_spell"),
		BlockLibrary.get_block(&"elem_fire"),
	]
	var restored := Skill.from_dict(skill.to_dict())
	_check(restored.display_name == "Feuerball", "Name übersteht den Rundweg")
	_check(restored.blocks.size() == 2, "alle Bausteine übernommen")
	_check(restored.is_valid(), "wiederhergestellter Skill ist gültig")
	_check(restored.get_mp_cost() == skill.get_mp_cost(), "MP-Kosten identisch")
	# Bausteine sind dieselben kanonischen Objekte aus der Bibliothek, nicht Kopien.
	_check(restored.blocks[0] == BlockLibrary.get_block(&"src_spell"),
		"Bausteine sind die geteilten Bibliotheks-Objekte (keine Duplikate)")


func _test_item_instance_roundtrip() -> void:
	print("ItemInstance-Rundweg:")
	var item := LootGenerator.roll_item(3, _rng(42))
	while item.affixes.is_empty():
		item = LootGenerator.roll_item(3, _rng(randi()))
	var restored := ItemInstance.from_dict(item.to_dict())
	_check(restored != null, "Wiederherstellung liefert ein Item")
	_check(restored.base.id == item.base.id, "Basis-Item-ID übersteht den Rundweg")
	_check(restored.affixes.size() == item.affixes.size(), "Affix-Anzahl übersteht den Rundweg")
	_check(restored.get_display_name() == item.get_display_name(), "Anzeigename identisch")
	_check(restored.item_level == item.item_level, "Item-Level identisch")

	var broken := ItemInstance.from_dict({"base_id": "nicht_vorhanden"})
	_check(broken == null, "unbekannte Basis-ID liefert null statt Absturz")


func _test_dungeon_card_roundtrip() -> void:
	print("DungeonCard-Rundweg:")
	var rng := _rng(7)
	var card := CardFactory.make_card(6, rng)
	var restored := DungeonCard.from_dict(card.to_dict())
	_check(restored.seed == card.seed and restored.tier == card.tier
		and restored.biome == card.biome and restored.floor_count == card.floor_count,
		"Kern-Felder überstehen den Rundweg")
	_check(restored.modifier_ids.size() == card.modifier_ids.size(),
		"Modifikatoren überstehen den Rundweg")
	# Determinismus bleibt erhalten: gleicher Seed -> gleiches Layout.
	var original_map := DungeonGenerator.generate(card)
	var restored_map := DungeonGenerator.generate(restored)
	_check(original_map.cells == restored_map.cells,
		"wiederhergestellte Karte generiert dasselbe Layout")


func _test_combatant_roundtrip() -> void:
	print("Combatant-Rundweg (Held mit Ausrüstung + Skills):")
	var hero := TestContent.make_party()[0]
	hero.level = 7
	hero.xp = 15
	hero.stat_points = 3
	hero.spend_stat_point(&"vitality")
	hero.equip(_test_weapon())
	hero.hp = hero.max_hp - 10  # angeschlagen, wie mitten im Dungeon
	var hp_before := hero.hp
	var mp_before := hero.mp
	var max_hp_before := hero.max_hp

	var restored := Combatant.from_dict(hero.to_dict())
	_check(restored.display_name == hero.display_name, "Name übersteht den Rundweg")
	_check(restored.level == 7 and restored.xp == 15, "Level und XP übersteht den Rundweg")
	_check(restored.stats.vitality == hero.stats.vitality, "verteilte Statuspunkte übersteht den Rundweg")
	_check(restored.max_hp == max_hp_before, "Max-HP inkl. Ausrüstungsbonus korrekt neu berechnet")
	_check(restored.hp == hp_before, "aktuelle (angeschlagene) HP übersteht den Rundweg — kein Auto-Heal")
	_check(restored.mp == mp_before, "aktuelle MP übersteht den Rundweg")
	_check(restored.equipment.has(Enums.EquipSlot.WEAPON), "Ausrüstung übersteht den Rundweg")
	_check(restored.skills.size() == hero.skills.size(), "Skills übersteht den Rundweg")
	_check(restored.sprite != null, "Sprite wird beim Laden neu zugewiesen")


func _test_gamestate_roundtrip() -> void:
	print("GameState-Gesamt-Rundweg:")
	var original: Node = load("res://autoload/game_state.gd").new()
	original.party = TestContent.make_party()
	original.party[0].equip(_test_weapon())
	var bench_hero := Combatant.from_dict({"name": "Edda", "level": 7})
	original.reserve.append(bench_hero)
	original.gold = 777
	var researched_list: Array[StringName] = [&"eff_stun", &"eff_shield"]
	original.researched = researched_list
	var inventory_list: Array[ItemInstance] = [LootGenerator.roll_item(2, _rng(3))]
	original.inventory = inventory_list
	original.consumables = {&"heiltrank": 5}
	original.materials = {&"heilkraut": 2}
	var cards_list: Array[DungeonCard] = [CardFactory.make_starter_card()]
	original.cards = cards_list
	original.card_capacity = 30
	original.storage_expansions = 1
	var hunt_order := {"type": "hunt", "count": 10, "progress": 4,
		"reward": {"kind": "gold", "gold": 90}}
	original.merchant_orders = [hunt_order] as Array[Dictionary]
	original.language = "en"
	var card := CardFactory.make_card(4, _rng(9))
	original.start_run(card)
	original.current_run["explored_by_floor"] = {0: {Vector2i(3, 3): true, Vector2i(3, 4): true}}
	original.current_run["defeated"] = [1001, 1002]
	original.current_run["events_used"] = [2, 1001]
	original.current_run["blessing"] = &"segen_kraft"
	original.current_run["player_pos"] = Vector2(123.0, 456.0)

	var restored: Node = load("res://autoload/game_state.gd").new()
	restored.apply_save_dict(original.to_save_dict())

	_check(restored.gold == 777, "Gold übersteht den Rundweg")
	_check(restored.researched.size() == 2 and &"eff_stun" in restored.researched,
		"erforschte Bausteine überstehen den Rundweg")
	_check(restored.party.size() == original.party.size(), "Party-Größe übersteht den Rundweg")
	_check(restored.party[0].equipment.has(Enums.EquipSlot.WEAPON),
		"Party-Ausrüstung übersteht den Rundweg")
	_check(restored.reserve.size() == 1 and restored.reserve[0].display_name == "Edda"
		and restored.reserve[0].level == 7, "Taverne-Bank übersteht den Rundweg")
	_check(restored.inventory.size() == 1, "Inventar übersteht den Rundweg")
	_check(restored.consumable_count(&"heiltrank") == 5, "Tränke überstehen den Rundweg")
	_check(restored.material_count(&"heilkraut") == 2, "Materialien überstehen den Rundweg")
	_check(restored.cards.size() == 1, "Kartenlager übersteht den Rundweg")
	_check(restored.card_capacity == 30 and restored.storage_expansions == 1,
		"Lager-Kapazität übersteht den Rundweg")

	_check(not restored.current_run.is_empty(), "laufender Dungeon-Run übersteht den Rundweg")
	var restored_card: DungeonCard = restored.current_run["card"]
	_check(restored_card.seed == card.seed, "Run-Karte übersteht den Rundweg")
	var pos: Vector2 = restored.current_run["player_pos"]
	_check(pos.is_equal_approx(Vector2(123.0, 456.0)), "Spielerposition übersteht den Rundweg")
	_check(restored.current_run["defeated"] == [1001, 1002],
		"besiegte Gegner überstehen den Rundweg")
	var explored: Dictionary = restored.current_run["explored_by_floor"][0]
	_check(explored.size() == 2 and explored.has(Vector2i(3, 3)),
		"Fog of War übersteht den Rundweg (der ursprüngliche Bugfix)")
	_check(restored.current_run["events_used"] == [2, 1001],
		"verbrauchte Dungeon-Events überstehen den Rundweg")
	_check(restored.current_run.get("blessing", &"") == &"segen_kraft",
		"aktiver Schrein-Segen übersteht den Rundweg")
	_check(restored.merchant_orders.size() == 1
		and int(restored.merchant_orders[0]["progress"]) == 4,
		"Händler-Aufträge samt Fortschritt überstehen den Rundweg")
	_check(restored.language == "en", "Sprach-Einstellung übersteht den Rundweg")
	restored.language = "de"  # globalen Loc-Zustand für weitere Tests zurücksetzen

	original.free()
	restored.free()


func _test_file_io() -> void:
	print("Datei-I/O (eigener Testpfad, NICHT der echte Spielstand):")
	SaveManager.delete_save(TEST_SAVE_PATH)
	_check(not SaveManager.has_save(TEST_SAVE_PATH), "kein Test-Save zu Beginn")

	var data := {"gold": 42, "nested": {"a": [1, 2, 3]}}
	_check(SaveManager.save(data, TEST_SAVE_PATH), "Speichern auf Testpfad klappt")
	_check(SaveManager.has_save(TEST_SAVE_PATH), "Datei existiert danach")

	var loaded := SaveManager.load_data(TEST_SAVE_PATH)
	_check(int(loaded.get("gold", 0)) == 42, "geladene Daten stimmen")
	var nested_array: Array = loaded.get("nested", {}).get("a", [])
	_check(nested_array.size() == 3 and nested_array[0] == 1
		and nested_array[1] == 2 and nested_array[2] == 3, "verschachtelte Daten stimmen")

	SaveManager.delete_save(TEST_SAVE_PATH)
	_check(not SaveManager.has_save(TEST_SAVE_PATH), "Löschen entfernt die Testdatei")
	_check(SaveManager.load_data(TEST_SAVE_PATH).is_empty(),
		"Laden ohne Datei liefert leeres Dictionary statt Absturz")

	# Spielstand-Slots: Slot 1 = klassischer Pfad (Altbestand kompatibel).
	print("Spielstand-Slots:")
	_check(SaveManager.path_for_slot(1) == SaveManager.SAVE_PATH,
		"Slot 1 nutzt den klassischen Pfad (alte Spielstände laufen weiter)")
	_check(SaveManager.path_for_slot(2) != SaveManager.path_for_slot(3),
		"jeder Slot hat eine eigene Datei")
	var previous_slot := SaveManager.active_slot
	SaveManager.active_slot = 3
	_check(SaveManager.active_path() == SaveManager.path_for_slot(3),
		"active_path folgt dem aktiven Slot")
	SaveManager.active_slot = previous_slot
	var info: Dictionary = SaveManager.slot_info(SaveManager.SLOT_COUNT)
	_check(info.is_empty() or info.has("heroes"),
		"slot_info liefert leer (kein Save) oder eine vollständige Kurzinfo")


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_weapon() -> ItemInstance:
	var item := ItemInstance.new()
	item.base = ItemLibrary.bases_for_tier(1)[0]
	item.item_level = 1
	return item
