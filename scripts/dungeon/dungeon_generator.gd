class_name DungeonGenerator
extends RefCounted
## Prozedurale Dungeon-Generierung, komplett deterministisch aus dem Seed
## der DungeonCard: gleiche Karte = gleiches Layout, gleiche Gegner- und
## Truhen-Positionen — die Grundlage für wiederholbare, farmbare Karten.
##
## Drei Layout-Stile, pro Ebene deterministisch gewählt (Abwechslung!):
##   CAVES   — organische Höhlen (Drunkard's Walk)
##   ROOMS   — klassischer Dungeon: rechteckige Räume + Korridore
##   TUNNELS — langgezogenes, verwinkeltes Ganggeflecht

enum Layout { CAVES, ROOMS, TUNNELS }

## Dungeon-Events (KEINE Fallen — Design-Entscheidung): Schreine helfen,
## Opfersteine tauschen HP gegen Schätze, Risiko-Truhen locken mit dicker
## Beute — oder einem Mimic.
## HAENDLER/GEFANGENER (2026-11-02): seltene Ereignisse aus DungeonEreignisse
## (eigener Würfel, hinten angehängt — alte Typ-Nummern bleiben gleich).
enum EventType { SHRINE_HEAL, SHRINE_MANA, SHRINE_POWER, SHRINE_WARD, SACRIFICE, RISK_CHEST,
	HAENDLER, GEFANGENER }

const FLOOR_RATIO := 0.30       ## Zielanteil Boden (CAVES)
const TUNNEL_RATIO := 0.22      ## Zielanteil Boden (TUNNELS — enger)
const WALKER_COUNT := 4

## Kartengröße wächst mit der Stufe: alle 5 Stufen +10 in Breite UND Höhe
## (gedeckelt), damit hohe Karten sich weitläufig anfühlen. Die Dichte an
## Gegnern/Truhen wächst mit, sonst wirken große Ebenen leer.
const BASE_WIDTH := 48
const BASE_HEIGHT := 36
const SIZE_STEP := 10
const SIZE_STEP_MAX := 4        ## Deckel: +40 (88×76 ab Stufe 20)
const MIN_ENEMY_SPAWN_DIST := 8
const MIN_ENEMY_SPACING := 5
const MIN_CHEST_DIST := 5
const CHEST_COUNT := 3
## Seltene Karten: je Raritätsstufe der Karte eine Chance, die Truhe aufzuwerten.
const TRUHEN_BONUS_JE_KARTENSTUFE := 0.3
## Höchstens so viele Tiefen-Würfe auf +1 Truhen-Rarität (früher tiefste Ebene 5).
const TRUHEN_TIEFE_MAX := 4
const EVENT_COUNT := 2
const MIN_EVENT_DIST := 6


## Welcher Layout-Stil auf dieser Ebene liegt — deterministisch aus dem
## Karten-Seed, damit die Ebenen einer Karte abwechslungsreich, aber bei
## jedem Besuch identisch sind.
static func layout_for(card: DungeonCard, floor_index: int) -> Layout:
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + floor_index * 911
	var bevorzugt := grundriss_neigung(card)
	if bevorzugt < 0:
		return rng.randi_range(0, 2) as Layout
	# Ort-Neigung: der bevorzugte Stil 3 von 5, die anderen je 1 von 5.
	var wurf := rng.randi_range(0, ORT_GEWICHT + 1)
	if wurf < ORT_GEWICHT:
		return bevorzugt as Layout
	var andere: Array = [0, 1, 2]
	andere.erase(bevorzugt)
	return andere[wurf - ORT_GEWICHT] as Layout


## Grundriss-Neigung je Ort (Lutz 2026-11-02): der Ort im Kartennamen
## gewichtet die drei Layout-Stile — Stollen, Gänge und Pfade eher Tunnel,
## Hain, Hof und Keller eher Räume, Spalten und Schächte eher Höhlen.
## Index = Ort in CardFactory.BIOME_PLACES[Biom]. Gilt nur für Karten ab
## Grundriss-Version 1 (DungeonCard.grundriss_version) — ältere Karten
## behalten ihren Grundriss (eine laufende Ebene wird aus dem Seed neu
## erzeugt und muss gleich bleiben).
const ORT_GRUNDRISS := {
	Enums.Biome.FOREST: [Layout.ROOMS, Layout.CAVES, Layout.TUNNELS],          # Hain, Forst, Pfad
	Enums.Biome.CAVE: [Layout.TUNNELS, Layout.CAVES, Layout.CAVES],            # Stollen, Schacht, Spalt
	Enums.Biome.RUINS: [Layout.ROOMS, Layout.TUNNELS, Layout.ROOMS],           # Tempel, Turm, Hof
	Enums.Biome.CRYPT: [Layout.TUNNELS, Layout.ROOMS, Layout.CAVES],           # Totengang, Knochenkeller, Seelenschacht
	Enums.Biome.INFERNAL: [Layout.TUNNELS, Layout.CAVES, Layout.ROOMS],        # Schlund, Krater, Kessel
}
const ORT_GEWICHT := 3


