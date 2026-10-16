extends SceneTree
## Balancing-Simulation: spielt Auto-Kämpfe und komplette Dungeon-Läufe
## (Party Level L vs. Karte Stufe T) und druckt eine Ergebnistabelle.
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/balance_sim.gd
## Kein Test (kein OK/FEHLER) — ein Werkzeug, um Skalierungs-Schrauben zu prüfen.
## Env-Schalter: BOSS=1 (Boss-Tabelle, mit STUFEN=40,50,60 eigene Stufen),
## BOSSDIAG=1 (Sieg-% je Boss-Typ; NACH=mods gruppiert nach Modifikatoren),
## KURVE=1 (Schaden Party↔Boss pro Runde je Level), SOLO=1 (Schaden je Held allein,
## 6 Runden inkl. Brand/Gift), SKILLS=1 (je Skill, NURBOSS=1 ohne Begleiter),
## PARTY=1, DIAG=1, EXTREME=1. Die Helden spielen wie Spieler (_spieler_zug).

const RUNS_PER_CELL := 60
const BATTLES_PER_RUN := 6  ## normale Kämpfe vor dem Boss
const MAX_TURNS := 400
var _letzte_aktion := ""  ## ZUGDIAG: was der Held zuletzt getan hat
## Belebungselixiere, die eine Sim-Party in jeden Bosskampf mitnimmt (wie ein
## vorsorgender Spieler); pro Battle gezählt.
const SIM_ELIXIERE := 2
var _elixiere := {}
var _wiederbelebt := 0  ## GEFAHR: Wiederbelebungen (Zauber + Elixier)


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
	if OS.get_environment("GEFAHR") == "1":
		_gefahr()
		quit(0)
		return
	if OS.get_environment("WAFFEN_PARTY") == "1":
		_waffen_party()
		quit(0)
		return
	if OS.get_environment("WAFFEN") == "1":
		_waffen_matrix()
		quit(0)
		return
	if OS.get_environment("ROHWERTE") == "1":
		_rohwerte()
		quit(0)
		return
	if OS.get_environment("ZUGDIAG") == "1":
		_zug_diagnose()
		quit(0)
		return
	if OS.get_environment("SOLO") == "1":
		_solo_schaden()
		quit(0)
		return
	if OS.get_environment("SKILLS") == "1":
		_skill_schaden()
		quit(0)
		return
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
		_runde_planen(battle, party)
		var actor := battle.next_turn()
		if actor == null:
			break
		# Gegenspiel wie echte Spieler: kündigt ein Boss seinen Spezialangriff
		# an, geht die Party in Verteidigungshaltung.
		if actor.is_player and not actor.is_summon and _boss_is_charging(battle):
			_gegen_aufladung(battle, actor)
		elif actor.is_player and not actor.is_summon:
			_spieler_zug(battle, actor)
		else:
			battle.ai_take_turn(actor)
		turns += 1
	# Sieg = Kampf vorbei und die Party lebt — geflohene Gegner (Güldene,
	# Metallschleime) zählen wie im Spiel als Sieg, nicht als Niederlage.
	return {"won": battle.is_over and not battle._living(party).is_empty(),
		"rounds": battle.round_number}


