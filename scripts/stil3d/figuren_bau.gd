class_name FigurenBau
extends RefCounted
## Baut Monster, Helden und Objekte aus Stil3D-Grundkörpern.
## Konventionen: Boden bei y = 0, Blick nach +Z, 1 Einheit = 1 Dungeon-Feld,
## normale Gegner 0.6–1.0 hoch, große 1.2–1.5. Jede Figur ist ein Node3D
## mit Meta "wippen" (Idle-Amplitude) für die Lebendigkeit.



static func _wurzel(name: String, wippen := 0.03) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.set_meta("wippen", wippen)
	return n


static func schleim() -> Node3D:
	var n := _wurzel("Schleim", 0.0)
	n.set_meta("quetschen", 0.06)
	var c := Stil3D.farbe("schleim")
	Stil3D.teil(n, Stil3D.zylinder(0.46, 0.5, 0.05), Stil3D.farbe("schleim"), Vector3(0, 0.025, 0))  # Pfütze
	Stil3D.teil(n, Stil3D.kugel(0.42, 0.66), c, Vector3(0, 0.33, 0))                         # Körper
	Stil3D.teil(n, Stil3D.kegel(0.13, 0.26), c, Vector3(0.04, 0.72, -0.02), Vector3(0, 0, -14))  # Tropfenspitze
	Stil3D.teil(n, Stil3D.kugel(0.07), Stil3D.farbe("schleim_hell"), Vector3(-0.2, 0.5, 0.22), Vector3.ZERO, false)  # Glanz
	Stil3D.auge(n, Vector3(0, 0.47, 0.31), 0.11)                    # großes Stirnauge
	Stil3D.auge(n, Vector3(-0.13, 0.33, 0.35), 0.06)
	Stil3D.auge(n, Vector3(0.13, 0.33, 0.35), 0.06)
	Stil3D.braue(n, Vector3(-0.13, 0.4, 0.38), 0.12, -1.0)
	Stil3D.braue(n, Vector3(0.13, 0.4, 0.38), 0.12, 1.0)
	Stil3D.teil(n, Stil3D.kugel(0.1, 0.07), Stil3D.farbe("mund"), Vector3(0, 0.2, 0.38))     # Maul
	Stil3D.teil(n, Stil3D.kegel(0.025, 0.06), Stil3D.farbe("weiss"), Vector3(-0.05, 0.2, 0.42), Vector3(180, 0, 0), false)
	Stil3D.teil(n, Stil3D.kegel(0.025, 0.06), Stil3D.farbe("weiss"), Vector3(0.05, 0.2, 0.42), Vector3(180, 0, 0), false)
	return n


static func wolf() -> Node3D:
	var n := _wurzel("Wolf", 0.02)
	var fell := Stil3D.farbe("fell")
	var maehne := Stil3D.farbe("maehne")
	for x in [-0.12, 0.12]:
		for z in [-0.24, 0.22]:
			Stil3D.teil(n, Stil3D.zylinder(0.055, 0.065, 0.34), fell, Vector3(x, 0.17, z))       # Beine
	Stil3D.teil(n, Stil3D.kapsel(0.2, 0.78), fell, Vector3(0, 0.44, -0.02), Vector3(90, 0, 0))   # Rumpf
	Stil3D.teil(n, Stil3D.kapsel(0.06, 0.42), maehne, Vector3(0, 0.56, -0.48), Vector3(-55, 0, 0))  # Schwanz
	Stil3D.teil(n, Stil3D.kugel(0.25, 0.42), maehne, Vector3(0, 0.56, 0.24))                     # Mähne
	for i in 5:
		var w := -50.0 + i * 25.0
		Stil3D.teil(n, Stil3D.kegel(0.07, 0.24), maehne,
			Vector3(sin(deg_to_rad(w)) * 0.2, 0.72, 0.18 - cos(deg_to_rad(w)) * 0.06),
			Vector3(-35, 0, -w * 0.8))
	Stil3D.teil(n, Stil3D.box(0.3, 0.26, 0.28), fell, Vector3(0, 0.64, 0.42))                   # Kopf
	Stil3D.teil(n, Stil3D.box(0.15, 0.11, 0.17), Stil3D.farbe("fell") * 1.12, Vector3(0, 0.58, 0.62))  # Schnauze
	Stil3D.teil(n, Stil3D.box(0.08, 0.06, 0.05), Stil3D.farbe("schwarz"), Vector3(0, 0.62, 0.71), Vector3.ZERO, false)
	Stil3D.teil(n, Stil3D.kegel(0.07, 0.17), fell, Vector3(-0.1, 0.84, 0.38), Vector3(0, 0, 12))   # Ohren
	Stil3D.teil(n, Stil3D.kegel(0.07, 0.17), fell, Vector3(0.1, 0.84, 0.38), Vector3(0, 0, -12))
	for x in [-0.08, 0.08]:
		Stil3D.teil(n, Stil3D.kugel(0.035), Stil3D.farbe("glut"), Vector3(x, 0.69, 0.56), Vector3.ZERO, false,
			Stil3D.farbe("glut") * 0.9)                                                    # Glutaugen
	Stil3D.teil(n, Stil3D.kegel(0.022, 0.06), Stil3D.farbe("weiss"), Vector3(-0.05, 0.5, 0.67), Vector3(180, 0, 0), false)
	Stil3D.teil(n, Stil3D.kegel(0.022, 0.06), Stil3D.farbe("weiss"), Vector3(0.05, 0.5, 0.67), Vector3(180, 0, 0), false)
	return n


