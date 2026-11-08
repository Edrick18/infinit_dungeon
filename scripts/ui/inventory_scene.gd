extends Control
## Ausrüstung & Inventar (Lutz 2026-10-14): Reiter Ausrüstung | Werte |
## Tränke & Feldzauber | Materialien. Oben die Heldenleiste, darunter
## eingerückt die Reiter: Ausrüstung und Werte in der Tafel des gewählten
## Helden, Tränke und Materialien in der Tafel „Gruppe“ (gemeinsamer Vorrat,
## wie Taschen und Gold).
## Ausrüstung: links die Figur mit den Ausrüstungs-Slots, rechts die Taschen
## als Raster aus Icons (wächst mit der Anzahl). Ein Klick auf einen Slot
## zeigt nur, was dort hineinpasst. Fährt die Maus über einen Gegenstand,
## erscheint seine Karte — Strg schaltet den Vergleich mit dem Ausgerüsteten
## an/aus (besser grün, schlechter rot). Ausrüsten per Drag & Drop (Taschen »
## Slot, Slot » Taschen) oder Doppelklick.
## Tastatur (WASD + E): Kacheln sind fokussierbar — E wählt aus, E auf dem
## Ausgewählten legt an bzw. ab; die Karte steht dann neben der Kachel.
## Die Taschen sind begrenzt (GameState.TASCHEN_LIMIT); das Raster zeigt
## Seiten und baut beim Auswählen nichts neu (Spieltest: 0,2 s je Klick).

const MAIN_SCENE := "res://scenes/main.tscn"
const KACHEL := 64
const ALLE := -1

## Slot-Anordnung um die Figur: [Slot, Spalte, Zeile].
const PUPPE := [
	[Enums.EquipSlot.AMULET, 0, 0], [Enums.EquipSlot.HELMET, 1, 0], [Enums.EquipSlot.RING_1, 2, 0],
	[Enums.EquipSlot.WEAPON, 0, 1], [Enums.EquipSlot.ARMOR, 1, 1], [Enums.EquipSlot.OFF_HAND, 2, 1],
	[Enums.EquipSlot.GLOVES, 0, 2], [Enums.EquipSlot.BOOTS, 1, 2], [Enums.EquipSlot.RING_2, 2, 2],
]

var _selected: Combatant = null
## Held, für den „Umskillen“ schon einmal angeklickt wurde (zweiter Klick bestätigt).
var _respec_id := 0
## Statuspunkte-Verteilung der aktuellen Seite und Held, für den schon vor dem Verwerfen gewarnt wurde.
var _alloc: StatAllocator = null
## Ziel des Wechsels, vor dem der Planungs-Hinweis gewarnt hat (Held,
## Reiter-ID oder &"zurueck"); erst derselbe Wechsel noch einmal führt aus.
var _wechsel_warnung: Variant = null
var _gold_label: Label
var _vergleich_label: Label
var _char_bar: HFlowContainer
## Name des gewählten Helden vor seinen Reitern (Ausrüstung, Werte).
var _held_titel: Label
var _studio: PortraitStudio
var _vorschau: FigurenVorschau

var _tab := &"ausruestung"
var _tab_buttons: Dictionary = {}
var _seiten: Dictionary = {}

# Ausrüstung
var _set_zeile: HBoxContainer
var _puppe: GridContainer
var _filter_leiste: HFlowContainer
var _raster: HFlowContainer
var _aktion_zeile: HBoxContainer
var _slot_filter := ALLE
var _auswahl: ItemInstance = null
var _auswahl_ausgeruestet := false
## Drag & Drop: Slot-Kacheln (zum Einfärben beim Ziehen) und der gezogene Gegenstand.
var _slot_kacheln: Dictionary = {}
var _gezogen: ItemInstance = null
## Taschen-Raster: Kacheln je Gegenstand (nur die aktuelle Seite) werden
## wiederverwendet; Auswahl färbt nur um.
const SEITE_GROESSE := 60
## Markierung „keine“ (Grundstil der Kachel).
const KEIN_RAHMEN := Color(0, 0, 0, 0)
const FILTER := [ALLE, Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND, Enums.EquipSlot.HELMET,
	Enums.EquipSlot.ARMOR, Enums.EquipSlot.GLOVES, Enums.EquipSlot.BOOTS,
	Enums.EquipSlot.RING_1, Enums.EquipSlot.AMULET]
var _bag_kacheln: Dictionary = {}  ## ItemInstance » Kachel
var _filter_knoepfe: Dictionary = {}  ## Filter » Button
var _raster_scroll: ScrollContainer
var _leer_label: Label
var _seiten_zeile: HBoxContainer
var _seite := 0
var _seite_zurueck: Button
var _seite_weiter: Button
var _seite_label: Label
var _taschen_label: Label
## Zweiter Klick: Verkaufen ab Episch (es gibt keinen Rückkauf) und
## „Gewöhnliche verkaufen“ immer.
var _verkauf_fragt: ItemInstance = null
var _commons_fragt := false
## Sachliche Rückmeldung in der Aktionszeile (z. B. nach dem Verkaufen).
var _meldung := ""

# Werte / Tränke / Materialien
var _stats_label: Label
var _stats_box: VBoxContainer
var _inventory_list: VBoxContainer
var _material_list: VBoxContainer

# Hover-Karte
var _popup_ebene: CanvasLayer
var _popup: Control = null
var _hover_item: ItemInstance = null
var _vergleich := true
## Karte neben dieser (per Tastatur fokussierten) Kachel statt an der Maus.
var _popup_anker: Control = null
## Letzte Eingabe kam von der Tastatur (dann zeigt der Fokus die Karte).
var _tastatur := false


func _ready() -> void:
	theme = UiTheme.get_theme()
	Music.play(&"menu")
	_selected = GameState.party[0]
	_build_layout()
	_refresh()
	UiTheme.focus_first_button(self)


## Name des Zurück-Ziels: Dungeon, Händler/Schmiede (Taschen-voll-Fenster
## dort) oder Menü.
static func ziel_name(szene: String) -> String:
	if szene.is_empty():
		return Loc.pick("Menü", "Menu")
	if szene.ends_with("shop_scene.tscn"):
		return Loc.pick("Händler", "Merchant")
	if szene.ends_with("smith.tscn"):
		return Loc.pick("Schmiede", "Smithy")
	return Loc.pick("Dungeon", "Dungeon")


## Geplante, unbestätigte Statuspunkte gehen bei jedem Wechsel (Held, Reiter,
## Zurück) verloren: der erste Versuch zeigt den Hinweis, erst derselbe Wechsel
## noch einmal führt aus. Ändert sich die Planung dazwischen, fragt er neu.
func _wechsel_erlaubt(ziel: Variant) -> bool:
	if _alloc == null or not is_instance_valid(_alloc) or _alloc.geplant() <= 0:
		_wechsel_warnung = null
		return true
	if _alloc.warnung_aktiv() and typeof(_wechsel_warnung) == typeof(ziel) \
			and _wechsel_warnung == ziel:
		_wechsel_warnung = null
		return true
	_wechsel_warnung = ziel
	_alloc.warnung_zeigen()
	return false


## Zurück dorthin, wo das Inventar geöffnet wurde (Dungeon, Stadt oder Menü).
func _go_back() -> void:
	if not _wechsel_erlaubt(&"zurueck"):
		return
	var target := GameState.ui_return_scene
	GameState.ui_return_scene = ""
	if target.is_empty():
		target = MAIN_SCENE
	get_tree().change_scene_to_file(target)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_tastatur = true
	elif event is InputEventMouseButton and event.pressed:
		_tastatur = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Esc übernimmt die Bildschirm-Vorlage; die Inventar-Taste schließt auch.
	if event.is_action_pressed(&"open_inventory"):
		get_viewport().set_input_as_handled()
		_go_back()
	elif event.keycode == KEY_CTRL:
		_vergleich = not _vergleich
		_vergleich_aktualisieren()
		_popup_zeigen(_hover_item, false, _popup_anker)


