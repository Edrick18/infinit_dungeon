class_name LexiconLibrary
extends RefCounted
## Das Spiel-Lexikon: JEDE Mechanik nachlesbar, ordentlich kategorisiert,
## zweisprachig (DE/EN). Inhalte leben hier als Daten — die Lexikon-Szene
## rendert sie nur. Neue Mechanik eingebaut? Hier den Eintrag ergänzen!


static func categories() -> Array[Dictionary]:
	return [
		{"id": &"kampf", "title": Loc.pick("Kampf", "Combat")},
		{"id": &"gegner", "title": Loc.pick("Gegner & Bosse", "Enemies & Bosses")},
		{"id": &"dungeon", "title": Loc.pick("Dungeons & Karten", "Dungeons & Maps")},
		{"id": &"items", "title": Loc.pick("Items & Loot", "Items & Loot")},
		{"id": &"helden", "title": Loc.pick("Helden & Skills", "Heroes & Skills")},
		{"id": &"hub", "title": Loc.pick("Hub & Wirtschaft", "Hub & Economy")},
		{"id": &"bestiarium", "title": Loc.pick("Bestiarium", "Bestiary")},
	]


static func entries(category: StringName) -> Array[Dictionary]:
	if category == &"bestiarium":
		return _bestiary_entries()
	var result: Array[Dictionary] = []
	for entry in _ALL:
		if entry["cat"] == category:
			result.append({
				"title": Loc.pick(entry["t_de"], entry["t_en"]),
				"body": Loc.pick(entry["b_de"], entry["b_en"]),
			})
	return result


## Bestiarium: dynamisch aus den Kills des Spielstands — besiegte Grundtypen
## zeigen ihre Daten, unbekannte bleiben „???" (Entdecker-Meta).
static func _bestiary_entries() -> Array[Dictionary]:
	var state: Node = null
	if Engine.get_main_loop() is SceneTree:
		state = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameState")
	var archetypes := EnemyLibrary.all_archetypes()
	archetypes.sort_custom(func(a: EnemyArchetype, b: EnemyArchetype) -> bool:
		return a.unlock_tier < b.unlock_tier)
	var discovered := 0
	var result: Array[Dictionary] = []
	for archetype in archetypes:
		var kills: int = state.kills_of(archetype.id) if state != null else 0
		if kills > 0:
			discovered += 1
			result.append({
				"title": "%s  (×%d)" % [archetype.display_name, kills],
				"body": _bestiary_body(archetype, kills, state),
			})
		else:
			result.append({
				"title": "???",
				"body": Loc.pick(
					"Noch nicht entdeckt.\nBesiege diesen Gegner, um seinen Eintrag freizuschalten. (Erster Fundort: ab Kartenstufe %d)",
					"Not yet discovered.\nDefeat this enemy to unlock its entry. (First found: from map tier %d)")
					% archetype.unlock_tier,
			})
	result.push_front({
		"title": Loc.pick("Fortschritt: %d/%d entdeckt", "Progress: %d/%d discovered")
			% [discovered, archetypes.size()],
		"body": Loc.pick(
			"Jeder besiegte Grundtyp schaltet seinen Eintrag frei. Regionen, Elemente, Klassen und Raritäten zählen zum selben Grundtyp — die Vielfalt entdeckst du im Kampf.",
			"Every defeated base type unlocks its entry. Regions, elements, classes and rarities count toward the same base type — you discover the variety in battle."),
	})
	return result


static func _bestiary_body(archetype: EnemyArchetype, kills: int, state: Node = null) -> String:
	var biome_names: Array[String] = []
	for biome in archetype.biomes:
		biome_names.append(CardFactory.biome_name(biome))
	var temperament := ""
	match archetype.temperament:
		Enums.Temperament.AGGRESSIVE:
			temperament = Loc.pick("Aggressiv (jagt dich immer)", "Aggressive (always hunts you)")
		Enums.Temperament.TERRITORIAL:
			temperament = Loc.pick("Territorial (verteidigt sein Gebiet)", "Territorial (defends its ground)")
		Enums.Temperament.SKITTISH:
			temperament = Loc.pick("Scheu (hält Abstand, flieht vor Stärkeren)", "Skittish (keeps distance, flees the strong)")
	var lines: Array[String] = [
		Loc.pick("[b]Besiegt:[/b] %d", "[b]Defeated:[/b] %d") % kills,
		Loc.pick("[b]Biome:[/b] %s", "[b]Biomes:[/b] %s")
			% (", ".join(biome_names) if not biome_names.is_empty()
				else Loc.pick("nur besondere Orte", "special places only")),
		Loc.pick("[b]Ab Kartenstufe:[/b] %d", "[b]From map tier:[/b] %d") % archetype.unlock_tier,
		Loc.pick("[b]Verhalten:[/b] %s", "[b]Behavior:[/b] %s") % temperament,
	]
	if archetype.undead:
		lines.append(Loc.pick("[b]Untot[/b] — Heilig trifft ×1,5!", "[b]Undead[/b] — holy hits ×1.5!"))
	lines.append(_element_zeile(archetype, state))
	var eigenheit := Eigenheiten.fuer(archetype.id)
	if eigenheit != &"":
		if state != null and state.kennt_eigenheit(String(archetype.id)):
			lines.append(Loc.pick("[b]Eigenheit — %s:[/b] %s", "[b]Trait — %s:[/b] %s")
				% [Eigenheiten.name_von(eigenheit), Eigenheiten.text_von(eigenheit)])
		else:
			lines.append(Loc.pick("[b]Eigenheit:[/b] ? (unentdeckt)", "[b]Trait:[/b] ? (undiscovered)"))
	if archetype.is_boss_capable:
		lines.append(Loc.pick("[b]Boss-fähig[/b] — kann als Kartenboss auftreten.",
			"[b]Boss-capable[/b] — can appear as a map boss."))
	if archetype.calls_reinforcements:
		lines.append(Loc.pick("Ruft Verstärkung der eigenen Art!", "Calls reinforcements of its kind!"))
	if archetype.variant_group != &"":
		lines.append(Loc.pick("Tritt in mehreren Klassen/Sorten auf.",
			"Appears in multiple classes/kinds."))
	return "\n".join(lines)


## Element-Wissen im Bestiarium: entdeckte Schwächen (▲) und Resistenzen (▼),
## der Rest bleibt ? — man lernt sie nur im Kampf.
static func _element_zeile(archetype: EnemyArchetype, state: Node) -> String:
	if archetype.element_faktoren.is_empty():
		return Loc.pick("[b]Elemente:[/b] keine besonderen Schwächen oder Resistenzen",
			"[b]Elements:[/b] no particular weaknesses or resistances")
	var teile: Array[String] = []
	var offen := 0
	for element in archetype.element_faktoren:
		if state == null or not state.kennt_element(String(archetype.id), int(element)):
			offen += 1
			continue
		var name := BlockLibrary.element_block(int(element)).display_name
		teile.append(("▲ " if archetype.element_faktoren[element] > 1.0 else "▼ ") + name)
	if offen > 0:
		teile.append(Loc.pick("? (%d unentdeckt)", "? (%d undiscovered)") % offen)
	return Loc.pick("[b]Elemente:[/b] %s", "[b]Elements:[/b] %s") % "  ·  ".join(teile)


static func all_entries() -> Array[Dictionary]:
	return _ALL


