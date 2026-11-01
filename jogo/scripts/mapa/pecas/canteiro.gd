@tool
extends PecaMapa
## Canteiro de concreto com arbustos (cobertura baixa). Origem = centro da base.

@export var tamanho := Vector3(2.4, 0.8, 1.0)


func _construir() -> void:
	caixa(Vector3(0, tamanho.y * 0.5, 0), tamanho, MateriaisMapa.obter("concreto", Color(0.78, 0.76, 0.72)))
	var verde := MateriaisMapa.obter("liso", Color(0.3, 0.55, 0.25))
	var n := maxi(1, int(tamanho.x / 0.9))
	for i in n:
		var x := (i + 0.5) / n * tamanho.x - tamanho.x * 0.5
		esfera(Vector3(x, tamanho.y + 0.3, 0), 0.45 + aleatorio(i) * 0.15, verde)
