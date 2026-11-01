class_name Construtor
## Funções utilitárias para gerar geometria low-poly por código
## (blocos com colisão, materiais leves). Usado enquanto não há modelos .glb.

static var _cache_materiais := {}


## Material com textura xadrez "projetada" (triplanar): dá noção de velocidade
## e escala sem precisar de UV. Materiais são reaproveitados (cache) para
## manter poucos draw calls / trocas de estado na GPU.
static func material_xadrez(cor_a: Color, cor_b: Color, escala_metros: float = 2.0) -> StandardMaterial3D:
	var chave := "%s|%s|%s" % [cor_a.to_html(), cor_b.to_html(), escala_metros]
	if _cache_materiais.has(chave):
		return _cache_materiais[chave]
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var xadrez := ((x / 32) + (y / 32)) % 2 == 0
			var cor := cor_a if xadrez else cor_b
			if x % 32 == 0 or y % 32 == 0:
				cor = cor.darkened(0.25)  # linhas finas, como rejunte
			img.set_pixel(x, y, cor)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / escala_metros
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache_materiais[chave] = m
	return m


static func material_liso(cor: Color) -> StandardMaterial3D:
	var chave := "liso|" + cor.to_html()
	if _cache_materiais.has(chave):
		return _cache_materiais[chave]
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 0.85
	_cache_materiais[chave] = m
	return m


## Cria um bloco sólido (StaticBody3D + colisão + malha) na camada "mundo".
## com_colisao = false cria só o visual (ex.: degraus, cuja colisão é uma rampa
## invisível — assim o personagem sobe escadas lisinho, sem "engasgar").
static func bloco(pai: Node, posicao: Vector3, tamanho: Vector3, material: Material,
		rotacao_graus: Vector3 = Vector3.ZERO, com_colisao: bool = true) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	corpo.position = posicao
	corpo.rotation_degrees = rotacao_graus
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	forma.shape = caixa
	if com_colisao:
		corpo.add_child(forma)
	var mi := MeshInstance3D.new()
	var malha := BoxMesh.new()
	malha.size = tamanho
	mi.mesh = malha
	mi.material_override = material
	corpo.add_child(mi)
	pai.add_child(corpo)
	return corpo


## Rampa: um bloco inclinado que começa no chão em "inicio" e sobe "altura"
## ao longo de "comprimento" na direção do eixo Z negativo (gira com yaw_graus).
static func rampa(pai: Node, inicio: Vector3, largura: float, comprimento: float, altura: float,
		material: Material, yaw_graus: float = 0.0) -> StaticBody3D:
	var angulo := atan2(altura, comprimento)
	var hipotenusa := sqrt(comprimento * comprimento + altura * altura)
	var espessura := 0.3
	var dir := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(yaw_graus))
	# Centro da placa, rebaixado meia espessura para a superfície encostar no chão.
	var centro := inicio + dir * (comprimento * 0.5) + Vector3.UP * (altura * 0.5)
	var normal := Vector3.UP.rotated(dir.cross(Vector3.UP).normalized(), angulo)
	centro -= normal * (espessura * 0.5)
	return bloco(pai, centro, Vector3(largura, espessura, hipotenusa), material,
		Vector3(rad_to_deg(angulo), yaw_graus, 0))
