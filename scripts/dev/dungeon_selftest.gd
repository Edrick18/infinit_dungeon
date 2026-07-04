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
	_test_layout_variety()
	_test_card_affix_generation()
	_test_events()
	_test_chest_rarities()
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


func _test_layout_variety() -> void:
	print("Layout-Vielfalt (3 Generierungs-Stile):")
	var seen := {}
	for i in 40:
		var card := _card(i * 7 + 1)
		seen[DungeonGenerator.layout_for(card, 0)] = true
	_check(seen.size() == 3, "über 40 Karten kommen alle 3 Layout-Stile vor (%d)" % seen.size())

	var multi := _card(99, 9)
	multi.floor_count = 3
	var floor_layouts := {}
	for f in 3:
		floor_layouts[DungeonGenerator.layout_for(multi, f)] = true
	_check(DungeonGenerator.layout_for(multi, 0) == DungeonGenerator.layout_for(multi, 0),
		"Layout pro Ebene ist deterministisch")

	# Jeder Stil erzeugt begehbare, zusammenhängende Karten (Prune-Garantie).
	for seed_value in [11, 22, 33, 44, 55, 66]:
		var card := _card(seed_value, 4)
		var map := DungeonGenerator.generate(card)
		var dist := map.distances_from(map.spawn)
		if dist.size() != map.floor_cells().size():
			_check(false, "Seed %d: unerreichbare Zellen trotz Prune!" % seed_value)
			return
	_check(true, "alle Stile: jede Bodenzelle vom Spawn erreichbar (6 Seeds)")


func _test_card_affix_generation() -> void:
	print("Karten-Affixe wirken auf die Generierung:")
	var plain := _card(500, 3)
	var crowded := _card(500, 3)
	crowded.card_affix_ids = [&"bevoelkert"] as Array[StringName]
	var rich := _card(500, 3)
	rich.card_affix_ids = [&"schatz"] as Array[StringName]

	var plain_map := DungeonGenerator.generate(plain)
	var crowded_map := DungeonGenerator.generate(crowded)
	var rich_map := DungeonGenerator.generate(rich)
	_check(crowded_map.enemies.size() == plain_map.enemies.size() + 3,
		"'Bevölkert': +3 Gegner (%d → %d)" % [plain_map.enemies.size(), crowded_map.enemies.size()])
	_check(rich_map.chests.size() == plain_map.chests.size() + 2,
		"'Schatzkammer': +2 Truhen (%d → %d)" % [plain_map.chests.size(), rich_map.chests.size()])

	# Elitär: doppelte Elite-Chance in Encountern.
	var elite_card := _card(700, 3)
	elite_card.modifier_ids = [&"gepanzert"] as Array[StringName]
	elite_card.card_affix_ids = [&"elitaer"] as Array[StringName]
	var base_card := _card(700, 3)
	base_card.modifier_ids = [&"gepanzert"] as Array[StringName]
	var elite_hits := 0
	var base_hits := 0
	for i in 60:
		var rng_a := RandomNumberGenerator.new()
		rng_a.seed = i
		for enemy in EnemyFactory.make_encounter(elite_card, rng_a):
			if "[" in enemy.display_name:
				elite_hits += 1
		var rng_b := RandomNumberGenerator.new()
		rng_b.seed = i
		for enemy in EnemyFactory.make_encounter(base_card, rng_b):
			if "[" in enemy.display_name:
				base_hits += 1
	_check(elite_hits > base_hits,
		"'Elitär' erzeugt mehr Eliten (%d > %d über 60 Encounter)" % [elite_hits, base_hits])

	# Gefährlich: Gegner stärker + mehr Beute (höhere Stufe, damit die
	# 15% nicht in der Ganzzahl-Rundung kleiner Werte verschwinden).
	var danger_card := _card(800, 8)
	danger_card.card_affix_ids = [&"gefaehrlich"] as Array[StringName]
	var normal_card := _card(800, 8)
	var rng_danger := RandomNumberGenerator.new()
	rng_danger.seed = 5
	var rng_normal := RandomNumberGenerator.new()
	rng_normal.seed = 5
	var dangerous := EnemyFactory.make_encounter(danger_card, rng_danger)[0]
	var normal := EnemyFactory.make_encounter(normal_card, rng_normal)[0]
	var danger_power := dangerous.innate_weapon_damage + dangerous.innate_spell_damage \
		+ dangerous.stats.strength + dangerous.stats.intelligence
	var normal_power := normal.innate_weapon_damage + normal.innate_spell_damage \
		+ normal.stats.strength + normal.stats.intelligence
	_check(danger_power > normal_power, "'Gefährlich': Gegner sind stärker")
	_check(dangerous.loot_mult > normal.loot_mult, "'Gefährlich': mehr Beute als Ausgleich")


