class_name PortraitStudio
extends Node
## Rendert 3D-Figuren EINMAL in kleine Texturen (Zugleiste, Party-Porträts,
## Mini-Icons). Jede Figur bekommt eine eigene SubViewport-Welt, die genau
## ein Bild rendert; danach wird das Bild in eine ImageTexture kopiert und
## der Viewport samt Figur freigegeben (STIL-3D.md 7h) — die zurückgegebene
## Textur bleibt dieselbe, sie füllt sich nur ein paar Bilder später.
##
## Verteilt auf mehrere Bilder (Taverne: 17 Farben + Helden, Zugleiste,
## Inventar-Icons): textur() baut die Figur gleich (meist im Szenenaufbau,
## Meshes aus dem Cache der Gliederpuppe), reiht sie aber nur ein; je Bild
## rendert _process höchstens NEU_JE_BILD neue Viewports und liest höchstens
## AUSLESEN_JE_BILD fertige Bilder aus (get_image() wartet auf die GPU).
## Vorher renderte und las ein Bild alle auf einmal.
##
## Figuren (Meta "anker_kopf") stehen in 3/4-Ansicht vor einer runden
## Hintergrundscheibe; Zweibeiner (Meta "brust_y") als Brustbild ab
## Gürtelhöhe, alle anderen ganz. Licht für Porträts und FigurenVorschau
## kommt aus licht_aufbauen() (Filmic, Führungs- und Kantenlicht).
## Gegenstände, Klötze, Tränke, Materialien und Biome (keine Figur) bekommen
## zusätzlich ein kühles Randlicht von hinten oben — die Silhouette löst sich
## vom Seltenheits-Hintergrund der Kachel; Meta "icon_blick" am Knoten setzt
## eine eigene Blickrichtung (Biom-Miniaturen schauen von schräg oben).

const GROESSE := 128
## Drehung der Figur im Porträt (3/4-Ansicht, Blick leicht nach links).
const DREHUNG_GRAD := -24.0

## Je Bild höchstens so viele neue Porträt-Viewports und so viele
## Auslesungen fertiger Bilder.
const NEU_JE_BILD := 4
const AUSLESEN_JE_BILD := 4

## Szenenübergreifender Zwischenspeicher (Rest Paket 5): Gegenstände,
## Klötze, Tränke, Materialien, Biome und Symbole (Gold, Medaille,
## Schatzkarte) sehen in jeder Szene gleich aus —
## einmal fertig gerendert, liegen sie für den nächsten Besuch bereit (jede
## Szene hat ihr eigenes Studio; Händler, Kartenlager und Inventar bauten
## sonst bei jedem Öffnen alle Icons neu). Figuren-Porträts nicht (Farbe und
## Ausrüstung ändern sich). Höchstens GETEILT_MAX Bilder (128² RGBA ≈ 64 KB,
## zusammen ≤ 16 MB); darüber fällt das am längsten unbenutzte heraus.
const GETEILT_PRAEFIXE: Array[String] = ["item|", "klotz|", "trank|", "material|", "biom|", "symbol|"]
const GETEILT_MAX := 256
## Item-Icons (Ausrüstung, Tränke, Materialien, Biome, Symbole) erscheinen stark
## verkleinert (58/40/36/32/26 px aus 128): ihr Bild bekommt einmalig
## Mipmaps, die Anzeige filtert sie weich (UiHolz.ICON_FILTER) — keine
## Treppen, keine abreißenden dünnen Linien (Sehne, Kette, Stabschaft).
## Mit Mipmaps belegt ein Icon ≈ 85 statt 64 KB (256 Icons ≤ 22 MB).
const MIPMAP_PRAEFIXE: Array[String] = ["item|", "trank|", "material|", "biom|", "symbol|"]
## Luft um Item-Icons (Bildgröße ÷ Ausdehnung im Kamerablick, Meta
## "icon_rand" am Wurzelknoten): nichts stößt an den Raritätsrahmen.
const ICON_RAND := 1.26
static var _geteilt: Dictionary = {}  ## Schlüssel » ImageTexture (fertig), älteste zuerst

