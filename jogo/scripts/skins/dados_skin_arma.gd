extends Resource
class_name DadosSkinArma
## Uma skin de arma: SÓ VISUAL (não muda nenhum número da arma).
## Cada skin fica num arquivo em data/skins_armas/<id>.tres (edite no Inspetor).

enum Padrao { LISO, LISTRAS, CAMUFLAGEM, DIGITAL, GRADIENTE, BRILHO }

@export var id := ""
@export var nome := ""
## Arma a que a skin pertence (id do CatalogoArmas).
@export var arma := ""
@export_enum("comum", "rara", "epica", "lendaria") var raridade := "comum"
@export var padrao: Padrao = Padrao.LISO
@export var cor_a := Color(0.3, 0.3, 0.3)
@export var cor_b := Color(0.15, 0.15, 0.15)
@export_range(0.0, 1.0) var metalico := 0.3
@export_range(0.0, 1.0) var rugosidade := 0.5
## Brilho próprio (lendárias): cor_b brilha.
@export var emissao := 0.0

@export_group("Detalhes (partes de metal)")
## Cor e acabamento das partes secundárias (metal, ferragens, cano).
@export var cor_detalhe := Color(0.14, 0.14, 0.15)
@export_range(0.0, 1.0) var metalico_detalhe := 0.5
@export_range(0.0, 1.0) var rugosidade_detalhe := 0.4

@export_group("Personalizado (opcional)")
## Textura própria do corpo (ex.: pintura feita no Krita/Photoshop). Substitui o padrão.
@export var textura_albedo: Texture2D
## Materiais próprios completos (ex.: um ShaderMaterial). Substituem tudo acima.
@export var material_principal: Material
@export var material_secundario: Material


static func cor_raridade(r: String) -> Color:
	match r:
		"rara": return Color(0.3, 0.6, 1.0)
		"epica": return Color(0.75, 0.35, 1.0)
		"lendaria": return Color(1.0, 0.7, 0.15)
	return Color(0.75, 0.75, 0.75)


static func nome_raridade(r: String) -> String:
	return {"comum": "Comum", "rara": "Rara", "epica": "Épica", "lendaria": "Lendária"}.get(r, r)
