extends RefCounted
class_name ControladorParkour
## Parkour do personagem (separado do Jogador para o código ficar organizado):
##   - correr na parede (wall run), pular da parede, de parede a parede
##   - correr parede acima e agarrar/subir beiradas
##   - transpor obstáculos baixos correndo (vault)
## Tudo usa colisão real do cenário (raios e teste de espaço livre): o personagem
## não atravessa nem "flutua" em paredes que não existem.
## Os números (velocidades, tempos, alcance) ficam no Jogador, no Inspetor.

var j: Jogador
## Verdadeiro durante a transposição de um obstáculo (vault).
var transpondo := false
var _pico := 0.0
var _vel_saida := Vector3.ZERO
var _duracao_transpor := 0.35


func _init(dono: Jogador) -> void:
	j = dono


# =========================================================================
#  PAREDE: grudar e correr pela parede / subir parede
# =========================================================================

## Procura parede ao lado (wall run) ou à frente (subir). Devolve true se grudou.
func tentar_parede(direcao: Vector3) -> bool:
	if j._recarga_parede > 0.0:
		return false
	var frente := j._frente_modelo()
	if direcao.length_squared() > 0.04:
		frente = direcao.normalized()
	var lado := frente.cross(Vector3.UP).normalized()  # direita

	# 1) De frente para a parede: corre parede acima.
	var hit_frente := raio_parede(frente, j.RAIO + 0.55)
	if hit_frente and frente.dot(-hit_frente.normal) > 0.75:
		j._normal_parede = hit_frente.normal
		j.velocity = Vector3(0, j.velocidade_subida_parede, 0)
		j._mudar_modo(Jogador.Modo.SUBINDO)
		return true

	# 2) Ao lado: corre pela parede.
	for s in [1.0, -1.0]:
		var hit := raio_parede(lado * s, j.RAIO + 0.8)  # generoso: no celular é difícil acertar a distância
		if hit:
			grudar_na_parede(hit.normal, frente)
			return true
	# 3) Parede na diagonal da frente (chegou meio torto).
	for s in [1.0, -1.0]:
		var diag: Vector3 = (frente + lado * s).normalized()
		var hit := raio_parede(diag, j.RAIO + 0.6)
		if hit:
			grudar_na_parede(hit.normal, frente)
			return true
	return false


func grudar_na_parede(normal: Vector3, frente: Vector3) -> void:
	j._normal_parede = normal
	# Direção ao longo da parede, para o lado em que o jogador já ia.
	var tangente := normal.cross(Vector3.UP).normalized()
	var referencia := Vector3(j.velocity.x, 0, j.velocity.z)
	if referencia.length_squared() < 1.0:
		referencia = frente
	if tangente.dot(referencia) < 0.0:
		tangente = -tangente
	j._direcao_parede = tangente
	var vel_h := maxf(referencia.length(), j.velocidade_parede)
	j.velocity = tangente * vel_h + Vector3.UP * j.impulso_inicial_parede
	j._pulo_duplo_disponivel = true
	j._mudar_modo(Jogador.Modo.PAREDE)


func modo_parede(direcao: Vector3, delta: float) -> void:
	# Pulo de parede: para longe da parede, mantendo o embalo.
	if j._buffer_pulo > 0.0:
		j._buffer_pulo = 0.0
		var saida := (j._normal_parede * j.pulo_parede_lateral + j._direcao_parede * j.velocidade_parede * 0.85)
		j.velocity = Vector3(saida.x, j.pulo_parede_vertical, saida.z)
		j._recarga_parede = 0.2
		j._controle_reduzido = 0.35
		j._pulando = true
		j._tempo_fora_do_chao = j.tempo_coyote + 1.0
		j._mudar_modo(Jogador.Modo.NORMAL)
		return

	# Escorrega devagar (j.gravidade reduzida) e corre ao longo da parede.
	j.velocity.y = max(j.velocity.y - j.gravidade * j.gravidade_parede * delta, -3.0)
	var vel_h := maxf(Vector2(j.velocity.x, j.velocity.z).length(), j.velocidade_parede)
	j.velocity.x = j._direcao_parede.x * vel_h - j._normal_parede.x * 1.5  # leve "puxão" para a parede
	j.velocity.z = j._direcao_parede.z * vel_h - j._normal_parede.z * 1.5
	j.move_and_slide()

	# Saída: acabou o tempo, a parede acabou, encostou no chão ou puxou para longe.
	var ainda_tem_parede := raio_parede(-j._normal_parede, j.RAIO + 0.7)
	var puxando_para_fora := direcao.dot(j._normal_parede) > 0.7
	if ainda_tem_parede:
		j._normal_parede = ainda_tem_parede.normal
	if j.is_on_floor() or not ainda_tem_parede or j._tempo_modo > j.duracao_parede or puxando_para_fora:
		j._recarga_parede = 0.25
		j.velocity += j._normal_parede * 1.0
		j._mudar_modo(Jogador.Modo.NORMAL)


