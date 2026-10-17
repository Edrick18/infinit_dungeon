extends Node
## Autoload "Music": prozedural komponierte Musik — wie die SFX komplett ohne
## Audio-Assets. Jeder Track ist eine kleine Partitur (Tonart, Modus,
## Akkordfolgen für Teil A und B, Form wie "AABA", Instrumente, Schlagzeug).
## Die Melodie entsteht aus einem Motiv (fester Seed), das über die Akkorde
## wandert und am Phrasenende auf dem Grundton landet. Gerendert wird in
## Stereo mit Pad, Bass, Arpeggio, Lead, Schlagzeug, Raumhall und Echo.
##
## Die Tracks werden beim Start in einem Hintergrund-Thread gerendert —
## jeder ist sofort spielbar, sobald er fertig ist (Menü zuerst).
##
## Nutzung: Music.play(&"menu"|&"stadt"|&"wald"|&"hoehle"|&"ruinen"|
## &"krypta"|&"kampf"|&"boss"|&"sieg"|&"niederlage").
## Derselbe Track läuft über Szenenwechsel einfach weiter (Autoload).

const MIX_RATE := 22050
const FADE_TIME := 0.9
const SILENT_DB := -50.0
const BUS := &"Musik"
const HALL_RUECKLAUF := 0.78
const HALL_DAEMPFUNG := 0.45

## Modi als Halbtonschritte ab Grundton.
const MODI := {
	"dur": [0, 2, 4, 5, 7, 9, 11],
	"moll": [0, 2, 3, 5, 7, 8, 10],
	"harmonisch": [0, 2, 3, 5, 7, 8, 11],
	"dorisch": [0, 2, 3, 5, 7, 9, 10],
	"phrygisch": [0, 1, 3, 5, 7, 8, 10],
	"lydisch": [0, 2, 4, 6, 7, 9, 11],
}

## Rhythmus-Bausteine für Melodie-Motive: je Takt (16 Sechzehntel) eine
## Liste [Start, Dauer] in Sechzehnteln.
const RHYTHMEN := {
	"ruhig": [[[0, 6], [6, 2], [8, 8]], [[0, 4], [4, 4], [8, 6], [14, 2]], [[0, 12], [12, 4]]],
	"lied": [[[0, 4], [4, 2], [6, 2], [8, 4], [12, 4]], [[0, 3], [3, 3], [6, 2], [8, 8]],
		[[0, 2], [2, 2], [4, 4], [8, 2], [10, 2], [12, 4]]],
	"treibend": [[[0, 2], [2, 2], [4, 2], [6, 2], [8, 3], [11, 3], [14, 2]],
		[[0, 3], [3, 3], [6, 2], [8, 2], [10, 2], [12, 4]], [[0, 4], [4, 2], [6, 2], [8, 8]]],
}

