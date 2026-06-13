# Global.gd
extends Node

# --- СОСТОЯНИЕ ИГРОКА ---
var coins := 100
var inventory := []
var is_tutorial_done := false
var saved_grid := []
var unlocked_cells := 12      # Начинаем с 12 (2 ряда)
var max_inventory_slots := 5  # Начинаем с 5 (1 ряд)
const MAX_SLOTS_LIMIT = 20    # Потолок рюкзака
var tutorial_step := 0
var purchased_shop_ids := []
var bobby_hidden_quest_id := -1

# --- СОСТОЯНИЕ ГЕНЕРАТОРОВ ---
var meadow_upgraded := false
var pond_upgraded := false
var mine_unlocked := false
var forest_unlocked := false

# Таймеры оффлайна
var last_coin_time: float = 0.0
var last_crystal_time: float = 0.0

# --- ДАННЫЕ ИЗ JSON ---
var backpack_data := []
var field_data := []
var dialogues_data := {}
var quest_pool := []
var active_quests := []

const SAVE_PATH = "user://savegame.json"

# --- НАСТРОЙКИ И ПРОФИЛЬ ---
var player_name := "Игрок"      # Имя (подгрузим с Яндекса или введет сам)
var player_id := ""            # Уникальный ID игрока
var music_enabled := true      # Состояние музыки
var sound_enabled := true      # Состояние звуков
const VERSION := "v1.0.1"      # Версия игры для настроек

# Текстура аватара (по умолчанию)
@onready var player_avatar: Texture2D = preload("res://Textures/BobbyAvatar.png")

# --- ТЕКСТУРЫ ---
@onready var bobby_texture = preload("res://Textures/BobbyTalk.png")

# --- СИГНАЛЫ ---
signal inventory_changed
signal item_merged(item_id)
signal item_collected(item_id)
signal item_sold(price)
signal coins_changed(total)
signal inventory_updated(count)

# --- БАЗА ПРЕДМЕТОВ (Изначально тут дефолтные текстуры) ---
@onready var items_data = {
	1: {"name": "Косточка", "merge_result": 2, "price": 2, "texture": preload("res://Textures/1_seed.png")},
	2: {"name": "Росток", "merge_result": 3, "price": 5, "texture": preload("res://Textures/2_sprout_thin.png")},
	3: {"name": "Листик", "merge_result": 4, "price": 10, "texture": preload("res://Textures/3_leaf.png")},
	4: {"name": "Молодой росток", "merge_result": 5, "price": 20, "texture": preload("res://Textures/4_sprout_soil.png")},
	5: {"name": "Бутон", "merge_result": 6, "price": 40, "texture": preload("res://Textures/5_bud.png")},
	6: {"name": "Цветок", "merge_result": 7, "price": 80, "texture": preload("res://Textures/6_flower.png")},
	7: {"name": "Роза", "merge_result": 8, "price": 150, "texture": preload("res://Textures/7_rose.png")},
	8: {"name": "Пышный куст", "merge_result": 9, "price": 300, "texture": preload("res://Textures/8_bush.png")},
	9: {"name": "Тележка цветов", "merge_result": 10, "price": 700, "texture": preload("res://Textures/9_cart.png")},
	10: {"name": "Машина цветов", "merge_result": -1, "price": 1500, "texture": preload("res://Textures/10_truck.png")},
	50: {"name": "Монетка", "price": 10, "texture": preload("res://Textures/coin_item.png")},
	60: {"name": "Кристалл", "price": 0, "texture": preload("res://Textures/crystal_item.png")},
	101: {"name": "Клумба", "spawn_list": [1, 1, 2], "texture": preload("res://Textures/gen_meadow.png")},
	102: {"name": "Пруд", "spawn_list": [3, 4], "texture": preload("res://Textures/gen_pond.png")}
}

var shop_items = [
	{"shop_id": "up_meadow", "type": "visual_upgrade", "gen_id": 101, "price": 5, "name": "Сияющая Клумба"},
	{"shop_id": "up_pond", "type": "visual_upgrade", "gen_id": 102, "price": 8, "name": "Магический Пруд"},
	{"shop_id": "buy_mine", "type": "passive_gen", "price": 15, "name": "Древняя Шахта"},
	{"shop_id": "buy_forest", "type": "passive_gen", "price": 20, "name": "Волшебный Лес"}
]

