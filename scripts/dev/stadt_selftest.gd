extends SceneTree
## Headless-Selbsttest „Begehbare Stadt“ (Paket 6a, Stufe b 2026-11-09):
## Die Stadt ist das Hub. Die Szene lädt; Taverne, Händler, Schmiede, Portal
## und Lagerfeuer stehen auf dem Platz, Türpunkte sind begehbar, Gebäude,
## Feuer und Brunnen blockieren, WASD läuft und gleitet an Wänden entlang,
## das Schild erscheint nur vor einem Ort. E vor einem Gebäude öffnet sein
## Menü, Zurück führt vor dieselbe Tür. Das Portal öffnet das Kartenlager
## (mit laufendem Dungeon erst die Wahl „fortsetzen“), das Lagerfeuer die
## Wahl Werkstatt/Ausrüstung; zurück steht der Held wieder dort. Esc öffnet
## das Stadt-Menü (hält den Helden an); das Lexikon kehrt an dieselbe
## Stelle zurück. Das alte Hub ist eine Weiche (Taverne/Gast-Ansicht/Stadt).
## Kein Knopf des Platzes nimmt den Tastatur-Fokus.
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/stadt_selftest.gd
##
## Szenen greifen auf Autoloads zu: erst nach dem ersten Bild per load()
## laden. Speichern ist gesperrt, Wegwerf-Slot 99.

const STADT := "res://scenes/hub/stadt.tscn"
const HUB := "res://scenes/main.tscn"
const ZIELE := {
	&"taverne": "res://scenes/hub/tavern.tscn",
	&"haendler": "res://scenes/hub/shop_scene.tscn",
	&"schmiede": "res://scenes/hub/smith.tscn",
}
const KARTENLAGER := "res://scenes/hub/card_storage.tscn"
const WERKSTATT := "res://scenes/workshop/skill_workshop.tscn"
const INVENTAR := "res://scenes/inventory/inventory_scene.tscn"
const LEXIKON := "res://scenes/hub/lexicon.tscn"

var failures := 0


func _initialize() -> void:
	await process_frame
	var waechter := FehlerWaechter.anmelden()
	var gs: Node = root.get_node_or_null(^"GameState")
	_check(gs != null, "GameState-Autoload vorhanden")
	if gs != null:
		gs.slot_gesperrt = true
		SaveManager.active_slot = 99
		for hinweis in ["menu", "schmiede", "haendler", "taverne", "inventar", "werkstatt", "lexikon", "kartenlager"]:
			gs.first_time(hinweis)
		gs.lade_hinweis = {}
		if gs.party.is_empty():
			gs.recruit("Probe", load("res://scripts/data/hero_library.gd").STARTER_LOADOUTS.keys()[0])
		_test_geometrie()
		_test_weiche()
		await _test_szene()
		await _test_rundgang()
		await _test_portal(gs)
		await _test_lagerfeuer()
		await _test_stadt_menue()
		await _test_mitspieler()
		await _test_kopf_tafel()
		await _test_hinweis_haelt_an()
		_test_quelltext()
		gs.clear_run()
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


func _taste_e() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = &"interact"
	e.pressed = true
	return e


func _knopf(wurzel: Node, text: String) -> Button:
	for k in wurzel.find_children("*", "Button", true, false):
		if (k as Button).text.begins_with(text) and (k as Button).is_visible_in_tree():
			return k
	return null


## Held vor einen Ort stellen und E drücken.
func _vor_ort_e(stadt: Node, id: StringName) -> void:
	stadt.held_pos = stadt._kulisse.tuer(id)
	stadt.laufen(Vector2.ZERO, 0.016)
	stadt._unhandled_input(_taste_e())


## Platz-Logik ohne Szene: Türen frei und erreichbar, Orte/Brunnen fest.
func _test_geometrie() -> void:
	print("Platz: Orte, Türen, Kollision:")
	var stadt_skript = load("res://scripts/ui/stadt_scene.gd")
	var kulisse_skript = load("res://scripts/stil3d/stadt_kulisse.gd")
	var orte: Dictionary = kulisse_skript.ORTE
	_check(orte.size() == 5 and orte.has(&"taverne") and orte.has(&"haendler") and orte.has(&"schmiede")
		and orte.has(&"portal") and orte.has(&"lagerfeuer"), "drei Gebäude, Portal und Lagerfeuer %s" % [orte.keys()])
	for id in orte:
		var tuer: Vector2 = kulisse_skript.tuer(id)
		_check(stadt_skript.frei(tuer), "Türpunkt %s ist begehbar %s" % [id, tuer])
		if orte[id]["fest"]:
			_check(not stadt_skript.frei(orte[id]["pos"]), "%s: Mitte blockiert" % id)
		for anderer in orte:
			if anderer != id:
				_check(tuer.distance_to(kulisse_skript.tuer(anderer)) > 2.0 * stadt_skript.NAH,
					"Schilder von %s und %s überlappen nicht" % [id, anderer])
	_check(not stadt_skript.frei(kulisse_skript.BRUNNEN), "Brunnen blockiert")
	_check(not stadt_skript.frei(Vector2(0, stadt_skript.LAUF_RADIUS + 0.2)), "Platzrand blockiert")
	# Die Kamera schaut von Süden: das Portal steht nördlich seiner Tür, nicht davor.
	_check((orte[&"portal"]["pos"] as Vector2).y < kulisse_skript.tuer(&"portal").y,
		"Portal steht hinter seiner Tür (verdeckt den Helden nicht)")


