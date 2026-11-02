# STIL-3D — Design-Standard „Infinit Dungeon 3D"

Verbindliche Regeln für ALLE 3D-Grafik. Umsetzung: `scripts/stil3d/`
(`Stil3D` = Bausteine, `FigurenBau` = Figuren/Objekte), Vorschau:
`scenes/stil3d/stil_showcase.tscn` (F6).

## 1. Grundsatz: Spielzeug-Diorama aus Grundkörpern
Alles entsteht im Code aus fünf Grundkörpern — **Kugel, Box, Zylinder/Kegel,
Kapsel, Prisma** (dazu die gefaste Box `WeltMaterial.fasen_box`). Keine
externen Modelle, keine Bilddateien, keine KI-Bilder. Oberflächen-Material
(Mauerwerk, Plattenrisse, Moos, Runen) entsteht **prozedural im Shader** aus
der Weltposition — es ist Bemalung, keine Textur.
Warum: endlos erweiterbar, jede Variante ist ein Parameter (Farbe, Maß,
Zusatzteil), alles bleibt automatisch stilgleich.
**Gebacken statt verschachtelt:** Statische Objekte mit vielen Teilen
(Truhe, Tresor, Schrein, Altar, Feuerschale, Banner, Wandkronen, Deko)
baut `Bausatz` (`scripts/stil3d/bausatz.gd`) aus denselben Grundkörpern zu
EINEM Mesh mit Vertexfarben plus einer Kontur-Hülle — zwei Zeichenaufrufe
statt zwei je Teil; als MultiMesh zwei je Variante, egal wie oft.
Vertex-Alpha < 1 = Eigenleuchten (Flammen, Kristalle, Runen).
**Figuren gebacken je Gelenk** (Figuren 2.0, Abschnitt 7g): eine Figur ist
EIN gebackener Rumpf plus je Gelenk (Arm, Kopf, Flügel …) ein gebackenes
Teil — 2 Zeichenaufrufe je Teil, gleiche Gegner teilen dieselben Meshes
(Helden und Zweibeiner: Abschnitt 7h, Vierbeiner und Schleime: 7i,
Krabbler/Flieger/Golems/Geist/Mimic: 7j). Seit 7j ist JEDER Gegner eine
Gliederpuppe — keine Einzel-Grundkörper-Figuren mehr. Die Figurgröße steckt
als `Bausatz.massstab` im Mesh (Kontur bleibt 0.022). Neben den
Grundkörpern kennt der Bausatz `fasenbox` (gefaste Steinblöcke),
`halbzylinder` (gewölbte Deckel) und `dreieck` (Flughäute, Membranen) —
jeweils mit gleich dicker Hülle.

## 2. Maßstab & Ausrichtung
- 1 Einheit = 1 Dungeon-Feld. Boden bei y = 0. Figuren blicken nach +Z.
- Normale Gegner 0.6–1.0 hoch, große 1.2–1.5, Bosse bis 2.0
  (zusätzlich `sprite_scale` der Archetypen gilt weiter als Skalierung).
- Proportionen leicht chibi: Köpfe groß, Beine kurz, Silhouette vor Detail.

## 3. Formensprache
- **Rund** (Kugel, Kapsel) = weich, flink, verspielt (Schleim, Fledermaus).
- **Kantig** (Box) = schwer, gepanzert, Konstrukt (Golem, Truhe, Mauern).
- **Spitz** (Kegel, Prisma) = gefährlich (Zähne, Hörner, Mähne, Flügel).
- Ausdruck über das Gesicht: Cartoon-Augen (`Stil3D.auge`) + böse Brauen
  (`Stil3D.braue`), kleine Zähne. Frech-fies, nie Horror.
- **Augen-Standard** (Figuren 2.0, `Gliederpuppe.auge`): weiße Kugel +
  Iris (Palettenfarbe, bei Verfluchten/Untoten leuchtend) + Pupille (rund,
  Schlitz bei Katze, Dämon, Schatten) + Glanzpunkt oben außen; Untote statt
  Weiß eine dunkle Höhle mit Glühpupille. Brauen böse (innen tief) oder
  besorgt (innen hoch), alles ohne Hülle.

## 4. Farbe
Nur Farben aus `Stil3D.PAL` (Hauspalette, Grundton Nachtblau `#14141f`,
Akzent Gold `#e8b44a`). Neue Farbe = erst in PAL aufnehmen, dann benutzen.
Helligkeits-Variation per Faktor (z. B. `farbe * 0.93`), nie freie Hexwerte
(der Geist hatte einen — jetzt PAL `geist` und `geist_tief`).
Biom-Flächen, Leuchtfugen und Untergrund stehen als eigene PAL-Einträge
(`wald_boden`, `krypta_fuge`, `hoehle_tief` …) und werden über `BiomStil`
benutzt. Lichtfarben (Sonne, Umgebung) sind Lichtwerte, keine Flächenfarben.
Auch die Oberfläche hat keine eigene Farbwelt mehr: `UiTheme` liest ihre
Rollenfarben (Gold, Messing, Fokus, Text, Warnrot, HP/MP) aus PAL
(`ui_holz*`, `messing*`, `fokus`, `ui_text*`, `pergament*`, `tinte`,
`hp_gut`, `warnrot`, `mana` — Abschnitt 7e). Einzige Ausnahme bleibt die
Seltenheit: `LootGenerator.RARITY_COLORS` ist ihre Quelle.

## 5. Licht & Shader
- Toon-Shader mit **zwei harten Lichtstufen nur auf dem Lichteinfall N·L**
  (Cel-Shading, `Stil3D.TOON_LICHT`). Die Reichweite der Punktlichter
  (ATTENUATION) läuft **weich** aus — keine harten Laternen-Scheiben oder
  Fackel-Ellipsen. Alle Stil-Shader (Figuren, Wände, Boden) teilen diesen
  Licht-Block.
- Schattenseiten tönt das **violette Umgebungslicht** — nie schwarz.
- Hauptlicht warm, von rechts-hinten (Kontrast statt Frontalbrei).
- Fackeln: orange Punktlichter, flackern. Im Dungeon tragen sie kein
  eigenes Licht (Licht-Pool, 7b); in Menü und Kampfhalle je ein OmniLight
  mit flachem Abfall (`Stil3D.PUNKTLICHT_ABFALL`) und Energie mal
  `Stil3D.PUNKTLICHT_AUSGLEICH` — sonst verlören Fackeln und Feuer dort mit
  der weichen Abschwächung ihre warmen Flecken. Die Kampfhalle hat genau
  vier (Licht-Budget, 7c).
- Schmaler Randlicht-Saum, Leuchtteile (Augen, Kristalle, Flammen) über
  `leuchten` + Glow.

## 5b. Bildstimmung „Spielbrett im Laternenschein" (Dungeon)
- **Grundhelligkeit wie ein beleuchtetes Spielbrett** — gut lesbar, kein
  Fog of War, nichts versinkt im Dunkeln. Darüber eine **warme
  Laternen-Insel** um den Helden und warme Fackel-Lichtpunkte.
- **Tonemapping Filmic** (`Stil3D.umgebung`, Belichtung 0.9), Glow ab 0.9,
  leichte Sättigung/Kontrast. AgX wäre in Compatibility 4.7 verfügbar,
  bleicht aber Flammen, Augen und Gold zu Weiß aus. Debanding am Viewport
  an, Vignette als CanvasLayer (-1) unter der UI mit geditherter Blende.
- **Material (Spielbrett):** Mauerwerk aus der Weltposition — Ziegel (Wald,
  Ruinen mit größeren Quadern), Bruchstein (Höhle), Gruftquader (Krypta);
  Moos kriecht von unten (Wald, Höhle), gefaste Decksteine mit leichtem
  Höhen-Jitter. **Der Deckel ist nie die hellste Fläche** (dunkler als der
  Boden; Kontur und Sockel zeigen die Wand). Boden = gefaste Platten mit
  Abnutzung, Abplatzern, Rissen; Biom-Zweig (Moos, Pfützen, Flecken,
  Runenkreise) und Umgebungsverdeckung an Wandfüßen.
- **Leuchtfugen (dezent):** Boden- und Mauerfugen, Krypta-Runen glimmen in
  Biomfarbe — fast aus in der Ferne, in Heldennähe stärker (Uniform
  `held_pos`). Nie heller als die Glow-Schwelle außer direkt am Helden.
- **Untergrund:** Sternen-Nebel in Biomfarbe unter der Karte statt schwarzer
  Leere (auch auf der Boss-Ebene), mit künstlicher Parallaxe (das Muster
  wandert mit dem Kamera-Ziel).
- **Atmosphäre:** wenige Partikel um das Kamera-Ziel — Wald Glühwürmchen,
  Höhle Tropfen, Ruinen Asche, Krypta Irrlichter.
- Alle Werte je Biom stehen in **einem** Datensatz: `BiomStil`
  (`scripts/stil3d/biom_stil.gd`): Flächen, Muster, Moos, Fugenfarbe,
  Umgebungs-/Sonnen-/Laternenlicht, Untergrund, Partikel und **Kulisse**
  (`kulisse`: Hallen-Säule für die Kampfbühne, Wandkronen, Kronen-Anteil,
  Deko-Varianten).
- **Biom-Kronen** (`BiomKulisse.krone`) auf einem Teil der Wände (per
  Zell-Hash, 26–36 %): Wald Tannen/Laubbaum, Höhle Tropfsteine/Kristalle,
  Ruinen Zinnen/Säulenstümpfe/Bruchkanten, Krypta Gruftaufsätze/Kreuze/
  Grabplatten. Zinnen, Gruft und Platten folgen der Wandrichtung.
- **Deko** (`BiomKulisse.deko`): größere Biom-Gruppen statt Einzelstücke —
  Wald Farne/Pilzgruppen/Wurzeln/Felsen, Höhle Kristallgruppen/Tropfsteine/
  Pfützen/Knochen, Ruinen Säulentrommeln/Kisten/Fässer/Trümmer, Krypta
  Sarkophage/schiefe Grabsteine/Kerzen/Knochen. Der Generator wählt Zelle
  und Art wie bisher; die Kulisse macht daraus eine Variante (Zell-Hash).
  **Wege frei:** in schmalen Gängen nur flache Varianten, Gruppen rücken
  an die Wand, alles bleibt im Feld, keine Kollision.
- **Ziele leuchten:** Truhen (Raritätsfarbe), Schreine (Typfarbe),
  Opferstein, Risiko-Truhe, Tresor (Gold) und Boss (Rot) tragen eine
  additive **Lichtsäule** mit aufsteigenden Streifen und ein weiches
  Bodenglühen; nur nahe dem Kamera-Ziel sichtbar. Modelle mit Beschlägen,
  gewölbtem Deckel, Schloss, Tresortür, Schrein-Kristall (schwebt, dreht),
  Altar-Kerzen. **Treppe** = Steinrahmen mit leuchtender Innenkante,
  Stufen mit Leuchtkanten, Glühen aus der Tiefe, Lichtsäule, Staub und
  eigenes Pool-Licht — kein dunkler Kasten.
- **Boss-Arena** (nur Optik, Grundriss unverändert; `WeltBau.boss_raum`
  liest den 9×9-Raum aus dem Grundriss): rotes Bodensiegel (Runenring +
  Stern, pulsiert ruhig — zeigt nie Ziel oder Absicht), Feuerschalen in den
  Ecken und neben der Gangmündung, rote Lichtsäule am Eingang, Boss mit
  Säule, Glutfunken und eigenem roten Pool-Licht.
  **Boss-Lichtsäule** (`DungeonWelt3D._boss_saeule`) = das stärkste Licht
  der Ebene: schmaler heller Kern (9 hoch, gebündelt), breiter roter
  Mantel, der langsam atmet (Shader-Uniforms `beginn`, `ansatz`, `puls`,
  `schaerfe` der Säule). Unterhalb von `beginn` ist die Säule ganz aus: der
  Kern beginnt knapp über dem Scheitel des Bosses (samt Krone), der Mantel
  um seinen Radius höher — er steht in der 45°-Schrägsicht VOR der Figur
  und legte sonst einen roten Schleier über den Boss (Review Paket 4,
  Test in `kampfszene_selftest`). Übrige Säulen: `beginn` 0 wie bisher.
  **Säulenfuß** (Rest Paket 4, Meta `saeule_fuss`): ein zweiter Kern vom
  Boden aufwärts, HINTER dem Boss — gegen die Kamerarichtung um den
  Rumpf-Radius (0.42 × Größe, höchstens der Umriss) + 0.25 versetzt
  (`DungeonWelt3D.saeulen_fuss_versatz`), jedes Bild in Weltlage gehalten
  (der Boss dreht sich davor). Die Figur verdeckt ihn, er liegt nie davor:
  die Säule reicht so sichtbar bis an den Boss, ohne ihn einzufärben.
  Bodenglühen in zwei Lagen (7.2/1.75 und 3.0/1.2, vorher 5.6/2.4 schwächer)
  und an der Säule aufsteigende Funken. Die Torsäule am Arena-Eingang
  (×0.85 statt ×0.6) hat einen eigenen Bodenschein — aus dem Gang ist sie
  bei Standard-Zoom der erste Wegweiser (die Boss-Säule steht dort oft
  noch seitlich außerhalb des Bilds; bei Zoom 14 ist sie zu sehen). Anders als alle anderen Säulen auf der ganzen Boss-Ebene sichtbar
  (Meta `saeule_weit`) — Wegweiser schon aus dem Gang. Übrige Säulen bleiben
  dezent und nur nahe sichtbar. Der Gang davor bekommt
  Fackeln und Banner (Banner nur an Wandseiten, die zur Kamera zeigen).

## 6. Kontur
- Dunkle Kontur `#14141f`, Dicke 0.022, um jede Figur und jedes Objekt
  (Inverted Hull) — das Erbe der Pixel-Ära, hält alles lesbar.
