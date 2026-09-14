extends CharacterBody2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

enum EnemyState { IDLE, CHASE, ATTACK, DEAD }
var state: EnemyState = EnemyState.IDLE

var speed := 140
var chase_range := 1000
var attack_range := 55
var last_direction := Vector2.DOWN
var player: Node2D = null
var is_attacking := false
var attack_damage := 8
var attack_cooldown := 1.0
var can_attack := true

@export var enemy_enabled: bool = false  # actívalo desde el Inspector cuando quieras usarlo

func _ready():
	if not enemy_enabled:
		set_physics_process(false)
		visible = false
		if has_node("Hurtbox"):
			$Hurtbox.set_deferred("monitoring", false)
		if has_node("CollisionShape2D"):
			$CollisionShape2D.set_deferred("disabled", true)
		collision_layer = 0
		collision_mask = 0
		return

	set_physics_process(true)
	z_index = 2
	player = get_tree().get_first_node_in_group("player")
	$Health.died.connect(_on_died)
	$Hurtbox.area_entered.connect(_on_hurtbox_area_entered)

func _physics_process(_delta):
	if state == EnemyState.DEAD or player == null:
		return
	if not is_instance_valid(player) or (player.has_node("Health") and player.get_node("Health").current_hp <= 0):
		velocity = Vector2.ZERO
		play_idle()
		return
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var dist = global_position.distance_to(player.global_position)
	match state:
		EnemyState.IDLE:
			velocity = Vector2.ZERO
			play_idle()
			if dist <= chase_range:
				state = EnemyState.CHASE
		EnemyState.CHASE:
			if dist <= attack_range:
				state = EnemyState.ATTACK
			elif dist > chase_range:
				state = EnemyState.IDLE
			else:
				var dir = (player.global_position - global_position).normalized()
				last_direction = dir
				velocity = dir * speed
				play_walk(dir)
		EnemyState.ATTACK:
			velocity = Vector2.ZERO
			do_attack()
	move_and_slide()

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

func play_idle():
	var anim = "idle_" + get_direction_suffix(last_direction)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

func play_walk(dir: Vector2):
	var anim = "walk_" + get_direction_suffix(dir)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

func do_attack():
	if not can_attack:
		return
	is_attacking = true
	can_attack = false
	var anim = "attack_" + get_direction_suffix(last_direction)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= attack_range + 15:
			if player.has_node("Health"):
				player.get_node("Health").take_damage(attack_damage)
	await get_tree().create_timer(0.3).timeout
	is_attacking = false
	if is_instance_valid(player):
		var new_dist = global_position.distance_to(player.global_position)
		if new_dist <= attack_range:
			state = EnemyState.ATTACK
		elif new_dist <= chase_range:
			state = EnemyState.CHASE
		else:
			state = EnemyState.IDLE
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func _on_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"):
		$Health.take_damage(15)

func _on_died():
	state = EnemyState.DEAD
	var anim = "death_" + get_direction_suffix(last_direction)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
		await sprite.animation_finished
	queue_free()
