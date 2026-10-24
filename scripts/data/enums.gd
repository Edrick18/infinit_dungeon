class_name Enums
extends RefCounted
## Zentrale Enums für das gesamte Datenmodell.

## Die drei unabhängigen Schadensachsen. Ein Skill kann beliebig viele davon
## gleichzeitig nutzen (siehe DESIGN.md Abschnitt 4).
enum DamageAxis {
	PHYSICAL,   ## Waffen-/Nahkampfschaden (skaliert typischerweise mit STR)
	MAGICAL,    ## Roher Zauberschaden (skaliert typischerweise mit INT)
	ELEMENTAL,  ## DoT-/Status-lastiger Schaden über Zeit (Brand, Gift, ...)
}

enum Element {
	NONE,
	FIRE,
	ICE,
	LIGHTNING,
	POISON,
	HOLY,
	DARK,
}

## Unterarten des physischen Schadens — Waffen und physische Skill-Bausteine
## haben ein Schadensprofil, Rüstungstypen mindern sie unterschiedlich stark.
enum PhysicalSubtype {
	SLASH,   ## Schnitt (Schwerter, Äxte)
	PIERCE,  ## Stich (Schwerter, Bögen, Dolche)
	BLUNT,   ## Stumpf (Knüppel, Hämmer, Stäbe)
}

## Rüstungstyp eines Rüstungsteils — bestimmt, wie gut es gegen die
## physischen Schadensarten schützt.
enum ArmorClass {
	NONE,     ## Schmuck etc. — Rüstungswert wirkt neutral
	LEATHER,  ## Leder: neutral gegen alles
	CHAIN,    ## Kette: stark gegen Schnitt, schwach gegen Stich/Stumpf
	PLATE,    ## Platte: stark gegen Schnitt/Stich, schwach gegen Stumpf
	# --- nur Gegner (natürliche Panzerung) ---
	FELL,     ## Fell/Haut: hält Hiebe, Stiche gehen durch
	KNOCHEN,  ## Knochen: Stiche rutschen durch die Rippen, Stumpf zertrümmert
}

## Schadensquelle eines Skills (Phase-3-Rework): der Schaden kommt aus der
## AUSGERÜSTETEN Waffe, nicht aus dem Baustein.
enum SkillSource {
	WEAPON,  ## Waffennutzung: physisch, Schaden + Art von der Waffe; Zielform fest durch Waffe
	SPELL,   ## Zauber: Zauberschaden der Waffe + INT; Standard Einzelziel-Projektil
	KOERPER, ## Körper: stumpfer Treffer aus Max-HP + Rüstung; ohne Gegner-Ziel nur Effekte (VIT-skaliert)
}

## Form/Targeting eines Skills. Nur bei Zauber-Quelle wählbar; ohne Form-Baustein
## ist ein Zauber Einzelziel-Projektil, eine Waffennutzung Einzelziel (Waffe entscheidet
## Nahkampf/Fernkampf).
enum SkillForm {
	SINGLE,  ## Standard: ein Gegner (Default, kein Baustein)
	AOE,     ## Alle Gegner
	ALLY,    ## Ein gewählter Verbündeter (gezielte Heilung/Buff)
	AURA,    ## Ganze Party
	SELF,    ## Nur der Anwender
	SUMMON,  ## Beschwörung (kämpft eigenständig mit)
}

