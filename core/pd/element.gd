extends RefCounted
class_name PdElemClass

enum ElemType {ARRAY, CANVAS, NUMBER, OBJECT, MESSAGE, SYMBOL, LIST, COMMENT}
static var special_obj_names = ["bng", "tgl", "nbx", "vsl", "hsl", "hradio", "vradio", "vu", "cnv"]

var index: int
var type: ElemType
var loc: Vector2i
var statement: String
var attr_dict = {}
var inlets = []
var outlets = []

var obj_name: String
var obj_name_special: String
var obj_params: PackedStringArray

var array_name: String
var array_size: int
var array_data_text: String
var array_data: Array[float]

var msg_text: String

var comment_text: String

var canvas_is_main = false
var canvas_show_graph = false
var canvas_name: String
var canvas_name_params: String
var canvas_subpatch: Dictionary[int, PdElemClass]
var canvas_code_hash: int

# For diff calculation
var uid: int
var text_feature: String
var diff_loc: bool
var diff_statement = null
var diff_attrs = {}
var counterpart = null

var debug_meta=0

func get_diff(old: PdElemClass):
    assert(type == old.type)
    assert(obj_name_special == old.obj_name_special)

    # Common for all types
    counterpart = old
    diff_loc = (loc != old.loc)
    for k in attr_dict:
        if k not in old.attr_dict:
            diff_attrs[k] = ["", attr_dict[k]]
        elif attr_dict[k] != old.attr_dict[k]:
            diff_attrs[k] = [old.attr_dict[k], attr_dict[k]]
    for k in old.attr_dict:
        if k not in attr_dict:
            diff_attrs[k] = [old.attr_dict[k], ""]
    
    # Type-specific attributes
    var add_attr_diff = func(attr, hint=null, show_value=true):
        if hint == null:
            hint = attr
        if get(attr) != old.get(attr):
            diff_attrs[hint] = [old.get(attr), get(attr)] if show_value else []

    var set_statement_diff = func(s1, s2):
        if s1 != s2:
            diff_statement = [s1, s2]

    if type == ElemType.ARRAY:
        add_attr_diff.call("array_name")
        add_attr_diff.call("array_size")
        add_attr_diff.call("array_data_text", "Array data changed.", false)
    elif type == ElemType.COMMENT:
        set_statement_diff.call(old.comment_text, comment_text)
    elif type == ElemType.MESSAGE:
        set_statement_diff.call(old.msg_text, msg_text)
    elif type == ElemType.OBJECT:
        if obj_name_special == "":
            var old_name = old.obj_name+ ' '+' '.join(old.obj_params)
            var new_name = obj_name+ ' '+' '.join(obj_params)
            set_statement_diff.call(old_name, new_name)
    elif type == ElemType.CANVAS:
        set_statement_diff.call(old.canvas_name_params, canvas_name_params)
        add_attr_diff.call("canvas_code_hash", "Subpatch changed. Click to view.", false)
    

