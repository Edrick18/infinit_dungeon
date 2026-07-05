class_name HeroLibrary
extends RefCounted
## Charakter-Erstellung und Starter-Kits. Helden werden SELBST erstellt:
## freier Name, wählbares Porträt, Starter-Kit (Waffe + erster Skill).
## Klassenlos: JEDER Held startet mit Level 1 und 5 auf allen Werten —
## alles ist später über Statuspunkte, Bauklötze und Ausrüstung umbaubar.
## Bis zu 10 Helden pro Spielstand; maximal 4 aktiv, der Rest wartet auf
## der Taverne-Bank (Austauschen jederzeit; macht Platz für Co-op-Gäste).

const MAX_PARTY_SIZE := 4
const MAX_HEROES := 10

## Namensvorschläge für die Erstellung (frei überschreibbar; die ersten
## vier sind die Namen aus alten Spielständen und behalten ihre Porträts).
const HERO_NAMES: Array[String] = ["Aldric", "Mira", "Talin", "Runa",
	"Edda", "Björn", "Liora", "Kaspar", "Selma", "Dorn"]

## Start-Loadouts: Bei der Erstellung wird die WAFFE gewählt, keine Klasse
## (klassenlos!). Der Start-Skill folgt der Waffe: Waffennutzung bei
## physischen Waffen, der passende Zauber bei Stäben. "offhand" (optional)
## kommt mit in die Nebenhand — Schild, zweiter Dolch, Köcher.
const STARTER_LOADOUTS := {
	&"schwert_schild": {"name": "Schwert & Schild", "name_en": "Sword & shield",
		"weapon": &"schwert", "offhand": &"schild",
		"skill_name": "Waffenhieb", "blocks": [&"src_weapon"]},
	&"dolche": {"name": "Zwei Dolche", "name_en": "Twin daggers",
		"weapon": &"dolch", "offhand": &"dolch",
		"skill_name": "Waffenhieb", "blocks": [&"src_weapon"]},
	&"axt": {"name": "Axt", "name_en": "Axe",
		"weapon": &"axt",
		"skill_name": "Waffenhieb", "blocks": [&"src_weapon"]},
	&"knueppel": {"name": "Knüppel", "name_en": "Club",
		"weapon": &"knueppel",
		"skill_name": "Waffenhieb", "blocks": [&"src_weapon"]},
	&"bogen": {"name": "Bogen & Köcher", "name_en": "Bow & quiver",
		"weapon": &"bogen", "offhand": &"koecher",
		"skill_name": "Waffenhieb", "blocks": [&"src_weapon"]},
	&"feuerstab": {"name": "Offensivstab & Relikt — Feuer",
		"name_en": "Offense staff & relic — fire",
		"weapon": &"offensivstab", "offhand": &"relikt",
		"skill_name": "Feuerball", "blocks": [&"src_spell", &"elem_fire"]},
	&"giftstab": {"name": "Offensivstab & Relikt — Gift",
		"name_en": "Offense staff & relic — poison",
		"weapon": &"offensivstab", "offhand": &"relikt",
		"skill_name": "Giftwolke", "blocks": [&"src_spell", &"elem_poison", &"form_aoe"]},
	&"heiligstab": {"name": "Heiligstab & Heiliges Kreuz",
		"name_en": "Holy staff & sacred cross",
		"weapon": &"heiligstab", "offhand": &"heiligkreuz",
		"skill_name": "Heilende Aura",
		"blocks": [&"src_spell", &"form_aura", &"eff_regen", &"eff_shield"]},
}

## Alte Kit-IDs (Spielstände/Tests von früher) » neue Loadout-IDs.
const LEGACY_KITS := {
	&"krieger": &"schwert_schild",
	&"feuermagier": &"feuerstab",
	&"heiler": &"heiligstab",
	&"giftmischer": &"giftstab",
}

const STAT_LABELS := {
	&"strength": ["Stärke", "Strength"], &"intelligence": ["Intelligenz", "Intelligence"],
	&"vitality": ["Vitalität", "Vitality"], &"spirit": ["Geist", "Spirit"],
	&"agility": ["Geschick", "Agility"], &"luck": ["Glück", "Luck"],
}


## Namensvorschläge, die noch nicht vergeben sind (für die Erstellung).
static func available_names(hired: Array[Combatant]) -> Array[String]:
	var taken := {}
	for member in hired:
		taken[member.display_name] = true
	var result: Array[String] = []
	for name in HERO_NAMES:
		if not taken.has(name):
			result.append(name)
	return result


## Vorschlag fürs Namensfeld der Charakter-Erstellung.
static func suggest_name(hired: Array[Combatant]) -> String:
	var names := available_names(hired)
	return names[0] if not names.is_empty() else "Held %d" % (hired.size() + 1)


