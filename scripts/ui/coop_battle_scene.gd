extends Control
## Co-op-Kampfansicht des GASTES: Der Host rechnet den Kampf, hier wählt der
## Mitspieler die Aktion seines EIGENEN Helden (Kommandophase) und verfolgt
## die Runde live — Zustand ("bstate"), Kampflog ("blog") und die geplanten
## Aktionen aller ("cmd_update") kommen vom Host. Kein Item-Zugriff: die
## Vorräte gehören dem Host.

const DUNGEON_SCENE := "res://scenes/dungeon/dungeon_scene.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"

var _units := {}    ## Netz-ID » letzter Unit-Zustand vom Host
var _panels := {}   ## Netz-ID » {"root", "hp", ("mp"), "status", ("plan")}
var _my_name := ""  ## Session-Name meines Helden beim Host
var _host_name := "?"
var _round := 1
var _my_down := false  ## eigener Held kampfunfähig » Menü zu
## Letztes Beute-Paket vom Host (kommt VOR battle_ended) — fürs Sieg-Panel.
var _last_gains: Dictionary = {}
## Das Ergebnis-Overlay (Sieg/Beute) — muss bei einem neuen Kampf weg.
var _result_overlay: Control

var _info_label: Label
var _enemy_row: HBoxContainer
var _party_row: HBoxContainer
var _action_box: VBoxContainer
var _log_label: RichTextLabel
var _turn_bar: HBoxContainer
var _buehne: KampfBuehne3D  ## 3D-Arena hinter der UI (STIL-3D.md 7c)
var _studio: PortraitStudio  ## Porträts für Zugleiste/Party


func _ready() -> void:
	theme = UiTheme.get_theme()
	Music.play(&"boss" if bool(GameState.coop_battle.get("is_boss", false)) else &"kampf")
	var biome := Enums.Biome.FOREST
	if GameState.current_run.has("card"):
		biome = GameState.current_run["card"].biome
	var stil := DungeonWelt3D.biom_stil(biome)
	_buehne = KampfBuehne3D.new()
	add_child(_buehne)
	_buehne.aufbauen(stil["floor_tint"], stil["wall_tint"], stil["deco"])
	_studio = PortraitStudio.new()
	add_child(_studio)
	_build_layout()
	_buehne.deckel = _turn_bar
	if Net.role != Net.Role.GUEST:
		# Direktstart/Offline (z.B. Szenen-Smoke-Test): sauber zurück.
		_info_label.text = Loc.pick("Keine Co-op-Kampfdaten.", "No co-op battle data.")
		var back := Button.new()
		back.text = Loc.pick("Zurück", "Back")
		back.pressed.connect(func() -> void:
			get_tree().change_scene_to_file(MAIN_SCENE))
		_action_box.add_child(back)
		return
	_my_name = Net.my_hero_name()
	_host_name = String(GameState.coop_battle.get("host", "?"))
	_refresh_info()
	Net.message_received.connect(_on_net_message)
	Net.coop_battle_started.connect(_on_new_battle)
	Net.coop_battle_ended.connect(_on_battle_ended)
	Net.session_ended.connect(_on_session_ended)
	Net.gains_received.connect(_on_gains)
	_log(Loc.pick("Der Kampf beginnt!", "The battle begins!"))
	Sfx.play(&"kampf_start")
	# Handshake: Der Host liefert Zustand + Pläne nach und fragt ggf. sofort
	# nach unserer Aktion (alles vor dem Szenenwechsel ging ins Leere).
	Net.send_to_host("cmd_ready", {})


func _refresh_info() -> void:
	_info_label.text = Loc.pick("Kampf bei %s — Runde %d", "Battle at %s's — round %d") \
		% [_host_name, _round]


# --- Nachrichten vom Host ------------------------------------------------------

func _on_net_message(_peer_id: int, type: String, data: Dictionary) -> void:
	match type:
		"bstate":
			_apply_state(data)
		"cmd_update":
			_apply_plans(data)
		"blog":
			_log(String(data.get("line", "")))
		"cmd_phase":
			_round = int(data.get("round", _round))
			_my_name = String(data.get("you", _my_name))
			_refresh_info()
			_show_command_menu()


