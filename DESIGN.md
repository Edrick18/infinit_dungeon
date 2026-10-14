# Infinit Dungeon — Konzept-Dokument (Stand: 2026-07-02)

## Kurzbeschreibung
Klassenloses, rundenbasiertes JRPG mit prozedural generierten Dungeons, Party-System und
freiem Skill-Crafting. Ausrüstung und selbst gebaute Skills definieren die Rolle des
Charakters statt einer festen Klasse. Solo-Hobbyprojekt mit ambitioniertem Scope, Godot-Engine.

---

## 1. Tech & Scope
- **Engine:** Godot 4.x mit GDScript (schnellste Solo-Iteration, ausreichend performant
  für ein rundenbasiertes JRPG)
- **Team:** Solo-Entwicklung, ambitionierter Umfang (kein reines MVP, aber iterativ gebaut)
- **Grafik:** 2D Pixel-Art, klassische JRPG-Kampfansicht (Party vs. Gegner)

## 2. Kampfsystem
- Rundenbasiert, klassisches JRPG-Kampf-Feeling (à la Final Fantasy/Dragon Quest)
- Party aus 3-4 Charakteren
- **Skill-Slots:** alle 5 Charakterlevel ein zusätzlicher Slot, kein Level-Cap
  → Charaktere werden im Lauf der Zeit spürbar vielseitiger, kein hartes Deckelung des Builds

## 3. Klassenlos: Ausrüstung & Charakteraufbau
- Keine festen Klassen. Rolle ergibt sich aus:
  - **Ausrüstung** (klassisch umfangreiches Slot-System: Waffe, Off-Hand/Schild, Helm,
    Rüstung, Handschuhe, Stiefel, 2 Ringe, Amulett)
  - **Waffen** haben Schadensprofile (Schwert = Stich+Schnitt, Bogen/Dolch = Stich,
    Axt = Schnitt, Knüppel/Hämmer = Stumpf) und sind ein- oder zweihändig —
    **Zweihänder blockieren den Nebenhand-Slot**
  - **Skill-Crafting** (siehe Abschnitt 4)
- **Stat-System:** klassische RPG-Attribute (STR/INT/VIT/SPI/AGI/LCK), plus Level-Ups
- **Balance-Formel:** einfach linear — jeder Punkt in einem Stat gibt einen festen,
  gleichbleibenden Bonus (z.B. 1 STR = +X physischer Schaden). Leicht verständlich und
  leicht zu balancieren; falls sich das Endgame zu flach anfühlt, später gezielt durch
  Ausrüstungs-/Skill-Effekte statt Stat-Kurven-Änderung gegensteuern

### Progression (festgelegt 2026-07-02)
- **Kein Level-Cap** — weder für Helden noch für Karten, alles ist unbegrenzt
- **Bis zu 4 Helden gleichzeitig** in der Party
- **Alle Helden starten identisch:** Level 1, 5 Punkte auf jedem Attribut —
  keine Startklassen, kein vordefiniertes Wachstum
- **Jedes Level gibt 5 frei verteilbare Statuspunkte** — Skillung (Punkte),
  Bauklötze (Skills) und Gear entscheiden, welche Rolle ein Held im Team einnimmt

## 4. Freies Skill-Crafting

### Waffengetriebener Schaden (festgelegt 2026-07-03, Phase-3-Rework)
Der Schaden steckt **in der Waffe**, nicht im Baustein. Bausteine bestimmen nur noch,
*wie* geliefert wird, nicht *wie viel*. Alle Team-Mitglieder haben eine **Startwaffe**.

**Grundidee (Skillbau 3.0, Lutz 2026-10-13):** ein JRPG, in dem jeder seine Skills selbst
baut — begrenzt durch Sockel und das, was freigeschaltet ist. **Keine fertigen Muster als
Klotz** (Streuung, Hagel, Kette, Durchbohren …) und kein reiner „+Schaden“-Klotz: Muster
baut man aus Grundbausteinen, jede Eigenschaft hat einen Preis.

