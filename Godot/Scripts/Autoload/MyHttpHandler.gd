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
			print("LOBBIJI: ", num_lobbies )
			var lobbies_info: Array = []
			for i in range(num_lobbies):
				var lobby_info: Dictionary = {}
				lobby_info["lobby_id"] = buffer.get_u32()
				var nickname_length = buffer.get_u64() 
				lobby_info["host_nickname"] = buffer.get_utf8_string(nickname_length)
				lobby_info["current_players"] = buffer.get_u8()
				lobby_info["max_players"] = buffer.get_u8()
				lobby_info["is_started"] = buffer.get_u8() != 0
				lobbies_info.append(lobby_info)
				print(lobby_info)
			Signals.UPDATE_LOBBY_UI.emit(lobbies_info)
			

func create_lobby_binary():
	var http = HTTPRequest.new()
	get_tree().root.add_child(http)
	http.request_completed.connect(_on_create_completed)
	
	var buffer = StreamPeerBuffer.new()
	buffer.put_u16(Network.my_local_port)
	
	var name_bytes = Network.my_nickname.to_utf8_buffer()
	buffer.put_u64(name_bytes.size())
	buffer.put_data(name_bytes)
	
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
			
			Network.my_id = buffer.get_u32()
			change_scene("res://Scenes/Test_Scene.tscn")

func join_lobby_binary(lobby_id: int, nickname: String):
	var http = HTTPRequest.new()
	get_tree().root.add_child(http)
	http.request_completed.connect(_on_join_completed)

	var buffer = StreamPeerBuffer.new()
	
	buffer.put_u32(lobby_id)
	
	buffer.put_u64(nickname.length())
	buffer.put_data(nickname.to_utf8_buffer())
	
	buffer.put_u16(Network.my_local_port)
	
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
		change_scene("res://Scenes/Test_Scene.tscn")
		#get_tree().change_scene_to_file("res://Scenes/Test_Scene.tscn")

func start_lobby():
	var http = HTTPRequest.new()
	get_tree().root.add_child(http)
	http.request_completed.connect(_on_start_lobby_completed)
	
	var buffer = StreamPeerBuffer.new()
	buffer.put_u32(4)# ClientMessage::LobbyStart
	buffer.big_endian = false
	buffer.put_u32(Network.my_id)
	buffer.put_u32(Network.current_lobby_id)
	print(Network.my_id)
	
	var headers = ["Content-Type: application/octet-stream"]
	var url = "http://127.0.0.1:3000/start-lobby"
	var err = http.request_raw(url, headers, HTTPClient.METHOD_POST, buffer.data_array)
	if err != OK:
		print("Greška pri slanju HTTP zahteva: ", err)
		http.queue_free()
		
func _on_start_lobby_completed(result, response_code, headers, body):
	if response_code == 200:
		print("Startovan lobbi!")
