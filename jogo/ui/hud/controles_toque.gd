extends Control
class_name ControlesToque
## Controles de toque com MULTITOQUE de verdade e layout PERSONALIZÁVEL.
##
## Por que não usar Buttons comuns? Os botões de interface da Godot respondem
## a um dedo por vez (emulação de mouse). Aqui tratamos cada dedo pelo seu
## índice: um dedo no joystick, outro arrastando para mirar e outro no
## botão de atirar, tudo junto.
##
## - Lado esquerdo (embaixo): joystick "flutuante": nasce onde o dedo toca.
## - Botões: viram ações do InputMap (Input.action_press / action_release).
## - Qualquer outro toque no lado direito: arrastar = mirar.
## - Arrastar o dedo em cima do botão ATIRAR também mira (atirar e mirar juntos).
##
## PERSONALIZAR: Configurações > "Personalizar botões". Arraste cada botão,
## use - / + para o tamanho do botão selecionado e "Concluir" para salvar.
## O layout fica salvo em Config "hud" (posição em fração da tela + raio).

const RAIO_JOYSTICK := 105.0
const ZONA_MORTA := 0.12
const RAIO_MIN := 26.0
const RAIO_MAX := 120.0

## Layout PADRÃO. "pos" = fração da tela (0..1), "raio" em pixels (tela base 1280x720).
const PADRAO := {
	"atirar":      {"acao": "atirar", "rotulo": "ATIRAR", "pos": Vector2(0.085, 0.25), "raio": 72.0, "mira_arrastando": true},
	"atirar_dir":  {"acao": "atirar", "rotulo": "ATIRAR", "pos": Vector2(0.80, 0.45), "raio": 50.0, "mira_arrastando": true},
	"pular":       {"acao": "pular", "rotulo": "PULAR", "pos": Vector2(0.82, 0.78), "raio": 78.0},
	"rolar":       {"acao": "rolar", "rotulo": "ROLAR", "pos": Vector2(0.66, 0.84), "raio": 48.0},
	"deslizar":    {"acao": "deslizar", "rotulo": "DESLIZ.", "pos": Vector2(0.70, 0.60), "raio": 44.0},
	"mirar":       {"acao": "mirar", "rotulo": "MIRA", "pos": Vector2(0.93, 0.50), "raio": 42.0},
	"recarregar":  {"acao": "recarregar", "rotulo": "REC", "pos": Vector2(0.94, 0.93), "raio": 36.0},
	"trocar_arma": {"acao": "trocar_arma", "rotulo": "TROCA", "pos": Vector2(0.45, 0.92), "raio": 36.0},
	"pausar":      {"acao": "pausar", "rotulo": "II", "pos": Vector2(0.96, 0.08), "raio": 30.0},
	"placar":      {"acao": "placar", "rotulo": "PLACAR", "pos": Vector2(0.89, 0.08), "raio": 28.0},
}

var botoes := {}          # id -> {acao, rotulo, pos (fração), raio, centro (px)}
var editando := false

var _dedo_joystick := -1
var _joy_base := Vector2.ZERO
var _joy_ponta := Vector2.ZERO
var _joy_repouso := Vector2.ZERO
var _dedos_botao := {}   # índice do dedo -> id do botão
var _dedos_olhar := {}   # índice do dedo -> última posição
var _contagem_acao := {} # ação -> quantos dedos seguram (dois botões de atirar)
var _fonte: Font

# Edição
var _selecionado := ""
var _arrastando := {}    # dedo -> deslocamento entre dedo e centro do botão
var _painel_edicao: PanelContainer


func _ready() -> void:
	add_to_group("controles_toque")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonte = ThemeDB.fallback_font
	_carregar_layout()
	_criar_painel_edicao()
	_atualizar_visibilidade()
	Config.alterado.connect(func(_c, _v): _atualizar_visibilidade())
	resized.connect(_montar_layout)
	_montar_layout()


func _atualizar_visibilidade() -> void:
	visible = editando or Config.eh_celular() or DisplayServer.is_touchscreen_available() \
		or Config.obter("forcar_toque")
	if not visible:
		_soltar_tudo()


# ---------------------------------------------------------------- layout

func _carregar_layout() -> void:
	botoes.clear()
	var salvo: Dictionary = Config.obter("hud")
	for id in PADRAO:
		var b: Dictionary = PADRAO[id].duplicate()
		if salvo.has(id):
			var v: Array = salvo[id]
			b["pos"] = Vector2(v[0], v[1])
			b["raio"] = float(v[2])
		botoes[id] = b


func _salvar_layout() -> void:
	var dados := {}
	for id in botoes:
		var b: Dictionary = botoes[id]
		dados[id] = [b["pos"].x, b["pos"].y, b["raio"]]
	Config.definir("hud", dados)
	Config.salvar()


func _montar_layout() -> void:
	for id in botoes:
		var b: Dictionary = botoes[id]
		b["centro"] = size * b["pos"]
	_joy_repouso = Vector2(size.x * 0.16, size.y - 190)
	if _dedo_joystick == -1:
		_joy_base = _joy_repouso
		_joy_ponta = _joy_repouso
	queue_redraw()


# ---------------------------------------------------------------- entrada

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# No PC sem tela de toque: o mouse imita um dedo (índice 0).
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


