class_name FigurenBau
extends RefCounted
## Baut Monster, Helden und Objekte aus Stil3D-Grundkörpern (STIL-3D.md).
## Konventionen: Boden bei y = 0, Blick nach +Z, 1 Einheit = 1 Dungeon-Feld,
## normale Gegner 0.6–1.0 hoch, große 1.2–1.5. Jede Figur ist ein Node3D
## mit Meta "wippen" (Idle-Amplitude), optional "quetschen" (Schleime) und
## "schwebt" (Höhe über dem Boden).
##
## Wenige Baukästen (ZweibeinerBau, VierbeinerBau, KreaturenBau, Troll) mit
## Parametern statt 33 Einzelmodellen — alle Gegner sind Gliederpuppen
## (STIL-3D.md 7g–7j); neue Gegner sind ein Eintrag im passenden Baukasten.


static func _p(name: String) -> Color:
	return Stil3D.farbe(name)


static func _wurzel(name: String, wippen := 0.03) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.set_meta("wippen", wippen)
	return n


## Größe ins Mesh backen statt Node-Skalierung (STIL-3D.md 6/7g): alle
## Grundkörper-Maße und Positionen × f, die Wurzel bleibt bei Skala 1 — die
## Kontur (next_pass, Dicke 0.022) ist so bei jeder Größe gleich dick, auch
## beim Boss ×1.5. Anker-Metas wandern mit, "groesse" merkt den Faktor
## (Rang-Ringe, Kronen). Gliederpuppen backen ihren Maßstab selbst.
static func massstab_einbacken(n: Node3D, f: float) -> Node3D:
	f *= n.scale.x
	n.scale = Vector3.ONE
	n.set_meta("groesse", float(n.get_meta("groesse", 1.0)) * f)
	if is_equal_approx(f, 1.0):
		return n
	if n.has_meta("glieder"):
		push_warning("massstab_einbacken: Gliederpuppe %s bäckt ihren Maßstab selbst" % n.name)
		n.scale = Vector3.ONE * f
		return n
	for kind in n.find_children("*", "Node3D", true, false):
		var k := kind as Node3D
		k.position *= f
		if k is MeshInstance3D:
			var mi := k as MeshInstance3D
			if mi.mesh is PrimitiveMesh:
				mi.mesh = Bausatz.skaliert(mi.mesh as PrimitiveMesh, f)
			else:
				mi.scale *= f
	for anker in ["anker_kopf", "anker_ruecken"]:
		if n.has_meta(anker):
			n.set_meta(anker, (n.get_meta(anker) as Vector3) * f)
	return n


## Die 3D-Figur zu einem Gegner-Archetyp. Optionen: boss (Boss-Krone,
## glühende Augen und größere Hörner bei Gliederpuppen), massstab (Größe im
## Mesh: Dungeon-Boss 1.5, Kampf-Boss 1.1), akzent (Leuchtfarbe für Augen/
## Akzente bei Gliederpuppen, z. B. Elite lila).
static func fuer_archetyp(id: StringName, opt := {}) -> Node3D:
	var boss: bool = opt.get("boss", false)
	var massstab: float = opt.get("massstab", 1.0)
	var figur: Node3D
	if id == &"troll":
		figur = troll(massstab, boss, opt.get("akzent", null))
	elif id in ZweibeinerBau.ARTEN:
		figur = ZweibeinerBau.gegner(id, massstab, boss, opt.get("akzent", null))
	elif id in VierbeinerBau.ARTEN:
		figur = VierbeinerBau.gegner(id, massstab, boss, opt.get("akzent", null))
	elif id in KreaturenBau.ARTEN:
		figur = KreaturenBau.gegner(id, massstab, boss, opt.get("akzent", null))
	else:
		# Unbekannter Archetyp (neu generiert, noch ohne Eintrag): bunter Schleim.
		figur = VierbeinerBau.gegner(&"schleim", massstab, boss, opt.get("akzent", null),
			Color.from_hsv(float(absi(hash(id)) % 360) / 360.0, 0.55, 0.85))
	if boss:
		boss_krone(figur)
	return figur


# --- Schleime und Vierbeiner (Figuren 2.0, VierbeinerBau) -----------------------

## Tropfenschleim als Gliederpuppe; p.farbe = Beschwörung bzw. bunter
## Fallback-Schleim (gleiches Modell, Bläschen aus farbe.lightened(0.45)).
static func schleim(p := {}) -> Node3D:
	return VierbeinerBau.gegner(&"schleim", 1.0, false, null, p.get("farbe", null))


static func schleimstapel() -> Node3D:
	return VierbeinerBau.gegner(&"schleimstapel")


static func wolf() -> Node3D:
	return VierbeinerBau.gegner(&"wolf")


# --- Krabbler, Flieger, Konstrukte, Geist, Mimic (Figuren 2.0, KreaturenBau) ------
# Die früheren Einzelbauer bleiben als Hüllen (Showcase, ältere Aufrufer).

## Riesenspinne; p.pilzhut = Pilzkrabbel.
static func krabbler(p := {}) -> Node3D:
	return KreaturenBau.gegner(&"pilzkrabbel" if p.get("pilzhut", false) else &"spinne")


static func golem() -> Node3D:
	return KreaturenBau.gegner(&"golem")


static func fledermaus() -> Node3D:
	return KreaturenBau.gegner(&"fledermaus")


static func geist() -> Node3D:
	return KreaturenBau.gegner(&"geist")


static func mimic() -> Node3D:
	return KreaturenBau.gegner(&"mimic")


# --- Zweibeiner (Helden, Humanoide, Untote, Dämonen) ----------------------------
# Figuren 2.0: Helden und Zweibeiner-Gegner baut ZweibeinerBau als
# Gliederpuppen (STIL-3D.md 7h); fuer_archetyp und held_mit leiten dorthin.


## Wählbare Rüstungsfarben. Index = Position in SpriteLib.HERO_PORTRAITS —
## so behalten alte Spielstände ihre frühere "Porträt"-Wahl als Farbe.
const HELD_FARBEN := ["ruestung", "umhang", "moos", "lila", "gold", "kristall",
	"braun_hell", "maehne", "schleim", "eisen"]


## Rüstungsfarbe nach Namen (Helden ohne Farbwahl, z. B. Altbestand).
static func held_farbe(name: String) -> Color:
	return _p(HELD_FARBEN[absi(hash(name)) % HELD_FARBEN.size()])


## Freischaltbare Rüstungsfarben (Bestiarium-Stufen, Reihenfolge = Stufe):
## [ID = PAL-Name, Name DE, Name EN]. Gespeichert als portrait_tile
## SONDER_FARBE_BASIS + Index — außerhalb der Porträt-Tiles, so bleibt das
## Format gleich und Co-op-Mitspieler sehen die Farbe ohne Zusatzfeld.
const SONDER_FARBEN := [
	[&"obsidian", "Obsidian", "Obsidian"], [&"smaragd", "Smaragd", "Emerald"],
	[&"bernstein", "Bernstein", "Amber"], [&"rosenquarz", "Rosenquarz", "Rose quartz"],
	[&"mitternacht", "Mitternacht", "Midnight"], [&"silber", "Silber", "Silver"],
	[&"drachenblut", "Drachenblut", "Dragon blood"],
]
const SONDER_FARBE_BASIS := 1000


