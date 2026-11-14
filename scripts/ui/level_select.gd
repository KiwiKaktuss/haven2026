extends Control
signal course_requested(index: int)
signal back_requested
@export var courses: CourseCatalog = preload("res://resources/levels/catalog.tres")

func _ready() -> void:
    for button: Node in $Center/Content.get_children():
        if button is Button:
            button.add_theme_color_override("font_focus_color", Color(0.17, 0.18, 0.24, 1))
    $Center/Content/Back.pressed.connect(func() -> void: back_requested.emit())
    for index: int in range(courses.courses.size()):
        get_node("Center/Content/Course%s" % index).pressed.connect(func() -> void: course_requested.emit(index))

func show_records(records: Dictionary) -> void:
    for index: int in range(courses.courses.size()):
        var course: CourseDefinition = courses.courses[index]
        var record: float = float(records.get(String(course.id), 0.0))
        get_node("Center/Content/Course%s" % index).text = "%02d    %s%s" % [index + 1, course.title, "    ·    Best " + GameHUD.format_time(record) if record > 0 else ""]
