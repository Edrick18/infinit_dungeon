class_name Schweif
extends MeshInstance3D
## Leuchtender Schweif hinter Projektilen und Zaubern (STIL-3D.md 7f): ein
## Band aus den letzten Positionen des Kopfes — quer zu Bewegung und Blick,
## zum Ende schmaler und durchsichtiger, mit hellem Kern. Statt einer Kette
## aus Kugel-Partikeln EIN ImmediateMesh je Projektil. Landet der Kopf
## (wird freigegeben), holt das Ende ihn ein und der Schweif räumt sich auf.

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 farbe : source_color = vec4(1.0);
void fragment() {
	float quer = 1.0 - abs(UV.y * 2.0 - 1.0);
	float kern = smoothstep(0.55, 1.0, quer);
	ALBEDO = mix(farbe.rgb, vec3(1.0), kern * 0.55) * 1.35;
	ALPHA = clamp(COLOR.a * smoothstep(0.0, 0.6, quer), 0.0, 1.0);
}
"""
## Höchstens so viele Stützpunkte; ein neuer erst nach ABSTAND Welteinheiten.
const PUNKTE := 14
const ABSTAND := 0.14
## Sekunden, in denen das Ende nach der Landung den Kopf einholt.
const AUSLAUF := 0.14

static var _shader: Shader

var kopf: Node3D
var kamera: Camera3D
var breite := 0.2
var _punkte := PackedVector3Array()
var _im := ImmediateMesh.new()
var _mat: ShaderMaterial
var _auslauf := 0.0


static func material(farbe: Color) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("farbe", farbe)
	return mat


## Ecken des Bands (Punkt 0 = Kopf): je Stützpunkt zwei Ecken quer zur
## Laufrichtung und zur Blickrichtung; die Breite läuft zum Ende auf 0 aus.
static func band(punkte: PackedVector3Array, auge: Vector3, breite_kopf: float) -> PackedVector3Array:
	var ecken := PackedVector3Array()
	var n := punkte.size()
	if n < 2:
		return ecken
	for i in n:
		var vor := punkte[maxi(0, i - 1)]
		var nach := punkte[mini(n - 1, i + 1)]
		var lauf := (vor - nach).normalized()
		var blick := (auge - punkte[i]).normalized()
		var quer := lauf.cross(blick)
		if quer.length_squared() < 0.0001:
			quer = Vector3.UP.cross(lauf)
		quer = quer.normalized() * breite_kopf * 0.5 * (1.0 - float(i) / float(n - 1))
		ecken.append(punkte[i] + quer)
		ecken.append(punkte[i] - quer)
	return ecken


func _init(farbe := Color.WHITE) -> void:
	_mat = material(farbe)
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true  # Ecken in Weltkoordinaten


func _process(delta: float) -> void:
	if kopf != null and is_instance_valid(kopf) and kopf.is_inside_tree():
		var p := kopf.global_position
		if _punkte.is_empty() or _punkte[0].distance_to(p) >= ABSTAND:
			_punkte.insert(0, p)
			if _punkte.size() > PUNKTE:
				_punkte.resize(PUNKTE)
		else:
			_punkte[0] = p
	else:
		# Kopf ist gelandet: das Ende holt auf, dann aufräumen.
		kopf = null
		_auslauf += delta
		var weg := ceili(float(PUNKTE) * delta / AUSLAUF)
		_punkte.resize(maxi(0, _punkte.size() - weg))
		if _punkte.size() < 2:
			queue_free()
			return
	_zeichnen()


func _zeichnen() -> void:
	_im.clear_surfaces()
	if _punkte.size() < 2:
		return
	var auge := kamera.global_position if kamera != null else _punkte[0] + Vector3(0, 6, 8)
	var ecken := band(_punkte, auge, breite)
	var n := _punkte.size()
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	for i in n:
		var t := float(i) / float(n - 1)
		var a := pow(1.0 - t, 1.4)
		_im.surface_set_color(Color(1, 1, 1, a))
		_im.surface_set_uv(Vector2(t, 0.0))
		_im.surface_add_vertex(ecken[i * 2])
		_im.surface_set_color(Color(1, 1, 1, a))
		_im.surface_set_uv(Vector2(t, 1.0))
		_im.surface_add_vertex(ecken[i * 2 + 1])
	_im.surface_end()
