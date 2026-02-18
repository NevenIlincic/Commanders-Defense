extends Node2D

#CONNECTION
var socket := PacketPeerUDP.new()
var server_address := "127.0.0.1"
var server_port := 8080
var my_id: int = -1

var is_disconnecting: bool = false

var INPUT_DATA: Dictionary


#PING
var ping_interval = 1.0 # 1 sekunda
var time_since_last_ping = 0.0
var ping_start_time: int
var current_ping: int

func _ready() -> void:
	INPUT_DATA = {
		"type": "input",
		"input_id": 0,
		"move_left": false,
		"move_right": false,
		"jump": false,
		"shoot": false,
		"mouse_angle": 0.0,
		"command": "JOIN",
		"gun": "pistol",
		"bullet_spawn_position": null
	}

func _process(delta):
	handle_ping(delta)
func connect_to_socket():
	socket.connect_to_host(server_address, server_port)

func disconnect_from_socket():
	is_disconnecting = true
	INPUT_DATA["command"] = "DISCONNECT"
	
	socket.put_packet(JSON.stringify(INPUT_DATA).to_utf8_buffer())
	await get_tree().create_timer(0.1).timeout
	socket.close()

func send_data(input_data: Dictionary):
	var json_string = JSON.stringify(input_data)
	socket.put_packet(json_string.to_utf8_buffer())

func handle_ping(delta: float):
	time_since_last_ping += delta
	if time_since_last_ping >= ping_interval:
		send_ping()
		time_since_last_ping = 0.0

func send_ping():
	if my_id != -1:
		ping_start_time = Time.get_ticks_msec()
		var data = {
			"type": "ping",
			"timestamp": ping_start_time
		}
		send_data(data)

func calculate_ping(timestamp: int):
	current_ping = Time.get_ticks_msec() - timestamp

	