func _process(_delta: float) -> void:
	if _popup == null or not is_instance_valid(_popup):
		return
	_popup.reset_size()  # ohne Container wächst die Karte sonst nie zurück
	var groesse := _popup.size
	var bild := get_viewport_rect().size
	# Tastatur: Karte neben der fokussierten Kachel, nie aus dem Bild.
	if _popup_anker != null and is_instance_valid(_popup_anker) and _popup_anker.is_visible_in_tree():
		var rahmen := _popup_anker.get_global_rect()
		var stelle := Vector2(rahmen.end.x + 10, rahmen.position.y)
		if stelle.x + groesse.x > bild.x - 8:
			stelle.x = rahmen.position.x - groesse.x - 10
		stelle.y = clampf(stelle.y, 8, maxf(8, bild.y - groesse.y - 8))
		_popup.position = stelle
		return
	# Karte neben der Maus, nie aus dem Bild.
	var maus := get_viewport().get_mouse_position()
	var pos := maus + Vector2(18, 18)
	if pos.x + groesse.x > bild.x - 8:
		pos.x = maus.x - groesse.x - 18
	if pos.y + groesse.y > bild.y - 8:
		pos.y = bild.y - groesse.y - 8
	_popup.position = pos


# --- Aktionen -------------------------------------------------------------------

func _on_equip(item: ItemInstance) -> void:
	GameState.inventory.erase(item)
	# Kann mehrere Items verdrängen (z.B. Zweihänder ersetzt Waffe + Schild).
	for replaced in _selected.equip(item):
		GameState.inventory.append(replaced)
	_auswahl = item
	_auswahl_ausgeruestet = true
	Sfx.play(&"ausruesten")
	_refresh()


func _on_unequip(slot: Enums.EquipSlot) -> void:
	var item := _selected.unequip(slot)
	if item != null:
		GameState.inventory.append(item)
		_auswahl = item
		_auswahl_ausgeruestet = false
	_refresh()


func _on_sell(item: ItemInstance) -> void:
	var stelle := _raster_stelle(item)
	var preis := LootGenerator.sell_price(item)
	GameState.inventory.erase(item)
	GameState.gold += preis
	if _auswahl == item:
		_auswahl = null
	_verkauf_fragt = null
	_meldung = Loc.pick("Verkauft: %s, +%d Gold", "Sold: %s, +%d gold") % [item.get_display_name(), preis]
	Sfx.play(&"gold")
	_taschen_geaendert()
	_fokus_ins_raster(stelle)


## QoL: der Stapel grauer Items geht mit einem Klick zu Gold (zweiter Klick bestätigt).
func _on_sell_commons() -> void:
	var ergebnis := GameState.gewoehnliche_verkaufen()
	_commons_fragt = false
	if _auswahl != null and not _auswahl_ausgeruestet and not GameState.inventory.has(_auswahl):
		_auswahl = null
	_meldung = Loc.pick("Gewöhnliche verkauft: %d Teile, +%d Gold", "Commons sold: %d items, +%d gold") \
		% [int(ergebnis["anzahl"]), int(ergebnis["gold"])]
	Sfx.play(&"gold")
	_taschen_geaendert()
	_fokus_ins_raster(0)


## Nach einem Verkauf: wartende Beute nachrücken, Zähler, Raster und
## Aktionen auffrischen — Figur und Slots bleiben, wie sie sind.
func _taschen_geaendert() -> void:
	var aufgenommen := GameState.warteliste_nachruecken()
	if aufgenommen > 0:
		_meldung += Loc.pick(" · aus der Warteliste aufgenommen: %d", " · taken in from the waiting list: %d") % aufgenommen
	_gold_label.text = "Gold: %d" % GameState.gold
	_taschen_anzeigen()
	_filter_aktualisieren()
	_raster_aufbauen()
	_markierungen()
	_refresh_aktionen()


## Auswahl ändern, ohne etwas neu zu bauen: Markierung + Aktionszeile.
func _auswahl_setzen(item: ItemInstance, ausgeruestet: bool) -> void:
	_auswahl = item
	_auswahl_ausgeruestet = ausgeruestet and item != null
	_verkauf_fragt = null
	_commons_fragt = false
	_meldung = ""
	_markierungen()
	_refresh_aktionen()


## Slot angeklickt: zeigt im Raster, was hineinpasst, und wählt sein Item.
func _slot_waehlen(slot: Enums.EquipSlot, item: ItemInstance) -> void:
	var filter := _filter_fuer(slot)
	if filter != _slot_filter:
		_slot_filter = filter
		_seite = 0
		_filter_aktualisieren()
		_raster_aufbauen()
	_auswahl_setzen(item, item != null)


func _filter_waehlen(filter: int) -> void:
	_slot_filter = filter
	_seite = 0
	_filter_aktualisieren()
	_raster_aufbauen()
	_markierungen()


# --- UI-Aufbau ------------------------------------------------------------------

func _build_layout() -> void:
	var b := Bildschirm.bauen(self, Loc.pick("Ausrüstung & Inventar", "Equipment & inventory"), &"lager",
		_go_back, ziel_name(GameState.ui_return_scene))
	b.zurueck.tooltip_text = Loc.pick("Zurück (Esc / %s)", "Back (Esc / %s)") % Settings.key_name(&"open_inventory")
	_vergleich_label = b.info("", UiTheme.INFO)
	_taschen_label = b.info("", UiTheme.TEXT)
	_gold_label = b.info("")
	_studio = PortraitStudio.new()
	add_child(_studio)
	_popup_ebene = CanvasLayer.new()
	_popup_ebene.layer = 80
	add_child(_popup_ebene)

	# Oben die Heldenleiste über die volle Breite (bricht bei 4 langen Namen
	# notfalls um, statt die Szene über den Bildrand zu schieben).
	_char_bar = HFlowContainer.new()
	_char_bar.add_theme_constant_override("h_separation", 8)
	_char_bar.add_theme_constant_override("v_separation", 6)
	b.inhalt.add_child(_char_bar)
	# Darunter, eingerückt, die Reiter (Spieltest: neben Name und Level wirkte
	# alles wie EIN gemeinsames Inventar). Links eine Tafel des gewählten
	# Helden mit seinem Namen — Ausrüstung und Werte gehören ihm. Rechts eine
	# eigene Tafel „Gruppe“: Taschen, Gold, Tränke und Materialien teilen sich
	# alle Helden (GameState.inventory/consumables/materials).
	var reiter_zeile := HBoxContainer.new()
	reiter_zeile.add_theme_constant_override("separation", 16)
	var einzug := MarginContainer.new()
	einzug.add_theme_constant_override("margin_left", 24)
	einzug.add_child(reiter_zeile)
	b.inhalt.add_child(einzug)
	var held_reiter := HBoxContainer.new()
	held_reiter.add_theme_constant_override("separation", 6)
	# Goldener Rahmen wie der gewählte Helden-Knopf darüber.
	var held_tafel := _reiter_tafel(held_reiter, "tafel_aktiv")
	held_tafel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reiter_zeile.add_child(held_tafel)
	_held_titel = Label.new()
	_held_titel.add_theme_color_override("font_color", UiTheme.GOLD)
	held_reiter.add_child(_held_titel)
	var gruppe_reiter := HBoxContainer.new()
	gruppe_reiter.add_theme_constant_override("separation", 6)
	reiter_zeile.add_child(_reiter_tafel(gruppe_reiter, "tafel"))
	var gruppe_titel := Label.new()
	gruppe_titel.text = Loc.pick("Gruppe (gemeinsam):", "Party (shared):")
	gruppe_titel.add_theme_color_override("font_color", UiTheme.GOLD)
	gruppe_reiter.add_child(gruppe_titel)
	for eintrag in [[&"ausruestung", Loc.pick("Ausrüstung", "Equipment"), held_reiter],
			[&"werte", Loc.pick("Werte & Statuspunkte", "Stats & points"), held_reiter],
			[&"traenke", Loc.pick("Tränke & Feldzauber", "Potions & field spells"), gruppe_reiter],
			[&"material", Loc.pick("Materialien", "Materials"), gruppe_reiter]]:
		var knopf := Button.new()
		knopf.text = eintrag[1]
		# Breit: W/S von der Heldenleiste und vom Inhalt landen auf dem Reiter
		# darunter/darüber, statt über die Zeile hinwegzuspringen.
		knopf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: StringName = eintrag[0]
		knopf.pressed.connect(func() -> void:
			if id == _tab or not _wechsel_erlaubt(id):
				return
			_tab = id
			_popup_zeigen(null)
			_refresh())
		(eintrag[2] as Control).add_child(knopf)
		_tab_buttons[id] = knopf

	var seiten := Control.new()
	seiten.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.inhalt.add_child(seiten)
	_seiten[&"ausruestung"] = _baue_ausruestung_seite()
	_seiten[&"werte"] = _baue_werte_seite()
	_seiten[&"traenke"] = _baue_listen_seite(Loc.pick("Tränke & Feldzauber", "Potions & field spells"))
	_inventory_list = _seiten[&"traenke"].get_meta(&"liste")
	_seiten[&"material"] = _baue_listen_seite(Loc.pick("Materialien", "Materials"))
	_material_list = _seiten[&"material"].get_meta(&"liste")
	for id in _seiten:
		var seite: Control = _seiten[id]
		seite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		seiten.add_child(seite)


