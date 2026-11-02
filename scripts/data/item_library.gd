class_name ItemLibrary
extends RefCounted
## Katalog der Basis-Items und Affixe fürs Loot-System (Diablo-Prinzip:
## Basis-Item + zufällige Prefix/Suffix-Affixe = konkretes Item).
## Vorerst im Code definiert, später .tres-Dateien in data/.

static var _bases: Array[ItemBase] = []
static var _affixes: Array[Affix] = []


## Sprachwechsel: Cache leeren, Namen backen sich neu.
static func reset_cache() -> void:
	_bases.clear()
	_affixes.clear()


static func bases_for_tier(tier: int) -> Array[ItemBase]:
	_ensure_built()
	var result: Array[ItemBase] = []
	for base in _bases:
		if base.min_tier <= tier:
			result.append(base)
	return result


## Alt-IDs aus früheren Katalog-Versionen » heutige Basis (alte Spielstände
## behalten ihre Items, statt sie beim Laden still zu verlieren).
const LEGACY_ALIASES := {
	&"kurzschwert": &"schwert", &"langschwert": &"schwert", &"rapier": &"schwert",
	&"runenklinge": &"schwert", &"daemonenklinge": &"zweihandschwert",
	&"stilett": &"dolch", &"schattenklinge": &"dolch",
	&"streitkolben": &"knueppel", &"morgenstern": &"knueppel",
	&"kriegssense": &"zweihandaxt",
	&"lehrlingsstab": &"offensivstab", &"kriegsstab": &"offensivstab",
	&"erzstab": &"offensivstab", &"nekrostab": &"offensivstab",
	&"seelenstab": &"heiligstab",
	&"holzschild": &"schild", &"spiegelschild": &"schild",
	&"jagdkoecher": &"koecher", &"kriegskoecher": &"koecher",
	&"lederharnisch": &"ruestung_leicht", &"kettenhemd": &"ruestung_mittel",
	&"schuppenpanzer": &"ruestung_mittel", &"plattenpanzer": &"ruestung_schwer",
	&"drachenharnisch": &"ruestung_schwer",
	&"lederkappe": &"helm_leicht", &"eisenhelm": &"helm_schwer",
	&"ritterhelm": &"helm_schwer",
	&"lederhandschuhe": &"handschuhe_leicht", &"kettenhandschuhe": &"handschuhe_schwer",
	&"plattenhandschuhe": &"handschuhe_schwer",
	&"lederstiefel": &"stiefel_leicht", &"reisestiefel": &"stiefel_leicht",
	&"plattenstiefel": &"stiefel_schwer",
	&"silberring": &"ring", &"goldring": &"ring", &"rubinring": &"ring",
	&"siegelring": &"ring",
	&"knochenamulett": &"amulett", &"jadeamulett": &"amulett",
	&"sternenamulett": &"amulett",
}


static func get_base(id: StringName) -> ItemBase:
	_ensure_built()
	var lookup: StringName = LEGACY_ALIASES.get(id, id)
	for base in _bases:
		if base.id == lookup:
			return base
	return null


## Fertiges, affixfreies Item aus einer Basis-ID (z.B. Startwaffen).
static func make_item(id: StringName, item_level := 1) -> ItemInstance:
	var base := get_base(id)
	if base == null:
		return null
	var item := ItemInstance.new()
	item.base = base
	item.item_level = item_level
	return item


static func get_affix(id: StringName) -> Affix:
	_ensure_built()
	for affix in _affixes:
		if affix.id == id:
			return affix
	return null


static func affixes_for_tier(tier: int, prefixes: bool) -> Array[Affix]:
	_ensure_built()
	var result: Array[Affix] = []
	for affix in _affixes:
		if affix.tier <= tier and affix.is_prefix == prefixes and affix.regelbruch == &"" \
				and affix.boss_id == &"" and not affix.ist_skill_affix():
			result.append(affix)
	return result


## Skill-Affixe bis zu dieser Kartenstufe (eigener Pool, LootGenerator zieht
## sie mit SKILL_AFFIX_ANTEIL).
static func skill_affixes_for_tier(tier: int) -> Array[Affix]:
	_ensure_built()
	var result: Array[Affix] = []
	for affix in _affixes:
		if affix.tier <= tier and affix.ist_skill_affix():
			result.append(affix)
	return result


## Regelbrecher-Affixe (nur über LootGenerator.regelbruch_hinzufuegen).
static func regel_affixe() -> Array[Affix]:
	_ensure_built()
	var result: Array[Affix] = []
	for affix in _affixes:
		if affix.regelbruch != &"":
			result.append(affix)
	return result


