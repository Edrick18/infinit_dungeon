class_name Bausatz
extends RefCounted
## Backt viele Grundkörper (STIL-3D.md Abschnitt 1) zu EINEM ArrayMesh mit
## Vertexfarben — dazu eine eigene Kontur-Hülle aus denselben, um die
## Konturdicke aufgeblähten Grundkörpern. Statt 15 MeshInstances mit je zwei
## Durchgängen (Toon + Kontur) kostet ein Objekt so zwei Zeichenaufrufe; als
## MultiMesh (Wandkronen, Deko) bleibt es bei zwei je Variante, egal wie oft.
##
## Farben stehen als sRGB in der Vertexfarbe — Godot wandelt COLOR selbst
## nach linear (Testbild 2026-11-01: vorab linearisiert wurde Holz rot),
## Vertex-Alpha < 1 heißt Leuchten (1 - Alpha = Stärke). Der
## Körper-Shader ist WeltMaterial "kulisse" (Toon-Licht, optional Screen-Door
## aus INSTANCE_CUSTOM.a), die Hülle Stil3D.kontur(0, dither) mit Dicke 0.

var _ecken := PackedVector3Array()
var _normalen := PackedVector3Array()
var _farben := PackedColorArray()
var _indizes := PackedInt32Array()
var _h_ecken := PackedVector3Array()
var _h_normalen := PackedVector3Array()
var _h_indizes := PackedInt32Array()

## Maßstab der Grundkörper (Figurengröße, Boss ×1.5): Maße und Positionen
## werden VOR dem Aufblähen der Hülle skaliert — die Kontur bleibt überall
## Stil3D.KONTUR_DICKE dick (keine Node-Skalierung nötig, STIL-3D.md 6).
var massstab := 1.0
## Sparsam (gebackene Figuren): kleine Kugeln, Kapseln und dünne Zylinder
## werden gröber unterteilt (Augen, Nieten, Zähne, Finger — Dreiecks-Budget).
var sparsam := false


## Ein Grundkörper an Position/Drehung (Grad); kontur = Teil der Hülle,
## leuchten 0..1 = Eigenleuchten in der eigenen Farbe (Flammen, Kristalle).
func teil(mesh: PrimitiveMesh, farbe: Color, pos: Vector3, rot_grad := Vector3.ZERO, kontur := true,
		leuchten := 0.0) -> Bausatz:
	return teil_t(mesh, farbe, Transform3D(Basis.from_euler(rot_grad * (PI / 180.0)), pos), kontur, leuchten)


## Wie teil(), aber mit vollständiger Lage (für Ketten, Waffen an der Hand,
## gekippte Kronen: Drehungen lassen sich so verketten).
func teil_t(mesh: PrimitiveMesh, farbe: Color, t: Transform3D, kontur := true, leuchten := 0.0) -> Bausatz:
	# Unterteilung nach den Figurmaßen (vor dem Maßstab): gleiche Figur =
	# gleiches Dreiecks-Budget, ob normal, Troll 1.4 oder Boss ×1.5.
	var m := _sparsam(mesh) if sparsam else mesh
	if not is_equal_approx(massstab, 1.0):
		m = skaliert(m, massstab)
		t.origin *= massstab
	var vertex := farbe
	vertex.a = 1.0 - clampf(leuchten, 0.0, 1.0)
	_anhaengen(m, t, false, vertex)
	if kontur:
		_anhaengen(aufgeblaeht(m, Stil3D.KONTUR_DICKE), t, true, Color.WHITE)
	return self


## Gefaste Box (WeltMaterial.fasen_box: die Kanten fangen Licht — Golem-
## Steinblöcke) mit Lage t in Figurmaßen; Maße und Lage × massstab, die Hülle
## ist eine um die Konturdicke größere BoxMesh (Kontur bleibt gleich dick).
func fasenbox(groesse: Vector3, fase: float, farbe: Color, t: Transform3D, kontur := true,
		leuchten := 0.0) -> Bausatz:
	var g := groesse * massstab
	t.origin *= massstab
	var vertex := farbe
	vertex.a = 1.0 - clampf(leuchten, 0.0, 1.0)
	_anhaengen(WeltMaterial.fasen_box(g, fase * massstab), t, false, vertex)
	if kontur:
		_anhaengen(Stil3D.box(g.x + Stil3D.KONTUR_DICKE * 2.0, g.y + Stil3D.KONTUR_DICKE * 2.0,
			g.z + Stil3D.KONTUR_DICKE * 2.0), t, true, Color.WHITE)
	return self


