extends Node
## Autoload "KiBruecke": lässt eine KI (Claude über einen Claude-Code-Mod) das
## Spiel ECHT spielen — sie liest den Spielzustand und gibt Befehle, die durch
## dieselben Wege laufen wie Tastatur und Maus (Kampfpläne, Knöpfe, Laufen).
##
## NUR AKTIV MIT STARTSCHALTER: `--ki` auf der Kommandozeile (Editor: hinter
## `--`, also `godot -- --ki`; EXE: `InfinitDungeon.exe --ki`) oder die
## Umgebungsvariable INFINIT_DUNGEON_KI=1. Ohne Schalter macht dieses Autoload
## nichts: kein Port, kein _process, keine Eingriffe.
## Denkpause: steht der Held und läuft kein Autopilot, bewegen sich die Gegner
## nicht (`--ki-echtzeit` = Welt läuft weiter wie beim Menschen).
##
## Technik: winziger HTTP-Server NUR auf 127.0.0.1 (Port 7781, `--ki-port=N`).
##   GET  /zustand[?warten=1&seit=N]  » Spielzustand als JSON
##   POST /aktion[?warten=1]          » Befehl (JSON-Body), Antwort = Zustand
## `warten=1` hält die Antwort, bis das Spiel wieder auf eine Eingabe wartet
## (Kampfrunde fertig, Autopilot angekommen, Szene geladen) — höchstens
## WARTEN_MAX_MS. So muss der Mod nicht pollen.

const STANDARD_PORT := 7781
const WARTEN_MAX_MS := 25000
## Eine frisch geladene Szene gilt erst nach dieser Zeit als bedienbar.
const SZENE_RUHE_MS := 500
const LOG_MAX := 300
## Autopilot: aufgeben, wenn sich der Held so lange kaum bewegt.
const FEST_MS := 1500
const AUTOPILOT_MAX_MS := 60000
const TEXT_MAX := 2500

var aktiv := false

var _server: TCPServer
var _verbindungen: Array[Dictionary] = []

var _log: Array[Dictionary] = []  ## {"nr": int, "text": String}
var _log_nr := 0

var _szene_id := 0
var _szene_seit_ms := 0

## Zuletzt gelistete Knöpfe (Nummer » Instanz-ID), für {"art": "knopf"}.
var _knoepfe: Array[int] = []

## Autopilot im Dungeon ({} = keiner): {"art", "id", "beschreibung", "szene",
## "start_ms", "pruef_pos", "pruef_ms", "jaeger", "dist", "dist_zelle"}.
var _ziel: Dictionary = {}
var _echtzeit := false
var _autopilot_ergebnis := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # auch hinter pausierenden Hinweisen
	aktiv = _schalter_an()
	_echtzeit = _echtzeit_an()
	if not aktiv:
		set_process(false)
		return
	var port := _port()
	_server = TCPServer.new()
	if _server.listen(port, "127.0.0.1") != OK:
		push_error("KiBruecke: Port %d konnte nicht geöffnet werden." % port)
		aktiv = false
		set_process(false)
		return
	print("KiBruecke aktiv: http://127.0.0.1:%d" % port)
	melden(Loc.pick("KI-Brücke bereit.", "AI bridge ready."))


static func _schalter_an() -> bool:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	return "--ki" in args or OS.get_environment("INFINIT_DUNGEON_KI") == "1"


static func _port() -> int:
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--ki-port="):
			return int(arg.get_slice("=", 1))
	return STANDARD_PORT


## Meldung fürs KI-Log (Kampflog, Dungeon-Meldungen). Ohne Schalter: nichts.
func melden(text: String) -> void:
	if not aktiv:
		return
	var sauber := _ohne_bbcode(text).strip_edges()
	if sauber.is_empty():
		return
	_log_nr += 1
	_log.append({"nr": _log_nr, "text": sauber})
	if _log.size() > LOG_MAX:
		_log.pop_front()


func _exit_tree() -> void:
	if _server != null:
		_server.stop()


# --- HTTP ----------------------------------------------------------------------

func _process(_delta: float) -> void:
	_szene_verfolgen()
	while _server.is_connection_available():
		var peer := _server.take_connection()
		_verbindungen.append({"peer": peer, "puffer": PackedByteArray(),
			"start": Time.get_ticks_msec(), "anfrage": {}})
	for verbindung in _verbindungen.duplicate():
		_bedienen(verbindung)


