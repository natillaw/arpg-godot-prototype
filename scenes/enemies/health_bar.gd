extends Node2D
@onready var bar: ProgressBar = $ProgressBar
@onready var arrow: Node = $SelectionArrow

func _ready():
	call_deferred("setup")

func setup():
	top_level = true
	z_index = 100
	arrow.visible = false
	if not get_parent().has_node("Health"):
		print("ERROR: HealthBar no encuentra Health en su padre: ", get_parent().name)
		return
	var health = get_parent().get_node("Health")
	bar.max_value = health.max_hp
	bar.value = health.current_hp
	if not health.damaged.is_connected(_on_damaged):
		health.damaged.connect(_on_damaged)

func _process(_delta):
	if get_parent():
		global_position = get_parent().global_position + Vector2(0, -25)

func _on_damaged(_amount):
	if get_parent() and get_parent().has_node("Health"):
		bar.value = get_parent().get_node("Health").current_hp

func set_selected(is_selected: bool):
	arrow.visible = is_selected
