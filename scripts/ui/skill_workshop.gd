extends Control
## Skill-Werkstatt: Bausteine aus der Bibliothek per Drag&Drop in die Sockel
## der Skill-Slots ziehen (PoE-Gem-Stil, vorerst mit Platzhalter-Optik).
## Rechtsklick leert einen Sockel. Forschbare Bausteine werden hier auch
## freigeschaltet (der spätere Forschungstisch im Hub übernimmt das dann).

const MAIN_SCENE := "res://scenes/main.tscn"
const SOCKETS_PER_SKILL := 6

var _selected: Combatant = null

var _gold_label: Label
var _char_bar: HBoxContainer
var _editor_list: VBoxContainer
var _library_list: VBoxContainer
var _test_log: RichTextLabel
## Pro Skill: {"skill", "cost_label", "valid_label", "sockets": Array[SocketSlot]}
var _editors: Array[Dictionary] = []


func _ready() -> void:
	theme = UiTheme.get_theme()
	_build_layout()
	_selected = GameState.party[0]
	_rebuild_all()
	UiTheme.focus_first_button(self)


# --- Drag&Drop-Ziel: Sockel ---------------------------------------------------

class SocketSlot:
	extends PanelContainer
	## Ein Sockel eines Skills. Nimmt Bausteine per Drag&Drop an.

	var workshop: Control
	var skill: Skill
	var index: int
	var label: Label

	func _init(p_workshop: Control, p_skill: Skill, p_index: int) -> void:
		workshop = p_workshop
		skill = p_skill
		index = p_index
		custom_minimum_size = Vector2(92, 64)
		label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 11)
		add_child(label)

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("block")

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		workshop.place_block(self, data["block"])

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_RIGHT:
			workshop.clear_socket(self)


# --- Drag&Drop-Quelle: Baustein-Karte ------------------------------------------

class BlockCard:
	extends PanelContainer
	## Ein Baustein in der Bibliothek. Freigeschaltete Karten sind draggbar.

	var block: SkillBlock
	var locked := false

	func _init(p_block: SkillBlock, p_locked: bool) -> void:
		block = p_block
		locked = p_locked
		custom_minimum_size = Vector2(0, 46)

	func _get_drag_data(_pos: Vector2) -> Variant:
		if locked:
			return null
		var preview := Label.new()
		preview.text = block.display_name
		set_drag_preview(preview)
		return {"block": block}


# --- Bearbeitungslogik ---------------------------------------------------------

func place_block(socket: SocketSlot, block: SkillBlock) -> void:
	var blocks := socket.skill.blocks
	if socket.index < blocks.size():
		blocks[socket.index] = block
	else:
		blocks.append(block)
	_refresh_editors()


func clear_socket(socket: SocketSlot) -> void:
	var blocks := socket.skill.blocks
	if socket.index < blocks.size():
		blocks.remove_at(socket.index)
		_refresh_editors()


func _on_research_pressed(block: SkillBlock) -> void:
	if GameState.research(block):
		Sfx.play(&"bestaetigen")
		_rebuild_all()
	else:
		Sfx.play(&"fehler")


# --- Skill-Test ----------------------------------------------------------------
# Probiert den Skill in einem simulierten Kampf aus, damit der Spieler prüfen
# kann, ob sein Bau das tut, was er sich vorstellt: Schaden gegen Puppen mit
# und ohne Rüstung, DoTs, Buffs/Heilung auf die Party, Schutzwall etc.

func _run_skill_test(skill: Skill) -> void:
	_test_log.text = ""
	if not skill.is_valid():
		_append_test("%s ist noch nicht einsatzbereit — siehe Hinweis am Skill." % skill.display_name)
		return
	_append_test("=== Test: %s (%s) ===" % [skill.display_name, _selected.display_name])
	_append_test("MP-Kosten für %s: %d" % [_selected.display_name, skill.get_mp_cost(_selected)])

	match skill.get_form():
		Enums.SkillForm.SINGLE, Enums.SkillForm.AOE:
			_test_offensive(skill, false)
			_test_offensive(skill, true)
		Enums.SkillForm.ALLY, Enums.SkillForm.AURA, Enums.SkillForm.SELF:
			_test_supportive(skill)
		Enums.SkillForm.SUMMON:
			_test_summon(skill)


