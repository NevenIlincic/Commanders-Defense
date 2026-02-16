extends Node2D
class_name OtherPlayer

var target_position: Vector2 = Vector2.ZERO

@onready var walking_sprite: Sprite2D = $walking_sprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var idle_sprite: Sprite2D = $idle_sprite
@onready var gun_anchor: Marker2D = $Gun_Anchor

const PISTOL_SCENE = preload("res://Scenes/Pistol.tscn")
const M4A1_RIFLE_SCENE = preload("res://Scenes/m4a1.tscn")

var weapons: Array[OtherPlayerGunVisualizer]
var current_gun_name: String

var weapon_map: Dictionary = {
	"pistol": 0,
	"m4a1_rifle": 1
}

func _ready() -> void:
	current_gun_name = "pistol"
	var pistol = OtherPlayerGunVisualizer.new(PISTOL_SCENE, gun_anchor)
	var m4a1_rifle = OtherPlayerGunVisualizer.new(M4A1_RIFLE_SCENE, gun_anchor)
	weapons.append(pistol)
	weapons.append(m4a1_rifle)
	weapons[weapon_map[current_gun_name]].instantiate_gun()

func _physics_process(delta: float) -> void:
	var distance = global_position.distance_to(target_position)
	
	if distance > 0.5:
		walking_sprite.visible = true
		idle_sprite.visible = false
		animation_player.play("walking_animation")
	else:
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
	
	weapons[weapon_map[current_gun_name]].set_snapshot(player_snapshot)
	change_gun(player_snapshot)
	
func change_gun(player_snapshot: Dictionary):
	if current_gun_name != player_snapshot["gun"]:
		weapons[weapon_map[current_gun_name]].remove_gun_from_scene()
		current_gun_name = player_snapshot["gun"]
		weapons[weapon_map[current_gun_name]].instantiate_gun()
