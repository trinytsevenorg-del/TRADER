extends Node
class_name CerebroBot
## IA de um bot. Fica como filho de um Jogador do tipo BOT e só dá COMANDOS
## (direção, mira, pular, rolar, deslizar, gatilho): o movimento e as armas são
## exatamente os mesmos do jogador humano.
##
## Estados:
##   PATRULHA   anda entre pontos aleatórios do mapa (pela malha de navegação)
##   COMBATE    inimigo à vista: mira, atira, anda de lado, pula/rola/desliza
##   COBERTURA  com pouca vida: vai para um ponto fora da visão do inimigo e recupera
##   BUSCA      perdeu o inimigo de vista: vai até onde o viu por último
##
## Três dificuldades (FACIL, MEDIO, DIFICIL) mudam reação, erro de mira,
## velocidade de giro, alcance de visão e o quanto usam parkour e cobertura.

enum Estado { PATRULHA, COMBATE, COBERTURA, BUSCA }
enum Dificuldade { FACIL, MEDIO, DIFICIL }

const PERFIS := {
	# reacao (s), erro de mira (graus), giro (graus/s), visao (m), fov (graus),
	# lado (andar de lado 0-1), parkour (chance 0-1), cobertura (vida para fugir),
	# tolerancia (graus para começar a atirar), pausa (fração do tempo sem atirar)
	Dificuldade.FACIL: {"reacao": 0.9, "erro": 7.0, "giro": 160.0, "visao": 32.0, "fov": 100.0,
		"lado": 0.35, "parkour": 0.05, "cobertura": 0.0, "tolerancia": 7.0, "pausa": 0.5},
	Dificuldade.MEDIO: {"reacao": 0.55, "erro": 4.2, "giro": 300.0, "visao": 45.0, "fov": 120.0,
		"lado": 0.7, "parkour": 0.25, "cobertura": 40.0, "tolerancia": 5.0, "pausa": 0.35},
	Dificuldade.DIFICIL: {"reacao": 0.32, "erro": 2.6, "giro": 520.0, "visao": 60.0, "fov": 150.0,
		"lado": 1.0, "parkour": 0.55, "cobertura": 55.0, "tolerancia": 4.0, "pausa": 0.2},
}

var dificuldade: Dificuldade = Dificuldade.MEDIO
var estado: Estado = Estado.PATRULHA
var alvo: Node3D = null

var _dono: Jogador
var _perfil: Dictionary
var _caminho := PackedVector3Array()
var _i_caminho := 0
var _destino := Vector3.ZERO
var _tempo_repath := 0.0
var _tempo_percepcao := 0.0
var _tempo_vendo := 0.0          # há quanto tempo vê o alvo (reação)
var _ultima_pos_alvo := Vector3.ZERO
var _tempo_sem_ver := 0.0
var _lado := 1.0
var _tempo_lado := 0.0
var _erro := Vector2.ZERO        # erro de mira atual (graus), vai "flutuando"
var _tempo_erro := 0.0
var _tempo_preso := 0.0
var _pos_anterior := Vector3.ZERO
var _tempo_estado := 0.0
var _tempo_gatilho := 0.0
var _tempo_luneta := 0.0
var _tempo_disciplina := 0.0
var _pausando := false


func _ready() -> void:
	_dono = get_parent() as Jogador
	_perfil = PERFIS[dificuldade]
	if not _dono.is_node_ready():
		await _dono.ready
	_tempo_percepcao = randf() * 0.15  # espalha o trabalho entre os bots
	_dono.saude.dano_recebido.connect(_ao_tomar_dano)
	_dono.renasceu.connect(func(): _mudar(Estado.PATRULHA); alvo = null)


func _mudar(novo: Estado) -> void:
	estado = novo
	_tempo_estado = 0.0
	_caminho = PackedVector3Array()


func _physics_process(delta: float) -> void:
	if _dono == null or not _dono.is_node_ready():
		return
	# A malha de navegação precisa sincronizar antes do primeiro uso.
	if NavigationServer3D.map_get_iteration_id(_mapa_nav()) == 0:
		return
	if _dono.esta_morto():
		_dono.comando_direcao = Vector3.ZERO
		_dono.armas.gatilho = false
		return
	_tempo_estado += delta
	_tempo_repath -= delta

	_tempo_percepcao -= delta
	if _tempo_percepcao <= 0.0:
		_tempo_percepcao = 0.15
		_perceber()

	match estado:
		Estado.PATRULHA:
			_patrulhar(delta)
		Estado.COMBATE:
			_combater(delta)
		Estado.COBERTURA:
			_cobrir(delta)
		Estado.BUSCA:
			_buscar(delta)

	_verificar_preso(delta)


