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
	# Bestiarium-Erweiterung
	"braun": Color("7a5235"), "braun_hell": Color("a87850"), "leder": Color("6e5034"),
	"knochen": Color("e6dcc2"), "fahl": Color("9fae8c"),
	"daemon": Color("b8322e"), "daemon_dunkel": Color("6e1f2a"),
	"schatten": Color("3a2f4f"), "robe_lila": Color("5a3a8a"), "robe_schwarz": Color("2c2a38"),
	"troll": Color("6e9a4a"), "moos_dunkel": Color("5a7a2c"), "pilz_rot": Color("d8463c"),
	"seele": Color("7dffb0"),
	# Rüstungsfarben aus den Bestiarium-Stufen (FigurenBau.SONDER_FARBEN)
	"obsidian": Color("34304a"), "smaragd": Color("2fa86a"), "bernstein": Color("e0892c"),
	"rosenquarz": Color("e58aa6"), "mitternacht": Color("26357a"), "silber": Color("c3c8d6"),
	"drachenblut": Color("9a1f2c"),
	# Biom-Stimmung der Dungeon-Welt (BiomStil): Flächen, Leuchtfugen, Untergrund
	"laterne": Color("ffc27e"), "stern": Color("c8d4ff"),
	"wald_boden": Color("8c8372"), "wald_wand": Color("7a7266"), "wald_deckel": Color("6c7458"),
	"wald_moos": Color("52783a"), "wald_fuge": Color("a6e060"), "wald_tief": Color("07110e"),
	"wald_nebel": Color("1f3d33"), "wald_funke": Color("e2f07a"),
	"hoehle_boden": Color("83868f"), "hoehle_wand": Color("666978"), "hoehle_deckel": Color("686c7e"),
	"hoehle_moos": Color("3f9aa8"), "hoehle_fuge": Color("56e0ff"), "hoehle_tief": Color("060a18"),
	"hoehle_nebel": Color("1c2c56"), "hoehle_funke": Color("a6dcff"),
	"ruinen_boden": Color("a0967f"), "ruinen_wand": Color("8e8474"), "ruinen_deckel": Color("847a66"),
	"ruinen_moos": Color("7f8f44"), "ruinen_fuge": Color("ff9a48"), "ruinen_tief": Color("120c10"),
	"ruinen_nebel": Color("3c2a42"), "ruinen_funke": Color("ffb868"),
	"krypta_boden": Color("827b8a"), "krypta_wand": Color("625a72"), "krypta_deckel": Color("5f586e"),
	"krypta_moos": Color("4f8a6a"), "krypta_fuge": Color("5cffaa"), "krypta_tief": Color("050c0a"),
	"krypta_nebel": Color("173a2d"), "krypta_funke": Color("80ffb6"),
	# Biom-Kulisse (Wandkronen, Deko, Ziele, Boss-Arena — BiomKulisse/DungeonWelt3D)
	"tanne": Color("3d7038"), "tanne_hell": Color("5b9147"), "farn": Color("4f8f3a"),
	"marmor": Color("c9c0aa"), "wasser": Color("6a88a8"), "kerze": Color("efe3c4"),
	"banner": Color("7e2232"), "messing": Color("c08a3e"),
	"boss_siegel": Color("ff5a48"), "treppe_licht": Color("8fe8ff"),
}

## Gemeinsames Toon-Licht aller Stil-Shader (Figuren, Wände, Boden): die
## harten Stufen gelten NUR für den Lichteinfall N·L; die Abschwächung der
## Punktlichter (ATTENUATION, bei der Sonne inkl. Schatten) wirkt weich —
## so entstehen keine harten Laternen-Scheiben oder Fackel-Ellipsen.
const TOON_LICHT := """
void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float stufe = smoothstep(0.02, 0.07, nl) * 0.7 + smoothstep(0.45, 0.50, nl) * 0.3;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * stufe * ATTENUATION;
}
"""

## Ausgleich für Fackeln/Feuer in Menü und Kampf: sie waren auf die alten
## harten Lichtscheiben abgestimmt (dort reichte jede Abschwächung über ~0.07
## für die volle Stufe, die Wärme reichte bis fast an omni_range). Mit
## weicher ATTENUATION verschwänden ihre warmen Flecken — flacherer Abfall
## (omni_attenuation) plus etwas mehr Energie halten die gewohnte Wärme,
## jetzt mit weichem Rand. Der Dungeon stimmt Laterne und Licht-Pool eigens ab.
const PUNKTLICHT_AUSGLEICH := 1.6
const PUNKTLICHT_ABFALL := 0.45