## Flache Tafel um eine Reiter-Zeile: oben/unten knapp (die Ausrüstungs-
## Seite braucht bei 720 px jede Zeile), seitlich Luft zum Rahmen.
func _reiter_tafel(kind: Control, art: String) -> PanelContainer:
	var tafel := Bildschirm.tafel(kind)
	var stil := UiHolz.box_mit_rand(art, 6)
	stil.content_margin_left = 12
	stil.content_margin_right = 12
	tafel.add_theme_stylebox_override("panel", stil)
	return tafel


func _baue_ausruestung_seite() -> Control:
	var zeile := HBoxContainer.new()
	zeile.add_theme_constant_override("separation", 16)

	# Links: Figur, Waffenset, Slots.
	var links := VBoxContainer.new()
	links.add_theme_constant_override("separation", 8)
	var links_tafel := Bildschirm.tafel(links)
	zeile.add_child(links_tafel)
	var figur_zeile := HBoxContainer.new()
	figur_zeile.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_child(figur_zeile)
	_vorschau = FigurenVorschau.new(Vector2i(150, 170))
	figur_zeile.add_child(_vorschau)
	_set_zeile = HBoxContainer.new()
	_set_zeile.add_theme_constant_override("separation", 8)
	links.add_child(_set_zeile)
	_puppe = GridContainer.new()
	_puppe.columns = 3
	_puppe.add_theme_constant_override("h_separation", 8)
	_puppe.add_theme_constant_override("v_separation", 8)
	var puppe_zeile := HBoxContainer.new()
	puppe_zeile.alignment = BoxContainer.ALIGNMENT_CENTER
	puppe_zeile.add_child(_puppe)
	links.add_child(puppe_zeile)

	# Rechts: Filter, Raster, Aktionen.
	var rechts := VBoxContainer.new()
	rechts.add_theme_constant_override("separation", 8)
	var rechts_tafel := Bildschirm.tafel(rechts)
	rechts_tafel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zeile.add_child(rechts_tafel)
	_filter_leiste = HFlowContainer.new()
	_filter_leiste.add_theme_constant_override("h_separation", 6)
	_filter_leiste.add_theme_constant_override("v_separation", 6)
	rechts.add_child(_filter_leiste)
	# Die Taschen gehören der ganzen Gruppe, nicht dem gewählten Helden.
	var taschen_titel := Label.new()
	taschen_titel.text = Loc.pick("Taschen der Gruppe:", "Party bags:")
	taschen_titel.add_theme_color_override("font_color", UiTheme.GOLD)
	taschen_titel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_filter_leiste.add_child(taschen_titel)
	# Filter: Alle + je Slot-Art (mit Anzahl) — einmal gebaut, nur aufgefrischt.
	for filter in FILTER:
		var knopf := Button.new()
		var f: int = filter
		knopf.pressed.connect(func() -> void: _filter_waehlen(f))
		_filter_leiste.add_child(knopf)
		_filter_knoepfe[filter] = knopf
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true  # Tastatur: die fokussierte Kachel bleibt im Bild
	# Leere Taschenfläche nimmt ausgerüstete Gegenstände an (= ablegen).
	scroll.set_drag_forwarding(Callable(), _passt_in_taschen, _in_taschen_ablegen)
	rechts.add_child(scroll)
	_raster_scroll = scroll
	_raster = HFlowContainer.new()
	_raster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_raster.add_theme_constant_override("h_separation", 6)
	_raster.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_raster)
	_leer_label = Label.new()
	_leer_label.text = Loc.pick("Nichts Passendes in den Taschen — Beute gibt es in den Dungeons, in der Schmiede und beim Händler.",
		"Nothing fitting in your bags — loot awaits in the dungeons, at the smithy and the merchant.")
	_leer_label.modulate = UiTheme.BLASS
	_leer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_leer_label.custom_minimum_size = Vector2(300, 0)
	_raster.add_child(_leer_label)
	# Seiten (SEITE_GROESSE Kacheln je Seite), nur sichtbar, wenn es mehrere gibt.
	_seiten_zeile = HBoxContainer.new()
	_seiten_zeile.alignment = BoxContainer.ALIGNMENT_CENTER
	_seiten_zeile.add_theme_constant_override("separation", 8)
	rechts.add_child(_seiten_zeile)
	_seite_zurueck = Button.new()
	_seite_zurueck.text = Loc.pick("« Seite zurück", "« Previous page")
	_seite_zurueck.pressed.connect(func() -> void: _seite_blaettern(-1))
	_seiten_zeile.add_child(_seite_zurueck)
	_seite_label = Label.new()
	_seiten_zeile.add_child(_seite_label)
	_seite_weiter = Button.new()
	_seite_weiter.text = Loc.pick("Seite vor »", "Next page »")
	_seite_weiter.pressed.connect(func() -> void: _seite_blaettern(1))
	_seiten_zeile.add_child(_seite_weiter)
	_aktion_zeile = HBoxContainer.new()
	_aktion_zeile.add_theme_constant_override("separation", 8)
	rechts.add_child(_aktion_zeile)
	return zeile


