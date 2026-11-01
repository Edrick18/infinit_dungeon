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
	_test_zahl_und_anzahl()
	_test_kartennamen_sprache()
	_test_skillnamen_sprache()
	_test_texte_englisch()
	Loc.set_language("de")
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
	_check(skill.get_mp_cost() == 5, "COST_REDUCTION 50%: 10 » 5")

	# Waffennutzung + Form ist verboten.
	var aoe := FormBlock.new()
	aoe.form = Enums.SkillForm.AOE
	skill.blocks.append(aoe)
	_check(skill.is_valid(), "Waffenangriff + Alle Gegner ist gültig (Salve)")
	aoe.form = Enums.SkillForm.ALLY
	_check(not skill.is_valid(), "Waffenangriff + Verbündeter ist ungültig")

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
	# Genus: Präfix wird passend dekliniert (Spieltest 2026-10-22).
	var namen := {}
	var basis_namen := {&"heiligstab": "Heiligstab", &"axt": "Axt", &"stiefel_schwer": "Panzerstiefel",
		&"ruestung_schwer": "Schwere Rüstung", &"amulett": "Amulett", &"helm_leicht": "Leichter Helm"}
	for id in basis_namen:
		var basis := ItemBase.new()
		basis.id = id
		basis.display_name = basis_namen[id]
		var stueck := ItemInstance.new()
		stueck.base = basis
		stueck.affixes = [flaming]
		namen[id] = stueck.get_display_name()
	_check(namen[&"heiligstab"] == "Flammender Heiligstab" and namen[&"axt"] == "Flammende Axt"
		and namen[&"stiefel_schwer"] == "Flammende Panzerstiefel" and namen[&"amulett"] == "Flammendes Amulett"
		and namen[&"ruestung_schwer"] == "Flammende schwere Rüstung" and namen[&"helm_leicht"] == "Flammender leichter Helm",
		"Präfix nach Genus/Numerus dekliniert %s" % [namen.values()])
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


func _test_zahl_und_anzahl() -> void:
	print("Loc.zahl / Loc.anzahl:")
	Loc.set_language("de")
	_check(Loc.zahl(1.5) == "1,5" and Loc.zahl(2.0, 2) == "2,00", "DE: Komma (1,5 / 2,00)")
	_check(Loc.anzahl(1, "Runde", "Runden", "round", "rounds") == "1 Runde"
		and Loc.anzahl(3, "Runde", "Runden", "round", "rounds") == "3 Runden", "DE: 1 Runde / 3 Runden")
	Loc.set_language("en")
	_check(Loc.zahl(1.5) == "1.5" and Loc.zahl(1.15, 2) == "1.15", "EN: Punkt (1.5 / 1.15)")
	_check(Loc.anzahl(1, "Punkt", "Punkte", "point", "points") == "1 point"
		and Loc.anzahl(0, "Punkt", "Punkte", "point", "points") == "0 points", "EN: 1 point / 0 points")
	Loc.set_language("de")