static func _ensure_built() -> void:
	if not _bases.is_empty():
		return

	var S := Enums.PhysicalSubtype
	# =========================================================================
	# EIN Basis-Item pro Kategorie (Design-Entscheidung): "Dolch ist Dolch".
	# Die ganze Item-Vielfalt entsteht aus Affixen, Raritäten, Namen und dem
	# endlos skalierenden Item-Level — nicht aus Basis-Duplikaten.
	# =========================================================================
	# --- Waffen ----------------------------------------------------------------
	_weapon(&"schwert", Loc.pick("Schwert", "Sword"), 8, [S.PIERCE, S.SLASH], false, null, 1, &"schwert")
	_weapon(&"zweihandschwert", Loc.pick("Zweihandschwert", "Greatsword"), 18, [S.PIERCE, S.SLASH], true, null, 3,
		&"schwert")
	var dolch := _weapon(&"dolch", Loc.pick("Dolch", "Dagger"), 5, [S.PIERCE], false,
		_stats(0, 0, 0, 0, 1, 0), 1, &"dolch")
	dolch.light = true  # Dual Wield: zweiter Dolch in die Nebenhand
	_weapon(&"axt", Loc.pick("Axt", "Axe"), 12, [S.SLASH], false, null, 2, &"axt")
	_weapon(&"zweihandaxt", Loc.pick("Zweihandaxt", "Greataxe"), 21, [S.SLASH], true, null, 3, &"axt")
	_weapon(&"knueppel", Loc.pick("Knüppel", "Club"), 6, [S.BLUNT], false, null, 1, &"stumpf")
	_weapon(&"kriegshammer", Loc.pick("Kriegshammer", "Warhammer"), 20, [S.BLUNT], true, null, 4, &"stumpf")
	# Fernkampf: zweihändig, aber ein KÖCHER darf in die Nebenhand.
	# Bogen: 2 Pfeile pro Waffennutzung (Mitigation greift pro Pfeil).
	# Armbrust: ein schwerer Bolzen mit Rüstungsdurchdringung.
	var bogen := _weapon(&"bogen", Loc.pick("Bogen", "Bow"), 7, [S.PIERCE], true, null, 2, &"bogen")
	bogen.ranged = true
	bogen.hit_count = 2
	var armbrust := _weapon(&"armbrust", Loc.pick("Armbrust", "Crossbow"), 20, [S.PIERCE], true, null, 5, &"armbrust")
	armbrust.ranged = true
	armbrust.armor_pierce = 0.2
	# Zwei Zauberstab-Arten (Design): offensiv (INT) und heilig (SPI).
	# Zwei getrennte Stab-GATTUNGEN: Schadensmagie und Heilmagie haben
	# eigene Trainings-Bäume und eigene Eigenheiten.
	_staff(&"offensivstab", Loc.pick("Offensivstab", "Battle Staff"), 9, false, _stats(0, 2, 0, 0, 0, 0), 1,
		&"offensivstab")
	_staff(&"heiligstab", Loc.pick("Heiligstab", "Holy Staff"), 8, false, _stats(0, 0, 0, 2, 0, 0), 1,
		&"heiligstab")
	# --- Nebenhand ---------------------------------------------------------------
	var schild := _armor(&"schild", Loc.pick("Schild", "Shield"), Enums.EquipSlot.OFF_HAND, 3,
		Enums.ArmorClass.CHAIN, null, 1)
	schild.family = &"schild"  # Schild-Techniken prüfen die Nebenhand-Gattung
	# Turmschild: ZWEIHÄNDIG (belegt die Waffenhand) — massiver Schutz,
	# aber kaum Angriffskraft. Der Panzerknacker unter den Verteidigern.
	var turmschild := _weapon(&"turmschild", Loc.pick("Turmschild", "Tower Shield"), 2,
		[S.BLUNT], true, _stats(0, 0, 1, 0, 0, 0), 2, &"schild")
	turmschild.base_armor = 9
	turmschild.armor_class = Enums.ArmorClass.PLATE
	_base(&"zauberbuch", Loc.pick("Zauberbuch", "Spellbook"), Enums.EquipSlot.OFF_HAND, 0, 0, _stats(0, 2, 0, 1, 0, 0), 2)
	var focus := _base(&"kristallfokus", Loc.pick("Kristallfokus", "Crystal Focus"), Enums.EquipSlot.OFF_HAND, 0, 0,
		_stats(0, 1, 0, 1, 0, 0), 4)
	focus.spell_damage = 4
	# Zauber-Nebenhände nach Zweck: Relikt für Schadensmagie (INT),
	# Heiliges Kreuz für Heilmagie (GEIST) — die Stäbe sind einhändig,
	# die Nebenhand verstärkt die gewählte Richtung schon ab Stufe 1.
	var relikt := _base(&"relikt", Loc.pick("Relikt", "Relic"), Enums.EquipSlot.OFF_HAND, 0, 0,
		_stats(0, 1, 0, 0, 0, 0), 1)
	relikt.spell_damage = 2
	var heiligkreuz := _base(&"heiligkreuz", Loc.pick("Heiliges Kreuz", "Holy Cross"), Enums.EquipSlot.OFF_HAND, 0, 0,
		_stats(0, 0, 0, 1, 0, 0), 1)
	heiligkreuz.spell_damage = 2
	_quiver(&"koecher", Loc.pick("Köcher", "Quiver"), 3, null, 2)
	# --- Rüstung (Brust): Gewichtsklassen + Roben nach Zweck ---------------------
	_armor(&"ruestung_leicht", Loc.pick("Leichte Rüstung", "Light Armor"), Enums.EquipSlot.ARMOR, 3,
		Enums.ArmorClass.LEATHER, _stats(0, 0, 0, 0, 1, 0), 1)
	_armor(&"ruestung_mittel", Loc.pick("Mittlere Rüstung", "Medium Armor"), Enums.EquipSlot.ARMOR, 5,
		Enums.ArmorClass.CHAIN, null, 2)
	_armor(&"ruestung_schwer", Loc.pick("Schwere Rüstung", "Heavy Armor"), Enums.EquipSlot.ARMOR, 6,
		Enums.ArmorClass.PLATE, _stats(0, 0, 1, 0, 0, 0), 3)
	# Roben: kaum Rüstung, dafür Zauberkraft — Schaden (INT), Heilung (SPI),
	# und die Kampfrobe dazwischen.
	var robe_schaden := _armor(&"robe_schaden", Loc.pick("Schadensrobe", "Sorcerer's Robe"), Enums.EquipSlot.ARMOR, 1,
		Enums.ArmorClass.NONE, _stats(0, 2, 0, 0, 0, 0), 2)
	robe_schaden.spell_damage = 4
	var robe_heil := _armor(&"robe_heil", Loc.pick("Heilrobe", "Healer's Robe"), Enums.EquipSlot.ARMOR, 1,
		Enums.ArmorClass.NONE, _stats(0, 0, 0, 3, 0, 0), 2)
	robe_heil.spell_damage = 2
	var robe_kampf := _armor(&"robe_kampf", Loc.pick("Kampfrobe", "Battle Robe"), Enums.EquipSlot.ARMOR, 2,
		Enums.ArmorClass.NONE, _stats(0, 1, 0, 1, 0, 0), 3)
	robe_kampf.spell_damage = 3
	# --- Rüstung (Kopf/Hände/Füße): leicht oder schwer ---------------------------
	_armor(&"helm_leicht", Loc.pick("Leichter Helm", "Light Helmet"), Enums.EquipSlot.HELMET, 2,
		Enums.ArmorClass.LEATHER, null, 1)
	_armor(&"helm_schwer", Loc.pick("Schwerer Helm", "Heavy Helmet"), Enums.EquipSlot.HELMET, 4,
		Enums.ArmorClass.PLATE, null, 3)
	_armor(&"handschuhe_leicht", Loc.pick("Leichte Handschuhe", "Light Gloves"), Enums.EquipSlot.GLOVES, 1,
		Enums.ArmorClass.LEATHER, _stats(0, 0, 0, 0, 1, 0), 1)
	_armor(&"handschuhe_schwer", Loc.pick("Panzerhandschuhe", "Gauntlets"), Enums.EquipSlot.GLOVES, 3,
		Enums.ArmorClass.PLATE, _stats(1, 0, 0, 0, 0, 0), 3)
	_armor(&"stiefel_leicht", Loc.pick("Leichte Stiefel", "Light Boots"), Enums.EquipSlot.BOOTS, 1,
		Enums.ArmorClass.LEATHER, _stats(0, 0, 0, 0, 2, 0), 1)
	_armor(&"stiefel_schwer", Loc.pick("Panzerstiefel", "Greaves"), Enums.EquipSlot.BOOTS, 3,
		Enums.ArmorClass.PLATE, _stats(0, 0, 1, 0, 0, 0), 3)
	# --- Schmuck ----------------------------------------------------------------
	# Schmuck mit Grund-Attributen, die mit dem Item-Level wachsen.
	var ring := _base(&"ring", "Ring", Enums.EquipSlot.RING_1, 0, 0, _stats(0, 0, 0, 0, 1, 2), 1)
	ring.stat_skaliert = true
	var amulett := _base(&"amulett", Loc.pick("Amulett", "Amulet"), Enums.EquipSlot.AMULET, 0, 0, _stats(0, 0, 1, 2, 0, 0), 1)
	amulett.stat_skaliert = true

	# Affix-Raritäten: bestimmen die Zieh-Wahrscheinlichkeit im Pool —
	# Basis-Stats häufig, Element-Rider selten, Skill-Affixe der Jackpot.
	var R := Enums.Rarity

	# --- Affixe: Prefixe -----------------------------------------------------
	_affix(&"flammend", true, Loc.pick("Flammendes", "Flaming"), null, 3, 0, 1, R.COMMON)
	_affix(&"robust", true, Loc.pick("Robustes", "Sturdy"), null, 0, 2, 1, R.COMMON)
	_affix(&"flink", true, Loc.pick("Flinkes", "Nimble"), _stats(0, 0, 0, 0, 2, 0), 0, 0, 1, R.COMMON)
	_affix(&"gesegnet", true, Loc.pick("Gesegnetes", "Blessed"), _stats(0, 0, 0, 2, 0, 0), 0, 0, 1, R.MAGIC)
	_affix(&"grausam", true, Loc.pick("Grausames", "Cruel"), null, 6, 0, 2, R.MAGIC)
	_affix(&"gehaertet", true, Loc.pick("Gehärtetes", "Hardened"), null, 0, 4, 2, R.MAGIC)
	_affix(&"brutal", true, Loc.pick("Brutales", "Brutal"), null, 10, 0, 3, R.RARE)

	# --- Affixe: Prefixe für Caster (Zauberkraft, nur Waffe/Nebenhand) --------
	_spell_affix(&"arkan", Loc.pick("Arkanes", "Arcane"), 3, 2, R.MAGIC)
	_spell_affix(&"verzaubert", Loc.pick("Verzaubertes", "Enchanted"), 6, 4, R.RARE)
	_spell_affix(&"transzendent", Loc.pick("Transzendentes", "Transcendent"), 10, 6, R.EPIC)

	# --- Affixe: Element-Rider (nur Waffen) — Waffennutzung trägt das Element --
	_rider_affix(&"lodernd", Loc.pick("Loderndes", "Blazing"), Enums.Element.FIRE, 4, 3, R.RARE)
	_rider_affix(&"giftgetraenkt", Loc.pick("Giftgetränktes", "Venomous"), Enums.Element.POISON, 3, 4, R.RARE)
	_rider_affix(&"frostig", Loc.pick("Frostiges", "Frosted"), Enums.Element.ICE, 5, 5, R.RARE)
	_rider_affix(&"knisternd", Loc.pick("Knisterndes", "Crackling"), Enums.Element.LIGHTNING, 5, 6, R.RARE)
	_rider_affix(&"geweiht", Loc.pick("Geweihtes", "Consecrated"), Enums.Element.HOLY, 5, 7, R.EPIC)
	_rider_affix(&"schattenhaft", Loc.pick("Schattenhaftes", "Shadowy"), Enums.Element.DARK, 5, 8, R.EPIC)

	# --- Affixe: Suffixe -----------------------------------------------------
	_affix(&"staerke", false, Loc.pick("der Stärke", "of Strength"), _stats(3, 0, 0, 0, 0, 0), 0, 0, 1, R.COMMON)
	_affix(&"geist", false, Loc.pick("des Geistes", "of the Mind"), _stats(0, 3, 0, 0, 0, 0), 0, 0, 1, R.COMMON)
	_affix(&"vitalitaet", false, Loc.pick("der Vitalität", "of Vitality"), _stats(0, 0, 3, 0, 0, 0), 0, 0, 1, R.COMMON)
	_affix(&"sturm", false, Loc.pick("des Sturms", "of the Storm"), _stats(0, 0, 0, 0, 3, 0), 0, 0, 1, R.COMMON)
	_affix(&"glueck", false, Loc.pick("des Glücks", "of Fortune"), _stats(0, 0, 0, 0, 0, 3), 0, 0, 1, R.COMMON)
	_affix(&"abwehr", false, Loc.pick("der Abwehr", "of Defense"), null, 0, 3, 2, R.MAGIC)
	_affix(&"verwuestung", false, Loc.pick("der Verwüstung", "of Devastation"), null, 5, 0, 2, R.RARE)
	_affix(&"titanen", false, Loc.pick("der Titanen", "of the Titans"), _stats(3, 0, 3, 0, 0, 0), 0, 0, 3, R.RARE)
	_affix(&"weisheit", false, Loc.pick("der Weisheit", "of Wisdom"), _stats(0, 3, 0, 3, 0, 0), 0, 0, 3, R.RARE)

	# --- Affixe: Element-Resistenzen (Rüstung/Schild/Schmuck) — das Gegenmittel
	# zu den Element-Gegnern hoher Kartenstufen.
	_resist_affix(&"feuerabwehr", Loc.pick("der Feuerabwehr", "of Flame Warding"), Enums.Element.FIRE, 8, 3, R.MAGIC)
	_resist_affix(&"giftabwehr", Loc.pick("der Giftabwehr", "of Venom Warding"), Enums.Element.POISON, 8, 4, R.MAGIC)
	_resist_affix(&"frostabwehr", Loc.pick("der Frostabwehr", "of Frost Warding"), Enums.Element.ICE, 10, 5, R.RARE)
	_resist_affix(&"blitzabwehr", Loc.pick("der Blitzabwehr", "of Storm Warding"), Enums.Element.LIGHTNING, 10, 6, R.RARE)
	_resist_affix(&"schattenabwehr", Loc.pick("der Schattenabwehr", "of Shadow Warding"), Enums.Element.DARK, 10, 8, R.RARE)
	_resist_affix(&"bannung", Loc.pick("der Bannung", "of Banishing"), Enums.Element.NONE, 6, 9, R.EPIC)  # alle Elemente

	# --- Affixe: Skill-Suffixe (MP-Kosten, Waffe/Nebenhand/Schmuck) ------------
	_skill_affix(&"fokus", Loc.pick("des Fokus", "of Focus"), 5, 2, R.RARE)
	_skill_affix(&"klarheit", Loc.pick("der Klarheit", "of Clarity"), 8, 5, R.EPIC)
	_skill_affix(&"erzmagier", Loc.pick("des Erzmagiers", "of the Archmage"), 12, 8, R.LEGENDARY)

	# --- Prozent-Affixe (ab Kartenstufe 10): teilen sich die Gruppe mit den
	# festen Affixen derselben Größe (Affix.gruppen) — je Item entweder
	# „+x Rüstung“ oder „+x % Rüstung“. Drei Stufen je Größe; Spanne je
	# Grundwert ×1,0–1,6 (4 → 4–6 %, 9 → 9–14 %, 15 → 15–24 %).
	for eintrag in PROZENT_AFFIXE:
		var stufen: Array = eintrag[3]
		for i in stufen.size():
			var namen: Array = eintrag[4 + i]
			var affix := _affix(StringName("p_%s_%d" % [eintrag[0], i + 1]), eintrag[1],
				Loc.pick(namen[0], namen[1]), null, 0, 0, int(stufen[i][0]), stufen[i][2])
			affix.prozent_art = eintrag[0]
			affix.prozent_wert = int(stufen[i][1])
			var slots: Array[Enums.EquipSlot] = []
			for slot in eintrag[2]:
				slots.append(slot)
			affix.allowed_slots = slots

	# --- Skill-Affixe: wirken auf selbst gebaute Skills mit passendem Bezug
	# (Skill.passt_bezug), höchstens einmal je Skill (Combatant.skill_bonus).
	for eintrag in SKILL_AFFIXE:
		var affix := _affix(eintrag[0], false, Loc.pick(eintrag[1], eintrag[2]), null, 0, 0,
			eintrag[6], eintrag[7])
		affix.klotz_bezug = eintrag[3]
		affix.klotz_wirkung = eintrag[4]
		affix.klotz_wert = eintrag[5]

	# --- Regelbrecher (nur Legendär: Regelrune oder seltener Glückswurf) -----
	for regel in [[&"baumeister", Loc.pick("des Baumeisters", "of the Builder"), &"sockel"],
			[&"doppelkern", Loc.pick("des Doppelkerns", "of the Twin Core"), &"doppelkern"],
			[&"waffenfreiheit", Loc.pick("der Waffenfreiheit", "of Free Arms"), &"waffenfrei"]]:
		var affix := _affix(regel[0], false, regel[1], null, 0, 0, 1, R.LEGENDARY)
		affix.regelbruch = regel[2]

	_boss_affixe_bauen()


