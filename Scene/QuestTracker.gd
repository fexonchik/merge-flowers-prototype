extends Control

@onready var icon = $Icon
@onready var title_label = $Title
@onready var progress_label = $ProgressLabel
@onready var reward_label = $RewardLabel
@onready var no_quests_label = $NoQuestsLabel

@onready var bobby_wrapper = get_node_or_null("BobbyWrapper")
@onready var bobby_text_label = get_node_or_null("BobbyWrapper/BobbyBubble/BobbyLabel")
@onready var hide_button = get_node_or_null("BobbyWrapper/HideButton")

func _ready():
	if not Global.is_connected("inventory_changed", update_tracker_ui):
		Global.inventory_changed.connect(update_tracker_ui)
	if not Global.is_connected("language_changed", _on_language_changed):
		Global.language_changed.connect(_on_language_changed)
	
	if hide_button:
		# Очищаем старые коннекты на всякий случай
		if hide_button.pressed.is_connected(_on_hide_pressed):
			hide_button.pressed.disconnect(_on_hide_pressed)
		hide_button.pressed.connect(_on_hide_pressed)
	
	update_tracker_ui()

func _on_hide_pressed():
	if Global.active_quests.size() > 0:
		# Запоминаем в Global ID текущего квеста
		Global.bobby_hidden_quest_id = int(Global.active_quests[0]["id"])
		if bobby_wrapper:
			bobby_wrapper.visible = false
		print("Бобби скрыт для квеста №", Global.bobby_hidden_quest_id)

func update_tracker_ui():
	self.visible = true

	if Global.active_quests.is_empty():
		no_quests_label.visible = true
		toggle_quest_elements(false)
		if bobby_wrapper: bobby_wrapper.visible = false
		return
	
	no_quests_label.visible = false
	toggle_quest_elements(true)
	
	var quest = Global.active_quests[0]
	var current_quest_id = int(quest["id"])
	
	# Заполняем доску
	title_label.text = _get_localized_text(quest.get("title", ""))
	reward_label.text = Global.loc("reward_label", {"reward": int(quest["reward"])})
	
	var item_id = int(quest["require_id"])
	if Global.items_data.has(item_id):
		icon.texture = Global.items_data[item_id]["texture"]
	
	var current = Global.get_item_count_in_inventory(item_id)
	var needed = int(quest["require_count"])
	progress_label.text = str(current) + " / " + str(needed)

	# --- ЛОГИКА ВИДИМОСТИ БОББИ ---
	if bobby_wrapper:
		# Условие показа:
		# 1. Туториал закончен
		# 2. ID текущего квеста НЕ совпадает с тем, который мы скрыли
		if Global.is_tutorial_done and Global.bobby_hidden_quest_id != current_quest_id:
			bobby_wrapper.visible = true
			if bobby_text_label:
				var bobby_phrase = _get_localized_text(quest.get("bobby_text", "hint_default"))
				if bobby_text_label.text != bobby_phrase:
					bobby_text_label.text = bobby_phrase
					animate_text(bobby_text_label)
		else:
			# Скрываем, если тутор идет ИЛИ если этот квест помечен как скрытый
			bobby_wrapper.visible = false

	# Цвет прогресса
	if current >= needed:
		progress_label.add_theme_color_override("font_color", Color.GREEN_YELLOW)
	else:
		progress_label.add_theme_color_override("font_color", Color.WHITE)

func _get_localized_text(value) -> String:
	if value is Dictionary:
		return str(value.get(Global.current_language, value.get("ru", "")))
	if typeof(value) == TYPE_STRING and String(value) == "hint_default":
		return Global.loc("hint_default")
	return str(value)

func _on_language_changed(_new_language):
	update_tracker_ui()

func toggle_quest_elements(state: bool):
	icon.visible = state
	title_label.visible = state
	progress_label.visible = state
	reward_label.visible = state

func animate_text(label_node):
	label_node.visible_ratio = 0
	var tw = create_tween()
	tw.tween_property(label_node, "visible_ratio", 1.0, 0.6)