- **Maße gehören ins Mesh, nie in die Node-Skalierung** (sonst wird die
  Kontur ungleich dick). Figurgröße (Troll 1.4, Katze 0.8, Boss ×1.5 im
  Dungeon, ×1.1 im Kampf) wird eingebacken: `Bausatz.massstab` skaliert
  Maße und Lagen VOR dem Aufblähen der Hülle, `FigurenBau.massstab_einbacken`
  macht dasselbe für Grundkörper-Figuren (Kopie der PrimitiveMeshes). Die
  Wurzel bleibt Skala 1, die Kontur überall 0.022; Meta `groesse` merkt den
  Faktor (Blob-Schatten, Schmuckringe; breite Figuren dazu `ring_faktor`,
  Golem 1.25, Pilzstamm 1.1). Nur die Kampfbühne skaliert die
  Wurzel weiter (Riesen-Deckel, Squash).
- Kleinteile ohne Kontur: Pupillen, Zähne, Glanzpunkte, Bänder, Gürtel.
- Gebackene Objekte (`Bausatz`): die Kontur ist eine eigene Hülle aus den
  um die Konturdicke aufgeblähten Grundkörpern (Kontur-Shader mit Dicke 0) —
  gleiche Optik wie Inverted Hull je Teil, aber ein Zeichenaufruf.
- Bodenplatten ohne Kontur — die dunklen Fugen übernehmen das.
- Wände mit Screen-Door-Glas: Kontur über `Stil3D.kontur(modus, true)` —
  sie liest dieselbe Deckkraft (INSTANCE_CUSTOM.a) und lässt dieselben
  Bildpunkte aus, sonst bliebe eine dunkle Hülle stehen.

## 7. Kameras
- **Erkunden:** orthografisch, 45°-Diorama-Blick (Position ~(11, 12.5, 11)
  relativ zum Ziel), `size` ~8.8.
- **Kein Fog of War:** Alles auf dem Bildschirm ist sichtbar, keine
  Überraschungen. Wände blockieren nur die Sicht der GEGNER auf den
  Spieler, nie die Sicht des Spielers.
- **Wände (Glas-Regel):** Jede Wand = fester dunkler **Sockel** (0.3 hoch,
  mit Kontur — zeigt IMMER, wo die Wand steht) + Körper und Deckel. Eine
  Wand wird in ~0.3 s **durchsichtig** (Deckkraft 0.25), sobald sie im
  45°-Blick den Helden **oder** einen Gegner, eine Truhe, die Treppe oder
  ein Event verdeckt (Wand liegt auf deren x+z-Diagonale davor und
  seitlich nah). **Kein Milchglas:** Der opake Wand-Shader lässt Bildpunkte
  nach einem 4×4-Bayer-Muster aus (Screen-Door, Deckkraft je Instanz in
  `INSTANCE_CUSTOM.a`); Kanten bleiben deutlich dichter, die Kontur
  dithert mit. Was dahinter steht, erscheint in voller Farbe — der Held
  wird nie ausgewaschen. Alle anderen Wände bleiben massiv. Nie Wände ganz
  ausblenden — Gänge und Durchgänge müssen lesbar bleiben.
  **Wandkronen dithern mit ihrer Wand** (eigene Instanz-Deckkraft, auch
  ihre Kontur-Hülle); weil eine Krone weiter nach hinten verdeckt, reicht
  der Glas-Abstand dieser Wand entsprechend weiter (Höhe × 1.25).
- **Kampf:** Perspektive, FOV 38, leicht erhöht. Monster in
  **3/4-Ansicht zur Bildmitte gedreht** (JRPG-Klassiker) — frontal wirken
  Schnauzen-Figuren wie Masken.

- **Steuerung bildschirmrelativ:** „W" = im Bild nach oben (Karten-
  Diagonale), nicht Karten-Norden (`DungeonWelt3D.bildschirm_zu_karte`).
  Mausrad zoomt (6.5–16, Start 10.5).

## 7b. Dungeon-Umsetzung (`scripts/dungeon/dungeon_welt_3d.gd`)
- Reine Anzeige: Die Spiellogik rechnet weiter in Karten-Pixeln
  (32 px = 1 Feld = 1 Welteinheit, Karten-y = Welt-z) und ruft jedes Bild
  `aktualisieren()` auf.
- Boden und Wände als **MultiMesh** (Instanzfarbe über `COLOR`,
  Zusatzdaten über `INSTANCE_CUSTOM`) mit den Shadern aus `WeltMaterial`
  (`scripts/stil3d/welt_material.gd`); nur Wände an Bodengrenzen werden
  gebaut — Räume schweben über dem Sternen-Nebel. Glas-Wände: nur die
  Instanz-Deckkraft ändert sich (keine Extra-Nodes, keine Transparenz).
- Figuren je Archetyp aus `FigurenBau.fuer_archetyp()` (Baukästen
  zweibeiner/vierbeiner/schleim/krabbler/golem/…), Truhenbänder in
  Raritätsfarbe, Schreine je Typ eingefärbt. Jede Figur am Boden hat einen
  weichen **Blob-Schatten** (bleibt beim Schweben am Boden, wird kleiner),
  der eigene Held zusätzlich einen goldenen **Bodenring** und einen
  leichten **Lauf-Hopser** (`WeltBau.naechster_hopser`).
- **Licht:** Sonne (Biomfarbe) + warme Laterne über dem Helden + **Licht-
  Pool** aus 6 echten OmniLights, die jedes Bild an die nächsten
  Lichtquellen um das Kamera-Ziel wandern (`WeltBau.pool_auswahl`, zum Rand
  weich ausgeblendet). Lichtquellen = Fackeln, Treppe, Feuerschalen und der
  lebende Boss — je mit eigener Farbe, Energie, Reichweite und Flackern. So bleiben es 7 Punktlichter — unter den Compatibility-
  Grenzen 8 pro Objekt (der Boden ist EIN Objekt) und 32 gesamt, egal wie
  viele Fackeln die Karte hat. Fackeln hängen in einem Wandhalter
  (`FigurenBau.fackel(false, true)`); wird ihre Wand Glas, wird die Fackel
  ausgeblendet (ihr Licht bleibt) — sonst schwebt die Rückseite einer
  Fackel an der Gangseite einer Vorderwand im Raster. Keine Uniform-Arrays,
  keine Licht-Schleifen im Shader.
- Wandkronen und Deko: je Variante ein MultiMesh (Körper, Shader
  `WeltMaterial` „kulisse“/„kulisse_glas“) + eines für die Kontur-Hülle.
  Lichtsäulen, Bodenglühen und örtliche Funken (Treppe, Feuerschalen,
  Boss) nur im Umkreis des Kamera-Ziels sichtbar (`LOKAL_REICHWEITE`,
  wächst mit dem Zoom — herausgezoomt geht am Bildrand nichts aus).
  Neue Shader (Säule, Glühen, Siegel, Kulisse, Funken) werden beim
  Aufbau mit winzigen verdeckten Proben vorgewärmt (keine Hänger, wenn die
  erste Truhe ins Bild kommt).
- Reine Funktionen (Wandhöhe, Pool-Auswahl, Hopser, Kronen-Wahl, Boss-Raum,
  Feuerschalen, Boss-Eingang) in `WeltBau` — ohne Autoloads, darum
  headless testbar (`grafik_selftest.gd`).
- Leistung (RX 7900 GRE, ohne VSync, Stufe 20 / 88×76, Mittel der Bilder
  400–800): Paket 1 vorher ~430, nachher ~410 FPS; Paket 2 (Kronen, Deko,
  Ziele, Minimap) ~410 » ~400 FPS (Streuung ±15); mit VSync 144.
  Paket 4 Gerüst (Gliederpuppe, Boss-Säule, Maßstab im Mesh): Messung bei
  stärker streuendem Rechner — Vergleich zur selben Zeit HEAD 318/318/343,
  nachher 299–399 (Mittel ~342): kein messbarer Unterschied.
  Paket 4 gesamt (Review, ruhiger Rechner, je drei Läufe zur selben Zeit):
  vor Paket 4 (`3b4aa8c`) 444/420/442, nach Paket 4 451/455/448 FPS
  (Zeichenaufrufe ~287).
- Dev-Screenshot: `scripts/dev/dungeon_shot.tscn -- --shot=<png>
  [--frames=N] [--zoom=Z] [--stufe=S] [--biom=0..3] [--ebene=N]
  [--neben-treppe] [--boss-raum] [--boss-gang] [--taste=move_up] [--ohne-vsync]` — gibt
  „FPS-Mittel (2. Hälfte)" aus. (`--treppe` betritt die Treppe und wechselt
  die Ebene — für Standbilder `--neben-treppe` nehmen.)

## 7c. Kampf-Umsetzung (`scripts/stil3d/kampf_buehne_3d.gd`, `kampf_halle.gd`)
- 3D-Arena hinter der unveränderten Kampf-UI (Host + Co-op-Gast bauen
  dieselbe Halle: `KampfBuehne3D.aufbauen(BiomStil.fuer(biom))`). Kamera
  perspektivisch, FOV 38, steil genug, dass die Gegner-Panels (oberes
  Bilddrittel) den Boden VOR den Säulen treffen.
- **Kampfhalle (`KampfHalle`, Grafik-Paket 3) — Rundhalle im Biom-Stil:**
  Hallen-Säulen der Biom-Kulisse (`BiomKulisse.saeule_bausatz`: Wald Baum,
  Höhle Tropfstein mit Kristallen, Ruinen Marmorsäule, Krypta Gruftpfeiler)
  auf einem **hinteren** Kreisbogen (r 9 um die Kampfmitte, alle z < -4 —
  vorn lägen sie hinter dem Befehlsmenü), vier Fackeln an Haltern zur Mitte
  gewandt. Dahinter ein Ring großer Biom-Stücke (`BiomKulisse.
  hallen_kulisse`: Tannen/Laubbäume/Felsen, Stalagmiten/Kristallgruppen,
  Mauerreste/Säulen, Grüfte/Kreuze/Grabplatten) plus Biom-Deko am
  Arenarand. Säulen und Kulisse sind je EIN gebackener Bausatz (je Biom
  zwischengespeichert) — vier Zeichenaufrufe für die ganze Halle.
- **Boden mit Dungeon-Material:** radiale Platten (gefaste Boxen) mit dem
  Arena-Shader (`WeltMaterial` „arena“: Steinstruktur, Abnutzung am
  Plattenrand, Abplatzer, Risse, Biom-Zweig Moos/Nässe/Flecken), äußerster
  Ring als Randstein; darunter eine Fugenscheibe, die zur Mitte hin in
  Biomfarbe glimmt; ein dezenter **Runenkreis** (Siegel-Shader in
  Fugenfarbe) in der Mitte; außen Dungeon-Platten (`boden`). Die Halle
  schwebt über dem **Sternen-Nebel** in Biomfarbe (wie der Dungeon), dazu
  die Biom-Partikel über der Arena.
- **Licht (Filmic über `Stil3D.umgebung` wie im Dungeon):** Sonne (Biom-
  farbe, schwächer), Umgebung aus `BiomStil`, ein **Spot von oben als
  Lichtinsel** auf dem Kampfkreis (ohne Schatten — Spot-Schatten streifen
  in Compatibility), der Arena-Shader dunkelt zum Rand und zum Vordergrund
  leicht ab, Vignette unter der UI, Debanding an. **Licht-Budget**
  (`KampfHalle.LICHT_BUDGET`): Spot 1 + Fackeln 4 + Boss-Spot 1 +
  Effekt-Lichter 2 = 8 Punkt-/Spotlichter — genau die Compatibility-Grenze
  je Objekt (der Boden ist eines). **Render-Ebenen:** die Bühne legt alle
  Figurteile auf `KampfHalle.FIGUR_EBENE` (2); der Boss-Spot trifft nur
  `HALLE_EBENE` (1), das rote Boss-Randlicht nur Figuren — Figuren zählen
  `FIGUR_LICHT_BUDGET` (Spot, Fackeln, Randlicht, Effekte = 8; die Fackeln
  reichen ohnehin nicht bis zur Mitte). Boss-Spot, Randlicht und Effekt-Lichter stehen von
  Anfang an. Achtung: ein Licht mit Energie 0 zählt beim Zeichnen nicht —
  darum leuchten sie beim Vorwärmen 0.4 s lang unmerklich (0.001, Effekt-
  Lichter mit weiter Reichweite), sonst bräuchten die Figuren beim ersten
  Aufleuchten eine neue Shader-Variante (leerer Shader-Cache: ~22 ms).
- **Grundhelligkeit wie das Spielbrett:** auch im Bosskampf bleibt die
  Umgebung über `KampfHalle.MIN_UMGEBUNG` — Gegner, Lebensleisten, Namen und
  Zielauswahl bleiben voll lesbar; kein Fog of War.
