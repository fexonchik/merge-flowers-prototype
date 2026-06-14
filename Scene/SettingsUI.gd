extends CanvasLayer

# Ссылки на текстовые узлы и аватар
@onready var name_label = %NameInput
@onready var id_label = %IDLabel
@onready var version_label = %VersionLabel
@onready var avatar_rect = %Avatar

# Ссылки на кнопки и слайдеры
@onready var music_btn = %MusicButton
@onready var sound_btn = %SoundButton
@onready var music_slider = %MusicSlider
@onready var sound_slider = %SoundSlider

const COLOR_ON = Color(1, 1, 1, 1)
const COLOR_OFF = Color(0.5, 0.5, 0.5, 1)

func _ready():
	self.visible = false
	
	# Подключаем кнопку закрытия (если она есть)
	var close_btn = find_child("CloseButton", true)
	if close_btn:
		close_btn.pressed.connect(func(): self.visible = false)
	var overlay = $Overlay # Убедись, что путь верный
	if overlay: 
		overlay.gui_input.connect(_on_overlay_gui_input)

	# Подключаем управление звуком
	if music_btn: music_btn.pressed.connect(_on_music_clicked)
	if sound_btn: sound_btn.pressed.connect(_on_sound_clicked)
	
	if music_slider: music_slider.value_changed.connect(_on_music_volume_changed)
	if sound_slider: sound_slider.value_changed.connect(_on_sound_volume_changed)
	
	# Сохранение при отпускании ползунка
	if music_slider: music_slider.drag_ended.connect(func(_val): Global.save_game())
	if sound_slider: sound_slider.drag_ended.connect(func(_val): Global.save_game())
	
	if music_slider:
		music_slider.drag_ended.connect(func(changed): 
			if changed: Global.save_game() 
		)
		
	if sound_slider:
		sound_slider.drag_ended.connect(func(changed): 
			if changed: Global.save_game() 
		)
	

# ГЛАВНАЯ ФУНКЦИЯ ОБНОВЛЕНИЯ
func open_settings():
	self.visible = true
	print("Настройки открыты, обновляю данные...")

	# 1. Заполняем текстовые данные из Global
	if name_label:
		name_label.text = str(Global.player_name)
	
	if id_label:
		if Global.player_id == "": Global.player_id = Global._generate_random_id()
		id_label.text = "ID: " + str(Global.player_id)
		
	if version_label:
		version_label.text = "v" + str(Global.VERSION)
		
	if avatar_rect:
		avatar_rect.texture = preload("res://Textures/BobbyAvatar.png")

	# 2. Настраиваем ползунки
	if music_slider:
		music_slider.value = Global.music_volume
		music_slider.visible = Global.music_enabled
		
	if sound_slider:
		sound_slider.value = Global.sound_volume
		sound_slider.visible = Global.sound_enabled
	
	update_visuals()

func update_visuals():
	# Потемнение кнопок
	if music_btn:
		music_btn.modulate = COLOR_ON if Global.music_enabled else COLOR_OFF
	if sound_btn:
		sound_btn.modulate = COLOR_ON if Global.sound_enabled else COLOR_OFF

# --- ОБРАБОТКА НАЖАТИЙ ---
func _on_music_volume_changed(value):
	Global.music_volume = value
	Global.apply_audio_settings() # Обновляем шину Music

func _on_sound_volume_changed(value):
	Global.sound_volume = value
	Global.apply_audio_settings() # Обновляем шину Sounds (все звуки сразу)

func _on_music_clicked():
	Global.play_sound("click") # Звук только при нажатии на кнопку
	Global.music_enabled = !Global.music_enabled
	if music_slider: music_slider.visible = Global.music_enabled
	Global.apply_audio_settings()
	update_visuals()
	Global.save_game()

func _on_sound_clicked():
	Global.play_sound("click") # Звук только при нажатии на кнопку
	Global.sound_enabled = !Global.sound_enabled
	if sound_slider: sound_slider.visible = Global.sound_enabled
	Global.apply_audio_settings()
	update_visuals()
	Global.save_game()


func _on_closesound_button_pressed() -> void:
	Global.play_sound("click")
	pass # Replace with function body.

func _on_overlay_gui_input(event):
	# Проверяем, что это нажатие левой кнопкой мыши
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Клик вне окна — закрываю настройки")
		Global.play_sound("click") # Опционально: звук закрытия
		self.visible = false