## Ein Held spielt wie ein Mensch (im Spiel plant der Spieler selbst — die
## Gegner-KI greift in 40 % der Züge zur Waffe, für einen Magier ein
## wertloser Stabhieb): heilen, wenn jemand angeschlagen ist; fehlende
## Stärkungen und Schwächungen auffrischen; sonst den Angriffs-Skill nutzen.
## Grundangriff nur ohne passendes Mana.
func _spieler_zug(battle: Battle, actor: Combatant) -> void:
	var foes := battle._living(battle.opponents_of(actor))
	if foes.is_empty():
		return
	# Geplanter Schutzwall (steht seit Rundenbeginn): der Zug gehört ihm.
	var schutz := _schutz_skill(actor)
	if schutz != null and actor.has_status(Enums.Status.PROTECT):
		_letzte_aktion = "schutzwall"
		battle.use_skill(actor, schutz, actor)
		return
	# 0. Gefallene zurückholen: Wiederbelebungs-Zauber, sonst ein Elixier.
	var gefallen: Combatant = null
	for ally in battle.allies_of(actor):
		if not ally.is_alive() and not ally.is_summon:
			gefallen = ally
			break
	if gefallen != null:
		for skill in actor.skills:
			for effekt in skill.get_effect_blocks():
				if effekt.status == Enums.Status.REVIVE and actor.mp >= skill.get_mp_cost(actor) \
						and skill.is_valid(actor):
					_letzte_aktion = "wiederbeleben"
					battle.use_skill(actor, skill, actor)
					_wiederbelebt += 1
					return
		var vorrat: int = _elixiere.get(battle, SIM_ELIXIERE if battle.has_boss() else 0)
		if vorrat > 0:
			_elixiere[battle] = vorrat - 1
			_letzte_aktion = "elixier"
			battle.use_consumable(actor, ConsumableLibrary.get_def(&"belebungselixier"), gefallen)
			_wiederbelebt += 1
			return
	var heilen: Array[Skill] = []
	var helfen: Array[Skill] = []
	var schwaechen: Array[Skill] = []
	var angreifen: Array[Skill] = []
	for skill in actor.skills:
		if not (skill.is_valid(actor) and skill.usable_with_weapon(actor)) \
				or actor.mp < skill.get_mp_cost(actor):
			continue
		match Battle.ki_rolle(skill):
			&"heilen": heilen.append(skill)
			&"helfen": helfen.append(skill)
			_:
				var schwaecht := false
				for effekt in skill.get_effect_blocks():
					if effekt.ziel in [EffectBlock.Ziel.ZIEL, EffectBlock.Ziel.ALLE_GEGNER] \
							and effekt.status in Combatant.STUFEN_STATUS:
						schwaecht = true
				if schwaecht:
					schwaechen.append(skill)
				else:
					angreifen.append(skill)
	# 1. Heilen: der am schwersten Verwundete unter 50 %.
	var verwundet := battle._am_meisten_verwundet(actor)
	if not heilen.is_empty() and verwundet != null \
			and float(verwundet.hp) / verwundet.max_hp < Battle.KI_HEILEN_UNTER:
		var skill: Skill = heilen[battle.rng.randi_range(0, heilen.size() - 1)]
		if skill.get_form() != Enums.SkillForm.SELF or verwundet == actor:
			_letzte_aktion = "heilen"
			battle.use_skill(actor, skill, verwundet)
			return
	_letzte_aktion = "buffen"
	# 2. Stärkungen, die gerade fehlen — gegen Bosse bis Stufe 2 (DQ9-Spiel:
	# erst aufbauen, dann zuschlagen).
	var boss := battle.has_boss()
	for skill in helfen:
		if skill.hat_effekt(Enums.Status.PROTECT):
			continue  # Schutzwall wird für die Runde geplant (_runde_planen)
		var ziel := battle._ki_hilfsziel(actor, skill)
		if ziel != null:
			battle.use_skill(actor, skill, ziel)
			return
	if boss:
		for skill in helfen:
			for ally in battle._living(battle.allies_of(actor)):
				if skill.get_form() == Enums.SkillForm.SELF and ally != actor:
					continue
				if _ausbaufaehig(ally, skill):
					battle.use_skill(actor, skill, ally)
					return
	_letzte_aktion = "debuffen"
	# 2b. Entzaubern, sobald ein Gegner ≥ 2 Buff-Stufen trägt (Anführer-Auren).
	for skill in actor.skills:
		var entzaubert := false
		for effekt in skill.get_effect_blocks():
			entzaubert = entzaubert or effekt.status == Enums.Status.ENTZAUBERN
		if not entzaubert or actor.mp < skill.get_mp_cost(actor):
			continue
		for foe in foes:
			if Battle._stufen_summe(foe, Battle.HELDEN_BUFFS) >= 2:
				_letzte_aktion = "entzaubern"
				battle.use_skill(actor, skill, foe)
				return
	# 3. Schwächungen am stärksten Gegner: fehlende zuerst, gegen Bosse bis Stufe 2.
	var haupt := foes[0]
	for foe in foes:
		if foe.max_hp > haupt.max_hp:
			haupt = foe
	for skill in schwaechen:
		for effekt in skill.get_effect_blocks():
			if effekt.status in Combatant.STUFEN_STATUS and not haupt.has_status(effekt.status):
				battle.use_skill(actor, skill, haupt)
				return
	if boss:
		for skill in schwaechen:
			if _ausbaufaehig(haupt, skill):
				battle.use_skill(actor, skill, haupt)
				return
	# 4. Angreifen: Skill, solange das Mana reicht (Waffen-Skills kosten seit
	# der MP-Formel 1 MP + 3 % der Max-MP — Sparen lohnt sich nicht mehr).
	if not angreifen.is_empty():
		# Wie ein Spieler mit Element-Wissen: Schwächen bevorzugen, Resistenzen meiden.
		var passend: Array[Skill] = []
		var neutral: Array[Skill] = []
		for skill in angreifen:
			var element := skill.get_element()
			var faktor := haupt.element_faktor(element.element) if element != null else 1.0
			if faktor > 1.0:
				passend.append(skill)
			elif faktor >= 1.0:
				neutral.append(skill)
		var wahl: Array[Skill] = passend if not passend.is_empty() else 			(neutral if not neutral.is_empty() else angreifen)
		var skill: Skill = wahl[battle.rng.randi_range(0, wahl.size() - 1)]
		_letzte_aktion = "skill"
		battle.use_skill(actor, skill, battle._ki_angriffsziel(actor, skill, foes))
		return
	_letzte_aktion = "grundangriff"
	battle.basic_attack(actor, foes[battle.rng.randi_range(0, foes.size() - 1)])


