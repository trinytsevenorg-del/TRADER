extends Node
class_name PortadorArmas
## Armas que um personagem carrega (principal + secundária) e toda a lógica de tiro:
## cadência, modos (semi/rajada/auto), recarga, troca, recuo, dispersão, zoom,
## aim assist e tiro automático.
##
## A ENTRADA vem de fora (variáveis gatilho, pedir_recarga...): o jogador local
## preenche pelos botões; os bots (etapa 5) vão preencher pela IA. Assim o mesmo
## código serve para todo mundo.
##
## O tiro é "hitscan" (instantâneo) a partir do centro da câmera, como em quase
## todo TPS de celular: a bala vai exatamente para onde a mira aponta.

signal arma_trocada(dados: DadosArma)
signal disparou(dados: DadosArma)
signal acertou(alvo: Node, dano: float, cabeca: bool, abate: bool)
signal recarga_iniciada(tempo: float)
## Para a rede: mostra o rastro do tiro nos outros aparelhos.
signal tiro_visual(de: Vector3, ate: Vector3)

const MASCARA_TIRO := 1 | 2  # mundo + personagens

## Estado de cada arma carregada.
class Slot:
	var dados: DadosArma
	var pente := 0
	var reserva := 0
	func _init(d: DadosArma) -> void:
		dados = d
		pente = d.pente
		reserva = d.reserva

# ---- entrada (preenchida pelo controlador: jogador ou IA) ----
var gatilho := false
var pedir_recarga := false
var pedir_troca := false
var mira_botao := false

# ---- estado público (HUD, câmera, animação) ----
var slots: Array[Slot] = []
var atual := 0
var zoom_ativo := false
var tempo_desde_tiro := 99.0
var recarregando := 0.0          # tempo que falta (0 = não está recarregando)
var equipando := 0.0
var dispersao_atual := 0.0       # graus (para a mira abrir na tela)
var alvo_na_mira: Node = null    # usado pelo tiro automático e pelo HUD

var dono: CharacterBody3D
var camera: CameraTPS
var modelo_arma: ModeloArma

var _bloom := 0.0
var _proximo_tiro := 0.0
var _rajada_restante := 0
var _gatilho_anterior := false
var _buffer_semi := 0.0
var _tempo_luneta := 0.0


func _ready() -> void:
	dono = get_parent() as CharacterBody3D
	camera = dono.get_node_or_null("CameraRig") as CameraTPS


## Define as armas carregadas (ids do CatalogoArmas).
func equipar_armas(ids: Array) -> void:
	slots.clear()
	for id in ids:
		var d := CatalogoArmas.carregar(id)
		if d:
			slots.append(Slot.new(d))
	atual = 0
	_equipar_atual()


func arma() -> DadosArma:
	return slots[atual].dados if not slots.is_empty() else null


func slot() -> Slot:
	return slots[atual] if not slots.is_empty() else null


func mult_velocidade() -> float:
	var d := arma()
	return d.mult_velocidade if d else 1.0


## Zoom atual (1.0 = sem zoom) para a câmera.
func zoom_atual() -> float:
	var d := arma()
	if d == null or not zoom_ativo:
		return 1.0
	return d.zoom


func reabastecer() -> void:
	for s in slots:
		s.pente = s.dados.pente
		s.reserva = s.dados.reserva


func _equipar_atual() -> void:
	recarregando = 0.0
	_rajada_restante = 0
	_bloom = 0.0
	zoom_ativo = false
	var d := arma()
	if d == null:
		return
	equipando = d.tempo_equipar
	if dono.is_inside_tree():
		Efeitos.som_3d("troca_arma", dono.global_position + Vector3.UP * 1.2, -6.0)
	# Troca o modelo na mão do personagem.
	reprender_modelo()
	arma_trocada.emit(d)


## Chame depois que o modelo do personagem muda (troca de skin/personagem).
func reprender_modelo() -> void:
	var d := arma()
	var modelo_personagem = dono.get("modelo")
	if d and modelo_personagem and modelo_personagem.has_method("prender_arma"):
		modelo_arma = modelo_personagem.prender_arma(d.cena_modelo, d)
		_aplicar_skin(d)


