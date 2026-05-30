class_name DeadState extends PlayerState

func enter(player: MyPlayer):
	player.is_on_ground = true
	player.walking_sprite.visible = false
	player.idle_sprite.visible = false
	player.dying_sprite.visible = true
	player.health_amount.visible = false
	
	player.is_dead = true
	player.can_move_left = false
	player.can_move_right = false
	player.animation_player.play("dying_animation")

func update(delta: float, player: MyPlayer, command: PlayerMoveCommand):
	apply_common_physics(delta, player, command)
	
func handle_inputs(player: MyPlayer):
	pass
