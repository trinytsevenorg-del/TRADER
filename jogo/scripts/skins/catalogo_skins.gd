class_name CatalogoSkins
## Encontra as skins de arma (data/skins_armas/<arma>_<n>.tres) e cria os materiais.
## Para criar uma skin nova: duplique um .tres, mude id/nome/cores e numere em
## sequência (ex.: corisco_ar_5.tres). Ela aparece sozinha nas caixas e no inventário.

const MAX_POR_ARMA := 12

static var _cache := {}
static var _por_arma := {}
static var _materiais := {}


static func carregar(id: String) -> DadosSkinArma:
	if id == "":
		return null
	if not _cache.has(id):
		var c := "res://data/skins_armas/%s.tres" % id
		_cache[id] = load(c) if ResourceLoader.exists(c) else null
	return _cache[id]


static func da_arma(id_arma: String) -> Array:
	if not _por_arma.has(id_arma):
		var r := []
		for n in range(1, MAX_POR_ARMA + 1):
			var s := carregar("%s_%d" % [id_arma, n])
			if s:
				r.append(s)
		_por_arma[id_arma] = r
	return _por_arma[id_arma]


static func todas() -> Array:
	var r := []
	for a in CatalogoArmas.todas():
		r.append_array(da_arma(a))
	return r


static func da_raridade(rar: String) -> Array:
	return todas().filter(func(s): return s.raridade == rar)


## Material da skin (com textura gerada pelo padrão). Reaproveitado (cache).
static func material(s: DadosSkinArma) -> StandardMaterial3D:
	if s == null:
		return null
	if _materiais.has(s.id):
		return _materiais[s.id]
	var m := StandardMaterial3D.new()
	m.metallic = s.metalico
	m.roughness = s.rugosidade
	m.albedo_texture = _textura(s)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 6.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if s.emissao > 0.0:
		m.emission_enabled = true
		m.emission = s.cor_b
		m.emission_energy_multiplier = s.emissao
		m.emission_texture = m.albedo_texture
	_materiais[s.id] = m
	return m


static func _textura(s: DadosSkinArma) -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(s.id)
	match s.padrao:
		DadosSkinArma.Padrao.LISO:
			img.fill(s.cor_a)
		DadosSkinArma.Padrao.LISTRAS:
			for y in n:
				for x in n:
					img.set_pixel(x, y, s.cor_a if ((x + y) / 8) % 2 == 0 else s.cor_b)
		DadosSkinArma.Padrao.GRADIENTE:
			for y in n:
				for x in n:
					img.set_pixel(x, y, s.cor_a.lerp(s.cor_b, float(y) / n))
		DadosSkinArma.Padrao.DIGITAL:
			for by in n / 8:
				for bx in n / 8:
					var c := s.cor_a if rng.randf() > 0.4 else (s.cor_b if rng.randf() > 0.4 else s.cor_a.lerp(s.cor_b, 0.5))
					img.fill_rect(Rect2i(bx * 8, by * 8, 8, 8), c)
		DadosSkinArma.Padrao.CAMUFLAGEM:
			img.fill(s.cor_a)
			for i in 14:
				var cx := rng.randi_range(0, n)
				var cy := rng.randi_range(0, n)
				var r := rng.randi_range(5, 13)
				var c := s.cor_b if i % 2 == 0 else s.cor_a.lerp(s.cor_b, 0.5).darkened(0.2)
				for y in range(-r, r):
					for x in range(-r, r):
						if x * x + y * y < r * r:
							img.set_pixel(posmod(cx + x, n), posmod(cy + y, n), c)
		DadosSkinArma.Padrao.BRILHO:
			img.fill(s.cor_a)
			for y in n:
				for x in n:
					if (x % 16 < 2) or (y % 16 < 2):
						img.set_pixel(x, y, s.cor_b)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
