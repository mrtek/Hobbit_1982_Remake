@tool
extends RefCounted

const Scope = preload("res://addons/godot_mcp/bridge/scene_scope.gd")
const MAX_POINTS := 256
const MAX_GENERATED_POINTS := 8192

var _editor

func _init(editor):
    _editor = editor

func _error(code: String, message: String) -> Dictionary:
    return {"__error":{"code":code,"message":message}}

func _point(value: Vector2) -> Dictionary:
    return {"x":value.x,"y":value.y}

func _finite(points: PackedVector2Array) -> bool:
    for value in points:
        if not is_finite(value.x) or not is_finite(value.y):
            return false
    return true

func _world(node: Node2D, local: PackedVector2Array) -> PackedVector2Array:
    var result := PackedVector2Array()
    for value in local:
        result.append(node.to_global(value))
    return result

func _area(polygon: PackedVector2Array) -> float:
    var twice := 0.0
    for index in range(polygon.size()):
        var next: Vector2 = polygon[(index+1)%polygon.size()]
        var current: Vector2 = polygon[index]
        twice += current.x*next.y-next.x*current.y
    return abs(twice)*0.5

func _route(node: Node2D, clearance: float) -> Dictionary:
    var local_polygons: Array = []
    var endpoints: Array = []
    if node is Line2D:
        var line := node as Line2D
        if line.closed or line.width_curve != null or not is_finite(line.width) or line.width <= 0.0:
            return {"unsupported":"Closed, variable-width or nonpositive Line2D is unsupported"}
        if line.points.size()<2 or line.points.size()>MAX_POINTS or not _finite(line.points):
            return {"unsupported":"Line2D requires 2..256 finite points"}
        local_polygons = Geometry2D.offset_polyline(line.points,line.width*0.5,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
        endpoints = [line.to_global(line.points[0]),line.to_global(line.points[-1])]
    elif node is Polygon2D:
        var shape := node as Polygon2D
        if shape.polygon.size()<3 or shape.polygon.size()>MAX_POINTS or not _finite(shape.polygon):
            return {"unsupported":"Polygon2D requires 3..256 finite vertices"}
        var shifted := PackedVector2Array()
        for value in shape.polygon:
            shifted.append(value+shape.offset)
        local_polygons = [shifted]
    else:
        return {"unsupported":"Route must be Line2D or Polygon2D"}
    if local_polygons.is_empty() or local_polygons.size()>32:
        return {"unsupported":"Route footprint could not be bounded"}
    var footprints: Array = []
    var generated := 0
    for local in local_polygons:
        var world := _world(node,local)
        if world.size()<3 or not _finite(world):
            return {"unsupported":"Route transform produced invalid geometry"}
        var expanded: Array = Geometry2D.offset_polygon(world,clearance,Geometry2D.JOIN_ROUND) if clearance>0.0 else [world]
        for polygon in expanded:
            generated += polygon.size()
            if generated>MAX_GENERATED_POINTS or footprints.size()>=32 or not _finite(polygon):
                return {"unsupported":"Route footprint exceeds geometry limits"}
            if polygon.size()>=3 and _area(polygon)>0.001:
                footprints.append(polygon)
    if footprints.is_empty():
        return {"unsupported":"Route footprint has no usable area"}
    return {"polygons":footprints,"endpoints":endpoints}

func _round_shape(radius: float, top: float = 0.0, bottom: float = 0.0) -> PackedVector2Array:
    var polygon := PackedVector2Array()
    if is_zero_approx(top) and is_zero_approx(bottom):
        for index in range(64):
            var angle := TAU*float(index)/64.0
            polygon.append(Vector2(cos(angle),sin(angle))*radius)
    else:
        for index in range(33):
            var angle := PI+PI*float(index)/32.0
            polygon.append(Vector2(cos(angle)*radius,top+sin(angle)*radius))
        for index in range(33):
            var angle := PI*float(index)/32.0
            polygon.append(Vector2(cos(angle)*radius,bottom+sin(angle)*radius))
    return polygon

func _obstacle(node: Node2D) -> Dictionary:
    var local := PackedVector2Array()
    var approximate := false
    if node is CollisionPolygon2D:
        var collision_polygon := node as CollisionPolygon2D
        if collision_polygon.disabled:
            return {"disabled":true}
        if collision_polygon.build_mode != CollisionPolygon2D.BUILD_SOLIDS or collision_polygon.one_way_collision:
            return {"unsupported":"Hollow or one-way CollisionPolygon2D is unsupported"}
        local = collision_polygon.polygon
    elif node is CollisionShape2D:
        var collider := node as CollisionShape2D
        if collider.disabled:
            return {"disabled":true}
        if collider.one_way_collision:
            return {"unsupported":"One-way CollisionShape2D requires directional analysis"}
        var shape := collider.shape
        if shape is RectangleShape2D:
            var half: Vector2 = shape.size*0.5
            local = PackedVector2Array([Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)])
        elif shape is ConvexPolygonShape2D:
            local = shape.points
        elif shape is CircleShape2D:
            local = _round_shape(shape.radius+0.5)
            approximate = true
        elif shape is CapsuleShape2D:
            var half_segment: float = max(0.0,shape.height*0.5-shape.radius)
            local = _round_shape(shape.radius+0.5,-half_segment,half_segment)
            approximate = true
        else:
            return {"unsupported":"CollisionShape2D shape is unsupported: "+(shape.get_class() if shape else "null")}
    else:
        return {"unsupported":"Obstacle must be CollisionShape2D or CollisionPolygon2D"}
    if local.size()<3 or local.size()>MAX_POINTS or not _finite(local):
        return {"unsupported":"Obstacle requires 3..256 finite vertices"}
    var world := _world(node,local)
    if not _finite(world) or _area(world)<=0.001:
        return {"unsupported":"Obstacle transform produced invalid geometry"}
    return {"polygons":[world],"approximate":approximate}