## Der Host hat einen NEUEN Kampf begonnen, während diese Ansicht noch offen
## war (z.B. Sieg-Panel): komplett zurücksetzen — sonst blieben Namen und
## Sprites des ALTEN Kampfs an den recycelten Netz-IDs kleben.
func _on_new_battle(data: Dictionary) -> void:
	if Net.my_hero_name() not in data.get("fighters", []):
		# Diesmal nicht dabei (andere Ebene) » zurück in den Dungeon.
		get_tree().change_scene_to_file(DUNGEON_SCENE)
		return
	GameState.coop_battle = data
	_host_name = String(data.get("host", "?"))
	_round = 1
	_my_down = false
	_last_gains = {}
	if _result_overlay != null and is_instance_valid(_result_overlay):
		_result_overlay.queue_free()
	_result_overlay = null
	_units.clear()
	for id in _panels:
		_panels[id]["root"].queue_free()
	_panels.clear()
	for child in _turn_bar.get_children():
		child.queue_free()
	_clear_actions()
	_log_label.clear()
	_log(Loc.pick("Der Kampf beginnt!", "The battle begins!"))
	_refresh_info()
	Sfx.play(&"kampf_start")
	Net.send_to_host("cmd_ready", {})


## Zustand aller Kämpfer übernehmen: Panels anlegen/aktualisieren/entfernen.
func _apply_state(data: Dictionary) -> void:
	_round = maxi(_round, int(data.get("round", 0)))
	_refresh_info()
	var seen := {}
	for unit_variant in data.get("units", []):
		var unit: Dictionary = unit_variant
		var id := int(unit.get("id", -1))
		seen[id] = true
		# Sicherheitsnetz: gleiche ID, anderer Name » Panel neu bauen
		# (Schleim-Stapeln etc. ersetzen Kämpfer mitten im Kampf).
		if _panels.has(id) and String(_units.get(id, {}).get("name", "")) \
				!= String(unit.get("name", "")):
			_panels[id]["root"].queue_free()
			_panels.erase(id)
		_units[id] = unit
		if not _panels.has(id):
			_make_panel(unit)
		var panel: Dictionary = _panels[id]
		panel["hp"].max_value = maxi(1, int(unit.get("maxhp", 1)))
		panel["hp"].value = int(unit.get("hp", 0))
		if panel.has("mp"):
			panel["mp"].max_value = maxi(1, int(unit.get("maxmp", 1)))
			panel["mp"].value = int(unit.get("mp", 0))
		var status_names: Array = unit.get("st", [])
		panel["status"].text = ", ".join(status_names)
		# Element-Wissen des Hosts (▲ schwach · ▼ resistent) — nur bei Änderung neu.
		if panel.has("wissen") and str(unit.get("sw", [])) != panel["sw"]:
			panel["sw"] = str(unit.get("sw", []))
			KampfUi.wissen_chips(panel["wissen"], unit.get("sw", []))
		panel["root"].modulate = Color(1, 1, 1) if bool(unit.get("alive", true)) \
			else Color(1, 1, 1, 0.3)
	for id in _panels.keys():
		if not seen.has(id):
			_panels[id]["root"].queue_free()
			_panels.erase(id)
			_units.erase(id)
	_apply_order(data.get("order", []), int(data.get("active", -1)))
	# Eigener Held gefallen: Menü schließen — die anderen kämpfen weiter.
	var mine := _my_unit()
	if not mine.is_empty():
		if not bool(mine.get("alive", true)):
			if not _my_down:
				_my_down = true
				_clear_actions()
				var head := Label.new()
				head.text = Loc.pick("Dein Held ist kampfunfähig —\ndie anderen kämpfen weiter.",
					"Your hero is down —\nthe others fight on.")
				head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_action_box.add_child(head)
		else:
			_my_down = false


