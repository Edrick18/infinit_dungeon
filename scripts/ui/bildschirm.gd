class_name Bildschirm
extends RefCounted
## Einheitliche Bildschirm-Vorlage für alle Menü-/Hub-Szenen (UI-Layout-Pass):
## gleiche Ränder, Kopfzeile mit Titel links und Info-Chips + Zurück-Knopf
## rechts (immer an derselben Stelle, Esc löst ihn aus), Untertitel darunter,
## dann der Inhalt. Dahinter die abgedunkelte 3D-Kulisse.
## Dazu fenster()/fenster_titel() für Ergebnis- und Abschlussfenster
## (Kampfende Host + Gast, Dungeon abgeschlossen); das Hauptmenü nutzt
## RAND und tafel() ohne Kopfzeile (es hat kein Zurück).
##
##   var b := Bildschirm.bauen(self, "Schmiede", &"schmiede", _zurueck)
##   b.info("Gold: 120")
##   b.inhalt.add_child(...)

const RAND := 24
const TITEL_GROESSE := 28
## Abschluss-/Ergebnisfenster (fenster()): Titel und Mindestbreite.
const FENSTER_TITEL_GROESSE := 32
const FENSTER_BREITE := 440

var wurzel: VBoxContainer       ## alles unter der Kulisse
var kopf_info: HBoxContainer     ## rechts in der Kopfzeile, vor dem Zurück-Knopf
var untertitel: Label            ## eine erklärende Zeile (leer = unsichtbar)
var inhalt: VBoxContainer        ## füllt den Rest des Bildschirms
var zurueck: Button
var titel: Label


## Baut die Vorlage in `szene` ein. `tabs` (optional) sitzt über der
## Kopfzeile. `zurueck_text` z.B. „Menü“, „Werkstatt“.
static func bauen(szene: Control, titel_text: String, ort: StringName,
		zurueck_aktion: Callable, zurueck_text := "", tabs: Control = null) -> Bildschirm:
	var b := Bildschirm.new()
	szene.theme = UiTheme.get_theme()
	szene.add_child(UiTheme.make_background(ort, true))

	var rand := MarginContainer.new()
	rand.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for seite in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		rand.add_theme_constant_override(seite, RAND)
	szene.add_child(rand)

	b.wurzel = VBoxContainer.new()
	b.wurzel.add_theme_constant_override("separation", 10)
	rand.add_child(b.wurzel)
	if tabs != null:
		tabs.set_meta(&"nicht_zuerst", true)
		b.wurzel.add_child(tabs)

	var kopf := HBoxContainer.new()
	kopf.add_theme_constant_override("separation", 10)
	b.wurzel.add_child(kopf)
	b.titel = Label.new()
	b.titel.text = titel_text
	b.titel.add_theme_font_size_override("font_size", TITEL_GROESSE)
	_eingraviert(b.titel)
	b.titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.titel.clip_text = true
	kopf.add_child(b.titel)
	b.kopf_info = HBoxContainer.new()
	b.kopf_info.add_theme_constant_override("separation", 8)
	b.kopf_info.alignment = BoxContainer.ALIGNMENT_END
	b.kopf_info.set_meta(&"nicht_zuerst", true)
	kopf.add_child(b.kopf_info)
	b.zurueck = Button.new()
	b.zurueck.text = "‹ " + (zurueck_text if not zurueck_text.is_empty() else Loc.pick("Zurück", "Back"))
	b.zurueck.tooltip_text = Loc.pick("Zurück (Esc)", "Back (Esc)")
	b.zurueck.custom_minimum_size = Vector2(120, 38)
	b.zurueck.pressed.connect(zurueck_aktion)
	b.zurueck.set_meta(&"nicht_zuerst", true)  # Tastatur-Fokus startet im Inhalt
	kopf.add_child(b.zurueck)

	b.untertitel = Label.new()
	b.untertitel.add_theme_font_size_override("font_size", 13)
	# Über der Kulisse: gedämpft, aber mit Kontur — bleibt auf jedem Grund lesbar.
	b.untertitel.add_theme_color_override("font_color", Color(UiTheme.TEXT, 0.8))
	b.untertitel.add_theme_color_override("font_outline_color", UiTheme.KERBE)
	b.untertitel.add_theme_constant_override("outline_size", 4)
	b.untertitel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.untertitel.visible = false
	b.wurzel.add_child(b.untertitel)

	b.inhalt = VBoxContainer.new()
	b.inhalt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.inhalt.theme = UiTheme.innen_theme()  # Zeilen = eingelassene Fächer
	b.inhalt.add_theme_constant_override("separation", 10)
	b.wurzel.add_child(b.inhalt)

	var esc := EscWaechter.new()
	esc.aktion = zurueck_aktion
	szene.add_child(esc)
	return b


