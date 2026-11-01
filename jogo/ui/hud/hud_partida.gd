extends Control
## HUD da partida mata-mata (desenhado por código = leve):
##  - topo: tempo restante e placar (você x líder, meta de abates)
##  - feed de abates (canto direito)
##  - barra de vida e indicador de direção do dano (arcos vermelhos)
##  - borda vermelha com pouca vida
##  - tela "ELIMINADO" com contagem para renascer
##  - placar completo (segurar PLACAR / Tab)
##  - tela de fim de partida

var _jogador: Jogador
var _modo: ModoMataMata
var _fonte: Font
var _feed: Array = []         # [{texto, tempo}]
var _danos: Array = []        # [{angulo_mundo, tempo}]
var _morto_por := ""
var _tempo_morto := 0.0
var _fim: Control


func configurar(jogador: Jogador, modo: ModoMataMata) -> void:
	_jogador = jogador
	_modo = modo
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonte = ThemeDB.fallback_font
	modo.abate.connect(_ao_abate)
	if jogador:
		jogador.saude.dano_recebido.connect(_ao_dano)
		jogador.morreu.connect(func(atacante):
			_morto_por = atacante.nome_exibicao if atacante is Jogador and atacante != jogador else "queda"
			_tempo_morto = 0.0)


func _ao_abate(matador: String, vitima: String, arma: String, cabeca: bool) -> void:
	var t := "%s  [%s%s]  %s" % [matador, arma, " ✦" if cabeca else "", vitima] if arma != "" else "%s caiu" % vitima
	_feed.push_front({"texto": t, "tempo": 5.0, "meu": _jogador and (matador == _jogador.nome_exibicao or vitima == _jogador.nome_exibicao)})
	if _feed.size() > 5:
		_feed.pop_back()


func _ao_dano(_qtd: float, atacante: Node, _ponto: Vector3, _cabeca: bool) -> void:
	if atacante is Node3D and atacante != _jogador:
		var d: Vector3 = atacante.global_position - _jogador.global_position
		_danos.append({"angulo": atan2(-d.x, -d.z), "tempo": 1.2})


func _process(delta: float) -> void:
	for f in _feed:
		f.tempo -= delta
	_feed = _feed.filter(func(f): return f.tempo > 0.0)
	for d in _danos:
		d.tempo -= delta
	_danos = _danos.filter(func(d): return d.tempo > 0.0)
	if _jogador and _jogador.esta_morto():
		_tempo_morto += delta
	queue_redraw()


func _texto(pos: Vector2, t: String, tam: int, cor := Color.WHITE, centralizado := false) -> void:
	if centralizado:
		pos.x -= _fonte.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x * 0.5
	draw_string_outline(_fonte, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 5, Color(0, 0, 0, 0.7))
	draw_string(_fonte, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)


