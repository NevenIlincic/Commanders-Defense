class_name JumpingState extends PlayerState

func enter(player: MyPlayer):
	player.vertical_velocity = -player.JUMP_VELOCITY
	player.is_on_ground = false
	player.jump_sound.play()
	
	player.walking_sprite.visible = true
	player.idle_sprite.visible = false
	player.dying_sprite.visible = false
	player.animation_player.play("walking_animation")
	

func update(delta: float, player: MyPlayer, command: PlayerMoveCommand):
	var direction = apply_common_physics(delta, player, command)
	
	if player.is_on_ground:
		if direction != 0:
			player.change_state(RunningState.new())
		else:
			player.change_state(IdleState.new())
		return
	
func handle_inputs(player: MyPlayer):
	super.handle_inputs(player)
