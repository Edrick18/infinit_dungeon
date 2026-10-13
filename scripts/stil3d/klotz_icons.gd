class_name KlotzIcons
extends RefCounted
## Symbole für die Skill-Bausteine (Werkstatt, Tooltips) im STIL-3D-Look:
## jedes Icon ist eine kleine Figur aus Grundkörpern, die PortraitStudio
## einmal in eine Textur rendert. Element = sein Zeichen, Effekt = sein
## Status, Verstärker = seine Wirkung als Bild.


static func schluessel(block: SkillBlock) -> String:
	return "klotz|%s" % block.id


static func textur(studio: PortraitStudio, block: SkillBlock) -> Texture2D:
	return studio.textur(schluessel(block), func() -> Node3D: return bauen(block))


static func bauen(block: SkillBlock) -> Node3D:
	var n := Node3D.new()
	if block is SourceBlock:
		if block.source == Enums.SkillSource.WEAPON:
			_schwert(n, Vector3.ZERO, 35.0)
		else:
			_kugel_leuchtend(n, Vector3(0, 0.45, 0), 0.32, _p("lila"))
			_ring(n, Vector3(0, 0.45, 0), 0.5, _p("gold"), Vector3(70, 0, 15))
	elif block is ElementBlock:
		_element(n, block.element)
	elif block is FormBlock:
		_form(n, block.form)
	elif block is EffectBlock:
		_effekt(n, block.status)
	elif block is ModifierBlock:
		_verstaerker(n, block.modifier)
	else:
		_kugel_leuchtend(n, Vector3(0, 0.4, 0), 0.3, _p("weiss"))
	return n


static func _p(name: String) -> Color:
	return Stil3D.farbe(name)


# --- Elemente ---------------------------------------------------------------------

static func _element(n: Node3D, element: Enums.Element) -> void:
	match element:
		Enums.Element.FIRE:
			Stil3D.teil(n, Stil3D.kegel(0.32, 0.85), _p("flamme"), Vector3(0, 0.43, 0), Vector3.ZERO, true, _p("flamme") * 0.6)
			Stil3D.teil(n, Stil3D.kegel(0.18, 0.5), _p("glut"), Vector3(0, 0.3, 0.12), Vector3.ZERO, false, _p("glut") * 0.8)
		Enums.Element.ICE:
			for i in 3:
				Stil3D.teil(n, Stil3D.prisma(0.22, 0.8 - i * 0.18, 0.22), _p("kristall"),
					Vector3((i - 1) * 0.24, (0.8 - i * 0.18) * 0.5, 0), Vector3(0, 0, (i - 1) * -18.0), true, _p("kristall") * 0.3)
		Enums.Element.LIGHTNING:
			var punkte := [Vector3(0.15, 0.95, 0), Vector3(-0.12, 0.55, 0), Vector3(0.14, 0.45, 0), Vector3(-0.15, 0.0, 0)]
			for i in 3:
				var a: Vector3 = punkte[i]
				var b: Vector3 = punkte[i + 1]
				var stueck := Stil3D.teil(n, Stil3D.box(0.13, a.distance_to(b) + 0.06, 0.08), _p("glut"), (a + b) * 0.5,
					Vector3.ZERO, true, _p("glut") * 0.7)
				stueck.rotation.z = -atan2(b.x - a.x, a.y - b.y)
		Enums.Element.POISON:
			Stil3D.teil(n, Stil3D.kugel(0.3), _p("moos"), Vector3(0, 0.3, 0), Vector3.ZERO, true, _p("moos") * 0.3)
			Stil3D.teil(n, Stil3D.kegel(0.21, 0.4), _p("moos"), Vector3(0, 0.68, 0))
			Stil3D.teil(n, Stil3D.kugel(0.07), _p("schleim_hell"), Vector3(-0.1, 0.38, 0.27), Vector3.ZERO, false)
		Enums.Element.HOLY:
			Stil3D.teil(n, Stil3D.box(0.16, 0.9, 0.12), _p("gold"), Vector3(0, 0.45, 0), Vector3.ZERO, true, _p("glut") * 0.4)
			Stil3D.teil(n, Stil3D.box(0.6, 0.16, 0.12), _p("gold"), Vector3(0, 0.62, 0), Vector3.ZERO, true, _p("glut") * 0.4)
		Enums.Element.DARK:
			Stil3D.teil(n, Stil3D.kugel(0.32), _p("schwarz"), Vector3(0, 0.45, 0))
			_ring(n, Vector3(0, 0.45, 0), 0.48, _p("lila"), Vector3(65, 0, -20))
			Stil3D.teil(n, Stil3D.kugel(0.08), _p("lila"), Vector3(0.1, 0.52, 0.28), Vector3.ZERO, false, _p("lila"))
		_:
			_kugel_leuchtend(n, Vector3(0, 0.4, 0), 0.3, _p("weiss"))


