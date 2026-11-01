extends Control
## Animação de abrir caixa: uma faixa de itens (sorteados com as mesmas chances da
## caixa) passa rápido e desacelera até parar no item ganho, embaixo do marcador.

const LARGURA_ITEM := 130.0
const POSICAO_PREMIO := 38

var _itens: Array = []      # DadosSkinArma
var _desloc := 0.0
var _fonte: Font


func _ready() -> void:
	_fonte = ThemeDB.fallback_font
	clip_contents = true
	_preencher(null)


func _preencher(premio: DadosSkinArma) -> void:
	_itens.clear()
	for i in POSICAO_PREMIO + 6:
		var lista := CatalogoSkins.da_raridade(Progresso.sortear_raridade())
		_itens.append(lista[randi() % lista.size()])
	if premio:
		_itens[POSICAO_PREMIO] = premio


func sortear(premio: DadosSkinArma) -> void:
	_preencher(premio)
	_desloc = 0.0
	# Para o centro do item do prêmio ficar sob o marcador (centro da faixa),
	# com um pequeno desvio aleatório para parecer natural.
	var destino := POSICAO_PREMIO * LARGURA_ITEM + LARGURA_ITEM * 0.5 - size.x * 0.5 + randf_range(-40, 40)
	var tw := create_tween()
	tw.tween_property(self, "_desloc", destino, 4.5).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(_v): queue_redraw(), 0.0, 1.0, 4.5)
	await tw.finished
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.07, 0.9))
	for i in _itens.size():
		var x := i * LARGURA_ITEM - _desloc
		if x < -LARGURA_ITEM or x > size.x:
			continue
		var s: DadosSkinArma = _itens[i]
		var cor := DadosSkinArma.cor_raridade(s.raridade)
		var r := Rect2(x + 5, 12, LARGURA_ITEM - 10, size.y - 24)
		draw_rect(r, cor.darkened(0.6))
		draw_rect(r, cor, false, 3.0)
		# "Amostra" da skin: as duas cores
		draw_rect(Rect2(r.position + Vector2(12, 14), Vector2(r.size.x - 24, 34)), s.cor_a)
		draw_rect(Rect2(r.position + Vector2(12, 40), Vector2(r.size.x - 24, 10)), s.cor_b)
		var arma := CatalogoArmas.carregar(s.arma)
		draw_string(_fonte, r.position + Vector2(8, 78), s.nome, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 15, Color.WHITE)
		draw_string(_fonte, r.position + Vector2(8, 98), arma.nome if arma else "", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 13, Color(0.8, 0.8, 0.85))
	# Marcador central
	var cx := size.x * 0.5
	draw_line(Vector2(cx, 0), Vector2(cx, size.y), Tema.COR_DESTAQUE, 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 12, 0), Vector2(cx + 12, 0), Vector2(cx, 14)]), Tema.COR_DESTAQUE)
