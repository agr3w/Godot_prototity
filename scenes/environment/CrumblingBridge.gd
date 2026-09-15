extends Node2D

@export var next_scene_path: String = "res://scenes/levels/Sewers_Level.tscn"
@export var fade_overlay: ColorRect
@export var collapse_delay: float = 0.6 # Tempo (em segundos) que a câmera treme antes da ponte quebrar
@export var break_angle_degrees: float = 58.0
@export var break_speed: float = 0.35

# Referências aos nós de som
#@onready var sond_colapse = $ColapseSond if has_node("ColapseSond") else null
@onready var break_bridge_sound = $BreakBridge if has_node("BreakBridge") else null

@onready var breaking_pivot: Node2D = $BreakingPivot if has_node("BreakingPivot") else null
@onready var trigger_area: Area2D = $TriggerArea if has_node("TriggerArea") else null

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
	if not player:
		return
		
	is_broken = true
	
	# 1. Trava os inputs e a física do jogador imediatamente
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	
	# 2. FASE PREPARATÓRIA: Toca o som de colapso/tremor e treme a câmera PRIMEIRO
	#if sond_colapse and sond_colapse.stream:
		#sond_colapse.play()

	if player.has_method("add_camera_shake"):
		player.call("add_camera_shake", 12.0, 3.5)

	# Aguarda o tempo do aviso prévio/tremor antes de romper a estrutura
	await get_tree().create_timer(collapse_delay).timeout

	# 3. FASE DE RUPTURA: Toca o som da ponte quebrando de fato
	if break_bridge_sound and break_bridge_sound.stream:
		break_bridge_sound.play()

	# 4. Animação da ponte inclinando/caindo
	if breaking_pivot:
		var tilt_tween = create_tween()
		tilt_tween.tween_property(breaking_pivot, "rotation", deg_to_rad(break_angle_degrees), break_speed)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN)
	
	# 5. Desativa a colisão para liberar a queda do jogador
	var collision = get_node_or_null("BreakingPivot/StaticBody2D/CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", true)

	# 6. Animação de queda do jogador
	if player.has_method("play_fall_animation"):
		player.call("play_fall_animation")
	elif player.has_node("AnimationPlayer"):
		var anim: AnimationPlayer = player.get_node("AnimationPlayer")
		if anim.has_animation("jump"):
			anim.play("jump")

	# 7. Movimento de queda acelerada pelo vão
	var fall_tween = create_tween().set_parallel(true)
	fall_tween.tween_property(player, "position:y", player.position.y + 650.0, 1.4)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	fall_tween.tween_property(player, "position:x", player.position.x + 90.0, 1.4)\
		.set_trans(Tween.TRANS_LINEAR)

	# 8. Transição com Fade Overlay
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

	# 9. Troca para a próxima cena
	if ResourceLoader.exists(next_scene_path):
		get_tree().change_scene_to_file(next_scene_path)
	else:
		push_warning("Cena não encontrada no caminho: " + next_scene_path)
