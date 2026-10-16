extends Control
## Kampfszene: klassische JRPG-Ansicht — Gegner oben, Party unten,
## Aktionsmenü rechts, Kampflog in der Mitte. Die UI wird komplett im Code
## aufgebaut; dahinter läuft die 3D-Arena (KampfBuehne3D), deren Figuren
## sich auf Platzhalter in den Gegner-Panels stellen (STIL-3D.md 7c).

const MAIN_SCENE := "res://scenes/main.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/dungeon_scene.tscn"
## Pause zwischen den Aktionen der Rundenauflösung — bewusst gemächlich,
## damit man (auch im Co-op) nachvollziehen kann, was passiert.
const ACTION_DELAY := 0.9

## Typ-Chips (Pokémon-Stil): Farbe je Angriffselement des Gegners.
const ELEMENT_CHIP_COLORS := {
	Enums.Element.FIRE: Color(1.0, 0.5, 0.25),
	Enums.Element.POISON: Color(0.45, 0.85, 0.3),
	Enums.Element.ICE: Color(0.5, 0.85, 1.0),
	Enums.Element.LIGHTNING: Color(1.0, 0.88, 0.3),
	Enums.Element.HOLY: Color(1.0, 0.93, 0.65),
	Enums.Element.DARK: Color(0.72, 0.45, 1.0),
}
const UNDEAD_CHIP_COLOR := Color(0.8, 0.78, 0.7)

## Was das Element im Kampf bedeutet (Tooltip auf dem Gegner-Panel).
const ELEMENT_HINTS := {
	Enums.Element.FIRE: "Feuer: Treffer bauen Brand-Stacks auf (halbieren sich pro Runde).",
	Enums.Element.POISON: "Gift: permanente Gift-Stacks, bis sie kuriert werden.",
	Enums.Element.ICE: "Eis: kann einfrieren (zerschmetterbar) oder verlangsamen.",
	Enums.Element.LIGHTNING: "Blitz: springt auf ein weiteres Ziel über, kann betäuben.",
	Enums.Element.HOLY: "Heilig: sehr effektiv gegen Untote.",
	Enums.Element.DARK: "Dunkel: raubt Leben und verflucht (+ erlittener Schaden).",
}

var battle := Battle.new()

## Gesetzt, wenn der Kampf aus dem Dungeon kam (statt aus dem Menü-Testkampf).
var _dungeon_context: Dictionary = {}

## Co-op: peer_ids der Gäste, deren Held mitkämpft (gleiche Ebene) — sie
## bekommen nach dem Sieg ihr eigenes Beute-Paket (XP/Gold/Items/Materialien).
var _coop_fighters: Array = []
## Die tatsächlich kämpfende Party (im Co-op ohne Gast-Helden anderer Ebenen).
var _fighting_party: Array[Combatant] = []

## Log-Zeile für einen aktiven Schrein-Segen (nach dem UI-Aufbau ausgegeben).
var _blessing_note := ""

var _active: Combatant = null
var _pending_skill: Skill = null  # null = Basisangriff
var _selecting_target := false

## Kommandophase (DQ-Stil): erst wählen ALLE Spieler ihre Aktion, dann läuft
## die Runde in Temporeihenfolge ab. Combatant » Plan ({"kind", "skill", …}).
var _plans := {}
## Noch unentschiedene, lokal gesteuerte Helden (in Wahl-Reihenfolge).
var _pending_local: Array[Combatant] = []
## Bereits gewählte lokale Helden — für „Befehl ändern“.
var _local_done: Array[Combatant] = []
## Co-op: Held » peer_id — wir warten auf die Wahl dieses Mitspielers.
var _awaiting_remote := {}
## Co-op: stabile Netz-IDs aller Kämpfer (die Arrays verschieben sich).
var _net_ids := {}
var _next_net_id := 0
## true, solange die Runde abläuft (keine Befehls-Menüs).
var _resolving := false

## Combatant » {"root", "hp", "mp" (nur Party), "status"}
var _panels := {}
## Combatant » Button (nur Gegner, für die Zielauswahl)
var _enemy_buttons := {}

var _info_label: Label
var _enemy_row: HBoxContainer
var _party_row: HBoxContainer
var _action_box: VBoxContainer
var _log_label: RichTextLabel
## Effekt-Ereignisse der laufenden Aktion (Battle.effekt), siehe _effekte_abspielen.
var _fx_puffer: Array = []
var _turn_bar: HBoxContainer
var _buehne: KampfBuehne3D
## Porträt-Renderer für Zugleiste/Party (statisch, weil _make_sprite statisch ist).
static var _studio: PortraitStudio


func _ready() -> void:
	theme = UiTheme.get_theme()
	_build_layout()
	_buehne.deckel = _turn_bar  # Riesen-Bosse bleiben unter der Zugleiste

	# Party kommt aus dem GameState (dort ggf. in der Werkstatt umgebaut).
	var party: Array[Combatant] = GameState.party
	var foes: Array[Combatant]
	if not GameState.pending_battle.is_empty():
		_dungeon_context = GameState.pending_battle
		GameState.pending_battle = {}
		foes = _dungeon_context["enemies"]
		# Co-op (Host): Gast-Helden kämpfen nur mit, wenn ihr Spieler auf
		# DERSELBEN Ebene steht (Design-Regel „reingezogen auf gleicher
		# Ebene“). Der Host steuert den Kampf für alle.
		if Net.role == Net.Role.HOST:
			_coop_fighters = Net.guests_on_floor(int(GameState.current_run.get("floor", 0)))
			var filtered: Array[Combatant] = []
			for member in GameState.party:
				if member.has_meta(&"guest_peer") \
						and int(member.get_meta(&"guest_peer")) not in _coop_fighters:
					continue
				filtered.append(member)
			party = filtered
			var fighter_names: Array = []
			for peer_id in _coop_fighters:
				fighter_names.append(Net.guest_name(peer_id))
			Net.broadcast("battle_started", {"host": Net.my_hero_name(),
				"fighters": fighter_names, "is_boss": _dungeon_context["is_boss"]})
		# Attrition im Dungeon: Statuseffekte weg, aber Wunden bleiben.
		for member in party:
			member.reset_for_battle(false)
		# Schrein-Segen (Dungeon-Event): wirkt genau auf den nächsten Kampf.
		if GameState.current_run.has("blessing"):
			var blessing: StringName = GameState.current_run["blessing"]
			GameState.current_run.erase("blessing")
			for member in party:
				if not member.is_alive():
					continue
				if blessing == &"segen_kraft":
					member.add_status(Enums.Status.ATK_UP, 3, 25)
				elif blessing == &"segen_schutz":
					member.add_status(Enums.Status.DEF_UP, 3, 30)
			_blessing_note = "Der Schrein-Segen liegt auf der Party (%s, 3 Runden)!" \
				% ("Angriff +25%" if blessing == &"segen_kraft" else "Rüstung +30%")
	else:
		for member in party:
			member.reset_for_battle(true)
		# Menü-Testkampf: zufällige Baukasten-Gruppe auf Stufe 1.
		var card := DungeonCard.new()
		card.seed = randi()
		card.tier = 1
		card.biome = Enums.Biome.FOREST
		var rng := RandomNumberGenerator.new()
		rng.seed = card.seed
		foes = EnemyFactory.make_encounter(card, rng)
	_fighting_party = party
	battle.log_line.connect(_on_log)
	battle.battle_ended.connect(_on_battle_ended)
	battle.battle_fled.connect(_on_battle_fled)
	battle.combatant_added.connect(_on_combatant_added)
	battle.combatant_removed.connect(_on_combatant_removed)
	battle.element_reaktion.connect(_on_element_reaktion)
	battle.effekt.connect(func(daten: Dictionary) -> void: _fx_puffer.append(daten))
	battle.start(party, foes)
	battle.ueberraschung = int(_dungeon_context.get("ueberraschung", Battle.KEINE_UEBERRASCHUNG))

	# Co-op: stabile Netz-IDs für den Kampf-Sync + Gast-Nachrichten abonnieren.
	for combatant in battle.players:
		_assign_net_id(combatant)
	for combatant in battle.enemies:
		_assign_net_id(combatant)
	if Net.role == Net.Role.HOST and not _coop_fighters.is_empty():
		Net.message_received.connect(_on_net_message)
		Net.guest_left.connect(_on_guest_left)

	for enemy in foes:
		_enemy_row.add_child(_make_enemy_panel(enemy))
	for member in party:
		_party_row.add_child(_make_party_panel(member))

	_refresh_all()
	if not _blessing_note.is_empty():
		_on_log(_blessing_note)
	Music.play(&"boss" if battle.has_boss() else &"kampf")
	Sfx.play(&"kampf_start")
	if battle.has_boss():
		_boss_auftritt()
	if battle.ueberraschung == Battle.ERSTSCHLAG:
		KampfUi.banner(self, Loc.pick("Erstschlag!", "Preemptive strike!"), UiTheme.GOLD)
	elif battle.ueberraschung == Battle.HINTERHALT:
		KampfUi.banner(self, Loc.pick("Hinterhalt!", "Ambush!"), UiTheme.ACCENT)
	_begin_command_phase()

	# Onboarding: die Kommandophase beim allerersten Kampf erklären.
	if GameState.first_time("kampf"):
		UiTheme.show_hint(self, Loc.pick("Dein erster Kampf", "Your first battle"),
			Loc.pick("Erst wählen ALLE Helden ihre Befehle — dann läuft die Runde nach Tempo ab.\n\nVERTEIDIGEN halbiert Schaden, KONZENTRIEREN lädt den nächsten Angriff auf, und FLIEHEN klappt nie gegen Bosse. Die Leiste oben zeigt die Zugreihenfolge.",
			"First ALL heroes choose their commands — then the round plays out by speed.\n\nDEFEND halves damage, FOCUS charges your next attack, and FLEEING never works against bosses. The bar at the top shows the turn order."))


# --- Kampfablauf: Kommandophase » Rundenauflösung (DQ-Stil) -------------------
# Erst wählen ALLE Spieler ihre Aktion (lokal + Co-op-Mitspieler parallel an
# ihren Bildschirmen), dann läuft die Runde in Temporeihenfolge ab — mit
# Pausen, damit jeder nachvollziehen kann, was passiert.

