extends SceneTree
## Headless-Selbsttest fürs Co-op-Netzwerk: Host + Gast als ECHTE
## ENet-Loopback-Verbindung im selben Prozess (kein Mock):
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/net_selftest.gd

const TEST_PORT := 34567
const PUMP_LIMIT := 400  # × 10 ms = max. 4 s pro Wartephase

var failures := 0


func _init() -> void:
	_test_coop_session()
	if failures == 0:
		print("SELFTEST OK — alle Netzwerk-Tests bestanden")
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


func _make_net(gs: Node) -> Node:
	var net: Node = load("res://autoload/net.gd").new()
	net._gs = gs  # GameState injizieren (Autoloads existieren im -s-Modus nicht)
	net.autosave = false  # der echte Spielstand darf im Test nie angefasst werden
	return net


func _make_gs() -> Node:
	# Nicht im Baum → _ready() (und damit load_game) läuft nie: frischer Zustand.
	return load("res://autoload/game_state.gd").new()


## Pumpt alle Netze, bis `done` true liefert oder das Limit reißt.
func _pump(nets: Array, done: Callable) -> bool:
	for i in PUMP_LIMIT:
		for net in nets:
			net._process(0.016)
		if done.call():
			return true
		OS.delay_msec(10)
	return false


func _test_coop_session() -> void:
	print("Co-op-Session (Handshake, Helden-Transfer, Beute, Trennung):")
	var host_gs := _make_gs()
	host_gs.party.append(Combatant.from_dict({"name": "Gastgeber", "level": 5}))
	var host := _make_net(host_gs)
	var guest_gs := _make_gs()
	var guest_hero := Combatant.from_dict({"name": "Reisende Lyra", "level": 3})
	guest_gs.party.append(guest_hero)
	var guest := _make_net(guest_gs)

	# Lambdas fangen lokale Werte per KOPIE — Flags müssen deshalb in ein
	# Dictionary (per Referenz), sonst sieht der Test die Signale nie.
	var flags := {"accepted": false, "gains": false, "rejection": ""}

	# --- Hosten + Beitreten (UPnP im Test aus — kein Router, kein Thread) ---
	_check(host.host_game(TEST_PORT, false), "Host öffnet die Welt auf Port %d" % TEST_PORT)
	guest.join_accepted.connect(func() -> void: flags["accepted"] = true)
	_check(guest.join_game("127.0.0.1", TEST_PORT, guest_hero), "Gast startet den Beitritt")
	_check(_pump([host, guest], func() -> bool: return flags["accepted"]),
		"Handshake kommt durch (welcome empfangen)")

	# --- Helden-Transfer: Gast-Held sitzt in der Host-Party, aber nie im Save ---
	_check(host_gs.party.size() == 2, "Gast-Held belegt einen Party-Slot beim Host")
	var transferred: Combatant = host_gs.party[1] if host_gs.party.size() > 1 else null
	_check(transferred != null and transferred.display_name == "Reisende Lyra"
		and transferred.level == 3, "Held kommt mit Name und Level an")
	_check(transferred != null and transferred.has_meta(&"guest_peer"),
		"Gast-Held ist als Gast markiert")
	_check(host_gs.to_save_dict()["party"].size() == 1,
		"Host-Spielstand enthält den Gast-Helden NICHT")
	_check(guest.roster.size() == 2, "Gast sieht das volle Roster")
	var guest_flags := 0
	for entry in guest.roster:
		if entry.get("guest", false):
			guest_flags += 1
	_check(guest_flags == 1, "genau ein Roster-Eintrag ist als Gast markiert")

	# --- Beute-Heimnahme: XP/Gold/Materialien landen im Gast-Spielstand ---
	var gold_before: int = guest_gs.gold
	guest.gains_received.connect(func(_gains: Dictionary) -> void: flags["gains"] = true)
	var ids: Array = host.guest_ids()
	_check(ids.size() == 1, "Host kennt genau einen Gast")
	host.award_guest(ids[0], {"xp": 50, "gold": 30, "materials": {"eisenerz": 2}, "items": []})
	_check(_pump([host, guest], func() -> bool: return flags["gains"]), "Beute-Paket kommt an")
	_check(guest_gs.gold == gold_before + 30, "Gold wandert in den Gast-Spielstand")
	_check(guest_gs.material_count(&"eisenerz") == 2, "Materialien wandern mit")
	_check(guest_hero.xp > 0 or guest_hero.level > 3, "XP landet auf dem mitgebrachten Helden")

	# --- Volle Party lehnt weitere Gäste ab ---
	host_gs.party.append(Combatant.from_dict({"name": "Dummy A", "level": 1}))
	host_gs.party.append(Combatant.from_dict({"name": "Dummy B", "level": 1}))
	var late_gs := _make_gs()
	var late_hero := Combatant.from_dict({"name": "Zu Spät", "level": 2})
	late_gs.party.append(late_hero)
	var late := _make_net(late_gs)
	late.join_rejected.connect(func(reason: String) -> void: flags["rejection"] = reason)
	late.join_game("127.0.0.1", TEST_PORT, late_hero)
	_check(_pump([host, guest, late], func() -> bool: return flags["rejection"] != ""),
		"volle Party → Beitritt wird abgelehnt")
	_check(host_gs.party.size() == 4, "abgelehnter Gast landet nie in der Party")

	# --- Trennung: Gast geht, Host räumt den Slot wieder frei ---
	guest.stop()
	_check(_pump([host], func() -> bool: return host_gs.party.size() == 3),
		"nach der Trennung ist der Gast-Slot wieder frei")
	var still_there := false
	for member in host_gs.party:
		if member.has_meta(&"guest_peer"):
			still_there = true
	_check(not still_there, "kein Gast-Held bleibt zurück")
	_check(guest_gs.party.size() == 1 and guest_gs.party[0] == guest_hero,
		"das lokale Original des Gast-Helden bleibt unberührt")

	late.stop()
	host.stop()
	late.free()
	guest.free()
	host.free()
	late_gs.free()
	guest_gs.free()
	host_gs.free()
