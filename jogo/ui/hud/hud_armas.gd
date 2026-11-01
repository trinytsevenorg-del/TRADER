extends Control
## HUD das armas: nome da arma, munição (pente / reserva), barra de recarga,
## marcador de acerto na mira, abertura da mira pela dispersão e tela de luneta.
## Lê o PortadorArmas do jogador a cada quadro (barato: só desenho 2D simples).

@export var jogador_path: NodePath

var _jogador: Jogador
var _portador: PortadorArmas
var _fonte: Font
var _marcador := 0.0          # tempo restante do "X" de acerto
var _marcador_abate := false
var _marcador_cabeca := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonte = ThemeDB.fallback_font
	if jogador_path != NodePath():
		var j := get_node_or_null(jogador_path) as Jogador
		if j:
			definir_jogador(j)


func definir_jogador(j: Jogador) -> void:
	_jogador = j
	_portador = _jogador.get_node("Armas")
	_portador.acertou.connect(func(_alvo, _dano, cabeca, abate):
		_marcador = 0.18 if not abate else 0.4
		_marcador_abate = abate
		_marcador_cabeca = cabeca)


func _process(delta: float) -> void:
	_marcador = max(_marcador - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if _portador == null or _portador.slots.is_empty() or not is_instance_valid(_jogador):
		return
	var d := _portador.arma()
	var s := _portador.slot()
	var centro := size * 0.5
	var cam := _jogador.camera_rig.camera
	var luneta := _portador.zoom_ativo and d.tem_luneta() and _jogador.camera_rig.progresso_mira() > 0.6

	# ---- Luneta: tela escura com círculo e retículo ----
	if luneta:
		var r := size.y * 0.46
		var preto := Color(0, 0, 0, 0.92)
		draw_rect(Rect2(0, 0, centro.x - r, size.y), preto)
		draw_rect(Rect2(centro.x + r, 0, size.x - centro.x - r, size.y), preto)
		# cantos do quadrado em volta do círculo (aproximação com anéis grossos)
		for i in 6:
			draw_arc(centro, r + 20.0 + i * 40.0, 0, TAU, 64, preto, 42.0)
		draw_arc(centro, r, 0, TAU, 96, Color(0, 0, 0, 1), 6.0, true)
		draw_line(centro - Vector2(r, 0), centro + Vector2(r, 0), Color(0, 0, 0, 0.85), 1.5)
		draw_line(centro - Vector2(0, r), centro + Vector2(0, r), Color(0, 0, 0, 0.85), 1.5)
		draw_circle(centro, 2.5, Color(1, 0.2, 0.2))
	else:
		# ---- Mira que abre com a dispersão ----
		var meio_fov := deg_to_rad(cam.fov * 0.5)
		var abertura: float = tan(deg_to_rad(_portador.dispersao_atual * 0.5)) / tan(meio_fov) * size.y * 0.5
		abertura = clamp(abertura, 4.0, 120.0)
		var cor := Color(1, 0.3, 0.3, 0.95) if _portador.alvo_na_mira else Color(1, 1, 1, 0.9)
		for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var a: Vector2 = centro + dir * abertura
			var b: Vector2 = centro + dir * (abertura + 10.0)
			draw_line(a + Vector2(1, 1), b + Vector2(1, 1), Color(0, 0, 0, 0.5), 3.0)
			draw_line(a, b, cor, 2.0)
		draw_circle(centro, 2.0, cor)

	# ---- Marcador de acerto (X) ----
	if _marcador > 0.0:
		var cor_m := Color(1, 0.2, 0.2) if _marcador_abate else (Color(1, 0.85, 0.2) if _marcador_cabeca else Color.WHITE)
		var t := 8.0 + (6.0 if _marcador_abate else 0.0)
		for dir in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(centro + dir * 6.0, centro + dir * (6.0 + t), cor_m, 3.0)

	# ---- Munição e nome (canto inferior, acima do botão TROCA) ----
	var base := Vector2(size.x * 0.5 - 10, size.y - 26)
	var txt_mun := "%d / %d" % [s.pente, s.reserva]
	var cor_mun := Color(1, 0.35, 0.3) if s.pente <= int(d.pente * 0.25) else Color.WHITE
	draw_string(_fonte, base + Vector2(2, 2), txt_mun, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0, 0, 0, 0.6))
	draw_string(_fonte, base, txt_mun, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, cor_mun)
	var modo: String = ["SEMI", "RAJADA", "AUTO"][d.modo]
	draw_string(_fonte, base + Vector2(0, -34), "%s  ·  %s" % [d.nome, modo], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.85))

	# ---- Recarga / equipando ----
	var total := 0.0
	var falta := 0.0
	var rotulo := ""
	if _portador.recarregando > 0.0:
		total = d.tempo_recarga
		falta = _portador.recarregando
		rotulo = "RECARREGANDO"
	elif _portador.equipando > 0.0:
		total = d.tempo_equipar
		falta = _portador.equipando
		rotulo = "EQUIPANDO"
	if total > 0.0:
		var p := 1.0 - falta / total
		var largura := 160.0
		var pos := centro + Vector2(-largura * 0.5, 60)
		draw_rect(Rect2(pos, Vector2(largura, 8)), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(pos, Vector2(largura * p, 8)), Color(1, 1, 1, 0.9))
		var lw := _fonte.get_string_size(rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(_fonte, pos + Vector2((largura - lw) * 0.5, -6), rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	elif s.pente == 0 and s.reserva == 0:
		draw_string(_fonte, centro + Vector2(-60, 70), "SEM MUNIÇÃO", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.4, 0.3))
