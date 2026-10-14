extends Node

func _ready() -> void:
	print("Controles: ", Input.get_connected_joypads())
	for id in Input.get_connected_joypads():
		print(id, " -> ", Input.get_joy_name(id))

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		print("BOTÃO: ", event.button_index)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		print("EIXO: ", event.axis, " valor: ", event.axis_value)
