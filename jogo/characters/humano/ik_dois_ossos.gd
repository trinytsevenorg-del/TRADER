extends SkeletonModifier3D
class_name IKDoisOssos
## IK analítico de dois ossos (ombro → cotovelo → mão) para colocar a mão
## EXATAMENTE num ponto da arma (cabo ou guarda-mão).
##
## Roda depois do AnimationTree (é um SkeletonModifier3D da Godot 4.3): a animação
## define a pose e este modificador corrige só o braço. "influence" (0..1, herdado)
## mistura com a pose animada — 0 desliga suavemente (rolamento, escalada...).
##
## O cotovelo dobra para o mesmo lado em que já estava na animação (mais natural),
## puxado de leve para baixo/fora por "dica_cotovelo".

@export var osso_braco := "upperarm_l"
@export var osso_antebraco := "lowerarm_l"
@export var osso_mao := "hand_l"
## Alvo (normalmente um Marker3D da arma).
var alvo: Node3D
## Também gira a mão para a orientação do alvo (empunhadura).
@export var girar_mao := false
## Correção da orientação da mão em relação ao alvo (calibrada pelo modelo).
var ajuste_mao := Transform3D.IDENTITY
## Direção (espaço do esqueleto) para onde o cotovelo tende a apontar.
@export var dica_cotovelo := Vector3(0, -1, 0)
## Fecha os dedos desta mão copiando a pose dos dedos da OUTRA mão (que já
## segura o cabo na animação). Pares [osso_destino, osso_origem].
var copiar_dedos: Array = []
## Como converter a rotação local de um lado para o outro (espelho): multiplica x,y,z,w.
var espelho_dedos := Vector4(1, 1, 1, 1)

var _i_braco := -1
var _i_antebraco := -1
var _i_mao := -1


func configurar(braco: String, antebraco: String, mao: String) -> void:
	osso_braco = braco
	osso_antebraco = antebraco
	osso_mao = mao
	_i_braco = -1


func _resolver_indices(esq: Skeleton3D) -> bool:
	if _i_braco < 0:
		_i_braco = esq.find_bone(osso_braco)
		_i_antebraco = esq.find_bone(osso_antebraco)
		_i_mao = esq.find_bone(osso_mao)
	return _i_braco >= 0 and _i_antebraco >= 0 and _i_mao >= 0


func _process_modification() -> void:
	var esq := get_skeleton()
	if esq == null or alvo == null or not is_instance_valid(alvo) or not _resolver_indices(esq):
		return
	var alvo_xf: Transform3D = esq.global_transform.affine_inverse() * alvo.global_transform * ajuste_mao

	var g_braco := esq.get_bone_global_pose(_i_braco)
	var g_ante := esq.get_bone_global_pose(_i_antebraco)
	var g_mao := esq.get_bone_global_pose(_i_mao)
	var a := g_braco.origin
	var b := g_ante.origin
	var c := g_mao.origin
	var t := alvo_xf.origin
	var comp_a := a.distance_to(b)
	var comp_b := b.distance_to(c)
	var para_alvo := t - a
	var d := clampf(para_alvo.length(), 0.01, comp_a + comp_b - 0.001)
	var dir := para_alvo.normalized()

	# Lado do cotovelo: o atual (da animação) + a dica, sem componente na direção do alvo
	var polo := (b - a) + dica_cotovelo * 0.3
	polo = (polo - dir * polo.dot(dir))
	if polo.length_squared() < 1e-6:
		polo = dica_cotovelo - dir * dica_cotovelo.dot(dir)
	polo = polo.normalized()

	# Lei dos cossenos: ângulo no ombro
	var cos_a := clampf((comp_a * comp_a + d * d - comp_b * comp_b) / (2.0 * comp_a * d), -1.0, 1.0)
	var sin_a := sqrt(1.0 - cos_a * cos_a)
	var novo_b := a + dir * (comp_a * cos_a) + polo * (comp_a * sin_a)

	# 1) Gira o braço para o cotovelo ir para novo_b
	var rot_braco := _rotacao_entre(b - a, novo_b - a)
	var novo_g_braco := Transform3D(Basis(rot_braco) * g_braco.basis, a)
	_definir_global(esq, _i_braco, novo_g_braco)
	# 2) Gira o antebraço para a mão ir para o alvo
	var g_ante2 := esq.get_bone_global_pose(_i_antebraco)
	var g_mao2 := esq.get_bone_global_pose(_i_mao)
	var rot_ante := _rotacao_entre(g_mao2.origin - g_ante2.origin, t - g_ante2.origin)
	_definir_global(esq, _i_antebraco, Transform3D(Basis(rot_ante) * g_ante2.basis, g_ante2.origin))
	# 3) Dedos fechados na arma (cópia espelhada da outra mão)
	for par in copiar_dedos:
		var q := esq.get_bone_pose_rotation(par[1])
		esq.set_bone_pose_rotation(par[0], Quaternion(q.x * espelho_dedos.x, q.y * espelho_dedos.y, q.z * espelho_dedos.z, q.w * espelho_dedos.w).normalized())
	# 4) Orientação da mão (empunhadura)
	if girar_mao:
		var g_mao3 := esq.get_bone_global_pose(_i_mao)
		_definir_global(esq, _i_mao, Transform3D(alvo_xf.basis.orthonormalized().scaled(g_mao3.basis.get_scale()), g_mao3.origin))


static func _rotacao_entre(de: Vector3, para: Vector3) -> Quaternion:
	var u := de.normalized()
	var v := para.normalized()
	var dot := u.dot(v)
	if dot > 0.99999:
		return Quaternion.IDENTITY
	if dot < -0.99999:
		var eixo := u.cross(Vector3.UP)
		if eixo.length_squared() < 1e-6:
			eixo = u.cross(Vector3.RIGHT)
		return Quaternion(eixo.normalized(), PI)
	return Quaternion(u.cross(v).normalized(), acos(dot))


## Define a pose GLOBAL (espaço do esqueleto) de um osso convertendo para local.
static func _definir_global(esq: Skeleton3D, osso: int, global: Transform3D) -> void:
	var pai := esq.get_bone_parent(osso)
	var local := global
	if pai >= 0:
		local = esq.get_bone_global_pose(pai).affine_inverse() * global
	esq.set_bone_pose_rotation(osso, local.basis.get_rotation_quaternion())
