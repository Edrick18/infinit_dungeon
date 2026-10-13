extends Node
## Dev-Werkzeug: startet eine echte Spielszene (Standard: Dungeon) und
## speichert einen Screenshot.
##   godot --path . res://scripts/dev/dungeon_shot.tscn -- --shot=<pfad.png>
##     [--frames=60] [--zoom=10.5] [--stufe=S] [--taste=move_up] [--szene=res://…]

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
	GameState.first_time("kampf")
	var szenen_pfad := "res://scenes/dungeon/dungeon_scene.tscn"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stufe="):
			var rng := RandomNumberGenerator.new()
			rng.seed = 4711
			GameState.start_run(CardFactory.make_card(int(arg.substr(8)), rng))
		elif arg.begins_with("--szene="):
			szenen_pfad = arg.substr(8)
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
		GameState.pending_battle = {"enemy_id": -1, "is_boss": boss, "enemies": feinde}
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
