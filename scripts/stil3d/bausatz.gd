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


func _anhaengen(mesh: PrimitiveMesh, t: Transform3D, ist_huelle: bool, farbe: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
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