func _bedienen(verbindung: Dictionary) -> void:
	var peer: StreamPeerTCP = verbindung["peer"]
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_verbindungen.erase(verbindung)
		return
	if verbindung["anfrage"].is_empty():
		var verfuegbar := peer.get_available_bytes()
		if verfuegbar > 0:
			var teil: Array = peer.get_partial_data(verfuegbar)
			if int(teil[0]) == OK:
				verbindung["puffer"].append_array(teil[1])
		var anfrage := _anfrage_lesen(verbindung["puffer"])
		if anfrage.is_empty():
			if Time.get_ticks_msec() - int(verbindung["start"]) > 5000:
				_antworten(verbindung, 408, {"fehler": "Zeitüberschreitung"})
			return
		verbindung["anfrage"] = anfrage
		_anfrage_ausfuehren(verbindung)
		return
	# Wartende Anfrage (warten=1): antworten, sobald das Spiel bereit ist.
	if _bereit() or Time.get_ticks_msec() > int(verbindung["warte_bis"]):
		_antworten(verbindung, 200, _antwort_mit_zustand(verbindung))


## Vollständige HTTP-Anfrage aus dem Puffer — {} solange noch Bytes fehlen.
func _anfrage_lesen(puffer: PackedByteArray) -> Dictionary:
	var text := puffer.get_string_from_utf8()
	var kopf_ende := text.find("\r\n\r\n")
	if kopf_ende < 0:
		return {}
	var zeilen := text.substr(0, kopf_ende).split("\r\n")
	var erste := zeilen[0].split(" ")
	if erste.size() < 2:
		return {"methode": "?", "pfad": "/", "query": {}, "body": ""}
	var laenge := 0
	for zeile in zeilen:
		if zeile.to_lower().begins_with("content-length:"):
			laenge = int(zeile.get_slice(":", 1).strip_edges())
	# Content-Length zählt Bytes, nicht Zeichen (Umlaute!).
	var body_start := text.substr(0, kopf_ende + 4).to_utf8_buffer().size()
	if puffer.size() - body_start < laenge:
		return {}
	var body := puffer.slice(body_start, body_start + laenge).get_string_from_utf8()
	var ziel := erste[1]
	var query := {}
	if "?" in ziel:
		for paar in ziel.get_slice("?", 1).split("&"):
			query[paar.get_slice("=", 0)] = paar.get_slice("=", 1).uri_decode() if "=" in paar else "1"
		ziel = ziel.get_slice("?", 0)
	return {"methode": erste[0], "pfad": ziel, "query": query, "body": body}


func _anfrage_ausfuehren(verbindung: Dictionary) -> void:
	var anfrage: Dictionary = verbindung["anfrage"]
	var query: Dictionary = anfrage["query"]
	verbindung["seit"] = int(query.get("seit", "0"))
	match [anfrage["methode"], anfrage["pfad"]]:
		["GET", "/zustand"]:
			pass
		["POST", "/aktion"]:
			var befehl: Variant = JSON.parse_string(anfrage["body"])
			if not (befehl is Dictionary):
				_antworten(verbindung, 400, {"fehler": "Body ist kein JSON-Objekt."})
				return
			verbindung["meldung"] = _aktion(befehl)
		_:
			_antworten(verbindung, 404, {"fehler": "Unbekannt: GET /zustand, POST /aktion"})
			return
	if query.get("warten", "0") == "1":
		# Erst ab dem nächsten Frame prüfen: ein Knopfdruck wechselt die
		# Szene oft verzögert, und „bereit“ hieße sonst noch die alte.
		verbindung["warte_bis"] = Time.get_ticks_msec() + WARTEN_MAX_MS
		_szene_seit_ms = Time.get_ticks_msec()
		return
	_antworten(verbindung, 200, _antwort_mit_zustand(verbindung))


func _antwort_mit_zustand(verbindung: Dictionary) -> Dictionary:
	var antwort := zustand(int(verbindung.get("seit", 0)))
	if verbindung.has("meldung"):
		antwort["meldung"] = verbindung["meldung"]
	return antwort


func _antworten(verbindung: Dictionary, code: int, daten: Dictionary) -> void:
	var peer: StreamPeerTCP = verbindung["peer"]
	var body := JSON.stringify(daten).to_utf8_buffer()
	var kopf := "HTTP/1.1 %d %s\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" \
		% [code, "OK" if code == 200 else "Fehler", body.size()]
	peer.put_data(kopf.to_utf8_buffer())
	peer.put_data(body)
	peer.disconnect_from_host()
	_verbindungen.erase(verbindung)


# --- Szene & Bereitschaft ---------------------------------------------------------

func _szene_verfolgen() -> void:
	var szene := get_tree().current_scene
	var id := szene.get_instance_id() if szene != null else 0
	if id != _szene_id:
		_szene_id = id
		_szene_seit_ms = Time.get_ticks_msec()
		_knoepfe.clear()
		if not _ziel.is_empty():
			_ziel_ende(Loc.pick("Szene gewechselt.", "Scene changed."))


