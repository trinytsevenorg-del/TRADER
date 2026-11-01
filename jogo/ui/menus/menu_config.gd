extends Control
## Menu de configurações (abre com o botão II no celular ou ESC no PC).
## Montado por código para ficar fácil adicionar opções:
## basta chamar _slider(...) ou _checkbox(...) em _montar().

var _caixa: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pausar"):
		var hud := get_tree().get_first_node_in_group("controles_toque")
		if hud and hud.editando:
			return
		alternar()


func alternar() -> void:
	visible = not visible
	# No menu principal o jogo não está rodando: não mexe no estado dos controles.
	if not get_tree().current_scene is Control:
		Controles.menu_aberto = visible
	if not visible:
		Config.salvar()


func _personalizar_hud() -> void:
	alternar()  # fecha o menu
	var hud := get_tree().get_first_node_in_group("controles_toque")
	if hud:
		hud.iniciar_edicao()


func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.55)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var painel := PanelContainer.new()
	painel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	painel.custom_minimum_size = Vector2(620, 0)
	painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	painel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(painel)

	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size = Vector2(600, 560)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	painel.add_child(rolagem)

	_caixa = VBoxContainer.new()
	_caixa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caixa.add_theme_constant_override("separation", 14)
	rolagem.add_child(_caixa)

	var titulo := Label.new()
	titulo.text = "CONFIGURAÇÕES"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 30)
	_caixa.add_child(titulo)

	_opcoes("Personagem", "personagem", ["Masculino", "Feminino"])
	_opcoes("Skin", "skin", Config.NOMES_SKINS)
	_opcoes_id("Arma principal", "arma_principal", CatalogoArmas.PRINCIPAIS)
	_opcoes_id("Arma secundária", "arma_secundaria", CatalogoArmas.SECUNDARIAS)
	_slider("Volume", "volume", 0.0, 1.0, 0.05)
	_slider("Sensibilidade (toque)", "sens_toque", 0.2, 3.0, 0.05)
	_slider("Sensibilidade (mouse)", "sens_mouse", 0.2, 3.0, 0.05)
	_slider("Sensibilidade mirando / luneta", "sens_mira", 0.2, 1.5, 0.05)
	_slider("Aim assist (0 = desligado)", "aim_assist", 0.0, 1.0, 0.05)
	_checkbox("Tiro automático (atira ao mirar no inimigo)", "tiro_automatico")
	_checkbox("Inverter eixo Y", "inverter_y")
	_checkbox("Mostrar FPS", "mostrar_fps")
	_checkbox("Forçar controles de toque (testar no PC)", "forcar_toque")
	_opcoes("Qualidade gráfica", "qualidade", ["Baixa (mais FPS)", "Média", "Alta"])

	var hud := Button.new()
	hud.text = "PERSONALIZAR BOTÕES"
	hud.custom_minimum_size = Vector2(0, 60)
	hud.add_theme_font_size_override("font_size", 22)
	hud.pressed.connect(_personalizar_hud)
	_caixa.add_child(hud)

	var voltar := Button.new()
	voltar.text = "VOLTAR AO JOGO"
	voltar.custom_minimum_size = Vector2(0, 64)
	voltar.add_theme_font_size_override("font_size", 24)
	voltar.pressed.connect(alternar)
	_caixa.add_child(voltar)


func _rotulo(texto: String) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 22)
	_caixa.add_child(l)
	return l


func _slider(texto: String, chave: String, minimo: float, maximo: float, passo: float) -> void:
	var l := _rotulo("")
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = passo
	s.value = Config.obter(chave)
	s.custom_minimum_size = Vector2(0, 44)  # alto o bastante para o dedo
	var atualizar := func(v: float):
		l.text = "%s: %.2f" % [texto, v]
		Config.definir(chave, v)
	s.value_changed.connect(atualizar)
	atualizar.call(s.value)
	_caixa.add_child(s)


func _checkbox(texto: String, chave: String) -> void:
	var c := CheckButton.new()
	c.text = texto
	c.button_pressed = Config.obter(chave)
	c.add_theme_font_size_override("font_size", 22)
	c.custom_minimum_size = Vector2(0, 48)
	c.toggled.connect(func(v: bool): Config.definir(chave, v))
	_caixa.add_child(c)


func _opcoes(texto: String, chave: String, itens: Array) -> void:
	_rotulo(texto)
	var o := OptionButton.new()
	for item in itens:
		o.add_item(item)
	o.selected = Config.obter(chave)
	o.custom_minimum_size = Vector2(0, 52)
	o.add_theme_font_size_override("font_size", 22)
	o.item_selected.connect(func(i: int): Config.definir(chave, i))
	_caixa.add_child(o)


## Lista de opções em que o valor salvo é um id (texto), não o índice.
func _opcoes_id(texto: String, chave: String, ids: Array) -> void:
	_rotulo(texto)
	var o := OptionButton.new()
	for n in CatalogoArmas.nomes(ids):
		o.add_item(n)
	o.selected = max(ids.find(Config.obter(chave)), 0)
	o.custom_minimum_size = Vector2(0, 52)
	o.add_theme_font_size_override("font_size", 22)
	o.item_selected.connect(func(i: int): Config.definir(chave, ids[i]))
	_caixa.add_child(o)