func _test_events() -> void:
	print("Dungeon-Events (Schreine, Opfersteine, Risiko-Truhen):")
	var a := DungeonGenerator.generate(_card(3131, 3))
	var b := DungeonGenerator.generate(_card(3131, 3))
	_check(str(a.events) == str(b.events),
		"gleicher Seed → identische Events (Position und Typ)")
	_check(a.events.size() == DungeonGenerator.EVENT_COUNT,
		"Stufe 3: %d Events pro Ebene" % DungeonGenerator.EVENT_COUNT)
	var high := DungeonGenerator.generate(_card(3131, 8))
	_check(high.events.size() == DungeonGenerator.EVENT_COUNT + 1,
		"Stufe 8: ein Event mehr")

	# Platzierung: begehbar, erreichbar, mit Abstand, kollisionsfrei.
	var placement_ok := true
	for seed_value in [7, 88, 999]:
		var map := DungeonGenerator.generate(_card(seed_value, 4))
		var dist := map.distances_from(map.spawn)
		var taken := {map.boss_cell: true, map.stairs_cell: true}
		for enemy in map.enemies:
			taken[enemy["cell"]] = true
		for chest in map.chests:
			taken[chest["cell"]] = true
		for event in map.events:
			var cell: Vector2i = event["cell"]
			if not map.is_floor(cell) or not dist.has(cell):
				placement_ok = false
			if dist.get(cell, 0) < DungeonGenerator.MIN_EVENT_DIST:
				placement_ok = false
			if taken.has(cell):
				placement_ok = false
			taken[cell] = true
	_check(placement_ok, "Events liegen begehbar, erreichbar und kollisionsfrei")

	# Über viele Karten kommen alle Event-Typen vor.
	var types := {}
	for i in 80:
		for event in DungeonGenerator.generate(_card(i * 13 + 5, 3)).events:
			types[event["type"]] = true
	_check(types.size() == 6, "über 80 Karten kommen alle 6 Event-Typen vor (%d)" % types.size())

	# Mimic: existiert als Archetyp, lauert aber in keinem Biom-Pool.
	_check(EnemyLibrary.get_archetype(&"mimic") != null, "Mimic-Archetyp existiert")
	var in_pool := false
	for biome in [Enums.Biome.FOREST, Enums.Biome.CAVE, Enums.Biome.RUINS, Enums.Biome.CRYPT]:
		for archetype in EnemyLibrary.archetypes_for_biome(biome, false, 999):
			if archetype.id == &"mimic":
				in_pool = true
	_check(not in_pool, "Mimic taucht in keinem Biom-Pool auf (nur in Risiko-Truhen)")


func _test_chest_rarities() -> void:
	print("Truhen-Raritäten:")
	var a := DungeonGenerator.generate(_card(6161, 4))
	var b := DungeonGenerator.generate(_card(6161, 4))
	_check(str(a.chests) == str(b.chests),
		"gleicher Seed → gleiche Truhen-Raritäten (deterministisch)")
	var has_rarity := true
	for chest in a.chests:
		if not chest.has("rarity"):
			has_rarity = false
	_check(has_rarity, "jede Truhe trägt eine Rarität")

	var rarities := {}
	for i in 50:
		for chest in DungeonGenerator.generate(_card(i * 11 + 3, 4)).chests:
			rarities[chest["rarity"]] = true
	_check(rarities.size() >= 3, "Truhen-Raritäten streuen (%d Stufen über 50 Karten)"
		% rarities.size())

	# Die Truhen-Rarität bestimmt die Rarität des Items — nicht die Häufigkeit.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var legendary := LootGenerator.roll_item_with_rarity(4, Enums.Rarity.LEGENDARY, rng)
	_check(legendary.rarity == Enums.Rarity.LEGENDARY
		and legendary.affixes.size() == LootGenerator.AFFIX_COUNT[Enums.Rarity.LEGENDARY],
		"legendäre Truhe → legendäres Item (4 Affixe)")
	var common := LootGenerator.roll_item_with_rarity(4, Enums.Rarity.COMMON, rng)
	_check(common.rarity == Enums.Rarity.COMMON and common.affixes.is_empty(),
		"gewöhnliche Truhe → gewöhnliches Item")
