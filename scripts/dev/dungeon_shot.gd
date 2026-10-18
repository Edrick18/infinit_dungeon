extends Node
## Dev-Werkzeug: startet eine echte Spielszene (Standard: Dungeon) und
## speichert einen Screenshot.
##   godot --path . res://scripts/dev/dungeon_shot.tscn -- --shot=<pfad.png>
##     [--frames=60] [--zoom=10.5] [--stufe=S] [--taste=move_up] [--szene=res://…]
##     Kampf: [--boss] [--schmuck] [--animtest] [--ueberraschung=1|-1] [--wissen]

func _ready() -> void:
	var pfad := ""
	var frames := 60
	var zoom := -1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			pfad = arg.substr(7)
		elif arg.begins_with("--frames="):
			frames = int(arg.substr(9))
		elif arg.begins_with("--zoom="):
			zoom = float(arg.substr(7))
	GameState.first_time("dungeon")  # Onboarding-Hinweise nicht ins Bild
	if "--bankheld" in OS.get_cmdline_user_args():
		# Bank-Training prüfen: Party auf 30, ein frischer Held auf der Bank.
		for member in GameState.party:
			member.level = 30
		GameState.recruit("Edda", &"krieger")
		if GameState.party.size() > 4 or GameState.reserve.is_empty():
			GameState.bench_hero(GameState.party.back())
		GameState.gold = 50000
	GameState.first_time("kampf")
	var szenen_pfad := "res://scenes/dungeon/dungeon_scene.tscn"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stufe="):
			var rng := RandomNumberGenerator.new()
			rng.seed = 4711
			GameState.start_run(CardFactory.make_card(int(arg.substr(8)), rng))
		elif arg.begins_with("--szene="):
			szenen_pfad = arg.substr(8)
	# Besondere Dungeons: --regel=<id> setzt die Sonderregel, --tresor sucht
	# eine Karte mit Tresor auf Ebene 1 und stellt den Helden daneben.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--regel=") and GameState.current_run.has("card"):
			GameState.current_run["card"].sonderregel = StringName(arg.substr(8))
			GameState.current_run["card"].sonder_element = Enums.Element.FIRE
	if "--tresor" in OS.get_cmdline_user_args() and GameState.current_run.has("card"):
		var karte: DungeonCard = GameState.current_run["card"]
		for versuch in 200:
			var map := DungeonGenerator.generate(karte, 0)
			if map.tresor_cell.x >= 0:
				var traeger: Vector2i = map.enemies[0]["cell"]
				for gegner in map.enemies:
					if int(gegner["id"]) == map.schluessel_id:
						traeger = gegner["cell"]
				GameState.current_run["player_pos"] = DungeonMap.cell_center_px(map.tresor_cell) \
					+ Vector2(0, 40)
				if "--offen" in OS.get_cmdline_user_args():
					GameState.current_run["tresore"] = [0]
				if "--traeger" in OS.get_cmdline_user_args():
					GameState.current_run["player_pos"] = DungeonMap.cell_center_px(traeger) + Vector2(0, 60)
				break
			karte.seed += 1
	# Kampf mit echter Begegnung der aktuellen Karte (statt Menü-Testkampf).
	if "battle" in szenen_pfad and GameState.current_run.has("card"):
		var boss := "--boss" in OS.get_cmdline_user_args()
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var feinde := EnemyFactory.make_encounter(GameState.current_run["card"], rng, boss)
		if "--schmuck" in OS.get_cmdline_user_args():
			# Rang-Optik prüfen: 1. gülden, 2. Elite, 3. Champion.
			EnemyFactory._gild(feinde[0])
			if feinde.size() > 1:
				feinde[1].set_meta(&"rang", "elite")
			if feinde.size() > 2:
				feinde[2].set_meta(&"rang", "champion")
		if "--sonder" in OS.get_cmdline_user_args():
			# Sondergegner-Optik: 1. gülden, 2. strahlend, 3. Kartenhüter.
			EnemyFactory._gild(feinde[0])
			if feinde.size() > 1:
				EnemyFactory._strahlen(feinde[1])
			if feinde.size() > 2:
				EnemyFactory._kartenhueter(feinde[2])
		var ueberraschung := 0
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--ueberraschung="):
				ueberraschung = int(arg.substr(16))
		if "--wissen" in OS.get_cmdline_user_args():
			# Schwächen-Chips prüfen: alles als entdeckt markieren (nur im Speicher).
			for feind: Combatant in feinde:
				for element in feind.element_faktoren:
					GameState.entdecke_element(feind.wissens_schluessel(), int(element))
		GameState.pending_battle = {"enemy_id": -1, "is_boss": boss, "enemies": feinde,
			"ueberraschung": ueberraschung}
	var szene: Node = load(szenen_pfad).instantiate()
	add_child(szene)
	if zoom > 0.0 and "_welt" in szene:
		szene._welt._zoom = zoom
	var taste := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--taste="):
			taste = arg.substr(8)
	var start: Vector2 = szene.player_pos if "player_pos" in szene else Vector2.ZERO
	if taste != "":
		Input.action_press(StringName(taste))
	for i in frames:
		await get_tree().process_frame
	if "--abstimmung" in OS.get_cmdline_user_args() and szene.has_method(&"_abstimmung_anzeigen"):
		szene._abstimmung_anzeigen({"id": 1, "art": "treppe", "floor": 0, "von": "Lyra",
			"teilnehmer": ["Lyra", Net.my_hero_name(), "Bram"], "ja": ["Lyra"]})
		await get_tree().process_frame
	if "--animtest" in OS.get_cmdline_user_args() and "battle" in szene:
		# Kampfanimationen im Standbild prüfen: Blitz+Wackeln, Puls, Verpuffen.
		var feinde: Array = szene.battle.enemies
		szene._flash_sprite(feinde[0], false)
		szene._shake_sprite(feinde[0])
		if feinde.size() > 1:
			szene._pulse_sprite(feinde[1])
		if feinde.size() > 2:
			feinde[2].hp = 0
		for i in 5:
			await get_tree().process_frame
	if "--notiztest" in OS.get_cmdline_user_args() and szene.has_method(&"_notiz_bearbeiten") 			and not GameState.cards.is_empty():
		# Kartenlager: Notiz nur im Speicher setzen und das Notiz-Fenster öffnen.
		GameState.cards[1 if GameState.cards.size() > 1 else 0].notiz = "Hexenmeisterin als Boss — gut zum Runen-Farmen"
		szene._refresh()
		await get_tree().process_frame
		if not "--nurchip" in OS.get_cmdline_user_args():
			szene._notiz_bearbeiten(GameState.cards[0])
		for i in 5:
			await get_tree().process_frame
	if "--ringtest" in OS.get_cmdline_user_args() and szene.has_method(&"_auf_slot_ablegen"):
		# Inventar: einen Ring per Drop-Logik in Ring 2 legen und seine Karte zeigen
		# (nur im Speicher — die Szene speichert dabei nicht).
		for item in GameState.inventory:
			if item.base.slot == Enums.EquipSlot.RING_1:
				szene._auf_slot_ablegen({"item": item, "slot": -1}, Enums.EquipSlot.RING_2)
				await get_tree().process_frame
				szene._popup_zeigen(item, true)
				break
		for i in 5:
			await get_tree().process_frame
	if "--hover" in OS.get_cmdline_user_args() and szene.has_method(&"_popup_zeigen") \
			and not GameState.inventory.is_empty():
		szene._popup_zeigen(GameState.inventory[0])  # Inventar: Hover-Karte zeigen
		for i in 5:
			await get_tree().process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--abschnitt=") and szene.has_method(&"_open_section"):
			szene._open_section(StringName(arg.substr(12)))  # Händler-Reiter
			for i in 5:
				await get_tree().process_frame
	if "_ziehen" in szene:
		# Werkstatt: --held=<Party-Index> wählt den Helden, --ziehen=<Klotz-ID>
		# zeigt die Sockel so, als würde dieser Klotz gerade gezogen.
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--held="):
				szene._selected = GameState.party[int(arg.substr(7))]
				szene._rebuild_all()
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--vorlage="):  # Vorlage N in Slot 2 (Vorschau prüfen)
				var angebot: Array = szene._vorlagen_fuer_helden()
				var nr := int(arg.substr(10))
				if nr < angebot.size() and szene._selected.skills.size() > 1:
					szene._vorlage_anwenden(szene._selected.skills[1], angebot[nr])
					szene._geaendert = false  # Werkzeug: nie den Spielstand anfassen
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--ziehen="):
				szene._ziehen = BlockLibrary.get_block(StringName(arg.substr(9)))
				szene._refresh_editors()
		for i in 20:
			await get_tree().process_frame
		if "--buch" in OS.get_cmdline_user_args():  # Rezeptbuch mit allen Vorlagen
			for vorlage in szene._vorlagen_fuer_helden():
				WerkstattLogik.ins_buch(szene._selected, vorlage)
			szene._rechts_zeigen(&"buch")
			szene._geaendert = false  # Werkzeug: nie den Spielstand anfassen
			for i in 5:
				await get_tree().process_frame
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--bib="):  # Klotz-Liste um N Pixel scrollen
				var scroll := szene._library_list.get_parent() as ScrollContainer
				if scroll != null:
					scroll.scroll_vertical = int(arg.substr(6))
				for i in 5:
					await get_tree().process_frame
	if "--auto" in OS.get_cmdline_user_args() and "battle" in szene:
		# Echte Runde durchspielen: jeder Held wirkt seinen ersten Skill (sonst
		# Angriff) auf den ersten Gegner — prüft Effekte im echten Ablauf.
		for runde in 2:
			for held: Combatant in szene._pending_local.duplicate():
				var ziel: Combatant = szene.battle.enemies.filter(
					func(c: Combatant) -> bool: return c.is_alive()).front()
				var skill: Skill = held.skills[0] if not held.skills.is_empty() \
					and held.skills[0].is_valid(held) else null
				if skill != null:
					szene._set_plan(held, {"kind": "skill", "skill": skill, "target": ziel})
				else:
					szene._set_plan(held, {"kind": "attack", "target": ziel})
			var sek := float(OS.get_environment("AUTO_SEK")) if OS.get_environment("AUTO_SEK") != "" else 7.0
			await get_tree().create_timer(sek).timeout
			if szene.battle.is_over:
				break
	if "--fxtest" in OS.get_cmdline_user_args() and "battle" in szene:
		# Kampf-Effekte im Standbild: je Gegner ein Element (mit Schwäche/
		# Resistenz/Krit), auf den Helden Heilung und Buffs.
		var feinde: Array = szene.battle.enemies
		var helden: Array = szene.battle.players
		var elemente := [Enums.Element.FIRE, Enums.Element.LIGHTNING, Enums.Element.ICE,
			Enums.Element.HOLY, Enums.Element.DARK, Enums.Element.POISON]
		var ereignisse: Array = []
		for i in feinde.size():
			ereignisse.append({"art": &"element", "von": helden[i % helden.size()], "an": feinde[i],
				"element": elemente[(i + int(OS.get_environment("FX_OFFSET"))) % elemente.size()],
				"faktor": [1.5, 1.0, 0.5][i % 3]})
		ereignisse.append({"art": &"krit", "von": helden[0], "an": feinde[0]})
		if helden.size() > 1:
			ereignisse.append({"art": &"heilung", "von": helden[0], "an": helden[1]})
		ereignisse.append({"art": &"waffe", "von": feinde[0], "an": helden[0], "fern": false})
		# Dauerhafte Status-Anzeigen an den Figuren.
		var zustaende := [[Enums.Status.BURN, Enums.Status.ATK_UP], [Enums.Status.STUN, Enums.Status.MARKED],
			[Enums.Status.SHIELD, Enums.Status.POISON_DOT], [Enums.Status.FROZEN]]
		for i in feinde.size():
			for status in zustaende[i % zustaende.size()]:
				feinde[i].add_status(status, 3, 5)
		szene._refresh_all()
		szene._buehne.effekte.abspielen(ereignisse, szene._ort_fuer)
		var fx_zeit := 0.3  # Sekunden nach dem Auslösen (Bildzahl schwankt beim Shader-Kompilieren)
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--fxzeit="):
				fx_zeit = float(arg.substr(9))
		await get_tree().create_timer(fx_zeit).timeout
	if taste != "":
		Input.action_release(StringName(taste))
		var weg: Vector2 = szene.player_pos - start
		print("BEWEGUNG %s: Karte %s  (Welt-Bodenrichtung %s)" % [taste, weg.round(), weg.normalized()])
	if "map" in szene:
		print("FPS: ", Engine.get_frames_per_second(), "  Karte: ", szene.map.width, "x", szene.map.height)
	else:
		print("FPS: ", Engine.get_frames_per_second())
	await RenderingServer.frame_post_draw
	if pfad != "":
		get_viewport().get_texture().get_image().save_png(pfad)
	get_tree().quit()
