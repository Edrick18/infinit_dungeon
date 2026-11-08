extends SceneTree
## Headless-Selbsttest „Begehbare Stadt“ (Paket 6a): die Stadt-Szene lädt,
## drei Gebäude und der Ausgang stehen auf dem Platz, Türpunkte sind
## begehbar, Wände und Brunnen blockieren, WASD läuft und gleitet an Wänden
## entlang, das Schild erscheint nur vor einer Tür, E vor einem Gebäude
## öffnet die richtige Szene, deren Zurück führt wieder in die Stadt — der
## Held steht dann vor genau dieser Tür. Kein Knopf der Stadt nimmt den
## Tastatur-Fokus (WASD muss laufen, nicht Fokus wandern); die alten
## Stadt-Reiter zwischen den drei Menüs sind weg; der Hub-Knopf führt in
## die Stadt.
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/stadt_selftest.gd
##
## Szenen greifen auf Autoloads zu: erst nach dem ersten Bild per load()
## laden. Speichern ist gesperrt, Wegwerf-Slot 99.

const STADT := "res://scenes/hub/stadt.tscn"
const ZIELE := {
	&"taverne": "res://scenes/hub/tavern.tscn",
	&"haendler": "res://scenes/hub/shop_scene.tscn",
	&"schmiede": "res://scenes/hub/smith.tscn",
}

var failures := 0


func _initialize() -> void:
	await process_frame
	var waechter := FehlerWaechter.anmelden()
	var gs: Node = root.get_node_or_null(^"GameState")
	_check(gs != null, "GameState-Autoload vorhanden")
	if gs != null:
		gs.slot_gesperrt = true
		SaveManager.active_slot = 99
		for hinweis in ["menu", "schmiede", "haendler", "taverne", "inventar"]:
			gs.first_time(hinweis)
		if gs.party.is_empty():
			gs.recruit("Probe", load("res://scripts/data/hero_library.gd").STARTER_LOADOUTS.keys()[0])
		_test_geometrie()
		await _test_szene()
		await _test_rundgang()
		_test_quelltext()
	failures += waechter.fehler_melden()
	if failures == 0:
		print("SELFTEST OK — alle Stadt-Tests bestanden")
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


## Platz-Logik ohne Szene: Türen frei und erreichbar, Gebäude/Brunnen fest.
func _test_geometrie() -> void:
	print("Platz: Türen, Kollision:")
	var stadt_skript = load("res://scripts/ui/stadt_scene.gd")
	var kulisse_skript = load("res://scripts/stil3d/stadt_kulisse.gd")
	var orte: Dictionary = kulisse_skript.ORTE
	_check(orte.has(&"taverne") and orte.has(&"haendler") and orte.has(&"schmiede") and orte.has(&"ausgang"),
		"drei Gebäude und der Ausgang")
	for id in orte:
		var tuer: Vector2 = kulisse_skript.tuer(id)
		_check(stadt_skript.frei(tuer), "Türpunkt %s ist begehbar %s" % [id, tuer])
		if orte[id]["fest"]:
			_check(not stadt_skript.frei(orte[id]["pos"]), "%s: Mitte des Gebäudes blockiert" % id)
		for anderer in orte:
			if anderer != id:
				_check(tuer.distance_to(kulisse_skript.tuer(anderer)) > 2.0 * stadt_skript.NAH,
					"Schilder von %s und %s überlappen nicht" % [id, anderer])
	_check(not stadt_skript.frei(kulisse_skript.BRUNNEN), "Brunnen blockiert")
	_check(not stadt_skript.frei(Vector2(0, stadt_skript.LAUF_RADIUS + 0.2)), "Platzrand blockiert")


func _test_szene() -> void:
	print("Stadt-Szene:")
	var stadt: Node = load(STADT).instantiate()
	root.add_child(stadt)
	await _bilder(3)
	var kulisse: Node = stadt._kulisse
	_check(kulisse != null and kulisse.get_parent() == stadt, "Kulisse hängt in der Szene")
	var gebaeude := 0
	for id in [&"taverne", &"haendler", &"schmiede"]:
		var knoten: Node = kulisse.find_child(String(id), true, false)
		if knoten != null and knoten.get_child_count() > 10:
			gebaeude += 1
	_check(gebaeude == 3, "drei Gebäude gebaut (%d)" % gebaeude)
	_check(kulisse._held != null and kulisse._held.is_inside_tree(), "Held steht auf dem Platz")
	_check(stadt.held_pos.distance_to(kulisse.tuer(&"ausgang")) < 0.01,
		"vom Hub kommend: Start am Ausgang")
	_check(stadt._nah == &"ausgang" and stadt._schild.visible, "Schild „Ausgang“ sichtbar")

	var fokus_knoepfe := 0
	for k in stadt.find_children("*", "BaseButton", true, false):
		if (k as BaseButton).focus_mode != Control.FOCUS_NONE:
			fokus_knoepfe += 1
	_check(fokus_knoepfe == 0, "kein Stadt-Knopf nimmt den Tastatur-Fokus (%d)" % fokus_knoepfe)
	var fokus_autoload := root.get_node_or_null(^"Fokus")
	_check(fokus_autoload == null or fokus_autoload.bester_knopf(stadt) == null,
		"Fokus-Netz findet nichts zum Greifen — WASD bleibt beim Laufen")

	# WASD: W läuft nach Norden (−z), das Schild verschwindet abseits der Türen.
	var start: Vector2 = stadt.held_pos
	for i in 30:
		stadt.laufen(Vector2(0, -1), 1.0 / 60.0)
	_check(stadt.held_pos.y < start.y - 1.0 and absf(stadt.held_pos.x - start.x) < 0.001,
		"W läuft nach oben im Bild (%s → %s)" % [start, stadt.held_pos])
	_check(stadt._nah.is_empty() and not stadt._schild.visible, "abseits der Türen kein Schild")
	await _bilder(2)
	_check(kulisse._held.position.distance_to(Vector3(stadt.held_pos.x, 0, stadt.held_pos.y)) < 0.2,
		"Figur folgt der Position")
	# Gegen den Brunnen: schräg laufen gleitet an ihm entlang statt zu stecken.
	stadt.held_pos = Vector2(0.3, 3.0)
	for i in 120:
		stadt.laufen(Vector2(0.4, -1), 1.0 / 60.0)
	_check(stadt.frei(stadt.held_pos), "Held steht nie im Brunnen")
	_check(stadt.held_pos.y < 1.4, "gleitet am Brunnen vorbei (%s)" % stadt.held_pos)
	# Klick-Ziel: Klick aufs Gebäude führt vor dessen Tür.
	_check(stadt._klick_ziel_fuer(kulisse.ORTE[&"schmiede"]["pos"]) == kulisse.tuer(&"schmiede"),
		"Klick aufs Gebäude zielt auf seine Tür")
	stadt.queue_free()
	await _bilder(2)


