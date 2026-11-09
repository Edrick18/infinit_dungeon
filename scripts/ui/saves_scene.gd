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
	Music.play(&"menu")
	_build_layout()
	_refresh()
	UiTheme.focus_first_button(self)


## Zurück dorthin, wo die Spielstände geöffnet wurden (Titelbildschirm oder Hub).
func _zurueck() -> void:
	var ziel := GameState.ui_return_scene
	GameState.ui_return_scene = ""
	get_tree().change_scene_to_file(MAIN_SCENE if ziel.is_empty() else ziel)


## Laden oder neues Spiel: immer in den Hub (dort ggf. die Heldenerstellung).
func _in_den_hub() -> void:
	GameState.ui_return_scene = ""
	get_tree().change_scene_to_file(MAIN_SCENE)


func _build_layout() -> void:
	var b := Bildschirm.bauen(self, Loc.pick("Spielstände", "Save games"), &"lager",
		_zurueck, Loc.pick("Menü", "Menu") if GameState.ui_return_scene.is_empty() \
			else Loc.pick("Hauptmenü", "Main menu"))
	b.setze_untertitel(Loc.pick("Der aktive Slot wird beim Spielen automatisch gesichert. Laden wechselt den Slot dauerhaft. „Hierher speichern“ kopiert den Stand in diesen Slot und spielt dort weiter.",
		"The active slot autosaves while you play. Loading switches the slot permanently. 'Save here' copies the game into this slot and continues there."))
	var teile := Bildschirm.scroll_liste(8)
	b.inhalt.add_child(teile[0])
	_slot_list = teile[1]


func _refresh() -> void:
	UiTheme.fokus_retten(self)  # Neuaufbau: Tastatur-Fokus bleibt an seinem Platz
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
		name_label.modulate = UiTheme.GUT
	info.add_child(name_label)

	var data := SaveManager.slot_info(slot)
	# Datei vorhanden, aber weder sie noch eine Sicherung lesbar: nie als
	# leer zeigen (sonst überschreibt „Neues Spiel“ sie ohne Rückfrage).
	var defekt := bool(data.get("defekt", false))
	var detail := Label.new()
	if defekt:
		detail.text = Loc.pick("— Datei nicht lesbar, keine Sicherung —",
			"— file unreadable, no backup —")
		detail.modulate = UiTheme.SCHLECHT
	elif data.is_empty():
		detail.text = Loc.pick("— leer —", "— empty —")
		detail.modulate = UiTheme.BLASS
	else:
		var parts: Array[String] = []
		if data["heroes"] != "":
			parts.append(String(data["heroes"]))
		if int(data["reserve_count"]) > 0:
			parts.append(Loc.pick("+%d auf der Bank", "+%d on the bench") % int(data["reserve_count"]))
		parts.append("%d Gold" % int(data["gold"]))
		parts.append(Loc.pick("%d Karten", "%d maps") % int(data["cards"]))
		if data["saved_at"] != "":
			parts.append(Loc.pick("zuletzt gespielt %s", "last played %s") % String(data["saved_at"]))
		var minuten := int(float(data["playtime_s"]) / 60.0)
		parts.append(Loc.pick("Spielzeit %d Std. %02d Min.", "playtime %d h %02d min") % [minuten / 60, minuten % 60])
		if bool(data.get("sicherung", false)):
			parts.append(Loc.pick("aus der Sicherung (Datei nicht lesbar)",
				"from the backup (file unreadable)"))
		detail.text = "   ·   ".join(parts)
		detail.modulate = UiTheme.HALB
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail)

	var exists := not data.is_empty()
	# Während einer Co-op-Session (Host UND Gast) ist der Slot-Wechsel
	# gesperrt — er würde Party, Gast-Helden und XP-Heimnahme zerreißen.
	var locked := Net.is_online()
	if exists and not is_active and not defekt:
		var load_button := Button.new()
		load_button.text = Loc.pick("Laden", "Load") if not locked \
			else Loc.pick("Gesperrt (Co-op)", "Locked (co-op)")
		load_button.disabled = locked
		load_button.pressed.connect(func() -> void:
			GameState.switch_to_slot(slot)
			Sfx.play(&"bestaetigen")
			_in_den_hub())
		row.add_child(load_button)

	if not exists:
		var new_button := Button.new()
		new_button.text = Loc.pick("Neues Spiel", "New game") if not locked \
			else Loc.pick("Gesperrt (Co-op)", "Locked (co-op)")
		new_button.disabled = locked
		new_button.pressed.connect(func() -> void:
			GameState.switch_to_slot(slot)
			Sfx.play(&"bestaetigen")
			_in_den_hub())
		row.add_child(new_button)

	# Ohne Helden (Titelbildschirm vor der Heldenerstellung) gibt es nichts zu kopieren.
	if not is_active and not GameState.party.is_empty():
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

	# Ein unlesbarer Slot lässt sich auch als aktiver löschen (er ist nicht geladen).
	if exists and (not is_active or defekt):
		var delete_button := Button.new()
		var delete_key := "delete_%d" % slot
		delete_button.text = Loc.pick("Wirklich löschen?", "Really delete?") \
			if _pending_confirm == delete_key else Loc.pick("Löschen", "Delete")
		UiTheme.gefahr(delete_button)  # Gefahr-Knopf wie im Kartenlager
		delete_button.pressed.connect(func() -> void:
			if _pending_confirm != delete_key:
				_pending_confirm = delete_key
				_refresh()
				return
			_pending_confirm = ""
			SaveManager.delete_save(SaveManager.path_for_slot(slot))
			if slot == SaveManager.active_slot:
				GameState.slot_gesperrt = false  # leer: ab jetzt wird wieder gespeichert
			Sfx.play(&"fehler")
			_refresh())
		row.add_child(delete_button)

	return panel
