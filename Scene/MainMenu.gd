extends Control

func _ready():
	$ReadmePanel.visible = false
	# Сначала загружаем игру, чтобы знать шаг туториала
	Global.load_game()
	check_tutorial()

func check_tutorial():
	if not has_node("TutorialLayer"): return
	
	# Если всё пройдено - прячем
	if Global.is_tutorial_done:
		$TutorialLayer.visible = false
		return
		
	var text = Global.get_bobby_text("MainMenu")
	
	if text != "" and text != "...":
		$TutorialLayer.visible = true
		$TutorialLayer/TutorialCharacter.texture = Global.bobby_texture
		var label = $TutorialLayer/DialogueBox/TutorialLabel
		
		# Плавное появление
		label.text = text
		label.visible_ratio = 0
		var tw = create_tween()
		tw.tween_property(label, "visible_ratio", 1.0, 0.5)
	else:
		$TutorialLayer.visible = false

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
