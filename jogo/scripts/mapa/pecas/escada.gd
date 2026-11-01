@tool
extends PecaMapa
## Escada externa. Começa no chão na origem e sobe "altura" ao longo de -Z
## ("comprimento"). Degraus só visuais + rampa invisível de colisão (sobe liso).
## Tem uma mureta de um lado (lado = 1 direita, -1 esquerda, 0 nenhum).

@export var largura := 1.8
@export var altura := 3.5
@export var comprimento := 5.0
@export var cor := Color(0.82, 0.8, 0.76)
@export var lado_mureta := 1


func _construir() -> void:
	var m := MateriaisMapa.obter("concreto", cor)
	var n := maxi(2, roundi(altura / 0.25))
	var passo := comprimento / n
	for i in n:
		var hd := altura * (i + 1) / n
		caixa(Vector3(0, hd * 0.5, -passo * (i + 0.5)), Vector3(largura, hd, passo), m, false)
	rampa_colisao(Vector3(0, 0, 0.05), Vector3(0, altura, -comprimento), largura)
	# Patamar no topo
	caixa(Vector3(0, altura - 0.1, -comprimento - 0.5), Vector3(largura, 0.2, 1.0), m)
	if lado_mureta != 0:
		var x := lado_mureta * (largura * 0.5 + 0.06)
		var ang := rad_to_deg(atan2(altura, comprimento))
		var hip := sqrt(altura * altura + comprimento * comprimento)
		caixa(Vector3(x, altura * 0.5 + 0.5, -comprimento * 0.5), Vector3(0.12, 0.9, hip), m, true, Vector3(ang, 0, 0))
