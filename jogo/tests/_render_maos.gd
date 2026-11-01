extends SceneTree
## Render de diagnóstico: personagem segurando 4 armas, de lado e de frente.
var c; var j; var f := 0; var cam: Camera3D; var armas := ["vespa_p9", "corisco_ar", "bigorna_lmg", "agulha_sr"]; var i := 0
var mirar := OS.get_environment("MIRAR") != "0"
func _initialize():
	c = load("res://scenes/test/teste_etapa1.tscn").instantiate(); root.add_child(c)
func _physics_process(_d):
	f += 1
	j = c.get_node("Jogador")
	var cfg = root.get_node("Config")
	if f == 3:
		cfg.definir("mostrar_fps", false); cfg.definir("personagem", 0)
		j.teleportar(Vector3(0, 0.1, 12), 0.0); c.get_node("HUD").visible = false
		cam = Camera3D.new(); c.add_child(cam); cam.fov = 32
	var fase := (f - 5) % 130
	if f < 5 or i >= armas.size():
		if i >= armas.size(): quit()
		return
	if fase == 0:
		cfg.definir("arma_principal", armas[i]); j.camera_rig.pitch = 0.0
	if fase == 70 and mirar: Input.action_press("mirar")
	if fase == 110:
		var b = j.global_position
		cam.global_transform = Transform3D.IDENTITY.translated(b + Vector3(1.9, 1.4, -0.9)).looking_at(b + Vector3(0, 1.25, -0.4)); cam.current = true
	if fase == 118:
		root.get_texture().get_image().save_png("res://../mao_%d_lado.png" % i)
		var b = j.global_position
		cam.global_transform = Transform3D.IDENTITY.translated(b + Vector3(0.5, 1.55, -2.6)).looking_at(b + Vector3(0, 1.3, -0.3))
	if fase == 128:
		root.get_texture().get_image().save_png("res://../mao_%d_frente.png" % i)
		cam.current = false; Input.action_release("mirar"); i += 1