## Bevorzugter Layout-Stil der Karte, -1 = keine Neigung (alte Karte,
## Startkarte, fester Name).
static func grundriss_neigung(card: DungeonCard) -> int:
	if card.grundriss_version < 1 or card.name_teile.size() != 3:
		return -1
	var orte: Array = ORT_GRUNDRISS.get(card.biome, [])
	var ort := int(card.name_teile[1])
	if ort < 0 or ort >= orte.size():
		return -1
	return int(orte[ort])


## Größen-Schritte einer Karte (alle 5 Stufen einer, gedeckelt).
static func size_steps(tier: int) -> int:
	return mini(SIZE_STEP_MAX, tier / 5)


## Gegnergruppen pro Ebene (Design-Review 2026-10-17: weniger Gegner, mehr
## XP): 8 + 2 je Größenstufe, also 8 bis 16. Vorher 6 + Stufe + 2 je
## Größenstufe — auf Stufe 50 über 60 Gruppen pro Ebene.
const GRUPPEN_BASIS := 8
const GRUPPEN_ALT_DECKEL := 68  ## so viele passten früher höchstens auf eine Ebene


static func gegner_gruppen(tier: int) -> int:
	return GRUPPEN_BASIS + size_steps(tier) * 2


## Ausgleich für die kleinere Gegnerzahl: XP, Gold und Beute normaler Gegner
## steigen so, dass eine Ebene insgesamt so viel abwirft wie vorher.
static func beute_faktor(tier: int) -> float:
	var alt := mini(6 + maxi(1, tier) + size_steps(tier) * 2, GRUPPEN_ALT_DECKEL)
	return maxf(1.0, float(alt) / gegner_gruppen(tier))


## Endlose Ebenen (Lutz 2026-11-09): Jede Karte hat unendlich viele Ebenen.
## Jede dritte Ebene (Ebene 3, 6, 9 … = Index 2, 5, 8 …) ist eine Boss-Ebene;
## danach geht es per Treppe weiter. Die Gegner steigen alle drei Ebenen um
## eine Stufe (ein „Abschnitt“ = zwei normale Ebenen + Boss-Ebene), jeder
## fünfte Boss ist ein großer Boss, alle zehn Ebenen beginnt eine neue Tiefe.
const BOSS_ALLE := 3
const GROSSER_BOSS_ALLE := 5
const TIEFE_ALLE := 10

## Boss-Ebene (Lutz 2026-10-24): ein einfacher Gang, der in einen Raum mit
## dem Boss mündet. Sonst nichts: keine Gegner, Truhen, Events, kein Tresor.
## Der Gang ist 3 Felder breit und steigt in Stufen nach rechts oben.
const BOSS_GANG_LAENGE := 28    ## waagerechte Strecke insgesamt
const BOSS_GANG_ANSTIEG := 10   ## senkrechte Strecke insgesamt
const BOSS_GANG_BREITE := 3
const BOSS_RAUM := 9


static func ist_boss_ebene(_card: DungeonCard, floor_index: int) -> bool:
	return floor_index >= 0 and (floor_index + 1) % BOSS_ALLE == 0


## Wievielter Boss auf dieser Ebene wartet (1, 2, 3 …); 0 = keine Boss-Ebene.
static func boss_nummer(floor_index: int) -> int:
	return (floor_index + 1) / BOSS_ALLE if (floor_index + 1) % BOSS_ALLE == 0 else 0


## Jeder fünfte Boss (Ebene 15, 30, 45 …) ist ein großer Boss.
static func ist_grosser_boss(floor_index: int) -> bool:
	var nummer := boss_nummer(floor_index)
	return nummer > 0 and nummer % GROSSER_BOSS_ALLE == 0


