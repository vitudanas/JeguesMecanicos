extends Node3D
## Cordilheira de verdade em volta do mundo, gerada como malha.
##
## Antes o "anel de montanhas" eram as rochas do nature-megakit escaladas 9x-18x
## (ver changelog 2026-08-02). O problema nao era o tamanho: uma pedra ampliada
## continua com silhueta de pedra — um seixo arredondado, sem cume, sem
## encosta longa, sem base que encontra o chao. Aqui cada montanha e um campo
## de altura proprio: perfil que vai a ZERO na borda (entao encosta no chao sem
## emenda), cume deslocado do centro e ruido de cordilheira por cima.
##
## RNG proprio com semente fixa, mesmo criterio de RuralScatter.gd: nao mexe na
## aleatoriedade de trafego/pedestres e o resultado e sempre o mesmo.

const MOUNTAIN_SHADER := preload("res://shaders/mountain.gdshader")

## Onde o PE da montanha comeca (distancia euclidiana do centro do mundo).
## E o pe, nao o centro: a base de um macico tem quase 100m de raio, entao
## posicionar pelo centro faria a encosta avancar mais de 100m pra dentro e
## engolir as fazendas e o cinturao. Aqui o centro e empurrado pra fora pelo
## proprio raio de cada macico.
@export var foot_radius := 235.0
## Quanto o pe pode recuar ainda mais, sorteado — da profundidade a cordilheira
## em vez de deixar todos os pes na mesma circunferencia.
@export var foot_spread := 55.0
@export var count := 30

@export var radius_min := 45.0
@export var radius_max := 95.0
@export var height_min := 45.0
@export var height_max := 115.0

## Resolucao da malha visual e da malha de colisao. A colisao e mais grossa de
## proposito: o jogador so precisa esbarrar, e um trimesh na resolucao visual
## seria dezenas de milhares de faces por macico.
@export var segments := 34

## Quanto o cume sai do centro da base (0 = cone simetrico, 1 = na borda).
## Montanha com pico centrado le como cone de tapete de festa.
@export var peak_offset := 0.34
## Amplitude do ruido de cordilheira sobre o perfil.
@export var ridge_strength := 0.42
## Amplitude da oitava fina de relevo (fracao da altura do macico).
@export var detail_relief := 0.11

@export var rng_seed := 20260803

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _material: ShaderMaterial

func _ready() -> void:
	_rng.seed = rng_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_octaves = 4
	_noise.frequency = 0.012
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.fractal_octaves = 3
	_detail.frequency = 0.05
	_material = ShaderMaterial.new()
	_material.shader = MOUNTAIN_SHADER

	# Distribuicao por setor: sorteio livre do angulo deixa buraco de horizonte
	# de um lado e amontoado do outro, e o anel deixa de fechar.
	for i in range(count):
		var sector := TAU * (float(i) + _rng.randf_range(0.15, 0.85)) / float(count)
		_build_mountain(sector, i)

## Meia-largura da caixa que a base ocupa (o mesmo valor que _build_mesh usa
## como limite de amostragem).
func _span(radius: float, stretch: Vector2, peak: Vector2) -> float:
	return radius * maxf(stretch.x, stretch.y) * (1.0 + peak.length())

func _build_mountain(sector: float, index: int) -> void:
	var radius := _rng.randf_range(radius_min, radius_max)
	# Macicos maiores sao mais altos, senao sai uma bolha larga e baixa.
	var t := (radius - radius_min) / maxf(radius_max - radius_min, 0.001)
	var height := lerpf(height_min, height_max, t) * _rng.randf_range(0.85, 1.15)
	# Base eliptica + giro: base redonda faz todos os macicos parecerem o mesmo.
	var stretch := Vector2(_rng.randf_range(0.75, 1.35), _rng.randf_range(0.75, 1.35))
	var spin := _rng.randf_range(0.0, TAU)
	var peak := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized() \
		* _rng.randf_range(0.0, peak_offset)
	# Meia-largura REAL da base, ja com o alongamento e o cume deslocado. E ela
	# que tem que ser descontada, nao `radius`: com o alongamento em 1.35 e o
	# cume em 0.34 a base chega a 1.8x o raio nominal, e usar o raio deixava o
	# pe da encosta 90m mais pra dentro do que o planejado — a verificacao pegou
	# ferro-velho e 128 props de natureza dentro da montanha.
	var span := _span(radius, stretch, peak)
	# Centro = pe + meia-base: garante que a encosta nao entra na area util.
	var dist := foot_radius + _rng.randf_range(0.0, foot_spread) + span
	var center := Vector3(cos(sector) * dist, 0.0, sin(sector) * dist)
	# Cada macico amostra o ruido de um canto diferente do dominio, senao todos
	# saem com o MESMO relevo.
	var noise_origin := Vector2(_rng.randf_range(-9000.0, 9000.0), _rng.randf_range(-9000.0, 9000.0))

	var body := StaticBody3D.new()
	body.name = "Macico%d" % index
	body.add_to_group("mountain")
	add_child(body)
	body.position = center

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _build_mesh(segments, radius, height, stretch, spin, peak, noise_origin)
	mesh_inst.material_override = _material
	body.add_child(mesh_inst)

	# Colisao da MESMA malha do desenho, nao de uma versao grosseira.
	#
	# `_build_mesh` descarta o quad que esta inteiramente no chao, entao a borda
	# da malha acompanha o pe da montanha com a precisao do PASSO da grade. Numa
	# grade grosseira (14 segmentos num macico de ~380 m) o passo e ~27 m: sobrava
	# um quad inteiro de colisao alem da encosta visivel, e o jogador batia numa
	# parede invisivel 27 m antes de chegar na montanha. Eram 41 macicos assim —
	# a maior parte do perimetro do mapa.
	#
	# Trimesh estatico dessa resolucao e barato; a economia nao valia o defeito.
	var shape := CollisionShape3D.new()
	shape.shape = mesh_inst.mesh.create_trimesh_shape()
	body.add_child(shape)

