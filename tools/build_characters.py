"""Monta os personagens vestidos num arquivo glTF unico, por script.

Problema que isso resolve: a roupa "Peasant" do pacote gratuito e um colete
ABERTO no peito, e por baixo esta o corpo do personagem base — entao aparecia
torso nu na rua. Costurar a abertura na malha nao e confiavel (a peca tem 50
bordas soltas, varias duplicadas), entao a solucao aqui e pintar o torso do
corpo com uma cor de tecido: o que aparece pelo decote vira uma camiseta por
baixo, em vez de pele.

De quebra, junta corpo + roupa + cabelo num arquivo so, o que deixa a
montagem em runtime (CharacterVisual.gd) desnecessaria.

Tambem gera os TIPOS FISICOS como shape keys (morph targets) em vez de um
arquivo por variante: o pacote gratuito so tem 2 corpos, entao a variedade
vem de deformar a malha. Cada shape key ("Bust", "Butt", "Belly", "Bulk",
"Skinny", "Hips") e uma soma de operacoes geometricas aplicadas ao corpo E a
roupa (senao a roupa nao acompanha e a pele vaza). Fazer isso como shape key
tem tres vantagens sobre exportar N personagens prontos: o arquivo quase nao
cresce (delta de vertice, nao textura nova), o esqueleto nao e tocado (a
animacao continua valendo), e o peso de cada forma e sorteado por NPC em
runtime — cada pedestre na rua tem um corpo diferente, nao um de 6.

Rodar:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
      --python tools/build_characters.py
"""
import bmesh
import bpy
import math
import os
from mathutils import Vector
from mathutils.bvhtree import BVHTree

## O caminho sai do PROPRIO arquivo, e nao escrito a mao. Aqui havia
## `/Users/<usuario-local>/Documents/JOGO2/...`, que deixou de existir quando
## o projeto mudou pra `/Users/Shared/JOGO2` (2026-08-08): quem rodasse este
## script depois disso so veria ele quebrar ao abrir o primeiro arquivo. Como o
## Blender recebe o script por `--python tools/build_characters.py`, `__file__` e
## o caminho dele, e `tools/..` e a raiz do projeto.
ROOT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "assets", "quaternius")
BASE = f"{ROOT}/universal-base-characters"
OUT_DIR = f"{ROOT}/characters-dressed"

# Altura que separa "roupa de cima" de "roupa de baixo" na hora de pintar a
# pele coberta (o que fica acima vira cor de camisa, abaixo vira cor de calca).
WAIST_Z = 0.93
# O quanto o corpo fica afundado abaixo do tecido; ate onde procurar tecido
# "por cima" da pele; e quanto o corpo pode ter atravessado o tecido pra ainda
# contar como vazamento. Ver tuck_under_clothes().
CLOTH_CLEARANCE = 0.018
CLOTH_SEARCH = 0.030
# Suavizacao do afundamento: sem ela a pele exposta ao lado do tecido (o
# antebraco na borda da manga) ganharia um degrau. Ver tuck_under_clothes().
TUCK_SMOOTH_ITERS = 6
TUCK_SMOOTH_DECAY = 0.85
# Pele que aparece por FRESTA entre duas pecas (o gibao e a manga sao malhas
# separadas, a bota e a calca tambem): ali nao ha tecido logo acima, mas ha
# tecido em volta. Um leque de raios inclinados distingue isso de pele que
# esta a mostra de verdade, tipo o antebraco na boca da manga.
GAP_RAYS = 8
GAP_TILT = 0.85
GAP_MIN_HITS = 6
# Generoso de proposito: partes inteiras do corpo (costas, coxa, pe) ficavam
# ate ~5cm pra fora do tecido. Passar do tecido pro outro lado do membro nao
# e problema porque o teste olha a ORIENTACAO da face atingida — ver
# tuck_under_clothes().
POKE_DEPTH = 0.060
# Cores em espaco LINEAR (o glTF guarda baseColorFactor assim). Um valor de
# 0.44 linear aparece quase branco na tela — estes ja estao convertidos pra
# casar com o tecido: caqui claro do colete no torso, marrom escuro da calca
# nas pernas, pra pele que escapa nao destoar em nenhum dos dois.
UNDERSHIRT_RGBA = (0.26, 0.24, 0.16, 1.0)
UNDERPANTS_RGBA = (0.055, 0.040, 0.025, 1.0)
# Afasta a roupa da pele pra nao brigar por z-fighting onde encostam.
CLOTHES_INFLATE = 0.004
MAX_TEXTURE = 1024
# Abaixo disso a shape key nao muda nada de visivel — nao vale gravar o alvo
# (glTF grava delta pra TODO vertice, entao um alvo vazio ainda custa espaco).
MIN_DELTA = 0.0005


