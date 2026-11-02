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
## Befehlsspalte: höchstens so hoch wie das volle Befehlsmenü (Kopf + 8
## Knöpfe), höchstens so breit, bevor lange Namen umbrechen.
const AKTIONEN_MAX_HOEHE := 360.0
const AKTIONEN_MAX_BREITE := 300.0
## Rand oben + unten der Kampf-Oberfläche (battle_scene/coop_battle_scene).
const KAMPF_RAND_Y := 24.0
## Rand links + rechts der Kampf-Oberfläche.
const KAMPF_RAND_X := 32.0
## Jeder Figur-Platzhalter der Gegnerreihe trägt seine Höchstbreite (Meta
## &"max_breite", Bildpunkte = Panelbreite + Abstand). Die Bühne verkleinert
## die Figuren danach aber erst, wenn sie gemessen nicht mehr passen (Bildrand
## oder Überlappung, KampfBuehne3D._reihe_eng) — unabhängig von der Gegnerzahl.
## Ab FIGUR_BREITE_AB Gegnern (Teilung, Verstärkung, Boss mit Begleitern) ist
## das Boss-Panel (Meta &"boss_panel") BOSS_PANEL_BREITE-mal so breit wie
## vorgesehen, damit der Boss auch verkleinert in Höhe und Fläche die größte
## Figur bleibt. Weniger Gegner: Panels unverändert.
const FIGUR_BREITE_AB := 7
const BOSS_PANEL_BREITE := 1.4


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
	# Befehle in einer Scroll-Spalte mit Höchsthöhe (Layout-Pass 2026-11): viele
	# Tränke oder Skill-Slots schieben weder die Spalte unter die Bildkante noch
	# Log und Party-Karten aus dem Bild; W/S scrollt den Fokus mit. Zu lange
	# Skill-/Itemnamen brechen um, statt die Spalte zu verbreitern.
	var spalte := Bildschirm.HoehenListe.new(6, 0, aktionen_hoehe.bind(main, bottom))
	spalte.max_breite = AKTIONEN_MAX_BREITE
	bottom.add_child(spalte)
	var action_box := spalte.liste
	action_box.custom_minimum_size = Vector2(240, 0)
	return {"log": log_label, "party": party_row, "aktionen": action_box}


## Höchsthöhe der Befehlsspalte: was über dem unteren Bereich (Kopfzeile,
## Zugleiste, Gegnerreihe) mindestens gebraucht wird, bleibt frei — und nie
## höher als das volle Befehlsmenü (AKTIONEN_MAX_HOEHE), damit die Arena
## nicht zusammenschrumpft.
static func aktionen_hoehe(main: VBoxContainer, bottom: Control) -> float:
	var oben := main.get_combined_minimum_size().y - bottom.get_combined_minimum_size().y
	var frei := main.get_viewport_rect().size.y - KAMPF_RAND_Y - oben
	return clampf(frei, 160.0, AKTIONEN_MAX_HOEHE)


## Gegnerreihe (Host + Gast): passt sich der Gegnerzahl an (Layout-Pass
## 2026-11). Bis zu 8 Gegner (Teilung, Riesenwuchs, Verstärkung) passen in
## die Bildbreite: erst rückt der Abstand zusammen (bis 4 px), dann werden
## die Panels schmaler (Namen brechen ohnehin um), notfalls auch die Plätze
## der 3D-Figuren. Wenige Gegner stehen unverändert. Panels melden ihren
## Figur-Platzhalter über die Meta &"figur_platz".
static func gegnerreihe(abstand: int) -> HBoxContainer:
	var reihe := HBoxContainer.new()
	reihe.add_theme_constant_override("separation", abstand)
	var einpassen := func(_kind: Node) -> void:
		gegnerreihe_einpassen.call_deferred(reihe, abstand)
	reihe.child_entered_tree.connect(einpassen)
	reihe.child_exiting_tree.connect(einpassen)
	return reihe


