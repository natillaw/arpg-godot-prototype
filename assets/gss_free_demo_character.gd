extends CharacterBody2D

@export var speed: float = 100.0
@export var y_multiplier: float = 0.5

func _ready() -> void:
	_ensure_action("iso_up",    [KEY_W, KEY_UP])
	_ensure_action("iso_down",  [KEY_S, KEY_DOWN])
	_ensure_action("iso_left",  [KEY_A, KEY_LEFT])
	_ensure_action("iso_right", [KEY_D, KEY_RIGHT])

func _ensure_action(action_name: String, keycodes: Array) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	for keycode in keycodes:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		InputMap.action_add_event(action_name, ev)

func _physics_process(_delta: float) -> void:
	var raw := Vector2(
		Input.get_axis("iso_left", "iso_right"),
		Input.get_axis("iso_up", "iso_down")
	)
	print("raw:", raw, " pos:", global_position)
	var input := raw.normalized()
	input.y *= y_multiplier
	velocity = input * speed
	move_and_slide()