## Prozent-Affixe: [Art, Prefix?, Slots (leer = alle), Stufen
## [[Kartenstufe, Prozent, Rarität], …], dann je Stufe [DE, EN]].
## Werte per Balancing-Simulation (balance_sim BOSS=1 BOSSNUR=1 GEARMIX=1).
const _STUFEN_PROZENT := [[10, 8, Enums.Rarity.MAGIC], [50, 12, Enums.Rarity.RARE],
	[120, 16, Enums.Rarity.EPIC]]
const _OHNE_WAFFE := [Enums.EquipSlot.OFF_HAND, Enums.EquipSlot.HELMET, Enums.EquipSlot.ARMOR,
	Enums.EquipSlot.GLOVES, Enums.EquipSlot.BOOTS, Enums.EquipSlot.RING_1, Enums.EquipSlot.AMULET]
const _ANGRIFF := [Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND, Enums.EquipSlot.GLOVES,
	Enums.EquipSlot.RING_1, Enums.EquipSlot.AMULET]
const _ZAUBER := [Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND, Enums.EquipSlot.ARMOR,
	Enums.EquipSlot.RING_1, Enums.EquipSlot.AMULET]
const PROZENT_AFFIXE := [
	[&"ruestung", true, _OHNE_WAFFE, _STUFEN_PROZENT,
		["Beschlagenes", "Studded"], ["Gepanzertes", "Armored"], ["Unbezwingbares", "Unyielding"]],
	[&"schaden", true, _ANGRIFF, _STUFEN_PROZENT,
		["Geschärftes", "Honed"], ["Wütendes", "Furious"], ["Vernichtendes", "Annihilating"]],
	[&"zauberkraft", true, _ZAUBER, _STUFEN_PROZENT,
		["Mystisches", "Mystic"], ["Astrales", "Astral"], ["Göttliches", "Divine"]],
	[&"strength", false, [], _STUFEN_PROZENT,
		["der Kraft", "of Might"], ["des Riesen", "of the Giant"], ["des Kolosses", "of the Colossus"]],
	[&"intelligence", false, [], _STUFEN_PROZENT,
		["des Scharfsinns", "of Wit"], ["des Gelehrten", "of the Scholar"],
		["der Erleuchtung", "of Enlightenment"]],
	[&"vitality", false, [], _STUFEN_PROZENT,
		["der Ausdauer", "of Endurance"], ["des Bollwerks", "of the Bulwark"],
		["der Unsterblichkeit", "of Immortality"]],
	[&"spirit", false, [], _STUFEN_PROZENT,
		["der Andacht", "of Devotion"], ["der Seele", "of the Soul"], ["des Himmels", "of the Heavens"]],
]

