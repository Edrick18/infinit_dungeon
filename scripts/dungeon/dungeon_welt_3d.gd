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
## OmniLights, der jedes Bild an die nächsten Fackeln wandert.

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
const VERSTECKT := Vector3(0, -100, 0)
## Glas-Regel: Wand liegt "vor" einem Ziel (Richtung Kamera) und seitlich nah.
const HELD_VOR_MAX := 5.0
const HELD_QUER_MAX := 3.0
const ZIEL_VOR_MAX := 2.6
const ZIEL_QUER_MAX := 1.1
const FACKEL_ENERGIE := 1.25
const LATERNE_ENERGIE := 0.85
const SCHREIN_FARBEN := {
	DungeonGenerator.EventType.SHRINE_HEAL: Color("6fe08a"),
	DungeonGenerator.EventType.SHRINE_MANA: Color("6fb0f0"),
	DungeonGenerator.EventType.SHRINE_POWER: Color("ff9a3a"),
	DungeonGenerator.EventType.SHRINE_WARD: Color("ffe07a"),
}


## Biom-Stil (Tönung, Deko, Material, Licht, Untergrund) — Datensatz in BiomStil.
static func biom_stil(biome: Enums.Biome) -> Dictionary:
	return BiomStil.fuer(biome)


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
var _fackel_lichtorte: Array[Vector3] = []  ## Lichtpunkt je Fackel (vor der Flamme)
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
	for eintrag in deko:
		var cell: Vector2i = eintrag["cell"]
		var d := FigurenBau.deko(eintrag["art"])
		add_child(d)
		d.position = Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)
		d.rotation.y = float(absi(hash(cell)) % 360)
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


func _umgebung() -> void:
	var welt := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = (_stil["tief"] as Color).srgb_to_linear()  # BG-Farbe erwartet linear
	Stil3D.umgebung(env, _stil["ambient"], _stil["ambient_energie"])
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
	WeltMaterial.vignette(self)


## Laterne des Helden (warm, weich auslaufend) + Licht-Pool für Fackeln.
func _licht_bauen() -> void:
	_laterne = OmniLight3D.new()
	_laterne.light_color = _stil["laterne"]
	_laterne.light_energy = LATERNE_ENERGIE
	_laterne.omni_range = 6.0
	_laterne.omni_attenuation = 1.3
	add_child(_laterne)
	for i in WeltBau.POOL_GROESSE:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.3)
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
	_partikel = WeltMaterial.partikel(_stil["partikel"], _stil["funke"])
	_partikel.position = _blickpunkt + Vector3(0, 0.9, 0)
	add_child(_partikel)


func _multimesh(mesh: Mesh, anzahl: int, mat: Material, custom := false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = anzahl
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
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
			"biom": int(_stil.get("biom", 0))}), true)
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
	for i in zellen.size():
		var c := zellen[i]
		var mitte := Vector3(c.x + 0.5, 0.0, c.y + 0.5)
		var h := WeltBau.wand_hoehe(c)
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
		_waende[c] = {"i": i, "alpha": 1.0}
		_fackel_pruefen(c, h)


