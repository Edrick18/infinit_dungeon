class_name BlockLibrary
extends RefCounted
## Katalog aller Skill-Bausteine (Skillbau 3.0) mit Freischaltbedingungen und
## Bauregeln (REGELN). Universelle Klötze kommen über das Charakter-Level,
## Waffen-Klötze über das Waffen-Training ihrer Gattung.
## Vorerst im Code definiert; später können die Bausteine als .tres-Dateien
## in data/ liegen und hier nur noch geladen werden.

static var _blocks: Dictionary = {}


## Sprachwechsel: Cache leeren, Namen backen sich neu.
static func reset_cache() -> void:
	_blocks.clear()


static func all_blocks() -> Array[SkillBlock]:
	_ensure_built()
	var result: Array[SkillBlock] = []
	for id in _blocks:
		result.append(_blocks[id])
	return result


static func get_block(id: StringName) -> SkillBlock:
	_ensure_built()
	return _blocks.get(id)


## Element-Baustein zu einem Element (für Element-Rider auf Waffen und
## Element-Gegner — geteilte Signatur-Logik statt Duplikaten).
static func element_block(element: Enums.Element) -> ElementBlock:
	_ensure_built()
	for id in _blocks:
		var block: SkillBlock = _blocks[id]
		if block is ElementBlock and block.element == element:
			return block
	return null


## Freischalt-Check als reine Funktion (testbar ohne Autoload):
## LEVEL-Bausteine ab Charakter-Level, RESEARCH-Bausteine wenn erforscht.
static func is_unlocked(block: SkillBlock, char_level: int, researched: Array,
		hero: Combatant = null) -> bool:
	match block.unlock_kind:
		Enums.UnlockKind.LEVEL:
			return char_level >= block.unlock_level
		Enums.UnlockKind.TRAINING:
			# Altbestand: früher erforschte Bausteine (z.B. Schutzwall)
			# bleiben freigeschaltet, auch ohne Trainings-Punkte.
			if block.id in researched:
				return true
			return hero != null and hero.invested(block.tree_family) >= block.tree_points
		_:
			return block.id in researched