## Dünnes Dreieck (Flughaut, Flossen, Membranen) zwischen drei Punkten in
## Figurmaßen; dicke quer zur Fläche. Die Hülle ist das um die Konturdicke
## nach außen versetzte Dreieck (Inkreis-Skalierung) — gleich dicker Rand.
func dreieck(a: Vector3, b: Vector3, c: Vector3, dicke: float, farbe: Color, kontur := true,
		leuchten := 0.0) -> Bausatz:
	a *= massstab
	b *= massstab
	c *= massstab
	var vertex := farbe
	vertex.a = 1.0 - clampf(leuchten, 0.0, 1.0)
	_anhaengen(_dreieck_mesh(a, b, c, dicke * massstab), Transform3D(), false, vertex)
	if kontur:
		# Inkreis-Mittelpunkt i, Inkreisradius r: Ecken um (r + d) / r von i weg.
		var la := b.distance_to(c)
		var lb := a.distance_to(c)
		var lc := a.distance_to(b)
		var umfang := maxf(0.0001, la + lb + lc)
		var i := (a * la + b * lb + c * lc) / umfang
		var flaeche := (b - a).cross(c - a).length() * 0.5
		var r := maxf(0.0001, 2.0 * flaeche / umfang)
		var f := (r + Stil3D.KONTUR_DICKE) / r
		_anhaengen(_dreieck_mesh(i + (a - i) * f, i + (b - i) * f, i + (c - i) * f,
			dicke * massstab + Stil3D.KONTUR_DICKE * 2.0), Transform3D(), true, Color.WHITE)
	return self


## Halbzylinder (gewölbter Truhendeckel): Achse entlang X, Wölbung nach +Y,
## flache Unterseite bei y = 0; Lage t in Figurmaßen. Hülle = Halbzylinder
## mit r + Konturdicke, Länge + 2 × Konturdicke, Boden um die Dicke tiefer.
func halbzylinder(r: float, laenge: float, segmente: int, farbe: Color, t: Transform3D, kontur := true,
		leuchten := 0.0) -> Bausatz:
	t.origin *= massstab
	var vertex := farbe
	vertex.a = 1.0 - clampf(leuchten, 0.0, 1.0)
	_anhaengen(_halbzylinder_mesh(r * massstab, laenge * massstab, segmente, 0.0), t, false, vertex)
	if kontur:
		var d := Stil3D.KONTUR_DICKE
		_anhaengen(_halbzylinder_mesh(r * massstab + d, laenge * massstab + d * 2.0, segmente, d), t, true,
			Color.WHITE)
	return self


## Dreiecks-Prisma (Vorder-/Rückseite + drei Seiten), flache Normalen.
static func _dreieck_mesh(a: Vector3, b: Vector3, c: Vector3, dicke: float) -> ArrayMesh:
	var n := (b - a).cross(c - a).normalized() * dicke * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mitte := (a + b + c) / 3.0
	_flaeche(st, [a + n, b + n, c + n], mitte)
	_flaeche(st, [a - n, b - n, c - n], mitte)
	for paar in [[a, b], [b, c], [c, a]]:
		var p: Vector3 = paar[0]
		var q: Vector3 = paar[1]
		_flaeche(st, [p + n, q + n, q - n, p - n], mitte)
	return st.commit()


