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
@export var ad_confirm_popup: Control
@export var ad_confirm_title_label: Label
@export var ad_confirm_label: Label
@export var ad_confirm_button: Button
@export var ad_cancel_button: Button

@export_group("Tutorial Markers")
@export var point_generator: Marker2D
@export var point_seeds: Marker2D

var grid := []
var barn_pos: Vector2 
var is_tutorial_active := false
var last_empty_generator_id := -1
var last_empty_generator_tap_time := -100.0
var last_empty_generator_hint_time := -100.0
var last_generator_ad_popup_time := -100.0
var pending_rewarded_ad_type := ""

const EMPTY_GENERATOR_DOUBLE_TAP_WINDOW := 3.0
const EMPTY_GENERATOR_HINT_COOLDOWN := 30.0
const GENERATOR_AD_POPUP_COOLDOWN := 30.0

# Константы сетки
const GRID_SIZE := 6
const CELL_SIZE := 110
const START_X := 335
const START_Y := 85
const GRID_ITEM_SIZE := 85.0
const PANEL_ITEM_SIZE := 225.0 

func _ready():
	randomize()
	pending_rewarded_ad_type = ""
	if ad_confirm_popup:
		ad_confirm_popup.visible = false
	if not Global.is_connected("language_changed", _on_language_changed):
		Global.language_changed.connect(_on_language_changed)
	if Global.session_started_at <= 0.0:
		Global.session_started_at = Time.get_unix_time_from_system()
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

	if not Ads.rewarded_ad_completed.is_connected(_on_rewarded_ad_completed):
		Ads.rewarded_ad_completed.connect(_on_rewarded_ad_completed)

	apply_ad_confirm_localization()

	if not Global.is_tutorial_done:
		call_deferred("start_tutorial")
	else:
		if tutorial_layer: tutorial_layer.visible = false

func _process(_delta):
	var now = Time.get_unix_time_from_system()
	refresh_generator_charges(now)

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

func show_temporary_bobby_hint(text: String, duration: float = 3.0):
	if not tutorial_layer:
		return
	if ad_confirm_popup:
		ad_confirm_popup.visible = false
	update_bobby(text)
	var expected_text = text
	var tutorial_was_active = is_tutorial_active and not Global.is_tutorial_done
	get_tree().create_timer(duration).timeout.connect(func():
		if not is_instance_valid(self) or not tutorial_layer or not tutorial_label:
			return
		if tutorial_label.text != expected_text:
			return
		if tutorial_was_active:
			update_bobby(Global.get_bobby_text("Game"))
		else:
			tutorial_layer.visible = false
	)

func maybe_show_empty_generator_bobby_hint(item_id: int):
	if Global.is_tutorial_done == false and int(Global.tutorial_step) < 10:
		return
	var now = Time.get_unix_time_from_system()
	var is_second_tap = item_id == last_empty_generator_id and now - last_empty_generator_tap_time <= EMPTY_GENERATOR_DOUBLE_TAP_WINDOW
	last_empty_generator_id = item_id
	last_empty_generator_tap_time = now
	if not is_second_tap:
		return
	if now - last_empty_generator_hint_time < EMPTY_GENERATOR_HINT_COOLDOWN:
		return
	last_empty_generator_hint_time = now
	var generator_name_key := "generator_name_default"
	match item_id:
		101:
			generator_name_key = "meadow_name"
		102:
			generator_name_key = "pond_name"
	var generator_name = Global.loc(generator_name_key).to_lower()
	show_temporary_bobby_hint(Global.loc("game_generator_empty_hint", {"generator": generator_name}), 3.5)

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
			update_bobby(Global.loc("game_need_more_seeds", {"count": 3 - count}))
		return
	if Global.active_quests.size() > 0:
		var q = Global.active_quests[0]
		var cur = Global.get_item_count_in_inventory(int(q["require_id"]))
		if cur >= int(q["require_count"]): update_bobby(Global.loc("game_order_ready"), "happy")

func _input(event):
	if is_tutorial_active and event is InputEventMouseButton and event.pressed:
		var step = int(Global.tutorial_step)
		if step in [1, 3, 4, 6]: next_tutorial_step()

