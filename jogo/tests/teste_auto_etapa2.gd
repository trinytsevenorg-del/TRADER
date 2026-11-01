extends Node
## Teste automático da etapa 2 (parkour), roda sem tela:
##   godot --headless --path . res://tests/teste_auto_etapa2.tscn

var _j: Jogador
var _falhas := 0


func _ready() -> void:
	var cena: Node = load("res://scenes/test/teste_etapa1.tscn").instantiate()
	add_child(cena)
	_j = cena.get_node("Jogador")
	_rodar()


func _checar(nome: String, ok: bool) -> void:
	print(("OK    " if ok else "FALHA ") + nome)
	if not ok: _falhas += 1


func _esperar(seg: float) -> void:
	var quadros := int(seg * 60.0)
	for i in quadros:
		await get_tree().physics_frame


func _apertar(acao: String) -> void:
	Input.action_press(acao)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(acao)


## Altura máxima em que o personagem ficou EM PÉ (no chão) durante o tempo dado.
func _altura_max(seg: float) -> float:
	var m := 0.0
	for i in int(seg * 60.0):
		await get_tree().physics_frame
		if _j.is_on_floor():
			m = max(m, _j.global_position.y)
	return m


func _preparar(pos: Vector3, yaw: float) -> void:
	Controles.joystick = Vector2.ZERO
	_j.teleportar(pos, yaw)
	await _esperar(0.3)


## Coloca o personagem caindo de frente para a caixa de 3 m e espera agarrar.
func _pendurar() -> void:
	Controles.joystick = Vector2.ZERO
	_j.teleportar(Vector3(2.0, 1.4, -6.45), 0.0)
	_j.velocity.y = -3.0
	Controles.joystick = Vector2(0, -1)
	for i in 40:
		await get_tree().physics_frame
		if _j.estado == &"pendurado":
			break
	Controles.joystick = Vector2.ZERO
	await _esperar(0.25)