func _szenen_art(szene: Node) -> String:
	if szene == null:
		return "laedt"
	if szene.has_method("_set_plan") and szene.get("battle") != null:
		return "kampf"
	if szene.has_method("_ki_autopilot") and szene.get("map") != null:
		return "dungeon"
	return "menue"


## Wartet das Spiel gerade auf eine Eingabe?
func _bereit() -> bool:
	var szene: Variant = get_tree().current_scene
	if szene == null or Time.get_ticks_msec() - _szene_seit_ms < SZENE_RUHE_MS:
		return false
	match _szenen_art(szene):
		"kampf":
			var kampf: Variant = szene
			if kampf.battle.is_over:
				return not _sichtbare_knoepfe(szene).is_empty()
			return _kampf_wartet_auf_befehl(kampf)
		"dungeon":
			return _ziel.is_empty() and not szene.get("_entering_battle")
	return true


func _kampf_wartet_auf_befehl(kampf: Variant) -> bool:
	return kampf._active != null and not kampf._resolving \
		and kampf._active in kampf._pending_local


# --- Zustand ---------------------------------------------------------------------

func zustand(seit_log := 0) -> Dictionary:
	var szene: Variant = get_tree().current_scene
	var art := _szenen_art(szene)
	var daten := {
		"szene": art,
		"szene_datei": szene.scene_file_path if szene != null else "",
		"bereit": _bereit(),
		"log": _log_seit(seit_log),
		"log_nr": _log_nr,
	}
	var gs: Variant = _gs()
	if gs != null:
		daten["gold"] = gs.gold
		daten["party"] = _party_daten(gs.party)
	match art:
		"kampf":
			daten["kampf"] = _kampf_daten(szene)
		"dungeon":
			daten["dungeon"] = _dungeon_daten(szene)
	if not _autopilot_ergebnis.is_empty():
		daten["autopilot"] = _autopilot_ergebnis
	# Knöpfe überall (Menüs, Hub, Kampfende, Hinweise); Texte nur, wo es
	# keinen eigenen Zustand gibt bzw. nach dem Kampf (Beute, Level-ups).
	daten["knoepfe"] = _knoepfe_listen(szene)
	if art == "menue" or art == "laedt" or (art == "kampf" and szene.battle.is_over):
		daten["texte"] = _texte(szene)
	return daten


func _log_seit(nr: int) -> Array:
	var out: Array = []
	for eintrag in _log:
		if int(eintrag["nr"]) > nr:
			out.append(eintrag["text"])
	return out


func _party_daten(party: Array) -> Array:
	var out: Array = []
	for held: Combatant in party:
		out.append({"name": held.display_name, "lv": held.level,
			"hp": "%d/%d" % [held.hp, held.max_hp], "mp": "%d/%d" % [held.mp, held.max_mp],
			"punkte": held.stat_points, "status": _status_namen(held)})
	return out


func _status_namen(kaempfer: Combatant) -> Array:
	var out: Array = []
	for eintrag in kaempfer.statuses:
		out.append(Battle.status_label(eintrag))
	return out


func _kampf_daten(kampf: Variant) -> Dictionary:
	var battle: Battle = kampf.battle
	var daten := {"runde": battle.round_number + 1, "boss": battle.has_boss(),
		"vorbei": battle.is_over}
	var helden: Array = []
	for held in battle.players:
		helden.append({"id": int(kampf._net_ids.get(held, -1)), "name": held.display_name,
			"lv": held.level, "hp": "%d/%d" % [held.hp, held.max_hp],
			"mp": "%d/%d" % [held.mp, held.max_mp], "lebt": held.is_alive(),
			"status": _status_namen(held), "plan": kampf._plan_text(held),
			"beschworen": held.is_summon})
	daten["helden"] = helden
	var gegner: Array = []
	for feind in battle.enemies:
		if not feind.is_alive():
			continue
		var elemente: Array = []
		for paar in KampfUi.element_wissen(feind):
			elemente.append("%s x%.2f" % [Enums.Element.keys()[int(paar[0])], float(paar[1])])
		# HP als Prozent: so viel verrät auch die Lebensleiste im Spiel.
		gegner.append({"id": int(kampf._net_ids.get(feind, -1)), "name": feind.display_name,
			"lv": feind.level, "hp_prozent": roundi(100.0 * feind.hp / maxf(1.0, feind.max_hp)),
			"status": _status_namen(feind), "bekannte_elemente": elemente, "boss": feind.is_boss})
	daten["gegner"] = gegner
	var reihe: Array = []
	for kaempfer in battle.upcoming_turns(6):
		reihe.append(kaempfer.display_name)
	daten["zugfolge"] = reihe
	if _kampf_wartet_auf_befehl(kampf):
		var held: Combatant = kampf._active
		var skills: Array = []
		for i in mini(held.skills.size(), held.skill_slots()):
			var skill: Skill = held.skills[i]
			if skill.get_sources().is_empty():
				continue
			skills.append({"nr": i, "name": skill.display_name, "mp": skill.get_mp_cost(held),
				"form": Enums.SkillForm.keys()[skill.get_form()], "nutzbar": skill.is_valid(held)})
		var items: Array = []
		var gs: Variant = _gs()
		for id in gs.consumables:
			var def := ConsumableLibrary.get_def(id)
			if def != null and int(gs.consumables[id]) > 0:
				items.append({"id": String(id), "name": def.display_name, "anzahl": int(gs.consumables[id])})
		daten["befehl_fuer"] = {"name": held.display_name, "skills": skills, "items": items,
			"waffenset_wechsel": held.has_second_weapon_set(), "fliehen": not battle.has_boss(),
			"zuruecknehmen": not kampf._local_done.is_empty()}
	return daten


