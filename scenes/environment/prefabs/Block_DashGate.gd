extends Node2D

@export var hazard_damage: int = 15
@onready var hazard_area: Area2D = $HazardArea

func _ready() -> void:
	if hazard_area:
		hazard_area.body_entered.connect(_on_hazard_body_entered)

func _on_hazard_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Só causa dano se o jogador NÃO estiver dando Dash (I-Frames)
		if "is_dashing" in body and not body.is_dashing:
			if body.has_method("take_damage"):
				body.take_damage(hazard_damage)
