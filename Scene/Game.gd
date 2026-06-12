extends Node2D

# --- ЭКСПОРТЫ ТЕКСТУР ---
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
@export var texture_gen_meadow: Texture2D
@export var texture_gen_pond: Texture2D
@export var empty_cell_texture: Texture2D
@export var locked_cell_texture: Texture2D # Спрайт заблокированной ячейки
@export var item_scene: PackedScene

@export_group("Tutorial UI")
@export var tutorial_layer: CanvasLayer
@export var tutorial_label: Label
@export var tutorial_arrow: Sprite2D
@export var bobby_character: TextureRect # Узел с Боби

@export_group("Tutorial Markers")
@export var point_generator: Marker2D
@export var point_seeds: Marker2D

# --- ПЕРЕМЕННЫЕ СОСТОЯНИЯ ---
var grid := []
var barn_pos: Vector2 
var is_tutorial_active := false

var coin_timer := 0.0
var crystal_timer := 0.0

# --- КОНСТАНТЫ СЕТКИ ---
const GRID_SIZE := 6
const CELL_SIZE := 105
const START_X := 355
const START_Y := 95
const GRID_ITEM_SIZE := 80.0
const PANEL_ITEM_SIZE := 210.0 

func _process(delta):
	# РАБОТА ЛЕСА (Монеты)
	if Global.forest_unlocked:
		coin_timer += delta
		if coin_timer >= 45.0: # Раз в 35 сек
			coin_timer = 0.0
			if not has_item_on_field(50): # 50 - ID монетки
				var cell = find_nearest_empty_cell()
				if cell != Vector2i(-1, -1): spawn_item(cell, 50)

	# РАБОТА ШАХТЫ (Кристаллы)
	if Global.mine_unlocked:
		crystal_timer += delta
		if crystal_timer >= 75.0: # Раз в 45 сек
			crystal_timer = 0.0
			if not has_item_on_field(60): # 60 - ID кристалла
				var cell = find_nearest_empty_cell()
				if cell != Vector2i(-1, -1): spawn_item(cell, 60)

func _ready():
	randomize()
	setup_textures_in_global()
	create_grid()
	
	# Подключаем Боби к изменениям инвентаря
	if not Global.is_connected("inventory_changed", _on_inventory_changed):
		Global.inventory_changed.connect(_on_inventory_changed)
	
	# Позиция рюкзака
	if has_node("BarnIcon"):
		barn_pos = $BarnIcon.global_position

	# Загрузка поля
	if Global.saved_grid.size() > 0:
		load_saved_grid()
		spawn_generators_only() 
	else:
		spawn_start_items()

	# Проверка туториала
	if Global.is_tutorial_done == false:
		call_deferred("start_tutorial")
	else:
		if tutorial_layer: tutorial_layer.visible = false

# --- ЛОГИКА БОББИ ---
func update_bobby(text: String, _mood: String = ""):
	if not tutorial_layer: return
	tutorial_layer.visible = true
	
	if tutorial_label:
		tutorial_label.text = text
		tutorial_label.visible_ratio = 0
		var tw = create_tween()
		tw.tween_property(tutorial_label, "visible_ratio", 1.0, 0.4)
	
	if bobby_character:
		bobby_character.texture = Global.bobby_texture
		bobby_character.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bobby_character.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _on_inventory_changed():
	if Global.is_tutorial_done:
		if tutorial_layer: tutorial_layer.visible = false
		return

	# ПРОВЕРКА ДЛЯ ТУТОРИАЛА (Листики)
	if Global.tutorial_step >= 7 and Global.tutorial_step < 10:
		var count = Global.get_item_count_in_inventory(3)
		if count >= 3:
			# Если собрали 3 листика, ставим шаг 8
			if Global.tutorial_step == 7:
				Global.tutorial_step = 8
				Global.save_game()
			update_bobby("Всё собрано! Теперь выходи на карту и иди к ВОРОТАМ.", "happy")
			return 
		else:
			# Если вдруг листиков стало меньше 3 (выложил случайно)
			Global.tutorial_step = 7
			update_bobby("Нам нужно 3 Листика. Собери еще " + str(3 - count) + " шт.")
			return

	# Логика для обычных квестов (после туториала)
	if Global.active_quests.size() > 0:
		if tutorial_layer: tutorial_layer.visible = false
		return

	# 4. Логика для остальных квестов (старая)
	var q = Global.active_quests[0]
	var current = Global.get_item_count_in_inventory(q["require_id"])
	var needed = q["require_count"]
	var item_name = Global.items_data[q["require_id"]]["name"]

	if current < needed:
		update_bobby("Нам нужно " + item_name + ". Собери еще " + str(needed - current) + " шт.")
	else:
		update_bobby("Заказ на " + item_name + " готов! Скорее беги к воротам!", "happy")

