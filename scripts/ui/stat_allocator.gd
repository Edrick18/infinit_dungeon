class_name StatAllocator
extends VBoxContainer
## Wiederverwendbare Statuspunkte-Verteilung im Planen-»-Bestätigen-Stil
## (wie im Inventar) — einbettbar, wo ein Level-Up passiert: Sieg-Panel
## der Kampfszene und Co-op-Kampfansicht, damit man die Punkte verteilt,
## BEVOR draußen der nächste Gegner zuschnappt.

var hero: Combatant
## Geplante, noch nicht bestätigte Punkte: Stat-Name » Anzahl.
var _pending: Dictionary = {}


static func create(p_hero: Combatant) -> StatAllocator:
	var alloc := StatAllocator.new()
	alloc.hero = p_hero
	alloc.add_theme_constant_override("separation", 6)
	alloc._rebuild()
	return alloc


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
		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(32, 0)
		minus.disabled = pending <= 0
		minus.pressed.connect(func() -> void:
			_pending[stat] = pending - 1
			_rebuild())
		row.add_child(minus)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(32, 0)
		plus.disabled = planned >= hero.stat_points
		plus.pressed.connect(func() -> void:
			_pending[stat] = pending + 1
			_rebuild())
		row.add_child(plus)

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
		GameState.save_game()
		Sfx.play(&"bestaetigen")
		_rebuild())
	confirm_row.add_child(confirm)
	var reset := Button.new()
	reset.text = Loc.pick("Zurücksetzen", "Reset")
	reset.disabled = planned <= 0
	reset.pressed.connect(func() -> void:
		_pending.clear()
		_rebuild())
	confirm_row.add_child(reset)


static func _stat_short(stat: StringName) -> String:
	match stat:
		&"strength": return "STR"
		&"intelligence": return "INT"
		&"vitality": return "VIT"
		&"spirit": return "SPI"
		&"agility": return "AGI"
		&"luck": return "LCK"
	return str(stat)
