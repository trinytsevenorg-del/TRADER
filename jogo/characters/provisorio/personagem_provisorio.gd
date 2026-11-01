extends Node3D
## Personagem PROVISÓRIO low-poly gerado por código (até chegarem os .glb).
##
## Contrato que todo modelo de personagem deve cumprir (o provisório e os .glb
## da etapa 6): ter o método atualizar_animacao(estado, fator_velocidade, mirando).
## Assim, trocar o modelo não exige mexer no script do jogador.
##
## As cores são exportadas: as skins (etapa 7) só trocam essas cores/materiais.

@export var cor_roupa := Color(0.15, 0.45, 0.85)
@export var cor_calca := Color(0.18, 0.18, 0.22)
@export var cor_pele := Color(0.93, 0.75, 0.6)
@export var cor_detalhe := Color(0.95, 0.55, 0.1)

var _fase := 0.0
var _quadril: Node3D
var _tronco: Node3D
var _braco_e: Node3D
var _braco_d: Node3D
var _perna_e: Node3D
var _perna_d: Node3D


func _ready() -> void:
	var m_roupa := _material(cor_roupa)
	var m_calca := _material(cor_calca)
	var m_pele := _material(cor_pele)
	var m_det := _material(cor_detalhe)

	_quadril = _pivo(self, Vector3(0, 0.95, 0))
	_tronco = _pivo(_quadril, Vector3.ZERO)
	_caixa(_tronco, Vector3(0, 0.3, 0), Vector3(0.46, 0.6, 0.26), m_roupa)
	_caixa(_tronco, Vector3(0, 0.38, 0.16), Vector3(0.36, 0.34, 0.08), m_det)  # mochila (costas = +Z)
	var cabeca := _caixa(_tronco, Vector3(0, 0.78, 0), Vector3(0.26, 0.28, 0.26), m_pele)
	_caixa(cabeca, Vector3(0, 0.03, -0.13), Vector3(0.2, 0.07, 0.02), m_calca)  # viseira (frente = -Z)

	_braco_e = _pivo(_tronco, Vector3(-0.31, 0.56, 0))
	_braco_d = _pivo(_tronco, Vector3(0.31, 0.56, 0))
	for b in [_braco_e, _braco_d]:
		_caixa(b, Vector3(0, -0.25, 0), Vector3(0.14, 0.52, 0.14), m_roupa)
		_caixa(b, Vector3(0, -0.56, 0), Vector3(0.12, 0.12, 0.12), m_pele)

	_perna_e = _pivo(_quadril, Vector3(-0.12, 0, 0))
	_perna_d = _pivo(_quadril, Vector3(0.12, 0, 0))
	for p in [_perna_e, _perna_d]:
		_caixa(p, Vector3(0, -0.45, 0), Vector3(0.18, 0.9, 0.2), m_calca)
		_caixa(p, Vector3(0, -0.9, -0.05), Vector3(0.19, 0.1, 0.3), m_det)


## Animação procedural simples (balanço de braços/pernas).
func atualizar_animacao(estado: StringName, fator_vel: float, mirando: bool) -> void:
	var dt := get_physics_process_delta_time()
	fator_vel = clamp(fator_vel, 0.0, 1.5)
	var amplitude := 0.0
	var inclinacao := 0.0
	match estado:
		&"correndo":
			_fase += dt * (7.0 + 5.0 * fator_vel)
			amplitude = 0.9 * fator_vel
			inclinacao = -0.18 * fator_vel
		&"pulando", &"caindo":
			amplitude = 0.0
		_:
			_fase += dt * 2.0
	var s := sin(_fase)
	var k := 1.0 - exp(-18.0 * dt)
	_perna_e.rotation.x = lerp(_perna_e.rotation.x, s * amplitude if amplitude > 0.0 else _pose_ar(estado, 1.0), k)
	_perna_d.rotation.x = lerp(_perna_d.rotation.x, -s * amplitude if amplitude > 0.0 else _pose_ar(estado, -1.0), k)
	if mirando or _mirando_forcado:
		# Braços "segurando a arma" apontados para frente.
		_braco_d.rotation.x = lerp(_braco_d.rotation.x, PI / 2.0, k)
		_braco_e.rotation.x = lerp(_braco_e.rotation.x, PI / 2.2, k)
	else:
		_braco_e.rotation.x = lerp(_braco_e.rotation.x, -s * amplitude * 0.8, k)
		_braco_d.rotation.x = lerp(_braco_d.rotation.x, s * amplitude * 0.8, k)
	_tronco.rotation.x = lerp(_tronco.rotation.x, inclinacao, k)
	# Leve "quique" do quadril ao correr; respiração parado.
	_quadril.position.y = 0.95 + abs(s) * 0.05 * amplitude + (sin(_fase) * 0.01 if amplitude == 0.0 else 0.0)


func _pose_ar(estado: StringName, lado: float) -> float:
	if estado == &"pulando" or estado == &"caindo":
		return 0.5 * lado - 0.2  # uma perna à frente, outra atrás
	return 0.0


func _material(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 0.8
	return m


func _pivo(pai: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	pai.add_child(n)
	return n


func _caixa(pai: Node3D, pos: Vector3, tamanho: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var malha := BoxMesh.new()
	malha.size = tamanho
	mi.mesh = malha
	mi.material_override = mat
	mi.position = pos
	pai.add_child(mi)
	return mi


## Contrato com o jogador: parte de cima mirando (aqui: braço levantado).
var _mirando_forcado := false
func definir_mira(peso: float, _pitch: float) -> void:
	_mirando_forcado = peso > 0.5


var _arma: Node3D
func prender_arma(cena: PackedScene) -> Node3D:
	if _arma:
		_arma.queue_free()
	if cena == null:
		return null
	_arma = cena.instantiate()
	_braco_d.add_child(_arma)
	# Braço levantado (rotação x = 90°) aponta para frente; a arma fica na mão.
	_arma.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, -0.56, 0))
	return _arma
