class_name StatAllocator
extends VBoxContainer
## Wiederverwendbare Statuspunkte-Verteilung im Planen-»-Bestätigen-Stil —
## eingebettet im Sieg-Panel der Kampfszene, der Co-op-Kampfansicht und im
## Inventar. GEDRÜCKT HALTEN wiederholt den Klick immer schneller.
##
## Tastatur (DQ-Stil, Spieltest 2026-10-19): jede Attribut-Zeile ist ein
## fokussierbarer Eintrag — W/S wählt, A/D nimmt einen Punkt weg bzw. gibt
## einen dazu (Halten wiederholt). Die −/+-Knöpfe sind nur für die Maus.
##
## WICHTIG: Die Anzeige wird IN PLACE aktualisiert statt neu gebaut — die
## ±-Knöpfe feuern beim Runterdrücken, und wer den Knopf unter dem noch
## gedrückten Mauszeiger zerstört, hinterlässt Godots Maus-Fokus auf einem
## toten Control: ALLE weiteren Klicks der Szene werden verschluckt
## (Spieltest-Bug „kann nichts mehr drücken“).

## Nach BESTÄTIGEN gefeuert — umgebende Szenen frischen ihre Anzeigen auf.
signal changed

## Auto-Klick beim Halten: Anlaufzeit, dann pro Wiederholung schneller.
const HOLD_FIRST_DELAY := 0.4
const HOLD_MIN_WAIT := 0.03
const HOLD_ACCEL := 0.85

var hero: Combatant
## Geplante, noch nicht bestätigte Punkte: Stat-Name » Anzahl.
var _pending: Dictionary = {}

## Halten-Zustand: welches Attribut, welche Richtung.
var _hold_stat: StringName = &""
var _hold_delta := 0
var _hold_wait := HOLD_FIRST_DELAY
var _hold_cooldown := 0.0

## Einmal gebaute UI-Referenzen (werden nur noch aktualisiert).
var _points_label: Label
var _rows: Dictionary = {}  ## Stat » {"label", "minus", "plus"} (label = Zeilen-Knopf)
var _confirm: Button
var _reset: Button


static func create(p_hero: Combatant) -> StatAllocator:
	var alloc := StatAllocator.new()
	alloc.hero = p_hero
	alloc.add_theme_constant_override("separation", 6)
	alloc._build()
	return alloc


## Auto-Klick: solange Maustaste/Bestätigen gehalten wird, immer schneller
## weiterzählen.
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


## Einen Punkt planen/zurücknehmen (mit Grenzen), dann Anzeige aktualisieren.
func _nudge(stat: StringName, delta_points: int) -> void:
	var pending := int(_pending.get(stat, 0))
	if delta_points > 0 and _pending_total() >= hero.stat_points:
		return
	if delta_points < 0 and pending <= 0:
		return
	_pending[stat] = pending + delta_points
	_refresh()


func _pending_total() -> int:
	var total := 0
	for stat in _pending:
		total += int(_pending[stat])
	return total


## Einmaliger UI-Aufbau; alle späteren Änderungen laufen über _refresh().
func _build() -> void:
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 13)
	add_child(_points_label)
	if hero.stat_points <= 0:
		_refresh()
		return

	var hint := Label.new()
	hint.text = Loc.pick("W/S: Attribut  ·  A/D: Punkt − / +  ·  Halten wiederholt",
		"W/S: attribute  ·  A/D: point − / +  ·  holding repeats")
	hint.add_theme_font_size_override("font_size", 10)
	hint.modulate = Color(1, 1, 1, 0.45)
	add_child(hint)

	for stat in StatBlock.STAT_NAMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		add_child(row)
		var stat_label := Button.new()
		stat_label.flat = true
		stat_label.alignment = HORIZONTAL_ALIGNMENT_LEFT
		stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_label.add_theme_font_size_override("font_size", 12)
		stat_label.gui_input.connect(_zeilen_taste.bind(stat))
		stat_label.focus_entered.connect(func() -> void: stat_label.flat = false)
		stat_label.focus_exited.connect(func() -> void: stat_label.flat = true)
		row.add_child(stat_label)
		var minus := _nudge_button(stat, -1)
		row.add_child(minus)
		var plus := _nudge_button(stat, 1)
		row.add_child(plus)
		_rows[stat] = {"label": stat_label, "minus": minus, "plus": plus}

	# Erst BESTÄTIGEN macht die Verteilung fest — bis dahin frei korrigierbar.
	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 8)
	add_child(confirm_row)
	_confirm = Button.new()
	_confirm.text = Loc.pick("Verteilung bestätigen", "Confirm allocation")
	_confirm.pressed.connect(func() -> void:
		for stat in _pending:
			for i in int(_pending[stat]):
				hero.spend_stat_point(stat)
		_pending.clear()
		_hold_stat = &""
		GameState.save_game()
		Sfx.play(&"bestaetigen")
		_refresh()
		changed.emit())
	confirm_row.add_child(_confirm)
	_reset = Button.new()
	_reset.text = Loc.pick("Zurücksetzen", "Reset")
	_reset.pressed.connect(func() -> void:
		_pending.clear()
		_hold_stat = &""
		_refresh())
	confirm_row.add_child(_reset)

	_refresh()


