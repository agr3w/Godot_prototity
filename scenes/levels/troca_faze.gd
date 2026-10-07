extends Area2D

@export_file("*.tscn") var proxima_fase: String = "res://IronSnow.tscn"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# set_deferred evita erro de mudar física durante o callback
		call_deferred("_trocar_fase")

func _trocar_fase() -> void:
	get_tree().change_scene_to_file(proxima_fase)
