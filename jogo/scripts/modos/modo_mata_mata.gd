extends Node
class_name ModoMataMata
## Modo mata-mata (todos contra todos):
##  - vence quem fizer "abates_para_vencer" (20) primeiro,
##  - ou quem tiver mais abates quando o tempo (8 min) acabar.
## Renascimento depois de 3 s no ponto mais longe dos inimigos.
##
## Na rede (etapa 8) só o HOST roda as regras; os outros recebem o placar.

signal abate(matador: String, vitima: String, arma: String, cabeca: bool)
signal placar_mudou
signal partida_terminou(resultado: Dictionary)

@export var abates_para_vencer := 20
@export var duracao := 480.0
@export var espera_renascer := 3.0

var participantes: Array = []    # [{no, nome, abates, mortes, bot, id}]
var tempo_restante := 480.0
var terminou := false
var mapa: Mapa
## false nos clientes da rede: eles só exibem o que o host manda.
var autoridade := true


func iniciar() -> void:
	tempo_restante = duracao
	terminou = false


func adicionar(no: Jogador, nome: String, bot: bool, id := -1) -> Dictionary:
	no.nome_exibicao = nome
	no.add_to_group("participantes")
	no.add_to_group("alvos")
	var p := {"no": no, "nome": nome, "abates": 0, "mortes": 0, "bot": bot, "id": id, "ultimo_cabeca": false}
	participantes.append(p)
	no.saude.dano_recebido.connect(func(_q, _a, _pt, cabeca): p.ultimo_cabeca = cabeca)
	no.morreu.connect(func(atacante): _ao_morrer(p, atacante))
	placar_mudou.emit()
	return p


func remover(no: Jogador) -> void:
	for p in participantes:
		if p.no == no:
			participantes.erase(p)
			break
	placar_mudou.emit()


func dados_de(no: Node) -> Dictionary:
	for p in participantes:
		if p.no == no:
			return p
	return {}


func _process(delta: float) -> void:
	if terminou or not autoridade:
		return
	tempo_restante -= delta
	if tempo_restante <= 0.0:
		tempo_restante = 0.0
		_terminar()


func _ao_morrer(vitima: Dictionary, atacante: Node) -> void:
	if terminou or not autoridade:
		return
	vitima.mortes += 1
	var matador := dados_de(atacante)
	var nome_arma := ""
	if not matador.is_empty() and matador.no != vitima.no:
		matador.abates += 1
		var a: DadosArma = matador.no.armas.arma()
		nome_arma = a.nome if a else ""
	abate.emit(matador.get("nome", "Queda"), vitima.nome, nome_arma, vitima.ultimo_cabeca)
	placar_mudou.emit()
	if not matador.is_empty() and matador.abates >= abates_para_vencer:
		_terminar()
		return
	get_tree().create_timer(espera_renascer).timeout.connect(func(): _renascer(vitima))


func _renascer(p: Dictionary) -> void:
	if terminou or not is_instance_valid(p.no):
		return
	var inimigos := []
	for o in participantes:
		if o != p and not o.no.esta_morto():
			inimigos.append(o.no.global_position)
	var ponto := mapa.escolher_renascimento(inimigos)
	p.no.renascer(ponto.global_position + Vector3.UP * 0.1, ponto.global_rotation.y)


## Coloca todo mundo no mapa no começo, cada um longe dos outros.
func posicionar_todos() -> void:
	var usados := []
	for p in participantes:
		var ponto := mapa.escolher_renascimento(usados)
		usados.append(ponto.global_position)
		p.no.renascer(ponto.global_position + Vector3.UP * 0.1, ponto.global_rotation.y)


func classificacao() -> Array:
	var c := participantes.duplicate()
	c.sort_custom(func(a, b): return a.abates > b.abates or (a.abates == b.abates and a.mortes < b.mortes))
	return c


func _terminar() -> void:
	if terminou:
		return
	terminou = true
	var ordem := classificacao()
	var res := {"vencedor": ordem[0].nome if not ordem.is_empty() else "", "tabela": []}
	for i in ordem.size():
		var p: Dictionary = ordem[i]
		res.tabela.append({"nome": p.nome, "abates": p.abates, "mortes": p.mortes, "bot": p.bot, "posicao": i + 1,
			"local": p.no.controlado_localmente})
	partida_terminou.emit(res)
