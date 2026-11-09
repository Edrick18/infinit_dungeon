extends Control
## Waffen-Training (DQ9-Stil): Skillpunkte (+3 pro Level-Up) pro Held in
## Waffengattungen investieren — Schwellen schalten Technik-Bausteine für
## die Skill-Werkstatt frei. Investieren ist unumkehrbar (wie in DQ9).
##
## Aufbau (UI-Pass 2026-11): Helden, darunter eine feste Aktionsleiste (freie
## und verplante Punkte, Bestätigen/Zurücksetzen — springt nicht mehr), dann
## die Liste: Meisterschafts-Slot (kompakt), geführte Waffen aufgeklappt,
## weitere Waffen eingeklappt. Jeder Baum zeigt einen Fortschrittsbalken mit
## seinen Schwellen und die nächste Stufe; die Stufen-Chips klappen auf.

const WORKSHOP_SCENE := "res://scenes/workshop/skill_workshop.tscn"

const TREES: Array[StringName] = [&"schwert", &"dolch", &"axt", &"stumpf",
	&"bogen", &"armbrust", &"offensivstab", &"heiligstab", &"schild"]
const BAUM_MAX := 100

var _selected: Combatant = null
var _char_bar: HBoxContainer
var _points_label: Label
var _bestaetigen: Button
var _zuruecksetzen: Button
var _tree_list: VBoxContainer
var _studio: PortraitStudio  ## rendert die Klotz-Icons der Bäume und die Helden-Bilder
const WERKSTATT := preload("res://scripts/ui/skill_workshop.gd")
var _confirm_rebirth := false
## Geplante (noch NICHT bestätigte) Trainings-Punkte: Gattung » Punkte.
var _pending: Dictionary = {}
## Erst der zweite Klick verwirft verplante, nicht bestätigte Punkte.
var _verwerfen_warnung := ""
## Aufgeklappte Bäume (Gattung » bool); ohne Eintrag: geführte offen, andere zu.
var _offen: Dictionary = {}


## Fortschrittsbalken eines Baums: investiert (grün), verplant (gold),
## Striche an jeder Schwelle (hell = erreicht).
class TrainingsBalken:
	extends Control

	var investiert := 0
	var geplant := 0
	var schwellen: Array[int] = []

	func _init() -> void:
		custom_minimum_size = Vector2(0, 12)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(UiTheme.KERBE, 0.9))
		var bis_investiert := w * clampf(float(investiert) / BAUM_MAX, 0.0, 1.0)
		draw_rect(Rect2(0, 0, bis_investiert, h), UiTheme.GUT)
		var bis_geplant := w * clampf(float(investiert + geplant) / BAUM_MAX, 0.0, 1.0)
		if bis_geplant > bis_investiert:
			draw_rect(Rect2(bis_investiert, 0, bis_geplant - bis_investiert, h), UiTheme.GOLD)
		for punkte in schwellen:
			var x := w * float(punkte) / BAUM_MAX
			var erreicht := punkte <= investiert + geplant
			draw_line(Vector2(x, 0), Vector2(x, h), Color(UiTheme.TEXT, 0.85 if erreicht else 0.4), 1.0)
		draw_rect(Rect2(0, 0, w, h), Color(UiTheme.GOLD, 0.45), false, 1.0)


func _ready() -> void:
	theme = UiTheme.get_theme()
	Music.play(&"menu")
	_selected = _erster_held()
	_build_layout()
	_refresh()
	UiTheme.focus_first_button(self)


func _erster_held() -> Combatant:
	for member in GameState.party:
		if not member.has_meta(&"guest_peer"):
			return member
	return null


