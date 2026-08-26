extends Area2D

@export var next_scene_path: String = "res://scenes/levels/Sewers_Level.tscn"
@export var fade_overlay: ColorRect
@export var fall_distance_y: float = 650.0
@export var fall_distance_x: float = 140.0
@export var fall_duration: float = 1.3

var is_falling: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if not fade_overlay:
		fade_overlay = get_node_or_null("../CanvasLayer/FadeOverlay")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_falling:
		trigger_fall_sequence(body as CharacterBody2D)

func trigger_fall_sequence(player: CharacterBody2D) -> void:
	is_falling = true
	
	# 1. Trava os inputs e a física do jogador
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	
	# 2. Chama animação de queda no player se existir
	if player.has_method("play_fall_animation"):
		player.play_fall_animation()
	elif player.has_node("AnimationPlayer"):
		var anim: AnimationPlayer = player.get_node("AnimationPlayer")
		if anim.has_animation("jump"):
			anim.play("jump")
	
	# 3. Tremor de câmera de impacto/desespero
	if player.has_method("add_camera_shake"):
		player.add_camera_shake(8.0, 4.0)

	# 4. Animação de queda acelerada usando Tween (Parábola cinematográfica)
	var fall_tween = create_tween().set_parallel(true)
	fall_tween.tween_property(player, "position:y", player.position.y + fall_distance_y, fall_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	fall_tween.tween_property(player, "position:x", player.position.x + fall_distance_x, fall_duration)\
		.set_trans(Tween.TRANS_LINEAR)
	
	# 5. Efeito Fade to Black
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate.a = 0.0
		var fade_tween = create_tween()
		fade_tween.tween_interval(0.4) # Aguarda começar a despencar
		fade_tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.8)
		await fade_tween.finished
	else:
		await fall_tween.finished
		
	# 6. Carrega a camada subterrânea (Esgotos)
	if ResourceLoader.exists(next_scene_path):
		get_tree().change_scene_to_file(next_scene_path)
	else:
		push_warning("Cena de destino não encontrada: " + next_scene_path)
