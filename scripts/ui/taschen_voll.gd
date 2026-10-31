class_name TaschenVoll
extends RefCounted
## Taschen voll (Lutz 2026-10-31, Taschenlimit GameState.TASCHEN_LIMIT):
## passt neue Beute nicht mehr in die Taschen, wartet sie in
## GameState.beute_warteliste. Dieses Fenster zeigt sie und bietet drei Wege:
##  • Gewöhnliche verkaufen — danach rückt die Warteliste nach, soweit Platz ist.
##  • Inventar aufräumen — die Warteliste bleibt (gespeichert); das Fenster
##    kommt bei der nächsten Gelegenheit wieder, solange etwas wartet.
##  • Liegen lassen — die wartenden Gegenstände verfallen.
## Gold und Materialien kommen immer an. Im Koop ist das Fenster nur lokal.

const INVENTORY_SCENE := "res://scenes/inventory/inventory_scene.tscn"
## So viele wartende Gegenstände werden einzeln genannt.
const MAX_ZEILEN := 10
const META := &"taschen_voll"


## Zeigt das Fenster, wenn Beute wartet (sonst null). Ist es schon offen,
## wird es nur neu befüllt. `aufraeumen` öffnet das Inventar (der Aufrufer
## merkt sich vorher, wohin es zurückgeht — siehe inventar_oeffnen).
static func pruefen(parent: Node, aufraeumen: Callable) -> CanvasLayer:
	if GameState.beute_warteliste.is_empty() or not parent.is_inside_tree():
		return null
	for kind in parent.get_children():
		if kind is CanvasLayer and kind.has_meta(META) and not kind.is_queued_for_deletion():
			_fuellen(kind, "")
			return kind
	var layer := CanvasLayer.new()
	layer.layer = 88
	layer.set_meta(META, true)
	parent.add_child(layer)
	# Merksatz: Anker VOR dem Einhängen setzen.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.theme = UiTheme.get_theme()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	layer.set_meta(&"box", box)
	layer.set_meta(&"aufraeumen", aufraeumen)
	_fuellen(layer, "")
	layer.set_meta(&"freigeben", UiTheme.fokus_einsperren(center))
	Sfx.play(&"menue")
	return layer


## Inventar öffnen; „Zurück“ führt nach `zurueck` (Szenenpfad).
static func inventar_oeffnen(baum: SceneTree, zurueck: String) -> void:
	GameState.ui_return_scene = zurueck
	baum.change_scene_to_file(INVENTORY_SCENE)


## Inhalt (neu) aufbauen. `ergebnis` = sachliche Zeile nach dem Verkaufen.
static func _fuellen(layer: CanvasLayer, ergebnis: String) -> void:
	var box: VBoxContainer = layer.get_meta(&"box")
	# Ausblenden statt aushängen: der gedrückte Knopf sendet gerade noch.
	for kind in box.get_children():
		kind.hide()
		kind.queue_free()
	var wartend := GameState.beute_warteliste
	var titel := Label.new()
	titel.text = Loc.pick("Taschen voll", "Bags full") if not wartend.is_empty() \
		else Loc.pick("Taschen", "Bags")
	titel.add_theme_font_size_override("font_size", 22)
	titel.add_theme_color_override("font_color", UiTheme.GOLD)
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(titel)
	if not ergebnis.is_empty():
		box.add_child(_zeile(ergebnis, Color(0.6, 0.95, 0.7)))
	var stand := _zeile(Loc.pick("Taschen: %d/%d", "Bags: %d/%d")
		% [GameState.inventory.size(), GameState.TASCHEN_LIMIT], UiTheme.TEXT)
	box.add_child(stand)
	if wartend.is_empty():
		box.add_child(_zeile(Loc.pick("Alle wartenden Gegenstände sind in den Taschen.",
			"All waiting items are in the bags."), UiTheme.TEXT))
		var ok := _knopf("OK")
		ok.pressed.connect(func() -> void: _schliessen(layer))
		box.add_child(ok)
		ok.grab_focus.call_deferred()
		return
	box.add_child(_zeile(Loc.pick("Diese Gegenstände passen nicht mehr hinein (%d):",
		"These items no longer fit (%d):") % wartend.size(), UiTheme.TEXT))
	for i in mini(wartend.size(), MAX_ZEILEN):
		var item: ItemInstance = wartend[i]
		var zeile := _zeile("   %s — %s, Lv %d" % [item.get_display_name(),
			LootGenerator.rarity_name(item.rarity), item.item_level],
			LootGenerator.RARITY_COLORS[item.rarity])
		zeile.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(zeile)
	if wartend.size() > MAX_ZEILEN:
		box.add_child(_zeile(Loc.pick("   +%d weitere", "   +%d more") % (wartend.size() - MAX_ZEILEN),
			UiTheme.TEXT_DIM))
	box.add_child(_zeile(Loc.pick("Gold und Materialien sind angekommen.",
		"Gold and materials were received."), UiTheme.TEXT_DIM))

	var knoepfe := VBoxContainer.new()
	knoepfe.add_theme_constant_override("separation", 6)
	box.add_child(knoepfe)
	var wert := GameState.gewoehnliche_wert()
	var verkaufen := _knopf(Loc.pick("Gewöhnliche verkaufen (%d Teile, +%d Gold)",
		"Sell commons (%d items, +%d gold)") % [int(wert["anzahl"]), int(wert["gold"])])
	verkaufen.disabled = int(wert["anzahl"]) == 0
	verkaufen.pressed.connect(func() -> void:
		var verkauft := GameState.gewoehnliche_verkaufen()
		var aufgenommen := GameState.warteliste_nachruecken()
		GameState.save_game()
		Sfx.play(&"gold")
		_fuellen(layer, Loc.pick("Verkauft: %d Teile, +%d Gold. Aufgenommen: %d.",
			"Sold: %d items, +%d gold. Taken in: %d.")
			% [int(verkauft["anzahl"]), int(verkauft["gold"]), aufgenommen]))
	knoepfe.add_child(verkaufen)
	var aufraeumen := _knopf(Loc.pick("Inventar aufräumen", "Tidy up inventory"))
	aufraeumen.pressed.connect(func() -> void:
		var weiter: Callable = layer.get_meta(&"aufraeumen")
		GameState.save_game()
		_schliessen(layer)
		if weiter.is_valid():
			weiter.call())
	knoepfe.add_child(aufraeumen)
	var liegen := _knopf(Loc.pick("Liegen lassen (%d Teile verfallen)", "Leave behind (%d items are lost)")
		% wartend.size())
	liegen.pressed.connect(func() -> void:
		GameState.warteliste_verwerfen()
		GameState.save_game()
		Sfx.play(&"bestaetigen")
		_schliessen(layer))
	knoepfe.add_child(liegen)
	(verkaufen if not verkaufen.disabled else aufraeumen).grab_focus.call_deferred()


static func _schliessen(layer: CanvasLayer) -> void:
	var freigeben: Variant = layer.get_meta(&"freigeben", null)
	if freigeben is Callable and (freigeben as Callable).is_valid():
		(freigeben as Callable).call()
	layer.remove_meta(&"freigeben")
	layer.queue_free()


static func _zeile(text: String, farbe: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", farbe)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(460, 0)
	return label


static func _knopf(text: String) -> Button:
	var knopf := Button.new()
	knopf.text = text
	knopf.custom_minimum_size = Vector2(320, 40)
	return knopf