## Stufen-Bonus der Ebene: +1 alle drei Ebenen (Boss gehört zu seinem Abschnitt).
static func tiefen_bonus(floor_index: int) -> int:
	return maxi(0, floor_index) / BOSS_ALLE


## Gegnerstufe einer Ebene: Kartenstufe + Tiefen-Bonus + Raritäts-Bonus.
## Gilt auch für Truhen, Tresor und Kampfbeute dieser Ebene.
static func gegner_stufe(card: DungeonCard, floor_index: int) -> int:
	return card.tier + tiefen_bonus(floor_index) + card.rarity_level_bonus()


## Tiefe (0 = Ebene 1–10, 1 = Ebene 11–20 …): dunkleres Licht und ab Tiefe 1
## eine Kampfregel (Sonderregeln.tiefen_regel_fuer).
static func tiefe(floor_index: int) -> int:
	return maxi(0, floor_index) / TIEFE_ALLE


static func _boss_ebene() -> DungeonMap:
	var map := DungeonMap.new()
	var rand := 2 + BOSS_GANG_BREITE / 2
	var raum_x := rand + BOSS_GANG_LAENGE
	var raum_mitte := 2 + BOSS_RAUM / 2
	map.width = raum_x + BOSS_RAUM + 2
	map.height = raum_mitte + BOSS_GANG_ANSTIEG + rand
	map.cells.resize(map.width * map.height)
	var pos := Vector2i(rand, raum_mitte + BOSS_GANG_ANSTIEG)
	map.spawn = pos
	# Rechts, hoch, rechts, hoch, rechts — jeweils mit einem 3×3-Pinsel gezogen.
	var waagerecht := [BOSS_GANG_LAENGE * 10 / 28, BOSS_GANG_LAENGE * 10 / 28,
		BOSS_GANG_LAENGE - 2 * (BOSS_GANG_LAENGE * 10 / 28)]
	var senkrecht := BOSS_GANG_ANSTIEG / 2
	for teil in 3:
		for _schritt in waagerecht[teil]:
			_gang_pinsel(map, pos)
			pos.x += 1
		if teil < 2:
			for _schritt in senkrecht:
				_gang_pinsel(map, pos)
				pos.y -= 1
	_gang_pinsel(map, pos)
	for x in range(raum_x, raum_x + BOSS_RAUM):
		for y in range(raum_mitte - BOSS_RAUM / 2, raum_mitte + BOSS_RAUM / 2 + 1):
			map.set_floor(Vector2i(x, y))
	map.has_boss = true
	map.boss_cell = Vector2i(raum_x + BOSS_RAUM - 3, raum_mitte)
	return map


static func _gang_pinsel(map: DungeonMap, mitte: Vector2i) -> void:
	var halb := BOSS_GANG_BREITE / 2
	for dx in range(-halb, halb + 1):
		for dy in range(-halb, halb + 1):
			map.set_floor(mitte + Vector2i(dx, dy))


static func generate(card: DungeonCard, floor_index := 0,
		width := -1, height := -1) -> DungeonMap:
	if ist_boss_ebene(card, floor_index):
		return _boss_ebene()
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + floor_index * 31337

	var steps := size_steps(card.tier)
	if width <= 0:
		width = BASE_WIDTH + steps * SIZE_STEP
	if height <= 0:
		height = BASE_HEIGHT + steps * SIZE_STEP

	var map := DungeonMap.new()
	map.width = width
	map.height = height
	map.cells.resize(width * height)

	match layout_for(card, floor_index):
		Layout.CAVES:
			_carve_caves(map, rng)
		Layout.ROOMS:
			_carve_rooms(map, rng)
		Layout.TUNNELS:
			_carve_tunnels(map, rng)

	map.spawn = Vector2i(width / 2, height / 2)
	map.set_floor(map.spawn)
	# Vom Spawn aus unerreichbare Bodenzellen wieder zumauern — dort dürfen
	# nie Gegner, Truhen oder der Boss landen.
	_prune_unreachable(map)

	var dist := map.distances_from(map.spawn)
	var landmark := _farthest_cell(dist)
	# Normale Ebenen führen immer per Treppe weiter (jede dritte ist die Boss-Ebene).
	map.stairs_cell = landmark

	# Karten-Affixe verändern die Bevölkerung der Ebene; größere Karten
	# bekommen mehr Gegner, Truhen und Events (Dichte bleibt erlebbar).
	var enemy_count := gegner_gruppen(card.tier)
	if &"bevoelkert" in card.card_affix_ids:
		enemy_count += 3
	var chest_count := CHEST_COUNT + steps
	if &"schatz" in card.card_affix_ids:
		chest_count += 2
	if card.sonderregel == Sonderregeln.SCHATZFIEBER:
		chest_count *= 2

	var event_count := EVENT_COUNT + steps
	if card.tier >= 5:
		event_count += 1

	_place_enemies(map, rng, dist, enemy_count)
	_place_chests(map, rng, dist, gegner_stufe(card, floor_index), chest_count, floor_index, card)
	_place_events(map, rng, dist, event_count)
	# Mimics stehen NICHT in der Karte fest: jede Truhe würfelt beim Öffnen
	# (Lutz 2026-10-24 — man soll sie vorher nicht erkennen oder sich merken).
	_place_tresor(map, card, floor_index, dist)
	# Seltene Ereignisse (Händler, Gefangener) — eigener Würfel je Ebene.
	DungeonEreignisse.platzieren(map, card, floor_index, dist)
	return map


