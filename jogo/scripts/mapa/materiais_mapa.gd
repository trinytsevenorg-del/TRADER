@tool
class_name MateriaisMapa
## Materiais do mapa, compartilhados (cache): mesma textura + mesma cor = mesmo
## material = pode ser mesclado num só draw call.
##
## Cada material tem duas versões:
##  - "editor": textura projetada no mundo (triplanar) para ver certo no editor;
##  - "jogo":   UV já calculado na mesclagem (1 leitura de textura, mais leve no
##              celular) + cor de vértice usada como sombra de contato (AO falso).

const TEXTURAS := {
	"reboco": "res://assets/map/texturas/reboco.png",
	"concreto": "res://assets/map/texturas/concreto.png",
	"chao_rua": "res://assets/map/texturas/chao_rua.png",
	"zinco": "res://assets/map/texturas/zinco.png",
	"madeira": "res://assets/map/texturas/madeira.png",
	"mosaico": "res://assets/map/texturas/mosaico.png",
	"toldo": "res://assets/map/texturas/toldo.png",
	"liso": "",
}
## Quantos metros cada repetição da textura ocupa.
const ESCALA := {
	"reboco": 3.0, "concreto": 2.5, "chao_rua": 4.0, "zinco": 2.0,
	"madeira": 1.0, "mosaico": 3.0, "toldo": 1.5, "liso": 1.0,
}

static var _editor := {}
static var _jogo := {}


static func obter(tipo: String, cor: Color = Color.WHITE) -> StandardMaterial3D:
	var chave := "%s|%s" % [tipo, cor.to_html()]
	if _editor.has(chave):
		return _editor[chave]
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 0.9 if tipo != "zinco" else 0.55
	m.metallic = 0.25 if tipo == "zinco" else 0.0
	var caminho: String = TEXTURAS.get(tipo, "")
	if caminho != "" and ResourceLoader.exists(caminho):
		m.albedo_texture = load(caminho)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE / float(ESCALA.get(tipo, 2.0))
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.set_meta("tipo", tipo)
	_editor[chave] = m
	return m


## Versão leve para o jogo (usada pelo Mesclador).
static func versao_jogo(m: Material) -> Material:
	if not (m is StandardMaterial3D):
		return m
	if _jogo.has(m):
		return _jogo[m]
	var j: StandardMaterial3D = m.duplicate()
	j.uv1_triplanar = false
	j.uv1_world_triplanar = false
	j.uv1_scale = Vector3.ONE
	j.vertex_color_use_as_albedo = true
	_jogo[m] = j
	return j


static func escala_de(m: Material) -> float:
	if m and m.has_meta("tipo"):
		return float(ESCALA.get(m.get_meta("tipo"), 2.0))
	return 2.0
