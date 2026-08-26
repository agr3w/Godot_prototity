extends Node2D

@onready var player: CharacterBody2D = get_node_or_null("CharacterBody2D")
@onready var fade_overlay: ColorRect = get_node_or_null("CanvasLayer/FadeOverlay")
@onready var photon_light: PointLight2D = get_node_or_null("CharacterBody2D/PhotonLight2D")

func _ready() -> void:
	intro_wake_up_sequence()

func intro_wake_up_sequence() -> void:
	if not player:
		return

	# 1. Trava o controle e física do jogador
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	
	# 2. Tela 100% preta e Célula de Fótons apagada
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate.a = 1.0

	if photon_light:
		photon_light.energy = 0.0

	# 3. Coloca o player deitado (pose no chão)
	var anim: AnimationPlayer = player.get_node_or_null("AnimationPlayer")
	if anim and anim.has_animation("death"):
		anim.play("death")
		anim.seek(anim.current_animation_length, true)
		anim.pause()

	# 4. Silêncio e escuridão inicial (1.0s)
	await get_tree().create_timer(1.0).timeout

	# 5. PRIMEIRO PISCAR DE OLHOS (Visão embaçada inicial)
	if fade_overlay:
		var blink1_open = create_tween()
		blink1_open.tween_property(fade_overlay, "modulate:a", 0.45, 0.7)\
			.set_trans(Tween.TRANS_SINE)
		await blink1_open.finished

		# Faísca inicial na Célula de Fótons
		if photon_light:
			var spark_tween = create_tween()
			spark_tween.tween_property(photon_light, "energy", 0.35, 0.2)
			spark_tween.tween_property(photon_light, "energy", 0.08, 0.2)

		# Os olhos pesam e fecham novamente
		var blink1_close = create_tween()
		blink1_close.tween_property(fade_overlay, "modulate:a", 0.9, 0.35)\
			.set_trans(Tween.TRANS_SINE)
		await blink1_close.finished

	# Leve tremor de tontura ao recobrar a consciência
	if player.has_method("add_camera_shake"):
		player.add_camera_shake(3.5, 4.0)

	await get_tree().create_timer(0.4).timeout

	# 6. SEGUNDO PISCAR (Despertar completo)
	if fade_overlay:
		var blink2_open = create_tween()
		blink2_open.tween_property(fade_overlay, "modulate:a", 0.0, 1.8)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)

		# Célula de Fótons estabiliza sua luz ciano
		if photon_light:
			var light_stable = create_tween()
			light_stable.tween_property(photon_light, "energy", 1.2, 0.7)
			light_stable.tween_property(photon_light, "energy", 1.0, 0.5)

		await blink2_open.finished
		fade_overlay.visible = false

	await get_tree().create_timer(0.4).timeout

	# 7. Personagem levanta e sacode a poeira
	if anim and anim.has_animation("idle"):
		anim.play("idle")
	
	var dust = player.get_node_or_null("GPUParticles2D")
	if dust:
		dust.restart()
		dust.emitting = true

	if player.has_method("add_camera_shake"):
		player.add_camera_shake(2.0, 6.0)

	# 8. Devolve o controle para o jogador!
	player.set_physics_process(true)
