extends CharacterBody3D
## Boneco de treino: alvo humano com vida, que morre e reaparece.
## Opcionalmente anda de um lado para o outro (para treinar mira em movimento).
## Fica no grupo "alvos": o aim assist e o tiro automático enxergam ele.

@export var movel := false
@export var distancia_movimento := 4.0
@export var velocidade := 3.0
@export var personagem := 0      ## 0 masculino, 1 feminino
@export var skin := 4
@export var tempo_reaparecer := 2.5

var _origem := Vector3.ZERO
var _fase := 0.0
var _modelo: Node3D
var _morto_ha := 0.0

@onready var saude: Saude = $Saude
@onready var _barra: Label3D = $Barra


func _ready() -> void:
	add_to_group("alvos")
	_origem = global_position
	_fase = randf() * TAU
	var caminho: String = Jogador.MODELOS[personagem]
	_modelo = load(caminho).instantiate()
	_modelo.skin = skin
	add_child(_modelo)
	saude.dano_recebido.connect(_ao_receber_dano)
	saude.morreu.connect(_ao_morrer)
	_atualizar_barra()


func receber_dano(quantidade: float, atacante: Node, ponto: Vector3, cabeca: bool) -> float:
	return saude.receber_dano(quantidade, atacante, ponto, cabeca)


func esta_morto() -> bool:
	return saude.morto


func _ao_receber_dano(qtd: float, _atacante: Node, ponto: Vector3, cabeca: bool) -> void:
	Efeitos.numero(ponto, qtd, cabeca, saude.morto)
	_atualizar_barra()


func _ao_morrer(_atacante: Node) -> void:
	_morto_ha = 0.0
	collision_layer = 0  # tiros atravessam o corpo caído
	_barra.visible = false


func _atualizar_barra() -> void:
	var partes := int(ceil(saude.vida / saude.vida_max * 10.0))
	_barra.text = "■".repeat(partes) + "□".repeat(10 - partes)
	_barra.modulate = Color(0.3, 1, 0.3).lerp(Color(1, 0.25, 0.2), 1.0 - saude.vida / saude.vida_max)


func _process(_delta: float) -> void:
	# Na luneta (FOV pequeno) a barra ficaria enorme: esconde.
	var cam := get_viewport().get_camera_3d()
	_barra.visible = not saude.morto and (cam == null or cam.fov > 35.0)


func _physics_process(delta: float) -> void:
	if saude.morto:
		_modelo.atualizar_animacao(&"morto", 0.0, false)
		_morto_ha += delta
		if _morto_ha > tempo_reaparecer:
			saude.reviver()
			collision_layer = 2
			_barra.visible = true
			_atualizar_barra()
			global_position = _origem
		return
	var vel_h := 0.0
	if movel:
		_fase += delta * velocidade / distancia_movimento
		var lado := Vector3.RIGHT * sin(_fase) * distancia_movimento
		var antes := global_position
		global_position = _origem + lado
		var mov := (global_position - antes) / delta
		vel_h = mov.length()
		if vel_h > 0.1:
			_modelo.rotation.y = atan2(-mov.x, -mov.z)
	_modelo.atualizar_animacao(&"correndo" if vel_h > 0.5 else &"parado", vel_h / 7.5, false)
