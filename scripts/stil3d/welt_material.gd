class_name WeltMaterial
extends RefCounted
## Material, Licht und Untergrund der Dungeon-Welt (STIL-3D.md, Abschnitt
## 5b/7b) — alles prozedural im Shader: Mauerwerk und Platten aus der
## Weltposition, Leuchtfugen in Biomfarbe, Sternen-Nebel statt schwarzer
## Leere, Blob-Schatten, Partikel und Vignette. Die Werte je Biom liefert
## BiomStil. Alle Shader nutzen das gemeinsame Toon-Licht (Stil3D.TOON_LICHT).

## Hash, Wert-Rauschen, fbm (3 Oktaven) und Zellkanten (F2-F1, für Risse
## und Bruchstein) — klein gehalten, die Flächen sind kartengroß.
const RAUSCHEN := """
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm3(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03 + vec2(1.7, 9.2)) * 0.3
		+ vnoise(p * 4.1 + vec2(5.3, 2.8)) * 0.15;
}
float zell_kante(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash22(n + g) - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return sqrt(d2) - sqrt(d1);
}
"""

## Wände (Sockel, Körper, Deckel): Mauerwerk aus der Weltposition —
## muster 0 Ziegel, 1 Bruchstein, 2 Gruftquader. Moos kriecht von unten,
## der Deckel ist grober Deckstein (bzw. bewachsen) und bleibt dunkler als
## der Boden. Fugen glimmen in Heldennähe in Biomfarbe.
## Glas-Regel: INSTANCE_CUSTOM.a = Deckkraft; unter 1 lässt der opake Shader
## Bildpunkte nach Bayer-Muster aus (Screen-Door), Kanten bleiben dichter.
const WAND_CODE := """
shader_type spatial;
uniform vec4 farbe : source_color = vec4(1.0);
uniform vec4 moos_farbe : source_color = vec4(0.37, 0.55, 0.21, 1.0);
uniform float moos = 0.0;
uniform float gras = 0.0;
uniform int muster = 0;
uniform vec2 stein = vec2(0.40, 0.19);
uniform vec4 fuge_farbe : source_color = vec4(0.6, 0.9, 0.4, 1.0);
uniform vec3 held_pos = vec3(0.0);
uniform vec3 halb = vec3(0.5);
varying vec3 wpos;
varying vec3 wnorm;
varying vec3 lokal;
varying float deck;
""" + RAUSCHEN + Stil3D.BAYER + """
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	lokal = VERTEX / halb;
	deck = INSTANCE_CUSTOM.a;
}

void fragment() {
	if (deck < 0.999) {
		// Kanten (zwei Achsen am Rand) dichter: die Wandform bleibt lesbar.
		vec3 a = abs(lokal);
		vec3 rand_band = vec3(1.0) - vec3(0.07) / halb;
		float kanten = step(rand_band.x, a.x) + step(rand_band.y, a.y) + step(rand_band.z, a.z);
		if (deck + step(1.5, kanten) * 0.4 < bayer4(FRAGCOORD.xy)) {
			discard;
		}
	}
	vec3 grund = farbe.rgb * COLOR.rgb;
	vec3 col;
	float fuge = 0.0;
	if (wnorm.y > 0.5) {
		// Deckel: grober Deckstein, Fase fängt das Licht (Mesh), ggf. Grasnarbe.
		float n = fbm3(wpos.xz * 3.1);
		col = grund * (0.86 + n * 0.24);
		vec2 lk = abs(fract(wpos.xz) - 0.5);
		float randnah = max(lk.x, lk.y);
		float g = gras * smoothstep(0.32, 0.5, n + 0.16 - randnah * 0.4);
		vec3 grasf = moos_farbe.rgb * (0.75 + 0.45 * vnoise(wpos.xz * 14.0));
		col = mix(col, grasf, clamp(g, 0.0, 1.0));
	} else {
		vec2 f = abs(wnorm.x) > 0.5 ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);
		float d;
		vec2 id;
		if (muster == 1) {
			vec2 q = f * vec2(3.2, 4.4);
			d = zell_kante(q) / 8.0;
			id = floor(q);
		} else {
			float reihe = floor(f.y / stein.y);
			vec2 g = vec2(f.x / stein.x + mod(reihe, 2.0) * 0.5 + hash12(vec2(reihe, 3.0)) * 0.2,
				f.y / stein.y);
			id = floor(g);
			vec2 lok = fract(g);
			vec2 k = min(lok, 1.0 - lok) * stein;
			d = min(k.x, k.y);
		}
		float w = fwidth(d) + 0.002;
		fuge = 1.0 - smoothstep(0.010, 0.010 + w * 1.5, d);
		float var = hash12(id * 1.37 + floor(wpos.xz) * 7.1);
		col = grund * (0.80 + var * 0.30) * (0.92 + 0.10 * vnoise(f * 9.0));
		// Steinwölbung: Mitte heller, Kanten dunkler (gemalte Fase).
		col *= 0.88 + 0.14 * smoothstep(0.0, 0.06, d);
		col = mix(col, grund * 0.34, fuge);
		// Moos/Feuchte kriecht von unten hoch und hängt in den Fugen.
		float n = fbm3(f * 2.6 + wpos.xz * 0.7);
		float m = moos * ((1.0 - smoothstep(0.05, 0.62, wpos.y + (n - 0.5) * 0.7)) + fuge * 0.35 * n);
		col = mix(col, moos_farbe.rgb * (0.7 + 0.4 * n), clamp(m, 0.0, 1.0) * 0.85);
		// Umgebungsverdeckung am Wandfuß.
		col *= mix(0.6, 1.0, smoothstep(-0.12, 0.5, wpos.y));
	}
	ALBEDO = col;
	float abstand = distance(wpos.xz, held_pos.xz);
	float glimm = 0.04 + 0.5 * exp(-abstand * abstand / 9.0);
	float rand = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = fuge_farbe.rgb * fuge * glimm + col * vec3(1.0, 0.9, 0.75) * smoothstep(0.55, 0.75, rand) * 0.08;
}
""" + Stil3D.TOON_LICHT

