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
	"tiro": "Pistol_Shoot", "recarga": "Pistol_Reload",
}
## Tempo de transição entre animações (crossfade), em segundos.
const MISTURA := 0.15
## Animações de locomoção usadas (nomes da biblioteca).
const LOCOMOCAO := ["parado", "parado_arma", "andar", "trote", "correr", "pulo", "parede",
	"subindo_parede", "escalar", "rolar", "deslizar", "morrer"]
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
	var bs := AnimationNodeBlendSpace1D.new()
	for par in [["Pistol_Aim_Down", -1.0], ["Pistol_Aim_Neutral", 0.0], ["Pistol_Aim_Up", 1.0]]:
		var an := AnimationNodeAnimation.new()
		an.animation = par[0]
		bs.add_blend_point(an, par[1])
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


## Escolhe a animação conforme o estado do personagem.
## (Animações que o pacote CC0 não tem, como deslize e corrida na parede, usam uma
##  animação parecida + inclinação do corpo feita pelo script do jogador. Na etapa 6
##  dá para colocar animações do Mixamo no lugar; veja o README.)
func atualizar_animacao(estado: StringName, fator_vel: float, mirando: bool) -> void:
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
		_:
			_tocar("parado_arma" if (mirando or _arma != null) else "parado")


## Tronco e braços mirando. peso 0..1; pitch -1 (baixo) .. 1 (cima).
func definir_mira(peso: float, pitch: float) -> void:
	_peso_mira_alvo = peso
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


func prender_arma(cena: PackedScene) -> ModeloArma:
	if _arma:
		_arma.queue_free()
		_arma = null
	if cena == null or _anexo_mao == null:
		return null
	_arma = cena.instantiate() as ModeloArma
	_anexo_mao.add_child(_arma)
	# Posiciona pelo ponto "Mao" da arma.
	var mao_local: Transform3D = (_arma.get_node("Mao") as Node3D).transform
	_arma.transform = _calibracao_mao * mao_local.affine_inverse()
	return _arma


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
