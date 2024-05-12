@tool
extends Container

@onready var use_layer_toggle : CheckButton = $CenterContainer/UseLayerCheckButton
@onready var layer_checkbox_container := $ScrollContainer/HBoxContainer

var using_button_group : ButtonGroup

signal use_layer_toggled(bool)
signal checkbox_pressed(CheckBox)

func _ready():
	using_button_group = ButtonGroup.new()
	load_layers([])

func load_layers(layers : Array) -> void:
	var layer_names =[]
	if layers == null:
		layer_names = []
	else:
		layer_names = layers

	var using_checkboxes = layer_checkbox_container.get_children()
	for checkbox : CheckBox in using_checkboxes:
		checkbox.set_pressed_no_signal(false)
		checkbox.hide()
		
	for i in layers.size():
		var layer_name = layers[i]
		if i >= using_checkboxes.size():
			create_layer_checkbox(layer_name)
		else:
			set_layer_checkbox(using_checkboxes[i], layer_name)
	
	for checkbox : CheckBox in layer_checkbox_container.get_children():
		checkbox.set_pressed_no_signal(true)
		break
	
func create_layer_checkbox(layer_name : StringName) -> void:
	var new_checkbox = CheckBox.new()
	layer_checkbox_container.add_child(new_checkbox)
	new_checkbox.pressed.connect(_on_checkbox_pressed.bind(new_checkbox))
	set_layer_checkbox(new_checkbox, layer_name)


func set_layer_checkbox(checkbox : CheckBox, layer_name : StringName) -> void:
	checkbox.set_pressed_no_signal(false)
	checkbox.button_group = using_button_group
	checkbox.text = layer_name
	checkbox.show()


func get_selected_layer_index() -> int:
	var checkboxs = layer_checkbox_container.get_children()
	for index in checkboxs.size():
		var checkbox : CheckBox = checkboxs[index]
		if checkbox.button_pressed:
			return index
	return 0


func get_is_use_layers() -> bool:
	return use_layer_toggle.button_pressed


func _on_use_layer_check_button_toggled(toggled_on):
	use_layer_toggled.emit(toggled_on)


func _on_checkbox_pressed(checkbox : CheckBox):
	checkbox_pressed.emit(checkbox)

