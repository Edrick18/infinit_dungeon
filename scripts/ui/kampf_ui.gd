class_name KampfUi
extends RefCounted
## Gemeinsame Bausteine der Kampf-UI (Host + Co-op-Gast): unterer Bereich
## mit Log über den Party-Karten, Party-Karten mit Zahlen auf den Balken,
## HP-Farbe nach Füllstand, goldener Rahmen für den Helden am Zug.

const HP_GUT := Color("5fbf6a")
const HP_MITTEL := Color("e8b44a")
const HP_KRITISCH := Color("e94560")
const MP_FARBE := Color("5a8ee8")
const LOG_HOEHE := 96


## Unterer Bereich: links Log (oben) + Party-Karten (unten), rechts die
## Befehle. Die Arena darüber bekommt so den ganzen freien Platz.
static func unterer_bereich(main: VBoxContainer) -> Dictionary:
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	main.add_child(bottom)
	var links := VBoxContainer.new()
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links.add_theme_constant_override("separation", 8)
	links.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_child(links)
	var log_label := RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(0, LOG_HOEHE)
	log_label.scroll_following = true
	log_label.add_theme_stylebox_override("normal", UiTheme.glas_tafel())
	log_label.add_theme_font_size_override("normal_font_size", 13)
	log_label.modulate.a = 0.0  # erst sichtbar mit der ersten Zeile (log_zeile)
	links.add_child(log_label)
	var party_row := HBoxContainer.new()
	party_row.add_theme_constant_override("separation", 10)
	links.add_child(party_row)
	var action_box := VBoxContainer.new()
	action_box.custom_minimum_size = Vector2(240, 0)
	action_box.add_theme_constant_override("separation", 6)
	bottom.add_child(action_box)
	return {"log": log_label, "party": party_row, "aktionen": action_box}


## Zeile ans Kampflog hängen; die leere Tafel bleibt bis dahin unsichtbar.
static func log_zeile(log_label: RichTextLabel, text: String) -> void:
	log_label.append_text(text + "\n")
	log_label.modulate.a = 1.0


## Party-Karte: Porträt links, rechts Name, HP- und MP-Balken mit Zahlen,
## Status und geplante Aktion.
static func party_karte(portrait: Control, name: String, name_farbe := UiTheme.TEXT) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	var reihe := HBoxContainer.new()
	reihe.add_theme_constant_override("separation", 10)
	panel.add_child(reihe)
	var bild := CenterContainer.new()
	bild.add_child(portrait)
	reihe.add_child(bild)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	reihe.add_child(box)
	var name_label := Label.new()
	name_label.text = name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", name_farbe)
	name_label.clip_text = true
	box.add_child(name_label)
	var hp := balken(16, HP_GUT, true)
	box.add_child(hp)
	var mp := balken(12, MP_FARBE)
	box.add_child(mp)
	var status_label := Label.new()
	status_label.add_theme_font_size_override("font_size", 11)
	box.add_child(status_label)
	var plan_label := Label.new()
	plan_label.add_theme_font_size_override("font_size", 11)
	plan_label.add_theme_color_override("font_color", UiTheme.GOLD)
	plan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(plan_label)
	return {"root": panel, "hp": hp, "mp": mp, "status": status_label, "plan": plan_label,
		"name": name_label}


## Balken mit eigener Füllfarbe und mittiger Zahl („156/156"); HP-Balken
## (nach_fuellstand) wechseln unter 50 % zu Gold, unter 25 % zu Rot.
static func balken(hoehe: int, farbe: Color, nach_fuellstand := false, mit_zahl := true) -> ProgressBar:
	return Balken.new(hoehe, farbe, nach_fuellstand, mit_zahl)