## Partituren. Akkorde = Stufen der Tonleiter (0 = Tonika). Mit "7" am Ende
## als String ("4.7") kommt die Septime dazu.
const PARTITUREN := {
	# Hauptmenü: ruhige, offene Moll-Ballade, Pad + Harfen-Arpeggio + Flöte.
	&"menu": {"bpm": 72, "grund": 57, "modus": "moll", "seed": 11, "form": "AB",
		"A": [0, 5, 2, 6, 0, 5, 3, 4], "B": [5, 6, 0, 0, 3, 4, 0, 0],
		"lead": "floete", "rhythmus": "ruhig", "pad": 0.10, "arp": 2, "arp_klang": "harfe",
		"bass": "ganz", "drums": "", "lead_gain": 0.11},
	# Stadt: freundliches Dur, wandernder Bass, leichtes Schlagzeug.
	&"stadt": {"bpm": 108, "grund": 60, "modus": "dur", "seed": 23, "form": "AABA",
		"A": [0, 3, 4, 0, 5, 3, 4, 0], "B": [3, 3, 0, 5, 1, 4, 4, 4],
		"lead": "puls", "rhythmus": "lied", "pad": 0.06, "arp": 0, "bass": "wandernd",
		"drums": "leicht", "lead_gain": 0.10},
	# Wald: dorisch — hell und verhalten, Abenteuer am Anfang.
	&"wald": {"bpm": 84, "grund": 55, "modus": "dorisch", "seed": 31, "form": "AB",
		"A": [0, 3, 0, 6, 0, 3, 4, 0], "B": [5, 6, 0, 3, 5, 6, 4, 4],
		"lead": "floete", "rhythmus": "lied", "pad": 0.08, "arp": 2, "arp_klang": "harfe",
		"bass": "halb", "drums": "hand", "lead_gain": 0.10},
	# Höhle: tief, viel Hall, Tropfen-Arpeggio, kaum Melodie.
	&"hoehle": {"bpm": 64, "grund": 50, "modus": "moll", "seed": 47, "form": "AB",
		"A": [0, 0, 5, 5, 3, 3, 4, 4], "B": [0, 6, 5, 4, 0, 6, 5, 4],
		"lead": "glocke", "rhythmus": "ruhig", "pad": 0.11, "arp": 4, "arp_klang": "tropfen",
		"bass": "ganz", "drums": "", "lead_gain": 0.08, "hall": 0.5, "lead_nur": "B"},
	# Ruinen: phrygisch, geheimnisvoll, gemessener Trommelschlag.
	&"ruinen": {"bpm": 76, "grund": 52, "modus": "phrygisch", "seed": 59, "form": "AB",
		"A": [0, 1, 0, 6, 0, 1, 5, 6], "B": [3, 1, 0, 0, 5, 6, 1, 0],
		"lead": "rohr", "rhythmus": "ruhig", "pad": 0.09, "arp": 0, "bass": "halb",
		"drums": "ritual", "lead_gain": 0.10, "hall": 0.4},
	# Krypta: harmonisches Moll, Orgel-Pad, langsam und schwer.
	&"krypta": {"bpm": 60, "grund": 50, "modus": "harmonisch", "seed": 67, "form": "AB",
		"A": [0, 5, 3, "4.7", 0, 5, 1, "4.7"], "B": [5, 3, 0, 4, 5, 1, "4.7", 0],
		"lead": "glocke", "rhythmus": "ruhig", "pad": 0.12, "pad_klang": "orgel", "arp": 0,
		"bass": "ganz", "drums": "", "lead_gain": 0.08, "hall": 0.55},
	# Kampf: treibende Achtel, Moll mit Dur-Dominante, volles Schlagzeug.
	&"kampf": {"bpm": 138, "grund": 57, "modus": "harmonisch", "seed": 79, "form": "AABA",
		"A": [0, 0, 5, 5, 3, 3, "4.7", "4.7"], "B": [5, 6, 2, 5, 3, 1, "4.7", "4.7"],
		"lead": "puls", "rhythmus": "treibend", "pad": 0.05, "arp": 2, "arp_klang": "puls",
		"bass": "achtel", "drums": "kampf", "lead_gain": 0.10},
	# Boss: schneller, tiefer, Halbton-Spannung, schwerer Kick.
	&"boss": {"bpm": 150, "grund": 50, "modus": "harmonisch", "seed": 97, "form": "AABA",
		"A": [0, 1, 0, 1, 5, 4, 0, "4.7"], "B": [5, 5, 1, 1, 3, 3, "4.7", "4.7"],
		"lead": "saege", "rhythmus": "treibend", "pad": 0.07, "pad_klang": "orgel", "arp": 1,
		"arp_klang": "puls", "bass": "oktave", "drums": "boss", "lead_gain": 0.10},
}

var enabled := true

var _tracks: Dictionary = {}
var _current: StringName = &""
var _thread: Thread
var _player_a: AudioStreamPlayer
var _player_b: AudioStreamPlayer
var _use_a := true
var _fade_a: Tween
var _fade_b: Tween
var _abbrechen := false
## Beim Rendern: Sample, an dem der Loop neu beginnt (ein Intro davor wird
## beim Überlauf am Ende übersprungen).
var _loop_anfang := 0


func _ready() -> void:
	# Eigener Bus "Musik" (Lautstärke in den Optionen), an den Master geroutet.
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
	var settings := get_node_or_null(^"/root/Settings")
	if settings != null:
		settings.apply_music_volume()
	_player_a = _make_player()
	_player_b = _make_player()
	_thread = Thread.new()
	_thread.start(_render_all)


func _exit_tree() -> void:
	_abbrechen = true
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _make_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = BUS
	player.volume_db = SILENT_DB
	add_child(player)
	return player


## Track wechseln (weicher Crossfade). Gleicher Track = weiterlaufen lassen.
## Noch nicht gerenderte Tracks starten automatisch, sobald sie fertig sind.
func play(track: StringName, fade := FADE_TIME) -> void:
	if not enabled or track == _current:
		return
	_current = track
	if not _tracks.has(track):
		_fade_out(_aktiver_player(), fade)
		return
	var incoming := _player_b if _use_a else _player_a
	var outgoing := _player_a if _use_a else _player_b
	_use_a = not _use_a
	incoming.stream = _tracks[track]
	incoming.volume_db = SILENT_DB
	incoming.play()
	_tween_setzen(incoming, create_tween())
	_tween_von(incoming).tween_property(incoming, "volume_db", 0.0, fade) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade_out(outgoing, fade)


func stop() -> void:
	_current = &""
	_fade_out(_player_a)
	_fade_out(_player_b)


func current() -> StringName:
	return _current


## Track für ein Biom (Enums.Biome) — fällt auf "wald" zurück.
static func biom_track(biome: int) -> StringName:
	match biome:
		Enums.Biome.CAVE:
			return &"hoehle"
		Enums.Biome.RUINS:
			return &"ruinen"
		Enums.Biome.CRYPT:
			return &"krypta"
	return &"wald"


func _aktiver_player() -> AudioStreamPlayer:
	return _player_a if not _use_a else _player_b


