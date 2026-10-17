extends SceneTree
## Rendert alle Musik-Tracks, misst die Renderzeit und speichert sie als WAV
## (zum Anhören außerhalb des Spiels):
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/musik_export.gd -- --ziel=C:/pfad


func _init() -> void:
	var ziel := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ziel="):
			ziel = arg.trim_prefix("--ziel=")
	var musik: Node = load("res://autoload/music.gd").new()
	var gesamt := 0
	for name in musik.RENDER_REIHENFOLGE:
		var t := Time.get_ticks_msec()
		var stream: AudioStreamWAV
		if name == &"sieg":
			stream = musik.render_sieg()
		elif name == &"niederlage":
			stream = musik.render_niederlage()
		else:
			stream = musik.render_partitur(musik.PARTITUREN[name])
		var dauer := Time.get_ticks_msec() - t
		gesamt += dauer
		print("%-11s %5.1f s Musik, gerendert in %5d ms" % [name, stream.get_length(), dauer])
		if ziel != "":
			stream.save_to_wav(ziel.path_join(String(name) + ".wav"))
	print("gesamt: %d ms" % gesamt)
	musik.free()
	quit(0)
