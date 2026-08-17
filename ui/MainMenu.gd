extends Control

@onready var painel_configs = $PainelConfigs
@onready var slider_volume = $PainelConfigs/MarginContainer/VBoxContainer/HSlider
@onready var btn_janela = $PainelConfigs/MarginContainer/VBoxContainer/Tela/HBoxContainer2/BtnJanela
@onready var btn_tela_cheia = $PainelConfigs/MarginContainer/VBoxContainer/Tela/HBoxContainer2/BtnTelaCheia

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	painel_configs.hide()
	_sync_window_mode_buttons()

func _on_btn_novo_jogo_pressed():
	get_tree().change_scene_to_file("res://scenes/levels/World.tscn")

func _on_btn_configs_pressed():
	painel_configs.show()

func _on_btn_sair_pressed():
	get_tree().quit()

func _on_btn_fechar_pressed():
	painel_configs.hide()

func _on_h_slider_value_changed(value):
	var volume_linear = value / 100.0
	var bus_index = AudioServer.get_bus_index("Master")

	if volume_linear == 0:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(volume_linear))

func _on_btn_tela_cheia_pressed():
	btn_tela_cheia.button_pressed = true
	btn_janela.button_pressed = false

	if OS.is_debug_build() and not OS.has_feature("template"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_btn_janela_pressed():
	btn_janela.button_pressed = true
	btn_tela_cheia.button_pressed = false

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _sync_window_mode_buttons():
	var modo_atual = DisplayServer.window_get_mode()
	btn_tela_cheia.button_pressed = modo_atual == DisplayServer.WINDOW_MODE_FULLSCREEN or modo_atual == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	btn_janela.button_pressed = not btn_tela_cheia.button_pressed
