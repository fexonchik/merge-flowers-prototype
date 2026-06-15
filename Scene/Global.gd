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
var localization_data := {}
var quest_pool := []
var active_quests := []

const SAVE_PATH = "user://savegame.json"
const YANDEX_SAVE_KEY = "save"
const YANDEX_INIT_TIMEOUT_SECONDS := 8.0
const YANDEX_PLAYER_WAIT_SECONDS := 10.0

# --- НАСТРОЙКИ И ПРОФИЛЬ ---
var player_name := ""      # Имя (подгрузим с Яндекса или введет сам)
var player_id := ""            # Уникальный ID игрока
var current_language := "ru"   # Текущий язык интерфейса
var music_enabled := true      # Состояние музыки
var sound_enabled := true      # Состояние звуков
const VERSION := "v1.0.1"      # Версия игры для настроек

@onready var player_avatar: Texture2D = preload("res://Textures/BobbyAvatar.png")

var music_player: AudioStreamPlayer
var music_volume: float = 0.8
var sound_volume: float = 0.8
var _audio_suspended_by_visibility := false

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
signal language_changed(new_language)
signal yandex_player_ready
signal save_loaded

# --- YANDEX / WEB STATE ---
var yandex_sdk_ready := false
var yandex_player_ready_flag := false
var yandex_loading_completed := false
var yandex_runtime_started := false
var save_loaded_once := false
var pending_save_requested := false
var pending_flush_requested := false
var is_saving_to_cloud := false
var yandex_last_error := ""
var yandex_player_name := ""
var yandex_player_avatar_url := ""
var yandex_player_mode := ""

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
	{"shop_id": "up_meadow", "type": "visual_upgrade", "gen_id": 101, "price": 1200, "name": "Сияющая Клумба", "name_key": "shop_item_up_meadow"},
	{"shop_id": "up_pond", "type": "visual_upgrade", "gen_id": 102, "price": 3400, "name": "Магический Пруд", "name_key": "shop_item_up_pond"},
	{"shop_id": "buy_mine", "type": "passive_gen", "price": 7800, "name": "Древняя Шахта", "name_key": "shop_item_buy_mine"},
	{"shop_id": "buy_forest", "type": "passive_gen", "price": 9800, "name": "Волшебный Лес", "name_key": "shop_item_buy_forest"}
]

func _ready():
	load_configs()
	load_game()
	_sync_generator_state_defaults()
	setup_audio_player()
	setup_bgm()
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("apply_audio_settings")

func load_configs():
	backpack_data = _load_json("res://Data/backpack_upgrades.json")
	field_data = _load_json("res://Data/field_upgrades.json")
	dialogues_data = _load_json("res://Data/dialogues.json")
	localization_data = _load_json("res://Data/localization.json")
	var all_quests = _normalize_quest_list(_load_json("res://Data/quests.json"))
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

func save_game(flush: bool = false):
	var save_data = _build_save_data()
	_save_local_fallback(save_data)
	if _should_use_yandex_cloud_save():
		_queue_yandex_save(flush)

func _build_save_data() -> Dictionary:
	return {
		"player_name": player_name,
		"player_id": player_id,
		"current_language": current_language,
		"music_enabled": music_enabled,
		"sound_enabled": sound_enabled,
		"music_volume": music_volume,
		"sound_volume": sound_volume,
		"coins": coins,
		"inventory": inventory,
		"is_tutorial_done": is_tutorial_done,
		"saved_grid": saved_grid,
		"max_inventory_slots": max_inventory_slots,
		"unlocked_cells": unlocked_cells,
		"tutorial_step": tutorial_step,
		"purchased_shop_ids": purchased_shop_ids,
		"meadow_upgraded": meadow_upgraded,
		"pond_upgraded": pond_upgraded,
		"mine_unlocked": mine_unlocked,
		"forest_unlocked": forest_unlocked,
		"active_quests": active_quests,
		"quest_pool": quest_pool,
		"last_coin_time": last_coin_time,
		"last_crystal_time": last_crystal_time,
		"bobby_hidden_quest_id": bobby_hidden_quest_id,
		"generator_states": generator_states,
		"session_started_at": session_started_at,
		"onboarding_boost_used": onboarding_boost_used,
		"last_daily_ad_claim_date": last_daily_ad_claim_date,
		"last_secret_gift_claim_date": last_secret_gift_claim_date,
		"last_secret_gift_time": last_secret_gift_time,
		"backpack_upgrade_ad_counter": backpack_upgrade_ad_counter,
		"field_upgrade_ad_counter": field_upgrade_ad_counter,
		"generator_ad_claims": generator_ad_claims,
		"generator_ad_last_claim_time": generator_ad_last_claim_time,
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system()
	}

