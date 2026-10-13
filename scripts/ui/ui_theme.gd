class_name UiTheme
extends RefCounted
## Zentrales UI-Theme (im Code gebaut, bis ein richtiges Art-Theme kommt):
## dunkle Panels mit Rand, klare Buttons mit Hover-Akzent, lesbare Balken —
## überall gleich. Jede Szene setzt `theme = UiTheme.get_theme()` auf ihrem
## Root und holt sich mit `make_background()` den bewegten Hintergrund
## (Farbverlauf + treibende Glut-/Magie-Funken).

const BG := Color("15152a")
const BG_TOP := Color("101022")
const BG_BOTTOM := Color("241740")
const PANEL := Color("222240")
const PANEL_BORDER := Color("3c3c66")
const FIELD := Color("18182e")
const BUTTON := Color("2c2c50")
const BUTTON_HOVER := Color("3a3a68")
const BUTTON_HOVER_BORDER := Color("6c6cb0")
const BUTTON_PRESSED := Color("232344")
const BUTTON_DISABLED := Color("20203a")
const ACCENT := Color("e94560")
const GOLD := Color("e8b44a")
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

	# Buttons: dezenter Rand, der beim Hovern aufleuchtet — fühlbares UI.
	theme.set_stylebox("normal", "Button", _box(BUTTON, true, PANEL_BORDER))
	theme.set_stylebox("hover", "Button", _box(BUTTON_HOVER, true, BUTTON_HOVER_BORDER))
	theme.set_stylebox("pressed", "Button", _box(BUTTON_PRESSED, true, ACCENT))
	theme.set_stylebox("disabled", "Button", _box(BUTTON_DISABLED))
	theme.set_stylebox("focus", "Button", _focus_box())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)
	theme.set_color("font_focus_color", "Button", Color.WHITE)

	# OptionButton (Dropdowns) im selben Look wie Buttons.
	for style in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(style, "OptionButton", theme.get_stylebox(style, "Button"))
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_hover_color", "OptionButton", Color.WHITE)
	theme.set_color("font_disabled_color", "OptionButton", TEXT_DIM)
	theme.set_stylebox("panel", "PopupMenu", _box(PANEL, true))
	theme.set_stylebox("hover", "PopupMenu", _box(BUTTON_HOVER))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)

	# Panels: Rand + etwas Innenabstand, damit nichts am Rahmen klebt.
	var panel := _box(PANEL, true)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	theme.set_stylebox("panel", "PanelContainer", panel)

	# Labels
	theme.set_color("font_color", "Label", TEXT)

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


static func _focus_box() -> StyleBoxFlat:
	var box := _box(Color(0, 0, 0, 0))
	box.set_border_width_all(1)
	box.border_color = ACCENT
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


## Bewegter Hintergrund für alle Menü-/Hub-Szenen: dunkler Farbverlauf mit
## langsam aufsteigenden Glut- und Magie-Funken. Rein prozedural (keine
## Assets), bewusst dezent — Inhalt bleibt der Star.
static func make_background() -> Control:
	var bg := AnimatedBackground.new()
	# WICHTIG: Anker VOR dem Einhängen setzen — nach add_child greift der
	# Preset nicht mehr zuverlässig (Godot-Layout-Eigenheit, Größe blieb 0).
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return bg


class AnimatedBackground:
	extends Control

	const PARTICLE_COUNT := 48
	var _particles: Array[Dictionary] = []
	var _time := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = -1
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in PARTICLE_COUNT:
			_particles.append(_spawn(rng, true))
		_fade_in_scene.call_deferred()

	## Sanfter Szenen-Übergang: ein schwarzes Overlay über der ganzen
	## Szene blendet beim Betreten aus — jede Szene bekommt das gratis,
	## weil jede Szene diesen Hintergrund nutzt.
	func _fade_in_scene() -> void:
		var parent := get_parent()
		if parent == null:
			return
		var overlay := ColorRect.new()
		overlay.color = Color(0.04, 0.04, 0.1, 1.0)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = 100
		parent.add_child(overlay)
		var fade := overlay.create_tween()
		fade.tween_property(overlay, "color:a", 0.0, 0.28) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		fade.tween_callback(overlay.queue_free)

	## Ein Funke: normierte Position, Drift-Tempo, Größe, Farbe, Sinus-Phase.
	func _spawn(rng: RandomNumberGenerator, anywhere := false) -> Dictionary:
		var warm := rng.randf() < 0.55
		return {
			"x": rng.randf(),
			"y": rng.randf() if anywhere else 1.05,
			"speed": rng.randf_range(0.015, 0.045),
			"size": rng.randf_range(1.5, 3.5),
			"sway": rng.randf_range(0.6, 1.6),
			"phase": rng.randf() * TAU,
			"color": Color("e8b44a") if warm else Color("6a8fe8"),
			"alpha": rng.randf_range(0.16, 0.38),
		}

	func _process(delta: float) -> void:
		_time += delta
		var respawn := RandomNumberGenerator.new()
		for particle in _particles:
			particle["y"] -= particle["speed"] * delta * 10.0
			if particle["y"] < -0.05:
				var fresh := _spawn(respawn)
				for key in fresh:
					particle[key] = fresh[key]
		queue_redraw()

	func _draw() -> void:
		# Vertikaler Farbverlauf als Bänder (weich genug, spottbillig).
		var bands := 24
		var band_height := size.y / bands
		for i in bands:
			var t := float(i) / (bands - 1)
			var color := UiTheme.BG_TOP.lerp(UiTheme.BG_BOTTOM, t)
			draw_rect(Rect2(0, i * band_height, size.x, band_height + 1.0), color)
		# Funken: äußeres Glühen + heller Kern, leichtes Sinus-Schweben.
		for particle in _particles:
			var sway: float = sin(_time * particle["sway"] + particle["phase"]) * 14.0
			var pos := Vector2(particle["x"] * size.x + sway, particle["y"] * size.y)
			var color: Color = particle["color"]
			color.a = particle["alpha"] * 0.4
			draw_circle(pos, particle["size"] * 2.6, color)
			color.a = particle["alpha"]
			draw_circle(pos, particle["size"], color)


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
