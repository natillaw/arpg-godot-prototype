extends Control
@export var player_path: NodePath
@onready var charge1: ColorRect = $Charge1
@onready var charge2: ColorRect = $Charge2

var player: Node = null

func _ready():
	if player_path:
		player = get_node(player_path)

func _process(_delta):
	if player == null:
		return

	update_charge_visual(charge1, 0)
	update_charge_visual(charge2, 1)

func update_charge_visual(rect: ColorRect, index: int):
	if index < player.roll_charges:
		rect.color = Color(0.3, 0.8, 1.0)  # celeste: carga disponible
	else:
		# está recargando: muestra progreso con un tono más apagado que se aclara
		var progress = 1.0 - (player.roll_recharge_timer / player.roll_recharge_time)
		progress = clamp(progress, 0.0, 1.0)
		rect.color = Color(0.15, 0.3, 0.4).lerp(Color(0.3, 0.8, 1.0), progress)
