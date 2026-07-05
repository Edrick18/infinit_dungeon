extends Control
## Taverne: Helden kostenlos anheuern, bis die Party voll ist (4).
## Jeder Rekrut startet identisch (Level 1, überall 5) — nur das gewählte
## Starter-Kit (Waffe + erster Skill) gibt eine Richtung vor.

const MAIN_SCENE := "res://scenes/main.tscn"

var _party_box: VBoxContainer
var _reserve_box: VBoxContainer
var _recruit_box: VBoxContainer
var _msg_label: Label


func _ready() -> void:
	theme = UiTheme.get_theme()
	_build_layout()
	_refresh()
	UiTheme.focus_first_button(self)


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1a1a2e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	root.offset_left = 40
	root.offset_right = -40
	root.offset_top = 24
	root.offset_bottom = -24
	add_child(root)

	# Stadt-Tabs: Taverne · Händler · Schmiede sind ein Ort.
	root.add_child(UiTheme.town_tabs(&"taverne"))

	var title := Label.new()
	title.text = Loc.pick("Taverne", "Tavern")
	title.add_theme_font_size_override("font_size", 36)
	root.add_child(title)

	var hint := Label.new()
	hint.text = Loc.pick("Anheuern ist kostenlos. Jeder Held startet gleich (Level 1, überall 5) — "
		+ "das Kit bestimmt nur Startwaffe und ersten Skill. Niemand stirbt dauerhaft. "
		+ "Maximal 4 sind aktiv — der Rest wartet auf der Bank (Platz für Co-op-Gäste!).",
		"Recruiting is free. Every hero starts the same (level 1, 5 everywhere) — "
		+ "the kit only sets the starting weapon and first skill. Nobody dies permanently. "
		+ "Up to 4 are active — the rest waits on the bench (room for co-op guests!).")
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	_party_box = _column(columns, Loc.pick("Deine Party", "Your party"), 8)
	_reserve_box = _column(columns, Loc.pick("Auf der Bank", "On the bench"), 8)
	_recruit_box = _column(columns, Loc.pick("Am Tresen", "At the bar"), 12)

	_msg_label = Label.new()
	_msg_label.modulate = Color(1.0, 0.9, 0.5)
	root.add_child(_msg_label)

	var back := Button.new()
	back.text = Loc.pick("Zurück zum Hub", "Back to hub")
	back.custom_minimum_size = Vector2(220, 44)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(MAIN_SCENE))
	root.add_child(back)


## Eine Spalte mit Überschrift; liefert die Inhalts-Box zurück.
func _column(columns: HBoxContainer, title_text: String, separation: int) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(panel)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", separation)
	scroll.add_child(box)
	return box


func _refresh() -> void:
	for box in [_party_box, _reserve_box, _recruit_box]:
		for child in box.get_children():
			child.queue_free()

	for member in GameState.party:
		_party_box.add_child(_member_row(member, true))

	if GameState.reserve.is_empty():
		var empty := Label.new()
		empty.text = Loc.pick("Niemand wartet — Party-Helden hier ablegen,\num Platz zu schaffen (z.B. für Co-op-Gäste).",
			"Nobody waiting — bench party heroes here\nto free up slots (e.g. for co-op guests).")
		empty.modulate = Color(1, 1, 1, 0.5)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_reserve_box.add_child(empty)
	for member in GameState.reserve:
		_reserve_box.add_child(_member_row(member, false))

	var names := HeroLibrary.available_names(GameState.party + GameState.reserve)
	if names.is_empty():
		var empty := Label.new()
		empty.text = Loc.pick("Alle Helden sind angeheuert.", "All heroes are hired.")
		empty.modulate = Color(1, 1, 1, 0.6)
		_recruit_box.add_child(empty)
	for hero_name in names:
		_recruit_box.add_child(_recruit_row(hero_name))


func _member_row(member: Combatant, in_party: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_portrait(member.sprite))
	var label := Label.new()
	label.text = Loc.pick("%s — Level %d   HP %d/%d", "%s — level %d   HP %d/%d") % [member.display_name, member.level,
		member.hp, member.max_hp]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	if member.has_meta(&"guest_peer"):
		var guest_tag := Label.new()
		guest_tag.text = Loc.pick("Co-op-Gast", "co-op guest")
		guest_tag.modulate = Color(0.7, 0.85, 1.0)
		row.add_child(guest_tag)
		return row

	var swap := Button.new()
	if in_party:
		swap.text = Loc.pick("Auf die Bank", "To the bench")
		swap.disabled = not _can_bench(member)
		swap.pressed.connect(func() -> void:
			if GameState.bench_hero(member):
				GameState.save_game()
				Sfx.play(&"bestaetigen")
				_refresh())
	else:
		swap.text = Loc.pick("In die Party", "Into the party")
		swap.disabled = GameState.party.size() >= HeroLibrary.MAX_PARTY_SIZE
		swap.pressed.connect(func() -> void:
			if GameState.activate_hero(member):
				GameState.save_game()
				Sfx.play(&"bestaetigen")
				_refresh())
	row.add_child(swap)
	return row


## Der letzte eigene Held ist nicht ablegbar (Party darf nie leer sein).
func _can_bench(member: Combatant) -> bool:
	var own_count := 0
	for hero in GameState.party:
		if not hero.has_meta(&"guest_peer"):
			own_count += 1
	return own_count > 1 and not member.has_meta(&"guest_peer")


func _recruit_row(hero_name: String) -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.add_child(_portrait(SpriteLib.hero(hero_name)))
	var name_label := Label.new()
	name_label.text = hero_name
	name_label.add_theme_font_size_override("font_size", 20)
	header.add_child(name_label)
	box.add_child(header)

	var kit_select := OptionButton.new()
	for kit_id in HeroLibrary.STARTER_KITS:
		var kit: Dictionary = HeroLibrary.STARTER_KITS[kit_id]
		kit_select.add_item("%s — %s" % [kit["name"], kit["desc"]])
		kit_select.set_item_metadata(kit_select.item_count - 1, kit_id)
	box.add_child(kit_select)

	var hire := Button.new()
	var to_bench := GameState.party.size() >= HeroLibrary.MAX_PARTY_SIZE
	hire.text = Loc.pick("Anheuern (kostenlos)", "Recruit (free)") \
		+ (Loc.pick(" » Bank", " » bench") if to_bench else "")
	hire.pressed.connect(func() -> void:
		var kit_id: StringName = kit_select.get_item_metadata(kit_select.selected)
		if GameState.recruit(hero_name, kit_id):
			GameState.save_game()
			Sfx.play(&"bestaetigen")
			_msg_label.text = Loc.pick("%s schließt sich der Party an!", "%s joins the party!") % hero_name \
				if not to_bench else Loc.pick("%s wartet auf der Bank.", "%s waits on the bench.") % hero_name
			_refresh())
	box.add_child(hire)
	return panel


func _portrait(texture: Texture2D) -> Control:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(48, 48)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect
