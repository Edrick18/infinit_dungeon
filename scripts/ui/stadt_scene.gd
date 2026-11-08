class_name StadtSzene
extends Control
## Begehbare Stadt (Paket 6a, Spieltest-Feedback 2026-11: „nicht permanent
## alle Optionen ins Gesicht gedrückt“): ein kleiner Stadtplatz im Stil des
## Lager-Dioramas. Der erste Held der Party läuft mit WASD (oder per
## Mausklick, wie ein Ziel im Dungeon); steht er vor einem Gebäude, zeigt
## ein schlichtes Namensschild, wo er ist — E (bzw. Klick aufs Schild)
## öffnet das Menü dahinter. Taverne, Händler und Schmiede kehren hierher
## zurück (zurueck()); der Held steht dann vor der Tür, aus der er kam.
## Esc oder der Steg im Süden führen zurück ins Hauptmenü.
##
## Alle Knöpfe hier sind ohne Tastatur-Fokus: WASD läuft, statt einen Fokus
## zu wandern (sonst griffe das Fokus-Netz nach dem ersten Knopf).

const MAIN_SCENE := "res://scenes/main.tscn"
const STADT_SCENE := "res://scenes/hub/stadt.tscn"
const ZIELE := {
	&"taverne": "res://scenes/hub/tavern.tscn",
	&"haendler": "res://scenes/hub/shop_scene.tscn",
	&"schmiede": "res://scenes/hub/smith.tscn",
	&"ausgang": MAIN_SCENE,
}
const TEMPO := 3.6        ## Welt-Einheiten pro Sekunde
const HALB := 0.3         ## halbe Breite des Helden (Kollision)
const LAUF_RADIUS := 7.2  ## so weit vom Platzmittelpunkt darf er laufen
const NAH := 1.25         ## Abstand zum Türpunkt, ab dem das Schild erscheint

## Ort, aus dessen Menü man zurückkommt (leer = vom Hauptmenü: am Steg).
static var herkunft: StringName = &""

var held_pos := Vector2.ZERO
var _nah: StringName = &""
var _klick_ziel: Variant = null  ## Vector2 oder null
var _kulisse: StadtKulisse
var _schild: Button
var _verlassen_laeuft := false


## Aus einem Stadt-Menü zurück auf den Platz, vor die Tür von `von`.
static func zurueck(baum: SceneTree, von: StringName) -> void:
	herkunft = von
	baum.change_scene_to_file(STADT_SCENE)


func _ready() -> void:
	theme = UiTheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Klicks auf den Platz kommen in _unhandled_input an
	Music.play(&"stadt")
	_kulisse = StadtKulisse.new()
	# Anker VOR dem Einhängen setzen (siehe UiTheme.make_background).
	_kulisse.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_kulisse.z_index = -1
	add_child(_kulisse)
	_oberflaeche_bauen()
	if ZIELE.has(herkunft) and herkunft != &"ausgang":
		_kulisse.springen(StadtKulisse.tuer(herkunft), StadtKulisse.front(herkunft))
	else:
		_kulisse.springen(StadtKulisse.tuer(&"ausgang"), Vector2(0, -1))
	herkunft = &""
	held_pos = _kulisse.held_pos
	_nah_pruefen()


func _oberflaeche_bauen() -> void:
	var rand := MarginContainer.new()
	rand.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for seite in ["margin_left", "margin_top", "margin_right"]:
		rand.add_theme_constant_override(seite, Bildschirm.RAND)
	add_child(rand)
	var kopf := HBoxContainer.new()
	kopf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rand.add_child(kopf)
	var titel := Label.new()
	titel.text = Loc.pick("Stadt", "Town")
	titel.add_theme_font_size_override("font_size", Bildschirm.TITEL_GROESSE)
	Bildschirm._eingraviert(titel)
	titel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kopf.add_child(titel)
	var zurueck_knopf := Button.new()
	zurueck_knopf.text = "‹ " + Loc.pick("Menü", "Menu")
	zurueck_knopf.tooltip_text = Loc.pick("Zurück (Esc)", "Back (Esc)")
	zurueck_knopf.custom_minimum_size = Vector2(120, 38)
	zurueck_knopf.focus_mode = Control.FOCUS_NONE
	zurueck_knopf.set_meta(&"nicht_zuerst", true)
	zurueck_knopf.pressed.connect(_verlassen)
	kopf.add_child(zurueck_knopf)

	# Namensschild unten in der Mitte — nur sichtbar vor einem Gebäude.
	_schild = Button.new()
	_schild.focus_mode = Control.FOCUS_NONE
	_schild.custom_minimum_size = Vector2(280, 64)
	_schild.add_theme_font_size_override("font_size", 18)
	_schild.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_schild.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_schild.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_schild.offset_bottom = -Bildschirm.RAND * 2
	_schild.visible = false
	_schild.pressed.connect(func() -> void: _betreten(_nah))
	add_child(_schild)

	var esc := Bildschirm.EscWaechter.new()
	esc.aktion = _verlassen
	add_child(esc)


