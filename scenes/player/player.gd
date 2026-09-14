extends CharacterBody2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

enum PlayerState { IDLE, MOVE, CASTING, LOCKED }
var state: PlayerState = PlayerState.IDLE

var speed := 180
var target_position: Vector2
var has_move_target := false
var last_direction := Vector2.DOWN
var stop_distance := 5

var is_dead := false

# ---------------- ROLL (con cargas) ----------------
var roll_max_charges := 2
var roll_charges := 2
var roll_recharge_time := 3.0
var roll_recharge_timer := 0.0
var is_rolling := false
var is_invincible := false
var roll_speed := 500
var roll_duration := 0.35
var roll_timer := 0.0
var roll_direction := Vector2.ZERO

# ---------------- FIREBALL ----------------
const PlayerFireballScene = preload("res://player_fireball.tscn")
var fireball_damage := 20
var fireball_cooldown := 0.8
var can_cast_fireball := true
var is_casting := false

func _ready():
	$Health.set_max_hp(100)
	z_index = 2
	if not $Hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		$Hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	if not $Health.died.is_connected(_on_died):
		$Health.died.connect(_on_died)

func _unhandled_input(event):
	if is_dead or is_rolling or is_casting:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			target_position = get_global_mouse_position()
			has_move_target = true
			state = PlayerState.MOVE

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		try_cast_fireball()

func _physics_process(_delta):
	# Recarga pasiva de cargas de roll
	if roll_charges < roll_max_charges:
		roll_recharge_timer -= _delta
		if roll_recharge_timer <= 0:
			roll_charges += 1
			if roll_charges < roll_max_charges:
				roll_recharge_timer = roll_recharge_time

	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_rolling:
		roll_timer -= _delta
		velocity = roll_direction * roll_speed
		move_and_slide()
		if roll_timer <= 0:
			end_roll()
		return

	if is_casting:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if Input.is_action_just_pressed("roll") and roll_charges > 0:
		start_roll()
		return

	match state:
		PlayerState.IDLE:
			handle_idle()
		PlayerState.MOVE:
			handle_move()
		PlayerState.LOCKED:
			velocity = Vector2.ZERO
	move_and_slide()

func handle_idle():
	velocity = Vector2.ZERO
	play_idle()

func handle_move():
	var direction = target_position - global_position
	if direction.length() <= stop_distance:
		velocity = Vector2.ZERO
		has_move_target = false
		state = PlayerState.IDLE
		play_idle()
		return
	direction = direction.normalized()
	last_direction = direction
	velocity = direction * speed
	play_walk(direction)

# ---------------- DIRECCIÓN / ANIMACIONES ----------------
func get_direction_suffix(dir: Vector2) -> String:
	var angle = rad_to_deg(dir.angle())
	if angle >= -22.5 and angle < 22.5: return "right"
	elif angle >= 22.5 and angle < 67.5: return "down_right"
	elif angle >= 67.5 and angle < 112.5: return "down"
	elif angle >= 112.5 and angle < 157.5: return "down_left"
	elif angle >= -157.5 and angle < -112.5: return "up_left"
	elif angle >= -112.5 and angle < -67.5: return "up"
	elif angle >= -67.5 and angle < -22.5: return "up_right"
	else: return "left"

func play_walk(dir: Vector2):
	var anim = "walk_" + get_direction_suffix(dir)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

func play_idle():
	var anim = "idle_" + get_direction_suffix(last_direction)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

# ---------------- FIREBALL ----------------
func try_cast_fireball():
	if not can_cast_fireball or is_casting:
		return
	do_cast_fireball()

func do_cast_fireball():
	can_cast_fireball = false
	is_casting = true
	state = PlayerState.CASTING
	velocity = Vector2.ZERO

	var dir = (get_global_mouse_position() - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = last_direction
	last_direction = dir

	var anim = "cast_" + get_direction_suffix(dir)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

	await get_tree().create_timer(0.25).timeout
	if is_dead:
		return

	var fb = PlayerFireballScene.instantiate()
	get_tree().current_scene.add_child(fb)
	fb.global_position = global_position + dir * 25
	fb.direction = dir
	fb.damage = fireball_damage

	await get_tree().create_timer(0.15).timeout
	if is_dead:
		return

	is_casting = false
	if has_move_target:
		state = PlayerState.MOVE
	else:
		state = PlayerState.IDLE
		play_idle()

	await get_tree().create_timer(fireball_cooldown).timeout
	if is_dead:
		return
	can_cast_fireball = true

# ---------------- ROLL ----------------
func start_roll():
	roll_charges -= 1
	if roll_charges == roll_max_charges - 1:
		roll_recharge_timer = roll_recharge_time
	is_rolling = true
	is_invincible = true
	state = PlayerState.LOCKED
	roll_timer = roll_duration
	roll_direction = last_direction

	var anim_name = "roll_" + get_direction_suffix(roll_direction)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

func end_roll():
	is_rolling = false
	is_invincible = false
	velocity = Vector2.ZERO

	if has_move_target and global_position.distance_to(target_position) > stop_distance:
		state = PlayerState.MOVE
	else:
		has_move_target = false
		state = PlayerState.IDLE
		play_idle()

# ---------------- DAÑO (centralizado, respeta invencibilidad) ----------------
func take_damage_safe(amount: int):
	if is_invincible or is_dead:
		return
	$Health.take_damage(amount)

func _on_hurtbox_area_entered(area: Area2D):
	if is_invincible:
		return
	if area.is_in_group("enemy_hitbox"):
		take_damage_safe(10)

# ---------------- MUERTE ----------------
func _on_died():
	if is_dead:
		return
	is_dead = true
	is_casting = false
	state = PlayerState.LOCKED
	velocity = Vector2.ZERO

	var anim_name = "death_" + get_direction_suffix(last_direction)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

	await get_tree().create_timer(1.0).timeout
	print("Player murió - Game Over")
