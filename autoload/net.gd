extends Node
## Autoload "Net": Co-op im DQ9-Stil. Ein Gast tritt der Welt des Hosts bei
## und bringt seinen EIGENEN Helden aus seinem eigenen Spielstand mit — der
## Held belegt beim Host einen freien Party-Slot, solange die Session läuft,
## und wird NIE in den Spielstand des Hosts geschrieben.
##
## Technik: ENet-Direktverbindung (LAN/Direkt-IP) mit UPnP-Versuch fürs
## Port-Forwarding — bewusst OHNE Relay-Server. Nachrichten sind JSON-Pakete
## {"t": Typ, "d": Daten} auf Kanal 0 (zuverlässig). Rundenbasiert = kein
## Echtzeit-Sync nötig, ein Nachrichtenprotokoll reicht.
##
## Beute-Regel (Design-Entscheidung): Der Gast nimmt XP/Gold/Items/
## Materialien mit nach Hause (Nachricht "gains" » eigener Spielstand),
## Dungeon-KARTEN bleiben beim Host.

signal roster_changed
signal guest_joined(guest_name: String)
signal guest_left(guest_name: String)
signal join_accepted
signal join_rejected(reason: String)
signal session_ended
signal gains_received(gains: Dictionary)
## Der Host hat eine Karte geöffnet » „Karte von (Spielername) — joinen“.
signal map_offered(host_name: String, card_name: String)
## Der Gast hat den Karten-Zustand erhalten und steht im Dungeon des Hosts.
signal map_joined
## Der Host hat Welt-Fortschritt geschickt (besiegte Gegner, Truhen, Events).
signal run_updated
## Gast-Seite: Der Host hat einen Kampf begonnen/beendet (Info-Anzeige).
signal coop_battle_started(data: Dictionary)
signal coop_battle_ended(data: Dictionary)
## Alles, was Net nicht selbst behandelt (Kampf-Beitritt — kommende
## Ausbaustufe), landet hier.
signal message_received(peer_id: int, type: String, data: Dictionary)

const DEFAULT_PORT := 7777
const MAX_GUESTS := 3  # Party-Größe 4 = eigener Held + bis zu 3 Gäste
const PROTOCOL_VERSION := 1
## Gäste, die nach dem Verbinden nie ihr "hello" schicken, fliegen raus.
const HELLO_TIMEOUT_MS := 10000

enum Role { OFFLINE, HOST, GUEST }

var role := Role.OFFLINE

## UPnP-Ergebnis für die Lobby-Anzeige (wird vom Worker-Thread befüllt).
var upnp_status := ""
var external_address := ""

## Rosteransicht (Name, Level, Gast?) — beim Host live, beim Gast per
## "roster"-Nachricht gespiegelt.
var roster: Array = []

## Im Test abschaltbar, damit "gains" nicht den echten Spielstand schreibt.
var autosave := true

## Mitspieler-Positionen im Dungeon: Helden-Name » {"pos": Vector2,
## "floor": int}. Ebene -1 = nicht (mehr) im Dungeon.
var remote_players: Dictionary = {}

## Gast: true, sobald der Host seine Karte geschlossen hat — die Dungeon-
## Szene wirft den Gast dann sauber raus (Net räumt current_run nie selbst
## weg, damit einer laufenden Szene nicht der Boden unter den Füßen fehlt).
var coop_run_closed := false

var _enet: ENetConnection
## Host: peer_id » {"peer": ENetPacketPeer, "name": String,
## "hero": Combatant|null, "joined_ms": int}. hero == null = Handshake offen.
var _guests: Dictionary = {}
var _next_peer_id := 1

## Gast: Verbindung zum Host + der mitgebrachte Held (fürs XP-Heimtragen).
var _server_peer: ENetPacketPeer
var _my_hero_name := ""
## Session-Name beim Host (kann bei Namens-Kollision einen Beinamen
## tragen — Positionen/Roster laufen darüber, XP-Heimnahme über den
## LOKALEN Namen _my_hero_name).
var _net_name := ""
var _my_hero_tile := -1
var _hello_sent := false

var _upnp_thread: Thread
var _upnp_mapped_port := -1

