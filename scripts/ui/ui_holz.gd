class_name UiHolz
extends RefCounted
## Oberflächen-Material (STIL-3D.md 7e): Tafeln und Knöpfe aus dunklem Holz
## mit Messing, Tooltips aus Pergament. Alles prozedural als ImageTexture und
## StyleBoxTexture (9-Slice) — KEIN Shader auf Knöpfen (ein CanvasItem-Shader
## färbte auch den Text). Jede Art entsteht EINMAL und bleibt gecacht.
##
## Die Maserung ist in der Mitte periodisch (Periode = Bildgröße minus
## 2 × Rand): Mitte und Kantenstreifen werden gekachelt statt gestreckt, die
## Holzlinien bleiben auf jeder Knopf- und Tafelgröße gleich fein.
##
## Arten (ARTEN): tafel (Messingrahmen, Nieten), tafel_aktiv (Glut-Rahmen —
## Held am Zug), fach (eingelassene Zeile in einer Tafel), feld
## (Eingabefeld), pergament (Tooltip), knopf / knopf_hover / knopf_druck /
## knopf_aus / knopf_aktiv (gewählter Reiter).
## "schein" = Glutschein außen herum (Bildpunkte, als expand_margin — die
## Tafel selbst behält ihre Größe), z. B. die Karte des Helden am Zug.

## w, h = Bildgröße; rand = 9-Slice-Rand; holz = [dunkel, hell] (PAL);
## rahmen: messing | gold | kerbe | knopf | pergament; innen = Innenrand
## des Inhalts [links/rechts, oben, unten]; alpha = Deckkraft des Holzes.
const ARTEN := {
	"tafel": {"w": 152, "h": 152, "rand": 14, "holz": ["ui_holz_tief", "ui_holz"], "rahmen": "messing",
		"fase": 6.0, "innen": [16, 12, 12], "alpha": 0.97},
	"tafel_aktiv": {"w": 168, "h": 168, "rand": 14, "holz": ["ui_holz", "ui_holz_hell"], "rahmen": "gold",
		"fase": 6.0, "innen": [16, 12, 12], "alpha": 0.98, "schein": 10},
	"fach": {"w": 104, "h": 72, "rand": 8, "holz": ["ui_kerbe", "ui_holz_tief"], "rahmen": "kerbe",
		"fase": 4.0, "innen": [12, 8, 8], "alpha": 0.92},
	"feld": {"w": 104, "h": 56, "rand": 8, "holz": ["ui_kerbe", "ui_kerbe"], "rahmen": "kerbe",
		"fase": 3.0, "innen": [10, 6, 6], "alpha": 0.96},
	"pergament": {"w": 128, "h": 96, "rand": 10, "holz": ["pergament_dunkel", "pergament"], "rahmen": "pergament",
		"fase": 3.0, "innen": [12, 8, 8], "alpha": 1.0},
	"knopf": {"w": 112, "h": 44, "rand": 10, "holz": ["ui_holz", "ui_holz_hell"], "rahmen": "knopf",
		"fase": 3.0, "innen": [14, 6, 9], "alpha": 1.0},
	"knopf_hover": {"w": 112, "h": 44, "rand": 10, "holz": ["ui_holz_hell", "holz"], "rahmen": "knopf",
		"fase": 3.0, "innen": [14, 6, 9], "alpha": 1.0, "saum": "messing_hell"},
	"knopf_druck": {"w": 112, "h": 44, "rand": 10, "holz": ["ui_holz_tief", "ui_holz"], "rahmen": "knopf",
		"fase": 3.0, "innen": [14, 9, 6], "alpha": 1.0, "gedrueckt": true, "saum": "gold"},
	"knopf_aus": {"w": 112, "h": 44, "rand": 10, "holz": ["ui_holz_tief", "ui_holz"], "rahmen": "knopf",
		"fase": 3.0, "innen": [14, 6, 9], "alpha": 0.82, "grau": 0.55},
	"knopf_aktiv": {"w": 112, "h": 44, "rand": 10, "holz": ["ui_holz_tief", "ui_holz"], "rahmen": "knopf",
		"fase": 3.0, "innen": [14, 7, 8], "alpha": 1.0, "saum": "gold", "gefuellt": true},
}

