extends CharacterBody2D
class_name MyPlayer

var input_data: Dictionary
var inputs_list: Array[Dictionary] = []
const SERVER_SPEED = 10
const METER_TO_PIXEL = 32
const SERVER_DELTA = 0.016

const JUMP_VELOCITY = 12.0
const GRAVITY = -15.0 
var vertical_velocity = 0.0
var is_on_ground_local = false

var can_move_left = true
var can_move_right = true

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $Sprite2D

func _ready() -> void:
	input_data = {
		"input_id": 0,
		"move_left": false,
		"move_right": false,
		"jump": false,
		"shoot": false,
		"mouse_angle": 0.0,
		"command": null
	}

func _physics_process(delta: float) -> void:
	handle_inputs(delta)

func handle_inputs(delta: float):
	input_data["move_left"] = Input.is_action_pressed("left")
	input_data["move_right"] = Input.is_action_pressed("right")
	input_data["jump"] = Input.is_action_pressed("jump")
	input_data["shoot"] = Input.is_action_pressed("shoot")
	input_data["mouse_angle"] = get_local_mouse_position().angle()
	
	var direction = Input.get_axis("left", "right")
	if direction:
		animation_player.play("walking_animation")
		sprite_2d.flip_h = (direction < 0)
	else:
		animation_player.stop()
	
	if direction == 1.0 and can_move_right:
		global_position.x += direction * SERVER_SPEED * METER_TO_PIXEL * delta
	if direction == -1.0 and can_move_left:
		global_position.x += direction * SERVER_SPEED * METER_TO_PIXEL * delta

	input_data["input_id"] += 1
	send_data()
	
func send_data():
	if !Network.is_disconnecting:
		var data_to_send = input_data.duplicate(true)
		Network.send_data(data_to_send)
		inputs_list.append(data_to_send)
		#if inputs_list.size() > 120: 
			#inputs_list.remove_at(0)

func handle_server_response(player_snapshot: Dictionary):
	var target_position = Vector2(player_snapshot["position"][0] * METER_TO_PIXEL, player_snapshot["position"][1] * METER_TO_PIXEL)
	var last_processed_id = player_snapshot["last_processed_input_id"]
	
	while len(inputs_list) > 0 and inputs_list[0]["input_id"] <= last_processed_id:
		inputs_list.remove_at(0)
		
	var distance_error = global_position.distance_to(target_position)
	var error_x = abs(global_position.x - target_position.x)
	var error_y = abs(global_position.y - target_position.y)
	# Ako je greška mala (npr. manja od 2px), ne diraj ništa - klijent i server su usklađeni
	if error_x > 10.0 or error_y > 10.0:
		# Ako je greška primetna, uradi teleport na zadnju potvrđenu poziciju...
		global_position = target_position
		# ...i odmah "premotaj" sve inpute koje server još nije video
		for input_item in inputs_list:
			apply_movement_correction(input_item)
	else:
		global_position = lerp(global_position, target_position, 40*SERVER_DELTA)

func apply_movement_correction(input_data: Dictionary):
	var dir = 0
	if input_data["move_left"]: dir -= 1
	if input_data["move_right"]: dir += 1
	
	global_position.x += dir * SERVER_SPEED * METER_TO_PIXEL * SERVER_DELTA
	global_position.y += 15*METER_TO_PIXEL*SERVER_DELTA
	
	if dir > 0:
		sprite_2d.flip_h = false
	elif dir < 0:
		sprite_2d.flip_h = true
	

func _on_right_indicator_area_entered(area: Area2D) -> void:
	if area.is_in_group("solids"):
		can_move_right = false