func _botao_em(pos: Vector2) -> String:
	var melhor := ""
	var melhor_d := INF
	for id in botoes:
		var b: Dictionary = botoes[id]
		var d: float = pos.distance_to(b["centro"])
		if d <= b["raio"] * 1.15 and d < melhor_d:  # 15% de folga: dedo erra pouco
			melhor = id
			melhor_d = d
	return melhor


func _toque(dedo: int, pos: Vector2, pressionado: bool) -> void:
	if editando:
		_toque_edicao(dedo, pos, pressionado)
		return
	if pressionado:
		if Controles.menu_aberto:
			return
		# 1) Algum botão?
		var id := _botao_em(pos)
		if id != "":
			var b: Dictionary = botoes[id]
			_dedos_botao[dedo] = id
			_pressionar(b["acao"])
			if b.get("mira_arrastando", false):
				_dedos_olhar[dedo] = pos
			queue_redraw()
			return
		# 2) Joystick (lado esquerdo, parte de baixo).
		if _dedo_joystick == -1 and pos.x < size.x * 0.42 and pos.y > size.y * 0.35:
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
	if editando:
		if _arrastando.has(dedo):
			var b: Dictionary = botoes[_selecionado]
			var c: Vector2 = (pos + _arrastando[dedo]).clamp(Vector2(b["raio"], b["raio"]), size - Vector2(b["raio"], b["raio"]))
			b["centro"] = c
			b["pos"] = c / size
			queue_redraw()
		return
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


# ---------------------------------------------------------------- edição do HUD

func iniciar_edicao() -> void:
	_soltar_tudo()
	editando = true
	_selecionado = ""
	Controles.menu_aberto = true  # o jogo não reage enquanto edita
	_painel_edicao.visible = true
	_atualizar_visibilidade()
	queue_redraw()


func _concluir_edicao() -> void:
	_salvar_layout()
	editando = false
	_arrastando.clear()
	_painel_edicao.visible = false
	Controles.menu_aberto = false
	_atualizar_visibilidade()
	queue_redraw()


func _toque_edicao(dedo: int, pos: Vector2, pressionado: bool) -> void:
	if _painel_edicao.get_global_rect().has_point(pos):
		return  # toque nos botões do painel (tratados pela interface normal)
	if pressionado:
		var id := _botao_em(pos)
		if id != "":
			_selecionado = id
			_arrastando[dedo] = botoes[id]["centro"] - pos
		queue_redraw()
	else:
		_arrastando.erase(dedo)


func _mudar_tamanho(delta_raio: float) -> void:
	if _selecionado == "":
		return
	var b: Dictionary = botoes[_selecionado]
	b["raio"] = clamp(b["raio"] + delta_raio, RAIO_MIN, RAIO_MAX)
	queue_redraw()


func _restaurar_padrao() -> void:
	Config.definir("hud", {})
	_carregar_layout()
	_montar_layout()


func _criar_painel_edicao() -> void:
	_painel_edicao = PanelContainer.new()
	_painel_edicao.visible = false
	_painel_edicao.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_painel_edicao.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_painel_edicao.position.y = 8
	add_child(_painel_edicao)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	_painel_edicao.add_child(linha)
	var dica := Label.new()
	dica.text = " Arraste os botões "
	dica.add_theme_font_size_override("font_size", 20)
	linha.add_child(dica)
	for item in [["  −  ", func(): _mudar_tamanho(-6.0)], ["  +  ", func(): _mudar_tamanho(6.0)],
			["Padrão", _restaurar_padrao], ["Concluir", _concluir_edicao]]:
		var bt := Button.new()
		bt.text = item[0]
		bt.custom_minimum_size = Vector2(80, 56)
		bt.add_theme_font_size_override("font_size", 22)
		bt.pressed.connect(item[1])
		linha.add_child(bt)


# ---------------------------------------------------------------- desenho

func _draw() -> void:
	if editando:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		# Área do joystick
		draw_rect(Rect2(Vector2(0, size.y * 0.35), Vector2(size.x * 0.42, size.y * 0.65)), Color(1, 1, 1, 0.06))
		draw_string(_fonte, Vector2(20, size.y - 20), "área do joystick", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.5))
	# Joystick
	draw_circle(_joy_base, RAIO_JOYSTICK, Color(1, 1, 1, 0.10))
	draw_arc(_joy_base, RAIO_JOYSTICK, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(_joy_ponta, 44.0, Color(1, 1, 1, 0.45 if _dedo_joystick != -1 else 0.3))
	# Botões
	var pressionados := {}
	for id in _dedos_botao.values():
		pressionados[id] = true
	for id in botoes:
		var b: Dictionary = botoes[id]
		var ativo := pressionados.has(id)
		var cor := Color(1, 0.35, 0.25, 0.55) if b["acao"] == "atirar" else Color(1, 1, 1, 0.22)
		if ativo:
			cor.a = 0.8
		draw_circle(b["centro"], b["raio"], cor)
		var cor_borda := Color(1, 0.85, 0.2, 1) if editando and id == _selecionado else Color(1, 1, 1, 0.5)
		draw_arc(b["centro"], b["raio"], 0, TAU, 40, cor_borda, 4.0 if id == _selecionado and editando else 2.0, true)
		var tam := int(clamp(b["raio"] * 0.3, 12, 24))
		var largura := _fonte.get_string_size(b["rotulo"], HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		draw_string(_fonte, b["centro"] + Vector2(-largura * 0.5, tam * 0.35), b["rotulo"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(1, 1, 1, 0.9))
