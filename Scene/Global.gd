# Global.gd
extends Node

var coins := 100
var inventory := []
var is_tutorial_done := false
var saved_grid := []

var max_inventory_slots := 10 # Начальный лимит
const MAX_SLOTS_LIMIT = 30    # Максимальный предел
const BP_BASE_PRICE = 200     # Начальная цена
const BP_PRICE_STEP = 150     # На сколько дорожает каждый раз

var meadow_upgraded := false
var pond_upgraded := false
var mine_unlocked := false   # Флаг для Шахты
var forest_unlocked := false # Флаг для Леса

const SAVE_PATH = "user://savegame.json"

# --- ТЕКСТУРЫ БОБИ ---
var bobby_texture = preload("res://Textures/BobbyTalk.png") # Выбери самую лучшую картинку

var meadow_level := 1  # 1 - обычная, 2 - светящаяся, 3 - шахта
var pond_level := 1    # 1 - обычный, 2 - светящийся, 3 - лес

# --- СИГНАЛЫ ---
signal bobby_updated(text, mood) # Для обновления тутора
signal inventory_changed # Чтобы Боби видел сбор предметов
signal item_merged(item_id)       # Сработает при мердже
signal item_collected(item_id)    # Сработает при закидывании в рюкзак
signal item_sold(price)           # Сработает при продаже
signal coins_changed(total)       # Сработает при любом изменении денег
signal inventory_updated(count)   # Сработает при изменении кол-ва предметов в амбаре
signal shop_purchased(item_type)  # Сработает при покупке чего-либо

var unlocked_cells := 18  # Сколько ячеек открыто (начало с 18)
var purchased_shop_ids := [] # Купленные уникальные апгрейды
var tutorial_step := 0 # Храним шаг тут

# Теперь текстуры загружаются здесь и доступны везде!
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
	50: {
		"name": "Монетка",
		"price": 10,
		"texture": preload("res://Textures/coin_item.png") # Создай или вырежи иконку монетки
	},
	60: {
	"name": "Кристалл",
	"price": 0, # Цена 0 = нельзя продать
	"texture": preload("res://Textures/crystal_item.png") # Твой спрайт
	},
	101: {
		"name": "Клумба", 
		"spawn_list": [1, 1, 2],
		"max_charges": 15,
		"recharge_speed": 3.0,
		"texture": preload("res://Textures/gen_meadow.png")
	},
	102: {
		"name": "Пруд", 
		"spawn_list": [3, 4], 
		"max_charges": 5,
		"recharge_speed": 10.0,
		"texture": preload("res://Textures/gen_pond.png")
	},
	103: {
		"name": "Шахта",
		"spawn_list": [1, 2], # Шахта может давать камни (если введешь) или редкие семена
		"texture": preload("res://Textures/gen_mine.png")
	},
	104: {
		"name": "Волшебный лес",
		"texture": preload("res://Textures/gen_forest.png")
	}
}

var quest_list = [
	{
		"id": "tutorial_merge",
		"text": "Боби: 'Попробуй соединить две косточки, чтобы получить Росток!'",
		"type": "merge",
		"target_id": 2, # Ждем появления предмета с ID 2
		"required_count": 1,
		"reward_coins": 10
	},
	{
		"id": "fill_slots",
		"text": "Боби: 'Отлично! Теперь нам нужен запас. Заполни 5 любых слотов в амбаре.'",
		"type": "inventory_count",
		"target_count": 5,
		"reward_coins": 50
	},
	{
		"id": "sell_for_profit",
		"text": "Боби: 'Время делать бизнес! Продай всё из амбара и заработай первые деньги.'",
		"type": "sell_all",
		"reward_coins": 20
	},
	{
		"id": "upgrade_time",
		"text": "Боби: 'Клумба работает медленно. Давай купим улучшение в магазине!'",
		"type": "buy_upgrade",
		"target_type": "upgrade",
		"reward_coins": 100
	}
]

# Список квестов, которые появятся ПОСЛЕ первого
var quest_pool = [
	{
		"id": 2,
		"title": "Большой заказ",
		"description": "Мэрия просит 5 Ростков (Ур. 2) для городского парка.",
		"require_id": 2, 
		"require_count": 5,
		"reward": 150,
	},
	{
		"id": 3,
		"title": "Цветочное шоу",
		"description": "Собери 2 Бутона (Ур. 5), чтобы удивить соседей!",
		"require_id": 5, 
		"require_count": 2,
		"reward": 300,
	}
]

var current_quest_index = 0
var quest_progress = 0



