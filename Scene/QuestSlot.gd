extends Panel

var quest_data : Dictionary

func setup(data: Dictionary):
	quest_data = data
	$Title.text = data["title"]
	$RewardLabel.text = "Награда: " + str(data["reward"]) + " $"
	$Icon.texture = Global.items_data[data["require_id"]]["texture"]
	update_status()

func update_status():
	var current = Global.get_item_count_in_inventory(quest_data["require_id"])
	var needed = quest_data["require_count"]
	
	$ProgressLabel.text = str(current) + " / " + str(needed)
	
	# Если предметов хватает, кнопка активна, если нет — выключена
	if current >= needed:
		$ClaimButton.disabled = false
		$ClaimButton.text = "Сдать!"
	else:
		$ClaimButton.disabled = true
		$ClaimButton.text = "Нужно еще..."

func _on_claim_button_pressed():
	if Global.complete_quest(quest_data["id"]):
		# Если это был первый квест, Боби радуется
		if quest_data["id"] == 1:
			print("ТУТОРИАЛ ЗАВЕРШЕН!")
		
		# Твой цикл поиска refresh_quests (как я давал выше)
		var parent_node = get_parent()
		while parent_node != null and not parent_node.has_method("refresh_quests"):
			parent_node = parent_node.get_parent()
		if parent_node: parent_node.refresh_quests()