## Das alte Hub leitet weiter: ohne Helden Taverne, sonst Stadt (auch Gäste).
func _test_weiche() -> void:
	print("Weiche im alten Hub:")
	var menue = load("res://scripts/ui/main_menu.gd")
	_check(menue.weiche_ziel(true, false) == ZIELE[&"taverne"], "ohne Helden » Taverne")
	_check(menue.weiche_ziel(true, true) == ZIELE[&"taverne"], "ohne Helden (auch als Gast) » Taverne")
	_check(menue.weiche_ziel(false, true) == STADT, "Co-op-Gast » Stadt (gemeinsamer Platz)")
	_check(menue.weiche_ziel(false, false) == STADT, "sonst » Stadt")


func _test_szene() -> void:
	print("Stadt-Szene:")
	var stadt: Node = load(STADT).instantiate()
	root.add_child(stadt)
	await _bilder(3)
	var kulisse: Node = stadt._kulisse
	_check(kulisse != null and kulisse.get_parent() == stadt, "Kulisse hängt in der Szene")
	var gebaut := 0
	for id in [&"taverne", &"haendler", &"schmiede", &"portal", &"lagerfeuer"]:
		var knoten: Node = kulisse.find_child(String(id), true, false)
		if knoten != null and knoten.get_child_count() > 6:
			gebaut += 1
	_check(gebaut == 5, "fünf Orte gebaut (%d)" % gebaut)
	_check(kulisse._held != null and kulisse._held.is_inside_tree(), "Held steht auf dem Platz")
	_check(stadt.held_pos.distance_to(kulisse.tuer(&"portal")) < 0.01, "ohne Herkunft: Ankunft am Portal")
	_check(stadt._nah == &"portal" and stadt._schild.visible
		and stadt._schild.text.begins_with(stadt.ort_name(&"portal")), "Schild „Portal“ sichtbar")
	_check(stadt._info.text.contains("Gold"), "Stand unter dem Titel (%s)" % stadt._info.text)

	var fokus_knoepfe := 0
	for k in stadt.find_children("*", "BaseButton", true, false):
		if (k as BaseButton).focus_mode != Control.FOCUS_NONE:
			fokus_knoepfe += 1
	_check(fokus_knoepfe == 0, "kein Stadt-Knopf nimmt den Tastatur-Fokus (%d)" % fokus_knoepfe)
	var fokus_autoload := root.get_node_or_null(^"Fokus")
	_check(fokus_autoload == null or fokus_autoload.bester_knopf(stadt) == null,
		"Fokus-Netz findet nichts zum Greifen — WASD bleibt beim Laufen")

	# WASD: S läuft nach Süden (+z), das Schild verschwindet abseits der Türen.
	stadt.held_pos = Vector2(-1.5, 2.8)
	var start: Vector2 = stadt.held_pos
	for i in 30:
		stadt.laufen(Vector2(0, 1), 1.0 / 60.0)
	_check(stadt.held_pos.y > start.y + 1.0 and absf(stadt.held_pos.x - start.x) < 0.001,
		"S läuft nach unten im Bild (%s → %s)" % [start, stadt.held_pos])
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
	_check(stadt._klick_ziel_fuer(kulisse.ORTE[&"schmiede"]["pos"]) == kulisse.tuer(&"schmiede"),
		"Klick aufs Gebäude zielt auf seine Tür")
	_check(stadt._klick_ziel_fuer(kulisse.ORTE[&"lagerfeuer"]["pos"]) == kulisse.tuer(&"lagerfeuer"),
		"Klick aufs Lagerfeuer zielt davor")
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
		stadt._unhandled_input(_taste_e())
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