func _build_layout() -> void:
	var b := Bildschirm.bauen(self, Loc.pick("Waffen-Training", "Weapon training"), &"lager",
		func() -> void:
			if _verwerfen_ok("zurueck"):
				get_tree().change_scene_to_file(WORKSHOP_SCENE), Loc.pick("Werkstatt", "Workshop"))
	_studio = PortraitStudio.new()
	add_child(_studio)
	b.setze_untertitel(Loc.pick("Jeder Level-Up gibt %d Skillpunkte (Level 50 und 100 einen mehr). Investieren ist unumkehrbar. Ein Baum auf 100 schaltet seine Meisterschaft frei: eine Rolle, die mit jeder Waffe wirkt.",
		"Every level-up grants %d skill points (one extra at levels 50 and 100). Investing is permanent. A tree at 100 unlocks its mastery: a role that works with any weapon.") \
		% Combatant.SKILL_POINTS_PER_LEVEL)
	var root := b.inhalt

	_char_bar = HBoxContainer.new()
	_char_bar.add_theme_constant_override("separation", 8)
	root.add_child(_char_bar)

	# Feste Aktionsleiste: Punkte und Bestätigen stehen immer an derselben Stelle.
	var leiste := HBoxContainer.new()
	leiste.add_theme_constant_override("separation", 10)
	root.add_child(Bildschirm.tafel(leiste))
	_points_label = Label.new()
	_points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Immer genau eine Zeile: die Leiste ändert nie ihre Höhe, die Liste darunter
	# verrutscht nicht (voller Text im Tooltip).
	_points_label.clip_text = true
	_points_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_points_label.mouse_filter = Control.MOUSE_FILTER_PASS
	leiste.add_child(_points_label)
	_bestaetigen = Button.new()
	_bestaetigen.custom_minimum_size = Vector2(150, 38)
	_bestaetigen.set_meta(&"fokus_id", "bestaetigen")
	_bestaetigen.pressed.connect(_bestaetigen_druecken)
	leiste.add_child(_bestaetigen)
	_zuruecksetzen = Button.new()
	_zuruecksetzen.text = Loc.pick("Zurücksetzen", "Reset")
	_zuruecksetzen.custom_minimum_size = Vector2(120, 38)
	_zuruecksetzen.set_meta(&"fokus_id", "zuruecksetzen")
	_zuruecksetzen.pressed.connect(func() -> void:
		_pending.clear()
		_refresh())
	leiste.add_child(_zuruecksetzen)

	var teile := Bildschirm.scroll_liste(8)
	root.add_child(teile[0])
	_tree_list = teile[1]


## Erst BESTÄTIGEN investiert wirklich (und ist dann unumkehrbar wie DQ9) —
## bis dahin lässt sich die Planung frei korrigieren.
func _bestaetigen_druecken() -> void:
	if _selected == null or _pending_total() == 0:
		return
	for family in _pending:
		if int(_pending[family]) > 0:
			_selected.invest_point(family, int(_pending[family]))
	_pending.clear()
	GameState.save_game()
	Sfx.play(&"bestaetigen")
	_refresh()


func _refresh() -> void:
	# Fokus merken: nach dem Neuaufbau landet er auf demselben Knopf (Tastatur).
	var fokus_id := ""
	var fokus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if fokus != null and fokus.has_meta(&"fokus_id"):
		fokus_id = String(fokus.get_meta(&"fokus_id"))

	# Alte Knöpfe sofort aus dem Baum: die Fokus-Suche findet nur die neuen.
	_leeren(_char_bar)
	for member in GameState.party:
		if member.has_meta(&"guest_peer"):
			continue  # Gast-Helden trainiert ihr Besitzer selbst
		var button := Button.new()
		button.text = Loc.pick("%s · Lv %d · %d P.", "%s · Lv %d · %d pts") % [member.display_name,
			member.level, member.skill_points]
		button.icon = _studio.textur(FigurenBau.schluessel_fuer(member),
			func() -> Node3D: return FigurenBau.held_aus(member))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 30)
		button.set_meta(&"fokus_id", "held:" + member.display_name)
		UiTheme.als_aktiv(button, member == _selected)
		button.pressed.connect(func() -> void:
			if _selected != member and not _verwerfen_ok("held:" + member.display_name):
				return
			_selected = member
			_confirm_rebirth = false
			_pending.clear()
			_refresh())
		_char_bar.add_child(button)

	_leeren(_tree_list)
	_aktionsleiste_aktualisieren()
	if _selected == null:
		return

	# Wiedergeburt (ab Level 100): Level/Stats auf Anfang, Training bleibt —
	# so farmt man über mehrere Leben die Bäume bis 100 voll.
	_tree_list.add_child(_meisterschafts_zeile())
	if _selected.can_rebirth():
		_tree_list.add_child(_rebirth_row())
	# Geführte Waffen zuerst (aufgeklappt) — das sind die Bäume, die gerade zählen.
	var gefuehrt: Array[StringName] = []
	var weitere: Array[StringName] = []
	for family in TREES:
		if _selected.wields_family(family):
			gefuehrt.append(family)
		else:
			weitere.append(family)
	if not gefuehrt.is_empty():
		_tree_list.add_child(Bildschirm.ueberschrift(Loc.pick("Geführte Waffen", "Wielded weapons")))
		for family in gefuehrt:
			_tree_list.add_child(_tree_row(family))
	_tree_list.add_child(Bildschirm.ueberschrift(Loc.pick("Weitere Waffen", "Other weapons")))
	for family in weitere:
		_tree_list.add_child(_tree_row(family))

	if not fokus_id.is_empty():
		_fokus_wiederherstellen.call_deferred(fokus_id)