static func gegnerreihe_einpassen(reihe_oder_frei: Variant, abstand_soll: int) -> void:
	# Untypisiert: beim Szenenwechsel kommt der Aufruf (deferred) erst nach
	# dem Freigeben der Reihe an.
	if not is_instance_valid(reihe_oder_frei) or not (reihe_oder_frei as Node).is_inside_tree():
		return
	var reihe := reihe_oder_frei as HBoxContainer
	var panels: Array[Control] = []
	for kind in reihe.get_children():
		if kind is Control and not kind.is_queued_for_deletion():
			panels.append(kind)
	var n := panels.size()
	if n == 0:
		return
	var breite := reihe.get_viewport_rect().size.x - KAMPF_RAND_X
	var summe := 0.0
	var soll_je: Array[float] = []
	for panel in panels:
		if not panel.has_meta(&"soll_breite"):
			# Gast: der Rahmen ist so breit wie sein Inhalt (Figur-Platz).
			panel.set_meta(&"soll_breite", maxf(panel.custom_minimum_size.x,
				panel.get_combined_minimum_size().x))
		var soll_b := float(panel.get_meta(&"soll_breite"))
		if n >= FIGUR_BREITE_AB and panel.has_meta(&"boss_panel"):
			soll_b *= BOSS_PANEL_BREITE  # Boss bleibt bei vielen Gegnern der Größte
		soll_je.append(soll_b)
		summe += soll_b
	var abstand := abstand_soll
	if n > 1 and summe + abstand_soll * (n - 1) > breite:
		abstand = clampi(floori((breite - summe) / (n - 1)), 4, abstand_soll)
	reihe.add_theme_constant_override("separation", abstand)
	var faktor := minf(1.0, (breite - abstand * (n - 1)) / maxf(1.0, summe))
	for i in n:
		var panel := panels[i]
		panel.custom_minimum_size.x = floorf(soll_je[i] * faktor)
		var platz: Variant = panel.get_meta(&"figur_platz", null)
		if is_instance_valid(platz) and platz is Control:
			var figur := platz as Control
			if not figur.has_meta(&"soll_groesse"):
				figur.set_meta(&"soll_groesse", figur.custom_minimum_size)
				figur.set_meta(&"soll_pivot", figur.pivot_offset)
			var soll: Vector2 = figur.get_meta(&"soll_groesse")
			var f := minf(1.0, panel.custom_minimum_size.x / maxf(1.0, soll.x))
			figur.custom_minimum_size = (soll * f).floor()
			figur.pivot_offset = (figur.get_meta(&"soll_pivot") as Vector2) * f
			figur.set_meta(&"max_breite", panel.custom_minimum_size.x + abstand)


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
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # gekürzt = „…“
	name_label.tooltip_text = name  # voller Name beim Darüberfahren
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
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
		_zahl.add_theme_color_override("font_outline_color", Color(UiTheme.KERBE, 0.8))
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
		draw_rect(rect, Color(Stil3D.PAL["ui_schild"], 0.75))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), Stil3D.PAL["stern"])

const SCHWACH_FARBE: Color = Stil3D.PAL["glut"]
const RESIST_FARBE: Color = Stil3D.PAL["ui_resist"]


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
	label.add_theme_color_override("font_outline_color", Color(UiTheme.KERBE, 0.9))
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
	banner(eltern, Loc.pick("Phase %d", "Phase %d") % phase, Stil3D.PAL["boss_siegel"])


## Boss-Banner als Letterbox: zwei dunkle Leisten schieben sich von oben und
## unten ins Bild — oben der Name, unten seine Eigenheiten — und gehen
## wieder. Das Boss-Panel und die Figur bleiben frei; Klicks gehen durch.
const LETTERBOX_HOEHE := 96.0


## buehne (optional): solange die obere Leiste steht, rahmt die Bühne den Boss
## darunter (KampfBuehne3D.rahmen_oben) — Krone, Hörner und Geweih bleiben frei.
static func boss_banner(eltern: Control, name: String, hinweis: String, buehne: KampfBuehne3D = null) -> void:
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
		stil.bg_color = Color(UiTheme.KERBE, 0.94)
		stil.border_color = Stil3D.PAL["boss_siegel"] if oben else UiTheme.GOLD
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
		label.add_theme_color_override("font_color", Stil3D.PAL["boss_siegel"] if oben else UiTheme.GOLD)
		label.add_theme_constant_override("outline_size", 8 if oben else 6)
		label.add_theme_color_override("font_outline_color", Color(UiTheme.KERBE, 0.9))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		leiste.add_child(label)
		ebene.add_child(leiste)
		leiste.visible = not text.is_empty()  # ohne Eigenheiten keine untere Leiste
		leisten.append(leiste)
	# Hineinschieben, sobald das Layout die Höhe kennt; nach 2.4 s wieder raus.
	for leiste in leisten:
		leiste.modulate.a = 0.0
	if buehne != null:
		# Gleich ab dem ersten Bild gerahmt (die Figur erscheint nicht erst groß).
		buehne.rahmen_oben = eltern.get_global_rect().position.y + LETTERBOX_HOEHE
	# Baum vorher merken: verlässt die Szene den Baum in diesen zwei Bildern
	# (Kampf sofort vorbei), wäre eltern beim zweiten Zugriff schon frei.
	var baum := eltern.get_tree()
	await baum.process_frame
	await baum.process_frame
	if not is_instance_valid(ebene) or not ebene.is_inside_tree():
		if is_instance_valid(buehne):
			buehne.rahmen_oben = 0.0
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
		if i == 0 and is_instance_valid(buehne):
			buehne.rahmen_oben = leiste.get_global_rect().end.y - weg  # Endlage (steht noch oben draußen)
			# Mit der Leiste hinaus: der Boss richtet sich zu voller Größe auf.
			var r := buehne.create_tween()
			r.tween_interval(0.35 + 2.4)
			r.tween_property(buehne, "rahmen_oben", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var ende := ebene.create_tween()
	ende.tween_interval(3.3)
	ende.tween_callback(func() -> void:
		if is_instance_valid(buehne):
			buehne.rahmen_oben = 0.0
		ebene.queue_free())


## Goldrahmen um die Karte des Helden, der gerade Befehle bekommt (UiHolz
## „tafel_aktiv“: helleres Holz, Glut-Rahmen statt Messing).
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
