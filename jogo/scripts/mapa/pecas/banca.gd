@tool
extends PecaMapa
## Banca de feira: balcão de madeira, 4 postes e toldo listrado inclinado
## (o toldo tem colisão: dá para subir nele). Origem = centro da base; frente = +Z.

@export var largura := 2.4
@export var profundidade := 1.6
@export var cor_toldo := Color(0.85, 0.25, 0.25)


func _construir() -> void:
	var madeira := MateriaisMapa.obter("madeira", Color(1, 1, 1))
	var poste := MateriaisMapa.obter("liso", Color(0.3, 0.3, 0.32))
	caixa(Vector3(0, 0.5, 0.1), Vector3(largura, 1.0, profundidade * 0.6), madeira)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var alt := 2.6 if sz < 0 else 2.2
			caixa(Vector3(sx * largura * 0.48, alt * 0.5, sz * profundidade * 0.48), Vector3(0.07, alt, 0.07), poste, false, Vector3.ZERO, true)
	var ang := rad_to_deg(atan2(0.4, profundidade))
	caixa(Vector3(0, 2.45, 0), Vector3(largura + 0.3, 0.06, profundidade + 0.4), MateriaisMapa.obter("toldo", cor_toldo), false, Vector3(-ang, 0, 0))
	# Colisão do toldo mais GROSSA para baixo (chapa de 6 cm deixa o corpo atravessar ou
	# prender na física); a superfície de cima continua no mesmo lugar.
	var giro := Basis(Vector3.RIGHT, deg_to_rad(-ang))
	var espessura := 0.3
	var cs := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(largura + 0.3, espessura, profundidade + 0.4)
	cs.shape = forma
	cs.transform = Transform3D(giro, Vector3(0, 2.45, 0) - giro.y * (espessura - 0.06) * 0.5)
	_corpo.add_child(cs)
	# Mercadoria (detalhe)
	var cores := [Color(0.9, 0.5, 0.1), Color(0.3, 0.6, 0.2), Color(0.8, 0.2, 0.2)]
	for i in 3:
		caixa(Vector3((i - 1) * largura * 0.3, 1.1, 0.15), Vector3(0.5, 0.2, 0.4), MateriaisMapa.obter("liso", cores[i]), false, Vector3.ZERO, true)
