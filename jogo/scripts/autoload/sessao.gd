extends Node
## Escolhas para a PRÓXIMA partida (preenchidas pelo menu) e o resultado da última.
## Autoload "Sessao".

enum TipoRede { SOLO, HOST, CLIENTE }

var mapa := "res://scenes/mapas/vila_telhado.tscn"
var dificuldade := 1                 # 0 fácil, 1 médio, 2 difícil
var total_participantes := 5         # jogadores + bots
var abates_para_vencer := 20
var duracao_segundos := 480.0        # 8 minutos
var tipo_rede: TipoRede = TipoRede.SOLO
var resultado_ultima := {}

const NOMES_BOTS := ["Raposa", "Trovão", "Faísca", "Corvo", "Lince", "Brasa", "Neblina",
	"Vespa", "Granito", "Coruja", "Cometa", "Sombra"]
