extends Node
## Progressão do jogador, salva no celular (user://progresso.save):
## nível, XP, moedas (só moeda do jogo), caixas, giros da roleta, skins de arma
## e de personagem desbloqueadas e equipadas, estatísticas.
## Autoload "Progresso".

signal mudou

const CAMINHO := "user://progresso.save"
const PRECO_CAIXA := 400

## Chances das raridades nas caixas (mostradas na tela; somam 100).
const CHANCES_CAIXA := {"comum": 60.0, "rara": 27.0, "epica": 10.0, "lendaria": 3.0}
## Item repetido vira moedas, conforme a raridade.
const MOEDAS_REPETIDA := {"comum": 40, "rara": 120, "epica": 350, "lendaria": 1000}

## Prêmios da roleta (peso = chance em %). Mostrados na tela da roleta.
const ROLETA := [
	{"id": "moedas_100", "texto": "100 moedas", "peso": 28.0, "cor": Color(0.85, 0.75, 0.3)},
	{"id": "xp_300", "texto": "300 XP", "peso": 18.0, "cor": Color(0.35, 0.65, 0.95)},
	{"id": "moedas_300", "texto": "300 moedas", "peso": 18.0, "cor": Color(0.95, 0.6, 0.2)},
	{"id": "caixa", "texto": "Caixa de arma", "peso": 14.0, "cor": Color(0.55, 0.4, 0.85)},
	{"id": "skin_personagem", "texto": "Roupa nova", "peso": 10.0, "cor": Color(0.3, 0.75, 0.45)},
	{"id": "xp_800", "texto": "800 XP", "peso": 7.0, "cor": Color(0.2, 0.45, 0.85)},
	{"id": "moedas_1000", "texto": "1000 moedas", "peso": 4.0, "cor": Color(1.0, 0.85, 0.2)},
	{"id": "skin_epica", "texto": "Skin épica+", "peso": 1.0, "cor": Color(0.9, 0.3, 0.5)},
]

var dados := {}


func _ready() -> void:
	_padrao()
	carregar()


func _padrao() -> void:
	dados = {
		"nivel": 1, "xp": 0, "moedas": 300, "caixas": 2, "giros": 1,
		"skins_armas": [],                 # ids de skins de arma que você tem
		"skin_arma_equipada": {},          # id_arma -> id_skin
		"skins_personagem": [0, 1],        # índices de roupa liberados (0-7)
		"abates_total": 0, "vitorias": 0, "partidas": 0,
	}


func salvar() -> void:
	var f := FileAccess.open(CAMINHO, FileAccess.WRITE)
	if f:
		f.store_var(dados)
	mudou.emit()


func carregar() -> void:
	if not FileAccess.file_exists(CAMINHO):
		return
	var f := FileAccess.open(CAMINHO, FileAccess.READ)
	var lido = f.get_var() if f else null
	if lido is Dictionary:
		for k in lido:
			dados[k] = lido[k]


func resetar() -> void:
	_padrao()
	salvar()


# =========================================================================
#  NÍVEL, XP E RECOMPENSAS
# =========================================================================

func xp_para_proximo(nivel: int) -> int:
	return 400 + 150 * (nivel - 1)


## Soma XP; cada nível novo dá 1 caixa + 1 giro. Devolve quantos níveis subiu.
func adicionar_xp(qtd: int) -> int:
	dados.xp += qtd
	var subiu := 0
	while dados.xp >= xp_para_proximo(dados.nivel):
		dados.xp -= xp_para_proximo(dados.nivel)
		dados.nivel += 1
		dados.caixas += 1
		dados.giros += 1
		subiu += 1
	return subiu


## Chamado no fim de cada partida. Devolve o resumo das recompensas.
func registrar_partida(meu: Dictionary, _resultado: Dictionary) -> Dictionary:
	var abates: int = meu.get("abates", 0)
	var venceu: bool = meu.get("posicao", 0) == 1
	var xp := 100 + 50 * abates + (300 if venceu else 0)
	var moedas := 40 + 8 * abates + (100 if venceu else 0)
	var caixas := 1 if venceu else 0
	# A cada 10 abates (somando todas as partidas) ganha um giro na roleta
	var giros := int((dados.abates_total + abates) / 10) - int(dados.abates_total / 10)
	dados.abates_total += abates
	dados.partidas += 1
	if venceu:
		dados.vitorias += 1
	dados.moedas += moedas
	dados.caixas += caixas
	dados.giros += giros
	var nivel_antes: int = dados.nivel
	var subiu := adicionar_xp(xp)
	salvar()
	return {"xp": xp, "moedas": moedas, "caixas": caixas + subiu, "giros": giros + subiu,
		"subiu_nivel": subiu > 0, "nivel": dados.nivel, "nivel_antes": nivel_antes}


