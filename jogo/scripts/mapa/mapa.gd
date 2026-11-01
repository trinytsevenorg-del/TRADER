extends Node3D
class_name Mapa
## Raiz de um mapa jogável.
##  - Ao carregar, mescla as malhas estáticas (poucos draw calls).
##  - Pontos de renascimento: Marker3D no grupo "renascimento" (a seta azul -Z
##    do marcador indica para onde o jogador olha ao nascer).
##  - Limites: paredes invisíveis nas bordas e "chão da morte" (caiu = renasce).

@export var metade_tamanho := 30.5     ## o mapa vai de -x a +x (e -z a +z)
@export var altura_limite := 40.0
@export var chao_da_morte := -8.0
@export var mesclar_malhas := true

signal pronto

var info_mesclagem := {}
var regiao_navegacao: NavigationRegion3D
var esta_pronto := false


func _ready() -> void:
	add_to_group("mapa")
	if mesclar_malhas and has_node("Pecas"):
		# Espera um quadro: as peças geram a geometria no _ready delas.
		await get_tree().process_frame
		info_mesclagem = Mesclador.mesclar($Pecas)
		print("Mapa: %d malhas -> %d após mesclagem" % [info_mesclagem.antes, info_mesclagem.depois])
	_criar_limites()
	preparar_navegacao()
	esta_pronto = true
	pronto.emit()
	var j := get_node_or_null("Jogador") as Jogador
	if j:
		var p := escolher_renascimento([])
		if p:
			j.teleportar(p.global_position + Vector3.UP * 0.1, p.global_rotation.y)


## Configuração da malha de navegação (bots).
static func nova_malha_navegacao(metade: float) -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_height = 1.75
	nm.agent_radius = 0.5  # múltiplo do cell_size (0,25)
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 45.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	# Só a área jogável (fora dela há a cidade de fundo).
	nm.filter_baking_aabb = AABB(Vector3(-metade, -1, -metade), Vector3(metade * 2, 20, metade * 2))
	return nm


## Gera a malha de navegação a partir das colisões das peças (sincrono).
func assar_navegacao() -> NavigationMesh:
	var nm := nova_malha_navegacao(metade_tamanho - 0.3)
	var fonte := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, fonte, $Pecas)
	NavigationServer3D.bake_from_source_geometry_data(nm, fonte)
	return nm


func preparar_navegacao() -> void:
	# Gerada ao carregar a partir das colisões (rápido: ~40 ms no PC).
	var t0 := Time.get_ticks_msec()
	var nm := assar_navegacao()
	print("Mapa: navegação gerada em %d ms (%d polígonos)" % [Time.get_ticks_msec() - t0, nm.get_polygon_count()])
	regiao_navegacao = NavigationRegion3D.new()
	regiao_navegacao.name = "Navegacao"
	regiao_navegacao.navigation_mesh = nm
	add_child(regiao_navegacao)


func mapa_navegacao() -> RID:
	return get_world_3d().navigation_map


func _criar_limites() -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "Limites"
	corpo.collision_layer = 1
	add_child(corpo)
	var s := metade_tamanho
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var cs := CollisionShape3D.new()
		var forma := BoxShape3D.new()
		forma.size = Vector3(1, altura_limite, s * 2 + 2) if d.x != 0 else Vector3(s * 2 + 2, altura_limite, 1)
		cs.shape = forma
		cs.position = d * (s + 0.5) + Vector3.UP * altura_limite * 0.5
		corpo.add_child(cs)


func _physics_process(_delta: float) -> void:
	# Chão da morte: quem cair do mapa renasce.
	for p in get_tree().get_nodes_in_group("personagens"):
		if p.global_position.y < chao_da_morte and p.has_method("teleportar"):
			var r := escolher_renascimento([])
			p.teleportar(r.global_position + Vector3.UP * 0.1, r.global_rotation.y)


## Escolhe o ponto de renascimento mais longe dos inimigos (posições dadas).
## Sem inimigos: aleatório. (Os bots e o modo mata-mata usam isto na etapa 5.)
func escolher_renascimento(posicoes_inimigos: Array) -> Node3D:
	var pontos := get_tree().get_nodes_in_group("renascimento")
	if pontos.is_empty():
		return null
	if posicoes_inimigos.is_empty():
		return pontos[randi() % pontos.size()]
	var melhor: Node3D = null
	var melhor_d := -1.0
	for p in pontos:
		var menor := INF
		for pos in posicoes_inimigos:
			menor = min(menor, p.global_position.distance_to(pos))
		# um pouco de aleatoriedade para não nascer sempre no mesmo lugar
		menor *= randf_range(0.85, 1.0)
		if menor > melhor_d:
			melhor_d = menor
			melhor = p
	return melhor