func start_tutorial():
	var step = int(Global.tutorial_step)
	if Global.is_tutorial_done or step >= 11:
		is_tutorial_active = false
		if tutorial_layer:
			tutorial_layer.visible = false
		if tutorial_arrow:
			tutorial_arrow.visible = false
		return
	is_tutorial_active = true
	if step <= 1:
		Global.tutorial_step = 1
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
	var tutorial_seed_recovery: bool = is_tutorial_active and item.item_id == 101 and step >= 2 and step < 8 and needs_tutorial_seed_recovery()
	if is_tutorial_active and not step in [2, 5] and not tutorial_seed_recovery: return
	if not has_generator_charge(item.item_id):
		Global.play_sound("error")
		if item.has_method("show_generator_cooldown_hint"):
			item.show_generator_cooldown_hint(get_generator_time_left(item.item_id))
		if item.item_id in [101, 102] and Global.can_claim_generator_ad(item.item_id) and can_show_generator_ad_popup():
			show_generator_ad_confirm(item.item_id)
		else:
			pending_rewarded_ad_type = ""
			maybe_show_empty_generator_bobby_hint(item.item_id)
		return
	var empty_cell = find_nearest_empty_cell()
	if empty_cell != Vector2i(-1, -1):
		consume_generator_charge(item.item_id)
		Global.play_sound("spawn")
		var spawn_id = 1 if (is_tutorial_active and item.item_id == 101 and step < 8) else Global.items_data[item.item_id]["spawn_list"].pick_random()
		spawn_item(empty_cell, spawn_id)
		if item.has_method("update_generator_charge_label"):
			item.update_generator_charge_label(get_generator_charge_text(item.item_id))
		if is_tutorial_active and (step == 2 or step == 5): next_tutorial_step()
		elif tutorial_seed_recovery:
			refresh_tutorial_after_seed_spawn()
		save_current_grid(); Global.save_game()

func format_seconds_to_mmss(seconds: float) -> String:
	var total_seconds = int(ceil(seconds))
	var minutes = total_seconds / 60
	var secs = total_seconds % 60
	return "%02d:%02d" % [minutes, secs]

func get_generator_ad_reward_amount(gen_id: int) -> int:
	match gen_id:
		101:
			return 10
		102:
			return 2
	return 0

func get_generator_name_key(gen_id: int) -> String:
	match gen_id:
		101:
			return "meadow_name"
		102:
			return "pond_name"
	return "generator_name_default"

func get_generator_ad_confirm_text(gen_id: int) -> String:
	var generator_name = Global.loc(get_generator_name_key(gen_id))
	var charges = get_generator_ad_reward_amount(gen_id)
	return Global.loc("game_generator_ad_confirm", {
		"generator": generator_name
	}) + "\n" + Global.loc("game_generator_ad_reward_line", {
		"generator": generator_name,
		"charges": charges
	})

func apply_ad_confirm_localization():
	if ad_confirm_title_label:
		ad_confirm_title_label.text = Global.loc("game_generator_ad_title")
	if ad_confirm_button:
		ad_confirm_button.text = Global.loc("game_generator_ad_button_confirm")
	if ad_cancel_button:
		ad_cancel_button.text = Global.loc("game_generator_ad_button_cancel")

func can_show_generator_ad_popup() -> bool:
	return Time.get_unix_time_from_system() - last_generator_ad_popup_time >= GENERATOR_AD_POPUP_COOLDOWN

func show_generator_ad_confirm(gen_id: int):
	last_generator_ad_popup_time = Time.get_unix_time_from_system()
	pending_rewarded_ad_type = "generator_" + str(gen_id)
	apply_ad_confirm_localization()
	if ad_confirm_label:
		ad_confirm_label.text = get_generator_ad_confirm_text(gen_id)
	if ad_confirm_popup:
		ad_confirm_popup.visible = true

func hide_generator_ad_confirm():
	if ad_confirm_popup:
		ad_confirm_popup.visible = false
	if ad_confirm_label:
		ad_confirm_label.text = ""

