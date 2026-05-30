class_name IdleState extends PlayerState

func enter(player: MyPlayer):
	player.vertical_velocity = 0
	player.is_on_ground = true
	player.walking_sprite.visible = false
	player.idle_sprite.visible = true
	player.dying_sprite.visible = false
	player.animation_player.play("idle_animation")

func update(delta: float, player: MyPlayer, command: PlayerMoveCommand):
	var direction = apply_common_physics(delta, player, command)
	if command.jump and player.is_on_ground:
		player.change_state(JumpingState.new())
		return

	if direction != 0:
		player.change_state(RunningState.new())
		return
		
		
func handle_inputs(player: MyPlayer):
	super.handle_inputs(player)
