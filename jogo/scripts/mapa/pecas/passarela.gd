@tool
extends PecaMapa
## Passarela entre telhados: começa na origem (altura 0 local) e vai até
## "comprimento" em -Z, subindo/descendo "desnivel". Piso de chapa e guarda-corpo
## baixo dos dois lados (dá para pular por cima).

@export var largura := 1.8
@export var comprimento := 6.0
@export var desnivel := 0.0
@export var cor := Color(0.45, 0.47, 0.5)
@export var guarda_corpo := true


func _construir() -> void:
	var chapa := MateriaisMapa.obter("zinco", cor)
	var ferro := MateriaisMapa.obter("liso", cor.darkened(0.3))
	var ang := rad_to_deg(atan2(desnivel, comprimento))
	var hip := sqrt(comprimento * comprimento + desnivel * desnivel)
	var meio := Vector3(0, desnivel * 0.5 - 0.08, -comprimento * 0.5)
	caixa(meio, Vector3(largura, 0.16, hip + 0.4), chapa, true, Vector3(ang, 0, 0))
	if guarda_corpo:
		for s in [-1, 1]:
			var x: float = s * (largura * 0.5 - 0.04)
			caixa(meio + Vector3(x, 0.95, 0), Vector3(0.06, 0.06, hip), ferro, true, Vector3(ang, 0, 0))
			var postes := maxi(2, int(hip / 1.5) + 1)
			for i in postes:
				var t := float(i) / (postes - 1)
				caixa(Vector3(x, desnivel * t + 0.45, -comprimento * t), Vector3(0.06, 0.9, 0.06), ferro, false, Vector3.ZERO, true)
