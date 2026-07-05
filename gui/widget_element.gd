extends Control
class_name WidgetElement

var char_width_unit: float
var num_socket = 1
var elem_info: PdElemClass

func _ready() -> void:
    
    var sb = $Fill.get_theme_stylebox("panel").duplicate()
    sb.bg_color = Color(StyleConfig.color_fill)
    $Fill.add_theme_stylebox_override("panel", sb)
    
    sb = $Border.get_theme_stylebox("panel").duplicate()
    sb.bg_color = Color(StyleConfig.color_major)
    $Border.add_theme_stylebox_override("panel", sb)
    
    $Label.add_theme_color_override("default_color", Color(StyleConfig.color_major))
    
    $BoxCornerUp.color = Color(StyleConfig.color_major)
    $BoxCornerDown.color = Color(StyleConfig.color_major)
    $ScaleLine.default_color = Color(StyleConfig.color_secondary)

    $Fill.position = Vector2()
    $Label.position = Vector2(StyleConfig.text_margin_w, StyleConfig.text_margin_h)
    $Border.position = Vector2()
    $Icon.position = Vector2()
    $Button.position = Vector2()
    
    char_width_unit = $Label.get_theme_default_font_size() * 0.55

func apply_element_style(elem: PdElemClass):
    num_socket = max(len(elem.inlets), len(elem.outlets))
    elem_info = elem
    var is_special_shape = false
    
    # TODO: Consider whether to render the colors according to the element attributes
    if elem.type == PdElemClass.ElemType.OBJECT:
        if elem.obj_name in PdElemClass.special_obj_names:
            is_special_shape = true
            if elem.obj_name in ['bng', 'tgl']:
                $Fill.size = Vector2(elem.attr_dict["size"], elem.attr_dict["size"])
                $Icon.visible = true
                $Icon.texture = load("res://res/icon_%s.svg" % elem.obj_name)
                $Icon.size = $Fill.size
                
            elif elem.obj_name == 'nbx':
                $Fill.size = Vector2(
                    elem.attr_dict["size"] * char_width_unit + 2 * StyleConfig.text_margin_w,
                    elem.attr_dict["height"]
                )
                $Icon.visible = true
                $Icon.texture = load("res://res/icon_nbx.svg")
                $Icon.size = Vector2(elem.attr_dict["height"], elem.attr_dict["height"])
                
            elif elem.obj_name in ['vsl', 'hsl', 'vu']:
                $Fill.size = Vector2(elem.attr_dict["width"], elem.attr_dict["height"])
                $ScaleLine.visible = true
                var slider_factor = 0.05
                $ScaleLine.points = [
                    Vector2(slider_factor * $Fill.size[0], 0),
                    Vector2(slider_factor * $Fill.size[0], $Fill.size[1])
                ] if elem.obj_name == 'hsl' else [
                    Vector2(0, (1-slider_factor) * $Fill.size[1]),
                    Vector2($Fill.size[0], (1-slider_factor) * $Fill.size[1])
                ]
                if elem.obj_name == 'vu':
                    $Fill.get_theme_stylebox("panel").bg_color = Color(StyleConfig.color_secondary)
                
            elif elem.obj_name in ['vradio', 'hradio']:
                var elem_size = elem.attr_dict["size"]
                var elem_num = elem.attr_dict["number"]
                var is_vertical = (elem.obj_name == 'vradio')
                $Fill.size = Vector2(
                    elem_size * (elem_num if not is_vertical else 1),
                    elem_size * (elem_num if is_vertical else 1)
                )
                var scale_points = [Vector2(1, elem_size) if is_vertical else Vector2(elem_size, 1)]
                for i in range(elem_num - 1):
                    var next_point = scale_points[-1] + (Vector2(elem_size-2, 0) if is_vertical else Vector2(0, elem_size-2))
                    scale_points.append(next_point)
                    scale_points.append(scale_points[-2])
                    next_point = scale_points[-1] + (Vector2(elem_size, 0) if not is_vertical else Vector2(0, elem_size))
                    scale_points.append(next_point)
                $ScaleLine.visible = true
                $ScaleLine.points = scale_points
                $ScaleLine.width = 1
                
            elif elem.obj_name == 'cnv':
                $Fill.size = Vector2(elem.attr_dict["width"], elem.attr_dict["height"])
                $Fill.get_theme_stylebox("panel").bg_color = Color(StyleConfig.color_fill)
                $Border.visible = false
                
            # Label placement for object with special shapes
            $Label.visible = false
            $SideLabel.visible = (elem.attr_dict["label"] != "empty")
            $SideLabel.text = elem.attr_dict["label"]
            $SideLabel.position = Vector2(elem.attr_dict["x_off"] - StyleConfig.text_margin_w, elem.attr_dict["y_off"] - StyleConfig.text_margin_h)
            $SideLabel.add_theme_font_size_override("normal_font_size", elem.attr_dict["fontsize"])
        else:
            $Label.text = elem.obj_name
            if len(elem.obj_params) > 0:
                $Label.text += ' ' + ' '.join(elem.obj_params)
    
    if elem.type == PdElemClass.ElemType.COMMENT:
        $Fill.get_theme_stylebox("panel").bg_color = Color(StyleConfig.color_fill_secondary)
        $Label.add_theme_color_override("default_color", Color(StyleConfig.color_secondary))
        $Border.visible = false
        $Label.text = elem.comment_text
    
    if elem.type == PdElemClass.ElemType.MESSAGE:
        $Fill.get_theme_stylebox("panel").bg_color = Color(StyleConfig.color_canvas)
        $Label.text = elem.msg_text
        $BoxCornerUp.visible = true
        $BoxCornerUp.scale[0] = -0.5
        $BoxCornerDown.visible = true
        $BoxCornerDown.scale[0] = -0.5
    
    if elem.type in [PdElemClass.ElemType.NUMBER, PdElemClass.ElemType.SYMBOL, PdElemClass.ElemType.LIST]:
        $Fill.get_theme_stylebox("panel").bg_color = Color(StyleConfig.color_canvas)
        $BoxCornerUp.visible = true
        $BoxCornerDown.visible = (elem.type == PdElemClass.ElemType.LIST)
        $Label.text = ""
        if "height" in elem.attr_dict and elem.attr_dict["height"] > 0:
            char_width_unit = 0.55 * elem.attr_dict["height"]
    
    if elem.type == PdElemClass.ElemType.CANVAS:
        $Label.text = elem.canvas_name_params
        if elem.canvas_show_graph and "width" in elem.attr_dict and "height" in elem.attr_dict:
            is_special_shape = true
            $Fill.size = Vector2(elem.attr_dict["width"], elem.attr_dict["height"])
            
    if elem.type == PdElemClass.ElemType.ARRAY:
        $Label.text = elem.array_name
        is_special_shape = true
        $Fill.size = Vector2(elem.attr_dict["width"], elem.attr_dict["height"])
        
        # TODO: plot the real data instead of a flat line
        $ScaleLine.visible = true
        $ScaleLine.points = [Vector2(0, elem.attr_dict["height"] / 2), Vector2(elem.attr_dict["width"], elem.attr_dict["height"] / 2)]
            
    if not is_special_shape:
        var base_height = max(1.5 * char_width_unit, $Label.get_content_height())
        $Fill.size[1] = base_height + 2 * StyleConfig.text_margin_h
        
        var base_width = max(3 * char_width_unit, $Label.get_content_width())
        if "char_width" in elem.attr_dict and elem.attr_dict["char_width"] > 0:
            base_width = elem.attr_dict["char_width"] * char_width_unit
        $Fill.size[0] = base_width + 2 * StyleConfig.text_margin_w
    
    $BoxCornerUp.position = Vector2($Fill.size[0], 0)
    $BoxCornerDown.position = Vector2($Fill.size[0], $Fill.size[1])
    
    $Label.text = $Label.text.replace("\\", "")
    
    # Label placement for non-object elements
    if "label" in elem.attr_dict and elem.attr_dict["label"] != "-" and not is_special_shape:
        $SideLabel.visible = true
        $SideLabel.text = elem.attr_dict["label"]
        if "height" in elem.attr_dict and elem.attr_dict["height"] > 0:
            $SideLabel.add_theme_font_size_override("normal_font_size", elem.attr_dict["height"])
        var placement = elem.attr_dict.get("label_pos", 0)
        if placement == 0:
            $SideLabel.position = Vector2(- $SideLabel.get_content_width() - StyleConfig.text_margin_w, $Fill.size[1] / 2 - $SideLabel.get_content_height() / 2)
        elif placement == 1:
            $SideLabel.position = Vector2($Fill.size[0] + StyleConfig.text_margin_w, $Fill.size[1] / 2 - $SideLabel.get_content_height() / 2)
        elif placement == 2:
            $SideLabel.position = Vector2(0, - StyleConfig.text_margin_h - $SideLabel.get_content_height())
        else:
            $SideLabel.position = Vector2(0, StyleConfig.text_margin_h + $Fill.size[1])
    
    $Border.size = $Fill.size
    $Button.size = $Fill.size
    size = $Fill.size

