extends CanvasLayer

@export var slot_scene: PackedScene # Сюда перетащи QuestSlot.tscn
@onready var list = $Window/ScrollContainer/VBoxContainer
@onready var title_label = $Window/Label
@onready var submit_hint_label = $Window/LabelSdat

func _ready():
	self.visible = false # Скрываем при старте игры
	Global.inventory_changed.connect(refresh_quests)
	if not Global.is_connected("language_changed", _on_language_changed):
		Global.language_changed.connect(_on_language_changed)

func open_quests():
	self.visible = true
	refresh_quests()
	_apply_localization()

func refresh_quests():
	# Очищаем старые квесты
	for child in list.get_children():
		child.queue_free()
	
	# Добавляем актуальные квесты из Global
	for quest in Global.active_quests:
		var slot = slot_scene.instantiate()
		list.add_child(slot)
		slot.setup(quest)
	
	# Обновляем монеты на карте, если мы что-то сдали
	if get_parent().has_method("update_ui"):
		get_parent().update_ui()

# В ShopUI.gd, BarnUI.gd и QuestUI.gd
func _on_language_changed(_new_language):
	_apply_localization()
	if visible:
		refresh_quests()

func _apply_localization():
	title_label.text = Global.loc("quests_title")
	submit_hint_label.text = Global.loc("quests_submit_hint")

func _on_close_button_pressed(): # Твой крестик
	self.visible = false
	# Просим карту мира снова показать Боби
	if get_parent().has_method("show_tutorial"):
		get_parent().show_tutorial()
