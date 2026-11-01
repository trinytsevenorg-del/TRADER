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
## Empunhadura da mão de apoio (esquerda), no espaço da arma (-Z frente, +Y cima, +X direita):
## A mão "abraça" um cilindro (o guarda-mão, ou a mão do cabo na pistola) em volta
## do eixo do cano. A cada quadro é escolhida a rotação da mão em volta desse cilindro
## ("giro": 0° = palma para cima, 90° = palma virada para a direita) e a inclinação dos
## dedos ao longo do cano que deixam o ANTEBRAÇO ALINHADO com a mão (pulso reto) e o
## cotovelo por baixo — como um corpo de verdade faria.
##   "giro": preferido, mínimo, máximo (graus); "raio": raio do cilindro; "afasta": folga da palma.
##   "eixo": eixo do cilindro (espaço da arma); "ref": palma com giro 0; "sentido": para que
##   lado os dedos dão a volta. Fuzil: guarda-mão (eixo do cano), palma para cima, dedos
##   subindo pela direita. Pistola: o CABO (quase vertical, inclinado para trás), palma
##   encostada no lado esquerdo da mão do cabo, dedos dando a volta pela frente.
const EMPUNHADURA_FUZIL := {"eixo": Vector3(0, 0, -1), "ref": Vector3(0, 1, 0), "sentido": 1.0,
	"giro": [15.0, -25.0, 70.0], "incl": [-20.0, 50.0, 10.0], "raio": -1.0, "afasta": 0.012}
const EMPUNHADURA_PISTOLA := {"eixo": Vector3(0, -0.95, 0.3), "ref": Vector3(1, 0, 0), "sentido": -1.0,
	"giro": [0.0, -40.0, 50.0], "incl": [-30.0, 30.0, 0.0], "raio": 0.04, "afasta": 0.008}
## Quanto cada falange fecha (rad): base, meio, ponta. Polegar fecha pouco.
## Ajuste ao chão: nenhuma destas juntas fica mais perto do piso (logo abaixo dela)
## que a margem (m) — a margem é a "carne" entre a junta e a superfície do corpo
## (sola do pé, palma, nuca...). Se ficar, o corpo inteiro sobe o necessário.
const APOIOS_CHAO := [["ball_l", 0.04], ["ball_r", 0.04], ["foot_l", 0.078], ["foot_r", 0.078],
	["hand_l", 0.03], ["hand_r", 0.03], ["lowerarm_l", 0.045], ["lowerarm_r", 0.045],
	["Head", 0.1], ["pelvis", 0.09]]
const CURVA_DEDOS := [0.9, 1.15, 0.8]
const CURVA_POLEGAR := [-0.5, -0.4, -0.3]


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
var _apoios: Array = []        # [osso, margem]
var _ajuste_chao := 0.0
var _tempo_sem_apoio := 0.0
var _empurrao := Vector3.ZERO  # afastamento do corpo visual de paredes (espaço do MUNDO:
                               # não gira junto quando o personagem vira)
## Velocidade máxima das correções do corpo visual (m/s): suave, sem tranco.
const VEL_CORRECAO := 3.0
var _corpo_fisico: CollisionObject3D
var _peso_postura := 0.0
var _pitch_norm := 0.0
var _concha_ombro := Vector3.ZERO   # onde a coronha apoia (pose de mira de fuzil)
var _queda_livre := true      # achou lugar livre para o corpo cair deitado
var _bloqueio := 0.0           # 0..1: arma recolhida por parede logo à frente
# Empunhadura calculada da mão esquerda
var _alvo_empunhadura_e: Marker3D
var _quadro_mao_e := Basis.IDENTITY   # dedos / polegar / palma da mão esquerda em repouso
var _palma_e := Vector3.ZERO           # centro da palma em relação ao punho (no quadro acima)
var _rest_mao_e := Basis.IDENTITY
var _guarda_local := Vector3.ZERO      # embaixo do guarda-mão (espaço da arma), achado pela geometria
var _guarda_raio := 0.025               # meia altura do guarda-mão (para a mão abraçar)
var _comp_braco_e := 0.25
var _comp_ante_e := 0.24
var _giro_e := 15.0                     # pegada escolhida no quadro anterior (suaviza)
var _incl_e := 10.0


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
	_criar_botas()
	_aplicar_skin()
	_montar_arvore()
	_calibrar_mao()
	_tocar("parado")
	for a in APOIOS_CHAO:
		var i := _esqueleto.find_bone(a[0])
		if i >= 0:
			var anexo := BoneAttachment3D.new()
			anexo.bone_name = a[0]
			_esqueleto.add_child(anexo)
			_apoios.append([i, a[1], anexo])
	var pai := get_parent()
	while pai and not pai is CollisionObject3D:
		pai = pai.get_parent()
	_corpo_fisico = pai


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
	# A árvore avança no _process deste script (antes do ajuste ao chão): assim o
	# ajuste usa a pose DESTE quadro, sem atraso (o pé não afunda na pisada).
	_arvore.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
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
	_arvore.advance(delta)
	_peso_mira = move_toward(_peso_mira, _peso_mira_alvo, delta * 8.0)
	# Pistola encostada na parede: braços recolhem (sai da pose de braços esticados).
	var peso := _peso_mira * (1.0 - _bloqueio) if not _arma_longa else _peso_mira
	# Arma longa: o tronco fica sempre na postura de fuzil (de lado, coronha no ombro),
	# também com a arma baixa — a posição da arma e dos braços foi feita para ela.
	# (Rolando, escalando, pendurado ou morto o corpo fica livre.)
	_peso_postura = move_toward(_peso_postura, 1.0 if (_arma_longa and _ik_permitido and not _pendurado) else 0.0, delta * 5.0)
	peso = maxf(peso, _peso_postura)
	# o tronco só inclina para cima/baixo com a câmera quando está mirando
	_arvore.set("parameters/mira/blend_position", _pitch_norm * _peso_mira)
	_arvore.set("parameters/mistura/blend_amount", peso)
	_atualizar_bloqueio(delta)
	_atualizar_arma(delta)
	_atualizar_pendurado(delta)
	_ajustar_ao_chao(delta)