func _test_kartennamen_sprache() -> void:
	print("Kartennamen DE/EN:")
	Loc.set_language("de")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var card := CardFactory.make_card(9, rng)
	var name_de := card.display_name
	_check(card.name_teile.size() == 3, "neue Karte speichert die Namens-Indizes")
	_check(name_de.begins_with(CardFactory.NAME_PREFIXES[card.name_teile[0]]), "DE-Name aus dem DE-Pool: " + name_de)
	Loc.set_language("en")
	var name_en := card.display_name
	_check(name_en.begins_with(CardFactory.NAME_PREFIXES_EN[card.name_teile[0]])
		and name_en.ends_with(CardFactory.NAME_SUFFIXES_EN[card.name_teile[2]]),
		"nach set_language(en) heißt dieselbe Karte englisch: " + name_en)
	var zurueck := DungeonCard.from_dict(card.to_dict())
	_check(zurueck.name_teile == card.name_teile and zurueck.display_name == name_en,
		"Roundtrip to_dict/from_dict behält die Teile")
	Loc.set_language("de")
	_check(zurueck.display_name == name_de, "zurück auf Deutsch: wieder der DE-Name")
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 4711
	var gleich := CardFactory.make_card(9, rng2)
	_check(gleich.seed == card.seed and gleich.name_teile == card.name_teile
		and gleich.modifier_ids == card.modifier_ids, "gleicher RNG » gleiche Karte und Namens-Teile")

	# Migration alter Spielstände (nur display_name gespeichert).
	var alt_de := DungeonCard.from_dict({"display_name": "Blutiger Tempel der Gier",
		"biome": Enums.Biome.RUINS})
	_check(alt_de.name_teile == ([3, 0, 3] as Array[int]), "Alt-Name DE wird zerlegt")
	var alt_en := DungeonCard.from_dict({"display_name": "Bloody Bone Cellar of Doom",
		"biome": Enums.Biome.CRYPT})
	_check(alt_en.display_name == "Blutiger Knochenkeller des Unheils", "Alt-Name EN (Ort mit Leerzeichen) » DE: " + alt_en.display_name)
	var alt_frei := DungeonCard.from_dict({"display_name": "Verwitterte Waldkarte", "biome": Enums.Biome.FOREST})
	_check(alt_frei.name_teile.is_empty() and alt_frei.display_name == "Verwitterte Waldkarte",
		"nicht zerlegbarer Alt-Name bleibt als Text")
	var alt_stern := DungeonCard.from_dict({"display_name": "★ Stiller Hain der Qual", "biome": Enums.Biome.FOREST})
	_check(alt_stern.name_teile == ([6, 0, 1] as Array[int]), "Stern-Präfix wird vor der Zerlegung entfernt")
	var falsches_biom := DungeonCard.from_dict({"display_name": "Blutiger Tempel der Gier",
		"biome": Enums.Biome.FOREST})
	_check(falsches_biom.name_teile.is_empty(), "Ort passt nicht zum Biom » Text bleibt")
	var alt_start := DungeonCard.from_dict({"display_name": "Stiller Hain der Anfänge", "biome": Enums.Biome.FOREST})
	_check(alt_start.name_key == CardFactory.START_NAME_KEY, "alte Startkarte bekommt den Start-Schlüssel")
	Loc.set_language("en")
	_check(alt_de.display_name == "Bloody Temple of Greed", "migrierte Karte auf Englisch: " + alt_de.display_name)
	_check(alt_start.display_name == "Silent Grove of Beginnings", "Startkarte auf Englisch")
	_check(alt_frei.display_name == "Verwitterte Waldkarte", "fester Text bleibt auch auf Englisch")
	var start := CardFactory.make_starter_card()
	Loc.set_language("de")
	_check(start.display_name == "Stiller Hain der Anfänge", "auf Englisch erzeugte Startkarte heißt auf Deutsch deutsch")
	var fest := DungeonCard.from_dict(alt_frei.to_dict())
	_check(fest.name_teile.is_empty() and fest.display_name == "Verwitterte Waldkarte",
		"fester Text übersteht den Roundtrip (kein zweites Zerlegen)")
	# Co-op: der Host schickt Namens-Teile (Net._map_offer_data), der Gast baut
	# den Namen in seiner Sprache (Net "map_opened").
	var angebot := {"display_name": card.display_name, "biome": card.biome,
		"name_teile": card.name_teile.duplicate(), "name_key": card.name_key}
	Loc.set_language("en")
	_check(DungeonCard.from_dict(angebot).display_name == name_en, "Co-op-Gast sieht den Kartennamen in seiner Sprache")
	Loc.set_language("de")
	card.display_name = "Meine Karte"
	_check(card.name_teile.is_empty() and card.display_name == "Meine Karte", "Text zuweisen setzt einen festen Namen")


