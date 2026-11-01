extends Label
## Mostra FPS, estado e velocidade do jogador. Ligue/desligue em Configurações.

@export var jogador_path: NodePath
var _jogador: Node
var _acumulado := 0.0


func definir_jogador(j: Node) -> void:
	_jogador = j


func _ready() -> void:
	if jogador_path != NodePath():
		_jogador = get_node_or_null(jogador_path)
	position = Vector2(16, 12)
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	visible = Config.obter("mostrar_fps")
	_acumulado += delta
	if not visible or _acumulado < 0.25:  # atualiza 4x/s (texto é caro de refazer)
		return
	_acumulado = 0.0
	var txt := "FPS %d" % Engine.get_frames_per_second()
	if _jogador:
		var v: Vector3 = _jogador.velocity
		txt += "\n%s  %.1f m/s" % [_jogador.estado, Vector2(v.x, v.z).length()]
	text = txt
