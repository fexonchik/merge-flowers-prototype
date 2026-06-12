extends Control

# Ссылки на узлы (убедись, что имена в сцене точно такие же)
@onready var icon = $Icon
@onready var title_label = $Title
@onready var progress_label = $ProgressLabel
@onready var reward_label = $RewardLabel

func _ready():
	# Подписываемся на сигнал из Global, чтобы цифры менялись сразу при сборе
	if not Global.is_connected("inventory_changed", update_tracker_ui):
		Global.inventory_changed.connect(update_tracker_ui)
	
	update_tracker_ui()

func update_tracker_ui():
	# Если заданий в списке нет — убираем доску с экрана
	if Global.active_quests.is_empty():
		self.visible = false
		return
	
	# Показываем доску
	self.visible = true
	
	# Берем самый актуальный квест (первый в списке)
	var quest = Global.active_quests[0]
	
	# 1. Тексты
	title_label.text = quest["title"]
	reward_label.text = "Награда: " + str(quest["reward"]) + " $"
	
	# 2. Иконка
	var item_id = int(quest["require_id"])
	if Global.items_data.has(item_id):
		icon.texture = Global.items_data[item_id]["texture"]
	
	# 3. Прогресс
	var current = Global.get_item_count_in_inventory(item_id)
	var needed = int(quest["require_count"])
	
	progress_label.text = str(current) + " / " + str(needed)
	
	# Визуальное выделение: если всё собрано, текст становится зеленым
	if current >= needed:
		progress_label.add_theme_color_override("font_color", Color.GREEN_YELLOW)
	else:
		progress_label.add_theme_color_override("font_color", Color.WHITE)
