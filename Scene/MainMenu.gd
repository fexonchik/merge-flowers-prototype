extends Control

@onready var play_button: Button = $Button
@onready var exit_button: Button = $Button3
@onready var readme_label: Label = $ReadmePanel/ReadmeText
@onready var close_button: Button = $ReadmePanel/CloseButton

func _ready():
	$ReadmePanel.visible = false
	if exit_button:
		exit_button.visible = not OS.has_feature("web")
	if not Global.is_connected("language_changed", _on_language_changed):
		Global.language_changed.connect(_on_language_changed)
	apply_localization()
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

func apply_localization():
	if play_button:
		play_button.text = Global.loc("main_menu_play")
	if exit_button:
		exit_button.text = Global.loc("main_menu_exit")
	if readme_label:
		readme_label.text = Global.loc("main_menu_readme")
	if close_button:
		close_button.text = Global.loc("main_menu_close")

func _on_language_changed(_new_language):
	apply_localization()
	check_tutorial()

func _on_exit_button_pressed():
	Global.play_sound("click")
	get_tree().quit()

func _on_button_pressed() -> void:
	Global.play_sound("click")
	# Если это самый старт, переключаем на шаг 1
	if int(Global.tutorial_step) == 0:
		Global.tutorial_step = 1
		Global.save_game()
	get_tree().change_scene_to_file("res://Scene/WorldMap.tscn")


func _on_settings_button_pressed() -> void:
	Global.play_sound("click")
	# Вызываем окно настроек
	$SettingsUI.open_settings()