static func _leeren(behaelter: Node) -> void:
	for child in behaelter.get_children():
		behaelter.remove_child(child)
		child.queue_free()


func _fokus_wiederherstellen(fokus_id: String) -> void:
	for knopf in find_children("*", "BaseButton", true, false):
		if knopf.is_queued_for_deletion() or not knopf.has_meta(&"fokus_id"):
			continue
		if String(knopf.get_meta(&"fokus_id")) == fokus_id and (knopf as Control).is_visible_in_tree():
			var ziel := knopf as BaseButton
			if ziel.disabled:
				break
			ziel.grab_focus()
			return
	# Knopf weg oder gesperrt (z. B. +5 ohne Punkte): Bestätigen, sonst der erste.
	if not _bestaetigen.disabled:
		_bestaetigen.grab_focus()
	else:
		UiTheme.focus_first_button(self)


func _aktionsleiste_aktualisieren() -> void:
	var planned := _pending_total()
	if planned == 0:
		_verwerfen_warnung = ""  # nichts mehr zu verwerfen (bestätigt oder zurückgesetzt)
	if _selected == null:
		_points_label.text = ""
		_bestaetigen.text = Loc.pick("Bestätigen", "Confirm")
		_bestaetigen.disabled = true
		_zuruecksetzen.disabled = true
		return
	var text := Loc.pick("Freie Punkte: %d", "Free points: %d") % (_selected.skill_points - planned)
	if planned > 0:
		text += Loc.pick("   ·   %d verplant — erst Bestätigen macht sie fest", "   ·   %d planned — only confirming locks them in") % planned
	if _selected.rebirths > 0:
		text += Loc.pick("   ·   Wiedergeburt ×%d", "   ·   rebirth ×%d") % _selected.rebirths
	if not _verwerfen_warnung.is_empty():
		# Ersetzt die Zeile (statt eine anzuhängen) — die Leiste bleibt gleich hoch.
		text = Loc.pick("%d verplante Punkte gehen verloren — noch einmal klicken zum Verwerfen.",
			"%d planned points will be lost — click again to discard.") % planned
	_points_label.text = text
	_points_label.tooltip_text = text
	_points_label.add_theme_color_override("font_color",
		UiTheme.ACHTUNG if not _verwerfen_warnung.is_empty() else (UiTheme.GUT if planned > 0 else UiTheme.TEXT))
	_bestaetigen.text = Loc.pick("Bestätigen (%d)", "Confirm (%d)") % planned if planned > 0 \
		else Loc.pick("Bestätigen", "Confirm")
	_bestaetigen.disabled = planned == 0
	_zuruecksetzen.disabled = planned == 0


