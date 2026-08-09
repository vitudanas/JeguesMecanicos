class_name BuildingFactory
extends RefCounted
## Constrói um prédio inteiro em geometria, em vez de instanciar um modelo.
##
## POR QUE ISTO EXISTE. A cidade tinha 837 prédios saindo de ~60 modelos de kit,
## e a medição de 2026-08-03 já tinha apontado o culpado do aspecto de desenho:
## não é a superfície (o PBR das fachadas resolveu isso), é a **geometria** —
## caixa lisa com a janela PINTADA na textura, sem beiral, sem parapeito, sem
## vão. E não existe kit CC0 de prédio realista pra baixar: a categoria de
## arquitetura do Poly Haven está vazia, e Kenney/KayKit/Quaternius são todos
## estilizados (pesquisado três vezes, ver docs/modelos-realistas.md).
##
## Gerando, os dois problemas caem juntos:
##   - a janela vira um **vão de verdade**, rebaixado, com vidro no fundo — é o
##     que faz a fachada ter profundidade e sombra própria;
##   - cada prédio é ÚNICO, então some a repetição, que é justamente o que
##     pioraria se a gente trocasse por 30 modelos realistas repetidos 28 vezes.
##
## CUSTO DE DESENHO: tudo é acumulado em três superfícies (parede, moldura,
## vidro), então um prédio inteiro custa **3 chamadas de desenho**, com 40 ou
## com 400 janelas. Sem isso, uma janela por MeshInstance3D estouraria a cidade.

const GLASS_INSET := 0.16     ## quanto o vidro recua da fachada
const FRAME_DEPTH := 0.07     ## saliência da moldura da janela

## Tipos de prédio. Mudam proporção, altura de pé-direito, telhado e detalhes —
## não são só cores diferentes.
enum Kind {TORRE, COMERCIO, CASA, GALPAO}

## Materiais de fachada disponíveis, por tipo. Vêm dos conjuntos PBR que o
## projeto já usa (ver CitySurface.SETS) — nenhum download novo.
const SURFACES := {
	Kind.TORRE: ["concreto", "concreto", "reboco"],
	Kind.COMERCIO: ["reboco", "tijolo", "concreto"],
	Kind.CASA: ["reboco", "tijolo", "reboco"],
	Kind.GALPAO: ["concreto", "concreto", "tijolo"],
}

## Paleta de fachada: tons de reboco/pintura de rua, dessaturados de propósito
## (cor saturada foi o que devolvia o aspecto de desenho em 2026-08-03).
const PALETTE: Array[Color] = [
	Color(0.86, 0.84, 0.79), Color(0.78, 0.75, 0.70), Color(0.72, 0.68, 0.63),
	Color(0.80, 0.76, 0.68), Color(0.68, 0.70, 0.72), Color(0.74, 0.71, 0.66),
	Color(0.82, 0.79, 0.74), Color(0.65, 0.63, 0.60), Color(0.79, 0.72, 0.65),
]

# --------------------------------------------------------------- as medidas

## Sorteia as medidas de um prédio. Separado da construção de propósito: o
## `CityBlocks` precisa saber a LARGURA antes de decidir se ele cabe no lote.
static func roll(rng: RandomNumberGenerator, kind: Kind) -> Dictionary:
	var d: Dictionary = {"kind": kind}
	match kind:
		Kind.TORRE:
			d["width"] = rng.randf_range(9.0, 15.0)
			d["depth"] = rng.randf_range(9.0, 13.0)
			d["floors"] = rng.randi_range(6, 11)
			d["floor_h"] = rng.randf_range(3.1, 3.5)
		Kind.COMERCIO:
			d["width"] = rng.randf_range(7.0, 13.0)
			d["depth"] = rng.randf_range(8.0, 12.5)
			d["floors"] = rng.randi_range(2, 5)
			d["floor_h"] = rng.randf_range(3.2, 3.8)
		Kind.CASA:
			d["width"] = rng.randf_range(6.0, 9.5)
			d["depth"] = rng.randf_range(7.0, 10.0)
			d["floors"] = rng.randi_range(1, 2)
			d["floor_h"] = rng.randf_range(2.9, 3.3)
		Kind.GALPAO:
			d["width"] = rng.randf_range(11.0, 18.0)
			d["depth"] = rng.randf_range(10.0, 13.0)
			d["floors"] = 1
			d["floor_h"] = rng.randf_range(5.0, 7.0)
	# Térreo mais alto que os andares de cima, como em prédio de verdade.
	d["ground_h"] = float(d["floor_h"]) * (1.35 if kind != Kind.CASA else 1.05)
	d["color"] = PALETTE[rng.randi() % PALETTE.size()]
	var opts: Array = SURFACES[kind]
	d["surface"] = opts[rng.randi() % opts.size()]
	d["parapet"] = kind != Kind.CASA
	d["balcony"] = kind == Kind.COMERCIO and rng.randf() < 0.45
	d["seed"] = rng.randi()
	return d

