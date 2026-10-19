
extends CharacterBody2D
 
signal vida_mudou(atual: int, maximo: int)   # avisa a barra de vida
signal morreu                                # avisa que o boss morreu
 
@export var max_health: int = 7              # antes: 3
@export var patrol_speed: float = 100.0
@export var chase_speed: float = 170.0       # antes: 150 (versão fraca) / 190 (versão agressiva)
@export var gravity: float = 900.0
@export var damage_amount: int = 15
@export var camada_inimigo: int = 2          # camada de colisão dos inimigos (igual aos mutantes)
 
@export_group("Agressividade")
@export var detection_range: float = 550.0   # começa a perseguir
@export var lose_range: float = 850.0        # só desiste além disso
@export var attack_range: float = 130.0      # distância para começar o bote
@export var attack_reach: float = 180.0      # alcance do golpe à frente do inimigo
@export var attack_height: float = 120.0     # tolerância de altura (para cima e para baixo)
@export var lunge_speed: float = 480.0
@export var lunge_jump: float = -220.0
@export var windup_time: float = 0.18        # preparo antes do bote
@export var lunge_time: float = 0.28
@export var attack_cooldown: float = 0.45    # intervalo entre os golpes da sequência
@export var hit_cooldown: float = 0.4        # intervalo entre danos no player
@export var wall_jump_velocity: float = -380.0
@export var stun_time: float = 0.12
 
@export_group("Descanso")
@export var combo_min_ataques: int = 3       # mínimo de ataques antes de descansar
@export var combo_max_ataques: int = 4       # máximo de ataques antes de descansar
@export var rest_time: float = 1.2           # tempo descansando (janela para o player atacar)
@export var dano_no_descanso: bool = false   # true = encostar nele machuca mesmo cansado
@export var rest_tint: Color = Color(0.7, 0.8, 1.0, 1.0)   # tom do boss cansado
 
@export_group("Animação")
@export var sprite_olha_para_direita: bool = true   # false se o desenho original olha para a esquerda
@export var anim_walk: String = "walking"           # animação de caminhada
@export var anim_attack: String = "atack"           # primeiro ataque
@export var anim_attack_2: String = "atackSegundo"  # segundo ataque
@export var anim_dead: String = "dead"              # animação de morte
@export_range(0.0, 1.0) var chance_segundo_ataque: float = 0.5  # 0 = só o primeiro, 1 = só o segundo
@export var sincronizar_ataque: bool = true         # ajusta a velocidade da animação para durar preparo + bote
@export var dead_hold_time: float = 0.6             # tempo parado no último quadro antes de sumir
@export var dead_fade_time: float = 0.4             # duração do fade final
 
var current_health: int
var direction: int = -1
var is_stunned: bool = false
var is_dead: bool = false
var is_chasing: bool = false
var is_attacking: bool = false
var is_lunging: bool = false
var is_resting: bool = false
var combo_left: int = 0
var rest_left: float = 0.0
var attack_hit_done: bool = false
var attack_token: int = 0
var attack_cd_left: float = 0.0
var hit_cd_left: float = 0.0
var player: Node2D
var sprite: AnimatedSprite2D
var hitbox: Area2D
 
@onready var ledge_detector: RayCast2D = get_node_or_null("LedgeDetector")
@onready var wall_detector: RayCast2D = get_node_or_null("WallDetector")
 
func _ready() -> void:
	# Acha o AnimatedSprite2D, não importa o nome do nó
	var achados := find_children("*", "AnimatedSprite2D", true, false)
	if achados.is_empty():
		push_error("Inimigo sem AnimatedSprite2D: adicione o sprite como filho do CharacterBody2D.")
		set_physics_process(false)
		return
	sprite = achados[0]
 
	# Acha a Area2D de dano (HitBox), não importa o nome do nó
	var areas := find_children("*", "Area2D", true, false)
	if areas.size() > 0:
		hitbox = areas[0]
 
	add_to_group("enemy")
	add_to_group("boss")   # para a barra de vida achar o boss pelo grupo, se precisar
 
	# Camada de colisão dos inimigos (a espada do player precisa ter essa camada na Mask)
	collision_layer = 0
	set_collision_layer_value(camada_inimigo, true)
 
	current_health = max_health
	vida_mudou.emit(current_health, max_health)   # inicializa a barra cheia
	reset_combo()
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
 
	if sprite.sprite_frames:
		# Se o nome da caminhada não existir, usa a primeira animação que o sprite tiver
		if not sprite.sprite_frames.has_animation(anim_walk):
			var nomes = sprite.sprite_frames.get_animation_names()
			if nomes.size() > 0:
				anim_walk = nomes[0]
		# Ataques e morte tocam uma vez só (sem loop)
		for nome in [anim_attack, anim_attack_2, anim_dead]:
			if sprite.sprite_frames.has_animation(nome):
				sprite.sprite_frames.set_animation_loop(nome, false)
 
	sprite.play(anim_walk)
	update_facing()
 
