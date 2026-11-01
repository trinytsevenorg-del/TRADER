extends CharacterBody3D
class_name Jogador
## Personagem controlável — ETAPA 1: correr, pular, câmera e controles.
## (Parkour, rolamento e tiro entram nas próximas etapas, neste mesmo script
##  e em componentes separados.)
##
## Dicas de fluidez usadas aqui:
##  - Aceleração/desaceleração com move_toward: arranca rápido, mas sem "teleporte".
##  - "Coyote time": dá para pular alguns milissegundos depois de sair da beirada.
##  - "Buffer" de pulo: apertar pular um pouco antes de tocar o chão ainda conta.
##  - Gravidade maior na descida: pulo mais "seco" e controlável.
##  - O modelo gira suavemente para a direção do movimento (lerp_angle).

signal estado_mudou(novo: StringName)

@export_group("Movimento no chão")
@export var velocidade_corrida := 7.5
@export var aceleracao_chao := 50.0
@export var desaceleracao_chao := 60.0
## Quanto do controle você mantém no ar (aceleração no ar).
@export var aceleracao_ar := 16.0

@export_group("Pulo")
@export var velocidade_pulo := 8.6
@export var gravidade := 24.0
## Multiplicador da gravidade caindo (pulo mais "seco").
@export var mult_gravidade_queda := 1.35
## Se ligado, soltar o botão cedo corta o pulo. Desligado por padrão porque no
## celular a pessoa dá toques rápidos e o pulo sairia sempre curto.
@export var pulo_variavel := false
@export var mult_pulo_curto := 0.55
@export var velocidade_queda_max := 40.0
@export var tempo_coyote := 0.12
@export var tempo_buffer_pulo := 0.13

@export_group("Visual")
@export var velocidade_giro_modelo := 16.0

## Falso para jogadores remotos e bots (etapas 5 e 8).
var controlado_localmente := true
var mirando := false
var estado: StringName = &"parado"

var _tempo_fora_do_chao := 0.0
var _buffer_pulo := 0.0
var _pulando := false

@onready var visual: Node3D = $Visual
@onready var camera_rig: CameraTPS = $CameraRig
## Modelo 3D (provisório ou .glb). Precisa ter o método atualizar_animacao().
var modelo: Node


func _ready() -> void:
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
	floor_stop_on_slope = true
	for filho in visual.get_children():
		if filho.has_method("atualizar_animacao"):
			modelo = filho
			break


func _physics_process(delta: float) -> void:
	var entrada := Controles.obter_movimento() if controlado_localmente else Vector2.ZERO
	var no_chao := is_on_floor()

	# --- Mira (botão segurado) ---
	mirando = controlado_localmente and Input.is_action_pressed("mirar")
	camera_rig.mirando = mirando

	# --- Gravidade ---
	if no_chao:
		_tempo_fora_do_chao = 0.0
		_pulando = false
	else:
		_tempo_fora_do_chao += delta
		var g := gravidade * (mult_gravidade_queda if velocity.y < 0.0 else 1.0)
		velocity.y = max(velocity.y - g * delta, -velocidade_queda_max)

	# --- Pulo com coyote time + buffer ---
	if controlado_localmente and Input.is_action_just_pressed("pular"):
		_buffer_pulo = tempo_buffer_pulo
	else:
		_buffer_pulo -= delta
	if _buffer_pulo > 0.0 and _tempo_fora_do_chao <= tempo_coyote and not _pulando:
		_pular()
	# Pulo variável: soltou o botão subindo -> corta a subida.
	if pulo_variavel and _pulando and velocity.y > 0.0 and not Input.is_action_pressed("pular"):
		velocity.y *= mult_pulo_curto
		_pulando = false

	# --- Movimento horizontal relativo à câmera ---
	var direcao := Vector3(entrada.x, 0.0, entrada.y).rotated(Vector3.UP, camera_rig.yaw)
	var alvo := direcao * velocidade_corrida  # joystick pela metade = andar devagar
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var acel := aceleracao_ar
	if no_chao:
		acel = aceleracao_chao if alvo.length_squared() >= horizontal.length_squared() * 0.98 \
			else desaceleracao_chao
	horizontal = horizontal.move_toward(alvo, acel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()

	_girar_modelo(direcao, delta)
	_atualizar_estado(horizontal.length())


func _pular() -> void:
	velocity.y = velocidade_pulo
	_buffer_pulo = 0.0
	_tempo_fora_do_chao = tempo_coyote + 1.0  # impede pulo duplo pelo coyote
	_pulando = true


func _girar_modelo(direcao: Vector3, delta: float) -> void:
	var alvo_yaw := visual.rotation.y
	if mirando:
		alvo_yaw = camera_rig.yaw  # mirando: corpo vira para onde a câmera olha
	elif direcao.length_squared() > 0.01:
		alvo_yaw = atan2(-direcao.x, -direcao.z)  # frente do modelo = -Z
	visual.rotation.y = lerp_angle(visual.rotation.y, alvo_yaw, 1.0 - exp(-velocidade_giro_modelo * delta))


func _atualizar_estado(vel_horizontal: float) -> void:
	var novo: StringName
	if not is_on_floor():
		novo = &"pulando" if velocity.y > 0.0 else &"caindo"
	elif vel_horizontal > 0.4:
		novo = &"correndo"
	else:
		novo = &"parado"
	if novo != estado:
		estado = novo
		estado_mudou.emit(estado)
	if modelo:
		modelo.atualizar_animacao(estado, vel_horizontal / velocidade_corrida, mirando)


## Teleporta o personagem (renascer, início de partida).
func teleportar(pos: Vector3, yaw: float = 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	visual.rotation.y = yaw
	camera_rig.yaw = yaw
	camera_rig.encaixar()
