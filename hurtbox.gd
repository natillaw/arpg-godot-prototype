# en Player.gd
func _ready():
	$Hurtbox.area_entered.connect(_on_hurtbox_area_entered)

func _on_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("enemy_hitbox"):
		$Health.take_damage(10)  # luego esto vendrá del enemigo, no hardcoded
