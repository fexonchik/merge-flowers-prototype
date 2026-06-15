extends CanvasLayer

# Ссылки на текстовые узлы и аватар
@onready var name_label = %NameInput
@onready var id_label = %IDLabel
@onready var version_label = %VersionLabel
@onready var avatar_rect = %Avatar
@onready var main_panel = $MainPanel

# Ссылки на кнопки и слайдеры
@onready var title_label = $MainPanel/Title
@onready var music_btn = %MusicButton
@onready var sound_btn = %SoundButton
@onready var lang_swap_btn = %LangSwap
@onready var music_slider = %MusicSlider
@onready var sound_slider = %SoundSlider

const COLOR_ON = Color(1, 1, 1, 1)
const COLOR_OFF = Color(0.5, 0.5, 0.5, 1)

func _ready():
	self.visible = false
	if not Global.is_connected("language_changed", _on_language_changed):
		Global.language_changed.connect(_on_language_changed)
	
	# Подключаем кнопку закрытия (если она есть)
	var close_btn = find_child("CloseButton", true)
	if close_btn and not close_btn.pressed.is_connected(_close_settings):
		close_btn.pressed.connect(_close_settings)
	var overlay = $Overlay # Убедись, что путь верный
	if overlay:
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		if not overlay.gui_input.is_connected(_on_overlay_gui_input):
			overlay.gui_input.connect(_on_overlay_gui_input)
	if main_panel:
		main_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Подключаем управление звуком
	if music_btn and not music_btn.pressed.is_connected(_on_music_clicked):
		music_btn.pressed.connect(_on_music_clicked)
	if sound_btn and not sound_btn.pressed.is_connected(_on_sound_clicked):
		sound_btn.pressed.connect(_on_sound_clicked)
	if lang_swap_btn and not lang_swap_btn.pressed.is_connected(_on_lang_swap_pressed):
		lang_swap_btn.pressed.connect(_on_lang_swap_pressed)
	
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
		name_label.text = Global.get_display_player_name()
	
	if id_label:
		if Global.player_id == "": Global.player_id = Global._generate_random_id()
		id_label.text = Global.loc("label_id", {"id": Global.player_id})
	
	_ensure_lang_button_setup()
	_apply_localization_texts()
		
	if version_label:
		version_label.text = Global.loc("label_version", {"version": Global.VERSION})
		
	if avatar_rect:
		avatar_rect.texture = preload("res://Textures/BobbyAvatar.png")
	
	update_language_button()

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

func _ensure_lang_button_setup():
	if not lang_swap_btn:
		return
	lang_swap_btn.text = String(Global.current_language).to_upper()
	lang_swap_btn.clip_text = false
	lang_swap_btn.flat = true
	lang_swap_btn.icon = null
	lang_swap_btn.expand_icon = false
	lang_swap_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	lang_swap_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	lang_swap_btn.custom_minimum_size = Vector2(120, 48)
	lang_swap_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	lang_swap_btn.focus_mode = Control.FOCUS_ALL
	if name_label:
		lang_swap_btn.add_theme_font_override("font", name_label.get_theme_font("font"))
		lang_swap_btn.add_theme_font_size_override("font_size", 28)
		lang_swap_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		lang_swap_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
		lang_swap_btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
		lang_swap_btn.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
		lang_swap_btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		lang_swap_btn.add_theme_constant_override("outline_size", 4)

func update_language_button():
	if lang_swap_btn:
		lang_swap_btn.text = String(Global.current_language).to_upper()

func _apply_localization_texts():
	if title_label:
		title_label.text = Global.loc("settings_title")

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

func _on_lang_swap_pressed():
	Global.play_sound("click")
	Global.toggle_language()
	update_language_button()
	if visible:
		open_settings()


func _on_language_changed(_new_language):
	if visible:
		open_settings()

func _close_settings() -> void:
	Global.play_sound("click")
	self.visible = false

func _on_close_button_pressed() -> void:
	_close_settings()

func _on_closesound_button_pressed() -> void:
	_close_settings()

func _on_overlay_gui_input(event):
	# Закрываем только при клике именно по затемнению, а не по дочерним контролам
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if main_panel and main_panel.get_global_rect().has_point(event.global_position):
			return
		print("Клик вне окна — закрываю настройки")
		_close_settings()