func setze_untertitel(text: String) -> void:
	untertitel.text = text
	untertitel.visible = not text.is_empty()


## Info-Chip rechts oben (Gold, Punkte, Zähler …). Gibt das Label zurück,
## damit die Szene den Text später aktualisieren kann.
func info(text: String, farbe := UiTheme.GOLD) -> Label:
	var chip := PanelContainer.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(UiTheme.HOLZ_TIEF, 0.9)
	stil.border_color = Color(farbe.r, farbe.g, farbe.b, 0.7)
	stil.set_border_width_all(1)
	stil.set_corner_radius_all(6)
	stil.content_margin_left = 10
	stil.content_margin_right = 10
	stil.content_margin_top = 4
	stil.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", stil)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", farbe)
	chip.add_child(label)
	kopf_info.add_child(chip)
	return label


## Inhaltstafel: dunkles Holz mit Messingrahmen (UiHolz „tafel“) — Text
## bleibt lesbar, egal was die Kulisse dahinter zeigt. Zeilen-Panels darin
## werden zu eingelassenen Fächern (UiTheme.innen_theme). `innen_rand` > 0 =
## Innenrand ringsum.
static func tafel(kind: Control = null, innen_rand := 0) -> PanelContainer:
	var panel := PanelContainer.new()
	var stil: StyleBox = UiHolz.box("tafel")
	if innen_rand > 0:
		stil = UiHolz.box_mit_rand("tafel", innen_rand)
	panel.add_theme_stylebox_override("panel", stil)
	panel.theme = UiTheme.innen_theme()
	if kind != null:
		panel.add_child(kind)
	return panel


## Abschluss-/Ergebnisfenster mittig über einer Szene (Kampfende, Dungeon
## abgeschlossen): Tafel mit dem Rand der Vorlage (RAND) und fester
## Mindestbreite. Gibt {"mitte": CenterContainer, "tafel": PanelContainer}
## zurück; Fokus setzen und einsperren (UiTheme.fokus_einsperren) macht die
## Szene, sie kennt den Start-Knopf.
static func fenster(eltern: Node) -> Dictionary:
	var mitte := CenterContainer.new()
	mitte.theme = UiTheme.get_theme()  # auch unter einer CanvasLayer
	mitte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # vor add_child
	eltern.add_child(mitte)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiHolz.box_mit_rand("tafel", RAND))
	panel.custom_minimum_size = Vector2(FENSTER_BREITE, 0)
	mitte.add_child(panel)
	return {"mitte": mitte, "tafel": panel}


## Fensterseite mit begrenzter Höhe (Sieg mit viel Beute, Taschen voll):
## alle Kinder von `seite` ab `ab_index` (Standard: alles nach dem Titel)
## wandern in eine Scroll-Liste. Sie ist so hoch wie ihr Inhalt, höchstens
## so hoch, dass die ganze Seite samt Knöpfen darunter in den Bildschirm
## passt — „Weiter“ läuft nie mehr hinaus. Knöpfe ganz am Ende der Seite
## (z. B. „Punkte verteilen“) bleiben unter der Liste stehen: immer im Bild,
## und W vom ersten Knopf erreicht die Liste darüber. Danach angehängte
## Knöpfe stehen ebenfalls darunter; Zeilen darin rücken enger (`abstand`).
## Gibt die Liste zurück (ihr Inhalt: `.liste`).
static func liste_einbauen(seite: VBoxContainer, ab_index := 1, abstand := 8) -> HoehenListe:
	var hoehen := HoehenListe.new(abstand)
	var kinder := seite.get_children().slice(ab_index)
	while kinder.size() > 1 and kinder.back() is BaseButton:
		kinder.pop_back()
	for kind in kinder:
		seite.remove_child(kind)
		hoehen.liste.add_child(kind)
	seite.add_child(hoehen)
	seite.move_child(hoehen, mini(ab_index, seite.get_child_count() - 1))
	return hoehen


