extends Control

func _ready():
	$ReadmePanel.visible = false

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://Scene/Game.tscn")

func _on_readme_button_pressed():
	$ReadmePanel.visible = true

func _on_close_button_pressed():
	$ReadmePanel.visible = false

func _on_exit_button_pressed():
	get_tree().quit()
