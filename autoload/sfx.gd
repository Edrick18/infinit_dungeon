extends Node
## Autoload "Sfx": prozedural synthetisierte Soundeffekte — komplett ohne
## Audio-Assets. Alle Klänge entstehen beim Start aus Wellenformen (Puls mit
## einstellbarer Breite, Sinus, Dreieck, gefiltertes Rauschen) mit Hüllkurve,
## Tiefpass und Echo und werden als AudioStreamWAV gecached.
##
## Nutzung: Sfx.play(&"treffer") — unbekannte Namen sind bewusst still.
## Alle Buttons im Spiel bekommen automatisch einen Klick-Sound (node_added).
## Eigener Bus "Effekte" (Lautstärke in den Optionen), an den Master geroutet.

enum Wave { SQUARE, SINE, TRIANGLE, NOISE, PULSE }

const MIX_RATE := 22050
const PLAYER_POOL_SIZE := 12
const MASTER_VOLUME_DB := -6.0
const BUS := &"Effekte"
## Derselbe Klang höchstens alle 45 ms — ein Flächenangriff auf vier Ziele
## soll nicht viermal übereinander knallen.
const MIN_ABSTAND_MS := 45
## Diese Klänge variieren leicht in der Tonhöhe (gegen Monotonie).
const VARIIERT: Array[StringName] = [&"treffer", &"treffer_fern", &"krit", &"block", &"ui_klick",
	&"dot", &"pfeil", &"gold", &"feuer", &"eis", &"blitz", &"gift", &"dunkel", &"magie",
	&"gegner_besiegt", &"schmiede"]

var enabled := true

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _zuletzt: Dictionary = {}


func _ready() -> void:
	bus_anlegen()
	var settings := get_node_or_null(^"/root/Settings")
	if settings != null:
		settings.apply_sfx_volume()
	_sounds = generate_all()
	for i in PLAYER_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.volume_db = MASTER_VOLUME_DB
		player.bus = BUS
		add_child(player)
		_players.append(player)
	# Jeder Button im ganzen Spiel bekommt automatisch Klick-Feedback.
	get_tree().node_added.connect(_on_node_added)


func play(name: StringName, lautstaerke_db := 0.0) -> void:
	if not enabled or not _sounds.has(name) or _players.is_empty():
		return
	if not _drossel_frei(name):
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _sounds[name]
	player.volume_db = MASTER_VOLUME_DB + lautstaerke_db
	player.pitch_scale = randf_range(0.93, 1.07) if name in VARIIERT else 1.0
	player.play()


func hat(name: StringName) -> bool:
	return _sounds.has(name)


## Drosselung: true = darf jetzt spielen (und merkt sich den Zeitpunkt).
func _drossel_frei(name: StringName) -> bool:
	var jetzt := Time.get_ticks_msec()
	if jetzt - int(_zuletzt.get(name, -100000)) < MIN_ABSTAND_MS:
		return false
	_zuletzt[name] = jetzt
	return true


static func bus_anlegen() -> void:
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)


# --- Kampf-Klänge -------------------------------------------------------------

## Stärkungen (Buff-Klang); alle anderen Status klingen als Schwächung.
const GUTE_STATUS: Array[Enums.Status] = [Enums.Status.SHIELD, Enums.Status.DEF_UP,
	Enums.Status.ATK_UP, Enums.Status.REGEN, Enums.Status.MANA_REGEN, Enums.Status.COUNTER,
	Enums.Status.THORNS, Enums.Status.FIRST_STRIKE, Enums.Status.MAGIE_SCHUTZ,
	Enums.Status.ELEMENT_SCHUTZ, Enums.Status.FOCUS, Enums.Status.CLEANSE,
	Enums.Status.EILE, Enums.Status.EISERNE_ABWEHR, Enums.Status.ZORN,
	Enums.Status.ZAUBERSPIEGEL, Enums.Status.PROVOKATION]
const ELEMENT_KLAENGE := {
	Enums.Element.FIRE: &"feuer", Enums.Element.ICE: &"eis", Enums.Element.LIGHTNING: &"blitz",
	Enums.Element.POISON: &"gift", Enums.Element.HOLY: &"heilig", Enums.Element.DARK: &"dunkel",
}