**Baustein-Kategorien:**
1. **Quelle** (mind. 1 Pflicht):
   - **Waffenangriff** — physisch; Schaden + Schadensart von der Waffe, inkl. ihrer
     **Besonderheit** (siehe unten).
   - **Zauber** — Schaden = Zauberschaden der Waffe + INT, Einzelziel; Element aus dem
     Element-Klotz (sonst roh magisch).
2. **Element** (max. 1): Feuer / Eis / Blitz / Gift / Heilig / Dunkel — am Zauber voll, an
   der Waffe als halber Zusatztreffer.
3. **Form** (max. 1): Alle Gegner / Verbündeter / Aura / Selbst / Beschwörung. Waffenangriffe
   nur mit „Alle Gegner“. Zielwahl-Eigenschaften (Zufallsziel, Wechselziel) zählen als Form.
4. **Effekt** (je einmal): Buffs, Debuffs, Schutz, Wiederbeleben, Betäuben … Jeder Effekt
   hat ein **Ziel**: das Trefferziel — oder (Figuren-Marke) den Anwender, die Party bzw.
   alle Gegner, dann einmal pro Skill (so stärkt auch ein Schwerthieb die Party).
   Gift/Brand/Blutung mit Dauer „bis zur Kur“ skalieren mit dem Trefferschaden.
5. **Eigenschaften** (Modifikatoren):
   - **Zusatztreffer** (stapelbar): +1 Treffer, alle Treffer teilen sich `1 + 15 %` je
     Zusatztreffer. Mit **Zufallsziel** = Hagel, **Wechselziel** = Fächer/Kette,
     **Überschlag** = Überschuss trifft den Nächsten.
   - **Mit Preis:** Präzision (+30 % Krit, ×0,9), Wucht (×1,5, handelt zuletzt), Flinkheit
     (handelt zuerst, ×0,75), Aufladen (nächster Zug, ×2), Sparsam (−40 % MP, ×0,75),
     Blutpreis (HP statt MP), Alles oder nichts (Krit ×3, sonst 0), Durchschlag (×0,85),
     Schwachstelle suchen (×0,85), Überladung (mehr Schaden, ×1,5 Kosten).
   - **Kombos:** Ausnutzen (betäubt/gefroren/verlangsamt), Entzünden (brennend, löscht den
     Brand), Nachsetzen (ein Verbündeter traf diese Runde), Zermalmen (Rüstungsriss),
     Duell (zuletzt selbst getroffen), Hinrichtung (< 30 % HP), Rache (eigene fehlende HP).
- **Treffer-Arten:** Krit ×1,5 · Schwachstelle ×2 · beides = **Volltreffer ×4**.
- **Kombis:** z.B. *Flammenhieb* = Waffenangriff + Feuer; *Pfeilhagel* = Waffenangriff +
  2× Zusatztreffer + Zufallsziel; *Kettenblitz* = Zauber + Blitz + 2× Zusatztreffer +
  Wechselziel.

### Waffen-Besonderheiten (Skillbau 3.0, 2026-10-13)
Gelten für jeden Waffenangriff (freier Angriff und Skills) — sie geben jeder Waffe ein
eigenes Spielgefühl, ohne ein Angriffsmuster vorzuschreiben:
Dolch trifft **doppelt** (je 60 %) · Axt: höchster Grundschaden (12 / Zweihand 21) und **×2, danach erschöpft** (nächster eigener Zug
fällt aus; Klotz „Unermüdlich“ hebt das auf, dann kein ×2) · Bogen 15 % Schwachstelle
(+Glück/3) · Armbrust durchschlägt 50 % Rüstung + zweites Ziel mit 40 % · Schwert 20 %
Parade (Hälfte zurück) · Hammer 15 % Betäubung · Offensivstab Element-Signaturen +50 % ·
Heiligstab Heilung +50 % · Schild 25 % Block.

**Symmetrie der Formen:** Einzelziel ↔ Fläche (Gegner), Verbündeter ↔ Aura (Freunde).

