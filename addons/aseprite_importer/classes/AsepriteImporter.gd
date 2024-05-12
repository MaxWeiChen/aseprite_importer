@tool
extends Node
class_name AsepriteImporter

enum Error{
	OK,
	INVALID_JSON_DATA,
	MISSING_JSON_DATA,
	MISSING_ANIMATION_PLAYER,
	MISSING_SPRITE,
	NO_TAGS_SELECTED,
	DUPLICATE_TAG_NAME,
	MISSING_TEXTURE,
}

static func generate_animations(import_data : AsepriteImportData, selected_tags : Array,
		animation_player : AnimationPlayer, sprites : Array, texture : Texture, is_use_layers : bool) -> int:
	
	if (import_data == null || import_data.json_data == null):
		return Error.MISSING_JSON_DATA
	
	var frame_tags : Array = import_data.get_tags()
	
	if (selected_tags == null):
		return Error.NO_TAGS_SELECTED
	else:
		var tag_names := []
		for tag_idx in selected_tags:
			var tag_name : String = frame_tags[tag_idx].name
			
			if tag_names.has(tag_name):
				return Error.DUPLICATE_TAG_NAME
			else:
				tag_names.append(tag_name)
	
	if not animation_player:
		return Error.MISSING_ANIMATION_PLAYER
				
	if texture == null:
		return Error.MISSING_TEXTURE
			
	# Animations are grouped in an AnimationLibrary resource
	# which is referenced by the AnimationPlayer
	var library_name = ""
	var animation_library : AnimationLibrary = null
	if(animation_player.has_animation_library(library_name)):
		animation_library = animation_player.get_animation_library(library_name)
	else:
		animation_library = AnimationLibrary.new()
		animation_player.add_animation_library(library_name, animation_library)
	
	var animation_root_path := animation_player.root_node
	var animation_root_node := animation_player.get_node(animation_root_path)
	
	var has_any_sprite_pass = false
	for sprite in sprites:
		if sprite is Sprite2D or sprite is Sprite3D:
			has_any_sprite_pass = true
			break
	
	if not has_any_sprite_pass:
		return Error.MISSING_SPRITE
			
	for layer_idx in sprites.size():
		var sprite = sprites[layer_idx]
		if sprite == null:
			continue
			
		var sprite_relative_path := str(animation_root_node.get_path_to(sprite))
		# These are tracks that will be used
		var tracks := {
			"region" : {
				path = (sprite_relative_path + ":region_rect"),
			},
			"offset" : {
				path = (sprite_relative_path + ":offset")
			}
		}

		var frames := import_data.get_frame_array()
		var frame_count_each_layer = import_data.get_frame_count_each_layer(is_use_layers)
		var is_sprite3d := sprite is Sprite3D
	
		# Iterate over each tag (animation)
		for tag_idx in selected_tags:
			var tag : Dictionary = frame_tags[tag_idx]
			
			var frame_idxs_offset = layer_idx * frame_count_each_layer
			var frame_idxs : Array = range(frame_idxs_offset + tag.from, frame_idxs_offset + tag.to + 1)
			var is_frame_idxs_safe = true
			for i in frame_idxs:			
				if i >= frames.size():
					is_frame_idxs_safe = false
					printerr("generate_animations fail, frame_idxs is over size -> ", i, ">=", frames.size())
					break
			if not is_frame_idxs_safe:
				printerr("generate_animations fail, tag -> ", tag.name)
				break
		
			var animation : Animation
			# Check if the Animation already exists
			if animation_library.has_animation(tag.name):
				animation = animation_library.get_animation(tag.name)
			else:
				# If it doesn't, adds a new one
				animation = Animation.new()
				# warning-ignore:return_value_discarded
				animation_library.add_animation(tag.name, animation)
		
			# Setup the animation tracks
			for track_name in tracks:
				var track : Dictionary = tracks[track_name]
				
				track.idx = animation.find_track(track.path, Animation.TYPE_VALUE)
				
				# Checks if the track doesn't exist
				if track.idx == -1:
					# Create a new_track
					track.idx = animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(track.idx, track.path)
				else:
					# Remove all existing keys from the track
					for key_idx in range(animation.track_get_key_count(track.idx)):
						animation.track_remove_key(track.idx, 0)
				
				# Set the track Interpolation Mode to Nearest
				animation.track_set_interpolation_type(track.idx, Animation.INTERPOLATION_NEAREST)
				# Enable the track
				animation.track_set_enabled(track.idx, true)
		
			var time := 0.0
			
			# Modify the frame order based on the tag's direction
			match tag.direction:
				"reverse":
					frame_idxs.reverse()
				"pingpong":
					var pong_frame_idxs := range(tag.from + 1, tag.to)
					pong_frame_idxs.reverse()
					frame_idxs += pong_frame_idxs
		
			# Insert the new keys
			for i in frame_idxs:				
				var frame : Dictionary = frames[i]
				
				# Get the region of the spritesheet that has the frame
				var rect = frame.frame
				var region = Rect2(rect.x, rect.y, rect.w, rect.h)
			
				# Insert the new key for the region track
				animation.track_insert_key(tracks.region.idx, time, region)
				
				# Get the center of the frame in the original size
				var source_size : Dictionary = frame.sourceSize
				var source_center_x : float = source_size.w / 2
				var source_center_y : float = source_size.h / 2
				
				# Get the center of the trimmed frame in the spritesheet
				var trim_rect : Dictionary = frame.spriteSourceSize
				var trim_rect_center_x : float = trim_rect.x + (trim_rect.w / 2)
				var trim_rect_center_y : float = trim_rect.y + (trim_rect.h / 2)
				
				# Calculate the offset between the trimmed frame center and original frame center
				var offset_x := trim_rect_center_x - source_center_x
				var offset_y := trim_rect_center_y - source_center_y
				
				# Invert the vertical offset when the selected sprite is a Sprite3D
				if is_sprite3d:
					offset_y *= -1
				
				# Insert the new key for the offset track
				animation.track_insert_key(tracks.offset.idx, time, Vector2(offset_x, offset_y))
				
				# Add up the current frame's duration for the next key position
				time += frame.duration / 1000
			
			# Set the animation length equal to the sum of all frame's durations
			animation.length = time
	
		sprite.texture = texture
		sprite.region_enabled = true
		sprite.centered = true

	return OK