- **Boss-Auftritt:** Boss-Banner als **Letterbox** (`KampfUi.boss_banner`:
  Leiste oben mit dem Namen, unten mit den Eigenheiten — fehlen sie, keine
  untere Leiste; schieben sich ein und nach ~3 s wieder hinaus, Klicks
  gehen durch). Die Halle dunkelt ab (`KampfHalle.stimmung`, Phase 1):
  Sonne und Spot gedämpft, Fackeln heruntergeflackert (unruhiger),
  rot-violettes Umgebungslicht, Runenkreis und Nebelschimmer rot, ein
  **roter Spot folgt dem Boss** — seit dem Rest Paket 4 nur noch auf Halle
  und Boden (Render-Ebene, s. Licht-Budget): er färbte den Boss um (Troll
  gelblich, Golem rosa). Auf der Figur liegt statt dessen ein **rotes
  Randlicht** schräg von hinten oben (`boss_rand`, Kicker zur Bildmitte
  hin abgewandt): Oberseiten und Flanken glühen rot, die Vorderseite bleibt
  im fast neutralen Spot (`spot` im Boss nur leicht wärmer, Test: G/B ≥ 2/3
  bzw. 0.58 von R) — der Boss bleibt in Eigenfarben lesbar. Der Runenkreis
  bleibt gedämpft, weil er unter Namen und Werten der Gegner liegt.
  **Rahmung:** solange die obere Letterbox steht, rahmt die Bühne jede Figur
  nach ihrer echten Höhe (`hoehe` = Umriss inkl. Krone/Geweih + Schweben,
  ×1.04, perspektivisch projiziert): der Scheitel bleibt 10 px unter der
  Leiste (`KampfBuehne3D.rahmen_oben`, von `KampfUi.boss_banner` gesetzt und
  mit der Leiste hinaus getweent — der Boss richtet sich dann zu voller
  Größe auf). Betrifft nur hohe Bosse (Dämonenkönig, Bock-Geweih,
  König-Schleim-Krone). Co-op-Gäste bekommen dieselbe Stimmung,
  sobald die Boss-Figur steht (ohne Banner).
- **Phasenwechsel** (`KampfBuehne3D.boss_phase`, aus `KampfUi.
  phasen_auftritt`): Spot und Umgebung schlagen kurz hellrot auf (0.06 s),
  dann färbt sich die Halle je Phase röter (Phase 3 am stärksten) —
  zusätzlich zu Beben, Aufglühen und Banner „Phase N“. Zeigt nur die Phase,
  nie eine Absicht.
- **Die UI bleibt Herr:** Jedes Gegner-Panel hat einen unsichtbaren
  Platzhalter (128 px × `sprite_scale`, Boss ×1.2). Die Figur stellt
  sich jedes Bild auf dessen Fußpunkt (Strahl auf den Boden) und skaliert
  so, dass eine 1 Einheit hohe Standardfigur den Platzhalter füllt —
  Eigengröße (Troll 1.4, Katze 0.8) wirkt zusätzlich. Klicks, Tooltips,
  Schadensvorschau und Layout funktionieren dadurch unverändert.
- Animationen laufen weiter als Tweens auf dem Platzhalter; die Figur
  übernimmt sie: Puls » Ausfallschritt zur Kamera, Rotation » Taumeln.
  Besiegte verpuffen drehend.
- **Treffer-Feedback:** Blitz = farbiger **Fresnel-Rand** (Treffer rot-
  orange, Heilung grün) als `material_overlay`, EIN Material je Figur
  (beim ersten Treffer angelegt, danach wiederverwendet); Kontur-Hüllen
  (Bausatz) blitzen nicht mit, eigene Overlays kommen zurück. Jeder
  Treffer staucht die Figur (Squash, federt in 0.4 s aus) und stößt sie
  zurück; nur **Krit/Volltreffer** zusätzlich ~60 ms **Hit-Stop** (die
  Figur friert lokal ein — nie `Engine.time_scale`, Netz-Timer laufen
  weiter) und ein leichter **Kamera-Ruck** (kein Wackeln; aus mit
  „Bildschirm wackeln“).
- **Vorwärmen:** beim Kampfstart rendern winzige Proben unter dem Boden
  die Effekt-, Blitz-, Schweif-, Gold-, Funken- und Säulen-Shader einmal
  (Compatibility übersetzt erst beim ersten Zeichnen), Effekt-Lichter und
  Boss-Spot/Randlicht leuchten dabei unmerklich (siehe Licht-Budget). Gemessen mit
  leerem Shader-Cache (`--fxschleife`): ohne Vorwärmen ~56 ms Hänger beim
  ersten Zauber, mit Proben ~22 ms, mit Licht-Vorwärmen keiner mehr beim
  Abschuss; beim ersten Einschlag bleibt ein einmaliger ~25-ms-Hänger
  (Ursache offen, nur bei leerem Cache). Mit gefülltem Cache: ~10 ms für
  die volle Einschlag-Salve (6 Elemente + Krit, CPU-Aufbau).
- Vierbeiner/Krabbler/Igel tragen Meta `drehung` » 3/4-Ansicht zur Mitte.
- Kleine Bilder (Zugleiste, Party) rendert `PortraitStudio` einmal aus
  der 3D-Figur (eigene SubViewport-Welt, UPDATE_ONCE) — verteilt: je Bild
  höchstens 4 neue Viewports und 4 Auslesungen (`NEU_JE_BILD`,
  `AUSLESEN_JE_BILD`; `get_image()` wartet auf die GPU), die Figur selbst
  wird beim Aufruf gebaut (meist im Szenenaufbau). Taverne (17 Farben +
  Helden, `--bildzeit`): Szenenaufbau 585 » ~250 ms (mit Formen-Cache),
  längstes Bild 47–49 » 36–37 ms, danach ≤ 8 ms; Kampfaufbau 489 » ~360 ms. Heldenfarbe kommt
  aus `FigurenBau.held_farbe(name)` — überall gleich.
- Leistung (RX 7900 GRE, ohne VSync, Stufe 20, Mittel der 2. Hälfte von
  8000 Bildern): vorher Kampf ~1520, Boss ~1690, Boss mit Effekt-Schleife
  (`--fxschleife`) ~1430 FPS; nachher ~1500 / ~1510–1580 / ~1475 (Streuung
  ±100). `--fxschleife` meldet das längste Bild in den 1.5 s nach dem
  ersten Effekt (Zeit-, nicht Bildfenster: ohne VSync wären 60 Bilder nur
  ~40 ms, die Einschläge kämen erst danach); der erste Effekt kommt
  frühestens 1 s nach Szenenstart. Dungeon Stufe 20 unverändert ~400.
  Rest Paket 4 (Boss-Inszenierung, je zwei Läufe zur selben Zeit, ohne
  VSync): Dungeon Stufe 20 vorher 435/435, nachher 437/434; Boss-Ebene
  (`--boss-raum`, 800 Bilder) 1531/1492 » 1544/1491; Bosskampf (8000 Bilder)
  1853/1807 » 1851/1847 FPS — kein messbarer Unterschied.
  Rest Paket 4 (Figuren, abwechselnd vorher/nachher gemessen, ohne VSync):
  Kampf Stufe 20 mit Effekt-Schleife (8000 Bilder) vorher 1681/1666/1647/
  1683/1634/1620, nachher 1655/1654/1671/1667/1639 FPS; Dungeon Stufe 20
  (3000 Bilder) vorher 418/433/428, nachher 432/418/446 — kein messbarer
  Unterschied. (Ein Hilfsaufruf je Glied in `beleben` kostete im Kampf ~2 %
  und ist wieder eingebettet.)
- Dev: `dungeon_shot.tscn -- --szene=res://scenes/battle/battle_scene.tscn
  --stufe=7 [--biom=N] [--boss] [--phasetest --phase=3] [--animtest]
  [--fxtest --fxzeit=0.12] [--fxschleife --ohne-vsync --frames=8000]`.

## 7d. Helden, Ränge, Menüs
- **Helden zeigen ihre echte Ausrüstung** (`FigurenBau.held_aus`): Waffe
  (Schwert/Großschwert, Axt/Großaxt, Keule/Hammer, Dolch, Bogen,
  Armbrust, Turmschild, Stab mit Licht), Nebenhand (Schild, Köcher,
  Dolch, Buch, Fokus/Relikt, Heiligkreuz) und Rüstungsklasse bestimmen die
  Rolle (Tank, Krieger, Schurke, Magier, Heiler, Abenteurer — Abschnitt 7h).
- **Rüstungsfarbe ist frei wählbar** (ersetzt die alte Porträtwahl; der
  gespeicherte `portrait_tile` ist jetzt der Farbindex — alte Spielstände
  behalten ihre Wahl). Ohne Wahl: Farbe nach Namen.
- **Ränge, Sonder, Boss** (`FigurenBau.schmuecken`, über Anker-Metas
  `anker_kopf`/`anker_ruecken` statt fester Höhen; Bodenteile über Meta
  `boden_teile` jedes Bild bei y = 0.015 gehalten, auch bei Schwebenden):
  Elite = dünner lila Leuchtring mit drei Kristallsplittern (im Porträt ein
  Strich, keine Pfütze; Gliederpuppen bekommen lila Augen), Champion =
  roter Doppelring mit sechs Zacken plus Hörnerstummel am Kopf
  (Segmentketten, `Gliederpuppe.kette`; Figuren mit eigenen Hörnern
  nicht), Strahlend = Glanz nur auf Körpern (nie auf Konturen) plus
  Silberring, Kartenhüter = Schriftrolle quer auf dem Rücken plus
  gestrichelter lila Ring (über dem Kopf bleibt Platz für Status und
  Marker). **Boss** (Parameter `boss`): Boss-Krone am Kopf-Anker (Reif, fünf
  Zacken, Drachenblut-Steine, 10° schräg; vorhandene Kronen werden zur
  Großkrone mit sieben Zacken und Mittelstein; Urgolem: Kristallkrone; ein
  schräg ruhendes Kopf-Glied wie der Mimic-Deckel gibt die Gegendrehung als
  Meta `anker_kopf_drehung`, die Krone sitzt in Ruhe aufrecht; Meta
  `krone_sitz` {versatz, neigung, schraeg, groesse} nur für die Krone:
  Leichenfresser auf dem Hinterkopf (tief hängender, nickender Kopf — von
  oben lag sie vor dem Gesicht), Schattenbestie tiefer (schwebte über dem
  runden Schädel), Igel kleiner und weiter hinten (saß wie ein Hut auf den
  Brauen), Hexenmeisterin um den Hut statt auf der geknickten Spitze;
  Durchsicht aller 34 Gegner: `stil_showcase -- --modus=kronen
  [--gruppe=0..6] [--nur=<id>] [--seite] [--oben] [--pose=idle:<s>]`), glühende Augen und größere
  Hörner/Hauer bei Gliederpuppen, im Kampf rotes Runen-Bodensiegel ohne
  Füllung plus zehn Glutfunken; Größe im Mesh (siehe 6). Aller Schmuck ist je
  Art und Größe EIN gebackenes Mesh ohne Schattenwurf (gecacht).
  **Güldene = echtes Gold** (`Stil3D.gold`: jedes Toon-Teil bekommt sein
  gecachtes Gold-Gegenstück — Albedo zu Gold gezogen, Helligkeit stark
  gestaucht, damit auch dunkle Figuren Gold statt Bronze werden,
  harte Glanzstufe im Licht, einzeln aufblitzende Glitzerpunkte; Kontur
  bleibt), kein additives Overlay mehr. Strahlende behalten ihren kühlen
  Glanz als Overlay (Treffer-Blitze geben ihn danach zurück).
- **Riesen-Deckel:** Kampf-Figuren ragen nie über die Zugleiste.
- Menüs: drehende `FigurenVorschau` (Inventar, Taverne, Heldenerstellung),
  Porträts aus `PortraitStudio` auf Knöpfen und Listen.

## 7e. Oberfläche, Menü-Kulisse & Icons (`scripts/ui/`, `menue_kulisse.gd`, Grafik-Paket 5)
Leitbild: **Spielbrett-Zubehör aus dunklem Holz mit Messing** über dem
Diorama — Grundhelligkeit gut lesbar, Laternen-Wärme nur als Akzent.
Lesbarkeit und Kontrast gehen vor jeder Zierde.
- **Material ohne Shader** (`UiHolz`, `scripts/ui/ui_holz.gd`): Tafeln,
  Knöpfe, Fächer, Eingabefelder und Tooltips sind prozedurale
  `ImageTexture`s in einer `StyleBoxTexture` (9-Slice). Ein CanvasItem-
  Shader auf Knöpfen ist verboten (er färbte den Text mit, ein Theme nimmt
  kein Material). Jede Art wird EINMAL gemalt und gecacht (alle Knöpfe
  teilen eine StyleBox). **Rest Paket 5:** `UiHolz.vorbereiten()` malt
  alle Arten gleichzeitig auf dem `WorkerThreadPool` (die Threads malen nur
  in eigene Bilder, eingetragen wird danach im Hauptthread), dazu ohne
  Zuteilung je Bildpunkt (Fase/Kante ohne Arrays, Rauschen als Bytes über
  eine L8-Tabelle, PAL-Farben vorab gelesen) — Bild für Bild identisch
  (Prüfsumme gleich). Erster Theme-Aufbau headless ~235 » ~37 ms; die
  größte Tafel bestimmt jetzt die Dauer.
  - Maserung: Jahresringe als Sinus, verbogen von nahtlosem Rauschen
    (`FastNoiseLite.get_seamless_image`), plus Fasern. Sie ist in der Mitte
    **periodisch** (Periode = Bildgröße − 2 × Rand): Mitte und Kantenstreifen
    werden gekachelt (`TILE_FIT`), nie gestreckt — gleich feine Linien auf
    jeder Größe. Licht der Rahmen nach der **nächsten Kante** (oben hell,
    unten dunkel), nie nach der Bildhälfte (sonst Stufe im Kachelstreifen).
  - Arten: `tafel` (Messingrahmen mit Glanzkante, Kerbe, Schattenfuge,
    Nieten), `tafel_aktiv` (Rahmen und Schein in PAL `glut` — heller als
    Messing, Gold läge zu nah dran; Schein als `expand_margin`: Held am Zug), `fach` (eingelassene Zeile), `feld` (Eingabe, Log),
    `pergament` (Tooltip, Tinte als Schrift), `knopf` / `knopf_hover`
    (Messingsaum) / `knopf_druck` (sinkt ein, Inhalt rutscht) / `knopf_aus`
    (ergraut) / `knopf_aktiv` (gewählter Reiter: dunkles Holz, Goldsaum,
    Goldschrift — `UiTheme.als_aktiv`).
  - Schalter (`CheckButton`): eigene Icons `UiHolz.schalter(an, gesperrt)`
    — Messing-Schiene mit Kerbe, „an“ in Gold gefüllt mit Knauf rechts.
    Godots Standard-Schalter (dunkle Schiene) verschwand auf dem Holz,
    „Aus“ las sich wie bloßer Text.