## Zugreihenfolge-Leiste wie beim Host: aktueller Kämpfer (gelb), dann die
## nächsten — grün umrandet = Party, rot = Gegner.
func _apply_order(order: Array, active_id: int) -> void:
	for child in _turn_bar.get_children():
		child.queue_free()
	var first := true
	for id_variant in order:
		var id := int(id_variant)
		if not _units.has(id):
			continue
		var unit: Dictionary = _units[id]
		var is_current := first and id == active_id
		var slot := PanelContainer.new()
		var style := StyleBoxFlat.new()
		var side_color := Color(0.45, 0.9, 0.5) \
			if String(unit.get("side", "")) == "p" else Color(0.95, 0.4, 0.35)
		if is_current:
			side_color = Color(1.0, 0.85, 0.3)
		style.bg_color = Color(side_color.r, side_color.g, side_color.b, 0.13)
		style.border_color = side_color
		style.set_border_width_all(2 if is_current else 1)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(2)
		slot.add_theme_stylebox_override("panel", style)
		slot.tooltip_text = String(unit.get("name", "?")) \
			+ (Loc.pick("  (am Zug)", "  (acting)") if is_current else "")
		slot.add_child(_unit_sprite(unit, 30 if is_current else 22))
		_turn_bar.add_child(slot)
		first = false
	for id in _panels:
		if _panels[id].has("plan"):
			KampfUi.aktiv_setzen(_panels[id]["root"], id == active_id)


func _apply_plans(data: Dictionary) -> void:
	for plan_variant in data.get("plans", []):
		var plan: Dictionary = plan_variant
		var id := int(plan.get("id", -1))
		if _panels.has(id) and _panels[id].has("plan"):
			_panels[id]["plan"].text = String(plan.get("text", ""))


func _on_battle_ended(data: Dictionary) -> void:
	_clear_actions()
	var victory := bool(data.get("victory", false))
	var fled := bool(data.get("fled", false))
	Sfx.play(&"sieg" if victory or fled else &"niederlage")

	# Ergebnis-Panel wie beim Host: Ausgang + Beute + Level-Up-Punkte.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_result_overlay = center
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var head := Label.new()
	head.add_theme_font_size_override("font_size", 32)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if fled:
		head.text = Loc.pick("Geflohen!", "Fled!")
	elif victory:
		head.text = Loc.pick("Sieg!", "Victory!")
	else:
		head.text = Loc.pick("Niederlage …", "Defeat …")
	box.add_child(head)

	# Beute-Übersicht: das Paket, das der Host für DEINEN Helden geschnürt
	# hat — es liegt bereits im eigenen Spielstand.
	if victory and not _last_gains.is_empty():
		var xp_gold := Label.new()
		xp_gold.text = "+%d XP   ·   +%d Gold" % [int(_last_gains.get("xp", 0)),
			int(_last_gains.get("gold", 0))]
		xp_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(xp_gold)
		for item_data in _last_gains.get("items", []):
			var item := ItemInstance.from_dict(item_data)
			if item == null:
				continue
			var item_label := Label.new()
			item_label.text = "%s (%s)" % [item.get_display_name(),
				LootGenerator.RARITY_NAMES[item.rarity]]
			item_label.modulate = LootGenerator.RARITY_COLORS[item.rarity]
			item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(item_label)
		var mats: Dictionary = _last_gains.get("materials", {})
		for id_str in mats:
			var mat_label := Label.new()
			mat_label.text = "+%d %s" % [int(mats[id_str]),
				MaterialLibrary.display_name(StringName(id_str))]
			mat_label.modulate = Color(0.6, 0.95, 0.7)
			mat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(mat_label)
		var levels := int(_last_gains.get("levels_gained", 0))
		var local_hero := Net.my_local_hero()
		if levels > 0:
			var level_label := Label.new()
			level_label.text = Loc.pick("%s erreicht Level %d! (+%d Statuspunkte, +%d Skillpunkte)",
				"%s reaches level %d! (+%d stat points, +%d skill points)") \
				% [_my_name, int(_last_gains.get("hero_level", 0)),
				levels * (local_hero.stat_points_per_level() if local_hero != null \
					else Combatant.POINTS_PER_LEVEL),
				levels * Combatant.SKILL_POINTS_PER_LEVEL]
			level_label.modulate = Color(0.55, 1.0, 0.55)
			level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(level_label)
		# Statuspunkte DIREKT hier verteilen — ohne dass im Dungeon des
		# Hosts der nächste Gegner dazwischenfunkt.
		var hero := Net.my_local_hero()
		if hero != null and hero.stat_points > 0:
			box.add_child(_make_alloc_button(panel, box, hero))

	var back := Button.new()
	back.text = Loc.pick("Zurück in den Dungeon", "Back to the dungeon")
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(DUNGEON_SCENE))
	box.add_child(back)
	back.grab_focus.call_deferred()


