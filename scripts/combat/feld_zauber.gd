class_name FeldZauber
extends RefCounted
## Skills auf Party-Mitglieder AUSSERHALB des Kampfs (Inventar » Tränke &
## Feldzauber): Heilig-Heilung (auch Vollheilung), Reinigung, Wiederbeleben,
## Lebensgabe und Innere Ruhe. Gleiche Formeln wie im Kampf (Battle), normale
## MP-Kosten — Vollheilung kostet wie dort nach Bedarf (Lutz 2026-11-09: der
## Heiler soll draußen Status und HP heilen können, wenn er das Mana hat).
## Ohne Nutzen (alle gesund, nichts zu kurieren) wird nichts gewirkt und kein
## Mana verbraucht. Reine Logik, headless testbar (skillbau_selftest).

## Effekte, die draußen wirken.
const FELD_EFFEKTE: Array[Enums.Status] = [Enums.Status.CLEANSE, Enums.Status.REVIVE,
	Enums.Status.LEBENSGABE, Enums.Status.INNERE_RUHE]


## Feld-tauglich: gültig, Form Verbündeter/Aura/Selbst und eine heilende oder
## kurierende Wirkung.
static func ist_feldzauber(skill: Skill, caster: Combatant) -> bool:
	if not skill.is_valid(caster):
		return false
	if not skill.get_form() in [Enums.SkillForm.ALLY, Enums.SkillForm.AURA, Enums.SkillForm.SELF]:
		return false
	if _heilig(skill):
		return true
	for effect in skill.get_effect_blocks():
		if effect.status in FELD_EFFEKTE:
			return true
	return false


## Wen der Zauber trifft: Verbündeter = das gewählte Ziel, Aura = die Party,
## Selbst = der Wirkende.
static func ziele(skill: Skill, caster: Combatant, gewaehlt: Combatant, party: Array) -> Array[Combatant]:
	var result: Array[Combatant] = []
	match skill.get_form():
		Enums.SkillForm.ALLY:
			if gewaehlt != null:
				result.append(gewaehlt)
		Enums.SkillForm.AURA:
			for held in party:
				result.append(held)
		Enums.SkillForm.SELF:
			result.append(caster)
	return result


## Hätte der Zauber auf diese Ziele eine Wirkung? (sonst: nicht wirken)
static func nutzen(skill: Skill, caster: Combatant, ziel_liste: Array[Combatant]) -> bool:
	for ziel in ziel_liste:
		if ziel.is_alive() and ziel.hp < ziel.max_hp and _heilig(skill):
			return true
		for effect in skill.get_effect_blocks():
			match effect.status:
				Enums.Status.CLEANSE:
					if ziel.is_alive() and _hat_leiden(ziel):
						return true
				Enums.Status.REVIVE:
					if not ziel.is_alive():
						return true
				Enums.Status.LEBENSGABE:
					if ziel != caster and ziel.is_alive() and ziel.hp < ziel.max_hp and caster.hp > 1:
						return true
				Enums.Status.INNERE_RUHE:
					if ziel.is_alive() and ziel.hp < ziel.max_hp:
						return true
	return false


## MP-Kosten für diese Ziele: normal wie im Kampf; Vollheilung nach Bedarf
## (höchstens alle MP). 0 = nichts zu bezahlen bzw. nichts zu heilen.
static func kosten(skill: Skill, caster: Combatant, ziel_liste: Array[Combatant]) -> int:
	if _nach_bedarf(skill, ziel_liste):
		return int(_vollheil_plan(skill, caster, ziel_liste)["kosten"])
	return skill.get_mp_cost(caster)


## Kann der Wirkende den Zauber jetzt wirken (lebt, Nutzen, genug Mana)?
## Vollheilung braucht nur 1 MP (sie heilt dann anteilig, wie im Kampf).
static func wirkbar(skill: Skill, caster: Combatant, ziel_liste: Array[Combatant]) -> bool:
	if not caster.is_alive() or not nutzen(skill, caster, ziel_liste):
		return false
	if _nach_bedarf(skill, ziel_liste):
		return caster.mp >= 1
	return caster.mp >= skill.get_mp_cost(caster)