static func height_of(d: Dictionary) -> float:
	return float(d["ground_h"]) + float(d["floors"] - 1) * float(d["floor_h"]) \
		+ (0.9 if bool(d["parapet"]) else 2.2)

# ------------------------------------------------------------- a construção

## Monta o prédio. A origem fica no CENTRO da planta, no chão (y = 0) — é o que
## o `CityBlocks` espera de qualquer construção.
static func build(d: Dictionary, facade_size: float, saturation: float,
		grime: float) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d["seed"])
	var root := Node3D.new()
	root.name = "PredioGerado"

	var wall := SurfaceTool.new()
	var trim := SurfaceTool.new()
	var glass := SurfaceTool.new()
	for st: SurfaceTool in [wall, trim, glass]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var w: float = d["width"]
	var dp: float = d["depth"]
	var floors: int = d["floors"]
	var gh: float = d["ground_h"]
	var fh: float = d["floor_h"]

	# As quatro faces. A fachada da frente (-Z, que é o lado que o CityBlocks
	# vira pra rua) ganha o térreo comercial; as outras são parede com janela.
	var y := 0.0
	for andar in range(floors):
		var alt: float = gh if andar == 0 else fh
		_ring(wall, trim, glass, rng, d, y, alt, andar == 0)
		y += alt
		# Faixa de separação entre andares: é ela que dá a "linha" horizontal
		# que todo prédio de rua tem e que caixa lisa não tem.
		if andar < floors - 1:
			_ledge(trim, w, dp, y, 0.10, 0.06)

	_roof(wall, trim, rng, d, y)

	_commit(root, wall, "Parede", d["color"], str(d["surface"]), facade_size,
		saturation, grime)
	# Moldura/beiral num tom mais claro que a parede: é assim que se lê como
	# concreto aparente contra reboco pintado.
	_commit(root, trim, "Molduras", (d["color"] as Color).lightened(0.22),
		"concreto", 1.4, saturation, 0.0)
	_commit_glass(root, glass)
	return root

## Um anel de parede com janelas nas quatro faces.
static func _ring(wall: SurfaceTool, trim: SurfaceTool, glass: SurfaceTool,
		rng: RandomNumberGenerator, d: Dictionary, y: float, alt: float,
		terreo: bool) -> void:
	var w: float = d["width"]
	var dp: float = d["depth"]
	var kind: int = d["kind"]
	var faces := [
		[Vector3(0, 0, -dp * 0.5), Vector3.RIGHT, Vector3.FORWARD, w],
		[Vector3(0, 0, dp * 0.5), Vector3.LEFT, Vector3.BACK, w],
		[Vector3(-w * 0.5, 0, 0), Vector3.FORWARD, Vector3.LEFT, dp],
		[Vector3(w * 0.5, 0, 0), Vector3.BACK, Vector3.RIGHT, dp],
	]
	for i in range(faces.size()):
		var f: Array = faces[i]
		var centro: Vector3 = f[0]
		var eixo: Vector3 = f[1]      # sentido em que a face corre
		var fora: Vector3 = f[2]      # normal da face, pra fora
		var comp: float = f[3]
		# Galpão não tem grade de janela: é um barracão com portão e faixa alta.
		if kind == Kind.GALPAO:
			_solid_face(wall, centro, eixo, fora, comp, y, alt)
			if i == 0:
				_shed_front(wall, trim, glass, centro, eixo, fora, comp, y, alt)
			continue
		# Quantas janelas cabem: uma a cada ~2.6 m, no mínimo uma.
		var vaos: int = maxi(1, int(floor(comp / 2.6)))
		var passo: float = comp / float(vaos)
		var jw: float = minf(passo * 0.52, 1.5)
		var jh: float = alt * (0.42 if terreo else 0.52)
		var jy: float = alt * (0.30 if terreo else 0.26)   # relativo ao piso
		# Vitrine no térreo da frente: vidro alto, do chão quase ao teto.
		if terreo and i == 0 and kind != Kind.CASA:
			jw = passo * 0.78
			jh = alt * 0.62
			jy = alt * 0.16
		_face(wall, trim, glass, centro, eixo, fora, comp, y, alt,
			vaos, passo, jw, jh, jy, rng)
		if terreo and i == 0 and kind == Kind.CASA:
			_door(wall, trim, centro, eixo, fora, y, alt)