class Balken:
	extends ProgressBar

	var _zahl: Label
	var _fuellung: StyleBoxFlat
	var _nach_fuellstand: bool

	func _init(hoehe: int, farbe: Color, nach_fuellstand: bool, mit_zahl: bool) -> void:
		_nach_fuellstand = nach_fuellstand
		show_percentage = false
		custom_minimum_size = Vector2(0, hoehe)
		var hintergrund := StyleBoxFlat.new()
		hintergrund.bg_color = Color(0.03, 0.03, 0.08, 0.85)
		hintergrund.set_corner_radius_all(4)
		add_theme_stylebox_override("background", hintergrund)
		_fuellung = StyleBoxFlat.new()
		_fuellung.set_corner_radius_all(4)
		_fuellung.border_width_top = 2
		_faerben(farbe)
		add_theme_stylebox_override("fill", _fuellung)
		_zahl = Label.new()
		_zahl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_zahl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_zahl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_zahl.add_theme_font_size_override("font_size", maxi(9, hoehe - 4))
		_zahl.add_theme_constant_override("outline_size", 3)
		_zahl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_zahl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_zahl.visible = mit_zahl
		add_child(_zahl)
		value_changed.connect(_neu)
		changed.connect(_neu.bind(0.0))
		_neu(0.0)

	# Range meldet Wertänderungen nur im Baum — beim Einhängen nachziehen.
	func _ready() -> void:
		_neu(0.0)

	func _neu(_wert: float) -> void:
		_zahl.text = "%d/%d" % [roundi(value), roundi(max_value)]
		if _nach_fuellstand:
			var anteil := value / maxf(1.0, max_value)
			_faerben(HP_GUT if anteil > 0.5 else (HP_MITTEL if anteil > 0.25 else HP_KRITISCH))

	func _faerben(farbe: Color) -> void:
		_fuellung.bg_color = farbe
		_fuellung.border_color = farbe.lightened(0.3)

const SCHWACH_FARBE := Color("ffd25a")
const RESIST_FARBE := Color(0.62, 0.68, 0.85)


## Bekannte Schwächen/Resistenzen eines Gegners: [[element, faktor], …] —
## nur, was die Spieler schon im Kampf entdeckt haben (GameState).
static func element_wissen(gegner: Combatant) -> Array:
	var liste: Array = []
	var schluessel := gegner.wissens_schluessel()
	for element in gegner.element_faktoren:
		if GameState.kennt_element(schluessel, int(element)):
			liste.append([int(element), float(gegner.element_faktoren[element])])
	return liste


## Füllt eine Chip-Reihe: ▲ Feuer (schwach, gold) · ▼ Eis (resistent, grau).
static func wissen_chips(box: HBoxContainer, liste: Array) -> void:
	for kind in box.get_children():
		kind.queue_free()
	for eintrag in liste:
		var block := BlockLibrary.element_block(int(eintrag[0]))
		if block == null:
			continue
		var schwach := float(eintrag[1]) > 1.0
		box.add_child(chip(("▲ " if schwach else "▼ ") + block.display_name,
			SCHWACH_FARBE if schwach else RESIST_FARBE))
	box.visible = not liste.is_empty()


## Kleiner farbiger Chip (Typen, Schwächen) — klick-durchlässig.
static func chip(text: String, farbe: Color) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(farbe.r, farbe.g, farbe.b, 0.22)
	stil.border_color = farbe
	stil.set_border_width_all(1)
	stil.set_corner_radius_all(4)
	stil.content_margin_left = 6
	stil.content_margin_right = 6
	stil.content_margin_top = 1
	stil.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", stil)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", farbe.lightened(0.35))
	panel.add_child(label)
	return panel


## Großes, ausblendendes Banner in der Bildmitte (Erstschlag/Hinterhalt).
static func banner(eltern: Control, text: String, farbe: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", farbe)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.08, 0.9))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 50
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	eltern.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


## Boss-Banner: Name groß, darunter die Eigenheit als Taktik-Hinweis.
static func boss_banner(eltern: Control, name: String, hinweis: String) -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = 50
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for zeile in [[name, 44, Color("ff5a4a")], [hinweis, 19, UiTheme.GOLD]]:
		if String(zeile[0]).is_empty():
			continue
		var label := Label.new()
		label.text = zeile[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", zeile[1])
		label.add_theme_color_override("font_color", zeile[2])
		label.add_theme_constant_override("outline_size", 10)
		label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.08, 0.9))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
	eltern.add_child(box)
	box.modulate.a = 0.0
	var tween := box.create_tween()
	tween.tween_property(box, "modulate:a", 1.0, 0.35)
	tween.tween_interval(2.4)
	tween.tween_property(box, "modulate:a", 0.0, 0.7)
	tween.tween_callback(box.queue_free)


## Goldener Rahmen um die Karte des Helden, der gerade Befehle bekommt.
static func aktiv_setzen(karte: Control, aktiv: bool) -> void:
	if not aktiv:
		karte.remove_theme_stylebox_override("panel")
		return
	var box := (karte.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	box.border_color = UiTheme.GOLD
	box.set_border_width_all(2)
	box.shadow_color = Color(UiTheme.GOLD, 0.25)
	box.shadow_size = 10
	box.shadow_offset = Vector2.ZERO
	karte.add_theme_stylebox_override("panel", box)
