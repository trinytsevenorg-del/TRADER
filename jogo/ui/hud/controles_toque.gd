extends Control
class_name ControlesToque
## Controles de toque com MULTITOQUE de verdade (vários dedos ao mesmo tempo).
##
## Por que não usar Buttons comuns? Os botões de interface da Godot respondem
## a um dedo por vez (emulação de mouse). Aqui tratamos cada dedo pelo seu
## índice: um dedo no joystick, outro arrastando para mirar e outro no
## botão de atirar, tudo junto.
##
## - Metade esquerda (embaixo): joystick "flutuante" — nasce onde o dedo toca.
## - Botões: viram ações do InputMap (Input.action_press / action_release).
## - Qualquer outro toque na metade direita: arrastar = mirar.
## - Arrastar o dedo em cima do botão ATIRAR também mira (atirar e mirar juntos).

const RAIO_JOYSTICK := 105.0
const ZONA_MORTA := 0.12

## Layout dos botões. "ancora" diz de qual canto a posição é medida:
## (1,1) = canto inferior direito, (0,1) = inferior esquerdo, (1,0) = superior direito.
var botoes := [
	{"acao": "atirar", "rotulo": "ATIRAR", "ancora": Vector2(1, 1), "pos": Vector2(-265, -255), "raio": 70.0, "mira_arrastando": true},
	{"acao": "pular", "rotulo": "PULAR", "ancora": Vector2(1, 1), "pos": Vector2(-105, -125), "raio": 60.0},
	{"acao": "rolar", "rotulo": "ROLAR", "ancora": Vector2(1, 1), "pos": Vector2(-250, -92), "raio": 47.0},
	{"acao": "mirar", "rotulo": "MIRA", "ancora": Vector2(1, 1), "pos": Vector2(-105, -290), "raio": 46.0},
	{"acao": "recarregar", "rotulo": "REC", "ancora": Vector2(1, 1), "pos": Vector2(-385, -75), "raio": 38.0},
	{"acao": "trocar_arma", "rotulo": "TROCA", "ancora": Vector2(1, 1), "pos": Vector2(-400, -200), "raio": 38.0},
	# Segundo botão de atirar no lado esquerdo (estilo comum em shooters mobile).
	{"acao": "atirar", "rotulo": "ATIRAR", "ancora": Vector2(0, 1), "pos": Vector2(230, -430), "raio": 46.0, "mira_arrastando": true},
	{"acao": "pausar", "rotulo": "II", "ancora": Vector2(1, 0), "pos": Vector2(-55, 55), "raio": 32.0},
]

var _dedo_joystick := -1
var _joy_base := Vector2.ZERO
var _joy_ponta := Vector2.ZERO
var _joy_repouso := Vector2.ZERO
var _dedos_botao := {}   # índice do dedo -> índice do botão
var _dedos_olhar := {}   # índice do dedo -> última posição
var _contagem_acao := {} # ação -> quantos dedos seguram (dois botões de atirar)
var _fonte: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonte = ThemeDB.fallback_font
	_atualizar_visibilidade()
	Config.alterado.connect(func(_c, _v): _atualizar_visibilidade())
	resized.connect(_montar_layout)
	_montar_layout()


func _atualizar_visibilidade() -> void:
	visible = Config.eh_celular() or DisplayServer.is_touchscreen_available() or Config.obter("forcar_toque")
	if not visible:
		_soltar_tudo()


