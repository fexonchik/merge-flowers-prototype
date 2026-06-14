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
var generator_states := {
	101: {"charges": 30, "max_charges": 30, "last_charge_time": 0.0},
	102: {"charges": 5, "max_charges": 5, "last_charge_time": 0.0}
}
var session_started_at: float = 0.0
var onboarding_boost_used := false

# --- РЕКЛАМА ---
const SECRET_GIFT_COOLDOWN_SECONDS := 25 * 60
const GENERATOR_AD_COOLDOWN_SECONDS := 2 * 60
var last_daily_ad_claim_date := ""
var last_secret_gift_claim_date := ""
var last_secret_gift_time := 0.0
var backpack_upgrade_ad_counter := 0
var field_upgrade_ad_counter := 0
var generator_ad_claims := {101: 0, 102: 0}
var generator_ad_last_claim_time := {101: 0.0, 102: 0.0}

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

@onready var player_avatar: Texture2D = preload("res://Textures/BobbyAvatar.png")

var music_player: AudioStreamPlayer
var music_volume: float = 0.8
var sound_volume: float = 0.8

@onready var sounds = {
	"click": {
		"stream": preload("res://Sounds/click.ogg"),
		"volume": 0.5  # 50% громкости
	},
	"spawn": {
		"stream": preload("res://Sounds/spawn.ogg"),
		"volume": 0.8  # 80% громкости
	},
	"merge": {
		"stream": preload("res://Sounds/merge.mp3"),
		"volume": 1.0  # 100% громкости
	},
	"collect": {
		"stream": preload("res://Sounds/collect.ogg"),
		"volume": 1.0
	},
	"coin": {
		"stream": preload("res://Sounds/coin.mp3"),
		"volume": 0.7
	},
	"error": {
		"stream": preload("res://Sounds/error.ogg"),
		"volume": 0.6
	}
}
var sfx_player: AudioStreamPlayer

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
	1: {"name": "Косточка", "merge_result": 2, "price": 3, "texture": preload("res://Textures/1_seed.png")},
	2: {"name": "Росток", "merge_result": 3, "price": 7, "texture": preload("res://Textures/2_sprout_thin.png")},
	3: {"name": "Листик", "merge_result": 4, "price": 15, "texture": preload("res://Textures/3_leaf.png")},
	4: {"name": "Молодой росток", "merge_result": 5, "price": 32, "texture": preload("res://Textures/4_sprout_soil.png")},
	5: {"name": "Бутон", "merge_result": 6, "price": 65, "texture": preload("res://Textures/5_bud.png")},
	6: {"name": "Цветок", "merge_result": 7, "price": 180, "texture": preload("res://Textures/6_flower.png")},
	7: {"name": "Роза", "merge_result": 8, "price": 420, "texture": preload("res://Textures/7_rose.png")},
	8: {"name": "Пышный куст", "merge_result": 9, "price": 900, "texture": preload("res://Textures/8_bush.png")},
	9: {"name": "Тележка цветов", "merge_result": 10, "price": 2200, "texture": preload("res://Textures/9_cart.png")},
	10: {"name": "Машина цветов", "merge_result": -1, "price": 6000, "texture": preload("res://Textures/10_truck.png")},
	50: {"name": "Монетка", "price": 10, "texture": preload("res://Textures/coin_item.png")},
	60: {"name": "Кристалл", "price": 0, "texture": preload("res://Textures/crystal_item.png")},
	101: {"name": "Клумба", "spawn_list": [1, 1, 2], "texture": preload("res://Textures/gen_meadow.png"), "cooldown": 40.0, "max_charges": 30},
	102: {"name": "Пруд", "spawn_list": [3, 4], "texture": preload("res://Textures/gen_pond.png"), "cooldown": 90.0, "max_charges": 5}
}

var shop_items = [
	{"shop_id": "up_meadow", "type": "visual_upgrade", "gen_id": 101, "price": 1200, "name": "Сияющая Клумба"},
	{"shop_id": "up_pond", "type": "visual_upgrade", "gen_id": 102, "price": 3400, "name": "Магический Пруд"},
	{"shop_id": "buy_mine", "type": "passive_gen", "price": 7800, "name": "Древняя Шахта"},
	{"shop_id": "buy_forest", "type": "passive_gen", "price": 9800, "name": "Волшебный Лес"}
]

