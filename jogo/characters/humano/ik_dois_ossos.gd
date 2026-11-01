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
## Dedos fechados numa pose calculada (envolvendo o guarda-mão/cabo):
## pares [osso, rotação local]. Usado no lugar de copiar_dedos quando preenchido.
var curvar_dedos: Array = []

## Osso da base do dedo médio: define o eixo da mão (punho -> dedos). Com ele, o
## cotovelo é escolhido para o antebraço ficar ALINHADO com a mão (pulso reto).
var osso_dedo_medio := ""
var _eixo_mao := Vector3.ZERO
## Parte da torção do pulso que o antebraço assume (0..1).
@export var fracao_torcao := 0.6

## Tronco do personagem (para o braço NUNCA entrar no corpo): por osso da coluna,
## [osso, centro (x,z), y_min, fatias, contorno] no espaço local do osso — contorno
## da pele em fatias de 4 cm e 24 direções, medido da malha pelo modelo.
var tronco: Array = []
## Meia espessura do braço (m), também medida da malha.
var raio_braco := 0.045
var _polo_anterior := Vector3.ZERO
## Encostar de leve (pele com pele) é natural; só proíbe passar disso (m).
const TOLERANCIA_TRONCO := 0.015

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
		var medio := esq.find_bone(osso_dedo_medio)
		if medio >= 0 and _i_mao >= 0:
			var r_mao := esq.get_bone_global_rest(_i_mao)
			var v := esq.get_bone_global_rest(medio).origin - r_mao.origin
			_eixo_mao = (r_mao.basis.orthonormalized().inverse() * v).normalized()
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
	var polo: Vector3
	if girar_mao and _eixo_mao != Vector3.ZERO:
		# Cotovelo ideal: atrás do punho, na linha do eixo da mão (pulso reto).
		var h := (alvo_xf.basis.orthonormalized() * _eixo_mao).normalized()
		var cotovelo_ideal := t - h * comp_b
		polo = (cotovelo_ideal - a) + dica_cotovelo.normalized() * 0.15
	else:
		# a dica manda mais que a pose da animação (cotovelo previsível)
		polo = (b - a).normalized() * 0.35 + dica_cotovelo.normalized()
	polo = (polo - dir * polo.dot(dir))
	if polo.length_squared() < 1e-6:
		polo = dica_cotovelo - dir * dica_cotovelo.dot(dir)
	polo = polo.normalized()

	# Lei dos cossenos: ângulo no ombro
	var cos_a := clampf((comp_a * comp_a + d * d - comp_b * comp_b) / (2.0 * comp_a * d), -1.0, 1.0)
	var sin_a := sqrt(1.0 - cos_a * cos_a)
	var centro_c := a + dir * (comp_a * cos_a)
	if not tronco.is_empty() and sin_a > 0.05:
		polo = _polo_fora_do_tronco(esq, a, t, centro_c, dir, polo, comp_a * sin_a)
	var novo_b := centro_c + polo * (comp_a * sin_a)

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
	for par in curvar_dedos:
		esq.set_bone_pose_rotation(par[0], par[1])
	# 4) Orientação da mão (empunhadura)
	if girar_mao:
		var g_mao3 := esq.get_bone_global_pose(_i_mao)
		_definir_global(esq, _i_mao, Transform3D(alvo_xf.basis.orthonormalized().scaled(g_mao3.basis.get_scale()), g_mao3.origin))
		_repartir_torcao(esq)


## O cotovelo pode ficar em qualquer ponto de um círculo (mesmo ombro, mesma mão).
## Escolhe o ponto mais perto do preferido (pulso reto) em que o braço inteiro fica
## FORA do tronco; sem pular de um lado para o outro entre quadros.
func _polo_fora_do_tronco(esq: Skeleton3D, a: Vector3, t: Vector3, centro_c: Vector3,
		dir: Vector3, preferido: Vector3, raio: float) -> Vector3:
	var u := preferido
	var v := dir.cross(u).normalized()
	var poses := []
	for seg in tronco:
		poses.append(esq.get_bone_global_pose(seg[0]).affine_inverse())
	var melhor := preferido
	var melhor_custo := INF
	for k in 24:
		var ang := k * TAU / 24.0
		var p := (u * cos(ang) + v * sin(ang)).normalized()
		var e := centro_c + p * raio
		var fundo := 0.0
		for f in [0.5, 0.75]:
			fundo = maxf(fundo, _dentro_do_tronco(a.lerp(e, f), poses))
		for f in [0.0, 0.3, 0.6]:
			fundo = maxf(fundo, _dentro_do_tronco(e.lerp(t, f), poses))
		var custo := minf(ang, TAU - ang)        # longe do preferido
		custo += maxf(fundo - TOLERANCIA_TRONCO, 0.0) * 400.0   # dentro do corpo: proibido
		if _polo_anterior != Vector3.ZERO:
			custo += p.angle_to(_polo_anterior) * 0.3
		if custo < melhor_custo:
			melhor_custo = custo
			melhor = p
	_polo_anterior = melhor
	return melhor


## Quanto (m) o ponto (espaço do esqueleto) entra no tronco (0 = fora), já contando
## a espessura do braço. Usa o contorno real da pele (medido da malha pelo modelo).
func _dentro_do_tronco(p: Vector3, poses: Array) -> float:
	var fundo := 0.0
	for i in tronco.size():
		var seg: Array = tronco[i]
		var l: Vector3 = (poses[i] as Transform3D) * p
		var fatias: int = seg[3]
		var fa := int(floor((l.y - float(seg[2])) / 0.04))
		if fa < 0 or fa >= fatias:
			continue
		var c: Vector2 = seg[1]
		var dx := l.x - c.x
		var dz := l.z - c.y
		var setores := 24
		var se := posmod(int(floor((atan2(dx, dz) + PI) / TAU * setores)), setores)
		var perfil: PackedFloat32Array = seg[4]
		var pele := perfil[fa * setores + se]
		var r := sqrt(dx * dx + dz * dz)
		fundo = maxf(fundo, pele + raio_braco - r)
	return maxf(fundo, 0.0)


## Divide a torção entre mão e antebraço (como o rádio gira em volta da ulna): sem
## isso a malha do pulso "torce" (efeito embrulho de bala) quando a mão gira muito.
func _repartir_torcao(esq: Skeleton3D) -> void:
	if _eixo_mao == Vector3.ZERO:
		return
	var mao_final := esq.get_bone_global_pose(_i_mao)
	var dlt := esq.get_bone_rest(_i_mao).basis.get_rotation_quaternion().inverse() * esq.get_bone_pose_rotation(_i_mao)
	var proj := Vector3(dlt.x, dlt.y, dlt.z).dot(_eixo_mao)
	var ang := wrapf(2.0 * atan2(proj, dlt.w), -PI, PI)
	var eixo_ante := esq.get_bone_rest(_i_mao).origin.normalized()   # antebraço -> punho (local)
	var qf := esq.get_bone_pose_rotation(_i_antebraco)
	esq.set_bone_pose_rotation(_i_antebraco, (qf * Quaternion(eixo_ante, ang * fracao_torcao)).normalized())
	_definir_global(esq, _i_mao, mao_final)


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
