extends Node
## Teste automático da etapa 5 (bots + mata-mata), roda sem tela:
##   godot --headless --path . res://tests/teste_auto_etapa5.tscn

var _falhas := 0
var _partida: Partida


func _checar(nome: String, ok: bool) -> void:
	print(("OK    " if ok else "FALHA ") + nome)
	if not ok: _falhas += 1


func _esperar(seg: float) -> void:
	for i in int(seg * 60.0):
		await get_tree().physics_frame


func _ready() -> void:
	Engine.physics_ticks_per_second = 60
	_rodar()


func _rodar() -> void:
	# ---------- Partida 1: bots difíceis, meta de 4 abates ----------
	Sessao.dificuldade = 2
	Sessao.total_participantes = 5
	Sessao.abates_para_vencer = 4
	Sessao.duracao_segundos = 600
	_partida = load("res://scenes/partida.tscn").instantiate()
	add_child(_partida)
	await _esperar(1.0)
	var modo := _partida.modo
	_checar("5 participantes (1 jogador + 4 bots)", modo.participantes.size() == 5)
	var nav := _partida.mapa.regiao_navegacao.navigation_mesh
	_checar("malha de navegação gerada (%d polígonos)" % nav.get_polygon_count(), nav.get_polygon_count() > 50)
	# Jogador local fica parado num canto e invencível (o teste é dos bots)
	var j := _partida.jogador
	var nomes := []
	for p in modo.participantes:
		nomes.append(p.nome)
	print("   participantes: ", nomes)

	var pos0 := {}
	for p in modo.participantes:
		pos0[p.no] = p.no.global_position
	await _esperar(4.0)
	var andaram := 0
	for p in modo.participantes:
		if p.bot and p.no.global_position.distance_to(pos0[p.no]) > 3.0:
			andaram += 1
	_checar("bots se movem pelo mapa (%d de 4 andaram > 3 m)" % andaram, andaram >= 3)

	# Espera a partida rolar: tiros, abates, renascimentos
	var terminou := [false]
	var resultado := [{}]
	modo.partida_terminou.connect(func(r): terminou[0] = true; resultado[0] = r)
	var morreu_alguem := false
	var renasceu := false
	var mortos_antes := {}
	var estados_vistos := {}
	var tempo := 0.0
	while tempo < 150.0 and not terminou[0]:
		await get_tree().physics_frame
		tempo += 1.0 / 60.0
		for p in modo.participantes:
			if p.no.has_node("Cerebro"):
				estados_vistos[p.no.get_node("Cerebro").estado] = true
			if p.no.esta_morto():
				morreu_alguem = true
				mortos_antes[p.no] = true
			elif mortos_antes.has(p.no):
				renasceu = true
	print("   simulado %.0f s de partida" % tempo)
	var total_abates := 0
	for p in modo.participantes:
		total_abates += p.abates
		print("   %-10s abates %d  mortes %d" % [p.nome, p.abates, p.mortes])
	_checar("bots entraram em combate (estados vistos: %s)" % str(estados_vistos.keys()), estados_vistos.has(CerebroBot.Estado.COMBATE))
	_checar("houve abates (%d)" % total_abates, total_abates > 0 and morreu_alguem)
	_checar("quem morre renasce", renasceu)
	_checar("partida termina ao atingir a meta de abates (vencedor: %s)" % resultado[0].get("vencedor", "-"), terminou[0])
	_partida.queue_free()
	await _esperar(0.5)

	# ---------- Partida 2: fim por tempo ----------
	Sessao.abates_para_vencer = 99
	Sessao.duracao_segundos = 3
	Sessao.dificuldade = 0
	_partida = load("res://scenes/partida.tscn").instantiate()
	add_child(_partida)
	await _esperar(1.0)
	var fim := [false]
	_partida.modo.partida_terminou.connect(func(_r): fim[0] = true)
	await _esperar(3.5)
	_checar("partida termina quando o tempo acaba", fim[0])

	print("RESULTADO: %d falha(s)" % _falhas)
	get_tree().quit(_falhas)
