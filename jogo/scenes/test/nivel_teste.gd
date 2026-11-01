extends Node3D
## Pista de testes da ETAPA 1: chão, caixas de várias alturas, rampas,
## escada, muro comprido e plataforma alta. Serve para sentir a aceleração,
## o pulo e a câmera (inclusive a câmera encostando nas paredes).
## O mapa urbano de verdade vem na etapa 4.

func _ready() -> void:
	var chao := Construtor.material_xadrez(Color(0.34, 0.36, 0.38), Color(0.29, 0.31, 0.33), 2.0)
	var concreto := Construtor.material_xadrez(Color(0.62, 0.58, 0.52), Color(0.56, 0.52, 0.47), 1.0)
	var laranja := Construtor.material_xadrez(Color(0.85, 0.42, 0.12), Color(0.76, 0.37, 0.1), 1.0)
	var azul := Construtor.material_xadrez(Color(0.2, 0.4, 0.7), Color(0.17, 0.35, 0.62), 1.0)

	var geo := Node3D.new()
	geo.name = "Geometria"
	add_child(geo)

	# Chão 80x80 m (topo em y = 0).
	Construtor.bloco(geo, Vector3(0, -0.5, 0), Vector3(80, 1, 80), chao)
	# Bordas para não cair do mundo.
	for i in 4:
		var ang := i * PI / 2.0
		var pos := Vector3(0, 1.5, -40.5).rotated(Vector3.UP, ang)
		Construtor.bloco(geo, pos, Vector3(82, 3, 1), concreto, Vector3(0, rad_to_deg(ang), 0))

	# Caixas de alturas diferentes (0.5 m, 1 m, 1.5 m, 2.2 m, 3 m).
	var alturas := [0.5, 1.0, 1.5, 2.2, 3.0]
	for i in alturas.size():
		var h: float = alturas[i]
		Construtor.bloco(geo, Vector3(-12 + i * 3.5, h * 0.5, -8), Vector3(2, h, 2), laranja)

	# Rampa suave subindo até uma plataforma de 4 m.
	Construtor.rampa(geo, Vector3(10, 0, 4), 4, 10, 4, concreto)
	Construtor.bloco(geo, Vector3(10, 2, -10), Vector3(8, 4, 8), concreto)
	# Passarela estreita saindo da plataforma.
	Construtor.bloco(geo, Vector3(0, 3.85, -12), Vector3(12, 0.3, 1.6), azul)
	Construtor.bloco(geo, Vector3(-9, 2, -12), Vector3(6, 4, 6), concreto)

	# Escada: degraus só visuais + rampa invisível como colisão (sobe sem engasgar).
	for d in 10:
		var h := 0.25 * (d + 1)
		Construtor.bloco(geo, Vector3(-20, h * 0.5, 6 - d * 0.5 - 0.25), Vector3(3, h, 0.5), concreto, Vector3.ZERO, false)
	var rampa_escada := Construtor.rampa(geo, Vector3(-20, 0, 6), 3, 5, 2.5, concreto)
	rampa_escada.get_child(1).visible = false  # esconde a malha, mantém a colisão
	Construtor.bloco(geo, Vector3(-20, 1.25, -0.5), Vector3(3, 2.5, 3), concreto)  # patamar

	# Muro comprido e alto (para testar a câmera encostando; wall run na etapa 2).
	Construtor.bloco(geo, Vector3(20, 2.5, 10), Vector3(0.6, 5, 24), azul)
	# Corredor apertado (a câmera tem de encurtar sem atravessar).
	Construtor.bloco(geo, Vector3(-4, 2, 18), Vector3(0.5, 4, 10), concreto)
	Construtor.bloco(geo, Vector3(-1.6, 2, 18), Vector3(0.5, 4, 10), concreto)
	Construtor.bloco(geo, Vector3(-2.8, 4.25, 18), Vector3(2.9, 0.5, 10), concreto)

	# Pilares.
	for i in 6:
		Construtor.bloco(geo, Vector3(-25 + i * 4, 3, 25), Vector3(1, 6, 1), laranja)