## Beschwörungs-Test: zeigt, welche Kreatur mit welchen Werten erscheint.
func _test_summon(skill: Skill) -> void:
	var caster := _clone_for_test(_selected)
	var dummy := _make_dummy(false)
	var battle := _make_test_battle([caster], [dummy])
	var lines: Array[String] = []
	battle.log_line.connect(func(text: String) -> void: lines.append(text))
	battle.use_skill(caster, skill, null)
	_append_test("— Beschwörung —")
	for line in lines:
		_append_test("  " + line)
	for ally in battle.players:
		if ally.is_summon:
			var damage_note := "%d Waffenschaden" % ally.innate_weapon_damage \
				if ally.innate_weapon_damage > 0 else "%d Zauberschaden" % ally.innate_spell_damage
			_append_test("  Werte: %d HP · %s · %d Züge"
				% [ally.max_hp, damage_note, ally.summon_turns_left])
			_append_status_list(ally, "  Status auf der Beschwörung")


## Offensiv-Test gegen eine Trainingspuppe (wahlweise gepanzert).
func _test_offensive(skill: Skill, armored: bool) -> void:
	var caster := _clone_for_test(_selected)
	var dummy := _make_dummy(armored)
	var battle := _make_test_battle([caster], [dummy])
	var lines: Array[String] = []
	battle.log_line.connect(func(text: String) -> void: lines.append(text))

	var hp_before := dummy.hp
	battle.use_skill(caster, skill, dummy)
	_append_test("— Gegen %s —" % dummy.display_name)
	for line in lines:
		if not line.begins_with("%s setzt" % caster.display_name):
			_append_test("  " + line)
	var direct := hp_before - dummy.hp
	var summary := "  Direktschaden: %d" % direct
	var dot_total := 0
	for entry in dummy.statuses:
		if entry["status"] == Enums.Status.BURN or entry["status"] == Enums.Status.POISON_DOT:
			dot_total += entry["potency"] * entry["turns"]
	if dot_total > 0:
		summary += "  ·  dazu %d Schaden über Zeit" % dot_total
	_append_test(summary)
	_append_status_list(dummy, "  Status auf dem Ziel")


## Support-Test: Wirkung auf die eigene Party (Buffs, Heilung, Wiederbelebung).
func _test_supportive(skill: Skill) -> void:
	var caster := _clone_for_test(_selected)
	var ally := _make_dummy(false)
	ally.display_name = "Verbündeter"
	ally.is_player = true
	ally.hp = roundi(ally.max_hp * 0.5)
	ally.mp = 0
	# Bei Wiederbelebungs-Skills liegt der Verbündete am Boden.
	var has_revive := false
	for effect in skill.get_effect_blocks():
		if effect.status == Enums.Status.REVIVE:
			has_revive = true
	if has_revive:
		ally.hp = 0
	var enemy := _make_dummy(false)
	var battle := _make_test_battle([caster, ally], [enemy])
	var lines: Array[String] = []
	battle.log_line.connect(func(text: String) -> void: lines.append(text))

	var ally_hp_before := ally.hp
	var ally_mp_before := ally.mp
	battle.use_skill(caster, skill, null)
	_append_test("— Wirkung auf die Party (Verbündeter mit halben HP) —")
	for line in lines:
		if not line.begins_with("%s setzt" % caster.display_name):
			_append_test("  " + line)
	if ally.hp != ally_hp_before:
		_append_test("  Verbündeter: %+d HP (jetzt %d/%d)"
			% [ally.hp - ally_hp_before, ally.hp, ally.max_hp])
	if ally.mp != ally_mp_before:
		_append_test("  Verbündeter: %+d MP" % (ally.mp - ally_mp_before))
	_append_status_list(caster, "  Status auf %s" % caster.display_name)
	_append_status_list(ally, "  Status auf dem Verbündeten")

	# Einen Zug simulieren, damit Regeneration/Mana-Fluss sichtbar ticken.
	if ally.is_alive() and not ally.statuses.is_empty():
		lines.clear()
		while true:
			var actor := battle.next_turn()
			if actor == ally or actor == null:
				break
		if not lines.is_empty():
			_append_test("  Nächster Zug des Verbündeten:")
			for line in lines:
				_append_test("    " + line)


func _append_status_list(target: Combatant, prefix: String) -> void:
	if target.statuses.is_empty():
		return
	var parts: Array[String] = []
	for entry in target.statuses:
		var text := Battle.status_display_name(entry["status"])
		if entry["potency"] > 0:
			text += " (%d)" % entry["potency"]
		text += " für %d Runden" % entry["turns"]
		parts.append(text)
	_append_test("%s: %s" % [prefix, ", ".join(parts)])


