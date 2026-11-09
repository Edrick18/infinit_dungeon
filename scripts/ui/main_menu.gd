extends Control
## Altes Hub (scenes/main.tscn) — seit 2026-11-09 nur noch eine Weiche. Alle
## Wege „zurück ins Menü“ (Dungeon, Kampf, Kartenlager, Werkstatt, Co-op …)
## landen hier und werden weitergeleitet:
##   ohne Helden » Taverne (den ersten Helden erstellen),
##   sonst » die begehbare Stadt — auch Co-op-Gäste (gemeinsamer Platz,
##   Gebäude mit dem eigenen Spielstand).
## Autosave und Lade-Hinweis übernehmen Stadt und Taverne. Die frühere
## Gast-Ansicht war nach der Umstellung nicht mehr erreichbar und ist entfernt
## (Prüfung 2026-11-09).

const TAVERN_SCENE := "res://scenes/hub/tavern.tscn"


## Wohin die Weiche führt. `_gast` bleibt für Aufrufer erhalten, zählt aber
## nicht mehr (Gäste kommen ebenfalls in die Stadt).
static func weiche_ziel(party_leer: bool, _gast := false) -> String:
	return TAVERN_SCENE if party_leer else StadtSzene.STADT_SCENE


func _ready() -> void:
	theme = UiTheme.get_theme()
	get_tree().change_scene_to_file.call_deferred(weiche_ziel(GameState.party.is_empty()))
