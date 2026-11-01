extends CharacterBody3D
class_name Jogador
## Personagem controlável — ETAPAS 1 e 2: movimento, câmera, parkour e rolamento.
##
## Modos (máquina de estados simples, em _physics_process):
##   NORMAL      andando/correndo no chão ou no ar (pulo, pulo duplo)
##   PAREDE      correndo/deslizando pela parede (wall run)
##   SUBINDO     correndo parede acima (de frente para a parede)
##   ESCALANDO   subindo numa beirada (movimento guiado, sem física)
##   PENDURADO   agarrado numa beirada alta (anda de lado, sobe, salta ou solta)
##   ROLANDO     cambalhota com invencibilidade curta
##   DESLIZANDO  deslize no chão depois de correr
##
## Como funciona o parkour (igual ao que você descreveu):
##  - No ar, ao lado de uma parede, aperte PULAR: gruda e corre pela parede,
##    escorregando devagar para baixo. PULAR de novo: salta para longe da parede.
##  - No ar, DE FRENTE para a parede, aperte PULAR: corre parede acima.
##  - Beiradas ao alcance das mãos são agarradas e escaladas sozinhas.
##  - Beirada alta agarrada já caindo: fica PENDURADO. Joystick anda de lado pela
##    borda, PULAR sobe, joystick para trás + PULAR salta para longe, DESLIZAR/ROLAR solta.
##  - Sem parede por perto, PULAR no ar = pulo duplo.
##  - ROLAR: cambalhota rápida (0,3 s invencível). No ar, fica guardada e sai ao aterrissar.
##  - DESLIZAR correndo: desliza no chão. Cair de alto correndo também desliza sozinho.
##
## Fluidez: nenhuma ação "mata" a velocidade; cada transição herda o embalo.

signal estado_mudou(novo: StringName)
signal morreu(atacante: Node)
signal renasceu

enum Modo { NORMAL, PAREDE, SUBINDO, ESCALANDO, ROLANDO, DESLIZANDO, MORTO, PENDURADO }
## LOCAL = você (botões e câmera). BOT = IA (ai/cerebro_bot.gd dá os comandos).
## REMOTO = personagem de outro aparelho: só mostra o que chega pela rede (etapa 8).
enum Tipo { LOCAL, BOT, REMOTO }

@export_group("Movimento no chão")
@export var velocidade_corrida := 7.5
@export var aceleracao_chao := 50.0
@export var desaceleracao_chao := 60.0
## Quanto do controle você mantém no ar (aceleração no ar).
@export var aceleracao_ar := 16.0

@export_group("Pulo")
@export var velocidade_pulo := 9.0
@export var velocidade_pulo_duplo := 8.2
@export var gravidade := 24.0
## Multiplicador da gravidade caindo (pulo mais "seco").
@export var mult_gravidade_queda := 1.35
## Se ligado, soltar o botão cedo corta o pulo (no celular fica estranho).
@export var pulo_variavel := false
@export var mult_pulo_curto := 0.55
@export var velocidade_queda_max := 40.0
@export var tempo_coyote := 0.12
@export var tempo_buffer_pulo := 0.15

@export_group("Parede (wall run)")
@export var velocidade_parede := 8.0
## Tempo máximo grudado na parede.
@export var duracao_parede := 1.6
## Gravidade na parede (fração da normal): baixa = escorrega devagar.
@export var gravidade_parede := 0.22
@export var impulso_inicial_parede := 2.0
@export var pulo_parede_lateral := 6.5
@export var pulo_parede_vertical := 8.8
@export var velocidade_subida_parede := 7.0
@export var duracao_subida_parede := 0.45

@export_group("Escalar beirada")
## Altura máxima da beirada (acima dos pés) que dá para agarrar no ar.
@export var alcance_beirada := 2.3
@export var duracao_escalada := 0.32
## Beirada mais alta que isto (acima dos pés), agarrada já caindo: fica pendurado.
@export var altura_min_pendurar := 1.55
## Velocidade andando de lado pendurado na beirada (m/s).
@export var velocidade_pendurado := 1.8
## Bots sobem sozinhos depois de ficar pendurados este tempo.
@export var tempo_bot_pendurado := 0.35

