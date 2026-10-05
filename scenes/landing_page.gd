extends Control

const GitUtils = preload("res://core/git/GitUtils.cs")

const CONFIG_PATH := "user://path_history.cfg"

func _ready() -> void:
    load_state()

    $VersionNumber.text = "Pure Diff Viewer v%s" % ProjectSettings.get_setting("application/config/version")

    var args := OS.get_cmdline_args()
    print("Pure Diff Viewer: Starts with arguments %s" % args)
    if args.size() < 2 or args[0] == "--scene":
        $FileDialog.visible = true
        return

    # Start diff tool
    var local_path = args[0]
    var remote_path = args[1]
    if not local_path.is_absolute_path():
        var cwd = OS.get_environment("PWD")
        local_path = cwd.path_join(local_path)
    if not remote_path.is_absolute_path():
        var cwd = OS.get_environment("PWD")
        remote_path = cwd.path_join(remote_path)

    # Dir mode
    if DirAccess.dir_exists_absolute(local_path) and DirAccess.dir_exists_absolute(remote_path):
        var dir_diff_tool = preload("res://scenes/dir_diff_tool.tscn").instantiate()
        dir_diff_tool.path_old = local_path
        dir_diff_tool.path_new = remote_path
        get_tree().root.add_child.call_deferred(dir_diff_tool)
        queue_free()

    # Single file mode
    elif FileAccess.file_exists(local_path) or FileAccess.file_exists(remote_path):
        if not local_path.ends_with(".pd") and not remote_path.ends_with(".pd"):
            print("Pure Diff Viewer: This program can only view changes of .pd files.")
            get_tree().quit()
        var file_diff_tool = preload("res://scenes/file_diff_tool.tscn").instantiate()
        if FileAccess.file_exists(local_path):
            file_diff_tool.path_old = local_path
        if FileAccess.file_exists(remote_path):
            file_diff_tool.path_new = remote_path
        get_tree().root.add_child.call_deferred(file_diff_tool)
        queue_free()


func _on_file_dialog_dir_selected(dir) -> void:
    var path = dir
    if not GitUtils.IsGitRepository(path):
        $FileDialog.visible = true
        $Label.text = "[color=red]The selected folder is not a Git repository.[/color]"
    else:
        var main_browser = preload("res://scenes/main_browser.tscn").instantiate()
        main_browser.repo = path
        get_tree().root.add_child(main_browser)
        queue_free()

func _on_file_dialog_canceled() -> void:
    get_tree().quit()

func load_state() -> void:
    var config := ConfigFile.new()
    var err := config.load(CONFIG_PATH)
    if err != OK:
        return

    var favorites := config.get_value("FileDialog", "favorites", PackedStringArray()) as PackedStringArray
    if favorites.size() > 0:
        $FileDialog.set_favorite_list(favorites)
    var recent_paths := config.get_value("FileDialog", "recent_paths", PackedStringArray()) as PackedStringArray
    if recent_paths.size() > 0:
        $FileDialog.set_recent_list(recent_paths)
        
func write_state() -> void:
    var config := ConfigFile.new()
    config.set_value("FileDialog", "favorites", $FileDialog.get_favorite_list())
    config.set_value("FileDialog", "recent_paths", $FileDialog.get_recent_list())
    var err := config.save(CONFIG_PATH)
    if err != OK:
        push_error("Failed to save landing page state: %d" % err)

func _exit_tree() -> void:
    write_state()