func _ready():
	load_configs()
	load_game()

func load_configs():
	backpack_data = _load_json("res://Data/backpack_upgrades.json")
	field_data = _load_json("res://Data/field_upgrades.json")
	dialogues_data = _load_json("res://Data/dialogues.json")
	var all_quests = _load_json("res://Data/quests.json")
	if quest_pool.is_empty() and active_quests.is_empty() and not is_tutorial_done:
		quest_pool = all_quests
		check_for_next_quest()

func _load_json(path):
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		return JSON.parse_string(file.get_as_text())
	return {}

func get_next_backpack_upgrade():
	var step = max_inventory_slots - 5
	if step < backpack_data.size(): return backpack_data[step]
	return null

func get_next_field_upgrade():
	var step = unlocked_cells - 12
	if step < field_data.size(): return field_data[step]
	return null

func save_game():
	var save_data = {
		"player_name": player_name,
		"player_id": player_id,
		"music_enabled": music_enabled,
		"sound_enabled": sound_enabled,
		"coins": coins, "inventory": inventory, "is_tutorial_done": is_tutorial_done,
		"saved_grid": saved_grid, "max_inventory_slots": max_inventory_slots,
		"unlocked_cells": unlocked_cells, "tutorial_step": tutorial_step,
		"purchased_shop_ids": purchased_shop_ids, "meadow_upgraded": meadow_upgraded,
		"pond_upgraded": pond_upgraded, "mine_unlocked": mine_unlocked,
		"forest_unlocked": forest_unlocked, "active_quests": active_quests,
		"quest_pool": quest_pool, "last_coin_time": last_coin_time,
		"last_crystal_time": last_crystal_time, "bobby_hidden_quest_id": bobby_hidden_quest_id
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(save_data))

func load_game():
	if not FileAccess.file_exists(SAVE_PATH): 
		apply_upgraded_textures()
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if data:
			coins = data.get("coins", 100)
			is_tutorial_done = data.get("is_tutorial_done", false)
			max_inventory_slots = data.get("max_inventory_slots", 5)
			unlocked_cells = data.get("unlocked_cells", 12)
			tutorial_step = data.get("tutorial_step", 0)
			meadow_upgraded = data.get("meadow_upgraded", false)
			pond_upgraded = data.get("pond_upgraded", false)
			mine_unlocked = data.get("mine_unlocked", false)
			forest_unlocked = data.get("forest_unlocked", false)
			purchased_shop_ids = data.get("purchased_shop_ids", [])
			saved_grid = data.get("saved_grid", [])
			active_quests = data.get("active_quests", [])
			quest_pool = data.get("quest_pool", [])
			last_coin_time = data.get("last_coin_time", Time.get_unix_time_from_system())
			last_crystal_time = data.get("last_crystal_time", Time.get_unix_time_from_system())
			bobby_hidden_quest_id = data.get("bobby_hidden_quest_id", -1)
			player_name = data.get("player_name", "Игрок")
			player_id = data.get("player_id", "")
			music_enabled = data.get("music_enabled", true)
			sound_enabled = data.get("sound_enabled", true)
			
			
			# Если ID пустой (первый запуск), создаем временный
			if player_id == "":
				player_id = _generate_random_id()
			var raw_inv = data.get("inventory", [])
			inventory = []
			for id in raw_inv: inventory.append(int(id))
			
			
			apply_upgraded_textures()

func apply_upgraded_textures():
	# КЛУМБА: Если куплено - ставим новую, иначе - старую
	if meadow_upgraded:
		items_data[101]["texture"] = load("res://Textures/gen_meadow_upgraded.png")
		items_data[101]["spawn_list"] = [1, 2, 2]
	else:
		items_data[101]["texture"] = load("res://Textures/gen_meadow.png")
		items_data[101]["spawn_list"] = [1, 1, 2]

	# ПРУД
	if pond_upgraded:
		items_data[102]["texture"] = load("res://Textures/gen_pond_upgraded.png")
		items_data[102]["spawn_list"] = [3, 4, 4]
	else:
		items_data[102]["texture"] = load("res://Textures/gen_pond.png")
		items_data[102]["spawn_list"] = [3, 4]

