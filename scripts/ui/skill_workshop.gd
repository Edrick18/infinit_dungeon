extends Control
## Skill-Werkstatt (Baukasten 2.0): Bausteine per Drag&Drop ODER Klick in die
## Sockel der Skills stecken. Jeder Klotz hat ein 3D-Icon (KlotzIcons); beim
## Ziehen zeigen die Sockel grün/rot, ob der Klotz dort passt (und warum
## nicht). Unter jedem Skill steht live, was er tut (Vorschau gegen eine
## Trainingspuppe). Vorlagen füllen einen Slot mit einem fertigen Rezept aus
## freigeschalteten Klötzen. Rechtsklick leert einen Sockel.

const MAIN_SCENE := "res://scenes/main.tscn"
const OK_FARBE := Color(0.45, 1.0, 0.55)
const NEIN_FARBE := Color(1.0, 0.42, 0.4)
const VORSCHAU_FARBE := Color(0.72, 0.88, 1.0)

var _selected: Combatant = null
var _studio: PortraitStudio

var _gold_label: Label
var _char_bar: HBoxContainer
var _editor_list: VBoxContainer
var _library_list: VBoxContainer
var _test_log: RichTextLabel
var _sockel_label: Label
var _gesperrte_zeigen := true
## Skill, in den ein Klick auf einen Klotz geht (goldener Rahmen).
var _aktiv_index := 0
## Gerade gezogener Klotz — die Sockel zeigen dann grün/rot.
var _ziehen: SkillBlock = null
## Ungespeicherte Änderungen (gespeichert wird beim Verlassen).
## Welche Vorlage zuletzt vor dem Ersetzen eines belegten Slots gewarnt hat.
var _vorlage_warnung := ""
var _geaendert := false
## Pro Skill: {"skill", "panel", "cost_label", "valid_label", "vorschau", "sockets"}
var _editors: Array[Dictionary] = []
## Rechte Spalte: &"bausteine" oder &"buch" (Rezeptbuch).
var _rechts_modus := &"bausteine"
var _tab_bausteine: Button
var _tab_buch: Button
var _filter: CheckButton


func _ready() -> void:
	theme = UiTheme.get_theme()
	Music.play(&"menu")
	_studio = PortraitStudio.new()
	add_child(_studio)
	_build_layout()
	_selected = GameState.party[0]
	_rebuild_all()
	UiTheme.focus_first_button(self)
	if GameState.first_time("werkstatt"):
		UiTheme.show_hint(self, Loc.pick("Die Skill-Werkstatt", "The skill workshop"),
			Loc.pick("Skills baust du selbst aus BAUSTEINEN: eine Quelle (Waffenangriff oder Zauber), dazu Form, Element und Zutaten nach Geschmack.\n\nZiehe einen Klotz in einen Sockel oder klicke ihn an (er landet im gold umrandeten Skill). Beim Ziehen zeigen die Sockel GRÜN, wenn er passt, und ROT mit Grund, wenn nicht. Unter jedem Skill steht live, was er tut.\n\nJeder Skill hat SOCKEL (3 zu Beginn, mehr mit höherem Level). Jeder Klotz passt nur einmal hinein, ◆-Klötze nur einer pro Gruppe, ★-Kern-Klötze nur einer pro Skill. Eigenschaften multiplizieren MP-Kosten und Schaden; der Zusatztreffer darf mehrfach hinein.\n\nKeine Idee? Unter \"Vorlage\" stecken fertige Rezepte aus deinen freigeschalteten Klötzen.",
			"You build skills yourself from BLOCKS: a source (weapon attack or spell), plus form, element and ingredients to taste.\n\nDrag a block into a socket or click it (it goes into the gold-framed skill). While dragging, sockets show GREEN when it fits and RED with a reason when not. Each skill shows live what it does.\n\nEvery skill has SOCKETS (3 at first, more at higher levels). Each block fits only once, ◆ blocks only one per group, ★ core blocks only one per skill. Traits multiply MP cost and damage; the extra hit may go in several times.\n\nNo idea? \"Template\" holds ready-made recipes from your unlocked blocks."))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var daten: Variant = get_viewport().gui_get_drag_data()
		if daten is Dictionary and daten.has("block"):
			_ziehen = daten["block"]
			_refresh_editors()
	elif what == NOTIFICATION_DRAG_END and _ziehen != null:
		_ziehen = null
		_refresh_editors()


func _exit_tree() -> void:
	if _geaendert:
		GameState.save_game()


func _zurueck() -> void:
	var ziel := GameState.ui_return_scene
	GameState.ui_return_scene = ""
	get_tree().change_scene_to_file(ziel if not ziel.is_empty() else MAIN_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	# Esc übernimmt die Bildschirm-Vorlage; die Werkstatt-Taste schließt auch.
	if event is InputEventKey and event.pressed and not event.echo \
			and event.is_action_pressed(&"open_workshop"):
		get_viewport().set_input_as_handled()
		_zurueck()


# --- Drag&Drop-Ziel: Sockel ---------------------------------------------------

class SocketSlot:
	extends PanelContainer
	## Ein Sockel eines Skills: Icon + Name. Nimmt passende Klötze an.

	var workshop: Control
	var skill: Skill
	var index: int
	var icon: TextureRect
	var label: Label

	func _init(p_workshop: Control, p_skill: Skill, p_index: int) -> void:
		workshop = p_workshop
		skill = p_skill
		index = p_index
		custom_minimum_size = Vector2(84, 92)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(54, 54)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.custom_minimum_size = Vector2(76, 0)
		label.add_theme_font_size_override("font_size", 10)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)
		# KI-Brücke: ein belegter Sockel lässt sich leeren (wie Rechtsklick).
		set_meta(&"ki_text", func() -> String:
			if index >= skill.blocks.size():
				return ""
			return Loc.pick("Sockel %d leeren: %s", "Clear socket %d: %s") \
				% [index + 1, skill.blocks[index].display_name])
		set_meta(&"ki_klick", func() -> void: workshop.clear_socket(self))

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("block") \
			and workshop.passt(skill, index, data["block"]).is_empty()

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		workshop.place_block(self, data["block"])

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				workshop.clear_socket(self)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				workshop.aktiv_waehlen(skill)


# --- Drag&Drop-Quelle: Baustein-Karte ------------------------------------------