func _dungeon_daten(dungeon: Variant) -> Dictionary:
	var map: DungeonMap = dungeon.map
	var card: DungeonCard = dungeon.card
	var spieler: Vector2i = dungeon._pos_to_cell(dungeon.player_pos)
	var weg := map.distances_from(spieler)
	var erkundet: Dictionary = dungeon._explored_cells
	var sichtbar: Dictionary = dungeon._visible_cells
	var daten := {
		"karte": card.display_name, "stufe": card.tier,
		"ebene": "%d/%d" % [dungeon.floor_index + 1, card.floor_count],
		"sonderregel": Sonderregeln.name_von(card),
		"spieler_zelle": [spieler.x, spieler.y],
	}
	var gegner: Array = []
	for feind: Dictionary in dungeon._enemies:
		var zelle: Vector2i = dungeon._pos_to_cell(feind["pos"])
		if not sichtbar.has(zelle):
			continue
		var archetyp: EnemyArchetype = feind.get("archetype")
		var eintrag := {"id": int(feind["id"]), "name": archetyp.display_name if archetyp != null else "?",
			"weg": int(weg.get(zelle, -1)), "jagt_dich": bool(feind.get("jagd", false))}
		# Im Spiel sichtbar (Schlüssel-Symbol am Gegner) — also auch der KI melden.
		if feind.get("schluessel", false):
			eintrag["traegt_schluessel"] = true
		gegner.append(eintrag)
	daten["gegner_in_sicht"] = gegner
	var truhen: Array = []
	for truhe: Dictionary in dungeon._chests:
		var zelle: Vector2i = dungeon._pos_to_cell(truhe["pos"])
		if erkundet.has(zelle):
			truhen.append({"id": int(truhe["id"]), "weg": int(weg.get(zelle, -1))})
	daten["truhen"] = truhen
	var ereignisse: Array = []
	for ereignis: Dictionary in dungeon._events:
		var zelle: Vector2i = dungeon._pos_to_cell(ereignis["pos"])
		if erkundet.has(zelle):
			ereignisse.append({"id": int(ereignis["id"]),
				"typ": DungeonGenerator.EventType.keys()[int(ereignis["type"])],
				"weg": int(weg.get(zelle, -1))})
	daten["ereignisse"] = ereignisse
	if map.stairs_cell.x >= 0 and erkundet.has(map.stairs_cell):
		daten["treppe_weg"] = int(weg.get(map.stairs_cell, -1))
	if dungeon._boss_alive and erkundet.has(map.boss_cell):
		daten["boss_weg"] = int(weg.get(map.boss_cell, -1))
	if not dungeon._tresor.is_empty():
		var tresor_zelle: Vector2i = dungeon._pos_to_cell(dungeon._tresor["pos"])
		if erkundet.has(tresor_zelle):
			daten["tresor"] = {"weg": int(weg.get(tresor_zelle, -1)), "schluessel": dungeon.hat_schluessel()}
	var offen := 0
	for zelle in weg:
		if not erkundet.has(zelle):
			offen += 1
	daten["unerkundete_erreichbare_felder"] = offen
	# Opferstein/Schrein direkt vor dem Helden: taste "interagieren" benutzt ihn.
	var nah: Dictionary = dungeon._ereignis_nah
	if not nah.is_empty():
		daten["ereignis_nah"] = {"id": int(nah["id"]),
			"typ": DungeonGenerator.EventType.keys()[int(nah["type"])],
			"text": _ohne_bbcode(dungeon.ereignis_text(nah))}
	if not _ziel.is_empty():
		daten["unterwegs_zu"] = _ziel["beschreibung"]
	return daten


# --- Knöpfe & Texte (allgemeine Bedienung) -------------------------------------------

