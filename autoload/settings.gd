extends Node
## Autoload "Settings": Geräte-Einstellungen — Lautstärke, Fenstermodus,
## Auflösung und frei belegbare Hotkeys. Liegt bewusst NICHT im Spielstand,
## sondern in einer eigenen Datei (user://settings.json).

const SETTINGS_PATH := "user://settings.json"

## Frei belegbare Aktionen: id » {Anzeigename DE/EN, Standard-Taste}.
const ACTIONS := {
	&"move_up": {"de": "Nach oben", "en": "Move up", "key": KEY_W},
	&"move_down": {"de": "Nach unten", "en": "Move down", "key": KEY_S},
	&"move_left": {"de": "Nach links", "en": "Move left", "key": KEY_A},
	&"move_right": {"de": "Nach rechts", "en": "Move right", "key": KEY_D},
	&"interact": {"de": "Interagieren (Opferstein …)", "en": "Interact (sacrifice stone …)",
		"key": KEY_E},
	&"open_inventory": {"de": "Inventar öffnen", "en": "Open inventory", "key": KEY_I},
	&"open_workshop": {"de": "Skill-Werkstatt öffnen", "en": "Open skill workshop", "key": KEY_K},
}

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440),
]

## Fenstermodi: 0 = Fenster, 1 = randloses Vollbild, 2 = exklusives Vollbild.
enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }

var master_volume := 0.8          ## 0.0 – 1.0
var music_volume := 0.7           ## 0.0 - 1.0 (eigener Musik-Bus)
var window_mode: WindowMode = WindowMode.WINDOWED
var resolution := Vector2i(1280, 720)
var keybinds: Dictionary = {}     ## Aktion » Keycode (int)
## Aktiver Spielstand-Slot (1..SaveManager.SLOT_COUNT) — liegt bewusst in
## den Einstellungen, nicht im Spielstand selbst.
var save_slot := 1


func _ready() -> void:
	# Standard-Belegung, dann gespeicherte Werte drüber.
	for action in ACTIONS:
		keybinds[action] = ACTIONS[action]["key"]
	load_settings()
	# WICHTIG: läuft vor GameState._ready (Autoload-Reihenfolge), damit der
	# richtige Slot geladen wird.
	SaveManager.active_slot = save_slot
	apply_all()


func apply_all() -> void:
	apply_volume()
	apply_window()
	apply_keybinds()


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(master_volume, 0.0001, 1.0)))
	AudioServer.set_bus_mute(0, master_volume <= 0.001)


## Musik-Bus regeln — der Bus entsteht erst im Music-Autoload, daher
## null-tolerant (und von dort nach dem Anlegen einmal aufgerufen).
func apply_music_volume() -> void:
	var idx := AudioServer.get_bus_index("Musik")
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(music_volume, 0.0001, 1.0)))
	AudioServer.set_bus_mute(idx, music_volume <= 0.001)


func apply_window() -> void:
	match window_mode:
		WindowMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(resolution)
			# Fenster mittig auf den Bildschirm setzen.
			var screen := DisplayServer.screen_get_usable_rect()
			DisplayServer.window_set_position(
				screen.position + (screen.size - resolution) / 2)
		WindowMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


## Bewegungs-Tasten spiegeln sich in die UI-Navigation (Menüs mit WASD
## bedienbar) — die Pfeiltasten bleiben zusätzlich immer aktiv.
const UI_MIRROR := {
	&"move_up": [&"ui_up", KEY_UP], &"move_down": [&"ui_down", KEY_DOWN],
	&"move_left": [&"ui_left", KEY_LEFT], &"move_right": [&"ui_right", KEY_RIGHT],
}


## Baut die InputMap aus den Hotkeys neu (Aktionen anlegen, Events ersetzen).
func apply_keybinds() -> void:
	for action in keybinds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = keybinds[action]
		InputMap.action_add_event(action, event)
	for action in UI_MIRROR:
		var ui_action: StringName = UI_MIRROR[action][0]
		InputMap.action_erase_events(ui_action)
		var arrow := InputEventKey.new()
		arrow.physical_keycode = UI_MIRROR[action][1]
		InputMap.action_add_event(ui_action, arrow)
		var mirror := InputEventKey.new()
		mirror.physical_keycode = keybinds.get(action, UI_MIRROR[action][1])
		InputMap.action_add_event(ui_action, mirror)


func rebind(action: StringName, keycode: Key) -> void:
	keybinds[action] = keycode
	apply_keybinds()
	save_settings()


func action_label(action: StringName) -> String:
	var info: Dictionary = ACTIONS[action]
	return Loc.pick(info["de"], info["en"])


func key_name(action: StringName) -> String:
	return OS.get_keycode_string(keybinds.get(action, KEY_NONE))


func reset_keybinds() -> void:
	for action in ACTIONS:
		keybinds[action] = ACTIONS[action]["key"]
	apply_keybinds()
	save_settings()


# --- Persistenz -----------------------------------------------------------------

func to_dict() -> Dictionary:
	var binds := {}
	for action in keybinds:
		binds[String(action)] = keybinds[action]
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"window_mode": int(window_mode),
		"resolution": [resolution.x, resolution.y],
		"keybinds": binds,
		"save_slot": save_slot,
	}


func apply_dict(data: Dictionary) -> void:
	master_volume = clampf(float(data.get("master_volume", 0.8)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", 0.7)), 0.0, 1.0)
	window_mode = clampi(int(data.get("window_mode", 0)), 0, 2) as WindowMode
	var res: Array = data.get("resolution", [1280, 720])
	resolution = Vector2i(int(res[0]), int(res[1]))
	save_slot = clampi(int(data.get("save_slot", 1)), 1, SaveManager.SLOT_COUNT)
	for action_str in data.get("keybinds", {}).keys():
		var action := StringName(action_str)
		if ACTIONS.has(action):
			keybinds[action] = int(data["keybinds"][action_str])


func save_settings() -> bool:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return true


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		apply_dict(parsed)