## Ebenen-Ziel Tresor (Design-Review 2026-10-17): ab Gegnerstufe 2 der Ebene
## (Kartenstufe + Tiefe, seit 2026-11-09) auf jeder 4.
## Ebene (Sonder-Dungeons jede 2.) — ein Gegner der Ebene trägt den Schlüssel.
## Eigener Würfel: Layout und Gegner bestehender Karten bleiben gleich.
const TRESOR_AB_STUFE := 2
const TRESOR_CHANCE := 0.25
const TRESOR_CHANCE_SONDER := 0.5
const TRESOR_MIN_DIST := 10


static func _place_tresor(map: DungeonMap, card: DungeonCard, floor_index: int, dist: Dictionary) -> void:
	if gegner_stufe(card, floor_index) < TRESOR_AB_STUFE or map.enemies.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([card.seed, floor_index, "tresor"])
	var chance := TRESOR_CHANCE_SONDER if card.sonderregel != &"" else TRESOR_CHANCE
	if rng.randf() >= chance:
		return
	var used: Array[Vector2i] = [map.boss_cell, map.stairs_cell, map.spawn]
	for liste in [map.enemies, map.chests, map.events]:
		for eintrag in liste:
			used.append(eintrag["cell"])
	for cell in _shuffled_floor(map, rng):
		if dist.has(cell) and dist[cell] >= TRESOR_MIN_DIST and cell not in used:
			map.tresor_cell = cell
			map.schluessel_id = int(map.enemies[rng.randi_range(0, map.enemies.size() - 1)]["id"])
			return


# --- Layout-Stile --------------------------------------------------------------

## Organische Höhlen: mehrere Läufer graben sich durch den Fels.
static func _carve_caves(map: DungeonMap, rng: RandomNumberGenerator) -> void:
	var target := int(map.width * map.height * FLOOR_RATIO)
	var center := Vector2i(map.width / 2, map.height / 2)
	var walkers: Array[Vector2i] = []
	for i in WALKER_COUNT:
		walkers.append(center)

	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var carved := 0
	while carved < target:
		for i in walkers.size():
			var pos := walkers[i]
			if not map.is_floor(pos):
				map.set_floor(pos)
				carved += 1
			pos += dirs[rng.randi_range(0, 3)]
			pos.x = clampi(pos.x, 1, map.width - 2)
			pos.y = clampi(pos.y, 1, map.height - 2)
			walkers[i] = pos


## Klassischer Dungeon: rechteckige Räume, nacheinander mit L-förmigen
## Korridoren verbunden (plus Ringschluss für Schleifen im Layout).
static func _carve_rooms(map: DungeonMap, rng: RandomNumberGenerator) -> void:
	var centers: Array[Vector2i] = []
	var room_count := rng.randi_range(6, 9)

	# Erster Raum liegt immer um den Spawn in der Kartenmitte.
	var center := Vector2i(map.width / 2, map.height / 2)
	_carve_room(map, center, rng.randi_range(4, 7), rng.randi_range(4, 6))
	centers.append(center)

	for i in room_count - 1:
		var w := rng.randi_range(4, 8)
		var h := rng.randi_range(4, 7)
		var pos := Vector2i(
			rng.randi_range(2 + w / 2, map.width - 3 - w / 2),
			rng.randi_range(2 + h / 2, map.height - 3 - h / 2))
		_carve_room(map, pos, w, h)
		centers.append(pos)

	for i in centers.size() - 1:
		_carve_corridor(map, centers[i], centers[i + 1])
	# Ringschluss: letzter Raum zurück zum ersten » Schleifen statt Sackgassen-Baum.
	_carve_corridor(map, centers[centers.size() - 1], centers[0])


