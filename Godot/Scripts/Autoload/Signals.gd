extends Node

signal HANDLE_LEVEL_UDP(package: PackedByteArray)
signal HANDLE_LOBBY_UDP(package: PackedByteArray)

signal CHANGE_TO_SCENE_SIGNAL(path: String)
signal UPDATE_LOBBY_UI(lobby_info_data: Array[Dictionary])
