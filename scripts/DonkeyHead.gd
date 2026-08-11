class_name DonkeyHead
extends RefCounted
## Cabeca de jegue, montada com primitivas em codigo.
##
## O jogo se chama Jegues Mecanicos e o jogador e uma mulher com cabeca de
## jegue — nao existe modelo disso em pacote CC0 nenhum, e nao ha ferramenta de
## geracao de modelo 3D neste ambiente (ver changelog 2026-08-04). Entao vale a
## mesma escolha do mobiliario urbano (`StreetFurniture.gd`) e das gambiarras
## (`GambiarraVisual.gd`): montar com esfera, capsula e caixa.
##
## Espaco de montagem: o no nasce na origem do OSSO `Head` do esqueleto do
## personagem (medido: fica em y = 1.55 do modelo, com os eixos praticamente
## alinhados com o mundo, e o rosto olhando pro **+Z**). Todas as medidas abaixo
## sao em metros a partir dali.
##
## A caixa craniana e generosa DE PROPOSITO: ela precisa ENGOLIR a cabeca
## humana do modelo, que faz parte da mesma malha do corpo e por isso nao pode
## ser escondida sozinha. Medido no arquivo, a cabeca ocupa x ±0.12,
## y 1.50..1.78 e z -0.16..0.11 — ou seja, relativo ao osso, de -0.05 a +0.23
## em Y. O crânio abaixo cobre isso com folga.

## Malhas do personagem que somem quando a cabeca de jegue entra: cabelo, olhos
## e sobrancelha sao malhas SEPARADAS no .glb, entao dá pra escondê-las. A
## cabeça humana em si NAO da — ela faz parte da mesma malha do corpo —, e por
## isso o crânio abaixo tem que engolir ela.
##
## O cabelo entra por PREFIXO, e nao por nome exato: medido nos dois arquivos, o
## modelo feminino usa `Hair_Long` e o masculino `Hair_SimpleParted`. Com a
## lista de nomes fixos que existia aqui, o cabelo do homem continuava ligado e
## aparecia atravessando o crânio.
const HIDE_MESHES: Array[String] = ["Eyes", "Eyebrows"]
const HIDE_PREFIXES: Array[String] = ["Hair"]

## Esta malha some quando a cabeca de jegue entra?
static func is_head_part(mesh_name: String) -> bool:
	if HIDE_MESHES.has(mesh_name):
		return true
	for prefix: String in HIDE_PREFIXES:
		if mesh_name.begins_with(prefix):
			return true
	return false

const FUR := Color(0.45, 0.41, 0.38)        ## pelo cinza-pardo de jegue
const FUR_DARK := Color(0.30, 0.27, 0.25)
const MUZZLE := Color(0.82, 0.78, 0.72)     ## focinho e volta dos olhos claros
const MANE := Color(0.19, 0.16, 0.15)
const EYE := Color(0.06, 0.05, 0.05)
const WHITE := Color(0.94, 0.94, 0.92)
const NOSTRIL := Color(0.16, 0.13, 0.12)

## Crânio. A crina é montada A PARTIR destes números (não de uma curva escrita
## à mão do lado), então ela continua colada na cabeça se o crânio mudar.
const SKULL_CENTER := Vector3(0.0, 0.10, 0.01)
const SKULL_RADII := Vector3(0.15, 0.17, 0.18)
const SKULL_TILT := -8.0

## Contas da crina. Precisa ser denso o bastante pro raio de cada esfera passar
## do passo entre elas — é isso que funde a fileira numa crista só.
const MANE_SEGMENTS := 26
## Varredura da crina sobre o crânio, em graus: 0 é o alto da cabeça, negativo
## vai descendo por trás. Começa um pouco à frente do topo (onde nasce o
## topete) e morre embaixo da nuca.
const MANE_FROM := 25.0
const MANE_TO := -140.0

## Ponto na superfície do crânio para um ângulo da varredura acima.
## `lift` > 1 põe o ponto pra fora da casca — é o que faz a crina se destacar
## em vez de sumir dentro do crânio.
static func _skull_point(angle_deg: float, lift: float) -> Vector3:
	var a := deg_to_rad(angle_deg)
	var offset := Vector3(0.0, SKULL_RADII.y * cos(a), SKULL_RADII.z * sin(a)) * lift
	return SKULL_CENTER + offset.rotated(Vector3.RIGHT, deg_to_rad(SKULL_TILT))