func get_bobby_text(scene_name: String) -> String:
	var step = int(tutorial_step)
	# Фейлсейф для шага 8
	if step == 7 and get_item_count_in_inventory(1) >= 3:
		step = 8
		tutorial_step = 8

	if dialogues_data.is_empty() or not dialogues_data.has(scene_name): return "..."
	var scene_texts = dialogues_data[scene_name]
	
	if scene_name == "MainMenu":
		if is_tutorial_done: return ""
		return scene_texts.get("step_0") if step <= 1 else scene_texts.get("already_started")
	if scene_name == "WorldMap":
		if step >= 2 and step <= 7: return scene_texts.get("step_2_to_7")
		return scene_texts.get("step_" + str(step), "...")
	if scene_name == "Game":
		if step <= 1: tutorial_step = 2; step = 2
		return scene_texts.get("step_" + str(step), "...")
	return "..."

func add_to_inventory(item_id: int) -> bool:
	if inventory.size() < max_inventory_slots:
		inventory.append(item_id)
		inventory_changed.emit()
		return true
	return false

func get_item_count_in_inventory(item_id: int) -> int:
	var c = 0
	for id in inventory: if int(id) == item_id: c += 1
	return c

func get_crystal_count() -> int: return get_item_count_in_inventory(60)

func complete_quest(quest_id: int) -> bool:
	for i in range(active_quests.size()):
		var q = active_quests[i]
		if int(q["id"]) == quest_id:
			var req_id = int(q["require_id"])
			var req_count = int(q["require_count"])
			if get_item_count_in_inventory(req_id) >= req_count:
				for n in range(req_count):
					inventory.remove_at(inventory.find(req_id))
				coins += int(q["reward"])
				active_quests.remove_at(i)
				if quest_id == 1: tutorial_step = 10
				if quest_id == 100: tutorial_step = 12; is_tutorial_done = true
				if quest_id != 100: check_for_next_quest()
				save_game(); inventory_changed.emit()
				return true
	return false

func check_for_next_quest():
	if quest_pool.size() > 0: active_quests.append(quest_pool.pop_front()); inventory_changed.emit()

func is_quest_id_completed(quest_id: int) -> bool:
	for q in active_quests: if int(q["id"]) == quest_id: return false
	for q in quest_pool: if int(q["id"]) == quest_id: return false
	return true
	
# Функция-заглушка, чтобы старые вызовы из BarnUI или Game не роняли игру
func check_quest_progress(_type, _data = null):
	# Пока нам не нужно ничего проверять здесь, так как Боби и Трекер 
	# работают через активные квесты и сигналы инвентаря.
	pass

# Генерация случайного ID (пока нет Яндекса)
func _generate_random_id() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result = ""
	for i in range(12):
		result += chars[randi() % chars.length()]
	return result

# Применение настроек звука к движку Godot
func apply_audio_settings():
	# Master — это главный канал, через который проходят все звуки и музыка
	var master_bus_idx = AudioServer.get_bus_index("Master")
	# Если мы хотим выключить ВООБЩЕ всё при отключении звуков:
	AudioServer.set_bus_mute(master_bus_idx, not sound_enabled)
	
	# Поиск отдельного канала для музыки
	var music_bus_idx = AudioServer.get_bus_index("Music")
	if music_bus_idx != -1: # Если канал "Music" существует
		AudioServer.set_bus_mute(music_bus_idx, not music_enabled)

# Функция для вызова из JavaScript (будущая связь с Яндекс.Играми)
func set_yandex_data(y_name: String, y_id: String, _y_avatar_url: String):
	player_name = y_name
	player_id = y_id
	# Логику загрузки аватарки по URL добавим позже
	save_game()
	inventory_changed.emit() # Чтобы обновить UI, если он открыт