## Skill-Affixe (Suffixe): [id, DE, EN, Bezug, Wirkung, Wert, Kartenstufe, Rarität].
## Bezüge auf echte Klötze der BlockLibrary (Skill.passt_bezug); Wirkungen
## siehe Affix.klotz_wirkung.
const SKILL_AFFIXE := [
	[&"s_salve_1", "der Salve", "of the Volley", &"klotz:mod_treffer", &"schaden", 8, 5,
		Enums.Rarity.MAGIC],
	[&"s_salve_2", "des Trommelfeuers", "of the Barrage", &"klotz:mod_treffer", &"schaden", 15, 40,
		Enums.Rarity.EPIC],
	[&"s_nachschlag", "des Nachschlags", "of the Follow-through", &"klotz:src_weapon", &"treffer", 8, 20,
		Enums.Rarity.RARE],
	[&"s_scharfblick", "des Scharfblicks", "of Keen Sight", &"gruppe:praezision", &"krit", 5, 10,
		Enums.Rarity.MAGIC],
	[&"s_fechter", "des Fechters", "of the Fencer", &"gattung:schwert", &"schaden", 10, 8,
		Enums.Rarity.MAGIC],
	[&"s_meuchler", "des Meuchlers", "of the Assassin", &"gattung:dolch", &"schaden", 10, 8,
		Enums.Rarity.MAGIC],
	[&"s_berserker", "des Berserkers", "of the Berserker", &"gattung:axt", &"schaden", 10, 8,
		Enums.Rarity.MAGIC],
	[&"s_brecher", "des Brechers", "of the Breaker", &"gattung:stumpf", &"schaden", 10, 8,
		Enums.Rarity.MAGIC],
	[&"s_jaeger", "des Jägers", "of the Hunter", &"gattung:bogen", &"schaden", 10, 8,
		Enums.Rarity.MAGIC],
	[&"s_schuetze", "des Schützen", "of the Marksman", &"gattung:armbrust", &"schaden", 10, 8,
		Enums.Rarity.MAGIC],
	[&"s_hexer", "des Hexers", "of the Warlock", &"gattung:offensivstab", &"schaden", 10, 8,
		Enums.Rarity.MAGIC],
	[&"s_priester", "des Priesters", "of the Priest", &"gattung:heiligstab", &"mp", 10, 8,
		Enums.Rarity.MAGIC],
	[&"s_waechter", "des Wächters", "of the Warden", &"gattung:schild", &"dauer", 1, 12,
		Enums.Rarity.RARE],
	[&"s_weite_1", "der Weite", "of Reach", &"form:aoe", &"mp", 8, 6, Enums.Rarity.MAGIC],
	[&"s_weite_2", "des Horizonts", "of the Horizon", &"form:aoe", &"mp", 14, 40, Enums.Rarity.EPIC],
	[&"s_nachhall", "des Nachhalls", "of Resonance", &"form:aura", &"dauer", 1, 16, Enums.Rarity.RARE],
	[&"s_glut_1", "der Glut", "of Embers", &"element:feuer", &"stacks", 10, 5, Enums.Rarity.MAGIC],
	[&"s_glut_2", "des Infernos", "of the Inferno", &"element:feuer", &"stacks", 18, 40,
		Enums.Rarity.EPIC],
	[&"s_faeulnis_1", "der Fäulnis", "of Rot", &"element:gift", &"stacks", 10, 14, Enums.Rarity.MAGIC],
	[&"s_faeulnis_2", "der Seuche", "of Plague", &"element:gift", &"stacks", 18, 45, Enums.Rarity.EPIC],
	[&"s_winter", "des Winters", "of Winter", &"element:eis", &"schaden", 10, 6, Enums.Rarity.MAGIC],
	[&"s_donner", "des Donners", "of Thunder", &"element:blitz", &"schaden", 10, 10, Enums.Rarity.MAGIC],
	[&"s_finsternis", "der Finsternis", "of Darkness", &"element:dunkel", &"schaden", 10, 18,
		Enums.Rarity.MAGIC],
]