static func _carve_room(map: DungeonMap, center: Vector2i, w: int, h: int) -> void:
	for y in range(center.y - h / 2, center.y + (h + 1) / 2):
		for x in range(center.x - w / 2, center.x + (w + 1) / 2):
			var cell := Vector2i(clampi(x, 1, map.width - 2), clampi(y, 1, map.height - 2))
			map.set_floor(cell)


## L-förmiger, 2 Zellen breiter Korridor zwischen zwei Punkten.
static func _carve_corridor(map: DungeonMap, from: Vector2i, to: Vector2i) -> void:
	var pos := from
	while pos.x != to.x:
		pos.x += signi(to.x - pos.x)
		map.set_floor(Vector2i(clampi(pos.x, 1, map.width - 2), clampi(pos.y, 1, map.height - 2)))
		map.set_floor(Vector2i(clampi(pos.x, 1, map.width - 2), clampi(pos.y + 1, 1, map.height - 2)))
	while pos.y != to.y:
		pos.y += signi(to.y - pos.y)
		map.set_floor(Vector2i(clampi(pos.x, 1, map.width - 2), clampi(pos.y, 1, map.height - 2)))
		map.set_floor(Vector2i(clampi(pos.x + 1, 1, map.width - 2), clampi(pos.y, 1, map.height - 2)))


## Verwinkeltes Ganggeflecht: Läufer mit Richtungs-Trägheit graben lange,
## gewundene Gänge (~2 Zellen breit).
static func _carve_tunnels(map: DungeonMap, rng: RandomNumberGenerator) -> void:
	var target := int(map.width * map.height * TUNNEL_RATIO)
	var center := Vector2i(map.width / 2, map.height / 2)
	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

	var walkers: Array[Vector2i] = []
	var headings: Array[Vector2i] = []
	for i in 3:
		walkers.append(center)
		headings.append(dirs[rng.randi_range(0, 3)])

	var carved := 0
	while carved < target:
		for i in walkers.size():
			var pos := walkers[i]
			if not map.is_floor(pos):
				map.set_floor(pos)
				carved += 1
			# Gang verbreitern: eine Nachbarzelle quer zur Laufrichtung.
			var side := Vector2i(headings[i].y, headings[i].x)
			var widen := pos + side
			widen.x = clampi(widen.x, 1, map.width - 2)
			widen.y = clampi(widen.y, 1, map.height - 2)
			if not map.is_floor(widen):
				map.set_floor(widen)
				carved += 1
			# Trägheit: meist geradeaus, gelegentlich abbiegen.
			if rng.randf() < 0.25:
				headings[i] = dirs[rng.randi_range(0, 3)]
			pos += headings[i]
			if pos.x <= 1 or pos.x >= map.width - 2 or pos.y <= 1 or pos.y >= map.height - 2:
				headings[i] = dirs[rng.randi_range(0, 3)]
			pos.x = clampi(pos.x, 1, map.width - 2)
			pos.y = clampi(pos.y, 1, map.height - 2)
			walkers[i] = pos


## Alles, was vom Spawn aus nicht erreichbar ist, wird wieder Wand.
static func _prune_unreachable(map: DungeonMap) -> void:
	var dist := map.distances_from(map.spawn)
	for cell in map.floor_cells():
		if not dist.has(cell):
			map.cells[cell.y * map.width + cell.x] = 0


static func _farthest_cell(dist: Dictionary) -> Vector2i:
	var best := Vector2i.ZERO
	var best_dist := -1
	for cell in dist:
		if dist[cell] > best_dist:
			best_dist = dist[cell]
			best = cell
	return best


static func _place_enemies(map: DungeonMap, rng: RandomNumberGenerator,
		dist: Dictionary, enemy_count: int) -> void:
	var candidates := _shuffled_floor(map, rng)
	var placed: Array[Vector2i] = []
	var next_id := 0
	for cell in candidates:
		if placed.size() >= enemy_count:
			break
		if not dist.has(cell) or dist[cell] < MIN_ENEMY_SPAWN_DIST:
			continue
		if cell == map.boss_cell or cell == map.stairs_cell:
			continue
		var too_close := false
		for other in placed:
			if (cell - other).length() < MIN_ENEMY_SPACING:
				too_close = true
				break
		if too_close:
			continue
		placed.append(cell)
		map.enemies.append({"id": next_id, "cell": cell})
		next_id += 1


