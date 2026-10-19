extends Node
## Autoload "Fokus": Sicherheitsnetz für die Tastatursteuerung (Spieltest
## 2026-10-19: „nicht alle Popups sind mit WASD steuerbar“). Hat kein Element
## den Fokus — etwa weil der gedrückte Knopf beim Neuaufbau einer Liste
## verschwand oder ein Fenster keinen Fokus setzt — und wird eine Menütaste
## gedrückt (WASD/Pfeile, Enter/Leertaste/E, Tab), springt der Fokus auf den
## ersten Knopf des obersten Fensters. Der Tastendruck selbst wird dabei
## verbraucht, damit nichts versehentlich ausgelöst wird.
##
## Im Dungeon (Laufen mit WASD) bleibt das Netz aus — dort setzen die
## Fenster (Hinweise, Abstimmung, Abschluss) ihren Fokus selbst.

const MENUE_AKTIONEN: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right",
	&"ui_accept", &"ui_focus_next", &"ui_focus_prev"]


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var viewport := get_viewport()
	if viewport.gui_get_focus_owner() != null:
		return
	var treffer := false
	for aktion in MENUE_AKTIONEN:
		if InputMap.has_action(aktion) and event.is_action_pressed(aktion):
			treffer = true
			break
	if not treffer or _im_dungeon():
		return
	var knopf := bester_knopf(get_tree().root)
	if knopf != null:
		knopf.grab_focus()
		viewport.set_input_as_handled()


func _im_dungeon() -> bool:
	var szene := get_tree().current_scene
	if szene == null:
		return false
	return szene.scene_file_path.ends_with("dungeon_scene.tscn") \
		or (szene.get_script() != null and String(szene.get_script().resource_path).ends_with("dungeon_scene.gd"))


## Erster bedienbarer Knopf im obersten Fenster: höchste CanvasLayer-Ebene,
## darin der zuletzt eingehängte Zweig (Popups kommen nach ihrem Bildschirm).
static func bester_knopf(wurzel: Node, auch_gesperrte := false) -> BaseButton:
	var gefunden := _suche(wurzel, auch_gesperrte)
	if gefunden == null and not auch_gesperrte:
		gefunden = _suche(wurzel, true)  # nur „Zurück“ da? Dann eben der.
	return gefunden


static func _suche(wurzel: Node, auch_gesperrte: bool) -> BaseButton:
	var bester: BaseButton = null
	var bester_rang := [-INF, -1]
	for knoten in wurzel.find_children("*", "BaseButton", true, false):
		var knopf := knoten as BaseButton
		if knopf.disabled or not knopf.is_visible_in_tree() or knopf.focus_mode == Control.FOCUS_NONE:
			continue
		if not auch_gesperrte and _gesperrt(knopf):
			continue
		var rang := _rang(knopf)
		# Höhere Ebene bzw. späterer Zweig gewinnt; innerhalb eines Zweigs der erste.
		if rang[0] > bester_rang[0] or (rang[0] == bester_rang[0] and rang[1] > bester_rang[1]):
			bester = knopf
			bester_rang = rang
	return bester


## Kopfzeile/Zurück-Knöpfe (Meta „nicht_zuerst“) nie als Start-Fokus.
static func _gesperrt(knoten: Node) -> bool:
	var k := knoten
	while k != null:
		if k.has_meta(&"nicht_zuerst"):
			return true
		k = k.get_parent()
	return false


## [CanvasLayer-Ebene, Position des obersten Zweigs unter seiner Ebene/Szene].
static func _rang(knopf: Control) -> Array:
	var ebene := 0.0
	var layer := knopf.get_canvas_layer_node()
	if layer != null:
		ebene = layer.layer
	# Zweig: Vorfahre direkt unter der Ebene (oder unter der aktuellen Szene).
	var zweig: Node = knopf
	var oben: Node = layer if layer != null else knopf.get_tree().current_scene
	while zweig.get_parent() != null and zweig.get_parent() != oben and zweig.get_parent() != knopf.get_tree().root:
		zweig = zweig.get_parent()
	return [ebene, zweig.get_index()]
