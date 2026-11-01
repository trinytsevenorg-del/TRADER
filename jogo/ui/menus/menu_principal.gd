extends Control
## Menu principal e telas do jogo (tudo montado por código, botões grandes):
##   INÍCIO      jogar contra bots (dificuldade), multiplayer, outras telas
##   PERSONAGEM  masculino/feminino + roupas (skins) — bloqueadas saem na roleta
##   ARSENAL     armas, atributos, skins de arma (raridades) e equipamento
##   CAIXAS      abrir caixas de arma com animação de sorteio e chances
##   ROLETA      girar a roleta de prêmios com animação e chances
## A prévia 3D (personagem ou arma) fica à esquerda; as telas, à direita.

const RodaRoleta := preload("res://ui/componentes/roda_roleta.gd")
const FaixaCaixa := preload("res://ui/componentes/faixa_caixa.gd")
const MenuConfig := preload("res://ui/menus/menu_config.gd")

var _vitrine: Vitrine3D
var _area: VBoxContainer          # onde as telas aparecem
var _perfil: Label
var _barra_xp: ProgressBar
var _recursos: Label
var _config: Control
var _arma_sel := "corisco_ar"
var _dificuldade := 1


func _ready() -> void:
	Controles.menu_aberto = true
	theme = Tema.obter()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_montar_base()
	Progresso.mudou.connect(_atualizar_perfil)
	_atualizar_perfil()
	_dificuldade = Sessao.dificuldade
	tela_inicio()


# =========================================================================
#  BASE: fundo, vitrine 3D, perfil
# =========================================================================

func _montar_base() -> void:
	var fundo := TextureRect.new()
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.95, 0.62, 0.32))
	grad.set_color(1, Color(0.22, 0.32, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0.6, 1)
	fundo.texture = gt
	fundo.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(fundo)

	_vitrine = Vitrine3D.new()
	_vitrine.anchor_right = 0.48
	_vitrine.anchor_bottom = 1.0
	_vitrine.offset_top = 90
	add_child(_vitrine)

	# Barra de perfil (topo)
	var topo := PanelContainer.new()
	topo.anchor_right = 1.0
	topo.offset_left = 12
	topo.offset_right = -12
	topo.offset_top = 10
	topo.offset_bottom = 80
	add_child(topo)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 20)
	topo.add_child(linha)
	var titulo := Tema.rotulo("PROJETO TELHADO", 28, Tema.COR_DESTAQUE)
	linha.add_child(titulo)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(col)
	_perfil = Tema.rotulo("", 18)
	col.add_child(_perfil)
	_barra_xp = ProgressBar.new()
	_barra_xp.custom_minimum_size = Vector2(0, 10)
	_barra_xp.show_percentage = false
	col.add_child(_barra_xp)
	_recursos = Tema.rotulo("", 20, Color(1, 0.88, 0.45))
	linha.add_child(_recursos)
	linha.add_child(Tema.botao("CONFIG.", _abrir_config, Vector2(130, 52), 18))

	# Área das telas (direita)
	var painel := PanelContainer.new()
	painel.anchor_left = 0.5
	painel.anchor_right = 1.0
	painel.anchor_bottom = 1.0
	painel.offset_left = 0
	painel.offset_right = -12
	painel.offset_top = 92
	painel.offset_bottom = -12
	add_child(painel)
	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	painel.add_child(rolagem)
	_area = VBoxContainer.new()
	_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area.custom_minimum_size = Vector2(540, 0)
	_area.add_theme_constant_override("separation", 12)
	rolagem.add_child(_area)

	_config = MenuConfig.new()
	add_child(_config)


func _atualizar_perfil() -> void:
	var d := Progresso.dados
	_perfil.text = "%s   ·   Nível %d   ·   %d / %d XP" % [Config.obter("nome_jogador"), d.nivel, d.xp, Progresso.xp_para_proximo(d.nivel)]
	_barra_xp.max_value = Progresso.xp_para_proximo(d.nivel)
	_barra_xp.value = d.xp
	_recursos.text = "%d moedas   %d caixas   %d giros" % [d.moedas, d.caixas, d.giros]


func _abrir_config() -> void:
	_config.alternar()