# Format: cat, t_de/t_en (Titel), b_de/b_en (BBCode-Fließtext).
static var _ALL: Array[Dictionary] = [
	# ============================== KAMPF ==================================
	{"cat": &"kampf", "t_de": "Schadensberechnung", "t_en": "Damage calculation",
	"b_de": "[b]Physisch:[/b] (Waffenschaden + Stärke × Skalierung) − Rüstung. Der Schaden verteilt sich gleichmäßig auf die Schadensarten der Waffe (z.B. Schwert: halb Stich, halb Schnitt), und jede Portion wird einzeln gegen die passende Rüstung gemindert.\n[b]Magisch:[/b] (Zauberkraft + Intelligenz × Skalierung) − Magieresistenz.\nJeder Treffer macht mindestens 1 Schaden.\n[b]Kritische Treffer:[/b] 5% + Glücksbonus (wächst mit Glück, flacht ab, höchstens +45%), Schaden ×1,5.\n[b]Durchdringung[/b] (Armbrust, Durchdringungs-Baustein) ignoriert einen Prozentsatz der Rüstung/Resistenz.\nDie Schadensvorschau bei der Zielwahl nutzt exakt diese Formeln (ohne Krit).",
	"b_en": "[b]Physical:[/b] (weapon damage + strength × scaling) − armor. Damage is split evenly across the weapon's damage types (e.g. sword: half pierce, half slash), and each portion is mitigated by the matching armor separately.\n[b]Magical:[/b] (spell power + intelligence × scaling) − magic resist.\nEvery hit deals at least 1 damage.\n[b]Critical hits:[/b] 5% + luck bonus (grows with luck, levels off, at most +45%), damage ×1.5.\n[b]Piercing[/b] (crossbow, pierce block) ignores a percentage of armor/resist.\nThe damage preview during targeting uses exactly these formulas (without crits)."},

	{"cat": &"kampf", "t_de": "Schadensarten & Rüstungsklassen", "t_en": "Damage types & armor classes",
	"b_de": "Drei physische Schadensarten: [b]Stich, Schnitt, Stumpf[/b]. Die Waffe bestimmt das Profil (Schwert = Stich+Schnitt, Axt = Schnitt, Hammer = Stumpf, Bogen/Dolch = Stich).\nRüstungsklassen wirken unterschiedlich:\n• [b]Leder:[/b] neutral gegen alles\n• [b]Kette:[/b] stark gegen Schnitt (×1,5), schwach gegen Stich/Stumpf (×0,75)\n• [b]Platte:[/b] stark gegen Schnitt (×1,5) und Stich (×1,25), aber Stumpf halbiert den Schutz (×0,5) — [b]Hämmer knacken Platte![/b]\n• [b]Roben:[/b] kaum Rüstung, dafür Zauberkraft.\n[b]Gegner tragen auch Klassen:[/b] [b]Fell[/b] (Wolf, Bär, Troll …: Stich geht durch, ×0,6), [b]Knochen[/b] (Skelette: Stumpf zertrümmert ×0,5, Stich rutscht ab ×1,5), [b]Kette[/b] (Schattenkrieger, Todesmeister …), [b]Platte[/b] (Golem, Spinne, Dämonenkönig …). Die Anzeige unter dem Gegner nennt die Schadensart, die am besten durchgeht (▲).\n[b]Rüstung mindert prozentual:[/b] Minderung = Rüstung ÷ (Rüstung + K), K wächst mit dem Level des Angreifers, höchstens 90 %. Ein schwer gerüsteter Tank mindert auf gleichem Level etwa die Hälfte — nie alles.\n[b]Magieschutz:[/b] Rüstungsteile schützen auch vor Zaubern — Roben am meisten (×4 ihrer Rüstung), Leder ×1,2, Kette ×0,6, Platte am wenigsten (×0,4).",
	"b_en": "Three physical damage types: [b]pierce, slash, blunt[/b]. The weapon sets the profile (sword = pierce+slash, axe = slash, hammer = blunt, bow/dagger = pierce).\nArmor classes react differently:\n• [b]Leather:[/b] neutral against everything\n• [b]Chain:[/b] strong vs slash (×1.5), weak vs pierce/blunt (×0.75)\n• [b]Plate:[/b] strong vs slash (×1.5) and pierce (×1.25), but blunt halves its protection (×0.5) — [b]hammers crack plate![/b]\n• [b]Robes:[/b] barely any armor, but grant spell power.\n[b]Enemies wear classes too:[/b] [b]hide[/b] (wolf, bear, troll …: pierce gets through, ×0.6), [b]bone[/b] (skeletons: blunt shatters ×0.5, pierce glances off ×1.5), [b]chain[/b] (shadow warriors, death masters …), [b]plate[/b] (golem, spider, demon king …). The line under each enemy names the damage type that gets through best (▲).\n[b]Armor reduces by percent:[/b] reduction = armor ÷ (armor + K), K grows with the attacker's level, at most 90%. A heavily armored tank reduces about half at equal level — never everything.\n[b]Magic ward:[/b] armor pieces also protect against spells — robes the most (×4 their armor), leather ×1.2, chain ×0.6, plate the least (×0.4)."},

	{"cat": &"kampf", "t_de": "Elemente & ihre Signaturen", "t_en": "Elements & their signatures",
	"b_de": "Jedes Element spielt sich eigen:\n• [b]Feuer:[/b] baut Brand-Stacks auf. Brand macht Schaden in Höhe der Stacks, danach halbieren sie sich — hoher Burst, klingt ab.\n• [b]Gift:[/b] weniger Stacks, aber PERMANENT bis zur Heilung (Gegengift/Allheilmittel).\n• [b]Eis:[/b] friert ein (Ziel setzt aus; der nächste physische Treffer zerschmettert das Eis: ×1,5 Schaden) oder verlangsamt.\n• [b]Blitz:[/b] springt auf ein weiteres Ziel über (50% Schaden), Chance auf Betäubung.\n• [b]Heilig:[/b] ×1,5 gegen Untote; auf Verbündete gewirkt wird der Schaden zu HEILUNG.\n• [b]Dunkel:[/b] raubt 30% des Schadens als Leben und verflucht (Ziel erleidet mehr Schaden).\n[b]Element-Resistenz[/b] (aus Loot-Affixen) mindert Elementschaden flach — und reduziert dadurch auch den Stack-Aufbau.",
	"b_en": "Every element plays differently:\n• [b]Fire:[/b] builds burn stacks. Burn deals damage equal to its stacks, then they halve — big burst, fades fast.\n• [b]Poison:[/b] fewer stacks, but PERMANENT until cured (antidote/panacea).\n• [b]Ice:[/b] freezes (target skips turns; the next physical hit shatters the ice for ×1.5 damage) or slows.\n• [b]Lightning:[/b] chains to another target (50% damage), chance to stun.\n• [b]Holy:[/b] ×1.5 vs undead; cast on allies, the damage becomes HEALING.\n• [b]Dark:[/b] steals 30% of damage dealt as life and curses (target takes increased damage).\n[b]Elemental resistance[/b] (from loot affixes) reduces elemental damage flat — which also reduces stack build-up."},

	{"cat": &"kampf", "t_de": "Buffs & Debuffs (alle Statuseffekte)", "t_en": "Buffs & debuffs (all status effects)",
	"b_de": "[b]Buffs:[/b]\n• Gestärkt (ATK_UP): +% Schaden\n• Gewappnet (DEF_UP): +% Rüstung\n• Magieschild: −25 % Magieschaden • Elementschutz: −25 % Elementschaden (auch Brand/Gift)\n• Regeneration: heilt % der Max-HP am Zugbeginn\n• Mana-Fluss: % der Max-MP am Zugbeginn\n• Schild: absorbiert Schaden in Höhe von % der Max-HP, bis er aufgebraucht ist\n• Verteidigt (GUARD): −50% Schaden bis zum nächsten Zug\n• Beschützer (PROTECT/Schutzwall): fängt alle Angriffe auf Verbündete ab und bekommt den Schaden selbst — auch Flächenangriffe, jeder Treffer einzeln. Wirkt ab Beginn der Runde, in der er eingesetzt wird, bis zu ihrem Ende.\n• Wiederbelebung: stellt einen Gefallenen wieder her\n[b]Debuffs:[/b]\n• Geschwächt: −% Schaden • Verlangsamt: −Tempo\n• Betäubt/Eingefroren: setzt aus — [b]bricht auch Boss-Aufladungen![/b]\n• Verflucht: +% erlittener Schaden • Brand/Gift: siehe Elemente\n• Rüstung schwächen/Rüstungsriss: −% Rüstung • Magiebruch: +25 % Magieschaden\n• Elementschwäche: +25 % Schaden vom Element des Zaubers (Eis-Zauber » Eis-Schwäche)\n[b]Stufen (wie DQ9):[/b] Stärken, Wappnen, Magieschild, Elementschutz, Schwächen, Rüstungsriss, Verlangsamen, Magiebruch und Elementschwäche lassen sich [b]zweimal[/b] stapeln — der zweite Zauber verdoppelt die Wirkung (Anzeige „II“) und frischt die Dauer auf, jeder weitere frischt nur noch auf. Obergrenzen: Stärken 60 %, Wappnen 100 %, Schilde 50 %.\nStatuseffekte ticken am Zugbeginn und laufen (außer Gift) nach ihrer Dauer ab. Kur-Tränke entfernen je ein Leiden, das Allheilmittel alle.",
	"b_en": "[b]Buffs:[/b]\n• Strengthened (ATK_UP): +% damage\n• Braced (DEF_UP): +% armor\n• Regeneration: heals % of max HP at turn start\n• Mana flow: % of max MP at turn start\n• Shield: absorbs damage worth % of max HP until depleted\n• Guarding: −50% damage until your next turn\n• Protector (guardian wall): intercepts all attacks on allies and takes the damage itself — AoE included, every hit separately. Active from the start of the round it is used in until that round ends.\n• Revive: restores a fallen ally\n[b]Debuffs:[/b]\n• Weakened: −% damage • Slowed: −speed\n• Stunned/Frozen: skip turn — [b]also breaks boss charge-ups![/b]\n• Cursed: +% damage taken • Burn/Poison: see Elements\nStatus effects tick at turn start and expire after their duration (except poison). Cure potions remove one ailment each, the panacea removes all."},

	{"cat": &"kampf", "t_de": "Konzentrieren (Fokus)", "t_en": "Focus (psyche up)",
	"b_de": "Die Aktion [b]Konzentrieren[/b] opfert den Zug: dein nächster Angriff macht +50% Schaden. Mehrfach konzentrieren stapelt bis +200% — ein riesiger Burst, aber jeder Aufbau-Zug ist ein Zug ohne Schaden und Heilung.\nDie Konzentration wird beim nächsten offensiven Einsatz verbraucht (Heil-/Support-Skills verbrauchen sie nicht).\nPerfektes Timing: Während der Boss seinen Spezialangriff auflädt, lädst du mit — oder du brichst seine Aufladung per Betäubung.",
	"b_en": "The [b]Focus[/b] action sacrifices your turn: your next attack deals +50% damage. Focusing repeatedly stacks up to +200% — a huge burst, but every build-up turn is a turn without damage or healing.\nFocus is consumed by your next offensive action (healing/support skills don't consume it).\nPerfect timing: while the boss charges its special attack, you charge too — or you break its charge with a stun."},

	{"cat": &"kampf", "t_de": "Zugreihenfolge & Tempo", "t_en": "Turn order & speed",
	"b_de": "Pro Runde handeln alle Kämpfer nach ihrer [b]Initiative[/b]: Tempo (= Agilität, Verlangsamung reduziert es) × ein Würfel von 0,85 bis 1,15. Wer deutlich schneller ist, handelt immer zuerst — bei knappem Vorsprung meistens, aber nicht garantiert. Die Leiste oben zeigt schon in der Befehlsphase die gewürfelte Reihenfolge: den aktuellen Kämpfer (gelber Rahmen) und die nächsten Züge — auch über das Rundenende hinaus. Grün = Party, Rot = Gegner. Tooltip zeigt Name und Tempowert.",
	"b_en": "Each round, all combatants act by [b]initiative[/b]: speed (= agility; slow reduces it) × a roll from 0.85 to 1.15. Whoever is clearly faster always goes first — with a narrow lead usually, but not guaranteed. The bar at the top already shows the rolled order during the command phase: the current combatant (yellow frame) and the upcoming turns — even beyond the end of the round. Green = party, red = enemies. The tooltip shows name and speed."},

	{"cat": &"kampf", "t_de": "Beschwörungen", "t_en": "Summons",
	"b_de": "Der Beschwörungs-Baustein erschafft einen temporären Verbündeten:\n• Zauber + Beschwörung » Wolf (physischer Angreifer)\n• Zauber + Element + Beschwörung » Elementar, der mit genau diesem Element zaubert\n• Effekt-Bausteine wirken auf die Kreatur (z.B. + Schutzwall = Wächter-Tank)\nWerte: HP = 15 + Willenskraft×5, Schaden = 60% deiner Zauberkraft. Hält 4 eigene Züge, handelt sofort, nur EINE pro Beschwörer. Beschwörungen zählen nicht für Sieg/Niederlage und geben weder XP noch Beute.",
	"b_en": "The summon block creates a temporary ally:\n• Spell + summon » wolf (physical attacker)\n• Spell + element + summon » an elemental casting exactly that element\n• Effect blocks apply to the creature (e.g. + guardian wall = tank guardian)\nStats: HP = 15 + spirit×5, damage = 60% of your spell power. Lasts 4 of its own turns, acts immediately, only ONE per summoner. Summons don't count for victory/defeat and grant no XP or loot."},

	# ============================== GEGNER =================================
	{"cat": &"kampf", "t_de": "Schwächen & Resistenzen", "t_en": "Weaknesses & resistances",
	"b_de": "Jeder Grundtyp reagiert anders auf Elemente: [b]schwach[/b] = ×1,5 Schaden (\"sehr effektiv!\"), [b]resistent[/b] = ×0,5 (\"kaum Wirkung …\"). Das gilt für jeden Elementtreffer — Zauber, Element an der Waffe, Waffen-Affixe, auch für Brand- und Gift-Stacks.\nDu [b]entdeckst[/b] sie im Kampf: Sobald ein Element eine Schwäche oder Resistenz trifft, erscheint am Gegner ein Chip (▲ schwach · ▼ resistent) — ab dann für immer bei diesem Gegnertyp und im Bestiarium.\n[b]Element-Gegner[/b] (Feuer-Wolf …) widerstehen ihrem eigenen Element und sind gegen das Gegenteil schwach: Feuer↔Eis, Blitz↔Gift, Heilig↔Dunkel. Untote nehmen Heilig ohnehin ×1,5.",
	"b_en": "Every base type reacts differently to elements: [b]weak[/b] = ×1.5 damage (\"super effective!\"), [b]resistant[/b] = ×0.5 (\"barely any effect …\"). This applies to every elemental hit — spells, elements on weapons, weapon affixes, even burn and poison stacks.\nYou [b]discover[/b] them in battle: as soon as an element hits a weakness or resistance, a chip appears on the enemy (▲ weak · ▼ resistant) — from then on forever for that enemy type and in the bestiary.\n[b]Elemental enemies[/b] (fire wolf …) resist their own element and are weak to its opposite: fire↔ice, lightning↔poison, holy↔dark. Undead take holy ×1.5 anyway."},

	{"cat": &"kampf", "t_de": "Erstschlag & Hinterhalt", "t_en": "Preemptive strike & ambush",
	"b_de": "Im Dungeon zählt, wer wem den Rücken zeigt:\n• [b]Erstschlag:[/b] Du berührst einen Gegner von HINTEN » in Runde 1 handelt nur deine Party.\n• [b]Hinterhalt:[/b] Ein Verfolger erwischt dich von hinten (du läufst weg) » in Runde 1 handeln nur die Gegner, du wählst keine Befehle.\n• Mimics schnappen immer aus dem Hinterhalt zu.\nRuhende Gegner sehen nur nach vorn — schleich dich an! Fliehende schwache Gegner (ab 8 Level Vorsprung) ergeben sich bei Berührung sofort.",
	"b_en": "In the dungeon it matters who shows whom their back:\n• [b]Preemptive strike:[/b] you touch an enemy from BEHIND » in round 1 only your party acts.\n• [b]Ambush:[/b] a pursuer catches you from behind (you're running away) » in round 1 only the enemies act and you pick no commands.\n• Mimics always ambush.\nResting enemies only look ahead — sneak up on them! Weak fleeing enemies (8-level lead) surrender instantly on touch."},

	{"cat": &"gegner", "t_de": "Geschichtete Gegner-Generierung", "t_en": "Layered enemy generation",
	"b_de": "Jeder Gegner entsteht aus fünf Schichten:\n[b]Grundtyp[/b] (Wolf, Skelett, Schleim … — der Pool wächst mit der Kartenstufe) × [b]Region[/b] (Wald- flink, Höhlen- zäh, Ruinen- gepanzert, Krypta- magisch) × [b]Element[/b] (Elementangriff + Resistenz, ab Stufe 2) × [b]Klasse[/b] (Humanoide: Krieger/Bogenschütze/Magier/Beschwörer; Schleime: Metall/Gift/Heil — ab Stufe 2) × [b]Rarität[/b] (Normal » Elite mit Karten-Modifikator » Champion ab Stufe 5: ×1,5 HP, doppelte Beute).\nBeispiel: „Champion: Krypta-Skelett-Bogenschütze (Feuer) [Schnell]\".\nDank Karten-Seed sind die Gegner derselben Karte bei jedem Besuch identisch.",
	"b_en": "Every enemy is built from five layers:\n[b]Base type[/b] (wolf, skeleton, slime … — the pool grows with map tier) × [b]region[/b] (forest- nimble, cave- tough, ruins- armored, crypt- magical) × [b]element[/b] (elemental attack + resist, from tier 2) × [b]class[/b] (humanoids: warrior/archer/mage/summoner; slimes: metal/poison/heal — from tier 2) × [b]rarity[/b] (normal » elite with a map modifier » champion from tier 5: ×1.5 HP, double loot).\nExample: \"Champion: Crypt-Skeleton-Archer (Fire) [Swift]\".\nThanks to the map seed, the same map spawns identical enemies on every visit."},

	{"cat": &"gegner", "t_de": "Boss-Mechaniken", "t_en": "Boss mechanics",
	"b_de": "Ab Kartenstufe 3 haben Bosse echte Mechaniken:\n• [b]Vernichtende Treffer:[/b] Bosse haben +10 % Krit-Chance, ihre Krits machen ×2.\n• [b]Bannwelle[/b] (ab Stufe 20): Hat die Party viele Stärkungen aufgebaut (Ø 2 Stufen pro Held) oder trägt der Boss 3 Schwächungs-Stufen, kann er alle Buffs der Helden aufheben und seine Schwächungen abschütteln — danach 5 Züge Pause.\n• [b]Phasen[/b] bei 66% und 33% HP: der Boss wird stärker und ruft Begleiter (echte Gegner — geben XP und Beute).\n• [b]Aufladung:[/b] alle 4 Züge kündigt der Boss einen verheerenden Flächenangriff an („⚡ LÄDT AUF\"). Nächster Zug: Volltreffer auf die ganze Party. Betäuben oder Einfrieren bricht die Aufladung ab.\n• [b]Kontroll-Resistenz:[/b] Betäuben und Einfrieren gelingen gegen Bosse nur mit halber Chance, und jeder Erfolg macht den Boss für den Rest des Kampfes widerstandsfähiger (+50%).\n• [b]Signatures:[/b] Bär = Wut (mehr Schaden je verwundeter) · Golem = Steinpanzer (+8 Rüstung, bis ein STUMPFER Treffer ihn sprengt) · Troll = Regeneration (8%/Runde — Brand oder Gift stoppt sie) · Kultist/Nekromant = doppelte Adds · Schattenbestie = Haltungswechsel (physisch↔magisch gepanzert, alle 3 Züge) · Schleimgott = verschlingt Schleime und wächst.",
	"b_en": "From map tier 3, bosses have real mechanics:\n• [b]Devastating blows:[/b] bosses have +10% crit chance, their crits deal ×2.\n• [b]Disruptive wave[/b] (from tier 20): if the party has built up many buffs (avg. 2 stages per hero) or the boss carries 3 debuff stages, it can dispel all heroes' buffs and shake off its debuffs — then 5 turns of rest.\n• [b]Phases[/b] at 66% and 33% HP: the boss grows stronger and calls adds (real enemies — they grant XP and loot).\n• [b]Charge-up:[/b] every 4 turns the boss telegraphs a devastating AoE (\"⚡ CHARGING\"). Next turn: full hit on the whole party. Stun or freeze cancels the charge.\n• [b]Control resistance:[/b] stun and freeze land on bosses with only half the chance, and every success makes the boss more resistant for the rest of the fight (+50%).\n• [b]Signatures:[/b] bear = rage (more damage the more wounded) · golem = stone armor (+8 armor until a BLUNT hit shatters it) · troll = regeneration (8%/round — burn or poison stops it) · cultist/necromancer = double adds · shadow beast = stance shift (physically↔magically armored, every 3 turns) · slime god = devours slimes and grows."},

	{"cat": &"gegner", "t_de": "Die Schleim-Familie", "t_en": "The slime family",
	"b_de": "Schleime stapeln sich (DQ-Prinzip): [b]3 Schleime » Schleimstapel » (2×) König-Schleim » (2×) SCHLEIMGOTT[/b]. Verschmolzene behalten die HP der Teile und tragen die gesamte Beute. Stapel, König und Gott spawnen auf hohen Stufen auch natürlich; der Schleimgott nur als Boss.\n[b]Metallschleim:[/b] fast unverwundbar (Treffer machen ~1 Schaden), nur 8 HP, flieht schnell — aber gibt die [b]8-fache Erfahrung[/b]. Ab Stufe 4.\nDazu: Giftschleim (permanente Gift-Stacks) und Heilschleim (heilt seine Gruppe).",
	"b_en": "Slimes stack (DQ style): [b]3 slimes » slime stack » (2×) king slime » (2×) SLIME GOD[/b]. Merged forms keep the parts' HP and carry all their loot. Stack, king and god also spawn naturally at high tiers; the slime god only as a boss.\n[b]Metal slime:[/b] nearly invulnerable (hits deal ~1 damage), only 8 HP, flees fast — but grants [b]8× experience[/b]. From tier 4.\nAlso: poison slime (permanent poison stacks) and heal slime (heals its group)."},

	{"cat": &"gegner", "t_de": "Sondergegner & Anführer", "t_en": "Special enemies & leaders",
	"b_de": "Manche Gegner sind besonders — erkennbar an Name und Glanz:\n• [b]Güldener[/b] (golden): Gold-Jackpot — ×6 Beute (Gold und Item-Chance), flüchtet gern.\n• [b]Strahlender[/b] (hellblau): XP-Jackpot — ×8 Erfahrung, gut gepanzert, flüchtet gern.\n• [b]Kartenhüter[/b] (Schriftrolle, ab Stufe 4): trägt eine seltene [b]Schatzkarte[/b] — episch oder legendär, 1-5 Stufen über der aktuellen Karte. Flieht nicht, ist aber zäher.\n[b]Anführer-Affixe[/b] (Elite-Eigenschaften der Karte): [b]Bannerträger[/b] (Stärken), [b]Schutzherr[/b] (Wappnen), [b]Bannwirker[/b] (Magieschild), [b]Lebensquell[/b] (Regeneration). Der Träger stärkt an jedem eigenen Zug seine ganze Gruppe — nach zwei Zügen auf Stufe 2. Nur Elite-Gegner tragen sie, Bosse nicht. Sie geben ×1,5 Beute und Erfahrung. [b]Entzaubern[/b] (Klotz ab Level 19) entfernt alle Stärkungen vom Ziel.",
	"b_en": "Some enemies are special — recognizable by name and glow:\n• [b]Gilded[/b] (golden): gold jackpot — ×6 loot (gold and item chance), likes to flee.\n• [b]Radiant[/b] (pale blue): XP jackpot — ×8 experience, well armored, likes to flee.\n• [b]Map keeper[/b] (scroll, from tier 4): carries a rare [b]treasure map[/b] — epic or legendary, 1-5 tiers above the current map. Never flees, but is tougher.\n[b]Leader affixes[/b] (elite traits of the map): [b]standard-bearer[/b] (strengthen), [b]warden[/b] (brace), [b]spellwarden[/b] (magic barrier), [b]wellspring[/b] (regeneration). The bearer empowers its whole group on each of its turns — stage 2 after two turns. Only elites carry them, never bosses. They grant ×1.5 loot and experience. [b]Dispel[/b] (block from level 19) removes all buffs from the target."},

	{"cat": &"gegner", "t_de": "Temperamente & Verstärkung", "t_en": "Temperaments & reinforcements",
	"b_de": "Im Dungeon verhalten sich Gegner nach Temperament: [b]Aggressiv[/b] jagt dich immer, [b]Territorial[/b] verteidigt sein Gebiet, [b]Scheu[/b] hält Abstand. Ist deine Party deutlich stärker als die Karte, ergreifen Scheue und Territoriale die Flucht. Ab [b]8 Level Vorsprung[/b] flieht JEDER normale Gegner — wer einen erwischt, gewinnt sofort ohne Kampf (halbe XP und halbes Gold, keine Items).\nRuhende Gegner sehen nur [b]nach vorn[/b] (plus ein kleiner Hörradius), Wände blockieren die Sicht — Anschleichen von hinten funktioniert und gibt einen [b]Erstschlag[/b]. Wer einmal jagt, verfolgt dich rundum.\nIm Kampf rufen [b]Rudeltiere[/b] (Wölfe, Kultisten) einmalig Verstärkung der eigenen Art (25% Chance, ab Stufe 3).",
	"b_en": "In the dungeon, enemies act by temperament: [b]aggressive[/b] always hunts you, [b]territorial[/b] defends its ground, [b]skittish[/b] keeps distance. If your party clearly outlevels the map, skittish and territorial enemies flee. From an [b]8-level lead[/b], EVERY normal enemy flees — catching one wins instantly without a battle (half XP and half gold, no items).\nResting enemies only look [b]ahead[/b] (plus a small hearing radius), walls block line of sight — sneaking up from behind works and grants a [b]preemptive strike[/b]. Once hunting, they track you all around.\nIn combat, [b]pack creatures[/b] (wolves, cultists) call reinforcements of their own kind once (25% chance, from tier 3)."},

	{"cat": &"gegner", "t_de": "Eigenheiten", "t_en": "Traits",
	"b_de": "Jeder normale Grundtyp hat eine [b]Eigenheit[/b] — eine eigene Regel im Kampf, z. B. [b]Körperlos[/b] (Waffentreffer machen halben Schaden), [b]Wiederkehr[/b] (steht einmal mit 30 % HP wieder auf, außer der letzte Treffer war Heilig oder stumpf) oder [b]Taschendieb[/b] (stiehlt Gold, das zurückkommt, wenn er besiegt wird).
Eine Eigenheit wird erst angezeigt, wenn sie einmal gewirkt hat: Dann steht sie im Kampflog, im Gegner-Tooltip und im Bestiarium.
Bosse haben keine Eigenheit, sondern ihre Signatur.",
	"b_en": "Every normal base type has a [b]trait[/b] — a rule of its own in battle, e.g. [b]Incorporeal[/b] (weapon hits deal half damage), [b]Reassemble[/b] (gets back up once with 30% HP unless the final hit was holy or blunt) or [b]Pickpocket[/b] (steals gold, which returns when he is defeated).
A trait is only shown once it has taken effect: then it appears in the battle log, the enemy tooltip and the bestiary.
Bosses have no trait; they have their signature instead."},

	# ============================== DUNGEON ================================
	{"cat": &"dungeon", "t_de": "Besondere Dungeons & Tresore", "t_en": "Special dungeons & vaults",
	"b_de": "Ab Stufe 3 trägt manche Karte eine [b]Sonderregel[/b] (seltene Karten öfter). Sie steht im Kartenlager und oben im Dungeon:
• [b]Elementarsturm:[/b] alle Gegner tragen ein Element, +25 % Beute.
• [b]Totenreich:[/b] alle Gegner untot, +15 % HP, +30 % Erfahrung.
• [b]Jagdgebiet:[/b] jede Gruppe hat einen Elite-Anführer, Champions doppelt so häufig, +40 % Beute.
• [b]Riesenwuchs:[/b] höchstens 2 Gegner pro Gruppe, jeder mit +80 % HP, +25 % Schaden, +80 % Erfahrung und Beute.
• [b]Manaflut:[/b] alle Skills kosten die Hälfte an MP — für Helden und Gegner.
• [b]Schatzfieber:[/b] doppelt so viele Truhen, jede vierte ist ein Mimic.
[b]Tresor:[/b] Ab Stufe 2 steht auf manchen Ebenen ein Tresor (in besonderen Dungeons öfter). Einer der Gegner der Ebene trägt den Schlüssel (goldener Schlüssel über dem Kopf) und zieht nicht weiter. Mit dem Schlüssel öffnet der Tresor: ein episches oder legendäres Item, viel Gold und eine Mini-Medaille.",
	"b_en": "From tier 3 some maps carry a [b]special rule[/b] (rarer maps more often). It is shown in map storage and at the top of the dungeon:
• [b]Elemental storm:[/b] all enemies carry one element, +25% loot.
• [b]Realm of the dead:[/b] all enemies undead, +15% HP, +30% experience.
• [b]Hunting ground:[/b] every group has an elite leader, champions twice as common, +40% loot.
• [b]Giant growth:[/b] at most 2 enemies per group, each with +80% HP, +25% damage, +80% experience and loot.
• [b]Mana flood:[/b] all skills cost half the MP — for heroes and enemies.
• [b]Treasure fever:[/b] twice as many chests, every fourth one is a mimic.
[b]Vault:[/b] from tier 2 some floors have a vault (more often in special dungeons). One enemy on the floor carries the key (golden key above its head) and never wanders off. The key opens the vault: an epic or legendary item, lots of gold and a mini medal."},

	{"cat": &"dungeon", "t_de": "Karten & Seeds (das Kartensystem)", "t_en": "Maps & seeds (the map system)",
	"b_de": "Dungeons existieren als [b]Karten[/b] (wie PoE-Maps/DQ9-Grotten): Jede Karte hat einen Seed — Layout, Gegner, Truhen und Events sind bei jedem Besuch IDENTISCH. Nur die Beute wird neu gewürfelt: perfekt zum Farmen.\nKartenstufe = Gegnerlevel. Nach dem Boss-Kill gibt es eine neue Karte auf Stufe ±3. [b]Karten-Modifikatoren[/b] (Eliten-Eigenschaften) sind fix bei Erstellung; [b]Karten-Affixe[/b] verändern die ganze Karte: Reich (+60% Gold), Bevölkert (+Gegner), Schatzkammer (+Truhen), Elitär (doppelte Eliten), Uralt (+25% XP), Gefährlich (stärkere Gegner, +30% Beute).\nEs gibt KEIN Stufen-Cap — Karten und Helden wachsen endlos.",
	"b_en": "Dungeons exist as [b]maps[/b] (like PoE maps/DQ9 grottoes): every map has a seed — layout, enemies, chests and events are IDENTICAL on every visit. Only loot is rerolled: perfect for farming.\nMap tier = enemy level. After the boss kill you receive a new map at tier ±3. [b]Map modifiers[/b] (elite traits) are fixed at creation; [b]map affixes[/b] change the whole map: Rich (+60% gold), Crowded (+enemies), Treasury (+chests), Elitist (double elites), Ancient (+25% XP), Dangerous (stronger enemies, +30% loot).\nThere is NO tier cap — maps and heroes grow endlessly."},

	{"cat": &"dungeon", "t_de": "Biome & Level-Fenster", "t_en": "Biomes & level windows",
	"b_de": "Vier Biome mit eigenen Gegnern, Optik und Region-Bonus:\n• [b]Wald[/b] (Stufe 1–9): flinke Gegner (+Tempo)\n• [b]Höhle[/b] (3–13): zähe Gegner (+HP)\n• [b]Ruinen[/b] (5–17): gepanzerte Gegner (+Rüstung)\n• [b]Krypta[/b] (ab 7, für immer): magische Gegner (+INT), viele Untote.\nBiome laufen aus: hohe Karten fühlen sich anders an als frühe. Wunsch-Karten aus Händler-Aufträgen können Biome auch außerhalb ihres Fensters liefern.",
	"b_en": "Four biomes with their own enemies, looks and region bonus:\n• [b]Forest[/b] (tier 1–9): nimble enemies (+speed)\n• [b]Cave[/b] (3–13): tough enemies (+HP)\n• [b]Ruins[/b] (5–17): armored enemies (+armor)\n• [b]Crypt[/b] (from 7, forever): magical enemies (+INT), many undead.\nBiomes retire: high maps feel different from early ones. Wish maps from merchant orders can grant biomes outside their window."},

	{"cat": &"dungeon", "t_de": "Ebenen, Tiefe & Kartengröße", "t_en": "Floors, depth & map size",
	"b_de": "Höhere Karten haben mehr Ebenen (Stufe 1–4: eine, 5–8: zwei, … maximal 5), verbunden über Treppen. [b]Der Boss wartet immer ganz unten.[/b]\nTiefere Ebenen: Gegner +1 Stufe pro Ebene UND bessere Truhen (35% Chance auf +1 Rarität pro Ebene).\nDie Kartengröße wächst alle 5 Stufen um +10 in Breite und Höhe (48×36 bis 88×76) — mit entsprechend mehr Gegnern, Truhen und Events.\nDie Minimap oben rechts zeigt Erkundetes, Spieler, Treppe, Boss und Truhen (in Raritäts-Farbe).",
	"b_en": "Higher maps have more floors (tier 1–4: one, 5–8: two, … max 5), connected by stairs. [b]The boss always waits at the very bottom.[/b]\nDeeper floors: enemies +1 tier per floor AND better chests (35% chance of +1 rarity per floor).\nMap size grows every 5 tiers by +10 in width and height (48×36 up to 88×76) — with more enemies, chests and events to match.\nThe minimap (top right) shows explored areas, player, stairs, boss and chests (in rarity colors)."},

	{"cat": &"dungeon", "t_de": "Dungeon-Events", "t_en": "Dungeon events",
	"b_de": "2–3 Events pro Ebene (mehr auf großen Karten), fest pro Karte:\n• [b]Heilschrein/Manaschrein:[/b] sofort 40% Max-HP/MP für die Party\n• [b]Kraftschrein/Schutzschrein:[/b] segnen den NÄCHSTEN Kampf (Angriff +25% bzw. +Rüstung, 3 Runden)\n• [b]Opferstein:[/b] per [E] bewusst auslösen — jeder Held opfert 15% Max-HP (niemand stirbt daran) für Gold und Materialien\n• [b]Risiko-Truhe (Juwelen-Truhe):[/b] 50% dicke Beute (doppeltes Gold, garantiertes Item) — 50% MIMIC-Kampf (Tier+1, Beute ×2,5)\nEs gibt bewusst KEINE Fallen — Events sind Chancen mit transparentem Risiko.",
	"b_en": "2–3 events per floor (more on large maps), fixed per map:\n• [b]Healing/mana shrine:[/b] instantly restores 40% max HP/MP for the party\n• [b]Power/ward shrine:[/b] blesses the NEXT battle (attack +25% or +armor, 3 rounds)\n• [b]Sacrifice stone:[/b] trigger deliberately with [E] — every hero sacrifices 15% max HP (nobody can die from it) for gold and materials\n• [b]Risk chest (jeweled chest):[/b] 50% fat loot (double gold, guaranteed item) — 50% MIMIC fight (tier+1, loot ×2.5)\nThere are deliberately NO traps — events are opportunities with transparent risk."},

	{"cat": &"dungeon", "t_de": "Truhen, Sicht & Steuerung", "t_en": "Chests, visibility & controls",
	"b_de": "[b]Truhen[/b] würfeln bei der Generierung eine Rarität (am Tint erkennbar!), die die Rarität des enthaltenen Items bestimmt — jede Truhe enthält genau ein Item plus Gold und oft Materialien. Tiefere Ebenen und [b]seltene Karten[/b] haben bessere Truhen.
[b]Gegner kommen und gehen:[/b] Jede Ebene hat eine Höchstzahl gleichzeitiger Gegner. Nach einer Weile ziehen Gegner weiter (nie, solange sie dich jagen oder du sie siehst); wird ein Platz frei, taucht bald irgendwo weit weg ein neuer auf.\n[b]Sicht:[/b] Kein Fog of War — alles auf dem Bildschirm ist sichtbar. Wände blockieren nur die Sicht der GEGNER; Wände vor deinem Helden werden durchsichtig. Die Minimap merkt sich, was schon im Bild war.\n[b]Steuerung:[/b] WASD/Pfeile laufen (bildschirmbezogen) · Mausrad zoomt ·[1]/[2] Heil-/Manatrank · [I] Inventar · [E] Opferstein · [Esc] Dungeon verlassen (Fortschritt bleibt).",
	"b_en": "[b]Chests[/b] roll a rarity at generation (visible by their tint!) which sets the rarity of the item inside — every chest holds exactly one item plus gold and often materials. Deeper floors and [b]rare maps[/b] have better chests.
[b]Enemies come and go:[/b] every floor has a cap of simultaneous enemies. After a while enemies wander off (never while they chase you or you can see them); when a slot frees up, a new one soon appears somewhere far away.\n[b]Visibility:[/b] no fog of war — everything on screen is visible. Walls only block the ENEMIES' sight; walls in front of your hero turn translucent. The minimap remembers what has been on screen.\n[b]Controls:[/b] WASD/arrows to move (screen-relative) · mouse wheel zooms ·[1]/[2] healing/mana potion · [I] inventory · [E] sacrifice stone · [Esc] leave dungeon (progress is kept)."},

	# ============================== ITEMS ==================================
	{"cat": &"items", "t_de": "Raritäten & Affixe", "t_en": "Rarities & affixes",
	"b_de": "Items = Basis-Item + zufällige Affixe (Diablo-Prinzip). Die Rarität bestimmt die Affix-Anzahl: Gewöhnlich 0 · Magisch 1 · Selten 2 · Episch 3 · Legendär 4.\n[b]Ein-Basis-Katalog:[/b] „Dolch ist Dolch\" — pro Kategorie existiert genau EIN Basis-Item; die ganze Vielfalt kommt aus Affixen, deren Qualität und dem Item-Level.\n[b]Affix-Qualität:[/b] Jeder Affix rollt ×1,0–1,6 („+3 Schaden\" wird zu „+3 bis +5\").\n[b]Affix-Raritäten:[/b] Häufige Affixe (Stats) fallen oft, seltene (Element-Rider, Skill-Affixe) sind der Jackpot — „des Erzmagiers\" (−12 % MP-Kosten) ist legendär.\nAffixe sind Slot-gebunden: Element-Rider nur auf Waffen, Resistenzen nur auf Rüstung/Schmuck. Resistenzen und MP-Ersparnis wirken in [b]Prozent[/b] (gedeckelt bei 60 % bzw. 50 %) und bleiben so auf jeder Stufe gleich viel wert.",
	"b_en": "Items = base item + random affixes (Diablo style). Rarity sets the affix count: Common 0 · Magic 1 · Rare 2 · Epic 3 · Legendary 4.\n[b]One-base catalog:[/b] \"a dagger is a dagger\" — each category has exactly ONE base item; all variety comes from affixes, their quality and item level.\n[b]Affix quality:[/b] every affix rolls ×1.0–1.6 (\"+3 damage\" becomes \"+3 to +5\").\n[b]Affix rarities:[/b] common affixes (stats) drop often, rare ones (element riders, skill affixes) are the jackpot — \"of the Archmage\" (−12% MP cost) is legendary.\nAffixes are slot-bound: element riders only on weapons, resistances only on armor/jewelry. Resistances and MP savings work in [b]percent[/b] (capped at 60% and 50%) and stay just as valuable at every level."},

	{"cat": &"items", "t_de": "Regelbrecher", "t_en": "Rule breakers",
	"b_de": "Sehr seltene Affixe auf legendären Items, die eine Bauregel für ihren Träger ändern:
• [b]des Baumeisters:[/b] +1 Sockel für alle Skills.
• [b]des Doppelkerns:[/b] zwei Kern-Klötze pro Skill.
• [b]der Waffenfreiheit:[/b] Waffen-Techniken funktionieren mit jeder Waffe.
Sie rollen nie im normalen Affix-Pool: 3 % der legendären Items tragen einen. Die [b]Rune der Regelbrecher[/b] (Medaillen-Stufen, selten von Bossen) garantiert beim Schmieden ein legendäres Item mit einem Regelbrecher.",
	"b_en": "Very rare affixes on legendary items that change a building rule for their wearer:
• [b]of the Builder:[/b] +1 socket for all skills.
• [b]of the Twin Core:[/b] two core blocks per skill.
• [b]of Free Arms:[/b] weapon techniques work with any weapon.
They never roll in the normal affix pool: 3% of legendary items carry one. The [b]Rule-breaker Rune[/b] (medal tiers, rarely from bosses) guarantees a legendary item with a rule breaker when smithing."},

	{"cat": &"items", "t_de": "Waffenarten & Besonderheiten", "t_en": "Weapon types & traits",
	"b_de": "Jede Waffe hat eine [b]Besonderheit[/b], die bei JEDEM Waffenangriff wirkt (auch in deinen Skills):\n• [b]Schwert:[/b] 20% Parade — der Treffer wird abgewehrt, die Hälfte geht zurück\n• [b]Dolch:[/b] trifft immer [b]doppelt[/b] (je 60%) — ideal für Gift, Blutung und Krits; ein zweiter Dolch wandert in die Nebenhand\n• [b]Axt:[/b] höchster Grundschaden und [b]doppelter Schaden[/b], danach erschöpft — der nächste eigene Zug fällt aus (Unermüdlich hebt das auf)\n• [b]Knüppel/Hammer:[/b] 15% Betäubung bei jedem Treffer; Stumpf knackt Platte\n• [b]Bogen:[/b] 15% Schwachstellen-Chance (+Glück/3) — Schwachstelle ×2, mit Krit [b]VOLLTREFFER ×4[/b]\n• [b]Armbrust:[/b] Bolzen durchschlägt 50% Rüstung und trifft einen zweiten Gegner mit 40%\n• [b]Offensivstab:[/b] Element-Signaturen (Brand, Frost, Gift …) +50%\n• [b]Heiligstab:[/b] Heilung +50%\n• [b]Schild (Nebenhand):[/b] 25% Block\n• [b]Köcher:[/b] Nebenhand zu Bogen/Armbrust (+Schaden)\n[b]Element-Rider-Affixe[/b] („Loderndes …\"): jeder Waffenhieb trägt zusätzlich Elementschaden mit voller Signatur.",
	"b_en": "Every weapon has a [b]trait[/b] that applies to EVERY weapon attack (in your skills too):\n• [b]Sword:[/b] 20% parry — the hit is deflected, half of it goes back\n• [b]Dagger:[/b] always hits [b]twice[/b] (60% each) — great for poison, bleed and crits; a second dagger goes to the off-hand\n• [b]Axe:[/b] highest base damage and [b]double damage[/b], then exhausted — your next turn is skipped (Tireless removes this)\n• [b]Club/hammer:[/b] 15% stun on every hit; blunt cracks plate\n• [b]Bow:[/b] 15% weak spot chance (+luck/3) — weak spot ×2, with a crit [b]FULL HIT ×4[/b]\n• [b]Crossbow:[/b] bolts pierce 50% armor and hit a second enemy for 40%\n• [b]Offensive staff:[/b] element signatures (burn, frost, poison …) +50%\n• [b]Holy staff:[/b] healing +50%\n• [b]Shield (off-hand):[/b] 25% block\n• [b]Quiver:[/b] off-hand companion for bow/crossbow (+damage)\n[b]Element rider affixes[/b] (\"Blazing …\"): every weapon hit carries extra elemental damage with full signature."},

	{"cat": &"items", "t_de": "Rüstung, Roben & Item-Level", "t_en": "Armor, robes & item level",
	"b_de": "Brustrüstung nach Gewicht und Zweck: [b]Leicht[/b] (Leder, +Tempo) · [b]Mittel[/b] (Kette) · [b]Schwer[/b] (Platte, +VIT) · [b]Schadensrobe[/b] (+INT, +Zauberkraft) · [b]Heilrobe[/b] (+SPI) · [b]Kampfrobe[/b] (dazwischen). Helm/Handschuhe/Stiefel je leicht oder schwer. Zauberkraft zählt aus der GESAMTEN Ausrüstung (Stab + Robe + Fokus stapeln).\n[b]Item-Level = Kartenstufe des Drops:[/b] Kampfwerte wachsen +13% pro Level — endlos. Ein Stufe-15-Schwert schlägt ein Stufe-2-Schwert deutlich; Gear bleibt auf jeder Stufe relevant.\nDas Inventar zeigt zu jedem Item den direkten Vergleich mit dem Ausgerüsteten.",
	"b_en": "Body armor by weight and purpose: [b]light[/b] (leather, +speed) · [b]medium[/b] (chain) · [b]heavy[/b] (plate, +VIT) · [b]damage robe[/b] (+INT, +spell power) · [b]healing robe[/b] (+SPI) · [b]battle robe[/b] (in between). Helmet/gloves/boots come in light or heavy. Spell power counts from your ENTIRE equipment (staff + robe + focus stack).\n[b]Item level = map tier of the drop:[/b] combat values grow +13% per level — endlessly. A tier-15 sword clearly beats a tier-2 sword; gear stays relevant at every tier.\nThe inventory shows a direct comparison with your equipped item."},

	# ============================== HELDEN =================================
	{"cat": &"helden", "t_de": "Attribute & abgeleitete Werte", "t_en": "Attributes & derived stats",
	"b_de": "• [b]Stärke:[/b] physischer Schaden (Waffennutzung)\n• [b]Intelligenz:[/b] Zauberschaden\n• [b]Vitalität:[/b] HP = 20 + VIT×8\n• [b]Willenskraft:[/b] MP = 10 + SPI×5, Beschwörungs-HP, stärkere Support-Effekte (Schild, Regeneration, Mana-Fluss, Wappnen — alle in Prozent: bis ×2, abnehmender Ertrag) und Heilung (bis ×2, abnehmender Ertrag)\n• [b]Agilität:[/b] Tempo (Zugreihenfolge)\n• [b]Glück:[/b] Krit-Chance (flacht ab) und mehr Beute\nAlle Helden starten identisch: Level 1, überall 5 Punkte. [b]Es gibt keine Klassen[/b] — die Rolle entsteht aus Statuspunkten, Skill-Bausteinen und Ausrüstung.",
	"b_en": "• [b]Strength:[/b] physical damage (weapon use)\n• [b]Intelligence:[/b] spell damage\n• [b]Vitality:[/b] HP = 20 + VIT×8\n• [b]Spirit:[/b] MP = 10 + SPI×5, summon HP, stronger support effects (shield, regen, mana flow, brace — all percentages: up to ×2, diminishing returns) and healing (up to ×2, diminishing returns)\n• [b]Agility:[/b] speed (turn order)\n• [b]Luck:[/b] crit chance (levels off) and more loot\nAll heroes start identical: level 1, 5 points everywhere. [b]There are no classes[/b] — your role emerges from stat points, skill blocks and equipment."},

	{"cat": &"helden", "t_de": "Level, XP & Party", "t_en": "Levels, XP & party",
	"b_de": "XP gibt es für Kampfsiege — sie wird [b]auf die Helden im Kampf geteilt[/b] (Gefallene bekommen ihren Anteil trotzdem). [b]Nachzügler-Bonus:[/b] Haben die Helden unterschiedliche Level, bekommt der niedrigste die Hälfte, die anderen teilen sich den Rest. [b]Bank-Helden[/b] trainieren mit (10 % der Kampf-XP) bis 5 Level unter den Schwächsten der Party — oder in der Taverne sofort gegen Gold. Helden auf der Bank bekommen keinen Kampf-Anteil. Gegner unter deinem Level geben weniger XP (−8 % je Level, min. 10 %), stärkere mehr (+5 % je Level, max. +50 %). Kein Level-Cap! Jeder Level-Up: [b]5 freie Statuspunkte[/b], [b]2 Waffen-Skillpunkte[/b] (+1 auf Level 50 und 100, siehe Waffentechniken) + volle Heilung. Skill-Slots: 1 + Level/5.\nDie Party wächst in der [b]Taverne[/b] — dort erstellst du bis zu 10 eigene Helden (Name, Porträt, Startwaffe), kostenlos. Maximal 4 sind aktiv; der Rest wartet auf der [b]Bank[/b] und ist jederzeit tauschbar (abgelegte Helden machen Platz für Co-op-Gäste). Jeder Held startet identisch — nur die gewählte Startwaffe (Schwert & Schild, Dolche, Bogen, Stäbe …) und ihr Start-Skill geben eine Richtung; die Werte stehen bei der Auswahl dabei.\n[b]Kein Permadeath:[/b] Gefallene stehen nach dem Kampf mit 1 HP auf; nach Siegen verschnauft die Party (+25% HP/MP); das Hub heilt immer voll. Bei einer Niederlage geht es zurück ins Hub — die Karte bleibt erhalten.",
	"b_en": "XP is earned from won battles — it is [b]split among the heroes in the fight[/b] (the fallen still get their share). [b]Catch-up bonus:[/b] if levels differ, the lowest hero gets half and the others share the rest. [b]Benched heroes[/b] train along (10% of battle XP) up to 5 levels below the party's weakest — or instantly for gold at the tavern. Benched heroes get no share of battle XP. Enemies below your level give less XP (−8% per level, min. 10%), stronger ones more (+5% per level, max. +50%). No level cap! Every level-up: [b]5 free stat points[/b], [b]2 weapon skill points[/b] (+1 at levels 50 and 100, see weapon techniques) + full heal. Skill slots: 1 + level/5.\nYour party grows at the [b]tavern[/b] — create up to 10 heroes of your own there (name, portrait, starting weapon), free of charge. Up to 4 are active; the rest waits on the [b]bench[/b], swappable anytime (benched heroes make room for co-op guests). Every hero starts identical — only the chosen starting weapon (sword & shield, daggers, bow, staves …) and its starter skill set a direction; stats are shown during selection.\n[b]No permadeath:[/b] fallen heroes get up with 1 HP after battle; after victories the party catches its breath (+25% HP/MP); the hub always heals fully. On defeat you return to the hub — the map is kept."},

	{"cat": &"helden", "t_de": "Skill-Bausteine (die Werkstatt)", "t_en": "Skill blocks (the workshop)",
	"b_de": "Statt fertiger Skills baust du deine eigenen aus Klötzen. Es gibt [b]keine fertigen Muster[/b] wie Hagel, Salve oder Kettenblitz — die baust du selbst:\n• [b]Quelle[/b] (Pflicht): [b]Waffenangriff[/b] (1 MP + 3% deiner Max-MP — auf jedem Level ~25 Hiebe pro Leiste, nutzt die Besonderheit deiner Waffe) oder [b]Zauber[/b] (3 MP + 15% INT, Heilung, Support, volle Element-Signatur). Beide = Hybrid. [b]Körper[/b] (ab Level 3, MP wie Waffenangriff): gegen Gegner ein stumpfer Treffer aus Max-HP + Rüstung, mit Selbst/Verbündeter/Aura nur Effekte, die mit VIT statt SPI skalieren. Körper lässt sich mit keiner anderen Quelle kombinieren.\n• [b]Nur mit Quelle:[/b] Schutzwall, Deckung, Provozieren, Eiserne Abwehr, Lebensgabe, Innere Ruhe und Zorn gehen nur mit Körper · Manaraub und Rückschlag nur mit Waffenangriff · Wiederbeleben, Schweigen und Zauberspiegel nur mit Zauber.\n• [b]Element[/b], [b]Form[/b] (Alle Gegner, Verbündeter, Aura, Selbst, Beschwörung), [b]Effekte[/b] (wirken aufs Ziel — oder mit Figuren-Marke auf dich, die Party bzw. alle Gegner)\n• [b]Zusatztreffer[/b] (stapelbar): +1 Treffer, alle Treffer teilen sich den Schaden (+15% je Zusatztreffer). Mit [b]Zufallsziel[/b] = Hagel, mit [b]Wechselziel[/b] = Fächer/Kette, mit [b]Überschlag[/b] trifft überschüssiger Schaden den Nächsten.\n• [b]Eigenschaften mit Preis:[/b] Präzision (+30% Krit, −10% Schaden), Wucht (×1,5, handelt zuletzt), Flinkheit (handelt zuerst, −25%), Aufladen (nächster Zug, ×2), Sparsam, Blutpreis (HP statt MP), Alles oder nichts (Krit ×3, sonst nichts), [b]Vollheilung[/b] (heilt bis voll und kostet so viel MP wie nötig — Heil-Boni zählen; reicht das Mana nicht, gehen alle MP drauf und es wird so viel geheilt wie möglich)\n• [b]Kombos:[/b] Ausnutzen (gegen Betäubte/Verlangsamte), Entzünden (gegen Brennende, löscht den Brand), Nachsetzen (wenn ein Verbündeter es schon traf), Hinrichtung, Rache …\n[b]Treffer-Arten:[/b] Krit ×1,5 · Schwachstelle ×2 · beides = [b]VOLLTREFFER ×4[/b].\n[b]Bauregeln:[/b] Sockel — 3 zu Beginn, +1 auf Level 8, 18, 30, 50 und nach der ersten Wiedergeburt (max. 8). Jeder Klotz nur einmal (außer Zusatztreffer); [b]◆[/b] = nur einer seiner Gruppe (z.B. eine Krit-Chance, ein Zeitpunkt); [b]★ Kern[/b] = höchstens einer pro Skill. Verstärker [b]multiplizieren[/b] die MP-Kosten.\n[b]Freischaltung:[/b] Universelle Klötze kommen übers [b]Charakter-Level[/b] — bis Level 20 jedes Level einer, danach seltener. Waffen-Klötze kommen übers Waffen-Training. Die Vorlagen in der Werkstatt zeigen Beispiel-Bauten.
[b]Rezeptbuch:[/b] Speichere beliebig viele Bauten („Ins Buch“) und tausche sie jederzeit in einen Slot — in den Kampf gehen nur die Slot-Skills. Umbauen geht überall außer im Kampf, auch mitten im Dungeon (Taste K).",
	"b_en": "Instead of ready-made skills you build your own from blocks. There are [b]no ready-made patterns[/b] like hail, volley or chain lightning — you build them yourself:\n• [b]Source[/b] (required): [b]weapon attack[/b] (1 MP + 3% of your max MP — ~25 strikes per bar at any level, uses your weapon's trait) or [b]spell[/b] (3 MP + 15% INT, healing, support, full element signature). Both = hybrid. [b]Body[/b] (from level 3, MP like a weapon attack): against enemies a blunt blow from max HP + armor, with self/ally/aura effects only, scaling with VIT instead of SPI. Body cannot be combined with another source.\n• [b]Source-bound:[/b] bulwark, cover, taunt, iron guard, life gift, inner calm and wrath only work with body · mana drain and recoil only with a weapon attack · revive, silence and magic mirror only with a spell.\n• [b]Element[/b], [b]form[/b] (all enemies, ally, aura, self, summon), [b]effects[/b] (hit the target — or, with a figure badge, you, the party or all enemies)\n• [b]Extra hit[/b] (stackable): +1 hit, all hits share the damage (+15% per extra hit). With [b]random target[/b] = hail, with [b]switching target[/b] = fan/chain, with [b]overflow[/b] excess damage hits the next enemy.\n• [b]Traits with a price:[/b] precision (+30% crit, −10% damage), heft (×1.5, acts last), swiftness (acts first, −25%), charge up (next turn, ×2), frugal, blood price (HP instead of MP), all or nothing (crit ×3, otherwise nothing), [b]full heal[/b] (heals to full and costs as much MP as needed — healing bonuses count; if MP runs short, all MP is spent and it heals as much as possible)\n• [b]Combos:[/b] exploit (vs stunned/slowed), ignite (vs burning, consumes the burn), follow-up (if an ally already hit it), execution, vengeance …\n[b]Hit types:[/b] crit ×1.5 · weak spot ×2 · both = [b]FULL HIT ×4[/b].\n[b]Build rules:[/b] sockets — 3 at first, +1 at level 8, 18, 30, 50 and after the first rebirth (max 8). Each block once (except extra hit); [b]◆[/b] = only one of its group (e.g. one crit chance, one timing); [b]★ core[/b] = at most one per skill. Modifiers [b]multiply[/b] the MP cost.\n[b]Unlocks:[/b] universal blocks come from [b]character level[/b] — one per level up to 20, rarer after that. Weapon blocks come from weapon training. The workshop templates show example builds.
[b]Recipe book:[/b] save as many builds as you like (\"To book\") and swap them into a slot at any time — only slotted skills go into battle. Rebuild anywhere except in battle, even mid-dungeon (key K)."},

	# ============================== HUB ====================================
	{"cat": &"hub", "t_de": "Materialien, Alchemist & Schmiede", "t_en": "Materials, alchemist & smithy",
	"b_de": "Gegner und Truhen droppen [b]Materialien[/b]:
• [b]Kräuter & Salze[/b] (Heilkraut, Manablüte, Reinigungssalz) » [b]Alchemist:[/b] Tränke brauen. Tränke heilen % ODER flach — der höhere Wert zählt.
• [b]Werkstoffe[/b] Erz, Leder, Kristall in 5 Stufen — [b]Eisen, Stahl, Mithril, Adamant, Sternen[/b]. Welche Stufe droppt, bestimmt die Kartenstufe (Stahl ab 8, Mithril ab 18, Adamant ab 32, Sternen ab 50); Bosse liefern manchmal schon die nächste.
• [b]Runen[/b] (selten von Bossen): garantieren beim Schmieden mindestens Selten, Episch oder Legendär.
[b]Schmiede:[/b] Reiter je Art (Nahkampf, Fernkampf, Stäbe, Nebenhand, Rüstung, Schmuck). Du wählst nur [b]Werkstoff, Item-Level und optional eine Rune[/b] — welche Basis, Rarität und Affixe herauskommen, ist Zufall. Höheres Level kostet mehr Gold (eine Stufe tiefer schmieden spart). Edlere Werkstoffe erlauben höhere Level und erhöhen die CHANCE auf seltene Stücke, garantieren aber nichts. Dazu [b]Affixe neu würfeln[/b].
[b]Händler:[/b] Tränke, Kräuter und Werkstoffe der Eisen-Stufe; [b]Ausrüstung[/b] gegen Gold: Art wählen, Level ≈ Party-Schnitt, sonst Zufall — teurer als die Schmiede.",
	"b_en": "Enemies and chests drop [b]materials[/b]:
• [b]Herbs & salts[/b] (healing herb, mana blossom, purifying salt) » [b]alchemist:[/b] brew potions. Potions heal % OR flat — the higher value counts.
• [b]Materials[/b] ore, leather, crystal in 5 tiers — [b]iron, steel, mithril, adamant, star[/b]. The map tier decides which drops (steel from 8, mithril from 18, adamant from 32, star from 50); bosses sometimes drop the next one.
• [b]Runes[/b] (rare boss drops): guarantee at least rare, epic or legendary when forging.
[b]Smithy:[/b] tabs per kind (melee, ranged, staves, off-hand, armor, jewelry). You only choose [b]material, item level and optionally a rune[/b] — base, rarity and affixes are luck. Higher levels cost more gold (forging a level lower saves). Finer materials allow higher levels and raise the CHANCE of rare pieces but guarantee nothing. Plus [b]reroll affixes[/b].
[b]Merchant:[/b] potions, herbs and iron-tier materials; [b]equipment[/b] for gold: pick the kind, level ≈ party average, the rest is luck — pricier than the smithy."},

	{"cat": &"hub", "t_de": "Mini-Medaillen", "t_en": "Mini medals",
	"b_de": "Seltene Sammelmünzen: 12% Chance in jeder Truhe, GARANTIERT in Risiko-Truhen und Tresoren, 30% bei Boss-Siegen.
Beim Händler eintauschbar:
• 3 Medaillen » Schmiede-Paket (je 3× Erz, Leder, Kristall)
• 5 Medaillen » Wunsch-Karte auf Party-Schnitt
• 8 Medaillen » garantiert EPISCHES Item
Jede Truhe ist damit eine zweite Lotterie.
[b]Medaillen-Stufen:[/b] Für insgesamt GESAMMELTE Medaillen (Ausgeben zählt nicht dagegen) gibt es beim Händler je Stufe eine feste Belohnung: 5 » +5 Kartenlager-Plätze, 10 » Rune der Pracht, 20 » Schatzkarte, 30 » Rune der Regelbrecher, 50 » Rune der Legenden, 75 » +5 Plätze, 100 » Rune der Regelbrecher, danach alle 50 eine Rune der Regelbrecher.",
	"b_en": "Rare collectible coins: 12% chance in every chest, GUARANTEED in risk chests and vaults, 30% on boss victories.
Exchange at the merchant:
• 3 medals » smithing bundle (3× ore, leather, crystal each)
• 5 medals » wish map at party average
• 8 medals » guaranteed EPIC item
Every chest becomes a second lottery — and the risk chest pays double.
[b]Medal tiers:[/b] medals COLLECTED in total (spending does not count against it) unlock one fixed reward per tier at the merchant: 5 » +5 map storage slots, 10 » Rune of Splendor, 20 » treasure map, 30 » Rule-breaker Rune, 50 » Rune of Legends, 75 » +5 slots, 100 » Rule-breaker Rune, then one Rule-breaker Rune every 50."},

	{"cat": &"hub", "t_de": "Co-op (mit Freunden spielen)", "t_en": "Co-op (play with friends)",
	"b_de": "Im Hauptmenü unter [b]Co-op[/b] öffnest du deine Welt (Host) oder trittst per IP bei (LAN oder Internet; der Host versucht die Portfreigabe automatisch per UPnP — klappt das nicht, Port 7777/UDP manuell freigeben).
[b]Der Gast bringt seinen eigenen Helden mit[/b] (aus dem eigenen Spielstand) — er belegt beim Host einen freien Party-Slot, pro Gast einer. Der Held wird NIE im Spielstand des Hosts gespeichert.
[b]Karten:[/b] Öffnet der Host eine Karte, erscheint bei allen Gästen „Karte von (Name) — joinen“. Gäste laufen frei durch den Dungeon (gleiches Layout), Mitspieler sind mit Namen sichtbar.
[b]Truhen, Schreine, Opfersteine, Risiko-Truhen und Tresore gibt es für jeden Spieler einzeln:[/b] Jeder öffnet und benutzt sie selbst und bekommt eigene Beute, ohne sie den anderen wegzunehmen. Ein Mimic startet einen gemeinsamen Kampf.
[b]Kämpfe:[/b] Berührt ein Spieler einen Gegner, wird jeder auf DERSELBEN Ebene mit hineingezogen; jeder wählt die Befehle seines Helden selbst, auch Tränke aus dem eigenen Inventar. Wer woanders ist, bleibt außen vor.
[b]Flucht:[/b] Geflohen wird nur, wenn ALLE Spieler im selben Zug Fliehen wählen — dann gilt die normale Fluchtchance.
[b]Abstimmung:[/b] Treppe nach unten und Bossangriff entscheiden alle Spieler auf der Ebene gemeinsam, das Verlassen des Dungeons durch den Host alle Spieler im Dungeon. Ein „Nicht bereit“ beendet die Abstimmung. Wer allein auf der Ebene ist, entscheidet allein.
[b]Beute:[/b] Mitkämpfende Gäste nehmen XP, Gold, Items und Materialien mit nach Hause, dazu eigene Schatzkarten, nach dem Boss eine eigene Belohnungskarte und eigene Boss-Medaillen.",
	"b_en": "In the main menu under [b]Co-op[/b] you open your world (host) or join via IP (LAN or internet; the host tries UPnP port forwarding automatically — if that fails, forward port 7777/UDP manually).
[b]The guest brings their own hero[/b] (from their own save) — it takes a free party slot on the host's side, one per guest. The hero is NEVER saved into the host's save file.
[b]Maps:[/b] When the host opens a map, every guest sees \"Map from (name) — join\". Guests roam the dungeon freely (same layout), teammates are visible with names.
[b]Chests, shrines, sacrifice stones, risk chests and vaults exist for every player separately:[/b] everyone opens and uses them on their own and gets their own loot without taking it from the others. A mimic starts a shared battle.
[b]Battles:[/b] when a player touches an enemy, everyone on the SAME floor is pulled in; each player picks the commands for their own hero, including potions from their own inventory. Anyone elsewhere stays out.
[b]Fleeing:[/b] the party only flees if ALL players choose Flee in the same turn — then the normal flee chance applies.
[b]Votes:[/b] taking the stairs down and attacking the boss are decided by all players on the floor; the host leaving the dungeon by all players in the dungeon. One 'Not ready' ends the vote. A player alone on a floor decides alone.
[b]Loot:[/b] Fighting guests take XP, gold, items and materials home, plus their own treasure maps, their own reward map after the boss and their own boss medals."},

	{"cat": &"hub", "t_de": "Händler-Aufträge & Kartenlager", "t_en": "Merchant orders & map storage",
	"b_de": "Der Händler bietet [b]3 rotierende Aufträge:[/b] Materialien liefern, N Gegner besiegen, eine Biom-Karte (Mindeststufe) abschließen. Der Fortschritt zählt automatisch. Belohnungen: Gold, Material-Pakete oder eine [b]Wunsch-Karte[/b] mit garantiertem Biom (Stufe = Party-Schnitt) — auch außerhalb des Biom-Fensters!\n[b]Karten-Raritäten:[/b] Magisch/Selten/Episch/Legendär = +1 bis +2 Gegnerstufen, bis ×2 Beute und ×1,5 XP auf ALLEN Gegnern der Karte (farbig im Lager).
Das [b]Kartenlager[/b] fasst 25 Karten (gegen Gold erweiterbar, +5 pro Ausbau). Ist es voll, verfallen neue Belohnungskarten — Lager-Management gehört zum Spiel. Karten sind löschbar. [b]★ Favoriten[/b] stehen oben und sind vor dem Löschen geschützt; das [b]Archiv[/b] (15 Plätze) bewahrt besondere Farm-Karten auf, ohne Lagerplatz zu belegen — betreten geht auch von dort.",
	"b_en": "The merchant offers [b]3 rotating orders:[/b] deliver materials, defeat N enemies, complete a biome map (minimum tier). Progress counts automatically. Rewards: gold, material bundles or a [b]wish map[/b] with a guaranteed biome (tier = party average) — even outside its biome window!\n[b]Map rarities:[/b] magic/rare/epic/legendary = +1 to +2 enemy tiers, up to ×2 loot and ×1.5 XP on ALL enemies of the map (colored in storage).
The [b]map storage[/b] holds 25 maps (expandable for gold, +5 per upgrade). When full, new reward maps are lost — storage management is part of the game. Maps can be deleted. [b]★ Favorites[/b] are listed first and protected from deletion; the [b]archive[/b] (15 slots) keeps special farming maps without using storage — you can enter them from there too."},

	{"cat": &"kampf", "t_de": "Fliehen", "t_en": "Fleeing",
	"b_de": "Die Aktion [b]Fliehen[/b] beendet den Kampf ohne Sieg oder Niederlage: keine XP, keine Beute, der Gegner bleibt im Dungeon stehen (mit kurzer Schonfrist, bis die Party auf Abstand ist).
Die Fluchtchance kommt aus dem [b]Geschick-Vergleich[/b] (Ø Party vs. Ø Gegner): 50% Basis, ±3% pro Punkt Unterschied, begrenzt auf 25–95%.
Misslingt die Flucht, ist der Zug verbraucht — die Gegner schlagen zu.
[b]Vor Bossen gibt es kein Entkommen[/b] — der Fliehen-Knopf fehlt dort komplett.",
	"b_en": "The [b]flee[/b] action ends the battle without victory or defeat: no XP, no loot, the enemy stays in the dungeon (with a short grace period until the party gains distance).
The escape chance comes from the [b]agility comparison[/b] (party avg. vs. enemy avg.): 50% base, ±3% per point of difference, clamped to 25–95%.
If the attempt fails, the turn is spent — the enemies strike.
[b]There is no escape from bosses[/b] — the flee button is absent there."},

	{"cat": &"helden", "t_de": "Waffentechniken", "t_en": "Weapon techniques",
	"b_de": "Das [b]Waffen-Training[/b] (Skill-Werkstatt » Waffen-Training) schaltet Klötze frei, die zu einer Waffe passen und [b]nur mit ihr[/b] nutzbar sind (Schild über die Nebenhand): +2 Skillpunkte pro Level-Up (auf Level 50 und 100 je einer mehr — genau zwei volle Bäume bis Level 100), investiert pro Gattung (unumkehrbar, wie DQ9). Sie schreiben kein Angriffsmuster vor — du baust sie in deine Skills ein. ★ = Kern-Klotz.\n• [b]Schwert:[/b] Klingenwall, Duellstoß, Entwaffnen, Kampfruf (Party), Wachsamkeit, Schwertkunst, Riposte, Schutzhieb, Heldenmut, Duellmeister, ★ Klingentanz (Zusatztreffer ohne Verlust), ★ Meisterklinge (Krit ×2,5)\n• [b]Dolch:[/b] Giftklinge, Schattenschritt, Blutung, Meucheln (Krit ×2,5), Lähmgift, Schwachpunkt, Serienschlag (viele Treffer, jeder aufs selbe Ziel stärker: 10 % » 100 %, über Züge), Hinterhalt, Schattenmantel, ★ Todesstoß, Rauchbombe (alle Gegner), ★ Elementklinge\n• [b]Axt:[/b] Kopfspalter, Kampfrausch, Rüstungsspalter, Blutrausch, Unermüdlich (keine Erschöpfung), Klaffende Wunde, Kriegsschrei, Berserkerwut, ★ Raserei\n• [b]Knüppel/Hammer:[/b] Betäuben, Rüstungsriss, Erschüttern, Benommenheit, Zermalmen, Betäuben II, Eisenhaut, Erdstoß (alle Gegner), ★ Rüstungsriss II\n• [b]Bogen:[/b] Markieren, Zielen, Lähmpfeil, Giftpfeil, Rückzug, Adlerauge, Sperrfeuer, Scharfschütze, ★ Meisterschuss (Volltreffer ×6)\n• [b]Armbrust:[/b] Netzbolzen, Panzerbrecher, Widerhaken, Kniender Schuss, Brandbolzen, Schwerer Bolzen, Markierbolzen, ★ Bolzenmeister\n• [b]Offensivstab:[/b] Effizienz, Arkanschild, Arkane Fessel, Fokussierung, Element-Fokus (Signatur ×2), Arkane Flut, ★ Echo, ★ Arkane Entladung\n• [b]Heiligstab:[/b] Überheilung, Mana-Fluss, Schutzgebet, Vergebung, Segensaura, Heiliger Eifer, ★ Wiederbeleben\n• [b]Schild:[/b] Schutzwall, Vergeltung, Schildstoß, Bastion, Standhaft, Gegenwehr, ★ Schutzkuppel\n[b]Meisterschaft:[/b] Ein Baum auf 100 schaltet seine Rolle frei — sie kommt in den Meisterschafts-Slot und wirkt mit JEDER Waffe: Klingenmeister (+20 % Parade), Schattentänzer (ein Hieb mehr), Schlächter (×1,5 unter 50 % HP), Erdbrecher (+15 % Betäubung), Adlerauge (Krit ×2,5), Belagerer (+30 % Durchschlag), Erzmagier (Signaturen +50 %), Heiliger (Heilung +50 %), Bollwerk (+25 % Block).\nDazu [b]%-Passive[/b] an den Zwischen-Schwellen (Waffenschaden, Krit, Zauberkraft, MP-Kosten, Rüstung) — aktiv, solange die Gattung geführt wird.",
	"b_en": "[b]Weapon training[/b] (skill workshop » weapon training) unlocks blocks that fit a weapon and can [b]only be used with it[/b] (shield via the off-hand): +2 skill points per level-up (one extra at levels 50 and 100 — exactly two full trees by level 100), invested per family (permanent, like DQ9). They don't dictate an attack pattern — you build them into your skills. ★ = core block.\n• [b]Sword:[/b] blade wall, duel thrust, disarm, rallying cry (party), vigilance, swordsmanship, riposte, guarding cut, valor, duel master, ★ blade dance (extra hits lose nothing), ★ master blade (crit ×2.5)\n• [b]Dagger:[/b] venom blade, shadow step, bleed, assassinate (crit ×2.5), paralytic venom, weak point, flurry (many hits, each on the same target stronger: 10% » 100%, across turns), ambush, shadow cloak, ★ death blow, smoke bomb (all enemies), ★ infused blade\n• [b]Axe:[/b] headsplitter, battle frenzy, armor splitter, bloodlust, tireless (no exhaustion), gaping wound, war shout, berserk rage, ★ frenzy\n• [b]Club/hammer:[/b] stun, armor break, rattle, daze, crush, stun II, iron skin, ground slam (all enemies), ★ armor break II\n• [b]Bow:[/b] mark, aim, crippling arrow, poison arrow, fall back, eagle eye, covering fire, sharpshooter, ★ master shot (full hit ×6)\n• [b]Crossbow:[/b] net bolt, armor breaker, barbed bolt, kneeling shot, fire bolt, heavy bolt, marking bolt, ★ bolt master\n• [b]Offensive staff:[/b] efficiency, arcane shield, arcane bind, concentration, element focus (signature ×2), arcane surge, ★ echo, ★ arcane discharge\n• [b]Holy staff:[/b] overheal, mana flow, prayer of shielding, absolution, aura of blessing, holy zeal, ★ revive\n• [b]Shield:[/b] bulwark, retribution, shield bash, bastion, steadfast, pushback, ★ shield dome\n[b]Mastery:[/b] a tree at 100 unlocks its role — it goes into the mastery slot and works with ANY weapon: blade master (+20% parry), shadow dancer (one more strike), butcher (×1.5 below 50% HP), earthbreaker (+15% stun), eagle eye (crit ×2.5), besieger (+30% pierce), archmage (signatures +50%), saint (healing +50%), bulwark (+25% block).\nPlus [b]%-passives[/b] at the in-between thresholds (weapon damage, crit, spell power, MP cost, armor) — active while the family is wielded."},

	{"cat": &"helden", "t_de": "Wiedergeburt (ab Level 100)", "t_en": "Rebirth (from level 100)",
	"b_de": "Ab [b]Level 100[/b] steht im Waffen-Training die [b]Wiedergeburt[/b] bereit: Level, XP und Statuspunkte gehen zurück auf Level 1. [b]Waffen-Training, Meisterschaft, freie Skillpunkte, Skills, freigeschaltete Klötze und Ausrüstung bleiben[/b].\nJe Wiedergeburt: [b]+10 % auf alle Werte[/b] (Grundwerte und Ausrüstungs-Boni); nach der ersten Wiedergeburt +1 Sockel pro Skill.\nEin Leben bis Level 100 bringt 200 Skillpunkte (zwei volle Bäume); es gibt 9 Bäume.\nDie Anzahl der Wiedergeburten wird angezeigt (Wiedergeburt ×N).",
	"b_en": "From [b]level 100[/b], weapon training offers [b]rebirth[/b]: level, XP and stat points return to level 1. [b]Weapon training, mastery, free skill points, skills, unlocked blocks and equipment remain[/b].\nPer rebirth: [b]+10% to all stats[/b] (base stats and equipment bonuses); after the first rebirth +1 socket per skill.\nOne life up to level 100 grants 200 skill points (two full trees); there are 9 trees.\nThe number of rebirths is shown (rebirth ×N)."},
]