class BlockCard:
	extends PanelContainer
	## Ein Baustein in der Bibliothek: ziehen ODER anklicken.

	var workshop: Control
	var block: SkillBlock
	var locked := false
	var icon_tex: Texture2D

	func _init(p_workshop: Control, p_block: SkillBlock, p_locked: bool, p_icon: Texture2D) -> void:
		workshop = p_workshop
		block = p_block
		locked = p_locked
		icon_tex = p_icon
		custom_minimum_size = Vector2(0, 50)
		mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
		# KI-Brücke: freie Klötze wie ein Klick (landet im aktiven Skill).
		if not locked:
			set_meta(&"ki_text", Loc.pick("Klotz: %s", "Block: %s") % block.display_name)
			set_meta(&"ki_klick", func() -> void: workshop.klotz_hinzufuegen(block))

	func _get_drag_data(_pos: Vector2) -> Variant:
		if locked:
			return null
		var vorschau := HBoxContainer.new()
		var bild := TextureRect.new()
		bild.texture = icon_tex
		bild.custom_minimum_size = Vector2(44, 44)
		bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vorschau.add_child(bild)
		var name_label := Label.new()
		name_label.text = block.display_name
		vorschau.add_child(name_label)
		set_drag_preview(vorschau)
		return {"block": block}

	func _gui_input(event: InputEvent) -> void:
		if locked:
			return
		if event is InputEventMouseButton and not event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			workshop.klotz_hinzufuegen(block)


# --- Bearbeitungslogik ---------------------------------------------------------

## Passt `block` in Sockel `index`? "" = ja, sonst der Grund (WerkstattLogik).
func passt(skill: Skill, index: int, block: SkillBlock) -> String:
	return WerkstattLogik.passt(skill, index, block, _selected)


func place_block(socket: SocketSlot, block: SkillBlock) -> void:
	var blocks := socket.skill.blocks
	if socket.index < blocks.size():
		blocks[socket.index] = block
	else:
		blocks.append(block)
	Sfx.play(&"bestaetigen")
	aktiv_waehlen(socket.skill)
	_aendern()


func clear_socket(socket: SocketSlot) -> void:
	var blocks := socket.skill.blocks
	if socket.index < blocks.size():
		blocks.remove_at(socket.index)
		_aendern()


## Klick auf einen Klotz: in den nächsten freien Sockel des aktiven Skills.
func klotz_hinzufuegen(block: SkillBlock) -> void:
	if _editors.is_empty():
		return
	var editor: Dictionary = _editors[clampi(_aktiv_index, 0, _editors.size() - 1)]
	var skill: Skill = editor["skill"]
	var grund := ""
	if skill.blocks.size() >= _selected.block_sockets():
		grund = Loc.pick("Alle Sockel belegt — erst einen leeren (Rechtsklick).",
			"All sockets taken — clear one first (right-click).")
	else:
		grund = passt(skill, skill.blocks.size(), block)
	if not grund.is_empty():
		Sfx.play(&"fehler")
		editor["valid_label"].text = "✕ " + grund
		editor["valid_label"].modulate = NEIN_FARBE
		return
	skill.blocks.append(block)
	Sfx.play(&"bestaetigen")
	_aendern()


func aktiv_waehlen(skill: Skill) -> void:
	var vorher := _aktiv_index
	for i in _editors.size():
		if _editors[i]["skill"] == skill:
			_aktiv_index = i
	_refresh_editors()
	if _rechts_modus == &"buch" and vorher != _aktiv_index:
		_rebuild_library()  # „In Slot N“ zeigt den neuen Ziel-Slot


func _aendern() -> void:
	_geaendert = true
	_refresh_editors()


## Vorlagen, die dieser Held bauen kann (alle Klötze frei, passt in die Sockel).
func _vorlagen_fuer_helden() -> Array[Skill]:
	return WerkstattLogik.vorlagen(WerkstattLogik.REZEPTE, _selected, func(block: SkillBlock) -> bool:
		return GameState.is_block_unlocked(block, _selected.level, _selected))


## Alte Skills (vor den Bauregeln) auf gültige Klötze zurückstutzen.
func _reparieren(skill: Skill) -> void:
	skill.blocks = WerkstattLogik.repariert(skill.blocks, _selected)
	Sfx.play(&"bestaetigen")
	_geaendert = true
	_rebuild_editors()


## Dezimalzahl mit Komma im Deutschen, Punkt im Englischen.
static func _dez(wert: float, stellen: int) -> String:
	var text := String.num(wert, stellen)
	return text if Loc.language == "en" else text.replace(".", ",")


func _vorlage_anwenden(skill: Skill, vorlage: Skill) -> void:
	# Ein belegter Slot wird erst beim zweiten Wählen derselben Vorlage ersetzt.
	if not skill.get_sources().is_empty():
		var schluessel := "%d:%s" % [skill.get_instance_id(), vorlage.display_name]
		if _vorlage_warnung != schluessel:
			_vorlage_warnung = schluessel
			_test_log.text = Loc.pick("„%s“ ersetzt den Skill „%s“ in diesem Slot. Vorlage noch einmal wählen zum Bestätigen.",
				"\"%s\" replaces the skill \"%s\" in this slot. Pick the template again to confirm.") \
				% [vorlage.display_name, skill.display_name]
			return
	_vorlage_warnung = ""
	skill.blocks = vorlage.blocks.duplicate()
	skill.display_name = vorlage.display_name
	_geaendert = true
	Sfx.play(&"bestaetigen")
	_rebuild_editors()


# --- Skill-Test ----------------------------------------------------------------
# Probiert den Skill in einem simulierten Kampf aus, damit der Spieler prüfen
# kann, ob sein Bau das tut, was er sich vorstellt: Schaden gegen Puppen mit
# und ohne Rüstung, DoTs, Buffs/Heilung auf die Party, Schutzwall etc.

