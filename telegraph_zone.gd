extends Node2D

signal telegraph_finished

@export var radius: float = 60.0
@export var telegraph_time: float = 0.8
@export var active_time: float = 0.3
@export var damage: int = 20
@export var is_major: bool = false

@onready var small_sprite: AnimatedSprite2D = $SmallSprite
@onready var big_sprite: AnimatedSprite2D = $BigSprite

var elapsed := 0.0
var phase := "warning"
const SQUASH := 0.5

func _ready():
	$DamageArea/CollisionShape2D.shape.radius = radius
	$DamageArea/CollisionShape2D.disabled = true
	top_level = true
	z_index = 1

	# Fuerza el apagado de AMBOS sprites, sin importar Autoplay o config del editor
	small_sprite.stop()
	small_sprite.visible = false
	big_sprite.stop()
	big_sprite.visible = false

	start()

func start():
	phase = "warning"
	elapsed = 0.0

func _process(_delta):
	elapsed += _delta
	queue_redraw()

	if phase == "warning" and elapsed >= telegraph_time:
		phase = "active"
		elapsed = 0.0
		$DamageArea/CollisionShape2D.disabled = false
		show_impact_animation()
		telegraph_finished.emit()
		apply_damage_delayed()
	elif phase == "active" and elapsed >= active_time:
		phase = "done"
		queue_free()

func show_impact_animation():
	var active_sprite = big_sprite if is_major else small_sprite
	active_sprite.scale = Vector2.ONE * (radius / 60.0)
	active_sprite.visible = true

	if active_sprite.sprite_frames and active_sprite.sprite_frames.has_animation("default"):
		active_sprite.play("default")

func apply_damage_delayed():
	await get_tree().physics_frame
	await get_tree().physics_frame
	apply_damage()

func apply_damage():
	var bodies = $DamageArea.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player"):
			if body.has_method("take_damage_safe"):
				body.take_damage_safe(damage)
			elif body.has_node("Health"):
				body.get_node("Health").take_damage(damage)

func _draw():
	if phase != "warning":
		return

	var progress = clamp(elapsed / telegraph_time, 0.0, 1.0)
	var pulse = 0.3 + 0.4 * sin(elapsed * (14.0 if is_major else 10.0)) * progress
	var base_alpha = 0.35 if is_major else 0.25
	var color = Color(1, 0.15, 0.1, base_alpha + progress * 0.35 + pulse * 0.1)
	var line_width = 4.0 if is_major else 2.0

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SQUASH))
	draw_circle(Vector2.ZERO, radius, color)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1, 0.3, 0.2, 0.9), line_width)
	if is_major:
		draw_arc(Vector2.ZERO, radius * 0.7, 0, TAU, 32, Color(1, 0.5, 0.2, 0.5 + progress * 0.4), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
