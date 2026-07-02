extends SceneTree
## Headless-Selbsttest für die Dungeon-Generierung:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/dungeon_selftest.gd

var failures := 0


func _init() -> void:
	_test_determinism()
	_test_connectivity()
	_test_placements()
	_test_floors()
	_test_line_of_sight()
	if failures == 0:
		print("SELFTEST OK — alle Dungeon-Tests bestanden")
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


func _card(seed_value: int, tier := 1) -> DungeonCard:
	var card := DungeonCard.new()
	card.seed = seed_value
	card.tier = tier
	return card


func _test_determinism() -> void:
	print("Determinismus (Kern des Kartensystems):")
	var a := DungeonGenerator.generate(_card(12345))
	var b := DungeonGenerator.generate(_card(12345))
	_check(a.cells == b.cells, "gleicher Seed → identisches Layout")
	_check(a.boss_cell == b.boss_cell, "gleicher Seed → gleiche Boss-Position")
	_check(str(a.enemies) == str(b.enemies), "gleicher Seed → gleiche Gegner-Platzierung")
	_check(str(a.chests) == str(b.chests), "gleicher Seed → gleiche Truhen (inkl. Gold)")
	var c := DungeonGenerator.generate(_card(99999))
	_check(a.cells != c.cells, "anderer Seed → anderes Layout")


func _test_connectivity() -> void:
	print("Erreichbarkeit:")
	for seed_value in [1, 777, 424242]:
		var map := DungeonGenerator.generate(_card(seed_value))
		var dist := map.distances_from(map.spawn)
		_check(dist.size() == map.floor_cells().size(),
			"Seed %d: jede Bodenzelle vom Spawn erreichbar" % seed_value)


func _test_placements() -> void:
	print("Platzierungen:")
	var map := DungeonGenerator.generate(_card(2026, 3))
	var dist := map.distances_from(map.spawn)
	_check(map.is_floor(map.spawn), "Spawn liegt auf Boden")
	_check(map.is_floor(map.boss_cell), "Boss liegt auf Boden")
	_check(dist[map.boss_cell] >= 10, "Boss liegt weit weg vom Spawn (%d Tiles)" % dist[map.boss_cell])
	_check(map.enemies.size() == 6 + 3, "Gegneranzahl skaliert mit Tier (6 + Tier)")

	var all_valid := true
	for enemy in map.enemies:
		if not map.is_floor(enemy["cell"]) or dist[enemy["cell"]] < DungeonGenerator.MIN_ENEMY_SPAWN_DIST:
			all_valid = false
	_check(all_valid, "alle Gegner auf Boden und mit Abstand zum Spawn")
	_check(map.chests.size() == DungeonGenerator.CHEST_COUNT, "Truhen platziert")
	var gold_ok := true
	for chest in map.chests:
		if chest["gold"] < 20 + 3 * 10:
			gold_ok = false
	_check(gold_ok, "Truhen-Gold skaliert mit Tier")


func _test_floors() -> void:
	print("Ebenen (Boss immer ganz unten):")
	var card := _card(777, 6)
	card.floor_count = 3

	var top := DungeonGenerator.generate(card, 0)
	var mid := DungeonGenerator.generate(card, 1)
	var bottom := DungeonGenerator.generate(card, 2)
	_check(not top.has_boss and top.stairs_cell.x >= 0,
		"Ebene 1: kein Boss, aber Treppe nach unten")
	_check(not mid.has_boss and mid.stairs_cell.x >= 0,
		"Ebene 2: kein Boss, aber Treppe nach unten")
	_check(bottom.has_boss and bottom.stairs_cell.x < 0,
		"Ebene 3 (unterste): Boss statt Treppe")
	_check(top.cells != mid.cells, "jede Ebene hat ein eigenes Layout")
	var top_again := DungeonGenerator.generate(card, 0)
	_check(top.cells == top_again.cells, "Ebenen sind pro Karte deterministisch")

	# Ebenen-Anzahl skaliert mit der Kartenstufe.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	_check(CardFactory.make_card(1, rng).floor_count == 1, "Stufe 1: 1 Ebene")
	_check(CardFactory.make_card(5, rng).floor_count == 2, "Stufe 5: 2 Ebenen")
	_check(CardFactory.make_card(9, rng).floor_count == 3, "Stufe 9: 3 Ebenen")
	_check(CardFactory.make_card(99, rng).floor_count == 5, "Stufe 99: gedeckelt bei 5")

	# Höhere Stufen schalten mehr Biome frei.
	var low_biomes := {}
	var high_biomes := {}
	for i in 60:
		var roll_rng := RandomNumberGenerator.new()
		roll_rng.seed = i
		low_biomes[CardFactory.make_card(1, roll_rng).biome] = true
		high_biomes[CardFactory.make_card(8, roll_rng).biome] = true
	_check(low_biomes.size() == 1, "Stufe 1: nur Wald")
	_check(high_biomes.size() == 4, "Stufe 8: alle vier Biome im Pool")


func _test_line_of_sight() -> void:
	print("Sichtlinie (Fog of War / Gegner-Wahrnehmung):")
	var map := DungeonMap.new()
	map.width = 5
	map.height = 5
	map.cells.resize(25)
	# Freies 5x5-Feld, dann eine durchgehende Wand in Spalte 2 (x=2).
	for y in 5:
		for x in 5:
			if x != 2:
				map.set_floor(Vector2i(x, y))

	_check(map.has_line_of_sight(Vector2i(0, 2), Vector2i(1, 2)),
		"freie Sicht über offenen Boden")
	_check(not map.has_line_of_sight(Vector2i(0, 2), Vector2i(4, 2)),
		"durchgehende Wand blockiert die Sicht komplett")
	_check(map.has_line_of_sight(Vector2i(1, 1), Vector2i(1, 1)),
		"Sicht auf die eigene Zelle ist immer frei")

	# Lücke in der Wand bei y=0 öffnet eine Sichtachse.
	map.set_floor(Vector2i(2, 0))
	_check(map.has_line_of_sight(Vector2i(0, 0), Vector2i(4, 0)),
		"Lücke in der Wand öffnet die Sichtlinie")
	_check(not map.has_line_of_sight(Vector2i(0, 2), Vector2i(4, 2)),
		"andere Zeile bleibt weiter blockiert")
