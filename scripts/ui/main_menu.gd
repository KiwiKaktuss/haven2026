extends Control
signal inspect_requested
signal lab_requested

func _on_inspect_pressed() -> void:
    inspect_requested.emit()

func _on_lab_pressed() -> void:
    lab_requested.emit()