- **Rollen statt „alles Gold“:** Hover = Messing, aktiv/gewählt = Gold,
  Seltenheit = `RARITY_COLORS`, **Tastatur-Fokus = eigene Farbe PAL `fokus`
  (Türkis)** als 3-px-Ring mit Schein (`UiHolz.fokus_box`, ein StyleBoxFlat
  für Knöpfe, Dropdowns, Felder, Schalter, Slider und Kacheln). Der Ring
  liegt auf der Knopfkante (kein Außenrand) — ScrollContainer schneiden
  sonst seine Seiten ab. Fokusfarbe hält Abstand zu Gold, Messing und jeder
  Seltenheit (Test in `oberflaeche_selftest`). WASD+E bleibt überall
  bedienbar (`focus_first_button`, `fokus_einsperren` unverändert).
- **Tafel in Tafel:** `Bildschirm.tafel` und der Inhaltsbereich der Vorlage
  tragen `UiTheme.innen_theme()` — Zeilen-Panels darin werden zu Fächern statt
  eigener Messingtafeln. Freistehende Panels (Fenster, Hinweise, Party-
  Karten im Kampf) bleiben Messingtafeln. Rauchglas (`glas_tafel`, Holzton
  mit Messingfaden) nur für Text direkt über 3D (Kampflog, Dungeon-HUD).
- **Schrift:** Standardschrift; Titel „eingraviert“ (Kontur in Kerbenfarbe,
  `Bildschirm._eingraviert`), Knopftext mit dünner Kontur, Untertitel über
  der Kulisse mit Kontur statt bloßer Transparenz. Gefahr-Knöpfe (Löschen)
  mit Schrift in Warnrot (`UiTheme.gefahr`, auch mit Fokus; Kartenlager und
  Spielstände).
- **Menü-Kulisse** (`UiTheme.make_background(ort, ruhig, versatz)` →
  `MenueKulisse`): Steininsel mit Ruinenbogen, Fackeln und der **eigenen
  Party**, Herzstück je Ort: `lager` (Lagerfeuer mit warmem Bodenschein,
  Standard), `taverne`, `schmiede`, `laden`. Sie schwebt über einer
  **Sternen-Nebel-Kuppel** (Schlieren + zwei Sterntiefen + Dither, nach
  Blickrichtung — die flache Untergrund-Ebene sähe im Streiflicht wie Wasser
  aus) mit Scholle darunter und Glühwürmchen. Bildstimmung **Filmic** über
  `Stil3D.umgebung` wie Dungeon, Kampf, Porträts und FigurenVorschau.
  Schleier 0.12 (Hauptmenü) bzw. 0.66 (`ruhig`) + Vignette. Aufheller von
  vorn, damit Gesichter lesbar bleiben.
- **Gedrosselt:** die Kulisse rendert nur 30 Bilder/s (`ruhig`: 15 und in
  halber Auflösung, `stretch_shrink` 2, dabei **linear** hochskaliert — das
  Projekt filtert Canvas-Texturen sonst „nearest“, die Kulisse bekäme
  Pixeltreppen), `FigurenVorschau` 30 Bilder/s —
  `SubViewport.UPDATE_ONCE` im Takt von `Stil3D.bild_faellig`; dazwischen
  zeigt der Container das letzte Bild.
- **Hauptmenü:** Knopfspalte als Holztafel links (Titel, Messingfaden,
  Kennzahlen, Spiel-Loop), die Kulisse rückt per `Camera3D.h_offset`
  (`versatz` −1.75) nach rechts — Lagerfeuer und Party stehen frei.
- **Icons** (PortraitStudio rendert einmal, 128 px, Filmic): Gegenstände
  (`GegenstandIcons`), Skill-Klötze (`KlotzIcons`, Körper-Quelle mit eigener
  Panzerfaust vor einem Herz), Tränke/Verbrauchsgüter und Materialien
  (`VorratIcons`: Flaschen und Phiolen in Trankfarbe, Erzbrocken mit Adern
  je Stufe, Lederstapel, Kristallspitzen, Runentafeln in Seltenheitsfarbe)
  und **Biom-Miniaturen** (`VorratIcons.biom`: Plattenstück + Wand + Krone +
  Deko aus derselben `BiomKulisse` wie der Dungeon). Nicht-Figuren bekommen
  ein kühles **Randlicht** von links hinten (`PortraitStudio.randlicht`),
  Meta `icon_blick` setzt eine eigene Blickrichtung. In Kacheln liegt hinter
  dem Icon ein **Seltenheits-Schein** (`UiHolz.glanz`, radial in der
  Seltenheitsfarbe) und das **Item-Level** als Messing-Chip
  (`UiHolz.level_chip`), nie direkt auf der Grafik. Icons stehen in
  Inventar (Ausrüstung, Tränke, Materialien), Händler (Tränke, Werkstoffe,
  Alchemie), Kartenlager (Biom), Kampf-Item-Menü (Host + Gast), Werkstatt.
  **Szenenübergreifender Icon-Cache** (Rest Paket 5): jede Szene hat ihr
  eigenes `PortraitStudio`; Icons mit den Präfixen `item|`, `klotz|`,
  `trank|`, `material|`, `biom|` kommen nach dem Auslesen zusätzlich in
  `PortraitStudio._geteilt` (statisch) — der nächste Besuch nimmt das
  fertige Bild, ohne die Figur zu bauen. Nur fertig gerenderte Bilder (ein
  Studio, das vorher stirbt, hinterlässt keine leeren), höchstens
  `GETEILT_MAX` = 256 (128² RGBA ≈ 64 KB, ≤ 16 MB), älteste fliegen zuerst.
  Figuren-Porträts bleiben je Szene (Farbe/Ausrüstung ändern sich).
  **Icon-Pass (2026-11, Befund I1–I13):**
  - *Schärfe:* Item-Icons (`item|`, `trank|`, `material|`, `biom|`,
    `PortraitStudio.MIPMAP_PRAEFIXE`) bekommen beim Auslesen einmalig
    Mipmaps (≈ 85 statt 64 KB je Icon, 256 Icons ≤ 22 MB); ihre
    TextureRects filtern `UiHolz.ICON_FILTER` (Linear mit Mipmaps) statt
    des Projekt-„nearest“ — `UiHolz.icon`, Inventar-Kachel, Zieh-Vorschau.
    Knöpfe mit Icon (Kampf-Item-Menü Host + Gast) nehmen
    `UiHolz.ICON_FILTER_KNOPF` (nearest **mit** Mipmaps): der Filter gilt
    auch für die Schrift, die so unverändert bleibt. Klötze, Porträts und
    Pixelkunst bleiben wie sie sind.
  - *Rahmen:* Meta `icon_rand` am Wurzelknoten (Ausrüstung
    `PortraitStudio.ICON_RAND` = 1,26, Vorräte `VorratIcons.RAND` = 1,18)
    schaltet `PortraitStudio.bild_rahmen` ein: alle Grundkörper werden auf
    die Bildebene der Kamera projiziert (Kugeln/Zylinder/Ringe als Kreise,
    sonst AABB-Ecken) — das Icon sitzt mittig, schräg in die Tiefe liegende
    Teile (Armbrust) ragen nicht mehr aus dem Bild, nichts stößt an den
    Raritätsrahmen. Ein größerer `icon_rand` macht ein Item bewusst kleiner
    (Dolch × 1,16). Flache Haufen (Lederreste, Kristallstaub) schauen per
    `icon_blick` von schräg oben. Biome und Klötze rahmen wie bisher.
  - *Unterscheidbar über die Silhouette, nicht die Größe* (jedes Icon wird
    auf seine Ausdehnung eingerahmt): Schwert/Zweihänder/Dolch wie
    `ZweibeinerBau._schwert`/`_dolch` (Zweihänder: langer Griff mit
    Goldringen, lederumwickelte Fehlschärfe mit Parierhaken; Dolch:
    Blattklinge, Messing-Parier); Axt mit Einzelblatt + Dorn, Zweihandaxt
    mit Doppelblatt + Spitze (wie die Figur, Eisen mit heller Schneide);
    Offensivstab = Holzgabel mit leuchtendem Doppelprisma, Heiligstab =
    Goldring mit acht Perlen (`_kristallstab`/`_ringstab`), Köpfe groß;
    Reflexbogen mit Griffwicklung und dicker Sehne; Armbrust mit Querbogen,
    Sehne und Bolzen. Rundschild mit Messingring, Diagonal-Wappen und
    Buckel; Turmschild mit Messingrand und Nieten; Zauberbuch als dicker
    Band (Rücken, Seitenschnitt, Goldecken, Stein); Kristallfokus =
    Leuchtkugel in Goldkralle; Relikt = Reliquiar (Giebeldach, rotes
    Fenster, Kreuz). Rüstungen als Brustpanzer mit Halsausschnitt, Taille
    und Schultern — Leder (Nähte, Schnallen), Kette (dunkles Eisen mit
    Ringraster, Lederkragen), Platte (hell, Brustgrat, Goldkanten). Roben
    mit Kapuze, Trompeten-Ärmeln und Saum; Lederkappe mit Wangenklappen,
    Topfhelm mit Sehschlitz und rotem Kamm; Stiefel als Paar im Profil;
    Amulett mit großem Anhänger und kurzem Perlenbogen. Griffe/Schäfte in
    etwas dunklerem Holz (`GegenstandIcons._holz`) — Kontrast auf warmem
    Glanz. Tränke: große Tränke als Walzenflasche mit Goldband und langem
    Hals, Stärkungstonikum eckig in Bernstein, Weckelixier mit Glocken-
    Stopfen, Belebungselixier mit weißen Flügeln und Heiligenschein,
    Tempotrunk geneigt mit nach hinten gestrichenen Flügeln. Erzadern groß
    in Stufenfarben (Eisen rostorange, Stahl silber, Mithril hellblau,
    Adamant grün, Sternenmetall violett + Stern); Kristallstaub als
    Pulverhäufchen in einer Schale, Mondkristall bleich-blau; Lederreste als
    lose Fetzen; Runen mit eigener Tafelform, Steinfarbe und Glyphe
    (schwaches Leuchten, Orange bleibt Orange), Regelbrecher zerbrochen.
  - Prüfen: `res://scripts/dev/icon_befund.tscn -- --ordner=<pfad>`
    (alle Icons in Anzeigegröße auf echten Kacheln, Rohbilder 128 px,
    Filtervergleich; `--modus=inventar [--fenster=WxH]` echtes Inventar);
    Test: `oberflaeche_selftest` „Icon-Pass“ (keine zwei Icons gleich,
    Rand, Armbrust im Bild, Mipmaps/Filter). Aufbau Inventar/Händler/
    Kartenlager und längstes Bild unverändert (erster wie zweiter Besuch).
  Zweiter Besuch (`--zweimal --bildzeit --ohne-vsync`): Händler Aufbau
  24 » 20 ms, längstes Bild 9,8 » 4,3 ms; Kartenlager 59 » 49 ms /
  23,8 » 19,0 ms; Inventar 28 » 24,5 ms / 11 » 10 ms; Werkstatt 64 »
  53 ms / 9 » 5,3 ms (Bild 1).
- **Kampf-UI (`KampfUi`, Host + Gast):** Log über den Party-Karten neben
  den Befehlen (Arena bekommt die Mitte), Log blendet erst mit der
  ersten Zeile ein; Party-Karten mit Porträt und Zahlen auf HP/MP; HP
  wird unter 50 % gold, unter 25 % rot; Held am Zug = hellere Tafel mit
  Glut-Rahmen und Schein (`UiHolz` „tafel_aktiv“); Party-Karten sind
  Messingtafeln.
  Skill-Knöpfe mit Tooltip (`KampfUi.skill_knopf`) und „Punkte
  verteilen“ (`KampfUi.punkte_knopf`) teilen Host und Gast.
  Arena dahinter: Kampfhalle (7c).
- **Dungeon-HUD (`DungeonHud`):** Titel + Wert-Chips oben links,
  Party-Karten unten links, Tastenkappen unten rechts, Meldungen oben
  mittig auf Rauchglas (`glas_tafel`), Minimap oben rechts.
- **Minimap (`scripts/ui/minimap.gd`):** gedreht wie die Kamera (oben =
  Blickrichtung). Die Karte ist EIN Bild (ImageTexture, 6 px je Zelle):
  erkundeter Boden als Fläche, Wände als helle Konturlinien; neue Zellen
  werden nur dazugemalt — gelesen ab dem letzten Stand (die erkundeten
  Zellen wachsen nur hinten an), nie die ganze Karte je Bild. 4 px je Zelle auf dem Schirm; passt die Karte nicht
  ins Fenster (max. 220 px), folgt ein Ausschnitt dem Spieler (nur
  verschoben, nicht neu gezeichnet). Marker-Ebene darüber, neu nur bei
  Änderung: Symbole für Treppe (Stufen), Boss (Schädel), Truhe (Kiste in
  Raritätsfarbe), Tresor, Schrein (Raute in Typfarbe), Opferstein (Dreieck),
  Risiko-Truhe, sichtbare Gegner (Punkt), Spieler als Pfeil in Laufrichtung
  (letzter Zellschritt). Rahmen: dunkle Tafel, Messing-Doppellinie, Nieten.
  **Abstand zu Weltobjekten:** liegt der Held, ein Gegner oder ein Ziel
  unter der Minimap, blendet sie auf 40 % aus.