## Figuren erst beim Rendern bauen statt in textur() (Sieg-Fenster mit
## vielen Beute-Icons: der Aufbau des Fensters bleibt so schnell wie ohne
## Icons, gebaut wird verteilt mit höchstens NEU_JE_BILD Figuren je Bild).
var bauen_verzoegern := false

var _cache: Dictionary = {}  ## Schlüssel » ImageTexture
var _warten: Array[Dictionary] = []  ## {tex, figur} — noch nicht im Viewport
var _offen: Array[Dictionary] = []  ## {vp, tex, bild} — warten auf ihr Bild


func _ready() -> void:
	set_process(not _offen.is_empty() or not _warten.is_empty())


func _exit_tree() -> void:
	for e in _warten:  # nie gerenderte Figuren hängen an keinem Baum
		if e.has("figur"):
			(e["figur"] as Node3D).free()
	_warten.clear()


func textur(schluessel: String, bauen: Callable) -> Texture2D:
	if _cache.has(schluessel):
		return _cache[schluessel]
	if _geteilt.has(schluessel):
		var fertig: ImageTexture = _geteilt[schluessel]
		_merken(schluessel, fertig)  # zuletzt benutzt » ans Ende
		_cache[schluessel] = fertig
		return fertig
	var tex := ImageTexture.create_from_image(Image.create(GROESSE, GROESSE, mit_mipmaps(schluessel),
		Image.FORMAT_RGBA8))
	_cache[schluessel] = tex
	if bauen_verzoegern and DisplayServer.get_name() != "headless":
		_warten.append({"tex": tex, "bauen": bauen, "schluessel": schluessel})
		set_process(true)
		return tex
	var figur: Node3D = bauen.call()
	if DisplayServer.get_name() == "headless":
		figur.free()  # ohne Renderer kein Bild — die Figur wurde trotzdem gebaut
		return tex
	_warten.append({"tex": tex, "figur": figur, "schluessel": schluessel})
	set_process(true)
	return tex


## Noch nicht gerenderte bzw. noch nicht ausgelesene Porträts (Dev).
func ausstehend() -> int:
	return _warten.size() + _offen.size()


func _rendern(e: Dictionary) -> void:
	var figur: Node3D = e["figur"] if e.has("figur") else (e["bauen"] as Callable).call()
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
	_offen.append({"vp": vp, "tex": e["tex"], "bild": Engine.get_frames_drawn(),
		"schluessel": e.get("schluessel", "")})


## Je Bild: ein paar fertig gerenderte Porträts in ihre Textur kopieren
## (Viewport freigeben), dann die nächsten wartenden rendern.
func _process(_delta: float) -> void:
	var gelesen := 0
	var i := 0
	while i < _offen.size() and gelesen < AUSLESEN_JE_BILD:
		var e: Dictionary = _offen[i]
		if Engine.get_frames_drawn() < int(e["bild"]) + 2:
			i += 1
			continue
		var vp: SubViewport = e["vp"]
		var bild := vp.get_texture().get_image()
		if bild != null and not bild.is_empty():
			bild.convert(Image.FORMAT_RGBA8)
			if mit_mipmaps(String(e["schluessel"])):
				bild.generate_mipmaps()  # einmal je Icon, danach aus dem Cache
			(e["tex"] as ImageTexture).update(bild)
			if ist_geteilt(String(e["schluessel"])):
				_merken(String(e["schluessel"]), e["tex"])
		vp.queue_free()
		_offen.remove_at(i)
		gelesen += 1
	for n in mini(NEU_JE_BILD, _warten.size()):
		_rendern(_warten.pop_front())
	if _offen.is_empty() and _warten.is_empty():
		set_process(false)


## Gehört der Schlüssel in den szenenübergreifenden Zwischenspeicher?
static func ist_geteilt(schluessel: String) -> bool:
	for praefix in GETEILT_PRAEFIXE:
		if schluessel.begins_with(praefix):
			return true
	return false


## Bekommt das Icon Mipmaps (stark verkleinert angezeigte Item-Icons)?
static func mit_mipmaps(schluessel: String) -> bool:
	for praefix in MIPMAP_PRAEFIXE:
		if schluessel.begins_with(praefix):
			return true
	return false


