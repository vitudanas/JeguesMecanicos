#!/usr/bin/env python3
"""Redimensiona o mundo do jogo a partir de UM numero: quantos quarteiroes por lado.

Por que uma ferramenta e nao edicao na mao: os parametros do `Town.tscn` sao
ACOPLADOS. A grade de ruas aparece em tres nos, o cinturao de transicao e o anel
rural sao offsets da borda da cidade, o chao tem que cobrir o pe da serra, a
oficina tem que ficar fora do asfalto, e as fazendas aparecem tanto como posicao
quanto dentro de duas listas de `exclude_points`. Mexer em um e esquecer outro e
o erro que este projeto ja cometeu varias vezes (ver changelog).

O que NAO escala, de proposito:
  - o espacamento das ruas (37.5): o tamanho do quarteirao e calibrado pelo
    tamanho dos predios, e mexer nele desalinha a cidade inteira;
  - a altura das montanhas: 320 m ja e ~9,5x o predio mais alto, que foi a
    calibragem feita medindo em 2026-08-04;
  - a escala de qualquer construcao.

Uso:
    python3 tools/expand_world.py 14        # 14 quarteiroes por lado
    python3 tools/expand_world.py 14 --dry  # so mostra o que faria
"""
import math
import pathlib
import re
import sys

TSCN = pathlib.Path(__file__).resolve().parent.parent / "scenes/world/Town.tscn"
SPACING = 37.5          # trava documentada: nao mexer
OLD_BLOCKS = 6          # o que existia quando esta ferramenta nasceu
ROAD_REACH = 22.5       # `extent` do CityStreets: quanto o asfalto passa da ultima rua


def street_axes(blocks: int):
    half = blocks * SPACING / 2.0
    return [round(-half + i * SPACING, 3) for i in range(blocks + 1)]


# Espacamento dos quarteiroes, do centro pra fora, espelhado nos dois lados.
#
# POR QUE VARIADO. A grade era uniforme (37.5 em todo lugar), e com ela o miolo
# de cada quarteirao dava 28.3 m: um orcamento de profundidade de 13.8 m por
# lote. Os predios realistas tem de 7 a 40 m de profundidade, entao a maioria
# simplesmente NAO CABIA. Alem disso quarteirao todo igual e o que mais denuncia
# grade gerada — cidade de verdade tem quadra grande e quadra curta.
#
# Todo valor e multiplo EXATO do tile de 7.5 (45 = 6 tiles, 67.5 = 9, 90 = 12).
# Essa e a trava documentada da malha viaria: espacamento que nao e multiplo do
# tile abre um vao em cada aproximacao de esquina (changelog 2026-08-03).
# Ordem escolhida por MEDIDA, nao por gosto: as torres do pacote downtown tem
# 35 a 41 m de PROFUNDIDADE, e o orcamento de um quarteirao e metade do miolo.
# Com o 90 no meio do padrao, as quadras do centro ficavam com 45 e 67.5 (17.6 e
# 28.9 m de orcamento) e NENHUMA torre alta cabia — a cidade nascia com 37 m de
# predio mais alto tendo modelos de 102 m no catalogo. Com o 90 encostado no
# centro, o miolo tem 80.8 m e as torres entram.
# Sem quadra de 45 m: com a rua larga (18,8 m de fachada a fachada) o miolo dela
# cai pra 26 m, e o orcamento de profundidade pra ~9 m — quase nenhum predio
# realista e tao raso. Medido, as quadras de 45 nasciam com as QUATRO bordas
# vazias, e sozinhas respondiam por 80 das 104 bordas vazias da cidade.
# Continua variado (67.5 e 90) e a meia-largura segue 337.5.
PADRAO = [90.0, 67.5, 90.0, 90.0]


def street_axes_variado(padrao=None):
    padrao = padrao or PADRAO
    for s in padrao:
        if abs(s / 7.5 - round(s / 7.5)) > 1e-6:
            raise SystemExit("espacamento %g nao e multiplo do tile 7.5" % s)
    pos, acc = [0.0], 0.0
    for s in padrao:
        acc += s
        pos.append(acc)
    return [round(-v, 3) for v in reversed(pos[1:])] + [round(v, 3) for v in pos]


def fmt_floats(vals):
    return "Array[float](%s)" % ("[" + ", ".join(_num(v) for v in vals) + "]")


def _num(v):
    return str(int(v)) if float(v) == int(v) else ("%g" % v)


def fmt_v3_array(pts):
    return "Array[Vector3](%s)" % (
        "[" + ", ".join("Vector3(%s, 0, %s)" % (_num(x), _num(z)) for x, z in pts) + "]")