static func sonder_farb_index(id: StringName) -> int:
	for i in SONDER_FARBEN.size():
		if SONDER_FARBEN[i][0] == id:
			return i
	return -1


static func sonder_farb_name(id: StringName) -> String:
	var i := sonder_farb_index(id)
	return Loc.pick(SONDER_FARBEN[i][1], SONDER_FARBEN[i][2]) if i >= 0 else String(id)


## portrait_tile-Wert einer Sonderfarbe (-1 = unbekannt).
static func sonder_farb_tile(id: StringName) -> int:
	var i := sonder_farb_index(id)
	return SONDER_FARBE_BASIS + i if i >= 0 else -1


## Rüstungsfarbe aus der gespeicherten Wahl (portrait_tile), sonst nach Namen.
static func held_farbe_aus(tile: int, name: String) -> Color:
	var sonder := tile - SONDER_FARBE_BASIS
	if sonder >= 0 and sonder < SONDER_FARBEN.size():
		return _p(String(SONDER_FARBEN[sonder][0]))
	var i := SpriteLib.HERO_PORTRAITS.find(tile)
	return _p(HELD_FARBEN[i % HELD_FARBEN.size()]) if i >= 0 else held_farbe(name)


## Sichtbare Ausrüstung als Dictionary (Item-Basis-IDs + Rüstungsklasse) —
## netzwerk- und cache-tauglich.
static func ausruestung_von(c: Combatant) -> Dictionary:
	var a := {"bekannt": true}
	var waffe: ItemInstance = c.equipment.get(Enums.EquipSlot.WEAPON)
	var neben: ItemInstance = c.equipment.get(Enums.EquipSlot.OFF_HAND)
	var panzer: ItemInstance = c.equipment.get(Enums.EquipSlot.ARMOR)
	if waffe != null:
		a["waffe"] = String(waffe.base.id)
	if neben != null:
		a["neben"] = String(neben.base.id)
	if panzer != null:
		a["ruestung"] = int(panzer.base.armor_class)
	# Rein optisch: Frisur/Haarfarbe aus dem Namen, Stab-Kristall nach dem
	# Element des ersten Zauber-Skills (Feuer flammt, Gift ist moosgrün).
	a["haar"] = absi(hash(c.display_name)) % 15
	var element := _skill_element(c.skills)
	if element != "":
		a["element"] = element
	return a


static func _skill_element(skills: Array) -> String:
	for skill in skills:
		for block in (skill as Skill).blocks:
			if block == null:
				continue
			if block.id == &"elem_fire":
				return "feuer"
			if block.id == &"elem_poison":
				return "gift"
	return ""


## Ein Held mit seiner echten Ausrüstung: Waffe, Nebenhand und Rüstungsart
## bestimmen die Figur (Rolle: Tank, Krieger, Schurke, Magier, Heiler,
## Abenteurer — ZweibeinerBau). Ohne Ausrüstungs-Info: Tank mit Schwert &
## Schild (Farbwahl-Symbol; Sonderfarben tragen Zusatzschmuck).
static func held_mit(farbe: Color, a := {}) -> Node3D:
	return ZweibeinerBau.held(farbe, a)


## Vorschau-Held für die Heldenerstellung: Farbwahl + Starter-Ausrüstung.
static func starter_held(tile: int, loadout_id: StringName) -> Node3D:
	var kit: Dictionary = HeroLibrary.STARTER_LOADOUTS.get(loadout_id, {})
	var a := {"bekannt": true, "waffe": String(kit.get("weapon", &"")), "neben": String(kit.get("offhand", &""))}
	var bloecke: Array = kit.get("blocks", [])
	if &"elem_fire" in bloecke:
		a["element"] = "feuer"
	elif &"elem_poison" in bloecke:
		a["element"] = "gift"
	return held_mit(held_farbe_aus(tile, ""), a)


const FARB_NAMEN := [["Königsblau", "Royal blue"], ["Blutrot", "Blood red"],
	["Waldgrün", "Forest green"], ["Violett", "Violet"], ["Gold", "Gold"],
	["Türkis", "Turquoise"], ["Sand", "Sand"], ["Karmesin", "Crimson"],
	["Mint", "Mint"], ["Eisen", "Iron"]]


## Wählbare portrait_tile-Werte: die Grundfarben, dann die freigeschalteten
## Sonderfarben (frei = IDs, z. B. GameState.farben_frei) in Stufen-Reihenfolge.
static func farb_tiles(frei: Array = []) -> Array[int]:
	var tiles: Array[int] = []
	tiles.append_array(SpriteLib.HERO_PORTRAITS)
	for eintrag in SONDER_FARBEN:
		if eintrag[0] in frei:
			tiles.append(sonder_farb_tile(eintrag[0]))
	return tiles


## Anzeigename einer Farbwahl (portrait_tile-Wert).
static func farb_name(tile: int) -> String:
	var sonder := tile - SONDER_FARBE_BASIS
	if sonder >= 0 and sonder < SONDER_FARBEN.size():
		return sonder_farb_name(SONDER_FARBEN[sonder][0])
	var index := SpriteLib.HERO_PORTRAITS.find(tile)
	var name_paar: Array = FARB_NAMEN[maxi(0, index) % FARB_NAMEN.size()]
	return Loc.pick(name_paar[0], name_paar[1])


## Auswahlfeld für die Rüstungsfarbe: Symbol = 3D-Porträt in dieser Farbe,
## Metadaten = Wert für portrait_tile (bleibt spielstandkompatibel).
## frei: freigeschaltete Sonderfarben (Bestiarium-Stufen).
static func farb_auswahl(studio: PortraitStudio, frei: Array = []) -> OptionButton:
	var auswahl := OptionButton.new()
	auswahl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auswahl.add_theme_constant_override("icon_max_width", 28)
	var tiles := farb_tiles(frei)
	for index in tiles.size():
		var tile: int = tiles[index]
		auswahl.add_icon_item(studio.textur("farbe:%d" % tile,
				func() -> Node3D: return held_mit(held_farbe_aus(tile, ""))),
			Loc.pick("Rüstung: %s", "Armor: %s") % farb_name(tile))
		auswahl.set_item_metadata(index, tile)
	return auswahl


## Held direkt aus dem Combatant (Farbwahl + angelegte Ausrüstung).
static func held_aus(c: Combatant) -> Node3D:
	return held_mit(held_farbe_aus(c.portrait_tile, c.display_name), ausruestung_von(c))


## Kampf-Boss: Größe im Mesh (der Platzhalter ist schon ×1.2, der Riesen-
## Deckel der Bühne greift weiter).
const KAMPF_BOSS_MASSSTAB := 1.1