func _physics_process(delta: float) -> void:
	# Morto: só cai até o chão e desliza até parar (a animação de morte toca em die())
	if is_dead:
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		move_and_slide()
		return
 
	# 1. Gravidade
	if not is_on_floor():
		velocity.y += gravity * delta
 
	attack_cd_left = max(attack_cd_left - delta, 0.0)
	hit_cd_left = max(hit_cd_left - delta, 0.0)
 
	# 2. IA
	if is_stunned:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	elif is_attacking:
		pass  # a velocidade é controlada por start_attack()
	elif is_resting:
		velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		sprite.pause()
		rest_left -= delta
		if rest_left <= 0.0:
			end_rest()
	else:
		run_ai()
 
	move_and_slide()
	check_contact_damage()
	check_attack_hit()
 
func run_ai() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
 
	var at_wall = (wall_detector and wall_detector.is_colliding()) or is_on_wall()
	var at_ledge = is_on_floor() and ledge_detector and not ledge_detector.is_colliding()
 
	# Persegue de longe, só desiste bem longe (histerese)
	if is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		is_chasing = dist <= detection_range or (is_chasing and dist <= lose_range)
	else:
		is_chasing = false
 
	if is_chasing:
		var dx = player.global_position.x - global_position.x
		var dy = player.global_position.y - global_position.y
 
		var new_dir = 1 if dx > 0 else -1
		if absf(dx) > 8.0 and new_dir != direction:
			direction = new_dir
			update_facing()
 
		# Bote quando está perto, na mesma altura e sem cooldown
		if absf(dx) <= attack_range and absf(dy) < 80.0 and attack_cd_left <= 0.0 and is_on_floor():
			start_attack()
			return
 
		if at_ledge:
			velocity.x = 0.0
			sprite.pause()            # parado na borda
		else:
			velocity.x = direction * chase_speed
			sprite.speed_scale = 1.6  # anda mais rápido (animação acelerada)
			play_anim(anim_walk)
			if at_wall and is_on_floor():
				velocity.y = wall_jump_velocity
	else:
		# Patrulha
		if at_ledge or at_wall:
			direction *= -1
			update_facing()
		velocity.x = direction * patrol_speed
		sprite.speed_scale = 1.0
		play_anim(anim_walk)
 
# Sorteia quantos ataques seguidos ele faz antes de descansar
func reset_combo() -> void:
	var menor = mini(combo_min_ataques, combo_max_ataques)
	var maior = maxi(combo_min_ataques, combo_max_ataques)
	combo_left = randi_range(maxi(menor, 1), maxi(maior, 1))
 
func start_rest() -> void:
	is_resting = true
	rest_left = rest_time
	velocity.x = 0.0
	sprite.speed_scale = 1.0
	sprite.pause()
	sprite.modulate = rest_tint
 
func end_rest() -> void:
	is_resting = false
	sprite.modulate = Color.WHITE
	reset_combo()
	attack_cd_left = 0.2
	play_anim(anim_walk, true)
 
# Sorteia qual animação de ataque usar
func escolher_animacao_ataque() -> String:
	var tem_1 = sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_attack)
	var tem_2 = sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_attack_2)
	if tem_1 and tem_2:
		return anim_attack_2 if randf() < chance_segundo_ataque else anim_attack
	if tem_2:
		return anim_attack_2
	if tem_1:
		return anim_attack
	return ""
 
func start_attack() -> void:
	is_attacking = true
	is_lunging = false
	attack_hit_done = false
	attack_token += 1
	var token = attack_token
	velocity.x = 0.0
 
	# Toca a animação de ataque sorteada desde o início
	var anim_escolhida := escolher_animacao_ataque()
	if anim_escolhida != "":
		if sincronizar_ataque:
			# duração da animação a velocidade normal = frames / fps
			var frames = sprite.sprite_frames.get_frame_count(anim_escolhida)
			var fps = sprite.sprite_frames.get_animation_speed(anim_escolhida)
			var duracao_anim = float(frames) / maxf(fps, 0.01)
			sprite.speed_scale = duracao_anim / maxf(windup_time + lunge_time, 0.01)
		else:
			sprite.speed_scale = 1.0
		sprite.play(anim_escolhida)
	else:
		sprite.pause()
 
	# Preparo
	await get_tree().create_timer(windup_time).timeout
	if is_dead or token != attack_token:
		return
 
	# Bote
	is_lunging = true
	velocity = Vector2(direction * lunge_speed, lunge_jump)
	await get_tree().create_timer(lunge_time).timeout
	is_lunging = false
	if is_dead or token != attack_token:
		return
 
	# Fim do ataque
	velocity.x = 0.0
	is_attacking = false
	attack_cd_left = attack_cooldown
	sprite.speed_scale = 1.0
 
	# Conta o ataque da sequência; acabou a sequência, descansa
	combo_left -= 1
	if combo_left <= 0:
		start_rest()
	else:
		play_anim(anim_walk, true)
 
