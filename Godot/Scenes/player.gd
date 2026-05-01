extends CharacterBody2D
class_name MyPlayer

#SCENES
const KILL_FEED_SCENE = preload("res://Scenes/Effects/kill_feed.tscn")
const DEATH_MESSAGE_SCENE = preload("res://Scenes/Effects/Death_Message_Screen.tscn")
const GAME_END_MESSAGE_SCENE = preload("res://Scenes/Effects/End_Game.tscn")
const PLAYER_MESSAGE_SCENE = preload("res://Scenes/Lobby/Player_Message.tscn")
const HAND_GRENADE_SCENE = preload("res://Scenes/Guns/Throwables/Hand_Grenade.tscn")
const THROWABLE_SCENE = preload("res://Scenes/Other_Player/Other_Player_Throwable.tscn")

@onready var kill_image: Sprite2D = $kill_image
@onready var kill_feed_position: Marker2D = $kill_feed_position

var inputs_list: Array[PlayerMoveCommand] = []
var state_history: Array[Dictionary] = []
const SERVER_SPEED = 10
const METER_TO_PIXEL = 32
#const SERVER_DELTA = 0.016
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
@onready var walking_sprite: Sprite2D = $Visuals/walking_sprite
@onready var idle_sprite: Sprite2D = $Visuals/idle_sprite
@onready var dying_sprite: Sprite2D = $Visuals/dying_sprite
@onready var hurt_sprite: Sprite2D = $hurt_sprite
@onready var visuals: Node2D = $Visuals

@onready var ping_label: Label = $Visuals/Camera2D/Ping_Label

#HUD
@onready var ammo_label: Label = $Visuals/Camera2D/Health_Bar/Ammo_Label
@onready var gun_sprite: Sprite2D = $Visuals/Camera2D/Health_Bar/Gun_Sprite
@onready var health_amount: Sprite2D = $Visuals/Camera2D/Health_Bar/Health_Amount
@onready var kill_feed_container: KillFeedContainer = $Visuals/Kill_Feed_Container
@onready var throwables_container: HBoxContainer = $Visuals/Throwables_Container
@onready var throwable_trajectory_line: Line2D = $Visuals/Throwable_Trajectory_Line

#SOUND
@onready var walk_sound: AudioStreamPlayer2D = $Walk_Sound
@onready var walk_sound_timer: Timer = $Walk_Sound_Timer
@onready var jump_sound: AudioStreamPlayer2D = $Jump_Sound
@onready var hit_sound: AudioStreamPlayer2D = $Hit_Sound
var can_play_walk_sound: bool = true

#PAUSE MENU
@onready var pause_menu: PauseMenu = $Visuals/Camera2D/PauseMenu
#CHAT
@onready var in_game_chat: Node2D = $Visuals/Camera2D/In_Game_Chat
@onready var messages_container: VBoxContainer = $Visuals/Camera2D/In_Game_Chat/ScrollContainer/Messages_Container
@onready var message_input: LineEdit = $Visuals/Camera2D/Message_Input
@onready var scroll_container: ScrollContainer = $Visuals/Camera2D/In_Game_Chat/ScrollContainer

#SCOREBOARD
@onready var scoreboard: Node2D = $Visuals/Camera2D/Scoreboard

var pistol: Pistol = null
var m4a1_rifle: m4a1Rifle = null
var hand_grenade: Throwable = null
var weapons: Array[PlayerGun] = []
var weapon_index = 0
var throwables: Array[PlayerThrowable] = []
var throwable_map: Dictionary = {
	"grenade": 0
}

#THROWABLES
#var throwables: Dictionary = {
	#"grenade": "",
	#"flash": "",
	#"smoke": ""
#}
var current_throwable: Throwable = null
var current_throwable_hand: PlayerThrowable = null
var current_throwable_index = null
var num_grenades: int = 1
var num_smokes: int = 1
var num_flashes: int = 1

const PISTOL_SCENE = preload("res://Scenes/Pistol.tscn")
const M4A1_RIFLE_SCENE = preload("res://Scenes/m4a1.tscn")
@onready var gun_anchor: Marker2D = $Visuals/Gun_Anchor

var weapons_names_list = ["pistol", "m4a1_rifle"]

var is_dead: bool = false
var game_finished: bool = false

