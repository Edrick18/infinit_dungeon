class_name UiTheme
extends RefCounted
## Zentrales UI-Theme im Spielzeug-Look von STIL-3D: halbtransparente
## Nachtblau-Tafeln über der 3D-Kulisse, Knöpfe mit „Unterkante", die beim
## Drücken einsinken, Gold als Akzent für Hover/Fokus. Jede Szene setzt
## `theme = UiTheme.get_theme()` auf ihrem Root und holt sich mit
## `make_background(ort)` die 3D-Kulisse (MenueKulisse).

const BG := Color("15152a")
const PANEL := Color(0.105, 0.105, 0.2, 0.88)
const PANEL_BORDER := Color("3c3c66")
const FIELD := Color("15152a")
const BUTTON := Color("2e2e56")
const BUTTON_KANTE := Color("16162c")
const BUTTON_HOVER := Color("3b3b6e")
const BUTTON_HOVER_BORDER := Color("c9a14a")
const BUTTON_PRESSED := Color("26264a")
const BUTTON_DISABLED := Color(0.13, 0.13, 0.23, 0.8)
const ACCENT := Color("e94560")
const GOLD := Color("e8b44a")
const TEXT := Color("ecebf6")
const TEXT_DIM := Color(0.91, 0.91, 0.96, 0.55)
const HP_FILL := Color("5fbf6a")
const BAR_BG := Color("101020")

static var _theme: Theme = null


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var theme := Theme.new()
	theme.default_font_size = 14

	# Knöpfe wie Spielzeugklötze: dunkle Unterkante (Tiefe), Hover = Goldrand,
	# Drücken = Klotz sinkt ein (Kante weg, Inhalt rutscht 2 px nach unten).
	theme.set_stylebox("normal", "Button", _knopf(BUTTON, BUTTON_KANTE, 4))
	theme.set_stylebox("hover", "Button", _knopf(BUTTON_HOVER, BUTTON_HOVER_BORDER, 4))
	theme.set_stylebox("pressed", "Button", _knopf(BUTTON_PRESSED, GOLD, 1))
	theme.set_stylebox("disabled", "Button", _knopf(BUTTON_DISABLED, Color(0, 0, 0, 0.25), 2))
	theme.set_stylebox("focus", "Button", _focus_box())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color("fff4d6"))
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_hover_pressed_color", "Button", GOLD)

	# OptionButton (Dropdowns) im selben Look wie Buttons.
	for style in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(style, "OptionButton", theme.get_stylebox(style, "Button"))
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_hover_color", "OptionButton", Color("fff4d6"))
	theme.set_color("font_disabled_color", "OptionButton", TEXT_DIM)
	var popup := _box(Color("1b1b33"), true)
	popup.shadow_color = Color(0, 0, 0, 0.45)
	popup.shadow_size = 10
	theme.set_stylebox("panel", "PopupMenu", popup)
	theme.set_stylebox("hover", "PopupMenu", _box(BUTTON_HOVER, true, BUTTON_HOVER_BORDER))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", Color("fff4d6"))

	# Tafeln: halbtransparent über der 3D-Kulisse, weicher Schatten, oben
	# ein feiner heller Saum (Licht fällt von oben).
	var panel := _box(PANEL, true)
	panel.set_corner_radius_all(10)
	panel.border_width_top = 2
	panel.border_color = Color("4a4a80")
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 12
	panel.shadow_offset = Vector2(0, 4)
	panel.content_margin_left = 14
	panel.content_margin_right = 14
	panel.content_margin_top = 10
	panel.content_margin_bottom = 10
	theme.set_stylebox("panel", "PanelContainer", panel)

	# Labels: leichter Schlagschatten, damit Text über 3D immer lesbar bleibt.
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 2)
	# Eingabefelder
	theme.set_stylebox("normal", "LineEdit", _box(FIELD, true))
	theme.set_stylebox("focus", "LineEdit", _focus_box())
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("caret_color", "LineEdit", TEXT)

	# Slider (Lautstärke): schlanke Leiste, griffiger Knauf.
	var slider_bg := _box(BAR_BG, true)
	slider_bg.content_margin_top = 2
	slider_bg.content_margin_bottom = 2
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", _box(ACCENT))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(GOLD))

	# Fortschrittsbalken (HP/MP)
	theme.set_stylebox("background", "ProgressBar", _box(BAR_BG))
	theme.set_stylebox("fill", "ProgressBar", _box(HP_FILL))

	# Log-/Textflächen
	theme.set_stylebox("normal", "RichTextLabel", _box(BAR_BG, true))
	theme.set_color("default_color", "RichTextLabel", TEXT)

	# Tooltips
	var tooltip := _box(Color("0d0d1e"), true, Color("50508a"))
	theme.set_stylebox("panel", "TooltipPanel", tooltip)
	theme.set_color("font_color", "TooltipLabel", TEXT)

	# Scrollbereiche unauffällig, Scrollbalken schlank.
	var empty := StyleBoxEmpty.new()
	theme.set_stylebox("panel", "ScrollContainer", empty)
	var scrollbar := _box(Color("2a2a4a"))
	scrollbar.content_margin_left = 2
	scrollbar.content_margin_right = 2
	theme.set_stylebox("grabber", "VScrollBar", scrollbar)
	theme.set_stylebox("grabber_highlight", "VScrollBar", _box(Color("44447a")))
	theme.set_stylebox("scroll", "VScrollBar", _box(Color("14142a")))

	_theme = theme
	return _theme


