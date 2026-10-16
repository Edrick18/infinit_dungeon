extends "res://scripts/dev/balance_sim.gd"
## Balance-Wächter: rechnet eine verkürzte Boss-Tabelle und prüft, dass die
## Kennzahlen in ihren ZIELKORRIDOREN bleiben. Schlägt Alarm, wenn eine
## Änderung (Rüstung, Kosten, Skalierung …) die Balance unbemerkt kippt —
## am 2026-10-15/16 ist das dreimal passiert, bevor die Boss-Tabelle lief.
## Deterministisch (feste Seeds), läuft ~1 Minute:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/balance_selftest.gd
## Korridore bewusst großzügig (24 Kämpfe je Zelle) — sie fangen Kipper, keine
## Feinjustage. Wer die Balance ABSICHTLICH verschiebt, passt sie hier an.

const KAEMPFE := 24

var failures := 0


func _init() -> void:
	_test_bosse()
	_test_boss_typen()
	_test_ruestung()
	_test_grind()
	if failures == 0:
		print("SELFTEST OK — Balance im Zielkorridor")
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


## Sieg-Anteil und Ø Runden aus KAEMPFE Kämpfen (Party-Level, Kartenstufe).
func _messen(level: int, stufe: int, boss: bool) -> Dictionary:
	var siege := 0
	var runden := 0
	for i in KAEMPFE:
		var rng := RandomNumberGenerator.new()
		rng.seed = 900000 + i * 613 + stufe * 17 + (1 if boss else 0)
		var card := CardFactory.make_card(stufe, rng)
		var party := _make_party(level, level)
		var foes := EnemyFactory.make_encounter(card, rng, boss, card.floor_count - 1 if boss else 0)
		var ergebnis := _run_battle(party, foes, rng.randi())
		runden += int(ergebnis["rounds"])
		if ergebnis["won"]:
			siege += 1
	return {"sieg": 100.0 * siege / KAEMPFE, "runden": float(runden) / KAEMPFE}


func _im_korridor(wert: float, von: float, bis: float, label: String) -> void:
	_check(wert >= von and wert <= bis, "%s: %.1f (Ziel %.1f-%.1f)" % [label, wert, von, bis])


func _test_bosse() -> void:
	print("Bosse (gleiches Level = Kartenstufe):")
	# [Stufe, Sieg von, Sieg bis] — Ziel: unten ~80 %, Stufe 100 ~55 %, danach hart.
	for zeile in [[10, 60, 100], [30, 50, 92], [50, 50, 90], [100, 35, 78], [150, 15, 60]]:
		var m := _messen(zeile[0], zeile[0], true)
		_im_korridor(m["sieg"], zeile[1], zeile[2], "Stufe %d Boss Sieg-%%" % zeile[0])
		if zeile[0] <= 100:
			# Stufe 30 liegt bei ~15-18 (Schleimgott hält lange) — Kandidat zum Nachschärfen.
			_im_korridor(m["runden"], 6, 20, "Stufe %d Boss Ø Runden (Ziel ~10)" % zeile[0])
	print("Farmen hilft (10 Level Vorsprung):")
	_im_korridor(_messen(110, 100, true)["sieg"], 75, 100, "Stufe 100 Boss mit Level 110 Sieg-%")
	print("Normale Gegner bleiben Alltag:")
	for stufe in [10, 50, 100]:
		_im_korridor(_messen(stufe, stufe, false)["sieg"], 92, 100, "Stufe %d normal Sieg-%%" % stufe)


## Kein Boss-Typ darf aus der Reihe tanzen (2026-10-16: Schleimgott 25 Runden,
## Dämonenkönig 0 % — erst die Aufschlüsselung je Typ zeigte es).
func _test_boss_typen() -> void:
	print("Boss-Typen auf Stufe 60 (keiner unter 35 % oder über 20 Runden):")
	var je_typ := {}
	for i in 72:
		var rng := RandomNumberGenerator.new()
		rng.seed = 900000 + i * 613 + 60 * 17 + 1
		var card := CardFactory.make_card(60, rng)
		var party := _make_party(60, 60)
		var foes := EnemyFactory.make_encounter(card, rng, true, card.floor_count - 1)
		var typ := String(foes[0].archetype_id)
		var ergebnis := _run_battle(party, foes, rng.randi())
		var info: Dictionary = je_typ.get(typ, {"n": 0, "sieg": 0, "runden": 0})
		info["n"] += 1
		info["runden"] += int(ergebnis["rounds"])
		if ergebnis["won"]:
			info["sieg"] += 1
		je_typ[typ] = info
	for typ in je_typ:
		var info: Dictionary = je_typ[typ]
		if info["n"] < 4:
			continue
		var sieg: float = 100.0 * info["sieg"] / info["n"]
		var runden: float = float(info["runden"]) / info["n"]
		_check(sieg >= 35.0 and runden <= 20.0, "%s: %.0f %% Sieg, %.1f Runden (%d Kämpfe)" % [typ, sieg, runden, info["n"]])


func _test_ruestung() -> void:
	print("Rüstung mindert prozentual — auf beiden Seiten spürbar:")
	for level in [10, 50, 100]:
		var party := _make_party(level, level)
		var tank: Combatant = party[0]
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var troll := EnemyFactory.build(EnemyLibrary.get_archetype(&"troll"), level, rng, [], Enums.Biome.FOREST)
		var tank_m := 100.0 * Combatant.minderung(tank.armor_against(Enums.PhysicalSubtype.SLASH), level)
		var boss_m := 100.0 * Combatant.minderung(troll.armor_against(Enums.PhysicalSubtype.SLASH), level)
		_im_korridor(tank_m, 35, 65, "Lv %d Tank (schwer) mindert %%" % level)
		_im_korridor(boss_m, 8, 30, "Lv %d Troll mindert %%" % level)


## Levels pro Lauf auf eigener Stufe (4er-Party, jede 2. Gruppe) — analytisch
## aus denselben Formeln wie das Spiel (XP-Kurve, Gegner-XP, Level-Faktor).
func _level_pro_lauf(stufe: int) -> float:
	var ebenen := clampi(1 + (stufe - 1) / 4, 1, 5)
	var gruppen := mini(6 + stufe + mini(4, stufe / 5) * 2, 68)
	var groesse := (1.0 + (2 if stufe <= 2 else 3)) / 2.0 + mini(2, stufe / 8) / 2.0
	var level := stufe
	var xp := 0.0
	for ebene in ebenen:
		var gegner_level := stufe + ebene
		var pro_gegner := (8 + gegner_level * 4 + gegner_level * gegner_level / 20.0) \
			* LootGenerator.xp_level_faktor(level, gegner_level)
		xp += gruppen * 0.5 * groesse * pro_gegner / 4.0
	var gewonnen := 0.0
	while xp >= Combatant.xp_bedarf(level):
		xp -= Combatant.xp_bedarf(level)
		level += 1
		gewonnen += 1.0
	return gewonnen + xp / Combatant.xp_bedarf(level)


func _test_grind() -> void:
	print("Grind (Level pro Lauf auf eigener Stufe, 4er-Party):")
	_im_korridor(_level_pro_lauf(10), 2.5, 6.0, "Stufe 10")
	_im_korridor(_level_pro_lauf(30), 2.0, 4.0, "Stufe 30")
	_im_korridor(_level_pro_lauf(50), 1.2, 2.6, "Stufe 50 (Karten steigen ~2,5 — hier beginnt der Grind)")
	_im_korridor(_level_pro_lauf(100), 0.3, 1.2, "Stufe 100")
