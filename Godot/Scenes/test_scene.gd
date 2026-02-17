extends Node2D

var players: Dictionary = {}
var initial_data: Dictionary
var connection_retry_timer = 0.0

const PLAYER = preload("res://Scenes/Player.tscn")
const OTHER_PLAYER = preload("res://Scenes/Other_Player/Other_Player.tscn")

func _ready() -> void:
	#LevelExporter.export_level_to_json()
	LevelManager.set_current_level_node(self)
	
	Network.connect_to_socket()
	Network.INPUT_DATA["command"] = "JOIN"	
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Network.disconnect_from_socket()
		get_tree().quit()

func _process(delta):
	if Network.my_id == -1:
		connection_retry_timer += delta
		if connection_retry_timer >= 0.5:
			connection_retry_timer = 0.0
			Network.INPUT_DATA["command"] = "JOIN"
			Network.send_data(Network.INPUT_DATA)
			
	while Network.socket.get_available_packet_count() > 0:
		var packet = Network.socket.get_packet()
		var response = JSON.parse_string(packet.get_string_from_utf8())
		
		if response: 
			if response.has("players"):
				update_players(response["players"])
				
			elif response.has("my_id"):
				Network.my_id = response["my_id"]
				continue
			
			if response.has("type") and response["type"] == "pong":
				Network.calculate_ping(response["timestamp"])
	
func spawn_players(snapshot: Array): # Array[Dictionary]
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
	check_disconnected(snapshot)
	spawn_players(snapshot)
	
	for player_snapshot in snapshot:
		var player_id = player_snapshot["id"]
		
		if player_id == Network.my_id:
			var player_node: MyPlayer = players[player_id]
			player_node.handle_server_response(player_snapshot)
		else:
			var other_player_node: OtherPlayer = players[player_id]
			other_player_node.handle_server_response(player_snapshot)
			
func check_disconnected(snapshot: Array):
	var active_ids = []
	for player_snapshot in snapshot:
		active_ids.append(player_snapshot["id"])
	
	for player_id in players.keys():
		if player_id not in active_ids:
			var player_node = players[player_id]
			player_node.queue_free()
			players.erase(player_id)
			print("IGRAC SA ID-jem: " + str(player_id) + " se diskonektovao!")
