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

	# 6) Rolamento: invencível no início, depois não; anda alguns metros
	await _preparar(Vector3(0, 0.1, 10), 0.0)
	var z_ini := _j.global_position.z
	await _apertar("rolar")
	_checar("rolando e invencível", _j.estado == &"rolando" and _j.invencivel)
	await _esperar(0.33)
	_checar("invencibilidade acaba (~0,3 s)", not _j.invencivel)
	await _esperar(0.3)
	_checar("rolou mais de 3,5 m (%.2f)" % (z_ini - _j.global_position.z), z_ini - _j.global_position.z > 3.5)
	await _apertar("rolar")
	_checar("recarga impede rolar de novo na hora", _j.estado != &"rolando")

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

	print("RESULTADO: %d falha(s)" % _falhas)
	get_tree().quit(_falhas)