## Ajuste ao chão (como o "foot IK" dos jogos): mede pés, mãos, cotovelos, cabeça e
## quadril contra o piso logo abaixo de cada um e sobe o corpo o mínimo necessário
## para nada atravessar o chão (parado, deslizando, rolando, caído...). Sobe na hora
## e desce suave.
func _ajustar_ao_chao(delta: float) -> void:
	if _apoios.is_empty() or not is_inside_tree():
		return
	var esp := get_world_3d().direct_space_state
	var xf := _esqueleto.global_transform
	var falta := -INF
	for a in _apoios:
		# Duas leituras: a pose deste quadro e a pose FINAL desenhada (anexo ao osso,
		# depois de todos os modificadores). Vale a mais baixa.
		var p: Vector3 = xf * _esqueleto.get_bone_global_pose(a[0]).origin
		var anexo: BoneAttachment3D = a[2]
		if anexo.global_position.y < p.y:
			p = anexo.global_position
		# começa bem acima: numa rampa o chão à frente pode estar muito acima da junta
		var de := p + Vector3.UP * 1.0
		for tentativa in 3:   # pula tetos/beirais (normal para baixo/lado) até achar piso
			var q := PhysicsRayQueryParameters3D.create(de, p + Vector3.DOWN * 0.35, 1)
			if _corpo_fisico:
				q.exclude = [_corpo_fisico.get_rid()]
			var hit := esp.intersect_ray(q)
			if hit.is_empty():
				break
			if hit.normal.y > 0.6:
				falta = maxf(falta, hit.position.y + float(a[1]) - p.y)
				break
			de = hit.position + Vector3.DOWN * 0.01
	var alvo := 0.0
	if falta > -INF:
		alvo = clampf(_ajuste_chao + falta, 0.0, 0.5)
	# Sobe na hora; para descer espera um pouco (correndo, a altura certa vem a cada
	# pisada — sem isso o pé afundaria entre um passo e outro).
	if alvo >= _ajuste_chao - 0.002:
		_ajuste_chao = move_toward(_ajuste_chao, maxf(alvo, _ajuste_chao), delta * VEL_CORRECAO)
		_tempo_sem_apoio = 0.0
	else:
		_tempo_sem_apoio += delta
		if _tempo_sem_apoio > 0.9:
			_ajuste_chao = move_toward(_ajuste_chao, alvo, delta * 0.15)
	_modelo.position.y = _ajuste_chao
	_afastar_de_paredes(esp, delta)


## Juntas que não podem entrar em paredes (o corpo visual é maior que a cápsula de
## colisão: passada larga, deslize deitado, rolamento, mãos esticadas...).
const JUNTAS_PAREDE := ["Head", "spine_03", "pelvis", "hand_l", "hand_r", "lowerarm_l", "lowerarm_r",
	"calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r"]
var _juntas_parede: Array = []   # [osso, anexo (pose final)]
## Distância mínima entre uma junta e a parede (a carne em volta da junta).
const FOLGA_PAREDE := 0.08
var _tempo_livre_parede := 0.0


## Se alguma junta passou de uma parede, afasta o corpo visual o necessário (até 60 cm).
## O raio sai do eixo do corpo, na altura da junta, até a junta (+ margem de carne).
func _afastar_de_paredes(esp: PhysicsDirectSpaceState3D, delta: float) -> void:
	if _juntas_parede.is_empty():
		for n in JUNTAS_PAREDE:
			var i := _esqueleto.find_bone(n)
			if i >= 0:
				var anexo := BoneAttachment3D.new()
				anexo.bone_name = n
				_esqueleto.add_child(anexo)
				_juntas_parede.append([i, anexo])
	var xf := _esqueleto.global_transform
	var eixo := global_position
	var total := Vector3.ZERO
	var leituras := []
	for par in _juntas_parede:
		# pose deste quadro e pose final desenhada (com IK das mãos)
		leituras.append(xf * _esqueleto.get_bone_global_pose(par[0]).origin)
		leituras.append((par[1] as Node3D).global_position)
	for p: Vector3 in leituras:
		var de := Vector3(eixo.x, p.y, eixo.z) + total
		var d := p - de
		d.y = 0.0
		var dist := d.length()
		if dist < 0.05:
			continue
		var dir := d / dist
		var q := PhysicsRayQueryParameters3D.create(de, de + dir * (dist + FOLGA_PAREDE), 1)
		if _corpo_fisico:
			q.exclude = [_corpo_fisico.get_rid()]
		var hit := esp.intersect_ray(q)
		if hit and absf(hit.normal.y) < 0.6:
			var fundo: float = dist + FOLGA_PAREDE - de.distance_to(hit.position)
			var n := Vector3(hit.normal.x, 0, hit.normal.z).normalized()
			total += n * fundo
	# "total" é o que ainda falta afastar a partir da posição ATUAL do corpo visual.
	total.y = 0.0
	if total.length() > 0.002:
		# corpo caído (até ~1,8 m de comprimento) pode ser afastado mais
		var alvo := (_empurrao + total).limit_length(1.2 if _atual == "morrer" else 0.6)
		_empurrao = _empurrao.move_toward(alvo, delta * VEL_CORRECAO)   # afasta rápido, sem tranco
		_tempo_livre_parede = 0.0
	else:
		_tempo_livre_parede += delta
		if _tempo_livre_parede > 0.3:
			_empurrao = _empurrao.move_toward(Vector3.ZERO, delta * 0.3)   # volta devagar
	var local := global_basis.orthonormalized().inverse() * _empurrao
	_modelo.position.x = local.x
	_modelo.position.z = local.z - AVANCO_PENDURADO * _peso_pendurado


