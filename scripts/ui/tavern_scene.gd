extends Control
## Taverne: Helden kostenlos anheuern, bis die Party voll ist (4).
## Jeder Rekrut startet identisch (Level 1, überall 5) — nur das gewählte
## Starter-Kit (Waffe + erster Skill) gibt eine Richtung vor.

const MAIN_SCENE := "res://scenes/main.tscn"

var _party_box: VBoxContainer
var _reserve_box: VBoxContainer
var _recruit_box: VBoxContainer
var _msg_label: Label
var _studio: PortraitStudio  ## 3D-Porträts der Helden


func _ready() -> void:
	theme = UiTheme.get_theme()
	Music.play(&"stadt")
	_build_layout()
	_refresh()
	UiTheme.focus_first_button(self)


func _build_layout() -> void:
	var b := Bildschirm.bauen(self, Loc.pick("Taverne", "Tavern"), &"taverne",
		func() -> void: get_tree().change_scene_to_file(MAIN_SCENE), Loc.pick("Menü", "Menu"),
		UiTheme.town_tabs(&"taverne"))
	_studio = PortraitStudio.new()
	add_child(_studio)
	b.setze_untertitel(Loc.pick("Erstelle bis zu %d eigene Helden (Name, Rüstungsfarbe, Start-Kit) — kostenlos. "
		+ "Jeder startet gleich (Level 1, überall 5), niemand stirbt dauerhaft. "
		+ "Maximal 4 sind aktiv — der Rest wartet auf der Bank (Platz für Co-op-Gäste!). "
		+ "XP wird auf die aktiven Helden geteilt — der mit dem niedrigsten Level bekommt die Hälfte (Nachzügler-Bonus). "
		+ "So holt ein eingewechselter Held schnell auf; wer einen Helden ganz allein leveln will, setzt die anderen auf die Bank. "
		+ "Bank-Helden trainieren mit (10 %% der Kampf-XP) bis 5 Level unter den Schwächsten der Party — oder sofort gegen Gold.",
		"Create up to %d heroes of your own (name, armor color, starter kit) — free. "
		+ "Everyone starts the same (level 1, 5 everywhere), nobody dies permanently. "
		+ "Up to 4 are active — the rest waits on the bench (room for co-op guests!). "
		+ "XP is split among the active heroes — the lowest-level one gets half (catch-up bonus). "
		+ "A swapped-in hero catches up fast; to level one hero alone, bench the others. "
		+ "Benched heroes train along (10%% of battle XP) up to 5 levels below the party's weakest — or instantly for gold.") \
		% HeroLibrary.MAX_HEROES)
	var root := b.inhalt

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	_party_box = _column(columns, Loc.pick("Deine Party", "Your party"), 8)
	_reserve_box = _column(columns, Loc.pick("Auf der Bank", "On the bench"), 8)
	_recruit_box = _column(columns, Loc.pick("Neuer Held", "New hero"), 10)

	_msg_label = Label.new()
	_msg_label.modulate = Color(1.0, 0.9, 0.5)
	root.add_child(_msg_label)


## Eine Spalte mit Überschrift; liefert die Inhalts-Box zurück.
func _column(columns: HBoxContainer, title_text: String, separation: int) -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	var tafel := Bildschirm.tafel(panel)
	tafel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(tafel)
	panel.add_child(Bildschirm.ueberschrift(title_text))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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

	_recruit_box.add_child(_creation_form())


func _member_row(member: Combatant, in_party: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_portrait(_studio.textur(FigurenBau.schluessel_fuer(member),
		func() -> Node3D: return FigurenBau.held_aus(member))))
	var label := Label.new()
	label.text = Loc.pick("%s — Level %d   HP %d/%d", "%s — level %d   HP %d/%d") % [member.display_name, member.level,
		member.hp, member.max_hp]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 120  # bricht um, statt die Spalte zu sprengen
	row.add_child(label)

	if member.has_meta(&"guest_peer"):
		var guest_tag := Label.new()
		guest_tag.text = Loc.pick("Co-op-Gast", "co-op guest")
		guest_tag.modulate = Color(0.7, 0.85, 1.0)
		row.add_child(guest_tag)
		return row

	var swap := Button.new()
	# Co-op-Gast: Party-Umbau gesperrt — der eigene Held ist gerade in der
	# Welt des Hosts unterwegs, Umbauten würden die XP-Heimnahme zerreißen.
	if Net.is_guest():
		swap.text = Loc.pick("Gesperrt (Co-op)", "Locked (co-op)")
		swap.disabled = true
		swap.tooltip_text = Loc.pick("Erst die Co-op-Session verlassen.",
			"Leave the co-op session first.")
		row.add_child(swap)
		return row
	if in_party:
		swap.text = Loc.pick("Auf die Bank", "To the bench")
		swap.disabled = not _can_bench(member)
		swap.pressed.connect(func() -> void:
			if GameState.bench_hero(member):
				GameState.save_game()
				Sfx.play(&"bestaetigen")
				_refresh())
	else:
		# Taverne-Training: gegen Gold auf 5 Level unter den Schwächsten der Party.
		var ziel := GameState.bank_ziel_level()
		if member.level < ziel:
			var kosten := GameState.training_kosten(member)
			var trainieren := Button.new()
			trainieren.text = Loc.pick("Training » Lv %d\n%d Gold", "Train » lv %d\n%d gold") % [ziel, kosten]
			trainieren.disabled = GameState.gold < kosten
			trainieren.tooltip_text = Loc.pick(
				"Holt den Helden auf 5 Level unter den Schwächsten der Party — mit allen Status- und Skillpunkten.",
				"Brings the hero up to 5 levels below the party's weakest — with all stat and skill points.")
			trainieren.pressed.connect(func() -> void:
				if GameState.bank_trainieren(member):
					GameState.save_game()
					Sfx.play(&"level_up")
					_refresh())
			row.add_child(trainieren)
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