## Positions-Drossel: max. ~8 Updates/s und nur bei echter Bewegung.
var _pos_last_sent_ms := 0
var _pos_last := Vector2.INF
var _pos_last_floor := -99

var _offer_layer: CanvasLayer

## Im Selbsttest injizierbar; im Spiel das GameState-Autoload.
var _gs: Node


func _game_state() -> Node:
	if _gs == null:
		_gs = get_node_or_null("/root/GameState")
	return _gs


func is_online() -> bool:
	return role != Role.OFFLINE


func is_guest() -> bool:
	return role == Role.GUEST


func my_hero_name() -> String:
	return _net_name if role == Role.GUEST else _host_name()


## Porträt des eigenen Helden (Gast: der mitgebrachte Held).
func my_hero_sprite() -> Texture2D:
	var gs := _game_state()
	if gs != null:
		for member in gs.party:
			if member.display_name == _my_hero_name:
				return member.sprite
	return SpriteLib.tile(_my_hero_tile) if _my_hero_tile >= 0 \
		else SpriteLib.hero(_my_hero_name)


## Gast: der mitgebrachte Held als LOKALES Original — für Skill-Listen der
## Co-op-Kampfansicht (der HP/MP-Stand im Kampf kommt vom Host).
func my_local_hero() -> Combatant:
	var gs := _game_state()
	if gs == null:
		return null
	for member in gs.party:
		if member.display_name == _my_hero_name:
			return member
	return null


# --- Host --------------------------------------------------------------------

func host_game(port := DEFAULT_PORT, try_upnp := true) -> bool:
	if role != Role.OFFLINE:
		stop()
	_enet = ENetConnection.new()
	var err := _enet.create_host_bound("0.0.0.0", port, MAX_GUESTS)
	if err != OK:
		_enet = null
		upnp_status = Loc.pick("Port %d konnte nicht geöffnet werden.",
			"Could not open port %d.") % port
		return false
	role = Role.HOST
	_guests.clear()
	_refresh_roster()
	upnp_status = Loc.pick("Warte auf Mitspieler …", "Waiting for players …")
	external_address = ""
	if try_upnp:
		_start_upnp(port)
	return true


## Für die Kampf-/Dungeon-Slices: Beute-Paket an einen Gast schicken —
## {"xp": int, "gold": int, "materials": {id: n}, "items": [ItemInstance-Dicts]}.
func award_guest(peer_id: int, gains: Dictionary) -> void:
	if role != Role.HOST or not _guests.has(peer_id):
		return
	_send(_guests[peer_id]["peer"], "gains", gains)


func guest_ids() -> Array:
	var out: Array = []
	for peer_id in _guests:
		if _guests[peer_id]["hero"] != null:
			out.append(peer_id)
	return out


func guest_name(peer_id: int) -> String:
	if _guests.has(peer_id):
		return _guests[peer_id]["name"]
	return ""


func guest_hero(peer_id: int) -> Combatant:
	return _guests.get(peer_id, {}).get("hero")


## Host: Gäste, deren SPIELER gerade auf dieser Dungeon-Ebene steht —
## nur deren Helden werden in Kämpfe hineingezogen (Design-Regel).
func guests_on_floor(floor_index: int) -> Array:
	var out: Array = []
	for peer_id in _guests:
		var info: Dictionary = _guests[peer_id]
		if info["hero"] == null:
			continue
		var presence: Dictionary = remote_players.get(info["name"], {})
		if int(presence.get("floor", -99)) == floor_index:
			out.append(peer_id)
	return out


# --- Gast --------------------------------------------------------------------

## Verbindet zum Host und bringt `hero` mit (wird serialisiert übertragen;
## das lokale Original bleibt unberührt im eigenen Spielstand).
func join_game(ip: String, port: int, hero: Combatant) -> bool:
	if role != Role.OFFLINE:
		stop()
	if hero == null:
		return false
	_enet = ENetConnection.new()
	var err := _enet.create_host(1)
	if err != OK:
		_enet = null
		return false
	_server_peer = _enet.connect_to_host(ip, port)
	if _server_peer == null:
		_enet.destroy()
		_enet = null
		return false
	role = Role.GUEST
	_my_hero_name = hero.display_name
	_net_name = hero.display_name
	_my_hero_tile = hero.portrait_tile
	_hello_sent = false
	# Das hello wird erst nach EVENT_CONNECT geschickt — bis dahin gemerkt.
	set_meta(&"pending_hero", hero.to_dict())
	return true


