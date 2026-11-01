@tool
extends PecaMapa
## Fonte octogonal no centro da praça: mureta baixa (cobertura), água e coluna.

@export var raio := 2.6
@export var cor := Color(0.88, 0.84, 0.76)


func _construir() -> void:
	var pedra := MateriaisMapa.obter("concreto", cor)
	var agua := MateriaisMapa.obter("liso", Color(0.25, 0.55, 0.7))
	var lados := 8
	var aresta := 2.0 * raio * tan(PI / lados)
	for i in lados:
		var a := TAU * i / lados
		var p := Vector3(sin(a), 0, cos(a)) * raio
		caixa(p + Vector3(0, 0.4, 0), Vector3(aresta + 0.05, 0.8, 0.35), pedra, true, Vector3(0, rad_to_deg(a), 0))
	caixa(Vector3(0, 0.3, 0), Vector3(raio * 1.6, 0.05, raio * 1.6), agua, false)
	cilindro(Vector3(0, 0.9, 0), 0.35, 1.8, pedra, 8)
	cilindro(Vector3(0, 1.85, 0), 0.9, 0.15, pedra, 8)
