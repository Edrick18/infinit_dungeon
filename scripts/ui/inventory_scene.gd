extends Control
## Ausrüstung & Inventar (Lutz 2026-10-14): Reiter Ausrüstung | Werte |
## Tränke & Feldzauber | Materialien.
## Ausrüstung: links die Figur mit den Ausrüstungs-Slots, rechts die Taschen
## als Raster aus Icons (wächst mit der Anzahl). Ein Klick auf einen Slot
## zeigt nur, was dort hineinpasst. Fährt die Maus über einen Gegenstand,
## erscheint seine Karte — Strg schaltet den Vergleich mit dem Ausgerüsteten
## an/aus (besser grün, schlechter rot). Doppelklick rüstet aus.

const MAIN_SCENE := "res://scenes/main.tscn"
const KACHEL := 64
const ALLE := -1

## Slot-Anordnung um die Figur: [Slot, Spalte, Zeile].
const PUPPE := [
	[Enums.EquipSlot.AMULET, 0, 0], [Enums.EquipSlot.HELMET, 1, 0], [Enums.EquipSlot.RING_1, 2, 0],
	[Enums.EquipSlot.WEAPON, 0, 1], [Enums.EquipSlot.ARMOR, 1, 1], [Enums.EquipSlot.OFF_HAND, 2, 1],
	[Enums.EquipSlot.GLOVES, 0, 2], [Enums.EquipSlot.BOOTS, 1, 2], [Enums.EquipSlot.RING_2, 2, 2],
]

var _selected: Combatant = null
var _gold_label: Label
var _vergleich_label: Label
var _char_bar: HBoxContainer
var _studio: PortraitStudio
var _vorschau: FigurenVorschau

var _tab := &"ausruestung"
var _tab_buttons: Dictionary = {}
var _seiten: Dictionary = {}

# Ausrüstung
var _set_zeile: HBoxContainer
var _puppe: GridContainer
var _filter_leiste: HFlowContainer
var _raster: HFlowContainer
var _aktion_zeile: HBoxContainer
var _slot_filter := ALLE
var _auswahl: ItemInstance = null
var _auswahl_ausgeruestet := false

# Werte / Tränke / Materialien
var _stats_label: Label
var _stats_box: VBoxContainer
var _inventory_list: VBoxContainer
var _material_list: VBoxContainer

# Hover-Karte
var _popup_ebene: CanvasLayer
var _popup: Control = null
var _hover_item: ItemInstance = null
var _vergleich := true


func _ready() -> void:
	theme = UiTheme.get_theme()
	Music.play(&"menu")
	_selected = GameState.party[0]
	_build_layout()
	_refresh()
	UiTheme.focus_first_button(self)


## Zurück dorthin, wo das Inventar geöffnet wurde (Dungeon oder Menü).
func _go_back() -> void:
	var target := GameState.ui_return_scene
	GameState.ui_return_scene = ""
	if target.is_empty():
		target = MAIN_SCENE
	get_tree().change_scene_to_file(target)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Esc übernimmt die Bildschirm-Vorlage; die Inventar-Taste schließt auch.
	if event.is_action_pressed(&"open_inventory"):
		get_viewport().set_input_as_handled()
		_go_back()
	elif event.keycode == KEY_CTRL:
		_vergleich = not _vergleich
		_vergleich_aktualisieren()
		_popup_zeigen(_hover_item)


func _process(_delta: float) -> void:
	if _popup == null or not is_instance_valid(_popup):
		return
	# Karte neben der Maus, nie aus dem Bild.
	_popup.reset_size()  # ohne Container wächst die Karte sonst nie zurück
	var maus := get_viewport().get_mouse_position()
	var groesse := _popup.size
	var bild := get_viewport_rect().size
	var pos := maus + Vector2(18, 18)
	if pos.x + groesse.x > bild.x - 8:
		pos.x = maus.x - groesse.x - 18
	if pos.y + groesse.y > bild.y - 8:
		pos.y = bild.y - groesse.y - 8
	_popup.position = pos


# --- Aktionen -------------------------------------------------------------------