@export_group("Rolamento")
## Velocidade no começo do rolamento (vai diminuindo suave até a de saída).
@export var velocidade_rolamento := 8.6
@export var velocidade_saida_rolamento := 6.2
@export var duracao_rolamento := 0.7
@export var invencibilidade_rolamento := 0.3
## Curta, para dar para encadear: rolar, atirar, rolar de novo.
@export var recarga_rolamento := 0.35
## Quão rápido o joystick muda a direção durante o rolamento (maior = mais rápido).
@export var controle_rolamento := 9.0

@export_group("Deslize (estilo prancha)")
@export var velocidade_min_deslize := 5.0
@export var bonus_deslize := 1.15
## Atrito baixo: o deslize mantém o embalo como uma prancha.
@export var atrito_deslize := 2.5
@export var duracao_max_deslize := 1.8
## Velocidade de "puxar para o lado" com o joystick (o zigue-zague rápido).
@export var velocidade_lateral_deslize := 7.5
## Quão rápido o lado muda (maior = mais frenético).
@export var aceleracao_lateral_deslize := 75.0
## Quão rápido a direção da prancha faz a curva (rad/s).
@export var curva_deslize := 1.2
## Cair com velocidade vertical maior que isto (correndo) já entra deslizando.
@export var queda_para_deslize := 13.0

@export_group("Aterrissagem")
## Queda alta sem deslizar/rolar: tempo andando devagar para recuperar o equilíbrio.
@export var tempo_recuperacao_queda := 0.25

@export_group("Visual")
@export var velocidade_giro_modelo := 16.0

const ALTURA_EM_PE := 1.8
const ALTURA_AGACHADO := 1.0
const RAIO := 0.35

## Cenas de personagem escolhíveis (índice = Config "personagem").
## Para adicionar um personagem novo, crie a cena e coloque o caminho aqui.
const MODELOS := [
	"res://characters/humano/humano_masculino.tscn",
	"res://characters/humano/humano_feminino.tscn",
]

## Defina ANTES de adicionar à cena (o spawner da partida faz isso).
var tipo: Tipo = Tipo.LOCAL
## Atalho: true só para o jogador deste aparelho.
var controlado_localmente := true
## Nome no placar / feed de abates.
var nome_exibicao := "Você"
## Para bots e remotos: qual personagem/skin usar (o local usa Config).
var personagem_inicial := 0
var skin_inicial := 0
## Comandos (BOT): direção no mundo (comprimento 0..1) e mira.
var comando_direcao := Vector3.ZERO
var yaw_mira := 0.0
var pitch_mira := 0.0
## Proteção ao renascer (invencível por alguns segundos).
@export var tempo_protecao_renascer := 1.5
var _protecao := 0.0
var mirando := false
## Verdadeiro durante a janela de invencibilidade do rolamento (o dano checa isto).
var invencivel := false
var estado: StringName = &"parado"
var modo: Modo = Modo.NORMAL

var _tempo_fora_do_chao := 0.0
var _buffer_pulo := 0.0
var _buffer_rolar := 0.0
var _buffer_deslizar := 0.0
var _pulando := false
var _pulo_duplo_disponivel := true
var _tempo_modo := 0.0           # há quanto tempo está no modo atual
var _recarga_rolar := 0.0
var _recarga_parede := 0.0
var _normal_parede := Vector3.ZERO
var _direcao_parede := Vector3.ZERO
var _dir_acao := Vector3.FORWARD # direção do rolamento/deslize
var _escalada_inicio := Vector3.ZERO
var _escalada_fim := Vector3.ZERO
var _vel_queda_anterior := 0.0
var _inclinacao := Vector2.ZERO
var _controle_reduzido := 0.0
var _vel_lateral := 0.0          # deslize: velocidade para o lado (zigue-zague)    # após pulo de parede, o joystick quase não muda a trajetória  # inclinação visual do corpo (x = frente, y = lado)

## Parkour (parede, beirada, transpor): scripts/jogador/parkour.gd
var parkour: ControladorParkour