static var _boxen: Dictionary = {}     ## Art » StyleBoxTexture
static var _bilder: Dictionary = {}    ## Art » Image (für Tests und Vorschau)
static var _glanz: Dictionary = {}     ## Farbe » GradientTexture2D (Seltenheits-Hintergrund)
static var _schalter: Dictionary = {}  ## "an|gesperrt" » ImageTexture (CheckButton-Icons)


static func _p(name: String) -> Color:
	return Stil3D.farbe(name)


## StyleBoxTexture einer Art (gecacht — alle Knöpfe teilen dieselbe).
## Innenränder bleiben pro Art fest; wer andere braucht, dupliziert.
static func box(art: String) -> StyleBoxTexture:
	if _boxen.has(art):
		return _boxen[art]
	var d: Dictionary = ARTEN.get(art, ARTEN["tafel"])
	var stil := StyleBoxTexture.new()
	stil.texture = ImageTexture.create_from_image(bild(art))
	var schein := float(d.get("schein", 0))
	var r := float(d["rand"]) + schein
	stil.set_expand_margin_all(schein)
	stil.texture_margin_left = r
	stil.texture_margin_right = r
	stil.texture_margin_top = r
	stil.texture_margin_bottom = r
	stil.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	stil.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	var innen: Array = d["innen"]
	stil.content_margin_left = innen[0]
	stil.content_margin_right = innen[0]
	stil.content_margin_top = innen[1]
	stil.content_margin_bottom = innen[2]
	_boxen[art] = stil
	return stil


## Kopie einer Art mit eigenem Innenrand ringsum (Fenster, Hauptmenü).
static func box_mit_rand(art: String, innen: int) -> StyleBoxTexture:
	var stil := box(art).duplicate() as StyleBoxTexture
	stil.set_content_margin_all(innen)
	return stil


## Das Bild einer Art (einmal gemalt, gecacht).
static func bild(art: String) -> Image:
	if not _bilder.has(art):
		vorbereiten([art] if ARTEN.has(art) else ["tafel"])
		if not ARTEN.has(art):
			_bilder[art] = _bilder["tafel"]
	return _bilder[art]


## Malt die noch fehlenden Arten (Standard: alle) GLEICHZEITIG auf den
## Arbeits-Threads (WorkerThreadPool) — der erste Theme-Aufbau wartet nur
## noch auf die größte Tafel statt auf die Summe (Rest Paket 5: ~130 ms).
## Die Threads malen nur in eigene Bilder; eingetragen wird danach hier.
static func vorbereiten(arten: Array = ARTEN.keys()) -> void:
	var offen: Array = []
	for art in arten:
		if not _bilder.has(art) and ARTEN.has(art):
			offen.append(art)
	if offen.is_empty():
		return
	_l8_tabelle()  # vor den Threads anlegen (statisch, danach nur gelesen)
	var ergebnisse: Array = []
	ergebnisse.resize(offen.size())
	var sperre := Mutex.new()
	var malen := func(i: int) -> void:
		var img := _malen(ARTEN[offen[i]])
		sperre.lock()
		ergebnisse[i] = img
		sperre.unlock()
	if offen.size() == 1:
		malen.call(0)
	else:
		var gruppe := WorkerThreadPool.add_group_task(malen, offen.size(), -1, true, "UiHolz")
		WorkerThreadPool.wait_for_group_task_completion(gruppe)
	for i in offen.size():
		_bilder[offen[i]] = ergebnisse[i]


## Grauwerte genau wie Image.get_pixel(L8).r — die Maserung liest die
## Rauschbilder als Bytes (ein Tabellenzugriff statt get_pixel je Punkt).
static var _l8 := PackedFloat32Array()


static func _l8_tabelle() -> PackedFloat32Array:
	if _l8.is_empty():
		var stufen := PackedByteArray()
		for i in 256:
			stufen.append(i)
		var img := Image.create_from_data(256, 1, false, Image.FORMAT_L8, stufen)
		var tabelle := PackedFloat32Array()
		tabelle.resize(256)
		for i in 256:
			tabelle[i] = img.get_pixel(i, 0).r
		_l8 = tabelle
	return _l8