## Knopf im Sieg-Panel: klappt die Punkteverteilung für den eigenen Helden
## auf — die Übersicht weicht solange, „Fertig“ führt zurück.
func _make_alloc_button(panel: PanelContainer, box: VBoxContainer,
		member: Combatant) -> Button:
	var button := Button.new()
	button.text = Loc.pick("Punkte verteilen: %s (%d frei)", "Spend points: %s (%d free)") \
		% [member.display_name, member.stat_points]
	button.pressed.connect(func() -> void:
		box.visible = false
		var wrap := VBoxContainer.new()
		wrap.add_theme_constant_override("separation", 10)
		var head := Label.new()
		head.text = Loc.pick("Statuspunkte — %s", "Stat points — %s") % member.display_name
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wrap.add_child(head)
		var alloc := StatAllocator.create(member)
		wrap.add_child(alloc)
		var done := Button.new()
		done.text = Loc.pick("« Fertig", "« Done")
		done.pressed.connect(func() -> void:
			wrap.queue_free()
			button.text = Loc.pick("Punkte verteilen: %s (%d frei)",
				"Spend points: %s (%d free)") % [member.display_name, member.stat_points]
			button.disabled = member.stat_points <= 0
			box.visible = true
			# Tastatur-Fokus lag auf dem (gleich zerstörten) Fertig-Knopf —
			# SYNCHRON freigeben und neu vergeben (deferred liefe zu früh:
			# der sterbende Knopf hält den Fokus bis zum Frame-Ende, der
			# Wächter in focus_first_button bräche dann ab » Fokus = null).
			done.release_focus()
			UiTheme.focus_first_button(box))
		# Nach BESTÄTIGEN den Fokus zum Fertig-Knopf schieben (der Bestätigen-
		# Knopf sperrt sich selbst — gesperrte Knöpfe halten keinen Fokus).
		alloc.changed.connect(func() -> void:
			done.grab_focus())
		wrap.add_child(done)
		panel.add_child(wrap))
	return button


func _on_session_ended() -> void:
	GameState.coop_guest_run = false
	GameState.current_run = {}
	get_tree().change_scene_to_file(MAIN_SCENE)


## Beute-Paket (XP/Gold/Items/Materialien) ist im eigenen Spielstand gelandet —
## merken fürs Ergebnis-Panel (battle_ended kommt gleich danach).
func _on_gains(gains: Dictionary) -> void:
	_last_gains = gains
	_log(Loc.pick("Deine Beute: +%d XP, +%d Gold, %d Items, %d Materialien.",
		"Your loot: +%d XP, +%d gold, %d items, %d materials.") % [
		int(gains.get("xp", 0)), int(gains.get("gold", 0)),
		gains.get("items", []).size(), gains.get("materials", {}).size()])


# --- Aktionswahl (Kommandophase) -------------------------------------------------

