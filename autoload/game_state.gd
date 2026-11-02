extends Node
## Autoload "GameState": persistenter Spielzustand über Szenenwechsel hinweg —
## Party, Gold, Karten, Inventar, Wissen — gespeichert über SaveManager.

var gold := 150
## Altbestand: Klötze, die in alten Spielständen am (gestrichenen)
## Forschungstisch freigeschaltet wurden — bleiben frei.
var researched: Array[StringName] = []
var party: Array[Combatant] = []
## Taverne-Bank: angeheuerte Helden, die gerade NICHT in der Party sind.
## Sie kämpfen nicht, bekommen kein XP und machen Platz für Co-op-Gäste.
var reserve: Array[Combatant] = []
var inventory: Array[ItemInstance] = []
## Taschenlimit (Lutz 2026-10-31): so viele Teile passen in die Taschen,
## angelegte Ausrüstung zählt nicht mit. Ältere Stände darüber behalten
## alles — es kommt nur keine neue Beute dazu, bis wieder Platz ist.
const TASCHEN_LIMIT := 300
## Beute, die bei vollen Taschen nicht mehr hineinpasste: wird gespeichert
## und aufgenommen, sobald Platz ist (oder per „Liegen lassen“ verworfen).
var beute_warteliste: Array[ItemInstance] = []

## Verbrauchsgegenstände stacken: ID » Anzahl.
var consumables: Dictionary = {}

## Crafting-Materialien (droppen von Gegnern/Truhen): ID » Anzahl.
var materials: Dictionary = {}

## Kartenlager: begrenzt, aber gegen Gold erweiterbar (siehe Design).
var cards: Array[DungeonCard] = []
var card_capacity := 25
## Archiv: aufbewahrte Lieblings-/Farmkarten außerhalb des Lagers (eigene Plätze).
var card_archive: Array[DungeonCard] = []
const ARCHIV_PLAETZE := 15
var storage_expansions := 0

## Händler-Aufträge: 3 rotierende Aufgaben (siehe MerchantOrders).
var merchant_orders: Array[Dictionary] = []

## Bestiarium: Grundtyp-ID » Anzahl Kills (fürs Monster-Lexikon).
var bestiary: Dictionary = {}

## Mini-Medaillen (DQ-Sammelschiene): selten aus Truhen/Bossen, beim
## Händler gegen Spezial-Belohnungen eintauschbar.
var medals := 0
## Insgesamt gesammelte Mini-Medaillen (Ausgeben zählt nicht dagegen) und
## Zahl der abgeholten Medaillen-Stufen (MedaillenStufen).
var medaillen_gesamt := 0
var medaillen_stufen := 0


## Mini-Medaillen erhalten — zählt auch für die Medaillen-Stufen.
func medaille(anzahl := 1) -> void:
	medals += anzahl
	medaillen_gesamt += anzahl
	bilanz_add("medaillen", anzahl)

## Bestiarium-Stufen (BestiariumStufen): Zahl der abgeholten Stufen und die
## dadurch freigeschalteten Rüstungsfarben (FigurenBau.SONDER_FARBEN-IDs).
var bestiarium_stufen := 0
var farben_frei: Array[StringName] = []

## Chronik (Lexikon „Chronik“, keine Belohnung): Zähler über den ganzen
## Spielstand — "dungeons", "bosse", "hoechste_stufe", "kaempfe",
## "helden_gefallen", "wiedergeburten", "gold" (verdient). Alte Stände
## starten aus den vorhandenen Daten (_chronik_aus_altbestand).
var chronik: Dictionary = {}


func chronik_add(schluessel: String, wert := 1) -> void:
	chronik[schluessel] = chronik_wert(schluessel) + wert


func chronik_wert(schluessel: String) -> int:
	return int(chronik.get(schluessel, 0))


## Eigener Dungeon abgeschlossen (Boss der Karte besiegt).
func chronik_dungeon(card: DungeonCard) -> void:
	chronik_add("dungeons")
	chronik_add("bosse")
	chronik["hoechste_stufe"] = maxi(chronik_wert("hoechste_stufe"), card.tier)


## Alte Spielstände ohne Chronik: was sich aus Karten und Helden ablesen
## lässt (Abschlüsse der noch vorhandenen Karten, Wiedergeburten), sonst 0.
func _chronik_aus_altbestand() -> Dictionary:
	var abschluesse := 0
	var hoechste := 0
	for card in cards + card_archive:
		abschluesse += card.times_completed
		if card.times_completed > 0:
			hoechste = maxi(hoechste, card.tier)
	var wiedergeburten := 0
	for member in party + reserve:
		wiedergeburten += member.rebirths
	return {"dungeons": abschluesse, "bosse": abschluesse, "hoechste_stufe": hoechste,
		"wiedergeburten": wiedergeburten}


## Grundtypen, die mindestens einmal besiegt wurden (Bestiarium-Fortschritt).
func entdeckte_grundtypen() -> int:
	var anzahl := 0
	for archetype in EnemyLibrary.all_archetypes():
		if kills_of(archetype.id) > 0:
			anzahl += 1
	return anzahl


## Was beim Händler abholbar ist: erfüllte Aufträge, erreichte Medaillen-
## und Bestiarium-Stufen (Zahl am Stadt-Knopf im Hub).
func abholbar_anzahl() -> int:
	var anzahl := 0
	for order in merchant_orders:
		if MerchantOrders.is_complete(order, self):
			anzahl += 1
	var stufe := medaillen_stufen
	while MedaillenStufen.abholbar(medaillen_gesamt, stufe):
		anzahl += 1
		stufe += 1
	var entdeckt := entdeckte_grundtypen()
	stufe = bestiarium_stufen
	while BestiariumStufen.abholbar(entdeckt, stufe):
		anzahl += 1
		stufe += 1
	return anzahl


## Text des Stadt-Knopfs im Hub: sachliche Zahl, wenn beim Händler etwas
## abholbar ist (abholbar_anzahl). Hier statt im Hauptmenü, damit der
## Selbsttest ihn ohne die Menü-Szene prüfen kann.
static func stadt_text(abholbar: int) -> String:
	var haendler := Loc.pick("Händler", "merchant")
	if abholbar > 0:
		haendler += Loc.pick(" (%d abgebbar)", " (%d to claim)") % abholbar
	return Loc.pick("Stadt  —  Taverne · %s · Schmiede", "Town  —  tavern · %s · smithy") % haendler

