# Game.gd
extends Node2D

@export_group("Items Textures")
@export var texture_1_seed: Texture2D
@export var texture_2_sprout_thin: Texture2D
@export var texture_3_leaf: Texture2D
@export var texture_4_sprout_soil: Texture2D
@export var texture_5_bud: Texture2D
@export var texture_6_flower: Texture2D
@export var texture_7_rose: Texture2D
@export var texture_8_bush: Texture2D
@export var texture_9_cart: Texture2D
@export var texture_10_truck: Texture2D
@export var empty_cell_texture: Texture2D
@export var locked_cell_texture: Texture2D
@export var item_scene: PackedScene

@export_group("Tutorial UI")
@export var tutorial_layer: CanvasLayer
@export var tutorial_label: Label
@export var tutorial_arrow: Sprite2D
@export var bobby_character: TextureRect 

@export_group("Tutorial Markers")
@export var point_generator: Marker2D
@export var point_seeds: Marker2D

var grid := []
var barn_pos: Vector2 
var is_tutorial_active := false

# Константы сетки
const GRID_SIZE := 6
const CELL_SIZE := 110
const START_X := 335
const START_Y := 85
const GRID_ITEM_SIZE := 85.0
const PANEL_ITEM_SIZE := 225.0 

func _ready():
	randomize()
	setup_textures_in_global()
	create_grid()
	
	if not Global.is_connected("inventory_changed", _on_inventory_changed):
		Global.inventory_changed.connect(_on_inventory_changed)
	
	if has_node("BarnIcon"):
		barn_pos = $BarnIcon.global_position

	if Global.saved_grid.size() > 0 or Global.tutorial_step > 1:
		load_saved_grid() 
	else:
		spawn_start_items()
		save_current_grid()
		Global.save_game()
	
	spawn_generators_only()
	check_offline_production()

	if not Global.is_tutorial_done:
		call_deferred("start_tutorial")
	else:
		if tutorial_layer: tutorial_layer.visible = false

func _process(_delta):
	var now = Time.get_unix_time_from_system()

	# ЛЕС (Авто-монеты)
	if Global.forest_unlocked:
		if now - Global.last_coin_time >= 30.0:
			if not has_item_on_field(50):
				var cell = find_nearest_empty_cell()
				if cell != Vector2i(-1, -1): spawn_item(cell, 50)
			Global.last_coin_time = now
			Global.save_game()

	# ШАХТА (Авто-кристаллы)
	if Global.mine_unlocked:
		if now - Global.last_crystal_time >= 45.0:
			if not has_item_on_field(60):
				var cell = find_nearest_empty_cell()
				if cell != Vector2i(-1, -1): spawn_item(cell, 60)
			Global.last_crystal_time = now
			Global.save_game()

	if tutorial_layer:
		$TutorialLayer/DialogueBox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$TutorialLayer/TutorialCharacter.mouse_filter = Control.MOUSE_FILTER_IGNORE

func check_offline_production():
	var now = Time.get_unix_time_from_system()
	if Global.forest_unlocked and not has_item_on_field(50):
		if now - Global.last_coin_time >= 30.0:
			var cell = find_nearest_empty_cell()
			if cell != Vector2i(-1, -1): spawn_item(cell, 50); Global.last_coin_time = now
	
	if Global.mine_unlocked and not has_item_on_field(60):
		if now - Global.last_crystal_time >= 45.0:
			var cell = find_nearest_empty_cell()
			if cell != Vector2i(-1, -1): spawn_item(cell, 60); Global.last_crystal_time = now

func setup_textures_in_global():
	var d = Global.items_data
	d[1]["texture"] = texture_1_seed
	d[2]["texture"] = texture_2_sprout_thin
	d[3]["texture"] = texture_3_leaf
	d[4]["texture"] = texture_4_sprout_soil
	d[5]["texture"] = texture_5_bud
	d[6]["texture"] = texture_6_flower
	d[7]["texture"] = texture_7_rose
	d[8]["texture"] = texture_8_bush
	d[9]["texture"] = texture_9_cart
	d[10]["texture"] = texture_10_truck
	# Генераторы 101 и 102 отсюда УДАЛЕНЫ, чтобы не затирать апгрейды

func update_bobby(text: String, _mood: String = ""):
	if not tutorial_layer: return
	tutorial_layer.visible = true
	if tutorial_label:
		tutorial_label.text = text
		tutorial_label.visible_ratio = 0
		create_tween().tween_property(tutorial_label, "visible_ratio", 1.0, 0.4)
	if bobby_character: bobby_character.texture = Global.bobby_texture