static func golem() -> Node3D:
	var n := _wurzel("Golem", 0.015)
	var stein := Stil3D.farbe("stein")
	var moos := Stil3D.farbe("moos")
	Stil3D.teil(n, Stil3D.box(0.26, 0.36, 0.28), Stil3D.farbe("stein_dunkel"), Vector3(-0.19, 0.18, 0))  # Beine
	Stil3D.teil(n, Stil3D.box(0.26, 0.36, 0.28), Stil3D.farbe("stein_dunkel"), Vector3(0.19, 0.18, 0))
	Stil3D.teil(n, Stil3D.box(0.72, 0.56, 0.46), stein, Vector3(0, 0.66, 0))                       # Torso
	Stil3D.teil(n, Stil3D.box(0.34, 0.28, 0.32), stein, Vector3(0, 1.08, 0.04))                    # Kopf
	Stil3D.teil(n, Stil3D.kugel(0.075), Stil3D.farbe("glut"), Vector3(0, 1.1, 0.2), Vector3.ZERO, true,
		Stil3D.farbe("glut"))                                                                # Glutauge
	for seite in [-1.0, 1.0]:
		Stil3D.teil(n, Stil3D.box(0.24, 0.52, 0.26), stein, Vector3(0.5 * seite, 0.62, 0), Vector3(0, 0, 6 * seite))
		Stil3D.teil(n, Stil3D.box(0.32, 0.3, 0.32), Stil3D.farbe("stein_hell"), Vector3(0.54 * seite, 0.26, 0.05))  # Fäuste
		Stil3D.teil(n, Stil3D.kugel(0.21, 0.15), moos, Vector3(0.3 * seite, 0.95, 0))                         # Moos
	Stil3D.teil(n, Stil3D.kegel(0.07, 0.3), Stil3D.farbe("kristall"), Vector3(0.14, 1.02, -0.22), Vector3(-25, 0, -15),
		true, Stil3D.farbe("kristall") * 0.5)
	Stil3D.teil(n, Stil3D.kegel(0.05, 0.22), Stil3D.farbe("kristall"), Vector3(-0.12, 0.98, -0.24), Vector3(-30, 0, 20),
		true, Stil3D.farbe("kristall") * 0.5)
	return n


static func fledermaus() -> Node3D:
	var n := _wurzel("Fledermaus", 0.08)
	var lila := Stil3D.farbe("lila")
	Stil3D.teil(n, Stil3D.kugel(0.2, 0.36), lila, Vector3(0, 0.95, 0))                              # Körper
	Stil3D.teil(n, Stil3D.kegel(0.07, 0.2), lila, Vector3(-0.1, 1.17, 0), Vector3(0, 0, 15))         # Ohren
	Stil3D.teil(n, Stil3D.kegel(0.07, 0.2), lila, Vector3(0.1, 1.17, 0), Vector3(0, 0, -15))
	for seite in [-1.0, 1.0]:
		Stil3D.teil(n, Stil3D.prisma(0.5, 0.3, 0.03), Stil3D.farbe("lila_dunkel"),
			Vector3(0.4 * seite, 1.0, -0.04), Vector3(0, 0, -100 * seite))                  # Flügel
	Stil3D.auge(n, Vector3(-0.075, 1.0, 0.15), 0.065)
	Stil3D.auge(n, Vector3(0.075, 1.0, 0.15), 0.065)
	Stil3D.teil(n, Stil3D.kegel(0.03, 0.08), Stil3D.farbe("weiss"), Vector3(0.05, 0.86, 0.15), Vector3(180, 0, 0), false)
	return n


