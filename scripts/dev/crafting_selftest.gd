extends SceneTree
## Headless-Selbsttest für Baustein-Bibliothek und Freischalt-Logik:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/crafting_selftest.gd

var failures := 0


func _init() -> void:
	_test_library_integrity()
	_test_unlock_rules()
	_test_crafted_skill_works_in_battle()
	_test_smith()
	if failures == 0:
		print("SELFTEST OK — alle Crafting-Tests bestanden")
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


func _test_library_integrity() -> void:
	print("Bibliothek:")
	var blocks := BlockLibrary.all_blocks()
	_check(blocks.size() >= 15, "mindestens 15 Bausteine vorhanden (%d)" % blocks.size())

	var has_source := false
	var has_element := false
	var has_form := false
	var has_effect := false
	var has_modifier := false
	var all_named := true
	for block in blocks:
		if block is SourceBlock: has_source = true
		elif block is ElementBlock: has_element = true
		elif block is FormBlock: has_form = true
		elif block is EffectBlock: has_effect = true
		elif block is ModifierBlock: has_modifier = true
		if block.display_name.is_empty() or block.id == StringName():
			all_named = false
	_check(has_source and has_element and has_form and has_effect and has_modifier,
		"alle Kategorien (Quelle/Element/Form/Effekt/Modifikator) vertreten")
	_check(all_named, "alle Bausteine haben ID und Namen")
	_check(BlockLibrary.get_block(&"src_weapon") != null, "Zugriff per ID funktioniert")

	_check(BlockLibrary.get_block(&"src_weapon") != null
		and BlockLibrary.get_block(&"src_spell") != null,
		"beide Quellen (Waffennutzung + Zauber) craftbar")


func _test_unlock_rules() -> void:
	print("Freischaltung (Start-Bausteine + Waffen-Training):")
	var level_block := BlockLibrary.get_block(&"eff_weaken")   # Level 3
	var training_block := BlockLibrary.get_block(&"eff_stun")  # Training: Stumpf 3

	_check(not BlockLibrary.is_unlocked(level_block, 2, []), "Level-Baustein unter Level gesperrt")
	_check(BlockLibrary.is_unlocked(level_block, 3, []), "Level-Baustein ab Level frei")
	_check(not BlockLibrary.is_unlocked(training_block, 99, []),
		"Trainings-Baustein trotz hohem Level gesperrt")
	_check(BlockLibrary.is_unlocked(training_block, 1, [&"eff_stun"]),
		"Altbestand: früher erforschte Bausteine bleiben frei")
	# Skillbau 3.0: universelle Klötze kommen übers Level — auf Level 1 nur
	# das Fundament, danach (fast) jedes Level etwas Neues.
	var ab_level := {}
	for block in BlockLibrary.all_blocks():
		if block.unlock_kind == Enums.UnlockKind.LEVEL:
			ab_level[block.unlock_level] = ab_level.get(block.unlock_level, 0) + 1
	_check(ab_level.get(1, 0) == 6 and BlockLibrary.get_block(&"elem_holy").unlock_level == 1,
		"Level 1: 6 Grundklötze (2 Quellen, Selbst, Zusatztreffer, Feuer, Heilig)")
	var luecken := 0
	for level in range(2, 21):
		if not ab_level.has(level):
			luecken += 1
	_check(luecken == 0, "Level 2–20: jedes Level schaltet einen Klotz frei")