func _begin_command_phase() -> void:
	if battle.is_over:
		return
	# Hinterhalt: in Runde 1 handeln nur die Gegner — keine Befehle zu wählen.
	if battle.round_number == 0 and battle.ueberraschung == Battle.HINTERHALT:
		_plans.clear()
		_pending_local.clear()
		_local_done.clear()
		_awaiting_remote.clear()
		_refresh_all()
		_broadcast_state()
		_resolve_round()
		return
	_resolving = false
	_plans.clear()
	_pending_local.clear()
	_local_done.clear()
	_awaiting_remote.clear()
	for member in battle.players:
		if not member.is_alive() or member.is_summon:
			continue
		if battle.hat_aufladung(member):
			_plans[member] = {"kind": "aufladung"}  # bricht automatisch los
			continue
		var peer_id := _guest_peer_of(member)
		if peer_id >= 0:
			_awaiting_remote[member] = peer_id
		else:
			_pending_local.append(member)
	_refresh_all()
	_broadcast_state()
	# Mitkämpfende Gäste wählen parallel an ihrem eigenen Bildschirm.
	for member in _awaiting_remote:
		Net.send_to_guest(_awaiting_remote[member], "cmd_phase",
			{"you": member.display_name, "round": battle.round_number + 1})
	_broadcast_plans()
	_show_next_local()


## Peer-ID des steuernden Mitspielers — −1 = lokal gesteuert. Getrennte
## Gäste fallen automatisch an den Host zurück (ihr Held kämpft weiter).
func _guest_peer_of(member: Combatant) -> int:
	if member.has_meta(&"guest_peer"):
		var peer_id := int(member.get_meta(&"guest_peer"))
		if peer_id in _coop_fighters and peer_id in Net.guest_ids():
			return peer_id
	return -1


func _show_next_local() -> void:
	if battle.is_over or _resolving:
		return
	if not _pending_local.is_empty():
		_show_actions(_pending_local[0])
		return
	_active = null
	if not _awaiting_remote.is_empty():
		_show_waiting_panel()
		return
	_resolve_round()


## Lokale Wahl steht: Plan merken, weiter zum nächsten Helden.
func _set_plan(member: Combatant, plan: Dictionary) -> void:
	_clear_actions()
	_set_enemy_buttons_enabled(false)
	_clear_target_previews()
	_plans[member] = plan
	_pending_local.erase(member)
	_local_done.append(member)
	_broadcast_plans()
	_refresh_all()
	_show_next_local()


## In der Kommandophase wird nichts sofort ausgeführt — nur geplant.
func _plan_action(skill: Skill, target: Combatant) -> void:
	if skill == null:
		_set_plan(_active, {"kind": "attack", "target": target})
	else:
		_set_plan(_active, {"kind": "skill", "skill": skill, "target": target})


## „Befehl ändern“: der zuletzt gewählte lokale Held entscheidet neu.
func _undo_last_plan() -> void:
	if _local_done.is_empty() or _resolving:
		return
	var member: Combatant = _local_done.pop_back()
	_plans.erase(member)
	_pending_local.push_front(member)
	_broadcast_plans()
	_refresh_all()
	_show_next_local()


func _show_waiting_panel() -> void:
	_clear_actions()
	var names: Array[String] = []
	for member in _awaiting_remote:
		names.append(member.display_name)
	var head := Label.new()
	head.text = Loc.pick("Warte auf: %s …", "Waiting for: %s …") % ", ".join(names)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_box.add_child(head)
	if not _local_done.is_empty():
		var undo := Button.new()
		undo.text = Loc.pick("« Befehl ändern", "« Change command")
		undo.pressed.connect(_undo_last_plan)
		_action_box.add_child(undo)


## Alle Befehle stehen » die Runde läuft in Temporeihenfolge ab.
func _resolve_round() -> void:
	_resolving = true
	_clear_actions()
	# Flinkheit/Wucht der geplanten Skills bestimmen den Platz in der Runde.
	for member in _plans:
		var plan: Dictionary = _plans[member]
		if String(plan.get("kind", "")) == "skill" and plan.get("skill") != null:
			battle.vorrang[member] = (plan["skill"] as Skill).zeit_vorrang()
	var head := Label.new()
	head.text = Loc.pick("Die Runde läuft …", "The round plays out …")
	head.modulate = Color(1, 1, 1, 0.7)
	_action_box.add_child(head)
	while not battle.is_over:
		# Zugbeginn verarbeitet DoT-Ticks/Regeneration — die Zahlen sollen
		# genauso sichtbar aufsteigen wie Treffer.
		var tick_snapshot := _snapshot_hp()
		_fx_puffer.clear()
		var actor := battle.next_turn()
		await _effekte_abspielen()
		if not is_inside_tree():
			break
		_animate_hp_changes(tick_snapshot)
		if actor == null:
			break
		_active = actor
		_refresh_all()
		_broadcast_state()
		await get_tree().create_timer(ACTION_DELAY).timeout
		if not is_inside_tree() or battle.is_over:
			break
		var before := _snapshot_hp()
		_fx_puffer.clear()
		_pulse_sprite(actor)
		if actor.is_player and not actor.is_summon:
			_execute_plan(actor)
			_plans.erase(actor)  # erledigt — die Anzeige zeigt nur noch Offenes
		else:
			battle.ai_take_turn(actor)
		await _effekte_abspielen()
		if not is_inside_tree():
			break
		_animate_hp_changes(before)
		_refresh_all()
		_broadcast_state()
		_broadcast_plans()
		if battle.round_pending():
			break  # Runde abgearbeitet » neue Kommandophase
	_active = null
	if not battle.is_over and is_inside_tree():
		await get_tree().create_timer(ACTION_DELAY * 0.6).timeout
		if is_inside_tree() and not battle.is_over:
			_begin_command_phase()


## Geplante Aktion ausführen — mit Ersatz, falls das Ziel inzwischen fiel.
func _execute_plan(actor: Combatant) -> void:
	# Aufgeladener Skill bricht los — der Zug gehört ihm.
	if battle.hat_aufladung(actor):
		battle.aufladung_ausloesen(actor)
		return
	var plan: Dictionary = _plans.get(actor, {"kind": "defend"})
	match String(plan.get("kind", "defend")):
		"attack":
			var target := _valid_enemy_target(plan.get("target"))
			if target != null:
				battle.basic_attack(actor, target)
		"skill":
			var skill: Skill = plan.get("skill")
			var target: Combatant = plan.get("target")
			if skill.get_form() == Enums.SkillForm.ALLY:
				if target == null or not target.is_alive():
					target = actor
			elif skill.get_form() == Enums.SkillForm.SINGLE:
				target = _valid_enemy_target(target)
				if target == null:
					return
			if not battle.use_skill(actor, skill, target):
				# Zu wenig MP/falsche Waffe: Ersatz-Basisangriff statt Leerlauf.
				var fallback := _valid_enemy_target(null)
				if fallback != null:
					battle.basic_attack(actor, fallback)
		"item":
			var def: ConsumableDef = plan.get("def")
			var target: Combatant = plan.get("target")
			if def != null and target != null \
					and GameState.consumable_count(def.id) > 0 \
					and battle.use_consumable(actor, def, target):
				GameState.consume(def.id)
			else:
				_on_log(Loc.pick("%s findet kein gültiges Ziel mehr — der Zug verfällt.",
					"%s no longer has a valid target — the turn is lost.") % actor.display_name)
		"focus":
			battle.concentrate(actor)
			Sfx.play(&"zauber")
		"flee":
			battle.attempt_flee(actor)
		_:
			battle.defend(actor)


## Das geplante Ziel, falls es noch lebt — sonst der erste lebende Gegner.
func _valid_enemy_target(planned: Variant) -> Combatant:
	if planned is Combatant and planned.is_alive() and not planned.is_player:
		return planned
	for enemy in battle.enemies:
		if enemy.is_alive():
			return enemy
	return null


## Anzeige der geplanten Aktion am Party-Panel (jeder sieht, was die
## anderen vorhaben — gerade im Co-op gewünscht).
func _plan_text(combatant: Combatant) -> String:
	if _plans.has(combatant):
		return "» " + _describe_plan(_plans[combatant])
	if _awaiting_remote.has(combatant) or combatant in _pending_local:
		return Loc.pick("» wählt …", "» choosing …")
	return ""


static func _describe_plan(plan: Dictionary) -> String:
	match String(plan.get("kind", "")):
		"attack":
			var target: Variant = plan.get("target")
			var text := Loc.pick("Angriff", "Attack")
			if target is Combatant:
				text += " » %s" % target.display_name
			return text
		"skill":
			var skill: Skill = plan.get("skill")
			var target: Variant = plan.get("target")
			var text := skill.display_name
			if target is Combatant:
				text += " » %s" % target.display_name
			return text
		"aufladung":
			return Loc.pick("entfesselt den aufgeladenen Skill", "unleashes the charged skill")
		"defend":
			return Loc.pick("Verteidigen", "Defend")
		"focus":
			return Loc.pick("Konzentrieren", "Focus")
		"item":
			var def: ConsumableDef = plan.get("def")
			var target: Variant = plan.get("target")
			var text: String = def.display_name if def != null else "Item"
			if target is Combatant:
				text += " » %s" % target.display_name
			return text
		"flee":
			return Loc.pick("Fliehen", "Flee")
	return "?"


# --- Co-op: Kampf-Sync mit mitkämpfenden Gästen -------------------------------
# Der Host bleibt Autorität: Gäste schicken nur ihre Aktionswahl ("cmd_pick"),
# zurück fließen Zustand ("bstate"), Pläne ("cmd_update") und Log ("blog").

func _assign_net_id(combatant: Combatant) -> void:
	if not _net_ids.has(combatant):
		_net_ids[combatant] = _next_net_id
		_next_net_id += 1


func _combatant_by_id(id: int) -> Combatant:
	for combatant in _net_ids:
		if int(_net_ids[combatant]) == id:
			return combatant
	return null


func _send_fighters(type: String, data: Dictionary) -> void:
	if Net.role != Net.Role.HOST:
		return
	for peer_id in _coop_fighters:
		Net.send_to_guest(peer_id, type, data)


