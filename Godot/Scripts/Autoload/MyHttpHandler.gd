extends Node

func change_scene(path: String):
	if path == "" or !FileAccess.file_exists(path):
		print("GREŠKA: Scena ne postoji: ", path)
		return
	
	print("Menjam scenu na: ", path)
	get_tree().change_scene_to_file.call_deferred(path)


func get_all_lobies():
	var http = HTTPRequest.new()
	get_tree().root.add_child(http)
	http.request_completed.connect(_on_get_all_lobbies_completed)
	
	var buffer = StreamPeerBuffer.new()
	
	var headers = ["Content-Type: application/octet-stream"]
	var url = "http://127.0.0.1:3000/lobbies"
	var err = http.request_raw(url, headers, HTTPClient.METHOD_GET, buffer.data_array)
	if err != OK:
		print("Greška pri slanju HTTP zahteva: ", err)
		http.queue_free()

func _on_get_all_lobbies_completed(result, response_code, headers, body):
	if response_code == 200:
		var buffer = StreamPeerBuffer.new()
		buffer.data_array = body
		buffer.big_endian = false
		var message_type = buffer.get_u32() 
		if message_type == 4: #ServerMessage::LobbiesList	
			var num_lobbies: int = buffer.get_u64()
			var lobbies_info: Array = []
			for i in range(num_lobbies):
				var lobby_info: Dictionary = {}
				lobby_info["lobby_id"] = buffer.get_u32()
				var nickname_length = buffer.get_u64() 
				lobby_info["host_nickname"] = buffer.get_utf8_string(nickname_length)
				lobby_info["current_players"] = buffer.get_u8()
				lobby_info["max_players"] = buffer.get_u8()
				lobby_info["is_started"] = buffer.get_u8() != 0
				lobby_info["has_password"] = buffer.get_u8() != 0
				lobbies_info.append(lobby_info)
			Signals.UPDATE_LOBBIES_MENU_UI.emit(lobbies_info)
			

func create_lobby_binary(max_players: int, password: String, game_mode_number: int = 0):
	var http = HTTPRequest.new()
	get_tree().root.add_child(http)
	http.request_completed.connect(_on_create_completed)
	
	var buffer = StreamPeerBuffer.new()
	buffer.put_u16(Network.my_local_port) #UDP port
	
	var name_bytes = Network.my_nickname.to_utf8_buffer() 
	buffer.put_u64(name_bytes.size())
	buffer.put_data(name_bytes) #Nickname
	buffer.put_u8(game_mode_number) #0-Towers, 1-FFA
	
	buffer.put_u8(max_players)
	##Password
	if password == "" or password == null:
		buffer.put_u8(0)
	else:
		buffer.put_u8(1)
		
	var message_bytes = password.to_utf8_buffer()
	buffer.put_u64(message_bytes.size()) 
	buffer.put_data(message_bytes)
	##
	
	var headers = ["Content-Type: application/octet-stream"]
	var url = "http://127.0.0.1:3000/create-lobby"
	var err = http.request_raw(url, headers, HTTPClient.METHOD_POST, buffer.data_array)
	if err != OK:
		print("Greška pri slanju HTTP zahteva: ", err)
		http.queue_free()
	
func _on_create_completed(result, response_code, headers, body):
	if response_code == 200:
		var buffer = StreamPeerBuffer.new()
		buffer.data_array = body
		buffer.big_endian = false
		var message_type = buffer.get_u32()
		if message_type == 5: #ServerMessage::CreatedLobbyResponse
			var current_lobby_id = buffer.get_u32()
			print("ID LOBBIJA: ", current_lobby_id)
			Network.current_lobby_id = current_lobby_id
			Network.my_skin_id = 0
			Network.my_id = buffer.get_u32()
			get_tree().change_scene_to_file("res://Scenes/Lobby/Lobby.tscn")