static func _material(color: Color, rough := 0.72) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.0
	return m

static func _sphere(parent: Node3D, size: Vector3, pos: Vector3, color: Color,
		rot := Vector3.ZERO, rough := 0.72) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 12
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(color, rough)
	mi.scale = size
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(color)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

# ------------------------------------------------- encaixe em modelo qualquer
#
# Ate 2026-08-10 a cabeca so servia nos dois personagens NATIVOS: as medidas
# acima sao em metros a partir do osso `Head` deles, e os 42 modelos baixados
# tem osso com outro nome, cabeca de outro tamanho e esqueleto em outra escala
# (de 0,7 a 208 unidades no arquivo). Posta crua num deles, a cabeca sai
# minuscula ao lado do pescoco ou engolindo o corpo inteiro.
#
# A saida e MEDIR a cabeca humana de cada modelo e encaixar a de jegue em cima —
# mesma disciplina do resto do projeto: a caixa da cabeca sai dos vertices, nao
# de constante escrita por modelo.

## A cabeca humana pra qual as medidas deste arquivo foram calibradas, em
## espaco do osso `Head` do modelo nativo. Medida nos vertices, nao estimada.
## E a partir dela que se calcula quanto crescer pra engolir a cabeca de outro
## modelo.
const CABECA_REFERENCIA := AABB(Vector3(-0.12, -0.05, -0.16), Vector3(0.24, 0.28, 0.27))

## Nome de osso que NAO e a cabeca, mesmo contendo "head". Levantado medindo os
## 44 rigs: mixamo poe `HeadTop_End`, rigify poe `forehead.L` e `MCH-ROT-head`,
## e o importador do Godot ainda acrescenta `_end`.
const NAO_E_CABECA: Array[String] = ["forehead", "end", "top", "mch", "nub", "tip"]

## Acha o osso da cabeca. Devolve -1 quando nao da.
##
## Por nome, com desempate: `head` exato ganha de `..._head`, que ganha de
## `head...`. Isso resolve os quatro padroes que apareceram nos 44 modelos —
## `Head`, `mixamorig_Head`, `CC_Base_Head`, `Bip01_Head`, `girlBone_Head`,
## `head_Armature` — sem uma lista de nome por modelo.
static func achar_osso(skeleton: Skeleton3D) -> int:
	if skeleton == null:
		return -1
	var melhor := -1
	var melhor_nota := 0
	for i in range(skeleton.get_bone_count()):
		var nome := _sem_sufixo(str(skeleton.get_bone_name(i)))
		var proibido := false
		for veto: String in NAO_E_CABECA:
			if nome.contains(veto):
				proibido = true
				break
		if proibido:
			continue
		var nota := 0
		if nome == "head":
			nota = 3
		elif nome.ends_with("head"):
			nota = 2
		elif nome.begins_with("head"):
			nota = 1
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = i
	return melhor

## Quando NENHUM osso tem "head" no nome (medido: 2 dos 44 — um rig com ossos
## chamados `Bone.004` e outro so com nomes de rigify), o osso da cabeca e
## achado pela geometria: aquele cujos vertices ficam mais no alto do corpo.
##
## Cobra uma fatia minima de vertices de proposito: sem isso, ganharia um osso
## de cabelo ou de acessorio, que fica ainda mais alto e move quase nada.
static func _osso_mais_alto_com_malha(skeleton: Skeleton3D, raiz: Node) -> int:
	var soma: Dictionary = {}
	var quantos: Dictionary = {}
	var total := 0
	for mi in _malhas_do_esqueleto(raiz, skeleton):
		var bind_pro_osso: Array[int] = []
		var mats: Array[Transform3D] = []
		for b in range(mi.skin.get_bind_count()):
			var idx := mi.skin.get_bind_bone(b)
			if idx < 0:
				idx = skeleton.find_bone(mi.skin.get_bind_name(b))
			bind_pro_osso.append(idx)
			mats.append(skeleton.get_bone_global_pose(idx) * mi.skin.get_bind_pose(b) \
				if idx >= 0 else Transform3D())
		for s in range(mi.mesh.get_surface_count()):
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ossos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if verts.is_empty() or ossos.is_empty():
				continue
			var por_vert: int = ossos.size() / verts.size()
			for v in range(verts.size()):
				var dom := -1
				var maior := 0.0
				for k in range(por_vert):
					var w := pesos[v * por_vert + k]
					if w > maior:
						maior = w
						dom = ossos[v * por_vert + k]
				if dom < 0 or dom >= bind_pro_osso.size() or bind_pro_osso[dom] < 0:
					continue
				var b_idx: int = bind_pro_osso[dom]
				var y: float = (mats[dom] * verts[v]).y
				soma[b_idx] = float(soma.get(b_idx, 0.0)) + y
				quantos[b_idx] = int(quantos.get(b_idx, 0)) + 1
				total += 1
	var melhor := -1
	var melhor_y := -1e20
	for b_idx: int in soma:
		if int(quantos[b_idx]) < maxi(1, total / 100):
			continue
		var media: float = float(soma[b_idx]) / float(quantos[b_idx])
		if media > melhor_y:
			melhor_y = media
			melhor = b_idx
	return melhor