func request_rewarded_ad(reward_type: String):
	if reward_type == "generator_101" and not Global.can_claim_generator_ad(101):
		pending_rewarded_ad_type = ""
		hide_generator_ad_confirm()
		return
	if reward_type == "generator_102" and not Global.can_claim_generator_ad(102):
		pending_rewarded_ad_type = ""
		hide_generator_ad_confirm()
		return
	hide_generator_ad_confirm()
	Ads.show_rewarded_ad(reward_type)

func grant_ad_reward(reward_type: String):
	if reward_type == "generator_101":
		add_generator_charges(101, 10)
		Global.mark_generator_ad_claimed(101)
		show_temporary_bobby_hint(Global.loc("game_ad_reward_meadow"), 2.5)
	elif reward_type == "generator_102":
		add_generator_charges(102, 2)
		Global.mark_generator_ad_claimed(102)
		show_temporary_bobby_hint(Global.loc("game_ad_reward_pond"), 2.5)

func _on_rewarded_ad_completed(reward_type: String):
	if reward_type != pending_rewarded_ad_type:
		return
	pending_rewarded_ad_type = ""
	grant_ad_reward(reward_type)

func _on_rewarded_ad_failed(reward_type: String):
	if reward_type != pending_rewarded_ad_type:
		return
	pending_rewarded_ad_type = ""
	hide_generator_ad_confirm()

func _on_ad_confirm_button_pressed():
	if pending_rewarded_ad_type.is_empty():
		return
	request_rewarded_ad(pending_rewarded_ad_type)

func _on_ad_cancel_button_pressed():
	pending_rewarded_ad_type = ""
	hide_generator_ad_confirm()

func _on_language_changed(_new_language):
	apply_ad_confirm_localization()
	if ad_confirm_popup and ad_confirm_popup.visible and pending_rewarded_ad_type.begins_with("generator_"):
		var gen_id = int(pending_rewarded_ad_type.trim_prefix("generator_"))
		if ad_confirm_label:
			ad_confirm_label.text = get_generator_ad_confirm_text(gen_id)

func add_generator_charges(gen_id: int, amount: int):
	if not Global.generator_states.has(gen_id):
		return
	var state = Global.generator_states[gen_id]
	var max_charges = int(Global.items_data[gen_id].get("max_charges", state.get("max_charges", 1)))
	state["max_charges"] = max_charges
	state["charges"] = min(max_charges, int(state.get("charges", 0)) + amount)
	if int(state["charges"]) >= max_charges:
		state["last_charge_time"] = Time.get_unix_time_from_system()
	refresh_generator_visuals()
	Global.save_game()

func item_released(item):
	var item_id = int(item.item_id)
	var home_pos = grid_to_screen(item.grid_position)
	
	# 1. ПРОВЕРКА НА КЛИК (Только для монет ID 50)
	# Если это монетка и ее почти не сдвинули — собираем по клику
	if item_id == 50 and item.global_position.distance_to(home_pos) < 20:
		collect_to_inventory(item)
		return

	# 2. ПРОВЕРКА НА ПОДНОС К АМБАРУ (Для всех предметов, включая Кристалл 60)
	if item.global_position.distance_to(barn_pos) < 100:
		if item_id < 100: 
			collect_to_inventory(item)
		else: 
			item.return_to_cell()
		return

	# 3. ЛОГИКА СЕТКИ (Перемещение и мердж)
	var target_coord = get_nearest_cell(item.global_position)
	if is_inside_grid(target_coord):
		var target_idx = target_coord.y * GRID_SIZE + target_coord.x + 1
		if target_idx > Global.unlocked_cells: 
			item.return_to_cell()
			return
			
		var target_item = grid[target_coord.x][target_coord.y]["item"]
		
		if target_item == null: 
			move_item(item, item.grid_position, target_coord)
		elif target_item != item and int(target_item.item_id) == item_id: 
			merge_items(item, target_item, target_coord)
		else: 
			item.return_to_cell()
	else: 
		item.return_to_cell()

