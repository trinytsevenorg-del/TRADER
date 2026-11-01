extends Node
## Camada de entrada unificada.
## Teclado/mouse (PC) e controles de toque (celular) viram as MESMAS ações do
## InputMap. Assim o personagem não precisa saber de onde veio o comando.
##
## - Botões de toque chamam Input.action_press()/action_release().
## - O joystick virtual escreve em Controles.joystick.
## - Arrastar o dedo (ou mover o mouse) acumula rotação em _olhar,
##   que a câmera consome uma vez por quadro com consumir_olhar().

## Radianos por pixel arrastado (antes da sensibilidade do jogador).
const FATOR_TOQUE := 0.0042
const FATOR_MOUSE := 0.0024

## Teclas de cada ação (para testar no PC).
const TECLAS := {
	"mover_frente": [KEY_W, KEY_UP],
	"mover_tras": [KEY_S, KEY_DOWN],
	"mover_esquerda": [KEY_A, KEY_LEFT],
	"mover_direita": [KEY_D, KEY_RIGHT],
	"pular": [KEY_SPACE],
	"rolar": [KEY_SHIFT, KEY_C],
	"recarregar": [KEY_R],
	"trocar_arma": [KEY_Q],
	"mirar": [],
	"atirar": [],
	"pausar": [KEY_ESCAPE, KEY_P],
}
const BOTOES_MOUSE := {
	"atirar": [MOUSE_BUTTON_LEFT],
	"mirar": [MOUSE_BUTTON_RIGHT],
}

## Vetor do joystick virtual (-1..1). Escrito pelo HUD de toque.
var joystick := Vector2.ZERO
## Quando um menu está aberto, o jogo ignora mira/movimento.
var menu_aberto := false:
	set(v):
		menu_aberto = v
		soltar_todas()
		_atualizar_mouse()

var _olhar := Vector2.ZERO


func _ready() -> void:
	_registrar_acoes()
	_atualizar_mouse()
	Config.alterado.connect(func(chave, _v):
		if chave == "forcar_toque":
			_atualizar_mouse())


func _registrar_acoes() -> void:
	var acoes := {}
	for a in TECLAS: acoes[a] = true
	for a in BOTOES_MOUSE: acoes[a] = true
	for acao in acoes:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao, 0.2)
		for tecla in TECLAS.get(acao, []):
			var ev := InputEventKey.new()
			ev.physical_keycode = tecla
			InputMap.action_add_event(acao, ev)
		for botao in BOTOES_MOUSE.get(acao, []):
			var evm := InputEventMouseButton.new()
			evm.button_index = botao
			InputMap.action_add_event(acao, evm)


## Usa o mouse "preso" na janela só no PC (no celular não existe cursor).
func usa_mouse() -> bool:
	return not Config.eh_celular() and not Config.obter("forcar_toque") \
		and not DisplayServer.is_touchscreen_available()


func _atualizar_mouse() -> void:
	if not usa_mouse():
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_aberto else Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if not usa_mouse() or menu_aberto:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_olhar += event.relative * FATOR_MOUSE * float(Config.obter("sens_mouse"))
	elif event is InputEventMouseButton and event.pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Chamado pelo HUD quando o dedo arrasta na área de mira (delta em pixels).
func adicionar_olhar_toque(delta_px: Vector2) -> void:
	if menu_aberto:
		return
	_olhar += delta_px * FATOR_TOQUE * float(Config.obter("sens_toque"))


## Devolve a rotação acumulada desde o último quadro (em radianos) e zera.
func consumir_olhar() -> Vector2:
	var v := _olhar
	_olhar = Vector2.ZERO
	return v


## Vetor de movimento final: o maior entre teclado e joystick virtual.
func obter_movimento() -> Vector2:
	if menu_aberto:
		return Vector2.ZERO
	var v := Input.get_vector("mover_esquerda", "mover_direita", "mover_frente", "mover_tras")
	if joystick.length_squared() > v.length_squared():
		v = joystick
	return v.limit_length(1.0)


func soltar_todas() -> void:
	joystick = Vector2.ZERO
	_olhar = Vector2.ZERO
	for acao in InputMap.get_actions():
		if Input.is_action_pressed(acao):
			Input.action_release(acao)
