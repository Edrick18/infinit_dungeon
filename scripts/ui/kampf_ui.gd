class_name KampfUi
extends RefCounted
## Gemeinsame Bausteine der Kampf-UI (Host + Co-op-Gast): unterer Bereich
## mit Log über den Party-Karten, Party-Karten mit Zahlen auf den Balken,
## HP-Farbe nach Füllstand, goldener Rahmen für den Helden am Zug.

const HP_GUT: Color = Stil3D.PAL["hp_gut"]
const HP_MITTEL: Color = Stil3D.PAL["gold"]
const HP_KRITISCH: Color = Stil3D.PAL["warnrot"]
const MP_FARBE: Color = Stil3D.PAL["mana"]
const LOG_HOEHE := 96


## Unterer Bereich: links Log (oben) + Party-Karten (unten), rechts die
## Befehle. Die Arena darüber bekommt so den ganzen freien Platz.
static func unterer_bereich(main: VBoxContainer) -> Dictionary:
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	main.add_child(bottom)
	var links := VBoxContainer.new()
	links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links.add_theme_constant_override("separation", 8)
	links.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_child(links)
	var log_label := RichTextLabel.new()
	log_label.custom_minimum_size = Vector2(0, LOG_HOEHE)
	log_label.scroll_following = true
	log_label.add_theme_stylebox_override("normal", UiTheme.glas_tafel())
	log_label.add_theme_font_size_override("normal_font_size", 13)
	log_label.modulate.a = 0.0  # erst sichtbar mit der ersten Zeile (log_zeile)
	links.add_child(log_label)
	var party_row := HBoxContainer.new()
	party_row.add_theme_constant_override("separation", 10)
	links.add_child(party_row)
	var action_box := VBoxContainer.new()
	action_box.custom_minimum_size = Vector2(240, 0)
	action_box.add_theme_constant_override("separation", 6)
	bottom.add_child(action_box)
	return {"log": log_label, "party": party_row, "aktionen": action_box}


## Zeile ans Kampflog hängen; die leere Tafel bleibt bis dahin unsichtbar.
static func log_zeile(log_label: RichTextLabel, text: String) -> void:
	log_label.append_text(text + "\n")
	log_label.modulate.a = 1.0


## Party-Karte: Porträt links, rechts Name, HP- und MP-Balken mit Zahlen,
## Status und geplante Aktion.
static func party_karte(portrait: Control, name: String, name_farbe := UiTheme.TEXT) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	var reihe := HBoxContainer.new()
	reihe.add_theme_constant_override("separation", 10)
	panel.add_child(reihe)
	var bild := CenterContainer.new()
	bild.add_child(portrait)
	reihe.add_child(bild)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	reihe.add_child(box)
	var name_label := Label.new()
	name_label.text = name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", name_farbe)
	name_label.clip_text = true
	box.add_child(name_label)
	var hp := balken(16, HP_GUT, true)
	box.add_child(hp)
	var mp := balken(12, MP_FARBE)
	box.add_child(mp)
	var status_label := Label.new()
	status_label.add_theme_font_size_override("font_size", 11)
	box.add_child(status_label)
	var plan_label := Label.new()
	plan_label.add_theme_font_size_override("font_size", 11)
	plan_label.add_theme_color_override("font_color", UiTheme.GOLD)
	plan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(plan_label)
	return {"root": panel, "hp": hp, "mp": mp, "status": status_label, "plan": plan_label,
		"name": name_label}


## Balken mit eigener Füllfarbe und mittiger Zahl („156/156"); HP-Balken
## (nach_fuellstand) wechseln unter 50 % zu Gold, unter 25 % zu Rot.
static func balken(hoehe: int, farbe: Color, nach_fuellstand := false, mit_zahl := true) -> ProgressBar:
	return Balken.new(hoehe, farbe, nach_fuellstand, mit_zahl)