## Nachricht an den Host (Gast-Seite) — für kommende Ausbaustufen.
func send_to_host(type: String, data: Dictionary) -> void:
	if role == Role.GUEST and _server_peer != null:
		_send(_server_peer, type, data)


## Nachricht an einen oder alle Gäste (Host-Seite).
func send_to_guest(peer_id: int, type: String, data: Dictionary) -> void:
	if role == Role.HOST and _guests.has(peer_id):
		_send(_guests[peer_id]["peer"], type, data)


func broadcast(type: String, data: Dictionary) -> void:
	if role != Role.HOST:
		return
	for peer_id in _guests:
		if _guests[peer_id]["hero"] != null:
			_send(_guests[peer_id]["peer"], type, data)


# --- Karten teilen & Welt-Sync (Slice 2) ----------------------------------------

## Host: "Karte von (Spielername) — joinen" an alle Gäste schicken.
func notify_map_opened() -> void:
	if role != Role.HOST:
		return
	var gs := _game_state()
	if gs == null or gs.current_run.is_empty():
		return
	broadcast("map_opened", _map_offer_data(gs))


func notify_map_closed() -> void:
	if role != Role.HOST:
		return
	broadcast("map_closed", {})
	remote_players.clear()


## Host: Welt-Fortschritt (besiegte Gegner, Truhen, Events, Boss) an alle
## Gäste — kleine Listen, darum einfach komplett schicken.
func notify_run_update() -> void:
	if role != Role.HOST:
		return
	var gs := _game_state()
	if gs == null or gs.current_run.is_empty():
		return
	broadcast("run_update", _run_state_data(gs))


## Gast: den Karten-Beitritt anfragen (Antwort kommt als "map_state").
func request_map_join() -> void:
	send_to_host("join_map", {})


## Gast: Dungeon des Hosts verlassen (Esc / eigener Entschluss).
func leave_map() -> void:
	if role == Role.GUEST:
		send_to_host("pos", {"name": _my_hero_name, "floor": -1, "x": 0, "y": 0})
	var gs := _game_state()
	if gs != null:
		gs.coop_guest_run = false
		gs.current_run = {}
	coop_run_closed = false
	remote_players.clear()


## Jeden Frame von der Dungeon-Szene gerufen — Net drosselt selbst
## (max. ~8/s, nur bei Bewegung oder Ebenenwechsel).
func update_presence(pos: Vector2, floor_index: int) -> void:
	if role == Role.OFFLINE:
		return
	var now := Time.get_ticks_msec()
	if floor_index == _pos_last_floor and now - _pos_last_sent_ms < 80:
		return
	if floor_index == _pos_last_floor and pos.distance_to(_pos_last) < 2.0:
		return
	_pos_last_sent_ms = now
	_pos_last = pos
	_pos_last_floor = floor_index
	var data := {"name": my_hero_name(), "floor": floor_index,
		"x": pos.x, "y": pos.y, "tile": _my_portrait_tile()}
	if role == Role.GUEST:
		send_to_host("pos", data)
	else:
		broadcast("pos", data)


## Porträt-Tile fürs Zeichnen des eigenen Avatars bei den Mitspielern.
func _my_portrait_tile() -> int:
	if role == Role.GUEST:
		return _my_hero_tile
	var gs := _game_state()
	if gs != null and not gs.party.is_empty():
		return gs.party[0].portrait_tile
	return -1


func _map_offer_data(gs: Node) -> Dictionary:
	var card: DungeonCard = gs.current_run["card"]
	return {"host": _host_name(), "card_name": card.display_name}


func _run_state_data(gs: Node) -> Dictionary:
	var run: Dictionary = gs.current_run
	return {
		"defeated": run.get("defeated", []),
		"opened": run.get("opened", []),
		"events_used": run.get("events_used", []),
		"boss_defeated": run.get("boss_defeated", false),
	}


