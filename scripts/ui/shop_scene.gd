extends Control
## Händler & Alchemist: Tränke, Kräuter und einfache Werkstoffe kaufen,
## zufällige Ausrüstung um den Party-Schnitt (nur Gold), Tränke brauen.
## Ein Kur-Trank pro Statuseffekt; das Allheilmittel wird aus allen
## Kur-Tränken zusammen gebraut.

const MAIN_SCENE := "res://scenes/main.tscn"

var _gold_label: Label
var _materials_label: Label
var _buy_list: VBoxContainer
var _craft_list: VBoxContainer
var _orders_list: VBoxContainer
var _medal_list: VBoxContainer
var _material_list: VBoxContainer
var _gear_list: VBoxContainer
## Zuletzt gekaufter Gegenstand (wird groß angezeigt).
var _gekauft: ItemInstance = null

## Untertabs (Kaufen/Alchemie/Aufträge/Medaillen): id → Bereichs-Container
## bzw. Tab-Button. Getrennt statt alles nebeneinander — Übersicht.
var _sections: Dictionary = {}
var _section_buttons: Dictionary = {}


func _ready() -> void:
	GameState.ensure_orders()
	theme = UiTheme.get_theme()
	Music.play(&"stadt")
	_build_layout()
	_refresh()
	_open_section(&"kaufen")
	UiTheme.focus_first_button(self)


func _open_section(id: StringName) -> void:
	for key in _sections:
		_sections[key].visible = key == id
		UiTheme.als_aktiv(_section_buttons[key], key == id)


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
	var b := Bildschirm.bauen(self, Loc.pick("Händler & Alchemist", "Merchant & alchemist"), &"laden",
		func() -> void: get_tree().change_scene_to_file(MAIN_SCENE), Loc.pick("Menü", "Menu"),
		UiTheme.town_tabs(&"haendler"))
	_gold_label = b.info("")
	_materials_label = b.untertitel  # Materialien-Zeile (wird in _refresh gefüllt)
	_materials_label.visible = true
	var main := b.inhalt

	# Untertabs: Kaufen · Alchemie · Aufträge · Medaillen — jede Sektion
	# eine eigene, ruhige Ansicht (User-Wunsch: mehr Übersicht).
	var section_bar := HBoxContainer.new()
	section_bar.add_theme_constant_override("separation", 8)
	main.add_child(section_bar)
	for entry in [[&"kaufen", Loc.pick("Tränke", "Potions")],
			[&"materialien", Loc.pick("Kräuter & Werkstoffe", "Herbs & materials")],
			[&"ausruestung", Loc.pick("Ausrüstung", "Equipment")],
			[&"alchemie", Loc.pick("Alchemie (Brauen)", "Alchemy (brewing)")],
			[&"auftraege", Loc.pick("Aufträge", "Orders")],
			[&"medaillen", Loc.pick("Medaillen-Tausch", "Medal exchange")]]:
		var section_button := Button.new()
		section_button.text = entry[1]
		section_button.custom_minimum_size = Vector2(150, 34)
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
	_material_list = _make_section(body, &"materialien")
	_gear_list = _make_section(body, &"ausruestung")


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
	_gold_label.text = "Gold: %d" % GameState.gold

	var material_parts: Array[String] = []
	for id in MaterialLibrary.ids_der_art(&"kraut"):
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
	medal_count.text = Loc.pick("Im Besitz: %d (aus Truhen, Risiko-Truhen, Tresoren und Bossen)",
		"Owned: %d (from chests, risk chests, vaults and bosses)") % GameState.medals
	medal_count.modulate = Color(1.0, 0.85, 0.4)
	medal_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_medal_list.add_child(medal_count)
	_baue_medaillen_stufen()
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

	_baue_materialien()
	_baue_ausruestung()


