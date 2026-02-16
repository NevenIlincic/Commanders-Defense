extends Node2D
class_name OtherPlayer

var target_position: Vector2 = Vector2.ZERO

@onready var walking_sprite: Sprite2D = $walking_sprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var idle_sprite: Sprite2D = $idle_sprite
@onready var gun_hand: Sprite2D = $gun_hand

func _ready() -> void:
	pass # Replace with function body.

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
	manage_arm_rotation(player_snapshot)

func manage_arm_rotation(player_snapshot: Dictionary):
	gun_hand.rotation = player_snapshot["mouse_angle"]
	gun_hand.rotation_degrees = wrap(gun_hand.rotation_degrees, 0, 360)
	if gun_hand.rotation_degrees > 90 and gun_hand.rotation_degrees < 270:
		gun_hand.scale.y = -1
	else:
		gun_hand.scale.y = 1
