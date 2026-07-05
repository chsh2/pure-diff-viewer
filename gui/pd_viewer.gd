extends Control
class_name PdViewer

var is_panning: bool = false
var zoom_min: float = 0.2
var zoom_max: float = 3.0
var zoom_factor: float = 1.1
var elem_nodes = {}
var deleted_nodes = {}

const WidgetElementRes = preload("res://gui/widget_element.tscn")
const WidgetConnectRes = preload("res://gui/widget_connect.tscn")

func clear():
    elem_nodes = {}
    deleted_nodes = {}
    for child in $Foreground.get_children():
        if child.name != "TraceShadow":
            child.queue_free()
        
func reset_position():
    $Foreground.position = Vector2(0, 0)
    $Foreground.scale = Vector2(1, 1)
    
var subpatch_stacks = []
func load_subpatch(elem_info: PdElemClass):
    assert(elem_info.canvas_subpatch != null)
    if not elem_info.uid:
        load_pd_graph(elem_info.canvas_subpatch, null, null, false, true)
    else:
        var old_graph = subpatch_stacks[-1][2][elem_info.uid][1].canvas_subpatch
        for idx in old_graph:
            if idx >= 0:
                old_graph[idx].uid = 0
        for idx in elem_info.canvas_subpatch:
            if idx >= 0:
                elem_info.canvas_subpatch[idx].uid = 0        
        var uid_map = DiffAlgo.compare_and_assign_uid(elem_info.canvas_subpatch, old_graph)
        load_pd_graph(elem_info.canvas_subpatch, old_graph, uid_map, false, true)


func load_pd_graph(graph: Dictionary[int, PdElemClass], old_graph=null, uid_map=null, clear_stack=true, push_stack=true):
    clear()
    if clear_stack:
        subpatch_stacks.clear()
    if push_stack:
        subpatch_stacks.push_back([graph, old_graph, uid_map])
    $BackButton.visible = subpatch_stacks.size() > 1
    
    # Highlight visibility
    var show_deleted = $CornerPanel/VBox/ShowDeleted.button_pressed
    var show_added = $CornerPanel/VBox/ShowAdded.button_pressed
    var show_text_changed = $CornerPanel/VBox/ShowTextChanged.button_pressed
    var show_prop_changed = $CornerPanel/VBox/ShowPropertyChanged.button_pressed
    var show_moved = $CornerPanel/VBox/ShowMoved.button_pressed
    
    # Deleted elements
    if old_graph:
        assert(uid_map != null)
        for idx in old_graph:
            if idx >= 0 and not old_graph[idx].uid:
                var elem_node: WidgetElement = WidgetElementRes.instantiate()
                deleted_nodes[idx] = elem_node
                $Foreground.add_child(elem_node)
                elem_node.position = old_graph[idx].loc
                elem_node.apply_element_style(old_graph[idx])
                elem_node.apply_diff_style(show_deleted,0,0,0,0)
                if not show_deleted:
                    elem_node.visible = false
                
    # Current elements
    for idx in graph:
        if idx >= 0:
            var elem_info = graph[idx]
            var elem_node: WidgetElement = WidgetElementRes.instantiate()
            elem_nodes[idx] = elem_node
            $Foreground.add_child(elem_node)
            elem_node.position = elem_info.loc
            elem_node.apply_element_style(elem_info)
            if old_graph:
                if not elem_info.uid:
                    elem_node.apply_diff_style(0,show_added,0,0,0)
                else:
                    elem_info.get_diff(uid_map[elem_info.uid][1])
                    elem_node.apply_diff_style(0 , 0,
                        show_text_changed and elem_info.diff_statement != null,
                        show_prop_changed and elem_info.diff_attrs.size() > 0,
                        show_moved and elem_info.diff_loc
                    )
            
    # Current connections
    var conn_map = {}
    for idx in graph:
        if idx >= 0:
            var elem_info = graph[idx]
            var elem_node: WidgetElement = elem_nodes[idx]
            for i in len(elem_info.outlets):
                var outlets = elem_info.outlets[i]
                for outlet in outlets:
                    var connect_node: WidgetConnect = WidgetConnectRes.instantiate()
                    $Foreground.add_child(connect_node)
                    connect_node.update_ends(
                        elem_node.position + elem_node.get_outlet_pos(i),
                        elem_nodes[outlet[0]].position + elem_nodes[outlet[0]].get_inlet_pos(outlet[1])
                    )
                    if old_graph:
                        if not elem_info.uid or not graph[outlet[0]].uid:
                            connect_node.apply_diff_style(0, show_added)
                        else:
                            conn_map[[elem_info.uid, i, graph[outlet[0]].uid, outlet[1]]] = [connect_node, true]
                        
    # Deleted conntections
    if old_graph:
        for idx in old_graph:
            if idx >= 0:
                var elem_info = old_graph[idx]
                for i in len(elem_info.outlets):
                    var outlets = elem_info.outlets[i]
                    for outlet in outlets:
                        # Nodes exist but connection is removed
                        if idx not in deleted_nodes and outlet[0] not in deleted_nodes:
                            if [elem_info.uid, i, old_graph[outlet[0]].uid, outlet[1]] not in conn_map:
                                var connect_node: WidgetConnect = WidgetConnectRes.instantiate()
                                var src_node = elem_nodes[uid_map[elem_info.uid][0].index]
                                var dst_node = elem_nodes[uid_map[old_graph[outlet[0]].uid][0].index]
                                $Foreground.add_child(connect_node)
                                connect_node.update_ends(
                                    src_node.position + src_node.get_outlet_pos(i),
                                    dst_node.position + dst_node.get_inlet_pos(outlet[1])
                                )
                                connect_node.apply_diff_style(show_deleted,0)
                                if not show_deleted:
                                    connect_node.visible = false
                            else:
                                conn_map[[elem_info.uid, i, old_graph[outlet[0]].uid, outlet[1]]][1] = false
                        # Node itself removed
                        else:
                            var src_node = elem_nodes[uid_map[elem_info.uid][0].index] if idx not in deleted_nodes else deleted_nodes[idx]
                            var dst_node = elem_nodes[uid_map[old_graph[outlet[0]].uid][0].index] if outlet[0] not in deleted_nodes else deleted_nodes[outlet[0]]
                            var connect_node: WidgetConnect = WidgetConnectRes.instantiate()
                            $Foreground.add_child(connect_node)
                            connect_node.update_ends(
                                src_node.position + src_node.get_outlet_pos(i),
                                dst_node.position + dst_node.get_inlet_pos(outlet[1])
                            )
                            connect_node.apply_diff_style(show_deleted,0)
                            if not show_deleted:
                                    connect_node.visible = false
    # New connections
    for v in conn_map.values():
        if v[1]:
            v[0].apply_diff_style(0,show_added)