## Holzmaserung 0..1, periodisch in (px, py): Jahresringe als Sinus über y,
## verbogen von nahtlosem Rauschen, dazu feine Fasern (in x gestreckt).
static func maserung(px: int, py: int, saat: int) -> PackedFloat32Array:
	var grob := FastNoiseLite.new()
	grob.seed = saat
	grob.frequency = 0.035
	var fein := FastNoiseLite.new()
	fein.seed = saat + 17
	fein.frequency = 0.11
	var bild_grob := grob.get_seamless_image(px, py, false, false, 0.1, true)
	var bild_fein := fein.get_seamless_image(px, py, false, false, 0.1, true)
	var werte := PackedFloat32Array()
	werte.resize(px * py)
	var ringe := maxf(1.0, roundf(py / 9.0))
	var lut := _l8_tabelle()
	var l8 := bild_grob.get_format() == Image.FORMAT_L8 and bild_fein.get_format() == Image.FORMAT_L8
	var grob_b := bild_grob.get_data()
	var fein_b := bild_fein.get_data()
	for y in py:
		var zeile := y * px
		var faser_zeile := ((y * 3) % py) * px
		var basis := float(y) / py * ringe
		for x in px:
			var verbiegen: float
			var faser: float
			if l8:
				verbiegen = lut[grob_b[zeile + x]]
				faser = lut[fein_b[faser_zeile + x]]
			else:
				verbiegen = bild_grob.get_pixel(x, y).r
				faser = bild_fein.get_pixel(x, (y * 3) % py).r
			var ring := 0.5 + 0.5 * sin(TAU * (basis + verbiegen * 1.6))
			werte[zeile + x] = clampf(ring * ring * 0.55 + faser * 0.45, 0.0, 1.0)
	return werte


## Abstand zum Bildrand mit abgeschrägten Ecken (Fase).
static func _abstand(x: float, y: float, w: float, h: float, fase: float) -> float:
	var rechts := w - 1.0 - x
	var unten := h - 1.0 - y
	var d := minf(minf(x, y), minf(rechts, unten))
	d = minf(d, (x + y - fase) * 0.7071)
	d = minf(d, (rechts + y - fase) * 0.7071)
	d = minf(d, (x + unten - fase) * 0.7071)
	return minf(d, (rechts + unten - fase) * 0.7071)


const _RAHMEN_ART := {"messing": 1, "gold": 1, "kerbe": 2, "pergament": 3, "knopf": 4}


static func _malen(d: Dictionary) -> Image:
	var w: int = d["w"]
	var h: int = d["h"]
	var schein: int = d.get("schein", 0)
	var rand: int = d["rand"] + schein
	var px := w - 2 * rand
	var py := h - 2 * rand
	var tw := float(w - 2 * schein)  # Tafel ohne Schein
	var th := float(h - 2 * schein)
	var holz := maserung(px, py, int(hash(d["holz"])) % 997)
	var dunkel := _p(d["holz"][0])
	var hell := _p(d["holz"][1])
	var rahmen: String = d["rahmen"]
	var rahmen_art: int = _RAHMEN_ART.get(rahmen, 0)
	var fase: float = d["fase"]
	var alpha: float = d["alpha"]
	var grau: float = d.get("grau", 0.0)
	var saum: Color = _p(d["saum"]) if d.has("saum") else Color.TRANSPARENT
	var gedrueckt: bool = d.get("gedrueckt", false)
	var gefuellt: bool = d.get("gefuellt", false)
	var kerbe := _p("ui_kerbe")
	var glut := _p("glut")
	var tinte := _p("tinte")
	var knopf_farben := [_p("messing_dunkel"), _p("ui_kerbe"), _p("gold")]
	# Held am Zug: Rahmen in Glut statt Gold — Gold und Messing liegen zu
	# dicht beieinander, die aktive Karte muss auf einen Blick auffallen.
	var messing := glut if rahmen == "gold" else _p("messing")
	var tw_i := int(tw)
	var th_i := int(th)
	var daten := PackedByteArray()
	daten.resize(w * h * 4)
	for y in h:
		var korn_zeile := ((y - rand + py * 4) % py) * px
		for x in w:
			var dist := _abstand(x - schein, y - schein, tw, th, fase)
			var c := Color(0, 0, 0, 0)
			if dist < 0.0 and schein > 0:
				var g := clampf(1.0 + dist / schein, 0.0, 1.0)
				c = Color(glut, g * g * 0.95)
			if dist >= 0.0:
				var korn := holz[korn_zeile + ((x - rand + px * 4) % px)]
				c = dunkel.lerp(hell, korn)
				c.a = alpha
				match rahmen_art:
					1:
						c = _tafel_rand(c, dist, _naechste_seite(x - schein, y - schein, tw_i, th_i), messing, kerbe)
					2:
						c = _kerbe_rand(c, dist, _naechste_seite(x - schein, y - schein, tw_i, th_i), kerbe)
					3:
						c = _pergament_rand(c, dist, korn, hell, dunkel, tinte)
					4:
						c = _knopf_rand(c, dist, y, h, saum, gedrueckt, kerbe, gefuellt, knopf_farben)
				if grau > 0.0:
					var l := c.get_luminance()
					c = Color(lerpf(c.r, l, grau), lerpf(c.g, l, grau), lerpf(c.b, l, grau), c.a)
				# Kantenglättung der Fase (halber Bildpunkt).
				c.a *= clampf(dist + 0.5, 0.0, 1.0)
			var i := (y * w + x) * 4
			daten[i] = clampi(roundi(c.r * 255.0), 0, 255)
			daten[i + 1] = clampi(roundi(c.g * 255.0), 0, 255)
			daten[i + 2] = clampi(roundi(c.b * 255.0), 0, 255)
			daten[i + 3] = clampi(roundi(c.a * 255.0), 0, 255)
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, daten)
	if rahmen == "messing" or rahmen == "gold":
		var o := schein + 8
		for p in [Vector2i(o, o), Vector2i(w - 1 - o, o), Vector2i(o, h - 1 - o), Vector2i(w - 1 - o, h - 1 - o)]:
			_niete(img, p, messing)
	return img