func _save_local_fallback(save_data: Dictionary) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		apply_upgraded_textures()
		_ensure_player_identity_defaults()
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			_apply_loaded_save_data(data)
		_ensure_player_identity_defaults()
		apply_upgraded_textures()

func _apply_loaded_save_data(data: Dictionary) -> void:
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
	active_quests = _normalize_quest_list(data.get("active_quests", []))
	quest_pool = _normalize_quest_list(data.get("quest_pool", []))
	last_coin_time = data.get("last_coin_time", Time.get_unix_time_from_system())
	last_crystal_time = data.get("last_crystal_time", Time.get_unix_time_from_system())
	bobby_hidden_quest_id = data.get("bobby_hidden_quest_id", -1)
	session_started_at = float(data.get("session_started_at", 0.0))
	onboarding_boost_used = data.get("onboarding_boost_used", false)
	player_name = str(data.get("player_name", ""))
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
	current_language = _normalize_supported_language(str(data.get("current_language", "ru")))
	music_enabled = data.get("music_enabled", true)
	sound_enabled = data.get("sound_enabled", true)
	_ensure_player_identity_defaults()
	var raw_inv = data.get("inventory", [])
	inventory = []
	for id in raw_inv:
		inventory.append(int(id))
	apply_upgraded_textures()

func _ensure_player_identity_defaults() -> void:
	if player_id == "":
		player_id = _generate_random_id()

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

	if dialogues_data.is_empty() or not dialogues_data.has(scene_name):
		return loc("hint_default")
	var scene_texts = dialogues_data[scene_name]
	var text_entry = null
	
	if scene_name == "MainMenu":
		if is_tutorial_done:
			return ""
		if step <= 0:
			text_entry = scene_texts.get("step_0")
		elif step == 1:
			text_entry = scene_texts.get("step_1")
		else:
			text_entry = scene_texts.get("already_started")
	elif scene_name == "WorldMap":
		if step >= 2 and step <= 7:
			text_entry = scene_texts.get("step_2_to_7")
		else:
			text_entry = scene_texts.get("step_" + str(step), loc("hint_default"))
	elif scene_name == "Game":
		if step <= 1:
			tutorial_step = 2
			step = 2
		text_entry = scene_texts.get("step_" + str(step), loc("hint_default"))
	else:
		return loc("hint_default")
	
	if text_entry is Dictionary:
		return str(text_entry.get(current_language, text_entry.get("ru", loc("hint_default"))))
	return str(text_entry)

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

func _normalize_localized_value(value):
	if value is Dictionary:
		var ru_value = value.get("ru", "")
		var en_value = value.get("en", ru_value)
		return {"ru": str(ru_value), "en": str(en_value)}
	return value

func _normalize_quest_data(quest):
	if quest is Dictionary:
		var normalized_quest = quest.duplicate(true)
		normalized_quest["title"] = _normalize_localized_value(normalized_quest.get("title", ""))
		normalized_quest["bobby_text"] = _normalize_localized_value(normalized_quest.get("bobby_text", ""))
		return normalized_quest
	return quest

func _normalize_quest_list(quests):
	var normalized_list = []
	if quests is Array:
		for quest in quests:
			normalized_list.append(_normalize_quest_data(quest))
	return normalized_list

func check_for_next_quest():
	if quest_pool.size() > 0:
		active_quests.append(_normalize_quest_data(quest_pool.pop_front()))
		inventory_changed.emit()

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
		AudioServer.set_bus_mute(music_bus_idx, _audio_suspended_by_visibility or not music_enabled)
		# Устанавливаем громкость из ползунка (переводим 0..1 в Децибелы)
		AudioServer.set_bus_volume_db(music_bus_idx, linear_to_db(music_volume))

	if sound_bus_idx != -1:
		AudioServer.set_bus_mute(sound_bus_idx, _audio_suspended_by_visibility or not sound_enabled)
		# Этот ползунок теперь влияет на ВСЕ звуки, у которых bus = "Sounds"
		AudioServer.set_bus_volume_db(sound_bus_idx, linear_to_db(sound_volume))

