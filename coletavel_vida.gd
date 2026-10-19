extends Area2D

@export var cura: int = 150                          # quanto de vida recupera
@export var ignorar_se_vida_cheia: bool = true      # true = não pega se o player já está com a vida cheia
@export var flutuar: bool = true                    # sobe e desce parado no ar
@export var altura_flutuar: float = 6.0
@export var raio_coleta: float = 70.0               # também coleta se o player chegar a esta distância (não depende de colisão)
@export var debug: bool = true                      # mostra mensagens no painel Output (desligue depois)

var coletado: bool = false
var player: Node2D

func _ready() -> void:
	# Detecta corpos de qualquer camada (quem decide é o grupo "player")
	collision_mask = 0xFFFFFFFF
	monitoring = true
	body_entered.connect(_on_body_entered)

	if debug:
		var tem_forma := false
		for filho in get_children():
			if filho is CollisionShape2D and filho.shape != null:
				tem_forma = true
		print("[Coletável] pronto | tem CollisionShape2D com forma: ", tem_forma)

	if flutuar:
		var base_y := position.y
		var tween := create_tween().set_loops()
		tween.tween_property(self, "position:y", base_y - altura_flutuar, 0.6).set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "position:y", base_y + altura_flutuar, 0.6).set_trans(Tween.TRANS_SINE)

func _physics_process(_delta: float) -> void:
	if coletado:
		return

	# 1) quem já está dentro da área
	for body in get_overlapping_bodies():
		tentar_coletar(body)

	# 2) plano B: distância até o player (funciona mesmo se a colisão falhar)
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= raio_coleta:
		tentar_coletar(player)

func _on_body_entered(body: Node2D) -> void:
	if debug:
		print("[Coletável] entrou: ", body.name, " | grupos: ", body.get_groups())
	tentar_coletar(body)

func tentar_coletar(body: Node2D) -> void:
	if coletado or not body.is_in_group("player"):
		return
	if not body.has_method("curar"):
		push_warning("O player não tem a função curar(): use o player.gd atualizado.")
		return

	# curar() devolve false quando a vida já estava cheia
	var curou: bool = body.curar(cura)
	if debug:
		print("[Coletável] curar(", cura, ") devolveu: ", curou)
	if not curou and ignorar_se_vida_cheia:
		return

	coletar()

func coletar() -> void:
	coletado = true
	set_deferred("monitoring", false)

	# efeito de coleta: cresce um pouco e some
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_property(self, "scale", scale * 1.4, 0.25)
	tween.chain().tween_callback(queue_free)
