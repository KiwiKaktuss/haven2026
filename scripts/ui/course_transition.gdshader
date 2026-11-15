shader_type canvas_item;
render_mode unshaded;

uniform vec2 viewport_size = vec2(800.0, 640.0);
uniform vec2 circle_center = vec2(400.0, 320.0);
uniform float radius = 0.0;

void fragment() {
    // Pixel-space distance preserves a true circle at every aspect ratio.
    float distance_to_center = distance(UV * viewport_size, circle_center);
    float coverage = radius <= 0.0 ? 1.0 : smoothstep(radius - 0.8, radius + 0.8, distance_to_center);
    COLOR.a *= coverage;
}