## Bodenplatten: Steinstruktur, Abnutzung (Mitte glatter, Ränder dunkler),
## Risse in etwa jeder dritten Platte; Biom: 0 Moos, 1 Pfützen, 2 Flecken,
## 3 Runenkreise (glimmen in Heldennähe). INSTANCE_CUSTOM = Wand an
## Nord/Ost/Süd/West (Umgebungsverdeckung an Wandfüßen).
const BODEN_CODE := """
shader_type spatial;
uniform vec4 farbe : source_color = vec4(1.0);
uniform vec4 moos_farbe : source_color = vec4(0.37, 0.55, 0.21, 1.0);
uniform vec4 rune_farbe : source_color = vec4(0.4, 1.0, 0.7, 1.0);
uniform int biom = 0;
uniform vec3 held_pos = vec3(0.0);
varying vec3 wpos;
varying vec4 ao;
""" + RAUSCHEN + """
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ao = INSTANCE_CUSTOM;
}

void fragment() {
	vec3 grund = farbe.rgb * COLOR.rgb;
	vec2 p = wpos.xz;
	vec2 zelle = floor(p);
	vec2 lok = fract(p);
	float zufall = hash12(zelle);
	float n = fbm3(p * 2.2 + zufall * 11.0);
	vec3 col = grund * (0.88 + n * 0.22);
	col *= 0.95 + 0.08 * vnoise(p * 23.0);
	// Abnutzung: begangene Mitte glatter und heller, Ränder dunkler.
	vec2 r = abs(lok - 0.5);
	float randnah = smoothstep(0.28, 0.49, max(r.x, r.y));
	col *= 1.03 - randnah * 0.13;
	// Abplatzer: kleine dunkle Kerben am Plattenrand.
	float kerbe = step(0.82, vnoise(p * 9.0 + zufall * 7.0)) * randnah;
	col *= 1.0 - kerbe * 0.22;
	if (zufall > 0.72) {
		// Risse: Zellkanten, nur in einem Teil der Platte (Rauschmaske).
		float k = zell_kante(p * 1.5 + zufall * 5.0);
		float w = fwidth(k) + 0.002;
		float riss = 1.0 - smoothstep(0.02, 0.02 + w * 1.5, k);
		riss *= smoothstep(0.55, 0.7, vnoise(p * 1.6 + zufall * 9.0));
		col = mix(col, grund * 0.5, riss * 0.8);
	}
	float flecken = fbm3(p * 0.9 + 3.3);
	vec3 leuchten = vec3(0.0);
	if (biom == 0) {
		float m = smoothstep(0.62, 0.76, flecken + randnah * 0.22 * n);
		col = mix(col, moos_farbe.rgb * (0.75 + 0.4 * vnoise(p * 12.0)), m * 0.55);
	} else if (biom == 1) {
		float nass = smoothstep(0.66, 0.71, flecken);
		col = mix(col, col * vec3(0.62, 0.68, 0.82), nass);
		leuchten = vec3(0.35, 0.5, 0.8) * nass * 0.12 * (0.6 + 0.4 * vnoise(p * 6.0 + TIME * 0.3));
	} else if (biom == 2) {
		float m = smoothstep(0.62, 0.72, flecken);
		col = mix(col, moos_farbe.rgb * 0.8, m * 0.5);
	} else if (zufall < 0.08) {
		// Krypta: Runenkreis mit Zeichen, glimmt in Heldennähe auf.
		vec2 c = lok - 0.5;
		float rr = length(c);
		float ring = min(abs(rr - 0.33), abs(rr - 0.25));
		float seg = fract(atan(c.y, c.x) * 6.0 / 6.2831 + zufall * 40.0);
		float zeichen = (abs(rr - 0.29) < 0.035 && abs(seg - 0.5) < 0.06) ? 0.0 : 1.0;
		float kern = abs(length(c - vec2(0.0, 0.02)) - 0.08);
		float lin = min(min(ring, kern), zeichen);
		float rune = 1.0 - smoothstep(0.008, 0.022, lin);
		col = mix(col, col * 0.55, rune);
		float abstand = distance(p, held_pos.xz);
		leuchten = rune_farbe.rgb * rune * (0.12 + 0.6 * exp(-abstand * abstand / 8.0));
	}
	// Umgebungsverdeckung an angrenzenden Wänden (N = -z, O = +x, S = +z, W = -x).
	float v = 1.0;
	v *= 1.0 - ao.x * (1.0 - smoothstep(0.0, 0.42, lok.y));
	v *= 1.0 - ao.y * (1.0 - smoothstep(0.0, 0.42, 1.0 - lok.x));
	v *= 1.0 - ao.z * (1.0 - smoothstep(0.0, 0.42, 1.0 - lok.y));
	v *= 1.0 - ao.w * (1.0 - smoothstep(0.0, 0.42, lok.x));
	col *= mix(0.58, 1.0, v);
	ALBEDO = col;
	EMISSION = leuchten;
}
""" + Stil3D.TOON_LICHT