# =========================================================================
#  PERCEPÇÃO
# =========================================================================

func _inimigos() -> Array:
	var r := []
	for p in get_tree().get_nodes_in_group("participantes"):
		if p != _dono and not p.esta_morto():
			r.append(p)
	return r


func _consegue_ver(o: Node3D) -> bool:
	var olhos := _dono.global_position + Vector3.UP * 1.55
	var peito := o.global_position + Vector3.UP * 1.2
	var dist := olhos.distance_to(peito)
	if dist > _perfil.visao:
		return false
	var frente := Vector3(0, 0, -1).rotated(Vector3.UP, _dono.yaw_mira)
	var para := (peito - olhos)
	para.y = 0
	# Fora do campo de visão só percebe muito de perto
	if dist > 8.0 and rad_to_deg(frente.angle_to(para.normalized())) > _perfil.fov * 0.5:
		return false
	var q := PhysicsRayQueryParameters3D.create(olhos, peito, 1)  # só o cenário bloqueia
	return _dono.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _perceber() -> void:
	var melhor: Node3D = null
	var melhor_d := INF
	for o in _inimigos():
		if _consegue_ver(o):
			var d := _dono.global_position.distance_to(o.global_position)
			if d < melhor_d:
				melhor_d = d
				melhor = o
		# Ouve tiros por perto
		elif o.armas.tempo_desde_tiro < 0.3 and _dono.global_position.distance_to(o.global_position) < 28.0 \
				and estado == Estado.PATRULHA:
			_ultima_pos_alvo = o.global_position
			_mudar(Estado.BUSCA)
	if melhor:
		if melhor != alvo:
			_tempo_vendo = 0.0
		alvo = melhor
		_ultima_pos_alvo = alvo.global_position
		_tempo_sem_ver = 0.0
		if estado != Estado.COBERTURA:
			if estado != Estado.COMBATE:
				_mudar(Estado.COMBATE)
	elif alvo:
		_tempo_sem_ver += 0.15
		_tempo_vendo = 0.0
		if estado == Estado.COMBATE and _tempo_sem_ver > 0.6:
			_mudar(Estado.BUSCA)


func _ao_tomar_dano(_qtd: float, atacante: Node, _ponto: Vector3, _cabeca: bool) -> void:
	if atacante is Node3D and atacante != _dono:
		_ultima_pos_alvo = atacante.global_position
		# Vira na direção de quem atirou
		var para: Vector3 = atacante.global_position - _dono.global_position
		_dono.yaw_mira = lerp_angle(_dono.yaw_mira, atan2(-para.x, -para.z), 0.6)
		if estado == Estado.PATRULHA:
			_mudar(Estado.BUSCA)
		# Bots melhores reagem rolando
		if randf() < _perfil.parkour * 0.6:
			_dono.pedir_rolar()
	if _perfil.cobertura > 0.0 and _dono.saude.vida < _perfil.cobertura and estado != Estado.COBERTURA:
		_iniciar_cobertura()


# =========================================================================
#  ESTADOS
# =========================================================================

func _patrulhar(delta: float) -> void:
	_dono.armas.gatilho = false
	if _caminho.is_empty() or _i_caminho >= _caminho.size():
		_ir_para(_ponto_aleatorio())
	_seguir_caminho(delta, 0.75)
	_olhar_para_onde_anda(delta)
	# Recarrega com calma
	var s := _dono.armas.slot()
	if s and s.pente < s.dados.pente * 0.5:
		_dono.armas.pedir_recarga = true