func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_suspend_audio_for_hidden_page(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_suspend_audio_for_hidden_page(false)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_suspend_audio_for_hidden_page(true)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_suspend_audio_for_hidden_page(false)

func _suspend_audio_for_hidden_page(should_suspend: bool) -> void:
	if _audio_suspended_by_visibility == should_suspend:
		return
	_audio_suspended_by_visibility = should_suspend
	apply_audio_settings()

func _normalize_supported_language(lang: String) -> String:
	var normalized := String(lang).to_lower()
	if normalized not in ["ru", "en"]:
		return "ru"
	return normalized

func _get_detected_web_language() -> String:
	if OS.get_name() != "Web":
		return ""
	if not Engine.has_singleton("JavaScriptBridge"):
		return ""
	var detected = JavaScriptBridge.eval("window.__YG_LANG || ''")
	return _normalize_supported_language(String(detected))

func is_yandex_sdk_ready() -> bool:
	if OS.get_name() != "Web":
		return true
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
	return bool(JavaScriptBridge.eval("window.__YG_SDK_READY === true"))

func is_yandex_player_ready() -> bool:
	if OS.get_name() != "Web":
		return false
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
	return bool(JavaScriptBridge.eval("window.__YG_PLAYER_READY === true"))

func apply_detected_language(force: bool = false) -> String:
	var detected_lang := _get_detected_web_language()
	if detected_lang.is_empty():
		return current_language
	if force or current_language != detected_lang:
		current_language = detected_lang
		language_changed.emit(current_language)
		inventory_changed.emit()
	return current_language

func loc(key: String, placeholders: Dictionary = {}) -> String:
	if localization_data.is_empty():
		return key
	var lang_dict = localization_data.get(current_language, localization_data.get("ru", {}))
	var text = str(lang_dict.get(key, key))
	for placeholder_key in placeholders.keys():
		text = text.replace("{" + str(placeholder_key) + "}", str(placeholders[placeholder_key]))
	return text

func set_language(lang: String) -> void:
	var normalized := _normalize_supported_language(lang)
	if current_language == normalized:
		return
	current_language = normalized
	save_game()
	language_changed.emit(current_language)
	inventory_changed.emit()

func toggle_language() -> void:
	if current_language == "ru":
		set_language("en")
	else:
		set_language("ru")

# Функция для вызова из JavaScript (будущая связь с Яндекс.Играми)
func get_default_player_name() -> String:
	return loc("player_name_default")

func get_localized_item_name(item_id: int, data: Dictionary = {}) -> String:
	match item_id:
		1:
			return loc("seed_name")
		2:
			return loc("sprout_name")
		3:
			return loc("leaf_name")
		4:
			return loc("young_sprout_name")
		5:
			return loc("bud_name")
		6:
			return loc("flower_name")
		7:
			return loc("rose_name")
		8:
			return loc("lush_bush_name")
		9:
			return loc("flower_cart_name")
		10:
			return loc("flower_truck_name")
		50:
			return loc("coin_name")
		60:
			return loc("crystal_name")
		101:
			return loc("meadow_name")
		102:
			return loc("pond_name")
	var fallback_name := str(data.get("name", "")).strip_edges()
	if fallback_name.is_empty():
		return loc("item_name_default")
	return fallback_name

func get_display_player_name() -> String:
	var trimmed_name := String(player_name).strip_edges()
	if trimmed_name.is_empty():
		return get_default_player_name()
	return trimmed_name

func set_yandex_data(y_name: String, y_id: String, _y_avatar_url: String):
	player_name = String(y_name).strip_edges()
	if not String(y_id).strip_edges().is_empty():
		player_id = String(y_id).strip_edges()
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

func initialize_yandex_runtime(wait_for_completion: bool = true) -> void:
	if yandex_loading_completed:
		return
	if yandex_runtime_started:
		if wait_for_completion and not save_loaded_once:
			await save_loaded
		return
	yandex_runtime_started = true
	call_deferred("_run_yandex_runtime_init")
	if wait_for_completion and not save_loaded_once:
		await save_loaded

func _run_yandex_runtime_init() -> void:
	if OS.get_name() != "Web":
		yandex_loading_completed = true
		save_loaded_once = true
		save_loaded.emit()
		return
	if not Engine.has_singleton("JavaScriptBridge"):
		yandex_loading_completed = true
		save_loaded_once = true
		save_loaded.emit()
		return
	await _wait_for_yandex_sdk_ready()
	await _wait_for_yandex_player_ready()
	_update_yandex_profile_from_js()
	await _load_yandex_cloud_save()
	if player_id == "":
		_ensure_player_identity_defaults()
		save_game(true)
	if pending_save_requested:
		await _flush_pending_cloud_save()

func _wait_for_yandex_sdk_ready() -> void:
	if OS.get_name() != "Web":
		return
	var waited := 0.0
	while waited < YANDEX_INIT_TIMEOUT_SECONDS:
		if is_yandex_sdk_ready():
			yandex_sdk_ready = true
			return
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	yandex_last_error = "Yandex SDK init timeout"

func _wait_for_yandex_player_ready() -> void:
	if OS.get_name() != "Web":
		return
	var waited := 0.0
	while waited < YANDEX_PLAYER_WAIT_SECONDS:
		if is_yandex_player_ready():
			yandex_player_ready_flag = true
			yandex_player_ready.emit()
			return
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	yandex_last_error = "Yandex Player init timeout"

func _load_yandex_cloud_save() -> void:
	yandex_loading_completed = true
	if not _should_use_yandex_cloud_save():
		save_loaded_once = true
		save_loaded.emit()
		return
	var raw = JavaScriptBridge.eval("window.__YG_getDataJson ? window.__YG_getDataJson() : ''")
	var save_json := String(raw)
	if save_json.is_empty() or save_json == "null" or save_json == "undefined":
		if FileAccess.file_exists(SAVE_PATH):
			load_game()
		save_loaded_once = true
		save_loaded.emit()
		return
	var parsed = JSON.parse_string(save_json)
	if parsed is Dictionary:
		var cloud_data = parsed.get(YANDEX_SAVE_KEY, parsed)
		if cloud_data is Dictionary and not cloud_data.is_empty():
			_apply_loaded_save_data(cloud_data)
			_save_local_fallback(_build_save_data())
	save_loaded_once = true
	save_loaded.emit()

func _queue_yandex_save(flush: bool) -> void:
	pending_save_requested = true
	pending_flush_requested = pending_flush_requested or flush
	if is_saving_to_cloud:
		return
		
	call_deferred("_run_deferred_yandex_save")

func _run_deferred_yandex_save() -> void:
	if not pending_save_requested:
		return
	await _flush_pending_cloud_save()

func _flush_pending_cloud_save() -> void:
	if not _should_use_yandex_cloud_save():
		return
	if is_saving_to_cloud:
		return
	is_saving_to_cloud = true
	while pending_save_requested:
		var flush_now := pending_flush_requested
		pending_save_requested = false
		pending_flush_requested = false
		var payload = _build_yandex_payload_json()
		var escaped_payload = JSON.stringify(payload)
		var flush_js = "true" if flush_now else "false"
		var result = JavaScriptBridge.eval("window.__YG_setDataJson ? window.__YG_setDataJson(%s, %s) : false" % [escaped_payload, flush_js])
		if not bool(result):
			yandex_last_error = "Yandex setData failed"
			break
	is_saving_to_cloud = false

func _build_yandex_payload_json() -> String:
	var payload = {
		YANDEX_SAVE_KEY: _build_save_data()
	}
	return JSON.stringify(payload)

func _should_use_yandex_cloud_save() -> bool:
	return OS.get_name() == "Web" and Engine.has_singleton("JavaScriptBridge") and is_yandex_player_ready()

func _update_yandex_profile_from_js() -> void:
	if OS.get_name() != "Web":
		return
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	var profile_json = String(JavaScriptBridge.eval("window.__YG_getPlayerProfileJson ? window.__YG_getPlayerProfileJson() : ''"))
	if profile_json.is_empty() or profile_json == "null" or profile_json == "undefined":
		return
	var parsed = JSON.parse_string(profile_json)
	if parsed is Dictionary:
		yandex_player_name = String(parsed.get("name", "")).strip_edges()
		yandex_player_avatar_url = String(parsed.get("avatar", "")).strip_edges()
		yandex_player_mode = String(parsed.get("mode", "")).strip_edges()
		var profile_id := String(parsed.get("id", "")).strip_edges()
		if not yandex_player_name.is_empty():
			player_name = yandex_player_name
		if not profile_id.is_empty():
			player_id = profile_id

func open_yandex_auth_dialog() -> bool:
	if OS.get_name() != "Web":
		return false
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
	var result = JavaScriptBridge.eval("window.__YG_openAuthDialog ? window.__YG_openAuthDialog() : false")
	return bool(result)

func is_yandex_player_authorized() -> bool:
	if OS.get_name() != "Web":
		return false
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
	return bool(JavaScriptBridge.eval("window.__YG_IS_AUTHORIZED === true"))
