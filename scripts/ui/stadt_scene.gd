class_name StadtSzene
extends Control
## Begehbare Stadt = das Hub (Paket 6a, Stufe b 2026-11-09): ein Stadtplatz
## im Stil des Lager-Dioramas. Der erste Held der Party läuft mit WASD (oder
## per Mausklick, wie ein Ziel im Dungeon); steht er vor einem Ort, zeigt ein
## schlichtes Namensschild, wo er ist — E (bzw. Klick aufs Schild) öffnet,
## was dahinter liegt:
##   Taverne, Händler, Schmiede — ihre Menüs;
##   Portal — das Kartenlager (läuft ein Dungeon: erst die Wahl „fortsetzen“);
##   Lagerfeuer — die Wahl Skill-Werkstatt oder Ausrüstung & Inventar.
## Esc öffnet das Stadt-Menü (Lexikon, Speichern, Hauptmenü). Zurück aus
## einem Menü steht der Held vor dem Ort, aus dem er kam (zurueck(), bzw.
## `herkunft` für Szenen, die über das alte Hub zurückkehren).
##
## Die Knöpfe des Platzes sind ohne Tastatur-Fokus: WASD läuft, statt einen
## Fokus zu wandern. Offene Fenster (Wahl, Stadt-Menü) halten den Helden an
## und sind mit WASD + E bedienbar.

const MAIN_SCENE := "res://scenes/main.tscn"
const STADT_SCENE := "res://scenes/hub/stadt.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const CARDS_SCENE := "res://scenes/hub/card_storage.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/dungeon_scene.tscn"
const WORKSHOP_SCENE := "res://scenes/workshop/skill_workshop.tscn"
const INVENTORY_SCENE := "res://scenes/inventory/inventory_scene.tscn"
const LEXICON_SCENE := "res://scenes/hub/lexicon.tscn"
## Gebäude mit eigenem Menü (Portal und Lagerfeuer bieten eine Wahl).
const ZIELE := {
	&"taverne": "res://scenes/hub/tavern.tscn",
	&"haendler": "res://scenes/hub/shop_scene.tscn",
	&"schmiede": "res://scenes/hub/smith.tscn",
}
const TEMPO := 3.6        ## Welt-Einheiten pro Sekunde
const HALB := 0.3         ## halbe Breite des Helden (Kollision)
const LAUF_RADIUS := 7.2  ## so weit vom Platzmittelpunkt darf er laufen
const NAH := 1.25         ## Abstand zum Türpunkt, ab dem das Schild erscheint

## Ort, aus dessen Menü man zurückkommt (leer = am Portal ankommen).
static var herkunft: StringName = &""
## Genaue Stelle für die Rückkehr aus dem Stadt-Menü (Lexikon) — oder null.
static var rueck_pos: Variant = null

var held_pos := Vector2.ZERO
var _nah: StringName = &""
var _klick_ziel: Variant = null  ## Vector2 oder null
var _kulisse: StadtKulisse
var _schild: Button
var _info: Label
var _verlassen_laeuft := false
## Offenes Fenster (Wahl oder Stadt-Menü) oder null — hält den Helden an.
var _fenster: Control = null
var _fenster_lage: CanvasLayer
var _fenster_freigeben: Callable


## Aus einem Stadt-Menü zurück auf den Platz, vor die Tür von `von`.
static func zurueck(baum: SceneTree, von: StringName) -> void:
	herkunft = von
	baum.change_scene_to_file(STADT_SCENE)


