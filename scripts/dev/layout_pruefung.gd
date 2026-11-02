extends Node
## Dev-Werkzeug (UI-Layout-Prüfung): baut eine Szene mit Stress-Daten (nur im
## Speicher, Slot 99) und meldet Elemente außerhalb des Bildschirms, abgeschnittene
## Texte, Kinder, die aus ihrem Container ragen, und den Tastatur-Fokus nach
## einer Tastenfolge.
##   godot --path . res://scripts/dev/layout_pruefung.tscn -- --szene=res://… [--shot=pfad.png]
##     [--fenster=WxH] [--englisch] [--stress] [--heldstufe=N] [--langnamen]
##     [--stufe=S] [--boss] [--feinde=a,b,c] [--riesen (Riesenwuchs-Größe ×1.3)] [--beute=F] [--kartenhueter] [--sieg]
##     [--taschen-voll] [--warteliste=N] [--aufstieg] [--punkte]
##     [--klicks=Text1|Text2] [--tasten=S*5,D,E] [--hinweise] [--warte=s]
##     [--aufloesung=WxH (Optionsmenü-Fenstermodus, misst das Fensterrechteck)]
##     [--namenlaenge=N] [--warteliste-lang=N] [--inventar-lang] [--vieleskills]
##     [--coop-sieg [--coop-items=N]] [--truhe] [--tresor-auf] [--meldung=Text]
##     [--methoden=_a|_b] [--hover [--regelbruch]] [--regel=id] [--vorlauf=s]
##     [--follow (Gegenprobe: alle Scroll-Listen folgen dem Fokus)]
##     [--zeit (Szenenaufbau, Sieg-Fenster-Aufbau und längstes Bild danach)]
## Layout-Pass 2026-11; der Test dazu: layout_selftest.gd.

const TEST_SLOT := 99
var _args: PackedStringArray


func _wert(name: String, standard := "") -> String:
	for a in _args:
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return standard


