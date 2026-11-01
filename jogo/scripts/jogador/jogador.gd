extends CharacterBody3D
class_name Jogador
## Personagem controlável — ETAPAS 1 e 2: movimento, câmera, parkour e rolamento.
##
## Modos (máquina de estados simples, em _physics_process):
##   NORMAL      andando/correndo no chão ou no ar (pulo, pulo duplo)
##   PAREDE      correndo/deslizando pela parede (wall run)
##   SUBINDO     correndo parede acima (de frente para a parede)
##   ESCALANDO   subindo numa beirada (movimento guiado, sem física)
##   ROLANDO     cambalhota com invencibilidade curta
##   DESLIZANDO  deslize no chão depois de correr
##
## Como funciona o parkour (igual ao que você descreveu):
##  - No ar, ao lado de uma parede, aperte PULAR: gruda e corre pela parede,
##    escorregando devagar para baixo. PULAR de novo: salta para longe da parede.
##  - No ar, DE FRENTE para a parede, aperte PULAR: corre parede acima.
##  - Beiradas ao alcance das mãos são agarradas e escaladas sozinhas.
##  - Sem parede por perto, PULAR no ar = pulo duplo.
##  - ROLAR: cambalhota rápida (0,3 s invencível). No ar, fica guardada e sai ao aterrissar.
##  - DESLIZAR correndo: desliza no chão. Cair de alto correndo também desliza sozinho.
##
## Fluidez: nenhuma ação "mata" a velocidade; cada transição herda o embalo.

signal estado_mudou(novo: StringName)

enum Modo { NORMAL, PAREDE, SUBINDO, ESCALANDO, ROLANDO, DESLIZANDO }

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

@export_group("Rolamento")
@export var velocidade_rolamento := 10.5
@export var duracao_rolamento := 0.45
@export var invencibilidade_rolamento := 0.3
@export var recarga_rolamento := 0.8

@export_group("Deslize")
@export var velocidade_min_deslize := 5.0
@export var bonus_deslize := 1.15
@export var atrito_deslize := 7.0
@export var duracao_max_deslize := 1.0
## Cair com velocidade vertical maior que isto (correndo) já entra deslizando.
@export var queda_para_deslize := 13.0

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

## Falso para jogadores remotos e bots (etapas 5 e 8).
var controlado_localmente := true
var mirando := false
## Verdadeiro durante a janela de invencibilidade do rolamento (o dano checa isto).
var invencivel := false
var estado: StringName = &"parado"
var modo: Modo = Modo.NORMAL

var _tempo_fora_do_chao := 0.0
var _buffer_pulo := 0.0
var _buffer_rolar := 0.0
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
var _controle_reduzido := 0.0    # após pulo de parede, o joystick quase não muda a trajetória  # inclinação visual do corpo (x = frente, y = lado)

@onready var visual: Node3D = $Visual
@onready var camera_rig: CameraTPS = $CameraRig
@onready var _colisao: CollisionShape3D = $Colisao
## Modelo 3D (provisório ou .glb). Precisa ter o método atualizar_animacao().
var modelo: Node


func _ready() -> void:
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
	floor_stop_on_slope = true
	# Forma própria (não compartilhada) para poder agachar no rolamento/deslize.
	_colisao.shape = _colisao.shape.duplicate()
	if controlado_localmente:
		trocar_modelo(Config.obter("personagem"), Config.obter("skin"))
		Config.alterado.connect(func(chave, _v):
			if chave == "personagem" or chave == "skin":
				trocar_modelo(Config.obter("personagem"), Config.obter("skin")))
	else:
		_achar_modelo()


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


func _achar_modelo() -> void:
	for filho in visual.get_children():
		if filho.has_method("atualizar_animacao"):
			modelo = filho
			return


# =========================================================================
#  LAÇO PRINCIPAL
# =========================================================================