func _knoepfe_listen(szene: Node) -> Array:
	_knoepfe.clear()
	var out: Array = []
	for knopf in _sichtbare_knoepfe(szene):
		_knoepfe.append(knopf.get_instance_id())
		var text := knopf.text.strip_edges().replace("\n", " · ")
		out.append({"nr": _knoepfe.size(), "text": text if not text.is_empty() else knopf.tooltip_text.left(40)})
	return out


## Sichtbare, nutzbare Knöpfe der Szene UND der Overlays (Hinweise, Koop).
func _sichtbare_knoepfe(szene: Node) -> Array[Button]:
	var out: Array[Button] = []
	for kind in get_tree().root.get_children():
		if kind == self:
			continue
		_knoepfe_sammeln(kind, out)
	return out


func _knoepfe_sammeln(knoten: Node, out: Array[Button]) -> void:
	if knoten is CanvasItem and not (knoten as CanvasItem).is_visible_in_tree():
		return
	if knoten is CanvasLayer and not (knoten as CanvasLayer).visible:
		return
	if knoten is Button and not (knoten as Button).disabled:
		var knopf := knoten as Button
		if not knopf.text.strip_edges().is_empty() or not knopf.tooltip_text.is_empty():
			out.append(knopf)
	for kind in knoten.get_children():
		_knoepfe_sammeln(kind, out)


func _texte(szene: Node) -> String:
	var teile: Array[String] = []
	# Nach dem Kampf zählt nur das Ergebnis-Fenster (Beute, Level-ups) — das
	# zuletzt eingehängte CenterContainer; das Kampflog steht schon im Log.
	if _szenen_art(szene) == "kampf":
		for i in range(szene.get_child_count() - 1, -1, -1):
			if szene.get_child(i) is CenterContainer:
				_texte_sammeln(szene.get_child(i), teile)
				return "\n".join(teile).left(TEXT_MAX)
	for kind in get_tree().root.get_children():
		if kind != self:
			_texte_sammeln(kind, teile)
	var text := "\n".join(teile)
	return text.left(TEXT_MAX)


func _texte_sammeln(knoten: Node, teile: Array[String]) -> void:
	if knoten is CanvasItem and not (knoten as CanvasItem).is_visible_in_tree():
		return
	if knoten is Button:
		return  # Knöpfe stehen schon in der Knopf-Liste
	var text := ""
	if knoten is Label:
		text = (knoten as Label).text
	elif knoten is RichTextLabel:
		text = (knoten as RichTextLabel).get_parsed_text()
	text = text.strip_edges()
	if not text.is_empty() and text not in teile:
		teile.append(text)
	for kind in knoten.get_children():
		_texte_sammeln(kind, teile)


# --- Aktionen --------------------------------------------------------------------

## Führt einen Befehl aus und gibt eine kurze Rückmeldung (Fehler beginnen mit „Fehler:“).
func _aktion(befehl: Dictionary) -> String:
	var szene: Variant = get_tree().current_scene
	_autopilot_ergebnis = ""
	match String(befehl.get("art", "")):
		"knopf":
			return _knopf_druecken(int(befehl.get("nr", 0)))
		"kampf":
			if _szenen_art(szene) != "kampf":
				return "Fehler: kein Kampf."
			return _kampf_befehl(szene, befehl)
		"gehe":
			if _szenen_art(szene) != "dungeon":
				return "Fehler: nicht im Dungeon."
			return _ziel_setzen(szene, befehl)
		"stopp":
			_ziel_ende(Loc.pick("Angehalten.", "Stopped."))
			return "ok"
		"taste":
			return _taste(String(befehl.get("taste", "")))
		"punkte":
			return _punkte_verteilen(befehl)
	return "Fehler: unbekannte art. Erlaubt: knopf, kampf, gehe, stopp, taste, punkte."


func _knopf_druecken(nr: int) -> String:
	if nr < 1 or nr > _knoepfe.size():
		return "Fehler: Knopf %d gibt es nicht (erst Zustand holen)." % nr
	var knopf := instance_from_id(_knoepfe[nr - 1]) as Button
	if knopf == null or not knopf.is_visible_in_tree() or knopf.disabled:
		return "Fehler: Knopf %d ist nicht mehr da." % nr
	var text := knopf.text.replace("\n", " · ")
	knopf.pressed.emit()
	melden(Loc.pick("KI drückt: %s", "AI presses: %s") % text)
	return "ok: %s" % text


