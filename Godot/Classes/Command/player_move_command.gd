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
	self.player.player_state.update(delta, self.player, self)
	
