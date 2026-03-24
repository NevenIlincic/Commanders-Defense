extends CharacterBody2D
class_name MyPlayer

#SCENES
const KILL_FEED_SCENE = preload("res://Scenes/Effects/kill_feed.tscn")
const DEATH_MESSAGE_SCENE = preload("res://Scenes/Effects/Death_Message_Screen.tscn")
const GAME_END_MESSAGE_SCENE = preload("res://Scenes/Effects/End_Game.tscn")
const PLAYER_MESSAGE_SCENE = preload("res://Scenes/Lobby/Player_Message.tscn")

@onready var kill_image: Sprite2D = $kill_image
@onready var kill_feed_position: Marker2D = $kill_feed_position

var inputs_list: Array[Dictionary] = []
var state_history: Array[Dictionary] = []
const SERVER_SPEED = 10
const METER_TO_PIXEL = 32
const SERVER_DELTA = 0.016
const JUMP_VELOCITY = 12.0
const GRAVITY = 15.0 
var vertical_velocity = 0.0

var can_move_left = true
var can_move_right = true
var is_on_ground: bool = false

var last_processed_event_kill_id: int = 0

var players_kill_images: Dictionary = { }
var HP: int = 100


@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var walking_sprite: Sprite2D = $walking_sprite
@onready var idle_sprite: Sprite2D = $idle_sprite
@onready var dying_sprite: Sprite2D = $dying_sprite
@onready var hurt_sprite: Sprite2D = $hurt_sprite

@onready var ping_label: Label = $Camera2D/Ping_Label

#HUD
@onready var ammo_label: Label = $Camera2D/Health_Bar/Ammo_Label
@onready var gun_sprite: Sprite2D = $Camera2D/Health_Bar/Gun_Sprite
@onready var health_amount: Sprite2D = $Camera2D/Health_Bar/Health_Amount
@onready var kill_feed_container: KillFeedContainer = $Kill_Feed_Container

#SOUND
@onready var walk_sound: AudioStreamPlayer2D = $Walk_Sound
@onready var walk_sound_timer: Timer = $Walk_Sound_Timer
@onready var jump_sound: AudioStreamPlayer2D = $Jump_Sound
@onready var hit_sound: AudioStreamPlayer2D = $Hit_Sound
var can_play_walk_sound: bool = true

#PAUSE MENU
@onready var pause_menu: PauseMenu = $Camera2D/PauseMenu
#CHAT
@onready var in_game_chat: Node2D = $Camera2D/In_Game_Chat
@onready var messages_container: VBoxContainer = $Camera2D/In_Game_Chat/ScrollContainer/Messages_Container
@onready var message_input: LineEdit = $Camera2D/Message_Input
@onready var scroll_container: ScrollContainer = $Camera2D/In_Game_Chat/ScrollContainer

#SCOREBOARD
@onready var scoreboard: Node2D = $Camera2D/Scoreboard

var pistol: Pistol = null
var m4a1_rifle: m4a1Rifle = null
var weapons: Array[PlayerGun] = []
var weapon_index = 0

const PISTOL_SCENE = preload("res://Scenes/Pistol.tscn")
const M4A1_RIFLE_SCENE = preload("res://Scenes/m4a1.tscn")
@onready var gun_anchor: Marker2D = $Gun_Anchor

var weapons_names_list = ["pistol", "m4a1_rifle"]

var is_dead: bool = false
var game_finished: bool = false

var current_gun_sprites: Array = [
	load("res://Sprites/effects/pistol_kill.png"),
	load("res://Sprites/effects/m4a1_rifle_kill.png")]

var death_message_node: DeathMessageScreen = null
var time_till_respawn: float = 0.0
@onready var ray_shape_down: ShapeCast2D = $ray_shape_down
@onready var ray_shape_top: ShapeCast2D = $ray_shape_top
@onready var ray_bottom: RayCast2D = $ray_bottom

