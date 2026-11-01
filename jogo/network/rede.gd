extends Node
## Multiplayer na mesma rede Wi-Fi (ENet nativo da Godot). Autoload "Rede".
##
## COMO FUNCIONA
##  - Um celular CRIA A SALA (host = servidor ENet na porta 7777) e anuncia a sala
##    na rede local por broadcast UDP (porta 7778) uma vez por segundo.
##  - O outro PROCURA SALAS (escuta a porta 7778), vê a sala na lista e ENTRA.
##    Se a busca não achar (alguns roteadores bloqueiam broadcast), dá para digitar o IP.
##  - No lobby o host aperta INICIAR: todos carregam a partida; bots completam as vagas.
##
## QUEM MANDA EM QUÊ (simples e responsivo para jogar com um amigo)
##  - Cada aparelho simula o PRÓPRIO personagem e envia o estado ~20x/s (sem confirmação,
##    o mais novo vale). Os outros mostram com interpolação (sincronizador_personagem.gd).
##  - Quem atira calcula o acerto (resposta imediata na tela) e pede o dano ao host.
##  - O HOST é a autoridade de vida, abates, placar, renascimento, tempo e bots.

signal lista_salas_mudou
signal lobby_mudou
signal mensagem(texto: String)

const PORTA_JOGO := 7777
const PORTA_DESCOBERTA := 7778
const MAX_CLIENTES := 4
const ENVIOS_POR_SEGUNDO := 20.0
const VERSAO := "telhado-1"

enum Papel { NENHUM, HOST, CLIENTE }

var papel: Papel = Papel.NENHUM
var salas := {}            # ip -> {nome, jogadores, visto}
var jogadores := {}        # peer_id -> {nome, personagem, skin, armas, skins}
var bots_info: Array = []  # [{nome, personagem, skin, armas}]
var em_partida := false
var partida: Partida
var nos := {}              # nome do nó -> Jogador

var _udp_anuncio: PacketPeerUDP
var _udp_busca: PacketPeerUDP
var _tempo_anuncio := 0.0
var _tempo_envio := 0.0
var _tempo_placar := 0.0
var _relogio := 0.0
var _prontos := {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_conectou)
	multiplayer.peer_disconnected.connect(_peer_desconectou)
	multiplayer.connected_to_server.connect(_conectado)
	multiplayer.connection_failed.connect(func(): mensagem.emit("Não conseguiu conectar."); sair())
	multiplayer.server_disconnected.connect(_host_saiu)


func em_rede() -> bool:
	return papel != Papel.NENHUM


func eh_host() -> bool:
	return papel == Papel.HOST


func meus_dados() -> Dictionary:
	var skins := {}
	for id in [Config.obter("arma_principal"), Config.obter("arma_secundaria")]:
		var s := Progresso.skin_equipada(id)
		if s:
			skins[id] = s.id
	return {"nome": Config.obter("nome_jogador"), "personagem": Config.obter("personagem"),
		"skin": Config.obter("skin"), "armas": [Config.obter("arma_principal"), Config.obter("arma_secundaria")],
		"skins": skins}


## Endereços IP desta máquina na rede local (para mostrar na tela).
func meus_ips() -> Array:
	var r := []
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or (ip.begins_with("172.") and not ip.begins_with("172.17.")):
			r.append(ip)
	return r


# =========================================================================
#  SALA: criar, procurar, entrar, sair
# =========================================================================

func criar_sala() -> bool:
	sair()
	var peer := ENetMultiplayerPeer.new()
	var erro := peer.create_server(PORTA_JOGO, MAX_CLIENTES)
	if erro != OK:
		mensagem.emit("Não deu para criar a sala (porta %d ocupada?)." % PORTA_JOGO)
		return false
	multiplayer.multiplayer_peer = peer
	papel = Papel.HOST
	jogadores = {1: meus_dados()}
	_udp_anuncio = PacketPeerUDP.new()
	_udp_anuncio.set_broadcast_enabled(true)
	lobby_mudou.emit()
	return true


