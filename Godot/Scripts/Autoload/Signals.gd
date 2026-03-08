extends Node

signal HANDLE_LEVEL_UDP(package: PackedByteArray)
signal HANDLE_LOBBY_UDP(package: PackedByteArray)

signal CHANGE_TO_SCENE_SIGNAL(path: String)

signal UPDATE_LOBBIES_MENU_UI(lobbies_info_data: Array[Dictionary])
signal UPDATE_LOBBY_UI(buffer: StreamPeerBuffer)
