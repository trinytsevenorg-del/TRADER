@tool
extends PecaMapa
## Bloco genérico (pisos, lajes, plataformas). Origem = centro da base.

@export var tamanho := Vector3(4, 0.2, 4)
@export_enum("reboco", "concreto", "chao_rua", "zinco", "madeira", "mosaico", "toldo", "liso") var textura := "concreto"
@export var cor := Color(1, 1, 1)
@export var colisao := true


func _construir() -> void:
	caixa(Vector3(0, tamanho.y * 0.5, 0), tamanho, MateriaisMapa.obter(textura, cor), colisao)
