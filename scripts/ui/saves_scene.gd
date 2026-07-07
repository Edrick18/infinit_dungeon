extends Control
## Spielstände: 5 Slots zum Speichern, Laden, Neustarten und Löschen.
## Slot 1 ist der klassische Spielstand (alte Saves laufen dort weiter);
## der aktive Slot wird in den Einstellungen gemerkt.

const MAIN_SCENE := "res://scenes/main.tscn"

var _slot_list: VBoxContainer
## Zerstörerische Aktionen brauchen einen zweiten Klick ("Wirklich?").
var _pending_confirm := ""


func _ready() -> void:
	theme = UiTheme.get_theme()
	_build_layout()
	_refresh()
	UiTheme.focus_first_button(self)


func _build_layout() -> void:
	add_child(UiTheme.make_background())

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	root.offset_left = 60
	root.offset_right = -60
	root.offset_top = 24
	root.offset_bottom = -24
	add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	var title := Label.new()
	title.text = Loc.pick("Spielstände", "Save games")
	title.add_theme_font_size_override("font_size", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back := Button.new()
	back.text = Loc.pick("Zurück zum Menü", "Back to menu")
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(MAIN_SCENE))
	head.add_child(back)

	var hint := Label.new()
	hint.text = Loc.pick("Der aktive Slot wird beim Spielen automatisch gesichert. Laden wechselt den Slot dauerhaft.",
		"The active slot autosaves while you play. Loading switches the slot permanently.")
	hint.modulate = Color(1, 1, 1, 0.55)
	root.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_slot_list = VBoxContainer.new()
	_slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_slot_list)


func _refresh() -> void:
	for child in _slot_list.get_children():
		child.queue_free()
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		_slot_list.add_child(_slot_row(slot))


func _slot_row(slot: int) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var is_active := slot == SaveManager.active_slot
	var name_label := Label.new()
	name_label.text = Loc.pick("Slot %d", "Slot %d") % slot \
		+ (Loc.pick("   — AKTIV", "   — ACTIVE") if is_active else "")
	name_label.add_theme_font_size_override("font_size", 18)
	if is_active:
		name_label.modulate = Color(0.55, 1.0, 0.55)
	info.add_child(name_label)

	var data := SaveManager.slot_info(slot)
	var detail := Label.new()
	if data.is_empty():
		detail.text = Loc.pick("— leer —", "— empty —")
		detail.modulate = Color(1, 1, 1, 0.4)
	else:
		var parts: Array[String] = []
		if data["heroes"] != "":
			parts.append(String(data["heroes"]))
		if int(data["reserve_count"]) > 0:
			parts.append(Loc.pick("+%d auf der Bank", "+%d on the bench") % int(data["reserve_count"]))
		parts.append("%d Gold" % int(data["gold"]))
		parts.append(Loc.pick("%d Karten", "%d maps") % int(data["cards"]))
		if data["saved_at"] != "":
			parts.append(String(data["saved_at"]))
		detail.text = "   ·   ".join(parts)
		detail.modulate = Color(1, 1, 1, 0.7)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail)

	var exists := not data.is_empty()
	# Während einer Co-op-Session (Host UND Gast) ist der Slot-Wechsel
	# gesperrt — er würde Party, Gast-Helden und XP-Heimnahme zerreißen.
	var locked := Net.is_online()
	if exists and not is_active:
		var load_button := Button.new()
		load_button.text = Loc.pick("Laden", "Load") if not locked \
			else Loc.pick("Gesperrt (Co-op)", "Locked (co-op)")
		load_button.disabled = locked
		load_button.pressed.connect(func() -> void:
			GameState.switch_to_slot(slot)
			Sfx.play(&"bestaetigen")
			get_tree().change_scene_to_file(MAIN_SCENE))
		row.add_child(load_button)

	if not exists:
		var new_button := Button.new()
		new_button.text = Loc.pick("Neues Spiel", "New game") if not locked \
			else Loc.pick("Gesperrt (Co-op)", "Locked (co-op)")
		new_button.disabled = locked
		new_button.pressed.connect(func() -> void:
			GameState.switch_to_slot(slot)
			Sfx.play(&"bestaetigen")
			get_tree().change_scene_to_file(MAIN_SCENE))
		row.add_child(new_button)

	if not is_active:
		var copy_button := Button.new()
		var copy_key := "copy_%d" % slot
		copy_button.text = Loc.pick("Wirklich überschreiben?", "Really overwrite?") \
			if _pending_confirm == copy_key and exists \
			else Loc.pick("Hierher speichern", "Save here")
		copy_button.pressed.connect(func() -> void:
			if exists and _pending_confirm != copy_key:
				_pending_confirm = copy_key
				_refresh()
				return
			_pending_confirm = ""
			# Aktuellen Stand in diesen Slot legen und ihn aktiv machen.
			GameState.switch_to_active_copy(slot)
			Sfx.play(&"bestaetigen")
			_refresh())
		row.add_child(copy_button)

	if exists and not is_active:
		var delete_button := Button.new()
		var delete_key := "delete_%d" % slot
		delete_button.text = Loc.pick("Wirklich löschen?", "Really delete?") \
			if _pending_confirm == delete_key else Loc.pick("Löschen", "Delete")
		delete_button.pressed.connect(func() -> void:
			if _pending_confirm != delete_key:
				_pending_confirm = delete_key
				_refresh()
				return
			_pending_confirm = ""
			SaveManager.delete_save(SaveManager.path_for_slot(slot))
			Sfx.play(&"fehler")
			_refresh())
		row.add_child(delete_button)

	return panel
