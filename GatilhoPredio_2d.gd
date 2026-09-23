extends Area2D

@export var predio_path: NodePath

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var predio := get_node_or_null(predio_path)
		if predio == null:
			push_error("Predio Path não configurado ou nó não encontrado: " + str(predio_path))
			return
		predio.ativar()