var current_gun_sprites: Array = [
	load("res://Sprites/effects/pistol_kill.png"),
	load("res://Sprites/effects/m4a1_rifle_kill.png"),
	load("res://Sprites/effects/grenade_kill.png")]

var death_message_node: DeathMessageScreen = null
var time_till_respawn: float = 0.0

var target_position: Vector2
const PHYSICS_DELTA = 1.0 / 60.0

var position_error = Vector2.ZERO

var has_thrown_throwable: bool = false

##JOYSTICK
@onready var look_joystick: VirtualJoystickPlus = $Look_Joystick
@onready var move_joystick: VirtualJoystickPlus = $Move_Joystick



func _ready() -> void:
	pistol = Pistol.new(PISTOL_SCENE, gun_anchor, LevelManager.players_pistol_hand_sprite_skin[Network.my_skin_id], LevelManager.players_pistol_hand_reload_sprites_skin[Network.my_skin_id])
	m4a1_rifle = m4a1Rifle.new(M4A1_RIFLE_SCENE, gun_anchor, LevelManager.players_m4a1_hand_sprite_skin[Network.my_skin_id], LevelManager.players_m4a1_hand_reload_sprites_skin[Network.my_skin_id])
	var grenade: PlayerThrowable = PlayerThrowable.new(THROWABLE_SCENE, gun_anchor, LevelManager.players_grenade_hand_sprite_skin[Network.my_skin_id], preload("res://Sprites/throwables/hand_grenade.png"))
	weapons.append(pistol)
	weapons.append(m4a1_rifle)
	throwables.append(grenade)
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
	var id = Network.INPUT_DATA.get("input_id")
	if id == null:
		return
	var move_command: PlayerMoveCommand = handle_move_inputs(Network.INPUT_DATA["input_id"], delta)
	apply_movement_step(move_command, PHYSICS_DELTA)
	if not self.message_input.visible and not self.pause_menu.visible:
		Network.INPUT_DATA["input_id"] += 1
		handle_inputs(delta)
		state_history.append(
			{
				"id": Network.INPUT_DATA["input_id"],
				"global_position": global_position
			}
		)
		#if Network.INPUT_DATA["input_id"] % 3 == 0:
		send_data(move_command)
		
				
	handle_pausable_actions(delta)
	ping_label.text = str("PING: ", Network.current_ping, "ms")
	if current_throwable_hand == null:
		ammo_label.visible = true
		ammo_label.text = str(weapons[weapon_index].current_ammo, "/", weapons[weapon_index].max_ammo )
	else:
		ammo_label.visible = false
		
	health_amount.scale.x = lerp(health_amount.scale.x, float(HP)/100, 0.2)
	
	var lerp_factor = 0.25
	if Network.current_ping > 50:
		lerp_factor = 0.15
	if Network.current_ping > 100:
		lerp_factor = 0.05
	
	##position_error = position_error.lerp(Vector2.ZERO, 0.25)
	visuals.position = visuals.position.lerp(Vector2.ZERO, 0.06)
	
	if throwable_trajectory_line.visible:
		check_for_throwable_indicator(PHYSICS_DELTA)

func check_for_throwable_indicator(delta:float):
	var points = []
	var pos = global_position
	var vel = Vector2.from_angle(deg_to_rad(JoystickInputs.get_look_position())) * 550
	
	for i in range(30):
		points.append(to_local(pos))
		
		vel.y += GRAVITY * METER_TO_PIXEL * delta
		
		pos += vel * delta
		
	throwable_trajectory_line.points = points


func apply_movement_step(command: PlayerMoveCommand, delta: float):
	command.execute(delta)

func handle_move_inputs(input_id: int, delta: float) -> PlayerMoveCommand:
	var has_pressed_left: bool = false
	var has_pressed_right: bool = false
	var has_pressed_jump: bool = false
	if not self.pause_menu.visible and not self.message_input.visible:
		#has_pressed_left = Input.is_action_pressed("left")
		has_pressed_left = move_joystick.get_value().x <= -0.1
		has_pressed_right = move_joystick.get_value().x >= 0.1
		has_pressed_jump = (move_joystick.get_value().y <= -0.5 and move_joystick.get_value().y <= 0.5)
		#has_pressed_right= Input.is_action_pressed("right")
		#has_pressed_jump = Input.is_action_pressed("jump")
	
	Network.INPUT_DATA["move_left"] = has_pressed_left
	Network.INPUT_DATA["move_right"] = has_pressed_right
	Network.INPUT_DATA["jump"] = has_pressed_jump
	
	var command: PlayerMoveCommand = PlayerMoveCommand.new(self, input_id)
	command.move_left = has_pressed_left
	command.move_right = has_pressed_right
	command.jump = has_pressed_jump
	
	return command
	