func apply_diff_style(del, add, mod, prop_mod, mov):
    if del:
        $Fill.modulate = Color(StyleConfig.color_del)
        $Fill.modulate.a = 0.8
        for node in get_children():
            node.modulate.a = 0.25
    elif add:
        $Fill.modulate = Color(StyleConfig.color_add)
        $Fill.modulate.a = 0.8
    elif mod:
        $Fill.modulate = Color(StyleConfig.color_mod)
    elif prop_mod:
        $Fill.modulate = Color(StyleConfig.color_mod_secondary)
    elif mov:
        $Fill.modulate = Color(StyleConfig.color_mov)

func get_inlet_pos(index):
    var w = ($Fill.size[0] - 2 * StyleConfig.text_margin_w) / max(num_socket - 1, 1)
    return Vector2(w * index + StyleConfig.text_margin_w, 0)

func get_outlet_pos(index):
    var w = ($Fill.size[0] - 2 * StyleConfig.text_margin_w) / max(num_socket - 1, 1)
    return Vector2(w * index + StyleConfig.text_margin_w, $Fill.size[1])


func _on_button_pressed() -> void:
    if elem_info.type == PdElemClass.ElemType.CANVAS:
        get_parent().get_parent().load_subpatch(elem_info)

func _on_mouse_entered() -> void:
    # Movement trace
    if elem_info.diff_loc:
        var trace_shape = get_parent().get_node("TraceShadow")
        trace_shape.visible = true
        var loc1 = elem_info.loc
        var loc2 = elem_info.counterpart.loc
        if abs(loc1.x - loc2.x) < abs(loc1.y - loc2.y):
            if loc1.y < loc2.y:
                trace_shape.polygon = [
                    Vector2(loc1.x, loc1.y + $Fill.size.y),
                    Vector2(loc1.x + $Fill.size.x, loc1.y + $Fill.size.y),
                    Vector2(loc2.x + $Fill.size.x, loc2.y + $Fill.size.y),
                    Vector2(loc2.x, loc2.y + $Fill.size.y)
                ]
            else:
                trace_shape.polygon = [
                    Vector2(loc1.x, loc1.y),
                    Vector2(loc1.x + $Fill.size.x, loc1.y),
                    Vector2(loc2.x + $Fill.size.x, loc2.y),
                    Vector2(loc2.x, loc2.y)
                ]
        else:
            if loc1.x < loc2.x:
                trace_shape.polygon = [
                    Vector2(loc1.x + $Fill.size.x, loc1.y),
                    Vector2(loc1.x + $Fill.size.x, loc1.y + $Fill.size.y),
                    Vector2(loc2.x + $Fill.size.x, loc2.y + $Fill.size.y),
                    Vector2(loc2.x + $Fill.size.x, loc2.y)
                ]
            else:
                trace_shape.polygon = [
                    Vector2(loc1.x, loc1.y),
                    Vector2(loc1.x, loc1.y + $Fill.size.y),
                    Vector2(loc2.x, loc2.y + $Fill.size.y),
                    Vector2(loc2.x, loc2.y)
                ]
    # Popup information panel
    if elem_info.diff_attrs.size() or elem_info.diff_statement:
        var popup = get_parent().get_parent().get_node("PopupPanel")
        var label = popup.get_node("RichTextLabel")
        popup.visible = true
        popup.global_position = get_viewport().get_mouse_position()
        
        label.text = ""
        if elem_info.diff_statement:
            label.text += "[b]Text: [/b][color=%s][s][lb]%s[rb][/s][/color] [color=%s][lb]%s[rb][/color]" \
                        % [StyleConfig.color_del, elem_info.diff_statement[0],
                        StyleConfig.color_add, elem_info.diff_statement[1]]
        if elem_info.diff_attrs.size():
            if elem_info.diff_statement:
                label.text += '\n'
            label.text += "[b]Properties: [/b]"
            for hint in elem_info.diff_attrs:
                label.text += "\n[ul]"
                label.text += "[b]%s[/b] " % hint
                if elem_info.diff_attrs[hint].size() == 2:
                    label.text += "[color=%s][s]%s[/s][/color] " % [StyleConfig.color_del, elem_info.diff_attrs[hint][0]]
                    label.text += "[color=%s]%s[/color] " % [StyleConfig.color_add, elem_info.diff_attrs[hint][1]]
                label.text += "[/ul]"
        popup.size = Vector2(0,0)
            
func _on_mouse_exited() -> void:
    get_parent().get_parent().get_node("PopupPanel").visible = false
    get_parent().get_node("TraceShadow").visible = false
