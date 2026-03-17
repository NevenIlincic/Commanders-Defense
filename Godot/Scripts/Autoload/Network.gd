extends Node2D

#####CONNECTION
#UDP
var socket := PacketPeerUDP.new()
var server_address := "127.0.0.1"
var server_port := 8080
var is_connected_to_udp_socket: bool = false

var websocket := WebSocketPeer.new()
var websocket_address := "ws://127.0.0.1:3000/ws"
var is_connected_to_websocket: bool = false

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
var time_since_last_ping = 0.0
var ping_start_time: int
var current_ping: int

func _ready() -> void:	
	if not socket.is_bound():
		var err = socket.bind(0)
		if err == OK:
			my_local_port = socket.get_local_port()
			print("Novi port dodeljen: ", my_local_port)
		else:
			print("Greška: Bind nije uspeo!")
			return
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
		"bullet_spawn_position": null,
		#"nickname": my_nickname
	}

func reset_for_new_session():
	my_id = -1
	my_nickname = ""
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
		"bullet_spawn_position": null,
		#"nickname": my_nickname
	}
	is_disconnecting = false
	print("Network session resetovan.")

enum Command {
	NONE = 0,
	JOIN = 1,
	DISCONNECT = 2,
	RELOAD = 3
}

enum Gun {
	PISTOL = 0,
	M4A1_RIFLE = 1
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
	
func connect_to_socket():
	socket.connect_to_host(server_address, server_port)
	is_connected_to_udp_socket = true

func connect_to_websocket():
	var err = websocket.connect_to_url(websocket_address)
	if err != OK:
		print("Ne mogu da pokrenem povezivanje: ", err)
		set_process(false)
		
	else:
		print("Zapocinjem konektovanje!")

func handle_websocket_connection():
	var state = websocket.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		is_connected_to_websocket = false
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

	if state == WebSocketPeer.STATE_CONNECTING:
		print("KONEKTUJEM SE")
func disconnect_from_websocket():
	if websocket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		websocket.close(1000, "Igrač je napustio lobi")
		is_connected_to_websocket = false
		LevelManager.CURRENT_LEVEL_GAME_MODE = ""
		LevelManager.FFA_KILLS_TO_WIN = -1
		print("Zatvaram WebSocket vezu...")
		

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
		var buffer = StreamPeerBuffer.new()
		buffer.data_array = package
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
		var current_time = Time.get_ticks_msec()
		buffer.put_u64(current_time)
		send_data(buffer.data_array)

func calculate_ping(timestamp: int):
	current_ping = Time.get_ticks_msec() - timestamp

	
