extends SceneTree
## Headless-Selbsttest Titelbildschirm (Feedback: „direkt ins Spiel
## reingeworfen, kein Hauptmenü im klassischen Sinne“):
##  • Startszene ist der Titelbildschirm, der Export schließt ihn nicht aus.
##  • Ohne Helden: kein Fortsetzen/Co-op, „Neues Spiel“ führt in den Hub zur
##    Heldenerstellung; mit Helden: Fortsetzen zuerst und fokussiert,
##    „Neues Spiel“ führt zu den Spielständen (nichts wird ersetzt).
##  • Spielstände und Optionen kehren zum Titel zurück, wenn sie von dort
##    geöffnet wurden, sonst in den Hub; Laden führt immer in den Hub.
##  • Hub: Ecken-Leiste nur noch Speichern + Hauptmenü (auch in der
##    Heldenerstellung der Weg zurück).
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/titel_selftest.gd
##
## Szenen hängen an Autoloads: erst nach dem ersten Bild per load() laden.
## Speichern ist gesperrt (Wegwerf-Slot 99), alles im Speicher.

const TITEL := "res://scenes/title.tscn"
const HUB := "res://scenes/main.tscn"
const TAVERNE := "res://scenes/hub/tavern.tscn"
const STADT := "res://scenes/hub/stadt.tscn"
const SPIELSTAENDE := "res://scenes/hub/saves.tscn"

var failures := 0


func _initialize() -> void:
	await process_frame
	var gs: Node = root.get_node_or_null(^"GameState")
	_check(gs != null, "GameState-Autoload vorhanden")
	if gs == null:
		_ende()
		return
	gs.slot_gesperrt = true
	SaveManager.active_slot = 99
	for hinweis in ["menu"]:
		gs.first_time(hinweis)
	gs.lade_hinweis = {}
	var waechter := FehlerWaechter.anmelden()
	_test_projekt()
	gs.reset_to_new_game()
	gs.slot_gesperrt = true
	await _test_ohne_helden(gs)
	gs.recruit("Probe", HeroLibrary.STARTER_LOADOUTS.keys()[0])
	await _test_mit_helden(gs)
	await _test_rueckkehr(gs)
	await _test_hub_ecke(gs)
	failures += waechter.fehler_melden()
	_ende()


func _ende() -> void:
	if failures == 0:
		print("SELFTEST OK — alle Titelbildschirm-Tests bestanden")
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


func _knopf_texte(szene: Node) -> Array[String]:
	var texte: Array[String] = []
	for b in szene.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree():
			texte.append((b as Button).text)
	return texte


func _test_projekt() -> void:
	print("Projekt und Export:")
	_check(ProjectSettings.get_setting("application/run/main_scene") == TITEL,
		"Startszene ist der Titelbildschirm")
	_check(ResourceLoader.exists(TITEL), "title.tscn vorhanden")
	var cfg := ConfigFile.new()
	_check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg lesbar")
	var filter := String(cfg.get_value("preset.0", "exclude_filter", ""))
	var ausgeschlossen := false
	for muster in filter.split(",", false):
		muster = muster.strip_edges()
		for pfad in ["scenes/title.tscn", "scripts/ui/title_scene.gd"]:
			if pfad.match(muster):
				ausgeschlossen = true
	_check(not ausgeschlossen, "Titelbildschirm nicht im Export-Ausschluss (%s)" % filter)


func _test_ohne_helden(gs: Node) -> void:
	print("Titel ohne Helden (frischer Slot):")
	var titel: Node = load(TITEL).instantiate()
	root.add_child(titel)
	await _bilder(3)
	var texte := _knopf_texte(titel)
	_check(not Loc.pick("Fortsetzen", "Continue") in texte, "kein Fortsetzen %s" % [texte])
	_check(not Loc.pick("Co-op", "Co-op") in texte, "kein Co-op ohne Party")
	_check(texte.size() == 4 and texte[0] == Loc.pick("Neues Spiel", "New game"),
		"Neues Spiel, Spielstände, Optionen, Beenden %s" % [texte])
	# slot_gesperrt nur für die reine Abfrage lösen (schreibt nichts).
	gs.slot_gesperrt = false
	_check(titel.neues_spiel_ziel() == HUB, "Neues Spiel führt über das Hub zur Heldenerstellung")
	gs.slot_gesperrt = true  # unlesbarer Slot: leer, aber nicht überschreiben
	_check(titel.neues_spiel_ziel() == SPIELSTAENDE, "unlesbarer Slot: Neues Spiel führt zu den Spielständen")
	var fokus := titel.get_viewport().gui_get_focus_owner()
	_check(fokus is Button and (fokus as Button).text == texte[0], "Fokus auf dem ersten Knopf")
	titel.queue_free()
	await _bilder(2)
	# Ohne Helden leitet das Hub in die Taverne (erster Held), Zurück = Titel.
	change_scene_to_file(HUB)
	await _bilder(5)
	var taverne: Node = current_scene
	_check(taverne != null and taverne.scene_file_path == TAVERNE, "ohne Helden: das Hub leitet in die Taverne")
	if taverne != null:
		texte = _knopf_texte(taverne)
		_check(texte.has("‹ " + Loc.pick("Hauptmenü", "Main menu")), "Taverne ohne Helden: Zurück zum Hauptmenü %s" % [texte.slice(0, 2)])
		_check(taverne._msg_label.text.begins_with(Loc.pick("Erstelle deinen ersten Helden", "Create your first hero")),
			"Taverne ohne Helden: Hinweis auf den ersten Helden")
	unload_current_scene()
	await _bilder(2)