## Onboarding: IDs der schon gezeigten Einmal-Hinweise — wird gespeichert.
var hints_seen: Array = []


## true genau EINMAL pro Spielstand — markiert den Hinweis als gesehen.
func first_time(hint_id: String) -> bool:
	if hint_id in hints_seen:
		return false
	hints_seen.append(hint_id)
	return true


func record_kill(archetype_id: StringName) -> void:
	if archetype_id == &"":
		return
	bestiary[archetype_id] = int(bestiary.get(archetype_id, 0)) + 1


func kills_of(archetype_id: StringName) -> int:
	return int(bestiary.get(archetype_id, 0))


## Element-Wissen (Bestiarium): Schlüssel (Combatant.wissens_schluessel)
## » entdeckte Elemente, deren Schwäche/Resistenz man im Kampf erlebt hat.
var element_wissen: Dictionary = {}


## Merkt sich eine Entdeckung — true, wenn sie neu war.
func entdecke_element(schluessel: String, element: int) -> bool:
	if schluessel.is_empty():
		return false
	var bekannt: Array = element_wissen.get(schluessel, [])
	if element in bekannt:
		return false
	bekannt.append(element)
	element_wissen[schluessel] = bekannt
	return true


func kennt_element(schluessel: String, element: int) -> bool:
	return element in element_wissen.get(schluessel, [])


## Gegner-Eigenheiten, die man im Kampf erlebt hat (Grundtyp-IDs).
var eigenheit_wissen: Array = []


## Merkt sich eine Eigenheit — true, wenn sie neu war.
func entdecke_eigenheit(archetype_id: String) -> bool:
	if archetype_id.is_empty() or archetype_id in eigenheit_wissen:
		return false
	eigenheit_wissen.append(archetype_id)
	return true


func kennt_eigenheit(archetype_id: String) -> bool:
	return archetype_id in eigenheit_wissen


## Sprache ("de"/"en", später mehr) — gespiegelt nach Loc, wird gespeichert.
var language := "de":
	set(value):
		language = value
		Loc.set_language(value)

## Laufender Dungeon-Besuch: {"card": DungeonCard, "defeated": Array[int],
## "opened": Array[int], "player_pos": Vector2, "boss_defeated": bool,
## "explored_by_floor": {floor_index: Dictionary[Vector2i, bool]}}.
## Leer = kein aktiver Run. Nur die Karte + Fortschritt werden gehalten,
## das Layout selbst kommt deterministisch aus dem Karten-Seed.
## explored_by_floor hält den Fog-of-War-Fortschritt über Szenenwechsel
## (z.B. Kämpfe) hinweg am Leben — er wird nur bei einer neuen Ebene oder
## einem neuen Dungeon-Run zurückgesetzt, nicht nach jedem Kampf.
var current_run: Dictionary = {}

## Übergabe an die Kampfszene: {"enemy_id": int, "is_boss": bool,
## "enemies": Array[Combatant]}. Leer = normaler Testkampf aus dem Menü.
var pending_battle: Dictionary = {}

## Wohin "Zurück" in UI-Szenen führt (z.B. Inventar aus dem Dungeon heraus
## geöffnet » zurück in den Dungeon statt ins Menü). Leer = Hauptmenü.
var ui_return_scene := ""

## Co-op-Gast: current_run gehört gerade der Welt des HOSTS (per Netz
## übernommen) — er wird nie gespeichert und beim Verlassen verworfen.
var coop_guest_run := false

## Co-op-Gast: Info-Paket des laufenden Host-Kampfes ("host", "fighters",
## "is_boss") — Übergabe der Dungeon-Szene an die Co-op-Kampfansicht.
var coop_battle: Dictionary = {}

## Nach einer Flucht: dieser Dungeon-Gegner (globale ID) schnappt nicht
## sofort wieder zu, bis die Party auf Abstand ist. Nicht gespeichert.
var flee_grace_enemy := -1
## Die Schonfrist endet spätestens dann (Spieltest 9: ein jagender Gegner
## blieb endlos neben dem Helden stehen, ohne zu kämpfen).
const FLUCHT_SCHONFRIST_MS := 4000
var flee_grace_bis_ms := 0
## Ab diesem Vielfachen der Kontaktweite gilt die Party als „auf Abstand“.
const FLUCHT_ABSTAND_FAKTOR := 2.5


## Schützt die Schonfrist den Gegner noch? Endet, sobald die Party auf
## Abstand war ODER die Zeit abgelaufen ist. (Reine Funktion, nicht static:
## der Aufruf über das Autoload bliebe sonst eine Editor-Warnung.)
func schonfrist_aktiv(abstand: float, kontakt_dist: float, jetzt_ms: int,
		bis_ms: int) -> bool:
	return abstand <= kontakt_dist * FLUCHT_ABSTAND_FAKTOR and jetzt_ms <= bis_ms


## Gesamte Spielzeit dieses Spielstands in Sekunden (pro Slot gespeichert).
var spielzeit_s := 0.0

## Ergebnis des letzten Ladens, falls es etwas zu melden gibt (Sicherung
## geladen / Datei unlesbar): {"slot", "zustand", "zeit"}. Das Hauptmenü
## zeigt es einmal an und leert es.
var lade_hinweis := {}
## Die Datei des aktiven Slots existiert, ist aber unlesbar und hat keine
## Sicherung: save_game() schreibt dann nichts, bis der Slot gelöscht oder
## ausdrücklich überschrieben wird.
var slot_gesperrt := false
## Inhalt des zuletzt geladenen/gespeicherten Stands (ohne Zeitstempel und
## Spielzeit) als Hash: autosave() schreibt nur, wenn sich daran etwas änderte.
var _stand_hash := 0
## Stand beim Betreten eines Kampfs (to_save_dict, tief kopiert). Wird das
## Fenster im Kampf geschlossen, gilt dieser Stand.
var stand_vor_kampf := {}

## Was das Schließen per Fenster-X speichert (beenden_modus()).
enum Beenden { NICHTS, AKTUELL, VOR_KAMPF }
const KAMPF_SZENEN := ["res://scenes/battle/battle_scene.tscn",
	"res://scenes/battle/coop_battle_scene.tscn"]


func _process(delta: float) -> void:
	spielzeit_s += delta


