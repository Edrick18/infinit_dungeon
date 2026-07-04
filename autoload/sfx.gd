extends Node
## Autoload "Sfx": prozedural synthetisierte Retro-Soundeffekte — komplett
## ohne Audio-Assets (keine Downloads, nichts Binäres im Repo). Alle Klänge
## werden beim Start aus einfachen Wellenformen (Rechteck/Sinus/Dreieck/
## Rauschen) mit Hüllkurve erzeugt und als AudioStreamWAV gecached.
##
## Nutzung: Sfx.play(&"treffer") — unbekannte Namen sind bewusst still.
## Alle Buttons im Spiel bekommen automatisch einen Klick-Sound (node_added).

enum Wave { SQUARE, SINE, TRIANGLE, NOISE }

const MIX_RATE := 22050
const PLAYER_POOL_SIZE := 8
const MASTER_VOLUME_DB := -8.0

## Global an/aus (später an ein Optionsmenü anschließbar).
var enabled := true

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	_sounds = generate_all()
	for i in PLAYER_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.volume_db = MASTER_VOLUME_DB
		add_child(player)
		_players.append(player)
	# Jeder Button im ganzen Spiel bekommt automatisch Klick-Feedback.
	get_tree().node_added.connect(_on_node_added)


func play(name: StringName) -> void:
	if not enabled or not _sounds.has(name) or _players.is_empty():
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _sounds[name]
	player.play()


func _on_node_added(node: Node) -> void:
	if node is Button:
		node.pressed.connect(play.bind(&"ui_klick"))


# --- Klang-Katalog -------------------------------------------------------------

## Erzeugt alle Sounds. Als eigene Funktion testbar (Headless, ohne Baum).
func generate_all() -> Dictionary:
	var sounds := {}
	# UI
	sounds[&"ui_klick"] = _stream([_tone(880, 660, 0.05, Wave.TRIANGLE, 0.4)])
	sounds[&"bestaetigen"] = _stream([_tone(660, 990, 0.09, Wave.SQUARE, 0.3)])
	sounds[&"fehler"] = _stream([_tone(220, 170, 0.14, Wave.SQUARE, 0.35)])
	# Kampf
	sounds[&"kampf_start"] = _stream([
		_mix(_tone(220, 90, 0.3, Wave.SQUARE, 0.35), _tone(0, 0, 0.3, Wave.NOISE, 0.15))])
	sounds[&"treffer"] = _stream([
		_mix(_tone(160, 70, 0.1, Wave.SQUARE, 0.4), _tone(0, 0, 0.08, Wave.NOISE, 0.35))])
	sounds[&"zauber"] = _stream([_tone(320, 980, 0.16, Wave.SINE, 0.4)])
	sounds[&"heilung"] = _stream([
		_tone(523, 523, 0.08, Wave.SINE, 0.35), _tone(659, 659, 0.08, Wave.SINE, 0.35),
		_tone(784, 784, 0.12, Wave.SINE, 0.35)])
	sounds[&"sieg"] = _stream([
		_tone(523, 523, 0.11, Wave.SQUARE, 0.3), _tone(659, 659, 0.11, Wave.SQUARE, 0.3),
		_tone(784, 784, 0.11, Wave.SQUARE, 0.3), _tone(1047, 1047, 0.22, Wave.SQUARE, 0.3)])
	sounds[&"niederlage"] = _stream([
		_tone(392, 392, 0.16, Wave.SQUARE, 0.3), _tone(330, 330, 0.16, Wave.SQUARE, 0.3),
		_tone(262, 196, 0.35, Wave.SQUARE, 0.3)])
	sounds[&"level_up"] = _stream([
		_tone(392, 392, 0.07, Wave.SQUARE, 0.3), _tone(523, 523, 0.07, Wave.SQUARE, 0.3),
		_tone(659, 659, 0.07, Wave.SQUARE, 0.3), _tone(784, 784, 0.07, Wave.SQUARE, 0.3),
		_tone(1047, 1047, 0.18, Wave.SQUARE, 0.3)])
	# Dungeon & Loot
	sounds[&"gold"] = _stream([
		_tone(1200, 1200, 0.06, Wave.TRIANGLE, 0.4), _tone(1600, 1600, 0.09, Wave.TRIANGLE, 0.4)])
	sounds[&"truhe"] = _stream([_tone(500, 950, 0.14, Wave.TRIANGLE, 0.4)])
	sounds[&"trank"] = _stream([
		_tone(600, 750, 0.07, Wave.SINE, 0.35), _tone(750, 600, 0.07, Wave.SINE, 0.35),
		_tone(600, 900, 0.1, Wave.SINE, 0.35)])
	sounds[&"treppe"] = _stream([
		_tone(500, 500, 0.09, Wave.TRIANGLE, 0.35), _tone(400, 400, 0.09, Wave.TRIANGLE, 0.35),
		_tone(320, 320, 0.12, Wave.TRIANGLE, 0.35)])
	# Events
	sounds[&"schrein"] = _stream([
		_mix(_tone(523, 523, 0.4, Wave.SINE, 0.25), _tone(784, 784, 0.4, Wave.SINE, 0.2))])
	sounds[&"opferstein"] = _stream([
		_mix(_tone(130, 90, 0.45, Wave.SINE, 0.4), _tone(0, 0, 0.2, Wave.NOISE, 0.1))])
	sounds[&"mimic"] = _stream([
		_mix(_tone(300, 120, 0.22, Wave.SQUARE, 0.4), _tone(0, 0, 0.12, Wave.NOISE, 0.3))])
	return sounds


# --- Synthese ------------------------------------------------------------------

## Ein Ton mit linearem Frequenzverlauf, kurzer Attack- und Ausklang-Hüllkurve.
func _tone(from_hz: float, to_hz: float, duration: float, wave: Wave,
		volume := 0.5) -> PackedFloat32Array:
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += lerpf(from_hz, to_hz, t) / MIX_RATE
		var value: float
		match wave:
			Wave.SQUARE:
				value = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			Wave.SINE:
				value = sin(phase * TAU)
			Wave.TRIANGLE:
				value = 4.0 * absf(fmod(phase, 1.0) - 0.5) - 1.0
			_:
				value = randf() * 2.0 - 1.0
		var attack := minf(1.0, i / (0.005 * MIX_RATE))
		samples[i] = value * attack * pow(1.0 - t, 1.5) * volume
	return samples


## Zwei Spuren übereinanderlegen (für Schichtklänge wie Treffer + Rauschen).
func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate()
	if b.size() > out.size():
		var tail := out
		out = b.duplicate()
		b = tail
	for i in b.size():
		out[i] = clampf(out[i] + b[i], -1.0, 1.0)
	return out


## Teilstücke hintereinander zu einem fertigen 16-Bit-Mono-Stream verketten.
func _stream(parts: Array) -> AudioStreamWAV:
	var total := 0
	for part in parts:
		total += part.size()
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	var offset := 0
	for part in parts:
		for i in part.size():
			bytes.encode_s16((offset + i) * 2, int(clampf(part[i], -1.0, 1.0) * 32000))
		offset += part.size()
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
