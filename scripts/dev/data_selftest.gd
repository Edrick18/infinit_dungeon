extends SceneTree
## Headless-Selbsttest fürs Datenmodell:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/data_selftest.gd
## Baut je ein Beispiel jeder Kern-Resource und prüft die Rechenlogik.

var failures := 0


func _init() -> void:
	_test_stat_block()
	_test_skill()
	_test_item()
	_test_character()
	_test_dungeon_card()
	_test_lexicon()
	_test_bestiary_category()
	if failures == 0:
		print("SELFTEST OK — alle Datenmodell-Tests bestanden")
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


func _test_stat_block() -> void:
	print("StatBlock:")
	var a := StatBlock.new()
	a.strength = 5
	a.vitality = 10
	var b := StatBlock.new()
	b.strength = 3
	a.add(b)
	_check(a.strength == 8 and a.vitality == 10, "add() addiert korrekt")
	var c := StatBlock.new()
	c.agility = 2
	a.add_scaled(c, 4)
	_check(a.agility == 8, "add_scaled() multipliziert korrekt")


func _test_skill() -> void:
	print("Skill (Bauklötze, waffengetrieben):")
	# Flammenhieb: Waffennutzung (physisch) + Zauber + Feuer — alle drei Achsen.
	var weapon := SourceBlock.new()
	weapon.source = Enums.SkillSource.WEAPON
	weapon.mp_cost = 4
	var spell := SourceBlock.new()
	spell.source = Enums.SkillSource.SPELL
	spell.mp_cost = 6
	var fire := ElementBlock.new()
	fire.element = Enums.Element.FIRE

	var skill := Skill.new()
	skill.display_name = "Flammenhieb"
	skill.blocks = [weapon, spell, fire]

	_check(skill.is_valid(), "Waffennutzung + Zauber + Element ist gültig")
	_check(skill.get_sources().size() == 2, "zwei Quellen kombiniert (physisch + magisch)")
	_check(skill.get_mp_cost() == 10, "MP-Kosten ohne Anwender: 4 + 6 = 10")

	var cheaper := ModifierBlock.new()
	cheaper.modifier = Enums.SkillModifier.COST_REDUCTION
	cheaper.magnitude = 50
	skill.blocks.append(cheaper)
	_check(skill.get_mp_cost() == 5, "COST_REDUCTION 50%: 10 → 5")

	# Waffennutzung + Form ist verboten.
	var aoe := FormBlock.new()
	aoe.form = Enums.SkillForm.AOE
	skill.blocks.append(aoe)
	_check(not skill.is_valid(), "Waffennutzung + Form ist ungültig")

	var no_source := Skill.new()
	no_source.blocks = [fire]
	_check(not no_source.is_valid(), "Skill ohne Quelle ist ungültig")


func _test_item() -> void:
	print("Item (Basis + Affixe):")
	var sword := ItemBase.new()
	sword.display_name = "Kurzschwert"
	sword.slot = Enums.EquipSlot.WEAPON
	sword.base_damage = 8

	var flaming := Affix.new()
	flaming.is_prefix = true
	flaming.name_part = "Flammendes"
	flaming.bonus_damage = 4

	var of_storm := Affix.new()
	of_storm.is_prefix = false
	of_storm.name_part = "des Sturms"
	of_storm.stat_bonus = StatBlock.new()
	of_storm.stat_bonus.agility = 3

	var item := ItemInstance.new()
	item.base = sword
	item.affixes = [flaming, of_storm]

	_check(item.get_display_name() == "Flammendes Kurzschwert des Sturms",
		"Namensbildung Prefix + Basis + Suffix")
	_check(item.get_total_damage() == 12, "Schaden: 8 Basis + 4 Affix = 12")
	_check(item.get_total_stat_bonus().agility == 3, "Stat-Boni aus Affixen summiert")


