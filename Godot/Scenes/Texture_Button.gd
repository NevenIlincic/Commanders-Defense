extends TextureButton # ili TextureButton, zavisi šta koristiš

# Podesi koliko želiš da se poveća (1.1 je 110% veličine)
@export var scale_amount : Vector2 = Vector2(1.1, 1.1)
@export var default_scale : Vector2 = Vector2(1.0, 1.0)
@export var transition_time : float = 0.1 # Brzina animacije u sekundama

func _ready():
	# Povezujemo signale koda sa ugrađenim hover funkcijama
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	# Kreiramo novi tween koji će glatko promeniti scale
	var tween = create_tween()
	# Postavljamo "ease" da prelaz bude prirodniji (progresivno ubrzanje/usporenje)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", scale_amount, transition_time)

func _on_mouse_exited():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", default_scale, transition_time)
