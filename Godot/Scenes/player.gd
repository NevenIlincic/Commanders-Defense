extends CharacterBody2D
class_name MyPlayer

var inputs_list: Array[Dictionary] = []
const SERVER_SPEED = 10
const METER_TO_PIXEL = 32
const SERVER_DELTA = 0.016

const JUMP_VELOCITY = 12.0
const GRAVITY = -15.0 
var vertical_velocity = 0.0
var is_on_ground_local = false

var can_move_left = true
var can_move_right = true

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var walking_sprite: Sprite2D = $walking_sprite
@onready var idle_sprite: Sprite2D = $idle_sprite
@onready var dying_sprite: Sprite2D = $dying_sprite

@onready var ping_label: Label = $Camera2D/Ping_Label
@onready var ammo_label: Label = $Camera2D/Ammo_Label


var pistol: Pistol = null
var m4a1_rifle: m4a1Rifle = null
var weapons: Array[PlayerGun] = []
var weapon_index = 0

const PISTOL_SCENE = preload("res://Scenes/Pistol.tscn")
const M4A1_RIFLE_SCENE = preload("res://Scenes/m4a1.tscn")
@onready var gun_anchor: Marker2D = $Gun_Anchor

var weapons_names_list = ["pistol", "m4a1_rifle"]

var is_dead: bool = false

func _ready() -> void:
	pistol = Pistol.new(PISTOL_SCENE, gun_anchor)
	m4a1_rifle = m4a1Rifle.new(M4A1_RIFLE_SCENE, gun_anchor)
	weapons.append(pistol)
	weapons.append(m4a1_rifle)
	weapons[weapon_index].instantiate_gun()
	Network.INPUT_DATA["gun"] = weapons_names_list[weapon_index]

func _physics_process(delta: float) -> void:
	handle_inputs(delta)
	ping_label.text = str("PING: ", Network.current_ping, "ms")
	
	ammo_label.text = str("AMMO: ", weapons[weapon_index].current_ammo, "/", weapons[weapon_index].max_ammo )

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
		
	if Input.is_action_just_pressed("switch_previous"):
		weapons[weapon_index].remove_gun_from_scene()
		weapon_index = (weapon_index - 1) % len(weapons)
		weapons[weapon_index].instantiate_gun()
		Network.INPUT_DATA["gun"] = weapons_names_list[weapon_index]
		
	if Input.is_action_just_pressed("reload"):
		Network.INPUT_DATA["command"] = "RELOAD"
		weapons[weapon_index].play_reload_animation()
	
	var direction = Input.get_axis("left", "right")
	if direction and not self.is_dead:
		walking_sprite.visible = true
		idle_sprite.visible = false
		animation_player.play("walking_animation")
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
	
	if direction == 1.0 and can_move_right:
		global_position.x += direction * SERVER_SPEED * METER_TO_PIXEL * delta
	if direction == -1.0 and can_move_left:
		global_position.x += direction * SERVER_SPEED * METER_TO_PIXEL * delta

	Network.INPUT_DATA["input_id"] += 1
	send_data()
		
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
	
	weapons[weapon_index].update_from_server(player_snapshot)
	
	#if player_snapshot["current_ammo"] == weapons[weapon_index].max_ammo:
		#ammo_label.text = str("AMMO: ", weapons[weapon_index].max_ammo, "/", weapons[weapon_index].max_ammo )

	
	while len(inputs_list) > 0 and inputs_list[0]["input_id"] <= last_processed_id:
		inputs_list.remove_at(0)
		
	var distance_error = global_position.distance_to(target_position)
	var error_x = abs(global_position.x - target_position.x)
	var error_y = abs(global_position.y - target_position.y)
	
	if error_x > 10.0 or error_y > 10.0:
		global_position = target_position
		for input_item in inputs_list:
			apply_movement_correction(input_item)
	else:
		global_position = lerp(global_position, target_position, 40*SERVER_DELTA)
	
	check_for_dying_animation(player_snapshot)
	
func apply_movement_correction(input_data: Dictionary):
	if self.is_dead:
		return
		
	var dir = 0
	if input_data["move_left"]: dir -= 1
	if input_data["move_right"]: dir += 1
	
	global_position.x += dir * SERVER_SPEED * METER_TO_PIXEL * SERVER_DELTA
	global_position.y += 15*METER_TO_PIXEL*SERVER_DELTA
	
	
	if cos(input_data["mouse_angle"]) > 0.0:
		walking_sprite.flip_h = false
		idle_sprite.flip_h = false
	else:
		walking_sprite.flip_h = true
		idle_sprite.flip_h = true
	
func check_for_dying_animation(player_snapshot: Dictionary):
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
	else:
		if self.is_dead: 
			self.is_dead = false
			can_move_left = true
			can_move_right = true
			
			self.dying_sprite.visible = false

			self.animation_player.stop()
	
func _on_right_indicator_area_entered(area: Area2D) -> void:
	if area.is_in_group("solids"):
		can_move_right = false

func _on_right_indicator_area_exited(area: Area2D) -> void:
	if area.is_in_group("solids"):
		can_move_right = true

func _on_left_indicator_area_entered(area: Area2D) -> void:
	if area.is_in_group("solids"):
		can_move_left = false

func _on_left_indicator_area_exited(area: Area2D) -> void:
	if area.is_in_group("solids"):
		can_move_left = true