func _test_mit_helden(gs: Node) -> void:
	print("Titel mit Helden:")
	var titel: Node = load(TITEL).instantiate()
	root.add_child(titel)
	await _bilder(3)
	var texte := _knopf_texte(titel)
	_check(texte == [Loc.pick("Fortsetzen", "Continue"), Loc.pick("Neues Spiel", "New game"),
		Loc.pick("Spielstände", "Save games"), Loc.pick("Co-op", "Co-op"),
		Loc.pick("Optionen", "Options"), Loc.pick("Beenden", "Quit")], "Knopf-Reihenfolge %s" % [texte])
	var fokus := titel.get_viewport().gui_get_focus_owner()
	_check(fokus is Button and (fokus as Button).text == Loc.pick("Fortsetzen", "Continue"),
		"Fokus auf Fortsetzen")
	_check(titel.neues_spiel_ziel() == SPIELSTAENDE,
		"Neues Spiel mit bestehendem Spiel führt zu den Spielständen")
	_check(not gs.party.is_empty() and titel.hat_spielstand(), "Spielstand erkannt")
	titel.queue_free()
	await _bilder(2)


func _test_rueckkehr(gs: Node) -> void:
	print("Rückkehr von Spielständen und Optionen:")
	for pfad in [SPIELSTAENDE, "res://scenes/hub/options.tscn"]:
		gs.ui_return_scene = TITEL
		var szene: Node = load(pfad).instantiate()
		root.add_child(szene)
		await _bilder(3)
		var texte := _knopf_texte(szene)
		_check(texte.any(func(t: String) -> bool: return t.contains(Loc.pick("Hauptmenü", "Main menu"))),
			"%s: Zurück heißt Hauptmenü %s" % [pfad.get_file(), texte.slice(0, 3)])
		szene.queue_free()
		await _bilder(2)
		gs.ui_return_scene = ""
		szene = load(pfad).instantiate()
		root.add_child(szene)
		await _bilder(3)
		texte = _knopf_texte(szene)
		_check(not texte.any(func(t: String) -> bool: return t.contains(Loc.pick("Hauptmenü", "Main menu"))),
			"%s: aus dem Hub geöffnet ohne Titel-Ziel" % pfad.get_file())
		szene.queue_free()
		await _bilder(2)


func _test_hub_ecke(_gs: Node) -> void:
	print("Stadt als Hub, Stadt-Menü (Esc):")
	change_scene_to_file(HUB)
	await _bilder(5)
	var stadt: Node = current_scene
	_check(stadt != null and stadt.scene_file_path == STADT, "mit Helden: das Hub leitet in die Stadt")
	if stadt == null or stadt.scene_file_path != STADT:
		return
	stadt.stadt_menue_zeigen()
	await _bilder(2)
	var texte := _knopf_texte(stadt._fenster)
	_check(" | ".join(texte.slice(0, 3)) == " | ".join([Loc.pick("Lexikon", "Encyclopedia"), Loc.pick("Speichern", "Save"),
		Loc.pick("Hauptmenü", "Main menu")]), "Stadt-Menü: Lexikon, Speichern, Hauptmenü %s" % [texte])
	for weg in [Loc.pick("Co-op", "Co-op"), Loc.pick("Spielstände", "Save games"),
			Loc.pick("Optionen", "Options"), Loc.pick("Beenden", "Quit")]:
		_check(not weg in texte, "„%s“ nicht im Stadt-Menü" % weg)
	var fokus := stadt.get_viewport().gui_get_focus_owner()
	_check(fokus is Button and (fokus as Button).text == Loc.pick("Lexikon", "Encyclopedia"),
		"Fokus im Stadt-Menü auf dem ersten Knopf")
	unload_current_scene()
	await _bilder(2)
