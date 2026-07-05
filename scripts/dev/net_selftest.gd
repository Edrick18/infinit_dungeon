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
	# Nicht im Baum » _ready() (und damit load_game) läuft nie: frischer Zustand.
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
	# Ohne diesen Wächter würde ein Compile-Fehler in net.gd alle Checks
	# überspringen und die Suite fälschlich "OK" melden.
	var net_script: Script = load("res://autoload/net.gd")
	_check(net_script != null and net_script.can_instantiate(), "net.gd kompiliert")
	if net_script == null or not net_script.can_instantiate():
		return
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

	# --- Karte teilen: Angebot » Beitritt » Welt-Sync » Positionen ---
	print("Karten-Beitritt & Welt-Sync:")
	var card_rng := RandomNumberGenerator.new()
	card_rng.seed = 4242
	host_gs.start_run(CardFactory.make_card(3, card_rng))
	var offer_flags := {"host": "", "card": "", "joined": false, "updated": false}
	guest.map_offered.connect(func(host_name: String, card_name: String) -> void:
		offer_flags["host"] = host_name
		offer_flags["card"] = card_name)
	guest.map_joined.connect(func() -> void: offer_flags["joined"] = true)
	guest.run_updated.connect(func() -> void: offer_flags["updated"] = true)
	host.notify_map_opened()
	_check(_pump([host, guest], func() -> bool: return offer_flags["host"] != ""),
		"Gast bekommt das Karten-Angebot")
	_check(offer_flags["host"] == "Gastgeber", "Angebot nennt den Host-Namen")
	guest.request_map_join()
	_check(_pump([host, guest], func() -> bool: return offer_flags["joined"]),
		"Karten-Zustand kommt beim Gast an")
	var host_card: DungeonCard = host_gs.current_run["card"]
	var guest_card: DungeonCard = guest_gs.current_run.get("card")
	_check(guest_card != null and guest_card.seed == host_card.seed,
		"Gast erhält dieselbe Karte (gleicher Seed » gleiches Layout)")
	_check(guest_gs.coop_guest_run, "Gast-Run ist als Co-op-Run markiert")
	_check(not guest_gs.to_save_dict().has("current_run"),
		"Co-op-Run wird NIE in den Gast-Spielstand geschrieben")

	# Welt-Update: der Host besiegt einen Gegner, der Gast sieht es.
	host_gs.current_run["defeated"].append(1001)
	host.notify_run_update()
	_check(_pump([host, guest], func() -> bool: return offer_flags["updated"]),
		"Welt-Update erreicht den Gast")
	_check(1001 in guest_gs.current_run["defeated"],
		"besiegter Gegner ist auch beim Gast abgehakt")

	# Positions-Sync in beide Richtungen (über den Host als Drehscheibe).
	guest.update_presence(Vector2(96, 64), 0)
	_check(_pump([host, guest], func() -> bool:
		return host.remote_players.has("Reisende Lyra")),
		"Host sieht die Position des Gasts")
	host.update_presence(Vector2(200, 120), 1)
	_check(_pump([host, guest], func() -> bool:
		return guest.remote_players.has("Gastgeber")),
		"Gast sieht die Position des Hosts")
	_check(int(guest.remote_players.get("Gastgeber", {}).get("floor", -1)) == 1,
		"Ebenen-Info wandert mit (Kampf-Beitritt braucht sie)")

	# Kampf-Beitritt: Nur Gäste auf DERSELBEN Ebene kämpfen mit.
	print("Kampf-Beitritt (gleiche Ebene):")
	_check(host.guests_on_floor(0).size() == 1,
		"Gast auf Ebene 0 wird in Kämpfe auf Ebene 0 gezogen")
	_check(host.guests_on_floor(2).is_empty(),
		"auf Ebene 2 kämpft der Gast NICHT mit")
	var fighter_id: int = host.guests_on_floor(0)[0]
	var fighter: Combatant = host.guest_hero(fighter_id)
	_check(fighter != null and fighter.display_name == "Reisende Lyra",
		"guest_hero liefert den mitkämpfenden Helden")
	var battle_flags := {"started": {}, "ended": {}}
	guest.coop_battle_started.connect(func(data: Dictionary) -> void:
		battle_flags["started"] = data)
	guest.coop_battle_ended.connect(func(data: Dictionary) -> void:
		battle_flags["ended"] = data)
	host.broadcast("battle_started", {"host": "Gastgeber",
		"fighters": ["Reisende Lyra"], "is_boss": false})
	_check(_pump([host, guest], func() -> bool:
		return not (battle_flags["started"] as Dictionary).is_empty()),
		"Kampf-Start erreicht den Gast")
	_check("Reisende Lyra" in (battle_flags["started"] as Dictionary).get("fighters", []),
		"der Gast weiß, dass sein Held mitkämpft")
	host.broadcast("battle_ended", {"victory": true})
	_check(_pump([host, guest], func() -> bool:
		return not (battle_flags["ended"] as Dictionary).is_empty()),
		"Kampf-Ende erreicht den Gast")

	# Gast verlässt die Karte: Run verworfen, Avatar verschwindet beim Host.
	guest.leave_map()
	_check(_pump([host, guest], func() -> bool:
		return not host.remote_players.has("Reisende Lyra")),
		"nach dem Verlassen ist der Gast-Avatar beim Host weg")
	_check(guest_gs.current_run.is_empty() and not guest_gs.coop_guest_run,
		"der Gast-Run wird lokal verworfen")

	# Freie Namen: Kollision mit dem Host-Helden bekommt einen Beinamen.
	print("Namens-Kollision (freie Helden-Namen):")
	var twin_gs := _make_gs()
	var twin_hero := Combatant.from_dict({"name": "Gastgeber", "level": 2})
	twin_gs.party.append(twin_hero)
	var twin := _make_net(twin_gs)
	var twin_flags := {"ok": false}
	twin.join_accepted.connect(func() -> void: twin_flags["ok"] = true)
	twin.join_game("127.0.0.1", TEST_PORT, twin_hero)
	_check(_pump([host, guest, twin], func() -> bool: return twin_flags["ok"]),
		"Namensvetter des Hosts darf trotzdem joinen")
	var session_names: Array[String] = []
	for member in host_gs.party:
		session_names.append(member.display_name)
	_check("Gastgeber (Gast)" in session_names,
		"Kollision wird zum Session-Namen 'Gastgeber (Gast)'")
	_check(twin.my_hero_name() == "Gastgeber (Gast)",
		"der Gast kennt seinen Session-Namen (welcome/your_name)")
	twin.stop()
	_check(_pump([host], func() -> bool: return host_gs.party.size() == 2),
		"Namensvetter verlässt die Session sauber")
	twin.free()
	twin_gs.free()

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
		"volle Party » Beitritt wird abgelehnt")
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