func _on_equip(item: ItemInstance) -> void:
	GameState.inventory.erase(item)
	# Kann mehrere Items verdrängen (z.B. Zweihänder ersetzt Waffe + Schild).
	for replaced in _selected.equip(item):
		GameState.inventory.append(replaced)
	_auswahl = item
	_auswahl_ausgeruestet = true
	Sfx.play(&"bestaetigen")
	_refresh()


func _on_unequip(slot: Enums.EquipSlot) -> void:
	var item := _selected.unequip(slot)
	if item != null:
		GameState.inventory.append(item)
		_auswahl = item
		_auswahl_ausgeruestet = false
	_refresh()


func _on_sell(item: ItemInstance) -> void:
	GameState.inventory.erase(item)
	GameState.gold += LootGenerator.sell_price(item)
	if _auswahl == item:
		_auswahl = null
	Sfx.play(&"gold")
	_refresh()


## QoL: der Stapel grauer Items geht mit einem Klick zu Gold.
func _on_sell_commons() -> void:
	var earned := 0
	for item in GameState.inventory.duplicate():
		if item.rarity == Enums.Rarity.COMMON:
			earned += LootGenerator.sell_price(item)
			GameState.inventory.erase(item)
	GameState.gold += earned
	if _auswahl != null and not _auswahl_ausgeruestet and not GameState.inventory.has(_auswahl):
		_auswahl = null
	_refresh()


# --- UI-Aufbau ------------------------------------------------------------------

func _build_layout() -> void:
	var ziel_text := Loc.pick("Dungeon", "Dungeon") if not GameState.ui_return_scene.is_empty() \
		else Loc.pick("Menü", "Menu")
	var b := Bildschirm.bauen(self, Loc.pick("Ausrüstung & Inventar", "Equipment & inventory"), &"lager",
		_go_back, ziel_text)
	b.zurueck.tooltip_text = Loc.pick("Zurück (Esc / %s)", "Back (Esc / %s)") % Settings.key_name(&"open_inventory")
	_vergleich_label = b.info("", Color(0.75, 0.88, 1.0))
	_gold_label = b.info("")
	_studio = PortraitStudio.new()
	add_child(_studio)
	_popup_ebene = CanvasLayer.new()
	_popup_ebene.layer = 80
	add_child(_popup_ebene)

	var kopf := HBoxContainer.new()
	kopf.add_theme_constant_override("separation", 16)
	b.inhalt.add_child(kopf)
	_char_bar = HBoxContainer.new()
	_char_bar.add_theme_constant_override("separation", 8)
	_char_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(_char_bar)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	kopf.add_child(tabs)
	for eintrag in [[&"ausruestung", Loc.pick("Ausrüstung", "Equipment")],
			[&"werte", Loc.pick("Werte & Statuspunkte", "Stats & points")],
			[&"traenke", Loc.pick("Tränke & Feldzauber", "Potions & field spells")],
			[&"material", Loc.pick("Materialien", "Materials")]]:
		var knopf := Button.new()
		knopf.text = eintrag[1]
		var id: StringName = eintrag[0]
		knopf.pressed.connect(func() -> void:
			_tab = id
			_popup_zeigen(null)
			_refresh())
		tabs.add_child(knopf)
		_tab_buttons[id] = knopf

	var seiten := Control.new()
	seiten.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.inhalt.add_child(seiten)
	_seiten[&"ausruestung"] = _baue_ausruestung_seite()
	_seiten[&"werte"] = _baue_werte_seite()
	_seiten[&"traenke"] = _baue_listen_seite(Loc.pick("Tränke & Feldzauber", "Potions & field spells"))
	_inventory_list = _seiten[&"traenke"].get_meta(&"liste")
	_seiten[&"material"] = _baue_listen_seite(Loc.pick("Materialien", "Materials"))
	_material_list = _seiten[&"material"].get_meta(&"liste")
	for id in _seiten:
		var seite: Control = _seiten[id]
		seite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		seiten.add_child(seite)