## Klang eines Kampf-Ereignisses (leer = still).
static func klang_fuer(e: Dictionary) -> StringName:
	match StringName(str(e.get("art", ""))):
		&"waffe":
			return &"treffer_fern" if e.get("fern", false) else &"treffer"
		&"magie":
			return &"magie"
		&"element":
			if int(e.get("element", -1)) == Enums.Element.HOLY and e.get("heilt", false):
				return &"heilung"
			return ELEMENT_KLAENGE.get(int(e.get("element", -1)), &"magie")
		&"heilung":
			return &"heilung"
		&"krit":
			return &"vernichtend" if e.get("vernichtend", false) else &"krit"
		&"block":
			return &"block"
		&"dot":
			return &"dot"
		&"beschwoerung":
			return &"beschwoerung"
		&"status":
			var status := int(e.get("status", -1))
			if status == Enums.Status.PROTECT:
				return &"schutzwall"
			return &"buff" if status in GUTE_STATUS else &"debuff"
		&"aufladung":
			return &"aufladung"
		&"entfesselt":
			return &"entfesselt"
		&"bannwelle":
			return &"bannwelle"
	return &""


func _on_node_added(node: Node) -> void:
	if node is Button:
		node.pressed.connect(play.bind(&"ui_klick"))


# --- Klang-Katalog -------------------------------------------------------------

