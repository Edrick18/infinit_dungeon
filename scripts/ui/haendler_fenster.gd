class_name HaendlerFenster
extends RefCounted
## Fahrender Händler im Dungeon (DungeonEreignisse): Fenster mit seinen
## Angeboten. Jedes Angebot gilt einmal; bezahlt wird mit Materialien.
## Bedienung W/S + E (Fokus eingesperrt), Esc schließt (DungeonScene).

const META := &"haendler_fenster"


## Öffnet das Fenster. `genutzt` (Indizes, wird ergänzt) liegt im Run;
## `fertig` wird beim Schließen gerufen (true = alle Angebote getauscht).
static func oeffnen(parent: Node, angebote: Array, genutzt: Array, fertig: Callable) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 88
	layer.set_meta(META, true)
	parent.add_child(layer)
	# Merksatz: Anker VOR dem Einhängen setzen.
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.KERBE, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.theme = UiTheme.get_theme()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	layer.set_meta(&"box", box)
	layer.set_meta(&"angebote", angebote)
	layer.set_meta(&"genutzt", genutzt)
	layer.set_meta(&"fertig", fertig)
	_fuellen(layer, "")
	layer.set_meta(&"freigeben", UiTheme.fokus_einsperren(center))
	Sfx.play(&"menue")
	return layer


static func ist_offen(layer: CanvasLayer) -> bool:
	return layer != null and is_instance_valid(layer) and not layer.is_queued_for_deletion()


## Fenster schließen (auch per Esc aus der Dungeon-Szene).
static func schliessen(layer: CanvasLayer) -> void:
	if not ist_offen(layer):
		return
	var freigeben: Variant = layer.get_meta(&"freigeben", null)
	if freigeben is Callable and (freigeben as Callable).is_valid():
		(freigeben as Callable).call()
	layer.remove_meta(&"freigeben")
	var fertig: Callable = layer.get_meta(&"fertig")
	var angebote: Array = layer.get_meta(&"angebote")
	var genutzt: Array = layer.get_meta(&"genutzt")
	layer.queue_free()
	if fertig.is_valid():
		fertig.call(genutzt.size() >= angebote.size())


static func _fuellen(layer: CanvasLayer, ergebnis: String) -> void:
	var box: VBoxContainer = layer.get_meta(&"box")
	# Ausblenden statt aushängen: der gedrückte Knopf sendet gerade noch.
	for kind in box.get_children():
		kind.hide()
		kind.queue_free()
	var angebote: Array = layer.get_meta(&"angebote")
	var genutzt: Array = layer.get_meta(&"genutzt")
	var titel := Label.new()
	titel.text = Loc.pick("Fahrender Händler", "Travelling merchant")
	titel.add_theme_font_size_override("font_size", 22)
	titel.add_theme_color_override("font_color", UiTheme.GOLD)
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(titel)
	box.add_child(_zeile(Loc.pick("Jedes Angebot gilt einmal.", "Each offer can be taken once."), UiTheme.TEXT_DIM))
	if not ergebnis.is_empty():
		box.add_child(_zeile(ergebnis, UiTheme.WERKSTOFF))
	var erster: Button = null
	for i in angebote.size():
		var angebot: Dictionary = angebote[i]
		var knopf := Button.new()
		knopf.custom_minimum_size = Vector2(500, 38)
		knopf.text = DungeonEreignisse.angebot_text(angebot)
		knopf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		knopf.tooltip_text = knopf.text
		if i in genutzt:
			knopf.text = Loc.pick("Getauscht: ", "Traded: ") + knopf.text
			knopf.disabled = true
		elif not DungeonEreignisse.bezahlbar(angebot, GameState):
			knopf.disabled = true
		knopf.pressed.connect(func() -> void:
			if i in genutzt or not DungeonEreignisse.tauschen(angebot, GameState):
				Sfx.play(&"fehler")
				return
			genutzt.append(i)
			GameState.save_game()
			Sfx.play(&"gold")
			_fuellen(layer, Loc.pick("Erhalten: %d× %s", "Received: %d× %s")
				% [int(angebot["gibt"][1]), DungeonEreignisse.teil_name(angebot["gibt"][0])]))
		box.add_child(knopf)
		box.add_child(_zeile(_vorrat_text(angebot), UiTheme.TEXT_DIM))
		if erster == null and not knopf.disabled:
			erster = knopf
	var zu := Button.new()
	zu.text = Loc.pick("Schließen", "Close")
	zu.custom_minimum_size = Vector2(500, 38)
	zu.pressed.connect(func() -> void: schliessen(layer))
	box.add_child(zu)
	(erster if erster != null else zu).grab_focus.call_deferred()


## „Vorrat: 5× Stahlerz“ — was die Party von den Zutaten hat.
static func _vorrat_text(angebot: Dictionary) -> String:
	var teile: Array[String] = []
	for teil in angebot["nimmt"]:
		teile.append("%d× %s" % [GameState.material_count(teil[0]), DungeonEreignisse.teil_name(teil[0])])
	return Loc.pick("Vorrat: ", "In stock: ") + ", ".join(teile)


static func _zeile(text: String, farbe: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", farbe)
	label.add_theme_font_size_override("font_size", 13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(500, 0)
	return label
