extends SceneTree
## Headless-Selbsttest für Einstellungen (Lautstärke/Fenster/Hotkeys) und
## Feld-Aktionen (Tränke + Heilzauber außerhalb des Kampfs):
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/settings_selftest.gd

var failures := 0


func _init() -> void:
	_test_settings_roundtrip()
	_test_keybinds()
	_test_field_healing_rules()
	if failures == 0:
		print("SELFTEST OK — alle Einstellungs-/Feld-Tests bestanden")
		quit(0)
	else:
		print("SELFTEST FEHLGESCHLAGEN — %d Fehler" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		printerr("  FEHLER: " + label)


func _make_settings() -> Node:
	return load("res://autoload/settings.gd").new()


func _test_settings_roundtrip() -> void:
	print("Einstellungen (Serialisierungs-Rundweg, ohne Datei-I/O):")
	var settings: Node = _make_settings()
	for action in settings.ACTIONS:
		settings.keybinds[action] = settings.ACTIONS[action]["key"]
	settings.master_volume = 0.35
	settings.window_mode = 2  # exklusives Vollbild
	settings.resolution = Vector2i(1920, 1080)
	settings.keybinds[&"interact"] = KEY_F

	var restored: Node = _make_settings()
	for action in restored.ACTIONS:
		restored.keybinds[action] = restored.ACTIONS[action]["key"]
	restored.apply_dict(settings.to_dict())
	_check(is_equal_approx(restored.master_volume, 0.35), "Lautstärke übersteht den Rundweg")
	_check(int(restored.window_mode) == 2, "Fenstermodus übersteht den Rundweg")
	_check(restored.resolution == Vector2i(1920, 1080), "Auflösung übersteht den Rundweg")
	_check(restored.keybinds[&"interact"] == KEY_F, "umbelegter Hotkey übersteht den Rundweg")
	_check(restored.keybinds[&"move_up"] == KEY_W, "unveränderte Hotkeys behalten den Standard")
	settings.free()
	restored.free()


func _test_keybinds() -> void:
	print("Hotkeys » InputMap:")
	var settings: Node = _make_settings()
	for action in settings.ACTIONS:
		settings.keybinds[action] = settings.ACTIONS[action]["key"]
	settings.apply_keybinds()
	_check(InputMap.has_action(&"move_up") and InputMap.has_action(&"interact")
		and InputMap.has_action(&"open_inventory"),
		"alle Aktionen sind in der InputMap registriert")
	settings.keybinds[&"open_inventory"] = KEY_TAB
	settings.apply_keybinds()
	var events := InputMap.action_get_events(&"open_inventory")
	_check(events.size() == 1 and (events[0] as InputEventKey).physical_keycode == KEY_TAB,
		"Umbelegen ersetzt das Tasten-Event (I » Tab)")
	_check(settings.key_name(&"open_inventory") == OS.get_keycode_string(KEY_TAB),
		"key_name zeigt die neue Taste")
	settings.free()


func _test_field_healing_rules() -> void:
	print("Feldzauber-Regeln (nur Heilung/Kuren draußen — keine Buffs):")
	# Heilig + Verbündeter = feld-tauglich; reiner Buff (Regen-Aura) nicht.
	var heal := Skill.new()
	heal.blocks.append(BlockLibrary.get_block(&"src_spell"))
	heal.blocks.append(BlockLibrary.get_block(&"elem_holy"))
	heal.blocks.append(BlockLibrary.get_block(&"form_ally"))
	var buff := Skill.new()
	buff.blocks.append(BlockLibrary.get_block(&"src_spell"))
	buff.blocks.append(BlockLibrary.get_block(&"form_aura"))
	buff.blocks.append(BlockLibrary.get_block(&"eff_regen"))
	var attack := Skill.new()
	attack.blocks.append(BlockLibrary.get_block(&"src_spell"))
	attack.blocks.append(BlockLibrary.get_block(&"elem_fire"))

	# Dieselben Regeln wie inventory_scene._is_field_skill (hier nachgebaut,
	# damit die Logik headless abgesichert ist).
	_check(_is_field_skill(heal), "Heilig-Heilzauber ist draußen wirkbar")
	_check(not _is_field_skill(buff), "reine Buff-Aura ist draußen NICHT wirkbar")
	_check(not _is_field_skill(attack), "Angriffszauber ist draußen NICHT wirkbar")

	var revive := Skill.new()
	revive.blocks.append(BlockLibrary.get_block(&"src_spell"))
	revive.blocks.append(BlockLibrary.get_block(&"form_ally"))
	revive.blocks.append(BlockLibrary.get_block(&"eff_revive"))
	_check(_is_field_skill(revive), "Wiederbelebung ist draußen wirkbar")


## Kopie der Feld-Regel aus inventory_scene (dort UI-gebunden).
func _is_field_skill(skill: Skill) -> bool:
	if not skill.is_valid():
		return false
	var form := skill.get_form()
	if form != Enums.SkillForm.ALLY and form != Enums.SkillForm.AURA \
			and form != Enums.SkillForm.SELF:
		return false
	var element := skill.get_element()
	if element != null and element.element == Enums.Element.HOLY:
		return true
	for effect in skill.get_effect_blocks():
		if effect.status == Enums.Status.CLEANSE or effect.status == Enums.Status.REVIVE:
			return true
	return false