static func _ensure_built() -> void:
	if not _blocks.is_empty():
		return
	var list: Array[SkillBlock] = []
	var A := EffectBlock.Ziel.ANWENDER
	var P := EffectBlock.Ziel.PARTY
	var G := EffectBlock.Ziel.ALLE_GEGNER

	# =========================================================================
	# UNIVERSELLE KLÖTZE — Freischaltung über das CHARAKTER-LEVEL (Skillbau 3.0):
	# bis Level 24 fast jedes Level einer, danach alle zwei bis fünf Level.
	# Keine fertigen Muster (Streuung, Hagel, Kette …) — Grundbausteine, aus
	# denen man solche Muster SELBST baut. Waffennutzung kostet 1 MP + 15 % STR,
	# Zauber 3 MP + 25 % INT; Zauber haben dafür Heilung, Support und die volle
	# Element-Signatur.
	# =========================================================================
	list.append(_lvl(_source(&"src_weapon", Loc.pick("Waffenangriff", "Weapon attack"), Enums.SkillSource.WEAPON, 1.0, 1.2, 1, 1), 1))
	list.append(_lvl(_source(&"src_spell", Loc.pick("Zauber", "Spell"), Enums.SkillSource.SPELL, 1.0, 1.0, 3, 1), 1))
	list.append(_lvl(_form(&"form_self", Loc.pick("Selbst", "Self"), Enums.SkillForm.SELF, 0.8, 1.0, 1), 1))
	list.append(_lvl(_mod(&"mod_treffer", Loc.pick("Zusatztreffer", "Extra hit"), Enums.SkillModifier.TREFFER, 1, 0, 1), 1))
	list.append(_lvl(_form(&"form_ally", Loc.pick("Verbündeter", "Ally"), Enums.SkillForm.ALLY, 1.0, 1.0, 1), 2))
	list.append(_lvl(_effect(&"eff_weaken", Loc.pick("Schwächen", "Weaken"), Enums.Status.WEAKEN, 80, 2, 25, 3, 1), 2))
	list.append(_lvl(_element(&"elem_fire", Loc.pick("Feuer", "Fire"), Enums.Element.FIRE, 3, 1.0, 2, 1), 3))
	list.append(_lvl(_form(&"form_aoe", Loc.pick("Alle Gegner", "All enemies"), Enums.SkillForm.AOE, 1.6, 0.65, 1), 4))
	list.append(_lvl(_mod(&"mod_praezision", Loc.pick("Präzision", "Precision"), Enums.SkillModifier.KRIT_BONUS, 30, 0, 1), 5))
	list.append(_lvl(_element(&"elem_ice", Loc.pick("Eis", "Ice"), Enums.Element.ICE, 0, 1.0, 3, 1), 6))
	list.append(_lvl(_effect(&"eff_shield", Loc.pick("Schild", "Shield"), Enums.Status.SHIELD, 100, 3, 10, 4, 1), 7))
	list.append(_lvl(_mod(&"mod_ziel_zufall", Loc.pick("Zufallsziel", "Random target"), Enums.SkillModifier.ZIEL_ZUFALL, 0, 0, 1), 8))
	list.append(_lvl(_mod(&"mod_wucht", Loc.pick("Wucht", "Heft"), Enums.SkillModifier.ZEIT_WUCHT, 0, 0, 1), 9))
	list.append(_lvl(_element(&"elem_lightning", Loc.pick("Blitz", "Lightning"), Enums.Element.LIGHTNING, 0, 1.0, 4, 1), 10))
	list.append(_lvl(_effect(&"eff_regen", "Regeneration", Enums.Status.REGEN, 100, 3, 8, 6, 1), 11))
	list.append(_lvl(_mod(&"mod_sparsam", Loc.pick("Sparsam", "Frugal"), Enums.SkillModifier.COST_REDUCTION, 40, 0, 1), 12))
	list.append(_lvl(_mod(&"mod_ziel_wechsel", Loc.pick("Wechselziel", "Switching target"), Enums.SkillModifier.ZIEL_WECHSEL, 0, 0, 1), 13))
	list.append(_lvl(_element(&"elem_poison", Loc.pick("Gift", "Poison"), Enums.Element.POISON, 4, 0.5, 3, 1), 14))
	list.append(_lvl(_mod(&"mod_flinkheit", Loc.pick("Flinkheit", "Swiftness"), Enums.SkillModifier.ZEIT_FLINK, 0, 0, 1), 15))
	list.append(_lvl(_form(&"form_aura", "Aura", Enums.SkillForm.AURA, 1.4, 0.7, 1), 16))
	list.append(_lvl(_mod(&"mod_ausnutzen", Loc.pick("Ausnutzen", "Exploit"), Enums.SkillModifier.AUSNUTZEN, 60, 0, 1), 17))
	list.append(_lvl(_element(&"elem_holy", Loc.pick("Heilig", "Holy"), Enums.Element.HOLY, 0, 1.0, 4, 1), 18))
	list.append(_lvl(_mod(&"mod_aufladen", Loc.pick("Aufladen", "Charge up"), Enums.SkillModifier.AUFLADEN, 0, 0, 1), 19))
	list.append(_lvl(_effect(&"eff_slow", Loc.pick("Verlangsamen", "Slow"), Enums.Status.SLOW, 80, 2, 30, 3, 1), 20))
	list.append(_lvl(_mod(&"mod_execute", Loc.pick("Hinrichtung", "Execution"), Enums.SkillModifier.EXECUTE, 50, 0, 1), 21))
	list.append(_lvl(_mod(&"mod_pierce", Loc.pick("Durchschlag", "Armor pierce"), Enums.SkillModifier.PIERCE_ARMOR, 50, 0, 1), 22))
	list.append(_lvl(_mod(&"mod_overload", Loc.pick("Überladung", "Overload"), Enums.SkillModifier.OVERLOAD, 40, 0, 1), 23))
	list.append(_lvl(_mod(&"mod_entzuenden", Loc.pick("Entzünden", "Ignite"), Enums.SkillModifier.ENTZUENDEN, 100, 0, 1), 24))
	list.append(_lvl(_element(&"elem_dark", Loc.pick("Dunkel", "Dark"), Enums.Element.DARK, 0, 1.0, 4, 1), 26))
	list.append(_lvl(_mod(&"mod_rache", Loc.pick("Rache", "Vengeance"), Enums.SkillModifier.RAGE, 80, 0, 1), 28))
	list.append(_lvl(_mod(&"mod_alles_oder_nichts", Loc.pick("Alles oder nichts", "All or nothing"), Enums.SkillModifier.ALLES_ODER_NICHTS, 0, 0, 1), 30))
	list.append(_lvl(_effect(&"eff_atk_up", Loc.pick("Stärken", "Strengthen"), Enums.Status.ATK_UP, 100, 3, 25, 5, 1), 32))
	list.append(_lvl(_mod(&"mod_ueberschlag", Loc.pick("Überschlag", "Overflow"), Enums.SkillModifier.UEBERSCHLAG, 0, 0, 1), 34))
	list.append(_lvl(_mod(&"mod_nachsetzen", Loc.pick("Nachsetzen", "Follow-up"), Enums.SkillModifier.NACHSETZEN, 60, 0, 1), 36))
	list.append(_lvl(_mod(&"mod_schwachstelle", Loc.pick("Schwachstelle suchen", "Seek weak spot"), Enums.SkillModifier.SCHWACHSTELLE, 20, 0, 1), 38))
	list.append(_lvl(_mod(&"mod_blutpreis", Loc.pick("Blutpreis", "Blood price"), Enums.SkillModifier.BLUTPREIS, 0, 0, 1), 40))
	list.append(_lvl(_effect(&"eff_def_up", Loc.pick("Wappnen", "Brace"), Enums.Status.DEF_UP, 100, 3, 5, 4, 1), 45))
	list.append(_lvl(_effect(&"eff_cleanse", Loc.pick("Reinigen", "Cleanse"), Enums.Status.CLEANSE, 100, 0, 0, 5, 1), 50))
	list.append(_lvl(_form(&"form_summon", Loc.pick("Beschwörung", "Summoning"), Enums.SkillForm.SUMMON, 2.0, 1.0, 1), 60))

	# =========================================================================
	# WAFFEN-KLÖTZE — Waffen-Training der Gattung, nur mit dieser Waffe nutzbar.
	# Sie passen zur Waffe, schreiben aber kein Angriffsmuster vor; die
	# Besonderheit der Waffe (Combatant.TRAIT_NAMES) wirkt zusätzlich.
	# =========================================================================
	# ---- Schwert (Ritter: Duell, Konter, Führung) ----
	list.append(_tech(_auf(_effect(&"tech_konter", Loc.pick("Klingenwall", "Blade wall"), Enums.Status.COUNTER, 100, 2, 60, 4, 1), A), &"schwert", 3))
	list.append(_tech(_mod(&"tech_duellstoss", Loc.pick("Duellstoß", "Duel thrust"), Enums.SkillModifier.DUELL, 60, 0, 1), &"schwert", 6))
	list.append(_tech(_effect(&"tech_entwaffnen", Loc.pick("Entwaffnen", "Disarm"), Enums.Status.WEAKEN, 100, 2, 30, 4, 1), &"schwert", 10))
	list.append(_tech(_auf(_effect(&"tech_kampfruf", Loc.pick("Kampfruf", "Rallying cry"), Enums.Status.ATK_UP, 100, 3, 15, 6, 1), P), &"schwert", 15))
	list.append(_tech(_auf(_effect(&"tech_wachsam", Loc.pick("Wachsamkeit", "Vigilance"), Enums.Status.FIRST_STRIKE, 100, 1, 0, 3, 1), A), &"schwert", 20))
	list.append(_tech(_mod(&"tech_schwertkunst", Loc.pick("Schwertkunst", "Swordsmanship"), Enums.SkillModifier.KRIT_BONUS, 25, 0, 1), &"schwert", 26))
	list.append(_tech(_auf(_effect(&"tech_riposte", "Riposte", Enums.Status.COUNTER, 100, 2, 120, 6, 1), A), &"schwert", 33))
	list.append(_tech(_auf(_effect(&"tech_schutzhieb", Loc.pick("Schutzhieb", "Guarding cut"), Enums.Status.SHIELD, 100, 3, 25, 5, 1), A), &"schwert", 41))
	list.append(_tech(_auf(_effect(&"tech_heldenmut", Loc.pick("Heldenmut", "Valor"), Enums.Status.REGEN, 100, 3, 10, 7, 1), P), &"schwert", 50))
	list.append(_tech(_mod(&"tech_duellmeister", Loc.pick("Duellmeister", "Duel master"), Enums.SkillModifier.DUELL, 150, 0, 1), &"schwert", 62))
	list.append(_tech(_mod(&"tech_klingentanz", Loc.pick("Klingentanz", "Blade dance"), Enums.SkillModifier.TREFFER_VOLL, 0, 0, 1), &"schwert", 76))
	list.append(_tech(_mod(&"tech_sw_meister", Loc.pick("Meisterklinge", "Master blade"), Enums.SkillModifier.KRIT_MULT, 250, 0, 1), &"schwert", 100))

	# ---- Dolch (Assassine: Gift, Tempo, Meucheln) ----
	list.append(_tech(_effect(&"tech_giftklinge", Loc.pick("Giftklinge", "Venom blade"), Enums.Status.POISON_DOT, 100, -1, 30, 3, 1), &"dolch", 3))
	list.append(_tech(_auf(_effect(&"tech_erstschlag", Loc.pick("Schattenschritt", "Shadow step"), Enums.Status.FIRST_STRIKE, 100, 1, 0, 3, 1), A), &"dolch", 6))
	list.append(_tech(_effect(&"tech_blutung", Loc.pick("Blutung", "Bleed"), Enums.Status.BLEED, 100, -1, 30, 4, 1), &"dolch", 10))
	list.append(_tech(_mod(&"tech_meucheln", Loc.pick("Meucheln", "Assassinate"), Enums.SkillModifier.KRIT_MULT, 250, 0, 1), &"dolch", 15))
	list.append(_tech(_effect(&"tech_laehmgift", Loc.pick("Lähmgift", "Paralytic venom"), Enums.Status.SLOW, 100, 2, 35, 4, 1), &"dolch", 20))
	list.append(_tech(_mod(&"tech_schwachpunkt", Loc.pick("Schwachpunkt", "Weak point"), Enums.SkillModifier.SCHWACHSTELLE, 25, 0, 1), &"dolch", 26))
	list.append(_tech(_mod(&"tech_hinterhalt", Loc.pick("Hinterhalt", "Ambush"), Enums.SkillModifier.AUSNUTZEN, 100, 0, 1), &"dolch", 33))
	list.append(_tech(_auf(_effect(&"tech_schattenmantel", Loc.pick("Schattenmantel", "Shadow cloak"), Enums.Status.SHIELD, 100, 2, 20, 4, 1), A), &"dolch", 41))
	list.append(_tech(_mod(&"tech_do_execute2", Loc.pick("Todesstoß", "Death blow"), Enums.SkillModifier.EXECUTE, 150, 0, 1), &"dolch", 50))
	list.append(_tech(_auf(_effect(&"tech_rauchbombe", Loc.pick("Rauchbombe", "Smoke bomb"), Enums.Status.WEAKEN, 100, 2, 25, 6, 1), G), &"dolch", 62))
	list.append(_tech(_mod(&"tech_elementklinge", Loc.pick("Elementklinge", "Infused blade"), Enums.SkillModifier.ELEMENT_FOKUS, 0, 0, 1), &"dolch", 76))

	# ---- Axt (Berserker: Wucht, Wut, Spalten) ----
	list.append(_tech(_mod(&"tech_kopfspalter", Loc.pick("Kopfspalter", "Headsplitter"), Enums.SkillModifier.EXECUTE, 100, 0, 1), &"axt", 3))
	list.append(_tech(_auf(_effect(&"tech_kampfrausch", Loc.pick("Kampfrausch", "Battle frenzy"), Enums.Status.ATK_UP, 100, 3, 25, 5, 1), A), &"axt", 6))
	list.append(_tech(_effect(&"tech_ruestungsspalter", Loc.pick("Rüstungsspalter", "Armor splitter"), Enums.Status.ARMOR_BREAK, 100, 2, 40, 5, 1), &"axt", 10))
	list.append(_tech(_effect(&"eff_lifesteal", Loc.pick("Blutrausch", "Bloodlust"), Enums.Status.LIFESTEAL, 100, 0, 30, 5, 1), &"axt", 15))
	list.append(_tech(_mod(&"tech_unermuedlich", Loc.pick("Unermüdlich", "Tireless"), Enums.SkillModifier.KEIN_ERSCHOEPFT, 0, 0, 1), &"axt", 20))
	list.append(_tech(_effect(&"tech_klaffende_wunde", Loc.pick("Klaffende Wunde", "Gaping wound"), Enums.Status.BLEED, 100, -1, 40, 5, 1), &"axt", 26))
	list.append(_tech(_auf(_effect(&"tech_kriegsschrei", Loc.pick("Kriegsschrei", "War shout"), Enums.Status.WEAKEN, 100, 2, 20, 6, 1), G), &"axt", 33))
	list.append(_tech(_mod(&"tech_berserker", Loc.pick("Berserkerwut", "Berserk rage"), Enums.SkillModifier.RAGE, 150, 0, 1), &"axt", 41))
	list.append(_tech(_mod(&"tech_ax_overload2", Loc.pick("Raserei", "Frenzy"), Enums.SkillModifier.OVERLOAD, 120, 0, 1), &"axt", 62))

	# ---- Knüppel/Hammer (Brecher: Kontrolle) ----
	list.append(_tech(_effect(&"eff_stun", Loc.pick("Betäuben", "Stun"), Enums.Status.STUN, 60, 1, 0, 6, 1), &"stumpf", 3))
	list.append(_tech(_effect(&"tech_ruestungsriss", Loc.pick("Rüstungsriss", "Armor break"), Enums.Status.ARMOR_BREAK, 100, 2, 40, 5, 1), &"stumpf", 6))
	list.append(_tech(_effect(&"tech_erschuettern", Loc.pick("Erschüttern", "Rattle"), Enums.Status.SLOW, 100, 2, 30, 3, 1), &"stumpf", 10))
	list.append(_tech(_effect(&"tech_benommen", Loc.pick("Benommenheit", "Daze"), Enums.Status.WEAKEN, 100, 2, 25, 4, 1), &"stumpf", 15))
	list.append(_tech(_mod(&"tech_zermalmen", Loc.pick("Zermalmen", "Crush"), Enums.SkillModifier.ZERMALMEN, 80, 0, 1), &"stumpf", 20))
	list.append(_tech(_effect(&"tech_st_stun2", Loc.pick("Betäuben II", "Stun II"), Enums.Status.STUN, 75, 1, 0, 7, 1), &"stumpf", 26))
	list.append(_tech(_auf(_effect(&"tech_eisenhaut", Loc.pick("Eisenhaut", "Iron skin"), Enums.Status.DEF_UP, 100, 3, 6, 4, 1), A), &"stumpf", 33))
	list.append(_tech(_auf(_effect(&"tech_erdstoss", Loc.pick("Erdstoß", "Ground slam"), Enums.Status.STUN, 30, 1, 0, 8, 1), G), &"stumpf", 41))
	list.append(_tech(_effect(&"tech_st_riss2", Loc.pick("Rüstungsriss II", "Armor break II"), Enums.Status.ARMOR_BREAK, 100, 3, 60, 7, 1), &"stumpf", 62))

	# ---- Bogen (Jäger: Markieren, Schwachstellen) ----
	list.append(_tech(_effect(&"tech_markieren", Loc.pick("Markieren", "Mark"), Enums.Status.MARKED, 100, 2, 25, 4, 1), &"bogen", 3))
	list.append(_tech(_mod(&"tech_zielen", Loc.pick("Zielen", "Aim"), Enums.SkillModifier.SCHWACHSTELLE, 20, 0, 1), &"bogen", 6))
	list.append(_tech(_effect(&"tech_laehmpfeil", Loc.pick("Lähmpfeil", "Crippling arrow"), Enums.Status.SLOW, 100, 2, 30, 4, 1), &"bogen", 10))
	list.append(_tech(_effect(&"tech_giftpfeil", Loc.pick("Giftpfeil", "Poison arrow"), Enums.Status.POISON_DOT, 100, -1, 25, 3, 1), &"bogen", 15))
	list.append(_tech(_auf(_effect(&"tech_rueckzug", Loc.pick("Rückzug", "Fall back"), Enums.Status.DEF_UP, 100, 2, 5, 3, 1), A), &"bogen", 20))
	list.append(_tech(_mod(&"tech_adlerauge", Loc.pick("Adlerauge", "Eagle eye"), Enums.SkillModifier.KRIT_BONUS, 25, 0, 1), &"bogen", 26))
	list.append(_tech(_auf(_effect(&"tech_sperrfeuer", Loc.pick("Sperrfeuer", "Covering fire"), Enums.Status.FIRST_STRIKE, 100, 1, 0, 3, 1), A), &"bogen", 33))
	list.append(_tech(_mod(&"tech_scharfschuetze", Loc.pick("Scharfschütze", "Sharpshooter"), Enums.SkillModifier.SCHWACHSTELLE, 45, 0, 1), &"bogen", 41))
	list.append(_tech(_mod(&"tech_volltreffer", Loc.pick("Meisterschuss", "Master shot"), Enums.SkillModifier.VOLLTREFFER_MULT, 600, 0, 1), &"bogen", 62))

	# ---- Armbrust (Belagerer: Durchschlag) ----
	list.append(_tech(_effect(&"tech_ar_slow2", Loc.pick("Netzbolzen", "Net bolt"), Enums.Status.SLOW, 100, 2, 45, 6, 1), &"armbrust", 3))
	list.append(_tech(_mod(&"tech_ar_pierce2", Loc.pick("Panzerbrecher", "Armor breaker"), Enums.SkillModifier.PIERCE_ARMOR, 80, 0, 1), &"armbrust", 6))
	list.append(_tech(_effect(&"tech_widerhaken", Loc.pick("Widerhaken", "Barbed bolt"), Enums.Status.BLEED, 100, -1, 25, 4, 1), &"armbrust", 10))
	list.append(_tech(_auf(_effect(&"tech_kniend", Loc.pick("Kniender Schuss", "Kneeling shot"), Enums.Status.DEF_UP, 100, 2, 6, 3, 1), A), &"armbrust", 15))
	list.append(_tech(_effect(&"tech_brandbolzen", Loc.pick("Brandbolzen", "Fire bolt"), Enums.Status.BURN, 100, -1, 30, 4, 1), &"armbrust", 20))
	list.append(_tech(_mod(&"tech_schwerer_bolzen", Loc.pick("Schwerer Bolzen", "Heavy bolt"), Enums.SkillModifier.KRIT_MULT, 220, 0, 1), &"armbrust", 26))
	list.append(_tech(_effect(&"tech_markierbolzen", Loc.pick("Markierbolzen", "Marking bolt"), Enums.Status.MARKED, 100, 2, 30, 4, 1), &"armbrust", 33))
	list.append(_tech(_mod(&"tech_ar_pierce3", Loc.pick("Bolzenmeister", "Bolt master"), Enums.SkillModifier.PIERCE_ARMOR, 100, 0, 1), &"armbrust", 62))

	# ---- Offensivstab (Schadensmagie) ----
	list.append(_tech(_mod(&"mod_cost", Loc.pick("Effizienz", "Efficiency"), Enums.SkillModifier.COST_REDUCTION, 25, 0, 1), &"offensivstab", 3))
	list.append(_tech(_auf(_effect(&"tech_arkanschild", Loc.pick("Arkanschild", "Arcane shield"), Enums.Status.SHIELD, 100, 3, 20, 5, 1), A), &"offensivstab", 6))
	list.append(_tech(_effect(&"tech_arkane_fessel", Loc.pick("Arkane Fessel", "Arcane bind"), Enums.Status.SLOW, 100, 2, 30, 4, 1), &"offensivstab", 10))
	list.append(_tech(_mod(&"tech_konzentration", Loc.pick("Fokussierung", "Concentration"), Enums.SkillModifier.KRIT_BONUS, 20, 0, 1), &"offensivstab", 15))
	list.append(_tech(_mod(&"tech_elementfokus", Loc.pick("Element-Fokus", "Element focus"), Enums.SkillModifier.ELEMENT_FOKUS, 0, 0, 1), &"offensivstab", 20))
	list.append(_tech(_mod(&"tech_arkanflut", Loc.pick("Arkane Flut", "Arcane surge"), Enums.SkillModifier.OVERLOAD, 60, 0, 1), &"offensivstab", 33))
	list.append(_tech(_mod(&"tech_echo", "Echo", Enums.SkillModifier.ECHO, 50, 0, 1), &"offensivstab", 50))
	list.append(_tech(_mod(&"tech_os_meister", Loc.pick("Arkane Entladung", "Arcane discharge"), Enums.SkillModifier.KRIT_MULT, 220, 0, 1), &"offensivstab", 76))

	# ---- Heiligstab (Heilmagie) ----
	list.append(_tech(_mod(&"tech_ueberheilung", Loc.pick("Überheilung", "Overheal"), Enums.SkillModifier.OVERHEAL_SHIELD, 100, 0, 1), &"heiligstab", 3))
	list.append(_tech(_effect(&"eff_mana_regen", Loc.pick("Mana-Fluss", "Mana flow"), Enums.Status.MANA_REGEN, 100, 3, 6, 5, 1), &"heiligstab", 6))
	list.append(_tech(_auf(_effect(&"tech_schutzgebet", Loc.pick("Schutzgebet", "Prayer of shielding"), Enums.Status.SHIELD, 100, 3, 15, 7, 1), P), &"heiligstab", 10))
	list.append(_tech(_auf(_effect(&"tech_vergebung", Loc.pick("Vergebung", "Absolution"), Enums.Status.CLEANSE, 100, 0, 0, 6, 1), P), &"heiligstab", 15))
	list.append(_tech(_auf(_effect(&"tech_segensaura", Loc.pick("Segensaura", "Aura of blessing"), Enums.Status.REGEN, 100, 3, 6, 6, 1), P), &"heiligstab", 20))
	list.append(_tech(_auf(_effect(&"tech_heiliger_eifer", Loc.pick("Heiliger Eifer", "Holy zeal"), Enums.Status.ATK_UP, 100, 3, 15, 6, 1), P), &"heiligstab", 33))
	list.append(_tech(_effect(&"eff_revive", Loc.pick("Wiederbeleben", "Revive"), Enums.Status.REVIVE, 100, 0, 40, 12, 1), &"heiligstab", 50))

	# ---- Schild (Bollwerk: Schutz & Dornen) ----
	list.append(_tech(_auf(_effect(&"eff_protect", Loc.pick("Schutzwall", "Bulwark"), Enums.Status.PROTECT, 100, 2, 0, 6, 1), A), &"schild", 3))
	list.append(_tech(_auf(_effect(&"tech_vergeltung", Loc.pick("Vergeltung", "Retribution"), Enums.Status.THORNS, 100, 2, 30, 5, 1), A), &"schild", 6))
	list.append(_tech(_effect(&"tech_sh_stun2", Loc.pick("Schildstoß", "Shield bash"), Enums.Status.STUN, 60, 1, 0, 5, 1), &"schild", 10))
	list.append(_tech(_auf(_effect(&"tech_wappnen", Loc.pick("Bastion", "Bastion"), Enums.Status.DEF_UP, 100, 3, 8, 4, 1), A), &"schild", 15))
	list.append(_tech(_auf(_effect(&"tech_standhaft", Loc.pick("Standhaft", "Steadfast"), Enums.Status.SHIELD, 100, 3, 25, 5, 1), A), &"schild", 20))
	list.append(_tech(_auf(_effect(&"tech_gegenwehr", Loc.pick("Gegenwehr", "Pushback"), Enums.Status.COUNTER, 100, 2, 80, 5, 1), A), &"schild", 33))
	list.append(_tech(_auf(_effect(&"tech_sh_shield2", Loc.pick("Schutzkuppel", "Shield dome"), Enums.Status.SHIELD, 100, 4, 40, 10, 1), P), &"schild", 50))

	for block in list:
		assert(not _blocks.has(block.id), "Doppelte Baustein-ID: %s" % block.id)
		_blocks[block.id] = block
		_regeln_anwenden(block)