class Balken:
	extends ProgressBar

	var _zahl: Label
	var _fuellung: StyleBoxFlat
	var _nach_fuellstand: bool
	## Schild-HP (Status SHIELD): hellblaues Segment hinter den HP, bei
	## voller Leiste von rechts darübergelegt; Zahl „+N“.
	var schild := 0:
		set(wert):
			if wert == schild:
				return
			schild = maxi(0, wert)
			_neu(0.0)
			queue_redraw()

	func _init(hoehe: int, farbe: Color, nach_fuellstand: bool, mit_zahl: bool) -> void:
		_nach_fuellstand = nach_fuellstand
		show_percentage = false
		custom_minimum_size = Vector2(0, hoehe)
		var hintergrund := StyleBoxFlat.new()
		hintergrund.bg_color = Color(UiTheme.KERBE, 0.9)
		hintergrund.set_corner_radius_all(4)
		add_theme_stylebox_override("background", hintergrund)
		_fuellung = StyleBoxFlat.new()
		_fuellung.set_corner_radius_all(4)
		_fuellung.border_width_top = 2
		_faerben(farbe)
		add_theme_stylebox_override("fill", _fuellung)
		_zahl = Label.new()
		_zahl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_zahl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_zahl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_zahl.add_theme_font_size_override("font_size", maxi(9, hoehe - 4))
		_zahl.add_theme_constant_override("outline_size", 3)
		_zahl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_zahl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_zahl.visible = mit_zahl
		add_child(_zahl)
		value_changed.connect(_neu)
		changed.connect(_neu.bind(0.0))
		_neu(0.0)

	# Range meldet Wertänderungen nur im Baum — beim Einhängen nachziehen.
	func _ready() -> void:
		_neu(0.0)

	func _neu(_wert: float) -> void:
		_zahl.text = "%d/%d" % [roundi(value), roundi(max_value)]
		if schild > 0:
			_zahl.text += "  +%d" % schild
		queue_redraw()
		if _nach_fuellstand:
			var anteil := value / maxf(1.0, max_value)
			_faerben(HP_GUT if anteil > 0.5 else (HP_MITTEL if anteil > 0.25 else HP_KRITISCH))

	func _faerben(farbe: Color) -> void:
		_fuellung.bg_color = farbe
		_fuellung.border_color = farbe.lightened(0.3)

	func _draw() -> void:
		if schild <= 0 or max_value <= 0.0:
			return
		var breite := size.x
		var anteil_hp := clampf(value / max_value, 0.0, 1.0)
		var anteil_schild := clampf(schild / max_value, 0.0, 1.0)
		var start := minf(anteil_hp, 1.0 - anteil_schild) * breite
		var rect := Rect2(start, 0, anteil_schild * breite, size.y)
		draw_rect(rect, Color(0.5, 0.75, 1.0, 0.75))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), Color(0.85, 0.94, 1.0))

const SCHWACH_FARBE: Color = Stil3D.PAL["glut"]
const RESIST_FARBE := Color(0.62, 0.68, 0.85)


## Bekannte Schwächen/Resistenzen eines Gegners: [[element, faktor], …] —
## nur, was die Spieler schon im Kampf entdeckt haben (GameState).
static func element_wissen(gegner: Combatant) -> Array:
	var liste: Array = []
	var schluessel := gegner.wissens_schluessel()
	for element in gegner.element_faktoren:
		if GameState.kennt_element(schluessel, int(element)):
			liste.append([int(element), float(gegner.element_faktoren[element])])
	return liste


## Füllt eine Chip-Reihe: ▲ Feuer (schwach, gold) · ▼ Eis (resistent, grau).
static func wissen_chips(box: HBoxContainer, liste: Array) -> void:
	for kind in box.get_children():
		kind.queue_free()
	for eintrag in liste:
		var block := BlockLibrary.element_block(int(eintrag[0]))
		if block == null:
			continue
		var schwach := float(eintrag[1]) > 1.0
		box.add_child(chip(("▲ " if schwach else "▼ ") + block.display_name,
			SCHWACH_FARBE if schwach else RESIST_FARBE))
	box.visible = not liste.is_empty()


