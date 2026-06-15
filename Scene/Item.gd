# Item.gd
extends Area2D

var dragging := false
var item_id := 1
var item_name := ""
var start_position := Vector2.ZERO
var grid_position := Vector2i.ZERO

func _ready():
	input_pickable = true
	# СБРОС МАСШТАБА: чтобы объект всегда был 1:1 при создании
	scale = Vector2.ONE
	if item_id >= 101:
		update_generator_charge_label("")

func set_item_data(new_item_id: int, new_texture: Texture2D, new_name: String, target_size: float):
	item_id = new_item_id
	item_name = new_name
	$FlowerIcon.texture = new_texture
	if item_id >= 101:
		update_generator_charge_label(get_parent().get_generator_charge_text(item_id) if get_parent().has_method("get_generator_charge_text") else "")
	
	# Масштабируем только иконку
	var tex_size = new_texture.get_size()
	var s = target_size / max(tex_size.x, tex_size.y)
	$FlowerIcon.scale = Vector2(s, s)
	
	# ФИКС КОЛЛИЗИИ: Создаем НОВУЮ форму для каждого предмета, 
	# чтобы они не влияли друг на друга
	if has_node("CollisionShape2D"):
		var new_shape = RectangleShape2D.new()
		
		if item_id >= 101:
			new_shape.size = Vector2(120, 120) # Размер для генератора
		else:
			new_shape.size = Vector2(70, 70)   # Размер для предмета (оптимально для 95 ячейки)
			
		$CollisionShape2D.shape = new_shape

func _process(_delta):
	if dragging:
		global_position = get_global_mouse_position()

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# ЕСЛИ ЭТО МОНЕТКА (ID 50)
			if item_id == 50:
				collect_coin()
				return # Выходим, чтобы не включать dragging

			if item_id < 100:
				dragging = true
				z_index = 1000
			
			if item_id >= 101:
				get_parent().use_generator(self)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and dragging:
			dragging = false
			z_index = 1
			get_parent().item_released(self)

func move_to(target_pos: Vector2):
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.1)
	start_position = target_pos

func return_to_cell():
	move_to(start_position)

func update_home_position():
	start_position = global_position

func set_grid_position(coord: Vector2i):
	grid_position = coord
	start_position = global_position
	
func collect_coin():
	# 1. Защита от двойного клика: выключаем коллизию
	input_pickable = false 
	Global.play_sound("coin")
	# 2. Добавляем деньги в Global
	Global.coins += 250
	Global.save_game()
	
	# Обновляем текст на карте (если мы там)
	if get_parent().has_method("update_ui"):
		get_parent().update_ui()

	# 3. ВИЗУАЛ: Прячем саму иконку монетки сразу
	$FlowerIcon.visible = false
	
	# 4. АНИМАЦИЯ ТЕКСТА
	var label = $CollectLabel # Наш заранее созданный Label
	label.text = "+250 $"
	label.visible = true
	label.modulate.a = 1.0 # Убеждаемся, что он не прозрачный
	label.scale = Vector2(0.5, 0.5) # Начинаем с маленького размера
	
	var tw = create_tween()
	tw.set_parallel(true) # Анимации будут идти одновременно
	
	# Взлет вверх на 100 пикселей
	tw.tween_property(label, "position:y", label.position.y - 100, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Плавное исчезновение (прозрачность в 0)
	tw.tween_property(label, "modulate:a", 0.0, 1.2)
	
	# Увеличение размера (эффект всплытия)
	tw.tween_property(label, "scale", Vector2(1.5, 1.5), 0.4)
	
	# 5. УДАЛЕНИЕ: Когда анимация текста закончилась, удаляем весь Item
	tw.chain().finished.connect(func():
		# Сообщаем сетке, что клетка освободилась (если функция есть в Game.gd)
		if get_parent().has_method("remove_item_from_grid"):
			get_parent().remove_item_from_grid(grid_position)
		queue_free()
	)
	
func update_generator_charge_label(text: String):
	if not has_node("ProgressLabel"):
		return
	var label = $ProgressLabel
	label.visible = item_id >= 101
	label.text = text

func show_generator_cooldown_hint(seconds_left: float):
	spawn_floating_text(Global.loc("shop_repeat_in", {"time": Global.loc("game_seconds_short", {"seconds": int(ceil(seconds_left))})}), Color(1, 0.8, 0.4))

func spawn_floating_text(txt: String, color: Color):
	var label = Label.new()
	label.text = txt
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 24)
	label.z_index = 2000 
	label.global_position = global_position + Vector2(-20, -40)
	get_tree().current_scene.add_child(label)
	
	var tw = create_tween()
	tw.set_parallel(true)
	# Вот тут исправлено:
	tw.tween_property(label, "position:y", label.position.y - 80, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector2(1.5, 1.5), 0.4)
	tw.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)
	
	tw.chain().finished.connect(label.queue_free)