func procurar_salas() -> void:
	parar_busca()
	salas.clear()
	_udp_busca = PacketPeerUDP.new()
	if _udp_busca.bind(PORTA_DESCOBERTA) != OK:
		mensagem.emit("Não deu para procurar salas (porta %d ocupada)." % PORTA_DESCOBERTA)
		_udp_busca = null


func parar_busca() -> void:
	if _udp_busca:
		_udp_busca.close()
		_udp_busca = null


func entrar(ip: String) -> void:
	parar_busca()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, PORTA_JOGO) != OK:
		mensagem.emit("Endereço inválido.")
		return
	multiplayer.multiplayer_peer = peer
	papel = Papel.CLIENTE
	mensagem.emit("Conectando a %s..." % ip)


func sair() -> void:
	parar_busca()
	if _udp_anuncio:
		_udp_anuncio.close()
		_udp_anuncio = null
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	papel = Papel.NENHUM
	jogadores.clear()
	em_partida = false
	nos.clear()
	lobby_mudou.emit()


func _conectado() -> void:
	_registrar.rpc_id(1, meus_dados())
	mensagem.emit("Conectado! Aguardando o host iniciar.")


func _peer_conectou(_id: int) -> void:
	pass


func _peer_desconectou(id: int) -> void:
	if not eh_host():
		return
	jogadores.erase(id)
	_atualizar_lobby.rpc(jogadores)
	lobby_mudou.emit()
	if em_partida:
		_remover_no.rpc("P%d" % id)
		_remover_no("P%d" % id)


func _host_saiu() -> void:
	mensagem.emit("O host saiu da partida.")
	sair()
	if get_tree().current_scene is Partida:
		Controles.menu_aberto = false
		get_tree().change_scene_to_file("res://ui/menus/menu_principal.tscn")


@rpc("any_peer", "reliable")
func _registrar(dados: Dictionary) -> void:
	if not eh_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if em_partida or jogadores.size() >= MAX_CLIENTES + 1:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	jogadores[id] = dados
	_atualizar_lobby.rpc(jogadores)
	lobby_mudou.emit()


@rpc("authority", "reliable")
func _atualizar_lobby(lista: Dictionary) -> void:
	jogadores = lista
	lobby_mudou.emit()


# =========================================================================
#  ANÚNCIO E BUSCA NA REDE LOCAL
# =========================================================================

func _process(delta: float) -> void:
	_relogio += delta
	# Host anuncia a sala
	if _udp_anuncio and eh_host() and not em_partida:
		_tempo_anuncio -= delta
		if _tempo_anuncio <= 0.0:
			_tempo_anuncio = 1.0
			var msg := JSON.stringify({"jogo": VERSAO, "nome": jogadores[1].nome, "jogadores": jogadores.size(), "porta": PORTA_JOGO})
			for destino in ["255.255.255.255", "127.0.0.1"]:
				_udp_anuncio.set_dest_address(destino, PORTA_DESCOBERTA)
				_udp_anuncio.put_packet(msg.to_utf8_buffer())
	# Busca recebe anúncios
	if _udp_busca:
		var mudou := false
		while _udp_busca.get_available_packet_count() > 0:
			var pacote := _udp_busca.get_packet()
			var ip := _udp_busca.get_packet_ip()
			var d = JSON.parse_string(pacote.get_string_from_utf8())
			if d is Dictionary and d.get("jogo") == VERSAO:
				if ip == "127.0.0.1" and not meus_ips().is_empty():
					ip = "127.0.0.1"
				salas[ip] = {"nome": d.nome, "jogadores": int(d.jogadores), "visto": _relogio}
				mudou = true
		for ip in salas.keys():
			if _relogio - salas[ip].visto > 3.5:
				salas.erase(ip)
				mudou = true
		if mudou:
			lista_salas_mudou.emit()


