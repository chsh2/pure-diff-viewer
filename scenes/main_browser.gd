extends Control

const PdParser = preload("res://core/pd/parser.gd")
const GitUtils = preload("res://core/git/GitUtils.cs")

var pdviewer: PdViewer
var tree: PdFileTree
var branch_selector: OptionButton
var commit_selector: OptionButton
var file_history_selector: OptionButton

var repo: String
var head_branch: String
var head_sha: String
var current_branch
var current_commit
var current_path
var parent_commit_sha
var branches
var commits

class Commit extends RefCounted:
    var name: String
    var sha: String
    var message: String
    var author: String
    var date: String
    var ui_text: String

func _ready() -> void:
    pdviewer = $HSplitContainer/PdViewer
    tree = $HSplitContainer/LeftPanel/FileTree
    branch_selector = $HSplitContainer/LeftPanel/CommitSelectPanel/BranchOption
    commit_selector = $HSplitContainer/LeftPanel/CommitSelectPanel/CommitOption
    file_history_selector = $HSplitContainer/LeftPanel/FileHistoryPanel/HistoryOption
    
    head_branch = GitUtils.GetHeadBranch(repo)
    head_sha = GitUtils.GetHeadSha(repo)
    current_branch = head_branch
    branches = GitUtils.GetBranches(repo)
    for i in branches.size():
        branch_selector.add_item(branches[i])
        if branches[i] == head_branch:
            branch_selector.selected = i
    get_commits_from_branch(head_branch)

func _on_branch_option_item_selected(index: int) -> void:
    current_branch = branches[index]
    file_history_selector.clear()
    pdviewer.clear()
    get_commits_from_branch(current_branch)

func get_commits_from_branch(branch):
    commits = []
    commit_selector.clear()
    if branch == head_branch:
        commit_selector.add_item("Current")
    
    var names = GitUtils.GetCommitNames(repo, branch, 0)
    var shas = GitUtils.GetCommitShas(repo, branch, 0)
    var authors = GitUtils.GetCommitAuthors(repo, branch, 0)
    var messages = GitUtils.GetCommitMessages(repo, branch, 0)
    var dates = GitUtils.GetCommitDates(repo, branch, 0)
    for i in names.size():
        var c = Commit.new()
        c.name = names[i]
        c.sha = shas[i]
        c.message = messages[i]
        c.author = authors[i]
        c.date = dates[i]
        c.ui_text = "%s [%s](%s)" % [c.message, c.name, c.date.split(" ")[0]]
        commits.append(c)
        commit_selector.add_item(c.ui_text)
    commit_selector.selected = 0
    _on_commit_option_item_selected(0)

func _on_commit_option_item_selected(index: int) -> void:
    pdviewer.clear()
    if current_branch == head_branch:
        if index == 0:
            current_commit = null
            parent_commit_sha = head_sha
        else:
            current_commit = commits[index-1]
            parent_commit_sha = null if index >= commits.size() else commits[index].sha
    else:
        current_commit = commits[index]
        parent_commit_sha = null if index+1 >= commits.size() else commits[index+1].sha
        
    if current_commit:
        tree.load_file_tree(
            GitUtils.GetCommitFilePaths(repo, current_commit.sha),
            GitUtils.GetCommitFileKinds(repo, current_commit.sha)
        )
    else:
        tree.load_file_tree(
            GitUtils.GetLatestFilesPaths(repo), 
            GitUtils.GetLatestFilesKinds(repo)
        )

func _on_tree_item_selected() -> void:
    var item = tree.get_node("Tree").get_selected()
    var change_kind = item.get_text(1)
    if change_kind == "Deleted":
        return
        
    var path = item.get_metadata(0)
    if path:
        current_path = path
        pdviewer.reset_position()
        load_file_in_canvas(path, change_kind=="Modified")
        set_file_commits_history(path)

func load_file_in_canvas(path, diff_mode=true):
    var file_lines = []
    if current_commit:
        file_lines = GitUtils.GetFileContent(repo, current_commit.sha, path).split("\n")
    else:
        var file = FileAccess.open(repo.path_join(path), FileAccess.READ)
        while file.get_position() < file.get_length():
            var line = file.get_line()
            file_lines.append(line)
    var res = PdParser.text_to_pd_graph(file_lines)
    var new_graph = res[0]
    
    if not res[1]:
        print_debug("ERROR: Cannot load file")
        return
    
    var old_graph = null
    if parent_commit_sha and diff_mode:
        var old_file_lines = GitUtils.GetFileContent(repo, parent_commit_sha, path).split("\n")
        if len(old_file_lines) > 0:
            res = PdParser.text_to_pd_graph(old_file_lines)
            old_graph = res[0]
            
    var uid_map
    if old_graph != null:
        uid_map = DiffAlgo.compare_and_assign_uid(new_graph, old_graph)
    
    pdviewer.load_pd_graph(new_graph, old_graph, uid_map)

var commit_option_map = []
func set_file_commits_history(path):
    file_history_selector.clear()
    commit_option_map = []
    # TODO: The library implementation is slow. Must set a constraint to # of commits
    var commit_shas = GitUtils.GetCommitsForFile(repo, current_branch, path, 0, 500)
    for sha in commit_shas:
        for i in commits.size():
            if commits[i].sha == sha:
                commit_option_map.append([i, commits[i]])
                file_history_selector.add_item(commits[i].ui_text)
                break
    file_history_selector.select(-1)
        
func _on_history_option_item_selected(index: int) -> void:
    current_commit = commit_option_map[index][1]
    var selection = commit_option_map[index][0] + int(current_branch == head_branch)
    commit_selector.select(selection)
    _on_commit_option_item_selected(selection)
    load_file_in_canvas(current_path)
