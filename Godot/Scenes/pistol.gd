class_name Pistol extends PlayerGun

func _init(gun_scene: PackedScene, gun_anchor: Marker2D) -> void:
	self.gun_scene = gun_scene
	self.gun_anchor = gun_anchor
	self.max_ammo = 12
	self.current_ammo = max_ammo
	self.shoot_scaling_rate = 0.2

func check_for_shoot():
	if Input.is_action_just_pressed("shoot"):
		var mouse_angle = get_global_mouse_position().angle()
		var bullet_angle = (get_global_mouse_position() - bullet_spawn_position.global_position).angle()
		var bullet: PlayerPistolBullet = PlayerPistolBullet.new(self.bullet_spawn_position, bullet_angle)
		bullet.instantiate_bullet()
	
