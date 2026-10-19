extends Control
## Optionen in vier Tabs: Audio (Gesamt/Musik/Effekte, stumm im Hintergrund),
## Anzeige (Fenstermodus, Auflösung, VSync, FPS-Grenze), Spiel (Sprache,
## Kampftempo, Bildschirmwackeln) und Steuerung (frei belegbare Hotkeys).
## Alles landet in user://settings.json (Settings-Autoload) — getrennt vom
## Spielstand.

const MAIN_SCENE := "res://scenes/main.tscn"
const TABS := [&"audio", &"anzeige", &"spiel", &"steuerung"]

## Zuletzt offener Tab — übersteht das Neuladen nach dem Sprachwechsel.
static var _tab: StringName = &"audio"

var _rebinding_action: StringName = &""
var _keybind_buttons: Dictionary = {}
var _resolution_select: OptionButton
var _tab_knoepfe: Dictionary = {}
var _inhalt: VBoxContainer


func _ready() -> void:
	theme = UiTheme.get_theme()
	Music.play(&"menu")
	_build_layout()


func _build_layout() -> void:
	var b := Bildschirm.bauen(self, Loc.pick("Optionen", "Options"), &"lager",
		func() -> void: get_tree().change_scene_to_file(MAIN_SCENE), Loc.pick("Menü", "Menu"))
	var leiste := HBoxContainer.new()
	leiste.add_theme_constant_override("separation", 6)
	b.inhalt.add_child(leiste)
	var namen := {
		&"audio": Loc.pick("Audio", "Audio"), &"anzeige": Loc.pick("Anzeige", "Display"),
		&"spiel": Loc.pick("Spiel", "Game"), &"steuerung": Loc.pick("Steuerung", "Controls"),
	}
	for id in TABS:
		var knopf := Button.new()
		knopf.text = namen[id]
		knopf.custom_minimum_size = Vector2(140, 36)
		knopf.pressed.connect(func() -> void:
			_tab = id
			_refresh())
		leiste.add_child(knopf)
		_tab_knoepfe[id] = knopf
	# Eine Tafel in einer Scroll-Fläche, damit bei kleinen Fenstern nichts verschwindet.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	b.inhalt.add_child(scroll)
	_inhalt = VBoxContainer.new()
	_inhalt.add_theme_constant_override("separation", 12)
	var tafel := Bildschirm.tafel(_inhalt)
	tafel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tafel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(tafel)

	var standard := Button.new()
	standard.text = Loc.pick("Standard wiederherstellen", "Restore defaults")
	standard.tooltip_text = Loc.pick("Setzt Audio, Anzeige und Spiel auf die Standardwerte. Hotkeys bleiben.",
		"Resets audio, display and game to their defaults. Hotkeys stay.")
	standard.pressed.connect(func() -> void:
		Settings.standard_wiederherstellen()
		Sfx.play(&"bestaetigen")
		_refresh())
	b.kopf_info.add_child(standard)
	# Credits & Lizenzen — für den öffentlichen Release Pflicht (Godot MIT).
	var credits := Button.new()
	credits.text = Loc.pick("Credits & Lizenzen", "Credits & licenses")
	credits.pressed.connect(_show_credits)
	b.kopf_info.add_child(credits)
	_refresh()


func _refresh() -> void:
	_rebinding_action = &""
	_keybind_buttons.clear()
	for id in _tab_knoepfe:
		UiTheme.als_aktiv(_tab_knoepfe[id], id == _tab)
	for kind in _inhalt.get_children():
		_inhalt.remove_child(kind)
		kind.queue_free()
	match _tab:
		&"audio":
			_baue_audio()
		&"anzeige":
			_baue_anzeige()
		&"spiel":
			_baue_spiel()
		_:
			_baue_steuerung()
	UiTheme.focus_first_button(self)


# --- Tabs ---------------------------------------------------------------------------

