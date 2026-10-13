class_name FehlerWaechter
extends Logger
## Zählt Skript-/Engine-Fehler während eines Selbsttests. Ein Laufzeitfehler
## bricht in GDScript nur die aktuelle Funktion ab — ohne Wächter meldet der
## Test danach trotzdem „OK“. Nutzung im Selbsttest:
##   var waechter := FehlerWaechter.anmelden()
##   … Tests …
##   failures += waechter.fehler_melden()

var anzahl := 0
var _mutex := Mutex.new()


static func anmelden() -> FehlerWaechter:
	var waechter := FehlerWaechter.new()
	OS.add_logger(waechter)
	return waechter


func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	anzahl += 1
	_mutex.unlock()


## Meldet aufgetretene Fehler, meldet sich ab und gibt ihre Anzahl zurück.
func fehler_melden() -> int:
	OS.remove_logger(self)
	if anzahl > 0:
		printerr("  FEHLER: %d Skript-/Engine-Fehler während des Tests (siehe oben)" % anzahl)
	return anzahl
