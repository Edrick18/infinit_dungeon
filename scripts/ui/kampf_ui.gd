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
