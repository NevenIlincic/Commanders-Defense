class_name RunningState extends PlayerState

func enter(player: MyPlayer):
	player.walking_sprite.visible = true
	player.idle_sprite.visible = false
	player.dying_sprite.visible = false
	player.animation_player.play("walking_animation")

func update(delta: float, player: MyPlayer, command: PlayerMoveCommand):
	var direction = apply_common_physics(delta, player, command)
	
	if not player.is_on_ground:
		player.change_state(JumpingState.new())
		return

	if direction != 0 and player.can_play_walk_sound:
		player.can_play_walk_sound = false
		player.walk_sound.play()
		player.walk_sound_timer.start(0.35)

	if command.jump and player.is_on_ground:
		player.vertical_velocity = -player.JUMP_VELOCITY
		player.jump_sound.play()
		player.change_state(JumpingState.new())
		return

	if direction == 0:
		player.change_state(IdleState.new())
		return
	
func handle_inputs(player: MyPlayer):
	super.handle_inputs(player)
