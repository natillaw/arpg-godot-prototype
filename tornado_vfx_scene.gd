extends Node2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	top_level = true
	z_index = 1
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("default"):
		sprite.play("default")