static func _place_chests(map: DungeonMap, rng: RandomNumberGenerator,
		dist: Dictionary, tier: int, chest_count: int, floor_index := 0,
		card: DungeonCard = null) -> void:
	# Seltene Karten haben bessere Truhen: je Karten-Raritätsstufe eine
	# weitere Chance auf eine Stufe mehr. Eigener Würfel, damit Layout und
	# Events bestehender Karten gleich bleiben.
	var karten_rng := RandomNumberGenerator.new()
	var karten_bonus := 0
	if card != null:
		karten_rng.seed = hash([card.seed, floor_index, "truhen"])
		karten_bonus = int(card.card_rarity)
	var used: Array[Vector2i] = [map.boss_cell, map.stairs_cell]
	for enemy in map.enemies:
		used.append(enemy["cell"])
	var candidates := _shuffled_floor(map, rng)
	var next_id := 0
	for cell in candidates:
		if next_id >= chest_count:
			break
		if not dist.has(cell) or dist[cell] < MIN_CHEST_DIST or cell in used:
			continue
		used.append(cell)
		# Truhen-Rarität: bestimmt die Rarität des Items IN der Truhe
		# (jede Truhe enthält genau eines), nicht dessen Häufigkeit.
		# DQ9-Prinzip: tiefere Ebenen haben bessere Truhen — pro Ebene
		# eine Chance, die Rarität eine Stufe anzuheben. Gedeckelt wie bei
		# der früher tiefsten Ebene (5), sonst wären endlose Ebenen bald
		# nur noch legendär.
		var rarity := LootGenerator.roll_rarity(rng)
		for depth in mini(floor_index, TRUHEN_TIEFE_MAX):
			if rng.randf() < 0.35:
				rarity = mini(rarity + 1, Enums.Rarity.LEGENDARY) as Enums.Rarity
		for stufe in karten_bonus:
			if karten_rng.randf() < TRUHEN_BONUS_JE_KARTENSTUFE:
				rarity = mini(rarity + 1, Enums.Rarity.LEGENDARY) as Enums.Rarity
		map.chests.append({
			"id": next_id, "cell": cell,
			# Gold wächst mit der Welt-Kurve wie Kampfgold (Spieltest 2026-10-23).
			"gold": roundi((20 + tier * 10 + rng.randi_range(0, 15)) * Scaling.factor(tier)),
			"rarity": rarity,
		})
		next_id += 1


## Events deterministisch platzieren (gleiche Karte = gleiche Events an
## gleichen Orten). Gewichtung: Schreine häufig, Risiko-Truhen und
## Opfersteine seltener.
static func _place_events(map: DungeonMap, rng: RandomNumberGenerator,
		dist: Dictionary, event_count: int) -> void:
	var used: Array[Vector2i] = [map.boss_cell, map.stairs_cell]
	for enemy in map.enemies:
		used.append(enemy["cell"])
	for chest in map.chests:
		used.append(chest["cell"])
	var candidates := _shuffled_floor(map, rng)
	var next_id := 0
	for cell in candidates:
		if next_id >= event_count:
			break
		if not dist.has(cell) or dist[cell] < MIN_EVENT_DIST or cell in used:
			continue
		used.append(cell)
		map.events.append({"id": next_id, "cell": cell, "type": _roll_event_type(rng)})
		next_id += 1


static func _roll_event_type(rng: RandomNumberGenerator) -> EventType:
	var roll := rng.randf()
	if roll < 0.5:
		return [EventType.SHRINE_HEAL, EventType.SHRINE_MANA,
			EventType.SHRINE_POWER, EventType.SHRINE_WARD][rng.randi_range(0, 3)]
	if roll < 0.8:
		return EventType.RISK_CHEST
	return EventType.SACRIFICE