func _broadcast_state() -> void:
	if _coop_fighters.is_empty():
		return
	var units: Array = []
	for combatant in battle.players:
		units.append(_unit_data(combatant, "p"))
	for combatant in battle.enemies:
		units.append(_unit_data(combatant, "e"))
	# Zugreihenfolge für die Gast-Zugleiste: aktueller Kämpfer + die nächsten.
	var order: Array = []
	var active_id := -1
	if _active != null and _active.is_alive():
		active_id = int(_net_ids.get(_active, -1))
		order.append(active_id)
	for combatant in battle.upcoming_turns(7):
		order.append(int(_net_ids.get(combatant, -1)))
	_send_fighters("bstate", {"round": battle.round_number, "units": units,
		"order": order, "active": active_id})


func _unit_data(combatant: Combatant, side: String) -> Dictionary:
	var status_names: Array = []
	for entry in combatant.statuses:
		status_names.append(Battle.status_label(entry))
	return {"id": int(_net_ids.get(combatant, -1)), "side": side,
		"name": combatant.display_name, "hp": combatant.hp, "maxhp": combatant.max_hp,
		"mp": combatant.mp, "maxmp": combatant.max_mp, "alive": combatant.is_alive(),
		"tile": combatant.portrait_tile, "arch": String(combatant.archetype_id),
		"boss": combatant.is_boss, "st": status_names,
		"scale": combatant.sprite_scale,
		# 3D-Figur beim Gast: Ausrüstung (Helden), Rang/Glanz (Gegner), Beschwörung.
		"aus": FigurenBau.ausruestung_von(combatant) if combatant.is_player else {},
		"rang": String(combatant.get_meta(&"rang", "")),
		"gulden": bool(combatant.get_meta(&"gulden", false)),
		"sonder": String(combatant.get_meta(&"sonder", "")),
		"figur": String(combatant.get_meta(&"figur", "")),
		"sw": [] if combatant.is_player else KampfUi.element_wissen(combatant),
		"sid": combatant.statuses.map(func(entry: Dictionary) -> int: return int(entry["status"]))}


func _broadcast_plans() -> void:
	if _coop_fighters.is_empty():
		return
	var plans: Array = []
	for member in battle.players:
		if member.is_summon:
			continue
		plans.append({"id": int(_net_ids.get(member, -1)), "text": _plan_text(member)})
	_send_fighters("cmd_update", {"plans": plans})


## Nachrichten der mitkämpfenden Gäste (Szenen-Handshake + Aktionswahl).
func _on_net_message(peer_id: int, type: String, data: Dictionary) -> void:
	if peer_id not in _coop_fighters:
		return
	match type:
		"cmd_ready":
			# Der Gast steht jetzt in seiner Kampfansicht: Zustand nachliefern
			# (Nachrichten vor seinem Szenenwechsel gingen ins Leere).
			_broadcast_state()
			_broadcast_plans()
			var hero := Net.guest_hero(peer_id)
			if hero != null and _awaiting_remote.has(hero):
				Net.send_to_guest(peer_id, "cmd_phase",
					{"you": hero.display_name, "round": battle.round_number + 1})
		"cmd_pick":
			var hero := Net.guest_hero(peer_id)
			if hero == null or not _awaiting_remote.has(hero):
				return
			_awaiting_remote.erase(hero)
			_plans[hero] = _plan_from_net(hero, data)
			_broadcast_plans()
			_refresh_all()
			# Wählt der Host selbst noch, startet _show_next_local die Runde
			# später — stand schon das Warten-Panel, geht es jetzt los.
			if _pending_local.is_empty() and _awaiting_remote.is_empty() \
					and not _resolving and _active == null:
				_show_next_local()
		"cmd_swap":
			# Freie Aktion: Waffenset des Gast-Helden wechseln.
			var hero := Net.guest_hero(peer_id)
			if hero != null and hero.has_second_weapon_set():
				hero.swap_weapon_set()
				_on_log(Loc.pick("%s wechselt das Waffenset.", "%s swaps weapon sets.")
					% hero.display_name)
				_broadcast_state()


## Gast-Wahl in einen Plan übersetzen — mit Validierung, der Host bleibt
## Autorität (ungültige Wahl » Verteidigen).
func _plan_from_net(hero: Combatant, data: Dictionary) -> Dictionary:
	var target := _combatant_by_id(int(data.get("target", -1)))
	match String(data.get("kind", "")):
		"attack":
			return {"kind": "attack", "target": target}
		"skill":
			var index := int(data.get("skill", -1))
			if index < 0 or index >= mini(hero.skills.size(), hero.skill_slots()):
				return {"kind": "defend"}
			var skill: Skill = hero.skills[index]
			if not skill.is_valid(hero):
				return {"kind": "defend"}
			return {"kind": "skill", "skill": skill, "target": target}
		"focus":
			return {"kind": "focus"}
	return {"kind": "defend"}


## Mitspieler getrennt: sein Held fällt an den Host zurück (nächste Runde);
## läuft gerade seine Wahl, wird sie durch Verteidigen ersetzt.
func _on_guest_left(_guest_name: String) -> void:
	for member in _awaiting_remote.keys():
		if int(_awaiting_remote[member]) not in Net.guest_ids():
			_awaiting_remote.erase(member)
			_plans[member] = {"kind": "defend"}
	_broadcast_plans()
	_refresh_all()
	if not _resolving and _active == null and not battle.is_over:
		_show_next_local()


# --- Aktionsmenü ------------------------------------------------------------

func _show_actions(actor: Combatant) -> void:
	_active = actor
	_clear_actions()
	for combatant in _panels:
		if _panels[combatant].has("plan"):
			KampfUi.aktiv_setzen(_panels[combatant]["root"], combatant == actor)

	var head := Label.new()
	head.text = Loc.pick("Befehl für %s", "Command for %s") % actor.display_name
	_action_box.add_child(head)

	var attack := Button.new()
	attack.text = Loc.pick("Angriff", "Attack")
	attack.pressed.connect(_begin_target_selection.bind(null))
	_action_box.add_child(attack)
	attack.grab_focus.call_deferred()  # Tastatur-Navigation: sofort bedienbar

	# Skills in einem eigenen Untermenü statt direkt in den Aktionen —
	# bei vielen gebauten Skills bleibt das Menü übersichtlich.
	var skill_count := 0
	for skill: Skill in actor.skills.slice(0, actor.skill_slots()):
		if not skill.get_sources().is_empty():
			skill_count += 1
	if skill_count > 0:
		var skills_button := Button.new()
		skills_button.text = Loc.pick("Skills (%d) »", "Skills (%d) »") % skill_count
		skills_button.pressed.connect(_show_skill_menu)
		_action_box.add_child(skills_button)

	var defend := Button.new()
	defend.text = Loc.pick("Verteidigen", "Defend")
	defend.pressed.connect(func() -> void:
		_set_plan(_active, {"kind": "defend"}))
	_action_box.add_child(defend)

	var focus := Button.new()
	focus.text = Loc.pick("Konzentrieren", "Focus")
	focus.tooltip_text = Loc.pick(
		"Opfert den Zug: nächster Angriff +50% Schaden (stapelbar bis +200%).",
		"Sacrifices the turn: next attack +50% damage (stacks up to +200%).")
	focus.pressed.connect(func() -> void:
		_set_plan(_active, {"kind": "focus"}))
	_action_box.add_child(focus)

	if not GameState.consumables.is_empty():
		var item_button := Button.new()
		item_button.text = "Item"
		item_button.pressed.connect(_show_item_menu)
		_action_box.add_child(item_button)

	# Waffenset wechseln: FREIE Aktion — Skills/Vorschau passen sich an.
	if actor.has_second_weapon_set():
		var set_swap := Button.new()
		var other_weapon: ItemInstance = actor.weapon_set_b.get(Enums.EquipSlot.WEAPON)
		set_swap.text = Loc.pick("Waffenset » %s", "Weapon set » %s") \
			% (other_weapon.get_display_name() if other_weapon != null else Loc.pick("(leer)", "(empty)"))
		set_swap.tooltip_text = Loc.pick("Freie Aktion: Haupt-/Nebenhand tauschen — deckt andere Gegner-Schwächen ab.",
			"Free action: swap main/off hand — covers different enemy weaknesses.")
		set_swap.pressed.connect(func() -> void:
			actor.swap_weapon_set()
			Sfx.play(&"bestaetigen")
			_on_log(Loc.pick("%s wechselt das Waffenset.", "%s swaps weapon sets.") % actor.display_name)
			_refresh_all()
			_show_actions(actor))
		_action_box.add_child(set_swap)

	# Fliehen — vor Bossen gibt es kein Entkommen (Button fehlt komplett).
	if not battle.has_boss():
		var flee_button := Button.new()
		flee_button.text = Loc.pick("Fliehen", "Flee")
		flee_button.tooltip_text = Loc.pick(
			"Fluchtchance aus dem Geschick-Vergleich (Party vs. Gegner).\nMisslingt die Flucht, ist der Zug verbraucht.",
			"Escape chance from the agility comparison (party vs. enemies).\nA failed attempt spends the turn.")
		flee_button.pressed.connect(_on_flee_pressed)
		_action_box.add_child(flee_button)

	# „Befehl ändern“: die Wahl des vorherigen Helden zurücknehmen.
	if not _local_done.is_empty():
		var undo := Button.new()
		undo.text = Loc.pick("« Befehl ändern", "« Change command")
		undo.pressed.connect(_undo_last_plan)
		_action_box.add_child(undo)