func _test_skillnamen_sprache() -> void:
	print("Skillnamen DE/EN:")
	Loc.set_language("de")
	var held := HeroLibrary.create_hero("Testheld", &"feuerstab")
	var start: Skill = held.skills[0]
	_check(start.display_name == "Feuerball" and start.name_key == "kit:feuerstab", "Start-Skill mit Schlüssel")
	Loc.set_language("en")
	_check(start.display_name == "Fireball", "Start-Skill wechselt nach set_language(en)")
	var vorlage := Skill.new()
	vorlage.blocks.append(BlockLibrary.get_block(&"src_weapon"))
	vorlage.display_name = "Double strike"
	vorlage.name_key = "rezept:doppelschlag"
	WerkstattLogik.ins_buch(held, vorlage)
	var buch: Skill = held.rezeptbuch.back()
	_check(buch.name_key == "rezept:doppelschlag", "Rezeptbuch-Kopie behält den Schlüssel")
	var eigen := Skill.new()
	eigen.display_name = "Mein Ball"
	var zurueck := Skill.from_dict(start.to_dict())
	Loc.set_language("de")
	_check(zurueck.display_name == "Feuerball" and buch.display_name == "Doppelschlag",
		"Roundtrip + Rückwechsel: Feuerball / Doppelschlag")
	_check(Skill.from_dict(eigen.to_dict()).display_name == "Mein Ball", "eigener Name bleibt")
	start.display_name = "Umbenannt"
	Loc.set_language("en")
	_check(start.display_name == "Umbenannt" and start.name_key.is_empty(), "umbenannter Skill behält seinen Namen")
	# Migration alter Spielstände ohne name_key.
	var alt_vorlage := Skill.from_dict({"name": "Doppelschlag", "block_ids": []})
	var alt_en := Skill.from_dict({"name": "New skill", "block_ids": []})
	var alt_kit := Skill.from_dict({"name": "Weapon Strike", "block_ids": []})
	var alt_frei := Skill.from_dict({"name": "Mein Hieb", "block_ids": []})
	_check(alt_vorlage.display_name == "Double strike", "Alt-Vorlage DE » EN: " + alt_vorlage.display_name)
	_check(alt_frei.name_key.is_empty() and alt_frei.display_name == "Mein Hieb", "Alt-Eigenname bleibt")
	Loc.set_language("de")
	_check(alt_en.display_name == "Neuer Skill" and alt_kit.display_name == "Waffenhieb",
		"Alt-Namen EN » DE: Neuer Skill / Waffenhieb")
	_check(Skill.from_dict({"name": "Feuerball", "name_key": "", "block_ids": []}).name_key.is_empty(),
		"gespeichertes leeres name_key bleibt leer (kein Migrieren)")
	var schluessel := {}
	for rezept in WerkstattLogik.REZEPTE:
		schluessel[rezept[3]] = true
	_check(schluessel.size() == WerkstattLogik.REZEPTE.size(), "Vorlagen-Schlüssel eindeutig")