### Waffen & Stäbe
- **Nahkampf/Fernwaffen** (Schwert/Axt/Bogen/…): physischer Waffenschaden + Schadensart.
- **Offensivstab:** hoher Zauberschaden, verstärkt Angriffs-Zauber.
- **Heiligstab:** macht heiligen Schaden; Heil-Zauber wandeln diesen in Heilung um.
- **Gegner** tragen keine Items → Grundtyp hält **innewohnende Waffen-/Zauberwerte**,
  damit ihre Skills identisch rechnen.

### Schadensachsen & Rüstung
- Drei unabhängige, kombinierbare Achsen: **physisch** (Waffennutzung),
  **magisch (raw)** (Zauber ohne Element), **elementar** (Zauber mit Element).
- **Physische Schadensarten:** Stich, Schnitt, Stumpf — von der Waffe bestimmt.
  Rüstungstypen (Leder neutral, Kette stark vs. Schnitt, Platte stark vs. Schnitt/Stich
  aber schwach vs. Stumpf) mindern unterschiedlich.

### Elemente & Signature-Status (festgelegt 2026-07-03)
- **🔥 Brand** — *aufbauend, abklingend:* Treffer fügt Stacks nach Schaden hinzu (addiert);
  pro Tick Schaden = Stacks, danach **Stacks halbieren**. Hoher Burst, kurze Dauer.
- **☠️ Gift** — *aufbauend, permanent:* weniger Stacks als Brand, aber **kein Abklingen** —
  bleiben bis zum Kurieren. Niedriger Dauerschaden, zwingt zum Kurieren.
- **🧊 Eis** — Status *Eingefroren* (wie Betäubung; physischer Treffer zerschmettert früher
  für Bonusschaden) + Slow.
- **⚡ Blitz** — Kettenwirkung (springt auf Nachbarn) + Betäubungs-Chance.
- **✨ Heilig** — Bonusschaden gegen **Untote**; Heil-Umwandlung bei Verbündeten-Zielen.
- **🌑 Dunkel** — Lebensraub + Status *Fluch* (Ziel nimmt mehr Schaden).

### Support-Magie
Wappnen (+Verteidigung), Stärken (+Schaden), HP-/Mana-Regeneration, Reinigen (Debuffs weg),
Schild, Wiederbeleben, **Schutzwall** (fängt ALLE Angriffe auf Verbündete ab, auch Flächen —
kann daran sterben).

### Bauregeln — Baukasten 2.0 (festgelegt 2026-10-13)
- **Sockel nach Level:** 3 auf Level 1, je +1 auf Level 8 / 18 / 30 / 50 und nach der
  ersten Wiedergeburt → max. 8 Klötze pro Skill (höchstes je erreichtes Level zählt).
  Gegner haben kein Sockel-Limit.
- **Keine Werte-Anforderungen:** Ist ein Klotz freigeschaltet, darf man ihn einbauen.
- **Einzigartig:** jeder Klotz nur einmal pro Skill (außer Zusatztreffer). **Gruppen (◆):**
  je höchstens ein Klotz — Waffenquelle, Zauberquelle, Form/Zielwahl, Element und
  Varianten-Gruppen (Krit-Chance, Krit-Wucht, Schwachstelle, Zeitpunkt, Kosten,
  Hinrichtung, Durchschlag, Überladung, Rache, Betäuben, Rüstungsriss, Verlangsamen,
  Schwächen, Stärken, Wappnen, Schild …; Tabelle `BlockLibrary.REGELN/GRUPPEN`).
  **Kern (★):** höchstens einer pro Skill — der höchste Klotz jedes Waffen-Baums, Echo,
  Klingentanz, Beschwörung, Wiederbeleben.
- Hybrid **Waffe + Zauber** bleibt erlaubt (zwei Treffer, beide Kosten) — mehr Vielfalt.
- Verletzt ein (alter) Skill eine Regel, bleibt er gespeichert und wird mit dem
  konkreten Grund gesperrt (Werkstatt + Kampfmenü), nichts wird gelöscht.

