extends Control
## Händler & Alchemist: einfache Tränke kaufen (Gold), alle Tränke aus
## Materialien craften. Ein Kur-Trank pro Statuseffekt; das Allheilmittel
## wird aus allen fünf Kur-Tränken zusammen gebraut.

const MAIN_SCENE := "res://scenes/main.tscn"

var _gold_label: Label
var _materials_label: Label
var _buy_list: VBoxContainer
var _craft_list: VBoxContainer
var _orders_list: VBoxContainer
var _medal_list: VBoxContainer


func _ready() -> void:
	GameState.ensure_orders()
	theme = UiTheme.get_theme()
	_build_layout()
	_refresh()


func _on_buy(def: ConsumableDef) -> void:
	if GameState.buy(def):
		Sfx.play(&"gold")
		_refresh()
	else:
		Sfx.play(&"fehler")


func _on_craft(def: ConsumableDef) -> void:
	if GameState.craft(def):
		Sfx.play(&"trank")
		_refresh()
	else:
		Sfx.play(&"fehler")


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
	title.text = Loc.pick("Händler & Alchemist", "Merchant & alchemist")
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_gold_label = Label.new()
	head.add_child(_gold_label)
	var back := Button.new()
	back.text = Loc.pick("Zurück zum Menü", "Back to menu")
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(MAIN_SCENE))
	head.add_child(back)

	_materials_label = Label.new()
	_materials_label.modulate = Color(1, 1, 1, 0.7)
	main.add_child(_materials_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	main.add_child(body)

	var buy_scroll := ScrollContainer.new()
	buy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(buy_scroll)
	var buy_box := VBoxContainer.new()
	buy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_scroll.add_child(buy_box)
	var buy_header := Label.new()
	buy_header.text = Loc.pick("Kaufen", "Buy")
	buy_header.add_theme_font_size_override("font_size", 18)
	buy_box.add_child(buy_header)
	_buy_list = VBoxContainer.new()
	_buy_list.add_theme_constant_override("separation", 4)
	buy_box.add_child(_buy_list)

	var craft_scroll := ScrollContainer.new()
	craft_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	craft_scroll.size_flags_stretch_ratio = 1.5
	body.add_child(craft_scroll)
	var craft_box := VBoxContainer.new()
	craft_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_scroll.add_child(craft_box)
	var craft_header := Label.new()
	craft_header.text = Loc.pick("Alchemie (Craften)", "Alchemy (crafting)")
	craft_header.add_theme_font_size_override("font_size", 18)
	craft_box.add_child(craft_header)
	_craft_list = VBoxContainer.new()
	_craft_list.add_theme_constant_override("separation", 4)
	craft_box.add_child(_craft_list)

	var orders_scroll := ScrollContainer.new()
	orders_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orders_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(orders_scroll)
	var orders_box := VBoxContainer.new()
	orders_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orders_scroll.add_child(orders_box)
	var orders_header := Label.new()
	orders_header.text = Loc.pick("Aufträge", "Orders")
	orders_header.add_theme_font_size_override("font_size", 18)
	orders_box.add_child(orders_header)
	_orders_list = VBoxContainer.new()
	_orders_list.add_theme_constant_override("separation", 4)
	orders_box.add_child(_orders_list)

	var medal_header := Label.new()
	medal_header.text = Loc.pick("Mini-Medaillen", "Mini medals")
	medal_header.add_theme_font_size_override("font_size", 18)
	orders_box.add_child(medal_header)
	_medal_list = VBoxContainer.new()
	_medal_list.add_theme_constant_override("separation", 4)
	orders_box.add_child(_medal_list)


func _refresh() -> void:
	_gold_label.text = "Gold: %d   " % GameState.gold

	var material_parts: Array[String] = []
	for id in MaterialLibrary.MATERIALS:
		material_parts.append("%s ×%d" % [MaterialLibrary.display_name(id),
			GameState.material_count(id)])
	_materials_label.text = Loc.pick("Materialien:  ", "Materials:  ") + "   ".join(material_parts)

	for child in _buy_list.get_children():
		child.queue_free()
	for def in ConsumableLibrary.buyable_defs():
		_buy_list.add_child(_make_buy_row(def))

	for child in _craft_list.get_children():
		child.queue_free()
	for def in ConsumableLibrary.craftable_defs():
		_craft_list.add_child(_make_craft_row(def))

	for child in _orders_list.get_children():
		child.queue_free()
	for order in GameState.merchant_orders:
		_orders_list.add_child(_make_order_row(order))

	for child in _medal_list.get_children():
		child.queue_free()
	var medal_count := Label.new()
	medal_count.text = Loc.pick("🏅 Im Besitz: %d (aus Truhen, Risiko-Truhen und Bossen)",
		"🏅 Owned: %d (from chests, risk chests and bosses)") % GameState.medals
	medal_count.modulate = Color(1.0, 0.85, 0.4)
	medal_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_medal_list.add_child(medal_count)
	_medal_list.add_child(_medal_offer(
		Loc.pick("3 🏅 → Schmiede-Paket (je 3× Erz/Leder/Kristall)",
			"3 🏅 → smithing bundle (3× ore/leather/crystal each)"), 3,
		func() -> void:
			GameState.add_material(&"eisenerz", 3)
			GameState.add_material(&"lederreste", 3)
			GameState.add_material(&"kristallstaub", 3)))
	_medal_list.add_child(_medal_offer(
		Loc.pick("5 🏅 → Wunsch-Karte (Stufe = Party-Schnitt)",
			"5 🏅 → wish map (tier = party average)"), 5,
		func() -> void:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			GameState.add_card(CardFactory.make_card(
				GameState.average_party_level(), rng))))
	_medal_list.add_child(_medal_offer(
		Loc.pick("8 🏅 → garantiert EPISCHES Item (Party-Schnitt)",
			"8 🏅 → guaranteed EPIC item (party average)"), 8,
		func() -> void:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			GameState.inventory.append(LootGenerator.roll_item_with_rarity(
				GameState.average_party_level(), Enums.Rarity.EPIC, rng))))


## Tausch-Button: Medaillen gegen Belohnung (gesperrt, wenn zu wenige).
func _medal_offer(label: String, cost: int, grant: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = GameState.medals < cost
	button.pressed.connect(func() -> void:
		if GameState.medals < cost:
			Sfx.play(&"fehler")
			return
		GameState.medals -= cost
		grant.call()
		GameState.save_game()
		Sfx.play(&"bestaetigen")
		_refresh())
	return button


func _make_order_row(order: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var task := Label.new()
	task.text = MerchantOrders.describe(order)
	task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(task)

	var reward := Label.new()
	reward.text = Loc.pick("Belohnung: ", "Reward: ") + MerchantOrders.reward_text(order)
	reward.modulate = Color(1.0, 0.85, 0.4)
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(reward)

	var claim := Button.new()
	claim.text = Loc.pick("Abgeben", "Turn in")
	claim.disabled = not MerchantOrders.is_complete(order, GameState)
	claim.pressed.connect(func() -> void:
		if GameState.claim_order(order):
			GameState.save_game()
			Sfx.play(&"bestaetigen")
			_refresh()
		else:
			Sfx.play(&"fehler"))
	box.add_child(claim)
	return panel


func _make_buy_row(def: ConsumableDef) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var info := Label.new()
	info.text = "%s (×%d)" % [def.display_name, GameState.consumable_count(def.id)]
	info.tooltip_text = def.description
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var buy := Button.new()
	buy.text = Loc.pick("Kaufen (%d G)", "Buy (%d G)") % def.price
	buy.disabled = GameState.gold < def.price
	buy.pressed.connect(_on_buy.bind(def))
	row.add_child(buy)
	return panel


func _make_craft_row(def: ConsumableDef) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = "%s (×%d)" % [def.display_name, GameState.consumable_count(def.id)]
	name_label.tooltip_text = def.description
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(name_label)
	var recipe_label := Label.new()
	recipe_label.text = Loc.pick("Rezept: ", "Recipe: ") + _recipe_text(def)
	recipe_label.add_theme_font_size_override("font_size", 11)
	recipe_label.modulate = Color(1, 1, 1, 0.6)
	info.add_child(recipe_label)

	var craft := Button.new()
	craft.text = Loc.pick("Craften", "Craft")
	craft.disabled = not GameState.can_craft(def)
	craft.pressed.connect(_on_craft.bind(def))
	row.add_child(craft)
	return panel


static func _recipe_text(def: ConsumableDef) -> String:
	var parts: Array[String] = []
	for id in def.craft_materials:
		parts.append("%d× %s" % [def.craft_materials[id], MaterialLibrary.display_name(id)])
	for id in def.craft_consumables:
		parts.append("%d× %s" % [def.craft_consumables[id],
			ConsumableLibrary.get_def(id).display_name])
	return " + ".join(parts)
