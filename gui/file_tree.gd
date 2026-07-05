extends Control
class_name PdFileTree

var tree: Tree

func file_array_to_tree(paths: Array[String], kinds: Array[String]) -> Dictionary:
    var root := {}
    for i in paths.size():
        var path = paths[i]
        var kind = kinds[i]
        
        if not path.ends_with(".pd"):
            continue
        if kind in ["Ignored", "Unreadable", "Conflicted"]:
            continue
            
        var parts = path.split("/")
        var current = root
        for j in parts.size():
            var part = parts[j]
            if j == parts.size() - 1:
                current[part] = [kind, path]
            else:
                if !current.has(part):
                    current[part] = {}
                current = current[part]
    return root

func add_items(parent: TreeItem, data: Dictionary):
    var keys = data.keys()
    keys.sort()
    for key in keys:
        if data[key] is Dictionary:
            var item = tree.create_item(parent)
            item.set_text(0, key)
            item.set_text(1, "")
            item.collapsed = true
            add_items(item, data[key])
    for key in keys:
        if data[key] is not Dictionary:
            var item = tree.create_item(parent)
            item.set_text(0, key)
            item.set_metadata(0, data[key][1])
            item.set_text(1, data[key][0] if data[key][0]!="Unmodified" else "")
            if data[key][0] == "Deleted":
                item.set_custom_color(0, StyleConfig.color_del)
            elif data[key][0] in ["Added", "Untracked"]:
                item.set_custom_color(0, StyleConfig.color_add)
            elif data[key][0] == "Modified":
                item.set_custom_color(0, StyleConfig.color_mod)
            elif data[key][0] == "Renamed":
                item.set_custom_color(0, StyleConfig.color_mov)

func load_file_tree(paths, kinds):
    var path_dict = file_array_to_tree(paths, kinds)
    tree.clear()
    var root = tree.create_item()
    add_items(root, path_dict)

func _ready():
    tree = $Tree
    tree.set_column_expand(0, true)
    tree.set_column_expand(1, false)
    tree.set_column_custom_minimum_width(1, 24)