### Mana-Kosten (2026-07-02, überarbeitet 2026-10-13)
`Basis = Σ Klotz-Grundkosten + Stat-Anteil je Quelle` → `Kosten = Basis × Form-Faktor ×
Π Kostenfaktoren`. Effekte addieren flach, **Eigenschaften multiplizieren** (Zusatztreffer
×1.2 je Stück, Überladung ×1.5, Überschlag ×1.25, Echo ×1.35 …) und tragen einen
**Schadensfaktor** (Wucht ×1.5, Präzision ×0.9 …) — große Skills sind stark, aber teuer.
- **Waffenangriff:** 1 MP + 15 % STR, Schaden ×1.2 gegenüber dem freien Angriff.
- **Zauber:** 3 MP + 25 % INT. Ihre Daseinsberechtigung: Formen (Fläche, Aura,
  Verbündeter, Selbst, Beschwörung), Heilung/Support und die volle Element-Signatur
  (an der Waffe nur halber Zusatztreffer), magisch statt gegen Rüstung.
Stärker = teurer, dadurch bleiben MP-Kosten ohne Level-Cap relevant.

### Keine Abklingzeiten (Lutz, 2026-10-13)
Wie in Dragon Quest: Solange das Mana reicht, kann jeder Held **jeden Skill in jedem Zug**
einsetzen. Mächtige Kern-Klötze werden nur über ihre Kostenfaktoren ausbalanciert.

### Schwächen, Erstschlag & Überlegenheit — Phase 2 (2026-10-13)
- **Element-Schwächen/-Resistenzen** je Grundtyp (×1.5 / ×0.5, Tabelle
  `EnemyLibrary.SCHWAECHEN`), gelten für jeden Elementtreffer inkl. Brand-/Gift-Stacks.
  Element-Schicht (Feuer-Wolf …): eigenes Element ×0.5, Gegenteil ×1.5 (Feuer↔Eis,
  Blitz↔Gift, Heilig↔Dunkel; Untote nicht doppelt heilig-schwach).
  **Entdecken:** erst nach dem ersten Treffer bekannt → Chips am Gegner (▲/▼), dauerhaft
  im Spielstand (`GameState.element_wissen`) und im Bestiarium.
- **Anschleichen:** ruhende Gegner sehen nur nach vorn (±110°) plus Hörradius; jagende
  verfolgen rundum (`Anschleichen`).
- **Erstschlag/Hinterhalt:** Kontakt mit dem Rücken des Gegners → in Runde 1 handelt nur
  die Party. Verfolger erwischt den weglaufenden Helden von hinten → nur die Gegner
  (keine Befehlsphase). Mimics immer Hinterhalt.
- **Überlegenheit (DQ):** Party ≥ 8 Level über Karte + Ebene + Raritätsbonus → jeder
  normale Gegner flieht; Berühren = Sofortsieg mit halber XP, halbem Gold, ohne Items.

### Geist & Kontrolle (2026-10-13)
- **SPI ist der Support-Wert:** Schild, Regeneration, Mana-Fluss, Wappnen × (1 + SPI/40),
  Heilung × (1 + SPI/100).
- **Bosse:** Betäuben/Einfrieren mit halber Chance, jeder Erfolg +50 % Kontroll-Resistenz
  (für den Kampf).

### Freischaltung neuer Bausteine (Skillbau 3.0)
- **Universelle Klötze (39)** über das **Charakter-Level** — „bei jedem Level etwas Neues“:
  Level 1 das Fundament (Waffenangriff, Zauber, Selbst, Zusatztreffer), Level 2–20 jedes
  Level einer, danach alle 2–5 Level bis Beschwörung auf 60. Der Level-up nennt sie.
- **Waffen-Klötze (81)** über das **Waffen-Training** (DQ9-Stil, +3 Punkte pro Level, pro
  Gattung), 7–12 je Waffe, Schwellen 3 bis 100, nur mit der Waffe nutzbar; der höchste
  jedes Baums ist Kern. Dazu %-Passive an den Zwischen-Schwellen.
- Alte Spielstände: entfernte Klötze werden beim Laden umgeschrieben (`BlockLibrary.ALIAS`:
  Mehrfachtreffer II → 2× Zusatztreffer, Kette → Wechselziel, Verstärken entfällt).