func _ready() -> void:
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Klicks auf den Platz kommen in _unhandled_input an
	Music.play(&"stadt")
	_kulisse = StadtKulisse.new()
	# Anker VOR dem Einhängen setzen (siehe UiTheme.make_background).
	_kulisse.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_kulisse.z_index = -1
	add_child(_kulisse)
	_oberflaeche_bauen()
	if rueck_pos is Vector2:
		_kulisse.springen(rueck_pos, Vector2(0, -1))
	elif StadtKulisse.ORTE.has(herkunft):
		_kulisse.springen(StadtKulisse.tuer(herkunft), StadtKulisse.front(herkunft))
	else:
		_kulisse.springen(StadtKulisse.tuer(&"portal"), StadtKulisse.front(&"portal"))
	herkunft = &""
	rueck_pos = null
	held_pos = _kulisse.held_pos
	_nah_pruefen()
	# Autosave: jeder Aufenthalt in der Stadt sichert den Fortschritt — nur
	# wenn sich etwas geändert hat (Start und Laden schreiben nichts).
	GameState.autosave()
	# Onboarding: der Spiel-Loop in einem Absatz (einmal pro Spielstand).
	if GameState.first_time("menu"):
		UiTheme.show_hint(self, Loc.pick("Willkommen in Infinit Dungeon!",
			"Welcome to Infinit Dungeon!"), Loc.pick(
			"Dein Loop: Am PORTAL eine Dungeon-Karte aus dem Kartenlager öffnen, drinnen kämpfen und looten, jede dritte Ebene ist eine Boss-Ebene. Nach jedem Boss gibt es eine Belohnungskarte und die Wahl: weiter hinab oder zurück in die Stadt — die Karten sind endlos tief.\n\nZwischendurch: In TAVERNE, beim HÄNDLER und in der SCHMIEDE Helden anheuern, einkaufen und schmieden, am LAGERFEUER Skills aus Bausteinen bauen und Ausrüstung anlegen. Esc öffnet das Stadt-Menü (Lexikon, Speichern, Hauptmenü).",
			"Your loop: at the PORTAL open a dungeon map from map storage, fight and loot inside, every third floor is a boss floor. After each boss you get a reward map and the choice: descend further or return to town — the maps are endlessly deep.\n\nIn between: recruit heroes at the TAVERN, shop at the MERCHANT and forge at the SMITHY, build skills from blocks and equip loot at the CAMPFIRE. Esc opens the town menu (encyclopedia, save, main menu)."))
	_lade_hinweis_zeigen()


## Meldung vom Laden (Sicherung geladen / Datei unlesbar), einmal anzeigen.
func _lade_hinweis_zeigen() -> void:
	var text := GameState.lade_hinweis_text()
	if text.is_empty():
		return
	GameState.lade_hinweis = {}
	UiTheme.show_hint(self, Loc.pick("Spielstand", "Save game"), text)


func _oberflaeche_bauen() -> void:
	var rand := MarginContainer.new()
	rand.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for seite in ["margin_left", "margin_top", "margin_right"]:
		rand.add_theme_constant_override(seite, Bildschirm.RAND)
	add_child(rand)
	var kopf := HBoxContainer.new()
	kopf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rand.add_child(kopf)
	var links := VBoxContainer.new()
	links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(links)
	var titel := Label.new()
	titel.text = Loc.pick("Stadt", "Town")
	titel.add_theme_font_size_override("font_size", Bildschirm.TITEL_GROESSE)
	Bildschirm._eingraviert(titel)
	links.add_child(titel)
	# Kurzer Stand unter dem Titel (früher im Hub-Menü).
	_info = Label.new()
	_info.text = stand_text()
	_info.add_theme_font_size_override("font_size", 13)
	_info.add_theme_color_override("font_color", Color(UiTheme.TEXT, 0.72))
	links.add_child(_info)
	var menue_knopf := Button.new()
	menue_knopf.text = Loc.pick("Menü (Esc)", "Menu (Esc)")
	menue_knopf.custom_minimum_size = Vector2(120, 38)
	menue_knopf.focus_mode = Control.FOCUS_NONE
	menue_knopf.set_meta(&"nicht_zuerst", true)
	menue_knopf.pressed.connect(stadt_menue_zeigen)
	kopf.add_child(menue_knopf)

	# Namensschild unten in der Mitte — nur sichtbar vor einem Ort.
	_schild = Button.new()
	_schild.focus_mode = Control.FOCUS_NONE
	_schild.custom_minimum_size = Vector2(280, 64)
	_schild.add_theme_font_size_override("font_size", 18)
	_schild.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_schild.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_schild.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_schild.offset_bottom = -Bildschirm.RAND * 2
	_schild.visible = false
	_schild.pressed.connect(func() -> void: _betreten(_nah))
	add_child(_schild)

	_fenster_lage = CanvasLayer.new()
	_fenster_lage.layer = 5
	add_child(_fenster_lage)

	var esc := Bildschirm.EscWaechter.new()
	esc.aktion = _esc
	add_child(esc)


