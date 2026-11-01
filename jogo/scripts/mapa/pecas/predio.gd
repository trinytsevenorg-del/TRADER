@tool
extends PecaMapa
## Prédio/casa: paredes pintadas, faixas por andar, janelas, porta, laje no topo,
## parapeito baixo (opcional) e objetos de telhado (caixa d'água, ar-condicionado).
## Origem = centro da base. O topo (telhado) fica em y = altura.

@export var tamanho := Vector3(10, 6, 10)
@export var cor := Color(0.85, 0.45, 0.3)
@export var cor_faixa := Color(0.95, 0.92, 0.85)
@export var janelas := true
@export var porta_na_frente := true      ## porta na face +Z
@export var parapeito := true            ## mureta baixa (0,45 m) em volta do telhado
@export var caixa_dagua := true
@export var ar_condicionado := 2


func _construir() -> void:
	var w := tamanho.x
	var h := tamanho.y
	var d := tamanho.z
	var parede := MateriaisMapa.obter("reboco", cor)
	var faixa := MateriaisMapa.obter("liso", cor_faixa)
	var laje := MateriaisMapa.obter("concreto", Color(0.68, 0.66, 0.63))
	var vidro := MateriaisMapa.obter("liso", Color(0.16, 0.22, 0.28))
	var moldura := MateriaisMapa.obter("liso", cor_faixa.darkened(0.15))

	caixa(Vector3(0, h * 0.5, 0), tamanho, parede)
	# Laje sem sobrar para fora: escadas e passarelas encostam lisinho no telhado.
	caixa(Vector3(0, h + 0.06, 0), Vector3(w, 0.12, d), laje)

	# Faixas por andar (~3 m) e rodapé
	var andares := maxi(1, roundi(h / 3.0))
	var alt_andar := h / andares
	for a in andares:
		var y := a * alt_andar + 0.08 if a == 0 else a * alt_andar
		caixa(Vector3(0, y, 0), Vector3(w + 0.06, 0.16, d + 0.06), faixa, false)

	# Janelas: a cada ~3 m em cada fachada, em cada andar
	if janelas:
		for a in andares:
			var yj := a * alt_andar + alt_andar * 0.55
			for lado in 4:
				var largura_face := w if lado < 2 else d
				var n := maxi(1, int(largura_face / 3.2))
				for i in n:
					var t := (i + 0.5) / n - 0.5
					if a == 0 and porta_na_frente and lado == 0 and i == n / 2:
						continue  # lugar da porta
					var pos: Vector3
					var tam: Vector3
					match lado:
						0: pos = Vector3(t * w, yj, d * 0.5 + 0.03); tam = Vector3(1.0, 1.2, 0.06)
						1: pos = Vector3(t * w, yj, -d * 0.5 - 0.03); tam = Vector3(1.0, 1.2, 0.06)
						2: pos = Vector3(w * 0.5 + 0.03, yj, t * d); tam = Vector3(0.06, 1.2, 1.0)
						_: pos = Vector3(-w * 0.5 - 0.03, yj, t * d); tam = Vector3(0.06, 1.2, 1.0)
					caixa(pos, tam, vidro, false)
					# peitoril
					var p2 := pos - Vector3(0, 0.66, 0)
					caixa(p2, Vector3(tam.x + 0.2 if tam.x > 0.5 else 0.14, 0.08, tam.z + 0.2 if tam.z > 0.5 else 0.14), moldura, false)
	if porta_na_frente:
		caixa(Vector3(0, 1.1, d * 0.5 + 0.04), Vector3(1.2, 2.2, 0.08), MateriaisMapa.obter("madeira", Color(0.75, 0.6, 0.5)), false)

	# Parapeito (dá cobertura no telhado; dá para passar por cima)
	if parapeito:
		var ph := 0.45
		var y := h + 0.12 + ph * 0.5
		caixa(Vector3(0, y, d * 0.5 - 0.1), Vector3(w, ph, 0.2), faixa)
		caixa(Vector3(0, y, -d * 0.5 + 0.1), Vector3(w, ph, 0.2), faixa)
		caixa(Vector3(w * 0.5 - 0.1, y, 0), Vector3(0.2, ph, d - 0.4), faixa)
		caixa(Vector3(-w * 0.5 + 0.1, y, 0), Vector3(0.2, ph, d - 0.4), faixa)

	# Objetos no telhado (cobertura e rotas)
	var topo := h + 0.12
	if caixa_dagua and w > 5 and d > 5:
		var px := (aleatorio(1) - 0.5) * (w - 4)
		var pz := (aleatorio(2) - 0.5) * (d - 4)
		var azul := MateriaisMapa.obter("liso", Color(0.22, 0.42, 0.62))
		caixa(Vector3(px, topo + 0.4, pz), Vector3(1.6, 0.8, 1.6), laje)
		cilindro(Vector3(px, topo + 1.4, pz), 0.75, 1.2, azul, 10)
	for i in ar_condicionado:
		var px := (aleatorio(10 + i) - 0.5) * (w - 2)
		var pz := (aleatorio(20 + i) - 0.5) * (d - 2)
		caixa(Vector3(px, topo + 0.35, pz), Vector3(1.0, 0.7, 0.7), MateriaisMapa.obter("liso", Color(0.82, 0.83, 0.85)), true, Vector3.ZERO, true)