# --- Bauregeln je Klotz -------------------------------------------------------
# [Gruppe, Kern?, Kostenfaktor, Schadensfaktor, stapelbar?] — fehlende Felder
# = Standard (false, 1.0, 1.0, false).
# Gruppe: pro Skill nur EIN Klotz dieser Gruppe (Varianten wie Präzision /
# Schwertkunst / Adlerauge stapeln nicht). Kern: der prägende Spitzen-Klotz
# eines Baums — höchstens einer pro Skill. Kostenfaktor multipliziert die
# MP des ganzen Skills, Schadensfaktor seinen Schaden (der „Preis“ oder
# „Lohn“ einer Eigenschaft).
const REGELN := {
	# Universell
	&"mod_treffer": [&"", false, 1.2, 1.0, true],
	&"mod_praezision": [&"praezision", false, 1.1, 0.9],
	&"mod_ziel_zufall": [&"form", false, 1.0, 1.1],
	&"mod_ziel_wechsel": [&"form", false, 1.1],
	&"mod_wucht": [&"zeit", false, 1.0, 1.5],
	&"mod_flinkheit": [&"zeit", false, 1.0, 0.75],
	&"mod_aufladen": [&"zeit", false, 1.0, 2.0],
	&"mod_sparsam": [&"kosten", false, 1.0, 0.75],
	&"mod_blutpreis": [&"kosten", false, 1.0],
	&"mod_ausnutzen": [&"ausnutzen", false, 1.1],
	&"mod_execute": [&"hinrichtung", false, 1.1],
	&"mod_pierce": [&"durchdringung", false, 1.15, 0.85],
	&"mod_overload": [&"ueberladung", false, 1.5],
	&"mod_entzuenden": [&"", false, 1.1],
	&"mod_rache": [&"rache", false, 1.1],
	&"mod_alles_oder_nichts": [&"kritwucht", false, 1.2],
	&"mod_ueberschlag": [&"", false, 1.25],
	&"mod_nachsetzen": [&"", false, 1.1],
	&"mod_schwachstelle": [&"schwachstelle", false, 1.1, 0.85],
	&"eff_weaken": [&"schwaechen"],
	&"eff_slow": [&"verlangsamen"],
	&"eff_shield": [&"schild"],
	&"eff_regen": [&"regen"],
	&"eff_atk_up": [&"staerken"],
	&"eff_def_up": [&"wappnen"],
	&"eff_cleanse": [&"reinigen"],
	&"form_summon": [&"", true],
	# Schwert
	&"tech_konter": [&"konter"],
	&"tech_duellstoss": [&"duell", false, 1.1],
	&"tech_entwaffnen": [&"schwaechen"],
	&"tech_kampfruf": [&"staerken"],
	&"tech_wachsam": [&"erstschlag"],
	&"tech_schwertkunst": [&"praezision", false, 1.1],
	&"tech_riposte": [&"konter"],
	&"tech_schutzhieb": [&"schild"],
	&"tech_heldenmut": [&"regen"],
	&"tech_duellmeister": [&"duell", false, 1.2],
	&"tech_klingentanz": [&"", true, 1.3],
	&"tech_sw_meister": [&"kritwucht", true, 1.2],
	# Dolch
	&"tech_giftklinge": [&"gift"],
	&"tech_erstschlag": [&"erstschlag"],
	&"tech_blutung": [&"blutung"],
	&"tech_meucheln": [&"kritwucht", false, 1.2],
	&"tech_laehmgift": [&"verlangsamen"],
	&"tech_schwachpunkt": [&"schwachstelle", false, 1.1],
	&"tech_hinterhalt": [&"ausnutzen", false, 1.15],
	&"tech_schattenmantel": [&"schild"],
	&"tech_do_execute2": [&"hinrichtung", true, 1.25],
	&"tech_rauchbombe": [&"schwaechen"],
	&"tech_elementklinge": [&"fokus", true, 1.3],
	# Axt
	&"tech_kopfspalter": [&"hinrichtung", false, 1.15],
	&"tech_kampfrausch": [&"staerken"],
	&"tech_ruestungsspalter": [&"ruestungsriss"],
	&"tech_unermuedlich": [&"", false, 1.1],
	&"tech_klaffende_wunde": [&"blutung"],
	&"tech_kriegsschrei": [&"schwaechen"],
	&"tech_berserker": [&"rache", false, 1.2],
	&"tech_ax_overload2": [&"ueberladung", true, 2.0],
	# Knüppel/Hammer
	&"eff_stun": [&"betaeuben"],
	&"tech_ruestungsriss": [&"ruestungsriss"],
	&"tech_erschuettern": [&"verlangsamen"],
	&"tech_benommen": [&"schwaechen"],
	&"tech_zermalmen": [&"", false, 1.1],
	&"tech_st_stun2": [&"betaeuben"],
	&"tech_eisenhaut": [&"wappnen"],
	&"tech_erdstoss": [&"betaeuben"],
	&"tech_st_riss2": [&"ruestungsriss", true],
	# Bogen
	&"tech_markieren": [&"markieren"],
	&"tech_zielen": [&"schwachstelle", false, 1.05],
	&"tech_laehmpfeil": [&"verlangsamen"],
	&"tech_giftpfeil": [&"gift"],
	&"tech_rueckzug": [&"wappnen"],
	&"tech_adlerauge": [&"praezision", false, 1.1],
	&"tech_sperrfeuer": [&"erstschlag"],
	&"tech_scharfschuetze": [&"schwachstelle", false, 1.15],
	&"tech_volltreffer": [&"", true, 1.3],
	# Armbrust
	&"tech_ar_slow2": [&"verlangsamen"],
	&"tech_ar_pierce2": [&"durchdringung", false, 1.25],
	&"tech_widerhaken": [&"blutung"],
	&"tech_kniend": [&"wappnen"],
	&"tech_brandbolzen": [&"brand"],
	&"tech_schwerer_bolzen": [&"kritwucht", false, 1.2],
	&"tech_markierbolzen": [&"markieren"],
	&"tech_ar_pierce3": [&"durchdringung", true, 1.35],
	# Offensivstab
	&"mod_cost": [&"kosten"],  # Effizienz: −25 % über die Magnitude
	&"tech_arkanschild": [&"schild"],
	&"tech_arkane_fessel": [&"verlangsamen"],
	&"tech_konzentration": [&"praezision", false, 1.1],
	&"tech_elementfokus": [&"fokus", false, 1.3],
	&"tech_arkanflut": [&"ueberladung", false, 1.6],
	&"tech_echo": [&"", true, 1.35],
	&"tech_os_meister": [&"kritwucht", true, 1.2],
	# Heiligstab
	&"tech_ueberheilung": [&"", false, 1.15],
	&"tech_schutzgebet": [&"schild"],
	&"tech_vergebung": [&"reinigen"],
	&"tech_segensaura": [&"regen"],
	&"tech_heiliger_eifer": [&"staerken"],
	&"eff_revive": [&"", true],
	# Schild
	&"tech_vergeltung": [&"dornen"],
	&"tech_sh_stun2": [&"betaeuben"],
	&"tech_wappnen": [&"wappnen"],
	&"tech_standhaft": [&"schild"],
	&"tech_gegenwehr": [&"konter"],
	&"tech_sh_shield2": [&"schild", true],
}