func _baue_ausruestung_seite() -> Control:
	var zeile := HBoxContainer.new()
	zeile.add_theme_constant_override("separation", 16)

	# Links: Figur, Waffenset, Slots.
	var links := VBoxContainer.new()
	links.add_theme_constant_override("separation", 8)
	var links_tafel := Bildschirm.tafel(links)
	zeile.add_child(links_tafel)
	var figur_zeile := HBoxContainer.new()
	figur_zeile.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_child(figur_zeile)
	_vorschau = FigurenVorschau.new(Vector2i(150, 170))
	figur_zeile.add_child(_vorschau)
	_set_zeile = HBoxContainer.new()
	_set_zeile.add_theme_constant_override("separation", 8)
	links.add_child(_set_zeile)
	_puppe = GridContainer.new()
	_puppe.columns = 3
	_puppe.add_theme_constant_override("h_separation", 8)
	_puppe.add_theme_constant_override("v_separation", 8)
	var puppe_zeile := HBoxContainer.new()
	puppe_zeile.alignment = BoxContainer.ALIGNMENT_CENTER
	puppe_zeile.add_child(_puppe)
	links.add_child(puppe_zeile)

	# Rechts: Filter, Raster, Aktionen.
	var rechts := VBoxContainer.new()
	rechts.add_theme_constant_override("separation", 8)
	var rechts_tafel := Bildschirm.tafel(rechts)
	rechts_tafel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zeile.add_child(rechts_tafel)
	_filter_leiste = HFlowContainer.new()
	_filter_leiste.add_theme_constant_override("h_separation", 6)
	_filter_leiste.add_theme_constant_override("v_separation", 6)
	rechts.add_child(_filter_leiste)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rechts.add_child(scroll)
	_raster = HFlowContainer.new()
	_raster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_raster.add_theme_constant_override("h_separation", 6)
	_raster.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_raster)
	_aktion_zeile = HBoxContainer.new()
	_aktion_zeile.add_theme_constant_override("separation", 8)
	rechts.add_child(_aktion_zeile)
	return zeile


