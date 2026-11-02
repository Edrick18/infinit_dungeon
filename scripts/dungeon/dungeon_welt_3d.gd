class_name DungeonWelt3D
extends Node3D
## 3D-Darstellung des begehbaren Dungeons nach STIL-3D.md — reine Anzeige.
## Die Spiellogik (dungeon_scene.gd) rechnet unverändert in Karten-Pixeln;
## 32 px = 1 Feld = 1 Welteinheit (Karten-y wird Welt-z). Jedes Bild ruft
## sie aktualisieren() auf, diese Klasse spiegelt den Zustand in 3D.
##
## Boden und Wände sind MultiMeshes (Karten bis 88×76 Felder) mit den
## Material-Shadern aus WeltMaterial (Werte je Biom: BiomStil). Verdeckt
## eine Wand etwas, sinkt ihre Deckkraft (INSTANCE_CUSTOM.a) und der opake
## Wand-Shader lässt Bildpunkte aus (Glas-Regel, STIL-3D.md Abschnitt 7).
## Licht: Sonne + warme Laterne über dem Helden + ein kleiner Pool echter
## OmniLights, der jedes Bild an die nächsten Lichtquellen wandert (Fackeln,
## Treppe, Feuerschalen, Boss).
##
## Biom-Kulisse (BiomKulisse): Wandkronen und Deko als gebackene MultiMeshes
## (je Variante Körper + Kontur-Hülle); Kronen dithern mit ihrer Wand.
## Ziele tragen Lichtsäule und Bodenglühen (nur nahe dem Kamera-Ziel
## sichtbar), die Boss-Ebene bekommt Arena, Siegel, Feuerschalen und Banner.

const PX := 32.0  ## muss DungeonMap.TILE_SIZE entsprechen
const KAMERA_RICHTUNG := Vector3(11.0, 12.5, 11.0)  ## 45°-Diorama-Blick
## Kameraabstand klein halten: die Schattenreichweite zählt ab der Kamera.
const KAMERA_ABSTAND := 1.2
const ZOOM_START := 10.5
const ZOOM_MIN := 6.5
const ZOOM_MAX := 16.0
## Oberkante des Wandsockels = Unterkante des Wandkörpers.
const SOCKEL_OBEN := 0.14
const DECKEL_HOEHE := 0.12
const DECKKRAFT_GLAS := 0.25
const GLAS_TEMPO := 3.0
const FACKEL_CHANCE := 0.05
const FACKEL_FARBE := Color(1.0, 0.6, 0.3)
const VERSTECKT := Vector3(0, -100, 0)
## Glas-Regel: Wand liegt "vor" einem Ziel (Richtung Kamera) und seitlich nah.
const HELD_VOR_MAX := 5.0
const HELD_QUER_MAX := 3.0
const ZIEL_VOR_MAX := 2.6
const ZIEL_QUER_MAX := 1.1
const FACKEL_ENERGIE := 1.25
const LATERNE_ENERGIE := 0.85
## Lichtsäulen, Bodenglühen und örtliche Funken nur so nah am Kamera-Ziel.
const LOKAL_REICHWEITE := 13.0
const SAEULE_STAERKE := 1.0
## Boss im Dungeon: Größe als Teil-Maßstab im Mesh (Kontur bleibt 0.022) und
## Höhe seiner Lichtsäule (die höchste im Bild, Wegweiser schon im Gang).
const BOSS_MASSSTAB := 1.5
const BOSS_SAEULE_HOEHE := 9.0
const SCHREIN_FARBEN := {
	DungeonGenerator.EventType.SHRINE_HEAL: Color("6fe08a"),
	DungeonGenerator.EventType.SHRINE_MANA: Color("6fb0f0"),
	DungeonGenerator.EventType.SHRINE_POWER: Color("ff9a3a"),
	DungeonGenerator.EventType.SHRINE_WARD: Color("ffe07a"),
}


## Biom-Stil (Tönung, Deko, Material, Licht, Untergrund) — Datensatz in BiomStil.
static func biom_stil(biome: Enums.Biome) -> Dictionary:
	return BiomStil.fuer(biome)


## Stil einer Karte: Biom-Stil mit ihrer Varianten-Abwandlung (Namensteile, Seed).
static func karten_stil(card: DungeonCard) -> Dictionary:
	return BiomStil.fuer_karte(card)


var _map: DungeonMap
var _stil: Dictionary
var _kamera: Camera3D
var _zoom := ZOOM_START
var _blickpunkt := Vector3.ZERO
var _vor := Vector2(-1, -1).normalized()   ## Bodenrichtung "von der Kamera weg"
var _rechts := Vector2(1, -1).normalized()  ## Bodenrichtung "Bildschirm rechts"
var _koerper_mm: MultiMesh
var _deckel_mm: MultiMesh
## Vector2i » {"i": Instanz-Index, "alpha": float}
var _waende: Dictionary = {}
var _figuren: Dictionary = {}  ## Schlüssel » Node3D
var _labels: Dictionary = {}   ## Schlüssel » Label3D
var _fackeln: Array[Node3D] = []
## Lichtquellen des Pools: Ort, Farbe, Energie, Reichweite, flackert?
var _licht_orte: Array[Vector3] = []
var _licht_daten: Array[Dictionary] = []
var _boss_licht := -1  ## Index der Boss-Lichtquelle (nur solange er lebt)
var _boss_lebt := false
## Örtliche Effekte (Lichtsäulen, Funken) ohne Figur: nur nahe sichtbar.
var _lokal: Array[Node3D] = []
## Shader-Proben (vorwärmen), nach ein paar Bildern wieder entfernt.
var _proben: Array[Node3D] = []
var _bilder := 0
var _pool: Array[OmniLight3D] = []
var _laterne: OmniLight3D
var _held_mats: Array[ShaderMaterial] = []  ## Materialien mit Uniform held_pos
var _untergrund_mat: ShaderMaterial
var _partikel: CPUParticles3D
var _blob_mat: ShaderMaterial
var _ring_mat: ShaderMaterial
var _letzte_spielerpos := Vector3.ZERO
var _hopser := 0.0
var _zeit := 0.0


# --- Aufbau ------------------------------------------------------------------

## stil = BiomStil.fuer(biom) (bzw. DungeonWelt3D.biom_stil).
func aufbauen(map: DungeonMap, stil: Dictionary, deko: Array[Dictionary], start_px: Vector2) -> void:
	_map = map
	_stil = stil
	_blob_mat = WeltMaterial.material("blob", {"deckkraft": 0.55})
	_ring_mat = WeltMaterial.material("blob", {"farbe": Stil3D.farbe("gold"), "deckkraft": 0.85, "ring": 1.0})
	_umgebung()
	_boden_bauen()
	_waende_bauen()
	_treppe_bauen()
	_deko_bauen(deko)
	if _map.has_boss:
		_boss_raum_bauen()
	_kamera = Camera3D.new()
	_kamera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_kamera.size = _zoom
	_kamera.far = 120.0
	add_child(_kamera)
	_kamera.look_at_from_position(KAMERA_RICHTUNG * KAMERA_ABSTAND, Vector3.ZERO)
	_kamera.make_current()
	var b := _kamera.global_transform.basis
	_rechts = Vector2(b.x.x, b.x.z).normalized()
	_vor = Vector2(-b.z.x, -b.z.z).normalized()
	_blickpunkt = _welt(start_px)
	_kamera.position = _blickpunkt + KAMERA_RICHTUNG * KAMERA_ABSTAND
	_letzte_spielerpos = _blickpunkt
	_licht_bauen()
	_untergrund_bauen()
	_vorwaermen()


## Figuren der Ebene vorab backen (STIL-3D.md 7g, Mesh-Cache der
## Gliederpuppe): jede Gegnerart des Ebenen-Pools (auch spätere Nachschub-
## Arten), der Boss und der eigene Held. Sonst baut das erste Bild alle Arten
## auf einmal (Stufe 20: ~14 Arten, ~0.4 s) und jeder Nachschub einer neuen
## Art kostet mitten im Laufen einen Hänger. Danach legen Figuren nur noch
## Nodes an (< 0.1 ms).
func figuren_vorwaermen(arten: Array, boss_id: StringName, held: Combatant) -> void:
	FigurenBau.vorwaermen(arten, boss_id, BOSS_MASSSTAB, held)