## Anzeigenamen der Variantengruppen (Skill.gruppen_name).
const GRUPPEN := {
	&"praezision": ["Krit-Chance", "crit chance"], &"kritwucht": ["Krit-Wucht", "crit power"],
	&"schwachstelle": ["Schwachstelle", "weak spot"], &"zeit": ["Zeitpunkt", "timing"],
	&"kosten": ["Kosten", "cost"], &"hinrichtung": ["Hinrichtung", "execution"],
	&"durchdringung": ["Durchschlag", "armor pierce"], &"ueberladung": ["Überladung", "overload"],
	&"rache": ["Rache", "vengeance"], &"ausnutzen": ["Ausnutzen", "exploit"],
	&"duell": ["Duell", "duel"], &"konter": ["Konter", "counter"],
	&"fokus": ["Element-Fokus", "element focus"], &"betaeuben": ["Betäuben", "stun"],
	&"ruestungsriss": ["Rüstungsriss", "armor break"], &"verlangsamen": ["Verlangsamen", "slow"],
	&"schwaechen": ["Schwächen", "weaken"], &"staerken": ["Stärken", "strengthen"],
	&"wappnen": ["Wappnen", "brace"], &"schild": ["Schild", "shield"],
	&"regen": ["Regeneration", "regeneration"], &"reinigen": ["Reinigen", "cleanse"],
	&"erstschlag": ["Erstschlag", "first strike"], &"markieren": ["Markieren", "mark"],
	&"gift": ["Gift", "poison"], &"blutung": ["Blutung", "bleed"], &"brand": ["Brand", "burn"],
	&"dornen": ["Dornen", "thorns"],
}

