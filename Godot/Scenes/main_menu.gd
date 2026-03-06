extends Node2D

@onready var start_button: TextureButton = $Start_Button
@onready var quit_button: TextureButton = $Quit_Button
@onready var nickname_input: LineEdit = $Nickname_Input
@onready var ip_address_input: LineEdit = $IP_Address_Input

@onready var hover_click_sound: AudioStreamPlayer2D = $"Hover-Click_Sound"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	#SoundHandler.play_background_music(SoundHandler.TI_SE_SAMO_USUDI)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_start_button_pressed() -> void:
	if nickname_input.text != "" and ip_address_input.text != "":
		hover_click_sound.play()
		Network.my_nickname = nickname_input.text
		Network.server_address = ip_address_input.text.split(":")[0]
		Network.server_port = int(ip_address_input.text.split(":")[1])
		
		join_lobby_binary(1, Network.my_nickname)
		


func _on_start_button_mouse_entered() -> void:
	hover_click_sound.play()


func _on_quit_button_mouse_entered() -> void:
	hover_click_sound.play()


func _on_quit_button_pressed() -> void:
	hover_click_sound.play()
	get_tree().quit()


##
func join_lobby_binary(lobby_id: int, nickname: String):
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_join_completed)

	var buffer = StreamPeerBuffer.new()
	
	buffer.put_u32(lobby_id)
	
	buffer.put_u64(nickname.length())
	buffer.put_data(nickname.to_utf8_buffer())
	
	# 3. udp_port (u16)
	buffer.put_u16(Network.my_local_port)
	
	var headers = ["Content-Type: application/octet-stream"]
	
	var url = "http://127.0.0.1:3000/join"
	http.request_raw(url, headers, HTTPClient.METHOD_POST, buffer.data_array)

func _on_join_completed(result, response_code, headers, body):
	if response_code == 200:
		print("Uspešno ubačen u lobi!")
		var buffer = StreamPeerBuffer.new()
		buffer.data_array = body
		buffer.big_endian = false
		
		var my_id = buffer.get_u32()
		print("Moj ID u igri je: ", my_id)
				
		Network.my_id = my_id
		get_tree().change_scene_to_file("res://Scenes/Test_Scene.tscn")
