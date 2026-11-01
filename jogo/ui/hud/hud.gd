extends CanvasLayer
## Raiz do HUD. Na partida, a cena Partida chama configurar(jogador, modo).
## (Nas cenas de teste antigas, os filhos acham o jogador pelo caminho "../../Jogador".)

const HudPartida := preload("res://ui/hud/hud_partida.gd")

var hud_partida: Control


func configurar(jogador: Jogador, modo: ModoMataMata) -> void:
	$HudArmas.definir_jogador(jogador)
	$PainelDebug.definir_jogador(jogador)
	hud_partida = HudPartida.new()
	hud_partida.name = "HudPartida"
	add_child(hud_partida)
	move_child(hud_partida, 1)  # abaixo dos controles de toque e do menu
	hud_partida.configurar(jogador, modo)


func mostrar_fim(resultado: Dictionary) -> void:
	$ControlesToque.visible = false
	hud_partida.mostrar_fim(resultado)
