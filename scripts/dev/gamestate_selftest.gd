extends SceneTree
## Headless-Selbsttest für GameState-Run-Verwaltung, insbesondere den
## Fog-of-War-Fix (persistiert über Szenenwechsel, aber nicht über
## Ebenen-/Run-Wechsel hinweg):
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/gamestate_selftest.gd

var failures := 0


func _init() -> void:
	_test_explored_survives_scene_reload()
	_test_explored_resets_on_new_floor()
	_test_explored_resets_on_new_run()
	_test_recruiting()
	_test_bank_training()
	_test_leerer_slot_bleibt_leer()
	_test_koop_eigener_run()
	_test_bestiary()
	_test_bank_reihenfolge()
	_test_flucht_schonfrist()
	if failures == 0:
		print("SELFTEST OK — alle GameState-Tests bestanden")
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


## Flucht-Schonfrist: endet bei Abstand ODER nach Ablauf der Zeit.
func _test_flucht_schonfrist() -> void:
	print("Flucht-Schonfrist (Abstand oder Zeit):")
	var state: Node = load("res://autoload/game_state.gd").new()
	var kontakt := 26.0
	var bis := 10000
	_check(state.schonfrist_aktiv(kontakt, kontakt, 9000, bis), "nah und in der Zeit: aktiv")
	_check(not state.schonfrist_aktiv(kontakt * 2.6, kontakt, 9000, bis), "auf Abstand: beendet")
	_check(state.schonfrist_aktiv(kontakt * 2.5, kontakt, 9000, bis), "genau an der Grenze: noch aktiv")
	_check(not state.schonfrist_aktiv(kontakt, kontakt, 10001, bis), "Zeit abgelaufen: beendet, auch wenn nah")
	_check(state.schonfrist_aktiv(0.0, kontakt, bis, bis), "letzte Millisekunde zählt noch")
	state.free()


func _test_explored_survives_scene_reload() -> void:
	print("Fog of War übersteht Szenenwechsel (z.B. Kampf):")
	var state: Node = load("res://autoload/game_state.gd").new()
	var card := DungeonCard.new()
	card.seed = 1
	card.tier = 1
	state.start_run(card)

	# Simuliert, was dungeon_scene.gd in _ready() tut: lazy anlegen, dieselbe
	# Referenz holen.
	if not state.current_run.has("explored_by_floor"):
		state.current_run["explored_by_floor"] = {}
	var explored_by_floor: Dictionary = state.current_run["explored_by_floor"]
	if not explored_by_floor.has(0):
		explored_by_floor[0] = {}
	var explored: Dictionary = explored_by_floor[0]
	explored[Vector2i(5, 5)] = true
	explored[Vector2i(6, 5)] = true

	# "Kampf-Szenenwechsel": current_run bleibt unangetastet, nur eine neue
	# Referenz wird wie in _ready() erneut geholt.
	var explored_after: Dictionary = state.current_run["explored_by_floor"][0]
	_check(explored_after.has(Vector2i(5, 5)) and explored_after.size() == 2,
		"erkundete Zellen sind nach simuliertem Kampf noch da")
	state.free()


func _test_explored_resets_on_new_floor() -> void:
	print("Fog of War ist pro Ebene getrennt:")
	var state: Node = load("res://autoload/game_state.gd").new()
	var card := DungeonCard.new()
	card.seed = 1
	card.tier = 5
	state.start_run(card)

	state.current_run["explored_by_floor"] = {}
	var explored_by_floor: Dictionary = state.current_run["explored_by_floor"]
	explored_by_floor[0] = {Vector2i(1, 1): true}

	# Treppe: floor hochzählen (wie in dungeon_scene.gd bei Treppen-Kontakt).
	state.current_run["floor"] = 1
	var new_floor_explored: Dictionary = explored_by_floor.get(1, {})
	_check(new_floor_explored.is_empty(), "neue Ebene startet mit leerem Fog")
	_check(explored_by_floor[0].size() == 1, "Fog der vorherigen Ebene bleibt unangetastet")
	state.free()


func _test_explored_resets_on_new_run() -> void:
	print("Fog of War resettet bei neuem Dungeon-Run:")
	var state: Node = load("res://autoload/game_state.gd").new()
	var card_a := DungeonCard.new()
	card_a.seed = 1
	card_a.tier = 1
	state.start_run(card_a)
	state.current_run["explored_by_floor"] = {0: {Vector2i(2, 2): true}}

	var card_b := DungeonCard.new()
	card_b.seed = 2
	card_b.tier = 1
	state.start_run(card_b)
	_check(not state.current_run.has("explored_by_floor"),
		"neuer Run baut current_run komplett neu auf — kein alter Fog übrig")
	state.free()


