extends Node2D

var lobby_started: bool = false

func _ready() -> void:
	Network.connect_to_socket()
	Signals.HANDLE_LOBBY_UDP.connect(handle_udp_package_receive)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("start_lobby") and not lobby_started:
		lobby_started = true
		Network.can_send_ping = true
		MyHttpHandler.start_lobby()

func handle_udp_package_receive(buffer: StreamPeerBuffer, message_type: int):
	match message_type:
		6: #ServerMessage::GameStarted
			get_tree().change_scene_to_file("res://Scenes/Test_Scene.tscn")
	