@onready var visual: Node3D = $Visual
@onready var camera_rig: CameraTPS = $CameraRig
@onready var _colisao: CollisionShape3D = $Colisao
@onready var armas: PortadorArmas = $Armas
@onready var saude: Saude = $Saude
## Modelo 3D (provisório ou .glb). Precisa ter o método atualizar_animacao().
var modelo: Node


func _ready() -> void:
	parkour = ControladorParkour.new(self)
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
	floor_stop_on_slope = true
	# Forma própria (não compartilhada) para poder agachar no rolamento/deslize.
	_colisao.shape = _colisao.shape.duplicate()
	controlado_localmente = tipo == Tipo.LOCAL
	saude.morreu.connect(_ao_morrer)
	# Animações de tiro e recarga no tronco
	armas.disparou.connect(func(d: DadosArma):
		if modelo and modelo.has_method("tocar_tiro") and d.intervalo() > 0.2:
			modelo.tocar_tiro())
	armas.arma_trocada.connect(func(d: DadosArma):
		if modelo and modelo.has_method("animar_troca"):
			modelo.animar_troca.call_deferred(d.tempo_equipar))
	armas.recarga_iniciada.connect(func(t: float):
		if modelo and modelo.has_method("tocar_recarga"):
			modelo.tocar_recarga(t))
	if not controlado_localmente:
		# Sem câmera própria (economiza os raios das SpringArms).
		camera_rig.process_mode = Node.PROCESS_MODE_DISABLED
		camera_rig.camera.current = false
		yaw_mira = rotation.y
	if controlado_localmente:
		trocar_modelo(Config.obter("personagem"), Config.obter("skin"))
		Config.alterado.connect(func(chave, _v):
			if chave == "personagem" or chave == "skin":
				trocar_modelo(Config.obter("personagem"), Config.obter("skin"))
			elif chave == "arma_principal" or chave == "arma_secundaria":
				_equipar_armas_config())
		_equipar_armas_config.call_deferred()
	else:
		trocar_modelo(personagem_inicial, skin_inicial)


func _equipar_armas_config() -> void:
	armas.equipar_armas([Config.obter("arma_principal"), Config.obter("arma_secundaria")])


## Chamado pelas armas inimigas (hitscan). Devolve o dano aplicado.
## Em rede, só o HOST aplica dano: os clientes enviam o pedido para ele.
func receber_dano(quantidade: float, atacante: Node, ponto: Vector3, cabeca: bool) -> float:
	if Rede.em_partida and not Rede.eh_host():
		if esta_morto() or invencivel:
			return 0.0
		Rede.pedir_dano(self, quantidade, atacante, ponto, cabeca)
		return quantidade
	return saude.receber_dano(quantidade, atacante, ponto, cabeca)


func esta_morto() -> bool:
	return saude.morto


## Yaw/pitch para onde o personagem olha (câmera no local, comando nos outros).
func yaw_visao() -> float:
	return camera_rig.yaw if controlado_localmente else yaw_mira


func pitch_visao() -> float:
	return camera_rig.pitch if controlado_localmente else pitch_mira


## Inclinação do CORPO ao mirar: dos olhos do personagem até o ponto que a mira
## da tela acerta (a câmera fica acima do ombro, então não dá para copiar o pitch dela).
var _pitch_corpo := 0.0
func pitch_corpo() -> float:
	return _pitch_corpo if controlado_localmente else pitch_mira


## Ponto e direção dos olhos (usado pelas armas dos bots e pela IA).
func transform_olhos() -> Transform3D:
	var base := Basis(Vector3.UP, yaw_visao()) * Basis(Vector3.RIGHT, pitch_visao())
	return Transform3D(base, global_position + Vector3.UP * (1.55 if modo != Modo.DESLIZANDO and modo != Modo.ROLANDO else 0.9))


# Comandos (usados pela IA dos bots; o jogador local usa os botões).
func pedir_pulo() -> void:
	_buffer_pulo = tempo_buffer_pulo


func pedir_rolar() -> void:
	_buffer_rolar = 0.3


func pedir_deslizar() -> void:
	_buffer_deslizar = 0.3