### Skill-Crafting-UI
- **Sockel/Drag&Drop-Grid** (ähnlich Path of Exile Gem-Links): Bausteine per Drag&Drop
  ODER Klick (landet im gold umrandeten Skill) in die Sockel des Helden.
- Jeder Klotz hat ein **3D-Icon** aus Grundkörpern (`KlotzIcons`, Schwert, Kugel, Flamme,
  Kristalle, Schild, Pfeile …); Sockel zeigen Icon + Name + ◆/★.
- **Beim Ziehen** färben sich die Sockel grün (passt) oder rot (Tooltip = Grund);
  unfertig (noch keine Quelle) ist kein Regelbruch, ein schon vorhandener Fehler sperrt
  nicht (man soll reparieren können) — Regeln in `WerkstattLogik` (getestet).
- **Live-Vorschau** unter jedem Skill: ≈ Schaden (+ über Zeit), Heilung, Zustände,
  Beschwörung — gegen eine Puppe, ohne Krits. Ausführlich weiter über „Testen".
- **Vorlagen** (22 Rezepte, nur mit freigeschalteten Klötzen, passend zu den Sockeln)
  und **Reparieren** für Skills aus der Zeit vor den Bauregeln (erster Klotz gewinnt).
- Filter „Gesperrte zeigen" (ohne fremde Waffen-Klötze), freigeschaltete Klötze zuerst;
  gespeichert wird beim Verlassen, wenn etwas geändert wurde.
- **Rezeptbuch:** beliebig viele gespeicherte Bauten pro Held („Ins Buch“); „In Slot N“
  tauscht mit dem aktiven Slot, der alte Skill wandert ins Buch. In den Kampf gehen nur die
  Slot-Skills (+1 Slot alle 5 Level).
- **Umbauen überall außer im Kampf:** die Werkstatt öffnet auch mitten im Dungeon
  (Taste K, umbelegbar) und kehrt an dieselbe Stelle zurück.

## 5. Loot & Items
- **Itemrarität:** prozedurale Affix-Items (Diablo-Stil) — Basis-Item + zufällige Prefix/Suffix-Eigenschaften
- **Kategorien:** Consumables, Rüstung, Waffen — alle prozedural generiert
- **Wirtschaft:** primär Crafting-Materialien statt/zusätzlich zu Gold; Monster droppen
  Materialien für Schmiede & Forschung

### Tränke/Consumables (festgelegt 2026-07-02)
- **Heilung skaliert:** Tränke geben einen Prozentsatz der Max-HP/MP PLUS einen
  Flat-Wert, der greift, wenn er höher ist — dadurch bleiben Tränke auch auf
  Level 100 relevant
- **Keine Trank-Drops von Mobs:** Gegner/Truhen droppen Crafting-Materialien;
  **alle Tränke sind craftbar** (Alchemist im Hub), die einfachen (Heil-/Manatrank)
  sind zusätzlich beim Händler kaufbar
- **Pro Statuseffekt ein eigener Kur-Trank** (Brandsalbe, Gegengift, Weckelixier,
  Tempotrunk, Stärkungstonikum); das **Allheilmittel** wird aus allen fünf zusammen
  gecraftet und entfernt sämtliche Leiden
- **Hub heilt immer voll** (HP und MP)

### Werkstoffe, Schmiede & Händler (Lutz, 2026-10-14)
- **Werkstoffe** Erz/Leder/Kristall in 5 Stufen (Eisen, Stahl, Mithril, Adamant,
  Sternen); die Kartenstufe bestimmt die Drop-Stufe (ab 1/8/18/32/50), Bosse manchmal
  eine höher. **Runen** (Boss, 25 %) garantieren beim Schmieden Selten/Episch/Legendär.
- **Schmiede:** Reiter je Art; man wählt nur Werkstoff, Item-Level und optional eine
  Rune — Basis, Rarität, Affixe sind Zufall. Gold wächst mit dem Level; Werkstoff-Stufe
  begrenzt das Level (12/26/42/62/offen, höchstens höchstes Helden-Level + 3) und gibt
  je Stufe über Eisen 30 % Chance auf +1 Rarität (nie garantiert).