## Uma face inteira: as faixas de parede EM VOLTA dos vãos, mais os vãos.
##
## As faixas são calculadas a partir do retângulo real da janela, e não de
## frações fixas. Foi esse o primeiro erro: eu desenhava a banda de baixo até
## 26% da altura enquanto a janela do térreo começava em 16%, e a fachada saía
## VAZADA — dava pra ver o interior do prédio pela parede (visto na folha de
## contato; nenhum número acusaria).
static func _face(wall: SurfaceTool, trim: SurfaceTool, glass: SurfaceTool,
		centro: Vector3, eixo: Vector3, fora: Vector3, comp: float, y: float,
		alt: float, vaos: int, passo: float, jw: float, jh: float, jy: float,
		rng: RandomNumberGenerator) -> void:
	var canto: Vector3 = centro + eixo * (-comp * 0.5) + Vector3.UP * y
	# Faixa abaixo das janelas e faixa acima delas: cobrem a largura inteira.
	if jy > 0.001:
		_quad(wall, canto, eixo * comp, Vector3.UP * jy, fora)
	var topo: float = alt - (jy + jh)
	if topo > 0.001:
		_quad(wall, canto + Vector3.UP * (jy + jh), eixo * comp,
			Vector3.UP * topo, fora)
	# Colunas entre um vão e outro, na altura exata das janelas.
	var bordas: Array[float] = []
	for n in range(vaos):
		var t: float = passo * (float(n) + 0.5)
		bordas.append(t - jw * 0.5)
		bordas.append(t + jw * 0.5)
	var cursor := 0.0
	for k in range(0, bordas.size(), 2):
		var a: float = bordas[k]
		if a - cursor > 0.001:
			_quad(wall, canto + eixo * cursor + Vector3.UP * jy,
				eixo * (a - cursor), Vector3.UP * jh, fora)
		cursor = bordas[k + 1]
	if comp - cursor > 0.001:
		_quad(wall, canto + eixo * cursor + Vector3.UP * jy,
			eixo * (comp - cursor), Vector3.UP * jh, fora)
	# E os vãos.
	for n in range(vaos):
		var p: Vector3 = centro + eixo * (-comp * 0.5 + passo * (float(n) + 0.5))
		_window(wall, trim, glass, p, eixo, fora, jw, jh, y + jy)

## Parede cheia, sem vão.
static func _solid_face(st: SurfaceTool, centro: Vector3, eixo: Vector3,
		fora: Vector3, comp: float, y: float, alt: float) -> void:
	_quad(st, centro + eixo * (-comp * 0.5) + Vector3.UP * y,
		eixo * comp, Vector3.UP * alt, fora)