func _physics_process(delta: float) -> void:
	var entrada := Controles.obter_movimento() if controlado_localmente else Vector2.ZERO
	var direcao := Vector3(entrada.x, 0.0, entrada.y).rotated(Vector3.UP, camera_rig.yaw)

	mirando = controlado_localmente and Input.is_action_pressed("mirar")
	camera_rig.mirando = mirando

	_tempo_modo += delta
	_recarga_rolar -= delta
	_recarga_parede -= delta
	_controle_reduzido -= delta
	if controlado_localmente and Input.is_action_just_pressed("pular"):
		_buffer_pulo = tempo_buffer_pulo
	else:
		_buffer_pulo -= delta
	if controlado_localmente and Input.is_action_just_pressed("rolar"):
		_buffer_rolar = 0.25
	else:
		_buffer_rolar -= delta
	var quer_deslizar := controlado_localmente and Input.is_action_just_pressed("deslizar")

	match modo:
		Modo.NORMAL:
			_modo_normal(direcao, quer_deslizar, delta)
		Modo.PAREDE:
			_modo_parede(direcao, delta)
		Modo.SUBINDO:
			_modo_subindo(direcao, delta)
		Modo.ESCALANDO:
			_modo_escalando(delta)
		Modo.ROLANDO:
			_modo_rolando(direcao, delta)
		Modo.DESLIZANDO:
			_modo_deslizando(direcao, delta)

	invencivel = modo == Modo.ROLANDO and _tempo_modo < invencibilidade_rolamento
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

	# Pulo / ações de parede / pulo duplo
	if _buffer_pulo > 0.0:
		if _tempo_fora_do_chao <= tempo_coyote and not _pulando:
			_pular(velocidade_pulo)
		elif not no_chao and _tentar_parede(direcao):
			_buffer_pulo = 0.0
			return
		elif not no_chao and _pulo_duplo_disponivel and _tempo_fora_do_chao > tempo_coyote:
			_pulo_duplo_disponivel = false
			_pular(velocidade_pulo_duplo)
	if pulo_variavel and _pulando and velocity.y > 0.0 and not Input.is_action_pressed("pular"):
		velocity.y *= mult_pulo_curto
		_pulando = false

	# Movimento horizontal relativo à câmera
	var alvo := direcao * velocidade_corrida  # joystick pela metade = andar devagar
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
	if not is_on_floor() and direcao.length_squared() > 0.25 and _tentar_beirada(direcao):
		return

	# Aterrissou
	if is_on_floor() and estava_no_ar:
		var vel_h := Vector2(velocity.x, velocity.z).length()
		if _buffer_rolar > 0.0 and _recarga_rolar <= 0.0:
			_iniciar_rolamento(direcao)
			return
		if _vel_queda_anterior < -queda_para_deslize and vel_h > velocidade_min_deslize:
			_iniciar_deslize()
			return

	# Rolar / deslizar no chão
	if is_on_floor():
		if _buffer_rolar > 0.0 and _recarga_rolar <= 0.0:
			_iniciar_rolamento(direcao)
		elif quer_deslizar and Vector2(velocity.x, velocity.z).length() > velocidade_min_deslize:
			_iniciar_deslize()


func _pular(forca: float) -> void:
	velocity.y = forca
	_buffer_pulo = 0.0
	_tempo_fora_do_chao = tempo_coyote + 1.0  # impede pulo extra pelo coyote
	_pulando = true


# =========================================================================
#  PAREDE: grudar e correr pela parede / subir parede
# =========================================================================

