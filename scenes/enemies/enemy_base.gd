extends CharacterBody2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

enum EnemyState { IDLE, CHASE, ATTACK, DEAD }
var state: EnemyState = EnemyState.IDLE

# ---------------- SEÑALES PARA LA UI (barra de vida) ----------------
signal health_changed(current, max_health)
signal phase_changed(phase_number)
signal died

var current_phase := 1
var has_bound_ui := false
@export var boss_display_name := "Boss"

var speed := 180
var chase_range := 900
var attack_range := 100
var ability_range := 650.0
var last_direction := Vector2.DOWN
var player: Node2D = null
var is_attacking := false

var attack_cooldown := 0.6
var can_attack := true

var attack_watchdog_max := 2.0
var attack_start_time := 0.0

var current_action_id := 0

const TelegraphZoneScene = preload("res://telegraph_zone.tscn")
const TelegraphLineScene = preload("res://telegraph_line.tscn")
const MinionScene = preload("res://scenes/enemies/EnemyBase.tscn")
const WeaponSlashScene = preload("res://weapon_slash.tscn")
const TornadoVFXScene = preload("res://tornado_vfx_scene.tscn")

const PLAYER_BODY_LAYER := 1

enum AttackPattern { SLAM, CHARGE, MULTI_TELEGRAPH, CONE, SUMMON, SLASH }
var available_patterns: Array = [AttackPattern.SLAM, AttackPattern.MULTI_TELEGRAPH, AttackPattern.CHARGE]
var ranged_patterns: Array = [AttackPattern.SLAM, AttackPattern.MULTI_TELEGRAPH, AttackPattern.CHARGE, AttackPattern.SLASH]
var melee_only_patterns: Array = [AttackPattern.CONE]

const AUTO_ATTACK_DAMAGE := 8
const SLAM_DAMAGE := 20
const CHARGE_DAMAGE := 32
const MULTI_TELEGRAPH_DAMAGE := 12
const CONE_DAMAGE := 16
const SUMMON_DAMAGE := 6
const SLASH_DAMAGE := 22
const CYCLONE_DAMAGE := 14

var charge_speed := 850.0
var charge_duration := 1.0
var cone_angle_deg := 90.0
var cone_range := 100.0

var ability_cooldown_timer := 0.0
var ability_cooldown_time := 3.0

var is_berserk := false
var cyclone_duration := 5.0
var cyclone_hit_cooldown := 0.5

func get_damage_multiplier() -> float:
	return 1.2 if is_berserk else 1.0

func deal_player_damage(amount: int):
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("take_damage_safe"):
		player.take_damage_safe(amount)
	elif player.has_node("Health"):
		player.get_node("Health").take_damage(amount)

# ---------------- HELPERS PARA LA UI ----------------
func get_max_health() -> int:
	return $Health.max_hp

func get_current_health() -> int:
	return $Health.current_hp

func _set_phase(phase_number: int) -> void:
	if phase_number != current_phase:
		current_phase = phase_number
		phase_changed.emit(phase_number)

func _bind_health_bar_if_needed() -> void:
	if has_bound_ui:
		return
	var bar = get_tree().get_first_node_in_group("boss_health_bar")
	if bar and bar.has_method("bind_to_boss"):
		has_bound_ui = true
		bar.bind_to_boss(self, boss_display_name)

func _ready():
	$Health.set_max_hp(600)
	set_physics_process(true)
	process_mode = Node.PROCESS_MODE_INHERIT
	z_index = 2
	player = get_tree().get_first_node_in_group("player")
	$Health.died.connect(_on_died)
	$Health.damaged.connect(_on_damaged)
	$Hurtbox.area_entered.connect(_on_hurtbox_area_entered)

func _physics_process(_delta):
	if state == EnemyState.DEAD or player == null:
		return

	if ability_cooldown_timer > 0:
		ability_cooldown_timer -= _delta

	if not is_instance_valid(player) or (player.has_node("Health") and player.get_node("Health").current_hp <= 0):
		velocity = Vector2.ZERO
		play_idle()
		return

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		if Time.get_ticks_msec() - attack_start_time > attack_watchdog_max * 1000:
			force_reset_attack()
		return

	var dist = global_position.distance_to(player.global_position)

	match state:
		EnemyState.IDLE:
			velocity = Vector2.ZERO
			play_idle()
			if dist <= chase_range:
				state = EnemyState.CHASE
				_bind_health_bar_if_needed()
		EnemyState.CHASE:
			if dist <= attack_range:
				state = EnemyState.ATTACK
			elif ability_cooldown_timer <= 0 and dist <= ability_range:
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
			play_attack()

	move_and_slide()

