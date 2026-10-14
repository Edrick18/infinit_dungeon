class_name GegenstandIcons
extends RefCounted
## 3D-Icons für Ausrüstung (Inventar-Raster, Slots) im STIL-3D-Look: je
## Basis-Item eine kleine Figur aus Grundkörpern, die PortraitStudio einmal
## in eine Textur rendert. Die Rarität zeigt der Rahmen in der UI, nicht das
## Icon — so reicht ein Icon pro Basis.


static func schluessel(base: ItemBase) -> String:
	return "item|%s" % base.id


static func textur(studio: PortraitStudio, base: ItemBase) -> Texture2D:
	return studio.textur(schluessel(base), func() -> Node3D: return bauen(base))


static func _p(name: String) -> Color:
	return Stil3D.farbe(name)


static func bauen(base: ItemBase) -> Node3D:
	var n := Node3D.new()
	match base.id:
		&"schwert": _klinge(n, 0.75, 0.09, -35.0)
		&"zweihandschwert": _klinge(n, 1.1, 0.13, -35.0)
		&"dolch": _klinge(n, 0.42, 0.08, -35.0)
		&"axt": _axt(n, 0.8, 0.28)
		&"zweihandaxt": _axt(n, 1.05, 0.42)
		&"knueppel":
			var k := _gekippt(n, -35.0)
			Stil3D.teil(k, Stil3D.zylinder(0.13, 0.05, 0.8), _p("holz"), Vector3(0, 0.4, 0))
			for i in 3:
				Stil3D.teil(k, Stil3D.kegel(0.05, 0.1), _p("eisen"), Vector3(0.12 * (i - 1), 0.72, 0.12), Vector3(90, 0, 0))
		&"kriegshammer":
			var k := _gekippt(n, -35.0)
			Stil3D.teil(k, Stil3D.zylinder(0.04, 0.045, 1.05), _p("holz"), Vector3(0, 0.5, 0))
			Stil3D.teil(k, Stil3D.box(0.42, 0.22, 0.22), _p("eisen"), Vector3(0, 1.0, 0))
		&"bogen":
			for teil in [[0.27, -20.0], [-0.27, 20.0]]:
				Stil3D.teil(n, Stil3D.zylinder(0.03, 0.035, 0.58), _p("holz"),
					Vector3(-0.08, 0.5 + teil[0], 0), Vector3(0, 0, teil[1]))
			Stil3D.teil(n, Stil3D.box(0.012, 1.05, 0.012), _p("weiss"), Vector3(0.0, 0.5, 0), Vector3.ZERO, false)
		&"armbrust":
			Stil3D.teil(n, Stil3D.box(0.14, 0.12, 0.85), _p("holz"), Vector3(0, 0.4, 0), Vector3(0, 40, 0))
			Stil3D.teil(n, Stil3D.box(0.9, 0.06, 0.08), _p("eisen"), Vector3(0.1, 0.46, 0.1), Vector3(0, 40, 0))
		&"offensivstab": _stab(n, _p("kristall"), false)
		&"heiligstab": _stab(n, _p("gold"), true)
		&"schild":
			Stil3D.teil(n, Stil3D.zylinder(0.45, 0.45, 0.1), _p("ruestung_dunkel"), Vector3(0, 0.45, 0), Vector3(90, 0, 0))
			Stil3D.teil(n, Stil3D.kugel(0.12), _p("gold"), Vector3(0, 0.45, 0.08))
		&"turmschild":
			Stil3D.teil(n, Stil3D.box(0.62, 0.95, 0.1), _p("ruestung_dunkel"), Vector3(0, 0.48, 0))
			Stil3D.teil(n, Stil3D.box(0.08, 0.8, 0.03), _p("gold"), Vector3(0, 0.48, 0.06), Vector3.ZERO, false)
			Stil3D.teil(n, Stil3D.box(0.5, 0.08, 0.03), _p("gold"), Vector3(0, 0.62, 0.06), Vector3.ZERO, false)
		&"zauberbuch":
			Stil3D.teil(n, Stil3D.box(0.55, 0.7, 0.18), _p("daemon_dunkel"), Vector3(0, 0.4, 0), Vector3(0, 20, 0))
			Stil3D.teil(n, Stil3D.box(0.5, 0.64, 0.14), _p("knochen"), Vector3(0.04, 0.4, 0.01), Vector3(0, 20, 0))
			Stil3D.teil(n, Stil3D.kugel(0.07), _p("kristall"), Vector3(-0.02, 0.42, 0.12), Vector3.ZERO, true, _p("kristall"))
		&"kristallfokus":
			Stil3D.teil(n, Stil3D.prisma(0.32, 0.55, 0.32), _p("kristall"), Vector3(0, 0.62, 0), Vector3.ZERO, true, _p("kristall") * 0.5)
			Stil3D.teil(n, Stil3D.prisma(0.32, 0.3, 0.32), _p("kristall"), Vector3(0, 0.2, 0), Vector3(180, 0, 0), true, _p("kristall") * 0.5)
		&"relikt":
			Stil3D.teil(n, Stil3D.box(0.5, 0.4, 0.35), _p("gold"), Vector3(0, 0.3, 0))
			Stil3D.teil(n, Stil3D.kugel(0.12), _p("daemon"), Vector3(0, 0.56, 0), Vector3.ZERO, true, _p("daemon") * 0.5)
		&"heiligkreuz":
			Stil3D.teil(n, Stil3D.box(0.14, 0.85, 0.1), _p("gold"), Vector3(0, 0.45, 0), Vector3.ZERO, true, _p("glut") * 0.2)
			Stil3D.teil(n, Stil3D.box(0.55, 0.14, 0.1), _p("gold"), Vector3(0, 0.6, 0), Vector3.ZERO, true, _p("glut") * 0.2)
		&"koecher":
			Stil3D.teil(n, Stil3D.zylinder(0.16, 0.13, 0.75), _p("leder"), Vector3(0, 0.38, 0), Vector3(0, 0, -15))
			for x in [-0.06, 0.04, 0.12]:
				Stil3D.teil(n, Stil3D.zylinder(0.015, 0.015, 0.3), _p("holz"), Vector3(x + 0.1, 0.85, 0), Vector3(0, 0, -15))
				Stil3D.teil(n, Stil3D.kegel(0.04, 0.1), _p("weiss"), Vector3(x + 0.14, 1.02, 0), Vector3(0, 0, -15), false)
		&"ruestung_leicht": _torso(n, _p("leder"), false)
		&"ruestung_mittel": _torso(n, _p("eisen").lightened(0.15), false)
		&"ruestung_schwer": _torso(n, _p("stein_hell"), true)
		&"robe_schaden": _robe(n, _p("robe_lila"))
		&"robe_heil": _robe(n, _p("weiss"))
		&"robe_kampf": _robe(n, _p("ruestung"))
		&"helm_leicht":
			Stil3D.teil(n, Stil3D.kugel(0.38, 0.5), _p("leder"), Vector3(0, 0.3, 0))
			Stil3D.teil(n, Stil3D.box(0.8, 0.06, 0.5), _p("leder") * 0.85, Vector3(0, 0.3, 0.1))
		&"helm_schwer":
			Stil3D.teil(n, Stil3D.kugel(0.4, 0.6), _p("stein_hell"), Vector3(0, 0.35, 0))
			Stil3D.teil(n, Stil3D.box(0.5, 0.06, 0.06), _p("schwarz"), Vector3(0, 0.38, 0.38), Vector3.ZERO, false)
			Stil3D.teil(n, Stil3D.kegel(0.05, 0.25), _p("umhang"), Vector3(0, 0.86, 0))
		&"handschuhe_leicht": _handschuh(n, _p("leder"))
		&"handschuhe_schwer": _handschuh(n, _p("stein_hell"))
		&"stiefel_leicht": _stiefel(n, _p("leder"))
		&"stiefel_schwer": _stiefel(n, _p("stein_hell"))
		&"ring":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.26
			torus.outer_radius = 0.34
			Stil3D.teil(n, torus, _p("gold"), Vector3(0, 0.35, 0), Vector3(70, 0, 0))
			Stil3D.teil(n, Stil3D.kugel(0.1), _p("daemon"), Vector3(0, 0.66, 0.08), Vector3.ZERO, true, _p("daemon") * 0.5)
		&"amulett":
			var kette := TorusMesh.new()
			kette.inner_radius = 0.34
			kette.outer_radius = 0.37
			Stil3D.teil(n, kette, _p("gold"), Vector3(0, 0.75, 0), Vector3(80, 0, 0))
			Stil3D.teil(n, Stil3D.prisma(0.26, 0.3, 0.1), _p("gold"), Vector3(0, 0.28, 0.1), Vector3(180, 0, 0))
			Stil3D.teil(n, Stil3D.kugel(0.08), _p("kristall"), Vector3(0, 0.33, 0.16), Vector3.ZERO, true, _p("kristall"))
		_:
			Stil3D.teil(n, Stil3D.box(0.5, 0.5, 0.5), _p("eisen"), Vector3(0, 0.3, 0))
	return n