# =========================================================================
#  INÍCIO DA PARTIDA
# =========================================================================

## Host: sorteia os bots, avisa todo mundo e carrega a partida.
func iniciar_partida_host(dificuldade: int) -> void:
	if not eh_host():
		return
	bots_info.clear()
	var livres: Array = Sessao.NOMES_BOTS.duplicate()
	livres.shuffle()
	for i in max(0, Sessao.total_participantes - jogadores.size()):
		var opcoes: Array = CatalogoArmas.PRINCIPAIS.duplicate()
		bots_info.append({"nome": livres[i], "personagem": randi() % 2, "skin": randi() % 8,
			"armas": [opcoes[randi() % opcoes.size()], CatalogoArmas.SECUNDARIAS[randi() % 2]]})
	_comecar.rpc(jogadores, bots_info, dificuldade)
	_comecar(jogadores, bots_info, dificuldade)


@rpc("authority", "reliable")
func _comecar(lista: Dictionary, bots: Array, dificuldade: int) -> void:
	jogadores = lista
	bots_info = bots
	Sessao.dificuldade = dificuldade
	Sessao.tipo_rede = Sessao.TipoRede.HOST if eh_host() else Sessao.TipoRede.CLIENTE
	Sessao.abates_para_vencer = 20
	Sessao.duracao_segundos = 480.0
	_prontos.clear()
	Controles.menu_aberto = false
	get_tree().change_scene_to_file("res://scenes/partida.tscn")


## Chamado pela cena Partida quando é partida em rede: cria todo mundo.
func iniciar_partida_em_rede(p: Partida) -> void:
	partida = p
	em_partida = true
	nos.clear()
	var modo := p.modo
	modo.autoridade = eh_host()
	var cena_jogador: PackedScene = load("res://characters/jogador.tscn")
	var meu_id := multiplayer.get_unique_id()
	var ids := jogadores.keys()
	ids.sort()
	for id in ids:
		var d: Dictionary = jogadores[id]
		var j: Jogador = cena_jogador.instantiate()
		j.name = "P%d" % id
		if id == meu_id:
			j.tipo = Jogador.Tipo.LOCAL
		else:
			j.tipo = Jogador.Tipo.REMOTO
			j.personagem_inicial = d.personagem
			j.skin_inicial = d.skin
			j.add_child(_novo_sincronizador())
		p.add_child(j)
		if id != meu_id:
			j.armas.skin_remota = d.get("skins", {})
			j.armas.equipar_armas(d.armas)
		else:
			p.jogador = j
		modo.adicionar(j, d.nome, false, id)
		nos[String(j.name)] = j  # chave String (nome de nó é StringName: seriam chaves diferentes)
	for i in bots_info.size():
		var b: Dictionary = bots_info[i]
		var bot: Jogador
		if eh_host():
			bot = p.criar_bot(i, b.nome, b)
		else:
			bot = cena_jogador.instantiate()
			bot.name = "Bot%d" % i
			bot.tipo = Jogador.Tipo.REMOTO
			bot.personagem_inicial = b.personagem
			bot.skin_inicial = b.skin
			bot.add_child(_novo_sincronizador())
			p.add_child(bot)
			bot.armas.equipar_armas(b.armas)
			modo.adicionar(bot, b.nome, true)
		nos[String(bot.name)] = bot
	# Eventos que viajam pela rede
	for nome in nos:
		var j: Jogador = nos[nome]
		j.armas.tiro_visual.connect(func(de: Vector3, ate: Vector3):
			if j.tipo != Jogador.Tipo.REMOTO:
				_efeito_tiro.rpc(j.name, de, ate))
		if eh_host():
			j.saude.dano_recebido.connect(func(qtd, atacante, ponto, cabeca):
				_vida_rede.rpc(j.name, j.saude.vida, qtd, atacante.name if atacante is Node else "", ponto, cabeca))
			j.morreu.connect(func(atacante): _morreu_rede.rpc(j.name, atacante.name if atacante is Node else ""))
			j.renasceu.connect(func(): _renasceu_rede.rpc(j.name, j.global_position, j.visual.rotation.y))
	if eh_host():
		modo.abate.connect(func(m, v, a, c): _abate_rede.rpc(m, v, a, c))
		modo.partida_terminou.connect(func(r): _fim_rede.rpc(r))
		modo.iniciar()
		# Espera os clientes carregarem (até 8 s) antes de posicionar todo mundo
		var limite := 8.0
		while _prontos.size() < jogadores.size() - 1 and limite > 0.0:
			await get_tree().create_timer(0.2).timeout
			limite -= 0.2
		modo.posicionar_todos()
	else:
		_cliente_pronto.rpc_id(1)


