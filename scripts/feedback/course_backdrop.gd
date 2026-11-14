extends CanvasLayer
## Course-specific pale skies keep the original terrain's material colors clear.
@export var palettes: PackedColorArray = PackedColorArray([
    Color(0.95, 0.98, 0.95), Color(0.93, 0.97, 1.0),
    Color(1.0, 0.97, 0.91), Color(0.96, 0.94, 1.0)])

func configure(index: int) -> void:
    $Sky.color = palettes[clampi(index, 0, palettes.size() - 1)]