func _show_command_menu() -> void:
	if _my_down:
		return
	_clear_actions()
	var hero := Net.my_local_hero()
	var head := Label.new()
	head.text = Loc.pick("Befehl für %s", "Command for %s") % _my_name
	_action_box.add_child(head)

	var attack := Button.new()
	attack.text = Loc.pick("Angriff", "Attack")
	attack.pressed.connect(func() -> void:
		_show_enemy_targets({"kind": "attack"}))
	_action_box.add_child(attack)
	attack.grab_focus.call_deferred()

	if hero != null:
		var usable := 0
		for i in mini(hero.skills.size(), hero.skill_slots()):
			if not hero.skills[i].get_sources().is_empty():
				usable += 1
		if usable > 0:
			var skills_button := Button.new()
			skills_button.text = Loc.pick("Skills (%d) »", "Skills (%d) »") % usable
			skills_button.pressed.connect(_show_skill_menu)
			_action_box.add_child(skills_button)

	var defend := Button.new()
	defend.text = Loc.pick("Verteidigen", "Defend")
	defend.pressed.connect(func() -> void:
		_send_pick({"kind": "defend"}))
	_action_box.add_child(defend)

	var focus := Button.new()
	focus.text = Loc.pick("Konzentrieren", "Focus")
	focus.tooltip_text = Loc.pick(
		"Opfert den Zug: nächster Angriff +50% Schaden (stapelbar bis +200%).",
		"Sacrifices the turn: next attack +50% damage (stacks up to +200%).")
	focus.pressed.connect(func() -> void:
		_send_pick({"kind": "focus"}))
	_action_box.add_child(focus)

	# Waffenset wechseln: FREIE Aktion — der Host wechselt sofort, das Menü
	# bleibt offen (lokale Kopie zieht mit, damit die Skill-Sperren stimmen).
	if hero != null and hero.has_second_weapon_set():
		var set_swap := Button.new()
		var other_weapon: ItemInstance = hero.weapon_set_b.get(Enums.EquipSlot.WEAPON)
		set_swap.text = Loc.pick("Waffenset » %s", "Weapon set » %s") \
			% (other_weapon.get_display_name() if other_weapon != null else Loc.pick("(leer)", "(empty)"))
		set_swap.pressed.connect(func() -> void:
			hero.swap_weapon_set()
			Net.send_to_host("cmd_swap", {})
			Sfx.play(&"bestaetigen")
			_show_command_menu())
		_action_box.add_child(set_swap)


func _show_skill_menu() -> void:
	_clear_actions()
	var hero := Net.my_local_hero()
	if hero == null:
		_show_command_menu()
		return
	var head := Label.new()
	head.text = Loc.pick("Skill wählen", "Choose a skill")
	_action_box.add_child(head)
	var mp := _my_mp()
	var first_enabled: Button = null
	for i in mini(hero.skills.size(), hero.skill_slots()):
		var skill: Skill = hero.skills[i]
		if skill.get_sources().is_empty():
			continue
		var cost := skill.get_mp_cost(hero)
		var wrong_weapon := not skill.usable_with_weapon(hero)
		var grund := skill.fehler(hero)
		var button := Button.new()
		button.text = "%s (%d MP)" % [skill.display_name, cost]
		if not grund.is_empty():
			button.text += Loc.pick("  [ungültig]", "  [invalid]")
			button.tooltip_text = grund
		elif wrong_weapon:
			button.text += Loc.pick("  [braucht %s]", "  [needs %s]") \
				% BlockLibrary.families_label(skill.required_weapon_families())
		button.disabled = mp < cost or wrong_weapon or not grund.is_empty()
		button.pressed.connect(_on_skill_pressed.bind(skill, i))
		_action_box.add_child(button)
		if first_enabled == null and not button.disabled:
			first_enabled = button
	var back := Button.new()
	back.text = Loc.pick("« Zurück", "« Back")
	back.pressed.connect(_show_command_menu)
	_action_box.add_child(back)
	(first_enabled if first_enabled != null else back).grab_focus.call_deferred()


func _on_skill_pressed(skill: Skill, index: int) -> void:
	match skill.get_form():
		Enums.SkillForm.SINGLE:
			_show_enemy_targets({"kind": "skill", "skill": index})
		Enums.SkillForm.ALLY:
			_show_ally_targets({"kind": "skill", "skill": index})
		_:
			_send_pick({"kind": "skill", "skill": index})