# --- ТУТОРИАЛ ---
func start_tutorial():
	is_tutorial_active = true
	if Global.tutorial_step == 0:
		Global.tutorial_step = 1
	next_tutorial_step(true)

func next_tutorial_step(resume = false):
	if not resume:
		Global.tutorial_step += 1
	
	if tutorial_arrow: tutorial_arrow.visible = false
	
	match Global.tutorial_step:
		1: update_bobby("Давай поработаем!")
		2: update_bobby("Соедини две косточки, чтобы получить Росток.")
		3: 
			if has_item_on_field(2): # Если росток уже есть
				Global.tutorial_step = 4
				next_tutorial_step(true)
			else:
				show_arrow(point_seeds.global_position if point_seeds else Vector2(500, 300))
		4: update_bobby("Здорово! Но этого мало. Нам нужно выполнить заказ у ворот.")
		5:
			update_bobby("Нажми на Клумбу, чтобы получить еще семян.")
			show_arrow(point_generator.global_position if point_generator else Vector2(150, 150))
		6: update_bobby("Соединяй ростки, пока не получишь Листики (ур. 3)!")
		7:
			update_bobby("Теперь перенеси Листик в рюкзак. Нам нужно 3 штуки!")
			show_arrow(barn_pos)

func show_arrow(pos: Vector2):
	if tutorial_arrow:
		tutorial_arrow.visible = true
		tutorial_arrow.global_position = pos + Vector2(0, -50)

# --- ВЗАИМОДЕЙСТВИЕ ---

func collect_to_inventory(item):
	var is_needed = false
	for q in Global.active_quests:
		if q["require_id"] == item.item_id:
			is_needed = true
			break
	
	if item.item_id >= 3 or is_needed:
		if Global.inventory.size() < Global.max_inventory_slots:
			grid[item.grid_position.x][item.grid_position.y]["item"] = null
			Global.add_to_inventory(item.item_id)
			
					# ИСПОЛЬЗУЕМ СИГНАЛЫ
			Global.item_collected.emit(item.item_id)
			Global.inventory_updated.emit(Global.inventory.size())
			#АВТОСОХРАНЕНИЕ
			save_current_grid()
			Global.save_game()
			
			var tw = create_tween()
			tw.set_parallel(true)
			tw.tween_property(item, "global_position", barn_pos, 0.3)
			tw.tween_property(item, "scale", Vector2.ZERO, 0.3)
			tw.chain().finished.connect(item.queue_free)
		else:
			shake_barn_icon()
			item.return_to_cell()
	else:
		# ПРЕДМЕТ СЛИШКОМ МАЛ
		update_bobby("Этот предмет еще слишком мал для рюкзака!")
		item.return_to_cell()
		
		# Если туториал УЖЕ закончен, Боби просто дает подсказку и уходит через 2 сек
		if Global.is_tutorial_done:
			# Создаем таймер на 2 секунды
			get_tree().create_timer(2.0).timeout.connect(func():
				# Прячем Боби, если за эти 2 секунды туториал не начался заново (на всякий случай)
				if Global.is_tutorial_done and tutorial_layer:
					tutorial_layer.visible = false
			)

func item_released(item):
	if item.global_position.distance_to(barn_pos) < 100:
		if item.item_id < 100: collect_to_inventory(item)
		else: item.return_to_cell()
		return

	var target_coord = get_nearest_cell(item.global_position)
	if is_inside_grid(target_coord):
		# Проверка на заблокированные ячейки
		var target_index = target_coord.y * GRID_SIZE + target_coord.x + 1
		if target_index > Global.unlocked_cells:
			item.return_to_cell()
			return

		var target_item = grid[target_coord.x][target_coord.y]["item"]
		if target_item == null:
			move_item(item, item.grid_position, target_coord)
		elif target_item != item and target_item.item_id == item.item_id:
			merge_items(item, target_item, target_coord)
		else:
			item.return_to_cell()
	else:
		item.return_to_cell()

