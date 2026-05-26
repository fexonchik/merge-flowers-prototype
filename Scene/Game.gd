extends Node2D

# --- ТВОИ ЭКСПОРТЫ ТЕКСТУР ---
@export_group("Items 1-10")
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
@export var texture_barn: Texture2D 

@export_group("Generators")
@export var texture_gen_meadow: Texture2D
@export var texture_gen_pond: Texture2D

@export_group("System")
@export var empty_cell_texture: Texture2D
@export var item_scene: PackedScene
@export var main_font: Font

# --- НОВЫЕ ЭКСПОРТЫ ДЛЯ ОБУЧЕНИЯ ---
@export_group("Tutorial UI")
@export var tutorial_layer: CanvasLayer
@export var tutorial_label: Label
@export var tutorial_arrow: Sprite2D
@export var tutorial_character: TextureRect

@export_group("Tutorial Markers")
@export var point_generator: Marker2D
@export var point_barn: Marker2D
@export var point_seeds: Marker2D

# --- ПЕРЕМЕННЫЕ СОСТОЯНИЯ ---
var shop_actual_pos: Vector2
var coin_label: Label
var stats_label: Label
var grid := []
var items_data := {}
var generators_state := {}
var coins := 0
var improvements_count := 0

# --- ПЕРЕМЕННЫЕ ОБУЧЕНИЯ ---
var tutorial_step := 0
var is_tutorial_active := false

# --- КОНСТАНТЫ СЕТКИ ---
const GRID_SIZE := 6
const CELL_SIZE := 95
const GAP := 8
const START_X := 425
const START_Y := 120
const GRID_ITEM_SIZE := 75.0
const PANEL_ITEM_SIZE := 240.0
const BARN_SIZE := 220.0
const PANEL_X := 250 
const PANEL_START_Y := 120
const PANEL_GAP := 220
const RIGHT_PANEL_X := 1100 
const STATS_START_Y := 200

func _ready():
	randomize()
	setup_items_data()
	create_grid()
	spawn_start_items()
	create_right_panel_ui()
	
	# ЗАПУСК ОБУЧЕНИЯ
	# В будущем тут можно добавить проверку: если обучение уже пройдено, не запускать
	call_deferred("start_tutorial")

# --- ЛОГИКА ОБУЧЕНИЯ ---
func find_item_by_id(id: int):
	for child in get_children():
		if "item_id" in child and child.item_id == id:
			return child
	return null

func start_tutorial():
	is_tutorial_active = true
	tutorial_layer.visible = true
	tutorial_step = 0
	next_tutorial_step()

func next_tutorial_step():
	tutorial_step += 1
	tutorial_arrow.visible = false
	
	match tutorial_step:
		1:
			show_tutorial_text("Привет! Я садовник Боби. Добро пожаловать в твой новый сад!")
		2:
			show_tutorial_text("Давай научимся магии объединения. Видишь две косточки на поле?")
		3:
			show_tutorial_text("Перетащи одну косточку на другую, чтобы вырастить Росток!")
			show_arrow(point_seeds.global_position)
			
		4:
			show_tutorial_text("Здорово! Теперь у тебя есть Росток. Чем выше уровень растения, тем оно дороже.")
		5:
			show_tutorial_text("Но нам нужно больше семян! Нажми на Клумбу слева, чтобы создать их.")
			show_arrow(point_generator.global_position)
			highlight_node(find_item_by_id(101)) 
			
		6:
			show_tutorial_text("Отлично! А теперь давай заработаем монеты. Возьми росток и перенеси его в амбар")
			show_arrow(point_barn.global_position)
			reset_highlights() # Убираем подсветку с генератора
			
		7:
			show_tutorial_text("Ты молодец! Теперь развивай сад, открывай новые цветы и богатей. Удачи!")
			tutorial_arrow.visible = false
		8:
			finish_tutorial()

# Эта функция подсвечивает узел, вынося его над затемнением
func highlight_node(node: Node2D):
	# Сначала сбрасываем всё старое (если было)
	reset_highlights() 
	if node:
		node.z_index = 100 # Выносим над всеми (черный фон тутора обычно имеет z = 0 или меньше)

# Эта функция возвращает всё как было
func reset_highlights():
	# Возвращаем генераторы на место
	for child in get_children():
		if child is Area2D: # Твои предметы и генераторы — это Area2D
			child.z_index = 0

func show_tutorial_text(text: String):
	tutorial_label.text = text
	# Эффект появления текста
	tutorial_label.visible_ratio = 0
	var tw = create_tween()
	tw.tween_property(tutorial_label, "visible_ratio", 1.0, 0.5)

func show_arrow(pos: Vector2):
	tutorial_arrow.visible = true
	tutorial_arrow.global_position = pos + Vector2(0, -50) # Чуть выше объекта
	# Анимация стрелочки
	var tw = create_tween().set_loops()
	tw.tween_property(tutorial_arrow, "position:y", tutorial_arrow.position.y + 20, 0.5)
	tw.tween_property(tutorial_arrow, "position:y", tutorial_arrow.position.y, 0.5)