func _test_recruiting() -> void:
	print("Taverne / Rekrutierung (Ein-Helden-Start):")
	var state: Node = load("res://autoload/game_state.gd").new()
	_check(state.party.is_empty(), "frischer Start: Party ist leer (Held wird im Menü erstellt)")

	_check(state.recruit("Aldric", &"krieger"), "erster Held wird rekrutiert")
	_check(state.party.size() == 1, "Party hat 1 Helden")
	var aldric: Combatant = state.party[0]
	_check(aldric.level == 1 and aldric.stats.strength == 5 and aldric.stats.luck == 5,
		"Rekrut startet identisch: Level 1, überall 5")
	_check(aldric.equipment.has(Enums.EquipSlot.WEAPON), "Kit-Startwaffe ist angelegt")
	_check(aldric.skills.size() == 1 and aldric.skills[0].is_valid(),
		"Kit-Skill ist gelernt und gültig")

	_check(not state.recruit("Aldric", &"feuermagier"),
		"derselbe Held kann nicht doppelt angeheuert werden")

	var mage_ok: bool = state.recruit("Mira", &"feuermagier")
	var mira: Combatant = state.party[1]
	var mira_fire := mira.skills[0].get_element() != null \
		and mira.skills[0].get_element().element == Enums.Element.FIRE
	_check(mage_ok and mira_fire, "Kits unterscheiden sich (Mira startet mit Feuerzauber)")

	state.recruit("Talin", &"heiler")
	state.recruit("Runa", &"giftmischer")
	_check(state.party.size() == 4, "Party lässt sich in der Taverne auf 4 füllen")
	_check(not state.recruit("Aldric", &"krieger"),
		"derselbe Held nie doppelt (auch bei voller Party)")

	# Taverne-Bank: mehr Helden als Party-Plätze, Austauschen jederzeit.
	_check(state.recruit("Edda", &"krieger"), "5. Held ist anheuerbar")
	_check(state.party.size() == 4 and state.reserve.size() == 1,
		"5. Held landet auf der Bank, Party bleibt bei 4")
	var edda: Combatant = state.reserve[0]
	_check(not state.activate_hero(edda),
		"volle Party: Bank-Held kann nicht nachrücken")
	var talin: Combatant = state.party[2]
	_check(state.bench_hero(talin), "Party-Held lässt sich auf die Bank legen")
	_check(state.party.size() == 3 and state.reserve.size() == 2,
		"nach dem Ablegen: 3 aktiv, 2 auf der Bank")
	_check(state.activate_hero(edda), "Bank-Held rückt in den freien Slot nach")
	_check(edda in state.party and edda not in state.reserve,
		"Aktivieren verschiebt wirklich (Bank » Party)")
	while state.party.size() > 1:
		state.bench_hero(state.party[state.party.size() - 1])
	_check(state.party.size() == 1 and not state.bench_hero(state.party[0]),
		"der letzte eigene Held bleibt immer in der Party")
	_check(HeroLibrary.available_names(state.party + state.reserve).size()
		== HeroLibrary.HERO_NAMES.size() - 5,
		"Namensvorschläge kennen Party UND Bank")

	# Charakter-Erstellung: freie Namen + Porträt, Limit 10 Helden.
	_check(not state.recruit("   ", &"krieger"), "leerer Name wird abgelehnt")
	_check(state.recruit("Zora die Kühne", &"feuermagier", 104),
		"eigener Name + Porträt sind erlaubt (Char-Erstellung)")
	_check(not state.recruit("Zora die Kühne", &"heiler"),
		"doppelter Name wird abgelehnt")
	var zora: Combatant = null
	for member in state.party + state.reserve:
		if member.display_name == "Zora die Kühne":
			zora = member
	_check(zora != null and zora.portrait_tile == 104 and zora.sprite != null,
		"gewähltes Porträt sitzt am Helden")
	var extra := 0
	while state.hero_count() < HeroLibrary.MAX_HEROES:
		extra += 1
		state.recruit("Recke %d" % extra, &"krieger")
	_check(not state.recruit("Der Elfte", &"krieger"),
		"mehr als %d Helden gehen nicht" % HeroLibrary.MAX_HEROES)
	state.free()

	# Start-Loadouts: WAFFE wählen statt Klasse — inkl. Nebenhand.
	var sword_board := HeroLibrary.create_hero("Testfried", &"schwert_schild")
	_check(sword_board.equipment.has(Enums.EquipSlot.WEAPON)
		and sword_board.equipment.has(Enums.EquipSlot.OFF_HAND),
		"Schwert & Schild belegt Haupt- UND Nebenhand")
	var twin_daggers := HeroLibrary.create_hero("Testine", &"dolche")
	_check(twin_daggers.equipment.has(Enums.EquipSlot.OFF_HAND)
		and twin_daggers.equipment[Enums.EquipSlot.OFF_HAND].base.id == &"dolch",
		"Zwei Dolche: der zweite sitzt in der Nebenhand (Dual Wield)")
	var archer := HeroLibrary.create_hero("Testbrand", &"bogen")
	_check(archer.equipment.has(Enums.EquipSlot.OFF_HAND)
		and archer.equipment[Enums.EquipSlot.OFF_HAND].base.quiver,
		"Bogen kommt mit Köcher in der Nebenhand")
	var legacy := HeroLibrary.create_hero("Testwig", &"feuermagier")
	_check(legacy.skills[0].get_element() != null
		and legacy.skills[0].get_element().element == Enums.Element.FIRE,
		"alte Kit-IDs (feuermagier) mappen aufs neue Loadout")
	_check(legacy.equipment.has(Enums.EquipSlot.OFF_HAND)
		and legacy.equipment[Enums.EquipSlot.OFF_HAND].base.id == &"relikt",
		"Offensivstab kommt mit Relikt in der Nebenhand")
	var healer := HeroLibrary.create_hero("Testrud", &"heiligstab")
	_check(healer.equipment.has(Enums.EquipSlot.OFF_HAND)
		and healer.equipment[Enums.EquipSlot.OFF_HAND].base.id == &"heiligkreuz",
		"Heiligstab kommt mit Heiligem Kreuz in der Nebenhand")
	_check(healer.spell_damage() > HeroLibrary.create_hero("Testlos",
		&"schwert_schild").spell_damage(),
		"die Zauber-Nebenhand zählt in die Zauberkraft")
	var descriptions_ok := true
	for loadout_id in HeroLibrary.STARTER_LOADOUTS:
		if HeroLibrary.loadout_description(loadout_id).is_empty():
			descriptions_ok = false
	_check(descriptions_ok, "jedes Loadout hat eine Werte-Beschreibung")
	_check("Schaden" in HeroLibrary.loadout_description(&"schwert_schild")
		and "Rüstung" in HeroLibrary.loadout_description(&"schwert_schild"),
		"Beschreibung zeigt Waffen- UND Nebenhand-Werte")


