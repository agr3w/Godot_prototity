extends Area2D

@export var shake_interval: float = 0.7
@export var shake_intensity: float = 5.0
var is_active: bool = false
var player_ref: CharacterBody2D = null
var timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body as CharacterBody2D
		is_active = true

func _on_body_exited(body: Node2D) -> void:
	if body == player_ref:
		is_active = false
		player_ref = null

func _process(delta: float) -> void:
	if is_active and is_instance_valid(player_ref) and player_ref.has_method("add_camera_shake"):
		timer += delta
		if timer >= shake_interval:
			timer = 0.0
			player_ref.add_camera_shake(shake_intensity, 8.0)