## Portal: ohne Dungeon direkt ins Kartenlager, mit Dungeon erst die Wahl.
func _test_portal(gs: Node) -> void:
	print("Portal:")
	gs.clear_run()
	change_scene_to_file(STADT)
	await _bilder(4)
	_vor_ort_e(current_scene, &"portal")
	await _bilder(4)
	_check(current_scene != null and current_scene.scene_file_path == KARTENLAGER, "ohne Dungeon: E öffnet das Kartenlager")
	if current_scene == null or current_scene.scene_file_path != KARTENLAGER:
		return
	var zurueck := _knopf(current_scene, "‹ ")
	_check(zurueck != null and zurueck.text == "‹ " + Loc.pick("Stadt", "Town"), "Kartenlager: Zurück heißt „Stadt“")
	if zurueck == null:
		return
	zurueck.pressed.emit()
	await _bilder(6)  # über das alte Hub (Weiche) in die Stadt
	var stadt: Node = current_scene
	_check(stadt != null and stadt.scene_file_path == STADT and stadt._nah == &"portal",
		"Kartenlager » Zurück: Held steht am Portal")
	if stadt == null or stadt.scene_file_path != STADT:
		return
	# Mit laufendem Dungeon: Wahl „fortsetzen“ oder Kartenlager.
	gs.start_run(CardFactory.make_starter_card())
	_vor_ort_e(stadt, &"portal")
	await _bilder(2)
	_check(stadt.fenster_offen(), "mit Dungeon: Wahlfenster statt Szenenwechsel")
	if not stadt.fenster_offen():
		return
	var fortsetzen := _knopf(stadt._fenster, Loc.pick("Dungeon fortsetzen", "Resume dungeon"))
	var lager := _knopf(stadt._fenster, Loc.pick("Kartenlager", "Map storage"))
	_check(fortsetzen != null and lager != null and _knopf(stadt._fenster, Loc.pick("Zurück", "Back")) != null,
		"Wahl: Dungeon fortsetzen, Kartenlager, Zurück")
	_check(stadt.get_viewport().gui_get_focus_owner() == fortsetzen, "Fokus auf „Dungeon fortsetzen“")
	# Fenster hält den Helden an und schluckt E.
	var vorher: Vector2 = stadt.held_pos
	stadt._process(0.5)
	stadt._unhandled_input(_taste_e())
	_check(stadt.held_pos == vorher and stadt.fenster_offen(), "offenes Fenster: Held steht, E am Platz wirkt nicht")
	stadt._esc()
	await _bilder(1)
	_check(not stadt.fenster_offen(), "Esc schließt das Wahlfenster")
	_vor_ort_e(stadt, &"portal")
	await _bilder(2)
	_knopf(stadt._fenster, Loc.pick("Kartenlager", "Map storage")).pressed.emit()
	await _bilder(4)
	_check(current_scene != null and current_scene.scene_file_path == KARTENLAGER, "Wahl „Kartenlager“ öffnet es")
	gs.clear_run()


## Lagerfeuer: Wahl Werkstatt / Ausrüstung, zurück steht der Held am Feuer.
func _test_lagerfeuer() -> void:
	print("Lagerfeuer:")
	for paar in [[Loc.pick("Skill-Werkstatt", "Skill workshop"), WERKSTATT],
			[Loc.pick("Ausrüstung & Inventar", "Equipment & inventory"), INVENTAR]]:
		change_scene_to_file(STADT)
		await _bilder(4)
		var stadt: Node = current_scene
		_vor_ort_e(stadt, &"lagerfeuer")
		await _bilder(2)
		_check(stadt.fenster_offen(), "E am Lagerfeuer: Wahlfenster")
		if not stadt.fenster_offen():
			return
		_check(_held_frei(stadt), "Wahlfenster verdeckt den Helden nicht")
		var knopf := _knopf(stadt._fenster, paar[0])
		_check(knopf != null, "Wahl enthält „%s“" % paar[0])
		if knopf == null:
			return
		knopf.pressed.emit()
		await _bilder(4)
		_check(current_scene != null and current_scene.scene_file_path == paar[1], "„%s“ öffnet %s" % [paar[0], paar[1].get_file()])
		if current_scene == null or current_scene.scene_file_path != paar[1]:
			return
		var zurueck := _knopf(current_scene, "‹ ")
		_check(zurueck != null and zurueck.text == "‹ " + Loc.pick("Stadt", "Town"), "%s: Zurück heißt „Stadt“" % paar[1].get_file())
		if zurueck == null:
			return
		zurueck.pressed.emit()
		await _bilder(6)
		_check(current_scene != null and current_scene.scene_file_path == STADT and current_scene._nah == &"lagerfeuer",
			"%s » Zurück: Held steht am Lagerfeuer" % paar[1].get_file())