func _show_enemy_targets(base: Dictionary) -> void:
	_show_targets(base, "e", Loc.pick("Ziel wählen …", "Choose a target …"))


func _show_ally_targets(base: Dictionary) -> void:
	_show_targets(base, "p", Loc.pick("Verbündeten wählen …", "Choose an ally …"))


func _show_targets(base: Dictionary, side: String, title: String) -> void:
	_clear_actions()
	var head := Label.new()
	head.text = title
	_action_box.add_child(head)
	var first: Button = null
	for id in _units:
		var unit: Dictionary = _units[id]
		if String(unit.get("side", "")) != side or not bool(unit.get("alive", true)):
			continue
		var button := Button.new()
		button.text = "%s (%d/%d HP)" % [String(unit.get("name", "?")),
			int(unit.get("hp", 0)), int(unit.get("maxhp", 1))]
		var pick := base.duplicate()
		pick["target"] = id
		button.pressed.connect(func() -> void:
			_send_pick(pick))
		_action_box.add_child(button)
		if first == null:
			first = button
	var back := Button.new()
	back.text = Loc.pick("« Zurück", "« Back")
	back.pressed.connect(_show_command_menu)
	_action_box.add_child(back)
	(first if first != null else back).grab_focus.call_deferred()


func _send_pick(pick: Dictionary) -> void:
	Net.send_to_host("cmd_pick", pick)
	Sfx.play(&"bestaetigen")
	_clear_actions()
	var head := Label.new()
	head.text = Loc.pick("Gewählt — warte auf die anderen …",
		"Chosen — waiting for the others …")
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_box.add_child(head)


# --- Helfer ----------------------------------------------------------------------

func _my_unit() -> Dictionary:
	for id in _units:
		if String(_units[id].get("name", "")) == _my_name:
			return _units[id]
	return {}


## Aktueller MP-Stand des eigenen Helden — aus dem Host-Zustand, nicht aus
## der lokalen Kopie (die kennt den Kampfverlauf nicht).
func _my_mp() -> int:
	return int(_my_unit().get("mp", 0))


func _log(text: String) -> void:
	if text != "":
		KampfUi.log_zeile(_log_label, text)


func _clear_actions() -> void:
	for child in _action_box.get_children():
		child.queue_free()


# --- UI-Aufbau --------------------------------------------------------------------

func _build_layout() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 16)
	root.add_theme_constant_override("margin_top", 12)
	root.add_theme_constant_override("margin_right", 16)
	root.add_theme_constant_override("margin_bottom", 12)
	add_child(root)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	root.add_child(main)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(_info_label)

	# Zugreihenfolge-Leiste (kommt mit jedem Zustands-Paket vom Host).
	var turn_center := CenterContainer.new()
	main.add_child(turn_center)
	_turn_bar = HBoxContainer.new()
	_turn_bar.add_theme_constant_override("separation", 6)
	turn_center.add_child(_turn_bar)

	var enemy_center := CenterContainer.new()
	enemy_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(enemy_center)
	_enemy_row = HBoxContainer.new()
	_enemy_row.add_theme_constant_override("separation", 24)
	enemy_center.add_child(_enemy_row)

	var unten := KampfUi.unterer_bereich(main)
	_log_label = unten["log"]
	_party_row = unten["party"]
	_action_box = unten["aktionen"]


