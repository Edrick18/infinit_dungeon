extends SceneTree
## Headless-Selbsttest für Medaillen-Stufen und Regelbrecher-Affixe:
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/meta_selftest.gd

var failures := 0


func _init() -> void:
	var waechter := FehlerWaechter.anmelden()
	_test_stufen()
	_test_regelbrecher_rollen()
	_test_regelbrecher_wirkung()
	failures += waechter.fehler_melden()
	if failures == 0:
		print("SELFTEST OK — alle Meta-Tests bestanden")
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


func _test_stufen() -> void:
	print("Medaillen-Stufen:")
	_check(MedaillenStufen.schwelle(0) == 5 and MedaillenStufen.schwelle(6) == 100
		and MedaillenStufen.schwelle(7) == 150 and MedaillenStufen.schwelle(8) == 200,
		"Schwellen 5 … 100, danach alle 50")
	_check(MedaillenStufen.belohnung(9) == &"rune_regel", "nach 100: Regelrunen")
	var state: Node = load("res://autoload/game_state.gd").new()
	state.medaille(4)
	_check(state.medals == 4 and state.medaillen_gesamt == 4, "medaille() zählt Besitz und Gesamt")
	_check(MedaillenStufen.abholen(state).is_empty(), "Stufe 5 mit 4 Medaillen noch nicht abholbar")
	state.medaille(1)
	state.medals -= 5  # ausgeben zählt nicht gegen die Stufen
	var lager_vorher: int = state.card_capacity
	_check(not MedaillenStufen.abholen(state).is_empty() and state.card_capacity == lager_vorher + 5,
		"Stufe 5: +5 Kartenlager-Plätze (trotz ausgegebener Medaillen)")
	_check(MedaillenStufen.abholen(state).is_empty(), "jede Stufe nur einmal")
	state.medaille(25)
	MedaillenStufen.abholen(state)
	MedaillenStufen.abholen(state)
	MedaillenStufen.abholen(state)
	_check(state.material_count(&"rune_episch") == 1 and state.material_count(&"rune_regel") == 1
		and state.medaillen_stufen == 4, "Stufen 10/20/30: Rune, Schatzkarte, Regelrune")
	var gespeichert: Dictionary = state.to_save_dict()
	var neu: Node = load("res://autoload/game_state.gd").new()
	neu.apply_save_dict(gespeichert)
	_check(neu.medaillen_gesamt == 30 and neu.medaillen_stufen == 4, "Zähler überstehen Speichern/Laden")
	var alt := gespeichert.duplicate()
	alt.erase("medaillen_gesamt")
	alt.erase("medaillen_stufen")
	alt["medals"] = 12
	neu.apply_save_dict(alt)
	_check(neu.medaillen_gesamt == 12 and neu.medaillen_stufen == 0, "alter Spielstand: Besitz zählt als gesammelt")
	state.free()
	neu.free()


func _test_regelbrecher_rollen() -> void:
	print("Regelbrecher rollen:")
	_check(ItemLibrary.regel_affixe().size() == 3, "drei Regelbrecher-Affixe")
	var im_pool := false
	for tier in [1, 50, 200]:
		for prefix in [true, false]:
			for affix in ItemLibrary.affixes_for_tier(tier, prefix):
				if affix.regelbruch != &"":
					im_pool = true
	_check(not im_pool, "Regelbrecher rollen nie im normalen Affix-Pool")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var garantiert := true
	for i in 30:
		var item := Smith.schmieden(&"nahkampf", 1, 10, &"rune_regel", rng)
		if item == null:
			continue
		var hat := false
		for affix in item.affixes:
			hat = hat or affix.regelbruch != &""
		garantiert = garantiert and hat and item.rarity == Enums.Rarity.LEGENDARY
	_check(garantiert, "Regelrune: legendär mit genau einem Regelbrecher")
	var ohne := true
	for i in 200:
		var item := Smith.schmieden(&"nahkampf", 1, 10, &"", rng)
		if item != null and item.rarity != Enums.Rarity.LEGENDARY:
			for affix in item.affixes:
				ohne = ohne and affix.regelbruch == &""
	_check(ohne, "nicht-legendäre Items tragen nie einen Regelbrecher")
	var kopie := ItemInstance.from_dict(Smith.schmieden(&"nahkampf", 1, 10, &"rune_regel", rng).to_dict())
	var gespeichert := false
	for affix in kopie.affixes:
		gespeichert = gespeichert or affix.regelbruch != &""
	_check(gespeichert, "Regelbrecher übersteht Speichern/Laden")


func _item_mit(regel: StringName, slot_item: StringName) -> ItemInstance:
	var item := ItemLibrary.make_item(slot_item, 10)
	for affix in ItemLibrary.regel_affixe():
		if affix.regelbruch == regel:
			item.affixes.append(affix)
			item.affix_rolls.append(1.0)
	return item


func _test_regelbrecher_wirkung() -> void:
	print("Regelbrecher wirken:")
	var held := Combatant.create("Held", StatBlock.new(), true)
	held.level = 1
	var sockel := held.block_sockets()
	held.equip(_item_mit(&"sockel", &"amulett"))
	_check(held.block_sockets() == sockel + 1, "Baumeister: +1 Sockel (%d » %d)" % [sockel, held.block_sockets()])

	# Zwei Kern-Klötze
	var kerne: Array[SkillBlock] = []
	for block in BlockLibrary.all_blocks():
		if block.kern and block.weapon_families.is_empty() and kerne.size() < 2:
			kerne.append(block)
	var skill := Skill.new()
	skill.blocks.append(BlockLibrary.get_block(&"src_spell"))
	for k in kerne:
		skill.blocks.append(k)
	var magier := Combatant.create("Magier", StatBlock.new(), true)
	magier.level = 60
	magier.peak_level = 60
	var vorher := skill.fehler(magier)
	magier.equip(_item_mit(&"doppelkern", &"ring"))
	var nachher := skill.fehler(magier)
	_check(kerne.size() == 2 and vorher.contains("Kern") and not nachher.contains("Kern"),
		"Doppelkern: zwei Kern-Klötze erlaubt (vorher: %s / nachher: %s)" % [vorher, nachher])

	# Techniken mit jeder Waffe
	var technik: SkillBlock = null
	for block in BlockLibrary.all_blocks():
		if block.weapon_families == [&"dolch"] and not block.kern and not block is SourceBlock:
			technik = block
			break
	var tskill := Skill.new()
	tskill.blocks.append(BlockLibrary.get_block(&"src_weapon"))
	tskill.blocks.append(technik)
	var kaempfer := Combatant.create("Kämpfer", StatBlock.new(), true)
	kaempfer.equip(ItemLibrary.make_item(&"axt", 10))
	var ohne := tskill.usable_with_weapon(kaempfer)
	kaempfer.equip(_item_mit(&"waffenfrei", &"amulett"))
	_check(technik != null and not ohne and tskill.usable_with_weapon(kaempfer),
		"Waffenfreiheit: Dolch-Technik mit der Axt nutzbar")
