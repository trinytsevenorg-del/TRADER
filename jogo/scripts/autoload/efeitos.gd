extends Node3D
## Efeitos visuais de combate com "pool" (objetos reaproveitados, nada é criado
## ou destruído durante a partida = sem engasgos do coletor de lixo):
##  - rastro da bala (linha fina e brilhante do cano até o acerto)
##  - impacto (fagulha/poeira onde a bala bateu)
##  - números de dano flutuando
## Uso: Efeitos.rastro(de, ate, cor) / Efeitos.impacto(pos, normal) / Efeitos.numero(pos, 25, cabeca)
##
## SONS (assets/sons/<nome>.wav, gerados por tools/gerar_sons.py):
##   Efeitos.som_3d("tiro_fuzil", posicao)   som no mundo (volume cai com a distância)
##   Efeitos.som_2d("acerto")                som de interface (sempre igual)

const QTD_RASTROS := 32
const QTD_IMPACTOS := 24
const QTD_NUMEROS := 16
const QTD_SONS_3D := 16
const QTD_SONS_2D := 4

var _rastros: Array[MeshInstance3D] = []
var _vida_rastros: Array[float] = []
var _impactos: Array[MeshInstance3D] = []
var _vida_impactos: Array[float] = []
var _numeros: Array[Label3D] = []
var _vida_numeros: Array[float] = []
var _i_rastro := 0
var _i_impacto := 0
var _i_numero := 0
var _sons_3d: Array[AudioStreamPlayer3D] = []
var _sons_2d: Array[AudioStreamPlayer] = []
var _i_som_3d := 0
var _i_som_2d := 0
var _cache_sons := {}


func _ready() -> void:
	var malha_rastro := BoxMesh.new()
	malha_rastro.size = Vector3(0.025, 0.025, 1.0)
	for i in QTD_RASTROS:
		var m := MeshInstance3D.new()
		m.mesh = malha_rastro
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		m.top_level = true
		add_child(m)
		_rastros.append(m)
		_vida_rastros.append(0.0)

	var malha_imp := BoxMesh.new()
	malha_imp.size = Vector3(0.09, 0.09, 0.09)
	var mat_imp := StandardMaterial3D.new()
	mat_imp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_imp.albedo_color = Color(1.0, 0.75, 0.35)
	for i in QTD_IMPACTOS:
		var m := MeshInstance3D.new()
		m.mesh = malha_imp
		m.material_override = mat_imp
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		m.top_level = true
		add_child(m)
		_impactos.append(m)
		_vida_impactos.append(0.0)

	for i in QTD_SONS_3D:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 8.0
		p.max_distance = 70.0
		p.attenuation_filter_cutoff_hz = 9000.0
		add_child(p)
		_sons_3d.append(p)
	for i in QTD_SONS_2D:
		var p2 := AudioStreamPlayer.new()
		add_child(p2)
		_sons_2d.append(p2)

	for i in QTD_NUMEROS:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0012
		l.font_size = 30
		l.outline_size = 8
		l.visible = false
		l.top_level = true
		add_child(l)
		_numeros.append(l)
		_vida_numeros.append(0.0)


func rastro(de: Vector3, ate: Vector3, cor: Color) -> void:
	var dist := de.distance_to(ate)
	if dist < 0.3:
		return
	var m := _rastros[_i_rastro]
	_vida_rastros[_i_rastro] = 0.07
	_i_rastro = (_i_rastro + 1) % QTD_RASTROS
	var meio := (de + ate) * 0.5
	m.global_transform = Transform3D(Basis.looking_at(ate - de, Vector3.UP if abs((ate - de).normalized().y) < 0.99 else Vector3.RIGHT), meio)
	m.scale = Vector3(1, 1, dist)
	(m.material_override as StandardMaterial3D).albedo_color = cor
	m.visible = true


func impacto(pos: Vector3, normal: Vector3) -> void:
	var m := _impactos[_i_impacto]
	_vida_impactos[_i_impacto] = 0.18
	_i_impacto = (_i_impacto + 1) % QTD_IMPACTOS
	m.global_position = pos + normal * 0.03
	m.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
	m.scale = Vector3.ONE
	m.visible = true


func numero(pos: Vector3, valor: float, cabeca: bool, abate: bool = false) -> void:
	var l := _numeros[_i_numero]
	_vida_numeros[_i_numero] = 0.7
	_i_numero = (_i_numero + 1) % QTD_NUMEROS
	l.text = str(roundi(valor))
	l.modulate = Color(1, 0.25, 0.2) if abate else (Color(1, 0.85, 0.2) if cabeca else Color.WHITE)
	l.font_size = 40 if cabeca or abate else 30
	l.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0.3, randf_range(-0.2, 0.2))
	l.visible = true


func _process(delta: float) -> void:
	for i in QTD_RASTROS:
		if _vida_rastros[i] > 0.0:
			_vida_rastros[i] -= delta
			var mat := _rastros[i].material_override as StandardMaterial3D
			mat.albedo_color.a = clamp(_vida_rastros[i] / 0.07, 0.0, 1.0) * 0.9
			if _vida_rastros[i] <= 0.0:
				_rastros[i].visible = false
	for i in QTD_IMPACTOS:
		if _vida_impactos[i] > 0.0:
			_vida_impactos[i] -= delta
			_impactos[i].scale = Vector3.ONE * (0.3 + _vida_impactos[i] / 0.18)
			if _vida_impactos[i] <= 0.0:
				_impactos[i].visible = false
	for i in QTD_NUMEROS:
		if _vida_numeros[i] > 0.0:
			_vida_numeros[i] -= delta
			_numeros[i].global_position.y += delta * 1.2
			_numeros[i].modulate.a = clamp(_vida_numeros[i] / 0.3, 0.0, 1.0)
			if _vida_numeros[i] <= 0.0:
				_numeros[i].visible = false


# =========================================================================
#  SONS
# =========================================================================

func _som(nome: String) -> AudioStream:
	if not _cache_sons.has(nome):
		var c := "res://assets/sons/%s.wav" % nome
		_cache_sons[nome] = load(c) if ResourceLoader.exists(c) else null
	return _cache_sons[nome]


## Som no mundo 3D. variacao = quanto o tom pode variar (evita repetição robótica).
func som_3d(nome: String, pos: Vector3, volume_db := 0.0, variacao := 0.06) -> void:
	var s := _som(nome)
	if s == null:
		return
	var p := _sons_3d[_i_som_3d]
	_i_som_3d = (_i_som_3d + 1) % QTD_SONS_3D
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-variacao, variacao)
	p.play()


## Som de interface (sem posição).
func som_2d(nome: String, volume_db := 0.0) -> void:
	var s := _som(nome)
	if s == null:
		return
	var p := _sons_2d[_i_som_2d]
	_i_som_2d = (_i_som_2d + 1) % QTD_SONS_2D
	p.stream = s
	p.volume_db = volume_db
	p.play()