func _combater(delta: float) -> void:
	if alvo == null or alvo.esta_morto():
		alvo = null
		_mudar(Estado.PATRULHA)
		return
	var d := _dono.armas.arma()
	var dist := _dono.global_position.distance_to(alvo.global_position)
	_tempo_vendo += delta

	# --- Mira com erro e reação ---
	_tempo_erro -= delta
	if _tempo_erro <= 0.0:
		_tempo_erro = randf_range(0.25, 0.6)
		var e: float = _perfil.erro * (1.0 + clamp(dist / 40.0, 0.0, 1.0))
		_erro = Vector2(randf_range(-e, e), randf_range(-e, e) * 0.6)
	var ponto := alvo.global_position + Vector3.UP * (1.25 if randf() > 0.15 else 1.55)
	var olhos := _dono.global_position + Vector3.UP * 1.55
	var para := ponto - olhos
	var yaw_alvo := atan2(-para.x, -para.z) + deg_to_rad(_erro.x)
	var pitch_alvo := atan2(para.y, Vector2(para.x, para.z).length()) + deg_to_rad(_erro.y)
	var passo := deg_to_rad(_perfil.giro) * delta
	var dif_yaw := wrapf(yaw_alvo - _dono.yaw_mira, -PI, PI)
	_dono.yaw_mira += clamp(dif_yaw, -passo, passo)
	_dono.pitch_mira += clamp(pitch_alvo - _dono.pitch_mira, -passo, passo)
	var mirado: bool = abs(rad_to_deg(wrapf(yaw_alvo - _dono.yaw_mira, -PI, PI))) < _perfil.tolerancia + 2.0

	# --- Atirar (com pausas: bots não ficam com o dedo colado no gatilho) ---
	_tempo_disciplina -= delta
	if _tempo_disciplina <= 0.0:
		_tempo_disciplina = randf_range(0.4, 1.0)
		_pausando = randf() < float(_perfil.pausa)
	var pode_atirar: bool = _tempo_vendo > _perfil.reacao and mirado and d and dist < d.alcance_maximo and not _pausando
	_controlar_gatilho(d, pode_atirar, delta)

	# --- Movimento: distância ideal + andar de lado ---
	var ideal := 14.0
	if d:
		match d.categoria:
			DadosArma.Categoria.ESCOPETA: ideal = 4.0
			DadosArma.Categoria.SUBMETRALHADORA, DadosArma.Categoria.PISTOLA: ideal = 9.0
			DadosArma.Categoria.SNIPER: ideal = 30.0
	var para_alvo := alvo.global_position - _dono.global_position
	para_alvo.y = 0
	var frente := para_alvo.normalized()
	var lado_v := frente.cross(Vector3.UP)
	_tempo_lado -= delta
	if _tempo_lado <= 0.0:
		_tempo_lado = randf_range(0.5, 1.4)
		_lado = [-1.0, 1.0][randi() % 2]
		# Parkour de combate (bots mais difíceis)
		if randf() < _perfil.parkour:
			match randi() % 3:
				0: _dono.pedir_pulo()
				1: _dono.pedir_rolar()
				2: _dono.pedir_deslizar()
	var mov := lado_v * _lado * float(_perfil.lado)
	if dist > ideal * 1.3:
		# Longe: aproxima pela malha de navegação
		if _tempo_repath <= 0.0:
			_ir_para(alvo.global_position)
		var dir_caminho := _direcao_caminho()
		mov = (dir_caminho + mov * 0.4)
	elif dist < ideal * 0.6:
		mov += -frente * 0.8
	_dono.comando_direcao = mov.limit_length(1.0)

	# Recarga: se acabou e o inimigo está longe, ou pouca bala
	var s := _dono.armas.slot()
	if s and s.pente == 0 and _perfil.cobertura > 0.0 and dist > 8.0:
		_iniciar_cobertura()


func _iniciar_cobertura() -> void:
	var p := _ponto_de_cobertura()
	if p == Vector3.INF:
		return
	_mudar(Estado.COBERTURA)
	_ir_para(p)


func _cobrir(delta: float) -> void:
	_dono.armas.gatilho = false
	var chegou := _seguir_caminho(delta, 1.0)
	_olhar_para_onde_anda(delta)
	var s := _dono.armas.slot()
	if s and s.pente < s.dados.pente:
		_dono.armas.pedir_recarga = true
	# Sai da cobertura com vida recuperada, ou depois de um tempo
	var recuperado := _dono.saude.vida > 80.0
	if (chegou and recuperado) or _tempo_estado > 7.0:
		_mudar(Estado.BUSCA if alvo else Estado.PATRULHA)


func _buscar(delta: float) -> void:
	_dono.armas.gatilho = false
	if _caminho.is_empty():
		_ir_para(_ultima_pos_alvo)
	var chegou := _seguir_caminho(delta, 1.0)
	_olhar_para_onde_anda(delta)
	if chegou or _tempo_estado > 8.0:
		alvo = null
		_mudar(Estado.PATRULHA)


# =========================================================================
#  ARMAS
# =========================================================================