# --------------------------------------------------------------------------
# Operacoes de deformacao
#
# Coordenadas no espaco do Blender depois de importar o glTF: X e a lateral,
# Z e a altura e a FRENTE do personagem e -Y (medido: os olhos ficam em
# y negativo). Todas as constantes abaixo saem de uma medicao das secoes
# transversais dos dois corpos, nao de chute — ver CLAUDE.md.
# --------------------------------------------------------------------------

def _smoothstep(t: float) -> float:
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


class Push:
    """Empurra a superficie numa direcao, dentro de uma regiao eliptica.

    A regiao e definida no plano lateral/altura (x, z) — que e onde da pra
    apontar "o peito", "a barriga", "o gluteo" olhando a silhueta de frente.
    O gate em Y liga o efeito so de um lado do corpo (senao empurrar o busto
    pra frente arrastaria junto as costas), com transicao suave pra nao
    aparecer degrau na lateral.
    """

    def __init__(self, center, radius, direction, gate):
        self.cx, self.cz = center
        self.rx, self.rz = radius
        self.direction = Vector(direction)
        self.y_off, self.y_on = gate

    def delta(self, co):
        dx = (co.x - self.cx) / self.rx
        dz = (co.z - self.cz) / self.rz
        d = math.sqrt(dx * dx + dz * dz)
        if d >= 1.0:
            return Vector((0.0, 0.0, 0.0))
        # Bump suave: 1 no centro da regiao, 0 na borda, sem quina.
        w = 0.5 * (1.0 + math.cos(math.pi * d))
        g = _smoothstep((co.y - self.y_off) / (self.y_on - self.y_off))
        return self.direction * (w * g)


class Bulge:
    """Infla uma regiao arredondando: cada vertice se AFASTA de um ponto
    dentro do corpo, proporcional a distancia que ja tinha dele.

    Diferenca pro Push, e o motivo de existir: empurrar a superficie toda
    numa direcao so, mais forte no meio que nas bordas, termina em ponta de
    cone. Aqui os tres eixos crescem junto, entao a silhueta fica redonda —
    e o mesmo motivo de o deslocamento poder ser bem menor pra ler igual.
    """

    def __init__(self, center, radius, amount, gate):
        self.center = Vector(center)
        self.radius = Vector(radius)
        self.amount = amount
        self.y_off, self.y_on = gate

    def delta(self, co):
        off = co - self.center
        d = Vector((off.x / self.radius.x, off.y / self.radius.y,
                    off.z / self.radius.z)).length
        if d >= 1.0:
            return Vector((0.0, 0.0, 0.0))
        w = 0.5 * (1.0 + math.cos(math.pi * d))
        g = _smoothstep((co.y - self.y_off) / (self.y_on - self.y_off))
        return off * (self.amount * w * g)