## Scroll-Fläche, die man auch per Tastatur lesen kann (Layout-Pass 2026-11):
## fokussierte Elemente darin scrollen ins Bild (follow_focus). Läuft sie
## über, ist sie selbst per Tastatur erreichbar: W/S (ui_up/ui_down)
## scrollen, am Ende wandert der Fokus wie gewohnt weiter; Fokusring wie bei
## Knöpfen. Mausrad scrollt immer. Ohne fokussierbaren Inhalt (Credits)
## bemerkt sie den Überlauf selbst am Scrollbalken.
class TastenScroll:
	extends ScrollContainer
	const SCHRITT := 48
	var _ueberlauf := false

	func _init(selbst_pruefen := true) -> void:
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		follow_focus = true
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_PASS
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		if selbst_pruefen:
			get_v_scroll_bar().changed.connect(func() -> void:
				var balken := get_v_scroll_bar()
				_ueberlauf_setzen(balken.max_value - balken.page > 0.5))

	func _ueberlauf_setzen(ueber: bool) -> void:
		if ueber == _ueberlauf:
			return
		_ueberlauf = ueber
		focus_mode = Control.FOCUS_ALL if ueber else Control.FOCUS_NONE
		if not ueber and has_focus():
			release_focus()
		_ueberlauf_geaendert(ueber)

	## Für Unterklassen (Platz für den Scrollbalken).
	func _ueberlauf_geaendert(_ueber: bool) -> void:
		pass

	## Läuft die Liste über? (Tests, KI-Brücke)
	func laeuft_ueber() -> bool:
		return _ueberlauf

	func _gui_input(event: InputEvent) -> void:
		if not has_focus():
			return
		var schritt := 0
		if event.is_action_pressed(&"ui_down", true):
			schritt = SCHRITT
		elif event.is_action_pressed(&"ui_up", true):
			schritt = -SCHRITT
		if schritt == 0:
			return
		var vorher := scroll_vertical
		scroll_vertical += schritt
		if scroll_vertical != vorher:
			accept_event()  # gescrollt; am Rand geht der Fokus normal weiter

	func _draw() -> void:
		if has_focus():
			draw_style_box(UiHolz.fokus_box(), Rect2(Vector2.ZERO, size))


