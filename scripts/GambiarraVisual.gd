extends Node3D
class_name GambiarraVisual
## Monta a APARENCIA de uma gambiarra com primitivas combinadas.
##
## Antes cada peca era UM bloco liso: um cubo cinza pro capo, um cilindro verde
## pro radiador, um cubo vermelho pro retrovisor e um amarelo pro parachoque.
## Na tela isso lia como cubo colorido grudado no carro, e a piada do jogo —
## consertar com tranqueira do dia a dia — nao chegava ao jogador. Aqui cada
## peca vira um objeto reconhecivel: a dobradica tem duas abas e um pino, a
## mangueira e um tubo curvo com abracadeiras, a fita sao tiras cruzadas e o
## plastico e uma lona amassada e translucida presa com fita.
##
## Tudo em codigo, com primitivas — mesma escolha ja feita pro mobiliario urbano
## (`StreetFurniture.gd`): manter um so estilo visual e nao trazer pacote novo.

## A ordem importa: o catalogo em `Economy.GAMBIARRAS` guarda o indice.
enum Kind {
	HINGE, HOSE, TAPE, PLASTIC,
	WIRE, STRAP,           # capo: barata / caprichada
	GUM, HOSE_HEAVY,       # radiador
	ZIPTIE, BIKE_MIRROR,   # retrovisor
	CARDBOARD, PLYWOOD,    # parachoque
}

@export var kind: Kind = Kind.HINGE
## Semente propria: sorteio global mudaria o layout da cidade inteira, que sai
## do mesmo RNG (licao ja registrada no projeto).
@export var rng_seed := 20260804

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = rng_seed + kind
	match kind:
		Kind.HINGE: _build_hinge()
		Kind.HOSE: _build_hose()
		Kind.TAPE: _build_tape()
		Kind.PLASTIC: _build_plastic()
		Kind.WIRE: _build_wire()
		Kind.STRAP: _build_strap()
		Kind.GUM: _build_gum()
		Kind.HOSE_HEAVY: _build_hose(true)
		Kind.ZIPTIE: _build_ziptie()
		Kind.BIKE_MIRROR: _build_bike_mirror()
		Kind.CARDBOARD: _build_cardboard()
		Kind.PLYWOOD: _build_plywood()

# ------------------------------------------------------------------ materiais

func _metal(color: Color, rough := 0.45) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.85
	m.metallic_specular = 0.6
	m.roughness = rough
	return m