## Fertiges Icon merken (bzw. als zuletzt benutzt ans Ende rücken); über
## GETEILT_MAX fällt das älteste heraus. Nur fertig gerenderte Bilder kommen
## hinein — ein Studio, das vorher stirbt, hinterlässt keine leeren.
static func _merken(schluessel: String, tex: ImageTexture) -> void:
	_geteilt.erase(schluessel)
	_geteilt[schluessel] = tex
	while _geteilt.size() > GETEILT_MAX:
		_geteilt.erase(_geteilt.keys()[0])


## Anzahl der szenenübergreifend gemerkten Icons (Dev, Tests).
static func geteilt_anzahl() -> int:
	return _geteilt.size()


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
	if figur.has_meta("icon_blick"):
		blick = figur.get_meta("icon_blick")
	if figur.has_meta("icon_rand"):
		var rahmen := bild_rahmen(figur, blick)
		mitte = rahmen[0]
		kamera.size = float(rahmen[1]) * float(figur.get_meta("icon_rand"))
	kamera.look_at_from_position(mitte + blick, mitte)
	if ist_figur:
		_scheibe(vp, mitte - blick.normalized() * 2.5, blick, kamera.size * 0.47)
	else:
		vp.add_child(randlicht())


## Kühles Randlicht von links hinten für Icons (Gegenstände, Klötze,
## Vorräte): fast quer zum Blick (Kamera vorn rechts) — es trifft nur die
## linken und oberen Silhouettenkanten, die Vorderseite bleibt im Führungslicht.
const RANDLICHT_RICHTUNG := Vector3(0.85, -0.35, 0.4)


static func randlicht() -> DirectionalLight3D:
	var rand := DirectionalLight3D.new()
	rand.transform = Transform3D(Basis.looking_at(RANDLICHT_RICHTUNG, Vector3.UP), Vector3.ZERO)
	rand.light_color = Stil3D.farbe("stern")
	rand.light_energy = 1.5
	return rand


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


## Ausschnitt eines Item-Icons im Kamerablick (orthogonal, Blick aus
## Richtung blick): alle Meshes werden auf die Bildebene projiziert, statt
## die Welt-AABB zu nehmen — schräg in die Tiefe liegende Teile (Armbrust)
## ragen so nicht mehr aus dem Bild, und jedes Icon sitzt mittig. Gemessen
## werden die echten Eckpunkte (Prismen: sechs statt acht AABB-Ecken) samt
## der Kontur genau so, wie der Kontur-Shader sie aufbläht (Kästen und
## Prismen je Achse um die Dicke, an den Ecken also weiter als die Dicke;
## runde Teile entlang der Normale) — Teile ohne Kontur ohne Zuschlag.
## Liefert [Bildmitte in Welt, größere Seite der Ausdehnung inkl. Kontur,
## Ausdehnung als Vector2 (Breite, Höhe im Bild)].
static func bild_rahmen(figur: Node3D, blick: Vector3) -> Array:
	var basis := Basis.looking_at(-blick, Vector3.UP)
	var rechts := basis.x
	var oben := basis.y
	var vor := basis.z
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var tiefe := 0.0
	var anzahl := 0
	for knoten in figur.find_children("*", "MeshInstance3D", true, false):
		var mi := knoten as MeshInstance3D
		if mi.mesh == null:
			continue
		var t := mi.global_transform
		var kontur := _kontur_von(mi)
		for p in _mesh_punkte(mi.mesh, kontur[0], kontur[1]):
			var w: Vector3 = t * p
			var q := Vector2(w.dot(rechts), w.dot(oben))
			lo = lo.min(q)
			hi = hi.max(q)
			tiefe += w.dot(vor)
			anzahl += 1
	if anzahl == 0:
		return [Vector3.ZERO, 1.0, Vector2.ONE]
	var m := (lo + hi) * 0.5
	return [rechts * m.x + oben * m.y + vor * (tiefe / anzahl), maxf(hi.x - lo.x, hi.y - lo.y), hi - lo]