## Erzeugt alle Sounds. Als eigene Funktion testbar (Headless, ohne Baum).
func generate_all() -> Dictionary:
	var s := {}
	# --- Oberfläche ---
	s[&"ui_klick"] = _stream([_lp(_tone(1250, 900, 0.035, Wave.TRIANGLE, 0.35), 0.5)])
	s[&"bestaetigen"] = _stream([_tone(660, 660, 0.05, Wave.PULSE, 0.22, 0.25),
		_tone(990, 990, 0.09, Wave.PULSE, 0.22, 0.25)])
	s[&"fehler"] = _stream([_lp(_tone(220, 160, 0.16, Wave.SQUARE, 0.28), 0.35)])
	s[&"kaufen"] = _stream([_echo(_cat([_tone(1320, 1320, 0.05, Wave.TRIANGLE, 0.35),
		_tone(1760, 1760, 0.12, Wave.TRIANGLE, 0.35)]), 0.07, 0.3, 0.3)])
	s[&"ausruesten"] = _stream([_mix(_noise(0.08, 0.3, 0.25), _tone(320, 240, 0.12, Wave.TRIANGLE, 0.3))])
	s[&"menue"] = _stream([_noise_sweep(0.16, 0.25, 0.1, 0.5)])
	# --- Kampf: Waffen ---
	s[&"kampf_start"] = _stream([_mix(_noise_sweep(0.35, 0.3, 0.6, 0.08),
		_tone(220, 70, 0.4, Wave.SQUARE, 0.25))])
	s[&"treffer"] = _stream([_mix(_lp(_tone(170, 60, 0.11, Wave.SQUARE, 0.4), 0.3),
		_noise(0.07, 0.35, 0.35))])
	s[&"treffer_fern"] = _stream([_mix(_tone(420, 140, 0.08, Wave.TRIANGLE, 0.4), _noise(0.05, 0.25, 0.5))])
	s[&"pfeil"] = _stream([_noise_sweep(0.14, 0.25, 0.7, 0.2)])
	s[&"krit"] = _stream([_mix(_mix(_lp(_tone(190, 50, 0.16, Wave.SQUARE, 0.45), 0.3),
		_noise(0.1, 0.4, 0.4)), _ring_ton(1480, 0.35, 0.2))])
	s[&"vernichtend"] = _stream([_mix(_mix(_tone(110, 32, 0.55, Wave.SINE, 0.7),
		_noise(0.3, 0.45, 0.2)), _ring_ton(740, 0.5, 0.18))])
	s[&"block"] = _stream([_mix(_mix(_ring_ton(950, 0.28, 0.3), _ring_ton(1430, 0.2, 0.18)),
		_noise(0.04, 0.3, 0.6))])
	# --- Kampf: Magie & Elemente ---
	s[&"zauber"] = _stream([_echo(_tone(320, 980, 0.18, Wave.SINE, 0.35), 0.09, 0.35, 0.35)])
	s[&"magie"] = _stream([_echo(_mix(_tone(600, 300, 0.15, Wave.SINE, 0.35), _noise(0.06, 0.15, 0.4)),
		0.08, 0.3, 0.3)])
	s[&"feuer"] = _stream([_mix(_crackle(0.35, 0.35), _lp(_tone(110, 70, 0.3, Wave.SQUARE, 0.2), 0.15))])
	s[&"eis"] = _stream([_echo(_mix(_ring_ton(1800, 0.25, 0.25), _ring_ton(2420, 0.3, 0.18)),
		0.06, 0.4, 0.4)])
	s[&"blitz"] = _stream([_mix(_tone(1600, 180, 0.12, Wave.SQUARE, 0.3), _noise(0.18, 0.35, 0.9))])
	s[&"gift"] = _stream([_cat([_tone(320, 480, 0.04, Wave.SINE, 0.35), _stille(0.03),
		_tone(260, 420, 0.05, Wave.SINE, 0.3), _stille(0.03), _tone(380, 560, 0.04, Wave.SINE, 0.3)])])
	s[&"heilig"] = _stream([_echo(_mix(_ring_ton(880, 0.6, 0.25), _ring_ton(1320, 0.5, 0.18)),
		0.11, 0.4, 0.4)])
	s[&"dunkel"] = _stream([_echo(_lp(_tone(140, 70, 0.4, Wave.PULSE, 0.3, 0.15), 0.25), 0.13, 0.4, 0.35)])
	s[&"dot"] = _stream([_lp(_tone(300, 200, 0.05, Wave.TRIANGLE, 0.28), 0.5)])
	s[&"heilung"] = _stream([_echo(_cat([_tone(523, 523, 0.07, Wave.SINE, 0.3),
		_tone(659, 659, 0.07, Wave.SINE, 0.3), _tone(784, 784, 0.07, Wave.SINE, 0.3),
		_tone(1047, 1047, 0.16, Wave.SINE, 0.3)]), 0.09, 0.35, 0.4)])
	s[&"buff"] = _stream([_echo(_cat([_tone(440, 440, 0.06, Wave.TRIANGLE, 0.3),
		_tone(554, 554, 0.06, Wave.TRIANGLE, 0.3), _tone(659, 880, 0.12, Wave.TRIANGLE, 0.3)]),
		0.08, 0.3, 0.3)])
	s[&"debuff"] = _stream([_lp(_cat([_tone(415, 415, 0.06, Wave.PULSE, 0.24, 0.25),
		_tone(349, 349, 0.06, Wave.PULSE, 0.24, 0.25), _tone(277, 220, 0.14, Wave.PULSE, 0.24, 0.25)]), 0.4)])
	s[&"schutzwall"] = _stream([_mix(_tone(160, 160, 0.4, Wave.TRIANGLE, 0.3), _ring_ton(640, 0.35, 0.18))])
	s[&"beschwoerung"] = _stream([_echo(_mix(_noise_sweep(0.3, 0.2, 0.1, 0.7),
		_tone(220, 660, 0.35, Wave.SINE, 0.3)), 0.1, 0.35, 0.35)])
	s[&"tod"] = _stream([_mix(_tone(330, 90, 0.45, Wave.TRIANGLE, 0.35), _lp(_noise(0.12, 0.3, 0.2), 0.3))])
	s[&"gegner_besiegt"] = _stream([_mix(_noise_sweep(0.22, 0.3, 0.5, 0.05), _tone(500, 160, 0.16, Wave.SQUARE, 0.18))])
	s[&"wiederbelebung"] = _stream([_echo(_cat([_tone(392, 392, 0.08, Wave.SINE, 0.3),
		_tone(523, 523, 0.08, Wave.SINE, 0.3), _tone(659, 659, 0.08, Wave.SINE, 0.3),
		_tone(784, 784, 0.08, Wave.SINE, 0.3), _tone(1047, 1047, 0.3, Wave.SINE, 0.32)]), 0.1, 0.4, 0.45)])
	s[&"aufladung"] = _stream([_tremolo(_tone(180, 720, 0.7, Wave.PULSE, 0.25, 0.3), 9.0)])
	s[&"entfesselt"] = _stream([_mix(_tone(90, 28, 0.7, Wave.SINE, 0.75), _lp(_noise(0.5, 0.55, 0.15), 0.4))])
	s[&"bannwelle"] = _stream([_echo(_mix(_noise_sweep(0.4, 0.3, 0.05, 0.7), _tone(900, 200, 0.4, Wave.SINE, 0.25)),
		0.1, 0.35, 0.3)])
	s[&"flucht"] = _stream([_noise_sweep(0.3, 0.25, 0.2, 0.6)])
	s[&"sieg"] = _stream([_echo(_cat([_tone(392, 392, 0.09, Wave.PULSE, 0.26, 0.25),
		_tone(523, 523, 0.09, Wave.PULSE, 0.26, 0.25), _tone(659, 659, 0.09, Wave.PULSE, 0.26, 0.25),
		_tone(784, 784, 0.18, Wave.PULSE, 0.26, 0.25), _stille(0.04),
		_akkord([523, 659, 784, 1047], 0.6, Wave.PULSE, 0.13)]), 0.12, 0.3, 0.3)])
	s[&"niederlage"] = _stream([_echo(_lp(_cat([_tone(392, 392, 0.2, Wave.TRIANGLE, 0.32),
		_tone(349, 349, 0.2, Wave.TRIANGLE, 0.32), _tone(311, 311, 0.2, Wave.TRIANGLE, 0.32),
		_tone(262, 196, 0.55, Wave.TRIANGLE, 0.32)]), 0.5), 0.14, 0.35, 0.3)])
	s[&"level_up"] = _stream([_echo(_cat([_tone(523, 523, 0.06, Wave.PULSE, 0.24, 0.125),
		_tone(659, 659, 0.06, Wave.PULSE, 0.24, 0.125), _tone(784, 784, 0.06, Wave.PULSE, 0.24, 0.125),
		_tone(1047, 1047, 0.06, Wave.PULSE, 0.24, 0.125), _akkord([784, 1047, 1319], 0.35, Wave.SINE, 0.16)]),
		0.08, 0.35, 0.4)])
	# --- Dungeon & Beute ---
	s[&"gold"] = _stream([_cat([_ring_ton(1568, 0.06, 0.3), _ring_ton(2093, 0.14, 0.3)])])
	s[&"truhe"] = _stream([_cat([_lp(_tone(140, 120, 0.12, Wave.SQUARE, 0.2), 0.2),
		_echo(_tone(660, 1320, 0.16, Wave.TRIANGLE, 0.3), 0.07, 0.3, 0.3)])])
	s[&"seltener_fund"] = _stream([_echo(_cat([_ring_ton(1047, 0.07, 0.25), _ring_ton(1319, 0.07, 0.25),
		_ring_ton(1568, 0.07, 0.25), _ring_ton(2093, 0.3, 0.25)]), 0.08, 0.45, 0.45)])
	s[&"schatzkarte"] = _stream([_cat([_noise_sweep(0.12, 0.2, 0.3, 0.6),
		_echo(_akkord([659, 988, 1319], 0.4, Wave.SINE, 0.15), 0.09, 0.4, 0.4)])])
	s[&"trank"] = _stream([_cat([_tone(600, 750, 0.06, Wave.SINE, 0.3), _tone(750, 600, 0.06, Wave.SINE, 0.3),
		_tone(500, 800, 0.06, Wave.SINE, 0.3), _tone(640, 980, 0.1, Wave.SINE, 0.3)])])
	s[&"treppe"] = _stream([_cat([_lp(_noise(0.05, 0.3, 0.3), 0.3), _stille(0.09),
		_lp(_noise(0.05, 0.27, 0.25), 0.3), _stille(0.09), _lp(_noise(0.06, 0.24, 0.2), 0.3)])])
	s[&"schrein"] = _stream([_echo(_akkord([523, 659, 784], 0.6, Wave.SINE, 0.16), 0.12, 0.45, 0.45)])
	s[&"opferstein"] = _stream([_mix(_tone(130, 70, 0.6, Wave.SINE, 0.45), _lp(_noise(0.25, 0.15, 0.1), 0.2))])
	s[&"mimic"] = _stream([_mix(_lp(_tone(300, 110, 0.25, Wave.SQUARE, 0.35), 0.3), _noise(0.12, 0.3, 0.4))])
	s[&"schmiede"] = _stream([_mix(_mix(_ring_ton(880, 0.3, 0.3), _ring_ton(1320, 0.22, 0.15)),
		_noise(0.05, 0.35, 0.6))])
	return s


