@abstract class_name PlayerGun 
extends Node2D

var bullet_spawn_position: Marker2D

var gun_scene: PackedScene
var gun_node: Node2D
var max_ammo: int
var current_ammo: int
var fire_rate: float
var gun_anchor: Marker2D
var shoot_cooldown: float
var reload_time: float
var reload_time_till_end: float
var reloaded: bool

#SOUND
var shoot_sound: AudioStreamPlayer2D
var reload_sound: AudioStreamPlayer2D

var is_reloading_locally: bool = false

var gun_hand_sprite: Sprite2D
var reload_gun_hand_sprite: Sprite2D
var gun_animation_player: AnimationPlayer
var reload_animation_name: String

var is_player_dead: bool

func _physics_process(delta: float) -> void:
	manage_arm_rotation()
	check_for_shoot()
	handle_shoot_cooldown(delta)
	#handle_reload_time_cooldown(delta)

func manage_arm_rotation():
	self.look_at(get_global_mouse_position())
	self.rotation_degrees = wrap(self.rotation_degrees, 0, 360)
	if self.rotation_degrees > 90 and self.rotation_degrees < 270:
		self.scale.y = -1
	else:
		self.scale.y = 1

func _init() -> void:
	pass

@abstract
func check_for_shoot();

func instantiate_gun():
	gun_anchor.add_child(self)
	gun_node = gun_scene.instantiate()
	self.bullet_spawn_position = gun_node.get_node("Bullet_Spawn_Position")
	self.shoot_sound = gun_node.get_node("Shoot_Sound")
	self.reload_sound = gun_node.get_node("Reload_Sound")
	self.add_child(gun_node)
	
	gun_hand_sprite = gun_node.find_child("gun_hand")
	reload_gun_hand_sprite = gun_node.find_child("reload_hand")
	gun_animation_player = gun_node.find_child("AnimationPlayer")
	
	is_reloading_locally = false
	is_player_dead = false
	
	
func remove_gun_from_scene():
	if is_instance_valid(gun_node):
		gun_node.queue_free() # Briše samo vizuelni deo
	
	if get_parent():
		get_parent().remove_child(self)

func handle_shoot_cooldown(delta: float):
	self.shoot_cooldown -= delta
	if self.shoot_cooldown < 0:
		self.shoot_cooldown = -1.0



func reset_shoot_cooldown():
	self.shoot_cooldown = self.fire_rate

func play_reload_animation():
	if self.current_ammo != self.max_ammo:
		self.gun_hand_sprite.visible = false
		self.reload_gun_hand_sprite.visible = true
		self.gun_animation_player.play(self.reload_animation_name)
		self.reload_sound.play()
	
func update_from_server(player_snapshot: Dictionary):
	self.current_ammo = player_snapshot["current_ammo"]
	self.reloaded = !player_snapshot["is_reloading"]
	
	self.is_player_dead = player_snapshot["respawn_timer"] > 0.0
	
	#Ako je igrac mrtav
	if is_player_dead:
		self.gun_hand_sprite.visible = false
		self.reload_gun_hand_sprite.visible = false
		return
	
	#Ako server kaze da treba repetiranje
	if player_snapshot["is_reloading"] and not is_reloading_locally:
		is_reloading_locally = true
		play_reload_animation()
	
	#Ako server kaze da je repetiranje zavrseno
	if not player_snapshot["is_reloading"] and is_reloading_locally:
		is_reloading_locally = false
		self.gun_hand_sprite.visible = true
		self.reload_gun_hand_sprite.visible = false
		self.gun_animation_player.stop()
	
	#Ako je igrac ziv i ne repetira
	if not is_reloading_locally:
		self.gun_hand_sprite.visible = true
		self.reload_gun_hand_sprite.visible = false
