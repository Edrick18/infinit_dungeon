class_name FigurenVorschau
extends SubViewportContainer
## Ruhige 3D-Vorschau einer Figur auf einem kleinen Podest (Inventar,
## Taverne, Heldenerstellung). Eigene Welt, durchsichtiger Hintergrund —
## fügt sich in jede UI ein. Licht wie die Porträts
## (PortraitStudio.licht_aufbauen, Filmic); die Kamera rahmt die Figur nach
## ihrer Höhe (hohe Hüte werden nicht abgeschnitten).
## Keine Selbstdrehung mehr (Spieltest: „fühlt sich schnell unruhig an“):
## die Figur steht in der 3/4-Ansicht der Porträts und dreht sich nur, wenn
## der Spieler es will — Maus links/rechts ziehen oder Komma / Punkt halten
## (TASTE_LINKS/TASTE_RECHTS; nicht in Textfeldern, E bleibt Bestätigen).
## Gedrosselt wie die MenueKulisse: höchstens BILDRATE Bilder pro Sekunde.

const BILDRATE := 30.0
## Grad je Pixel Mausweg und Grad je Sekunde bei gehaltener Taste.
const ZIEH_GRAD := 0.6
const TASTEN_GRAD := 150.0
const TASTE_LINKS := KEY_COMMA
const TASTE_RECHTS := KEY_PERIOD

var _vp: SubViewport
var _halter: Node3D
var _kamera: Camera3D
var _figur: Node3D
var _zeit := 0.0
var _takt := 0.0
var _zieht := false


func _init(groesse := Vector2i(170, 210)) -> void:
	stretch = true
	custom_minimum_size = Vector2(groesse)
	# Fängt die Maus nur zum Drehen; Klicks auf die Figur tun sonst nichts.
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HSIZE
	tooltip_text = Loc.pick("Ziehen oder Komma / Punkt halten: Figur drehen",
		"Drag or hold comma / period: turn the figure")
	_vp = SubViewport.new()
	_vp.size = groesse
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)

	PortraitStudio.licht_aufbauen(_vp)

	Stil3D.teil(_vp_wurzel(), Stil3D.zylinder(0.55, 0.6, 0.12), Stil3D.farbe("stein_dunkel"),
		Vector3(0, -0.06, 0))
	_halter = Node3D.new()
	_halter.rotation_degrees.y = PortraitStudio.DREHUNG_GRAD
	_vp.add_child(_halter)

	_kamera = Camera3D.new()
	_kamera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_vp.add_child(_kamera)
	_rahmen(1.2)


## Kamera auf die Figurhöhe einstellen (Ohne Szenenbaum kein look_at —
## Blickrichtung direkt als Basis).
func _rahmen(hoehe: float) -> void:
	_kamera.size = maxf(1.85, hoehe * 1.3)
	var ziel := Vector3(0, maxf(0.6, hoehe * 0.5), 0)
	var pos := ziel + Vector3(0, 1.0, 3.9)
	_kamera.transform = Transform3D(Basis.looking_at(ziel - pos, Vector3.UP), pos)


func _vp_wurzel() -> Node3D:
	var n := Node3D.new()
	_vp.add_child(n)
	return n


## Neue Figur zeigen (die alte wird freigegeben, der Blickwinkel bleibt).
func zeige(figur: Node3D) -> void:
	if _figur != null and is_instance_valid(_figur):
		_figur.queue_free()
	_figur = figur
	_halter.add_child(figur)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_rahmen(FigurenBau.umriss_lokal(figur).end.y)


## Aktueller Blickwinkel in Grad (Selbsttest).
func drehung_grad() -> float:
	return _halter.rotation_degrees.y


## Um grad weiterdrehen (Maus, Tasten).
func drehen(grad: float) -> void:
	_halter.rotation_degrees.y = wrapf(_halter.rotation_degrees.y + grad, -180.0, 180.0)


## Maus: gedrückt halten und links/rechts ziehen. Die Maus bleibt beim
## Ziehen über den Rand hinaus an der Vorschau (Godot hält den Klick fest).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_zieht = event.pressed
		accept_event()
	elif event is InputEventMouseMotion and _zieht:
		drehen(event.relative.x * ZIEH_GRAD)
		accept_event()


## Tastatur: Komma/Punkt halten dreht — nicht, solange ein Textfeld tippt
## (Heldenname in Taverne und Heldenerstellung).
func _tasten_richtung() -> float:
	if not is_visible_in_tree():
		return 0.0
	var fokus := get_viewport().gui_get_focus_owner()
	if fokus is LineEdit or fokus is TextEdit:
		return 0.0
	return float(Input.is_physical_key_pressed(TASTE_RECHTS)) - float(Input.is_physical_key_pressed(TASTE_LINKS))


func _process(delta: float) -> void:
	var richtung := _tasten_richtung()
	if richtung != 0.0:
		drehen(richtung * TASTEN_GRAD * delta)
	_zeit += delta
	_takt += delta
	if not Stil3D.bild_faellig(_takt, BILDRATE):
		return
	_takt = fmod(_takt, 1.0 / BILDRATE)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	# Gliederpuppen (STIL-3D.md 7g) atmen und wippen im Idle.
	if _figur != null and is_instance_valid(_figur) and _figur.has_meta("glieder"):
		var wurzel := Gliederpuppe.beleben(_figur, _zeit)
		_figur.rotation.x = wurzel.x
		_figur.rotation.z = wurzel.z