## Gast: Karten-Zustand des Hosts als eigenen (rein clientseitigen) Run
## übernehmen — das Layout kommt deterministisch aus dem Karten-Seed.
func _apply_map_state(data: Dictionary) -> void:
	var gs := _game_state()
	if gs == null:
		return
	var card := DungeonCard.from_dict(data.get("card", {}))
	var run := {
		"card": card,
		"floor": 0,
		"defeated": [],
		"opened": [],
		"events_used": [],
		"player_pos": Vector2.ZERO,
		"boss_defeated": false,
		"explored_by_floor": {},
	}
	gs.current_run = run
	_apply_run_state(data)
	gs.coop_guest_run = true
	coop_run_closed = false
	map_joined.emit()
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/dungeon/dungeon_scene.tscn")


func _apply_run_state(data: Dictionary) -> void:
	var gs := _game_state()
	if gs == null or gs.current_run.is_empty():
		return
	var run: Dictionary = gs.current_run
	for key in ["defeated", "opened", "events_used"]:
		var ids: Array = []
		for id in data.get(key, []):
			ids.append(int(id))
		run[key] = ids
	run["boss_defeated"] = bool(data.get("boss_defeated", false))
	run_updated.emit()


func _apply_pos(data: Dictionary) -> void:
	var who := String(data.get("name", ""))
	if who == "" or who == my_hero_name():
		return
	if int(data.get("floor", -1)) < 0:
		remote_players.erase(who)
		return
	remote_players[who] = {
		"pos": Vector2(float(data.get("x", 0)), float(data.get("y", 0))),
		"floor": int(data.get("floor", 0)),
		"tile": int(data.get("tile", -1)),
	}


# --- Session beenden -----------------------------------------------------------

func stop() -> void:
	if role == Role.HOST:
		for peer_id in _guests:
			_remove_guest_hero(peer_id)
			_guests[peer_id]["peer"].peer_disconnect()
		_guests.clear()
		_refresh_roster()
	elif role == Role.GUEST and _server_peer != null:
		_server_peer.peer_disconnect()
	if _enet != null:
		# Disconnect-Kommandos brauchen ein paar Service-Runden, damit die
		# Gegenseite sie wirklich bekommt — flush() allein schickt sie nicht.
		for i in 8:
			_enet.service(10)
		_enet.destroy()
		_enet = null
	_server_peer = null
	_hello_sent = false
	if _upnp_mapped_port > 0:
		_remove_upnp(_upnp_mapped_port)
		_upnp_mapped_port = -1
	remote_players.clear()
	_dismiss_offer()
	if role != Role.OFFLINE:
		role = Role.OFFLINE
		session_ended.emit()


func _exit_tree() -> void:
	stop()
	if _upnp_thread != null and _upnp_thread.is_started():
		_upnp_thread.wait_to_finish()


# --- Poll-Schleife ---------------------------------------------------------------

func _process(_delta: float) -> void:
	if _enet == null:
		return
	# Pro Frame mehrere Ereignisse abholen, aber nie endlos hängen.
	for i in 64:
		var event: Array = _enet.service(0)
		var kind := int(event[0])
		if kind == ENetConnection.EVENT_NONE:
			break
		if kind == ENetConnection.EVENT_ERROR:
			stop()
			return
		var peer: ENetPacketPeer = event[1]
		match kind:
			ENetConnection.EVENT_CONNECT:
				_on_connect(peer)
			ENetConnection.EVENT_DISCONNECT:
				_on_disconnect(peer)
				if _enet == null:
					return
			ENetConnection.EVENT_RECEIVE:
				_on_packet(peer, peer.get_packet())
				if _enet == null:
					return
	if role == Role.HOST:
		_kick_silent_peers()


func _on_connect(peer: ENetPacketPeer) -> void:
	if role == Role.HOST:
		var peer_id := _next_peer_id
		_next_peer_id += 1
		_guests[peer_id] = {"peer": peer, "name": "", "hero": null,
			"joined_ms": Time.get_ticks_msec()}
	elif role == Role.GUEST and not _hello_sent:
		_hello_sent = true
		_send(_server_peer, "hello", {
			"version": PROTOCOL_VERSION,
			"name": _my_hero_name,
			"hero": get_meta(&"pending_hero", {}),
		})
		remove_meta(&"pending_hero")


