extends CharacterBody2D

var input_data: Dictionary
var inputs_list: Array[Dictionary] = []
const SERVER_SPEED = 20
const METER_TO_PIXEL = 32

const JUMP_VELOCITY = 12.0
const GRAVITY = -15.0 
var vertical_velocity = 0.0
var is_on_ground_local = false
var connection_retry_timer: float = 0.0

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


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if Network.my_id == -1:
		connection_retry_timer += delta
		if connection_retry_timer >= 0.5:
			connection_retry_timer = 0.0
			var initial_data = input_data.duplicate(true)
			initial_data["command"] = "JOIN"
			Network.send_data(initial_data)
	else:
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