## Altura em funcao da posicao na base (coordenadas locais, ja em metros).
## O perfil cai a ZERO na borda do disco: e o que faz o pe da montanha encostar
## no chao sem degrau, o que uma rocha escalada nunca faz.
func _height_at(local: Vector2, radius: float, height: float, stretch: Vector2,
		spin: float, peak: Vector2, noise_origin: Vector2) -> float:
	var p := local.rotated(-spin)
	p.x /= stretch.x
	p.y /= stretch.y
	var d := (p / radius - peak).length() / (1.0 + peak.length())
	if d >= 1.0:
		return 0.0
	# Perfil concavo: encosta que abre na base e afina no cume.
	var profile := pow(1.0 - d, 1.7)
	# Ruido de cordilheira: abs() do simplex cria vinco/aresta em vez de bolha.
	var n := _noise.get_noise_2d(noise_origin.x + local.x, noise_origin.y + local.y)
	var ridge := 1.0 - absf(n)
	var shaped := profile * lerpf(1.0, ridge, ridge_strength)
	# Oitava fina: sulcos e esporoes na encosta. Sem ela a rampa e lisa e o
	# unico relevo vem do normal map, que some na silhueta.
	var fine := _detail.get_noise_2d(noise_origin.y + local.x, noise_origin.x + local.y)
	shaped += profile * fine * detail_relief
	# Amortece o ruido perto da borda pra nao levantar degrau no encontro com o
	# chao (a beirada tem que morrer em zero de verdade).
	return height * lerpf(profile, shaped, smoothstep(1.0, 0.55, d))

func _build_mesh(res: int, radius: float, height: float, stretch: Vector2, spin: float,
		peak: Vector2, noise_origin: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var span := _span(radius, stretch, peak)
	var step := 2.0 * span / float(res)
	for j in range(res):
		for i in range(res):
			var x0 := -span + i * step
			var z0 := -span + j * step
			var quad := [
				Vector2(x0, z0), Vector2(x0 + step, z0),
				Vector2(x0 + step, z0 + step), Vector2(x0, z0 + step)]
			var h: Array[float] = []
			for c: Vector2 in quad:
				h.append(_height_at(c, radius, height, stretch, spin, peak, noise_origin))
			# Quad inteiro no chao nao vira geometria: sem isso cada macico
			# arrastaria um tapete quadrado de faces coplanares brigando por
			# z-fighting com o chao do mundo.
			if h[0] <= 0.0 and h[1] <= 0.0 and h[2] <= 0.0 and h[3] <= 0.0:
				continue
			var v: Array[Vector3] = []
			for k in range(4):
				v.append(Vector3(quad[k].x, h[k], quad[k].y))
			# Ordem dos vertices = pra que lado a face olha. Com [0,2,1,0,3,2] a
			# normal saia apontando pra BAIXO: o macico ficava invisivel visto de
			# cima (cull_back comia a face virada pra camera) e de longe so
			# aparecia a parede interna do lado oposto — dai a "lasca" fina que a
			# vista aerea mostrou.
			for idx in [0, 1, 2, 0, 2, 3]:
				# UV planar so pra ter tangente coerente: o shader amostra por
				# posicao de mundo, entao a UV em si nao pinta nada — mas sem
				# ela o SurfaceTool se recusa a gerar tangente, e sem tangente
				# a normal de detalhe do shader nao tem base pra girar.
				st.set_uv(Vector2(quad[idx].x, quad[idx].y) * 0.05)
				st.add_vertex(v[idx])
	# index() antes de generate_normals(): sem isso cada quad guarda vertices
	# proprios, a normal sai por FACE e o macico vira um amontoado de placas
	# chapadas (ficou visivel na primeira foto de perto). Indexado, os
	# vertices da grade sao compartilhados e a normal e a media dos vizinhos.
	st.index()
	st.generate_normals()
	st.generate_tangents()
	return st.commit()
