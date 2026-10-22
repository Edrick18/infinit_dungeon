extends SceneTree
## Headless-Selbsttest für die Körper-Quelle und die Quell-gebundenen Klötze
## (Schutzwall, Deckung, Provozieren, Eiserne Abwehr, Lebensgabe, Innere Ruhe,
## Zorn · Manaraub, Rückschlag · Wiederbeleben, Schweigen, Zauberspiegel · Eile):
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/koerper_selftest.gd

var failures := 0


func _init() -> void:
	var waechter := FehlerWaechter.anmelden()
	_test_bauregeln()
	_test_koerpertreffer()
	_test_vit_skalierung()
	_test_deckung()
	_test_provozieren()
	_test_eiserne_abwehr()
	_test_zorn()
	_test_lebensgabe()
	_test_schweigen()
	_test_zauberspiegel()
	_test_rueckschlag()
	_test_manaraub()
	_test_eile()
	_test_ueberheil_deckel()
	_test_kampfende_status()
	failures += waechter.fehler_melden()
	if failures == 0:
		print("SELFTEST OK — alle Körper-Tests bestanden")
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


func _held(name := "Held", vit := 10) -> Combatant:
	var stats := StatBlock.new()
	stats.strength = 10
	stats.vitality = vit
	stats.spirit = 5
	stats.intelligence = 10
	stats.agility = 20
	var held := Combatant.create(name, stats, true)
	held.level = 40
	held.max_hp = 2000
	held.hp = held.max_hp
	held.max_mp = 500
	held.mp = held.max_mp
	return held


func _gegner(name := "Gegner") -> Combatant:
	var stats := StatBlock.new()
	stats.strength = 10
	stats.vitality = 10
	var gegner := Combatant.create(name, stats, false)
	gegner.max_hp = 100000
	gegner.hp = gegner.max_hp
	return gegner


func _kampf(helden: Array[Combatant], gegner: Array[Combatant]) -> Battle:
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = 1
	battle.start(helden, gegner)
	return battle


func _skill(ids: Array) -> Skill:
	var skill := Skill.new()
	skill.display_name = "Test"
	for id in ids:
		skill.blocks.append(BlockLibrary.get_block(id))
	return skill


func _test_bauregeln() -> void:
	print("Bauregeln:")
	var held := _held()
	_check(_skill([&"src_koerper"]).is_valid(held), "Körper allein ist ein Rammstoß (Einzelziel)")
	_check(_skill([&"src_koerper", &"form_self", &"eff_protect"]).is_valid(held), "Körper + Selbst + Schutzwall")
	_check(not _skill([&"src_spell", &"form_self", &"eff_protect"]).is_valid(held), "Schutzwall mit Zauber ist ungültig")
	_check(not _skill([&"src_koerper", &"eff_protect"]).is_valid(held),
		"Körper-Klötze brauchen Selbst/Verbündeter/Aura")
	_check(not _skill([&"src_koerper", &"src_weapon"]).is_valid(held), "Körper + Waffenangriff ist ungültig")
	_check(not _skill([&"src_koerper", &"form_summon"]).is_valid(held), "Körper kann nicht beschwören")
	_check(not _skill([&"src_spell", &"mod_rueckschlag"]).is_valid(held), "Rückschlag nur mit Waffenangriff")
	_check(_skill([&"src_weapon", &"mod_rueckschlag"]).is_valid(held), "Waffenangriff + Rückschlag")
	_check(not _skill([&"src_weapon", &"eff_schweigen"]).is_valid(held), "Schweigen nur mit Zauber")
	_check(not _skill([&"src_koerper", &"form_aura", &"eff_revive"]).is_valid(held), "Wiederbeleben nur mit Zauber")
	_check(_skill([&"src_spell", &"form_aura", &"eff_eile"]).is_valid(held)
		and _skill([&"src_koerper", &"form_self", &"eff_eile"]).is_valid(held), "Eile geht mit jeder Quelle")
	_check(_skill([&"src_weapon", &"eff_regen"]).is_valid(held) or _skill([&"src_weapon", &"eff_atk_up"]).is_valid(held),
		"Waffenangriff + Selbst-Stärkung bleibt kombinierbar")
	var block := BlockLibrary.get_block(&"eff_protect")
	_check(block.quelle_noetig == &"koerper" and BlockLibrary.get_block(&"tech_zauberspiegel").quelle_noetig == &"zauber"
		and BlockLibrary.get_block(&"tech_manaraub").quelle_noetig == &"waffe", "Klötze tragen ihre nötige Quelle")
	_check(BlockLibrary.get_block(&"src_koerper").unlock_level == 3, "Körper ab Level 3")
	_check(_skill([&"src_koerper"]).get_mp_cost(held) == _skill([&"src_weapon"]).get_mp_cost(held),
		"Körper kostet MP wie ein Waffenangriff")


func _koerper_schaden(max_hp: int, ruestung := false) -> int:
	var held := _held()
	held.max_hp = max_hp
	held.hp = max_hp
	if ruestung:
		held.armor = 300
	var gegner := _gegner()
	var battle := _kampf([held], [gegner])
	battle.use_skill(held, _skill([&"src_koerper"]), gegner)
	return gegner.max_hp - gegner.hp