# --- Formen -----------------------------------------------------------------------

static func _form(n: Node3D, form: Enums.SkillForm) -> void:
	match form:
		Enums.SkillForm.AOE:
			for i in 6:
				var w := TAU * i / 6.0
				Stil3D.teil(n, Stil3D.kugel(0.12), _p("flamme"), Vector3(cos(w) * 0.45, 0.12, sin(w) * 0.45))
			Stil3D.teil(n, Stil3D.kugel(0.16), _p("glut"), Vector3(0, 0.16, 0), Vector3.ZERO, true, _p("glut") * 0.5)
		Enums.SkillForm.ALLY:
			_maennchen(n, Vector3(-0.22, 0, 0), _p("ruestung"))
			_maennchen(n, Vector3(0.22, 0, 0), _p("moos"))
			Stil3D.teil(n, Stil3D.kugel(0.08), _p("schleim_hell"), Vector3(0.22, 0.95, 0), Vector3.ZERO, false, _p("schleim_hell"))
		Enums.SkillForm.AURA:
			_ring(n, Vector3(0, 0.05, 0), 0.55, _p("schleim_hell"), Vector3.ZERO)
			for i in 3:
				var w := TAU * i / 3.0 + 0.5
				_maennchen(n, Vector3(cos(w) * 0.28, 0, sin(w) * 0.28), _p("ruestung"), 0.75)
		Enums.SkillForm.SELF:
			_maennchen(n, Vector3.ZERO, _p("ruestung"))
			_ring(n, Vector3(0, 0.05, 0), 0.4, _p("gold"), Vector3.ZERO)
		Enums.SkillForm.SUMMON:
			var wolf := FigurenBau.fuer_archetyp(&"wolf")
			n.add_child(wolf)
			_ring(n, Vector3(0, 0.03, 0), 0.6, _p("lila"), Vector3.ZERO)
		_:
			_kugel_leuchtend(n, Vector3(0, 0.4, 0), 0.3, _p("weiss"))


# --- Effekte (nach Status) --------------------------------------------------------

static func _effekt(n: Node3D, status: Enums.Status) -> void:
	match status:
		Enums.Status.SHIELD, Enums.Status.PROTECT, Enums.Status.DEF_UP:
			_schild(n, _p("ruestung") if status != Enums.Status.PROTECT else _p("gold"))
		Enums.Status.ARMOR_BREAK:
			_schild(n, _p("stein"))
			Stil3D.teil(n, Stil3D.prisma(0.2, 0.75, 0.12), _p("schwarz"), Vector3(0.05, 0.45, 0.1), Vector3(0, 0, 15))
		Enums.Status.ATK_UP:
			_pfeil(n, _p("flamme"), true)
		Enums.Status.WEAKEN:
			_pfeil(n, _p("lila"), false)
		Enums.Status.SLOW:
			Stil3D.teil(n, Stil3D.kegel(0.3, 0.42), _p("braun_hell"), Vector3(0, 0.66, 0), Vector3(180, 0, 0))
			Stil3D.teil(n, Stil3D.kegel(0.3, 0.42), _p("braun_hell"), Vector3(0, 0.21, 0))
			Stil3D.teil(n, Stil3D.box(0.7, 0.06, 0.2), _p("holz"), Vector3(0, 0.88, 0))
			Stil3D.teil(n, Stil3D.box(0.7, 0.06, 0.2), _p("holz"), Vector3(0, 0.0, 0))
		Enums.Status.STUN:
			for i in 5:
				var w := TAU * i / 5.0
				Stil3D.teil(n, Stil3D.prisma(0.22, 0.38, 0.1), _p("glut"),
					Vector3(sin(w) * 0.2, 0.45 + cos(w) * 0.2, 0), Vector3(0, 0, -rad_to_deg(w)), true, _p("glut") * 0.5)
			Stil3D.teil(n, Stil3D.kugel(0.16), _p("glut"), Vector3(0, 0.45, 0), Vector3.ZERO, false, _p("glut") * 0.6)
		Enums.Status.REGEN, Enums.Status.REVIVE:
			var farbe := _p("schleim") if status == Enums.Status.REGEN else _p("gold")
			Stil3D.teil(n, Stil3D.box(0.22, 0.75, 0.16), farbe, Vector3(0, 0.45, 0), Vector3.ZERO, true, farbe * 0.4)
			Stil3D.teil(n, Stil3D.box(0.75, 0.22, 0.16), farbe, Vector3(0, 0.45, 0), Vector3.ZERO, true, farbe * 0.4)
			if status == Enums.Status.REVIVE:
				_ring(n, Vector3(0, 0.95, 0), 0.25, _p("gold"), Vector3(90, 0, 0))
		Enums.Status.MANA_REGEN:
			_tropfen(n, _p("ruestung"))
		Enums.Status.LIFESTEAL, Enums.Status.BLEED:
			_tropfen(n, _p("daemon"))
			if status == Enums.Status.BLEED:
				Stil3D.teil(n, Stil3D.kugel(0.09), _p("daemon"), Vector3(0.32, 0.15, 0))
		Enums.Status.CLEANSE:
			for winkel in [0.0, 60.0, 120.0]:
				Stil3D.teil(n, Stil3D.box(0.1, 0.85, 0.08), _p("weiss"), Vector3(0, 0.45, 0), Vector3(0, 0, winkel), true, _p("weiss") * 0.5)
		Enums.Status.COUNTER:
			_schwert(n, Vector3(-0.08, 0, 0), 35.0)
			_schwert(n, Vector3(0.08, 0, 0.05), -35.0)
		Enums.Status.THORNS:
			Stil3D.teil(n, Stil3D.kugel(0.25), _p("holz"), Vector3(0, 0.45, 0))
			for i in 8:
				var w := TAU * i / 8.0
				Stil3D.teil(n, Stil3D.kegel(0.07, 0.25), _p("knochen"),
					Vector3(sin(w) * 0.3, 0.45 + cos(w) * 0.3, 0), Vector3(0, 0, -rad_to_deg(w)))
		Enums.Status.MARKED:
			_ring(n, Vector3(0, 0.45, 0), 0.42, _p("daemon"), Vector3(90, 0, 0))
			_ring(n, Vector3(0, 0.45, 0), 0.22, _p("daemon"), Vector3(90, 0, 0))
			Stil3D.teil(n, Stil3D.kugel(0.08), _p("daemon"), Vector3(0, 0.45, 0))
		Enums.Status.FIRST_STRIKE:
			Stil3D.teil(n, Stil3D.box(0.7, 0.12, 0.1), _p("glut"), Vector3(-0.08, 0.45, 0), Vector3.ZERO, true, _p("glut") * 0.4)
			Stil3D.teil(n, Stil3D.kegel(0.18, 0.3), _p("glut"), Vector3(0.38, 0.45, 0), Vector3(0, 0, -90), true, _p("glut") * 0.4)
		_:
			_kugel_leuchtend(n, Vector3(0, 0.4, 0), 0.28, _p("lila"))