func _novo_sincronizador() -> SincronizadorPersonagem:
	var s := SincronizadorPersonagem.new()
	s.name = "Sincronizador"
	return s


@rpc("any_peer", "reliable")
func _cliente_pronto() -> void:
	_prontos[multiplayer.get_remote_sender_id()] = true


# =========================================================================
#  DURANTE A PARTIDA
# =========================================================================

func _physics_process(delta: float) -> void:
	if not em_partida or partida == null or not is_instance_valid(partida):
		return
	_tempo_envio -= delta
	if _tempo_envio <= 0.0:
		_tempo_envio = 1.0 / ENVIOS_POR_SEGUNDO
		for nome in nos:
			var j: Jogador = nos[nome]
			if not is_instance_valid(j) or j.tipo == Jogador.Tipo.REMOTO:
				continue  # cada um envia só o que simula (o seu e, no host, os bots)
			_estado.rpc(j.name, _relogio, j.global_position, j.velocity, j.visual.rotation.y, j.pitch_corpo(),
				j.estado, Vector2(j.velocity.x, j.velocity.z).length(), j.mirando, j.armas.atual)
	if eh_host():
		_tempo_placar -= delta
		if _tempo_placar <= 0.0:
			_tempo_placar = 1.0
			var lista := []
			for p in partida.modo.participantes:
				lista.append([p.no.name, p.abates, p.mortes, p.no.saude.vida])
			_placar_rede.rpc(lista, partida.modo.tempo_restante)


@rpc("any_peer", "unreliable_ordered")
func _estado(nome: String, t: float, pos: Vector3, vel: Vector3, yaw: float, pitch: float,
		estado: StringName, vel_h: float, mirando: bool, arma: int) -> void:
	var j: Jogador = nos.get(nome)
	if j == null or not is_instance_valid(j) or j.tipo != Jogador.Tipo.REMOTO:
		return
	var s := j.get_node_or_null("Sincronizador") as SincronizadorPersonagem
	if s:
		s.receber(t, pos, vel, yaw, pitch, estado, vel_h, mirando)
	if arma != j.armas.atual and arma < j.armas.slots.size():
		j.armas.atual = arma
		j.armas.reprender_modelo()


@rpc("any_peer", "unreliable")
func _efeito_tiro(nome: String, de: Vector3, ate: Vector3) -> void:
	var j: Jogador = nos.get(nome)
	if j == null or not is_instance_valid(j):
		return
	Efeitos.rastro(de, ate, j.armas.arma().cor_rastro if j.armas.arma() else Color.WHITE)
	if j.armas.arma():
		Efeitos.som_3d(j.armas.arma().nome_som_tiro(), de, -3.0)
	if j.armas.modelo_arma:
		j.armas.modelo_arma.disparou()
	j.armas.tempo_desde_tiro = 0.0  # bots "ouvem" o tiro


