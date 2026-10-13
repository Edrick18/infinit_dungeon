class_name DungeonHud
extends Control
## HUD des Dungeons im STIL-3D-Look: oben links Kartentitel mit Wert-Chips,
## unten links die Party als Mini-Karten (Porträt + HP-Balken mit Zahl),
## unten rechts die Tasten, oben mittig Meldungen. Die Minimap hängt die
## Dungeon-Szene selbst oben rechts ein.

const CHIP_FARBE := Color(1, 1, 1, 0.07)

var _titel: Label
var _chips := {}       ## Schlüssel » Label
var _party_leiste: HBoxContainer
var _karten := {}      ## Combatant » {"root", "hp"}
var _studio: PortraitStudio
var _meldung: Label
var _meldung_tafel: PanelContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	_studio = PortraitStudio.new()
	add_child(_studio)

	# Oben links: Titel + Chips
	var oben := _tafel()
	oben.position = Vector2(10, 8)
	add_child(oben)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oben.add_child(box)
	_titel = Label.new()
	_titel.add_theme_font_size_override("font_size", 18)
	_titel.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(_titel)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(chips)
	for schluessel in ["stufe", "ebene", "gegner", "gold"]:
		chips.add_child(_chip(schluessel))

	# Unten links: Party-Karten (wachsen nach oben)
	_party_leiste = HBoxContainer.new()
	_party_leiste.add_theme_constant_override("separation", 8)
	_party_leiste.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party_leiste.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_party_leiste.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)
	add_child(_party_leiste)

	# Unten rechts: Tasten
	var tasten := HBoxContainer.new()
	tasten.add_theme_constant_override("separation", 6)
	tasten.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tasten.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tasten.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tasten.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	add_child(tasten)
	for paar in [[Settings.key_name(&"open_inventory"), Loc.pick("Inventar & Tränke", "Inventory & potions")],
			["Esc", Loc.pick("Verlassen", "Leave")], [Loc.pick("Mausrad", "Wheel"), "Zoom"]]:
		tasten.add_child(_taste(paar[0]))
		var text := Label.new()
		text.text = paar[1] + "   "
		text.add_theme_font_size_override("font_size", 12)
		text.modulate = Color(1, 1, 1, 0.75)
		tasten.add_child(text)

	# Oben mittig: Meldungen (nur sichtbar, wenn es etwas zu sagen gibt)
	var mitte := CenterContainer.new()
	mitte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mitte.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mitte.offset_top = 92
	add_child(mitte)
	_meldung_tafel = _tafel()
	_meldung_tafel.visible = false
	mitte.add_child(_meldung_tafel)
	_meldung = Label.new()
	_meldung.add_theme_font_size_override("font_size", 16)
	_meldung.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	_meldung.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meldung_tafel.add_child(_meldung)


## Einmal pro Bild: Titel, Werte und Party-HP spiegeln.
func aktualisieren(titel: String, werte: Dictionary, party: Array) -> void:
	_titel.text = titel
	for schluessel in werte:
		if _chips.has(schluessel):
			_chips[schluessel].text = werte[schluessel]
	for held in _karten.keys():
		if held not in party:
			_karten[held]["root"].queue_free()
			_karten.erase(held)
	for held: Combatant in party:
		if not _karten.has(held):
			_karten[held] = _party_karte(held)
		var karte: Dictionary = _karten[held]
		karte["hp"].max_value = held.max_hp
		karte["hp"].value = held.hp
		karte["root"].modulate = Color.WHITE if held.is_alive() else Color(1, 1, 1, 0.4)


func meldung_zeigen(text: String) -> void:
	_meldung.text = text
	_meldung_tafel.visible = text != ""


func meldung() -> String:
	return _meldung.text


func _party_karte(held: Combatant) -> Dictionary:
	var tafel := _tafel()
	tafel.custom_minimum_size = Vector2(176, 0)
	_party_leiste.add_child(tafel)
	var reihe := HBoxContainer.new()
	reihe.add_theme_constant_override("separation", 8)
	reihe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tafel.add_child(reihe)
	var bild := TextureRect.new()
	bild.texture = _studio.textur(FigurenBau.schluessel_fuer(held),
		func() -> Node3D: return FigurenBau.held_aus(held))
	bild.custom_minimum_size = Vector2(40, 40)
	bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reihe.add_child(bild)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	reihe.add_child(box)
	var name_label := Label.new()
	name_label.text = held.display_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.clip_text = true
	box.add_child(name_label)
	var hp := KampfUi.balken(14, KampfUi.HP_GUT, true)
	box.add_child(hp)
	return {"root": tafel, "hp": hp}


func _tafel() -> PanelContainer:
	var tafel := PanelContainer.new()
	tafel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stil := UiTheme.glas_tafel()
	stil.set_corner_radius_all(10)
	stil.border_width_top = 2
	stil.border_color = Color(1, 1, 1, 0.1)
	tafel.add_theme_stylebox_override("panel", stil)
	return tafel


func _chip(schluessel: String) -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stil := StyleBoxFlat.new()
	stil.bg_color = CHIP_FARBE
	stil.set_corner_radius_all(9)
	stil.content_margin_left = 8
	stil.content_margin_right = 8
	stil.content_margin_top = 1
	stil.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", stil)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	chip.add_child(label)
	_chips[schluessel] = label
	return chip


## Tastenkappe im Knopf-Look (Unterkante wie die UI-Knöpfe).
func _taste(text: String) -> Control:
	var kappe := PanelContainer.new()
	kappe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stil := StyleBoxFlat.new()
	stil.bg_color = UiTheme.BUTTON
	stil.set_corner_radius_all(5)
	stil.border_width_bottom = 3
	stil.border_color = UiTheme.BUTTON_KANTE
	stil.content_margin_left = 7
	stil.content_margin_right = 7
	stil.content_margin_top = 1
	stil.content_margin_bottom = 1
	kappe.add_theme_stylebox_override("panel", stil)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UiTheme.GOLD)
	kappe.add_child(label)
	return kappe
