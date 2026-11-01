extends SceneTree
## Monta weapons/modelos/<id>.tscn a partir de assets/weapons/<id>.fbx (ou .glb):
##  - gira para o cano apontar para -Z (frente) e escala para o comprimento real;
##  - acha os pontos de encaixe pela geometria: Mao (empunhadura), Cano (ponta do
##    cano) e Mira (topo, sobre a empunhadura).
## Uso: godot --headless --path jogo -s res://tools/montar_armas.gd
## Para um modelo novo: coloque o arquivo em assets/weapons/<id>.fbx (cano para +X,
## topo para +Y, origem perto do gatilho) e rode de novo.

const COMPRIMENTO := {  # metros
	"vespa_p9": 0.22, "rinoceronte_50": 0.3, "zumbido_mk2": 0.45, "faisca_r3": 0.62,
	"corisco_ar": 0.88, "falcao_br": 0.7, "patrulha_dmr": 0.98, "trovao_12": 0.98,
	"ciclone_a12": 0.82, "bigorna_lmg": 1.0, "agulha_sr": 1.2, "coruja_sx": 1.12,
}


func _verts(n: Node, xf: Transform3D, saida: PackedVector3Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var m: Mesh = n.mesh
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			for v in arr[Mesh.ARRAY_VERTEX]:
				saida.append(t * v)
	for c in n.get_children():
		_verts(c, t, saida)


func _initialize() -> void:
	for id in COMPRIMENTO:
		var caminho := "res://assets/weapons/%s.fbx" % id
		if not ResourceLoader.exists(caminho):
			caminho = "res://assets/weapons/%s.glb" % id
		if not ResourceLoader.exists(caminho):
			print("sem modelo para ", id); continue
		var cena: PackedScene = load(caminho)
		var inst: Node3D = cena.instantiate()
		var vs := PackedVector3Array()
		_verts(inst, Transform3D.IDENTITY, vs)
		inst.free()
		var mn := Vector3.INF; var mx := -Vector3.INF
		for v in vs:
			mn = mn.min(v); mx = mx.max(v)
		var comp := mx.x - mn.x
		var esc: float = COMPRIMENTO[id] / comp
		# Cano: média dos vértices na ponta (+X)
		var soma := Vector3.ZERO; var n := 0
		for v in vs:
			if v.x > mx.x - comp * 0.03:
				soma += v; n += 1
		var cano_m: Vector3 = soma / float(maxi(n, 1))
		# Empunhadura: vértices mais baixos perto da origem (cabo da arma)
		var soma_g := Vector3.ZERO; var ng := 0
		for v in vs:
			if abs(v.x) < comp * 0.12 and v.y < mn.y + (mx.y - mn.y) * 0.35:
				soma_g += v; ng += 1
		var cabo: Vector3 = soma_g / float(maxi(ng, 1))
		var mao_m := Vector3(cabo.x, lerpf(cabo.y, 0.0, 0.55), 0.0)  # meio do cabo
		var mira_m := Vector3(mao_m.x + comp * 0.08, mx.y, 0.0)
		# Modelo (+X frente) -> arma (-Z frente): gira 90° em Y; escala; empunhadura na origem
		var base := Basis(Vector3.UP, PI / 2.0).scaled(Vector3.ONE * esc)
		var conv := func(p: Vector3) -> Vector3: return base * (p - mao_m)

		var raiz := Node3D.new()
		raiz.name = id.capitalize().replace(" ", "")
		raiz.set_script(load("res://scripts/armas/arma.gd"))
		var modelo: Node3D = cena.instantiate()
		modelo.name = "Modelo"
		modelo.transform = Transform3D(base, base * -mao_m)
		raiz.add_child(modelo)
		modelo.owner = raiz
		for par in [["Mao", Vector3.ZERO], ["Cano", conv.call(cano_m) + Vector3(0, 0, -0.01)], ["Mira", conv.call(mira_m)]]:
			var mk := Marker3D.new()
			mk.name = par[0]
			mk.position = par[1]
			raiz.add_child(mk)
			mk.owner = raiz
		var ps := PackedScene.new()
		ps.pack(raiz)
		ResourceSaver.save(ps, "res://weapons/modelos/%s.tscn" % id)
		print("%-15s escala %.3f  cano %s  mira %s" % [id, esc, conv.call(cano_m).snapped(Vector3.ONE * 0.001), conv.call(mira_m).snapped(Vector3.ONE * 0.001)])
		raiz.free()
	quit()
