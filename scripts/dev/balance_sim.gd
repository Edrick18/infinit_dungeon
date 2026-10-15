extends SceneTree
## Balancing-Simulation: spielt Auto-Kämpfe und komplette Dungeon-Läufe
## (Party Level L vs. Karte Stufe T) und druckt eine Ergebnistabelle.
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/balance_sim.gd
## Kein Test (kein OK/FEHLER) — ein Werkzeug, um Skalierungs-Schrauben zu prüfen.
## Env-Schalter: BOSS=1 (Boss-Tabelle, mit STUFEN=40,50,60 eigene Stufen),
## BOSSDIAG=1 (Sieg-% je Boss-Typ; NACH=mods gruppiert nach Modifikatoren),
## KURVE=1 (Schaden Party↔Boss pro Runde je Level), PARTY=1, DIAG=1, EXTREME=1.

const RUNS_PER_CELL := 60
const BATTLES_PER_RUN := 6  ## normale Kämpfe vor dem Boss
const MAX_TURNS := 400


func _init() -> void:
	print("Party-Level vs. Kartenstufe — %d Läufe pro Zelle" % RUNS_PER_CELL)
	print("Lauf = %d Kämpfe + Boss, Verschnaufen +25%% nach Siegen, keine Tränke" % BATTLES_PER_RUN)
	print("")
	print("  L=Level T=Tier | Einzelkampf% | Lauf geschafft% | Ø Runden/Kampf")
	var pairs := [[1, 1], [3, 3], [5, 5], [8, 8], [12, 12], [5, 3], [5, 8], [10, 13],
			# Endgame-Zellen (Exponential-Skalierung): hält die Balance auch
			# auf hohen Stufen? [Level, Kartenstufe] — Gear = eigenes Level.
			[25, 25], [50, 50], [100, 100], [200, 200],
			# Karte über dem eigenen Stand » muss spürbar wehtun.
			[50, 60], [100, 120]]
	# EXTREME=1: das Level-1000-Ziel gegenrechnen (dauert etwas länger).
	if OS.get_environment("EXTREME") == "1":
		pairs += [[400, 400], [700, 700], [1000, 1000]]
	# BOSS=1: Gegner-Druck pro Kartenstufe — normale Kämpfe vs. Boss (DQ9-Prinzip:
	# normale Gegner sind Alltag, der Boss ist die Hürde).
	if OS.get_environment("KURVE") == "1":
		_kurve()
		quit(0)
		return
	if OS.get_environment("BOSSDIAG") == "1":
		_boss_diagnose()
		quit(0)
		return
	if OS.get_environment("BOSS") == "1":
		_boss_tabelle()
		quit(0)
		return
	# PARTY=1: zeigt, womit die Sim-Party auf einigen Leveln antritt.
	if OS.get_environment("PARTY") == "1":
		for lv in [5, 25, 100]:
			_party_zeigen(lv)
	for pair in pairs:
		_simulate_cell(pair[0], pair[1])
	quit(0)


func _simulate_cell(level: int, tier: int) -> void:
	var battle_wins := 0
	var battle_total := 0
	var runs_completed := 0
	var rounds_total := 0

	for i in RUNS_PER_CELL:
		var rng := RandomNumberGenerator.new()
		rng.seed = 100000 + i * 977 + level * 13 + tier
		var card := CardFactory.make_card(tier, rng)
		# Gear entspricht dem eigenen Fortschritt (Level), nicht der Karte.
		var party := _make_party(level, level)
		var run_alive := true

		# Diagnose (per Env DIAG=1): Kennzahlen der ersten Begegnung.
		if i == 0 and OS.get_environment("DIAG") == "1":
			var probe_rng := RandomNumberGenerator.new()
			probe_rng.seed = rng.seed
			var probe := EnemyFactory.make_encounter(card, probe_rng)
			var hero := party[1]  # der Schadens-Held
			var foe := probe[0]
			var battle := Battle.new()
			battle.start(party, probe)
			print("    DIAG Held: HP %d  Rüstung %d  Waffe %d  STR %d » Netto an Gegner: %d" % [
				hero.max_hp, hero.total_armor(), hero.weapon_damage(), hero.stat(&"strength"),
				battle.preview_mitigated(hero, foe,
					float(Battle.BASIC_ATTACK_BASE + hero.stat(&"strength") + hero.weapon_damage()),
					Enums.DamageAxis.PHYSICAL, hero.weapon_subtypes())])
			print("    DIAG Gegner (%s ×%d): HP %d  Rüstung %d  Waffe %d  STR %d » Netto an Held: %d" % [
				foe.display_name, probe.size(), foe.max_hp, foe.armor,
				foe.innate_weapon_damage, foe.stat(&"strength"),
				battle.preview_mitigated(foe, hero,
					float(Battle.BASIC_ATTACK_BASE + foe.stat(&"strength") + foe.weapon_damage()),
					Enums.DamageAxis.PHYSICAL, foe.weapon_subtypes())])

		for battle_index in BATTLES_PER_RUN + 1:
			var is_boss := battle_index == BATTLES_PER_RUN
			var foes := EnemyFactory.make_encounter(card, rng, is_boss)
			var result := _run_battle(party, foes, rng.randi())
			battle_total += 1
			rounds_total += result["rounds"]
			if result["won"]:
				battle_wins += 1
				for member in party:
					member.statuses.clear()
					member.hp = maxi(member.hp, 1)
					member.heal(roundi(member.max_hp * 0.25))
					member.mp = mini(member.max_mp, member.mp + roundi(member.max_mp * 0.25))
			else:
				run_alive = false
				break
		if run_alive:
			runs_completed += 1

	print("  L%2d vs T%2d    |      %5.1f%%  |         %5.1f%%  |  %5.1f" % [
		level, tier,
		100.0 * battle_wins / battle_total,
		100.0 * runs_completed / RUNS_PER_CELL,
		float(rounds_total) / battle_total,
	])


