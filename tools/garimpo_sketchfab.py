#!/usr/bin/env python3
"""Garimpa o Sketchfab por predios que servem para a cidade do jogo.

A API de busca e publica (nao precisa de login) e devolve contagem de faces e
licenca — que sao exatamente os dois filtros que separam o modelo usavel do
scan de meio milhao de triangulos. Clicar pagina por pagina pra descobrir isso
seria inviavel; aqui da pra varrer centenas de resultados em segundos.

Os limites vem de docs/modelos-realistas.md, que por sua vez saiu do gerador:
  - licenca CC0 ou CC-BY (CC-BY-NC proibe uso comercial, ND proibe modificar);
  - <= 40 mil faces (o orcamento e 25 mil triangulos; deixo folga porque o
    numero da API e de FACES, e quad conta como uma);
  - >= 150 faces (abaixo disso e um cubo, nao adianta).

Uso:  python3 tools/garimpo_sketchfab.py [--max-faces 40000]
"""
import json
import subprocess
import sys
import urllib.parse

API = "https://api.sketchfab.com/v3/search"
LICENCAS_OK = {"cc0", "by"}          # dominio publico e atribuicao
# Sem teto util, por decisao do usuario em 2026-08-09 ("nao se limite, quero o
# maximo de qualidade"). O numero continua sendo IMPRESSO em cada candidato:
# ele nao filtra mais, mas segue sendo o dado que diz o custo de por aquele
# modelo 800 vezes numa cidade sem Nanite.
MAX_FACES = 2_000_000
MIN_FACES = 150

# Termos escolhidos pelos quatro tipos que o CityBlocks distribui por zona.
TERMOS = {
    "torre": ["office building game ready", "skyscraper low poly",
              "modern office tower game", "highrise building lowpoly"],
    "comercio": ["apartment building game ready", "shophouse low poly",
                 "city building lowpoly", "commercial building game asset",
                 "corner building low poly", "residential block lowpoly"],
    "casa": ["house game ready low poly", "row house lowpoly",
             "suburban house game asset", "townhouse low poly"],
    "galpao": ["warehouse game ready", "industrial building low poly",
               "factory building lowpoly"],
}
# Palavra no nome que denuncia o que NAO serve pra uma cidade moderna.
VETO = ("medieval", "fantasy", "castle", "ruin", "scan", "photogrammetry",
        "church", "temple", "mosque", "sci-fi", "scifi", "cyber", "voxel",
        "minecraft", "interior", "room", "cartoon", "toon")


def buscar(termo, max_faces):
    achados = []
    for lic in sorted(LICENCAS_OK):
        # curl e nao urllib: o Python deste ambiente nao tem a cadeia de
        # certificados e falha em toda chamada HTTPS.
        q = urllib.parse.urlencode({
            "type": "models", "downloadable": "true", "license": lic,
            "q": termo, "count": 24, "sort_by": "-likeCount"})
        try:
            saida = subprocess.run(["curl", "-sS", "%s?%s" % (API, q)],
                                   capture_output=True, timeout=40).stdout
            dados = json.loads(saida)
        except Exception as e:                       # rede e instavel; segue
            print("  (falhou %s / %s: %s)" % (termo, lic, e), file=sys.stderr)
            continue
        for m in dados.get("results", []):
            nome = (m.get("name") or "").lower()
            if any(v in nome for v in VETO):
                continue
            # O filtro de faces da API (max_face_count) devolve lista VAZIA —
            # nao e parametro valido. Filtra aqui.
            faces = m.get("faceCount") or 0
            if faces < MIN_FACES or faces > max_faces:
                continue
            achados.append({
                "nome": m.get("name"), "faces": m.get("faceCount"),
                "licenca": lic, "uid": m.get("uid"),
                "url": m.get("viewerUrl"), "likes": m.get("likeCount", 0)})
    return achados


def main():
    max_faces = MAX_FACES
    if "--max-faces" in sys.argv:
        max_faces = int(sys.argv[sys.argv.index("--max-faces") + 1])
    tudo = {}
    for zona, termos in TERMOS.items():
        print("=== %s ===" % zona)
        vistos = {}
        for t in termos:
            for m in buscar(t, max_faces):
                vistos[m["uid"]] = m          # o mesmo modelo cai em varios termos
        ordenado = sorted(vistos.values(), key=lambda m: -m["likes"])
        for m in ordenado[:12]:
            print("  %6d faces  %-4s  %-46s  %s" % (
                m["faces"], m["licenca"], (m["nome"] or "")[:46], m["url"]))
        print("  (%d candidatos)" % len(ordenado))
        tudo[zona] = ordenado
    with open("/tmp/garimpo.json", "w") as f:
        json.dump(tudo, f, indent=1)
    print("\ntotal: %d candidatos, salvos em /tmp/garimpo.json"
          % sum(len(v) for v in tudo.values()))


if __name__ == "__main__":
    main()
