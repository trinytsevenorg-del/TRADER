@tool
extends PecaMapa
## Quiosque: cabine pequena com telhado de zinco que sobra para os lados
## (dá para subir no telhado). Origem = centro da base.

@export var tamanho := Vector3(3, 2.6, 3)
@export var cor := Color(0.95, 0.75, 0.3)
@export var cor_telhado := Color(0.55, 0.6, 0.62)


func _construir() -> void:
	caixa(Vector3(0, tamanho.y * 0.5, 0), tamanho, MateriaisMapa.obter("reboco", cor))
	caixa(Vector3(0, 1.4, tamanho.z * 0.5 + 0.03), Vector3(tamanho.x * 0.7, 0.9, 0.06), MateriaisMapa.obter("liso", Color(0.16, 0.22, 0.28)), false)
	caixa(Vector3(0, 0.95, tamanho.z * 0.5 + 0.2), Vector3(tamanho.x * 0.8, 0.08, 0.4), MateriaisMapa.obter("madeira", Color.WHITE))
	caixa(Vector3(0, tamanho.y + 0.08, 0), Vector3(tamanho.x + 1.0, 0.12, tamanho.z + 1.0), MateriaisMapa.obter("zinco", cor_telhado), true, Vector3(4, 0, 0))
