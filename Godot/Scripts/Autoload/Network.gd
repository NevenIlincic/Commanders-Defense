extends Node2D

var is_local: bool = false
const VERSION: int = 1

#####CONNECTION
#UDP
var socket := PacketPeerUDP.new()
#var server_address := "commanders-defense-test-server.switzerlandnorth.cloudapp.azure.com" #127.0.0.1
var server_address = null
var server_port := 9000
var is_connected_to_udp_socket: bool = false

var websocket := WebSocketPeer.new()
#var websocket_address := "wss://commanders-defense-test-server.switzerlandnorth.cloudapp.azure.com/ws"
var websocket_address = null

var is_connected_to_websocket: bool = false
var is_conenction_with_websocket_lost: bool = false

var my_id: int = -1
var my_nickname: String = ""
var my_local_port: int = -1
var current_lobby_id: int = 0
var my_skin_id: int = 0
var AUTH_TOKEN: String = ""

var is_disconnecting: bool = false

var INPUT_DATA: Dictionary


#PING
var can_send_ping: bool = false
var ping_interval = 1.0 # 1 sekunda
var time_since_last_ping = 1.0
var ping_start_time: int
var current_ping: int

#HEARTBEAT
var heartbeat_timer: Timer

func _ready() -> void:	
	if is_local:
		server_address = "127.0.0.1"
		websocket_address = "ws://127.0.0.1:8080/ws"
	else:
		server_address = "commanders-defense-test-server.switzerlandnorth.cloudapp.azure.com" #127.0.0.1
		websocket_address = "wss://commanders-defense-test-server.switzerlandnorth.cloudapp.azure.com/ws"

	
	if not socket.is_bound():
		var err = socket.bind(0)
		if err == OK:
			my_local_port = socket.get_local_port()
		else:
			return
	INPUT_DATA = {
		"player_id": my_id,
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
	setup_heartbeat_timer()

func reset_for_new_session():
	my_id = -1
	my_nickname = ""
	INPUT_DATA = {
		"player_id": my_id,
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
	is_disconnecting = false

enum Command {
	NONE = 0,
	JOIN = 1,
	DISCONNECT = 2,
	RELOAD = 3
}

enum Gun {
	PISTOL = 0,
	M4A1_RIFLE = 1,
	GRENADE = 2
}

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		is_disconnecting = true
		Network.disconnect_from_socket()
		Network.disconnect_from_websocket()
		socket.close()
		
		#if not is_disconnecting:
			#get_tree().quit()

func _process(delta):
	if is_connected_to_udp_socket:
		handle_udp_connection()
		handle_ping(delta)
	handle_websocket_connection()

func setup_heartbeat_timer():
	heartbeat_timer = Timer.new()
	heartbeat_timer.autostart = true
	heartbeat_timer.one_shot = false
	heartbeat_timer.timeout.connect(handle_heartbeat)
	add_child(heartbeat_timer)
	heartbeat_timer.start(15)

func handle_heartbeat():
	if AUTH_TOKEN != "":
		MyHttpHandler.send_heartbeat()
		MyHttpHandler.send_websocket_hearbeat()
		
func connect_to_socket():
	var ip = IP.resolve_hostname(server_address)
	if ip == "" or not ip.is_valid_ip_address():
		return

	var err = socket.set_dest_address(ip, server_port)
	if err != OK:
		return
		
	#socket.set_dest_address(ip, server_port)
	is_connected_to_udp_socket = true

func connect_to_websocket():
	var auth_header = "Authorization: Bearer " + Network.AUTH_TOKEN
	var lobby_header = "X-Lobby-Id: " + str(Network.current_lobby_id)
	websocket.handshake_headers = PackedStringArray([auth_header, lobby_header])
	var err = websocket.connect_to_url(websocket_address)
	if err != OK:
		set_process(false)

func handle_websocket_connection():
	var state = websocket.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		if is_connected_to_websocket:
			Signals.SHOW_LOADING_MESSAGE.emit("Connection with the server lost!")
			is_conenction_with_websocket_lost = true
			MyHttpHandler.logout()
			disconnect_from_socket()
			disconnect_from_websocket()
			is_connected_to_websocket = false
			get_tree().change_scene_to_file("res://Scenes/Main_Menu.tscn")
		return

	websocket.poll()
	state = websocket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if !is_connected_to_websocket:
			is_connected_to_websocket = true
			
		while websocket.get_available_packet_count() > 0:
			var package = websocket.get_packet() # Koristi websocket, ne Network.socket
			var buffer = StreamPeerBuffer.new()
			buffer.data_array = package
			var message_type = buffer.get_u32()
			match message_type:
				#0: #ServerMessage::Init
						#Signals.HANDLE_LEVEL_UDP.emit(buffer, 0)
					#1: #ServerMessage::Snapshot	
						#Signals.HANDLE_LEVEL_UDP.emit(buffer, 1)
					#2: #ServerMessage::Pong
						#Signals.HANDLE_LEVEL_UDP.emit(buffer, 2)
					3: #ServerMessage::GameEnd
						Signals.HANDLE_LEVEL_UDP.emit(buffer, 3)
					6: #ServerMessage::GameStarted
						Signals.HANDLE_LOBBY_UDP.emit(buffer, 6)
					7: #ServerMessage::LobbyInfo
						Signals.HANDLE_LOBBY_UDP.emit(buffer, 7)
					8: #ServerMessage::PlayerDisconnected
						Signals.HANDLE_LEVEL_UDP.emit(buffer, 8)
						Signals.HANDLE_LOBBY_UDP.emit(buffer, 8)
					9: #ServerMessage::PlayerChangedSkin
						Signals.HANDLE_LOBBY_UDP.emit(buffer, 9)
					10: #ServerMessage::PlayerChangedReadyState
						Signals.HANDLE_LOBBY_UDP.emit(buffer, 10)
					11: #ServerMessage::TowerMaxHPChanged
						Signals.HANDLE_LOBBY_UDP.emit(buffer, 11)
					12: #ServerMessage::PlayerMessage
						Signals.HANDLE_LOBBY_UDP.emit(buffer, 12)
						Signals.HANDLE_LEVEL_UDP.emit(buffer, 12)
					13: #ServerMessage::PlayerConnected
						Signals.HANDLE_LOBBY_UDP.emit(buffer, 13)
						Signals.HANDLE_LEVEL_UDP.emit(buffer, 13)
					14: #ServerMessage::PlayerKilled
						Signals.HANDLE_LEVEL_UDP.emit(buffer, 14)
					15: #ServerMessage::KillsToWinChanged
						Signals.HANDLE_LOBBY_UDP.emit(buffer, 15)
					17: #ServerMessage::MapChanged
						Signals.HANDLE_LOBBY_UDP.emit(buffer, 17)
					19: #ServerMessage:TowerCreated -- pozivam na startu levela
						var tower = {}
						tower["id"] = buffer.get_u32()
						tower["owner_id"] =  buffer.get_u32()
						tower["hp"] = buffer.get_32()
						tower["is_left_tower"] = buffer.get_u8()
						LevelManager.TOWERS_CREATE_INFO.append(tower)
						#Signals.HANDLE_LEVEL_UDP.emit(buffer, 19)

func disconnect_from_websocket():
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		websocket.close(1000, "Igrač je napustio lobi")
		is_connected_to_websocket = false
		LevelManager.CURRENT_LEVEL_GAME_MODE = ""
		LevelManager.FFA_KILLS_TO_WIN = -1
		

func disconnect_from_socket():	
	is_connected_to_udp_socket = false
	can_send_ping = false
	await get_tree().create_timer(0.1).timeout

func send_data(data: PackedByteArray):
	if is_connected_to_udp_socket:
		socket.put_packet(data)

func convert_input_data_to_byte_array():
	var buffer = StreamPeerBuffer.new()
	
	buffer.put_u32(0) # ClientMessage::Input
	buffer.put_u32(my_id)
	buffer.put_u32(INPUT_DATA["input_id"])
	
	buffer.put_u8(1 if INPUT_DATA["move_left"] else 0)
	buffer.put_u8(1 if INPUT_DATA["move_right"] else 0)
	buffer.put_u8(1 if INPUT_DATA["jump"] else 0)
	buffer.put_u8(1 if INPUT_DATA["shoot"] else 0)
	
	buffer.put_float(INPUT_DATA["mouse_angle"])
	
	var cmd_id = Command.get(INPUT_DATA["command"], 0)
	buffer.put_u32(cmd_id) 

	var gun_id = Gun.get(INPUT_DATA["gun"].to_upper(), 0)
	buffer.put_u32(gun_id)

	if INPUT_DATA["bullet_spawn_position"] == null:
		buffer.put_u8(0)
	else:
		buffer.put_u8(1)
		buffer.put_float(INPUT_DATA["bullet_spawn_position"][0])
		buffer.put_float(INPUT_DATA["bullet_spawn_position"][1])
			
	return buffer.data_array

func handle_udp_connection():
	while Network.socket.get_available_packet_count() > 0:
		var package = Network.socket.get_packet()
	
		if package.is_empty(): continue
		
		var final_data: PackedByteArray
		
		# PROVERA: Da li je paket GZIP? (Prva dva bajta su 31 i 139)
		if package.size() > 2 and package[0] == 31 and package[1] == 139:
			var decompressed = package.decompress(65535, FileAccess.COMPRESSION_GZIP)
			if decompressed.is_empty():
				continue
			final_data = decompressed
		else:
			final_data = package
		var buffer = StreamPeerBuffer.new()
		buffer.data_array = final_data
		var message_type = buffer.get_u32()
		
		match message_type:
			0: #ServerMessage::Init
				Signals.HANDLE_LEVEL_UDP.emit(buffer, 0)
			1: #ServerMessage::Snapshot	
				Signals.HANDLE_LEVEL_UDP.emit(buffer, 1)
			2: #ServerMessage::Pong
				Signals.HANDLE_LEVEL_UDP.emit(buffer, 2)
			#3: #ServerMessage::GameEnd
				#Signals.HANDLE_LEVEL_UDP.emit(buffer, 3)
			#6: #ServerMessage::GameStarted
				#Signals.HANDLE_LOBBY_UDP.emit(buffer, 6)
			#7: #ServerMessage::LobbyInfo
				#Signals.HANDLE_LOBBY_UDP.emit(buffer, 7)

func handle_ping(delta: float):
	time_since_last_ping += delta
	if time_since_last_ping >= ping_interval:
		send_ping()
		time_since_last_ping = 0.0

func send_ping():
	if can_send_ping:
		var buffer = StreamPeerBuffer.new()
		buffer.put_u32(1) #ClientMessage::Ping
		buffer.put_u32(my_id)
		var current_time = Time.get_ticks_msec()
		buffer.put_u64(current_time)
		send_data(buffer.data_array)

func calculate_ping(timestamp: int):
	current_ping = Time.get_ticks_msec() - timestamp

	
