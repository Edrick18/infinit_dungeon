class_name UiTheme
extends RefCounted
## Zentrales UI-Theme (STIL-3D.md 7e): Tafeln und Knöpfe aus dunklem Holz
## mit Messing (UiHolz: prozedurale ImageTexture + StyleBoxTexture, 9-Slice,
## kein Shader), Tooltips aus Pergament, Gold für Hover/aktiv, eine eigene
## kühle Fokus-Rolle für WASD+E. Alle Farben kommen aus Stil3D.PAL — die
## einzige Farbquelle; Seltenheit bleibt LootGenerator.RARITY_COLORS.
## Jede Szene setzt `theme = UiTheme.get_theme()` auf ihrem Root und holt
## sich mit `make_background(ort)` die 3D-Kulisse (MenueKulisse).

const GOLD: Color = Stil3D.PAL["gold"]            ## Hover, aktiv, Titel, Info
const MESSING: Color = Stil3D.PAL["messing"]      ## Rahmen, Linien
const FOKUS: Color = Stil3D.PAL["fokus"]          ## NUR der Tastatur-Fokus
const ACCENT: Color = Stil3D.PAL["warnrot"]       ## Warnung, Gefahr, Hinterhalt
const TEXT: Color = Stil3D.PAL["ui_text"]
const TEXT_HELL: Color = Stil3D.PAL["ui_text_hell"]
const TEXT_DIM := Color(Stil3D.PAL["ui_text"], 0.55)  ## ui_text, halb deckend
const TINTE: Color = Stil3D.PAL["tinte"]          ## Text auf Pergament
const HOLZ_TIEF: Color = Stil3D.PAL["ui_holz_tief"]
const KERBE: Color = Stil3D.PAL["ui_kerbe"]
const HP_FILL: Color = Stil3D.PAL["hp_gut"]
const BAR_BG: Color = Stil3D.PAL["ui_kerbe"]
## Tastenkappen im HUD (Knopf-Look ohne Knopf).
const BUTTON: Color = Stil3D.PAL["ui_holz"]
const BUTTON_KANTE: Color = Stil3D.PAL["messing_dunkel"]

static var _theme: Theme = null
static var _innen: Theme = null


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var theme := Theme.new()
	theme.default_font_size = 14

	# Knöpfe = Holzklötze mit Messing-Unterkante; Hover = Messingsaum, Drücken
	# sinkt ein (Kante weg, Inhalt rutscht), gesperrt = ergraut, Fokus = der
	# kühle Leuchtrahmen über allem.
	for typ in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", typ, UiHolz.box("knopf"))
		theme.set_stylebox("hover", typ, UiHolz.box("knopf_hover"))
		theme.set_stylebox("pressed", typ, UiHolz.box("knopf_druck"))
		theme.set_stylebox("hover_pressed", typ, UiHolz.box("knopf_druck"))
		theme.set_stylebox("disabled", typ, UiHolz.box("knopf_aus"))
		theme.set_stylebox("focus", typ, UiHolz.fokus_box())
		theme.set_color("font_color", typ, TEXT)
		theme.set_color("font_hover_color", typ, TEXT_HELL)
		theme.set_color("font_pressed_color", typ, GOLD)
		theme.set_color("font_hover_pressed_color", typ, GOLD)
		theme.set_color("font_focus_color", typ, TEXT_HELL)
		theme.set_color("font_disabled_color", typ, TEXT_DIM)
		theme.set_color("font_outline_color", typ, KERBE)
		theme.set_constant("outline_size", typ, 3)
	# Schalter (Optionen): ohne Klotz, nur Hover-Fach und Fokus.
	var leer := StyleBoxEmpty.new()
	leer.set_content_margin_all(4)
	for zustand in ["normal", "pressed", "disabled", "hover_pressed"]:
		theme.set_stylebox(zustand, "CheckButton", leer)
	theme.set_stylebox("hover", "CheckButton", UiHolz.box("fach"))
	theme.set_stylebox("focus", "CheckButton", UiHolz.fokus_box())
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_hover_color", "CheckButton", TEXT_HELL)
	theme.set_color("font_pressed_color", "CheckButton", TEXT)
	theme.set_color("font_hover_pressed_color", "CheckButton", TEXT_HELL)
	theme.set_color("font_focus_color", "CheckButton", TEXT_HELL)

	theme.set_stylebox("panel", "PopupMenu", UiHolz.box("tafel"))
	theme.set_stylebox("hover", "PopupMenu", UiHolz.box("knopf_hover"))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", TEXT_HELL)
	theme.set_color("font_separator_color", "PopupMenu", MESSING)

	# Tafeln: dunkles Holz mit Messingrahmen und Nieten. Innerhalb einer
	# Inhaltstafel (Bildschirm.tafel) werden Zeilen zu eingelassenen Fächern
	# (innen_theme) — sonst stapelten sich Messingrahmen.
	theme.set_stylebox("panel", "PanelContainer", UiHolz.box("tafel"))

	# Labels: Schlagschatten in Kerbenfarbe, Text über 3D bleibt lesbar.
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(KERBE, 0.75))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 2)
	# Eingabefelder: eingelassene dunkle Kerbe.
	for typ in ["LineEdit", "TextEdit"]:
		theme.set_stylebox("normal", typ, UiHolz.box("feld"))
		theme.set_stylebox("read_only", typ, UiHolz.box("feld"))
		theme.set_stylebox("focus", typ, UiHolz.fokus_box())
		theme.set_color("font_color", typ, TEXT)
		theme.set_color("caret_color", typ, GOLD)
		theme.set_color("font_placeholder_color", typ, TEXT_DIM)
		theme.set_color("selection_color", typ, Color(GOLD, 0.35))

	# Slider (Lautstärke): Kerbe als Leiste, Messing gefüllt, Gold beim Greifen.
	var slider_bg := _box(BAR_BG, true, Color(MESSING, 0.5))
	slider_bg.content_margin_top = 3
	slider_bg.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", _box(MESSING))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(GOLD))
	theme.set_stylebox("focus", "HSlider", UiHolz.fokus_box())

	# Fortschrittsbalken (HP/MP)
	theme.set_stylebox("background", "ProgressBar", _box(BAR_BG))
	theme.set_stylebox("fill", "ProgressBar", _box(HP_FILL))

	# Log-/Textflächen
	theme.set_stylebox("normal", "RichTextLabel", UiHolz.box("feld"))
	theme.set_color("default_color", "RichTextLabel", TEXT)

	# Tooltips: Pergament mit Tinte.
	theme.set_stylebox("panel", "TooltipPanel", UiHolz.box("pergament"))
	theme.set_color("font_color", "TooltipLabel", TINTE)
	theme.set_color("font_shadow_color", "TooltipLabel", Color(0, 0, 0, 0))

	# Trennlinien als Messingfaden.
	var linie := StyleBoxLine.new()
	linie.color = Color(MESSING, 0.6)
	linie.thickness = 2
	theme.set_stylebox("separator", "HSeparator", linie)
	theme.set_constant("separation", "HSeparator", 8)

	# Scrollbereiche unauffällig, Scrollbalken schlank in Messing.
	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	var griff := _box(Color(MESSING, 0.75))
	griff.content_margin_left = 3
	griff.content_margin_right = 3
	theme.set_stylebox("grabber", "VScrollBar", griff)
	theme.set_stylebox("grabber_highlight", "VScrollBar", _box(GOLD))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _box(GOLD))
	theme.set_stylebox("scroll", "VScrollBar", _box(Color(KERBE, 0.8)))

	_theme = theme
	return _theme