class Thicken:
    """Engrossa (ou afina) um membro afastando os vertices de uma linha central.

    `axis` e a direcao do membro: "z" pro tronco e pernas, "x" pros bracos
    (que na T-pose saem na horizontal). `span` e o trecho ao longo desse eixo,
    com entrada/saida suave nas pontas. `perp_limit` impede que engrossar o
    tronco arraste tambem os bracos, que estao longe da linha central.
    """

    def __init__(self, axis, center, span, amount, perp_limit=(9.0, 10.0)):
        self.axis = axis
        self.ca, self.cb = center
        self.lo, self.hi = span
        self.amount = amount
        self.perp_lo, self.perp_hi = perp_limit

    def delta(self, co):
        if self.axis == "z":
            along, a, b = co.z, co.x - self.ca, co.y - self.cb
        else:
            along, a, b = abs(co.x), co.y - self.ca, co.z - self.cb
        if along <= self.lo or along >= self.hi:
            return Vector((0.0, 0.0, 0.0))
        # Suaviza nas duas pontas do trecho (10% de cada lado).
        edge = (self.hi - self.lo) * 0.18
        w = _smoothstep((along - self.lo) / edge) * _smoothstep((self.hi - along) / edge)
        perp = math.sqrt(a * a + b * b)
        w *= 1.0 - _smoothstep((perp - self.perp_lo) / (self.perp_hi - self.perp_lo))
        if w <= 0.0:
            return Vector((0.0, 0.0, 0.0))
        scale = self.amount * w
        if self.axis == "z":
            return Vector((a * scale, b * scale, 0.0))
        return Vector((0.0, a * scale, b * scale))


def mirrored(op):
    """Mesma operacao espelhada no eixo X (par de seios, gluteos, pernas...).

    Thicken no eixo "x" (os bracos) ja e simetrico por construcao, porque mede
    a posicao ao longo do braco como abs(x) — espelhar ali so estragaria o
    centro, que naquele caso e um par (y, z), nao uma posicao lateral.
    """
    if isinstance(op, Bulge):
        twin = Bulge((-op.center.x, op.center.y, op.center.z), op.radius,
                     op.amount, (op.y_off, op.y_on))
    elif isinstance(op, Push):
        twin = Push((-op.cx, op.cz), (op.rx, op.rz),
                    (-op.direction.x, op.direction.y, op.direction.z),
                    (op.y_off, op.y_on))
    elif op.axis == "x":
        return [op]
    else:
        twin = Thicken(op.axis, (-op.ca, op.cb), (op.lo, op.hi), op.amount,
                       (op.perp_lo, op.perp_hi))
    return [op, twin]


# Frente do corpo (gate "acende" indo pra -y) e costas (indo pra +y).
FRONT = (0.02, -0.09)
BACK = (0.01, 0.10)

FEMALE_SHAPES = {
    # Seio: volume redondo inflado a partir de um ponto dentro do torax
    # (medido: peito em z 1.25-1.35, a frente do torso ali fica em y
    # -0.115..-0.140). O raio em X e curto de proposito, senao as duas
    # bolhas se encontram no esterno e o meio do peito incha junto.
    "Bust": mirrored(Bulge((0.072, -0.025, 1.315), (0.125, 0.185, 0.150),
                           1.15, (0.03, -0.03))),
    # Gluteo: mesma ideia, inflando de dentro do quadril (medido: z
    # 0.85-1.00, as costas ali ja sao o ponto mais recuado do corpo, +0.162).
    # Junto vai a coxa: so o gluteo crescendo fica desproporcional em cima de
    # uma perna fina. O trecho comeca acima do joelho (medido: a perna e mais
    # estreita em z 0.45-0.55, raio 0.058, e engrossa ate 0.092 no topo) e a
    # linha central da coxa fica em x 0.11.
    "Butt": mirrored(Bulge((0.085, 0.065, 0.945), (0.150, 0.160, 0.170),
                           1.0, (0.0, 0.07)))
    + mirrored(Thicken("z", (0.110, 0.020), (0.48, 0.99), 0.20, (0.10, 0.16))),
    # Quadril largo, sem mexer na cintura.
    "Hips": mirrored(Thicken("z", (0.0, 0.01), (0.72, 1.06), 0.16, (0.24, 0.34))),
    "Belly": [Push((0.0, 1.09), (0.20, 0.21), (0.0, -0.085, 0.0), FRONT),
              Thicken("z", (0.0, 0.01), (0.92, 1.28), 0.20, (0.22, 0.32))],
    "Bulk": [Thicken("z", (0.0, 0.01), (0.86, 1.46), 0.15, (0.24, 0.34))]
    + mirrored(Thicken("x", (0.01, 1.40), (0.24, 0.90), 0.22))
    + mirrored(Thicken("z", (0.09, 0.01), (0.05, 0.80), 0.16, (0.20, 0.30))),
    "Skinny": [Thicken("z", (0.0, 0.01), (0.80, 1.50), -0.13, (0.24, 0.34))]
    + mirrored(Thicken("x", (0.01, 1.40), (0.24, 0.90), -0.16))
    + mirrored(Thicken("z", (0.09, 0.01), (0.05, 0.82), -0.12, (0.20, 0.30))),
}