func _baue_werte_seite() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 14)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_stats_label)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 2)
	box.add_child(_stats_box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return Bildschirm.tafel(scroll)


func _baue_listen_seite(_titel: String) -> Control:
	var teile := Bildschirm.scroll_liste(4)
	var tafel := Bildschirm.tafel(teile[0])
	tafel.set_meta(&"liste", teile[1])
	return tafel


# --- Aktualisieren --------------------------------------------------------------

func _refresh() -> void:
	_gold_label.text = "Gold: %d" % GameState.gold
	_vergleich_aktualisieren()
	for id in _seiten:
		_seiten[id].visible = id == _tab
		UiTheme.als_aktiv(_tab_buttons[id], id == _tab)

	for child in _char_bar.get_children():
		child.queue_free()
	for member in GameState.party:
		var button := Button.new()
		button.text = "%s (Lv. %d)" % [member.display_name, member.level]
		button.icon = _studio.textur(FigurenBau.schluessel_fuer(member),
			func() -> Node3D: return FigurenBau.held_aus(member))
		button.add_theme_constant_override("icon_max_width", 30)
		UiTheme.als_aktiv(button, member == _selected)
		button.pressed.connect(func() -> void:
			_selected = member
			if _auswahl_ausgeruestet:
				_auswahl = null
			_refresh())
		_char_bar.add_child(button)

	match _tab:
		&"ausruestung":
			_refresh_ausruestung()
		&"werte":
			_stats_label.text = _char_summary(_selected)
			_rebuild_stat_allocation()
		&"traenke":
			_refresh_traenke()
		&"material":
			_refresh_material()


func _vergleich_aktualisieren() -> void:
	_vergleich_label.text = Loc.pick("Vergleich: %s  [Strg]", "Compare: %s  [Ctrl]") \
		% (Loc.pick("an", "on") if _vergleich else Loc.pick("aus", "off"))


func _refresh_ausruestung() -> void:
	# Figur neu aufbauen: Waffenwechsel/Ablegen sieht man sofort am Helden.
	_vorschau.zeige(FigurenBau.held_aus(_selected))
	if _auswahl_ausgeruestet and not _selected.equipment.values().has(_auswahl):
		_auswahl = null
	if not _auswahl_ausgeruestet and _auswahl != null and not GameState.inventory.has(_auswahl):
		_auswahl = null

	# Waffenset-Umschalter: Haupt-/Nebenhand existieren doppelt (Set A/B).
	for child in _set_zeile.get_children():
		child.queue_free()
	var set_label := Label.new()
	set_label.text = Loc.pick("Waffenset %s", "Weapon set %s") % ("A" if _selected.active_weapon_set == 0 else "B")
	set_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_zeile.add_child(set_label)
	var set_swap := Button.new()
	var other_weapon: ItemInstance = _selected.weapon_set_b.get(Enums.EquipSlot.WEAPON)
	set_swap.text = Loc.pick("Wechseln » %s", "Swap » %s") \
		% (other_weapon.base.display_name if other_weapon != null else Loc.pick("(leer)", "(empty)"))
	set_swap.tooltip_text = Loc.pick(
		"Tauscht Haupt- und Nebenhand gegen das andere Set.\nZum Bestücken: wechseln, dann Waffen anlegen.\nIm Kampf ist der Wechsel eine freie Aktion.",
		"Swaps main and off hand with the other set.\nTo fill it: swap, then equip weapons.\nSwapping in battle is a free action.")
	set_swap.pressed.connect(func() -> void:
		_selected.swap_weapon_set()
		GameState.save_game()
		Sfx.play(&"bestaetigen")
		_refresh())
	_set_zeile.add_child(set_swap)

	# Slots um die Figur.
	for child in _puppe.get_children():
		child.queue_free()
	for eintrag in PUPPE:
		var slot: Enums.EquipSlot = eintrag[0]
		var item: ItemInstance = _selected.equipment.get(slot)
		var kachel := _kachel(item, ItemInfo.slot_name(slot), 72)
		var aktiv := _filter_fuer(slot) == _slot_filter
		if aktiv:
			_markieren(kachel, UiTheme.GOLD)
		if item != null and item == _auswahl:
			_markieren(kachel, Color.WHITE)
		kachel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_slot_filter = _filter_fuer(slot)
				_auswahl = item
				_auswahl_ausgeruestet = item != null
				if event.double_click and item != null:
					_on_unequip(slot)
					return
				_refresh())
		kachel.mouse_entered.connect(func() -> void: _popup_zeigen(item, true))
		kachel.mouse_exited.connect(func() -> void: _popup_zeigen(null))
		_puppe.add_child(kachel)

	# Filter: Alle + je Slot-Art (mit Anzahl).
	for child in _filter_leiste.get_children():
		child.queue_free()
	for filter in [ALLE, Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND, Enums.EquipSlot.HELMET,
			Enums.EquipSlot.ARMOR, Enums.EquipSlot.GLOVES, Enums.EquipSlot.BOOTS,
			Enums.EquipSlot.RING_1, Enums.EquipSlot.AMULET]:
		var anzahl := 0
		for item in GameState.inventory:
			if _passt(item, filter):
				anzahl += 1
		var knopf := Button.new()
		knopf.text = "%s (%d)" % [Loc.pick("Alle", "All") if filter == ALLE else ItemInfo.slot_name(filter), anzahl]
		UiTheme.als_aktiv(knopf, filter == _slot_filter)
		var f: int = filter
		knopf.pressed.connect(func() -> void:
			_slot_filter = f
			_refresh())
		_filter_leiste.add_child(knopf)

	# Taschen-Raster: beste Rarität zuerst, dann höheres Level.
	for child in _raster.get_children():
		child.queue_free()
	var liste: Array[ItemInstance] = []
	for item in GameState.inventory:
		if _passt(item, _slot_filter):
			liste.append(item)
	liste.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		if a.rarity != b.rarity:
			return a.rarity > b.rarity
		if a.item_level != b.item_level:
			return a.item_level > b.item_level
		return a.base.slot < b.base.slot)
	if liste.is_empty():
		var leer := Label.new()
		leer.text = Loc.pick("Nichts Passendes in den Taschen — Beute gibt es in den Dungeons, in der Schmiede und beim Händler.",
			"Nothing fitting in your bags — loot awaits in the dungeons, at the smithy and the merchant.")
		leer.modulate = Color(1, 1, 1, 0.5)
		leer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		leer.custom_minimum_size = Vector2(300, 0)
		_raster.add_child(leer)
	for item in liste:
		var kachel := _kachel(item, "", KACHEL)
		if item == _auswahl:
			_markieren(kachel, Color.WHITE)
		kachel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if event.double_click:
					_on_equip(item)
					return
				_auswahl = item
				_auswahl_ausgeruestet = false
				_refresh())
		kachel.mouse_entered.connect(func() -> void: _popup_zeigen(item))
		kachel.mouse_exited.connect(func() -> void: _popup_zeigen(null))
		_raster.add_child(kachel)

	_refresh_aktionen()


