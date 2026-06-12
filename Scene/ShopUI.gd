extends CanvasLayer

@export var shop_slot_scene: PackedScene 
@onready var grid = $TextureRect/ScrollContainer/GridContainer

func open_shop():
	self.visible = true
	refresh_shop()

func refresh_shop():
	for child in grid.get_children():
		child.queue_free()
	
	var items = Global.shop_items.duplicate()
	
	# СОРТИРОВКА: Купленные улетают вниз
	items.sort_custom(func(a, b):
		var a_bought = a["shop_id"] in Global.purchased_shop_ids
		var b_bought = b["shop_id"] in Global.purchased_shop_ids
		# Для рюкзака проверяем лимит отдельно внутри цикла, здесь просто база
		if a_bought == b_bought:
			return a["price"] < b["price"]
		return !a_bought
	)

	for data in items:
		var slot = shop_slot_scene.instantiate()
		grid.add_child(slot)
		
		var icon = slot.get_node("Icon")
		var price_label = slot.get_node("PriceLabel")
		var buy_btn = slot.get_node("BuyButton")
		
		# --- ЛОГИКА ДИНАМИЧЕСКОГО РЮКЗАКА ---
		var is_bought = data["shop_id"] in Global.purchased_shop_ids
		var current_price = data["price"]
		var item_name = data.get("name", "")
		
		if data["type"] == "upgrade_backpack":
			# Получаем актуальную цену из расчетов в Global
			current_price = Global.get_backpack_upgrade_price()
			# Название с текущим лимитом
			item_name = "Рюкзак (" + str(Global.max_inventory_slots) + "/" + str(Global.MAX_SLOTS_LIMIT) + ")"
			# Рюкзак считается купленным только при достижении максимума
			if Global.max_inventory_slots >= Global.MAX_SLOTS_LIMIT:
				is_bought = true
		# ------------------------------------

		# ПРОВЕРКА КВЕСТОВ
		var quest_ok = true
		if data.has("need_quest"):
			quest_ok = Global.is_quest_finished(data["need_quest"])
		
		# ОПРЕДЕЛЕНИЕ ИМЕНИ ДЛЯ ОБЫЧНЫХ ПРЕДМЕТОВ
		if item_name == "" and data["type"] == "item":
			item_name = Global.items_data[data["id"]]["name"]

		# УСТАНОВКА ИКОНОК
		if data["type"] == "item":
			icon.texture = Global.items_data[data["id"]]["texture"]
		elif data["type"] == "upgrade_backpack":
			icon.texture = preload("res://Textures/BarnIcon.png")
		elif data["type"] == "upgrade_field":
			icon.texture = preload("res://Textures/cell_bg.png")
		elif data["shop_id"] == "up_meadow":
			icon.texture = preload("res://Textures/gen_meadow_upgraded.png")
		elif data["shop_id"] == "up_pond":
			icon.texture = preload("res://Textures/gen_pond_upgraded.png")
		elif data["shop_id"] == "buy_mine":
			icon.texture = preload("res://Textures/gen_mine.png")
		elif data["shop_id"] == "buy_forest":
			icon.texture = preload("res://Textures/gen_forest.png")

		# ЛОГИКА СОСТОЯНИЙ
		if is_bought:
			slot.modulate = Color(0.6, 0.6, 0.6, 1.0)
			price_label.visible = false
			buy_btn.visible = true
			buy_btn.disabled = true
			buy_btn.text = "МАКСИМУМ" if data["type"] == "upgrade_backpack" else "КУПЛЕНО"
			buy_btn.add_theme_color_override("font_disabled_color", Color.GREEN_YELLOW)
			
		elif not quest_ok:
			slot.modulate = Color(1, 0.7, 0.7, 1.0)
			price_label.visible = true
			price_label.text = "ЗАБЛОКИРОВАНО"
			buy_btn.text = "НУЖЕН КВЕСТ"
			buy_btn.disabled = true
			buy_btn.add_theme_color_override("font_disabled_color", Color.CRIMSON)
			
		else:
			# Если это редкое поле
			if data.get("is_rare", false) and Global.get_crystal_count() < 10:
				buy_btn.text = "НУЖНО 10 💎"
				buy_btn.disabled = true
			else:
				buy_btn.text = item_name
				buy_btn.disabled = false
				
			slot.modulate = Color(1, 1, 1, 1)
			price_label.visible = true
			price_label.text = str(current_price) + " $"
			
			# Важно: создаем копию данных с АКТУАЛЬНОЙ ценой для функции покупки
			var final_data = data.duplicate()
			final_data["price"] = current_price
			
			if not buy_btn.pressed.is_connected(_on_buy_pressed):
				buy_btn.pressed.connect(_on_buy_pressed.bind(final_data))

func _on_buy_pressed(data):
	if Global.coins < data["price"]:
		print("Мало монет!")
		return

	if data.get("is_rare", false) and Global.get_crystal_count() < 10:
		print("Нужно 10 кристаллов!")
		return

	# СПИСЫВАЕМ ДЕНЬГИ
	Global.coins -= data["price"]

	match data["type"]:
		"visual_upgrade":
			if data["gen_id"] == 101: Global.meadow_upgraded = true
			if data["gen_id"] == 102: Global.pond_upgraded = true
			Global.apply_upgraded_textures()
			var current_scene = get_tree().current_scene
			if current_scene.has_method("refresh_generator_visuals"):
				current_scene.refresh_generator_visuals()
			Global.purchased_shop_ids.append(data["shop_id"])

		"passive_gen":
			if data["shop_id"] == "buy_mine": Global.mine_unlocked = true
			if data["shop_id"] == "buy_forest": Global.forest_unlocked = true
			Global.purchased_shop_ids.append(data["shop_id"])

		"upgrade_backpack":
			Global.max_inventory_slots += 2
			print("Рюкзак расширен до ", Global.max_inventory_slots)
			
			# Добавляем в "куплено" ТОЛЬКО если достигли лимита
			if Global.max_inventory_slots >= Global.MAX_SLOTS_LIMIT:
				Global.purchased_shop_ids.append(data["shop_id"])
			
			# ТУТОРИАЛ
			if int(Global.tutorial_step) == 10:
				Global.tutorial_step = 11

		"upgrade_field":
			if data.get("is_rare", false):
				for n in range(10):
					var idx = Global.inventory.find(60)
					if idx != -1: Global.inventory.remove_at(idx)
			Global.unlocked_cells += data["amount"]
			Global.purchased_shop_ids.append(data["shop_id"])
			if get_tree().current_scene.name == "Game": get_tree().reload_current_scene()

	Global.save_game()
	if get_parent().has_method("update_ui"): get_parent().update_ui()
	refresh_shop()
	Global.check_quest_progress("buy_upgrade", data["type"])

func _on_texture_button_pressed():
	self.visible = false
	if get_parent().has_method("show_tutorial"):
		get_parent().show_tutorial()
