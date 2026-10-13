extends Control
## Spiel-Lexikon: jede Mechanik nachlesbar — Kategorien links, Einträge in
## der Mitte, Inhalt rechts (BBCode). Inhalte kommen aus LexiconLibrary
## (zweisprachig, DE/EN).

const MAIN_SCENE := "res://scenes/main.tscn"

var _category_box: VBoxContainer
var _entry_box: VBoxContainer
var _body_title: Label
var _body_text: RichTextLabel
var _current_category: StringName = &"kampf"


func _ready() -> void:
	theme = UiTheme.get_theme()
	Music.play(&"menu")
	_build_layout()
	_refresh_categories()
	_open_category(&"kampf")
	UiTheme.focus_first_button(self)


func _build_layout() -> void:
	var b := Bildschirm.bauen(self, Loc.pick("Lexikon", "Encyclopedia"), &"lager",
		func() -> void: get_tree().change_scene_to_file(MAIN_SCENE), Loc.pick("Menü", "Menu"))
	var root := b.inhalt

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	# Links: Kategorien.
	var category_scroll := ScrollContainer.new()
	category_scroll.custom_minimum_size = Vector2(200, 0)
	category_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	category_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(category_scroll)
	_category_box = VBoxContainer.new()
	_category_box.add_theme_constant_override("separation", 4)
	_category_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	category_scroll.add_child(_category_box)

	# Mitte: Einträge der Kategorie.
	var entry_scroll := ScrollContainer.new()
	entry_scroll.custom_minimum_size = Vector2(290, 0)
	entry_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	entry_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(entry_scroll)
	_entry_box = VBoxContainer.new()
	_entry_box.add_theme_constant_override("separation", 4)
	_entry_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_scroll.add_child(_entry_box)

	# Rechts: der Inhalt.
	var body_panel := Bildschirm.tafel()
	body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(body_panel)
	var body_box := VBoxContainer.new()
	body_box.add_theme_constant_override("separation", 8)
	body_panel.add_child(body_box)
	_body_title = Label.new()
	_body_title.add_theme_font_size_override("font_size", 22)
	body_box.add_child(_body_title)
	_body_text = RichTextLabel.new()
	_body_text.bbcode_enabled = true
	_body_text.fit_content = false
	_body_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_text.add_theme_font_size_override("normal_font_size", 15)
	body_box.add_child(_body_text)


func _refresh_categories() -> void:
	for child in _category_box.get_children():
		child.queue_free()
	for category in LexiconLibrary.categories():
		var button := _liste_knopf(category["title"])
		button.set_meta(&"id", category["id"])
		button.pressed.connect(_open_category.bind(category["id"]))
		_category_box.add_child(button)


func _liste_knopf(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = text
	return button


func _open_category(category_id: StringName) -> void:
	_current_category = category_id
	for button: Button in _category_box.get_children():
		UiTheme.als_aktiv(button, button.get_meta(&"id", &"") == category_id)
	for child in _entry_box.get_children():
		child.queue_free()
	var entries := LexiconLibrary.entries(category_id)
	for entry in entries:
		var button := _liste_knopf(entry["title"])
		button.pressed.connect(_show_entry.bind(entry))
		_entry_box.add_child(button)
	if not entries.is_empty():
		_show_entry(entries[0])


func _show_entry(entry: Dictionary) -> void:
	for button: Button in _entry_box.get_children():
		if not button.is_queued_for_deletion():
			UiTheme.als_aktiv(button, button.text == entry["title"])
	_body_title.text = entry["title"]
	_body_text.text = entry["body"]