func _ao_morrer(atacante: Node) -> void:
	_mudar_modo(Modo.MORTO)
	velocity = Vector3.ZERO
	collision_layer = 0  # tiros e outros personagens atravessam o corpo
	armas.gatilho = false
	morreu.emit(atacante)


## Renasce num ponto: vida cheia, munição cheia e proteção curta.
func renascer(pos: Vector3, yaw: float) -> void:
	saude.reviver()
	armas.reabastecer()
	collision_layer = 2
	teleportar(pos, yaw)
	yaw_mira = yaw
	pitch_mira = 0.0
	_protecao = tempo_protecao_renascer
	var sinc := get_node_or_null("Sincronizador")
	if sinc:
		sinc.limpar()
	renasceu.emit()


## Troca o modelo 3D (personagem e skin) sem mexer em mais nada.
func trocar_modelo(indice: int, skin: int = 0) -> void:
	var caminho: String = MODELOS[clamp(indice, 0, MODELOS.size() - 1)]
	if not ResourceLoader.exists(caminho):
		_achar_modelo()  # sem o modelo: mantém o provisório
		return
	for filho in visual.get_children():
		filho.queue_free()
	var novo: Node3D = load(caminho).instantiate()
	if "skin" in novo:
		novo.skin = skin
	visual.add_child(novo)
	modelo = novo
	if is_node_ready() and armas and not armas.slots.is_empty():
		armas.reprender_modelo.call_deferred()


func _achar_modelo() -> void:
	for filho in visual.get_children():
		if filho.has_method("atualizar_animacao"):
			modelo = filho
			return


# =========================================================================
#  LAÇO PRINCIPAL
# =========================================================================

func _physics_process(delta: float) -> void:
	if tipo == Tipo.REMOTO:
		# Posição/estado vêm da rede (network/sincronizador_personagem.gd).
		_protecao -= delta
		invencivel = estado_remoto == &"rolando" or _protecao > 0.0
		_atualizar_animacao_remota()
		return
	_protecao -= delta
	var direcao: Vector3
	if controlado_localmente:
		var entrada := Controles.obter_movimento()
		direcao = Vector3(entrada.x, 0.0, entrada.y).rotated(Vector3.UP, camera_rig.yaw)
	else:
		direcao = Vector3(comando_direcao.x, 0.0, comando_direcao.z).limit_length(1.0)
	if modo == Modo.MORTO:
		direcao = Vector3.ZERO

	# Corpo vira para a mira ao mirar ou atirar; câmera só aproxima com MIRA
	# ou com armas que têm zoom (fuzis com mira óptica, snipers).
	mirando = armas.mira_botao or armas.gatilho or armas.zoom_ativo or armas.tempo_desde_tiro < 0.6
	if controlado_localmente:
		camera_rig.mirando = armas.mira_botao or armas.zoom_ativo
		camera_rig.zoom_arma = armas.zoom_atual() if armas.zoom_ativo else 1.0
		# Na luneta (zoom forte) o próprio personagem some para não tampar a visão.
		visual.visible = not (armas.zoom_ativo and armas.zoom_atual() >= 2.5 and camera_rig.progresso_mira() > 0.6)

	_tempo_modo += delta
	_recarga_rolar -= delta
	_recarga_parede -= delta
	parkour.recarga_pendurar -= delta
	_controle_reduzido -= delta
	if controlado_localmente and Input.is_action_just_pressed("pular"):
		_buffer_pulo = tempo_buffer_pulo
	else:
		_buffer_pulo -= delta
	# Botões "guardados": apertar um pouco antes da hora (recarga, fim do rolamento)
	# ainda vale, para encadear rolar -> atirar -> rolar -> deslizar sem perder o toque.
	if controlado_localmente and Input.is_action_just_pressed("rolar"):
		_buffer_rolar = recarga_rolamento + 0.1
	else:
		_buffer_rolar -= delta
	if controlado_localmente and Input.is_action_just_pressed("deslizar"):
		_buffer_deslizar = 0.3
	else:
		_buffer_deslizar -= delta
	var quer_deslizar := _buffer_deslizar > 0.0

	match modo:
		Modo.NORMAL:
			_modo_normal(direcao, quer_deslizar, delta)
		Modo.PAREDE:
			parkour.modo_parede(direcao, delta)
		Modo.SUBINDO:
			parkour.modo_subindo(direcao, delta)
		Modo.ESCALANDO:
			parkour.modo_escalando(delta)
		Modo.PENDURADO:
			parkour.modo_pendurado(direcao, delta)
		Modo.ROLANDO:
			_modo_rolando(direcao, delta)
		Modo.DESLIZANDO:
			_modo_deslizando(direcao, delta)
		Modo.MORTO:
			if not is_on_floor():
				velocity.y -= gravidade * delta
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()

	invencivel = (modo == Modo.ROLANDO and _tempo_modo < invencibilidade_rolamento) or _protecao > 0.0
	_girar_modelo(direcao, delta)
	_atualizar_estado()


