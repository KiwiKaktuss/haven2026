extends Control
signal course_requested(index: int)
signal back_requested
@export var courses: CourseCatalog = preload("res://resources/levels/catalog.tres")

@onready var grid: GridContainer = $Center/Content/Grid
@onready var content: VBoxContainer = $Center/Content
@onready var panel: Panel = $Center/MenuPanel

func _ready() -> void:
    $Center/Content/Back.pressed.connect(func() -> void: back_requested.emit())
    for index: int in range(courses.courses.size()):
        var button: Button = grid.get_child(index)
        button.configure(courses.courses[index], index, 0.0)
        button.pressed.connect(func() -> void: course_requested.emit(index))
        # Follow the visual rows with arrows, keeping Back reachable below them.
        button.focus_neighbor_left = button.get_path_to(grid.get_child(index - 1 if index % 2 else index))
        button.focus_neighbor_right = button.get_path_to(grid.get_child(index + 1 if index % 2 == 0 else index))
        button.focus_neighbor_top = button.get_path_to(grid.get_child(index - 2)) if index > 1 else button.get_path_to(button)
        button.focus_neighbor_bottom = button.get_path_to(grid.get_child(index + 2)) if index < 2 else button.get_path_to($Center/Content/Back)
    $Center/Content/Back.focus_neighbor_top = $Center/Content/Back.get_path_to(grid.get_child(2))
    resized.connect(_layout_cards)
    _layout_cards()

func _layout_cards() -> void:
    # Landscape cards give the illustration most of the space, even at 800 x 640.
    var width: float = floorf(clampf((size.x - 168.0) * 0.5, 300.0, 410.0))
    var height: float = floorf(clampf(minf((size.y - 242.0) * 0.5, width * 0.64), 198.0, 262.0))
    for button: Control in grid.get_children():
        button.custom_minimum_size = Vector2(width, height)
    content.custom_minimum_size.x = width * 2.0 + 16.0
    panel.custom_minimum_size = Vector2(content.custom_minimum_size.x + 48.0, content.get_combined_minimum_size().y + 36.0)

func show_records(records: Dictionary) -> void:
    for index: int in range(courses.courses.size()):
        var course: CourseDefinition = courses.courses[index]
        grid.get_child(index).configure(course, index, float(records.get(String(course.id), 0.0)))
