class_name StatAllocator
extends VBoxContainer
## Wiederverwendbare Statuspunkte-Verteilung im Planen-»-Bestätigen-Stil —
## eingebettet im Sieg-Panel der Kampfszene, der Co-op-Kampfansicht und im
## Inventar. GEDRÜCKT HALTEN wiederholt den Klick immer schneller (bei
## hunderten Punkten aus der Endgame-Punkte-Kurve klickt sich niemand wund).

## Nach BESTÄTIGEN gefeuert — umgebende Szenen frischen ihre Anzeigen auf.
signal changed

## Auto-Klick beim Halten: Anlaufzeit, dann pro Wiederholung schneller.
const HOLD_FIRST_DELAY := 0.4
const HOLD_MIN_WAIT := 0.03
const HOLD_ACCEL := 0.85

var hero: Combatant
## Geplante, noch nicht bestätigte Punkte: Stat-Name » Anzahl.
var _pending: Dictionary = {}

## Halten-Zustand: welches Attribut, welche Richtung — lebt auf DIESEM
## Container, weil _rebuild() die Buttons ersetzt (Frei-Klick-Falle).
var _hold_stat: StringName = &""
var _hold_delta := 0
var _hold_wait := HOLD_FIRST_DELAY
var _hold_cooldown := 0.0
## Zuletzt benutzter Knopf (Stat + Richtung) — bekommt nach dem Neubau
## den Fokus zurück (Tastatur-Nutzer!).
var _focus_stat: StringName = &""
var _focus_delta := 0


static func create(p_hero: Combatant) -> StatAllocator:
	var alloc := StatAllocator.new()
	alloc.hero = p_hero
	alloc.add_theme_constant_override("separation", 6)
	alloc._rebuild()
	return alloc


## Auto-Klick: solange Maustaste/Bestätigen gehalten wird, immer schneller
## weiterzählen — unabhängig davon, dass _rebuild() die Buttons ersetzt.
func _process(delta: float) -> void:
	if _hold_stat == &"":
		return
	if not (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			or Input.is_action_pressed("ui_accept")):
		_hold_stat = &""
		return
	_hold_cooldown -= delta
	if _hold_cooldown <= 0.0:
		_hold_wait = maxf(HOLD_MIN_WAIT, _hold_wait * HOLD_ACCEL)
		_hold_cooldown = _hold_wait
		_nudge(_hold_stat, _hold_delta)


func _begin_hold(stat: StringName, delta_points: int) -> void:
	_hold_stat = stat
	_hold_delta = delta_points
	_hold_wait = HOLD_FIRST_DELAY
	_hold_cooldown = HOLD_FIRST_DELAY


## Einen Punkt planen/zurücknehmen (mit Grenzen), dann Anzeige neu bauen.
func _nudge(stat: StringName, delta_points: int) -> void:
	var pending := int(_pending.get(stat, 0))
	if delta_points > 0 and _pending_total() >= hero.stat_points:
		return
	if delta_points < 0 and pending <= 0:
		return
	_pending[stat] = pending + delta_points
	_focus_stat = stat
	_focus_delta = delta_points
	_rebuild()


func _pending_total() -> int:
	var total := 0
	for stat in _pending:
		total += int(_pending[stat])
	return total


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	var planned := _pending_total()

	var points_label := Label.new()
	points_label.text = Loc.pick("Freie Statuspunkte: %d", "Free stat points: %d") \
		% (hero.stat_points - planned)
	if planned > 0:
		points_label.text += Loc.pick("   ·   %d verplant", "   ·   %d planned") % planned
	points_label.add_theme_font_size_override("font_size", 13)
	points_label.modulate = Color(0.55, 1.0, 0.55) if hero.stat_points > 0 \
		else Color(1, 1, 1, 0.5)
	add_child(points_label)
	if hero.stat_points <= 0:
		return

	var hint := Label.new()
	hint.text = Loc.pick("Tipp: Gedrückt halten zählt automatisch — immer schneller.",
		"Tip: hold the button to auto-count — faster and faster.")
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(1, 1, 1, 0.45)
	add_child(hint)

	for stat in StatBlock.STAT_NAMES:
		var pending := int(_pending.get(stat, 0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		var stat_label := Label.new()
		stat_label.text = "%s: %d (Basis %d)" % [_stat_short(stat),
			hero.stat(stat) + pending, hero.stats.get(stat) + pending]
		if pending > 0:
			stat_label.text += "  [+%d]" % pending
			stat_label.modulate = Color(0.55, 1.0, 0.55)
		stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_label.add_theme_font_size_override("font_size", 12)
		row.add_child(stat_label)
		row.add_child(_nudge_button(stat, -1, pending <= 0))
		row.add_child(_nudge_button(stat, 1, planned >= hero.stat_points))

	# Erst BESTÄTIGEN macht die Verteilung fest — bis dahin frei korrigierbar.
	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 8)
	add_child(confirm_row)
	var confirm := Button.new()
	confirm.text = Loc.pick("Verteilung bestätigen", "Confirm allocation")
	confirm.disabled = planned <= 0
	confirm.pressed.connect(func() -> void:
		for stat in _pending:
			for i in int(_pending[stat]):
				hero.spend_stat_point(stat)
		_pending.clear()
		_hold_stat = &""
		GameState.save_game()
		Sfx.play(&"bestaetigen")
		_rebuild()
		changed.emit())
	confirm_row.add_child(confirm)
	var reset := Button.new()
	reset.text = Loc.pick("Zurücksetzen", "Reset")
	reset.disabled = planned <= 0
	reset.pressed.connect(func() -> void:
		_pending.clear()
		_hold_stat = &""
		_rebuild())
	confirm_row.add_child(reset)


## −/+-Knopf mit Halten-Wiederholung; der zuletzt benutzte bekommt nach
## dem Neubau den Fokus zurück (Pfeile/Enter bleiben flüssig bedienbar).
func _nudge_button(stat: StringName, delta_points: int, locked: bool) -> Button:
	var button := Button.new()
	button.text = "−" if delta_points < 0 else "+"
	button.custom_minimum_size = Vector2(32, 0)
	button.disabled = locked
	# Schon beim RUNTERDRÜCKEN zählen (nicht erst beim Loslassen) — nahtlos
	# in die Halten-Wiederholung übergehend.
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.pressed.connect(func() -> void:
		_nudge(stat, delta_points)
		_begin_hold(stat, delta_points))
	if stat == _focus_stat and delta_points == _focus_delta and not locked:
		button.grab_focus.call_deferred()
	return button


static func _stat_short(stat: StringName) -> String:
	match stat:
		&"strength": return "STR"
		&"intelligence": return "INT"
		&"vitality": return "VIT"
		&"spirit": return "SPI"
		&"agility": return "AGI"
		&"luck": return "LCK"
	return str(stat)