func merge_items(dragged, target, coord):
	var next_id = Global.items_data[dragged.item_id]["merge_result"]
	if next_id == -1:
		dragged.return_to_cell()
		return
	
	# Очистка старых данных
	grid[dragged.grid_position.x][dragged.grid_position.y]["item"] = null
	grid[coord.x][coord.y]["item"] = null
	
	# Анимация и удаление
	var tw = create_tween()
	tw.tween_property(target, "scale", Vector2.ZERO, 0.1)
	dragged.queue_free()
	target.queue_free()
	
	# Спавн нового
	spawn_item(coord, next_id)
	
		# ИСПОЛЬЗУЕМ СИГНАЛ (убираем желтую ошибку)
	Global.item_merged.emit(next_id)
	
	# АВТОСОХРАНЕНИЕ
	save_current_grid()
	Global.save_game()
	
	# Продвигаем туториал
	if is_tutorial_active:
		if next_id == 2 and Global.tutorial_step <= 3:
			Global.tutorial_step = 3
			next_tutorial_step()
		elif next_id == 3 and Global.tutorial_step <= 6:
			Global.tutorial_step = 6
			next_tutorial_step()
	
	Global.check_quest_progress("merge", next_id)

func use_generator(item):
	if is_tutorial_active and Global.tutorial_step < 5: return 
	var empty_cell = find_nearest_empty_cell()
	if empty_cell != Vector2i(-1, -1):
		# Если место есть — спавним
		var data = Global.items_data[item.item_id]
		spawn_item(empty_cell, data["spawn_list"].pick_random())
		
				# АВТОСОХРАНЕНИЕ: Сразу записываем новое семечко в файл
		save_current_grid()
		Global.save_game()
		
		# Анимация клика по генератору
		var tw = create_tween()
		tw.tween_property(item, "scale", item.scale * 1.1, 0.05)
		tw.tween_property(item, "scale", item.scale, 0.05)
		
		if is_tutorial_active and Global.tutorial_step == 5: 
			next_tutorial_step()
	else:
		# Если места НЕТ — трясем генератор или пишем в консоль
		print("Нет свободного места на открытой территории!")
		shake_generator(item)

# Маленькая функция для тряски генератора, если места нет
func shake_generator(item):
	var tw = create_tween()
	var pos = item.global_position
	tw.tween_property(item, "global_position", pos + Vector2(5, 0), 0.05)
	tw.tween_property(item, "global_position", pos - Vector2(5, 0), 0.05)
	tw.tween_property(item, "global_position", pos, 0.05)

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
			tile.centered = true
			tile.set_meta("is_tile", true)
			if empty_cell_texture:
				tile.scale = Vector2(float(CELL_SIZE)/empty_cell_texture.get_width(), float(CELL_SIZE)/empty_cell_texture.get_width())
			tile.position = grid_to_screen(Vector2i(x, y))
			tile.z_index = -1
			add_child(tile)
			
			if cell_count > Global.unlocked_cells:
				if locked_cell_texture:
					var lock = Sprite2D.new()
					lock.texture = locked_cell_texture
					lock.centered = true
					lock.position = Vector2.ZERO # Точно в центре
					
					# --- НАСТРОЙКА РАЗМЕРА ТУТ ---
					# Вариант 1: Просто поставить 1.0 (оригинальный размер картинки)
					# lock.scale = Vector2(1.0, 1.0) 
					
					# Вариант 2: Авто-подгон под размер ячейки (95 пикселей)
					# Мы делим размер ячейки на ширину твоей картинки замка
					var lock_size = float(CELL_SIZE) / locked_cell_texture.get_width()
					
					# Умножь на 0.8, если хочешь, чтобы были небольшие отступы, 
					# или на 1.0, чтобы замок был впритык к краям ячейки
					var final_scale = lock_size * 2.4
					lock.scale = Vector2(final_scale, final_scale)
					
					tile.add_child(lock)

func spawn_item(coord: Vector2i, item_id: int):
	if not Global.items_data.has(item_id): return null
	var item = item_scene.instantiate()
	add_child(item)
	
	var data = Global.items_data[item_id]
	# ТУТ ВАЖНО: берем data["texture"], которую мы подменили в Global
	var t_size = PANEL_ITEM_SIZE if item_id >= 101 else GRID_ITEM_SIZE
	item.set_item_data(item_id, data["texture"], data["name"], t_size)
	if coord.x != -1:
		item.global_position = grid_to_screen(coord)
		grid[coord.x][coord.y]["item"] = item
	item.set_grid_position(coord)
	return item

func get_nearest_cell(pos: Vector2) -> Vector2i:
	var x = int(round((pos.x - START_X) / CELL_SIZE))
	var y = int(round((pos.y - START_Y) / CELL_SIZE))
	return Vector2i(x, y)

func grid_to_screen(coord: Vector2i) -> Vector2:
	return Vector2(START_X + coord.x * CELL_SIZE, START_Y + coord.y * CELL_SIZE)

func is_inside_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < GRID_SIZE and c.y >= 0 and c.y < GRID_SIZE

