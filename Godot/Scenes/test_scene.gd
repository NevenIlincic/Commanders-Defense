extends Node2D

const FLAG_FACING_RIGHT = 1
const FLAG_IS_ON_GROUND = 2
const FLAG_IS_RELOADING = 4

var players: Dictionary = {}
var bullets: Dictionary = {}
var towers: Dictionary = {}
var grenades: Dictionary = {}
var scoreboard_info: Dictionary = {}

var initial_data: Dictionary
var connection_retry_timer = 0.0

const PLAYER = preload("res://Scenes/Player.tscn")
const OTHER_PLAYER = preload("res://Scenes/Other_Player/Other_Player.tscn")
const PISTOL_BULLET = preload("res://Scenes/Bullet/Pistol_Bullet.tscn")
const TOWER = preload("res://Scenes/Tower.tscn")
const GRENADE = preload("res://Scenes/Guns/Throwables/Hand_Grenade.tscn")

var server_response: Dictionary

#TOWERS
@onready var left_tower_position: Marker2D = $Left_Tower_Position
@onready var right_tower_position: Marker2D = $Right_Tower_Position


@onready var end_game_timer: Timer = $End_Game_Timer

@export var map_name: String = ""

var disconnected_players: Dictionary = {}

func _ready() -> void:
	#LevelExporter.export_level_to_json(map_name)
	LevelManager.set_current_level_node(self)
	Signals.HANDLE_LEVEL_UDP.connect(handle_udp_package_receive)
	
	Network.INPUT_DATA["command"] = "JOIN"
	#Network.INPUT_DATA["nickname"] = Network.my_nickname
	CustomCursor.hide_cursor()

	
	if LevelManager.CURRENT_LEVEL_GAME_MODE == "TOWERS":
		spawn_towers(LevelManager.TOWERS_CREATE_INFO)
		
func _process(delta):
	pass

func handle_udp_package_receive(buffer: StreamPeerBuffer, message_type: int):
	match message_type:
		0: #ServerMessage::Init
			parse_binary_my_id(buffer)
		1: #ServerMessage::Snapshot	
			parse_binary_snapshot(buffer)
		2: #ServerMessage::Pong
			parse_binary_pong(buffer)
		3: #ServerMessage::GameEnd
			parse_binary_game_end_message(buffer)
		8: #ServerMessage::PlayerDisconnected
			parse_binary_player_disconnected(buffer)
		12: #ServerMessage::PlayerMessage
			parse_binary_player_message(buffer)
		13: #ServerMessage::PlayerConnected
			parse_binary_player_connected(buffer)
		14: #ServerMessage::PlayerKilled
			parse_binary_scoreboard_data(buffer)
		#19: #ServerMessage::TowerCreated
			#parse_binary_tower_created(buffer)
				
func parse_binary_my_id(buffer:StreamPeerBuffer):
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
		var bullet_event_type: int = buffer.get_u32()
		if bullet_event_type == 0: #CREATED
			var b = create_bullets_snapshot(buffer)
			parsed_bullets.append(b)
		else:
			var bullet_id: int = buffer.get_u32()
			var position_destroyed_x: float = buffer.get_float()
			var position_destroyed_y: float = buffer.get_float()
			if bullets.has(bullet_id):
				var bullet_node = bullets[bullet_id]
				if bullet_node:
					bullet_node.queue_free()
				bullets.erase(bullet_id)
	#Citanje TowerSnapshots
	var parsed_towers: Array = []
	var num_towers = buffer.get_u64()
	
	for i in range(num_towers):
		var tower_event_type: int = buffer.get_u32()
		if tower_event_type == 0: #CREATED
			pass
			#var t = create_towers_snapshot(buffer)
			#parsed_towers.append(t)
			#spawn_towers(parsed_towers)
		else: #DAMAGED
			var tower_id: int = buffer.get_u32()
			var owner_id: int = buffer.get_u32()
			var tower_hp: int = buffer.get_32()
			var tower_data: Dictionary = {}
			tower_data["id"] = tower_id
			tower_data["owner_id"] = owner_id
			tower_data["hp"] = tower_hp
			
			parsed_towers.append(tower_data)
	
	var parsed_grenades: Array = []
	var num_grenades: int = buffer.get_u64()
	
	for i in range(num_grenades):
		var grenade_event_type: int = buffer.get_u32()
		if grenade_event_type == 0: #CREATED
			var g = create_grenade_snapshot(buffer)
			parsed_grenades.append(g)
	
	
	update_players(parsed_players)
	update_bullets(parsed_bullets)
	update_towers(parsed_towers)
	update_grenades(parsed_grenades)

func parse_binary_pong(buffer: StreamPeerBuffer):
	var timestamp = buffer.get_u64()
	Network.calculate_ping(timestamp)

