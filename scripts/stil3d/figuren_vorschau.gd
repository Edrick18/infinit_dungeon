class_name FigurenVorschau
extends SubViewportContainer
## Langsam drehende 3D-Vorschau einer Figur auf einem kleinen Podest
## (Inventar, Taverne, Heldenerstellung). Eigene Welt, durchsichtiger
## Hintergrund — fügt sich in jede UI ein.

const DREHTEMPO := 0.6

var _vp: SubViewport
var _halter: Node3D
var _figur: Node3D


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

	var welt := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.42, 0.68)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	welt.environment = env
	_vp.add_child(welt)
	var licht := DirectionalLight3D.new()
	licht.rotation_degrees = Vector3(-40, 35, 0)
	licht.light_energy = 0.9
	_vp.add_child(licht)

	Stil3D.teil(_vp_wurzel(), Stil3D.zylinder(0.55, 0.6, 0.12), Stil3D.farbe("stein_dunkel"),
		Vector3(0, -0.06, 0))
	_halter = Node3D.new()
	_vp.add_child(_halter)

	var kamera := Camera3D.new()
	kamera.projection = Camera3D.PROJECTION_ORTHOGONAL
	kamera.size = 1.85
	_vp.add_child(kamera)
	# Ohne Szenenbaum kein look_at — Blickrichtung direkt als Basis setzen.
	var pos := Vector3(0, 1.6, 3.9)
	var ziel := Vector3(0, 0.6, 0)
	kamera.transform = Transform3D(Basis.looking_at(ziel - pos, Vector3.UP), pos)


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


func _process(delta: float) -> void:
	_halter.rotation.y += delta * DREHTEMPO