## Cliente acertou alguém: pede ao host para aplicar o dano.
func pedir_dano(alvo: Jogador, qtd: float, atacante: Node, ponto: Vector3, cabeca: bool) -> void:
	_pedir_dano.rpc_id(1, alvo.name, qtd, atacante.name if atacante is Node else "", ponto, cabeca)


@rpc("any_peer", "reliable")
func _pedir_dano(alvo_nome: String, qtd: float, atacante_nome: String, ponto: Vector3, cabeca: bool) -> void:
	if not eh_host():
		return
	var alvo: Jogador = nos.get(alvo_nome)
	if alvo == null or alvo.esta_morto():
		return
	alvo.saude.receber_dano(qtd, nos.get(atacante_nome), ponto, cabeca)


@rpc("authority", "reliable")
func _vida_rede(nome: String, vida: float, qtd: float, atacante_nome: String, ponto: Vector3, cabeca: bool) -> void:
	var j: Jogador = nos.get(nome)
	if j == null:
		return
	j.saude.vida = vida
	j.saude.tempo_desde_dano = 0.0
	j.saude.dano_recebido.emit(qtd, nos.get(atacante_nome), ponto, cabeca)


@rpc("authority", "reliable")
func _morreu_rede(nome: String, atacante_nome: String) -> void:
	var j: Jogador = nos.get(nome)
	if j == null or j.saude.morto:
		return
	j.saude.vida = 0.0
	j.saude.morto = true
	j._ao_morrer(nos.get(atacante_nome))


@rpc("authority", "reliable")
func _renasceu_rede(nome: String, pos: Vector3, yaw: float) -> void:
	var j: Jogador = nos.get(nome)
	if j == null:
		return
	j.renascer(pos, yaw)
	var s := j.get_node_or_null("Sincronizador") as SincronizadorPersonagem
	if s:
		s.limpar()


@rpc("authority", "reliable")
func _abate_rede(matador: String, vitima: String, arma: String, cabeca: bool) -> void:
	if partida:
		partida.modo.abate.emit(matador, vitima, arma, cabeca)


@rpc("authority", "unreliable_ordered")
func _placar_rede(lista: Array, tempo: float) -> void:
	if partida == null:
		return
	partida.modo.tempo_restante = tempo
	for linha in lista:
		var j: Jogador = nos.get(linha[0])
		if j == null:
			continue
		var d := partida.modo.dados_de(j)
		if not d.is_empty():
			d.abates = linha[1]
			d.mortes = linha[2]
		if not j.esta_morto():
			j.saude.vida = linha[3]
	partida.modo.placar_mudou.emit()


@rpc("authority", "reliable")
func _fim_rede(resultado: Dictionary) -> void:
	# Marca a minha linha (no host, "local" era a do host)
	var meu := "P%d" % multiplayer.get_unique_id()
	for linha in resultado.tabela:
		linha.local = false
	for p in partida.modo.participantes:
		if p.no.name == meu:
			for linha in resultado.tabela:
				if linha.nome == p.nome:
					linha.local = true
	partida.modo.terminou = true
	partida._ao_terminar(resultado)


@rpc("authority", "reliable")
func _remover_no(nome: String) -> void:
	var j: Jogador = nos.get(nome)
	if j and is_instance_valid(j):
		if partida:
			partida.modo.remover(j)
		j.queue_free()
	nos.erase(nome)


func partida_terminou_local() -> void:
	em_partida = false


# =========================================================================
#  TELA DO MULTIPLAYER (dentro do menu principal)
# =========================================================================