func parse_binary_game_end_message(buffer: StreamPeerBuffer):
	var winner_id = buffer.get_u32()
	
	if winner_id != 0:
		players[Network.my_id].show_game_end_message(players[winner_id], winner_id)
	
	LevelManager.TOWERS_CREATE_INFO = []
	end_game_timer.start(5)

func parse_binary_player_disconnected(buffer: StreamPeer):
	var player_id = buffer.get_u32()
	var player_node = players[player_id]
	#var host_id = buffer.get_u32()
	player_node.queue_free()
	players.erase(player_id)
	Signals.UPDATE_SCOREBOARD_DISCONNECTED.emit(player_id)

func parse_binary_player_message(buffer: StreamPeerBuffer):
	var player_id: int = buffer.get_u32()
	if players.has(player_id):
		var message_length: int = buffer.get_u64()
		var message: String = buffer.get_utf8_string(message_length)
		var message_from_player: OtherPlayer = players[player_id]
		var player_nickname: String = message_from_player.NICKNAME
		players[Network.my_id].add_message(player_nickname, message)

func parse_binary_player_connected(buffer: StreamPeerBuffer):
	var player_id: int = buffer.get_u32()
	if disconnected_players.has(player_id):
		disconnected_players.erase(player_id)

func parse_binary_scoreboard_data(buffer: StreamPeerBuffer):
	var killer_id: int = buffer.get_u32()
	var victim_id: int = buffer.get_u32()
	var gun_id: int = buffer.get_u32() #GunEnum
	scoreboard_info[killer_id] += 1
		
	var kill_events: Dictionary = {}
	
	kill_events["killer_id"] = killer_id
	kill_events["victim_id"] = victim_id
	if gun_id == 0:
		kill_events["killed_with"] = "pistol"
	elif gun_id == 1:
		kill_events["killed_with"] = "m4a1_rifle"
	elif gun_id == 2:
		kill_events["killed_with"] = "grenade"
	
	var kill_event_snapshot = []
	kill_event_snapshot.append(kill_events)
	update_kill_events(kill_event_snapshot)
	
	Signals.UPDATE_SCOREBOARD.emit(scoreboard_info)

func create_players_snapshot(buffer: StreamPeerBuffer):
	var snapshot: Dictionary = {}
	
	snapshot["id"] = buffer.get_u32()
	
	var name_length = buffer.get_u64() 
	snapshot["nickname"] = buffer.get_utf8_string(name_length)
	
	var pos_x = buffer.get_float()
	var pos_y = buffer.get_float()
	snapshot["position"] = Vector2(pos_x, pos_y)
	
	snapshot["hp"] = buffer.get_32()
	
	#is_facing_right
	var flags_byte: int = buffer.get_u8()
	var facing_right = (flags_byte & FLAG_FACING_RIGHT) != 0
	var is_on_ground = (flags_byte & FLAG_IS_ON_GROUND) != 0
	var is_reloading = (flags_byte & FLAG_IS_RELOADING) != 0
	
	snapshot["facing_right"] = facing_right
	snapshot["is_on_ground"] = is_on_ground
	snapshot["is_reloading"] = is_reloading
	
	snapshot["respawn_timer"] = buffer.get_float()
	snapshot["last_processed_input_id"] = buffer.get_u32()
	snapshot["mouse_angle"] = buffer.get_float()
	
	var gun_id = buffer.get_u32() 
	if gun_id == 0:
		snapshot["gun"] = "pistol"
	elif gun_id == 1:
		snapshot["gun"] = "m4a1_rifle"
	elif gun_id == 2:
		snapshot["gun"] = "grenade"
	
	snapshot["current_ammo"] = buffer.get_16()
	snapshot["player_skin"] = buffer.get_u8()
	snapshot["player_score"] = buffer.get_u8()
	snapshot["velocity_x"] = buffer.get_u32()
	snapshot["velocity_y"] = buffer.get_u32()
	
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

func create_grenade_snapshot(buffer: StreamPeerBuffer) -> Dictionary:
	var grenade_id: int = buffer.get_u32()
	var grenade_owner_id: int = buffer.get_u32()
	var grenade_position_x: float = buffer.get_float()
	var grenade_position_y: float = buffer.get_float()
	var grenade_angle: float = buffer.get_float()
	
	var grenade_data: Dictionary = {}
	grenade_data["id"] = grenade_id
	grenade_data["owner_id"] = grenade_owner_id
	grenade_data["position"] = [grenade_position_x, grenade_position_y]
	grenade_data["angle"] = grenade_angle
	
	return grenade_data

func parse_binary_tower_created(buffer: StreamPeerBuffer):
	var tower_list = []
	var tower = {}
	tower["id"] = buffer.get_u32()
	tower["owner_id"] =  buffer.get_u32()
	tower["hp"] = buffer.get_32()
	tower["is_left_tower"] = buffer.get_u8()
	tower_list.append(tower)
	spawn_towers(tower_list)
	#return tower

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
	elif gun_id == 2:
		kill_events["killed_with"] = "grenade"
	return kill_events
	
