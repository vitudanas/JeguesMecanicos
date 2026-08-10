class_name MedirPersonagem
extends RefCounted
## Mede um personagem 3D recebido de terceiro: altura e se e mesmo UMA pessoa
## de pe.
##
## PRA QUE LADO ELE OLHA NAO SE MEDE AQUI, e isso foi tentado e descartado com
## numero na mao. O sinal geometrico que parecia obvio — o dedo do pe avanca
## alem do quadril, entao o centro da nuvem la embaixo aponta pra frente — foi
## medido nos 36 e erra nos DOIS sentidos: acusou de costas o `frank_army_man`,
## o `fuse_civilian_1`, o `nathan` e o `nilda`, que a foto mostra de frente, e
## deixou passar o `old_man_spice`, que esta mesmo de costas. Testado tambem na
## pose animada (nao so na de repouso) e continuou errando. Sinal que erra nos
## dois sentidos e pior que sinal nenhum: aplicado, giraria 18 personagens
## certos pra consertar 2. Quem sabe disso e a folha de contato, e a lista dos
## que precisam de giro esta em `preparar_personagens.gd`, conferida na foto.
##
## Existe como dono unico porque tres coisas leem estas medidas — o gerador do
## catalogo (`tools/preparar_personagens.gd`), a folha de contato
## (`tools/verify/personagens_sheet.gd`) e o verificador — e medida repetida em
## tres lugares vira tres medidas. Foi exatamente o que aconteceu em 2026-08-10:
## o catalogo dizia 1,80 m pra todo mundo e a folha mostrava personagem
## microscopico ao lado de gigante.
##
## O PONTO CENTRAL: numa malha SKINADA, `mesh.get_aabb()` NAO diz o tamanho que
## aparece na tela. Os vertices ficam no espaco em que a malha foi autorada, e
## quem os leva pro espaco do esqueleto e a bind pose — entao a caixa crua pode
## estar em outra unidade e ate em outro eixo. Medido nos 46 arquivos recebidos:
## `casual_woman_in_brown_dress` da 0,019 na caixa crua e 1,899 depois do skin
## (98x de erro), e `animated_man` da 1471 contra 114 (13x). Aqui a medida sai
## do vertice JA LEVADO pelo skin, que e o que o renderizador desenha.

## Quantos vertices amostrar por superficie. Pra medir altura e orientacao 3000
## bastam; 50 mil custam minutos em GDScript.
const AMOSTRA := 3000

## Acima disso a medida do skin nao e confiavel: alguma malha do arquivo tem a
## bind pose quebrada e estica a nuvem. Os ossos ficam DENTRO do corpo, entao
## servem de piso — a altura real fica entre 1,00 e 1,19x a extensao deles
## (medido nos 46). So a INFLACAO reprova: quando o skin da MENOS que os ossos,
## quem esta certo e o skin (o rig tem osso auxiliar fora do corpo), e foi assim
## que o `stickman` saiu com metade do tamanho pedido.
const RAZAO_MAX := 1.45

## Um humano de pe e alto e fino. Acima disso o arquivo nao e alguem em pe: e
## alguem SENTADO (o `old_fat_man` vem com a poltrona junto) ou uma cena.
const PROFUNDIDADE_MAX := 0.75

## Quanto o desenho inteiro pode passar da altura da pessoa. Um personagem em
## T-pose chega a ~1,15x (a envergadura), entao 2,2x so acontece quando ha OUTRA
## COISA no arquivo — e ha: varios modelos de portfolio vem com o cenario do
## render junto (o `chibi_rem_confession` traz um diorama com ceu, montanha e
## arvore; outro traz um painel com a ilustracao da personagem). Na tela isso
## aparece como um outdoor gigante seguindo o jogador.
const CENARIO_MAX := 2.2