func _test_character() -> void:
	print("CharacterDef:")
	var hero := CharacterDef.new()
	hero.base_stats = StatBlock.new()
	hero.base_stats.strength = 5
	hero.growth_per_level = StatBlock.new()
	hero.growth_per_level.strength = 2

	_check(hero.stats_at_level(1).strength == 5, "Level 1 = Basiswerte")
	_check(hero.stats_at_level(10).strength == 23, "Level 10: 5 + 9×2 = 23")
	_check(CharacterDef.skill_slots_for_level(1) == 1, "Level 1: 1 Skill-Slot")
	_check(CharacterDef.skill_slots_for_level(5) == 2, "Level 5: 2 Slots")
	_check(CharacterDef.skill_slots_for_level(23) == 5, "Level 23: 5 Slots")


func _test_dungeon_card() -> void:
	print("DungeonCard:")
	var card := DungeonCard.new()
	card.display_name = "Verwitterte Waldkarte"
	card.seed = 123456
	card.tier = 4
	card.modifier_ids = [&"burning", &"armored"]
	_check(card.modifier_ids.size() == 2, "Modifikatoren fix auf der Karte gespeichert")


func _test_lexicon() -> void:
	print("Lexikon (Spielhilfe, zweisprachig):")
	_check(LexiconLibrary.categories().size() >= 6, "mindestens 6 Kategorien")
	_check(LexiconLibrary.all_entries().size() >= 20,
		"mindestens 20 Einträge (%d)" % LexiconLibrary.all_entries().size())

	# Jeder Eintrag ist vollständig zweisprachig und einer Kategorie zugeordnet.
	var category_ids := {}
	for category in LexiconLibrary.categories():
		category_ids[category["id"]] = true
	var complete := true
	for entry in LexiconLibrary.all_entries():
		if not category_ids.has(entry["cat"]):
			complete = false
			printerr("    Eintrag ohne Kategorie: %s" % entry.get("t_de", "?"))
		for key in ["t_de", "t_en", "b_de", "b_en"]:
			if String(entry.get(key, "")).is_empty():
				complete = false
				printerr("    unvollständig: %s (%s)" % [entry.get("t_de", "?"), key])
	_check(complete, "jeder Eintrag hat Titel + Inhalt in Deutsch UND Englisch")

	# Jede Kategorie hat Einträge, und die Sprache schaltet die Inhalte um.
	var all_filled := true
	for category in LexiconLibrary.categories():
		if LexiconLibrary.entries(category["id"]).is_empty():
			all_filled = false
	_check(all_filled, "keine leere Kategorie")

	Loc.language = "de"
	var de_title: String = LexiconLibrary.entries(&"kampf")[0]["title"]
	Loc.language = "en"
	var en_title: String = LexiconLibrary.entries(&"kampf")[0]["title"]
	Loc.language = "de"
	_check(de_title != en_title, "Sprachumschaltung liefert andere Texte (%s / %s)"
		% [de_title, en_title])
	_check(Loc.pick("Hallo", "Hello") == "Hallo", "Loc.pick: Deutsch als Standard")
	Loc.language = "en"
	_check(Loc.pick("Hallo", "Hello") == "Hello", "Loc.pick: Englisch nach Umschaltung")
	Loc.language = "de"


func _test_bestiary_category() -> void:
	print("Bestiarium im Lexikon:")
	var found := false
	for category in LexiconLibrary.categories():
		if category["id"] == &"bestiarium":
			found = true
	_check(found, "Bestiarium-Kategorie existiert")
	var entries := LexiconLibrary.entries(&"bestiarium")
	_check(entries.size() == EnemyLibrary.all_archetypes().size() + 1,
		"ein Eintrag pro Grundtyp + Fortschritts-Zeile (%d)" % entries.size())
	var hidden := 0
	for entry in entries:
		if entry["title"] == "???":
			hidden += 1
	_check(hidden == EnemyLibrary.all_archetypes().size(),
		"ohne Kills sind alle Einträge verborgen (???)")
