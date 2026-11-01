extends Node
## Pente fino de colisão no MAPA REAL (Vila Telhado), roda sem tela:
##   godot --headless --path . res://tests/teste_auto_colisao.tscn
##
## 4 bots difíceis jogam a partida e o jogador anda sozinho pelo mapa fazendo de
## tudo (correr, pular, parede, rolar, deslizar, escalar). A cada quadro, para cada
## personagem, verifica:
##   1. a cápsula de colisão não está dentro do cenário (parede, chão, caixa);
##   2. nenhuma junta do esqueleto (cabeça, mãos, cotovelos, quadril, joelhos, pés)
##      está DENTRO do cenário — as juntas ficam no meio da carne, então uma junta
##      dentro de uma parede/chão é atravessamento de verdade, não só encostar;
##   3. ninguém cai para fora do mapa;
##   4. fluidez: o corpo visual não dá trancos (> 8 cm num quadro), não gira mais de
##      30° num quadro e o estado (correndo, caindo...) não fica "piscando".

const OSSOS := ["Head", "neck_01", "spine_03", "pelvis", "hand_l", "hand_r", "lowerarm_l",
	"lowerarm_r", "calf_l", "calf_r", "foot_l", "foot_r", "ball_l", "ball_r"]
const SEGUNDOS := 60.0

var _falhas := 0
var _partida: Partida
var _ocorrencias := {}      # "tipo|estado|o que" -> quadros
var _quadros := 0
var _anexos := {}           # personagem -> {osso: BoneAttachment3D}
var _seguidos := {}         # "personagem|osso" -> quadros seguidos dentro do cenário
var _max_seguidos := 0
var _max_cap := 0
var _longos := 0            # contatos de mais de 0,5 s
var _max_seguidos_ex := ""
# Fluidez (por personagem): último deslocamento visual, último yaw, histórico de estado
var _ult := {}
var _trancos := 0           # corpo visual pulou > 4 cm num quadro (fora do movimento)
var _maior_tranco := 0.0
var _trancos_por := {}
var _giros := 0             # corpo virou > 30° num quadro
var _piscadas := 0          # estado voltou ao anterior em menos de 0,1 s
var _piscadas_ex := {}
var _pior := {}             # "tipo|estado|o que" -> [profundidade aproximada, posição]


func _checar(nome: String, ok: bool) -> void:
	print(("OK    " if ok else "FALHA ") + nome)
	if not ok: _falhas += 1


func _ready() -> void:
	Engine.physics_ticks_per_second = 60
	# Mede no fim de cada quadro (depois de animação, IK, ajuste ao chão): é o que
	# aparece na tela.
	process_priority = 10000
	_rodar()


var _medir := false


func _process(_delta: float) -> void:
	if not _medir or _partida == null:
		return
	_quadros += 1
	var esp := _partida.get_world_3d().direct_space_state
	for p in _partida.modo.participantes:
		if is_instance_valid(p.no):
			_verificar(p.no, esp)


func _registrar(chave: String, pos: Vector3) -> void:
	_ocorrencias[chave] = _ocorrencias.get(chave, 0) + 1
	if not _pior.has(chave):
		_pior[chave] = pos


func _dentro_do_cenario(esp: PhysicsDirectSpaceState3D, p: Vector3, excluir: Array[RID]) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collision_mask = 1
	q.exclude = excluir
	return not esp.intersect_point(q, 1).is_empty()