## Boss-Affixe (nur über BossBeute.boss_affix_hinzufuegen): je Boss-Grundtyp
## zwei Suffixe mit Boss-Namen im Genitiv. Wirkung entweder ein eigener
## Effekt (boss_effekt, Prozent) oder eine normale Mechanik (Rider, Rüstung …).
## Eintrag: [id, boss, DE, EN, effekt, wert, art] — art: "" (eigener Effekt),
## "rider:<element>", "ruestung", "stat:<name>", "mp".
const BOSS_AFFIXE := [
	[&"boss_baer_wut", &"baer", "des Bären", "of the Bear", &"wut", 10, ""],
	[&"boss_baer_kraft", &"baer", "des Bären", "of the Bear", &"", 4, "stat:strength"],
	[&"boss_schleimgott_schlund", &"schleimgott", "des Schleimgotts", "of the Slime God", &"verschlingen", 4, ""],
	[&"boss_schleimgott_gift", &"schleimgott", "des Schleimgotts", "of the Slime God", &"", 4, "rider:poison"],
	[&"boss_golem_haut", &"golem", "des Golems", "of the Golem", &"steinhaut", 6, ""],
	[&"boss_golem_panzer", &"golem", "des Golems", "of the Golem", &"", 5, "ruestung"],
	[&"boss_troll_regen", &"troll", "des Trolls", "of the Troll", &"regeneration", 2, ""],
	[&"boss_troll_zaeh", &"troll", "des Trolls", "of the Troll", &"", 4, "stat:vitality"],
	[&"boss_kultist_opfer", &"kultist", "des Kultisten", "of the Cultist", &"opfergabe", 4, ""],
	[&"boss_kultist_ritus", &"kultist", "des Kultisten", "of the Cultist", &"", 5, "mp"],
	[&"boss_nekromant_raub", &"nekromant", "des Nekromanten", "of the Necromancer", &"lebensraub", 4, ""],
	[&"boss_nekromant_schatten", &"nekromant", "des Nekromanten", "of the Necromancer", &"", 4, "rider:dark"],
	[&"boss_schattenbestie_jagd", &"schattenbestie", "der Schattenbestie", "of the Shadow Beast", &"jaeger", 10, ""],
	[&"boss_schattenbestie_biss", &"schattenbestie", "der Schattenbestie", "of the Shadow Beast", &"lebensraub", 3, ""],
	[&"boss_todesmeister_ende", &"todesmeister", "des Todesmeisters", "of the Master of Death", &"jaeger", 12, ""],
	[&"boss_todesmeister_ernte", &"todesmeister", "des Todesmeisters", "of the Master of Death", &"verschlingen", 3, ""],
	[&"boss_bock_zorn", &"verfluchtbock", "des Verfluchten Bocks", "of the Cursed Buck", &"wut", 12, ""],
	[&"boss_bock_fell", &"verfluchtbock", "des Verfluchten Bocks", "of the Cursed Buck", &"steinhaut", 4, ""],
	[&"boss_hexe_spiegel", &"hexenmeisterin", "der Hexenmeisterin", "of the Witch Mistress", &"rache", 8, ""],
	[&"boss_hexe_zehrung", &"hexenmeisterin", "der Hexenmeisterin", "of the Witch Mistress", &"opfergabe", 3, ""],
	[&"boss_daemonenkoenig_rache", &"demonenkonig", "des Dämonenkönigs", "of the Demon King", &"rache", 10, ""],
	[&"boss_daemonenkoenig_glut", &"demonenkonig", "des Dämonenkönigs", "of the Demon King", &"", 5, "rider:fire"],
	[&"boss_kristall_splitter", &"kristallkoenigin", "der Kristallkönigin", "of the Crystal Queen", &"rache", 6, ""],
	[&"boss_kristall_glanz", &"kristallkoenigin", "der Kristallkönigin", "of the Crystal Queen", &"", 5, "mp"],
	[&"boss_aschekoloss_kruste", &"aschekoloss", "des Aschekolosses", "of the Ash Colossus", &"steinhaut", 5, ""],
	[&"boss_aschekoloss_glut", &"aschekoloss", "des Aschekolosses", "of the Ash Colossus", &"", 4, "rider:fire"],
]
const _BOSS_RIDER := {"poison": Enums.Element.POISON, "dark": Enums.Element.DARK,
	"fire": Enums.Element.FIRE}


