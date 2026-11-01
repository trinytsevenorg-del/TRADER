@tool
extends Node3D
class_name PecaMapa
## Base de todas as peças do mapa (prédio, container, caixa, escada...).
##
## Cada peça é uma cena separada em scenes/mapa/pecas/*.tscn e gera sua geometria
## low-poly por código (aparece no editor graças ao @tool). Os nós gerados NÃO são
## salvos na cena: só os parâmetros (tamanho, cor...) ficam no arquivo.
##
## TROCAR POR UM MODELO .glb:
##   1) abra a cena da peça (ou a instância no mapa) e desmarque "gerar";
##   2) arraste o .glb para dentro dela e adicione as colisões
##      (StaticBody3D + CollisionShape3D) na camada 1 ("mundo").
##   O mapa continua funcionando igual (inclusive a mesclagem de malhas).

## Desligue para usar um modelo próprio no lugar da geometria gerada.
@export var gerar := true:
	set(v):
		gerar = v
		_pedir_reconstrucao()

var _corpo: StaticBody3D
var _gerado: Node3D
var _assinatura := ""
var _tempo_editor := 0.0


func _ready() -> void:
	_reconstruir()


## Peças concretas implementam isto usando caixa(), cilindro(), etc.
func _construir() -> void:
	pass


func _pedir_reconstrucao() -> void:
	if is_inside_tree():
		_reconstruir.call_deferred()


func _reconstruir() -> void:
	if _gerado:
		_gerado.free()
		_gerado = null
	_corpo = null
	if not gerar:
		return
	_gerado = Node3D.new()
	_gerado.name = "_Gerado"
	add_child(_gerado)  # sem "owner": não é salvo no .tscn
	_corpo = StaticBody3D.new()
	_corpo.collision_layer = 1
	_corpo.collision_mask = 0
	_gerado.add_child(_corpo)
	_construir()
	_assinatura = _calcular_assinatura()


# No editor: reconstrói quando algum parâmetro muda no Inspetor.
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	_tempo_editor += delta
	if _tempo_editor < 0.3:
		return
	_tempo_editor = 0.0
	var a := _calcular_assinatura()
	if a != _assinatura:
		_reconstruir()


func _calcular_assinatura() -> String:
	var partes := []
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_EDITOR:
			partes.append(str(get(p.name)))
	return "|".join(partes)


# =========================================================================
#  Ferramentas de construção
# =========================================================================

## Caixa com malha e (opcional) colisão. detalhe = objeto pequeno, some de longe.
func caixa(pos: Vector3, tam: Vector3, mat: Material, colisao := true,
		rot_graus := Vector3.ZERO, detalhe := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_graus
	if detalhe:
		mi.set_meta("detalhe", true)
	_gerado.add_child(mi)
	if colisao:
		var cs := CollisionShape3D.new()
		var forma := BoxShape3D.new()
		forma.size = tam
		cs.shape = forma
		cs.position = pos
		cs.rotation_degrees = rot_graus
		_corpo.add_child(cs)
	return mi


## Bloco "inclinado" (paralelepípedo) com cantos origem + a*u + b*v + c*w (a,b,c em 0..1).
## Serve para muretas/corrimãos que acompanham uma escada sem quinas para fora.
## Visual e colisão têm exatamente a mesma forma.
func paralelepipedo(origem: Vector3, u: Vector3, v: Vector3, w: Vector3, mat: Material,
		colisao := true) -> MeshInstance3D:
	var c := []
	for k in 8:
		c.append(origem + u * float(k & 1) + v * float((k >> 1) & 1) + w * float((k >> 2) & 1))
	var centro: Vector3 = origem + (u + v + w) * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 6 faces (índices dos cantos), cada uma em 2 triângulos virados para fora
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		var a: Vector3 = c[f[0]]
		var b: Vector3 = c[f[1]]
		var d: Vector3 = c[f[2]]
		var e: Vector3 = c[f[3]]
		var n := (b - a).cross(d - a).normalized()
		var ordem := [a, b, d, a, d, e]
		if n.dot((a + b + d + e) * 0.25 - centro) < 0.0:
			n = -n
			ordem = [a, d, b, a, e, d]
		for pt in ordem:
			st.set_normal(n)
			st.add_vertex(pt)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	_gerado.add_child(mi)
	if colisao:
		var cs := CollisionShape3D.new()
		var forma := ConvexPolygonShape3D.new()
		forma.points = PackedVector3Array(c)
		cs.shape = forma
		_corpo.add_child(cs)
	return mi


func cilindro(pos: Vector3, raio: float, altura: float, mat: Material, lados := 10,
		colisao := true, detalhe := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = raio
	c.bottom_radius = raio
	c.height = altura
	c.radial_segments = lados
	c.rings = 1
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	if detalhe:
		mi.set_meta("detalhe", true)
	_gerado.add_child(mi)
	if colisao:
		var cs := CollisionShape3D.new()
		var forma := CylinderShape3D.new()
		forma.radius = raio
		forma.height = altura
		cs.shape = forma
		cs.position = pos
		_corpo.add_child(cs)
	return mi


func esfera(pos: Vector3, raio: float, mat: Material, detalhe := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = raio
	s.height = raio * 1.8
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	if detalhe:
		mi.set_meta("detalhe", true)
	_gerado.add_child(mi)
	return mi


## Colisão em rampa invisível de "a" até "b" (pontos do piso), com largura.
## Usada em escadas: o personagem sobe liso, sem "engasgar" nos degraus.
func rampa_colisao(a: Vector3, b: Vector3, largura: float) -> void:
	var meio := (a + b) * 0.5
	var dir := b - a
	var comp := dir.length()
	var cs := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(largura, 0.2, comp)
	cs.shape = forma
	var base := Basis.looking_at(dir.normalized(), Vector3.UP)
	cs.transform = Transform3D(base, meio - base.y * 0.1)
	_corpo.add_child(cs)


## Cunha MACIÇA de colisão sob uma rampa/escada (de "a" no chão até "b" no alto,
## ao longo de -Z): ninguém entra por baixo da escada nem fica "dentro" dos degraus.
func cunha_colisao(a: Vector3, b: Vector3, largura: float) -> void:
	var cs := CollisionShape3D.new()
	var forma := ConvexPolygonShape3D.new()
	var x := largura * 0.5
	forma.points = PackedVector3Array([
		Vector3(-x, a.y, a.z), Vector3(x, a.y, a.z),
		Vector3(-x, a.y, b.z), Vector3(x, a.y, b.z),
		Vector3(-x, b.y, b.z), Vector3(x, b.y, b.z)])
	cs.shape = forma
	_corpo.add_child(cs)


## Pseudoaleatório estável (mesmo resultado sempre, depende da posição da peça).
func aleatorio(i: int) -> float:
	var h := hash(Vector3i(roundi(position.x * 10), roundi(position.y * 10), roundi(position.z * 10)) + Vector3i(i, i * 7, i * 13))
	return float(h % 10000) / 10000.0