func _append_test(text: String) -> void:
	_test_log.append_text(text + "\n")


static func _clone_for_test(source: Combatant) -> Combatant:
	var copy := Combatant.create(source.display_name, source.stats.duplicated(), true)
	copy.level = source.level
	copy.equipment = source.equipment.duplicate()
	copy.recompute_derived()
	copy.hp = copy.max_hp
	copy.mp = 999999  # Kosten sollen den Test nicht blockieren
	return copy


static func _make_dummy(armored: bool) -> Combatant:
	var stats := StatBlock.new()
	stats.vitality = 100
	var dummy := Combatant.create(
		"Trainingspuppe (gepanzert)" if armored else "Trainingspuppe (ungepanzert)",
		stats, false)
	if armored:
		dummy.armor = 10
		dummy.magic_resist = 8
	return dummy


static func _make_test_battle(players: Array[Combatant], enemies: Array[Combatant]) -> Battle:
	var battle := Battle.new()
	battle.crit_enabled = false  # deterministisches Ergebnis
	battle.rng.seed = 1
	battle.start(players, enemies)
	return battle


func _select_character(member: Combatant) -> void:
	_selected = member
	_rebuild_all()


# --- UI-Aufbau -------------------------------------------------------------------

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

	# Kopfzeile: Titel · Gold · Zurück
	var head := HBoxContainer.new()
	main.add_child(head)
	var title := Label.new()
	title.text = Loc.pick("Skill-Werkstatt", "Skill workshop")
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_gold_label = Label.new()
	head.add_child(_gold_label)
	var training := Button.new()
	training.text = Loc.pick("Waffen-Training »", "Weapon training »")
	training.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/workshop/training.tscn"))
	head.add_child(training)
	var back := Button.new()
	back.text = Loc.pick("Zurück zum Menü", "Back to menu")
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(MAIN_SCENE))
	head.add_child(back)

	_char_bar = HBoxContainer.new()
	_char_bar.add_theme_constant_override("separation", 8)
	main.add_child(_char_bar)

	# Hauptbereich: links Skill-Slots, rechts Bibliothek
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	main.add_child(body)

	var editor_scroll := ScrollContainer.new()
	editor_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_scroll.size_flags_stretch_ratio = 1.6
	body.add_child(editor_scroll)
	_editor_list = VBoxContainer.new()
	_editor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_list.add_theme_constant_override("separation", 12)
	editor_scroll.add_child(_editor_list)

	var library_scroll := ScrollContainer.new()
	library_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(library_scroll)
	_library_list = VBoxContainer.new()
	_library_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_library_list.add_theme_constant_override("separation", 6)
	library_scroll.add_child(_library_list)

	var hint := Label.new()
	hint.text = Loc.pick("Bausteine per Drag&Drop in die Sockel ziehen · Rechtsklick leert einen Sockel · \"Testen\" probiert den Skill gefahrlos aus", "Drag blocks into the sockets · right-click clears a socket · \"Test\" tries the skill safely")
	hint.modulate = Color(1, 1, 1, 0.55)
	main.add_child(hint)

	_test_log = RichTextLabel.new()
	_test_log.custom_minimum_size = Vector2(0, 150)
	_test_log.scroll_following = true
	_test_log.text = Loc.pick("Skill-Test: Wähle bei einem Skill \"Testen\", um Schaden und Effekte gegen Trainingspuppen zu prüfen.", "Skill test: choose \"Test\" on a skill to check damage and effects against training dummies.")
	main.add_child(_test_log)


func _rebuild_all() -> void:
	_gold_label.text = "Gold: %d   " % GameState.gold
	_rebuild_char_bar()
	_rebuild_editors()
	_rebuild_library()


func _rebuild_char_bar() -> void:
	for child in _char_bar.get_children():
		child.queue_free()
	for member in GameState.party:
		var button := Button.new()
		button.text = "%s (Lv. %d)" % [member.display_name, member.level]
		button.disabled = member == _selected
		button.pressed.connect(_select_character.bind(member))
		_char_bar.add_child(button)


