class_name EnemyLibrary
extends RefCounted
## Katalog der Gegner-Archetypen und Elite-Modifikatoren für den Baukasten.
## Gegner-Skills werden aus denselben Bausteinen gebaut wie Spieler-Skills
## (BlockLibrary) — ein System für alles. Vorerst im Code, später .tres.

static var _archetypes: Dictionary = {}
static var _modifiers: Dictionary = {}


## Sprachwechsel: Cache leeren, Namen backen sich neu.
static func reset_cache() -> void:
	_archetypes.clear()
	_modifiers.clear()


static func all_archetypes() -> Array[EnemyArchetype]:
	_ensure_built()
	var result: Array[EnemyArchetype] = []
	for id in _archetypes:
		result.append(_archetypes[id])
	return result


static func get_archetype(id: StringName) -> EnemyArchetype:
	_ensure_built()
	return _archetypes.get(id)


## tier filtert nach unlock_tier: der Grundtyp-Pool wächst mit den Stufen.
static func archetypes_for_biome(biome: Enums.Biome, boss_only := false,
		tier := 999) -> Array[EnemyArchetype]:
	var result: Array[EnemyArchetype] = []
	for archetype in all_archetypes():
		if biome not in archetype.biomes:
			continue
		if boss_only and not archetype.is_boss_capable:
			continue
		if not boss_only and archetype.boss_only:
			continue  # z.B. Schleimgott: nur als Boss, nie als Trash-Mob
		if archetype.unlock_tier > tier:
			continue
		result.append(archetype)
	return result


static func get_modifier(id: StringName) -> EnemyModifier:
	_ensure_built()
	return _modifiers.get(id)


static func all_modifiers() -> Array[EnemyModifier]:
	_ensure_built()
	var result: Array[EnemyModifier] = []
	for id in _modifiers:
		result.append(_modifiers[id])
	return result


