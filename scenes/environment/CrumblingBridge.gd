extends Node2D

@export var next_scene_path: String = "res://scenes/levels/Sewers_Level.tscn"
@export var fade_overlay: ColorRect
@export var break_angle_degrees: float = 58.0
@export var break_speed: float = 0.35

@onready var breaking_pivot: Node2D = $BreakingPivot
@onready var breaking_collision: CollisionShape2D = $BreakingPivot/StaticBody2D/CollisionShape2D
@onready var trigger_area: Area2D = $TriggerArea

var is_broken: bool = false

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)
	if not fade_overlay:
		fade_overlay = get_node_or_null("../CanvasLayer/FadeOverlay")
		if not fade_overlay:
			fade_overlay = get_node_or_null("../../CanvasLayer/FadeOverlay")

func _on_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_broken:
		trigger_collapse(body as CharacterBody2D)

func trigger_collapse(player: CharacterBody2D) -> void:
	is_broken = true
	
	# 1. Trava os inputs e a física do jogador
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	
	# 2. Tremor forte na câmera de impacto do chão cedendo
	if player.has_method("add_camera_shake"):
		player.add_camera_shake(12.0, 3.5)

	# 3. Animação de quebra do chão inclinando para baixo
	var tilt_tween = create_tween()
	tilt_tween.tween_property(breaking_pivot, "rotation", deg_to_rad(break_angle_degrees), break_speed)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	
	# 4. Desativa a colisão para o jogador despencar
	if is_instance_valid(breaking_collision):
		breaking_collision.set_deferred("disabled", true)

	# 5. Animação de queda do personagem
	if player.has_method("play_fall_animation"):
		player.play_fall_animation()
	elif player.has_node("AnimationPlayer"):
		var anim: AnimationPlayer = player.get_node("AnimationPlayer")
		if anim.has_animation("jump"):
			anim.play("jump")

	# 6. Movimento de queda acelerada pelo vão do abismo
	var fall_tween = create_tween().set_parallel(true)
	fall_tween.tween_property(player, "position:y", player.position.y + 650.0, 1.4)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	fall_tween.tween_property(player, "position:x", player.position.x + 90.0, 1.4)\
		.set_trans(Tween.TRANS_LINEAR)

	# 7. Fade to Black cinematográfico
	if not fade_overlay:
		fade_overlay = get_node_or_null("../../CanvasLayer/FadeOverlay")
	
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate.a = 0.0
		var fade_tween = create_tween()
		fade_tween.tween_interval(0.45)
		fade_tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.8)
		await fade_tween.finished
	else:
		await fall_tween.finished

	# 8. Troca de cena para a camada subterrânea (Esgotos)
	if ResourceLoader.exists(next_scene_path):
		get_tree().change_scene_to_file(next_scene_path)
	else:
		push_warning("Cena não encontrada: " + next_scene_path)
