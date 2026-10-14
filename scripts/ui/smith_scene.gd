extends Control
## Schmiede (Lutz 2026-10-14): Reiter je Gegenstandsart. Man wählt nur die
## Werkstoff-Stufe, das Item-Level und optional eine Rune — welche Basis,
## Rarität und welche Affixe herauskommen, entscheidet der Amboss.
## Dazu ein Reiter „Neu würfeln“ für die Affixe vorhandener Items.

const MAIN_SCENE := "res://scenes/main.tscn"
const NEU_WUERFELN := &"neu_wuerfeln"

var _gold_label: Label
var _tab_leiste: HBoxContainer
var _tabs: Dictionary = {}           ## Kategorie-ID » Button
var _links: VBoxContainer            ## Auftrag (Stufe, Level, Rune, Kosten)
var _rechts: VBoxContainer           ## Chancen + Ergebnis
var _kategorie: StringName = &"nahkampf"
var _stufe := 1
var _level := 1
var _rune: StringName = &""
var _ergebnis: ItemInstance = null
var _ergebnis_text := ""
var _reroll_item: ItemInstance = null


func _ready() -> void:
	theme = UiTheme.get_theme()
	Music.play(&"stadt")
	_level = GameState.average_party_level()
	_stufe = _beste_stufe_mit_material()
	_build_layout()
	_refresh()
	UiTheme.focus_first_button(self)


func _build_layout() -> void:
	var b := Bildschirm.bauen(self, Loc.pick("Schmiede", "Smithy"), &"schmiede",
		func() -> void: get_tree().change_scene_to_file(MAIN_SCENE), Loc.pick("Menü", "Menu"),
		UiTheme.town_tabs(&"schmiede"))
	_gold_label = b.info("")
	b.setze_untertitel(Loc.pick("Du bestimmst Art, Werkstoff und Level — was genau der Amboss daraus macht, ist Glück. Edlere Werkstoffe (von Gegnern höherer Karten) erlauben höhere Level und verbessern die Chance auf seltene Stücke; Runen von Bossen garantieren eine Mindest-Rarität.",
		"You choose type, material and level — what exactly the anvil makes of it is luck. Finer materials (from enemies on higher maps) allow higher levels and improve the odds of rare pieces; runes from bosses guarantee a minimum rarity."))

	_tab_leiste = HBoxContainer.new()
	_tab_leiste.add_theme_constant_override("separation", 6)
	b.inhalt.add_child(_tab_leiste)
	for k in Smith.KATEGORIEN:
		_tab(k["id"], Smith.kategorie_name(k))
	_tab(NEU_WUERFELN, Loc.pick("Neu würfeln", "Reroll"))

	var spalten := HBoxContainer.new()
	spalten.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spalten.add_theme_constant_override("separation", 16)
	b.inhalt.add_child(spalten)
	_links = VBoxContainer.new()
	_links.add_theme_constant_override("separation", 10)
	var links_tafel := Bildschirm.tafel(_links)
	links_tafel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links_tafel.size_flags_stretch_ratio = 1.3
	spalten.add_child(links_tafel)
	_rechts = VBoxContainer.new()
	_rechts.add_theme_constant_override("separation", 8)
	var rechts_tafel := Bildschirm.tafel(_rechts)
	rechts_tafel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spalten.add_child(rechts_tafel)


func _tab(id: StringName, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 34)
	button.pressed.connect(func() -> void:
		_kategorie = id
		_ergebnis = null
		_refresh())
	_tab_leiste.add_child(button)
	_tabs[id] = button


func _refresh() -> void:
	_gold_label.text = "Gold: %d" % GameState.gold
	for id in _tabs:
		UiTheme.als_aktiv(_tabs[id], id == _kategorie)
	for child in _links.get_children():
		child.queue_free()
	for child in _rechts.get_children():
		child.queue_free()
	if _kategorie == NEU_WUERFELN:
		_baue_neu_wuerfeln()
	else:
		_baue_auftrag()
		_baue_chancen()
	_baue_ergebnis()