func _run_skill_test(skill: Skill) -> void:
	_test_log.text = ""
	if not skill.is_valid(_selected):
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
	copy.peak_level = source.peak_level
	copy.rebirths = source.rebirths
	copy.weapon_invest = source.weapon_invest.duplicate()  # Trainings-Boni zählen mit
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
	# Aus dem Dungeon geöffnet (Taste K) » zurück an dieselbe Stelle.
	var ziel := Loc.pick("Dungeon", "Dungeon") if not GameState.ui_return_scene.is_empty() \
		else Loc.pick("Menü", "Menu")
	var b := Bildschirm.bauen(self, Loc.pick("Skill-Werkstatt", "Skill workshop"), &"lager", _zurueck, ziel)
	b.zurueck.tooltip_text = Loc.pick("Zurück (Esc / %s)", "Back (Esc / %s)") % Settings.key_name(&"open_workshop")
	_gold_label = b.info("")
	var training := Button.new()
	training.text = Loc.pick("Waffen-Training »", "Weapon training »")
	training.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/workshop/training.tscn"))
	b.kopf_info.add_child(training)
	var main := b.inhalt
	main.add_theme_constant_override("separation", 8)

	_char_bar = HBoxContainer.new()
	_char_bar.add_theme_constant_override("separation", 8)
	main.add_child(_char_bar)

	_sockel_label = Label.new()
	_sockel_label.add_theme_color_override("font_color", UiTheme.GOLD)
	main.add_child(_sockel_label)

	# Hauptbereich: links die Skills, rechts die Bibliothek
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	main.add_child(body)

	var editor_scroll := ScrollContainer.new()
	editor_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_scroll.size_flags_stretch_ratio = 1.5
	editor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(editor_scroll)
	_editor_list = VBoxContainer.new()
	_editor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_list.add_theme_constant_override("separation", 10)
	editor_scroll.add_child(_editor_list)

	var rechts := VBoxContainer.new()
	rechts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rechts.add_theme_constant_override("separation", 6)
	body.add_child(rechts)
	# Reiter: Bausteine (die Klötze) | Rezeptbuch (gespeicherte Bauten)
	var bib_kopf := HBoxContainer.new()
	bib_kopf.add_theme_constant_override("separation", 6)
	rechts.add_child(bib_kopf)
	_tab_bausteine = Button.new()
	_tab_bausteine.text = Loc.pick("Bausteine", "Blocks")
	_tab_bausteine.pressed.connect(_rechts_zeigen.bind(&"bausteine"))
	bib_kopf.add_child(_tab_bausteine)
	_tab_buch = Button.new()
	_tab_buch.tooltip_text = Loc.pick("Deine gespeicherten Bauten — beliebig viele. In den Kampf gehen nur die Skills in den Slots.",
		"Your saved builds — as many as you like. Only the skills in the slots go into battle.")
	_tab_buch.pressed.connect(_rechts_zeigen.bind(&"buch"))
	bib_kopf.add_child(_tab_buch)
	var luecke := Control.new()
	luecke.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bib_kopf.add_child(luecke)
	_filter = CheckButton.new()
	_filter.text = Loc.pick("Gesperrte zeigen", "Show locked")
	_filter.button_pressed = _gesperrte_zeigen
	_filter.toggled.connect(func(an: bool) -> void:
		_gesperrte_zeigen = an
		_rebuild_library())
	bib_kopf.add_child(_filter)
	var library_scroll := ScrollContainer.new()
	library_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rechts.add_child(library_scroll)
	_library_list = VBoxContainer.new()
	_library_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_library_list.add_theme_constant_override("separation", 5)
	library_scroll.add_child(_library_list)

	var hint := Label.new()
	hint.text = Loc.pick("Klotz ziehen oder anklicken (landet im gold umrandeten Skill) · Rechtsklick leert einen Sockel · beim Ziehen: grün = passt, rot = Regelbruch",
		"Drag or click a block (goes into the gold-framed skill) · right-click clears a socket · while dragging: green = fits, red = breaks a rule")
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.add_theme_font_size_override("font_size", 12)
	main.add_child(hint)

	_test_log = RichTextLabel.new()
	_test_log.custom_minimum_size = Vector2(0, 110)
	_test_log.scroll_following = true
	_test_log.add_theme_stylebox_override("normal", UiTheme.glas_tafel())
	_test_log.text = Loc.pick("Skill-Test: \"Testen\" zeigt ausführlich, was ein Skill gegen Trainingspuppen tut.",
		"Skill test: \"Test\" shows in detail what a skill does against training dummies.")
	main.add_child(_test_log)


func _rebuild_all() -> void:
	_gold_label.text = "Gold: %d" % GameState.gold
	_rebuild_char_bar()
	_rebuild_editors()
	_rebuild_library()


func _rebuild_char_bar() -> void:
	for child in _char_bar.get_children():
		child.queue_free()
	for member in GameState.party:
		var button := Button.new()
		button.text = "%s (Lv. %d)" % [member.display_name, member.level]
		button.icon = _studio.textur(FigurenBau.schluessel_fuer(member),
			func() -> Node3D: return FigurenBau.held_aus(member))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 30)
		UiTheme.als_aktiv(button, member == _selected)
		button.pressed.connect(func() -> void:
			_aktiv_index = 0
			_select_character(member))
		_char_bar.add_child(button)


func _rebuild_editors() -> void:
	for child in _editor_list.get_children():
		child.queue_free()
	_editors.clear()

	# Skill-Liste auf Slot-Anzahl auffüllen (+1 Slot alle 5 Level).
	while _selected.skills.size() < _selected.skill_slots():
		var empty := Skill.new()
		empty.display_name = Loc.pick("Neuer Skill", "New skill")
		_selected.skills.append(empty)

	var naechster := CharacterDef.next_socket_level(maxi(_selected.level, _selected.peak_level))
	_sockel_label.text = Loc.pick("Sockel pro Skill: %d", "Sockets per skill: %d") % _selected.block_sockets() \
		+ (Loc.pick("  ·  nächster Sockel ab Level %d", "  ·  next socket at level %d") % naechster if naechster > 0 else "") \
		+ Loc.pick("   ·   ◆ = nur einer seiner Gruppe   ★ = Kern, nur einer pro Skill",
			"   ·   ◆ = only one of its group   ★ = core, only one per skill")

	# Genau ein Editor pro freigeschaltetem Slot.
	_aktiv_index = clampi(_aktiv_index, 0, _selected.skill_slots() - 1)
	for i in _selected.skill_slots():
		_editor_list.add_child(_make_skill_editor(_selected.skills[i], i))
	_refresh_editors()


