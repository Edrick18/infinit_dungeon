extends SceneTree
## Headless-Selbsttest für Loot-Generierung und Ausrüstungs-Wirkung:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/loot_selftest.gd

var failures := 0


func _init() -> void:
	_test_item_generation()
	_test_tier_gating()
	_test_equipment_effects()
	_test_battle_loot()
	_test_element_affixes()
	_test_skill_affixes()
	_test_affix_rolls_and_rarities()
	_test_boss_beute()
	if failures == 0:
		print("SELFTEST OK — alle Loot-Tests bestanden")
		quit(0)
	else:
		print("SELFTEST FEHLGESCHLAGEN — %d Fehler" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		printerr("  FEHLER: " + label)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_item_generation() -> void:
	print("Item-Generierung:")
	var a := LootGenerator.roll_item(3, _rng(42))
	var b := LootGenerator.roll_item(3, _rng(42))
	_check(a.get_display_name() == b.get_display_name() and a.rarity == b.rarity,
		"gleicher RNG-Seed » gleiches Item")

	var counts_ok := true
	var name_ok := true
	var rarities := {}
	for i in 300:
		var item := LootGenerator.roll_item(3, _rng(i))
		rarities[item.rarity] = true
		if item.affixes.size() != LootGenerator.AFFIX_COUNT[item.rarity]:
			counts_ok = false
		if item.base.display_name.to_lower() not in item.get_display_name().to_lower():
			name_ok = false
	_check(counts_ok, "Affix-Anzahl passt immer zur Rarity (0/1/2/3/4)")
	_check(name_ok, "Basisname steckt immer im Item-Namen")
	_check(rarities.size() >= 4, "über 300 Rolls kommen ≥4 Raritäten vor (%d)" % rarities.size())


func _test_tier_gating() -> void:
	print("Tier-Begrenzung:")
	var ok := true
	for i in 200:
		var item := LootGenerator.roll_item(1, _rng(i))
		if item.base.min_tier > 1:
			ok = false
		for affix in item.affixes:
			if affix.tier > 1:
				ok = false
	_check(ok, "Tier-1-Drops enthalten keine höherstufigen Basen/Affixe")
	_check(ItemLibrary.bases_for_tier(4).size() > ItemLibrary.bases_for_tier(1).size(),
		"höhere Stufen schalten mehr Basis-Items frei")


func _test_equipment_effects() -> void:
	print("Ausrüstung wirkt im Kampf:")
	var stats := StatBlock.new()
	stats.strength = 5
	stats.vitality = 5
	var hero := Combatant.create("Held", stats, true)

	var sword := ItemInstance.new()
	sword.base = ItemLibrary.bases_for_tier(1)[0]  # Schwert, +8 Schaden
	var vit_affix: Affix = null
	for affix in ItemLibrary.affixes_for_tier(1, false):
		if affix.id == &"vitalitaet":
			vit_affix = affix
	sword.affixes = [vit_affix]

	var hp_before := hero.max_hp
	var replaced := hero.equip(sword)
	_check(replaced.is_empty(), "Slot war leer » nichts ersetzt")
	_check(hero.weapon_damage() == 8, "Waffenschaden +8 vom Schwert")
	_check(hero.max_hp == hp_before + 3 * Combatant.HP_PER_VIT,
		"'der Vitalität' erhöht Max-HP (+3 VIT)")

	# Basisangriff nutzt Waffe: 5 Basis + 5 STR + 8 Waffe = 18
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = 1
	var dummy := Combatant.create("Ziel", StatBlock.new(), false)
	battle.start([hero], [dummy])
	var target_hp := dummy.hp
	battle.basic_attack(hero, dummy)
	_check(target_hp - dummy.hp == 18, "Basisangriff: 5 + 5 STR + 8 Waffe = 18")

	# Ringe: zweiter Ring wandert in Slot 2.
	var ring_base: ItemBase = null
	for base in ItemLibrary.bases_for_tier(1):
		if base.slot == Enums.EquipSlot.RING_1:
			ring_base = base
	var ring1 := ItemInstance.new()
	ring1.base = ring_base
	var ring2 := ItemInstance.new()
	ring2.base = ring_base
	hero.equip(ring1)
	var replaced_ring := hero.equip(ring2)
	_check(replaced_ring.is_empty() and hero.equipment.has(Enums.EquipSlot.RING_2),
		"zweiter Ring belegt Ring-Slot 2 statt zu ersetzen")

	var removed := hero.unequip(Enums.EquipSlot.WEAPON)
	_check(removed == sword and hero.weapon_damage() == 0, "Ablegen entfernt Waffenbonus")


func _test_battle_loot() -> void:
	print("Kampf-Beute:")
	var stats := StatBlock.new()
	var normal := Combatant.create("Gegner", stats, false)
	var elite := Combatant.create("Elite", stats, false)
	elite.loot_mult = 1.5

	var loot := LootGenerator.roll_battle_loot([normal, elite], 2, false, _rng(1))
	_check(loot["gold"] > 0, "Kills geben Gold")

	var boss_loot := LootGenerator.roll_battle_loot([normal], 2, true, _rng(1))
	_check(boss_loot["items"].size() >= LootGenerator.BOSS_ITEM_COUNT,
		"Boss droppt garantiert %d+ Items" % LootGenerator.BOSS_ITEM_COUNT)
	_check(boss_loot["materials"].size() >= 2, "Boss droppt garantiert Materialien")

	var material_found := false
	var potion_free := true
	for i in 40:
		var roll := LootGenerator.roll_battle_loot([normal, elite], 1, false, _rng(i))
		if not roll["materials"].is_empty():
			material_found = true
		if roll.has("consumables"):
			potion_free = false
	_check(material_found, "Materialien droppen aus normalen Kämpfen")
	_check(potion_free, "Tränke droppen NICHT mehr von Gegnern")

	var item := LootGenerator.roll_item(2, _rng(5))
	_check(LootGenerator.sell_price(item) > 0, "Verkaufspreis ist positiv")


func _item_with_affix(base_id: StringName, affix_id: StringName,
		item_level := 1) -> ItemInstance:
	var item := ItemLibrary.make_item(base_id, item_level)
	item.affixes = [ItemLibrary.get_affix(affix_id)] as Array[Affix]
	return item


func _test_element_affixes() -> void:
	print("Element-Affixe (Rider + Resistenzen):")
	# Slot-Bindung: Rider landen nie auf Rüstung, Resistenzen nie auf Waffen.
	var slots_ok := true
	for i in 400:
		var item := LootGenerator.roll_item(10, _rng(i))
		for affix in item.affixes:
			if affix.element_damage > 0 and item.base.slot != Enums.EquipSlot.WEAPON:
				slots_ok = false
			if affix.element_resist > 0 and item.base.slot == Enums.EquipSlot.WEAPON:
				slots_ok = false
	_check(slots_ok, "Slot-Bindung: Rider nur auf Waffen, Resistenzen nie auf Waffen")

	# Rider: Waffennutzung trägt Elementschaden mit voller Signatur (Brand-Stacks).
	var stats := StatBlock.new()
	stats.strength = 5
	var hero := Combatant.create("Held", stats, true)
	hero.equip(_item_with_affix(&"schwert", &"lodernd"))
	_check(hero.element_riders().get(Enums.Element.FIRE, 0) == 4,
		"'Loderndes' Schwert: +4 Feuer-Rider")
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = 1
	var dummy := Combatant.create("Ziel", StatBlock.new(), false)
	dummy.max_hp = 500
	dummy.hp = 500
	battle.start([hero], [dummy])
	var weapon_skill := Skill.new()
	weapon_skill.blocks.append(BlockLibrary.get_block(&"src_weapon"))
	hero.skills = [weapon_skill]
	hero.mp = 99
	battle.use_skill(hero, weapon_skill, dummy)
	_check(dummy.has_status(Enums.Status.BURN),
		"Feuer-Rider baut Brand-Stacks über Waffennutzung auf")

	# Resistenz: senkt Elementschaden und damit auch die aufgebauten Stacks.
	var resist_hero := Combatant.create("Verteidiger", StatBlock.new(), true)
	resist_hero.equip(_item_with_affix(&"ruestung_leicht", &"feuerabwehr"))
	_check(resist_hero.element_resist(Enums.Element.FIRE) == 8,
		"'der Feuerabwehr': +8 % Feuer-Resistenz")
	_check(resist_hero.element_resist(Enums.Element.ICE) == 0,
		"Feuer-Resistenz wirkt nicht gegen Eis")
	var banish_hero := Combatant.create("Bannträger", StatBlock.new(), true)
	banish_hero.equip(_item_with_affix(&"ruestung_leicht", &"bannung"))
	_check(banish_hero.element_resist(Enums.Element.DARK) == 6
		and banish_hero.element_resist(Enums.Element.FIRE) == 6,
		"'der Bannung' wirkt gegen alle Elemente")

	var naked := Combatant.create("Nackt", StatBlock.new(), true)
	var fire_block: ElementBlock = BlockLibrary.element_block(Enums.Element.FIRE)
	var battle2 := Battle.new()
	battle2.crit_enabled = false
	battle2.rng.seed = 1
	battle2.start([hero], [naked, resist_hero])
	battle2._apply_elemental_hit(hero, naked, 10.0, fire_block)
	battle2._apply_elemental_hit(hero, resist_hero, 10.0, fire_block)
	var naked_stacks: int = naked.get_status(Enums.Status.BURN)["potency"]
	var resist_stacks: int = resist_hero.get_status(Enums.Status.BURN)["potency"]
	_check(resist_stacks < naked_stacks,
		"Resistenz senkt Brand-Stacks (%d < %d)" % [resist_stacks, naked_stacks])

	# Prozent statt flach: auf hohem Level wiegt dieselbe Resistenz genauso viel.
	var hoch := ItemLibrary.make_item(&"ruestung_leicht", 80)
	hoch.affixes.append(ItemLibrary.get_affix(&"feuerabwehr"))
	hoch.affix_rolls.append(1.0)
	_check(hoch.get_element_resist(Enums.Element.FIRE) == 8,
		"Resistenz ist Prozent und hängt nicht am Item-Level")
	var wall := Combatant.create("Wall", StatBlock.new(), true)
	for i in 12:
		wall.equip(_item_with_affix(&"ring", &"bannung"))
	_check(wall.element_resist(Enums.Element.FIRE) <= Combatant.ELEMENT_RESIST_MAX,
		"Resistenz ist gedeckelt (höchstens %d %%)" % Combatant.ELEMENT_RESIST_MAX)

	# Zauberkraft skaliert jetzt mit dem Item-Level (Caster-Endgame-Fix).
	var staff_low := ItemLibrary.make_item(&"offensivstab", 1)
	var staff_high := ItemLibrary.make_item(&"offensivstab", 12)
	_check(staff_high.get_total_spell_damage() > staff_low.get_total_spell_damage(),
		"Zauberkraft skaliert mit Item-Level (%d > %d)"
		% [staff_high.get_total_spell_damage(), staff_low.get_total_spell_damage()])
	var arcane_staff := _item_with_affix(&"offensivstab", &"arkan")
	_check(arcane_staff.get_total_spell_damage() == 12,
		"'Arkanes': +3 Zauberkraft (9 + 3)")


func _test_skill_affixes() -> void:
	print("Skill-Affixe (MP-Kosten):")
	var stats := StatBlock.new()
	stats.intelligence = 5
	var mage := Combatant.create("Magier", stats, true)
	var spell := Skill.new()
	spell.blocks.append(BlockLibrary.get_block(&"src_spell"))
	var cost_before := spell.get_mp_cost(mage)
	mage.equip(_item_with_affix(&"ring", &"fokus"))
	_check(mage.mp_cost_reduction() == 5, "'des Fokus': −5 % MP-Kosten")
	_check(spell.get_mp_cost(mage) <= cost_before,
		"MP-Kosten steigen nie durch den Affix (%d » %d)" % [cost_before, spell.get_mp_cost(mage)])
	# Prozent statt flach: ein teurer Endgame-Zauber spart genauso 5 %.
	var teuer := Skill.new()
	for id in [&"src_spell", &"elem_fire", &"form_aoe", &"mod_overload"]:
		teuer.blocks.append(BlockLibrary.get_block(id))
	var stark := Combatant.create("Erzmagier", stats, true)
	stark.level = 90
	var ohne := teuer.get_mp_cost(stark)
	stark.equip(_item_with_affix(&"ring", &"fokus"))
	var mit := teuer.get_mp_cost(stark)
	_check(absf(float(ohne - mit) / ohne - 0.05) < 0.02,
		"Endgame: weiterhin ~5 %% gespart (%d » %d MP)" % [ohne, mit])

func _test_affix_rolls_and_rarities() -> void:
	print("Affix-Qualität (Wertstreuung) und Affix-Raritäten:")
	# Qualitäts-Roll: "+5 Schaden" (der Verwüstung) wird zu +5 bis +8.
	var seen_values := {}
	var in_band := true
	for i in 80:
		var item := ItemLibrary.make_item(&"schwert", 1)
		item.affixes = [ItemLibrary.get_affix(&"verwuestung")] as Array[Affix]
		var roll_rng := _rng(i)
		var rolls: Array[float] = [snappedf(roll_rng.randf_range(
			LootGenerator.AFFIX_ROLL_MIN, LootGenerator.AFFIX_ROLL_MAX), 0.01)]
		item.affix_rolls = rolls
		var bonus := item.get_total_damage() - 8  # Basis Schwert = 8
		seen_values[bonus] = true
		if bonus < 5 or bonus > 8:
			in_band = false
	_check(in_band, "'der Verwüstung' rollt +5 bis +8 (Basis 5 × 1,0–1,6)")
	_check(seen_values.size() >= 3, "Werte streuen (%d verschiedene)" % seen_values.size())

	# Der Loot-Generator würfelt die Qualität automatisch mit.
	var rolls_ok := true
	for i in 60:
		var item := LootGenerator.roll_item(6, _rng(i * 13))
		if item.affix_rolls.size() != item.affixes.size():
			rolls_ok = false
		for roll in item.affix_rolls:
			if roll < LootGenerator.AFFIX_ROLL_MIN or roll > LootGenerator.AFFIX_ROLL_MAX:
				rolls_ok = false
	_check(rolls_ok, "jeder gedroppte Affix bekommt einen Qualitäts-Roll in der Spanne")

	# Affix-Raritäten: der Katalog nutzt mehrere Stufen …
	var rarities := {}
	for is_prefix in [true, false]:
		for affix in ItemLibrary.affixes_for_tier(99, is_prefix):
			rarities[affix.rarity] = true
	_check(rarities.size() >= 4, "Affix-Katalog nutzt ≥4 Raritätsstufen (%d)" % rarities.size())

	# … und die Gewichtung wirkt: häufige Affixe fallen öfter als legendäre.
	var common_hits := 0
	var legendary_hits := 0
	for i in 400:
		var item := LootGenerator.roll_item_with_rarity(9, Enums.Rarity.RARE, _rng(i * 7))
		for affix in item.affixes:
			if affix.rarity == Enums.Rarity.COMMON:
				common_hits += 1
			elif affix.rarity == Enums.Rarity.LEGENDARY:
				legendary_hits += 1
	_check(common_hits > legendary_hits * 3,
		"Gewichtung: häufige Affixe %d× vs. legendäre %d×" % [common_hits, legendary_hits])

	# Qualitäts-Rolls überstehen den Speicher-Rundweg.
	var original := LootGenerator.roll_item_with_rarity(6, Enums.Rarity.EPIC, _rng(42))
	var restored := ItemInstance.from_dict(original.to_dict())
	_check(restored.affix_rolls.size() == original.affix_rolls.size()
		and restored.get_total_damage() == original.get_total_damage()
		and restored.get_total_armor() == original.get_total_armor()
		and restored.get_total_stat_bonus().strength == original.get_total_stat_bonus().strength,
		"Qualitäts-Rolls überstehen den Speicher-Rundweg (Werte identisch)")


# --- Boss-Beute (BossBeute) ------------------------------------------------------

func _held_mit(item: ItemInstance) -> Combatant:
	var stats := StatBlock.new()
	for stat in StatBlock.STAT_NAMES:
		stats.set(stat, 10)
	var held := Combatant.create("Held", stats, true)
	if item != null:
		held.equip(item)
	return held


func _boss_item(affix_id: StringName, base_id := &"ring") -> ItemInstance:
	var item := ItemLibrary.make_item(base_id, 10)
	item.affixes = [ItemLibrary.get_affix(affix_id)] as Array[Affix]
	item.affix_rolls = [1.0] as Array[float]
	return item


func _feind(hp: int) -> Combatant:
	var feind := Combatant.create("Feind", StatBlock.new(), false)
	feind.max_hp = hp
	feind.hp = hp
	return feind


func _kampf(held: Combatant, feind: Combatant) -> Battle:
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.start([held] as Array[Combatant], [feind] as Array[Combatant])
	return battle


func _test_boss_beute() -> void:
	print("Boss-Beute:")
	# Jeder Boss-Grundtyp hat einen Pool; nichts davon rollt im normalen Pool.
	# (Neue Bosse ohne Pool geben einfach keine Boss-Affixe — hier gelistet.)
	var ohne_pool: Array[String] = []
	for archetype in EnemyLibrary.all_archetypes():
		if archetype.is_boss_capable and ItemLibrary.boss_affixe(archetype.id).size() < 2:
			ohne_pool.append(String(archetype.id))
	if not ohne_pool.is_empty():
		print("  Hinweis: Bosse ohne Boss-Affix-Pool: %s" % ", ".join(ohne_pool))
	var pools_ok := true
	for boss_id in [&"baer", &"schleimgott", &"golem", &"troll", &"kultist", &"nekromant",
			&"schattenbestie", &"todesmeister", &"verfluchtbock", &"hexenmeisterin", &"demonenkonig"]:
		pools_ok = pools_ok and ItemLibrary.boss_affixe(boss_id).size() >= 2
	_check(pools_ok, "jeder Boss-Grundtyp hat mindestens 2 Boss-Affixe")
	var im_normalen_pool := false
	for tier in [1, 20, 100]:
		for prefix in [true, false]:
			for affix in ItemLibrary.affixes_for_tier(tier, prefix):
				im_normalen_pool = im_normalen_pool or affix.boss_id != &""
	_check(not im_normalen_pool, "Boss-Affixe rollen nie im normalen Affix-Pool")
	var normal_mit_boss := false
	for i in 300:
		normal_mit_boss = normal_mit_boss or BossBeute.hat_boss_affix(LootGenerator.roll_item(40, _rng(i)))
	_check(not normal_mit_boss, "normale Drops tragen keinen Boss-Affix")

	# Bosskampf-Beute: Chance je Item, Pool passt zum Boss, beliebige Basis.
	var boss := Combatant.create("Boss: Schleimgott", StatBlock.new(), false)
	boss.archetype_id = &"schleimgott"
	boss.ist_bossgegner = true
	var items_gesamt := 0
	var mit_affix := 0
	var passend := true
	var basen := {}
	for i in 600:
		var loot := LootGenerator.roll_battle_loot([boss] as Array[Combatant], 30, true, _rng(9000 + i))
		for item: ItemInstance in loot["items"]:
			items_gesamt += 1
			for affix in item.affixes:
				if affix.boss_id != &"":
					mit_affix += 1
					passend = passend and affix.boss_id == &"schleimgott"
					basen[item.base.id] = true
	var anteil := float(mit_affix) / maxi(1, items_gesamt)
	_check(anteil > 0.08 and anteil < 0.16, "etwa 12 %% der Boss-Items tragen einen Boss-Affix (%.1f %%)" % (anteil * 100))
	_check(passend, "Boss-Affixe stammen aus dem Pool des besiegten Bosses")
	_check(basen.size() >= 8, "Boss-Affixe auf vielen Basen (%d)" % basen.size())
	var legacy := 0
	var legacy_items := 0
	for i in 600:
		var loot := LootGenerator.roll_battle_loot([boss] as Array[Combatant], 30, true, _rng(19000 + i), 0, true)
		for item: ItemInstance in loot["items"]:
			legacy_items += 1
			if BossBeute.hat_boss_affix(item):
				legacy += 1
	_check(float(legacy) / maxi(1, legacy_items) > anteil, "Legacy-Bosse geben öfter Boss-Beute (%d/%d)" % [legacy, legacy_items])
	var normal := Combatant.create("Wolf", StatBlock.new(), false)
	normal.archetype_id = &"wolf"
	var ohne_boss := 0
	for i in 200:
		for item: ItemInstance in LootGenerator.roll_battle_loot([normal] as Array[Combatant], 30, true, _rng(i))["items"]:
			if BossBeute.hat_boss_affix(item):
				ohne_boss += 1
	_check(ohne_boss == 0, "ohne Boss im Kampf keine Boss-Affixe")

	# Slot-Bindung: Rider nur auf Waffen; höchstens ein Boss-Affix je Item.
	var slot_ok := true
	for i in 50:
		var probe := ItemLibrary.make_item(&"ring", 5)
		BossBeute.boss_affix_hinzufuegen(probe, &"schleimgott", _rng(i))
		for affix in probe.affixes:
			slot_ok = slot_ok and affix.element_damage == 0
	_check(slot_ok, "Gift-Rider des Schleimgotts landet nie auf einem Ring")
	var ring := ItemLibrary.make_item(&"ring", 5)
	_check(BossBeute.boss_affix_hinzufuegen(ring, &"golem", _rng(1))
		and not BossBeute.boss_affix_hinzufuegen(ring, &"golem", _rng(2)), "höchstens ein Boss-Affix je Item")

	# Name: Boss-Suffix, deutsches Genus (Ring maskulin), Englisch ganz englisch.
	var name_item := _boss_item(&"boss_schleimgott_schlund")
	name_item.affixes.push_front(ItemLibrary.get_affix(&"flammend"))
	name_item.affixes.append(ItemLibrary.get_affix(&"sturm"))
	name_item.affix_rolls = [1.0, 1.0, 1.0] as Array[float]
	_check(name_item.get_display_name() == "Flammender Ring des Schleimgotts",
		"Name DE: %s" % name_item.get_display_name())
	_check(ItemLibrary.make_item(&"ring").get_display_name() == "Ring", "Ring ohne Affix")
	var gespeichert_name := name_item.to_dict()
	Loc.set_language("en")
	ItemLibrary.reset_cache()
	EnemyLibrary.reset_cache()
	var name_en := ItemInstance.from_dict(gespeichert_name).get_display_name()
	var text_en := " · ".join(ItemInfo.eigenschaften(ItemInstance.from_dict(gespeichert_name)))
	Loc.set_language("de")
	ItemLibrary.reset_cache()
	EnemyLibrary.reset_cache()
	_check(name_en == "Flaming Ring of the Slime God", "Name EN: %s" % name_en)
	_check(text_en.contains("Boss loot (Slime God)") and text_en.contains("when defeating an enemy"),
		"Item-Karte EN: %s" % text_en)
	var text_de := " · ".join(ItemInfo.eigenschaften(_boss_item(&"boss_schleimgott_schlund")))
	_check(text_de.contains("Boss-Beute (Schleimgott)") and text_de.contains("heilt 4 %"),
		"Item-Karte DE: %s" % text_de)
	var mechanik := " · ".join(ItemInfo.eigenschaften(_boss_item(&"boss_daemonenkoenig_glut", &"axt")))
	_check(mechanik.contains("Boss-Beute (Dämonen-König)") and mechanik.contains("Feuer"),
		"Boss-Affix über normale Mechanik (Feuer-Rider): %s" % mechanik)

	# Speichern: nur IDs, Roll bleibt; Schmiede-Neuwürfeln behält den Boss-Affix.
	var gespeichert := _boss_item(&"boss_golem_haut", &"ruestung_schwer")
	gespeichert.affix_rolls = [1.4] as Array[float]
	var daten := gespeichert.to_dict()
	var geladen := ItemInstance.from_dict(JSON.parse_string(JSON.stringify(daten)))
	_check(daten["affix_ids"] == ["boss_golem_haut"] and geladen.affixes[0].boss_effekt == &"steinhaut"
		and is_equal_approx(geladen.affix_roll(0), 1.4), "Speicherformat: nur Affix-ID + Roll")
	geladen.rarity = Enums.Rarity.EPIC
	Smith.reroll(geladen, _rng(3))
	var behalten := false
	for i in geladen.affixes.size():
		behalten = behalten or (geladen.affixes[i].id == &"boss_golem_haut" and is_equal_approx(geladen.affix_roll(i), 1.4))
	_check(behalten and geladen.affixes.size() == 4,
		"Neuwürfeln behält den Boss-Affix samt Roll (%d Affixe)" % geladen.affixes.size())

	# Kampfwirkung: Faktoren.
	var held := _held_mit(_boss_item(&"boss_bock_zorn"))
	var feind := _feind(1000)
	_kampf(held, feind)
	_check(is_equal_approx(BossBeute.schadens_faktor(held, feind), 1.0), "Wut: volle HP, kein Bonus")
	held.hp = held.max_hp / 3
	_check(is_equal_approx(BossBeute.schadens_faktor(held, feind), 1.12), "Wut: unter 50 % HP +12 %")
	var jaeger := _held_mit(_boss_item(&"boss_todesmeister_ende"))
	feind.hp = 400
	_check(is_equal_approx(BossBeute.schadens_faktor(jaeger, feind), 1.12), "Jäger: Ziel unter 50 % HP +12 %")
	var stein := _held_mit(_boss_item(&"boss_golem_haut"))
	_check(is_equal_approx(BossBeute.schadens_faktor(feind, stein), 0.94), "Steinhaut: 6 % weniger Schaden")
	var viel := _held_mit(null)
	for slot_base in [&"ring", &"amulett", &"helm_schwer", &"ruestung_schwer", &"stiefel_schwer"]:
		var teil := _boss_item(&"boss_golem_haut", slot_base)
		teil.affix_rolls = [1.6] as Array[float]
		viel.equip(teil)
	_check(BossBeute.wert(viel, &"steinhaut") == BossBeute.DECKEL[&"steinhaut"],
		"Deckel: Steinhaut höchstens %d %%" % BossBeute.DECKEL[&"steinhaut"])
	_check(BossBeute.wert(feind, &"wut") == 0, "Gegner haben keine Boss-Beute-Werte")
	# Echter Treffer: Steinhaut senkt den Schaden.
	var ohne := _held_mit(null)
	var a := _feind(100)
	var b1 := _kampf(ohne, a)
	var voll := b1._deal_damage(a, ohne, 40.0, Enums.DamageAxis.ELEMENTAL)
	var stein2 := _held_mit(_boss_item(&"boss_golem_haut"))
	var b2 := _kampf(stein2, a)
	var weniger := b2._deal_damage(a, stein2, 40.0, Enums.DamageAxis.ELEMENTAL)
	_check(weniger < voll, "Steinhaut im echten Treffer (%d statt %d)" % [weniger, voll])

	# Lebensraub / Verschlingen / Opfergabe / Rache / Regeneration über echte Treffer.
	var vampir := _held_mit(_boss_item(&"boss_nekromant_raub"))
	vampir.hp = 10
	var ziel := _feind(5000)
	var schaden := _kampf(vampir, ziel)._deal_damage(vampir, ziel, 200.0, Enums.DamageAxis.ELEMENTAL)
	_check(vampir.hp == mini(vampir.max_hp, 10 + maxi(1, roundi(schaden * 0.04))),
		"Lebensraub: heilt 4 %% des Schadens (%d Schaden, %d HP)" % [schaden, vampir.hp])
	var fresser := _held_mit(_boss_item(&"boss_schleimgott_schlund"))
	fresser.hp = 10
	var opfer := _feind(5)
	_kampf(fresser, opfer)._deal_damage(fresser, opfer, 500.0, Enums.DamageAxis.ELEMENTAL)
	_check(not opfer.is_alive() and fresser.hp == 10 + maxi(1, roundi(fresser.max_hp * 0.04)),
		"Verschlingen: heilt 4 %% Max-HP beim Besiegen (%d HP)" % fresser.hp)
	var priester := _held_mit(_boss_item(&"boss_kultist_opfer"))
	priester.mp = 0
	var opfer2 := _feind(5)
	_kampf(priester, opfer2)._deal_damage(priester, opfer2, 500.0, Enums.DamageAxis.ELEMENTAL)
	_check(priester.mp == maxi(1, roundi(priester.max_mp * 0.04)),
		"Opfergabe: 4 %% Max-MP beim Besiegen (%d MP)" % priester.mp)
	var raecher := _held_mit(_boss_item(&"boss_daemonenkoenig_rache"))
	raecher.max_hp = 10000
	raecher.hp = 10000
	var angreifer := _feind(1000)
	var erlitten := _kampf(raecher, angreifer)._deal_damage(angreifer, raecher, 300.0, Enums.DamageAxis.ELEMENTAL)
	_check(angreifer.hp == 1000 - maxi(1, roundi(erlitten * 0.1)),
		"Rache: 10 %% des erlittenen Schadens zurück (%d, %d)" % [erlitten, 1000 - angreifer.hp])
	var troll := _held_mit(_boss_item(&"boss_troll_regen"))
	var kampf5 := _kampf(troll, _feind(50))
	troll.hp = 10
	kampf5._process_turn_start(troll)
	_check(troll.hp == 10 + maxi(1, roundi(troll.max_hp * 0.02)), "Regeneration: 2 %% Max-HP je Zug (%d)" % troll.hp)
	troll.hp = 10
	troll.add_status(Enums.Status.POISON_DOT, -1, 1)
	kampf5._process_turn_start(troll)
	_check(troll.hp <= 10, "Regeneration: Gift blockiert sie (%d)" % troll.hp)