func _ready() -> void:
	pistol = Pistol.new(PISTOL_SCENE, gun_anchor, LevelManager.players_pistol_hand_sprite_skin[Network.my_skin_id], LevelManager.players_pistol_hand_reload_sprites_skin[Network.my_skin_id])
	m4a1_rifle = m4a1Rifle.new(M4A1_RIFLE_SCENE, gun_anchor, LevelManager.players_m4a1_hand_sprite_skin[Network.my_skin_id], LevelManager.players_m4a1_hand_reload_sprites_skin[Network.my_skin_id])
	weapons.append(pistol)
	weapons.append(m4a1_rifle)
	weapons[weapon_index].instantiate_gun()
	Network.INPUT_DATA["gun"] = weapons_names_list[weapon_index]
	gun_sprite.texture = current_gun_sprites[weapon_index]
	
	in_game_chat.visible = false
	message_input.visible = false
	scoreboard.visible = false
	set_up_player_skin()
	
func set_up_player_skin():
	walking_sprite.texture = LevelManager.players_walking_sprites_skin[Network.my_skin_id]
	idle_sprite.texture = LevelManager.players_idle_sprites_skin[Network.my_skin_id]
	dying_sprite.texture = LevelManager.players_dying_spirtes_skin[Network.my_skin_id]
	kill_image.texture = LevelManager.players_kill_image_skin[Network.my_skin_id]

func _physics_process(delta: float) -> void:
	if not self.message_input.visible and not self.pause_menu.visible:
		handle_inputs(delta)
		Network.INPUT_DATA["input_id"] += 1
		apply_movement_step(Network.INPUT_DATA, SERVER_DELTA)
		state_history.append(
			{
				"id": Network.INPUT_DATA["input_id"],
				"global_position": global_position
			}
		)
		send_data()
		
				
	handle_pausable_actions(delta)
	ping_label.text = str("PING: ", Network.current_ping, "ms")
	ammo_label.text = str(weapons[weapon_index].current_ammo, "/", weapons[weapon_index].max_ammo )
	health_amount.scale.x = lerp(health_amount.scale.x, float(HP)/100, 0.2)

func apply_movement_step(input_data: Dictionary, delta: float):
	if self.is_dead:
		return

	# --- KORAK 1: GRAVITACIJA (Kao u Rustu: pre bilo kakvog pomeranja) ---
	if is_on_ground and vertical_velocity >= 0.0:
		vertical_velocity = 0.0
	
	# Rust: player.vertical_velocity += custom_gravity.y * delta;
	vertical_velocity += GRAVITY * delta # GRAVITY je 15.0
	
	if vertical_velocity > 12.0:
		vertical_velocity = 12.0

	# --- KORAK 2: X OSA (Kao u Rustu: move_shape horizontal) ---
	var direction = 0
	if input_data.get("move_left", false): direction -= 1
	if input_data.get("move_right", false): direction += 1
	global_position.x += direction * SERVER_SPEED * METER_TO_PIXEL * delta

	# --- KORAK 3: SKOK (Provera inputa) ---
	# NAPOMENA: U Rustu skok verovatno menja brzinu pre Y pomeranja
	if input_data.get("jump", false) and is_on_ground:
		vertical_velocity = -JUMP_VELOCITY # -12.0
		is_on_ground = false

	# --- KORAK 4: Y OSA (Kao u Rustu: move_shape vertical) ---
	# Primenjujemo vertikalnu brzinu na poziciju
	global_position.y += vertical_velocity * delta * METER_TO_PIXEL

	# --- KORAK 5: KOLIZIJA I SNAPPING (Kao u Rustu: cast_ray na kraju) ---
	ray_bottom.force_raycast_update()
	#ray_shape_top.force_raycast_update()

	# Plafon (ako udariš u plafon dok ideš na gore)
	if ray_shape_top.is_colliding() and vertical_velocity < 0:
		vertical_velocity = 0.0

	# Pod (ako padaš i udariš u pod)
	if ray_bottom.is_colliding() and vertical_velocity > 0:
		var collision_y = ray_bottom.get_collision_point().y
		# Snapping na Rapier offset (0.01m * 32 = 0.32px)
		global_position.y = collision_y - 16.0 - 0.32
		# Ne setujemo brzinu na 0 ovde, jer će to Rust uraditi na POČETKU sledećeg frejma
	
	# Finalno ažuriranje stanja za sledeći frejm (Identisno sa Rust cast_ray)
	is_on_ground = ray_bottom.is_colliding()
	global_position.y = snapped(global_position.y, 0.001)
	#if self.is_dead:
		#return