func _mudar_modo(novo: Modo) -> void:
	modo = novo
	_tempo_modo = 0.0
	var agachado := novo == Modo.ROLANDO or novo == Modo.DESLIZANDO
	_definir_altura(ALTURA_AGACHADO if agachado else ALTURA_EM_PE)


# =========================================================================
#  NORMAL: chão e ar
# =========================================================================

func _modo_normal(direcao: Vector3, quer_deslizar: bool, delta: float) -> void:
	var no_chao := is_on_floor()

	# Gravidade
	if no_chao:
		_tempo_fora_do_chao = 0.0
		_pulando = false
		_pulo_duplo_disponivel = true
	else:
		_tempo_fora_do_chao += delta
		var g := gravidade * (mult_gravidade_queda if velocity.y < 0.0 else 1.0)
		velocity.y = max(velocity.y - g * delta, -velocidade_queda_max)

	# Pulo / transpor obstáculo / ações de parede / pulo duplo
	if _buffer_pulo > 0.0:
		if no_chao and parkour.tentar_transpor(direcao):
			return
		if _tempo_fora_do_chao <= tempo_coyote and not _pulando:
			_pular(velocidade_pulo)
		elif not no_chao and parkour.tentar_parede(direcao):
			_buffer_pulo = 0.0
			return
		elif not no_chao and _pulo_duplo_disponivel and _tempo_fora_do_chao > tempo_coyote:
			_pulo_duplo_disponivel = false
			_pular(velocidade_pulo_duplo)
	if pulo_variavel and _pulando and velocity.y > 0.0 and not Input.is_action_pressed("pular"):
		velocity.y *= mult_pulo_curto
		_pulando = false

	# Movimento horizontal relativo à câmera
	var alvo := direcao * velocidade_corrida * armas.mult_velocidade()  # joystick pela metade = andar devagar
	if _recuperacao > 0.0:
		_recuperacao -= delta
		alvo *= 0.45  # recuperando o equilíbrio depois de uma queda alta
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var acel := aceleracao_ar
	if _controle_reduzido > 0.0:
		acel *= 0.15
	if no_chao:
		acel = aceleracao_chao if alvo.length_squared() >= horizontal.length_squared() * 0.98 \
			else desaceleracao_chao
		horizontal = horizontal.move_toward(alvo, acel * delta)
	else:
		# No ar o embalo é preservado: o joystick acelera na direção dele, mas a
		# velocidade "de lado" (ex.: pulo de parede) só se perde aos poucos.
		if alvo.length_squared() < 0.01:
			horizontal = horizontal.move_toward(Vector3.ZERO, acel * 0.25 * delta)
		else:
			var dir_in := alvo.normalized()
			var ao_longo := horizontal.dot(dir_in)
			var lateral := horizontal - dir_in * ao_longo
			if ao_longo < alvo.length():
				ao_longo = move_toward(ao_longo, alvo.length(), acel * delta)
			lateral = lateral.move_toward(Vector3.ZERO, acel * 0.35 * delta)
			horizontal = dir_in * ao_longo + lateral
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	_vel_queda_anterior = velocity.y
	var estava_no_ar := not no_chao
	move_and_slide()

	# Agarrar beirada automaticamente (no ar, empurrando contra a parede)
	if not is_on_floor() and direcao.length_squared() > 0.25 and parkour.tentar_beirada(direcao):
		return

	# Passos (som) correndo no chão
	if is_on_floor():
		_dist_passo += Vector2(velocity.x, velocity.z).length() * delta
		if _dist_passo > 2.1:
			_dist_passo = 0.0
			_som("passo", -14.0, 0.15)

	# Aterrissou
	if is_on_floor() and estava_no_ar:
		var vel_h := Vector2(velocity.x, velocity.z).length()
		if _vel_queda_anterior < -6.0:
			_som("aterrissar", clampf(-18.0 - _vel_queda_anterior * 0.6, -14.0, -2.0))
		if _buffer_rolar > 0.0 and _recarga_rolar <= 0.0:
			_iniciar_rolamento(direcao)
			return
		if _vel_queda_anterior < -queda_para_deslize and vel_h > velocidade_min_deslize:
			_iniciar_deslize()
			return
		if _vel_queda_anterior < -12.0:
			_recuperacao = tempo_recuperacao_queda

	# Rolar / deslizar no chão
	if is_on_floor():
		if _buffer_rolar > 0.0 and _recarga_rolar <= 0.0:
			_iniciar_rolamento(direcao)
		elif quer_deslizar and Vector2(velocity.x, velocity.z).length() > velocidade_min_deslize:
			_iniciar_deslize()