# --- Verstärker -------------------------------------------------------------------

static func _verstaerker(n: Node3D, art: Enums.SkillModifier) -> void:
	match art:
		Enums.SkillModifier.POWER_AMP:
			for i in 2:
				Stil3D.teil(n, Stil3D.prisma(0.6, 0.3, 0.14), _p("gold"), Vector3(0, 0.28 + i * 0.32, 0), Vector3.ZERO, true, _p("glut") * 0.2)
		Enums.SkillModifier.MULTI_HIT:
			for i in 3:
				_schwert(n, Vector3((i - 1) * 0.22, 0, i * 0.03), 20.0 - i * 20.0, 0.75)
		Enums.SkillModifier.PIERCE_ARMOR:
			Stil3D.teil(n, Stil3D.box(0.5, 0.5, 0.08), _p("eisen"), Vector3(0, 0.45, -0.05))
			Stil3D.teil(n, Stil3D.box(0.95, 0.07, 0.07), _p("holz"), Vector3(0, 0.45, 0.06))
			Stil3D.teil(n, Stil3D.kegel(0.1, 0.22), _p("stein_hell"), Vector3(0.55, 0.45, 0.06), Vector3(0, 0, -90))
		Enums.SkillModifier.EXECUTE:
			Stil3D.teil(n, Stil3D.kugel(0.32, 0.6), _p("knochen"), Vector3(0, 0.5, 0))
			Stil3D.teil(n, Stil3D.box(0.3, 0.16, 0.25), _p("knochen"), Vector3(0, 0.22, 0))
			for x in [-0.12, 0.12]:
				Stil3D.teil(n, Stil3D.kugel(0.075), _p("schwarz"), Vector3(x, 0.52, 0.27), Vector3.ZERO, false)
		Enums.SkillModifier.SPREAD:
			Stil3D.teil(n, Stil3D.kugel(0.16), _p("flamme"), Vector3(0, 0.45, 0), Vector3.ZERO, true, _p("flamme") * 0.4)
			for i in 6:
				var w := TAU * i / 6.0
				Stil3D.teil(n, Stil3D.prisma(0.12, 0.22, 0.08), _p("eisen"),
					Vector3(sin(w) * 0.36, 0.45 + cos(w) * 0.36, 0), Vector3(0, 0, -rad_to_deg(w)))
		Enums.SkillModifier.CHAIN_ON_KILL:
			for i in 3:
				_ring(n, Vector3((i - 1) * 0.3, 0.45, 0), 0.18, _p("eisen"), Vector3(0, 90 * (i % 2), 0))
		Enums.SkillModifier.ECHO:
			for i in 3:
				_ring(n, Vector3(0, 0.45, 0), 0.16 + i * 0.15, _p("lila"), Vector3(90, 0, 0))
		Enums.SkillModifier.OVERLOAD:
			Stil3D.teil(n, Stil3D.prisma(0.45, 0.4, 0.3), _p("daemon"), Vector3(0, 0.62, 0), Vector3.ZERO, true, _p("daemon") * 0.5)
			Stil3D.teil(n, Stil3D.prisma(0.45, 0.4, 0.3), _p("daemon"), Vector3(0, 0.22, 0), Vector3(180, 0, 0), true, _p("daemon") * 0.5)
		Enums.SkillModifier.COST_REDUCTION:
			_tropfen(n, _p("ruestung"))
			Stil3D.teil(n, Stil3D.box(0.3, 0.07, 0.07), _p("weiss"), Vector3(0, 0.32, 0.3), Vector3.ZERO, false)
		Enums.SkillModifier.VS_UNDEAD:
			Stil3D.teil(n, Stil3D.kugel(0.26, 0.5), _p("knochen"), Vector3(0, 0.35, 0))
			Stil3D.teil(n, Stil3D.box(0.1, 0.45, 0.08), _p("gold"), Vector3(0.22, 0.65, 0.2), Vector3.ZERO, true, _p("glut") * 0.3)
			Stil3D.teil(n, Stil3D.box(0.3, 0.1, 0.08), _p("gold"), Vector3(0.22, 0.75, 0.2), Vector3.ZERO, true, _p("glut") * 0.3)
		Enums.SkillModifier.OVERHEAL_SHIELD:
			_schild(n, _p("schleim"))
		_:
			_kugel_leuchtend(n, Vector3(0, 0.4, 0), 0.28, _p("gold"))


