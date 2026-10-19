extends ProgressBar

# Arraste o boss aqui no Inspector. Se deixar vazio, a barra procura no grupo "boss".
@export var boss: Node2D
@export var tempo_animacao: float = 0.2     # velocidade da barra descendo ao levar dano
@export var tempo_escondida: float = 9.0    # segundos escondida quando a fase começa
@export var tempo_encher: float = 1.7       # quanto a barra leva para encher ao aparecer

var tween: Tween
var boss_morto: bool = false

func _ready() -> void:
	# Começa escondida
	visible = false

	# Liga no boss (arrastado no Inspector ou pelo grupo "boss")
	if boss == null:
		await get_tree().process_frame
		boss = get_tree().get_first_node_in_group("boss") as Node2D

	if boss != null:
		boss.vida_mudou.connect(_on_vida_mudou)
		boss.morreu.connect(_on_boss_morreu)
		max_value = boss.max_health
		value = 0
	else:
		push_warning("Barra de vida sem boss: arraste o boss no Inspector ou adicione-o ao grupo 'boss'.")

	# Fica escondida pelo tempo definido e depois aparece
	await get_tree().create_timer(tempo_escondida).timeout
	if boss_morto:
		return
	visible = true

	# Enche a barra ao aparecer
	if boss != null:
		if tween:
			tween.kill()
		tween = create_tween()
		tween.tween_property(self, "value", boss.current_health, tempo_encher)

func _on_vida_mudou(atual: int, maximo: int) -> void:
	max_value = maximo
	# animação suave da barra descendo
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "value", atual, tempo_animacao)

func _on_boss_morreu() -> void:
	boss_morto = true
	visible = false
