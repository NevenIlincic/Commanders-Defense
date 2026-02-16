class_name Pistol extends Gun

func _init(gun_scene: PackedScene, gun_anchor: Marker2D) -> void:
	self.gun_scene = gun_scene
	self.gun_anchor = gun_anchor
	self.max_ammo = 12
	self.current_ammo = max_ammo
	self.shoot_scaling_rate = 0.2