func _kampf_befehl(kampf: Variant, befehl: Dictionary) -> String:
	if kampf.battle.is_over:
		return "Fehler: Der Kampf ist vorbei — Knöpfe benutzen."
	var wahl := String(befehl.get("befehl", ""))
	if wahl == "zuruecknehmen":
		if kampf._local_done.is_empty():
			return "Fehler: nichts zurückzunehmen."
		kampf._undo_last_plan()
		return "ok"
	if not _kampf_wartet_auf_befehl(kampf):
		return "Fehler: Die Runde läuft gerade — warten."
	var held: Combatant = kampf._active
	if wahl == "waffenwechsel":
		if not held.has_second_weapon_set():
			return "Fehler: %s hat kein zweites Waffenset." % held.display_name
		held.swap_weapon_set()
		kampf._on_log(Loc.pick("%s wechselt das Waffenset.", "%s swaps weapon sets.") % held.display_name)
		kampf._refresh_all()
		kampf._show_actions(held)
		return "ok (freie Aktion, %s ist weiter dran)" % held.display_name
	var art: String = {"angriff": "attack", "skill": "skill", "item": "item", "verteidigen": "defend",
		"konzentrieren": "focus", "fliehen": "flee"}.get(wahl, "")
	if art.is_empty():
		return "Fehler: befehl muss angriff, skill, item, verteidigen, konzentrieren, fliehen, waffenwechsel oder zuruecknehmen sein."
	if art == "flee" and kampf.battle.has_boss():
		return "Fehler: Vor Bossen gibt es keine Flucht."
	# Dieselbe Übersetzung wie für Koop-Mitspieler: geprüft, Ungültiges fällt auf.
	var daten := {"kind": art, "target": int(befehl.get("ziel", -1)),
		"skill": int(befehl.get("skill", -1)), "item": String(befehl.get("item", ""))}
	var plan: Dictionary = kampf._plan_from_net(held, daten)
	if String(plan["kind"]) != art:
		return "Fehler: ungültig (Skill-Nummer, MP, Item oder Ziel prüfen)."
	if art == "item" and _gs().consumable_count(StringName(daten["item"])) <= 0:
		return "Fehler: Item %s ist nicht mehr da." % daten["item"]
	kampf._set_plan(held, plan)
	return "ok: %s » %s" % [held.display_name, kampf._describe_plan(plan)]


func _punkte_verteilen(befehl: Dictionary) -> String:
	var name := String(befehl.get("held", ""))
	var stat := StringName(String(befehl.get("stat", "")))
	var anzahl := maxi(1, int(befehl.get("anzahl", 1)))
	for held: Combatant in _gs().party:
		if held.display_name != name:
			continue
		var verteilt := 0
		for i in anzahl:
			if held.spend_stat_point(stat):
				verteilt += 1
		if verteilt == 0:
			return "Fehler: keine Punkte frei oder unbekannter Wert. Werte: %s" % ", ".join(StatBlock.STAT_NAMES)
		melden("%s: +%d %s" % [name, verteilt, stat])
		return "ok: %d Punkt(e) in %s, noch %d frei" % [verteilt, stat, held.stat_points]
	return "Fehler: Held %s nicht in der Party." % name


## Tasten wie ein Spieler sie drückt (Dungeon: Esc verlassen, E Opferstein, …).
func _taste(name: String) -> String:
	var ereignis: InputEvent
	match name:
		"esc":
			var taste := InputEventKey.new()
			taste.keycode = KEY_ESCAPE
			taste.pressed = true
			ereignis = taste
		"interagieren", "inventar", "werkstatt":
			# Die echte belegte Taste schicken: der Dungeon nimmt nur
			# InputEventKey an (Spieltest 2026-10-22: Opferstein ging nicht).
			var aktion: StringName = {"interagieren": &"interact", "inventar": &"open_inventory",
				"werkstatt": &"open_workshop"}[name]
			for belegt in InputMap.action_get_events(aktion):
				if belegt is InputEventKey:
					var taste := (belegt as InputEventKey).duplicate() as InputEventKey
					taste.pressed = true
					ereignis = taste
					break
			if ereignis == null:
				return "Fehler: keine Taste für %s belegt." % name
		_:
			return "Fehler: taste muss esc, interagieren, inventar oder werkstatt sein."
	Input.parse_input_event(ereignis)
	# Auch loslassen, sonst gilt die Taste für Godot als dauerhaft gehalten.
	var los := ereignis.duplicate() as InputEvent
	los.set("pressed", false)
	Input.parse_input_event(los)
	return "ok"


# --- Autopilot (Dungeon-Zielbefehle) -------------------------------------------------