func _baue_audio() -> void:
	_inhalt.add_child(Bildschirm.ueberschrift(Loc.pick("Lautstärke", "Volume")))
	_regler(Loc.pick("Gesamt", "Master"), Settings.master_volume, func(wert: float) -> void:
		Settings.master_volume = wert
		Settings.apply_volume(), &"ui_klick")
	_regler(Loc.pick("Musik", "Music"), Settings.music_volume, func(wert: float) -> void:
		Settings.music_volume = wert
		Settings.apply_music_volume(), &"")
	_regler(Loc.pick("Effekte", "Effects"), Settings.sfx_volume, func(wert: float) -> void:
		Settings.sfx_volume = wert
		Settings.apply_sfx_volume(), &"treffer")
	_schalter(Loc.pick("Stumm im Hintergrund", "Mute in background"),
		Loc.pick("Kein Ton, solange das Spielfenster nicht im Vordergrund ist.",
			"No sound while the game window is not in focus."),
		Settings.hintergrund_stumm, func(an: bool) -> void:
			Settings.hintergrund_stumm = an
			Settings.apply_volume())


func _baue_anzeige() -> void:
	_inhalt.add_child(Bildschirm.ueberschrift(Loc.pick("Anzeige", "Display")))
	var mode_select := OptionButton.new()
	mode_select.add_item(Loc.pick("Fenster", "Windowed"))
	mode_select.add_item(Loc.pick("Randloses Vollbild", "Borderless fullscreen"))
	mode_select.add_item(Loc.pick("Exklusives Vollbild", "Exclusive fullscreen"))
	mode_select.select(int(Settings.window_mode))
	mode_select.item_selected.connect(func(index: int) -> void:
		Settings.window_mode = index as Settings.WindowMode
		Settings.apply_window()
		Settings.save_settings()
		_resolution_select.disabled = index != Settings.WindowMode.WINDOWED)
	_zeile(Loc.pick("Fenstermodus", "Window mode"), mode_select)

	_resolution_select = OptionButton.new()
	for res in Settings.RESOLUTIONS:
		_resolution_select.add_item("%d × %d" % [res.x, res.y])
	_resolution_select.select(maxi(0, Settings.RESOLUTIONS.find(Settings.resolution)))
	_resolution_select.disabled = Settings.window_mode != Settings.WindowMode.WINDOWED
	_resolution_select.item_selected.connect(func(index: int) -> void:
		Settings.resolution = Settings.RESOLUTIONS[index]
		Settings.apply_window()
		Settings.save_settings())
	_zeile(Loc.pick("Auflösung (Fenster)", "Resolution (windowed)"), _resolution_select)

	_schalter(Loc.pick("VSync", "VSync"),
		Loc.pick("Bildaufbau im Takt des Monitors.", "Frames are synced to the monitor refresh."),
		Settings.vsync, func(an: bool) -> void:
			Settings.vsync = an
			Settings.apply_anzeige())

	var fps := OptionButton.new()
	for grenze in Settings.FPS_GRENZEN:
		fps.add_item(Loc.pick("Unbegrenzt", "Unlimited") if grenze == 0 else "%d FPS" % grenze)
	fps.select(maxi(0, Settings.FPS_GRENZEN.find(Settings.fps_limit)))
	fps.item_selected.connect(func(index: int) -> void:
		Settings.fps_limit = Settings.FPS_GRENZEN[index]
		Settings.apply_anzeige()
		Settings.save_settings())
	_zeile(Loc.pick("Bildrate-Grenze", "Frame rate limit"), fps)

	var embed_hint := Label.new()
	embed_hint.text = Loc.pick("Im eingebetteten Editor-Fenster wirken Fenstermodus und Auflösung nicht.",
		"Window mode and resolution have no effect in the embedded editor window.")
	embed_hint.modulate = Color(1, 1, 1, 0.45)
	embed_hint.add_theme_font_size_override("font_size", 11)
	embed_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inhalt.add_child(embed_hint)