func _ready() -> void:
	# Fenster-X selbst behandeln, damit vorher gespeichert wird.
	get_tree().set_auto_accept_quit(false)
	_ki_bruecke_einhaengen()
	if load_game():
		return
	# Kein (nutzbarer) Spielstand vorhanden — frischer Start. Die Party bleibt
	# LEER: Das Hauptmenü führt durch die Erstellung des ersten Helden, weitere
	# werden kostenlos in der Taverne angeheuert.
	_provision_fresh_start()


## KI-Brücke (Claude-Spieltests, autoload/ki_bruecke.gd) ist KEIN Autoload:
## Die Release-EXE enthält das Skript nicht (exclude_filter im Export-Preset),
## ein fehlendes Autoload-Skript bräche dort den Start. Eingehängt wird sie
## nur aus dem Quelltext (Editor-Build der Engine) mit Startschalter `--ki`
## (`godot --path . -- --ki`) als /root/KiBruecke.
const KI_BRUECKE_PFAD := "res://autoload/ki_bruecke.gd"


static func ki_bruecke_gewuenscht(args: PackedStringArray, editor_build: bool) -> bool:
	return editor_build and "--ki" in args


func _ki_bruecke_einhaengen() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if not ki_bruecke_gewuenscht(args, OS.has_feature("editor")):
		return
	if not ResourceLoader.exists(KI_BRUECKE_PFAD):
		return
	var bruecke: Node = load(KI_BRUECKE_PFAD).new()
	bruecke.name = "KiBruecke"
	# Die Wurzel baut gerade die Autoloads auf: erst danach einhängen.
	get_tree().root.add_child.call_deferred(bruecke)


## Startausstattung eines neuen Spielstands (auch beim Slot-Neustart).
func _provision_fresh_start() -> void:
	if cards.is_empty():
		# Zwei Startkarten, damit es direkt losgehen kann.
		cards.append(CardFactory.make_starter_card())
		cards.append(CardFactory.make_starter_card())
	if consumables.is_empty():
		# Startvorrat als Puffer gegen die Dungeon-Attrition.
		add_consumable(&"heiltrank", 3)
		add_consumable(&"manatrank", 1)
	if materials.is_empty():
		add_material(&"heilkraut", 2)


## Alles auf Anfang (für einen leeren Spielstand-Slot). Sprache bleibt.
func reset_to_new_game() -> void:
	gold = 150
	spielzeit_s = 0.0
	researched.clear()
	party.clear()
	reserve.clear()
	inventory.clear()
	beute_warteliste.clear()
	consumables.clear()
	materials.clear()
	cards.clear()
	card_capacity = 25
	card_archive.clear()
	storage_expansions = 0
	merchant_orders.clear()
	bestiary.clear()
	element_wissen.clear()
	eigenheit_wissen.clear()
	medals = 0
	medaillen_gesamt = 0
	medaillen_stufen = 0
	bestiarium_stufen = 0
	farben_frei.clear()
	chronik.clear()
	hints_seen.clear()
	current_run = {}
	pending_battle = {}
	coop_guest_run = false
	_provision_fresh_start()


## Spielstand-Slot wechseln: aktuellen Stand sichern, dann den Ziel-Slot
## laden — oder frisch starten, wenn er leer ist. Der gewählte Slot wird
## in den Einstellungen gemerkt (überlebt den Neustart). Ein unlesbarer
## Slot ohne Sicherung wird nicht betreten (false).
func switch_to_slot(slot: int) -> bool:
	if SaveManager.lesen(SaveManager.path_for_slot(slot))["zustand"] == SaveManager.DEFEKT:
		return false
	autosave()
	SaveManager.active_slot = slot
	if is_inside_tree():
		var settings := get_node_or_null(^"/root/Settings")
		if settings != null:
			settings.save_slot = slot
			settings.save_settings()
	if not load_game():
		reset_to_new_game()
		save_game()  # den neuen Slot direkt anlegen
	return true


## Aktuellen Stand in einen anderen Slot legen und diesen aktiv machen
## ("Hierher speichern") — lädt nichts, kopiert nur.
func switch_to_active_copy(slot: int) -> void:
	SaveManager.active_slot = slot
	# Ausdrücklich bestätigt: eine unlesbare Datei dort wird nach .defekt
	# verschoben (SaveManager.save) und darf überschrieben werden.
	slot_gesperrt = false
	if is_inside_tree():
		var settings := get_node_or_null(^"/root/Settings")
		if settings != null:
			settings.save_slot = slot
			settings.save_settings()
	save_game()


## EINE Einlass-Stelle für neue Gegenstände (Kampfbeute, Truhen, Tresor,
## Schmiede, Händler, Koop-Gewinne). true = in den Taschen; false = die
## Taschen sind voll, der Gegenstand wartet in der Warteliste.
func item_aufnehmen(item: ItemInstance) -> bool:
	if item == null:
		return false
	warteliste_nachruecken()
	# Wartet schon etwas, stellt sich Neues hinten an (Reihenfolge bleibt).
	if beute_warteliste.is_empty() and inventory.size() < TASCHEN_LIMIT:
		inventory.append(item)
		return true
	beute_warteliste.append(item)
	return false


## Freie Plätze in den Taschen (0, wenn voll oder überfüllt).
func taschen_frei() -> int:
	return maxi(0, TASCHEN_LIMIT - inventory.size())


## Wartende Beute in die Taschen, soweit Platz ist. Gibt die Anzahl zurück.
func warteliste_nachruecken() -> int:
	var aufgenommen := 0
	while not beute_warteliste.is_empty() and inventory.size() < TASCHEN_LIMIT:
		inventory.append(beute_warteliste.pop_front())
		aufgenommen += 1
	return aufgenommen


## „Liegen lassen“: die wartende Beute verfällt. Gibt die Anzahl zurück.
func warteliste_verwerfen() -> int:
	var anzahl := beute_warteliste.size()
	beute_warteliste.clear()
	return anzahl


## Gewöhnliche Teile in den Taschen (nicht angelegt): {"anzahl", "gold"}.
func gewoehnliche_wert() -> Dictionary:
	var anzahl := 0
	var wert := 0
	for item in inventory:
		if item.rarity == Enums.Rarity.COMMON:
			anzahl += 1
			wert += LootGenerator.sell_price(item)
	return {"anzahl": anzahl, "gold": wert}


## Verkauft alle gewöhnlichen Teile aus den Taschen: {"anzahl", "gold"}.
func gewoehnliche_verkaufen() -> Dictionary:
	var ergebnis := gewoehnliche_wert()
	var behalten: Array[ItemInstance] = []
	for item in inventory:
		if item.rarity != Enums.Rarity.COMMON:
			behalten.append(item)
	inventory.clear()
	inventory.append_array(behalten)
	gold += int(ergebnis["gold"])
	return ergebnis


