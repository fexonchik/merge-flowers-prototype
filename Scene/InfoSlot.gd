extends TextureRect

@onready var icon = $Icon
@onready var name_label = $NameLabel
@onready var price_label = $PriceLabel
@onready var info_label = $InfoLabel

func setup_item(item_id: int, data: Dictionary):
	name_label.text = Global.get_localized_item_name(item_id, data)
	price_label.text = Global.loc("ui_price", {"price": data.get("price", 0)})
	info_label.text = Global.loc("label_id", {"id": item_id})
	icon.texture = data.get("texture", null)

func setup_special_item(data: Dictionary):
	name_label.text = str(data.get("name", Global.loc("item_name_default")))
	price_label.text = str(data.get("price_text", ""))
	info_label.text = str(data.get("description", ""))
	icon.texture = data.get("texture", null)

func setup_generator(item_id: int, data: Dictionary):
	var entry := {
		"name": data.get("name", Global.loc("generator_name_default")),
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
	name_label.text = str(data.get("name", Global.loc("generator_name_default")))
	icon.texture = data.get("texture", null)

	var spawn_names := []
	for spawn_id in data.get("spawn_list", []):
		var spawn_data = Global.items_data.get(int(spawn_id), {})
		spawn_names.append(Global.get_localized_item_name(int(spawn_id), spawn_data))

	var info_lines := []
	if item_id >= 0:
		info_lines.append(Global.loc("label_id", {"id": item_id}))
	info_lines.append(Global.loc("ui_charges", {"charges": data.get("max_charges", 0)}))
	info_lines.append(Global.loc("ui_cooldown_seconds", {"seconds": data.get("cooldown", 0)}))
	if data.has("spawn_hint"):
		info_lines.append(str(data.get("spawn_hint", "")))
	elif spawn_names.size() > 0:
		info_lines.append(Global.loc("ui_spawns", {"items": ", ".join(spawn_names)}))
	var description := str(data.get("description", "")).strip_edges()
	if description != "":
		info_lines.append(description)

	price_label.text = ""
	info_label.text = "\n".join(info_lines)