func _on_inventory_changed():
	if Global.is_tutorial_done:
		if tutorial_layer: tutorial_layer.visible = false
		return
	var step = int(Global.tutorial_step)
	if step >= 7 and step < 10:
		var count = Global.get_item_count_in_inventory(1)
		if count >= 3:
			Global.tutorial_step = 8; Global.save_game()
			update_bobby(Global.get_bobby_text("Game"), "happy")
		else:
			update_bobby("Нужно еще " + str(3 - count) + " косточки.")
		return
	if Global.active_quests.size() > 0:
		var q = Global.active_quests[0]
		var cur = Global.get_item_count_in_inventory(int(q["require_id"]))
		if cur >= int(q["require_count"]): update_bobby("Заказ готов! Иди к воротам!", "happy")

func _input(event):
	if is_tutorial_active and event is InputEventMouseButton and event.pressed:
		var step = int(Global.tutorial_step)
		if step in [1, 3, 4, 6]: next_tutorial_step()

func start_tutorial():
	is_tutorial_active = true
	if int(Global.tutorial_step) <= 1: Global.tutorial_step = 1
	update_bobby(Global.get_bobby_text("Game"))

func next_tutorial_step():
	Global.tutorial_step += 1; Global.save_game()
	if tutorial_arrow: tutorial_arrow.visible = false
	update_bobby(Global.get_bobby_text("Game"))
	var step = int(Global.tutorial_step)
	if step in [2, 5]: show_arrow(point_generator.global_position if point_generator else Vector2(150, 150))
	elif step == 7: show_arrow(barn_pos)

func show_arrow(pos: Vector2):
	if tutorial_arrow:
		tutorial_arrow.visible = true
		tutorial_arrow.global_position = pos + Vector2(0, -50)

func use_generator(item):
	var step = int(Global.tutorial_step)
	if is_tutorial_active and not step in [2, 5]: return 
	var empty_cell = find_nearest_empty_cell()
	if empty_cell != Vector2i(-1, -1):
		var spawn_id = 1 if is_tutorial_active else Global.items_data[item.item_id]["spawn_list"].pick_random()
		spawn_item(empty_cell, spawn_id)
		if is_tutorial_active and (step == 2 or step == 5): next_tutorial_step()
		save_current_grid(); Global.save_game()

func item_released(item):
	if item.global_position.distance_to(barn_pos) < 100:
		if item.item_id < 100: collect_to_inventory(item)
		else: item.return_to_cell()
		return
	var target_coord = get_nearest_cell(item.global_position)
	if is_inside_grid(target_coord):
		var target_idx = target_coord.y * GRID_SIZE + target_coord.x + 1
		if target_idx > Global.unlocked_cells: item.return_to_cell(); return
		var target_item = grid[target_coord.x][target_coord.y]["item"]
		if target_item == null: move_item(item, item.grid_position, target_coord)
		elif target_item != item and target_item.item_id == item.item_id: merge_items(item, target_item, target_coord)
		else: item.return_to_cell()
	else: item.return_to_cell()

func merge_items(dragged, target, coord):
	var next_id = Global.items_data[dragged.item_id]["merge_result"]
	if next_id == -1: dragged.return_to_cell(); return
	grid[dragged.grid_position.x][dragged.grid_position.y]["item"] = null
	grid[coord.x][coord.y]["item"] = null
	dragged.queue_free(); target.queue_free(); spawn_item(coord, next_id)
	save_current_grid(); Global.save_game()

func collect_to_inventory(item):
	var is_needed = false
	for q in Global.active_quests:
		if int(q["require_id"]) == item.item_id: is_needed = true; break
	if item.item_id >= 3 or is_needed:
		if Global.add_to_inventory(item.item_id):
			grid[item.grid_position.x][item.grid_position.y]["item"] = null
			var tw = create_tween()
			tw.set_parallel(true)
			tw.tween_property(item, "global_position", barn_pos, 0.3)
			tw.tween_property(item, "scale", Vector2.ZERO, 0.3)
			tw.finished.connect(item.queue_free)
			save_current_grid(); Global.save_game()
		else:
			shake_barn_icon(); item.return_to_cell()
	else:
		update_bobby("Этот предмет еще слишком мал!"); item.return_to_cell()