## „Gold 120 · Karten 3/25 · Mini-Medaillen 2“
static func stand_text() -> String:
	return Loc.pick("Gold %d   ·   Karten %d/%d   ·   Mini-Medaillen %d",
		"Gold %d   ·   Maps %d/%d   ·   Mini medals %d") % [GameState.gold,
		GameState.cards.size(), GameState.card_capacity, GameState.medals]


## Name eines Ortes fürs Schild; beim Händler mit abgebbaren Belohnungen.
static func ort_name(id: StringName) -> String:
	match id:
		&"taverne":
			return Loc.pick("Taverne", "Tavern")
		&"haendler":
			var abholbar := GameState.abholbar_anzahl()
			var text := Loc.pick("Händler & Alchemist", "Merchant & alchemist")
			if abholbar > 0:
				text += Loc.pick(" (%d abgebbar)", " (%d to claim)") % abholbar
			return text
		&"schmiede":
			return Loc.pick("Schmiede", "Smithy")
		&"portal":
			return Loc.pick("Portal", "Portal")
		&"lagerfeuer":
			return Loc.pick("Lagerfeuer", "Campfire")
	return ""


## Was E am Ort tut (zweite Zeile des Schilds).
static func ort_aktion(id: StringName) -> String:
	match id:
		&"portal":
			return Loc.pick("Kartenlager", "Map storage")
		&"lagerfeuer":
			return Loc.pick("Werkstatt & Ausrüstung", "Workshop & equipment")
	return Loc.pick("Betreten", "Enter")


func _unhandled_input(event: InputEvent) -> void:
	if fenster_offen():
		return
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var punkt: Variant = _kulisse.boden_punkt((event as InputEventMouseButton).position)
		if punkt != null:
			_klick_ziel = _klick_ziel_fuer(punkt)
		return
	if event.is_action_pressed(&"interact") and not event.is_echo() and not _nah.is_empty():
		get_viewport().set_input_as_handled()
		_betreten(_nah)


## Klick auf einen Ort (oder nah davor) führt vor seine Tür, sonst zur
## angeklickten Stelle (am Platzrand begrenzt).
func _klick_ziel_fuer(punkt: Vector2) -> Vector2:
	for id in StadtKulisse.ORTE:
		var o: Dictionary = StadtKulisse.ORTE[id]
		var lokal := (punkt - (o["pos"] as Vector2)).rotated(deg_to_rad(float(o["dreh"])))
		var halb: Vector2 = o["halb"]
		if absf(lokal.x) < halb.x + 0.6 and absf(lokal.y) < halb.y + 0.6 \
				or punkt.distance_to(StadtKulisse.tuer(id)) < NAH:
			return StadtKulisse.tuer(id)
	return punkt.limit_length(LAUF_RADIUS)


func _process(delta: float) -> void:
	if fenster_offen():
		return
	var dir := Vector2.ZERO
	if Input.is_action_pressed(&"move_left") or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_action_pressed(&"move_right") or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_action_pressed(&"move_up") or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_action_pressed(&"move_down") or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	laufen(dir, delta)


## Ein Schritt: Tastatur-Richtung (Bildschirm = Platz, die Kamera schaut
## fest nach Norden) oder, ohne Taste, zum Klickziel. Achsen getrennt wie
## im Dungeon, damit man an Hauswänden entlanggleitet.
func laufen(dir: Vector2, delta: float) -> void:
	var weite := TEMPO * delta
	if dir != Vector2.ZERO:
		_klick_ziel = null
	elif _klick_ziel != null:
		dir = (_klick_ziel as Vector2) - held_pos
		weite = minf(weite, dir.length())
		if dir.length() < 0.05:
			_klick_ziel = null
			dir = Vector2.ZERO
	if dir != Vector2.ZERO:
		var schritt := dir.normalized() * weite
		var vorher := held_pos
		if frei(held_pos + Vector2(schritt.x, 0)):
			held_pos.x += schritt.x
		if frei(held_pos + Vector2(0, schritt.y)):
			held_pos.y += schritt.y
		if held_pos.distance_squared_to(vorher) < 0.0000001:
			_klick_ziel = null  # festgelaufen
	_kulisse.held_pos = held_pos
	_nah_pruefen()


