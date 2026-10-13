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
	var level_block := BlockLibrary.get_block(&"eff_weaken")   # Start, Level 2
	var training_block := BlockLibrary.get_block(&"eff_stun")  # Training: Stumpf 3

	_check(not BlockLibrary.is_unlocked(level_block, 1, []), "Level-Baustein unter Level gesperrt")
	_check(BlockLibrary.is_unlocked(level_block, 2, []), "Level-Baustein ab Level frei")
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
	_check(ab_level.get(1, 0) == 4, "Level 1: 4 Grundklötze (2 Quellen, Selbst, Zusatztreffer)")
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
	print("Schmiede (Gear-Crafting nach Typ):")
	# Schmiede-Materialien existieren und droppen (Gewicht > 0).
	for id in [&"eisenerz", &"lederreste", &"kristallstaub"]:
		_check(MaterialLibrary.MATERIALS.has(id),
			"Material %s existiert" % MaterialLibrary.display_name(id))

	# Kategorie = genau EIN Basis-Item ("Dolch ist Dolch") — die Vielfalt
	# kommt aus Level, Rarität, Affixen und damit auch den Namen.
	var always_dagger := true
	var names := {}
	for i in 40:
		var item := Smith.craft(&"dolch", 6, _rng(i))
		if item == null or item.base.id != &"dolch":
			always_dagger = false
		else:
			names[item.get_display_name()] = true
	_check(always_dagger, "Kategorie 'Dolch' liefert IMMER einen Dolch")
	_check(names.size() >= 5,
		"Vielfalt trotz einer Basis: %d verschiedene Namen über 40 Crafts (Affixe)"
		% names.size())

	# Jede Kategorie im Katalog liefert genau ihre Basis.
	var catalog_ok := true
	for section in Smith.SECTIONS:
		for base_id in section["bases"]:
			var item := Smith.craft(base_id, 10, _rng(int(hash(base_id))))
			if item == null or item.base.id != base_id:
				catalog_ok = false
				printerr("    Kategorie kaputt: %s" % base_id)
	_check(catalog_ok, "alle %d Schmiede-Kategorien liefern genau ihr Item" % _category_count())

	var bow := Smith.craft(&"bogen", 5, _rng(3))
	_check(bow != null and bow.base.hit_count == 2, "Bogen: 2 Pfeile pro Angriff")
	var crossbow := Smith.craft(&"armbrust", 6, _rng(3))
	_check(crossbow != null and crossbow.base.armor_pierce > 0.0,
		"Armbrust: Rüstungsdurchdringung")
	var staff := Smith.craft(&"offensivstab", 5, _rng(7))
	_check(staff != null and staff.base.spell_damage > 0, "Offensivstab: Zauberkraft")
	var robe := Smith.craft(&"robe_schaden", 5, _rng(7))
	_check(robe != null and robe.base.spell_damage > 0
		and robe.base.slot == Enums.EquipSlot.ARMOR,
		"Schadensrobe: Rüstungs-Slot mit Zauberkraft")

	# Item-Level streut leicht um den Party-Schnitt.
	var levels := {}
	var in_range := true
	for i in 60:
		var item := Smith.craft(&"ruestung_leicht", 8, _rng(i * 3))
		levels[item.item_level] = true
		if absi(item.item_level - 8) > Smith.LEVEL_DEVIATION:
			in_range = false
	_check(in_range, "Item-Level bleibt im Band Party-Schnitt ±%d" % Smith.LEVEL_DEVIATION)
	_check(levels.size() >= 3, "Item-Level streut (%d verschiedene Level)" % levels.size())

	# Die Schmiede liefert keinen grauen Schrott.
	var no_common := true
	for i in 50:
		if Smith.craft(&"helm_leicht", 4, _rng(i + 900)).rarity == Enums.Rarity.COMMON:
			no_common = false
	_check(no_common, "gecraftete Items sind mindestens Magisch")

	# Kategorien öffnen sich mit dem Level: Bogen (Stufe 2) ist ab Level 1
	# erreichbar (Streuung nach oben ±2), Armbrust (Stufe 5) erst ab Level 3.
	_check(Smith.can_craft(&"bogen", 1), "Bogen ist ab Level 1 craftbar (Streuung nach oben)")
	_check(not Smith.can_craft(&"armbrust", 1), "Armbrust ist auf Level 1 noch gesperrt")
	_check(Smith.can_craft(&"armbrust", 3), "Armbrust öffnet ab Level 3")

	# Neuwürfeln: Basis/Level/Rarity bleiben, Affix-Anzahl passt zur Rarity.
	var item := Smith.craft(&"schwert", 6, _rng(11))
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


func _category_count() -> int:
	var count := 0
	for section in Smith.SECTIONS:
		count += section["bases"].size()
	return count
