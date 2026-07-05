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
	_test_slime_god()
	_test_metal_slime()
	_test_reinforcements()
	_test_floor_scaling()
	_test_chest_depth()
	_test_grotto_names()
	_test_legendary_cards()
	_test_themed_materials()
	_test_concentrate()
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


## Baut einen Trupp identischer Schleim-Familienmitglieder (ohne Varianten).
func _plain_slimes(archetype_id: StringName, count: int, tier := 3) -> Array[Combatant]:
	var archetype := EnemyLibrary.get_archetype(archetype_id)
	var result: Array[Combatant] = []
	var attempt := 0
	while result.size() < count and attempt < 200:
		attempt += 1
		var slime := EnemyFactory.build(archetype, tier, _rng(500 + attempt))
		if slime.display_name == archetype.display_name:  # keine Metall-/Gift-Variante
			result.append(slime)
	return result


func _test_slime_stack() -> void:
	print("Schleim-Evolutionskette (DQ-Prinzip):")
	_check(EnemyLibrary.get_archetype(&"schleimstapel") != null
		and EnemyLibrary.get_archetype(&"koenigschleim") != null
		and EnemyLibrary.get_archetype(&"schleimgott") != null,
		"Schleimstapel, König-Schleim und Schleimgott existieren als Archetypen")
	_check(EnemyLibrary.get_archetype(&"schleimgott").boss_only,
		"der Schleimgott spawnt NUR als Boss")
	var normal_pool := EnemyLibrary.archetypes_for_biome(Enums.Biome.CAVE, false, 99)
	var god_in_pool := false
	for archetype in normal_pool:
		if archetype.id == &"schleimgott":
			god_in_pool = true
	_check(not god_in_pool, "Schleimgott taucht nie in normalen Encountern auf")

	# Stufe 1: drei Schleime → Schleimstapel.
	var slimes := _plain_slimes(&"schleim", 3)
	var total_hp := 0
	for slime in slimes:
		total_hp += slime.hp
	var battle := _battle([_hero()], slimes, 3)
	var merged := false
	for i in 30:
		if battle._try_slime_merge(slimes[0]):
			merged = true
			break
	_check(merged, "drei Schleime stapeln sich")
	var stack: Combatant = battle.enemies[0]
	_check(stack.display_name == "Schleimstapel", "das Ergebnis ist ein SCHLEIMSTAPEL")
	_check(stack.hp == mini(stack.max_hp, total_hp),
		"die HP der Teile bleiben erhalten (gedeckelt): %d" % stack.hp)
	_check(battle.enemies.size() == 1, "die verschmolzenen Schleime sind vom Feld")
	_check(stack.loot_mult >= 3.0, "der Stapel trägt die Beute aller drei")

	# Stufe 2: zwei Schleimstapel → König-Schleim.
	var stacks := _plain_slimes(&"schleimstapel", 2, 5)
	var battle2 := _battle([_hero()], stacks, 3)
	var king_merged := false
	for i in 30:
		if battle2._try_slime_merge(stacks[0]):
			king_merged = true
			break
	_check(king_merged and battle2.enemies[0].display_name == "König-Schleim",
		"zwei Schleimstapel türmen sich zum KÖNIG-SCHLEIM")

	# Stufe 3: zwei Könige → Schleimgott.
	var kings := _plain_slimes(&"koenigschleim", 2, 9)
	var battle3 := _battle([_hero()], kings, 3)
	var god_merged := false
	for i in 30:
		if battle3._try_slime_merge(kings[0]):
			god_merged = true
			break
	_check(god_merged and battle3.enemies[0].display_name == "Schleimgott",
		"zwei König-Schleime verschmelzen zum SCHLEIMGOTT")

	# Ein einzelner Schleim stapelt nicht.
	var lonely := _plain_slimes(&"schleim", 1)
	var battle4 := _battle([_hero()], lonely, 3)
	var lonely_merged := false
	for i in 30:
		if battle4._try_slime_merge(lonely[0]):
			lonely_merged = true
	_check(not lonely_merged, "ein einzelner Schleim bleibt ein Schleim")


