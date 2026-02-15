extends Node2D
class_name OtherPlayer

var target_position: Vector2 = Vector2.ZERO

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	pass # Replace with function body.

func _physics_process(delta: float) -> void:
	var distance = global_position.distance_to(target_position)
	
	if distance > 0.5:
		animation_player.play("walking_animation")
	else:
		animation_player.stop()
	if distance < 50:
		global_position = global_position.lerp(target_position, 40.0 * delta)
	else:
		global_position = target_position
	
	#if global_position.distance_to(target_position) > 0.1:
		#global_position = target_position
	#else:
		#global_position = global_position.lerp(target_position, 20.0 * delta)

func handle_server_response(player_snapshot: Dictionary):
	target_position = Vector2(player_snapshot["position"][0] * 32, player_snapshot["position"][1] * 32)
	sprite_2d.flip_h = !player_snapshot["facing_right"]
