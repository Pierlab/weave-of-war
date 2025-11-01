extends GdUnitLiteTestCase

const LOGISTICS_PATH := "res://data/logistics.json"

func test_logistics_maps_are_connected() -> void:
    var file := FileAccess.open(LOGISTICS_PATH, FileAccess.READ)
    asserts.is_not_null(file, "Logistics dataset should be readable")
    if file == null:
        return

    var entries := JSON.parse_string(file.get_as_text())
    asserts.is_true(entries is Array, "Logistics dataset should parse into an array")
    if not (entries is Array):
        return

    for entry in entries:
        if not (entry is Dictionary):
            continue
        var context := "logistics[%s]" % entry.get("id", "unknown")
        var map_data := entry.get("map")
        asserts.is_true(map_data is Dictionary, "%s map definition must exist" % context)
        if not (map_data is Dictionary):
            continue

        var graph := _build_graph(map_data)
        var nodes: Array = graph.get("nodes", [])
        var adjacency: Dictionary = graph.get("adjacency", {})
        asserts.is_true(nodes.size() > 0, "%s map should declare nodes" % context)
        if nodes.is_empty():
            continue

        var visited := _breadth_first(nodes[0], adjacency)
        for node_id in nodes:
            asserts.is_true(visited.has(node_id), "%s map node %s is disconnected" % [context, node_id])

func _build_graph(map_data: Dictionary) -> Dictionary:
    var nodes: Array = []
    var adjacency: Dictionary = {}

    if map_data.has("supply_centers") and map_data.get("supply_centers") is Array:
        for center in map_data.get("supply_centers"):
            var tile_id := _tile_id_from_variant(center)
            if tile_id.is_empty():
                continue
            if not nodes.has(tile_id):
                nodes.append(tile_id)
            if not adjacency.has(tile_id):
                adjacency[tile_id] = []

    if map_data.has("routes") and map_data.get("routes") is Array:
        for route in map_data.get("routes"):
            if not (route is Dictionary):
                continue
            var path_ids: Array = []
            if route.has("path") and route.get("path") is Array:
                for node in route.get("path"):
                    var tile_id := _tile_id_from_variant(node)
                    if tile_id.is_empty():
                        continue
                    path_ids.append(tile_id)
                    if not nodes.has(tile_id):
                        nodes.append(tile_id)
                    if not adjacency.has(tile_id):
                        adjacency[tile_id] = []
            if path_ids.size() < 2:
                continue
            for index in range(path_ids.size() - 1):
                _connect_nodes(adjacency, path_ids[index], path_ids[index + 1])
            var route_type := str(route.get("type", ""))
            if route_type == "ring" and path_ids.size() > 2:
                _connect_nodes(adjacency, path_ids[path_ids.size() - 1], path_ids[0])

    return {
        "nodes": nodes,
        "adjacency": adjacency,
    }

func _connect_nodes(adjacency: Dictionary, a: String, b: String) -> void:
    var neighbors_a: Array = adjacency.get(a, [])
    if not neighbors_a.has(b):
        neighbors_a.append(b)
    adjacency[a] = neighbors_a

    var neighbors_b: Array = adjacency.get(b, [])
    if not neighbors_b.has(a):
        neighbors_b.append(a)
    adjacency[b] = neighbors_b

func _breadth_first(start: String, adjacency: Dictionary) -> Dictionary:
    var visited: Dictionary = {}
    var queue: Array = [start]
    var index := 0
    while index < queue.size():
        var current: String = queue[index]
        index += 1
        if visited.has(current):
            continue
        visited[current] = true
        var neighbors: Array = adjacency.get(current, [])
        for neighbor in neighbors:
            if not visited.has(neighbor):
                queue.append(neighbor)
    return visited

func _tile_id_from_variant(data: Variant) -> String:
    if data is Dictionary:
        return "%d,%d" % [int(data.get("q", 0)), int(data.get("r", 0))]
    if data is Array and data.size() >= 2:
        return "%d,%d" % [int(data[0]), int(data[1])]
    return ""