static func _shuffled_floor(map: DungeonMap, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells := map.floor_cells()
	# Fisher-Yates mit dem Karten-RNG (Array.shuffle() wäre nicht seed-stabil).
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	return cells


# --- Ereignis-Werte und -Texte ------------------------------------------------------
# Eine Quelle für Hinweis (vor [E]), Ergebnis-Meldung und Kampf-Segen, damit
# Zahlen und Sprache überall gleich sind (Dungeon, Kampf, Co-op-Host).

const SCHREIN_HEIL_ANTEIL := 0.4    ## Heilschrein: Anteil der Max-HP
const SCHREIN_MANA_ANTEIL := 0.4    ## Manaschrein: Anteil der Max-MP
const OPFER_ANTEIL := 0.15          ## Opferstein: Anteil der Max-HP pro Held
const SEGEN_KRAFT := 25             ## Kraftschrein: Angriff +% im nächsten Kampf
const SEGEN_SCHUTZ := 30            ## Schutzschrein: Rüstung +% im nächsten Kampf
const SEGEN_RUNDEN := 3


static func _prozent(anteil: float) -> int:
	return roundi(anteil * 100)


## Wirkung eines Schrein-Segens im Kampf: [Status, Stärke]; leer = kein Segen.
static func segen_status(blessing: StringName) -> Array:
	match blessing:
		&"segen_kraft":
			return [Enums.Status.ATK_UP, SEGEN_KRAFT]
		&"segen_schutz":
			return [Enums.Status.DEF_UP, SEGEN_SCHUTZ]
	return []


## „Angriff +25%“ / „attack +25%“.
static func segen_wirkung(blessing: StringName) -> String:
	if blessing == &"segen_kraft":
		return Loc.pick("Angriff +%d%%", "attack +%d%%") % SEGEN_KRAFT
	return Loc.pick("Rüstung +%d%%", "armor +%d%%") % SEGEN_SCHUTZ


static func _segen_runden() -> String:
	return Loc.anzahl(SEGEN_RUNDEN, "Runde", "Runden", "round", "rounds")


## Meldung zu Kampfbeginn, wenn ein Segen wirkt.
static func segen_notiz(blessing: StringName) -> String:
	return Loc.pick("Der Schrein-Segen liegt auf der Party (%s, %s)!",
		"The shrine blessing is on the party (%s, %s)!") % [segen_wirkung(blessing), _segen_runden()]


## Hinweis vor einem [E]-Ereignis: was es tut ("" = kein [E]-Ereignis).
static func ereignis_hinweis(typ: int, taste: String) -> String:
	match typ:
		EventType.SACRIFICE:
			return Loc.pick("Opferstein [%s]: Jeder Held opfert %d%% Max-HP für Gold und Materialien.",
				"Sacrifice stone [%s]: every hero sacrifices %d%% max HP for gold and materials.") \
				% [taste, _prozent(OPFER_ANTEIL)]
		EventType.SHRINE_HEAL:
			return Loc.pick("Heilschrein [%s]: heilt die Party um %d%% Max-HP.",
				"Healing shrine [%s]: heals the party for %d%% max HP.") % [taste, _prozent(SCHREIN_HEIL_ANTEIL)]
		EventType.SHRINE_MANA:
			return Loc.pick("Manaschrein [%s]: gibt der Party %d%% Max-MP zurück.",
				"Mana shrine [%s]: restores %d%% max MP to the party.") % [taste, _prozent(SCHREIN_MANA_ANTEIL)]
		EventType.SHRINE_POWER:
			return Loc.pick("Kraftschrein [%s]: Der nächste Kampf beginnt mit %s (%s).",
				"Power shrine [%s]: the next battle starts with %s (%s).") \
				% [taste, segen_wirkung(&"segen_kraft"), _segen_runden()]
		EventType.SHRINE_WARD:
			return Loc.pick("Schutzschrein [%s]: Der nächste Kampf beginnt mit %s (%s).",
				"Ward shrine [%s]: the next battle starts with %s (%s).") \
				% [taste, segen_wirkung(&"segen_schutz"), _segen_runden()]
		EventType.HAENDLER:
			return Loc.pick("Fahrender Händler [%s]: tauscht Materialien gegen andere Materialien und Tränke.",
				"Travelling merchant [%s]: trades materials for other materials and potions.") % taste
		EventType.GEFANGENER:
			return Loc.pick("Gefangener Held [%s]: Wächter bewachen ihn. Nach dem Sieg über sie wartet er in der Taverne auf der Bank.",
				"Captive hero [%s]: guards watch over him. Once they are defeated he waits on the tavern bench.") % taste
	return ""


## Meldung nach dem Benutzen eines Schreins.
static func schrein_ergebnis(typ: int) -> String:
	match typ:
		EventType.SHRINE_HEAL:
			return Loc.pick("Heilschrein: Die Party wird um %d%% Max-HP geheilt!",
				"Healing shrine: the party is healed for %d%% max HP!") % _prozent(SCHREIN_HEIL_ANTEIL)
		EventType.SHRINE_MANA:
			return Loc.pick("Manaschrein: Die Party erhält %d%% Max-MP zurück!",
				"Mana shrine: the party regains %d%% max MP!") % _prozent(SCHREIN_MANA_ANTEIL)
		EventType.SHRINE_POWER:
			return Loc.pick("Kraftschrein: Der nächste Kampf beginnt mit %s (%s)!",
				"Power shrine: the next battle starts with %s (%s)!") \
				% [segen_wirkung(&"segen_kraft"), _segen_runden()]
		EventType.SHRINE_WARD:
			return Loc.pick("Schutzschrein: Der nächste Kampf beginnt mit %s (%s)!",
				"Ward shrine: the next battle starts with %s (%s)!") \
				% [segen_wirkung(&"segen_schutz"), _segen_runden()]
	return ""


static func opfer_meldung(gold: int) -> String:
	return Loc.pick("Der Opferstein nimmt euer Blut: +%d Gold und Materialien.",
		"The sacrifice stone takes your blood: +%d gold and materials.") % gold


# --- Endlose Ebenen: Anzeige und Licht der Tiefe ---------------------------------

## HUD-Text der Ebene: „Ebene 4  (Gegner +1)“, „Boss-Ebene 6“, „Großer Boss · Ebene 15“,
## ab Tiefe 1 mit „· Tiefe 1“.
static func ebenen_text(ebene: int, boss_ebene: bool) -> String:
	var text: String
	if boss_ebene and ist_grosser_boss(ebene):
		text = Loc.pick("Großer Boss · Ebene %d", "Great boss · floor %d") % (ebene + 1)
	elif boss_ebene:
		text = Loc.pick("Boss-Ebene %d", "Boss floor %d") % (ebene + 1)
	else:
		text = Loc.pick("Ebene %d", "Floor %d") % (ebene + 1)
	var bonus := tiefen_bonus(ebene)
	if bonus > 0:
		text += Loc.pick("  (Gegner +%d)", "  (enemies +%d)") % bonus
	var tiefe := tiefe(ebene)
	if tiefe > 0:
		text += Loc.pick("  · Tiefe %d", "  · depth %d") % tiefe
	return text


## Je Tiefe wird das Licht dunkler (Umgebung und Hauptlicht), mit Untergrenze.
const TIEFE_LICHT_SCHRITT := 0.08
const TIEFE_LICHT_MIN := 0.6


static func tiefen_licht_faktor(tiefe: int) -> float:
	return maxf(TIEFE_LICHT_MIN, 1.0 - TIEFE_LICHT_SCHRITT * maxi(0, tiefe))


static func tiefen_licht_anwenden(stil: Dictionary, tiefe: int) -> void:
	var faktor := tiefen_licht_faktor(tiefe)
	for schluessel in ["ambient_energie", "licht_energie"]:
		if stil.has(schluessel):
			stil[schluessel] = float(stil[schluessel]) * faktor


## „Tiefe 1 — Ausweglos: …“ (leer ohne Regel der Tiefe).
static func tiefen_hinweis(karte: DungeonCard, ebene: int) -> String:
	if karte == null or karte.tiefen_regel == &"":
		return ""
	return Loc.pick("Tiefe %d — %s: %s", "Depth %d — %s: %s") % [tiefe(ebene),
		Sonderregeln.regel_name(karte.tiefen_regel), Sonderregeln.regel_text(karte, karte.tiefen_regel)]


## Normale Truhe: „Seltene Truhe: +40 Gold!“ (Item und Extras hängt der Aufrufer an).
static func truhen_meldung(rarity: Enums.Rarity, gold: int) -> String:
	return Loc.pick("%s: +%d Gold!", "%s: +%d gold!") % [LootGenerator.truhen_name(rarity), gold]


static func risiko_truhe_meldung(gold: int, item: ItemInstance) -> String:
	return Loc.pick("Risiko-Truhe: +%d Gold, %s (%s) und Materialien!",
		"Risk chest: +%d gold, %s (%s) and materials!") \
		% [gold, item.get_display_name(), LootGenerator.rarity_name(item.rarity)]


static func mimic_meldung() -> String:
	return Loc.pick("Die Truhe lebt — ein Mimic!", "The chest is alive — a mimic!")
