extends Node2D
class_name Lobby


@onready var v_box_container: VBoxContainer = $ScrollContainer/VBoxContainer
const LOBBY_PLAYER_INFO_SCENE = preload("res://Scenes/Lobby/Lobby_Player_Info.tscn")
const PLAYER_MESSAGE_SCENE = preload("res://Scenes/Lobby/Player_Message.tscn")
#LABELS
@onready var lobby_host_name_label: Label = $Lobby_Host_Name_Label
@onready var player_connected_label: Label = $Player_Connected_Label
#BUTTONS
@onready var start_lobby_button: Button = $Start_Lobby_Button
#ANIMATION PLAYER
@onready var animation_player: AnimationPlayer = $AnimationPlayer

#CHAT
@onready var messages_container: VBoxContainer = $Chat_Scroll_Container/Messages_Container

var IS_HOST: bool = false

var lobby_started: bool = false
var players_lobby_row: Dictionary = {} #Kljuc ID, vrednost Node2D scena
var lobby_info: Dictionary = {
	"lobby_host_id": -1,
	"player_row_info": {}, #Kljuc ID, vrednost Node2D scena
	"players": {},
	"game_mode_settings": {},
	"map": "Grassy Field",
	"has_started": false
}
var maps_dict: Dictionary = {
	0: "Grassy Field",
	1: "Grassy Field 2"
}


#SELECTED MAP
@onready var map_name_label: Label = $Selected_Map/Map_Name_Label
@onready var select_map_left_button: TextureButton = $Selected_Map/Select_Map_Left_Button
@onready var select_map_right_button: TextureButton = $Selected_Map/Select_Map_Right_Button

#TOWER SETTINGS
@onready var tower_hp_amount_label: Label = $Tower_Health_Settings/Tower_HP_Amount_Label
@onready var tower_left_button: TextureButton = $Tower_Health_Settings/Left_Button
@onready var tower_right_button: TextureButton = $Tower_Health_Settings/Right_Button
@onready var tower_health_settings: HBoxContainer = $Tower_Health_Settings

var tower_max_hp: int = 2000

#FFA SETTINGS
@onready var ffa_players_to_kill_settings: HBoxContainer = $FFA_Players_To_Kill_Settings
@onready var kills_to_win_amount_label: Label = $FFA_Players_To_Kill_Settings/Kills_To_Win_Amount_Label
@onready var players_to_kill_left_button: TextureButton = $FFA_Players_To_Kill_Settings/Players_To_Kill_Left_Button
@onready var players_to_kill_right_button: TextureButton = $FFA_Players_To_Kill_Settings/Players_To_Kill_Right_Button

var ffa_kills_to_win: int = 25

#CHAT
@onready var message_input: LineEdit = $Message_Input

@onready var join_button: Button = $Join_Button


func _ready() -> void:
	Network.can_send_ping = false
	if not Network.is_connected_to_udp_socket:
		Network.connect_to_socket()
	if not Network.is_connected_to_websocket:
		Network.connect_to_websocket()
	Signals.UPDATE_LOBBY_UI.connect(parse_binary_lobby_info)
	Signals.HANDLE_LOBBY_UDP.connect(handle_udp_package_receive)
	MyHttpHandler.get_lobby_info()
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
		12: #ServerMessage::PlayerMessage
			parse_binary_player_message(buffer)
		13: #ServerMessage::PlayerConnected
			parse_binary_player_connected(buffer)
		15: #ServerMessage::KillsToWinChanged
			parse_binary_kills_to_win_changed(buffer)

func parse_binary_lobby_info(buffer: StreamPeerBuffer):
	var num_players = buffer.get_u64()
	for i in range(num_players):
		create_player_info_snapshot(buffer)
		
	var message_type = buffer.get_u32()
	if message_type == 0: #GameModeSettings::TOWERS
		ffa_players_to_kill_settings.visible = false
		tower_health_settings.visible = true
		var towers_max_hp: int = buffer.get_u32()
		lobby_info["game_mode_settings"]["towers_max_hp"] = towers_max_hp
		tower_max_hp = towers_max_hp
		tower_hp_amount_label.text = str(towers_max_hp)
		var map_index = buffer.get_u8()
		lobby_info["map"] = maps_dict[map_index]
		map_name_label.text = lobby_info["map"]
		LevelManager.CURRENT_LEVEL_GAME_MODE = "TOWERS"
	elif message_type == 1: #GameModeSettings::FFA
		tower_health_settings.visible = false
		ffa_players_to_kill_settings.visible = true
		ffa_kills_to_win = buffer.get_u32()
		kills_to_win_amount_label.text = str(ffa_kills_to_win)
		lobby_info["game_mode_settings"]["kills_to_win"] = ffa_kills_to_win
		LevelManager.FFA_KILLS_TO_WIN = ffa_kills_to_win
		LevelManager.CURRENT_LEVEL_GAME_MODE = "FFA"
		var map_index = buffer.get_u8()
		lobby_info["map"] = maps_dict[map_index]
		map_name_label.text = lobby_info["map"]
	
	lobby_info["has_started"] = buffer.get_u8() != 0
	set_host_elements_visible()	
	update_lobby_ui()

