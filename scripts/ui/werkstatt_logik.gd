class_name WerkstattLogik
extends RefCounted
## Regeln der Skill-Werkstatt ohne UI (headless testbar): passt ein Klotz in
## einen Sockel, wie repariert man einen Skill aus der Zeit vor den Bauregeln,
## und welche Vorlagen kann ein Held bauen.


## Vorlagen: [Name DE, Name EN, Klotz-IDs]. Angeboten wird nur, was der Held
## freigeschaltet hat und was in seine Sockel passt. Muster wie Hagel, Salve
## oder Kettenblitz gibt es nicht als Klotz — die Vorlagen zeigen, wie man
## sie aus Grundbausteinen baut.
const REZEPTE := [
	["Doppelschlag", "Double strike", [&"src_weapon", &"mod_treffer"]],
	["Wirbelhieb", "Whirlwind", [&"src_weapon", &"form_aoe"]],
	["Präzisionsstoß", "Precise thrust", [&"src_weapon", &"mod_praezision"]],
	["Pfeilhagel", "Arrow hail", [&"src_weapon", &"mod_treffer", &"mod_treffer", &"mod_ziel_zufall"]],
	["Fächerschlag", "Fan strike", [&"src_weapon", &"mod_treffer", &"mod_treffer", &"mod_ziel_wechsel"]],
	["Wuchtschlag", "Heavy blow", [&"src_weapon", &"mod_wucht"]],
	["Flammenhieb", "Flame slash", [&"src_weapon", &"elem_fire"]],
	["Giftklinge", "Venom blade", [&"src_weapon", &"elem_poison"]],
	["Betäubungsschlag", "Stunning blow", [&"src_weapon", &"eff_stun"]],
	["Lebensraub", "Life drain", [&"src_weapon", &"eff_lifesteal"]],
	["Hinrichter", "Executioner", [&"src_weapon", &"mod_execute", &"mod_wucht"]],
	["Feuerball", "Fireball", [&"src_spell", &"elem_fire"]],
	["Eissplitter", "Ice shard", [&"src_spell", &"elem_ice"]],
	["Blitzschlag", "Lightning bolt", [&"src_spell", &"elem_lightning"]],
	["Kettenblitz", "Chain lightning", [&"src_spell", &"elem_lightning", &"mod_treffer", &"mod_treffer", &"mod_ziel_wechsel"]],
	["Meteor", "Meteor", [&"src_spell", &"elem_fire", &"mod_aufladen"]],
	["Giftwolke", "Poison cloud", [&"src_spell", &"elem_poison", &"form_aoe"]],
	["Eissturm", "Ice storm", [&"src_spell", &"elem_ice", &"form_aoe"]],
	["Feuersturm", "Firestorm", [&"src_spell", &"elem_fire", &"form_aoe"]],
	["Heilung", "Heal", [&"src_spell", &"elem_holy", &"form_ally"]],
	["Heilende Aura", "Healing aura", [&"src_spell", &"elem_holy", &"form_aura"]],
	["Schutzschild", "Barrier", [&"src_spell", &"form_self", &"eff_shield"]],
	["Schlachtruf", "Battle cry", [&"src_spell", &"form_aura", &"eff_atk_up"]],
	["Bollwerk", "Rampart", [&"src_spell", &"form_aura", &"eff_def_up"]],
	["Schwächen", "Weaken", [&"src_spell", &"eff_weaken"]],
	["Beschwörung", "Summon", [&"src_spell", &"form_summon"]],
	["Wiederbeleben", "Revive", [&"src_spell", &"form_aura", &"eff_revive"]],
	["Rammstoß", "Ram", [&"src_koerper"]],
	["Schutzwall", "Bulwark wall", [&"src_koerper", &"form_self", &"eff_protect"]],
	["Provozieren", "Taunt", [&"src_koerper", &"form_self", &"eff_provozieren"]],
	["Innere Ruhe", "Inner calm", [&"src_koerper", &"form_self", &"eff_innere_ruhe"]],
	["Lebensgabe", "Life gift", [&"src_koerper", &"form_ally", &"eff_lebensgabe"]],
	["Eile", "Haste", [&"src_spell", &"form_aura", &"eff_eile"]],
	["Schweigen", "Silence", [&"src_spell", &"eff_schweigen"]],
	["Kraftschlag", "Reckless blow", [&"src_weapon", &"mod_rueckschlag"]],
]