## Skin da arma (só visual). Jogador local: a equipada no inventário.
## Bots: uma skin aleatória daquela arma (fica estiloso na partida).
var skin_bot: DadosSkinArma
func _aplicar_skin(d: DadosArma) -> void:
	if modelo_arma == null:
		return
	var s: DadosSkinArma = null
	if dono.controlado_localmente:
		s = Progresso.skin_equipada(d.id)
	elif dono.tipo == Jogador.Tipo.BOT:
		var opcoes := CatalogoSkins.da_arma(d.id)
		if not opcoes.is_empty() and randf() < 0.6:
			s = opcoes[randi() % opcoes.size()]
	else:
		s = CatalogoSkins.carregar(skin_remota.get(d.id, ""))
	if s:
		modelo_arma.aplicar_material(CatalogoSkins.material(s))


## Skins dos jogadores remotos (preenchido pela rede na etapa 8).
var skin_remota := {}


# =========================================================================

func _physics_process(delta: float) -> void:
	if slots.is_empty():
		return
	var d := arma()
	var s := slot()
	tempo_desde_tiro += delta
	_proximo_tiro -= delta
	_buffer_semi -= delta
	_bloom = max(_bloom - d.recuperacao_dispersao * delta, 0.0)

	if dono.controlado_localmente:
		_ler_entrada_local()
	if dono.esta_morto():
		gatilho = false
		_gatilho_anterior = false
		return

	# Troca de arma
	if pedir_troca and slots.size() > 1:
		pedir_troca = false
		atual = (atual + 1) % slots.size()
		_equipar_atual()
		return
	pedir_troca = false

	if equipando > 0.0:
		equipando -= delta
		_gatilho_anterior = gatilho
		return

	# Recarga
	if pedir_recarga:
		pedir_recarga = false
		_iniciar_recarga()
	if recarregando > 0.0:
		recarregando -= delta
		zoom_ativo = false
		if recarregando <= 0.0:
			var falta: int = d.pente - s.pente
			var pega: int = min(falta, s.reserva)
			s.pente += pega
			s.reserva -= pega
		_gatilho_anterior = gatilho
		return

	# Zoom: snipers abrem a luneta segurando; armas com zoom leve aproximam ao atirar.
	if d.atira_ao_soltar:
		# O quadro em que solta o botão ainda conta como "na luneta" (o tiro sai preciso).
		zoom_ativo = gatilho or mira_botao or (_gatilho_anterior and not gatilho)
	else:
		zoom_ativo = (gatilho and d.zoom > 1.0) or (mira_botao and d.zoom > 1.0)
	_tempo_luneta = _tempo_luneta + delta if zoom_ativo else 0.0

	_processar_gatilho(d, s)
	_gatilho_anterior = gatilho
	dispersao_atual = _calcular_dispersao(d)


func _ler_entrada_local() -> void:
	var menu: bool = Controles.menu_aberto
	gatilho = not menu and Input.is_action_pressed("atirar")
	mira_botao = not menu and Input.is_action_pressed("mirar")
	if not menu and Input.is_action_just_pressed("recarregar"):
		pedir_recarga = true
	if not menu and Input.is_action_just_pressed("trocar_arma"):
		pedir_troca = true
	_aim_assist()
	# Tiro automático: atira sozinho enquanto um inimigo estiver na mira.
	if Config.obter("tiro_automatico") and alvo_na_mira != null and not arma().atira_ao_soltar:
		gatilho = true


func _processar_gatilho(d: DadosArma, s: Slot) -> void:
	var apertou := gatilho and not _gatilho_anterior
	var soltou := not gatilho and _gatilho_anterior

	if s.pente <= 0:
		if apertou or (gatilho and d.modo == DadosArma.Modo.AUTO):
			if apertou:
				Efeitos.som_3d("vazio", dono.global_position + Vector3.UP * 1.3, -6.0)
			_iniciar_recarga()  # recarrega sozinho ao tentar atirar sem bala
		return

	if d.atira_ao_soltar:
		if soltou and _proximo_tiro <= 0.0:
			_disparar(d, s)
		return

	match d.modo:
		DadosArma.Modo.SEMI:
			if apertou:
				_buffer_semi = 0.12  # toque um pouco antes da hora ainda vale
			var auto_semi: bool = Config.obter("tiro_automatico") and alvo_na_mira != null and gatilho
			if (_buffer_semi > 0.0 or auto_semi) and _proximo_tiro <= 0.0:
				_buffer_semi = 0.0
				_disparar(d, s)
		DadosArma.Modo.AUTO:
			if gatilho and _proximo_tiro <= 0.0:
				_disparar(d, s)
		DadosArma.Modo.RAJADA:
			if _rajada_restante == 0 and gatilho and _proximo_tiro <= 0.0:
				_rajada_restante = d.tiros_por_rajada
			if _rajada_restante > 0 and _proximo_tiro <= 0.0:
				_disparar(d, s)
				_rajada_restante -= 1
				if _rajada_restante == 0 or s.pente <= 0:
					_rajada_restante = 0
					_proximo_tiro = d.pausa_rajada


