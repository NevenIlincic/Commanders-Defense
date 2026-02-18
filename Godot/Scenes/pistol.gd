class_name Pistol extends PlayerGun

func _init(gun_scene: PackedScene, gun_anchor: Marker2D) -> void:
	self.gun_scene = gun_scene
	self.gun_anchor = gun_anchor
	self.max_ammo = 12
	self.current_ammo = max_ammo
	self.fire_rate = 0.1

func check_for_shoot():
	if Input.is_action_just_pressed("shoot") and shoot_cooldown <= 0.0:
		self.reset_shoot_cooldown()
		var bullet_spawn_coordinates = bullet_spawn_position.global_position
		Network.INPUT_DATA["bullet_spawn_position"] = [bullet_spawn_coordinates.x / 32, bullet_spawn_coordinates.y / 32]
		var mouse_angle = get_global_mouse_position().angle()
		var bullet_angle = Network.INPUT_DATA["mouse_angle"]
		var bullet: PlayerPistolBullet = PlayerPistolBullet.new(self.bullet_spawn_position.global_position, bullet_angle)
		bullet.instantiate_bullet()
	
