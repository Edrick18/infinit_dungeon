extends Control
## Waffen-Training (DQ9-Stil): Skillpunkte (+3 pro Level-Up) pro Held in
## Waffengattungen investieren — Schwellen schalten Technik-Bausteine für
## die Skill-Werkstatt frei. Investieren ist unumkehrbar (wie in DQ9).

const WORKSHOP_SCENE := "res://scenes/workshop/skill_workshop.tscn"

const TREES: Array[StringName] = [&"schwert", &"dolch", &"axt", &"stumpf",
	&"bogen", &"armbrust", &"offensivstab", &"heiligstab", &"schild"]

var _selected: Combatant = null
var _char_bar: HBoxContainer
var _points_label: Label
var _tree_list: VBoxContainer
var _studio: PortraitStudio  ## rendert die Klotz-Icons der Bäume
const WERKSTATT := preload("res://scripts/ui/skill_workshop.gd")
var _confirm_rebirth := false
## Geplante (noch NICHT bestätigte) Trainings-Punkte: Gattung » Punkte.
var _pending: Dictionary = {}
## Erst der zweite Klick verwirft verplante, nicht bestätigte Punkte.
var _verwerfen_warnung := ""


func _ready() -> void:
	theme = UiTheme.get_theme()
	Music.play(&"menu")
	_selected = GameState.party[0] if not GameState.party.is_empty() else null
	_build_layout()
	_refresh()
	UiTheme.focus_first_button(self)


func _build_layout() -> void:
	var b := Bildschirm.bauen(self, Loc.pick("Waffen-Training", "Weapon training"), &"lager",
		func() -> void:
			if _verwerfen_ok("zurueck"):
				get_tree().change_scene_to_file(WORKSHOP_SCENE), Loc.pick("Werkstatt", "Workshop"))
	_studio = PortraitStudio.new()
	add_child(_studio)
	_points_label = b.info("")
	b.setze_untertitel(Loc.pick("Jeder Level-Up gibt %d Skillpunkte (Level 50 und 100 einen mehr) — genug für zwei volle Bäume bis Level 100. Investieren ist unumkehrbar. Ein Baum auf 100 schaltet seine MEISTERSCHAFT frei: eine Rolle für den Meisterschafts-Slot, die mit jeder Waffe wirkt.",
		"Every level-up grants %d skill points (one extra at levels 50 and 100) — enough for two full trees by level 100. Investing is permanent. A tree at 100 unlocks its MASTERY: a role for the mastery slot that works with any weapon.") \
		% Combatant.SKILL_POINTS_PER_LEVEL)
	var root := b.inhalt

	_char_bar = HBoxContainer.new()
	_char_bar.add_theme_constant_override("separation", 8)
	root.add_child(_char_bar)

	var teile := Bildschirm.scroll_liste(6)
	root.add_child(teile[0])
	_tree_list = teile[1]


func _refresh() -> void:
	for child in _char_bar.get_children():
		child.queue_free()
	for member in GameState.party:
		if member.has_meta(&"guest_peer"):
			continue  # Gast-Helden trainiert ihr Besitzer selbst
		var button := Button.new()
		button.text = "%s (Lv %d, %d P.)" % [member.display_name, member.level,
			member.skill_points]
		UiTheme.als_aktiv(button, member == _selected)
		button.pressed.connect(func() -> void:
			if _selected != member and not _verwerfen_ok("held:" + member.display_name):
				return
			_selected = member
			_confirm_rebirth = false
			_pending.clear()
			_refresh())
		_char_bar.add_child(button)

	for child in _tree_list.get_children():
		child.queue_free()
	if _selected == null:
		return
	var planned := _pending_total()
	_points_label.text = Loc.pick("Freie Punkte: %d", "Free points: %d") \
		% (_selected.skill_points - planned)
	if planned > 0:
		_points_label.text += Loc.pick("   ·   %d verplant", "   ·   %d planned") % planned
	if not _verwerfen_warnung.is_empty():
		_points_label.text += Loc.pick("   ·   Nicht bestätigte Punkte gehen verloren — noch einmal klicken zum Verwerfen",
			"   ·   Unconfirmed points are lost — click again to discard")
	if _selected.rebirths > 0:
		_points_label.text += Loc.pick("   ·   Wiedergeburt ×%d", "   ·   rebirth ×%d") \
			% _selected.rebirths

	# Wiedergeburt (ab Level 100): Level/Stats auf Anfang, Training bleibt —
	# so farmt man über mehrere Leben die Bäume bis 100 voll.
	if planned > 0:
		_tree_list.add_child(_confirm_row())
	_tree_list.add_child(_meisterschafts_zeile())
	if _selected.can_rebirth():
		_tree_list.add_child(_rebirth_row())
	# Geführte Waffen zuerst — das sind die Bäume, die gerade zählen.
	var reihenfolge: Array[StringName] = []
	for family in TREES:
		if _selected.wields_family(family):
			reihenfolge.append(family)
	for family in TREES:
		if not _selected.wields_family(family):
			reihenfolge.append(family)
	for family in reihenfolge:
		_tree_list.add_child(_tree_row(family))


