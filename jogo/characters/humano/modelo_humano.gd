extends Node3D
## Personagem humano a partir de um modelo .gltf/.glb com esqueleto humanoide.
##
## Contrato (igual ao modelo provisório):
##   atualizar_animacao(estado, fator_velocidade, mirando)
##   definir_mira(peso, pitch_normalizado)   parte de cima do corpo mirando (0..1, -1..1)
##   prender_arma(cena) -> ModeloArma         coloca a arma na mão direita
##
## Animação: um AnimationTree montado por código:
##
##   [locomoção: Transition com Idle, Walk, Jog, Sprint, Jump, Roll...] -> [velocidade]
##                                                                        \
##   [mira: BlendSpace1D Pistol_Aim_Down / Neutral / Up] --(só tronco/braços/cabeça)--> Blend2 -> saída
##
## Ou seja: as pernas continuam correndo/pulando enquanto o tronco e os braços
## miram para onde a câmera aponta (atirar correndo, no ar, na parede...).
##
## Armas longas (fuzis, submetralhadoras, escopetas, snipers) usam a mira de FUZIL:
## Rifle_Aim_Down/Neutral/Up, geradas aqui mesmo a partir da mira de pistola, com o
## tronco girado (ombro esquerdo à frente, coronha no ombro direito) e a cabeça
## compensando para continuar olhando para a frente. A recarga de fuzil é feita por
## IK: a mão esquerda sai do guarda-mão, tira o pente, vai até a cintura e volta.
##
## Pendurado na beirada ("pendurado"): as duas mãos vão até a borda por IK.
## As animações vêm de UMA biblioteca compartilhada (assets/animations/animacoes_humanas.glb).
##
## Para trocar o modelo: aponte "cena_modelo" para outro .glb com o MESMO esqueleto
## (nomes de ossos estilo UE: pelvis, spine_01, thigh_l, hand_r...). Nada de código muda.

## Bibliotecas de animação (mesmo esqueleto). Todas são juntadas numa só.
## Para adicionar animações suas (ex.: Mixamo convertidas), coloque o .glb aqui.
const CAMINHOS_ANIMACOES := [
	"res://assets/animations/animacoes_humanas.glb",    # Universal Animation Library (CC0)
	"res://assets/animations/animacoes_humanas_2.glb",  # Universal Animation Library 2 (CC0)
]
## Qual animação cada estado usa. Troque os nomes para usar outras animações
## (por exemplo, uma corrida na parede do Mixamo) sem mexer no resto do código.
const ANIM := {
	"parado": "Idle", "parado_arma": "Pistol_Idle", "andar": "Walk", "trote": "Jog_Fwd",
	"correr": "Sprint", "pulo": "Jump", "parede": "Sprint", "subindo_parede": "NinjaJump_Start",
	"escalar": "ClimbUp_1m", "rolar": "Roll", "deslizar": "Slide", "morrer": "Death01",
	"aterrissar": "Jump_Land", "transpor": "NinjaJump_Start",
	"tiro": "Pistol_Shoot", "recarga": "Pistol_Reload", "pendurado": "Idle",
}
## Tempo de transição entre animações (crossfade), em segundos.
const MISTURA := 0.15
## Animações de locomoção usadas (nomes da biblioteca).
const LOCOMOCAO := ["parado", "parado_arma", "andar", "trote", "correr", "pulo", "parede",
	"subindo_parede", "escalar", "rolar", "deslizar", "morrer", "aterrissar", "transpor", "pendurado"]