func _test_texte_englisch() -> void:
	print("Texte im Englisch-Modus:")
	Loc.set_language("en")
	_check(LootGenerator.rarity_name(Enums.Rarity.EPIC) == "Epic"
		and ItemInfo.raritaet_name(Enums.Rarity.MAGIC) == "Magic", "Seltenheit englisch")
	# ItemInfo bleibt ohne UiTheme-Abhängigkeit: UiTheme braucht über
	# MenueKulisse den Autoload GameState und kompiliert hier (-s) nicht.
	_check(not FileAccess.get_file_as_string("res://scripts/ui/item_info.gd").contains("UiTheme."),
		"ItemInfo kompiliert ohne Autoloads (Farben aus Stil3D.PAL)")
	_check(LootGenerator.truhen_name(Enums.Rarity.RARE) == "Rare chest", "Truhe englisch")
	_check(CardFactory.card_affix_name(&"reich") == "Rich"
		and CardFactory.card_affix_desc(&"reich") == "+60% gold from battles", "Karten-Affix englisch")
	var deutsche_skillnamen := EnemyLibrary.SKILL_NAMEN_EN.keys()
	var deutsch_gefunden := ""
	for archetype in EnemyLibrary.all_archetypes():
		for skill in archetype.skill_pool:
			if skill.display_name in deutsche_skillnamen \
					and EnemyLibrary.SKILL_NAMEN_EN[skill.display_name] != skill.display_name:
				deutsch_gefunden = skill.display_name
	_check(deutsch_gefunden.is_empty(), "keine deutschen Gegner-Skills im Englisch-Modus " + deutsch_gefunden)
	_check(EnemyLibrary.get_archetype(&"baer").skill_pool[0].display_name == "Paw Swipe", "Prankenhieb » Paw Swipe")
	# Ein Grund-Skill ohne Eintrag in SKILL_NAMEN_EN bliebe still deutsch:
	# DE- und EN-Bibliothek Skill für Skill vergleichen.
	var namen_en: Array[String] = []
	for archetype in EnemyLibrary.all_archetypes():
		for gegner_skill in archetype.skill_pool:
			namen_en.append(gegner_skill.display_name)
	Loc.set_language("de")
	var namen_de: Array[String] = []
	for archetype in EnemyLibrary.all_archetypes():
		for gegner_skill in archetype.skill_pool:
			namen_de.append(gegner_skill.display_name)
	var unuebersetzt := ""
	for i in mini(namen_de.size(), namen_en.size()):
		if namen_de[i] == namen_en[i] and EnemyLibrary.SKILL_NAMEN_EN.get(namen_de[i], "") != namen_de[i]:
			unuebersetzt += " " + namen_de[i]
	_check(not namen_de.is_empty() and namen_de.size() == namen_en.size() and unuebersetzt.is_empty(),
		"jeder Gegner-Skill hat einen englischen Namen" + unuebersetzt)
	Loc.set_language("en")
	var hinweis := DungeonGenerator.ereignis_hinweis(DungeonGenerator.EventType.SHRINE_WARD, "E")
	var ergebnis := DungeonGenerator.schrein_ergebnis(DungeonGenerator.EventType.SHRINE_WARD)
	var notiz := DungeonGenerator.segen_notiz(&"segen_schutz")
	var zahl := "%d%%" % DungeonGenerator.SEGEN_SCHUTZ
	_check(zahl in hinweis and zahl in ergebnis and zahl in notiz, "Schutzschrein nennt überall Rüstung +30%")
	_check(DungeonGenerator.segen_status(&"segen_schutz") == [Enums.Status.DEF_UP, DungeonGenerator.SEGEN_SCHUTZ],
		"Segen-Wirkung aus derselben Quelle")
	var alle := hinweis + ergebnis + notiz + DungeonGenerator.mimic_meldung() + DungeonGenerator.opfer_meldung(5) \
		+ DungeonGenerator.truhen_meldung(Enums.Rarity.EPIC, 5)
	_check(not "Rüstung" in alle and not "Truhe" in alle and not "Gold" in alle, "Ereignis-Meldungen englisch: " + alle)
	var held := Combatant.create("Hero", StatBlock.new(), true)
	var skill := Skill.new()
	skill.display_name = "Fireball"
	var zeilen: Array[String] = [Battle.einsatz_zeile(held, skill), "Dummy takes 5 damage."]
	_check(WerkstattLogik.ohne_einsatz_zeile(zeilen, held, skill) == (["Dummy takes 5 damage."] as Array[String]),
		"Skill-Test filtert die Ansage auch auf Englisch")
	Loc.set_language("de")
	zeilen = [Battle.einsatz_zeile(held, skill), "x"]
	_check(WerkstattLogik.ohne_einsatz_zeile(zeilen, held, skill).size() == 1, "… und auf Deutsch")


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

	# Eigennamen-Lokalisierung: set_language() leert die Definitions-Caches,
	# danach bauen die Bibliotheken ihre Namen in der neuen Sprache.
	Loc.set_language("en")
	var sword_found := false
	for base in ItemLibrary.bases_for_tier(1):
		if base.display_name == "Sword":
			sword_found = true
	_check(sword_found, "EN: Item-Basis heißt 'Sword'")
	_check(ConsumableLibrary.get_def(&"heiltrank").display_name == "Healing Potion",
		"EN: Heiltrank heißt 'Healing Potion'")
	_check(MaterialLibrary.display_name(&"eisenerz") == "Iron Ore",
		"EN: Material heißt 'Iron Ore'")
	_check(EnemyLibrary.get_archetype(&"wolf").display_name == "Wolf",
		"EN: Wolf bleibt Wolf")
	Loc.set_language("de")
	_check(ConsumableLibrary.get_def(&"heiltrank").display_name == "Heiltrank",
		"Rückschaltung: wieder 'Heiltrank' (Cache-Reset wirkt)")


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