## Nächste Bildkante: 0 oben, 1 rechts, 2 unten, 3 links. Licht nach der
## Kante statt nach der Bildhälfte — sonst entstünde mitten im Seitenstreifen
## eine Stufe, die das 9-Slice-Kacheln wiederholt. Gleichstand: die erste
## Kante in dieser Reihenfolge.
static func _naechste_seite(x: int, y: int, w: int, h: int) -> int:
	var beste := 0
	var kleinster := y
	if w - 1 - x < kleinster:
		beste = 1
		kleinster = w - 1 - x
	if h - 1 - y < kleinster:
		beste = 2
		kleinster = h - 1 - y
	if x < kleinster:
		beste = 3
	return beste


## Licht je Kante: oben hell, unten dunkel, Seiten neutral.
const KANTEN_LICHT := [0.22, 0.0, -0.2, 0.06]


## Tafel: dunkle Außenkante, Messingrahmen mit Licht von oben, Kerbe,
## Schattenfuge auf dem Holz.
static func _tafel_rand(c: Color, dist: float, seite: int, messing: Color, kerbe: Color) -> Color:
	if dist < 1.0:
		return Color(kerbe, 0.95)
	if dist < 4.5:
		var licht: float = KANTEN_LICHT[seite]
		var m := messing.lightened(maxf(0.0, licht)).darkened(maxf(0.0, -licht))
		if dist < 2.0:
			m = m.lightened(0.18)  # Glanzkante
		elif dist > 3.6:
			m = m.darkened(0.25)
		return Color(m, 1.0)
	if dist < 5.5:
		return Color(kerbe, 1.0)
	if dist < 11.0:
		return Color(c.darkened(0.45 * (1.0 - (dist - 5.5) / 5.5)), c.a)
	return c


## Eingelassenes Fach / Eingabefeld: Kerbe, Schatten oben (vertieft),
## heller Saum unten.
static func _kerbe_rand(c: Color, dist: float, seite: int, kerbe: Color) -> Color:
	if dist < 1.0:
		return Color(kerbe, maxf(c.a, 0.9))
	if dist < 3.0:
		if seite == 0 or seite == 3:
			return Color(c.darkened(0.5), c.a)
		return Color(c.lightened(0.12), c.a)
	return c