func _pular(forca: float) -> void:
	velocity.y = forca
	_som("pulo", -8.0)
	_buffer_pulo = 0.0
	_tempo_fora_do_chao = tempo_coyote + 1.0  # impede pulo extra pelo coyote
	_pulando = true


# =========================================================================
#  ROLAMENTO
# =========================================================================

func _iniciar_rolamento(direcao: Vector3) -> void:
	_buffer_rolar = 0.0
	_som("rolar", -6.0)
	_dir_acao = direcao.normalized() if direcao.length_squared() > 0.04 else _frente_modelo()
	_mudar_modo(Modo.ROLANDO)
	visual.rotation.y = atan2(-_dir_acao.x, -_dir_acao.z)  # vira na hora para onde rola


func _modo_rolando(direcao: Vector3, delta: float) -> void:
	var t := _tempo_modo / duracao_rolamento
	# O joystick muda a direção durante o rolamento (resposta rápida, mas suave).
	if direcao.length_squared() > 0.04:
		_dir_acao = _dir_acao.slerp(direcao.normalized(), 1.0 - exp(-controle_rolamento * delta)).normalized()
	# Velocidade cai suavemente do começo ao fim (sem tranco na saída).
	var vel := lerpf(velocidade_rolamento, velocidade_saida_rolamento, ease(clampf(t, 0.0, 1.0), 0.6))
	velocity.x = _dir_acao.x * vel
	velocity.z = _dir_acao.z * vel
	velocity.y = velocity.y - gravidade * delta if not is_on_floor() else -1.0
	move_and_slide()
	var livre := _espaco_livre(global_position, ALTURA_EM_PE)
	if t >= 1.0 and livre:
		_recarga_rolar = recarga_rolamento
		_mudar_modo(Modo.NORMAL)
	elif _buffer_pulo > 0.0 and t > 0.5 and livre:
		# Pulo no fim do rolamento: emenda direto.
		_recarga_rolar = recarga_rolamento
		_mudar_modo(Modo.NORMAL)
		_pular(velocidade_pulo)


# =========================================================================
#  DESLIZE (estilo prancha)
# =========================================================================

func _iniciar_deslize() -> void:
	_buffer_deslizar = 0.0
	_som("deslizar", -7.0)
	var h := Vector3(velocity.x, 0, velocity.z)
	_dir_acao = h.normalized() if h.length_squared() > 0.1 else _frente_modelo()
	var v := maxf(h.length() * bonus_deslize, velocidade_corrida * bonus_deslize)
	velocity.x = _dir_acao.x * v
	velocity.z = _dir_acao.z * v
	_vel_lateral = 0.0
	_mudar_modo(Modo.DESLIZANDO)


