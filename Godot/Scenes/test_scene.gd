extends Node2D

var players: Dictionary = {}
var bullets: Dictionary = {}
var towers: Dictionary = {}

var initial_data: Dictionary
var connection_retry_timer = 0.0

const PLAYER = preload("res://Scenes/Player.tscn")
const OTHER_PLAYER = preload("res://Scenes/Other_Player/Other_Player.tscn")
const PISTOL_BULLET = preload("res://Scenes/Bullet/Pistol_Bullet.tscn")
const TOWER = preload("res://Scenes/Tower.tscn")

var server_response: Dictionary

func _ready() -> void:
	#LevelExporter.export_level_to_json()
	LevelManager.set_current_level_node(self)
	
	Network.connect_to_socket()
	Network.INPUT_DATA["command"] = "JOIN"
	Network.INPUT_DATA["nickname"] = Network.my_nickname
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Network.disconnect_from_socket()
		get_tree().quit()

func _process(delta):
	if Network.my_id == -1:
		connection_retry_timer += delta
		if connection_retry_timer >= 0.5:
			connection_retry_timer = 0.0
			Network.INPUT_DATA["command"] = "JOIN"
			var packed_byte_array: PackedByteArray = Network.convert_input_data_to_byte_array()
			Network.send_data(packed_byte_array)
			
	while Network.socket.get_available_packet_count() > 0:
		var package = Network.socket.get_packet()
		var buffer = StreamPeerBuffer.new()
		buffer.data_array = package
		var message_type = buffer.get_u32()
		
		match message_type:
			0: #ServerMessage::Init
				parse_binary_my_id(buffer)
			1: #ServerMessage::Snapshot	
				parse_binary_snapshot(buffer)
			2: #ServerMessage::Pong
				parse_binary_pong(buffer)
			3: 
				parse_binary_combat_log(buffer)
			#elif response.has("my_id"):
				#Network.my_id = response["my_id"]
				#continue
			#
			#if response.has("type") and response["type"] == "pong":
				#Network.calculate_ping(response["timestamp"])
	
func parse_binary_my_id(buffer:StreamPeerBuffer):
	#print(buffer.get_u32())
	Network.my_id = buffer.get_u32()

func parse_binary_snapshot(buffer: StreamPeerBuffer):
	#CITANJE PlayerSnapshots
	var parsed_players: Array = []
	var num_players = buffer.get_u64() 
	
	for i in range(num_players):
		var p = create_players_snapshot(buffer)
		parsed_players.append(p)
	
	# Citanje BulletSnapshots
	var parsed_bullets: Array = []
	var num_bullets = buffer.get_u64()
	
	for i in range(num_bullets):
		var b = create_bullets_snapshot(buffer)
		parsed_bullets.append(b)
	
	#Citanje TowerSnapshots
	var parsed_towers: Array = []
	var num_towers = buffer.get_u64()
	
	for i in range(num_towers):
		var t = create_towers_snapshot(buffer)
		parsed_towers.append(t)
		
	
	#Citanje killEvent
	var parsed_kill_events: Array = []
	var num_events = buffer.get_u64()
	
	for i in range(num_events):
		var b = create_kill_event_snapshot(buffer)
		parsed_kill_events.append(b)
		
		
	update_players(parsed_players)
	update_bullets(parsed_bullets)
	update_towers(parsed_towers)
	update_kill_events(parsed_kill_events)

func parse_binary_pong(buffer: StreamPeerBuffer):
	var timestamp = buffer.get_u64()
	Network.calculate_ping(timestamp)

func parse_binary_combat_log(buffer: StreamPeerBuffer):
	var combat_log: Dictionary = {}

func create_players_snapshot(buffer: StreamPeerBuffer):
	var snapshot: Dictionary = {}
	
	snapshot["id"] = buffer.get_u32()
	
	var name_length = buffer.get_u64() 
	snapshot["nickname"] = buffer.get_utf8_string(name_length)
	
	var pos_x = buffer.get_float()
	var pos_y = buffer.get_float()
	snapshot["position"] = Vector2(pos_x, pos_y)
	
	snapshot["hp"] = buffer.get_32()
	
	snapshot["facing_right"] = buffer.get_u8() != 0
	snapshot["is_on_ground"] = buffer.get_u8() != 0
	
	snapshot["respawn_timer"] = buffer.get_float()
	snapshot["last_processed_input_id"] = buffer.get_u32()
	snapshot["mouse_angle"] = buffer.get_float()
	
	var gun_id = buffer.get_u32() 
	if gun_id == 0:
		snapshot["gun"] = "pistol"
	elif gun_id == 1:
		snapshot["gun"] = "m4a1_rifle"
	
	snapshot["is_reloading"] = buffer.get_u8() != 0
	snapshot["current_ammo"] = buffer.get_16()
	
	return snapshot

func create_bullets_snapshot(buffer: StreamPeerBuffer) -> Dictionary:
	var bullet = {}
	
	bullet["id"] = buffer.get_u32()
	
	var pos_x = buffer.get_float()
	var pos_y = buffer.get_float()
	bullet["position"] = Vector2(pos_x, pos_y)
	bullet["owner_id"] = buffer.get_u32()
	bullet["angle"] = buffer.get_float()
	
	var gun_id = buffer.get_u32() 
	if gun_id == 0:
		bullet["gun"] = "pistol"
	elif gun_id == 1:
		bullet["gun"] = "m4a1_rifle"
		
	return bullet

