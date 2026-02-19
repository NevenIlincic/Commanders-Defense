class_name PlayerM4A1Bullet extends PlayerBullet

func _init(spawn_position: Vector2, angle: float) -> void:
	self.bullet_scene = preload("res://Scenes/Bullet/m4a1_Rifle_Bullet.tscn")
	self.bullet_spawn_position = spawn_position
	self.bullet_angle = angle
	self.SERVER_SPEED = 30