static func _boss_affixe_bauen() -> void:
	for eintrag in BOSS_AFFIXE:
		var art: String = eintrag[6]
		var wert: int = eintrag[5]
		var affix := _affix(eintrag[0], false, Loc.pick(eintrag[2], eintrag[3]), null, 0, 0, 1,
			Enums.Rarity.LEGENDARY)
		affix.boss_id = eintrag[1]
		affix.boss_effekt = eintrag[4]
		if art.is_empty():
			affix.boss_wert = wert
		elif art.begins_with("rider:"):
			affix.element = _BOSS_RIDER[art.substr(6)]
			affix.element_damage = wert
			affix.allowed_slots = [Enums.EquipSlot.WEAPON] as Array[Enums.EquipSlot]
		elif art == "ruestung":
			affix.bonus_armor = wert
			affix.allowed_slots = _defensive_slots()
		elif art.begins_with("stat:"):
			var stats := StatBlock.new()
			stats.set(StringName(art.substr(5)), wert)
			affix.stat_bonus = stats
		elif art == "mp":
			affix.mp_cost_reduction = wert
			affix.allowed_slots = [Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND,
				Enums.EquipSlot.RING_1, Enums.EquipSlot.AMULET] as Array[Enums.EquipSlot]


## Boss-Affixe eines Boss-Grundtyps (leer = dieser Boss hat keine).
static func boss_affixe(boss_id: StringName) -> Array[Affix]:
	_ensure_built()
	var result: Array[Affix] = []
	for affix in _affixes:
		if affix.boss_id != &"" and affix.boss_id == boss_id:
			result.append(affix)
	return result


