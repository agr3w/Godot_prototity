extends ParallaxLayer  # Este script controla uma camada de paralaxe (o prédio no fundo)

# Variáveis exportadas: aparecem no Inspector pra você configurar sem mexer no código
@export var texture_predio2: Texture2D      # Textura alternativa (prédio "aceso"/diferente) usada durante o piscar
@export var blink_interval: float = 0.5     # Tempo entre trocar de textura durante o piscar
@export var blink_count: int = 10           # Quantas vezes a luz pisca em cada ciclo
@export var wait_time: float = 0.5          # Tempo de espera entre um ciclo de piscadas e o próximo
@export var label_duration: float = 5.0     # Quanto tempo o texto "EMERGENCY" fica visível na tela

# Caminho pro Label na tela — você vai arrastar o nó "TextoEmergency" no Inspector
@export var emergency_label_path: NodePath

# Referências a nós filhos, carregadas automaticamente quando a cena entra em execução
@onready var sprite: Sprite2D = $Sprite2D                                  # Sprite do prédio
@onready var emergency_audio: AudioStreamPlayer = $"Area2D/Emergency"      # Player de áudio
@onready var emergency_label: Label = get_node(emergency_label_path)       # Referência ao texto "EMERGENCY" na tela

var texture_original: Texture2D   # Guarda a textura original do prédio
var ativado: bool = false         # Controla se o alarme já foi ativado

func _ready() -> void:
	texture_original = sprite.texture   # Salva a textura original antes de qualquer piscada
	emergency_label.visible = false     # Garante que o texto começa escondido

func ativar() -> void:
	if ativado:
		return          # Evita ativar o alarme duas vezes
	ativado = true

	emergency_audio.play()          # Toca o som de emergência
	emergency_label.visible = true  # Mostra o texto "EMERGENCY" na tela

	esconder_texto_depois_de(label_duration)   # Agenda o texto pra sumir depois de X segundos, sem travar o resto

	while true:
		await get_tree().create_timer(wait_time).timeout
		await blink()

func esconder_texto_depois_de(tempo: float) -> void:
	await get_tree().create_timer(tempo).timeout   # Espera o tempo definido (5 segundos por padrão)
	emergency_label.visible = false                # Esconde o texto depois de esperar

func blink() -> void:
	for i in range(blink_count):
		if texture_predio2:
			sprite.texture = texture_predio2
		await get_tree().create_timer(blink_interval).timeout
		sprite.texture = texture_original
		await get_tree().create_timer(blink_interval).timeout
