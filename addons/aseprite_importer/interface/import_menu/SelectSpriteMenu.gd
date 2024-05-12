@tool
extends Container

@onready var buttons_container : Container = $VBoxContainer
@onready var select_node_dialog : Window = $SelectNodeDialog

const SELECT_BUTTON_DEFAULT_TEXT := "Select a Node"

var select_buttons : Array = []
var saved_sprites : Array = []
var layer_names : Array = []
var selected_index : int

var _sprite2d_icon : Texture
var _sprite3d_icon : Texture

const LAYERS_DEFAULT := ["ALL"]

signal node_selected(sprite)

func _ready():
	select_node_dialog.class_filters = ["Sprite2D", "Sprite3D"]
	load_layers(LAYERS_DEFAULT)
	select_node_dialog.node_selected.connect(_on_SelectNodeDialog_node_selected)
	

func load_layers(layers : Array) -> void:
	if layers == null || layers == []:
		layer_names = LAYERS_DEFAULT
	else:
		layer_names = layers

	var using_buttons_count = layer_names.size()
	saved_sprites.clear()
	for button in select_buttons:
		button.get_parent().hide()
		
	for index in using_buttons_count:
		var layer_name = layer_names[index]
		if index < saved_sprites.size():
			saved_sprites[index] = null
		else:
			saved_sprites.append(null)
			
		if index < select_buttons.size():
			var button = select_buttons[index]
			reset_button_view(button, layer_name)
		else:
			var button_group = HBoxContainer.new()
			var button = Button.new()
			var remove_btn = Button.new()
			
			remove_btn.text = "X"
			remove_btn.self_modulate = Color.RED
			remove_btn.pressed.connect(_on_RemoveButton_pressed.bind(index))
			button.pressed.connect(_on_SelectButton_pressed.bind(index))
			
			button_group.add_child(button)
			button_group.add_child(remove_btn)
			buttons_container.add_child(button_group)		
			
			select_buttons.append(button)
			reset_button_view(button, layer_name)


func set_button_text(button : Button, layer_name : StringName, text : StringName) -> void:
	button.text = "[" + layer_name + "]: " + text

func reset_button_view(button : Button, layer_name : StringName) -> void:
	set_button_text(button, layer_name, SELECT_BUTTON_DEFAULT_TEXT)
	button.icon = _sprite2d_icon
	button.get_parent().show()


func get_state() -> Dictionary:
	var state := {}

	if saved_sprites:
		state.sprites = saved_sprites;

	return state


func set_state(new_state : Dictionary) -> void:
	load_layers(LAYERS_DEFAULT)


func _update_theme(editor_theme : EditorTheme) -> void:
	_sprite2d_icon = editor_theme.get_icon("Sprite2D")
	_sprite3d_icon = editor_theme.get_icon("Sprite3D")


# Setters and Getters
func set_sprite(index : int, node : Node) -> void:
	saved_sprites[selected_index] = node
	var layer_name = layer_names[index]
		
	if(node == null):
		reset_button_view(select_buttons[selected_index], layer_name)
		return
	
	var node_path := node.owner.get_parent().get_path_to(node)
	set_button_text(select_buttons[selected_index], layer_name, str(node_path))

	if node.is_class("Sprite2D"):
		select_buttons[selected_index].icon = _sprite2d_icon
	elif node.is_class("Sprite3D"):
		select_buttons[selected_index].icon = _sprite3d_icon

# Signal Callbacks
func _on_SelectButton_pressed(index : int) -> void:
	selected_index = index
	if select_node_dialog.initialize():
		select_node_dialog.popup_centered_ratio(.5)

func _on_RemoveButton_pressed(index : int) -> void:
	set_sprite(index, null)

func _on_SelectNodeDialog_node_selected(selected_node : Node) -> void:
	set_sprite(selected_index, selected_node)
	emit_signal("node_selected", selected_node)
