extends Control

@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var phase_label: Label = $MarginContainer/VBoxContainer/PhaseLabel

var boss: Node = null


func _ready():
	visible = false  # se muestra recién cuando el boss aparece / aggrea


# Llamá esto una vez, cuando el boss entra en combate.
# Ejemplo desde el boss: $UI/BossHealthBar.bind_to_boss(self, "Rey Carmesí")
func bind_to_boss(boss_node: Node, boss_name: String = "Boss") -> void:
	boss = boss_node
	name_label.text = boss_name
	visible = true

	if boss.has_signal("health_changed") and not boss.is_connected("health_changed", _on_boss_health_changed):
		boss.health_changed.connect(_on_boss_health_changed)

	if boss.has_signal("phase_changed") and not boss.is_connected("phase_changed", _on_boss_phase_changed):
		boss.phase_changed.connect(_on_boss_phase_changed)

	if boss.has_signal("died") and not boss.is_connected("died", _on_boss_died):
		boss.died.connect(_on_boss_died)

	if boss.has_method("get_max_health") and boss.has_method("get_current_health"):
		progress_bar.max_value = boss.get_max_health()
		progress_bar.value = boss.get_current_health()


func _on_boss_health_changed(current: float, max_health: float) -> void:
	progress_bar.max_value = max_health
	progress_bar.value = current
	_update_bar_color(current / max_health if max_health > 0 else 0.0)


func _on_boss_phase_changed(phase_number: int) -> void:
	phase_label.text = "Fase " + str(phase_number)
	phase_label.visible = true


func _on_boss_died() -> void:
	visible = false


func _update_bar_color(ratio: float) -> void:
	# Cambia de color según cuánta vida le queda; ajustá los colores a tu paleta.
	if ratio > 0.5:
		progress_bar.modulate = Color(1, 1, 1)
	elif ratio > 0.25:
		progress_bar.modulate = Color(1, 0.75, 0.3)
	else:
		progress_bar.modulate = Color(1, 0.3, 0.3)
