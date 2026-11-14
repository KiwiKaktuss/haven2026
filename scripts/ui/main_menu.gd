extends Control
signal inspect_requested

func _on_inspect_pressed() -> void:
    inspect_requested.emit()