func join_lobby_binary(password: String):
	var http = HTTPRequest.new()
	get_tree().root.add_child(http)
	http.request_completed.connect(_on_join_completed)

	var buffer = StreamPeerBuffer.new()
	
	buffer.put_u32(Network.current_lobby_id) #lobby_id
	
	buffer.put_u64(Network.my_nickname.length()) #nickname
	buffer.put_data(Network.my_nickname.to_utf8_buffer())
	buffer.put_u16(Network.my_local_port)
	if password == "" or password == null:
		buffer.put_u8(0)
	else:
		buffer.put_u8(1)
		var password_bytes = password.to_utf8_buffer()
		buffer.put_u64(password_bytes.size()) 
		buffer.put_data(password_bytes)
		
	
	var headers = ["Content-Type: application/octet-stream"]
	
	var url = "http://127.0.0.1:3000/join"
	var err = http.request_raw(url, headers, HTTPClient.METHOD_POST, buffer.data_array)
	if err != OK:
		print("Greška pri slanju HTTP zahteva: ", err)
		http.queue_free()

func _on_join_completed(result, response_code, headers, body):
	if response_code == 200:
		print("Uspešno ubačen u lobi!")
		var buffer = StreamPeerBuffer.new()
		buffer.data_array = body
		buffer.big_endian = false
		
		var my_id = buffer.get_u32()
		print("Moj ID u igri je: ", my_id)
				
		Network.my_id = my_id
		Network.my_skin_id = 0
		get_tree().change_scene_to_file("res://Scenes/Lobby/Lobby.tscn")
		#get_tree().change_scene_to_file("res://Scenes/Test_Scene.tscn")

func get_lobby_info():
	print("DOBAVLJAM!")
	var http = HTTPRequest.new()
	get_tree().root.add_child(http)
	http.request_completed.connect(_on_get_lobby_info_completed)

	var buffer = StreamPeerBuffer.new()
	buffer.put_u32(6)# ClientMessage::GetLobbyInfo
	buffer.put_u32(Network.current_lobby_id)
	
	var headers = ["Content-Type: application/octet-stream"]
	
	var url = "http://127.0.0.1:3000/get-lobby-info"
	var err = http.request_raw(url, headers, HTTPClient.METHOD_POST, buffer.data_array)
	if err != OK:
		print("Greška pri slanju HTTP zahteva: ", err)
		http.queue_free()

func _on_get_lobby_info_completed(result, response_code, headers, body):
	if response_code == 200:
		print("DOBAVIO INFO ZA LOBI!")
		var buffer = StreamPeerBuffer.new()
		buffer.data_array = body
		buffer.big_endian = false
		var message_type = buffer.get_u32()
		if message_type == 7: #ServerMessage::LobbyInfo
			Signals.UPDATE_LOBBY_UI.emit(buffer)
		
func start_lobby():
	#var http = HTTPRequest.new()
	#get_tree().root.add_child(http)
	#http.request_completed.connect(_on_start_lobby_completed)
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u32(4)# ClientMessage::LobbyStart
	buffer.put_u32(Network.my_id)
	buffer.put_u32(Network.current_lobby_id)
	Network.websocket.put_packet(buffer.data_array)
	#
	#var headers = ["Content-Type: application/octet-stream"]
	#var url = "http://127.0.0.1:3000/start-lobby"
	#var err = http.request_raw(url, headers, HTTPClient.METHOD_POST, buffer.data_array)
	#if err != OK:
		#print("Greška pri slanju HTTP zahteva: ", err)
		#http.queue_free()
		
func _on_start_lobby_completed(result, response_code, headers, body):
	print(response_code)
	if response_code == 200:
		print("Startovan lobbi!")

func change_is_player_ready():
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u32(5)# ClientMessage::PlayerReady
	buffer.put_u32(Network.current_lobby_id)
	buffer.put_u32(Network.my_id)
	Network.websocket.put_packet(buffer.data_array)
		