# =========================================================================
#  CAIXAS E ROLETA
# =========================================================================

func comprar_caixa() -> bool:
	if dados.moedas < PRECO_CAIXA:
		return false
	dados.moedas -= PRECO_CAIXA
	dados.caixas += 1
	salvar()
	return true


static func sortear_raridade(minima := "comum") -> String:
	var ordem := ["comum", "rara", "epica", "lendaria"]
	var validas := ordem.slice(ordem.find(minima))
	var total := 0.0
	for r in validas:
		total += CHANCES_CAIXA[r]
	var x := randf() * total
	for r in validas:
		x -= CHANCES_CAIXA[r]
		if x <= 0.0:
			return r
	return validas[-1]


## Abre uma caixa: sorteia raridade e depois uma skin dessa raridade.
## Repetida vira moedas. Devolve {skin: DadosSkinArma, repetida, moedas}.
func abrir_caixa(minima := "comum") -> Dictionary:
	if dados.caixas <= 0 and minima == "comum":
		return {}
	if minima == "comum":
		dados.caixas -= 1
	var rar := sortear_raridade(minima)
	var opcoes := CatalogoSkins.da_raridade(rar)
	var skin: DadosSkinArma = opcoes[randi() % opcoes.size()]
	var repetida: bool = dados.skins_armas.has(skin.id)
	var moedas := 0
	if repetida:
		moedas = MOEDAS_REPETIDA[rar]
		dados.moedas += moedas
	else:
		dados.skins_armas.append(skin.id)
	salvar()
	return {"skin": skin, "repetida": repetida, "moedas": moedas}


## Sorteia um prêmio da roleta (índice em ROLETA) e já aplica.
func girar_roleta() -> Dictionary:
	if dados.giros <= 0:
		return {}
	dados.giros -= 1
	var total := 0.0
	for p in ROLETA:
		total += p.peso
	var x := randf() * total
	var indice := 0
	for i in ROLETA.size():
		x -= ROLETA[i].peso
		if x <= 0.0:
			indice = i
			break
	var premio: Dictionary = ROLETA[indice]
	var extra := {}
	match premio.id:
		"moedas_100": dados.moedas += 100
		"moedas_300": dados.moedas += 300
		"moedas_1000": dados.moedas += 1000
		"xp_300": extra["niveis"] = adicionar_xp(300)
		"xp_800": extra["niveis"] = adicionar_xp(800)
		"caixa": dados.caixas += 1
		"skin_personagem":
			var faltam := []
			for i in 8:
				if not dados.skins_personagem.has(i):
					faltam.append(i)
			if faltam.is_empty():
				dados.moedas += 300
				extra["convertido"] = 300
			else:
				var s: int = faltam[randi() % faltam.size()]
				dados.skins_personagem.append(s)
				extra["skin_personagem"] = s
		"skin_epica":
			salvar()
			extra["caixa"] = abrir_caixa("epica")
	salvar()
	return {"indice": indice, "premio": premio, "extra": extra}


# =========================================================================
#  SKINS
# =========================================================================

func tem_skin_arma(id_skin: String) -> bool:
	return dados.skins_armas.has(id_skin)


func equipar_skin_arma(id_arma: String, id_skin: String) -> void:
	if id_skin == "":
		dados.skin_arma_equipada.erase(id_arma)
	elif tem_skin_arma(id_skin):
		dados.skin_arma_equipada[id_arma] = id_skin
	salvar()


func skin_equipada(id_arma: String) -> DadosSkinArma:
	var id: String = dados.skin_arma_equipada.get(id_arma, "")
	return CatalogoSkins.carregar(id) if id != "" else null


func tem_skin_personagem(i: int) -> bool:
	return dados.skins_personagem.has(i)
