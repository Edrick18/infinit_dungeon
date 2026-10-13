extends Control
## Co-op-Lobby (DQ9-Stil): Welt öffnen (Host) oder per IP beitreten (Gast).
## Der Gast wählt, welchen seiner Helden er mitbringt — der belegt beim Host
## einen freien Party-Slot. Beute-Regel: XP/Gold/Items/Materialien nimmt der
## Gast mit nach Hause, Karten bleiben beim Host.

const MAIN_SCENE := "res://scenes/main.tscn"

var _host_port: LineEdit
var _host_button: Button
var _stop_button: Button
var _host_status: Label
var _join_ip: LineEdit
var _join_port: LineEdit
var _hero_select: OptionButton
var _join_button: Button
var _leave_button: Button
var _join_status: Label
var _roster_box: VBoxContainer


func _ready() -> void:
	theme = UiTheme.get_theme()
	Music.play(&"menu")
	_build_layout()
	Net.roster_changed.connect(_refresh)
	Net.join_accepted.connect(func() -> void:
		_join_status.text = Loc.pick("Verbunden! Du bist Teil der Party.",
			"Connected! You are part of the party.")
		Sfx.play(&"bestaetigen")
		_refresh())
	Net.join_rejected.connect(func(reason: String) -> void:
		_join_status.text = Loc.pick("Abgelehnt: %s", "Rejected: %s") % reason
		Sfx.play(&"fehler")
		_refresh())
	Net.session_ended.connect(func() -> void:
		_join_status.text = Loc.pick("Session beendet.", "Session ended.")
		_refresh())
	Net.guest_joined.connect(func(guest: String) -> void:
		Sfx.play(&"bestaetigen")
		_refresh()
		_host_status.text += "\n" + Loc.pick("%s ist beigetreten!", "%s joined!") % guest)
	Net.guest_left.connect(func(guest: String) -> void:
		_refresh()
		_host_status.text += "\n" + Loc.pick("%s hat die Session verlassen.",
			"%s left the session.") % guest)
	_refresh()
	UiTheme.focus_first_button(self)


func _build_layout() -> void:
	var b := Bildschirm.bauen(self, Loc.pick("Co-op — gemeinsam in den Dungeon", "Co-op — into the dungeon together"),
		&"lager", func() -> void: get_tree().change_scene_to_file(MAIN_SCENE), Loc.pick("Menü", "Menu"))
	b.setze_untertitel(Loc.pick(
		"Ein Gast bringt seinen eigenen Helden mit und belegt einen freien Party-Slot.\nBeute-Regel: XP, Gold, Items und Materialien nimmt der Gast mit nach Hause — Dungeon-Karten bleiben beim Host.",
		"A guest brings their own hero and takes a free party slot.\nLoot rule: guests take XP, gold, items and materials home — dungeon maps stay with the host."))
	var root := b.inhalt

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)

	# Links: Welt öffnen (Host).
	var host_panel := VBoxContainer.new()
	host_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_panel.add_theme_constant_override("separation", 8)
	var host_tafel := Bildschirm.tafel(host_panel)
	host_tafel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(host_tafel)
	var host_title := Label.new()
	host_title.text = Loc.pick("Meine Welt öffnen", "Open my world")
	host_title.add_theme_font_size_override("font_size", 20)
	host_panel.add_child(host_title)
	var port_row := HBoxContainer.new()
	port_row.add_theme_constant_override("separation", 8)
	host_panel.add_child(port_row)
	var port_label := Label.new()
	port_label.text = "Port:"
	port_row.add_child(port_label)
	_host_port = LineEdit.new()
	_host_port.text = str(Net.DEFAULT_PORT)
	_host_port.custom_minimum_size = Vector2(100, 0)
	port_row.add_child(_host_port)
	_host_button = Button.new()
	_host_button.text = Loc.pick("Welt öffnen (Host)", "Open world (host)")
	_host_button.pressed.connect(_on_host)
	host_panel.add_child(_host_button)
	_stop_button = Button.new()
	_stop_button.text = Loc.pick("Session beenden", "End session")
	_stop_button.pressed.connect(func() -> void:
		Net.stop()
		_host_status.text = ""
		_refresh())
	host_panel.add_child(_stop_button)
	_host_status = Label.new()
	_host_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_host_status.modulate = Color(0.7, 0.85, 1.0)
	host_panel.add_child(_host_status)

	# Rechts: Beitreten (Gast).
	var join_panel := VBoxContainer.new()
	join_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_panel.add_theme_constant_override("separation", 8)
	var join_tafel := Bildschirm.tafel(join_panel)
	join_tafel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(join_tafel)
	var join_title := Label.new()
	join_title.text = Loc.pick("Einer Welt beitreten", "Join a world")
	join_title.add_theme_font_size_override("font_size", 20)
	join_panel.add_child(join_title)
	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 8)
	join_panel.add_child(ip_row)
	var ip_label := Label.new()
	ip_label.text = Loc.pick("IP des Hosts:", "Host IP:")
	ip_row.add_child(ip_label)
	_join_ip = LineEdit.new()
	_join_ip.text = "127.0.0.1"
	_join_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_row.add_child(_join_ip)
	_join_port = LineEdit.new()
	_join_port.text = str(Net.DEFAULT_PORT)
	_join_port.custom_minimum_size = Vector2(80, 0)
	ip_row.add_child(_join_port)
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 8)
	join_panel.add_child(hero_row)
	var hero_label := Label.new()
	hero_label.text = Loc.pick("Ich bringe mit:", "I bring along:")
	hero_row.add_child(hero_label)
	_hero_select = OptionButton.new()
	_hero_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_child(_hero_select)
	_join_button = Button.new()
	_join_button.text = Loc.pick("Beitreten", "Join")
	_join_button.pressed.connect(_on_join)
	join_panel.add_child(_join_button)
	_leave_button = Button.new()
	_leave_button.text = Loc.pick("Verlassen", "Leave")
	_leave_button.pressed.connect(func() -> void:
		Net.stop()
		_refresh())
	join_panel.add_child(_leave_button)
	_join_status = Label.new()
	_join_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_join_status.modulate = Color(0.7, 0.85, 1.0)
	join_panel.add_child(_join_status)

	# Unten: die aktuelle Gruppe.
	var roster_title := Label.new()
	roster_title.text = Loc.pick("Gruppe", "Party")
	roster_title.add_theme_font_size_override("font_size", 20)
	_roster_box = VBoxContainer.new()
	_roster_box.add_theme_constant_override("separation", 2)
	var roster := VBoxContainer.new()
	roster.add_child(roster_title)
	roster.add_child(_roster_box)
	root.add_child(Bildschirm.tafel(roster))