func handle_inputs(delta: float):
	if Network.INPUT_DATA["gun"] == "m4a1_rifle":
		Network.INPUT_DATA["shoot"] = Input.is_action_pressed("shoot")
	else:
		Network.INPUT_DATA["shoot"] = Input.is_action_just_pressed("shoot")
	#if Network.INPUT_DATA["gun"] == "pistol":
		#Network.INPUT_DATA["shoot"] = Input.is_action_just_pressed("shoot")
	#else:
		#Network.INPUT_DATA["shoot"] = Input.is_action_pressed("shoot")
	
	#Network.INPUT_DATA["mouse_angle"] = get_local_mouse_position().angle()
	if look_joystick.get_value() != Vector2.ZERO:
		JoystickInputs.set_look_position(look_joystick.get_angle_degrees(false, true))
	Network.INPUT_DATA["mouse_angle"] = JoystickInputs.get_look_position()
	
	if Input.is_action_just_pressed("switch_next"):
		if current_throwable_hand == null:
			weapons[weapon_index].remove_gun_from_scene()
		else:
			throwables[current_throwable_index].remove_throwable_from_scene()
		current_throwable = null
		current_throwable_hand = null
		current_throwable_index = -1
		throwable_trajectory_line.visible = false
		
		weapon_index = (weapon_index + 1) % len(weapons)
		weapons[weapon_index].instantiate_gun()
		Network.INPUT_DATA["gun"] = weapons_names_list[weapon_index]
		gun_sprite.texture = current_gun_sprites[weapon_index]
		CustomCursor.set_sight_cursor_visible()
		
	if Input.is_action_just_pressed("switch_previous"):
		if current_throwable_hand == null:
			weapons[weapon_index].remove_gun_from_scene()
		else:
			throwables[current_throwable_index].remove_throwable_from_scene()
		current_throwable = null
		current_throwable_hand = null
		current_throwable_index = -1
		throwable_trajectory_line.visible = false
		
		weapon_index -= 1
		if weapon_index < 0:
			weapon_index = len(weapons) - 1
		weapons[weapon_index].instantiate_gun()
		
		Network.INPUT_DATA["gun"] = weapons_names_list[weapon_index]
		gun_sprite.texture = current_gun_sprites[weapon_index]
		CustomCursor.set_sight_cursor_visible()
	
	if Input.is_action_just_pressed("HandGrenade"):
		if num_grenades > 0 and current_throwable_hand == null and current_throwable_index != 0:
			current_throwable_index = 0
			weapons[weapon_index].remove_gun_from_scene()
			current_throwable_hand = throwables[current_throwable_index]
			throwables[current_throwable_index].instantiate_throwable()
			Network.INPUT_DATA["gun"] = "grenade"
			gun_sprite.texture = current_gun_sprites[2]
			throwable_trajectory_line.visible = true
		
	#
	if Input.is_action_just_pressed("shoot") and current_throwable_hand != null:
		num_grenades -= 1
		current_throwable = HAND_GRENADE_SCENE.instantiate()
		throwables[current_throwable_index].remove_throwable_from_scene()
		LevelManager.CURRENT_LEVEL_NODE.add_child(current_throwable)
		current_throwable.throw(self.global_position, Vector2.from_angle(deg_to_rad(Network.INPUT_DATA["mouse_angle"])))
		current_throwable = null
		current_throwable_hand = null
		throwable_trajectory_line.visible = false
		has_thrown_throwable = true
		
		CustomCursor.set_sight_cursor_visible()
		throwables_container.get_child(current_throwable_index).queue_free()
	
	if Input.is_action_just_pressed("reload"):
		if current_throwable == null:
			Network.INPUT_DATA["command"] = "RELOAD"
			weapons[weapon_index].play_reload_animation()
		
	var is_moving: bool = (move_joystick.get_value().x <= -0.1 or move_joystick.get_value().x >= 0.1)
	if is_moving and not self.is_dead:
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
	
	if cos(deg_to_rad(JoystickInputs.get_look_position())) > 0.0:
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
	