# --- Bausteine der Icons ------------------------------------------------------------

static func _schwert(n: Node3D, pos: Vector3, neigung: float, groesse := 1.0) -> void:
	var s := Node3D.new()
	n.add_child(s)
	s.position = pos
	s.rotation_degrees = Vector3(0, 0, neigung)
	Stil3D.teil(s, Stil3D.box(0.12 * groesse, 0.62 * groesse, 0.04), _p("stein_hell"), Vector3(0, 0.55 * groesse, 0))
	Stil3D.teil(s, Stil3D.box(0.36 * groesse, 0.07, 0.08), _p("gold"), Vector3(0, 0.22 * groesse, 0))
	Stil3D.teil(s, Stil3D.zylinder(0.04, 0.04, 0.2 * groesse), _p("holz"), Vector3(0, 0.08 * groesse, 0))


static func _schild(n: Node3D, farbe: Color) -> void:
	Stil3D.teil(n, Stil3D.zylinder(0.4, 0.4, 0.1), farbe, Vector3(0, 0.45, 0), Vector3(90, 0, 0))
	Stil3D.teil(n, Stil3D.kugel(0.1), _p("gold"), Vector3(0, 0.45, 0.07))


static func _pfeil(n: Node3D, farbe: Color, hoch: bool) -> void:
	var r := 0.0 if hoch else 180.0
	Stil3D.teil(n, Stil3D.box(0.2, 0.45, 0.14), farbe, Vector3(0, 0.3 if hoch else 0.6, 0))
	Stil3D.teil(n, Stil3D.prisma(0.55, 0.35, 0.14), farbe, Vector3(0, 0.68 if hoch else 0.22, 0), Vector3(0, 0, r))


static func _tropfen(n: Node3D, farbe: Color) -> void:
	Stil3D.teil(n, Stil3D.kugel(0.3), farbe, Vector3(0, 0.3, 0), Vector3.ZERO, true, farbe * 0.25)
	Stil3D.teil(n, Stil3D.kegel(0.21, 0.4), farbe, Vector3(0, 0.68, 0))


static func _maennchen(n: Node3D, pos: Vector3, farbe: Color, groesse := 1.0) -> void:
	Stil3D.teil(n, Stil3D.kapsel(0.14 * groesse, 0.5 * groesse), farbe, pos + Vector3(0, 0.25 * groesse, 0))
	Stil3D.teil(n, Stil3D.kugel(0.15 * groesse), _p("haut"), pos + Vector3(0, 0.62 * groesse, 0))


static func _kugel_leuchtend(n: Node3D, pos: Vector3, r: float, farbe: Color) -> void:
	Stil3D.teil(n, Stil3D.kugel(r), farbe, pos, Vector3.ZERO, true, farbe * 0.5)


static func _ring(n: Node3D, pos: Vector3, r: float, farbe: Color, rot: Vector3) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = r * 0.82
	torus.outer_radius = r
	Stil3D.teil(n, torus, farbe, pos, rot, false, farbe * 0.3)