func _verificar(j: Jogador, esp: PhysicsDirectSpaceState3D) -> void:
	if j.esta_morto() and j.estado == &"morto" and not j.is_on_floor():
		pass
	var tipo := "jogador" if j.controlado_localmente else "bot"
	var est := String(j.estado)
	var excluir: Array[RID] = [j.get_rid()]
	# 1) Cápsula (um pouco menor que a real: encostar não conta)
	var col := j.get_node("Colisao") as CollisionShape3D
	var cap := col.shape as CapsuleShape3D
	var forma := CapsuleShape3D.new()
	forma.radius = cap.radius - 0.04
	forma.height = maxf(cap.height - 0.1, forma.radius * 2.0)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = col.global_transform
	q.collision_mask = 1
	q.exclude = excluir
	var dentro := esp.intersect_shape(q, 1)
	var chave_cap := "%d|cápsula" % j.get_instance_id()
	if not dentro.is_empty():
		_registrar("%s|%s|cápsula (em %s, vy %.1f, chão %s)" % [tipo, est, String(dentro[0].collider.name), j.velocity.y, j.is_on_floor()], j.global_position)
		_seguidos[chave_cap] = _seguidos.get(chave_cap, 0) + 1
		_max_cap = maxi(_max_cap, _seguidos[chave_cap])
	else:
		_seguidos[chave_cap] = 0
	# 2) Juntas do esqueleto
	# (BoneAttachment3D: posição FINAL da junta, depois do IK e do ajuste ao chão)
	if not _anexos.has(j):
		_anexos[j] = {}
		var esq: Skeleton3D = j.modelo.get("_esqueleto") if j.modelo else null
		if esq:
			for nome in OSSOS:
				if esq.find_bone(nome) >= 0:
					var b := BoneAttachment3D.new()
					b.bone_name = nome
					esq.add_child(b)
					_anexos[j][nome] = b
	# (as paredes invisíveis do limite do mapa não contam para o corpo: não aparecem)
	var excluir_corpo: Array[RID] = excluir.duplicate()
	var limites := _partida.mapa.get_node_or_null("Limites") as CollisionObject3D
	if limites:
		excluir_corpo.append(limites.get_rid())
	for nome in _anexos[j]:
		var p: Vector3 = _anexos[j][nome].global_position
		var chave := "%d|%s" % [j.get_instance_id(), nome]
		if _dentro_do_cenario(esp, p, excluir_corpo):
			_registrar("%s|%s|%s" % [tipo, est, nome], p)
			_seguidos[chave] = _seguidos.get(chave, 0) + 1
			if _seguidos[chave] > _max_seguidos:
				_max_seguidos = _seguidos[chave]
				_max_seguidos_ex = "%s %s %s em %s" % [tipo, est, nome, p.snapped(Vector3.ONE * 0.01)]
		else:
			if _seguidos.get(chave, 0) > 30:
				_longos += 1
			_seguidos[chave] = 0
	# 4) Fluidez
	var m: Node3D = j.modelo.get("_modelo") if j.modelo else null
	var id := j.get_instance_id()
	if m and _ult.has(id):
		var u: Dictionary = _ult[id]
		# deslocamento do corpo visual em relação ao corpo físico, no MUNDO
		var off: Vector3 = m.global_position - j.global_position
		var salto: float = (off - u.off).length()
		var teleporte: bool = j.global_position.distance_to(u.pos) > 1.5
		if salto > 0.08 and est == u.est and not teleporte:
			_trancos += 1
			_trancos_por[est] = _trancos_por.get(est, 0) + 1
			_maior_tranco = maxf(_maior_tranco, salto)
		var giro := absf(wrapf(j.visual.rotation.y - u.yaw, -PI, PI))
		if giro > deg_to_rad(30.0) and est == u.est and not j.esta_morto() and not teleporte:
			_giros += 1
		if est != u.est:
			if est == u.est_ant and u.tempo_est < 6:
				_piscadas += 1
				var k := "%s<->%s" % [u.est, est]
				_piscadas_ex[k] = _piscadas_ex.get(k, 0) + 1
			u.est_ant = u.est
			u.tempo_est = 0
		u.tempo_est += 1
		u.off = m.global_position - j.global_position
		u.pos = j.global_position
		u.yaw = j.visual.rotation.y
		u.est = est
	elif m:
		_ult[id] = {"pos": j.global_position, "off": m.global_position - j.global_position, "yaw": j.visual.rotation.y, "est": est, "est_ant": est, "tempo_est": 0}
	# 3) Caiu do mapa
	if j.global_position.y < -3.0:
		_registrar("%s|%s|caiu do mapa" % [tipo, est], j.global_position)


func _contatos_longos() -> int:
	var n := _longos
	for k in _seguidos:
		if not String(k).ends_with("cápsula") and _seguidos[k] > 30:
			n += 1
	return n


