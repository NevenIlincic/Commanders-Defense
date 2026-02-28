extends Node2D
class_name OtherPlayer

var target_position: Vector2 = Vector2.ZERO

@onready var walking_sprite: Sprite2D = $walking_sprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var idle_sprite: Sprite2D = $idle_sprite
@onready var gun_anchor: Marker2D = $Gun_Anchor
@onready var dying_sprite: Sprite2D = $dying_sprite
@onready var collision_shape_2d: CollisionShape2D = $Hitbox/CollisionShape2D

#SOUND
@onready var pitol_shoot_sound: AudioStreamPlayer2D = $Pitol_Shoot_Sound
@onready var m4a1_rifle_shoot_sound: AudioStreamPlayer2D = $m4a1_Rifle_Shoot_Sound
@onready var jump_sound: AudioStreamPlayer2D = $Jump_Sound
@onready var walk_sound: AudioStreamPlayer2D = $Walk_Sound
@onready var walk_sound_timer: Timer = $Walk_Sound_Timer
var can_play_walking_sound: bool = true

var is_dead: bool = false
var has_jumped: bool = false

#const PISTOL_SCENE = preload("res://Scenes/Pistol.tscn")
const PISTOL_SCENE = preload("res://Scenes/Other_Player/Other_Player_Pistol.tscn")
const M4A1_RIFLE_SCENE = preload("res://Scenes/Other_Player/Other_Player_m4a1_Rifle.tscn")

var weapons: Array[OtherPlayerGunVisualizer]
var current_gun_name: String

var weapon_map: Dictionary = {
	"pistol": 0,
	"m4a1_rifle": 1
}

var NICKNAME: String = ""

func _ready() -> void:
	current_gun_name = "pistol"
	var pistol = OtherPlayerPistolVisualizer.new(PISTOL_SCENE, gun_anchor, "res://Sprites/player/enemy_player/enemy_player_pistol_hand.png","res://Sprites/player/enemy_player/enemy_player_pistol_reload_sprites.png")
	var m4a1_rifle = OtherPlayerM4A1RifleVisualizer.new(M4A1_RIFLE_SCENE, gun_anchor, "res://Sprites/player/enemy_player/enemy_player_m4a1_hand.png" , "res://Sprites/player/enemy_player/enemy_player_m4a1_reload_sprites.png")
	weapons.append(pistol)
	weapons.append(m4a1_rifle)
	weapons[weapon_map[current_gun_name]].instantiate_gun()

func _physics_process(delta: float) -> void:
	var distance = global_position.distance_to(target_position)
	
	if distance > 0.5 and not self.is_dead:
		walking_sprite.visible = true
		idle_sprite.visible = false
		animation_player.play("walking_animation")
	else:
		if not self.is_dead:
			walking_sprite.visible = false
			idle_sprite.visible = true
			animation_player.play("idle_animation")
	if distance < 50:
		global_position = global_position.lerp(target_position, 40.0 * delta)
	else:
		global_position = target_position
	
func handle_server_response(player_snapshot: Dictionary):
	target_position = Vector2(player_snapshot["position"][0] * 32, player_snapshot["position"][1] * 32)
	walking_sprite.flip_h = !player_snapshot["facing_right"]
	idle_sprite.flip_h = !player_snapshot["facing_right"]
	dying_sprite.flip_h = !player_snapshot["facing_right"]
	NICKNAME = player_snapshot["nickname"]
	
	
	#Provera zvuka skoka
	if has_jumped:
		if player_snapshot["is_on_ground"]:
			has_jumped = false
	
	if not has_jumped:	
		if not player_snapshot["is_on_ground"]:
			has_jumped = true
			jump_sound.play()
	##
	
	##Provera zvuka hodanja
	if self.global_position != target_position and not self.is_dead:
		if self.can_play_walking_sound and player_snapshot["is_on_ground"] and self.global_position.distance_to(target_position) > 5:
			self.can_play_walking_sound = false
			walk_sound.play()
			walk_sound_timer.start(0.35)
	
	weapons[weapon_map[current_gun_name]].set_snapshot(player_snapshot)
	change_gun(player_snapshot)
	check_is_player_dead(player_snapshot)
	
func change_gun(player_snapshot: Dictionary):
	if current_gun_name != player_snapshot["gun"]:
		weapons[weapon_map[current_gun_name]].remove_gun_from_scene()
		current_gun_name = player_snapshot["gun"]
		weapons[weapon_map[current_gun_name]].instantiate_gun()

func get_bullet_spawn_position_marker():
	return weapons[weapon_map[current_gun_name]].get_bullet_spawn_position_marker()

func check_is_player_dead(player_snapshot: Dictionary):
	var is_respawning: bool = player_snapshot["respawn_timer"] > 0.0
	
	if is_respawning:
		if not self.is_dead:
			self.is_dead = true
			self.dying_sprite.visible = true
			self.walking_sprite.visible = false
			self.idle_sprite.visible = false
			self.animation_player.play("dying_animation")
			collision_shape_2d.disabled = true
	else:
		if self.is_dead: 
			self.is_dead = false
			self.dying_sprite.visible = false
			collision_shape_2d.disabled = false
			self.animation_player.stop()


func _on_walk_sound_timer_timeout() -> void:
	self.can_play_walking_sound = true