func _tween_setzen(player: AudioStreamPlayer, tween: Tween) -> void:
	var alt := _fade_a if player == _player_a else _fade_b
	if alt != null and alt.is_valid():
		alt.kill()
	if player == _player_a:
		_fade_a = tween
	else:
		_fade_b = tween


func _tween_von(player: AudioStreamPlayer) -> Tween:
	return _fade_a if player == _player_a else _fade_b


func _fade_out(player: AudioStreamPlayer, fade := FADE_TIME) -> void:
	if not player.playing:
		return
	_tween_setzen(player, create_tween())
	var tween := _tween_von(player)
	tween.tween_property(player, "volume_db", SILENT_DB, fade)
	tween.tween_callback(player.stop)


# --- Rendern (Hintergrund-Thread) ---------------------------------------------

## Reihenfolge = Wichtigkeit: was beim Start zuerst gebraucht wird, zuerst.
const RENDER_REIHENFOLGE: Array[StringName] = [&"menu", &"stadt", &"wald", &"kampf",
	&"sieg", &"niederlage", &"hoehle", &"ruinen", &"krypta", &"boss"]


func _render_all() -> void:
	for name in RENDER_REIHENFOLGE:
		if _abbrechen:
			return
		var stream: AudioStreamWAV
		if name == &"sieg":
			stream = render_sieg()
		elif name == &"niederlage":
			stream = render_niederlage()
		else:
			stream = render_partitur(PARTITUREN[name])
		call_deferred("_on_rendered", name, stream)


func _on_rendered(name: StringName, stream: AudioStreamWAV) -> void:
	_tracks[name] = stream
	if _current == name:
		_current = &""  # play() soll den Wechsel wirklich ausführen
		play(name)


# --- Komposition ----------------------------------------------------------------

static func _midi(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


## Ton einer Tonleiterstufe (darf negativ/über 6 sein — Oktaven werden umgerechnet).
static func _stufe(grund: int, leiter: Array, stufe: int) -> int:
	var oktave := floori(stufe / 7.0)
	return grund + leiter[posmod(stufe, 7)] + 12 * oktave


## Akkord-Angabe (int oder "4.7") » [Stufe, mit Septime].
static func _akkord_info(eintrag: Variant) -> Array:
	if eintrag is String:
		var teile: PackedStringArray = (eintrag as String).split(".")
		return [int(teile[0]), teile.size() > 1]
	return [int(eintrag), false]


## Rendert eine komplette Partitur zu einem nahtlosen Stereo-Loop.
func render_partitur(p: Dictionary) -> AudioStreamWAV:
	var bpm := float(p["bpm"])
	var sechzehntel := 60.0 / bpm / 4.0
	var leiter: Array = MODI[p["modus"]]
	var grund := int(p["grund"])
	var takte: Array = []
	for teil in String(p["form"]):
		takte.append_array(p[teil])
	var n := int(takte.size() * 16 * sechzehntel * MIX_RATE)
	var trocken := PackedFloat32Array()
	trocken.resize(n)
	var hall_send := PackedFloat32Array()
	hall_send.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p["seed"])
	var teile: Array[String] = []
	var motive := {}
	for teil in String(p["form"]):
		for k in (p[teil] as Array).size():
			teile.append(teil)
		if not motive.has(teil):
			motive[teil] = _motiv_bauen(rng, p)
	var cache := {}
	_loop_anfang = 0

	for t in takte.size():
		var info := _akkord_info(takte[t])
		var stufe: int = info[0]
		var akkord: Array[int] = []
		for k in [0, 2, 4]:
			akkord.append(_stufe(grund, leiter, stufe + k))
		if info[1]:
			akkord.append(_stufe(grund, leiter, stufe + 6))
		var t0 := t * 16 * sechzehntel
		var takt_dauer := 16 * sechzehntel
		# Pad: Akkord als langer, weicher Klangteppich.
		if float(p.get("pad", 0.0)) > 0.0:
			for ton in akkord:
				_note(trocken, hall_send, cache, String(p.get("pad_klang", "pad")), ton, t0,
					takt_dauer * 1.02, float(p["pad"]) * 0.55, 0.6)
		# Bass
		_bass(trocken, hall_send, cache, p, akkord, t0, sechzehntel)
		# Arpeggio
		var arp := int(p.get("arp", 0))
		if arp > 0:
			var klang := String(p.get("arp_klang", "harfe"))
			var abstand := arp
			var schritte := 16 / arp
			var ton_reihe: Array[int] = []
			for ton in akkord:
				ton_reihe.append(ton + 12)
			ton_reihe.append(akkord[0] + 24)
			for s in schritte:
				var ton: int = ton_reihe[(s if (t % 2 == 0) else schritte - 1 - s) % ton_reihe.size()]
				if klang == "tropfen":
					ton = akkord[rng.randi_range(0, akkord.size() - 1)] + 24
					if rng.randf() < 0.4:
						continue
				_note(trocken, hall_send, cache, klang, ton, t0 + s * abstand * sechzehntel,
					abstand * sechzehntel * 0.9, 0.055, 0.5)
		# Melodie: Motiv über den Akkord gelegt; letzte zwei Takte jeder
		# Achter-Gruppe kadenzieren auf Grundton/Terz.
		var phrase_pos := t % 8
		var motiv: Array = motive[teile[t]]
		var motiv_takt: Array = motiv[phrase_pos % motiv.size()]
		if String(p.get("lead_nur", "")) != "" and not String(p["lead_nur"]).contains(teile[t]):
			motiv_takt = []
		for note in motiv_takt:
			var start: int = note[0]
			var dauer: int = note[1]
			var versatz: int = note[2]
			var ton := _stufe(grund + 12, leiter, stufe + versatz)
			# Melodie bleibt in einer singbaren Lage.
			while ton > grund + 26:
				ton -= 12
			while ton < grund + 7:
				ton += 12
			_note(trocken, hall_send, cache, String(p["lead"]), ton, t0 + start * sechzehntel,
				dauer * sechzehntel * 0.95, float(p.get("lead_gain", 0.1)), 0.45)
		# Schlagzeug
		_drums(trocken, hall_send, String(p.get("drums", "")), t0, sechzehntel, t)

	return _mastern(trocken, hall_send, sechzehntel, float(p.get("hall", 0.3)), 0)


