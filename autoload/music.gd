extends Node
## Autoload "Music": prozedural komponierte Chiptune-Loops — wie die SFX
## komplett ohne Audio-Assets (keine Downloads, keine Lizenzfragen, nichts
## Binäres im Repo). Die Tracks werden beim Start in einem Hintergrund-
## Thread vorgerendert; bis dahin bleibt es still und der erste Track
## blendet weich ein, sobald er fertig ist.
##
## Nutzung: Music.play(&"menu"|&"stadt"|&"dungeon"|&"kampf"|&"boss").
## Derselbe Track läuft über Szenenwechsel einfach weiter (Autoload).

const MIX_RATE := 22050
const FADE_TIME := 0.9
const SILENT_DB := -50.0

var enabled := true

var _tracks: Dictionary = {}
var _rendered := false
var _pending: StringName = &""
var _current: StringName = &""
var _thread: Thread
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _use_a := true


func _ready() -> void:
	# Eigener Bus "Musik" (Lautstärke in den Optionen), an den Master geroutet.
	if AudioServer.get_bus_index("Musik") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Musik")
	var settings := get_node_or_null(^"/root/Settings")
	if settings != null:
		settings.apply_music_volume()
	_player_a = _make_player()
	_player_b = _make_player()
	_thread = Thread.new()
	_thread.start(_render_all)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _make_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"Musik"
	player.volume_db = SILENT_DB
	add_child(player)
	return player


## Track wechseln (weicher Crossfade). Gleicher Track = weiterlaufen lassen.
func play(track: StringName) -> void:
	if not enabled or track == _current:
		return
	_current = track
	if not _rendered:
		_pending = track  # wird nachgeholt, sobald der Render-Thread fertig ist
		return
	var incoming := _player_b if _use_a else _player_a
	var outgoing := _player_a if _use_a else _player_b
	_use_a = not _use_a
	var stream: AudioStreamWAV = _tracks.get(track)
	if stream == null:
		_fade_out(outgoing)
		return
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(incoming, "volume_db", 0.0, FADE_TIME)
	_fade_out(outgoing)


func stop() -> void:
	_current = &""
	_pending = &""
	_fade_out(_player_a)
	_fade_out(_player_b)


func _fade_out(player: AudioStreamPlayer) -> void:
	if not player.playing:
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", SILENT_DB, FADE_TIME)
	tween.tween_callback(player.stop)


# --- Komposition -----------------------------------------------------------------
# Ein Track = Akkordfolge (MIDI-Noten je Akkord) + Stil (Tempo, Muster).
# Pro 16tel-Schritt: Bass (Dreieck), Arpeggio (Rechteck), Hi-Hat (Rauschen),
# Kick (Sinus-Sweep). Loop-Punkt exakt am Ende der Folge.

func _render_all() -> void:
	var tracks := {}
	# Hauptmenü/Hub: ruhiges Moll-Arpeggio, kein Schlagzeug.
	tracks[&"menu"] = _render_track(76.0, [
		[57, 60, 64], [55, 59, 62], [52, 55, 59], [57, 60, 64],
	], {"bass_every": 8, "arp_every": 4, "arp_gain": 0.09})
	# Stadt: fröhliches Dur, leichter Puls.
	tracks[&"stadt"] = _render_track(104.0, [
		[60, 64, 67], [53, 57, 60], [55, 59, 62], [60, 64, 67],
	], {"bass_every": 4, "arp_every": 2, "arp_gain": 0.08, "hats": true})
	# Dungeon: langsam, spärlich, tief — Anspannung statt Action.
	tracks[&"dungeon"] = _render_track(66.0, [
		[45, 48, 52], [41, 45, 48], [45, 48, 52], [44, 47, 52],
	], {"bass_every": 8, "arp_every": 4, "arp_gain": 0.07})
	# Kampf: treibende Achtel, Hi-Hats + Kick.
	tracks[&"kampf"] = _render_track(132.0, [
		[57, 60, 64], [55, 59, 62], [53, 57, 60], [52, 56, 59],
	], {"bass_every": 2, "arp_every": 2, "arp_gain": 0.10,
		"hats": true, "kick": true, "kick_every": 8})
	# Boss: schneller, tiefer, dichter.
	tracks[&"boss"] = _render_track(144.0, [
		[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 49, 52],
	], {"bass_every": 2, "arp_every": 1, "arp_gain": 0.09,
		"hats": true, "kick": true, "kick_every": 4})
	call_deferred("_on_rendered", tracks)


