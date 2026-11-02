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
	_test_seltene_ereignisse()
	_test_chest_rarities()
	_test_map_growth()
	_test_gegner_nachschub()
	_test_boss_ebene()
	_test_boss_figur()
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
	_check(a.cells == b.cells, "gleicher Seed » identisches Layout")
	_check(a.boss_cell == b.boss_cell, "gleicher Seed » gleiche Boss-Position")
	_check(str(a.enemies) == str(b.enemies), "gleicher Seed » gleiche Gegner-Platzierung")
	_check(str(a.chests) == str(b.chests), "gleicher Seed » gleiche Truhen (inkl. Gold)")
	var c := DungeonGenerator.generate(_card(99999))
	_check(a.cells != c.cells, "anderer Seed » anderes Layout")


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
	_check(not map.has_boss and map.is_floor(map.stairs_cell),
		"normale Ebene: Treppe statt Boss")
	_check(dist[map.stairs_cell] >= 10, "Treppe liegt weit weg vom Spawn (%d Tiles)" % dist[map.stairs_cell])
	_check(map.enemies.size() == DungeonGenerator.gegner_gruppen(3),
		"Gegneranzahl = 8 + 2 je Größenstufe (%d)" % map.enemies.size())
	_check(DungeonGenerator.gegner_gruppen(200) == 16 and DungeonGenerator.beute_faktor(200) > 3.5,
		"höchstens 16 Gruppen, dafür lohnendere Gegner (Faktor %.2f)" % DungeonGenerator.beute_faktor(200))

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
	print("Ebenen (3 normale + Boss-Ebene):")
	var card := _card(777, 6)
	card.floor_count = 3

	var top := DungeonGenerator.generate(card, 0)
	var mid := DungeonGenerator.generate(card, 1)
	var bottom := DungeonGenerator.generate(card, 2)
	var boss := DungeonGenerator.generate(card, 3)
	_check(not top.has_boss and top.stairs_cell.x >= 0,
		"Ebene 1: kein Boss, aber Treppe nach unten")
	_check(not mid.has_boss and mid.stairs_cell.x >= 0,
		"Ebene 2: kein Boss, aber Treppe nach unten")
	_check(not bottom.has_boss and bottom.stairs_cell.x >= 0,
		"Ebene 3 (letzte normale): Treppe zur Boss-Ebene")
	_check(boss.has_boss and boss.stairs_cell.x < 0, "Ebene 4 ist die Boss-Ebene: Boss statt Treppe")
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
		"'Bevölkert': +3 Gegner (%d » %d)" % [plain_map.enemies.size(), crowded_map.enemies.size()])
	_check(rich_map.chests.size() == plain_map.chests.size() + 2,
		"'Schatzkammer': +2 Truhen (%d » %d)" % [plain_map.chests.size(), rich_map.chests.size()])

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
		"gleicher Seed » identische Events (Position und Typ)")
	# Gezählt werden die normalen Events (Händler/Gefangener kommen extra, selten).
	_check(_normale_events(a) == DungeonGenerator.EVENT_COUNT,
		"Stufe 3: %d Events pro Ebene" % DungeonGenerator.EVENT_COUNT)
	var high := DungeonGenerator.generate(_card(3131, 8))
	_check(_normale_events(high) == DungeonGenerator.EVENT_COUNT + 2,
		"Stufe 8: mehr Events (+1 ab Stufe 5, +1 pro Größenschritt)")

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
			if not DungeonEreignisse.ist_sonderereignis(event["type"]):
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


func _normale_events(map: DungeonMap) -> int:
	var anzahl := 0
	for event in map.events:
		if not DungeonEreignisse.ist_sonderereignis(event["type"]):
			anzahl += 1
	return anzahl