static func held() -> Node3D:
	var n := _wurzel("Held", 0.012)
	Stil3D.teil(n, Stil3D.box(0.13, 0.3, 0.15), Stil3D.farbe("ruestung_dunkel"), Vector3(-0.08, 0.15, 0))  # Beine
	Stil3D.teil(n, Stil3D.box(0.13, 0.3, 0.15), Stil3D.farbe("ruestung_dunkel"), Vector3(0.08, 0.15, 0))
	Stil3D.teil(n, Stil3D.box(0.4, 0.5, 0.05), Stil3D.farbe("umhang"), Vector3(0, 0.55, -0.16), Vector3(12, 0, 0))  # Umhang
	Stil3D.teil(n, Stil3D.zylinder(0.19, 0.23, 0.44), Stil3D.farbe("ruestung"), Vector3(0, 0.52, 0))      # Rumpf
	Stil3D.teil(n, Stil3D.box(0.4, 0.06, 0.3), Stil3D.farbe("holz"), Vector3(0, 0.36, 0), Vector3.ZERO, false)  # Gürtel
	Stil3D.teil(n, Stil3D.kugel(0.17), Stil3D.farbe("haut"), Vector3(0, 0.88, 0))                         # Kopf
	Stil3D.teil(n, Stil3D.kugel(0.19, 0.2), Stil3D.farbe("eisen"), Vector3(0, 0.98, -0.01))               # Helm
	Stil3D.teil(n, Stil3D.kegel(0.04, 0.16), Stil3D.farbe("umhang"), Vector3(0, 1.12, -0.04))             # Helmbusch
	for x in [-0.06, 0.06]:
		Stil3D.teil(n, Stil3D.kugel(0.028), Stil3D.farbe("schwarz"), Vector3(x, 0.88, 0.155), Vector3.ZERO, false)
	Stil3D.teil(n, Stil3D.kapsel(0.06, 0.3), Stil3D.farbe("ruestung"), Vector3(-0.27, 0.56, 0.02), Vector3(0, 0, 12))  # Arme
	Stil3D.teil(n, Stil3D.kapsel(0.06, 0.3), Stil3D.farbe("ruestung"), Vector3(0.27, 0.56, 0.02), Vector3(0, 0, -12))
	Stil3D.teil(n, Stil3D.zylinder(0.18, 0.18, 0.05), Stil3D.farbe("ruestung_dunkel"), Vector3(-0.33, 0.55, 0.1),
		Vector3(90, 0, 0))                                                               # Schild
	Stil3D.teil(n, Stil3D.kugel(0.05), Stil3D.farbe("gold"), Vector3(-0.33, 0.55, 0.14), Vector3.ZERO, false)
	Stil3D.teil(n, Stil3D.box(0.05, 0.6, 0.025), Stil3D.farbe("weiss"), Vector3(0.32, 0.72, 0.1))          # Klinge
	Stil3D.teil(n, Stil3D.box(0.18, 0.04, 0.05), Stil3D.farbe("gold"), Vector3(0.32, 0.44, 0.1))           # Parierstange
	return n


# --- Objekte -----------------------------------------------------------------

static func truhe() -> Node3D:
	var n := _wurzel("Truhe", 0.0)
	Stil3D.teil(n, Stil3D.box(0.62, 0.36, 0.42), Stil3D.farbe("holz"), Vector3(0, 0.18, 0))
	Stil3D.teil(n, Stil3D.box(0.64, 0.16, 0.44), Stil3D.farbe("holz_hell"), Vector3(0, 0.44, 0))
	for x in [-0.2, 0.2]:
		Stil3D.teil(n, Stil3D.box(0.06, 0.54, 0.45), Stil3D.farbe("eisen"), Vector3(x, 0.27, 0), Vector3.ZERO, false)
	Stil3D.teil(n, Stil3D.box(0.12, 0.14, 0.05), Stil3D.farbe("gold"), Vector3(0, 0.33, 0.23))
	return n


static func fackel() -> Node3D:
	var n := _wurzel("Fackel", 0.0)
	Stil3D.teil(n, Stil3D.zylinder(0.05, 0.035, 0.3), Stil3D.farbe("holz"), Vector3(0, 0, 0), Vector3(-20, 0, 0))
	Stil3D.teil(n, Stil3D.kugel(0.08, 0.14), Stil3D.farbe("flamme"), Vector3(0, 0.18, 0.05), Vector3.ZERO, false,
		Stil3D.farbe("flamme"))
	Stil3D.teil(n, Stil3D.kugel(0.045, 0.09), Stil3D.farbe("glut"), Vector3(0, 0.2, 0.07), Vector3.ZERO, false,
		Stil3D.farbe("glut"))
	var licht := OmniLight3D.new()
	licht.light_color = Color(1.0, 0.55, 0.22)
	licht.light_energy = 0.7
	licht.omni_range = 3.2
	licht.position = Vector3(0, 0.25, 0.3)
	n.add_child(licht)
	n.set_meta("licht", licht)
	return n
