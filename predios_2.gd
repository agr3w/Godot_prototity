extends ParallaxLayer

@export var texture_predio2: Texture2D
@export var blink_interval: float = 0.5   # tempo entre cada troca
@export var blink_count: int = 10          # quantas vezes vai piscar
@export var wait_time: float = 3.0       # intervalo entre cada ciclo de piscadas

@onready var sprite: Sprite2D = $Sprite2D
var texture_original: Texture2D

func _ready() -> void:
	texture_original = sprite.texture
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