## Charakter-Erstellung: freier Name, wählbares Porträt, Starter-Kit.
func _creation_form() -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var counter := Label.new()
	counter.text = Loc.pick("Helden: %d/%d", "Heroes: %d/%d") \
		% [GameState.hero_count(), HeroLibrary.MAX_HEROES]
	counter.modulate = Color(1, 1, 1, 0.6)
	box.add_child(counter)

	if GameState.hero_count() >= HeroLibrary.MAX_HEROES:
		var full := Label.new()
		full.text = Loc.pick("Alle Helden-Slots sind belegt.", "All hero slots are taken.")
		full.modulate = Color(1, 1, 1, 0.6)
		box.add_child(full)
		return panel

	# Name (mit freiem Vorschlag vorbelegt).
	var name_edit := LineEdit.new()
	name_edit.text = HeroLibrary.suggest_name(GameState.party + GameState.reserve)
	name_edit.max_length = 24
	name_edit.placeholder_text = Loc.pick("Name des Helden", "Hero name")
	box.add_child(name_edit)

	# Rüstungsfarbe + Startwaffe mit drehender 3D-Vorschau daneben.
	var portrait_row := HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 12)
	box.add_child(portrait_row)
	var preview := FigurenVorschau.new(Vector2i(120, 150))
	portrait_row.add_child(preview)
	var waehler := VBoxContainer.new()
	waehler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	waehler.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_row.add_child(waehler)
	var portrait_select := FigurenBau.farb_auswahl(_studio)
	portrait_select.select(GameState.hero_count() % SpriteLib.HERO_PORTRAITS.size())
	waehler.add_child(portrait_select)

	# Startwaffe wählen (keine Klasse!) — mit den echten Waffenwerten.
	var loadout_select := OptionButton.new()
	for loadout_id in HeroLibrary.STARTER_LOADOUTS:
		loadout_select.add_item(HeroLibrary.loadout_label(loadout_id))
		loadout_select.set_item_metadata(loadout_select.item_count - 1, loadout_id)
	waehler.add_child(loadout_select)
	var vorschau_zeigen := func(_index := 0) -> void:
		preview.zeige(FigurenBau.starter_held(
			portrait_select.get_item_metadata(portrait_select.selected),
			loadout_select.get_item_metadata(loadout_select.selected)))
	portrait_select.item_selected.connect(vorschau_zeigen)
	loadout_select.item_selected.connect(vorschau_zeigen)
	vorschau_zeigen.call()
	var stats_label := Label.new()
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.modulate = Color(0.75, 0.9, 1.0)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.text = HeroLibrary.loadout_description(
		loadout_select.get_item_metadata(0))
	loadout_select.item_selected.connect(func(index: int) -> void:
		stats_label.text = HeroLibrary.loadout_description(
			loadout_select.get_item_metadata(index)))
	box.add_child(stats_label)

	var create := Button.new()
	var to_bench := GameState.party.size() >= HeroLibrary.MAX_PARTY_SIZE
	create.text = Loc.pick("Erstellen (kostenlos)", "Create (free)") \
		+ (Loc.pick(" » Bank", " » bench") if to_bench else "")
	create.pressed.connect(func() -> void:
		if Net.is_guest():
			Sfx.play(&"fehler")
			_msg_label.text = Loc.pick("Als Co-op-Gast gesperrt — erst die Session verlassen.",
				"Locked as a co-op guest — leave the session first.")
			return
		var hero_name := name_edit.text.strip_edges()
		var kit_id: StringName = loadout_select.get_item_metadata(loadout_select.selected)
		var tile: int = portrait_select.get_item_metadata(portrait_select.selected)
		if GameState.recruit(hero_name, kit_id, tile):
			GameState.save_game()
			Sfx.play(&"bestaetigen")
			_msg_label.text = Loc.pick("%s schließt sich der Party an!", "%s joins the party!") % hero_name \
				if not to_bench else Loc.pick("%s wartet auf der Bank.", "%s waits on the bench.") % hero_name
			_refresh()
		else:
			Sfx.play(&"fehler")
			_msg_label.text = Loc.pick("Name fehlt oder ist schon vergeben.",
				"Name missing or already taken."))
	box.add_child(create)
	return panel


func _portrait(texture: Texture2D) -> Control:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(48, 48)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect
