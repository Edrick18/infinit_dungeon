class_name PortraitStudio
extends Node
## Rendert 3D-Figuren EINMAL in kleine Texturen (Zugleiste, Party-Porträts,
## Mini-Icons). Jede Figur bekommt eine eigene SubViewport-Welt, die genau
## ein Bild rendert und danach ruht — die ViewportTexture bleibt gültig,
## solange das Studio lebt (es hängt an der jeweiligen Szene).

const GROESSE := 128

var _cache: Dictionary = {}  ## Schlüssel » ViewportTexture


func textur(schluessel: String, bauen: Callable) -> Texture2D:
	if _cache.has(schluessel):
		return _cache[schluessel]
	var vp := SubViewport.new()
	vp.size = Vector2i(GROESSE, GROESSE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)

	var welt := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.42, 0.68)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	welt.environment = env
	vp.add_child(welt)
	var licht := DirectionalLight3D.new()
	licht.rotation_degrees = Vector3(-40, 35, 0)
	licht.light_energy = 0.9
	vp.add_child(licht)

	var figur: Node3D = bauen.call()
	vp.add_child(figur)
	var box := _umriss(figur)
	var mitte := box.get_center()
	var kamera := Camera3D.new()
	kamera.projection = Camera3D.PROJECTION_ORTHOGONAL
	kamera.size = maxf(box.size.y, box.size.x) * 1.12
	vp.add_child(kamera)
	kamera.look_at_from_position(mitte + Vector3(1.2, 0.7, 4.0), mitte)

	var tex := vp.get_texture()
	_cache[schluessel] = tex
	return tex


## Umhüllende aller Meshes einer Figur in Weltkoordinaten.
static func _umriss(figur: Node3D) -> AABB:
	var box := AABB()
	var erste := true
	for mi in figur.find_children("*", "MeshInstance3D", true, false):
		var teil: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		box = teil if erste else box.merge(teil)
		erste = false
	if erste:
		return AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1, 1))
	return box