func _baue_werte_seite() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 14)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_stats_label)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 2)
	box.add_child(_stats_box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true  # Tastatur: Punkte-Knöpfe unten scrollen ins Bild
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return Bildschirm.tafel(scroll)


func _baue_listen_seite(_titel: String) -> Control:
	var teile := Bildschirm.scroll_liste(4)
	var tafel := Bildschirm.tafel(teile[0])
	tafel.set_meta(&"liste", teile[1])
	return tafel


# --- Aktualisieren --------------------------------------------------------------

func _refresh() -> void:
	# Beim Öffnen und wenn Platz frei wurde (z. B. in einen leeren Slot
	# angelegt): wartende Beute rückt nach.
	var aufgenommen := GameState.warteliste_nachruecken()
	if aufgenommen > 0:
		_meldung = Loc.pick("Aus der Warteliste aufgenommen: %d", "Taken in from the waiting list: %d") % aufgenommen
	_gold_label.text = "Gold: %d" % GameState.gold
	_taschen_anzeigen()
	_verkauf_fragt = null
	_commons_fragt = false
	_vergleich_aktualisieren()
	for id in _seiten:
		_seiten[id].visible = id == _tab
		UiTheme.als_aktiv(_tab_buttons[id], id == _tab)

	# Tastatur: lag der Fokus auf einem Helden-Knopf, bleibt er an derselben Stelle.
	var fokus_held := -1
	for child in _char_bar.get_children():
		if (child as Control).has_focus():
			fokus_held = child.get_index()
		child.queue_free()
	# S aus der Heldenleiste immer auf die Reiter darunter (unter dem ersten
	# Helden steht sonst nur der Name, und WASD sprang ins Raster).
	var reiter_ziel: Button = _tab_buttons[&"werte" if _tab == &"ausruestung" else &"ausruestung"]
	for member in GameState.party:
		var button := Button.new()
		button.text = "%s (Lv. %d)" % [member.display_name, member.level]
		button.icon = _studio.textur(FigurenBau.schluessel_fuer(member),
			func() -> Node3D: return FigurenBau.held_aus(member))
		button.add_theme_constant_override("icon_max_width", 30)
		UiTheme.als_aktiv(button, member == _selected)
		button.pressed.connect(func() -> void:
			if member == _selected or not _wechsel_erlaubt(member):
				return
			_respec_id = 0
			_selected = member
			if _auswahl_ausgeruestet:
				_auswahl = null
			_refresh())
		_char_bar.add_child(button)
		button.focus_neighbor_bottom = button.get_path_to(reiter_ziel)
		if GameState.party.find(member) == fokus_held:
			button.grab_focus.call_deferred()
	_held_titel.text = "%s:" % _selected.display_name

	match _tab:
		&"ausruestung":
			_refresh_ausruestung()
		&"werte":
			_stats_label.text = _char_summary(_selected)
			_rebuild_stat_allocation()
		&"traenke":
			_refresh_traenke()
		&"material":
			_refresh_material()


## Kopfzeile: Taschen-Stand und wartende Beute (Taschenlimit).
func _taschen_anzeigen() -> void:
	_taschen_label.text = Loc.pick("Taschen: %d/%d", "Bags: %d/%d") \
		% [GameState.inventory.size(), GameState.TASCHEN_LIMIT]
	if not GameState.beute_warteliste.is_empty():
		_taschen_label.text += Loc.pick("  ·  wartend: %d", "  ·  waiting: %d") % GameState.beute_warteliste.size()


func _vergleich_aktualisieren() -> void:
	_vergleich_label.text = Loc.pick("Vergleich: %s  [Strg]", "Compare: %s  [Ctrl]") \
		% (Loc.pick("an", "on") if _vergleich else Loc.pick("aus", "off"))


func _refresh_ausruestung() -> void:
	# Figur neu aufbauen: Waffenwechsel/Ablegen sieht man sofort am Helden.
	_vorschau.zeige(FigurenBau.held_aus(_selected))
	if _auswahl_ausgeruestet and not _selected.equipment.values().has(_auswahl):
		_auswahl = null
	if not _auswahl_ausgeruestet and _auswahl != null and not GameState.inventory.has(_auswahl):
		_auswahl = null

	# Waffenset-Umschalter: Haupt-/Nebenhand existieren doppelt (Set A/B).
	for child in _set_zeile.get_children():
		child.queue_free()
	var set_label := Label.new()
	set_label.text = Loc.pick("Waffenset %s", "Weapon set %s") % ("A" if _selected.active_weapon_set == 0 else "B")
	set_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_zeile.add_child(set_label)
	var set_swap := Button.new()
	var other_weapon: ItemInstance = _selected.weapon_set_b.get(Enums.EquipSlot.WEAPON)
	set_swap.text = Loc.pick("Wechseln » %s", "Swap » %s") \
		% (other_weapon.basis_name() if other_weapon != null else Loc.pick("(leer)", "(empty)"))
	set_swap.tooltip_text = Loc.pick(
		"Tauscht Haupt- und Nebenhand gegen das andere Set.\nZum Bestücken: wechseln, dann Waffen anlegen.\nIm Kampf ist der Wechsel eine freie Aktion.",
		"Swaps main and off hand with the other set.\nTo fill it: swap, then equip weapons.\nSwapping in battle is a free action.")
	set_swap.pressed.connect(func() -> void:
		_selected.swap_weapon_set()
		GameState.save_game()
		Sfx.play(&"bestaetigen")
		_refresh())
	_set_zeile.add_child(set_swap)

	# Slots um die Figur (neu gebaut — der Tastatur-Fokus bleibt auf dem Slot).
	var fokus_slot := -1
	for slot in _slot_kacheln:
		if is_instance_valid(_slot_kacheln[slot]) and (_slot_kacheln[slot] as Control).has_focus():
			fokus_slot = slot
	for child in _puppe.get_children():
		child.queue_free()
	_slot_kacheln.clear()
	for eintrag in PUPPE:
		var slot: Enums.EquipSlot = eintrag[0]
		var item: ItemInstance = _selected.equipment.get(slot)
		var kachel := _kachel(item, ItemInfo.slot_name(slot), 72)
		# Auswahl erst beim Loslassen — ein Neuaufbau beim Drücken würde das
		# Ziehen abbrechen. Doppelklick legt ab. E: auswählen, nochmal E legt ab.
		kachel.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed and event.double_click and item != null:
					_on_unequip(slot)
				elif not event.pressed:
					_slot_waehlen(slot, item)
			elif event.is_action_pressed(&"ui_accept"):
				kachel.accept_event()
				if item != null and item == _auswahl and _auswahl_ausgeruestet:
					_on_unequip(slot)
				else:
					_slot_waehlen(slot, item))
		kachel.mouse_entered.connect(func() -> void: _popup_zeigen(item, true))
		kachel.mouse_exited.connect(_popup_maus_weg)
		kachel.focus_entered.connect(func() -> void: _kachel_fokus(kachel, item, true))
		kachel.focus_exited.connect(func() -> void: _kachel_fokus_weg(kachel))
		# KI-Brücke: Kachel wie ein Knopf (Auswahl + Info-Karte).
		kachel.set_meta(&"ki_text", "%s: %s" % [ItemInfo.slot_name(slot),
			"%s (Lv %d) — %s" % [item.get_display_name(), item.item_level, ItemInfo.kurz(item)]
			if item != null else Loc.pick("leer", "empty")])
		kachel.set_meta(&"ki_klick", func() -> void:
			_slot_waehlen(slot, item)
			_popup_zeigen(item, true))
		# Drag & Drop: Gegenstand auf den Slot ziehen = anlegen; vom Slot in
		# die Taschen ziehen = ablegen.
		kachel.set_drag_forwarding(
			func(_pos: Vector2) -> Variant: return _ziehen_starten(item, slot),
			func(_pos: Vector2, daten: Variant) -> bool: return _passt_auf_slot(daten, slot),
			func(_pos: Vector2, daten: Variant) -> void: _auf_slot_ablegen(daten, slot))
		_slot_kacheln[slot] = kachel
		_puppe.add_child(kachel)
		if slot == fokus_slot:
			kachel.grab_focus()

	_filter_aktualisieren()
	_raster_aufbauen()
	_markierungen()
	_refresh_aktionen()


## Filterknöpfe: Anzahl je Slot-Art in EINEM Durchlauf (statt 9 × alle Teile).
func _filter_aktualisieren() -> void:
	var anzahl := {ALLE: GameState.inventory.size()}
	for item in GameState.inventory:
		var slot := int(item.base.slot)
		anzahl[slot] = int(anzahl.get(slot, 0)) + 1
		# Leichte Waffen passen auch in die Nebenhand (wie _passt).
		if item.base.light and item.base.slot == Enums.EquipSlot.WEAPON:
			anzahl[Enums.EquipSlot.OFF_HAND] = int(anzahl.get(Enums.EquipSlot.OFF_HAND, 0)) + 1
	for filter in _filter_knoepfe:
		var knopf: Button = _filter_knoepfe[filter]
		knopf.text = "%s (%d)" % [Loc.pick("Alle", "All") if filter == ALLE else ItemInfo.slot_name(filter),
			int(anzahl.get(filter, 0))]
		UiTheme.als_aktiv(knopf, filter == _slot_filter)