## Procura parede ao lado (wall run) ou à frente (subir). Devolve true se grudou.
func _tentar_parede(direcao: Vector3) -> bool:
	if _recarga_parede > 0.0:
		return false
	var frente := _frente_modelo()
	if direcao.length_squared() > 0.04:
		frente = direcao.normalized()
	var lado := frente.cross(Vector3.UP).normalized()  # direita

	# 1) De frente para a parede: corre parede acima.
	var hit_frente := _raio_parede(frente, RAIO + 0.55)
	if hit_frente and frente.dot(-hit_frente.normal) > 0.75:
		_normal_parede = hit_frente.normal
		velocity = Vector3(0, velocidade_subida_parede, 0)
		_mudar_modo(Modo.SUBINDO)
		return true

	# 2) Ao lado: corre pela parede.
	for s in [1.0, -1.0]:
		var hit := _raio_parede(lado * s, RAIO + 0.8)  # generoso: no celular é difícil acertar a distância
		if hit:
			_grudar_na_parede(hit.normal, frente)
			return true
	# 3) Parede na diagonal da frente (chegou meio torto).
	for s in [1.0, -1.0]:
		var diag: Vector3 = (frente + lado * s).normalized()
		var hit := _raio_parede(diag, RAIO + 0.6)
		if hit:
			_grudar_na_parede(hit.normal, frente)
			return true
	return false


func _grudar_na_parede(normal: Vector3, frente: Vector3) -> void:
	_normal_parede = normal
	# Direção ao longo da parede, para o lado em que o jogador já ia.
	var tangente := normal.cross(Vector3.UP).normalized()
	var referencia := Vector3(velocity.x, 0, velocity.z)
	if referencia.length_squared() < 1.0:
		referencia = frente
	if tangente.dot(referencia) < 0.0:
		tangente = -tangente
	_direcao_parede = tangente
	var vel_h := maxf(referencia.length(), velocidade_parede)
	velocity = tangente * vel_h + Vector3.UP * impulso_inicial_parede
	_pulo_duplo_disponivel = true
	_mudar_modo(Modo.PAREDE)


func _modo_parede(direcao: Vector3, delta: float) -> void:
	# Pulo de parede: para longe da parede, mantendo o embalo.
	if _buffer_pulo > 0.0:
		_buffer_pulo = 0.0
		var saida := (_normal_parede * pulo_parede_lateral + _direcao_parede * velocidade_parede * 0.85)
		velocity = Vector3(saida.x, pulo_parede_vertical, saida.z)
		_recarga_parede = 0.2
		_controle_reduzido = 0.35
		_pulando = true
		_tempo_fora_do_chao = tempo_coyote + 1.0
		_mudar_modo(Modo.NORMAL)
		return

	# Escorrega devagar (gravidade reduzida) e corre ao longo da parede.
	velocity.y = max(velocity.y - gravidade * gravidade_parede * delta, -3.0)
	var vel_h := maxf(Vector2(velocity.x, velocity.z).length(), velocidade_parede)
	velocity.x = _direcao_parede.x * vel_h - _normal_parede.x * 1.5  # leve "puxão" para a parede
	velocity.z = _direcao_parede.z * vel_h - _normal_parede.z * 1.5
	move_and_slide()

	# Saída: acabou o tempo, a parede acabou, encostou no chão ou puxou para longe.
	var ainda_tem_parede := _raio_parede(-_normal_parede, RAIO + 0.7)
	var puxando_para_fora := direcao.dot(_normal_parede) > 0.7
	if ainda_tem_parede:
		_normal_parede = ainda_tem_parede.normal
	if is_on_floor() or not ainda_tem_parede or _tempo_modo > duracao_parede or puxando_para_fora:
		_recarga_parede = 0.25
		velocity += _normal_parede * 1.0
		_mudar_modo(Modo.NORMAL)


