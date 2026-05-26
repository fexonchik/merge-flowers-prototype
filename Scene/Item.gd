extends Area2D

@export var show_debug_label := false
@export var item_font: Font

var dragging := false

var item_id := 1
var item_name := ""

var start_position := Vector2.ZERO
var grid_position := Vector2i.ZERO

const TARGET_SIZE := 70.0

func _ready():
	update_label()

func set_item_data(new_item_id: int, new_texture: Texture2D, new_name: String, custom_target_size: float = 0.0):
	item_id = new_item_id
	item_name = new_name
	if new_texture == null: return

	$FlowerIcon.texture = new_texture
	
	# Используем переданный размер или стандартный (если забыли передать)
	var final_size = custom_target_size if custom_target_size > 0 else 100.0

	var tex_size = new_texture.get_size()
	var max_side = max(tex_size.x, tex_size.y)
	var scale_factor = final_size / max_side
	$FlowerIcon.scale = Vector2(scale_factor, scale_factor)
	
	update_label()
	
func update_home_position():
	start_position = global_position

# Позволяет менять текст таймера из Game.gd
func set_timer_text(text: String):
	if not has_node("Label"): return
	var l = $Label
	l.visible = text != ""
	l.text = text
	
	if item_font:
		l.add_theme_font_override("font", item_font)
	
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)

func set_grid_position(coord: Vector2i):
	grid_position = coord
	start_position = global_position

func _process(_delta):
	if dragging:
		global_position = get_global_mouse_position()

# Это срабатывает ТОЛЬКО при нажатии на предмет
func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Начинаем тащить, только если это НЕ генератор
			# Если генератор — просто помечаем нажатие, но не включаем dragging
			if item_id < 100:
				dragging = true
				z_index = 1000
			
			# Поглощаем событие, чтобы не кликать сквозь предметы
			get_viewport().set_input_as_handled()

# А это ловит отпускание кнопки В ЛЮБОМ месте экрана (решает залипание)
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			if dragging:
				# Если тащили — отпускаем
				dragging = false
				z_index = 100 + grid_position.x + grid_position.y
				get_parent().item_released(self)
			elif is_mouse_over():
				# Если не тащили (например, это генератор), но отпустили над предметом
				# Это считается за обычный клик
				get_parent().item_released(self)

# Вспомогательная функция, чтобы понять, что мышь над предметом
func is_mouse_over() -> bool:
	var shape = $CollisionShape2D # Убедись, что у тебя так называется узел коллизии
	return get_rect_world().has_point(get_global_mouse_position())

func get_rect_world() -> Rect2:
	# Получаем размеры коллизии для проверки клика
	var shape = $CollisionShape2D.shape
	if shape is RectangleShape2D:
		var size = shape.size * global_scale
		return Rect2(global_position - size / 2, size)
	return Rect2(global_position - Vector2(50,50), Vector2(100,100))

func move_to(target_pos: Vector2):
	var tween := create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.12)
	start_position = target_pos

func return_to_cell():
	move_to(start_position)

func update_label():
	if has_node("Label"):
		$Label.visible = show_debug_label
		$Label.text = str(item_id)