enum Status {
	STUN,
	BURN,
	POISON_DOT,
	SLOW,
	WEAKEN,
	LIFESTEAL,
	SHIELD,
	REGEN,
	GUARD,       ## Verteidigungshaltung: reduziert erlittenen Schaden prozentual
	ATK_UP,      ## Buff: erhöht ausgeteilten Schaden prozentual
	DEF_UP,      ## Buff: erhöht Rüstung flach
	MANA_REGEN,  ## Buff: regeneriert MP am Zugbeginn
	PROTECT,     ## Beschützer: fängt ALLE Angriffe auf Verbündete ab (auch Flächen!)
	CLEANSE,     ## Kein echter Status: entfernt beim Anwenden alle Leiden vom Ziel
	REVIVE,      ## Kein echter Status: belebt beim Anwenden gefallene Verbündete wieder
	FROZEN,      ## Eingefroren: setzt aus wie Betäubung; physischer Treffer zerschmettert
	CURSED,      ## Fluch (Dunkel): Ziel nimmt prozentual mehr Schaden
	FOCUS,       ## Konzentriert (DQ-Psyche-Up): nächster Angriff +%, wird verbraucht
	# --- Trainings-Zutaten (Waffenbaum-Bausteine) ---
	BLEED,        ## Blutung: Stacks aus % des Trefferschadens, bis zur Kur
	COUNTER,      ## Konter-Haltung: physische Angreifer kassieren % Waffenschaden
	THORNS,       ## Vergeltung: reflektiert % des erlittenen Schadens
	MARKED,       ## Markiert: Ziel nimmt +% Schaden von ALLEN
	ARMOR_BREAK,  ## Rüstungsriss: −% Rüstung des Ziels
	FIRST_STRIKE, ## Erstschlag: handelt nächste Runde garantiert zuerst
	# --- Skillbau 3.0 ---
	EXHAUSTED,    ## Erschöpft (Axt-Besonderheit): der nächste eigene Zug fällt aus
	# --- Buff-/Debuff-Stufen (DQ9: Magic Barrier, Insulatle …) ---
	MAGIE_SCHUTZ,      ## Magieschild: −% erlittener Magieschaden
	ELEMENT_SCHUTZ,    ## Elementschutz: −% erlittener Elementschaden (alle Elemente)
	MAGIE_BRUCH,       ## Magiebruch: +% erlittener Magieschaden
	ELEMENT_SCHWAECHE, ## Elementschwäche: +% Schaden durch EIN Element (das des Zaubers)
	ENTZAUBERN,        ## Kein echter Status: entfernt beim Anwenden alle Buffs vom Ziel
	# --- Körper-Quelle & DQ9-Ergänzungen (2026-10-19) ---
	DECKUNG,           ## Gedeckt: Angriffe auf dieses Ziel trifft sein Beschützer (bis Rundenende)
	PROVOKATION,       ## Provoziert: Gegner greifen bevorzugt diesen Helden an
	EISERNE_ABWEHR,    ## −% erlittener physischer Schaden bis Rundenende
	ZORN,              ## jeder erlittene Treffer gibt eine Stufe Stärken
	SCHWEIGEN,         ## kann keine Zauber-Skills einsetzen
	EILE,              ## +% Tempo (Stufen)
	ZAUBERSPIEGEL,     ## gegnerische Zauber werden auf den Zaubernden zurückgeworfen
	LEBENSGABE,        ## Kein echter Status: gibt dem Ziel % der eigenen Max-HP
	INNERE_RUHE,       ## Kein echter Status: heilt % Max-HP und entfernt Leiden
	MANARAUB,          ## Kein echter Status: % des Schadens kommen als MP zurück
}


static func physical_subtype_name(subtype: PhysicalSubtype) -> String:
	match subtype:
		PhysicalSubtype.SLASH: return Loc.pick("Schnitt", "Slash")
		PhysicalSubtype.PIERCE: return Loc.pick("Stich", "Pierce")
		PhysicalSubtype.BLUNT: return Loc.pick("Stumpf", "Blunt")
	return "?"


static func armor_class_name(armor_class: ArmorClass) -> String:
	match armor_class:
		ArmorClass.LEATHER: return "Leder"
		ArmorClass.CHAIN: return "Kette"
		ArmorClass.PLATE: return "Platte"
		ArmorClass.FELL: return Loc.pick("Fell", "Hide")
		ArmorClass.KNOCHEN: return Loc.pick("Knochen", "Bone")
	return ""