## Der Held (Kopf bis Füße auf dem Bildschirm) liegt außerhalb der Fenstertafel.
func _held_frei(stadt: Node) -> bool:
	var tafel: Control = null
	for kind in stadt._fenster.get_children():
		if kind is PanelContainer:
			tafel = kind
	if tafel == null:
		return false
	var rahmen: Rect2 = tafel.get_global_rect()
	var kulisse: Control = stadt._kulisse
	kulisse.springen(kulisse.held_pos, Vector2(0, 1))  # Kamera ohne Nachlauf
	var kamera: Camera3D = kulisse._kamera
	var vp: SubViewport = kulisse._vp
	var massstab := kulisse.size / Vector2(vp.size)
	var fuss := Vector3(kulisse.held_pos.x, 0.0, kulisse.held_pos.y)
	for hoehe in [0.0, 0.5, 1.0]:
		var punkt := kulisse.global_position + kamera.unproject_position(fuss + Vector3(0, hoehe, 0)) * massstab
		if rahmen.has_point(punkt):
			return false
	return true


## Kopfzeile: Titel und Stand auf einer Holztafel, Tafel endet vor dem Menü-Knopf.
func _test_kopf_tafel() -> void:
	print("Kopftafel:")
	change_scene_to_file(STADT)
	await _bilder(4)
	var stadt: Node = current_scene
	var tafel: PanelContainer = stadt._kopf_tafel
	_check(tafel != null and stadt._info.get_parent().get_parent() == tafel, "Stand liegt auf der Kopftafel")
	if tafel == null:
		return
	_check(tafel.size.x < stadt.get_viewport().get_visible_rect().size.x * 0.5,
		"Kopftafel nur so breit wie ihr Text (%d px)" % tafel.size.x)


## Co-op: Mitspieler auf dem Platz — Figur erscheint, gleitet, zeigt das
## Gebäude im Schild und verschwindet, wenn er den Platz verlässt.
func _test_mitspieler() -> void:
	print("Co-op: Mitspieler in der Stadt:")
	change_scene_to_file(STADT)
	await _bilder(4)
	var stadt: Node = current_scene
	var net: Node = root.get_node("Net")
	var px: float = net.STADT_PX
	net.remote_players["Mira"] = {"pos": Vector2(2.0, 3.0) * px, "floor": net.ORT_STADT, "tile": -1,
		"blick": 0.5, "aus": {}, "drin": ""}
	var kulisse: Node = stadt._kulisse
	kulisse.mitspieler_setzen(stadt.mitspieler_ziele(), 0.016)
	var pos: Dictionary = kulisse.mitspieler_positionen()
	_check(pos.has("Mira") and (pos["Mira"] as Vector2).is_equal_approx(Vector2(2.0, 3.0)),
		"Mitspieler erscheint an seiner Stelle (%s)" % [pos])
	net.remote_players["Mira"]["pos"] = Vector2(2.5, 3.0) * px
	kulisse.mitspieler_setzen(stadt.mitspieler_ziele(), 0.05)
	var x: float = (kulisse.mitspieler_positionen()["Mira"] as Vector2).x
	_check(x > 2.0 and x < 2.5, "er gleitet zum neuen Ziel statt zu springen (x = %.2f)" % x)
	net.remote_players["Mira"]["drin"] = "schmiede"
	kulisse.mitspieler_setzen(stadt.mitspieler_ziele(), 0.016)
	var schild: Label3D = kulisse._mitspieler["Mira"]["schild"]
	_check(schild.text == "Mira · " + stadt.ort_name(&"schmiede"), "Schild zeigt das Gebäude („%s“)" % schild.text)
	net.remote_players["Mira"]["floor"] = 0  # jetzt im Dungeon
	kulisse.mitspieler_setzen(stadt.mitspieler_ziele(), 0.016)
	_check(kulisse.mitspieler_positionen().is_empty(), "verlässt er den Platz, verschwindet die Figur")
	net.remote_players.clear()
	unload_current_scene()
	await _bilder(2)