# --- Schmieden -----------------------------------------------------------------

func _baue_auftrag() -> void:
	var k := Smith.kategorie(_kategorie)
	var max_level := Smith.max_level(_stufe, GameState.highest_party_level())
	_level = clampi(_level, 1, max_level)

	_links.add_child(Bildschirm.ueberschrift(Smith.kategorie_name(k)))
	var namen: Array[String] = []
	for base in Smith.moegliche_basen(_kategorie, _level):
		namen.append(base.display_name)
	_links.add_child(_hinweis(Loc.pick("Kann werden: %s", "Can become: %s") % ", ".join(namen)))

	# Werkstoff-Stufe: ein Knopf je Stufe mit Vorrat des Rezepts.
	_links.add_child(_zwischentitel(Loc.pick("Werkstoff", "Material")))
	var stufen := HFlowContainer.new()
	stufen.add_theme_constant_override("h_separation", 6)
	stufen.add_theme_constant_override("v_separation", 6)
	_links.add_child(stufen)
	for s in range(1, 6):
		var knopf := Button.new()
		var kosten := Smith.kosten(_kategorie, s, _level)
		var genug := _material_reicht(kosten)
		knopf.text = "%s%s" % [MaterialLibrary.stufen_name(s), "" if genug else " ✕"]
		knopf.tooltip_text = _vorrat_text(kosten) + "\n" + Loc.pick("Bis Level %s", "Up to level %s") \
			% (str(MaterialLibrary.STUFE_MAX_LEVEL[s - 1]) if MaterialLibrary.STUFE_MAX_LEVEL[s - 1] > 0 else "∞")
		knopf.custom_minimum_size = Vector2(96, 32)
		UiTheme.als_aktiv(knopf, s == _stufe)
		var stufe := s
		knopf.pressed.connect(func() -> void:
			_stufe = stufe
			_refresh())
		stufen.add_child(knopf)
	_links.add_child(_hinweis(_vorrat_text(Smith.kosten(_kategorie, _stufe, _level))))

	# Item-Level: −5 −1 [Regler] +1 +5 — höher kostet mehr Gold.
	_links.add_child(_zwischentitel(Loc.pick("Item-Level %d  (höchstens %d)", "Item level %d  (max %d)") % [_level, max_level]))
	var zeile := HBoxContainer.new()
	zeile.add_theme_constant_override("separation", 6)
	_links.add_child(zeile)
	for schritt in [-5, -1]:
		zeile.add_child(_level_knopf(schritt, max_level))
	var regler := HSlider.new()
	regler.min_value = 1
	regler.max_value = max_level
	regler.value = _level
	regler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regler.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	regler.drag_ended.connect(func(_geaendert: bool) -> void:
		_level = int(regler.value)
		_refresh())
	zeile.add_child(regler)
	for schritt in [1, 5]:
		zeile.add_child(_level_knopf(schritt, max_level))

	# Rune (optional).
	_links.add_child(_zwischentitel(Loc.pick("Rune", "Rune")))
	var runen := OptionButton.new()
	runen.add_item(Loc.pick("Keine Rune", "No rune"))
	runen.set_item_metadata(0, &"")
	for id in MaterialLibrary.RUNEN_RARITAET:
		var anzahl := GameState.material_count(id)
		if anzahl > 0:
			runen.add_item("%s ×%d — %s" % [MaterialLibrary.display_name(id), anzahl,
				Loc.pick("mindestens %s", "at least %s") % ItemInfo.raritaet_name(MaterialLibrary.RUNEN_RARITAET[id])])
			runen.set_item_metadata(runen.item_count - 1, id)
			if id == _rune:
				runen.select(runen.item_count - 1)
	if GameState.material_count(_rune) <= 0:
		_rune = &""
	runen.disabled = runen.item_count <= 1
	runen.tooltip_text = Loc.pick("Runen droppen selten von Bossen.", "Runes rarely drop from bosses.")
	runen.item_selected.connect(func(index: int) -> void:
		_rune = runen.get_item_metadata(index)
		_refresh())
	_links.add_child(runen)

	# Kosten + Schmieden.
	var kosten := _kosten()
	var schmieden := Button.new()
	schmieden.text = Loc.pick("Schmieden  —  %s", "Forge  —  %s") % _kosten_text(kosten)
	schmieden.custom_minimum_size = Vector2(0, 44)
	schmieden.disabled = not GameState.can_pay(kosten) or Smith.moegliche_basen(_kategorie, _level).is_empty()
	schmieden.pressed.connect(_schmieden)
	var luecke := Control.new()
	luecke.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_links.add_child(luecke)
	_links.add_child(schmieden)


