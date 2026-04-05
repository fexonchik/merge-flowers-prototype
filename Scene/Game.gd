extends Node2D

@export var item_scene: PackedScene

@export var pink_texture: Texture2D
@export var red_texture: Texture2D
@export var pinkred_texture: Texture2D

var items_data = {}

func _ready():
	setup_items_data()
	spawn_start_items()

func setup_items_data():
	items_data = {
		1: {
			"name": "Pink",
			"texture": pink_texture,
			"merge_result": 2
		},
		2: {
			"name": "Red",
			"texture": red_texture,
			"merge_result": 3
		},
		3: {
			"name": "PinkRed",
			"texture": pinkred_texture,
			"merge_result": -1
		}
	}

func spawn_start_items():
	var start_x = 140
	var start_y = 140
	var cell_size = 120

	for row in range(3):
		for col in range(3):
			var pos = Vector2(
				start_x + col * cell_size,
				start_y + row * cell_size
			)
			spawn_item(pos, 1)

func spawn_item(pos: Vector2, item_id: int):
	var item = item_scene.instantiate()
	add_child(item)
	item.global_position = pos
	item.set_item_data(item_id, items_data[item_id]["texture"])

func merge_items(dragged_item, target_item):
	if not is_instance_valid(dragged_item) or not is_instance_valid(target_item):
		return

	if dragged_item == target_item:
		return

	if dragged_item.item_id != target_item.item_id:
		return

	var result_id = items_data[dragged_item.item_id]["merge_result"]

	if result_id == -1:
		# Нечего мержить дальше
		dragged_item.return_to_start()
		return

	# Новый цветок появляется НА МЕСТЕ ЦЕЛИ
	var spawn_pos = target_item.global_position

	dragged_item.queue_free()
	target_item.queue_free()

	call_deferred("spawn_item", spawn_pos, result_id)
	
func _on_menu_button_pressed():
	get_tree().change_scene_to_file("res://Scene/MainMenu.tscn")

func _on_readme_button_pressed():
	$CanvasLayer/ReadmePanel.visible = true

func _on_close_button_pressed():
	$CanvasLayer/ReadmePanel.visible = false
