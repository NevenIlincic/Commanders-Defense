extends OptionButton


func _on_item_selected(index: int) -> void:
	var is_max_two_players: bool = false
	
	if index == 0: #Tower/Hangar
		is_max_two_players = true
	Signals.SET_MAXIMUM_PLAYERS_TOWER_GAME_MODE.emit(is_max_two_players)

		