func _rodar() -> void:
	Sessao.dificuldade = 2
	Sessao.total_participantes = 5
	Sessao.abates_para_vencer = 999
	Sessao.duracao_segundos = 900
	_partida = load("res://scenes/partida.tscn").instantiate()
	add_child(_partida)
	for i in 60:
		await get_tree().physics_frame
	var j := _partida.jogador
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var acoes := ["pular", "pular", "rolar", "deslizar", "pular"]
	var proxima := 0
	for f in int(SEGUNDOS * 60.0):
		# Jogador "explorador": muda de direção e faz uma ação a cada ~0,6-1,5 s
		if f >= proxima:
			proxima = f + rng.randi_range(36, 90)
			var ang := rng.randf() * TAU
			Controles.joystick = Vector2(cos(ang), sin(ang))
			Input.action_press(acoes[rng.randi() % acoes.size()])
		elif f == proxima - 30:
			for a in ["pular", "rolar", "deslizar"]:
				Input.action_release(a)
		j._protecao = 1.0   # o jogador não morre (o teste é de colisão)
		_medir = true
		await get_tree().physics_frame
		await get_tree().process_frame
	_medir = false
	Controles.joystick = Vector2.ZERO

	var total := 0
	var chaves := _ocorrencias.keys()
	chaves.sort_custom(func(a, b): return _ocorrencias[a] > _ocorrencias[b])
	for k in chaves:
		total += _ocorrencias[k]
		print("   %5d quadros  %-45s ex.: %s" % [_ocorrencias[k], k, _pior[k].snapped(Vector3.ONE * 0.01)])
	print("   (%d quadros x 5 personagens analisados)" % _quadros)
	var capsula := 0
	var caiu := 0
	var juntas := 0
	for k in _ocorrencias:
		if "cápsula" in k: capsula += _ocorrencias[k]
		elif k.ends_with("caiu do mapa"): caiu += _ocorrencias[k]
		else: juntas += _ocorrencias[k]
	var com_esqueleto := 0
	for k in _anexos:
		if not _anexos[k].is_empty():
			com_esqueleto += 1
	_checar("todos os personagens têm esqueleto medido (%d)" % com_esqueleto, com_esqueleto >= 5)
	# Caindo muito rápido (15 m/s = 25 cm por quadro) a física pode encostar a cápsula
	# no chão por 1 quadro e desfazer no seguinte: isso não aparece. Mais que 1 quadro, sim.
	_checar("cápsula não fica dentro do cenário (%d quadros no total, no máx. %d seguido)" % [capsula, _max_cap], _max_cap <= 2)
	_checar("ninguém caiu para fora do mapa (%d)" % caiu, caiu == 0)
	# Um contato novo leva alguns quadros para o ajuste reagir (corrige rápido, mas sem
	# tranco). Medido: quase sempre 1-8 quadros; contatos longos são raros. Critério: no
	# total, menos de 0,2% das medições e no máximo 1 contato de mais de 0,5 s por minuto.
	var total_medidas := _quadros * 5 * OSSOS.size()
	_checar("partes do corpo dentro de chão/parede: %d de %d medições (%.3f%%), máx. %d quadros seguidos (%s), contatos > 0,5 s: %d" \
		% [juntas, total_medidas, 100.0 * juntas / maxf(total_medidas, 1), _max_seguidos, _max_seguidos_ex, _contatos_longos()],
		juntas < total_medidas * 0.002 and _contatos_longos() <= 1)
	print("   trancos por estado: ", _trancos_por)
	print("   fluidez: trancos %d (maior %.3f m), giros bruscos %d, estados piscando %d %s" % [_trancos, _maior_tranco, _giros, _piscadas, _piscadas_ex])
	_checar("corpo visual sem trancos: %d acima de 8 cm num quadro (máx. 2/min), maior %.3f m (máx. 0,12)" % [_trancos, _maior_tranco],
		_trancos <= 2 and _maior_tranco <= 0.12)
	_checar("corpo não gira mais de 30° num quadro: %d" % _giros, _giros == 0)
	_checar("estado não pisca (volta em < 0,1 s): %d" % _piscadas, _piscadas <= 10)
	print("RESULTADO: %d falha(s)" % _falhas)
	get_tree().quit(_falhas)