## Kleiner farbiger Chip (Typen, Schwächen) — klick-durchlässig.
static func chip(text: String, farbe: Color) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(farbe.r, farbe.g, farbe.b, 0.22)
	stil.border_color = farbe
	stil.set_border_width_all(1)
	stil.set_corner_radius_all(4)
	stil.content_margin_left = 6
	stil.content_margin_right = 6
	stil.content_margin_top = 1
	stil.content_margin_bottom = 1
	panel.add_theme_stylebox_override("panel", stil)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", farbe.lightened(0.35))
	panel.add_child(label)
	return panel


## Großes, ausblendendes Banner in der Bildmitte (Erstschlag/Hinterhalt).
static func banner(eltern: Control, text: String, farbe: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", farbe)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.08, 0.9))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 50
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	eltern.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


## Boss-Phasenwechsel: Lichtblitz, die Halle färbt sich röter, Beben +
## Aufglühen des Bosses und ein Banner „Phase N“. Nennt nur die Phase,
## nicht was der Boss vorhat.
static func phasen_auftritt(eltern: Control, buehne: KampfBuehne3D, schluessel: Variant,
		phase: int) -> void:
	if buehne != null:
		buehne.boss_phase(schluessel, phase)
	banner(eltern, Loc.pick("Phase %d", "Phase %d") % phase, Color("ff5a4a"))


## Boss-Banner als Letterbox: zwei dunkle Leisten schieben sich von oben und
## unten ins Bild — oben der Name, unten seine Eigenheiten — und gehen
## wieder. Das Boss-Panel und die Figur bleiben frei; Klicks gehen durch.
const LETTERBOX_HOEHE := 96.0


static func boss_banner(eltern: Control, name: String, hinweis: String) -> void:
	var ebene := Control.new()
	ebene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ebene.z_index = 50
	ebene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	eltern.add_child(ebene)
	var leisten: Array[Control] = []
	for oben in [true, false]:
		var text := name if oben else hinweis
		var leiste := PanelContainer.new()
		leiste.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var stil := StyleBoxFlat.new()
		stil.bg_color = Color(0.02, 0.02, 0.05, 0.94)
		stil.border_color = Color("ff5a4a") if oben else UiTheme.GOLD
		stil.border_color.a = 0.75
		if oben:
			stil.border_width_bottom = 2
		else:
			stil.border_width_top = 2
		stil.content_margin_left = 24
		stil.content_margin_right = 24
		stil.content_margin_top = 10
		stil.content_margin_bottom = 10
		leiste.add_theme_stylebox_override("panel", stil)
		leiste.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if oben else Control.PRESET_BOTTOM_WIDE)
		leiste.custom_minimum_size = Vector2(0, LETTERBOX_HOEHE)
		leiste.grow_vertical = Control.GROW_DIRECTION_END if oben else Control.GROW_DIRECTION_BEGIN
		var label := Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 40 if oben else 18)
		label.add_theme_color_override("font_color", Color("ff5a4a") if oben else UiTheme.GOLD)
		label.add_theme_constant_override("outline_size", 8 if oben else 6)
		label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.08, 0.9))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		leiste.add_child(label)
		ebene.add_child(leiste)
		leiste.visible = not text.is_empty()  # ohne Eigenheiten keine untere Leiste
		leisten.append(leiste)
	# Hineinschieben, sobald das Layout die Höhe kennt; nach 2.4 s wieder raus.
	for leiste in leisten:
		leiste.modulate.a = 0.0
	# Baum vorher merken: verlässt die Szene den Baum in diesen zwei Bildern
	# (Kampf sofort vorbei), wäre eltern beim zweiten Zugriff schon frei.
	var baum := eltern.get_tree()
	await baum.process_frame
	await baum.process_frame
	if not is_instance_valid(ebene) or not ebene.is_inside_tree():
		return
	for i in leisten.size():
		var leiste := leisten[i]
		var ziel := leiste.position.y
		var weg := leiste.size.y * (-1.0 if i == 0 else 1.0)
		leiste.position.y = ziel + weg
		var t := leiste.create_tween()
		t.tween_property(leiste, "position:y", ziel, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(leiste, "modulate:a", 1.0, 0.25)
		t.tween_interval(2.4)
		t.tween_property(leiste, "position:y", ziel + weg, 0.45).set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)
		t.parallel().tween_property(leiste, "modulate:a", 0.0, 0.45)
	var ende := ebene.create_tween()
	ende.tween_interval(3.3)
	ende.tween_callback(ebene.queue_free)


