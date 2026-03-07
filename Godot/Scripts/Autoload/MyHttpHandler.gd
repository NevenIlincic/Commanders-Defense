extends Node

func change_scene(path: String):
	if path == "" or !FileAccess.file_exists(path):
		print("GREŠKA: Scena ne postoji: ", path)
		return
	
	print("Menjam scenu na: ", path)
	# Koristimo call_deferred jer smo verovatno unutar HTTP callback-a
	get_tree().change_scene_to_file.call_deferred(path)

func create_lobby_binary():
	var http = HTTPRequest.new()
	get_tree().root.add_child(http)
	http.request_completed.connect(_on_create_completed)
	
	var buffer = StreamPeerBuffer.new()
	buffer.put_u16(Network.my_local_port)
	
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