- **Bildschirm-Vorlage (`Bildschirm.bauen`, UI-Layout-Pass 2026-10-14,
  abgeschlossen 2026-11-01):** jede Menü-/Hub-Szene nutzt sie; das
  Hauptmenü nur Rand + Holztafel-Spalte (kein Zurück, keine Kopfzeile).
  Ergebnis- und Abschlussfenster (Kampfende Host/Gast, Dungeon
  abgeschlossen): `Bildschirm.fenster` (Messingtafel, 24 px Innenrand, 440 px
  Mindestbreite) + `fenster_titel` (gold, eingraviert, 32 px). 24 px Rand, ruhige
  Kulisse; Kopfzeile = Titel links, Info-Chips (`b.info`, Gold, Punkte …) +
  Zusatzknöpfe + **„‹ Ziel“-Zurück rechts** (Esc löst ihn aus); Stadt-Reiter
  über der Kopfzeile; Untertitel = eine gedämpfte Erklärzeile mit Kontur.
  Inhalt in Holztafeln (`Bildschirm.tafel`, Zeilen darin = Fächer), Listen nur senkrecht scrollend
  (`Bildschirm.scroll_liste`), lange Texte mit Autowrap — nie quer scrollen.
  Tastatur-Fokus startet im Inhalt (Kopfzeile/Reiter tragen `nicht_zuerst`).
- **Ergebnisfenster mit viel Beute** (Rest Paket 5,
  `Bildschirm.liste_einbauen` / `Bildschirm.HoehenListe`): alles unter dem
  Seitentitel wandert in eine Scroll-Liste, so hoch wie ihr Inhalt, höchstens
  Bildschirm − 4 × RAND − Rest der Seite — Knöpfe darunter („Weiter“,
  „Weiter »“) bleiben immer im Bild. Kampfende Host (Beute- und Level-Seite)
  und Gast. Läuft die Liste über, ist sie per Tastatur erreichbar (W von
  „Weiter“ » Liste mit Fokusring, W/S scrollt, am Ende geht der Fokus
  weiter); Start-Fokus bleibt auf dem ersten Knopf der Seite. Zeilen enger
  (8 px), gleiche Materialien als eine Zeile („+5 Wyvernleder“).
  Review-Fix: `liste_einbauen` hängt Knöpfe (Punkte verteilen) um — sie
  kommen erneut durch `SceneTree.node_added`; `Sfx` verbindet den Klick-
  Klang deshalb nur einmal (vorher „Signal 'pressed' is already connected“).
- **Layout-Pass 2026-11** (Lutz: „Sachen verschwinden vom Bildschirm, z. B.
  bei den Drops nach einem Kampf“) — nur Layout, Design unverändert:
  - `Bildschirm.TastenScroll` (Basis von `HoehenListe`): `follow_focus`, läuft
    sie über, selbst fokussierbar (W/S scrollt, Fokusring); ohne
    fokussierbaren Inhalt (Credits) erkennt sie den Überlauf am Balken.
  - `liste_einbauen` lässt **Knöpfe am Seitenende** unter der Liste stehen
    (Punkte verteilen) — W vom ersten Knopf erreicht die Liste; vorher lagen
    sie darin, `follow_focus` scrollte ans Ende und die Aufstiegszeilen waren
    per Tastatur nicht mehr lesbar.
  - `HoehenListe` bricht einzeilige Zeilen/Knöpfe um, die breiter als
    `max_breite` wären (Standard Bildschirm − 4 × RAND − Polster − Balken):
    die Bank-Zeile mit langen Namen schob das Sieg-Fenster auf 1476 px.
    Umbrochen wird auf die Breite der übrigen Zeilen (mind. `UMBRUCH_MIN`
    560 px, höchstens die Grenze) — sonst zog eine einzige lange Zeile das
    Fenster auf fast die ganze Bildbreite (Abnahme: 1184 » ca. 760 px).
    Optional `polster` (0 = Balken nur rechts) und `grenze` (Höhen-Funktion).
  - **Taschen voll** (`TaschenVoll`, nach dem Sieg im Dungeon, Händler,
    Schmiede): Item-Zeilen in einer `HoehenListe`, Hinweis und die drei
    Knöpfe darunter immer im Bild (vorher bis 847 px hoch, Fokus auf
    unsichtbaren Knöpfen).
  - **Kampf-Befehlsspalte** (`KampfUi.unterer_bereich`, Host + Gast): die
    Aktionen stecken in einer `HoehenListe` (Polster 0, 240 px), höchstens
    `AKTIONEN_MAX_HOEHE` = 360 px (Kopf + 8 Knöpfe, das volle Befehlsmenü
    scrollt nie) bzw. was über Zugleiste und Gegnerreihe frei bleibt;
    Namen über `AKTIONEN_MAX_BREITE` (300 px) brechen um. Alle 16 Tränke
    oder 13 Skill-Slots scrollen, Log und Party-Karten bleiben im Bild.
  - **Gegnerreihe** (`KampfUi.gegnerreihe`): bis 8 Gegner passen in die
    Bildbreite — erst rückt der Abstand zusammen (32/24 » min. 4 px), dann
    werden die Panels schmaler, notfalls die Figur-Platzhalter (Meta
    `figur_platz`; die 3D-Figur folgt der Platzhalterhöhe). 1–7 Gegner
    stehen unverändert.
  - Inventar: Helden-Reiter als `HFlowContainer` (24-Zeichen-Namen » zweite
    Zeile statt Szene breiter als der Bildschirm), Seiten-Reiter oben.
  - Dungeon-Meldung bricht um, höchstens Bildbreite − 2 × (Minimap 220 +
    24) — nie unter die Minimap; kurze Meldungen bleiben einzeilig.
  - Party-Namen (HUD, Kampf-Karten) mit „…“ statt hartem Abschneiden,
    im Kampf voller Name als Tooltip.
  - Alle Scroll-Listen (Händler, Kartenlager, Taverne, Lexikon, Training,
    Werkstatt, Inventar-Werte, `Bildschirm.scroll_liste`) mit `follow_focus`
    — vorher blieb S am letzten sichtbaren Eintrag hängen (Godot sucht
    Fokus-Nachbarn nur im sichtbaren Ausschnitt). Namensfelder (LineEdit)
    stören WASD nicht: per Tastatur fokussiert tippen sie erst nach E.
  - **Fenstermodus** (`Settings.fenster_rechteck`): die gewählte Auflösung
    samt Titelleiste passt immer in den nutzbaren Bereich (ohne Taskleiste),
    sonst im Seitenverhältnis verkleinert und mittig — 1920×1080 im Fenster
    auf einem 1080p-Monitor legte „Weiter“ und die Party-Leiste unter die
    Taskleiste. Die Einstellung selbst bleibt gespeichert wie gewählt.
  - Prüfen: `scripts/dev/layout_pruefung.tscn` (Stress-Daten im Speicher,
    Slot 99; meldet Elemente außerhalb, beschnitten, gekürzt, Fokus nach
    `--tasten=S*20`; `--fenster=WxH`, `--aufloesung=WxH`, `--sieg`,
    `--taschen-voll --warteliste-lang=N`, `--feinde=…`, `--vieleskills`,
    `--langnamen`, `--follow` …), Test `layout_selftest.gd`.
- **Eine Farbquelle** (Rest Paket 5): Szenen färben nur noch über
  `UiTheme`-Rollen bzw. `Stil3D.PAL` — `GUT` (Gewinn, passt, besser),
  `SCHLECHT`, `INFO` (Vergleich, Vorschau, Status), `WERKSTOFF`,
  `BELOHNUNG`, `ACHTUNG`, dazu PAL `ui_resist`, `ui_schild`,
  `ui_heil_tief`/`ui_schaden_tief` (Kontur der Zahlen), `ui_klotz_*`
  (Werkstatt-Gruppen); Element-Chips = `Stil3D.ELEMENT_FARBEN`, Zugleiste
  = `hp_gut`/`warnrot`/`gold`, Minimap aus PAL, Item-Karte auf Holz statt
  Blauschwarz. Deckkraft als modulate: `BLASS` (0.6, Nebentext — vorher
  teils 0.45/0.5, darunter fiel der Kontrast unter 4,5:1), `HALB` (0.75),
  `INAKTIV` (0.4, tot/gesperrt). Seltenheit bleibt `RARITY_COLORS`. Test:
  kein `Color(<Zahl>`/`Color("…")` in `scripts/ui/` (außer den Stufen und
  durchsichtigem Schwarz), jede Textrolle ≥ 4,5:1 auf `ui_holz`.
  Ausnahme `ItemInfo`: liest dieselben Rollen direkt aus `Stil3D.PAL`,
  nicht aus `UiTheme` — `UiTheme` braucht über `MenueKulisse` den Autoload
  `GameState` und kompiliert in Headless-Selbsttests (`-s`) nicht; sonst
  scheitert das Kompilieren von `data_selftest` (Review-Fix, Test dort).
- **Pergament-Tooltip umbrechen** (Rest Paket 5): Godots Standard-Tooltip
  bricht nie um — „Ins Buch“, „Reparieren“, Optionen liefen als eine Zeile
  über den halben Bildschirm. `UiTheme` hängt sich an
  `SceneTree.node_added` und bricht das `TooltipLabel` vor dem Messen an
  Wortgrenzen auf `TOOLTIP_BREITE` (420 px) um (`UiTheme.umbrechen`).
  Prüfen: `dungeon_shot --tooltip[=Knopftext]` (Mausbewegung nur als
  Ereignis, in Fensterkoordinaten).
- **Englisch** (Rest Paket 5, `--englisch`): Hauptmenü-Kennzahlen als zwei
  feste Zeilen (frei umbrochen hing „·“ am Zeilenende). Heldenerstellung:
  Beschreibung mit fester Höhe für 5 Zeilen (längste Ausrüstung, DE und EN)
  und flachere Vorschau (128 statt 150 px) — die Tafel springt beim
  Blättern nicht mehr und stößt nicht mehr an den Rand (`--kit=N`).
- **Durchsicht der Zeilen** (Händler, Spielstände; Fächer mit Deckkraft
  0.92) bewusst belassen: gemessen in den Zeilen Haupttext 13–15:1 im
  Mittel, ≥ 5,8:1 auch über der hellsten Kulissenstelle; Nebentext (BLASS)
  ≥ 4,0:1 auf 99 % der Zeilenfläche, die hellsten Stellen liegen in der
  Zeilenmitte ohne Text. Der leichte Durchschein gibt Tiefe, Lesbarkeit
  leidet nicht.
- Leistung Rest Paket 5 (ohne VSync, abwechselnd gemessen): Dungeon
  Stufe 20 (800 Bilder) vorher 442/439/414/442, nachher 449/414/441/445
  FPS; Kampf mit `--fxschleife` (3000 Bilder) vorher 1784/1790/1735/1787,
  nachher 1802/1728/1762/1793 FPS — kein messbarer Unterschied.
- Falle: `Range` (ProgressBar) meldet `value_changed` nur im Baum —
  Anzeigen beim Einhängen (`_ready`) nachziehen.
- Falle: `Color.TRANSPARENT` ist in Godot 4 WEISS mit Alpha 0 — in
  gefilterten Texturen (Holz, Minimap) gibt das helle Säume; dort
  `Color(0, 0, 0, 0)`.

## 7f. Kampf-Effekte (`scripts/stil3d/kampf_effekte.gd`)
- **Quelle:** `Battle.effekt` meldet darstellbare Ereignisse (element, waffe, magie,
  heilung, status, dot, krit, block) — die Kampflogik bleibt UI-frei. Die Kampfszene
  sammelt sie pro Aktion und spielt sie VOR den Schadenszahlen ab; Co-op-Gäste
  bekommen sie als Netz-Nachricht `fx` (Netz-IDs statt Kämpfern).
- **Aus Grundkörpern:** Kugel-Explosion, Funken (CPUParticles3D), Ring (TorusMesh),
  Lichtsäule, Eissplitter (Prismen), Blitz (Zickzack aus dünnen Boxen), Implosion,
  Hieb (gestreckte Box). Shader: unshaded, gemischt (nicht additiv — sonst wird auf
  hellem Boden alles weiß), satter Kern + heller Fresnel-Rand.
- **Projektile mit echtem Schweif** (`Schweif`, `scripts/stil3d/schweif.gd`): EIN
  Band-Mesh (ImmediateMesh) aus den letzten Positionen des Kopfes — quer zu Flug-
  und Blickrichtung, zum Ende spitz und durchsichtig, heller Kern, gemischt; nach
  der Landung holt das Ende den Kopf ein. Zauber: Kugelkopf + breiter Schweif in
  Elementfarbe + ein paar Funken (Größenkurve); Pfeile: schmaler heller Schweif.
- **Partikel-Budget:** höchstens 320 Funken gleichzeitig (`PARTIKEL_BUDGET`);
  darüber werden neue Ausbrüche ausgedünnt.
- **Element-Signaturen:** Feuer = Explosion + Funkenregen · Eis = Splitter ·
  Blitz = Strahl vom Himmel · Gift = aufsteigende Blasen · Heilig = Lichtsäule ·
  Dunkel = Implosion. Zauber und Fernkampf fliegen als Projektil mit Schweif
  (Zauber im Bogen, Pfeile gerade), 0.22 s.
- **Helden** sind Karten in der UI → ihre Effekte sind 2D (weiche Lichtpunkte +
  Farbblitz über der Karte), sonst lägen sie hinter der UI. Nahkampf hinterlässt
  Krallenspuren, Treffer schütteln die Karte (Rotation, containersicher).
- **Wucht:** kurzes farbiges Aufleuchten am Ziel aus einem **Licht-Pool von zwei
  OmniLights** (das gerade schwächste springt um — Licht-Budget 7c), auf das weiche
  Toon-Licht abgestimmt (Energie ×0.55 × Ausgleich, flacher Abfall, Reichweite 3.6;
  vorher ×0.22 ohne Ausgleich — mit weicher Abschwächung kaum noch zu sehen),
  Rückstoß + Squash der Figur, Hit-Stop und Kamera-Ruck bei Krit/Volltreffer (7c),
  Bodenwelle bei Krit und Schwäche, Mündungsblitz beim Werfer, Rauchwolke beim Tod.