func _level_knopf(schritt: int, max_level: int) -> Button:
	var knopf := Button.new()
	knopf.text = "%+d" % schritt
	knopf.custom_minimum_size = Vector2(44, 30)
	knopf.disabled = (schritt < 0 and _level <= 1) or (schritt > 0 and _level >= max_level)
	knopf.pressed.connect(func() -> void:
		_level = clampi(_level + schritt, 1, max_level)
		_refresh())
	return knopf


## Kosten inkl. Rune (die Rune wird verbraucht).
func _kosten() -> Dictionary:
	var kosten := Smith.kosten(_kategorie, _stufe, _level)
	if _rune != &"":
		var mats: Dictionary = kosten["materials"]
		mats[_rune] = 1
	return kosten


func _baue_chancen() -> void:
	_rechts.add_child(Bildschirm.ueberschrift(Loc.pick("Chancen", "Odds")))
	var chancen := Smith.raritaets_chancen(_stufe, _rune)
	for r in [Enums.Rarity.MAGIC, Enums.Rarity.RARE, Enums.Rarity.EPIC, Enums.Rarity.LEGENDARY]:
		var anteil: float = chancen.get(r, 0.0)
		var zeile := HBoxContainer.new()
		zeile.add_theme_constant_override("separation", 8)
		_rechts.add_child(zeile)
		var titel := Label.new()
		titel.text = ItemInfo.raritaet_name(r)
		titel.custom_minimum_size = Vector2(90, 0)
		titel.add_theme_color_override("font_color", LootGenerator.RARITY_COLORS[r])
		zeile.add_child(titel)
		var balken := ProgressBar.new()
		balken.max_value = 1.0
		balken.value = anteil
		balken.show_percentage = false
		balken.custom_minimum_size = Vector2(0, 14)
		balken.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		balken.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fuellung := StyleBoxFlat.new()
		fuellung.bg_color = LootGenerator.RARITY_COLORS[r]
		fuellung.set_corner_radius_all(3)
		balken.add_theme_stylebox_override("fill", fuellung)
		zeile.add_child(balken)
		var prozent := Label.new()
		prozent.text = "%d %%" % roundi(anteil * 100)
		prozent.custom_minimum_size = Vector2(48, 0)
		prozent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		zeile.add_child(prozent)


func _schmieden() -> void:
	var kosten := _kosten()
	if not GameState.pay(kosten):
		Sfx.play(&"fehler")
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var item := Smith.schmieden(_kategorie, _stufe, _level, _rune, rng)
	if item == null:
		Sfx.play(&"fehler")
		return
	GameState.inventory.append(item)
	GameState.save_game()
	Sfx.play(&"schmiede")
	_ergebnis = item
	_ergebnis_text = Loc.pick("Geschmiedet!", "Forged!")
	_refresh()


# --- Neu würfeln ---------------------------------------------------------------

