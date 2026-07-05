extends RefCounted

const MAIN_CANVAS_IDX = -1

static func parse_coords(segs: Array[String], obj: PdElemClass) -> bool:
    if len(segs) < 8:
        print_debug("ERROR: incorrect syntax for coords")
        return false
    obj.attr_dict["x_from"] = float(segs[1])
    obj.attr_dict["y_to"] = float(segs[2])
    obj.attr_dict["x_to"] = float(segs[3])
    obj.attr_dict["y_from"] = float(segs[4])
    obj.attr_dict["width"] = int(segs[5])
    obj.attr_dict["height"] = int(segs[6])
    obj.canvas_show_graph = int(segs[7])
    return true

static func text_to_pd_graph(text_lines, is_main=true):
    var pd_graph: Dictionary[int, PdElemClass]
    var connections = []
    var _warnings = 0
    var i = 0
    
    while i < len(text_lines):
        var line = text_lines[i]
        line = line.strip_edges()
        
        # Basic syntax check
        if len(line) == 0:
            i += 1
            continue
        if len(line) < 3 or line[0] != "#" or line[1] not in ['A', 'X', 'N']:
            print_debug("ERROR: cannot parse: %s" % line)
            return [{}, false]
        # Aggregate multiple lines
        while i+1 < len(text_lines) and text_lines[i][-1] != ';':
            i += 1
            line += ' '+ text_lines[i].strip_edges()
            
        var elem_text = line.rstrip(";").substr(3).strip_edges()
        var new_elem = PdElemClass.new()
        
        # May have optional width suffix
        var tmp = elem_text.replace("\\,", "")
        if tmp.contains(","):
            var width_segs = tmp.get_slice(",", 1).strip_edges().split(" ")
            if len(width_segs) >= 2 and  width_segs[0] == 'f' and width_segs[-1].is_valid_int():
                new_elem.attr_dict["char_width"] = int(width_segs[-1])
            elem_text = elem_text.substr(0, elem_text.rfind(","))
        new_elem.statement = elem_text
        var segs = elem_text.split(" ")
        
        # Process connections after elements
        # TODO: Bezier data is ignored for now
        if segs[0] == "connect":
            if len(segs) < 5:
                _warnings += 1
                print_debug("invalid connect syntax: %s" % line)
            else:
                connections.append([
                    int(segs[1]), int(segs[2]), int(segs[3]), int(segs[4])
                ])
            i += 1
            continue
        
        # TODO: Objects to ignore for now
        if segs[0] in ["saved", "struct", "scalar", "declare"]:
            i += 1 
            continue
        
        if MAIN_CANVAS_IDX not in pd_graph and segs[0] != "canvas":
            print_debug("ERROR: cannot find the main canvas")
            return [{}, false]
        
        # Canvas: three cases
        if segs[0] == "canvas":
            # Main canvas: must be the first element
            if MAIN_CANVAS_IDX not in pd_graph:
                if len(segs) < 6:
                    print_debug("ERROR: incorrect syntax for main canvas: %s" % line)
                    return [{}, false]
                new_elem.loc = Vector2i(int(segs[1]), int(segs[2]))
                new_elem.type = PdElemClass.ElemType.CANVAS
                new_elem.attr_dict["x_size"] = int(segs[3])
                new_elem.attr_dict["y_size"] = int(segs[4])
                if is_main:
                    new_elem.attr_dict["font_size"] = int(segs[5])
                    new_elem.canvas_is_main = true
                else:
                    new_elem.canvas_name = segs[5]
                    new_elem.canvas_is_main = false
                    # Calculate code hash to identify subpatch changes quickly
                    new_elem.canvas_code_hash = "".join(text_lines).hash()
                pd_graph[MAIN_CANVAS_IDX] = new_elem
                i += 1
                continue
                
            # Array defined in GUI: regard it as a single element by looking ahead
            if i+1 < len(text_lines) and text_lines[i+1].substr(3).strip_edges().begins_with("array"):
                i += 1
                elem_text = text_lines[i].rstrip(";").substr(3).strip_edges()
                segs = elem_text.split(" ")
                if len(segs) < 4:
                    print_debug("ERROR: incorrect syntax for array: %s" % text_lines[i])
                    return [{}, false]
                new_elem.type = PdElemClass.ElemType.ARRAY
                new_elem.array_name = segs[1]
                new_elem.array_size = int(segs[2])
                new_elem.statement = elem_text
                
                # Get other attributes from "coords" and "#A" statements
                while i+1 < len(text_lines) and not text_lines[i+1].substr(3).strip_edges().begins_with("restore"):
                    i += 1
                    if text_lines[i].begins_with("#A"):
                        elem_text = text_lines[i].rstrip(";").substr(3).strip_edges()
                        segs = elem_text.split(" ")
                        if segs[1].is_valid_float():
                            new_elem.array_data_text = elem_text
                            for seg in segs.slice(1):
                                new_elem.array_data.append(float(seg))
                    else:
                        segs = text_lines[i].rstrip(";").substr(3).strip_edges().split(" ")
                        if segs[0] == "coords":
                            if not parse_coords(segs, new_elem):
                                return [{}, false]
                # Process the last statement
                i += 1
                if i >= len(text_lines):
                    print_debug("ERROR: incorrect syntax for array")
                    return [{}, false]
                segs = text_lines[i].rstrip(";").substr(3).strip_edges().split(" ")
                if len(segs) < 3:
                    print_debug("ERROR: incorrect syntax for array")
                    return [{}, false]
                new_elem.loc = Vector2i(int(segs[1]), int(segs[2]))
                new_elem.index = len(pd_graph)-1
                pd_graph[new_elem.index] = new_elem
                
                i += 1
                continue
                
            # Subpatch canvas: extract lines and parse them recursively
            var j = i + 1
            var stack_depth = 1
            while j < len(text_lines) and stack_depth > 0:
                if text_lines[j].substr(3).strip_edges().begins_with("restore"):
                    stack_depth -= 1
                if text_lines[j].substr(3).strip_edges().begins_with("canvas"):
                    stack_depth += 1
                j += 1
            if stack_depth > 0:
                print_debug("ERROR: incorrect syntax for subpatch")
                return [{}, false]
            var res = text_to_pd_graph(text_lines.slice(i, j), false)
            if res[1] == false:
                print_debug("ERROR: incorrect syntax for subpatch")
                return [{}, false]
            new_elem = res[0][MAIN_CANVAS_IDX]
            new_elem.index = len(pd_graph)-1
            pd_graph[new_elem.index] = new_elem
            new_elem.canvas_subpatch = res[0]
            i = j
            continue
                       
        if segs[0] == "restore":
            if len(segs) < 3:
                print_debug("ERROR: incorrect syntax for restore: %s" % line)
                return [{}, false]
            pd_graph[MAIN_CANVAS_IDX].loc = Vector2i(int(segs[1]), int(segs[2]))
            if len(segs) >= 4:
                pd_graph[MAIN_CANVAS_IDX].canvas_name_params = " ".join(segs.slice(3))
            i += 1
            continue
            
        if segs[0] == "coords":
            if not parse_coords(segs, pd_graph[MAIN_CANVAS_IDX]):
                return [{}, false]
            i += 1
            continue
            
        if segs[0] == "f":
            if len(segs) < 2:
                print_debug("ERROR: incorrect syntax for char width: %s" % line)
                return [{}, false]
            pd_graph[len(pd_graph)-2].attr_dict["char_width"] = int(segs[1])
            i += 1
            continue
            
        if segs[0] == "msg":
            if len(segs) < 3:
                print_debug("ERROR: incorrect syntax for msg: %s" % line)
                return [{}, false]
            new_elem.type = PdElemClass.ElemType.MESSAGE
            new_elem.loc = Vector2i(int(segs[1]), int(segs[2]))
            new_elem.msg_text = " ".join(segs.slice(3))
            new_elem.index = len(pd_graph)-1
            pd_graph[new_elem.index] = new_elem
            i += 1
            continue
            
        if segs[0] == "text":
            if len(segs) < 3:
                print_debug("ERROR: incorrect syntax for text: %s" % line)
                return [{}, false]
            new_elem.type = PdElemClass.ElemType.COMMENT
            new_elem.loc = Vector2i(int(segs[1]), int(segs[2]))
            new_elem.comment_text = " ".join(segs.slice(3))
            new_elem.index = len(pd_graph)-1
            pd_graph[new_elem.index] = new_elem
            i += 1
            continue
            
        if segs[0] in ["floatatom", "symbolatom", "listbox"]:
            if len(segs) < 10:
                print_debug("ERROR: incorrect syntax for float/symbol: %s" % line)
                return [{}, false]
            new_elem.type = PdElemClass.ElemType.NUMBER if segs[0] == "floatatom" \
                    else PdElemClass.ElemType.SYMBOL if segs[0] == "symbolatom" \
                    else PdElemClass.ElemType.LIST
            new_elem.loc = Vector2i(int(segs[1]), int(segs[2]))
            new_elem.attr_dict["char_width"] = int(segs[3])
            new_elem.attr_dict["lower_limit"] = int(segs[4])
            new_elem.attr_dict["upper_limit"] = int(segs[5])
            new_elem.attr_dict["label_pos"] = int(segs[6])  # 0 - left, 1 - right, 2 - up, 3 - down
            new_elem.attr_dict["label"] = segs[7]
            new_elem.attr_dict["receive"] = segs[8]
            new_elem.attr_dict["send"] = segs[9]
            if len(segs) > 10:
                new_elem.attr_dict["height"] = int(segs[10])
            new_elem.index = len(pd_graph)-1
            pd_graph[new_elem.index] = new_elem
            i += 1
            continue
            
        if segs[0] == "obj":
            if len(segs) < 3:
                print_debug("ERROR: incorrect syntax for obj: %s" % line)
                return [{}, false]
            new_elem.type = PdElemClass.ElemType.OBJECT
            new_elem.loc = Vector2i(int(segs[1]), int(segs[2]))
            new_elem.obj_name = "" if len(segs)<4 else segs[3]
            new_elem.obj_params = segs.slice(4)
            new_elem.parse_special_obj()
            new_elem.index = len(pd_graph)-1
            pd_graph[new_elem.index] = new_elem
            i += 1
            continue
           
        print_debug("unrecognized line: %s" % line) 
        _warnings += 1
        i += 1
        
    for conn in connections:
        var src = conn[0]
        var outlet = conn[1]
        var dst = conn[2]
        var inlet = conn[3]
        if src not in pd_graph or dst not in pd_graph:
            _warnings += 1
            print_debug("invalid connection found")
            continue
            
        while len(pd_graph[src].outlets) <= outlet:
            pd_graph[src].outlets.append([])
        pd_graph[src].outlets[outlet].append([dst, inlet])
        
        while len(pd_graph[dst].inlets) <= inlet:
            pd_graph[dst].inlets.append([])
        pd_graph[dst].inlets[inlet].append([src, outlet])
        
    return [pd_graph, true]
    
    

            
        
