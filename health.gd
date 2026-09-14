# health.gd — como componente reusable (Node)
extends Node
class_name Health

signal died
signal damaged(amount: int)

@export var max_hp: int = 100
var current_hp: int

func _ready():
	current_hp = max_hp


func set_max_hp(value: int) -> void:
	max_hp = value
	current_hp = max_hp


func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	print(get_parent().name, " recibió ", amount, " de daño. HP: ", current_hp)
	damaged.emit(amount)
	if current_hp <= 0:
		died.emit()