func _baue_neu_wuerfeln() -> void:
	_links.add_child(Bildschirm.ueberschrift(Loc.pick("Affixe neu würfeln", "Reroll affixes")))
	_links.add_child(_hinweis(Loc.pick("Basis, Level und Rarität bleiben — Affixe und ihre Qualität werden neu ausgewürfelt.",
		"Base, level and rarity stay — affixes and their quality are rerolled.")))
	var auswahl := OptionButton.new()
	var kandidaten: Array[ItemInstance] = []
	for item in GameState.inventory:
		if item.rarity != Enums.Rarity.COMMON:
			kandidaten.append(item)
	if not kandidaten.has(_reroll_item):
		_reroll_item = kandidaten[0] if not kandidaten.is_empty() else null
	for item in kandidaten:
		auswahl.add_item("%s (Lv %d, %s)" % [item.get_display_name(), item.item_level,
			ItemInfo.raritaet_name(item.rarity)])
		auswahl.set_item_metadata(auswahl.item_count - 1, item)
		if item == _reroll_item:
			auswahl.select(auswahl.item_count - 1)
	auswahl.item_selected.connect(func(index: int) -> void:
		_reroll_item = auswahl.get_item_metadata(index)
		_refresh())
	_links.add_child(auswahl)
	var knopf := Button.new()
	knopf.custom_minimum_size = Vector2(0, 44)
	if _reroll_item == null:
		knopf.text = Loc.pick("Kein Gegenstand mit Affixen im Inventar", "No item with affixes in the inventory")
		knopf.disabled = true
		auswahl.disabled = true
	else:
		var kosten := Smith.reroll_cost(_reroll_item)
		knopf.text = Loc.pick("Neu würfeln  —  %s", "Reroll  —  %s") % _kosten_text(kosten)
		knopf.disabled = not GameState.can_pay(kosten)
		knopf.pressed.connect(func() -> void:
			if not GameState.pay(Smith.reroll_cost(_reroll_item)):
				Sfx.play(&"fehler")
				return
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			Smith.reroll(_reroll_item, rng)
			GameState.save_game()
			Sfx.play(&"schmiede")
			_ergebnis = _reroll_item
			_ergebnis_text = Loc.pick("Neu gewürfelt!", "Rerolled!")
			_refresh())
		_rechts.add_child(Bildschirm.ueberschrift(Loc.pick("Aktuell", "Current")))
		if _ergebnis != _reroll_item:
			_rechts.add_child(ItemInfo.karte(_reroll_item))
	var luecke := Control.new()
	luecke.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_links.add_child(luecke)
	_links.add_child(knopf)


func _baue_ergebnis() -> void:
	if _ergebnis == null:
		return
	_rechts.add_child(HSeparator.new())
	_rechts.add_child(Bildschirm.ueberschrift(_ergebnis_text))
	_rechts.add_child(ItemInfo.karte(_ergebnis))


# --- Helfer --------------------------------------------------------------------

## Höchste Werkstoff-Stufe, für die das Material der Kategorie reicht.
func _beste_stufe_mit_material() -> int:
	var beste := 1
	for s in range(1, 6):
		if _material_reicht(Smith.kosten(_kategorie, s, 1)):
			beste = s
	return beste


static func _material_reicht(kosten: Dictionary) -> bool:
	var mats: Dictionary = kosten.get("materials", {})
	for id in mats:
		if GameState.material_count(id) < mats[id]:
			return false
	return true


## „Braucht: 3 Mithrilerz (hast 5) · 1 Wyvernleder (hast 0)“
static func _vorrat_text(kosten: Dictionary) -> String:
	var teile: Array[String] = []
	var mats: Dictionary = kosten.get("materials", {})
	for id in mats:
		teile.append(Loc.pick("%d %s (hast %d)", "%d %s (have %d)") % [mats[id],
			MaterialLibrary.display_name(id), GameState.material_count(id)])
	return Loc.pick("Braucht: ", "Needs: ") + "  ·  ".join(teile)


static func _kosten_text(cost: Dictionary) -> String:
	var parts: Array[String] = ["%d G" % cost.get("gold", 0)]
	var mats: Dictionary = cost.get("materials", {})
	for id in mats:
		parts.append("%d %s" % [mats[id], MaterialLibrary.display_name(id)])
	return ", ".join(parts)


static func _hinweis(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.modulate = Color(1, 1, 1, 0.65)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func _zwischentitel(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	return label