## Um vão de janela: caixa rebaixada (as quatro paredinhas do recuo), o vidro no
## fundo e a moldura saliente em volta. É a peça que tira a fachada de "caixa".
static func _window(wall: SurfaceTool, trim: SurfaceTool, glass: SurfaceTool,
		p: Vector3, eixo: Vector3, fora: Vector3, jw: float, jh: float,
		jy: float) -> void:
	var meio: Vector3 = p + Vector3.UP * jy
	var dentro: Vector3 = -fora * GLASS_INSET
	# Paredinhas do recuo (jamba, peitoril interno e verga interna).
	_quad(wall, meio + eixo * (-jw * 0.5), dentro, Vector3.UP * jh, eixo)
	_quad(wall, meio + eixo * (jw * 0.5) + dentro, -dentro, Vector3.UP * jh, -eixo)
	_quad(wall, meio + eixo * (-jw * 0.5), eixo * jw, dentro, Vector3.UP)
	_quad(wall, meio + eixo * (-jw * 0.5) + Vector3.UP * jh + dentro,
		eixo * jw, -dentro, Vector3.DOWN)
	# O vidro, no fundo do recuo.
	_quad(glass, meio + eixo * (-jw * 0.5) + dentro, eixo * jw, Vector3.UP * jh, fora)
	# Moldura saliente: peitoril embaixo e verga em cima.
	var sal: Vector3 = fora * FRAME_DEPTH
	_box_between(trim, meio + eixo * (-jw * 0.5 - 0.06) - Vector3.UP * 0.08,
		meio + eixo * (jw * 0.5 + 0.06) + sal, 0.08)
	_box_between(trim, meio + eixo * (-jw * 0.5 - 0.06) + Vector3.UP * jh,
		meio + eixo * (jw * 0.5 + 0.06) + sal + Vector3.UP * (jh + 0.09), 0.09)

## Porta de casa: recuo raso e uma soleira.
static func _door(wall: SurfaceTool, trim: SurfaceTool, centro: Vector3,
		eixo: Vector3, fora: Vector3, y: float, alt: float) -> void:
	var lw := 1.05
	var lh: float = alt * 0.68
	var p: Vector3 = centro + eixo * 0.0 + Vector3.UP * y
	var dentro: Vector3 = -fora * 0.12
	_quad(wall, p + eixo * (-lw * 0.5) + dentro, eixo * lw, Vector3.UP * lh, fora)
	_box_between(trim, p + eixo * (-lw * 0.5 - 0.07),
		p + eixo * (lw * 0.5 + 0.07) + fora * 0.06 + Vector3.UP * (lh + 0.1), 0.1)

## Frente de galpão: portão largo e faixa de janela alta.
static func _shed_front(wall: SurfaceTool, trim: SurfaceTool, glass: SurfaceTool,
		centro: Vector3, eixo: Vector3, fora: Vector3, comp: float, y: float,
		alt: float) -> void:
	var pw: float = minf(comp * 0.45, 5.5)
	var ph: float = alt * 0.62
	var p: Vector3 = centro + Vector3.UP * y
	var dentro: Vector3 = -fora * 0.14
	_quad(wall, p + eixo * (-pw * 0.5) + dentro, eixo * pw, Vector3.UP * ph, fora)
	_box_between(trim, p + eixo * (-pw * 0.5 - 0.1) + Vector3.UP * ph,
		p + eixo * (pw * 0.5 + 0.1) + fora * 0.14 + Vector3.UP * (ph + 0.18), 0.18)
	# Fita de janela alta, típica de barracão.
	var fw: float = comp * 0.8
	_quad(glass, p + eixo * (-fw * 0.5) + Vector3.UP * (alt * 0.74) - fora * 0.1,
		eixo * fw, Vector3.UP * (alt * 0.14), fora)

## Faixa horizontal que contorna o prédio (separação de andar, beiral).
static func _ledge(trim: SurfaceTool, w: float, dp: float, y: float,
		saliencia: float, esp: float) -> void:
	var a := Vector3(-w * 0.5 - saliencia, y, -dp * 0.5 - saliencia)
	var b := Vector3(w * 0.5 + saliencia, y + esp, dp * 0.5 + saliencia)
	_cuboid(trim, a, b)