func create_grid():
	for child in get_children():
		if child is Sprite2D and child.has_meta("is_tile"): child.queue_free()
	grid = []
	for x in range(GRID_SIZE):
		grid.append([])
		for y in range(GRID_SIZE): grid[x].append({"item": null})
	var cell_count = 0
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			cell_count += 1
			var tile = Sprite2D.new()
			tile.texture = empty_cell_texture
			tile.centered = true; tile.set_meta("is_tile", true)
			if empty_cell_texture:
				var s = float(CELL_SIZE) / empty_cell_texture.get_width()
				tile.scale = Vector2(s, s)
			tile.position = grid_to_screen(Vector2i(x, y))
			tile.z_index = -1; add_child(tile)
			if cell_count > Global.unlocked_cells:
				if locked_cell_texture:
					var lock = Sprite2D.new()
					lock.texture = locked_cell_texture
					lock.position = Vector2.ZERO
					var lock_s = (empty_cell_texture.get_width() / locked_cell_texture.get_width()) * 2.0
					lock.scale = Vector2(lock_s, lock_s)
					tile.add_child(lock)

func spawn_item(coord: Vector2i, item_id: int):
	if not Global.items_data.has(int(item_id)): return null
	var item = item_scene.instantiate()
	add_child(item)
	var data = Global.items_data[int(item_id)]
	var t_size = PANEL_ITEM_SIZE if item_id >= 101 else GRID_ITEM_SIZE
	item.set_item_data(item_id, data["texture"], data["name"], t_size)
	if coord.x != -1:
		item.global_position = grid_to_screen(coord)
		grid[coord.x][coord.y]["item"] = item
	item.set_grid_position(coord)
	return item

func get_nearest_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(round((pos.x - START_X) / CELL_SIZE)), int(round((pos.y - START_Y) / CELL_SIZE)))

func grid_to_screen(coord: Vector2i) -> Vector2:
	return Vector2(START_X + coord.x * CELL_SIZE, START_Y + coord.y * CELL_SIZE)

func is_inside_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < GRID_SIZE and c.y >= 0 and c.y < GRID_SIZE

func find_nearest_empty_cell() -> Vector2i:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var idx = y * GRID_SIZE + x + 1
			if grid[x][y]["item"] == null and idx <= Global.unlocked_cells: return Vector2i(x, y)
	return Vector2i(-1, -1)

func has_item_on_field(id: int) -> bool:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell = grid[x][y]["item"]
			if cell and cell.item_id == id: return true
	return false

func spawn_generators_only():
	for child in get_children():
		if child.has_method("set_item_data") and child.item_id >= 101: child.queue_free()
	var g1 = spawn_item(Vector2i(-1, -1), 101)
	if has_node("GeneratorPos"): g1.global_position = $GeneratorPos.global_position
	g1.update_home_position()
	var g2 = spawn_item(Vector2i(-1, -1), 102)
	if has_node("GeneratorPos2"): g2.global_position = $GeneratorPos2.global_position
	g2.update_home_position()

func refresh_generator_visuals():
	for child in get_children():
		if child.has_method("set_item_data") and child.item_id >= 101:
			var icon = child.get_node_or_null("FlowerIcon")
			if icon: icon.texture = Global.items_data[child.item_id]["texture"]

func load_saved_grid():
	for data in Global.saved_grid: spawn_item(Vector2i(data["x"], data["y"]), data["id"])

func save_current_grid():
	Global.saved_grid.clear()
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell = grid[x][y]["item"]
			if cell and cell.item_id < 100: Global.saved_grid.append({"x": x, "y": y, "id": cell.item_id})

func move_item(item, old_coord, new_coord):
	grid[old_coord.x][old_coord.y]["item"] = null
	grid[new_coord.x][new_coord.y]["item"] = item
	item.set_grid_position(new_coord)
	item.move_to(grid_to_screen(new_coord))
	save_current_grid(); Global.save_game()

func shake_barn_icon():
	if has_node("BarnIcon"):
		var tw = create_tween()
		tw.tween_property($BarnIcon, "position:x", $BarnIcon.position.x + 10, 0.05)
		tw.tween_property($BarnIcon, "position:x", $BarnIcon.position.x - 10, 0.05)
		tw.tween_property($BarnIcon, "position:x", $BarnIcon.position.x, 0.05)

func _on_back_button_pressed():
	save_current_grid()
	if Global.get_item_count_in_inventory(1) >= 3 and int(Global.tutorial_step) < 8: Global.tutorial_step = 8
	Global.save_game()
	get_tree().change_scene_to_file("res://Scene/WorldMap.tscn")

func remove_item_from_grid(coord: Vector2i):
	if is_inside_grid(coord):
		grid[coord.x][coord.y]["item"] = null
		save_current_grid(); Global.save_game()

# Функция спавна стартовых предметов (те самые 1-2 косточки в начале)
func spawn_start_items():
	# Оставляем одну косточку (ID 1) в центре, чтобы игрок начал туториал
	spawn_item(Vector2i(2, 1), 1)