func _hat(name: String) -> bool:
	return ("--" + name) in _args


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	SaveManager.active_slot = TEST_SLOT
	if _hat("englisch"):
		GameState.language = "en"
	var fenster := _wert("fenster")
	if fenster != "":
		var t := fenster.split("x")
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(int(t[0]), int(t[1])))
	var aufl := _wert("aufloesung")
	if aufl != "":
		# Wie das Optionsmenü (nur im Speicher, nie gespeichert).
		var t2 := aufl.split("x")
		Settings.window_mode = Settings.WindowMode.WINDOWED
		Settings.resolution = Vector2i(int(t2[0]), int(t2[1]))
		Settings.apply_window()
		for i in 10:
			await get_tree().process_frame
		var fenster_rect := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
		var deko := Rect2i(DisplayServer.window_get_position_with_decorations(),
			DisplayServer.window_get_size_with_decorations())
		var nutzbar := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		print("AUFLOESUNG %s: Fenster %s  mit Rahmen %s  Bildschirm nutzbar %s  ganz sichtbar: %s" % [aufl,
			fenster_rect, deko, nutzbar, Rect2(nutzbar).encloses(Rect2(deko))])
	if not _hat("hinweise"):
		for h in ["dungeon", "kampf", "menu", "werkstatt", "inventar", "schmiede", "haendler", "taverne"]:
			GameState.first_time(h)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	if _hat("stress"):
		_stress(rng)
	var stufe := int(_wert("stufe", "20"))
	var szenen_pfad := _wert("szene", "res://scenes/main.tscn")
	if "battle" in szenen_pfad or "dungeon" in szenen_pfad:
		GameState.start_run(CardFactory.make_card(stufe, rng))
		if _wert("regel") != "":
			GameState.current_run["card"].sonderregel = StringName(_wert("regel"))
			GameState.current_run["card"].sonder_element = Enums.Element.FIRE
	if _hat("taschen-voll"):
		while GameState.inventory.size() < GameState.TASCHEN_LIMIT:
			GameState.inventory.append(LootGenerator.roll_item_with_rarity(stufe, Enums.Rarity.COMMON, rng))
	var warte_n := int(_wert("warteliste", "0"))
	for i in warte_n:
		GameState.beute_warteliste.append(LootGenerator.roll_item_with_rarity(stufe,
			[Enums.Rarity.LEGENDARY, Enums.Rarity.EPIC, Enums.Rarity.RARE][i % 3], rng))
	var lang_n := int(_wert("warteliste-lang", "0"))
	if lang_n > 0:
		GameState.beute_warteliste.append_array(lange_items(lang_n, stufe, rng))
	if _hat("inventar-lang"):
		GameState.inventory = lange_items(GameState.inventory.size(), stufe, rng)
	if "battle" in szenen_pfad:
		_kampf_vorbereiten(rng)
	var szene: Node = load(szenen_pfad).instantiate()
	var t0 := Time.get_ticks_usec()
	add_child(szene)
	var aufbau := Time.get_ticks_usec() - t0
	var laengstes := await _laengstes_bild(30)
	if _hat("zeit"):
		print("ZEIT Szenenaufbau: %.1f ms  längstes Bild (30): %.1f ms" % [aufbau / 1000.0, laengstes / 1000.0])
	if _wert("vorlauf") != "":
		await get_tree().create_timer(float(_wert("vorlauf"))).timeout
	if _hat("sieg") and "battle" in szene:
		await _sieg(szene)
	if _hat("coop-sieg") and "_last_gains" in szene:
		var items: Array = []
		for item in lange_items(int(_wert("coop-items", "20")), 60, rng):
			items.append(item.to_dict())
		var mats := {}
		for id in MaterialLibrary.MATERIALS:
			mats[String(id)] = 3
		szene._last_gains = {"xp": 123456, "gold": 999999, "items": items, "items_wartend": 7,
			"materials": mats, "levels_gained": 5, "hero_level": 60}
		szene._on_battle_ended({"victory": true})
		for i in 10:
			await get_tree().process_frame
	if _hat("truhe") and "_chests" in szene and not szene._chests.is_empty():
		var truhe: Dictionary = szene._chests[0]
		truhe["rarity"] = Enums.Rarity.LEGENDARY
		truhe["gold"] = 12345
		szene._open_chest(truhe)
		for i in 5:
			await get_tree().process_frame
	if _hat("tresor-auf") and szene.has_method(&"_tresor_oeffnen"):
		szene._tresor_oeffnen()
		for i in 5:
			await get_tree().process_frame
	if _wert("meldung") != "" and szene.has_method(&"_show_message"):
		szene._show_message(_wert("meldung"))
		for i in 5:
			await get_tree().process_frame
	if _hat("hover") and szene.has_method(&"_popup_zeigen"):
		var bestes: ItemInstance = null
		for item in GameState.inventory:
			if bestes == null or item.affixes.size() > bestes.affixes.size():
				bestes = item
		if _hat("regelbruch"):
			LootGenerator.regelbruch_hinzufuegen(bestes, rng)
		get_viewport().warp_mouse(Vector2(1200, 650))
		szene._popup_zeigen(bestes)
		for i in 5:
			await get_tree().process_frame
	for m in _wert("methoden").split("|", false):
		print("METHODE ", m, ": ", szene.has_method(StringName(m)))
		if szene.has_method(StringName(m)):
			szene.call(StringName(m))
			for i in 10:
				await get_tree().process_frame
	for klick in _wert("klicks").split("|", false):
		await _klick(szene, klick)
	if _hat("follow"):
		# Gegenprobe: alle Scroll-Listen folgen dem Fokus.
		for sc in get_tree().root.find_children("*", "ScrollContainer", true, false):
			(sc as ScrollContainer).follow_focus = true
	var tasten := _wert("tasten")
	if tasten != "":
		await _tasten(tasten)
	var warte := float(_wert("warte", "0.5"))
	await get_tree().create_timer(warte).timeout
	_pruefen(self)
	await RenderingServer.frame_post_draw
	var pfad := _wert("shot")
	if pfad != "":
		get_viewport().get_texture().get_image().save_png(pfad)
	print("FENSTER ", DisplayServer.window_get_size(), " Viewport ", get_viewport().get_visible_rect().size)
	get_tree().quit()