static func _box(color: Color, bordered := false, border_color := PANEL_BORDER) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(6)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	if bordered:
		box.set_border_width_all(1)
		box.border_color = border_color
	return box


static func _knopf(farbe: Color, kante: Color, tiefe: int) -> StyleBoxFlat:
	var box := _box(farbe, true, kante)
	box.set_corner_radius_all(8)
	box.border_width_bottom = tiefe
	box.content_margin_top = 6 + (4 - tiefe)
	box.content_margin_bottom = 6
	box.content_margin_left = 14
	box.content_margin_right = 14
	return box


static func _focus_box() -> StyleBoxFlat:
	var box := _box(Color(0, 0, 0, 0))
	box.set_corner_radius_all(9)
	box.set_border_width_all(2)
	box.border_color = GOLD
	box.expand_margin_left = 2
	box.expand_margin_right = 2
	box.expand_margin_top = 2
	box.expand_margin_bottom = 2
	return box


## Halbtransparente Tafel für Text über 3D-Szenen (Kampflog über der Arena).
static func glas_tafel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.05, 0.12, 0.72)
	box.set_corner_radius_all(6)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


## 3D-Kulisse für alle Menü-/Hub-Szenen (STIL-3D 7e): die eigene Party im
## Diorama — `ort` wählt das Herzstück (lager, taverne, schmiede, laden),
## `ruhig` dunkelt für textlastige Bildschirme stärker ab.
static func make_background(ort: StringName = &"lager", ruhig := false) -> Control:
	var bg := MenueKulisse.new(ort, ruhig)
	# WICHTIG: Anker VOR dem Einhängen setzen — nach add_child greift der
	# Preset nicht mehr zuverlässig (Godot-Layout-Eigenheit, Größe blieb 0).
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -1
	return bg


## Sanfter Szenen-Übergang: ein Overlay über der ganzen Szene blendet beim
## Betreten aus — jede Szene mit Kulisse bekommt das gratis.
static func szene_einblenden(szene: Node) -> void:
	if szene == null or not szene.is_inside_tree():
		return
	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.04, 0.1, 1.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 100
	szene.add_child.call_deferred(overlay)
	var fade := szene.get_tree().create_tween().bind_node(overlay)
	fade.tween_interval(0.05)
	fade.tween_property(overlay, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.tween_callback(overlay.queue_free)

## Einmaliger Onboarding-Hinweis: abgedunkeltes Overlay mit Titel, Text
## und OK — der Aufrufer prüft GameState.first_time() selbst.
## Merksatz: Anker VOR dem Einhängen setzen.
static func show_hint(parent: Node, title: String, text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 85
	parent.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.theme = get_theme()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(480, 0)
	box.add_child(body)
	var ok := Button.new()
	ok.text = "OK"
	ok.custom_minimum_size = Vector2(160, 40)
	ok.pressed.connect(layer.queue_free)
	box.add_child(ok)
	ok.grab_focus.call_deferred()


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
	if node is BaseButton and not (node as BaseButton).disabled \
			and (node as Control).is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _find_first_button(child)
		if found != null:
			return found
	return null


## Reiter/Auswahlknopf als „gerade gewählt" zeigen: gesperrt (kein erneutes
## Anklicken), aber golden hervorgehoben statt ausgegraut.
static func als_aktiv(button: Button, aktiv: bool) -> void:
	button.disabled = aktiv
	if aktiv:
		button.add_theme_stylebox_override("disabled", _knopf(BUTTON_HOVER, GOLD, 3))
		button.add_theme_color_override("font_disabled_color", GOLD)
	else:
		button.remove_theme_stylebox_override("disabled")
		button.remove_theme_color_override("font_disabled_color")


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
			als_aktiv(button, true)
		else:
			var path: String = tab[2]
			button.pressed.connect(func() -> void:
				bar.get_tree().change_scene_to_file(path))
		bar.add_child(button)
	return bar
