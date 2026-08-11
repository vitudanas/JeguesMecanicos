#!/usr/bin/env python3
"""Ajusta o IMPORT dos personagens baixados: textura capada e morph sem uso fora.

Por que existe: os modelos recebidos do Sketchfab vem em tamanho de portfolio,
nao de jogo — 893 MB de textura crua (ate 4K por mapa) e ate 176 shape keys
faciais por arquivo. E o exportador leva TUDO que esta na pasta do projeto
(`export_filter="all_resources"`), entao isso vira build: medido em 2026-08-10,
o `.pck` foi a 1,4 GB (o normal do projeto e ~190 MB).

As duas correcoes sao no IMPORT, e nao no arquivo, de proposito: o original fica
intacto (e re-baixavel, mas grande) e quem viaja no `.pck` e a versao
importada.

  1. `process/size_limit=1024` nas texturas — a mesma resolucao que
     `tools/build_characters.py` usa nos dois personagens nativos. O jogador
     aparece UM por vez na tela.
  2. `import_script` apontando pra `tools/pos_import_personagem.gd`, que remove
     as shape keys que o jogo nunca usa. Sao elas que incham o `.scn`: cada
     morph guarda uma copia de todos os vertices.

Uso (a pasta precisa ter sido importada uma vez, pra existir o `.import`):

    python3 tools/preparar_import_personagens.py
    godot --headless --path . --editor --quit     # reimporta
"""

import pathlib
import re
import sys

LIMITE = 1024
POS_IMPORT = "res://tools/pos_import_personagem.gd"
RAIZ = pathlib.Path(__file__).resolve().parent.parent / "assets" / "personagens"


def capar_textura(imp: pathlib.Path, texto: str) -> str | None:
    """Resolucao capada, compressao de VRAM ligada e mipmap."""
    novo = texto
    if "process/size_limit=" in novo:
        novo = novo.replace("process/size_limit=0", "process/size_limit=%d" % LIMITE)
    else:
        print("  ! %s: sem o campo process/size_limit — pulei" % imp.name)
    # COMPRESSAO DE VRAM. Sem ela a textura fica RGBA8 crua na placa de video:
    # medido, os 28 modelos de pedestre custavam +577 MB de VRAM, e a cidade
    # inteira chegava a 2,5 GB. O modo 2 (VRAM Compressed) e ~4x menor.
    #
    # O Godot tem `detect_3d/compress_to=1`, que faria isso sozinho — mas so
    # dispara quando o EDITOR abre uma cena 3D que usa a textura, e aqui tudo e
    # importado headless. Por isso vai explicito.
    novo = novo.replace("compress/mode=0", "compress/mode=2")
    # Mipmap: pedestre a 100 m sem mipmap cintila, e ainda custa mais banda de
    # textura que a versao com.
    novo = novo.replace("mipmaps/generate=false", "mipmaps/generate=true")
    return novo if novo != texto else None


def ligar_pos_import(imp: pathlib.Path, texto: str) -> str | None:
    if POS_IMPORT in texto:
        return None
    if "import_script/path=" not in texto:
        print("  ! %s: sem o campo import_script/path — pulei" % imp.name)
        return None
    return texto.replace('import_script/path=""', 'import_script/path="%s"' % POS_IMPORT)


def atualizar_exclude_filter() -> None:
    """Poe no `exclude_filter` dos dois presets os modelos que o jogo nao usa.

    Gerado a partir do catalogo, e nao escrito a mao, porque a lista muda toda
    vez que chega personagem novo — e `export_filter="all_resources"` leva tudo
    que esta na pasta, entao um modelo reprovado que ninguem lembrou de excluir
    viaja no `.pck` calado.
    """
    catalogo = RAIZ / "catalogo.gd"
    presets = RAIZ.parent.parent / "export_presets.cfg"
    if not catalogo.exists() or not presets.exists():
        return
    texto = catalogo.read_text(encoding="utf-8")
    fora = re.findall(r'"id": "([^"]+)"[^}]*?"jogavel": false', texto, re.S)
    padroes = ["assets/personagens/_zips/*"]
    padroes += ["assets/personagens/%s/*" % i for i in sorted(fora)]

    cfg = presets.read_text(encoding="utf-8")
    linhas = []
    for linha in cfg.splitlines(keepends=True):
        if linha.startswith("exclude_filter="):
            atuais = linha.split('"', 2)[1].split(",")
            mantidos = [p for p in atuais if not p.startswith("assets/personagens/")]
            # Os de personagem entram logo depois do primeiro padrao, pra
            # diferenca no git ficar sempre no mesmo lugar.
            novo = mantidos[:1] + padroes + mantidos[1:]
            linha = 'exclude_filter="%s"\n' % ",".join(novo)
        linhas.append(linha)
    presets.write_text("".join(linhas), encoding="utf-8")
    print("exclude_filter: %d modelo(s) fora do build (+ os zips)" % len(fora))


def main() -> int:
    if not RAIZ.exists():
        print("nada em %s" % RAIZ)
        return 0
    atualizar_exclude_filter()
    texturas = 0
    cenas = 0
    for imp in sorted(RAIZ.rglob("*.import")):
        if "_zips" in imp.parts:
            continue
        texto = imp.read_text(encoding="utf-8")
        novo = None
        if 'importer="texture"' in texto:
            novo = capar_textura(imp, texto)
            texturas += novo is not None
        elif 'importer="scene"' in texto:
            novo = ligar_pos_import(imp, texto)
            cenas += novo is not None
        if novo:
            imp.write_text(novo, encoding="utf-8")

    print("%d textura(s) capadas em %d px, %d cena(s) ligadas ao pos-import"
          % (texturas, LIMITE, cenas))
    print("agora reimporte:  godot --headless --path . --editor --quit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