#
	##HORIZONTALNO KRETANJE
	#var direction = 0
	#if input_data.get("move_left", false): direction -= 1
	#if input_data.get("move_right", false): direction += 1
	#
	#if direction == 1.0 and can_move_right:
		#global_position.x += direction * SERVER_SPEED * METER_TO_PIXEL * delta
	#elif direction == -1.0 and can_move_left:
		#global_position.x += direction * SERVER_SPEED * METER_TO_PIXEL * delta
#
	##VERTIKALNO KRETANJE
	##Gravitacija
	#vertical_velocity += GRAVITY * delta * METER_TO_PIXEL
	#
	##Vertikalna brzina
	#if vertical_velocity > 12.0 * METER_TO_PIXEL:
		#vertical_velocity = 12.0 * METER_TO_PIXEL
	#
	##Skok
	#if input_data.get("jump", false) and is_on_ground:
		#vertical_velocity = -JUMP_VELOCITY * METER_TO_PIXEL
		#is_on_ground = false
		#jump_sound.play()
	#
	##Provera da li je igrac udario u plafon
	#if ray_shape_top.is_colliding() and vertical_velocity < 0:
		#vertical_velocity = 0.0
		#
	##Provera da li je na igrac na podu
		#
	#if ray_bottom.is_colliding() and vertical_velocity > 0:
		#vertical_velocity = 0.0
		#is_on_ground = true
	#else:
		#is_on_ground = false
	#global_position.y += vertical_velocity * delta
	

func handle_inputs(delta: float):
	Network.INPUT_DATA["move_left"] = Input.is_action_pressed("left")
	Network.INPUT_DATA["move_right"] = Input.is_action_pressed("right")
	Network.INPUT_DATA["jump"] = Input.is_action_pressed("jump")
	if Network.INPUT_DATA["gun"] == "pistol":
		Network.INPUT_DATA["shoot"] = Input.is_action_just_pressed("shoot")
	else:
		Network.INPUT_DATA["shoot"] = Input.is_action_pressed("shoot")
	Network.INPUT_DATA["mouse_angle"] = get_local_mouse_position().angle()
	
	if Input.is_action_just_pressed("switch_next"):
		weapons[weapon_index].remove_gun_from_scene()
		weapon_index = (weapon_index + 1) % len(weapons)
		weapons[weapon_index].instantiate_gun()
		Network.INPUT_DATA["gun"] = weapons_names_list[weapon_index]
		gun_sprite.texture = current_gun_sprites[weapon_index]
		CustomCursor.set_sight_cursor_visible()
		
	if Input.is_action_just_pressed("switch_previous"):
		weapons[weapon_index].remove_gun_from_scene()
		weapon_index = (weapon_index - 1) % len(weapons)
		weapons[weapon_index].instantiate_gun()
		Network.INPUT_DATA["gun"] = weapons_names_list[weapon_index]
		gun_sprite.texture = current_gun_sprites[weapon_index]
		CustomCursor.set_sight_cursor_visible()
		
	if Input.is_action_just_pressed("reload"):
		Network.INPUT_DATA["command"] = "RELOAD"
		weapons[weapon_index].play_reload_animation()
		
	var direction = Input.get_axis("left", "right")
	if direction and not self.is_dead:
		walking_sprite.visible = true
		idle_sprite.visible = false
		animation_player.play("walking_animation")
		if can_play_walk_sound and is_on_ground:
			can_play_walk_sound = false
			walk_sound.play()
			walk_sound_timer.start(0.35)
		
	else:
		if not self.is_dead:
			walking_sprite.visible = false
			idle_sprite.visible = true
			animation_player.play("idle_animation")
	
	var mouse_angle = get_local_mouse_position().angle()
	if cos(mouse_angle) > 0.0:
		walking_sprite.flip_h = false
		idle_sprite.flip_h = false
	else:
		walking_sprite.flip_h = true
		idle_sprite.flip_h = true
		
	if Input.is_action_just_pressed("show_scoreboard"):
		scoreboard.visible = true
	if Input.is_action_just_released("show_scoreboard"):
		scoreboard.visible = false