func add_consumable(id: StringName, amount := 1) -> void:
	consumables[id] = consumable_count(id) + amount


func consumable_count(id: StringName) -> int:
	return consumables.get(id, 0)


## Verbraucht ein Exemplar. false, wenn keins da ist.
func consume(id: StringName) -> bool:
	if consumable_count(id) <= 0:
		return false
	consumables[id] -= 1
	if consumables[id] <= 0:
		consumables.erase(id)
	return true


func add_material(id: StringName, amount := 1) -> void:
	materials[id] = material_count(id) + amount


func material_count(id: StringName) -> int:
	return materials.get(id, 0)


## Kosten-Helfer für Schmiede & Co.: {"gold": int, "materials": {id: Anzahl}}.
func can_pay(cost: Dictionary) -> bool:
	if gold < cost.get("gold", 0):
		return false
	var mats: Dictionary = cost.get("materials", {})
	for id in mats:
		if material_count(id) < mats[id]:
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_pay(cost):
		return false
	gold -= cost.get("gold", 0)
	var mats: Dictionary = cost.get("materials", {})
	for id in mats:
		materials[id] -= mats[id]
		if materials[id] <= 0:
			materials.erase(id)
	return true


## Höchstes (je erreichtes) Level der Party — Obergrenze fürs Schmieden.
func highest_party_level() -> int:
	var best := 1
	for member in party:
		best = maxi(best, maxi(member.level, member.peak_level))
	return best


## Bank-Training (Lutz 2026-10-16, Variante C): Bank-Helden fallen nie ganz
## zurück, überholen aber niemanden.
##  • Mittraining: nach jedem Sieg 10 % der Kampf-XP — bis 5 Level unter dem
##    schwächsten aktiven Helden.
##  • Taverne-Training: gegen Gold sofort auf dieselbe Grenze (Goldsenke;
##    ein Level kostet die Beute von ~10 Kämpfen auf diesem Level).
const BANK_MITTRAINING := 0.1
const BANK_ABSTAND := 5
const TRAINING_KAEMPFE_JE_LEVEL := 10


## Level, bis zu dem Bank-Helden mittrainieren (0 = keine Party).
func bank_ziel_level() -> int:
	var tiefst := 0
	for member in party:
		if member.has_meta(&"guest_peer"):
			continue
		tiefst = member.level if tiefst == 0 else mini(tiefst, member.level)
	return maxi(1, tiefst - BANK_ABSTAND) if tiefst > 0 else 0


## XP, die `held` bis Level `ziel` noch fehlen (vor dem Wiedergeburts-Bonus).
static func xp_bis_level(held: Combatant, ziel: int) -> int:
	if held.level >= ziel:
		return 0
	var noetig := Combatant.xp_bedarf(held.level) - held.xp
	for stufe in range(held.level + 1, ziel):
		noetig += Combatant.xp_bedarf(stufe)
	return maxi(1, noetig)


## Mittraining nach einem Sieg. Gibt die Aufstiege zurück („Edda Lv 12“).
func bank_mittraining(xp_kampf: int) -> Array[String]:
	var aufstiege: Array[String] = []
	var ziel := bank_ziel_level()
	if ziel <= 0 or xp_kampf <= 0:
		return aufstiege
	for held in reserve:
		var fehlt := xp_bis_level(held, ziel)
		if fehlt <= 0:
			continue
		var vorher := held.level
		held.gain_xp(mini(fehlt, maxi(1, roundi(xp_kampf * BANK_MITTRAINING))))
		if held.level > vorher:
			aufstiege.append("%s Lv %d" % [held.display_name, held.level])
	return aufstiege


static func training_preis_je_level(stufe: int) -> int:
	return roundi(TRAINING_KAEMPFE_JE_LEVEL * (8 + stufe * 4) * Scaling.factor(stufe))


## Goldpreis, um `held` in der Taverne auf das Bank-Ziel zu bringen.
func training_kosten(held: Combatant) -> int:
	var kosten := 0
	for stufe in range(held.level, bank_ziel_level()):
		kosten += training_preis_je_level(stufe)
	return kosten


func bank_trainieren(held: Combatant) -> bool:
	var ziel := bank_ziel_level()
	var kosten := training_kosten(held)
	if held not in reserve or held.level >= ziel or gold < kosten:
		return false
	gold -= kosten
	held.gain_xp(xp_bis_level(held, ziel))
	return true


## Durchschnittliches Party-Level (Basis für Händler-Ware).
func average_party_level() -> int:
	if party.is_empty():
		return 1
	var total := 0
	for member in party:
		total += member.level
	return maxi(1, roundi(float(total) / party.size()))


## Einfache Tränke beim Händler kaufen.
func buy(def: ConsumableDef) -> bool:
	if def.price <= 0 or gold < def.price:
		return false
	gold -= def.price
	add_consumable(def.id)
	return true


## Prüft, ob Materialien + Zutaten-Tränke fürs Rezept reichen.
func can_craft(def: ConsumableDef) -> bool:
	if not def.is_craftable():
		return false
	for id in def.craft_materials:
		if material_count(id) < def.craft_materials[id]:
			return false
	for id in def.craft_consumables:
		if consumable_count(id) < def.craft_consumables[id]:
			return false
	return true


## Craftet einen Trank beim Alchemisten (verbraucht das Rezept).
func craft(def: ConsumableDef) -> bool:
	if not can_craft(def):
		return false
	for id in def.craft_materials:
		materials[id] -= def.craft_materials[id]
		if materials[id] <= 0:
			materials.erase(id)
	for id in def.craft_consumables:
		for i in def.craft_consumables[id]:
			consume(id)
	add_consumable(def.id)
	return true


## Karte ins Lager legen. false, wenn das Lager voll ist (Karte verfällt —
## bewusste Design-Konsequenz des begrenzten Lagers).
func add_card(card: DungeonCard) -> bool:
	if cards.size() >= card_capacity:
		return false
	cards.append(card)
	return true


func delete_card(card: DungeonCard) -> void:
	cards.erase(card)
	card_archive.erase(card)


## Karte ins Archiv legen (false: Archiv voll).
func archive_card(card: DungeonCard) -> bool:
	if card_archive.size() >= ARCHIV_PLAETZE or not cards.has(card):
		return false
	cards.erase(card)
	card_archive.append(card)
	return true


