extends SceneTree
## Headless-Selbsttest „Feinschliff“ (2026-11-02): englische Item-Namen ganz
## englisch (alle Basis×Präfix×Suffix-Kombinationen), deutsche Namen
## unverändert (Prüfsumme über alle Kombinationen), Namen hängen nur an IDs
## (Sprachwechsel bei schon erzeugten Items), gesperrte Knöpfe sind nicht
## per Tastatur erreichbar (zentral über UiTheme, auch im Taschen-voll-
## Fenster), Icons in der Dungeon-Meldung und in der Neu-würfeln-Liste.
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/feinschliff_selftest.gd
##
## Szenen greifen auf Autoloads zu: sie werden erst nach dem ersten Bild per
## load() geladen. Speichern ist gesperrt, Wegwerf-Slot 99.

## Prüfsumme aller deutschen Namen (Basis × [kein]+Präfixe × [kein]+Suffixe
## inkl. Regelbrecher, Katalog-Reihenfolge), ermittelt VOR der Übersetzung
## der Affixe (HEAD 7fd60f6): Deutsch darf sich dadurch nicht ändern.
## Einzige gewollte Änderung danach (2026-11-02): „Ring“ ist maskulin
## („Flammender Ring“ statt „Flammendes Ring“); Boss-Affixe zählen nicht mit.
const DE_ANZAHL := 11968
const DE_MD5 := "95a7c670a8d01f0d74d1160aa5daa810"

var failures := 0


func _initialize() -> void:
	await process_frame
	var waechter := FehlerWaechter.anmelden()
	var sprache_vorher := Loc.language
	_test_deutsch_unveraendert()
	_test_englisch_ganz()
	_test_sprachwechsel_bestehender_items()
	Loc.set_language("de")
	var gs: Node = root.get_node_or_null(^"GameState")
	_check(gs != null, "GameState-Autoload vorhanden")
	if gs != null:
		gs.slot_gesperrt = true
		SaveManager.active_slot = 99
		await _test_gesperrte_knoepfe()
		await _test_taschen_fenster(gs)
		await _test_meldung_icons()
		await _test_schmiede_icons(gs)
		_test_quelltext()
	Loc.set_language(sprache_vorher)
	failures += waechter.fehler_melden()
	if failures == 0:
		print("SELFTEST OK — alle Feinschliff-Tests bestanden")
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


func _bilder(anzahl: int) -> void:
	for i in anzahl:
		await process_frame


# --- Item-Namen ------------------------------------------------------------------

func _suffixe(mit_neuen := true) -> Array[Affix]:
	var liste := _nur_alte(ItemLibrary.affixes_for_tier(999, false), mit_neuen)
	if mit_neuen:
		liste.append_array(ItemLibrary.skill_affixes_for_tier(999))
	liste.append_array(ItemLibrary.regel_affixe())
	return liste


## Ohne die Affix-Arten von 2026-11-02 (prozentual, Skill-Affix) — die
## Prüfsumme sichert die Namen von vorher.
func _nur_alte(liste: Array[Affix], mit_neuen: bool) -> Array[Affix]:
	if mit_neuen:
		return liste
	var result: Array[Affix] = []
	for affix in liste:
		if affix.prozent_art == &"" and not affix.ist_skill_affix():
			result.append(affix)
	return result


## Alle Namen der aktuellen Sprache (Reihenfolge wie der Katalog).
## mit_neuen = false: nur die Affixe vor den Prozent- und Skill-Affixen.
func _alle_namen(mit_neuen := false) -> Array[String]:
	var namen: Array[String] = []
	var praefixe: Array = [null]
	praefixe.append_array(_nur_alte(ItemLibrary.affixes_for_tier(999, true), mit_neuen))
	var suffixe: Array = [null]
	suffixe.append_array(_suffixe(mit_neuen))
	for base in ItemLibrary.bases_for_tier(999):
		for p in praefixe:
			for s in suffixe:
				var item := ItemInstance.new()
				item.base = base
				if p != null:
					item.affixes.append(p)
				if s != null:
					item.affixes.append(s)
				namen.append(item.get_display_name())
	return namen


