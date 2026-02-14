extends Node2D

var players: Dictionary = {}

func _ready() -> void:
	Network.connect_to_socket()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Network.disconnect_from_socket()
		get_tree().quit()

func _process(delta):
	while Network.socket.get_available_packet_count() > 0:
		var packet = Network.socket.get_packet()
		var snapshot = JSON.parse_string(packet.get_string_from_utf8())
		
		if snapshot: 
			if snapshot.has("players"):
				for p_data in snapshot["players"]:
					var p_id = p_data["id"]
			elif snapshot.has("my_id"):
				Network.my_id = snapshot["my_id"]
				continue
				#if not players.has(p_id):
					#spawn_player(p_id)
				#
				#players[p_id].update_from_server(p_data)
	
