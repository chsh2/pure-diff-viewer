extends Control

var viewer_ref 

func _process(_delta: float) -> void:
    queue_redraw()
    
func _draw() -> void:
    if not viewer_ref:
        return
    var layer_pos = viewer_ref.position
    var layer_scale = viewer_ref.scale.x
    
    var base_grid_size = 16
    var grid_size = base_grid_size * layer_scale
    
    var start_x = fmod(layer_pos.x, grid_size)
    var start_y = fmod(layer_pos.y, grid_size)
    
    var line_color = Color(StyleConfig.color_secondary)
    line_color[3] = 0.2
    var w = size.x
    var h = size.y
    
    for x in range(start_x, w, grid_size):
        draw_line(Vector2(x, 0), Vector2(x, h), line_color)
    for y in range(start_y, h, grid_size):
        draw_line(Vector2(0, y), Vector2(w, y), line_color)
