extends Control
## Taverne: Helden kostenlos anheuern, bis die Party voll ist (4).
## Jeder Rekrut startet identisch (Level 1, überall 5) — nur das gewählte
## Starter-Kit (Waffe + erster Skill) gibt eine Richtung vor.

const MAIN_SCENE := "res://scenes/main.tscn"

var _party_box: VBoxContainer
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

	var title := Label.new()
	title.text = Loc.pick("Taverne", "Tavern")
	title.add_theme_font_size_override("font_size", 36)
	root.add_child(title)

	var hint := Label.new()
	hint.text = Loc.pick("Anheuern ist kostenlos. Jeder Held startet gleich (Level 1, überall 5) — "
		+ "das Kit bestimmt nur Startwaffe und ersten Skill. Niemand stirbt dauerhaft.",
		"Recruiting is free. Every hero starts the same (level 1, 5 everywhere) — "
		+ "the kit only sets the starting weapon and first skill. Nobody dies permanently.")
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	var party_panel := VBoxContainer.new()
	party_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(party_panel)
	var party_title := Label.new()
	party_title.text = Loc.pick("Deine Party", "Your party")
	party_title.add_theme_font_size_override("font_size", 22)
	party_panel.add_child(party_title)
	_party_box = VBoxContainer.new()
	_party_box.add_theme_constant_override("separation", 8)
	party_panel.add_child(_party_box)

	var recruit_panel := VBoxContainer.new()
	recruit_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(recruit_panel)
	var recruit_title := Label.new()
	recruit_title.text = Loc.pick("Am Tresen", "At the bar")
	recruit_title.add_theme_font_size_override("font_size", 22)
	recruit_panel.add_child(recruit_title)
	_recruit_box = VBoxContainer.new()
	_recruit_box.add_theme_constant_override("separation", 12)
	recruit_panel.add_child(_recruit_box)

	_msg_label = Label.new()
	_msg_label.modulate = Color(1.0, 0.9, 0.5)
	root.add_child(_msg_label)

	var back := Button.new()
	back.text = Loc.pick("Zurück zum Hub", "Back to hub")
	back.custom_minimum_size = Vector2(220, 44)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(MAIN_SCENE))
	root.add_child(back)


func _refresh() -> void:
	for child in _party_box.get_children():
		child.queue_free()
	for child in _recruit_box.get_children():
		child.queue_free()

	for member in GameState.party:
		_party_box.add_child(_member_row(member))

	var free_slots := HeroLibrary.MAX_PARTY_SIZE - GameState.party.size()
	if free_slots <= 0:
		var full := Label.new()
		full.text = Loc.pick("Die Party ist voll (%d/%d).", "The party is full (%d/%d).") % [GameState.party.size(),
			HeroLibrary.MAX_PARTY_SIZE]
		full.modulate = Color(1, 1, 1, 0.6)
		_recruit_box.add_child(full)
		return
	for hero_name in HeroLibrary.available_names(GameState.party):
		_recruit_box.add_child(_recruit_row(hero_name))


func _member_row(member: Combatant) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_portrait(member.sprite))
	var label := Label.new()
	label.text = Loc.pick("%s — Level %d   HP %d/%d", "%s — level %d   HP %d/%d") % [member.display_name, member.level,
		member.hp, member.max_hp]
	row.add_child(label)
	return row


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
	hire.text = Loc.pick("Anheuern (kostenlos)", "Recruit (free)")
	hire.pressed.connect(func() -> void:
		var kit_id: StringName = kit_select.get_item_metadata(kit_select.selected)
		if GameState.recruit(hero_name, kit_id):
			GameState.save_game()
			Sfx.play(&"bestaetigen")
			_msg_label.text = Loc.pick("%s schließt sich der Party an!", "%s joins the party!") % hero_name
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