func set_host_elements_visible():
	if IS_HOST:
		select_map_left_button.visible = true
		select_map_right_button.visible = true
		start_lobby_button.visible = true
		if LevelManager.CURRENT_LEVEL_GAME_MODE == "TOWERS":
			tower_left_button.visible = true
			tower_right_button.visible = true
			ffa_players_to_kill_settings.visible = false
		elif LevelManager.CURRENT_LEVEL_GAME_MODE == "FFA":
			tower_health_settings.visible = false
			players_to_kill_left_button.visible = true
			players_to_kill_right_button.visible = true
	else:
		select_map_left_button.visible = false
		select_map_right_button.visible = false
		tower_left_button.visible = false
		tower_right_button.visible = false
		start_lobby_button.visible = false
		players_to_kill_left_button.visible = false
		players_to_kill_right_button.visible = false
		start_lobby_button.visible = false

func parse_binary_player_disconnected(buffer: StreamPeerBuffer):
	var player_id = buffer.get_u32()
	var player_node = lobby_info["player_row_info"][player_id]
	
	add_joining_leaving_message(lobby_info["players"][player_id]["nickname"], false)
	
	player_node.queue_free()
	lobby_info["player_row_info"].erase(player_id)
	lobby_info["players"].erase(player_id)
	
	var host_id = buffer.get_u32()
	if host_id == Network.my_id:
		IS_HOST = true
	else:
		IS_HOST = false

	set_host_elements_visible()
	lobby_host_name_label.text = str(lobby_info["players"][host_id]["nickname"],"'s lobby")

func parse_binary_player_changed_skin(buffer:StreamPeerBuffer):
	var player_id: int = buffer.get_u32()
	var player_skin: int = buffer.get_u8()
	lobby_info["players"][player_id]["player_skin"] = player_skin
	update_lobby_ui()

func parse_binary_player_changed_ready_state(buffer: StreamPeerBuffer):
	var player_id: int = buffer.get_u32()
	lobby_info["players"][player_id]["is_ready"] = !lobby_info["players"][player_id]["is_ready"]
	#print(str(lobby_info["players"][player_id]["nickname"],": ", player_id))
	update_lobby_ui()

func parse_binary_tower_max_hp_changed(buffer: StreamPeerBuffer):
	tower_max_hp = buffer.get_u32()
	tower_hp_amount_label.text = str(tower_max_hp)

func parse_binary_player_message(buffer: StreamPeerBuffer):
	var player_id: int = buffer.get_u32()
	var message_length: int = buffer.get_u64()
	var message: String = buffer.get_utf8_string(message_length)
	var player = lobby_info["players"][player_id]
	add_message(player["nickname"], message)

func parse_binary_player_connected(buffer: StreamPeerBuffer):
	var player_id: int = buffer.get_u32()
	var nickname_length: int = buffer.get_u64()
	var player_nickname: String = buffer.get_utf8_string(nickname_length)
	
	var player_data: Dictionary = {}
	player_data["player_id"] = player_id
	player_data["nickname"] = player_nickname
	player_data["player_skin"] = 0
	player_data["is_ready"] = false
	player_data["is_host"] = false
	lobby_info["players"][player_id] = player_data
	
	var player_info: LobbyPlayerInfo = LOBBY_PLAYER_INFO_SCENE.instantiate()
	player_info.player_id = player_id
	lobby_info["player_row_info"][player_id] = player_info
	v_box_container.add_child(player_info)
	add_joining_leaving_message(player_data["nickname"], true)
	
	update_lobby_ui()
	
func parse_binary_kills_to_win_changed(buffer: StreamPeerBuffer):
	ffa_kills_to_win = buffer.get_u32()
	LevelManager.FFA_KILLS_TO_WIN = ffa_kills_to_win
	kills_to_win_amount_label.text = str(ffa_kills_to_win)
	
		
func create_player_info_snapshot(buffer: StreamPeerBuffer):
	var player_snapshot = {}
	player_snapshot["player_id"] = buffer.get_u32()
	var nickname_length = buffer.get_u64() 
	player_snapshot["nickname"] = buffer.get_utf8_string(nickname_length)
	player_snapshot["player_skin"] = buffer.get_u8() #skin indexd
	player_snapshot["is_ready"] = buffer.get_u8() != 0
	player_snapshot["is_host"] = buffer.get_u8() != 0
	if player_snapshot["is_host"]:
		lobby_host_name_label.text = str(player_snapshot["nickname"],"'s lobby")
		if player_snapshot["player_id"] == Network.my_id:
			IS_HOST = true
		else:
			IS_HOST = false

	print(player_snapshot)
	lobby_info["players"][player_snapshot["player_id"]] = player_snapshot
	
	var player_info: LobbyPlayerInfo = LOBBY_PLAYER_INFO_SCENE.instantiate()
	player_info.player_id = player_snapshot["player_id"]
	lobby_info["player_row_info"][player_snapshot["player_id"]] = player_info
	v_box_container.add_child(player_info)