## Skills-Untermenü: alle gebauten Skills der freigeschalteten Slots
## (+1 alle 5 Level) — Waffentechniken sind ohne passende Waffe gesperrt.
func _show_skill_menu() -> void:
	_clear_actions()
	var head := Label.new()
	head.text = Loc.pick("Skill wählen", "Choose a skill")
	_action_box.add_child(head)
	var first_enabled: Button = null
	for skill: Skill in _active.skills.slice(0, _active.skill_slots()):
		if skill.get_sources().is_empty():
			continue  # leere Werkstatt-Slots tauchen im Kampf nicht auf
		var cost: int = skill.get_mp_cost(_active)
		var wrong_weapon := not skill.usable_with_weapon(_active)
		var grund := skill.fehler(_active)
		var button := Button.new()
		button.text = "%s (%d MP)" % [skill.display_name, cost]
		var voll := skill.hat(Enums.SkillModifier.VOLLHEILUNG)
		if voll:
			# Vollheilung: MP nach Bedarf (Richtwert = normale Kosten), notfalls alle.
			button.text = Loc.pick("%s (MP nach Bedarf)", "%s (MP as needed)") % skill.display_name
			cost = 1
		if not grund.is_empty():
			button.text += Loc.pick("  [ungültig]", "  [invalid]")
		elif wrong_weapon:
			button.text += Loc.pick("  [braucht %s]", "  [needs %s]") \
				% BlockLibrary.families_label(skill.required_weapon_families())
		button.disabled = _active.mp < cost or wrong_weapon or not grund.is_empty()
		button.tooltip_text = grund if not grund.is_empty() else _skill_tooltip(skill, cost)
		button.pressed.connect(_on_skill_pressed.bind(skill))
		_action_box.add_child(button)
		if first_enabled == null and not button.disabled:
			first_enabled = button
	var back := Button.new()
	back.text = Loc.pick("« Zurück", "« Back")
	back.pressed.connect(func() -> void: _show_actions(_active))
	_action_box.add_child(back)
	(first_enabled if first_enabled != null else back).grab_focus.call_deferred()


func _on_flee_pressed() -> void:
	# Flucht ist ein geplanter Befehl wie jeder andere: der Versuch passiert,
	# wenn der Held am Zug ist (misslingt er, ist der Zug verbraucht).
	_set_plan(_active, {"kind": "flee"})


## Erfolgreiche Flucht: kein Sieg, keine Niederlage — zurück in den Dungeon,
## der Gegner bleibt stehen (kurze Schonfrist, damit er nicht sofort wieder
## zuschnappt).
func _on_battle_fled() -> void:
	_clear_actions()
	Sfx.play(&"treppe")
	if Net.role == Net.Role.HOST and not _dungeon_context.is_empty():
		Net.broadcast("battle_ended", {"victory": false, "fled": true})
	if not _dungeon_context.is_empty():
		GameState.flee_grace_enemy = int(_dungeon_context.get("enemy_id", -1))
		get_tree().change_scene_to_file(DUNGEON_SCENE)
	else:
		get_tree().change_scene_to_file(MAIN_SCENE)


## Tooltip: woraus der Skill gebaut ist — direkt im Kampf nachschlagbar.
static func _skill_tooltip(skill: Skill, cost: int) -> String:
	var parts: Array[String] = []
	for block in skill.blocks:
		if not block.display_name.is_empty():
			parts.append(block.display_name)
	var text := Loc.pick("Bausteine: %s\nKosten: %d MP", "Blocks: %s\nCost: %d MP") % [" + ".join(parts), cost]
	for effect in skill.get_effect_blocks():
		text += "\n· " + Battle.status_effect_text(effect.status, effect.potency)
	if skill.has_technique():
		text += "\n" + Loc.pick("Waffentechnik — nur mit: %s", "Weapon technique — only with: %s") \
			% BlockLibrary.families_label(skill.required_weapon_families())
	return text


## Item-Menü: Trank wählen » Party-Mitglied als Ziel wählen » Zug verbraucht.
func _show_item_menu() -> void:
	_clear_actions()
	var head := Label.new()
	head.text = Loc.pick("Item wählen", "Choose an item")
	_action_box.add_child(head)
	for id in GameState.consumables:
		var def := ConsumableLibrary.get_def(id)
		if def == null:
			continue
		var button := Button.new()
		button.text = "%s (×%d)" % [def.display_name, GameState.consumable_count(id)]
		button.tooltip_text = def.description
		button.pressed.connect(_show_item_targets.bind(def))
		_action_box.add_child(button)
	var back := Button.new()
	back.text = Loc.pick("Zurück", "Back")
	back.pressed.connect(func() -> void: _show_actions(_active))
	_action_box.add_child(back)


func _show_item_targets(def: ConsumableDef) -> void:
	_clear_actions()
	var head := Label.new()
	head.text = "%s auf wen?" % def.display_name
	_action_box.add_child(head)
	var needs_dead := def.effect == Enums.ConsumableEffect.REVIVE
	for member in battle.players:
		if member.is_alive() == needs_dead:
			continue
		var button := Button.new()
		button.text = "%s (%d/%d HP)" % [member.display_name, member.hp, member.max_hp]
		button.pressed.connect(_use_item_on.bind(def, member))
		_action_box.add_child(button)
	var back := Button.new()
	back.text = Loc.pick("Zurück", "Back")
	back.pressed.connect(_show_item_menu)
	_action_box.add_child(back)


func _use_item_on(def: ConsumableDef, target: Combatant) -> void:
	_set_plan(_active, {"kind": "item", "def": def, "target": target})


func _on_skill_pressed(skill: Skill) -> void:
	match skill.get_form():
		Enums.SkillForm.SINGLE:
			_begin_target_selection(skill)   # ein Gegner
		Enums.SkillForm.ALLY:
			_begin_ally_selection(skill)     # ein Verbündeter
		_:
			_plan_action(skill, null)        # Fläche/Aura/Selbst: kein Ziel nötig


## Zielauswahl auf einen Verbündeten (Form „Verbündeter") — Buttons im Aktionsmenü.
func _begin_ally_selection(skill: Skill) -> void:
	_clear_actions()
	var head := Label.new()
	head.text = "Verbündeten wählen …"
	_action_box.add_child(head)
	for member in battle.players:
		if not member.is_alive():
			continue
		var button := Button.new()
		button.text = "%s (%d/%d HP)" % [member.display_name, member.hp, member.max_hp]
		button.pressed.connect(_plan_action.bind(skill, member))
		_action_box.add_child(button)
	var cancel := Button.new()
	cancel.text = "Zurück"
	cancel.pressed.connect(func() -> void: _show_actions(_active))
	_action_box.add_child(cancel)


func _begin_target_selection(skill: Skill) -> void:
	_pending_skill = skill
	_selecting_target = true
	_clear_actions()

	var hint := Label.new()
	hint.text = Loc.pick("Ziel wählen …", "Choose a target …")
	_action_box.add_child(hint)

	var cancel := Button.new()
	cancel.text = "Zurück"
	cancel.pressed.connect(func() -> void:
		_selecting_target = false
		_set_enemy_buttons_enabled(false)
		_clear_target_previews()
		_show_actions(_active))
	_action_box.add_child(cancel)

	_set_enemy_buttons_enabled(true)
	_show_target_previews()
	# Tastatur: erstes lebendes Ziel fokussieren (Pfeile wechseln, Enter wählt).
	for enemy in _enemy_buttons:
		if enemy.is_alive():
			(_enemy_buttons[enemy] as Button).grab_focus.call_deferred()
			break


func _on_enemy_clicked(enemy: Combatant) -> void:
	if not _selecting_target or not enemy.is_alive():
		return
	_selecting_target = false
	_clear_target_previews()
	_plan_action(_pending_skill, enemy)


## Schadensvorschau an allen lebenden Gegnern einblenden (Zielwahl-Phase).
func _show_target_previews() -> void:
	if _active == null:
		return
	for enemy in _enemy_buttons:
		if not enemy.is_alive() or not _panels.has(enemy):
			continue
		var estimate := _estimate_action(_active, _pending_skill, enemy)
		var label: Label = _panels[enemy]["preview"]
		label.text = estimate["text"]
		label.modulate = Color(0.55, 1.0, 0.55) if estimate["effective"] \
			else Color(1.0, 0.95, 0.5)


func _clear_target_previews() -> void:
	for combatant in _panels:
		var panel: Dictionary = _panels[combatant]
		if panel.has("preview"):
			panel["preview"].text = ""


## Schadensvorschau: dieselben Formeln wie der Kampf (via preview_mitigated),
## ohne Krit — daher "≈". effective = trifft eine Schwäche (Heilig vs. Untot,
## Zerschmettern von Eingefrorenen, Hinrichtung unter der HP-Schwelle).
func _estimate_action(actor: Combatant, skill: Skill, target: Combatant) -> Dictionary:
	var total := 0
	var stack_parts: Array[String] = []
	var effective := false

	if skill == null:
		# Basisangriff mit Waffen-Besonderheit (Axt ×2, Dolch zweimal …).
		if target.has_status(Enums.Status.FROZEN):
			effective = true
		var waffe := battle.vorschau_waffe(actor)
		var raw := float(Battle.BASIC_ATTACK_BASE + actor.stat(&"strength")
			+ actor.weapon_damage()) * actor.training_weapon_mult()
		total += roundi(battle.preview_mitigated(actor, target, raw, Enums.DamageAxis.PHYSICAL,
			actor.weapon_subtypes(), clampf(waffe["pierce"], 0.0, 0.9)) * waffe["faktor"])
	else:
		var form_block := skill.get_form_block()
		var power_mult := (form_block.power_multiplier if form_block != null else 1.0) \
			* skill.schaden_faktor()
		# Treffer auf DIESES Ziel: bei Zufalls-/Wechselziel nur einer sicher.
		var hits := skill.schaden_je_treffer()
		if not (skill.hat(Enums.SkillModifier.ZIEL_ZUFALL) or skill.hat(Enums.SkillModifier.ZIEL_WECHSEL)):
			hits *= skill.treffer()
		var pierce := 0.0
		for mod in skill.get_modifier_blocks():
			match mod.modifier:
				Enums.SkillModifier.OVERLOAD:
					power_mult *= 1.0 + mod.magnitude / 100.0
				Enums.SkillModifier.PIERCE_ARMOR:
					pierce = maxf(pierce, mod.magnitude / 100.0)
		var situation := battle.vorschau_situation(actor, skill, target)
		if situation > 1.0:
			effective = true
		var element_block := skill.get_element()
		for source in skill.get_sources():
			if source.source == Enums.SkillSource.WEAPON:
				if target.has_status(Enums.Status.FROZEN):
					effective = true
				var waffe := battle.vorschau_waffe(actor, skill.hat(Enums.SkillModifier.KEIN_ERSCHOEPFT))
				var raw := (actor.weapon_damage()
					+ actor.stat(&"strength") * source.scaling_per_point) \
					* power_mult * source.power_multiplier * situation \
					* actor.training_weapon_mult()
				var weapon_pierce := clampf(pierce + waffe["pierce"], 0.0, 0.9)
				total += roundi(battle.preview_mitigated(actor, target, raw,
					Enums.DamageAxis.PHYSICAL, actor.weapon_subtypes(), weapon_pierce) \
					* waffe["faktor"] * hits)
				var riders := actor.element_riders()
				for rider_element in riders:
					var rider_block := BlockLibrary.element_block(rider_element)
					if rider_block != null:
						var part := _estimate_element(actor, target,
							riders[rider_element] * power_mult, rider_block, pierce)
						total += roundi(part["damage"] * hits)
						if part["stacks"] > 0:
							stack_parts.append("+%d %s" % [roundi(part["stacks"] * hits), part["kind"]])
						effective = effective or part["effective"]
				# Element-Baustein auf Waffennutzung ("Flammenklinge"): halber
				# Rohschaden als Element obendrauf (gleiche Formel wie im Kampf).
				if element_block != null:
					var element_part := _estimate_element(actor, target,
						raw * 0.5, element_block, pierce)
					total += roundi(element_part["damage"] * hits)
					if element_part["stacks"] > 0:
						stack_parts.append("+%d %s" % [roundi(element_part["stacks"] * hits),
							element_part["kind"]])
					effective = effective or element_part["effective"]
			else:
				var raw := (actor.spell_damage()
					+ actor.stat(&"intelligence") * source.scaling_per_point) \
					* power_mult * source.power_multiplier * situation \
					* actor.training_spell_mult()
				if element_block != null:
					var part := _estimate_element(actor, target, raw, element_block, pierce)
					total += roundi(part["damage"] * hits)
					if part["stacks"] > 0:
						stack_parts.append("+%d %s" % [roundi(part["stacks"] * hits), part["kind"]])
					effective = effective or part["effective"]
				else:
					total += roundi(battle.preview_mitigated(actor, target, raw,
						Enums.DamageAxis.MAGICAL, [], pierce) * hits)

	var parts: Array[String] = []
	if total > 0:
		parts.append("≈%d Schaden" % total)
	parts.append_array(stack_parts)
	var text := "  ".join(parts)
	if effective and not text.is_empty():
		text += " !"
	return {"text": text, "effective": effective}