- **Händler:** Tränke, Kräuter, Werkstoffe der Eisen-Stufe; Ausrüstung nur gegen Gold
  (Art wählbar, Level = Party-Schnitt ±1, sonst Zufall), rund 4× Schmiede-Gold.

### Dynamische Gegner (Lutz, 2026-10-14)
Jede Ebene hat eine Höchstzahl gleichzeitiger Gegner (= Startbestand des Generators).
Gegner ziehen nach 2–4 Minuten weiter (nie während der Jagd oder in Sicht); ein freier
Platz wird nach 8–16 s irgendwo weit weg (≥ 12 Zellen) neu besetzt. Der Bestand liegt im
Run (`gegner_by_floor`), wird gespeichert und an Co-op-Gäste gesendet.

## 6. Dungeons
- **Struktur:** begehbare, zusammenhängende Oberwelt pro Dungeon (keine reine Raum-Kachelung),
  frei erkundbar, Gegner sichtbar in der Welt
- **Kartenstufe = Gegnerlevel:** Karte Stufe 5 → Gegner Level 5
- **Ebenen:** höhere Kartenstufen haben mehrere Ebenen (Stufe 1-4: 1, 5-8: 2, ...,
  max. 5), verbunden über Treppen; **der Boss wartet immer nur auf der untersten Ebene**
- **Freischaltung durch Stufe:** höhere Kartenstufen schalten mehr Dungeon-Varianten frei —
  Biome (Wald ab 1, Höhle ab 3, Ruinen ab 5, Krypta ab 7) und mehr gleichzeitige
  Karten-Modifikatoren (bis zu 4)
- **Dauer:** mittel, ca. 30-60 Minuten pro Dungeon
- **Dungeon-Karten-System (zentral!):**
  - Dungeon-Layouts werden als "Karten" gespeichert, wiederholbar und farmbar
  - Karten können gezielt behalten werden, um bestimmte Gegner-Drops zu farmen
  - Karten sind löschbar
  - Nach Abschluss eines Dungeons erhält man eine **neue Dungeon-Karte auf Stufe ±3**
    relativ zur abgeschlossenen Stufe (ähnlich Path-of-Exile-Maps/Diablo-Rifts-Prinzip)
  - **Kartenlager:** großzügiger Start mit 25+ Slots, im Hub gegen Gold erweiterbar —
    wenig frühe Frustration durchs Wegwerfen-Müssen, Erweiterung dient v.a. dem
    Endgame-Hoarding vieler guter Karten
  - **Elite-/Boss-Modifikatoren:** werden bei Karten-Erstellung fix festgelegt und bleiben
    bei jedem Betreten gleich → Karten sind gezielt "planbar" zum Farmen bestimmter
    Kombinationen
- **Wipe-Konsequenz:** bei Niederlage der ganzen Party geht es zurück zum Hub, die
  Dungeon-Karte bleibt erhalten (kein Kartenverlust, nur Zeitverlust)

## 7. Gegner & Bosse
- **Geschichtete Generierung (festgelegt 2026-07-03, Phase-3-Rework)** — wie beim Loot:
  **Grundtyp + Schichten**:
  - **Grundtyp:** Skelett, Wolf, Schleim, Golem, Spinne, Troll, Geist, Nekromant …
  - **Region-Variante:** Wald-/Höhlen-/Ruinen-/Krypta-… (Stat-Multiplikator + evtl.
    innewohnendes Element) → „Wald-Skelett"
  - **Element-Typ:** Brand-/Frost-/Gift-/Blitz-… (Elementangriff + Resistenz) →
    „Brennendes Wald-Skelett"
  - **Elite-Modifikatoren:** Anzahl skaliert mit **Rarität** (Normal → Elite → Champion)
- **Pool-Wachstum über Level:** Alle 5 Dungeon-Stufen kommen neue Grundtypen dazu.
  **Biome haben ein Level-Fenster** — Wald & Höhle findet man früh, ab höheren Stufen
  verschwinden sie und werden durch höhere Biome + stärkere Varianten ersetzt → Pool
  bleibt frisch.