func _ziel_setzen(dungeon: Variant, befehl: Dictionary) -> String:
	var art := String(befehl.get("ziel", ""))
	var id := int(befehl.get("id", -1))
	if art not in ["gegner", "truhe", "ereignis", "treppe", "boss", "tresor", "erkunden"]:
		return "Fehler: ziel muss gegner, truhe, ereignis, treppe, boss, tresor oder erkunden sein."
	var jaeger: Array = []
	for feind: Dictionary in dungeon._enemies:
		if feind.get("jagd", false):
			jaeger.append(int(feind["id"]))
	_ziel = {"art": art, "id": id, "szene": dungeon.get_instance_id(),
		"start_ms": Time.get_ticks_msec(), "pruef_pos": dungeon.player_pos,
		"pruef_ms": Time.get_ticks_msec(), "jaeger": jaeger,
		"beschreibung": art + ("" if id < 0 else " %d" % id)}
	var zelle := _ziel_zelle(dungeon)
	# Fair bleiben: nur ansteuern, was der Spieler schon gesehen hat.
	var bekannt: Dictionary = dungeon._visible_cells if art == "gegner" else dungeon._explored_cells
	if zelle.x < 0 or (art != "erkunden" and not bekannt.has(zelle)):
		var grund := _autopilot_ergebnis
		_ziel = {}
		return "Fehler: " + (grund if not grund.is_empty() else "Ziel unbekannt oder nicht in Sicht.")
	melden(Loc.pick("KI läuft los: %s", "AI heads for: %s") % _ziel["beschreibung"])
	return "ok: unterwegs zu " + _ziel["beschreibung"]


## Denkpause (Spieltest 2026-10-22: zweimal beim Nachdenken erwischt): ohne
## laufenden Autopiloten bewegen sich die Gegner nicht, solange der Held
## steht. `--ki-echtzeit` schaltet das ab.
func denkpause() -> bool:
	return aktiv and _ziel.is_empty() and not _echtzeit


static func _echtzeit_an() -> bool:
	return "--ki-echtzeit" in OS.get_cmdline_args() + OS.get_cmdline_user_args()


## Der Spieler greift selbst zur Tastatur: Autopilot sofort beenden.
func autopilot_stoppen() -> void:
	_ziel_ende(Loc.pick("Spieler übernimmt.", "Player took over."))


func _ziel_ende(grund: String) -> void:
	if _ziel.is_empty():
		return
	_autopilot_ergebnis = "%s: %s" % [_ziel["beschreibung"], grund]
	melden(_autopilot_ergebnis)
	_ziel = {}


## Vom Dungeon jeden Frame gerufen, solange keine Taste gedrückt ist:
## Laufrichtung in Kartenkoordinaten (ZERO = stehen bleiben).
func autopilot_richtung(dungeon: Variant) -> Vector2:
	if not aktiv or _ziel.is_empty():
		return Vector2.ZERO
	if dungeon.get_instance_id() != int(_ziel["szene"]):
		_ziel_ende(Loc.pick("Szene gewechselt.", "Scene changed."))
		return Vector2.ZERO
	var jetzt := Time.get_ticks_msec()
	if jetzt - int(_ziel["start_ms"]) > AUTOPILOT_MAX_MS:
		_ziel_ende(Loc.pick("Zeit abgelaufen.", "Timed out."))
		return Vector2.ZERO
	# Neuer Verfolger? Anhalten, damit die KI entscheiden kann (kämpfen/fliehen).
	# Ist die Party weit überlegen, fliehen alle Gegner — dann kein Halt.
	var feinde: Array = [] if dungeon._ueberlegen() else dungeon._enemies
	for feind: Dictionary in feinde:
		var fid := int(feind["id"])
		if feind.get("jagd", false) and fid not in _ziel["jaeger"] \
				and not (_ziel["art"] == "gegner" and fid == int(_ziel["id"])):
			var archetyp: EnemyArchetype = feind.get("archetype")
			_ziel_ende(Loc.pick("Gegner %d (%s) hat dich entdeckt!", "Enemy %d (%s) spotted you!")
				% [fid, archetyp.display_name if archetyp != null else "?"])
			return Vector2.ZERO
	var ziel := _ziel_zelle(dungeon)
	if ziel.x < 0:
		if _autopilot_ergebnis.is_empty():
			_ziel_ende(Loc.pick("Ziel erreicht.", "Target reached."))
		else:
			_ziel = {}
		return Vector2.ZERO
	var pos: Vector2 = dungeon.player_pos
	if jetzt - int(_ziel["pruef_ms"]) > FEST_MS:
		if pos.distance_to(_ziel["pruef_pos"]) < 4.0:
			_ziel_ende(Loc.pick("Festgesteckt.", "Stuck."))
			return Vector2.ZERO
		_ziel["pruef_pos"] = pos
		_ziel["pruef_ms"] = jetzt
	var map: DungeonMap = dungeon.map
	var hier: Vector2i = dungeon._pos_to_cell(pos)
	var mitte_hier := DungeonMap.cell_center_px(hier)
	if hier == ziel:
		if pos.distance_to(mitte_hier) < 3.0:
			_ziel_ende(Loc.pick("Ziel erreicht.", "Target reached."))
			return Vector2.ZERO
		return mitte_hier - pos
	if _ziel.get("dist_zelle", Vector2i(-9, -9)) != ziel:
		_ziel["dist"] = map.distances_from(ziel)
		_ziel["dist_zelle"] = ziel
	var dist: Dictionary = _ziel["dist"]
	if not dist.has(hier):
		_ziel_ende(Loc.pick("Kein Weg dorthin.", "No path there."))
		return Vector2.ZERO
	var naechste := hier
	for schritt in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var kandidat: Vector2i = hier + schritt
		if dist.has(kandidat) and int(dist[kandidat]) < int(dist[naechste]):
			naechste = kandidat
	# Richtung zur Nachbarzelle, quer dazu zurück auf die Spurmitte — so
	# bleibt der Held nicht an Wandecken hängen.
	var richtung := Vector2(naechste - hier) * float(DungeonMap.TILE_SIZE)
	var versatz := mitte_hier - pos
	if richtung.x != 0.0:
		richtung.y = versatz.y * 2.0
	else:
		richtung.x = versatz.x * 2.0
	return richtung