func _iniciar_recarga() -> void:
	var s := slot()
	if recarregando > 0.0 or s.pente >= s.dados.pente or s.reserva <= 0:
		return
	recarregando = s.dados.tempo_recarga
	_rajada_restante = 0
	Efeitos.som_3d("recarga", dono.global_position + Vector3.UP * 1.2, -4.0)
	recarga_iniciada.emit(recarregando)


func _calcular_dispersao(d: DadosArma) -> float:
	var vel_h := Vector2(dono.velocity.x, dono.velocity.z).length()
	var disp := d.dispersao_base + _bloom
	disp += d.dispersao_movendo * clamp(vel_h / 7.5, 0.0, 1.0)
	if not dono.is_on_floor():
		disp += d.dispersao_ar
	if zoom_ativo or mira_botao:
		# Luneta: precisa de um instante "assentando" para ficar precisa.
		var assentado := 1.0 if not d.tem_luneta() else clampf(_tempo_luneta / 0.2, 0.0, 1.0)
		disp *= lerpf(1.0, d.mult_dispersao_mirando, assentado)
	return disp


func _disparar(d: DadosArma, s: Slot) -> void:
	s.pente -= 1
	_proximo_tiro = d.intervalo()
	tempo_desde_tiro = 0.0
	var disp := _calcular_dispersao(d)

	# Base da mira: câmera (jogador local) ou "olhos" do personagem (bots).
	var base_mira: Basis
	var origem: Vector3
	var peito := dono.global_position + Vector3.UP * 1.3
	if dono.controlado_localmente:
		var cam := camera.camera
		base_mira = cam.global_basis
		var frente := -base_mira.z
		# Origem do raio: o ponto da linha da câmera mais próximo do personagem
		# (assim nada entre a câmera e o personagem bloqueia o tiro).
		origem = cam.global_position + frente * maxf((peito - cam.global_position).dot(frente), 0.0)
	else:
		var olhos: Transform3D = dono.transform_olhos()
		base_mira = olhos.basis
		origem = olhos.origin
	var cano := modelo_arma.cano.global_position if modelo_arma else peito
	var espaco := dono.get_world_3d().direct_space_state

	for p in d.projeteis:
		var dir := _direcao_com_dispersao(base_mira, disp)
		var q := PhysicsRayQueryParameters3D.create(origem, origem + dir * d.alcance_maximo, MASCARA_TIRO)
		q.exclude = [dono.get_rid()]
		q.collide_with_areas = false
		var hit := espaco.intersect_ray(q)
		var fim: Vector3 = hit.position if hit else origem + dir * d.alcance_maximo
		# O tiro sai do corpo/arma, não da câmera: se a câmera "enxerga por cima"
		# de um obstáculo que o corpo não enxerga, a bala bate no obstáculo.
		if dono.controlado_localmente:
			var q2 := PhysicsRayQueryParameters3D.create(peito, fim, 1)
			q2.exclude = [dono.get_rid()]
			var bloqueio := espaco.intersect_ray(q2)
			if bloqueio and bloqueio.position.distance_to(fim) > 0.3:
				hit = bloqueio
				fim = bloqueio.position
		if p < 3:  # escopeta: só alguns rastros (economia)
			Efeitos.rastro(cano, fim, d.cor_rastro)
		if p == 0:
			tiro_visual.emit(cano, fim)
		if hit:
			var alvo: Object = hit.collider
			if alvo.has_method("receber_dano"):
				var dist := origem.distance_to(hit.position)
				var cabeca: bool = (hit.position.y - alvo.global_position.y) > 1.45
				var dano := d.dano_na_distancia(dist) * (d.mult_cabeca if cabeca else 1.0)
				var aplicado: float = alvo.receber_dano(dano, dono, hit.position, cabeca)
				if aplicado > 0.0:
					var abate: bool = alvo.has_method("esta_morto") and alvo.esta_morto()
					acertou.emit(alvo, aplicado, cabeca, abate)
			else:
				Efeitos.impacto(hit.position, hit.normal)

	_bloom = min(_bloom + d.dispersao_por_tiro, d.dispersao_extra_max)
	var fator_recuo := 0.6 if (zoom_ativo or mira_botao) else 1.0
	if dono.controlado_localmente:
		camera.adicionar_recuo(d.recuo_vertical * randf_range(0.85, 1.15) * fator_recuo,
			randf_range(-1.0, 1.0) * d.recuo_horizontal * fator_recuo)
	else:
		# Bots: o recuo sobe a mira deles (a IA compensa aos poucos).
		dono.pitch_mira += deg_to_rad(d.recuo_vertical * 0.5)
		dono.yaw_mira += deg_to_rad(randf_range(-1.0, 1.0) * d.recuo_horizontal * 0.5)
	if modelo_arma:
		modelo_arma.disparou(0.05 + d.recuo_vertical * 0.015)
	Efeitos.som_3d(d.nome_som_tiro(), cano, 0.0 if dono.controlado_localmente else -3.0)
	disparou.emit(d)


