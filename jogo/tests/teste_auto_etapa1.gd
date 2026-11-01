extends Node
## Teste automático da etapa 1 (roda sem tela):
##   godot --headless --path . res://tests/teste_auto_etapa1.tscn
## Simula entradas e verifica movimento, pulo e câmera.

var _t := 0.0
var _fase := 0
var _j: Jogador
var _falhas := 0

func _ready() -> void:
	var cena: Node = load("res://scenes/test/teste_etapa1.tscn").instantiate()
	add_child(cena)
	_j = cena.get_node("Jogador")
	var sol: DirectionalLight3D = cena.get_node("Sol")
	_checar("sol aponta para baixo", (-sol.global_basis.z).y < -0.3)

func _checar(nome: String, ok: bool) -> void:
	print(("OK    " if ok else "FALHA ") + nome)
	if not ok: _falhas += 1

func _physics_process(delta: float) -> void:
	_t += delta
	match _fase:
		0:
			if _t > 0.5:
				_checar("começa no chão", _j.is_on_floor())
				_fase = 1; _t = 0
				Controles.joystick = Vector2(0, -1)  # frente
		1:
			if _t > 0.15:
				var v := Vector2(_j.velocity.x, _j.velocity.z).length()
				_checar("acelera rápido (%.2f m/s em 0.15s)" % v, v > 6.0)
				_fase = 2; _t = 0
		2:
			if _t > 0.4:
				_checar("estado correndo", _j.estado == &"correndo")
				Input.action_press("pular")
				_fase = 3; _t = 0
		3:
			if _t > 0.25:
				Input.action_release("pular")
				_checar("pulou (y=%.2f)" % _j.global_position.y, _j.global_position.y > 1.0)
				_fase = 4; _t = 0
		4:
			if _t > 1.2:
				_checar("voltou ao chão", _j.is_on_floor())
				Controles.joystick = Vector2.ZERO
				_fase = 5; _t = 0
		5:
			if _t > 0.25:
				var v := Vector2(_j.velocity.x, _j.velocity.z).length()
				_checar("para suave mas rápido (%.2f m/s)" % v, v < 0.1)
				_j.camera_rig.yaw += PI / 2.0
				Controles.joystick = Vector2(0, -1)
				_fase = 6; _t = 0
		6:
			if _t > 0.4:
				var v := _j.velocity.normalized()
				var esperado := Vector3(0, 0, -1).rotated(Vector3.UP, _j.camera_rig.yaw)
				_checar("anda para onde a câmera olha", Vector3(v.x, 0, v.z).normalized().dot(esperado) > 0.95)
				Controles.joystick = Vector2.ZERO
				# Teleporta para dentro do corredor estreito, de costas para a parede
				_j.teleportar(Vector3(-2.8, 0.1, 22.0), 0.0)
				_j.camera_rig.yaw = PI / 2.0  # olhando para -X: câmera fica atrás, em +X... e o ombro em direção à parede
				_fase = 7; _t = 0
		7:
			if _t > 0.5:
				var cam := _j.camera_rig.camera.global_position
				_checar("câmera dentro do corredor (x=%.2f entre -3.75 e -1.85)" % cam.x, cam.x > -3.75 and cam.x < -1.85)
				_checar("câmera abaixo do teto (y=%.2f)" % cam.y, cam.y < 4.0)
				_j.teleportar(Vector3(-20, 0.1, 7.0), PI)
				_j.camera_rig.yaw = 0.0
				Controles.joystick = Vector2(0, -1)
				_fase = 8; _t = 0
		8:
			if _t > 1.0:  # ~7 m: rampa (5 m) + patamar
				_checar("subiu a escada (y=%.2f)" % _j.global_position.y, _j.global_position.y > 2.3)
				Controles.joystick = Vector2.ZERO
				print("RESULTADO: %d falha(s)" % _falhas)
				get_tree().quit(_falhas)
