extends Area2D

var dragging := false
var item_id := 1

var start_position := Vector2.ZERO
var drag_start_mouse_pos := Vector2.ZERO
var moved_enough := false

func _ready():
	update_label()

func set_item_data(new_item_id: int, new_texture: Texture2D):
	item_id = new_item_id
	$FlowerIcon.texture = new_texture
	update_label()

func _process(_delta):
	if dragging:
		global_position = get_global_mouse_position()

func _input_event(viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Начинаем drag только для этого конкретного цветка
			dragging = true
			moved_enough = false
			start_position = global_position
			drag_start_mouse_pos = get_global_mouse_position()
			z_index = 1000

			# Чтобы событие не улетало в другие цветки под ним
			viewport.set_input_as_handled()

		else:
			# ВАЖНО:
			# отпускание обрабатывает только тот цветок, который реально тащили
			if not dragging:
				return

			dragging = false
			z_index = 0

			if get_global_mouse_position().distance_to(drag_start_mouse_pos) > 10.0:
				moved_enough = true

			if moved_enough:
				var merged = try_merge()
				if not merged:
					return_to_start()
			else:
				return_to_start()

			viewport.set_input_as_handled()

func try_merge() -> bool:
	var targets = get_overlapping_areas()

	for area in targets:
		if area == self:
			continue

		if not area.has_method("get_item_id"):
			continue

		if area.item_id == item_id:
			get_parent().merge_items(self, area)
			return true

	return false

func return_to_start():
	var tween = create_tween()
	tween.tween_property(self, "global_position", start_position, 0.12)

func get_item_id():
	return item_id

func update_label():
	if has_node("Label"):
		$Label.text = str(item_id)