func _baue_spiel() -> void:
	_inhalt.add_child(Bildschirm.ueberschrift(Loc.pick("Spiel", "Game")))
	var language_button := Button.new()
	language_button.text = Loc.language_name()
	language_button.pressed.connect(func() -> void:
		GameState.language = "en" if GameState.language == "de" else "de"
		GameState.save_game()
		# Bestehende Instanzen (Inventar-Items) tragen gebackene Namen —
		# ein Lade-Roundtrip benennt sie in die neue Sprache um. Im Co-op
		# nicht: die laufende Session-Party darf nicht ersetzt werden.
		if not Net.is_online():
			GameState.load_game()
		get_tree().reload_current_scene())
	_zeile("Sprache / Language", language_button)

	var tempo := OptionButton.new()
	for faktor in Settings.KAMPF_TEMPI:
		tempo.add_item(("%.1f×" % faktor).replace(".0×", "×"))
	tempo.select(maxi(0, Settings.KAMPF_TEMPI.find(Settings.kampf_tempo)))
	tempo.tooltip_text = Loc.pick("Geschwindigkeit der Animationen im Kampf.",
		"Speed of the animations in battle.")
	tempo.item_selected.connect(func(index: int) -> void:
		Settings.kampf_tempo = Settings.KAMPF_TEMPI[index]
		Settings.save_settings())
	_zeile(Loc.pick("Kampftempo", "Battle speed"), tempo)

	_schalter(Loc.pick("Bildschirmwackeln", "Screen shake"),
		Loc.pick("Kamerastoß bei kritischen Treffern und Boss-Angriffen.",
			"Camera shake on critical hits and boss attacks."),
		Settings.bildschirm_wackeln, func(an: bool) -> void:
			Settings.bildschirm_wackeln = an)


func _baue_steuerung() -> void:
	_inhalt.add_child(Bildschirm.ueberschrift(Loc.pick("Hotkeys (klicken, dann Taste drücken)",
		"Hotkeys (click, then press a key)")))
	for action in Settings.ACTIONS:
		var button := Button.new()
		button.text = Settings.key_name(action)
		button.pressed.connect(_begin_rebind.bind(action))
		_zeile(Settings.action_label(action), button)
		_keybind_buttons[action] = button
	var reset := Button.new()
	reset.text = Loc.pick("Hotkeys zurücksetzen", "Reset hotkeys")
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func() -> void:
		Settings.reset_keybinds()
		_refresh_keybind_buttons())
	_inhalt.add_child(reset)


# --- Bausteine ------------------------------------------------------------------------

