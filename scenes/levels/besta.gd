extends CharacterBody2D

@export var cont: int = 0
@export var speed: float = 130.0
@export var detection_radius: float = 300.0
@export var give_up_radius: float = 450.0
@export var acceleration: float = 8.0

var player_ref: CharacterBody2D = null
var is_chasing: bool = false

# Referência do AnimatedSprite2D dentro do container Sprite2D
@onready var anim_sprite: AnimatedSprite2D = $Sprite2D/AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemies")
	_find_player()

# TESTE MANUAL DE TECLADO: Aperte ESPAÇO durante o jogo para forçar a virada
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if anim_sprite:
				anim_sprite.flip_h = not anim_sprite.flip_h
				print("TESTE FLIP: anim_sprite.flip_h agora é = ", anim_sprite.flip_h)

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0] as CharacterBody2D

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		_find_player()
		return

	var dist: float = global_position.distance_to(player_ref.global_position)

	if dist <= detection_radius:
		if not is_chasing:
			cont = 1 # Marca o início da perseguição
		is_chasing = true
	elif dist > give_up_radius:
		is_chasing = false
		cont = 0

	if is_chasing:
		var direction: Vector2 = (player_ref.global_position - global_position).normalized()
		velocity = velocity.lerp(direction * speed, acceleration * delta)
		move_and_slide()
		_update_facing_and_animation(true)
	else:
		velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		_update_facing_and_animation(false)

func _update_facing_and_animation(moving: bool) -> void:
	if not anim_sprite or not is_instance_valid(player_ref):
		return

	# LÓGICA AUTOMÁTICA (Baseada na posição real X do jogador):
	# Compara se o jogador está à direita do inimigo para aplicar o flip
	anim_sprite.flip_h = player_ref.global_position.x > global_position.x

	# Controle da animação de caminhada
	if moving:
		if not anim_sprite.is_playing():
			anim_sprite.play("walk")
	else:
		anim_sprite.stop()