## Element-Anteil der Vorschau: DoT-Elemente liefern Stacks, Rest Direktschaden.
func _estimate_element(actor: Combatant, target: Combatant, raw: float,
		element_block: ElementBlock, pierce: float) -> Dictionary:
	var resist := target.element_resist(element_block.element)
	if resist > 0:
		raw = maxf(1.0, raw * (1.0 - resist / 100.0 * (1.0 - pierce)))
	match element_block.element:
		Enums.Element.FIRE, Enums.Element.POISON:
			var kind := "Brand" if element_block.element == Enums.Element.FIRE else "Gift"
			return {"damage": 0, "kind": kind, "effective": false,
				"stacks": maxi(1, roundi(raw * element_block.status_scale))}
		Enums.Element.HOLY:
			var holy_raw := raw * (Battle.HOLY_UNDEAD_BONUS if target.is_undead else 1.0)
			return {"damage": battle.preview_mitigated(actor, target, holy_raw,
				Enums.DamageAxis.MAGICAL, [], pierce),
				"stacks": 0, "kind": "", "effective": target.is_undead}
	return {"damage": battle.preview_mitigated(actor, target, raw,
		Enums.DamageAxis.MAGICAL, [], pierce),
		"stacks": 0, "kind": "", "effective": false}


func _set_enemy_buttons_enabled(enabled: bool) -> void:
	for enemy in _enemy_buttons:
		var button: Button = _enemy_buttons[enemy]
		button.disabled = not (enabled and enemy.is_alive())


func _clear_actions() -> void:
	for child in _action_box.get_children():
		child.queue_free()


# --- Kampfende --------------------------------------------------------------

