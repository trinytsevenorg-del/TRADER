extends SceneTree
func _aabb(n: Node, xf: Transform3D, acc: Array):
	if n is MeshInstance3D:
		var a: AABB = (xf * n.transform) * n.get_aabb()
		acc[0] = a if acc[0] == null else acc[0].merge(a)
	if n is Node3D:
		for c in n.get_children(): _aabb(c, xf * n.transform if n.get_parent() else xf, acc)
func _initialize():
	var d := DirAccess.open("res://assets/weapons/pacote")
	for f in d.get_files():
		if not f.ends_with(".fbx"): continue
		var c: Node3D = load("res://assets/weapons/pacote/" + f).instantiate()
		var acc := [null]
		for ch in c.get_children(): _aabb(ch, Transform3D.IDENTITY, acc)
		var a: AABB = acc[0]
		var mats := 0
		for mi in c.find_children("*", "MeshInstance3D", true, false): mats += mi.mesh.get_surface_count()
		print("%-22s tam=%s pos=%s superficies=%d" % [f, a.size.snapped(Vector3.ONE*0.01), a.position.snapped(Vector3.ONE*0.01), mats])
		c.free()
	quit()
