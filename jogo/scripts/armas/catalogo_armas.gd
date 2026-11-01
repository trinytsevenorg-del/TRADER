class_name CatalogoArmas
## Lista de todas as armas do jogo. Para adicionar uma arma nova:
##   1) crie data/armas/<id>.tres (duplique um existente no editor)
##   2) crie weapons/modelos/<id>.tscn (duplique um existente)
##   3) coloque o id aqui.
## (Lista fixa porque no APK exportado não dá para "listar a pasta" de forma confiável.)

const PRINCIPAIS := [
	"zumbido_mk2", "faisca_r3", "corisco_ar", "falcao_br", "patrulha_dmr",
	"trovao_12", "ciclone_a12", "bigorna_lmg", "agulha_sr", "coruja_sx",
]
const SECUNDARIAS := ["vespa_p9", "rinoceronte_50"]

static var _cache := {}


static func todas() -> Array:
	return PRINCIPAIS + SECUNDARIAS


static func carregar(id: String) -> DadosArma:
	if not _cache.has(id):
		var caminho := "res://data/armas/%s.tres" % id
		_cache[id] = load(caminho) if ResourceLoader.exists(caminho) else null
	return _cache[id]


static func nomes(ids: Array) -> Array:
	var r := []
	for id in ids:
		var d := carregar(id)
		r.append(d.nome if d else id)
	return r
