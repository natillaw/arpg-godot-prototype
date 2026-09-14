extends Node2D
@export var speed: float = 450.0
@export var damage: int = 20
@export var max_lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var lifetime := 0.0
var hit := false

func _ready():
	top_level = true
	z_index = 3
	rotation = direction.angle()
	$HitArea.body_entered.connect(_on_body_entered)

func _process(_delta):
	if hit:
		return
	lifetime += _delta
	if lifetime >= max_lifetime:
		queue_free()
		return
	position += direction * speed * _delta
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, 10, Color(1.0, 0.5, 0.1, 0.95))
	draw_circle(Vector2.ZERO, 5, Color(1.0, 0.9, 0.4, 1.0))

func _on_body_entered(body):
	if hit:
		return
	if body.is_in_group("enemy") and body.has_node("Health"):
		hit = true
		body.get_node("Health").take_damage(damage)
		queue_free()