func modo_subindo(direcao: Vector3, delta: float) -> void:
	j.velocity = -j._normal_parede * 1.0 + Vector3.UP * j.velocidade_subida_parede * (1.0 - j._tempo_modo / j.duracao_subida_parede * 0.4)
	j.move_and_slide()
	if tentar_beirada(-j._normal_parede):
		return
	# Pulo durante a subida: salto para trás (vira de costas para a parede).
	if j._buffer_pulo > 0.0 and j._tempo_modo > 0.08:
		j._buffer_pulo = 0.0
		j.velocity = j._normal_parede * j.pulo_parede_lateral + Vector3.UP * j.pulo_parede_vertical
		j._recarga_parede = 0.2
		j._controle_reduzido = 0.35
		j._mudar_modo(Jogador.Modo.NORMAL)
		return
	if j._tempo_modo > j.duracao_subida_parede or not raio_parede(-j._normal_parede, j.RAIO + 0.7):
		j.velocity = j._normal_parede * 1.5 + Vector3.UP * 1.0
		j._recarga_parede = 0.3
		j._mudar_modo(Jogador.Modo.NORMAL)


## Raio horizontal na altura do peito procurando parede "de pé".
func raio_parede(dir: Vector3, alcance: float) -> Dictionary:
	var origem := j.global_position + Vector3.UP * 1.0
	var q := PhysicsRayQueryParameters3D.create(origem, origem + dir * alcance, 1)
	q.exclude = [j.get_rid()]
	var hit := j.get_world_3d().direct_space_state.intersect_ray(q)
	if hit and abs(hit.normal.y) < 0.3:
		return hit
	return {}


# =========================================================================
#  ESCALAR BEIRADA
# =========================================================================

## Se houver uma beirada ao alcance à frente, começa a escalar. Devolve true se começou.
func tentar_beirada(direcao: Vector3) -> bool:
	var frente := Vector3(direcao.x, 0, direcao.z).normalized()
	var parede := raio_parede(frente, j.RAIO + 0.45)
	if not parede or frente.dot(-parede.normal) < 0.6:
		return false
	# Raio de cima para baixo, logo depois da borda da parede.
	var ponto: Vector3 = parede.position - parede.normal * 0.45
	var topo_busca := j.global_position.y + j.alcance_beirada + 0.1
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(ponto.x, topo_busca, ponto.z), Vector3(ponto.x, j.global_position.y + 0.4, ponto.z), 1)
	q.exclude = [j.get_rid()]
	var chao := j.get_world_3d().direct_space_state.intersect_ray(q)
	if not chao or chao.normal.y < 0.75:
		return false
	var destino: Vector3 = chao.position + Vector3.UP * 0.05
	if not j._espaco_livre(destino, j.ALTURA_EM_PE):
		return false
	j._escalada_inicio = j.global_position
	j._escalada_fim = destino
	j.velocity = Vector3.ZERO
	j._mudar_modo(Jogador.Modo.ESCALANDO)
	return true


# =========================================================================
#  TRANSPOR OBSTÁCULO (vault)
# =========================================================================

