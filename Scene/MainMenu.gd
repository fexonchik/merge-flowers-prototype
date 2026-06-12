extends Control

func _ready():
	$ReadmePanel.visible = false
	# Сначала загружаем игру, чтобы знать шаг туториала
	Global.load_game()
	check_tutorial()

func check_tutorial():
	if has_node("TutorialLayer"):
		# Если туториал УЖЕ пройден — скрываем Боби навсегда
		if Global.is_tutorial_done or int(Global.tutorial_step) > 1:
			$TutorialLayer.visible = false
			return
		
		# Если это самое начало (шаг 0 или 1)
		var layer = $TutorialLayer
		layer.visible = true
		
		var label = $TutorialLayer/DialogueBox/TutorialLabel
		var bobby = $TutorialLayer/TutorialCharacter
		
		if bobby: bobby.texture = Global.bobby_texture
		
		if label:
			label.text = "Привет! Я Боби. Давай построим лучшую ферму! Нажимай ИГРАТЬ."
			label.visible_ratio = 0
			var tw = create_tween()
			tw.tween_property(label, "visible_ratio", 1.5, 1.5)
		else:
			layer.visible = false
	else:
		# Если ты забыл добавить TutorialLayer, игра просто напишет в консоль, но НЕ ВЫЛЕТИТ
		print("Предупреждение: TutorialLayer не найден на сцене MainMenu. Проверь дерево узлов!")

func _on_readme_button_pressed():
	$ReadmePanel.visible = true

func _on_close_button_pressed():
	$ReadmePanel.visible = false

func _on_exit_button_pressed():
	get_tree().quit()

func _on_button_pressed() -> void:
	# Если это самый старт, переключаем на шаг 1
	if int(Global.tutorial_step) == 0:
		Global.tutorial_step = 1
		Global.save_game()
	get_tree().change_scene_to_file("res://Scene/WorldMap.tscn")