var shop_items = [
	{
		"shop_id": "bp_1", 
		"type": "upgrade_backpack", 
		"price": 200, 
		"name": "Расширение рюкзака"
	},
	# Обычные расширения (до 30 ячейки)
	{"shop_id": "field_1", "type": "upgrade_field", "price": 2, "name": "Расширение: Зона 1", "amount": 6},
	{"shop_id": "field_2", "type": "upgrade_field", "price": 3, "name": "Расширение: Зона 2", "amount": 6},
	
	# РЕДКОЕ расширение (последние 6 ячеек)
	{
		"shop_id": "field_rare", 
		"type": "upgrade_field", 
		"price": 10, 
		"name": "Заброшенный сад (Финал)", 
		"amount": 6,
		"need_quest": 10 # ID квеста, который должен быть выполнен
	},
	# АПГРЕЙДЫ ВИЗУАЛА (для тех, что на поле)
	{"shop_id": "up_meadow", "type": "visual_upgrade", "gen_id": 101, "price": 5, "name": "Сияющая\nКлумба"},
	{"shop_id": "up_pond", "type": "visual_upgrade", "gen_id": 102, "price": 5, "name": "Магический\nПруд"},
	# ПАССИВНЫЕ ГЕНЕРАТОРЫ (невидимые)
	{"shop_id": "buy_mine", "type": "passive_gen", "price": 7, "name": "Древняя\nШахта", "desc": "Дает кристаллы"},
	{"shop_id": "buy_forest", "type": "passive_gen", "price": 7, "name": "Волшебный\nЛес", "desc": "Дает монеты"}
]

# Текущие активные заказы
var active_quests = [
	{
		"id": 1,
		"title": "Первый контракт",
		"description": "Боби нужно 3 Листика (Ур. 3) для начала работы.",
		"require_id": 3, 
		"require_count": 3,
		"reward": 100,
	}
]


func _ready():
	load_game()

