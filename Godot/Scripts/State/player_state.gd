@abstract class_name PlayerState
extends Node

@abstract
func enter(player: MyPlayer);

@abstract
func update(delta: float, player: MyPlayer, command: PlayerMoveCommand);

func apply_common_physics(delta: float, player: MyPlayer, command: PlayerMoveCommand):
	var direction = 0
	if not player.is_dead:
		if command.move_left:  direction -= 1
		if command.move_right: direction += 1

		if direction > 0 and not player.can_move_right:  direction = 0
		elif direction < 0 and not player.can_move_left: direction = 0
	else:
		direction = 0
	var motion_x = direction * player.SERVER_SPEED * player.METER_TO_PIXEL
	player.move_and_collide(Vector2(motion_x * delta, 0))
	
	var predicted_v_velocity = player.vertical_velocity + player.GRAVITY * delta
	if predicted_v_velocity > 12.0:
		predicted_v_velocity = 12.0

	var motion_y = predicted_v_velocity * delta * player.METER_TO_PIXEL
	var collision = player.move_and_collide(Vector2(0, motion_y))
	
	player.is_on_ground = false

	if collision:
		var normal = collision.get_normal()
		if normal.y < -0.5:
			player.is_on_ground = true
			player.vertical_velocity = 0.0
		elif normal.y > 0.5:
			player.vertical_velocity = 0.0
	else:
		player.vertical_velocity = predicted_v_velocity

	return direction

func handle_inputs(player: MyPlayer):
	if Network.INPUT_DATA["gun"] == "m4a1_rifle":
		Network.INPUT_DATA["shoot"] = Input.is_action_pressed("shoot")
	else:
		Network.INPUT_DATA["shoot"] = Input.is_action_just_pressed("shoot")
	#if Network.INPUT_DATA["gun"] == "pistol":
		#Network.INPUT_DATA["shoot"] = Input.is_action_just_pressed("shoot")
	#else:
		#Network.INPUT_DATA["shoot"] = Input.is_action_pressed("shoot")
	Network.INPUT_DATA["mouse_angle"] = player.get_local_mouse_position().angle()
	
	if Input.is_action_just_pressed("switch_next"):
		if player.current_throwable_hand == null:
			player.weapons[player.weapon_index].remove_gun_from_scene()
		else:
			player.throwables[player.current_throwable_index].remove_throwable_from_scene()
		player.current_throwable = null
		player.current_throwable_hand = null
		player.current_throwable_index = -1
		player.throwable_trajectory_line.visible = false
		
		player.weapon_index = (player.weapon_index + 1) % len(player.weapons)
		player.weapons[player.weapon_index].instantiate_gun()
		Network.INPUT_DATA["gun"] = player.weapons_names_list[player.weapon_index]
		player.gun_sprite.texture = player.current_gun_sprites[player.weapon_index]
		CustomCursor.set_sight_cursor_visible()
		
	if Input.is_action_just_pressed("switch_previous"):
		if player.current_throwable_hand == null:
			player.weapons[player.weapon_index].remove_gun_from_scene()
		else:
			player.throwables[player.current_throwable_index].remove_throwable_from_scene()
		player.current_throwable = null
		player.current_throwable_hand = null
		player.current_throwable_index = -1
		player.throwable_trajectory_line.visible = false
		
		player.weapon_index -= 1
		if player.weapon_index < 0:
			player.weapon_index = len(player.weapons) - 1
		player.weapons[player.weapon_index].instantiate_gun()
		
		Network.INPUT_DATA["gun"] =player.weapons_names_list[player.weapon_index]
		player.gun_sprite.texture = player.current_gun_sprites[player.weapon_index]
		CustomCursor.set_sight_cursor_visible()
	
	if Input.is_action_just_pressed("HandGrenade"):
		if player.num_grenades > 0 and player.current_throwable_hand == null and player.current_throwable_index != 0:
			player.current_throwable_index = 0
			player.weapons[player.weapon_index].remove_gun_from_scene()
			player.current_throwable_hand = player.throwables[player.current_throwable_index]
			player.throwables[player.current_throwable_index].instantiate_throwable()
			Network.INPUT_DATA["gun"] = "grenade"
			player.gun_sprite.texture = player.current_gun_sprites[2]
			player.throwable_trajectory_line.visible = true
		
	#
	if Input.is_action_just_pressed("shoot") and player.current_throwable_hand != null:
		player.num_grenades -= 1
		player.current_throwable = player.HAND_GRENADE_SCENE.instantiate()
		player.throwables[player.current_throwable_index].remove_throwable_from_scene()
		LevelManager.CURRENT_LEVEL_NODE.add_child(player.current_throwable)
		player.current_throwable.throw(player.global_position, Vector2.from_angle(Network.INPUT_DATA["mouse_angle"]))
		player.current_throwable = null
		player.current_throwable_hand = null
		player.throwable_trajectory_line.visible = false
		player.has_thrown_throwable = true
		
		CustomCursor.set_sight_cursor_visible()
		player.throwables_container.get_child(player.current_throwable_index).queue_free()
	
	if Input.is_action_just_pressed("reload"):
		if player.current_throwable == null:
			Network.INPUT_DATA["command"] = "RELOAD"
			player.weapons[player.weapon_index].play_reload_animation()
		
	var direction = Input.get_axis("left", "right")
	if direction and not player.is_dead:
		player.walking_sprite.visible = true
		player.idle_sprite.visible = false
		player.animation_player.play("walking_animation")
		if player.can_play_walk_sound and player.is_on_ground:
			player.can_play_walk_sound = false
			player.walk_sound.play()
			player.walk_sound_timer.start(0.35)
		
	else:
		if not player.is_dead:
			player.walking_sprite.visible = false
			player.idle_sprite.visible = true
			player.animation_player.play("idle_animation")
	
	var mouse_angle = player.get_local_mouse_position().angle()
	if cos(mouse_angle) > 0.0:
		player.walking_sprite.flip_h = false
		player.idle_sprite.flip_h = false
	else:
		player.walking_sprite.flip_h = true
		player.idle_sprite.flip_h = true
		
	if Input.is_action_just_pressed("show_scoreboard"):
		player.scoreboard.visible = true
	if Input.is_action_just_released("show_scoreboard"):
		player.scoreboard.visible = false