func _modo_deslizando(direcao: Vector3, delta: float) -> void:
	# Velocidade "para frente" (ao longo da prancha) cai devagar.
	var h := Vector3(velocity.x, 0, velocity.z)
	var v := maxf(h.dot(_dir_acao) - atrito_deslize * delta, 0.0)
	var lado := _dir_acao.cross(Vector3.UP).normalized()  # direita da prancha
	var entrada_lateral := 0.0
	if direcao.length_squared() > 0.04:
		# Curva suave da prancha na direção do joystick...
		var alvo := direcao.normalized()
		if alvo.dot(_dir_acao) > -0.3:  # puxar para trás não vira a prancha
			_dir_acao = _dir_acao.slerp(alvo, 1.0 - exp(-curva_deslize * delta)).normalized()
			lado = _dir_acao.cross(Vector3.UP).normalized()
		# ...e o "puxão" lateral rápido (o zigue-zague).
		entrada_lateral = clampf(direcao.dot(lado), -1.0, 1.0)
	_vel_lateral = move_toward(_vel_lateral, entrada_lateral * velocidade_lateral_deslize,
		aceleracao_lateral_deslize * delta)
	# Sem espaço para levantar (ex.: túnel baixo): continua rastejando para a frente.
	if not _espaco_livre(global_position, ALTURA_EM_PE) and direcao.length_squared() > 0.04:
		v = maxf(v, 3.0)
	var mov := _dir_acao * v + lado * _vel_lateral
	velocity.x = mov.x
	velocity.z = mov.z
	velocity.y = velocity.y - gravidade * delta if not is_on_floor() else -1.0
	move_and_slide()

	var livre := _espaco_livre(global_position, ALTURA_EM_PE)
	# Pulo saindo do deslize mantém (e aumenta um pouco) a velocidade.
	if _buffer_pulo > 0.0 and livre:
		_mudar_modo(Modo.NORMAL)
		_pular(velocidade_pulo)
		velocity.x *= 1.05
		velocity.z *= 1.05
		return
	# Rolamento direto do deslize (deslizar -> rolar -> deslizar...).
	if _buffer_rolar > 0.0 and _recarga_rolar <= 0.0 and livre:
		_iniciar_rolamento(direcao)
		return
	if (v < 3.5 or _tempo_modo > duracao_max_deslize or not is_on_floor()) and livre:
		_mudar_modo(Modo.NORMAL)


# =========================================================================
#  UTILIDADES
# =========================================================================

var _dist_passo := 0.0
var _recuperacao := 0.0
## Sons do corpo (pulo, passo, rolamento...). Mais baixos para os outros personagens.
func _som(nome: String, volume_db := 0.0, variacao := 0.08) -> void:
	Efeitos.som_3d(nome, global_position + Vector3.UP * 0.3, volume_db - (0.0 if controlado_localmente else 4.0), variacao)


func _frente_modelo() -> Vector3:
	return Vector3(0, 0, -1).rotated(Vector3.UP, visual.rotation.y)


## Muda a altura da cápsula (agachar no rolamento/deslize passa por baixo de coisas).
func _definir_altura(altura: float) -> void:
	var cap := _colisao.shape as CapsuleShape3D
	if is_equal_approx(cap.height, altura):
		return
	cap.height = altura
	_colisao.position.y = altura * 0.5