func _stress(rng: RandomNumberGenerator) -> void:
	GameState.party.clear()
	GameState.reserve.clear()
	var namen := ["Wilhelmina-Kunigunde Abc", "Maximilian von Eschenba", "Bartholomäus Grünwaldt",
		"Konstantinopel-Reisende", "Friederike Sonnenschein", "Hildegard von Bingenhaus",
		"Theodora Wellenbrecherin", "Leopoldine Morgenstern", "Gottfried Eisenschmied", "Adalbert Wolkenstürmer"]
	if not _hat("langnamen"):
		namen = ["Aldric", "Mira", "Talin", "Runa", "Edda", "Björn", "Liora", "Kaspar", "Selma", "Dorn"]
	var laenge := int(_wert("namenlaenge", "0"))
	if laenge > 0:
		namen.clear()
		for i in 10:
			namen.append(("Friedericke Sonnenwald Xyz".left(laenge - 1)) + str(i))
	var kits := HeroLibrary.STARTER_LOADOUTS.keys()
	var heldstufe := int(_wert("heldstufe", "60"))
	for i in namen.size():
		GameState.recruit(namen[i], kits[i % kits.size()])
	for held: Combatant in GameState.party + GameState.reserve:
		while held.level < heldstufe:
			held.gain_xp(held.xp_to_next())
		for j in 14:
			held.equip(LootGenerator.roll_item_with_rarity(clampi(heldstufe, 1, 60), Enums.Rarity.LEGENDARY, rng))
		held.recompute_derived()
		held.hp = held.max_hp
		held.mp = held.max_mp
	GameState.gold = 999999999
	GameState.medals = 9999
	var tier := clampi(heldstufe, 1, 60)
	while GameState.inventory.size() < GameState.TASCHEN_LIMIT - 10:
		GameState.inventory.append(LootGenerator.roll_item_with_rarity(tier,
			[Enums.Rarity.COMMON, Enums.Rarity.MAGIC, Enums.Rarity.RARE, Enums.Rarity.EPIC,
			Enums.Rarity.LEGENDARY][rng.randi_range(0, 4)], rng))
	for def in ConsumableLibrary.all_defs():
		GameState.add_consumable(def.id, 999)
	for id in MaterialLibrary.MATERIALS:
		GameState.add_material(id, 9999)
	GameState.cards.clear()
	while GameState.cards.size() < GameState.card_capacity:
		var karte := CardFactory.make_card(rng.randi_range(1, 99), rng)
		karte.notiz = "Notiz mit recht langem Text zum Prüfen des Umbruchs in der Kartenzeile"
		GameState.cards.append(karte)
	GameState.card_archive.clear()
	while GameState.card_archive.size() < GameState.ARCHIV_PLAETZE:
		GameState.card_archive.append(CardFactory.make_card(rng.randi_range(1, 99), rng))


## Die n Gegenstände mit den längsten Namen aus vielen Würfen (legendär).
static func lange_items(n: int, stufe: int, rng: RandomNumberGenerator) -> Array[ItemInstance]:
	var alle: Array[ItemInstance] = []
	for i in maxi(3000, n * 4):
		alle.append(LootGenerator.roll_item_with_rarity(stufe, Enums.Rarity.LEGENDARY, rng))
	alle.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		return a.get_display_name().length() > b.get_display_name().length())
	return alle.slice(0, n)


func _kampf_vorbereiten(rng: RandomNumberGenerator) -> void:
	var boss := _hat("boss")
	var feinde := EnemyFactory.make_encounter(GameState.current_run["card"], rng, boss)
	var liste_text := _wert("feinde")
	if liste_text != "":
		var liste: Array[Combatant] = []
		for id in liste_text.split(","):
			var g := EnemyFactory.build(EnemyLibrary.get_archetype(StringName(id)), 3, rng)
			g.is_boss = boss and liste.is_empty()
			liste.append(g)
		feinde = liste
	if _hat("riesen"):
		for f: Combatant in feinde:
			f.sprite_scale *= 1.3
	var beute := float(_wert("beute", "1"))
	for f: Combatant in feinde:
		f.loot_mult *= beute
	if _hat("kartenhueter"):
		for f: Combatant in feinde:
			EnemyFactory._kartenhueter(f)
	if _hat("aufstieg"):
		for held: Combatant in GameState.party:
			held.xp = held.xp_to_next() - 1
	if _hat("vieleskills"):
		for held: Combatant in GameState.party:
			var vorlage: Skill = held.skills[0]
			while held.skills.size() < held.skill_slots():
				var neu := Skill.new()
				neu.display_name = "Langer Skillname Nummer %d" % held.skills.size()
				neu.blocks = vorlage.blocks.duplicate()
				held.skills.append(neu)
			print("SKILLS ", held.display_name, ": ", held.skills.size(), " / Slots ", held.skill_slots())
	if _hat("punkte"):
		for held: Combatant in GameState.party:
			held.stat_points = 999
	GameState.pending_battle = {"enemy_id": -1, "is_boss": boss, "enemies": feinde, "ueberraschung": 0}


