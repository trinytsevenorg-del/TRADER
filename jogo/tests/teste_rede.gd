extends SceneTree
## Teste de rede com 2 processos (host e cliente) na mesma máquina.
##   PAPEL=host    godot --headless --path . -s res://tests/teste_rede.gd
##   PAPEL=cliente godot --headless --path . -s res://tests/teste_rede.gd
## Cada processo imprime "OK"/"FALHA" e "RESULTADO".

var papel := OS.get_environment("PAPEL")
var rede: Node
var t := 0.0
var fase := 0
var falhas := 0
var pos_inicial := {}
var marca := 0.0


func _checar(nome: String, ok: bool) -> void:
	print("[%s] %s %s" % [papel, "OK   " if ok else "FALHA", nome])
	if not ok: falhas += 1


func _fim() -> void:
	print("[%s] RESULTADO: %d falha(s)" % [papel, falhas])
	rede.sair()
	quit(falhas)


func _partida() -> Node:
	var c := current_scene
	return c if c and c.get("modo") != null and c.modo != null else null


func _process(delta: float) -> bool:
	t += delta
	if rede == null:
		rede = root.get_node("Rede")
		root.get_node("Config").definir("nome_jogador", papel.capitalize())
		root.get_node("Config").definir("arma_principal", "corisco_ar")
		return false
	if t > 60.0:
		_checar("tempo esgotado na fase %d" % fase, false)
		_fim()
		return false
	if papel == "host":
		_host()
	else:
		_cliente()
	return false


func _host() -> void:
	match fase:
		0:
			_checar("sala criada", rede.criar_sala())
			fase = 1
		1:
			if rede.jogadores.size() == 2:
				_checar("cliente entrou no lobby (%s)" % str(rede.jogadores.values().map(func(d): return d.nome)), true)
				var sessao = root.get_node("Sessao")
				sessao.total_participantes = 4
				rede.iniciar_partida_host(0)
				fase = 2
		2:
			var p := _partida()
			if p and rede.nos.size() == 4 and p.jogador:
				_checar("partida em rede com 2 jogadores + 2 bots (%s)" % str(rede.nos.keys()), true)
				marca = t
				fase = 3
		3:
			if t - marca > 2.0:
				for n in rede.nos:
					pos_inicial[String(n)] = rede.nos[n].global_position
				# Host vai para a praça, de frente para onde o cliente vai ficar
				_partida().jogador.saude.regeneracao_por_segundo = 0.0
				_partida().jogador.teleportar(Vector3(4, 0.15, 6), PI)
				marca = t
				fase = 4
		4:
			if t - marca > 6.0:  # o cliente atira entre ~4 s e ~7 s e sai aos ~9 s
				var cli := ""
				for n in rede.nos:
					if String(n).begins_with("P") and String(n) != "P1":
						cli = String(n)
				var andou: float = rede.nos[cli].global_position.distance_to(pos_inicial[cli])
				_checar("host vê o cliente se mexer (%.1f m)" % andou, andou > 2.0)
				var j = _partida().jogador
				var levou: bool = j.saude.vida < 100.0 or _partida().modo.dados_de(j).mortes > 0
				_checar("tiros do cliente causaram dano no host (vida %.0f, mortes %d)" % [j.saude.vida, _partida().modo.dados_de(j).mortes], levou)
				_fim()


func _cliente() -> void:
	match fase:
		0:
			rede.procurar_salas()
			fase = 1
		1:
			if not rede.salas.is_empty():
				var ip: String = rede.salas.keys()[0]
				_checar("achou a sala na rede local pela busca (%s em %s)" % [rede.salas[ip].nome, ip], true)
				rede.entrar(ip)
				fase = 2
		2:
			var p := _partida()
			if p and rede.nos.size() == 4 and p.jogador:
				_checar("cliente entrou na partida (%s)" % str(rede.nos.keys()), true)
				marca = t
				fase = 3
		3:
			if t - marca > 2.5:
				for n in rede.nos:
					pos_inicial[String(n)] = rede.nos[n].global_position
				root.get_node("Controles").joystick = Vector2(0, -1)
				marca = t
				fase = 4
		4:
			if t - marca > 1.5:
				root.get_node("Controles").joystick = Vector2.ZERO
				# Cliente vai para a praça, de frente para o host, mira e atira
				_partida().jogador.teleportar(Vector3(4, 0.15, -6), 0.0)
				var host = rede.nos["P1"]
				var j = _partida().jogador
				for i in 10:
					j.camera_rig.puxar_para(host.global_position + Vector3.UP * 1.2, 1.0)
				Input.action_press("atirar")
				marca = t
				fase = 5
		5:
			var host = rede.nos["P1"]
			_partida().jogador.camera_rig.puxar_para(host.global_position + Vector3.UP * 1.2, 1.0)
			if t - marca > 3.0:
				Input.action_release("atirar")
				var bots_andaram := 0
				for n in rede.nos:
					if String(n).begins_with("Bot") and rede.nos[n].global_position.distance_to(pos_inicial[String(n)]) > 1.0:
						bots_andaram += 1
				_checar("cliente vê os bots do host se movendo (%d de 2)" % bots_andaram, bots_andaram >= 1)
				var p = _partida()
				_checar("cliente recebe o placar do host (tempo %.0f s)" % p.modo.tempo_restante, p.modo.tempo_restante < 479.0)
				marca = t
				fase = 6
		6:
			if t - marca > 2.0:
				_fim()