## Karte aus dem Archiv zurück ins Lager (false: Lager voll).
func unarchive_card(card: DungeonCard) -> bool:
	if cards.size() >= card_capacity or not card_archive.has(card):
		return false
	card_archive.erase(card)
	cards.append(card)
	return true


func storage_expansion_cost() -> int:
	return 100 + storage_expansions * 50


func can_expand_storage() -> bool:
	return gold >= storage_expansion_cost()


## Lager gegen Gold um 5 Slots erweitern.
func expand_storage() -> bool:
	if not can_expand_storage():
		return false
	gold -= storage_expansion_cost()
	card_capacity += 5
	storage_expansions += 1
	return true


# --- Händler-Aufträge ----------------------------------------------------------

## Freie Auftrags-Slots nachfüllen (beim Betreten des Händlers).
func ensure_orders() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while merchant_orders.size() < MerchantOrders.ORDER_SLOTS:
		merchant_orders.append(MerchantOrders.make_order(average_party_level(), rng, self))


## Erfüllten Auftrag abgeben: zieht bei Lieferaufträgen die Materialien ein,
## gewährt die Belohnung und rückt einen neuen Auftrag nach.
func claim_order(order: Dictionary) -> bool:
	if order not in merchant_orders or not MerchantOrders.is_complete(order, self):
		return false
	var reward: Dictionary = order["reward"]
	# Wunsch-Karte braucht Platz im Lager — sonst bleibt der Auftrag offen.
	if reward["kind"] == "card" and cards.size() >= card_capacity:
		return false
	if order["type"] == "deliver":
		if not pay({"materials": {order["material"]: order["count"]}}):
			return false
	match reward["kind"]:
		"gold":
			gold += reward["gold"]
		"materials":
			for id in reward["materials"]:
				add_material(id, reward["materials"][id])
		"card":
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			add_card(CardFactory.make_card(average_party_level(), rng, reward["biome"]))
	merchant_orders.erase(order)
	ensure_orders()
	return true


## Kampf gewonnen » Jagd-Aufträge zählen mit.
func note_kills(count: int) -> void:
	for order in merchant_orders:
		if order["type"] == "hunt":
			order["progress"] = mini(int(order["count"]), int(order["progress"]) + count)


## Kampf gewonnen » Grundtyp-, Elite- und Boss-Aufträge zählen mit
## (besiegte = gefallene Gegner ohne Beschwörungen).
func note_kampf_auftraege(besiegte: Array, is_boss: bool, card: DungeonCard) -> void:
	MerchantOrders.kampf_zaehlen(merchant_orders, besiegte, is_boss, card)


## Eine Gegner-Eigenheit hat im Kampf gewirkt » Eigenheits-Aufträge zählen mit.
func note_eigenheit(eigenheit: StringName) -> void:
	MerchantOrders.eigenheit_zaehlen(merchant_orders, eigenheit)


## Karte abgeschlossen (Boss besiegt) » passende Abschluss-Aufträge erfüllen.
func note_card_cleared(card: DungeonCard) -> void:
	for order in merchant_orders:
		if order["type"] == "clear" and int(order["progress"]) < 1 \
				and card.biome == int(order["biome"]) and card.tier >= int(order["min_tier"]):
			order["progress"] = 1


# --- Bilanz eines Laufs ----------------------------------------------------------

## Bilanz für „Dungeon abgeschlossen“: Summen über den Lauf. items =
## Rarität (int) » Anzahl; start_s = Spielzeit beim Start; teilweise = der
## Lauf begann in einem älteren Stand ohne Bilanz.
func neue_bilanz(teilweise := false) -> Dictionary:
	return {"gold": 0, "xp": 0, "items": {}, "medaillen": 0, "materialien": 0,
		"kaempfe": 0, "level_auf": 0, "start_s": spielzeit_s, "teilweise": teilweise}


## Zählt in der Bilanz des laufenden Laufs mit (ohne Lauf: nichts).
## Verdientes Gold zählt zusätzlich in der Chronik.
func bilanz_add(schluessel: String, wert := 1) -> void:
	if wert == 0:
		return
	if schluessel == "gold":
		chronik_add("gold", wert)
	if current_run.is_empty():
		return
	var bilanz := _bilanz()
	bilanz[schluessel] = int(bilanz.get(schluessel, 0)) + wert


func bilanz_item(rarity: int) -> void:
	if current_run.is_empty():
		return
	var items: Dictionary = _bilanz()["items"]
	items[rarity] = int(items.get(rarity, 0)) + 1


func _bilanz() -> Dictionary:
	if not current_run.has("bilanz"):
		current_run["bilanz"] = neue_bilanz(true)
	var bilanz: Dictionary = current_run["bilanz"]
	if not bilanz.has("items"):
		bilanz["items"] = {}
	return bilanz


## Sachliche Zeilen der Bilanz (leer, wenn es keine gibt). spielzeit = die
## aktuelle Gesamt-Spielzeit (für die Dauer).
static func bilanz_zeilen(bilanz: Dictionary, spielzeit: float) -> Array[String]:
	var zeilen: Array[String] = []
	if bilanz.is_empty():
		return zeilen
	zeilen.append(Loc.pick("Kämpfe %d  ·  +%d XP  ·  +%d Gold", "Battles %d  ·  +%d XP  ·  +%d gold")
		% [int(bilanz.get("kaempfe", 0)), int(bilanz.get("xp", 0)), int(bilanz.get("gold", 0))])
	var items: Dictionary = bilanz.get("items", {})
	var teile: Array[String] = []
	for rarity in [Enums.Rarity.LEGENDARY, Enums.Rarity.EPIC, Enums.Rarity.RARE,
			Enums.Rarity.MAGIC, Enums.Rarity.COMMON]:
		var anzahl := int(items.get(rarity, items.get(str(rarity), 0)))
		if anzahl > 0:
			teile.append("%d %s" % [anzahl, LootGenerator.rarity_name(rarity)])
	zeilen.append(Loc.pick("Items: %s", "Items: %s") % (", ".join(teile) if not teile.is_empty()
		else Loc.pick("keine", "none")))
	var minuten := maxi(0, roundi((spielzeit - float(bilanz.get("start_s", spielzeit))) / 60.0))
	zeilen.append(Loc.pick("+%d Mini-Medaillen  ·  +%d Materialien  ·  %d Level-Aufstiege  ·  %d Min.",
		"+%d mini medals  ·  +%d materials  ·  %d level-ups  ·  %d min") % [int(bilanz.get("medaillen", 0)),
		int(bilanz.get("materialien", 0)), int(bilanz.get("level_auf", 0)), minuten])
	if bilanz.get("teilweise", false):
		zeilen.append(Loc.pick("(Bilanz unvollständig: der Lauf begann vor dieser Version)",
			"(Summary incomplete: the run started before this version)"))
	return zeilen