func finish_tutorial():
	is_tutorial_active = false
	tutorial_layer.visible = false
	# Тут можно сохранить в файл, что обучение пройдено

# --- ОБРАБОТКА КЛИКА ПО ЭКРАНУ (для диалогов) ---
func _input(event):
	if is_tutorial_active and event is InputEventMouseButton and event.pressed:
		# Если сейчас шаги с пояснениями (1, 2, 4, 7), переходим кликом
		if tutorial_step in [1, 2, 4, 7]:
			next_tutorial_step()

# --- ТВОЯ ОСНОВНАЯ ЛОГИКА С ПРАВКАМИ ---

func setup_items_data():
	items_data = {
		1: {"name": "Косточка", "texture": texture_1_seed, "merge_result": 2, "price": 2},
		2: {"name": "Росток", "texture": texture_2_sprout_thin, "merge_result": 3, "price": 5},
		3: {"name": "Листик", "texture": texture_3_leaf, "merge_result": 4, "price": 10},
		4: {"name": "Молодой росток", "texture": texture_4_sprout_soil, "merge_result": 5, "price": 20},
		5: {"name": "Бутон", "texture": texture_5_bud, "merge_result": 6, "price": 40},
		6: {"name": "Цветок", "texture": texture_6_flower, "merge_result": 7, "price": 80},
		7: {"name": "Роза", "texture": texture_7_rose, "merge_result": 8, "price": 150},
		8: {"name": "Пышный куст", "texture": texture_8_bush, "merge_result": 9, "price": 300},
		9: {"name": "Тележка цветов", "texture": texture_9_cart, "merge_result": 10, "price": 700},
		10: {"name": "Машина цветов", "texture": texture_10_truck, "merge_result": -1, "price": 1500},
		
		101: {
			"name": "Клумба", 
			"texture": texture_gen_meadow, 
			"spawn_list": [1, 1, 1, 2],
			"max_charges": 15,
			"recharge_speed": 3.0,
			"merge_result": -1,
			"price": 0
		},
		102: {
			"name": "Пруд", 
			"texture": texture_gen_pond, 
			"spawn_list": [3, 4], 
			"max_charges": 5,
			"recharge_speed": 10.0,
			"merge_result": -1,
			"price": 0
		}
	}

func create_grid():
	grid.clear()
	for x in range(GRID_SIZE):
		grid.append([])
		for y in range(GRID_SIZE):
			grid[x].append({"item": null})
			var tile = Sprite2D.new()
			if empty_cell_texture:
				tile.texture = empty_cell_texture
				var s = float(CELL_SIZE) / tile.texture.get_width()
				tile.scale = Vector2(s, s)
			tile.position = grid_to_screen(Vector2i(x, y))
			tile.z_index = -1
			add_child(tile)

func grid_to_screen(coord: Vector2i) -> Vector2:
	return Vector2(START_X + coord.x * CELL_SIZE, START_Y + coord.y * CELL_SIZE)

func create_right_panel_ui():
	coin_label = Label.new()
	coin_label.text = "МОНЕТЫ: " + str(coins)
	apply_label_style(coin_label, 30)
	coin_label.position = Vector2(RIGHT_PANEL_X - 100, STATS_START_Y)
	add_child(coin_label)
	
	stats_label = Label.new()
	stats_label.text = "УЛУЧШЕНИЙ: " + str(improvements_count)
	apply_label_style(stats_label, 25)
	stats_label.position = Vector2(RIGHT_PANEL_X - 100, STATS_START_Y + 80)
	add_child(stats_label)

func apply_label_style(label: Label, size: int):
	if main_font: label.add_theme_font_override("font", main_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)

func spawn_start_items():
	# Генераторы
	var gen1 = spawn_item(Vector2i(-1, 0), 101)
	gen1.global_position = Vector2(PANEL_X, PANEL_START_Y)
	gen1.update_home_position()
	
	var gen2 = spawn_item(Vector2i(-1, 1), 102)
	gen2.global_position = Vector2(PANEL_X, PANEL_START_Y + PANEL_GAP)
	gen2.update_home_position()
	
	create_shop_ui()

	# Стартовые косточки для обучения
	spawn_item(Vector2i(2, 2), 1)
	spawn_item(Vector2i(3, 2), 1)

func create_shop_ui():
	var shop_icon = Sprite2D.new()
	shop_icon.texture = texture_barn if texture_barn else empty_cell_texture
	var s = BARN_SIZE / shop_icon.texture.get_width()
	shop_icon.scale = Vector2(s, s)
	shop_actual_pos = Vector2(PANEL_X, PANEL_START_Y + PANEL_GAP * 2)
	shop_icon.position = shop_actual_pos
	shop_icon.z_index = -1
	add_child(shop_icon)