## Kräuter & Werkstoffe: Kräuter fürs Brauen, Werkstoffe der Stufe 1 für die
## Schmiede — jeweils einzeln oder im Fünferpack.
func _baue_materialien() -> void:
	for child in _material_list.get_children():
		child.queue_free()
	_material_list.add_child(_abschnitt_hinweis(Loc.pick("Edlere Werkstoffe (Stahl, Mithril …) und Runen verkauft niemand — die gibt es nur als Beute.",
		"Finer materials (steel, mithril …) and runes aren't for sale — they only come as loot.")))
	for id in Haendler.MATERIAL_PREIS:
		var preis: int = Haendler.MATERIAL_PREIS[id]
		var panel := PanelContainer.new()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		panel.add_child(row)
		var info := Label.new()
		info.text = "%s   (%s %d)" % [MaterialLibrary.display_name(id), Loc.pick("hast", "have"),
			GameState.material_count(id)]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		for menge in [1, 5]:
			var kaufen := Button.new()
			kaufen.text = Loc.pick("%d× kaufen (%d G)", "Buy %d× (%d G)") % [menge, preis * menge]
			kaufen.disabled = GameState.gold < preis * menge
			var anzahl: int = menge
			kaufen.pressed.connect(func() -> void:
				if GameState.gold < preis * anzahl:
					Sfx.play(&"fehler")
					return
				GameState.gold -= preis * anzahl
				GameState.add_material(id, anzahl)
				GameState.save_game()
				Sfx.play(&"gold")
				_refresh())
			row.add_child(kaufen)
		_material_list.add_child(panel)


## Ausrüstung: Art wählen, bezahlen, überraschen lassen. Level ≈ Party-Schnitt,
## alles andere Zufall — teurer als die Schmiede, dafür ohne Materialien.
func _baue_ausruestung() -> void:
	for child in _gear_list.get_children():
		child.queue_free()
	var schnitt := GameState.average_party_level()
	var preis := Haendler.ausruestung_preis(schnitt)
	_gear_list.add_child(_abschnitt_hinweis(Loc.pick("Die Händlerin zwinkert: „Sag mir die Art, leg das Gold hin — was im Sack steckt, siehst du danach.“  Level etwa %d (Party-Schnitt), mindestens Magisch.",
		"The merchant winks: \"Name the kind, put down the gold — you'll see what's in the bag afterwards.\"  Level about %d (party average), at least magic.") % schnitt))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	_gear_list.add_child(flow)
	for k in Smith.KATEGORIEN:
		var knopf := Button.new()
		knopf.text = "%s\n%d Gold" % [Smith.kategorie_name(k), preis]
		knopf.custom_minimum_size = Vector2(170, 56)
		knopf.disabled = GameState.gold < preis
		var kategorie_id: StringName = k["id"]
		knopf.pressed.connect(func() -> void:
			if GameState.gold < preis:
				Sfx.play(&"fehler")
				return
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			var item := Haendler.ausruestung_kaufen(kategorie_id, schnitt, rng)
			if item == null:
				Sfx.play(&"fehler")
				return
			GameState.gold -= preis
			GameState.inventory.append(item)
			GameState.save_game()
			Sfx.play(&"kaufen")
			_gekauft = item
			_refresh())
		flow.add_child(knopf)
	if _gekauft != null:
		var titel := Label.new()
		titel.text = Loc.pick("Gekauft:", "Bought:")
		titel.add_theme_font_size_override("font_size", 16)
		_gear_list.add_child(titel)
		var karte := ItemInfo.karte(_gekauft)
		karte.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_gear_list.add_child(karte)


static func _abschnitt_hinweis(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0.7)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Medaillen-Stufen: feste Belohnungen für insgesamt gesammelte Medaillen —
## die nächste abholbare Stufe und die zwei danach.
func _baue_medaillen_stufen() -> void:
	var titel := Label.new()
	titel.text = Loc.pick("Medaillen-Stufen — insgesamt gesammelt: %d", "Medal tiers — collected in total: %d") \
		% GameState.medaillen_gesamt
	titel.add_theme_color_override("font_color", UiTheme.GOLD)
	_medal_list.add_child(titel)
	for versatz in 3:
		var index := GameState.medaillen_stufen + versatz
		var zeile := HBoxContainer.new()
		zeile.add_theme_constant_override("separation", 10)
		_medal_list.add_child(zeile)
		var text := Label.new()
		text.text = "%d » %s" % [MedaillenStufen.schwelle(index), MedaillenStufen.text(MedaillenStufen.belohnung(index))]
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zeile.add_child(text)
		if versatz == 0:
			var knopf := Button.new()
			knopf.text = Loc.pick("Abholen", "Claim")
			knopf.disabled = not MedaillenStufen.abholbar(GameState.medaillen_gesamt, index)
			knopf.pressed.connect(func() -> void:
				var erhalten := MedaillenStufen.abholen(GameState)
				if erhalten.is_empty():
					Sfx.play(&"fehler")
					return
				GameState.save_game()
				Sfx.play(&"seltener_fund")
				_refresh())
			zeile.add_child(knopf)
		else:
			text.modulate = Color(1, 1, 1, 0.55)
	var trenner := HSeparator.new()
	_medal_list.add_child(trenner)


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