static func _halbzylinder_mesh(r: float, laenge: float, segmente: int, tiefer: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := laenge * 0.5
	var mitte := Vector3(0, r * 0.4, 0)
	var bogen: Array[Vector3] = []
	for i in segmente + 1:
		var w := PI * float(i) / segmente
		bogen.append(Vector3(0, sin(w) * r, cos(w) * r))
	bogen[0].y = -tiefer
	bogen[segmente].y = -tiefer
	for i in segmente:
		var p := bogen[i]
		var q := bogen[i + 1]
		var np := Vector3(0, maxf(0.0, p.y), p.z).normalized()
		var nq := Vector3(0, maxf(0.0, q.y), q.z).normalized()
		_flaeche(st, [p + Vector3(h, 0, 0), q + Vector3(h, 0, 0), q - Vector3(h, 0, 0), p - Vector3(h, 0, 0)],
			mitte, [np, nq, nq, np])
	_flaeche(st, [bogen[0] + Vector3(h, 0, 0), bogen[segmente] + Vector3(h, 0, 0),
		bogen[segmente] - Vector3(h, 0, 0), bogen[0] - Vector3(h, 0, 0)], mitte)
	for sx in [-1.0, 1.0]:
		var kappe: Array = []
		for p in bogen:
			kappe.append(p + Vector3(h * sx, 0, 0))
		_flaeche(st, kappe, mitte)
	return st.commit()


## Konvexe Fläche (Fächer) mit Normalen nach außen (weg von mitte); ohne
## normalen = flache Normale. Godot: Vorderseite im Uhrzeigersinn.
static func _flaeche(st: SurfaceTool, ecken: Array, mitte: Vector3, normalen: Array = []) -> void:
	var a: Vector3 = ecken[0]
	var flach := Vector3.ZERO
	for i in range(1, ecken.size() - 1):
		flach += ((ecken[i] as Vector3) - a).cross((ecken[i + 1] as Vector3) - a)
	var aussen := flach.dot(a - mitte) >= 0.0
	flach = flach.normalized() * (1.0 if aussen else -1.0)
	for i in range(1, ecken.size() - 1):
		var reihe := [0, i + 1, i] if aussen else [0, i, i + 1]
		for k in reihe:
			st.set_normal(normalen[k] if not normalen.is_empty() else flach)
			st.add_vertex(ecken[k])


## Kopie eines Grundkörpers mit allen Maßen × f (Kugel, Box, Zylinder,
## Kapsel, Prisma, Torus). Auch für FigurenBau.massstab_einbacken.
static func skaliert(mesh: PrimitiveMesh, f: float) -> PrimitiveMesh:
	var m: PrimitiveMesh = mesh.duplicate()
	if m is BoxMesh:
		(m as BoxMesh).size *= f
	elif m is SphereMesh:
		(m as SphereMesh).radius *= f
		(m as SphereMesh).height *= f
	elif m is CylinderMesh:
		var z := m as CylinderMesh
		z.top_radius *= f
		z.bottom_radius *= f
		z.height *= f
	elif m is CapsuleMesh:
		(m as CapsuleMesh).radius *= f
		(m as CapsuleMesh).height *= f
	elif m is PrismMesh:
		(m as PrismMesh).size *= f
	elif m is TorusMesh:
		(m as TorusMesh).inner_radius *= f
		(m as TorusMesh).outer_radius *= f
	return m


## Gröbere Unterteilung (sparsam, gebackene Figuren): je Radius gestaffelt —
## Kleinteile (Glanz, Nieten, Zähne) 6–8 Segmente, mittlere 10–12, große
## Rumpfkugeln 14. Mit Toon-Stufen und Kontur nicht zu sehen, hält aber das
## Dreiecks-Budget je Figur (Körper + Hülle: Gegner ≤ 6000, STIL-3D.md 7g).
## Nur Standard-Unterteilungen (Stil3D: Kugel 24, Kapsel/Zylinder 20) werden
## vergröbert — ein ausdrücklich gewählter Wert (Augen) bleibt.
static func _sparsam(mesh: PrimitiveMesh) -> PrimitiveMesh:
	if mesh is SphereMesh:
		var k := mesh as SphereMesh
		var seg := 6 if k.radius < 0.045 else (8 if k.radius < 0.1 else (10 if k.radius < 0.2 else 12))
		if k.radial_segments == 24 and k.radial_segments > seg:  # nur Standard-Unterteilung
			k = k.duplicate()
			k.radial_segments = seg
			k.rings = maxi(3, seg / 2)
		return k
	if mesh is CapsuleMesh:
		var c := mesh as CapsuleMesh
		var seg := 6 if c.radius < 0.04 else (8 if c.radius < 0.09 else (10 if c.radius < 0.15 else 12))
		if c.radial_segments == 20 and c.radial_segments > seg:
			c = c.duplicate()
			c.radial_segments = seg
			c.rings = 1 if seg <= 6 else 2
		return c
	if mesh is CylinderMesh:
		var z := mesh as CylinderMesh
		var r := maxf(z.top_radius, z.bottom_radius)
		var seg := 8 if r < 0.05 else (10 if r < 0.15 else 14)
		if z.radial_segments == 20 and z.radial_segments > seg:
			z = z.duplicate()
			z.radial_segments = seg
		return z
	if mesh is TorusMesh:
		var t := mesh as TorusMesh
		if t.rings > 40 or t.ring_segments > 8:
			t = t.duplicate()
			t.rings = mini(t.rings, 40)
			t.ring_segments = mini(t.ring_segments, 8)
		return t
	return mesh


## Einen anderen Bausatz (z. B. eine Gruppe) versetzt übernehmen.
func bausatz(anderer: Bausatz, t: Transform3D) -> Bausatz:
	var basis_n := t.basis.inverse().transposed()
	var start := _ecken.size()
	for i in anderer._ecken.size():
		_ecken.append(t * anderer._ecken[i])
		_normalen.append((basis_n * anderer._normalen[i]).normalized())
		_farben.append(anderer._farben[i])
	for i in anderer._indizes:
		_indizes.append(start + i)
	start = _h_ecken.size()
	for i in anderer._h_ecken.size():
		_h_ecken.append(t * anderer._h_ecken[i])
		_h_normalen.append((basis_n * anderer._h_normalen[i]).normalized())
	for i in anderer._h_indizes:
		_h_indizes.append(start + i)
	return self


func ist_leer() -> bool:
	return _ecken.is_empty()


func hat_huelle() -> bool:
	return not _h_ecken.is_empty()


func dreiecke() -> int:
	return (_indizes.size() + _h_indizes.size()) / 3


## Körper als ArrayMesh (Vertexfarben, Alpha = 1 - Leuchten).
func mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _ecken
	arrays[Mesh.ARRAY_NORMAL] = _normalen
	arrays[Mesh.ARRAY_COLOR] = _farben
	arrays[Mesh.ARRAY_INDEX] = _indizes
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Kontur-Hülle als ArrayMesh (null, wenn kein Teil eine Kontur hat).
func huelle() -> ArrayMesh:
	if _h_ecken.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _h_ecken
	arrays[Mesh.ARRAY_NORMAL] = _h_normalen
	arrays[Mesh.ARRAY_INDEX] = _h_indizes
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static var _koerper_mat: ShaderMaterial
static var _huelle_mat: ShaderMaterial


## Einzelnes Objekt: Node3D mit Körper und Hülle (zwei Zeichenaufrufe).
func knoten(name: String, wippen := 0.0) -> Node3D:
	var n := knoten_aus(name, mesh(), huelle())
	n.set_meta("wippen", wippen)
	return n


## Knoten aus schon gebackenen Meshes (z. B. je Biom zwischengespeichert —
## die Kampfhalle backt ihre Säulen und Kulisse nur einmal).
static func knoten_aus(name: String, koerper_mesh: Mesh, h: Mesh) -> Node3D:
	if _koerper_mat == null:
		_koerper_mat = WeltMaterial.material("kulisse")
	if _huelle_mat == null:
		_huelle_mat = Stil3D.kontur(0)
		_huelle_mat.set_shader_parameter("dicke", 0.0)
	var n := Node3D.new()
	n.name = name
	var koerper := MeshInstance3D.new()
	koerper.mesh = koerper_mesh
	koerper.material_override = _koerper_mat
	n.add_child(koerper)
	if h != null:
		var rand := MeshInstance3D.new()
		rand.mesh = h
		rand.material_override = _huelle_mat
		rand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(rand)
	return n


static var _figur_mat: ShaderMaterial


## Figur-Knoten (Gliederpuppe, Rang-Schmuck): wie knoten_aus, aber der
## Körper trägt das Toon-Material der Figuren (Stil3D.material(Weiß), die
## Vertexfarbe liefert die Farbe, Vertex-Alpha das Leuchten). So greifen
## Gold (Stil3D.gold über ist_toon — EIN Gold-Material für alle gebackenen
## Figuren), Treffer-Blitz und Strahlend-Overlay wie bei Grundkörper-Figuren;
## die Hülle bleibt die Bausatz-Hülle (ist_kontur, blitzt nicht mit).
func figur_knoten(name: String) -> Node3D:
	return figur_knoten_aus(name, mesh(), huelle())


static func figur_knoten_aus(name: String, koerper_mesh: Mesh, h: Mesh, schatten := true) -> Node3D:
	var n := Node3D.new()
	n.name = name
	figur_meshes(n, koerper_mesh, h, schatten)
	return n


## Körper und Hülle direkt als Kinder von eltern (ohne Zwischen-Node).
static func figur_meshes(eltern: Node3D, koerper_mesh: Mesh, h: Mesh, schatten := true) -> void:
	if _figur_mat == null:
		_figur_mat = Stil3D.material(Color.WHITE)
		if _huelle_mat == null:
			_huelle_mat = Stil3D.kontur(0)
			_huelle_mat.set_shader_parameter("dicke", 0.0)
	var koerper := MeshInstance3D.new()
	koerper.mesh = koerper_mesh
	koerper.material_override = _figur_mat
	if not schatten:
		koerper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eltern.add_child(koerper)
	if h != null:
		var rand := MeshInstance3D.new()
		rand.mesh = h
		rand.material_override = _huelle_mat
		rand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eltern.add_child(rand)


## Kopie eines Grundkörpers, um d nach außen aufgebläht (Kontur-Hülle).
static func aufgeblaeht(mesh: PrimitiveMesh, d: float) -> PrimitiveMesh:
	var m: PrimitiveMesh = mesh.duplicate()
	if m is BoxMesh:
		(m as BoxMesh).size += Vector3.ONE * d * 2.0
	elif m is SphereMesh:
		var k := m as SphereMesh
		k.radius += d
		k.height += d * 2.0
	elif m is CylinderMesh:
		var z := m as CylinderMesh
		z.top_radius = z.top_radius + d if z.top_radius > 0.0 else 0.0
		z.bottom_radius = z.bottom_radius + d if z.bottom_radius > 0.0 else 0.0
		z.height += d * 2.0
	elif m is CapsuleMesh:
		var c := m as CapsuleMesh
		c.radius += d
		c.height += d * 2.0
	elif m is PrismMesh:
		(m as PrismMesh).size += Vector3.ONE * d * 2.0
	elif m is TorusMesh:
		var t := m as TorusMesh
		t.inner_radius = maxf(0.0, t.inner_radius - d)
		t.outer_radius += d
	return m


## Ecken, Normalen und Indizes je Grundkörper-Form (Art + Maße + Unterteilung):
## PrimitiveMesh.get_mesh_arrays() legt das Mesh im Compatibility-Renderer auf
## der GPU an und liest es zurück — ~0.1 ms je Teil, eine Figur kalt ~25 ms.
## Gleiche Formen (Augen, Zähne, Nieten, ihre Hüllen) kommen in jeder Figur
## wieder; die Daten werden nur gelesen, nie verändert.
static var _formen: Dictionary = {}


static func _form_schluessel(m: Mesh) -> String:
	if m is SphereMesh:
		var k := m as SphereMesh
		return "k%.5f|%.5f|%d|%d|%s" % [k.radius, k.height, k.radial_segments, k.rings, k.is_hemisphere]
	if m is CylinderMesh:
		var z := m as CylinderMesh
		return "z%.5f|%.5f|%.5f|%d|%d|%s%s" % [z.top_radius, z.bottom_radius, z.height, z.radial_segments, z.rings,
			z.cap_top, z.cap_bottom]
	if m is CapsuleMesh:
		var c := m as CapsuleMesh
		return "c%.5f|%.5f|%d|%d" % [c.radius, c.height, c.radial_segments, c.rings]
	if m is BoxMesh:
		var b := m as BoxMesh
		return "b%.5f|%.5f|%.5f|%d|%d|%d" % [b.size.x, b.size.y, b.size.z, b.subdivide_width, b.subdivide_height,
			b.subdivide_depth]
	if m is PrismMesh:
		var p := m as PrismMesh
		return "p%.5f|%.5f|%.5f|%.5f|%d|%d|%d" % [p.size.x, p.size.y, p.size.z, p.left_to_right, p.subdivide_width,
			p.subdivide_height, p.subdivide_depth]
	if m is TorusMesh:
		var t := m as TorusMesh
		return "t%.5f|%.5f|%d|%d" % [t.inner_radius, t.outer_radius, t.rings, t.ring_segments]
	return ""


static func _form_daten(mesh: Mesh) -> Array:
	if not (mesh is PrimitiveMesh):
		return mesh.surface_get_arrays(0)
	var pm := mesh as PrimitiveMesh
	if pm.flip_faces or pm.add_uv2:
		return pm.get_mesh_arrays()
	var schluessel := _form_schluessel(pm)
	if schluessel.is_empty():
		return pm.get_mesh_arrays()
	var daten: Variant = _formen.get(schluessel)
	if daten == null:
		daten = pm.get_mesh_arrays()
		_formen[schluessel] = daten
	return daten


func _anhaengen(mesh: Mesh, t: Transform3D, ist_huelle: bool, farbe: Color) -> void:
	var arrays := _form_daten(mesh)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var basis_n := t.basis.inverse().transposed()
	var start := _h_ecken.size() if ist_huelle else _ecken.size()
	for i in v.size():
		var e := t * v[i]
		var nn := (basis_n * n[i]).normalized()
		if ist_huelle:
			_h_ecken.append(e)
			_h_normalen.append(nn)
		else:
			_ecken.append(e)
			_normalen.append(nn)
			_farben.append(farbe)
	var liste := idx if not idx.is_empty() else PackedInt32Array(range(v.size()))
	for i in liste:
		if ist_huelle:
			_h_indizes.append(start + i)
		else:
			_indizes.append(start + i)