## −/+-Knopf mit Halten-Wiederholung. Feuert beim RUNTERDRÜCKEN und geht
## nahtlos in die Wiederholung über — der Knopf selbst überlebt jede
## Aktualisierung (kein Neubau!), Fokus und Maus-Fokus bleiben intakt.
func _nudge_button(stat: StringName, delta_points: int) -> Button:
	var button := Button.new()
	button.text = "−" if delta_points < 0 else "+"
	button.custom_minimum_size = Vector2(32, 0)
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.focus_mode = Control.FOCUS_NONE  # Tastatur: A/D auf der Zeile
	button.pressed.connect(func() -> void:
		_nudge(stat, delta_points)
		_begin_hold(stat, delta_points))
	return button


## Texte und Sperr-Zustände nachziehen — ohne einen Knoten zu zerstören.
func _refresh() -> void:
	var planned := _pending_total()
	_points_label.text = Loc.pick("Freie Statuspunkte: %d", "Free stat points: %d") \
		% (hero.stat_points - planned)
	if planned > 0:
		_points_label.text += Loc.pick("   ·   %d verplant", "   ·   %d planned") % planned
	_points_label.modulate = Color(0.55, 1.0, 0.55) if hero.stat_points > 0 \
		else Color(1, 1, 1, 0.5)

	for stat in _rows:
		var pending := int(_pending.get(stat, 0))
		var row: Dictionary = _rows[stat]
		var text := "%s: %d (Basis %d)" % [_stat_short(stat),
			hero.stat(stat) + pending, hero.stats.get(stat) + pending]
		if pending > 0:
			text += "  [+%d]" % pending
		row["label"].text = text
		row["label"].modulate = Color(0.55, 1.0, 0.55) if pending > 0 else Color.WHITE
		row["minus"].disabled = pending <= 0
		row["plus"].disabled = planned >= hero.stat_points
	if _confirm != null:
		_confirm.disabled = planned <= 0
		_reset.disabled = planned <= 0


## A/D (ui_left/ui_right) auf einer Attribut-Zeile: Punkt weg/dazu —
## gehaltene Taste wiederholt über die Tasten-Wiederholung.
func _zeilen_taste(event: InputEvent, stat: StringName) -> void:
	if event.is_action_pressed(&"ui_right", true):
		_nudge(stat, 1)
		accept_event()
	elif event.is_action_pressed(&"ui_left", true):
		_nudge(stat, -1)
		accept_event()


## Tastatur-Fokus auf die erste Attribut-Zeile (bzw. Bestätigen).
func fokus_setzen() -> void:
	for stat in StatBlock.STAT_NAMES:
		if _rows.has(stat):
			(_rows[stat]["label"] as Button).grab_focus.call_deferred()
			return


static func _stat_short(stat: StringName) -> String:
	match stat:
		&"strength": return "STR"
		&"intelligence": return "INT"
		&"vitality": return "VIT"
		&"spirit": return "SPI"
		&"agility": return "AGI"
		&"luck": return "LCK"
	return str(stat)
