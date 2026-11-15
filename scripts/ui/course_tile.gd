extends Button

const ARTWORK: Texture2D = preload("res://art/difficulty.png")
const ACCENTS: Array[Color] = [Color("287d58"), Color("68748e"), Color("2467bf"), Color("a23798")]

func _ready() -> void:
    var artwork_material := ShaderMaterial.new()
    artwork_material.shader = preload("res://scripts/ui/course_artwork.gdshader")
    artwork_material.set_shader_parameter("background_color", ARTWORK.get_image().get_pixel(2, 2))
    $Margin/Content/Artwork/Canvas/Image.material = artwork_material
    $Margin/Content/Artwork/Canvas.resized.connect(_layout_artwork)
    _layout_artwork()

func _layout_artwork() -> void:
    var canvas: Control = $Margin/Content/Artwork/Canvas
    var image: TextureRect = $Margin/Content/Artwork/Canvas/Image
    # Integer magnification keeps the small source illustration crisp at every size.
    var magnification: float = maxf(1.0, floorf(minf(canvas.size.x / 46.0, canvas.size.y / 30.0)))
    image.size = Vector2(46, 30) * magnification
    image.position = ((canvas.size - image.size) * 0.5).floor()

func configure(course: CourseDefinition, index: int, record: float) -> void:
    var image := AtlasTexture.new()
    image.atlas = ARTWORK
    # Exclude the sprite sheet's one-pixel dividers from each illustration.
    image.region = Rect2(1 + (index % 2) * 48, 1 + (index / 2) * 32, 46, 30)
    $Margin/Content/Artwork/Canvas/Image.texture = image
    $Margin/Content/Details/Number.text = "%02d" % (index + 1)
    $Margin/Content/Details/Number.add_theme_color_override("font_color", ACCENTS[index])
    $Margin/Content/Details/Title.text = course.title
    $Margin/Content/Details/Time.text = GameHUD.format_time(record) if record > 0.0 else "—"
    tooltip_text = "%02d · %s\n%s" % [index + 1, course.title, "Best: " + GameHUD.format_time(record) if record > 0.0 else "No record yet — finish this course to set one."]
    accessibility_name = "Level %d, %s, %s" % [index + 1, course.title, "record " + GameHUD.format_time(record) if record > 0.0 else "no record yet"]
