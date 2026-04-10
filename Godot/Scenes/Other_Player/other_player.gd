extends Node2D
class_name OtherPlayer

var target_position: Vector2 = Vector2.ZERO

#SPRITES
@onready var walking_sprite: Sprite2D = $walking_sprite
@onready var kill_image: Sprite2D = $kill_image
@onready var idle_sprite: Sprite2D = $idle_sprite
@onready var dying_sprite: Sprite2D = $dying_sprite

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var gun_anchor: Marker2D = $Gun_Anchor
@onready var collision_shape_2d: CollisionShape2D = $Hitbox/CollisionShape2D

#SOUND
@onready var pitol_shoot_sound: AudioStreamPlayer2D = $Pitol_Shoot_Sound
@onready var m4a1_rifle_shoot_sound: AudioStreamPlayer2D = $m4a1_Rifle_Shoot_Sound
@onready var jump_sound: AudioStreamPlayer2D = $Jump_Sound
@onready var walk_sound: AudioStreamPlayer2D = $Walk_Sound
@onready var walk_sound_timer: Timer = $Walk_Sound_Timer
@onready var hit_sound: AudioStreamPlayer2D = $Hit_Sound

var can_play_walking_sound: bool = true

var is_dead: bool = false
var has_jumped: bool = false

#const PISTOL_SCENE = preload("res://Scenes/Pistol.tscn")
const PISTOL_SCENE = preload("res://Scenes/Other_Player/Other_Player_Pistol.tscn")
const M4A1_RIFLE_SCENE = preload("res://Scenes/Other_Player/Other_Player_m4a1_Rifle.tscn")
const THROWABLE_SCENE = preload("res://Scenes/Other_Player/Other_Player_Throwable.tscn")
var weapons: Array[OtherPlayerGunVisualizer]
var throwables: Array[OtherPlayerThrowableVisualizer]

var current_gun_name: String

var weapon_map: Dictionary = {
	"pistol": 0,
	"m4a1_rifle": 1,
	"grenade": 100
}
var throwable_map: Dictionary = {
	"grenade": 0
}

var NICKNAME: String = ""
var HP = 100
var SKIN_INDEX = -1

func _ready() -> void:
	current_gun_name = "pistol"
	var pistol = OtherPlayerPistolVisualizer.new(PISTOL_SCENE, gun_anchor, LevelManager.players_pistol_hand_sprite_skin[SKIN_INDEX], LevelManager.players_pistol_hand_reload_sprites_skin[SKIN_INDEX])
	var m4a1_rifle = OtherPlayerM4A1RifleVisualizer.new(M4A1_RIFLE_SCENE, gun_anchor, LevelManager.players_m4a1_hand_sprite_skin[SKIN_INDEX] , LevelManager.players_m4a1_hand_reload_sprites_skin[SKIN_INDEX])
	var grenade = OtherPlayerThrowableVisualizer.new(THROWABLE_SCENE, gun_anchor, LevelManager.players_grenade_hand_sprite_skin[SKIN_INDEX], preload("res://Sprites/throwables/hand_grenade.png"))
	weapons.append(pistol)
	weapons.append(m4a1_rifle)
	throwables.append(grenade)
	weapons[weapon_map[current_gun_name]].instantiate_gun()
	
	set_player_skin()

func set_player_skin():
	walking_sprite.texture = LevelManager.players_walking_sprites_skin[SKIN_INDEX]
	idle_sprite.texture = LevelManager.players_idle_sprites_skin[SKIN_INDEX]
	dying_sprite.texture = LevelManager.players_dying_spirtes_skin[SKIN_INDEX]
	kill_image.texture = LevelManager.players_kill_image_skin[SKIN_INDEX]

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
		global_position = global_position.lerp(target_position, 0.3) #40.0 * delta
	else:
		global_position = target_position
	
func handle_server_response(player_snapshot: Dictionary):
	target_position = Vector2(player_snapshot["position"][0] * 32, player_snapshot["position"][1] * 32)
	walking_sprite.flip_h = !player_snapshot["facing_right"]
	idle_sprite.flip_h = !player_snapshot["facing_right"]
	dying_sprite.flip_h = !player_snapshot["facing_right"]
	NICKNAME = player_snapshot["nickname"]
	
	#if SKIN_INDEX == -1:
		#SKIN_INDEX = player_snapshot["player_skin"]
		
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
	
	change_gun(player_snapshot)
	if weapon_map[current_gun_name] <= 1:
		weapons[weapon_map[current_gun_name]].set_snapshot(player_snapshot)
	else:
		throwables[throwable_map[current_gun_name]].set_snapshot(player_snapshot)
	check_is_player_dead(player_snapshot)
	
func change_gun(player_snapshot: Dictionary):
	if current_gun_name != player_snapshot["gun"]:
		if weapon_map[current_gun_name] <= 1:
			weapons[weapon_map[current_gun_name]].remove_gun_from_scene()
		else:
			throwables[throwable_map[current_gun_name]].remove_throwable_from_scene()
		current_gun_name = player_snapshot["gun"]
		if weapon_map[current_gun_name] <= 1:
			weapons[weapon_map[current_gun_name]].instantiate_gun()
		else:
			throwables[throwable_map[current_gun_name]].instantiate_throwable()

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
		
		if HP != player_snapshot["hp"]:
			HP = player_snapshot["hp"]
			hit_sound.play()

func _on_walk_sound_timer_timeout() -> void:
	self.can_play_walking_sound = true

func play_gun_blast_animation():
	weapons[weapon_map[current_gun_name]].play_gun_blast_animation()
