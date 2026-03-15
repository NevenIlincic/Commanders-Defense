extends Node

signal HANDLE_LEVEL_UDP(package: PackedByteArray)
signal HANDLE_LOBBY_UDP(package: PackedByteArray)

signal CHANGE_TO_SCENE_SIGNAL(path: String)

signal UPDATE_LOBBIES_MENU_UI(lobbies_info_data: Array[Dictionary])
signal UPDATE_LOBBY_UI(buffer: StreamPeerBuffer)

#CREATE LOBBY
signal SET_MAXIMUM_PLAYERS_TOWER_GAME_MODE(is_max_two_players: bool)
signal SET_LOBBIES_MENU_VISIBLE()

#SCOREBOARD
signal UPDATE_SCOREBOARD(scoreboard_info: Dictionary)
signal UPDATE_SCOREBOARD_CONNECTED(player_id: int, player_nickname: String)
signal UPDATE_SCOREBOARD_DISCONNECTED(player_id: int)