## Ein Motiv = 8 Takte mit [Start, Dauer, Stufen-Versatz zum Akkord-Grundton].
## Takt 1–2 sind das Kernmotiv, 3–4 eine Variation, 5–6 wiederholen es,
## 7–8 schließen ab — klassische Periode, damit es nach Melodie klingt.
func _motiv_bauen(rng: RandomNumberGenerator, p: Dictionary) -> Array:
	var rhythmen: Array = RHYTHMEN[String(p.get("rhythmus", "lied"))]
	var kern: Array = []
	for i in 2:
		kern.append(_motiv_takt(rng, rhythmen[rng.randi_range(0, rhythmen.size() - 1)]))
	var variation: Array = []
	for takt in kern:
		var neu: Array = []
		for note in takt:
			var v: int = note[2]
			if rng.randf() < 0.45:
				v += [-1, 1, 2][rng.randi_range(0, 2)]
			neu.append([note[0], note[1], v])
		variation.append(neu)
	var schluss: Array = [_motiv_takt(rng, rhythmen[0]), [[0, 8, 2], [8, 8, 0]]]
	return [kern[0], kern[1], variation[0], variation[1], kern[0], kern[1], schluss[0], schluss[1]]


func _motiv_takt(rng: RandomNumberGenerator, rhythmus: Array) -> Array:
	var takt: Array = []
	var letzter: int = [0, 2, 4][rng.randi_range(0, 2)]
	for schlag in rhythmus:
		var start: int = schlag[0]
		var v: int
		if start % 4 == 0:
			# Betonte Zählzeit: Akkordton nahe am vorherigen Ton.
			var kandidaten := [0, 2, 4, 7, -3]
			kandidaten.sort_custom(func(a, b): return absi(a - letzter) < absi(b - letzter))
			v = kandidaten[mini(rng.randi_range(0, 2), kandidaten.size() - 1)]
		else:
			# Unbetont: Schritt nach oben oder unten (Durchgangston).
			v = letzter + (1 if rng.randf() < 0.5 else -1)
		takt.append([start, schlag[1], v])
		letzter = v
	return takt


## Basslage: Ton in den Bereich 33..44 (A1..G#2) schieben.
static func _bass_lage(ton: int) -> int:
	while ton > 44:
		ton -= 12
	while ton < 33:
		ton += 12
	return ton


func _bass(daten: PackedFloat32Array, send: PackedFloat32Array, cache: Dictionary, p: Dictionary,
		akkord: Array[int], t0: float, s: float) -> void:
	var tief := _bass_lage(akkord[0])
	match String(p.get("bass", "ganz")):
		"ganz":
			_note(daten, send, cache, "bass", tief, t0, 16 * s * 0.98, 0.22, 0.1)
		"halb":
			_note(daten, send, cache, "bass", tief, t0, 8 * s * 0.95, 0.22, 0.1)
			_note(daten, send, cache, "bass", _bass_lage(akkord[2]), t0 + 8 * s, 8 * s * 0.95, 0.2, 0.1)
		"wandernd":
			var toene := [tief, _bass_lage(akkord[1]), _bass_lage(akkord[2]), tief + 12]
			for i in 4:
				_note(daten, send, cache, "bass", toene[i], t0 + i * 4 * s, 4 * s * 0.85, 0.2, 0.1)
		"achtel":
			for i in 8:
				var ton := tief + (12 if i % 4 == 3 else 0)
				_note(daten, send, cache, "bass_kurz", ton, t0 + i * 2 * s, 2 * s * 0.8, 0.2, 0.05)
		"oktave":
			for i in 8:
				_note(daten, send, cache, "bass_kurz", tief + (12 if i % 2 == 1 else 0), t0 + i * 2 * s,
					2 * s * 0.8, 0.21, 0.05)