func _draw() -> void:
	if _modo == null or (_fim and _fim.visible):
		return
	var w := size.x
	var h := size.y
	var c := size * 0.5

	# ---- Borda vermelha com pouca vida ----
	if _jogador and not _jogador.esta_morto() and _jogador.saude.vida < 35.0:
		var a := (1.0 - _jogador.saude.vida / 35.0) * 0.45 * (0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.008))
		for i in 6:
			draw_rect(Rect2(0, 0, w, h), Color(0.8, 0, 0, a * (1.0 - i / 6.0)), false, 40.0 + i * 30.0)

	# ---- Topo: tempo e placar ----
	var t := int(ceil(_modo.tempo_restante))
	_texto(Vector2(c.x, 34), "%02d:%02d" % [t / 60, t % 60], 26, Color.WHITE, true)
	var ordem := _modo.classificacao()
	var meu := _modo.dados_de(_jogador) if _jogador else {}
	if not ordem.is_empty():
		var lider: Dictionary = ordem[0]
		var txt := "Você %d   ·   Líder: %s %d   ·   meta %d" % [meu.get("abates", 0), lider.nome, lider.abates, _modo.abates_para_vencer]
		_texto(Vector2(c.x, 60), txt, 17, Color(1, 0.95, 0.8), true)

	# ---- Feed de abates ----
	var y := 110.0
	for f in _feed:
		var alpha: float = clamp(f.tempo, 0.0, 1.0)
		var cor := Color(1, 0.85, 0.3, alpha) if f.meu else Color(1, 1, 1, alpha)
		var largura := _fonte.get_string_size(f.texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_rect(Rect2(w - largura - 30, y - 18, largura + 16, 24), Color(0, 0, 0, 0.35 * alpha))
		_texto(Vector2(w - largura - 22, y), f.texto, 16, cor)
		y += 28

	if _jogador == null:
		return

	# ---- Barra de vida ----
	var vida := _jogador.saude.vida
	var bx := w * 0.5 - 330.0
	var by := h - 70.0
	draw_rect(Rect2(bx, by, 220, 16), Color(0, 0, 0, 0.5))
	var cor_vida := Color(0.3, 0.9, 0.4) if vida > 50 else (Color(1, 0.8, 0.2) if vida > 25 else Color(1, 0.3, 0.25))
	draw_rect(Rect2(bx + 2, by + 2, 216 * vida / _jogador.saude.vida_max, 12), cor_vida)
	_texto(Vector2(bx, by - 6), "%d" % ceil(vida), 18)
	if _jogador.invencivel and not _jogador.esta_morto():
		_texto(Vector2(bx + 50, by - 6), "protegido", 14, Color(0.6, 0.9, 1))

	# ---- Indicador de dano (arco na direção de quem atirou) ----
	var yaw_cam := _jogador.yaw_visao()
	for d in _danos:
		var rel: float = wrapf(d.angulo - yaw_cam, -PI, PI)
		var ang_tela := -rel - PI / 2.0  # 0 = cima da tela
		var alpha: float = clamp(d.tempo, 0.0, 1.0)
		draw_arc(c, 120, ang_tela - 0.35, ang_tela + 0.35, 16, Color(1, 0.15, 0.1, 0.8 * alpha), 10.0, true)

	# ---- Eliminado ----
	if _jogador.esta_morto():
		draw_rect(Rect2(0, c.y - 70, w, 120), Color(0, 0, 0, 0.45))
		_texto(Vector2(c.x, c.y - 20), "ELIMINADO", 40, Color(1, 0.3, 0.25), true)
		_texto(Vector2(c.x, c.y + 14), "por %s" % _morto_por, 20, Color.WHITE, true)
		var falta := maxf(_modo.espera_renascer - _tempo_morto, 0.0)
		_texto(Vector2(c.x, c.y + 42), "renascendo em %.0f" % ceil(falta), 18, Color(0.9, 0.9, 0.9), true)

	# ---- Placar completo ----
	if Input.is_action_pressed("placar"):
		_desenhar_placar(ordem, Rect2(c.x - 260, 90, 520, 60 + ordem.size() * 34))


func _desenhar_placar(ordem: Array, r: Rect2) -> void:
	draw_rect(r, Color(0, 0, 0, 0.72))
	_texto(Vector2(r.position.x + 20, r.position.y + 34), "PLACAR", 22, Color(1, 0.85, 0.3))
	_texto(Vector2(r.position.x + 330, r.position.y + 34), "Abates", 16)
	_texto(Vector2(r.position.x + 420, r.position.y + 34), "Mortes", 16)
	for i in ordem.size():
		var p: Dictionary = ordem[i]
		var yy := r.position.y + 70 + i * 34
		var cor := Color(1, 0.85, 0.3) if p.no == _jogador else Color.WHITE
		_texto(Vector2(r.position.x + 20, yy), "%d. %s%s" % [i + 1, p.nome, "  (bot)" if p.bot else ""], 18, cor)
		_texto(Vector2(r.position.x + 345, yy), str(p.abates), 18, cor)
		_texto(Vector2(r.position.x + 440, yy), str(p.mortes), 18, cor)


# =========================================================================
#  FIM DE PARTIDA
# =========================================================================

func mostrar_fim(resultado: Dictionary) -> void:
	_fim = PanelContainer.new()
	_fim.set_anchors_preset(Control.PRESET_CENTER)
	_fim.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fim.grow_vertical = Control.GROW_DIRECTION_BOTH
	_fim.custom_minimum_size = Vector2(620, 0)
	_fim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fim)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_fim.add_child(v)
	var meu := {}
	for l in resultado.tabela:
		if l.local:
			meu = l
	var titulo := Label.new()
	titulo.text = "VITÓRIA!" if meu.get("posicao", 0) == 1 else "FIM DE PARTIDA"
	titulo.add_theme_font_size_override("font_size", 40)
	titulo.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if meu.get("posicao", 0) == 1 else Color.WHITE)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)
	var sub := Label.new()
	sub.text = "Vencedor: %s" % resultado.vencedor
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	v.add_child(sub)
	for l in resultado.tabela:
		var linha := Label.new()
		linha.text = "%d.  %-14s   %2d abates   %2d mortes" % [l.posicao, l.nome, l.abates, l.mortes]
		linha.add_theme_font_size_override("font_size", 20)
		if l.local:
			linha.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		v.add_child(linha)
	var rec: Dictionary = resultado.get("recompensas", {})
	if not rec.is_empty():
		var r := Label.new()
		var partes := ["+%d XP" % rec.get("xp", 0), "+%d moedas" % rec.get("moedas", 0)]
		if rec.get("caixas", 0) > 0: partes.append("+%d caixa(s)" % rec.caixas)
		if rec.get("giros", 0) > 0: partes.append("+%d giro(s) na roleta" % rec.giros)
		if rec.get("subiu_nivel", false): partes.append("SUBIU PARA O NÍVEL %d!" % rec.nivel)
		r.text = "   ".join(partes)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.autowrap_mode = TextServer.AUTOWRAP_WORD
		r.add_theme_font_size_override("font_size", 20)
		r.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
		v.add_child(r)
	var linha_botoes := HBoxContainer.new()
	linha_botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	linha_botoes.add_theme_constant_override("separation", 16)
	v.add_child(linha_botoes)
	for par in [["JOGAR DE NOVO", _jogar_de_novo], ["MENU", _ir_menu]]:
		var b := Button.new()
		b.text = par[0]
		b.custom_minimum_size = Vector2(220, 64)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(par[1])
		linha_botoes.add_child(b)
	if Controles.usa_mouse():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _jogar_de_novo() -> void:
	Controles.menu_aberto = false
	get_tree().reload_current_scene()


func _ir_menu() -> void:
	Controles.menu_aberto = false
	var menu := "res://ui/menus/menu_principal.tscn"
	if ResourceLoader.exists(menu):
		get_tree().change_scene_to_file(menu)
	else:
		get_tree().reload_current_scene()