## Meisterschafts-Slot: freigeschaltete Rollen wählen (oder keine); gesperrte
## zeigen, was ab 100 Punkten wartet.
func _meisterschafts_zeile() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var tafel := Bildschirm.tafel(box)
	var kopf := HBoxContainer.new()
	kopf.add_theme_constant_override("separation", 10)
	box.add_child(kopf)
	var titel := Bildschirm.ueberschrift(Loc.pick("Meisterschafts-Slot", "Mastery slot"))
	kopf.add_child(titel)
	var aktiv := Label.new()
	if _selected.meisterschaft != &"" and _selected.meister(_selected.meisterschaft):
		aktiv.text = "%s — %s" % [Combatant.meisterschaft_name(_selected.meisterschaft),
			Combatant.meisterschaft_text(_selected.meisterschaft)]
		aktiv.add_theme_color_override("font_color", UiTheme.GOLD)
	else:
		aktiv.text = Loc.pick("leer — ein Baum auf 100 Punkten schaltet seine Rolle frei", "empty — a tree at 100 points unlocks its role")
		aktiv.modulate = Color(1, 1, 1, 0.55)
	aktiv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aktiv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(aktiv)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	box.add_child(flow)
	for family in Combatant.MEISTERSCHAFTEN:
		var frei := _selected.invested(family) >= 100
		var knopf := Button.new()
		knopf.text = "%s%s" % ["" if frei else "✕ ", Combatant.meisterschaft_name(family)]
		knopf.tooltip_text = "%s (%s)\n%s" % [Combatant.meisterschaft_name(family),
			BlockLibrary.family_label(family), Combatant.meisterschaft_text(family)] \
			+ ("" if frei else Loc.pick("\nGesperrt: %s auf 100 Punkte bringen (jetzt %d).",
				"\nLocked: bring %s to 100 points (now %d).") % [BlockLibrary.family_label(family), _selected.invested(family)])
		knopf.disabled = not frei
		if frei:
			UiTheme.als_aktiv(knopf, _selected.meisterschaft == family)
			var f: StringName = family
			knopf.pressed.connect(func() -> void:
				_selected.meisterschaft = f
				GameState.save_game()
				Sfx.play(&"bestaetigen")
				_refresh())
		flow.add_child(knopf)
	if _selected.meisterschaft != &"":
		var leeren := Button.new()
		leeren.text = Loc.pick("Slot leeren", "Clear slot")
		leeren.pressed.connect(func() -> void:
			_selected.meisterschaft = &""
			GameState.save_game()
			_refresh())
		flow.add_child(leeren)
	return tafel


## Ohne verplante Punkte sofort frei; sonst erst beim zweiten Klick auf dasselbe Ziel.
func _verwerfen_ok(schluessel: String) -> bool:
	if _pending_total() == 0 or _verwerfen_warnung == schluessel:
		_verwerfen_warnung = ""
		return true
	_verwerfen_warnung = schluessel
	_refresh()
	return false


