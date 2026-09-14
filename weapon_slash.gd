extends Node2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var speed: float = 500.0
@export var damage: int = 22
@export var max_lifetime: float = 1.2

var direction: Vector2 = Vector2.RIGHT
var lifetime := 0.0
var hit_something := false

func _ready():
	top_level = true
	z_index = 3

	if direction.x < 0:
		sprite.flip_v = true
		rotation = direction.angle() - PI
	else:
		sprite.flip_v = false
		rotation = direction.angle()

	if not $HitArea.body_entered.is_connected(_on_body_entered):
		$HitArea.body_entered.connect(_on_body_entered)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("default"):
		sprite.play("default")

func _process(_delta):
	if hit_something:
		return
	lifetime += _delta
	if lifetime >= max_lifetime:
		queue_free()
		return
	position += direction * speed * _delta

func _on_body_entered(body: Node2D):
	if hit_something:
		return
	if body.is_in_group("player") and body.has_node("Health"):
		hit_something = true
		body.get_node("Health").take_damage(damage)
		queue_free()