MALE_SHAPES = {
    # Barriga de chope: infla pra frente do peito pra baixo do umbigo.
    "Belly": [Push((0.0, 1.12), (0.22, 0.23), (0.0, -0.105, 0.0), FRONT),
              Thicken("z", (0.0, 0.01), (0.94, 1.32), 0.24, (0.24, 0.34))],
    # Encorpado: tronco, bracos e pernas mais grossos.
    "Bulk": [Thicken("z", (0.0, 0.01), (0.88, 1.48), 0.17, (0.24, 0.34))]
    + mirrored(Thicken("x", (0.02, 1.42), (0.24, 0.92), 0.24))
    + mirrored(Thicken("z", (0.09, 0.01), (0.05, 0.82), 0.16, (0.20, 0.30))),
    # Peito/ombro largo, sem engrossar a cintura.
    "Chest": [Thicken("z", (0.0, 0.01), (1.20, 1.50), 0.20, (0.26, 0.36)),
              Push((0.0, 1.34), (0.26, 0.16), (0.0, -0.030, 0.0), FRONT)],
    "Skinny": [Thicken("z", (0.0, 0.01), (0.80, 1.52), -0.14, (0.24, 0.34))]
    + mirrored(Thicken("x", (0.02, 1.42), (0.24, 0.92), -0.18))
    + mirrored(Thicken("z", (0.09, 0.01), (0.05, 0.82), -0.12, (0.20, 0.30))),
}

VARIANTS = [
    {
        "name": "Male_Dressed",
        "body": f"{BASE}/Characters/Superhero_Male_FullBody.gltf",
        "outfit": f"{ROOT}/outfits-fantasy/Outfits/Male_Peasant.gltf",
        "hair": f"{BASE}/Hairstyles/Hair_SimpleParted.gltf",
        "shapes": MALE_SHAPES,
    },
    {
        "name": "Female_Dressed",
        "body": f"{BASE}/Characters/Superhero_Female_FullBody.gltf",
        "outfit": f"{ROOT}/outfits-fantasy/Outfits/Female_Peasant.gltf",
        "hair": f"{BASE}/Hairstyles/Hair_Long.gltf",
        "shapes": FEMALE_SHAPES,
    },
]


def meshes_and_armature(before):
    """Objetos criados desde o snapshot `before`, separados por tipo."""
    new = [o for o in bpy.data.objects if o.name not in before]
    arm = next((o for o in new if o.type == "ARMATURE"), None)
    meshes = [o for o in new if o.type == "MESH"]
    return meshes, arm


def _cloth_material(name, rgba):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def _in_cloth_gap(bvh, point, normal):
    """Ha tecido em VOLTA deste ponto, mesmo sem ter tecido logo acima dele?

    E o caso da pele que aparece pela emenda entre duas pecas de roupa. Um
    raio so, na direcao da normal, sai pela fresta e nao acha nada — igual ao
    antebraco nu. O que separa os dois casos e o entorno: na fresta quase todo
    o leque de raios inclinados bate em tecido; no antebraco, quase nenhum.
    """
    axis = Vector((0.0, 0.0, 1.0))
    if abs(normal.z) > 0.9:
        axis = Vector((1.0, 0.0, 0.0))
    side = normal.cross(axis).normalized()
    up = normal.cross(side)
    hits = 0
    for k in range(GAP_RAYS):
        angle = 2.0 * math.pi * k / GAP_RAYS
        tilted = (normal * math.cos(GAP_TILT)
                  + (side * math.cos(angle) + up * math.sin(angle)) * math.sin(GAP_TILT))
        if bvh.ray_cast(point + tilted * 1e-4, tilted, CLOTH_SEARCH * 2.0)[3] is not None:
            hits += 1
    return hits >= GAP_MIN_HITS


