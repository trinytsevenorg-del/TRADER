extends Control
## Roleta de prêmios. Cada fatia tem o TAMANHO proporcional à chance real
## (o que você vê é o que é sorteado). A seta fica em cima; girar_para(i)
## gira algumas voltas e desacelera parando na fatia i (await).

var _angulo := 0.0       # rotação atual da roda (radianos)
var _fonte: Font


func _ready() -> void:
	_fonte = ThemeDB.fallback_font


func _fatias() -> Array:
	var total := 0.0
	for p in Progresso.ROLETA:
		total += p.peso
	var r := []
	var ini := 0.0
	for p in Progresso.ROLETA:
		var tam: float = TAU * p.peso / total
		r.append({"ini": ini, "fim": ini + tam, "p": p})
		ini += tam
	return r


func girar_para(indice: int) -> void:
	var f: Dictionary = _fatias()[indice]
	# Ponto aleatório dentro da fatia (sem cair na borda)
	var margem: float = (f.fim - f.ini) * 0.15
	var alvo_local := randf_range(f.ini + margem, f.fim - margem)
	# A seta está no topo (-PI/2). Ângulo final da roda para a fatia ficar sob a seta:
	var final := -PI / 2.0 - alvo_local
	var voltas := 5.0 * TAU
	var destino := _angulo + voltas + wrapf(final - _angulo, 0.0, TAU)
	var tw := create_tween()
	tw.tween_property(self, "_angulo", destino, 4.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(_v): queue_redraw(), 0.0, 1.0, 4.2)
	await tw.finished
	_angulo = wrapf(_angulo, 0.0, TAU)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r: float = min(size.x, size.y) * 0.46
	draw_circle(c, r + 6, Color(0.1, 0.1, 0.12))
	for f in _fatias():
		var a0: float = f.ini + _angulo
		var a1: float = f.fim + _angulo
		var pts := PackedVector2Array([c])
		var passos := maxi(3, int((a1 - a0) / 0.08))
		for i in passos + 1:
			var a: float = lerpf(a0, a1, float(i) / passos)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, f.p.cor)
		draw_line(c, c + Vector2(cos(a0), sin(a0)) * r, Color(0, 0, 0, 0.5), 2.0)
		# Texto na fatia (se couber)
		if f.fim - f.ini > 0.22:
			var meio: float = (a0 + a1) * 0.5
			var pos := c + Vector2(cos(meio), sin(meio)) * r * 0.62
			var t: String = f.p.texto
			var w := _fonte.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string_outline(_fonte, pos - Vector2(w * 0.5, -5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.7))
			draw_string(_fonte, pos - Vector2(w * 0.5, -5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_circle(c, r * 0.12, Color(0.95, 0.95, 0.95))
	# Seta no topo
	var topo := c - Vector2(0, r + 4)
	draw_colored_polygon(PackedVector2Array([topo + Vector2(-16, -22), topo + Vector2(16, -22), topo + Vector2(0, 10)]), Tema.COR_DESTAQUE)
