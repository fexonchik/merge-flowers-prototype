extends CanvasLayer

@export var slot_scene: PackedScene # Сюда перетащи QuestSlot.tscn
@onready var list = $Window/ScrollContainer/VBoxContainer

func _ready():
	self.visible = false # Скрываем при старте игры
	Global.inventory_changed.connect(refresh_quests)

func open_quests():
	self.visible = true
	refresh_quests()

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
func _on_close_button_pressed(): # Твой крестик
	self.visible = false
	# Просим карту мира снова показать Боби
	if get_parent().has_method("show_tutorial"):
		get_parent().show_tutorial()
