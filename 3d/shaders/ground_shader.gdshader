shader_type spatial;
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // Get the X and Z coordinates (Y is up in 3D)
    vec2 pos = world_position.xz;
    
    // Determine which quadrant we're in
    vec3 color;
    
    if (pos.x >= 0.0 && pos.y >= 0.0) {
        // Top-right quadrant - Red
        color = vec3(0.8, 0.0, 0.0);
    }
    else if (pos.x < 0.0 && pos.y >= 0.0) {
        // Top-left quadrant - Green
        color = vec3(0.0, 0.8, 0.0);
    }
    else if (pos.x < 0.0 && pos.y < 0.0) {
        // Bottom-left quadrant - Blue
        color = vec3(0.0, 0.0, 0.8);
    }
    else {
        // Bottom-right quadrant - Yellow
        color = vec3(0.8, 0.5, 0.0);
    }
    
    ALBEDO = color;
}