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

enum Kind {HINGE, HOSE, TAPE, PLASTIC}

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
func _build_hose() -> void:
	var rubber := _matte(Color(0.10, 0.28, 0.13), 0.9)
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
		# Corrugado: um anel a cada dois segmentos.
		if i % 2 == 1:
			_torus(radius * 0.92, radius * 1.22, pos, rubber,
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
