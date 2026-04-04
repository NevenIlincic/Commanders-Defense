extends Node
class_name PlayerMoveCommand

var player: MyPlayer
var move_left: bool
var move_right: bool
var jump: bool
var input_id: int

func _init(player: MyPlayer, input_id: int) -> void:
	self.player = player
	self.move_left = false
	self.move_right = false
	self.jump = false
	self.input_id = input_id

func execute(delta: float):
	if self.player.is_dead:
		return
		
	var direction = 0
	if self.move_left:
		direction -= 1
	if self.move_right:
		direction += 1
		
	if direction > 0 and not self.player.can_move_right:
		direction = 0
	elif direction < 0 and not self.player.can_move_left:
		direction = 0
	
	self.player.global_position.x += direction * self.player.SERVER_SPEED * self.player.METER_TO_PIXEL * delta
	self.update_all_shapes()

	var predicted_v_velocity = self.player.vertical_velocity + (self.player.GRAVITY * delta)
	if predicted_v_velocity > 12.0:
		predicted_v_velocity = 12.0
		
	self.player.ray_shape_down.force_shapecast_update()

	self.player.is_on_ground = false
	if self.player.ray_shape_down.is_colliding() and predicted_v_velocity >= 0.0:
		var normal = self.player.ray_shape_down.get_collision_normal(0)
		if normal.y < -0.5:
			self.player.is_on_ground = true

	if self.player.is_on_ground:
		self.player.vertical_velocity = 0.0
		var collision_y = self.player.ray_shape_down.get_collision_point(0).y
		self.player.global_position.y = collision_y - 16
		
	else:
		self.player.vertical_velocity = predicted_v_velocity
		self.player.global_position.y += self.player.vertical_velocity * delta * self.player.METER_TO_PIXEL

	if self.jump and self.player.is_on_ground:
		self.player.vertical_velocity = -self.player.JUMP_VELOCITY
		self.player.is_on_ground = false
		
		self.player.global_position.y -= 1.0

	if self.player.ray_shape_top.is_colliding() and self.player.vertical_velocity < 0:
		var normal = self.player.ray_shape_top.get_collision_normal(0)
		if normal.y > 0.5:
			self.player.vertical_velocity = 0.0
			var ceiling_y = self.player.ray_shape_top.get_collision_point(0).y
			self.player.global_position.y = ceiling_y + 16.0


func update_all_shapes():
	self.player.ray_shape_top.force_shapecast_update()
	self.player.ray_shape_left.force_shapecast_update()
	self.player.ray_shape_right.force_shapecast_update()
	
	self.player.can_move_left = true
	if self.player.ray_shape_left.is_colliding():
		for i in range(self.player.ray_shape_left.get_collision_count()):
			var normal = self.player.ray_shape_left.get_collision_normal(i)
			if normal.x > 0.5: 
				self.player.can_move_left = false
				break
				
	self.player.can_move_right = true
	if self.player.ray_shape_right.is_colliding():
		for i in range(self.player.ray_shape_right.get_collision_count()):
			var normal = self.player.ray_shape_right.get_collision_normal(i)
			if normal.x < -0.5:
				self.player.can_move_right = false
				break
	#self.player.can_move_left = !self.player.ray_shape_left.is_colliding()
	#self.player.can_move_right = !self.player.ray_shape_right.is_colliding() 