## Darf der Held hier stehen? Platzrand, Brunnen und feste Orte.
static func frei(p: Vector2) -> bool:
	if p.length() > LAUF_RADIUS:
		return false
	if p.distance_to(StadtKulisse.BRUNNEN) < StadtKulisse.BRUNNEN_RADIUS + HALB:
		return false
	for id in StadtKulisse.ORTE:
		var o: Dictionary = StadtKulisse.ORTE[id]
		if not o["fest"]:
			continue
		var lokal := (p - (o["pos"] as Vector2)).rotated(deg_to_rad(float(o["dreh"])))
		var halb: Vector2 = o["halb"]
		if absf(lokal.x) < halb.x + HALB and absf(lokal.y) < halb.y + HALB:
			return false
	return true


## Nächster Ort, vor dessen Tür der Held steht → Schild zeigen.
func _nah_pruefen() -> void:
	var bester: StringName = &""
	var abstand := NAH
	for id in StadtKulisse.ORTE:
		var d := held_pos.distance_to(StadtKulisse.tuer(id))
		if d < abstand:
			abstand = d
			bester = id
	if bester == _nah:
		return
	_nah = bester
	_schild.visible = not _nah.is_empty()
	if _schild.visible:
		_schild.text = "%s\n[%s] %s" % [ort_name(_nah), Settings.key_name(&"interact"), ort_aktion(_nah)]


func _betreten(id: StringName) -> void:
	if id.is_empty() or _verlassen_laeuft or fenster_offen():
		return
	match id:
		&"portal":
			_portal()
		&"lagerfeuer":
			wahl_zeigen(ort_name(id), [
				[Loc.pick("Skill-Werkstatt", "Skill workshop"), _wechseln.bind(WORKSHOP_SCENE, id)],
				[Loc.pick("Ausrüstung & Inventar", "Equipment & inventory"), _wechseln.bind(INVENTORY_SCENE, id)],
			])
		_:
			_wechseln(ZIELE[id], id)


## Portal: Kartenlager — läuft schon ein Dungeon, zuerst die Wahl.
func _portal() -> void:
	if GameState.current_run.is_empty() or GameState.coop_guest_run:
		_wechseln(CARDS_SCENE, &"portal")
		return
	wahl_zeigen(ort_name(&"portal"), [
		[Loc.pick("Dungeon fortsetzen", "Resume dungeon"), _wechseln.bind(DUNGEON_SCENE, &"portal")],
		[Loc.pick("Kartenlager (%d/%d)", "Map storage (%d/%d)") % [GameState.cards.size(),
			GameState.card_capacity], _wechseln.bind(CARDS_SCENE, &"portal")],
	])


## In ein Menü wechseln; zurück steht der Held wieder vor `von`.
func _wechseln(pfad: String, von: StringName) -> void:
	if _verlassen_laeuft:
		return
	_verlassen_laeuft = true
	herkunft = von
	GameState.ui_return_scene = ""
	get_tree().change_scene_to_file(pfad)


# --- Fenster: Wahl und Stadt-Menü ------------------------------------------------

## Hält den Helden an: eigenes Fenster (Wahl, Stadt-Menü) oder ein Hinweis
## (Willkommen, Laden — UiTheme.show_hint), solange er offen ist.
func fenster_offen() -> bool:
	return eigenes_fenster_offen() or hinweis_offen()


## Nur das eigene Fenster (Wahl, Stadt-Menü), ohne Hinweise.
func eigenes_fenster_offen() -> bool:
	return is_instance_valid(_fenster) and not _fenster.is_queued_for_deletion()


## Offener Hinweis (UiTheme.show_hint hängt eine eigene Ebene an die Szene).
func hinweis_offen() -> bool:
	for kind in get_children():
		if kind is CanvasLayer and kind != _fenster_lage and not kind.is_queued_for_deletion() \
				and (kind as CanvasLayer).layer == UiTheme.HINWEIS_EBENE:
			return true
	return false