## Tira o sufixo que o importador do Godot poe no nome do osso (`Head_17`,
## `CC_Base_Head_038`) e normaliza pra minuscula.
static func _sem_sufixo(nome: String) -> String:
	var limpo := nome.to_lower()
	var corte := limpo.rfind("_")
	if corte > 0 and limpo.substr(corte + 1).is_valid_int():
		limpo = limpo.substr(0, corte)
	return limpo

## A caixa da cabeca HUMANA do modelo, em espaco do osso (so transladado, com os
## eixos do modelo — a rotacao do osso e cancelada na hora de pendurar).
##
## Entram DOIS conjuntos de vertices, unidos:
##
##   1. os dominados pelo osso da cabeca e pelos DESCENDENTES dele — em rig com
##      rosto detalhado (rigify, Character Creator) a testa, o queixo e a
##      bochecha sao ossos filhos, e sem eles a caixa nao cobre o rosto;

## Tentei acrescentar "todo vertice acima da origem do osso" pra pegar cabelo
## presa fora da cabeca, e DESISTI: em varios rigs a origem do osso nao fica na
## altura do pescoco no espaco medido, entao a regra engolia o corpo inteiro e a
## caixa da "cabeca" saia igual a do corpo — a proporcao dava 100%, a medida era
## reprovada e a cabeca de jegue nascia com 9 cm.
## Devolve `{"cabeca": AABB, "corpo": AABB}`, as duas NO MESMO ESPACO.
##
## Medir as duas juntas nao e comodidade: a cabeca sai dos vertices ja levados
## pelo skin, e a altura do corpo precisa vir da MESMA conta. Medindo o corpo
## pelas posicoes dos ossos, os dois numeros ficam em espacos diferentes —
## medido, ha rig em que os ossos ocupam 0,3 enquanto a malha ocupa 1,8, porque
## a escala mora na bind pose. Comparando um com o outro, a cabeca "media" dava
## 110% do corpo, era reprovada como implausivel e caia numa estimativa
## minuscula: 3 cm de largura, invisivel dentro da cabeca humana.
static func medir_cabeca(skeleton: Skeleton3D, osso: int, raiz: Node) -> Dictionary:
	if skeleton == null or osso < 0:
		return {"cabeca": AABB(), "corpo": AABB()}
	var familia := {osso: true}
	for i in range(skeleton.get_bone_count()):
		var p := skeleton.get_bone_parent(i)
		while p >= 0:
			if p == osso:
				familia[i] = true
				break
			p = skeleton.get_bone_parent(p)
	var origem: Vector3 = skeleton.get_bone_global_pose(osso).origin
	var caixa := AABB()
	var corpo := AABB()
	var primeiro := true
	var primeiro_corpo := true
	for mi in _malhas_do_esqueleto(raiz, skeleton):
		# ARMADILHA: o indice guardado em `ARRAY_BONES` NAO e o indice do osso no
		# esqueleto — e a posicao dentro da lista de binds do skin. Comparar um
		# com o outro faz o teste "este vertice e da cabeca?" acertar por acaso e
		# errar na maioria, que foi o que pos a cabeca de jegue a 37% da altura em
		# tres modelos.
		var bind_pro_osso: Array[int] = []
		var mats: Array[Transform3D] = []
		for b in range(mi.skin.get_bind_count()):
			var idx := mi.skin.get_bind_bone(b)
			if idx < 0:
				idx = skeleton.find_bone(mi.skin.get_bind_name(b))
			bind_pro_osso.append(idx)
			mats.append(skeleton.get_bone_global_pose(idx) * mi.skin.get_bind_pose(b) \
				if idx >= 0 else Transform3D())
		for s in range(mi.mesh.get_surface_count()):
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ossos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if verts.is_empty() or ossos.is_empty():
				continue
			var por_vert: int = ossos.size() / verts.size()
			for v in range(verts.size()):
				var dominante := -1
				var maior := 0.0
				for k in range(por_vert):
					var w := pesos[v * por_vert + k]
					if w > maior:
						maior = w
						dominante = ossos[v * por_vert + k]
				if dominante < 0 or dominante >= bind_pro_osso.size():
					continue
				var p: Vector3 = (mats[dominante] * verts[v]) - origem
				if primeiro_corpo:
					corpo = AABB(p, Vector3.ZERO)
					primeiro_corpo = false
				else:
					corpo = corpo.expand(p)
				if not familia.has(bind_pro_osso[dominante]):
					continue
				if primeiro:
					caixa = AABB(p, Vector3.ZERO)
					primeiro = false
				else:
					caixa = caixa.expand(p)
	return {"cabeca": caixa, "corpo": corpo}

