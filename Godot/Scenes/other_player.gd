extends Node2D
class_name OtherPlayer

var target_position: Vector2 = Vector2.ZERO

@onready var walking_sprite: Sprite2D = $walking_sprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var idle_sprite: Sprite2D = $idle_sprite

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
