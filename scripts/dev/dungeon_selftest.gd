extends SceneTree
## Headless-Selbsttest für die Dungeon-Generierung:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/dungeon_selftest.gd

var failures := 0


func _init() -> void:
	_test_determinism()
	_test_connectivity()
	_test_placements()
	_test_encounter_determinism()
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


func _test_encounter_determinism() -> void:
	print("Encounter:")
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 555
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 555
	var group_a := TestContent.make_encounter(2, rng_a)
	var group_b := TestContent.make_encounter(2, rng_b)
	_check(group_a.size() == group_b.size(), "gleicher Seed → gleiche Gruppengröße")
	var same := true
	for i in group_a.size():
		if group_a[i].display_name != group_b[i].display_name:
			same = false
	_check(same, "gleicher Seed → gleiche Gegner-Zusammensetzung")

	var tier1_rng := RandomNumberGenerator.new()
	tier1_rng.seed = 1
	var tier5_rng := RandomNumberGenerator.new()
	tier5_rng.seed = 1
	var weak := TestContent.make_encounter(1, tier1_rng)[0]
	var strong := TestContent.make_encounter(5, tier5_rng)[0]
	_check(strong.max_hp > weak.max_hp, "höheres Tier → stärkere Gegner")

	var boss_rng := RandomNumberGenerator.new()
	boss_rng.seed = 1
	var boss := TestContent.make_encounter(1, boss_rng, true)
	_check(boss.size() == 1 and boss[0].display_name == "Knochenfürst", "Boss-Encounter liefert Boss")