## Alte Klotz-IDs (vor Skillbau 3.0) → Ersatz. Gespeicherte Skills werden beim
## Laden umgeschrieben (Skill.from_dict); leere Liste = Klotz entfällt.
const ALIAS := {
	&"mod_power": [],
	&"tech_sw_power2": [], &"tech_ax_power2": [], &"tech_os_power2": [],
	&"mod_vs_undead": [],
	&"mod_multi": [&"mod_treffer"],
	&"tech_sw_multi2": [&"mod_treffer", &"mod_treffer"],
	&"tech_bo_multi2": [&"mod_treffer", &"mod_treffer"],
	&"tech_bo_multi3": [&"mod_treffer", &"mod_treffer", &"mod_treffer"],
	&"mod_chain": [&"mod_ziel_wechsel"],
	&"mod_spread": [&"form_aoe"],
}


static func _regeln_anwenden(block: SkillBlock) -> void:
	if block is ModifierBlock:
		block.mp_cost = 0  # Verstärker wirken nur über ihren Kostenfaktor
	if not REGELN.has(block.id):
		return
	var regel: Array = REGELN[block.id]
	block.gruppe = regel[0]
	if regel.size() > 1:
		block.kern = regel[1]
	if regel.size() > 2:
		block.kosten_faktor = regel[2]
	if regel.size() > 3:
		block.schaden_faktor = regel[3]
	if regel.size() > 4:
		block.stapelbar = regel[4]