func create_towers_snapshot(buffer: StreamPeerBuffer) -> Dictionary:
	var tower = {}
	tower["id"] = buffer.get_u32()
	tower["owner_id"] =  buffer.get_u32()
	tower["hp"] = buffer.get_32()
	tower["is_left_tower"] = buffer.get_u8()
	return tower

func create_kill_event_snapshot(buffer: StreamPeerBuffer) -> Dictionary:
	var kill_events: Dictionary = {}
	
	kill_events["event_id"] = buffer.get_u32()
	kill_events["killer_id"] = buffer.get_u32()
	kill_events["victim_id"] = buffer.get_u32()
	var gun_id = buffer.get_u32() 
	if gun_id == 0:
		kill_events["killed_with"] = "pistol"
	elif gun_id == 1:
		kill_events["killed_with"] = "m4a1_rifle"
	
	return kill_events
	
func spawn_players(snapshot: Array): # Array[Dictionary]
	for player_snapshot in snapshot:
		var player_id = player_snapshot["id"]
		if players.has(player_id):
			continue
		
		if player_id == Network.my_id:
			var my_player = PLAYER.instantiate()
			my_player.name = "My_Player"
			self.add_child(my_player)
			players[player_id] = my_player
		else:
			var other_player = OTHER_PLAYER.instantiate()
			self.add_child(other_player)
			players[player_id] = other_player
	
func update_players(snapshot: Array):
	check_disconnected(snapshot)
	spawn_players(snapshot)
	
	for player_snapshot in snapshot:
		var player_id = player_snapshot["id"]
		
		if player_id == Network.my_id:
			var player_node: MyPlayer = players[player_id]
			player_node.handle_server_response(player_snapshot)
		else:
			var other_player_node: OtherPlayer = players[player_id]
			other_player_node.handle_server_response(player_snapshot)

func spawn_bullets(snapshot: Array): # Array[Dictionary]
	for bullet_snapshot in snapshot:
		var bullet_id = bullet_snapshot["id"]
		if bullets.has(bullet_id):
			continue
			
		match bullet_snapshot["gun"]:
			"pistol":
				if Network.my_id != bullet_snapshot["owner_id"]:
					var client_spawn_position = players[bullet_snapshot["owner_id"]].get_bullet_spawn_position_marker().global_position
					var server_spawn_position:Vector2 = Vector2(bullet_snapshot["position"][0] * 32, bullet_snapshot["position"][1] * 32)
					var bullet: PlayerPistolBullet = PlayerPistolBullet.new(client_spawn_position, bullet_snapshot["angle"])
					bullet.instantiate_bullet(server_spawn_position, true)
					bullets[bullet_id] = bullet
			"m4a1_rifle":
				if Network.my_id != bullet_snapshot["owner_id"]:
					var client_spawn_position = players[bullet_snapshot["owner_id"]].get_bullet_spawn_position_marker().global_position
					var server_spawn_position:Vector2 = Vector2(bullet_snapshot["position"][0] * 32, bullet_snapshot["position"][1] * 32)
					var bullet: PlayerM4A1Bullet = PlayerM4A1Bullet.new(client_spawn_position, bullet_snapshot["angle"])
					bullet.instantiate_bullet(server_spawn_position, true)
					bullets[bullet_id] = bullet
	
func update_bullets(snapshot: Array):
	check_bullet_destroyed(snapshot)
	spawn_bullets(snapshot)
	if Network.my_id != -1:
		for bullet_snapshot in snapshot:
			var bullet_id = bullet_snapshot["id"]
			var bullet_owner_id = bullet_snapshot["owner_id"]
			if Network.my_id != bullet_owner_id:
				if bullets[bullet_id] != null:
					var bullet_node: PlayerBullet = bullets[bullet_id]
					bullet_node.handle_server_response(bullet_snapshot)
			
func update_kill_events(snapshot: Array):
	var my_player: MyPlayer = players[Network.my_id]
	my_player.check_for_kill_display(snapshot, players)

func spawn_towers(tower_snapshots: Array):
	for tower_snapshot in tower_snapshots:
		var tower_id = tower_snapshot["id"]
		if towers.has(tower_id):
			continue

			
		var tower: Tower = TOWER.instantiate()
		self.add_child(tower)
		tower.setup(tower_snapshot)
		towers[tower_id] = tower
		
		
func update_towers(tower_snapshots: Array):
	spawn_towers(tower_snapshots)
	for tower_snapshot in tower_snapshots:
		var tower_id = tower_snapshot["id"]
		var tower: Tower = towers[tower_id]
		tower.handle_server_response(tower_snapshot)
func check_disconnected(snapshot: Array):
	var active_ids = []
	for player_snapshot in snapshot:
		active_ids.append(player_snapshot["id"])
	
	for player_id in players.keys():
		if player_id not in active_ids:
			var player_node = players[player_id]
			player_node.queue_free()
			players.erase(player_id)
			print("IGRAC SA ID-jem: " + str(player_id) + " se diskonektovao!")

func check_bullet_destroyed(snapshot: Array):
	var active_ids = []
	for bullet_snapshot in snapshot:
		active_ids.append(bullet_snapshot["id"])
	
	for bullet_id in bullets.keys():
		if bullet_id not in active_ids:
			var bullet_node = bullets[bullet_id]
			if bullet_node:
				bullet_node.queue_free()
			bullets.erase(bullet_id)