## Echter Sieg über die Battle-Signale (Beute, XP, Level-Up wie im Spiel).
func _sieg(szene: Node) -> void:
	var battle = szene.battle
	for f: Combatant in battle.enemies:
		f.hp = 0
	battle.is_over = true
	var t0 := Time.get_ticks_usec()
	battle.battle_ended.emit(true)
	var aufbau := Time.get_ticks_usec() - t0
	var laengstes := await _laengstes_bild(20)
	if _hat("zeit"):
		print("ZEIT Sieg-Fenster: %.1f ms  längstes Bild (20): %.1f ms" % [aufbau / 1000.0, laengstes / 1000.0])


## Längstes Einzelbild der nächsten n Bilder (µs).
func _laengstes_bild(n: int) -> int:
	var laengstes := 0
	var letzte := Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		var jetzt := Time.get_ticks_usec()
		laengstes = maxi(laengstes, jetzt - letzte)
		letzte = jetzt
	return laengstes


func _klick(szene: Node, text: String) -> void:
	var treffer: Button = null
	for b in get_tree().root.find_children("*", "BaseButton", true, false):
		var k := b as Button
		if k != null and k.is_visible_in_tree() and k.text.contains(text):
			treffer = k
			break
	print("KLICK '%s': %s" % [text, treffer.get_path() if treffer else "nicht gefunden"])
	if treffer != null:
		treffer.pressed.emit()
	for i in 15:
		await get_tree().process_frame


func _tasten(folge: String) -> void:
	var codes := {"W": KEY_W, "A": KEY_A, "S": KEY_S, "D": KEY_D, "E": KEY_E, "Q": KEY_Q, "ESC": KEY_ESCAPE,
		"TAB": KEY_TAB}
	var schritte: Array[String] = []
	for teil in folge.split(",", false):
		if "*" in teil:
			var p := teil.split("*")
			for i in int(p[1]):
				schritte.append(p[0])
		else:
			schritte.append(teil)
	var n := 0
	for s in schritte:
		n += 1
		for gedrueckt in [true, false]:
			var ev := InputEventKey.new()
			ev.physical_keycode = codes[s]
			ev.keycode = codes[s]
			ev.pressed = gedrueckt
			Input.parse_input_event(ev)
			await get_tree().process_frame
		for i in 3:
			await get_tree().process_frame
		var f := get_viewport().gui_get_focus_owner()
		if f == null:
			print("TASTE %d %s » kein Fokus" % [n, s])
			continue
		var r := f.get_global_rect()
		var sicht := _sichtbar(f)
		var anteil := (sicht.get_area() / r.get_area()) if r.get_area() > 0 else 0.0
		var text := ""
		if f is Button:
			text = (f as Button).text.replace("\n", " ").left(50)
		elif f is LineEdit:
			text = "%s%s" % [(f as LineEdit).text.left(40), " [tippt]" if (f as LineEdit).is_editing() else ""]
		var scrolls := ""
		for sc in get_tree().root.find_children("*", "ScrollContainer", true, false):
			if (sc as Control).is_visible_in_tree() and (sc as ScrollContainer).get_v_scroll_bar().max_value \
					> (sc as Control).size.y + 1:
				scrolls += " scroll=%d/%d" % [(sc as ScrollContainer).scroll_vertical,
					int((sc as ScrollContainer).get_v_scroll_bar().max_value - (sc as Control).size.y)]
		print("TASTE %d %s » %s '%s' %s sichtbar=%d%%%s%s" % [n, s, f.get_class(), text, r, int(anteil * 100),
			scrolls, "  <<< UNSICHTBAR" if anteil < 0.9 else ""])