func _make_skill_editor(skill: Skill, slot_index: int) -> Control:
	var panel := PanelContainer.new()
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			aktiv_waehlen(skill))
	panel.set_meta(&"ki_text", func() -> String:
		return "" if _editors.size() < 2 else Loc.pick("Slot %d bearbeiten", "Edit slot %d") % (slot_index + 1))
	panel.set_meta(&"ki_klick", func() -> void: aktiv_waehlen(skill))
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
		skill.display_name = text
		_geaendert = true)
	head.add_child(name_edit)
	var cost_label := Label.new()
	cost_label.add_theme_color_override("font_color", UiTheme.GOLD)
	cost_label.add_theme_font_size_override("font_size", 16)
	head.add_child(cost_label)

	# Vorlagen als Menü (Text bleibt "Vorlage ▾" — nichts wirkt vorausgewählt).
	var vorlagen := MenuButton.new()
	vorlagen.text = Loc.pick("Vorlage ▾", "Template ▾")
	vorlagen.flat = false
	var angebot := _vorlagen_fuer_helden()
	for i in angebot.size():
		var vorlage: Skill = angebot[i]
		vorlagen.get_popup().add_icon_item(KlotzIcons.textur(_studio, vorlage.blocks.back()), vorlage.display_name, i)
	vorlagen.get_popup().add_theme_constant_override("icon_max_width", 26)
	vorlagen.disabled = angebot.is_empty()
	vorlagen.tooltip_text = Loc.pick("Fertige Rezepte aus deinen freigeschalteten Klötzen — ersetzt diesen Slot.",
		"Ready-made recipes from your unlocked blocks — replaces this slot.")
	vorlagen.get_popup().id_pressed.connect(func(id: int) -> void:
		_vorlage_anwenden(skill, angebot[id]))
	head.add_child(vorlagen)

	var reparieren := Button.new()
	reparieren.text = Loc.pick("Reparieren", "Repair")
	reparieren.tooltip_text = Loc.pick("Entfernt doppelte und unverträgliche Klötze und alles über der Sockelzahl — der erste passende Klotz bleibt.",
		"Removes duplicate and conflicting blocks and anything beyond the socket count — the first fitting block stays.")
	reparieren.pressed.connect(func() -> void: _reparieren(skill))
	head.add_child(reparieren)

	var ins_buch := Button.new()
	ins_buch.text = Loc.pick("Ins Buch", "To book")
	ins_buch.tooltip_text = Loc.pick("Speichert eine Kopie dieses Baus im Rezeptbuch — so kannst du im Slot weiterbasteln und später zurücktauschen.",
		"Saves a copy of this build in the recipe book — keep tinkering in the slot and swap back later.")
	ins_buch.pressed.connect(func() -> void:
		if WerkstattLogik.ins_buch(_selected, skill):
			_geaendert = true
			_test_log.text = Loc.pick("„%s“ liegt jetzt im Rezeptbuch.", "\"%s\" is now in the recipe book.") % skill.display_name
		else:
			_test_log.text = Loc.pick("Schon im Rezeptbuch (oder leer).", "Already in the recipe book (or empty).")
		_tabs_aktualisieren()
		if _rechts_modus == &"buch":
			_rebuild_library())
	head.add_child(ins_buch)

	var test_button := Button.new()
	test_button.text = Loc.pick("Testen", "Test")
	test_button.tooltip_text = Loc.pick("Probiert den Skill gegen Trainingspuppen aus:\nSchaden, DoTs, Buffs, Heilung — ohne Risiko.",
		"Tries the skill against training dummies:\ndamage, DoTs, buffs, healing — risk-free.")
	test_button.pressed.connect(_run_skill_test.bind(skill))
	head.add_child(test_button)

	var socket_row := HBoxContainer.new()
	socket_row.add_theme_constant_override("separation", 6)
	box.add_child(socket_row)
	var sockets: Array = []
	for i in maxi(_selected.block_sockets(), skill.blocks.size()):
		var socket := SocketSlot.new(self, skill, i)
		socket_row.add_child(socket)
		sockets.append(socket)

	var valid_label := Label.new()
	valid_label.add_theme_font_size_override("font_size", 12)
	valid_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(valid_label)
	var vorschau := Label.new()
	vorschau.add_theme_font_size_override("font_size", 12)
	vorschau.add_theme_color_override("font_color", VORSCHAU_FARBE)
	vorschau.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(vorschau)

	_editors.append({
		"skill": skill, "panel": panel, "cost_label": cost_label,
		"valid_label": valid_label, "vorschau": vorschau, "sockets": sockets,
		"reparieren": reparieren,
	})
	return panel


## Aktualisiert Sockel, Kosten, Gültigkeit und Vorschau ohne Neuaufbau.
## Beim Ziehen färbt jeder Sockel grün (passt) oder rot (mit Grund).
func _refresh_editors() -> void:
	for i in _editors.size():
		var editor: Dictionary = _editors[i]
		var skill: Skill = editor["skill"]
		KampfUi.aktiv_setzen(editor["panel"], i == _aktiv_index)
		for socket: SocketSlot in editor["sockets"]:
			var belegt := socket.index < skill.blocks.size()
			if belegt:
				var block: SkillBlock = skill.blocks[socket.index]
				socket.icon.texture = KlotzIcons.textur(_studio, block)
				socket.label.text = _block_badge(block) + _block_short_name(block)
				socket.label.modulate = _category_color(block)
				socket.tooltip_text = _block_description(block)
			else:
				socket.icon.texture = null
				socket.label.text = Loc.pick("· leer ·", "· empty ·")
				socket.label.modulate = Color(1, 1, 1, 0.5)
				socket.tooltip_text = ""
			var ueber_limit := socket.index >= _selected.block_sockets()
			socket.modulate = Color(1.0, 0.45, 0.45) if ueber_limit \
				else (Color.WHITE if belegt else Color(1, 1, 1, 0.6))
			if _ziehen != null and not ueber_limit and socket.index <= skill.blocks.size():
				var grund := passt(skill, socket.index, _ziehen)
				socket.modulate = OK_FARBE if grund.is_empty() else NEIN_FARBE
				socket.tooltip_text = grund
		var grund := skill.fehler(_selected)
		editor["reparieren"].visible = not grund.is_empty() and not skill.get_sources().is_empty()
		if skill.blocks.is_empty():
			editor["cost_label"].text = ""
			editor["valid_label"].text = Loc.pick("Leer — Klötze hineinziehen oder eine Vorlage wählen.",
				"Empty — drag blocks in or pick a template.")
			editor["valid_label"].modulate = Color(1, 1, 1, 0.55)
			editor["vorschau"].text = ""
		elif grund.is_empty():
			editor["cost_label"].text = "%d MP" % skill.get_mp_cost(_selected)
			var faktor := skill.kosten_faktor()
			var passende_waffe := skill.usable_with_weapon(_selected)
			editor["valid_label"].text = Loc.pick("✔ Einsatzbereit", "✔ Ready") if passende_waffe \
				else Loc.pick("✕ Nicht einsatzbereit", "✕ Not ready")
			if not is_equal_approx(faktor, 1.0):
				editor["valid_label"].text += Loc.pick("   ·   Kostenfaktor ×%s", "   ·   cost factor ×%s") % _dez(faktor, 2)
			if not passende_waffe:
				editor["valid_label"].text += Loc.pick("   ·   braucht %s", "   ·   needs %s") \
					% BlockLibrary.families_label(skill.required_weapon_families())
			editor["valid_label"].modulate = OK_FARBE if passende_waffe else Color(1.0, 0.7, 0.4)
			editor["vorschau"].text = _vorschau(skill)
		else:
			editor["cost_label"].text = "—"
			editor["valid_label"].text = "✕ " + grund
			editor["valid_label"].modulate = Color(1.0, 0.7, 0.4)
			editor["vorschau"].text = ""