func _on_battle_ended(victory: bool) -> void:
	_clear_actions()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	# Mehrseitiges Ergebnis (Spieltest: „zu viel Zeug auf einmal“):
	# Seite 1 = Ausgang + Beute · Seite 2 = Level-Ups + Punkte verteilen ·
	# Seite 3 = Belohnungskarte wählen. Leere Seiten entfallen.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var level_box := VBoxContainer.new()
	level_box.add_theme_constant_override("separation", 12)
	panel.add_child(level_box)
	var reward_box := VBoxContainer.new()
	reward_box.add_theme_constant_override("separation", 12)
	panel.add_child(reward_box)

	var label := Label.new()
	label.text = Loc.pick("Sieg!", "Victory!") if victory else Loc.pick("Niederlage …", "Defeat …")
	label.add_theme_font_size_override("font_size", 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	Sfx.play(&"sieg" if victory else &"niederlage")

	# Beute und XP gibt es nur für Dungeon-Kämpfe (der Menü-Testkampf wäre
	# sonst eine kostenlose Farm).
	if victory and not _dungeon_context.is_empty():
		var run_affixes: Array[StringName] = GameState.current_run["card"].card_affix_ids
		# Jagd-Aufträge des Händlers zählen jeden echten Kill mit.
		var kill_count := 0
		for foe in battle.enemies:
			if not foe.is_summon:
				kill_count += 1
		GameState.note_kills(kill_count)
		for foe in battle.enemies:
			if not foe.is_summon:
				GameState.record_kill(foe.archetype_id)
		# XP wird auf die Helden im Kampf GETEILT (auch Gefallene bekommen
		# ihren Anteil — kein Feel-Bad), jeder mit seinem Level-Faktor.
		# Beschwörungen geben weder XP noch Beute.
		var real_foes: Array[Combatant] = []
		for foe in battle.enemies:
			if not foe.is_summon:
				real_foes.append(foe)
		var helden_im_kampf: Array[Combatant] = []
		for member in _fighting_party:
			if not member.is_summon:
				helden_im_kampf.append(member)
		var is_boss_kampf: bool = _dungeon_context["is_boss"]
		var xp_total := LootGenerator.xp_fuer(real_foes, is_boss_kampf, run_affixes)
		# Nachzügler-Bonus: der niedrigste Held bekommt die Hälfte (VOR dem
		# Level-Up berechnen — sonst verschiebt der erste Aufstieg die Verteilung).
		var xp_je_held := LootGenerator.xp_fuer_helden(real_foes, is_boss_kampf, run_affixes,
			helden_im_kampf)
		var xp_label := Label.new()
		xp_label.text = "+%d XP" % xp_total
		if helden_im_kampf.size() > 1:
			var teile: Array[String] = []
			var verteilung := LootGenerator.xp_verteilung(helden_im_kampf)
			for member in helden_im_kampf:
				var teil := "%s +%d" % [member.display_name, int(xp_je_held[member])]
				if verteilung[member] > 1.0 / helden_im_kampf.size() + 0.001:
					teil += Loc.pick(" (Nachzügler)", " (catching up)")
				teile.append(teil)
			xp_label.text += "\n" + "  ·  ".join(teile)
		xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		xp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(xp_label)
		var leveled := false
		for member in _fighting_party:
			var gained := member.gain_xp(int(xp_je_held.get(member, 0)))
			if gained > 0:
				if not leveled:
					leveled = true
					Sfx.play(&"level_up")
				var level_label := Label.new()
				level_label.text = Loc.pick("%s erreicht Level %d! (+%d Statuspunkte, +%d Skillpunkte)",
					"%s reaches level %d! (+%d stat points, +%d skill points)") \
					% [member.display_name, member.level,
					gained * member.stat_points_per_level(),
					Combatant.skill_punkte_bis(member.level) - Combatant.skill_punkte_bis(member.level - gained)]
				if CharacterDef.skill_slots_for_level(member.level) \
						> CharacterDef.skill_slots_for_level(member.level - gained):
					level_label.text += Loc.pick("  (+1 Skill-Slot)", "  (+1 skill slot)")
				level_label.modulate = Color(0.55, 1.0, 0.55)
				level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				level_box.add_child(level_label)
				# Skillbau 3.0: jeder Aufstieg bringt (fast immer) einen neuen Klotz.
				var neu := BlockLibrary.aufstieg_text(member.level - gained, member.level, member.rebirths)
				if not neu.is_empty():
					var neu_label := Label.new()
					neu_label.text = neu + Loc.pick("  — in der Werkstatt (Taste %s)", "  — in the workshop (key %s)") \
						% Settings.key_name(&"open_workshop")
					neu_label.add_theme_color_override("font_color", UiTheme.GOLD)
					neu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					neu_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					level_box.add_child(neu_label)

		# Bank-Helden trainieren mit (10 %, bis 5 Level unter der Party).
		var bank_auf := GameState.bank_mittraining(xp_total)
		if not bank_auf.is_empty():
			var bank_label := Label.new()
			bank_label.text = Loc.pick("Auf der Bank mittrainiert: %s", "Trained on the bench: %s") % ", ".join(bank_auf)
			bank_label.modulate = Color(0.7, 0.9, 1.0)
			bank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			level_box.add_child(bank_label)

		# Verschnaufen: Gefallene stehen wieder auf, alle regenerieren 25%.
		for member in _fighting_party:
			member.hp = maxi(member.hp, 1)
			member.heal(roundi(member.max_hp * 0.25))
			member.mp = mini(member.max_mp, member.mp + roundi(member.max_mp * 0.25))
		var rest_label := Label.new()
		rest_label.text = Loc.pick("Die Party verschnauft (+25% HP/MP).", "The party catches its breath (+25% HP/MP).")
		rest_label.modulate = Color(1, 1, 1, 0.6)
		rest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(rest_label)

		var tier: int = GameState.current_run["card"].tier
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		# Glück der Party zahlt auf die Beute ein (Gold + Drop-Chance).
		var luck_sum := 0
		for member in _fighting_party:
			luck_sum += member.stat(&"luck")
		var loot := LootGenerator.roll_battle_loot(
			real_foes, tier, _dungeon_context["is_boss"], rng,
			luck_sum / maxi(1, _fighting_party.size()))
		if &"reich" in run_affixes:
			loot["gold"] = roundi(loot["gold"] * 1.6)
		GameState.gold += loot["gold"]
		var gold_label := Label.new()
		gold_label.text = "+%d Gold" % loot["gold"]
		gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(gold_label)
		# Kartenhüter: seltene Schatzkarte (episch/legendär).
		for foe in real_foes:
			if not foe.get_meta(&"schatzkarte", false) or foe.is_alive():
				continue
			var schatz := CardFactory.make_schatzkarte(tier)
			var karten_label := Label.new()
			karten_label.text = Loc.pick("Schatzkarte erbeutet: %s (Stufe %d, %s)%s",
				"Treasure map found: %s (tier %d, %s)%s") % [schatz.display_name, schatz.tier,
				LootGenerator.RARITY_NAMES[schatz.card_rarity],
				"" if GameState.add_card(schatz) else Loc.pick(" — Kartenlager voll!", " — map storage full!")]
			karten_label.add_theme_color_override("font_color", UiTheme.GOLD)
			karten_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			karten_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(karten_label)
		for item in loot["items"]:
			GameState.inventory.append(item)
			var item_label := Label.new()
			item_label.text = "%s (%s)" % [item.get_display_name(),
				LootGenerator.RARITY_NAMES[item.rarity]]
			item_label.modulate = LootGenerator.RARITY_COLORS[item.rarity]
			item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(item_label)
		if _dungeon_context["is_boss"] and rng.randf() < 0.3:
			GameState.medals += 1
			var medal_label := Label.new()
			medal_label.text = Loc.pick("+1 Mini-Medaille!", "+1 mini medal!")
			medal_label.modulate = Color(1.0, 0.85, 0.4)
			medal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(medal_label)
		for material_id in loot["materials"]:
			GameState.add_material(material_id)
			var material_label := Label.new()
			material_label.text = "+1 %s" % MaterialLibrary.display_name(material_id)
			material_label.modulate = Color(0.6, 0.95, 0.7)
			material_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(material_label)

		# Co-op: Mitkämpfer-Gäste nehmen dasselbe Paket mit nach Hause —
		# XP auf ihren Helden, Gold/Items/Materialien in ihren Spielstand.
		if not _coop_fighters.is_empty():
			var mats_out := {}
			for material_id in loot["materials"]:
				mats_out[String(material_id)] = int(mats_out.get(String(material_id), 0)) + 1
			var items_out: Array = []
			for item in loot["items"]:
				items_out.append(item.to_dict())
			for peer_id in _coop_fighters:
				var gast_xp := int(xp_je_held.get(_gast_held(peer_id), 0))
				Net.award_guest(peer_id, {"xp": gast_xp, "gold": loot["gold"],
					"materials": mats_out, "items": items_out})

	# Level-Up? Statuspunkte DIREKT hier verteilen — draußen könnte schon
	# der nächste Gegner warten (Gast-Helden verteilt der Gast bei sich).
	if victory:
		for member in _fighting_party:
			if member.has_meta(&"guest_peer") or member.stat_points <= 0:
				continue
			level_box.add_child(_make_alloc_button(panel, level_box, member))

	if Net.role == Net.Role.HOST and not _dungeon_context.is_empty():
		_broadcast_state()  # Endstand (HP/Status) noch an die Mitkämpfer
		Net.broadcast("battle_ended", {"victory": victory})

	var back := Button.new()
	if _dungeon_context.is_empty():
		back.text = Loc.pick("Zurück zum Menü", "Back to menu")
		back.pressed.connect(func() -> void:
			get_tree().change_scene_to_file(MAIN_SCENE))
	elif victory:
		# Gegner im Run als besiegt markieren, dann zurück in den Dungeon.
		if _dungeon_context["is_boss"]:
			GameState.current_run["boss_defeated"] = true
			var run_card: DungeonCard = GameState.current_run["card"]
			run_card.times_completed += 1
			GameState.note_card_cleared(run_card)
			_offer_reward_choice(reward_box)
		else:
			GameState.current_run["defeated"].append(_dungeon_context["enemy_id"])
		back.text = Loc.pick("Weiter", "Continue")
		back.pressed.connect(func() -> void:
			_finalize_reward()
			get_tree().change_scene_to_file(DUNGEON_SCENE))
	else:
		# Wipe: zurück zum Hub, die Karte bleibt erhalten (siehe Design) —
		# nur der laufende Besuch (besiegte Gegner etc.) geht verloren.
		back.text = Loc.pick("Zurück zum Hub", "Back to hub")
		back.pressed.connect(func() -> void:
			GameState.clear_run()
			get_tree().change_scene_to_file(MAIN_SCENE))

	# Seiten zusammensetzen: nur gefüllte kommen in die Reihenfolge;
	# „Weiter »“ blättert, der Abschluss-Knopf sitzt auf der letzten Seite.
	if level_box.get_child_count() > 0:
		var level_head := Label.new()
		level_head.text = Loc.pick("Level-Aufstiege!", "Level-ups!")
		level_head.add_theme_font_size_override("font_size", 24)
		level_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_box.add_child(level_head)
		level_box.move_child(level_head, 0)
	var pages: Array[VBoxContainer] = [box]
	if level_box.get_child_count() > 0:
		pages.append(level_box)
	if reward_box.get_child_count() > 0:
		pages.append(reward_box)
	for i in pages.size():
		pages[i].visible = i == 0
	for i in pages.size() - 1:
		var current: VBoxContainer = pages[i]
		var next_page: VBoxContainer = pages[i + 1]
		var next_button := Button.new()
		next_button.text = Loc.pick("Weiter »", "Next »")
		next_button.pressed.connect(func() -> void:
			current.visible = false
			next_page.visible = true
			UiTheme.focus_first_button(next_page))
		current.add_child(next_button)
	pages[pages.size() - 1].add_child(back)
	# Tastatur: Das Ergebnis-Panel ist ab der ersten Seite bedienbar.
	UiTheme.focus_first_button(pages[0])


## Boss besiegt: ZWEI Belohnungskarten zur Wahl — die Stufe rollt gewichtet
## −2..+5 um die abgeschlossene Karte, im Schnitt geht es also bergauf.
## „Weiter“ ohne Wahl nimmt automatisch die höhere Stufe.
var _reward_choices: Array[DungeonCard] = []


func _offer_reward_choice(box: VBoxContainer) -> void:
	var run_card: DungeonCard = GameState.current_run["card"]
	_reward_choices = [CardFactory.make_reward(run_card),
		CardFactory.make_reward(run_card)]
	var head := Label.new()
	head.text = Loc.pick("Belohnungskarte wählen:", "Choose a reward map:")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for card in _reward_choices:
		var button := Button.new()
		button.text = "%s\nStufe %d · %d Ebenen" \
			% [card.display_name, card.tier, card.floor_count]
		var affix_parts: Array[String] = []
		for id in card.card_affix_ids:
			affix_parts.append(CardFactory.card_affix_name(id))
		if not affix_parts.is_empty():
			button.tooltip_text = ", ".join(affix_parts)
		button.pressed.connect(func() -> void:
			_pick_reward(card)
			for child in row.get_children():
				child.disabled = true
			button.text = "[OK] " + button.text)
		row.add_child(button)


func _pick_reward(card: DungeonCard) -> void:
	GameState.current_run["reward"] = card
	GameState.current_run["reward_added"] = GameState.add_card(card)
	_reward_choices.clear()
	Sfx.play(&"bestaetigen")


## „Weiter“ ohne Wahl: automatisch die Karte mit der höheren Stufe nehmen.
func _finalize_reward() -> void:
	if _reward_choices.is_empty():
		return
	var best: DungeonCard = _reward_choices[0]
	for card in _reward_choices:
		if card.tier > best.tier:
			best = card
	_pick_reward(best)


## Knopf im Sieg-Panel: klappt die Punkteverteilung für diesen Helden auf —
## die Übersicht weicht solange, „Fertig“ führt zurück.
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


# --- UI-Aufbau --------------------------------------------------------------

func _build_layout() -> void:
	var biome := Enums.Biome.FOREST
	if GameState.current_run.has("card"):
		biome = GameState.current_run["card"].biome
	var stil := DungeonWelt3D.biom_stil(biome)
	_buehne = KampfBuehne3D.new()
	add_child(_buehne)
	_buehne.aufbauen(stil["floor_tint"], stil["wall_tint"], stil["deco"])
	_buehne.effekte.ui = self
	_studio = PortraitStudio.new()
	add_child(_studio)

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

	# Zugreihenfolge-Leiste: wer ist jetzt und als Nächstes dran.
	var turn_center := CenterContainer.new()
	main.add_child(turn_center)
	_turn_bar = HBoxContainer.new()
	_turn_bar.add_theme_constant_override("separation", 6)
	turn_center.add_child(_turn_bar)

	var enemy_center := CenterContainer.new()
	enemy_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(enemy_center)
	_enemy_row = HBoxContainer.new()
	_enemy_row.add_theme_constant_override("separation", 32)
	enemy_center.add_child(_enemy_row)

	var unten := KampfUi.unterer_bereich(main)
	_log_label = unten["log"]
	_party_row = unten["party"]
	_action_box = unten["aktionen"]


func _make_enemy_panel(enemy: Combatant) -> Control:
	var button := Button.new()
	button.flat = true
	button.disabled = true
	button.custom_minimum_size = Vector2(132, 185)
	button.pressed.connect(_on_enemy_clicked.bind(enemy))
	_enemy_buttons[enemy] = button

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	_ignore_mouse_recursive(box)
	button.add_child(box)

	var sprite_center := CenterContainer.new()
	box.add_child(sprite_center)
	var groesse := roundi(128 * enemy.sprite_scale * (1.2 if enemy.is_boss else 1.0))
	button.custom_minimum_size = Vector2(maxf(132, groesse + 16), 185 + maxf(0, groesse - 64))
	# Unsichtbarer Platzhalter: hier steht die 3D-Figur der Arena. Puls- und
	# Wackel-Tweens laufen weiter auf ihm, die Figur übernimmt sie.
	var sprite := Control.new()
	sprite.custom_minimum_size = Vector2(groesse, groesse)
	sprite.pivot_offset = Vector2(groesse, groesse) * 0.5
	sprite_center.add_child(sprite)
	_buehne.anmelden(enemy, sprite, FigurenBau.fuer_kaempfer(enemy), enemy.is_alive)

	var name_label := Label.new()
	name_label.text = enemy.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 13)
	box.add_child(name_label)

	# Typ-Chips (Pokémon-Stil): Angriffselemente + Untot auf einen Blick.
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 4)
	for element in _attack_elements(enemy):
		var element_block := BlockLibrary.element_block(element)
		if element_block != null:
			chips.add_child(_make_type_chip(element_block.display_name,
				ELEMENT_CHIP_COLORS.get(element, Color.WHITE)))
	if enemy.is_undead:
		chips.add_child(_make_type_chip("Untot", UNDEAD_CHIP_COLOR))
	if chips.get_child_count() > 0:
		box.add_child(chips)

	# Entdeckte Schwächen/Resistenzen (▲ schwach · ▼ resistent).
	var wissen := HBoxContainer.new()
	wissen.alignment = BoxContainer.ALIGNMENT_CENTER
	wissen.add_theme_constant_override("separation", 4)
	box.add_child(wissen)
	KampfUi.wissen_chips(wissen, KampfUi.element_wissen(enemy))

	var hp_bar := KampfUi.balken(10, KampfUi.HP_GUT, true, false)
	hp_bar.max_value = enemy.max_hp
	hp_bar.value = enemy.hp
	box.add_child(hp_bar)

	# Verteidigung auf einen Blick: physisch (Rüstung) vs. magisch (Resistenz).
	# Wird laufend aktualisiert (Haltungswechsel, Steinpanzer-Bruch!).
	var defense_label := Label.new()
	defense_label.text = abwehr_text(enemy)
	defense_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defense_label.add_theme_font_size_override("font_size", 10)
	defense_label.modulate = Color(1, 1, 1, 0.65)
	box.add_child(defense_label)

	var status_label := Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	box.add_child(status_label)

	# Schadensvorschau während der Zielwahl ("≈24 Schaden !").
	var preview_label := Label.new()
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.add_theme_font_size_override("font_size", 12)
	box.add_child(preview_label)

	# Ausführliche Infos beim Draufzeigen (auch bei gesperrtem Button sichtbar).
	button.tooltip_text = _enemy_tooltip(enemy)

	_ignore_mouse_recursive(box)
	_panels[enemy] = {"root": button, "hp": hp_bar, "status": status_label,
		"sprite": sprite, "preview": preview_label, "name": name_label,
		"defense": defense_label, "wissen": wissen}
	return button


