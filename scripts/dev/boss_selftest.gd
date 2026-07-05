extends SceneTree
## Headless-Selbsttest für Boss-Mechaniken und Schleim-Stapeln:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/boss_selftest.gd

var failures := 0


func _init() -> void:
	_test_boss_setup()
	_test_charge_cycle()
	_test_stun_breaks_charge()
	_test_phases_and_adds()
	_test_signatures()
	_test_slime_stack()
	_test_floor_scaling()
	_test_grotto_names()
	if failures == 0:
		print("SELFTEST OK — alle Boss-/Mechanik-Tests bestanden")
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


func _card(seed_value: int, tier: int, biome: Enums.Biome) -> DungeonCard:
	var card := DungeonCard.new()
	card.seed = seed_value
	card.tier = tier
	card.biome = biome
	return card


func _hero(vitality := 30) -> Combatant:
	var stats := StatBlock.new()
	stats.strength = 8
	stats.vitality = vitality
	stats.agility = 5
	return Combatant.create("Held", stats, true)


func _battle(players: Array[Combatant], foes: Array[Combatant], seed_value := 1) -> Battle:
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = seed_value
	battle.start(players, foes)
	return battle


## Boss eines bestimmten Archetyps mit Mechaniken bauen (Stufe ≥ 3).
func _make_boss(archetype_id: StringName, tier := 5) -> Combatant:
	var boss := EnemyFactory.build(EnemyLibrary.get_archetype(archetype_id), tier, _rng(1))
	boss.is_boss = true
	boss.boss_signature = EnemyFactory.BOSS_SIGNATURES.get(archetype_id, &"")
	boss.charge_cooldown = 4
	boss.boss_add_id = &"wolf"
	if boss.boss_signature == &"steinpanzer":
		boss.armor += EnemyFactory.STONE_ARMOR_BONUS
	boss.max_hp = 200
	boss.hp = 200
	return boss


func _test_boss_setup() -> void:
	print("Boss-Setup (Mechaniken ab Stufe %d):" % EnemyFactory.BOSS_MECHANICS_MIN_TIER)
	var low := EnemyFactory.make_encounter(_card(5, 1, Enums.Biome.FOREST), _rng(2), true)[0]
	_check(not low.is_boss, "Stufe-1-Boss bleibt mechanik-frei (sanfter Einstieg)")
	var high := EnemyFactory.make_encounter(_card(5, 5, Enums.Biome.CAVE), _rng(2), true)[0]
	_check(high.is_boss, "Stufe-5-Boss hat Mechaniken")
	_check(high.boss_add_id != &"", "Boss kennt seinen Add-Archetyp")
	var all_signatures := {}
	for id in EnemyFactory.BOSS_SIGNATURES:
		all_signatures[EnemyFactory.BOSS_SIGNATURES[id]] = true
	_check(all_signatures.size() >= 5, "5 Signature-Mechaniken definiert")


func _test_charge_cycle() -> void:
	print("Aufgeladener Spezialangriff:")
	var boss := _make_boss(&"baer")
	var hero := _hero(30)
	var battle := _battle([hero], [boss])
	# Cooldown runterspielen: Boss handelt 4x → Aufladung beginnt.
	var charged := false
	for i in 10:
		battle.ai_take_turn(boss)
		if boss.charge_active:
			charged = true
			break
	_check(charged, "Boss lädt nach einigen Zügen den Spezialangriff auf")
	var hp_before := hero.hp
	battle.ai_take_turn(boss)  # Entfesselung
	_check(not boss.charge_active, "Aufladung ist nach der Entfesselung verbraucht")
	_check(hero.hp < hp_before, "der entfesselte Angriff trifft die Party hart (−%d HP)"
		% (hp_before - hero.hp))


func _test_stun_breaks_charge() -> void:
	print("Betäubung bricht die Aufladung:")
	var boss := _make_boss(&"troll")
	boss.boss_signature = &""  # Regeneration hier nicht mittesten
	var hero := _hero()
	var battle := _battle([hero], [boss])
	boss.charge_active = true
	boss.add_status(Enums.Status.STUN, 1, 0)
	battle._process_turn_start(boss)
	_check(not boss.charge_active, "Betäubung unterbricht die Aufladung (Gegenspiel!)")


func _test_phases_and_adds() -> void:
	print("Phasen bei 66%/33% + Adds:")
	var boss := _make_boss(&"baer")
	var hero := _hero()
	var battle := _battle([hero], [boss])
	var enemies_before := battle.enemies.size()
	boss.hp = roundi(boss.max_hp * 0.5)  # unter 66%
	battle._check_battle_end()
	_check(boss.boss_phase == 2, "Phase 2 bei ≤66% HP")
	_check(boss.has_status(Enums.Status.ATK_UP), "Phase 2: Boss wird stärker")
	_check(battle.enemies.size() == enemies_before + 1, "Phase 2 ruft einen Add")
	boss.hp = roundi(boss.max_hp * 0.2)  # unter 33%
	battle._check_battle_end()
	_check(boss.boss_phase == 3, "Phase 3 bei ≤33% HP")
	_check(battle.enemies.size() == enemies_before + 2, "Phase 3 ruft den nächsten Add")

	# Adds-Signature (Kultist/Nekromant): doppelt so viele Begleiter.
	var summoner := _make_boss(&"kultist")
	var battle2 := _battle([_hero()], [summoner])
	summoner.hp = roundi(summoner.max_hp * 0.5)
	battle2._check_battle_end()
	_check(battle2.enemies.size() == 3, "Adds-Signature: Phase 2 ruft ZWEI Begleiter")


