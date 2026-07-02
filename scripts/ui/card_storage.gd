extends Control
## Kartenlager: gesammelte Dungeon-Karten ansehen, betreten, löschen,
## Lager gegen Gold erweitern. Der Einstiegspunkt in jeden Dungeon-Run.

const MAIN_SCENE := "res://scenes/main.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/dungeon_scene.tscn"

var _gold_label: Label
var _capacity_label: Label
var _expand_button: Button
var _card_list: VBoxContainer


func _ready() -> void:
	_build_layout()
	_refresh()


func _on_enter(card: DungeonCard) -> void:
	GameState.start_run(card)
	get_tree().change_scene_to_file(DUNGEON_SCENE)


func _on_delete(card: DungeonCard) -> void:
	GameState.delete_card(card)
	_refresh()


func _on_expand() -> void:
	if GameState.expand_storage():
		_refresh()


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1a1a2e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for margin in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		root.add_theme_constant_override(margin, 16)
	add_child(root)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	root.add_child(main)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	main.add_child(head)
	var title := Label.new()
	title.text = "Kartenlager"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_gold_label = Label.new()
	head.add_child(_gold_label)
	_capacity_label = Label.new()
	head.add_child(_capacity_label)
	_expand_button = Button.new()
	_expand_button.pressed.connect(_on_expand)
	head.add_child(_expand_button)
	var back := Button.new()
	back.text = "Zurück zum Menü"
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(MAIN_SCENE))
	head.add_child(back)

	var hint := Label.new()
	hint.text = "Nach jedem Abschluss gibt es eine neue Karte auf Stufe ±3. Karten sind wiederholbar — gleiche Karte, gleiches Layout, gleiche Elite-Typen."
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)
	_card_list = VBoxContainer.new()
	_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_card_list)


func _refresh() -> void:
	_gold_label.text = "Gold: %d" % GameState.gold
	_capacity_label.text = "Karten: %d/%d" % [GameState.cards.size(), GameState.card_capacity]
	_expand_button.text = "Lager erweitern +5 (%d G)" % GameState.storage_expansion_cost()
	_expand_button.disabled = not GameState.can_expand_storage()

	for child in _card_list.get_children():
		child.queue_free()
	if GameState.cards.is_empty():
		var empty := Label.new()
		empty.text = "Keine Karten — schließe Dungeons ab, um neue zu erhalten."
		empty.modulate = Color(1, 1, 1, 0.5)
		_card_list.add_child(empty)
	for card in GameState.cards:
		_card_list.add_child(_make_card_row(card))


func _make_card_row(card: DungeonCard) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = "%s  —  Stufe %d, %s, %d Ebene%s" % [card.display_name, card.tier,
		CardFactory.BIOME_NAMES[card.biome], card.floor_count,
		"" if card.floor_count == 1 else "n"]
	info.add_child(name_label)

	var detail := Label.new()
	var modifier_names: Array[String] = []
	for id in card.modifier_ids:
		var modifier := EnemyLibrary.get_modifier(id)
		if modifier != null:
			modifier_names.append(modifier.display_name)
	var detail_parts: Array[String] = []
	if not modifier_names.is_empty():
		detail_parts.append("Modifikatoren: " + ", ".join(modifier_names))
	if card.times_completed > 0:
		detail_parts.append("%d× abgeschlossen" % card.times_completed)
	detail.text = "  ·  ".join(detail_parts) if not detail_parts.is_empty() else "Noch unerkundet"
	detail.add_theme_font_size_override("font_size", 11)
	detail.modulate = Color(1, 1, 1, 0.6)
	info.add_child(detail)

	var enter := Button.new()
	enter.text = "Betreten"
	enter.pressed.connect(_on_enter.bind(card))
	row.add_child(enter)

	var delete := Button.new()
	delete.text = "Löschen"
	delete.pressed.connect(_on_delete.bind(card))
	row.add_child(delete)
	return panel
