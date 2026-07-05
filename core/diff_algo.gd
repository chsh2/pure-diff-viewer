extends RefCounted
class_name DiffAlgo

const dist_threshold = 15
const similarity_threshold = 1.5

const HungarianOptimizer = preload("res://core/HungarianOptimizer.cs")

static func array_similarity(a1, a2):
    return 1.0 - array_edit_distance(a1, a2) / max(a1.size(), a2.size())

static func array_edit_distance(a1: Array, a2: Array) -> int:
    var n := a1.size()
    var m := a2.size()

    # dp[i][j]: distance from a1[:i] to a2[:j]
    var dp: Array = []
    dp.resize(n + 1)
    for i in range(n + 1):
        dp[i] = []
        dp[i].resize(m + 1)

    for i in range(n + 1):
        dp[i][0] = i
    for j in range(m + 1):
        dp[0][j] = j

    for i in range(1, n + 1):
        for j in range(1, m + 1):
            if a1[i - 1] == a2[j - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            else:
                dp[i][j] = min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + 1)
    return dp[n][m]
    
static func socket_similarity(s1, s2, graph1, graph2, use_uid=false):
    var n = max(s1.size(), s2.size())
    if n == 0:
        return 1.0
    var score = .0
    var bonus = .0
    for i in n:
        if i>=s1.size() or i>=s2.size():
            continue
        var count_diff = {}
        for j in s1[i].size():
            var feature = [graph1[s1[i][j][0]].text_feature, s1[i][j][1]]
            if use_uid:
                feature.append(graph1[s1[i][j][0]].uid)
            count_diff[feature] = count_diff.get(feature, 0) + 1 
        for j in s2[i].size():
            var feature = [graph2[s2[i][j][0]].text_feature, s2[i][j][1]]
            if use_uid:
                feature.append(graph2[s2[i][j][0]].uid)
            count_diff[feature] = count_diff.get(feature, 0) - 1
        var diff = 0
        for feature in count_diff:
            diff += abs(count_diff[feature])
            if use_uid and count_diff[feature] == 0 and feature[2]:
                bonus = 1
        score += 1 - diff / max(s1[i].size(), s2[i].size(), 1)
    return score / n + bonus