func _test_signatures() -> void:
	print("Signature-Mechaniken:")
	# Golem: Steinpanzer bricht beim ersten stumpfen Treffer.
	var golem := _make_boss(&"golem")
	var armor_before := golem.armor
	var battle := _battle([_hero()], [golem])
	var blunt: Array[Enums.PhysicalSubtype] = [Enums.PhysicalSubtype.BLUNT]
	battle._deal_damage(battle.players[0], golem, 20.0, Enums.DamageAxis.PHYSICAL, blunt)
	_check(golem.armor == armor_before - EnemyFactory.STONE_ARMOR_BONUS,
		"Steinpanzer: stumpfer Treffer sprengt +%d Rüstung" % EnemyFactory.STONE_ARMOR_BONUS)
	_check(not golem.signature_active, "Steinpanzer bricht nur einmal")

	# Troll: regeneriert — außer unter Brand/Gift.
	var troll := _make_boss(&"troll")
	var battle2 := _battle([_hero()], [troll])
	troll.hp = 100
	battle2._process_turn_start(troll)
	_check(troll.hp > 100, "Troll regeneriert am Zugbeginn")
	troll.hp = 100
	troll.add_status(Enums.Status.BURN, -1, 1)
	battle2._process_turn_start(troll)
	_check(troll.hp <= 100, "Brand stoppt die Troll-Regeneration")

	# Schattenbestie: Haltungswechsel verschiebt Rüstung ↔ Resistenz.
	var beast := _make_boss(&"schattenbestie")
	beast.boss_signature = &"haltung"
	beast.armor += 8
	var battle3 := _battle([_hero()], [beast])
	var armor_start := beast.armor
	battle3._toggle_stance(beast)
	_check(beast.armor < armor_start and beast.magic_resist > 0,
		"Haltungswechsel: Rüstung sinkt, Resistenz steigt")


func _test_slime_stack() -> void:
	print("Schleim-Stapeln (DQ-Prinzip):")
	var slime_archetype := EnemyLibrary.get_archetype(&"schleim")
	var slimes: Array[Combatant] = []
	for i in 3:
		slimes.append(EnemyFactory.build(slime_archetype, 3, _rng(100 + i)))
	var total_hp := 0
	for slime in slimes:
		total_hp += slime.hp
	var hero := _hero()
	var battle := _battle([hero], slimes, 3)
	# Merge erzwingen: so lange würfeln, bis der Stapel steht (35% Chance).
	var merged := false
	for i in 30:
		if battle._try_slime_merge(slimes[0]):
			merged = true
			break
	_check(merged, "drei Schleime stapeln sich")
	var king := slimes[0]
	_check(king.display_name == "König-Schleim", "der Stapel ist ein KÖNIG-SCHLEIM")
	_check(king.hp == total_hp, "die HP aller Schleime addieren sich (%d)" % king.hp)
	_check(battle.enemies.size() == 1, "die verschmolzenen Schleime sind vom Feld")
	_check(king.loot_mult > 1.5, "der König trägt die Beute aller drei")

	# Ein einzelner Schleim stapelt nicht.
	var lonely := EnemyFactory.build(slime_archetype, 3, _rng(200))
	var battle2 := _battle([_hero()], [lonely], 3)
	var lonely_merged := false
	for i in 30:
		if battle2._try_slime_merge(lonely):
			lonely_merged = true
	_check(not lonely_merged, "ein einzelner Schleim bleibt ein Schleim")


func _test_floor_scaling() -> void:
	print("Tiefere Ebenen = stärkere Gegner (DQ9-Prinzip):")
	var card := _card(9, 4, Enums.Biome.CAVE)
	var top := EnemyFactory.make_encounter(card, _rng(5), false, 0)
	var deep := EnemyFactory.make_encounter(card, _rng(5), false, 2)
	_check(deep[0].level == top[0].level + 2,
		"Ebene 3: Gegner sind +2 Stufen (%d → %d)" % [top[0].level, deep[0].level])


func _test_grotto_names() -> void:
	print("Grotten-Namen (DQ9-Stil):")
	var names := {}
	var parts_ok := true
	for i in 30:
		var card := CardFactory.make_card(6, _rng(i * 3))
		names[card.display_name] = true
		if card.display_name.split(" ").size() < 3:
			parts_ok = false
	_check(parts_ok, "Namen haben das Muster 'Adjektiv Ort des …'")
	_check(names.size() >= 10, "Namen sind abwechslungsreich (%d über 30 Karten)" % names.size())
	var starter := CardFactory.make_starter_card()
	_check(starter.display_name == "Stiller Hain der Anfänge", "Startkarte hat ihren festen Namen")