func _refresh_aktionen() -> void:
	for child in _aktion_zeile.get_children():
		child.queue_free()
	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.clip_text = true
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_aktion_zeile.add_child(info)
	if _auswahl == null:
		info.text = Loc.pick("Klick wählt aus · Doppelklick rüstet aus/legt ab · Maus drauf zeigt die Werte",
			"Click selects · double-click equips/unequips · hover shows the stats")
		info.modulate = Color(1, 1, 1, 0.55)
	else:
		info.text = _auswahl.get_display_name()
		info.add_theme_color_override("font_color", LootGenerator.RARITY_COLORS[_auswahl.rarity])
		if _auswahl_ausgeruestet:
			var ablegen := Button.new()
			ablegen.text = Loc.pick("Ablegen", "Unequip")
			var slot := _slot_von(_auswahl)
			ablegen.pressed.connect(func() -> void: _on_unequip(slot))
			_aktion_zeile.add_child(ablegen)
		else:
			var anlegen := Button.new()
			anlegen.text = Loc.pick("Ausrüsten (%s)", "Equip (%s)") % _selected.display_name
			var item := _auswahl
			anlegen.pressed.connect(func() -> void: _on_equip(item))
			_aktion_zeile.add_child(anlegen)
			var verkaufen := Button.new()
			verkaufen.text = Loc.pick("Verkaufen (%d G)", "Sell (%d G)") % LootGenerator.sell_price(item)
			verkaufen.pressed.connect(func() -> void: _on_sell(item))
			_aktion_zeile.add_child(verkaufen)
	var commons := 0
	for item in GameState.inventory:
		if item.rarity == Enums.Rarity.COMMON:
			commons += 1
	if commons > 0:
		var sell_commons := Button.new()
		sell_commons.text = Loc.pick("Gewöhnliche verkaufen (%d)", "Sell commons (%d)") % commons
		sell_commons.pressed.connect(_on_sell_commons)
		_aktion_zeile.add_child(sell_commons)


func _refresh_traenke() -> void:
	for child in _inventory_list.get_children():
		child.queue_free()
	_build_field_skill_section()
	var header := Label.new()
	header.text = Loc.pick("Tränke (Ziel: %s)", "Potions (target: %s)") % _selected.display_name
	header.add_theme_font_size_override("font_size", 16)
	_inventory_list.add_child(header)
	if GameState.consumables.is_empty():
		var leer := Label.new()
		leer.text = Loc.pick("Keine Tränke — der Händler verkauft sie, der Alchemist braut sie.",
			"No potions — the merchant sells them, the alchemist brews them.")
		leer.modulate = Color(1, 1, 1, 0.5)
		_inventory_list.add_child(leer)
	for id in GameState.consumables:
		var def := ConsumableLibrary.get_def(id)
		if def != null:
			_inventory_list.add_child(_make_consumable_row(def))


## Materialien nach Art gruppiert, mit Stufe.
func _refresh_material() -> void:
	for child in _material_list.get_children():
		child.queue_free()
	var arten := [[&"kraut", Loc.pick("Kräuter & Salze (Alchemie)", "Herbs & salts (alchemy)")],
		[&"erz", Loc.pick("Erz (Schmiede)", "Ore (smithy)")],
		[&"leder", Loc.pick("Leder (Schmiede)", "Leather (smithy)")],
		[&"kristall", Loc.pick("Kristall (Schmiede)", "Crystal (smithy)")],
		[&"rune", Loc.pick("Runen (Schmiede, garantieren Mindest-Rarität)", "Runes (smithy, guarantee a minimum rarity)")]]
	var irgendwas := false
	for art in arten:
		var zeilen: Array[String] = []
		for id in MaterialLibrary.ids_der_art(art[0]):
			var anzahl := GameState.material_count(id)
			if anzahl > 0:
				var stufe := "" if art[0] in [&"kraut", &"rune"] \
					else "  (%s)" % MaterialLibrary.stufen_name(MaterialLibrary.stufe(id))
				zeilen.append("%s ×%d%s" % [MaterialLibrary.display_name(id), anzahl, stufe])
		if zeilen.is_empty():
			continue
		irgendwas = true
		_material_list.add_child(Bildschirm.ueberschrift(art[1]))
		for text in zeilen:
			var zeile := Label.new()
			zeile.text = "   " + text
			_material_list.add_child(zeile)
	if not irgendwas:
		var leer := Label.new()
		leer.text = Loc.pick("Noch keine Materialien — Gegner und Truhen lassen sie fallen.",
			"No materials yet — enemies and chests drop them.")
		leer.modulate = Color(1, 1, 1, 0.5)
		_material_list.add_child(leer)