func merge_items(dragged, target, coord):
	var next_id = Global.items_data[dragged.item_id]["merge_result"]
	if next_id == -1: dragged.return_to_cell(); return
	Global.play_sound("merge")
	grid[dragged.grid_position.x][dragged.grid_position.y]["item"] = null
	grid[coord.x][coord.y]["item"] = null
	dragged.queue_free(); target.queue_free(); spawn_item(coord, next_id)
	refresh_tutorial_after_seed_merge()
	save_current_grid(); Global.save_game()

func collect_to_inventory(item):
	var item_id = int(item.item_id)
	var is_needed = false
	
	for q in Global.active_quests:
		if int(q["require_id"]) == item_id: 
			is_needed = true
			break
	
	# Условие сбора: уровень 3+, квест, монета или кристалл
	if item_id >= 3 or is_needed or item_id == 50 or item_id == 60:
		if Global.add_to_inventory(item_id):
			
			# РАЗДЕЛЯЕМ ЗВУКИ:
			if item_id == 50:
				Global.play_sound("coin")     # Звук звона монет для ID 50
			else:
				Global.play_sound("collect")  # Звук сбора для кристаллов (60) и прочего
			
			grid[item.grid_position.x][item.grid_position.y]["item"] = null
			
			var tw = create_tween()
			tw.set_parallel(true)
			tw.tween_property(item, "global_position", barn_pos, 0.3)
			tw.tween_property(item, "scale", Vector2.ZERO, 0.3)
			tw.finished.connect(item.queue_free)
			
			save_current_grid()
			Global.save_game()
		else:
			Global.play_sound("error") 
			shake_barn_icon()
			item.return_to_cell()
	else:
		Global.play_sound("error")
		show_temporary_bobby_hint(Global.loc("game_item_too_small"), 1.8)
		item.return_to_cell()

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
			if child.has_method("update_generator_charge_label"):
				child.update_generator_charge_label(get_generator_charge_text(child.item_id))

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
	pending_rewarded_ad_type = ""
	hide_generator_ad_confirm()
	save_current_grid()
	if Global.get_item_count_in_inventory(1) >= 3 and int(Global.tutorial_step) < 8: Global.tutorial_step = 8
	Global.save_game()
	Global.play_sound("click")
	get_tree().change_scene_to_file("res://Scene/WorldMap.tscn")

func remove_item_from_grid(coord: Vector2i):
	if is_inside_grid(coord):
		grid[coord.x][coord.y]["item"] = null
		save_current_grid(); Global.save_game()

# Функция спавна стартовых предметов (те самые 1-2 косточки в начале)
func spawn_start_items():
	# Оставляем одну косточку (ID 1) в центре, чтобы игрок начал туториал
	spawn_item(Vector2i(2, 1), 1)

func needs_tutorial_seed_recovery() -> bool:
	var step = int(Global.tutorial_step)
	if Global.is_tutorial_done or step < 2 or step >= 8:
		return false
	var quest_requires_seeds := false
	if not Global.active_quests.is_empty():
		var quest = Global.active_quests[0]
		quest_requires_seeds = int(quest.get("require_id", -1)) == 1 and int(quest.get("require_count", 0)) >= 3
	if not quest_requires_seeds:
		return false
	var total_seeds = Global.get_item_count_in_inventory(1) + count_items_on_field(1)
	return total_seeds < 3

func count_items_on_field(item_id: int) -> int:
	var count := 0
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var cell = grid[x][y]["item"]
			if cell and int(cell.item_id) == item_id:
				count += 1
	return count

func refresh_tutorial_after_seed_spawn():
	if not is_tutorial_active or Global.is_tutorial_done:
		return
	var step = int(Global.tutorial_step)
	if step >= 2 and step < 8 and needs_tutorial_seed_recovery():
		if tutorial_arrow and point_generator:
			show_arrow(point_generator.global_position)
		update_bobby(Global.loc("game_need_more_seeds", {"count": 3 - (Global.get_item_count_in_inventory(1) + count_items_on_field(1))}))
		return
	if step >= 2 and step < 8:
		Global.tutorial_step = 7
		Global.save_game()
		if tutorial_arrow:
			tutorial_arrow.visible = false
		show_arrow(barn_pos)
		update_bobby(Global.get_bobby_text("Game"), "happy")