func _matte(color: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.0
	m.roughness = rough
	return m

## Plastico de saco de lixo: translucido e um pouco brilhante.
func _film(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.28
	m.metallic = 0.0
	# Lona tem duas faces: sem isso o lado de dentro some e o remendo fica com
	# buraco quando o jogador olha de outro angulo.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

# ------------------------------------------------------------------- tijolos

func _box(size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	add_child(mi)
	return mi

func _cyl(radius: float, height: float, pos: Vector3, mat: Material,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	add_child(mi)
	return mi

func _torus(inner: float, outer: float, pos: Vector3, mat: Material,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 12
	mesh.ring_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	add_child(mi)
	return mi

# --------------------------------------------------------------------- pecas

## Dobradica de porta parafusada no capo: duas abas, o pino no meio e os
## parafusos. E a peca que fica mais perto do olho do jogador (em cima do capo),
## entao vale ter os parafusos.
func _build_hinge() -> void:
	var steel := _metal(Color(0.62, 0.62, 0.66), 0.40)
	var rust := _metal(Color(0.45, 0.26, 0.14), 0.75)
	var plate := Vector3(0.15, 0.014, 0.10)
	# Abas ligeiramente abertas, como dobradica meio torta — e gambiarra.
	_box(plate, Vector3(-0.075, 0.012, 0.0), steel, Vector3(0.0, 0.0, deg_to_rad(-7.0)))
	_box(plate, Vector3(0.075, 0.004, 0.0), rust, Vector3(0.0, 0.0, deg_to_rad(4.0)))
	# Pino do eixo, deitado ao longo do vinco.
	_cyl(0.016, 0.13, Vector3(0.0, 0.016, 0.0), steel, Vector3(deg_to_rad(90.0), 0.0, 0.0))
	# Parafusos: dois por aba.
	for sx: float in [-0.115, 0.115]:
		for sz: float in [-0.032, 0.032]:
			_cyl(0.011, 0.010, Vector3(sx, 0.020, sz), rust)

## Mangueira de pia enfiada no radiador: tubo curvo em segmentos, com
## abracadeira de metal nas duas pontas. O corrugado sai de aneis ao longo do
## tubo — e o que faz ler como mangueira e nao como cano.
func _build_hose(heavy := false) -> void:
	# A versao pesada e a mesma mangueira em borracha preta trancada, mais
	# grossa e com abracadeira em todo segmento — le como "peca de verdade
	# improvisada", que e o degrau caro deste ponto.
	var rubber := _matte(Color(0.10, 0.28, 0.13), 0.9)
	if heavy:
		rubber = _matte(Color(0.11, 0.11, 0.13), 0.75)
	var clamp_mat := _metal(Color(0.72, 0.72, 0.75), 0.35)
	var segments := 7
	var radius := 0.035
	var length := 0.42
	var step := length / float(segments)
	for i in range(segments):
		var t := float(i) / float(segments - 1)
		# Arco simples: sobe e curva pra fora conforme avanca.
		var bend: float = sin(t * PI * 0.65) * 0.10
		var pos := Vector3(bend * 0.35, bend, -length * 0.5 + step * float(i))
		var tilt: float = deg_to_rad(t * 26.0)
		_cyl(radius, step * 1.5, pos, rubber, Vector3(deg_to_rad(90.0) - tilt, 0.0, 0.0))
		# Corrugado: um anel a cada dois segmentos. Na pesada, o anel vira
		# abracadeira de metal — e o que se ve de longe e diz "essa nao cai".
		if i % 2 == 1:
			_torus(radius * 0.92, radius * 1.22, pos,
				clamp_mat if heavy else rubber,
				Vector3(deg_to_rad(90.0) - tilt, 0.0, 0.0))
	# Abracadeiras nas pontas.
	_torus(radius * 1.0, radius * 1.35, Vector3(0.0, 0.0, -length * 0.5), clamp_mat,
		Vector3(deg_to_rad(90.0), 0.0, 0.0))
	var end_t := 1.0
	var end_bend: float = sin(end_t * PI * 0.65) * 0.10
	_torus(radius * 1.0, radius * 1.35,
		Vector3(end_bend * 0.35, end_bend, -length * 0.5 + step * float(segments - 1)),
		clamp_mat, Vector3(deg_to_rad(90.0) - deg_to_rad(26.0), 0.0, 0.0))

## Fita isolante segurando o retrovisor: tiras cruzadas, meio tortas, mais o
## rolo sobrando pendurado. Fita preta com brilho baixo, nao cubo vermelho.
func _build_tape() -> void:
	var tape := _matte(Color(0.09, 0.09, 0.10), 0.5)
	var tape2 := _matte(Color(0.12, 0.12, 0.14), 0.45)
	# Tres tiras em angulos diferentes, como quem enrolou com pressa.
	_box(Vector3(0.26, 0.006, 0.055), Vector3(0.0, 0.0, 0.0), tape,
		Vector3(0.0, 0.0, deg_to_rad(12.0)))
	_box(Vector3(0.24, 0.006, 0.050), Vector3(0.0, 0.012, 0.02), tape2,
		Vector3(deg_to_rad(6.0), 0.0, deg_to_rad(-18.0)))
	_box(Vector3(0.20, 0.006, 0.045), Vector3(-0.01, -0.014, -0.02), tape,
		Vector3(0.0, deg_to_rad(8.0), deg_to_rad(3.0)))
	# Ponta solta, levantada — o detalhe que denuncia a gambiarra.
	_box(Vector3(0.09, 0.005, 0.042), Vector3(0.15, 0.03, 0.01), tape2,
		Vector3(0.0, 0.0, deg_to_rad(38.0)))
	# O rolo sobrando, preso junto.
	_torus(0.026, 0.052, Vector3(-0.10, 0.035, 0.0), tape,
		Vector3(0.0, 0.0, deg_to_rad(90.0)))

## Lona plastica amassada no lugar do parachoque, presa com fita. Varias abas
## em angulos levemente diferentes dao o amassado sem precisar de malha propria.
func _build_plastic() -> void:
	var film := _film(Color(0.86, 0.90, 0.95, 0.55))
	var film2 := _film(Color(0.78, 0.85, 0.92, 0.48))
	var tape := _matte(Color(0.72, 0.70, 0.66), 0.6)
	for i in range(5):
		var t := float(i) / 4.0
		var w: float = _rng.randf_range(0.16, 0.22)
		var hgt: float = _rng.randf_range(0.16, 0.24)
		var mat: Material = film if i % 2 == 0 else film2
		_box(Vector3(w, hgt, 0.006),
			Vector3(-0.30 + t * 0.60, _rng.randf_range(-0.02, 0.02),
				_rng.randf_range(-0.012, 0.012)),
			mat,
			Vector3(_rng.randf_range(-0.14, 0.14), _rng.randf_range(-0.20, 0.20),
				_rng.randf_range(-0.16, 0.16)))
	# Fita crua segurando a lona nas pontas e no meio.
	for x: float in [-0.26, 0.0, 0.26]:
		_box(Vector3(0.045, 0.26, 0.010), Vector3(x, 0.0, 0.012), tape,
			Vector3(0.0, 0.0, _rng.randf_range(-0.12, 0.12)))

# ------------------------------------------- as opcoes barata e caprichada
#
# Um builder por item, todos com as mesmas primitivas dos quatro originais. O
# que separa os tres degraus de cada ponto NAO e cor: e o objeto ser
# reconhecivelmente pior ou melhor. Arame torto le como gambiarra na hora;
# cinta de amarracao com catraca le como "alguem se esforcou".

## Liga dois pontos com um cilindro. Sem isto, "arame" virava um punhado de
## palitos soltos no ar: eu posicionava cada pedaco por angulo, e angulo escrito
## na mao nao garante que a ponta de um encoste na do outro. Ligando ponto a
## ponto, o arame e continuo por construcao.
func _link(a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var dir := b - a
	var comp := dir.length()
	if comp < 0.0005:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = comp
	mesh.radial_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	# O cilindro do Godot cresce no Y: monto uma base com Y na direcao do
	# segmento e escolho o eixo de referencia que nao for quase paralelo a ela.
	var ey := dir / comp
	var ref := Vector3.RIGHT if absf(ey.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var ex := ref.cross(ey).normalized()
	var ez := ex.cross(ey)
	mi.transform = Transform3D(Basis(ex, ey, ez), (a + b) * 0.5)
	add_child(mi)

## Capo, opcao barata: dois pedacos de arame torcidos passando pelo vinco.
func _build_wire() -> void:
	var wire := _metal(Color(0.55, 0.56, 0.58), 0.55)
	for sz: float in [-0.045, 0.045]:
		# Uma volta fechada de arame, ponto a ponto: elipse deitada com o
		# raio sacudido, que e como fica arame dobrado na mao.
		var pts: Array[Vector3] = []
		var n := 12
		for i in range(n):
			var t := TAU * float(i) / float(n)
			var jitter: float = 1.0 + _rng.randf_range(-0.16, 0.16)
			pts.append(Vector3(cos(t) * 0.052 * jitter, 0.020 + sin(t) * 0.030 * jitter,
				sz + _rng.randf_range(-0.004, 0.004)))
		for i in range(n):
			_link(pts[i], pts[(i + 1) % n], 0.005, wire)
		# As duas pontas torcidas uma na outra, subindo — e o detalhe que
		# denuncia a gambiarra.
		var topo: Vector3 = pts[3]
		_link(topo, topo + Vector3(0.008, 0.022, 0.006), 0.0045, wire)
		_link(topo + Vector3(0.008, 0.022, 0.006),
			topo + Vector3(-0.004, 0.040, 0.012), 0.0045, wire)
	# O arame que atravessa de uma volta a outra.
	_link(Vector3(-0.045, 0.022, -0.045), Vector3(0.045, 0.026, 0.045), 0.005, wire)

## Capo, opcao caprichada: cinta de amarracao (aquela laranja de carreto) com
## catraca de metal no meio.
func _build_strap() -> void:
	var webbing := _matte(Color(0.78, 0.34, 0.06), 0.9)
	var steel := _metal(Color(0.58, 0.59, 0.62), 0.35)
	# Duas voltas de fita larga, quase deitadas.
	for sz: float in [-0.05, 0.05]:
		_box(Vector3(0.34, 0.006, 0.045), Vector3(0.0, 0.008, sz), webbing,
			Vector3(0.0, _rng.randf_range(-0.03, 0.03), 0.0))
	# Catraca: corpo de metal com o gancho.
	_box(Vector3(0.085, 0.038, 0.055), Vector3(0.0, 0.030, 0.0), steel)
	_cyl(0.009, 0.075, Vector3(0.0, 0.030, 0.0), steel,
		Vector3(0.0, 0.0, deg_to_rad(90.0)))
	_box(Vector3(0.03, 0.010, 0.022), Vector3(0.055, 0.046, 0.0), steel,
		Vector3(0.0, 0.0, deg_to_rad(-25.0)))

## Radiador, opcao barata: um bolo de chiclete rosa com fita por cima. E o item
## mais ridiculo do catalogo, de proposito — o degrau barato tem que DAR MEDO.
func _build_gum() -> void:
	var gum := _matte(Color(0.85, 0.45, 0.52), 0.55)
	var tape := _matte(Color(0.14, 0.14, 0.15), 0.7)
	# Bolo irregular: tres esferas achatadas encavaladas.
	for i in range(3):
		var mesh := SphereMesh.new()
		mesh.radius = _rng.randf_range(0.030, 0.045)
		mesh.height = mesh.radius * 1.5
		mesh.radial_segments = 8
		mesh.rings = 5
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = gum
		mi.position = Vector3(_rng.randf_range(-0.03, 0.03), 0.02,
			_rng.randf_range(-0.03, 0.03))
		add_child(mi)
	# Duas tiras de fita cruzadas por cima, mal coladas.
	for ang: float in [22.0, -48.0]:
		_box(Vector3(0.16, 0.004, 0.030), Vector3(0.0, 0.045, 0.0), tape,
			Vector3(0.0, deg_to_rad(ang), deg_to_rad(_rng.randf_range(-6.0, 6.0))))

## Retrovisor, opcao media: abracadeira de nylon (aquela de amarrar fio), com a
## ponta comprida sobrando.
func _build_ziptie() -> void:
	var nylon := _matte(Color(0.16, 0.16, 0.18), 0.55)
	for sy: float in [0.0, 0.045]:
		# A alca: quatro tirinhas formando um retangulo fechado.
		_box(Vector3(0.10, 0.005, 0.004), Vector3(0.0, 0.012 + sy, 0.030), nylon)
		_box(Vector3(0.10, 0.005, 0.004), Vector3(0.0, 0.012 + sy, -0.030), nylon)
		_box(Vector3(0.004, 0.005, 0.064), Vector3(-0.050, 0.012 + sy, 0.0), nylon)
		_box(Vector3(0.004, 0.005, 0.064), Vector3(0.050, 0.012 + sy, 0.0), nylon)
		# Cabecinha da trava.
		_box(Vector3(0.014, 0.012, 0.011), Vector3(0.050, 0.014 + sy, 0.030), nylon)
	# A ponta que ninguem corta.
	_box(Vector3(0.004, 0.005, 0.075), Vector3(0.050, 0.014, 0.070), nylon,
		Vector3(deg_to_rad(12.0), 0.0, 0.0))

## Retrovisor, opcao caprichada: espelhinho de bicicleta num braco articulado.
## Nao e peca original, mas e um espelho DE VERDADE — o cliente quase nao
## reclama.
func _build_bike_mirror() -> void:
	var steel := _metal(Color(0.52, 0.53, 0.57), 0.3)
	# Metalico puro com rugosidade zero fica PRETO quando nao ha nada em volta
	# pra refletir — foi o que a folha de contato mostrou. Um pouco de emissao e
	# metalico parcial fazem o vidro ler como espelho em qualquer luz.
	var glass := _metal(Color(0.86, 0.90, 0.96), 0.08)
	glass.metallic = 0.75
	glass.emission_enabled = true
	glass.emission = Color(0.62, 0.70, 0.82)
	glass.emission_energy_multiplier = 0.55
	var black := _matte(Color(0.12, 0.12, 0.13), 0.6)
	# Base presa na lataria e o braco subindo torto.
	_box(Vector3(0.05, 0.014, 0.04), Vector3(0.0, 0.008, 0.0), black)
	_cyl(0.008, 0.10, Vector3(0.0, 0.055, -0.012), steel,
		Vector3(deg_to_rad(14.0), 0.0, deg_to_rad(10.0)))
	# Aro e vidro.
	# O VIDRO FICA NA FACE DE FORA do aro. Com ele atras, quem olha o carro de
	# fora ve so o plastico preto — na folha de contato o item virou um disco
	# escuro num poste, e ninguem diria que aquilo e um espelho.
	_cyl(0.045, 0.010, Vector3(-0.018, 0.105, -0.030), black,
		Vector3(deg_to_rad(78.0), 0.0, 0.0))
	_cyl(0.038, 0.004, Vector3(-0.018, 0.106, -0.022), glass,
		Vector3(deg_to_rad(78.0), 0.0, 0.0))

## Parachoque, opcao barata: uma placa de papelao amassada amarrada com
## barbante. De longe ja parece papelao molhado.
func _build_cardboard() -> void:
	var papel := _matte(Color(0.55, 0.42, 0.28), 0.95)
	var barbante := _matte(Color(0.78, 0.72, 0.55), 0.95)
	# Tres abas em angulos diferentes: papelao dobrado nunca fica plano.
	for i in range(3):
		var t := float(i) / 2.0 - 0.5
		_box(Vector3(0.20, 0.006, 0.16),
			Vector3(t * 0.19, 0.01 + absf(t) * 0.015, 0.0), papel,
			Vector3(deg_to_rad(_rng.randf_range(-9.0, 9.0)), 0.0,
				deg_to_rad(t * 16.0)))
	# Barbante amarrando de ponta a ponta.
	for sz: float in [-0.05, 0.05]:
		_cyl(0.004, 0.60, Vector3(0.0, 0.030, sz), barbante,
			Vector3(0.0, 0.0, deg_to_rad(90.0)))

## Parachoque, opcao caprichada: chapa de compensado parafusada. Feia, mas
## solida — e o degrau que sobrevive ao test-drive.
func _build_plywood() -> void:
	var madeira := _matte(Color(0.72, 0.56, 0.33), 0.9)
	var borda := _matte(Color(0.58, 0.44, 0.25), 0.9)
	var steel := _metal(Color(0.60, 0.61, 0.64), 0.4)
	_box(Vector3(0.58, 0.016, 0.20), Vector3(0.0, 0.014, 0.0), madeira)
	# As laminas na borda, que e o que faz compensado parecer compensado.
	for sy: float in [0.007, 0.021]:
		_box(Vector3(0.585, 0.003, 0.205), Vector3(0.0, sy, 0.0), borda)
	# Parafusos nos quatro cantos, um deles torto.
	for sx: float in [-0.24, 0.24]:
		for sz: float in [-0.07, 0.07]:
			_cyl(0.010, 0.014, Vector3(sx, 0.026, sz), steel,
				Vector3(deg_to_rad(_rng.randf_range(-8.0, 8.0)), 0.0, 0.0))