def tuck_under_clothes(body_mesh_obj, garment_objs):
    """Afunda o corpo por baixo do tecido onde os dois quase se encostam.

    O corpo e a roupa sao malhas independentes, exportadas separadamente pelo
    Quaternius, e em varios pontos a pele fica RENTE ao tecido — na parte de
    dentro do braco e nas costas ela chegava a atravessar.

    A pergunta certa e "existe tecido DIRETAMENTE ACIMA desta pele?", entao o
    teste e um raio saindo do vertice ao longo da propria normal. Medir so a
    distancia ate a roupa mais proxima nao serve: o antebraco nu passa a poucos
    centimetros da manga e o pescoco passa perto da gola, e os dois entrariam
    na conta como se estivessem cobertos.

    Dois casos, os dois resolvidos pelo mesmo empurrao pra dentro:
    - o raio pra fora acha tecido perto demais -> afunda ate CLOTH_CLEARANCE;
    - o raio pra fora nao acha nada mas o de dentro acha a FACE EXTERNA do
      tecido -> o vertice ja furou a roupa, volta pra baixo dela.

    Isso substitui a tentativa antiga de encolher o corpo por um fator unico:
    encolher uniformemente mexia na cabeca junto (o corpo do Quaternius e uma
    malha so) e mesmo assim nao resolvia — o vao entre pele e tecido nao e o
    mesmo em todo lugar, e so medindo ponto a ponto pra saber onde apertar.

    Devolve os indices de vertice cobertos por roupa, que paint_under_clothes()
    usa pra saber onde pintar cor de tecido.
    """
    verts: list = []
    polys: list = []
    for garment in garment_objs:
        offset = len(verts)
        verts.extend(v.co.copy() for v in garment.data.vertices)
        polys.extend([i + offset for i in p.vertices] for p in garment.data.polygons)
    bvh = BVHTree.FromPolygons(verts, polys, all_triangles=False)

    me = body_mesh_obj.data
    normals = [v.normal.copy() for v in me.vertices]
    covered = set()
    need = [0.0] * len(me.vertices)
    poked = 0
    gaps = 0
    for v in me.vertices:
        normal = normals[v.index]
        _loc, _n, _i, above = bvh.ray_cast(v.co + normal * 1e-4, normal, CLOTH_SEARCH)
        if above is not None:
            covered.add(v.index)
            need[v.index] = max(0.0, CLOTH_CLEARANCE - above)
            continue
        _loc, hit_normal, _i, under = bvh.ray_cast(
            v.co - normal * 1e-4, -normal, POKE_DEPTH)
        # Se o raio de volta encontra a face EXTERNA do tecido, o vertice
        # estava do lado de fora dele: e vazamento, nao pele a mostra.
        if under is None or hit_normal.dot(normal) <= 0.0:
            if _in_cloth_gap(bvh, v.co, normal):
                covered.add(v.index)
                # Recua tambem: nao ha tecido por cima pra esconder, mas
                # afundar deixa a pele atras da borda das duas pecas.
                need[v.index] = CLOTH_CLEARANCE
                gaps += 1
            continue
        covered.add(v.index)
        need[v.index] = under + CLOTH_CLEARANCE
        poked += 1

    # Espalha o afundamento pros vizinhos, com perda a cada anel: a pele que
    # fica na fronteira (antebraco na boca da manga) afunda um pouco tambem,
    # entao a transicao vira rampa e nao degrau. O max() garante que ninguem
    # afunde menos do que precisa.
    neighbors: list = [[] for _ in me.vertices]
    for edge in me.edges:
        a, b = edge.vertices
        neighbors[a].append(b)
        neighbors[b].append(a)
    for _ in range(TUCK_SMOOTH_ITERS):
        spread = list(need)
        for i, ring in enumerate(neighbors):
            if not ring:
                continue
            average = sum(need[j] for j in ring) / len(ring)
            spread[i] = max(need[i], average * TUCK_SMOOTH_DECAY)
        need = spread

    moved = 0
    peak = 0.0
    for v in me.vertices:
        if need[v.index] <= 0.0:
            continue
        v.co -= normals[v.index] * need[v.index]
        moved += 1
        peak = max(peak, need[v.index])
    print(f"    afundado sob a roupa: {moved} vertices ({poked} tinham furado, "
          f"max {peak * 100:.1f}cm de {POKE_DEPTH * 100:.0f}cm de alcance), "
          f"{len(covered)} cobertos ({gaps} em fresta entre pecas)")
    return covered