func _drums(daten: PackedFloat32Array, send: PackedFloat32Array, stil: String, t0: float, s: float,
		takt: int) -> void:
	if stil == "":
		return
	var fill := takt % 8 == 7  # letzter Takt einer Phrase: Fill
	for step in 16:
		var t := t0 + step * s
		match stil:
			"leicht":
				if step % 8 == 0:
					_kick(daten, t, 0.22)
				if step % 8 == 4:
					_snare(daten, send, t, 0.10, 0.4)
				if step % 2 == 0:
					_hat(daten, t, 0.035 if step % 4 == 0 else 0.022)
			"hand":
				# Handtrommel: tiefer Schlag auf 1 und 3, leichte Klopfer dazwischen.
				if step == 0 or step == 10:
					_tom(daten, send, t, 110.0, 0.18)
				elif step == 6 or step == 14 or (fill and step >= 12):
					_tom(daten, send, t, 180.0, 0.1)
			"ritual":
				if step == 0:
					_tom(daten, send, t, 70.0, 0.28)
				if step == 8 and takt % 2 == 1:
					_tom(daten, send, t, 95.0, 0.2)
				if fill and step >= 12 and step % 2 == 0:
					_tom(daten, send, t, 120.0, 0.14)
			"kampf":
				if step % 8 == 0 or step == 10:
					_kick(daten, t, 0.28)
				if step % 8 == 4:
					_snare(daten, send, t, 0.16, 0.5)
				if step % 2 == 0:
					_hat(daten, t, 0.04 if step % 4 == 2 else 0.025)
				if fill and step >= 12:
					_snare(daten, send, t, 0.08 + 0.02 * (step - 12), 0.5)
			"boss":
				if step % 4 == 0 or step == 14:
					_kick(daten, t, 0.32)
				if step % 8 == 4:
					_snare(daten, send, t, 0.17, 0.55)
				_hat(daten, t, 0.03 if step % 2 == 0 else 0.017)
				if fill and step >= 8 and step % 2 == 0:
					_tom(daten, send, t, 200.0 - 12.0 * (step - 8), 0.16)
				if takt == 0 and step == 0:
					_becken(daten, send, t, 0.12)


# --- Instrumente ----------------------------------------------------------------

## Note additiv einmischen. Gleiche Noten werden einmal synthetisiert und dann
## aus dem Cache kopiert. Über das Ende hinaus klingende Noten laufen am
## Anfang weiter — der Loop bleibt nahtlos.
func _note(daten: PackedFloat32Array, send: PackedFloat32Array, cache: Dictionary, klang: String,
		midi: int, t0: float, dauer: float, gain: float, hall: float) -> void:
	var schluessel := "%s|%d|%d" % [klang, midi, int(dauer * 1000)]
	var samples: PackedFloat32Array = cache.get(schluessel, PackedFloat32Array())
	if samples.is_empty():
		samples = _instrument(klang, _midi(midi), dauer)
		cache[schluessel] = samples
	var start := int(t0 * MIX_RATE)
	var n := daten.size()
	for i in samples.size():
		var idx := start + i
		if idx >= n:
			idx = _loop_anfang + (idx - n) % (n - _loop_anfang)
		var v := samples[i] * gain
		daten[idx] += v
		send[idx] += v * hall


