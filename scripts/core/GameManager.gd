extends Node

var current_tick: int = 0
var player_nation_id: int = -1
var is_paused: bool = false
var game_speed: float = 1.0

var game_year: int = 2025
var game_month: int = 1
var game_day: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if is_paused:
		return
	var scaled_delta = delta * game_speed
	_process_game_tick(scaled_delta)

var _tick_accumulator: float = 0.0
const TICK_DURATION: float = 1.0

func _process_game_tick(delta: float) -> void:
	_tick_accumulator += delta
	if _tick_accumulator >= TICK_DURATION:
		_tick_accumulator -= TICK_DURATION
		current_tick += 1
		_advance_date()
		EventBus.game_tick.emit(current_tick)


func _advance_date() -> void:
	game_day += 1
	var days_in_month = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if game_day > days_in_month[game_month - 1]:
		game_day = 1
		game_month += 1
		if game_month > 12:
			game_month = 1
			game_year += 1

func set_speed(speed: float) -> void:
	game_speed = clamp(speed, 0.0, 5.0)

func toggle_pause() -> void:
	is_paused = not is_paused