## Alle Elemente, mit denen dieser Gegner angreift (aus seinem Skill-Pool).
func _attack_elements(combatant: Combatant) -> Array:
	var found: Array = []
	for skill in combatant.skills:
		var element_block := skill.get_element()
		if element_block != null and element_block.element not in found:
			found.append(element_block.element)
	return found


## Kleiner farbiger Typ-Chip (Pokémon-Stil) für die Gegner-Panels.
func _make_type_chip(text: String, color: Color) -> Control:
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.22)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color.lightened(0.35))
	chip.add_child(label)
	return chip


## Tooltip mit allem, was man über den Gegner wissen will: Typen, Verteidigung,
## Element-Auswirkungen und seine Angriffe.
func _enemy_tooltip(enemy: Combatant) -> String:
	var lines: Array[String] = [enemy.display_name]
	var elements := _attack_elements(enemy)
	var type_names: Array[String] = []
	for element in elements:
		var element_block := BlockLibrary.element_block(element)
		if element_block != null:
			type_names.append(element_block.display_name)
	if enemy.is_undead:
		type_names.append("Untot")
	if not type_names.is_empty():
		lines.append("Typen: " + ", ".join(type_names))
	lines.append(abwehr_text(enemy))
	for element in elements:
		if ELEMENT_HINTS.has(element):
			lines.append(ELEMENT_HINTS[element])
	if enemy.is_undead:
		lines.append("Untot: nimmt ×1,5 Schaden von Heilig.")
	if not enemy.skills.is_empty():
		var skill_names: Array[String] = []
		for skill in enemy.skills:
			skill_names.append(skill.display_name)
		lines.append("Angriffe: " + ", ".join(skill_names))
	if enemy.loot_mult > 1.0:
		lines.append("Beute ×%.1f" % enemy.loot_mult)
	var wissen := KampfUi.element_wissen(enemy)
	var offen := enemy.element_faktoren.size() - wissen.size()
	if not enemy.element_faktoren.is_empty():
		var teile: Array[String] = []
		for eintrag in wissen:
			teile.append(("schwach: " if eintrag[1] > 1.0 else "resistent: ") + BlockLibrary.element_block(eintrag[0]).display_name)
		if offen > 0:
			teile.append("%d unentdeckt" % offen)
		lines.append("Elemente — " + ", ".join(teile))
	return "\n".join(lines)


## Party-Karte (KampfUi): Porträt, HP/MP mit Zahlen, Status und geplante
## Aktion („» Angriff » Wolf“) — jeder sieht die Pläne der anderen.
func _make_party_panel(member: Combatant) -> Control:
	var sprite := _make_sprite(member, 44)
	var karte := KampfUi.party_karte(sprite, member.display_name)
	karte["hp"].max_value = member.max_hp
	karte["hp"].value = member.hp
	karte["mp"].max_value = member.max_mp
	karte["mp"].value = member.mp
	karte.erase("name")
	karte["sprite"] = sprite
	_panels[member] = karte
	return karte["root"]


func _refresh_all() -> void:
	if _resolving:
		_info_label.text = Loc.pick("Runde %d", "Round %d") % battle.round_number
	else:
		_info_label.text = Loc.pick("Befehle wählen — Runde %d",
			"Choose commands — round %d") % (battle.round_number + 1)
	_refresh_turn_bar()
	for combatant in _panels:
		var panel: Dictionary = _panels[combatant]
		panel["hp"].max_value = combatant.max_hp  # König-Schleim wächst!
		panel["hp"].value = combatant.hp
		if panel.has("mp"):
			panel["mp"].value = combatant.mp
		if panel.has("name"):
			panel["name"].text = combatant.display_name
		if panel.has("defense"):
			panel["defense"].text = abwehr_text(combatant)
		var names: Array[String] = []
		if combatant.charge_active:
			names.append("⚡ LÄDT AUF")
		for entry in combatant.statuses:
			names.append(Battle.status_label(entry))
		panel["status"].text = ", ".join(names)
		if panel.has("plan"):
			panel["plan"].text = _plan_text(combatant)
			KampfUi.aktiv_setzen(panel["root"], combatant == _active and not _resolving)
		if _buehne != null and _buehne.hat(combatant):
			var ids: Array = []
			for entry in combatant.statuses:
				ids.append(int(entry["status"]))
			_buehne.status_setzen(combatant, ids if combatant.is_alive() else [])
		panel["root"].modulate = Color(1, 1, 1) if combatant.is_alive() \
			else Color(1, 1, 1, 0.3)


## Zugreihenfolge-Leiste: aktueller Kämpfer (groß, gelber Rahmen) und die
## nächsten Züge als Mini-Porträts — grün umrandet = Party, rot = Gegner.
func _refresh_turn_bar() -> void:
	if _turn_bar == null:
		return
	for child in _turn_bar.get_children():
		child.queue_free()
	var order: Array[Combatant] = []
	if _active != null and _active.is_alive():
		order.append(_active)
	for combatant in battle.upcoming_turns(7):
		order.append(combatant)
	for i in order.size():
		var combatant := order[i]
		var is_current := i == 0 and combatant == _active
		var slot := PanelContainer.new()
		var style := StyleBoxFlat.new()
		var side_color := Color(0.45, 0.9, 0.5) if combatant.is_player \
			else Color(0.95, 0.4, 0.35)
		if is_current:
			side_color = Color(1.0, 0.85, 0.3)
		style.bg_color = Color(side_color.r, side_color.g, side_color.b, 0.13)
		style.border_color = side_color
		style.set_border_width_all(2 if is_current else 1)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(2)
		slot.add_theme_stylebox_override("panel", style)
		slot.tooltip_text = combatant.display_name \
			+ ("  (am Zug)" if is_current else "  (Tempo %d)" % combatant.effective_speed())
		slot.add_child(_make_sprite(combatant, 30 if is_current else 22))
		_turn_bar.add_child(slot)
		if i == 0 and order.size() > 1:
			var arrow := Label.new()
			arrow.text = "›"
			arrow.modulate = Color(1, 1, 1, 0.5)
			_turn_bar.add_child(arrow)


func _on_log(text: String) -> void:
	KampfUi.log_zeile(_log_label, text)
	# Co-op: Mitkämpfer lesen dasselbe Kampflog live mit.
	_send_fighters("blog", {"line": text})


## Kampf-Effekte einer Aktion abspielen (Projektile, Einschläge, Popups) —
## danach erst die Zahlen. Co-op-Mitkämpfer bekommen dieselben Ereignisse.
func _effekte_abspielen() -> void:
	if _fx_puffer.is_empty() or _buehne == null:
		return
	var ereignisse := _fx_puffer.duplicate()
	_fx_puffer.clear()
	var netz: Array = []
	for e: Dictionary in ereignisse:
		if e.get("art") == &"krit":
			_buehne.stoss()
		var kopie := e.duplicate()
		kopie["art"] = String(e.get("art", ""))
		kopie["von"] = int(_net_ids.get(e.get("von"), -1)) if e.get("von") != null else -1
		kopie["an"] = int(_net_ids.get(e.get("an"), -1)) if e.get("an") != null else -1
		netz.append(kopie)
	_send_fighters("fx", {"e": netz})
	await _buehne.effekte.abspielen(ereignisse, _ort_fuer)


## Wo steht ein Kämpfer? Gegner: 3D-Figur der Arena · Helden: Party-Karte.
func _ort_fuer(combatant: Variant) -> Variant:
	if combatant == null or not _panels.has(combatant):
		return null
	if _buehne.hat(combatant):
		var mitte: Variant = _buehne.figur_mitte(combatant)
		return {"welt": mitte, "schluessel": combatant} if mitte != null else null
	var karte: Control = _panels[combatant]["root"]
	return {"rect": karte.get_global_rect(), "karte": karte}


## Element traf Schwäche/Resistenz: Wissen merken, Chips + Tooltips aller
## Gegner desselben Typs aktualisieren (auch beim Co-op-Gast).
func _on_element_reaktion(target: Combatant, element: Enums.Element, _faktor: float) -> void:
	if target.is_player or not GameState.entdecke_element(target.wissens_schluessel(), element):
		return
	for combatant in _panels:
		if _panels[combatant].has("wissen") \
				and combatant.wissens_schluessel() == target.wissens_schluessel():
			KampfUi.wissen_chips(_panels[combatant]["wissen"], KampfUi.element_wissen(combatant))
			_panels[combatant]["root"].tooltip_text = _enemy_tooltip(combatant)
	_broadcast_state()


