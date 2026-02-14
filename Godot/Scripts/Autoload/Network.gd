extends Node2D

var socket := PacketPeerUDP.new()
var server_address := "127.0.0.1"
var server_port := 8080
var my_id: int = -1

var is_disconnecting: bool = false

func connect_to_socket():
	socket.connect_to_host(server_address, server_port)

func disconnect_from_socket():
	is_disconnecting = true
	var dc_data = {
		"input_id": 0,
		"move_left": false,
		"move_right": false,
		"jump": false,
		"shoot": false,
		"mouse_angle": 0.0,
		"command": "DISCONNECT" # Ključna reč
	}
	socket.put_packet(JSON.stringify(dc_data).to_utf8_buffer())
	await get_tree().create_timer(0.1).timeout
	socket.close()

func send_data(input_data: Dictionary):
	var json_string = JSON.stringify(input_data)
	socket.put_packet(json_string.to_utf8_buffer())