func _test_koerpertreffer() -> void:
	print("Körpertreffer:")
	var wenig := _koerper_schaden(1000)
	var viel := _koerper_schaden(3000)
	_check(wenig > 0, "Rammstoß verursacht Schaden (%d)" % wenig)
	_check(viel > wenig, "mehr Max-HP » mehr Schaden (%d > %d)" % [viel, wenig])
	_check(_koerper_schaden(1000, true) > wenig, "Rüstung erhöht den Körperschaden")
	var held := _held()
	var gegner := _gegner()
	var battle := _kampf([held], [gegner])
	battle.use_skill(held, _skill([&"src_koerper", &"form_self", &"eff_innere_ruhe"]), held)
	_check(gegner.hp == gegner.max_hp, "mit Form Selbst kein Schaden")


func _ruhe_heilung(vit: int) -> int:
	var held := _held("Held", vit)
	held.max_hp = 2000
	held.hp = 100
	var battle := _kampf([held], [_gegner()])
	battle.use_skill(held, _skill([&"src_koerper", &"form_self", &"eff_innere_ruhe"]), held)
	return held.hp - 100


func _test_vit_skalierung() -> void:
	print("Innere Ruhe / VIT:")
	var wenig := _ruhe_heilung(5)
	var viel := _ruhe_heilung(200)
	_check(wenig >= 400, "Innere Ruhe heilt mind. 20 %% der Max-HP (%d)" % wenig)
	_check(viel > wenig, "mehr VIT » mehr Heilung (%d > %d)" % [viel, wenig])
	var held := _held()
	held.hp = 500
	held.add_status(Enums.Status.POISON_DOT, -1, 20)
	var battle := _kampf([held], [_gegner()])
	battle.use_skill(held, _skill([&"src_koerper", &"form_self", &"eff_innere_ruhe"]), held)
	_check(not held.has_status(Enums.Status.POISON_DOT), "Innere Ruhe entfernt Gift")


func _test_deckung() -> void:
	print("Deckung:")
	var tank := _held("Tank")
	tank.equip(ItemLibrary.make_item(&"schild"))
	var magier := _held("Magier")
	var gegner := _gegner()
	var battle := _kampf([tank, magier], [gegner])
	_check(battle.use_skill(tank, _skill([&"src_koerper", &"form_ally", &"tech_deckung"]), magier),
		"Deckung wird auf den Magier gewirkt")
	var tank_hp := tank.hp
	battle.basic_attack(gegner, magier)
	_check(magier.hp == magier.max_hp and tank.hp < tank_hp, "Angriff auf den Magier trifft den Tank")
	battle._schutz_zum_rundenbeginn()
	_check(not magier.has_status(Enums.Status.DECKUNG), "Deckung endet zur nächsten Runde")


func _test_provozieren() -> void:
	print("Provozieren:")
	var tank := _held("Tank")
	var magier := _held("Magier")
	var gegner := _gegner()
	var battle := _kampf([tank, magier], [gegner])
	battle.use_skill(tank, _skill([&"src_koerper", &"form_self", &"eff_provozieren"]), tank)
	_check(tank.has_status(Enums.Status.PROVOKATION), "Tank provoziert")
	for i in 8:
		battle.ai_take_turn(gegner)
	_check(magier.hp == magier.max_hp and tank.hp < tank.max_hp, "Gegner greifen nur den Provokateur an")


func _test_eiserne_abwehr() -> void:
	print("Eiserne Abwehr:")
	var held := _held()
	var gegner := _gegner()
	gegner.stats.strength = 60
	var battle := _kampf([held], [gegner])
	battle.basic_attack(gegner, held)
	var normal := held.max_hp - held.hp
	held.hp = held.max_hp
	held.equip(ItemLibrary.make_item(&"schild"))
	var ohne_schild_ruestung := normal
	battle.basic_attack(gegner, held)
	ohne_schild_ruestung = held.max_hp - held.hp
	held.hp = held.max_hp
	_check(battle.use_skill(held, _skill([&"src_koerper", &"form_self", &"tech_eiserne_abwehr"]), held),
		"Eiserne Abwehr wird gewirkt")
	battle.basic_attack(gegner, held)
	var gemindert := held.max_hp - held.hp
	_check(gemindert <= roundi(ohne_schild_ruestung * 0.3) + 1,
		"−75 %% physischer Schaden (%d statt %d)" % [gemindert, ohne_schild_ruestung])


func _test_zorn() -> void:
	print("Zorn:")
	var held := _held()
	held.equip(ItemLibrary.make_item(&"axt"))
	var gegner := _gegner()
	var battle := _kampf([held], [gegner])
	_check(battle.use_skill(held, _skill([&"src_koerper", &"form_self", &"tech_zorn"]), held), "Zorn wird gewirkt")
	battle.basic_attack(gegner, held)
	_check(held.has_status(Enums.Status.ATK_UP), "ein Treffer gibt Stärken")