## Die Figur zu einem Kämpfer: Beschwörungen nach Meta, Helden nach Farbe +
## Ausrüstung, Gegner nach Archetyp — plus Rang-, Sonder- und Boss-Schmuck.
static func fuer_kaempfer(c: Combatant) -> Node3D:
	var figur: Node3D
	var rang := String(c.get_meta(&"rang", ""))
	var opt := {}
	if c.is_boss:
		opt = {"boss": true, "massstab": KAMPF_BOSS_MASSSTAB}
	elif rang == "elite":
		opt = {"akzent": _p("lila")}
	if c.has_meta(&"figur"):
		figur = fuer_archetyp(c.get_meta(&"figur"))
	elif c.is_player and c.archetype_id == &"":
		return held_aus(c)
	elif c.archetype_id != &"":
		figur = fuer_archetyp(c.archetype_id, opt)
	else:
		figur = schleim({"farbe": Color.from_hsv(float(absi(hash(c.display_name)) % 360) / 360.0, 0.55, 0.85)})
	return schmuecken(figur, rang, bool(c.get_meta(&"gulden", false)), String(c.get_meta(&"sonder", "")),
		c.is_boss and not c.has_meta(&"figur"))


## Schlüssel für Porträt-Caches: gleiche Figur = gleicher Schlüssel.
static func schluessel_fuer(c: Combatant) -> String:
	var zusatz := "|%s|%s|%s|%s" % [c.get_meta(&"rang", ""), c.get_meta(&"gulden", false), c.get_meta(&"sonder", ""),
		c.is_boss]
	if c.has_meta(&"figur"):
		return "figur:" + String(c.get_meta(&"figur")) + zusatz
	if c.is_player and c.archetype_id == &"":
		return "held:%s|%d|%s" % [c.display_name, c.portrait_tile, str(ausruestung_von(c))]
	if c.archetype_id != &"":
		return "arch:" + String(c.archetype_id) + zusatz
	return "name:" + c.display_name + zusatz


