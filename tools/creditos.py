#!/usr/bin/env python3
"""Monta a tela de creditos a partir dos `license.txt` de cada modelo baixado.

Os modelos do Sketchfab sao CC-BY: uso comercial liberado, credito OBRIGATORIO.
Manter essa lista na mao daria errado na primeira vez que alguem baixasse mais
um pacote — aqui ela sai do proprio arquivo que o Sketchfab poe dentro do zip.
"""
import os
import re

BASE = "assets/realistas"
SAIDA = "docs/creditos.md"


def ler(pasta):
    caminho = os.path.join(BASE, pasta, "license.txt")
    if not os.path.exists(caminho):
        return None
    t = open(caminho, encoding="utf-8", errors="ignore").read()
    campo = lambda k: (re.search(r"\* %s:\s*(.+)" % k, t) or [None, "?"])[1].strip()
    autor = campo("author")
    nome = re.sub(r"\s*\(http.*\)", "", autor)
    return {"titulo": campo("title"), "fonte": campo("source"),
            "autor": nome, "perfil": (re.search(r"\((https[^)]+)\)", autor) or [None, ""])[1],
            "licenca": campo("license type")}


def main():
    itens = []
    for d in sorted(os.listdir(BASE)):
        if not os.path.isdir(os.path.join(BASE, d)):
            continue
        m = ler(d)
        if m:
            itens.append(m)
    linhas = ["# Créditos dos modelos de terceiros", "",
              "Gerado por `tools/creditos.py` a partir do `license.txt` de cada pacote.",
              "**CC-BY exige crédito** — esta lista alimenta a tela de créditos do jogo.",
              ""]
    for m in itens:
        linhas.append('- **%s** por [%s](%s) — [%s](%s), licença %s'
                      % (m["titulo"], m["autor"], m["perfil"], "página do modelo",
                         m["fonte"], m["licenca"]))
    open(SAIDA, "w").write("\n".join(linhas) + "\n")
    print("%d modelos creditados em %s" % (len(itens), SAIDA))


if __name__ == "__main__":
    main()