## Meisterschafts-Slot: freigeschaltete Rollen wählen (oder keine). Solange
## keine frei ist, nur eine Zeile — die Rollen stehen am Ende jedes Baums.
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
		aktiv.modulate = UiTheme.BLASS
	aktiv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aktiv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(aktiv)
	var freie: Array[StringName] = []
	for family in Combatant.MEISTERSCHAFTEN:
		if _selected.invested(family) >= BAUM_MAX:
			freie.append(family)
	if freie.is_empty():
		return tafel
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	box.add_child(flow)
	for family in freie:
		var knopf := Button.new()
		knopf.text = Combatant.meisterschaft_name(family)
		knopf.tooltip_text = "%s (%s)\n%s" % [Combatant.meisterschaft_name(family),
			BlockLibrary.family_label(family), Combatant.meisterschaft_text(family)]
		knopf.set_meta(&"fokus_id", "meister:" + String(family))
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
		leeren.set_meta(&"fokus_id", "meister_leeren")
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


func _rebirth_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var panel := Bildschirm.tafel(row)
	var info := Label.new()
	info.text = Loc.pick("%s hat Level %d erreicht. Wiedergeburt: zurück auf Level 1 — Waffen-Training, Meisterschaft, freie Skillpunkte, Skills, freigeschaltete Klötze und Ausrüstung bleiben. +10 %% auf alle Werte je Wiedergeburt (danach: +%d %%).",
		"%s reached level %d. Rebirth: back to level 1 — weapon training, mastery, free skill points, skills, unlocked blocks and equipment remain. +10%% to all stats per rebirth (afterwards: +%d%%).") \
		% [_selected.display_name, _selected.level, roundi(Combatant.WIEDERGEBURT_BONUS * 100 * (_selected.rebirths + 1))]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.modulate = UiTheme.BELOHNUNG
	row.add_child(info)
	var button := Button.new()
	button.text = Loc.pick("Wirklich wiedergeboren werden?", "Really be reborn?") \
		if _confirm_rebirth else Loc.pick("Wiedergeburt", "Rebirth")
	button.set_meta(&"fokus_id", "wiedergeburt")
	button.pressed.connect(func() -> void:
		if not _confirm_rebirth:
			_confirm_rebirth = true
			_refresh()
			return
		_confirm_rebirth = false
		if _selected.rebirth():
			GameState.chronik_add("wiedergeburten")
			GameState.save_game()
			Sfx.play(&"level_up")
		_refresh())
	row.add_child(button)
	return panel


