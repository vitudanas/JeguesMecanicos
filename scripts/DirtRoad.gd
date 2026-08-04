extends Node3D
## Estrada de terra ligando a cidade a oficina.
##
## Antes o trecho entre a ultima rua asfaltada (x = -112.5) e o patio da oficina
## (x = -175) era grama pura: dava pra dirigir, mas nada indicava o caminho e a
## oficina parecia largada no meio do nada.
##
## E uma FITA DE MALHA sem colisao, pousada rente ao chao. Sem colisao de
## proposito: o chao do mundo ja e solido, e um corpo a mais aqui so criaria
## degrau e risco de parede invisivel — que e exatamente o defeito que a
## cordilheira tinha.

## Pontos do eixo da estrada (x, z). O Y sai do chao medido, nao chutado.
@export var points: Array[Vector2] = []
@export var width := 7.0
## Altura sobre o chao. Rente: alto demais vira degrau, e o carro sobe nele.
@export var lift := 0.03
@export var dirt_color := Color(0.36, 0.29, 0.21)
@export var rut_color := Color(0.28, 0.22, 0.16)
@export var rng_seed := 20260804

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	if points.size() < 2:
		# Alto, nao calado: sem pontos o no existe na cena e nao desenha nada, e
		# procurar uma estrada que nunca foi construida custa caro.
		push_warning("DirtRoad '%s': sem pontos, nada foi construido" % name)
		return
	print("DirtRoad '%s': %d pontos, de %s a %s" % [name, points.size(),
		points[0], points[-1]])
	_rng.seed = rng_seed
	_build_ribbon(width, dirt_color, lift, 0.10)
	# Duas trilhas de roda, mais escuras e mais estreitas, deslocadas do eixo.
	# E o que faz ler como estrada de terra usada em vez de faixa de barro.
	for side: float in [-1.0, 1.0]:
		_build_ribbon(1.05, rut_color, lift + 0.004, 0.02, side * width * 0.19)

## Uma fita ao longo do eixo. `jitter` bagunca a largura de segmento em
## segmento: borda reta perfeita denuncia que a estrada foi desenhada, e
## estrada de terra nao tem meio-fio.
func _build_ribbon(w: float, color: Color, y: float, jitter: float,
		offset := 0.0) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var has_prev := false
	var total := points.size()
	for i in range(total):
		var p := points[i]
		# Direcao pelo vizinho: nas pontas usa o unico vizinho que existe.
		var a: Vector2 = points[maxi(i - 1, 0)]
		var b: Vector2 = points[mini(i + 1, total - 1)]
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var half: float = w * 0.5 * (1.0 + _rng.randf_range(-jitter, jitter))
		var c := p + nrm * offset
		var l := c - nrm * half
		var r := c + nrm * half
		var lv := Vector3(l.x, y, l.y)
		var rv := Vector3(r.x, y, r.y)
		if has_prev:
			for v: Vector3 in [prev_l, prev_r, rv, prev_l, rv, lv]:
				st.set_uv(Vector2(v.x, v.z) * 0.08)
				st.add_vertex(v)
		prev_l = lv
		prev_r = rv
		has_prev = true
	st.index()
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic = 0.0
	# Dupla face: a fita foi construida e mesmo assim nao aparecia na foto —
	# ordem de vertice define pra que lado a face olha, e a montanha ja tinha
	# caido nessa mesma armadilha. Numa fita plana rente ao chao, desligar o
	# descarte custa nada e tira a duvida de vez.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)