## Fugen unter den Bodenplatten: dunkel, glimmen in Heldennähe in Biomfarbe.
const FUGE_CODE := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform vec4 dunkel : source_color = vec4(0.14, 0.13, 0.18, 1.0);
uniform vec4 farbe : source_color = vec4(0.6, 0.9, 0.4, 1.0);
uniform vec3 held_pos = vec3(0.0);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = distance(wpos.xz, held_pos.xz);
	float k = 0.05 + 0.6 * exp(-d * d / 10.0);
	k *= 0.82 + 0.18 * sin(TIME * 1.1 + wpos.x * 0.6 + wpos.z * 0.45);
	ALBEDO = dunkel.rgb + farbe.rgb * k;
}
"""

## Untergrund unter der Karte: Nebel mit Sternen statt schwarzer Leere.
## Künstliche Parallaxe: das Muster wandert mit dem Kamera-Ziel (die
## Orthokamera hat keine eigene). Dither gegen Banding im dunklen Verlauf.
const UNTERGRUND_CODE := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform vec4 tief : source_color = vec4(0.03, 0.03, 0.09, 1.0);
uniform vec4 nebel : source_color = vec4(0.22, 0.2, 0.5, 1.0);
uniform vec4 schimmer : source_color = vec4(0.4, 1.0, 0.7, 1.0);
uniform vec4 stern : source_color = vec4(0.78, 0.83, 1.0, 1.0);
uniform vec2 kamera = vec2(0.0);
varying vec3 wpos;
""" + RAUSCHEN + """
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = (wpos.xz + kamera * 0.45) * 0.16;
	float n = fbm3(p + vec2(TIME * 0.015, TIME * 0.008));
	float schlieren = smoothstep(0.38, 0.82, fbm3(p * 1.7 - vec2(TIME * 0.02, 0.0) + n));
	vec3 c = mix(tief.rgb, nebel.rgb, schlieren);
	c += schimmer.rgb * schlieren * schlieren * schlieren * 0.1;
	// Sterne in zwei Tiefen: sparsam, funkeln langsam.
	for (int lage = 0; lage < 2; lage++) {
		float tiefe = lage == 0 ? 0.75 : 0.88;
		vec2 sp = (wpos.xz + kamera * tiefe) * (lage == 0 ? 1.4 : 2.3);
		vec2 sz = floor(sp);
		float h = hash12(sz + float(lage) * 17.0);
		vec2 versatz = (hash22(sz + 3.1) - 0.5) * 0.6;
		float s = step(0.962, h) * (1.0 - smoothstep(0.0, 0.08, length(fract(sp) - 0.5 - versatz)));
		s *= 0.55 + 0.45 * sin(TIME * (1.0 + h * 3.0) + h * 40.0);
		c += stern.rgb * s * (lage == 0 ? 1.1 : 0.6);
	}
	c += (hash12(FRAGCOORD.xy) - 0.5) / 255.0;
	ALBEDO = c;
}
"""

