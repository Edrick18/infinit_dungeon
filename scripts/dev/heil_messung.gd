extends SceneTree
## Messwerkzeug (kein Test): Wie stark ist Heilung im Verhältnis zu Max-HP und
## Gegnerschaden über die Level? Heiler (INT/SPI) heilt einen Tank (VIT/STR),
## beide mit Ausrüstung auf ihrem Level; Gegner einer Karte derselben Stufe.
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/heil_messung.gd

const LEVEL := [1, 10, 25, 50, 75, 100]


func _init() -> void:
	print("Level | Heilung | % Tank-HP | Gegner-Treffer % Tank-HP | Heilung / Treffer | Zauber % Gegner-HP")
	for level in LEVEL:
		_messen(level)
	quit(0)


func _held(name: String, level: int, anteile: Dictionary, gear: Array) -> Combatant:
	var stats := StatBlock.new()
	for stat in StatBlock.STAT_NAMES:
		stats.set(stat, 5)
	var punkte := 0
	for l in range(2, level + 1):
		punkte += Combatant.stat_points_for_level(l, 0)
	for stat in anteile:
		stats.set(stat, stats.get(stat) + roundi(punkte * anteile[stat]))
	var held := Combatant.create(name, stats, true)
	held.level = level
	held.peak_level = level
	for id in gear:
		held.equip(ItemLibrary.make_item(id, level))
	held.recompute_derived()
	held.hp = held.max_hp
	held.mp = held.max_mp
	return held


func _skill(ids: Array) -> Skill:
	var skill := Skill.new()
	for id in ids:
		skill.blocks.append(BlockLibrary.get_block(id))
	return skill


func _messen(level: int) -> void:
	var heiler := _held("Heiler", level, {&"intelligence": 0.4, &"spirit": 0.4, &"vitality": 0.2},
		[&"heiligstab", &"robe_heil"])
	var tank := _held("Tank", level, {&"vitality": 0.6, &"strength": 0.4},
		[&"schwert", &"ruestung_schwer", &"helm_schwer"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + level
	var karte := CardFactory.make_card(level, rng)
	var gegner := EnemyFactory.make_encounter(karte, rng, false)

	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = 1
	battle.start([heiler, tank] as Array[Combatant], gegner)
	heiler.mp = 99999

	# Heilung auf den verwundeten Tank.
	tank.hp = 1
	battle.use_skill(heiler, _skill([&"src_spell", &"elem_holy", &"form_ally"]), tank)
	var heilung := tank.hp - 1

	# Durchschnittlicher Gegner-Treffer auf den Tank.
	var summe := 0
	for foe in gegner:
		tank.hp = tank.max_hp
		battle.basic_attack(foe, tank)
		summe += tank.max_hp - tank.hp
	var treffer := float(summe) / maxi(1, gegner.size())

	# Reiner Zauber des Heilers gegen den ersten Gegner (Vergleich Schaden;
	# Feuer wäre Brand über Zeit und hier nicht sichtbar).
	var ziel: Combatant = gegner[0]
	ziel.hp = ziel.max_hp
	heiler.mp = 99999
	battle.use_skill(heiler, _skill([&"src_spell"]), ziel)
	var feuer := ziel.max_hp - ziel.hp

	print("%5d | %7d | %8.0f %% | %10.0f %% | %13.1f | %8.0f %%" % [level, heilung,
		100.0 * heilung / tank.max_hp, 100.0 * treffer / tank.max_hp,
		heilung / maxf(1.0, treffer), 100.0 * feuer / maxi(1, ziel.max_hp)])