# ФУНКЦИЯ СОХРАНЕНИЯ
func save_game():
	var save_data = {
		
		"meadow_upgraded": meadow_upgraded,
		"pond_upgraded": pond_upgraded,
		"coins": coins,
		"inventory": inventory,
		"is_tutorial_done": is_tutorial_done,
		"saved_grid": saved_grid,
		"max_inventory_slots": max_inventory_slots,
		"active_quests": active_quests,
		"quest_pool": quest_pool,
		"unlocked_cells": unlocked_cells,
		"purchased_shop_ids": purchased_shop_ids,
		"mine_unlocked": mine_unlocked,
		"forest_unlocked": forest_unlocked,
		"meadow_level": meadow_level,
		"pond_level": pond_level,
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		file.close()
		print("Игра сохранена. Лимит слотов: ", max_inventory_slots)

# ФУНКЦИЯ ЗАГРУЗКИ
func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.get_data()
			
			meadow_upgraded = data.get("meadow_upgraded", false)
			pond_upgraded = data.get("pond_upgraded", false)
			purchased_shop_ids = data.get("purchased_shop_ids", [])
			mine_unlocked = data.get("mine_unlocked", false)
			forest_unlocked = data.get("forest_unlocked", false)
			coins = data.get("coins", 100)
			is_tutorial_done = data.get("is_tutorial_done", false)
			saved_grid = data.get("saved_grid", [])
			max_inventory_slots = data.get("max_inventory_slots", 10)
			unlocked_cells = data.get("unlocked_cells", 18)
			purchased_shop_ids = data.get("purchased_shop_ids", [])
			meadow_level = data.get("meadow_level", 1)
			pond_level = data.get("pond_level", 1)
			
			apply_upgraded_textures()
			print("Данные загружены. Клумба улучшена: ", meadow_upgraded)
			
			# --- ЗАГРУЖАЕМ И ЧИНИМ АКТИВНЫЕ КВЕСТЫ ---
			var raw_active = data.get("active_quests", active_quests)
			active_quests = []
			for q in raw_active:
				q["id"] = int(q["id"])
				q["require_id"] = int(q["require_id"])
				q["require_count"] = int(q["require_count"])
				q["reward"] = int(q["reward"])
				active_quests.append(q)

			# --- ЗАГРУЖАЕМ И ЧИНИМ ОЧЕРЕДЬ КВЕСТОВ ---
			var raw_pool = data.get("quest_pool", quest_pool)
			quest_pool = []
			for q in raw_pool:
				q["id"] = int(q["id"])
				q["require_id"] = int(q["require_id"])
				q["require_count"] = int(q["require_count"])
				q["reward"] = int(q["reward"])
				quest_pool.append(q)
			
			# Чиним инвентарь (это у тебя уже было, но проверь)
			var raw_inventory = data.get("inventory", [])
			inventory = []
			for id in raw_inventory:
				inventory.append(int(id))
				
			print("Загрузка завершена успешно. Все ID конвертированы в int.")
			
func apply_upgraded_textures():
	if meadow_upgraded:
		items_data[101]["texture"] = load("res://Textures/gen_meadow_upgraded.png")
		items_data[101]["spawn_list"] = [1, 2, 2]
	if pond_upgraded:
		items_data[102]["texture"] = load("res://Textures/gen_pond_upgraded.png")
		items_data[102]["spawn_list"] = [3, 4, 4]

	# ПРУД / ЛЕС
	if pond_level == 2:
		items_data[102]["texture"] = load("res://Textures/gen_pond_upgraded.png")
	elif pond_level == 3:
		items_data[102]["texture"] = load("res://Textures/gen_forest.png")
		forest_unlocked = true # Включаем авто-монеты

func add_to_inventory(item_id: int):
	if inventory.size() < max_inventory_slots:
		inventory.append(item_id)
		inventory_changed.emit() # ОПОВЕЩАЕМ ВСЕХ
		return true
	return false

# Функция для проверки: сколько таких предметов сейчас в инвентаре?
func get_item_count_in_inventory(item_id: int) -> int:
	var count = 0
	for id in inventory:
		if id == item_id:
			count += 1
	return count

func check_quest_progress(type, data = null):
	if current_quest_index >= quest_list.size(): return
	
	var quest = quest_list[current_quest_index]
	if quest["type"] != type: return # Если сигнал не тот, что ждет квест — игнорим

	match type:
		"merge":
			if data == quest["target_id"]:
				complete_current_quest()
		"inventory_count":
			if inventory.size() >= quest["target_count"]:
				complete_current_quest()
		"sell_all":
			if inventory.size() == 0:
				complete_current_quest()
		"buy_upgrade":
			if data == quest["target_type"]:
				complete_current_quest()

func complete_current_quest():
	var quest = quest_list[current_quest_index]
	coins += quest.get("reward_coins", 0)
	current_quest_index += 1
	save_game()
	emit_signal("coins_changed", coins)
	print("Квест выполнен: ", quest["id"])

# Функция туториал завия квеста
func complete_quest(quest_id: int) -> bool:
	for i in range(active_quests.size()):
		var q = active_quests[i]
		if int(q["id"]) == quest_id:
			var req_id = int(q["require_id"])
			var req_count = int(q["require_count"])
			
			# Проверяем, реально ли у нас хватает предметов (на всякий случай)
			if get_item_count_in_inventory(req_id) >= req_count:
				# УДАЛЯЕМ ПРЕДМЕТЫ
				for n in range(req_count):
					var idx = inventory.find(req_id)
					if idx != -1:
						inventory.remove_at(idx)
						print("Удален предмет ", req_id, " из инвентаря.")
				
				# Даем награду
				coins += int(q["reward"])
				active_quests.remove_at(i)
				check_for_next_quest()
				
				# Флаг туториала
				if quest_id == 1:
					tutorial_step = 10  # БЫЛО 8, СТАВИМ 10
					print("Квест №1 сдан! Теперь шаг 10: Лавка.")
				
				active_quests.remove_at(i)
				check_for_next_quest()
				
				save_game()
				inventory_changed.emit() # Оповещаем всех (Боби, UI и т.д.)
				return true
			else:
				print("Ошибка: Предметов для сдачи не хватает!")
				return false
	return false
	
func is_quest_finished(id: int) -> bool:
	# Если квеста нет в активных и нет в пуле — значит он либо выполнен, либо еще не начат.
	# Для простоты: если мы прошли туториал (квест 1), можно считать прогресс.
	# Но лучше всего ориентироваться на ID выполненного квеста.
	# Если ты удалил квест с ID 10 из quest_pool и active_quests — значит он пройден.
	for q in active_quests:
		if q["id"] == id: return false
	for q in quest_pool:
		if q["id"] == id: return false
	return true
	
# Функция, которая берет следующий квест из очереди и делает его активным
func check_for_next_quest():
	if quest_pool.size() > 0:
		var next_q = quest_pool.pop_front() # Берем самый первый квест из запаса
		active_quests.append(next_q)
		print("Новое задание добавлено: ", next_q["title"])
	else:
		print("Все задания выполнены!")
		
func get_crystal_count() -> int:
	return get_item_count_in_inventory(60)
	
func get_backpack_upgrade_price() -> int:
	# Считаем сколько раз уже купили ( (текущие - начальные) / шаг )
	var upgrades_done = (max_inventory_slots - 10) / 2
	return BP_BASE_PRICE + (upgrades_done * BP_PRICE_STEP)