func force_reset_attack():
	current_action_id += 1
	is_attacking = false
	can_attack = true
	velocity = Vector2.ZERO
	sprite.visible = true
	if has_node("ChargeHitbox") and $ChargeHitbox.has_node("CollisionShape2D"):
		$ChargeHitbox/CollisionShape2D.disabled = true
	if is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= chase_range:
			state = EnemyState.CHASE
			var dir = (player.global_position - global_position).normalized()
			play_walk(dir)
		else:
			state = EnemyState.IDLE
			play_idle()
	else:
		state = EnemyState.IDLE
		play_idle()

# ---------------- ANIMACIONES ----------------
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

# ---------------- SELECTOR ----------------
func play_attack():
	if not can_attack:
		return
	current_action_id += 1
	var my_id = current_action_id
	is_attacking = true
	can_attack = false
	attack_start_time = Time.get_ticks_msec()

	var dist_now = global_position.distance_to(player.global_position) if is_instance_valid(player) else 9999.0

	if ability_cooldown_timer <= 0:
		ability_cooldown_timer = ability_cooldown_time
		var pool = ranged_patterns.duplicate()
		if dist_now <= attack_range:
			pool += melee_only_patterns
			if available_patterns.has(AttackPattern.SUMMON):
				pool.append(AttackPattern.SUMMON)
		var pattern = pool[randi() % pool.size()]
		match pattern:
			AttackPattern.SLAM:
				await attack_slam(my_id)
			AttackPattern.CHARGE:
				await attack_charge(my_id)
			AttackPattern.MULTI_TELEGRAPH:
				await attack_multi_telegraph(my_id)
			AttackPattern.CONE:
				await attack_cone(my_id)
			AttackPattern.SUMMON:
				await attack_summon(my_id)
			AttackPattern.SLASH:
				await attack_slash(my_id)
	elif dist_now <= attack_range:
		await auto_attack(my_id)
	else:
		if my_id == current_action_id:
			is_attacking = false
			can_attack = true
			state = EnemyState.CHASE
		return

	is_attacking = false

	if my_id == current_action_id:
		if is_instance_valid(player):
			var new_dist = global_position.distance_to(player.global_position)
			if new_dist <= attack_range:
				state = EnemyState.ATTACK
			elif new_dist <= ability_range or new_dist <= chase_range:
				state = EnemyState.CHASE
				var dir = (player.global_position - global_position).normalized()
				play_walk(dir)
			else:
				state = EnemyState.IDLE
				play_idle()
		else:
			state = EnemyState.IDLE
			play_idle()

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

# ---------------- AUTO-ATAQUE ----------------
func auto_attack(my_id: int):
	var anim = "attack_" + get_direction_suffix(last_direction)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

	await get_tree().create_timer(0.2).timeout
	if my_id != current_action_id:
		return

	if is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= attack_range + 15:
			deal_player_damage(int(AUTO_ATTACK_DAMAGE * get_damage_multiplier()))

	await get_tree().create_timer(0.2).timeout

# ---------------- HABILIDADES ----------------
func attack_slam(my_id: int):
	var telegraph = TelegraphZoneScene.instantiate()
	get_tree().current_scene.add_child(telegraph)
	telegraph.global_position = player.global_position if is_instance_valid(player) else global_position
	telegraph.radius = 90
	telegraph.is_major = true
	telegraph.telegraph_time = 0.6
	telegraph.damage = int(SLAM_DAMAGE * get_damage_multiplier())

	telegraph.telegraph_finished.connect(func():
		if my_id == current_action_id:
			var anim = "cast_" + get_direction_suffix(last_direction)
			if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
				sprite.play(anim)
	)

	await get_tree().create_timer(telegraph.telegraph_time + 0.1).timeout

