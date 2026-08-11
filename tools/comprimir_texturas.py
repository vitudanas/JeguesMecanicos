#!/usr/bin/env python3
"""Liga COMPRESSAO DE VRAM nas texturas 3D do jogo.

Por que: medido com `tools/verify/perf_probe.tscn`, a cidade usava **2,5 GB de
memoria de textura**. A causa e que todas as texturas estavam em
`compress/mode=0` (Lossless), que no disco comprime mas na PLACA DE VIDEO fica
RGBA8 cru — 1024x1024 vira 4 MB, e sao centenas.

O Godot tem `detect_3d/compress_to=1`, que faria isso sozinho, mas so dispara
quando o EDITOR abre uma cena 3D que usa a textura. Neste projeto tudo e
importado headless, entao nunca disparou em nada.

Ficam de FORA de proposito: `assets/icon` (icone do jogo e da janela, onde
artefato de compressao aparece em cheio) e as `Previews` dos kits, que nem
entram no build.

    python3 tools/comprimir_texturas.py
    godot --headless --path . --editor --quit     # reimporta (demora)
"""

import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent / "assets"
FORA = ("icon", "Previews", "_zips")


def main() -> int:
    mexidas = 0
    ja = 0
    for imp in sorted(RAIZ.rglob("*.import")):
        if any(parte in FORA for parte in imp.parts):
            continue
        texto = imp.read_text(encoding="utf-8")
        if 'importer="texture"' not in texto:
            continue
        if "compress/mode=2" in texto:
            ja += 1
            continue
        novo = texto.replace("compress/mode=0", "compress/mode=2")
        novo = novo.replace("mipmaps/generate=false", "mipmaps/generate=true")
        if novo == texto:
            continue
        imp.write_text(novo, encoding="utf-8")
        mexidas += 1
    print("%d textura(s) passaram pra VRAM comprimida, %d ja estavam" % (mexidas, ja))
    if mexidas:
        print("reimporte:  godot --headless --path . --editor --quit")
    return 0


if __name__ == "__main__":
    sys.exit(main())
