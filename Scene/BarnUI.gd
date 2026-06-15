extends CanvasLayer

@export var slot_scene: PackedScene

@onready var grid = $TextureRect/ScrollContainer/GridContainer
@onready var hint_label = $Label

const MAX_SLOTS = 24 # Сколько всего мест в амбаре

func _ready():
	# Когда инвентарь меняется (включая сдачу квеста), амбар сам себя перерисует
	Global.inventory_changed.connect(refresh_inventory)
	if not Global.is_connected("language_changed", _on_language_changed):
		Global.language_changed.connect(_on_language_changed)

func open_barn():
	self.visible = true
	_apply_localization()
	refresh_inventory()

func refresh_inventory():
	for child in grid.get_children():
		child.queue_free()
	
	# Создаем ячейки согласно ТЕКУЩЕМУ лимиту
	for i in range(Global.max_inventory_slots):
		var new_slot = slot_scene.instantiate()
		grid.add_child(new_slot)
		
		# Если предмет по этому индексу есть в инвентаре
		if i < Global.inventory.size():
			var item_id = int(Global.inventory[i])
			var item_data = Global.items_data[item_id]
			
			new_slot.get_node("Icon").texture = item_data["texture"]
			new_slot.get_node("Icon").visible = true
			
			var sell_btn = new_slot.get_node("SellButton")
			if item_data["price"] > 0:
				sell_btn.text = str(item_data["price"]) + " $"
				sell_btn.visible = true
				if sell_btn.pressed.is_connected(_on_sell_item):
					sell_btn.pressed.disconnect(_on_sell_item)
				sell_btn.pressed.connect(_on_sell_item.bind(i))
		else:
			# Ячейка пустая, но она ВИДНА как пустой квадрат
			new_slot.get_node("Icon").visible = false
			new_slot.get_node("SellButton").visible = false

func _on_language_changed(_new_language):
	_apply_localization()
	if visible:
		refresh_inventory()

func _apply_localization():
	hint_label.text = Global.loc("barn_sell_hint")

func _on_sell_item(index: int):
	var item_id = Global.inventory[index]
	var price = Global.items_data[item_id]["price"]
	
	Global.coins += price
	Global.inventory.remove_at(index)
	
	# СИГНАЛЫ
	Global.item_sold.emit(price)
	Global.inventory_updated.emit(Global.inventory.size())
	
	Global.save_game() # Сохраняем монеты и новый инвентарь
	refresh_inventory()
	
	# Обновляем текст монет в WorldMap
	if get_parent().has_method("update_ui"):
		get_parent().update_ui()
		
	Global.check_quest_progress("sell_all") # Проверяем, стало ли пусто

# В ShopUI.gd, BarnUI.gd и QuestUI.gd
func _on_texture_button_pressed(): # Твой крестик
	self.visible = false
	# Просим карту мира снова показать Боби
	if get_parent().has_method("show_tutorial"):
		get_parent().show_tutorial()
