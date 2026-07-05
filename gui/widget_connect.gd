extends Control
class_name WidgetConnect

var tension = 0.2

func apply_diff_style(del, add):
    if add:
        $Line2D.default_color = Color(StyleConfig.color_add)
    if del:
        $Line2D.material = preload("res://res/dash_line.tres")
        $Inlet/ColorRect.modulate.a = 0.25
        $Outlet/ColorRect.modulate.a = 0.25

func update_ends(start_pos: Vector2, end_pos: Vector2) -> void:
    var curve = Curve2D.new()
    var distance_y = abs(end_pos.y - start_pos.y)
    
    var p0_out_handle = Vector2(0, distance_y * tension)
    var p1_in_handle = Vector2(0, -distance_y * tension)
    
    curve.add_point(start_pos, Vector2.ZERO, p0_out_handle)
    curve.add_point(end_pos, p1_in_handle, Vector2.ZERO)
    
    $Line2D.points = curve.get_baked_points()
    $Outlet.set_position($Line2D.points[0])
    $Inlet.set_position($Line2D.points[-1])

func _ready() -> void:
    $Outlet/ColorRect.color = Color(StyleConfig.color_major)
    $Inlet/ColorRect.color = Color(StyleConfig.color_major)
    $Line2D.default_color = Color(StyleConfig.color_major)
    $Line2D.default_color.a = 0.5