## Theme für den Inhalt einer Tafel (Bildschirm.tafel): Zeilen-Panels sind
## dort eingelassene Fächer statt eigener Messingtafeln. Alles andere erbt
## vom Haupt-Theme.
static func innen_theme() -> Theme:
	if _innen != null:
		return _innen
	_innen = Theme.new()
	_innen.set_stylebox("panel", "PanelContainer", UiHolz.box("fach"))
	return _innen


static func _box(color: Color, bordered := false, border_color := MESSING) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(5)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	if bordered:
		box.set_border_width_all(1)
		box.border_color = border_color
	return box


## Fokusrahmen für selbstgebaute Kacheln (PanelContainer zeichnen keinen
## eigenen) — derselbe kühle Leuchtrahmen wie bei Knöpfen.
static func fokus_rahmen() -> StyleBoxFlat:
	return UiHolz.fokus_box()


## Rauchglas in Holzton für Text über 3D-Szenen (Kampflog über der Arena,
## Dungeon-HUD): leichter als eine Holztafel, Messingfaden oben und unten.
static func glas_tafel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(HOLZ_TIEF, 0.8)
	box.border_color = Color(MESSING, 0.5)
	box.border_width_top = 1
	box.border_width_bottom = 1
	box.set_corner_radius_all(6)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


## 3D-Kulisse für alle Menü-/Hub-Szenen (STIL-3D 7e): die eigene Party im
## Diorama — `ort` wählt das Herzstück (lager, taverne, schmiede, laden),
## `ruhig` dunkelt für textlastige Bildschirme stärker ab, `versatz` rückt das
## Diorama zur Seite (Camera3D.h_offset; Hauptmenü: Knopfspalte links).
static func make_background(ort: StringName = &"lager", ruhig := false, versatz := 0.0) -> Control:
	var bg := MenueKulisse.new(ort, ruhig)
	bg.versatz = versatz
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
	overlay.color = Color(KERBE, 1.0)
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
	dim.color = Color(KERBE, 0.62)
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
	box.add_child(ok)
	var freigeben := fokus_einsperren(center)
	ok.pressed.connect(func() -> void:
		freigeben.call()
		layer.queue_free())
	ok.grab_focus.call_deferred()


## Tastatur-Fokus im Fenster halten (Spieltest 2026-10-19): solange es offen
## ist, sind alle anderen Elemente nicht per Tastatur erreichbar — sonst
## springt WASD auf (gesperrte) Knöpfe dahinter, z.B. Gegner-Ziele unter dem
## Sieg-Fenster. Gibt die Rücknahme zurück (beim Schließen aufrufen).
static func fokus_einsperren(fenster: Control) -> Callable:
	var gesperrt: Array = []
	if fenster.is_inside_tree():
		for knoten in fenster.get_tree().root.find_children("*", "Control", true, false):
			var c := knoten as Control
			if c.focus_mode == Control.FOCUS_NONE or c == fenster or fenster.is_ancestor_of(c):
				continue
			gesperrt.append([c, c.focus_mode])
			c.focus_mode = Control.FOCUS_NONE
	return func() -> void:
		for eintrag in gesperrt:
			if is_instance_valid(eintrag[0]):
				(eintrag[0] as Control).focus_mode = eintrag[1]


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
	# Kopfzeile, Stadt-Reiter, Zurück: nie der Start-Fokus (ganzer Teilbaum).
	if node.has_meta(&"nicht_zuerst"):
		return null
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
		button.add_theme_stylebox_override("disabled", UiHolz.box("knopf_aktiv"))
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