func _test_chest_rarities() -> void:
	print("Truhen-Raritäten:")
	var a := DungeonGenerator.generate(_card(6161, 4))
	var b := DungeonGenerator.generate(_card(6161, 4))
	_check(str(a.chests) == str(b.chests),
		"gleicher Seed » gleiche Truhen-Raritäten (deterministisch)")
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
		"legendäre Truhe » legendäres Item (4 Affixe)")
	var common := LootGenerator.roll_item_with_rarity(4, Enums.Rarity.COMMON, rng)
	_check(common.rarity == Enums.Rarity.COMMON and common.affixes.is_empty(),
		"gewöhnliche Truhe » gewöhnliches Item")


func _test_map_growth() -> void:
	print("Kartengröße wächst mit der Stufe (alle 5 Stufen +10):")
	var t1 := DungeonGenerator.generate(_card(70, 1))
	_check(t1.width == 48 and t1.height == 36, "Stufe 1: 48×36 (Basisgröße)")
	var t5 := DungeonGenerator.generate(_card(70, 5))
	_check(t5.width == 58 and t5.height == 46, "Stufe 5: 58×46 (+10)")
	var t10 := DungeonGenerator.generate(_card(70, 10))
	_check(t10.width == 68 and t10.height == 56, "Stufe 10: 68×56 (+20)")
	var t99 := DungeonGenerator.generate(_card(70, 99))
	_check(t99.width == 88 and t99.height == 76, "Stufe 99: gedeckelt bei 88×76")

	# Große Karten bleiben zusammenhängend und dichter bevölkert.
	var dist := t10.distances_from(t10.spawn)
	_check(dist.size() == t10.floor_cells().size(),
		"Stufe-10-Karte: jede Bodenzelle erreichbar (Prune-Garantie)")
	_check(t10.enemies.size() == t1.enemies.size() + 4,
		"größere Karte » etwas mehr Gegner (%d = %d + 4)" % [t10.enemies.size(), t1.enemies.size()])
	_check(t10.chests.size() == DungeonGenerator.CHEST_COUNT + 2,
		"größere Karte » mehr Truhen (%d)" % t10.chests.size())


func _test_gegner_nachschub() -> void:
	print("Dynamische Gegner (Höchstzahl, Nachrücken, Bestand):")
	var card := CardFactory.make_starter_card()
	var map := DungeonGenerator.generate(card)
	var run := {"defeated": []}
	var bestand := GegnerNachschub.bestand(run, map, 0, 1000)
	_check(bestand.size() == map.enemies.size() and run.has("gegner_by_floor"),
		"erstes Betreten: Bestand = Generator-Gegner (%d)" % bestand.size())
	run["defeated"].append(int(bestand[0][0]))
	_check(GegnerNachschub.bestand(run, map, 0, 1000).size() == map.enemies.size() - 1,
		"besiegte Gegner fallen aus dem Bestand")
	bestand = GegnerNachschub.bestand(run, map, 0, 1000)
	var id := GegnerNachschub.neue_id(bestand, run["defeated"], 0, map.enemies.size(), 1000)
	_check(id >= map.enemies.size() and id < 1000, "neue ID über den Generator-IDs (%d)" % id)
	# Voller Bereich: alte Besiegt-Einträge werden aufgeräumt statt zu blockieren.
	var voll: Array = []
	for i in range(map.enemies.size(), 1000):
		voll.append(i)
	var wieder := GegnerNachschub.neue_id([], voll, 0, map.enemies.size(), 1000)
	_check(wieder >= map.enemies.size(), "IDs gehen nie aus (Aufräumen, dann %d)" % wieder)
	# Neue Gegner tauchen auf Boden auf, weit weg vom Helden.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var weit := true
	var boden := true
	for i in 30:
		var zelle := GegnerNachschub.spawn_zelle(map, rng, map.spawn, [])
		if zelle.x < 0:
			continue
		if not map.is_floor(zelle):
			boden = false
		if absi(zelle.x - map.spawn.x) + absi(zelle.y - map.spawn.y) < GegnerNachschub.MIN_ABSTAND_ZELLEN:
			weit = false
	_check(boden and weit, "Nachschub erscheint auf Boden und weit weg vom Helden")



