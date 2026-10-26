@tool
extends RefCounted
var metadata: Dictionary = {}
var _chunks: PackedStringArray = []
var _failed := false
var _length := 0
func begin(value: Dictionary) -> bool:
    metadata = value.duplicate()
    _failed = int(value.get("totalBytes",0))<1 or int(value.get("totalBytes",0))>16*1024*1024 or int(value.get("totalChunks",0))<1 or int(value.get("totalChunks",0))>342
    _failed = _failed or int(value.get("width",0))<1 or int(value.get("width",0))>4096 or int(value.get("height",0))<1 or int(value.get("height",0))>4096 or str(value.get("sha256","")).length()!=64
    return not _failed
func push(index: int, data: String) -> bool:
    if _failed or index != _chunks.size() or index >= int(metadata.get("totalChunks",0)) or data.length()>65536 or _length+data.length()>22369624:
        _failed = true
        return false
    _chunks.append(data)
    _length += data.length()
    return true
func finish() -> Dictionary:
    if _failed or _chunks.size()!=int(metadata.get("totalChunks",0)):
        return {"__error":{"code":"INVALID_CAPTURE_PAYLOAD","message":"Incomplete or invalid game capture"}}
    var encoded := "".join(_chunks)
    var bytes := Marshalls.base64_to_raw(encoded)
    var hashing := HashingContext.new()
    hashing.start(HashingContext.HASH_SHA256)
    hashing.update(bytes)
    if bytes.size()!=int(metadata.totalBytes) or Marshalls.raw_to_base64(bytes)!=encoded or hashing.finish().hex_encode()!=metadata.sha256:
        return {"__error":{"code":"INVALID_CAPTURE_PAYLOAD","message":"Game capture checksum mismatch"}}
    return {"png_base64":encoded,"width":metadata.width,"height":metadata.height,"scene":metadata.get("scene"),
        "captured_at":metadata.get("captured_at"),"viewport_index":null,"run_id":metadata.runId,
        "framing":metadata.get("framing")}