## Shader vorwärmen: Compatibility übersetzt einen Shader erst beim ersten
## Zeichnen. Lichtsäulen, Siegel und Bodenglühen kämen sonst erst später ins
## Bild (Truhe taucht auf) und kosteten dann einen Hänger. Winzige Proben im
## Bodensockel am Kamera-Ziel (verdeckt, aber gezeichnet), nach ein paar
## Bildern wieder weg.
func _vorwaermen() -> void:
	for art in ["saeule", "lichtfleck", "siegel", "kulisse", "funke"]:
		var probe := MeshInstance3D.new()
		probe.mesh = Stil3D.box(0.02, 0.02, 0.02)
		probe.material_override = WeltMaterial.material(art)
		probe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		probe.position = _blickpunkt + Vector3(0, -0.3, 0)
		add_child(probe)
		_proben.append(probe)


func _umgebung() -> void:
	var welt := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = (_stil["tief"] as Color).srgb_to_linear()  # BG-Farbe erwartet linear
	Stil3D.umgebung(env, _stil["ambient"], _stil["ambient_energie"])
	env.tonemap_exposure *= float(_stil.get("belichtung", 1.0))
	welt.environment = env
	add_child(welt)
	var sonne := DirectionalLight3D.new()
	sonne.rotation_degrees = Vector3(-52, 112, 0)
	sonne.light_color = _stil["licht"]
	sonne.light_energy = _stil["licht_energie"]
	sonne.shadow_enabled = true
	sonne.shadow_blur = 1.5
	sonne.directional_shadow_max_distance = 40.0
	add_child(sonne)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().use_debanding = true  # dunkle Verläufe (Laterne, Nebel) ohne Treppen
	WeltMaterial.vignette(self, 0.42 + float(_stil.get("vignette_plus", 0.0)))


## Laterne des Helden (warm, weich auslaufend) + Licht-Pool für Fackeln.
func _licht_bauen() -> void:
	_laterne = OmniLight3D.new()
	_laterne.light_color = _stil["laterne"]
	_laterne.light_energy = LATERNE_ENERGIE * float(_stil.get("laterne_energie", 1.0))
	_laterne.omni_range = 6.0
	_laterne.omni_attenuation = 1.3
	add_child(_laterne)
	for i in WeltBau.POOL_GROESSE:
		var l := OmniLight3D.new()
		l.light_color = FACKEL_FARBE
		l.omni_range = 4.2
		l.omni_attenuation = 1.4
		l.visible = false
		add_child(l)
		_pool.append(l)


## Sternen-Nebel unter der Karte (statt schwarzer Leere) + Biom-Partikel.
func _untergrund_bauen() -> void:
	var ebene := PlaneMesh.new()
	ebene.size = Vector2(_map.width + 90, _map.height + 90)
	var mi := MeshInstance3D.new()
	mi.mesh = ebene
	_untergrund_mat = WeltMaterial.material("untergrund", {"tief": _stil["tief"],
		"nebel": _stil["nebel"], "schimmer": _stil["fuge"], "stern": Stil3D.farbe("stern")})
	mi.material_override = _untergrund_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(_map.width * 0.5, -2.6, _map.height * 0.5)
	add_child(mi)
	_partikel = WeltMaterial.partikel(_stil["partikel"], _stil["funke"], float(_stil.get("partikel_menge", 1.0)))
	_partikel.position = _blickpunkt + Vector3(0, 0.9, 0)
	add_child(_partikel)


func _multimesh(mesh: Mesh, anzahl: int, mat: Material, custom := false, schatten := true) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = anzahl
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	if not schatten:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mm


## Material mit Uniform held_pos (Leuchtfugen glimmen in Heldennähe).
func _held_mat(art: String, werte: Dictionary, kontur_modus := -1) -> ShaderMaterial:
	var mat := WeltMaterial.material(art, werte, kontur_modus)
	_held_mats.append(mat)
	return mat


func _boden_bauen() -> void:
	var zellen := _map.floor_cells()
	var platten := _multimesh(WeltMaterial.fasen_box(Vector3(0.965, 0.16, 0.965), 0.03), zellen.size(),
		_held_mat("boden", {"moos_farbe": _stil["moos"], "rune_farbe": _stil["fuge"],
			"biom": int(_stil.get("biom", 0)), "risse": float(_stil.get("risse", 0.28)),
			"bewuchs": float(_stil.get("bewuchs", 0.0)), "pfuetzen": float(_stil.get("pfuetzen", 0.0)),
			"pfuetze_farbe": _stil.get("pfuetze_farbe", Stil3D.farbe("wasser"))}), true)
	var sockel := _multimesh(Stil3D.box(1.0, 0.5, 1.0), zellen.size(),
		_held_mat("fuge", {"farbe": _stil["fuge"], "dunkel": Stil3D.farbe("fuge")}))
	var stein: Color = _stil["boden"]
	for i in zellen.size():
		var c := zellen[i]
		var mitte := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
		var platte := mitte + Vector3(0, -0.08 + float(absi(hash(c * 13)) % 5) * 0.004, 0)
		if c == _map.stairs_cell:
			platte = VERSTECKT  # Treppe hat ihr eigenes Loch
		var hell := 0.95 + float(absi(hash(c)) % 9) * 0.012
		var schach := 1.0 if (c.x + c.y) % 2 == 0 else 0.965
		# Leicht verdrehte Platten: jede liegt ein wenig anders (handgelegt).
		var dreh := Basis(Vector3.UP, (float(absi(hash(c * 7)) % 9) - 4.0) * 0.006)
		platten.set_instance_transform(i, Transform3D(dreh, platte))
		platten.set_instance_color(i, stein * (hell * schach))
		# Wand an Nord/Ost/Süd/West » Umgebungsverdeckung im Boden-Shader.
		platten.set_instance_custom_data(i, Color(
			0.0 if _map.is_floor(c + Vector2i(0, -1)) else 1.0,
			0.0 if _map.is_floor(c + Vector2i(1, 0)) else 1.0,
			0.0 if _map.is_floor(c + Vector2i(0, 1)) else 1.0,
			0.0 if _map.is_floor(c + Vector2i(-1, 0)) else 1.0))
		sockel.set_instance_transform(i, Transform3D(Basis(), mitte + Vector3(0, -0.27, 0)))
		sockel.set_instance_color(i, Color.WHITE)


