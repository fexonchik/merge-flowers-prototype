extends Panel

var quest_data : Dictionary

func setup(data: Dictionary):
	# Запоминаем данные и ПРИНУДИТЕЛЬНО переводим всё в int, 
	# чтобы избавиться от ошибок типа '1.0'
	quest_data = data
	var q_id = int(data["id"])
	var req_id = int(data["require_id"])
	var req_count = int(data["require_count"])
	var reward_val = int(data["reward"])
	
	# Обновляем сам словарь, чтобы в других функциях тоже были int
	quest_data["id"] = q_id
	quest_data["require_id"] = req_id
	quest_data["require_count"] = req_count
	quest_data["reward"] = reward_val

	$Title.text = data["title"]
	$RewardLabel.text = "Награда: " + str(reward_val) + " $"
	
	# Теперь используем очищенный от точек req_id
	if Global.items_data.has(req_id):
		$Icon.texture = Global.items_data[req_id]["texture"]
	else:
		print("ОШИБКА: Предмет с ID ", req_id, " не найден в Global.items_data!")
		
	update_status()

func update_status():
	# Опять используем int() для надежности
	var req_id = int(quest_data["require_id"])
	var current = Global.get_item_count_in_inventory(req_id)
	var needed = int(quest_data["require_count"])
	
	$ProgressLabel.text = str(current) + " / " + str(needed)
	
	# Если предметов хватает, кнопка активна, если нет — выключена
	if current >= needed:
		$ClaimButton.disabled = false
		$ClaimButton.text = "Сдать!"
	else:
		$ClaimButton.disabled = true
		$ClaimButton.text = "Нужно еще..."

func _on_claim_button_pressed():
	# Передаем ID как целое число
	if Global.complete_quest(int(quest_data["id"])):
		# Твой цикл поиска refresh_quests
		var parent_node = get_parent()
		while parent_node != null and not parent_node.has_method("refresh_quests"):
			parent_node = parent_node.get_parent()
		
		if parent_node: 
			parent_node.refresh_quests()
