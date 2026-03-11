extends Node2D
class_name Lobby


@onready var v_box_container: VBoxContainer = $ScrollContainer/VBoxContainer
const LOBBY_PLAYER_INFO_SCENE = preload("res://Scenes/Lobby/Lobby_Player_Info.tscn")
@onready var lobby_host_name_label: Label = $Lobby_Host_Name_Label
@onready var start_lobby_button: Button = $Start_Lobby_Button

var lobby_started: bool = false
var players: Dictionary = {}

var maps_dict: Dictionary = {
	0: "Grassy Field",
	1: "Grassy Field 2"
}

#SELECTED MAP
@onready var map_name_label: Label = $Selected_Map/Map_Name_Label
@onready var map_left_button: TextureButton = $Selected_Map/Left_Button
@onready var map_right_button: TextureButton = $Selected_Map/Right_Button

#TOWER SETTINGS
@onready var tower_hp_amount_label: Label = $Tower_Health_Settings/Tower_HP_Amount_Label
@onready var tower_left_button: TextureButton = $Tower_Health_Settings/Left_Button
@onready var tower_right_button: TextureButton = $Tower_Health_Settings/Right_Button
var tower_max_hp: int = 2000


func _ready() -> void:
	Network.connect_to_socket()
	Signals.UPDATE_LOBBY_UI.connect(parse_binary_lobby_info)
	Signals.HANDLE_LOBBY_UDP.connect(handle_udp_package_receive)
	MyHttpHandler.get_lobby_info()
	tower_hp_amount_label.text = str(tower_max_hp)

func _process(delta: float) -> void:
	pass

func handle_udp_package_receive(buffer: StreamPeerBuffer, message_type: int):
	match message_type:
		6: #ServerMessage::GameStarted
			lobby_started = true
			Network.can_send_ping = true
			get_tree().change_scene_to_file("res://Scenes/Test_Scene.tscn")
		7: #ServerMessage::LobbyInfo
			parse_binary_lobby_info(buffer)

func parse_binary_lobby_info(buffer: StreamPeerBuffer):
	var players_info: Array = []
	var num_players = buffer.get_u64()
	for i in range(num_players):
		var player_info: Dictionary = create_player_info_snapshot(buffer)
		players_info.append(player_info)
		
	var message_type = buffer.get_u32()
	var game_mode_settings: Dictionary = {}
	if message_type == 0: #GameModeSettings::TOWERS
		game_mode_settings["towers_max_hp"] = buffer.get_32()
		tower_max_hp = game_mode_settings["towers_max_hp"]
		tower_hp_amount_label.text = str(game_mode_settings["towers_max_hp"])
		var map_index = buffer.get_u8()
		map_name_label.text = maps_dict[map_index]
				
	update_lobby_ui(players_info)
	
func create_player_info_snapshot(buffer: StreamPeerBuffer):
	var player_snapshot = {}
	player_snapshot["player_id"] = buffer.get_u32()
	var nickname_length = buffer.get_u64() 
	player_snapshot["nickname"] = buffer.get_utf8_string(nickname_length)
	player_snapshot["player_skin"] = buffer.get_u32() #PlayerSkin
	player_snapshot["is_ready"] = buffer.get_u8() != 0
	player_snapshot["is_host"] = buffer.get_u8() != 0
	if player_snapshot["is_host"]:
		lobby_host_name_label.text = str(player_snapshot["nickname"],"'s lobby")
		if player_snapshot["player_id"] == Network.my_id:
			map_left_button.visible = true
			map_right_button.visible = true
			tower_left_button.visible = true
			tower_right_button.visible = true
			start_lobby_button.visible = true
		else:
			map_left_button.visible = false
			map_right_button.visible = false
			tower_left_button.visible = false
			tower_right_button.visible = false
			start_lobby_button.visible = false
			
			
		
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
		
		if player_id != Network.my_id:
			if player_snapshot["is_host"]:
				hide_only_host_visible_elements()

func hide_only_host_visible_elements():
	start_lobby_button.visible = false
	map_left_button.visible = false
	map_right_button.visible = false
	tower_left_button.visible = false
	tower_right_button.visible = false

func check_disconnected(snapshot: Array):
	var active_ids = []
	for player_snapshot in snapshot:
		active_ids.append(player_snapshot["player_id"])
		
	for player_id in players.keys():
		if player_id not in active_ids:
			var player_node = players[player_id]
			player_node.queue_free()
			players.erase(player_id)
			
func update_lobby_ui(players_info: Array): #Array[Dictionary]
	check_disconnected(players_info)
	spawn_player_info(players_info)

	for player_snapshot in players_info:
		var player_info: LobbyPlayerInfo = players[player_snapshot["player_id"]]
		player_info.handle_server_response(player_snapshot)
	
	

func _on_start_lobby_button_pressed() -> void:
	if not lobby_started:
		MyHttpHandler.start_lobby()


func _on_right_button_pressed() -> void:
	tower_max_hp += 100
	tower_hp_amount_label.text = str(tower_max_hp)
	MyHttpHandler.change_tower_max_hp(tower_max_hp)


func _on_left_button_pressed() -> void:
	tower_max_hp -= 100
	if tower_max_hp <= 0:
		tower_max_hp = 100
		
	tower_hp_amount_label.text = str(tower_max_hp)
	MyHttpHandler.change_tower_max_hp(tower_max_hp)


	


func _on_leave_lobby_button_pressed() -> void:
	MyHttpHandler.leave_lobby()