func spawn_player_info(): # Array[Dictionary]
	for player_snapshot in lobby_info["players"].values():
		var player_id = player_snapshot["player_id"]
		if lobby_info["player_row_info"].has(player_id):
			continue
		
		var player_info: LobbyPlayerInfo = LOBBY_PLAYER_INFO_SCENE.instantiate()
		player_info.player_id = player_id
		lobby_info["player_row_info"][player_id] = player_info
		v_box_container.add_child(player_info)
		add_joining_leaving_message(player_snapshot["nickname"], true)

		if player_id != Network.my_id:
			if player_snapshot["is_host"]:
				hide_only_host_visible_elements()

func hide_only_host_visible_elements():
	start_lobby_button.visible = false
	select_map_left_button.visible = false
	select_map_right_button.visible = false
	tower_left_button.visible = false
	tower_right_button.visible = false
			
func update_lobby_ui(): #Array[Dictionary]
	#spawn_player_info()
	for player_row_info_id in lobby_info["player_row_info"].keys():
		var player_info: LobbyPlayerInfo = lobby_info["player_row_info"][player_row_info_id]
		player_info.handle_server_response(lobby_info["players"][player_row_info_id])
	
	if lobby_info["has_started"]:
		join_button.visible = true
	else:
		join_button.visible = false
		
	
func _on_start_lobby_button_pressed() -> void:
	if not lobby_started:
		MyHttpHandler.start_lobby()


func _on_right_button_pressed() -> void:
	tower_max_hp += 100
	tower_hp_amount_label.text = str(tower_max_hp)
	MyHttpHandler.change_tower_max_hp(tower_max_hp)


func _on_left_button_pressed() -> void:
	if tower_max_hp - 100 > 0:
		tower_max_hp -= 100
	#if tower_max_hp <= 0:
		#tower_max_hp = 100	
		tower_hp_amount_label.text = str(tower_max_hp)
		MyHttpHandler.change_tower_max_hp(tower_max_hp)

func _on_leave_lobby_button_pressed() -> void:
	MyHttpHandler.leave_lobby()

func _on_message_input_text_submitted(new_text: String) -> void:
	if new_text != "":
		add_message(Network.my_nickname, new_text)
		MyHttpHandler.send_message(new_text)
		message_input.text = ""

func add_message(player_nickname: String, message_text: String):
	var player_message: PlayerMessage = PLAYER_MESSAGE_SCENE.instantiate()
	messages_container.add_child(player_message)
	player_message.setup(player_nickname, message_text)

func add_joining_leaving_message(player_nickname: String, is_connecting: bool):
	var player_message: PlayerMessage = PLAYER_MESSAGE_SCENE.instantiate()
	messages_container.add_child(player_message)
	player_message.setup_connected_disconnected_message(player_nickname, is_connecting)

func _on_message_input_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()

func _on_message_input_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_start_lobby_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()

func _on_start_lobby_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_leave_lobby_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()

func _on_leave_lobby_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()


func _on_left_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
func _on_left_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_right_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
func _on_right_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()


func _on_players_to_kill_left_button_pressed() -> void:
	ffa_kills_to_win -= 1
	if ffa_kills_to_win <= 0:
		ffa_kills_to_win = 1
	kills_to_win_amount_label.text = str(ffa_kills_to_win)
	LevelManager.FFA_KILLS_TO_WIN = ffa_kills_to_win
	MyHttpHandler.change_kills_for_win(ffa_kills_to_win)

func _on_players_to_kill_right_button_pressed() -> void:
	ffa_kills_to_win += 1
	if ffa_kills_to_win >= 1000:
		ffa_kills_to_win = 1000
	kills_to_win_amount_label.text = str(ffa_kills_to_win)
	LevelManager.FFA_KILLS_TO_WIN = ffa_kills_to_win
	MyHttpHandler.change_kills_for_win(ffa_kills_to_win)

func _on_join_button_pressed() -> void:
	MyHttpHandler.join_started_lobby()

func _on_players_to_kill_left_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
func _on_players_to_kill_left_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()


func _on_select_map_left_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
func _on_select_map_left_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()

func _on_select_map_right_button_mouse_entered() -> void:
	CustomCursor.set_pointer_cursor_visible()
func _on_select_map_right_button_mouse_exited() -> void:
	CustomCursor.set_regular_cursor_visible()