## Kurzfassung des Skill-Tests in einer Zeile: was der Skill gegen eine
## ungepanzerte Puppe bzw. auf die Party tut (ohne Krits, fester Würfel).
func _vorschau(skill: Skill) -> String:
	var caster := _clone_for_test(_selected)
	match skill.get_form():
		Enums.SkillForm.SINGLE, Enums.SkillForm.AOE:
			var dummy := _make_dummy(false)
			var battle := _make_test_battle([caster], [dummy])
			var vorher := dummy.hp
			battle.use_skill(caster, skill, dummy)
			var teile: Array[String] = [Loc.pick("≈ %d Schaden", "≈ %d damage") % (vorher - dummy.hp)]
			var ueber_zeit := 0
			var zustaende: Array[String] = []
			for entry in dummy.statuses:
				if entry["status"] in [Enums.Status.BURN, Enums.Status.POISON_DOT, Enums.Status.BLEED]:
					ueber_zeit += int(entry["potency"]) * (3 if entry["status"] != Enums.Status.BURN else 2)
				else:
					zustaende.append(Battle.status_display_name(entry["status"]))
			if ueber_zeit > 0:
				teile.append(Loc.pick("+ ≈ %d über Zeit", "+ ≈ %d over time") % ueber_zeit)
			if skill.get_form() == Enums.SkillForm.AOE:
				teile.append(Loc.pick("trifft alle Gegner", "hits all enemies"))
			if not zustaende.is_empty():
				teile.append(", ".join(zustaende))
			return Loc.pick("Vorschau: ", "Preview: ") + "  ·  ".join(teile)
		Enums.SkillForm.SUMMON:
			var battle := _make_test_battle([caster], [_make_dummy(false)])
			battle.use_skill(caster, skill, null)
			for ally in battle.players:
				if ally.is_summon:
					return Loc.pick("Vorschau: beschwört %s (%d HP, %d Züge)", "Preview: summons %s (%d HP, %d turns)") \
						% [ally.display_name, ally.max_hp, ally.summon_turns_left]
			return ""
		_:
			var ally := _make_dummy(false)
			ally.is_player = true
			ally.hp = roundi(ally.max_hp * 0.5)
			var battle := _make_test_battle([caster, ally], [_make_dummy(false)])
			var vorher := ally.hp
			battle.use_skill(caster, skill, ally)
			var teile: Array[String] = []
			if ally.hp > vorher:
				teile.append(Loc.pick("heilt ≈ %d", "heals ≈ %d") % (ally.hp - vorher))
			var ziel := ally if skill.get_form() != Enums.SkillForm.SELF else caster
			for entry in ziel.statuses:
				var text := Battle.status_display_name(entry["status"])
				if int(entry["potency"]) > 0:
					text += " %d" % int(entry["potency"])
				teile.append(text)
			if skill.get_form() == Enums.SkillForm.AURA:
				teile.append(Loc.pick("ganze Party", "whole party"))
			return Loc.pick("Vorschau: ", "Preview: ") + ("  ·  ".join(teile) if not teile.is_empty()
				else Loc.pick("keine sichtbare Wirkung", "no visible effect"))


func _rebuild_library() -> void:
	for child in _library_list.get_children():
		child.queue_free()

	_tabs_aktualisieren()
	if _rechts_modus == &"buch":
		_rebuild_buch()
		return

	var categories := [
		[Loc.pick("Quelle", "Source"), func(b: SkillBlock) -> bool: return b is SourceBlock,
			Loc.pick("Pflicht: mindestens eine, je Art höchstens eine. Der Waffenangriff ist billiger und nutzt die Besonderheit deiner Waffe, Zauber können dafür Heilung, Support und volle Element-Effekte.",
				"Required: at least one, at most one of each kind. The weapon attack is cheaper and uses your weapon's trait; spells get healing, support and full element effects."), Color(1.0, 0.75, 0.45)],
		[Loc.pick("Element", "Element"), func(b: SkillBlock) -> bool: return b is ElementBlock,
			Loc.pick("Höchstens eins. Am Zauber volle Wirkung, an der Waffe als halber Zusatztreffer.",
				"At most one. Full effect on spells, a half extra hit on weapons."), Color(0.6, 0.85, 1.0)],
		[Loc.pick("Form", "Form"), func(b: SkillBlock) -> bool: return b is FormBlock,
			Loc.pick("Höchstens eine: wen der Skill trifft (ohne = ein Gegner). Waffenangriffe nur mit „Alle Gegner“.",
				"At most one: whom the skill hits (none = one enemy). Weapon attacks only with 'all enemies'."), Color(0.75, 1.0, 0.7)],
		[Loc.pick("Effekte", "Effects"), func(b: SkillBlock) -> bool: return b is EffectBlock,
			Loc.pick("Jeder Effekt nur einmal pro Skill. Kosten addieren sich; Schutz-Effekte wachsen mit Geist.",
				"Each effect once per skill. Costs add up; protective effects grow with spirit."), Color(0.95, 0.75, 1.0)],
		[Loc.pick("Eigenschaften", "Traits"), func(b: SkillBlock) -> bool: return b is ModifierBlock,
			Loc.pick("Treffer, Zielwahl, Krit, Zeitpunkt, Kombos … Zusatztreffer ist stapelbar, sonst jede nur einmal. Sie MULTIPLIZIEREN MP-Kosten und Schaden des ganzen Skills.",
				"Hits, targeting, crits, timing, combos … extra hit stacks, everything else once. They MULTIPLY the MP cost and damage of the whole skill."), Color(1.0, 0.95, 0.55)],
	]
	for category in categories:
		var bloecke: Array[SkillBlock] = []
		var frei := 0
		for block in BlockLibrary.all_blocks():
			if category[1].call(block):
				var offen: bool = GameState.is_block_unlocked(block, _selected.level, _selected)
				if offen:
					frei += 1
				# Gesperrte Klötze fremder Waffen nicht zeigen — die Bäume
				# stehen im Waffen-Training, hier wäre es nur eine lange Liste.
				if offen or (_gesperrte_zeigen and not _fremde_waffe(block)):
					bloecke.append(block)
		var header := Label.new()
		header.text = "%s  (%d)" % [category[0], frei]
		header.add_theme_font_size_override("font_size", 16)
		header.modulate = category[3]
		_library_list.add_child(header)
		var hint := Label.new()
		hint.text = category[2]
		hint.add_theme_font_size_override("font_size", 10)
		hint.modulate = Color(1, 1, 1, 0.5)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_library_list.add_child(hint)
		# Freigeschaltete zuerst, gesperrte danach: was als Nächstes kommt, oben.
		bloecke.sort_custom(func(a: SkillBlock, b: SkillBlock) -> bool:
			var fa: bool = GameState.is_block_unlocked(a, _selected.level, _selected)
			var fb: bool = GameState.is_block_unlocked(b, _selected.level, _selected)
			if fa != fb:
				return fa
			return _schwelle(a) < _schwelle(b))
		for block in bloecke:
			_library_list.add_child(_make_block_card(block))


## Waffen-Klotz einer Gattung, die der Held gerade nicht führt?
func _fremde_waffe(block: SkillBlock) -> bool:
	for family in block.weapon_families:
		if _selected.wields_family(family):
			return false
	return not block.weapon_families.is_empty()


## Sortier-Schlüssel für Gesperrte: Level bzw. Trainings-Schwelle.
static func _schwelle(block: SkillBlock) -> int:
	return block.tree_points if block.unlock_kind == Enums.UnlockKind.TRAINING else block.unlock_level


func _rechts_zeigen(modus: StringName) -> void:
	_rechts_modus = modus
	_rebuild_library()


func _tabs_aktualisieren() -> void:
	_tab_buch.text = Loc.pick("Rezeptbuch (%d)", "Recipe book (%d)") % _selected.rezeptbuch.size()
	UiTheme.als_aktiv(_tab_bausteine, _rechts_modus == &"bausteine")
	UiTheme.als_aktiv(_tab_buch, _rechts_modus == &"buch")
	_filter.visible = _rechts_modus == &"bausteine"