## Verstärker/Modifikator-Typen für Skill-Bausteine.
enum SkillModifier {
	MULTI_HIT,       ## (Altbestand, ungenutzt — heute: TREFFER)
	COST_REDUCTION,  ## Reduziert MP-Kosten (magnitude = Prozent)
	POWER_AMP,       ## (Altbestand, ungenutzt — reiner Mehrschaden ist kein Klotz mehr)
	CHAIN_ON_KILL,   ## (Altbestand, ungenutzt — heute: TREFFER + ZIEL_WECHSEL)
	SPREAD,          ## (Altbestand, ungenutzt — heute: Form „Alle Gegner“)
	PIERCE_ARMOR,    ## Durchdringung: ignoriert Teil der Rüstung/Resistenz (Prozent)
	EXECUTE,         ## Hinrichtung: Bonus gegen Ziele unter 30% HP (Prozent)
	OVERLOAD,        ## Überladung: mehr Schaden (Prozent), aber +50% MP-Kosten
	VS_UNDEAD,       ## (Altbestand, ungenutzt)
	# --- Trainings-Zutaten (Waffenbaum-Bausteine) ---
	RAGE,            ## Wut: bis +% Schaden, je mehr eigene HP fehlen
	OPENER,          ## (Altbestand, ungenutzt)
	ECHO,            ## Echo: der Skill wiederholt sich nächste Runde mit 50%
	OVERHEAL_SHIELD, ## Überheilung: Heilung über Max-HP wird zu Schild-HP (%)
	# --- Skillbau 3.0: Grundbausteine (frei kombinierbar) ---
	TREFFER,           ## +1 Treffer; alle Treffer teilen sich den Schaden (stapelbar)
	TREFFER_VOLL,      ## Zusatztreffer verlieren keinen Schaden mehr
	ZIEL_ZUFALL,       ## jeder Treffer wählt einen zufälligen Gegner
	ZIEL_WECHSEL,      ## jeder weitere Treffer geht auf einen anderen Gegner
	UEBERSCHLAG,       ## Schaden über die Rest-HP hinaus trifft den nächsten Gegner
	KRIT_BONUS,        ## +% Krit-Chance
	KRIT_MULT,         ## Krit-Multiplikator in % (250 = ×2,5)
	ALLES_ODER_NICHTS, ## Krit ×3, ohne Krit kein Schaden
	SCHWACHSTELLE,     ## +% Schwachstellen-Chance (Schwachstelle ×2, mit Krit ×4)
	VOLLTREFFER_MULT,  ## Krit + Schwachstelle trifft mit diesem Multiplikator (%)
	ZEIT_FLINK,        ## handelt als Erster der Runde
	ZEIT_WUCHT,        ## handelt als Letzter der Runde
	AUFLADEN,          ## wirkt erst im nächsten eigenen Zug
	BLUTPREIS,         ## kostet HP statt MP
	ENTZUENDEN,        ## +% gegen brennende Ziele, löscht den Brand
	AUSNUTZEN,         ## +% gegen betäubte, gefrorene oder verlangsamte Ziele
	NACHSETZEN,        ## +% gegen Ziele, die ein Verbündeter diese Runde schon traf
	DUELL,             ## +% gegen das Ziel, das man zuletzt selbst getroffen hat
	KEIN_ERSCHOEPFT,   ## Axt: keine Erschöpfung (dafür kein doppelter Schaden)
	ZERMALMEN,         ## +% gegen Ziele mit Rüstungsriss
	ELEMENT_FOKUS,     ## Element-Signaturen dieses Skills ×2
	VOLLHEILUNG,       ## heilt bis voll; MP nach Bedarf, sonst alle MP für so viel wie möglich
	SERIE,             ## +magnitude Treffer; je Treffer aufs selbe Ziel stärker (10 % » 100 %, zugübergreifend)
	RUECKSCHLAG,       ## mehr Schaden, magnitude % des Schadens treffen den Anwender
}

enum EquipSlot {
	WEAPON,
	OFF_HAND,
	HELMET,
	ARMOR,
	GLOVES,
	BOOTS,
	RING_1,
	RING_2,
	AMULET,
}

enum Rarity {
	COMMON,
	MAGIC,
	RARE,
	EPIC,
	LEGENDARY,
}

enum Biome {
	FOREST,
	CAVE,
	RUINS,
	CRYPT,
}

## Bewegungsverhalten der Gegner im begehbaren Dungeon (nicht im Kampf).
enum Temperament {
	AGGRESSIVE,   ## Verfolgt den Spieler immer, sobald in Wahrnehmungsreichweite
	TERRITORIAL,  ## Reagiert nur aus kurzer Distanz, sonst wie AGGRESSIVE
	SKITTISH,     ## Flieht vor deutlich stärkeren Spieler-Parteien, sonst zögerlich
}

## Wie ein Skill-Baustein freigeschaltet wird (DESIGN.md Abschnitt 4).
enum UnlockKind {
	LEVEL,     ## Automatisch ab Charakter-Level
	TRAINING,  ## Waffen-Training: investierte Skillpunkte in einer Gattung
}

enum ConsumableEffect {
	HEAL_HP,        ## Stellt HP wieder her
	RESTORE_MP,     ## Stellt MP wieder her
	CURE_AILMENTS,  ## Entfernt negative Statuseffekte
	REVIVE,         ## Belebt einen Gefallenen wieder (potency = % Max-HP)
}