func _rodar() -> void:
	await _esperar(0.4)

	# 1) Pulo duplo
	await _preparar(Vector3(0, 0.1, 10), 0.0)
	await _apertar("pular")
	var y_max := 0.0
	for i in 60:
		if i == 22: await _apertar("pular")  # perto do topo do primeiro pulo
		y_max = max(y_max, _j.global_position.y)
		await get_tree().physics_frame
	_checar("pulo duplo sobe mais de 2,8 m (%.2f)" % y_max, y_max > 2.8)
	await _esperar(1.0)

	# 2) Corrida na parede (muro azul em x = 19.7, correndo para -Z)
	await _preparar(Vector3(19.0, 0.1, 20.0), 0.0)
	Controles.joystick = Vector2(0, -1)
	await _esperar(0.3)
	await _apertar("pular")
	await _esperar(0.45)  # já caindo
	await _apertar("pular")
	await _esperar(0.1)
	_checar("grudou na parede (estado %s)" % _j.estado, _j.estado == &"parede")
	var z0 := _j.global_position.z
	await _esperar(0.8)
	_checar("continua na parede após 0,8 s", _j.estado == &"parede")
	_checar("correu ao longo da parede (%.1f m)" % (z0 - _j.global_position.z), z0 - _j.global_position.z > 5.0)
	_checar("não caiu no chão (y=%.2f)" % _j.global_position.y, _j.global_position.y > 0.8)
	var x0 := _j.global_position.x
	await _apertar("pular")
	await _esperar(0.3)
	_checar("pulo de parede afasta da parede (%.2f m)" % (x0 - _j.global_position.x), x0 - _j.global_position.x > 1.2)
	Controles.joystick = Vector2.ZERO
	await _esperar(1.5)

	# 3) Pular de uma parede para a outra (paredes em x=28 e x=33)
	await _preparar(Vector3(29.0, 0.1, -2.0), 0.0)
	Controles.joystick = Vector2(0, -1)
	await _esperar(0.25)
	await _apertar("pular")
	await _esperar(0.4)
	await _apertar("pular")      # gruda na parede da esquerda
	await _esperar(0.3)
	await _apertar("pular")      # salta para a parede da direita
	await _esperar(0.5)
	await _apertar("pular")      # gruda na outra parede
	await _esperar(0.1)
	_checar("parede a parede: grudou na segunda parede (x=%.2f, %s)" % [_j.global_position.x, _j.estado],
		_j.estado == &"parede" and _j.global_position.x > 31.0)
	Controles.joystick = Vector2.ZERO
	await _esperar(2.0)

	# 4) Agarrar e subir beirada (caixa de 2,2 m em x=-1.5, z=-8)
	await _preparar(Vector3(-1.5, 0.1, -4.5), 0.0)
	Controles.joystick = Vector2(0, -1)
	await _esperar(0.2)
	await _apertar("pular")
	var ym := await _altura_max(1.0)
	_checar("subiu na caixa de 2,2 m (y=%.2f)" % ym, ym > 2.1)
	Controles.joystick = Vector2.ZERO

	# 5) Correr parede acima e subir (caixa de 3 m em x=2, z=-8)
	await _preparar(Vector3(2.0, 0.1, -5.5), 0.0)
	Controles.joystick = Vector2(0, -1)
	await _esperar(0.15)
	await _apertar("pular")
	await _esperar(0.2)
	await _apertar("pular")
	var ym2 := await _altura_max(1.0)
	_checar("subiu na caixa de 3 m correndo na parede (y=%.2f, em pé no topo)" % ym2, ym2 > 2.9)
	Controles.joystick = Vector2.ZERO

	# 6) Rolamento: mais lento e suave, invencível só no começo, joystick muda a direção
	await _preparar(Vector3(0, 0.1, 10), 0.0)
	var z_ini := _j.global_position.z
	await _apertar("rolar")
	_checar("rolando e invencível", _j.estado == &"rolando" and _j.invencivel)
	await _esperar(0.33)
	_checar("invencibilidade acaba (~0,3 s)", not _j.invencivel)
	_checar("rolamento ainda em andamento aos 0,35 s (mais lento)", _j.estado == &"rolando")
	await _esperar(0.45)
	var dist_rol := z_ini - _j.global_position.z
	_checar("rolou entre 4 e 6,5 m (%.2f)" % dist_rol, dist_rol > 4.0 and dist_rol < 6.5)
	_checar("rolamento terminou (~0,7 s)", _j.estado != &"rolando")
	await _apertar("rolar")   # durante a recarga: fica guardado
	await _esperar(0.4)
	_checar("rolar apertado na recarga sai sozinho logo depois (encadear)", _j.estado == &"rolando")
	await _esperar(1.0)
	# Direção no meio do rolamento
	await _preparar(Vector3(0, 0.1, 10), 0.0)
	await _apertar("rolar")
	Controles.joystick = Vector2(1, 0)  # puxa para a direita
	await _esperar(0.3)
	var dir_rol := Vector3(_j.velocity.x, 0, _j.velocity.z).normalized()
	_checar("joystick muda a direção do rolamento (dir.x=%.2f)" % dir_rol.x, dir_rol.x > 0.8)
	Controles.joystick = Vector2.ZERO
	await _esperar(1.0)

	# 6b) Deslize estilo prancha: zigue-zague rápido e mantém embalo
	await _preparar(Vector3(10, 0.1, 36), 0.0)   # área aberta
	Controles.joystick = Vector2(0, -1)
	await _esperar(0.4)
	await _apertar("deslizar")
	Controles.joystick = Vector2(1, -0.2).normalized()   # puxa para a direita
	await _esperar(0.25)
	var x_dir := _j.global_position.x
	Controles.joystick = Vector2(-1, -0.2).normalized()  # e para a esquerda, rápido
	await _esperar(0.3)
	var x_esq := _j.global_position.x
	_checar("deslize: foi para a direita (x=%.2f) e voltou para a esquerda rápido (x=%.2f)" % [x_dir, x_esq],
		x_dir > 10.8 and x_esq < x_dir - 0.6)
	_checar("deslize mantém o embalo (%.1f m/s, ainda deslizando)" % Vector2(_j.velocity.x, _j.velocity.z).length(),
		_j.estado == &"deslizando" and Vector2(_j.velocity.x, _j.velocity.z).length() > 7.0)
	# Encadeia: deslize -> rolamento -> deslize
	await _apertar("rolar")
	_checar("rolamento direto do deslize", _j.estado == &"rolando")
	await _esperar(0.75)
	await _apertar("deslizar")
	await _esperar(0.1)
	_checar("deslize de novo logo após o rolamento (%s, %.1f m/s, chão %s)" % [_j.estado, Vector2(_j.velocity.x, _j.velocity.z).length(), _j.is_on_floor()], _j.estado == &"deslizando")
	Controles.joystick = Vector2.ZERO
	await _esperar(2.0)

	# 7) Deslize correndo, passando por baixo do túnel baixo (vão de 1,3 m)
	await _preparar(Vector3(-28, 0.1, 16), 0.0)
	Controles.joystick = Vector2(0, -1)
	await _esperar(0.5)
	await _apertar("deslizar")
	_checar("deslizando", _j.estado == &"deslizando")
	await _esperar(1.2)
	_checar("entrou no túnel baixo deslizando (z=%.2f)" % _j.global_position.z, _j.global_position.z < 7.0)
	await _esperar(0.8)  # continua segurando para frente: rasteja até sair
	_checar("saiu do outro lado do túnel (z=%.2f)" % _j.global_position.z, _j.global_position.z < 6.0)
	Controles.joystick = Vector2.ZERO
	await _esperar(1.5)
	_checar("levantou depois de sair do túnel (%s)" % _j.estado, _j.estado != &"deslizando")

	# 8) Transpor obstáculo baixo (mureta de 1,1 m em z = -4, x de -30 a -26)
	await _preparar(Vector3(-28, 0.1, 0.5), 0.0)
	Controles.joystick = Vector2(0, -1)
	var viu_transpor := false
	var vel_depois := 0.0
	for i in 70:
		if i == 27: Input.action_press("pular")
		if i == 29: Input.action_release("pular")
		await get_tree().physics_frame
		if _j.estado == &"transpondo":
			viu_transpor = true
		if i == 60:
			vel_depois = Vector2(_j.velocity.x, _j.velocity.z).length()
	Controles.joystick = Vector2.ZERO
	_checar("transpôs a mureta (estado visto: %s, z=%.2f)" % [viu_transpor, _j.global_position.z],
		viu_transpor and _j.global_position.z < -4.6 and _j.global_position.y < 0.4)
	_checar("manteve a velocidade ao transpor (%.1f m/s)" % vel_depois, vel_depois > 5.5)
	await _esperar(0.5)

	# 9) Queda alta parado: recupera o equilíbrio (aterrissando) e depois volta ao normal
	await _preparar(Vector3(0, 8.0, 10), 0.0)
	var viu_aterrissar := false
	for i in 120:
		await get_tree().physics_frame
		if _j.estado == &"aterrissando":
			viu_aterrissar = true
	_checar("queda alta: recuperação na aterrissagem", viu_aterrissar)
	_checar("depois da recuperação volta ao normal (%s)" % _j.estado, _j.estado == &"parado")

	# 10) Pendurar na beirada (caixa de 3 m em x 1..3, z -9..-7): agarrar caindo
	await _pendurar()
	_checar("agarrou a beirada alta caindo e ficou pendurado (%s, y=%.2f)" % [_j.estado, _j.global_position.y],
		_j.estado == &"pendurado" and absf(_j.global_position.y - 1.26) < 0.1)
	await _esperar(0.5)
	_checar("pendurado não cai (y=%.2f)" % _j.global_position.y, _j.estado == &"pendurado" and absf(_j.global_position.y - 1.26) < 0.1)
	# Andar de lado pela borda (para a direita = +x), parando no fim da caixa
	Controles.joystick = Vector2(1, 0)
	await _esperar(0.4)
	_checar("anda de lado pendurado (x=%.2f)" % _j.global_position.x, _j.estado == &"pendurado" and _j.global_position.x > 2.4)
	await _esperar(1.0)
	_checar("para no fim da beirada sem cair (x=%.2f, %s)" % [_j.global_position.x, _j.estado],
		_j.estado == &"pendurado" and _j.global_position.x < 2.8)
	Controles.joystick = Vector2.ZERO
	await _esperar(0.1)
	await _apertar("pular")
	var ym3 := await _altura_max(1.0)
	_checar("PULAR pendurado sobe na beirada (y=%.2f)" % ym3, ym3 > 2.9)
	# Soltar com DESLIZAR: cai e não agarra de novo
	await _pendurar()
	await _apertar("deslizar")
	await _esperar(0.8)
	_checar("DESLIZAR solta a beirada e cai (y=%.2f, %s)" % [_j.global_position.y, _j.estado],
		_j.global_position.y < 0.3 and _j.estado != &"pendurado")
	# Joystick para trás + PULAR: salta para longe da parede
	await _pendurar()
	Controles.joystick = Vector2(0, 1)
	await _apertar("pular")
	await _esperar(0.1)
	_checar("trás + PULAR salta para longe da parede (vz=%.1f, vy=%.1f)" % [_j.velocity.z, _j.velocity.y],
		_j.estado != &"pendurado" and _j.velocity.z > 3.0 and _j.velocity.y > 2.0)
	Controles.joystick = Vector2.ZERO
	await _esperar(1.5)

	print("RESULTADO: %d falha(s)" % _falhas)
	get_tree().quit(_falhas)