func _on_disconnect(peer: ENetPacketPeer) -> void:
	if role == Role.HOST:
		var peer_id := _peer_id_of(peer)
		if peer_id < 0:
			return
		var was_named: String = _guests[peer_id]["name"]
		_remove_guest_hero(peer_id)
		_guests.erase(peer_id)
		_refresh_roster()
		if was_named != "":
			# Sein Avatar verschwindet bei allen aus dem Dungeon.
			remote_players.erase(was_named)
			broadcast("pos", {"name": was_named, "floor": -1, "x": 0, "y": 0})
			guest_left.emit(was_named)
			_broadcast_roster()
	elif role == Role.GUEST:
		# Host weg (oder hat uns abgelehnt und getrennt) » Session zu Ende.
		var enet := _enet
		_enet = null  # stop() soll nicht doppelt trennen
		if enet != null:
			enet.destroy()
		_server_peer = null
		role = Role.OFFLINE
		session_ended.emit()


func _on_packet(peer: ENetPacketPeer, bytes: PackedByteArray) -> void:
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if parsed == null or not (parsed is Dictionary):
		return
	var type := String(parsed.get("t", ""))
	var data: Dictionary = parsed.get("d", {}) if parsed.get("d", {}) is Dictionary else {}
	if role == Role.HOST:
		_handle_host_message(peer, type, data)
	else:
		_handle_guest_message(type, data)


# --- Nachrichten: Host-Seite --------------------------------------------------

func _handle_host_message(peer: ENetPacketPeer, type: String, data: Dictionary) -> void:
	var peer_id := _peer_id_of(peer)
	if peer_id < 0:
		return
	match type:
		"hello":
			_handle_hello(peer_id, peer, data)
		"join_map":
			var gs := _game_state()
			if gs != null and not gs.current_run.is_empty():
				var state := _run_state_data(gs)
				state["card"] = gs.current_run["card"].to_dict()
				_send(peer, "map_state", state)
			else:
				_send(peer, "map_closed", {})
		"pos":
			_apply_pos(data)
			# Der Host ist die Drehscheibe: Gast-Positionen an alle ANDEREN
			# Gäste weiterreichen.
			for other_id in _guests:
				if other_id != peer_id and _guests[other_id]["hero"] != null:
					_send(_guests[other_id]["peer"], "pos", data)
		_:
			message_received.emit(peer_id, type, data)


func _handle_hello(peer_id: int, peer: ENetPacketPeer, data: Dictionary) -> void:
	if int(data.get("version", 0)) != PROTOCOL_VERSION:
		_reject(peer, Loc.pick("Spielversionen passen nicht zusammen.",
			"Game versions do not match."))
		return
	var gs := _game_state()
	if gs == null or gs.party.size() >= HeroLibrary.MAX_PARTY_SIZE:
		_reject(peer, Loc.pick("Die Party des Hosts hat keinen freien Platz.",
			"The host's party has no free slot."))
		return
	var hero := Combatant.from_dict(data.get("hero", {}))
	if hero == null or hero.display_name == "":
		_reject(peer, Loc.pick("Held konnte nicht übertragen werden.",
			"Hero could not be transferred."))
		return
	# Freie Namen können kollidieren (Held des Hosts heißt genauso) —
	# der Gast bekommt für die Session einen Beinamen. Positionen, Roster
	# und Kampf-Meldungen laufen über diesen Session-Namen ("your_name").
	var base_name := hero.display_name
	if _name_in_use(hero.display_name):
		hero.display_name = base_name + Loc.pick(" (Gast)", " (guest)")
	if _name_in_use(hero.display_name):
		hero.display_name = "%s %d" % [base_name, peer_id]
	# Der Gast-Held belegt einen Party-Slot — markiert, damit er weder in
	# den Spielstand des Hosts wandert noch die Session überlebt.
	hero.set_meta(&"guest_peer", peer_id)
	gs.party.append(hero)
	_guests[peer_id]["name"] = hero.display_name
	_guests[peer_id]["hero"] = hero
	_refresh_roster()
	_send(peer, "welcome", {"host_name": _host_name(), "roster": roster,
		"your_name": hero.display_name})
	_broadcast_roster()
	# Läuft beim Host schon eine Karte, bekommt der Neuankömmling das
	# Beitritts-Angebot sofort.
	if not gs.current_run.is_empty():
		_send(peer, "map_opened", _map_offer_data(gs))
	guest_joined.emit(_guests[peer_id]["name"])


