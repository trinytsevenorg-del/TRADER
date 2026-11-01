class_name Mesclador
## Junta (mescla) as malhas estáticas do mapa para ter POUCOS draw calls.
##
## Centenas de pecinhas (paredes, janelas, faixas, caixas...) viram poucas malhas
## grandes: uma por (material x região do mapa). As regiões ("blocos" de 24 m)
## mantêm o "frustum culling": o que está fora da tela não é desenhado.
## Objetos marcados como "detalhe" vão para malhas separadas que somem de longe.
## A cor de cada peça vai para a cor dos vértices: agrupa-se só por textura.
##
## Na mesclagem também:
##  - calcula o UV projetado no mundo (a textura repete por metros, sem triplanar);
##  - pinta a cor dos vértices com uma sombra de contato no pé das paredes (AO falso).
## As colisões NÃO são mexidas (continuam nas peças).

const DISTANCIA_DETALHE := 40.0


static func mesclar(raiz: Node, tamanho_bloco := 32.0) -> Dictionary:
	var grupos := {}   # chave -> {mat, detalhe, st: SurfaceTool}
	var removidos := 0
	for mi in raiz.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree() or mi.mesh == null or mi.has_meta("nao_mesclar"):
			continue
		if mi.get_parent() and mi.get_parent().has_meta("nao_mesclar"):
			continue
		var xf: Transform3D = mi.global_transform
		var detalhe: bool = mi.has_meta("detalhe")
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.material_override if mi.material_override else mi.get_active_material(s)
			# Materiais do mapa: agrupa só pela TEXTURA; a cor vai para a cor do vértice.
			# Assim paredes de 10 cores diferentes viram um único draw call.
			var cor := Color.WHITE
			if mat is StandardMaterial3D and mat.has_meta("tipo"):
				cor = (mat as StandardMaterial3D).albedo_color
				mat = MateriaisMapa.obter(mat.get_meta("tipo"), Color.WHITE)
			var centro: Vector3 = xf * mi.mesh.get_aabb().get_center()
			var bloco := Vector2i(floori(centro.x / tamanho_bloco), floori(centro.z / tamanho_bloco))
			var chave := "%d|%s|%s" % [mat.get_instance_id() if mat else 0, bloco, detalhe]
			if not grupos.has(chave):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				grupos[chave] = {"mat": mat, "detalhe": detalhe, "st": st}
			_adicionar(grupos[chave].st, mi.mesh, s, xf, MateriaisMapa.escala_de(mat), cor)
		mi.queue_free()
		removidos += 1

	var novas := 0
	var destino := Node3D.new()
	destino.name = "MalhasMescladas"
	raiz.add_child(destino)
	for chave in grupos:
		var g: Dictionary = grupos[chave]
		var st: SurfaceTool = g.st
		st.index()
		var malha := st.commit()
		var novo := MeshInstance3D.new()
		novo.mesh = malha
		novo.material_override = MateriaisMapa.versao_jogo(g.mat)
		if g.detalhe:
			novo.visibility_range_end = DISTANCIA_DETALHE
			novo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		destino.add_child(novo)
		novas += 1
	return {"antes": removidos, "depois": novas}


static func _adicionar(st: SurfaceTool, malha: Mesh, superficie: int, xf: Transform3D, escala_uv: float, cor: Color) -> void:
	var arr := malha.surface_get_arrays(superficie)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var normais: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var indices = arr[Mesh.ARRAY_INDEX]
	var base := xf.basis
	var normal_xf := base.inverse().transposed()
	var lista: PackedInt32Array
	if indices == null or (indices as PackedInt32Array).is_empty():
		lista = PackedInt32Array(range(verts.size()))
	else:
		lista = indices
	for k in lista.size():
		var i := lista[k]
		var p := xf * verts[i]
		var n := (normal_xf * normais[i]).normalized()
		# UV projetado na face dominante (metros / escala da textura)
		var uv: Vector2
		var an := n.abs()
		if an.y >= an.x and an.y >= an.z:
			uv = Vector2(p.x, p.z)
		elif an.x >= an.z:
			uv = Vector2(p.z, -p.y)
		else:
			uv = Vector2(p.x, -p.y)
		uv /= escala_uv
		# Sombra de contato: paredes ficam mais escuras perto do chão (y ~ 0)
		var ao := 1.0
		if an.y < 0.5:
			ao = lerpf(0.6, 1.0, clampf(p.y / 1.4, 0.0, 1.0))
		st.set_color(Color(cor.r * ao, cor.g * ao, cor.b * ao))
		st.set_normal(n)
		st.set_uv(uv)
		st.add_vertex(p)
	# Primitivas da Godot vêm em sentido horário; SurfaceTool mantém a ordem dada.