def paint_under_clothes(body_mesh_obj, covered):
    """Pinta de cor de tecido a pele que fica por baixo da roupa.

    Segunda linha de defesa depois de tuck_under_clothes(): onde ainda escapar
    um pedacinho de pele entre os poligonos, ele le como roupa de baixo em vez
    de pele nua. A regiao vem da medicao de cobertura, nao de caixas de
    coordenada como antes — era por isso que a parte de dentro do braco e as
    costas ficavam de fora e mostravam pele.
    """
    me = body_mesh_obj.data
    me.materials.append(_cloth_material("MI_Undershirt", UNDERSHIRT_RGBA))
    torso_slot = len(me.materials) - 1
    me.materials.append(_cloth_material("MI_Underpants", UNDERPANTS_RGBA))
    legs_slot = len(me.materials) - 1

    torso = legs = 0
    for poly in me.polygons:
        # Basta a MAIORIA dos vertices estar coberta. Exigir todos deixava de
        # fora exatamente as faces da fronteira — e sao elas que atravessam o
        # tecido, porque a face e reta e o tecido em volta e curvo.
        inside = sum(1 for i in poly.vertices if i in covered)
        if inside * 2 <= len(poly.vertices):
            continue
        if poly.center.z >= WAIST_Z:
            poly.material_index = torso_slot
            torso += 1
        else:
            poly.material_index = legs_slot
            legs += 1
    print(f"    pintado: torso {torso} faces, pernas {legs} (de {len(me.polygons)})")


def strip_skin_surfaces(mesh_obj):
    """Joga fora a pele que vem embutida na propria roupa.

    A peca de braco do pacote (Male_Peasant_Arms) nao e so tecido: ela traz
    junto uma malha de BRACO (material MI_Regular_Male), pensada pra ser usada
    sem personagem por baixo. Como aqui existe o corpo completo embaixo, ficam
    dois bracos quase no mesmo lugar — e o da roupa aparecia furando a manga
    dela mesma, no ombro e no cotovelo. Nenhum ajuste no corpo resolvia isso,
    porque o pedaco que vazava nem era do corpo.
    """
    me = mesh_obj.data
    skin_slots = {i for i, mat in enumerate(me.materials)
                  if mat is None or "Peasant" not in mat.name}
    if not skin_slots:
        return 0
    bm = bmesh.new()
    bm.from_mesh(me)
    doomed = [f for f in bm.faces if f.material_index in skin_slots]
    if doomed:
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        bm.to_mesh(me)
    bm.free()
    return len(doomed)


def inflate(mesh_obj, amount):
    """Empurra os vertices ao longo da normal, pra roupa ficar por fora."""
    me = mesh_obj.data
    for v in me.vertices:
        v.co += v.normal * amount


def add_shape_keys(mesh_obj, shapes):
    """Grava cada tipo fisico como shape key na malha.

    Corpo e roupa recebem exatamente as mesmas operacoes: como as duas malhas
    ocupam o mesmo espaco, deformar so o corpo faria a barriga/seio atravessar
    o tecido. O vao de CLOTHES_INFLATE entre as duas nao fecha, porque as duas
    superficies andam junto.
    """
    me = mesh_obj.data
    base = [v.co.copy() for v in me.vertices]
    added = []
    for name, ops in shapes.items():
        moved = 0
        peak = 0.0
        coords = []
        for co in base:
            delta = Vector((0.0, 0.0, 0.0))
            for op in ops:
                delta += op.delta(co)
            length = delta.length
            if length > MIN_DELTA:
                moved += 1
                peak = max(peak, length)
            coords.append(co + delta)
        if moved == 0:
            continue
        if not me.shape_keys:
            mesh_obj.shape_key_add(name="Basis", from_mix=False)
        key = mesh_obj.shape_key_add(name=name, from_mix=False)
        for i, co in enumerate(coords):
            key.data[i].co = co
        added.append(f"{name}({moved}v, {peak * 100:.1f}cm)")
    if added:
        print(f"      formas em {mesh_obj.name}: {', '.join(added)}")