## Frischer Held: Level 1, überall 5, Loadout-Waffe(n) angelegt, Skill gelernt.
## portrait_tile -1 = Porträt über den Namen (Altbestand/Vorschlagsnamen).
static func create_hero(hero_name: String, loadout_id: StringName,
		portrait_tile := -1) -> Combatant:
	var resolved: StringName = LEGACY_KITS.get(loadout_id, loadout_id)
	var loadout: Dictionary = STARTER_LOADOUTS.get(resolved,
		STARTER_LOADOUTS[&"schwert_schild"])
	var stats := StatBlock.new()
	for stat in StatBlock.STAT_NAMES:
		stats.set(stat, 5)
	var hero := Combatant.create(hero_name, stats, true)
	hero.portrait_tile = portrait_tile
	hero.sprite = SpriteLib.tile(portrait_tile) if portrait_tile >= 0 \
		else SpriteLib.hero(hero_name)

	var skill := Skill.new()
	skill.display_name = loadout["skill_name"]
	for block_id in loadout["blocks"]:
		var block := BlockLibrary.get_block(block_id)
		assert(block != null, "Unbekannter Baustein im Starter-Loadout: %s" % block_id)
		skill.blocks.append(block)
	hero.skills = [skill]

	var weapon := ItemLibrary.make_item(loadout["weapon"])
	if weapon != null:
		hero.equip(weapon)
	if loadout.has("offhand"):
		var offhand := ItemLibrary.make_item(loadout["offhand"])
		if offhand != null:
			hero.equip(offhand)
	return hero


static func loadout_label(loadout_id: StringName) -> String:
	var loadout: Dictionary = STARTER_LOADOUTS.get(loadout_id, {})
	if loadout.is_empty():
		return String(loadout_id)
	return Loc.pick(loadout["name"], loadout["name_en"])


## Werte-Beschreibung fürs Erstellungs-Formular: exakt die Items, die der
## Held bekommt (Basiswerte Level 1, ohne Affixe), plus der Start-Skill.
static func loadout_description(loadout_id: StringName) -> String:
	var resolved: StringName = LEGACY_KITS.get(loadout_id, loadout_id)
	var loadout: Dictionary = STARTER_LOADOUTS.get(resolved, {})
	if loadout.is_empty():
		return ""
	var lines: Array[String] = []
	var weapon := ItemLibrary.make_item(loadout["weapon"])
	lines.append("%s — %s" % [weapon.base.display_name,
		", ".join(_item_facts(weapon))])
	if loadout.has("offhand"):
		var offhand := ItemLibrary.make_item(loadout["offhand"])
		lines.append(Loc.pick("Nebenhand: %s — %s", "Off-hand: %s — %s")
			% [offhand.base.display_name, ", ".join(_item_facts(offhand))])
	lines.append(Loc.pick("Start-Skill: %s", "Starter skill: %s")
		% loadout["skill_name"])
	return "\n".join(lines)


## Die Kernwerte eines Items als kurze Fakten-Liste.
static func _item_facts(item: ItemInstance) -> Array[String]:
	var facts: Array[String] = []
	if item.get_total_damage() > 0:
		var subtype_names: Array[String] = []
		for subtype in item.base.weapon_subtypes:
			subtype_names.append(Enums.physical_subtype_name(subtype))
		if subtype_names.is_empty():
			facts.append(Loc.pick("+%d Schaden", "+%d damage") % item.get_total_damage())
		else:
			facts.append(Loc.pick("+%d Schaden (%s)", "+%d damage (%s)")
				% [item.get_total_damage(), "/".join(subtype_names)])
	if item.base.hit_count > 1:
		facts.append(Loc.pick("%d Treffer pro Angriff", "%d hits per attack")
			% item.base.hit_count)
	if item.base.armor_pierce > 0.0:
		facts.append(Loc.pick("ignoriert %d%% Rüstung", "ignores %d%% armor")
			% roundi(item.base.armor_pierce * 100))
	if item.get_total_spell_damage() > 0:
		facts.append(Loc.pick("+%d Zauberkraft", "+%d spell power")
			% item.get_total_spell_damage())
	if item.base.base_armor > 0:
		facts.append(Loc.pick("+%d Rüstung", "+%d armor") % item.base.base_armor)
	if item.base.stat_bonus != null:
		for stat in StatBlock.STAT_NAMES:
			var bonus := int(item.base.stat_bonus.get(stat))
			if bonus > 0:
				facts.append("+%d %s" % [bonus,
					Loc.pick(STAT_LABELS[stat][0], STAT_LABELS[stat][1])])
	if item.base.ranged:
		facts.append(Loc.pick("Fernkampf", "ranged"))
	elif item.base.two_handed:
		facts.append(Loc.pick("zweihändig", "two-handed"))
	if item.base.light:
		facts.append(Loc.pick("leicht (Dual Wield)", "light (dual wield)"))
	if item.base.quiver:
		facts.append(Loc.pick("nur mit Bogen/Armbrust", "bow/crossbow only"))
	return facts
