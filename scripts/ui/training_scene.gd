extends Control
## Waffen-Training (DQ9-Stil): Skillpunkte (+3 pro Level-Up) pro Held in
## Waffengattungen investieren — Schwellen schalten Technik-Bausteine für
## die Skill-Werkstatt frei. Investieren ist unumkehrbar (wie in DQ9).

const WORKSHOP_SCENE := "res://scenes/workshop/skill_workshop.tscn"

const TREES: Array[StringName] = [&"schwert", &"dolch", &"axt", &"stumpf",
	&"bogen", &"armbrust", &"offensivstab", &"heiligstab", &"schild"]

var _selected: Combatant = null
var _char_bar: HBoxContainer
var _points_label: Label
var _tree_list: VBoxContainer
var _confirm_rebirth := false
## Geplante (noch NICHT bestätigte) Trainings-Punkte: Gattung » Punkte.
var _pending: Dictionary = {}


func _ready() -> void:
	theme = UiTheme.get_theme()
	_selected = GameState.party[0] if not GameState.party.is_empty() else null
	_build_layout()
	_refresh()
	UiTheme.focus_first_button(self)


func _build_layout() -> void:
	add_child(UiTheme.make_background())

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
			_confirm_rebirth = false
			_pending.clear()
			_refresh())
		_char_bar.add_child(button)

	for child in _tree_list.get_children():
		child.queue_free()
	if _selected == null:
		return
	var planned := _pending_total()
	_points_label.text = Loc.pick("Freie Punkte: %d", "Free points: %d") \
		% (_selected.skill_points - planned)
	if planned > 0:
		_points_label.text += Loc.pick("   ·   %d verplant", "   ·   %d planned") % planned
	if _selected.rebirths > 0:
		_points_label.text += Loc.pick("   ·   Wiedergeburt ×%d", "   ·   rebirth ×%d") \
			% _selected.rebirths

	# Wiedergeburt (ab Level 100): Level/Stats auf Anfang, Training bleibt —
	# so farmt man über mehrere Leben die Bäume bis 100 voll.
	if planned > 0:
		_tree_list.add_child(_confirm_row())
	if _selected.can_rebirth():
		_tree_list.add_child(_rebirth_row())
	for family in TREES:
		_tree_list.add_child(_tree_row(family))


func _pending_total() -> int:
	var total := 0
	for family in _pending:
		total += int(_pending[family])
	return total


## Erst BESTÄTIGEN investiert wirklich (und ist dann unumkehrbar wie DQ9) —
## bis dahin lässt sich die Planung frei korrigieren.
func _confirm_row() -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var info := Label.new()
	info.text = Loc.pick("%d Punkte verplant — erst Bestätigen macht sie fest.",
		"%d points planned — only confirming locks them in.") % _pending_total()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.modulate = Color(0.55, 1.0, 0.55)
	row.add_child(info)
	var confirm := Button.new()
	confirm.text = Loc.pick("Bestätigen", "Confirm")
	confirm.pressed.connect(func() -> void:
		for family in _pending:
			if int(_pending[family]) > 0:
				_selected.invest_point(family, int(_pending[family]))
		_pending.clear()
		GameState.save_game()
		Sfx.play(&"bestaetigen")
		_refresh())
	row.add_child(confirm)
	var reset := Button.new()
	reset.text = Loc.pick("Zurücksetzen", "Reset")
	reset.pressed.connect(func() -> void:
		_pending.clear()
		_refresh())
	row.add_child(reset)
	return panel


func _rebirth_row() -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var info := Label.new()
	info.text = Loc.pick("%s hat Level %d erreicht! Wiedergeburt: zurück auf Level 1 — Waffen-Training, freie Skillpunkte, Skills und Ausrüstung bleiben.",
		"%s reached level %d! Rebirth: back to level 1 — weapon training, free skill points, skills and equipment remain.") \
		% [_selected.display_name, _selected.level]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.modulate = Color(1.0, 0.85, 0.4)
	row.add_child(info)
	var button := Button.new()
	button.text = Loc.pick("Wirklich wiedergeboren werden?", "Really be reborn?") \
		if _confirm_rebirth else Loc.pick("Wiedergeburt", "Rebirth")
	button.pressed.connect(func() -> void:
		if not _confirm_rebirth:
			_confirm_rebirth = true
			_refresh()
			return
		_confirm_rebirth = false
		if _selected.rebirth():
			GameState.save_game()
			Sfx.play(&"level_up")
		_refresh())
	row.add_child(button)
	return panel


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
	name_label.tooltip_text = Loc.pick("Eigenheit (immer aktiv beim Führen): %s",
		"Trait (always active while wielded): %s") % Combatant.trait_label(family)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(name_label)
	var pending := int(_pending.get(family, 0))
	if pending > 0:
		name_label.text += "  [+%d geplant]" % pending if Loc.language == "de" \
			else "  [+%d planned]" % pending
		name_label.modulate = Color(0.55, 1.0, 0.55)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(36, 0)
	minus.disabled = pending <= 0
	minus.pressed.connect(func() -> void:
		_pending[family] = pending - 1
		_refresh())
	head.add_child(minus)
	var invest := Button.new()
	invest.text = "+1"
	invest.disabled = _pending_total() >= _selected.skill_points
	invest.pressed.connect(func() -> void:
		_pending[family] = pending + 1
		_refresh())
	head.add_child(invest)
	var invest_five := Button.new()
	invest_five.text = "+5"
	invest_five.disabled = _pending_total() + 5 > _selected.skill_points
	invest_five.pressed.connect(func() -> void:
		_pending[family] = pending + 5
		_refresh())
	head.add_child(invest_five)

	# Alle Schwellen des Baums (Techniken + Passiv-Boni), nach Punkten
	# sortiert — erreichte mit [OK], kommende als Ausblick.
	var preview := invested + int(_pending.get(family, 0))
	var entries: Array[Dictionary] = []
	for block in BlockLibrary.tree_blocks(family):
		entries.append({"points": block.tree_points, "label": block.display_name,
			"reached": preview >= block.tree_points or block.id in GameState.researched})
	for passive in BlockLibrary.passives_for(family):
		entries.append({"points": int(passive["points"]),
			"label": BlockLibrary.passive_label(passive),
			"reached": preview >= int(passive["points"])})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["points"]) < int(b["points"]))
	var parts: Array[String] = []
	for entry in entries:
		parts.append("%s%d: %s" % ["[OK] " if entry["reached"] else "",
			entry["points"], entry["label"]])
	var unlocks := Label.new()
	unlocks.text = "   ·   ".join(parts)
	unlocks.add_theme_font_size_override("font_size", 12)
	unlocks.modulate = Color(0.75, 0.9, 1.0, 0.9)
	unlocks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(unlocks)
	return panel
