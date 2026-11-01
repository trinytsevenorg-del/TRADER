extends SceneTree
## Dobra os dedos da mão esquerda em cada eixo e mede o quanto a ponta se aproxima da palma.
var m; var f := 0; var esq: Skeleton3D
func _initialize():
	m = load("res://characters/humano/humano_masculino.tscn").instantiate(); root.add_child(m)
func _process(_d):
	f += 1
	if f == 3:
		esq = m.find_child("Skeleton3D", true, false)
		var mao := esq.find_bone("hand_l")
		for eixo in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			for sinal in [1.0, -1.0]:
				var poses := {}
				for n in ["index_01_l", "index_02_l", "index_03_l"]:
					var i := esq.find_bone(n); poses[i] = esq.get_bone_pose_rotation(i)
					esq.set_bone_pose_rotation(i, poses[i] * Quaternion(eixo, sinal * 0.8))
				var ponta := esq.get_bone_global_pose(esq.find_bone("index_04_leaf_l")).origin
				var palma := esq.get_bone_global_pose(mao)
				# distância da ponta do indicador à "frente da palma" (abaixo da mão)
				print("eixo %s sinal %+d -> ponta a %.3f m do punho; altura relativa %.3f" % [eixo, sinal, ponta.distance_to(palma.origin), (palma.affine_inverse() * ponta).length()])
				for i in poses: esq.set_bone_pose_rotation(i, poses[i])
		var p0 := esq.get_bone_global_pose(esq.find_bone("index_04_leaf_l")).origin
		print("sem dobrar -> ponta a %.3f m do punho" % p0.distance_to(esq.get_bone_global_pose(mao).origin))
		quit()
