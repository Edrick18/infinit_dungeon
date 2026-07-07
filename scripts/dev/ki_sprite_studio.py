# -*- coding: utf-8 -*-
"""Sprite-Studio: kleines Fenster um KI-Bilder per Klick in spielfertige
Pixel-Art zu verwandeln (Import-Pipeline mit Vorschau).

Start:  python scripts/dev/ki_sprite_studio.py  [bild.png ...]
        (oder Sprite-Studio.bat doppelklicken; Bilder auf die Bat
        ziehen laedt sie direkt vor)
"""
import os
import re
import sys
import threading
import tkinter as tk
from tkinter import filedialog, ttk

from PIL import Image, ImageTk

import ki_sprite_import as ksi

COMFY_OUTPUT = r"C:\Users\Lutz\Documents\comfy\ComfyUI\output"
VORSCHAU_PX = 320


def name_saeubern(dateiname):
    stamm = os.path.splitext(os.path.basename(dateiname))[0]
    stamm = stamm.lower().replace(" ", "_")
    for alt, neu in (("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")):
        stamm = stamm.replace(alt, neu)
    stamm = re.sub(r"[^a-z0-9_]+", "", stamm)
    # ComfyUI-Nummernschwaenze wie _00007_ abwerfen
    return re.sub(r"_\d{5,}_?$", "", stamm) or "sprite"