func _reject(peer: ENetPacketPeer, reason: String) -> void:
	_send(peer, "reject", {"reason": reason})
	peer.peer_disconnect_later()


func _remove_guest_hero(peer_id: int) -> void:
	var hero: Combatant = _guests.get(peer_id, {}).get("hero")
	if hero == null:
		return
	var gs := _game_state()
	if gs != null:
		gs.party.erase(hero)
	_guests[peer_id]["hero"] = null


func _kick_silent_peers() -> void:
	var now := Time.get_ticks_msec()
	for peer_id in _guests.keys():
		var info: Dictionary = _guests[peer_id]
		if info["hero"] == null and now - int(info["joined_ms"]) > HELLO_TIMEOUT_MS:
			info["peer"].peer_disconnect()
			_guests.erase(peer_id)


func _host_name() -> String:
	var gs := _game_state()
	if gs != null:
		for member in gs.party:
			if not member.has_meta(&"guest_peer"):
				return member.display_name
	return "Host"


## Ist der Name in dieser Welt schon vergeben (Party ODER Bank)?
func _name_in_use(candidate: String) -> bool:
	var gs := _game_state()
	if gs == null:
		return false
	for member in gs.party + gs.reserve:
		if member.display_name == candidate:
			return true
	return false


# --- Nachrichten: Gast-Seite -----------------------------------------------------

func _handle_guest_message(type: String, data: Dictionary) -> void:
	match type:
		"welcome":
			roster = data.get("roster", [])
			_net_name = String(data.get("your_name", _net_name))
			roster_changed.emit()
			join_accepted.emit()
		"reject":
			join_rejected.emit(String(data.get("reason", "?")))
			# Der Host trennt gleich von sich aus (peer_disconnect_later).
		"roster":
			roster = data.get("list", [])
			roster_changed.emit()
		"gains":
			_apply_gains(data)
		"map_opened":
			map_offered.emit(String(data.get("host", "?")), String(data.get("card_name", "?")))
			_show_offer_ui(String(data.get("host", "?")), String(data.get("card_name", "?")))
		"map_closed":
			_dismiss_offer()
			coop_run_closed = true
			remote_players.clear()
		"map_state":
			_dismiss_offer()
			_apply_map_state(data)
		"run_update":
			_apply_run_state(data)
		"pos":
			_apply_pos(data)
		"battle_started":
			coop_battle_started.emit(data)
		"battle_ended":
			coop_battle_ended.emit(data)
		_:
			message_received.emit(0, type, data)


## DQ9-Regel: Der Gast nimmt XP/Gold/Items/Materialien mit nach Hause —
## direkt in den EIGENEN Spielstand (Karten bleiben beim Host).
func _apply_gains(gains: Dictionary) -> void:
	var gs := _game_state()
	if gs == null:
		return
	var xp := int(gains.get("xp", 0))
	if xp > 0:
		for member in gs.party:
			if member.display_name == _my_hero_name:
				member.gain_xp(xp)
				break
	gs.gold += int(gains.get("gold", 0))
	var mats: Dictionary = gains.get("materials", {})
	for id_str in mats:
		gs.add_material(StringName(id_str), int(mats[id_str]))
	for item_data in gains.get("items", []):
		var item := ItemInstance.from_dict(item_data)
		if item != null:
			gs.inventory.append(item)
	if autosave:
		gs.save_game()
	gains_received.emit(gains)


# --- Helfer ---------------------------------------------------------------------

func _send(peer: ENetPacketPeer, type: String, data: Dictionary) -> void:
	var bytes := JSON.stringify({"t": type, "d": data}).to_utf8_buffer()
	peer.send(0, bytes, ENetPacketPeer.FLAG_RELIABLE)


func _peer_id_of(peer: ENetPacketPeer) -> int:
	for peer_id in _guests:
		if _guests[peer_id]["peer"] == peer:
			return peer_id
	return -1


func _refresh_roster() -> void:
	roster = []
	var gs := _game_state()
	if gs == null:
		return
	for member in gs.party:
		roster.append({"name": member.display_name, "level": member.level,
			"guest": member.has_meta(&"guest_peer")})
	roster_changed.emit()