# --- Kacheln & Hover-Karte -----------------------------------------------------

## Kachel mit Item-Icon, Raritäts-Rahmen und Level (leer: Slot-Name).
func _kachel(item: ItemInstance, leer_text: String, groesse: int) -> PanelContainer:
	var kachel := PanelContainer.new()
	kachel.custom_minimum_size = Vector2(groesse, groesse)
	kachel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var stil := StyleBoxFlat.new()
	stil.set_corner_radius_all(8)
	stil.set_border_width_all(2)
	stil.set_content_margin_all(3)
	if item != null:
		var farbe: Color = LootGenerator.RARITY_COLORS[item.rarity]
		stil.bg_color = Color(farbe.r * 0.18, farbe.g * 0.18, farbe.b * 0.22, 0.95)
		stil.border_color = farbe
	else:
		stil.bg_color = Color(0.06, 0.06, 0.12, 0.8)
		stil.border_color = Color(1, 1, 1, 0.15)
	kachel.add_theme_stylebox_override("panel", stil)
	var lage := Control.new()
	lage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kachel.add_child(lage)
	if item != null:
		var bild := TextureRect.new()
		bild.texture = GegenstandIcons.textur(_studio, item.base)
		bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bild.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lage.add_child(bild)
		var stufe := Label.new()
		stufe.text = str(item.item_level)
		stufe.add_theme_font_size_override("font_size", 10)
		stufe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stufe.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		stufe.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		stufe.grow_vertical = Control.GROW_DIRECTION_BEGIN
		lage.add_child(stufe)
	else:
		var text := Label.new()
		text.text = leer_text
		text.add_theme_font_size_override("font_size", 10)
		text.modulate = Color(1, 1, 1, 0.4)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lage.add_child(text)
	return kachel