- **Dauerzustände an den Figuren** (`KampfBuehne3D.status_setzen`): Brand =
  flackernde Flammen, Gift/Blutung/Regeneration = Partikel, Gefroren = Eispanzer,
  Betäubt = kreisende Sterne am Kopf, Schild/Schutzwall = Blase, Gestärkt/Gewappnet/
  Verlangsamt = Bodenring, Markiert/Verflucht = Zeichen über dem Kopf. Höhen in den
  Maßstab der Figur umrechnen (große Figuren haben Eigen-Skalierung).
- **Popups** gestapelt über dem Ziel: „SEHR EFFEKTIV!" (gold), „kaum Wirkung …"
  (grau), „KRITISCH!" (orange, plus Kamera-Ruck), „Block!". Schadenszahlen größer,
  mit Kontur und kurzem Aufploppen.
- Dev: `dungeon_shot.tscn -- --szene=res://scenes/battle/battle_scene.tscn --stufe=7
  --fxtest [--fxzeit=0.3]` (Standbild mitten im Effekt) · `--auto` spielt echte Runden.

## 7g. Figuren 2.0 / Gliederpuppe (`scripts/stil3d/gliederpuppe.gd`)
Gerüst für die neu gestalteten Monster und Helden (Paket 4). Beispielfigur
und Referenz: `FigurenBau.troll` (Buckel-Gorilla mit Baumkeule).
- **Aufbau:** `Gliederpuppe.new(name, massstab)`; `rumpf` = Bausatz für
  alles Statische (Beine, Rumpf, Kopf mit Gesicht, Hut, Umhang, Zubehör);
  `glied(name, gelenk, ruhe_grad, eltern)` = eigener Bausatz je Pivot, Teile
  RELATIV zum Gelenk. Namen: `arm_l`/`arm_r` (Arm samt Hand UND Waffe),
  `kopf`, `kiefer`, `bein_l`/`bein_r` (nur Sonderbau — Beine sind sonst
  gebacken), `schwanz`, `fluegel_l`/`fluegel_r`, `orbit`. Höchstens 5
  Glieder (Bosse), sonst 2–4. Pivots werden NUR gedreht, nie skaliert.
- **Metas:** `glieder` (Name » Node3D), je Glied `ruhe` (Euler, Bogenmaß),
  `anim` (Profil), `groesse`, `anker_kopf`/`anker_ruecken` (+ `_glied`),
  dazu wie immer `wippen`, `schwebt`, `drehung` (Zweibeiner 12°).
- **Proportionen** (Zweibeiner chibi): Kopf ~38 % der Höhe, ein
  Silhouetten-Merkmal über den Schultern, ein zweites auf Handhöhe.
- **Bausteine:** `auge` (Augapfel leicht hochoval, Iris in Palettenfarbe,
  Pupille rund/Schlitz, Glanzpunkt oben außen leuchtend; `hohl` = dunkle
  Höhle mit Glühpupille für Untote und Kapuzen), `braue` (böse/besorgt per
  Winkel), `mund` (strich, laecheln, o, grinsen, fies, unterbiss, optional
  Hauer), `wangen`, `arm` (liefert die Handmitte), `bein`, `griff` +
  `waffe` (Griff geht immer DURCH die Hand-Kugel: schwert, dolch, stab,
  keule, baumkeule, axt, schild_rund), `kette` (gebogene Segmentkette für
  Hörner, Geweih, Kämme), `krone`. Gesicht, Glanz, Nieten, Zähne ohne Hülle.
- **Material:** Körper `Stil3D.material(Weiß)` — Toon, Farbe aus der
  Vertexfarbe (sRGB, nie linearisieren), Leuchten aus Vertex-Alpha
  (`EMISSION += grund * (1 - COLOR.a) * 1.4` in TOON_CODE und GOLD_CODE;
  Grundkörper und MultiMesh haben Alpha 1, unverändert). Darum greifen
  Gold (`Stil3D.gold`: EIN Gold-Material für alle gebackenen Figuren),
  Treffer-Blitz und Strahlend-Overlay wie bei Grundkörper-Figuren. Hülle =
  Bausatz-Hülle (`ist_kontur`, blitzt nicht mit). `Bausatz.figur_knoten`.
- **Mesh-Cache:** `Gliederpuppe.gebacken(schluessel, bauen)` bäckt einmal je
  Schlüssel (Art | Größe | Boss | Akzent | Variante bzw. Mal); jede weitere
  Figur legt nur Nodes an. Troll: 6 MeshInstances statt ~25, 6 Zeichenaufrufe.
- **Formen-Cache** (`Bausatz._form_daten`, Rest Paket 4): `PrimitiveMesh.
  get_mesh_arrays()` legt das Mesh im Compatibility-Renderer auf der GPU an
  und liest es zurück (~0.1 ms je Teil). Ecken/Normalen/Indizes werden je
  Form (Art + Maße + Unterteilung, auch offene Röhren) einmal geholt —
  eine Figur kalt ~14 statt ~25 ms, Truhen < 0.5 statt ~7 ms.
- **Vorwärmen** (`FigurenBau.vorwaermen`, beim Dungeon-Aufbau über
  `DungeonWelt3D.figuren_vorwaermen`): alle Gegnerarten des Ebenen-Pools
  (auch spätere Nachschub-Arten), der Boss (Maßstab 1.5) und der eigene Held
  werden im Szenenaufbau gebacken. Vorher baute das erste Bild alle Arten
  auf einmal und jeder Nachschub einer neuen Art kostete mitten im Laufen
  ~25 ms. Stufe 20 (`--bildzeit`): längstes Bild 610–670 ms » 130–140 ms
  (der Rest ist das erste Rendern der Welt), Szenenaufbau 234 » ~450 ms.
  Kampf-Figuren mit Varianten backen beim Kampfaufbau.
- **Budget** (Körper + Hülle, `Bausatz.dreiecke()`, Selbsttest): Gegner ≤ 6000,
  Helden ≤ 8000, Bosse ≤ 12000. `Bausatz.sparsam` unterteilt nach Figurmaßen
  (vor dem Maßstab) gröber: Kugeln 6/8/10/12 Segmente nach Radius, Kapseln
  6–12, Zylinder 8–14; ausdrücklich gewählte Unterteilungen (Augen) bleiben.
  Troll: 5968 Dreiecke.
- **Animation ohne Skript je Figur:** `Gliederpuppe.PROFILE` = Tabelle je
  Archetyp-Typ (zweibeiner, troll, je Zweibeiner/Vierbeiner/Schleim-Art,
  flieger, krabbler):
  je Glied `idle`/`geh` = [Achse, Amplitude °, Hz, Phase, Form] und
  `angriff`/`treffer`/`phase` = Schlüsselbilder [t, Grad] relativ zur Ruhe
  (smoothstep, erstes und letztes Bild 0 — kehrt exakt in die Ruhe
  zurück). Glied `wurzel` liefert den Neige-/Roll-Versatz der Wurzel.
  `beleben(fig, zeit, aktion_t, treffer_t, geht, phase_t)` ist allokationsfrei.
  Dungeon: nur Figuren im Umkreis (`LOKAL_REICHWEITE`), „geht“ aus der
  Bodenbewegung; ferne Figuren fallen einmal in die Ruhepose. Kampfbühne
  (`Gliederpuppe.kampf_takt`): Angriff an der steigenden Flanke des
  Platzhalter-Pulses, Treffer mit dem Rückstoß, Phasen-Pose beim
  Boss-Phasenwechsel (nur Optik, nie Absicht; im laufenden Kampf geprüft
  für Dämonenkönig und Todesmeister — `dungeon_shot -- --feinde=todesmeister
  --boss --phasekampf`), Sonderposen der Fähigkeiten (7k); im Hit-Stop
  eingefroren.
  Koop-Gast nutzt dieselbe Bühne. Vorschau/Showcase: Idle. Porträt:
  Ruhepose (beste Silhouette). Profil-Form 2 = Dauerdrehung (Amplitude in
  Grad je Sekunde: Orbit, Kristall). Verschachtelte Glieder (`eltern`)
  liegen im in Ruhe gedrehten Eltern-Glied (Hexen-Kristall im Krummstab).
- **Showcase:** `stil_showcase.tscn -- --modus=geruest [--nah|--fern]
  [--pose=angriff:0.3]` zeigt Gliederpuppe, Ränge, Gold und Boss-Schmuck.

## 7h. Zweibeiner 2.0 und Helden (`scripts/stil3d/zweibeiner_bau.gd`)
Alle Helden und die zwölf Zweibeiner-Gegner (Bandit, Kultist, Nekromant,
Skelett, Toddiener, Schattenkrieger, Todesmeister, Kleindämon,
Dämonenbeschwörer, Dämonenkönig, Pilzhexe, Hexenmeisterin) sind
Gliederpuppen aus `ZweibeinerBau`; `FigurenBau.fuer_archetyp`/`held_mit`
leiten dorthin (Aufrufer unverändert). Der Troll bleibt in `FigurenBau`.
- **Proportion** (Höhe 1.0 ohne Hut, Blick +Z): Kopf r 0.21 bei y 0.86,
  Rumpf 0.33–0.63, Beine kurz, Schultern (±0.22, 0.6), Arm 0.26 mit
  Hand-Kugel — Griffe gehen DURCH die Hand (`_lage`: Waffenrichtung in
  Weltmaßen der Ruhepose). Je Figur EIN Silhouetten-Merkmal über den
  Schultern (Helmkamm, Zipfelkapuze, Zauberhut, Goldreif, Stehkragen,
  Widderhörner, Fliegenpilz, Hexenhut, Knochenkrone …) und eines auf
  Handhöhe (Waffe, Kerze, Laterne, Buch, Sense, Feuerball).
- **Körperbau** (`_koerper`, Option `bau`): normal, keil (Tank,
  Schattenkrieger), schmal (Schurke, Bandit), glocke (Robe ohne Beine),
  schwebend (Robe läuft spitz aus, Todesmeister); Skelett, Kleindämon und
  Dämonenfürst bauen frei. Vorgebeugte/schiefe Figuren kippen den
  Oberkörper-Bausatz um die Hüfte (`Gliederpuppe.uebernehmen`), nie per Node.
  Kopf als Glied nur, wo er sich bewegt (Toddiener, Pilzhexe, Todesmeister,
  Dämonenfürst).
- **Gesicht:** Helden große Augen mit Glanz, Brauen (mutig 8°, freundlich
  −6°), kleiner Mund, Wangen in Rosenquarz; Böse schmale Augen/25°-Brauen,
  Untote hohle Höhlen mit Glühpupille, Dämonen Schlitzpupillen. Kapuzen
  sitzen HINTER dem Kopf (Gesicht frei) bzw. mit schwarzem Loch (Kultist).
- **Leuchtfarbe = Element** an Augen UND Waffe/Fokus (Seele = Tod,
  Glut/Flamme = Dämon, Lila = Schatten, Moos = Gift, Kristall/Gold = Held).
  Elite-Akzent und Boss-Siegelrot färben genau diese Teile (eigener
  Cache-Schlüssel). Boss: Hörner ×1.3 mit glühenden Spitzen; Todesmeister
  und Dämonenkönig tragen eine eigene Großkrone (`hat_krone`).
- **Helden nach Ausrüstung** (`ZweibeinerBau.held_info`): Platte = Tank
  (Keil, Brustplatte mit Grat und Nieten, Schulterplatten mit Goldrand,
  Nasalhelm mit Helmkamm, Umhang), Kette = Krieger (Kettenhaube,
  Wappenrock), Leder = Schurke (Zipfelkapuze, Kreuzgurte, Halstuch bei
  Dolchen, Köcher), Stab ohne Platte = Magier (Glocke, geknickter
  Zauberhut, Kristallstab in Element-Farbe) bzw. Heiler (Stola, Haube,
  schwebender Goldreif, Ringstab, Heiligkreuz an der Kette), ohne Rüstung
  = Abenteurer (Weste, Halstuch, drei Frisuren). Rollenzeichen nur an
  Helden. Sekundärfarbe = Farbe × 0.65, bei dunklen Farben aufgehellt
  (`sekundaer`). Farbwahl-Symbol = Tank; Sonderfarben schmücken ihn
  (Obsidian Glutkamm, Silber weißer Kamm, Bernstein Goldnieten, Smaragd/
  Rosenquarz/Mitternacht/Drachenblut Umhang in der Farbe). Frisur und
  Haarfarbe aus dem Namen (`a["haar"]`), Stab-Kristall aus dem Element des
  ersten Zaubers (`a["element"]`) — reine Optik.
- **Animation:** Profile in `Gliederpuppe.PROFILE` je Waffe
  (held_einhand, held_zweihand, held_dolche, held_bogen, held_armbrust,
  held_turm, held_stab, held_heiler; mit Rundschild held_schild,
  held_stab_schild, held_heiler_schild — der Schildarm hebt höchstens 25°)
  und je Gegner (Archetyp-ID). Ohne Ellbogen kippt ein Stab mit dem Arm —
  Stabträger heben den Arm seitlich (Stabspitze über den Kopf) und neigen
  ihn dann zum Gegner, statt ihn hochzureißen. MenueKulisse belebt die
  Party im Idle.