func _esc() -> void:
	if hinweis_offen():
		return  # der Hinweis schließt mit OK, Esc öffnet nichts darunter
	if eigenes_fenster_offen():
		fenster_schliessen()
	elif not _verlassen_laeuft:
		stadt_menue_zeigen()


func fenster_schliessen() -> void:
	if eigenes_fenster_offen():
		_fenster.queue_free()
		if _fenster_freigeben.is_valid():
			_fenster_freigeben.call()
	_fenster = null


## Kleines Fenster mit Titel und Knöpfen [[Text, Callable], …] plus
## „Zurück“; WASD + E bedienbar, Esc schließt. Gibt die Tafel-Box zurück.
func wahl_zeigen(titel: String, optionen: Array, zeilen: Array[String] = []) -> VBoxContainer:
	fenster_schliessen()
	_klick_ziel = null
	var fenster := Bildschirm.fenster(_fenster_lage)
	_fenster = fenster["mitte"]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	fenster["tafel"].add_child(box)
	box.add_child(Bildschirm.fenster_titel(titel))
	for zeile in zeilen:
		var label := Label.new()
		label.text = zeile
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color(UiTheme.TEXT, 0.72))
		box.add_child(label)
	var erster: Button = null
	for option in optionen:
		var knopf := Button.new()
		knopf.text = option[0]
		knopf.custom_minimum_size = Vector2(300, 46)
		knopf.pressed.connect(option[1])
		box.add_child(knopf)
		if erster == null:
			erster = knopf
	var zurueck_knopf := Button.new()
	zurueck_knopf.text = Loc.pick("Zurück (Esc)", "Back (Esc)")
	zurueck_knopf.custom_minimum_size = Vector2(300, 40)
	zurueck_knopf.pressed.connect(fenster_schliessen)
	box.add_child(zurueck_knopf)
	_fenster_freigeben = UiTheme.fokus_einsperren(_fenster)
	(erster if erster != null else zurueck_knopf).grab_focus.call_deferred()
	return box


## Stadt-Menü (Esc): Lexikon, Speichern, Hauptmenü; dazu Spielstand und Version.
func stadt_menue_zeigen() -> void:
	var slot := Loc.pick("Spielstand-Slot %d", "Save slot %d") % SaveManager.active_slot \
		+ (Loc.pick(" (Datei nicht lesbar, Speichern gesperrt)",
			" (file unreadable, saving locked)") if GameState.slot_gesperrt else "") \
		+ "   ·   v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	var box := wahl_zeigen(Loc.pick("Stadt-Menü", "Town menu"), [
		[Loc.pick("Lexikon", "Encyclopedia"), _lexikon],
		[Loc.pick("Speichern", "Save"), func() -> void: pass],
		[Loc.pick("Hauptmenü", "Main menu"), _hauptmenue],
	], [stand_text(), slot])
	# Speichern meldet sich im Knopf selbst („Gespeichert!“), das Fenster bleibt offen.
	for knopf in box.find_children("*", "Button", false, false):
		if (knopf as Button).text == Loc.pick("Speichern", "Save"):
			var speichern := knopf as Button
			speichern.pressed.connect(func() -> void:
				var ok := GameState.save_game()
				speichern.text = Loc.pick("Gespeichert!", "Saved!") if ok else Loc.pick("Fehler!", "Failed!")
				# Tween am Knopf: stirbt mit ihm, wenn das Fenster vorher schließt.
				var zurueck_tween := speichern.create_tween()
				zurueck_tween.tween_interval(1.5)
				zurueck_tween.tween_callback(func() -> void:
					speichern.text = Loc.pick("Speichern", "Save")))


func _lexikon() -> void:
	rueck_pos = held_pos
	_wechseln(LEXICON_SCENE, &"")


func _hauptmenue() -> void:
	if _verlassen_laeuft:
		return
	_verlassen_laeuft = true
	GameState.ui_return_scene = ""
	get_tree().change_scene_to_file(TITLE_SCENE)