## Scroll-Liste eines Fensters: wächst mit dem Inhalt bis zur Höchsthöhe
## (Standard: Bildschirm minus Rand, Fenster-Innenrand und Rest der Seite;
## oder `grenze`, eine Funktion, die die Höhe liefert), darüber scrollt sie
## (Tastatur wie TastenScroll). Einzeilige Texte und Knöpfe, die breiter als
## `max_breite` wären (Standard: Bildschirm minus Ränder), brechen um, statt
## das Fenster über den Bildrand zu schieben. `polster` = Abstand der Zeilen
## zum Fokusring links und rechts; mit Polster bleiben die Zeilen auch mit
## Scrollbalken mittig (Fenster), ohne steht der Balken nur rechts (Spalte).
class HoehenListe:
	extends TastenScroll
	const POLSTER := 8
	var liste: VBoxContainer
	var max_breite := 0.0
	var _rand: MarginContainer
	var _polster := POLSTER
	var _grenze := Callable()

	func _init(abstand: int, polster := POLSTER, grenze := Callable()) -> void:
		super(false)
		_polster = polster
		_grenze = grenze
		_rand = MarginContainer.new()
		_rand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rand.mouse_filter = Control.MOUSE_FILTER_PASS
		_rand.add_theme_constant_override("margin_left", polster)
		_rand.add_theme_constant_override("margin_right", polster)
		add_child(_rand)
		liste = VBoxContainer.new()
		liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		liste.mouse_filter = Control.MOUSE_FILTER_PASS
		liste.add_theme_constant_override("separation", abstand)
		_rand.add_child(liste)
		_rand.minimum_size_changed.connect(_anpassen)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_RESIZED:
			_anpassen.call_deferred()

	## Höchsthöhe: was die Seite ohne die Liste braucht, bleibt frei.
	func hoechsthoehe() -> float:
		if not is_inside_tree():
			return 400.0
		if _grenze.is_valid():
			return float(_grenze.call())
		var seite := get_parent() as Control
		var rest := 0.0
		if seite != null:
			rest = seite.get_combined_minimum_size().y - custom_minimum_size.y
		return maxf(120.0, get_viewport_rect().size.y - 4 * RAND - rest)

	## Breiteste erlaubte Zeile: Bildschirm minus Rand und Fenster-Innenrand,
	## Polster und Scrollbalken.
	func breitengrenze() -> float:
		if max_breite > 0.0:
			return max_breite
		return get_viewport_rect().size.x - 4 * RAND - 2 * _polster - 2 * _balken_breite()

	func _balken_breite() -> int:
		return int(get_v_scroll_bar().get_combined_minimum_size().x) + 4

	## Zu breite einzeilige Zeilen umbrechen (lange Heldennamen auf der Bank,
	## lange Skill-/Itemnamen in der Kampfspalte). Umbrochen wird auf die
	## Breite der übrigen Zeilen (mindestens UMBRUCH_MIN, höchstens die
	## Grenze) — eine einzelne lange Zeile zieht das Fenster so nicht auf
	## fast die ganze Bildbreite (Abnahme 2026-11).
	const UMBRUCH_MIN := 560.0

	func _breite_begrenzen() -> void:
		var grenze := breitengrenze()
		var zu_breit: Array[Control] = []
		var rest_breite := 0.0
		for kind in liste.get_children():
			var zeile := kind as Control
			if zeile == null or not zeile.visible:
				continue
			var einzeilig := (zeile is Label and (zeile as Label).autowrap_mode == TextServer.AUTOWRAP_OFF) \
				or (zeile is Button and (zeile as Button).autowrap_mode == TextServer.AUTOWRAP_OFF)
			var breite := zeile.get_combined_minimum_size().x
			if einzeilig and breite > grenze + 0.5:
				zu_breit.append(zeile)
			else:
				rest_breite = maxf(rest_breite, breite)
		if zu_breit.is_empty():
			return
		var ziel := clampf(rest_breite, minf(UMBRUCH_MIN, grenze), grenze)
		for zeile in zu_breit:
			if zeile is Label:
				(zeile as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			else:
				(zeile as Button).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			zeile.custom_minimum_size.x = ziel

	func _anpassen() -> void:
		if not is_inside_tree():
			return
		_breite_begrenzen()
		var inhalt := liste.get_combined_minimum_size().y
		var grenze := hoechsthoehe()
		var hoehe := minf(inhalt, grenze)
		if absf(custom_minimum_size.y - hoehe) > 0.5:
			custom_minimum_size.y = hoehe
		_ueberlauf_setzen(inhalt > grenze + 0.5)

	func _ueberlauf_geaendert(ueber: bool) -> void:
		# Platz für den Scrollbalken (die breiteste Zeile läge sonst
		# darunter) — im Fenster links gleich viel, die Zeilen bleiben mittig.
		var balken := _balken_breite() if ueber else 0
		_rand.add_theme_constant_override("margin_left", _polster + (balken if _polster > 0 else 0))
		_rand.add_theme_constant_override("margin_right", _polster + balken)


## Titel eines Fensters bzw. einer Fensterseite (gold, mittig).
static func fenster_titel(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FENSTER_TITEL_GROESSE)
	label.add_theme_color_override("font_color", UiTheme.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eingraviert(label)
	return label


## Titel wie ins Holz geschnitten: dunkle Kontur in Kerbenfarbe, damit
## große Schrift auf Holz und 3D-Kulisse gleich gut steht.
static func _eingraviert(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", UiTheme.KERBE)
	label.add_theme_constant_override("outline_size", 6)


## Überschrift innerhalb des Inhalts (Spalten-Titel).
static func ueberschrift(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", UiTheme.GOLD)
	return label


## Senkrechte Scroll-Liste, die den verfügbaren Platz füllt (nie quer).
## Der Tastatur-Fokus scrollt mit (sonst blieben Einträge unter dem Rand
## per WASD unerreichbar).
static func scroll_liste(abstand := 6) -> Array:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var liste := VBoxContainer.new()
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste.add_theme_constant_override("separation", abstand)
	scroll.add_child(liste)
	return [scroll, liste]


class EscWaechter:
	extends Node
	## Esc = Zurück-Knopf, in jeder Szene gleich.
	var aktion: Callable

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo \
				and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			aktion.call()