## Stadt → Gebäude (E) → Zurück → Stadt, Held vor derselben Tür.
func _test_rundgang() -> void:
	print("Rundgang: E öffnet das Menü, Zurück führt vor dieselbe Tür:")
	change_scene_to_file(STADT)
	await _bilder(4)
	for id in ZIELE:
		var stadt: Node = current_scene
		_check(stadt != null and stadt.scene_file_path == STADT, "%s: in der Stadt" % id)
		if stadt == null or stadt.scene_file_path != STADT:
			return
		stadt.held_pos = stadt._kulisse.tuer(id)
		stadt.laufen(Vector2.ZERO, 0.016)
		_check(stadt._nah == id and stadt._schild.visible, "%s: Schild vor der Tür" % id)
		_check(stadt._schild.text.begins_with(stadt.ort_name(id)), "%s: Schild nennt den Ort (%s)"
			% [id, stadt._schild.text.replace("\n", " | ")])
		var e := InputEventAction.new()
		e.action = &"interact"
		e.pressed = true
		stadt._unhandled_input(e)
		await _bilder(4)
		var menue: Node = current_scene
		_check(menue != null and menue.scene_file_path == ZIELE[id], "%s: E öffnet %s" % [id, ZIELE[id].get_file()])
		if menue == null or menue.scene_file_path != ZIELE[id]:
			return
		var zurueck: Button = null
		var reiter := 0
		for k in menue.find_children("*", "Button", true, false):
			var text := (k as Button).text
			if text.begins_with("‹ "):
				zurueck = k
			if text in [Loc.pick("Taverne", "Tavern"), Loc.pick("Händler & Alchemist", "Merchant & alchemist"),
					Loc.pick("Schmiede", "Smithy")]:
				reiter += 1
		_check(reiter == 0, "%s: keine Stadt-Reiter mehr" % id)
		_check(zurueck != null and zurueck.text == "‹ " + Loc.pick("Stadt", "Town"), "%s: Zurück heißt „Stadt“" % id)
		if zurueck == null:
			return
		zurueck.pressed.emit()
		await _bilder(4)
		var wieder: Node = current_scene
		_check(wieder != null and wieder.scene_file_path == STADT, "%s: Zurück führt in die Stadt" % id)
		if wieder == null or wieder.scene_file_path != STADT:
			return
		_check(wieder.held_pos.distance_to(wieder._kulisse.tuer(id)) < 0.01 and wieder._nah == id,
			"%s: Held steht vor der Tür, aus der er kam" % id)
	# Esc in einem Menü führt ebenfalls in die Stadt (EscWaechter = Zurück).
	current_scene.held_pos = current_scene._kulisse.tuer(&"taverne")
	current_scene._betreten(&"taverne")
	await _bilder(4)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	await _bilder(4)
	_check(current_scene != null and current_scene.scene_file_path == STADT
		and current_scene._nah == &"taverne", "Esc in der Taverne: zurück vor die Taverne")
	_check(load("res://scripts/ui/stadt_scene.gd").herkunft == &"", "Herkunft nach dem Betreten wieder leer")


## Quelltext: Stadt-Reiter entfernt, Hub-Knopf führt in die Stadt.
func _test_quelltext() -> void:
	print("Quelltext:")
	var ui_theme := FileAccess.get_file_as_string("res://scripts/ui/ui_theme.gd")
	_check(not ui_theme.contains("func town_tabs"), "UiTheme.town_tabs entfernt")
	for pfad in ["res://scripts/ui/tavern_scene.gd", "res://scripts/ui/shop_scene.gd", "res://scripts/ui/smith_scene.gd"]:
		var text := FileAccess.get_file_as_string(pfad)
		_check(not text.contains("town_tabs") and text.contains("StadtSzene.zurueck("),
			"%s: ohne Reiter, Zurück in die Stadt" % pfad.get_file())
	var menue := FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd")
	_check(menue.contains("stadt_text(GameState.abholbar_anzahl()), StadtSzene.STADT_SCENE)"),
		"Hub-Knopf „Stadt“ führt in die begehbare Stadt")
