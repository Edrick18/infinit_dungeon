class_name BossBeute
extends RefCounted
## Boss-Beute (statt fester Unikate): Items aus einem Bosskampf tragen mit
## kleiner Chance einen BOSS-AFFIX aus dem Pool ihres Bosses
## (ItemLibrary.BOSS_AFFIXE) — auf beliebiger Basis, zusätzlich zu den
## normalen Affixen, mit gewürfeltem Qualitäts-Roll. Eine bestimmte
## Kombination (Basis × Boss-Affix × normale Affixe) bleibt so selten.
## Gespeichert wird nur die Affix-ID (ItemInstance.to_dict).
##
## Kampfwirkung der eigenen Effekte (boss_effekt) über drei Haken in Battle:
## schadens_faktor (_deal_damage), nach_treffer (_deal_damage), zugbeginn
## (_process_turn_start). Alles nur für Helden.

## Chance je Item eines Bosskampfs.
const CHANCE := 0.12
## Legacy-Bosse (legendäre Karten) etwas öfter.
const CHANCE_LEGACY := 0.2

## Obergrenze je Effekt über die ganze Ausrüstung (Prozent).
const DECKEL := {
	&"wut": 40, &"jaeger": 40, &"steinhaut": 25, &"verschlingen": 15,
	&"opfergabe": 15, &"lebensraub": 15, &"regeneration": 6, &"rache": 30,
}

## Effekt » [DE, EN] mit %d = Prozent.
const TEXTE := {
	&"wut": ["+%d %% Schaden, solange die eigenen HP unter 50 %% liegen",
		"+%d%% damage while own HP is below 50%%"],
	&"jaeger": ["+%d %% Schaden gegen Ziele unter 50 %% HP", "+%d%% damage against targets below 50%% HP"],
	&"steinhaut": ["%d %% weniger erlittener Schaden", "%d%% less damage taken"],
	&"verschlingen": ["heilt %d %% der Max-HP beim Besiegen eines Gegners",
		"heals %d%% of max HP when defeating an enemy"],
	&"opfergabe": ["stellt %d %% der Max-MP beim Besiegen eines Gegners wieder her",
		"restores %d%% of max MP when defeating an enemy"],
	&"lebensraub": ["heilt um %d %% des verursachten Schadens", "heals for %d%% of damage dealt"],
	&"regeneration": ["heilt zu Beginn jedes Zuges %d %% der Max-HP, außer bei Brand oder Gift",
		"heals %d%% of max HP at the start of each turn, except while burning or poisoned"],
	&"rache": ["wirft %d %% des erlittenen Schadens auf den Angreifer zurück",
		"reflects %d%% of damage taken back to the attacker"],
}


## Bosse ohne eigenen Affix-Pool in ItemLibrary nutzen den Pool eines
## verwandten Bosses ihres Bioms (Höllenschlund 2026-11-02: der Aschekoloss
## lässt die Glut- und Rache-Affixe des Dämonen-Königs fallen).
const POOL_VERWANDT := {&"aschekoloss": &"demonenkonig"}


## Boss, dessen Affix-Pool für diesen Boss gilt.
static func pool_boss(boss_id: StringName) -> StringName:
	if ItemLibrary.boss_affixe(boss_id).is_empty() and POOL_VERWANDT.has(boss_id):
		return POOL_VERWANDT[boss_id]
	return boss_id


## Boss-Grundtyp eines Bosskampfs (der Boss selbst, nicht die Begleiter).
static func boss_von(gegner: Array[Combatant]) -> StringName:
	for foe in gegner:
		if foe.ist_bossgegner or foe.is_boss:
			return foe.archetype_id
	return &""


## Boss-Beute würfeln: jedes Item mit `chance` ein Boss-Affix dieses Bosses.
## Gibt die Zahl der veränderten Items zurück.
static func beute_wuerfeln(items: Array, boss_id: StringName, rng: RandomNumberGenerator,
		chance := CHANCE) -> int:
	boss_id = pool_boss(boss_id)
	if boss_id == &"" or ItemLibrary.boss_affixe(boss_id).is_empty():
		return 0
	var anzahl := 0
	for item in items:
		if rng.randf() < chance and boss_affix_hinzufuegen(item, boss_id, rng):
			anzahl += 1
	return anzahl


## Hängt einen passenden Boss-Affix an (höchstens einer je Item). false,
## wenn das Item schon einen trägt oder keiner auf seinen Slot passt.
static func boss_affix_hinzufuegen(item: ItemInstance, boss_id: StringName,
		rng: RandomNumberGenerator) -> bool:
	if hat_boss_affix(item):
		return false
	var pool: Array[Affix] = []
	for affix in ItemLibrary.boss_affixe(pool_boss(boss_id)):
		if affix.allowed_slots.is_empty() or item.base.slot in affix.allowed_slots:
			pool.append(affix)
	if pool.is_empty():
		return false
	item.affixes.append(pool[rng.randi_range(0, pool.size() - 1)])
	item.affix_rolls.append(snappedf(rng.randf_range(LootGenerator.AFFIX_ROLL_MIN,
		LootGenerator.AFFIX_ROLL_MAX), 0.01))
	return true


