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
## Kopfzeile (Stadt-Reiter). `zurueck_text` z.B. „Menü“, „Werkstatt“.
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
static func scroll_liste(abstand := 6) -> Array:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
