extends Node
## Teste automático da etapa 3 (armas), roda sem tela:
##   godot --headless --path . res://tests/teste_auto_etapa3.tscn

var _j: Jogador
var _a: PortadorArmas
var _falhas := 0
var _alvo: Node3D


func _ready() -> void:
	Config.definir("tiro_automatico", false)
	Config.definir("aim_assist", 0.0)
	var cena: Node = load("res://scenes/test/teste_etapa1.tscn").instantiate()
	add_child(cena)
	_j = cena.get_node("Jogador")
	_a = _j.get_node("Armas")
	_rodar()


func _checar(nome: String, ok: bool) -> void:
	print(("OK    " if ok else "FALHA ") + nome)
	if not ok: _falhas += 1


func _esperar(seg: float) -> void:
	for i in int(seg * 60.0):
		await get_tree().physics_frame


## Aponta a câmera para o peito (ou cabeça) do alvo.
func _mirar(alvo: Node3D, altura := 1.2) -> void:
	for i in 20:
		_j.camera_rig.puxar_para(alvo.global_position + Vector3.UP * altura, 1.0)
		await get_tree().process_frame


func _equipar(principal: String) -> void:
	_a.equipar_armas([principal, "vespa_p9"])
	await _esperar(1.0)  # tempo de equipar


