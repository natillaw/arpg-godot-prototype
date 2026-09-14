
extends Area2D  # o Node2D, según cómo armaste tu "spike" de prueba

func _process(_delta):
	if Input.is_action_just_pressed("ui_accept"):
		$Health.take_damage(10)
		print("HP actual: ", $Health.current_hp)