## Würfelt Modifikatoren für eine neue Dungeon-Karte (fix bei Erstellung,
## siehe DungeonCard). Nur Modifikatoren, deren min_tier zur Stufe passt;
## höhere Stufen können mehr Modifikatoren gleichzeitig tragen (bis zu 4).
static func roll_modifiers(tier: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var eligible: Array[EnemyModifier] = []
	for modifier in all_modifiers():
		if modifier.min_tier <= tier:
			eligible.append(modifier)
	var result: Array[StringName] = []
	var max_count := clampi(1 + tier / 5, 1, 4)
	var count := rng.randi_range(1, max_count)
	for i in count:
		if eligible.is_empty():
			break
		var pick := rng.randi_range(0, eligible.size() - 1)
		result.append(eligible[pick].id)
		eligible.remove_at(pick)
	return result


static func _ensure_built() -> void:
	if not _archetypes.is_empty():
		return
	_build_archetypes()
	_build_modifiers()


static func _build_archetypes() -> void:
	var list: Array[EnemyArchetype] = []

	# Basisnamen ohne Region — die Region-Variante ("Wald-", "Krypta-", …)
	# legt die EnemyFactory als Schicht obendrauf.
	var wolf := _archetype(&"wolf", "Wolf",
		[Enums.Biome.FOREST],
		_stats(6, 0, 4, 0, 9, 2), _stats(1, 0, 1, 0, 1, 0), 0, 0,
		[_skill("Biss", [&"src_weapon"])], 1, false,
		Enums.Temperament.AGGRESSIVE, 1)
	wolf.calls_reinforcements = true  # heult das Rudel herbei
	wolf.variant_group = &"bestie"  # Alpha-/Gift-/Blut-/Ur-Wolf
	list.append(wolf)

	# Bandit: menschlicher Räuber — Klassen-Varianten (Krieger/Bogenschütze/
	# Magier/Beschwörer) und ruft Kumpane zur Verstärkung.
	var bandit := _archetype(&"bandit", "Bandit",
		[Enums.Biome.FOREST, Enums.Biome.RUINS],
		_stats(7, 2, 6, 2, 7, 4), _stats(1, 0, 1, 0, 1, 0), 1, 1,
		[_skill("Hinterhalt", [&"src_weapon"])], 1, false,
		Enums.Temperament.AGGRESSIVE, 2)
	bandit.variant_group = &"humanoid"
	bandit.calls_reinforcements = true
	list.append(bandit)

	# Mimic: taucht in KEINEM Biom-Pool auf (leere Biom-Liste) — er lauert
	# ausschließlich in Risiko-Truhen (Dungeon-Events).
	list.append(_archetype(&"mimic", "Mimic",
		[] as Array[Enums.Biome],
		_stats(9, 0, 10, 0, 6, 4), _stats(2, 0, 2, 0, 1, 0), 3, 2,
		[_skill("Zuschnappen", [&"src_weapon"])], 1, false,
		Enums.Temperament.AGGRESSIVE, 1))

	var bear := _archetype(&"baer", Loc.pick("Bär", "Bear"),
		[Enums.Biome.FOREST],
		_stats(9, 0, 9, 0, 4, 1), _stats(1, 0, 2, 0, 0, 0), 2, 0,
		[_skill("Prankenhieb", [&"src_weapon"])], 1, true,
		Enums.Temperament.TERRITORIAL, 2)
	bear.variant_group = &"bestie"
	list.append(bear)

	# --- Die Schleim-Familie (DQ-Prinzip): Schleim » Schleimstapel »
	# König-Schleim » SCHLEIMGOTT. Alle Stufen spawnen natürlich (steigende
	# Freischalt-Stufen) UND entstehen im Kampf durchs Stapeln (Battle).
	var slime := _archetype(&"schleim", Loc.pick("Schleim", "Slime"),
		[Enums.Biome.FOREST, Enums.Biome.CAVE],
		_stats(3, 0, 7, 4, 3, 0), _stats(0, 0, 1, 1, 0, 0), 0, 2,
		[_skill("Säurespucke", [&"src_spell", &"elem_poison"])], 1, false,
		Enums.Temperament.SKITTISH, 1)
	slime.variant_group = &"schleim"  # Metall-/Gift-/Heilschleim
	list.append(slime)

	var slime_stack := _archetype(&"schleimstapel", Loc.pick("Schleimstapel", "Slime Stack"),
		[Enums.Biome.FOREST, Enums.Biome.CAVE],
		_stats(6, 0, 12, 6, 4, 1), _stats(1, 0, 1, 1, 0, 0), 1, 3,
		[_skill("Wabernder Schlag", [&"src_weapon"]),
			_skill("Säureschwall", [&"src_spell", &"elem_poison"])], 1, false,
		Enums.Temperament.TERRITORIAL, 4)
	slime_stack.variant_group = &"schleim"
	list.append(slime_stack)

	var slime_king := _archetype(&"koenigschleim", Loc.pick("König-Schleim", "King Slime"),
		[Enums.Biome.FOREST, Enums.Biome.CAVE],
		_stats(10, 0, 20, 10, 5, 2), _stats(2, 0, 2, 1, 0, 0), 2, 4,
		[_skill("Königsplatscher", [&"src_weapon"]),
			_skill("Schleimwoge", [&"src_spell", &"form_aoe"])], 2, false,
		Enums.Temperament.AGGRESSIVE, 8)
	slime_king.sprite_scale = 1.3  # Der König IST einfach größer.
	list.append(slime_king)

	# Schleimgott: NUR als Boss — ruft Schleime und verschlingt sie (Battle).
	var slime_god := _archetype(&"schleimgott", Loc.pick("Schleimgott", "Slime God"),
		[Enums.Biome.FOREST, Enums.Biome.CAVE],
		_stats(14, 8, 18, 14, 6, 3), _stats(2, 1, 2, 2, 0, 0), 3, 6,
		[_skill("Götterplatscher", [&"src_weapon"]),
			_skill("Urschleim-Flut", [&"src_spell", &"elem_poison", &"form_aoe"])], 2, true,
		Enums.Temperament.AGGRESSIVE, 10)
	slime_god.boss_only = true
	slime_god.sprite_scale = 1.5
	list.append(slime_god)

	var bat := _archetype(&"fledermaus", Loc.pick("Fledermaus", "Bat"),
		[Enums.Biome.FOREST, Enums.Biome.CAVE],
		_stats(4, 0, 3, 0, 11, 3), _stats(1, 0, 1, 0, 1, 0), 0, 0,
		[_skill("Sturzflug", [&"src_weapon"])], 1, false,
		Enums.Temperament.SKITTISH, 1)
	bat.variant_group = &"bestie"
	list.append(bat)

	var spider := _archetype(&"spinne", Loc.pick("Riesenspinne", "Giant Spider"),
		[Enums.Biome.FOREST, Enums.Biome.CAVE],
		_stats(5, 0, 5, 3, 8, 1), _stats(1, 0, 1, 1, 1, 0), 1, 1,
		[_skill("Giftbiss", [&"src_spell", &"elem_poison"])], 1, false,
		Enums.Temperament.SKITTISH, 3)
	spider.variant_group = &"bestie"
	list.append(spider)

	var golem := _archetype(&"golem", "Golem",
		[Enums.Biome.CAVE, Enums.Biome.RUINS],
		_stats(8, 0, 10, 0, 2, 0), _stats(1, 0, 2, 0, 0, 0), 5, 2,
		[_skill("Steinwurf", [&"src_weapon"]),
			_skill("Beben", [&"src_spell", &"form_aoe"])], 1, true,
		Enums.Temperament.TERRITORIAL, 3)
	golem.variant_group = &"konstrukt"
	list.append(golem)

	list.append(_archetype(&"troll", "Troll",
		[Enums.Biome.CAVE, Enums.Biome.RUINS],
		_stats(11, 0, 12, 0, 3, 0), _stats(2, 0, 2, 0, 0, 0), 3, 1,
		[_skill("Keulenschlag", [&"src_weapon"])], 1, true,
		Enums.Temperament.TERRITORIAL, 5))

	var skeleton := _archetype(&"skelett", Loc.pick("Skelett", "Skeleton"),
		[Enums.Biome.RUINS, Enums.Biome.CRYPT],
		_stats(7, 0, 6, 0, 4, 1), _stats(1, 0, 1, 0, 1, 0), 3, 0,
		[_skill("Knochenhieb", [&"src_weapon"])], 1, false,
		Enums.Temperament.AGGRESSIVE, 1)
	skeleton.undead = true
	skeleton.variant_group = &"humanoid"  # Skelett-Krieger/-Bogenschütze/…
	list.append(skeleton)

	var cultist := _archetype(&"kultist", Loc.pick("Kultist", "Cultist"),
		[Enums.Biome.RUINS, Enums.Biome.CRYPT],
		_stats(2, 8, 6, 6, 5, 2), _stats(0, 1, 2, 1, 0, 0), 0, 3,
		[_skill("Schattenblitz", [&"src_spell"]),
			_skill("Feuerodem", [&"src_spell", &"elem_fire"])], 2, true,
		Enums.Temperament.TERRITORIAL, 4)
	cultist.undead = true
	cultist.variant_group = &"humanoid"
	cultist.calls_reinforcements = true  # ruft Glaubensbrüder
	list.append(cultist)

	var ghost := _archetype(&"geist", Loc.pick("Ruhelose Seele", "Restless Soul"),
		[Enums.Biome.RUINS, Enums.Biome.CRYPT],
		_stats(2, 9, 5, 7, 8, 2), _stats(0, 1, 1, 1, 1, 0), 0, 5,
		[_skill("Seelengriff", [&"src_spell"])], 1, false,
		Enums.Temperament.AGGRESSIVE, 7)
	ghost.undead = true
	ghost.variant_group = &"geist"
	list.append(ghost)

	# Nekromant: nutzt das Beschwörungs-System — ruft Dunkel-Elementare!
	var necromancer := _archetype(&"nekromant", Loc.pick("Nekromant", "Necromancer"),
		[Enums.Biome.CRYPT],
		_stats(3, 11, 9, 9, 4, 2), _stats(0, 1, 2, 1, 0, 0), 1, 4,
		[_skill("Schattenlanze", [&"src_spell", &"elem_dark"]),
			_skill("Totenruf", [&"src_spell", &"elem_dark", &"form_summon"])], 2, true,
		Enums.Temperament.TERRITORIAL, 9)
	necromancer.undead = true
	list.append(necromancer)

	list.append(_archetype(&"schattenbestie", Loc.pick("Schattenbestie", "Shadow Beast"),
		[Enums.Biome.RUINS, Enums.Biome.CRYPT],
		_stats(12, 6, 10, 4, 9, 3), _stats(2, 1, 2, 1, 1, 0), 2, 3,
		[_skill("Schattenklauen", [&"src_weapon"]),
			_skill("Dunkler Odem", [&"src_spell", &"elem_dark"])], 2, true,
		Enums.Temperament.AGGRESSIVE, 12))

	# --- Krypta-Familien (lokal generiert via qwen2.5-coder, geprüft) ------

	# Familie 1: Untote Diener und ihr Meister
	var toddiener := _archetype(&"toddiener", Loc.pick("Toddiener", "Undead Servant"),
		[Enums.Biome.CRYPT],
		_stats(4, 2, 6, 3, 5, 2), _stats(1, 0, 1, 1, 1, 0), 1, 2,
		[_skill("Todesschlag", [&"src_weapon", &"eff_slow"])], 1, false,
		Enums.Temperament.AGGRESSIVE, 3)
	toddiener.undead = true
	toddiener.calls_reinforcements = true
	toddiener.variant_group = &"humanoid"
	list.append(toddiener)

	var leichenfresser := _archetype(&"leichenfresser", Loc.pick("Leichenfresser", "Corpse Eater"),
		[Enums.Biome.CRYPT],
		_stats(8, 0, 7, 4, 9, 2), _stats(2, 0, 2, 1, 1, 0), 2, 3,
		[_skill("Krallensturm", [&"src_spell", &"form_aoe"]),
			_skill("Leichenfressen", [&"src_weapon", &"eff_lifesteal"])], 2, false,
		Enums.Temperament.AGGRESSIVE, 5)
	leichenfresser.undead = true
	leichenfresser.variant_group = &"bestie"
	list.append(leichenfresser)

	var schattenkrieger := _archetype(&"schattenkrieger", Loc.pick("Schattenkrieger", "Shadow Knight"),
		[Enums.Biome.CRYPT],
		_stats(8, 3, 10, 4, 4, 2), _stats(1, 1, 2, 1, 1, 0), 3, 4,
		[_skill("Schattenschlag", [&"src_weapon", &"elem_dark"]),
			_skill("Panzer", [&"src_spell", &"form_self", &"eff_shield"])], 2, false,
		Enums.Temperament.TERRITORIAL, 6)
	schattenkrieger.undead = true
	schattenkrieger.variant_group = &"humanoid"
	list.append(schattenkrieger)

	var todesmeister := _archetype(&"todesmeister", Loc.pick("Todesmeister", "Master of Death"),
		[Enums.Biome.CRYPT],
		_stats(10, 15, 12, 10, 6, 4), _stats(1, 1, 2, 1, 1, 0), 4, 5,
		[_skill("Seelenfressen", [&"src_spell", &"elem_dark", &"eff_lifesteal"]),
			_skill("Dunkelheit", [&"src_spell", &"elem_dark", &"form_aoe"])], 2, true,
		Enums.Temperament.AGGRESSIVE, 8)
	todesmeister.undead = true
	todesmeister.boss_only = true
	todesmeister.variant_group = &"humanoid"
	list.append(todesmeister)

	# Familie 2: Dämonenbrut
	var kleindaemon := _archetype(&"kleindaemon", Loc.pick("Klein-Dämon", "Small Demon"),
		[Enums.Biome.CRYPT],
		_stats(4, 8, 5, 6, 6, 3), _stats(1, 2, 1, 1, 1, 0), 1, 3,
		[_skill("Feuerball", [&"src_spell", &"elem_fire"])], 1, false,
		Enums.Temperament.AGGRESSIVE, 4)
	kleindaemon.undead = true
	kleindaemon.calls_reinforcements = true
	kleindaemon.variant_group = &"humanoid"
	list.append(kleindaemon)

	var daemonenjaeger := _archetype(&"demonenjager", Loc.pick("Dämonenjäger", "Demon Hunter"),
		[Enums.Biome.CRYPT],
		_stats(8, 2, 7, 4, 9, 2), _stats(2, 1, 1, 1, 1, 0), 2, 3,
		[_skill("Dämonenklaue", [&"src_weapon", &"elem_dark"]),
			_skill("Jagdinstinkt", [&"src_weapon", &"tech_kampfrausch"])], 2, false,
		Enums.Temperament.AGGRESSIVE, 5)
	daemonenjaeger.undead = true
	daemonenjaeger.variant_group = &"bestie"
	list.append(daemonenjaeger)

	var daemonenbeschwoerer := _archetype(&"demonenbeschwoerer", Loc.pick("Dämonenbeschwörer", "Demon Summoner"),
		[Enums.Biome.CRYPT],
		_stats(6, 10, 8, 8, 5, 3), _stats(1, 1, 2, 1, 1, 0), 2, 4,
		[_skill("Dämonenfeuer", [&"src_spell", &"elem_fire", &"form_aoe"]),
			_skill("Beschwörung", [&"src_spell", &"form_summon"])], 2, false,
		Enums.Temperament.TERRITORIAL, 7)
	daemonenbeschwoerer.undead = true
	daemonenbeschwoerer.variant_group = &"humanoid"
	list.append(daemonenbeschwoerer)

	# --- Wald-Familien (lokal generiert, Batch 2) --------------------------

	# Familie 1: Verfluchte Waldkreaturen
	var verfluchtkatz := _archetype(&"verfluchtkatz", Loc.pick("Verfluchte Katze", "Cursed Cat"),
		[Enums.Biome.FOREST],
		_stats(6, 0, 4, 0, 9, 2), _stats(1, 0, 1, 0, 1, 0), 0, 2,
		[_skill("Verfluchtkratzer", [&"src_weapon", &"tech_erstschlag"])], 1, false,
		Enums.Temperament.AGGRESSIVE, 2)
	verfluchtkatz.calls_reinforcements = true
	verfluchtkatz.variant_group = &"bestie"
	list.append(verfluchtkatz)

	var verfluchtigel := _archetype(&"verfluchtigel", Loc.pick("Verfluchter Igel", "Cursed Hedgehog"),
		[Enums.Biome.FOREST],
		_stats(5, 0, 5, 0, 10, 2), _stats(1, 0, 1, 0, 1, 0), 1, 2,
		[_skill("Verfluchtstachel", [&"src_weapon", &"tech_konter"])], 1, false,
		Enums.Temperament.AGGRESSIVE, 3)
	verfluchtigel.calls_reinforcements = true
	verfluchtigel.variant_group = &"bestie"
	list.append(verfluchtigel)

	var verfluchtdachs := _archetype(&"verfluchtdachs", Loc.pick("Verfluchter Dachs", "Cursed Badger"),
		[Enums.Biome.FOREST],
		_stats(6, 2, 12, 4, 3, 2), _stats(1, 1, 2, 1, 1, 0), 3, 4,
		[_skill("Verfluchtdachsschlag", [&"src_weapon", &"eff_slow"]),
			_skill("Panzer", [&"src_spell", &"form_self", &"eff_shield"])], 2, false,
		Enums.Temperament.TERRITORIAL, 4)
	verfluchtdachs.variant_group = &"bestie"
	list.append(verfluchtdachs)

	var verfluchtbock := _archetype(&"verfluchtbock", Loc.pick("Verfluchter Bock", "Cursed Buck"),
		[Enums.Biome.FOREST],
		_stats(10, 4, 8, 4, 6, 3), _stats(1, 1, 2, 1, 1, 0), 4, 5,
		[_skill("Verfluchthufschlag", [&"src_weapon", &"elem_dark"]),
			_skill("Hufstampfer", [&"src_spell", &"form_aoe"])], 2, true,
		Enums.Temperament.AGGRESSIVE, 6)
	verfluchtbock.sprite_scale = 1.3
	verfluchtbock.variant_group = &"bestie"
	list.append(verfluchtbock)

	# Familie 2: Pilz-Hexenzirkel
	var pilzhexe := _archetype(&"pilzhexe", Loc.pick("Pilzhexe", "Mushroom Witch"),
		[Enums.Biome.FOREST],
		_stats(3, 10, 4, 8, 3, 2), _stats(1, 0, 1, 1, 1, 0), 1, 3,
		[_skill("Pilzsporen", [&"src_spell", &"elem_poison", &"form_aoe"])], 1, false,
		Enums.Temperament.SKITTISH, 3)
	pilzhexe.variant_group = &"humanoid"
	list.append(pilzhexe)

	var pilzkrabbel := _archetype(&"pilzkrabbel", Loc.pick("Pilzkrabbel", "Mushroom Crawler"),
		[Enums.Biome.FOREST],
		_stats(7, 0, 8, 2, 9, 2), _stats(1, 0, 1, 1, 2, 0), 2, 3,
		[_skill("Pilzkrallen", [&"src_weapon", &"tech_blutung"])], 1, false,
		Enums.Temperament.AGGRESSIVE, 4)
	pilzkrabbel.calls_reinforcements = true
	pilzkrabbel.variant_group = &"bestie"
	list.append(pilzkrabbel)

	var pilzstamm := _archetype(&"pilzstamm", Loc.pick("Pilzstamm", "Mushroom Trunk"),
		[Enums.Biome.FOREST],
		_stats(5, 2, 14, 4, 3, 2), _stats(1, 1, 2, 1, 1, 0), 4, 5,
		[_skill("Stammhieb", [&"src_weapon", &"mod_wucht"]),
			_skill("Pilzpanzer", [&"src_spell", &"form_self", &"eff_def_up"])], 2, false,
		Enums.Temperament.TERRITORIAL, 5)
	list.append(pilzstamm)

	var hexenmeisterin := _archetype(&"hexenmeisterin", Loc.pick("Hexenmeisterin", "Witch Mistress"),
		[Enums.Biome.FOREST],
		_stats(3, 14, 7, 9, 5, 3), _stats(1, 2, 1, 1, 1, 0), 3, 5,
		[_skill("Verfluchter Pilz", [&"src_spell", &"elem_dark", &"eff_lifesteal"]),
			_skill("Hexenfeuer", [&"src_spell", &"elem_fire", &"form_aoe"])], 2, true,
		Enums.Temperament.AGGRESSIVE, 7)
	hexenmeisterin.sprite_scale = 1.3
	hexenmeisterin.variant_group = &"humanoid"
	list.append(hexenmeisterin)

	var daemonenkoenig := _archetype(&"demonenkonig", Loc.pick("Dämonen-König", "Demon King"),
		[Enums.Biome.CRYPT],
		_stats(10, 16, 12, 10, 8, 4), _stats(1, 1, 2, 1, 1, 0), 5, 6,
		[_skill("Dämonenfeuer", [&"src_spell", &"elem_fire", &"form_aoe"]),
			_skill("Dunkelschlag", [&"src_weapon", &"elem_dark", &"eff_slow"])], 2, true,
		Enums.Temperament.AGGRESSIVE, 8)
	daemonenkoenig.undead = true
	daemonenkoenig.boss_only = true
	daemonenkoenig.variant_group = &"humanoid"
	list.append(daemonenkoenig)

	for archetype in list:
		assert(not _archetypes.has(archetype.id), "Doppelte Archetyp-ID: %s" % archetype.id)
		_archetypes[archetype.id] = archetype
		var klasse: Array = RUESTUNGSKLASSEN.get(archetype.id, [Enums.ArmorClass.NONE, 0])
		archetype.armor_class = klasse[0]
		archetype.armor = maxi(archetype.armor, int(klasse[1]))
		var faktoren: Dictionary = SCHWAECHEN.get(archetype.id, {})
		for element in faktoren:
			archetype.element_faktoren[element] = faktoren[element]


## Rüstungsklassen der Gegner (Lutz 2026-10-16) — wie die Elementschwächen
## für Zauber: die Waffenwahl soll gegen Gegner zählen. [Klasse, Mindest-
## Rüstungspunkte] — auf 0 Punkten würde die Klasse nichts bewirken.
##   Fell: Stich gut (Bogen, Dolch, Armbrust)  · Knochen: Stumpf gut, Stich schlecht
##   Kette: Stich/Stumpf gut, Hieb schlecht    · Platte: Stumpf gut, Hieb/Stich schlecht
const RUESTUNGSKLASSEN := {
	&"wolf": [Enums.ArmorClass.FELL, 1], &"baer": [Enums.ArmorClass.FELL, 2],
	&"troll": [Enums.ArmorClass.FELL, 3], &"fledermaus": [Enums.ArmorClass.FELL, 1],
	&"verfluchtkatz": [Enums.ArmorClass.FELL, 1], &"verfluchtdachs": [Enums.ArmorClass.FELL, 3],
	&"verfluchtbock": [Enums.ArmorClass.FELL, 4], &"schattenbestie": [Enums.ArmorClass.FELL, 2],
	&"skelett": [Enums.ArmorClass.KNOCHEN, 3], &"toddiener": [Enums.ArmorClass.KNOCHEN, 2],
	&"schattenkrieger": [Enums.ArmorClass.CHAIN, 3], &"todesmeister": [Enums.ArmorClass.CHAIN, 4],
	&"demonenjager": [Enums.ArmorClass.CHAIN, 2], &"kleindaemon": [Enums.ArmorClass.CHAIN, 1],
	&"golem": [Enums.ArmorClass.PLATE, 5], &"mimic": [Enums.ArmorClass.PLATE, 3],
	&"spinne": [Enums.ArmorClass.PLATE, 2], &"pilzkrabbel": [Enums.ArmorClass.PLATE, 2],
	&"pilzstamm": [Enums.ArmorClass.PLATE, 4], &"verfluchtigel": [Enums.ArmorClass.PLATE, 2],
	&"demonenkonig": [Enums.ArmorClass.PLATE, 5],
	&"bandit": [Enums.ArmorClass.LEATHER, 1], &"kultist": [Enums.ArmorClass.LEATHER, 0],
	&"nekromant": [Enums.ArmorClass.LEATHER, 1], &"hexenmeisterin": [Enums.ArmorClass.LEATHER, 3],
	&"pilzhexe": [Enums.ArmorClass.LEATHER, 1], &"demonenbeschwoerer": [Enums.ArmorClass.LEATHER, 2],
}


## Element-Schwächen (×1.5) und -Resistenzen (×0.5) je Grundtyp — Spieler
## entdecken sie im Kampf (Chips am Gegner, Bestiarium). Untote nehmen
## Heilig ohnehin ×1.5 (Battle.HOLY_UNDEAD_BONUS) und stehen hier nicht
## nochmal als heilig-schwach.
const _F := Enums.Element.FIRE
const _E := Enums.Element.ICE
const _B := Enums.Element.LIGHTNING
const _G := Enums.Element.POISON
const _H := Enums.Element.HOLY
const _D := Enums.Element.DARK
const SCHWAECHEN := {
	&"wolf": {_F: 1.5, _E: 0.5},
	&"bandit": {_G: 1.5},
	&"mimic": {_B: 1.5, _G: 0.5},
	&"baer": {_F: 1.5, _E: 0.5},
	&"schleim": {_F: 1.5, _G: 0.5},
	&"schleimstapel": {_F: 1.5, _G: 0.5},
	&"koenigschleim": {_F: 1.5, _G: 0.5},
	&"schleimgott": {_B: 1.5, _G: 0.5},
	&"fledermaus": {_B: 1.5, _D: 0.5},
	&"spinne": {_F: 1.5, _G: 0.5},
	&"golem": {_B: 1.5, _G: 0.5, _F: 0.5},
	&"troll": {_F: 1.5, _E: 0.5},
	&"skelett": {_G: 0.5, _E: 0.5},
	&"kultist": {_D: 0.5, _B: 1.5},
	&"geist": {_G: 0.5, _D: 0.5},
	&"nekromant": {_D: 0.5, _F: 1.5},
	&"schattenbestie": {_H: 1.5, _D: 0.5},
	&"toddiener": {_G: 0.5, _F: 1.5},
	&"leichenfresser": {_G: 0.5, _F: 1.5},
	&"schattenkrieger": {_D: 0.5, _B: 1.5},
	&"todesmeister": {_D: 0.5, _E: 0.5},
	&"kleindaemon": {_F: 0.5, _E: 1.5},
	&"demonenjager": {_F: 0.5, _E: 1.5},
	&"demonenbeschwoerer": {_F: 0.5, _E: 1.5},
	&"verfluchtkatz": {_H: 1.5, _D: 0.5},
	&"verfluchtigel": {_F: 1.5, _G: 0.5},
	&"verfluchtdachs": {_E: 1.5, _D: 0.5},
	&"verfluchtbock": {_H: 1.5, _D: 0.5},
	&"pilzhexe": {_F: 1.5, _G: 0.5},
	&"pilzkrabbel": {_F: 1.5, _G: 0.5},
	&"pilzstamm": {_F: 1.5, _B: 0.5},
	&"hexenmeisterin": {_H: 1.5, _G: 0.5},
	&"demonenkonig": {_F: 0.5, _D: 0.5},
}


# --- Kombo-Skills (Skillbau 3.0 für Gegner) -------------------------------------
# Jeder Grundtyp kann zusätzlich einen Skill aus den neuen Grundbausteinen
# bekommen — passend zu ihm: Wölfe beißen im Rudel nach, Spinnen lähmen,
# Priester-Schleime heilen, Golems schlagen mit Wucht. [Name DE, Name EN,
# Klötze, ab Kartenstufe]. Normale Gegner würfeln einen der verfügbaren,
# Bosse bekommen alle.
const KOMBOS := {
	&"wolf": [["Rudelbiss", "Pack bite", [&"src_weapon", &"mod_nachsetzen"], 1],
		["Kehlbiss", "Throat bite", [&"src_weapon", &"tech_blutung"], 4]],
	&"bandit": [["Hinterhältiger Stich", "Dirty stab", [&"src_weapon", &"mod_ausnutzen"], 2],
		["Messersalve", "Knife volley", [&"src_weapon", &"mod_treffer", &"mod_treffer", &"mod_ziel_zufall"], 5]],
	&"mimic": [["Verschlingen", "Devour", [&"src_weapon", &"mod_wucht", &"eff_lifesteal"], 1]],
	&"baer": [["Zermalmender Prankenhieb", "Crushing maul", [&"src_weapon", &"mod_wucht"], 2],
		["Brüllen", "Roar", [&"src_spell", &"tech_kriegsschrei"], 5]],
	&"schleim": [["Klebschleim", "Sticky slime", [&"src_spell", &"elem_poison", &"eff_slow"], 3]],
	&"schleimstapel": [["Schleimregen", "Slime rain", [&"src_spell", &"elem_poison", &"mod_treffer", &"mod_treffer", &"mod_ziel_zufall"], 4]],
	&"koenigschleim": [["Königliche Gnade", "Royal mercy", [&"src_spell", &"elem_holy", &"form_aura"], 1]],
	&"schleimgott": [["Urschleim-Segen", "Primordial blessing", [&"src_spell", &"elem_holy", &"form_aura"], 1],
		["Ursuppe", "Primordial soup", [&"src_spell", &"elem_poison", &"form_aoe", &"mod_aufladen"], 1]],
	&"fledermaus": [["Blutsaugen", "Blood suck", [&"src_weapon", &"eff_lifesteal"], 1],
		["Flattersturm", "Flutter storm", [&"src_weapon", &"mod_treffer", &"mod_ziel_wechsel"], 3]],
	&"spinne": [["Lähmbiss", "Paralytic bite", [&"src_weapon", &"tech_laehmgift"], 2],
		["Giftfalle", "Venom trap", [&"src_spell", &"elem_poison", &"mod_ausnutzen"], 5]],
	&"golem": [["Steinhaut", "Stone skin", [&"src_spell", &"form_self", &"eff_def_up"], 1],
		["Erdbeben", "Earthquake", [&"src_weapon", &"form_aoe", &"mod_wucht"], 4],
		["Granitwall", "Granite wall", [&"src_spell", &"form_self", &"eff_elementschutz"], 20]],
	&"troll": [["Trollzorn", "Troll fury", [&"src_weapon", &"mod_rache"], 1],
		["Keulenwirbel", "Club whirl", [&"src_weapon", &"form_aoe"], 3]],
	&"skelett": [["Knochensplitter", "Bone shards", [&"src_weapon", &"mod_treffer", &"mod_ziel_zufall"], 3],
		["Panzerbrecher", "Armor breaker", [&"src_weapon", &"tech_ruestungsriss"], 5]],
	&"kultist": [["Dunkle Weihe", "Dark rite", [&"src_spell", &"form_aura", &"eff_atk_up"], 2],
		["Blutopfer", "Blood sacrifice", [&"src_spell", &"elem_dark", &"mod_blutpreis", &"mod_wucht"], 4],
		["Rostfluch", "Rust curse", [&"src_spell", &"eff_ruestung_schwaechen"], 10]],
	&"geist": [["Klagelied", "Wail", [&"src_spell", &"tech_rauchbombe"], 3],
		["Seelenkälte", "Soul chill", [&"src_spell", &"elem_ice"], 2]],
	&"nekromant": [["Lebensentzug", "Life drain", [&"src_spell", &"elem_dark", &"eff_lifesteal"], 1],
		["Knochenschild", "Bone shield", [&"src_spell", &"form_aura", &"eff_shield"], 4]],
	&"schattenbestie": [["Schattensprung", "Shadow pounce", [&"src_weapon", &"mod_flinkheit", &"mod_ausnutzen"], 1]],
	&"toddiener": [["Todesgriff", "Death grip", [&"src_weapon", &"mod_execute"], 1]],
	&"leichenfresser": [["Wunden reißen", "Rend wounds", [&"src_weapon", &"tech_blutung"], 1]],
	&"schattenkrieger": [["Schattenschild", "Shadow shield", [&"src_spell", &"form_self", &"eff_shield"], 1],
		["Klingenwirbel", "Blade whirl", [&"src_weapon", &"mod_treffer", &"mod_treffer", &"mod_ziel_wechsel"], 1]],
	&"todesmeister": [["Todesurteil", "Death sentence", [&"src_spell", &"elem_dark", &"mod_execute"], 1],
		["Seelenernte", "Soul harvest", [&"src_spell", &"elem_dark", &"form_aoe", &"mod_aufladen"], 1],
		["Seelenbann", "Soul ward", [&"src_spell", &"form_aura", &"eff_magieschild"], 15]],
	&"kleindaemon": [["Funkenregen", "Spark rain", [&"src_spell", &"elem_fire", &"mod_treffer", &"mod_ziel_zufall"], 1]],
	&"demonenjager": [["Gezielter Hieb", "Aimed strike", [&"src_weapon", &"mod_praezision"], 1]],
	&"demonenbeschwoerer": [["Höllenpakt", "Infernal pact", [&"src_spell", &"form_aura", &"eff_atk_up"], 1],
		["Entzünden", "Ignite", [&"src_spell", &"elem_fire", &"mod_entzuenden"], 1]],
	&"verfluchtkatz": [["Krallenhagel", "Claw hail", [&"src_weapon", &"mod_treffer", &"mod_treffer", &"mod_ziel_zufall"], 1]],
	&"verfluchtigel": [["Stachelpanzer", "Spine armor", [&"src_spell", &"form_self", &"tech_vergeltung"], 1]],
	&"verfluchtdachs": [["Wühlbiss", "Burrowing bite", [&"src_weapon", &"mod_wucht"], 1]],
	&"verfluchtbock": [["Sturmangriff", "Charge", [&"src_weapon", &"mod_flinkheit"], 1]],
	&"pilzhexe": [["Heilsporen", "Healing spores", [&"src_spell", &"elem_holy", &"form_aura"], 1],
		["Schlafsporen", "Sleep spores", [&"src_spell", &"elem_poison", &"eff_slow"], 1]],
	&"pilzkrabbel": [["Sporenwolke", "Spore cloud", [&"src_spell", &"elem_poison", &"form_aoe"], 3]],
	&"pilzstamm": [["Wurzelheilung", "Root mending", [&"src_spell", &"elem_holy", &"form_self"], 1]],
	&"hexenmeisterin": [["Hexenschild", "Hex shield", [&"src_spell", &"form_aura", &"eff_shield"], 1],
		["Fluchblick", "Cursed gaze", [&"src_spell", &"elem_dark", &"mod_ausnutzen"], 1],
		["Bannfluch", "Hex break", [&"src_spell", &"form_aoe", &"eff_magiebruch"], 15]],
	&"demonenkonig": [["Höllenfeuer", "Hellfire", [&"src_spell", &"elem_fire", &"form_aoe", &"mod_aufladen"], 1],
		["Königszorn", "Royal wrath", [&"src_weapon", &"mod_rache", &"mod_wucht"], 1],
		["Höllenmal", "Hellbrand", [&"src_spell", &"elem_fire", &"eff_elementschwaeche"], 20]],
}


## Kombo-Skills eines Grundtyps, die auf dieser Kartenstufe schon dran sind.
static func kombos_fuer(archetype_id: StringName, tier: int) -> Array[Skill]:
	var result: Array[Skill] = []
	for eintrag in KOMBOS.get(archetype_id, []):
		if tier >= int(eintrag[3]):
			var skill := _skill(Loc.pick(eintrag[0], eintrag[1]), eintrag[2])
			result.append(skill)
	return result


static func _build_modifiers() -> void:
	var list: Array[EnemyModifier] = []

	list.append(_modifier(&"brennend", Loc.pick("Brennend", "Burning"), 1.0, 1.0, 1.0, 0, 1.3, 1,
		_skill("Feuerhauch", [&"src_spell", &"elem_fire"])))
	list.append(_modifier(&"gepanzert", Loc.pick("Gepanzert", "Armored"), 1.2, 1.0, 1.0, 4, 1.3, 1, null))
	list.append(_modifier(&"schnell", Loc.pick("Schnell", "Swift"), 1.0, 1.1, 1.5, 0, 1.2, 1, null))
	list.append(_modifier(&"wuetend", Loc.pick("Wütend", "Raging"), 0.9, 1.4, 1.0, 0, 1.4, 2, null))
	list.append(_modifier(&"vampirisch", Loc.pick("Vampirisch", "Vampiric"), 1.0, 1.0, 1.0, 0, 1.5, 2,
		_skill("Vampirbiss", [&"src_weapon", &"eff_lifesteal"])))
	list.append(_modifier(&"kolossal", Loc.pick("Kolossal", "Colossal"), 1.8, 1.0, 0.8, 0, 1.6, 3, null))
	# Anführer-Affixe (Lutz 2026-10-16): stärken jeden Zug die ganze Gruppe —
	# zuerst ausschalten oder entzaubern! Dafür mehr Beute und Erfahrung.
	list.append(_aura(&"bannertraeger", Loc.pick("Bannerträger", "Standard-bearer"),
		Enums.Status.ATK_UP, 20, 5))
	list.append(_aura(&"schutzherr", Loc.pick("Schutzherr", "Warden"), Enums.Status.DEF_UP, 30, 8))
	list.append(_aura(&"bannwirker", Loc.pick("Bannwirker", "Spellwarden"), Enums.Status.MAGIE_SCHUTZ, 25, 12))
	list.append(_aura(&"lebensquell", Loc.pick("Lebensquell", "Wellspring"), Enums.Status.REGEN, 4, 15))

	for modifier in list:
		assert(not _modifiers.has(modifier.id), "Doppelte Modifikator-ID: %s" % modifier.id)
		_modifiers[modifier.id] = modifier


# --- Fabrik-Helfer -------------------------------------------------------------

static func _archetype(id: StringName, name: String, biomes: Array[Enums.Biome],
		base_stats: StatBlock, per_tier: StatBlock, armor: int, resist: int,
		skills: Array[Skill], skill_count: int, boss: bool,
		temperament: Enums.Temperament = Enums.Temperament.AGGRESSIVE,
		unlock_tier := 1) -> EnemyArchetype:
	var archetype := EnemyArchetype.new()
	archetype.id = id
	archetype.display_name = name
	archetype.biomes = biomes
	archetype.base_stats = base_stats
	archetype.stats_per_tier = per_tier
	archetype.armor = armor
	archetype.magic_resist = resist
	archetype.skill_pool = skills
	archetype.skill_count = skill_count
	archetype.is_boss_capable = boss
	archetype.temperament = temperament
	archetype.unlock_tier = unlock_tier
	return archetype


static func _modifier(id: StringName, name: String, hp_mult: float, dmg_mult: float,
		speed_mult: float, armor_bonus: int, loot_mult: float, min_tier: int,
		granted_skill: Skill) -> EnemyModifier:
	var modifier := EnemyModifier.new()
	modifier.id = id
	modifier.display_name = name
	modifier.hp_multiplier = hp_mult
	modifier.damage_multiplier = dmg_mult
	modifier.speed_multiplier = speed_mult
	modifier.armor_bonus = armor_bonus
	modifier.loot_multiplier = loot_mult
	modifier.min_tier = min_tier
	modifier.granted_skill = granted_skill
	return modifier


const AURA_BEUTE := 1.5
const AURA_XP := 1.5


static func _aura(id: StringName, name: String, status: Enums.Status, potency: int,
		min_tier: int) -> EnemyModifier:
	var modifier := _modifier(id, name, 1.1, 1.0, 1.0, 0, AURA_BEUTE, min_tier, null)
	modifier.xp_multiplier = AURA_XP
	modifier.aura_status = status
	modifier.aura_potency = potency
	return modifier


static func _skill(name: String, block_ids: Array) -> Skill:
	var skill := Skill.new()
	skill.display_name = name
	for id in block_ids:
		var block := BlockLibrary.get_block(id)
		assert(block != null, "Unbekannter Baustein: %s" % id)
		skill.blocks.append(block)
	return skill


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