func _rebuild_editors() -> void:
	for child in _editor_list.get_children():
		child.queue_free()
	_editors.clear()

	# Skill-Liste auf Slot-Anzahl auffüllen (+1 Slot alle 5 Level).
	while _selected.skills.size() < _selected.skill_slots():
		var empty := Skill.new()
		empty.display_name = "Neuer Skill"
		_selected.skills.append(empty)

	# Genau ein Editor pro freigeschaltetem Slot.
	for i in _selected.skill_slots():
		_editor_list.add_child(_make_skill_editor(_selected.skills[i], i))
	_refresh_editors()


func _make_skill_editor(skill: Skill, slot_index: int) -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var slot_label := Label.new()
	slot_label.text = "Slot %d" % (slot_index + 1)
	slot_label.modulate = Color(1, 1, 1, 0.55)
	head.add_child(slot_label)
	var name_edit := LineEdit.new()
	name_edit.text = skill.display_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(text: String) -> void:
		skill.display_name = text)
	head.add_child(name_edit)
	var cost_label := Label.new()
	head.add_child(cost_label)
	var test_button := Button.new()
	test_button.text = Loc.pick("Testen", "Test")
	test_button.tooltip_text = "Probiert den Skill gegen Trainingspuppen aus:\nSchaden, DoTs, Buffs, Heilung — ohne Risiko."
	test_button.pressed.connect(_run_skill_test.bind(skill))
	head.add_child(test_button)

	var socket_row := HBoxContainer.new()
	socket_row.add_theme_constant_override("separation", 6)
	box.add_child(socket_row)
	var sockets: Array = []
	for i in SOCKETS_PER_SKILL:
		var socket := SocketSlot.new(self, skill, i)
		socket_row.add_child(socket)
		sockets.append(socket)

	var valid_label := Label.new()
	valid_label.add_theme_font_size_override("font_size", 12)
	box.add_child(valid_label)

	_editors.append({
		"skill": skill, "cost_label": cost_label,
		"valid_label": valid_label, "sockets": sockets,
	})
	return panel


## Aktualisiert Sockel-Beschriftungen, Kosten und Gültigkeit ohne Neuaufbau.
func _refresh_editors() -> void:
	for editor in _editors:
		var skill: Skill = editor["skill"]
		for socket in editor["sockets"]:
			if socket.index < skill.blocks.size():
				var block: SkillBlock = skill.blocks[socket.index]
				socket.label.text = _block_short_name(block)
				socket.label.modulate = _category_color(block)
				socket.modulate = Color(1, 1, 1)
			else:
				socket.label.text = Loc.pick("· leer ·", "· empty ·")
				socket.label.modulate = Color.WHITE
				socket.modulate = Color(1, 1, 1, 0.45)
		if skill.is_valid():
			editor["cost_label"].text = "%d MP" % skill.get_mp_cost(_selected)
			editor["valid_label"].text = Loc.pick("✔ Einsatzbereit", "✔ Ready")
			editor["valid_label"].modulate = Color(0.5, 1.0, 0.5)
		else:
			editor["cost_label"].text = "—"
			editor["valid_label"].modulate = Color(1.0, 0.7, 0.4)
			if skill.get_sources().is_empty():
				editor["valid_label"].text = Loc.pick("Braucht eine Quelle (Waffennutzung oder Zauber)", "Needs a source (weapon use or spell)")
			else:
				editor["valid_label"].text = Loc.pick("Waffennutzung erlaubt keine Form (Fläche/Aura/…)", "Weapon use allows no form (area/aura/…)")


func _rebuild_library() -> void:
	for child in _library_list.get_children():
		child.queue_free()

	var categories := [
		["Quelle", func(b: SkillBlock) -> bool: return b is SourceBlock,
			"Pflicht: mindestens eine. Bestimmt, woher der Schaden kommt."],
		["Element", func(b: SkillBlock) -> bool: return b is ElementBlock,
			"Optional, nur für Zauber: Elementart + Spezialeffekt."],
		["Form", func(b: SkillBlock) -> bool: return b is FormBlock,
			"Optional, nur für Zauber: wen der Skill trifft (ohne = ein Gegner)."],
		["Effekte", func(b: SkillBlock) -> bool: return b is EffectBlock,
			"Beliebig viele: Buffs, Debuffs, Schutz, Wiederbelebung."],
		["Verstärker", func(b: SkillBlock) -> bool: return b is ModifierBlock,
			"Beliebig viele: verändern, wie der Skill wirkt."],
	]
	for category in categories:
		var header := Label.new()
		header.text = category[0]
		header.add_theme_font_size_override("font_size", 16)
		header.modulate = _category_color_by_name(category[0])
		_library_list.add_child(header)
		var hint := Label.new()
		hint.text = category[2]
		hint.add_theme_font_size_override("font_size", 10)
		hint.modulate = Color(1, 1, 1, 0.5)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_library_list.add_child(hint)
		for block in BlockLibrary.all_blocks():
			if category[1].call(block):
				_library_list.add_child(_make_block_card(block))