func _ready():
    $GridBackground.viewer_ref = $Foreground
    $Foreground/TraceShadow.color = StyleConfig.color_mov
    $Foreground/TraceShadow.color.a = 0.33
    $CornerPanel/VBox/ShowDeleted.add_theme_color_override("font_color", Color(StyleConfig.color_del))
    $CornerPanel/VBox/ShowDeleted.add_theme_color_override("font_pressed_color", Color(StyleConfig.color_del))
    $CornerPanel/VBox/ShowAdded.add_theme_color_override("font_color", Color(StyleConfig.color_add))
    $CornerPanel/VBox/ShowAdded.add_theme_color_override("font_pressed_color", Color(StyleConfig.color_add))
    $CornerPanel/VBox/ShowTextChanged.add_theme_color_override("font_color", Color(StyleConfig.color_mod))
    $CornerPanel/VBox/ShowTextChanged.add_theme_color_override("font_pressed_color", Color(StyleConfig.color_mod))
    $CornerPanel/VBox/ShowPropertyChanged.add_theme_color_override("font_color", Color(StyleConfig.color_mod_secondary))
    $CornerPanel/VBox/ShowPropertyChanged.add_theme_color_override("font_pressed_color", Color(StyleConfig.color_mod_secondary))
    $CornerPanel/VBox/ShowMoved.add_theme_color_override("font_color", Color(StyleConfig.color_mov))
    $CornerPanel/VBox/ShowMoved.add_theme_color_override("font_pressed_color", Color(StyleConfig.color_mov))

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
        is_panning = event.pressed
        get_viewport().set_input_as_handled()
        
    if event is InputEventMouseMotion and is_panning:
        $Foreground.position += event.relative
        get_viewport().set_input_as_handled()
        
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            zoom_at_mouse(zoom_factor)
            get_viewport().set_input_as_handled()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            zoom_at_mouse(1.0 / zoom_factor)
            get_viewport().set_input_as_handled()

func zoom_at_mouse(factor: float) -> void:
    var graph_layer = $Foreground
    var mouse_pos = get_local_mouse_position()
    var old_scale = graph_layer.scale
    var new_scale = old_scale * factor
    
    new_scale.x = clamp(new_scale.x, zoom_min, zoom_max)
    new_scale.y = clamp(new_scale.y, zoom_min, zoom_max)
    if old_scale == new_scale: return
    
    graph_layer.position -= (mouse_pos - graph_layer.position) * (new_scale / old_scale - Vector2.ONE)
    graph_layer.scale = new_scale

func _on_back_button_pressed() -> void:
    subpatch_stacks.pop_back()
    $BackButton.visible = subpatch_stacks.size() > 1
    load_pd_graph(subpatch_stacks[-1][0], subpatch_stacks[-1][1], subpatch_stacks[-1][2], false, false)

func _on_corner_button_pressed() -> void:
    if subpatch_stacks.size():
        load_pd_graph(subpatch_stacks[-1][0], subpatch_stacks[-1][1], subpatch_stacks[-1][2], false, false)