func _test_slime_god() -> void:
	print("Schleimgott-Boss (ruft Schleime und verschlingt sie):")
	var god := EnemyFactory.build(EnemyLibrary.get_archetype(&"schleimgott"), 10, _rng(1))
	god.is_boss = true
	god.boss_signature = &"verschlingen"
	god.boss_add_id = &"schleim"
	god.charge_cooldown = 99
	var snack := _plain_slimes(&"schleim", 1, 10)[0]
	var battle := _battle([_hero()], [god, snack], 3)
	god.hp = roundi(god.max_hp * 0.5)
	var hp_before := god.hp
	var consumed := battle._boss_pre_turn(god)
	_check(consumed, "Verschlingen verbraucht den Zug")
	_check(god.hp > hp_before, "der Gott heilt sich um die HP des Schleims")
	_check(god.has_status(Enums.Status.ATK_UP), "… und wird dauerhaft stärker")
	_check(battle.enemies.size() == 1, "der verschlungene Schleim ist vom Feld")


func _test_metal_slime() -> void:
	print("Metallschleim (XP-Jackpot, DQ-Prinzip):")
	var slime_archetype := EnemyLibrary.get_archetype(&"schleim")
	var metal: Combatant = null
	for i in 300:
		var candidate := EnemyFactory.build(slime_archetype, 5, _rng(i))
		if candidate.display_name == "Metallschleim":
			metal = candidate
			break
	_check(metal != null, "Metallschleime spawnen als Variante")
	_check(metal.xp_mult >= 8.0, "Metallschleim: 8-fache Erfahrung")
	_check(metal.flee_chance > 0.0, "Metallschleim flüchtet gern")
	_check(metal.armor >= 35, "Metallschleim ist fast unverwundbar (Rüstung %d)" % metal.armor)
	_check(metal.max_hp < 15, "… hat dafür kaum HP (%d)" % metal.max_hp)

	# Flucht: verschwindet aus dem Kampf (kein XP, keine Beute).
	var hero := _hero()
	var battle := _battle([hero], [metal], 7)
	var fled := false
	for i in 40:
		if battle._try_flee(metal):
			fled = true
			break
	_check(fled, "Metallschleim entwischt irgendwann")
	_check(not battle.enemies.has(metal), "der Flüchtige ist aus dem Kampf verschwunden")


func _test_reinforcements() -> void:
	print("Verstärkung rufen (Rudeltiere):")
	var wolf := EnemyFactory.build(EnemyLibrary.get_archetype(&"wolf"), 3, _rng(4))
	_check(wolf.can_call_reinforcements, "Wölfe können Verstärkung rufen")
	# Jeder Gegner würfelt nur EINMAL (25%) — über viele Wölfe ruft einer.
	var called_battle: Battle = null
	var caller: Combatant = null
	for i in 60:
		var candidate := EnemyFactory.build(EnemyLibrary.get_archetype(&"wolf"), 3, _rng(4))
		var battle := _battle([_hero()], [candidate], 100 + i)
		if battle._try_call_reinforcements(candidate):
			called_battle = battle
			caller = candidate
			break
	_check(called_battle != null, "manche Wölfe rufen Verstärkung (25%-Wurf)")
	_check(called_battle.enemies.size() == 2, "ein zweiter Gegner erscheint")
	_check(called_battle.enemies[1].archetype_id == &"wolf", "die Verstärkung ist ein Artgenosse")
	_check(called_battle.enemies[1].reinforcement_called,
		"Gerufene rufen nicht weiter (Kettenschutz)")
	var again := false
	for i in 60:
		if called_battle._try_call_reinforcements(caller):
			again = true
	_check(not again, "jeder Gegner würfelt höchstens EINMAL")

	var bear := EnemyFactory.build(EnemyLibrary.get_archetype(&"baer"), 3, _rng(4))
	_check(not bear.can_call_reinforcements, "Bären rufen keine Verstärkung (Einzelgänger)")


func _test_chest_depth() -> void:
	print("Truhen-Qualität steigt mit der Tiefe (DQ9-Prinzip):")
	var deep_better := 0
	var top_better := 0
	for i in 40:
		var card := DungeonCard.new()
		card.seed = i * 17 + 3
		card.tier = 9
		card.floor_count = 3
		var top := DungeonGenerator.generate(card, 0)
		var deep := DungeonGenerator.generate(card, 2)
		for chest in top.chests:
			top_better += int(chest["rarity"])
		for chest in deep.chests:
			deep_better += int(chest["rarity"])
	_check(deep_better > top_better,
		"unterste Ebene hat im Schnitt bessere Truhen (%d > %d Raritätspunkte)"
		% [deep_better, top_better])


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