func _test_deutsch_unveraendert() -> void:
	print("Deutsche Item-Namen unverändert:")
	Loc.set_language("de")
	var namen := _alle_namen()
	_check(namen.size() == DE_ANZAHL, "alle Kombinationen (%d)" % namen.size())
	_check("\n".join(namen).md5_text() == DE_MD5, "Prüfsumme aller deutschen Namen wie vorher")
	_check(_name(&"robe_schaden", &"flammend", &"schattenabwehr") == "Flammende Schadensrobe der Schattenabwehr",
		"Stichprobe Genus f: " + _name(&"robe_schaden", &"flammend", &"schattenabwehr"))
	_check(_name(&"relikt", &"flink", &"staerke") == "Flinkes Relikt der Stärke",
		"Stichprobe Neutrum: " + _name(&"relikt", &"flink", &"staerke"))
	_check(_name(&"ruestung_schwer", &"flink", &"") == "Flinke schwere Rüstung",
		"zweites Adjektiv klein: " + _name(&"ruestung_schwer", &"flink", &""))
	_check(_name(&"dolch", &"grausam", &"sturm") == "Grausamer Dolch des Sturms",
		"Stichprobe Genus m: " + _name(&"dolch", &"grausam", &"sturm"))


func _test_englisch_ganz() -> void:
	print("Englische Item-Namen ohne deutsche Teile:")
	# Alle deutschen Namensteile samt Genus-Endungen sammeln.
	Loc.set_language("de")
	var deutsch: Array[String] = []
	var praefixe := ItemLibrary.affixes_for_tier(999, true)
	for affix in praefixe:
		deutsch.append(affix.name_part)
		var stamm := affix.name_part.left(affix.name_part.length() - 2)
		for endung in ["er", "e", "es"]:
			deutsch.append(stamm + endung)
	for affix in _suffixe():
		deutsch.append(affix.name_part)
	var de_teile := {}
	for affix in praefixe:
		de_teile[affix.id] = affix.name_part
	for affix in _suffixe():
		de_teile[affix.id] = affix.name_part
	Loc.set_language("en")
	var gleich: Array[String] = []
	for affix in ItemLibrary.affixes_for_tier(999, true) + _suffixe():
		if affix.name_part == de_teile.get(affix.id, ""):
			gleich.append(String(affix.id))
	_check(gleich.is_empty(), "jeder Affix hat einen englischen Namensteil %s" % [gleich])
	var namen := _alle_namen(true)
	var schlecht: Array[String] = []
	var umlaut := RegEx.create_from_string("[äöüÄÖÜß]")
	for name in namen:
		var mit_rand := " %s " % name
		var treffer := umlaut.search(name) != null or mit_rand.contains(" der ") or mit_rand.contains(" des ")
		if not treffer:
			for wort in deutsch:
				if mit_rand.contains(" %s " % wort):
					treffer = true
					break
		if treffer:
			schlecht.append(name)
	_check(namen.size() > DE_ANZAHL and schlecht.is_empty(),
		"%d englische Namen ohne deutsche Wörter %s" % [namen.size(), schlecht.slice(0, 5)])
	_check(_name(&"robe_schaden", &"flammend", &"schattenabwehr") == "Flaming Sorcerer's Robe of Shadow Warding",
		"Beispiel: " + _name(&"robe_schaden", &"flammend", &"schattenabwehr"))
	_check(_name(&"relikt", &"flink", &"staerke") == "Nimble Relic of Strength",
		"Beispiel: " + _name(&"relikt", &"flink", &"staerke"))
	_check(_name(&"ruestung_schwer", &"brutal", &"titanen") == "Brutal Heavy Armor of the Titans",
		"englische Wortstellung, Großschreibung bleibt: " + _name(&"ruestung_schwer", &"brutal", &"titanen"))
	Loc.set_language("de")


## Name aus Basis-/Affix-IDs in der aktuellen Sprache.
func _name(base_id: StringName, praefix: StringName, suffix: StringName) -> String:
	var item := ItemInstance.new()
	item.base = ItemLibrary.get_base(base_id)
	for id in [praefix, suffix]:
		if id != &"":
			item.affixes.append(ItemLibrary.get_affix(id))
	return item.get_display_name()


func _test_sprachwechsel_bestehender_items() -> void:
	print("Namen hängen nur an IDs:")
	Loc.set_language("de")
	var item := ItemInstance.new()
	item.base = ItemLibrary.get_base(&"robe_schaden")
	item.affixes.append(ItemLibrary.get_affix(&"flammend"))
	item.affixes.append(ItemLibrary.get_affix(&"schattenabwehr"))
	item.affix_rolls = [1.2, 1.3]
	var daten := item.to_dict()
	_check(not daten.has("name") and not daten.has("display_name") and daten.has("base_id")
		and daten.has("affix_ids"), "Spielstand speichert nur IDs, keinen Anzeigenamen")
	# Das Inventar hält Items, die vor dem Sprachwechsel erzeugt wurden.
	Loc.set_language("en")
	_check(item.get_display_name() == "Flaming Sorcerer's Robe of Shadow Warding",
		"vorher erzeugtes Item heißt nach dem Wechsel englisch: " + item.get_display_name())
	_check(item.basis_name() == "Sorcerer's Robe", "basis_name() in der aktuellen Sprache")
	var geladen := ItemInstance.from_dict(daten)
	_check(geladen != null and geladen.get_display_name() == item.get_display_name(),
		"geladenes Item heißt gleich")
	Loc.set_language("de")
	_check(item.get_display_name() == "Flammende Schadensrobe der Schattenabwehr",
		"zurück auf Deutsch: " + item.get_display_name())