## Zeile: Beschriftung links, Bedienelement rechts.
func _zeile(text: String, element: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_inhalt.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(260, 0)
	row.add_child(label)
	element.custom_minimum_size = Vector2(maxf(element.custom_minimum_size.x, 260), 36)
	row.add_child(element)
	return row


## Lautstärke-Regler 0–100 % mit Prozentanzeige; `probe` klingt nach dem Ziehen.
func _regler(text: String, wert: float, setzen: Callable, probe: StringName) -> void:
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = roundf(wert * 100)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := _zeile(text, slider)
	var prozent := Label.new()
	prozent.text = "%d %%" % int(slider.value)
	prozent.custom_minimum_size = Vector2(60, 0)
	row.add_child(prozent)
	slider.value_changed.connect(func(v: float) -> void:
		prozent.text = "%d %%" % int(v)
		setzen.call(v / 100.0)
		Settings.save_settings())
	if probe != &"":
		slider.drag_ended.connect(func(_changed: bool) -> void:
			Sfx.play(probe))


## An/Aus-Schalter mit Erklärung darunter.
func _schalter(text: String, erklaerung: String, wert: bool, setzen: Callable) -> void:
	var knopf := CheckButton.new()
	knopf.button_pressed = wert
	knopf.text = Loc.pick("An", "On") if wert else Loc.pick("Aus", "Off")
	knopf.toggled.connect(func(an: bool) -> void:
		knopf.text = Loc.pick("An", "On") if an else Loc.pick("Aus", "Off")
		setzen.call(an)
		Settings.save_settings())
	_zeile(text, knopf)
	var hinweis := Label.new()
	hinweis.text = erklaerung
	hinweis.modulate = Color(1, 1, 1, 0.55)
	hinweis.add_theme_font_size_override("font_size", 12)
	hinweis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inhalt.add_child(hinweis)


## Vollflächiges Credits-Overlay: Wer hat's gemacht, welche Bausteine
## stecken drin — inklusive des kompletten Godot-Lizenztexts (MIT), den
## die Engine-Lizenz für ausgelieferte Spiele zugänglich verlangt.
func _show_credits() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	# Merksatz: Anker VOR dem Einhängen setzen.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var root := VBoxContainer.new()
	root.theme = UiTheme.get_theme()
	root.add_theme_constant_override("separation", 10)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 80
	root.offset_right = -80
	root.offset_top = 30
	root.offset_bottom = -30
	layer.add_child(root)

	var head := Label.new()
	head.text = Loc.pick("Credits & Lizenzen", "Credits & licenses")
	head.add_theme_font_size_override("font_size", 28)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var text := RichTextLabel.new()
	text.fit_content = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text = _credits_text()
	scroll.add_child(text)

	var close := Button.new()
	close.text = Loc.pick("Schließen", "Close")
	close.custom_minimum_size = Vector2(240, 44)
	var freigeben := UiTheme.fokus_einsperren(root)
	close.pressed.connect(func() -> void:
		freigeben.call()
		layer.queue_free())
	root.add_child(close)
	close.grab_focus()


static func _credits_text() -> String:
	var parts: Array[String] = [
		Loc.pick("INFINIT DUNGEON  ·  ein Spiel von Lutz",
			"INFINIT DUNGEON  ·  a game by Lutz"),
		"",
		Loc.pick("— Grafik —", "— Art —"),
		Loc.pick("Kenney „Tiny Dungeon“ (kenney.nl) — Creative Commons Zero (CC0), frei verwendbar. Danke, Kenney!",
			"Kenney \"Tiny Dungeon\" (kenney.nl) — Creative Commons Zero (CC0). Thanks, Kenney!"),
		"",
		Loc.pick("— Klang —", "— Audio —"),
		Loc.pick("Alle Soundeffekte und Musik werden prozedural im Spiel erzeugt.",
			"All sound effects and music are generated procedurally in-game."),
		"",
		"— Engine —",
		Loc.pick("Erstellt mit Godot Engine (godotengine.org), Version %s.",
			"Made with Godot Engine (godotengine.org), version %s.")
			% Engine.get_version_info()["string"],
		"",
		Loc.pick("Vollständiger Engine-Lizenztext (MIT u.a.):",
			"Full engine license text (MIT et al.):"),
		"",
		Engine.get_license_text(),
	]
	return "\n".join(parts)


func _begin_rebind(action: StringName) -> void:
	_rebinding_action = action
	_keybind_buttons[action].text = Loc.pick("Taste drücken …", "Press a key …")


func _unhandled_key_input(event: InputEvent) -> void:
	if _rebinding_action == &"" or not (event is InputEventKey and event.pressed):
		return
	var key_event := event as InputEventKey
	if key_event.physical_keycode == KEY_ESCAPE:
		# Esc bricht die Neubelegung ab (und bleibt selbst unbelegbar).
		_keybind_buttons[_rebinding_action].text = Settings.key_name(_rebinding_action)
	else:
		Settings.rebind(_rebinding_action, key_event.physical_keycode)
		_keybind_buttons[_rebinding_action].text = Settings.key_name(_rebinding_action)
		Sfx.play(&"bestaetigen")
	_rebinding_action = &""
	get_viewport().set_input_as_handled()


func _refresh_keybind_buttons() -> void:
	for action in _keybind_buttons:
		_keybind_buttons[action].text = Settings.key_name(action)