## Name eines Ortes fürs Schild; beim Händler mit abgebbaren Belohnungen.
static func ort_name(id: StringName) -> String:
	match id:
		&"taverne":
			return Loc.pick("Taverne", "Tavern")
		&"haendler":
			var abholbar := GameState.abholbar_anzahl()
			var text := Loc.pick("Händler & Alchemist", "Merchant & alchemist")
			if abholbar > 0:
				text += Loc.pick(" (%d abgebbar)", " (%d to claim)") % abholbar
			return text
		&"schmiede":
			return Loc.pick("Schmiede", "Smithy")
	return Loc.pick("Ausgang", "Exit")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var punkt: Variant = _kulisse.boden_punkt((event as InputEventMouseButton).position)
		if punkt != null:
			_klick_ziel = _klick_ziel_fuer(punkt)
		return
	if event.is_action_pressed(&"interact") and not event.is_echo() and not _nah.is_empty():
		get_viewport().set_input_as_handled()
		_betreten(_nah)


## Klick auf ein Gebäude (oder nah davor) führt vor seine Tür, sonst zur
## angeklickten Stelle (am Platzrand begrenzt).
func _klick_ziel_fuer(punkt: Vector2) -> Vector2:
	for id in StadtKulisse.ORTE:
		var o: Dictionary = StadtKulisse.ORTE[id]
		var lokal := (punkt - (o["pos"] as Vector2)).rotated(deg_to_rad(float(o["dreh"])))
		var halb: Vector2 = o["halb"]
		if absf(lokal.x) < halb.x + 0.6 and absf(lokal.y) < halb.y + 0.6 \
				or punkt.distance_to(StadtKulisse.tuer(id)) < NAH:
			return StadtKulisse.tuer(id)
	return punkt.limit_length(LAUF_RADIUS)


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed(&"move_left") or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_action_pressed(&"move_right") or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_action_pressed(&"move_up") or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_action_pressed(&"move_down") or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	laufen(dir, delta)


## Ein Schritt: Tastatur-Richtung (Bildschirm = Platz, die Kamera schaut
## fest nach Norden) oder, ohne Taste, zum Klickziel. Achsen getrennt wie
## im Dungeon, damit man an Hauswänden entlanggleitet.
func laufen(dir: Vector2, delta: float) -> void:
	var weite := TEMPO * delta
	if dir != Vector2.ZERO:
		_klick_ziel = null
	elif _klick_ziel != null:
		dir = (_klick_ziel as Vector2) - held_pos
		weite = minf(weite, dir.length())
		if dir.length() < 0.05:
			_klick_ziel = null
			dir = Vector2.ZERO
	if dir != Vector2.ZERO:
		var schritt := dir.normalized() * weite
		var vorher := held_pos
		if frei(held_pos + Vector2(schritt.x, 0)):
			held_pos.x += schritt.x
		if frei(held_pos + Vector2(0, schritt.y)):
			held_pos.y += schritt.y
		if held_pos.distance_squared_to(vorher) < 0.0000001:
			_klick_ziel = null  # festgelaufen
	_kulisse.held_pos = held_pos
	_nah_pruefen()


## Darf der Held hier stehen? Platzrand, Brunnen und Gebäude-Grundflächen.
static func frei(p: Vector2) -> bool:
	if p.length() > LAUF_RADIUS:
		return false
	if p.distance_to(StadtKulisse.BRUNNEN) < StadtKulisse.BRUNNEN_RADIUS + HALB:
		return false
	for id in StadtKulisse.ORTE:
		var o: Dictionary = StadtKulisse.ORTE[id]
		if not o["fest"]:
			continue
		var lokal := (p - (o["pos"] as Vector2)).rotated(deg_to_rad(float(o["dreh"])))
		var halb: Vector2 = o["halb"]
		if absf(lokal.x) < halb.x + HALB and absf(lokal.y) < halb.y + HALB:
			return false
	return true


## Nächster Ort, vor dessen Tür der Held steht → Schild zeigen.
func _nah_pruefen() -> void:
	var bester: StringName = &""
	var abstand := NAH
	for id in StadtKulisse.ORTE:
		var d := held_pos.distance_to(StadtKulisse.tuer(id))
		if d < abstand:
			abstand = d
			bester = id
	if bester == _nah:
		return
	_nah = bester
	_schild.visible = not _nah.is_empty()
	if _schild.visible:
		var taste := Settings.key_name(&"interact")
		var aktion := Loc.pick("Verlassen", "Leave") if _nah == &"ausgang" else Loc.pick("Betreten", "Enter")
		_schild.text = "%s\n[%s] %s" % [ort_name(_nah), taste, aktion]


func _betreten(id: StringName) -> void:
	if id.is_empty() or _verlassen_laeuft:
		return
	if id == &"ausgang":
		_verlassen()
		return
	_verlassen_laeuft = true
	get_tree().change_scene_to_file(ZIELE[id])


func _verlassen() -> void:
	if _verlassen_laeuft:
		return
	_verlassen_laeuft = true
	get_tree().change_scene_to_file(MAIN_SCENE)