## Alle Schwellen eines Baums (Techniken, Passiv-Boni, Meisterschaft bei 100),
## nach Punkten sortiert; "reached" mit den verplanten Punkten.
func _stufen(family: StringName, preview: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for block in BlockLibrary.tree_blocks(family):
		entries.append({"points": block.tree_points, "label": block.display_name, "block": block,
			"reached": preview >= block.tree_points or block.id in GameState.researched})
	for passive in BlockLibrary.passives_for(family):
		entries.append({"points": int(passive["points"]),
			"label": BlockLibrary.passive_label(passive), "block": null,
			"reached": preview >= int(passive["points"])})
	entries.append({"points": BAUM_MAX, "block": null, "reached": preview >= BAUM_MAX,
		"label": "♛ " + Combatant.meisterschaft_name(family),
		"meister": Combatant.meisterschaft_text(family)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["points"]) < int(b["points"]))
	return entries


func baum_offen(family: StringName) -> bool:
	return bool(_offen.get(family, _selected != null and _selected.wields_family(family)))


func _tree_row(family: StringName) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var panel := PanelContainer.new()
	panel.add_child(box)
	var invested := _selected.invested(family)
	var pending := int(_pending.get(family, 0))
	var preview := invested + pending
	var entries := _stufen(family, preview)
	var offen := baum_offen(family)

	# Kopf: Auf-/Zuklappen, Name, Punkte, Knöpfe.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var klappe := Button.new()
	klappe.text = "▾" if offen else "▸"
	klappe.custom_minimum_size = Vector2(38, 34)
	klappe.add_theme_font_size_override("font_size", 20)
	klappe.tooltip_text = Loc.pick("Stufen ausblenden", "Hide tiers") if offen else Loc.pick("Stufen zeigen", "Show tiers")
	klappe.set_meta(&"fokus_id", "klappe:" + String(family))
	klappe.pressed.connect(func() -> void:
		_offen[family] = not offen
		_refresh())
	head.add_child(klappe)
	var name_label := Label.new()
	name_label.text = BlockLibrary.family_label(family)
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.tooltip_text = Loc.pick("Eigenheit (immer aktiv beim Führen): %s",
		"Trait (always active while wielded): %s") % Combatant.trait_label(family)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	if _selected.wields_family(family):
		name_label.modulate = UiTheme.GUT
	head.add_child(name_label)
	var punkte := Label.new()
	punkte.text = "%d / %d" % [invested, BAUM_MAX]
	if pending > 0:
		punkte.text += "  (+%d)" % pending
		punkte.add_theme_color_override("font_color", UiTheme.GOLD)
	else:
		punkte.modulate = UiTheme.BLASS
	punkte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(punkte)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(40, 0)
	minus.disabled = pending <= 0
	minus.set_meta(&"fokus_id", "minus:" + String(family))
	minus.pressed.connect(func() -> void:
		_pending[family] = pending - 1
		_refresh())
	head.add_child(minus)
	var frei := _selected.skill_points - _pending_total()
	var rest := BAUM_MAX - preview
	var invest := Button.new()
	invest.text = "+1"
	invest.custom_minimum_size = Vector2(48, 0)
	invest.disabled = frei < 1 or rest < 1
	invest.set_meta(&"fokus_id", "plus1:" + String(family))
	invest.pressed.connect(func() -> void:
		_pending[family] = pending + 1
		_refresh())
	head.add_child(invest)
	var invest_five := Button.new()
	invest_five.text = "+5"
	invest_five.custom_minimum_size = Vector2(48, 0)
	invest_five.disabled = frei < 5 or rest < 5
	invest_five.set_meta(&"fokus_id", "plus5:" + String(family))
	invest_five.pressed.connect(func() -> void:
		_pending[family] = pending + 5
		_refresh())
	head.add_child(invest_five)

	# Balken mit Schwellen-Strichen, daneben die nächste Stufe.
	var zeile := HBoxContainer.new()
	zeile.add_theme_constant_override("separation", 12)
	box.add_child(zeile)
	var balken := TrainingsBalken.new()
	balken.investiert = invested
	balken.geplant = pending
	for entry in entries:
		balken.schwellen.append(int(entry["points"]))
	zeile.add_child(balken)
	var naechstes := Label.new()
	naechstes.add_theme_font_size_override("font_size", 13)
	naechstes.custom_minimum_size = Vector2(360, 0)
	naechstes.clip_text = true
	naechstes.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var ziel: Dictionary = {}
	for entry in entries:
		if not entry["reached"]:
			ziel = entry
			break
	if ziel.is_empty():
		naechstes.text = Loc.pick("Alle Stufen erreicht", "All tiers reached")
		naechstes.add_theme_color_override("font_color", UiTheme.GUT)
	else:
		naechstes.text = Loc.pick("Nächste: %s bei %d (noch %d)", "Next: %s at %d (%d to go)") \
			% [ziel["label"], int(ziel["points"]), int(ziel["points"]) - preview]
		naechstes.add_theme_color_override("font_color", UiTheme.GOLD)
	naechstes.tooltip_text = naechstes.text
	naechstes.mouse_filter = Control.MOUSE_FILTER_PASS
	zeile.add_child(naechstes)

	# Alle Stufen als Chips (aufgeklappt): erreicht = grün, nächstes Ziel = gold.
	if offen:
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
	var farbe: Color = {&"erreicht": UiTheme.GUT, &"naechstes": UiTheme.GOLD,
		&"gesperrt": Stil3D.PAL["stein_hell"]}[stufe]
	var chip := PanelContainer.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(farbe, 0.16 if stufe != &"gesperrt" else 0.06)
	stil.border_color = Color(farbe, 0.8 if stufe != &"gesperrt" else 0.3)
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
	punkte.add_theme_font_size_override("font_size", 12)
	punkte.modulate = UiTheme.BLASS
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
	titel.add_theme_font_size_override("font_size", 13)
	titel.add_theme_color_override("font_color", farbe if stufe != &"gesperrt" else Color(Stil3D.PAL["stein_hell"], 0.75))
	zeile.add_child(titel)
	return chip