class Studio(tk.Tk):
    def __init__(self, start_dateien):
        super().__init__()
        self.title("Infinit Dungeon — Sprite-Studio")
        self.resizable(False, False)
        self.dateien = []
        self._vorschau_bild = None  # Referenz halten, sonst sammelt Tk es weg

        haupt = ttk.Frame(self, padding=12)
        haupt.grid()

        ttk.Button(haupt, text="Bilder wählen …", command=self.waehlen)\
            .grid(row=0, column=0, sticky="w")
        self.dateien_label = ttk.Label(haupt, text="keine Bilder gewählt")
        self.dateien_label.grid(row=0, column=1, columnspan=2, sticky="w", padx=8)

        ttk.Label(haupt, text="Name:").grid(row=1, column=0, sticky="w", pady=(8, 0))
        self.name_feld = ttk.Entry(haupt, width=28)
        self.name_feld.grid(row=1, column=1, sticky="w", padx=8, pady=(8, 0))
        ttk.Label(haupt, text="(bei mehreren wird nummeriert)")\
            .grid(row=1, column=2, sticky="w", pady=(8, 0))

        ttk.Label(haupt, text="Größe:").grid(row=2, column=0, sticky="w", pady=(8, 0))
        self.groesse = ttk.Combobox(haupt, values=("64", "96", "128", "192", "256"),
            width=6, state="readonly")
        self.groesse.set("128")
        self.groesse.grid(row=2, column=1, sticky="w", padx=8, pady=(8, 0))

        self.start_knopf = ttk.Button(haupt, text="» Zu Pixel-Art machen",
            command=self.konvertieren)
        self.start_knopf.grid(row=3, column=0, columnspan=2, sticky="we", pady=12)
        ttk.Button(haupt, text="Ausgabe-Ordner öffnen",
            command=lambda: os.startfile(os.path.abspath(ksi.OUT_DIR)))\
            .grid(row=3, column=2, sticky="we", pady=12, padx=(8, 0))

        # Radiergummi: in der Vorschau auf eine Stelle klicken » die
        # zusammenhaengende Flaeche dieser Farbe wird transparent.
        self._radiert = False
        self._ergebnis = None       # PIL-Bild des letzten Ergebnisses
        self._ergebnis_pfad = None
        self._faktor = 1
        self._verlauf = []
        self.radier_knopf = ttk.Button(haupt, text="Radiergummi: AUS",
            command=self.radier_umschalten, state="disabled")
        self.radier_knopf.grid(row=5, column=0, sticky="we", pady=(10, 0))
        self.undo_knopf = ttk.Button(haupt, text="Rückgängig",
            command=self.rueckgaengig, state="disabled")
        self.undo_knopf.grid(row=5, column=1, sticky="we", pady=(10, 0), padx=8)
        ttk.Label(haupt, text="(AN: Klick in die Vorschau löscht die Fläche)")\
            .grid(row=5, column=2, sticky="w", pady=(10, 0))

        # Platzhalter als echtes Bild — width/height eines Text-Labels
        # zaehlt in ZEICHEN/ZEILEN, nicht Pixeln (Riesenfenster-Falle!).
        platzhalter = Image.new("RGBA", (VORSCHAU_PX, VORSCHAU_PX), (36, 31, 49, 255))
        self._vorschau_bild = ImageTk.PhotoImage(platzhalter)
        self.vorschau = tk.Label(haupt, image=self._vorschau_bild,
            background="#241f31")
        self.vorschau.grid(row=4, column=0, columnspan=3)

        self.status = tk.Text(haupt, width=54, height=6, state="disabled",
            background="#14141f", foreground="#c8c8dc")
        self.status.grid(row=6, column=0, columnspan=3, pady=(10, 0))
        self.vorschau.bind("<Button-1>", self._vorschau_klick)

        if start_dateien:
            self.setze_dateien([p for p in start_dateien if os.path.isfile(p)])

    def melden(self, text):
        self.status.configure(state="normal")
        self.status.insert("end", text + "\n")
        self.status.see("end")
        self.status.configure(state="disabled")

    def waehlen(self):
        dateien = filedialog.askopenfilenames(
            title="KI-Bilder wählen",
            initialdir=COMFY_OUTPUT if os.path.isdir(COMFY_OUTPUT) else ".",
            filetypes=[("PNG-Bilder", "*.png"), ("Alle Dateien", "*.*")])
        if dateien:
            self.setze_dateien(list(dateien))

    def setze_dateien(self, dateien):
        self.dateien = dateien
        if not dateien:
            return
        text = os.path.basename(dateien[0])
        if len(dateien) > 1:
            text += "  (+%d weitere)" % (len(dateien) - 1)
        self.dateien_label.configure(text=text)
        self.name_feld.delete(0, "end")
        self.name_feld.insert(0, name_saeubern(dateien[0]))

    def konvertieren(self):
        if not self.dateien:
            self.melden("Erst Bilder wählen!")
            return
        self.start_knopf.configure(state="disabled", text="arbeite …")
        threading.Thread(target=self._arbeiten, daemon=True).start()

    def _arbeiten(self):
        ksi.SIZE = int(self.groesse.get())
        basis = name_saeubern(self.name_feld.get() or "sprite")
        letzte = None
        for i, pfad in enumerate(self.dateien):
            name = basis if len(self.dateien) == 1 else "%s_%d" % (basis, i + 1)
            try:
                self.after(0, self.melden,
                    "verarbeite %s …" % os.path.basename(pfad))
                ksi.verarbeiten(pfad, name)
                letzte = os.path.join(ksi.OUT_DIR, name + ".png")
                self.after(0, self.melden, "  fertig » %s.png" % name)
            except Exception as fehler:
                self.after(0, self.melden, "  FEHLER: %s" % fehler)
        self.after(0, self._fertig, letzte)

    def _fertig(self, letzte):
        self.start_knopf.configure(state="normal", text="» Zu Pixel-Art machen")
        if letzte and os.path.isfile(letzte):
            self._ergebnis = Image.open(letzte).convert("RGBA")
            self._ergebnis_pfad = letzte
            self._verlauf = []
            self.radier_knopf.configure(state="normal")
            self.undo_knopf.configure(state="disabled")
            self._vorschau_zeigen()

    def _vorschau_zeigen(self):
        bild = self._ergebnis
        self._faktor = max(1, VORSCHAU_PX // bild.width)
        gross = bild.resize((bild.width * self._faktor,
            bild.height * self._faktor), Image.NEAREST)
        # Dungeon-dunkler Hintergrund hinter die Transparenz
        unterlage = Image.new("RGBA", gross.size, (36, 31, 49, 255))
        unterlage.alpha_composite(gross)
        self._vorschau_bild = ImageTk.PhotoImage(unterlage)
        self.vorschau.configure(image=self._vorschau_bild, text="",
            width=unterlage.width, height=unterlage.height)

    # --- Radiergummi -------------------------------------------------------

    def radier_umschalten(self):
        self._radiert = not self._radiert
        self.radier_knopf.configure(
            text="Radiergummi: AN" if self._radiert else "Radiergummi: AUS")
        self.vorschau.configure(cursor="crosshair" if self._radiert else "")

    def rueckgaengig(self):
        if not self._verlauf:
            return
        self._ergebnis = self._verlauf.pop()
        self._ergebnis.save(self._ergebnis_pfad)
        self._vorschau_zeigen()
        if not self._verlauf:
            self.undo_knopf.configure(state="disabled")
        self.melden("rückgängig gemacht")

    def _vorschau_klick(self, event):
        if not self._radiert or self._ergebnis is None:
            return
        x = event.x // self._faktor
        y = event.y // self._faktor
        if not (0 <= x < self._ergebnis.width and 0 <= y < self._ergebnis.height):
            return
        self._region_entfernen(x, y)

    def _region_entfernen(self, sx, sy):
        """Zusammenhaengende Flaeche gleicher Palettenfarbe transparent
        stanzen und die Kontur ums neue Loch nachziehen."""
        from collections import deque
        bild = self._ergebnis
        px = bild.load()
        w, h = bild.size
        seed = px[sx, sy]
        if seed[3] == 0:
            self.melden("da ist schon Transparenz")
            return
        self._verlauf.append(bild.copy())
        if len(self._verlauf) > 20:
            self._verlauf.pop(0)
        ziel = seed[:3]

        def passt(farbe):
            # Toleranz 40: erwischt benachbarte Palettentoene desselben
            # Flecks (Weiss + Blassmint), aber nicht die Koerperfarbe.
            return all(abs(farbe[i] - ziel[i]) <= 40 for i in range(3))

        entfernt = []
        gesehen = {(sx, sy)}
        q = deque([(sx, sy)])
        while q:
            x, y = q.popleft()
            if px[x, y][3] == 0 or not passt(px[x, y][:3]):
                continue
            entfernt.append((x, y))
            px[x, y] = (0, 0, 0, 0)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in gesehen:
                    gesehen.add((nx, ny))
                    q.append((nx, ny))
        # Kontur ums neue Loch (Outline-Dunkel wie in der Pipeline)
        outline = ksi.RGB[0] + (255,)
        for x, y in entfernt:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0:
                    px[nx, ny] = outline
        bild.save(self._ergebnis_pfad)
        self.undo_knopf.configure(state="normal")
        self._vorschau_zeigen()
        self.melden("%d Pixel entfernt (Fläche bei %d,%d)" % (len(entfernt), sx, sy))


if __name__ == "__main__":
    try:
        Studio(sys.argv[1:]).mainloop()
    except Exception:
        # pythonw hat keine Konsole — Fehler sichtbar machen statt schlucken.
        import traceback
        from tkinter import messagebox
        fehler = traceback.format_exc()
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                "_studio_fehler.txt"), "w", encoding="utf-8") as f:
            f.write(fehler)
        try:
            messagebox.showerror("Sprite-Studio", fehler)
        except Exception:
            pass