func _run_battle(party: Array[Combatant], foes: Array[Combatant], seed_value: int) -> Dictionary:
	var battle := Battle.new()
	battle.rng.seed = seed_value
	for member in party:
		member.statuses.clear()
	battle.start(party, foes)
	var turns := 0
	while not battle.is_over and turns < MAX_TURNS:
		var actor := battle.next_turn()
		if actor == null:
			break
		# Gegenspiel wie echte Spieler: kündigt ein Boss seinen Spezialangriff
		# an, geht die Party in Verteidigungshaltung.
		if actor.is_player and _boss_is_charging(battle):
			battle.defend(actor)
		else:
			battle.ai_take_turn(actor)
		turns += 1
	# Sieg = Kampf vorbei und die Party lebt — geflohene Gegner (Güldene,
	# Metallschleime) zählen wie im Spiel als Sieg, nicht als Niederlage.
	return {"won": battle.is_over and not battle._living(party).is_empty(),
		"rounds": battle.round_number}


func _boss_is_charging(battle: Battle) -> bool:
	for enemy in battle.enemies:
		if enemy.is_alive() and enemy.charge_active:
			return true
	return false


## Typische 4er-Party auf Level L (Skillbau 3.0, 2026-10-15): Tank, Axt-
## Kämpfer, Magier, Heiler — volle Ausrüstung auf eigenem Level (Selten mit
## zufälligen Affixen), Waffen-Training in die eigene Waffe, Skills nur aus
## freigeschalteten Klötzen innerhalb der Sockel. Gear-Level = `tier`.
func _make_party(level: int, tier: int) -> Array[Combatant]:
	var gear_rng := RandomNumberGenerator.new()
	gear_rng.seed = level * 7919 + tier

	var tank := _hero("Tank", level, {&"vitality": 0.5, &"strength": 0.3, &"agility": 0.2})
	_ausruesten(tank, tier, gear_rng, [&"schwert", &"schild", &"ruestung_schwer", &"helm_schwer",
		&"handschuhe_schwer", &"stiefel_schwer", &"ring", &"ring", &"amulett"])
	_trainieren(tank, [&"schild", &"schwert"])
	tank.skills = _skills(tank, [
		[&"src_spell", &"form_self", &"eff_protect"],
		[&"src_weapon", &"tech_konter", &"mod_wucht"],
		[&"src_weapon", &"tech_duellstoss", &"mod_praezision"],
	])

	var axt := _hero("Axt", level, {&"strength": 0.5, &"agility": 0.3, &"vitality": 0.2})
	_ausruesten(axt, tier, gear_rng, [&"axt", &"ruestung_mittel", &"helm_leicht",
		&"handschuhe_leicht", &"stiefel_leicht", &"ring", &"ring", &"amulett"])
	_trainieren(axt, [&"axt", &"bogen"])
	axt.skills = _skills(axt, [
		[&"src_weapon", &"tech_kopfspalter", &"mod_praezision", &"mod_execute"],
		[&"src_weapon", &"form_aoe", &"mod_wucht"],
		[&"src_weapon", &"elem_fire", &"mod_treffer"],
	])

	var mage := _hero("Magier", level, {&"intelligence": 0.5, &"spirit": 0.3, &"vitality": 0.2})
	_ausruesten(mage, tier, gear_rng, [&"offensivstab", &"zauberbuch", &"robe_schaden", &"helm_leicht",
		&"handschuhe_leicht", &"stiefel_leicht", &"ring", &"ring", &"amulett"])
	_trainieren(mage, [&"offensivstab", &"heiligstab"])
	mage.skills = _skills(mage, [
		[&"src_spell", &"elem_fire", &"form_aoe", &"tech_elementfokus", &"mod_overload"],
		[&"src_spell", &"elem_ice", &"mod_praezision", &"mod_overload"],
		[&"src_spell", &"elem_lightning", &"mod_treffer", &"mod_ziel_wechsel"],
	])

	var heiler := _hero("Heiler", level, {&"spirit": 0.4, &"intelligence": 0.35, &"vitality": 0.25})
	_ausruesten(heiler, tier, gear_rng, [&"heiligstab", &"relikt", &"robe_heil", &"helm_leicht",
		&"handschuhe_leicht", &"stiefel_leicht", &"ring", &"ring", &"amulett"])
	_trainieren(heiler, [&"heiligstab", &"offensivstab"])
	heiler.skills = _skills(heiler, [
		[&"src_spell", &"elem_holy", &"form_ally", &"mod_vollheilung"],
		[&"src_spell", &"elem_holy", &"form_aura", &"eff_regen"],
		[&"src_spell", &"form_aura", &"eff_atk_up", &"eff_def_up"],
		[&"src_spell", &"elem_holy", &"form_ally"],
	])

	for held in [tank, axt, mage, heiler]:
		held.recompute_derived()
		held.hp = held.max_hp
		held.mp = held.max_mp
	return [tank, axt, mage, heiler]