# --- Gesperrte Knöpfe -----------------------------------------------------------------

func _test_gesperrte_knoepfe() -> void:
	print("Gesperrte Knöpfe nicht fokussierbar:")
	var box := VBoxContainer.new()
	var ui_theme = load("res://scripts/ui/ui_theme.gd")  # untypisiert: nutzt Autoloads
	box.theme = ui_theme.get_theme()  # setzt den Haken (wie jede Szene)
	root.add_child(box)
	var oben := Button.new()
	oben.text = "oben"
	var mitte := Button.new()
	mitte.text = "mitte"
	mitte.disabled = true
	var unten := Button.new()
	unten.text = "unten"
	for k in [oben, mitte, unten]:
		box.add_child(k)
	await _bilder(2)
	_check(mitte.focus_mode == Control.FOCUS_NONE, "gesperrt eingehängt » nicht fokussierbar")
	_check(oben.focus_mode == Control.FOCUS_ALL and unten.focus_mode == Control.FOCUS_ALL,
		"aktive Knöpfe bleiben fokussierbar")
	unten.grab_focus()
	_check(unten.find_valid_focus_neighbor(SIDE_TOP) == oben, "W von unten springt über den gesperrten Knopf")
	mitte.disabled = false
	await _bilder(2)
	_check(mitte.focus_mode == Control.FOCUS_ALL, "entsperrt » wieder fokussierbar")
	_check(unten.find_valid_focus_neighbor(SIDE_TOP) == mitte, "W landet wieder auf dem entsperrten Knopf")
	# Fokussierter Knopf wird gesperrt: Fokus wandert weiter, Tastatur bleibt bedienbar.
	mitte.grab_focus()
	mitte.disabled = true
	await _bilder(2)
	var fokus := root.get_viewport().gui_get_focus_owner()
	_check(mitte.focus_mode == Control.FOCUS_NONE and fokus != null and fokus != mitte,
		"gesperrt während fokussiert » Fokus wandert weiter")
	# Fenster sperrt den Fokus ein: ein dahinter entsperrter Knopf bleibt draußen.
	var fenster := VBoxContainer.new()
	root.add_child(fenster)
	var ok := Button.new()
	ok.text = "ok"
	fenster.add_child(ok)
	await _bilder(1)
	var freigeben: Callable = ui_theme.fokus_einsperren(fenster)
	mitte.disabled = false
	await _bilder(2)
	_check(mitte.focus_mode == Control.FOCUS_NONE, "hinter einem Fenster entsperrt » bleibt eingesperrt")
	freigeben.call()
	_check(mitte.focus_mode == Control.FOCUS_ALL and oben.focus_mode == Control.FOCUS_ALL,
		"Fenster zu » alle wieder fokussierbar")
	mitte.disabled = true
	freigeben = ui_theme.fokus_einsperren(fenster)
	freigeben.call()
	await _bilder(1)
	_check(mitte.focus_mode == Control.FOCUS_NONE, "gesperrt bleibt nach dem Fenster nicht fokussierbar")
	box.queue_free()
	fenster.queue_free()
	await _bilder(2)


func _test_taschen_fenster(gs: Node) -> void:
	print("Taschen voll ohne Gewöhnliche:")
	var taschen_voll = load("res://scripts/ui/taschen_voll.gd")  # untypisiert: nutzt Autoloads
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var liste: Array[ItemInstance] = []
	for i in gs.TASCHEN_LIMIT:
		liste.append(LootGenerator.roll_item_with_rarity(5, Enums.Rarity.MAGIC, rng))
	gs.inventory = liste
	gs.beute_warteliste.clear()
	gs.item_aufnehmen(LootGenerator.roll_item_with_rarity(5, Enums.Rarity.RARE, rng))
	var buehne := Control.new()
	root.add_child(buehne)
	var fenster: CanvasLayer = taschen_voll.pruefen(buehne, Callable())
	await _bilder(3)
	var verkaufen: Button = null
	var aufraeumen: Button = null
	for k in fenster.find_children("*", "Button", true, false):
		var knopf := k as Button
		if knopf.text.begins_with(Loc.pick("Gewöhnliche verkaufen", "Sell commons")):
			verkaufen = knopf
		elif knopf.text.begins_with(Loc.pick("Inventar aufräumen", "Tidy up inventory")):
			aufraeumen = knopf
	_check(verkaufen != null and verkaufen.disabled and verkaufen.focus_mode == Control.FOCUS_NONE,
		"„Gewöhnliche verkaufen (0 Teile)“ gesperrt und nicht fokussierbar")
	var fokus := root.get_viewport().gui_get_focus_owner()
	_check(fokus == aufraeumen, "Fokus startet auf „Inventar aufräumen“")
	_check(aufraeumen != null and aufraeumen.find_valid_focus_neighbor(SIDE_TOP) != verkaufen,
		"W von „Inventar aufräumen“ überspringt den gesperrten Knopf")
	taschen_voll._schliessen(fenster)
	gs.beute_warteliste.clear()
	gs.inventory = [] as Array[ItemInstance]
	buehne.queue_free()
	await _bilder(2)