## Nur Wandzellen, die an Boden grenzen, werden gebaut — darunter liegt der
## Sternen-Nebel (Räume schweben wie Dioramen über dem Untergrund).
func _waende_bauen() -> void:
	var zellen: Array[Vector2i] = []
	for y in _map.height:
		for x in _map.width:
			var c := Vector2i(x, y)
			if not _map.is_floor(c) and _grenzt_an_boden(c):
				zellen.append(c)
	var werte := {"moos_farbe": _stil["moos"], "moos": _stil["moos_wand"], "muster": _stil["muster"],
		"stein": _stil["stein"], "fuge_farbe": _stil["fuge"]}
	var sockel := _multimesh(Stil3D.box(1.0, 0.3, 1.0), zellen.size(), _held_mat("wand", werte, 1), true)
	_koerper_mm = _multimesh(Stil3D.box(1.0, 1.0, 1.0), zellen.size(), _held_mat("wand", werte, 1), true)
	var deckel_werte := werte.duplicate()
	deckel_werte["gras"] = _stil["moos_deckel"]
	deckel_werte["halb"] = Vector3(0.5, DECKEL_HOEHE * 0.5, 0.5)
	_deckel_mm = _multimesh(WeltMaterial.fasen_box(Vector3(1.0, DECKEL_HOEHE, 1.0), 0.035), zellen.size(),
		_held_mat("wand", deckel_werte), true)
	var wand: Color = _stil["wand"]
	var deckel: Color = _stil["deckel"]
	var kronen := {}  ## Variante » Array[[Zelle, Transform3D]]
	var kulisse: Dictionary = _stil.get("kulisse", {})
	var arten: Array = kulisse.get("kronen", [])
	var gang_ende := WeltBau.boss_raum(_map).position.x if _map.has_boss else -1
	var zacken := float(_stil.get("wand_zacken", 0.0))
	for i in zellen.size():
		var c := zellen[i]
		var mitte := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
		var h := WeltBau.wand_hoehe(c, zacken)
		var farbe := wand * (0.94 + float(absi(hash(c)) % 9) * 0.012)
		sockel.set_instance_transform(i, Transform3D(Basis(), mitte + Vector3(0, -0.01, 0)))
		sockel.set_instance_color(i, farbe * 0.8)
		sockel.set_instance_custom_data(i, Color(0, 0, 0, 1))
		_koerper_mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(1, h, 1)),
			mitte + Vector3(0, SOCKEL_OBEN + h * 0.5, 0)))
		_koerper_mm.set_instance_color(i, farbe)
		_koerper_mm.set_instance_custom_data(i, Color(0, 0, 0, 1))
		_deckel_mm.set_instance_transform(i, Transform3D(Basis(),
			mitte + Vector3(0, SOCKEL_OBEN + h + DECKEL_HOEHE * 0.5, 0)))
		_deckel_mm.set_instance_color(i, deckel * (0.96 + float(absi(hash(c * 5)) % 7) * 0.012))
		_deckel_mm.set_instance_custom_data(i, Color(0, 0, 0, 1))
		_waende[c] = {"i": i, "alpha": 1.0, "vor": ZIEL_VOR_MAX}
		var oben := SOCKEL_OBEN + h + DECKEL_HOEHE
		if not arten.is_empty() and WeltBau.hat_krone(c, float(kulisse.get("krone_anteil", 0.3))):
			var art: String = arten[WeltBau.kronen_variante(c, arten.size())]
			if not kronen.has(art):
				kronen[art] = []
			kronen[art].append([c, _kronen_lage(c, art, mitte + Vector3(0, oben, 0))])
		if gang_ende >= 0:
			if c.x < gang_ende:
				_boss_gang_schmuck(c, h)
		else:
			_fackel_pruefen(c, h)
	for art in kronen:
		_kronen_bauen(art, kronen[art])


