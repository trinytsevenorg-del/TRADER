extends Node3D
class_name CameraTPS
## Câmera em terceira pessoa "por cima do ombro".
##
## Estrutura (montada em jogador.tscn):
##   CameraRig (este nó, top_level: não herda a posição do pai)   -> gira no eixo Y (yaw)
##     Pitch                                                       -> gira no eixo X (olhar p/ cima/baixo)
##       BracoOmbro (SpringArm3D, aponta para a direita)           -> desloca para o ombro
##         Ponta
##           Braco (SpringArm3D, aponta para trás)                 -> distância da câmera
##             Camera3D
##
## Os dois SpringArm3D fazem um "raio" contra o cenário: se tiver parede no
## caminho, a câmera encosta antes dela, então ela nunca atravessa paredes
## (nem para o lado, quando o ombro encosta numa parede).

## Explorando: câmera longe e alta, vendo bastante do mapa (personagem pequeno na tela).
## Mirando: câmera vem para perto do ombro.
@export var altura := 1.7             ## altura do ponto de foco (acima dos pés)
@export var ombro := 0.3              ## deslocamento lateral (direita) explorando
@export var ombro_mira := 0.65        ## deslocamento lateral mirando
@export var distancia := 5.4          ## distância explorando
@export var distancia_mira := 1.7     ## distância ao mirar
@export var fov_normal := 70.0
@export var fov_mira := 60.0
@export var pitch_min_graus := -70.0
@export var pitch_max_graus := 65.0
## Suavidade de seguir o personagem (maior = mais "grudado").
@export var seguir_horizontal := 24.0
@export var seguir_vertical := 12.0
@export var velocidade_transicao_mira := 9.0  ## maior = transição mais rápida

var yaw := 0.0
var pitch := deg_to_rad(-22.0)
var mirando := false
## Multiplicador de zoom da arma (as snipers vão usar isto na etapa 3).
var zoom_arma := 1.0

var alvo: Node3D
var _mira_t := 0.0  # 0 = normal, 1 = mirando (interpolado)

@onready var _pitch: Node3D = $Pitch
@onready var _braco_ombro: SpringArm3D = $Pitch/BracoOmbro
@onready var _ponta: Node3D = $Pitch/BracoOmbro/Ponta
@onready var _braco: SpringArm3D = $Pitch/BracoOmbro/Ponta/Braco
@onready var camera: Camera3D = $Pitch/BracoOmbro/Ponta/Braco/Camera3D


func _ready() -> void:
	alvo = get_parent() as Node3D
	top_level = true

	# Braço do ombro aponta para +X (SpringArm estica no seu eixo +Z).
	_braco_ombro.rotation = Vector3(0, PI / 2.0, 0)
	_ponta.rotation = Vector3(0, -PI / 2.0, 0)  # desfaz a rotação
	var esfera := SphereShape3D.new()
	esfera.radius = 0.18  # um pouco maior que o "near" da câmera: não corta paredes
	for braco in [_braco_ombro, _braco]:
		braco.shape = esfera
		braco.collision_mask = 1  # só o cenário (camada "mundo")
		braco.margin = 0.05
		if alvo is CollisionObject3D:
			braco.add_excluded_object(alvo.get_rid())
	_braco_ombro.spring_length = ombro
	_braco.spring_length = distancia

	camera.near = 0.05
	camera.far = 250.0
	camera.fov = fov_normal
	yaw = alvo.rotation.y
	encaixar()


## Teleporta a câmera direto para o alvo (use após renascer).
func encaixar() -> void:
	global_position = _ponto_foco()
	_aplicar_rotacao()


func _ponto_foco() -> Vector3:
	return alvo.global_position + Vector3.UP * altura


func _process(delta: float) -> void:
	# 1) Rotação: aplicada na hora (sem suavizar) para a mira ser responsiva.
	if alvo.get("controlado_localmente") != false:
		var olhar := Controles.consumir_olhar()
		if mirando:
			olhar *= float(Config.obter("sens_mira")) / zoom_arma
		var inv := -1.0 if Config.obter("inverter_y") else 1.0
		yaw -= olhar.x
		pitch = clamp(pitch - olhar.y * inv, deg_to_rad(pitch_min_graus), deg_to_rad(pitch_max_graus))
	_aplicar_rotacao()

	# 2) Posição: segue o personagem com suavização exponencial
	#    (independe do FPS). Vertical mais suave para pulos não "chacoalharem".
	var destino := _ponto_foco()
	var p := global_position
	var kh := 1.0 - exp(-seguir_horizontal * delta)
	var kv := 1.0 - exp(-seguir_vertical * delta)
	p.x = lerp(p.x, destino.x, kh)
	p.z = lerp(p.z, destino.z, kh)
	p.y = lerp(p.y, destino.y, kv)
	global_position = p

	# 3) Transição de mira: aproxima a câmera e fecha o FOV.
	_mira_t = move_toward(_mira_t, 1.0 if mirando else 0.0, delta * velocidade_transicao_mira * 0.5)
	var t := ease(_mira_t, -2.0)  # suaviza começo e fim
	_braco.spring_length = lerp(distancia, distancia_mira, t)
	_braco_ombro.spring_length = lerp(ombro, ombro_mira, t)
	camera.fov = lerp(fov_normal, fov_mira / zoom_arma, t)


func _aplicar_rotacao() -> void:
	rotation = Vector3(0, yaw, 0)
	_pitch.rotation = Vector3(pitch, 0, 0)


## Direção "para frente" da câmera no plano do chão.
func frente_plana() -> Vector3:
	return Vector3(0, 0, -1).rotated(Vector3.UP, yaw)


## Raio a partir do centro da tela: devolve o ponto que a mira está apontando.
## (Usado pelas armas na etapa 3.)
func ponto_mirado(alcance: float = 200.0, mascara: int = 1 | 4) -> Vector3:
	var origem := camera.global_position
	var dir := -camera.global_basis.z
	var consulta := PhysicsRayQueryParameters3D.create(origem, origem + dir * alcance, mascara)
	if alvo is CollisionObject3D:
		consulta.exclude = [alvo.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(consulta)
	return hit.position if hit else origem + dir * alcance