func parse_special_obj():
    if obj_name not in special_obj_names:
        return
    obj_name_special = obj_name
    if obj_name == "bng":
        if len(obj_params) < 14:
            print_debug("Invalid parameters for bng: %s" % statement)
            return
        attr_dict["size"] = int(obj_params[0])
        attr_dict["hold"] = int(obj_params[1])
        attr_dict["interrupt"] = int(obj_params[2])
        attr_dict["init"] = int(obj_params[3])
        attr_dict["send"] = obj_params[4]
        attr_dict["receive"] = obj_params[5]
        attr_dict["label"] = obj_params[6]
        attr_dict["x_off"] = int(obj_params[7])
        attr_dict["y_off"] = int(obj_params[8])
        attr_dict["font"] = obj_params[9]
        attr_dict["fontsize"] = int(obj_params[10])
        attr_dict["bg_color"] = obj_params[11]
        attr_dict["fg_color"] = obj_params[12]
        attr_dict["label_color"] = obj_params[13]
    elif obj_name == "tgl":
        if len(obj_params) < 14:
            print_debug("Invalid parameters for tgl: %s" % statement)
            return
        attr_dict["size"] = int(obj_params[0])
        attr_dict["init"] = int(obj_params[1])
        attr_dict["send"] = obj_params[2]
        attr_dict["receive"] = obj_params[3]
        attr_dict["label"] = obj_params[4]
        attr_dict["x_off"] = int(obj_params[5])
        attr_dict["y_off"] = int(obj_params[6])
        attr_dict["font"] = obj_params[7]
        attr_dict["fontsize"] = int(obj_params[8])
        attr_dict["bg_color"] = obj_params[9]
        attr_dict["fg_color"] = obj_params[10]
        attr_dict["label_color"] = obj_params[11]
        attr_dict["init_value"] = int(obj_params[12])
        attr_dict["default_value"] = int(obj_params[13])
    elif obj_name == "nbx":
        if len(obj_params) < 17:
            print_debug("Invalid parameters for nbx: %s" % statement)
            return
        attr_dict["size"] = int(obj_params[0])
        attr_dict["height"] = int(obj_params[1])
        attr_dict["min"] = obj_params[2]
        attr_dict["max"] = obj_params[3]
        attr_dict["log"] = int(obj_params[4])
        attr_dict["init"] = int(obj_params[5])
        attr_dict["send"] = obj_params[6]
        attr_dict["receive"] = obj_params[7]
        attr_dict["label"] = obj_params[8]
        attr_dict["x_off"] = int(obj_params[9])
        attr_dict["y_off"] = int(obj_params[10])
        attr_dict["font"] = obj_params[11]
        attr_dict["fontsize"] = int(obj_params[12])
        attr_dict["bg_color"] = obj_params[13]
        attr_dict["fg_color"] = obj_params[14]
        attr_dict["label_color"] = obj_params[15]
        attr_dict["log_height"] = int(obj_params[16])
    elif obj_name == "vsl" or obj_name == "hsl":
        if len(obj_params) < 18:
            print_debug("Invalid parameters for slider: %s" % statement)
            return
        attr_dict["width"] = int(obj_params[0])
        attr_dict["height"] = int(obj_params[1])
        attr_dict["bottom"] = int(obj_params[2])
        attr_dict["top"] = int(obj_params[3])
        attr_dict["log"] = int(obj_params[4])
        attr_dict["init"] = int(obj_params[5])
        attr_dict["send"] = obj_params[6]
        attr_dict["receive"] = obj_params[7]
        attr_dict["label"] = obj_params[8]
        attr_dict["x_off"] = int(obj_params[9])
        attr_dict["y_off"] = int(obj_params[10])
        attr_dict["font"] = obj_params[11]
        attr_dict["fontsize"] = int(obj_params[12])
        attr_dict["bg_color"] = obj_params[13]
        attr_dict["fg_color"] = obj_params[14]
        attr_dict["label_color"] = obj_params[15]
        attr_dict["default_value"] = int(obj_params[16])
        attr_dict["steady_on_click"] = int(obj_params[17])
    elif obj_name == "vradio" or obj_name == "hradio":
        if len(obj_params) < 15:
            print_debug("Invalid parameters for radio: %s" % statement)
            return
        attr_dict["size"] = int(obj_params[0])
        attr_dict["new_old"] = int(obj_params[1])
        attr_dict["init"] = int(obj_params[2])
        attr_dict["number"] = int(obj_params[3])
        attr_dict["send"] = obj_params[4]
        attr_dict["receive"] = obj_params[5]
        attr_dict["label"] = obj_params[6]
        attr_dict["x_off"] = int(obj_params[7])
        attr_dict["y_off"] = int(obj_params[8])
        attr_dict["font"] = obj_params[9]
        attr_dict["fontsize"] = int(obj_params[10])
        attr_dict["bg_color"] = obj_params[11]
        attr_dict["fg_color"] = obj_params[12]
        attr_dict["label_color"] = obj_params[13]
        attr_dict["default_value"] = int(obj_params[14])
    elif obj_name == "vu":
        if len(obj_params) < 11:
            print_debug("Invalid parameters for vu: %s" % statement)
            return
        attr_dict["width"] = int(obj_params[0])
        attr_dict["height"] = int(obj_params[1])
        attr_dict["receive"] = obj_params[2]
        attr_dict["label"] = obj_params[3]
        attr_dict["x_off"] = int(obj_params[4])
        attr_dict["y_off"] = int(obj_params[5])
        attr_dict["font"] = obj_params[6]
        attr_dict["fontsize"] = int(obj_params[7])
        attr_dict["bg_color"] = obj_params[8]
        attr_dict["label_color"] = obj_params[9]
        attr_dict["scale"] = int(obj_params[10])
    elif obj_name == "cnv":
        if len(obj_params) < 12:
            print_debug("Invalid parameters for cnv: %s" % statement)
            return
        attr_dict["size"] = int(obj_params[0])
        attr_dict["width"] = int(obj_params[1])
        attr_dict["height"] = int(obj_params[2])
        attr_dict["send"] = obj_params[3]
        attr_dict["receive"] = obj_params[4]
        attr_dict["label"] = obj_params[5]
        attr_dict["x_off"] = int(obj_params[6])
        attr_dict["y_off"] = int(obj_params[7])
        attr_dict["font"] = obj_params[8]
        attr_dict["fontsize"] = int(obj_params[9])
        attr_dict["bg_color"] = obj_params[10]
        attr_dict["label_color"] = obj_params[11]

func _to_string() -> String:
    return "[%s], %s" % [statement, attr_dict]