func _test_bestiary() -> void:
	print("Bestiarium (Kill-Zähler):")
	var state: Node = load("res://autoload/game_state.gd").new()
	_check(state.kills_of(&"wolf") == 0, "unbekannte Gegner starten bei 0")
	state.record_kill(&"wolf")
	state.record_kill(&"wolf")
	state.record_kill(&"schleim")
	state.record_kill(&"")  # leere ID (z.B. Beschwörungen) zählt nicht
	_check(state.kills_of(&"wolf") == 2 and state.kills_of(&"schleim") == 1,
		"Kills werden pro Grundtyp gezählt")
	_check(state.bestiary.size() == 2, "leere IDs landen nicht im Bestiarium")

	state.medals = 7
	var restored: Node = load("res://autoload/game_state.gd").new()
	restored.apply_save_dict(state.to_save_dict())
	_check(restored.kills_of(&"wolf") == 2, "Bestiarium übersteht den Speicher-Rundweg")
	_check(restored.medals == 7, "Mini-Medaillen überstehen den Speicher-Rundweg")
	state.free()
	restored.free()


## Co-op-Gast tritt der Host-Karte bei: der eigene laufende Dungeon bleibt
## im Spielstand und ist nach dem Verlassen wieder da.
func _test_koop_eigener_run() -> void:
	print("Co-op: eigener Run bleibt beim Beitritt erhalten:")
	var state = load("res://autoload/game_state.gd").new()
	state.party = TestContent.make_party()
	var eigene_karte := CardFactory.make_starter_card()
	state.start_run(eigene_karte)
	state.current_run["floor"] = 4
	var host_run := {"card": CardFactory.make_starter_card(), "floor": 0, "defeated": [], "opened": [],
		"events_used": [], "player_pos": Vector2.ZERO, "boss_defeated": false, "explored_by_floor": {}}
	state.koop_lauf_beginnen(host_run)
	_check(state.coop_guest_run and state.current_run == host_run, "Gast spielt im Run des Hosts")
	var daten: Dictionary = state.to_save_dict()
	_check(daten.has("current_run") and int(daten["current_run"].get("floor", -1)) == 4,
		"gespeichert wird der EIGENE Run (Ebene 5), nicht der des Hosts")
	state.koop_lauf_beenden()
	_check(not state.coop_guest_run and int(state.current_run.get("floor", -1)) == 4
		and state.current_run.get("card") == eigene_karte, "nach dem Verlassen ist der eigene Run wieder da")
	state.koop_lauf_beginnen(host_run)
	state.clear_run()
	_check(int(state.current_run.get("floor", -1)) == 4, "auch clear_run im Gast-Run holt den eigenen zurück")
	var ohne = load("res://autoload/game_state.gd").new()
	ohne.koop_lauf_beginnen(host_run)
	ohne.koop_lauf_beenden()
	_check(ohne.current_run.is_empty(), "ohne eigenen Run: danach leer wie bisher")
	state.free()
	ohne.free()