# --- Icons --------------------------------------------------------------------------

func _test_meldung_icons() -> void:
	print("Icons in der Dungeon-Meldung:")
	var hud: Control = load("res://scripts/ui/dungeon_hud.gd").new()  # untypisiert: nutzt Autoloads
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(hud)
	await _bilder(1)
	var material: StringName = MaterialLibrary.MATERIALS.keys()[0]
	hud.meldung_zeigen("Seltene Truhe: +40 Gold!  Schwert!  +1 Mini-Medaille!", [{"symbol": &"gold"},
		{"base": ItemLibrary.get_base(&"schwert")}, {"symbol": &"medaille"}, {"material": material}])
	_check(hud.meldung_icons() == 4, "vier Icons über der Meldung")
	var bilder: Array = []
	for k in hud.find_children("*", "TextureRect", true, false):
		if (k as TextureRect).custom_minimum_size.x == hud.MELDUNG_ICON:
			bilder.append(k)
	_check(bilder.size() == 4 and bilder.all(func(b: TextureRect) -> bool: return b.texture == null),
		"Texturen noch leer beim Zeigen (verzögert, kein Ruckeln)")
	await _bilder(2)
	_check(bilder.all(func(b: TextureRect) -> bool: return is_instance_valid(b) and b.texture != null),
		"Texturen im nächsten Bild gesetzt")
	hud.meldung_zeigen("Text ohne Icons")
	_check(hud.meldung_icons() == 0, "Meldung ohne Icons zeigt keine Icon-Zeile")
	hud.meldung_zeigen("Tresor", [{"symbol": &"gold"}])
	hud.meldung_zeigen("")
	_check(hud.meldung_icons() == 0, "leere Meldung räumt die Icons ab")
	hud.queue_free()
	await _bilder(2)


func _test_schmiede_icons(gs: Node) -> void:
	print("Icons in der Neu-würfeln-Liste:")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var liste: Array[ItemInstance] = []
	for r in [Enums.Rarity.MAGIC, Enums.Rarity.RARE, Enums.Rarity.EPIC, Enums.Rarity.COMMON]:
		liste.append(LootGenerator.roll_item_with_rarity(10, r, rng))
	gs.inventory = liste
	var schmiede: Node = load("res://scenes/hub/smith.tscn").instantiate()
	root.add_child(schmiede)
	await _bilder(2)
	schmiede._kategorie = schmiede.NEU_WUERFELN
	schmiede._refresh()
	await _bilder(3)
	var auswahl: OptionButton = null
	for k in schmiede.find_children("*", "OptionButton", true, false):
		if not k.is_queued_for_deletion():
			auswahl = k
	_check(auswahl != null and auswahl.item_count == 3, "Auswahl mit den drei Items mit Affixen")
	var mit_icon := 0
	if auswahl != null:
		for i in auswahl.item_count:
			if auswahl.get_item_icon(i) != null:
				mit_icon += 1
	_check(auswahl != null and mit_icon == auswahl.item_count, "jeder Eintrag mit Item-Icon (%d)" % mit_icon)
	_check(auswahl != null and auswahl.get_theme_constant("icon_max_width") == schmiede.REROLL_ICON,
		"Icon auf Zeilengröße begrenzt")
	schmiede.queue_free()
	gs.inventory = [] as Array[ItemInstance]
	await _bilder(2)


func _test_quelltext() -> void:
	print("Truhen-, Tresor- und Risiko-Meldungen geben Icons mit:")
	var quelle := FileAccess.get_file_as_string("res://scripts/dungeon/dungeon_scene.gd")
	_check(quelle.contains("_show_message(message, icons)"), "normale Truhe")
	_check(quelle.contains("_show_message(DungeonGenerator.risiko_truhe_meldung(gold, item), ["), "Risiko-Truhe")
	_check(quelle.contains("[{\"base\": item.base}, {\"symbol\": &\"gold\"}, {\"symbol\": &\"medaille\"}]"),
		"Tresor")