func _test_lebensgabe() -> void:
	print("Lebensgabe:")
	var geber := _held("Geber")
	var empfaenger := _held("Empfänger")
	empfaenger.hp = 100
	var battle := _kampf([geber, empfaenger], [_gegner()])
	battle.use_skill(geber, _skill([&"src_koerper", &"form_ally", &"eff_lebensgabe"]), empfaenger)
	var gegeben := empfaenger.hp - 100
	_check(gegeben > 0 and geber.max_hp - geber.hp == gegeben, "HP wandern vom Geber zum Empfänger (%d)" % gegeben)
	geber.hp = 1
	empfaenger.hp = 100
	battle.use_skill(geber, _skill([&"src_koerper", &"form_ally", &"eff_lebensgabe"]), empfaenger)
	_check(geber.hp == 1 and geber.is_alive(), "der Geber stirbt nie daran")


func _test_schweigen() -> void:
	print("Schweigen:")
	var held := _held()
	var gegner := _gegner()
	var battle := _kampf([held], [gegner])
	held.add_status(Enums.Status.SCHWEIGEN, 2, 0)
	_check(not battle.use_skill(held, _skill([&"src_spell", &"elem_fire"]), gegner), "verstummt: kein Zauber")
	_check(battle.use_skill(held, _skill([&"src_weapon"]), gegner), "verstummt: Waffenangriff geht")
	_check(Enums.Status.SCHWEIGEN in Battle.KONTROLL_STATUS, "Schweigen ist Kontrolle (halbe Chance gegen Bosse)")


func _test_zauberspiegel() -> void:
	print("Zauberspiegel:")
	var held := _held()
	var gegner := _gegner()
	var battle := _kampf([held], [gegner])
	gegner.add_status(Enums.Status.ZAUBERSPIEGEL, 2, 0)
	battle.use_skill(held, _skill([&"src_spell"]), gegner)
	_check(gegner.hp == gegner.max_hp and held.hp < held.max_hp, "der Zauber prallt auf den Zaubernden zurück")
	held.hp = held.max_hp
	battle.use_skill(held, _skill([&"src_weapon"]), gegner)
	_check(gegner.hp < gegner.max_hp, "Waffenangriffe werden nicht gespiegelt")


func _test_rueckschlag() -> void:
	print("Rückschlag:")
	var held := _held()
	var gegner := _gegner()
	var battle := _kampf([held], [gegner])
	battle.use_skill(held, _skill([&"src_weapon", &"mod_rueckschlag"]), gegner)
	var schaden := gegner.max_hp - gegner.hp
	var rueck := held.max_hp - held.hp
	_check(schaden > 0 and rueck > 0, "der Anwender nimmt Rückschlag (%d von %d)" % [rueck, schaden])
	_check(absi(rueck - roundi(schaden * 0.25)) <= 1, "Rückschlag = 25 % des Schadens")


func _test_manaraub() -> void:
	print("Manaraub:")
	var held := _held()
	held.equip(ItemLibrary.make_item(&"bogen"))
	var gegner := _gegner()
	var battle := _kampf([held], [gegner])
	held.max_mp = 500
	held.mp = 100
	var skill := _skill([&"src_weapon", &"tech_manaraub"])
	var kosten := skill.get_mp_cost(held)
	battle.use_skill(held, skill, gegner)
	_check(held.mp > 100 - kosten, "Manaraub gibt MP zurück (%d MP, Kosten %d)" % [held.mp, kosten])


func _test_eile() -> void:
	print("Eile:")
	var held := _held()
	var vorher := held.effective_speed()
	var battle := _kampf([held], [_gegner()])
	battle.use_skill(held, _skill([&"src_spell", &"form_self", &"eff_eile"]), held)
	_check(held.has_status(Enums.Status.EILE) and held.effective_speed() > vorher,
		"Eile erhöht das Tempo (%d » %d)" % [vorher, held.effective_speed()])


func _test_ueberheil_deckel() -> void:
	print("Überheilung (Deckel):")
	var heiler := _held("Heiler")
	heiler.equip(ItemLibrary.make_item(&"heiligstab"))
	heiler.stats.intelligence = 400
	var patient := _held("Patient")
	patient.max_hp = 100
	patient.hp = 100
	var battle := _kampf([heiler, patient], [_gegner()])
	heiler.max_mp = 5000
	heiler.mp = 5000
	battle.use_skill(heiler, _skill([&"src_spell", &"elem_holy", &"form_ally", &"tech_ueberheilung"]), patient)
	var schild := int(patient.get_status(Enums.Status.SHIELD).get("potency", 0))
	_check(schild > 0 and schild <= 50, "Schild aus Überheilung höchstens 50 %% der Max-HP (%d)" % schild)


func _test_kampfende_status() -> void:
	print("Kampfende:")
	var held := _held()
	var gegner := _gegner()
	gegner.max_hp = 1
	gegner.hp = 1
	var battle := _kampf([held], [gegner])
	held.add_status(Enums.Status.POISON_DOT, -1, 30)
	held.add_status(Enums.Status.WEAKEN, 3, 20)
	battle.basic_attack(held, gegner)
	_check(battle.is_over and held.statuses.is_empty(), "nach dem Sieg keine Statuseffekte mehr an der Party")
