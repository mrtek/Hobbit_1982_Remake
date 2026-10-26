@tool
extends RefCounted
var _editor
func _init(editor): _editor=editor
func _error(code:String,message:String)->Dictionary:return {"__error":{"code":code,"message":message}}
func _dependency_path(raw:String)->String:
    var value=raw.get_slice("::",2) if raw.contains("::") else raw
    if value.is_empty() and raw.contains("::"): value=ResourceUID.ensure_path(raw.get_slice("::",0))
    value=ResourceUID.ensure_path(value) if value.begins_with("uid://") else value
    return value
func _safe(path_value:String)->bool:
    if not path_value.begins_with("res://") or path_value.contains("\\") or path_value.substr(6).contains(":"):return false
    for part in path_value.substr(6).split("/"):
        if part.to_lower() in ["",".","..",".godot",".godot-mcp",".git"]:return false
    return true
func _exists(path_value:String)->bool:return FileAccess.file_exists(path_value) or ResourceLoader.exists(path_value)
func dependencies(params:Dictionary)->Dictionary:
    var root=str(params.get("path",""));if not _safe(root):return _error("INVALID_ARGUMENT","Unsafe resource path")
    var recursive=bool(params.get("recursive",false));var max_nodes=int(params.get("max_nodes",200));var max_depth=int(params.get("max_depth",8))
    var pending:Array=[{"path":root,"depth":0}];var seen:Dictionary={};var nodes:Array=[];var edges:Array=[];var broken:Array=[];var truncated=false;var max_edges=min(4000,max_nodes*8)
    while not pending.is_empty():
        var item=pending.pop_front();var path_value=str(item.path);var key=path_value.to_lower()
        if seen.has(key):continue
        if nodes.size()>=max_nodes:truncated=true;break
        seen[key]=true
        var exists=_exists(path_value);var direct:Array=[]
        if exists:
            for raw in ResourceLoader.get_dependencies(path_value):
                if edges.size()>=max_edges:truncated=true;break
                var dependency=_dependency_path(str(raw));if not _safe(dependency):continue
                direct.append(dependency);edges.append({"from":path_value,"to":dependency,"raw":str(raw)})
                if not _exists(dependency) and not broken.has(dependency):broken.append(dependency)
                if recursive and int(item.depth)<max_depth and _exists(dependency):pending.append({"path":dependency,"depth":int(item.depth)+1})
                elif recursive and int(item.depth)>=max_depth:truncated=true
        else:broken.append(path_value)
        direct.sort();nodes.append({"path":path_value,"exists":exists,"depth":int(item.depth),"dependencies":direct})
    nodes.sort_custom(func(a,b):return a.path<b.path);edges.sort_custom(func(a,b):return (a.from+"\n"+a.to)<(b.from+"\n"+b.to));broken.sort()
    return {"root":root,"nodes":nodes,"edges":edges,"broken":broken,"truncated":truncated,"complete":not truncated}
func _walk(directory:String,pending:Array,files:Array,max_files:int,state:Dictionary)->bool:
    var dir=DirAccess.open(directory);if dir==null:return true
    var entries:Array=[]
    dir.list_dir_begin()
    while true:
        var name=dir.get_next();if name.is_empty():break
        entries.append({"name":name,"directory":dir.current_is_dir(),"link":dir.is_link(name)})
    dir.list_dir_end();entries.sort_custom(func(a,b):return a.name.to_lower()<b.name.to_lower())
    for entry in entries:
        var name:String=entry.name
        if entry.link:state.links+=1;continue
        if directory=="res://addons" and name=="godot_mcp":continue
        if name.begins_with(".") or name in ["addons"] and directory=="res://":
            if entry.directory and name=="addons":pending.append(directory.path_join(name))
            continue
        var path_value=directory.path_join(name)
        if entry.directory:pending.append(path_value)
        elif not name.ends_with(".import") and not name.ends_with(".uid"):
            files.append(path_value);if files.size()>max_files:return false
    return true
func impact(params:Dictionary)->Dictionary:
    var target=str(params.get("path",""));if not _safe(target):return _error("INVALID_ARGUMENT","Unsafe resource path")
    var max_files=int(params.get("max_files",1000));var pending:Array=["res://"];var files:Array=[];var complete=true;var scan={"links":0}
    while not pending.is_empty():
        if not _walk(pending.pop_front(),pending,files,max_files,scan):complete=false;break
    var inbound:Array=[];var checked=0
    for source in files:
        if str(source).to_lower()==target.to_lower():continue
        for raw in ResourceLoader.get_dependencies(source):
            checked+=1
            if checked>20000:complete=false;break
            if _dependency_path(str(raw)).to_lower()==target.to_lower():inbound.append({"path":source,"raw":str(raw)});break
        if not complete or inbound.size()>=1000:complete=false;break
    inbound.sort_custom(func(a,b):return a.path<b.path)
    var warnings:Array=[]
    if not complete:warnings.append("SCAN_TRUNCATED")
    if scan.links>0:warnings.append("LINKS_SKIPPED")
    if not inbound.is_empty():warnings.append("INBOUND_REFERENCES")
    if str(params.get("action"))=="move" and FileAccess.file_exists(str(params.get("target_path",""))):warnings.append("TARGET_EXISTS")
    return {"path":target,"action":params.action,"targetPath":params.get("target_path"),"inbound":inbound,"scannedFiles":min(files.size(),max_files),"linksSkipped":scan.links,"complete":complete,"safe":complete and warnings.is_empty(),"warnings":warnings}
func _import_valid(filesystem,path_value:String)->bool:
    var directory=filesystem.get_filesystem_path(path_value.get_base_dir());if directory==null:return false
    for i in range(directory.get_file_count()):
        if directory.get_file_path(i)==path_value:return directory.get_file_import_is_valid(i)
    return false
func import_resources(params:Dictionary)->Dictionary:
    var paths:PackedStringArray=PackedStringArray(params.get("paths",[]));var timeout=int(params.get("timeout_ms",15000));var started=Time.get_ticks_msec();var filesystem=_editor.get_resource_filesystem()
    while filesystem.is_scanning():
        if Time.get_ticks_msec()-started>=timeout:return _error("IMPORT_TIMEOUT","Filesystem scan did not finish")
        await _editor.get_base_control().get_tree().process_frame
    for path_value in paths:
        if not _safe(path_value) or not FileAccess.file_exists(path_value):return _error("NOT_FOUND","Import source does not exist: "+path_value)
        filesystem.update_file(path_value)
    filesystem.reimport_files(paths)
    var results:Array=[]
    for path_value in paths:results.append({"path":path_value,"valid":_import_valid(filesystem,path_value),"type":filesystem.get_file_type(path_value)})
    return {"requested":Array(paths),"results":results,"complete":not filesystem.is_scanning(),"durationMs":Time.get_ticks_msec()-started}
