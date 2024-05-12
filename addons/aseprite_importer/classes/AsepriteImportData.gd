@tool
extends Node
class_name AsepriteImportData


enum Error{
	OK = 0,
	# Error codes start from 49 to not conflict with GlobalScope's error constants
	ERR_JSON_PARSE_ERROR = 49,
	ERR_INVALID_JSON_DATA,
	ERR_MISSING_FRAME_TAGS,
	ERR_EMPTY_FRAME_TAGS,
	ERR_MISSING_LAYERS_TAGS,
	ERR_EMPTY_LAYERS_TAGS
}

const FRAME_TEMPLATE = {
	frame = {
		x = TYPE_INT,
		y = TYPE_INT,
		w = TYPE_INT,
		h = TYPE_INT,
	},
	spriteSourceSize = {
		x = TYPE_INT,
		y = TYPE_INT,
		w = TYPE_INT,
		h = TYPE_INT,
	},
	sourceSize = {
		w = TYPE_INT,
		h = TYPE_INT,
	},
	duration = TYPE_INT,
}

const META_TEMPLATE = {
	frameTags = [
		{
			name = TYPE_STRING,
			from = TYPE_INT,
			to = TYPE_INT,
			direction = TYPE_STRING
		},
	],
	size = {
		w = TYPE_INT,
		h = TYPE_INT,
	},
	layers = [
		{
			name = TYPE_STRING,
		},
	],
}

var json_filepath : String
var json_data : Dictionary

func load(filepath : String) -> int:
	var file = FileAccess.open(filepath, FileAccess.READ)
	if(file == null):
		var error := FileAccess.get_open_error()
		return error
	
	var file_text = file.get_as_text()
	
	var json = JSON.new()
	var error := json.parse(file_text)
	
	if error != OK:
		return Error.ERR_JSON_PARSE_ERROR
	
	error = _validate_json(json)
	if error != OK:
		return error

	json_filepath = filepath
	json_data = json.get_data()

	return OK

func get_frame_array() -> Array:
	if (json_data == null || not json_data is Dictionary):
		return []
	
	var frame_data = json_data.frames
	if frame_data is Dictionary:
		return frame_data.values()
	
	return frame_data
	

func get_frame_count_each_layer(is_use_layers : bool) -> int:
	if (json_data == null || not json_data is Dictionary):
		return 0
		
	var frames_count = get_frame_array().size()
	if is_use_layers:
		var layers_count = get_layers().size()
		#print("get_frame_count_each_layer -> ", frames_count, " / ", layers_count, " = ", frames_count / layers_count)
		return frames_count / layers_count
	
	#print("get_frame_count_each_layer -> ", frames_count)
	return frames_count

func get_image_filename() -> String:
	if (json_data == null || not json_data is Dictionary || !json_data.meta.has("image")):
		print("get_image_filename -> ", str(json_data))
		return ""
	return json_data.meta.image

func get_image_size() -> Vector2:
	if (json_data == null || not json_data is Dictionary):
		return Vector2.ZERO
	
	var image_size : Dictionary = json_data.meta.size
	return Vector2(
		image_size.w,
		image_size.h
	)


func get_tag(tag_idx : int) -> Dictionary:
	var tags := get_tags()
	
	if tag_idx >= 0 and tag_idx < tags.size():
		return tags[tag_idx]
	
	return {}


func get_tags() -> Array:
	if (json_data == null):
		return []
	
	return json_data.meta.frameTags
	
	
func get_layers() -> Array:
	if (json_data == null):
		return []
	var layer_names :=[]
	for layer in json_data.meta.layers:
		if layer.name != "ALL":
			layer_names.append(layer.name)
	return layer_names


static func _validate_json(json : JSON) -> int:
	var data = json.get_data()
	
	if not (data is Dictionary and data.has_all(["frames", "meta"])):
		return Error.ERR_INVALID_JSON_DATA
	
	# "frames" validation
	var frames = data.frames
	var is_hash : bool = (frames is Dictionary)
	
	for frame in frames:
		if is_hash:
			frame = frames[frame]
		
		if not _match_template(frame, FRAME_TEMPLATE):
			return Error.ERR_INVALID_JSON_DATA


	# "meta" validation
	if not _match_template(data.meta, META_TEMPLATE):
		var meta := data.meta as Dictionary
		# "framgeTags" validation
		if not meta.has("frameTags"):
			return Error.ERR_MISSING_FRAME_TAGS
		elif meta.frameTags == []:
			return Error.ERR_EMPTY_FRAME_TAGS
		# "layers" validation
		if not meta.has("layers"):
			return Error.ERR_MISSING_LAYERS_TAGS
		elif meta.layers == []:
			return Error.ERR_EMPTY_LAYERS_TAGS

		return Error.ERR_INVALID_JSON_DATA
	

	return OK


# This helper function recursively walks an Array or a Dictionary checking if each
# children's type matches the template
static func _match_template(data, template) -> bool:
	match typeof(template):
		TYPE_INT:
			# When parsed, the JSON interprets integer values as floats
			if template == TYPE_INT and typeof(data) == TYPE_FLOAT:
				return true
			return typeof(data) == template
		TYPE_DICTIONARY:
			if typeof(data) != TYPE_DICTIONARY:
				return false

			if not data.has_all(template.keys()):
				return false

			for key in template:
				if not _match_template(data[key], template[key]):
					return false
		TYPE_ARRAY:
			if typeof(data) != TYPE_ARRAY:
				return false

			if data.is_empty():
				return false

			for element in data:
				if not _match_template(element, template[0]):
					return false

	return true
