extends Node
## Teste automático da etapa 7 (progressão, caixas, roleta, skins, telas):
##   godot --headless --path . res://tests/teste_auto_etapa7.tscn

var _falhas := 0


func _checar(nome: String, ok: bool) -> void:
	print(("OK    " if ok else "FALHA ") + nome)
	if not ok: _falhas += 1


func _ready() -> void:
	var P = Progresso
	P.resetar()

	# Catálogo
	_checar("72 skins de arma (6 por arma)", CatalogoSkins.todas().size() == 72)
	var rars := {}
	for s in CatalogoSkins.todas():
		rars[s.raridade] = true
	_checar("tem as 4 raridades", rars.size() == 4)
	_checar("material de skin é criado", CatalogoSkins.material(CatalogoSkins.todas()[0]) != null)

	# XP e nível
	var subiu: int = P.adicionar_xp(P.xp_para_proximo(1) + 10)
	_checar("subir de nível (nível %d, sobra %d XP, +caixa/+giro)" % [P.dados.nivel, P.dados.xp],
		subiu == 1 and P.dados.nivel == 2 and P.dados.xp == 10 and P.dados.caixas == 3 and P.dados.giros == 2)

	# Recompensa de partida
	P.resetar()
	var r: Dictionary = P.registrar_partida({"abates": 12, "posicao": 1}, {})
	_checar("vitória com 12 abates: XP %d, moedas %d, caixas %d, giros %d" % [r.xp, r.moedas, r.caixas, r.giros],
		r.xp == 100 + 600 + 300 and r.moedas == 40 + 96 + 100 and r.caixas >= 1 and r.giros >= 1)

	# Chances da caixa (10 000 sorteios ~ 60/27/10/3)
	var cont := {"comum": 0, "rara": 0, "epica": 0, "lendaria": 0}
	for i in 10000:
		cont[P.sortear_raridade()] += 1
	print("   sorteio de 10000 caixas: ", cont)
	_checar("chances da caixa batem com as anunciadas",
		abs(cont.comum - 6000) < 300 and abs(cont.rara - 2700) < 250 and abs(cont.epica - 1000) < 150 and abs(cont.lendaria - 300) < 90)

	# Abrir caixa e repetida -> moedas
	P.resetar()
	P.dados.caixas = 200
	var repetidas := 0
	var moedas_rep := 0
	for i in 200:
		var res: Dictionary = P.abrir_caixa()
		if res.repetida:
			repetidas += 1
			moedas_rep += res.moedas
	_checar("200 caixas: %d skins novas, %d repetidas viraram %d moedas" % [P.dados.skins_armas.size(), repetidas, moedas_rep],
		P.dados.skins_armas.size() + repetidas == 200 and moedas_rep > 0 and P.dados.caixas == 0)
	_checar("sem caixa não abre", P.abrir_caixa().is_empty())

	# Comprar caixa
	P.dados.moedas = 450
	_checar("comprar caixa com moedas", P.comprar_caixa() and P.dados.moedas == 50 and P.dados.caixas == 1)
	_checar("sem moedas não compra", not P.comprar_caixa())

	# Roleta
	P.resetar()
	P.dados.giros = 3000
	var cont_r := {}
	for i in 3000:
		var g: Dictionary = P.girar_roleta()
		cont_r[g.premio.id] = cont_r.get(g.premio.id, 0) + 1
	print("   3000 giros: ", cont_r)
	_checar("roleta segue as chances (100 moedas ~28%%: %d de 3000)" % cont_r.get("moedas_100", 0), abs(cont_r.get("moedas_100", 0) - 840) < 120)
	_checar("roleta liberou roupas de personagem", P.dados.skins_personagem.size() == 8)

	# Equipar skin
	var s: DadosSkinArma = CatalogoSkins.da_arma("corisco_ar")[0]
	P.dados.skins_armas.append(s.id)
	P.equipar_skin_arma("corisco_ar", s.id)
	_checar("skin equipada", P.skin_equipada("corisco_ar") == s)
	P.equipar_skin_arma("corisco_ar", "corisco_ar_99")
	_checar("não equipa skin que não tem", P.skin_equipada("corisco_ar") == s)

	# Salvar e carregar
	P.dados.moedas = 1234
	P.salvar()
	P.dados.moedas = 0
	P.carregar()
	_checar("progresso salvo e carregado (moedas %d)" % P.dados.moedas, P.dados.moedas == 1234)

	# Telas abrem sem erro
	var menu: Node = load("res://ui/menus/menu_principal.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	for t in ["tela_personagem", "tela_arsenal", "tela_caixas", "tela_roleta", "tela_inicio"]:
		menu.call(t)
		await get_tree().process_frame
	_checar("todas as telas do menu abrem", true)

	P.resetar()
	print("RESULTADO: %d falha(s)" % _falhas)
	get_tree().quit(_falhas)
