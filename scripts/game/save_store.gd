class_name SaveStore
extends RefCounted
## Stable IDs; malformed or incompatible fields fall back independently.
var path: String = "user://deck_golf.json"
var equipped: Array[StringName] = []
var records: Dictionary = {}

func read_save(catalog: CardCatalog, courses: CourseCatalog) -> void:
    equipped = catalog.default_deck.duplicate()
    records.clear()
    if not FileAccess.file_exists(path):
        return
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
        return
    var data: Dictionary = parser.data
    if data.get("version") != 1:
        return
    var candidate: Array[StringName] = []
    var raw: Variant = data.get("deck", [])
    if raw is Array:
        for id: Variant in raw:
            if id is String and catalog.find_card(StringName(id)) != null and not candidate.has(StringName(id)):
                candidate.append(StringName(id))
        # Preserve equipped choices when migrating earlier deck sizes.
        if raw.size() == candidate.size() and raw.size() in [4, CardCatalog.DECK_SIZE, 6]:
            equipped.assign(candidate.slice(0, CardCatalog.DECK_SIZE))
            for id: StringName in catalog.default_deck:
                if equipped.size() < CardCatalog.DECK_SIZE and not equipped.has(id):
                    equipped.append(id)
    var saved_records: Variant = data.get("records", {})
    if saved_records is Dictionary:
        for course: CourseDefinition in courses.courses:
            var time: Variant = saved_records.get(String(course.id))
            if (time is float or time is int) and is_finite(float(time)) and float(time) > 0.0:
                records[String(course.id)] = float(time)

func record_win(id: StringName, seconds: float) -> bool:
    if not is_finite(seconds) or seconds <= 0.0:
        return false
    var previous: float = float(records.get(String(id), INF))
    if seconds >= previous:
        return false
    records[String(id)] = seconds
    return true

func write_save() -> bool:
    var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify({"version": 1, "deck": equipped, "records": records}))
    file.flush()
    var error: Error = file.get_error()
    file.close()
    if error != OK:
        return false
    return DirAccess.rename_absolute(path + ".tmp", path) == OK