- **Bosse:** rein prozedural, mehr Varianz — eigener Boss-Modifikator-Pool (Berserker,
  Beschwörer, Elite-Panzerung); Bosse würfeln mehr Modifikatoren.
- **Untot-Tag** auf Skelett/Kultist/Geist/Nekromant → Synergie mit Heilig-Schaden.

## 8. Content-Roadmap (Phase 3, festgelegt 2026-07-03)
Reihenfolge (Systemumbauten zuerst):
1. **Waffengetriebener Schaden** — Quell-/Form-Bausteine, Startwaffen, Stab-Varianten,
   Gegner-Innenwerte, Basisangriff + Tests umstellen
2. **Elemente + Stack-Status (Brand/Gift) + neue Modifikatoren**
3. **Beschwörungen** (SUMMON als Form)
4. **Geschichtete Gegner-Generierung + Biom-Level-Fenster**
5. **Loot-Erweiterung** — mehr Waffen/Stäbe, elementare Affixe, elementare Resistenzen,
   skill-modifizierende Suffixe (**keine Unikate/Sets** — bei Random-Drops nie
   zuverlässig sammelbar)
6. **Dungeon-Events** — Schreine, Risiko-Truhen/Mimics, Opfersteine, Statuen, Elite-Packs
   (**keine Fallen**)

## 8. Hub-Bereich (zwischen Dungeon-Läufen)
- Forschungstisch (Skill-Bausteine freischalten, siehe Abschnitt 4)
- Schmiede/Crafting-Werkstatt (Ausrüstung verbessern/craften aus Materialien)
- Händler/NPCs mit Aufträgen (Kauf/Verkauf, Nebenquests)
- Party-Rekrutierung: **feste, handdesignte Charaktere** mit eigenem Aussehen/Namen/Persönlichkeit,
  die nach und nach freigeschaltet werden (kein Zufallsrekrut)

## 9. Meta-Progression
- **Kein Permadeath** — persistenter Charakter/Party zwischen Dungeon-Läufen
- Charakter behält Level, Ausrüstung, freigeschaltete Bausteine dauerhaft
- Fortschritt kommt aus: Charakterlevel, Ausrüstung, Forschungstisch-Freischaltungen,
  Dungeon-Kartensammlung

## 10. Story & Setting
- **Setting:** klassisches High Fantasy
- **Story-Umfang:** minimal — grober Rahmen reicht, Fokus liegt komplett auf
  Loot/Build/Kampf-Gameplay-Systemen

---

## 11. Vertical Slice (erstes Entwicklungsziel)
Kompletter Mini-Loop, der die Kernschleife des ganzen Spiels einmal end-to-end zeigt:
1. **Hub** mit Forschungstisch (auch wenn nur 1-2 Bausteine freischaltbar sind)
2. **Ein Dungeon** mit dem Kartensystem (Karte generieren, speichern, betreten)
3. Rundenkampf mit einer kleinen Party (2-3 Charaktere reichen für den Slice)
4. Rückkehr zum Hub nach Abschluss/Wipe, **neue Karte auf Stufe ±3** wird ausgestellt
5. Ein Durchlauf: Loot einsammeln → im Hub craften/verkaufen → erneut in eine Karte gehen

Ziel: den Loot→Craft→Dungeon→Loot-Kreislauf so früh wie möglich spielbar/fühlbar machen,
auch mit stark reduziertem Content (wenige Bausteine, ein Gegnertyp, ein Kartenlevel-Bereich).

---

## Status
Alle grundlegenden Design-Fragen sind geklärt. Das Konzept ist bereit für die Umsetzung
des Vertical Slice (Abschnitt 11). Einzig konkrete Zahlenwerte (z.B. genaue Erweiterungskosten
fürs Kartenlager, exakte Stat-Bonus-Werte) werden erst während der Implementierung/des
Playtestings final austariert — das ist normales Balancing, kein offener Design-Punkt mehr.
