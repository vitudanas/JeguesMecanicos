#!/usr/bin/env python3
"""Monta os creditos a partir do `license.txt` de cada modelo baixado.

Os modelos do Sketchfab sao CC-BY: uso comercial liberado, credito
**OBRIGATORIO**. Manter essa lista na mao daria errado na primeira vez que
alguem baixasse mais um pacote — aqui ela sai do proprio arquivo que o Sketchfab
poe dentro do zip.

Gera DOIS arquivos:

  * `docs/creditos.md` — pra ler no repositorio;
  * `assets/creditos.gd` — os mesmos dados como const, que e o que a TELA de
    creditos do jogo carrega. Vai em codigo, e nao num `.tres` ou `.json`,
    porque recurso escrito a mao ja ficou de fora do `.pck` exportado neste
    projeto (2026-08-04) e o defeito so aparece no binario.

So entra quem de fato VIAJA no build: pacote listado no `exclude_filter` do
`export_presets.cfg` nao e distribuido, entao nao precisa (nem deve) ser
creditado como se estivesse no jogo.

    python3 tools/creditos.py
"""
import os
import re

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PASTAS = ["assets/realistas", "assets/personagens"]
SAIDA_MD = "docs/creditos.md"
SAIDA_GD = "assets/creditos.gd"

## Pacotes CC0 (dominio publico): credito NAO e exigido, mas listar e o minimo.
## Escritos a mao porque nao vem com `license.txt` — sao a fonte do resto do
## jogo (cidade, natureza, carros, sons, ceu, texturas PBR).
CC0 = [
    ("Kenney", "https://kenney.nl", "kits de rua, cidade, sons de impacto e interface"),
    ("Quaternius", "https://quaternius.com", "personagens, animações, carros, fazenda e natureza"),
    ("ambientCG", "https://ambientcg.com", "texturas PBR de asfalto, tijolo, concreto, grama e rocha"),
    ("Poly Haven / Amal Kumar", "https://polyhaven.com", "céu HDRI e material PBR Gravel Road"),
    ("domasx2 / OpenGameArt", "https://opengameart.org/content/racing-car-engine-sound-loops", "gravação CC0 de motor em laço"),
    ("IgnasD / OpenGameArt", "https://opengameart.org/content/wind", "gravação CC0 de vento rural"),
    ("Cleyton Kauffman", "https://opengameart.org/content/pause-menu-music", "música Offline do menu"),
    ("Umplix", "https://opengameart.org/content/super-wreck-roadway", "música Super Wreck Roadway do mundo"),
]


def excluidos():
    """As pastas que o `exclude_filter` corta — ou seja, o que nao e distribuido."""
    caminho = os.path.join(RAIZ, "export_presets.cfg")
    if not os.path.exists(caminho):
        return set()
    texto = open(caminho, encoding="utf-8").read()
    fora = set()
    for linha in re.findall(r'^exclude_filter="(.*)"$', texto, re.M):
        for padrao in linha.split(","):
            padrao = padrao.strip().rstrip("/*").rstrip("/")
            if padrao.count("/") == 2 and "*" not in padrao:
                fora.add(padrao)
    return fora


def ler(pasta_base, nome):
    caminho = os.path.join(RAIZ, pasta_base, nome, "license.txt")
    if not os.path.exists(caminho):
        return None
    t = open(caminho, encoding="utf-8", errors="ignore").read()

    def campo(k):
        achado = re.search(r"\* %s:\s*(.+)" % k, t)
        return achado.group(1).strip() if achado else "?"

    autor = campo("author")
    return {
        "titulo": campo("title"),
        "fonte": campo("source"),
        "autor": re.sub(r"\s*\(http.*\)", "", autor),
        "perfil": (re.search(r"\((https[^)]+)\)", autor) or ["", ""])[1],
        "licenca": campo("license type").split(" (")[0],
    }


def escapar(s):
    return s.replace("\\", "").replace('"', "'")


def main():
    fora = excluidos()
    itens = []
    for base in PASTAS:
        raiz = os.path.join(RAIZ, base)
        if not os.path.isdir(raiz):
            continue
        for nome in sorted(os.listdir(raiz)):
            if nome.startswith("_") or not os.path.isdir(os.path.join(raiz, nome)):
                continue
            if "%s/%s" % (base, nome) in fora:
                continue
            m = ler(base, nome)
            if m:
                m["grupo"] = "Construções" if "realistas" in base else "Personagens"
                itens.append(m)
    itens.sort(key=lambda m: (m["grupo"], m["autor"].lower(), m["titulo"].lower()))

    linhas = ["# Créditos dos modelos de terceiros", "",
              "Gerado por `tools/creditos.py` a partir do `license.txt` de cada pacote.",
              "**CC-BY exige crédito** — esta lista alimenta a tela de créditos do jogo.",
              "Só entra o que de fato viaja no build.", ""]
    grupo = ""
    for m in itens:
        if m["grupo"] != grupo:
            grupo = m["grupo"]
            linhas += ["", "## %s" % grupo, ""]
        linhas.append("- **%s** por [%s](%s) — [página do modelo](%s), licença %s"
                      % (m["titulo"], m["autor"], m["perfil"], m["fonte"], m["licenca"]))
    linhas += ["", "## Pacotes CC0 (domínio público)", ""]
    for nome, site, o_que in CC0:
        linhas.append("- **%s** (%s) — %s" % (nome, site, o_que))
    open(os.path.join(RAIZ, SAIDA_MD), "w", encoding="utf-8").write("\n".join(linhas) + "\n")

    gd = ['class_name CreditosDados', 'extends RefCounted',
          '## GERADO por tools/creditos.py — nao editar na mao.',
          '##',
          '## Os modelos de terceiro sao CC-BY: credito e OBRIGATORIO, e sem esta',
          '## lista na tela o jogo esta fora da licenca. So entra o que viaja no',
          '## build (pacote no `exclude_filter` nao e distribuido).', '',
          'const CC_BY: Array[Dictionary] = [']
    for m in itens:
        gd.append('\t{"titulo": "%s", "autor": "%s", "grupo": "%s", "licenca": "%s"},'
                  % (escapar(m["titulo"]), escapar(m["autor"]),
                     m["grupo"], escapar(m["licenca"])))
    gd += [']', '', 'const CC0: Array[Dictionary] = [']
    for nome, site, o_que in CC0:
        gd.append('\t{"autor": "%s", "site": "%s", "o_que": "%s"},' % (nome, site, o_que))
    gd += [']', '']
    open(os.path.join(RAIZ, SAIDA_GD), "w", encoding="utf-8").write("\n".join(gd))

    print("%d modelos CC-BY creditados (%d pacote(s) fora do build, nao creditados)"
          % (len(itens), len(fora)))
    print("  %s\n  %s" % (SAIDA_MD, SAIDA_GD))


if __name__ == "__main__":
    main()
