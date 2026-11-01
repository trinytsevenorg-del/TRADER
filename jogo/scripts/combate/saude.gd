extends Node
class_name Saude
## Vida de um personagem (jogador, bot, boneco de treino).
## O dono pode ter a variável "invencivel" (rolamento): o dano é ignorado.

signal dano_recebido(quantidade: float, atacante: Node, ponto: Vector3, cabeca: bool)
signal morreu(atacante: Node)
signal curado

@export var vida_max := 100.0
var vida := 100.0
var morto := false


func _ready() -> void:
	vida = vida_max


## Devolve o dano realmente aplicado (0 se invencível ou já morto).
func receber_dano(quantidade: float, atacante: Node, ponto: Vector3, cabeca: bool) -> float:
	if morto:
		return 0.0
	var dono := get_parent()
	if dono and dono.get("invencivel") == true:
		return 0.0
	var aplicado: float = min(quantidade, vida)
	vida -= aplicado
	dano_recebido.emit(aplicado, atacante, ponto, cabeca)
	if vida <= 0.0:
		morto = true
		morreu.emit(atacante)
	return aplicado


func reviver() -> void:
	vida = vida_max
	morto = false
	curado.emit()
