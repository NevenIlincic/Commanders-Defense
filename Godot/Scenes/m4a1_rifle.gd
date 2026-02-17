class_name m4a1Rifle extends PlayerGun

func _init(gun_scene: PackedScene, gun_anchor: Marker2D) -> void:
	self.gun_scene = gun_scene
	self.gun_anchor = gun_anchor
	self.max_ammo = 30
	self.current_ammo = max_ammo
	self.shoot_scaling_rate = 0.2

func check_for_shoot():
	pass