func _ready():
	load_configs()
	load_game()
	_sync_generator_state_defaults()
	setup_audio_player()
	setup_bgm()
	call_deferred("apply_audio_settings")

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
		"music_volume": music_volume,
		"sound_volume": sound_volume,
		"coins": coins, "inventory": inventory, "is_tutorial_done": is_tutorial_done,
		"saved_grid": saved_grid, "max_inventory_slots": max_inventory_slots,
		"unlocked_cells": unlocked_cells, "tutorial_step": tutorial_step,
		"purchased_shop_ids": purchased_shop_ids, "meadow_upgraded": meadow_upgraded,
		"pond_upgraded": pond_upgraded, "mine_unlocked": mine_unlocked,
		"forest_unlocked": forest_unlocked, "active_quests": active_quests,
		"quest_pool": quest_pool, "last_coin_time": last_coin_time,
		"last_crystal_time": last_crystal_time, "bobby_hidden_quest_id": bobby_hidden_quest_id,
		"generator_states": generator_states,
		"session_started_at": session_started_at,
		"onboarding_boost_used": onboarding_boost_used,
		"last_daily_ad_claim_date": last_daily_ad_claim_date,
		"last_secret_gift_claim_date": last_secret_gift_claim_date,
		"last_secret_gift_time": last_secret_gift_time,
		"backpack_upgrade_ad_counter": backpack_upgrade_ad_counter,
		"field_upgrade_ad_counter": field_upgrade_ad_counter,
		"generator_ad_claims": generator_ad_claims,
		"generator_ad_last_claim_time": generator_ad_last_claim_time
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
			# Загружаем настройки звука (с дефолтными значениями 0.8, если файла нет)
			music_enabled = data.get("music_enabled", true)
			sound_enabled = data.get("sound_enabled", true)
			music_volume = data.get("music_volume", 0.8)
			sound_volume = data.get("sound_volume", 0.8)
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
			session_started_at = float(data.get("session_started_at", 0.0))
			onboarding_boost_used = data.get("onboarding_boost_used", false)
			player_name = data.get("player_name", "Игрок")
			last_daily_ad_claim_date = data.get("last_daily_ad_claim_date", "")
			last_secret_gift_claim_date = data.get("last_secret_gift_claim_date", "")
			last_secret_gift_time = float(data.get("last_secret_gift_time", 0.0))
			backpack_upgrade_ad_counter = int(data.get("backpack_upgrade_ad_counter", 0))
			field_upgrade_ad_counter = int(data.get("field_upgrade_ad_counter", 0))
			var loaded_generator_ad_claims = data.get("generator_ad_claims", {})
			generator_ad_claims[101] = int(loaded_generator_ad_claims.get("101", loaded_generator_ad_claims.get(101, 0)))
			generator_ad_claims[102] = int(loaded_generator_ad_claims.get("102", loaded_generator_ad_claims.get(102, 0)))
			var loaded_generator_ad_times = data.get("generator_ad_last_claim_time", {})
			generator_ad_last_claim_time[101] = float(loaded_generator_ad_times.get("101", loaded_generator_ad_times.get(101, 0.0)))
			generator_ad_last_claim_time[102] = float(loaded_generator_ad_times.get("102", loaded_generator_ad_times.get(102, 0.0)))
			var loaded_generator_states = data.get("generator_states", {})
			for gen_id in generator_states.keys():
				var loaded_state = loaded_generator_states.get(str(gen_id), loaded_generator_states.get(gen_id, {}))
				generator_states[gen_id]["charges"] = int(loaded_state.get("charges", generator_states[gen_id]["max_charges"]))
				generator_states[gen_id]["last_charge_time"] = float(loaded_state.get("last_charge_time", Time.get_unix_time_from_system()))
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

func _sync_generator_state_defaults():
	var now = Time.get_unix_time_from_system()
	if session_started_at <= 0.0:
		session_started_at = now
	if not onboarding_boost_used:
		generator_states[101]["charges"] = max(int(generator_states[101].get("charges", 0)), 30)
		generator_states[101]["max_charges"] = max(int(generator_states[101].get("max_charges", 1)), 30)
		generator_states[102]["charges"] = max(int(generator_states[102].get("charges", 0)), 5)
		generator_states[102]["max_charges"] = max(int(generator_states[102].get("max_charges", 1)), 5)
		onboarding_boost_used = true
	for gen_id in generator_states.keys():
		generator_states[gen_id]["max_charges"] = int(max(items_data[gen_id].get("max_charges", generator_states[gen_id].get("max_charges", 1)), generator_states[gen_id].get("max_charges", 1)))
		generator_states[gen_id]["charges"] = clamp(int(generator_states[gen_id].get("charges", generator_states[gen_id]["max_charges"])), 0, int(generator_states[gen_id]["max_charges"]))
		if float(generator_states[gen_id].get("last_charge_time", 0.0)) <= 0.0:
			generator_states[gen_id]["last_charge_time"] = now

func get_today_key() -> String:
	return Time.get_date_string_from_system()

func can_claim_daily_ad_bonus() -> bool:
	return last_daily_ad_claim_date != get_today_key()

func can_claim_secret_gift() -> bool:
	return get_secret_gift_cooldown_left() <= 0.0

func mark_daily_ad_claimed():
	last_daily_ad_claim_date = get_today_key()
	save_game()

func mark_secret_gift_claimed():
	last_secret_gift_claim_date = get_today_key()
	last_secret_gift_time = Time.get_unix_time_from_system()
	save_game()