## Parede (ou qualquer obstáculo) logo à frente da arma: ela é recolhida para cima
## (como um agente de verdade faz ao encostar numa parede), em vez de atravessar.
func _atualizar_bloqueio(delta: float) -> void:
	var alvo := 0.0
	if _arma and is_instance_valid(_arma) and is_inside_tree() and not _pendurado:
		var frente := -global_basis.z.normalized()
		var peito := global_position + Vector3.UP * 1.35
		var alcance := 0.25 + absf((_arma.get_node("Cano") as Node3D).position.z) * _escala_arma + 0.08
		var q := PhysicsRayQueryParameters3D.create(peito, peito + frente * alcance, 1)
		if _corpo_fisico:
			q.exclude = [_corpo_fisico.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit:
			alvo = clampf((alcance - peito.distance_to(hit.position)) / 0.45, 0.0, 1.0)
	_bloqueio = move_toward(_bloqueio, alvo, delta * 5.0)


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
			pitch = lerpf(pitch, deg_to_rad(70.0), _bloqueio)   # recolhida para cima na parede
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
		_atualizar_empunhadura_e()
	_recarga_t = maxf(_recarga_t - delta, 0.0)
	if _pendurado or _peso_pendurado > 0.0:
		return  # IK das mãos fica com a beirada (_atualizar_pendurado)
	var tem_arma := _arma != null and is_instance_valid(_arma) and _ik_permitido
	var alvo_d := 1.0 if (_arma_longa and tem_arma) else 0.0
	# Pistola: a mão de apoio envolve a mão do cabo quando mira com as duas mãos.
	var alvo_e := alvo_d if _arma_longa else (_peso_mira * (1.0 - _bloqueio) if tem_arma else 0.0)
	if _ik_d:
		_ik_d.influence = move_toward(_ik_d.influence, alvo_d, delta * 6.0)
		_ik_d.active = _ik_d.influence > 0.001
	if _ik_e:
		_ik_e.influence = move_toward(_ik_e.influence, alvo_e, delta * 6.0)
		_ik_e.active = _ik_e.influence > 0.001


## Alvo da mão esquerda na arma (posição + orientação da mão inteira).
func _atualizar_empunhadura_e() -> void:
	if _alvo_empunhadura_e == null or _ik_e == null:
		return
	if _arma_longa:
		var centro := _arma.global_transform * (_guarda_local + Vector3.UP * _guarda_raio)
		_alvo_empunhadura_e.global_transform = _pose_empunhadura_e(centro, EMPUNHADURA_FUZIL)
	else:
		var cabo: Vector3 = (_arma.get_node("Mao") as Node3D).global_position
		cabo -= _arma.global_basis.orthonormalized().y * 0.025
		_alvo_empunhadura_e.global_transform = _pose_empunhadura_e(cabo, EMPUNHADURA_PISTOLA)
	if not _pendurado and _ik_e.alvo != _alvo_mao_e:
		_ik_e.alvo = _alvo_empunhadura_e


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
			_ik_e.alvo = _alvo_empunhadura_e
		return
	_atualizar_empunhadura_e()
	var guarda: Vector3 = _alvo_empunhadura_e.global_position
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
	# a mão mantém a orientação da empunhadura durante o caminho
	_alvo_mao_e.global_transform = Transform3D(_alvo_empunhadura_e.global_basis, p)
	if not _pendurado:
		_ik_e.alvo = _alvo_mao_e


## Pendurado na beirada: mãos na borda por IK, corpo encostado na parede e um
## leve balanço; andando de lado, as mãos alternam (uma vai, a outra segue).
func _atualizar_pendurado(delta: float) -> void:
	if _ik_d == null or _alvo_beirada_d == null:
		return
	_peso_pendurado = move_toward(_peso_pendurado, 1.0 if _pendurado else 0.0, delta * 8.0)
	if _peso_pendurado <= 0.0:
		if _ik_d.alvo == _alvo_beirada_d:
			_ik_d.alvo = _alvo_arma_d
			_ik_e.alvo = _alvo_empunhadura_e
			_ik_e.girar_mao = true
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
	_ik_e.girar_mao = false
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
	if estado != &"morto" and _modelo.rotation.y != PI:
		_modelo.rotation.y = PI   # renasceu: volta a olhar para a frente
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
			if _atual != "morrer":
				_escolher_lado_da_queda()
			_tocar("morrer")
		&"transpondo":
			_tocar("transpor", 1.6)
		&"aterrissando":
			_tocar("aterrissar", 2.2)
		&"pendurado":
			_tocar("pendurado", 0.4)
		_:
			_tocar("parado_arma" if (mirando or _arma != null) else "parado")


## Teletransporte/renascimento: zera as correções do corpo visual (não carrega o
## ajuste do corpo caído para o personagem de pé).
func reiniciar_ajustes() -> void:
	_ajuste_chao = 0.0
	_empurrao = Vector3.ZERO
	_tempo_sem_apoio = 0.0
	if _modelo:
		_modelo.position = Vector3.ZERO
		_modelo.rotation.y = PI


## A animação de morte cai para TRÁS (~1,8 m). Se atrás tiver parede, caixa ou
## beirada, o corpo cai para o lado mais livre (o corpo não entra em nada).
func _escolher_lado_da_queda() -> void:
	if not is_inside_tree():
		return
	var esp := get_world_3d().direct_space_state
	var tras := global_basis.z
	tras.y = 0.0
	tras = tras.normalized()
	var chao_y := global_position.y
	# Volume do corpo deitado, do quadril até a cabeça, com os braços abertos: dividido
	# em 6 pedaços (2 de largura x 3 de comprimento) para medir o quanto está livre.
	var pedaco := BoxShape3D.new()
	pedaco.size = Vector3(0.62, 0.4, 0.58)
	var melhor := 0.0
	var melhor_livres := -1
	var achou := false
	for graus in [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 120.0, -120.0, 150.0, -150.0, 180.0]:
		var dir := tras.rotated(Vector3.UP, deg_to_rad(graus))
		var base := Basis.looking_at(dir, Vector3.UP)
		var livres := 0
		for lado in [-0.31, 0.31]:
			for ao_longo in [0.35, 0.9, 1.45]:
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = pedaco
				q.transform = Transform3D(base, global_position + dir * ao_longo + base.x * lado + Vector3.UP * 0.25)
				q.collision_mask = 1
				if _corpo_fisico:
					q.exclude = [_corpo_fisico.get_rid()]
				if esp.intersect_shape(q, 1).is_empty():
					livres += 1
		# chão plano debaixo da cabeça (não cai "no vazio" de uma beirada nem num degrau)
		var cabeca := global_position + dir * 1.3
		var qc := PhysicsRayQueryParameters3D.create(cabeca + Vector3.UP * 0.4, cabeca + Vector3.DOWN * 0.3, 1)
		var h := esp.intersect_ray(qc)
		if h.is_empty() or absf(h.position.y - chao_y) > 0.15:
			livres -= 3
		if livres == 6:
			melhor = graus
			achou = true
			break
		if livres > melhor_livres:
			melhor_livres = livres
			melhor = graus
	_modelo.rotation.y = PI + deg_to_rad(melhor)
	_queda_livre = achou


## Tronco e braços mirando. peso 0..1; pitch -1 (baixo) .. 1 (cima).
func definir_mira(peso: float, pitch: float) -> void:
	_peso_mira_alvo = peso
	_pitch_mira_rad = clampf(pitch, -1.0, 1.0) * deg_to_rad(60.0)
	_pitch_norm = clampf(pitch, -1.0, 1.0)


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
		# Cotovelos para baixo e um pouco para trás (sem "asa de galinha").
		_ik_d = _novo_ik(BRACO_D, Vector3(-0.35, -1, -0.45))
		_ik_d.girar_mao = true
		_ik_d.ajuste_mao = _calibracao_mao.affine_inverse()
		_ik_e = _novo_ik(BRACO_E, Vector3(0.25, -1, -0.2))
		_calibrar_mao_esquerda()
		var corpo := _medir_tronco()
		for ik in [_ik_d, _ik_e]:
			ik.tronco = corpo.tronco
			ik.raio_braco = corpo.raio_braco
		_concha_ombro = _achar_concha_ombro(anim_fuzil)
		# Alvos soltos (posição global definida a cada quadro)
		_alvo_mao_e = _novo_alvo("AlvoRecargaMaoE")
		_alvo_beirada_d = _novo_alvo("AlvoBeiradaD")
		_alvo_beirada_e = _novo_alvo("AlvoBeiradaE")
		_alvo_empunhadura_e = _novo_alvo("AlvoEmpunhaduraE")


## Mede a mão esquerda em repouso (para onde apontam dedos, polegar e palma) e
## calcula a pose dos dedos fechados em volta de um cabo. Funciona com qualquer
## modelo de mesmo esqueleto: nada é ajustado à mão.
func _calibrar_mao_esquerda() -> void:
	var mao := _osso(BRACO_E[2])
	var medio := _esqueleto.find_bone("middle_01_l")
	var indicador := _esqueleto.find_bone("index_01_l")
	var minimo := _esqueleto.find_bone("pinky_01_l")
	if mao < 0 or medio < 0 or indicador < 0 or minimo < 0:
		return
	var r_mao := _esqueleto.get_bone_global_rest(mao)
	var p_med := _esqueleto.get_bone_global_rest(medio).origin
	var f := (p_med - r_mao.origin).normalized()
	var lado := _esqueleto.get_bone_global_rest(indicador).origin - _esqueleto.get_bone_global_rest(minimo).origin
	var s := (lado - f * lado.dot(f)).normalized()
	var n := f.cross(s).normalized()     # sai da palma
	_quadro_mao_e = Basis(f, s, n)
	_palma_e = _quadro_mao_e.inverse() * (r_mao.origin.lerp(p_med, 0.6) - r_mao.origin)
	_rest_mao_e = r_mao.basis.orthonormalized()
	var o_braco := _esqueleto.get_bone_global_rest(_osso(BRACO_E[0])).origin
	var o_ante := _esqueleto.get_bone_global_rest(_osso(BRACO_E[1])).origin
	_comp_braco_e = o_braco.distance_to(o_ante)
	_comp_ante_e = o_ante.distance_to(r_mao.origin)
	# Dedos: cada falange gira em volta do eixo que leva a ponta para a palma.
	var eixo_dedos := f.cross(n).normalized()
	var curvas := []
	for nome in ["index", "middle", "ring", "pinky"]:
		for k in 3:
			curvas.append(["%s_0%d_l" % [nome, k + 1], eixo_dedos, CURVA_DEDOS[k]])
	var t1 := _esqueleto.find_bone("thumb_01_l")
	var t2 := _esqueleto.find_bone("thumb_02_l")
	if t1 >= 0 and t2 >= 0:
		var t := (_esqueleto.get_bone_global_rest(t2).origin - _esqueleto.get_bone_global_rest(t1).origin).normalized()
		var eixo_pol := t.cross(n).normalized()
		for k in 3:
			curvas.append(["thumb_0%d_l" % (k + 1), eixo_pol, CURVA_POLEGAR[k]])
	_ik_e.copiar_dedos.clear()
	_ik_e.curvar_dedos.clear()
	for c in curvas:
		var b := _esqueleto.find_bone(c[0])
		if b < 0:
			continue
		# Giro no espaço do esqueleto convertido para o espaço local do osso: q * (G⁻¹ R G)
		var g := _esqueleto.get_bone_global_rest(b).basis.orthonormalized()
		var eixo_local: Vector3 = (g.inverse() * c[1]).normalized()
		var q := _esqueleto.get_bone_rest(b).basis.get_rotation_quaternion()
		_ik_e.curvar_dedos.append([b, (q * Quaternion(eixo_local, c[2])).normalized()])
	_ik_e.girar_mao = true


## A "concha" do ombro, onde a coronha apoia: parte da articulação do ombro direito
## (um pouco para dentro e para baixo) e anda para a frente até sair da pele do peito
## (contorno medido da malha). A coronha encosta na pele — não entra no corpo.
func _achar_concha_ombro(anim: Animation) -> Vector3:
	var p := _ombro_d_mira + Vector3(0.05, -0.06, 0)
	if _ik_d == null or _ik_d.tronco.is_empty():
		return p + Vector3(0, 0, 0.08)
	var poses := []
	for seg in _ik_d.tronco:
		poses.append(_pose_global_na_animacao(anim, seg[0]).affine_inverse())
	var raio: float = _ik_d.raio_braco
	_ik_d.raio_braco = 0.0
	for k in 40:
		if _ik_d._dentro_do_tronco(p, poses) <= 0.0:
			break
		p.z += 0.005
	_ik_d.raio_braco = raio
	return p + Vector3(0, 0, 0.01)


## Mede o tronco na malha (para os braços não entrarem no corpo): para cada osso da
## coluna, a elipse que contém os vértices do tronco ligados a ele (espaço do osso),
## e a espessura do braço. Fica guardado por malha (todos os bots reaproveitam).
static var _troncos := {}
const SETORES_TRONCO := 24


func _medir_tronco() -> Dictionary:
	if _troncos.has(_corpo.mesh):
		return _troncos[_corpo.mesh]
	var res := {"tronco": [], "raio_braco": 0.045}
	var skin := _corpo.skin
	if skin == null:
		return res
	var nomes_tronco := ["spine_01", "spine_02", "spine_03"]
	var pontos := {}     # bind -> [pontos locais]
	var braco := []      # distâncias ao eixo do braço
	var bind_braco := -1
	var bind_por_nome := {}
	for i in skin.get_bind_count():
		var nome := String(skin.get_bind_name(i))
		if nome == "":
			nome = _esqueleto.get_bone_name(skin.get_bind_bone(i))
		bind_por_nome[nome] = i
		if nome in nomes_tronco:
			pontos[i] = []
		if nome == "upperarm_r":
			bind_braco = i
	var arr := _corpo.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bs = arr[Mesh.ARRAY_BONES]
	var ws = arr[Mesh.ARRAY_WEIGHTS]
	if bs == null or ws == null:
		return res
	var por: int = bs.size() / vs.size()
	for v in vs.size():
		var melhor: int = -1
		var peso: float = 0.0
		for k in por:
			if ws[v * por + k] > peso:
				peso = ws[v * por + k]
				melhor = bs[v * por + k]
		if pontos.has(melhor):
			pontos[melhor].append(skin.get_bind_pose(melhor) * vs[v])
		elif melhor == bind_braco:
			var l: Vector3 = skin.get_bind_pose(melhor) * vs[v]
			braco.append(Vector2(l.x, l.z).length())   # osso aponta em +Y local
	if braco.size() > 10:
		braco.sort()
		res.raio_braco = braco[int(braco.size() * 0.35)]   # braço "relaxado" (não o bíceps inteiro)
	# Contorno real do tronco: para cada osso da coluna, em cada fatia de altura (4 cm) e
	# direção em volta do centro (24 setores), a distância até a pele mais afastada.
	for nome in nomes_tronco:
		if not bind_por_nome.has(nome) or (pontos[bind_por_nome[nome]] as Array).size() < 20:
			continue
		var osso := _esqueleto.find_bone(nome)
		var lista: Array = pontos[bind_por_nome[nome]]
		var cx := 0.0
		var cz := 0.0
		var ymin := INF
		var ymax := -INF
		for q in lista:
			cx += q.x
			cz += q.z
			ymin = minf(ymin, q.y)
			ymax = maxf(ymax, q.y)
		cx /= lista.size()
		cz /= lista.size()
		var fatias := maxi(1, ceili((ymax - ymin) / 0.04))
		var perfil := PackedFloat32Array()
		perfil.resize(fatias * SETORES_TRONCO)
		for q in lista:
			var fa := clampi(int((q.y - ymin) / 0.04), 0, fatias - 1)
			var dx: float = q.x - cx
			var dz: float = q.z - cz
			var se := posmod(int(floor((atan2(dx, dz) + PI) / TAU * SETORES_TRONCO)), SETORES_TRONCO)
			var k := fa * SETORES_TRONCO + se
			perfil[k] = maxf(perfil[k], sqrt(dx * dx + dz * dz))
		# setores vazios: o maior vizinho (sem buracos no contorno)
		for rep in 3:
			var novo := perfil.duplicate()
			for fa in fatias:
				for se in SETORES_TRONCO:
					var k := fa * SETORES_TRONCO + se
					if perfil[k] <= 0.0:
						var m := 0.0
						for d in [-1, 1]:
							m = maxf(m, perfil[fa * SETORES_TRONCO + posmod(se + d, SETORES_TRONCO)])
							if fa + d >= 0 and fa + d < fatias:
								m = maxf(m, perfil[(fa + d) * SETORES_TRONCO + se])
						novo[k] = m
			perfil = novo
		res.tronco.append([osso, Vector2(cx, cz), ymin, fatias, perfil])
	_troncos[_corpo.mesh] = res
	return res


## Pose da mão esquerda segurando a arma: palma encostada, dedos em volta.
## "centro" = eixo do cilindro que a mão abraça. Devolve o transform global do PUNHO.
## Procura (giro, inclinação) em que o cotovelo ideal — atrás do punho, na linha da
## mão — fique exatamente a um braço de distância do ombro e abaixo da mão.
func _pose_empunhadura_e(centro: Vector3, emp: Dictionary) -> Transform3D:
	var w := _arma.global_basis.orthonormalized()
	var eixo := (w * (emp.eixo as Vector3)).normalized()
	var r0 := (w * (emp.ref as Vector3)).normalized()
	var r1 := eixo.cross(r0).normalized()
	var sentido := float(emp.sentido)
	var escala := _esqueleto.global_basis.get_scale().x
	var ombro := _esqueleto.global_transform * _esqueleto.get_bone_global_pose(_osso(BRACO_E[0])).origin
	var lu := _comp_braco_e * escala
	var lf := _comp_ante_e * escala
	var raio: float = _guarda_raio if float(emp.raio) < 0.0 else float(emp.raio)
	var dist := raio + float(emp.afasta)
	var giros: Array = emp.giro
	var incls: Array = emp.incl
	var melhor := INF
	var melhor_xf := Transform3D.IDENTITY
	var melhor_g := _giro_e
	var melhor_i := _incl_e
	var g := float(giros[1])
	while g <= float(giros[2]) + 0.01:
		var incl := float(incls[0])
		while incl <= float(incls[1]) + 0.01:
			var gr := deg_to_rad(g)
			var n := (r0 * cos(gr) + r1 * sin(gr)).normalized()   # palma olha para o eixo
			var f0 := eixo.cross(n).normalized() * sentido          # dedos dão a volta no cilindro
			var ir := deg_to_rad(incl)
			var f := (f0 * cos(ir) + eixo * sin(ir)).normalized()
			var s := n.cross(f).normalized()   # lado do polegar (mão esquerda: palma = dedos x polegar)
			var alvo := Basis(f, s, n)
			var punho := centro - n * dist - alvo * _palma_e * escala
			var cotovelo := punho - f * lf
			var erro := absf(cotovelo.distance_to(ombro) - lu) * 10.0
			erro += maxf(cotovelo.y - (punho.y - 0.03), 0.0) * 4.0       # cotovelo abaixo da mão
			erro += absf(g - float(giros[0])) * 0.004 + absf(incl - float(incls[2])) * 0.003
			erro += (absf(g - _giro_e) + absf(incl - _incl_e)) * 0.002   # sem tremer entre quadros
			if erro < melhor:
				melhor = erro
				melhor_xf = Transform3D(alvo * _quadro_mao_e.inverse() * _rest_mao_e, punho)
				melhor_g = g
				melhor_i = incl
			incl += 10.0
		g += 10.0
	_giro_e = melhor_g
	_incl_e = melhor_i
	return melhor_xf


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
	ik.osso_dedo_medio = "middle_01_r" if nomes == BRACO_D else "middle_01_l"
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
		# Mesmo arma sem coronha (ou coronha dobrada) fica com o cabo a um palmo do
		# ombro: com menos que isso o braço direito não cabe (pulso torto).
		var traseira := maxf(_comprimento_traseiro(_arma), 0.2)
		# Cabo na frente do ombro: a coronha (traseira) encosta no ombro.
		# A coronha apoia na "concha" do ombro: na FRENTE da articulação (na pele, ~6 cm
		# à frente), um pouco para dentro (lado do peito) e abaixo — não dentro do ombro.
		var cabo := _concha_ombro + Vector3(0, 0, 1) * traseira + aj_pos
		var base := (Basis(Vector3.UP, PI) * aj_rot).scaled(Vector3.ONE * aj_esc)
		# mirando: um pouco à frente e para fora do peitoral (a caixa da arma não entra no
		# peito; o braço direito fica com espaço)
		var desejado := Transform3D(base, cabo + Vector3(-0.03, 0, 0.04))
		_base_arma_mira = _pose_peito_mira.affine_inverse() * desejado * mao_local.affine_inverse()
		# Pronto baixo: cano inclinado para baixo, girando em volta do ombro
		var ang := deg_to_rad(dados.angulo_pronto_baixo)
		# gira em volta de onde a coronha apoia (a coronha não sobe para dentro do ombro)
		var piv := _concha_ombro
		# ...e vai um pouco para a frente e para fora (lado da mão do cabo): o cabo não
		# cola na barriga e o braço direito tem espaço (pulso sem dobrar demais).
		var baixo := Transform3D.IDENTITY.translated(piv + Vector3(-0.05, -0.03, 0.07)) * Transform3D(Basis(Vector3.RIGHT, ang)) * Transform3D.IDENTITY.translated(-piv) * desejado
		_base_arma_baixa = _pose_peito_mira.affine_inverse() * baixo * mao_local.affine_inverse()
		_arma.transform = _base_arma_baixa
		_arma_longa = true
		_usar_mira("fuzil")
		_alvo_arma_d = _arma.get_node("Mao")
		_alvo_arma_e = _arma.get_node_or_null("MaoEsquerda")
		if _alvo_arma_e == null:
			_alvo_arma_e = _alvo_arma_d
		_guarda_local = _baixo_do_guarda_mao(_arma, _alvo_arma_e.position)
		if not _pendurado:
			_ik_d.alvo = _alvo_arma_d
			_ik_e.alvo = _alvo_empunhadura_e
	else:
		_anexo_mao.add_child(_arma)
		# Posiciona pelo ponto "Mao" da arma.
		_base_arma_mao = _calibracao_mao * Transform3D(aj_rot.scaled(Vector3.ONE * aj_esc), aj_pos) * mao_local.affine_inverse()
		_arma.transform = _base_arma_mao
	return _arma


## Onde a palma da mão esquerda encosta: a parte de BAIXO do guarda-mão, na altura
## (z) do marcador MaoEsquerda. Um raio vertical desce pela geometria da arma; o
## corpo da arma ali é o que fica até ~9 cm abaixo da superfície de cima (cano +
## guarda-mão). Assim a mão não fica "pendurada" se o marcador estiver baixo.
func _baixo_do_guarda_mao(arma: Node3D, marcador: Vector3) -> Vector3:
	var inv := arma.global_transform.affine_inverse()
	var de := Vector3(0, 1.0, marcador.z)
	var ys: Array[float] = []
	for mi in arma.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = inv * mi.global_transform
		var malha: Mesh = mi.mesh
		if malha == null:
			continue
		for i in malha.get_surface_count():
			var tri: PackedVector3Array = malha.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
			var idx = malha.surface_get_arrays(i)[Mesh.ARRAY_INDEX]
			var n: int = idx.size() if idx != null and idx.size() > 0 else tri.size()
			for k in range(0, n - 2, 3):
				var a := xf * tri[idx[k] if idx else k]
				var b := xf * tri[idx[k + 1] if idx else k + 1]
				var c := xf * tri[idx[k + 2] if idx else k + 2]
				var hit = Geometry3D.ray_intersects_triangle(de, Vector3.DOWN, a, b, c)
				if hit == null:
					hit = Geometry3D.ray_intersects_triangle(de, Vector3.DOWN, a, c, b)
				if hit != null:
					ys.append(hit.y)
	if ys.is_empty():
		return marcador
	var topo: float = ys.max()
	var baixo := topo
	for y in ys:
		if y >= topo - 0.09:
			baixo = minf(baixo, y)
	# raio do "cilindro" que a mão abraça (guarda-mão), sem exagerar
	_guarda_raio = clampf((topo - baixo) * 0.5, 0.015, 0.03)
	return Vector3(marcador.x, baixo, marcador.z)


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


## Botas de verdade. O corpo base tem os dedos do pé esculpidos (parece descalço
## mesmo pintado). A bota é uma cópia da malha do pé (e do tornozelo, até o cano),
## suavizada (os dedos viram um bico arredondado) e um pouco inflada, presa aos
## MESMOS ossos com os mesmos pesos: dobra junto na passada, como uma bota real.
## Serve para qualquer modelo de mesmo esqueleto (é gerada da malha dele).
const COR_BOTA := Color(0.1, 0.085, 0.07)
const ESPESSURA_BOTA := 0.011
const ALTURA_CANO := 0.1          # acima do osso do tornozelo
static var _malhas_bota := {}      # malha do corpo -> ArrayMesh da bota (gera uma vez)


func _criar_botas() -> void:
	if _corpo == null or _corpo.skin == null:
		return
	var malha: ArrayMesh = _malhas_bota.get(_corpo.mesh)
	if malha == null:
		malha = _gerar_malha_bota()
		if malha == null:
			return
		_malhas_bota[_corpo.mesh] = malha
	var mi := MeshInstance3D.new()
	mi.name = "Botas"
	mi.mesh = malha
	mi.skin = _corpo.skin
	_corpo.get_parent().add_child(mi)
	mi.transform = _corpo.transform
	mi.skeleton = mi.get_path_to(_esqueleto)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COR_BOTA
	mat.roughness = 0.7
	mi.material_override = mat


func _gerar_malha_bota() -> ArrayMesh:
	var skin := _corpo.skin
	var pes := {}       # índice do bind -> é pé (foot/ball)
	var canela := {}    # índice do bind -> é canela (calf): entra só perto do tornozelo
	for i in skin.get_bind_count():
		var nome := String(skin.get_bind_name(i))
		if nome == "":
			nome = _esqueleto.get_bone_name(skin.get_bind_bone(i))
		if nome.begins_with("foot_") or nome.begins_with("ball_"):
			pes[i] = true
		elif nome.begins_with("calf_"):
			canela[i] = true
	var y_tornozelo := _esqueleto.get_bone_global_rest(_esqueleto.find_bone("foot_l")).origin.y
	var pos := PackedVector3Array()
	var regiao_v := PackedInt32Array()   # osso dominante (foot/ball de cada lado) ou -1 (cano)
	var ossos := PackedInt32Array()
	var pesos := PackedFloat32Array()
	var indices := PackedInt32Array()
	var por := 4
	for sfc in _corpo.mesh.get_surface_count():
		var arr := _corpo.mesh.surface_get_arrays(sfc)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bs = arr[Mesh.ARRAY_BONES]
		var ws = arr[Mesh.ARRAY_WEIGHTS]
		var ind = arr[Mesh.ARRAY_INDEX]
		if bs == null or ws == null or bs.size() == 0 or ind == null:
			continue
		por = bs.size() / vs.size()
		var e_bota := PackedByteArray()
		e_bota.resize(vs.size())
		var dom := PackedInt32Array()
		dom.resize(vs.size())
		for v in vs.size():
			var melhor: int = -1
			var peso: float = 0.0
			for k in por:
				if ws[v * por + k] > peso:
					peso = ws[v * por + k]
					melhor = bs[v * por + k]
			var ok: bool = pes.has(melhor) or (canela.has(melhor) and vs[v].y < y_tornozelo + ALTURA_CANO)
			e_bota[v] = 1 if ok else 0
			dom[v] = melhor if pes.has(melhor) else -1
		var novo := {}
		for t in range(0, ind.size(), 3):
			if e_bota[ind[t]] == 0 or e_bota[ind[t + 1]] == 0 or e_bota[ind[t + 2]] == 0:
				continue
			for k in 3:
				var v: int = ind[t + k]
				if not novo.has(v):
					novo[v] = pos.size()
					pos.append(vs[v])
					regiao_v.append(dom[v])
					for q in por:
						ossos.append(bs[v * por + q])
						pesos.append(ws[v * por + q])
				indices.append(novo[v])
	if indices.is_empty():
		return null
	# Vértices na mesma posição (costuras de UV) andam juntos.
	var grupo := PackedInt32Array()
	grupo.resize(pos.size())
	var chaves := {}
	for v in pos.size():
		var c := Vector3i((pos[v] * 2000.0).round())
		if not chaves.has(c):
			chaves[c] = chaves.size()
		grupo[v] = chaves[c]
	var ng := chaves.size()
	var gp := PackedVector3Array()
	gp.resize(ng)
	for v in pos.size():
		gp[grupo[v]] = pos[v]
	var vizinhos := []
	vizinhos.resize(ng)
	for g in ng:
		vizinhos[g] = {}
	for t in range(0, indices.size(), 3):
		for k in 3:
			var a := grupo[indices[t + k]]
			var b := grupo[indices[t + (k + 1) % 3]]
			vizinhos[a][b] = true
			vizinhos[b][a] = true
	var g_regiao := PackedInt32Array()
	g_regiao.resize(ng)
	for v in pos.size():
		g_regiao[grupo[v]] = regiao_v[v]
	# Envelope: cada parte do pé (bico = osso ball; pé = osso foot) vira a casca
	# convexa dos seus pontos — fecha o vão entre os dedos e o arco do pé, como uma
	# bota. Casca aproximada por 96 planos (k-DOP) e projeção a partir do centro.
	var dirs := []
	for k in 96:
		var yk := 1.0 - (k + 0.5) / 48.0
		var r := sqrt(maxf(1.0 - yk * yk, 0.0))
		var ang := k * 2.399963
		dirs.append(Vector3(cos(ang) * r, yk, sin(ang) * r))
	var regioes := {}
	for g in ng:
		if g_regiao[g] >= 0:
			if not regioes.has(g_regiao[g]):
				regioes[g_regiao[g]] = []
			regioes[g_regiao[g]].append(g)
	for rg in regioes:
		var membros: Array = regioes[rg]
		var centro := Vector3.ZERO
		for g in membros:
			centro += gp[g]
		centro /= membros.size()
		var limites := []
		for d in dirs:
			var m := -INF
			for g in membros:
				m = maxf(m, (d as Vector3).dot(gp[g]))
			limites.append(m)
		for g in membros:
			var dir: Vector3 = gp[g] - centro
			if dir.length_squared() < 1e-8:
				continue
			var t := INF
			for k in dirs.size():
				var nd: float = (dirs[k] as Vector3).dot(dir)
				if nd > 1e-6:
					t = minf(t, (float(limites[k]) - (dirs[k] as Vector3).dot(centro)) / nd)
			if t < INF and t > 1.0:
				gp[g] = centro + dir * t
	# Borda de cima do cano reta (sem dentes)
	var uso := {}
	for t in range(0, indices.size(), 3):
		for k in 3:
			var a := grupo[indices[t + k]]
			var b := grupo[indices[t + (k + 1) % 3]]
			var e := Vector2i(mini(a, b), maxi(a, b))
			uso[e] = uso.get(e, 0) + 1
	var y_corte := y_tornozelo + ALTURA_CANO
	for e in uso:
		if uso[e] == 1:
			for g in [e.x, e.y]:
				if g_regiao[g] < 0:
					gp[g].y = y_corte
	# Suavização de Taubin leve (junta as partes sem degraus e sem encolher)
	for it in 6:
		var fator := 0.5 if it % 2 == 0 else -0.53
		var nova := gp.duplicate()
		for g in ng:
			var soma := Vector3.ZERO
			var n := 0
			for b in vizinhos[g]:
				soma += gp[b]
				n += 1
			if n > 0:
				nova[g] = gp[g] + (soma / n - gp[g]) * fator
		gp = nova
	# Normais e espessura (infla para fora: cobre o pé de baixo)
	var normais := PackedVector3Array()
	normais.resize(ng)
	for t in range(0, indices.size(), 3):
		var a := gp[grupo[indices[t]]]
		var b := gp[grupo[indices[t + 1]]]
		var c := gp[grupo[indices[t + 2]]]
		var nf := (b - a).cross(c - a)
		for k in 3:
			normais[grupo[indices[t + k]]] += nf
	var final_pos := PackedVector3Array()
	var final_n := PackedVector3Array()
	for v in pos.size():
		var g := grupo[v]
		# Godot: faces da frente em sentido horário -> (b-a)x(c-a) aponta para DENTRO.
		var n := -normais[g].normalized()
		final_n.append(n)
		final_pos.append(gp[g] + n * ESPESSURA_BOTA)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = final_pos
	arrays[Mesh.ARRAY_NORMAL] = final_n
	arrays[Mesh.ARRAY_BONES] = ossos
	arrays[Mesh.ARRAY_WEIGHTS] = pesos
	arrays[Mesh.ARRAY_INDEX] = indices
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if por == 8 else 0)
	return am


func _aplicar_skin() -> void:
	if _corpo == null or texturas_skin.is_empty():
		return
	var tex: Texture2D = texturas_skin[clamp(skin, 0, texturas_skin.size() - 1)]
	var mat := _corpo.mesh.surface_get_material(0)
	if mat is BaseMaterial3D:
		mat = mat.duplicate()  # duplicar: não afeta outros personagens
		mat.albedo_texture = tex
		_corpo.set_surface_override_material(0, mat)
