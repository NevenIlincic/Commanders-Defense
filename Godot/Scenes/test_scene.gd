extends Node2D

var players: Dictionary = {}
var initial_data: Dictionary
var connection_retry_timer = 0.0

const PLAYER = preload("res://Scenes/Player.tscn")
const OTHER_PLAYER = preload("res://Scenes/Other_Player.tscn")

func _ready() -> void:
	LevelExporter.export_level_to_json()
	
	Network.connect_to_socket()
	initial_data = {
		"input_id": 0,
		"move_left": false,
		"move_right": false,
		"jump": false,
		"shoot": false,
		"mouse_angle": 0.0,
		"command": "JOIN"
	}
	
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Network.disconnect_from_socket()
		get_tree().quit()

func _process(delta):
	if Network.my_id == -1:
		connection_retry_timer += delta
		if connection_retry_timer >= 0.5:
			connection_retry_timer = 0.0
			initial_data["command"] = "JOIN"
			Network.send_data(initial_data)
			
	while Network.socket.get_available_packet_count() > 0:
		var packet = Network.socket.get_packet()
		var response = JSON.parse_string(packet.get_string_from_utf8())
		
		if response: 
			if response.has("players"):
				update_players(response["players"])
				
			elif response.has("my_id"):
				Network.my_id = response["my_id"]
				continue
				#if not players.has(p_id):
					#spawn_player(p_id)
				#
				#players[p_id].update_from_server(p_data)

func spawn_players(snapshot: Array): # Array[Dictionary]aa
	for player_snapshot in snapshot:
		var player_id = player_snapshot["id"]
		if players.has(player_id):
			continue
		
		if player_id == Network.my_id:
			var my_player = PLAYER.instantiate()
			my_player.name = "My_Player"
			self.add_child(my_player)
			players[player_id] = my_player
		else:
			var other_player = OTHER_PLAYER.instantiate()
			self.add_child(other_player)
			players[player_id] = other_player
	

func update_players(snapshot: Array):
	spawn_players(snapshot)
	for player_snapshot in snapshot:
		var player_id = player_snapshot["id"]
		
		if player_id == Network.my_id:
			var player_node: MyPlayer = players[player_id]
			player_node.handle_server_response(player_snapshot)
		else:
			var other_player_node: OtherPlayer = players[player_id]
			other_player_node.handle_server_response(player_snapshot)
