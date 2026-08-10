#!/usr/bin/env python3
"""Configura o Town.tscn para a cidade REALISTA.

Roda DEPOIS de `tools/expand_world.py variado`, que e quem monta a grade de
ruas e reposiciona os aneis. Aqui ficam so as decisoes que sao da cidade
realista em si:

  1. o `CityBlocks` passa a construir com `assets/realistas_prontos/`;
  2. os aneis de zoneamento sao recalibrados pro tamanho novo da cidade;
  3. dois bolsoes industriais;
  4. os 8 clusters rurais voltam pro anel de natureza e o campo fica mais cheio.

Separado do `expand_world.py` de proposito: aquele mexe na GEOMETRIA do mundo
(grade, aneis, chao, serra) e vale pra qualquer cidade; este mexe no que a
cidade e feita.

  python3 tools/cidade_realista.py [--dry]
"""
import pathlib
import re
import sys

TSCN = pathlib.Path(__file__).resolve().parent.parent / "scenes/world/Town.tscn"

# Onde cada cluster rural fica, em coordenada de mundo.
#
# Postos a mao, e nao escalados pela ferramenta de expansao: ela multiplica a
# posicao pelo crescimento da cidade assumindo que os clusters estao onde o
# mundo ORIGINAL os deixou, e rodando sobre um mundo ja expandido escala de
# novo — foi assim que as 5 fazendas foram parar a ~1240 do centro, ALEM da
# serra (pe em ~700) e fora do anel de natureza.
CLUSTERS = {
    "Farm1": (520, 180), "Farm2": (-200, 540), "Farm3": (560, -330),
    "Farm4": (-560, -260), "Farm5": (150, 600),
    "Scrapyard1": (-520, 240), "Scrapyard2": (300, -560), "Scrapyard3": (-300, -560),
}
def marcos(texto):
    """Oficina e ferro-velho do jogador, LIDOS do arquivo.

    Entram na lista de exclusao junto dos clusters, senao nasce arvore dentro do
    patio. Lidos, e nao escritos aqui: quem os posiciona e o `expand_world`, em
    funcao de onde o asfalto acaba — deixar o numero repetido nos dois lugares
    faria a exclusao apontar pro lugar errado toda vez que a cidade mudasse de
    tamanho (e ja apontava: estavam em -377.5 com a oficina em -400).
    """
    saida = []
    for nome in ("Workshop", "Junkyard"):
        m = re.search(r'\[node name="%s" parent="\." instance=ExtResource\("\d+"\)\]\n'
                      r'transform = Transform3D\([^)]*?,\s*([-\d.]+),\s*[-\d.]+,\s*([-\d.]+)\)'
                      % nome, texto)
        if m is None:
            raise SystemExit("nao achei a posicao de %s" % nome)
        saida.append((float(m.group(1)), float(m.group(2))))
    return saida

# Aneis de zoneamento. Os centros de quarteirao da grade variada caem em 45,
# 112.5, 168.75, 247.5 e 315 de distancia Chebyshev, entao 130 poe os dois
# aneis internos no "centro" e 260 leva ate o penultimo.
DOWNTOWN = 130.0
MIDTOWN = 260.0
INDUSTRIAIS = [(247.5, -247.5), (-247.5, 247.5)]
RAIO_INDUSTRIAL = 95.0

# Anel rural mais cheio (pedido do usuario). O anel tambem CRESCEU de area com a
# cidade nova, entao manter a contagem antiga ja o deixaria mais ralo.
DECOR = 2800
SOLID = 780


def main() -> int:
    dry = "--dry" in sys.argv
    texto = TSCN.read_text()
    passos = []

    def trocar(regex, novo, rotulo, esperado=1):
        nonlocal texto
        achou = len(re.findall(regex, texto, re.M))
        if achou != esperado:
            raise SystemExit("FALHOU %s: esperava %d, achei %d" % (rotulo, esperado, achou))
        texto = re.sub(regex, novo, texto, flags=re.M)
        passos.append(rotulo)
        print("  ok  %s  (%d)" % (rotulo, achou))

    # ------------------------------------------------- 1. o no CityBlocks
    m = re.search(r'\[node name="CityBlocks"[^\n]*\]\n(.*?)(?=\n\[node )', texto, re.S)
    if m is None:
        raise SystemExit("nao achei o no CityBlocks")
    bloco = m.group(1)

    def campo(txt, nome, valor):
        pat = re.compile(r"^%s = .*$" % re.escape(nome), re.M)
        if pat.search(txt):
            return pat.sub("%s = %s" % (nome, valor), txt, count=1)
        return txt.rstrip("\n") + "\n%s = %s\n" % (nome, valor)

    bloco = campo(bloco, "usar_realistas", "true")
    bloco = campo(bloco, "downtown_extent", "%.1f" % DOWNTOWN)
    bloco = campo(bloco, "midtown_extent", "%.1f" % MIDTOWN)
    bloco = campo(bloco, "industrial_centers", "Array[Vector3](%s)" % (
        "[" + ", ".join("Vector3(%g, 0, %g)" % (x, z) for x, z in INDUSTRIAIS) + "]"))
    bloco = campo(bloco, "industrial_radius", "%.1f" % RAIO_INDUSTRIAL)
    texto = texto[:m.start(1)] + bloco + texto[m.end(1):]
    passos.append("CityBlocks realista")
    print("  ok  CityBlocks realista (zonas %.0f/%.0f, %d bolsoes industriais)"
          % (DOWNTOWN, MIDTOWN, len(INDUSTRIAIS)))

    # --------------------------------------------- 2. clusters de volta ao anel
    for nome, (x, z) in CLUSTERS.items():
        trocar(r'(\[node name="%s" parent="\." instance=ExtResource\("\d+"\)\]\n)'
               r'transform = Transform3D\([^)]*\)' % nome,
               r"\1" + "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %d, 0, %d)"
               % (x, z), "cluster %s" % nome)

    pontos = list(CLUSTERS.values()) + marcos(texto)
    trocar(r"^exclude_points = Array\[Vector3\]\(\[[^\]]*\]\)$",
           "exclude_points = Array[Vector3](%s)" % (
               "[" + ", ".join("Vector3(%g, 0, %g)" % (x, z) for x, z in pontos) + "]"),
           "exclude_points (natureza e cinturao)", 2)

    # ------------------------------------------------------ 3. campo mais cheio
    # `decor_count` existe tambem nos 3 ferros-velhos rurais (valores 6 e 7); o
    # do NatureScatter e o unico acima de 100, entao casa so ele.
    trocar(r"^decor_count = \d{3,}$", "decor_count = %d" % DECOR, "densidade de decoracao")
    trocar(r"^solid_count = \d{3,}$", "solid_count = %d" % SOLID, "densidade de arvore/rocha")

    if dry:
        print("\n%d passo(s)  (DRY RUN)" % len(passos))
        return 0
    TSCN.write_text(texto)
    print("\n%d passo(s) aplicados" % len(passos))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
