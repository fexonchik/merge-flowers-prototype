extends CanvasLayer

@export var shop_slot_scene: PackedScene 
@onready var grid = $TextureRect/ScrollContainer/GridContainer

func _ready():
	if not Global.is_connected("language_changed", _on_language_changed):
		Global.language_changed.connect(_on_language_changed)

func open_shop():
	self.visible = true
	refresh_shop()

func _on_language_changed(_new_language):
	if visible:
		refresh_shop()

func refresh_shop():
	for child in grid.get_children():
		child.queue_free()
	
	var secret_slot = shop_slot_scene.instantiate()
	grid.add_child(secret_slot)
	setup_secret_ad_slot(secret_slot)
	
	var next_bp = Global.get_next_backpack_upgrade()
	if next_bp:
		var slot = shop_slot_scene.instantiate()
		grid.add_child(slot)
		setup_upgrade_slot(slot, "upgrade_backpack", next_bp)

	var next_field = Global.get_next_field_upgrade()
	if next_field:
		var slot = shop_slot_scene.instantiate()
		grid.add_child(slot)
		setup_upgrade_slot(slot, "upgrade_field", next_field)

	var items = Global.shop_items.duplicate(true)
	items.sort_custom(func(a, b):
		return (a["shop_id"] in Global.purchased_shop_ids) < (b["shop_id"] in Global.purchased_shop_ids)
	)

	for data in items:
		var slot = shop_slot_scene.instantiate()
		grid.add_child(slot)
		setup_standard_slot(slot, data)

func setup_upgrade_slot(slot, type, data):
	var icon = slot.get_node("Icon")
	var price_label = slot.get_node("PriceLabel")
	var buy_btn = slot.get_node("BuyButton")
	var name_label = slot.get_node_or_null("NameLabel")
	
	var coins_req = int(data.get("price_coins", 0))
	var gems_req = int(data.get("price_gems", 0))
	
	var display_text = ""
	if type == "upgrade_backpack":
		icon.texture = preload("res://Textures/BarnIcon.png")
		display_text = Global.loc("shop_backpack_upgrade", {"slot": Global.max_inventory_slots + 1})
	else:
		icon.texture = preload("res://Textures/cell_bg.png")
		display_text = Global.loc("shop_field_upgrade", {"slot": Global.unlocked_cells + 1})

	if name_label:
		name_label.text = display_text
		buy_btn.text = ""
	else:
		buy_btn.text = display_text

	var p_text = str(coins_req) + " $"
	if gems_req > 0:
		p_text += "\n" + str(gems_req) + " 💎"
	price_label.text = p_text

	var can_buy = Global.coins >= coins_req and Global.get_item_count_in_inventory(60) >= gems_req
	buy_btn.disabled = !can_buy

	if not buy_btn.disabled:
		if buy_btn.pressed.is_connected(_on_upgrade_pressed):
			buy_btn.pressed.disconnect(_on_upgrade_pressed)
		buy_btn.pressed.connect(_on_upgrade_pressed.bind(type, data))

func format_seconds_to_mmss(seconds: float) -> String:
	var total_seconds = int(ceil(seconds))
	var minutes = total_seconds / 60
	var secs = total_seconds % 60
	return "%02d:%02d" % [minutes, secs]

func setup_secret_ad_slot(slot):
	var icon = slot.get_node("Icon")
	var price_label = slot.get_node("PriceLabel")
	var buy_btn = slot.get_node("BuyButton")
	var name_label = slot.get_node_or_null("NameLabel")
	icon.texture = preload("res://Textures/crystal_item.png")
	var title = Global.loc("shop_secret_gift")
	if name_label:
		name_label.text = title
		buy_btn.text = ""
	else:
		buy_btn.text = title
	price_label.text = Global.loc("shop_ad_reward")
	buy_btn.disabled = not Global.can_claim_secret_gift()
	if buy_btn.disabled:
		price_label.text = Global.loc("shop_repeat_in", {"time": format_seconds_to_mmss(Global.get_secret_gift_cooldown_left())})
	if not buy_btn.disabled:
		if buy_btn.pressed.is_connected(claim_secret_ad_gift):
			buy_btn.pressed.disconnect(claim_secret_ad_gift)
		buy_btn.pressed.connect(claim_secret_ad_gift)

func _get_shop_item_name(data: Dictionary) -> String:
	if data.has("name_key"):
		return Global.loc(str(data["name_key"]))
	return str(data.get("name", ""))

