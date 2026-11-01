extends Node3D
## Personagem humano a partir de um modelo .gltf/.glb com esqueleto humanoide.
##
## Cumpre o mesmo contrato do modelo provisório: atualizar_animacao(estado, fator, mirando).
## As animações vêm de UMA biblioteca compartilhada (assets/animations/animacoes_humanas.glb),
## carregada uma vez só e reaproveitada por todos os personagens (economiza memória).
##
## Para trocar o modelo: aponte "cena_modelo" para outro .glb com o MESMO esqueleto
## (nomes de ossos estilo UE: pelvis, spine_01, thigh_l...). Nada de código muda.

const CAMINHO_ANIMACOES := "res://assets/animations/animacoes_humanas.glb"
## Tempo de transição entre animações (crossfade), em segundos.
const MISTURA := 0.18

@export var cena_modelo: PackedScene
## Texturas de cor alternativas (skins de tom de pele). A primeira é a original.
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
var _ap: AnimationPlayer
var _corpo: MeshInstance3D
var _atual := ""


func _ready() -> void:
	_modelo = cena_modelo.instantiate()
	_modelo.rotation.y = PI  # o .gltf olha para +Z; no jogo a frente é -Z
	add_child(_modelo)

	_ap = AnimationPlayer.new()
	_ap.name = "AnimationPlayer"
	_modelo.add_child(_ap)
	_ap.root_node = NodePath("..")
	_ap.add_animation_library("", _obter_biblioteca())
	_ap.playback_default_blend_time = MISTURA

	# Corpo principal = maior malha do modelo (onde a skin é aplicada).
	var maior := 0.0
	for mi in _modelo.find_children("*", "MeshInstance3D", true, false):
		var tam: float = mi.get_aabb().get_volume()
		if tam > maior:
			maior = tam
			_corpo = mi
	_prender_acessorios()
	_aplicar_skin()
	_tocar("Idle")


func _prender_acessorios() -> void:
	if acessorios_cabeca.is_empty():
		return
	var esq: Skeleton3D = _modelo.find_child("Skeleton3D")
	var osso := esq.find_bone("Head")
	if osso < 0:
		return
	var anexo := BoneAttachment3D.new()
	anexo.bone_name = "Head"
	esq.add_child(anexo)
	# Desfaz a posição de repouso da cabeça: o acessório foi modelado no
	# espaço do corpo inteiro, e o anexo já está na cabeça.
	var inverso := esq.get_bone_global_rest(osso).affine_inverse()
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


static func _obter_biblioteca() -> AnimationLibrary:
	if _biblioteca == null:
		var cena: Node = load(CAMINHO_ANIMACOES).instantiate()
		var ap: AnimationPlayer = cena.find_child("AnimationPlayer")
		_biblioteca = ap.get_animation_library("")
		cena.free()
	return _biblioteca


func _aplicar_skin() -> void:
	if _corpo == null or texturas_skin.is_empty():
		return
	var tex: Texture2D = texturas_skin[clamp(skin, 0, texturas_skin.size() - 1)]
	var mat := _corpo.mesh.surface_get_material(0)
	if mat is BaseMaterial3D:
		mat = mat.duplicate()  # duplicar: não afeta outros personagens
		mat.albedo_texture = tex
		_corpo.set_surface_override_material(0, mat)


func _tocar(nome: String, velocidade: float = 1.0) -> void:
	_ap.speed_scale = velocidade
	if nome != _atual:
		_atual = nome
		_ap.play(nome)


## Escolhe a animação conforme o estado do personagem.
func atualizar_animacao(estado: StringName, fator_vel: float, mirando: bool) -> void:
	match estado:
		&"correndo":
			if fator_vel < 0.35:
				_tocar("Walk", clamp(fator_vel / 0.25, 0.6, 1.4))
			elif fator_vel < 0.75:
				_tocar("Jog_Fwd", clamp(fator_vel / 0.6, 0.8, 1.3))
			else:
				_tocar("Sprint", clamp(fator_vel, 0.85, 1.2))
		&"pulando", &"caindo":
			_tocar("Jump")
		_:
			_tocar("Pistol_Idle" if mirando else "Idle")
