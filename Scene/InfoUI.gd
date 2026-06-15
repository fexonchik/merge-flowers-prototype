extends CanvasLayer

@export var info_slot_scene: PackedScene
@onready var grid = $TextureRect/ScrollContainer/GridContainer

const SPECIAL_ITEM_ENTRIES := [
	{
		"texture": preload("res://Textures/coin_item.png"),
		"name_key": "coin_name",
		"price_text_key": "info_coin_price_text",
		"description_key": "info_coin_description"
	},
	{
		"texture": preload("res://Textures/crystal_item.png"),
		"name_key": "crystal_name",
		"price_text_key": "info_crystal_price_text",
		"description_key": "info_crystal_description"
	}
]

const GENERATOR_ENTRIES := [
	{
		"name_key": "meadow_name",
		"texture": preload("res://Textures/gen_meadow.png"),
		"spawn_list": [1, 1, 2],
		"cooldown": 40.0,
		"max_charges": 30,
		"description_key": "info_gen_meadow_description"
	},
	{
		"name_key": "shop_item_up_meadow",
		"texture": preload("res://Textures/gen_meadow_upgraded.png"),
		"spawn_list": [1, 2, 2],
		"cooldown": 28.0,
		"max_charges": 30,
		"description_key": "info_gen_meadow_upgraded_description"
	},
	{
		"name_key": "pond_name",
		"texture": preload("res://Textures/gen_pond.png"),
		"spawn_list": [3, 4],
		"cooldown": 90.0,
		"max_charges": 5,
		"description_key": "info_gen_pond_description"
	},
	{
		"name_key": "shop_item_up_pond",
		"texture": preload("res://Textures/gen_pond_upgraded.png"),
		"spawn_list": [3, 4, 4],
		"cooldown": 65.0,
		"max_charges": 5,
		"description_key": "info_gen_pond_upgraded_description"
	},
	{
		"name_key": "shop_item_buy_mine",
		"texture": preload("res://Textures/gen_mine.png"),
		"spawn_list": [],
		"spawn_hint_key": "info_gen_mine_spawn_hint",
		"cooldown": 45.0,
		"max_charges": 1,
		"description_key": "info_gen_mine_description"
	},
	{
		"name_key": "shop_item_buy_forest",
		"texture": preload("res://Textures/gen_forest.png"),
		"spawn_list": [],
		"spawn_hint_key": "info_gen_forest_spawn_hint",
		"cooldown": 30.0,
		"max_charges": 1,
		"description_key": "info_gen_forest_description"
	}
]

func _ready():
	if not Global.is_connected("language_changed", _on_language_changed):
		Global.language_changed.connect(_on_language_changed)

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
		special_slot.setup_special_item(_build_special_item_entry(special_item_data))

	for generator_data in GENERATOR_ENTRIES:
		var slot = info_slot_scene.instantiate()
		grid.add_child(slot)
		slot.setup_generator_entry(_build_generator_entry(generator_data))

func _build_special_item_entry(data: Dictionary) -> Dictionary:
	return {
		"name": Global.loc(str(data.get("name_key", "item_name_default"))),
		"texture": data.get("texture", null),
		"price_text": Global.loc(str(data.get("price_text_key", ""))),
		"description": Global.loc(str(data.get("description_key", "")))
	}

func _build_generator_entry(data: Dictionary) -> Dictionary:
	var entry := data.duplicate(true)
	entry["name"] = Global.loc(str(data.get("name_key", "generator_name_default")))
	if data.has("spawn_hint_key"):
		entry["spawn_hint"] = Global.loc(str(data.get("spawn_hint_key", "")))
	entry["description"] = Global.loc(str(data.get("description_key", "")))
	return entry

func _on_language_changed(_new_language):
	if visible:
		refresh_info()

func _on_texture_button_pressed():
	self.visible = false
	if get_parent().has_method("show_tutorial"):
		get_parent().show_tutorial()