func get_secret_gift_cooldown_left() -> float:
	var elapsed = Time.get_unix_time_from_system() - last_secret_gift_time
	return max(0.0, SECRET_GIFT_COOLDOWN_SECONDS - elapsed)

func can_claim_generator_ad(gen_id: int) -> bool:
	return get_generator_ad_cooldown_left(gen_id) <= 0.0

func get_generator_ad_cooldown_left(gen_id: int) -> float:
	var last_time = float(generator_ad_last_claim_time.get(gen_id, 0.0))
	var elapsed = Time.get_unix_time_from_system() - last_time
	return max(0.0, GENERATOR_AD_COOLDOWN_SECONDS - elapsed)

func mark_generator_ad_claimed(gen_id: int):
	generator_ad_last_claim_time[gen_id] = Time.get_unix_time_from_system()
	generator_ad_claims[gen_id] = int(generator_ad_claims.get(gen_id, 0)) + 1
	save_game()

func add_generator_ad_claim(gen_id: int):
	mark_generator_ad_claimed(gen_id)

func increment_upgrade_ad_counter(upgrade_type: String):
	if upgrade_type == "upgrade_backpack":
		backpack_upgrade_ad_counter += 1
		save_game()
		if backpack_upgrade_ad_counter % 2 == 0:
			Ads.show_interstitial_ad("backpack_upgrade")
	elif upgrade_type == "upgrade_field":
		field_upgrade_ad_counter += 1
		save_game()
		if field_upgrade_ad_counter % 2 == 0:
			Ads.show_interstitial_ad("field_upgrade")

func apply_upgraded_textures():
	# КЛУМБА: Если куплено - ставим новую, иначе - старую
	if meadow_upgraded:
		items_data[101]["texture"] = load("res://Textures/gen_meadow_upgraded.png")
		items_data[101]["spawn_list"] = [1, 2, 2]
		items_data[101]["cooldown"] = 28.0
	else:
		items_data[101]["texture"] = load("res://Textures/gen_meadow.png")
		items_data[101]["spawn_list"] = [1, 1, 2]
		items_data[101]["cooldown"] = 40.0

	# ПРУД
	if pond_upgraded:
		items_data[102]["texture"] = load("res://Textures/gen_pond_upgraded.png")
		items_data[102]["spawn_list"] = [3, 4, 4]
		items_data[102]["cooldown"] = 65.0
	else:
		items_data[102]["texture"] = load("res://Textures/gen_pond.png")
		items_data[102]["spawn_list"] = [3, 4]
		items_data[102]["cooldown"] = 90.0

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
	var music_bus_idx = AudioServer.get_bus_index("Music")
	var sound_bus_idx = AudioServer.get_bus_index("Sounds")

	if music_bus_idx != -1:
		# Мьютим (выключаем), если кнопка выключена
		AudioServer.set_bus_mute(music_bus_idx, not music_enabled)
		# Устанавливаем громкость из ползунка (переводим 0..1 в Децибелы)
		AudioServer.set_bus_volume_db(music_bus_idx, linear_to_db(music_volume))

	if sound_bus_idx != -1:
		AudioServer.set_bus_mute(sound_bus_idx, not sound_enabled)
		# Этот ползунок теперь влияет на ВСЕ звуки, у которых bus = "Sounds"
		AudioServer.set_bus_volume_db(sound_bus_idx, linear_to_db(sound_volume))

# Функция для вызова из JavaScript (будущая связь с Яндекс.Играми)
func set_yandex_data(y_name: String, y_id: String, _y_avatar_url: String):
	player_name = y_name
	player_id = y_id
	# Логику загрузки аватарки по URL добавим позже
	save_game()
	inventory_changed.emit() # Чтобы обновить UI, если он открыт
	
func setup_audio_player():
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	sfx_player.bus = "Sounds" # Убедись, что создал шину Sounds в Audio вкладке

func play_sound(sound_name: String):
	if not sound_enabled: return
	if sounds.has(sound_name):
		var sound_data = sounds[sound_name]
		var temp_player = AudioStreamPlayer.new()
		add_child(temp_player)
		temp_player.stream = sound_data["stream"]
		
		# ВАЖНО: ВСЕ ЭФФЕКТЫ ПРИВЯЗЫВАЕМ К ШИНЕ SOUNDS
		temp_player.bus = "Sounds" 
		
		temp_player.volume_db = linear_to_db(sound_data["volume"])
		temp_player.pitch_scale = randf_range(0.95, 1.05)
		temp_player.play()
		temp_player.finished.connect(temp_player.queue_free)
		
func setup_bgm():
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	# Укажи путь к своей музыке!
	music_player.stream = preload("res://Sounds/Spring Farm.ogg") 
	music_player.bus = "Music" # ПРИВЯЗЫВАЕМ К ШИНЕ МУЗЫКИ
	music_player.autoplay = true
	music_player.play()