func send_data(move_command: PlayerMoveCommand):
	if !Network.is_disconnecting:
		var packed_byte_array: PackedByteArray = Network.convert_input_data_to_byte_array()
		Network.send_data(packed_byte_array)
		inputs_list.append(move_command)
		if inputs_list.size() > 30:
			inputs_list = inputs_list.slice(-30)
		Network.INPUT_DATA["command"] = "NONE"
		
		if has_thrown_throwable:#Switching to m4a1 rifle
			has_thrown_throwable = false
			weapon_index = 1
			weapons[weapon_index].instantiate_gun()
			Network.INPUT_DATA["gun"] = weapons_names_list[weapon_index]
			gun_sprite.texture = current_gun_sprites[weapon_index]
			current_throwable_index = -1
		#if inputs_list.size() > 120: 
			#inputs_list.remove_at(0)

func handle_server_response(player_snapshot: Dictionary):
	target_position = Vector2(player_snapshot["position"][0] * METER_TO_PIXEL, player_snapshot["position"][1] * METER_TO_PIXEL)
	var last_processed_id = player_snapshot["last_processed_input_id"]
	#is_on_ground = player_snapshot["is_on_ground"]
	
	if not throwable_map.has(player_snapshot["gun"]):
		weapons[weapon_index].update_from_server(player_snapshot)
		if weapons_names_list[weapon_index] != player_snapshot["gun"]:
			weapons[weapon_index].reload_sound.stop()
	else: #BOMBE
		throwables[throwable_map[player_snapshot["gun"]]].set_snapshot(player_snapshot)
		
	while len(inputs_list) > 0 and inputs_list[0].input_id <= last_processed_id:
		inputs_list.remove_at(0)
		
	var checking_state = null
	var match_index: int = -1
	for i in range(len(state_history)):
		if state_history[i]["id"] == last_processed_id:
			checking_state = state_history[i]
			match_index = i
			break
	
	
		
	if checking_state != null:
		var error_vec = target_position - checking_state["global_position"]
	
		var distance = error_vec.length()
		#TESKA KOREKCIJA
		if distance > 100.0:
			global_position = target_position
			for input_item in inputs_list:
				apply_movement_correction(input_item, PHYSICS_DELTA)
		
		#LAGANA KOREKCIJA
		
		else:
			var old_pos = global_position
			global_position = target_position
			#vertical_velocity = player_snapshot["velocity_y"] * METER_TO_PIXEL
			#is_on_ground = player_snapshot["is_on_ground"]
			#for input_item in inputs_list:
				#apply_movement_correction(input_item, PHYSICS_DELTA)
			
			var new_predicted_pos = global_position
			var offset = old_pos - new_predicted_pos
			visuals.global_position += offset 

	while state_history.size() > 0 and state_history[0]["id"] <= last_processed_id:
		state_history.remove_at(0)
	
	check_for_dying_animation(player_snapshot)

	
func apply_movement_correction(move_command: PlayerMoveCommand, delta: float):
	move_command.execute(delta)
	
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
			if num_grenades <= 0:
				num_grenades = 1
				
				var grenade_icon = TextureRect.new()
				grenade_icon.texture = preload("res://Sprites/effects/grenade_kill.png")
				grenade_icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
				grenade_icon.stretch_mode = TextureRect.STRETCH_SCALE
				grenade_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

				throwables_container.add_child(grenade_icon)
			
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
	#if area.is_in_group("solids"):
		#can_move_right = false
	if area.is_in_group("tower_hit_box"):
		can_move_right = false

func _on_right_indicator_area_exited(area: Area2D) -> void:
	#if area.is_in_group("solids"):
		#can_move_right = true
	if area.is_in_group("tower_hit_box"):
		can_move_right = true

func _on_left_indicator_area_entered(area: Area2D) -> void:
	#if area.is_in_group("solids"):
		#can_move_left = false
	if area.is_in_group("tower_hit_box"):
		can_move_left = false

func _on_left_indicator_area_exited(area: Area2D) -> void:
	#if area.is_in_group("solids"):
		#can_move_left = true
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
			
