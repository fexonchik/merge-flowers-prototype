extends Control

@onready var coin_label = $TextureRect2/Label
@onready var tutorial = $TutorialLayer
@onready var gates_label = $TextureRect7/Ворота
@onready var shop_label = $TextureRect3/Лавка
@onready var barn_label = $TextureRect4/Амбар
@onready var farm_label = $TextureRect5/Ферма
@onready var info_label = $InfoButton/Инфо
@onready var daily_button = $DailyAdButton

func _ready():
	update_ui()
	apply_localization()
	# Проверяем туториал с небольшой задержкой, чтобы JSON точно успел загрузиться
	call_deferred("check_tutorial_step")
	
	# Подписываемся на изменения: как только сдал квест у ворот, Боби обновит реплику
	if not Global.is_connected("inventory_changed", check_tutorial_step):
		Global.inventory_changed.connect(check_tutorial_step)
	if not Global.is_connected("language_changed", _on_language_changed):
		Global.language_changed.connect(_on_language_changed)

func update_ui():
	if coin_label:
		coin_label.text = Global.loc("label_coins", {"coins": Global.coins})
	if daily_button:
		daily_button.disabled = not Global.can_claim_daily_ad_bonus()
		daily_button.text = Global.loc("daily_bonus_ready") if Global.can_claim_daily_ad_bonus() else Global.loc("daily_bonus_claimed")

func apply_localization():
	if gates_label:
		gates_label.text = Global.loc("map_gates")
	if shop_label:
		shop_label.text = Global.loc("map_shop")
	if barn_label:
		barn_label.text = Global.loc("map_barn")
	if farm_label:
		farm_label.text = Global.loc("map_farm")
	if info_label:
		info_label.text = Global.loc("map_info_items")
	update_ui()

func _on_language_changed(_new_language):
	apply_localization()

# --- УПРАВЛЕНИЕ БОББИ (ЧЕРЕЗ JSON) ---

func hide_tutorial():
	if tutorial: tutorial.visible = false

func show_tutorial():
	if not Global.is_tutorial_done:
		if tutorial: tutorial.visible = true
		check_tutorial_step()

func check_tutorial_step():
	if Global.is_tutorial_done:
		if has_node("TutorialLayer"): $TutorialLayer.visible = false
		return

	if has_node("TutorialLayer"):
		var text = Global.get_bobby_text("WorldMap")
		var label = $TutorialLayer/DialogueBox/TutorialLabel
		var bobby = $TutorialLayer/TutorialCharacter
		bobby.texture = Global.bobby_texture
		
		$TutorialLayer.visible = true

		# Анимируем только если текст реально сменился
		if label.text != text:
			label.text = text
			label.visible_ratio = 0
			var tw = create_tween()
			tw.tween_property(label, "visible_ratio", 1.0, 0.5)
			
		# Спец-логика для финального шага 11 (исчезновение)
		if int(Global.tutorial_step) == 11:
			get_tree().create_timer(3.0).timeout.connect(func():
				Global.is_tutorial_done = true
				$TutorialLayer.visible = false
				Global.save_game()
			)

func _on_texture_button_pressed(): # Кнопка ФЕРМА
	Global.play_sound("click")
	get_tree().change_scene_to_file("res://Scene/Game.tscn")

func _on_texture_button_2_pressed(): # Кнопка ЛАВКА
	hide_tutorial()
	Global.play_sound("click")
	if has_node("ShopUI"): $ShopUI.open_shop()

func _on_texture_button_3_pressed(): # Кнопка АМБАР
	hide_tutorial()
	Global.play_sound("click")
	if has_node("BarnUI"): $BarnUI.open_barn()

func _on_texture_button_4_pressed(): # Кнопка ВОРОТА
	hide_tutorial()
	Global.play_sound("click")
	if has_node("QuestUI"): $QuestUI.open_quests()


func _on_info_button_pressed():
	hide_tutorial()
	Global.play_sound("click")
	if has_node("InfoUI"):
		$InfoUI.open_info()

func _on_daily_ad_button_pressed():
	if not Global.can_claim_daily_ad_bonus():
		return
	if not Ads.rewarded_ad_completed.is_connected(_on_rewarded_ad_completed):
		Ads.rewarded_ad_completed.connect(_on_rewarded_ad_completed)
	if not Ads.rewarded_ad_failed.is_connected(_on_rewarded_ad_failed):
		Ads.rewarded_ad_failed.connect(_on_rewarded_ad_failed)
	Ads.show_rewarded_ad("daily_bonus")

func _on_rewarded_ad_completed(reward_type: String):
	if reward_type != "daily_bonus":
		return
	if Ads.rewarded_ad_completed.is_connected(_on_rewarded_ad_completed):
		Ads.rewarded_ad_completed.disconnect(_on_rewarded_ad_completed)
	if Ads.rewarded_ad_failed.is_connected(_on_rewarded_ad_failed):
		Ads.rewarded_ad_failed.disconnect(_on_rewarded_ad_failed)
	grant_daily_ad_bonus()

func _on_rewarded_ad_failed(reward_type: String):
	if reward_type != "daily_bonus":
		return
	if Ads.rewarded_ad_completed.is_connected(_on_rewarded_ad_completed):
		Ads.rewarded_ad_completed.disconnect(_on_rewarded_ad_completed)
	if Ads.rewarded_ad_failed.is_connected(_on_rewarded_ad_failed):
		Ads.rewarded_ad_failed.disconnect(_on_rewarded_ad_failed)

func grant_daily_ad_bonus():
	var roll = randi() % 100
	if roll < 60:
		Global.coins += 300
	elif roll < 90:
		Global.add_to_inventory(60)
	else:
		if Global.generator_states.has(101):
			Global.generator_states[101]["charges"] = min(int(Global.generator_states[101].get("max_charges", 30)), int(Global.generator_states[101].get("charges", 0)) + 5)
	Global.mark_daily_ad_claimed()
	Global.save_game()
	update_ui()

func _on_settings_button_pressed():
	# Если в сцене Game есть туториал, прячем его
	hide_tutorial() 
	Global.play_sound("click")
	# Вызываем окно настроек
	$SettingsUI.open_settings()
