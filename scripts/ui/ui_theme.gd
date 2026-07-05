class_name UiTheme
extends RefCounted
## Zentrales UI-Theme (im Code gebaut, bis ein richtiges Art-Theme kommt):
## dunkle Panels mit Rand, klare Buttons, lesbare Balken — überall gleich.
## Jede Szene setzt `theme = UiTheme.get_theme()` auf ihrem Root.

const BG := Color("15152a")
const PANEL := Color("222240")
const PANEL_BORDER := Color("3c3c66")
const FIELD := Color("18182e")
const BUTTON := Color("2c2c50")
const BUTTON_HOVER := Color("3a3a68")
const BUTTON_PRESSED := Color("232344")
const BUTTON_DISABLED := Color("20203a")
const ACCENT := Color("e94560")
const TEXT := Color("e8e8f4")
const TEXT_DIM := Color(0.91, 0.91, 0.96, 0.55)
const HP_FILL := Color("5fbf6a")
const BAR_BG := Color("101020")

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var theme := Theme.new()
	theme.default_font_size = 14

	# Buttons
	theme.set_stylebox("normal", "Button", _box(BUTTON))
	theme.set_stylebox("hover", "Button", _box(BUTTON_HOVER))
	theme.set_stylebox("pressed", "Button", _box(BUTTON_PRESSED))
	theme.set_stylebox("disabled", "Button", _box(BUTTON_DISABLED))
	theme.set_stylebox("focus", "Button", _focus_box())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)

	# Panels
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, true))

	# Labels
	theme.set_color("font_color", "Label", TEXT)

	# Eingabefelder
	theme.set_stylebox("normal", "LineEdit", _box(FIELD, true))
	theme.set_stylebox("focus", "LineEdit", _focus_box())
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", TEXT)

	# Fortschrittsbalken (HP/MP)
	theme.set_stylebox("background", "ProgressBar", _box(BAR_BG))
	theme.set_stylebox("fill", "ProgressBar", _box(HP_FILL))

	# Log-/Textflächen
	theme.set_stylebox("normal", "RichTextLabel", _box(BAR_BG, true))
	theme.set_color("default_color", "RichTextLabel", TEXT)

	# Tooltips
	theme.set_stylebox("panel", "TooltipPanel", _box(Color("101024"), true))
	theme.set_color("font_color", "TooltipLabel", TEXT)

	# Scrollbereiche unauffällig
	var empty := StyleBoxEmpty.new()
	theme.set_stylebox("panel", "ScrollContainer", empty)

	_theme = theme
	return _theme


static func _box(color: Color, bordered := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(6)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	if bordered:
		box.set_border_width_all(1)
		box.border_color = PANEL_BORDER
	return box


static func _focus_box() -> StyleBoxFlat:
	var box := _box(Color(0, 0, 0, 0))
	box.set_border_width_all(1)
	box.border_color = ACCENT
	return box


## Tastatur-Navigation: den ersten aktiven Button fokussieren, damit man
## jede Szene ohne Maus bedienen kann (Pfeile/Tab bewegen, Enter aktiviert).
## Klaut niemandem den Fokus, wenn schon etwas fokussiert ist.
static func focus_first_button(root: Node) -> void:
	if not root.is_inside_tree():
		return
	var owner := root.get_viewport().gui_get_focus_owner()
	if owner != null and is_instance_valid(owner):
		return
	var button := _find_first_button(root)
	if button != null:
		button.grab_focus.call_deferred()


static func _find_first_button(node: Node) -> BaseButton:
	if node is BaseButton and not (node as BaseButton).disabled 			and (node as Control).is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _find_first_button(child)
		if found != null:
			return found
	return null


## Stadt-Navigation: Taverne, Händler und Schmiede sind EIN Ort — diese
## Tab-Leiste hängt oben in allen drei Szenen (aktueller Tab deaktiviert).
static func town_tabs(current: StringName) -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var tabs := [
		[&"taverne", Loc.pick("Taverne", "Tavern"), "res://scenes/hub/tavern.tscn"],
		[&"haendler", Loc.pick("Händler & Alchemist", "Merchant & alchemist"),
			"res://scenes/hub/shop_scene.tscn"],
		[&"schmiede", Loc.pick("Schmiede", "Smithy"), "res://scenes/hub/smith.tscn"],
	]
	for tab in tabs:
		var button := Button.new()
		button.text = tab[1]
		button.custom_minimum_size = Vector2(190, 36)
		if tab[0] == current:
			button.disabled = true
		else:
			var path: String = tab[2]
			button.pressed.connect(func() -> void:
				bar.get_tree().change_scene_to_file(path))
		bar.add_child(button)
	return bar