## Kontur eines Teils: [Dicke, Modus] aus dem Kontur-Pass (Stil3D.kontur:
## 0 = Normale, 1 = Kasten/Prisma, 2 = Zylinder); ohne Kontur [0, -1].
static func _kontur_von(mi: MeshInstance3D) -> Array:
	var mat := mi.material_override
	if mat == null and mi.mesh is PrimitiveMesh:
		mat = (mi.mesh as PrimitiveMesh).material
	var naechster: Material = mat.next_pass if mat != null else null
	if naechster is ShaderMaterial:
		var sm := naechster as ShaderMaterial
		var dicke: Variant = sm.get_shader_parameter("dicke")
		var modus: Variant = sm.get_shader_parameter("modus")
		if dicke != null and modus != null:
			return [float(dicke), int(modus)]
	return [0.0, -1]


## Umrisspunkte eines Grundkörpers (lokal) samt Kontur (Dicke, Modus wie
## der Kontur-Shader): Kugeln, Zylinder und Ringe als Kreise statt AABB-
## Ecken — sonst wären runde Icons (Ring, Tränke) zu klein; Kästen und
## Prismen mit ihren echten Ecken.
static func _mesh_punkte(mesh: Mesh, dicke := 0.0, modus := -1) -> PackedVector3Array:
	var punkte := PackedVector3Array()
	var kreis := func(r: float, y: float, ry := 0.0) -> void:
		for i in 16:
			var w := TAU * i / 16.0
			punkte.append(Vector3(cos(w) * r, y, sin(w) * r))
			if ry > 0.0:
				punkte.append(Vector3(cos(w) * r, y + ry, sin(w) * r))
				punkte.append(Vector3(cos(w) * r, y - ry, sin(w) * r))
	if mesh is SphereMesh:
		var k := mesh as SphereMesh
		var h := k.height * (1.0 if k.is_hemisphere else 0.5)
		var unten := 0.0 if k.is_hemisphere else -h
		for j in 7:  # Breitenkreise (Ellipsoid: Radius r, halbe Höhe h), Kontur entlang der Normale
			var v := lerpf(-PI * 0.5, PI * 0.5, j / 6.0)
			var y := sin(v) * h
			if y < unten - 0.0001:
				continue
			var r := cos(v) * k.radius
			var n := Vector2(r / maxf(k.radius * k.radius, 0.000001), y / maxf(h * h, 0.000001)).normalized()
			kreis.call(r + n.x * dicke, y + n.y * dicke)
		punkte.append(Vector3(0, h + dicke, 0))
		if k.is_hemisphere and dicke > 0.0:  # flacher Boden: Kontur nach unten
			kreis.call(k.radius + dicke, -dicke)
	elif mesh is CylinderMesh:
		var z := mesh as CylinderMesh
		kreis.call(z.top_radius + dicke, z.height * 0.5 + dicke)
		kreis.call(z.bottom_radius + dicke, -z.height * 0.5 - dicke)
	elif mesh is CapsuleMesh:
		var c := mesh as CapsuleMesh
		var h := c.height * 0.5 - c.radius
		var r := c.radius + dicke
		for j in 5:
			var v := lerpf(0.0, PI * 0.5, j / 4.0)
			kreis.call(cos(v) * r, h + sin(v) * r)
			kreis.call(cos(v) * r, -h - sin(v) * r)
	elif mesh is TorusMesh:
		var t := mesh as TorusMesh
		var rohr := (t.outer_radius - t.inner_radius) * 0.5
		kreis.call(t.outer_radius + dicke, 0.0, rohr + dicke)
	else:
		var ecken := PackedVector3Array()
		if mesh is PrismMesh:  # Dreiecksprisma: vier Bodenecken, zwei Firstecken
			var pr := mesh as PrismMesh
			var s := pr.size * 0.5
			var first := -s.x + pr.size.x * pr.left_to_right
			for z in [-s.z, s.z]:
				ecken.append(Vector3(-s.x, -s.y, z))
				ecken.append(Vector3(s.x, -s.y, z))
				ecken.append(Vector3(first, s.y, z))
		else:
			var a := mesh.get_aabb()
			for i in 8:
				ecken.append(a.get_endpoint(i))
		for e in ecken:
			if dicke <= 0.0:
				punkte.append(e)
			elif modus == 1 or not (mesh is PrimitiveMesh):  # Kontur je Achse wie sign(VERTEX)
				punkte.append(e + e.sign() * dicke)
			else:  # Normalen-Kontur an einer Ecke: höchstens Dicke weit, in jede Richtung
				punkte.append(e)
				for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
					punkte.append(e + d * dicke)
	return punkte


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
