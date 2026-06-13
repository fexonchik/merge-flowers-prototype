extends Control

@onready var coin_label = $TextureRect2/Label 
@onready var tutorial = $TutorialLayer

func _ready():
	update_ui()
	# Проверяем туториал с небольшой задержкой, чтобы JSON точно успел загрузиться
	call_deferred("check_tutorial_step")
	
	# Подписываемся на изменения: как только сдал квест у ворот, Боби обновит реплику
	if not Global.is_connected("inventory_changed", check_tutorial_step):
		Global.inventory_changed.connect(check_tutorial_step)

func update_ui():
	if coin_label:
		coin_label.text = "МОНЕТЫ: " + str(Global.coins)

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
	get_tree().change_scene_to_file("res://Scene/Game.tscn")

func _on_texture_button_2_pressed(): # Кнопка ЛАВКА
	hide_tutorial()
	if has_node("ShopUI"): $ShopUI.open_shop()

func _on_texture_button_3_pressed(): # Кнопка АМБАР
	hide_tutorial()
	if has_node("BarnUI"): $BarnUI.open_barn()

func _on_texture_button_4_pressed(): # Кнопка ВОРОТА
	hide_tutorial()
	if has_node("QuestUI"): $QuestUI.open_quests()
