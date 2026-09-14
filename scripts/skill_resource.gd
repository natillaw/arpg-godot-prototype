extends Resource
class_name SkillResource

## Nombre para mostrar en UI (ej: en un hotbar de cooldowns)
@export var skill_name := "Skill"

## Tiempo en segundos antes de poder volver a usar esta skill
@export var cooldown := 3.0

## Tiempo que el player queda inmóvil/casteando al usar la skill
@export var cast_lock_time := 0.3

## Escena del proyectil (debe tener un script con función launch(direction, damage, speed))
@export var projectile_scene: PackedScene

## Daño que aplica el proyectil al impactar
@export var damage := 15

## Velocidad de desplazamiento del proyectil
@export var speed := 400.0