## Cobertura: laje com parapeito (prédio) ou telhado de duas águas (casa).
static func _roof(wall: SurfaceTool, trim: SurfaceTool,
		rng: RandomNumberGenerator, d: Dictionary, y: float) -> void:
	var w: float = d["width"]
	var dp: float = d["depth"]
	if bool(d["parapet"]):
		# Laje.
		_quad(wall, Vector3(-w * 0.5, y, -dp * 0.5), Vector3(w, 0, 0),
			Vector3(0, 0, dp), Vector3.UP)
		# Beiral saliente e o parapeito por cima dele.
		_ledge(trim, w, dp, y, 0.16, 0.10)
		var h := 0.9
		var e := 0.14
		for lado: Array in [[Vector3(-w * 0.5, y, -dp * 0.5), Vector3(w * 0.5, y + h, -dp * 0.5 + e)],
				[Vector3(-w * 0.5, y, dp * 0.5 - e), Vector3(w * 0.5, y + h, dp * 0.5)],
				[Vector3(-w * 0.5, y, -dp * 0.5), Vector3(-w * 0.5 + e, y + h, dp * 0.5)],
				[Vector3(w * 0.5 - e, y, -dp * 0.5), Vector3(w * 0.5, y + h, dp * 0.5)]]:
			_cuboid(trim, lado[0], lado[1])
		# Casa de máquinas: quebra a silhueta reta vista de longe.
		if rng.randf() < 0.6:
			var cw: float = w * rng.randf_range(0.22, 0.34)
			var cd: float = dp * rng.randf_range(0.22, 0.34)
			var cx: float = rng.randf_range(-w * 0.2, w * 0.2)
			var cz: float = rng.randf_range(-dp * 0.2, dp * 0.2)
			_cuboid(wall, Vector3(cx - cw * 0.5, y, cz - cd * 0.5),
				Vector3(cx + cw * 0.5, y + rng.randf_range(1.8, 2.8), cz + cd * 0.5))
		return
	# Telhado de duas águas, com beiral passando da parede.
	var b := 0.35
	var h: float = maxf(w, dp) * 0.22
	var x0: float = -w * 0.5 - b
	var x1: float = w * 0.5 + b
	var z0: float = -dp * 0.5 - b
	var z1: float = dp * 0.5 + b
	var cume: float = y + h
	# Duas águas ao longo de X.
	_quad(trim, Vector3(x0, y, z0), Vector3(x1 - x0, 0, 0),
		Vector3(0, h, (z1 - z0) * 0.5), Vector3(0, 1, -1).normalized())
	_quad(trim, Vector3(x1, y, z1), Vector3(x0 - x1, 0, 0),
		Vector3(0, h, -(z1 - z0) * 0.5), Vector3(0, 1, 1).normalized())
	# Empenas (os triângulos das pontas) fechadas com parede.
	for x: float in [x0, x1]:
		var n := Vector3(-1, 0, 0) if x == x0 else Vector3(1, 0, 0)
		_tri(wall, Vector3(x, y, z0), Vector3(x, y, z1), Vector3(x, cume, (z0 + z1) * 0.5), n)

# ------------------------------------------------------- primitivas de malha

## Um quadrilátero a partir de um canto e dois vetores. Ordem dos vértices
## definida pela normal pedida — errar isso deixa a face virada pra dentro e ela
## some (armadilha que já custou a montanha invisível, changelog 2026-08-04).
static func _quad(st: SurfaceTool, origem: Vector3, du: Vector3, dv: Vector3,
		normal: Vector3) -> void:
	var p0 := origem
	var p1 := origem + du
	var p2 := origem + du + dv
	var p3 := origem + dv
	# Escala de UV em metros, pro triplanar do shader casar com o mundo.
	var uv := [Vector2(0, 0), Vector2(du.length(), 0),
		Vector2(du.length(), dv.length()), Vector2(0, dv.length())]
	var pts := [p0, p1, p2, p3]
	# O GODOT USA WINDING HORARIO pra face frontal — o contrario da regra da mao
	# direita. Eu montei a ordem pela regra da mao direita e as quatro paredes
	# sairam viradas pra dentro: o predio ficava VAZADO, dava pra ver o interior
	# pela fachada. Renderizar com `cull_disabled` foi o que separou "nao foi
	# gerada" de "esta virada" — sem esse teste eu teria mexido na geometria, que
	# estava certa desde o começo.
	var ordem := [0, 2, 1, 0, 3, 2]
	var n := (p1 - p0).cross(p3 - p0)
	if n.dot(normal) < 0.0:
		ordem = [0, 1, 2, 0, 2, 3]
	for i in ordem:
		st.set_normal(normal)
		st.set_uv(uv[i])
		st.add_vertex(pts[i])

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		normal: Vector3) -> void:
	var pts := [a, c, b]
	if (b - a).cross(c - a).dot(normal) < 0.0:
		pts = [a, b, c]
	for p: Vector3 in pts:
		st.set_normal(normal)
		st.set_uv(Vector2(p.x + p.z, p.y))
		st.add_vertex(p)