func montar_tela(area: VBoxContainer, menu: Control) -> void:
	var info := Tema.rotulo("Os dois celulares precisam estar na MESMA rede Wi-Fi.", 17, Tema.COR_SUAVE)
	area.add_child(info)
	var nome := LineEdit.new()
	nome.text = Config.obter("nome_jogador")
	nome.placeholder_text = "Seu nome"
	nome.custom_minimum_size = Vector2(0, 52)
	nome.text_changed.connect(func(t: String): Config.definir("nome_jogador", t.strip_edges().left(14)); Config.salvar())
	area.add_child(nome)
	var estado := Tema.rotulo("", 18, Color(1, 0.88, 0.5))
	estado.autowrap_mode = TextServer.AUTOWRAP_WORD
	area.add_child(estado)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 6)
	area.add_child(lista)
	var botoes := VBoxContainer.new()
	botoes.add_theme_constant_override("separation", 8)
	area.add_child(botoes)

	var redesenhar := func(): pass
	redesenhar = func():
		if not is_instance_valid(lista):
			return
		for c in lista.get_children():
			c.queue_free()
		for c in botoes.get_children():
			c.queue_free()
		match papel:
			Papel.NENHUM:
				estado.text = "Crie uma sala ou entre na de um amigo." + ("  Seu IP: " + ", ".join(meus_ips()) if not meus_ips().is_empty() else "")
				botoes.add_child(Tema.botao("CRIAR SALA (eu sou o host)", func():
					criar_sala()))
				if _udp_busca == null:
					procurar_salas()
				lista.add_child(Tema.rotulo("Salas encontradas na rede:", 18))
				if salas.is_empty():
					lista.add_child(Tema.rotulo("procurando...", 16, Tema.COR_SUAVE))
				for ip in salas:
					var s: Dictionary = salas[ip]
					lista.add_child(Tema.botao("ENTRAR: sala de %s  (%d/5)  ·  %s" % [s.nome, s.jogadores, ip], func(): entrar(ip), Vector2(0, 58), 18))
				var linha := HBoxContainer.new()
				var ip_campo := LineEdit.new()
				ip_campo.placeholder_text = "ou digite o IP do host (ex.: 192.168.0.10)"
				ip_campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				ip_campo.custom_minimum_size = Vector2(0, 52)
				linha.add_child(ip_campo)
				linha.add_child(Tema.botao("ENTRAR", func(): entrar(ip_campo.text.strip_edges()), Vector2(130, 52), 18))
				botoes.add_child(linha)
			Papel.HOST:
				var ips := ", ".join(meus_ips()) if not meus_ips().is_empty() else "(conecte no Wi-Fi)"
				estado.text = "Sala criada! Seu IP: %s. Esperando o amigo entrar..." % ips
				lista.add_child(Tema.rotulo("Jogadores (%d/5) — bots completam o resto:" % jogadores.size(), 18))
				for id in jogadores:
					lista.add_child(Tema.rotulo("  • %s%s" % [jogadores[id].nome, "  (você)" if id == 1 else ""], 18))
				botoes.add_child(Tema.botao("INICIAR PARTIDA", func():
					iniciar_partida_host(menu._dificuldade), Vector2(0, 70), 26))
				botoes.add_child(Tema.botao("FECHAR SALA", func(): sair(), Vector2(0, 52), 18))
			Papel.CLIENTE:
				lista.add_child(Tema.rotulo("Jogadores na sala:", 18))
				for id in jogadores:
					lista.add_child(Tema.rotulo("  • %s" % jogadores[id].nome, 18))
				botoes.add_child(Tema.botao("SAIR DA SALA", func(): sair(), Vector2(0, 52), 18))
	var ao_mudar := func(): redesenhar.call()
	var ao_msg := func(t: String):
		if is_instance_valid(estado):
			estado.text = t
	lobby_mudou.connect(ao_mudar)
	lista_salas_mudou.connect(ao_mudar)
	mensagem.connect(ao_msg)
	# Ao sair da tela: desliga os sinais e para de procurar salas
	lista.tree_exiting.connect(func():
		lobby_mudou.disconnect(ao_mudar)
		lista_salas_mudou.disconnect(ao_mudar)
		mensagem.disconnect(ao_msg)
		if papel == Papel.NENHUM:
			parar_busca())
	redesenhar.call()