static func _gekippt(n: Node3D, winkel: float) -> Node3D:
	var k := Node3D.new()
	k.rotation_degrees = Vector3(0, 0, winkel)
	n.add_child(k)
	return k


static func _klinge(n: Node3D, laenge: float, breite: float, winkel: float) -> void:
	var k := _gekippt(n, winkel)
	Stil3D.teil(k, Stil3D.box(breite, laenge, 0.04), _p("stein_hell"), Vector3(0, 0.25 + laenge / 2.0, 0))
	Stil3D.teil(k, Stil3D.prisma(breite, breite * 1.2, 0.04), _p("stein_hell"), Vector3(0, 0.25 + laenge + breite * 0.6, 0))
	Stil3D.teil(k, Stil3D.box(breite * 3.2, 0.07, 0.09), _p("gold"), Vector3(0, 0.24, 0))
	Stil3D.teil(k, Stil3D.zylinder(0.04, 0.04, 0.22), _p("leder"), Vector3(0, 0.1, 0))
	Stil3D.teil(k, Stil3D.kugel(0.06), _p("gold"), Vector3(0, -0.02, 0))


static func _axt(n: Node3D, stiel: float, blatt: float) -> void:
	var k := _gekippt(n, -30.0)
	Stil3D.teil(k, Stil3D.zylinder(0.035, 0.04, stiel), _p("holz"), Vector3(0, stiel / 2.0, 0))
	Stil3D.teil(k, Stil3D.prisma(blatt, blatt * 0.9, 0.05), _p("stein_hell"),
		Vector3(blatt * 0.45, stiel - blatt * 0.3, 0), Vector3(0, 0, -90))


