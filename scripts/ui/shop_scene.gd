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
var _gamble_list: VBoxContainer

## Glücksbude (Gamble im Diablo/PoE-Stil): gewählte Item-Stufe — daraus
## errechnet sich der Preis, das Item selbst ist komplett zufällig.
## 0 = noch nicht gewählt » beim ersten Öffnen Party-Durchschnitt.
var _gamble_level := 0

## Untertabs (Kaufen/Alchemie/Aufträge/Medaillen): id → Bereichs-Container
## bzw. Tab-Button. Getrennt statt alles nebeneinander — Übersicht.
var _sections: Dictionary = {}
var _section_buttons: Dictionary = {}


func _ready() -> void:
	GameState.ensure_orders()
	theme = UiTheme.get_theme()
	_build_layout()
	_refresh()
	_open_section(&"kaufen")
	UiTheme.focus_first_button(self)


func _open_section(id: StringName) -> void:
	for key in _sections:
		_sections[key].visible = key == id
		_section_buttons[key].disabled = key == id


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
	add_child(UiTheme.make_background())

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for margin in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		root.add_theme_constant_override(margin, 16)
	add_child(root)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	root.add_child(main)

	# Stadt-Tabs: Taverne · Händler · Schmiede sind ein Ort.
	main.add_child(UiTheme.town_tabs(&"haendler"))

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

	# Untertabs: Kaufen · Alchemie · Aufträge · Medaillen — jede Sektion
	# eine eigene, ruhige Ansicht (User-Wunsch: mehr Übersicht).
	var section_bar := HBoxContainer.new()
	section_bar.add_theme_constant_override("separation", 8)
	main.add_child(section_bar)
	for entry in [[&"kaufen", Loc.pick("Kaufen", "Buy")],
			[&"alchemie", Loc.pick("Alchemie (Brauen)", "Alchemy (brewing)")],
			[&"auftraege", Loc.pick("Aufträge", "Orders")],
			[&"medaillen", Loc.pick("Medaillen-Tausch", "Medal exchange")],
			[&"gamble", Loc.pick("Glücksbude", "Gamble")]]:
		var section_button := Button.new()
		section_button.text = entry[1]
		section_button.custom_minimum_size = Vector2(170, 34)
		section_button.pressed.connect(_open_section.bind(entry[0]))
		section_bar.add_child(section_button)
		_section_buttons[entry[0]] = section_button

	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(body)

	_buy_list = _make_section(body, &"kaufen")
	_craft_list = _make_section(body, &"alchemie")
	_orders_list = _make_section(body, &"auftraege")
	_medal_list = _make_section(body, &"medaillen")
	_gamble_list = _make_section(body, &"gamble")


## Eine Untertab-Sektion: Scroll-Bereich über die volle Fläche, darin die
## Inhaltsliste. Sichtbarkeit steuert _open_section.
func _make_section(body: Control, id: StringName) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	_sections[id] = scroll
	return list


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
	medal_count.text = Loc.pick("Im Besitz: %d (aus Truhen, Risiko-Truhen und Bossen)",
		"Owned: %d (from chests, risk chests and bosses)") % GameState.medals
	medal_count.modulate = Color(1.0, 0.85, 0.4)
	medal_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_medal_list.add_child(medal_count)
	_medal_list.add_child(_medal_offer(
		Loc.pick("3 Medaillen » Schmiede-Paket (je 3× Erz/Leder/Kristall)",
			"3 medals » smithing bundle (3× ore/leather/crystal each)"), 3,
		func() -> void:
			GameState.add_material(&"eisenerz", 3)
			GameState.add_material(&"lederreste", 3)
			GameState.add_material(&"kristallstaub", 3)))
	_medal_list.add_child(_medal_offer(
		Loc.pick("5 Medaillen » Wunsch-Karte (Stufe = Party-Schnitt)",
			"5 medals » wish map (tier = party average)"), 5,
		func() -> void:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			GameState.add_card(CardFactory.make_card(
				GameState.average_party_level(), rng))))
	_medal_list.add_child(_medal_offer(
		Loc.pick("8 Medaillen » garantiert EPISCHES Item (Party-Schnitt)",
			"8 medals » guaranteed EPIC item (party average)"), 8,
		func() -> void:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			GameState.inventory.append(LootGenerator.roll_item_with_rarity(
				GameState.average_party_level(), Enums.Rarity.EPIC, rng))))

	_rebuild_gamble()


## Glücksbude: Stufe wählen (−/+), Preis wächst quadratisch mit der Stufe
## (wie die XP-Kurve — bleibt also in jeder Spielphase relevant), das Item
## ist komplett zufällig: Waffe oder Rüstung, Rarität nach Beute-Tabelle.
func _rebuild_gamble() -> void:
	for child in _gamble_list.get_children():
		child.queue_free()
	if _gamble_level <= 0:
		_gamble_level = maxi(1, GameState.average_party_level())

	var intro := Label.new()
	intro.text = Loc.pick("Die Händlerin zwinkert: „Stufe aussuchen, Gold auf den Tisch —\nwas im Sack steckt, siehst du erst danach.“",
		"The merchant winks: \"Pick a tier, put your gold on the table —\nyou'll see what's in the bag afterwards.\"")
	intro.modulate = Color(1, 1, 1, 0.7)
	_gamble_list.add_child(intro)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_gamble_list.add_child(row)

	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(40, 0)
	minus.disabled = _gamble_level <= 1
	minus.pressed.connect(func() -> void:
		_gamble_level = maxi(1, _gamble_level - 1)
		_rebuild_gamble())
	row.add_child(minus)

	var level_label := Label.new()
	level_label.text = Loc.pick("Item-Stufe %d", "Item tier %d") % _gamble_level
	row.add_child(level_label)

	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(40, 0)
	plus.pressed.connect(func() -> void:
		_gamble_level += 1
		_rebuild_gamble())
	row.add_child(plus)

	var cost := _gamble_cost(_gamble_level)
	var buy := Button.new()
	buy.text = Loc.pick("Zufalls-Ausrüstung kaufen (%d Gold)",
		"Buy random gear (%d gold)") % cost
	buy.disabled = GameState.gold < cost
	buy.pressed.connect(func() -> void:
		if GameState.gold < cost:
			Sfx.play(&"fehler")
			return
		GameState.gold -= cost
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var item := LootGenerator.roll_item(_gamble_level, rng)
		GameState.inventory.append(item)
		GameState.save_game()
		Sfx.play(&"kaufen")
		_refresh()
		_open_section(&"gamble")
		# Ergebnis groß anzeigen — der ganze Reiz der Bude.
		var result := Label.new()
		result.text = Loc.pick("Gezogen: %s (%s)", "You drew: %s (%s)") \
			% [item.get_display_name(), LootGenerator.RARITY_NAMES[item.rarity]]
		result.modulate = LootGenerator.RARITY_COLORS[item.rarity]
		result.add_theme_font_size_override("font_size", 16)
		_gamble_list.add_child(result))
	row.add_child(buy)


## Preis der Glücksbude: folgt der zentralen Welt-Wachstumskurve (wie
## Gold-Beute) — grob 2–3 Kämpfe derselben Stufe, in jeder Spielphase.
static func _gamble_cost(level: int) -> int:
	return roundi((60 + 20 * level) * Scaling.factor(level))


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
