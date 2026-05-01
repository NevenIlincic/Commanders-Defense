extends Node

signal HANDLE_LEVEL_UDP(package: PackedByteArray)
signal HANDLE_LOBBY_UDP(package: PackedByteArray)

signal CHANGE_TO_SCENE_SIGNAL(path: String)

signal UPDATE_LOBBIES_MENU_UI(lobbies_menu_info_data: Dictionary)

#LOBBY
signal UPDATE_LOBBY_UI(buffer: StreamPeerBuffer)
signal UPDATE_PLAYER_ROW_INFO(player_id: int, skin_index: int, is_ready_bool)

#CREATE LOBBY
signal SET_MAXIMUM_PLAYERS_TOWER_GAME_MODE(is_max_two_players: bool)
signal SET_LOBBIES_MENU_VISIBLE()

#SCOREBOARD
signal UPDATE_SCOREBOARD(scoreboard_info: Dictionary)
signal UPDATE_SCOREBOARD_CONNECTED(player_id: int, player_nickname: String)
signal UPDATE_SCOREBOARD_DISCONNECTED(player_id: int)
signal UPDATE_SCOREBOARD_WHEN_JOIN(player_id)

#MAIN MENU SIGNALS
signal REGISTRATION_COMPLETE(status_code: int)

signal HIDE_LOADING_MESSAGE()
signal SHOW_LOADING_MESSAGE(message: String)

signal CAMERA_SHAKE()