## Mede `inst` (a cena do modelo, ja dentro da arvore) e devolve tudo que o
## catalogo precisa saber.
static func medir(inst: Node3D) -> Dictionary:
	var esqueletos := esqueletos_de(inst)
	var pontos := _nuvem_skinada(inst, esqueletos)
	var caixa := _caixa(pontos)
	if pontos.is_empty():
		caixa = _caixa_malhas(inst)   # estatua: sem skin, a caixa da malha e o que ha

	var deitado: bool = caixa.size.z > caixa.size.y * 1.4
	var altura: float = caixa.size.z if deitado else caixa.size.y

	var suspeita := ""
	var altura_ossos := 0.0
	if not esqueletos.is_empty():
		altura_ossos = _caixa_ossos(esqueletos[0]).size.y
		if altura_ossos > 0.0 and altura / altura_ossos > RAZAO_MAX:
			suspeita = "skin %.2f x ossos %.2f (%.1fx)" % [
				altura, altura_ossos, altura / altura_ossos]
			altura = altura_ossos / 0.90

	# O DESENHO inteiro, e nao so a pessoa: o que nao tem skin renderiza pelo
	# transform do proprio no, entao a caixa da malha vale pra esses (e so pra
	# esses — ver o cabecalho).
	#
	# Com a medida do skin sob suspeita, a base passa a ser a dos OSSOS: senao a
	# mesma malha de bind quebrada que ja enganou a altura seria lida como
	# cenario. Medido: o `virtual_model` dava 14,5x aqui e a foto mostra so uma
	# pessoa.
	var total := _caixa_ossos(esqueletos[0]) if suspeita != "" and not esqueletos.is_empty() \
		else _caixa(pontos)
	for mi in malhas_de(inst):
		if mi.mesh == null or mi.skin != null:
			continue
		total = total.merge(mi.global_transform * mi.mesh.get_aabb())
	var maior: float = maxf(total.size.x, maxf(total.size.y, total.size.z))

	var profundidade: float = caixa.size.z / maxf(caixa.size.y, 0.001)
	var motivo := ""
	if esqueletos.is_empty() or esqueletos[0].get_bone_count() == 0:
		motivo = "sem esqueleto (estatua: nao anda)"
	elif esqueletos.size() > 1:
		motivo = "%d esqueletos — e uma CENA com varios personagens" % esqueletos.size()
	elif profundidade > PROFUNDIDADE_MAX and not deitado:
		motivo = "fundo demais pra estar de pe (z/y = %.2f: sentado ou com cenario junto)" \
			% profundidade
	elif altura > 0.0 and maior > altura * CENARIO_MAX:
		motivo = "vem com CENARIO junto (o desenho mede %.1fx a pessoa)" % (maior / altura)

	return {
		"altura": altura,
		"altura_ossos": altura_ossos,
		"maior_desenho": maior,
		"deitado": deitado,
		"ossos": esqueletos[0].get_bone_count() if not esqueletos.is_empty() else 0,
		"esqueletos": esqueletos.size(),
		"jogavel": motivo == "",
		"motivo": motivo,
		"suspeita": suspeita,
	}

## A nuvem que o RENDERIZADOR desenha: vertice levado pelo skin (rest do osso
## vezes bind pose) e depois pelo transform do esqueleto.
##
## So a malha presa ao PRIMEIRO esqueleto entra — assim prop nao skinado
## (poltrona, andaime, chao) fica de fora da medida da pessoa.
static func _nuvem_skinada(inst: Node3D, esqueletos: Array[Skeleton3D]) -> PackedVector3Array:
	var out := PackedVector3Array()
	if esqueletos.is_empty():
		return out
	var alvo := esqueletos[0]
	for mi in malhas_de(inst):
		if mi.mesh == null or mi.skin == null:
			continue
		if mi.get_node_or_null(mi.skeleton) != alvo:
			continue
		var mats: Array[Transform3D] = []
		for b in range(mi.skin.get_bind_count()):
			var idx := mi.skin.get_bind_bone(b)
			if idx < 0:
				idx = alvo.find_bone(mi.skin.get_bind_name(b))
			mats.append(alvo.global_transform * alvo.get_bone_global_rest(idx) \
				* mi.skin.get_bind_pose(b) if idx >= 0 else Transform3D())
		for s in range(mi.mesh.get_surface_count()):
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ossos: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var pesos: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if verts.is_empty() or ossos.is_empty():
				continue
			var por_vert: int = ossos.size() / verts.size()
			var passo: int = maxi(1, verts.size() / AMOSTRA)
			for v in range(0, verts.size(), passo):
				var p := Vector3.ZERO
				var total := 0.0
				for k in range(por_vert):
					var w := pesos[v * por_vert + k]
					if w <= 0.0:
						continue
					var bi := ossos[v * por_vert + k]
					if bi < 0 or bi >= mats.size():
						continue
					p += (mats[bi] * verts[v]) * w
					total += w
				if total > 0.0:
					out.append(p / total)
	return out

static func _caixa(pontos: PackedVector3Array) -> AABB:
	if pontos.is_empty():
		return AABB()
	var box := AABB(pontos[0], Vector3.ZERO)
	for p in pontos:
		box = box.expand(p)
	return box

## Extensao pelas posicoes de REST dos ossos: segunda opiniao contra bind pose
## quebrada.
static func _caixa_ossos(s: Skeleton3D) -> AABB:
	var box := AABB()
	var first := true
	for i in range(s.get_bone_count()):
		var p: Vector3 = s.global_transform * s.get_bone_global_rest(i).origin
		if first:
			box = AABB(p, Vector3.ZERO)
			first = false
		else:
			box = box.expand(p)
	return box

static func _caixa_malhas(root: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in malhas_de(root):
		if mi.mesh == null:
			continue
		var world := mi.global_transform * mi.mesh.get_aabb()
		if first:
			box = world
			first = false
		else:
			box = box.merge(world)
	return box

static func malhas_de(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		out.append_array(malhas_de(c))
	return out

static func esqueletos_de(node: Node) -> Array[Skeleton3D]:
	var out: Array[Skeleton3D] = []
	if node is Skeleton3D:
		out.append(node as Skeleton3D)
	for c in node.get_children():
		out.append_array(esqueletos_de(c))
	return out
