class_name PortraitStudio
extends Node
## Rendert 3D-Figuren EINMAL in kleine Texturen (Zugleiste, Party-Porträts,
## Mini-Icons). Jede Figur bekommt eine eigene SubViewport-Welt, die genau
## ein Bild rendert; danach wird das Bild in eine ImageTexture kopiert und
## der Viewport samt Figur freigegeben (STIL-3D.md 7h) — die zurückgegebene
## Textur bleibt dieselbe, sie füllt sich nur ein, zwei Bilder später.
##
## Figuren (Meta "anker_kopf") stehen in 3/4-Ansicht vor einer runden
## Hintergrundscheibe; Zweibeiner (Meta "brust_y") als Brustbild ab
## Gürtelhöhe, alle anderen ganz. Licht für Porträts und FigurenVorschau
## kommt aus licht_aufbauen() (Filmic, Führungs- und Kantenlicht).

const GROESSE := 128
## Drehung der Figur im Porträt (3/4-Ansicht, Blick leicht nach links).
const DREHUNG_GRAD := -24.0

var _cache: Dictionary = {}  ## Schlüssel » ImageTexture
var _offen: Array[Dictionary] = []  ## {vp, tex, bild} — warten auf ihr Bild


func _ready() -> void:
	set_process(not _offen.is_empty())


func textur(schluessel: String, bauen: Callable) -> Texture2D:
	if _cache.has(schluessel):
		return _cache[schluessel]
	var tex := ImageTexture.create_from_image(Image.create(GROESSE, GROESSE, false, Image.FORMAT_RGBA8))
	_cache[schluessel] = tex
	var figur: Node3D = bauen.call()
	if DisplayServer.get_name() == "headless":
		figur.free()  # ohne Renderer kein Bild — die Figur wurde trotzdem gebaut
		return tex
	var vp := SubViewport.new()
	vp.size = Vector2i(GROESSE, GROESSE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	licht_aufbauen(vp)
	vp.add_child(figur)
	_einrahmen(vp, figur)
	_offen.append({"vp": vp, "tex": tex, "bild": Engine.get_frames_drawn()})
	set_process(true)
	return tex


## Fertig gerenderte Porträts in ihre Textur kopieren, Viewport freigeben.
func _process(_delta: float) -> void:
	var i := 0
	while i < _offen.size():
		var e: Dictionary = _offen[i]
		if Engine.get_frames_drawn() < int(e["bild"]) + 2:
			i += 1
			continue
		var vp: SubViewport = e["vp"]
		var bild := vp.get_texture().get_image()
		if bild != null and not bild.is_empty():
			bild.convert(Image.FORMAT_RGBA8)
			(e["tex"] as ImageTexture).update(bild)
		vp.queue_free()
		_offen.remove_at(i)
	if _offen.is_empty():
		set_process(false)


## Gemeinsames Licht für Porträts und FigurenVorschau: Filmic wie die
## 3D-Welten (ohne Glow, der Hintergrund bleibt durchsichtig), warmes
## Führungslicht von vorn-oben, kühles Kantenlicht von hinten.
static func licht_aufbauen(eltern: Node) -> void:
	var welt := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	Stil3D.umgebung(env, Color(0.46, 0.42, 0.68), 0.55)
	env.glow_enabled = false
	welt.environment = env
	eltern.add_child(welt)
	var licht := DirectionalLight3D.new()
	licht.rotation_degrees = Vector3(-38, 28, 0)
	licht.light_color = Color(1.0, 0.95, 0.86)
	licht.light_energy = 1.0
	eltern.add_child(licht)
	var kante := DirectionalLight3D.new()
	kante.rotation_degrees = Vector3(-18, 155, 0)
	kante.light_color = Color(0.7, 0.8, 1.0)
	kante.light_energy = 0.55
	eltern.add_child(kante)


## Kamera und Hintergrundscheibe: Figuren in 3/4-Ansicht (Brustbild bei
## Zweibeinern), Gegenstände und Bausteine wie bisher ganz.
func _einrahmen(vp: SubViewport, figur: Node3D) -> void:
	var ist_figur := figur.has_meta("anker_kopf")
	if ist_figur:
		figur.rotation_degrees.y = DREHUNG_GRAD
	var box := _umriss(figur)
	var mitte := box.get_center()
	var hoehe := maxf(box.size.y, box.size.x)
	if ist_figur:
		var kopf := FigurenBau.anker(figur, "anker_kopf")
		var kopf_welt := (kopf[0] as Node3D).global_transform * (kopf[1] as Vector3)
		var unten := box.position.y
		if figur.has_meta("brust_y"):
			unten = maxf(unten, float(figur.get_meta("brust_y")))
		# Oben bis knapp über den Scheitel-Anker (Hut, Helm, Krone) — lange
		# Stäbe, Sensen und Keulen ragen hinaus, der Kopf bleibt groß.
		var g := maxf(1.0, float(figur.get_meta("groesse", 1.0)))
		var oben := minf(box.end.y, kopf_welt.y + 0.12 * g)
		hoehe = maxf(oben - unten, 0.5)
		mitte = Vector3(lerpf(mitte.x, kopf_welt.x, 0.6), (oben + unten) * 0.5, kopf_welt.z)
		if not figur.has_meta("brust_y"):
			hoehe = maxf(hoehe, box.size.x * 0.9)
	var kamera := Camera3D.new()
	kamera.projection = Camera3D.PROJECTION_ORTHOGONAL
	kamera.size = hoehe * (1.1 if ist_figur else 1.12)
	kamera.far = 60.0
	vp.add_child(kamera)
	var blick := Vector3(0, 0.35, 4.0) if ist_figur else Vector3(1.2, 0.7, 4.0)
	kamera.look_at_from_position(mitte + blick, mitte)
	if ist_figur:
		_scheibe(vp, mitte - blick.normalized() * 2.5, blick, kamera.size * 0.47)


static var _scheiben_mat: Array[StandardMaterial3D] = []


## Runde Hintergrundscheibe hinter der Figur (dunkel mit Messingrand); die
## beiden Materialien gelten für alle Porträts (einmal angelegt).
static func _scheibe(vp: Node, ort: Vector3, blick: Vector3, r: float) -> void:
	var basis := Basis.looking_at(-blick, Vector3.UP) * Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	if _scheiben_mat.is_empty():
		for farbe in [Stil3D.farbe("messing") * 0.7, Stil3D.farbe("nacht").lightened(0.1)]:
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = farbe
			_scheiben_mat.append(mat)
	for teil in [[r, _scheiben_mat[0], 0.0], [r * 0.93, _scheiben_mat[1], 0.02]]:
		var mi := MeshInstance3D.new()
		mi.mesh = Stil3D.zylinder(teil[0], teil[0], 0.01, 40)
		mi.material_override = teil[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = Transform3D(basis, ort + blick.normalized() * float(teil[2]))
		vp.add_child(mi)


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