## Verifica se cabe uma cápsula em pé nesta posição (para levantar ou escalar).
func _espaco_livre(pos_pes: Vector3, altura: float) -> bool:
	var forma := CapsuleShape3D.new()
	forma.radius = RAIO - 0.03
	forma.height = altura - 0.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = Transform3D(Basis(), pos_pes + Vector3.UP * (altura * 0.5 + 0.05))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _girar_modelo(direcao: Vector3, delta: float) -> void:
	var k := 1.0 - exp(-velocidade_giro_modelo * delta)
	var alvo_yaw := visual.rotation.y
	var alvo_incl := Vector2.ZERO
	match modo:
		Modo.PAREDE:
			alvo_yaw = atan2(-_direcao_parede.x, -_direcao_parede.z)
			# Inclina o corpo para longe da parede (pés na parede).
			var lado_parede := signf(_direcao_parede.cross(Vector3.UP).dot(-_normal_parede))
			alvo_incl.y = -0.45 * lado_parede
		Modo.SUBINDO, Modo.ESCALANDO, Modo.PENDURADO:
			alvo_yaw = atan2(_normal_parede.x, _normal_parede.z) if modo != Modo.ESCALANDO else visual.rotation.y
		Modo.ROLANDO:
			alvo_yaw = atan2(-_dir_acao.x, -_dir_acao.z)
		Modo.DESLIZANDO:
			# Como numa prancha: corpo meio de lado, inclinando para dentro da curva.
			alvo_yaw = yaw_visao() if mirando else atan2(-_dir_acao.x, -_dir_acao.z)
			alvo_incl.x = 0.15
			alvo_incl.y = -_vel_lateral / velocidade_lateral_deslize * 0.4
		_:
			if mirando:
				alvo_yaw = yaw_visao()  # mirando: corpo vira para onde a câmera olha
			elif direcao.length_squared() > 0.01:
				alvo_yaw = atan2(-direcao.x, -direcao.z)  # frente do modelo = -Z
	visual.rotation.y = lerp_angle(visual.rotation.y, alvo_yaw, k)
	_inclinacao = _inclinacao.lerp(alvo_incl, k)
	visual.rotation.x = _inclinacao.x
	visual.rotation.z = _inclinacao.y


func _atualizar_estado() -> void:
	var vel_h := Vector2(velocity.x, velocity.z).length()
	var novo: StringName
	match modo:
		Modo.PAREDE: novo = &"parede"
		Modo.SUBINDO: novo = &"subindo_parede"
		Modo.ESCALANDO: novo = &"transpondo" if parkour.transpondo else &"escalando"
		Modo.PENDURADO: novo = &"pendurado"
		Modo.ROLANDO: novo = &"rolando"
		Modo.DESLIZANDO: novo = &"deslizando"
		Modo.MORTO: novo = &"morto"
		_:
			if not is_on_floor():
				novo = &"pulando" if velocity.y > 0.0 else &"caindo"
			elif _recuperacao > 0.0:
				novo = &"aterrissando"
			elif vel_h > 0.4:
				novo = &"correndo"
			else:
				novo = &"parado"
	if novo != estado:
		estado = novo
		estado_mudou.emit(estado)
	if modelo and modelo.has_method("atualizar_animacao"):
		modelo.atualizar_animacao(estado, vel_h / velocidade_corrida, mirando)
	if modelo and modelo.has_method("definir_mira"):
		# Tronco mira junto com a câmera (menos no rolamento e na escalada).
		var pode := modo != Modo.ROLANDO and modo != Modo.ESCALANDO and modo != Modo.PENDURADO
		if controlado_localmente and mirando:
			var alvo := camera_rig.ponto_mirado(80.0, 1)
			var olhos := global_position + Vector3.UP * 1.45
			var d := alvo - olhos
			_pitch_corpo = atan2(d.y, Vector2(d.x, d.z).length())
		var pitch_norm := pitch_corpo() / deg_to_rad(60.0)
		modelo.definir_mira(1.0 if (mirando and pode) else 0.0, pitch_norm)


## Teleporta o personagem (renascer, início de partida).
func teleportar(pos: Vector3, yaw: float = 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	if modo != Modo.MORTO:
		_mudar_modo(Modo.NORMAL)
	else:
		modo = Modo.NORMAL
		_tempo_modo = 0.0
	visual.rotation.y = yaw
	yaw_mira = yaw
	camera_rig.yaw = yaw
	if controlado_localmente:
		camera_rig.encaixar()


# ---- Personagem remoto (etapa 8): estado vem da rede ----
var estado_remoto: StringName = &"parado"
var vel_remota := 0.0
var mirando_remoto := false


func _atualizar_animacao_remota() -> void:
	estado = estado_remoto
	if modelo and modelo.has_method("atualizar_animacao"):
		modelo.atualizar_animacao(estado, vel_remota / velocidade_corrida, mirando_remoto)
	if modelo and modelo.has_method("definir_mira"):
		modelo.definir_mira(1.0 if mirando_remoto else 0.0, pitch_mira / deg_to_rad(60.0))