func play_anim(nome: String, reiniciar: bool = false) -> void:
	if not sprite.sprite_frames or not sprite.sprite_frames.has_animation(nome):
		return
	if reiniciar or sprite.animation != nome or not sprite.is_playing():
		sprite.play(nome)
 
func update_facing() -> void:
	if sprite:
		sprite.flip_h = (direction < 0) if sprite_olha_para_direita else (direction > 0)
	if ledge_detector:
		ledge_detector.position.x = absf(ledge_detector.position.x) * direction
	if wall_detector:
		wall_detector.target_position.x = absf(wall_detector.target_position.x) * direction
 
func take_damage(amount: int = 1, knockback_source: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
 
	current_health -= amount
	current_health = maxi(current_health, 0)
	vida_mudou.emit(current_health, max_health)   # atualiza a barra de vida
	is_stunned = true
	is_attacking = false   # cancela o bote
	is_lunging = false
	attack_token += 1
	attack_cd_left = 0.25
	sprite.speed_scale = 1.0
 
	if knockback_source != Vector2.ZERO:
		var knockback_dir = (global_position - knockback_source).normalized()
		velocity = Vector2(knockback_dir.x * 220.0, -150.0)
	else:
		velocity = Vector2(-direction * 180.0, -120.0)
 
	if current_health <= 0:
		die()
	else:
		# Flash vermelho de impacto (depois volta ao tom certo: branco ou cansado)
		sprite.modulate = Color(2.0, 0.3, 0.3, 1.0)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", rest_tint if is_resting else Color.WHITE, 0.15)
 
		if not is_resting:
			is_chasing = true  # levou dano: passa a perseguir
			play_anim(anim_walk, true)
		await get_tree().create_timer(stun_time).timeout
		is_stunned = false
 
func die() -> void:
	is_dead = true
	morreu.emit()   # avisa a barra de vida (ela se esconde)
	is_attacking = false
	is_lunging = false
	is_resting = false
	attack_token += 1
	# a velocidade do golpe (recuo) é mantida: ele desliza e cai até o chão
	if hitbox:
		hitbox.set_deferred("monitoring", false)
 
	sprite.speed_scale = 1.0
	sprite.modulate = Color.WHITE
 
	var tem_dead = sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_dead)
	if tem_dead:
		# Toca a animação de morte e espera ela terminar + um tempo parado no último quadro
		sprite.play(anim_dead)
		var frames = sprite.sprite_frames.get_frame_count(anim_dead)
		var fps = sprite.sprite_frames.get_animation_speed(anim_dead)
		var duracao = float(frames) / maxf(fps, 0.01)
		await get_tree().create_timer(maxf(duracao, 0.1) + dead_hold_time).timeout
 
		var fade = create_tween()
		fade.tween_property(sprite, "modulate:a", 0.0, dead_fade_time)
		await fade.finished
	else:
		# Sem animação de morte: encolhe e some
		sprite.pause()
		var death_tween = create_tween().set_parallel(true)
		death_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		death_tween.tween_property(sprite, "scale:y", 0.1, 0.3)
		await death_tween.finished
 
	queue_free()
 
func check_contact_damage() -> void:
	if not hitbox or is_stunned or hit_cd_left > 0.0:
		return
	if is_resting and not dano_no_descanso:
		return
	for body in hitbox.get_overlapping_bodies():
		if try_damage(body):
			break
 
func try_damage(body: Node2D) -> bool:
	if is_dead or is_stunned or hit_cd_left > 0.0:
		return false
	if is_resting and not dano_no_descanso:
		return false
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage_amount)
		hit_cd_left = hit_cooldown
		return true
	return false
 
# Dano do golpe: confere a posição do player durante o bote,
# sem depender do tamanho da HitBox
func check_attack_hit() -> void:
	if not is_lunging or attack_hit_done or not is_instance_valid(player):
		return
	var dx = (player.global_position.x - global_position.x) * direction
	var dy = absf(player.global_position.y - global_position.y)
	# dx > -30: o player está à frente (ou quase encostado); dy: mesma altura aproximada
	if dx > -30.0 and dx <= attack_reach and dy <= attack_height:
		# Se o player está em dash ou machucado, o golpe não conta e pode tentar de novo
		if player.get("is_dashing") == true or player.get("is_hurt") == true:
			return
		if player.has_method("take_damage"):
			player.take_damage(damage_amount)
			attack_hit_done = true
			hit_cd_left = hit_cooldown
 
func _on_hitbox_body_entered(body: Node2D) -> void:
	try_damage(body)