func _rodar() -> void:
	await _esperar(0.5)
	# Boneco parado mais próximo (0, 0, -18)
	for b in get_tree().get_nodes_in_group("alvos"):
		if b.global_position.distance_to(Vector3(0, 0, -18)) < 0.5:
			_alvo = b

	# 0) Todas as armas carregam, com modelo e pontos de encaixe
	var ok_todas := true
	for id in CatalogoArmas.todas():
		var d := CatalogoArmas.carregar(id)
		if d == null or d.cena_modelo == null:
			ok_todas = false; continue
		var m: Node = d.cena_modelo.instantiate()
		if not (m.has_node("Mao") and m.has_node("Cano") and m.has_node("Mira")):
			ok_todas = false
		m.free()
	_checar("12 armas carregam com modelo e pontos Mao/Cano/Mira", ok_todas and CatalogoArmas.todas().size() == 12)

	# 1) Queda de dano por distância
	var ar := CatalogoArmas.carregar("corisco_ar")
	_checar("dano cai com a distância (%.1f perto, %.1f longe)" % [ar.dano_na_distancia(10), ar.dano_na_distancia(70)],
		ar.dano_na_distancia(10) == ar.dano and ar.dano_na_distancia(70) < ar.dano * 0.6)

	# 2) Arma na mão, apontando para frente na pose de mira
	_j.teleportar(Vector3(0, 0.1, -8), 0.0)
	await _equipar("corisco_ar")
	_checar("arma principal equipada (Corisco AR, 30 balas)", _a.arma().id == "corisco_ar" and _a.slot().pente == 30)
	Input.action_press("mirar")
	await _esperar(0.6)
	var frente_arma := -_a.modelo_arma.global_basis.z
	var frente_corpo := Vector3(0, 0, -1).rotated(Vector3.UP, _j.visual.rotation.y)
	_checar("arma aponta para frente mirando (alinhamento %.2f)" % frente_arma.dot(frente_corpo), frente_arma.dot(frente_corpo) > 0.85)
	Input.action_release("mirar")

	# 3) Automático: segurar 1 s gasta ~10 balas e acerta o boneco
	await _mirar(_alvo)
	var vida0: float = _alvo.saude.vida
	Input.action_press("atirar")
	await _esperar(1.0)
	Input.action_release("atirar")
	var gastou := 30 - _a.slot().pente
	_checar("automático: ~10 tiros em 1 s (gastou %d)" % gastou, gastou >= 8 and gastou <= 12)
	_checar("acertou o boneco (vida %.0f -> %.0f / morreu: %s)" % [vida0, _alvo.saude.vida, _alvo.saude.morto],
		_alvo.saude.morto or _alvo.saude.vida < vida0)
	await _esperar(3.0)  # boneco reaparece

	# 4) Recarga
	var reserva0 := _a.slot().reserva
	Input.action_press("recarregar"); await get_tree().physics_frame; Input.action_release("recarregar")
	await _esperar(0.2)
	_checar("recarregando", _a.recarregando > 0.0)
	await _esperar(2.4)
	_checar("pente cheio após recarga (%d) e reserva diminuiu (%d -> %d)" % [_a.slot().pente, reserva0, _a.slot().reserva],
		_a.slot().pente == 30 and _a.slot().reserva < reserva0)

	# 5) Semiautomática: segurar = 1 tiro só
	Input.action_press("trocar_arma"); await get_tree().physics_frame; Input.action_release("trocar_arma")
	await _esperar(0.6)
	_checar("trocou para a secundária (Vespa P9)", _a.arma().id == "vespa_p9")
	var p0 := _a.slot().pente
	Input.action_press("atirar")
	await _esperar(0.8)
	Input.action_release("atirar")
	_checar("semi: segurar dispara 1 tiro (gastou %d)" % (p0 - _a.slot().pente), p0 - _a.slot().pente == 1)

	# 6) Rajada: 1 toque = 3 tiros
	await _equipar("faisca_r3")
	await _mirar(_alvo)
	Input.action_press("atirar"); await _esperar(0.05); Input.action_release("atirar")
	await _esperar(0.4)
	_checar("rajada: 1 toque = 3 tiros (gastou %d)" % (30 - _a.slot().pente), 30 - _a.slot().pente == 3)

	# 7) Zoom leve ao atirar (Falcão BR) e sem zoom (Corisco AR)
	await _equipar("falcao_br")
	Input.action_press("atirar"); await _esperar(0.1)
	_checar("Falcão BR aproxima ao atirar (zoom %.2f)" % _a.zoom_atual(), _a.zoom_ativo and _a.zoom_atual() > 1.2)
	Input.action_release("atirar")
	await _equipar("corisco_ar")
	Input.action_press("atirar"); await _esperar(0.1)
	_checar("Corisco AR NÃO aproxima ao atirar", not _a.zoom_ativo)
	Input.action_release("atirar")
	await _esperar(3.0)

	# 8) Sniper: segurar abre a luneta sem atirar; soltar atira. Tiro na cabeça derruba.
	await _equipar("agulha_sr")
	await _mirar(_alvo, 1.62)
	Input.action_press("atirar")
	await _esperar(0.6)
	_checar("sniper: segurando abre a luneta (zoom %.1f) sem atirar" % _a.zoom_atual(), _a.zoom_ativo and _a.slot().pente == 5)
	await _mirar(_alvo, 1.62)
	await _esperar(0.3)
	Input.action_release("atirar")
	await _esperar(0.1)
	_checar("sniper: soltou = atirou (pente %d)" % _a.slot().pente, _a.slot().pente == 4)
	_checar("sniper na cabeça derruba com 1 tiro", _alvo.saude.morto)
	await _esperar(3.0)

	# 9) Escopeta de perto: 1 tiro derruba
	_j.teleportar(_alvo.global_position + Vector3(0, 0.1, 4.0), 0.0)
	await _equipar("trovao_12")
	await _mirar(_alvo)
	Input.action_press("atirar"); await _esperar(0.05); Input.action_release("atirar")
	await _esperar(0.1)
	_checar("escopeta a 4 m: 1 tiro derruba (vida %.0f)" % _alvo.saude.vida, _alvo.saude.morto)
	await _esperar(3.0)

	# 10) Tiro automático: com a mira no inimigo, atira sozinho
	_j.teleportar(Vector3(0, 0.1, -8), 0.0)
	await _equipar("corisco_ar")
	Config.definir("tiro_automatico", true)
	await _mirar(_alvo)
	await _esperar(0.5)
	_checar("tiro automático disparou sozinho (gastou %d)" % (30 - _a.slot().pente), _a.slot().pente < 30)
	Config.definir("tiro_automatico", false)

	# 11) Rolamento: invencível ignora dano
	await _esperar(0.5)
	Input.action_press("rolar"); await get_tree().physics_frame; Input.action_release("rolar")
	await get_tree().physics_frame
	var vida_j := _j.saude.vida
	_j.receber_dano(50, null, _j.global_position, false)
	_checar("invencível no rolamento não toma dano", _j.saude.vida == vida_j)
	await _esperar(0.5)
	_j.receber_dano(30, null, _j.global_position, false)
	_checar("fora do rolamento toma dano (vida %.0f)" % _j.saude.vida, _j.saude.vida == vida_j - 30)

	# 12) Animações de fuzil: mira com tronco girado e recarga com a mão esquerda
	await _esperar(1.0)
	await _equipar("corisco_ar")
	var mod = _j.modelo
	if mod.get("_esqueleto") == null:
		_checar("modelo humano presente para testar animações de fuzil", false)
	else:
		_checar("mira de fuzil gerada (Rifle_Aim_Down/Neutral/Up)",
			mod._obter_biblioteca().has_animation("Rifle_Aim_Neutral") and mod._obter_biblioteca().has_animation("Rifle_Aim_Up"))
		_checar("arma longa usa a mira de fuzil", mod._pontos_mira[1].animation == &"Rifle_Aim_Neutral")
		var esq: Skeleton3D = mod._esqueleto
		var mao_e := BoneAttachment3D.new()
		mao_e.bone_name = "hand_l"
		esq.add_child(mao_e)
		await _esperar(0.3)
		var guarda: Node3D = _a.modelo_arma.get_node("MaoEsquerda")
		var antes := mao_e.global_position.distance_to(guarda.global_position)
		_checar("mão esquerda no guarda-mão antes da recarga (%.2f m)" % antes, antes < 0.08)
		_a.slot().pente = 5
		_a.pedir_recarga = true
		var maior := 0.0
		for i in int(_a.arma().tempo_recarga * 60.0):
			await get_tree().physics_frame
			maior = maxf(maior, mao_e.global_position.distance_to(guarda.global_position))
		_checar("recarga de fuzil: mão esquerda sai do guarda-mão até a cintura (%.2f m)" % maior, maior > 0.25)
		await _esperar(0.4)
		var depois := mao_e.global_position.distance_to(guarda.global_position)
		_checar("mão esquerda volta ao guarda-mão (%.2f m) e pente cheio (%d)" % [depois, _a.slot().pente],
			depois < 0.08 and _a.slot().pente == _a.arma().pente)
		mao_e.queue_free()

	print("RESULTADO: %d falha(s)" % _falhas)
	get_tree().quit(_falhas)
