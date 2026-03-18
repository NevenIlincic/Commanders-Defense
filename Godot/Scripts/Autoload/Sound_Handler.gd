extends AudioStreamPlayer


const TI_SE_SAMO_USUDI = preload("res://Sounds/Music/Ti_Se_Samo_Usudi_Instrumental.mp3")

var current_song: AudioStream

var VOLUME: float = 30.0
func _ready():
	connect("finished", Callable(self, "_on_music_finished"))

func _on_music_finished():
	stream = TI_SE_SAMO_USUDI
	volume_db = 0.0
	play()

func _play_music(music: AudioStream, volume = 0.0):
	stream = music
	volume_db = volume
	bus = "Background Music"
	play()

func play_background_music(chosen_music, volume = 0.0):
	_play_music(chosen_music, volume)

func pause_music():
	stream_paused = true
	
func play_music():
	play() 
