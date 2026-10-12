class_name Stil3D
extends RefCounted
## DESIGN-STANDARD "Infinit Dungeon 3D" — die Bausteine, aus denen ALLES
## gebaut wird (Regeln: docs/STIL-3D.md).
## - Formen nur aus Grundkörpern: Kugel, Box, Zylinder/Kegel, Kapsel, Prisma.
## - Toon-Licht mit zwei harten Stufen; Schattenseiten färbt das violette
##   Umgebungslicht (nie schwarz).
## - Dunkle Kontur (#14141f) um jede Figur und jedes Objekt — das Erbe der
##   Pixel-Ära, hält alles lesbar.
## - Farben NUR aus der Hauspalette PAL.

const KONTUR := Color("14141f")
const KONTUR_DICKE := 0.022

const PAL := {
	"nacht": Color("14141f"),
	"stein": Color("8f8b9c"), "stein_hell": Color("b3afbf"), "stein_dunkel": Color("6b6779"),
	"fuge": Color("24222f"),
	"holz": Color("9a6438"), "holz_hell": Color("b98149"), "eisen": Color("6e7385"),
	"gold": Color("e8b44a"),
	"schleim": Color("4fd6b8"), "schleim_hell": Color("9df0dc"),
	"fell": Color("9a98ad"), "fell_hell": Color("c9c7d6"), "maehne": Color("e0505e"),
	"moos": Color("86b03c"), "kristall": Color("6fe3f0"),
	"lila": Color("8f5fd8"), "lila_dunkel": Color("5e3a9c"),
	"ruestung": Color("4a7ad8"), "ruestung_dunkel": Color("2f4f9e"),
	"umhang": Color("c8364a"), "haut": Color("f2c79e"),
	"weiss": Color("f4f1ea"), "schwarz": Color("1b1a24"), "mund": Color("7a1f2e"),
	"glut": Color("ffd25a"), "flamme": Color("ff9a3a"),
}

const TOON_CODE := """
shader_type spatial;
uniform vec4 farbe : source_color = vec4(1.0);
uniform vec4 leuchten : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	ALBEDO = farbe.rgb;
	// Schmaler Randlicht-Saum: Formen lösen sich vom dunklen Hintergrund.
	float rand = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = leuchten.rgb + farbe.rgb * smoothstep(0.62, 0.70, rand) * 0.10;
}

void light() {
	float licht = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	// Zwei harte Stufen statt weichem Verlauf = Cel-Shading.
	float stufe = smoothstep(0.02, 0.07, licht) * 0.7 + smoothstep(0.45, 0.50, licht) * 0.3;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * stufe;
}
"""

const KONTUR_CODE := """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform vec4 farbe : source_color = vec4(0.078, 0.078, 0.122, 1.0);
uniform float dicke = 0.022;
uniform int modus = 0;  // 0 = glatte Form, 1 = Box/Prisma, 2 = Zylinder/Kegel

void vertex() {
	vec3 richtung = NORMAL;
	if (modus == 1) {
		richtung = sign(VERTEX);
	} else if (modus == 2) {
		vec2 xz = VERTEX.xz;
		float l = length(xz);
		vec2 d = l > 0.0001 ? xz / l : vec2(0.0);
		richtung = vec3(d.x, sign(VERTEX.y), d.y);
	}
	VERTEX += richtung * dicke;
}

void fragment() {
	ALBEDO = farbe.rgb;
}
"""

static var _toon: Shader
static var _kontur: Shader
static var _cache: Dictionary = {}


static func farbe(name: String) -> Color:
	return PAL[name]


## Toon-Material, optional mit Kontur (modus: -1 = keine, 0/1/2 = Formtyp).
static func material(grundfarbe: Color, modus := -1, leuchten := Color.BLACK) -> ShaderMaterial:
	var key := "%s|%d|%s" % [grundfarbe.to_html(), modus, leuchten.to_html()]
	if _cache.has(key):
		return _cache[key]
	if _toon == null:
		_toon = Shader.new()
		_toon.code = TOON_CODE
		_kontur = Shader.new()
		_kontur.code = KONTUR_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _toon
	mat.set_shader_parameter("farbe", grundfarbe)
	mat.set_shader_parameter("leuchten", leuchten)
	if modus >= 0:
		var rand := ShaderMaterial.new()
		rand.shader = _kontur
		rand.set_shader_parameter("modus", modus)
		rand.set_shader_parameter("dicke", KONTUR_DICKE)
		rand.set_shader_parameter("farbe", KONTUR)
		mat.next_pass = rand
	_cache[key] = mat
	return mat


## Ein Bauteil: Grundkörper + Palettenfarbe an Position/Drehung.
## Formen NIE über die Node-Skalierung verzerren — Maße gehören ins Mesh,
## sonst wird die Kontur ungleichmäßig dick.
static func teil(eltern: Node3D, mesh: PrimitiveMesh, grundfarbe: Color, pos: Vector3,
		rot_grad := Vector3.ZERO, kontur := true, leuchten := Color.BLACK) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var modus := -1
	if kontur:
		modus = 0
		if mesh is BoxMesh or mesh is PrismMesh:
			modus = 1
		elif mesh is CylinderMesh:
			modus = 2
	mi.material_override = material(grundfarbe, modus, leuchten)
	mi.position = pos
	mi.rotation_degrees = rot_grad
	eltern.add_child(mi)
	return mi


# --- Grundkörper -------------------------------------------------------------

static func kugel(r: float, hoehe := -1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = hoehe if hoehe > 0.0 else r * 2.0
	m.radial_segments = 24
	m.rings = 12
	return m


static func box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


static func zylinder(r_oben: float, r_unten: float, hoehe: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_oben
	m.bottom_radius = r_unten
	m.height = hoehe
	m.radial_segments = 20
	m.rings = 1
	return m


static func kegel(r: float, hoehe: float) -> CylinderMesh:
	return zylinder(0.0, r, hoehe)


static func kapsel(r: float, hoehe: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(hoehe, r * 2.0)
	m.radial_segments = 20
	m.rings = 8
	return m


static func prisma(x: float, y: float, z: float) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = Vector3(x, y, z)
	return m


## Cartoon-Auge: weiße Kugel + Pupille in Blickrichtung (+Z = nach vorn).
static func auge(eltern: Node3D, pos: Vector3, r: float, blick := Vector3(0, 0, 1)) -> void:
	teil(eltern, kugel(r), farbe("weiss"), pos)
	teil(eltern, kugel(r * 0.52), farbe("schwarz"), pos + blick.normalized() * r * 0.68,
		Vector3.ZERO, false)


## Böse Augenbraue über einem Auge (seite: -1 links, +1 rechts).
static func braue(eltern: Node3D, pos: Vector3, breite: float, seite: float) -> void:
	teil(eltern, box(breite, breite * 0.28, breite * 0.3), farbe("schwarz"), pos,
		Vector3(0, 0, -22.0 * seite), false)
