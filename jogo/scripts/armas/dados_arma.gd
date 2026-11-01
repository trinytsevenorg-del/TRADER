extends Resource
class_name DadosArma
## Todos os números de UMA arma. Cada arma tem seu arquivo em data/armas/*.tres:
## abra no Inspetor da Godot e ajuste à vontade, sem mexer em código.
##
## Unidades: distâncias em metros, ângulos em graus, tempos em segundos.

enum Modo { SEMI, RAJADA, AUTO }
enum Categoria { PISTOLA, SUBMETRALHADORA, FUZIL, ESCOPETA, METRALHADORA, SNIPER }

@export_group("Identidade")
@export var id := ""
@export var nome := ""
@export var categoria: Categoria = Categoria.FUZIL
## Texto curto mostrado no inventário (vantagem / fraqueza).
@export_multiline var descricao := ""
## Cena do modelo 3D (weapons/modelos/*.tscn) com os pontos Mao, Cano e Mira.
@export var cena_modelo: PackedScene

@export_group("Disparo")
@export var modo: Modo = Modo.AUTO
## Tiros por minuto (dentro da rajada, no caso de RAJADA).
@export var cadencia := 600.0
@export var tiros_por_rajada := 3
## Pausa depois de cada rajada.
@export var pausa_rajada := 0.3
## Projéteis por tiro (escopetas > 1).
@export var projeteis := 1
## Snipers: segurar ATIRAR abre a luneta e o tiro sai ao SOLTAR.
@export var atira_ao_soltar := false

@export_group("Dano")
@export var dano := 25.0
@export var mult_cabeca := 1.7
## Até esta distância o dano é total.
@export var alcance_efetivo := 30.0
## Distância máxima do tiro. Entre o efetivo e o máximo o dano cai até "dano_minimo".
@export var alcance_maximo := 70.0
## Fração do dano no alcance máximo (0.5 = metade).
@export var dano_minimo := 0.5

@export_group("Precisão")
## Abertura do cone de tiro parado, em graus.
@export var dispersao_base := 1.5
## Somado quando está correndo (proporcional à velocidade).
@export var dispersao_movendo := 2.0
## Somado no ar / parede / rolamento.
@export var dispersao_ar := 3.0
## Cada tiro abre mais a mira ("bloom")...
@export var dispersao_por_tiro := 0.3
## ...até este limite extra...
@export var dispersao_extra_max := 6.0
## ...e fecha de volta nesta velocidade (graus por segundo).
@export var recuperacao_dispersao := 10.0
## Multiplicador da dispersão mirando (botão MIRA ou zoom da arma).
@export var mult_dispersao_mirando := 0.5

@export_group("Recuo")
## Quanto a câmera sobe por tiro (graus).
@export var recuo_vertical := 1.0
## Variação lateral por tiro (graus, para os dois lados).
@export var recuo_horizontal := 0.4

@export_group("Munição")
@export var pente := 30
@export var reserva := 120
@export var tempo_recarga := 2.0
@export var tempo_equipar := 0.45

@export_group("Mira e movimento")
## 1.0 = não aproxima ao atirar. 1.2–1.5 = aproximação leve (alguns fuzis).
## 2.5+ = luneta (tela de luneta aparece).
@export var zoom := 1.0
## Multiplicador da velocidade de corrida segurando esta arma.
@export var mult_velocidade := 1.0

@export_group("Visual")
@export var cor_rastro := Color(1.0, 0.85, 0.4)


func intervalo() -> float:
	return 60.0 / max(cadencia, 1.0)


func tem_luneta() -> bool:
	return zoom >= 2.5


## Dano depois da queda por distância (sem contar cabeça).
func dano_na_distancia(dist: float) -> float:
	if dist <= alcance_efetivo:
		return dano
	var t: float = clamp((dist - alcance_efetivo) / max(alcance_maximo - alcance_efetivo, 0.01), 0.0, 1.0)
	return dano * lerpf(1.0, dano_minimo, t)