func spawn_players(snapshot: Array): # Array[Dictionary]
	for player_snapshot in snapshot:
		var player_id = player_snapshot["id"]
		Signals.UPDATE_SCOREBOARD_CONNECTED.emit(player_id, player_snapshot["nickname"], player_snapshot["player_skin"], player_snapshot["player_score"])	

		if players.has(player_id):
			continue
		
		scoreboard_info[player_id] = player_snapshot["player_score"]
		if player_id == Network.my_id:
			var my_player = PLAYER.instantiate()
			my_player.name = "My_Player"
			self.add_child(my_player)
			players[player_id] = my_player
		else:
			var other_player: OtherPlayer = OTHER_PLAYER.instantiate()
			other_player.SKIN_INDEX = player_snapshot["player_skin"]
			self.add_child(other_player)
			players[player_id] = other_player
		
func update_players(snapshot: Array):
	#check_disconnected(snapshot)
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
					var bullet: PlayerPistolBullet = PlayerPistolBullet.new(client_spawn_position, rad_to_deg(bullet_snapshot["angle"]))
					bullet.instantiate_bullet(server_spawn_position, true)
					bullets[bullet_id] = bullet
					players[bullet_snapshot["owner_id"]].pitol_shoot_sound.play()
					players[bullet_snapshot["owner_id"]].play_gun_blast_animation()
			"m4a1_rifle":
				if Network.my_id != bullet_snapshot["owner_id"]:
					var client_spawn_position = players[bullet_snapshot["owner_id"]].get_bullet_spawn_position_marker().global_position
					var server_spawn_position:Vector2 = Vector2(bullet_snapshot["position"][0] * 32, bullet_snapshot["position"][1] * 32)
					var bullet: PlayerM4A1Bullet = PlayerM4A1Bullet.new(client_spawn_position, rad_to_deg(bullet_snapshot["angle"]))
					bullet.instantiate_bullet(server_spawn_position, true)
					bullets[bullet_id] = bullet
					players[bullet_snapshot["owner_id"]].m4a1_rifle_shoot_sound.play()
					players[bullet_snapshot["owner_id"]].play_gun_blast_animation()
func update_bullets(snapshot: Array):
	#check_bullet_destroyed(snapshot)
	spawn_bullets(snapshot)
	if Network.my_id != -1:
		for bullet_snapshot in snapshot:
			var bullet_id = bullet_snapshot["id"]
			var bullet_owner_id = bullet_snapshot["owner_id"]
			if Network.my_id != bullet_owner_id:
				if bullets[bullet_id] != null:
					var bullet_node: PlayerBullet = bullets[bullet_id]
					#bullet_node.handle_server_response(bullet_snapshot)

func spawn_grenades(snapshot: Array):
	for grenade_snapshot in snapshot:
		var grenade_id = grenade_snapshot["id"]

		#if grenades.has(grenade_id):
			#continue
		#
		if grenade_snapshot["owner_id"] != Network.my_id:
			var grenade: Throwable = GRENADE.instantiate()
			self.add_child(grenade)
			grenade.throw(Vector2(grenade_snapshot["position"][0] * 32, grenade_snapshot["position"][1] * 32), Vector2.from_angle(grenade_snapshot["angle"]))
			grenades[grenade_id] = grenade
	
func update_grenades(snapshot: Array):
	spawn_grenades(snapshot)

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
		tower.setup(tower_snapshot, left_tower_position.global_position, right_tower_position.global_position)
		towers[tower_id] = tower
			
func update_towers(tower_snapshots: Array):
	#check_disconnected_towers(tower_snapshots)
	#spawn_towers(tower_snapshots)
	for tower_snapshot in tower_snapshots:	
		var tower_id = tower_snapshot["id"]
		var tower: Tower = towers[tower_id]
		tower.handle_server_response(tower_snapshot)

func check_disconnected_towers(snapshot: Array):
	var active_ids = []
	for tower_snapshot in snapshot:
		active_ids.append(tower_snapshot["id"])
	
	for tower_id in towers.keys():
		if tower_id not in active_ids:
			var tower_node = towers[tower_id]
			tower_node.queue_free()
			towers.erase(tower_id)
			

func check_disconnected(snapshot: Array):
	var active_ids = []
	for player_snapshot in snapshot:
		active_ids.append(player_snapshot["id"])
	
	for player_id in players.keys():
		if player_id not in active_ids:
			var player_node = players[player_id]
			player_node.queue_free()
			players.erase(player_id)
			
			#SAMO ZA GAME MODE SA KULAMA!
			players[Network.my_id].show_game_end_message(null, null, "GAME SUSPENDED!")
			
			end_game_timer.start(5)

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

func _on_end_game_timer_timeout() -> void:
	get_tree().change_scene_to_file("res://Scenes/Lobby/Lobby.tscn")
