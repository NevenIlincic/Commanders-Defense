extends CharacterBody2D
class_name MyPlayer

var input_data: Dictionary
var inputs_list: Array[Dictionary] = []
const SERVER_SPEED = 20
const METER_TO_PIXEL = 32
const SERVER_DELTA = 0.016

const JUMP_VELOCITY = 12.0
const GRAVITY = -15.0 
var vertical_velocity = 0.0
var is_on_ground_local = false

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
		global_position.x += direction * SERVER_SPEED * METER_TO_PIXEL * delta
		print(delta)
	
	#Vertikalno kretanje (skok)
	#vertical_velocity += GRAVITY * delta
	#
	#if input_data["jump"] and is_on_ground_local:
		#vertical_velocity = JUMP_VELOCITY
		#is_on_ground_local = false
	#
	#global_position.y -= vertical_velocity * METER_TO_PIXEL * delta
	
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
	var target_position = Vector2(player_snapshot["position"][0] * METER_TO_PIXEL, global_position.y)
	var last_processed_id = player_snapshot["last_processed_input_id"]
	
	while len(inputs_list) > 0 and inputs_list[0]["input_id"] <= last_processed_id:
		inputs_list.remove_at(0)
	
	var distance_error = global_position.distance_to(target_position)
	if distance_error > 2.0:
		global_position = target_position
		
		for input_data in inputs_list:
			apply_movement_correction(input_data)

func apply_movement_correction(input_data: Dictionary):
	var dir = 0
	if input_data["move_left"]: dir -= 1
	if input_data["move_right"]: dir += 1
	
	global_position.x += dir * SERVER_SPEED * METER_TO_PIXEL * SERVER_DELTA
	
	# Ovde dodaj i skok/gravitaciju ako ih imaš u Rustu
	# npr. velocity.y += gravity * delta