func _pending_total() -> int:
	var total := 0
	for family in _pending:
		total += int(_pending[family])
	return total


## Erst BESTÄTIGEN investiert wirklich (und ist dann unumkehrbar wie DQ9) —
## bis dahin lässt sich die Planung frei korrigieren.
func _confirm_row() -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var info := Label.new()
	info.text = Loc.pick("%d Punkte verplant — erst Bestätigen macht sie fest.",
		"%d points planned — only confirming locks them in.") % _pending_total()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.modulate = Color(0.55, 1.0, 0.55)
	row.add_child(info)
	var confirm := Button.new()
	confirm.text = Loc.pick("Bestätigen", "Confirm")
	confirm.pressed.connect(func() -> void:
		for family in _pending:
			if int(_pending[family]) > 0:
				_selected.invest_point(family, int(_pending[family]))
		_pending.clear()
		GameState.save_game()
		Sfx.play(&"bestaetigen")
		_refresh())
	row.add_child(confirm)
	var reset := Button.new()
	reset.text = Loc.pick("Zurücksetzen", "Reset")
	reset.pressed.connect(func() -> void:
		_pending.clear()
		_refresh())
	row.add_child(reset)
	return panel


func _rebirth_row() -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var info := Label.new()
	info.text = Loc.pick("%s hat Level %d erreicht. Wiedergeburt: zurück auf Level 1 — Waffen-Training, Meisterschaft, freie Skillpunkte, Skills, freigeschaltete Klötze und Ausrüstung bleiben. +10 %% auf alle Werte je Wiedergeburt (danach: +%d %%).",
		"%s reached level %d. Rebirth: back to level 1 — weapon training, mastery, free skill points, skills, unlocked blocks and equipment remain. +10%% to all stats per rebirth (afterwards: +%d%%).") \
		% [_selected.display_name, _selected.level, roundi(Combatant.WIEDERGEBURT_BONUS * 100 * (_selected.rebirths + 1))]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.modulate = Color(1.0, 0.85, 0.4)
	row.add_child(info)
	var button := Button.new()
	button.text = Loc.pick("Wirklich wiedergeboren werden?", "Really be reborn?") \
		if _confirm_rebirth else Loc.pick("Wiedergeburt", "Rebirth")
	button.pressed.connect(func() -> void:
		if not _confirm_rebirth:
			_confirm_rebirth = true
			_refresh()
			return
		_confirm_rebirth = false
		if _selected.rebirth():
			GameState.save_game()
			Sfx.play(&"level_up")
		_refresh())
	row.add_child(button)
	return panel