def rebind(mesh_obj, armature):
    """Prende a malha ao esqueleto do corpo (mesmo rig de 65 ossos)."""
    for m in mesh_obj.modifiers:
        if m.type == "ARMATURE":
            m.object = armature
            break
    else:
        m = mesh_obj.modifiers.new(name="Armature", type="ARMATURE")
        m.object = armature
    mesh_obj.parent = armature


def build(variant):
    print(f"\n=== {variant['name']} ===")
    bpy.ops.wm.read_factory_settings(use_empty=True)

    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=variant["body"])
    body_meshes, body_arm = meshes_and_armature(before)
    body_mesh = next(o for o in body_meshes if "Superhero" in o.name or "SuperHero" in o.name)
    print(f"  corpo: {body_mesh.name} | esqueleto: {body_arm.name} ({len(body_arm.data.bones)} ossos)")
    shaped = [body_mesh]
    garments: list = []

    for kind in ("outfit", "hair"):
        before = set(bpy.data.objects.keys())
        bpy.ops.import_scene.gltf(filepath=variant[kind])
        meshes, arm = meshes_and_armature(before)
        # A esfera de referencia do pacote vem junto em cada import; tirar ela
        # aqui evita inflar/deformar a toa (ela e descartada mais abaixo).
        meshes = [m for m in meshes if not m.name.startswith("Icosphere")]
        for m in meshes:
            if kind == "outfit":
                dropped = strip_skin_surfaces(m)
                if dropped:
                    print(f"    {m.name}: {dropped} faces de pele embutida removidas")
                inflate(m, CLOTHES_INFLATE)
                shaped.append(m)
                garments.append(m)
            rebind(m, body_arm)
        print(f"  {kind}: {[m.name for m in meshes]}")
        if arm:
            bpy.data.objects.remove(arm, do_unlink=True)

    # Depois da roupa estar na posicao final (ja inflada): afunda a pele por
    # baixo dela e pinta de tecido o que fica coberto.
    covered = tuck_under_clothes(body_mesh, garments)
    paint_under_clothes(body_mesh, covered)

    # Cabelo e olhos ficam de fora de proposito: as deformacoes sao do pescoco
    # pra baixo, entao um alvo la seria so peso morto no arquivo.
    print(f"  tipos fisicos: {', '.join(variant['shapes'].keys())}")
    for m in shaped:
        add_shape_keys(m, variant["shapes"])

    # Sobra do pacote: esferas de referencia que nao fazem parte do personagem
    # (vem uma por arquivo importado, numeradas: Icosphere, .001, .002...).
    for o in [o for o in bpy.data.objects if o.name.startswith("Icosphere")]:
        bpy.data.objects.remove(o, do_unlink=True)

    # As texturas de origem sao 4K (normal maps inclusive). Pra um NPC low-poly
    # visto de longe isso e desperdicio: embutidas no GLB davam ~50MB por
    # personagem. 1024 mantem a leitura e derruba o arquivo mais de 10x.
    for img in bpy.data.images:
        if max(img.size) > MAX_TEXTURE:
            w, h = img.size
            f = MAX_TEXTURE / max(w, h)
            img.scale(int(w * f), int(h * f))

    os.makedirs(OUT_DIR, exist_ok=True)
    out = f"{OUT_DIR}/{variant['name']}.glb"
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_skins=True,
        export_morph=True,
        export_morph_normal=True,
        export_yup=True,
    )
    print(f"  -> {out} ({os.path.getsize(out) / 1e6:.1f} MB)")


for v in VARIANTS:
    build(v)
print("\nPRONTO")
