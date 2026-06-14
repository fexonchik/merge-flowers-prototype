extends TextureRect

@onready var icon = $Icon
@onready var name_label = $NameLabel
@onready var price_label = $PriceLabel
@onready var info_label = $InfoLabel

func setup_item(item_id: int, data: Dictionary):
	name_label.text = data.get("name", "Предмет")
	price_label.text = "Цена: " + str(data.get("price", 0)) + " $"
	info_label.text = "ID: " + str(item_id)
	icon.texture = data.get("texture", null)

func setup_special_item(data: Dictionary):
	name_label.text = data.get("name", "Предмет")
	price_label.text = data.get("price_text", "")
	info_label.text = data.get("description", "")
	icon.texture = data.get("texture", null)

func setup_generator(item_id: int, data: Dictionary):
	var entry := {
		"name": data.get("name", "Генератор"),
		"texture": data.get("texture", null),
		"spawn_list": data.get("spawn_list", []),
		"cooldown": data.get("cooldown", 0),
		"max_charges": data.get("max_charges", 0),
		"description": ""
	}
	_setup_generator_common(item_id, entry)

func setup_generator_entry(data: Dictionary):
	_setup_generator_common(-1, data)

func _setup_generator_common(item_id: int, data: Dictionary):
	name_label.text = data.get("name", "Генератор")
	icon.texture = data.get("texture", null)

	var spawn_names := []
	for spawn_id in data.get("spawn_list", []):
		var spawn_data = Global.items_data.get(int(spawn_id), {})
		spawn_names.append(spawn_data.get("name", str(spawn_id)))

	var info_lines := []
	if item_id >= 0:
		info_lines.append("ID: " + str(item_id))
	info_lines.append("Зарядов: " + str(data.get("max_charges", 0)))
	info_lines.append("КД: " + str(data.get("cooldown", 0)) + " сек.")
	if data.has("spawn_hint"):
		info_lines.append(str(data.get("spawn_hint", "")))
	elif spawn_names.size() > 0:
		info_lines.append("Спавнит: " + ", ".join(spawn_names))
	var description := str(data.get("description", "")).strip_edges()
	if description != "":
		info_lines.append(description)

	price_label.text = ""
	info_label.text = "\n".join(info_lines)