func _on_change_is_player_ready_completed(result, response_code, headers, body):
	if response_code == 200:
		print("PROMENIO SPREMNOST")
		#var buffer = StreamPeerBuffer.new()
		#buffer.data_array = body
		#buffer.big_endian = false
		#var message_type = buffer.get_u32()
		#if message_type == 7: #ServerMessage::LobbyInfo
			#Signals.UPDATE_LOBBY_UI.emit(buffer)

func change_tower_max_hp(tower_max_hp: int):
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u32(7)# ClientMessage::ChangeTowerMaxHP
	buffer.put_u32(Network.current_lobby_id)
	buffer.put_u32(tower_max_hp)
	Network.websocket.put_packet(buffer.data_array)


func _on_change_tower_max_hp_completed(result, response_code, headers, body):
	if response_code == 200:
		print("PROMENJEN MAX HP KULE!")

func change_player_skin(skin_index):
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u32(8)# ClientMessage::ChangePlayerBodySkin
	buffer.put_u32(Network.current_lobby_id)
	buffer.put_u32(Network.my_id)
	buffer.put_u32(skin_index) #PlayerSkin enum
	Network.websocket.put_packet(buffer.data_array)
	

func _on_change_player_skin_completed(result, response_code, headers, body):
	if response_code == 200:
		print("PROMENJEN SKIN IGRACA!")

func leave_lobby():
	var http = HTTPRequest.new()
	get_tree().root.add_child(http)
	http.request_completed.connect(_on_leave_lobby_completed)
	
	var buffer = StreamPeerBuffer.new()
	buffer.put_u32(9)# ClientMessage::LobbyLeave
	buffer.put_u32(Network.current_lobby_id)
	buffer.put_u32(Network.my_id)
	
	var headers = ["Content-Type: application/octet-stream"]
	var url = "http://127.0.0.1:3000/leave-lobby"
	var err = http.request_raw(url, headers, HTTPClient.METHOD_POST, buffer.data_array)
	if err != OK:
		print("Greška pri slanju HTTP zahteva: ", err)
		http.queue_free()

func _on_leave_lobby_completed(result, response_code, headers, body):
	if response_code == 200:
		Network.current_lobby_id = -1
		Network.my_id = -1
		Network.my_skin_id = -1
		if not Network.is_disconnecting:
			Network.disconnect_from_websocket()
			Network.disconnect_from_socket()
			get_tree().change_scene_to_file("res://Scenes/Lobbies_Menu.tscn")
		else:
			get_tree().quit()

func send_message(player_message: String):
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u32(10)# ClientMessage::PlayerMessage
	buffer.put_u32(Network.current_lobby_id)
	buffer.put_u32(Network.my_id)
	
	var message_bytes = player_message.to_utf8_buffer()
	buffer.put_u64(message_bytes.size()) 
	
	buffer.put_data(message_bytes)
	
	Network.websocket.put_packet(buffer.data_array)

func change_kills_for_win(kill_amount: int):
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_u32(11)# ClientMessage::ChangeKillsToWin
	buffer.put_u32(Network.current_lobby_id)
	buffer.put_u32(kill_amount)
	
	Network.websocket.put_packet(buffer.data_array)

func join_started_lobby():
	var http = HTTPRequest.new()
	get_tree().root.add_child(http)
	http.request_completed.connect(_on_joined_started_lobby_completed)

	var buffer = StreamPeerBuffer.new()
	buffer.put_u32(12)# ClientMessage::JoinStartedLobby
	buffer.put_u32(Network.current_lobby_id)
	buffer.put_u32(Network.my_id)
	
	var headers = ["Content-Type: application/octet-stream"]
	
	var url = "http://127.0.0.1:3000/join-started-lobby"
	var err = http.request_raw(url, headers, HTTPClient.METHOD_POST, buffer.data_array)
	if err != OK:
		print("Greška pri slanju HTTP zahteva: ", err)
		http.queue_free()
		
func _on_joined_started_lobby_completed(result, response_code, headers, body):
	if response_code == 200:
		get_tree().change_scene_to_file("res://Scenes/Test_Scene.tscn")
