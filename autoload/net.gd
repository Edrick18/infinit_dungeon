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
## Materialien mit nach Hause (Nachricht "gains" → eigener Spielstand),
## Dungeon-KARTEN bleiben beim Host.

signal roster_changed
signal guest_joined(guest_name: String)
signal guest_left(guest_name: String)
signal join_accepted
signal join_rejected(reason: String)
signal session_ended
signal gains_received(gains: Dictionary)
## Alles, was Net nicht selbst behandelt (Positions-Sync, Karten-Prompts,
## Kampf-Beitritt — kommende Ausbaustufen), landet hier.
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

var _enet: ENetConnection
## Host: peer_id → {"peer": ENetPacketPeer, "name": String,
## "hero": Combatant|null, "joined_ms": int}. hero == null = Handshake offen.
var _guests: Dictionary = {}
var _next_peer_id := 1

## Gast: Verbindung zum Host + der mitgebrachte Held (fürs XP-Heimtragen).
var _server_peer: ENetPacketPeer
var _my_hero_name := ""
var _hello_sent := false

var _upnp_thread: Thread
var _upnp_mapped_port := -1

## Im Selbsttest injizierbar; im Spiel das GameState-Autoload.
var _gs: Node


func _game_state() -> Node:
	if _gs == null:
		_gs = get_node_or_null("/root/GameState")
	return _gs


func is_online() -> bool:
	return role != Role.OFFLINE


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
			guest_left.emit(was_named)
			_broadcast_roster()
	elif role == Role.GUEST:
		# Host weg (oder hat uns abgelehnt und getrennt) → Session zu Ende.
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
	# Der Gast-Held belegt einen Party-Slot — markiert, damit er weder in
	# den Spielstand des Hosts wandert noch die Session überlebt.
	hero.set_meta(&"guest_peer", peer_id)
	gs.party.append(hero)
	_guests[peer_id]["name"] = String(data.get("name", hero.display_name))
	_guests[peer_id]["hero"] = hero
	_refresh_roster()
	_send(peer, "welcome", {"host_name": _host_name(), "roster": roster})
	_broadcast_roster()
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


# --- Nachrichten: Gast-Seite -----------------------------------------------------

func _handle_guest_message(type: String, data: Dictionary) -> void:
	match type:
		"welcome":
			roster = data.get("roster", [])
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
