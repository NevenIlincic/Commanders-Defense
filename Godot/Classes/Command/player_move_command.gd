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
	#if self.player.is_dead:
		#return
	self.player.player_state.update(delta, self.player, self)
	
	#var direction = 0
	#if self.move_left:
		#direction -= 1
	#if self.move_right:
		#direction += 1
#
	#if direction > 0 and not self.player.can_move_right:
		#direction = 0
	#elif direction < 0 and not self.player.can_move_left:
		#direction = 0
#
	#var motion = Vector2(direction * self.player.SERVER_SPEED * self.player.METER_TO_PIXEL, 0)
	#
	#var collision = self.player.move_and_collide(motion * delta)
	#if collision:
		#motion.x = 0
	#
	##Vertikalno kretanje
	#var predicted_v_velocity = self.player.vertical_velocity + self.player.GRAVITY * delta
	#if predicted_v_velocity > 12.0:
		#predicted_v_velocity = 12.0
#
	#motion.y = predicted_v_velocity * delta * self.player.METER_TO_PIXEL
#
	#collision = self.player.move_and_collide(Vector2(0, motion.y))
	#self.player.is_on_ground = false
#
	#if collision:
		##Stoji na podu
		#var normal = collision.get_normal()
		#if normal.y < -0.5:
			#self.player.is_on_ground = true
			#self.player.vertical_velocity = 0.0
		#
		##Udario u plafon
		#elif normal.y > 0.5:
			#self.player.vertical_velocity = 0.0
	#else:
		#self.player.vertical_velocity = predicted_v_velocity
#
	##Skok
	#if self.jump and self.player.is_on_ground:
		#self.player.vertical_velocity = -self.player.JUMP_VELOCITY
		#self.player.is_on_ground = false
		#self.player.jump_sound.play()