## Taschen-Raster: beste Rarität zuerst, dann höheres Level — seitenweise.
## Vorhandene Kacheln bleiben (gleicher Gegenstand = gleiche Kachel), nur
## Neue werden gebaut und Verschwundene entfernt.
func _raster_aufbauen() -> void:
	var liste: Array[ItemInstance] = []
	for item in GameState.inventory:
		if _passt(item, _slot_filter):
			liste.append(item)
	liste.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		if a.rarity != b.rarity:
			return a.rarity > b.rarity
		if a.item_level != b.item_level:
			return a.item_level > b.item_level
		return a.base.slot < b.base.slot)
	var seiten := maxi(1, ceili(liste.size() / float(SEITE_GROESSE)))
	_seite = clampi(_seite, 0, seiten - 1)
	var seite := liste.slice(_seite * SEITE_GROESSE, (_seite + 1) * SEITE_GROESSE)
	var auf_seite := {}
	for item in seite:
		auf_seite[item] = true

	# Verschwundene entfernen. Lag der Fokus auf einer davon, rückt er auf
	# die Kachel, die danach an derselben Stelle steht.
	var fokus := get_viewport().gui_get_focus_owner()
	var fokus_stelle := -1
	if fokus != null and fokus.get_parent() == _raster and fokus is PanelContainer:
		fokus_stelle = fokus.get_index() - 1  # Index 0 ist der Leer-Hinweis
	for item in _bag_kacheln.keys():
		if auf_seite.has(item):
			continue
		var alt: Control = _bag_kacheln[item]
		if alt == _popup_anker:
			_popup_zeigen(null)
		_raster.remove_child(alt)
		alt.queue_free()
		_bag_kacheln.erase(item)
	_leer_label.visible = liste.is_empty()
	for i in seite.size():
		var item: ItemInstance = seite[i]
		var kachel: PanelContainer = _bag_kacheln.get(item)
		if kachel == null:
			kachel = _bag_kachel(item)
			_bag_kacheln[item] = kachel
			_raster.add_child(kachel)
		_raster.move_child(kachel, i + 1)

	_seiten_zeile.visible = seiten > 1
	_seite_label.text = Loc.pick("Seite %d/%d  ·  %d Teile", "Page %d/%d  ·  %d items") \
		% [_seite + 1, seiten, liste.size()]
	_seite_zurueck.disabled = _seite <= 0
	_seite_weiter.disabled = _seite >= seiten - 1
	if fokus_stelle >= 0 and get_viewport().gui_get_focus_owner() == null:
		_fokus_ins_raster(fokus_stelle)


## Kachel eines Taschen-Gegenstands (mit Maus, Tastatur, Drag & Drop, KI).
func _bag_kachel(item: ItemInstance) -> PanelContainer:
	var kachel := _kachel(item, "", KACHEL)
	kachel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if not GameState.inventory.has(item):
				return  # gerade angelegt oder verkauft (Doppelklick-Rest)
			if event.pressed and event.double_click:
				_on_equip(item)
			elif not event.pressed:
				_auswahl_setzen(item, false)
		elif event.is_action_pressed(&"ui_accept") and GameState.inventory.has(item):
			kachel.accept_event()
			# E: erst auswählen, E auf dem Ausgewählten legt an (wie Doppelklick).
			if item == _auswahl and not _auswahl_ausgeruestet:
				_on_equip(item)
			else:
				_auswahl_setzen(item, false))
	kachel.mouse_entered.connect(func() -> void: _popup_zeigen(item))
	kachel.mouse_exited.connect(_popup_maus_weg)
	kachel.focus_entered.connect(func() -> void: _kachel_fokus(kachel, item, false))
	kachel.focus_exited.connect(func() -> void: _kachel_fokus_weg(kachel))
	kachel.set_meta(&"ki_text", Loc.pick("Tasche: %s (%s, Lv %d) — %s", "Bag: %s (%s, lv %d) — %s")
		% [item.get_display_name(), ItemInfo.raritaet_name(item.rarity), item.item_level, ItemInfo.kurz(item)])
	# KI-Brücke: Taschen-Kacheln bilden eine Gruppe (wird bei vielen gekürzt).
	kachel.set_meta(&"ki_gruppe", "tasche")
	kachel.set_meta(&"ki_klick", func() -> void:
		_auswahl_setzen(item, false)
		_popup_zeigen(item))
	kachel.set_drag_forwarding(
		func(_pos: Vector2) -> Variant: return _ziehen_starten(item, -1),
		_passt_in_taschen, _in_taschen_ablegen)
	return kachel


func _seite_blaettern(richtung: int) -> void:
	_seite += richtung
	_raster_aufbauen()
	_markierungen()
	_raster_scroll.scroll_vertical = 0


## Stelle eines Gegenstands auf der aktuellen Seite (-1 = nicht da).
func _raster_stelle(item: ItemInstance) -> int:
	var kachel: Control = _bag_kacheln.get(item)
	return kachel.get_index() - 1 if kachel != null else -1


## Tastatur: Fokus auf die Taschen-Kachel an Stelle `stelle` (sonst die
## letzte); gibt es keine, auf die Aktionszeile. Nur, wenn der Fokus gerade
## nirgends oder auf einem sterbenden Knopf liegt.
func _fokus_ins_raster(stelle: int) -> void:
	if stelle < 0:
		return
	var besitzer := get_viewport().gui_get_focus_owner()
	if besitzer != null and not besitzer.is_queued_for_deletion() and besitzer.is_visible_in_tree():
		return
	var kacheln: Array[Control] = []
	for kind in _raster.get_children():
		if kind is PanelContainer and not kind.is_queued_for_deletion():
			kacheln.append(kind)
	if kacheln.is_empty():
		(func() -> void: UiTheme.focus_first_button(_aktion_zeile)).call_deferred()
		return
	kacheln[clampi(stelle, 0, kacheln.size() - 1)].grab_focus()


## Rahmen: Gold = aktiver Slot-Filter, Weiß = Auswahl. Nur Stile, kein Neubau.
func _markierungen() -> void:
	for slot in _slot_kacheln:
		var kachel: PanelContainer = _slot_kacheln[slot]
		var item: ItemInstance = _selected.equipment.get(slot)
		var farbe := KEIN_RAHMEN
		if _filter_fuer(slot) == _slot_filter:
			farbe = UiTheme.GOLD
		if item != null and item == _auswahl:
			farbe = Color.WHITE
		_markieren(kachel, farbe)
	for item in _bag_kacheln:
		var gewaehlt: bool = item == _auswahl and not _auswahl_ausgeruestet
		_markieren(_bag_kacheln[item], Color.WHITE if gewaehlt else KEIN_RAHMEN)


