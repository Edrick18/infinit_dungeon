extends Node
## Dev-Werkzeug (Befund Item-Icons, nur prüfen): rendert ALLE Item-Icons in den
## echten Anzeigegrößen auf dem echten Hintergrund (Inventar-Kachel mit
## Raritäts-Rahmen und Glanz, Holz-Tafel) und speichert Sammelbilder.
##   godot --path . res://scripts/dev/icon_befund.tscn -- --ordner=<pfad>
##     [--modus=blatt|inventar] [--name=<datei.png>] (Übersicht unter anderem Namen)
##     [--nur-uebersicht] (nur das Übersichtsblatt, z. B. Vorher/Nachher)
##   blatt:    <ordner>/befund_icons_uebersicht.png (Anzeigegröße, wie im Spiel:
##             Filter des Projekts = NEAREST), befund_icons_gross.png (128er-Rohbild),
##             befund_icons_filter.png (gleiche Kacheln: Nearest / Linear / Mipmaps)
##   inventar: echtes Inventar mit je einem Item pro Basis (nur im Speicher, Slot 99)
##             -> <ordner>/befund_icons_inventar.png

const TEST_SLOT := 99
const RARITAETEN := [Enums.Rarity.COMMON, Enums.Rarity.MAGIC, Enums.Rarity.RARE,
	Enums.Rarity.EPIC, Enums.Rarity.LEGENDARY]

var _studio: PortraitStudio
var _ordner := ""
var _mip_cache: Dictionary = {}