## Pergament: Ränder angedunkelt (alt), dünne Tintenkante.
## hell/dunkel = PAL „pergament“ / „pergament_dunkel“ (vorab gelesen).
static func _pergament_rand(_c: Color, dist: float, korn: float, hell: Color, dunkel: Color,
		tinte: Color) -> Color:
	if dist < 1.2:
		return Color(tinte, 1.0)
	return Color(hell.lerp(dunkel, korn * 0.45 + (1.0 - minf(dist / 9.0, 1.0)) * 0.5), 1.0)


## Knopf: Holzklotz mit dunkler Kontur, Lichtkante oben, Messing-Unterkante
## (Tiefe) — gedrückt ohne Unterkante; saum = Rahmenlinie (Hover/Aktiv).
## farben = PAL [messing_dunkel, ui_kerbe, gold] (vorab gelesen, nicht je Punkt).
static func _knopf_rand(c: Color, dist: float, y: int, h: int, saum: Color, gedrueckt: bool,
		kerbe: Color, gefuellt: bool, farben: Array) -> Color:
	var unten := float(h - 1 - y)
	var kante := 2.0 if gedrueckt else 5.0
	if dist < 1.0:
		return Color(kerbe, maxf(c.a, 0.95))
	if unten < kante:
		var m: Color = farben[0] if not gedrueckt else farben[1]
		return Color(m.lightened(0.15 * (unten / kante)), c.a)
	if saum.a > 0.0 and dist < 2.6:
		return Color(saum, c.a)
	var top := float(y)
	if top < 3.0 and not gedrueckt:
		return Color(c.lightened(0.16), c.a)
	if gefuellt and dist < 6.0:
		return Color(c.lerp(farben[2], 0.22 * (1.0 - (dist - 2.6) / 3.4)), c.a)
	return c


## Messingniete (3×3, Licht von oben links).
static func _niete(img: Image, mitte: Vector2i, messing: Color) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var licht := 0.35 if dx + dy < 0 else (-0.25 if dx + dy > 0 else 0.1)
			img.set_pixel(mitte.x + dx, mitte.y + dy,
				messing.lightened(maxf(0.0, licht)).darkened(maxf(0.0, -licht)))


## Fokusrahmen (eigene Rolle, STIL-3D.md 7e): kräftiger heller Ring in
## PAL „fokus“ mit dunkler Außenlinie und Leuchtschein — kühl gegen das
## warme Holz, unterscheidbar von Hover (Messing), Aktiv (Gold) und den
## Seltenheitsfarben. Ein StyleBoxFlat ohne Füllung, über dem Knopf.
static var _fokus: StyleBoxFlat


static func fokus_box() -> StyleBoxFlat:
	if _fokus != null:
		return _fokus
	var box_f := StyleBoxFlat.new()
	box_f.draw_center = false
	box_f.set_corner_radius_all(6)
	box_f.set_border_width_all(3)
	box_f.border_color = _p("fokus")
	# Ohne Außenrand: Listen in ScrollContainern schneiden alles außerhalb
	# des Knopfs ab — der Ring liegt auf der Knopfkante, nur der Schein ragt
	# hinaus.
	box_f.set_expand_margin_all(0)
	box_f.shadow_color = Color(_p("fokus"), 0.5)
	box_f.shadow_size = 8
	box_f.anti_aliasing = true
	_fokus = box_f
	return _fokus


## An/Aus-Schalter (CheckButton-Icons) im Holz-Look: Messing-Schiene mit
## dunkler Kerbe, „aus“ = heller Knauf links auf leerer Schiene, „an“ =
## Schiene in Gold gefüllt, Knauf rechts. Godots Standard-Schalter (dunkle
## Schiene) verschwand auf dem dunklen Holz. Je Zustand einmal gemalt.
const SCHALTER_GROESSE := Vector2i(44, 24)


