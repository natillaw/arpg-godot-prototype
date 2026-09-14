extends Node2D

signal telegraph_finished

@export var length: float = 350.0
@export var width: float = 90.0
@export var telegraph_time: float = 0.6
@export var direction: Vector2 = Vector2.RIGHT

var elapsed := 0.0

func _ready():
	top_level = true
	z_index = 1
	direction = direction.normalized()

func _process(_delta):
	elapsed += _delta
	queue_redraw()
	if elapsed >= telegraph_time:
		telegraph_finished.emit()
		queue_free()

func _draw():
	var progress = clamp(elapsed / telegraph_time, 0.0, 1.0)
	var pulse = 0.3 + 0.4 * sin(elapsed * 12.0) * progress
	var color = Color(1, 0.15, 0.1, 0.2 + progress * 0.45 + pulse * 0.1)

	var angle = direction.angle()
	var points = PackedVector2Array([
		Vector2(0, -width / 2.0),
		Vector2(length, -width / 2.0),
		Vector2(length, width / 2.0),
		Vector2(0, width / 2.0)
	])
	var rotated_points = PackedVector2Array()
	for p in points:
		rotated_points.append(p.rotated(angle))

	draw_colored_polygon(rotated_points, color)