func _limpar_area(titulo: String) -> void:
	for c in _area.get_children():
		c.queue_free()
	var cab := HBoxContainer.new()
	_area.add_child(cab)
	var t := Tema.rotulo(titulo, 30, Tema.COR_DESTAQUE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(t)
	if titulo != "INÍCIO":
		cab.add_child(Tema.botao("< VOLTAR", tela_inicio, Vector2(150, 52), 18))


func _mostrar_meu_personagem() -> void:
	_vitrine.mostrar_personagem(Config.obter("personagem"), Config.obter("skin"))


# =========================================================================
#  INÍCIO
# =========================================================================

func tela_inicio() -> void:
	_limpar_area("INÍCIO")
	_mostrar_meu_personagem()
	_area.add_child(Tema.rotulo("Mata-mata contra bots (5 jogadores, 20 abates ou 8 min)", 18, Tema.COR_SUAVE))
	var difs := HBoxContainer.new()
	difs.add_theme_constant_override("separation", 8)
	_area.add_child(difs)
	var grupo := ButtonGroup.new()
	for i in 3:
		var b := Button.new()
		b.text = ["FÁCIL", "MÉDIO", "DIFÍCIL"][i]
		b.toggle_mode = true
		b.button_group = grupo
		b.button_pressed = i == _dificuldade
		b.custom_minimum_size = Vector2(0, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggled.connect(func(on: bool):
			if on:
				_dificuldade = i)
		difs.add_child(b)
	var jogar := Tema.botao("JOGAR", _jogar, Vector2(0, 84), 34)
	jogar.add_theme_stylebox_override("normal", Tema._caixa(Tema.COR_DESTAQUE.darkened(0.1), 12))
	jogar.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
	_area.add_child(jogar)
	_area.add_child(Tema.botao("MULTIPLAYER (Wi-Fi com um amigo)", tela_multiplayer))
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 10)
	grade.add_theme_constant_override("v_separation", 10)
	_area.add_child(grade)
	for par in [["PERSONAGEM", tela_personagem], ["ARSENAL", tela_arsenal],
			["CAIXAS (%d)" % Progresso.dados.caixas, tela_caixas], ["ROLETA (%d)" % Progresso.dados.giros, tela_roleta]]:
		var b := Tema.botao(par[0], par[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grade.add_child(b)
	var est := Progresso.dados
	_area.add_child(Tema.rotulo("Partidas: %d   ·   Vitórias: %d   ·   Abates: %d" % [est.partidas, est.vitorias, est.abates_total], 16, Tema.COR_SUAVE))


func _jogar() -> void:
	Sessao.dificuldade = _dificuldade
	Sessao.tipo_rede = Sessao.TipoRede.SOLO
	Sessao.total_participantes = 5
	Sessao.abates_para_vencer = 20
	Sessao.duracao_segundos = 480.0
	Config.salvar()
	Controles.menu_aberto = false
	get_tree().change_scene_to_file("res://scenes/partida.tscn")


# =========================================================================
#  PERSONAGEM
# =========================================================================

func tela_personagem() -> void:
	_limpar_area("PERSONAGEM")
	_mostrar_meu_personagem()
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	_area.add_child(linha)
	for i in 2:
		var b := Tema.botao(["MASCULINO", "FEMININO"][i], func():
			Config.definir("personagem", i)
			Config.salvar()
			tela_personagem(), Vector2(0, 58))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if Config.obter("personagem") == i:
			b.add_theme_stylebox_override("normal", Tema._caixa(Tema.COR_DESTAQUE.darkened(0.35), 10))
		linha.add_child(b)
	_area.add_child(Tema.rotulo("Roupas (só visual). As bloqueadas saem na ROLETA.", 16, Tema.COR_SUAVE))
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 8)
	grade.add_theme_constant_override("v_separation", 8)
	_area.add_child(grade)
	for s in Config.NOMES_SKINS.size():
		var tem := Progresso.tem_skin_personagem(s)
		var b := Button.new()
		b.text = Config.NOMES_SKINS[s] if tem else "Bloqueada · " + Config.NOMES_SKINS[s].split(" (")[0]
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		b.disabled = not tem
		if tem and Config.obter("skin") == s:
			b.add_theme_stylebox_override("normal", Tema._caixa(Tema.COR_DESTAQUE.darkened(0.35), 10))
		b.pressed.connect(func():
			Config.definir("skin", s)
			Config.salvar()
			tela_personagem())
		b.mouse_entered.connect(func(): _vitrine.mostrar_personagem(Config.obter("personagem"), s))
		grade.add_child(b)


# =========================================================================
#  ARSENAL (inventário de armas e skins)
# =========================================================================

func tela_arsenal() -> void:
	_limpar_area("ARSENAL")
	var d := CatalogoArmas.carregar(_arma_sel)
	var skin := Progresso.skin_equipada(_arma_sel)
	_vitrine.mostrar_arma(_arma_sel, skin)

	# Lista de armas (rolagem horizontal)
	var rol := ScrollContainer.new()
	rol.custom_minimum_size = Vector2(0, 70)
	rol.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_area.add_child(rol)
	var lista := HBoxContainer.new()
	lista.add_theme_constant_override("separation", 6)
	rol.add_child(lista)
	for id in CatalogoArmas.todas():
		var a := CatalogoArmas.carregar(id)
		var b := Tema.botao(a.nome, func(): _arma_sel = id; tela_arsenal(), Vector2(150, 56), 16)
		if id == _arma_sel:
			b.add_theme_stylebox_override("normal", Tema._caixa(Tema.COR_DESTAQUE.darkened(0.35), 10))
		lista.add_child(b)

	var cat: String = ["Pistola", "Submetralhadora", "Fuzil", "Escopeta", "Metralhadora", "Sniper"][d.categoria]
	_area.add_child(Tema.rotulo("%s  ·  %s  ·  %s" % [d.nome, cat, ["Semiautomática", "Rajada", "Automática"][d.modo]], 22))
	var desc := Tema.rotulo(d.descricao, 16, Tema.COR_SUAVE)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_area.add_child(desc)
	# Atributos normalizados (0-1) só para comparar armas
	var dps: float = d.dano * d.projeteis * d.cadencia / 60.0
	var stats := [
		["Dano", clampf(d.dano * d.projeteis / 100.0, 0, 1)],
		["Cadência", clampf(d.cadencia / 1000.0, 0, 1)],
		["Dano/seg", clampf(dps / 400.0, 0, 1)],
		["Alcance", clampf(d.alcance_efetivo / 120.0, 0, 1)],
		["Precisão", clampf(1.0 - d.dispersao_base / 7.0, 0, 1)],
		["Controle", clampf(1.0 - d.recuo_vertical / 7.0, 0, 1)],
		["Mobilidade", clampf((d.mult_velocidade - 0.8) / 0.3, 0, 1)],
	]
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	_area.add_child(g)
	for st in stats:
		var l := Tema.rotulo(st[0], 16)
		l.custom_minimum_size = Vector2(110, 0)
		g.add_child(l)
		var barra := ProgressBar.new()
		barra.max_value = 1.0
		barra.value = st[1]
		barra.show_percentage = false
		barra.custom_minimum_size = Vector2(0, 14)
		barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		g.add_child(barra)
	_area.add_child(Tema.rotulo("Pente %d · Recarga %.1f s · Zoom %s" % [d.pente, d.tempo_recarga, ("%.1fx" % d.zoom) if d.zoom > 1.0 else "não"], 16, Tema.COR_SUAVE))

	# Equipar como principal/secundária
	var principal := d.categoria != DadosArma.Categoria.PISTOLA
	var chave := "arma_principal" if principal else "arma_secundaria"
	var ja: bool = Config.obter(chave) == _arma_sel
	var eq := Tema.botao("EQUIPADA (%s)" % ("principal" if principal else "secundária") if ja else "EQUIPAR COMO %s" % ("PRINCIPAL" if principal else "SECUNDÁRIA"),
		func():
			Config.definir(chave, _arma_sel)
			Config.salvar()
			tela_arsenal(), Vector2(0, 56), 20)
	eq.disabled = ja
	_area.add_child(eq)

	# Skins desta arma
	_area.add_child(Tema.rotulo("Skins (só visual)", 20, Tema.COR_DESTAQUE))
	var gs := GridContainer.new()
	gs.columns = 3
	gs.add_theme_constant_override("h_separation", 8)
	gs.add_theme_constant_override("v_separation", 8)
	_area.add_child(gs)
	var padrao_b := Tema.botao("Padrão", func(): Progresso.equipar_skin_arma(_arma_sel, ""); tela_arsenal(), Vector2(0, 64), 16)
	padrao_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gs.add_child(padrao_b)
	for s in CatalogoSkins.da_arma(_arma_sel):
		var tem := Progresso.tem_skin_arma(s.id)
		var equipada: bool = skin != null and skin.id == s.id
		var b := Button.new()
		b.text = "%s\n%s%s" % [s.nome, DadosSkinArma.nome_raridade(s.raridade), "" if tem else " · bloqueada"]
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_stylebox_override("normal", Tema.caixa_raridade(s.raridade, equipada))
		b.add_theme_stylebox_override("disabled", Tema.caixa_raridade(s.raridade, false))
		b.disabled = not tem
		b.mouse_entered.connect(func(): _vitrine.mostrar_arma(_arma_sel, s))
		b.pressed.connect(func():
			Progresso.equipar_skin_arma(_arma_sel, s.id)
			tela_arsenal())
		gs.add_child(b)


# =========================================================================
#  CAIXAS
# =========================================================================

func tela_caixas() -> void:
	_limpar_area("CAIXAS DE ARMA")
	_mostrar_meu_personagem()
	_area.add_child(Tema.rotulo("Você tem %d caixa(s). Cada caixa dá uma skin de arma." % Progresso.dados.caixas, 18))
	var chances := ""
	for r in Progresso.CHANCES_CAIXA:
		chances += "%s %.0f%%    " % [DadosSkinArma.nome_raridade(r), Progresso.CHANCES_CAIXA[r]]
	_area.add_child(Tema.rotulo("Chances: " + chances, 17, Color(1, 0.9, 0.6)))
	_area.add_child(Tema.rotulo("Repetida vira moedas: comum 40 · rara 120 · épica 350 · lendária 1000", 15, Tema.COR_SUAVE))
	var faixa: Control = FaixaCaixa.new()
	faixa.custom_minimum_size = Vector2(0, 150)
	_area.add_child(faixa)
	var resultado := Tema.rotulo("", 22)
	resultado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resultado.autowrap_mode = TextServer.AUTOWRAP_WORD
	_area.add_child(resultado)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	_area.add_child(linha)
	var abrir := Tema.botao("ABRIR CAIXA", func(): pass, Vector2(0, 70), 26)
	abrir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abrir.disabled = Progresso.dados.caixas <= 0
	linha.add_child(abrir)
	var comprar := Tema.botao("COMPRAR (%d moedas)" % Progresso.PRECO_CAIXA, func():
		if Progresso.comprar_caixa():
			tela_caixas(), Vector2(0, 70), 18)
	comprar.disabled = Progresso.dados.moedas < Progresso.PRECO_CAIXA
	linha.add_child(comprar)
	abrir.pressed.connect(func():
		abrir.disabled = true
		comprar.disabled = true
		var r := Progresso.abrir_caixa()
		if r.is_empty():
			return
		await faixa.sortear(r.skin)
		var s: DadosSkinArma = r.skin
		var arma := CatalogoArmas.carregar(s.arma)
		resultado.text = "%s  ·  %s (%s)" % [DadosSkinArma.nome_raridade(s.raridade).to_upper(), s.nome, arma.nome]
		if r.repetida:
			resultado.text += "\nRepetida: +%d moedas" % r.moedas
		resultado.add_theme_color_override("font_color", DadosSkinArma.cor_raridade(s.raridade))
		_vitrine.mostrar_arma(s.arma, s)
		abrir.disabled = Progresso.dados.caixas <= 0
		comprar.disabled = Progresso.dados.moedas < Progresso.PRECO_CAIXA)


# =========================================================================
#  ROLETA
# =========================================================================

func tela_roleta() -> void:
	_limpar_area("ROLETA")
	_mostrar_meu_personagem()
	var giros := Tema.rotulo("", 17)
	var atualizar_giros := func(): giros.text = "Giros: %d  (ganhe jogando: subir de nível e a cada 10 abates)" % Progresso.dados.giros
	atualizar_giros.call()
	_area.add_child(giros)
	var roda: Control = RodaRoleta.new()
	roda.custom_minimum_size = Vector2(0, 330)
	_area.add_child(roda)
	var resultado := Tema.rotulo("", 24)
	resultado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_area.add_child(resultado)
	var girar := Tema.botao("GIRAR", func(): pass, Vector2(0, 70), 28)
	girar.disabled = Progresso.dados.giros <= 0
	_area.add_child(girar)
	var chances := ""
	for p in Progresso.ROLETA:
		chances += "%s %.0f%%   " % [p.texto, p.peso]
	var lc := Tema.rotulo("Chances: " + chances, 15, Color(1, 0.9, 0.6))
	lc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_area.add_child(lc)
	girar.pressed.connect(func():
		girar.disabled = true
		var r := Progresso.girar_roleta()
		if r.is_empty():
			return
		atualizar_giros.call()
		await roda.girar_para(r.indice)
		var txt: String = "Você ganhou: " + r.premio.texto
		var ex: Dictionary = r.extra
		if ex.has("skin_personagem"):
			txt += " (%s)" % Config.NOMES_SKINS[ex.skin_personagem]
		if ex.has("convertido"):
			txt += " (já tinha todas: +%d moedas)" % ex.convertido
		if ex.has("caixa") and not ex.caixa.is_empty():
			txt += " (%s)" % ex.caixa.skin.nome
			_vitrine.mostrar_arma(ex.caixa.skin.arma, ex.caixa.skin)
		if ex.get("niveis", 0) > 0:
			txt += "  ·  subiu de nível!"
		resultado.text = txt
		resultado.add_theme_color_override("font_color", r.premio.cor.lightened(0.3))
		girar.disabled = Progresso.dados.giros <= 0)


# =========================================================================
#  MULTIPLAYER (etapa 8)
# =========================================================================

func tela_multiplayer() -> void:
	_limpar_area("MULTIPLAYER")
	_mostrar_meu_personagem()
	if Rede.has_method("montar_tela"):
		Rede.montar_tela(_area, self)
	else:
		_area.add_child(Tema.rotulo("Em breve.", 20))