func _instrument(klang: String, f: float, dauer: float) -> PackedFloat32Array:
	var ausklang := 0.25
	match klang:
		"pad", "orgel":
			ausklang = 0.6
		"harfe", "tropfen", "glocke":
			ausklang = 0.9
	var n := int((dauer + ausklang) * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var halte := int(dauer * MIX_RATE)
	var phase := 0.0
	var phase2 := 0.0
	var lp := 0.0
	for i in n:
		var zeit := float(i) / MIX_RATE
		var vib := 1.0
		if (klang == "floete" or klang == "rohr" or klang == "saege") and zeit > 0.18:
			vib = 1.0 + 0.004 * sin(TAU * 5.2 * zeit)
		phase += f * vib / MIX_RATE
		phase2 += f * 1.006 / MIX_RATE
		var p := fmod(phase, 1.0)
		var w: float
		var huelle: float
		match klang:
			"pad":
				w = (sin(TAU * phase) + sin(TAU * phase2) * 0.8 + (4.0 * absf(p - 0.5) - 1.0) * 0.3) * 0.5
				huelle = minf(1.0, zeit / 0.35)
			"orgel":
				w = (sin(TAU * phase) + 0.5 * sin(TAU * phase * 2.0) + 0.25 * sin(TAU * phase * 3.0)
					+ 0.6 * sin(TAU * phase2)) * 0.4
				huelle = minf(1.0, zeit / 0.12)
			"floete":
				w = sin(TAU * phase) + 0.15 * sin(TAU * phase * 2.0) + (randf() - 0.5) * 0.04
				huelle = minf(1.0, zeit / 0.06) * (1.0 - 0.25 * minf(1.0, zeit / maxf(dauer, 0.01)))
			"rohr":
				w = (1.0 if p < 0.3 else -1.0) * 0.6
				huelle = minf(1.0, zeit / 0.04) * (1.0 - 0.3 * minf(1.0, zeit / maxf(dauer, 0.01)))
			"puls":
				w = (1.0 if p < 0.25 else -1.0) * 0.55
				huelle = minf(1.0, zeit / 0.006) * (0.75 + 0.25 * exp(-zeit * 8.0))
			"saege":
				w = ((p * 2.0 - 1.0) + (fmod(phase2, 1.0) * 2.0 - 1.0)) * 0.35
				huelle = minf(1.0, zeit / 0.01) * (0.7 + 0.3 * exp(-zeit * 6.0))
			"harfe":
				w = sin(TAU * phase) + 0.3 * sin(TAU * phase * 2.0) * exp(-zeit * 6.0)
				huelle = minf(1.0, zeit / 0.003) * exp(-zeit * 3.2)
			"tropfen":
				w = sin(TAU * phase * (1.0 + 0.5 * exp(-zeit * 40.0)))
				huelle = minf(1.0, zeit / 0.002) * exp(-zeit * 5.0)
			"glocke":
				w = sin(TAU * phase) + 0.45 * sin(TAU * phase * 2.76) * exp(-zeit * 3.0) \
					+ 0.2 * sin(TAU * phase * 5.4) * exp(-zeit * 6.0)
				huelle = minf(1.0, zeit / 0.003) * exp(-zeit * 1.6)
			"bass":
				w = (4.0 * absf(p - 0.5) - 1.0) + 0.35 * sin(TAU * phase)
				huelle = minf(1.0, zeit / 0.01)
			"bass_kurz":
				w = (4.0 * absf(p - 0.5) - 1.0) + 0.4 * (1.0 if p < 0.5 else -1.0) * exp(-zeit * 20.0)
				huelle = minf(1.0, zeit / 0.004) * exp(-zeit * 4.0)
			_:
				w = sin(TAU * phase)
				huelle = 1.0
		if i > halte:
			huelle *= maxf(0.0, 1.0 - float(i - halte) / (ausklang * MIX_RATE))
		# Sanfter Tiefpass gegen Härte (Pulse/Sägen klingen sonst schrill).
		lp += 0.35 * (w - lp)
		out[i] = lp * huelle
	return out


func _kick(daten: PackedFloat32Array, t0: float, gain: float) -> void:
	var start := int(t0 * MIX_RATE)
	var n := int(0.16 * MIX_RATE)
	var phase := 0.0
	for i in n:
		var p := float(i) / n
		phase += lerpf(130.0, 38.0, sqrt(p)) / MIX_RATE
		daten[(start + i) % daten.size()] += sin(phase * TAU) * gain * (1.0 - p) * (1.0 - p)


func _snare(daten: PackedFloat32Array, send: PackedFloat32Array, t0: float, gain: float, hall: float) -> void:
	var start := int(t0 * MIX_RATE)
	var n := int(0.14 * MIX_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = start
	var y := 0.0
	var phase := 0.0
	for i in n:
		var p := float(i) / n
		y += 0.6 * (rng.randf_range(-1.0, 1.0) - y)
		phase += 190.0 / MIX_RATE
		var v := (y * 0.9 + sin(phase * TAU) * 0.5 * (1.0 - p)) * gain * pow(1.0 - p, 2.0)
		var idx := (start + i) % daten.size()
		daten[idx] += v
		send[idx] += v * hall


func _hat(daten: PackedFloat32Array, t0: float, gain: float) -> void:
	var start := int(t0 * MIX_RATE)
	var n := int(0.035 * MIX_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = start + 7
	var vorher := 0.0
	for i in n:
		var r := rng.randf_range(-1.0, 1.0)
		var hp := r - vorher  # Hochpass: nur das Zischen
		vorher = r
		daten[(start + i) % daten.size()] += hp * gain * (1.0 - float(i) / n)


func _tom(daten: PackedFloat32Array, send: PackedFloat32Array, t0: float, hz: float, gain: float) -> void:
	var start := int(t0 * MIX_RATE)
	var n := int(0.3 * MIX_RATE)
	var phase := 0.0
	for i in n:
		var p := float(i) / n
		phase += hz * (1.0 - 0.35 * p) / MIX_RATE
		var v := sin(phase * TAU) * gain * exp(-p * 5.0)
		var idx := (start + i) % daten.size()
		daten[idx] += v
		send[idx] += v * 0.5


func _becken(daten: PackedFloat32Array, send: PackedFloat32Array, t0: float, gain: float) -> void:
	var start := int(t0 * MIX_RATE)
	var n := int(1.2 * MIX_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = start + 3
	var vorher := 0.0
	for i in n:
		var r := rng.randf_range(-1.0, 1.0)
		var v := (r - vorher) * gain * exp(-float(i) / n * 4.0)
		vorher = r
		var idx := (start + i) % daten.size()
		daten[idx] += v
		send[idx] += v * 0.4


# --- Mastering: Hall, Echo, Stereo, Begrenzer ------------------------------------

## Raumhall (zwei Kammfilter je Kanal) + punktiertes Achtel-Echo im Wechsel
## links/rechts. Läuft zweimal über den Puffer, damit der Hall am Loop-Ende
## sauber in den Anfang übergeht. loop_begin > 0: Intro (z.B. Fanfare) wird
## nicht wiederholt, nur der Teil danach.
func _mastern(trocken: PackedFloat32Array, send: PackedFloat32Array, sechzehntel: float,
		hall: float, loop_begin: int) -> AudioStreamWAV:
	var n := trocken.size()
	var links := trocken.duplicate()
	var rechts := trocken.duplicate()
	var b0 := PackedFloat32Array()
	b0.resize(int(0.0297 * MIX_RATE))
	var b1 := PackedFloat32Array()
	b1.resize(int(0.0371 * MIX_RATE))
	var b2 := PackedFloat32Array()
	b2.resize(int(0.0411 * MIX_RATE))
	var b3 := PackedFloat32Array()
	b3.resize(int(0.0437 * MIX_RATE))
	var echo := int(sechzehntel * 3.0 * MIX_RATE)
	var echo_l := PackedFloat32Array()
	echo_l.resize(echo)
	var echo_r := PackedFloat32Array()
	echo_r.resize(echo)
	var p0 := 0
	var p1 := 0
	var p2 := 0
	var p3 := 0
	var ep := 0
	var f0 := 0.0
	var f1 := 0.0
	var f2 := 0.0
	var f3 := 0.0
	var nass := hall * 0.5
	# Vorlauf: die letzten Sekunden einmal durchschicken, damit Hall und Echo
	# am Loop-Anfang schon so klingen wie am Ende (nahtloser Übergang).
	var vorlauf := mini(n, int(4.0 * MIX_RATE)) if loop_begin == 0 else 0
	for k in range(-vorlauf, n):
		var i := k if k >= 0 else k + n
		var x := send[i]
		var y0 := b0[p0]
		var y1 := b1[p1]
		var y2 := b2[p2]
		var y3 := b3[p3]
		f0 += HALL_DAEMPFUNG * (y0 - f0)
		f1 += HALL_DAEMPFUNG * (y1 - f1)
		f2 += HALL_DAEMPFUNG * (y2 - f2)
		f3 += HALL_DAEMPFUNG * (y3 - f3)
		b0[p0] = x + f0 * HALL_RUECKLAUF
		b1[p1] = x + f1 * HALL_RUECKLAUF
		b2[p2] = x + f2 * HALL_RUECKLAUF
		b3[p3] = x + f3 * HALL_RUECKLAUF
		p0 = (p0 + 1) % b0.size()
		p1 = (p1 + 1) % b1.size()
		p2 = (p2 + 1) % b2.size()
		p3 = (p3 + 1) % b3.size()
		# Ping-Pong-Echo: links speist rechts und umgekehrt.
		var el := echo_l[ep]
		var er := echo_r[ep]
		echo_l[ep] = x * 0.5 + er * 0.35
		echo_r[ep] = el * 0.8
		ep = (ep + 1) % echo
		if k >= 0:
			links[i] += (y0 + y2) * nass + el * 0.3
			rechts[i] += (y1 + y3) * nass + er * 0.3
	# Mit Intro: Hall-/Echo-Ausklang vom Loop-Ende an den Loop-Anfang legen,
	# sonst bricht er beim Zurückspringen hart ab.
	if loop_begin > 0:
		var ausklang := mini(n - loop_begin, int(1.5 * MIX_RATE))
		for j in ausklang:
			var y0 := b0[p0]
			var y1 := b1[p1]
			var y2 := b2[p2]
			var y3 := b3[p3]
			f0 += HALL_DAEMPFUNG * (y0 - f0)
			f1 += HALL_DAEMPFUNG * (y1 - f1)
			f2 += HALL_DAEMPFUNG * (y2 - f2)
			f3 += HALL_DAEMPFUNG * (y3 - f3)
			b0[p0] = f0 * HALL_RUECKLAUF
			b1[p1] = f1 * HALL_RUECKLAUF
			b2[p2] = f2 * HALL_RUECKLAUF
			b3[p3] = f3 * HALL_RUECKLAUF
			p0 = (p0 + 1) % b0.size()
			p1 = (p1 + 1) % b1.size()
			p2 = (p2 + 1) % b2.size()
			p3 = (p3 + 1) % b3.size()
			var el := echo_l[ep]
			var er := echo_r[ep]
			echo_l[ep] = er * 0.35
			echo_r[ep] = el * 0.8
			ep = (ep + 1) % echo
			links[loop_begin + j] += (y0 + y2) * nass + el * 0.3
			rechts[loop_begin + j] += (y1 + y3) * nass + er * 0.3
	# Sanfter Begrenzer + Ausgabe als 16-Bit-Stereo. Spitze auf ~-3 dB, damit
	# die Musik unter den Effekten liegt.
	var spitze := 0.001
	for i in n:
		spitze = maxf(spitze, maxf(absf(links[i]), absf(rechts[i])))
	var vor := clampf(0.7 / spitze, 0.4, 2.5)
	var bytes := PackedByteArray()
	bytes.resize(n * 4)
	for i in n:
		bytes.encode_s16(i * 4, int(_weich(links[i] * vor) * 30000.0))
		bytes.encode_s16(i * 4 + 2, int(_weich(rechts[i] * vor) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = true
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = loop_begin
	wav.loop_end = n
	return wav


static func _weich(x: float) -> float:
	# Weiche Sättigung statt hartem Clipping.
	if x > 1.0:
		return 1.0
	if x < -1.0:
		return -1.0
	return x * (1.5 - 0.5 * x * x)


# --- Sieg und Niederlage ---------------------------------------------------------

## Sieg: Fanfare (einmal) + ruhige Dur-Schleife für den Ergebnis-Bildschirm.
func render_sieg() -> AudioStreamWAV:
	var bpm := 120.0
	var s := 60.0 / bpm / 4.0
	var takte_intro := 2
	var takte_loop := 8
	var n := int((takte_intro + takte_loop) * 16 * s * MIX_RATE)
	var daten := PackedFloat32Array()
	daten.resize(n)
	var send := PackedFloat32Array()
	send.resize(n)
	var cache := {}
	_loop_anfang = int(takte_intro * 16 * s * MIX_RATE)
	# Fanfare: drei kurze Stöße + langer Akkord (klassischer Sieges-Ruf).
	var fanfare := [[0, 1, 72], [1, 1, 72], [2, 1, 72], [3, 3, 72], [6, 2, 68], [8, 2, 70],
		[10, 2, 72], [12, 1, 70], [13, 3, 72]]
	for f in fanfare:
		_note(daten, send, cache, "puls", f[2], f[0] * s, f[1] * s * 0.9, 0.13, 0.4)
		_note(daten, send, cache, "puls", f[2] - 5 if f[2] != 72 else 67, f[0] * s, f[1] * s * 0.9, 0.07, 0.4)
	for ton in [60, 64, 67, 72]:
		_note(daten, send, cache, "pad", ton, 16 * s, 14 * s, 0.07, 0.6)
	_kick(daten, 0.0, 0.25)
	_becken(daten, send, 16 * s, 0.1)
	# Schleife: ruhige Dur-Folge mit Harfe.
	var folge := [[60, 64, 67], [65, 69, 72], [67, 71, 74], [60, 64, 67],
		[57, 60, 64], [65, 69, 72], [67, 71, 74], [60, 64, 67]]
	for t in takte_loop:
		var t0 := (takte_intro + t) * 16 * s
		var akkord: Array = folge[t]
		_note(daten, send, cache, "bass", akkord[0] - 24, t0, 16 * s * 0.95, 0.18, 0.1)
		for ton in akkord:
			_note(daten, send, cache, "pad", ton, t0, 16 * s, 0.035, 0.6)
		for k in 8:
			_note(daten, send, cache, "harfe", akkord[k % 3] + 12 + (12 if k == 3 or k == 7 else 0),
				t0 + k * 2 * s, 2 * s * 0.9, 0.05, 0.5)
	return _mastern(daten, send, s, 0.35, int(takte_intro * 16 * s * MIX_RATE))


## Niederlage: langsames, absteigendes Moll-Motiv, danach leiser Teppich.
func render_niederlage() -> AudioStreamWAV:
	var bpm := 66.0
	var s := 60.0 / bpm / 4.0
	var n := int(6 * 16 * s * MIX_RATE)
	var daten := PackedFloat32Array()
	daten.resize(n)
	var send := PackedFloat32Array()
	send.resize(n)
	var cache := {}
	_loop_anfang = int(2 * 16 * s * MIX_RATE)
	var motiv := [[0, 4, 69], [4, 4, 67], [8, 4, 65], [12, 4, 64], [16, 8, 62], [24, 8, 61]]
	for m in motiv:
		_note(daten, send, cache, "floete", m[2], m[0] * s, m[1] * s * 0.95, 0.12, 0.6)
	var folge := [[50, 53, 57], [46, 50, 53], [43, 46, 50], [45, 49, 52], [50, 53, 57], [50, 53, 57]]
	for t in folge.size():
		var t0 := t * 16 * s
		for ton in folge[t]:
			_note(daten, send, cache, "orgel", ton, t0, 16 * s, 0.04, 0.7)
		_note(daten, send, cache, "bass", folge[t][0] - 12, t0, 16 * s * 0.95, 0.15, 0.2)
	return _mastern(daten, send, s, 0.5, int(2 * 16 * s * MIX_RATE))
