extends Area2D

var direction := Vector2.RIGHT
var damage := 10
var speed := 400.0
var lifetime := 2.0


func _ready():
	area_entered.connect(_on_area_entered)
	rotation = direction.angle()
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()


# Llamar esto justo después de instanciar el proyectil (ver spawn_skill_projectile en player.gd)
func launch(dir: Vector2, dmg: int = 10, spd: float = 400.0) -> void:
	direction = dir.normalized()
	damage = dmg
	speed = spd
	rotation = direction.angle()


func _physics_process(delta):
	position += direction * speed * delta


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		var target = area.owner if area.owner else area.get_parent()
		if target.has_node("Health"):
			target.get_node("Health").take_damage(damage)
		queue_free()
	elif area.is_in_group("wall"):
		queue_free()