## No chão, correndo, com PULAR: se houver um obstáculo baixo (0,35 a 1,35 m) logo à
## frente, passa por cima num arco sem perder a velocidade. Obstáculo fino: cai do outro
## lado. Largo: sobe nele. Devolve true se começou.
func tentar_transpor(_direcao: Vector3) -> bool:
	var h := Vector3(j.velocity.x, 0, j.velocity.z)
	if h.length() < 3.0:
		return false
	var frente := h.normalized()
	var esp := j.get_world_3d().direct_space_state
	var pe := j.global_position
	var q := PhysicsRayQueryParameters3D.create(pe + Vector3.UP * 0.4, pe + Vector3.UP * 0.4 + frente * (j.RAIO + 1.0), 1)
	q.exclude = [j.get_rid()]
	var hit := esp.intersect_ray(q)
	if not hit or absf(hit.normal.y) > 0.3:
		return false
	# Topo do obstáculo
	var borda: Vector3 = hit.position - hit.normal * 0.15
	var q2 := PhysicsRayQueryParameters3D.create(Vector3(borda.x, pe.y + 1.7, borda.z), Vector3(borda.x, pe.y + 0.3, borda.z), 1)
	q2.exclude = [j.get_rid()]
	var topo := esp.intersect_ray(q2)
	if not topo or topo.normal.y < 0.75:
		return false
	var altura: float = topo.position.y - pe.y
	if altura < 0.35 or altura > 1.35:
		return false
	# Precisa de espaço por cima do obstáculo para o corpo passar
	if not j._espaco_livre(Vector3(borda.x, topo.position.y + 0.02, borda.z), 1.0):
		return false
	# Do outro lado tem chão mais baixo? (obstáculo fino: mureta, caixote)
	var destino := Vector3.INF
	for dist in [0.55, 0.85, 1.25]:
		var alem: Vector3 = hit.position + frente * (dist + j.RAIO)
		var q3 := PhysicsRayQueryParameters3D.create(Vector3(alem.x, topo.position.y + 0.3, alem.z), Vector3(alem.x, pe.y - 1.2, alem.z), 1)
		q3.exclude = [j.get_rid()]
		var chao := esp.intersect_ray(q3)
		if chao and chao.normal.y > 0.75 and chao.position.y < topo.position.y - 0.25 \
				and j._espaco_livre(chao.position + Vector3.UP * 0.05, j.ALTURA_EM_PE):
			destino = chao.position + Vector3.UP * 0.05
			break
	if destino == Vector3.INF:
		# Obstáculo largo: termina em cima dele...
		var em_cima := Vector3(borda.x, topo.position.y + 0.05, borda.z) + frente * 0.35
		if not j._espaco_livre(em_cima, j.ALTURA_EM_PE):
			return false
		# ...mas se logo depois vem uma parede mais alta (ex.: caixote encostado num
		# container), é melhor o pulo normal, que agarra a beirada de cima.
		var q4 := PhysicsRayQueryParameters3D.create(em_cima + Vector3.UP * 1.0, em_cima + Vector3.UP * 1.0 + frente * 1.2, 1)
		q4.exclude = [j.get_rid()]
		if not esp.intersect_ray(q4).is_empty():
			return false
		destino = em_cima
	j._escalada_inicio = pe
	j._escalada_fim = destino
	_pico = topo.position.y + 0.3
	var vel := maxf(h.length(), j.velocidade_corrida * 0.9)
	_vel_saida = frente * vel
	_duracao_transpor = clampf(pe.distance_to(destino) / vel, 0.25, 0.45)
	transpondo = true
	j._buffer_pulo = 0.0
	j.velocity = Vector3.ZERO
	j._mudar_modo(Jogador.Modo.ESCALANDO)
	return true


func _modo_transpondo() -> void:
	var t := clampf(j._tempo_modo / _duracao_transpor, 0.0, 1.0)
	var a := j._escalada_inicio
	var b := j._escalada_fim
	var p := a.lerp(b, t)
	# Arco que passa acima do topo do obstáculo
	var base_y := lerpf(a.y, b.y, t)
	var folga := maxf(_pico - maxf(a.y, b.y), 0.0) + 0.15
	p.y = base_y + 4.0 * t * (1.0 - t) * folga
	j.global_position = p
	if t >= 1.0:
		transpondo = false
		j.velocity = _vel_saida  # sai correndo, sem perder o embalo
		j._pulo_duplo_disponivel = true
		j._mudar_modo(Jogador.Modo.NORMAL)


func modo_escalando(_delta: float) -> void:
	if transpondo:
		_modo_transpondo()
		return
	# Movimento guiado em "L": primeiro sobe, depois avança por cima da borda.
	var t := clampf(j._tempo_modo / j.duracao_escalada, 0.0, 1.0)
	var sobe := ease(clampf(t / 0.6, 0.0, 1.0), 0.6)
	var avanca := ease(clampf((t - 0.35) / 0.65, 0.0, 1.0), 1.6)
	var p := j._escalada_inicio
	p.y = lerpf(j._escalada_inicio.y, j._escalada_fim.y, sobe)
	p.x = lerpf(j._escalada_inicio.x, j._escalada_fim.x, avanca)
	p.z = lerpf(j._escalada_inicio.z, j._escalada_fim.z, avanca)
	j.global_position = p
	if t >= 1.0:
		# Sai já andando para a frente (não perde o ritmo).
		var frente := (j._escalada_fim - j._escalada_inicio)
		frente.y = 0
		j.velocity = frente.normalized() * j.velocidade_corrida * 0.7
		j._pulo_duplo_disponivel = true
		j._mudar_modo(Jogador.Modo.NORMAL)