const TOON_CODE := """
shader_type spatial;
uniform vec4 farbe : source_color = vec4(1.0);
uniform vec4 leuchten : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	// COLOR = Instanzfarbe bei MultiMeshes, sonst Weiß.
	vec3 grund = farbe.rgb * COLOR.rgb;
	ALBEDO = grund;
	// Schmaler Randlicht-Saum: Formen lösen sich vom dunklen Hintergrund.
	float rand = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// Vertex-Alpha < 1 = Leuchten (gebackene Figuren, Bausatz.teil leuchten);
	// Grundkörper und MultiMesh-Instanzfarben haben Alpha 1 — unverändert.
	EMISSION = leuchten.rgb + grund * smoothstep(0.62, 0.70, rand) * 0.10
		+ grund * (1.0 - COLOR.a) * 1.4;
}
""" + TOON_LICHT

## Kontur (Inverted Hull). Mit DITHER liest sie die Deckkraft aus
## INSTANCE_CUSTOM.a (MultiMesh-Wände) und lässt dieselben Bildpunkte aus wie
## der Wand-Shader (Glas-Regel per Screen-Door) — sonst bliebe eine dunkle
## Hülle stehen.
static func kontur_code(dither := false) -> String:
	return """
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform vec4 farbe : source_color = vec4(0.078, 0.078, 0.122, 1.0);
uniform float dicke = 0.022;
uniform int modus = 0;  // 0 = glatte Form, 1 = Box/Prisma, 2 = Zylinder/Kegel
varying float deck;
""" + BAYER + """
void vertex() {
	deck = %s;
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
	if (deck < 0.999 && deck < bayer4(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = farbe.rgb;
}
""" % ("INSTANCE_CUSTOM.a" if dither else "1.0")


## Geordnetes 4×4-Bayer-Muster (0..1) für Screen-Door-Transparenz: opake
## Shader lassen Bildpunkte aus, statt in die Transparenz-Pipeline zu gehen.
const BAYER := """
float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x * 0.5 + a.y * a.y * 0.75);
}
float bayer4(vec2 a) {
	return bayer2(a * 0.5) * 0.25 + bayer2(a) + 0.03125;
}
"""

static var _toon: Shader
static var _kontur: Shader
static var _kontur_dither: Shader
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
	var mat := ShaderMaterial.new()
	mat.shader = _toon
	mat.set_shader_parameter("farbe", grundfarbe)
	mat.set_shader_parameter("leuchten", leuchten)
	if modus >= 0:
		mat.next_pass = kontur(modus)
	_cache[key] = mat
	return mat


## Kontur-Pass für einen Formtyp (modus 0/1/2), optional mit Screen-Door-
## Dithering aus INSTANCE_CUSTOM.a (MultiMesh mit use_custom_data).
static func kontur(modus: int, dither := false) -> ShaderMaterial:
	if dither and _kontur_dither == null:
		_kontur_dither = Shader.new()
		_kontur_dither.code = kontur_code(true)
	elif not dither and _kontur == null:
		_kontur = Shader.new()
		_kontur.code = kontur_code(false)
	var rand := ShaderMaterial.new()
	rand.shader = _kontur_dither if dither else _kontur
	rand.set_shader_parameter("modus", modus)
	rand.set_shader_parameter("dicke", KONTUR_DICKE)
	rand.set_shader_parameter("farbe", KONTUR)
	return rand