func attack_charge(my_id: int):
	if not is_instance_valid(player):
		return
	if not has_node("ChargeHitbox") or not $ChargeHitbox.has_node("CollisionShape2D"):
		return

	var anim = "charge_" + get_direction_suffix(last_direction)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

	var charge_dir = (player.global_position - global_position).normalized()
	last_direction = charge_dir

	var line = TelegraphLineScene.instantiate()
	get_tree().current_scene.add_child(line)
	line.global_position = global_position
	line.direction = charge_dir
	line.length = charge_speed * charge_duration
	line.width = 100
	line.telegraph_time = 0.4

	await get_tree().create_timer(0.4).timeout
	if my_id != current_action_id:
		return

	$ChargeHitbox/CollisionShape2D.disabled = false
	var hit := false

	var elapsed := 0.0
	while elapsed < charge_duration:
		if my_id != current_action_id:
			$ChargeHitbox/CollisionShape2D.disabled = true
			return
		velocity = charge_dir * charge_speed
		move_and_slide()

		if not hit:
			for body in $ChargeHitbox.get_overlapping_bodies():
				if body.is_in_group("player"):
					deal_player_damage(int(CHARGE_DAMAGE * get_damage_multiplier()))
					hit = true
					break
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()

	$ChargeHitbox/CollisionShape2D.disabled = true
	velocity = Vector2.ZERO

	if is_instance_valid(player):
		var post_dist = global_position.distance_to(player.global_position)
		if post_dist < 70:
			var push_dir = (global_position - player.global_position).normalized()
			if push_dir == Vector2.ZERO:
				push_dir = -charge_dir
			global_position += push_dir * (70 - post_dist)

func spawn_flame_puff():
	var puff = Node2D.new()
	puff.top_level = true
	puff.z_index = 1
	puff.global_position = global_position
	get_tree().current_scene.add_child(puff)

	var script := GDScript.new()
	script.source_code = """
extends Node2D
var elapsed = 0.0
var duration = 0.4

func _process(delta):
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()

func _draw():
	var alpha = 1.0 - (elapsed / duration)
	var size = 12.0 + (elapsed / duration) * 6.0
	draw_circle(Vector2.ZERO, size, Color(1.0, 0.4, 0.05, alpha * 0.7))
"""
	script.reload()
	puff.set_script(script)

func attack_multi_telegraph(my_id: int):
	if not is_instance_valid(player):
		return

	var center = player.global_position
	var count := 12
	var first_telegraph = null

	for i in range(count):
		var telegraph = TelegraphZoneScene.instantiate()
		get_tree().current_scene.add_child(telegraph)
		var offset = Vector2(randf_range(-180, 180), randf_range(-180, 180))
		telegraph.global_position = center + offset
		telegraph.radius = 50
		telegraph.is_major = false
		telegraph.telegraph_time = 0.7 + i * 0.06
		telegraph.damage = int(MULTI_TELEGRAPH_DAMAGE * get_damage_multiplier())
		if i == 0:
			first_telegraph = telegraph

	if first_telegraph:
		first_telegraph.telegraph_finished.connect(func():
			if my_id == current_action_id:
				var anim = "cast_" + get_direction_suffix(last_direction)
				if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
					sprite.play(anim)
		)

	await get_tree().create_timer(1.5).timeout

func attack_cone(my_id: int):
	if not is_instance_valid(player):
		return
	var dir = (player.global_position - global_position).normalized()
	last_direction = dir
	var anim = "cast_" + get_direction_suffix(last_direction)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

	await get_tree().create_timer(0.3).timeout
	if my_id != current_action_id:
		return

	if is_instance_valid(player):
		var to_player = player.global_position - global_position
		if to_player.length() <= cone_range:
			var angle_diff = rad_to_deg(dir.angle_to(to_player.normalized()))
			if abs(angle_diff) <= cone_angle_deg / 2.0:
				deal_player_damage(int(CONE_DAMAGE * get_damage_multiplier()))

	await get_tree().create_timer(0.2).timeout

func attack_summon(my_id: int):
	var anim = "cast_" + get_direction_suffix(last_direction)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

	for i in range(2):
		var minion = MinionScene.instantiate()
		get_tree().current_scene.add_child(minion)
		var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		minion.global_position = global_position + offset
		if minion.has_node("Health"):
			minion.get_node("Health").max_hp = 30
		minion.scale = Vector2(0.6, 0.6)
		minion.speed = 120

	await get_tree().create_timer(0.7).timeout

