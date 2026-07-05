class_name HeroLibrary
extends RefCounted
## Die anheuerbaren Helden und die wählbaren Starter-Kits.
## Klassenlos: JEDER Held startet mit Level 1 und 5 auf allen Werten —
## nur Startwaffe + Start-Skill geben eine erste Richtung, alles ist
## später über Statuspunkte, Bauklötze und Ausrüstung umbaubar.
## Mehr Helden als Party-Plätze: Der Rest wartet auf der Taverne-Bank
## (Austauschen jederzeit; Bank-Helden machen Platz für Co-op-Gäste).

const MAX_PARTY_SIZE := 4

## Die Helden-Auswahl (Name = Schlüssel für Porträt in SpriteLib.HERO_TILES).
const HERO_NAMES: Array[String] = ["Aldric", "Mira", "Talin", "Runa",
	"Edda", "Björn", "Liora", "Kaspar", "Selma", "Dorn"]

## Starter-Kits: Waffe + vorgebauter Skill aus kanonischen Bausteinen.
## Reine Presets, keine Klassen — die Bausteine sind dieselben wie überall.
const STARTER_KITS := {
	&"krieger": {
		"name": "Krieger", "weapon": &"schwert", "skill_name": "Waffenhieb",
		"blocks": [&"src_weapon"],
		"desc": "Schwert — Nahkampf, Schaden aus der Waffe",
	},
	&"feuermagier": {
		"name": "Feuermagier", "weapon": &"offensivstab", "skill_name": "Feuerball",
		"blocks": [&"src_spell", &"elem_fire"],
		"desc": "Offensivstab — Feuerzauber, baut Brand-Stacks auf",
	},
	&"heiler": {
		"name": "Heiler", "weapon": &"heiligstab", "skill_name": "Heilende Aura",
		"blocks": [&"src_spell", &"form_aura", &"eff_regen", &"eff_shield"],
		"desc": "Heiligstab — Aura mit Regeneration und Schild für die Party",
	},
	&"giftmischer": {
		"name": "Giftmischer", "weapon": &"offensivstab", "skill_name": "Giftwolke",
		"blocks": [&"src_spell", &"elem_poison", &"form_aoe"],
		"desc": "Offensivstab — Flächengift, permanente Gift-Stacks auf alle",
	},
}


## Helden-Namen, die weder in der Party noch auf der Bank sind
## (Rekruten-Pool der Taverne).
static func available_names(hired: Array[Combatant]) -> Array[String]:
	var taken := {}
	for member in hired:
		taken[member.display_name] = true
	var result: Array[String] = []
	for name in HERO_NAMES:
		if not taken.has(name):
			result.append(name)
	return result


## Frischer Held: Level 1, überall 5, Kit-Waffe angelegt, Kit-Skill gelernt.
static func create_hero(hero_name: String, kit_id: StringName) -> Combatant:
	var kit: Dictionary = STARTER_KITS.get(kit_id, STARTER_KITS[&"krieger"])
	var stats := StatBlock.new()
	for stat in StatBlock.STAT_NAMES:
		stats.set(stat, 5)
	var hero := Combatant.create(hero_name, stats, true)
	hero.sprite = SpriteLib.hero(hero_name)

	var skill := Skill.new()
	skill.display_name = kit["skill_name"]
	for block_id in kit["blocks"]:
		var block := BlockLibrary.get_block(block_id)
		assert(block != null, "Unbekannter Baustein im Starter-Kit: %s" % block_id)
		skill.blocks.append(block)
	hero.skills = [skill]

	var weapon := ItemLibrary.make_item(kit["weapon"])
	if weapon != null:
		hero.equip(weapon)
	return hero