func setup_standard_slot(slot, data):
	var icon = slot.get_node("Icon")
	var price_label = slot.get_node("PriceLabel")
	var buy_btn = slot.get_node("BuyButton")
	var name_label = slot.get_node_or_null("NameLabel")
	
	var is_bought = data["shop_id"] in Global.purchased_shop_ids
	
	if data["shop_id"] == "up_meadow": icon.texture = preload("res://Textures/gen_meadow_upgraded.png")
	elif data["shop_id"] == "up_pond": icon.texture = preload("res://Textures/gen_pond_upgraded.png")
	elif data["shop_id"] == "buy_mine": icon.texture = preload("res://Textures/gen_mine.png")
	elif data["shop_id"] == "buy_forest": icon.texture = preload("res://Textures/gen_forest.png")
	
	if is_bought:
		if name_label:
			name_label.text = Global.loc("shop_bought")
		else:
			buy_btn.text = Global.loc("shop_bought")
		price_label.text = Global.loc("shop_done")
		buy_btn.disabled = true
	else:
		var item_name = _get_shop_item_name(data)
		if name_label:
			name_label.text = item_name
			buy_btn.text = ""
		else:
			buy_btn.text = item_name
			
		price_label.text = str(data["price"]) + " $"
		buy_btn.disabled = Global.coins < data["price"]
		
		if not buy_btn.disabled:
			if buy_btn.pressed.is_connected(_on_buy_pressed):
				buy_btn.pressed.disconnect(_on_buy_pressed)
			buy_btn.pressed.connect(_on_buy_pressed.bind(data))

func claim_secret_ad_gift():
	if not Global.can_claim_secret_gift():
		refresh_shop()
		return
	if not Ads.rewarded_ad_completed.is_connected(_on_rewarded_ad_completed):
		Ads.rewarded_ad_completed.connect(_on_rewarded_ad_completed)
	if not Ads.rewarded_ad_failed.is_connected(_on_rewarded_ad_failed):
		Ads.rewarded_ad_failed.connect(_on_rewarded_ad_failed)
	Ads.show_rewarded_ad("secret_gift")

func _on_rewarded_ad_completed(reward_type: String):
	if reward_type != "secret_gift":
		return
	if Ads.rewarded_ad_completed.is_connected(_on_rewarded_ad_completed):
		Ads.rewarded_ad_completed.disconnect(_on_rewarded_ad_completed)
	if Ads.rewarded_ad_failed.is_connected(_on_rewarded_ad_failed):
		Ads.rewarded_ad_failed.disconnect(_on_rewarded_ad_failed)
	grant_secret_ad_gift()

func _on_rewarded_ad_failed(reward_type: String):
	if reward_type != "secret_gift":
		return
	if Ads.rewarded_ad_completed.is_connected(_on_rewarded_ad_completed):
		Ads.rewarded_ad_completed.disconnect(_on_rewarded_ad_completed)
	if Ads.rewarded_ad_failed.is_connected(_on_rewarded_ad_failed):
		Ads.rewarded_ad_failed.disconnect(_on_rewarded_ad_failed)
	refresh_shop()

func grant_secret_ad_gift():
	var roll = randi() % 100
	if roll < 20:
		Global.add_to_inventory(60)
	elif roll < 60:
		Global.coins += 250
	else:
		var item_id = randi_range(1, 4)
		Global.add_to_inventory(item_id)
	Global.mark_secret_gift_claimed()
	Global.save_game()
	refresh_shop()
	if get_parent().has_method("update_ui"):
		get_parent().update_ui()

func _on_upgrade_pressed(type, data):
	var coins_req = int(data["price_coins"])
	var gems_req = int(data.get("price_gems", 0))
	if Global.coins >= coins_req and Global.get_item_count_in_inventory(60) >= gems_req:
		Global.coins -= coins_req
		if gems_req > 0:
			for n in range(gems_req):
				var idx = Global.inventory.find(60)
				if idx != -1: Global.inventory.remove_at(idx)
		if type == "upgrade_backpack":
			Global.max_inventory_slots += 1
			Global.increment_upgrade_ad_counter(type)
			if int(Global.tutorial_step) == 10: Global.tutorial_step = 11
		elif type == "upgrade_field":
			Global.unlocked_cells += 1
			Global.increment_upgrade_ad_counter(type)
			if get_tree().current_scene.name == "Game": get_tree().reload_current_scene()
		Global.save_game()
		refresh_shop()
		if get_parent().has_method("update_ui"): get_parent().update_ui()

func _on_buy_pressed(data):
	if Global.coins >= data["price"]:
		Global.coins -= data["price"]
		match data["type"]:
			"visual_upgrade":
				if data["gen_id"] == 101: Global.meadow_upgraded = true
				if data["gen_id"] == 102: Global.pond_upgraded = true
				Global.apply_upgraded_textures()
				if get_tree().current_scene.has_method("refresh_generator_visuals"):
					get_tree().current_scene.refresh_generator_visuals()
			"passive_gen":
				if data["shop_id"] == "buy_mine": Global.mine_unlocked = true
				if data["shop_id"] == "buy_forest": Global.forest_unlocked = true
		Global.purchased_shop_ids.append(data["shop_id"])
		Global.save_game()
		refresh_shop()
		if get_parent().has_method("update_ui"): get_parent().update_ui()

func _on_texture_button_pressed():
	self.visible = false
	if get_parent().has_method("show_tutorial"):
		get_parent().show_tutorial()
