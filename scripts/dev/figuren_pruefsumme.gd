extends SceneTree
## Dev-Werkzeug: Prüfsummen aller Figuren (Helden-Kombinationen und Gegner)
## für Vorher/Nachher-Vergleiche bei Grafik-Korrekturen. Je Figur eine Zeile
## "<schlüssel> <mesh-md5> <posen-md5>": mesh = alle Meshes (Rumpf, Glieder,
## Hüllen, Schmuck) samt Lage, posen = Glied-Drehungen in Idle, Gehen,
## Angriff, Treffer, Phase und allen Sonderposen.
##   godot --headless --path . -s scripts/dev/figuren_pruefsumme.gd -- --aus=<datei.txt>
## Vergleich: diff vorher.txt nachher.txt (nur Figuren mit Befund dürfen fehlen).

const WAFFEN := ["", "schwert", "zweihandschwert", "dolch", "axt", "zweihandaxt", "knueppel", "kriegshammer",
	"bogen", "armbrust", "turmschild", "offensivstab", "heiligstab"]
const NEBEN := ["", "schild", "dolch", "koecher", "zauberbuch", "kristallfokus", "relikt", "heiligkreuz"]
const FARBEN := ["ruestung", "obsidian", "silber", "gold", "drachenblut"]
const POSEN := ["panzer", "segen", "ruf", "woge", "heulen", "stachel"]


func _init() -> void:
	var aus := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--aus="):
			aus = arg.substr(6)
	var zeilen: Array[String] = []
	var klassen := {"keine": Enums.ArmorClass.NONE, "leder": Enums.ArmorClass.LEATHER,
		"kette": Enums.ArmorClass.CHAIN, "platte": Enums.ArmorClass.PLATE}
	# Helden: unbekannte Ausrüstung (Farbwahl-Tank) und alle Kombinationen
	for farbe in FARBEN:
		zeilen.append(_zeile("held|%s|std" % farbe, FigurenBau.held_mit(Stil3D.farbe(farbe))))
	for waffe in WAFFEN:
		for neben in NEBEN:
			for klasse in klassen:
				for farbe in (FARBEN if klasse == "platte" else ["ruestung", "obsidian"]):
					for element in ["", "feuer"]:
						if element != "" and not waffe in ["offensivstab", "heiligstab"] and neben != "kristallfokus":
							continue
						var a := {"bekannt": true, "waffe": waffe, "neben": neben, "ruestung": klassen[klasse],
							"haar": (WAFFEN.find(waffe) + NEBEN.find(neben)) % 15}
						if element != "":
							a["element"] = element
						var key := "held|%s|%s|%s|%s|%s" % [farbe, waffe, neben, klasse, element]
						zeilen.append(_zeile(key, FigurenBau.held_mit(Stil3D.farbe(farbe), a)))
	# Gegner: alle Archetypen normal, Boss, Elite, Klassen-Varianten, Element
	var arten: Array = [&"troll"]
	arten.append_array(ZweibeinerBau.ARTEN)
	arten.append_array(VierbeinerBau.ARTEN)
	arten.append_array(KreaturenBau.ARTEN)
	for id in arten:
		var optionen := {"normal": {}, "boss": {"boss": true, "massstab": FigurenBau.KAMPF_BOSS_MASSSTAB},
			"dungeonboss": {"boss": true, "massstab": 1.5}, "elite": {"akzent": Stil3D.farbe("lila")},
			"krieger": {"variante": "krieger"}, "magier": {"variante": "magier"}, "feuer": {"element": Enums.Element.FIRE}}
		for name in optionen:
			zeilen.append(_zeile("gegner|%s|%s" % [id, name], FigurenBau.fuer_archetyp(id, optionen[name])))
	var text := "\n".join(zeilen) + "\n"
	if aus != "":
		var f := FileAccess.open(aus, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	print("PRUEFSUMMEN %d Figuren" % zeilen.size())
	quit(0)


func _zeile(key: String, figur: Node3D) -> String:
	var mesh := HashingContext.new()
	mesh.start(HashingContext.HASH_MD5)
	for mi in figur.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		mesh.update(var_to_bytes([String(figur.get_path_to(m)), _lage(figur, m)]))
		if m.mesh is ArrayMesh:
			for s in (m.mesh as ArrayMesh).get_surface_count():
				mesh.update(var_to_bytes((m.mesh as ArrayMesh).surface_get_arrays(s)))
		elif m.mesh != null:
			mesh.update(var_to_bytes(m.mesh.get_class()))
	var posen := HashingContext.new()
	posen.start(HashingContext.HASH_MD5)
	if figur.has_meta("glieder"):
		var proben: Array = []
		for t in [0.0, 0.7, 1.9]:
			proben.append(Gliederpuppe.beleben(figur, t))
			proben.append(_drehungen(figur))
			proben.append(Gliederpuppe.beleben(figur, t, -1.0, -1.0, true))
			proben.append(_drehungen(figur))
		for t in [0.05, 0.12, 0.18, 0.24, 0.3, 0.36, 0.45, 0.6]:
			proben.append(Gliederpuppe.beleben(figur, -1.0, t))
			proben.append(_drehungen(figur))
			proben.append(Gliederpuppe.beleben(figur, -1.0, -1.0, t))
			proben.append(_drehungen(figur))
			proben.append(Gliederpuppe.beleben(figur, -1.0, -1.0, -1.0, false, t * 2.0))
			proben.append(_drehungen(figur))
		for pose in POSEN:
			for t in [0.15, 0.5, 1.0]:
				proben.append(Gliederpuppe.beleben(figur, -1.0, -1.0, -1.0, false, -1.0, t, pose))
				proben.append(_drehungen(figur))
				proben.append(Gliederpuppe.hub())
		posen.update(var_to_bytes(proben))
	figur.free()
	return "%s %s %s" % [key, mesh.finish().hex_encode(), posen.finish().hex_encode()]


func _lage(figur: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D()
	var k: Node = n
	while k != null and k != figur:
		t = (k as Node3D).transform * t
		k = k.get_parent()
	return t


func _drehungen(figur: Node3D) -> Array:
	var r: Array = []
	var glieder: Dictionary = figur.get_meta("glieder", {})
	var namen := glieder.keys()
	namen.sort()
	for n in namen:
		r.append([n, snapped((glieder[n] as Node3D).rotation, Vector3.ONE * 0.0001)])
	return r
