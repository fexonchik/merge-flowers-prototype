extends CanvasLayer

@export var info_slot_scene: PackedScene
@onready var grid = $TextureRect/ScrollContainer/GridContainer

const SPECIAL_ITEM_ENTRIES := [
	{
		"name": "Монетка",
		"texture": preload("res://Textures/coin_item.png"),
		"price_text": "Даёт: 250 монет",
		"description": "Полезный бонусный предмет. Можно забрать в инвентарь и получить монеты."
	},
	{
		"name": "Кристалл",
		"texture": preload("res://Textures/crystal_item.png"),
		"price_text": "Не продаётся",
		"description": "Редкий ресурс для улучшений и особых покупок. Лучше копить его бережно."
	}
]

const GENERATOR_ENTRIES := [
	{
		"name": "Клумба",
		"texture": preload("res://Textures/gen_meadow.png"),
		"spawn_list": [1, 1, 2],
		"cooldown": 40.0,
		"max_charges": 30,
		"description": "Базовый генератор цветов."
	},
	{
		"name": "Сияющая Клумба",
		"texture": preload("res://Textures/gen_meadow_upgraded.png"),
		"spawn_list": [1, 2, 2],
		"cooldown": 28.0,
		"max_charges": 30,
		"description": "Улучшенная клумба с ускоренным восстановлением."
	},
	{
		"name": "Пруд",
		"texture": preload("res://Textures/gen_pond.png"),
		"spawn_list": [3, 4],
		"cooldown": 90.0,
		"max_charges": 5,
		"description": "Базовый водный генератор редких ростков."
	},
	{
		"name": "Магический Пруд",
		"texture": preload("res://Textures/gen_pond_upgraded.png"),
		"spawn_list": [3, 4, 4],
		"cooldown": 65.0,
		"max_charges": 5,
		"description": "Улучшенный пруд с более выгодным спавном."
	},
	{
		"name": "Древняя Шахта",
		"texture": preload("res://Textures/gen_mine.png"),
		"spawn_list": [],
		"spawn_hint": "Спавнит: секретный предмет",
		"cooldown": 45.0,
		"max_charges": 1,
		"description": "Таинственный генератор, который время от времени приносит редкую находку."
	},
	{
		"name": "Волшебный Лес",
		"texture": preload("res://Textures/gen_forest.png"),
		"spawn_list": [],
		"spawn_hint": "Спавнит: секретный предмет",
		"cooldown": 30.0,
		"max_charges": 1,
		"description": "Загадочное место, где иногда появляется полезный сюрприз."
	}
]

func open_info():
	self.visible = true
	refresh_info()

func refresh_info():
	for child in grid.get_children():
		child.queue_free()

	var flower_ids: Array[int] = []
	for item_id in Global.items_data.keys():
		if item_id >= 1 and item_id <= 10:
			flower_ids.append(item_id)

	flower_ids.sort()

	for item_id in flower_ids:
		var slot = info_slot_scene.instantiate()
		grid.add_child(slot)
		slot.setup_item(item_id, Global.items_data[item_id])

	for special_item_data in SPECIAL_ITEM_ENTRIES:
		var special_slot = info_slot_scene.instantiate()
		grid.add_child(special_slot)
		special_slot.setup_special_item(special_item_data)

	for generator_data in GENERATOR_ENTRIES:
		var slot = info_slot_scene.instantiate()
		grid.add_child(slot)
		slot.setup_generator_entry(generator_data)

func _on_texture_button_pressed():
	self.visible = false
	if get_parent().has_method("show_tutorial"):
		get_parent().show_tutorial()