## Alle Skillpunkte in die Gattungen (der Reihe nach, je höchstens 100);
## die Meisterschaft des ersten vollen Baums kommt in den Slot.
func _trainieren(hero: Combatant, gattungen: Array) -> void:
	hero.skill_points = Combatant.skill_punkte_bis(hero.level)
	for gattung in gattungen:
		hero.invest_point(gattung, mini(100, hero.skill_points))
	for gattung in gattungen:
		if hero.invested(gattung) >= 100:
			hero.meisterschaft = gattung
			break


## Skills wie ein Spieler sie bauen würde: pro Rezept nur Klötze, die schon
## freigeschaltet sind, und nur so viele, wie Sockel da sind (Reihenfolge =
## Wichtigkeit). Rezepte ohne Quelle oder ungültige fallen weg.
func _skills(hero: Combatant, rezepte: Array) -> Array[Skill]:
	var result: Array[Skill] = []
	for rezept in rezepte:
		var skill := Skill.new()
		skill.display_name = "Sim"
		for id in rezept:
			var block := BlockLibrary.get_block(id)
			if block == null or skill.blocks.size() >= hero.block_sockets():
				continue
			if not BlockLibrary.is_unlocked(block, hero.level, [], hero):
				continue
			skill.blocks.append(block)
			if not skill.is_valid(hero):
				skill.blocks.pop_back()
		if not skill.get_sources().is_empty() and skill.is_valid(hero) \
				and result.size() < hero.skill_slots():
			result.append(skill)
	return result


## Ausrüstung auf eigenem Level, Rarität Selten mit zufälligen Affixen.
## Basen, die es auf dem Level noch nicht gibt, fallen weg.
func _ausruesten(hero: Combatant, level: int, rng: RandomNumberGenerator, ids: Array) -> void:
	for id in ids:
		var base := ItemLibrary.get_base(id)
		if base == null or base.min_tier > level:
			continue
		var item := ItemInstance.new()
		item.base = base
		item.item_level = level
		item.rarity = Enums.Rarity.RARE
		LootGenerator.apply_random_affixes(item, rng)
		hero.equip(item)


