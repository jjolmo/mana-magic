@tool
class_name ManaJsonHelper
extends RefCounted

const DATA_PATH := "res://data/databases/"

static func load_json(filename: String) -> Array:
	var path := DATA_PATH + filename
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ManaJsonHelper: Cannot open %s" % path)
		return []
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("ManaJsonHelper: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return []
	var data = json.data
	if data is Array:
		return data
	return []

static func load_json_dict(filename: String) -> Dictionary:
	var path := DATA_PATH + filename
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ManaJsonHelper: Cannot open %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("ManaJsonHelper: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
	var data = json.data
	if data is Dictionary:
		return data
	return {}

static func save_json_dict(filename: String, data: Dictionary) -> Error:
	var path := DATA_PATH + filename
	var json_text := JSON.stringify(data, "  ")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("ManaJsonHelper: Cannot write %s" % path)
		return ERR_FILE_CANT_WRITE
	file.store_string(json_text)
	file.close()
	return OK

static func save_json(filename: String, data: Array) -> Error:
	var path := DATA_PATH + filename
	var json_text := JSON.stringify(data, "  ")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("ManaJsonHelper: Cannot write %s" % path)
		return ERR_FILE_CANT_WRITE
	file.store_string(json_text)
	file.close()
	return OK

static func get_next_id(data: Array) -> int:
	var max_id := -1
	for entry in data:
		if entry is Dictionary and entry.has("id"):
			var eid = entry["id"]
			if eid is int or eid is float:
				max_id = maxi(max_id, int(eid))
	return max_id + 1

static func find_by_id(data: Array, id: int) -> Dictionary:
	for entry in data:
		if entry is Dictionary and entry.get("id") == id:
			return entry
	return {}

static func find_index_by_id(data: Array, id: int) -> int:
	for i in range(data.size()):
		var entry = data[i]
		if entry is Dictionary and entry.get("id") == id:
			return i
	return -1

static func remove_by_id(data: Array, id: int) -> bool:
	var idx := find_index_by_id(data, id)
	if idx >= 0:
		data.remove_at(idx)
		return true
	return false