func handle_pausable_actions(delta: float):
	if Input.is_action_just_pressed("chat"):
		in_game_chat.visible = true
		message_input.visible = !message_input.visible
	if message_input.visible:
		await get_tree().process_frame
		message_input.grab_focus()
	else:
		message_input.release_focus()

	if Input.is_action_just_pressed("show_hide_chat"):
		if not message_input.visible:
			in_game_chat.visible = !in_game_chat.visible	
	
	if not message_input.visible:
		if Input.is_action_just_pressed("escape"):
			pause_menu.show_hide_pause_menu()
	
func send_data():
	if !Network.is_disconnecting:
		var packed_byte_array: PackedByteArray = Network.convert_input_data_to_byte_array()
		Network.send_data(packed_byte_array)
		inputs_list.append(Network.INPUT_DATA)
		Network.INPUT_DATA["command"] = "NONE"
		#if inputs_list.size() > 120: 
			#inputs_list.remove_at(0)

func handle_server_response(player_snapshot: Dictionary):
	var target_position = Vector2(player_snapshot["position"][0] * METER_TO_PIXEL, player_snapshot["position"][1] * METER_TO_PIXEL)
	var last_processed_id = player_snapshot["last_processed_input_id"]
	#is_on_ground = player_snapshot["is_on_ground"]

	weapons[weapon_index].update_from_server(player_snapshot)
	if weapons_names_list[weapon_index] != player_snapshot["gun"]:
		weapons[weapon_index].reload_sound.stop()
		
	while len(inputs_list) > 0 and inputs_list[0]["input_id"] <= last_processed_id:
		inputs_list.remove_at(0)
		
	var checking_state = null
	var match_index: int = -1
	for i in range(len(state_history)):
		if state_history[i]["id"] == last_processed_id:
			checking_state = state_history[i]
			match_index = i
			break
		
	if checking_state != null:
		var error = target_position.distance_to(checking_state["global_position"])
		var error_x = abs(checking_state["global_position"].x - target_position.x)
		var error_y = abs(checking_state["global_position"].y - target_position.y)

		print(checking_state["global_position"].y, "  ", target_position.y)
		if error_x > 20.0 or error_y > 20.0:#20.0 20.0
			global_position = target_position
			vertical_velocity = player_snapshot["velocity_y"]* METER_TO_PIXEL
			is_on_ground = player_snapshot["is_on_ground"]
			for input_item in inputs_list:
				apply_movement_correction(input_item, SERVER_DELTA)
			state_history = state_history.slice(match_index + 1)
		#elif error > 2.0:
		else:
			#global_position = global_position.lerp(target_position, 0.2)
			state_history = state_history.slice(match_index + 1)
	else:
		if state_history.size() > 300:
			state_history.clear()
	check_for_dying_animation(player_snapshot)
	
func apply_movement_correction(input_data: Dictionary, delta: float):
	apply_movement_step(input_data, delta)
	if cos(input_data["mouse_angle"]) > 0.0:
		walking_sprite.flip_h = false
		idle_sprite.flip_h = false
	else:
		walking_sprite.flip_h = true
		idle_sprite.flip_h = true
	
func check_for_dying_animation(player_snapshot: Dictionary):
	time_till_respawn = player_snapshot["respawn_timer"]
	
	var is_respawning = player_snapshot["respawn_timer"] > 0.0
	if is_respawning:
		if not self.is_dead:
			self.is_dead = true
			can_move_left = false
			can_move_right = false
			
			self.walking_sprite.visible = false
			self.idle_sprite.visible = false
			self.dying_sprite.visible = true
			self.animation_player.play("dying_animation")
			var mouse_angle = get_local_mouse_position().angle()
			if cos(player_snapshot["mouse_angle"]) > 0:
				dying_sprite.flip_h = false
			else:
				dying_sprite.flip_h = true
				
			health_amount.visible = false
	else:
		if self.is_dead: 
			self.is_dead = false
			can_move_left = true
			can_move_right = true
			
			self.dying_sprite.visible = false

			self.animation_player.stop()
			HP = 100
			hurt_sprite.self_modulate.a = 0
			health_amount.scale.x = 1
			health_amount.visible = true
			
			if death_message_node != null:
				death_message_node.remove_from_parent_scene()
			
		check_for_hit_animation(player_snapshot)