func _on_host() -> void:
	var port := maxi(1024, int(_host_port.text))
	if Net.host_game(port):
		_host_status.text = Loc.pick("Welt offen — warte auf Mitspieler …",
			"World open — waiting for players …")
		Sfx.play(&"bestaetigen")
	else:
		_host_status.text = Net.upnp_status
		Sfx.play(&"fehler")
	_refresh()


func _on_join() -> void:
	var hero: Combatant = null
	if _hero_select.selected >= 0:
		hero = _hero_select.get_item_metadata(_hero_select.selected)
	if hero == null:
		_join_status.text = Loc.pick("Du brauchst einen Helden — erstelle erst einen im Hauptmenü.",
			"You need a hero — create one in the main menu first.")
		Sfx.play(&"fehler")
		return
	if Net.join_game(_join_ip.text.strip_edges(), maxi(1024, int(_join_port.text)), hero):
		_join_status.text = Loc.pick("Verbinde zu %s …", "Connecting to %s …") % _join_ip.text
	else:
		_join_status.text = Loc.pick("Verbindung fehlgeschlagen.", "Connection failed.")
		Sfx.play(&"fehler")
	_refresh()


func _refresh() -> void:
	var online := Net.is_online()
	_host_button.disabled = online
	_stop_button.disabled = Net.role != Net.Role.HOST
	_join_button.disabled = online
	_leave_button.disabled = Net.role != Net.Role.GUEST

	if Net.role == Net.Role.HOST:
		var status_parts: Array[String] = [Net.upnp_status]
		if Net.external_address != "":
			status_parts.append(Loc.pick("Deine öffentliche IPv4: %s", "Your public IPv4: %s")
				% Net.external_address)
		# Ohne eigene IPv4 (DS-Lite/CGNAT): über die IPv6 geht es direkt —
		# der Mitspieler braucht dafür ebenfalls einen IPv6-Anschluss.
		var ipv6 := Net.public_ipv6()
		if ipv6 != "":
			status_parts.append(Loc.pick("Deine IPv6 (falls keine IPv4 klappt): %s",
				"Your IPv6 (if IPv4 fails): %s") % ipv6)
		status_parts.append(Loc.pick("Gäste: %d", "Guests: %d") % Net.guest_ids().size())
		_host_status.text = "\n".join(status_parts)

	_hero_select.clear()
	for member in GameState.party:
		if member.has_meta(&"guest_peer"):
			continue
		_hero_select.add_item("%s (Lv %d)" % [member.display_name, member.level])
		_hero_select.set_item_metadata(_hero_select.item_count - 1, member)

	for child in _roster_box.get_children():
		child.queue_free()
	if Net.roster.is_empty() and not online:
		var empty := Label.new()
		empty.text = Loc.pick("Keine aktive Session.", "No active session.")
		empty.modulate = Color(1, 1, 1, 0.5)
		_roster_box.add_child(empty)
		return
	for entry in Net.roster:
		var line := Label.new()
		var guest_tag: String = Loc.pick("  ·  Gast", "  ·  guest") if entry.get("guest", false) else ""
		line.text = "%s (Lv %d)%s" % [entry.get("name", "?"), int(entry.get("level", 1)), guest_tag]
		_roster_box.add_child(line)
