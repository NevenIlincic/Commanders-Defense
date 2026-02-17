class_name PlayerPistolBullet extends PlayerBullet

func _init(spawn_position: Marker2D, angle: float) -> void:
	self.bullet_scene = preload("res://Scenes/Bullet/Pistol_Bullet.tscn")
	self.bullet_spawn_position = spawn_position
	self.bullet_angle = angle
	self.SERVER_SPEED = 25