## Ossos que NÃO entram na mira (ficam com a locomoção).
## Aceita os nomes do esqueleto atual (estilo UE) e os do perfil humanoide da Godot
## (usado quando você reprojeta animações do Mixamo no importador; veja o README).
const OSSOS_PERNAS := ["root", "pelvis", "thigh_l", "calf_l", "foot_l", "ball_l", "ball_leaf_l",
	"thigh_r", "calf_r", "foot_r", "ball_r", "ball_leaf_r",
	"Root", "Hips", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes"]
const OSSO_MAO := ["hand_r", "RightHand"]
const OSSO_DEDO := ["middle_01_r", "RightMiddleProximal"]
const OSSO_CABECA := ["Head", "head"]
const OSSO_PEITO := ["spine_03", "UpperChest", "Chest"]
const BRACO_D := [["upperarm_r", "RightUpperArm"], ["lowerarm_r", "RightLowerArm"], ["hand_r", "RightHand"]]
const BRACO_E := [["upperarm_l", "LeftUpperArm"], ["lowerarm_l", "LeftLowerArm"], ["hand_l", "LeftHand"]]
## Estados em que as mãos soltam a arma (IK desliga suave).
const ESTADOS_SEM_IK := [&"rolando", &"escalando", &"subindo_parede", &"morto", &"pendurado"]
## Mira de fuzil: quanto o tronco gira (ombro esquerdo à frente) e quanto o
## pescoço/cabeça compensam, em radianos. Gerada a partir da mira de pistola.
const GIRO_TRONCO_FUZIL := 0.42
const GIRO_PESCOCO_FUZIL := 0.26
const GIRO_CABECA_FUZIL := 0.14
const INCLINACAO_TRONCO_FUZIL := 0.08
const MIRAS := {
	"pistola": ["Pistol_Aim_Down", "Pistol_Aim_Neutral", "Pistol_Aim_Up"],
	"fuzil": ["Rifle_Aim_Down", "Rifle_Aim_Neutral", "Rifle_Aim_Up"],
}
## Pendurado: mãos na borda (espaço do personagem: x direita, y cima, -z frente)
## e quanto o corpo encosta na parede (a cápsula de colisão é mais larga que o corpo).
const MAOS_BEIRADA := Vector3(0.23, 1.7, -0.4)
const AVANCO_PENDURADO := 0.17


## Primeiro osso que existir na lista (para aceitar esqueletos com nomes diferentes).
func _osso(nomes: Array) -> int:
	for n in nomes:
		var i := _esqueleto.find_bone(n)
		if i >= 0:
			return i
	return -1

@export var cena_modelo: PackedScene
## Texturas de cor alternativas (skins). A primeira é a padrão.
@export var texturas_skin: Array[Texture2D] = []
## Acessórios presos ao osso da cabeça (cabelo, barba...). Os arquivos estão
## modelados na posição do corpo em pose T ("origin at 0").
@export var acessorios_cabeca: Array[PackedScene] = []
## A textura do cabelo é cinza (feita para ser tingida): esta cor tinge cabelo,
## barba e sobrancelhas.
@export var cor_cabelo := Color(0.2, 0.13, 0.08)
@export var skin := 0:
	set(v):
		skin = v
		if is_node_ready():
			_aplicar_skin()

static var _biblioteca: AnimationLibrary

var _modelo: Node3D
var _esqueleto: Skeleton3D
var _arvore: AnimationTree
var _corpo: MeshInstance3D
var _atual := ""
var _peso_mira := 0.0
var _peso_mira_alvo := 0.0
var _anexo_mao: BoneAttachment3D
var _calibracao_mao := Transform3D.IDENTITY
var _arma: ModeloArma
# Armas longas: encaixe no peito + IK das duas mãos
var _anexo_peito: BoneAttachment3D
var _pose_peito_mira := Transform3D.IDENTITY
var _ombro_d_mira := Vector3.ZERO
var _ik_d: IKDoisOssos
var _ik_e: IKDoisOssos
var _arma_longa := false
var _base_arma_mira := Transform3D.IDENTITY
var _base_arma_baixa := Transform3D.IDENTITY
var _ik_permitido := true
var _troca_t := 0.0
var _troca_total := 0.0
var _base_arma_mao := Transform3D.IDENTITY
var _pitch_mira_rad := 0.0
var _ajuste_rot_arma := Basis.IDENTITY
var _escala_arma := 1.0
var _angulo_baixo := 15.0
# Mira de fuzil (BlendSpace com nomes trocáveis) e recarga de fuzil por IK
var _pontos_mira: Array[AnimationNodeAnimation] = []
var _recarga_t := 0.0
var _recarga_total := 0.0
var _alvo_mao_e: Marker3D        # alvo da mão esquerda na recarga
var _alvo_arma_d: Node3D
var _alvo_arma_e: Node3D
# Pendurado na beirada
var _pendurado := false
var _peso_pendurado := 0.0
var _alvo_beirada_d: Marker3D
var _alvo_beirada_e: Marker3D
var _fase_pendurado := 0.0
var _fator_vel := 0.0


func _ready() -> void:
	_modelo = cena_modelo.instantiate()
	_modelo.rotation.y = PI  # o .gltf olha para +Z; no jogo a frente é -Z
	add_child(_modelo)
	_esqueleto = _modelo.find_child("Skeleton3D")

	# Corpo principal = maior malha do modelo (onde a skin é aplicada).
	var maior := 0.0
	for mi in _modelo.find_children("*", "MeshInstance3D", true, false):
		var tam: float = mi.get_aabb().get_volume()
		if tam > maior:
			maior = tam
			_corpo = mi
	_prender_acessorios()
	_aplicar_skin()
	_montar_arvore()
	_calibrar_mao()
	_tocar("parado")


# =========================================================================
#  ANIMATION TREE
# =========================================================================

static func _obter_biblioteca() -> AnimationLibrary:
	if _biblioteca == null:
		_biblioteca = AnimationLibrary.new()
		for caminho in CAMINHOS_ANIMACOES:
			if not ResourceLoader.exists(caminho):
				continue
			var cena: Node = load(caminho).instantiate()
			var ap: AnimationPlayer = cena.find_child("AnimationPlayer")
			var lib := ap.get_animation_library("")
			for nome in lib.get_animation_list():
				if not _biblioteca.has_animation(nome):
					_biblioteca.add_animation(nome, lib.get_animation(nome))
			cena.free()
	return _biblioteca


func _montar_arvore() -> void:
	_arvore = AnimationTree.new()
	_arvore.name = "AnimationTree"
	_modelo.add_child(_arvore)
	_arvore.root_node = NodePath("..")
	_gerar_mira_fuzil()
	_arvore.add_animation_library("", _obter_biblioteca())

	var bt := AnimationNodeBlendTree.new()
	# Locomoção: troca de animação com crossfade.
	var trans := AnimationNodeTransition.new()
	trans.xfade_time = MISTURA
	for i in LOCOMOCAO.size():
		trans.add_input(LOCOMOCAO[i])
	bt.add_node("loco", trans, Vector2(200, 0))
	for i in LOCOMOCAO.size():
		var an := AnimationNodeAnimation.new()
		an.animation = ANIM[LOCOMOCAO[i]]
		bt.add_node("a_" + LOCOMOCAO[i], an, Vector2(0, i * 80))
		bt.connect_node("loco", i, "a_" + LOCOMOCAO[i])
	var vel := AnimationNodeTimeScale.new()
	bt.add_node("vel", vel, Vector2(400, 0))
	bt.connect_node("vel", 0, "loco")

	# Mira: olha para baixo / reto / para cima conforme a câmera.
	# (os nomes são trocados para Rifle_Aim_* ao segurar uma arma longa)
	var bs := AnimationNodeBlendSpace1D.new()
	_pontos_mira.clear()
	for par in [[MIRAS.pistola[0], -1.0], [MIRAS.pistola[1], 0.0], [MIRAS.pistola[2], 1.0]]:
		var an := AnimationNodeAnimation.new()
		an.animation = par[0]
		bs.add_blend_point(an, par[1])
		_pontos_mira.append(an)
	bt.add_node("mira", bs, Vector2(400, 300))

	# Mistura só no tronco/braços/cabeça.
	var b2 := AnimationNodeBlend2.new()
	_filtrar_tronco(b2)
	bt.add_node("mistura", b2, Vector2(600, 100))
	bt.connect_node("mistura", 0, "vel")
	bt.connect_node("mistura", 1, "mira")

	# Tiro e recarga: "one-shots" só no tronco (dá para recarregar correndo).
	var a_tiro := AnimationNodeAnimation.new()
	a_tiro.animation = ANIM.tiro
	bt.add_node("a_tiro", a_tiro, Vector2(600, 300))
	var tiro := AnimationNodeOneShot.new()
	tiro.fadein_time = 0.04
	tiro.fadeout_time = 0.15
	_filtrar_tronco(tiro)
	bt.add_node("tiro", tiro, Vector2(800, 100))
	bt.connect_node("tiro", 0, "mistura")
	bt.connect_node("tiro", 1, "a_tiro")
	var a_rec := AnimationNodeAnimation.new()
	a_rec.animation = ANIM.recarga
	bt.add_node("a_recarga", a_rec, Vector2(800, 300))
	var vel_rec := AnimationNodeTimeScale.new()
	bt.add_node("vel_recarga", vel_rec, Vector2(900, 300))
	bt.connect_node("vel_recarga", 0, "a_recarga")
	var rec := AnimationNodeOneShot.new()
	rec.fadein_time = 0.12
	rec.fadeout_time = 0.2
	_filtrar_tronco(rec)
	bt.add_node("recarga", rec, Vector2(1000, 100))
	bt.connect_node("recarga", 0, "tiro")
	bt.connect_node("recarga", 1, "vel_recarga")
	bt.connect_node("output", 0, "recarga")

	_arvore.tree_root = bt
	_arvore.active = true


## Cria (uma vez, na biblioteca compartilhada) a mira de fuzil a partir da mira de
## pistola: gira o tronco no osso spine_02, inclina um pouco para a frente e
## compensa no pescoço/cabeça. Os braços não importam: o IK põe as mãos na arma.
func _gerar_mira_fuzil() -> void:
	var lib := _obter_biblioteca()
	if lib.has_animation(MIRAS.fuzil[1]):
		return
	var ajustes := [
		[["spine_02", "Spine"], -GIRO_TRONCO_FUZIL, INCLINACAO_TRONCO_FUZIL],
		[["neck_01", "Neck"], GIRO_PESCOCO_FUZIL, 0.0],
		[["Head", "head"], GIRO_CABECA_FUZIL, -INCLINACAO_TRONCO_FUZIL * 0.5],
	]
	var prefixo := "%s:" % str(_modelo.get_path_to(_esqueleto))
	for i in 3:
		var base := lib.get_animation(MIRAS.pistola[i])
		if base == null:
			return
		var anim: Animation = base.duplicate(true)
		for aj in ajustes:
			var osso := _osso(aj[0])
			if osso < 0:
				continue
			var trilha := anim.find_track(NodePath(prefixo + _esqueleto.get_bone_name(osso)), Animation.TYPE_ROTATION_3D)
			if trilha < 0:
				continue
			# Rotação desejada no espaço do esqueleto (em volta do eixo vertical e do
			# eixo lateral), convertida para o espaço local do osso: L' = L * G⁻¹ R G
			var g := _pose_global_na_animacao(base, osso).basis.orthonormalized()
			var r := Basis(Vector3.UP, aj[1]) * Basis(Vector3.RIGHT, aj[2])
			var delta := Quaternion(g.inverse() * r * g).normalized()
			for k in anim.track_get_key_count(trilha):
				var q: Quaternion = anim.track_get_key_value(trilha, k)
				anim.track_set_key_value(trilha, k, (q * delta).normalized())
		lib.add_animation(MIRAS.fuzil[i], anim)


## Mira de pistola ou de fuzil no BlendSpace (sem remontar a árvore).
func _usar_mira(tipo: String) -> void:
	for i in _pontos_mira.size():
		_pontos_mira[i].animation = MIRAS[tipo][i]


func _filtrar_tronco(no: AnimationNode) -> void:
	no.filter_enabled = true
	var prefixo := str(_modelo.get_path_to(_esqueleto))
	for i in _esqueleto.get_bone_count():
		var nome := _esqueleto.get_bone_name(i)
		if not OSSOS_PERNAS.has(nome):
			no.set_filter_path(NodePath("%s:%s" % [prefixo, nome]), true)


## Animação de tiro no tronco (armas de tiro "pesado": semi, rajada, sniper).
func tocar_tiro() -> void:
	_arvore.set("parameters/tiro/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Recarga no tronco, na duração da recarga da arma.
func tocar_recarga(tempo: float) -> void:
	_recarga_total = maxf(tempo, 0.1)
	_recarga_t = _recarga_total
	if _arma_longa:
		return  # fuzil: recarga por IK da mão esquerda (_atualizar_recarga_fuzil)
	var dur := _obter_biblioteca().get_animation(ANIM.recarga).length
	_arvore.set("parameters/vel_recarga/scale", dur / maxf(tempo, 0.1))
	_arvore.set("parameters/recarga/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _tocar(nome: String, velocidade: float = 1.0) -> void:
	_arvore.set("parameters/vel/scale", velocidade)
	if nome != _atual:
		_atual = nome
		_arvore.set("parameters/loco/transition_request", nome)


func _process(delta: float) -> void:
	_peso_mira = move_toward(_peso_mira, _peso_mira_alvo, delta * 8.0)
	_arvore.set("parameters/mistura/blend_amount", _peso_mira)
	_atualizar_arma(delta)
	_atualizar_pendurado(delta)


## Posição da arma (pronto baixo <-> mirando, animação de troca) e força do IK.
func _atualizar_arma(delta: float) -> void:
	_troca_t = maxf(_troca_t - delta, 0.0)
	var k_troca := ease(_troca_t / _troca_total, 0.5) if _troca_total > 0.0 else 0.0
	var abaixar := Transform3D(Basis(Vector3.RIGHT, -1.1 * k_troca), Vector3(0, -0.12 * k_troca, 0))
	if _arma and is_instance_valid(_arma):
		if _arma_longa:
			# POSIÇÃO: presa ao peito (acompanha o balanço do corpo nas animações).
			var xf := _base_arma_baixa.interpolate_with(_base_arma_mira, _peso_mira)
			_arma.transform = xf
			# ORIENTAÇÃO: frente do personagem + inclinação da mira (não herda a
			# curvatura do tronco de cada animação). Mirando, aponta para a mira.
			var mao_local: Vector3 = (_arma.get_node("Mao") as Node3D).position
			var mao_g := _arma.global_transform * mao_local
			var pitch := lerpf(-deg_to_rad(_angulo_baixo), _pitch_mira_rad, _peso_mira)
			# Recarga: a arma gira um pouco (janela do pente para cima/fora) e sobe.
			var k_rec := _fase_recarga()
			var giro_rec := Basis(Vector3(0, 0, 1), -0.45 * sin(PI * k_rec)) * Basis(Vector3.RIGHT, 0.18 * sin(PI * k_rec))
			var base_g := _esqueleto.global_basis.orthonormalized() * Basis(Vector3.UP, PI) \
				* Basis(Vector3.RIGHT, pitch) * giro_rec * _ajuste_rot_arma * abaixar.basis
			base_g = base_g.scaled(Vector3.ONE * _escala_arma)
			_arma.global_transform = Transform3D(base_g, mao_g + abaixar.origin - base_g * mao_local)
			_atualizar_recarga_fuzil()
		else:
			_arma.transform = _base_arma_mao * abaixar
		_arma.visible = _peso_pendurado < 0.5  # pendurado: arma "nas costas"
	_recarga_t = maxf(_recarga_t - delta, 0.0)
	if _pendurado or _peso_pendurado > 0.0:
		return  # IK das mãos fica com a beirada (_atualizar_pendurado)
	var alvo := 1.0 if (_arma_longa and _ik_permitido and _arma != null) else 0.0
	for ik in [_ik_d, _ik_e]:
		if ik:
			ik.influence = move_toward(ik.influence, alvo, delta * 6.0)
			ik.active = ik.influence > 0.001


## Progresso da recarga de fuzil (0..1; 0 = sem recarga).
func _fase_recarga() -> float:
	if not _arma_longa or _recarga_total <= 0.0 or _recarga_t <= 0.0:
		return 0.0
	return 1.0 - _recarga_t / _recarga_total


## Recarga de fuzil: caminho da mão esquerda (guarda-mão -> pente -> cintura ->
## pente -> tapa no pente -> guarda-mão). O IK leva a mão até o alvo.
func _atualizar_recarga_fuzil() -> void:
	if _ik_e == null or _alvo_mao_e == null:
		return
	var f := _fase_recarga()
	if f <= 0.0 or _alvo_arma_e == null or not is_instance_valid(_alvo_arma_e):
		if _ik_e.alvo == _alvo_mao_e:
			_ik_e.alvo = _alvo_arma_e
		return
	var guarda: Vector3 = _alvo_arma_e.global_position
	var mao_d: Vector3 = (_arma.get_node("Mao") as Node3D).global_position
	var pente := mao_d.lerp(guarda, 0.4) - _arma.global_basis.orthonormalized().y * 0.1
	var xf := global_transform.orthonormalized()
	var cintura := xf * Vector3(-0.16, 0.98, -0.12)  # bolsa do pente, lado esquerdo
	var p: Vector3
	if f < 0.15:
		p = guarda.lerp(pente, smoothstep(0.0, 0.15, f))
	elif f < 0.4:
		p = pente.lerp(cintura, smoothstep(0.15, 0.4, f))
	elif f < 0.52:
		p = cintura
	elif f < 0.75:
		p = cintura.lerp(pente, smoothstep(0.52, 0.75, f))
	elif f < 0.85:
		p = pente + xf.basis.y * 0.04 * sin(PI * (f - 0.75) / 0.1)  # tapa no pente
	else:
		p = pente.lerp(guarda, smoothstep(0.85, 1.0, f))
	_alvo_mao_e.global_position = p
	if not _pendurado:
		_ik_e.alvo = _alvo_mao_e


## Pendurado na beirada: mãos na borda por IK, corpo encostado na parede e um
## leve balanço; andando de lado, as mãos alternam (uma vai, a outra segue).
func _atualizar_pendurado(delta: float) -> void:
	if _ik_d == null or _alvo_beirada_d == null:
		return
	_peso_pendurado = move_toward(_peso_pendurado, 1.0 if _pendurado else 0.0, delta * 8.0)
	_modelo.position.z = -AVANCO_PENDURADO * _peso_pendurado
	if _peso_pendurado <= 0.0:
		if _ik_d.alvo == _alvo_beirada_d:
			_ik_d.alvo = _alvo_arma_d
			_ik_e.alvo = _alvo_arma_e
			_ik_d.girar_mao = true
			_ik_d.ajuste_mao = _calibracao_mao.affine_inverse()
			_ik_d.influence = 0.0
			_ik_e.influence = 0.0
		return
	var andando := _fator_vel > 0.02 and _pendurado
	if andando:
		_fase_pendurado += delta * 7.0
	var xf := global_transform.orthonormalized()
	var levanta_d := maxf(sin(_fase_pendurado), 0.0) * 0.06 if andando else 0.0
	var levanta_e := maxf(-sin(_fase_pendurado), 0.0) * 0.06 if andando else 0.0
	_alvo_beirada_d.global_position = xf * Vector3(MAOS_BEIRADA.x, MAOS_BEIRADA.y + levanta_d, MAOS_BEIRADA.z)
	_alvo_beirada_e.global_position = xf * Vector3(-MAOS_BEIRADA.x, MAOS_BEIRADA.y + levanta_e, MAOS_BEIRADA.z)
	_ik_d.alvo = _alvo_beirada_d
	_ik_e.alvo = _alvo_beirada_e
	_ik_d.girar_mao = false
	_ik_d.ajuste_mao = Transform3D.IDENTITY  # o ajuste é da empunhadura da arma
	for ik in [_ik_d, _ik_e]:
		ik.influence = _peso_pendurado
		ik.active = ik.influence > 0.001


## Arma descendo e subindo ao trocar (dura o tempo de equipar da arma).
func animar_troca(tempo: float) -> void:
	_troca_total = maxf(tempo, 0.05)
	_troca_t = _troca_total


## Escolhe a animação conforme o estado do personagem.
## (Animações que o pacote CC0 não tem, como deslize e corrida na parede, usam uma
##  animação parecida + inclinação do corpo feita pelo script do jogador. Na etapa 6
##  dá para colocar animações do Mixamo no lugar; veja o README.)
func atualizar_animacao(estado: StringName, fator_vel: float, mirando: bool) -> void:
	_ik_permitido = not ESTADOS_SEM_IK.has(estado)
	_pendurado = estado == &"pendurado"
	_fator_vel = fator_vel
	match estado:
		&"correndo":
			if fator_vel < 0.35:
				_tocar("andar", clamp(fator_vel / 0.25, 0.6, 1.4))
			elif fator_vel < 0.75:
				_tocar("trote", clamp(fator_vel / 0.6, 0.8, 1.3))
			else:
				_tocar("correr", clamp(fator_vel, 0.85, 1.2))
		&"pulando", &"caindo":
			_tocar("pulo")
		&"parede":
			_tocar("parede", 1.1)
		&"subindo_parede":
			_tocar("subindo_parede", 1.4)
		&"escalando":
			_tocar("escalar", 2.0)    # 0,67 s de animação; a escalada dura ~0,32 s
		&"rolando":
			_tocar("rolar", 2.1)      # a animação tem 1,47 s; o rolamento dura ~0,7 s
		&"deslizando":
			_tocar("deslizar", 1.0)
		&"morto":
			_tocar("morrer")
		&"transpondo":
			_tocar("transpor", 1.6)
		&"aterrissando":
			_tocar("aterrissar", 2.2)
		&"pendurado":
			_tocar("pendurado", 0.4)
		_:
			_tocar("parado_arma" if (mirando or _arma != null) else "parado")


## Tronco e braços mirando. peso 0..1; pitch -1 (baixo) .. 1 (cima).
func definir_mira(peso: float, pitch: float) -> void:
	_peso_mira_alvo = peso
	_pitch_mira_rad = clampf(pitch, -1.0, 1.0) * deg_to_rad(60.0)
	_arvore.set("parameters/mira/blend_position", clamp(pitch, -1.0, 1.0))


# =========================================================================
#  ARMA NA MÃO
# =========================================================================

## Calcula, uma vez, como a arma deve ficar presa ao osso da mão para que,
## na pose de mira, ela aponte exatamente para a frente do personagem.
## Funciona para qualquer modelo com o mesmo esqueleto (sem ajuste manual).
func _calibrar_mao() -> void:
	var osso := _osso(OSSO_MAO)
	if osso < 0:
		return
	var anim := _obter_biblioteca().get_animation("Pistol_Aim_Neutral")  # pose de referência
	var mao := _pose_global_na_animacao(anim, osso)
	var dedo := _osso(OSSO_DEDO)
	var palma := mao.origin
	if dedo >= 0:
		palma = mao.origin.lerp(_pose_global_na_animacao(anim, dedo).origin, 0.6)
	# No espaço do esqueleto o personagem olha para +Z: a arma (-Z = frente) gira 180°.
	var desejado := Transform3D(Basis(Vector3.UP, PI), palma)
	_calibracao_mao = mao.affine_inverse() * desejado

	_anexo_mao = BoneAttachment3D.new()
	_anexo_mao.bone_name = _esqueleto.get_bone_name(osso)
	_esqueleto.add_child(_anexo_mao)

	# Encaixe no peito (armas longas) e ombro direito, na pose de mira
	var peito := _osso(OSSO_PEITO)
	var ombro := _osso(BRACO_D[0])
	if peito >= 0 and ombro >= 0:
		# Armas longas: referência é a mira de FUZIL (tronco girado)
		var anim_fuzil := _obter_biblioteca().get_animation(MIRAS.fuzil[1])
		if anim_fuzil == null:
			anim_fuzil = anim
		_pose_peito_mira = _pose_global_na_animacao(anim_fuzil, peito)
		_ombro_d_mira = _pose_global_na_animacao(anim_fuzil, ombro).origin
		_anexo_peito = BoneAttachment3D.new()
		_anexo_peito.bone_name = _esqueleto.get_bone_name(peito)
		_esqueleto.add_child(_anexo_peito)
		# IK das duas mãos (desligado até prender uma arma longa)
		_ik_d = _novo_ik(BRACO_D, Vector3(-0.6, -1, 0))
		_ik_d.girar_mao = true
		_ik_d.ajuste_mao = _calibracao_mao.affine_inverse()
		_ik_e = _novo_ik(BRACO_E, Vector3(0.6, -1, 0))
		# Mão de apoio fecha os dedos no guarda-mão (copia a pose da mão do cabo)
		for nome_dedo in ["index", "middle", "ring", "pinky", "thumb"]:
			for k in ["01", "02", "03"]:
				var e := _esqueleto.find_bone("%s_%s_l" % [nome_dedo, k])
				var d := _esqueleto.find_bone("%s_%s_r" % [nome_dedo, k])
				if e >= 0 and d >= 0:
					_ik_e.copiar_dedos.append([e, d])
		# Alvos soltos (posição global definida a cada quadro)
		_alvo_mao_e = _novo_alvo("AlvoRecargaMaoE")
		_alvo_beirada_d = _novo_alvo("AlvoBeiradaD")
		_alvo_beirada_e = _novo_alvo("AlvoBeiradaE")


func _novo_alvo(nome: String) -> Marker3D:
	var m := Marker3D.new()
	m.name = nome
	m.top_level = true
	add_child(m)
	return m



## Pose global (no espaço do esqueleto) de um osso no primeiro quadro de uma animação.
func _pose_global_na_animacao(anim: Animation, osso: int) -> Transform3D:
	var cadeia := []
	var b := osso
	while b >= 0:
		cadeia.push_front(b)
		b = _esqueleto.get_bone_parent(b)
	var prefixo := "%s:" % str(_modelo.get_path_to(_esqueleto))
	var t := Transform3D.IDENTITY
	for i in cadeia:
		var rest := _esqueleto.get_bone_rest(i)
		var rot := rest.basis.get_rotation_quaternion()
		var pos := rest.origin
		var esc := rest.basis.get_scale()
		var caminho := NodePath(prefixo + _esqueleto.get_bone_name(i))
		var tr := anim.find_track(caminho, Animation.TYPE_ROTATION_3D)
		if tr >= 0:
			rot = anim.rotation_track_interpolate(tr, 0.0)
		var tp := anim.find_track(caminho, Animation.TYPE_POSITION_3D)
		if tp >= 0:
			pos = anim.position_track_interpolate(tp, 0.0)
		t = t * Transform3D(Basis(rot).scaled(esc), pos)
	return t


func _novo_ik(nomes: Array, dica: Vector3) -> IKDoisOssos:
	var ik := IKDoisOssos.new()
	var n := []
	for opcoes in nomes:
		var i := _osso(opcoes)
		n.append(_esqueleto.get_bone_name(i) if i >= 0 else "")
	ik.configurar(n[0], n[1], n[2])
	ik.dica_cotovelo = dica
	ik.influence = 0.0
	_esqueleto.add_child(ik)
	return ik


## Prende a arma. Pistolas: na mão direita (calibrada pela pose de mira).
## Armas longas: no peito, com a coronha no ombro direito; as mãos vão até o
## cabo (Mao) e o guarda-mão (MaoEsquerda) por IK. "dados" traz o ajuste fino.
func prender_arma(cena: PackedScene, dados: DadosArma = null) -> ModeloArma:
	if _arma:
		_arma.queue_free()
		_arma = null
	_arma_longa = false
	_recarga_t = 0.0
	_alvo_arma_d = null
	_alvo_arma_e = null
	_usar_mira("pistola")
	if cena == null or _anexo_mao == null:
		return null
	_arma = cena.instantiate() as ModeloArma
	var mao_local: Transform3D = (_arma.get_node("Mao") as Node3D).transform
	var aj_rot := Basis.IDENTITY
	var aj_pos := Vector3.ZERO
	var aj_esc := 1.0
	if dados:
		aj_rot = Basis.from_euler(dados.ajuste_rotacao * (PI / 180.0))
		# ajuste no espaço do personagem (x direita, y cima, z frente) -> esqueleto (frente = +Z, direita = -X)
		aj_pos = Vector3(-dados.ajuste_posicao.x, dados.ajuste_posicao.y, dados.ajuste_posicao.z)
		aj_esc = dados.ajuste_escala
	_ajuste_rot_arma = aj_rot
	_escala_arma = aj_esc
	if dados:
		_angulo_baixo = dados.angulo_pronto_baixo
	if dados and dados.usa_ombro() and _anexo_peito:
		_anexo_peito.add_child(_arma)
		var traseira := _comprimento_traseiro(_arma)
		# Cabo na frente do ombro: a coronha (traseira) encosta no ombro.
		var cabo := _ombro_d_mira + Vector3(0, 0, 1) * (traseira - 0.03) + Vector3(0.07, -0.08, 0) + aj_pos
		var base := (Basis(Vector3.UP, PI) * aj_rot).scaled(Vector3.ONE * aj_esc)
		var desejado := Transform3D(base, cabo)
		_base_arma_mira = _pose_peito_mira.affine_inverse() * desejado * mao_local.affine_inverse()
		# Pronto baixo: cano inclinado para baixo, girando em volta do ombro
		var ang := deg_to_rad(dados.angulo_pronto_baixo)
		var piv := _ombro_d_mira
		var baixo := Transform3D.IDENTITY.translated(piv + Vector3(0, -0.05, 0)) * Transform3D(Basis(Vector3.RIGHT, ang)) * Transform3D.IDENTITY.translated(-piv) * desejado
		_base_arma_baixa = _pose_peito_mira.affine_inverse() * baixo * mao_local.affine_inverse()
		_arma.transform = _base_arma_baixa
		_arma_longa = true
		_usar_mira("fuzil")
		_alvo_arma_d = _arma.get_node("Mao")
		_alvo_arma_e = _arma.get_node_or_null("MaoEsquerda")
		if _alvo_arma_e == null:
			_alvo_arma_e = _alvo_arma_d
		if not _pendurado:
			_ik_d.alvo = _alvo_arma_d
			_ik_e.alvo = _alvo_arma_e
	else:
		_anexo_mao.add_child(_arma)
		# Posiciona pelo ponto "Mao" da arma.
		_base_arma_mao = _calibracao_mao * Transform3D(aj_rot.scaled(Vector3.ONE * aj_esc), aj_pos) * mao_local.affine_inverse()
		_arma.transform = _base_arma_mao
	return _arma


## Distância (m) do cabo até a ponta de trás da arma (coronha), pela geometria.
func _comprimento_traseiro(arma: Node3D) -> float:
	var inv := arma.global_transform.affine_inverse()
	var maximo := 0.05
	for mi in arma.find_children("*", "MeshInstance3D", true, false):
		var caixa: AABB = (inv * mi.global_transform) * mi.get_aabb()
		maximo = maxf(maximo, caixa.end.z)
	var mao_z: float = (arma.get_node("Mao") as Node3D).position.z
	return clampf(maximo - mao_z, 0.05, 0.6)


# =========================================================================
#  SKIN E ACESSÓRIOS
# =========================================================================

func _prender_acessorios() -> void:
	if acessorios_cabeca.is_empty():
		return
	var osso := _osso(OSSO_CABECA)
	if osso < 0:
		return
	var anexo := BoneAttachment3D.new()
	anexo.bone_name = _esqueleto.get_bone_name(osso)
	_esqueleto.add_child(anexo)
	# Desfaz a posição de repouso da cabeça: o acessório foi modelado no
	# espaço do corpo inteiro, e o anexo já está na cabeça.
	var inverso := _esqueleto.get_bone_global_rest(osso).affine_inverse()
	for cena in acessorios_cabeca:
		var a: Node3D = cena.instantiate()
		a.transform = inverso * a.transform
		anexo.add_child(a)
	# Tinge cabelo/barba (acessórios) e sobrancelhas.
	var pelos: Array = anexo.find_children("*", "MeshInstance3D", true, false)
	pelos.append_array(_modelo.find_children("Eyebrows*", "MeshInstance3D", true, false))
	for mi in pelos:
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(i)
			if mat is BaseMaterial3D:
				mat = mat.duplicate()
				mat.albedo_color = cor_cabelo
				mi.set_surface_override_material(i, mat)


func _aplicar_skin() -> void:
	if _corpo == null or texturas_skin.is_empty():
		return
	var tex: Texture2D = texturas_skin[clamp(skin, 0, texturas_skin.size() - 1)]
	var mat := _corpo.mesh.surface_get_material(0)
	if mat is BaseMaterial3D:
		mat = mat.duplicate()  # duplicar: não afeta outros personagens
		mat.albedo_texture = tex
		_corpo.set_surface_override_material(0, mat)