func _controlar_gatilho(d: DadosArma, pode: bool, delta: float) -> void:
	var a := _dono.armas
	if d == null:
		return
	if d.atira_ao_soltar:
		# Sniper: segura (abre a luneta), assenta e solta para atirar
		if pode:
			a.gatilho = true
			_tempo_luneta += delta
			if _tempo_luneta > 0.45:
				a.gatilho = false
				_tempo_luneta = -0.3
		else:
			a.gatilho = false
			_tempo_luneta = 0.0
		return
	if not pode:
		a.gatilho = false
		return
	match d.modo:
		DadosArma.Modo.AUTO:
			a.gatilho = true
		_:
			# Semi e rajada: "toques" no gatilho no ritmo da arma
			_tempo_gatilho -= delta
			if _tempo_gatilho <= 0.0:
				a.gatilho = not a.gatilho
				_tempo_gatilho = 0.05 if a.gatilho else maxf(d.intervalo(), d.pausa_rajada if d.modo == DadosArma.Modo.RAJADA else 0.0) + randf_range(0.02, 0.15)


# =========================================================================
#  NAVEGAÇÃO
# =========================================================================

func _mapa_nav() -> RID:
	return _dono.get_world_3d().navigation_map


func _ir_para(destino: Vector3) -> void:
	_destino = destino
	_tempo_repath = 0.6
	var mapa := _mapa_nav()
	var de := NavigationServer3D.map_get_closest_point(mapa, _dono.global_position)
	var ate := NavigationServer3D.map_get_closest_point(mapa, destino)
	_caminho = NavigationServer3D.map_get_path(mapa, de, ate, true)
	_i_caminho = 1 if _caminho.size() > 1 else 0


func _direcao_caminho() -> Vector3:
	while _i_caminho < _caminho.size():
		var p := _caminho[_i_caminho]
		var d := p - _dono.global_position
		var plano := Vector2(d.x, d.z)
		if plano.length() < 0.6 and abs(d.y) < 1.6:
			_i_caminho += 1
			continue
		return Vector3(d.x, 0, d.z).normalized()
	return Vector3.ZERO


## Anda pelo caminho. Devolve true quando chega ao fim.
func _seguir_caminho(_delta: float, velocidade: float) -> bool:
	var dir := _direcao_caminho()
	_dono.comando_direcao = dir * velocidade
	# De vez em quando, um pouco de parkour no caminho (estilo do jogo)
	if dir != Vector3.ZERO and randf() < _perfil.parkour * 0.01:
		_dono.pedir_pulo()
	return dir == Vector3.ZERO


func _olhar_para_onde_anda(delta: float) -> void:
	var dir := _dono.comando_direcao
	if dir.length_squared() < 0.01:
		return
	var yaw_alvo := atan2(-dir.x, -dir.z)
	_dono.yaw_mira = lerp_angle(_dono.yaw_mira, yaw_alvo, 1.0 - exp(-6.0 * delta))
	_dono.pitch_mira = lerpf(_dono.pitch_mira, 0.0, 1.0 - exp(-4.0 * delta))


func _ponto_aleatorio() -> Vector3:
	var mapa := _mapa_nav()
	for i in 6:
		var p := NavigationServer3D.map_get_random_point(mapa, 1, true)
		if p.distance_to(_dono.global_position) > 8.0:
			return p
	return NavigationServer3D.map_get_random_point(mapa, 1, true)


## Procura um ponto perto, alcançável, onde o inimigo NÃO enxerga.
func _ponto_de_cobertura() -> Vector3:
	var de_onde := _ultima_pos_alvo + Vector3.UP * 1.5
	var mapa := _mapa_nav()
	var espaco := _dono.get_world_3d().direct_space_state
	var melhor := Vector3.INF
	var melhor_d := INF
	for i in 12:
		var ang := TAU * i / 12.0
		var raio := randf_range(4.0, 10.0)
		var p := NavigationServer3D.map_get_closest_point(mapa, _dono.global_position + Vector3(sin(ang), 0, cos(ang)) * raio)
		var q := PhysicsRayQueryParameters3D.create(de_onde, p + Vector3.UP * 1.0, 1)
		if espaco.intersect_ray(q).is_empty():
			continue  # o inimigo vê esse ponto
		var d := p.distance_to(_dono.global_position)
		if d < melhor_d:
			melhor_d = d
			melhor = p
	return melhor


func _verificar_preso(delta: float) -> void:
	var quer_andar := _dono.comando_direcao.length_squared() > 0.25
	var andou := _dono.global_position.distance_to(_pos_anterior)
	_pos_anterior = _dono.global_position
	if quer_andar and andou < 0.6 * delta:
		_tempo_preso += delta
		if _tempo_preso > 0.6 and _tempo_preso - delta <= 0.6:
			_dono.pedir_pulo()  # pula obstáculo baixo (e agarra beiradas)
		if _tempo_preso > 1.6:
			_tempo_preso = 0.0
			_ir_para(_ponto_aleatorio())
	else:
		_tempo_preso = 0.0