## Altura do corpo pelas posicoes de repouso dos ossos. Serve de escala de
## referencia: os ossos ficam dentro do corpo, entao a medida e um piso
## confiavel mesmo quando alguma malha do arquivo tem a bind pose quebrada.
static func altura_pelos_ossos(skeleton: Skeleton3D) -> float:
	var alto := -1e20
	var baixo := 1e20
	for i in range(skeleton.get_bone_count()):
		var y: float = skeleton.get_bone_global_pose(i).origin.y
		alto = maxf(alto, y)
		baixo = minf(baixo, y)
	return maxf(alto - baixo, 0.0)

## A altura do CORPO do modelo nativo, medida na mesma conta (vertice levado
## pelo skin). E daqui que sai o tamanho de cabeca estimado quando a medida do
## proprio modelo nao e confiavel.
const ALTURA_CORPO_REFERENCIA := 1.79

## Quanto da altura da pessoa a cabeca ocupa. Medido nos dois nativos
## (0,276/1,788 e 0,288/1,852). E o numero que dimensiona a cabeca de jegue
## quando a medida do proprio arquivo nao e confiavel.
const CABECA_DA_ALTURA := 0.155

## As malhas skinadas DESTE personagem. A busca comeca na raiz do visual, e nao
## nos filhos diretos do `Skeleton3D` (nem todo exportador pendura a malha
## embaixo do esqueleto) nem subindo a arvore ate o topo — subindo, na folha de
## contato, onde os personagens sao irmaos, eu media a cabeca de um com o corpo
## do vizinho e a cabeca de jegue saia com 184 m.
static func _malhas_do_esqueleto(raiz: Node, skeleton: Skeleton3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	_coletar_malhas(raiz, skeleton, out)
	return out

static func _coletar_malhas(node: Node, skeleton: Skeleton3D,
		out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		# TODA malha skinada do personagem entra, sem cobrar que o `skeleton`
		# dela resolva pra este no. Cobrando, o corpo ficava de fora em varios
		# modelos (o caminho relativo nao resolve do jeito esperado) e sobrava so
		# a malha da cabeca: o "corpo" media 0,33 contra 0,32 da cabeca, a
		# proporcao dava 97%, a medida era reprovada e a cabeca de jegue nascia
		# com 9 cm. Personagem com mais de um esqueleto ja foi reprovado antes,
		# no catalogo, entao aqui so ha um.
		if mi.skin != null and mi.mesh != null:
			out.append(mi)
	for c in node.get_children():
		_coletar_malhas(c, skeleton, out)

## Pendura a cabeca de jegue no osso da cabeca de QUALQUER modelo, do tamanho
## certo. Devolve o no criado, ou nulo se o modelo nao tem osso de cabeca.
## `altura_mundo` e a altura que o personagem tem NA CENA, em metros. Ela e a
## ancora do dimensionamento: medir a cabeca dentro do arquivo funciona na
## maioria, mas ha rig em que o espaco do skin nao bate com o que e desenhado (o
## corpo "mede" 0,33 pra um boneco de 1,80 m). Nesses, a cabeca sai de uma
## fracao da altura de mundo, convertida pela escala real do osso — duas
## grandezas que nao dependem de como o arquivo foi montado.
static func attach_to(visual: Node3D, altura_mundo := 1.80) -> Node3D:
	var skeleton := CharacterVisual.find_skeleton(visual)
	if skeleton == null:
		return null
	var osso := achar_osso(skeleton)
	var por_geometria := false
	if osso < 0:
		osso = _osso_mais_alto_com_malha(skeleton, visual)
		por_geometria = true
	if osso < 0:
		return null
	# Tudo aqui le a POSE do osso, e nao o REST, porque e a pose que o
	# `BoneAttachment3D` usa pra pendurar e e ela que aparece na tela. Nem todo
	# rig guarda a orientacao no rest: medido nos 44, varios chegam com o rest
	# quase zerado e a postura inteira na pose — lendo o rest, a altura do corpo
	# saia perto de zero e a cabeca de jegue nascia com 3 cm de largura, invisivel
	# dentro da cabeca humana.
	skeleton.force_update_all_bone_transforms()
	# A medida so vale se for PLAUSIVEL. Um arquivo com bind pose quebrada
	# (medido: um dos 44 tem uma malha 16x fora de lugar) devolve uma caixa
	# enorme, e a cabeca de jegue saía a 16 m do chão. Cabeca de gente fica entre
	# 8% e 32% da altura do corpo e perto do osso — fora disso, a medida do
	# arquivo não é confiável e vale a estimativa pela escala do esqueleto.
	var medida := medir_cabeca(skeleton, osso, visual)
	var alvo: AABB = medida["cabeca"]
	var altura: float = (medida["corpo"] as AABB).size.y
	if altura <= 0.0:
		altura = altura_pelos_ossos(skeleton)
	var proporcao: float = alvo.size.y / maxf(altura, 0.001)
	var confiavel: bool = proporcao >= 0.08 and proporcao <= 0.32 \
		and alvo.get_center().length() <= altura * 0.25

	var attach := BoneAttachment3D.new()
	attach.name = "CabecaAttach"
	skeleton.add_child(attach)
	attach.bone_idx = osso

	# O palpite geometrico so vale se cair no ALTO do corpo. Sem esta trava, o
	# unico modelo em que ele erra (um rig de anime sem nenhum osso com "head" no
	# nome) ganhava a cabeca de jegue no PEITO, como se estivesse carregando ela.
	# Cabeca nenhuma e melhor que cabeca no lugar errado.
	if por_geometria and visual.global_transform.origin.y + altura_mundo * 0.72 \
			> attach.global_transform.origin.y:
		attach.queue_free()
		return null

	# Daqui pra baixo TUDO em metros de mundo. `CABECA_REFERENCIA` ja esta nessa
	# unidade (foi medida no modelo nativo, que e 1:1 em metros), e o berco abaixo
	# nasce sem escala nenhuma — entao converter aqui deixa uma unidade so no
	# resto da conta, em vez de misturar unidade de arquivo com metro.
	var escala: float = maxf(attach.global_transform.basis.get_scale().y, 1e-6)
	if confiavel:
		alvo = AABB(alvo.position * escala, alvo.size * escala)
	else:
		# Sem medida confiavel, a cabeca sai de uma FRACAO da altura do
		# personagem na cena — que e um numero que nao depende de como o arquivo
		# foi montado.
		var k_ref: float = CABECA_DA_ALTURA * altura_mundo / CABECA_REFERENCIA.size.y
		alvo = AABB(CABECA_REFERENCIA.position * k_ref, CABECA_REFERENCIA.size * k_ref)

	# A cabeca e montada nos eixos do MODELO, e o osso pode estar girado em
	# relacao a ele (mixamo deita o eixo do pescoco, rigify usa outro). O
	# alinhamento sai dos transforms de MUNDO — a base real do ponto de encaixe
	# contra a base real do personagem —, e nao da base de repouso do osso:
	# cancelando a de repouso, os rigs cujo espaco de skin nao bate com o
	# desenhado recebiam a cabeca DEITADA em cima do craniо, feito chapeu.
	#
	# O que sobra depois disso e o giro da ANIMACAO, que e justamente o que deve
	# mexer a cabeca junto com o pescoco.
	var berco := Node3D.new()
	berco.name = "CabecaBerco"
	attach.add_child(berco)
	berco.global_transform = Transform3D(
		visual.global_transform.basis.orthonormalized(),
		attach.global_transform.origin)
	var cabeca := build()
	# Cresce o bastante pra ENGOLIR a cabeca humana nos tres eixos (ela nao pode
	# ser escondida: na maioria dos modelos faz parte da mesma malha do corpo).
	var k: float = maxf(alvo.size.x / CABECA_REFERENCIA.size.x,
		maxf(alvo.size.y / CABECA_REFERENCIA.size.y,
			alvo.size.z / CABECA_REFERENCIA.size.z))
	cabeca.scale = Vector3.ONE * k
	cabeca.position = alvo.get_center() - CABECA_REFERENCIA.get_center() * k
	# Pro verificador poder cobrar o TAMANHO, e nao so a posicao: cabeca no lugar
	# certo mas pequena demais some dentro da cabeca humana, e a foto mostra o
	# personagem sem cabeca de jegue nenhuma.
	cabeca.set_meta("alvo_medido", alvo)
	cabeca.set_meta("altura_ossos", altura)
	cabeca.set_meta("diag", "cabeca=%.3f corpo=%.3f prop=%.3f k=%.3f estimou=%s"
		% [(medida["cabeca"] as AABB).size.y, altura, proporcao, k,
			"sim" if alvo != (medida["cabeca"] as AABB) else "nao"])

	berco.add_child(cabeca)
	return cabeca

## Monta a cabeca. O +Z do no devolvido e a direcao do FOCINHO.
static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "CabecaDeJegue"

	# ------------------------------------------------------------- crânio
	# Engole a cabeca humana (ver o comentario do topo). Ligeiramente ovalado e
	# inclinado pra frente, que e o formato de cabeca de equino.
	# A escala de `_sphere` é o DIÂMETRO (a esfera base tem raio 0.5), por isso
	# o dobro dos raios.
	_sphere(root, SKULL_RADII * 2.0, SKULL_CENTER, FUR,
		Vector3(deg_to_rad(SKULL_TILT), 0.0, 0.0))
	# Testa/topete: a saliencia entre as orelhas.
	_sphere(root, Vector3(0.22, 0.14, 0.20), Vector3(0.0, 0.235, 0.03), FUR)

	# ------------------------------------------------------------- focinho
	# Duas peças: o cano do nariz (mais fino) e a boca/venta (mais clara). Um
	# focinho de peça só sai como bico e não lê como jegue.
	#
	# A ponta tem que ser MAIS ESTREITA que o cano: na primeira versão ela era
	# mais larga (0.20 contra 0.19) e formava um degrau, então lia como um bulbo
	# pálido grudado na cara em vez de focinho. Ela também recuou pra sobrepor
	# mais o cano — o que emenda as duas peças em uma forma só.
	# O cano CAI da testa pra ponta (12°, era 6°) e ficou mais curto: esticado e
	# quase na horizontal, o focinho lia como tubo de tamanduá. Cabeça de equino
	# tem a linha do nariz descendo.
	_sphere(root, Vector3(0.185, 0.175, 0.27), Vector3(0.0, 0.038, 0.185), FUR,
		Vector3(deg_to_rad(12.0), 0.0, 0.0))
	_sphere(root, Vector3(0.170, 0.155, 0.175), Vector3(0.0, -0.005, 0.272), MUZZLE)
	# Beiço de baixo, um pouco solto — é o detalhe que dá o ar bocó do bicho.
	_sphere(root, Vector3(0.128, 0.078, 0.118), Vector3(0.0, -0.050, 0.272), MUZZLE)

	for side in [-1.0, 1.0]:
		# Ventas. Pequenas DE PROPÓSITO: na primeira versão mediam 4.5 x 5.5 cm
		# e, quase pretas sobre o focinho claro, liam como um SEGUNDO par de
		# olhos no meio da cara (o bicho parecia ter quatro). Inclinadas pra
		# fora, que é o desenho da venta de equino.
		_sphere(root, Vector3(0.030, 0.040, 0.032), Vector3(side * 0.044, 0.010, 0.340),
			NOSTRIL, Vector3(0.0, 0.0, deg_to_rad(side * 18.0)), 0.45)
		# ------------------------------------------------------------ olhos
		# Bem pro lado da cabeça, como em qualquer herbívoro — olho de frente
		# lê como pessoa fantasiada.
		_sphere(root, Vector3(0.075, 0.085, 0.075), Vector3(side * 0.125, 0.145, 0.115),
			EYE, Vector3.ZERO, 0.18)
		# Brilho: sem ele o olho preto vira buraco (a mesma lição da fachada).
		# Pequeno — a 2.6 cm ele tomava metade do olho e virava olho esbugalhado
		# de desenho, não reflexo.
		_sphere(root, Vector3(0.018, 0.018, 0.018),
			Vector3(side * 0.140, 0.172, 0.142), WHITE, Vector3.ZERO, 0.1)
		# Pálpebra clara por cima, que é o que marca a cara de jegue.
		_sphere(root, Vector3(0.095, 0.045, 0.09), Vector3(side * 0.122, 0.185, 0.11),
			MUZZLE)

		# --------------------------------------------------------- orelhas
		# A assinatura do bicho: longas, estreitas e abertas pra fora. Uma
		# cápsula dá a ponta arredondada sem custar geometria.
		var ear := Node3D.new()
		ear.position = Vector3(side * 0.085, 0.235, -0.01)
		ear.rotation = Vector3(deg_to_rad(-12.0), 0.0, deg_to_rad(side * -20.0))
		root.add_child(ear)
		var outer := CapsuleMesh.new()
		outer.radius = 0.5
		outer.height = 2.0
		outer.radial_segments = 12
		outer.rings = 6
		var ear_mi := MeshInstance3D.new()
		ear_mi.mesh = outer
		ear_mi.material_override = _material(FUR)
		ear_mi.scale = Vector3(0.085, 0.17, 0.055)
		ear_mi.position = Vector3(0.0, 0.17, 0.0)
		ear.add_child(ear_mi)
		# Miolo claro, levemente à frente: é o que faz a orelha ter FRENTE e
		# não parecer um chifre.
		var inner := CapsuleMesh.new()
		inner.radius = 0.5
		inner.height = 2.0
		inner.radial_segments = 10
		inner.rings = 5
		var inner_mi := MeshInstance3D.new()
		inner_mi.mesh = inner
		inner_mi.material_override = _material(MUZZLE)
		inner_mi.scale = Vector3(0.05, 0.145, 0.03)
		inner_mi.position = Vector3(0.0, 0.165, 0.022)
		ear.add_child(inner_mi)

	# --------------------------------------------------------------- crina
	# Faixa escura descendo da testa pela nuca.
	#
	# Duas versões erradas antes desta, as duas pelo mesmo motivo — a crina
	# ficava SOLTA da cabeça em vez de nascer nela:
	#   1. 5 esferas espaçadas e inclinadas uma a uma: girar cada uma afastava
	#      as pontas do eixo longo e saía um colar de contas soltas.
	#   2. contas densas ao longo de uma curva escrita à mão: virou um tubo
	#      levantado no meio da nuca, tipo lagarta.
	# Agora os pontos saem da PRÓPRIA casca do crânio (`_skull_point`), só um
	# pouco pra fora: metade de cada esfera fica enterrada, então o que aparece
	# é uma crista rente à cabeça — que é como crina de burro se comporta.
	for i in range(MANE_SEGMENTS):
		var t := float(i) / float(MANE_SEGMENTS - 1)
		# Larga em cima e afinando pra nuca, senão a crista sai reta.
		var wide := lerpf(0.105, 0.052, t)
		var thick := lerpf(0.058, 0.034, t)
		_sphere(root, Vector3(wide, thick, thick),
			_skull_point(lerpf(MANE_FROM, MANE_TO, t), 1.02), MANE, Vector3.ZERO, 0.85)

	# Topete caído na testa, entre as orelhas. Achatado: alto demais ele lia
	# como um chifre no meio do crânio.
	_sphere(root, Vector3(0.105, 0.048, 0.10), Vector3(0.0, 0.272, 0.064), MANE,
		Vector3(deg_to_rad(32.0), 0.0, 0.0), 0.85)

	# ----------------------------------------------------------------- boca
	_box(root, Vector3(0.090, 0.011, 0.046), Vector3(0.0, -0.028, 0.326), FUR_DARK,
		Vector3(deg_to_rad(12.0), 0.0, 0.0))

	return root
