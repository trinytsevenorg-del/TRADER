extends SubViewportContainer
class_name Vitrine3D
## Prévia 3D (personagem ou arma) dentro de uma tela de menu.
## Mundo 3D próprio (não interfere no jogo). Arraste para girar.

var _viewport: SubViewport
var _pivo: Node3D
var _camera: Camera3D
var _atual: Node3D
var _arrastando := false
var girar_sozinho := true


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.82)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	amb.environment = env
	_viewport.add_child(amb)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35, 35, 0)
	luz.light_energy = 1.2
	_viewport.add_child(luz)
	var contra := DirectionalLight3D.new()
	contra.rotation_degrees = Vector3(-20, 200, 0)
	contra.light_energy = 0.5
	contra.light_color = Color(1, 0.8, 0.6)
	_viewport.add_child(contra)
	_pivo = Node3D.new()
	_viewport.add_child(_pivo)
	_camera = Camera3D.new()
	_camera.fov = 35
	_viewport.add_child(_camera)


func _limpar() -> void:
	if _atual:
		_atual.queue_free()
		_atual = null


func mostrar_personagem(indice: int, skin: int) -> void:
	_limpar()
	var cena: PackedScene = load(Jogador.MODELOS[indice])
	_atual = cena.instantiate()
	_atual.skin = skin
	_pivo.add_child(_atual)
	_camera.position = Vector3(0, 1.05, 4.2)
	_camera.look_at(Vector3(0, 0.95, 0))


func mostrar_arma(id_arma: String, skin: DadosSkinArma) -> void:
	_limpar()
	var d := CatalogoArmas.carregar(id_arma)
	if d == null:
		return
	var arma: ModeloArma = d.cena_modelo.instantiate()
	_atual = Node3D.new()
	_atual.add_child(arma)
	_pivo.add_child(_atual)
	# Centraliza a arma (de lado) e enquadra pelo comprimento
	arma.rotation.y = PI / 2.0
	var comprimento := absf(arma.get_node("Cano").position.z) + 0.25
	arma.position = Vector3(-comprimento * 0.4, 0, 0)
	if skin:
		arma.aplicar_material(CatalogoSkins.material(skin))
	_camera.position = Vector3(0, 0.12, comprimento * 2.2 + 0.25)
	_camera.look_at(Vector3(0, 0.05, 0))


func _process(delta: float) -> void:
	if girar_sozinho and not _arrastando and _pivo:
		_pivo.rotation.y += delta * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		_arrastando = event.pressed
	elif (event is InputEventMouseMotion and _arrastando) or event is InputEventScreenDrag:
		_pivo.rotation.y += event.relative.x * 0.01