## Ersetzt veraltete IDs (ALIAS) — unbekannte IDs bleiben, damit der
## Aufrufer sie wie bisher überspringen kann.
static func migriere_ids(ids: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for id in ids:
		var sid := StringName(id)
		if ALIAS.has(sid):
			for neu in ALIAS[sid]:
				result.append(neu)
		else:
			result.append(sid)
	return result


static func _lvl(block: SkillBlock, level: int) -> SkillBlock:
	block.unlock_kind = Enums.UnlockKind.LEVEL
	block.unlock_level = level
	return block


## Effekt-Ziel setzen (Anwender, Party, alle Gegner) statt des Trefferziels.
static func _auf(block: EffectBlock, ziel: EffectBlock.Ziel) -> EffectBlock:
	block.ziel = ziel
	return block


# --- Baustein-Fabriken -------------------------------------------------------

static func _source(id: StringName, name: String, source: Enums.SkillSource,
		per_point: float, power_mult: float, mp_cost: int, unlock_level: int) -> SourceBlock:
	var block := SourceBlock.new()
	block.id = id
	block.display_name = name
	block.source = source
	block.scaling_per_point = per_point
	block.power_multiplier = power_mult
	block.mp_cost = mp_cost
	block.unlock_level = unlock_level
	return block


static func _element(id: StringName, name: String, element: Enums.Element,
		dot_turns: int, status_scale: float, mp_cost: int, unlock_level: int) -> ElementBlock:
	var block := ElementBlock.new()
	block.id = id
	block.display_name = name
	block.element = element
	block.dot_turns = dot_turns
	block.status_scale = status_scale
	block.mp_cost = mp_cost
	block.unlock_level = unlock_level
	return block


static func _form(id: StringName, name: String, form: Enums.SkillForm,
		cost_mult: float, power_mult: float, unlock_level: int) -> FormBlock:
	var block := FormBlock.new()
	block.id = id
	block.display_name = name
	block.form = form
	block.cost_multiplier = cost_mult
	block.power_multiplier = power_mult
	block.unlock_level = unlock_level
	return block


static func _effect(id: StringName, name: String, status: Enums.Status, chance: int,
		turns: int, potency: int, mp_cost: int, unlock_level: int) -> EffectBlock:
	var block := EffectBlock.new()
	block.id = id
	block.display_name = name
	block.status = status
	block.chance_percent = chance
	block.duration_turns = turns
	block.potency = potency
	block.mp_cost = mp_cost
	block.unlock_level = unlock_level
	return block


static func _mod(id: StringName, name: String, kind: Enums.SkillModifier,
		magnitude: int, mp_cost: int, unlock_level: int) -> ModifierBlock:
	var block := ModifierBlock.new()
	block.id = id
	block.display_name = name
	block.modifier = kind
	block.magnitude = magnitude
	block.mp_cost = mp_cost
	block.unlock_level = unlock_level
	return block


static func _research(block: SkillBlock, gold_cost: int) -> void:
	block.unlock_kind = Enums.UnlockKind.RESEARCH
	block.research_cost_gold = gold_cost



## Waffentechnik: an EINE Gattung gebunden, freigeschaltet über investierte
## Trainings-Punkte (Schwelle `points`) in ebendieser Gattung.
static func _tech(block: SkillBlock, family: StringName, points: int) -> SkillBlock:
	block.weapon_families = [family]
	block.unlock_kind = Enums.UnlockKind.TRAINING
	block.tree_family = family
	block.tree_points = points
	return block


# --- Passiv-Boni der Trainings-Bäume ---------------------------------------
# Greifen automatisch, sobald die Schwelle erreicht ist UND die Gattung
# geführt wird (Schild über die Nebenhand). ALLE Boni sind PROZENTE:
# dmg (+% Waffenschaden), spell (+% Zauberkraft), crit (+% Kritchance),
# armor (+% Rüstung), mp (−% MP-Kosten).

const _PHYS_PASSIVES: Array = [
	{"points": 7, "kind": &"dmg", "magnitude": 10},
	{"points": 14, "kind": &"crit", "magnitude": 5},
	{"points": 22, "kind": &"dmg", "magnitude": 10},
	{"points": 35, "kind": &"crit", "magnitude": 5},
	{"points": 50, "kind": &"dmg", "magnitude": 15},
	{"points": 75, "kind": &"dmg", "magnitude": 15},
	{"points": 92, "kind": &"crit", "magnitude": 10},
]
const _STAB_PASSIVES: Array = [
	{"points": 7, "kind": &"spell", "magnitude": 10},
	{"points": 14, "kind": &"mp", "magnitude": 5},
	{"points": 22, "kind": &"spell", "magnitude": 10},
	{"points": 35, "kind": &"mp", "magnitude": 5},
	{"points": 50, "kind": &"spell", "magnitude": 15},
	{"points": 75, "kind": &"spell", "magnitude": 15},
	{"points": 92, "kind": &"mp", "magnitude": 10},
]
const _SCHILD_PASSIVES: Array = [
	{"points": 7, "kind": &"armor", "magnitude": 5},
	{"points": 14, "kind": &"armor", "magnitude": 5},
	{"points": 22, "kind": &"armor", "magnitude": 5},
	{"points": 35, "kind": &"armor", "magnitude": 5},
	{"points": 50, "kind": &"armor", "magnitude": 10},
	{"points": 75, "kind": &"armor", "magnitude": 10},
	{"points": 92, "kind": &"armor", "magnitude": 10},
]
const TREE_PASSIVES := {
	&"schwert": _PHYS_PASSIVES, &"dolch": _PHYS_PASSIVES,
	&"axt": _PHYS_PASSIVES, &"stumpf": _PHYS_PASSIVES,
	&"bogen": _PHYS_PASSIVES, &"armbrust": _PHYS_PASSIVES,
	&"offensivstab": _STAB_PASSIVES, &"heiligstab": _STAB_PASSIVES,
	&"schild": _SCHILD_PASSIVES,
}


static func passives_for(family: StringName) -> Array:
	return TREE_PASSIVES.get(family, [])


static func passive_label(passive: Dictionary) -> String:
	match passive["kind"]:
		&"dmg":
			return Loc.pick("+%d%% Waffenschaden", "+%d%% weapon damage") % passive["magnitude"]
		&"spell":
			return Loc.pick("+%d%% Zauberkraft", "+%d%% spell power") % passive["magnitude"]
		&"crit":
			return Loc.pick("+%d%% Kritchance", "+%d%% crit chance") % passive["magnitude"]
		&"armor":
			return Loc.pick("+%d%% Rüstung", "+%d%% armor") % passive["magnitude"]
		&"mp":
			return Loc.pick("−%d%% MP-Kosten", "−%d%% MP cost") % passive["magnitude"]
	return ""


## Universelle Klötze, die beim Aufstieg von Level `von` auf `bis` neu
## freigeschaltet werden (für die Level-up-Anzeige).
static func neu_ab_level(von: int, bis: int) -> Array[SkillBlock]:
	_ensure_built()
	var result: Array[SkillBlock] = []
	for id in _blocks:
		var block: SkillBlock = _blocks[id]
		if block.unlock_kind == Enums.UnlockKind.LEVEL \
				and block.unlock_level > von and block.unlock_level <= bis:
			result.append(block)
	result.sort_custom(func(a: SkillBlock, b: SkillBlock) -> bool:
		return a.unlock_level < b.unlock_level)
	return result


## „Neue Klötze: Präzision, Eis · +1 Sockel“ — leer, wenn nichts Neues kam.
static func aufstieg_text(von: int, bis: int, rebirths := 0) -> String:
	var teile: Array[String] = []
	var namen: Array[String] = []
	for block in neu_ab_level(von, bis):
		namen.append(block.display_name)
	if not namen.is_empty():
		teile.append(Loc.pick("Neue Klötze: %s", "New blocks: %s") % ", ".join(namen))
	var sockel := CharacterDef.block_sockets_for(bis, rebirths) - CharacterDef.block_sockets_for(von, rebirths)
	if sockel > 0:
		teile.append(Loc.pick("+%d Sockel pro Skill", "+%d socket per skill") % sockel)
	return "  ·  ".join(teile)


## Alle Technik-Bausteine eines Trainings-Baums, nach Schwelle sortiert.
static func tree_blocks(family: StringName) -> Array[SkillBlock]:
	_ensure_built()
	var result: Array[SkillBlock] = []
	for id in _blocks:
		var block: SkillBlock = _blocks[id]
		if block.unlock_kind == Enums.UnlockKind.TRAINING and block.tree_family == family:
			result.append(block)
	result.sort_custom(func(a: SkillBlock, b: SkillBlock) -> bool:
		return a.tree_points < b.tree_points)
	return result


## Anzeigenamen der Waffengattungen (ItemBase.family) für Technik-Hinweise.
const FAMILY_NAMES := {
	&"schwert": ["Schwert", "Sword"], &"dolch": ["Dolch", "Dagger"],
	&"axt": ["Axt", "Axe"], &"stumpf": ["Knüppel/Hammer", "Club/hammer"],
	&"bogen": ["Bogen", "Bow"], &"armbrust": ["Armbrust", "Crossbow"],
	&"offensivstab": ["Offensivstab", "Offense staff"],
	&"heiligstab": ["Heiligstab", "Holy staff"],
}


static func family_label(family: StringName) -> String:
	if FAMILY_NAMES.has(family):
		return Loc.pick(FAMILY_NAMES[family][0], FAMILY_NAMES[family][1])
	return String(family)


## "Nur mit: Schwert/Dolch" — für Werkstatt-Beschreibungen und Kampf-Tooltips.
static func families_label(families: Array[StringName]) -> String:
	var parts: Array[String] = []
	for family in families:
		parts.append(family_label(family))
	return "/".join(parts)
