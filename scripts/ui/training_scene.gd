extends Control
## Waffen-Training (DQ9-Stil): Skillpunkte (+3 pro Level-Up) pro Held in
## Waffengattungen investieren — Schwellen schalten Technik-Bausteine für
## die Skill-Werkstatt frei. Investieren ist unumkehrbar (wie in DQ9).

const WORKSHOP_SCENE := "res://scenes/workshop/skill_workshop.tscn"

const TREES: Array[StringName] = [&"schwert", &"dolch", &"axt", &"stumpf",
	&"bogen", &"armbrust", &"stab", &"schild"]

var _selected: Combatant = null
var _char_bar: HBoxContainer
var _points_label: Label
var _tree_list: VBoxContainer


func _ready() -> void:
	theme = UiTheme.get_theme()
	_selected = GameState.party[0] if not GameState.party.is_empty() else null
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
	root.add_theme_constant_override("separation", 10)
	root.offset_left = 40
	root.offset_right = -40
	root.offset_top = 20
	root.offset_bottom = -20
	add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	var title := Label.new()
	title.text = Loc.pick("Waffen-Training", "Weapon training")
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 18)
	head.add_child(_points_label)
	var back := Button.new()
	back.text = Loc.pick("Zurück zur Werkstatt", "Back to workshop")
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(WORKSHOP_SCENE))
	head.add_child(back)

	var hint := Label.new()
	hint.text = Loc.pick("Jeder Level-Up gibt %d Skillpunkte. Investiere sie in Waffengattungen, um Technik-Bausteine freizuschalten (unumkehrbar). Techniken sind nur mit passender geführter Waffe einsetzbar — Schild zählt über die Nebenhand, Stab-Techniken verstärken Zauber.",
		"Every level-up grants %d skill points. Invest them into weapon families to unlock technique blocks (irreversible). Techniques only work with the matching wielded weapon — shields count via the off-hand, staff techniques empower spells.") \
		% Combatant.SKILL_POINTS_PER_LEVEL
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	_char_bar = HBoxContainer.new()
	_char_bar.add_theme_constant_override("separation", 8)
	root.add_child(_char_bar)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_tree_list = VBoxContainer.new()
	_tree_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_tree_list)


func _refresh() -> void:
	for child in _char_bar.get_children():
		child.queue_free()
	for member in GameState.party:
		if member.has_meta(&"guest_peer"):
			continue  # Gast-Helden trainiert ihr Besitzer selbst
		var button := Button.new()
		button.text = "%s (Lv %d, %d P.)" % [member.display_name, member.level,
			member.skill_points]
		button.disabled = member == _selected
		button.pressed.connect(func() -> void:
			_selected = member
			_refresh())
		_char_bar.add_child(button)

	for child in _tree_list.get_children():
		child.queue_free()
	if _selected == null:
		return
	_points_label.text = Loc.pick("Freie Punkte: %d", "Free points: %d") \
		% _selected.skill_points
	for family in TREES:
		_tree_list.add_child(_tree_row(family))


func _tree_row(family: StringName) -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var name_label := Label.new()
	var invested := _selected.invested(family)
	name_label.text = "%s — %d" % [BlockLibrary.family_label(family), invested]
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _selected.wields_family(family):
		name_label.text += Loc.pick("   (geführt)", "   (wielded)")
		name_label.modulate = Color(0.7, 1.0, 0.75)
	head.add_child(name_label)
	var invest := Button.new()
	invest.text = Loc.pick("+1 Punkt", "+1 point")
	invest.disabled = _selected.skill_points <= 0
	invest.pressed.connect(func() -> void:
		if _selected.invest_point(family):
			GameState.save_game()
			Sfx.play(&"bestaetigen")
			_refresh())
	head.add_child(invest)
	var invest_five := Button.new()
	invest_five.text = "+5"
	invest_five.disabled = _selected.skill_points < 5
	invest_five.pressed.connect(func() -> void:
		if _selected.invest_point(family, 5):
			GameState.save_game()
			Sfx.play(&"bestaetigen")
			_refresh())
	head.add_child(invest_five)

	# Die Schwellen des Baums: erreichte Techniken hell, kommende gedimmt.
	var unlocks := Label.new()
	var parts: Array[String] = []
	for block in BlockLibrary.tree_blocks(family):
		var reached: bool = invested >= block.tree_points \
			or block.id in GameState.researched
		parts.append("%s%d: %s%s" % ["[OK] " if reached else "", block.tree_points,
			block.display_name, "" if reached else " (gesperrt)" if Loc.language == "de" else " (locked)"])
	unlocks.text = "   ·   ".join(parts)
	unlocks.add_theme_font_size_override("font_size", 12)
	unlocks.modulate = Color(0.75, 0.9, 1.0, 0.9)
	unlocks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(unlocks)
	return panel
