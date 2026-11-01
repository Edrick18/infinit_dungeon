class_name FigurenVorschau
extends SubViewportContainer
## Langsam drehende 3D-Vorschau einer Figur auf einem kleinen Podest
## (Inventar, Taverne, Heldenerstellung). Eigene Welt, durchsichtiger
## Hintergrund — fügt sich in jede UI ein. Licht wie die Porträts
## (PortraitStudio.licht_aufbauen, Filmic); die Kamera rahmt die Figur nach
## ihrer Höhe (hohe Hüte werden nicht abgeschnitten), Start in 3/4-Ansicht.

const DREHTEMPO := 0.6

var _vp: SubViewport
var _halter: Node3D
var _kamera: Camera3D
var _figur: Node3D
var _zeit := 0.0


func _init(groesse := Vector2i(170, 210)) -> void:
	stretch = true
	custom_minimum_size = Vector2(groesse)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.size = groesse
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
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


## Neue Figur zeigen (die alte wird freigegeben, die Drehung läuft weiter).
func zeige(figur: Node3D) -> void:
	if _figur != null and is_instance_valid(_figur):
		_figur.queue_free()
	_figur = figur
	_halter.add_child(figur)
	_rahmen(FigurenBau.umriss_lokal(figur).end.y)


func _process(delta: float) -> void:
	_halter.rotation.y += delta * DREHTEMPO
	_zeit += delta
	# Gliederpuppen (STIL-3D.md 7g) atmen und wippen im Idle.
	if _figur != null and is_instance_valid(_figur) and _figur.has_meta("glieder"):
		var wurzel := Gliederpuppe.beleben(_figur, _zeit)
		_figur.rotation.x = wurzel.x
		_figur.rotation.z = wurzel.z