## Kategorie-Farben: gleiche Farbe in Bibliothek UND Sockeln — man sieht
## auf einen Blick, was in einem Skill steckt.
static func _category_color(block: SkillBlock) -> Color:
	if block is SourceBlock:
		return Color(1.0, 0.75, 0.45)   # Orange: Quelle
	if block is ElementBlock:
		return Color(0.6, 0.85, 1.0)    # Hellblau: Element
	if block is FormBlock:
		return Color(0.75, 1.0, 0.7)    # Grün: Form
	if block is EffectBlock:
		return Color(0.95, 0.75, 1.0)   # Violett: Effekt
	if block is ModifierBlock:
		return Color(1.0, 0.95, 0.55)   # Gelb: Verstärker
	return Color.WHITE


static func _category_color_by_name(name: String) -> Color:
	match name:
		"Quelle": return Color(1.0, 0.75, 0.45)
		"Element": return Color(0.6, 0.85, 1.0)
		"Form": return Color(0.75, 1.0, 0.7)
		"Effekte": return Color(0.95, 0.75, 1.0)
		"Verstärker": return Color(1.0, 0.95, 0.55)
	return Color.WHITE


func _make_block_card(block: SkillBlock) -> Control:
	var unlocked: bool = GameState.is_block_unlocked(block, _selected.level, _selected)
	var card := BlockCard.new(block, not unlocked)
	card.tooltip_text = _block_description(block)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	# Kategorie-Farbstreifen: gleiche Farbe wie in den Sockeln.
	var stripe := ColorRect.new()
	stripe.color = _category_color(block)
	stripe.custom_minimum_size = Vector2(4, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stripe)

	var name_label := Label.new()
	name_label.text = block.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	if unlocked:
		var info := Label.new()
		info.text = _block_short_summary(block)
		info.modulate = Color(1, 1, 1, 0.55)
		info.add_theme_font_size_override("font_size", 11)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(info)
	elif block.unlock_kind == Enums.UnlockKind.RESEARCH:
		card.modulate = Color(1, 1, 1, 0.6)
		var research := Button.new()
		research.text = Loc.pick("Forschen (%d G)", "Research (%d G)") % block.research_cost_gold
		research.disabled = not GameState.can_research(block)
		research.pressed.connect(_on_research_pressed.bind(block))
		row.add_child(research)
	elif block.unlock_kind == Enums.UnlockKind.TRAINING:
		card.modulate = Color(1, 1, 1, 0.4)
		var lock := Label.new()
		lock.text = Loc.pick("Training %s %d (hat: %d)", "training %s %d (has: %d)") \
			% [BlockLibrary.family_label(block.tree_family), block.tree_points,
			_selected.invested(block.tree_family)]
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lock)
	else:
		card.modulate = Color(1, 1, 1, 0.4)
		var lock := Label.new()
		lock.text = Loc.pick("ab Lv. %d", "from lv. %d") % block.unlock_level
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lock)
	return card


# --- Baustein-Beschreibungen ------------------------------------------------------

static func _block_short_name(block: SkillBlock) -> String:
	return block.display_name if not block.display_name.is_empty() else "Baustein"


static func _block_short_summary(block: SkillBlock) -> String:
	if block is SourceBlock:
		return "Waffennutzung" if block.source == Enums.SkillSource.WEAPON else "Zauber"
	if block is ElementBlock:
		return "Element"
	if block is FormBlock:
		return "Form"
	if block is EffectBlock:
		return "Effekt"
	if block is ModifierBlock:
		return "Verstärker"
	return ""


