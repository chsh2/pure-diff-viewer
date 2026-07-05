extends Control

const PdParser = preload("res://core/pd/parser.gd")
var path_new = null
var path_old = null

func _ready():
    var file_lines = []
    var file
    var res
    var new_graph = {}
    var old_graph = {}
    
    if path_new:
        file = FileAccess.open(path_new, FileAccess.READ)
        while file.get_position() < file.get_length():
            var line = file.get_line()
            file_lines.append(line)
        res = PdParser.text_to_pd_graph(file_lines)
        if not res[1]:
            print_debug("ERROR: Cannot load file")
            return
        new_graph = res[0]
    
    if path_old:
        file_lines = []
        file = FileAccess.open(path_old, FileAccess.READ)
        while file.get_position() < file.get_length():
            var line = file.get_line()
            file_lines.append(line)
        res = PdParser.text_to_pd_graph(file_lines)
        if not res[1]:
            print_debug("ERROR: Cannot load file")
            return
        old_graph = res[0]
        
    var uid_map
    if old_graph != null:
        uid_map = DiffAlgo.compare_and_assign_uid(new_graph, old_graph)
    
    $PdViewer.load_pd_graph(new_graph, old_graph, uid_map)
