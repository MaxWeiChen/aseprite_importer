@tool
extends Container


@onready var select_all_button : CheckBox = get_node("%SelectAllButton")
@onready var tree : Tree = $Tree


enum Columns {
	SELECTED,
	NAME,
	START,
	END,
	DIRECTION,
}


var _tree_root : TreeItem
var _options := []
var _toggling_option := false


signal frame_selected(idx)
signal selected_tags_changed(selected_tags)
signal tag_selected(tag_name)


func _ready():
	clear_options()

	tree.columns = Columns.size()

	tree.set_column_expand(Columns.SELECTED, false)
	tree.set_column_custom_minimum_width(Columns.SELECTED, 32)

	tree.set_column_title(Columns.NAME, "Name")
	tree.set_column_expand(Columns.NAME, true)
	tree.set_column_custom_minimum_width(Columns.START, 48)

	tree.set_column_title(Columns.START, "Start")
	tree.set_column_expand(Columns.START, false)
	tree.set_column_custom_minimum_width(Columns.START, 48)

	tree.set_column_title(Columns.END, "End")
	tree.set_column_expand(Columns.END, false)
	tree.set_column_custom_minimum_width(Columns.END, 48)

	tree.set_column_title(Columns.DIRECTION, "Direction")
	tree.set_column_expand(Columns.DIRECTION, false)
	tree.set_column_custom_minimum_width(Columns.DIRECTION, 84)

	tree.set_column_titles_visible(true)
	
	select_all_button.toggled.connect(_on_SelectAllButton_toggled)
	tree.cell_selected.connect(_on_Tree_cell_selected)
	tree.item_edited.connect(_on_Tree_item_edited)


func clear_options() -> void:
	select_all_button.hide()

	for option in _options:
		option.free()
	_options.clear()

	tree.clear()

	_tree_root = tree.create_item()


func load_tags(tags : Array) -> void:
	clear_options()

	if tags == []:
		return

	for tag in tags:
		var new_tree_item := tree.create_item(_tree_root)

		new_tree_item.set_cell_mode(Columns.SELECTED, TreeItem.CELL_MODE_CHECK)
		new_tree_item.set_editable(Columns.SELECTED, true)
		new_tree_item.set_checked(Columns.SELECTED, true)
		new_tree_item.set_selectable(Columns.SELECTED, false)

		new_tree_item.set_text(Columns.NAME, tag.name)

		new_tree_item.set_text(Columns.START, str(floor(tag.from)))
		new_tree_item.set_text_alignment(Columns.START, HORIZONTAL_ALIGNMENT_CENTER)

		new_tree_item.set_text(Columns.END, str(floor(tag.to)))
		new_tree_item.set_text_alignment(Columns.END, HORIZONTAL_ALIGNMENT_CENTER)

		new_tree_item.set_text(Columns.DIRECTION, "  %s" % tag.direction)
		new_tree_item.set_selectable(Columns.DIRECTION, false)

		_options.append(new_tree_item)

	select_all_button.set_pressed_no_signal(true)
	select_all_button.show()


func get_selected_tags() -> Array:
	var selected_tags := []

	for i in range(_options.size()):
		var item : TreeItem = _options[i]
		if item.is_checked(Columns.SELECTED):
			selected_tags.append(i)

	return selected_tags


func get_state() -> Dictionary:
	var state := {
		selected_tags = get_selected_tags()
	}

	var selected_item := tree.get_selected()
	if selected_item != null:
		var selected_column := tree.get_selected_column()

		var item_idx := _options.find(selected_item)

		state.selected_cell = Vector2(selected_column, item_idx)

	return state


func set_state(new_state : Dictionary) -> void:
	if new_state.has("selected_tags") and _options != []:
		select_all_button.set_pressed_no_signal(false)

		for tag in new_state.selected_tags:
			_options[tag].set_checked(Columns.SELECTED, true)

		if new_state.has("selected_cell"):
			var selected_cell : Vector2 = new_state.selected_cell
			var tree_item : TreeItem = _options[selected_cell.y]
			var column : int = selected_cell.x

			tree_item.select(column)

			match column:
				Columns.NAME:
					tag_selected.emit(selected_cell.y)
				Columns.START, Columns.END:
					frame_selected.emit(tree_item.get_text(column).to_int())


		for option in _options:
			if not option.is_checked(Columns.SELECTED):
				return

		_toggling_option = true
		select_all_button.set_pressed_no_signal(true)
		_toggling_option = false


# Signal Callbacks
func _on_SelectAllButton_toggled(button_pressed : bool) -> void:
	if _toggling_option:
		return

	for option in _options:
		option.set_checked(Columns.SELECTED, button_pressed)

	selected_tags_changed.emit(get_selected_tags())


func _on_Tree_cell_selected() -> void:
	var selected_column := tree.get_selected_column()
	var selected_item := tree.get_selected()

	match selected_column:
		Columns.NAME:
			tag_selected.emit(_options.find(selected_item))
		Columns.START, Columns.END:
			frame_selected.emit(selected_item.get_text(selected_column).to_int())


func _on_Tree_item_edited() -> void:
	_toggling_option = true

	if select_all_button.pressed:
		for option in _options:
			if option.is_checked(Columns.SELECTED):
				select_all_button.set_pressed_no_signal(false)
				break
	else:
		var is_all_selected := true
		for option in _options:
			if not option.is_checked(Columns.SELECTED):
				is_all_selected = false
				break

		if is_all_selected:
			select_all_button.set_pressed_no_signal(true)

	_toggling_option = false

	emit_signal("selected_tags_changed", get_selected_tags())
