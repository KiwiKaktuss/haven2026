shader_type canvas_item;

uniform vec4 background_color : source_color;
varying vec4 tint;

void vertex() {
    tint = COLOR;
}

void fragment() {
    vec4 pixel = texture(TEXTURE, UV);
    // Let the white card show through the sprite sheet's flat backdrop.
    pixel.a *= step(0.025, distance(pixel.rgb, background_color.rgb));
    COLOR = tint * pixel;
}
