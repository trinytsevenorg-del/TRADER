extends Node3D
## Gera uma arma PROVISÓRIA low-poly por código (corpo, cano, pente, coronha,
## luneta). Fica no nó "Modelo" de cada cena de arma; quando houver um .glb,
## é só substituir este nó (veja scripts/armas/arma.gd).
##
## Todas as peças usam UM material (cor) + um de detalhe: poucos draw calls.

@export var comprimento_corpo := 0.45
@export var altura_corpo := 0.11
@export var largura := 0.06
@export var comprimento_cano := 0.25
@export var diametro_cano := 0.035
@export var tamanho_pente := 0.16
@export var comprimento_coronha := 0.22
@export var tem_luneta := false
@export var tambor := false            ## pente redondo (metralhadora)
@export var cor := Color(0.18, 0.19, 0.2)
@export var cor_detalhe := Color(0.45, 0.35, 0.22)


func _ready() -> void:
	var m := _mat(cor)
	var md := _mat(cor_detalhe)
	# Origem = empunhadura (mão). Frente = -Z.
	var frente := -comprimento_corpo * 0.7          # onde o corpo termina na frente
	_caixa(Vector3(0, altura_corpo * 0.5 + 0.02, -comprimento_corpo * 0.2), Vector3(largura, altura_corpo, comprimento_corpo), m)
	# Cabo (pistol grip)
	_caixa(Vector3(0, -0.03, 0.02), Vector3(largura * 0.85, 0.12, 0.05), md, Vector3(-18, 0, 0))
	# Cano
	var cano := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = diametro_cano * 0.5
	cil.bottom_radius = diametro_cano * 0.5
	cil.height = comprimento_cano
	cil.radial_segments = 8
	cano.mesh = cil
	cano.material_override = m
	cano.rotation.x = PI / 2.0
	cano.position = Vector3(0, altura_corpo * 0.7, frente - comprimento_cano * 0.5)
	add_child(cano)
	# Pente
	if tamanho_pente > 0.0:
		if tambor:
			_caixa(Vector3(0, -0.06, -0.12), Vector3(largura * 1.6, 0.12, 0.12), md)
		else:
			_caixa(Vector3(0, -tamanho_pente * 0.4, -0.1), Vector3(largura * 0.7, tamanho_pente, 0.05), md, Vector3(12, 0, 0))
	# Coronha
	if comprimento_coronha > 0.0:
		_caixa(Vector3(0, altura_corpo * 0.35, comprimento_coronha * 0.5 + 0.05), Vector3(largura * 0.8, altura_corpo * 0.9, comprimento_coronha), md)
	# Luneta
	if tem_luneta:
		var lun := MeshInstance3D.new()
		var c2 := CylinderMesh.new()
		c2.top_radius = 0.028
		c2.bottom_radius = 0.028
		c2.height = 0.24
		c2.radial_segments = 8
		lun.mesh = c2
		lun.material_override = m
		lun.rotation.x = PI / 2.0
		lun.position = Vector3(0, altura_corpo + 0.07, -comprimento_corpo * 0.25)
		add_child(lun)


func _mat(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.6
	mat.metallic = 0.3
	return mat


func _caixa(pos: Vector3, tam: Vector3, mat: Material, rot_graus := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_graus
	add_child(mi)
