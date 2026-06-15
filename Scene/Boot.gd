extends Control

const MAIN_MENU_SCENE := "res://Scene/MainMenu.tscn"
const MAX_WAIT_SECONDS := 12.0

@onready var status_label: Label = $CenterContainer/Panel/VBoxContainer/StatusLabel
@onready var timer_label: Label = $CenterContainer/Panel/VBoxContainer/TimerLabel
@onready var rotate_overlay: Control = $RotateOverlay
@onready var rotate_label: Label = $RotateOverlay/Panel/VBoxContainer/RotateLabel

var elapsed := 0.0
var started := false
var boot_started := false

func _ready() -> void:
	update_texts()
	_update_orientation_warning()
	set_process(true)
	call_deferred("_start_boot_flow")

func _process(delta: float) -> void:
	_update_orientation_warning()
	if started:
		return
	elapsed += delta
	update_timer_label()
	if elapsed >= MAX_WAIT_SECONDS and not boot_started:
		_start_boot_flow()

func _start_boot_flow() -> void:
	if boot_started:
		return
	boot_started = true
	Global.initialize_yandex_runtime(false)
	_begin_boot()

func _begin_boot() -> void:
	if started:
		return
	started = true
	Global.apply_detected_language(true)
	update_texts()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func update_texts() -> void:
	if status_label:
		status_label.text = Global.loc("boot_detecting_language")
	if rotate_label:
		rotate_label.text = Global.loc("rotate_device_landscape")
	update_timer_label()

func update_timer_label() -> void:
	if not timer_label:
		return
	if OS.get_name() == "Web" and not Global.save_loaded_once:
		timer_label.text = "Загрузка профиля и сохранения Yandex..."
	else:
		timer_label.text = Global.loc("boot_loading")

func _update_orientation_warning() -> void:
	if not rotate_overlay:
		return
	var viewport_size := get_viewport_rect().size
	var is_portrait := viewport_size.y > viewport_size.x
	rotate_overlay.visible = OS.has_feature("web") and DisplayServer.is_touchscreen_available() and is_portrait
