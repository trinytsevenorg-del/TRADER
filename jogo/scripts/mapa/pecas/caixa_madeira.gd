@tool
extends PecaMapa
## Caixote de madeira (cobertura baixa e degrau para escalar). Origem = centro da base.

@export var tamanho := Vector3(1, 1, 1)
@export var cor := Color(1, 1, 1)


func _construir() -> void:
	var m := MateriaisMapa.obter("madeira", cor)
	var reforco := MateriaisMapa.obter("liso", Color(0.35, 0.24, 0.15))
	caixa(Vector3(0, tamanho.y * 0.5, 0), tamanho, m)
	# Reforços nas bordas verticais
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			caixa(Vector3(sx * tamanho.x * 0.48, tamanho.y * 0.5, sz * tamanho.z * 0.48),
				Vector3(0.08, tamanho.y, 0.08), reforco, false, Vector3.ZERO, true)
