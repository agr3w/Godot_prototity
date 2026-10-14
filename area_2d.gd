extends Area2D

@export var plataforma: Node            # arraste a plataforma aqui, no Inspector
@export var uma_vez: bool = true        # false = pode ativar de novo ao reentrar

var usado: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if usado and uma_vez:
		return
	if body.is_in_group("player"):
		usado = true
		if plataforma and plataforma.has_method("ativar"):
			plataforma.ativar()