func find_nearest_empty_cell() -> Vector2i:
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			# Считаем индекс текущей клетки
			var cell_index = y * GRID_SIZE + x + 1
			
			# Проверяем ДВА условия: 
			# 1. Клетка пустая
			# 2. Клетка РАЗБЛОКИРОВАНА
			if grid[x][y]["item"] == null and cell_index <= Global.unlocked_cells:
				return Vector2i(x, y)
				
	return Vector2i(-1, -1) # Если свободных открытых клеток нет

func move_item(item, old_coord, new_coord):
	grid[old_coord.x][old_coord.y]["item"] = null
	grid[new_coord.x][new_coord.y]["item"] = item
	item.set_grid_position(new_coord)
	item.move_to(grid_to_screen(new_coord))
	
		# АВТОСОХРАНЕНИЕ
	save_current_grid()
	Global.save_game()

# --- ВСПОМОГАТЕЛЬНЫЕ ---

# Game.gd

func setup_textures_in_global():
	var d = Global.items_data
	
	# Цветы 1-10 записываем всегда
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

	# ГЕНЕРАТОРЫ:
	# Если апгрейд НЕ куплен, ставим обычную текстуру из инспектора Game
	if not Global.meadow_upgraded:
		d[101]["texture"] = texture_gen_meadow
	# Если куплен — НИЧЕГО НЕ ДЕЛАЕМ (там уже лежит картинка из Global.apply_upgraded_textures)

	if not Global.pond_upgraded:
		d[102]["texture"] = texture_gen_pond

func spawn_generators_only():
	# Очистка (чтобы не дублировались)
	for child in get_children():
		if child.has_method("set_item_data") and child.item_id >= 101:
			child.queue_free()

	# 1. Клумба
	var g1 = spawn_item(Vector2i(-1, -1), 101)
	if has_node("GeneratorPos"): g1.global_position = $GeneratorPos.global_position
	g1.update_home_position()

	# 2. Пруд
	var g2 = spawn_item(Vector2i(-1, -1), 102)
	if has_node("GeneratorPos2"): g2.global_position = $GeneratorPos2.global_position
	g2.update_home_position()

func spawn_start_items():
	spawn_item(Vector2i(2, 2), 1)
	spawn_item(Vector2i(3, 2), 1)
	spawn_generators_only()

func has_item_on_field(id: int) -> bool:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell = grid[x][y]["item"]
			if cell and cell.item_id == id: return true
	return false

func load_saved_grid():
	for data in Global.saved_grid: spawn_item(Vector2i(data["x"], data["y"]), data["id"])

func save_current_grid():
	Global.saved_grid.clear()
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell = grid[x][y]["item"]
			if cell and cell.item_id < 100:
				Global.saved_grid.append({"x": x, "y": y, "id": cell.item_id})

func shake_barn_icon():
	if has_node("BarnIcon"):
		var tw = create_tween()
		tw.tween_property($BarnIcon, "position:x", $BarnIcon.position.x + 10, 0.05)
		tw.tween_property($BarnIcon, "position:x", $BarnIcon.position.x - 10, 0.05)
		tw.tween_property($BarnIcon, "position:x", $BarnIcon.position.x, 0.05)

func _input(event):
	if is_tutorial_active and event is InputEventMouseButton and event.pressed:
		if Global.tutorial_step in [1, 4]: next_tutorial_step()

func _on_back_button_pressed():
	save_current_grid()
	get_tree().change_scene_to_file("res://Scene/WorldMap.tscn")

# Добавь эту функцию в любое место Game.gd
func refresh_generator_visuals():
	for child in get_children():
		if child.has_method("set_item_data") and child.item_id >= 101:
			# Обновляем текстуру из Global
			var data = Global.items_data[child.item_id]
			var icon = child.get_node_or_null("FlowerIcon")
			if icon:
				icon.texture = data["texture"]

func try_spawn_auto_coin():
	# 1. Проверяем, есть ли уже монетка на поле
	if has_item_on_field(50):
		return # Если монетка есть, новую не создаем

	# 2. Проверяем, стоит ли сам Лес на поле
	# (Если у тебя гены всегда на поле, то просто ищем пустую клетку)
	var empty_cell = find_nearest_empty_cell()
	if empty_cell != Vector2i(-1, -1):
		spawn_item(empty_cell, 50)
		print("Лес создал монетку!")
		
func remove_item_from_grid(coord: Vector2i):
	if is_inside_grid(coord):
		grid[coord.x][coord.y]["item"] = null
		save_current_grid()
		Global.save_game()
		
func try_spawn_crystal():
	# Ограничение: не более 1 кристалла на поле одновременно
	if has_item_on_field(60): return 
	
	var empty_cell = find_nearest_empty_cell()
	if empty_cell != Vector2i(-1, -1):
		spawn_item(empty_cell, 60)
		print("Шахта выдала кристалл!")