# --- Synthese ------------------------------------------------------------------

func _samples(duration: float) -> int:
	return maxi(1, int(duration * MIX_RATE))


## Ein Ton mit linearem Frequenzverlauf, kurzer Attack- und Ausklang-Hüllkurve.
## duty: Pulsbreite für Wave.PULSE (0.125 = dünn, 0.5 = Rechteck).
func _tone(from_hz: float, to_hz: float, duration: float, wave: Wave,
		volume := 0.5, duty := 0.5) -> PackedFloat32Array:
	var count := _samples(duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += lerpf(from_hz, to_hz, t) / MIX_RATE
		var p := fmod(phase, 1.0)
		var value: float
		match wave:
			Wave.SQUARE:
				value = 1.0 if p < 0.5 else -1.0
			Wave.PULSE:
				value = 1.0 if p < duty else -1.0
			Wave.SINE:
				value = sin(phase * TAU)
			Wave.TRIANGLE:
				value = 4.0 * absf(p - 0.5) - 1.0
			_:
				value = randf() * 2.0 - 1.0
		var attack := minf(1.0, i / (0.004 * MIX_RATE))
		samples[i] = value * attack * pow(1.0 - t, 1.5) * volume
	return samples


## Glocken-/Metallklang: Sinus mit unharmonischem Oberton, langes Ausklingen.
func _ring_ton(hz: float, duration: float, volume: float) -> PackedFloat32Array:
	var count := _samples(duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var zeit := float(i) / MIX_RATE
		var huelle := exp(-5.0 * float(i) / count) * minf(1.0, i / (0.002 * MIX_RATE))
		samples[i] = (sin(TAU * hz * zeit) + 0.4 * sin(TAU * hz * 2.76 * zeit)) * huelle * volume * 0.7
	return samples


## Rauschen mit Tiefpass (helligkeit 0..1: 0 = dumpf, 1 = hell).
func _noise(duration: float, volume: float, helligkeit: float) -> PackedFloat32Array:
	var count := _samples(duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var y := 0.0
	var a := clampf(helligkeit, 0.02, 1.0)
	for i in count:
		y += a * ((randf() * 2.0 - 1.0) - y)
		samples[i] = y * pow(1.0 - float(i) / count, 1.4) * volume * (1.0 + (1.0 - a))
	return samples


## Rauschen, dessen Helligkeit von `von` nach `bis` gleitet (Wischer, Zisch).
func _noise_sweep(duration: float, volume: float, von: float, bis: float) -> PackedFloat32Array:
	var count := _samples(duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var y := 0.0
	for i in count:
		var t := float(i) / count
		var a := clampf(lerpf(von, bis, t), 0.02, 1.0)
		y += a * ((randf() * 2.0 - 1.0) - y)
		var huelle := sin(PI * t)  # an- und abschwellen
		samples[i] = y * huelle * volume * 1.6
	return samples


## Knistern (Feuer): dünne Rauschimpulse in zufälligen Abständen.
func _crackle(duration: float, volume: float) -> PackedFloat32Array:
	var count := _samples(duration)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var y := 0.0
	for i in count:
		var t := float(i) / count
		var impuls := (randf() * 2.0 - 1.0) if randf() < 0.08 else 0.0
		y += 0.5 * (impuls - y)
		samples[i] = (y * 2.0 + (randf() * 2.0 - 1.0) * 0.15) * (1.0 - t) * volume
	return samples


## Akkord aus mehreren Tönen gleichzeitig.
func _akkord(freqs: Array, duration: float, wave: Wave, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in freqs:
		out = _mix(out, _tone(f, f, duration, wave, volume, 0.25))
	return out


func _stille(duration: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(_samples(duration))
	return samples


## Einfacher Tiefpass (staerke 0..1: kleiner = dumpfer) — nimmt die Härte.
func _lp(samples: PackedFloat32Array, staerke: float) -> PackedFloat32Array:
	var out := samples.duplicate()
	var y := 0.0
	for i in out.size():
		y += staerke * (out[i] - y)
		out[i] = y
	return out


## Echo: verzögerte, leisere Kopien (verlängert den Klang um die Fahnen).
func _echo(samples: PackedFloat32Array, delay: float, feedback: float, anteil: float) -> PackedFloat32Array:
	var d := _samples(delay)
	var out := samples.duplicate()
	out.resize(samples.size() + d * 4)
	for i in range(d, out.size()):
		out[i] += out[i - d] * feedback * (anteil / 0.35)
	for i in out.size():
		out[i] = clampf(out[i], -1.0, 1.0)
	return out


## Lautstärke-Zittern (Spannungsaufbau).
func _tremolo(samples: PackedFloat32Array, hz: float) -> PackedFloat32Array:
	var out := samples.duplicate()
	for i in out.size():
		out[i] *= 0.65 + 0.35 * sin(TAU * hz * float(i) / MIX_RATE)
	return out


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


## Teilstücke hintereinander hängen.
func _cat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for part in parts:
		out.append_array(part)
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