static func hat_boss_affix(item: ItemInstance) -> bool:
	for affix in item.affixes:
		if affix.boss_id != &"":
			return true
	return false


## Zeile für die Item-Karte: „Boss-Beute (Schleimgott): heilt 5 % …“; bei
## Boss-Affixen über normale Mechaniken nur der Boss (der Wert steht oben).
static func eigenschaft_text(item: ItemInstance, index: int) -> String:
	var affix := item.affixes[index]
	var boss := EnemyLibrary.get_archetype(affix.boss_id)
	var boss_name := boss.display_name if boss != null else String(affix.boss_id)
	if affix.boss_effekt == &"" or not TEXTE.has(affix.boss_effekt):
		return Loc.pick("Boss-Beute (%s)", "Boss loot (%s)") % boss_name
	var t: Array = TEXTE[affix.boss_effekt]
	return Loc.pick("Boss-Beute (%s): ", "Boss loot (%s): ") % boss_name \
		+ Loc.pick(t[0], t[1]) % item.affix_value(index, affix.boss_wert)


## Summe eines Effekts über die getragene Ausrüstung (Prozent, gedeckelt).
static func wert(c: Combatant, effekt: StringName) -> int:
	if c == null or not c.is_player:
		return 0
	var summe := 0
	for slot in c.equipment:
		var item: ItemInstance = c.equipment[slot]
		if item == null:
			continue
		for i in item.affixes.size():
			if item.affixes[i].boss_effekt == effekt:
				summe += item.affix_value(i, item.affixes[i].boss_wert)
	return mini(summe, int(DECKEL.get(effekt, 0)))


## Schadensfaktor eines Treffers: Wut/Jäger des Angreifers, Steinhaut des Ziels.
static func schadens_faktor(angreifer: Combatant, ziel: Combatant) -> float:
	var faktor := 1.0
	if angreifer != null and angreifer.is_player:
		if angreifer.hp < angreifer.max_hp * 0.5:
			faktor += wert(angreifer, &"wut") / 100.0
		if ziel != null and ziel.hp < ziel.max_hp * 0.5:
			faktor += wert(angreifer, &"jaeger") / 100.0
	if ziel != null and ziel.is_player:
		faktor *= 1.0 - wert(ziel, &"steinhaut") / 100.0
	return faktor


## Nach einem Treffer: Lebensraub, Heilung/MP beim Besiegen, Rache.
static func nach_treffer(battle: Battle, angreifer: Combatant, ziel: Combatant, schaden: int) -> void:
	if schaden <= 0 or angreifer == null or ziel == null or angreifer == ziel:
		return
	if angreifer.is_player and angreifer.is_alive():
		var raub := wert(angreifer, &"lebensraub")
		if raub > 0:
			angreifer.heal(maxi(1, roundi(schaden * raub / 100.0)))
		if not ziel.is_alive() and not ziel.is_player:
			var hp_plus := wert(angreifer, &"verschlingen")
			if hp_plus > 0:
				var menge := maxi(1, roundi(angreifer.max_hp * hp_plus / 100.0))
				angreifer.heal(menge)
				battle.log_line.emit(Loc.pick("%s heilt %d HP (Boss-Beute).", "%s heals %d HP (boss loot).")
					% [angreifer.display_name, menge])
			var mp_plus := wert(angreifer, &"opfergabe")
			if mp_plus > 0 and angreifer.max_mp > 0:
				var mana := maxi(1, roundi(angreifer.max_mp * mp_plus / 100.0))
				angreifer.mp = mini(angreifer.max_mp, angreifer.mp + mana)
				battle.log_line.emit(Loc.pick("%s erhält %d MP (Boss-Beute).", "%s gains %d MP (boss loot).")
					% [angreifer.display_name, mana])
	# Rache: nie als Antwort auf einen Rückschlag (keine Kaskaden).
	if ziel.is_player and ziel.is_alive() and angreifer.is_alive() and not battle._retaliating:
		var rache := wert(ziel, &"rache")
		if rache > 0:
			battle._retaliating = true
			var zurueck := angreifer.take_damage(maxi(1, roundi(schaden * rache / 100.0)))
			battle._retaliating = false
			battle.log_line.emit(Loc.pick("Rache: %s erleidet %d Schaden.", "Vengeance: %s suffers %d damage.")
				% [angreifer.display_name, zurueck])
			if not angreifer.is_alive():
				battle.log_line.emit(Loc.pick("%s wurde besiegt!", "%s was defeated!") % angreifer.display_name)


## Zugbeginn: Regeneration (Brand/Gift blockieren sie, wie jede Regeneration).
static func zugbeginn(battle: Battle, actor: Combatant, hatte_dot: bool) -> void:
	if not actor.is_player or not actor.is_alive() or hatte_dot or actor.hp >= actor.max_hp:
		return
	var regen := wert(actor, &"regeneration")
	if regen <= 0:
		return
	var menge := maxi(1, roundi(actor.max_hp * regen / 100.0))
	actor.heal(menge)
	battle.log_line.emit(Loc.pick("%s regeneriert %d HP (Boss-Beute).", "%s regenerates %d HP (boss loot).")
		% [actor.display_name, menge])