const GOLD_CODE := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, shadows_disabled;
uniform vec4 farbe : source_color = vec4(1.0, 0.8, 0.3, 0.35);
void fragment() {
	// Wandernder Glanzstreifen über der Figur.
	float streifen = smoothstep(0.85, 1.0, sin(TIME * 2.5 + VERTEX.y * 6.0) * 0.5 + 0.5);
	ALBEDO = farbe.rgb * (farbe.a + streifen * 0.45);
	ALPHA = 1.0;
}
"""
static var _gold_mat: ShaderMaterial
static var _strahl_mat: ShaderMaterial


## Rang-, Sonder- und Boss-Schmuck (STIL-3D.md 7d), einheitlich für alle
## Figuren über ihre Anker (anker_kopf, anker_ruecken; Boden = −schwebt):
## - Elite: dünner lila Leuchtring mit drei Kristallsplittern (im Porträt ein
##   schmaler Strich, keine Pfütze); Gliederpuppen bekommen lila Augen.
## - Champion: roter Doppelring mit sechs Zacken + Hörnerstummel am Kopf.
## - Gülden: echtes Gold (Stil3D.gold) — für gebackene Figuren EIN Material.
## - Strahlend: kühler Glanz nur auf Körpern (nicht auf Konturen) + Silberring.
## - Kartenhüter: Schriftrolle auf dem Rücken, gestrichelter lila Ring — über
##   dem Kopf bleibt Platz für Status-Zeichen und Gegner-Marker.
## - Boss (Kampf): Boss-Krone, rotes Runen-Bodensiegel ohne Füllung und
##   aufsteigende Glutfunken. Im Dungeon trägt die Arena Siegel und Säule.
## Ringe und Splitter sind je Art und Größe gebacken (ein Mesh, gecacht).
static func schmuecken(figur: Node3D, rang: String, gulden: bool, sonder := "", boss := false) -> Node3D:
	var boden := Vector3(0, -float(figur.get_meta("schwebt", 0.0)) + 0.015, 0)
	# Meta "ring_faktor": breite Figuren (Golem, Pilzstamm) bekommen weitere
	# Ringe, sonst verschwinden sie unter dem Körper.
	var g := maxf(1.0, float(figur.get_meta("groesse", 1.0))) * float(figur.get_meta("ring_faktor", 1.0))
	if rang == "elite" or rang == "champion":
		_boden_an(figur, _schmuck_knoten(rang, g), boden)
		if rang == "champion" and not figur.get_meta("hoerner", false):
			var kopf := anker(figur, "anker_kopf")
			_schmuck_an(figur, kopf[0], _schmuck_knoten("champion_hoerner", g), kopf[1])
	if boss:
		boss_krone(figur)
		_boden_an(figur, _schmuck_knoten("boss_siegel", g), boden)
		var funken := WeltMaterial.funken(_p("boss_siegel").lightened(0.2), 10, Vector3(0.36, 0.05, 0.36) * g,
			0.6, 1.6, 1.1)
		funken.name = "BossFunken"
		_boden_an(figur, funken, boden)
	if gulden:
		# Echtes Gold: Toon-Teile (auch gebackene Figuren und Schmuck) bekommen
		# ihr Gold-Gegenstück; Konturen bleiben, Fremdmaterial bekommt den Glanz.
		for mi in figur.find_children("*", "MeshInstance3D", true, false):
			var teil := mi as MeshInstance3D
			if Stil3D.ist_toon(teil.material_override):
				teil.material_override = Stil3D.gold(teil.material_override)
			elif not Stil3D.ist_kontur(teil.material_override):
				if _gold_mat == null:
					var shader := Shader.new()
					shader.code = GOLD_CODE
					_gold_mat = ShaderMaterial.new()
					_gold_mat.shader = shader
				teil.material_overlay = _gold_mat
	# Strahlende (XP-Jackpot): kühler, hellblauer Glanz — nur auf Körpern.
	if sonder == "strahlend":
		if _strahl_mat == null:
			var shader := Shader.new()
			shader.code = GOLD_CODE
			_strahl_mat = ShaderMaterial.new()
			_strahl_mat.shader = shader
			_strahl_mat.set_shader_parameter(&"farbe", Color(0.55, 0.9, 1.0, 0.4))
		for mi in figur.find_children("*", "MeshInstance3D", true, false):
			if not Stil3D.ist_kontur((mi as MeshInstance3D).material_override):
				(mi as MeshInstance3D).material_overlay = _strahl_mat
		_boden_an(figur, _schmuck_knoten("strahlend", g), boden)
	if sonder == "karte":
		var ruecken := anker(figur, "anker_ruecken")
		_schmuck_an(figur, ruecken[0], _schmuck_knoten("karte_rolle", g), ruecken[1])
		_boden_an(figur, _schmuck_knoten("karte_ring", g), boden)
	return figur


## Boss-Krone am Kopf-Anker (hängt am Kopf-Glied, nickt also mit): goldener
## Reif, fünf Zacken mit Drachenblut-Steinen, 10° schräg aufgesetzt. Figuren
## mit eigener Krone (Meta "hat_krone": König-Schleim, Todesmeister,
## Dämonenkönig — als Boss mit Großkrone im Bausatz; Gottschleim: Schein)
## bekommen keine Zusatzkrone.
static func boss_krone(figur: Node3D) -> void:
	if figur.has_meta("boss_krone"):
		return
	var g := float(figur.get_meta("groesse", 1.0))
	if figur.get_meta("hat_krone", false):
		return  # eigene (Groß-)Krone bzw. Heiligenschein aus dem Bausatz
	var kopf := anker(figur, "anker_kopf")
	var knoten := _schmuck_knoten("krone", 0.12 * maxf(1.0, g))
	(kopf[0] as Node3D).add_child(knoten)
	# anker_kopf_drehung: Kopf-Glied mit schräger Ruhe (Mimic-Deckel) — die
	# Krone sitzt in Ruhe trotzdem aufrecht.
	var dreh: Vector3 = figur.get_meta("anker_kopf_drehung", Vector3.ZERO)
	knoten.position = (kopf[1] as Vector3) + Basis.from_euler(dreh * Gliederpuppe.GRAD) * Vector3(0, -0.03 * g, 0)
	knoten.rotation_degrees = dreh + Vector3(0, 0, 10.0)
	figur.set_meta("boss_krone", knoten)


## Anker einer Figur: [Eltern-Node, lokale Lage]. Gliederpuppen hängen den
## Kopf-Anker an ihr Kopf-Glied (Meta "<anker>_glied"); fehlt ein Anker,
## gilt der Umriss (Scheitel bzw. Rücken auf 60 % Höhe).
static func anker(figur: Node3D, art: String) -> Array:
	var eltern: Node3D = figur
	var glied := String(figur.get_meta(art + "_glied", ""))
	if glied != "":
		eltern = (figur.get_meta("glieder", {}) as Dictionary).get(glied, figur)
	if figur.has_meta(art):
		return [eltern, figur.get_meta(art)]
	var box := umriss_lokal(figur)
	var mitte := box.get_center()
	if art == "anker_ruecken":
		return [figur, Vector3(mitte.x, box.position.y + box.size.y * 0.6, box.position.z + 0.04)]
	return [figur, Vector3(mitte.x, box.end.y - 0.02, mitte.z)]


## Umriss aller Meshes im Raum der Figur-Wurzel (ohne Szenenbaum).
static func umriss_lokal(figur: Node3D) -> AABB:
	var box := AABB()
	var erste := true
	for kind in figur.find_children("*", "MeshInstance3D", true, false):
		var mi := kind as MeshInstance3D
		var t := mi.transform
		var p := mi.get_parent()
		while p != figur and p is Node3D:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		var teil := t * mi.get_aabb()
		box = teil if erste else box.merge(teil)
		erste = false
	return box if not erste else AABB(Vector3(-0.3, 0, -0.3), Vector3(0.6, 0.8, 0.6))


static func _schmuck_an(figur: Node3D, eltern: Node3D, knoten: Node3D, pos: Vector3) -> void:
	knoten.position = pos
	eltern.add_child(knoten)
	var liste: Array = figur.get_meta("schmuck", [])
	liste.append(knoten)
	figur.set_meta("schmuck", liste)


## Bodenschmuck (Ringe, Siegel, Funken): Meta "boden_teile" — Dungeon,
## Kampfbühne und Showcase halten diese Teile jedes Bild am Boden (wie den
## Blob-Schatten), auch wenn die Figur schwebt oder wippt.
static func _boden_an(figur: Node3D, knoten: Node3D, boden: Vector3) -> void:
	_schmuck_an(figur, figur, knoten, boden)
	var liste: Array = figur.get_meta("boden_teile", [])
	liste.append(knoten)
	figur.set_meta("boden_teile", liste)


## Gebackener Bodenschmuck einer Art (_schmuck_bauen) am Boden der Figur —
## z. B. die Glutscheibe des Gottschleims; Größe aus Meta "groesse".
static func boden_schmuck(figur: Node3D, art: String) -> void:
	var g := maxf(1.0, float(figur.get_meta("groesse", 1.0)))
	_boden_an(figur, _schmuck_knoten(art, g), Vector3(0, -float(figur.get_meta("schwebt", 0.0)) + 0.015, 0))


## Bodenteile einer Figur auf den Boden setzen: hoehe = Abstand der Wurzel
## über dem Boden (Welt), skala_y = Wurzel-Skalierung (Kampfbühne).
static func boden_halten(figur: Node3D, hoehe: float, skala_y := 1.0) -> void:
	for teil in figur.get_meta("boden_teile", []):
		if is_instance_valid(teil):
			(teil as Node3D).position.y = (0.015 - hoehe) / maxf(0.01, skala_y)


static var _schmuck_cache: Dictionary = {}


## Gebackener Schmuck je Art und Größe (Ring + Splitter = EIN Mesh, ohne
## Schattenwurf). Arten: elite, champion, champion_hoerner, strahlend,
## karte_rolle, karte_ring, boss_siegel, gott_ring, krone (g = Radius).
static func _schmuck_knoten(art: String, g: float) -> Node3D:
	var key := "%s|%.3f" % [art, g]
	if not _schmuck_cache.has(key):
		var b := Bausatz.new()
		b.sparsam = true
		_schmuck_bauen(b, art, g)
		_schmuck_cache[key] = [b.mesh(), b.huelle()]
	var daten: Array = _schmuck_cache[key]
	return Bausatz.figur_knoten_aus("Schmuck_" + art, daten[0], daten[1], false)


static func _ring(b: Bausatz, r: float, rohr: float, farbe: Color, leuchten: float, y := 0.0) -> void:
	var t := TorusMesh.new()
	t.inner_radius = r - rohr
	t.outer_radius = r + rohr
	t.rings = 40
	t.ring_segments = 6
	b.teil(t, farbe, Vector3(0, y, 0), Vector3.ZERO, false, leuchten)


static func _schmuck_bauen(b: Bausatz, art: String, g: float) -> void:
	match art:
		"elite":
			var lila := _p("lila")
			_ring(b, 0.55 * g, 0.022, lila, 0.6)
			for i in 3:
				var w := TAU * i / 3.0 + 0.4
				var t := Transform3D(Basis(Vector3.UP, w), Vector3(sin(w) * 0.55 * g, 0.04, cos(w) * 0.55 * g))
				t = t * Transform3D(Basis.from_euler(Vector3(20, 0, 0) * Gliederpuppe.GRAD), Vector3.ZERO)
				b.teil_t(Stil3D.kegel(0.035, 0.12, 8), lila.lightened(0.15), t * Transform3D(Basis(),
					Vector3(0, 0.05, 0)), true, 0.5)
		"champion":
			var rot := _p("maehne")
			_ring(b, 0.55 * g, 0.02, rot, 0.5)
			_ring(b, 0.62 * g, 0.02, rot, 0.5)
			for i in 6:
				var w := TAU * i / 6.0
				var t := Transform3D(Basis(Vector3.UP, w), Vector3(sin(w) * 0.585 * g, 0.0, cos(w) * 0.585 * g))
				t = t * Transform3D(Basis.from_euler(Vector3(30, 0, 0) * Gliederpuppe.GRAD), Vector3.ZERO)
				b.teil_t(Stil3D.kegel(0.04, 0.15, 8), rot, t * Transform3D(Basis(), Vector3(0, 0.07, 0)), true, 0.4)
		"champion_hoerner":
			for s in [-1.0, 1.0]:
				var t := Transform3D(Basis.from_euler(Vector3(-10, 0, -25.0 * s) * Gliederpuppe.GRAD),
					Vector3(0.09 * s * g, -0.02, 0))
				Gliederpuppe.kette(b, t, 3, 0.13 * g, 0.04 * g, 0.012, Vector3(-14, 0, 12.0 * s),
					_p("knochen"), _p("maehne"), 0.5)
		"strahlend":
			_ring(b, 0.55 * g, 0.018, _p("silber"), 0.5)
		"karte_rolle":
			var rolle := Stil3D.zylinder(0.06, 0.06, 0.36, 14)
			b.teil(rolle, _p("knochen"), Vector3.ZERO, Vector3(0, 0, 90), true, 0.2)
			for s in [-1.0, 1.0]:
				b.teil(Stil3D.kugel(0.035, -1.0, 10), _p("holz"), Vector3(0.21 * s, 0, 0))
			b.teil(Stil3D.box(0.04, 0.26, 0.135), _p("leder"), Vector3(0.05, 0, 0), Vector3(0, 0, 32), false)
		"karte_ring":
			for i in 12:
				var w := TAU * i / 12.0
				b.teil(Stil3D.box(0.12, 0.02, 0.03), _p("lila"), Vector3(sin(w) * 0.6 * g, 0, cos(w) * 0.6 * g),
					Vector3(0, rad_to_deg(w) + 90.0, 0), false, 0.6)
		"boss_siegel":
			var rot := _p("boss_siegel")
			_ring(b, 0.66 * g, 0.02, rot, 0.5)
			_ring(b, 0.5 * g, 0.012, rot, 0.45)
			for i in 6:
				var w := TAU * i / 6.0 + PI / 6.0
				b.teil(Stil3D.box(0.07, 0.012, 0.07), rot, Vector3(sin(w) * 0.58 * g, 0, cos(w) * 0.58 * g),
					Vector3(0, rad_to_deg(w) + 45.0, 0), false, 0.5)
		"gott_ring":  # Gottschleim: Glutscheibe mit acht Runen außen (ohne Füllung der Mitte)
			var glut := _p("glut")
			_ring(b, 0.5 * g, 0.03, glut, 0.6)
			_ring(b, 0.62 * g, 0.018, glut, 0.55)
			for i in 8:
				var w := TAU * i / 8.0
				b.teil(Stil3D.box(0.06 * g, 0.012, 0.12 * g), glut, Vector3(sin(w) * 0.72 * g, 0.004, cos(w) * 0.72 * g),
					Vector3(0, rad_to_deg(w), 0), false, 0.75)
		"krone":
			Gliederpuppe.krone(b, Transform3D(), g, 5, _p("gold"), _p("drachenblut"), 0.3)


# --- Figuren 2.0 (Gliederpuppe) --------------------------------------------------

const TROLL_GROESSE := 1.4


## Troll — Beispielfigur des Gerüsts (STIL-3D.md 7g): Buckel-Gorilla aus
## einer Gliederpuppe. Rumpf gebacken (O-Beine, Lendenschurz, Bauch,
## Buckel, Moos, kleiner Kopf tief vor den Schultern), Pivots arm_r (Faust +
## Baumkeule) und arm_l (freie Faust). boss: glühende Augen, Hauer ×1.3
## mit glühenden Spitzen; akzent: Leuchtfarbe der Augen (Elite lila).
static func troll(massstab := 1.0, boss := false, akzent: Variant = null) -> Node3D:
	var g := TROLL_GROESSE * massstab
	var key := "troll|%.3f|%s|%s" % [g, boss, (akzent as Color).to_html() if akzent != null else "-"]
	return Gliederpuppe.gebacken(key, func() -> Gliederpuppe: return _troll_puppe(g, boss, akzent))


static func _troll_puppe(g: float, boss: bool, akzent: Variant) -> Gliederpuppe:
	var pu := Gliederpuppe.new("Troll", g)
	pu.meta("anim", "troll").meta("wippen", 0.008).meta("drehung", 12.0)
	pu.meta("anker_kopf", Vector3(0, 0.74, 0.25)).meta("anker_ruecken", Vector3(0, 0.66, -0.3))
	var haut := _p("troll")
	var b := pu.rumpf
	# Kurze O-Beine mit Klumpfüßen und Knochen-Zehen
	for s in [-1.0, 1.0]:
		b.teil(Stil3D.kapsel(0.085, 0.22), haut.darkened(0.12), Vector3(0.13 * s, 0.15, 0.0), Vector3(0, 0, -12.0 * s))
		b.teil(Stil3D.kugel(0.11, 0.09), haut.darkened(0.2), Vector3(0.15 * s, 0.045, 0.05))
		for z in 3:
			b.teil(Stil3D.kugel(0.026), _p("knochen"), Vector3(0.15 * s + (z - 1) * 0.045, 0.04, 0.15),
				Vector3.ZERO, false)
	# Lendenschurz mit Knochengürtel
	b.teil(Stil3D.zylinder(0.25, 0.3, 0.14), _p("leder"), Vector3(0, 0.27, 0.01))
	for i in 3:
		b.teil(Stil3D.kapsel(0.022, 0.11), _p("knochen"), Vector3(-0.1 + i * 0.1, 0.31, 0.27 - absf(i - 1) * 0.02),
			Vector3(0, 0, 90), false)
	# Rumpf: abgeflachte Kugel 15° vor, heller Bauch, Buckel hinten oben,
	# Schultern höher als der Kopf
	b.teil(Stil3D.kugel(0.34, 0.54), haut, Vector3(0, 0.5, 0.0), Vector3(15, 0, 0))
	b.teil(Stil3D.kugel(0.22, 0.3), haut.lightened(0.2), Vector3(0, 0.44, 0.16), Vector3.ZERO, false)  # Bauch: Farbfläche, ohne Hülle
	b.teil(Stil3D.kugel(0.21, 0.24), haut, Vector3(0, 0.7, -0.12))
	for s in [-1.0, 1.0]:
		b.teil(Stil3D.kugel(0.15), haut, Vector3(0.28 * s, 0.67, 0.03))
	# Moos-Flecken und Steinwarzen auf dem Rücken
	for v in [Vector3(-0.07, 0.8, -0.17), Vector3(0.13, 0.72, -0.26), Vector3(-0.04, 0.6, -0.33)]:
		b.teil(Stil3D.kugel(0.085, 0.07), _p("moos_dunkel"), v, Vector3(-50, 0, 0), false)
	for v in [Vector3(0.07, 0.81, -0.12), Vector3(-0.15, 0.72, -0.24), Vector3(0.2, 0.6, -0.26),
			Vector3(-0.07, 0.52, -0.35)]:
		b.teil(Stil3D.kugel(0.028), _p("stein"), v, Vector3.ZERO, false)
	# Kleiner Kopf tief vorn: Hängeohren, Brauenwulst, kleine Augen,
	# Knollennase, Unterbiss mit Hauern
	var kopf := Vector3(0, 0.58, 0.25)
	b.teil(Stil3D.kugel(0.16, 0.3), haut, kopf)
	for s in [-1.0, 1.0]:
		b.teil(Stil3D.prisma(0.1, 0.12, 0.035), haut.darkened(0.1), kopf + Vector3(0.155 * s, 0.0, -0.02),
			Vector3(0, -20.0 * s, -78.0 * s))
	b.teil(Stil3D.box(0.22, 0.05, 0.08), haut.darkened(0.3), kopf + Vector3(0, 0.072, 0.115), Vector3(12, 0, 0), false)
	var glut: Variant = _p("boss_siegel") if boss else akzent
	for s in [-1.0, 1.0]:
		var o := {"seite": s}
		if glut != null:
			o["iris"] = glut
			o["iris_leuchten"] = 0.8
		Gliederpuppe.auge(b, kopf + Vector3(0.064 * s, 0.022, 0.126), 0.04, o)
	b.teil(Stil3D.kugel(0.062, 0.07), haut.darkened(0.08), kopf + Vector3(0, -0.035, 0.17))
	Gliederpuppe.mund(b, kopf + Vector3(0, -0.095, 0.13), 0.13, "unterbiss",
		{"hauer": 0.075 * (1.3 if boss else 1.0), "hauer_leuchten": 0.4 if boss else 0.0,
		"hauer_farbe": _p("knochen")})
	# Arme: lange Arme mit Riesenfäusten (fast bis zum Boden); rechts die
	# Baumkeule, in Ruhe aufrecht vor der Schulter (beste Silhouette).
	for s in [-1.0, 1.0]:
		var glied_name := "arm_r" if s > 0.0 else "arm_l"
		var ruhe := Vector3(-108, 0, 6) if s > 0.0 else Vector3(-10, 0, -12)
		var arm := pu.glied(glied_name, Vector3(0.37 * s, 0.67, 0.04), ruhe)
		var hand := Gliederpuppe.arm(arm, 0.44, 0.085, haut, haut.darkened(0.1), 0.115)
		if s > 0.0:
			Gliederpuppe.waffe(arm, "baumkeule", Gliederpuppe.griff(hand, Vector3(118, 0, 0)))
	return pu


## Der Held des Spielers (Rüstungsfarbe = Unterscheidung im Co-op).
static func held(ruestung := Color("4a7ad8")) -> Node3D:
	return held_mit(ruestung)


# --- Objekte -----------------------------------------------------------------

## Truhe (gebacken, zwei Zeichenaufrufe): Füße, Korpus mit Leisten,
## gewölbter Deckel, Bänder in Raritätsfarbe, Messing-Eckbeschläge, Schloss.
static func truhe(band := Color("6e7385")) -> Node3D:
	return _truhe_bausatz(band).knoten("Truhe")


static func _truhe_bausatz(band: Color) -> Bausatz:
	var b := Bausatz.new()
	for x in [-0.26, 0.26]:
		for z in [-0.17, 0.17]:
			b.teil(Stil3D.box(0.08, 0.05, 0.08), _p("eisen") * 0.7, Vector3(x, 0.025, z))
	b.teil(Stil3D.box(0.62, 0.32, 0.42), _p("holz"), Vector3(0, 0.2, 0))
	b.teil(Stil3D.box(0.64, 0.05, 0.44), _p("holz_hell"), Vector3(0, 0.07, 0), Vector3.ZERO, false)
	var deckel := Stil3D.zylinder(0.21, 0.21, 0.62)
	deckel.radial_segments = 14
	b.teil(deckel, _p("holz_hell"), Vector3(0, 0.36, 0), Vector3(0, 0, 90))
	b.teil(Stil3D.box(0.65, 0.035, 0.45), _p("eisen"), Vector3(0, 0.36, 0), Vector3.ZERO, false)
	for x in [-0.2, 0.2]:
		var reif := Stil3D.zylinder(0.225, 0.225, 0.065)
		reif.radial_segments = 14
		b.teil(reif, band, Vector3(x, 0.36, 0), Vector3(0, 0, 90), false)
		b.teil(Stil3D.box(0.065, 0.32, 0.445), band, Vector3(x, 0.2, 0), Vector3.ZERO, false)
	for x in [-0.3, 0.3]:
		for z in [-0.2, 0.2]:
			b.teil(Stil3D.box(0.055, 0.1, 0.055), _p("messing"), Vector3(x, 0.31, z), Vector3.ZERO, false)
	b.teil(Stil3D.box(0.14, 0.16, 0.04), _p("gold"), Vector3(0, 0.33, 0.225))
	b.teil(Stil3D.box(0.03, 0.06, 0.01), _p("nacht"), Vector3(0, 0.32, 0.247), Vector3.ZERO, false)
	return b


## Tresor (Ebenen-Ziel): Steinkasten auf Sockel, Goldbänder, Nieten und
## eine runde Tresortür mit Speichen und glimmendem Schloss.
static func tresor() -> Node3D:
	var b := Bausatz.new()
	b.teil(Stil3D.box(0.92, 0.08, 0.68), _p("stein_dunkel") * 0.85, Vector3(0, 0.04, 0))
	b.teil(Stil3D.box(0.82, 0.5, 0.58), _p("stein_dunkel"), Vector3(0, 0.33, 0))
	b.teil(Stil3D.box(0.88, 0.14, 0.64), _p("stein"), Vector3(0, 0.65, 0))
	for x in [-0.33, 0.33]:
		b.teil(Stil3D.box(0.07, 0.62, 0.61), _p("gold"), Vector3(x, 0.36, 0), Vector3.ZERO, false)
	var tuer := Stil3D.zylinder(0.19, 0.19, 0.05)
	tuer.radial_segments = 16
	b.teil(tuer, _p("gold"), Vector3(0, 0.34, 0.3), Vector3(90, 0, 0))
	for w in [0.0, 60.0, 120.0]:
		b.teil(Stil3D.box(0.3, 0.035, 0.02), _p("messing"), Vector3(0, 0.34, 0.33), Vector3(0, 0, w), false)
	b.teil(Stil3D.kugel(0.05), _p("gold"), Vector3(0, 0.34, 0.34), Vector3.ZERO, false, 0.6)
	for x in [-0.25, 0.25]:
		for y in [0.15, 0.52]:
			b.teil(Stil3D.kugel(0.025), _p("messing"), Vector3(x, y, 0.295), Vector3.ZERO, false)
	return b.knoten("Tresor")


## Schwebender Schlüssel über dem Schlüsselträger.
static func schluessel() -> Node3D:
	var n := _wurzel("Schluessel", 0.08)
	var gold := _p("gold")
	Stil3D.teil(n, Stil3D.box(0.06, 0.32, 0.06), gold, Vector3.ZERO, Vector3.ZERO, true, gold * 0.5)
	Stil3D.teil(n, Stil3D.kugel(0.09), gold, Vector3(0, 0.2, 0), Vector3.ZERO, true, gold * 0.5)
	Stil3D.teil(n, Stil3D.box(0.1, 0.05, 0.05), gold, Vector3(0.06, -0.1, 0), Vector3.ZERO, false, gold * 0.5)
	Stil3D.teil(n, Stil3D.box(0.08, 0.05, 0.05), gold, Vector3(0.05, -0.02, 0), Vector3.ZERO, false, gold * 0.5)
	return n


## Risiko-Truhe: goldene Truhe mit glimmendem Dämonenauge und Hörnchen.
static func risikotruhe() -> Node3D:
	var b := _truhe_bausatz(_p("gold"))
	b.teil(Stil3D.kugel(0.075), _p("daemon"), Vector3(0, 0.58, 0.1), Vector3.ZERO, true, 0.7)
	b.teil(Stil3D.kugel(0.03), _p("schwarz"), Vector3(0, 0.59, 0.165), Vector3.ZERO, false)
	for x in [-0.16, 0.16]:
		b.teil(Stil3D.kegel(0.04, 0.14), _p("daemon_dunkel"), Vector3(x, 0.6, 0), Vector3(0, 0, -x * 140.0))
	return b.knoten("Risikotruhe")


## Schrein: Stufensockel, Säule, Becken mit leuchtendem Wasser in Typfarbe,
## Runensteine am Sockel; darüber ein schwebender Kristall (Meta "kristall",
## dreht sich in der Dungeon-Welt).
static func schrein(wasser: Color) -> Node3D:
	var b := Bausatz.new()
	var sockel := Stil3D.zylinder(0.38, 0.4, 0.08)
	sockel.radial_segments = 10
	b.teil(sockel, _p("stein_dunkel"), Vector3(0, 0.04, 0))
	var stufe := Stil3D.zylinder(0.3, 0.32, 0.08)
	stufe.radial_segments = 10
	b.teil(stufe, _p("stein"), Vector3(0, 0.12, 0))
	var saeule := Stil3D.zylinder(0.13, 0.16, 0.3)
	saeule.radial_segments = 8
	b.teil(saeule, _p("stein_dunkel"), Vector3(0, 0.31, 0))
	var becken := Stil3D.zylinder(0.36, 0.26, 0.14)
	becken.radial_segments = 12
	b.teil(becken, _p("stein"), Vector3(0, 0.52, 0))
	b.teil(Stil3D.zylinder(0.29, 0.29, 0.02), wasser, Vector3(0, 0.59, 0), Vector3.ZERO, false, 0.6)
	for i in 4:
		var w := TAU * i / 4.0 + PI * 0.25
		b.teil(Stil3D.box(0.06, 0.1, 0.025), wasser, Vector3(sin(w) * 0.37, 0.05, cos(w) * 0.37),
			Vector3(0, rad_to_deg(w), 0), false, 0.7)
	var n := b.knoten("Schrein")
	var k := Bausatz.new()
	k.teil(Stil3D.kegel(0.1, 0.2), wasser, Vector3(0, 0.1, 0), Vector3.ZERO, true, 0.65)
	k.teil(Stil3D.kegel(0.1, 0.2), wasser, Vector3(0, -0.1, 0), Vector3(180, 0, 0), true, 0.65)
	var kristall := k.knoten("Kristall")
	kristall.position = Vector3(0, 0.92, 0)
	n.add_child(kristall)
	n.set_meta("kristall", kristall)
	return n


## Opferstein: dunkler Block, Steinplatte mit Blutschale, glimmende Runen
## und zwei Kerzen an den Ecken.
static func altar() -> Node3D:
	var b := Bausatz.new()
	b.teil(Stil3D.box(0.62, 0.06, 0.48), _p("stein_dunkel") * 0.8, Vector3(0, 0.03, 0))
	b.teil(Stil3D.box(0.56, 0.32, 0.42), _p("robe_schwarz"), Vector3(0, 0.22, 0))
	b.teil(Stil3D.box(0.72, 0.1, 0.52), _p("stein_dunkel"), Vector3(0, 0.43, 0))
	for x in [-0.16, 0.0, 0.16]:
		b.teil(Stil3D.box(0.06, 0.08, 0.02), _p("daemon"), Vector3(x, 0.24, 0.215), Vector3.ZERO, false, 0.8)
	var schale := Stil3D.zylinder(0.1, 0.07, 0.05)
	schale.radial_segments = 10
	b.teil(schale, _p("eisen"), Vector3(0.1, 0.505, 0.04))
	b.teil(Stil3D.zylinder(0.08, 0.08, 0.01), _p("daemon_dunkel"), Vector3(0.1, 0.53, 0.04), Vector3.ZERO, false, 0.3)
	for t in [[Vector3(-0.27, 0.48, -0.17), 0.16], [Vector3(-0.2, 0.48, 0.18), 0.1]]:
		var p: Vector3 = t[0]
		var h: float = t[1]
		b.teil(Stil3D.zylinder(0.03, 0.035, h), _p("kerze"), p + Vector3(0, h * 0.5, 0))
		b.teil(Stil3D.kugel(0.028, 0.055), _p("flamme"), p + Vector3(0, h + 0.03, 0), Vector3.ZERO, false, 1.0)
	return b.knoten("Altar")


## Feuerschale auf einem Steinsockel (Boss-Arena, Boss-Eingang): Glut und
## Flammen leuchten selbst, Licht kommt aus dem Licht-Pool der Welt.
static func feuerschale(stein := Color("6b6779")) -> Node3D:
	var b := Bausatz.new()
	b.teil(Stil3D.box(0.42, 0.1, 0.42), stein * 0.85, Vector3(0, 0.05, 0))
	var schaft := Stil3D.zylinder(0.12, 0.16, 0.56)
	schaft.radial_segments = 8
	b.teil(schaft, stein, Vector3(0, 0.38, 0))
	var schale := Stil3D.zylinder(0.3, 0.16, 0.16)
	schale.radial_segments = 12
	b.teil(schale, _p("eisen"), Vector3(0, 0.74, 0))
	b.teil(Stil3D.zylinder(0.31, 0.31, 0.03), _p("messing"), Vector3(0, 0.815, 0), Vector3.ZERO, false)
	b.teil(Stil3D.kugel(0.24, 0.1), _p("glut"), Vector3(0, 0.82, 0), Vector3.ZERO, false, 0.9)
	for t in [[Vector3(0, 0.95, 0), 0.15, 0.36], [Vector3(0.09, 0.9, 0.06), 0.09, 0.22],
			[Vector3(-0.1, 0.9, -0.03), 0.08, 0.2]]:
		b.teil(Stil3D.kegel(t[1], t[2]), _p("flamme"), t[0], Vector3.ZERO, false, 1.0)
	return b.knoten("Feuerschale")


## Banner an der Wand (Boss-Gang): Stange, Tuch mit Goldsaum und Zeichen,
## spitzes Ende. Hängt mit dem Rücken an der Wand und blickt nach +Z.
static func banner(tuch := Color("7e2232")) -> Node3D:
	var b := Bausatz.new()
	var stange := Stil3D.zylinder(0.025, 0.025, 0.56)
	stange.radial_segments = 6
	b.teil(stange, _p("eisen"), Vector3(0, 0, 0.04), Vector3(0, 0, 90))
	b.teil(Stil3D.box(0.42, 0.62, 0.025), tuch, Vector3(0, -0.33, 0.03))
	b.teil(Stil3D.prisma(0.42, 0.18, 0.025), tuch, Vector3(0, -0.73, 0.03), Vector3(180, 0, 0))
	b.teil(Stil3D.box(0.43, 0.04, 0.03), _p("gold"), Vector3(0, -0.6, 0.032), Vector3.ZERO, false)
	b.teil(Stil3D.box(0.12, 0.12, 0.03), _p("gold"), Vector3(0, -0.3, 0.035), Vector3(0, 0, 45), false, 0.25)
	for x in [-0.22, 0.22]:
		b.teil(Stil3D.kugel(0.035), _p("messing"), Vector3(x, 0, 0.04))
	return b.knoten("Banner")


## Fackel; mit_licht = eigenes OmniLight (Menü, Kampf). Der Dungeon nutzt
## stattdessen seinen Licht-Pool (Lichtlimits) und hängt sie in einen
## Wandhalter (Platte, Arm, Tülle).
static func fackel(mit_licht := true, wandhalter := false) -> Node3D:
	var n := _wurzel("Fackel", 0.0)
	if wandhalter:
		Stil3D.teil(n, Stil3D.box(0.16, 0.24, 0.03), _p("eisen") * 0.7, Vector3(0, -0.02, -0.08))
		Stil3D.teil(n, Stil3D.box(0.04, 0.04, 0.12), _p("eisen"), Vector3(0, -0.06, -0.02))
		Stil3D.teil(n, Stil3D.zylinder(0.065, 0.04, 0.08), _p("eisen"), Vector3(0, -0.06, 0.03))
	Stil3D.teil(n, Stil3D.zylinder(0.05, 0.035, 0.3), _p("holz"), Vector3(0, 0, 0), Vector3(-20, 0, 0))
	Stil3D.teil(n, Stil3D.kugel(0.08, 0.14), _p("flamme"), Vector3(0, 0.18, 0.05), Vector3.ZERO, false,
		_p("flamme"))
	Stil3D.teil(n, Stil3D.kugel(0.045, 0.09), _p("glut"), Vector3(0, 0.2, 0.07), Vector3.ZERO, false,
		_p("glut"))
	if not mit_licht:
		return n
	var licht := OmniLight3D.new()
	licht.light_color = Color(1.0, 0.55, 0.22)
	licht.light_energy = 0.7
	licht.omni_range = 3.2
	licht.omni_attenuation = Stil3D.PUNKTLICHT_ABFALL
	licht.position = Vector3(0, 0.25, 0.3)
	n.add_child(licht)
	n.set_meta("licht", licht)
	return n


# --- Deko (rein optisch, Biom-typisch) ----------------------------------------

static func deko(art: String) -> Node3D:
	var n := _wurzel("Deko_" + art, 0.0)
	match art:
		"pilz":
			Stil3D.teil(n, Stil3D.zylinder(0.05, 0.06, 0.18), _p("knochen"), Vector3(0, 0.09, 0))
			Stil3D.teil(n, Stil3D.kugel(0.15, 0.12), _p("pilz_rot"), Vector3(0, 0.2, 0))
			Stil3D.teil(n, Stil3D.zylinder(0.03, 0.04, 0.1), _p("knochen"), Vector3(0.15, 0.05, 0.08))
			Stil3D.teil(n, Stil3D.kugel(0.08, 0.07), _p("pilz_rot"), Vector3(0.15, 0.11, 0.08))
		"felsbrocken":
			Stil3D.teil(n, Stil3D.kugel(0.26, 0.3), _p("stein_dunkel"), Vector3(0, 0.14, 0))
			Stil3D.teil(n, Stil3D.kugel(0.15, 0.16), _p("stein"), Vector3(0.2, 0.08, 0.12))
			Stil3D.teil(n, Stil3D.kugel(0.14, 0.06), _p("moos"), Vector3(-0.05, 0.27, 0.02), Vector3.ZERO, false)
		"knochen":
			Stil3D.teil(n, Stil3D.kugel(0.11, 0.12), _p("knochen"), Vector3(0, 0.06, 0))
			for x in [-0.04, 0.04]:
				Stil3D.teil(n, Stil3D.kugel(0.025), _p("schwarz"), Vector3(x, 0.08, 0.09), Vector3.ZERO, false)
			Stil3D.teil(n, Stil3D.kapsel(0.025, 0.3), _p("knochen"), Vector3(0.18, 0.03, -0.05), Vector3(90, 40, 0))
		"amboss":
			Stil3D.teil(n, Stil3D.box(0.16, 0.16, 0.16), _p("eisen") * 0.7, Vector3(0, 0.08, 0))
			Stil3D.teil(n, Stil3D.box(0.4, 0.12, 0.2), _p("eisen"), Vector3(0, 0.22, 0))
		"fass":
			Stil3D.teil(n, Stil3D.zylinder(0.18, 0.18, 0.4), _p("holz"), Vector3(0, 0.2, 0))
			for y in [0.08, 0.32]:
				Stil3D.teil(n, Stil3D.zylinder(0.19, 0.19, 0.03), _p("eisen"), Vector3(0, y, 0), Vector3.ZERO, false)
		"grabstein":
			Stil3D.teil(n, Stil3D.box(0.34, 0.4, 0.1), _p("stein"), Vector3(0, 0.2, 0))
			Stil3D.teil(n, Stil3D.zylinder(0.17, 0.17, 0.1), _p("stein"), Vector3(0, 0.4, 0), Vector3(90, 0, 0))
			Stil3D.teil(n, Stil3D.box(0.12, 0.03, 0.02), _p("stein_dunkel"), Vector3(0, 0.3, 0.06), Vector3.ZERO, false)
	return n
