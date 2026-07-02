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
Skills werden aus unabhängigen Bausteinen zusammengesetzt. Ein Skill kann eine, mehrere
oder alle drei Schadensachsen gleichzeitig nutzen:

- **Schadensachsen (unabhängig voneinander, kombinierbar):**
  - *Physisch* — z.B. Schwerthieb, roher Nahkampfschaden
  - *Magisch (raw)* — z.B. Feuerball-Rohschaden, reiner Zauberschaden
  - *Elementar (DoT/Status-lastig)* — z.B. Brand-, Gift-Schaden über Zeit
- **Physische Schadensarten (festgelegt 2026-07-02):** Stich, Schnitt, Stumpf —
  gilt für Waffen UND physische Skill-Bausteine. Rüstungstypen (Leder neutral,
  Kette stark vs. Schnitt, Platte stark vs. Schnitt/Stich aber schwach vs. Stumpf)
  mindern sie unterschiedlich stark
- **Support-Magie:** Bausteine zum Schützen/Buffen des Teams — Verteidigung erhöhen
  (Wappnen), Schaden erhöhen (Stärken), HP-/Mana-Regeneration, Debuffs entfernen
  (Reinigen), Schild — plus **Schutzwall**: ein Held stellt sich vor das Team und
  fängt Einzelziel-Angriffe auf Verbündete ab (neuer "Selbst"-Träger)
- **Träger/Form:** Projektil, Flächeneffekt, Nahkampf-Treffer, Beschwörung, Aura
- **Zusatzeffekt/Status:** Betäubung, Verbrennen, Verlangsamen, Lebensraub, Buff/Debuff
- **Verstärker/Modifikatoren:** Reichweite, Mehrfachtreffer, geringere Kosten, Kettenreaktion bei Kill

### Freischaltung neuer Bausteine
- **Basis-Bausteine:** automatisch über Charakter-Level
- **Spezielle/mächtige Bausteine:** permanent freischaltbar über einen **Forschungstisch**
  im Hub, bezahlt mit Gold

### Skill-Crafting-UI
- **Sockel/Drag&Drop-Grid** (ähnlich Path of Exile Gem-Links): Bausteine als Icons, die
  frei in begrenzte Sockel gezogen werden — passt gut zum modularen Bausteinsystem und
  bleibt visuell verständlich auch bei vielen Kombinationsmöglichkeiten

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
- **Generierung:** Baukasten-Gegner — prozedural aus Teilen zusammengesetzt
  (analog zum Skill-/Item-System), hohe Varianz auch bei Bossen

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