## Güldene Figuren (Rang „gülden“): echtes Gold statt Overlay — die Albedo
## wird zu Gold gezogen (Helligkeit bleibt, Formen und Gesichter lesbar),
## dazu eine harte Glanzstufe (Toon-Metall) und Glitzerpunkte, die einzeln
## aufblitzen. Gleiche Uniforms wie TOON_CODE; Kontur bleibt als next_pass.
const GOLD_CODE := """
shader_type spatial;
uniform vec4 farbe : source_color = vec4(1.0);
uniform vec4 leuchten : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 gold : source_color = vec4(0.91, 0.71, 0.29, 1.0);
varying vec3 opos;

float glitzer_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	opos = VERTEX;
}

void fragment() {
	vec3 grund = farbe.rgb * COLOR.rgb;
	float hell = dot(grund, vec3(0.299, 0.587, 0.114));
	// Helligkeit stark gestaucht: auch dunkle Figuren (Fledermaus, Schatten-
	// bestie) werden Gold statt Bronze/Braun; Augen und Flecken bleiben als
	// dunkleres Gold lesbar.
	vec3 g = gold.rgb * (0.5 + 0.46 * hell);
	ALBEDO = mix(grund, g, 0.86);
	float rand = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float h = glitzer_hash(floor(opos * 18.0));
	float funkeln = step(0.94, h) * pow(max(0.0, sin(TIME * (1.6 + h * 3.0) + h * 70.0)), 16.0);
	// Etwas Eigenglanz in Gold: kühles Biomlicht (Höhle) macht es sonst oliv.
	EMISSION = leuchten.rgb + g * (0.16 + smoothstep(0.55, 0.78, rand) * 0.3)
		+ vec3(1.0, 0.93, 0.72) * funkeln * 1.8 + g * (1.0 - COLOR.a) * 1.4;
}

void light() {
	float nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float stufe = smoothstep(0.02, 0.07, nl) * 0.7 + smoothstep(0.45, 0.50, nl) * 0.3;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * stufe * ATTENUATION;
	float glanz = smoothstep(0.93, 0.955, dot(NORMAL, normalize(LIGHT + VIEW)));
	SPECULAR_LIGHT += LIGHT_COLOR * glanz * ATTENUATION * 0.9;
}
"""
static var _gold: Shader
static var _gold_cache: Dictionary = {}


## Ist das ein Toon-Material aus material() (Figurenteile)?
static func ist_toon(mat: Material) -> bool:
	return mat is ShaderMaterial and _toon != null and (mat as ShaderMaterial).shader == _toon


## Ist das ein Kontur-Material (Inverted Hull bzw. Bausatz-Hülle)?
static func ist_kontur(mat: Material) -> bool:
	if not (mat is ShaderMaterial):
		return false
	var s := (mat as ShaderMaterial).shader
	return s != null and (s == _kontur or s == _kontur_dither)


## Gold-Gegenstück eines Toon-Materials (je Ausgangsmaterial einmal, gecacht).
static func gold(toon: ShaderMaterial) -> ShaderMaterial:
	var key := toon.get_instance_id()
	if _gold_cache.has(key):
		return _gold_cache[key]
	if _gold == null:
		_gold = Shader.new()
		_gold.code = GOLD_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _gold
	mat.set_shader_parameter("farbe", toon.get_shader_parameter("farbe"))
	mat.set_shader_parameter("leuchten", toon.get_shader_parameter("leuchten"))
	mat.set_shader_parameter("gold", farbe("gold"))
	mat.next_pass = toon.next_pass
	_gold_cache[key] = mat
	return mat


## Gemeinsame Bildstimmung der 3D-Welten: Filmic-Tonemapping statt Linear
## (weiche Lichter statt ausgefressener Flecken). AgX gibt es in
## Compatibility 4.7 auch, bleicht aber Flammen, Augen und Gold zu Weiß aus
## (Testbild 2026-11-01) — darum Filmic, Belichtung leicht gesenkt.
static func umgebung(env: Environment, ambient: Color, ambient_energie: float) -> void:
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energie
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.tonemap_white = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.08


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

## segmente: Unterteilung rundum (Ringe = Hälfte); Kleinteile (Augen, Nieten,
## Zähne) mit 10–12 statt 24 sparen Dreiecke (STIL-3D.md 7g, Budget).
static func kugel(r: float, hoehe := -1.0, segmente := 24) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = hoehe if hoehe > 0.0 else r * 2.0
	m.radial_segments = segmente
	m.rings = maxi(3, segmente / 2)
	return m


static func box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


static func zylinder(r_oben: float, r_unten: float, hoehe: float, segmente := 20) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_oben
	m.bottom_radius = r_unten
	m.height = hoehe
	m.radial_segments = segmente
	m.rings = 1
	return m


static func kegel(r: float, hoehe: float, segmente := 20) -> CylinderMesh:
	return zylinder(0.0, r, hoehe, segmente)


static func kapsel(r: float, hoehe: float, segmente := 20) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(hoehe, r * 2.0)
	m.radial_segments = segmente
	m.rings = 8 if segmente >= 20 else maxi(2, segmente / 4)
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