## Wirkt den Zauber (zieht MP ab). Gibt eine kurze Zeile für die Anzeige
## zurück ("" = nichts gewirkt).
static func wirken(skill: Skill, caster: Combatant, ziel_liste: Array[Combatant]) -> String:
	if not wirkbar(skill, caster, ziel_liste):
		return ""
	var teile: Array[String] = []
	var plan := {}
	if _nach_bedarf(skill, ziel_liste):
		plan = _vollheil_plan(skill, caster, ziel_liste)
		caster.mp -= int(plan["kosten"])
	else:
		caster.mp -= skill.get_mp_cost(caster)
	var koerper := skill.has_source(Enums.SkillSource.KOERPER)
	var vit := Battle.vit_prozent_faktor(caster) if koerper else 1.0
	for ziel in ziel_liste:
		# Wiederbeleben zuerst — danach heilt die Heilung den Belebten mit.
		for effect in skill.get_effect_blocks():
			if effect.status == Enums.Status.REVIVE and not ziel.is_alive():
				ziel.hp = maxi(1, roundi(ziel.max_hp * effect.potency / 100.0))
				_leiden_weg(ziel)
				teile.append(Loc.pick("%s steht auf", "%s gets up") % ziel.display_name)
		if not ziel.is_alive():
			continue
		if _heilig(skill) and ziel.hp < ziel.max_hp:
			var menge: int
			if not plan.is_empty():
				menge = int((plan["menge"] as Dictionary).get(ziel, 0))
			else:
				menge = roundi(Battle.normale_heilung(caster, skill))
			var vorher := ziel.hp
			ziel.heal(menge)
			if ziel.hp > vorher:
				teile.append("%s +%d HP" % [ziel.display_name, ziel.hp - vorher])
		for effect in skill.get_effect_blocks():
			match effect.status:
				Enums.Status.CLEANSE:
					if _hat_leiden(ziel):
						_leiden_weg(ziel)
						teile.append(Loc.pick("%s gereinigt", "%s cleansed") % ziel.display_name)
				Enums.Status.LEBENSGABE:
					if ziel != caster and ziel.hp < ziel.max_hp:
						var gabe := mini(roundi(caster.max_hp * effect.potency / 100.0 * vit), caster.hp - 1)
						gabe = mini(gabe, ziel.max_hp - ziel.hp)
						if gabe > 0:
							caster.hp -= gabe
							ziel.heal(gabe)
							teile.append("%s +%d HP" % [ziel.display_name, gabe])
				Enums.Status.INNERE_RUHE:
					if ziel.hp < ziel.max_hp:
						var vorher := ziel.hp
						ziel.heal(maxi(1, roundi(ziel.max_hp * effect.potency / 100.0 * vit)))
						teile.append("%s +%d HP" % [ziel.display_name, ziel.hp - vorher])
	return "%s: %s" % [skill.display_name, ", ".join(teile)] if not teile.is_empty() else skill.display_name


# --- intern ----------------------------------------------------------------------

static func _heilig(skill: Skill) -> bool:
	var element := skill.get_element()
	return element != null and element.element == Enums.Element.HOLY \
		and skill.has_source(Enums.SkillSource.SPELL)


static func _hat_leiden(held: Combatant) -> bool:
	for entry in held.statuses:
		if entry["status"] in Battle.CURABLE_STATUSES:
			return true
	return false


static func _leiden_weg(held: Combatant) -> void:
	for entry in held.statuses.duplicate():
		if entry["status"] in Battle.CURABLE_STATUSES:
			held.statuses.erase(entry)


static func _verwundet(ziel_liste: Array[Combatant]) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for ziel in ziel_liste:
		if ziel.is_alive() and ziel.hp < ziel.max_hp:
			result.append(ziel)
	return result


## Vollheilung mit Verwundeten kostet nach Bedarf; ohne Verwundete (aber mit
## anderer Wirkung, z. B. Reinigung) gelten die normalen Kosten.
static func _nach_bedarf(skill: Skill, ziel_liste: Array[Combatant]) -> bool:
	return skill.hat(Enums.SkillModifier.VOLLHEILUNG) and _heilig(skill) \
		and not _verwundet(ziel_liste).is_empty()


## Wie Battle._vollheilung_planen: Heilung je MP aus normaler Heilung ÷
## normalen Kosten. Reicht das Mana, heilt sie alle voll und kostet nur das
## Nötige; sonst alle MP für anteilige Heilung.
static func _vollheil_plan(skill: Skill, caster: Combatant, ziel_liste: Array[Combatant]) -> Dictionary:
	var verwundet := _verwundet(ziel_liste)
	var summe := 0
	for ziel in verwundet:
		summe += ziel.max_hp - ziel.hp
	if summe <= 0:
		return {"kosten": 0, "menge": {}}
	var pro_wurf := Battle.normale_heilung(caster, skill) * maxi(1, ziel_liste.size())
	var heil_pro_mp := pro_wurf / maxf(1.0, skill.get_mp_cost(caster))
	var noetig := maxi(1, ceili(summe / maxf(0.001, heil_pro_mp)))
	var zahlen := mini(noetig, caster.mp)
	var anteil := minf(1.0, float(zahlen) / noetig) if zahlen > 0 else 0.0
	var menge := {}
	for ziel in verwundet:
		menge[ziel] = maxi(1, roundi((ziel.max_hp - ziel.hp) * anteil))
	return {"kosten": zahlen, "menge": menge}