static func _stab(n: Node3D, licht: Color, heilig: bool) -> void:
	var k := _gekippt(n, -25.0)
	Stil3D.teil(k, Stil3D.zylinder(0.035, 0.045, 1.2), _p("holz"), Vector3(0, 0.6, 0))
	if heilig:
		Stil3D.teil(k, Stil3D.box(0.06, 0.3, 0.05), licht, Vector3(0, 1.32, 0), Vector3.ZERO, true, licht * 0.4)
		Stil3D.teil(k, Stil3D.box(0.22, 0.06, 0.05), licht, Vector3(0, 1.38, 0), Vector3.ZERO, true, licht * 0.4)
	else:
		Stil3D.teil(k, Stil3D.kugel(0.13), licht, Vector3(0, 1.3, 0), Vector3.ZERO, true, licht)


static func _torso(n: Node3D, farbe: Color, schwer: bool) -> void:
	Stil3D.teil(n, Stil3D.box(0.62, 0.7, 0.34), farbe, Vector3(0, 0.4, 0))
	for x in [-0.4, 0.4]:
		Stil3D.teil(n, Stil3D.kugel(0.17 if schwer else 0.13), farbe * 0.9, Vector3(x, 0.7, 0))
	Stil3D.teil(n, Stil3D.box(0.64, 0.08, 0.36), _p("leder") if not schwer else _p("gold"), Vector3(0, 0.15, 0))


static func _robe(n: Node3D, farbe: Color) -> void:
	Stil3D.teil(n, Stil3D.kegel(0.42, 0.95), farbe, Vector3(0, 0.45, 0))
	Stil3D.teil(n, Stil3D.box(0.5, 0.06, 0.3), _p("gold"), Vector3(0, 0.55, 0))
	Stil3D.teil(n, Stil3D.kugel(0.16, 0.5), farbe * 0.8, Vector3(0, 0.92, 0))


static func _handschuh(n: Node3D, farbe: Color) -> void:
	Stil3D.teil(n, Stil3D.box(0.4, 0.42, 0.18), farbe, Vector3(0, 0.45, 0))
	for i in 4:
		Stil3D.teil(n, Stil3D.box(0.08, 0.2, 0.12), farbe, Vector3(-0.15 + i * 0.1, 0.75, 0))
	Stil3D.teil(n, Stil3D.box(0.1, 0.18, 0.12), farbe, Vector3(0.26, 0.5, 0), Vector3(0, 0, -40))
	Stil3D.teil(n, Stil3D.zylinder(0.22, 0.24, 0.16), farbe * 0.8, Vector3(0, 0.18, 0))


static func _stiefel(n: Node3D, farbe: Color) -> void:
	Stil3D.teil(n, Stil3D.box(0.3, 0.6, 0.3), farbe, Vector3(0, 0.5, 0))
	Stil3D.teil(n, Stil3D.box(0.32, 0.22, 0.6), farbe, Vector3(0, 0.12, 0.14))
	Stil3D.teil(n, Stil3D.box(0.34, 0.06, 0.32), _p("leder") * 0.6, Vector3(0, 0.78, 0))
