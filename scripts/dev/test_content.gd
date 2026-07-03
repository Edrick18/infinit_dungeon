class_name TestContent
extends RefCounted
## Handgebauter Platzhalter-Content für den Kampf-Prototyp.
## Skills entstehen aus den kanonischen Bausteinen der BlockLibrary (per ID
## geteilt → speicherbar). Der Schaden kommt aus der Startwaffe (Phase-3-Rework).


static func make_party() -> Array[Combatant]:
	# Klassenlos und gleichberechtigt: alle Helden starten Level 1, überall 5.
	# Rolle entsteht aus Statuspunkten, Bauklötzen und Ausrüstung — nur die
	# Startwaffe + der Start-Skill geben eine erste Richtung.
	var aldric := _hero("Aldric", &"kurzschwert",
		[_skill("Waffenhieb", [&"src_weapon"])])
	var mira := _hero("Mira", &"lehrlingsstab",
		[_skill("Feuerball", [&"src_spell", &"elem_fire"])])
	var talin := _hero("Talin", &"lehrlingsstab",
		[_skill("Heilende Aura", [&"src_spell", &"form_aura", &"eff_regen", &"eff_shield"])])
	var runa := _hero("Runa", &"lehrlingsstab",
		[_skill("Giftwolke", [&"src_spell", &"elem_poison", &"form_aoe"])])
	return [aldric, mira, talin, runa]


static func _hero(name: String, weapon_id: StringName, skills: Array[Skill]) -> Combatant:
	var hero := Combatant.create(name, _stats(5, 5, 5, 5, 5, 5), true)
	hero.skills = skills
	hero.sprite = SpriteLib.hero(name)
	var weapon := ItemLibrary.make_item(weapon_id)
	if weapon != null:
		hero.equip(weapon)
	return hero


# --- Baustein-Helfer --------------------------------------------------------

static func _stats(strength: int, intelligence: int, vitality: int,
		spirit: int, agility: int, luck: int) -> StatBlock:
	var s := StatBlock.new()
	s.strength = strength
	s.intelligence = intelligence
	s.vitality = vitality
	s.spirit = spirit
	s.agility = agility
	s.luck = luck
	return s


## Baut einen Skill aus kanonischen BlockLibrary-Bausteinen (per ID).
static func _skill(name: String, block_ids: Array) -> Skill:
	var skill := Skill.new()
	skill.display_name = name
	for id in block_ids:
		var block := BlockLibrary.get_block(id)
		assert(block != null, "Unbekannter Baustein: %s" % id)
		skill.blocks.append(block)
	return skill
