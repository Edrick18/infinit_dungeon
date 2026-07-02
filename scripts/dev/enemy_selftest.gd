extends SceneTree
## Headless-Selbsttest für den Gegner-Baukasten:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/enemy_selftest.gd

var failures := 0


func _init() -> void:
	_test_library()
	_test_build()
	_test_modifiers()
	_test_encounters()
	_test_boss()
	if failures == 0:
		print("SELFTEST OK — alle Gegner-Baukasten-Tests bestanden")
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


func _card(seed_value: int, tier: int, biome: Enums.Biome,
		modifier_ids: Array[StringName] = []) -> DungeonCard:
	var card := DungeonCard.new()
	card.seed = seed_value
	card.tier = tier
	card.biome = biome
	card.modifier_ids = modifier_ids
	return card


func _test_library() -> void:
	print("Gegner-Bibliothek:")
	_check(EnemyLibrary.all_archetypes().size() >= 7, "mindestens 7 Archetypen")
	_check(EnemyLibrary.all_modifiers().size() >= 6, "mindestens 6 Modifikatoren")
	for biome in [Enums.Biome.FOREST, Enums.Biome.CAVE, Enums.Biome.RUINS, Enums.Biome.CRYPT]:
		_check(not EnemyLibrary.archetypes_for_biome(biome).is_empty(),
			"Biom %d hat Archetypen" % biome)
		_check(not EnemyLibrary.archetypes_for_biome(biome, true).is_empty(),
			"Biom %d hat Boss-Kandidaten" % biome)

	var rolled := EnemyLibrary.roll_modifiers(1, _rng(9))
	var tier_ok := true
	for id in rolled:
		if EnemyLibrary.get_modifier(id).min_tier > 1:
			tier_ok = false
	_check(rolled.size() >= 1 and tier_ok, "roll_modifiers respektiert min_tier")


func _test_build() -> void:
	print("Gegner bauen:")
	var wolf_archetype: EnemyArchetype = EnemyLibrary.archetypes_for_biome(Enums.Biome.FOREST)[0]
	var tier1 := EnemyFactory.build(wolf_archetype, 1, _rng(1))
	var tier5 := EnemyFactory.build(wolf_archetype, 5, _rng(1))
	_check(tier1.display_name == wolf_archetype.display_name, "Name ohne Modifikatoren = Archetyp")
	_check(tier5.max_hp > tier1.max_hp, "Tier 5 hat mehr HP als Tier 1")
	_check(not tier1.skills.is_empty(), "Gegner bekommt Skills aus dem Pool")
	_check(tier1.armor == wolf_archetype.armor, "Rüstung vom Archetyp übernommen")


func _test_modifiers() -> void:
	print("Elite-Modifikatoren:")
	var archetype: EnemyArchetype = EnemyLibrary.archetypes_for_biome(Enums.Biome.FOREST)[0]
	var armored: Array[EnemyModifier] = [EnemyLibrary.get_modifier(&"gepanzert")]
	var plain := EnemyFactory.build(archetype, 1, _rng(1))
	var elite := EnemyFactory.build(archetype, 1, _rng(1), armored)
	_check(elite.armor == plain.armor + 4, "Gepanzert: +4 Rüstung")
	_check(elite.max_hp == roundi(plain.max_hp * 1.2), "Gepanzert: 20% mehr HP")
	_check("Gepanzert" in elite.display_name, "Modifikator steht im Namen")

	var burning: Array[EnemyModifier] = [EnemyLibrary.get_modifier(&"brennend")]
	var fiery := EnemyFactory.build(archetype, 1, _rng(1), burning)
	_check(fiery.skills.size() == plain.skills.size() + 1, "Brennend: verleiht Zusatz-Skill")


func _test_encounters() -> void:
	print("Encounter:")
	var mods: Array[StringName] = [&"gepanzert", &"schnell"]
	var card := _card(777, 2, Enums.Biome.FOREST, mods)
	var group_a := EnemyFactory.make_encounter(card, _rng(55))
	var group_b := EnemyFactory.make_encounter(card, _rng(55))
	_check(group_a.size() == group_b.size(), "gleicher Seed → gleiche Gruppengröße")
	var same := true
	for i in group_a.size():
		if group_a[i].display_name != group_b[i].display_name:
			same = false
	_check(same, "gleicher Seed → identische Gruppe (Kern des Karten-Farmens)")
	_check(group_a.size() >= 1 and group_a.size() <= 3, "Gruppengröße 1-3")

	var biome_ok := true
	for i in 20:
		for enemy in EnemyFactory.make_encounter(_card(i, 1, Enums.Biome.CRYPT), _rng(i)):
			if enemy.display_name.begins_with("Waldwolf") or enemy.display_name.begins_with("Urwaldbär"):
				biome_ok = false
	_check(biome_ok, "Krypta-Encounter enthalten keine Wald-Gegner")

	var elite_found := false
	for i in 40:
		for enemy in EnemyFactory.make_encounter(_card(i, 2, Enums.Biome.FOREST, mods), _rng(i * 3)):
			if "[" in enemy.display_name:
				elite_found = true
	_check(elite_found, "Elite-Gegner mit Karten-Modifikator tauchen auf")


func _test_boss() -> void:
	print("Boss:")
	var mods: Array[StringName] = [&"brennend"]
	var card := _card(4242, 3, Enums.Biome.FOREST, mods)
	var bosses := EnemyFactory.make_encounter(card, _rng(1), true)
	_check(bosses.size() == 1, "Boss-Encounter hat genau einen Gegner")
	var boss := bosses[0]
	_check(boss.display_name.begins_with("Boss: "), "Boss-Namenspräfix")
	_check("Brennend" in boss.display_name, "Boss trägt die Karten-Modifikatoren")

	var normal_rng := _rng(1)
	var pool := EnemyLibrary.archetypes_for_biome(card.biome, true)
	var archetype := pool[normal_rng.randi_range(0, pool.size() - 1)]
	var normal := EnemyFactory.build(archetype, card.tier, normal_rng,
		[EnemyLibrary.get_modifier(&"brennend")])
	_check(boss.max_hp > normal.max_hp, "Boss hat deutlich mehr HP als Normalform")