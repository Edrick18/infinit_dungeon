extends Control
## Optionen: Lautstärke, Fenstermodus, Auflösung und frei belegbare Hotkeys.
## Alles landet in user://settings.json (Settings-Autoload) — getrennt vom
## Spielstand.

const MAIN_SCENE := "res://scenes/main.tscn"

var _rebinding_action: StringName = &""
var _keybind_buttons: Dictionary = {}
var _resolution_select: OptionButton


func _ready() -> void:
	theme = UiTheme.get_theme()
	Music.play(&"menu")
	_build_layout()


func _build_layout() -> void:
	add_child(UiTheme.make_background(&"lager", true))

	# Scrollbar, damit bei kleinen Fenstern nichts abgeschnitten wird
	# (der Zurück-Knopf war sonst unerreichbar).
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60
	scroll.offset_right = -60
	scroll.offset_top = 16
	scroll.offset_bottom = -16
	scroll.follow_focus = true
	add_child(scroll)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	var title := Label.new()
	title.text = Loc.pick("Optionen", "Options")
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	# --- Sprache (aus dem Hauptmenü hierher gezogen) -----------------------------
	var language_row := HBoxContainer.new()
	language_row.add_theme_constant_override("separation", 12)
	box.add_child(language_row)
	var language_label := Label.new()
	language_label.text = "Sprache / Language"
	language_label.custom_minimum_size = Vector2(160, 0)
	language_row.add_child(language_label)
	var language_button := Button.new()
	language_button.text = Loc.language_name()
	language_button.custom_minimum_size = Vector2(240, 36)
	language_button.pressed.connect(func() -> void:
		GameState.language = "en" if GameState.language == "de" else "de"
		GameState.save_game()
		# Bestehende Instanzen (Inventar-Items) tragen gebackene Namen —
		# ein Lade-Roundtrip benennt sie in die neue Sprache um. Im Co-op
		# nicht: die laufende Session-Party darf nicht ersetzt werden.
		if not Net.is_online():
			GameState.load_game()
		get_tree().reload_current_scene())
	language_row.add_child(language_button)

	# --- Lautstärke ------------------------------------------------------------
	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 12)
	box.add_child(volume_row)
	var volume_label := Label.new()
	volume_label.text = Loc.pick("Lautstärke", "Volume")
	volume_label.custom_minimum_size = Vector2(160, 0)
	volume_row.add_child(volume_label)
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.value = Settings.master_volume * 100
	volume.custom_minimum_size = Vector2(240, 0)
	volume.value_changed.connect(func(value: float) -> void:
		Settings.master_volume = value / 100.0
		Settings.apply_volume()
		Settings.save_settings())
	volume.drag_ended.connect(func(_changed: bool) -> void:
		Sfx.play(&"ui_klick"))  # Probeklang in der neuen Lautstärke
	volume_row.add_child(volume)

	# --- Musik-Lautstärke (eigener Bus, unabhängig von den Effekten) ------------
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 12)
	box.add_child(music_row)
	var music_label := Label.new()
	music_label.text = Loc.pick("Musik", "Music")
	music_label.custom_minimum_size = Vector2(160, 0)
	music_row.add_child(music_label)
	var music_slider := HSlider.new()
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.value = Settings.music_volume * 100
	music_slider.custom_minimum_size = Vector2(240, 0)
	music_slider.value_changed.connect(func(value: float) -> void:
		Settings.music_volume = value / 100.0
		Settings.apply_music_volume()
		Settings.save_settings())
	music_row.add_child(music_slider)

	# --- Fenstermodus ----------------------------------------------------------
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	box.add_child(mode_row)
	var mode_label := Label.new()
	mode_label.text = Loc.pick("Fenstermodus", "Window mode")
	mode_label.custom_minimum_size = Vector2(160, 0)
	mode_row.add_child(mode_label)
	var mode_select := OptionButton.new()
	mode_select.custom_minimum_size = Vector2(240, 0)
	mode_select.add_item(Loc.pick("Fenster", "Windowed"))
	mode_select.add_item(Loc.pick("Randloses Vollbild", "Borderless fullscreen"))
	mode_select.add_item(Loc.pick("Exklusives Vollbild", "Exclusive fullscreen"))
	mode_select.select(int(Settings.window_mode))
	mode_select.item_selected.connect(func(index: int) -> void:
		Settings.window_mode = index as Settings.WindowMode
		Settings.apply_window()
		Settings.save_settings()
		_resolution_select.disabled = index != Settings.WindowMode.WINDOWED)
	mode_row.add_child(mode_select)

	var embed_hint := Label.new()
	embed_hint.text = Loc.pick("Hinweis: Im eingebetteten Editor-Fenster wirken Fenstermodus/Auflösung nicht — als eigenständiges Spiel starten.",
		"Note: window mode/resolution have no effect in the embedded editor window — run the game standalone.")
	embed_hint.modulate = Color(1, 1, 1, 0.45)
	embed_hint.add_theme_font_size_override("font_size", 11)
	embed_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(embed_hint)

	# --- Auflösung (nur im Fenstermodus) ----------------------------------------
	var resolution_row := HBoxContainer.new()
	resolution_row.add_theme_constant_override("separation", 12)
	box.add_child(resolution_row)
	var resolution_label := Label.new()
	resolution_label.text = Loc.pick("Auflösung", "Resolution")
	resolution_label.custom_minimum_size = Vector2(160, 0)
	resolution_row.add_child(resolution_label)
	_resolution_select = OptionButton.new()
	_resolution_select.custom_minimum_size = Vector2(240, 0)
	for res in Settings.RESOLUTIONS:
		_resolution_select.add_item("%d × %d" % [res.x, res.y])
	var current := Settings.RESOLUTIONS.find(Settings.resolution)
	_resolution_select.select(maxi(0, current))
	_resolution_select.disabled = Settings.window_mode != Settings.WindowMode.WINDOWED
	_resolution_select.item_selected.connect(func(index: int) -> void:
		Settings.resolution = Settings.RESOLUTIONS[index]
		Settings.apply_window()
		Settings.save_settings())
	resolution_row.add_child(_resolution_select)

	# --- Hotkeys -----------------------------------------------------------------
	var keys_title := Label.new()
	keys_title.text = Loc.pick("Hotkeys (klicken, dann Taste drücken)",
		"Hotkeys (click, then press a key)")
	keys_title.add_theme_font_size_override("font_size", 18)
	box.add_child(keys_title)
	for action in Settings.ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		box.add_child(row)
		var label := Label.new()
		label.text = Settings.action_label(action)
		label.custom_minimum_size = Vector2(240, 0)
		row.add_child(label)
		var button := Button.new()
		button.text = Settings.key_name(action)
		button.custom_minimum_size = Vector2(160, 0)
		button.pressed.connect(_begin_rebind.bind(action))
		row.add_child(button)
		_keybind_buttons[action] = button

	var reset := Button.new()
	reset.text = Loc.pick("Hotkeys zurücksetzen", "Reset hotkeys")
	reset.pressed.connect(func() -> void:
		Settings.reset_keybinds()
		_refresh_keybind_buttons())
	box.add_child(reset)

	# Credits & Lizenzen — für den öffentlichen Release Pflicht (Godot MIT).
	var credits := Button.new()
	credits.text = Loc.pick("Credits & Lizenzen", "Credits & licenses")
	credits.custom_minimum_size = Vector2(240, 40)
	credits.pressed.connect(_show_credits)
	box.add_child(credits)

	var back := Button.new()
	back.text = Loc.pick("Zurück zum Menü", "Back to menu")
	back.custom_minimum_size = Vector2(240, 44)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(MAIN_SCENE))
	box.add_child(back)
	back.grab_focus()


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
	close.pressed.connect(layer.queue_free)
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