func validate_walkways(params: Dictionary) -> Dictionary:
    var root: Node = _editor.get_edited_scene_root()
    if root == null:
        return _error("NO_OPEN_SCENE","Open a scene before validating walkways")
    var route_paths: Array = params.get("routes",[])
    var obstacle_paths: Array = params.get("obstacles",[])
    var connections: Array = params.get("connections",[])
    if route_paths.is_empty() or route_paths.size()>32 or obstacle_paths.is_empty() or obstacle_paths.size()>64 or connections.size()>64:
        return _error("INVALID_ARGUMENT","Geometry request exceeds route, obstacle or connection limits")
    var clearance := float(params.get("agent_radius_px",0.0))
    var max_findings := int(params.get("max_findings",100))
    if not is_finite(clearance) or clearance<0.0 or clearance>256.0 or max_findings<1 or max_findings>100:
        return _error("INVALID_ARGUMENT","Geometry bounds are invalid")
    var routes: Dictionary = {}
    var obstacles: Dictionary = {}
    var route_node_ids: Dictionary = {}
    var obstacle_node_ids: Dictionary = {}
    var diagnostics: Array = []
    var approximate: Array = []
    var skipped_disabled: Array = []
    for route_path in route_paths:
        var node = Scope.resolve(root,str(route_path))
        if node == null:
            return _error("NODE_NOT_FOUND","Route does not exist in the edited scene: "+str(route_path))
        if route_node_ids.has(node.get_instance_id()):
            return _error("INVALID_ARGUMENT","Routes must refer to distinct scene nodes")
        route_node_ids[node.get_instance_id()] = true
        var route = _route(node,clearance) if node is Node2D else {"unsupported":"Route is not Node2D"}
        if route.has("unsupported"):
            diagnostics.append({"code":"UNSUPPORTED_ROUTE","nodePath":route_path,"message":route.unsupported})
        else:
            routes[route_path] = route
    for obstacle_path in obstacle_paths:
        var node = Scope.resolve(root,str(obstacle_path))
        if node == null:
            return _error("NODE_NOT_FOUND","Obstacle does not exist in the edited scene: "+str(obstacle_path))
        if obstacle_node_ids.has(node.get_instance_id()):
            return _error("INVALID_ARGUMENT","Obstacles must refer to distinct scene nodes")
        obstacle_node_ids[node.get_instance_id()] = true
        var obstacle = _obstacle(node) if node is Node2D else {"unsupported":"Obstacle is not Node2D"}
        if obstacle.has("disabled"):
            skipped_disabled.append(obstacle_path)
        elif obstacle.has("unsupported"):
            diagnostics.append({"code":"UNSUPPORTED_SHAPE","nodePath":obstacle_path,"message":obstacle.unsupported})
        else:
            obstacles[obstacle_path] = obstacle
            if obstacle.approximate:
                approximate.append(obstacle_path)
    var findings: Array = []
    var checked_pairs := 0
    var truncated := false
    for route_path in route_paths:
        if not routes.has(route_path):
            continue
        for obstacle_path in obstacle_paths:
            if not obstacles.has(obstacle_path):
                continue
            checked_pairs += 1
            var overlap_area := 0.0
            var first_point = null
            for route_polygon in routes[route_path].polygons:
                for obstacle_polygon in obstacles[obstacle_path].polygons:
                    for overlap in Geometry2D.intersect_polygons(route_polygon,obstacle_polygon):
                        if overlap.size()<3:
                            continue
                        var area := _area(overlap)
                        if area<=0.001:
                            continue
                        overlap_area += area
                        if first_point == null:
                            first_point = _point(overlap[0])
            if overlap_area>0.001:
                if findings.size()>=max_findings:
                    truncated = true
                    break
                findings.append({"code":"PATH_COLLISION","routePath":route_path,"obstaclePath":obstacle_path,
                    "point":first_point,"overlapAreaPx2":overlap_area,"approximate":obstacles[obstacle_path].approximate})
        if truncated:
            break
    if not truncated:
        for link in connections:
            var from_path = str(link.get("from",""))
            var to_path = str(link.get("to",""))
            if not routes.has(from_path) or not routes.has(to_path) or routes[from_path].endpoints.is_empty() or routes[to_path].endpoints.is_empty():
                diagnostics.append({"code":"CONNECTION_UNSUPPORTED","from":from_path,"to":to_path})
                continue
            var from_point: Vector2 = routes[from_path].endpoints[0 if link.get("from_end")=="start" else 1]
            var to_point: Vector2 = routes[to_path].endpoints[0 if link.get("to_end")=="start" else 1]
            var gap := from_point.distance_to(to_point)
            if gap>float(link.get("max_gap_px",0)):
                if findings.size()>=max_findings:
                    truncated = true
                    break
                findings.append({"code":"CONNECTION_GAP","from":from_path,"to":to_path,
                    "fromPoint":_point(from_point),"toPoint":_point(to_point),
                    "distancePx":gap,"maxGapPx":float(link.get("max_gap_px",0))})
    var complete := not truncated and diagnostics.is_empty()
    return {"scenePath":root.scene_file_path,"complete":complete,"clear":complete and findings.is_empty(),
        "truncated":truncated,"findings":findings,"diagnostics":diagnostics,"checkedPairs":checked_pairs,
        "routesChecked":routes.size(),"obstaclesChecked":obstacles.size(),"skippedDisabled":skipped_disabled,
        "approximateObstacles":approximate,"agentRadiusPx":clearance}