static func _base(id: StringName, name: String, slot: Enums.EquipSlot, damage: int,
		armor: int, stat_bonus: StatBlock, min_tier: int) -> ItemBase:
	var base := ItemBase.new()
	base.id = id
	base.display_name = name
	base.slot = slot
	base.base_damage = damage
	base.base_armor = armor
	base.stat_bonus = stat_bonus
	base.min_tier = min_tier
	_bases.append(base)
	return base


static func _weapon(id: StringName, name: String, damage: int,
		subtypes: Array, two_handed: bool,
		stat_bonus: StatBlock, min_tier: int, family: StringName = &"") -> ItemBase:
	var base := _base(id, name, Enums.EquipSlot.WEAPON, damage, 0, stat_bonus, min_tier)
	var typed: Array[Enums.PhysicalSubtype] = []
	for subtype in subtypes:
		typed.append(subtype)
	base.weapon_subtypes = typed
	base.two_handed = two_handed
	base.family = family
	return base


## Stab/Fokus: Zauberschaden (spell_damage) statt physischem Waffenschaden.
static func _staff(id: StringName, name: String, spell_dmg: int, two_handed: bool,
		stat_bonus: StatBlock, min_tier: int, family: StringName) -> void:
	var base := _base(id, name, Enums.EquipSlot.WEAPON, 0, 0, stat_bonus, min_tier)
	base.spell_damage = spell_dmg
	base.two_handed = two_handed
	base.family = family
	# Stäbe können notfalls stumpf zuschlagen (falls jemand Waffennutzung wählt).
	base.weapon_subtypes = [Enums.PhysicalSubtype.BLUNT] as Array[Enums.PhysicalSubtype]