- **Sitz von Waffen und Kleidung** (Korrektur nach Durchsicht 2026-11-02,
  abgesichert in `grafik_selftest` „Figur-Lagen“ über
  `ZweibeinerBau.messpunkte` — Hand, Waffenlage, Kopf je Figur, nur beim
  Backen geschrieben):
  - Zweihand (Großschwert, Großaxt, Hammer): Querhaltung schräg vor der
    Brust, ~25–35° steigend. Handziele je Körperbau (`HAND_ZIELE`, rechte
    Hand unten am Griffende, linke höher am Griff), die Arme zeigen per
    `_ruhe_zu` darauf (Ruhe ohne Y-Anteil). Die Waffenachse läuft von der
    rechten DURCH die linke Handmitte; der Nebenarm ist dafür 0.3 lang
    (`ZWEIHAND_ARM_L`, sonst reicht er bei Schultern ±0.22 nicht vor die
    Brust). Keil-Rumpf (Tank): Brustplatte und Grat reichen vorn bis
    z 0.257/0.275, der Rumpf oben r 0.25 — die Hände liegen dort weiter vorn
    (z 0.26/0.28), beide Arme länger (`ZWEIHAND_ARME_KEIL` 0.3/0.34), der
    Griff steigt nur ~15° und liegt in Ruhe/Idle VOR Brustplatte, Grat und
    Rumpf (Selbsttest über den Messpunkt `brust`; beim Schlag +20° streift
    er die Plattenkante kurz). Großschwert mit Griff über beide Hände (`_schwert` Option
    `griff`), Großaxt 0.1 tiefer gefasst; Kopf und Klinge links neben dem
    Gesicht (vorn, Porträt −24°, −40°). held_zweihand dreht beide Arme
    immer gleich und nur um X (gemeinsame Schulterachse) — der Griff bleibt
    geschlossen; Ausholen −12°, Schlag +20°, die Wucht kommt aus der Wurzel.
  - Armbrust: Pistolengriff (Schaft durch die Handmitte), `quer` = links
    — Bolzenschiene und Sehne oben; die linke Hand hängt frei.
  - Turmschild: flach vor der Brust (Rückseite z ≥ 0.27 vor Brustplatte,
    Grat und Wappenrock), Hand direkt dahinter; die Ramme hebt den Arm nur
    16° (Kante bleibt unter dem Kinn). Rundschild: Scheibe vor der
    Kleidung (Mitte z ≥ 0.28, Gieren 10°), Hand direkt dahinter, Handziel je
    Körperbau (Robe höher).
  - Zauberbuch `quer` = links (Seiten oben, Deckel als V); Heiligkreuz mit
    Gegendrehung lotrecht unter der Hand; Trompetenärmel eng an der
    Schulter, weit zur Hand, Saum am weiten Ende; Zughand des Bogens zur
    Sehne hin vor Brust/Kinn; Tank-Stab nach vorn/außen an Schulterplatte
    und Goldrand vorbei (`STAB_KEIL`); Tank-Helm ohne Brauen, Rand 0.02
    höher, Nasenschutz ohne Hülle; Köcher bei jeder Rolle mit Köcher
    (Umhang bzw. Rücken, oben vorgeneigt wie Umhang und Robe).
  - Gegner: Todesmeister-Sensenblatt außen über der rechten Schulter (nie
    über der Krone); Dämonenfürst trägt das Flammenschwert einhändig steil
    neben dem Kopf, die freie Faust hängt seitlich und holt gegenläufig aus.
    Beschwörer-Buch wie das Heldenbuch `quer` = links (Seiten oben, Deckel
    als V).
  - Prüfsummen vorher/nachher (`figuren_pruefsumme.gd`, 1684 Figuren):
    geändert nur Figuren mit Befund; Bandit, Kleindämon, Troll, alle
    Vierbeiner/Kreaturen und 160 Helden-Kombinationen mesh- und posengleich.
    Leistung (ohne VSync, Stufe 20): Dungeon vorher 434/431, nachher
    436/441 FPS; Kampf mit `--fxschleife` vorher 1688/1715, nachher
    1719/1693 FPS — kein messbarer Unterschied.
- **Budget** (Selbsttest): Gegner ≤ 6000 Dreiecke, Bosse (Todesmeister,
  Dämonenkönig) ≤ 12000, Helden ≤ 8000; 2–5 Glieder, je Teil 2 Aufrufe
  (Zweibeiner 6–12 statt 20–50 vorher).
- **Porträts** (`PortraitStudio`): Figuren in 3/4-Ansicht (−24°) vor einer
  dunklen Scheibe mit Messingrand, Zweibeiner als Brustbild ab `brust_y`
  bis knapp über den Kopf-Anker (lange Stäbe ragen hinaus); gemeinsames
  Licht `PortraitStudio.licht_aufbauen` (Filmic ohne Glow, warmes
  Führungs- und kühles Kantenlicht) auch für `FigurenVorschau` (rahmt nach
  Figurhöhe). Nach dem Rendern wird das Bild in die zurückgegebene
  ImageTexture kopiert und der SubViewport freigegeben.
- **Showcase:** `stil_showcase.tscn -- --modus=figuren [--fern] [--boss]
  [--ruestung] [--pose=angriff:0.2] [--blick=x,y,z,fov]`.
- **Prüfstände** (Dev): `held_pruefstand.tscn -- --held=<farbe>/<waffe>/
  <neben>/<rüstung>/<element>/<haar>[;…] [--drehungen=0,40,-40]
  [--pose=angriff:<s>] [--blick=x,y,z,fov] [--kampfblick] [--portraet]`,
  `gegner_pruefstand.tscn -- --gegner=<id>[:boss|:elite][;…]
  [--pose=panzer|segen|ruf|woge:<s>]`; Vorher/Nachher aller Figuren:
  `-s scripts/dev/figuren_pruefsumme.gd -- --aus=<datei>` (je Figur MD5 der
  Meshes und der Glied-Drehungen aller Posen — unbetroffene Figuren
  müssen gleich bleiben).

## 7i. Vierbeiner und Schleime 2.0 (`scripts/stil3d/vierbeiner_bau.gd`)
Wolf, Bär, Schattenbestie, Leichenfresser, Dämonenjäger, Verfluchte Katze,
Verfluchter Dachs, Verfluchter Bock, (Verfluchter) Igel, Schleim,
Schleimstapel, König- und Gottschleim sind Gliederpuppen aus
`VierbeinerBau`; `FigurenBau.fuer_archetyp`, `wolf()`, `schleim(farbe)`
(Beschwörung, bunter Fallback-Schleim) und `schleimstapel()` leiten dorthin.
- **Chibi-Vierbeiner statt Kasten** (`_chassis`/`_kopf`): Kopf-Kugel r
  0.14–0.23 (~40 % der Höhe) ist das größte, hellste Element; Schnauze
  `lang` (Hunde), `kurz` (Bär), `kegel` (Dachs) oder `katze` (Backen +
  Schnurrhaare); Rumpf = geneigte Kapsel mit Brust-, Schulter- und
  Keulenkugeln, Beine kurze konische Zylinder mit Pfote bzw. Huf. Ungleich
  lange Vorder-/Hinterbeine geben die Haltung (Hyäne hoch vorn, Dachs flach).
- **Ein Kennzeichen je Art** außen an der Silhouette: Wolf Spitzohren +
  Buschschwanz (25° schräg) + helle Halskrause; Bär Schulterbuckel +
  Rundohren + Mondsichel; Schattenbestie Rückenkamm mit Glimmspitzen,
  Stirnauge, glühendes Maul; Leichenfresser abfallender Rücken, Wirbel und
  Rippen, Knickohr, Knochen im Maul; Dämonenjäger Sichelhörner,
  Flammenmähne, Dornenhalsband, Flammenschwanz; Katze Riesenkopf mit lila
  Schlitzaugen und Fragezeichen-Schwanz; Dachs flacher Keil mit drei
  Runen-Panzerplatten und schwarzen Längsstreifen bis auf die Schnauze (kein
  Panda: heller Kopf, Streifen laufen spitz zur Nase); Bock Geweihkrone mit
  Fluchkristallen und Moos, Hals mit Mähne, weißer Spiegel; Igel voller
  Stachelkranz; Schleim Tropfen mit Zipfel; Stapel Turm aus drei Lagen mit
  eigenen Gesichtern; König Krone, Schnurrbart, Hermelin-Umhang, Zepter;
  Gott Heiligenschein (geneigt, knapp über dem Scheitel), Stirnauge,
  Trabanten-Orbit, Glutscheibe am Boden (Bodenteil `gott_ring`).
- **Glieder:** `koerper` (Beine + Rumpf, Gelenk an den Hinterpfoten bzw.
  beim Igel in der Kugelmitte) > `kopf` (Hals) > `kiefer`, dazu `schwanz`
  am Steiß. Schleime: Körper im Rumpf, `zipfel`, `lage1` > `lage2`,
  `krone` + `zepter`, `schein` + `orbit`. Wolf 8 Zeichenaufrufe statt ~39,
  Schleim 4 statt ~19; im Stufe-20-Dungeon 285 statt 363–375 Aufrufe je
  Bild (FPS ohne VSync ~439 statt ~426), im Kampf Wolf/Bär/Schleim mit
  Effekt-Schleife 293 statt 509.
- **Leuchten** nur an Augen, Runen, Flammen und Spitzen (Vertex-Alpha);
  Elite-Akzent (lila) und Boss-Siegelrot färben Iris und Fluch-Akzente
  (eigener Cache-Schlüssel); Boss: Hörner/Geweih/Stacheln ×1.3 mit
  glühenden Spitzen, Boss-Krone am Kopf-Glied (König: eigene Großkrone,
  Gott: Schein statt Krone, beide `hat_krone`).
- **Animation** (Profile hund, baer, panther, ghul, hoellenhund, katze,
  dachs, bock, igel, schleim, stapel, koenig, gott in
  `Gliederpuppe.PROFILE`): Wolf Sprungbiss mit Zuschnappen, Bär Aufrichten +
  Prankenhieb mit Stampf-Platsch (Phase: Brüllen), Panther Bogensprung,
  Ghul Kopfschütteln, Höllenhund Ruck-Scan + Ausfall, Katze Hüpfer + drei
  Krallen-Rucke, Dachs Abtauchen, Bock gesenktes Geweih (Phase: Aufsteigen
  + Hufstampfer), Igel Vorwärtsrolle (Koerper 360°), Schleime Stretch und
  Platsch, Stapel kippende Spitze, König Hüpfer mit Bauchklatscher, Gott
  Aufsteigen + Orbit-Wirbel. Neu: Glied `hub` = [Anheben, Quer-,
  Hoch-Skalierung] der WURZEL (`Gliederpuppe.hub_anwenden`, nur Kampfbühne
  und Showcase; Bodenteile bleiben am Boden) — Sprünge und Squash ohne
  Glied-Skalierung. Wellenform 3 = Stoß (Schnüffeln/Scharren alle n s),
  Form 4 = Ruck-Scan (−1/0/+1/0, Jagdblick).
- **Porträt:** Vierbeiner als Brustbild ab Bauchhöhe (`brust_y`), Schleime
  ab Boden — der Kopf füllt das 40-px-Bild, Ringe und Orbit machen es
  nicht klein.
- **Budget:** Gegner ≤ 6000 Dreiecke (Schleim 2000, Wolf 5600, Dämonenjäger 5950),
  Gott/Bosse ≤ 12000; Kleinteile mit grober Unterteilung, Streifen,
  Zähne, Krallen, Runen, Schnurrhaare ohne Hülle.
- **Showcase:** `stil_showcase.tscn -- --modus=vierbeiner [--fern] [--boss]
  [--elite] [--nur=<id>] [--ohne-namen] [--pose=angriff:0.24|treffer:…|phase:…]
  [--blick=x,y,z,fov]` — Aufstellung wie der Entwurf. Kampf mit festen
  Gegnern: `dungeon_shot.tscn -- --szene=res://scenes/battle/battle_scene.tscn
  --stufe=5 --feinde=wolf,verfluchtbock,verfluchtkatz [--boss] [--schmuck]`.
- **Varianten** (Rest Paket 4, Abschnitt 9): Schleim und Schleimstapel
  färben den Körper (`VierbeinerBau.SCHLEIM_VARIANTEN`: Metall silber mit
  zweitem Glanzstreifen, Gift giftgrün mit Leuchtblasen und Gifttropfen,
  Heil rosé mit leuchtendem Heilkreuz am Zipfel); Vierbeiner tragen ein
  Leuchtmal auf der Stirn (`_kopf`, Farbe der Variante bzw. Element-Schicht).
  Sonderposen der Fähigkeiten siehe 7k.

## 7j. Krabbler, Flieger, Golems, Geist, Mimic 2.0 (`scripts/stil3d/kreaturen_bau.gd`)
Spinne, Pilzkrabbel, Fledermaus, Geist, Golem, Pilzstamm und Mimic sind
Gliederpuppen aus `KreaturenBau` (höchstens drei Glieder je Figur);
`FigurenBau.fuer_archetyp` und die alten Einzelbauer `krabbler()`,
`golem()`, `fledermaus()`, `geist()`, `mimic()` leiten dorthin.
- **„Kreaturen-Diorama": ein Silhouetten-Zeichen je Art**, das in der
  45°-Draufsicht (Zoom 16) und im Porträt trägt: Spinne = flaches X mit
  hochgestellten Knien, leuchtende Sanduhr, Fellringe, Kieferklauen mit
  Giftzahn und Tropfen, vier glimmende Nebenaugen; Pilzkrabbel = rote
  Pilzkuppel (Lippe, Tupfen, Lamellen) mit zwei erhobenen Scheren, Stiel-
  augen vor dem Hutrand und Sporen (Größe 0.8 im Mesh); Fledermaus =
  gezacktes M aus Fingerknochen-Flügeln mit eingebuchteter Flughaut
  (`Bausatz.dreieck`), Ohrenkopf mit Nasenblatt und Fangzähnen; Geist =
  Tropfen mit S-förmig gekringeltem Schweif (durchgehende Kegelstumpf-
  Kette, geist » geist_tief, das Ende glimmt), Seelen-Locke, hohle Augen
  mit Seelenlicht, Klauenarme mit Eisenschelle und zerrissener Kette —
  leuchtet über Vertex-Alpha, keine Transparenz; Golem = Gorilla-Trapez aus
  gefasten Steinblöcken (`Bausatz.fasenbox`), Lebenskern als Y-Rune,
  Kristallgrat, Mooskissen, Zyklopenauge im Visierschlitz, Riesenfäuste;
  Pilzstamm = Fliegenpilz-Schirm auf Baumstumpf, Gesicht im Stamm, Wurzel-
  füße, Leuchtpilze (Heiler-Zeichen), Baumschwamm-Schild; Mimic = die
  Risiko-Truhe erwacht (Goldreifen, Hörner, Goldschloss) mit offenem
  Halbzylinder-Deckel als Oberkiefer, Augen auf der Deckelkante, Zunge,
  Münzen im Maul, vier Krallenbeine.