## Zielzelle des Autopiloten; (-1, -1) = erreicht oder weg (dann steht der
## Grund ggf. schon in _autopilot_ergebnis).
func _ziel_zelle(dungeon: Variant) -> Vector2i:
	var map: DungeonMap = dungeon.map
	var weg := Vector2i(-1, -1)
	var id := int(_ziel["id"])
	match String(_ziel["art"]):
		"gegner":
			for feind: Dictionary in dungeon._enemies:
				if int(feind["id"]) == id:
					return dungeon._pos_to_cell(feind["pos"])
		"truhe":
			for truhe: Dictionary in dungeon._chests:
				if int(truhe["id"]) == id:
					return dungeon._pos_to_cell(truhe["pos"])
		"ereignis":
			for ereignis: Dictionary in dungeon._events:
				if int(ereignis["id"]) == id:
					# Schreine verschwinden beim Benutzen; der Opferstein bleibt
					# stehen, bis man [E] drückt — dort genügt Ankommen.
					return dungeon._pos_to_cell(ereignis["pos"])
		"treppe":
			if map.stairs_cell.x >= 0 and dungeon._explored_cells.has(map.stairs_cell):
				return map.stairs_cell
		"boss":
			if dungeon._boss_alive and dungeon._explored_cells.has(map.boss_cell):
				return map.boss_cell
		"tresor":
			if not dungeon._tresor.is_empty():
				return dungeon._pos_to_cell(dungeon._tresor["pos"])
		"erkunden":
			return _naechstes_unerkundetes(dungeon)
	return weg


## Nächstes erreichbares, noch nie gesehenes Feld (Breitensuche vom Helden).
## Sobald das bisherige Erkundungsziel in Sicht kommt, ist der Schritt fertig.
func _naechstes_unerkundetes(dungeon: Variant) -> Vector2i:
	var erkundet: Dictionary = dungeon._explored_cells
	if _ziel.has("erkundungs_zelle"):
		var bisher: Vector2i = _ziel["erkundungs_zelle"]
		if erkundet.has(bisher):
			_ziel_ende(Loc.pick("Neues Gebiet in Sicht.", "New area in view."))
			return Vector2i(-1, -1)
		return bisher
	var map: DungeonMap = dungeon.map
	var start: Vector2i = dungeon._pos_to_cell(dungeon.player_pos)
	var dist := map.distances_from(start)
	var beste := Vector2i(-1, -1)
	var beste_weg := 1 << 30
	for zelle in dist:
		if not erkundet.has(zelle) and int(dist[zelle]) < beste_weg:
			beste = zelle
			beste_weg = int(dist[zelle])
	if beste.x < 0:
		_autopilot_ergebnis = Loc.pick("Diese Ebene ist komplett erkundet.", "This floor is fully explored.")
		return beste
	_ziel["erkundungs_zelle"] = beste
	return beste


# --- Helfer ----------------------------------------------------------------------

func _gs() -> Variant:
	return get_node_or_null(^"/root/GameState")


static func _ohne_bbcode(text: String) -> String:
	# Nur BBCode-Tags entfernen — Tastenhinweise wie „[E]“ bleiben stehen.
	var regex := RegEx.create_from_string("\\[/?(b|i|u|s|color|bgcolor|font|font_size|outline_size|outline_color|url|center|right|wave|shake|rainbow|pulse|img|code)\\b[^\\]]*\\]")
	return regex.sub(text, "", true)