func attack_slash(my_id: int):
	if not is_instance_valid(player):
		return
	var dir = (player.global_position - global_position).normalized()
	last_direction = dir

	var anim = "cast_" + get_direction_suffix(dir)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)

	await get_tree().create_timer(0.35).timeout
	if my_id != current_action_id:
		return

	var slash = WeaponSlashScene.instantiate()
	get_tree().current_scene.add_child(slash)
	slash.global_position = global_position
	slash.direction = (player.global_position - global_position).normalized()
	slash.damage = int(SLASH_DAMAGE * get_damage_multiplier())

	await get_tree().create_timer(0.25).timeout

# ---------------- BERSERK / CYCLONE ----------------
func enter_berserk():
	speed *= 1.4
	ability_cooldown_time *= 0.6
	attack_cooldown *= 0.6
	trigger_cyclone()

func trigger_cyclone():
	current_action_id += 1
	var my_id = current_action_id
	is_attacking = true
	can_attack = false
	attack_start_time = Time.get_ticks_msec()

	sprite.visible = false

	var tornado_vfx = TornadoVFXScene.instantiate()
	get_tree().current_scene.add_child(tornado_vfx)
	tornado_vfx.top_level = true
	tornado_vfx.z_index = 1

	var cyclone_area := Area2D.new()
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 110
	shape_node.shape = circle
	cyclone_area.add_child(shape_node)
	cyclone_area.collision_layer = 0
	cyclone_area.set_collision_mask_value(PLAYER_BODY_LAYER, true)
	get_tree().current_scene.add_child(cyclone_area)

	var elapsed := 0.0
	var hit_timer := 0.0
	while elapsed < cyclone_duration:
		if my_id != current_action_id or state == EnemyState.DEAD:
			break
		if not is_instance_valid(player) or (player.has_node("Health") and player.get_node("Health").current_hp <= 0):
			break

		tornado_vfx.global_position = global_position
		cyclone_area.global_position = global_position

		if is_instance_valid(player):
			var dir = (player.global_position - global_position).normalized()
			velocity = dir * (speed * 0.5)
			move_and_slide()

		hit_timer -= get_physics_process_delta_time()
		if hit_timer <= 0:
			for body in cyclone_area.get_overlapping_bodies():
				if body.is_in_group("player"):
					deal_player_damage(int(CYCLONE_DAMAGE * get_damage_multiplier()))
					hit_timer = cyclone_hit_cooldown

		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()

	sprite.visible = true
	if is_instance_valid(tornado_vfx):
		tornado_vfx.queue_free()
	if is_instance_valid(cyclone_area):
		cyclone_area.queue_free()

	velocity = Vector2.ZERO
	is_attacking = false
	can_attack = true

	if my_id == current_action_id and state != EnemyState.DEAD:
		state = EnemyState.CHASE

# ---------------- RECIBIR DAÑO ----------------
func _on_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("player_hitbox"):
		$Health.take_damage(15)

func _on_damaged(_amount):
	if state != EnemyState.DEAD:
		var hit_anim = "hit_" + get_direction_suffix(last_direction)
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(hit_anim):
			sprite.play(hit_anim)

	var current = $Health.current_hp
	var max_health = $Health.max_hp
	health_changed.emit(current, max_health)

	var hp_percent = float(current) / float(max_health)

	if hp_percent <= 0.66 and not available_patterns.has(AttackPattern.CONE):
		available_patterns.append(AttackPattern.CONE)
		_set_phase(2)
	if hp_percent <= 0.5 and not is_berserk:
		is_berserk = true
		call_deferred("enter_berserk")
		_set_phase(3)
	if hp_percent <= 0.33 and not available_patterns.has(AttackPattern.SUMMON):
		available_patterns.append(AttackPattern.SUMMON)
		_set_phase(4)

func _on_died():
	current_action_id += 1
	state = EnemyState.DEAD
	died.emit()
	sprite.visible = true
	var death_anim = "death_" + get_direction_suffix(last_direction)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(death_anim):
		sprite.play(death_anim)
	await sprite.animation_finished
	queue_free()