## Der Kern des Ganzen: ein rein aus Bibliotheks-Bausteinen gebauter Skill
## funktioniert unverändert im Kampfsystem.
func _test_crafted_skill_works_in_battle() -> void:
	print("Gecrafteter Skill im Kampf:")
	var skill := Skill.new()
	skill.display_name = "Werkstatt-Test"
	skill.blocks = [
		BlockLibrary.get_block(&"src_spell"),
		BlockLibrary.get_block(&"elem_fire"),
	]
	_check(skill.is_valid(), "Skill aus Bibliotheks-Bausteinen ist gültig")

	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = 7
	var stats := StatBlock.new()
	stats.intelligence = 5
	stats.spirit = 10
	stats.agility = 5
	var caster := Combatant.create("Crafter", stats, true)
	caster.innate_spell_damage = 12  # ohne Waffe: innewohnender Zauberschaden für den Test
	var target_stats := StatBlock.new()
	target_stats.vitality = 10
	var target := Combatant.create("Ziel", target_stats, false)
	battle.start([caster], [target])

	_check(battle.use_skill(caster, skill, target), "Skill wird im Kampf ausgeführt")
	_check(target.has_status(Enums.Status.BURN), "Brand-DoT aus Feuer-Element angewendet")


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_smith() -> void:
	print("Schmiede (Kategorie + Werkstoff + Level, Ergebnis zufällig):")
	# Werkstoffe: 3 Arten × 5 Stufen, plus 4 Runen (Seltenheit, Pracht, Legenden, Regelbrecher).
	for art in [&"erz", &"leder", &"kristall"]:
		_check(MaterialLibrary.ids_der_art(art).size() == 5, "5 Stufen %s" % art)
	_check(MaterialLibrary.RUNEN_RARITAET.size() == 4, "vier Runen")

	# Kategorie Nahkampf: Basis zufällig aus dem Pool, nie etwas anderes.
	var basen := {}
	var nur_nahkampf := true
	var pool: Array = Smith.kategorie(&"nahkampf")["bases"]
	for i in 80:
		var item := Smith.schmieden(&"nahkampf", 1, 10, &"", _rng(i))
		if item == null or not item.base.id in pool:
			nur_nahkampf = false
		else:
			basen[item.base.id] = true
	_check(nur_nahkampf, "Nahkampf liefert nur Nahkampfwaffen")
	_check(basen.size() >= 4, "Basis ist Zufall (%d verschiedene)" % basen.size())

	# Jede Kategorie liefert etwas (Level hoch genug für alle Basen).
	var alle_ok := true
	for k in Smith.KATEGORIEN:
		var item := Smith.schmieden(k["id"], 1, 10, &"", _rng(int(hash(k["id"]))))
		if item == null or not item.base.id in k["bases"]:
			alle_ok = false
			printerr("    Kategorie kaputt: %s" % k["id"])
	_check(alle_ok, "alle %d Kategorien liefern passende Gegenstände" % Smith.KATEGORIEN.size())

	# Level ist exakt das gewählte; Basen öffnen sich mit dem Level.
	_check(Smith.schmieden(&"ruestung", 1, 7, &"", _rng(5)).item_level == 7, "Item-Level = gewähltes Level")
	var armbrust_frueh := false
	for base in Smith.moegliche_basen(&"fernkampf", 2):
		if base.id == &"armbrust":
			armbrust_frueh = true
	_check(not armbrust_frueh, "Armbrust (ab Stufe 5) gibt es auf Level 2 noch nicht")

	# Höheres Level = mehr Gold; Werkstoff-Stufe ändert die Materialien.
	_check(Smith.kosten(&"nahkampf", 1, 10)["gold"] > Smith.kosten(&"nahkampf", 1, 5)["gold"],
		"höheres Level kostet mehr Gold")
	_check(Smith.kosten(&"nahkampf", 3, 5)["materials"].has(&"mithrilerz"), "Stufe 3 braucht Mithrilerz")
	_check(Smith.max_level(1, 50) == 12 and Smith.max_level(5, 50) == 53 and Smith.max_level(2, 4) == 7,
		"Level-Grenze: Werkstoff-Stufe und höchstes Helden-Level + 3")

	# Mindestens Magisch; edlere Werkstoffe erhöhen die Chance, garantieren nichts.
	var no_common := true
	for i in 50:
		if Smith.schmieden(&"ruestung", 1, 4, &"", _rng(i + 900)).rarity == Enums.Rarity.COMMON:
			no_common = false
	_check(no_common, "geschmiedete Items sind mindestens Magisch")
	var eisen := Smith.raritaets_chancen(1, &"")
	var sternen := Smith.raritaets_chancen(5, &"")
	_check(float(sternen.get(Enums.Rarity.EPIC, 0.0)) + float(sternen.get(Enums.Rarity.LEGENDARY, 0.0))
		> float(eisen.get(Enums.Rarity.EPIC, 0.0)) + float(eisen.get(Enums.Rarity.LEGENDARY, 0.0)) + 0.1,
		"Sternen-Werkstoff: deutlich mehr Episch/Legendär als Eisen")
	_check(float(sternen.get(Enums.Rarity.MAGIC, 0.0)) > 0.0, "… aber nicht garantiert (Magisch bleibt möglich)")
	var rune_ok := true
	for i in 60:
		if Smith.schmieden(&"schmuck", 1, 5, &"rune_episch", _rng(i + 50)).rarity < Enums.Rarity.EPIC:
			rune_ok = false
	_check(rune_ok, "Rune der Pracht garantiert mindestens Episch")

	# Drops: Kartenstufe bestimmt die Werkstoff-Stufe; Bosse bringen manchmal Runen.
	_check(MaterialLibrary.stufe_fuer_karte(1) == 1 and MaterialLibrary.stufe_fuer_karte(20) == 3
		and MaterialLibrary.stufe_fuer_karte(99) == 5, "Werkstoff-Stufe folgt der Kartenstufe")
	var hohe := 0
	for i in 200:
		var id := MaterialLibrary.roll_der_art(&"erz", _rng(i), 20)
		if MaterialLibrary.stufe(id) == 3:
			hohe += 1
	_check(hohe > 100, "auf Karte 20 droppt meist Mithril (%d/200)" % hohe)
	var runen := 0
	for i in 400:
		if MaterialLibrary.roll_rune(_rng(i + 7)) != &"":
			runen += 1
	_check(runen > 50 and runen < 160, "Boss-Runen sind selten (%d/400)" % runen)

	# Händler: Ausrüstung um den Party-Schnitt, teurer als die Schmiede.
	var levels_ok := true
	for i in 40:
		var gekauft := Haendler.ausruestung_kaufen(&"ruestung", 8, _rng(i + 300))
		if gekauft == null or absi(gekauft.item_level - 8) > Haendler.LEVEL_STREUUNG \
				or gekauft.rarity == Enums.Rarity.COMMON:
			levels_ok = false
	_check(levels_ok, "Händler-Ausrüstung: Level ≈ Party-Schnitt, mindestens Magisch")
	_check(Haendler.ausruestung_preis(8) > Smith.kosten(&"ruestung", 1, 8)["gold"] * 3,
		"Händler-Ausrüstung kostet ein Vielfaches des Schmiede-Golds")

	# Neuwürfeln: Basis/Level/Rarity bleiben, Affix-Anzahl passt zur Rarity.
	var item := Smith.schmieden(&"nahkampf", 1, 6, &"", _rng(11))
	var base_before := item.base
	var rarity_before := item.rarity
	Smith.reroll(item, _rng(99))
	_check(item.base == base_before and item.rarity == rarity_before,
		"Neuwürfeln behält Basis und Rarität")
	_check(item.affixes.size() == LootGenerator.AFFIX_COUNT[item.rarity],
		"Affix-Anzahl passt nach dem Neuwürfeln zur Rarität")

	# Kosten-Helfer im GameState.
	var state: Node = load("res://autoload/game_state.gd").new()
	state.gold = 100
	state.materials = {&"eisenerz": 2, &"lederreste": 1}
	var cost := {"gold": 50, "materials": {&"eisenerz": 2}}
	_check(state.can_pay(cost), "can_pay: Gold + Materialien reichen")
	_check(state.pay(cost) and state.gold == 50 and state.material_count(&"eisenerz") == 0,
		"pay: zieht Gold und Materialien ab")
	_check(not state.pay(cost), "pay: schlägt fehl, wenn Materialien fehlen")
	state.free()