func _grenzt_an_boden(c: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if (dx != 0 or dy != 0) and _map.is_floor(c + Vector2i(dx, dy)):
				return true
	return false


## Vereinzelte Fackeln an Wänden, die direkt an Boden grenzen (deterministisch).
## Sie tragen kein eigenes Licht — der Licht-Pool leuchtet die nächsten an.
func _fackel_pruefen(c: Vector2i, hoehe: float) -> void:
	if float(absi(hash(c * 7 + Vector2i(13, 29))) % 1000) / 1000.0 			> FACKEL_CHANCE * float(_stil.get("fackel_anteil", 1.0)):
		return
	for richtung in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		if _map.is_floor(c + richtung):
			_fackel_setzen(c, richtung, hoehe)
			return


func _fackel_setzen(c: Vector2i, richtung: Vector2i, hoehe: float) -> void:
	var f := FigurenBau.fackel(false, true)
	add_child(f)
	var aussen := Vector3(richtung.x, 0, richtung.y)
	f.position = Vector3(c.x + 0.5, SOCKEL_OBEN + hoehe - 0.3, c.y + 0.5) + aussen * 0.58
	f.rotation.y = atan2(float(richtung.x), float(richtung.y))
	_fackeln.append(f)
	# Glas-Regel: wird die Wand durchsichtig, verschwindet ihre Fackel mit —
	# sonst schwebt die Rückseite einer Fackel an der Gangseite einer
	# Vorderwand dunkel im Raster (Licht bleibt im Pool).
	var w: Dictionary = _waende.get(c, {})
	if not w.is_empty():
		if not w.has("fackeln"):
			w["fackeln"] = []
		w["fackeln"].append(f)
	_licht_dazu(f.position + aussen * 0.32 + Vector3(0, 0.22, 0), FACKEL_FARBE, FACKEL_ENERGIE, 4.2, true)


## Lichtquelle für den Pool (Fackel, Treppe, Feuerschale, Boss); Index zurück.
func _licht_dazu(ort: Vector3, farbe: Color, energie: float, reichweite: float, flackert: bool) -> int:
	_licht_orte.append(ort)
	_licht_daten.append({"farbe": farbe, "energie": energie, "reichweite": reichweite, "flackert": flackert})
	return _licht_orte.size() - 1


## Lage einer Wandkrone: Zinnen, Gruft und Grabplatten folgen der Wand
## (0° oder 90°), Bäume und Steine drehen frei; leichte Größenstreuung.
func _kronen_lage(c: Vector2i, art: String, oben: Vector3) -> Transform3D:
	var zufall := absi(hash(c * 13 + Vector2i(41, 7)))
	var winkel := float(zufall % 628) / 100.0
	if art in ["zinnen", "bruchkante", "gruftaufsatz", "kreuz", "grabplatte"]:
		var laengs_x := not _map.is_floor(c + Vector2i(1, 0)) and not _map.is_floor(c + Vector2i(-1, 0))
		winkel = 0.0 if laengs_x else PI * 0.5
		if art == "kreuz" or art == "gruftaufsatz":
			winkel = PI * 0.25 * (1.0 if laengs_x else -1.0) if zufall % 3 == 0 else winkel
	var skala := 0.86 + float(zufall % 7) * 0.04
	return Transform3D(Basis(Vector3.UP, winkel).scaled(Vector3.ONE * skala), oben)


## Eine Kronen-Variante als zwei MultiMeshes (Körper + Kontur-Hülle), beide
## mit Instanz-Deckkraft — sie dithern zusammen mit ihrer Wand (Glas-Regel).
func _kronen_bauen(art: String, lagen: Array) -> void:
	var bausatz := BiomKulisse.krone(art, _stil)
	var koerper_mat := WeltMaterial.material("kulisse_glas")
	var koerper_mesh := bausatz.mesh()
	var koerper := _multimesh(koerper_mesh, lagen.size(), koerper_mat, true)
	var huelle: MultiMesh = null
	if bausatz.hat_huelle():
		var rand := Stil3D.kontur(0, true)
		rand.set_shader_parameter("dicke", 0.0)
		huelle = _multimesh(bausatz.huelle(), lagen.size(), rand, true, false)
	var hoehe := koerper_mesh.get_aabb().end.y
	for i in lagen.size():
		var c: Vector2i = lagen[i][0]
		var t: Transform3D = lagen[i][1]
		var ton := 0.9 + float(absi(hash(c * 3)) % 9) * 0.025
		for mm in [koerper, huelle]:
			if mm == null:
				continue
			mm.set_instance_transform(i, t)
			mm.set_instance_color(i, Color(ton, ton, ton))
			mm.set_instance_custom_data(i, Color(0, 0, 0, 1))
		var w: Dictionary = _waende[c]
		w["krone"] = [koerper, huelle, i]
		# Höhere Silhouette verdeckt weiter nach hinten: Glas früher auslösen.
		w["vor"] = maxf(ZIEL_VOR_MAX, (t.origin.y + hoehe * t.basis.get_scale().y) * 1.25 + 0.2)


## Biom-Deko: Zellen und Generator-Art bleiben (Platzierung unverändert),
## die Kulisse wählt eine größere Biom-Variante; in schmalen Gängen nur
## flache, und die Gruppe rückt an die Wand — der Weg bleibt frei.
func _deko_bauen(deko: Array[Dictionary]) -> void:
	var gruppen := {}  ## Variante » Array[Transform3D]
	for eintrag in deko:
		var c: Vector2i = eintrag["cell"]
		var nachbarn := 0
		var zur_wand := Vector3.ZERO
		for r in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _map.is_floor(c + r):
				nachbarn += 1
			else:
				zur_wand += Vector3(r.x, 0, r.y)
		var schmal := nachbarn <= 2
		var art := BiomKulisse.deko_variante(_stil, String(eintrag["art"]), c, schmal)
		if art == "":
			var einzeln := FigurenBau.deko(eintrag["art"])
			add_child(einzeln)
			einzeln.position = Vector3(c.x + 0.5, 0.0, c.y + 0.5)
			continue
		var zufall := absi(hash(c * 11 + Vector2i(2, 9)))
		var versatz := zur_wand.normalized() * 0.16 if zur_wand != Vector3.ZERO else Vector3.ZERO
		var skala := 0.92 + float(zufall % 6) * 0.04
		var basis := Basis(Vector3.UP, float(zufall % 628) / 100.0).scaled(Vector3.ONE * skala)
		if not gruppen.has(art):
			gruppen[art] = []
		gruppen[art].append(Transform3D(basis, Vector3(c.x + 0.5, 0.0, c.y + 0.5) + versatz))
	_streu_sammeln(deko, gruppen)
	for art in gruppen:
		var bausatz := BiomKulisse.deko(art, _stil)
		var lagen: Array = gruppen[art]
		var koerper := _multimesh(bausatz.mesh(), lagen.size(), WeltMaterial.material("kulisse"))
		var huelle: MultiMesh = null
		if bausatz.hat_huelle():
			var rand := Stil3D.kontur(0)
			rand.set_shader_parameter("dicke", 0.0)
			huelle = _multimesh(bausatz.huelle(), lagen.size(), rand, false, false)
		for i in lagen.size():
			var ton := 0.94 + float(i % 5) * 0.03
			for mm in [koerper, huelle]:
				if mm != null:
					mm.set_instance_transform(i, lagen[i])
					mm.set_instance_color(i, Color(ton, ton, ton))


## Streu-Deko der Karten-Variante (BiomStil "streu"/"streu_anteil"): flache
## Stücke an Wandrändern auf freien Bodenzellen (Zell-Hash, immer gleich),
## nie auf Treppe, Start, Gegnern, Truhen, Ereignissen oder Generator-Deko.
## Reine Optik — sie landen in denselben Varianten-MultiMeshes wie die Deko.
func _streu_sammeln(deko: Array[Dictionary], gruppen: Dictionary) -> void:
	var arten: Array = _stil.get("streu", [])
	var anteil := float(_stil.get("streu_anteil", 0.0))
	if arten.is_empty() or anteil <= 0.0:
		return
	var belegt := {_map.stairs_cell: true, _map.spawn: true, _map.boss_cell: true, _map.tresor_cell: true}
	for eintrag in deko:
		belegt[eintrag["cell"]] = true
	for liste in [_map.enemies, _map.chests, _map.events]:
		for eintrag: Dictionary in liste:
			belegt[eintrag["cell"]] = true
	for c in _map.floor_cells():
		if belegt.has(c) or float(absi(hash(c * 19 + Vector2i(77, 3))) % 1000) / 1000.0 >= anteil:
			continue
		var zur_wand := Vector3.ZERO
		var nachbarn := 0
		for r in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _map.is_floor(c + r):
				nachbarn += 1
			else:
				zur_wand += Vector3(r.x, 0, r.y)
		if zur_wand == Vector3.ZERO:
			continue  # nur an Wandrändern — die Raummitte bleibt frei
		var zufall := absi(hash(c * 23 + Vector2i(4, 61)))
		var art := String(arten[zufall % arten.size()])
		if nachbarn <= 2 and art not in BiomKulisse.FLACH:
			continue
		var richtung := zur_wand.normalized()
		# Spinnweben hängen in der Ecke: Rückseite zur Wand (lokal -z).
		var winkel := atan2(-richtung.x, -richtung.z) if art == "spinnweben" else float(zufall % 628) / 100.0
		var basis := Basis(Vector3.UP, winkel).scaled(Vector3.ONE * (0.85 + float(zufall % 5) * 0.05))
		if not gruppen.has(art):
			gruppen[art] = []
		gruppen[art].append(Transform3D(basis, Vector3(c.x + 0.5, 0.0, c.y + 0.5) + richtung * 0.2))


## Treppe: Loch mit Steinrahmen und leuchtender Innenkante, Stufen mit
## Leuchtkanten, Glühen aus der Tiefe, Lichtsäule mit Staub und eine
## Lichtquelle im Pool — kein dunkler Kasten, man findet sie sofort.
func _treppe_bauen() -> void:
	var t := _map.stairs_cell
	if t.x < 0:
		return
	var mitte := Vector3(t.x + 0.5, 0.0, t.y + 0.5)
	var licht := Stil3D.farbe("treppe_licht")
	var rahmen: Color = (_stil["deckel"] as Color) * 1.3
	var b := Bausatz.new()
	b.teil(Stil3D.box(0.9, 0.62, 0.9), Stil3D.farbe("nacht"), Vector3(0, -0.33, 0), Vector3.ZERO, false)
	for s in 4:
		var y := -0.07 - s * 0.13
		var z := -0.31 + s * 0.2
		b.teil(Stil3D.box(0.8, 0.1, 0.22), Stil3D.farbe("stein_hell") * (1.0 - s * 0.16), Vector3(0, y, z),
			Vector3.ZERO, false)
		b.teil(Stil3D.box(0.8, 0.018, 0.025), licht, Vector3(0, y + 0.05, z + 0.1), Vector3.ZERO, false,
			0.75 - s * 0.12)
	for seite in [[Vector3(0, 0.04, -0.46), Vector3(1.0, 0.1, 0.1)], [Vector3(0, 0.04, 0.46), Vector3(1.0, 0.1, 0.1)],
			[Vector3(-0.46, 0.04, 0), Vector3(0.1, 0.1, 0.82)], [Vector3(0.46, 0.04, 0), Vector3(0.1, 0.1, 0.82)]]:
		var g: Vector3 = seite[1]
		b.teil(Stil3D.box(g.x, g.y, g.z), rahmen, seite[0])
		var innen: Vector3 = seite[0] * 0.9
		b.teil(Stil3D.box(maxf(0.02, g.x * 0.86 if g.x > 0.5 else 0.02), 0.02, maxf(0.02, g.z if g.z > 0.5 else 0.02)),
			licht, Vector3(innen.x, 0.095, innen.z), Vector3.ZERO, false, 0.8)
	for x in [-0.42, 0.42]:
		b.teil(Stil3D.box(0.14, 0.42, 0.14), rahmen * 0.9, Vector3(x, 0.21, -0.42))
		b.teil(Stil3D.kugel(0.07), licht, Vector3(x, 0.5, -0.42), Vector3.ZERO, true, 0.8)
	var treppe := b.knoten("Treppe")
	treppe.position = mitte
	add_child(treppe)
	var tiefe := WeltMaterial.bodenbild("lichtfleck", 0.9, {"farbe": licht, "staerke": 0.55})
	tiefe.position = mitte + Vector3(0, -0.6, 0)
	add_child(tiefe)
	var saeule := WeltMaterial.lichtsaeule(licht, 3.0, 0.4, SAEULE_STAERKE)
	saeule.position += mitte + Vector3(0, -0.25, 0)
	add_child(saeule)
	_lokal.append(saeule)
	var staub := WeltMaterial.funken(licht, 14, Vector3(0.3, 0.1, 0.3), 0.4, 2.4)
	staub.position = mitte + Vector3(0, -0.2, 0)
	add_child(staub)
	_lokal.append(staub)
	_licht_dazu(mitte + Vector3(0, 0.7, 0), licht, 0.9, 3.6, false)


## Boss-Arena im Boss-Raum (Grundriss unverändert): Bodensiegel, Feuerschalen
## in den Ecken und am Eingang, rote Lichtsäule über dem Eingang; der Boss
## selbst bekommt Aura, Säule und ein eigenes Licht (aktualisieren()).
func _boss_raum_bauen() -> void:
	var raum := WeltBau.boss_raum(_map)
	if raum.size.x <= 0:
		return
	var siegel_farbe := Stil3D.farbe("boss_siegel")
	var mitte := Vector3(raum.position.x + raum.size.x * 0.5, 0.0, raum.position.y + raum.size.y * 0.5)
	var siegel := WeltMaterial.bodenbild("siegel", minf(raum.size.x, raum.size.y) - 0.6,
		{"farbe": siegel_farbe, "staerke": 0.7})
	siegel.position += mitte
	add_child(siegel)
	var stein: Color = (_stil["wand"] as Color) * 1.15
	for zelle in WeltBau.boss_schalen(_map, raum):
		var schale := FigurenBau.feuerschale(stein)
		schale.position = Vector3(zelle.x + 0.5, 0.0, zelle.y + 0.5)
		add_child(schale)
		var glut := WeltMaterial.funken(Stil3D.farbe("glut"), 8, Vector3(0.12, 0.05, 0.12), 0.5, 1.4)
		glut.position = schale.position + Vector3(0, 1.0, 0)
		add_child(glut)
		_lokal.append(glut)
		_licht_dazu(schale.position + Vector3(0, 1.2, 0), FACKEL_FARBE, 1.1, 4.2, true)
	var eingang := WeltBau.boss_eingang(_map, raum)
	if eingang.x >= 0:
		# Torsäule mit Bodenschein: aus dem Gang ist sie der erste Wegweiser
		# (die Boss-Säule steht bei Standard-Zoom oft noch außerhalb des Bilds).
		var tor := WeltMaterial.lichtsaeule(siegel_farbe, 2.4, 0.5, SAEULE_STAERKE * 0.85)
		tor.position += Vector3(eingang.x + 0.5, 0.0, eingang.y + 0.5)
		add_child(tor)
		_lokal.append(tor)
		var tor_schein := WeltMaterial.bodenbild("lichtfleck", 2.6, {"farbe": siegel_farbe, "staerke": 1.1, "tempo": 1.7})
		tor_schein.position += Vector3(eingang.x + 0.5, 0.0, eingang.y + 0.5)
		add_child(tor_schein)
		_lokal.append(tor_schein)
	var boss := Vector3(_map.boss_cell.x + 0.5, 0.0, _map.boss_cell.y + 0.5)
	_boss_licht = _licht_dazu(boss + Vector3(0, 1.8, 0), siegel_farbe, 0.75, 4.0, false)


## Boss-Gang: Banner an den sichtbaren Wandseiten, Fackeln in festem Takt.
func _boss_gang_schmuck(c: Vector2i, hoehe: float) -> void:
	var takt := posmod(c.x + c.y, 4)
	for richtung in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		if not _map.is_floor(c + richtung):
			continue
		var sichtbar: bool = richtung.x > 0 or richtung.y > 0  # Seite zeigt zur Kamera
		if takt == 0 and sichtbar:
			var banner := FigurenBau.banner(Stil3D.farbe("banner"))
			add_child(banner)
			var aussen := Vector3(richtung.x, 0, richtung.y)
			banner.position = Vector3(c.x + 0.5, SOCKEL_OBEN + hoehe - 0.06, c.y + 0.5) + aussen * 0.5
			banner.rotation.y = atan2(float(richtung.x), float(richtung.y))
			return
		if takt == 2:
			_fackel_setzen(c, richtung, hoehe)
			return


# --- Laufende Aktualisierung --------------------------------------------------

func aktualisieren(delta: float, szene: Node) -> void:
	_zeit += delta
	_bilder += 1
	if _bilder == 4:
		for probe in _proben:
			probe.queue_free()
		_proben.clear()
	var spieler := _welt(szene.player_pos)
	var gesehen := {}
	var ziele: Array[Vector2] = []

	# Held des Spielers: Blickrichtung aus der eigenen Bewegung, Lauf-Hopser.
	var held_kaempfer: Combatant = szene.held_kaempfer()
	var held_bauen := func() -> Node3D:
		var h: Node3D = FigurenBau.held_aus(held_kaempfer) if held_kaempfer != null else FigurenBau.held()
		_bodenring(h)
		return h
	var held := _figur("spieler", held_bauen, spieler, gesehen)
	var schritt := spieler - _letzte_spielerpos
	if schritt.length() > 0.002:
		held.rotation.y = lerp_angle(held.rotation.y, atan2(schritt.x, schritt.z), minf(1.0, delta * 14.0))
	_hopser = WeltBau.naechster_hopser(_hopser, schritt.length() > 0.002, delta)
	held.set_meta("hopser", absf(sin(_hopser * PI)) * WeltBau.HOPSER_HOEHE)
	_letzte_spielerpos = spieler

	for gegner in szene._enemies:
		var arch: EnemyArchetype = gegner.get("archetype")
		var id := StringName(arch.id) if arch != null else &"?"
		var key := "e%d" % gegner["id"]
		var pos := _welt(gegner["pos"])
		var fig := _figur(key, func() -> Node3D: return FigurenBau.fuer_archetyp(id), pos, gesehen)
		var kurs: Vector2 = gegner.get("kurs", Vector2.ZERO)
		if kurs != Vector2.ZERO:
			fig.rotation.y = lerp_angle(fig.rotation.y, atan2(kurs.x, kurs.y), minf(1.0, delta * 10.0))
		ziele.append(Vector2(pos.x, pos.z))
		if gegner.get("schluessel", false):
			_figur("k%d" % gegner["id"], func() -> Node3D: return FigurenBau.schluessel(),
				pos + Vector3(0, 1.3, 0), gesehen, false)
		var marker_zeit: float = gegner.get("marker_zeit", 0.0)
		if marker_zeit > 0.0:
			var gelb: bool = gegner.get("marker", "") == "!"
			var farbe := Color(1.0, 0.85, 0.3) if gelb else Color(0.75, 0.85, 1.0)
			farbe.a = clampf(marker_zeit / 0.3, 0.0, 1.0)
			_label(key, gegner["marker"], pos + Vector3(0, 1.55, 0), farbe, 96, gesehen)

	for truhe in szene._chests:
		var key := "c%d" % truhe["id"]
		var band: Color = LootGenerator.RARITY_COLORS.get(truhe["rarity"], Stil3D.farbe("eisen"))
		var pos := _welt(truhe["pos"])
		var truhe_fig := _figur(key, func() -> Node3D: return FigurenBau.truhe(band), pos, gesehen)
		_ziel_licht(truhe_fig, band, 1.3)
		ziele.append(Vector2(pos.x, pos.z))

	for ev in szene._events:
		var key := "v%d" % ev["id"]
		var typ: DungeonGenerator.EventType = ev["type"]
		var pos := _welt(ev["pos"])
		var ev_fig := _figur(key, func() -> Node3D: return _event_figur(typ), pos, gesehen)
		_ziel_licht(ev_fig, event_farbe(typ), 1.4)
		ziele.append(Vector2(pos.x, pos.z))

	if not szene._tresor.is_empty():
		var tresor_pos := _welt(szene._tresor["pos"])
		var tresor_fig := _figur("tresor", func() -> Node3D: return FigurenBau.tresor(), tresor_pos, gesehen)
		_ziel_licht(tresor_fig, Stil3D.farbe("gold"), 1.6)
		ziele.append(Vector2(tresor_pos.x, tresor_pos.z))

	_boss_lebt = szene._boss_alive
	if szene._boss_alive:
		var zelle: Vector2i = szene.map.boss_cell
		var pos := Vector3(zelle.x + 0.5, 0.0, zelle.y + 0.5)
		var boss_id: StringName = szene._boss_archetyp_id()
		# Größe im Mesh (Bausatz-/Teil-Maßstab 1.5) statt Node-Skalierung: die
		# Kontur bleibt so dick wie bei allen anderen Figuren.
		var boss_bauen := func() -> Node3D:
			return FigurenBau.fuer_archetyp(boss_id, {"boss": true, "massstab": BOSS_MASSSTAB})
		var boss := _figur("boss", boss_bauen, pos, gesehen)
		boss.rotation.y = atan2(spieler.x - pos.x, spieler.z - pos.z)
		if not boss.has_meta("saeule"):
			_boss_saeule(boss)
		ziele.append(Vector2(pos.x, pos.z))

	if _map.stairs_cell.x >= 0:
		ziele.append(Vector2(_map.stairs_cell.x + 0.5, _map.stairs_cell.y + 0.5))

	# Co-op-Mitspieler auf derselben Ebene (geglättete Anzeigeposition).
	for wer in Net.remote_players:
		var info: Dictionary = Net.remote_players[wer]
		if int(info["floor"]) != szene.floor_index:
			continue
		var key := "m:" + String(wer)
		var pos := _welt(szene._remote_display.get(wer, info["pos"]))
		var ruestung := FigurenBau.held_farbe_aus(int(info.get("tile", -1)), String(wer))
		_figur(key, func() -> Node3D: return FigurenBau.held(ruestung), pos, gesehen)
		_label(key, String(wer), pos + Vector3(0, 1.45, 0), Color(0.75, 0.9, 1.0), 48, gesehen)
		ziele.append(Vector2(pos.x, pos.z))

	# Verschwundenes (besiegt, geöffnet, benutzt, Mitspieler weg) aufräumen.
	for key in _figuren.keys():
		if not gesehen.has(key):
			_figuren[key].queue_free()
			_figuren.erase(key)
	for key in _labels.keys():
		if not gesehen.has("L" + key):
			_labels[key].queue_free()
			_labels.erase(key)

	_lebendigkeit()
	_kamera_folgen(delta, spieler)
	_licht_aktualisieren(spieler)
	_glas_aktualisieren(delta, Vector2(spieler.x, spieler.z), ziele)


func _welt(px: Vector2) -> Vector3:
	return Vector3(px.x / PX, 0.0, px.y / PX)


## Figur zum Schlüssel holen bzw. bauen; am_boden = mit Blob-Schatten.
func _figur(key: String, bauen: Callable, pos: Vector3, gesehen: Dictionary, am_boden := true) -> Node3D:
	gesehen[key] = true
	var fig: Node3D = _figuren.get(key)
	if fig == null:
		fig = bauen.call()
		if am_boden:
			# Größe steckt im Mesh (Wurzel-Skala 1) — der Schatten wächst mit.
			var blob := WeltMaterial.blob(0.95 * maxf(0.6, float(fig.get_meta("groesse", 1.0))), _blob_mat)
			fig.add_child(blob)
			fig.set_meta("blob", blob)
		add_child(fig)
		_figuren[key] = fig
		fig.set_meta("phase", float(absi(hash(key)) % 628) / 100.0)
	fig.set_meta("boden", pos)
	return fig


## Bodenring unter dem eigenen Helden: wo bin ich — auch im Gewimmel.
func _bodenring(held: Node3D) -> void:
	var ring := WeltMaterial.blob(1.0, _ring_mat)
	held.add_child(ring)
	held.set_meta("ring", ring)


func _label(key: String, text: String, pos: Vector3, farbe: Color, groesse: int, gesehen: Dictionary) -> void:
	gesehen["L" + key] = true
	var l: Label3D = _labels.get(key)
	if l == null:
		l = Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.pixel_size = 0.005
		l.outline_size = 14
		l.outline_modulate = Stil3D.farbe("nacht")
		add_child(l)
		_labels[key] = l
	l.text = text
	l.font_size = groesse
	l.modulate = farbe
	l.outline_modulate.a = farbe.a
	l.position = pos


func _event_figur(typ: DungeonGenerator.EventType) -> Node3D:
	match typ:
		DungeonGenerator.EventType.SACRIFICE:
			return FigurenBau.altar()
		DungeonGenerator.EventType.RISK_CHEST:
			return FigurenBau.risikotruhe()
		DungeonGenerator.EventType.HAENDLER:
			return _haendler_figur()
		DungeonGenerator.EventType.GEFANGENER:
			return _gefangener_figur()
	return FigurenBau.schrein(SCHREIN_FARBEN.get(typ, Color.WHITE))


## Fahrender Händler: Held in Händlerfarbe mit Warenkiste und Bündel.
static func _haendler_figur() -> Node3D:
	var n := Node3D.new()
	n.name = "Haendler"
	var held := FigurenBau.held_mit(Stil3D.farbe("bernstein"))
	held.position = Vector3(-0.2, 0, 0)
	n.add_child(held)
	var kiste := FigurenBau.truhe(Stil3D.farbe("gold"))
	kiste.scale = Vector3.ONE * 0.6
	kiste.position = Vector3(0.38, 0, 0.12)
	n.add_child(kiste)
	var b := Bausatz.new()
	b.teil(Stil3D.kugel(0.13), Stil3D.farbe("leder"), Vector3(0.38, 0.42, 0.12))
	b.teil(Stil3D.box(0.05, 0.08, 0.05), Stil3D.farbe("braun"), Vector3(0.38, 0.55, 0.12))
	n.add_child(b.knoten("Buendel"))
	return n


## Gefangener Held: Held in Grau hinter Gitterstäben (Käfig aus Eisen).
static func _gefangener_figur() -> Node3D:
	var n := Node3D.new()
	n.name = "Gefangener"
	var held := FigurenBau.held_mit(Stil3D.farbe("fahl"))
	n.add_child(held)
	var b := Bausatz.new()
	var eisen := Stil3D.farbe("eisen")
	var boden := Stil3D.zylinder(0.46, 0.48, 0.06)
	boden.radial_segments = 12
	b.teil(boden, Stil3D.farbe("stein_dunkel"), Vector3(0, 0.03, 0))
	var deckel := Stil3D.zylinder(0.46, 0.46, 0.05)
	deckel.radial_segments = 12
	b.teil(deckel, eisen, Vector3(0, 1.32, 0))
	for i in 10:
		var w := TAU * i / 10.0
		b.teil(Stil3D.zylinder(0.022, 0.022, 1.3), eisen, Vector3(sin(w) * 0.44, 0.67, cos(w) * 0.44))
	b.teil(Stil3D.kugel(0.06), eisen, Vector3(0, 1.38, 0))
	n.add_child(b.knoten("Kaefig"))
	return n


## Leuchtfarbe eines Ereignisses (Schrein-Typ, Opferstein, Risiko-Truhe).
static func event_farbe(typ: DungeonGenerator.EventType) -> Color:
	match typ:
		DungeonGenerator.EventType.SACRIFICE:
			return Stil3D.farbe("daemon")
		DungeonGenerator.EventType.RISK_CHEST:
			return Stil3D.farbe("gold")
		DungeonGenerator.EventType.HAENDLER:
			return Stil3D.farbe("bernstein")
		DungeonGenerator.EventType.GEFANGENER:
			return Stil3D.farbe("silber")
	return SCHREIN_FARBEN.get(typ, Color.WHITE)


## Lichtsäule + Bodenglühen an einem Ziel (einmal je Figur). Die Figur-
## Skalierung (Boss ×1.5) wird ausgeglichen; sichtbar nur nahe (Lebendigkeit).
func _ziel_licht(fig: Node3D, farbe: Color, fleck: float, hoehe := 2.4, staerke := SAEULE_STAERKE) -> void:
	if fig.has_meta("saeule"):
		return
	var ausgleich := Vector3.ONE / fig.scale
	var saeule := WeltMaterial.lichtsaeule(farbe, hoehe, 0.34 * fleck / 1.3, staerke)
	saeule.scale = ausgleich
	saeule.position *= ausgleich
	fig.add_child(saeule)
	var glanz := WeltMaterial.bodenbild("lichtfleck", fleck, {"farbe": farbe, "staerke": 0.55})
	glanz.scale = ausgleich
	glanz.position *= ausgleich
	fig.add_child(glanz)
	fig.set_meta("saeule", [saeule, glanz])


## Boss-Lichtsäule: das stärkste Licht der Ebene — ein schmaler, heller Kern,
## der erst über dem Boss-Kopf voll einsetzt (die Figur bleibt lesbar), ein
## breiter, langsam atmender roter Mantel, kräftiges Bodenglühen in zwei
## Lagen und Funken, die an der Säule hochsteigen. Anders als die übrigen
## Lichtsäulen ist sie auf der ganzen Boss-Ebene sichtbar (Meta
## "saeule_weit"), also schon aus dem Gang als Wegweiser.
func _boss_saeule(boss: Node3D) -> void:
	var rot := Stil3D.farbe("boss_siegel")
	var ausgleich := Vector3.ONE / boss.scale
	var teile: Array[Node3D] = []
	# Unterhalb von Scheitel (+ Krone) bleiben Kern und Mantel ganz aus: der
	# Mantel (r 1.15) steht in der Schrägsicht VOR der Figur und legte sonst
	# einen roten Schleier über den Boss, der Kern einen weißen Streifen über
	# den Rücken. Der Mantel beginnt um seinen Radius höher (Schrägsicht 45°).
	var scheitel := FigurenBau.umriss_lokal(boss).end.y
	var kern := WeltMaterial.lichtsaeule(rot.lightened(0.28), BOSS_SAEULE_HOEHE, 0.22, 1.15)
	var kern_mat := kern.material_override as ShaderMaterial
	kern_mat.set_shader_parameter("beginn", (scheitel + 0.1) / BOSS_SAEULE_HOEHE)
	kern_mat.set_shader_parameter("ansatz", 0.12)
	kern_mat.set_shader_parameter("schaerfe", 2.0)
	kern_mat.set_shader_parameter("puls", 0.12)
	teile.append(kern)
	var mantel_hoehe := BOSS_SAEULE_HOEHE * 0.8
	var mantel := WeltMaterial.lichtsaeule(rot, mantel_hoehe, 1.15, 1.25)
	var mantel_mat := mantel.material_override as ShaderMaterial
	mantel_mat.set_shader_parameter("beginn", minf(0.5, (scheitel + 1.0) / mantel_hoehe))
	mantel_mat.set_shader_parameter("ansatz", 0.14)
	mantel_mat.set_shader_parameter("puls", 0.25)
	teile.append(mantel)
	# Bodenschein kräftiger und weiter (Wegweiser aus dem Gang, Rest Paket 4):
	# liegt flach am Boden, färbt die Figur also nicht.
	teile.append(WeltMaterial.bodenbild("lichtfleck", 7.2, {"farbe": rot, "staerke": 1.75, "tempo": 1.7}))
	teile.append(WeltMaterial.bodenbild("lichtfleck", 3.0,
		{"farbe": rot.lightened(0.3), "staerke": 1.2, "tempo": 1.7}))
	var glut := WeltMaterial.funken(rot, 22, Vector3(0.7, 0.1, 0.7), 0.45, 2.0, 1.3)
	glut.position = Vector3(0, 0.1, 0)
	teile.append(glut)
	var aufstieg := WeltMaterial.funken(rot.lightened(0.3), 34, Vector3(0.4, 0.1, 0.4), 1.0, 4.0, 1.9)
	aufstieg.position = Vector3(0, 1.2, 0)
	teile.append(aufstieg)
	for teil in teile:
		teil.scale = ausgleich
		teil.position *= ausgleich
		boss.add_child(teil)
	boss.set_meta("saeule", teile)
	boss.set_meta("saeule_weit", true)
	# Säulenfuß: ein zweiter Kern vom Boden aufwärts, HINTER dem Boss (von der
	# Kamera weg um seinen Rumpf-Radius versetzt) — die Figur verdeckt ihn,
	# er liegt nie davor. So reicht die Säule sichtbar bis zum Bodenschein,
	# ohne den Boss einzufärben (Review Paket 4: Mantel-Schleier). Lage
	# hält _lebendigkeit jedes Bild (der Boss dreht sich zum Helden).
	# Rumpf-Radius statt ganzem Umriss: Flügel, Waffen und Schwänze ragen weit
	# hinaus, der Fuß stünde sonst Felder hinter dem Boss.
	var box := FigurenBau.umriss_lokal(boss)
	var halb := maxf(maxf(absf(box.position.x), box.end.x), maxf(absf(box.position.z), box.end.z))
	var radius := minf(halb, 0.42 * float(boss.get_meta("groesse", 1.0)))
	var fuss := WeltMaterial.lichtsaeule(rot.lightened(0.28), BOSS_SAEULE_HOEHE * 0.6, 0.2, 0.95)
	var fuss_mat := fuss.material_override as ShaderMaterial
	fuss_mat.set_shader_parameter("ansatz", 0.03)
	fuss_mat.set_shader_parameter("schaerfe", 2.0)
	fuss_mat.set_shader_parameter("puls", 0.12)
	fuss.set_meta("hinten", saeulen_fuss_versatz(radius))
	fuss.set_meta("mitte_y", fuss.position.y)
	boss.add_child(fuss)
	boss.set_meta("saeule_fuss", fuss)
	_saeulen_fuss_halten(boss)


## Versatz des Säulenfußes vom Boss weg (Welt, xz): entlang der Blickrichtung
## der Kamera nach hinten, knapp hinter den Rumpf (radius = Rumpf-Radius).
static func saeulen_fuss_versatz(radius: float) -> Vector3:
	var hinten := -Vector3(KAMERA_RICHTUNG.x, 0.0, KAMERA_RICHTUNG.z).normalized()
	return hinten * (radius + 0.25)


## Säulenfuß hinter dem Boss halten: Weltlage unabhängig von Drehung und
## Wippen der Figur (die Säule steht, der Boss dreht sich davor).
func _saeulen_fuss_halten(boss: Node3D) -> void:
	var fuss: Node3D = boss.get_meta("saeule_fuss")
	var boden: Vector3 = boss.get_meta("boden", boss.position)
	var ziel := boden + (fuss.get_meta("hinten") as Vector3) + Vector3(0, float(fuss.get_meta("mitte_y")), 0)
	if boss.is_inside_tree():
		fuss.global_transform = Transform3D(Basis(), ziel)
	else:
		fuss.transform = boss.transform.affine_inverse() * Transform3D(Basis(), ziel)


## Idle-Wippen, Lauf-Hopser, Schleim-Quetschen, Schweben; der Blob-Schatten
## bleibt am Boden und wird kleiner, je höher die Figur schwebt.
func _lebendigkeit() -> void:
	# Weiter herausgezoomt sieht man mehr Boden: der Umkreis wächst mit,
	# sonst gingen Lichtsäulen am Bildrand aus (Zoom 16 ≈ 19 Felder zur Ecke).
	var reichweite := LOKAL_REICHWEITE * maxf(1.0, _zoom / ZOOM_START)
	for fig in _figuren.values():
		var boden: Vector3 = fig.get_meta("boden", fig.position)
		var phase: float = fig.get_meta("phase", 0.0)
		var hoehe := float(fig.get_meta("schwebt", 0.0)) \
			+ sin(_zeit * 2.2 + phase) * float(fig.get_meta("wippen", 0.0)) \
			+ float(fig.get_meta("hopser", 0.0))
		fig.position = boden + Vector3(0, hoehe, 0)
		var quetsch := float(fig.get_meta("quetschen", 0.0))
		if quetsch > 0.0:
			var basis_skala: float = fig.get_meta("basis_skala", fig.scale.x)
			fig.set_meta("basis_skala", basis_skala)
			var s := sin(_zeit * 3.0 + phase) * quetsch
			fig.scale = Vector3(1.0 - s * 0.5, 1.0 + s, 1.0 - s * 0.5) * basis_skala
		if fig.has_meta("blob"):
			var blob: Node3D = fig.get_meta("blob")
			blob.position.y = (0.03 - hoehe) / maxf(0.01, fig.scale.y)
			blob.scale = Vector3.ONE * clampf(1.0 - hoehe * 0.35, 0.5, 1.0)
		if fig.has_meta("ring"):
			var ring: Node3D = fig.get_meta("ring")
			ring.position.y = (0.036 - hoehe) / maxf(0.01, fig.scale.y)
		if fig.has_meta("boden_teile"):
			FigurenBau.boden_halten(fig, hoehe, fig.scale.y)
		if fig.has_meta("glieder"):
			_glieder_beleben(fig, boden, phase, reichweite)
		if fig.has_meta("kristall"):
			var k: Node3D = fig.get_meta("kristall")
			k.rotation.y = _zeit * 1.2 + phase
			k.position.y = 0.92 + sin(_zeit * 2.0 + phase) * 0.05
		if fig.has_meta("saeule"):
			var nah: bool = fig.get_meta("saeule_weit", false) or boden.distance_to(_blickpunkt) < reichweite
			for teil in fig.get_meta("saeule"):
				teil.visible = nah
			if fig.has_meta("saeule_fuss"):
				(fig.get_meta("saeule_fuss") as Node3D).visible = nah
				_saeulen_fuss_halten(fig)
	for teil in _lokal:
		var ort := Vector3(teil.global_position.x, 0.0, teil.global_position.z)
		var nah := ort.distance_to(_blickpunkt) < reichweite
		if teil.visible == nah:
			continue
		teil.visible = nah
		if teil is CPUParticles3D:
			(teil as CPUParticles3D).emitting = nah


## Gliederpuppen (STIL-3D.md 7g) nur im Umkreis beleben (Idle bzw. Gehen,
## wenn sich der Bodenpunkt bewegt); ferne Figuren fallen einmal in die
## Ruhepose zurück und kosten danach nichts.
func _glieder_beleben(fig: Node3D, boden: Vector3, phase: float, reichweite: float) -> void:
	if boden.distance_to(_blickpunkt) < reichweite:
		var alt: Vector3 = fig.get_meta("boden_alt", boden)
		var geht := alt.distance_squared_to(boden) > 0.000001 or float(fig.get_meta("hopser", 0.0)) > 0.001
		fig.set_meta("boden_alt", boden)
		var wurzel := Gliederpuppe.beleben(fig, _zeit + phase, -1.0, -1.0, geht)
		fig.rotation.x = wurzel.x
		fig.rotation.z = wurzel.z
		fig.set_meta("belebt", true)
	elif fig.get_meta("belebt", false):
		Gliederpuppe.ruhe(fig)
		fig.rotation.x = 0.0
		fig.rotation.z = 0.0
		fig.set_meta("belebt", false)


func _kamera_folgen(delta: float, spieler: Vector3) -> void:
	_blickpunkt = _blickpunkt.lerp(spieler, minf(1.0, delta * 8.0))
	_kamera.position = _blickpunkt + KAMERA_RICHTUNG * KAMERA_ABSTAND
	_kamera.size = lerpf(_kamera.size, _zoom, minf(1.0, delta * 10.0))


## Laterne folgt dem Helden, der Pool wandert an die nächsten Fackeln (weich
## ausgeblendet zum Rand, damit ein Wechsel nicht springt), Leuchtfugen und
## Untergrund bekommen Held bzw. Kamera-Ziel.
func _licht_aktualisieren(spieler: Vector3) -> void:
	_laterne.position = spieler + Vector3(0, 1.5, 0)
	# Karten-Variante „der Angst“: unruhige Laterne mit kurzen Einbrüchen.
	var unruhe := float(_stil.get("laterne_flackern", 0.0))
	var einbruch := smoothstep(0.82, 0.98, sin(_zeit * 1.9) * sin(_zeit * 3.7 + 1.3))
	_laterne.light_energy = LATERNE_ENERGIE * float(_stil.get("laterne_energie", 1.0)) * (1.0
		+ sin(_zeit * 9.0) * (0.025 + 0.09 * unruhe) + sin(_zeit * 23.0) * (0.015 + 0.06 * unruhe)
		- einbruch * 0.45 * unruhe)
	var auswahl := WeltBau.pool_auswahl(_licht_orte, _blickpunkt, WeltBau.POOL_GROESSE,
		WeltBau.POOL_REICHWEITE)
	if _boss_licht >= 0 and not _boss_lebt:
		auswahl.erase(_boss_licht)
	for j in _pool.size():
		var l := _pool[j]
		if j >= auswahl.size():
			l.visible = false
			continue
		var k := auswahl[j]
		var ort := _licht_orte[k]
		var daten: Dictionary = _licht_daten[k]
		var rand := 1.0 - smoothstep(WeltBau.POOL_REICHWEITE - 3.0, WeltBau.POOL_REICHWEITE,
			ort.distance_to(_blickpunkt))
		var flackern := 1.0
		if daten["flackert"]:
			flackern = 0.88 + 0.12 * sin(_zeit * 13.0 + k) * sin(_zeit * 7.3 + k * 2.0)
		else:
			flackern = 0.94 + 0.06 * sin(_zeit * 1.7 + k)
		l.visible = true
		l.position = ort
		l.light_color = daten["farbe"]
		l.omni_range = daten["reichweite"]
		l.light_energy = float(daten["energie"]) * flackern * rand
	for mat in _held_mats:
		mat.set_shader_parameter("held_pos", spieler)
	_untergrund_mat.set_shader_parameter("kamera", Vector2(_blickpunkt.x, _blickpunkt.z))
	_partikel.position = _blickpunkt + Vector3(0, 0.9, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(ZOOM_MIN, _zoom - 0.8)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(ZOOM_MAX, _zoom + 0.8)


# --- Glas-Regel ----------------------------------------------------------------

func _glas_aktualisieren(delta: float, held: Vector2, ziele: Array[Vector2]) -> void:
	var bereich := sichtbarer_bereich(2)
	for y in range(bereich[1], bereich[3]):
		for x in range(bereich[0], bereich[2]):
			var c := Vector2i(x, y)
			var w: Dictionary = _waende.get(c, {})
			if w.is_empty():
				continue
			var p := Vector2(x + 0.5, y + 0.5)
			var ziel_alpha := DECKKRAFT_GLAS if _verdeckt(p, held, ziele, w["vor"]) else 1.0
			var alt: float = w["alpha"]
			if is_equal_approx(alt, ziel_alpha):
				continue
			var neu := move_toward(alt, ziel_alpha, delta * GLAS_TEMPO)
			w["alpha"] = neu
			_glas_setzen(w, neu)


## vor_max = wie weit die Wand (samt Krone) nach hinten verdeckt.
func _verdeckt(p: Vector2, held: Vector2, ziele: Array[Vector2], vor_max := ZIEL_VOR_MAX) -> bool:
	if _liegt_vor(p, held, maxf(HELD_VOR_MAX, vor_max), HELD_QUER_MAX):
		return true
	for z in ziele:
		if _liegt_vor(p, z, vor_max, ZIEL_QUER_MAX):
			return true
	return false


func _liegt_vor(p: Vector2, ziel: Vector2, vor_max: float, quer_max: float) -> bool:
	var d := p - ziel
	var vor := -d.dot(_vor)  # > 0: Wand steht zwischen Kamera und Ziel
	return vor > 0.3 and vor < vor_max and absf(d.dot(_rechts)) < quer_max


## Deckkraft in die Instanzdaten: der opake Wand-Shader (und seine Kontur)
## lässt danach Bildpunkte aus — kein Milchglas, der Held bleibt farbecht.
func _glas_setzen(w: Dictionary, alpha: float) -> void:
	var i: int = w["i"]
	var deck := Color(0, 0, 0, 1.0 if alpha >= 0.999 else alpha)
	_koerper_mm.set_instance_custom_data(i, deck)
	_deckel_mm.set_instance_custom_data(i, deck)
	if w.has("krone"):
		var krone: Array = w["krone"]
		for mm in [krone[0], krone[1]]:
			if mm != null:
				(mm as MultiMesh).set_instance_custom_data(krone[2], deck)
	for f in w.get("fackeln", []):
		(f as Node3D).visible = alpha > 0.6


# --- Abfragen für die Spiellogik ------------------------------------------------

## Zellbereich im Bild (+Rand) als [x0, y0, x1, y1) — aus den vier
## Bildecken auf die Bodenebene projiziert.
func sichtbarer_bereich(rand: int) -> Array[int]:
	# Ohne Baum kein Viewport (Szenenwechsel) — in der Release-EXE wäre der
	# Aufruf auf null ein harter Absturz statt einer Fehlermeldung.
	if _kamera == null or not is_inside_tree():
		return [0, 0, 0, 0]
	var groesse := get_viewport().get_visible_rect().size
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for ecke in [Vector2.ZERO, Vector2(groesse.x, 0), Vector2(0, groesse.y), groesse]:
		var o := _kamera.project_ray_origin(ecke)
		var n := _kamera.project_ray_normal(ecke)
		if absf(n.y) < 0.0001:
			continue
		var t := -o.y / n.y
		var p := o + n * t
		min_p = min_p.min(Vector2(p.x, p.z))
		max_p = max_p.max(Vector2(p.x, p.z))
	return [maxi(0, floori(min_p.x) - rand), maxi(0, floori(min_p.y) - rand),
		mini(_map.width, ceili(max_p.x) + rand), mini(_map.height, ceili(max_p.y) + rand)]


## Bildschirmpunkt eines Weltorts (Minimap blendet sich über Zielen aus).
func bildschirm_punkt(ort: Vector3) -> Vector2:
	if _kamera == null or not is_inside_tree():
		return Vector2(-1000, -1000)
	return _kamera.unproject_position(ort)


## WASD/Pfeile sind Bildschirm-Richtungen ("W" = nach oben im Bild) —
## umgerechnet auf Karten-Achsen (x = Welt-x, y = Welt-z).
func bildschirm_zu_karte(eingabe: Vector2) -> Vector2:
	return _rechts * eingabe.x + _vor * (-eingabe.y)