func _hero(name: String, level: int, weights: Dictionary) -> Combatant:
	var stats := StatBlock.new()
	for stat in StatBlock.STAT_NAMES:
		stats.set(stat, 5)
	# Punkte wie ein fleißiger Spieler: echte Kurve (ab Level 100 wachsend).
	# PREP=1 simuliert zusätzlich eine Wiedergeburt pro 100 Level
	# (+1 Punkt/Level je Leben) — die „alles ausgekitzelt“-Schätzung.
	var rebirths := level / 100 if OS.get_environment("PREP") == "1" else 0
	var points := 0
	for l in range(2, level + 1):
		points += Combatant.stat_points_for_level(l, rebirths)
	var spent := 0
	for stat in weights:
		var share := int(points * weights[stat])
		stats.set(stat, stats.get(stat) + share)
		spent += share
	# Rest in den ersten Gewichts-Stat.
	if spent < points:
		var first: StringName = weights.keys()[0]
		stats.set(first, stats.get(first) + points - spent)
	var hero := Combatant.create(name, stats, true)
	hero.level = level
	hero.peak_level = level  # Sockel und Skill-Slots hängen am Höchstlevel
	return hero


func _party_zeigen(level: int) -> void:
	print("  Party auf Level %d:" % level)
	for held in _make_party(level, level):
		var skills: Array[String] = []
		for skill in held.skills:
			var ids: Array[String] = []
			for block in skill.blocks:
				ids.append(String(block.id))
			skills.append("+".join(ids))
		print("    %-7s HP %6d MP %5d  Sockel %d  Training %s  Skills: %s" % [held.display_name, held.max_hp,
			held.max_mp, held.block_sockets(), held.weapon_invest, " | ".join(skills)])



const BOSS_STUFEN := [1, 5, 10, 20, 30, 50, 75, 100, 125, 150, 200]
const BOSS_LAEUFE := 40


## Pro Kartenstufe T (Party-Level = T): normale Kämpfe (Sieg-%, HP-Verlust
## der Party) und der Boss der Karte (letzte Ebene) aus voller Gesundheit —
## einmal auf gleichem Level, einmal mit 10 Leveln Vorsprung (Farmen).
func _boss_tabelle() -> void:
	print("Stufe | normal: Sieg  HP-Verlust | Boss gleiches Lv | Boss +10 Lv | Boss +25 Lv | Ø Runden Boss")
	# STUFEN=40,45,50: eigene Stufen statt der Standard-Liste.
	var stufen: Array = BOSS_STUFEN
	if OS.get_environment("STUFEN") != "":
		stufen = Array(OS.get_environment("STUFEN").split(",")).map(func(t): return int(t))
	for stufe in stufen:
		var normal := _kaempfe(stufe, stufe, false)
		var boss := _kaempfe(stufe, stufe, true)
		var boss_plus := _kaempfe(stufe + 10, stufe, true)
		var boss_plus25 := _kaempfe(stufe + 25, stufe, true)
		print("%5d | %9.0f %%  %8.0f %% | %13.0f %% | %9.0f %% | %9.0f %% | %6.1f" % [stufe,
			normal["sieg"] * 100.0, normal["verlust"] * 100.0, boss["sieg"] * 100.0,
			boss_plus["sieg"] * 100.0, boss_plus25["sieg"] * 100.0, boss["runden"]])


## BOSS_LAEUFE Kämpfe einer Sorte aus voller Gesundheit. Gibt Sieg-Anteil,
## mittleren HP-Verlust der Party (bei Siegen) und Runden zurück.
func _kaempfe(level: int, stufe: int, boss: bool) -> Dictionary:
	var siege := 0
	var verlust := 0.0
	var runden := 0
	for i in BOSS_LAEUFE:
		var rng := RandomNumberGenerator.new()
		rng.seed = 900000 + i * 613 + stufe * 17 + (1 if boss else 0)
		var card := CardFactory.make_card(stufe, rng)
		var party := _make_party(level, level)
		var hp_vorher := 0
		for held in party:
			hp_vorher += held.max_hp
		var foes := EnemyFactory.make_encounter(card, rng, boss, card.floor_count - 1 if boss else 0)
		var ergebnis := _run_battle(party, foes, rng.randi())
		runden += int(ergebnis["rounds"])
		if ergebnis["won"]:
			siege += 1
			var hp_nachher := 0
			for held in party:
				hp_nachher += maxi(0, held.hp)
			verlust += 1.0 - float(hp_nachher) / hp_vorher
	return {"sieg": float(siege) / BOSS_LAEUFE, "verlust": verlust / maxi(1, siege),
		"runden": float(runden) / BOSS_LAEUFE}


