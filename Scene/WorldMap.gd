extends Control

@onready var coin_label = $TextureRect2/Label 
# Убедись, что TutorialLayer — это прямой ребенок WorldMap
@onready var tutorial = $TutorialLayer

func _ready():
	update_ui()
	check_tutorial_step()
	# Подписываемся на изменения, чтобы Боби реагировал на сдачу квеста
	if not Global.is_connected("inventory_changed", check_tutorial_step):
		Global.inventory_changed.connect(check_tutorial_step)

func update_ui():
	if coin_label:
		coin_label.text = "МОНЕТЫ: " + str(Global.coins)

# --- УПРАВЛЕНИЕ БОББИ ---

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
		var label = $TutorialLayer/DialogueBox/TutorialLabel
		var bobby = $TutorialLayer/TutorialCharacter
		bobby.texture = Global.bobby_texture
		
		var step = int(Global.tutorial_step)
		var new_text = "" # Сюда запишем текст

		match step:
			1, 2, 3, 4, 5, 6, 7:
				new_text = "Заходи на ФЕРМУ, Боби ждет тебя там!"
			8, 9:
				new_text = "Отлично! Теперь жми на ВОРОТА и сдай наш первый заказ."
			10:
				new_text = "Ого, сколько монет! Давай заглянем в ЛАВКУ и купим расширение рюкзака."
			11:
				new_text = "Теперь ты настоящий мастер! Я пошел отдыхать. Удачи!"
				get_tree().create_timer(4.0).timeout.connect(func():
					Global.is_tutorial_done = true
					$TutorialLayer.visible = false
					Global.save_game()
				)
		
		# ПРОВЕРКА: Анимируем только если текст реально изменился или был пустым
		if label.text != new_text:
			label.text = new_text
			label.visible_ratio = 0
			var tw = create_tween()
			tw.tween_property(label, "visible_ratio", 1.0, 0.5)

# --- КНОПКИ (со скрытием Боби) ---

func _on_texture_button_pressed(): # ФЕРМА
	get_tree().change_scene_to_file("res://Scene/Game.tscn")

func _on_texture_button_2_pressed(): # ЛАВКА
	hide_tutorial()
	$ShopUI.open_shop()

func _on_texture_button_3_pressed(): # АМБАР
	hide_tutorial()
	$BarnUI.open_barn()

func _on_texture_button_4_pressed(): # ВОРОТА
	hide_tutorial()
	$QuestUI.open_quests()
