@tool
extends PecaMapa
## Muro com capa de concreto. Origem = centro da base; comprimento no eixo X.

@export var tamanho := Vector3(4, 1.1, 0.4)
@export var cor := Color(0.9, 0.85, 0.75)


func _construir() -> void:
	caixa(Vector3(0, tamanho.y * 0.5, 0), tamanho, MateriaisMapa.obter("reboco", cor))
	caixa(Vector3(0, tamanho.y + 0.05, 0), Vector3(tamanho.x + 0.08, 0.1, tamanho.z + 0.08),
		MateriaisMapa.obter("concreto", Color(0.8, 0.78, 0.75)))
