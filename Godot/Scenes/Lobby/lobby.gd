extends Node2D
class_name Lobby


@onready var v_box_container: VBoxContainer = $ScrollContainer/VBoxContainer
const LOBBY_PLAYER_INFO_SCENE = preload("res://Scenes/Lobby/Lobby_Player_Info.tscn")
#LABELS
@onready var lobby_host_name_label: Label = $Lobby_Host_Name_Label
@onready var player_connected_label: Label = $Player_Connected_Label
#BUTTONS
@onready var start_lobby_button: Button = $Start_Lobby_Button
#ANIMATION PLAYER
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var lobby_started: bool = false
var players_lobby_row: Dictionary = {} #Kljuc ID, vrednost Node2D scena
var lobby_info: Dictionary = {
	"lobby_host_id": -1,
	"player_row_info": {}, #Kljuc ID, vrednost Node2D scena
	"players": {},
	"game_mode_settings": {},
	"map": "Grassy Field"
}
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
	Network.can_send_ping = false
	if not Network.is_connected_to_udp_socket:
		Network.connect_to_socket()
	if not Network.is_connected_to_websocket:
		Network.connect_to_websocket()
	Signals.UPDATE_LOBBY_UI.connect(parse_binary_lobby_info)
	Signals.HANDLE_LOBBY_UDP.connect(handle_udp_package_receive)
	MyHttpHandler.get_lobby_info()
	tower_hp_amount_label.text = str(tower_max_hp)
	CustomCursor.set_regular_cursor_visible()

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
		8: #ServerMessage::PlayerDisconnected
			parse_binary_player_disconnected(buffer)
		9: #ServerMessage::PlayerChangedSkin
			parse_binary_player_changed_skin(buffer)
		10: #ServerMessage::PlayerChangedReadyState
			parse_binary_player_changed_ready_state(buffer)
		11: #ServerMessage::TowerMaxHPChanged
			parse_binary_tower_max_hp_changed(buffer)

func parse_binary_lobby_info(buffer: StreamPeerBuffer):
	var players_info: Array = []
	var num_players = buffer.get_u64()
	print(num_players)
	for i in range(num_players):
		var player_info: Dictionary = create_player_info_snapshot(buffer)
		players_info.append(player_info)
		
	var message_type = buffer.get_u32()
	if message_type == 0: #GameModeSettings::TOWERS
		var towers_max_hp: int = buffer.get_u32()
		lobby_info["game_mode_settings"]["towers_max_hp"] = towers_max_hp
		tower_max_hp = towers_max_hp
		tower_hp_amount_label.text = str(towers_max_hp)
		var map_index = buffer.get_u8()
		lobby_info["map"] = maps_dict[map_index]
		map_name_label.text = lobby_info["map"]
	
	update_lobby_ui()

func parse_binary_player_disconnected(buffer: StreamPeerBuffer):
	var player_id = buffer.get_u32()
	var player_node = lobby_info["player_row_info"][player_id]
	player_node.queue_free()
	lobby_info["player_row_info"].erase(player_id)
	lobby_info["players"].erase(player_id)
	
	var host_id = buffer.get_u32()
	if host_id == Network.my_id:
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
	
	lobby_host_name_label.text = str(lobby_info["players"][host_id]["nickname"],"'s lobby")
	print("IGRAC SA ID-jem: " + str(player_id) + " se diskonektovao!")

func parse_binary_player_changed_skin(buffer:StreamPeerBuffer):
	var player_id: int = buffer.get_u32()
	var player_skin: int = buffer.get_u32()
	lobby_info["players"][player_id]["player_skin"] = player_skin
	update_lobby_ui()

func parse_binary_player_changed_ready_state(buffer: StreamPeerBuffer):
	var player_id: int = buffer.get_u32()
	lobby_info["players"][player_id]["is_ready"] = !lobby_info["players"][player_id]["is_ready"]
	update_lobby_ui()

func parse_binary_tower_max_hp_changed(buffer: StreamPeerBuffer):
	var tower_max_hp: int = buffer.get_u32()
	tower_hp_amount_label.text = str(tower_max_hp)

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
	
	lobby_info["players"][player_snapshot["player_id"]] = player_snapshot
	return player_snapshot

func spawn_player_info(): # Array[Dictionary]
	for player_snapshot in lobby_info["players"].values():
		var player_id = player_snapshot["player_id"]
		if lobby_info["player_row_info"].has(player_id):
			continue
		
		var player_info: LobbyPlayerInfo = LOBBY_PLAYER_INFO_SCENE.instantiate()
		player_info.player_id = player_id
		lobby_info["player_row_info"][player_id] = player_info
		v_box_container.add_child(player_info)
		#player_connected_label.text = str(player_snapshot["nickname"], " has just connected!")
		#animation_player.seek(0)
		#animation_player.play("Has_Just_Connected_Animation")

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
		
	for player_id in lobby_info["player_row_info"].keys():
		if player_id not in active_ids:
			var player_node = lobby_info["player_row_info"][player_id]
			player_node.queue_free()
			lobby_info["player_row_info"].erase(player_id)
			lobby_info["players"].erase(player_id)
			
func update_lobby_ui(): #Array[Dictionary]
	#check_disconnected(players_info)
	spawn_player_info()
	for player_row_info_id in lobby_info["player_row_info"].keys():
		var player_info: LobbyPlayerInfo = lobby_info["player_row_info"][player_row_info_id]
		player_info.handle_server_response(lobby_info["players"][player_row_info_id])
		

	
	

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
