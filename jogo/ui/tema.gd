class_name Tema
## Tema visual das telas (cores quentes do jogo, botões grandes para o dedo).

const COR_FUNDO := Color(0.08, 0.09, 0.12, 0.88)
const COR_PAINEL := Color(0.12, 0.13, 0.17, 0.92)
const COR_DESTAQUE := Color(1.0, 0.62, 0.18)
const COR_TEXTO := Color(0.96, 0.95, 0.92)
const COR_SUAVE := Color(0.7, 0.72, 0.78)

static var _tema: Theme


static func obter() -> Theme:
	if _tema:
		return _tema
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", COR_TEXTO)
	t.set_color("font_color", "Button", COR_TEXTO)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color(0.1, 0.1, 0.1))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.55))
	t.set_stylebox("normal", "Button", _caixa(Color(0.2, 0.22, 0.28), 10))
	t.set_stylebox("hover", "Button", _caixa(Color(0.27, 0.29, 0.36), 10))
	t.set_stylebox("pressed", "Button", _caixa(COR_DESTAQUE, 10))
	t.set_stylebox("disabled", "Button", _caixa(Color(0.16, 0.16, 0.2), 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", _caixa(COR_PAINEL, 14, 14))
	t.set_stylebox("panel", "Panel", _caixa(COR_PAINEL, 14))
	t.set_stylebox("background", "ProgressBar", _caixa(Color(0.05, 0.05, 0.07), 6, 0))
	t.set_stylebox("fill", "ProgressBar", _caixa(COR_DESTAQUE, 6, 0))
	_tema = t
	return t


static func _caixa(cor: Color, raio: int, margem := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.set_corner_radius_all(raio)
	s.content_margin_left = margem
	s.content_margin_right = margem
	s.content_margin_top = margem * 0.6
	s.content_margin_bottom = margem * 0.6
	return s


## Botão grande padrão.
static func botao(texto: String, acao: Callable, tamanho := Vector2(0, 64), fonte := 24) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = tamanho
	b.add_theme_font_size_override("font_size", fonte)
	b.pressed.connect(acao)
	return b


static func rotulo(texto: String, tam := 22, cor := COR_TEXTO) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	return l


## Moldura colorida por raridade.
static func caixa_raridade(rar: String, preenchido := false) -> StyleBoxFlat:
	var c := DadosSkinArma.cor_raridade(rar)
	var s := _caixa(c.darkened(0.55) if preenchido else Color(0.14, 0.15, 0.2), 10)
	s.border_color = c
	s.set_border_width_all(3)
	return s
