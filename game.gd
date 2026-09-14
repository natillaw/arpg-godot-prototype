# en un script de Game.gd, o donde quieras spawnear
extends Node2D
const ENEMY_SCENE = preload("res://scenes/enemies/EnemyBase.tscn")

func spawn_enemy(pos: Vector2):
	var enemy = ENEMY_SCENE.instantiate()
	enemy.global_position = pos
	add_child(enemy)
func _ready():
	spawn_enemy(Vector2(300, 200))  # posición de prueba, ajusta a tu mapa
