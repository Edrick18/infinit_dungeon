extends Control
## Titelbildschirm (Startszene): Fortsetzen, Neues Spiel, Spielstände, Co-op,
## Optionen, Beenden — Holztafel-Spalte links wie im Hub, rechts das
## Lagerfeuer-Diorama. Der Spielstand des aktiven Slots ist zu diesem
## Zeitpunkt schon geladen (GameState._ready); „Fortsetzen“ führt nur in den
## Hub (scenes/main.tscn), der alle Spiel-Bildschirme bündelt.

const SPALTE_BREITE := 470
const KULISSE_VERSATZ := -1.75

const HUB_SCENE := "res://scenes/main.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const OPTIONS_SCENE := "res://scenes/hub/options.tscn"
const COOP_SCENE := "res://scenes/hub/coop.tscn"
const SAVES_SCENE := "res://scenes/hub/saves.tscn"


func _ready() -> void:
	theme = UiTheme.get_theme()
	Music.play(&"menu")
	add_child(UiTheme.make_background(&"lager", false, KULISSE_VERSATZ))

	var spalte := CenterContainer.new()
	spalte.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	spalte.offset_left = Bildschirm.RAND * 2
	spalte.offset_right = Bildschirm.RAND * 2 + SPALTE_BREITE
	spalte.offset_top = Bildschirm.RAND
	spalte.offset_bottom = -Bildschirm.RAND
	add_child(spalte)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(SPALTE_BREITE - 2 * Bildschirm.RAND, 0)
	spalte.add_child(Bildschirm.tafel(box, Bildschirm.RAND))

	var title := Bildschirm.fenster_titel("Infinit Dungeon")
	title.add_theme_font_size_override("font_size", 52)
	box.add_child(title)
	box.add_child(HSeparator.new())

	# Fortsetzen nur mit vorhandenem Helden — sonst wartet im Hub erst die
	# Heldenerstellung, und das ist „Neues Spiel“.
	if hat_spielstand():
		var weiter := _knopf(box, Loc.pick("Fortsetzen", "Continue"))
		weiter.pressed.connect(func() -> void: _wechseln(HUB_SCENE))
		var info := Label.new()
		info.text = _slot_zeile()
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_theme_font_size_override("font_size", 12)
		info.add_theme_color_override("font_color", Color(UiTheme.TEXT, 0.6))
		box.add_child(info)

	var neu := _knopf(box, Loc.pick("Neues Spiel", "New game"))
	neu.pressed.connect(func() -> void: _wechseln(neues_spiel_ziel(), true))
	var staende := _knopf(box, Loc.pick("Spielstände", "Save games"))
	staende.pressed.connect(func() -> void: _wechseln(SAVES_SCENE, true))
	# Co-op braucht eine Party (die Co-op-Szene kehrt in den Hub zurück).
	if hat_spielstand():
		var coop := _knopf(box, Loc.pick("Co-op", "Co-op"))
		coop.pressed.connect(func() -> void: _wechseln(COOP_SCENE))
	var optionen := _knopf(box, Loc.pick("Optionen", "Options"))
	optionen.pressed.connect(func() -> void: _wechseln(OPTIONS_SCENE, true))
	var beenden := _knopf(box, Loc.pick("Beenden", "Quit"))
	beenden.pressed.connect(_beenden)

	# Fußzeile wie im Hub: Version unten links.
	var version := Label.new()
	version.text = "v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	version.add_theme_font_size_override("font_size", 11)
	version.add_theme_color_override("font_color", Color(UiTheme.TEXT, 0.5))
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)  # vor add_child
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_left = Bildschirm.RAND
	version.offset_top = -Bildschirm.RAND
	version.offset_bottom = -Bildschirm.RAND
	add_child(version)

	UiTheme.focus_first_button(self)
	_lade_hinweis_zeigen()


## Gibt es im aktiven Slot ein spielbares Spiel (mindestens einen Helden)?
static func hat_spielstand() -> bool:
	return not GameState.party.is_empty()


## „Neues Spiel“: Ist der aktive Slot noch leer (und lesbar), beginnt die
## Heldenerstellung direkt im Hub; sonst wird unter „Spielstände“ ein freier
## Slot gewählt — ein bestehendes Spiel wird nie stillschweigend ersetzt.
static func neues_spiel_ziel() -> String:
	if GameState.party.is_empty() and not GameState.slot_gesperrt:
		return HUB_SCENE
	return SAVES_SCENE


func _slot_zeile() -> String:
	var namen: Array[String] = []
	for member in GameState.party:
		namen.append(member.display_name)
	return Loc.pick("Slot %d: %s", "Slot %d: %s") % [SaveManager.active_slot, ", ".join(namen)]


## Szene wechseln; Spielstände und Optionen kehren hierher zurück.
func _wechseln(pfad: String, zurueck_zum_titel := false) -> void:
	GameState.ui_return_scene = TITLE_SCENE if zurueck_zum_titel and pfad != HUB_SCENE else ""
	get_tree().change_scene_to_file(pfad)


## Spiel beenden: speichert vorher wie der Fenster-X (Co-op-Gast nie).
func _beenden() -> void:
	if hat_spielstand() and not Net.is_guest() and not GameState.coop_guest_run:
		GameState.save_game()
	if Net.is_online():
		Net.stop()
	get_tree().quit()


## Meldung vom Laden (Sicherung geladen / Datei unlesbar), einmal anzeigen.
func _lade_hinweis_zeigen() -> void:
	var text := GameState.lade_hinweis_text()
	if text.is_empty():
		return
	GameState.lade_hinweis = {}
	UiTheme.show_hint(self, Loc.pick("Spielstand", "Save game"), text)


func _knopf(box: VBoxContainer, label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(340, 50)
	button.add_theme_font_size_override("font_size", 16)
	box.add_child(button)
	return button