func _refresh_aktionen() -> void:
	for child in _aktion_zeile.get_children():
		child.queue_free()
	var info := Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.clip_text = true
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_aktion_zeile.add_child(info)
	if _auswahl == null:
		if not _meldung.is_empty():
			info.text = _meldung
			info.add_theme_color_override("font_color", UiTheme.WERKSTOFF)
		else:
			info.text = Loc.pick("Ziehen auf einen Slot rüstet aus, zurück in die Taschen legt ab · Doppelklick oder zweimal E geht auch · Maus oder Fokus zeigt die Werte",
				"Drag onto a slot to equip, back into the bags to unequip · double-click or E twice works too · hover or focus shows the stats")
			info.modulate = UiTheme.BLASS
	else:
		info.text = _auswahl.get_display_name()
		info.add_theme_color_override("font_color", LootGenerator.RARITY_COLORS[_auswahl.rarity])
		if _auswahl_ausgeruestet:
			var ablegen := Button.new()
			ablegen.text = Loc.pick("Ablegen", "Unequip")
			var slot := _slot_von(_auswahl)
			ablegen.pressed.connect(func() -> void: _on_unequip(slot))
			_aktion_zeile.add_child(ablegen)
		else:
			var anlegen := Button.new()
			anlegen.text = Loc.pick("Ausrüsten (%s)", "Equip (%s)") % _selected.display_name
			var item := _auswahl
			anlegen.pressed.connect(func() -> void: _on_equip(item))
			_aktion_zeile.add_child(anlegen)
			var verkaufen := Button.new()
			var preis := LootGenerator.sell_price(item)
			verkaufen.text = Loc.pick("Verkaufen (%d G)", "Sell (%d G)") % preis
			if _verkauf_fragt == item:
				verkaufen.text = Loc.pick("Wirklich verkaufen? (%d G)", "Really sell? (%d G)") % preis
			verkaufen.pressed.connect(func() -> void:
				# Ab Episch erst der zweite Klick (kein Rückkauf). Der erste
				# ändert nur den Text — der Fokus bleibt auf dem Knopf.
				if item.rarity >= Enums.Rarity.EPIC and _verkauf_fragt != item:
					_verkauf_fragt = item
					verkaufen.text = Loc.pick("Wirklich verkaufen? (%d G)", "Really sell? (%d G)") % preis
					return
				_on_sell(item))
			_aktion_zeile.add_child(verkaufen)
	var wert := GameState.gewoehnliche_wert()
	var anzahl := int(wert["anzahl"])
	if anzahl > 0:
		var sell_commons := Button.new()
		var gold := int(wert["gold"])
		sell_commons.text = Loc.pick("Gewöhnliche verkaufen (%d Teile, +%d Gold)",
			"Sell commons (%d items, +%d gold)") % [anzahl, gold]
		if _commons_fragt:
			sell_commons.text = Loc.pick("Wirklich %d verkaufen für %d Gold?", "Really sell %d for %d gold?") % [anzahl, gold]
		sell_commons.pressed.connect(func() -> void:
			if not _commons_fragt:
				_commons_fragt = true
				sell_commons.text = Loc.pick("Wirklich %d verkaufen für %d Gold?", "Really sell %d for %d gold?") % [anzahl, gold]
				return
			_on_sell_commons())
		_aktion_zeile.add_child(sell_commons)


func _refresh_traenke() -> void:
	for child in _inventory_list.get_children():
		child.queue_free()
	_build_field_skill_section()
	var header := Label.new()
	header.text = Loc.pick("Tränke (Ziel: %s)", "Potions (target: %s)") % _selected.display_name
	header.add_theme_font_size_override("font_size", 16)
	_inventory_list.add_child(header)
	if GameState.consumables.is_empty():
		var leer := Label.new()
		leer.text = Loc.pick("Keine Tränke — der Händler verkauft sie, der Alchemist braut sie.",
			"No potions — the merchant sells them, the alchemist brews them.")
		leer.modulate = UiTheme.BLASS
		_inventory_list.add_child(leer)
	for id in GameState.consumables:
		var def := ConsumableLibrary.get_def(id)
		if def != null:
			_inventory_list.add_child(_make_consumable_row(def))


## Materialien nach Art gruppiert, mit Stufe.
func _refresh_material() -> void:
	for child in _material_list.get_children():
		child.queue_free()
	var arten := [[&"kraut", Loc.pick("Kräuter & Salze (Alchemie)", "Herbs & salts (alchemy)")],
		[&"erz", Loc.pick("Erz (Schmiede)", "Ore (smithy)")],
		[&"leder", Loc.pick("Leder (Schmiede)", "Leather (smithy)")],
		[&"kristall", Loc.pick("Kristall (Schmiede)", "Crystal (smithy)")],
		[&"rune", Loc.pick("Runen (Schmiede, garantieren Mindest-Rarität)", "Runes (smithy, guarantee a minimum rarity)")]]
	var irgendwas := false
	for art in arten:
		var zeilen: Array = []  # [Material-ID, Text]
		for id in MaterialLibrary.ids_der_art(art[0]):
			var anzahl := GameState.material_count(id)
			if anzahl > 0:
				var stufe := "" if art[0] in [&"kraut", &"rune"] \
					else "  (%s)" % MaterialLibrary.stufen_name(MaterialLibrary.stufe(id))
				zeilen.append([id, "%s ×%d%s" % [MaterialLibrary.display_name(id), anzahl, stufe]])
		if zeilen.is_empty():
			continue
		irgendwas = true
		_material_list.add_child(Bildschirm.ueberschrift(art[1]))
		for eintrag in zeilen:
			var zeile := HBoxContainer.new()
			zeile.add_theme_constant_override("separation", 8)
			zeile.add_child(UiHolz.icon(VorratIcons.material(_studio, eintrag[0]), 32))
			var text := Label.new()
			text.text = eintrag[1]
			zeile.add_child(text)
			_material_list.add_child(zeile)
	if not irgendwas:
		var leer := Label.new()
		leer.text = Loc.pick("Noch keine Materialien — Gegner und Truhen lassen sie fallen.",
			"No materials yet — enemies and chests drop them.")
		leer.modulate = UiTheme.BLASS
		_material_list.add_child(leer)


# --- Kacheln & Hover-Karte -----------------------------------------------------

## Kachel mit Item-Icon, Raritäts-Rahmen und Level (leer: Slot-Name).
## Fokussierbar (WASD + E) mit goldenem Fokusrahmen.
func _kachel(item: ItemInstance, leer_text: String, groesse: int) -> PanelContainer:
	var kachel := PanelContainer.new()
	kachel.custom_minimum_size = Vector2(groesse, groesse)
	kachel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	kachel.focus_mode = Control.FOCUS_ALL
	var stil := StyleBoxFlat.new()
	stil.set_corner_radius_all(8)
	stil.set_border_width_all(2)
	stil.set_content_margin_all(3)
	if item != null:
		var farbe: Color = LootGenerator.RARITY_COLORS[item.rarity]
		stil.bg_color = Color(UiTheme.HOLZ_TIEF.lerp(farbe, 0.1), 0.95)
		stil.border_color = farbe
	else:
		stil.bg_color = Color(UiTheme.KERBE, 0.8)
		stil.border_color = Color(UiTheme.MESSING, 0.25)
	kachel.add_theme_stylebox_override("panel", stil)
	kachel.set_meta(&"stil", stil)
	var lage := Control.new()
	lage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kachel.add_child(lage)
	if item != null:
		# Seltenheits-Schein hinter dem Icon (UiHolz.glanz), Icon mit Randlicht.
		var schein := TextureRect.new()
		schein.texture = UiHolz.glanz(LootGenerator.RARITY_COLORS[item.rarity])
		schein.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		schein.stretch_mode = TextureRect.STRETCH_SCALE
		schein.mouse_filter = Control.MOUSE_FILTER_IGNORE
		schein.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lage.add_child(schein)
		var bild := TextureRect.new()
		bild.texture = GegenstandIcons.textur(_studio, item.base)
		bild.texture_filter = UiHolz.ICON_FILTER
		bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bild.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lage.add_child(bild)
		# Item-Level als Messing-Chip unten rechts (nie direkt auf dem Icon).
		var stufe := UiHolz.level_chip(item.item_level)
		stufe.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)  # vor add_child
		stufe.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		stufe.grow_vertical = Control.GROW_DIRECTION_BEGIN
		stufe.offset_right = 1
		stufe.offset_bottom = 1
		lage.add_child(stufe)
	else:
		var text := Label.new()
		text.text = leer_text
		text.add_theme_font_size_override("font_size", 10)
		text.add_theme_color_override("font_color", Color(UiTheme.TEXT, 0.45))
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lage.add_child(text)
	# Fokusrahmen obenauf, nur solange die Kachel den Fokus hat.
	var rahmen := Panel.new()
	rahmen.add_theme_stylebox_override("panel", UiTheme.fokus_rahmen())
	rahmen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rahmen.visible = false
	rahmen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lage.add_child(rahmen)
	kachel.focus_entered.connect(func() -> void: rahmen.visible = true)
	kachel.focus_exited.connect(func() -> void: rahmen.visible = false)
	return kachel