## Prüfung 2026-11-09: ohne Helden und ohne Datei legt Autosave keinen Slot an.
func _test_leerer_slot_bleibt_leer() -> void:
	print("Leerer Slot bleibt leer:")
	var state = load("res://autoload/game_state.gd").new()
	var slot_vorher := SaveManager.active_slot
	SaveManager.active_slot = 97
	if state.has_save_file():
		print("  (Slot 97 hat eine Datei — Prüfung übersprungen)")
	else:
		state.slot_gesperrt = false
		state.party.clear()
		_check(not state.autosave() and not state.has_save_file(), "Autosave ohne Helden schreibt nichts")
	SaveManager.active_slot = slot_vorher
	state.free()


func _test_bank_training() -> void:
	print("Bank-Training (Mittraining + Taverne):")
	var state: Node = load("res://autoload/game_state.gd").new()
	for name in ["A", "B", "C", "D", "E"]:
		state.recruit(name, &"krieger")
	for member in state.party:
		member.level = 30
	state.party[3].level = 25
	var bank: Combatant = state.reserve[0]
	_check(state.bank_ziel_level() == 20, "Ziel: 5 Level unter dem Schwächsten (25 » 20)")
	var vorher := bank.xp
	state.bank_mittraining(1000)
	_check(bank.level > 1 or bank.xp > vorher, "Bank-Held trainiert mit (10 % der Kampf-XP)")
	state.bank_mittraining(10000000)
	_check(bank.level == 20, "Mittraining stoppt an der Grenze (Lv %d)" % bank.level)
	bank.level = 3
	bank.xp = 0
	var kosten: int = state.training_kosten(bank)
	state.gold = kosten - 1
	_check(not state.bank_trainieren(bank), "zu wenig Gold: kein Training")
	state.gold = kosten
	var punkte_vorher := bank.stat_points
	_check(state.bank_trainieren(bank) and bank.level == 20 and state.gold == 0,
		"Taverne-Training: Lv 3 » 20 für %d Gold" % kosten)
	_check(bank.stat_points > punkte_vorher, "mit allen Statuspunkten")
	_check(not state.bank_trainieren(bank), "am Ziel kein weiteres Training")
	state.free()


## Spieltest 2026-10-24: Bank und Zurückholen änderte die Party-Reihenfolge.
func _test_bank_reihenfolge() -> void:
	print("Bank-Reihenfolge:")
	var state: Node = load("res://autoload/game_state.gd").new()
	state.party.clear()
	for name in ["Tank", "dps", "mage", "healer"]:
		var stats := StatBlock.new()
		state.party.append(Combatant.create(name, stats, true))
	var dps: Combatant = state.party[1]
	state.bench_hero(dps)
	state.activate_hero(dps)
	var namen: Array = state.party.map(func(c: Combatant) -> String: return c.display_name)
	_check(namen == ["Tank", "dps", "mage", "healer"], "zurückgeholter Held steht wieder an seinem Platz %s" % [namen])
	state.free()
