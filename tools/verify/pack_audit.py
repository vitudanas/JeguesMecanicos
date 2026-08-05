#!/usr/bin/env python3
"""Confere que TUDO que o jogo referencia esta dentro do .pck exportado.

Por que existe: esta e a classe de bug mais cara do projeto e ja aconteceu
duas vezes.

  * 2026-08-02 — um `exclude_filter` amplo demais cortou `Textures/colormap.png`
    e o jogo simplesmente NAO ABRIA, sem erro visivel.
  * 2026-08-04 — um `.tscn` escrito a mao (a tela de graficos) ficou de fora do
    pacote: presente no cache do editor, ausente no `.pck`. O `preload` dele
    teria quebrado o menu principal so no binario exportado.

Os dois so aparecem rodando o build de verdade — o modo desenvolvedor le do
disco e nunca reclama. Aqui a conferencia e mecanica: varre os arquivos do
projeto atras de todo caminho `res://`, e cobra cada um dentro do pacote.

    python3 tools/verify/pack_audit.py

Sai com codigo 1 se faltar alguma coisa.
"""

import pathlib
import re
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]

# Onde procurar referencias. `tools/` fica de fora de proposito: ele esta no
# `exclude_filter`, entao o que ele referencia nao precisa estar no pacote.
SOURCE_DIRS = ["scenes", "scripts", "autoload", "shaders"]
SOURCE_FILES = ["project.godot"]
SOURCE_EXT = {".gd", ".tscn", ".tres", ".gdshader", ".godot"}

REF = re.compile(r"res://[A-Za-z0-9_./ %+-]+?\.[A-Za-z0-9]+")

# Extensoes que o importador converte: o `.pck` guarda o arquivo IMPORTADO
# (.ctex, .mesh...) e nao o original, entao cobrar o nome de origem daria falso
# alarme. O que importa e a pasta `.godot/imported`, coberta pelo proprio
# funcionamento do jogo.
IMPORTED_EXT = {".png", ".jpg", ".jpeg", ".hdr", ".exr", ".glb", ".gltf",
                ".fbx", ".obj", ".ogg", ".wav", ".mp3", ".ttf", ".svg"}


def pack_bytes(zip_path: pathlib.Path) -> bytes:
    with zipfile.ZipFile(zip_path) as z:
        names = [n for n in z.namelist() if n.endswith(".pck")]
        if not names:
            sys.exit("nao achei .pck dentro de %s" % zip_path)
        return z.read(names[0])


def in_pack(ref: str, data: bytes) -> bool:
    """O caminho original OU a forma convertida do exportador.

    Cena e recurso de texto nao entram no `.pck` com o nome de origem: o
    exportador converte pra binario e guarda em
    `res://.godot/exported/<id>/export-<hash>-<Nome>.scn`, com uma tabela de
    remapeamento. Cobrar so o caminho original acusava `Main.tscn` como
    ausente — e ele obviamente esta la.

    Limitacao conhecida: a forma convertida so carrega o NOME do arquivo, entao
    duas cenas de mesmo nome em pastas diferentes nao sao distinguidas aqui.
    """
    if ref.encode("utf-8") in data:
        return True
    stem = pathlib.Path(ref).stem
    ext = pathlib.Path(ref).suffix.lower()
    converted = {".tscn": ".scn", ".tres": ".res"}.get(ext)
    if converted is None:
        return False
    return ("-%s%s" % (stem, converted)).encode("utf-8") in data


def collect_refs() -> set:
    refs = set()
    files = [ROOT / f for f in SOURCE_FILES]
    for d in SOURCE_DIRS:
        files += [p for p in (ROOT / d).rglob("*") if p.suffix in SOURCE_EXT]
    for f in files:
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for m in REF.findall(text):
            refs.add(m.rstrip('"').rstrip("'"))
    return refs


def main() -> int:
    zip_path = ROOT / "builds" / "macos" / "JeguesMecanicos.zip"
    if not zip_path.exists():
        sys.exit("build nao encontrado: %s (exporte antes)" % zip_path)
    data = pack_bytes(zip_path)
    refs = collect_refs()

    missing = []
    skipped = 0
    for ref in sorted(refs):
        ext = pathlib.Path(ref).suffix.lower()
        if ext in IMPORTED_EXT:
            skipped += 1
            continue
        if not (ROOT / ref[len("res://"):]).exists():
            # Referencia pra arquivo que nao existe mais no projeto: e problema,
            # mas de codigo morto, nao de empacotamento.
            missing.append((ref, "nao existe no projeto"))
            continue
        if not in_pack(ref, data):
            missing.append((ref, "FORA DO PACOTE"))

    print("pacote: %.0f MB" % (len(data) / 1e6))
    print("referencias conferidas: %d (%d importadas, puladas)" % (len(refs) - skipped, skipped))
    if missing:
        print("\n%d PROBLEMA(S):" % len(missing))
        for ref, why in missing:
            print("  - %-60s %s" % (ref, why))
        return 1
    print("\nnenhum problema encontrado")
    return 0


if __name__ == "__main__":
    sys.exit(main())
