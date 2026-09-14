extends Control
@onready var bar: ProgressBar = $ProgressBar
@export var player_path: NodePath

func _ready():
	var player = get_node(player_path)
	var health = player.get_node("Health")
	bar.max_value = health.max_hp
	bar.value = health.current_hp
	health.damaged.connect(_on_damaged.bind(health))

func _on_damaged(_amount, health):
	bar.value = health.current_hp