static func compare_and_assign_uid(graph: Dictionary[int, PdElemClass], old_graph: Dictionary[int, PdElemClass]):
    var node_by_text = {}
    var node_by_text_old = {}
    
    # Extract text other than coordinates as the feature of a node
    for key in graph:
        if key >= 0:
            var elem = graph[key]
            var feature
            if elem.type in [PdElemClass.ElemType.CANVAS, PdElemClass.ElemType.ARRAY]:
                feature = " ".join(elem.statement.split(" ").slice(1))
            else:
                feature = " ".join(elem.statement.split(" ").slice(3))
            if feature not in node_by_text:
                node_by_text[feature] = []
            node_by_text[feature].append(elem)
            elem.text_feature = feature
    for key in old_graph:
        if key >= 0:
            var elem = old_graph[key]
            var feature
            if elem.type in [PdElemClass.ElemType.CANVAS, PdElemClass.ElemType.ARRAY]:
                feature = " ".join(elem.statement.split(" ").slice(1))
            else:
                feature = " ".join(elem.statement.split(" ").slice(3))
            if feature not in node_by_text_old:
                node_by_text_old[feature] = []
            node_by_text_old[feature].append(elem)
            elem.text_feature = feature
    
    var uid_dict = {}
    # Step 1: Initial set of node pairs that must be the same element
    for feature in node_by_text:
        if node_by_text[feature].size() == 1 and (feature in node_by_text_old and node_by_text_old[feature].size() == 1):
            var new_id = ResourceUID.create_id()
            var node1 = node_by_text[feature][0]
            var node2 = node_by_text_old[feature][0]
            var is_identical = false
            if node1.loc.distance_to(node2.loc) < dist_threshold:
                is_identical = true
                node1.debug_meta=1
            elif socket_similarity(node1.inlets, node2.inlets, graph, old_graph) > 0.9:
                is_identical = true
                node1.debug_meta=2
            elif socket_similarity(node1.outlets, node2.outlets, graph, old_graph) > 0.9:
                is_identical = true
                node1.debug_meta=3
            if is_identical:
                node1.uid = new_id
                node2.uid = new_id
                uid_dict[new_id] = [node1, node2]
                
    # Step 2: Propagate from known node pairs to find more
    var neighbor_by_feature = func(sockets, g):
        var s_dict = {}
        for s in sockets:
            var feature = [g[s[0]].text_feature, s[1]]
            if feature not in s_dict:
                s_dict[feature] = []
            s_dict[feature].append(g[s[0]])
        return s_dict
    var stack = []
    var visited = {}
    var p = 0
    for pair in uid_dict.values():
        stack.append(pair)
    while p < stack.size():
        var src1 = stack[p][0]
        var src2 = stack[p][1]
        if src1.uid in visited:
            p += 1
            continue
        visited[src1.uid] = true
        
        var sockets_pairs = []
        for i in min(src1.inlets.size(), src2.inlets.size()):
            sockets_pairs.append([src1.inlets[i], src2.inlets[i]])
        for i in min(src1.outlets.size(), src2.outlets.size()):
            sockets_pairs.append([src1.outlets[i], src2.outlets[i]])
            
        for pair in sockets_pairs:
            var neighbors1 = neighbor_by_feature.call(pair[0], graph)
            var neighbors2 = neighbor_by_feature.call(pair[1], old_graph)
            for feature in neighbors1:
                if feature in neighbors2:
                    for dst1 in neighbors1[feature]:
                        if not dst1.uid:
                            var new_id = ResourceUID.create_id()
                            for dst2 in neighbors2[feature]:
                                if not dst2.uid:
                                    if dst1.loc.distance_to(dst2.loc) < dist_threshold or \
                                        (dst1.loc-src1.loc).distance_to(dst2.loc-src2.loc) < dist_threshold or \
                                        (neighbors1[feature].size() == 1 and neighbors2[feature].size() == 1):
                                        dst1.uid = new_id
                                        dst2.uid = new_id
                                        uid_dict[new_id] = [dst1, dst2]
                                        stack.append([dst1, dst2])
                                        dst1.debug_meta=4
                                        break
                                        
        p += 1
    
    # Step 3: Pairing the remained nodes by calculating a similarity matrix
    var remains1 = []
    var remains2 = []
    for key in graph:
        if key >= 0 and not graph[key].uid:
            remains1.append(graph[key])
    for key in old_graph:
        if key >= 0 and not old_graph[key].uid:
            remains2.append(old_graph[key])
    
    var similarity_mat = {}
    var solver = HungarianOptimizer.new()
    solver.Init()
    var n = max(remains1.size(), remains2.size())
    for i in n:
        for j in n:
            # Padding
            if i >= remains1.size() or j >= remains2.size():
                solver.AddArcWithCost(i, j, 0)
                continue
            var score = 0
            var n1:PdElemClass = remains1[i]
            var n2:PdElemClass = remains2[j]
            # Similarity metrics: each scores 0~1
            if n1.type == n2.type and n1.obj_name_special == n2.obj_name_special:
                score += array_similarity(n1.text_feature.split(" "), n2.text_feature.split(" "))
                score += 0.5 * socket_similarity(n1.outlets, n2.outlets, graph, old_graph, true)
                score += 0.5 * socket_similarity(n1.inlets, n2.inlets, graph, old_graph, true)
                score += pow(2, min(dist_threshold - n1.loc.distance_to(n2.loc), 0) / dist_threshold)
            similarity_mat[[i,j]] = score
            solver.AddArcWithCost(i, j, -score)
    
    solver.Solve()
    for i in remains1.size():
        var j = solver.RightMate(i)
        if j < remains2.size() and similarity_mat[[i,j]] > similarity_threshold:
            var new_id = ResourceUID.create_id()
            remains1[i].uid = new_id
            remains2[j].uid = new_id
            uid_dict[new_id] = [remains1[i], remains2[j]]
            remains1[i].debug_meta=5
            
    solver.FreeSolver()
    return uid_dict
