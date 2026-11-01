extends Node3D
class_name Partida
## Monta a partida: carrega o mapa, cria o jogador, os bots, o HUD e o modo
## mata-mata, conforme a Sessao. (Na rede, etapa 8, cria também os outros jogadores.)

const CENA_JOGADOR := preload("res://characters/jogador.tscn")
const CENA_HUD := preload("res://ui/hud/hud.tscn")

var mapa: Mapa
var modo: ModoMataMata
var jogador: Jogador
var hud: CanvasLayer


func _ready() -> void:
	Controles.menu_aberto = false
	mapa = load(Sessao.mapa).instantiate()
	add_child(mapa)
	if not mapa.esta_pronto:
		await mapa.pronto
	# A navegação precisa de um quadro de física para sincronizar.
	await get_tree().physics_frame

	modo = ModoMataMata.new()
	modo.name = "Modo"
	modo.mapa = mapa
	modo.abates_para_vencer = Sessao.abates_para_vencer
	modo.duracao = Sessao.duracao_segundos
	add_child(modo)
	modo.partida_terminou.connect(_ao_terminar)

	if Sessao.tipo_rede == Sessao.TipoRede.SOLO:
		jogador = criar_jogador_local()
		var faltam := Sessao.total_participantes - 1
		for i in faltam:
			criar_bot(i)
		modo.iniciar()
		modo.posicionar_todos()
	else:
		Rede.iniciar_partida_em_rede(self)

	hud = CENA_HUD.instantiate()
	add_child(hud)
	hud.configurar(jogador, modo)


func criar_jogador_local(nome := "") -> Jogador:
	var j: Jogador = CENA_JOGADOR.instantiate()
	j.name = "Jogador"
	j.tipo = Jogador.Tipo.LOCAL
	add_child(j)
	modo.adicionar(j, nome if nome != "" else Config.obter("nome_jogador"), false, multiplayer.get_unique_id())
	return j


func criar_bot(indice: int, nome := "") -> Jogador:
	var b: Jogador = CENA_JOGADOR.instantiate()
	b.name = "Bot%d" % indice
	b.tipo = Jogador.Tipo.BOT
	b.personagem_inicial = randi() % 2
	b.skin_inicial = randi() % 8
	var cerebro := CerebroBot.new()
	cerebro.name = "Cerebro"
	cerebro.dificuldade = Sessao.dificuldade
	b.add_child(cerebro)
	add_child(b)
	# Armas: fáceis não usam sniper; os outros às vezes.
	var opcoes: Array = CatalogoArmas.PRINCIPAIS.duplicate()
	if Sessao.dificuldade == 0:
		opcoes.erase("agulha_sr")
		opcoes.erase("coruja_sx")
	b.armas.equipar_armas([opcoes[randi() % opcoes.size()], CatalogoArmas.SECUNDARIAS[randi() % 2]])
	if nome == "":
		var livres: Array = Sessao.NOMES_BOTS.duplicate()
		for p in modo.participantes:
			livres.erase(p.nome)
		nome = livres[randi() % livres.size()]
	modo.adicionar(b, nome, true)
	return b


func _ao_terminar(resultado: Dictionary) -> void:
	Sessao.resultado_ultima = resultado
	# Para todo mundo
	for p in modo.participantes:
		p.no.set_physics_process(false)
		p.no.armas.set_physics_process(false)
		if p.no.has_node("Cerebro"):
			p.no.get_node("Cerebro").set_physics_process(false)
	Controles.menu_aberto = true
	if has_node("/root/Progresso"):
		var meu := {}
		for linha in resultado.tabela:
			if linha.local:
				meu = linha
		resultado["recompensas"] = get_node("/root/Progresso").registrar_partida(meu, resultado)
	hud.mostrar_fim(resultado)