func _make_panel(unit: Dictionary) -> void:
	var id := int(unit.get("id", -1))
	var is_party := String(unit.get("side", "e")) == "p"
	if is_party:
		var mein := String(unit.get("name", "?")) == _my_name
		var karte := KampfUi.party_karte(_unit_sprite(unit, 44),
			String(unit.get("name", "?")) + (Loc.pick(" (du)", " (you)") if mein else ""),
			UiTheme.GOLD if mein else UiTheme.TEXT)
		karte.erase("name")
		_panels[id] = karte
		_party_row.add_child(karte["root"])
		return
	# Gegner: unsichtbarer Rahmen — die 3D-Figur der Arena steht dahinter.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.custom_minimum_size = Vector2(132, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var sprite_center := CenterContainer.new()
	box.add_child(sprite_center)
	# Platzhalter für die 3D-Figur der Arena (wie beim Host).
	var groesse := roundi(128 * float(unit.get("scale", 1.0))
		* (1.2 if bool(unit.get("boss", false)) else 1.0))
	var platz := Control.new()
	platz.custom_minimum_size = Vector2(groesse, groesse)
	sprite_center.add_child(platz)
	_buehne.anmelden(id, platz, _figur_fuer(unit),
		func() -> bool: return bool(_units.get(id, {}).get("alive", true)))
	var name_label := Label.new()
	name_label.text = String(unit.get("name", "?"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 13)
	box.add_child(name_label)

	var wissen := HBoxContainer.new()
	wissen.alignment = BoxContainer.ALIGNMENT_CENTER
	wissen.add_theme_constant_override("separation", 4)
	wissen.visible = false
	box.add_child(wissen)

	var hp_bar := KampfUi.balken(10, KampfUi.HP_GUT, true, false)
	box.add_child(hp_bar)
	var status_label := Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	box.add_child(status_label)
	_panels[id] = {"root": panel, "hp": hp_bar, "status": status_label, "wissen": wissen,
		"sw": ""}
	_enemy_row.add_child(panel)


## 3D-Figur aus den Netz-Daten des Hosts: Beschwörung, Gegner (mit Rang-
## Schmuck) oder Held (Farbwahl + Ausrüstung).
func _figur_fuer(unit: Dictionary) -> Node3D:
	var figur_id := String(unit.get("figur", ""))
	var arch := String(unit.get("arch", ""))
	var figur: Node3D
	if figur_id != "":
		figur = FigurenBau.fuer_archetyp(StringName(figur_id))
	elif arch != "":
		figur = FigurenBau.fuer_archetyp(StringName(arch))
	else:
		var held_name := String(unit.get("name", "?"))
		return FigurenBau.held_mit(FigurenBau.held_farbe_aus(int(unit.get("tile", -1)), held_name),
			unit.get("aus", {}))
	return FigurenBau.schmuecken(figur, String(unit.get("rang", "")), bool(unit.get("gulden", false)))


## Sprite aus den Netz-Daten: Gegner über den Archetyp, Helden übers Porträt.
## Fallbacks: eigener Held » lokales Original, Legacy-Helden » Namens-Tile.
func _unit_sprite(unit: Dictionary, size: int) -> Control:
	var tex: Texture2D = null
	var arch := String(unit.get("arch", ""))
	var unit_name := String(unit.get("name", "?"))
	if _studio != null:
		# Porträt aus der 3D-Figur (Farbe, Ausrüstung, Rang — wie beim Host).
		tex = _studio.textur("%s|%s|%s|%s|%s|%s" % [arch, unit_name, unit.get("tile", -1),
			str(unit.get("aus", {})), unit.get("rang", ""), unit.get("gulden", false)],
			func() -> Node3D: return _figur_fuer(unit))
	if tex == null and arch != "":
		tex = SpriteLib.enemy(StringName(arch))
	var tile := int(unit.get("tile", -1))
	if tex == null and tile >= 0:
		tex = SpriteLib.tile(tile)
	if tex == null and unit_name == _my_name:
		# Eigener Held ohne Porträt-Tile (älterer Spielstand): das lokale
		# Original kennt sein Sprite noch.
		var hero := Net.my_local_hero()
		if hero != null:
			tex = hero.sprite
	if tex == null:
		tex = SpriteLib.hero(unit_name)  # Legacy-Helden mit festen Namen
	if tex != null:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(size, size)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		return rect
	var fallback := ColorRect.new()
	fallback.custom_minimum_size = Vector2(size, size)
	fallback.color = Color.from_hsv(
		float(absi(hash(String(unit.get("name", "?")))) % 360) / 360.0, 0.55, 0.85)
	return fallback