## BOSSDIAG=1 (STUFEN=30,50,75): Sieg-% pro Boss-Typ auf gleichem Level —
## zeigt, welcher Boss eine Stufe leicht oder schwer macht.
func _boss_diagnose() -> void:
	var stufen: Array = [30, 50, 75]
	if OS.get_environment("STUFEN") != "":
		stufen = Array(OS.get_environment("STUFEN").split(",")).map(func(t): return int(t))
	for stufe in stufen:
		var je_boss := {}
		for i in 120:
			var rng := RandomNumberGenerator.new()
			rng.seed = 900000 + i * 613 + stufe * 17 + 1
			var card := CardFactory.make_card(stufe, rng)
			var party := _make_party(stufe, stufe)
			var foes := EnemyFactory.make_encounter(card, rng, true, card.floor_count - 1)
			var name := String(foes[0].archetype_id)
			if OS.get_environment("NACH") == "mods":
				name = "%d Modifikatoren, %d Begleiter" % [card.modifier_ids.size(), foes.size() - 1]
			var info: Dictionary = je_boss.get(name, {"n": 0, "sieg": 0, "hp": 0, "str": 0, "runden": 0})
			info["n"] += 1
			info["hp"] += foes[0].max_hp
			info["str"] += maxi(foes[0].stats.strength, foes[0].stats.intelligence)
			var ergebnis := _run_battle(party, foes, rng.randi())
			info["runden"] += int(ergebnis["rounds"])
			if ergebnis["won"]:
				info["sieg"] += 1
			je_boss[name] = info
		var party_hp := 0
		for held in _make_party(stufe, stufe):
			party_hp += held.max_hp
		print("Stufe %d (Party-HP gesamt %d):" % [stufe, party_hp])
		for name in je_boss:
			var info: Dictionary = je_boss[name]
			print("  %-40s %3d Kämpfe  Sieg %3.0f %%  Ø HP %7d  Ø STR/INT %5d  Ø Runden %4.1f" % [name, info["n"],
				100.0 * info["sieg"] / info["n"], info["hp"] / info["n"], info["str"] / info["n"],
				float(info["runden"]) / info["n"]])


## KURVE=1: Wer wächst schneller? Pro Level ein nackter Boss (ohne Karten-
## Modifikatoren, ohne Begleiter) gegen die Party, 3 Runden lang:
## Party-Schaden in % der Boss-HP pro Runde und Boss-Schaden in % der Party-HP.
func _kurve() -> void:
	print("Level | Party » Boss %HP/Runde | Boss » Party %HP/Runde | Sockel | Bäume | Party-HP/Welt | Boss-HP/Welt")
	for level in [10, 20, 25, 30, 35, 40, 45, 50, 55, 60, 70, 80, 90, 100]:
		var aus := 0.0
		var ein := 0.0
		var boss_hp := 0.0
		var party_hp := 0.0
		var n := 30
		var je_held := {}
		for i in n:
			var rng := RandomNumberGenerator.new()
			rng.seed = 700000 + i * 131 + level
			var card := CardFactory.make_card(level, rng)
			card.modifier_ids.clear()
			card.card_affix_ids.clear()
			card.card_rarity = Enums.Rarity.COMMON
			card.legendary = false
			var foes := EnemyFactory.make_encounter(card, rng, true, card.floor_count - 1)
			var boss := foes[0]
			var nur_boss: Array[Combatant] = [boss]
			var party := _make_party(level, level)
			var hp_party := 0
			for held in party:
				hp_party += held.max_hp
			var battle := Battle.new()
			battle.rng.seed = rng.randi()
			battle.start(party, nur_boss)
			var zuege := 0
			while not battle.is_over and battle.round_number <= 3 and zuege < 200:
				var actor := battle.next_turn()
				if actor == null:
					break
				var vorher := boss.hp
				battle.ai_take_turn(actor)
				if actor.is_player:
					je_held[actor.display_name] = je_held.get(actor.display_name, 0.0) 						+ float(vorher - maxi(0, boss.hp)) / boss.max_hp
				zuege += 1
			var runden := maxf(1.0, battle.round_number - 1)
			var rest := 0
			for held in party:
				rest += maxi(0, held.hp)
			aus += (1.0 - float(maxi(0, boss.hp)) / boss.max_hp) / runden
			ein += (1.0 - float(rest) / hp_party) / runden
			boss_hp += boss.max_hp
			party_hp += hp_party
		var anteile: Array[String] = []
		for name in je_held:
			anteile.append("%s %.0f" % [name, 100.0 * je_held[name] / n / 3.0])
		print("      " + "  ".join(anteile))
		var probe := _make_party(level, level)[1]
		var welt := Scaling.factor(level)
		print("%5d | %20.1f %% | %20.1f %% | %6d | %s | %13.0f | %12.0f" % [level, 100.0 * aus / n, 100.0 * ein / n,
			probe.block_sockets(), probe.weapon_invest, party_hp / n / welt, boss_hp / n / welt])
