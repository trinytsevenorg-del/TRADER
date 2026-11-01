extends Node
class_name SincronizadorPersonagem
## Mostra um personagem REMOTO de forma suave.
##
## Os estados chegam ~20 vezes por segundo (e às vezes atrasados ou fora de ordem).
## Guardamos os últimos e desenhamos o personagem ATRASO segundos "no passado",
## interpolando entre os dois estados em volta desse instante. Se faltar pacote,
## extrapolamos um pouco com a velocidade (até 0,25 s).

const ATRASO := 0.1

var _dono: Jogador
var _buffer: Array = []   # [{t, pos, vel, yaw, pitch, estado, vel_h, mirando}]
var _relogio := 0.0


func _ready() -> void:
	_dono = get_parent() as Jogador


func receber(t: float, pos: Vector3, vel: Vector3, yaw: float, pitch: float, estado: StringName, vel_h: float, mirando: bool) -> void:
	# Relógio local acompanha o do remetente (o primeiro estado sincroniza).
	if _buffer.is_empty():
		_relogio = t
	if not _buffer.is_empty() and t <= _buffer[-1].t:
		return  # pacote velho/duplicado
	_buffer.append({"t": t, "pos": pos, "vel": vel, "yaw": yaw, "pitch": pitch, "estado": estado,
		"vel_h": vel_h, "mirando": mirando})
	if _buffer.size() > 30:
		_buffer.pop_front()
	# Se o relógio ficou muito para trás/frente (rede travou), reajusta.
	if abs(_relogio - t) > 0.5:
		_relogio = t


func _physics_process(delta: float) -> void:
	if _buffer.is_empty() or _dono == null:
		return
	_relogio += delta
	var alvo_t := _relogio - ATRASO
	# Acha os dois estados em volta do instante desejado
	var a: Dictionary = _buffer[0]
	var b: Dictionary = _buffer[0]
	for i in _buffer.size():
		if _buffer[i].t <= alvo_t:
			a = _buffer[i]
			b = _buffer[min(i + 1, _buffer.size() - 1)]
	var pos: Vector3
	var yaw: float
	if a == b:
		# Sem estado mais novo: extrapola um pouco
		var extra := clampf(alvo_t - a.t, 0.0, 0.25)
		pos = a.pos + a.vel * extra
		yaw = a.yaw
	else:
		var k := clampf((alvo_t - a.t) / maxf(b.t - a.t, 0.001), 0.0, 1.0)
		pos = a.pos.lerp(b.pos, k)
		yaw = lerp_angle(a.yaw, b.yaw, k)
	_dono.global_position = pos
	_dono.visual.rotation.y = yaw
	_dono.pitch_mira = b.pitch
	_dono.yaw_mira = yaw
	_dono.estado_remoto = b.estado
	_dono.vel_remota = b.vel_h
	_dono.mirando_remoto = b.mirando
	# Descarta estados muito antigos
	while _buffer.size() > 2 and _buffer[1].t < alvo_t - 0.5:
		_buffer.pop_front()


func limpar() -> void:
	_buffer.clear()