## Was passiert, wenn `block` in Sockel `index` kommt? "" = passt, sonst der
## Grund. Unfertig (noch keine Quelle) ist erlaubt, und ein Fehler, den der
## Skill ohnehin schon hat, sperrt nicht (man soll ihn reparieren können).
static func passt(skill: Skill, index: int, block: SkillBlock, held: Combatant) -> String:
	var probe := Skill.new()
	probe.blocks = skill.blocks.duplicate()
	if index < probe.blocks.size():
		probe.blocks[index] = block
	else:
		probe.blocks.append(block)
	if probe.get_sources().is_empty():
		return ""
	var grund := probe.fehler(held)
	if grund.is_empty() or grund == skill.fehler(held):
		return ""
	return grund


## Behält Klotz für Klotz nur, was keine Regel bricht (der erste gewinnt) und
## in die Sockel des Helden passt.
static func repariert(blocks: Array[SkillBlock], held: Combatant) -> Array[SkillBlock]:
	var neu: Array[SkillBlock] = []
	for block in blocks:
		if neu.size() >= held.block_sockets():
			break
		var probe := Skill.new()
		probe.blocks = neu.duplicate()
		probe.blocks.append(block)
		# Noch ohne Quelle: mit einer Platzhalter-Quelle prüfen, damit z.B.
		# zwei Elemente VOR dem Zauber nicht beide durchrutschen.
		if probe.get_sources().is_empty():
			probe.blocks.append(BlockLibrary.get_block(&"src_spell"))
		if probe.fehler(held).is_empty():
			neu.append(block)
	return neu


## Vorlagen ([Name DE, Name EN, Klotz-IDs]), die `held` bauen kann:
## alle Klötze freigeschaltet (`ist_frei.call(block)`) und gültig.
static func vorlagen(rezepte: Array, held: Combatant, ist_frei: Callable) -> Array[Skill]:
	var result: Array[Skill] = []
	for rezept in rezepte:
		var skill := Skill.new()
		var frei := true
		for id in rezept[2]:
			var block := BlockLibrary.get_block(id)
			if block == null or not ist_frei.call(block):
				frei = false
				break
			skill.blocks.append(block)
		if frei and skill.is_valid(held):
			skill.display_name = Loc.pick(rezept[0], rezept[1])
			result.append(skill)
	return result


# --- Rezeptbuch -------------------------------------------------------------------
# Beliebig viele gespeicherte Bauten pro Held (Combatant.rezeptbuch); in den
# Kampf gehen nur die Skills in den Slots. Tauschen verliert nie etwas: der
# bisherige Slot-Skill wandert ins Buch.

## Gleiche Klötze in gleicher Reihenfolge (der Name zählt nicht).
static func gleiches_rezept(a: Skill, b: Skill) -> bool:
	if a.blocks.size() != b.blocks.size():
		return false
	for i in a.blocks.size():
		if a.blocks[i].id != b.blocks[i].id:
			return false
	return true


static func im_buch(held: Combatant, skill: Skill) -> bool:
	for eintrag in held.rezeptbuch:
		if gleiches_rezept(eintrag, skill):
			return true
	return false


## Legt eine Kopie ins Rezeptbuch. false = leer oder schon drin.
static func ins_buch(held: Combatant, skill: Skill) -> bool:
	if skill.blocks.is_empty() or im_buch(held, skill):
		return false
	var kopie := Skill.new()
	kopie.display_name = skill.display_name
	kopie.blocks = skill.blocks.duplicate()
	held.rezeptbuch.append(kopie)
	return true


## Rüstet Eintrag `buch_index` in Slot `slot` aus. Der bisherige Slot-Skill
## kommt ins Buch (falls er nicht leer und nicht schon drin ist).
static func ausruesten(held: Combatant, buch_index: int, slot: int) -> void:
	if buch_index < 0 or buch_index >= held.rezeptbuch.size() or slot < 0:
		return
	var neu: Skill = held.rezeptbuch[buch_index]
	held.rezeptbuch.remove_at(buch_index)
	while held.skills.size() <= slot:
		var leer := Skill.new()
		leer.display_name = Loc.pick("Neuer Skill", "New skill")
		held.skills.append(leer)
	var alt: Skill = held.skills[slot]
	held.skills[slot] = neu
	if not alt.blocks.is_empty() and not im_buch(held, alt):
		held.rezeptbuch.insert(mini(buch_index, held.rezeptbuch.size()), alt)