func check_for_hit_animation(player_snapshot: Dictionary):
	if player_snapshot["hp"] != HP:
		HP = player_snapshot["hp"]
		hit_sound.play()
		if HP <= 30:
			hurt_sprite.visible = true
			hurt_sprite.self_modulate.a = 0.1
		else:
			hurt_sprite.self_modulate.a = 0
			hurt_sprite.visible = false
		print(str("POGODJEN SAM: ", HP))
		
func get_player_kill_image(id: int, players: Dictionary) -> Sprite2D:
	if id == Network.my_id:
		return self.kill_image
	
	if players.has(id):
		var img = players[id].find_child("kill_image")
		if img: return img
	
	return null 

func show_game_end_message(player_won: Node2D, winner_id, message=null):
	if not self.game_finished:
		self.game_finished = true
		var game_end_node: GameEndMessageScreen = GAME_END_MESSAGE_SCENE.instantiate()
		add_child(game_end_node)
		game_end_node.setup(player_won, winner_id, message)
		if death_message_node != null:
			death_message_node.queue_free()

func check_for_kill_display(snapshot: Array, players: Dictionary):
	if not self.game_finished:
		for kill_event in snapshot:			
			var k_id = kill_event["killer_id"]
			var v_id = kill_event["victim_id"]
			
			var killer_img = get_player_kill_image(k_id, players)
			var victim_img = get_player_kill_image(v_id, players)
			
			if killer_img == null or victim_img == null:
				continue
				
			
			var action = "neutral"
			if k_id == Network.my_id: action = "killed"
			elif v_id == Network.my_id: action = "death"
			
			var kill_feed = KILL_FEED_SCENE.instantiate()
			kill_feed_container.add_kill_feed(kill_feed)
			kill_feed.setup(
				killer_img, 
				victim_img, 
				kill_event["killed_with"], 
				kill_feed_position.global_position, 
				action
			)
			
			if action == "death":
				death_message_node = DEATH_MESSAGE_SCENE.instantiate()
				self.add_child(death_message_node)
				death_message_node.setup(killer_img, players[k_id].NICKNAME, time_till_respawn)

func add_message(player_nickname: String, message_text: String):
	var player_message: PlayerMessage = PLAYER_MESSAGE_SCENE.instantiate()
	messages_container.add_child(player_message)
	player_message.setup(player_nickname, message_text)
	await get_tree().process_frame
	await get_tree().process_frame
	
	scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)
		
func _on_right_indicator_area_entered(area: Area2D) -> void:
	if area.is_in_group("solids"):
		can_move_right = false
	if area.is_in_group("tower_hit_box"):
		can_move_right = false

func _on_right_indicator_area_exited(area: Area2D) -> void:
	if area.is_in_group("solids"):
		can_move_right = true
	if area.is_in_group("tower_hit_box"):
		can_move_right = true

func _on_left_indicator_area_entered(area: Area2D) -> void:
	if area.is_in_group("solids"):
		can_move_left = false
	if area.is_in_group("tower_hit_box"):
		can_move_left = false

func _on_left_indicator_area_exited(area: Area2D) -> void:
	if area.is_in_group("solids"):
		can_move_left = true
	if area.is_in_group("tower_hit_box"):
		can_move_left = true

func _on_walk_sound_timer_timeout() -> void:
	can_play_walk_sound = true


func _on_chat_input_text_submitted(new_text: String) -> void:
	if new_text != "":
		MyHttpHandler.send_message(new_text)
		add_message(Network.my_nickname, new_text)
		message_input.clear()
		message_input.release_focus()
			