func start_run(card: DungeonCard) -> void:
	# Das Hub heilt: Jeder Run startet mit frischer Party (HP und MP voll).
	heal_party()
	current_run = {
		"card": card,
		"floor": 0,
		"defeated": [],
		"opened": [],
		"events_used": [],
		"player_pos": Vector2.ZERO,
		"boss_defeated": false,
		"bilanz": neue_bilanz(),
	}
	coop_guest_run = false
	# Co-op: „Karte von (Spielername) — joinen“ an alle Gäste.
	var net := _net()
	if net != null:
		net.notify_map_opened()


func clear_run() -> void:
	current_run = {}
	pending_battle = {}
	coop_guest_run = false
	coop_battle = {}
	# Zurück im Hub: volle Heilung für HP und MP.
	heal_party()
	var net := _net()
	if net != null:
		net.notify_map_closed()


## Das Net-Autoload, falls vorhanden (Selbsttests laufen ohne Autoloads).
func _net() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null(^"/root/Net")


func heal_party() -> void:
	for member in party:
		member.reset_for_battle(true)
	# Die Bank sitzt in der Taverne — immer ausgeruht.
	for member in reserve:
		member.reset_for_battle(true)


## Held in der Taverne ERSTELLEN — kostenlos, freier Name + Porträt + Kit,
## bis zu 10 Helden. Ist die Party voll (4), wartet der Neue auf der Bank.
## Kein Permadeath im Spiel: Gefallene stehen nach dem Kampf wieder auf,
## die Taverne dient dem AUFBAU.
func recruit(hero_name: String, kit_id: StringName, portrait_tile := -1) -> bool:
	var trimmed := hero_name.strip_edges()
	if trimmed.is_empty():
		return false
	if hero_count() >= HeroLibrary.MAX_HEROES:
		return false
	# Namen müssen eindeutig sein (Co-op und Speicherstände hängen daran).
	for member in party + reserve:
		if member.display_name == trimmed:
			return false
	var hero := HeroLibrary.create_hero(trimmed, kit_id, portrait_tile)
	if party.size() < HeroLibrary.MAX_PARTY_SIZE:
		party.append(hero)
	else:
		reserve.append(hero)
	return true


## Party-Held auf die Taverne-Bank legen (macht z.B. Platz für Co-op-
## Gäste). Der letzte eigene Held bleibt immer aktiv; Gast-Helden gehören
## ihrem Spieler und sind nicht ablegbar.
func bench_hero(hero: Combatant) -> bool:
	if hero not in party or hero.has_meta(&"guest_peer"):
		return false
	var own_count := 0
	for member in party:
		if not member.has_meta(&"guest_peer"):
			own_count += 1
	if own_count <= 1:
		return false
	hero.set_meta(&"party_platz", party.find(hero))
	party.erase(hero)
	reserve.append(hero)
	return true


## Eigene Helden (Party + Bank, ohne Co-op-Gäste) — fürs 10er-Limit.
func hero_count() -> int:
	var count := reserve.size()
	for member in party:
		if not member.has_meta(&"guest_peer"):
			count += 1
	return count


## Bank-Held zurück in die Party holen (wenn ein Slot frei ist).
func activate_hero(hero: Combatant) -> bool:
	if hero not in reserve or party.size() >= HeroLibrary.MAX_PARTY_SIZE:
		return false
	reserve.erase(hero)
	# Alter Platz in der Party (Spieltest 2026-10-24: Reihenfolge änderte sich).
	var platz := int(hero.get_meta(&"party_platz", party.size()))
	party.insert(clampi(platz, 0, party.size()), hero)
	hero.remove_meta(&"party_platz")
	return true


## Level-Klötze gelten ab dem HÖCHSTEN je erreichten Level als frei — nach
## einer Wiedergeburt bleiben alle Klötze in der Werkstatt nutzbar.
func is_block_unlocked(block: SkillBlock, char_level: int,
		hero: Combatant = null) -> bool:
	if hero != null:
		char_level = maxi(char_level, hero.peak_level)
	return BlockLibrary.is_unlocked(block, char_level, researched, hero)


# --- Speichersystem ----------------------------------------------------------
# Reine Serialisierung (to_save_dict/apply_save_dict) ist von der Datei-I/O
# (SaveManager) getrennt, damit sich der Rundweg ohne Festplattenzugriff
# testen lässt.

## pfad nur für Selbsttests (eigener Testpfad); sonst der aktive Slot.
func save_game(pfad := "") -> bool:
	if slot_gesperrt:
		return false
	var data := to_save_dict()
	var ok := SaveManager.save(data, pfad if not pfad.is_empty() else SaveManager.active_path())
	if ok and pfad.is_empty():
		_stand_hash = inhalt_hash(data)
	return ok


## Automatisches Sichern (Hub, Slot-Wechsel): schreibt nur, wenn sich der
## Inhalt seit dem letzten Laden/Speichern geändert hat. Spielstart und Laden
## allein ändern so weder Datei noch „zuletzt gespielt“ (Spieltest 11, Fund 6).
func autosave() -> bool:
	if slot_gesperrt or inhalt_hash(to_save_dict()) == _stand_hash:
		return false
	return save_game()


## Hash des Spielstand-Inhalts ohne Zeitstempel und Spielzeit.
static func inhalt_hash(data: Dictionary) -> int:
	var inhalt := data.duplicate()
	inhalt.erase("saved_at")
	inhalt.erase("playtime_s")
	return inhalt.hash()


## true, wenn ein nutzbarer Spielstand geladen und übernommen wurde (auch
## aus der Sicherung). Setzt lade_hinweis und slot_gesperrt.
func load_game(pfad := "") -> bool:
	var ergebnis := SaveManager.lesen(pfad if not pfad.is_empty() else SaveManager.active_path())
	var zustand: String = ergebnis["zustand"]
	slot_gesperrt = zustand == SaveManager.DEFEKT
	lade_hinweis = {}
	if zustand == SaveManager.SICHERUNG or zustand == SaveManager.DEFEKT:
		lade_hinweis = {"slot": SaveManager.active_slot, "zustand": zustand,
			"zeit": ergebnis["sicherung_von"]}
	var data: Dictionary = ergebnis["daten"]
	if data.is_empty():
		_stand_hash = 0
		return false
	apply_save_dict(data)
	if pfad.is_empty():
		_stand_hash = inhalt_hash(to_save_dict())
	return true