## Goldrahmen um die Karte des Helden, der gerade Befehle bekommt (UiHolz
## „tafel_aktiv“: helleres Holz, Gold statt Messing).
static func aktiv_setzen(karte: Control, aktiv: bool) -> void:
	if not aktiv:
		karte.remove_theme_stylebox_override("panel")
		return
	karte.add_theme_stylebox_override("panel", UiHolz.box("tafel_aktiv"))


## Knopf im Skill-Untermenü (Host + Co-op-Gast): Name und MP-Kosten, Sperr-
## Vermerk (ungültig / falsche Waffe), Tooltip mit Bausteinen und Wirkung.
## `mp` = verfügbare MP des Helden (beim Gast aus dem Netz-Stand).
static func skill_knopf(skill: Skill, held: Combatant, mp: int) -> Button:
	var cost: int = skill.get_mp_cost(held)
	var richtwert := cost
	var wrong_weapon := not skill.usable_with_weapon(held)
	var grund := skill.fehler(held)
	var button := Button.new()
	button.text = "%s (%d MP)" % [skill.display_name, cost]
	if skill.hat(Enums.SkillModifier.VOLLHEILUNG):
		# Vollheilung: MP nach Bedarf (Richtwert = normale Kosten), notfalls alle.
		button.text = Loc.pick("%s (MP nach Bedarf)", "%s (MP as needed)") % skill.display_name
		cost = 1
	if not grund.is_empty():
		button.text += Loc.pick("  [ungültig]", "  [invalid]")
	elif wrong_weapon:
		button.text += Loc.pick("  [braucht %s]", "  [needs %s]") \
			% BlockLibrary.families_label(skill.required_weapon_families())
	button.disabled = mp < cost or wrong_weapon or not grund.is_empty()
	button.tooltip_text = grund if not grund.is_empty() else skill_tooltip(skill, richtwert)
	return button


## Tooltip: woraus der Skill gebaut ist — direkt im Kampf nachschlagbar.
static func skill_tooltip(skill: Skill, cost: int) -> String:
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


static func punkte_text(member: Combatant) -> String:
	return Loc.pick("Punkte verteilen: %s (%d frei)", "Spend points: %s (%d free)") \
		% [member.display_name, member.stat_points]


## Knopf im Sieg-Panel (Host + Co-op-Gast): klappt die Punkteverteilung für
## diesen Helden auf — die Übersicht `box` weicht solange, „Fertig“ führt
## zurück. `speichern` = false, wenn der Stand gerade nicht gesichert werden
## darf (Host nach dem Boss: sonst stünde „Boss besiegt“ ohne Belohnungskarte
## im Stand).
static func punkte_knopf(panel: PanelContainer, box: VBoxContainer,
		member: Combatant, speichern := true) -> Button:
	var button := Button.new()
	button.text = punkte_text(member)
	# Verteilt die KI-Brücke von außen, frischt sie den Text über die Gruppe auf.
	button.set_meta(&"held", member)
	button.add_to_group(&"punkte_knopf")
	button.pressed.connect(func() -> void:
		button.release_focus()
		box.visible = false
		var wrap := VBoxContainer.new()
		wrap.add_theme_constant_override("separation", 10)
		var head := Label.new()
		head.text = Loc.pick("Statuspunkte — %s", "Stat points — %s") % member.display_name
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wrap.add_child(head)
		var alloc := StatAllocator.create(member)
		alloc.speichern = speichern
		wrap.add_child(alloc)
		var done := Button.new()
		done.text = Loc.pick("« Fertig", "« Done")
		done.pressed.connect(func() -> void:
			wrap.queue_free()
			button.text = punkte_text(member)
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
		panel.add_child(wrap)
		alloc.fokus_setzen()
		if member.stat_points <= 0:
			done.grab_focus.call_deferred())
	return button