## Köcher: Nebenhand-Ergänzung zu Fernkampfwaffen (Bonus zählt nur mit Bogen/Armbrust).
static func _quiver(id: StringName, name: String, damage: int,
		stat_bonus: StatBlock, min_tier: int) -> void:
	var base := _base(id, name, Enums.EquipSlot.OFF_HAND, damage, 0, stat_bonus, min_tier)
	base.quiver = true


static func _armor(id: StringName, name: String, slot: Enums.EquipSlot, armor: int,
		armor_class: Enums.ArmorClass, stat_bonus: StatBlock, min_tier: int) -> ItemBase:
	var base := _base(id, name, slot, 0, armor, stat_bonus, min_tier)
	base.armor_class = armor_class
	return base


static func _affix(id: StringName, is_prefix: bool, name_part: String,
		stat_bonus: StatBlock, damage: int, armor: int, tier: int,
		rarity: Enums.Rarity = Enums.Rarity.COMMON) -> Affix:
	var affix := Affix.new()
	affix.id = id
	affix.is_prefix = is_prefix
	affix.name_part = name_part
	affix.stat_bonus = stat_bonus
	affix.bonus_damage = damage
	affix.bonus_armor = armor
	affix.tier = tier
	affix.rarity = rarity
	_affixes.append(affix)
	return affix


## Slots, auf denen Rüstungs-/Schmuck-Affixe (Resistenzen, …) rollen dürfen.
static func _defensive_slots() -> Array[Enums.EquipSlot]:
	return [Enums.EquipSlot.HELMET, Enums.EquipSlot.ARMOR, Enums.EquipSlot.GLOVES,
		Enums.EquipSlot.BOOTS, Enums.EquipSlot.OFF_HAND, Enums.EquipSlot.RING_1,
		Enums.EquipSlot.AMULET] as Array[Enums.EquipSlot]


## Element-Rider-Prefix: Waffennutzung trägt zusätzlichen Elementschaden.
static func _rider_affix(id: StringName, name_part: String, element: Enums.Element,
		damage: int, tier: int, rarity: Enums.Rarity = Enums.Rarity.RARE) -> void:
	var affix := _affix(id, true, name_part, null, 0, 0, tier, rarity)
	affix.element = element
	affix.element_damage = damage
	affix.allowed_slots = [Enums.EquipSlot.WEAPON] as Array[Enums.EquipSlot]


## Resistenz-Suffix: mindert Schaden eines Elements um Prozent (NONE = alle).
static func _resist_affix(id: StringName, name_part: String, element: Enums.Element,
		resist: int, tier: int, rarity: Enums.Rarity = Enums.Rarity.MAGIC) -> void:
	var affix := _affix(id, false, name_part, null, 0, 0, tier, rarity)
	affix.element = element
	affix.element_resist = resist
	affix.allowed_slots = _defensive_slots()


## Zauberkraft-Prefix für Stäbe/Foki.
static func _spell_affix(id: StringName, name_part: String, spell_damage: int,
		tier: int, rarity: Enums.Rarity = Enums.Rarity.MAGIC) -> void:
	var affix := _affix(id, true, name_part, null, 0, 0, tier, rarity)
	affix.bonus_spell_damage = spell_damage
	affix.allowed_slots = [Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND] \
		as Array[Enums.EquipSlot]


## Skill-Suffix: senkt die MP-Kosten aller Skills des Trägers um Prozent.
static func _skill_affix(id: StringName, name_part: String, reduction: int,
		tier: int, rarity: Enums.Rarity = Enums.Rarity.RARE) -> void:
	var affix := _affix(id, false, name_part, null, 0, 0, tier, rarity)
	affix.mp_cost_reduction = reduction
	affix.allowed_slots = [Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND,
		Enums.EquipSlot.RING_1, Enums.EquipSlot.AMULET] as Array[Enums.EquipSlot]


static func _stats(strength: int, intelligence: int, vitality: int,
		spirit: int, agility: int, luck: int) -> StatBlock:
	var stats := StatBlock.new()
	stats.strength = strength
	stats.intelligence = intelligence
	stats.vitality = vitality
	stats.spirit = spirit
	stats.agility = agility
	stats.luck = luck
	return stats