## Text zum lade_hinweis (leer = nichts zu melden).
func lade_hinweis_text() -> String:
	if lade_hinweis.is_empty():
		return ""
	var slot := int(lade_hinweis["slot"])
	if lade_hinweis["zustand"] == SaveManager.SICHERUNG:
		return Loc.pick("Slot %d: Spielstand-Datei nicht lesbar. Sicherung von %s geladen.",
			"Slot %d: save file unreadable. Backup from %s loaded.") % [slot,
			String(lade_hinweis["zeit"]).replace("T", " ")]
	return Loc.pick("Slot %d: Spielstand-Datei nicht lesbar, keine Sicherung vorhanden. In diesen Slot wird nicht gespeichert, bis er unter „Spielstände“ gelöscht oder überschrieben wird.",
		"Slot %d: save file unreadable, no backup available. Nothing is saved to this slot until it is deleted or overwritten under 'Save games'.") % slot


## Fenster-X: je nach Szene speichern, Co-op trennen, beenden.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST:
		return
	# Zuerst: quit() beendet erst nach diesem Bild. Bricht das Speichern mit
	# einem Skriptfehler ab, schließt das Fenster trotzdem (auto_accept_quit
	# ist aus — sonst ginge es gar nicht mehr zu).
	get_tree().quit()
	var szene := ""
	if get_tree().current_scene != null:
		szene = get_tree().current_scene.scene_file_path
	var net := _net()
	var gast: bool = coop_guest_run or (net != null and net.is_guest())
	match beenden_modus(szene, gast):
		Beenden.AKTUELL:
			save_game()
		Beenden.VOR_KAMPF:
			if not stand_vor_kampf.is_empty() and not slot_gesperrt:
				SaveManager.save(stand_vor_kampf, SaveManager.active_path())
	if net != null and net.is_online():
		net.stop()


## Was beim Schließen gespeichert wird: nichts in Dev-Szenen und als
## Co-op-Gast, im Kampf der Stand vor dem Kampf, sonst der aktuelle Stand.
static func beenden_modus(szene: String, gast: bool) -> Beenden:
	if szene.is_empty() or szene.begins_with("res://scripts/dev/") or gast:
		return Beenden.NICHTS
	if szene in KAMPF_SZENEN:
		return Beenden.VOR_KAMPF
	return Beenden.AKTUELL


## Beim Betreten eines Kampfs: den Stand davor merken (tief kopiert — der
## Run teilt sonst Listen wie "defeated" mit dem laufenden Zustand).
func stand_vor_kampf_merken() -> void:
	stand_vor_kampf = to_save_dict().duplicate(true)


func has_save_file() -> bool:
	return SaveManager.has_save(SaveManager.active_path())


func to_save_dict() -> Dictionary:
	var researched_list: Array = []
	for id in researched:
		researched_list.append(String(id))

	var party_list: Array = []
	for member in party:
		# Co-op-Gast-Helden gehören dem Gast, nicht diesem Spielstand.
		if member.has_meta(&"guest_peer"):
			continue
		party_list.append(member.to_dict())

	var reserve_list: Array = []
	for member in reserve:
		reserve_list.append(member.to_dict())

	var inventory_list: Array = []
	for item in inventory:
		inventory_list.append(item.to_dict())
	var warteliste_list: Array = []
	for item in beute_warteliste:
		warteliste_list.append(item.to_dict())

	var consumables_dict := {}
	for id in consumables:
		consumables_dict[String(id)] = consumables[id]

	var materials_dict := {}
	for id in materials:
		materials_dict[String(id)] = materials[id]

	var cards_list: Array = []
	for card in cards:
		cards_list.append(card.to_dict())
	var archiv_list: Array = []
	for card in card_archive:
		archiv_list.append(card.to_dict())

	var orders_list: Array = []
	for order in merchant_orders:
		orders_list.append(MerchantOrders.to_dict(order))

	var bestiary_dict := {}
	for id in bestiary:
		bestiary_dict[String(id)] = bestiary[id]

	var data := {
		"version": 1,
		"gold": gold,
		"researched": researched_list,
		"party": party_list,
		"inventory": inventory_list,
		"beute_warteliste": warteliste_list,
		"consumables": consumables_dict,
		"materials": materials_dict,
		"cards": cards_list,
		"card_capacity": card_capacity,
		"card_archive": archiv_list,
		"storage_expansions": storage_expansions,
		"merchant_orders": orders_list,
		"language": language,
		"bestiary": bestiary_dict,
		"element_wissen": element_wissen.duplicate(true),
		"eigenheit_wissen": eigenheit_wissen.duplicate(),
		"medals": medals,
		"medaillen_gesamt": medaillen_gesamt,
		"medaillen_stufen": medaillen_stufen,
		"bestiarium_stufen": bestiarium_stufen,
		"farben_frei": farben_frei.map(func(id: StringName) -> String: return String(id)),
		"chronik": chronik.duplicate(),
		"hints_seen": hints_seen,
		"reserve": reserve_list,
		# Für die Spielstand-Übersicht (Slot-Auswahl).
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"playtime_s": spielzeit_s,
	}
	# Der Run eines Co-op-Gasts gehört der Welt des Hosts — nie speichern.
	if not current_run.is_empty() and not coop_guest_run:
		data["current_run"] = _run_to_dict(current_run)
	return data


