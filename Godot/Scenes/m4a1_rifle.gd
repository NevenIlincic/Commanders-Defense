class_name m4a1Rifle extends PlayerGun

func _init(gun_scene: PackedScene, gun_anchor: Marker2D,
gun_hand_texture: CompressedTexture2D, gun_hand_reload_texture: CompressedTexture2D) -> void:
	super._init(gun_hand_texture, gun_hand_reload_texture)
	
	self.gun_scene = gun_scene
	self.gun_anchor = gun_anchor
	self.max_ammo = 30
	self.current_ammo = max_ammo
	self.fire_rate = 0.1
	self.reload_time = 3
	self.reload_animation_name = "m4a1_rifle_reload_animation"

func check_for_shoot():
	if Input.is_action_pressed("shoot") and shoot_cooldown <= 0.0 and self.reloaded and not is_player_dead and not self.is_chat_visible:
		self.reset_shoot_cooldown()
		var bullet_spawn_coordinates = bullet_spawn_position.global_position
		Network.INPUT_DATA["bullet_spawn_position"] = [bullet_spawn_coordinates.x / 32, bullet_spawn_coordinates.y / 32]
		var mouse_angle = get_global_mouse_position().angle()
		var bullet_angle = Network.INPUT_DATA["mouse_angle"]
		var bullet: PlayerM4A1Bullet = PlayerM4A1Bullet.new(self.bullet_spawn_position.global_position, bullet_angle)
		bullet.instantiate_bullet()
		self.shoot_sound.play()
		CustomCursor.make_cursor_tween(0.9)
	