- **Glieder:** Spinne `koerper`, `beine_a`, `beine_b` (abwechselnd links/
  rechts — Trippeln); Pilzkrabbel `schere_l/r`, `beine`; Fledermaus
  `fluegel_l/r`; Geist `schweif`, `arm_l/r`; Golem `kopf`, `arm_l/r`;
  Pilzstamm `rumpf` > `arm_l/r` (Wurzelfüße bleiben am Boden); Mimic
  `deckel` (Ruhe 55° offen), `zunge`. 6–8 Zeichenaufrufe statt 12–42;
  Kampf Spinne/Golem/Fledermaus mit Effekt-Schleife 329 statt 573 Aufrufe
  (FPS ~1840 statt ~1640), Dungeon Stufe 20 unverändert ~287 (FPS ~454).
- **Ruheposen = beste Silhouette** (Porträt, ferne Figuren): Flügel
  gespreizt, Scheren erhoben, Deckel offen, Arme greifend. Porträts als
  Brustbild über `brust_y` (Gesicht füllt das 40-px-Bild), der Mimic ganz.
- **Boss:** glühende Augen/Akzente im Siegelrot, Zähne/Hörner ×1.3;
  Urgolem (bossfähig) mit Kristallkrone, Schulterdornen, Faust-Runen und
  rotem Lebenskern. Elite färbt Augen, Sanduhr, Sporen, Kern lila.
- **Animation** (Profile spinne, krabbe, fledermaus, geist, golem,
  pilzstamm, mimic): Spinne Aufbäumen + Vorschnappen, Krabbe Scheren zurück
  und Zuschnappen (Treffer: Scheren vors Gesicht), Fledermaus Flügelschlag,
  Sturzflug (Flügel falten, aufreißen), Geist Ausholen + Seelengriff mit
  peitschendem Schweif, Golem Faust über den Kopf + Hieb (Phase: Beben mit
  beiden Fäusten), Pilzstamm Stammhieb, Mimic hechelt, reißt den Deckel auf,
  springt und schnappt zu.
- **Budget:** ≤ 6000 Dreiecke (Spinne, Krabbel, Pilzstamm, Mimic knapp
  darunter), Boss ≤ 12000.
- **Showcase:** `stil_showcase.tscn -- --modus=kreaturen` (Optionen wie
  vierbeiner) und `--modus=varianten [--ids=bandit,wolf,…] [--fern]`:
  normal, Elite, Champion, Gülden, Strahlend, Kartenhüter, Boss je Zeile —
  Rang- und Boss-Schmuck aller Gruppen auf einen Blick.
- **Varianten** (Rest Paket 4, Abschnitt 9): Golem `GOLEM_VARIANTEN`
  (Rost = rostbrauner Stein, Roststellen statt Moos; Kristall = Blaustein,
  leuchtende Kristallkissen, hellerer Grat; Obsidian = schwarzes Glas mit
  glühenden Lavarissen), Geist `GEIST_VARIANTEN` (Zorn = rot glühender
  Schweif, böse Brauen; Frost = eisblau mit zwei Eissplittern am Kopf;
  Polter = Sepia), Fledermaus mit Stirnmal; Spinne, Krabbel, Pilzstamm und
  Mimic tragen den Akzent an Sanduhr, Sporen, Leuchtpilzen bzw. Augen.
- **Feinschliff (Rest Paket 4):** Geist-Schweif aus offenen Röhren
  (`cap_top/cap_bottom = false`), die Gelenkkugeln tragen die Hülle — vorher
  stachen die aufgeblähten Deckel-Ränder aus dem Nachbarabschnitt und zogen
  eine feine Linie zwischen Körper und Schweif (eine Kugel-Hülle zeigt nur
  ihre Silhouette). Fledermaus-Flügel in Ruhe 45° nach hinten gekippt
  (Glied-Ruhe x −45°): in der 45°-Draufsicht breite Flughaut statt eines
  Strichs, von vorn weiter offen; Flügelschlag läuft in der gekippten Ebene.

## 7k. Sonderposen der Fähigkeiten (`Gliederpuppe.POSEN`, Rest Paket 4)
Die Kampfbühne erfährt, WELCHE Fähigkeit läuft — reine Anzeige, nie eine
Absicht: `Battle._skill_wirken_innen` sendet das Ereignis `faehigkeit`
(von = Anwender, `skill` = sprachfeste Kennung aus Meta `fx_id`, `form`,
`zauber`). Die Kennung setzen `EnemyLibrary._skill` (deutscher Grundname,
auch für Kombo-Skills auf Englisch) und `EnemyFactory` (Varianten-Skills).
`KampfEffekte.abspielen` reicht es sofort an `KampfBuehne3D.faehigkeit`
weiter (Host und Koop-Gast: das Ereignis geht mit den übrigen Effekten
übers Netz, `von` = Netz-ID); die Bühne setzt `pose`/`pose_t`, und
`Gliederpuppe.kampf_takt` unterdrückt den Angriff am Puls dieses Zugs
(`POSE_STATT_ANGRIFF` 0.6 s).
- **Posen:** heulen (Kopf hoch, Maul auf: Brüllen, Klagelied, Jagdinstinkt,
  Krallensturm), panzer (ducken, Arme/Fäuste vor den Körper: Panzer,
  Steinhaut, Granitwall, Schattenschild, Pilzpanzer — sonst jede
  Selbst-Fähigkeit), stachel (Igel rollt sich zur Stachelkugel, zittert),
  segen (Arme/Zepter hoch, halten: Königliche Gnade, Heilende Aura,
  Wurzelheilung, Urschleim-Segen — sonst Aura/Verbündeter), woge
  (Flächenzauber: anschwellen und aufschlagen: Schleimwoge, Urschleim-Flut,
  Säureschwall, Schleimregen, Beben, Erdbeben, Hufstampfer, Dunkler Odem,
  Sporenwolke — sonst Flächen-Zauber), ruf (Beschwörung: beide Arme hoch).
- **Spuren:** `POSEN[profil][pose]` ist ein String (die gleichnamige Spur
  des Profils — meist die Phasen-Pose, die genau dafür gebaut ist: Bär
  brüllt, Golem bebt) oder ein Dictionary mit Schlüsselbildern je Glied
  (erstes und letztes Bild 0, Orbit volle Umdrehungen). Zweibeiner-Gegner
  ohne eigenen Eintrag nehmen "zweibeiner". **Gegenstandsträger**
  (Nekromant, Beschwörer, Hexenmeisterin, Pilzhexe, Kultist, Toddiener,
  Skelett, Schattenkrieger; Todesmeister und Dämonenfürst außer der Woge)
  nehmen die `_TR_*`-Spuren: ohne Ellbogen kippt der Gegenstand mit dem
  Arm, darum hebt der Arm MIT Gegenstand nur ~22–40° (vorn/seitlich, die
  Spitze bleibt ≤ 45° zur Senkrechten über der Hand, nie durch Kopf oder
  Kapuze), nur der freie Arm reißt hoch; Skelett/Schattenkrieger halten in
  der Panzer-Pose Klinge und Schild nach innen geschwenkt vor Brust und
  Hals. Kultist-Angriff: Kerze bleibt aufrecht. Ohne passende Pose
  (`pose_fuer` liefert "") spielt der normale Angriff. `beleben(..., pose_t, pose)` bleibt
  allokationsfrei und ohne Hilfsaufruf je Glied (Kampf ~1600 FPS).
- **Dev:** `stil_showcase.tscn -- --modus=posen [--gruppe=0|1]
  [--pose=x:0.6] [--ruhe]`; im echten Ablauf `dungeon_shot.tscn --
  --szene=res://scenes/battle/battle_scene.tscn --feinde=verfluchtigel,…
  --posetest=Stachelpanzer [--fxzeit=0.55]`.

## 8. Lebendigkeit
Keine Skelett-Animationen. Bewegung entsteht aus Transform-Tweens:
Idle-Wippen (Meta `wippen`), Schleim-Quetschen (Meta `quetschen`),
Fackel-Flackern; Angriffe/Treffer als Squash & Stretch, Sprünge, Wackeln.
Gliederpuppen (7g) drehen zusätzlich ihre Glieder nach `Gliederpuppe.PROFILE`
(`beleben`) — reine Rotationen, keine Tweens, kein Skript je Figur. Sprung,
Stretch und Platsch der ganzen Figur kommen aus dem Profil-Glied `hub`
(Wurzel-Anheben/-Skalierung, 7i); Glieder bleiben unskaliert.

## 9. Varianten (passt zum Gegner-Baukasten)
Varianten = Palettentausch + Zusatzteile: Elite/Champion bekommen Hörner,
Krone, Aura-Ring; Elemente färben Akzente (Feuer = Flamme/Glut, Gift =
Moos/Schleim, Eis = Kristall). „Güldene" Gegner: Gold-Palette.
- **Klassen-Varianten und Element-Schicht an der Figur** (Rest Paket 4):
  `EnemyFactory.build` setzt Meta `variante` (Name der Variante klein, z. B.
  "metall", "bogenschütze"; reine Anzeige, keine Regel liest sie), die
  Element-Schicht steht schon in `element_schicht`. `FigurenBau.fuer_kaempfer`
  (und der Koop-Gast über `var`/`el` in den Netz-Daten, beide über
  `FigurenBau.gegner_optionen`) reicht beides an `fuer_archetyp`; dort wird
  daraus die Kennung (`akzent_kennung`: Variante, sonst "el<N>") und die
  Akzentfarbe (`VARIANTEN_AKZENT` bzw. `Stil3D.ELEMENT_FARBEN` — dieselben
  Farben wie die Kampf-Effekte). Ohne Elite färbt sie Augen, Runen, Kerne
  und Waffen-Fokus; dazu ein kleines Leuchtmal in ihrer Farbe, auch bei
  Elite (lila Augen): Gürtel- bzw. Robenstein (Zweibeiner, `_koerper`),
  Stirnmal (Vierbeiner, Fledermaus). Schleime, Golem und Geist färben dazu
  Körper/Stein/Seelenleib und tragen kleine Teile (7i, 7j). Silhouette und
  Zeichenaufrufe bleiben, Budget ≤ 6000 Dreiecke (Bandit, Troll und
  Schattenkrieger dafür etwas gröber: Kapuzenrand, Schal, Schulterkugeln;
  Iris 6 statt 8 Segmente). Porträt-Schlüssel enthält Variante und Element.
- Im Dungeon sind Varianten noch nicht ausgewürfelt (erst beim Kampf) — die
  Figuren dort zeigen die Grundform.
- **Showcase:** `stil_showcase.tscn -- --modus=akzente [--zeile=0..6]
  [--fern]` — Schleim, Stapel, Golem, Geist, Wolf, Bandit je mit allen
  Varianten, letzte Zeile Spinne mit allen Element-Schichten.

## 10. Technik-Fallen
- Renderer bleibt **Compatibility** (läuft überall); MSAA 4×, Glow an.
  Grenzen: 8 Punktlichter pro Objekt, 32 gesamt; globale Shader-Uniforms
  ohne Arrays. Transparenz nur, wo nötig — Wände dithern opak.
- Tonemapping: überall Filmic über `Stil3D.umgebung` — Dungeon, Kampfhalle,
  Menü-Kulisse, Porträts, Icons und FigurenVorschau.
- UI-Texturen: Bilder in `UiHolz` in der Mitte periodisch malen und
  `TILE_FIT` nutzen; `StyleBoxTexture` kennt keinen Schatten — Schein als
  Bildrand + `expand_margin`. Code, der eine Theme-StyleBox duplizieren will,
  darf sie nicht als `StyleBoxFlat` casten (`UiHolz.box_mit_rand`).
- Punkt-/Spotlichter je Objekt zählen: Kampfhalle = genau 8 (7c). Neue
  Lichter dort nur gegen ein anderes tauschen, nie dazulegen.
- `get_meta(name, null)` meldet bei fehlendem Eintrag einen Fehler — erst
  `has_meta` prüfen.
- Neue `class_name`-Skripte: einmal `godot --headless --path . --import`,
  sonst kennt der Skript-Check die Klasse nicht.
- `Environment.background_color` erwartet **lineare** Farbe →
  `PAL["nacht"].srgb_to_linear()`, sonst wird der Hintergrund lila.
- Klassen-Aliase per `const X := Klasse` werden nicht als Konstante
  akzeptiert → Klassennamen direkt verwenden.
- Screenshot-Modus der Showcase: `-- --shot=<pfad.png> [--modus=kampf]`.
- **Vertexfarben bleiben sRGB:** Godot wandelt `COLOR` im Shader selbst
  nach linear. Vorab linearisiert (wie für `source_color`) wird doppelt
  gewandelt — Holz wurde rot (Testbild 2026-11-01).
- Ein Control mit Größe 0 wird nicht gezeichnet (Zeichenebenen ohne
  Anker brauchen eine Größe — die Minimap-Marker blieben sonst unsichtbar).
