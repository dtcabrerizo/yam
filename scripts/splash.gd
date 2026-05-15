extends Control


@onready var texture_rect: TextureRect = %TextureRect
@onready var progress_bar: ProgressBar = %ProgressBar

@onready var main_scene: PackedScene = preload("res://scenes/Main.tscn")

func _ready() -> void:
	texture_rect.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)	
	# Move para o destino
	tween.tween_property(texture_rect, "modulate:a", 1.0, 3.0)
	tween.tween_property(progress_bar, "value", 100.0, 6.0)
	tween.set_parallel(false)
	tween.tween_interval(2.0)
	tween.finished.connect(func(): 
		get_tree().change_scene_to_packed(main_scene)
	)
