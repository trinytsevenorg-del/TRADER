extends Node
## Configurações do jogador: sensibilidade, aim assist, qualidade gráfica etc.
## É um "autoload" (singleton): qualquer script acessa com Config.obter("chave").
## Fica salvo em user://config.cfg (no Android, na pasta privada do app).

signal alterado(chave: String, valor)

const CAMINHO := "user://config.cfg"
## Nomes das skins de personagem (mesma ordem de texturas_skin nas cenas humanas).
const NOMES_SKINS := [
	"Tático (pele escura)", "Tático (pele clara)",
	"Urbano (pele escura)", "Urbano (pele clara)",
	"Noturno (pele escura)", "Noturno (pele clara)",
	"Deserto (pele escura)", "Deserto (pele clara)",
]

## Valores padrão. Para criar uma opção nova, basta adicionar aqui.
var valores := {
	"sens_toque": 1.0,       # multiplicador ao arrastar o dedo para mirar
	"sens_mouse": 1.0,       # multiplicador do mouse (testes no PC)
	"sens_mira": 0.6,        # multiplicador extra ao mirar / usar luneta
	"inverter_y": false,
	"aim_assist": 0.5,       # 0 = desligado, 1 = máximo (usado a partir da etapa 3)
	"qualidade": 1,          # 0 = baixa, 1 = média, 2 = alta
	"mostrar_fps": true,
	"forcar_toque": false,   # mostra os controles de toque também no PC
	"personagem": 0,         # 0 = masculino, 1 = feminino
	"skin": 0,               # variação visual do personagem
	"tiro_automatico": false, # atira sozinho quando a mira passa no inimigo (etapa 3)
	"hud": {},               # posições/tamanhos dos botões personalizados
}


func _ready() -> void:
	carregar()
	aplicar_graficos()


func obter(chave: String):
	return valores.get(chave)


## Muda um valor em memória. Chame salvar() quando o menu fechar
## (evita escrever no disco a cada movimento do slider).
func definir(chave: String, valor) -> void:
	valores[chave] = valor
	if chave == "qualidade":
		aplicar_graficos()
	alterado.emit(chave, valor)


func salvar() -> void:
	var arquivo := ConfigFile.new()
	for chave in valores:
		arquivo.set_value("config", chave, valores[chave])
	arquivo.save(CAMINHO)


func carregar() -> void:
	var arquivo := ConfigFile.new()
	if arquivo.load(CAMINHO) != OK:
		return
	for chave in valores:
		valores[chave] = arquivo.get_value("config", chave, valores[chave])


func eh_celular() -> bool:
	return OS.has_feature("mobile")


## Aplica as opções gráficas. A resolução 3D é a maior alavanca de desempenho
## no celular: renderizar a 75% e esticar quase não se nota numa tela pequena.
func aplicar_graficos() -> void:
	var q: int = valores["qualidade"]
	var raiz := get_tree().root
	raiz.scaling_3d_scale = [0.7, 0.85, 1.0][q]
	raiz.msaa_3d = Viewport.MSAA_DISABLED if q < 2 else Viewport.MSAA_2X
	# Física roda a 60 Hz; travar o desenho em 60 FPS evita "tremidas"
	# (cada quadro desenhado corresponde a exatamente um passo de física).
	Engine.max_fps = 60
	# Sombras: desligadas na qualidade baixa.
	for luz in get_tree().get_nodes_in_group("luz_principal"):
		luz.shadow_enabled = q > 0