func _markieren(kachel: PanelContainer, farbe: Color) -> void:
	var stil := (kachel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	stil.border_color = farbe
	stil.set_border_width_all(3)
	kachel.add_theme_stylebox_override("panel", stil)


## Hover-Karte zeigen (null = verstecken). Ausgerüstete Items ohne Vergleich.
func _popup_zeigen(item: ItemInstance, ausgeruestet := false) -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null
	_hover_item = item if not ausgeruestet else null
	if item == null:
		return
	var gegenstueck: ItemInstance = null if ausgeruestet else _ausgeruestet_fuer(item)
	_popup = ItemInfo.karte(item, gegenstueck, _vergleich and not ausgeruestet)
	_popup_ebene.add_child(_popup)
	_process(0.0)


## Das Item, mit dem `item` verglichen wird: gleicher Slot beim Helden
## (Ringe: Ring 1, sonst Ring 2; leichte Waffen auch gegen die Nebenhand).
func _ausgeruestet_fuer(item: ItemInstance) -> ItemInstance:
	var slot := item.base.slot
	var gegen: ItemInstance = _selected.equipment.get(slot)
	if gegen == null and slot == Enums.EquipSlot.RING_1:
		gegen = _selected.equipment.get(Enums.EquipSlot.RING_2)
	if gegen == null and _slot_filter == Enums.EquipSlot.OFF_HAND:
		gegen = _selected.equipment.get(Enums.EquipSlot.OFF_HAND)
	return gegen


## Filter-Schlüssel eines Slots (beide Ringe teilen sich einen Filter).
static func _filter_fuer(slot: Enums.EquipSlot) -> int:
	return Enums.EquipSlot.RING_1 if slot == Enums.EquipSlot.RING_2 else slot


## Passt das Item in den gefilterten Slot? Leichte Waffen auch in die Nebenhand.
static func _passt(item: ItemInstance, filter: int) -> bool:
	if filter == ALLE:
		return true
	if filter == Enums.EquipSlot.OFF_HAND and item.base.light and item.base.slot == Enums.EquipSlot.WEAPON:
		return true
	return item.base.slot == filter


func _slot_von(item: ItemInstance) -> Enums.EquipSlot:
	for slot in _selected.equipment:
		if _selected.equipment[slot] == item:
			return slot
	return item.base.slot


## Statuspunkte verteilen: geteiltes StatAllocator-Widget (Planen »
## Bestätigen, Gedrückthalten = Auto-Klick) + Umskillen gegen Gold.
func _rebuild_stat_allocation() -> void:
	for child in _stats_box.get_children():
		child.queue_free()

	var alloc := StatAllocator.create(_selected)
	alloc.changed.connect(_refresh)
	_stats_box.add_child(alloc)

	# Umskillen gegen Gold: alle verteilten Punkte zurück in den freien Pool
	# (Attribute auf Basis 5) — für alle, die sich verskillt haben.
	var invested := 0
	for stat in StatBlock.STAT_NAMES:
		invested += maxi(0, _selected.stats.get(stat) - 5)
	if invested > 0:
		var cost := 100 + 20 * invested
		var respec_button := Button.new()
		respec_button.text = Loc.pick("Umskillen — %d Punkte zurück (%d Gold)",
			"Respec — refund %d points (%d gold)") % [invested, cost]
		respec_button.disabled = GameState.gold < cost
		respec_button.tooltip_text = Loc.pick(
			"Setzt alle Attribute auf die Basis 5 zurück;\ndie Punkte landen im freien Pool.",
			"Resets all attributes to the base of 5;\nthe points return to the free pool.")
		respec_button.pressed.connect(func() -> void:
			GameState.gold -= cost
			_selected.respec()
			GameState.save_game()
			Sfx.play(&"bestaetigen")
			_refresh())
		_stats_box.add_child(respec_button)


static func _char_summary(member: Combatant) -> String:
	return "Level %d (%d/%d XP)  ·  HP %d/%d  ·  MP %d/%d  ·  Rüstung %d  ·  Waffenschaden +%d\nSTR %d  INT %d  VIT %d  SPI %d  AGI %d  LCK %d" % [
		member.level, member.xp, member.xp_to_next(),
		member.hp, member.max_hp, member.mp, member.max_mp,
		member.total_armor(), member.weapon_damage(),
		member.stat(&"strength"), member.stat(&"intelligence"), member.stat(&"vitality"),
		member.stat(&"spirit"), member.stat(&"agility"), member.stat(&"luck"),
	]



# --- Tränke & Feldzauber (außerhalb des Kampfs) ---------------------------------

## Trank-Zeile: Benutzen wirkt auf den links ausgewählten Helden.
func _make_consumable_row(def: ConsumableDef) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var info := Label.new()
	info.text = "%s ×%d  —  %s" % [def.display_name,
		GameState.consumable_count(def.id), def.description]
	info.add_theme_font_size_override("font_size", 12)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(info)
	var use := Button.new()
	use.text = Loc.pick("Benutzen (%s)", "Use (%s)") % _selected.display_name
	var needs_dead := def.effect == Enums.ConsumableEffect.REVIVE
	use.disabled = _selected.is_alive() == needs_dead
	use.pressed.connect(_use_consumable.bind(def))
	row.add_child(use)
	return panel


func _use_consumable(def: ConsumableDef) -> void:
	var target := _selected
	match def.effect:
		Enums.ConsumableEffect.HEAL_HP:
			if not target.is_alive():
				return
			target.heal(def.heal_amount(target))
		Enums.ConsumableEffect.RESTORE_MP:
			if not target.is_alive():
				return
			target.mp = mini(target.max_mp, target.mp + def.mana_amount(target))
		Enums.ConsumableEffect.CURE_AILMENTS:
			if not target.is_alive():
				return
			for entry in target.statuses.duplicate():
				if entry["status"] in def.cures:
					target.statuses.erase(entry)
		Enums.ConsumableEffect.REVIVE:
			if target.is_alive():
				return
			target.hp = maxi(1, roundi(target.max_hp * def.potency / 100.0))
	GameState.consume(def.id)
	Sfx.play(&"trank")
	_refresh()


## Feldzauber: Heilung (Heilig), Kuren (Reinigung) und Wiederbelebung sind
## AUSSERHALB des Kampfs wirkbar (Prep vor Kämpfen) — Buffs bewusst nicht.
func _build_field_skill_section() -> void:
	var rows: Array[Control] = []
	for caster in GameState.party:
		if not caster.is_alive():
			continue
		for skill: Skill in caster.skills.slice(0, caster.skill_slots()):
			if not _is_field_skill(skill, caster):
				continue
			rows.append(_make_field_skill_row(caster, skill))
	if rows.is_empty():
		return
	var header := Label.new()
	header.text = Loc.pick("Feldzauber (Heilung/Kuren — Ziel: %s)",
		"Field spells (healing/cures — target: %s)") % _selected.display_name
	header.add_theme_font_size_override("font_size", 16)
	_inventory_list.add_child(header)
	for row in rows:
		_inventory_list.add_child(row)


## Feld-tauglich: gültig, freundliche Form UND heilende/kurierende Wirkung.
func _is_field_skill(skill: Skill, caster: Combatant) -> bool:
	if not skill.is_valid(caster):
		return false
	var form := skill.get_form()
	if form != Enums.SkillForm.ALLY and form != Enums.SkillForm.AURA \
			and form != Enums.SkillForm.SELF:
		return false
	var element := skill.get_element()
	if element != null and element.element == Enums.Element.HOLY:
		return true
	for effect in skill.get_effect_blocks():
		if effect.status == Enums.Status.CLEANSE or effect.status == Enums.Status.REVIVE:
			return true
	return false


func _make_field_skill_row(caster: Combatant, skill: Skill) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var cost := skill.get_mp_cost(caster)
	var info := Label.new()
	info.text = "%s: %s (%d MP)  ·  %d/%d MP" % [caster.display_name,
		skill.display_name, cost, caster.mp, caster.max_mp]
	info.add_theme_font_size_override("font_size", 12)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var cast := Button.new()
	cast.text = Loc.pick("Wirken", "Cast")
	cast.disabled = caster.mp < cost
	cast.pressed.connect(_cast_field_skill.bind(caster, skill))
	row.add_child(cast)
	return panel


func _cast_field_skill(caster: Combatant, skill: Skill) -> void:
	var cost := skill.get_mp_cost(caster)
	if caster.mp < cost or not caster.is_alive():
		Sfx.play(&"fehler")
		return
	caster.mp -= cost
	var targets: Array[Combatant] = []
	match skill.get_form():
		Enums.SkillForm.ALLY:
			targets = [_selected]
		Enums.SkillForm.AURA:
			targets = GameState.party.duplicate()
		Enums.SkillForm.SELF:
			targets = [caster]
	var element := skill.get_element()
	for target in targets:
		# Heilig-Heilung: dieselbe Formel wie im Kampf (friendly Holy » Heilung).
		if element != null and element.element == Enums.Element.HOLY and target.is_alive():
			for source in skill.get_sources():
				if source.source == Enums.SkillSource.SPELL:
					var form_block := skill.get_form_block()
					var power := form_block.power_multiplier if form_block != null else 1.0
					target.heal(roundi((caster.spell_damage()
						+ caster.stat(&"intelligence") * source.scaling_per_point)
						* power * source.power_multiplier))
		for effect in skill.get_effect_blocks():
			if effect.status == Enums.Status.CLEANSE and target.is_alive():
				for entry in target.statuses.duplicate():
					if entry["status"] in Battle.CURABLE_STATUSES:
						target.statuses.erase(entry)
			elif effect.status == Enums.Status.REVIVE and not target.is_alive():
				target.hp = maxi(1, roundi(target.max_hp * effect.potency / 100.0))
	Sfx.play(&"heilung")
	_refresh()