## Rezeptbuch: gespeicherte Bauten mit Klotz-Icons, Kosten und Status;
## „In Slot N“ tauscht mit dem gold umrandeten Slot (nichts geht verloren).
func _rebuild_buch() -> void:
	var hinweis := Label.new()
	hinweis.text = Loc.pick("Beliebig viele Bauten speichern („Ins Buch“ am Skill). In den Kampf gehen nur die Skills in den Slots — „In Slot %d“ tauscht mit dem gold umrandeten Slot, der alte Skill kommt dafür ins Buch.",
		"Save as many builds as you like (\"To book\" on a skill). Only the skills in the slots go into battle — \"Into slot %d\" swaps with the gold-framed slot; the old skill goes into the book.") % (_aktiv_index + 1)
	hinweis.add_theme_font_size_override("font_size", 11)
	hinweis.modulate = Color(1, 1, 1, 0.6)
	hinweis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_library_list.add_child(hinweis)
	if _selected.rezeptbuch.is_empty():
		var leer := Label.new()
		leer.text = Loc.pick("Noch leer.", "Still empty.")
		leer.modulate = Color(1, 1, 1, 0.45)
		_library_list.add_child(leer)
		return
	for i in _selected.rezeptbuch.size():
		_library_list.add_child(_buch_eintrag(_selected.rezeptbuch[i], i))


func _buch_eintrag(skill: Skill, index: int) -> Control:
	var karte := PanelContainer.new()
	var zeile := HBoxContainer.new()
	zeile.add_theme_constant_override("separation", 8)
	karte.add_child(zeile)
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override("separation", 1)
	for block in skill.blocks:
		var bild := TextureRect.new()
		bild.texture = KlotzIcons.textur(_studio, block)
		bild.custom_minimum_size = Vector2(26, 26)
		bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bild.tooltip_text = block.display_name
		icons.add_child(bild)
	zeile.add_child(icons)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	zeile.add_child(text)
	var titel := Label.new()
	titel.text = skill.display_name
	titel.clip_text = true
	text.add_child(titel)
	var status := Label.new()
	status.add_theme_font_size_override("font_size", 10)
	var grund := skill.fehler(_selected)
	if not grund.is_empty():
		status.text = "✕ " + grund
		status.modulate = Color(1.0, 0.7, 0.4)
	elif not skill.usable_with_weapon(_selected):
		status.text = Loc.pick("%d MP  ·  ⚠ braucht %s", "%d MP  ·  ⚠ needs %s") \
			% [skill.get_mp_cost(_selected), BlockLibrary.families_label(skill.required_weapon_families())]
		status.modulate = Color(1.0, 0.85, 0.5)
	else:
		status.text = "%d MP" % skill.get_mp_cost(_selected)
		status.modulate = OK_FARBE
	status.clip_text = true
	text.add_child(status)
	var ausruesten := Button.new()
	ausruesten.text = Loc.pick("In Slot %d", "Into slot %d") % (_aktiv_index + 1)
	ausruesten.pressed.connect(func() -> void:
		WerkstattLogik.ausruesten(_selected, index, _aktiv_index)
		_geaendert = true
		_rebuild_editors()
		_rebuild_library())
	zeile.add_child(ausruesten)
	var loeschen := Button.new()
	loeschen.text = "✕"
	loeschen.tooltip_text = Loc.pick("Aus dem Rezeptbuch löschen", "Delete from the recipe book")
	loeschen.pressed.connect(func() -> void:
		_selected.rezeptbuch.remove_at(index)
		_geaendert = true
		_rebuild_library())
	zeile.add_child(loeschen)
	return karte


## Kategorie-Farben: gleiche Farbe in Bibliothek UND Sockeln.
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
		return Color(1.0, 0.95, 0.55)   # Gelb: Eigenschaften
	return Color.WHITE


func _make_block_card(block: SkillBlock) -> Control:
	var unlocked: bool = GameState.is_block_unlocked(block, _selected.level, _selected)
	var tex := KlotzIcons.textur(_studio, block)
	var card := BlockCard.new(self, block, not unlocked, tex)
	card.tooltip_text = _block_description(block)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)

	var stripe := ColorRect.new()
	stripe.color = _category_color(block)
	stripe.custom_minimum_size = Vector2(4, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stripe)

	var bild := TextureRect.new()
	bild.texture = tex
	bild.custom_minimum_size = Vector2(40, 40)
	bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bild)

	var texte := VBoxContainer.new()
	texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texte.alignment = BoxContainer.ALIGNMENT_CENTER
	texte.add_theme_constant_override("separation", 0)
	texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texte)
	var name_label := Label.new()
	name_label.text = _block_badge(block) + block.display_name
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texte.add_child(name_label)
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 10)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.clip_text = true
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texte.add_child(info)

	if unlocked:
		var lines := _block_description(block).split("\n")
		info.text = lines[0] if not lines.is_empty() else ""
		info.modulate = Color(1, 1, 1, 0.6)
		if not block.weapon_families.is_empty():
			var tech := Label.new()
			tech.text = BlockLibrary.families_label(block.weapon_families)
			tech.add_theme_font_size_override("font_size", 10)
			tech.modulate = Color(1.0, 0.85, 0.5, 0.8)
			tech.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(tech)
	elif block.unlock_kind == Enums.UnlockKind.TRAINING:
		card.modulate = Color(1, 1, 1, 0.45)
		info.text = Loc.pick("Training %s %d (hat: %d)", "training %s %d (has: %d)") \
			% [BlockLibrary.family_label(block.tree_family), block.tree_points,
			_selected.invested(block.tree_family)]
	else:
		card.modulate = Color(1, 1, 1, 0.45)
		info.text = Loc.pick("ab Lv. %d", "from lv. %d") % block.unlock_level
	return card


# --- Baustein-Beschreibungen ------------------------------------------------------

## Regel-Abzeichen vor dem Namen: ★ Kern-Klotz, ◆ Variantengruppe.
static func _block_badge(block: SkillBlock) -> String:
	if block.kern:
		return "★ "
	if block.gruppe != &"":
		return "◆ "
	return ""


static func _block_short_name(block: SkillBlock) -> String:
	return block.display_name if not block.display_name.is_empty() else "Baustein"


static func _block_short_summary(block: SkillBlock) -> String:
	if block is SourceBlock:
		match block.source:
			Enums.SkillSource.WEAPON: return Loc.pick("Waffenangriff", "Weapon attack")
			Enums.SkillSource.KOERPER: return Loc.pick("Körper", "Body")
		return Loc.pick("Zauber", "Spell")
	if block is ElementBlock:
		return Loc.pick("Element", "Element")
	if block is FormBlock:
		return Loc.pick("Form", "Form")
	if block is EffectBlock:
		return Loc.pick("Effekt", "Effect")
	if block is ModifierBlock:
		return Loc.pick("Eigenschaft", "Property")
	return ""


