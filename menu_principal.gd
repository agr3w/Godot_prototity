extends Control

# Referência para a tela de configurações (que faremos a seguir)
# @onready var tela_configs = $ConfiguracoesPanel 

func _ready():
    # Garante que o mouse esteja visível no menu
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_btn_novo_jogo_pressed():
    get_tree().change_scene_to_file("res://character_body_2d.tscn")

func _on_btn_configs_pressed():
    print("Abrir painel de configurações")

func _on_btn_sair_pressed():
    get_tree().quit()