func spawn_item(coord: Vector2i, item_id: int):
	if not items_data.has(item_id): return null
	var item = item_scene.instantiate()
	add_child(item)
	var target_size = PANEL_ITEM_SIZE if item_id >= 101 else GRID_ITEM_SIZE
	item.set_item_data(item_id, items_data[item_id]["texture"], items_data[item_id]["name"], target_size)
	
	if coord.x != -1:
		item.global_position = grid_to_screen(coord)
		grid[coord.x][coord.y]["item"] = item
	item.set_grid_position(coord)
	
	if item_id >= 101:
		generators_state[item.get_instance_id()] = {
			"charges": items_data[item_id]["max_charges"],
			"last_recharge_time": Time.get_unix_time_from_system()
		}
	return item

func _process(_delta):
	update_generators_visuals()

func update_generators_visuals():
	var now = Time.get_unix_time_from_system()
	for item_id_key in generators_state.keys():
		var item = instance_from_id(item_id_key)
		if not is_instance_valid(item): continue
		var state = generators_state[item_id_key]
		var data = items_data[item.item_id]
		var elapsed = now - state["last_recharge_time"]
		if elapsed >= data["recharge_speed"] and state["charges"] < data["max_charges"]:
			state["charges"] = min(data["max_charges"], state["charges"] + 1)
			state["last_recharge_time"] = now
		
		if state["charges"] > 0:
			item.modulate = Color(1, 1, 1)
			item.set_timer_text("")
		else:
			item.modulate = Color(0.4, 0.4, 0.4)
			var time_left = int(data["recharge_speed"] - (now - state["last_recharge_time"]))
			item.set_timer_text(str(time_left) + "s")

func use_generator(item):
	# Блокировка: нельзя жать на генератор до 5-го шага обучения
	if is_tutorial_active and tutorial_step < 5: return
	
	var inst_id = item.get_instance_id()
	var state = generators_state[inst_id]
	var data = items_data[item.item_id]
	
	if state["charges"] > 0:
		var empty_cell = find_nearest_empty_cell()
		if empty_cell != Vector2i(-1, -1):
			state["charges"] -= 1
			var spawn_id = data["spawn_list"].pick_random()
			spawn_item(empty_cell, spawn_id)
			
			# ШАГ ТУТОРИАЛА
			if is_tutorial_active and tutorial_step == 5:
				next_tutorial_step()
				
			var tw = create_tween()
			tw.tween_property(item, "scale", item.scale * 0.9, 0.05)
			tw.tween_property(item, "scale", item.scale, 0.1)

func find_nearest_empty_cell() -> Vector2i:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if grid[x][y]["item"] == null: return Vector2i(x, y)
	return Vector2i(-1, -1)

func item_released(item):
	var moved_dist = item.global_position.distance_to(item.start_position)
	if moved_dist < 25: 
		if item.item_id >= 101: use_generator(item)
		item.return_to_cell()
		return

	# ПРОВЕРКА ПРОДАЖИ
	if item.global_position.distance_to(shop_actual_pos) < 130: 
		if item.item_id < 100:
			sell_item(item)
			# ШАГ ТУТОРИАЛА
			if is_tutorial_active and tutorial_step == 6:
				next_tutorial_step()
		else:
			item.return_to_cell()
		return

	var target_coord := get_nearest_cell(item.global_position)
	if is_inside_grid(target_coord):
		var target_item = grid[target_coord.x][target_coord.y]["item"]
		if target_item == null:
			move_item_to_cell(item, item.grid_position, target_coord)
		elif target_item != item and target_item.item_id == item.item_id:
			merge_items(item, target_item, item.grid_position, target_coord)
		else:
			item.return_to_cell()
	else:
		item.return_to_cell()

func merge_items(dragged_item, target_item, old_coord, target_coord):
	var result_id = items_data[dragged_item.item_id]["merge_result"]
	if result_id == -1:
		dragged_item.return_to_cell()
		return
		
	# ШАГ ТУТОРИАЛА
	if is_tutorial_active and tutorial_step == 3:
		next_tutorial_step()
		
	grid[old_coord.x][old_coord.y]["item"] = null
	grid[target_coord.x][target_coord.y]["item"] = null
	dragged_item.queue_free()
	target_item.queue_free()
	call_deferred("spawn_item", target_coord, result_id)

func sell_item(item):
	var price = items_data[item.item_id]["price"]
	coins += price
	update_stats_ui()
	grid[item.grid_position.x][item.grid_position.y]["item"] = null
	item.queue_free()

func update_stats_ui():
	coin_label.text = "МОНЕТЫ: " + str(coins)
	stats_label.text = "УЛУЧШЕНИЙ: " + str(improvements_count)

func move_item_to_cell(item, old_coord, new_coord):
	grid[old_coord.x][old_coord.y]["item"] = null
	grid[new_coord.x][new_coord.y]["item"] = item
	item.set_grid_position(new_coord)
	item.move_to(grid_to_screen(new_coord))

func get_nearest_cell(world_pos: Vector2) -> Vector2i:
	var best_coord := Vector2i(-1, -1)
	var best_distance := INF
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var dist := world_pos.distance_to(grid_to_screen(Vector2i(x, y)))
			if dist < best_distance:
				best_distance = dist
				best_coord = Vector2i(x, y)
	return best_coord

func is_inside_grid(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < GRID_SIZE and coord.y >= 0 and coord.y < GRID_SIZE