## Weicher Blob-Schatten unter Figuren bzw. Bodenring (ring = 1) — gemischt,
## schreibt keine Tiefe, wirft keinen Schatten.
const BLOB_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 farbe : source_color = vec4(0.05, 0.04, 0.09, 1.0);
uniform float deckkraft = 0.42;
uniform float ring = 0.0;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float blob = 1.0 - smoothstep(0.25, 1.0, d);
	float band = (1.0 - smoothstep(0.03, 0.1, abs(d - 0.78))) * (0.8 + 0.2 * sin(TIME * 2.4));
	ALBEDO = farbe.rgb;
	ALPHA = mix(blob * blob, band, ring) * deckkraft;
}
"""

## Schwebende Lichtpunkte (Glühwürmchen, Irrlichter, Asche, Tropfen).
const FUNKE_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled;
uniform vec4 farbe : source_color = vec4(1.0);
uniform float staerke = 0.9;

void fragment() {
	float kern = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	ALBEDO = farbe.rgb * staerke * COLOR.a * (0.3 + kern);
}
"""

## Vignette über der 3D-Welt, unter der UI: ohne Bildschirm-Textur (billig),
## nur eine abgedunkelte, geditherte Randblende.
const VIGNETTE_CODE := """
shader_type canvas_item;
uniform vec4 farbe : source_color = vec4(0.02, 0.02, 0.06, 1.0);
uniform float staerke = 0.42;

void fragment() {
	vec2 d = UV - 0.5;
	d.x *= SCREEN_PIXEL_SIZE.y > 0.0 ? SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x * 0.8 : 1.0;
	float v = smoothstep(0.38, 0.95, length(d) * 1.25);
	float rauschen = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(farbe.rgb, clamp(v * staerke + (rauschen - 0.5) * (2.0 / 255.0), 0.0, 1.0));
}
"""

static var _shader: Dictionary = {}


static func shader(art: String) -> Shader:
	if _shader.has(art):
		return _shader[art]
	var s := Shader.new()
	match art:
		"wand": s.code = WAND_CODE
		"boden": s.code = BODEN_CODE
		"fuge": s.code = FUGE_CODE
		"untergrund": s.code = UNTERGRUND_CODE
		"blob": s.code = BLOB_CODE
		"funke": s.code = FUNKE_CODE
		"vignette": s.code = VIGNETTE_CODE
		_: push_error("WeltMaterial: unbekannter Shader " + art)
	_shader[art] = s
	return s


## Neues Material aus einem WeltMaterial-Shader; kontur_modus >= 0 hängt
## eine mitdithernde Kontur an (Wände mit INSTANCE_CUSTOM.a).
static func material(art: String, werte: Dictionary = {}, kontur_modus := -1) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader(art)
	for k in werte:
		mat.set_shader_parameter(k, werte[k])
	if kontur_modus >= 0:
		mat.next_pass = Stil3D.kontur(kontur_modus, true)
	return mat


