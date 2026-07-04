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
		_rebuild_all()


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
			_append_test("Beschwörungen sind noch nicht implementiert.")


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
	title.text = "Skill-Werkstatt"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_gold_label = Label.new()
	head.add_child(_gold_label)
	var back := Button.new()
	back.text = "Zurück zum Menü"
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
	hint.text = "Bausteine per Drag&Drop in die Sockel ziehen · Rechtsklick leert einen Sockel · \"Testen\" probiert den Skill gefahrlos aus"
	hint.modulate = Color(1, 1, 1, 0.55)
	main.add_child(hint)

	_test_log = RichTextLabel.new()
	_test_log.custom_minimum_size = Vector2(0, 150)
	_test_log.scroll_following = true
	_test_log.text = "Skill-Test: Wähle bei einem Skill \"Testen\", um Schaden und Effekte gegen Trainingspuppen zu prüfen."
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
	test_button.text = "Testen"
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
				socket.label.text = _block_short_name(skill.blocks[socket.index])
				socket.modulate = Color(1, 1, 1)
			else:
				socket.label.text = "· leer ·"
				socket.modulate = Color(1, 1, 1, 0.45)
		if skill.is_valid():
			editor["cost_label"].text = "%d MP" % skill.get_mp_cost(_selected)
			editor["valid_label"].text = "✔ Einsatzbereit"
			editor["valid_label"].modulate = Color(0.5, 1.0, 0.5)
		else:
			editor["cost_label"].text = "—"
			editor["valid_label"].modulate = Color(1.0, 0.7, 0.4)
			if skill.get_sources().is_empty():
				editor["valid_label"].text = "Braucht eine Quelle (Waffennutzung oder Zauber)"
			else:
				editor["valid_label"].text = "Waffennutzung erlaubt keine Form (Fläche/Aura/…)"


func _rebuild_library() -> void:
	for child in _library_list.get_children():
		child.queue_free()

	var categories := [
		["Quelle", func(b: SkillBlock) -> bool: return b is SourceBlock],
		["Element", func(b: SkillBlock) -> bool: return b is ElementBlock],
		["Form", func(b: SkillBlock) -> bool: return b is FormBlock],
		["Effekte", func(b: SkillBlock) -> bool: return b is EffectBlock],
		["Verstärker", func(b: SkillBlock) -> bool: return b is ModifierBlock],
	]
	for category in categories:
		var header := Label.new()
		header.text = category[0]
		header.add_theme_font_size_override("font_size", 16)
		_library_list.add_child(header)
		for block in BlockLibrary.all_blocks():
			if category[1].call(block):
				_library_list.add_child(_make_block_card(block))


func _make_block_card(block: SkillBlock) -> Control:
	var unlocked: bool = GameState.is_block_unlocked(block, _selected.level)
	var card := BlockCard.new(block, not unlocked)
	card.tooltip_text = _block_description(block)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

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
		research.text = "Forschen (%d G)" % block.research_cost_gold
		research.disabled = not GameState.can_research(block)
		research.pressed.connect(_on_research_pressed.bind(block))
		row.add_child(research)
	else:
		card.modulate = Color(1, 1, 1, 0.4)
		var lock := Label.new()
		lock.text = "ab Lv. %d" % block.unlock_level
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
			Enums.SkillForm.SUMMON: lines.append("Beschwörung (noch nicht implementiert)")
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
	if block.mp_cost > 0:
		lines.append("Kostenbeitrag: %d MP" % block.mp_cost)
	return "\n".join(lines)