func _modo_subindo(direcao: Vector3, delta: float) -> void:
	velocity = -_normal_parede * 1.0 + Vector3.UP * velocidade_subida_parede * (1.0 - _tempo_modo / duracao_subida_parede * 0.4)
	move_and_slide()
	if _tentar_beirada(-_normal_parede):
		return
	# Pulo durante a subida: salto para trás (vira de costas para a parede).
	if _buffer_pulo > 0.0 and _tempo_modo > 0.08:
		_buffer_pulo = 0.0
		velocity = _normal_parede * pulo_parede_lateral + Vector3.UP * pulo_parede_vertical
		_recarga_parede = 0.2
		_controle_reduzido = 0.35
		_mudar_modo(Modo.NORMAL)
		return
	if _tempo_modo > duracao_subida_parede or not _raio_parede(-_normal_parede, RAIO + 0.7):
		velocity = _normal_parede * 1.5 + Vector3.UP * 1.0
		_recarga_parede = 0.3
		_mudar_modo(Modo.NORMAL)


## Raio horizontal na altura do peito procurando parede "de pé".
func _raio_parede(dir: Vector3, alcance: float) -> Dictionary:
	var origem := global_position + Vector3.UP * 1.0
	var q := PhysicsRayQueryParameters3D.create(origem, origem + dir * alcance, 1)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and abs(hit.normal.y) < 0.3:
		return hit
	return {}


# =========================================================================
#  ESCALAR BEIRADA
# =========================================================================

## Se houver uma beirada ao alcance à frente, começa a escalar. Devolve true se começou.
func _tentar_beirada(direcao: Vector3) -> bool:
	var frente := Vector3(direcao.x, 0, direcao.z).normalized()
	var parede := _raio_parede(frente, RAIO + 0.45)
	if not parede or frente.dot(-parede.normal) < 0.6:
		return false
	# Raio de cima para baixo, logo depois da borda da parede.
	var ponto: Vector3 = parede.position - parede.normal * 0.45
	var topo_busca := global_position.y + alcance_beirada + 0.1
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(ponto.x, topo_busca, ponto.z), Vector3(ponto.x, global_position.y + 0.4, ponto.z), 1)
	q.exclude = [get_rid()]
	var chao := get_world_3d().direct_space_state.intersect_ray(q)
	if not chao or chao.normal.y < 0.75:
		return false
	var destino: Vector3 = chao.position + Vector3.UP * 0.05
	if not _espaco_livre(destino, ALTURA_EM_PE):
		return false
	_escalada_inicio = global_position
	_escalada_fim = destino
	velocity = Vector3.ZERO
	_mudar_modo(Modo.ESCALANDO)
	return true


func _modo_escalando(_delta: float) -> void:
	# Movimento guiado em "L": primeiro sobe, depois avança por cima da borda.
	var t := clampf(_tempo_modo / duracao_escalada, 0.0, 1.0)
	var sobe := ease(clampf(t / 0.6, 0.0, 1.0), 0.6)
	var avanca := ease(clampf((t - 0.35) / 0.65, 0.0, 1.0), 1.6)
	var p := _escalada_inicio
	p.y = lerpf(_escalada_inicio.y, _escalada_fim.y, sobe)
	p.x = lerpf(_escalada_inicio.x, _escalada_fim.x, avanca)
	p.z = lerpf(_escalada_inicio.z, _escalada_fim.z, avanca)
	global_position = p
	if t >= 1.0:
		# Sai já andando para a frente (não perde o ritmo).
		var frente := (_escalada_fim - _escalada_inicio)
		frente.y = 0
		velocity = frente.normalized() * velocidade_corrida * 0.7
		_pulo_duplo_disponivel = true
		_mudar_modo(Modo.NORMAL)


# =========================================================================
#  ROLAMENTO
# =========================================================================

func _iniciar_rolamento(direcao: Vector3) -> void:
	_buffer_rolar = 0.0
	_dir_acao = direcao.normalized() if direcao.length_squared() > 0.04 else _frente_modelo()
	_mudar_modo(Modo.ROLANDO)
	visual.rotation.y = atan2(-_dir_acao.x, -_dir_acao.z)  # vira na hora para onde rola


