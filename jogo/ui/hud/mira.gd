extends Control
## Mira simples no centro da tela (desenhada, sem textura = leve).
## Na etapa 3 ela abre com a dispersão da arma e mostra o acerto.

var abertura := 10.0  ## distância das linhas ao centro (px)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var cor := Color(1, 1, 1, 0.9)
	var sombra := Color(0, 0, 0, 0.5)
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var a: Vector2 = c + d * abertura
		var b: Vector2 = c + d * (abertura + 9.0)
		draw_line(a + Vector2(1, 1), b + Vector2(1, 1), sombra, 3.0)
		draw_line(a, b, cor, 2.0)
	draw_circle(c, 2.0, cor)