static func _block_description(block: SkillBlock) -> String:
	var lines: Array[String] = []
	if block is SourceBlock:
		if block.source == Enums.SkillSource.WEAPON:
			lines.append("Physischer Angriff: Schaden + Art von der Waffe (Einzelziel)")
		else:
			lines.append("Zauber: Zauberschaden der Waffe + INT (Standard Einzelziel)")
	elif block is ElementBlock:
		match block.element:
			Enums.Element.FIRE:
				lines.append("Feuer: Brand-Stacks nach Schaden — hoher Burst,")
				lines.append("halbieren sich aber nach jedem Tick")
			Enums.Element.POISON:
				lines.append("Gift: weniger Stacks, aber sie bleiben")
				lines.append("bestehen, bis sie kuriert werden")
			Enums.Element.ICE:
				lines.append("Eis: Chance einzufrieren (setzt aus) —")
				lines.append("physische Treffer zerschmettern das Eis für Bonusschaden")
			Enums.Element.LIGHTNING:
				lines.append("Blitz: springt auf ein weiteres Ziel über,")
				lines.append("Chance zu betäuben")
			Enums.Element.HOLY:
				lines.append("Heilig: Bonus gegen Untote; mit Form")
				lines.append("Verbündeter/Aura/Selbst wird Schaden zu Heilung")
			Enums.Element.DARK:
				lines.append("Dunkel: raubt Leben und verflucht das Ziel")
				lines.append("(nimmt mehr Schaden)")
	elif block is FormBlock:
		match block.form:
			Enums.SkillForm.AOE: lines.append("Fläche: trifft alle Gegner (schwächer, teurer)")
			Enums.SkillForm.ALLY: lines.append("Verbündeter: ein gewählter Kamerad")
			Enums.SkillForm.AURA: lines.append("Aura: wirkt auf die ganze Party")
			Enums.SkillForm.SELF: lines.append("Selbst: nur der Anwender")
			Enums.SkillForm.SUMMON:
				lines.append("Beschwört einen Verbündeten (ohne Element: Wolf,")
				lines.append("mit Element: Elementar; Effekte wirken auf ihn)")
	elif block is EffectBlock:
		lines.append("%s: %d%% Chance, %d Runden"
			% [Battle.status_display_name(block.status), block.chance_percent,
				block.duration_turns])
		if block.potency > 0:
			lines.append("Stärke: %d" % block.potency)
	elif block is ModifierBlock:
		match block.modifier:
			Enums.SkillModifier.POWER_AMP:
				lines.append("+%d%% Schaden" % block.magnitude)
			Enums.SkillModifier.COST_REDUCTION:
				lines.append("-%d%% MP-Kosten" % block.magnitude)
			Enums.SkillModifier.MULTI_HIT:
				lines.append("+%d zusätzliche Treffer" % block.magnitude)
			Enums.SkillModifier.CHAIN_ON_KILL:
				lines.append("Springt bei Kill über (max. %d Sprünge)" % block.magnitude)
			Enums.SkillModifier.SPREAD:
				lines.append("Einzelziel: %d%% des Schadens auf alle anderen" % block.magnitude)
			Enums.SkillModifier.PIERCE_ARMOR:
				lines.append("Ignoriert %d%% der Rüstung/Resistenz" % block.magnitude)
			Enums.SkillModifier.EXECUTE:
				lines.append("+%d%% Schaden gegen Ziele unter 30%% HP" % block.magnitude)
			Enums.SkillModifier.OVERLOAD:
				lines.append("+%d%% Schaden, aber +50%% MP-Kosten" % block.magnitude)
			Enums.SkillModifier.VS_UNDEAD:
				lines.append("+%d%% Schaden gegen Untote" % block.magnitude)
			Enums.SkillModifier.RAGE:
				lines.append("Wut: bis +%d%% Schaden, je mehr eigene HP fehlen" % block.magnitude)
			Enums.SkillModifier.OPENER:
				lines.append("Volltreffer: +%d%% gegen Ziele über 95%% HP" % block.magnitude)
			Enums.SkillModifier.ECHO:
				lines.append("Echo: wiederholt sich nächste Runde mit %d%% Kraft" % block.magnitude)
			Enums.SkillModifier.OVERHEAL_SHIELD:
				lines.append("Überheilung: %d%% des Überschusses werden Schild-HP" % block.magnitude)
	if not block.weapon_families.is_empty():
		lines.append(Loc.pick("WAFFENTECHNIK — nur mit: %s", "WEAPON TECHNIQUE — only with: %s")
			% BlockLibrary.families_label(block.weapon_families))
		lines.append(Loc.pick("(braucht Waffennutzung als Quelle)", "(requires weapon use as source)"))
	if block.mp_cost > 0:
		lines.append("Kostenbeitrag: %d MP" % block.mp_cost)
	return "\n".join(lines)