## Direção aleatória dentro de um cone (distribuição uniforme no disco).
func _direcao_com_dispersao(base: Basis, graus: float) -> Vector3:
	var r := tan(deg_to_rad(graus * 0.5)) * sqrt(randf())
	var a := randf() * TAU
	return (-base.z + base.x * cos(a) * r + base.y * sin(a) * r).normalized()


# =========================================================================
#  AIM ASSIST e alvo na mira
# =========================================================================

func _aim_assist() -> void:
	alvo_na_mira = null
	camera.fator_atrito = 1.0
	var forca: float = Config.obter("aim_assist")
	var d := arma()
	var cam := camera.camera
	var frente := -cam.global_basis.z
	var melhor: Node3D = null
	var melhor_ang := deg_to_rad(lerpf(1.5, 9.0, forca))  # cone de ajuda
	for alvo in get_tree().get_nodes_in_group("alvos"):
		if alvo == dono or (alvo.has_method("esta_morto") and alvo.esta_morto()) or not alvo.is_visible_in_tree():
			continue
		var ponto: Vector3 = alvo.global_position + Vector3.UP * 1.2
		var para := ponto - cam.global_position
		var dist := para.length()
		if dist > d.alcance_maximo:
			continue
		var ang := frente.angle_to(para)
		# Cone um pouco maior perto (alvo grande na tela)
		if ang < melhor_ang * clamp(12.0 / dist, 0.6, 2.0):
			melhor = alvo
			melhor_ang = ang
	if melhor == null:
		return
	# Linha de visão até o alvo
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, melhor.global_position + Vector3.UP * 1.2, MASCARA_TIRO)
	q.exclude = [dono.get_rid()]
	var hit := dono.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit or hit.collider != melhor:
		return
	# Alvo exatamente sob a mira (para o tiro automático): ângulo pequeno.
	var ang_real := frente.angle_to(melhor.global_position + Vector3.UP * 1.2 - cam.global_position)
	var dist_real := cam.global_position.distance_to(melhor.global_position)
	if ang_real < atan2(0.45, dist_real):  # ~ largura do corpo
		alvo_na_mira = melhor
	if forca <= 0.0:
		return
	# 1) Atrito: a mira "gruda" (fica mais lenta) passando pelo alvo.
	camera.fator_atrito = lerpf(1.0, 0.45, forca)
	# 2) Magnetismo leve só enquanto atira: puxa a mira para o alvo.
	if gatilho or tempo_desde_tiro < 0.25:
		camera.puxar_para(melhor.global_position + Vector3.UP * 1.2, deg_to_rad(30.0 * forca) * get_physics_process_delta_time())