func _wert(name: String, standard := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return standard


func _ready() -> void:
	SaveManager.active_slot = TEST_SLOT
	_ordner = _wert("ordner", "user://")
	_studio = PortraitStudio.new()
	add_child(_studio)
	if _wert("modus", "blatt") == "inventar":
		await _inventar()
	else:
		await _blaetter()
	get_tree().quit()


func _warten_bis_fertig() -> void:
	for i in 600:
		await get_tree().process_frame
		if _studio.ausstehend() == 0 and i > 10:
			break
	for i in 6:
		await get_tree().process_frame


# --- Icons ------------------------------------------------------------------

func _alle_basen() -> Array[ItemBase]:
	return ItemLibrary.bases_for_tier(999)


func _tex_item(base: ItemBase) -> Texture2D:
	return GegenstandIcons.textur(_studio, base)


## Kopie mit Mipmaps (nur Vergleich: was ein Mipmap-Filter zeigen würde).
func _mip(tex: Texture2D) -> Texture2D:
	if _mip_cache.has(tex):
		return _mip_cache[tex]
	var img := tex.get_image()
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_mip_cache[tex] = t
	return t


## Kachel wie InventoryScene._kachel (gleicher Stil, Glanz, Level-Chip).
func _kachel(tex: Texture2D, rarity: int, groesse: int, filter: int = UiHolz.ICON_FILTER, level := 12) -> PanelContainer:
	var kachel := PanelContainer.new()
	kachel.custom_minimum_size = Vector2(groesse, groesse)
	var stil := StyleBoxFlat.new()
	stil.set_corner_radius_all(8)
	stil.set_border_width_all(2)
	stil.set_content_margin_all(3)
	var farbe: Color = LootGenerator.RARITY_COLORS[rarity]
	stil.bg_color = Color(UiTheme.HOLZ_TIEF.lerp(farbe, 0.1), 0.95)
	stil.border_color = farbe
	kachel.add_theme_stylebox_override("panel", stil)
	var lage := Control.new()
	kachel.add_child(lage)
	var schein := TextureRect.new()
	schein.texture = UiHolz.glanz(farbe)
	schein.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	schein.stretch_mode = TextureRect.STRETCH_SCALE
	schein.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lage.add_child(schein)
	var bild := TextureRect.new()
	bild.texture = tex
	bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bild.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if filter >= 0:
		bild.texture_filter = filter
	lage.add_child(bild)
	if level > 0:
		var stufe := UiHolz.level_chip(level)
		stufe.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		stufe.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		stufe.grow_vertical = Control.GROW_DIRECTION_BEGIN
		stufe.offset_right = 1
		stufe.offset_bottom = 1
		lage.add_child(stufe)
	return kachel


func _label(text: String, groesse := 12, farbe := UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	return l


func _zeile(abstand := 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", abstand)
	return h


func _spalte(abstand := 2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", abstand)
	return v


func _gitter(spalten: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = spalten
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 8)
	return g


## Leinwand: SubViewport mit Projekt-Filter (NEAREST wie das Hauptfenster;
## Icon-Bilder setzen ihren Filter selbst wie im Spiel).
func _leinwand(breite: int, hoehe: int) -> Array:
	var vp := SubViewport.new()
	vp.size = Vector2i(breite, hoehe)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)
	var hg := ColorRect.new()
	hg.color = UiTheme.HOLZ_TIEF.darkened(0.25)
	hg.size = Vector2(breite, hoehe)
	vp.add_child(hg)
	var rand := MarginContainer.new()
	rand.theme = UiTheme.get_theme()
	for s in ["left", "right", "top", "bottom"]:
		rand.add_theme_constant_override("margin_" + s, 14)
	rand.size = Vector2(breite, hoehe)
	vp.add_child(rand)
	var inhalt := _spalte(10)
	rand.add_child(inhalt)
	return [vp, inhalt]


func _speichern(vp: SubViewport, name: String) -> void:
	var img := vp.get_texture().get_image()
	var pfad := _ordner.path_join(name)
	img.save_png(pfad)
	print("BEFUND gespeichert: ", pfad, " ", img.get_size())


func _tafel(kind: Control) -> PanelContainer:
	return Bildschirm.tafel(kind, 10)


func _blaetter() -> void:
	var basen := _alle_basen()
	var traenke := ConsumableLibrary.all_defs()
	var materialien: Array[StringName] = []
	for art in [&"kraut", &"erz", &"leder", &"kristall", &"rune"]:
		materialien.append_array(MaterialLibrary.ids_der_art(art))
	# Alle Icons anstoßen, dann warten.
	for b in basen:
		_tex_item(b)
	for d in traenke:
		VorratIcons.trank(_studio, d.id)
	for m in materialien:
		VorratIcons.material(_studio, m)
	for biome in 4:
		VorratIcons.biom(_studio, biome)
	for id in VorratIcons.SYMBOLE:
		VorratIcons.symbol(_studio, id)
	await _warten_bis_fertig()

	# 1) Übersicht in Anzeigegröße (Projektfilter NEAREST).
	var l1 := _leinwand(1560, 1860)
	var inhalt: VBoxContainer = l1[1]
	inhalt.add_child(_label("AUSRÜSTUNG — Inventar-Kachel 64 px je Rarität (Gewöhnlich, Magisch, Selten, Episch, Legendär) + Ausrüstungs-Slot 72 px + Zieh-Vorschau 56 px", 14, UiTheme.GOLD))
	var g := _gitter(3)
	for b in basen:
		var zelle := _spalte()
		zelle.add_child(_label("%s  [%s]" % [b.display_name, b.id], 12))
		var z := _zeile()
		for r in RARITAETEN:
			z.add_child(_kachel(_tex_item(b), r, 64))
		z.add_child(_kachel(_tex_item(b), Enums.Rarity.RARE, 72, -1, 0))
		var vorschau := TextureRect.new()
		vorschau.texture = _tex_item(b)
		vorschau.custom_minimum_size = Vector2(56, 56)
		vorschau.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vorschau.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vorschau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vorschau.modulate.a = 0.85
		vorschau.texture_filter = UiHolz.ICON_FILTER
		z.add_child(vorschau)
		zelle.add_child(z)
		g.add_child(zelle)
	inhalt.add_child(_tafel(g))
	inhalt.add_child(_label("VERBRAUCHSGÜTER — Inventar 40 px, Händler 36 px, Kampf-Knopf 26 px", 14, UiTheme.GOLD))
	var gt := _gitter(4)
	for d in traenke:
		var z := _zeile(8)
		var tex := VorratIcons.trank(_studio, d.id)
		z.add_child(UiHolz.icon(tex, 40))
		z.add_child(UiHolz.icon(tex, 36))
		z.add_child(UiHolz.icon(tex, 26))
		z.add_child(_label("%s [%s]" % [d.display_name, d.id], 12))
		gt.add_child(z)
	inhalt.add_child(_tafel(gt))
	inhalt.add_child(_label("MATERIALIEN — Inventar 32 px, Händler 36 px", 14, UiTheme.GOLD))
	var gm := _gitter(4)
	for m in materialien:
		var z := _zeile(8)
		var tex := VorratIcons.material(_studio, m)
		z.add_child(UiHolz.icon(tex, 32))
		z.add_child(UiHolz.icon(tex, 36))
		z.add_child(_label("%s [%s]" % [MaterialLibrary.display_name(m), m], 12))
		gm.add_child(z)
	inhalt.add_child(_tafel(gm))
	inhalt.add_child(_label("BIOME (Kartenlager) — 60 px  ·  SYMBOLE (Gold, Mini-Medaille, Schatzkarte) — 60 / 28 px", 14, UiTheme.GOLD))
	var gb := _zeile(18)
	for biome in 4:
		gb.add_child(UiHolz.icon(VorratIcons.biom(_studio, biome), 60))
	for id in VorratIcons.SYMBOLE:
		gb.add_child(UiHolz.icon(VorratIcons.symbol(_studio, id), 60))
		gb.add_child(UiHolz.icon(VorratIcons.symbol(_studio, id), 28))
	inhalt.add_child(_tafel(gb))
	await _warten_bis_fertig()
	_speichern(l1[0], _wert("name", "befund_icons_uebersicht.png"))
	if "--nur-uebersicht" in OS.get_cmdline_user_args():
		return

	# 2) Rohbilder 128 px (Detail), dunkles Holz.
	var l2 := _leinwand(1440, 1500)
	var inhalt2: VBoxContainer = l2[1]
	inhalt2.add_child(_label("ROHBILDER 128 px (PortraitStudio), 1:1", 14, UiTheme.GOLD))
	var g2 := _gitter(10)
	g2.add_theme_constant_override("h_separation", 8)
	var alle: Array = []
	for b in basen:
		alle.append([_tex_item(b), String(b.id)])
	for d in traenke:
		alle.append([VorratIcons.trank(_studio, d.id), String(d.id)])
	for m in materialien:
		alle.append([VorratIcons.material(_studio, m), String(m)])
	for biome in 4:
		alle.append([VorratIcons.biom(_studio, biome), "biom %d" % biome])
	var roh := _ordner.path_join("roh")
	DirAccess.make_dir_recursive_absolute(roh)
	for e in alle:
		(e[0] as Texture2D).get_image().save_png(roh.path_join(String(e[1]).replace(" ", "_") + ".png"))
	for e in alle:
		var zelle := _spalte()
		var hg := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = UiTheme.HOLZ_TIEF
		hg.add_theme_stylebox_override("panel", st)
		hg.add_child(UiHolz.icon(e[0], 128))
		zelle.add_child(hg)
		zelle.add_child(_label(e[1], 11))
		g2.add_child(zelle)
	inhalt2.add_child(g2)
	await _warten_bis_fertig()
	_speichern(l2[0], "befund_icons_gross.png")

	# 3) Filtervergleich: dieselbe 64er-Kachel mit Nearest (Spiel), Linear, Mipmaps;
	#    dazu 32er/26er Vorrat. Je Gruppe ähnlicher Items.
	var l3 := _leinwand(1440, 1060)
	var inhalt3: VBoxContainer = l3[1]
	inhalt3.add_child(_label("FILTER: je Item drei Kacheln 64 px — Nearest (so im Spiel, Projekt default_texture_filter=0) | Linear | Linear+Mipmaps", 14, UiTheme.GOLD))
	var g3 := _gitter(4)
	for b in basen:
		var zelle := _spalte()
		zelle.add_child(_label(String(b.id), 11))
		var z := _zeile()
		var tex := _tex_item(b)
		z.add_child(_kachel(tex, Enums.Rarity.MAGIC, 64, CanvasItem.TEXTURE_FILTER_NEAREST))
		z.add_child(_kachel(tex, Enums.Rarity.MAGIC, 64, CanvasItem.TEXTURE_FILTER_LINEAR))
		z.add_child(_kachel(_mip(tex), Enums.Rarity.MAGIC, 64, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS))
		zelle.add_child(z)
		g3.add_child(zelle)
	inhalt3.add_child(_tafel(g3))
	var gv := _zeile(6)
	for d in traenke:
		var tex := VorratIcons.trank(_studio, d.id)
		var s := _spalte()
		var i1 := UiHolz.icon(tex, 26)
		i1.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var i2 := UiHolz.icon(_mip(tex), 26)
		i2.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.add_child(i1)
		s.add_child(i2)
		gv.add_child(s)
	for m in materialien:
		var tex := VorratIcons.material(_studio, m)
		var s := _spalte()
		var i1 := UiHolz.icon(tex, 32)
		i1.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var i2 := UiHolz.icon(_mip(tex), 32)
		i2.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		s.add_child(i1)
		s.add_child(i2)
		gv.add_child(s)
	inhalt3.add_child(_label("Tränke 26 px (Kampf-Knopf) und Materialien 32 px (Inventar): oben Nearest (Spiel), unten Mipmaps", 12))
	inhalt3.add_child(_tafel(gv))
	await _warten_bis_fertig()
	_speichern(l3[0], "befund_icons_filter.png")


# --- Echtes Inventar ----------------------------------------------------------

func _inventar() -> void:
	var fenster := _wert("fenster")
	if fenster != "":
		var t := fenster.split("x")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(int(t[0]), int(t[1])))
	if GameState.party.is_empty():
		GameState.recruit("Edda", &"krieger")
	GameState.inventory.clear()
	var i := 0
	for b in _alle_basen():
		var item := ItemLibrary.make_item(b.id, 10 + i)
		item.rarity = RARITAETEN[i % RARITAETEN.size()]
		GameState.inventory.append(item)
		i += 1
	var szene: Node = load("res://scenes/inventory/inventory_scene.tscn").instantiate()
	add_child(szene)
	await _warten_bis_fertig()
	for k in 30:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var pfad := _ordner.path_join("befund_icons_inventar%s.png" % ("" if fenster == "" else "_" + fenster))
	img.save_png(pfad)
	print("BEFUND gespeichert: ", pfad, " ", img.get_size())
