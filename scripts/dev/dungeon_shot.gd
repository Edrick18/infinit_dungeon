extends Node
## Dev-Werkzeug: startet den echten Dungeon und speichert einen Screenshot.
##   godot --path . res://scripts/dev/dungeon_shot.tscn -- --shot=<pfad.png> [--frames=60] [--zoom=10.5]

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
	GameState.first_time("dungeon")  # Onboarding-Hinweis nicht ins Bild
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stufe="):
			var rng := RandomNumberGenerator.new()
			rng.seed = 4711
			GameState.start_run(CardFactory.make_card(int(arg.substr(8)), rng))
	var szene: Node = load("res://scenes/dungeon/dungeon_scene.tscn").instantiate()
	add_child(szene)
	if zoom > 0.0:
		szene._welt._zoom = zoom
	var taste := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--taste="):
			taste = arg.substr(8)
	var start: Vector2 = szene.player_pos
	if taste != "":
		Input.action_press(StringName(taste))
	for i in frames:
		await get_tree().process_frame
	if taste != "":
		Input.action_release(StringName(taste))
		var weg: Vector2 = szene.player_pos - start
		print("BEWEGUNG %s: Karte %s  (Welt-Bodenrichtung %s)" % [taste, weg.round(), weg.normalized()])
	print("FPS: ", Engine.get_frames_per_second(), "  Karte: ", szene.map.width, "x", szene.map.height)
	await RenderingServer.frame_post_draw
	if pfad != "":
		get_viewport().get_texture().get_image().save_png(pfad)
	get_tree().quit()