func _test_legendary_cards() -> void:
	print("Legendäre Karten (Legacy-Boss levelt pro Abschluss):")
	var found := 0
	for i in 300:
		if CardFactory.make_card(8, _rng(i * 13 + 1)).legendary:
			found += 1
	_check(found > 0 and found < 60,
		"legendäre Karten sind selten, aber existieren (%d/300)" % found)
	var low_found := false
	for i in 200:
		if CardFactory.make_card(2, _rng(i)).legendary:
			low_found = true
	_check(not low_found, "unter Stufe 4 gibt es keine legendären Karten")

	var card := _card(9, 6, Enums.Biome.CAVE)
	card.legendary = true
	card.times_completed = 3
	var fresh := _card(9, 6, Enums.Biome.CAVE)
	var boss := EnemyFactory.make_encounter(card, _rng(2), true)[0]
	var normal_boss := EnemyFactory.make_encounter(fresh, _rng(2), true)[0]
	_check(boss.level == normal_boss.level + 6,
		"3× abgeschlossen → Legacy-Boss ist +6 Stufen (%d vs %d)"
		% [boss.level, normal_boss.level])
	_check(boss.loot_mult > normal_boss.loot_mult, "Legacy-Boss gibt mehr Beute")
	_check(boss.xp_mult > normal_boss.xp_mult, "Legacy-Boss gibt mehr XP")

	# Persistenz: das Legendär-Flag übersteht den Speicher-Rundweg.
	var restored := DungeonCard.from_dict(card.to_dict())
	_check(restored.legendary and restored.legacy_boss_bonus() == 6,
		"Legendär-Flag und Boss-Bonus überstehen den Rundweg")


func _test_themed_materials() -> void:
	print("Themen-Material-Drops (gezieltes Farmen):")
	var wolf := EnemyFactory.build(EnemyLibrary.get_archetype(&"wolf"), 3, _rng(1))
	var slime := EnemyFactory.build(EnemyLibrary.get_archetype(&"schleim"), 3, _rng(1))
	var wolf_leather := 0
	var slime_crystal := 0
	for i in 200:
		if LootGenerator.material_for_enemy(wolf, _rng(i)) == &"lederreste":
			wolf_leather += 1
		if LootGenerator.material_for_enemy(slime, _rng(i + 999)) == &"kristallstaub":
			slime_crystal += 1
	_check(wolf_leather > 100, "Wölfe droppen bevorzugt Lederreste (%d/200)" % wolf_leather)
	_check(slime_crystal > 100, "Schleime droppen bevorzugt Kristallstaub (%d/200)" % slime_crystal)
	var hero := _hero()
	var herbs_possible := false
	for i in 300:
		var material := LootGenerator.material_for_enemy(wolf, _rng(i * 7))
		if material == &"heilkraut" or material == &"manabluete":
			herbs_possible = true
	_check(herbs_possible, "Kräuter droppen weiterhin (globale Tabelle bleibt im Spiel)")


func _test_concentrate() -> void:
	print("Konzentrieren (DQ-Psyche-Up):")
	var hero := _hero()
	var dummy := _hero(40)
	dummy.is_player = false
	var battle := _battle([hero], [dummy], 11)

	battle.concentrate(hero)
	var focus := hero.get_status(Enums.Status.FOCUS)
	_check(not focus.is_empty() and int(focus["potency"]) == 50,
		"einmal konzentrieren: +50%")
	battle.concentrate(hero)
	_check(int(hero.get_status(Enums.Status.FOCUS)["potency"]) == 100,
		"stapelt: zweimal = +100%")
	for i in 10:
		battle.concentrate(hero)
	_check(int(hero.get_status(Enums.Status.FOCUS)["potency"]) == battle.FOCUS_MAX,
		"gedeckelt bei +%d%%" % battle.FOCUS_MAX)

	# Fokussierter Angriff macht mehr Schaden — und verbraucht den Fokus.
	var plain_hero := _hero()
	var plain_dummy := _hero(40)
	plain_dummy.is_player = false
	var plain_battle := _battle([plain_hero], [plain_dummy], 11)
	var hp_a := plain_dummy.hp
	plain_battle.basic_attack(plain_hero, plain_dummy)
	var normal_damage := hp_a - plain_dummy.hp

	var hp_b := dummy.hp
	battle.basic_attack(hero, dummy)
	var focused_damage := hp_b - dummy.hp
	_check(focused_damage > normal_damage * 2,
		"voll fokussiert schlägt deutlich härter (%d vs %d)" % [focused_damage, normal_damage])
	_check(not hero.has_status(Enums.Status.FOCUS), "der Fokus ist nach dem Angriff verbraucht")