## Boss-Ebene (Lutz 2026-10-24): nur ein Gang zum Boss-Raum, sonst nichts.
func _test_boss_ebene() -> void:
	print("Boss-Ebene:")
	for stufe in [1, 6, 30]:
		var card := _card(4000 + stufe, stufe)
		card.floor_count = 2
		_check(DungeonGenerator.ist_boss_ebene(card, 2) and not DungeonGenerator.ist_boss_ebene(card, 1),
			"Stufe %d: Ebene 3 ist die Boss-Ebene, Ebene 1–2 sind normal" % stufe)
		var map := DungeonGenerator.generate(card, DungeonGenerator.boss_ebene_index(card))
		_check(map.has_boss and map.is_floor(map.boss_cell) and map.stairs_cell.x < 0,
			"Stufe %d: Boss im Raum, keine Treppe" % stufe)
		_check(map.enemies.is_empty() and map.chests.is_empty() and map.events.is_empty()
			and map.tresor_cell.x < 0, "Stufe %d: nur der Boss — keine Gegner, Truhen, Events, Tresor" % stufe)
		var dist := map.distances_from(map.spawn)
		_check(dist.size() == map.floor_cells().size() and dist[map.boss_cell] >= DungeonGenerator.BOSS_GANG_LAENGE,
			"Stufe %d: alles erreichbar, der Boss liegt am Ende des Gangs (%d Felder)" % [stufe, dist[map.boss_cell]])
	var karte := DungeonGenerator.generate(_card(5, 5), 2)
	var gang_breite := 0
	for y in karte.height:
		if karte.is_floor(Vector2i(karte.spawn.x + 3, y)):
			gang_breite += 1
	_check(gang_breite == DungeonGenerator.BOSS_GANG_BREITE, "der Gang ist 3 Felder breit (%d)" % gang_breite)
	_check(karte.boss_cell.y < karte.spawn.y - 5 and karte.boss_cell.x > karte.spawn.x + 20,
		"der Gang verläuft nach rechts oben (Spawn %s, Boss %s)" % [karte.spawn, karte.boss_cell])
	var raum_breite := 0
	for y in karte.height:
		if karte.is_floor(Vector2i(karte.boss_cell.x - 3, y)):
			raum_breite += 1
	_check(raum_breite == DungeonGenerator.BOSS_RAUM, "am Ende ein Raum (%d Felder breit)" % raum_breite)
	var a := DungeonGenerator.generate(_card(1, 5), 5)
	var b := DungeonGenerator.generate(_card(99, 5), 5)
	_check(a.cells == b.cells and a.boss_cell == b.boss_cell, "die Boss-Ebene ist immer gleich")


## Die Boss-Figur auf der Boss-Ebene ist derselbe Grundtyp wie der Boss im
## Kampf — über alle Biome, Raritäten, Stufen und legendäre Abschlüsse.
func _test_boss_figur() -> void:
	print("Boss-Figur = Boss im Kampf:")
	var geprueft := 0
	var abweichungen := 0
	var unterschiedlich := {}
	for biome in Enums.Biome.values():
		for rarity in Enums.Rarity.values():
			for stufe in [1, 2, 4, 5, 6, 9, 12, 25]:
				for abschluesse in [0, 2, 5]:
					for seed_value in [11, 4711]:
						var card := _card(seed_value * 13 + stufe * 7 + biome, stufe)
						card.biome = biome
						card.card_rarity = rarity
						card.floor_count = 1 + (seed_value + stufe) % 4
						card.legendary = rarity == Enums.Rarity.LEGENDARY
						card.times_completed = abschluesse
						var ebene := DungeonGenerator.boss_ebene_index(card)
						var figur := EnemyFactory.boss_figur_id(card, ebene)
						var rng := RandomNumberGenerator.new()
						rng.seed = EnemyFactory.encounter_seed(card, ebene, -1)
						var foes := EnemyFactory.make_encounter(card, rng, true, ebene)
						geprueft += 1
						if foes.is_empty() or foes[0].archetype_id != figur:
							abweichungen += 1
						unterschiedlich[figur] = true
	_check(abweichungen == 0, "%d Karten: Figur und Kampf-Boss gleich (%d Abweichungen)" % [geprueft, abweichungen])
	_check(unterschiedlich.size() >= 4, "verschiedene Bosse kommen vor (%d Grundtypen)" % unterschiedlich.size())
	# Startkarte (Stufe 1, gewöhnlich): Fallback = frühester Boss, nie zufällig.
	var start := _card(1, 1)
	var figuren := {}
	for seed_value in 40:
		start.seed = seed_value
		figuren[EnemyFactory.boss_figur_id(start, 0)] = true
	_check(figuren.size() == 1, "Stufe-1-Karten zeigen immer den frühesten Boss (%s)" % [figuren.keys()])