## Caixa fechada entre dois cantos.
static func _cuboid(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var s := hi - lo
	_quad(st, Vector3(lo.x, lo.y, lo.z), Vector3(s.x, 0, 0), Vector3(0, s.y, 0), Vector3.FORWARD)
	_quad(st, Vector3(lo.x, lo.y, hi.z), Vector3(s.x, 0, 0), Vector3(0, s.y, 0), Vector3.BACK)
	_quad(st, Vector3(lo.x, lo.y, lo.z), Vector3(0, 0, s.z), Vector3(0, s.y, 0), Vector3.LEFT)
	_quad(st, Vector3(hi.x, lo.y, lo.z), Vector3(0, 0, s.z), Vector3(0, s.y, 0), Vector3.RIGHT)
	_quad(st, Vector3(lo.x, hi.y, lo.z), Vector3(s.x, 0, 0), Vector3(0, 0, s.z), Vector3.UP)
	_quad(st, Vector3(lo.x, lo.y, lo.z), Vector3(s.x, 0, 0), Vector3(0, 0, s.z), Vector3.DOWN)

## Caixa entre dois pontos garantindo espessura mínima em Y.
static func _box_between(st: SurfaceTool, a: Vector3, b: Vector3, esp: float) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	if hi.y - lo.y < esp:
		hi.y = lo.y + esp
	# Espessura mínima nos outros eixos também, senão vira um plano invisível.
	if hi.x - lo.x < 0.02:
		hi.x = lo.x + 0.02
	if hi.z - lo.z < 0.02:
		hi.z = lo.z + 0.02
	_cuboid(st, lo, hi)

static func _commit(root: Node3D, st: SurfaceTool, nome: String, cor: Color,
		kind: String, size: float, saturation: float, grime: float) -> void:
	st.generate_tangents()
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = mesh
	# Mesmo shader das fachadas do kit: sombreamento facetado + PBR triplanar.
	# Sem atlas — aqui o albedo é a própria cor, e o PBR entra como grão.
	mi.material_override = CitySurface.make(null, cor, kind, size, saturation,
		0.5, grime)
	root.add_child(mi)

static var _glass_mat: StandardMaterial3D = null

static func _commit_glass(root: Node3D, st: SurfaceTool) -> void:
	st.generate_tangents()
	var mesh := st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	if _glass_mat == null:
		# Um material só pra cidade inteira: vidro não varia de prédio pra
		# prédio e um material por instância seria troca de estado à toa.
		_glass_mat = StandardMaterial3D.new()
		_glass_mat.albedo_color = Color(0.14, 0.18, 0.23)
		_glass_mat.metallic = 0.85
		_glass_mat.roughness = 0.08
		# Emissão fraca: em rua estreita a janela não enxerga o céu e voltaria a
		# ser um buraco preto (mesma correção feita nas vitrines em 2026-08-04).
		_glass_mat.emission_enabled = true
		_glass_mat.emission = Color(0.30, 0.38, 0.48)
		_glass_mat.emission_energy_multiplier = 0.28
	var mi := MeshInstance3D.new()
	mi.name = "Vidros"
	mi.mesh = mesh
	mi.material_override = _glass_mat
	root.add_child(mi)
