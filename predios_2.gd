extends ParallaxLayer  # Este script controla uma camada de paralaxe (o prédio no fundo)

# Variáveis exportadas: aparecem no Inspector pra você configurar sem mexer no código
@export var texture_predio2: Texture2D      # Textura alternativa (prédio "aceso"/diferente) usada durante o piscar
@export var blink_interval: float = 0.5     # Tempo (em segundos) entre trocar de textura durante o piscar
@export var blink_count: int = 10           # Quantas vezes a luz pisca em cada ciclo
@export var wait_time: float = 0.5          # Tempo de espera entre um ciclo de piscadas e o próximo

# Referências a nós filhos, carregadas automaticamente quando a cena entra em execução
@onready var sprite: Sprite2D = $Sprite2D                                  # O sprite do prédio que vai trocar de textura
@onready var emergency_audio: AudioStreamPlayer = $"Area2D/Emergency"      # Player de áudio, filho do Area2D

var texture_original: Texture2D   # Guarda a textura original do prédio
var ativado: bool = false         # Controla se o alarme já foi ativado

func _ready() -> void:
	texture_original = sprite.texture   # Salva a textura original antes de qualquer piscada

func ativar() -> void:
	if ativado:
		return          # Evita ativar duas vezes
	ativado = true

	emergency_audio.play()   # Toca o som de emergência

	while true:
		await get_tree().create_timer(wait_time).timeout
		await blink()

func blink() -> void:
	for i in range(blink_count):
		if texture_predio2:
			sprite.texture = texture_predio2
		await get_tree().create_timer(blink_interval).timeout
		sprite.texture = texture_original
		await get_tree().create_timer(blink_interval).timeout
