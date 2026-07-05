extends Control

const PdParser = preload("res://core/pd/parser.gd")
var path_new
var path_old
var files_dict_old = {}
var files_dict_new = {}
    
func get_relative_path(base_dir: String, target_path: String) -> String:
    base_dir = base_dir.simplify_path().trim_suffix("/")
    target_path = target_path.simplify_path()

    var base_parts = base_dir.split("/")
    var target_parts = target_path.split("/")

    var common_length = 0
    var min_length = mini(base_parts.size(), target_parts.size())
    for i in range(min_length):
        if base_parts[i] == target_parts[i]:
            common_length += 1
        else:
            break

    var rel_parts = PackedStringArray()
    for i in range(common_length, base_parts.size()):   
        if base_parts[i] != "": 
            rel_parts.append("..")
    for i in range(common_length, target_parts.size()):
        if target_parts[i] != "":
            rel_parts.append(target_parts[i])

    var result = "/".join(rel_parts)
    return result if result != "" else "."

func scan_pd_files(path: String, files: Array):
    var dir := DirAccess.open(path)
    if dir == null:
        return

    dir.list_dir_begin()
    while true:
        var file_name = dir.get_next()
        if file_name == "":
            break
        if file_name == "." or file_name == "..":
            continue

        var full_path = path.path_join(file_name)
        if dir.current_is_dir():
            scan_pd_files(full_path, files)
        elif full_path.ends_with(".pd"):
            files.append(full_path)
    dir.list_dir_end()

func _ready() -> void:
    var files_old = []
    var files_new = []
    scan_pd_files(path_old, files_old)
    scan_pd_files(path_new, files_new)
    for full_path in files_old:
        files_dict_old[get_relative_path(path_old, full_path)] = full_path
    for full_path in files_new:
        files_dict_new[get_relative_path(path_new, full_path)] = full_path
    
    var paths: Array[String] = []
    var kinds: Array[String] = []
    for key in files_dict_old:
        if key not in files_dict_new:
            paths.append(key)
            kinds.append("Added")
        else:
            paths.append(key)
            kinds.append("Modified")
    for key in files_dict_new:
        if key not in files_dict_old:
            paths.append(key)
            kinds.append("Deleted")
    $HSplitContainer/LeftPanel/FileTree.load_file_tree(paths, kinds)


func _on_tree_item_selected() -> void:
    var item = $HSplitContainer/LeftPanel/FileTree/Tree.get_selected()
    var change_kind = item.get_text(1)
    if change_kind == "Deleted":
        return
    var path = item.get_metadata(0)
    if path:
        var full_path_old = path_old.path_join(path)
        var full_path_new = path_new.path_join(path) 
        var file_lines = []
        var file
        var res
        var new_graph = {}
        var old_graph = null
        var uid_map = null
        
        file = FileAccess.open(full_path_new, FileAccess.READ)
        while file.get_position() < file.get_length():
            var line = file.get_line()
            file_lines.append(line)
        res = PdParser.text_to_pd_graph(file_lines)
        if not res[1]:
            print_debug("ERROR: Cannot load file")
            return
        new_graph = res[0]
        
        if path in files_dict_old:
            file_lines = []
            file = FileAccess.open(full_path_old, FileAccess.READ)
            while file.get_position() < file.get_length():
                var line = file.get_line()
                file_lines.append(line)
            res = PdParser.text_to_pd_graph(file_lines)
            if not res[1]:
                print_debug("ERROR: Cannot load file")
                return
            old_graph = res[0]
            uid_map = DiffAlgo.compare_and_assign_uid(new_graph, old_graph)
    
        $HSplitContainer/PdViewer.load_pd_graph(new_graph, old_graph, uid_map)