func refresh_tutorial_after_seed_merge():
	if not is_tutorial_active or Global.is_tutorial_done:
		return
	var step = int(Global.tutorial_step)
	if step >= 2 and step < 8 and needs_tutorial_seed_recovery():
		if tutorial_arrow and point_generator:
			show_arrow(point_generator.global_position)
		update_bobby(Global.loc("game_need_more_seeds", {"count": 3 - (Global.get_item_count_in_inventory(1) + count_items_on_field(1))}))


func refresh_generator_charges(now: float):
	for gen_id in Global.generator_states.keys():
		var state = Global.generator_states[gen_id]
		var max_charges = int(Global.items_data[gen_id].get("max_charges", state.get("max_charges", 1)))
		state["max_charges"] = max_charges
		if int(state["charges"]) >= max_charges:
			state["charges"] = max_charges
			state["last_charge_time"] = now
			continue
		var cooldown = get_generator_cooldown(gen_id)
		var elapsed = now - float(state["last_charge_time"])
		if elapsed < cooldown:
			continue
		var restored = int(floor(elapsed / cooldown))
		if restored <= 0:
			continue
		state["charges"] = min(max_charges, int(state["charges"]) + restored)
		state["last_charge_time"] = now - fmod(elapsed, cooldown)
	for child in get_children():
		if child.has_method("update_generator_charge_label") and child.item_id >= 101:
			child.update_generator_charge_label(get_generator_charge_text(child.item_id))

func has_generator_charge(gen_id: int) -> bool:
	if not Global.generator_states.has(gen_id):
		return true
	return int(Global.generator_states[gen_id]["charges"]) > 0

func consume_generator_charge(gen_id: int):
	if not Global.generator_states.has(gen_id):
		return
	var state = Global.generator_states[gen_id]
	var max_charges = int(Global.items_data[gen_id].get("max_charges", state.get("max_charges", 1)))
	if int(state["charges"]) == max_charges:
		state["last_charge_time"] = Time.get_unix_time_from_system()
	state["charges"] = max(0, int(state["charges"]) - 1)

func get_generator_time_left(gen_id: int) -> float:
	if not Global.generator_states.has(gen_id):
		return 0.0
	var state = Global.generator_states[gen_id]
	if int(state["charges"]) > 0:
		return 0.0
	var cooldown = get_generator_cooldown(gen_id)
	var elapsed = Time.get_unix_time_from_system() - float(state["last_charge_time"])
	return max(0.0, cooldown - elapsed)

func get_generator_charge_text(gen_id: int) -> String:
	if not Global.generator_states.has(gen_id):
		return ""
	var state = Global.generator_states[gen_id]
	var charges = int(state["charges"])
	var max_charges = int(Global.items_data[gen_id].get("max_charges", state.get("max_charges", 1)))
	if charges > 0:
		return str(charges) + "/" + str(max_charges)
	var seconds_left = int(ceil(get_generator_time_left(gen_id)))
	return Global.loc("game_seconds_short", {"seconds": seconds_left})

func get_generator_cooldown(gen_id: int) -> float:
	var base_cooldown = float(Global.items_data[gen_id].get("cooldown", 1.0))
	if is_onboarding_boost_active():
		return max(1.0, base_cooldown * 0.5)
	return base_cooldown

func is_onboarding_boost_active() -> bool:
	if Global.session_started_at <= 0.0:
		return false
	return Time.get_unix_time_from_system() - Global.session_started_at < 600.0

func _on_settings_button_pressed():
	# 1. Прячем туториал, если он активен, чтобы не мешал
	Global.play_sound("click")
	if tutorial_layer:
		tutorial_layer.visible = false
	
	# 2. Вызываем настройки через уникальное имя (%)
	# Если ты поставил галочку в редакторе, это сработает из любого места дерева
	var settings = get_node_or_null("%SettingsUI")
	
	if settings:
		settings.open_settings()
	else:
		# Если вдруг забыл поставить %, попробуем найти просто поиском
		var backup_settings = find_child("SettingsUI", true)
		if backup_settings:
			backup_settings.open_settings()
		else:
			print("Ошибка: Узел SettingsUI не найден в сцене Game! Проверь имя или поставь %")