## Beschwörung erscheint mitten im Kampf » Panel dynamisch anlegen.
func _on_combatant_added(combatant: Combatant) -> void:
	_assign_net_id(combatant)
	if combatant.is_player:
		_party_row.add_child(_make_party_panel(combatant))
	else:
		_enemy_row.add_child(_make_enemy_panel(combatant))
	_refresh_all()
	_broadcast_state()


func _on_combatant_removed(combatant: Combatant) -> void:
	if _panels.has(combatant):
		_panels[combatant]["root"].queue_free()
		_panels.erase(combatant)
	_enemy_buttons.erase(combatant)


func _ignore_mouse_recursive(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_ignore_mouse_recursive(child)


## Kleines Bild des Kämpfers (Zugleiste, Party-Panel): aus der 3D-Figur
## gerendertes Porträt; Fallback: farbiges Rechteck.
static func _make_sprite(combatant: Combatant, size: int) -> Control:
	var node: Control
	var tex: Texture2D = combatant.sprite
	if _studio != null and is_instance_valid(_studio):
		tex = _studio.textur(FigurenBau.schluessel_fuer(combatant),
			func() -> Node3D: return FigurenBau.fuer_kaempfer(combatant))
	if tex != null:
		var rect := TextureRect.new()
		rect.texture = tex
		rect.custom_minimum_size = Vector2(size, size)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node = rect
	else:
		var fallback := ColorRect.new()
		fallback.custom_minimum_size = Vector2(size, size)
		fallback.color = _placeholder_color(combatant.display_name)
		node = fallback
	# Pivot mittig, damit Puls-/Wackel-Animationen nicht aus der Ecke wachsen.
	node.pivot_offset = Vector2(size, size) * 0.5
	return node


static func _placeholder_color(name: String) -> Color:
	return Color.from_hsv(float(absi(hash(name)) % 360) / 360.0, 0.55, 0.85)


# --- Kampf-Animationen -----------------------------------------------------------
# Rein visuell auf Basis eines HP-Vorher/Nachher-Vergleichs — Battle bleibt
# UI-frei. Tweens auf "scale"/"rotation" statt "position", weil Container
# (CenterContainer/HBoxContainer) die Position kontrollierter Kinder sonst
# beim nächsten Sortierdurchlauf zurücksetzen würden.

func _snapshot_hp() -> Dictionary:
	var snap := {}
	for combatant in _panels:
		snap[combatant] = combatant.hp
	return snap


func _animate_hp_changes(before: Dictionary) -> void:
	var any_damage := false
	var any_heal := false
	for combatant in _panels:
		if not before.has(combatant):
			continue
		var diff: int = combatant.hp - before[combatant]
		if diff == 0:
			continue
		any_damage = any_damage or diff < 0
		any_heal = any_heal or diff > 0
		_spawn_floating_number(combatant, diff)
		# Gefallen: Rauchwolke an der 3D-Figur.
		if combatant.hp <= 0 and before[combatant] > 0 and _buehne != null:
			var mitte: Variant = _buehne.figur_mitte(combatant)
			if mitte != null:
				_buehne.effekte.tod(mitte)
		_flash_sprite(combatant, diff > 0)
		if diff < 0:
			_shake_sprite(combatant)
	# Ein Klang pro Animations-Schub (nicht pro Ziel — Flächenskills!).
	if any_damage:
		Sfx.play(&"treffer")
	if any_heal:
		Sfx.play(&"heilung")


## Kurzer Skalierungs-Puls, wenn ein Kämpfer eine Aktion ausführt.
func _pulse_sprite(combatant: Combatant) -> void:
	if not _panels.has(combatant):
		return
	var sprite: Control = _panels[combatant]["sprite"]
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.08)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.14)


## Kurzes Wackeln (Rotation statt Position — containersicher) bei Treffern.
func _shake_sprite(combatant: Combatant) -> void:
	if not _panels.has(combatant):
		return
	var sprite: Control = _panels[combatant]["sprite"]
	var tween := create_tween()
	tween.tween_property(sprite, "rotation", deg_to_rad(10), 0.04)
	tween.tween_property(sprite, "rotation", deg_to_rad(-10), 0.05)
	tween.tween_property(sprite, "rotation", 0.0, 0.05)


## Rot-/Grünblitz als kurzlebiges Overlay über dem Sprite.
func _flash_sprite(combatant: Combatant, is_heal: bool) -> void:
	if not _panels.has(combatant):
		return
	if _buehne != null and _buehne.hat(combatant):
		_buehne.blitz(combatant, is_heal)  # 3D-Figur leuchtet statt Rechteck-Overlay
		return
	var sprite: Control = _panels[combatant]["sprite"]
	var overlay := ColorRect.new()
	overlay.color = Color(0.55, 1.0, 0.6, 0.55) if is_heal else Color(1.0, 0.3, 0.3, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite.add_child(overlay)
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.3)
	tween.tween_callback(overlay.queue_free)


## Aufsteigende Schadens-/Heilzahl über dem betroffenen Kämpfer.
func _spawn_floating_number(combatant: Combatant, diff: int) -> void:
	if not _panels.has(combatant):
		return
	var sprite: Control = _panels[combatant]["sprite"]
	var label := Label.new()
	label.text = ("+%d" % diff) if diff > 0 else str(-diff)
	label.add_theme_font_size_override("font_size", 28 if absi(diff) >= 100 else 24)
	label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if diff > 0 else Color(1.0, 0.92, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color",
		Color(0.05, 0.25, 0.1, 0.95) if diff > 0 else Color(0.45, 0.05, 0.08, 0.95))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 44
	add_child(label)
	label.reset_size()
	label.pivot_offset = label.size * 0.5
	var start := sprite.get_global_rect().position + Vector2(sprite.size.x * 0.5 - label.size.x * 0.5, -10)
	label.global_position = start
	label.scale = Vector2.ONE * 0.5
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE * 1.2, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.08)
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", start + Vector2(0, -40), 0.75)
	tween.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


## Gast-Held eines Co-op-Mitspielers im Kampf (für seinen XP-Anteil).
func _gast_held(peer_id: int) -> Combatant:
	for member in _fighting_party:
		if member.has_meta(&"guest_peer") and int(member.get_meta(&"guest_peer")) == peer_id:
			return member
	return null


## Verteidigung eines Gegners als Minderung gegen die eigene Party (Ø-Level):
## „Rüstung −17 % · Magie −6 %“ — Rüstungsriss, Durchschlag und Haltungs-
## wechsel sind so direkt ablesbar.
static func abwehr_text(gegner: Combatant) -> String:
	var level := maxi(1, roundi(GameState.average_party_level()))
	var magisch := Combatant.minderung(gegner.total_magic_resist(), level)
	# Je Schadensart (Hieb/Stich/Stumpf): Rüstungsklasse zeigt, was durchgeht.
	var werte := {}
	for art in [Enums.PhysicalSubtype.SLASH, Enums.PhysicalSubtype.PIERCE, Enums.PhysicalSubtype.BLUNT]:
		werte[art] = roundi(100.0 * Combatant.minderung(gegner.armor_against(art), level))
	var tiefst: int = werte.values().min()
	var hoechst: int = werte.values().max()
	var text := Loc.pick("Rüstung −%d %%", "Armor −%d%%") % werte[Enums.PhysicalSubtype.SLASH]
	if hoechst - tiefst >= 3:
		var gut: Array[String] = []
		for art in werte:
			if werte[art] == tiefst:
				gut.append(Enums.physical_subtype_name(art))
		text = Loc.pick("Rüstung −%d-%d %% (%s ▲)", "Armor −%d-%d%% (%s ▲)") % [tiefst, hoechst, "/".join(gut)]
	return text + Loc.pick("\nMagie −%d %%", "\nMagic −%d%%") % roundi(magisch * 100.0)


## Taktik-Hinweis zur Boss-Eigenheit (fürs Boss-Banner).
const BOSS_HINWEISE := {
	&"wut": ["Wut: je weniger HP, desto härter schlägt er zu", "Rage: the lower its HP, the harder it hits"],
	&"steinpanzer": ["Steinpanzer: der erste stumpfe Treffer sprengt ihn", "Stone armor: the first blunt hit shatters it"],
	&"regeneration": ["Regeneration: Brand oder Gift stoppen sie", "Regeneration: burn or poison stop it"],
	&"adds": ["Ruft Verstärkung — bei 66 % und 33 % HP", "Calls reinforcements — at 66% and 33% HP"],
	&"haltung": ["Haltungswechsel: mal physisch, mal magisch verwundbar", "Stance shift: vulnerable to physical, then magic"],
	&"verschlingen": ["Verschlingt Schleime und wächst daran", "Devours slimes and grows stronger"],
}


## Boss-Auftritt: Kamerafahrt vom Boss in die Übersicht + Banner mit Name
## und Eigenheit (Lutz: der Bosskampf soll sich wie der Höhepunkt anfühlen).
func _boss_auftritt() -> void:
	var boss: Combatant = null
	for foe in battle.enemies:
		if foe.is_boss:
			boss = foe
			break
	if boss == null:
		return
	var hinweise: Array[String] = []
	if BOSS_HINWEISE.has(boss.boss_signature):
		hinweise.append(Loc.pick(BOSS_HINWEISE[boss.boss_signature][0], BOSS_HINWEISE[boss.boss_signature][1]))
	if boss.level >= Battle.BANNWELLE_AB_STUFE:
		hinweise.append(Loc.pick("Bannwelle: hebt aufgebaute Stärkungen auf", "Disruptive wave: dispels built-up buffs"))
	for aura in boss.get_meta(&"auren", []):
		hinweise.append(Loc.pick("%s: stärkt seine Gruppe", "%s: empowers its group") % aura[2])
	# Name ohne Modifikator-Liste — die stehen als Hinweis darunter.
	var boss_name := boss.display_name.trim_prefix("Boss: ").get_slice(" [", 0)
	KampfUi.boss_banner(self, boss_name, "\n".join(hinweise))
	# Figuren-Positionen stehen erst nach dem ersten Layout fest.
	for i in 3:
		await get_tree().process_frame
	if is_inside_tree() and _buehne != null:
		_buehne.boss_intro(boss)