func _montar_layout() -> void:
	for b in botoes:
		b["centro"] = size * b["ancora"] + b["pos"]
	_joy_repouso = Vector2(200, size.y - 190)
	if _dedo_joystick == -1:
		_joy_base = _joy_repouso
		_joy_ponta = _joy_repouso
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# No PC com "forçar toque": o mouse imita um dedo (índice 0) para testar o layout.
	if not DisplayServer.is_touchscreen_available():
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_toque(0, event.position, event.pressed)
		elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_arrasto(0, event.position, event.relative)
		return
	if event is InputEventScreenTouch:
		_toque(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_arrasto(event.index, event.position, event.relative)


func _toque(dedo: int, pos: Vector2, pressionado: bool) -> void:
	if pressionado:
		if Controles.menu_aberto:
			return
		# 1) Algum botão?
		for i in botoes.size():
			var b: Dictionary = botoes[i]
			if pos.distance_to(b["centro"]) <= b["raio"] * 1.15:  # 15% de folga: dedo erra pouco
				_dedos_botao[dedo] = i
				_pressionar(b["acao"])
				if b.get("mira_arrastando", false):
					_dedos_olhar[dedo] = pos
				queue_redraw()
				return
		# 2) Joystick (canto inferior esquerdo).
		if _dedo_joystick == -1 and pos.x < size.x * 0.42 and pos.y > size.y * 0.3:
			_dedo_joystick = dedo
			_joy_base = pos
			_joy_ponta = pos
			queue_redraw()
			return
		# 3) Resto da tela à direita: mirar arrastando.
		if pos.x >= size.x * 0.35:
			_dedos_olhar[dedo] = pos
	else:
		if _dedos_botao.has(dedo):
			_soltar(botoes[_dedos_botao[dedo]]["acao"])
			_dedos_botao.erase(dedo)
			queue_redraw()
		if dedo == _dedo_joystick:
			_dedo_joystick = -1
			Controles.joystick = Vector2.ZERO
			_joy_base = _joy_repouso
			_joy_ponta = _joy_repouso
			queue_redraw()
		_dedos_olhar.erase(dedo)


func _arrasto(dedo: int, pos: Vector2, relativo: Vector2) -> void:
	if dedo == _dedo_joystick:
		var d := pos - _joy_base
		# Se o dedo passar muito do limite, a base "segue" o dedo (não perde o controle).
		if d.length() > RAIO_JOYSTICK * 1.4:
			_joy_base = pos - d.normalized() * RAIO_JOYSTICK * 1.4
			d = pos - _joy_base
		_joy_ponta = _joy_base + d.limit_length(RAIO_JOYSTICK)
		var v := d / RAIO_JOYSTICK
		var forca := v.length()
		if forca < ZONA_MORTA:
			v = Vector2.ZERO
		else:
			# Remapeia para começar em 0 logo após a zona morta (controle fino).
			v = v.normalized() * clamp((forca - ZONA_MORTA) / (1.0 - ZONA_MORTA), 0.0, 1.0)
		Controles.joystick = v
		queue_redraw()
	elif _dedos_olhar.has(dedo):
		Controles.adicionar_olhar_toque(relativo)
		_dedos_olhar[dedo] = pos


func _pressionar(acao: String) -> void:
	_contagem_acao[acao] = _contagem_acao.get(acao, 0) + 1
	if _contagem_acao[acao] == 1:
		Input.action_press(acao)


func _soltar(acao: String) -> void:
	_contagem_acao[acao] = max(0, _contagem_acao.get(acao, 0) - 1)
	if _contagem_acao[acao] == 0:
		Input.action_release(acao)


func _soltar_tudo() -> void:
	for acao in _contagem_acao:
		if _contagem_acao[acao] > 0:
			Input.action_release(acao)
	_contagem_acao.clear()
	_dedos_botao.clear()
	_dedos_olhar.clear()
	_dedo_joystick = -1
	Controles.joystick = Vector2.ZERO


func _notification(what: int) -> void:
	# App foi para segundo plano: solta tudo para não ficar "andando sozinho".
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_soltar_tudo()


func _draw() -> void:
	# Joystick
	draw_circle(_joy_base, RAIO_JOYSTICK, Color(1, 1, 1, 0.10))
	draw_arc(_joy_base, RAIO_JOYSTICK, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(_joy_ponta, 44.0, Color(1, 1, 1, 0.45 if _dedo_joystick != -1 else 0.3))
	# Botões
	var pressionados := {}
	for i in _dedos_botao.values():
		pressionados[i] = true
	for i in botoes.size():
		var b: Dictionary = botoes[i]
		var ativo := pressionados.has(i)
		var cor := Color(1, 0.35, 0.25, 0.55) if b["acao"] == "atirar" else Color(1, 1, 1, 0.22)
		if ativo:
			cor.a = 0.8
		draw_circle(b["centro"], b["raio"], cor)
		draw_arc(b["centro"], b["raio"], 0, TAU, 40, Color(1, 1, 1, 0.5), 2.0, true)
		var tam := 18 if b["raio"] > 40.0 else 14
		var largura := _fonte.get_string_size(b["rotulo"], HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		draw_string(_fonte, b["centro"] + Vector2(-largura * 0.5, tam * 0.35), b["rotulo"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(1, 1, 1, 0.9))
