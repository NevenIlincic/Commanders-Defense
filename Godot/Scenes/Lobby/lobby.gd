extends Node2D


@onready var v_box_container: VBoxContainer = $ScrollContainer/VBoxContainer
const LOBBY_PLAYER_INFO_SCENE = preload("res://Scenes/Lobby/Lobby_Player_Info.tscn")

var lobby_started: bool = false
var players: Dictionary = {}

func _ready() -> void:
	Network.connect_to_socket()
	Signals.UPDATE_LOBBY_UI.connect(parse_binary_lobby_info)
	Signals.HANDLE_LOBBY_UDP.connect(handle_udp_package_receive)
	MyHttpHandler.get_lobby_info()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("start_lobby") and not lobby_started:
		lobby_started = true
		Network.can_send_ping = true
		MyHttpHandler.start_lobby()

func handle_udp_package_receive(buffer: StreamPeerBuffer, message_type: int):
	match message_type:
		6: #ServerMessage::GameStarted
			get_tree().change_scene_to_file("res://Scenes/Test_Scene.tscn")
		7: #ServerMessage::LobbyInfo
			parse_binary_lobby_info(buffer)

func parse_binary_lobby_info(buffer: StreamPeerBuffer):
	var players_info: Array = []
	var num_players = buffer.get_u64()
	for i in range(num_players):
		var player_info: Dictionary = create_player_info_snapshot(buffer)
		players_info.append(player_info)
	
	update_lobby_ui(players_info)
	
func create_player_info_snapshot(buffer: StreamPeerBuffer):
	var player_snapshot = {}
	player_snapshot["player_id"] = buffer.get_u32()
	var nickname_length = buffer.get_u64() 
	player_snapshot["nickname"] = buffer.get_utf8_string(nickname_length)
	player_snapshot["is_ready"] = buffer.get_u8() != 0
	player_snapshot["is_host"] = buffer.get_u8() != 0
	
	return player_snapshot

func spawn_player_info(snapshot: Array): # Array[Dictionary]
	for player_snapshot in snapshot:
		var player_id = player_snapshot["player_id"]
		if players.has(player_id):
			continue
		
		var player_info: LobbyPlayerInfo = LOBBY_PLAYER_INFO_SCENE.instantiate()
		player_info.player_id = player_id
		players[player_id] = player_info
		v_box_container.add_child(player_info)

func check_disconnected(snapshot: Array):
	var active_ids = []
	for player_snapshot in snapshot:
		active_ids.append(player_snapshot["player_id"])
	
	for player_id in players.keys():
		if player_id not in active_ids:
			var player_node = players[player_id]
			player_node.queue_free()
			players.erase(player_id)
			v_box_container.remove_child(player_node)
			
func update_lobby_ui(players_info: Array): #Array[Dictionary]
	check_disconnected(players_info)
	spawn_player_info(players_info)
	#for single_row in v_box_container.get_children():
		#single_row.queue_free()
	
	for player_snapshot in players_info:
		var player_info: LobbyPlayerInfo = players[player_snapshot["player_id"]]
		player_info.handle_server_response(player_snapshot)