func _modo_rolando(direcao: Vector3, delta: float) -> void:
	var t := _tempo_modo / duracao_rolamento
	# Um pouco de controle durante o rolamento (curva suave).
	if direcao.length_squared() > 0.04:
		_dir_acao = _dir_acao.slerp(direcao.normalized(), 3.0 * delta).normalized()
	var vel := lerpf(velocidade_rolamento, velocidade_corrida, t * t)
	velocity.x = _dir_acao.x * vel
	velocity.z = _dir_acao.z * vel
	velocity.y = velocity.y - gravidade * delta if not is_on_floor() else -1.0
	move_and_slide()
	if t >= 1.0 and _espaco_livre(global_position, ALTURA_EM_PE):
		_recarga_rolar = recarga_rolamento
		_mudar_modo(Modo.NORMAL)
	elif _buffer_pulo > 0.0 and t > 0.5 and _espaco_livre(global_position, ALTURA_EM_PE):
		# Pulo no fim do rolamento: emenda direto.
		_recarga_rolar = recarga_rolamento
		_mudar_modo(Modo.NORMAL)
		_pular(velocidade_pulo)


# =========================================================================
#  DESLIZE
# =========================================================================

func _iniciar_deslize() -> void:
	var h := Vector3(velocity.x, 0, velocity.z)
	_dir_acao = h.normalized() if h.length_squared() > 0.1 else _frente_modelo()
	var v := maxf(h.length() * bonus_deslize, velocidade_corrida * bonus_deslize)
	velocity.x = _dir_acao.x * v
	velocity.z = _dir_acao.z * v
	_mudar_modo(Modo.DESLIZANDO)


func _modo_deslizando(direcao: Vector3, delta: float) -> void:
	var h := Vector3(velocity.x, 0, velocity.z)
	var v := maxf(h.length() - atrito_deslize * delta, 0.0)
	if direcao.length_squared() > 0.04:
		_dir_acao = _dir_acao.slerp(direcao.normalized(), 1.5 * delta).normalized()
	# Sem espaço para levantar (ex.: túnel baixo): continua rastejando para a frente.
	if not _espaco_livre(global_position, ALTURA_EM_PE) and direcao.length_squared() > 0.04:
		v = maxf(v, 3.0)
	velocity.x = _dir_acao.x * v
	velocity.z = _dir_acao.z * v
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
	if (v < 3.0 or _tempo_modo > duracao_max_deslize or not is_on_floor()) and livre:
		_mudar_modo(Modo.NORMAL)


# =========================================================================
#  UTILIDADES
# =========================================================================

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
		Modo.SUBINDO, Modo.ESCALANDO:
			alvo_yaw = atan2(_normal_parede.x, _normal_parede.z) if modo == Modo.SUBINDO else visual.rotation.y
		Modo.ROLANDO, Modo.DESLIZANDO:
			alvo_yaw = atan2(-_dir_acao.x, -_dir_acao.z)
			if modo == Modo.DESLIZANDO:
				alvo_incl.x = 0.5  # corpo deitado para trás
		_:
			if mirando:
				alvo_yaw = camera_rig.yaw  # mirando: corpo vira para onde a câmera olha
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
		Modo.ESCALANDO: novo = &"escalando"
		Modo.ROLANDO: novo = &"rolando"
		Modo.DESLIZANDO: novo = &"deslizando"
		_:
			if not is_on_floor():
				novo = &"pulando" if velocity.y > 0.0 else &"caindo"
			elif vel_h > 0.4:
				novo = &"correndo"
			else:
				novo = &"parado"
	if novo != estado:
		estado = novo
		estado_mudou.emit(estado)
	if modelo and modelo.has_method("atualizar_animacao"):
		modelo.atualizar_animacao(estado, vel_h / velocidade_corrida, mirando)


## Teleporta o personagem (renascer, início de partida).
func teleportar(pos: Vector3, yaw: float = 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_mudar_modo(Modo.NORMAL)
	visual.rotation.y = yaw
	camera_rig.yaw = yaw
	camera_rig.encaixar()