## Sichtbarer Teil: Schnitt mit allen beschneidenden Vorfahren und dem Bild.
func _sichtbar(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var p := c.get_parent()
	while p != null:
		if p is Control and ((p as Control).clip_contents or p is ScrollContainer):
			r = r.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	return r.intersection(get_viewport().get_visible_rect())


func _pfad(c: Node) -> String:
	var teile: Array[String] = []
	var n := c
	while n != null and n != self:
		teile.push_front(n.get_class().left(4) + (":" + n.name if not String(n.name).begins_with("@") else ""))
		n = n.get_parent()
	return "/".join(teile)


func _beschreibung(c: Control) -> String:
	var t := ""
	if c is Label:
		t = (c as Label).text
	elif c is Button:
		t = (c as Button).text
	elif c is RichTextLabel:
		t = (c as RichTextLabel).get_parsed_text()
	return "%s '%s' %s" % [c.get_class(), t.replace("\n", "⏎").left(60), c.get_global_rect()]


func _pruefen(wurzel: Node) -> void:
	var bild := get_viewport().get_visible_rect().grow(1.0)
	var gemeldet := 0
	for k in wurzel.find_children("*", "Control", true, false):
		var c := k as Control
		if not c.is_visible_in_tree() or c.size.x < 2 or c.size.y < 2:
			continue
		if c.modulate.a < 0.05 or c.self_modulate.a < 0.05:
			continue
		var r := c.get_global_rect()
		var interessant := c is Label or c is BaseButton or c is RichTextLabel or c is LineEdit \
			or c is Range or c is TextureRect or c is PanelContainer
		if not interessant:
			continue
		# Vollbild-Hintergründe überspringen.
		if r.size.x >= bild.size.x - 4 and r.size.y >= bild.size.y - 4:
			continue
		var sicht := _sichtbar(c)
		var anteil := sicht.get_area() / maxf(1.0, r.get_area())
		if not bild.encloses(r):
			# Liegt ein Scroll-Vorfahr dazwischen, der selbst im Bild ist? Dann
			# ist das Element nur weggescrollt (kein Fehler).
			var scroll := _scroll_vorfahr(c)
			if scroll != null and bild.encloses(scroll.get_global_rect()):
				continue
			print("AUSSERHALB (%d%% sichtbar) %s  [%s]" % [int(anteil * 100), _beschreibung(c), _pfad(c)])
			gemeldet += 1
			continue
		# Von einem nicht scrollenden Vorfahr beschnitten?
		if anteil < 0.98 and _scroll_vorfahr(c) == null:
			print("BESCHNITTEN (%d%% sichtbar) %s  [%s]" % [int(anteil * 100), _beschreibung(c), _pfad(c)])
			gemeldet += 1
		# Ragt aus dem Eltern-Container?
		var eltern := c.get_parent() as Container
		if eltern != null and eltern.is_visible_in_tree() and not (eltern is ScrollContainer):
			var er := eltern.get_global_rect().grow(2.0)
			if not er.encloses(r):
				print("RAGT HERAUS %s aus %s %s  [%s]" % [_beschreibung(c), eltern.get_class(), eltern.get_global_rect(), _pfad(c)])
				gemeldet += 1
		# Gekürzter einzeiliger Text?
		if c is Label and (c as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
			var l := c as Label
			if l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
				var breite := 0.0
				for zeile in l.text.split("\n"):
					breite = maxf(breite, l.get_theme_font("font").get_string_size(zeile,
						HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x)
				if breite > l.size.x + 2:
					print("GEKUERZT %s (Text %d px > %d px)  [%s]" % [_beschreibung(c), int(breite), int(l.size.x), _pfad(c)])
					gemeldet += 1
		if c is Button and ((c as Button).clip_text or (c as Button).text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING):
			var b := c as Button
			var bb := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				b.get_theme_font_size("font_size")).x
			if bb > b.size.x - 8:
				print("GEKUERZT %s (Text %d px > %d px)  [%s]" % [_beschreibung(c), int(bb), int(b.size.x), _pfad(c)])
				gemeldet += 1
	print("PRUEFUNG fertig: %d Meldungen" % gemeldet)


func _scroll_vorfahr(c: Control) -> ScrollContainer:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null