func _broadcast_roster() -> void:
	broadcast("roster", {"list": roster})


# --- „Karte von X — joinen“: Overlay über jeder Szene ----------------------------

func _show_offer_ui(host_name: String, card_name: String) -> void:
	if not is_inside_tree():
		return
	var gs := _game_state()
	# Wer schon im Dungeon des Hosts steht, braucht kein neues Angebot.
	if gs != null and gs.coop_guest_run and not coop_run_closed:
		return
	_dismiss_offer()
	_offer_layer = CanvasLayer.new()
	_offer_layer.layer = 90
	add_child(_offer_layer)
	# Merksatz: Anker + Offsets VOR dem Einhängen setzen — sonst steht das
	# Overlay mit Größe 0 oben links statt in der Bildmitte.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_offer_layer.add_child(dim)
	var root := CenterContainer.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_offer_layer.add_child(root)
	var panel := PanelContainer.new()
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var label := Label.new()
	label.text = Loc.pick("Karte von %s:\n„%s“", "Map from %s:\n\"%s\"") % [host_name, card_name]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var join := Button.new()
	join.text = Loc.pick("Joinen", "Join")
	join.custom_minimum_size = Vector2(120, 40)
	join.pressed.connect(func() -> void:
		_dismiss_offer()
		request_map_join())
	buttons.add_child(join)
	var later := Button.new()
	later.text = Loc.pick("Später", "Later")
	later.custom_minimum_size = Vector2(120, 40)
	later.pressed.connect(_dismiss_offer)
	buttons.add_child(later)
	join.grab_focus.call_deferred()
	# Sfx über den Baum holen — als Identifier würde net.gd im Headless-
	# Selbsttest (ohne Autoloads) nicht kompilieren.
	var sfx := get_node_or_null(^"/root/Sfx")
	if sfx != null:
		sfx.play(&"bestaetigen")


func _dismiss_offer() -> void:
	if _offer_layer != null and is_instance_valid(_offer_layer):
		_offer_layer.queue_free()
	_offer_layer = null


# --- UPnP (automatischer Port-Forwarding-Versuch) --------------------------------

func _start_upnp(port: int) -> void:
	if _upnp_thread != null and _upnp_thread.is_started():
		_upnp_thread.wait_to_finish()
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_worker.bind(port))


## Läuft im Thread — Ergebnisse nur per call_deferred zurückreichen.
func _upnp_worker(port: int) -> void:
	var upnp := UPNP.new()
	var found := upnp.discover()
	if found != UPNP.UPNP_RESULT_SUCCESS or upnp.get_gateway() == null \
			or not upnp.get_gateway().is_valid_gateway():
		call_deferred("_apply_upnp_result", -1, "",
			Loc.pick("Kein UPnP-Router gefunden — im LAN geht es trotzdem, für Internet-Spiele Port %d (UDP) manuell freigeben.",
				"No UPnP router found — LAN still works; for internet play forward port %d (UDP) manually.") % port)
		return
	var mapped := upnp.add_port_mapping(port, port, "InfinitDungeon", "UDP")
	if mapped != UPNP.UPNP_RESULT_SUCCESS:
		call_deferred("_apply_upnp_result", -1, "",
			Loc.pick("UPnP-Portfreigabe abgelehnt — Port %d (UDP) manuell freigeben.",
				"UPnP port mapping refused — forward port %d (UDP) manually.") % port)
		return
	var address := upnp.query_external_address()
	call_deferred("_apply_upnp_result", port, address,
		Loc.pick("Port %d offen (UPnP).", "Port %d open (UPnP).") % port)


func _apply_upnp_result(mapped_port: int, address: String, status: String) -> void:
	_upnp_mapped_port = mapped_port
	external_address = address
	upnp_status = status
	roster_changed.emit()  # die Lobby lauscht darauf und zeichnet neu


func _remove_upnp(port: int) -> void:
	if _upnp_thread != null and _upnp_thread.is_started():
		_upnp_thread.wait_to_finish()
	_upnp_thread = Thread.new()
	_upnp_thread.start(func() -> void:
		var upnp := UPNP.new()
		if upnp.discover() == UPNP.UPNP_RESULT_SUCCESS:
			upnp.delete_port_mapping(port, "UDP"))