# --- Seltene Ereignisse: Händler und Gefangener (DungeonEreignisse) ----------------

func _test_seltene_ereignisse() -> void:
	print("Seltene Ereignisse (Händler, Gefangener):")
	var ebenen := 0
	var haendler := 0
	var gefangene := 0
	var platz_ok := true
	var ids_ok := true
	for i in 400:
		var karte := _card(70000 + i, 30)
		karte.floor_count = 5
		var map := DungeonGenerator.generate(karte, i % 3)
		ebenen += 1
		var dist := map.distances_from(map.spawn)
		var ids := {}
		var belegt := {map.boss_cell: true, map.stairs_cell: true, map.spawn: true, map.tresor_cell: true}
		for liste in [map.enemies, map.chests]:
			for eintrag in liste:
				belegt[eintrag["cell"]] = true
		for event in map.events:
			ids_ok = ids_ok and not ids.has(int(event["id"]))
			ids[int(event["id"])] = true
			platz_ok = platz_ok and not belegt.has(event["cell"])
			belegt[event["cell"]] = true
			if event["type"] == DungeonGenerator.EventType.HAENDLER:
				haendler += 1
				platz_ok = platz_ok and dist.get(event["cell"], 0) >= DungeonEreignisse.MIN_ABSTAND
			elif event["type"] == DungeonGenerator.EventType.GEFANGENER:
				gefangene += 1
				platz_ok = platz_ok and dist.get(event["cell"], 0) >= DungeonEreignisse.MIN_ABSTAND
	print("  %d Ebenen (Stufe 30): %d Händler, %d Gefangene" % [ebenen, haendler, gefangene])
	_check(haendler > ebenen * 0.12 and haendler < ebenen * 0.25, "Händler auf etwa 18 % der Ebenen")
	_check(gefangene > ebenen * 0.03 and gefangene < ebenen * 0.1, "Gefangener selten (etwa 6 % der Ebenen)")
	_check(platz_ok and ids_ok, "seltene Ereignisse begehbar, mit Abstand, kollisionsfrei, eindeutige IDs")
	var unter := 0
	for i in 200:
		for event in DungeonGenerator.generate(_card(80000 + i, 2)).events:
			if DungeonEreignisse.ist_sonderereignis(event["type"]):
				unter += 1
	_check(unter == 0, "Stufe 1–2: keine Händler oder Gefangenen")
	var boss_karte := _card(4242, 30)
	var boss_map := DungeonGenerator.generate(boss_karte, DungeonGenerator.boss_ebene_index(boss_karte))
	_check(boss_map.events.is_empty(), "Boss-Ebene: keine Ereignisse")
	# Fest je Karte: gleiche Karte, gleiche Ereignisse; normale Ereignisse zuerst.
	var mit := -1
	for i in 400:
		var probe := _card(70000 + i, 30)
		probe.floor_count = 5
		var map := DungeonGenerator.generate(probe, i % 3)
		for event in map.events:
			if event["type"] == DungeonGenerator.EventType.GEFANGENER:
				mit = i
		if mit >= 0:
			break
	var karte_g := _card(70000 + mit, 30)
	karte_g.floor_count = 5
	var m1 := DungeonGenerator.generate(karte_g, mit % 3)
	var m2 := DungeonGenerator.generate(karte_g, mit % 3)
	_check(str(m1.events) == str(m2.events), "seltene Ereignisse fest je Karte und Ebene")
	var normal_zuerst := true
	var sonder_gesehen := false
	for event in m1.events:
		if DungeonEreignisse.ist_sonderereignis(event["type"]):
			sonder_gesehen = true
		elif sonder_gesehen:
			normal_zuerst = false
	_check(normal_zuerst, "normale Ereignisse behalten ihre IDs (seltene hängen hinten an)")

	# Gefangener Held: prozedural, fest je Karte, Level/Werte/Ausrüstung nach Stufe.
	var event_id := -1
	for event in m1.events:
		if event["type"] == DungeonGenerator.EventType.GEFANGENER:
			event_id = int(event["id"])
	var held := DungeonEreignisse.held_erzeugen(karte_g, mit % 3, event_id, 28, ["Aldric"])
	var gleich := DungeonEreignisse.held_erzeugen(karte_g, mit % 3, event_id, 28, ["Aldric"])
	_check(held.display_name == gleich.display_name and held.stats.strength == gleich.stats.strength
		and held.equipment.size() == gleich.equipment.size(), "gleicher Gefangener je Karte/Ebene/Ereignis (%s)" % held.display_name)
	_check(held.is_player and held.level == 28 and held.stat_points == 0, "Level 28, alle Statuspunkte verteilt")
	var summe := 0
	for stat in StatBlock.STAT_NAMES:
		summe += int(held.stats.get(stat))
	_check(summe == 6 * 5 + 27 * held.stat_points_per_level(), "Startwerte: 5 je Wert + Punkte aus 27 Aufstiegen (%d)" % summe)
	var teile_ok := held.equipment.size() >= 4
	for slot in held.equipment:
		var item: ItemInstance = held.equipment[slot]
		teile_ok = teile_ok and item.item_level == 28 and item.rarity >= Enums.Rarity.MAGIC and not item.affixes.is_empty()
	_check(teile_ok, "Ausrüstung: %d Teile auf Item-Level 28, mindestens Magisch" % held.equipment.size())
	_check(held.hp == held.max_hp and held.mp == held.max_mp, "volle HP/MP")
	var namen: Array = []
	var namen_ok := true
	for i in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var name := DungeonEreignisse.held_name(rng, namen)
		namen_ok = namen_ok and name not in namen and name.length() >= 3
		namen.append(name)
	_check(namen_ok, "Namen eindeutig gegenüber vergebenen (%s …)" % ", ".join(namen.slice(0, 5)))
	var niedrig := DungeonEreignisse.held_erzeugen(karte_g, 0, 1, 1, [])
	_check(niedrig.level == 1, "Ziel-Level 1 bleibt Level 1")
	var gespeichert := Combatant.from_dict(JSON.parse_string(JSON.stringify(held.to_dict())))
	_check(gespeichert.level == held.level and gespeichert.equipment.size() == held.equipment.size()
		and gespeichert.display_name == held.display_name, "Gefangener übersteht den Speicher-Rundweg")

	# Fahrender Händler: Angebote nach Biom und Stufe, fest je Karte, Tausch.
	var wald := _card(9001, 40)
	wald.biome = Enums.Biome.FOREST
	var hoehle := _card(9001, 40)
	hoehle.biome = Enums.Biome.CAVE
	var a1 := DungeonEreignisse.angebote(wald, 0, 4)
	_check(str(a1) == str(DungeonEreignisse.angebote(wald, 0, 4)), "Angebote fest je Karte/Ebene/Ereignis")
	_check(a1.size() >= 3 and a1[0]["gibt"][0] == MaterialLibrary.werkstoff(&"leder", MaterialLibrary.stufe_fuer_karte(40)),
		"Wald: Händler bietet Leder der Kartenstufe (%s)" % a1[0]["gibt"][0])
	var a2 := DungeonEreignisse.angebote(hoehle, 0, 4)
	_check(a2[0]["gibt"][0] == MaterialLibrary.werkstoff(&"erz", MaterialLibrary.stufe_fuer_karte(40)),
		"Höhle: Händler bietet Erz (%s)" % a2[0]["gibt"][0])
	var trank_da := false
	for angebot in a1:
		trank_da = trank_da or (bool(angebot["trank"]) and ConsumableLibrary.get_def(angebot["gibt"][0]) != null)
	_check(trank_da, "ein Trank-Angebot ist dabei")
	var klein := _card(9001, 4)
	var a3 := DungeonEreignisse.angebote(klein, 0, 4)
	_check(MaterialLibrary.stufe(a3[0]["gibt"][0]) == 1 and a3[2]["gibt"][0] in [&"heiltrank", &"manatrank"],
		"Stufe 4: Eisen-Stufe und einfache Tränke")
	var text := DungeonEreignisse.angebot_text(a1[0])
	_check(text.contains("für") and text.contains("×"), "Angebotstext: %s" % text)
	var state: Node = load("res://autoload/game_state.gd").new()
	var angebot: Dictionary = a1[0]
	_check(not DungeonEreignisse.bezahlbar(angebot, state) and not DungeonEreignisse.tauschen(angebot, state),
		"ohne Material kein Tausch")
	for teil in angebot["nimmt"]:
		state.add_material(teil[0], int(teil[1]))
	_check(DungeonEreignisse.tauschen(angebot, state), "Tausch mit genug Material")
	var preis_weg := true
	for teil in angebot["nimmt"]:
		preis_weg = preis_weg and state.material_count(teil[0]) == 0
	_check(preis_weg and state.material_count(angebot["gibt"][0]) == int(angebot["gibt"][1]),
		"Preis abgezogen, Ware erhalten")
	var trank_angebot: Dictionary = a1[2]
	for teil in trank_angebot["nimmt"]:
		state.add_material(teil[0], int(teil[1]))
	_check(DungeonEreignisse.tauschen(trank_angebot, state)
		and state.consumable_count(trank_angebot["gibt"][0]) == int(trank_angebot["gibt"][1]), "Trank-Tausch gibt Tränke")
	state.free()
	# Texte DE/EN.
	_check(not DungeonGenerator.ereignis_hinweis(DungeonGenerator.EventType.HAENDLER, "E").is_empty()
		and not DungeonGenerator.ereignis_hinweis(DungeonGenerator.EventType.GEFANGENER, "E").is_empty(),
		"Hinweise für Händler und Gefangenen")
	Loc.set_language("en")
	var en := DungeonGenerator.ereignis_hinweis(DungeonGenerator.EventType.GEFANGENER, "E") + " " \
		+ DungeonEreignisse.angebot_text(a1[0])
	Loc.set_language("de")
	_check(en.begins_with("Captive hero") and en.contains(" for "), "Texte englisch: %s" % en)
	# Getauschte Angebote überstehen Speichern/Laden (kein zweiter Tausch).
	var gs: Node = load("res://autoload/game_state.gd").new()
	var lauf := {"card": wald, "haendler_genutzt": {"1004": [0, 2]},
		"defeated": [DungeonEreignisse.WAECHTER_ID + 1007]}
	var zurueck: Dictionary = gs._run_from_dict(JSON.parse_string(JSON.stringify(gs._run_to_dict(lauf))))
	_check(zurueck.get("haendler_genutzt", {}).get("1004", []) == [0, 2]
		and DungeonEreignisse.WAECHTER_ID + 1007 in zurueck["defeated"],
		"Händler-Tausch und besiegte Wächter überstehen den Speicher-Rundweg")
	var alt_lauf: Dictionary = gs._run_from_dict(JSON.parse_string(JSON.stringify(gs._run_to_dict({"card": wald}))))
	_check(not alt_lauf.has("haendler_genutzt"), "alter Lauf ohne Händler lädt")
	gs.free()