## Stadt-Menü (Esc): hält an, Lexikon kehrt an dieselbe Stelle zurück.
func _test_stadt_menue() -> void:
	print("Stadt-Menü:")
	change_scene_to_file(STADT)
	await _bilder(4)
	var stadt: Node = current_scene
	stadt.held_pos = Vector2(1.5, 3.5)
	stadt.laufen(Vector2.ZERO, 0.016)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	await _bilder(2)
	_check(stadt.fenster_offen(), "Esc öffnet das Stadt-Menü")
	if not stadt.fenster_offen():
		return
	var texte: Array[String] = []
	for k in stadt._fenster.find_children("*", "Button", true, false):
		texte.append((k as Button).text)
	_check(" | ".join(texte) == " | ".join([Loc.pick("Lexikon", "Encyclopedia"), Loc.pick("Speichern", "Save"),
		Loc.pick("Hauptmenü", "Main menu"), Loc.pick("Zurück (Esc)", "Back (Esc)")]), "Knöpfe %s" % [texte])
	var speichern := _knopf(stadt._fenster, Loc.pick("Speichern", "Save"))
	speichern.pressed.emit()
	_check(speichern.text == Loc.pick("Fehler!", "Failed!") and stadt.fenster_offen(),
		"Speichern meldet sich im Knopf (gesperrter Test-Slot: Fehler), Fenster bleibt")
	root.push_input(esc)
	await _bilder(2)
	_check(not stadt.fenster_offen(), "Esc schließt das Stadt-Menü wieder")
	stadt.stadt_menue_zeigen()
	await _bilder(1)
	_knopf(stadt._fenster, Loc.pick("Lexikon", "Encyclopedia")).pressed.emit()
	await _bilder(4)
	_check(current_scene != null and current_scene.scene_file_path == LEXIKON, "Lexikon öffnet sich")
	if current_scene == null or current_scene.scene_file_path != LEXIKON:
		return
	var lex_zurueck := _knopf(current_scene, "‹ ")
	_check(lex_zurueck != null and lex_zurueck.text == "‹ " + Loc.pick("Stadt", "Town"), "Lexikon: Zurück heißt „Stadt“")
	lex_zurueck.pressed.emit()
	await _bilder(6)
	_check(current_scene != null and current_scene.scene_file_path == STADT
		and current_scene.held_pos.distance_to(Vector2(1.5, 3.5)) < 0.01, "zurück aus dem Lexikon: dieselbe Stelle")


## Ein Hinweis (Willkommen, Laden) hält den Helden an; Esc öffnet nichts darunter.
func _test_hinweis_haelt_an() -> void:
	print("Hinweis hält den Helden an:")
	change_scene_to_file(STADT)
	await _bilder(4)
	var stadt: Node = current_scene
	stadt.held_pos = Vector2(-1.5, 2.8)
	stadt.laufen(Vector2.ZERO, 0.016)
	load("res://scripts/ui/ui_theme.gd").show_hint(stadt, "Test", "Hinweis")
	await _bilder(2)
	_check(stadt.hinweis_offen() and stadt.fenster_offen(), "Hinweis zählt als offenes Fenster")
	var vorher: Vector2 = stadt.held_pos
	Input.action_press(&"move_down")
	stadt._process(0.5)
	Input.action_release(&"move_down")
	_check(stadt.held_pos == vorher, "WASD läuft nicht hinter dem Hinweis")
	stadt._esc()
	await _bilder(1)
	_check(not is_instance_valid(stadt._fenster), "Esc öffnet kein Stadt-Menü unter dem Hinweis")
	var ok := _knopf(stadt, "OK")
	_check(ok != null, "Hinweis hat einen OK-Knopf")
	if ok == null:
		return
	ok.pressed.emit()
	await _bilder(2)
	_check(not stadt.hinweis_offen(), "OK schließt den Hinweis")
	Input.action_press(&"move_down")
	stadt._process(0.5)
	Input.action_release(&"move_down")
	_check(stadt.held_pos.y > vorher.y, "danach läuft der Held wieder (%s → %s)" % [vorher, stadt.held_pos])


## Quelltext: Stadt-Reiter entfernt, Gast-Ansicht hat weiter den Stadt-Knopf.
func _test_quelltext() -> void:
	print("Quelltext:")
	var ui_theme := FileAccess.get_file_as_string("res://scripts/ui/ui_theme.gd")
	_check(not ui_theme.contains("func town_tabs"), "UiTheme.town_tabs entfernt")
	for pfad in ["res://scripts/ui/tavern_scene.gd", "res://scripts/ui/shop_scene.gd", "res://scripts/ui/smith_scene.gd"]:
		var text := FileAccess.get_file_as_string(pfad)
		_check(not text.contains("town_tabs") and text.contains("StadtSzene.zurueck("),
			"%s: ohne Reiter, Zurück in die Stadt" % pfad.get_file())
	var menue := FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd")
	_check(menue.contains("weiche_ziel") and not menue.contains("_build_hero_creation")
		and not menue.contains("_menu_button"), "altes Hub ist nur noch die Weiche (keine tote Gast-Ansicht)")
