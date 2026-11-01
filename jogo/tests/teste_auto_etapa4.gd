extends Node
## Teste automático da etapa 4 (mapa Vila Telhado), roda sem tela:
##   godot --headless --path . res://tests/teste_auto_etapa4.tscn

var _mapa: Mapa
var _j: Jogador
var _falhas := 0


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_mapa = load("res://scenes/mapas/vila_telhado.tscn").instantiate()
	add_child(_mapa)
	_j = _mapa.get_node("Jogador")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("tempo de carga + mesclagem: %d ms" % (Time.get_ticks_msec() - t0))
	_rodar()


func _checar(nome: String, ok: bool) -> void:
	print(("OK    " if ok else "FALHA ") + nome)
	if not ok: _falhas += 1


func _esperar(seg: float) -> void:
	for i in int(seg * 60.0):
		await get_tree().physics_frame


func _correr(pos: Vector3, yaw: float, seg: float, pular_em := -1.0) -> void:
	Controles.joystick = Vector2.ZERO
	_j.teleportar(pos, yaw)
	await _esperar(0.25)
	Controles.joystick = Vector2(0, -1)
	var t := 0.0
	while t < seg:
		if pular_em >= 0.0 and abs(t - pular_em) < 0.01:
			Input.action_press("pular")
		if pular_em >= 0.0 and abs(t - pular_em - 0.05) < 0.01:
			Input.action_release("pular")
		await get_tree().physics_frame
		t += 1.0 / 60.0
	Controles.joystick = Vector2.ZERO
	await _esperar(0.3)


func _rodar() -> void:
	await _esperar(0.3)
	var info: Dictionary = _mapa.info_mesclagem
	_checar("malhas mescladas: %d -> %d" % [info.get("antes", 0), info.get("depois", 0)],
		info.get("depois", 999) < 120 and info.get("antes", 0) > 500)

	# Renascimentos: no chão, com espaço livre, dentro do mapa e espalhados
	var pontos := get_tree().get_nodes_in_group("renascimento")
	_checar("10 pontos de renascimento", pontos.size() == 10)
	var espaco := _j.get_world_3d().direct_space_state
	var todos_ok := true
	for p in pontos:
		var pos: Vector3 = p.global_position
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos - Vector3.UP * 1.0, 1)
		var hit := espaco.intersect_ray(q)
		var no_chao: bool = hit and pos.y - hit.position.y < 0.6
		var livre := _j._espaco_livre(pos + Vector3.UP * 0.05, 1.8)
		var dentro: bool = abs(pos.x) < 30 and abs(pos.z) < 30
		var mais_perto := INF
		for o in pontos:
			if o != p:
				mais_perto = min(mais_perto, pos.distance_to(o.global_position))
		if not (no_chao and livre and dentro and mais_perto > 9.0):
			todos_ok = false
			print("   problema em %s: chão=%s livre=%s dentro=%s vizinho=%.1f m" % [p.name, no_chao, livre, dentro, mais_perto])
	_checar("renascimentos no chão, livres, dentro do mapa e espalhados (> 9 m)", todos_ok)

	# Escolha de renascimento longe do inimigo
	var inimigo := Vector3(-8, 0, -28)
	var esc: Node3D = _mapa.escolher_renascimento([inimigo])
	_checar("renasce longe do inimigo (%.1f m)" % esc.global_position.distance_to(inimigo), esc.global_position.distance_to(inimigo) > 25.0)

	# Chão da morte
	_j.teleportar(Vector3(0, -20, 0), 0.0)
	await _esperar(0.2)
	_checar("caiu do mapa -> renasceu (y=%.1f)" % _j.global_position.y, _j.global_position.y > -1.0)

	# Limite do mapa
	await _correr(Vector3(-28.8, 0.2, 0), PI / 2.0, 1.5)  # correndo para oeste (-X)
	_checar("limite segura o jogador (x=%.2f)" % _j.global_position.x, _j.global_position.x > -30.5)

	# Rotas para os telhados
	await _correr(Vector3(3.5, 0.2, -9.5), 0.0, 1.6)
	_checar("escada até o telhado do N-meio (y=%.2f)" % _j.global_position.y, _j.global_position.y > 3.4)
	await _correr(Vector3(-17.1, 0.2, 8.0), 0.0, 1.2)  # para no patamar do topo
	_checar("escada até o telhado do prédio Oeste (y=%.2f)" % _j.global_position.y, _j.global_position.y > 4.4)
	await _correr(Vector3(-23, 4.8, -7.0), 0.0, 1.5)
	_checar("passarela do prédio Oeste até o NO (y=%.2f)" % _j.global_position.y, _j.global_position.y > 5.9)
	await _correr(Vector3(17, 5.4, -7.5), 0.0, 1.5)
	_checar("passarela do container até o NE (y=%.2f)" % _j.global_position.y, _j.global_position.y > 6.4)
	await _correr(Vector3(13, 0.2, 7.0), PI, 1.8)
	_checar("escada até o telhado do SE (y=%.2f)" % _j.global_position.y, _j.global_position.y > 5.9)
	await _correr(Vector3(5.0, 7.3, 20), -PI / 2.0, 1.2)
	_checar("passarela do S-meio até o SE (y=%.2f, x=%.1f)" % [_j.global_position.y, _j.global_position.x], _j.global_position.y > 5.9 and _j.global_position.x > 10)
	# Subir no container com o caixote (pular no caixote e depois no container)
	await _correr(Vector3(15, 0.2, -3.8), 0.0, 1.0, 0.15)  # pula no caixote e agarra a beirada
	_checar("caixote -> em cima do container de baixo (y=%.2f)" % _j.global_position.y, _j.global_position.y > 2.5)
	# e do container de baixo para o de cima (5,2 m), pulando contra a parede
	Controles.joystick = Vector2(1, 0)  # para leste, onde está o container de cima
	await _esperar(0.15)
	Input.action_press("pular"); await _esperar(0.05); Input.action_release("pular")
	await _esperar(1.0)
	Controles.joystick = Vector2.ZERO
	await _esperar(0.3)
	_checar("container de baixo -> container de cima (y=%.2f)" % _j.global_position.y, _j.global_position.y > 5.1)

	print("RESULTADO: %d falha(s)" % _falhas)
	get_tree().quit(_falhas)