## Box mit Fase (SurfaceTool): die Kanten fangen Licht — Miniatur-Optik.
## Flache Normalen je Fläche, Fase höchstens 90 % der kleinsten Halbachse.
static func fasen_box(groesse: Vector3, fase: float) -> ArrayMesh:
	var h := groesse * 0.5
	var f := minf(fase, minf(h.x, minf(h.y, h.z)) * 0.9)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Ecke s (Vorzeichen je Achse), auf den Achsen mit innen = 1 um f eingerückt.
	var punkt := func(s: Vector3, innen: Vector3) -> Vector3:
		return Vector3(s.x * (h.x - f * innen.x), s.y * (h.y - f * innen.y), s.z * (h.z - f * innen.z))
	var dreieck := func(a: Vector3, b: Vector3, c: Vector3) -> void:
		var n := (b - a).cross(c - a)
		if n.dot(a + b + c) < 0.0:  # Normale nach außen (konvexer Körper um 0)
			var t := b
			b = c
			c = t
			n = -n
		n = n.normalized()
		# Godot: Vorderseite im Uhrzeigersinn » Reihenfolge a, c, b.
		for v in [a, c, b]:
			st.set_normal(n)
			st.add_vertex(v)
	var viereck := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		dreieck.call(a, b, c)
		dreieck.call(a, c, d)
	# Hauptflächen (je Achse ±), um f eingerückt.
	for achse in 3:
		for vz in [-1.0, 1.0]:
			var ecken: Array[Vector3] = []
			for e in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var s := Vector3.ZERO
				var innen := Vector3.ONE
				s[achse] = vz
				innen[achse] = 0.0
				s[(achse + 1) % 3] = e.x
				s[(achse + 2) % 3] = e.y
				ecken.append(punkt.call(s, innen))
			viereck.call(ecken[0], ecken[1], ecken[2], ecken[3])
	# Kanten-Fasen entlang jeder Achse.
	for achse in 3:
		var b := (achse + 1) % 3
		var c := (achse + 2) % 3
		for sb in [-1.0, 1.0]:
			for sc in [-1.0, 1.0]:
				var pts: Array[Vector3] = []
				for sa in [-1.0, 1.0]:
					var s := Vector3.ZERO
					s[achse] = sa
					s[b] = sb
					s[c] = sc
					var auf_b := Vector3.ONE
					auf_b[b] = 0.0
					var auf_c := Vector3.ONE
					auf_c[c] = 0.0
					pts.append(punkt.call(s, auf_b))
					pts.append(punkt.call(s, auf_c))
				viereck.call(pts[0], pts[2], pts[3], pts[1])
	# Ecken-Dreiecke.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var s := Vector3(sx, sy, sz)
				dreieck.call(punkt.call(s, Vector3(0, 1, 1)), punkt.call(s, Vector3(1, 0, 1)),
					punkt.call(s, Vector3(1, 1, 0)))
	return st.commit()


## Blob-Schatten (bzw. Bodenring) als liegende Ebene, Mittelpunkt bei 0.
static func blob(durchmesser: float, mat: ShaderMaterial) -> MeshInstance3D:
	var ebene := PlaneMesh.new()
	ebene.size = Vector2(durchmesser, durchmesser)
	var mi := MeshInstance3D.new()
	mi.mesh = ebene
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Atmosphäre je Biom (BiomStil "partikel"): Lichtpunkte um das Kamera-Ziel.
static func partikel(art: String, farbe: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 34
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.local_coords = false
	var kugel := SphereMesh.new()
	kugel.radius = 0.03
	kugel.height = 0.06
	kugel.radial_segments = 6
	kugel.rings = 3
	p.mesh = kugel
	p.material_override = material("funke", {"farbe": farbe})
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(8.0, 0.8, 8.0)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var rampe := Gradient.new()
	rampe.set_color(0, Color(1, 1, 1, 0))
	rampe.set_color(1, Color(1, 1, 1, 0))
	rampe.add_point(0.25, Color(1, 1, 1, 1))
	rampe.add_point(0.7, Color(1, 1, 1, 0.8))
	p.color_ramp = rampe
	match art:
		"gluehwuermchen":
			p.emission_box_extents = Vector3(8.0, 0.5, 8.0)
			p.initial_velocity_max = 0.35
		"tropfen":
			p.gravity = Vector3(0, -2.5, 0)
			p.direction = Vector3.DOWN
			p.spread = 4.0
			p.lifetime = 1.6
			p.preprocess = 1.6
			p.amount = 22
			p.emission_box_extents = Vector3(8.0, 0.4, 8.0)
			p.scale_amount_min = 0.4
			p.scale_amount_max = 0.7
		"asche":
			p.gravity = Vector3(0, 0.3, 0)
			p.spread = 35.0
			p.initial_velocity_min = 0.08
			p.initial_velocity_max = 0.3
			p.scale_amount_min = 0.4
			p.scale_amount_max = 0.8
		"irrlicht":
			p.gravity = Vector3(0, 0.1, 0)
			p.amount = 18
			p.lifetime = 6.0
			p.preprocess = 6.0
			p.scale_amount_min = 1.3
			p.scale_amount_max = 2.0
	return p


## Vignette als CanvasLayer UNTER der UI (Ebene -1, über der 3D-Welt).
static func vignette(eltern: Node, staerke := 0.42) -> CanvasLayer:
	var ebene := CanvasLayer.new()
	ebene.layer = -1
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = shader("vignette")
	mat.set_shader_parameter("staerke", staerke)
	rect.material = mat
	ebene.add_child(rect)
	eltern.add_child(ebene)
	return ebene