func _on_rendered(tracks: Dictionary) -> void:
	_tracks = tracks
	_rendered = true
	if _pending != &"":
		var track := _pending
		_pending = &""
		_current = &""  # play() soll den Wechsel wirklich ausführen
		play(track)


static func _midi(note: int) -> float:
	return 440.0 * pow(2.0, (note - 69) / 12.0)


func _render_track(bpm: float, chords: Array, style: Dictionary) -> AudioStreamWAV:
	var steps_per_bar := 16
	var step_time := (60.0 / bpm) / 4.0
	var total_steps := chords.size() * steps_per_bar
	var count := int(total_steps * step_time * MIX_RATE)
	var data := PackedFloat32Array()
	data.resize(count)

	var bass_every := int(style.get("bass_every", 4))
	var arp_every := int(style.get("arp_every", 2))
	var arp_gain := float(style.get("arp_gain", 0.09))
	for bar in chords.size():
		var chord: Array = chords[bar]
		for step in steps_per_bar:
			var t0 := (bar * steps_per_bar + step) * step_time
			if step % bass_every == 0:
				_add_note(data, t0, step_time * bass_every * 0.9,
					_midi(int(chord[0]) - 24), 0.24, 1)
			if step % arp_every == 0:
				var tone := int(chord[(step / arp_every) % chord.size()])
				_add_note(data, t0, step_time * arp_every * 0.85,
					_midi(tone), arp_gain, 0)
			if style.get("hats", false) and step % 4 == 2:
				_add_noise(data, t0, 0.03, 0.045)
			if style.get("kick", false) and step % int(style.get("kick_every", 8)) == 0:
				_add_kick(data, t0)

	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav


## Note additiv einmischen: wave 0 = Rechteck (Lead), 1 = Dreieck (Bass).
func _add_note(data: PackedFloat32Array, t0: float, duration: float,
		freq: float, gain: float, wave: int) -> void:
	var start := int(t0 * MIX_RATE)
	var n := maxi(1, int(duration * MIX_RATE))
	var phase := 0.0
	var attack := 0.005 * MIX_RATE
	for i in n:
		var idx := start + i
		if idx >= data.size():
			return
		phase += freq / MIX_RATE
		var cycle := fmod(phase, 1.0)
		var sample: float
		if wave == 0:
			sample = 1.0 if cycle < 0.5 else -1.0
		else:
			sample = 4.0 * absf(cycle - 0.5) - 1.0
		var envelope := minf(1.0, i / attack) * exp(-3.0 * float(i) / n)
		data[idx] += sample * gain * envelope


func _add_noise(data: PackedFloat32Array, t0: float, duration: float, gain: float) -> void:
	var start := int(t0 * MIX_RATE)
	var n := int(duration * MIX_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = start  # deterministisch — Loop klingt bei jedem Durchlauf gleich
	for i in n:
		var idx := start + i
		if idx >= data.size():
			return
		data[idx] += rng.randf_range(-1.0, 1.0) * gain * (1.0 - float(i) / n)


## Kick: kurzer Sinus-Sweep von 110 Hz abwärts.
func _add_kick(data: PackedFloat32Array, t0: float) -> void:
	var start := int(t0 * MIX_RATE)
	var n := int(0.12 * MIX_RATE)
	var phase := 0.0
	for i in n:
		var idx := start + i
		if idx >= data.size():
			return
		var progress := float(i) / n
		phase += lerpf(110.0, 40.0, progress) / MIX_RATE
		data[idx] += sin(phase * TAU) * 0.30 * (1.0 - progress)
