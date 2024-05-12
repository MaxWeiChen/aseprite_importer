@tool
extends PanelContainer

@onready var import_menu : Container = %ImportMenu
@onready var json_import_menu : Container = %JSONImportMenu
@onready var layers_menu : Container = %LayersMenu
@onready var tags_menu : Container = %TagsMenu
@onready var select_animation_player_menu = %SelectAnimationPlayerMenu
@onready var select_sprite_menu = %SelectSpriteMenu
@onready var generate_button : Button = %GenerateButton

@onready var spritesheet_inspector : Container = %SpritesheetInspector

@onready var alert_dialog : AcceptDialog = %AlertDialog


const ERROR_MSG := {
	AsepriteImporter.Error.MISSING_JSON_DATA : "Missing JSON Data!",
	AsepriteImporter.Error.MISSING_ANIMATION_PLAYER : "Select an AnimationPlayer node!",
	AsepriteImporter.Error.MISSING_SPRITE : "Select a Sprite node!",
	AsepriteImporter.Error.NO_TAGS_SELECTED : "No tags selected to import!",
	AsepriteImporter.Error.DUPLICATE_TAG_NAME : "Two or more of the selected tags share the same name\nSelect only tags with distinct names",
	AsepriteImporter.Error.MISSING_TEXTURE: "No texture selected!",
}

const IMPORT_MENU_INITIAL_WIDTH := 300

var import_data : AsepriteImportData

var _is_ready := false

signal animations_generated(animation_player)


func _ready() -> void:
	import_menu.size.x = IMPORT_MENU_INITIAL_WIDTH
	
	json_import_menu.data_imported.connect(_on_JSONImportMenu_data_imported)
	json_import_menu.data_cleared.connect(_on_JSONImportMenu_data_cleared)
	tags_menu.frame_selected.connect(_on_TagSelectMenu_frame_selected)
	tags_menu.tag_selected.connect(_on_TagSelectMenu_tag_selected)
	generate_button.pressed.connect(_on_GenerateButton_pressed)
	layers_menu.use_layer_toggled.connect(_on_use_layer_check_button_toggled)


func get_state() -> Dictionary:
	var state := {
		"import_data" : import_data,
		"tags_menu" : tags_menu.get_state(),
		"select_sprite_menu" : select_sprite_menu.get_state(),
		"select_animation_player_menu" : select_animation_player_menu.get_state(),
		"spritesheet_inspector" : spritesheet_inspector.get_state(),
	}
	return state


func set_state(new_state : Dictionary) -> void:
	var json_filepath := ""
	var tags := []
	var selected_tags := []
	var layers := []

	if new_state.get("import_data", false):
		import_data = new_state.import_data
		json_filepath = import_data.json_filepath
		tags = import_data.get_tags()
		spritesheet_inspector.frames = import_data.get_frame_array()
		layers = import_data.get_layers()
	
	else:
		import_data = null
		new_state.erase("tags_menu")

	json_import_menu.set_json_filepath(json_filepath)

	select_sprite_menu.set_state(new_state.get("select_sprite_menu", {}))

	select_animation_player_menu.set_state(new_state.get("select_animation_player_menu", {}))

	spritesheet_inspector.set_state(new_state.get("spritesheet_inspector", {}))

	tags_menu.load_tags(tags)
	tags_menu.set_state(new_state.get("tags_menu", {}))
	
	layers_menu.load_layers(layers)
	select_sprite_menu.load_layers(layers)


func _show_alert(message : String) -> void:
	alert_dialog.dialog_text = message
	alert_dialog.popup_centered()


func _update_theme(editor_theme : EditorTheme) -> void:
	generate_button.icon = editor_theme.get_icon("ImportCheck")
	
	
func update_menus_by_layer_changed() -> void:
	if import_data && layers_menu.get_is_use_layers():
		var layers : Array = import_data.get_layers()
		layers_menu.load_layers(layers)
		select_sprite_menu.load_layers(layers)
	else:
		layers_menu.load_layers([])
		select_sprite_menu.load_layers([])
	
	
func get_frame_idx_by_layer(idx : int) -> int:
	var selected_layer_index = layers_menu.get_selected_layer_index()
	var frame_count_each_layer = import_data.get_frame_count_each_layer(layers_menu.get_is_use_layers())
	var frame_idxs_offset = selected_layer_index * frame_count_each_layer
	#print("idx: ", idx)
	#print("selected_layer_index: ", selected_layer_index)
	#print("offset: ", frame_idxs_offset)
	#print("result: ", idx + frame_idxs_offset)
	return idx + frame_idxs_offset


# Signal Callbacks	
func _on_GenerateButton_pressed() -> void:
	var selected_tags : Array = tags_menu.get_selected_tags()
	var animation_player : AnimationPlayer = select_animation_player_menu.animation_player
	var sprites : Array = select_sprite_menu.saved_sprites
	var texture : Texture = spritesheet_inspector.get_texture()
	var is_use_layers : bool = layers_menu.get_is_use_layers()

	var error := AsepriteImporter.generate_animations(import_data, selected_tags, animation_player, sprites, texture, is_use_layers)

	if error != OK:
		var error_msg : String

		if ERROR_MSG.has(error):
			error_msg = ERROR_MSG[error]
		else:
			error_msg = "An error ocurred!"

		_show_alert(error_msg)
	else:
		emit_signal("animations_generated", animation_player)


func _on_JSONImportMenu_data_imported(new_import_data : AsepriteImportData) -> void:
	import_data = new_import_data

	var tags : Array = import_data.get_tags()
	tags_menu.load_tags(tags)

	var json_filepath := import_data.json_filepath
	var json_dir_path := json_filepath.rsplit("/", true, 1)[0]

	var image_filepath := ""

	var image_filename := import_data.get_image_filename()

	image_filepath = str(json_dir_path, "/", image_filename)

	spritesheet_inspector.texture_size = import_data.get_image_size()
	spritesheet_inspector.frames = import_data.get_frame_array()
	spritesheet_inspector.load_texture(image_filepath)
	
	update_menus_by_layer_changed()
	

func _on_JSONImportMenu_data_cleared() -> void:
	import_data = null

	spritesheet_inspector.clear_texture()
	tags_menu.clear_options()
	layers_menu.load_layers([])
	select_sprite_menu.load_layers([])


func _on_TagSelectMenu_frame_selected(idx : int) -> void:
	spritesheet_inspector.select_frames([get_frame_idx_by_layer(idx)])


func _on_TagSelectMenu_tag_selected(tag_idx : int) -> void:
	var selected_tag := import_data.get_tag(tag_idx)
	var from = get_frame_idx_by_layer(selected_tag.from)
	var to = get_frame_idx_by_layer(selected_tag.to + 1)
	spritesheet_inspector.select_frames(range(from, to))


func _on_use_layer_check_button_toggled(toggled_on):
	update_menus_by_layer_changed()
		