## Rahmenfarbe setzen (KEIN_RAHMEN = Grundstil). Unverändertes wird übersprungen.
func _markieren(kachel: PanelContainer, farbe: Color) -> void:
	if kachel.get_meta(&"markiert", KEIN_RAHMEN) == farbe:
		return
	kachel.set_meta(&"markiert", farbe)
	var basis: StyleBoxFlat = kachel.get_meta(&"stil")
	if farbe == KEIN_RAHMEN:
		kachel.add_theme_stylebox_override("panel", basis)
		return
	var stil := basis.duplicate() as StyleBoxFlat
	stil.border_color = farbe
	stil.set_border_width_all(3)
	kachel.add_theme_stylebox_override("panel", stil)


## Kachel per Tastatur fokussiert: Werte-Karte daneben zeigen.
func _kachel_fokus(kachel: Control, item: ItemInstance, ausgeruestet: bool) -> void:
	if _tastatur:
		_popup_zeigen(item, ausgeruestet, kachel)


func _kachel_fokus_weg(kachel: Control) -> void:
	if _popup_anker == kachel:
		_popup_zeigen(null)


## Maus verlässt eine Kachel: eine Tastatur-Karte bleibt stehen.
func _popup_maus_weg() -> void:
	if _popup_anker == null or not is_instance_valid(_popup_anker):
		_popup_zeigen(null)


## Hover-Karte zeigen (null = verstecken). Ausgerüstete Items ohne Vergleich.
## `anker`: neben dieser Kachel statt an der Maus (Tastatur).
func _popup_zeigen(item: ItemInstance, ausgeruestet := false, anker: Control = null) -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null
	_popup_anker = anker if item != null else null
	_hover_item = item if not ausgeruestet else null
	if item == null:
		return
	var gegenstueck: ItemInstance = null if ausgeruestet else _ausgeruestet_fuer(item)
	_popup = ItemInfo.karte(item, gegenstueck, _vergleich and not ausgeruestet, _studio)
	_popup_ebene.add_child(_popup)
	_process(0.0)


## Das Item, mit dem `item` verglichen wird: gleicher Slot beim Helden
## (Ringe: Ring 1, sonst Ring 2; leichte Waffen auch gegen die Nebenhand).
func _ausgeruestet_fuer(item: ItemInstance) -> ItemInstance:
	var slot := item.base.slot
	var gegen: ItemInstance = _selected.equipment.get(slot)
	if gegen == null and slot == Enums.EquipSlot.RING_1:
		gegen = _selected.equipment.get(Enums.EquipSlot.RING_2)
	if gegen == null and _slot_filter == Enums.EquipSlot.OFF_HAND:
		gegen = _selected.equipment.get(Enums.EquipSlot.OFF_HAND)
	return gegen


# --- Drag & Drop ----------------------------------------------------------------

## Ziehen beginnt: Vorschau-Icon am Mauszeiger, passende Slots leuchten grün.
## `von_slot` = -1 für Taschen-Gegenstände.
func _ziehen_starten(item: ItemInstance, von_slot: int) -> Variant:
	if item == null:
		return null
	_popup_zeigen(null)
	var bild := TextureRect.new()
	bild.texture = GegenstandIcons.textur(_studio, item.base)
	bild.texture_filter = UiHolz.ICON_FILTER
	bild.custom_minimum_size = Vector2(56, 56)
	bild.size = Vector2(56, 56)
	bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bild.modulate.a = 0.85
	set_drag_preview(bild)
	_gezogen = item
	for slot in _slot_kacheln:
		var kachel: Control = _slot_kacheln[slot]
		if von_slot < 0:
			kachel.modulate = UiTheme.GUT if _passt_in_slot(item, slot) else UiTheme.INAKTIV
	return {"item": item, "slot": von_slot}


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _gezogen != null:
		_gezogen = null
		for slot in _slot_kacheln:
			if is_instance_valid(_slot_kacheln[slot]):
				_slot_kacheln[slot].modulate = Color.WHITE


func _passt_auf_slot(daten: Variant, slot: Enums.EquipSlot) -> bool:
	return daten is Dictionary and int(daten.get("slot", 0)) < 0 \
		and _passt_in_slot(daten["item"], slot)


## Kann `item` in genau diesen Slot? Ringe in beide Ring-Slots, leichte
## Waffen (Dolch) auch in die Nebenhand — aber nicht neben einem Zweihänder.
func _passt_in_slot(item: ItemInstance, slot: Enums.EquipSlot) -> bool:
	match slot:
		Enums.EquipSlot.RING_1, Enums.EquipSlot.RING_2:
			return item.base.slot == Enums.EquipSlot.RING_1
		Enums.EquipSlot.OFF_HAND:
			if item.base.slot == Enums.EquipSlot.OFF_HAND:
				return true
			var haupt: ItemInstance = _selected.equipment.get(Enums.EquipSlot.WEAPON)
			return item.base.light and item.base.slot == Enums.EquipSlot.WEAPON \
				and (haupt == null or not haupt.base.two_handed)
	return item.base.slot == slot


## Auf einen Slot fallen lassen: Ringe und Zweitdolch landen GENAU dort,
## alles andere geht durch die normalen Ausrüst-Regeln.
func _auf_slot_ablegen(daten: Variant, slot: Enums.EquipSlot) -> void:
	var item: ItemInstance = daten["item"]
	var genau := slot in [Enums.EquipSlot.RING_1, Enums.EquipSlot.RING_2] \
		or (slot == Enums.EquipSlot.OFF_HAND and item.base.slot == Enums.EquipSlot.WEAPON)
	if not genau:
		_on_equip(item)
		return
	GameState.inventory.erase(item)
	var alt := _selected.unequip(slot)
	if alt != null:
		GameState.inventory.append(alt)
	_selected.equipment[slot] = item
	_selected.recompute_derived()
	_auswahl = item
	_auswahl_ausgeruestet = true
	Sfx.play(&"bestaetigen")
	_refresh()


## Taschen nehmen ausgerüstete Gegenstände an (= ablegen).
func _passt_in_taschen(_pos: Vector2, daten: Variant) -> bool:
	return daten is Dictionary and int(daten.get("slot", -1)) >= 0


func _in_taschen_ablegen(_pos: Vector2, daten: Variant) -> void:
	_on_unequip(int(daten["slot"]) as Enums.EquipSlot)


## Filter-Schlüssel eines Slots (beide Ringe teilen sich einen Filter).
static func _filter_fuer(slot: Enums.EquipSlot) -> int:
	return Enums.EquipSlot.RING_1 if slot == Enums.EquipSlot.RING_2 else slot


## Passt das Item in den gefilterten Slot? Leichte Waffen auch in die Nebenhand.
static func _passt(item: ItemInstance, filter: int) -> bool:
	if filter == ALLE:
		return true
	if filter == Enums.EquipSlot.OFF_HAND and item.base.light and item.base.slot == Enums.EquipSlot.WEAPON:
		return true
	return item.base.slot == filter


func _slot_von(item: ItemInstance) -> Enums.EquipSlot:
	for slot in _selected.equipment:
		if _selected.equipment[slot] == item:
			return slot
	return item.base.slot


## Nach dem Bestätigen wird alles neu gebaut — der Fokus lag auf dem
## sterbenden Bestätigen-Knopf: freigeben und in der Verteilung neu setzen.
func _nach_verteilung() -> void:
	var besitzer := get_viewport().gui_get_focus_owner()
	if besitzer != null:
		besitzer.release_focus()
	_refresh()
	(func() -> void: UiTheme.focus_first_button(_stats_box)).call_deferred()