static func schalter(an: bool, gesperrt := false) -> ImageTexture:
	var key := "%s|%s" % [an, gesperrt]
	if _schalter.has(key):
		return _schalter[key]
	var w := SCHALTER_GROESSE.x
	var h := SCHALTER_GROESSE.y
	var r := h * 0.5 - 1.0
	var mitte_y := h * 0.5
	var knauf_x := (w - h * 0.5) if an else h * 0.5
	var schiene := _p("gold").darkened(0.15) if an else _p("ui_kerbe")
	var rand := _p("messing_hell") if an else _p("messing")
	var knauf := _p("ui_text_hell") if an else _p("ui_text").darkened(0.12)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var px := float(x) + 0.5
			var py := float(y) + 0.5
			# Kapsel: Abstand zur Mittellinie minus Radius (negativ = innen).
			var nx := clampf(px, h * 0.5, w - h * 0.5)
			var d := Vector2(px - nx, py - mitte_y).length() - r
			var k := Vector2(px - knauf_x, py - mitte_y).length() - (r - 3.0)
			var c := Color(0, 0, 0, 0)
			if d < 0.5:
				c = rand if d > -2.0 else schiene
				c.a = clampf(0.5 - d, 0.0, 1.0)
			if k < 0.5:
				var licht := knauf.lightened(0.25) if py < mitte_y - 2.0 else knauf
				c = c.blend(Color(licht, clampf(0.5 - k, 0.0, 1.0)))
				if k > -1.2:
					c = c.blend(Color(_p("ui_kerbe"), 0.5 * clampf(0.5 - k, 0.0, 1.0)))
			if gesperrt:
				var l := c.get_luminance()
				c = Color(lerpf(c.r, l, 0.6), lerpf(c.g, l, 0.6), lerpf(c.b, l, 0.6), c.a * 0.6)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_schalter[key] = tex
	return tex


## Weicher Seltenheits-Hintergrund hinter Icons: radialer Schein in der
## Seltenheitsfarbe (LootGenerator.RARITY_COLORS), je Farbe einmal.
static func glanz(farbe: Color) -> Texture2D:
	var key := farbe.to_html()
	if _glanz.has(key):
		return _glanz[key]
	var verlauf := Gradient.new()
	verlauf.set_color(0, Color(farbe, 0.55))
	verlauf.set_color(1, Color(farbe, 0.0))
	verlauf.add_point(0.45, Color(farbe, 0.22))
	var tex := GradientTexture2D.new()
	tex.gradient = verlauf
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.42)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 64
	tex.height = 64
	_glanz[key] = tex
	return tex


## Filter für Item-Icons aus PortraitStudio (128 px mit Mipmaps, angezeigt
## mit 26–87 px): weich verkleinert statt „nearest“ (Projektstandard für
## Pixelkunst) — sonst Treppen und abreißende dünne Linien.
const ICON_FILTER := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
## Knöpfe mit Item-Icon (Kampf-Item-Menü): der Filter gilt auch für den
## Text — „nearest“ mit Mipmaps lässt die Schrift unverändert (Schrift-
## texturen haben keine Mipmaps) und nimmt fürs Icon die passende Stufe.
const ICON_FILTER_KNOPF := CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS


## Icon-Bild fester Größe (Tränke, Materialien, Biome in Listenzeilen).
static func icon(tex: Texture2D, groesse := 40) -> TextureRect:
	var bild := TextureRect.new()
	bild.texture = tex
	bild.texture_filter = ICON_FILTER
	bild.custom_minimum_size = Vector2(groesse, groesse)
	bild.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bild.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bild.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bild.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return bild


## Kleiner Chip für das Item-Level (unten rechts auf der Kachel): dunkle
## Messingplakette, die Zahl liegt nie direkt auf dem Icon.
static var _chip_stil: StyleBoxFlat


static func level_chip(stufe: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _chip_stil == null:  # eine StyleBox für alle Chips (Inventar: 60+ je Seite)
		_chip_stil = StyleBoxFlat.new()
		_chip_stil.bg_color = Color(_p("ui_holz_tief"), 0.92)
		_chip_stil.border_color = _p("messing")
		_chip_stil.set_border_width_all(1)
		_chip_stil.set_corner_radius_all(4)
		_chip_stil.content_margin_left = 4
		_chip_stil.content_margin_right = 4
		_chip_stil.content_margin_top = 0
		_chip_stil.content_margin_bottom = 0
	chip.add_theme_stylebox_override("panel", _chip_stil)
	var zahl := Label.new()
	zahl.text = str(stufe)
	zahl.add_theme_font_size_override("font_size", 10)
	zahl.add_theme_color_override("font_color", _p("messing_hell"))
	zahl.add_theme_constant_override("shadow_offset_y", 0)
	zahl.add_theme_constant_override("shadow_offset_x", 0)
	zahl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(zahl)
	return chip