## Hat `ziel` einen Stufen-Effekt des Skills noch unter Stufe 2?
func _ausbaufaehig(ziel: Combatant, skill: Skill) -> bool:
	for effekt in skill.get_effect_blocks():
		if effekt.status in Combatant.STUFEN_STATUS:
			var eintrag := ziel.get_status(effekt.status)
			if eintrag.is_empty() or int(eintrag.get("stufe", 0)) < Combatant.STUFEN_MAX:
				return true
	return false


## Der Boss lädt auf: wer den Schutzwall für die Runde geplant hat, setzt
## ihn ein, alle anderen gehen in Verteidigung.
func _gegen_aufladung(battle: Battle, actor: Combatant) -> void:
	var skill := _schutz_skill(actor)
	if skill != null and actor.has_status(Enums.Status.PROTECT):
		battle.use_skill(actor, skill, actor)
		return
	battle.defend(actor)


func _schutz_skill(actor: Combatant) -> Skill:
	for skill in actor.skills:
		if skill.hat_effekt(Enums.Status.PROTECT) and actor.mp >= skill.get_mp_cost(actor) \
				and skill.is_valid(actor) and skill.usable_with_weapon(actor):
			return skill
	return null


## Vor jeder neuen Runde (wie die Befehlsphase): lädt ein Boss auf oder ist
## ein Verbündeter unter 35 % HP, plant der Tank den Schutzwall — er steht
## dann ab Rundenbeginn; seinen Zug verbraucht er dafür.
func _runde_planen(battle: Battle, party: Array[Combatant]) -> void:
	if not battle._queue.is_empty():
		return
	# Schützen, wenn der Boss auflädt — oder ein Verbündeter kurz vorm Umfallen ist.
	var noetig := _boss_is_charging(battle)
	for held in party:
		if held.is_alive() and _schutz_skill(held) == null and float(held.hp) / held.max_hp < 0.35:
			noetig = true
	if not noetig:
		return
	for held in party:
		if held.is_alive() and _schutz_skill(held) != null:
			battle.geplanter_schutz.append(held)
			return


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
	# Wie ein Spieler baut: der dickste Hieb (Raserei, sonst Überladung) mit
	# Blutung und Hinrichtung, ein Flächenhieb und ein Hieb mit Kampfrausch.
	axt.skills = _skills(axt, [
		[&"src_weapon", &"tech_ax_overload2", &"mod_overload", &"tech_klaffende_wunde",
			&"tech_kopfspalter", &"mod_praezision", &"mod_schwachstelle"],
		[&"src_weapon", &"form_aoe", &"mod_wucht", &"tech_klaffende_wunde", &"mod_overload"],
		[&"src_weapon", &"tech_kampfrausch", &"tech_klaffende_wunde", &"mod_praezision"],
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

	var heiler := _hero("Heiler", level, {&"spirit": 0.5, &"intelligence": 0.3, &"vitality": 0.2})
	_ausruesten(heiler, tier, gear_rng, [&"heiligstab", &"relikt", &"robe_heil", &"helm_leicht",
		&"handschuhe_leicht", &"stiefel_leicht", &"ring", &"ring", &"amulett"])
	_trainieren(heiler, [&"heiligstab", &"offensivstab"])
	# Heiler-Rolle (Lutz): heilen, Helden stärken, Gegner schwächen —
	# eigener Schaden ist Nebensache.
	heiler.skills = _skills(heiler, [
		[&"src_spell", &"elem_holy", &"form_ally", &"mod_vollheilung"],
		[&"src_spell", &"form_aoe", &"eff_weaken", &"eff_ruestung_schwaechen", &"eff_slow"],
		[&"src_spell", &"elem_holy", &"form_aura", &"eff_regen"],
		[&"src_spell", &"form_aura", &"eff_def_up", &"eff_atk_up"],
		[&"src_spell", &"form_aura", &"eff_magieschild", &"eff_elementschutz"],
		[&"src_spell", &"form_aoe", &"eff_magiebruch", &"eff_elementschwaeche"],
		[&"src_spell", &"form_aoe", &"eff_entzaubern"],
		[&"src_spell", &"form_ally", &"eff_revive"],
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
		var leer := Battle._is_friendly_form(skill.get_form()) and skill.get_element() == null \
			and skill.get_effect_blocks().is_empty()
		if not skill.get_sources().is_empty() and skill.is_valid(hero) and not leer \
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
				_runde_planen(battle, party)
				var actor := battle.next_turn()
				if actor == null:
					break
				var vorher := boss.hp
				if actor.is_player and not actor.is_summon:
					_spieler_zug(battle, actor)
				else:
					battle.ai_take_turn(actor)
				var wer := actor.display_name if actor.is_player else "Rest"
				je_held[wer] = je_held.get(wer, 0.0) + float(vorher - maxi(0, boss.hp)) / boss.max_hp
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


## SKILLS=1: Ø Schaden jedes Party-Skills (und des Grundangriffs) gegen einen
## nackten Boss, in % seiner HP — plus MP-Kosten in % der eigenen MP.
func _skill_schaden() -> void:
	for level in [10, 30, 50, 100]:
		print("Level %d:" % level)
		var party := _make_party(level, level)
		for held in party:
			var zeilen: Array = [["Grundangriff", null]]
			for skill in held.skills:
				var ids: Array[String] = []
				for block in skill.blocks:
					ids.append(String(block.id).trim_prefix("src_").trim_prefix("elem_").trim_prefix("mod_").trim_prefix("tech_").trim_prefix("form_").trim_prefix("eff_"))
				zeilen.append(["+".join(ids), skill])
			for zeile in zeilen:
				var summe := 0.0
				var n := 20
				var mp := 0
				for i in n:
					var rng := RandomNumberGenerator.new()
					rng.seed = 500000 + i * 71 + level
					var card := CardFactory.make_card(level, rng)
					card.modifier_ids.clear()
					card.card_affix_ids.clear()
					card.card_rarity = Enums.Rarity.COMMON
					card.legendary = false
					var foes := EnemyFactory.make_encounter(card, rng, true, card.floor_count - 1)
					if OS.get_environment("NURBOSS") == "1":
						foes = [foes[0]]
					var neu_party := _make_party(level, level)
					var ich: Combatant = neu_party[party.find(held)]
					var battle := Battle.new()
					battle.rng.seed = rng.randi()
					battle.start(neu_party, foes)
					var vorher := 0
					for f in foes:
						vorher += f.hp
					var skill: Skill = null
					if zeile[1] != null:
						skill = ich.skills[held.skills.find(zeile[1])]
					if skill == null:
						battle.basic_attack(ich, foes[0])
					else:
						mp = skill.get_mp_cost(ich)
						var ziel: Combatant = foes[0]
						if Battle._is_friendly_form(skill.get_form()):
							ziel = ich
						battle.use_skill(ich, skill, ziel)
					# Vier Gegnerzüge: Brand/Gift ticken mit (ohne Gegner-Aktion).
					for runde in 4:
						for f in foes:
							if f.is_alive():
								battle._process_turn_start(f)
					var nachher := 0
					for f in foes:
						nachher += maxi(0, f.hp)
					summe += float(vorher - nachher) / foes[0].max_hp
				print("    %-7s %-48s %6.1f %% Boss-HP   MP %5d (%4.1f %% der MP)" % [held.display_name, zeile[0],
					100.0 * summe / n, mp, 100.0 * mp / maxi(1, held.max_mp)])


## SOLO=1: Jeder Held allein, 6 Runden gegen einen Boss, der stillhält —
## Ø Boss-HP pro Runde inkl. Brand/Gift, mit echtem Mana-Verbrauch und
## Axt-Erschöpfung. Die ehrliche Schadens-Rangliste der Rollen.
func _solo_schaden() -> void:
	const RUNDEN := 6
	for level in [10, 30, 50, 75, 100]:
		var zeile: Array[String] = []
		for index in 4:
			var summe := 0.0
			var name := ""
			var n := 20
			for i in n:
				var rng := RandomNumberGenerator.new()
				rng.seed = 300000 + i * 97 + level
				var card := CardFactory.make_card(level, rng)
				card.modifier_ids.clear()
				card.card_affix_ids.clear()
				card.card_rarity = Enums.Rarity.COMMON
				card.legendary = false
				var boss := EnemyFactory.make_encounter(card, rng, true, card.floor_count - 1)[0]
				boss.max_hp *= 50  # überlebt sicher, Prozente rechnen auf die echte HP
				boss.hp = boss.max_hp
				var held: Combatant = _make_party(level, level)[index]
				name = held.display_name
				var allein: Array[Combatant] = [held]
				var gegner: Array[Combatant] = [boss]
				var battle := Battle.new()
				battle.rng.seed = rng.randi()
				battle.start(allein, gegner)
				var zuege := 0
				while not battle.is_over and battle.round_number <= RUNDEN and zuege < 100:
					_runde_planen(battle, allein)
					var actor := battle.next_turn()
					if actor == null:
						break
					if actor == held:
						_spieler_zug(battle, held)
					zuege += 1
				summe += float(boss.max_hp - boss.hp) / (boss.max_hp / 50.0) / RUNDEN
			zeile.append("%s %5.1f %%" % [name, 100.0 * summe / n])
		print("Level %3d:  %s" % [level, "   ".join(zeile)])


## ZUGDIAG=1: Wohin gehen die Runden in ECHTEN Bosskämpfen? Pro Level:
## Boss-HP gegenüber dem nackten Boss (Modifikatoren/Karten-Rarität),
## Schadensanteil auf Boss vs. Begleiter, und was die Helden-Züge tun.
func _zug_diagnose() -> void:
	for level in [30, 50, 100]:
		var zaehler := {}
		var hp_echt := 0.0
		var hp_nackt := 0.0
		var auf_boss := 0.0
		var auf_rest := 0.0
		var runden := 0
		var n := 40
		for i in n:
			var rng := RandomNumberGenerator.new()
			rng.seed = 900000 + i * 613 + level * 17 + 1
			var card := CardFactory.make_card(level, rng)
			var party := _make_party(level, level)
			var foes := EnemyFactory.make_encounter(card, rng, true, card.floor_count - 1)
			var boss := foes[0]
			hp_echt += boss.max_hp
			var nackt_rng := RandomNumberGenerator.new()
			nackt_rng.seed = 1
			hp_nackt += EnemyFactory.boss_hp_faktor(level + card.floor_count - 1) \
				* EnemyFactory.build(EnemyLibrary.get_archetype(boss.archetype_id), level + card.floor_count - 1,
					nackt_rng, [], card.biome).max_hp
			var battle := Battle.new()
			battle.rng.seed = rng.randi()
			for member in party:
				member.statuses.clear()
			battle.start(party, foes)
			var zuege := 0
			while not battle.is_over and zuege < MAX_TURNS:
				var vorher := {}
				for f in battle.enemies:
					vorher[f] = f.hp
				_runde_planen(battle, party)
				var actor := battle.next_turn()
				if actor == null:
					break
				if actor.is_player and not actor.is_summon:
					var art := ""
					if _boss_is_charging(battle):
						art = "verteidigen (Boss lädt)"
						battle.defend(actor)
					else:
						_spieler_zug(battle, actor)
						art = _letzte_aktion
					zaehler[art] = zaehler.get(art, 0) + 1
					for f in vorher:
						var weg := float(vorher[f] - maxi(0, f.hp))
						if f == boss:
							auf_boss += weg / boss.max_hp
						else:
							auf_rest += weg / boss.max_hp
				else:
					battle.ai_take_turn(actor)
				zuege += 1
			runden += battle.round_number
		var summe := 0
		for art in zaehler:
			summe += zaehler[art]
		var teile: Array[String] = []
		for art in zaehler:
			teile.append("%s %.0f %%" % [art, 100.0 * zaehler[art] / summe])
		print("Level %d: Ø %.1f Runden · Boss-HP echt = ×%.2f vom nackten Boss · Helden-Schaden: Boss %.0f %% / Begleiter %.0f %% (in Boss-HP)" % [
			level, float(runden) / n, hp_echt / hp_nackt, 100.0 * auf_boss / n, 100.0 * auf_rest / n])
		print("    Heldenzüge: " + " · ".join(teile))


## ROHWERTE=1: die Bausteine des Schadens je Level, geteilt durch die Welt-
## Kurve (Scaling.factor) — was nicht mitwächst, fällt hier sofort auf.
func _rohwerte() -> void:
	print("Level | Welt  | Axt: STR  Waffe  Roh(Grund) | Magier: INT  Zauber  | Boss: Rüstung  MagRes  HP   (alles ÷ Welt)")
	for level in [10, 30, 50, 75, 100]:
		var party := _make_party(level, level)
		var axt: Combatant = party[1]
		var mage: Combatant = party[2]
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		var arch := EnemyLibrary.get_archetype(&"troll")
		var boss := EnemyFactory.build(arch, level, rng, [], Enums.Biome.FOREST)
		var w := Scaling.factor(level)
		var roh := Battle.BASIC_ATTACK_BASE + axt.stat(&"strength") + axt.weapon_damage()
		print("%5d | %5.1f | %8.0f %6.0f %10.0f | %11.0f %7.0f | %13.0f %7.0f %6.0f" % [level, w,
			axt.stat(&"strength") / w, axt.weapon_damage() / w, roh / w,
			mage.stat(&"intelligence") / w, mage.spell_damage() / w,
			boss.armor_against(Enums.PhysicalSubtype.SLASH) / w, boss.total_magic_resist() / w,
			boss.max_hp * EnemyFactory.boss_hp_faktor(level) / w])
		print("        Axt: Waffe=%s  Training ×%.2f  Gear-Level %d" % [axt.equipment.get(Enums.EquipSlot.WEAPON).base.id,
			axt.training_weapon_mult(), axt.equipment.get(Enums.EquipSlot.WEAPON).item_level])


## Spieler-Builds je Schadens-Waffe: [Ausrüstung, zweiter Baum, Stat-Gewichte,
## Rezepte (stärkster Skill zuerst; was noch nicht frei ist, fällt weg)].
const WAFFEN_BUILDS := {
	&"schwert": [[&"zweihandschwert"], &"schild",
		{&"strength": 0.5, &"agility": 0.3, &"vitality": 0.2}, [
		[&"src_weapon", &"tech_sw_meister", &"tech_duellmeister", &"tech_duellstoss", &"tech_schwertkunst",
			&"mod_praezision", &"mod_overload", &"mod_schwachstelle"],
		[&"src_weapon", &"tech_klingentanz", &"mod_treffer", &"mod_treffer", &"mod_overload"],
		[&"src_weapon", &"tech_kampfruf", &"mod_praezision", &"mod_overload"]]],
	&"dolch": [[&"dolch", &"dolch"], &"bogen",
		{&"strength": 0.5, &"agility": 0.3, &"vitality": 0.2}, [
		[&"src_weapon", &"tech_serienschlag", &"tech_blutung", &"tech_giftklinge", &"tech_meucheln",
			&"mod_praezision", &"mod_overload"],
		[&"src_weapon", &"tech_do_execute2", &"tech_hinterhalt", &"tech_schwachpunkt", &"mod_overload"],
		[&"src_weapon", &"elem_fire", &"tech_elementklinge", &"mod_treffer"]]],
	&"axt": [[&"zweihandaxt"], &"bogen",
		{&"strength": 0.5, &"agility": 0.3, &"vitality": 0.2}, [
		[&"src_weapon", &"tech_ax_overload2", &"mod_overload", &"tech_klaffende_wunde",
			&"tech_kopfspalter", &"mod_praezision", &"mod_schwachstelle"],
		[&"src_weapon", &"form_aoe", &"mod_wucht", &"tech_klaffende_wunde", &"mod_overload"],
		[&"src_weapon", &"tech_kampfrausch", &"tech_klaffende_wunde", &"mod_praezision"]]],
	&"stumpf": [[&"kriegshammer"], &"schild",
		{&"strength": 0.5, &"agility": 0.3, &"vitality": 0.2}, [
		[&"src_weapon", &"tech_zermalmen", &"tech_st_riss2", &"tech_ruestungsriss", &"mod_overload",
			&"mod_praezision", &"mod_schwachstelle"],
		[&"src_weapon", &"tech_st_stun2", &"eff_stun", &"mod_overload"],
		[&"src_weapon", &"form_aoe", &"mod_wucht"]]],
	&"bogen": [[&"bogen", &"koecher"], &"dolch",
		{&"strength": 0.5, &"agility": 0.3, &"vitality": 0.2}, [
		[&"src_weapon", &"tech_volltreffer", &"tech_scharfschuetze", &"tech_adlerauge", &"tech_zielen",
			&"mod_praezision", &"tech_markieren", &"mod_overload"],
		[&"src_weapon", &"tech_giftpfeil", &"mod_treffer", &"mod_overload"],
		[&"src_weapon", &"tech_markieren", &"mod_overload"]]],
	&"armbrust": [[&"armbrust", &"koecher"], &"dolch",
		{&"strength": 0.5, &"agility": 0.3, &"vitality": 0.2}, [
		[&"src_weapon", &"tech_schwerer_bolzen", &"tech_ar_pierce3", &"tech_ar_pierce2", &"tech_widerhaken",
			&"tech_brandbolzen", &"mod_praezision", &"mod_overload"],
		[&"src_weapon", &"tech_markierbolzen", &"mod_overload"],
		[&"src_weapon", &"form_aoe", &"mod_wucht"]]],
	&"offensivstab": [[&"offensivstab", &"zauberbuch"], &"heiligstab",
		{&"intelligence": 0.5, &"spirit": 0.3, &"vitality": 0.2}, [
		[&"src_spell", &"elem_fire", &"form_aoe", &"tech_elementfokus", &"mod_overload", &"tech_echo",
			&"tech_os_meister"],
		[&"src_spell", &"elem_ice", &"mod_praezision", &"mod_overload", &"tech_konzentration"],
		[&"src_spell", &"elem_lightning", &"mod_treffer", &"mod_ziel_wechsel", &"mod_overload"]]],
}


func _waffen_held(familie: StringName, level: int) -> Combatant:
	var bau: Array = WAFFEN_BUILDS[familie]
	var held := _hero(String(familie), level, bau[2])
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 7919 + 5
	_ausruesten(held, level, rng, bau[0] + [&"ruestung_mittel", &"helm_leicht", &"handschuhe_leicht",
		&"stiefel_leicht", &"ring", &"ring", &"amulett"])
	_trainieren(held, [familie, bau[1]])
	held.skills = _skills(held, bau[3])
	held.recompute_derived()
	held.hp = held.max_hp
	held.mp = held.max_mp
	return held


## WAFFEN=1: jede Schadens-Waffe mit Spieler-Build allein gegen einen Boss,
## der stillhält — Ø Runden, bis er fällt (echte HP, Hinrichtung greift),
## inkl. Brand/Gift/Blutung, Mana-Verbrauch und Waffen-Eigenheiten.
func _waffen_matrix() -> void:
	const RUNDEN := 60
	var stufen: Array = [10, 30, 50, 75, 100]
	if OS.get_environment("STUFEN") != "":
		stufen = Array(OS.get_environment("STUFEN").split(",")).map(func(t): return int(t))
	var kopf := "Waffe        "
	for level in stufen:
		kopf += " | Lv %3d" % level
	print(kopf + "   (Ø Runden, bis der Boss allein fällt — kleiner = stärker)")
	for familie in WAFFEN_BUILDS:
		var zeile := "%-12s " % familie
		for level in stufen:
			var summe := 0.0
			var n := 16
			for i in n:
				var rng := RandomNumberGenerator.new()
				rng.seed = 300000 + i * 97 + level
				var card := CardFactory.make_card(level, rng)
				card.modifier_ids.clear()
				card.card_affix_ids.clear()
				card.card_rarity = Enums.Rarity.COMMON
				card.legendary = false
				var boss := EnemyFactory.make_encounter(card, rng, true, card.floor_count - 1)[0]
				var held := _waffen_held(familie, level)
				var allein: Array[Combatant] = [held]
				var gegner: Array[Combatant] = [boss]
				var battle := Battle.new()
				battle.rng.seed = rng.randi()
				battle.start(allein, gegner)
				var zuege := 0
				while not battle.is_over and battle.round_number <= RUNDEN and zuege < 400:
					_runde_planen(battle, allein)
					var actor := battle.next_turn()
					if actor == null:
						break
					if actor == held:
						_spieler_zug(battle, held)
					zuege += 1
				summe += battle.round_number if not boss.is_alive() else RUNDEN + 1
			zeile += " | %6.1f" % (summe / n)
		print(zeile)
	if OS.get_environment("BAUTEN") == "1":
		for familie in WAFFEN_BUILDS:
			var held := _waffen_held(familie, 100)
			var namen: Array[String] = []
			for skill in held.skills:
				var ids: Array[String] = []
				for block in skill.blocks:
					ids.append(String(block.id))
				namen.append("+".join(ids))
			print("  %s Lv100 MP %d: %s" % [familie, held.max_mp, " | ".join(namen)])


## WAFFEN_PARTY=1: echte Bosskämpfe (Boss greift an, Begleiter, Phasen) —
## der Schadens-Platz der Party (sonst die Axt) wird mit jeder Waffe besetzt.
## Zeigt Sieg-% und Ø Runden: Parade, Betäubung, Gift … zählen hier mit.
func _waffen_party() -> void:
	var stufen: Array = [30, 50, 100]
	if OS.get_environment("STUFEN") != "":
		stufen = Array(OS.get_environment("STUFEN").split(",")).map(func(t): return int(t))
	var kopf := "Waffe        "
	for level in stufen:
		kopf += " | Lv %3d Sieg  Runden" % level
	print(kopf)
	for familie in WAFFEN_BUILDS:
		var zeile := "%-12s " % familie
		for level in stufen:
			var siege := 0
			var runden := 0
			var n := 30
			for i in n:
				var rng := RandomNumberGenerator.new()
				rng.seed = 900000 + i * 613 + level * 17 + 1
				var card := CardFactory.make_card(level, rng)
				var party := _make_party(level, level)
				party[1] = _waffen_held(familie, level)
				var foes := EnemyFactory.make_encounter(card, rng, true, card.floor_count - 1)
				var ergebnis := _run_battle(party, foes, rng.randi())
				runden += int(ergebnis["rounds"])
				if ergebnis["won"]:
					siege += 1
			zeile += " | %10.0f %% %6.1f" % [100.0 * siege / n, float(runden) / n]
		print(zeile)


## GEFAHR=1: Wie gefährlich sind Bosskämpfe auf gleichem Level? Pro Stufe:
## Sieg, Runden, Tode und Wiederbelebungen pro Kampf, Anteil Kämpfe mit
## mindestens einem Tod, One-Shot-Anteil je Rolle (mit ≥ 90 % HP durch EINEN
## Gegnerzug gefallen) und welchen Anteil des Schadens der Tank fängt.
func _gefahr() -> void:
	var stufen: Array = [10, 30, 50, 100]
	if OS.get_environment("STUFEN") != "":
		stufen = Array(OS.get_environment("STUFEN").split(",")).map(func(t): return int(t))
	print("Stufe | Sieg | Runden | Tode/Kampf | Kämpfe mit Tod | Wiederbel./Kampf | One-Shots Tank/Axt/Mag/Heil | Tank fängt")
	for level in stufen:
		var n := 40
		var siege := 0
		var runden := 0
		var tode := 0
		var mit_tod := 0
		_wiederbelebt = 0
		var treffer := {}
		var one := {}
		var schaden := {}
		var schutz_n := 0
		var schutz_verlust := 0.0
		var schutz_max := 0.0
		var schutz_tod := 0
		var schutz_one := 0
		var schutz_voll := 0
		for i in n:
			var rng := RandomNumberGenerator.new()
			rng.seed = 900000 + i * 613 + level * 17 + 1
			var card := CardFactory.make_card(level, rng)
			var party := _make_party(level, level)
			var foes := EnemyFactory.make_encounter(card, rng, true, card.floor_count - 1)
			var battle := Battle.new()
			battle.rng.seed = rng.randi()
			battle.start(party, foes)
			var tode_hier := 0
			var zuege := 0
			var abgefangen := [0]
			battle.log_line.connect(func(t: String) -> void:
				if "schützend" in t or "leaps in front" in t:
					abgefangen[0] += 1)
			var tank: Combatant = party[0]
			while not battle.is_over and zuege < MAX_TURNS:
				_runde_planen(battle, party)
				var actor := battle.next_turn()
				if actor == null:
					break
				var vorher := {}
				for held in party:
					vorher[held] = held.hp
				abgefangen[0] = 0
				if actor.is_player and not actor.is_summon:
					if _boss_is_charging(battle):
						_gegen_aufladung(battle, actor)
					else:
						_spieler_zug(battle, actor)
				else:
					battle.ai_take_turn(actor)
					# Tank fängt einen Flächenangriff für mehrere ab?
					if abgefangen[0] >= 2 and int(vorher[tank]) > 0:
						schutz_n += 1
						var anteil := float(int(vorher[tank]) - maxi(0, tank.hp)) / tank.max_hp
						schutz_verlust += anteil
						schutz_max = maxf(schutz_max, anteil)
						if not tank.is_alive():
							schutz_tod += 1
							if float(vorher[tank]) / tank.max_hp >= 0.9:
								schutz_one += 1
						if float(vorher[tank]) / tank.max_hp >= 0.9:
							schutz_voll += 1
				for held in party:
					var verlust := int(vorher[held]) - maxi(0, held.hp)
					if verlust > 0 and not actor.is_player:
						var rolle := held.display_name
						treffer[rolle] = treffer.get(rolle, 0) + 1
						schaden[rolle] = schaden.get(rolle, 0) + verlust
						if float(vorher[held]) / held.max_hp >= 0.9 and not held.is_alive():
							one[rolle] = one.get(rolle, 0) + 1
					if int(vorher[held]) > 0 and held.hp <= 0:
						tode_hier += 1
				zuege += 1
			runden += battle.round_number
			tode += tode_hier
			if tode_hier > 0:
				mit_tod += 1
			if battle.is_over and not battle._living(party).is_empty():
				siege += 1
		var gesamt := 0
		for rolle in schaden:
			gesamt += schaden[rolle]
		var os: Array[String] = []
		for rolle in ["Tank", "Axt", "Magier", "Heiler"]:
			os.append("%.0f%%" % (100.0 * one.get(rolle, 0) / maxi(1, treffer.get(rolle, 0))))
		print("%5d | %3.0f%% | %6.1f | %10.1f | %13.0f%% | %16.1f | %27s | %7.0f%%" % [level, 100.0 * siege / n,
			float(runden) / n, float(tode) / n, 100.0 * mit_tod / n, float(_wiederbelebt) / n,
			" / ".join(os), 100.0 * schaden.get("Tank", 0) / maxi(1, gesamt)])
		print("        Schutzwall gegen Flächen: %d× — Tank verliert Ø %.0f %%, max %.0f %%, stirbt %d× (%.0f %%); aus voller HP: %d von %d tödlich" % [
			schutz_n, 100.0 * schutz_verlust / maxi(1, schutz_n), 100.0 * schutz_max, schutz_tod,
			100.0 * schutz_tod / maxi(1, schutz_n), schutz_one, schutz_voll])