## Statuspunkte verteilen: geteiltes StatAllocator-Widget (Planen »
## Bestätigen, Gedrückthalten = Auto-Klick) + Umskillen gegen Gold.
func _rebuild_stat_allocation() -> void:
	for child in _stats_box.get_children():
		child.queue_free()

	var alloc := StatAllocator.create(_selected)
	_alloc = alloc
	alloc.changed.connect(_nach_verteilung)
	_stats_box.add_child(alloc)

	# Umskillen gegen Gold: alle verteilten Punkte zurück in den freien Pool
	# (Attribute auf Basis 5) — für alle, die sich verskillt haben.
	var invested := 0
	for stat in StatBlock.STAT_NAMES:
		invested += maxi(0, _selected.stats.get(stat) - 5)
	if invested > 0:
		var cost := 100 + 20 * invested
		var respec_button := Button.new()
		var respec_fragt := _respec_id == _selected.get_instance_id()
		respec_button.text = Loc.pick("Umskillen — %s zurück (%d Gold)",
			"Respec — refund %s (%d gold)") % [
			Loc.anzahl(invested, "Punkt", "Punkte", "point", "points"), cost]
		if respec_fragt:
			respec_button.text = Loc.pick("Wirklich umskillen? %d Gold, alle Punkte zurück",
				"Really respec? %d gold, all points refunded") % cost
		respec_button.disabled = GameState.gold < cost
		respec_button.tooltip_text = Loc.pick(
			"Setzt alle Attribute auf die Basis 5 zurück;\ndie Punkte landen im freien Pool.",
			"Resets all attributes to the base of 5;\nthe points return to the free pool.")
		respec_button.pressed.connect(func() -> void:
			if _respec_id != _selected.get_instance_id():
				# Kein _refresh: eine laufende Planung bleibt bis zur Bestätigung erhalten.
				_respec_id = _selected.get_instance_id()
				respec_button.text = Loc.pick("Wirklich umskillen? %d Gold, alle Punkte zurück",
					"Really respec? %d gold, all points refunded") % cost
				return
			_respec_id = 0
			GameState.gold -= cost
			_selected.respec()
			GameState.save_game()
			Sfx.play(&"bestaetigen")
			_refresh())
		_stats_box.add_child(respec_button)


static func _char_summary(member: Combatant) -> String:
	return Loc.pick("Level %d (%d/%d XP)  ·  HP %d/%d  ·  MP %d/%d  ·  Rüstung %d (−%d %% gg. Lv %d)  ·  Waffenschaden +%d\nSTR %d  INT %d  VIT %d  SPI %d  AGI %d  LCK %d",
		"Level %d (%d/%d XP)  ·  HP %d/%d  ·  MP %d/%d  ·  Armor %d (−%d %% vs Lv %d)  ·  Weapon damage +%d\nSTR %d  INT %d  VIT %d  SPI %d  AGI %d  LCK %d") % [
		member.level, member.xp, member.xp_to_next(),
		member.hp, member.max_hp, member.mp, member.max_mp,
		member.total_armor(), roundi(100.0 * Combatant.minderung(member.total_armor(), member.level)),
		member.level, member.weapon_damage(),
		member.stat(&"strength"), member.stat(&"intelligence"), member.stat(&"vitality"),
		member.stat(&"spirit"), member.stat(&"agility"), member.stat(&"luck"),
	]



# --- Tränke & Feldzauber (außerhalb des Kampfs) ---------------------------------

## Trank-Zeile: Benutzen wirkt auf den links ausgewählten Helden.
func _make_consumable_row(def: ConsumableDef) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	row.add_child(UiHolz.icon(VorratIcons.trank(_studio, def.id), 40))
	var info := Label.new()
	info.text = "%s ×%d  —  %s" % [def.display_name,
		GameState.consumable_count(def.id), def.description]
	info.add_theme_font_size_override("font_size", 12)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(info)
	var use := Button.new()
	use.text = Loc.pick("Benutzen (%s)", "Use (%s)") % _selected.display_name
	var needs_dead := def.effect == Enums.ConsumableEffect.REVIVE
	use.disabled = _selected.is_alive() == needs_dead
	use.pressed.connect(_use_consumable.bind(def))
	row.add_child(use)
	return panel


func _use_consumable(def: ConsumableDef) -> void:
	var target := _selected
	match def.effect:
		Enums.ConsumableEffect.HEAL_HP:
			if not target.is_alive():
				return
			target.heal(def.heal_amount(target))
		Enums.ConsumableEffect.RESTORE_MP:
			if not target.is_alive():
				return
			target.mp = mini(target.max_mp, target.mp + def.mana_amount(target))
		Enums.ConsumableEffect.CURE_AILMENTS:
			if not target.is_alive():
				return
			for entry in target.statuses.duplicate():
				if entry["status"] in def.cures:
					target.statuses.erase(entry)
		Enums.ConsumableEffect.REVIVE:
			if target.is_alive():
				return
			target.hp = maxi(1, roundi(target.max_hp * def.potency / 100.0))
	GameState.consume(def.id)
	Sfx.play(&"trank")
	_refresh()


## Feldzauber: Heilung (Heilig), Kuren (Reinigung) und Wiederbelebung sind
## AUSSERHALB des Kampfs wirkbar (Prep vor Kämpfen) — Buffs bewusst nicht.
func _build_field_skill_section() -> void:
	var rows: Array[Control] = []
	for caster in GameState.party:
		if not caster.is_alive():
			continue
		for skill: Skill in caster.skills.slice(0, caster.skill_slots()):
			if not _is_field_skill(skill, caster):
				continue
			rows.append(_make_field_skill_row(caster, skill))
	if rows.is_empty():
		return
	var header := Label.new()
	header.text = Loc.pick("Feldzauber (Heilung/Kuren — Ziel: %s)",
		"Field spells (healing/cures — target: %s)") % _selected.display_name
	header.add_theme_font_size_override("font_size", 16)
	_inventory_list.add_child(header)
	for row in rows:
		_inventory_list.add_child(row)


## Feld-tauglich: gültig, freundliche Form UND heilende/kurierende Wirkung.
func _is_field_skill(skill: Skill, caster: Combatant) -> bool:
	if not skill.is_valid(caster):
		return false
	var form := skill.get_form()
	if form != Enums.SkillForm.ALLY and form != Enums.SkillForm.AURA \
			and form != Enums.SkillForm.SELF:
		return false
	var element := skill.get_element()
	if element != null and element.element == Enums.Element.HOLY:
		return true
	for effect in skill.get_effect_blocks():
		if effect.status == Enums.Status.CLEANSE or effect.status == Enums.Status.REVIVE:
			return true
	return false


func _make_field_skill_row(caster: Combatant, skill: Skill) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var cost := skill.get_mp_cost(caster)
	var info := Label.new()
	info.text = "%s: %s (%d MP)  ·  %d/%d MP" % [caster.display_name,
		skill.display_name, cost, caster.mp, caster.max_mp]
	info.add_theme_font_size_override("font_size", 12)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var cast := Button.new()
	cast.text = Loc.pick("Wirken", "Cast")
	cast.disabled = caster.mp < cost
	cast.pressed.connect(_cast_field_skill.bind(caster, skill))
	row.add_child(cast)
	return panel


func _cast_field_skill(caster: Combatant, skill: Skill) -> void:
	var cost := skill.get_mp_cost(caster)
	if caster.mp < cost or not caster.is_alive():
		Sfx.play(&"fehler")
		return
	caster.mp -= cost
	var targets: Array[Combatant] = []
	match skill.get_form():
		Enums.SkillForm.ALLY:
			targets = [_selected]
		Enums.SkillForm.AURA:
			targets = GameState.party.duplicate()
		Enums.SkillForm.SELF:
			targets = [caster]
	var element := skill.get_element()
	for target in targets:
		# Heilig-Heilung: dieselbe Formel wie im Kampf (Battle.normale_heilung —
		# mit Geist-, Heiligstab-, Trainings- und Eigenschafts-Boni).
		if element != null and element.element == Enums.Element.HOLY and target.is_alive():
			target.heal(roundi(Battle.normale_heilung(caster, skill)))
		for effect in skill.get_effect_blocks():
			if effect.status == Enums.Status.CLEANSE and target.is_alive():
				for entry in target.statuses.duplicate():
					if entry["status"] in Battle.CURABLE_STATUSES:
						target.statuses.erase(entry)
			elif effect.status == Enums.Status.REVIVE and not target.is_alive():
				target.hp = maxi(1, roundi(target.max_hp * effect.potency / 100.0))
	Sfx.play(&"heilung")
	_refresh()