class Patcher:
    """Aplica trocas exigindo que cada uma case, e grava a cada passo.

    Grava a cada passo por licao propria (changelog 2026-08-03): um script que
    so gravava no fim abortava no meio e DESCARTAVA em silencio tudo o que ja
    tinha impresso como feito.
    """

    def __init__(self, path, dry):
        self.path = path
        self.dry = dry
        self.text = path.read_text()
        self.n = 0

    def sub(self, old, new, label, count=1):
        found = self.text.count(old)
        if found != count:
            raise SystemExit("FALHOU %s: esperava %d ocorrencia(s), achei %d\n  %r"
                             % (label, count, found, old[:110]))
        self.text = self.text.replace(old, new)
        self.n += 1
        print("  ok  %s" % label)
        self.flush()

    def re_sub(self, pattern, new, label, count=1):
        found = len(re.findall(pattern, self.text, re.M))
        if found != count:
            raise SystemExit("FALHOU %s: esperava %d, achei %d (%s)"
                             % (label, count, found, pattern))
        self.text = re.sub(pattern, new, self.text, flags=re.M)
        self.n += 1
        print("  ok  %s  (%d)" % (label, found))
        self.flush()

    def flush(self):
        if not self.dry:
            self.path.write_text(self.text)


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    dry = "--dry" in sys.argv
    if sys.argv[1] == "variado":
        axes = street_axes_variado()
        blocks = len(axes) - 1
    else:
        blocks = int(sys.argv[1])
        if blocks % 2 or blocks < 2:
            raise SystemExit("use um numero PAR de quarteiroes (a cidade e centrada em 0)")
        axes = street_axes(blocks)

    old_half = OLD_BLOCKS * SPACING / 2.0          # 112.5
    half = axes[-1]                                 # meia-largura da cidade
    k = half / old_half                             # fator dos aneis externos
    city_reach = half + ROAD_REACH                  # ate onde vai o asfalto

    # Aneis: sao OFFSETS da borda da cidade no arquivo atual, entao continuam
    # offsets — e nao proporcoes, que engordariam o campo junto com a cidade.
    outskirts_in = half + 7.5
    outskirts_out = half + 41.5
    street_reach = half + 22.5
    nature_in = half + 27.5
    nature_out = round(half * 2.03, 1)
    mount_foot = round(half * 2.67, 1)
    # O chao precisa caber o PE da serra, que se espalha bem alem do raio
    # nominal (a base e eliptica e o cume e deslocado — lição de 2026-08-04, que
    # custou 128 props engolidos). Sobra generosa de proposito.
    ground = int(math.ceil((mount_foot + 90.0 + 190.0 * 2.9) * 2.0 / 100.0) * 100)

    # A oficina fica a 40 m depois de onde o asfalto acaba, como hoje.
    shop_x = -(city_reach + 40.0)
    junk = (shop_x, 40.0)
    spawn = (shop_x + 6.0, 6.0)

    print("=== mundo de %d x %d quarteiroes ===" % (blocks, blocks))
    print("  cidade      %.1f m de lado (era %.1f) = %.1fx de area"
          % (half * 2, old_half * 2, (half / old_half) ** 2))
    print("  asfalto ate %.1f | cinturao %.1f-%.1f | natureza %.1f-%.1f"
          % (city_reach, outskirts_in, outskirts_out, nature_in, nature_out))
    print("  serra em %.1f | chao %d x %d" % (mount_foot, ground, ground))
    print("  oficina em (%.0f, 0) | ferro-velho (%.0f, %.0f)" % (shop_x, junk[0], junk[1]))

    p = Patcher(TSCN, dry)
    # LIMPAR ANTES DE VALIDAR. Os blocos abaixo cobram um numero exato de
    # ocorrencias de cada campo; com um CityLife/CityHazards duplicado de uma
    # rodada anterior, `streets_x` aparecia 6 vezes em vez de 4 e a ferramenta
    # travava logo no comeco, antes de chegar na remocao.
    # CityLife/CityHazards entram na lista de remocao junto com as rotas: o bloco
    # de geradores e ACRESCENTADO logo abaixo, sem checar se ja existe, entao
    # rodar a ferramenta duas vezes deixava DOIS de cada — ou seja o dobro de
    # carro, pedestre, buraco e poca, calado. Estava assim no arquivo commitado.
    apagados = 0
    for prefixo in ("TrafficRoute", "PedestrianRoute", "Pothole", "MudZone",
                    "EventSpawnPoint", "CityLife", "CityHazards"):
        apagados += drop_nodes(p, prefixo)
    print("  ok  %d nos de rota/buraco/spawn removidos" % apagados)

    grid = fmt_floats(axes)

    # ------------------------------------------------------------ grade de ruas
    old_grid = re.search(r"streets_x = (Array\[float\]\(\[[^\]]*\]\))", p.text).group(1)
    p.re_sub(r"^streets_x = Array\[float\]\(\[[^\]]*\]\)$", "streets_x = " + grid,
             "streets_x", 2)
    p.re_sub(r"^streets_z = Array\[float\]\(\[[^\]]*\]\)$", "streets_z = " + grid,
             "streets_z", 2)
    p.re_sub(r"^street_axes_x = Array\[float\]\(\[[^\]]*\]\)$",
             "street_axes_x = " + grid, "street_axes_x", 1)
    p.re_sub(r"^street_axes_z = Array\[float\]\(\[[^\]]*\]\)$",
             "street_axes_z = " + grid, "street_axes_z", 1)

    # --------------------------------------------------------------- os aneis
    p.re_sub(r"^shader_parameter/city_extent = [-\d.]+$",
          "shader_parameter/city_extent = %.1f" % city_reach, "city_extent do chao", 1)
    p.re_sub(r"^inner_extent = [-\d.]+\nouter_extent = [-\d.]+$",
          "inner_extent = %.1f\nouter_extent = %.1f" % (outskirts_in, outskirts_out),
          "cinturao de transicao")
    p.re_sub(r"^exclude_radius = [-\d.]+\nrng_seed = 20260803$",
          "exclude_radius = 44.0\nrng_seed = 20260803",
          "folga em volta dos clusters (o cinturao encostou no ferro-velho)", 2)
    p.re_sub(r"^street_reach = [-\d.]+$", "street_reach = %.1f" % street_reach,
          "alcance das ruas no cinturao")
    p.re_sub(r"^inner_extent = [-\d.]+(?=\nouter_radius)", "inner_extent = %.1f" % nature_in,
          "borda interna da natureza")
    p.re_sub(r"^outer_radius = [-\d.]+$", "outer_radius = %.1f" % nature_out,
          "borda externa da natureza")
    p.re_sub(r"^foot_radius = [-\d.]+$", "foot_radius = %.1f" % mount_foot, "raio da serra", 1)
    # Mais montanhas pra fechar um circulo maior; o TAMANHO delas nao muda.
    novo_count = int(round(44 * mount_foot / 300.0))
    p.re_sub(r"(?<=foot_spread = 90.0\n)count = \d+",
             "count = %d" % novo_count, "quantidade de montanhas")
    p.re_sub(r"^size = Vector3\(\d+, 1, \d+\)$", "size = Vector3(%d, 1, %d)"
             % (ground, ground), "tamanho do chao", 2)

    # -------------------------------------------------- fazendas e ferros-velhos
    # Vao junto com o anel rural, senao caem dentro da cidade nova.
    rural = []
    for m in re.finditer(
            r'(\[node name="(?:Farm\d|Scrapyard\d)" parent="\." instance=ExtResource\("\d+"\)\]\n'
            r'transform = Transform3D\(1, 0, 0, 0, 1, 0, 0, 0, 1, )(-?[\d.]+), 0, (-?[\d.]+)\)',
            p.text):
        rural.append((float(m.group(2)), float(m.group(3))))
    if len(rural) != 8:
        raise SystemExit("esperava 8 clusters rurais, achei %d" % len(rural))
    novos = [(round(x * k, 1), round(z * k, 1)) for x, z in rural]
    txt = p.text
    for (ox, oz), (nx, nz) in zip(rural, novos):
        alvo = "1, 0, 0, 0, 1, 0, 0, 0, 1, %s, 0, %s)" % (_num(ox), _num(oz))
        if txt.count(alvo) != 1:
            raise SystemExit("cluster rural (%s, %s): %d ocorrencias"
                             % (ox, oz, txt.count(alvo)))
        txt = txt.replace(alvo, "1, 0, 0, 0, 1, 0, 0, 0, 1, %s, 0, %s)" % (_num(nx), _num(nz)))
    p.text = txt
    p.flush()
    print("  ok  8 clusters rurais movidos (x%.2f)" % k)

    # As duas listas de exclusao tem que casar com as posicoes novas MAIS os dois
    # marcos do jogador. Regeradas inteiras: e a lista que ja divergiu antes.
    excl = fmt_v3_array(novos + [(shop_x, 0.0), junk])
    p.re_sub(r"^exclude_points = Array\[Vector3\]\(\[[^\]]*\]\)$",
             "exclude_points = " + excl, "exclude_points (natureza e cinturao)", 2)

    # ------------------------------------------------------- marcos do jogador
    p.re_sub(r'(?<=\[node name="Junkyard" parent="\." instance=ExtResource\("3"\)\]\n)'
             r'transform = Transform3D\([^)]*\)',
             "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, 0, %s)"
             % (_num(junk[0]), _num(junk[1])), "ferro-velho")
    p.re_sub(r'(?<=\[node name="Workshop" parent="\." instance=ExtResource\("4"\)\]\n)'
             r'transform = Transform3D\([^)]*\)',
             "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, 0, 0)"
             % _num(shop_x), "oficina")
    p.re_sub(r'(?<=\[node name="PlayerSpawn" type="Marker3D" parent="\."\]\n)'
             r'transform = Transform3D\([^)]*\)',
          "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, 0.4, %s)"
          % (_num(spawn[0]), _num(spawn[1])), "nascimento do jogador")

    # Estrada de terra: comeca onde o asfalto acaba e vai ate o patio.
    d0 = -(city_reach + 2.0)
    d1 = shop_x + 3.0
    passo = (d1 - d0) / 5.0
    pts = [(round(d0 + passo * i, 1),
            [2.6, 2.0, -0.5, -1.0, 0.0, 1.0][i]) for i in range(6)]
    novo_dirt = "points = Array[Vector2](%s)" % (
        "[" + ", ".join("Vector2(%s, %s)" % (_num(x), _num(y)) for x, y in pts) + "]")
    p.re_sub(r"^points = Array\[Vector2\]\(\[[^\]]*\]\)$", novo_dirt,
             "estrada de terra", 1)

    # ------------------------------------- rotas, buracos e pontos de evento
    # Deixam de ser nos escritos a mao e passam a ser GERADOS da grade (ver
    # CityLife.gd e CityHazards.gd). Com 14x14 quarteiroes seriam ~90
    # retangulos digitados; dois deles ja nasceram fora de rua nenhuma quando
    # eram 18 (changelog 2026-08-03). A REMOCAO dos nos antigos acontece la em
    # cima, logo depois de abrir o arquivo — ver o porque la.

    # IDS LIVRES, medidos no arquivo. Escolhi 410/411/412 no olho da primeira vez
    # e eles JA ESTAVAM em uso pelas texturas de grama: `ExtResource("410")`
    # passou a resolver pra uma imagem, o script nao carregou ("Cannot set object
    # script") e a cidade nasceu sem UM buraco — sem erro que reprovasse nada.
    usados = {int(x) for x in re.findall(r'^\[ext_resource [^\]]*id="(\d+)"\]$',
                                        p.text, re.M)}
    livre = max(usados) + 1

    def id_declarado(caminho):
        """Id de um ext_resource ja declarado, ou None."""
        m = re.search(r'^\[ext_resource [^\]]*path="%s"[^\]]*id="(\d+)"\]$'
                      % re.escape(caminho), p.text, re.M)
        return int(m.group(1)) if m else None

    # REUSAR o id quando o recurso JA esta declarado. Sem isto, rodar a
    # ferramenta uma segunda vez alocava ids novos (421-423), pulava a
    # declaracao — porque o `if` abaixo ve que o script ja existe — e escrevia
    # nos apontando pra ExtResource que nao existe. O Godot recusa a cena
    # inteira com um "Parse error" que so aponta a linha do no.
    ja = {k: id_declarado(c) for k, c in (
        ("life", "res://scripts/CityLife.gd"),
        ("hazards", "res://scripts/CityHazards.gd"),
        ("pothole", "res://scenes/world/Pothole.tscn"))}
    if all(v is not None for v in ja.values()):
        ids = ja
        print("  ok  scripts novos ja declarados (ids %d/%d/%d, reusados)"
              % (ids["life"], ids["hazards"], ids["pothole"]))
    else:
        ids = {"life": livre, "hazards": livre + 1, "pothole": livre + 2}
    if 'path="res://scripts/CityLife.gd"' not in p.text:
        p.sub('[ext_resource type="Script" path="res://scripts/MountainRange.gd" id="401"]',
              '[ext_resource type="Script" path="res://scripts/MountainRange.gd" id="401"]\n'
              '[ext_resource type="Script" path="res://scripts/CityLife.gd" id="%d"]\n'
              '[ext_resource type="Script" path="res://scripts/CityHazards.gd" id="%d"]\n'
              '[ext_resource type="PackedScene" path="res://scenes/world/Pothole.tscn" id="%d"]'
              % (ids["life"], ids["hazards"], ids["pothole"]),
              "scripts novos declarados (ids %d-%d, livres)" % (livre, livre + 2))
        bump_load_steps(p, 4)

    # Pontos de evento: cruzamentos espalhados, sempre livres por construcao.
    passo = max(1, (len(axes) - 1) // 3)
    pontos = []
    for i in range(1, len(axes) - 1, passo):
        for j in range(1, len(axes) - 1, passo):
            pontos.append((axes[i], axes[j]))
    blocos = []
    for n, (x, z) in enumerate(pontos, 1):
        blocos.append('[node name="EventSpawnPoint%d" type="Marker3D" parent="."]\n'
                      'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, 0.5, %s)\n'
                      % (n, _num(x), _num(z)))

    # Quantos agentes: cresce com a cidade, mas SUBLINEAR de proposito. O
    # jogador so ve alguns quarteiroes por vez, e cada pedestre e uma malha
    # animada — multiplicar por 5.4 daria ~140 esqueletos animando fora da tela.
    # Uma rota de carro a cada ~8 quarteiroes e uma de pedestre a cada ~9. Cresce
    # com a cidade, mas bem abaixo do proporcional: o jogador so ve alguns
    # quarteiroes por vez, e cada pedestre e uma malha animada.
    fator = math.sqrt(half / old_half)
    rotas_carro = max(6, blocks * blocks // 8)
    rotas_ped = max(6, blocks * blocks // 9)
    # Buracos por COMPRIMENTO de rua, nao por quarteirao: um por ~250 m de
    # asfalto. Os 4 fixos de antes davam um a cada 790 m, e estavam listados
    # nas limitacoes conhecidas justamente por isso — o test-drive caotico e um
    # pilar do jogo e a cidade era lisa.
    comprimento = 2.0 * (blocks + 1) * (blocks * SPACING)
    buracos = int(round(comprimento / 250.0))
    geradores = (
        '[node name="CityLife" type="Node3D" parent="."]\n'
        'script = ExtResource("%d")\n'
        'streets_x = %s\n'
        'streets_z = %s\n'
        'traffic_scene = ExtResource("6")\n'
        'traffic_routes = %d\n'
        'cars_per_route = 3\n'
        'car_models = Array[PackedScene]([ExtResource("101"), ExtResource("102"), '
        'ExtResource("103"), ExtResource("104"), ExtResource("105"), ExtResource("106")])\n'
        'pedestrian_scene = ExtResource("15")\n'
        'pedestrian_routes = %d\n'
        'peds_per_route = 4\n'
        'character_models = Array[PackedScene]([ExtResource("200"), ExtResource("201")])\n'
        'anim_scene = ExtResource("207")\n'
        '\n'
        '[node name="CityHazards" type="Node3D" parent="."]\n'
        'script = ExtResource("%d")\n'
        'streets_x = %s\n'
        'streets_z = %s\n'
        'pothole_scene = ExtResource("%d")\n'
        'mud_scene = ExtResource("7")\n'
        'count = %d\n'
        % (ids["life"], grid, grid, rotas_carro, rotas_ped,
           ids["hazards"], grid, grid, ids["pothole"], buracos))

    p.text = p.text.rstrip("\n") + "\n\n" + geradores + "\n" + "\n".join(blocos)
    p.flush()
    print("  ok  CityLife (%d rotas de carro, %d de pedestre) + CityHazards + %d pontos de evento"
          % (rotas_carro, rotas_ped, len(pontos)))

    print("\n%d blocos de parametro reescritos%s" % (p.n, "  (DRY RUN)" if dry else ""))


## Remove um no e os filhos dele (que se declaram por parent="<nome>").
def drop_nodes(p, prefixo):
    blocos = re.findall(r'^\[node name="%s[^"]*"[^\]]*\]\n(?:(?!\[node |\[sub_resource|\[ext_resource)[^\n]*\n)*'
                        % prefixo, p.text, re.M)
    for b in blocos:
        p.text = p.text.replace(b, "")
    # filhos declarados com parent="Nome" ou parent="Nome/..."
    filhos = re.findall(r'^\[node name="[^"]*" type="[^"]*" parent="%s[^"]*"\]\n(?:(?!\[node )[^\n]*\n)*'
                        % prefixo, p.text, re.M)
    for b in filhos:
        p.text = p.text.replace(b, "")
    p.flush()
    return len(blocos)


def bump_load_steps(p, delta):
    m = re.search(r"load_steps=(\d+)", p.text)
    p.text = p.text.replace("load_steps=%s" % m.group(1),
                            "load_steps=%d" % (int(m.group(1)) + delta), 1)
    p.flush()


if __name__ == "__main__":
    main()