func apply_save_dict(data: Dictionary) -> void:
	gold = int(data.get("gold", 150))
	spielzeit_s = float(data.get("playtime_s", 0.0))

	researched.clear()
	for id_str in data.get("researched", []):
		researched.append(StringName(id_str))

	party.clear()
	for member_data in data.get("party", []):
		party.append(Combatant.from_dict(member_data))

	reserve.clear()
	for member_data in data.get("reserve", []):
		reserve.append(Combatant.from_dict(member_data))

	inventory.clear()
	for item_data in data.get("inventory", []):
		var item := ItemInstance.from_dict(item_data)
		if item != null:
			inventory.append(item)
	beute_warteliste.clear()
	for item_data in data.get("beute_warteliste", []):
		var item := ItemInstance.from_dict(item_data)
		if item != null:
			beute_warteliste.append(item)

	consumables.clear()
	for id_str in data.get("consumables", {}).keys():
		consumables[StringName(id_str)] = int(data["consumables"][id_str])

	materials.clear()
	for id_str in data.get("materials", {}).keys():
		materials[StringName(id_str)] = int(data["materials"][id_str])

	cards.clear()
	for card_data in data.get("cards", []):
		cards.append(DungeonCard.from_dict(card_data))
	card_archive.clear()
	for card_data in data.get("card_archive", []):
		card_archive.append(DungeonCard.from_dict(card_data))

	card_capacity = int(data.get("card_capacity", 25))
	storage_expansions = int(data.get("storage_expansions", 0))

	merchant_orders.clear()
	for order_data in data.get("merchant_orders", []):
		merchant_orders.append(MerchantOrders.from_dict(order_data))

	language = String(data.get("language", "de"))

	bestiary.clear()
	for id_str in data.get("bestiary", {}).keys():
		bestiary[StringName(id_str)] = int(data["bestiary"][id_str])

	element_wissen.clear()
	var wissen: Dictionary = data.get("element_wissen", {})
	for schluessel in wissen:
		var elemente: Array = []
		for element in wissen[schluessel]:
			elemente.append(int(element))
		element_wissen[String(schluessel)] = elemente
	eigenheit_wissen.clear()
	for id in data.get("eigenheit_wissen", []):
		eigenheit_wissen.append(String(id))

	medals = int(data.get("medals", 0))
	# Alte Spielstände: mindestens die vorhandenen Medaillen zählen als gesammelt.
	medaillen_gesamt = maxi(int(data.get("medaillen_gesamt", 0)), medals)
	medaillen_stufen = int(data.get("medaillen_stufen", 0))
	bestiarium_stufen = int(data.get("bestiarium_stufen", 0))
	farben_frei.clear()
	for id in data.get("farben_frei", []):
		if StringName(id) not in farben_frei:
			farben_frei.append(StringName(id))
	chronik.clear()
	var chronik_daten: Dictionary = data.get("chronik", _chronik_aus_altbestand())
	for schluessel in chronik_daten:
		chronik[String(schluessel)] = int(chronik_daten[schluessel])
	hints_seen = data.get("hints_seen", [])

	current_run = {}
	if data.has("current_run"):
		current_run = _run_from_dict(data["current_run"])
	pending_battle = {}


func _run_to_dict(run: Dictionary) -> Dictionary:
	var explored_out := {}
	var explored_by_floor: Dictionary = run.get("explored_by_floor", {})
	for floor_idx in explored_by_floor:
		var cells: Array = []
		for cell in explored_by_floor[floor_idx]:
			cells.append([cell.x, cell.y])
		explored_out[str(floor_idx)] = cells
	var pos: Vector2 = run.get("player_pos", Vector2.ZERO)
	var out := {
		"card": run["card"].to_dict(),
		"floor": run.get("floor", 0),
		"defeated": run.get("defeated", []),
		"opened": run.get("opened", []),
		"events_used": run.get("events_used", []),
		"player_pos": [pos.x, pos.y],
		"boss_defeated": run.get("boss_defeated", false),
		"explored_by_floor": explored_out,
	}
	if run.has("gegner_by_floor"):
		out["gegner_by_floor"] = run["gegner_by_floor"]
	if run.has("blessing"):
		out["blessing"] = String(run["blessing"])
	# Geöffnete Tresore und schon gezeigte Ebenen-Hinweise (je Ebene).
	for liste in ["tresore", "hinweise", "schluessel"]:
		if run.has(liste):
			out[liste] = run[liste]
	if run.has("bilanz"):
		var bilanz: Dictionary = (run["bilanz"] as Dictionary).duplicate(true)
		var items := {}
		for rarity in bilanz.get("items", {}):
			items[str(rarity)] = int(bilanz["items"][rarity])
		bilanz["items"] = items
		out["bilanz"] = bilanz
	return out


func _run_from_dict(data: Dictionary) -> Dictionary:
	var explored_by_floor := {}
	var explored_in: Dictionary = data.get("explored_by_floor", {})
	for floor_str in explored_in.keys():
		var cells := {}
		for pair in explored_in[floor_str]:
			cells[Vector2i(int(pair[0]), int(pair[1]))] = true
		explored_by_floor[int(floor_str)] = cells
	var pos: Array = data.get("player_pos", [0, 0])
	var defeated: Array = []
	for id in data.get("defeated", []):
		defeated.append(int(id))
	var opened: Array = []
	for id in data.get("opened", []):
		opened.append(int(id))
	var events_used: Array = []
	for id in data.get("events_used", []):
		events_used.append(int(id))
	var run := {
		"card": DungeonCard.from_dict(data.get("card", {})),
		"floor": int(data.get("floor", 0)),
		"defeated": defeated,
		"opened": opened,
		"events_used": events_used,
		"player_pos": Vector2(float(pos[0]), float(pos[1])),
		"boss_defeated": bool(data.get("boss_defeated", false)),
		"explored_by_floor": explored_by_floor,
	}
	if data.has("gegner_by_floor"):
		run["gegner_by_floor"] = (data["gegner_by_floor"] as Dictionary).duplicate(true)
	if data.has("blessing"):
		run["blessing"] = StringName(data["blessing"])
	for liste in ["tresore", "hinweise", "schluessel"]:
		if data.has(liste):
			run[liste] = (data[liste] as Array).map(func(e: Variant) -> int: return int(e))
	# Bilanz; ein Lauf aus einem älteren Stand bekommt eine Teil-Bilanz ab jetzt.
	var gespeichert: Dictionary = data.get("bilanz", {})
	var bilanz := neue_bilanz(not data.has("bilanz"))
	for schluessel in ["gold", "xp", "medaillen", "materialien", "kaempfe", "level_auf"]:
		bilanz[schluessel] = int(gespeichert.get(schluessel, 0))
	bilanz["start_s"] = float(gespeichert.get("start_s", spielzeit_s))
	bilanz["teilweise"] = bool(gespeichert.get("teilweise", bilanz["teilweise"]))
	var items_in: Dictionary = gespeichert.get("items", {})
	for rarity_str in items_in:
		bilanz["items"][int(rarity_str)] = int(items_in[rarity_str])
	run["bilanz"] = bilanz
	return run