func _grenzt_an_boden(c: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if (dx != 0 or dy != 0) and _map.is_floor(c + Vector2i(dx, dy)):
				return true
	return false


## Vereinzelte Fackeln an Wänden, die direkt an Boden grenzen (deterministisch).
## Sie tragen kein eigenes Licht — der Licht-Pool leuchtet die nächsten an.
func _fackel_pruefen(c: Vector2i, hoehe: float) -> void:
	if float(absi(hash(c * 7 + Vector2i(13, 29))) % 1000) / 1000.0 > FACKEL_CHANCE:
		return
	for richtung in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
		if _map.is_floor(c + richtung):
			var f := FigurenBau.fackel(false, true)
			add_child(f)
			var aussen := Vector3(richtung.x, 0, richtung.y)
			f.position = Vector3(c.x + 0.5, SOCKEL_OBEN + hoehe - 0.3, c.y + 0.5) + aussen * 0.58
			f.rotation.y = atan2(float(richtung.x), float(richtung.y))
			_fackeln.append(f)
			_fackel_lichtorte.append(f.position + aussen * 0.32 + Vector3(0, 0.22, 0))
			return


func _treppe_bauen() -> void:
	var t := _map.stairs_cell
	if t.x < 0:
		return
	var mitte := Vector3(t.x + 0.5, 0.0, t.y + 0.5)
	Stil3D.teil(self, Stil3D.box(0.94, 0.6, 0.94), Stil3D.farbe("nacht"), mitte + Vector3(0, -0.3, 0),
		Vector3.ZERO, false)
	for s in 3:
		Stil3D.teil(self, Stil3D.box(0.94, 0.12, 0.3), Stil3D.farbe("stein_hell") * (1.0 - s * 0.22),
			mitte + Vector3(0, -0.1 - s * 0.16, -0.32 + s * 0.31), Vector3.ZERO, false)


# --- Laufende Aktualisierung --------------------------------------------------

func aktualisieren(delta: float, szene: Node) -> void:
	_zeit += delta
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
		_figur(key, func() -> Node3D: return FigurenBau.truhe(band), pos, gesehen)
		ziele.append(Vector2(pos.x, pos.z))

	for ev in szene._events:
		var key := "v%d" % ev["id"]
		var typ: DungeonGenerator.EventType = ev["type"]
		var pos := _welt(ev["pos"])
		_figur(key, func() -> Node3D: return _event_figur(typ), pos, gesehen)
		ziele.append(Vector2(pos.x, pos.z))

	if not szene._tresor.is_empty():
		var tresor_pos := _welt(szene._tresor["pos"])
		_figur("tresor", func() -> Node3D: return FigurenBau.tresor(), tresor_pos, gesehen)
		ziele.append(Vector2(tresor_pos.x, tresor_pos.z))

	if szene._boss_alive:
		var zelle: Vector2i = szene.map.boss_cell
		var pos := Vector3(zelle.x + 0.5, 0.0, zelle.y + 0.5)
		var boss_id: StringName = szene._boss_archetyp_id()
		var boss_bauen := func() -> Node3D:
			var b := FigurenBau.fuer_archetyp(boss_id)
			b.scale *= 1.5
			return b
		var boss := _figur("boss", boss_bauen, pos, gesehen)
		boss.rotation.y = atan2(spieler.x - pos.x, spieler.z - pos.z)
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
			var blob := WeltMaterial.blob(0.95, _blob_mat)
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
	return FigurenBau.schrein(SCHREIN_FARBEN.get(typ, Color.WHITE))


## Idle-Wippen, Lauf-Hopser, Schleim-Quetschen, Schweben; der Blob-Schatten
## bleibt am Boden und wird kleiner, je höher die Figur schwebt.
func _lebendigkeit() -> void:
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


func _kamera_folgen(delta: float, spieler: Vector3) -> void:
	_blickpunkt = _blickpunkt.lerp(spieler, minf(1.0, delta * 8.0))
	_kamera.position = _blickpunkt + KAMERA_RICHTUNG * KAMERA_ABSTAND
	_kamera.size = lerpf(_kamera.size, _zoom, minf(1.0, delta * 10.0))


## Laterne folgt dem Helden, der Pool wandert an die nächsten Fackeln (weich
## ausgeblendet zum Rand, damit ein Wechsel nicht springt), Leuchtfugen und
## Untergrund bekommen Held bzw. Kamera-Ziel.
func _licht_aktualisieren(spieler: Vector3) -> void:
	_laterne.position = spieler + Vector3(0, 1.5, 0)
	_laterne.light_energy = LATERNE_ENERGIE * (1.0 + sin(_zeit * 9.0) * 0.025 + sin(_zeit * 23.0) * 0.015)
	var auswahl := WeltBau.pool_auswahl(_fackel_lichtorte, _blickpunkt, WeltBau.POOL_GROESSE,
		WeltBau.POOL_REICHWEITE)
	for j in _pool.size():
		var l := _pool[j]
		if j >= auswahl.size():
			l.visible = false
			continue
		var ort := _fackel_lichtorte[auswahl[j]]
		var rand := 1.0 - smoothstep(WeltBau.POOL_REICHWEITE - 3.0, WeltBau.POOL_REICHWEITE,
			ort.distance_to(_blickpunkt))
		var flackern := 0.88 + 0.12 * sin(_zeit * 13.0 + auswahl[j]) * sin(_zeit * 7.3 + auswahl[j] * 2.0)
		l.visible = true
		l.position = ort
		l.light_energy = FACKEL_ENERGIE * flackern * rand
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
			var ziel_alpha := DECKKRAFT_GLAS if _verdeckt(p, held, ziele) else 1.0
			var alt: float = w["alpha"]
			if is_equal_approx(alt, ziel_alpha):
				continue
			var neu := move_toward(alt, ziel_alpha, delta * GLAS_TEMPO)
			w["alpha"] = neu
			_glas_setzen(w, neu)


func _verdeckt(p: Vector2, held: Vector2, ziele: Array[Vector2]) -> bool:
	if _liegt_vor(p, held, HELD_VOR_MAX, HELD_QUER_MAX):
		return true
	for z in ziele:
		if _liegt_vor(p, z, ZIEL_VOR_MAX, ZIEL_QUER_MAX):
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


## WASD/Pfeile sind Bildschirm-Richtungen ("W" = nach oben im Bild) —
## umgerechnet auf Karten-Achsen (x = Welt-x, y = Welt-z).
func bildschirm_zu_karte(eingabe: Vector2) -> Vector2:
	return _rechts * eingabe.x + _vor * (-eingabe.y)