func _tree_row(family: StringName) -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var name_label := Label.new()
	var invested := _selected.invested(family)
	name_label.text = "%s — %d" % [BlockLibrary.family_label(family), invested]
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _selected.wields_family(family):
		name_label.text += Loc.pick("   (geführt)", "   (wielded)")
		name_label.modulate = Color(0.7, 1.0, 0.75)
	name_label.tooltip_text = Loc.pick("Eigenheit (immer aktiv beim Führen): %s",
		"Trait (always active while wielded): %s") % Combatant.trait_label(family)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(name_label)
	var pending := int(_pending.get(family, 0))
	if pending > 0:
		name_label.text += "  [+%d geplant]" % pending if Loc.language == "de" \
			else "  [+%d planned]" % pending
		name_label.modulate = Color(0.55, 1.0, 0.55)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(36, 0)
	minus.disabled = pending <= 0
	minus.pressed.connect(func() -> void:
		_pending[family] = pending - 1
		_refresh())
	head.add_child(minus)
	var invest := Button.new()
	invest.text = "+1"
	invest.disabled = _pending_total() >= _selected.skill_points
	invest.pressed.connect(func() -> void:
		_pending[family] = pending + 1
		_refresh())
	head.add_child(invest)
	var invest_five := Button.new()
	invest_five.text = "+5"
	invest_five.disabled = _pending_total() + 5 > _selected.skill_points
	invest_five.pressed.connect(func() -> void:
		_pending[family] = pending + 5
		_refresh())
	head.add_child(invest_five)

	# Alle Schwellen des Baums (Techniken + Passiv-Boni), nach Punkten
	# sortiert — erreichte mit [OK], kommende als Ausblick.
	var preview := invested + int(_pending.get(family, 0))
	var entries: Array[Dictionary] = []
	for block in BlockLibrary.tree_blocks(family):
		entries.append({"points": block.tree_points, "label": block.display_name, "block": block,
			"reached": preview >= block.tree_points or block.id in GameState.researched})
	for passive in BlockLibrary.passives_for(family):
		entries.append({"points": int(passive["points"]),
			"label": BlockLibrary.passive_label(passive), "block": null,
			"reached": preview >= int(passive["points"])})
	# Bei 100 Punkten: die Meisterschafts-Rolle dieses Baums.
	entries.append({"points": 100, "block": null, "reached": preview >= 100,
		"label": "♛ " + Combatant.meisterschaft_name(family),
		"meister": Combatant.meisterschaft_text(family)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["points"]) < int(b["points"]))
	# Als Chips: erreicht = grün, das nächste Ziel = gold, der Rest gedämpft.
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	box.add_child(flow)
	var naechstes_gefunden := false
	for entry in entries:
		var stufe := &"erreicht" if entry["reached"] else &"gesperrt"
		if not entry["reached"] and not naechstes_gefunden:
			stufe = &"naechstes"
			naechstes_gefunden = true
		flow.add_child(_stufen_chip(entry, stufe))
	return panel


func _stufen_chip(entry: Dictionary, stufe: StringName) -> Control:
	var farbe: Color = {&"erreicht": Color(0.45, 1.0, 0.55), &"naechstes": UiTheme.GOLD,
		&"gesperrt": Color(0.6, 0.6, 0.75)}[stufe]
	var chip := PanelContainer.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(farbe.r, farbe.g, farbe.b, 0.16 if stufe != &"gesperrt" else 0.06)
	stil.border_color = Color(farbe.r, farbe.g, farbe.b, 0.8 if stufe != &"gesperrt" else 0.3)
	stil.set_border_width_all(1)
	stil.set_corner_radius_all(6)
	stil.content_margin_left = 6
	stil.content_margin_right = 8
	stil.content_margin_top = 2
	stil.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", stil)
	var zeile := HBoxContainer.new()
	zeile.add_theme_constant_override("separation", 4)
	zeile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(zeile)
	var punkte := Label.new()
	punkte.text = str(entry["points"])
	punkte.add_theme_font_size_override("font_size", 11)
	punkte.modulate = Color(1, 1, 1, 0.55)
	zeile.add_child(punkte)
	var block: SkillBlock = entry["block"]
	if block != null:
		var bild := TextureRect.new()
		bild.texture = KlotzIcons.textur(_studio, block)
		bild.custom_minimum_size = Vector2(22, 22)
		bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bild.modulate.a = 1.0 if stufe != &"gesperrt" else 0.5
		zeile.add_child(bild)
		chip.tooltip_text = block.display_name + "\n" + WERKSTATT._block_description(block)
	elif entry.has("meister"):
		chip.tooltip_text = Loc.pick("Meisterschafts-Rolle (für den Meisterschafts-Slot, wirkt mit jeder Waffe):\n%s",
			"Mastery role (for the mastery slot, works with any weapon):\n%s") % entry["meister"]
	else:
		chip.tooltip_text = Loc.pick("Passiv-Bonus, solange die Waffe geführt wird",
			"Passive bonus while the weapon is wielded")
	var titel := Label.new()
	titel.text = ("✔ " if stufe == &"erreicht" else "") + ("★ " if block != null and block.kern else "") + entry["label"]
	titel.add_theme_font_size_override("font_size", 12)
	titel.add_theme_color_override("font_color", farbe if stufe != &"gesperrt" else Color(0.8, 0.8, 0.9, 0.6))
	zeile.add_child(titel)
	return chip
