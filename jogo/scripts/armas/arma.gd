extends Node3D
class_name ModeloArma
## Raiz da cena de cada arma (weapons/modelos/*.tscn).
##
## Convenção: a frente da arma é -Z e o topo é +Y.
## Pontos de encaixe (Marker3D) que TODA cena de arma deve ter:
##   Mao  - onde a mão direita segura (o modelo é posicionado por este ponto)
##   Cano - saída do tiro (clarão e rastro saem daqui)
##   Mira - ponto da mira/luneta
## Para trocar o modelo provisório por um .glb: apague o nó "Modelo", arraste o
## .glb para a cena, renomeie para "Modelo" e mova os três Marker3D para os
## lugares certos. Nenhum código precisa mudar.

@onready var mao: Marker3D = $Mao
@onready var cano: Marker3D = $Cano
@onready var mira: Marker3D = $Mira

var _clarao: MeshInstance3D
var _tempo_clarao := 0.0
var _coice := 0.0


func _ready() -> void:
	# Clarão do disparo: um losango emissivo (sem luz dinâmica = barato no celular).
	_clarao = MeshInstance3D.new()
	var malha := PrismMesh.new()
	malha.size = Vector3(0.12, 0.22, 0.12)
	_clarao.mesh = malha
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.8, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_clarao.material_override = mat
	_clarao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clarao.rotation.x = -PI / 2.0
	_clarao.position.z = -0.1
	_clarao.visible = false
	cano.add_child(_clarao)


func _process(delta: float) -> void:
	if _tempo_clarao > 0.0:
		_tempo_clarao -= delta
		if _tempo_clarao <= 0.0:
			_clarao.visible = false
	# Coice: a arma volta suavemente para a posição.
	if _coice > 0.0:
		_coice = move_toward(_coice, 0.0, delta * 1.2)
		var modelo := get_node_or_null("Modelo") as Node3D
		if modelo:
			modelo.position.z = _coice * 0.6
			modelo.rotation.x = _coice * 1.5


func disparou(forca: float = 0.08) -> void:
	_clarao.visible = true
	_clarao.rotation.y = randf() * TAU
	_clarao.scale = Vector3.ONE * randf_range(0.8, 1.3)
	_tempo_clarao = 0.05
	_coice = max(_coice, forca)


## Skins de arma (etapa 7): troca só o material, mesmo modelo.
func aplicar_material(mat: Material) -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		if mi != _clarao:
			mi.material_override = mat
