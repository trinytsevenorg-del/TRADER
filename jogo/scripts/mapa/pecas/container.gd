@tool
extends PecaMapa
## Container de carga (6,1 x 2,6 x 2,44 m), zinco ondulado colorido. Empilhável.
## Origem = centro da base; comprimento ao longo do eixo X.

@export var cor := Color(0.75, 0.25, 0.2)
@export var tamanho := Vector3(6.1, 2.6, 2.44)


func _construir() -> void:
	var m := MateriaisMapa.obter("zinco", cor)
	var borda := MateriaisMapa.obter("liso", cor.darkened(0.35))
	caixa(Vector3(0, tamanho.y * 0.5, 0), tamanho, m)
	# Portas numa ponta (duas barras) e reforços nos cantos
	for z in [-0.4, 0.4]:
		caixa(Vector3(tamanho.x * 0.5 + 0.02, tamanho.y * 0.5, z), Vector3(0.04, tamanho.y - 0.3, 0.08), borda, false)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			caixa(Vector3(sx * (tamanho.x * 0.5 - 0.06), tamanho.y * 0.5, sz * (tamanho.z * 0.5 - 0.06)),
				Vector3(0.14, tamanho.y + 0.02, 0.14), borda, false)