static func _block_description(block: SkillBlock) -> String:
	var lines: Array[String] = []
	if block is SourceBlock:
		if block.source == Enums.SkillSource.WEAPON:
			lines.append(Loc.pick("Physischer Angriff: Schaden + Art von der Waffe (Einzelziel)",
				"Physical attack: damage + type from the weapon (single target)"))
		elif block.source == Enums.SkillSource.KOERPER:
			lines.append(Loc.pick("Körpertreffer: stumpf, Schaden aus Max-HP + Rüstung (Einzelziel)",
				"Body blow: blunt, damage from max HP + armor (single target)"))
			lines.append(Loc.pick("Mit Selbst/Verbündeter/Aura nur Effekte — sie skalieren mit VIT",
				"With self/ally/aura effects only — they scale with VIT"))
		else:
			lines.append(Loc.pick("Zauber: Zauberschaden der Waffe + INT (Standard Einzelziel)",
				"Spell: weapon spell damage + INT (single target by default)"))
	elif block is ElementBlock:
		match block.element:
			Enums.Element.FIRE:
				lines.append(Loc.pick("Feuer: Brand-Stacks nach Schaden, halbieren sich nach jedem Tick",
					"Fire: burn stacks from damage, halved after every tick"))
			Enums.Element.POISON:
				lines.append(Loc.pick("Gift: weniger Stacks, sie bleiben bis zur Kur",
					"Poison: fewer stacks, they stay until cured"))
			Enums.Element.ICE:
				lines.append(Loc.pick("Eis: Chance einzufrieren (setzt aus)",
					"Ice: chance to freeze (skips a turn)"))
				lines.append(Loc.pick("Physische Treffer zerschmettern das Eis für Bonusschaden",
					"Physical hits shatter the ice for bonus damage"))
			Enums.Element.LIGHTNING:
				lines.append(Loc.pick("Blitz: springt auf ein weiteres Ziel über, Chance zu betäuben",
					"Lightning: jumps to another target, chance to stun"))
			Enums.Element.HOLY:
				lines.append(Loc.pick("Heilig: Bonus gegen Untote",
					"Holy: bonus against undead"))
				lines.append(Loc.pick("Mit Form Verbündeter/Aura/Selbst wird Schaden zu Heilung",
					"With form ally/aura/self, damage becomes healing"))
			Enums.Element.DARK:
				lines.append(Loc.pick("Dunkel: raubt Leben, verflucht das Ziel (nimmt mehr Schaden)",
					"Dark: drains life, curses the target (takes more damage)"))
	elif block is FormBlock:
		match block.form:
			Enums.SkillForm.AOE: lines.append(Loc.pick("Fläche: trifft alle Gegner (schwächer, teurer)",
				"Area: hits all enemies (weaker, costlier)"))
			Enums.SkillForm.ALLY: lines.append(Loc.pick("Verbündeter: ein gewählter Kamerad",
				"Ally: one chosen companion"))
			Enums.SkillForm.AURA: lines.append(Loc.pick("Aura: wirkt auf die ganze Party",
				"Aura: affects the whole party"))
			Enums.SkillForm.SELF: lines.append(Loc.pick("Selbst: nur der Anwender", "Self: the user only"))
			Enums.SkillForm.SUMMON:
				lines.append(Loc.pick("Beschwört einen Verbündeten (ohne Element: Wolf, mit Element: Elementar)",
					"Summons an ally (no element: wolf, with element: elemental)"))
				lines.append(Loc.pick("Effekte wirken auf die Beschwörung", "Effects apply to the summon"))
	elif block is EffectBlock:
		lines.append(Loc.pick("Status: %s", "Status: %s") % Battle.status_display_name(block.status))
		lines.append(Battle.status_effect_text(block.status, block.potency))
		match block.ziel:
			EffectBlock.Ziel.ANWENDER:
				lines.append(Loc.pick("Wirkt auf DICH — auch an einem Angriff", "Affects YOU — even on an attack"))
			EffectBlock.Ziel.PARTY:
				lines.append(Loc.pick("Wirkt auf die ganze PARTY", "Affects the whole PARTY"))
			EffectBlock.Ziel.ALLE_GEGNER:
				lines.append(Loc.pick("Wirkt auf ALLE GEGNER", "Affects ALL ENEMIES"))
		var effect_terms: Array[String] = []
		if block.chance_percent < 100:
			effect_terms.append(Loc.pick("%d%% Auslöse-Chance", "%d%% trigger chance")
				% block.chance_percent)
		# Der Beschützer gilt immer nur für die Runde des Einsatzes — die Dauer-Angabe
		# des Klotzes würde dem Beschreibungstext widersprechen.
		if block.duration_turns > 0 and block.status != Enums.Status.PROTECT:
			effect_terms.append(Loc.pick("%d Runde" if block.duration_turns == 1 else "%d Runden",
				"%d round" if block.duration_turns == 1 else "%d rounds") % block.duration_turns)
		elif block.duration_turns < 0:
			effect_terms.append(Loc.pick("Dauer: bis zur Kur", "Duration: until cured"))
		if not effect_terms.is_empty():
			lines.append(" · ".join(effect_terms))
	elif block is ModifierBlock:
		var m: int = block.magnitude
		match block.modifier:
			Enums.SkillModifier.TREFFER:
				lines.append(Loc.pick("+1 Treffer — alle Treffer teilen sich den Schaden (+15 % je Zusatztreffer); stapelbar",
					"+1 hit — all hits share the damage (+15% per extra hit); stackable"))
			Enums.SkillModifier.TREFFER_VOLL:
				lines.append(Loc.pick("Zusatztreffer verlieren keinen Schaden mehr", "Extra hits no longer lose damage"))
			Enums.SkillModifier.ZIEL_ZUFALL:
				lines.append(Loc.pick("Jeder Treffer sucht sich einen zufälligen Gegner (mit Zusatztreffern: Hagel)",
					"Each hit picks a random enemy (with extra hits: hail)"))
			Enums.SkillModifier.ZIEL_WECHSEL:
				lines.append(Loc.pick("Jeder weitere Treffer springt auf einen anderen Gegner (Fächer, Kette)",
					"Each further hit jumps to another enemy (fan, chain)"))
			Enums.SkillModifier.UEBERSCHLAG:
				lines.append(Loc.pick("Schaden über die Rest-HP hinaus trifft den nächsten Gegner",
					"Damage beyond the remaining HP hits the next enemy"))
			Enums.SkillModifier.KRIT_BONUS:
				lines.append(Loc.pick("+%d%% Krit-Chance", "+%d%% crit chance") % m)
			Enums.SkillModifier.KRIT_MULT:
				lines.append(Loc.pick("Krits treffen ×%s statt ×1,5", "Crits hit ×%s instead of ×1.5") % _dez(m / 100.0, 1))
			Enums.SkillModifier.ALLES_ODER_NICHTS:
				lines.append(Loc.pick("Krit ×3 — ohne Krit kein Schaden", "Crit ×3 — no damage without a crit"))
			Enums.SkillModifier.SCHWACHSTELLE:
				lines.append(Loc.pick("+%d%% Schwachstellen-Chance (×2, mit Krit VOLLTREFFER ×4)",
					"+%d%% weak spot chance (×2, with a crit FULL HIT ×4)") % m)
			Enums.SkillModifier.VOLLTREFFER_MULT:
				lines.append(Loc.pick("Volltreffer (Krit + Schwachstelle) ×%d statt ×4",
					"Full hits (crit + weak spot) ×%d instead of ×4") % (m / 100))
			Enums.SkillModifier.ZEIT_FLINK:
				lines.append(Loc.pick("Handelt als Erster der Runde", "Acts first in the round"))
			Enums.SkillModifier.ZEIT_WUCHT:
				lines.append(Loc.pick("Handelt als Letzter der Runde", "Acts last in the round"))
			Enums.SkillModifier.AUFLADEN:
				lines.append(Loc.pick("Lädt auf: wirkt erst in deinem nächsten Zug",
					"Charges: takes effect on your next turn"))
			Enums.SkillModifier.BLUTPREIS:
				lines.append(Loc.pick("Kostet HP statt MP (×%.1f)", "Costs HP instead of MP (×%.1f)") % Battle.BLUTPREIS_FAKTOR)
			Enums.SkillModifier.COST_REDUCTION:
				lines.append(Loc.pick("−%d%% MP-Kosten", "−%d%% MP cost") % m)
			Enums.SkillModifier.PIERCE_ARMOR:
				lines.append(Loc.pick("Ignoriert %d%% der Rüstung/Resistenz", "Ignores %d%% of armor/resistance") % m)
			Enums.SkillModifier.EXECUTE:
				lines.append(Loc.pick("+%d%% Schaden gegen Ziele unter 30%% HP", "+%d%% damage vs targets below 30%% HP") % m)
			Enums.SkillModifier.OVERLOAD:
				lines.append(Loc.pick("+%d%% Schaden", "+%d%% damage") % m)
			Enums.SkillModifier.RAGE:
				lines.append(Loc.pick("Bei vollen HP −30 %%, je mehr eigene HP fehlen, desto härter (bis +%d%%)",
					"−30%% at full HP, the more HP you miss the harder (up to +%d%%)") % m)
			Enums.SkillModifier.ENTZUENDEN:
				lines.append(Loc.pick("+%d%% gegen brennende Ziele — löscht den Brand", "+%d%% vs burning targets — consumes the burn") % m)
			Enums.SkillModifier.AUSNUTZEN:
				lines.append(Loc.pick("+%d%% gegen betäubte, gefrorene oder verlangsamte Ziele",
					"+%d%% vs stunned, frozen or slowed targets") % m)
			Enums.SkillModifier.NACHSETZEN:
				lines.append(Loc.pick("+%d%% gegen Ziele, die ein Verbündeter diese Runde schon traf",
					"+%d%% vs targets an ally already hit this round") % m)
			Enums.SkillModifier.DUELL:
				lines.append(Loc.pick("+%d%% gegen das Ziel, das du zuletzt selbst getroffen hast",
					"+%d%% vs the target you hit last") % m)
			Enums.SkillModifier.KEIN_ERSCHOEPFT:
				lines.append(Loc.pick("Axt: keine Erschöpfung — dafür kein doppelter Schaden",
					"Axe: no exhaustion — but no double damage"))
			Enums.SkillModifier.ZERMALMEN:
				lines.append(Loc.pick("+%d%% gegen Ziele mit Rüstungsriss", "+%d%% vs targets with armor break") % m)
			Enums.SkillModifier.SERIE:
				lines.append(Loc.pick("+%d Treffer. Jeder Treffer auf dasselbe Ziel wird stärker: 10 %%, 15 %%, 20 %% … bis 100 %% — bleibt über die Züge erhalten.",
					"+%d hits. Every hit on the same target gets stronger: 10%%, 15%%, 20%% … up to 100%% — carries over between turns.") % m)
			Enums.SkillModifier.VOLLHEILUNG:
				lines.append(Loc.pick("Heilt die Ziele VOLL — kostet so viel MP, wie die Heilung braucht (Heil-Boni zählen mit).",
					"Heals the targets to FULL — costs as much MP as the healing needs (healing bonuses count)."))
				lines.append(Loc.pick("Reicht das Mana nicht, gehen alle MP drauf und es wird so viel geheilt wie möglich. Braucht Heilig + Verbündeter/Selbst/Aura.",
					"If MP runs short, all MP is spent and it heals as much as possible. Needs holy + ally/self/aura."))
			Enums.SkillModifier.ELEMENT_FOKUS:
				lines.append(Loc.pick("Element-Signatur (Brand, Frost, Gift …) ×2", "Element signature (burn, frost, poison …) ×2"))
			Enums.SkillModifier.ECHO:
				lines.append(Loc.pick("Echo: wiederholt sich nächste Runde mit %d%% Kraft", "Echo: repeats next round at %d%% power") % m)
			Enums.SkillModifier.OVERHEAL_SHIELD:
				lines.append(Loc.pick("Überheilung: %d%% des Überschusses werden Schild-HP (höchstens 50 %% der Max-HP)",
					"Overheal: %d%% of the excess becomes shield HP (at most 50%% of max HP)") % m)
			Enums.SkillModifier.RUECKSCHLAG:
				lines.append(Loc.pick("%d%% des verursachten Schadens trifft dich selbst", "%d%% of the damage dealt hits you as well") % m)
	if not is_equal_approx(block.schaden_faktor, 1.0):
		lines.append(Loc.pick("Schaden des Skills ×%.2f", "Skill damage ×%.2f") % block.schaden_faktor)
	if block.quelle_noetig != &"":
		lines.append(Loc.pick("NUR MIT QUELLE: %s", "ONLY WITH SOURCE: %s") % Skill.quellen_name(block.quelle_noetig))
	if not block.weapon_families.is_empty():
		lines.append(Loc.pick("WAFFENTECHNIK — nur mit: %s", "WEAPON TECHNIQUE — only with: %s")
			% BlockLibrary.families_label(block.weapon_families))
	var gruppe := Skill.gruppe_von(block)
	if block.kern:
		lines.append(Loc.pick("★ KERN-KLOTZ — höchstens einer pro Skill", "★ CORE BLOCK — at most one per skill"))
	if gruppe != &"" and not (block is SourceBlock):
		lines.append(Loc.pick('◆ Gruppe "%s" — nur ein Klotz dieser Gruppe pro Skill',
			'◆ Group "%s" — only one block of this group per skill') % Skill.gruppen_name(gruppe, block))
	if block.mp_cost > 0:
		lines.append(Loc.pick("Kostenbeitrag: %d MP", "Cost contribution: %d MP") % block.mp_cost)
	if not is_equal_approx(block.kosten_faktor, 1.0):
		lines.append(Loc.pick("Kosten des Skills ×%s", "Skill cost ×%s") % _dez(block.kosten_faktor, 2))
	return "\n".join(lines)
