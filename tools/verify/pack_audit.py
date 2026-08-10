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


PLACEHOLDER = re.compile(r"%0?\d*[ds]")


def expand_pattern(ref: str) -> list:
    """`res://.../som_%03d.ogg` -> os arquivos reais que casam com o padrao."""
    rel = PLACEHOLDER.sub("*", ref[len("res://"):])
    return sorted(ROOT.glob(rel))


## O projeto pede todo conjunto ambientCG nos TRES mapas, montando o caminho com
## `%s` (ver CitySurface.gd e MountainRange.gd). Como o caminho nunca aparece
## inteiro no codigo, uma limpeza de arquivo passa batida por este auditor: em
## 2026-08-09 apaguei o NormalGL e o Roughness do Gravel022 achando que so a cor
## era usada — o chao usa so a cor, mas o piso de cascalho da cidade usa os tres,
## e o jogo passou a soltar "Resource file not found" em silencio (erro de load
## nao reprova teste nenhum). Aqui a convencao vira regra.
PBR_MAPS = ("Color", "NormalGL", "Roughness")


def check_pbr_sets() -> list:
    faltando = []
    pat = re.compile(r"res://(assets/ambientcg/[^\"']*?%s[^\"']*?\.jpg)")
    for f in [ROOT / x for x in SOURCE_FILES] + [
            p for d in SOURCE_DIRS for p in (ROOT / d).rglob("*")
            if p.suffix in SOURCE_EXT]:
        try:
            text = f.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for rel in pat.findall(text):
            for mapa in PBR_MAPS:
                alvo = ROOT / (rel % mapa)
                if not alvo.exists():
                    faltando.append(str(alvo.relative_to(ROOT)))
    return sorted(set(faltando))


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


## Fontes mais novas que o build que estamos auditando.
##
## POR QUE ISTO EXISTE. O caminho do build e FIXO aqui, e exportar pra outro
## lugar (`--export-release "macOS" builds/outro.zip`) nao da erro nenhum: o
## auditor simplesmente le o zip ANTIGO e diz "nenhum problema encontrado" sobre
## um build que ninguem acabou de gerar. Foi o que aconteceu em 2026-08-09 —
## aprovei um pacote de 142 MB enquanto o recem-exportado tinha 674 MB. Auditar
## build velho e pior que nao auditar, porque da confianca.
def newer_than_build(zip_path: pathlib.Path) -> list:
    build_mtime = zip_path.stat().st_mtime
    fontes = []
    for sub in ("scripts", "scenes", "autoload", "shaders"):
        for f in (ROOT / sub).rglob("*"):
            if f.suffix.lower() in (".gd", ".tscn", ".gdshader") \
                    and f.stat().st_mtime > build_mtime:
                fontes.append(str(f.relative_to(ROOT)))
    for nome in ("project.godot", "export_presets.cfg"):
        f = ROOT / nome
        if f.exists() and f.stat().st_mtime > build_mtime:
            fontes.append(nome)
    return sorted(fontes)


def main() -> int:
    zip_path = ROOT / "builds" / "macos" / "JeguesMecanicos.zip"
    if not zip_path.exists():
        sys.exit("build nao encontrado: %s (exporte antes)" % zip_path)
    stale = newer_than_build(zip_path)
    data = pack_bytes(zip_path)
    refs = collect_refs()

    missing = []
    skipped = 0
    expanded = 0
    for ref in sorted(refs):
        ext = pathlib.Path(ref).suffix.lower()
        # Caminho montado em runtime (o AudioManager usa "..._%03d.ogg" pra
        # varrer as variacoes de um som). O nome literal nao existe em disco,
        # entao a checagem normal nao diria nada — e como .ogg ainda por cima
        # cai em IMPORTED_EXT, o padrao passaria 100% calado. Aqui ele e
        # EXPANDIDO e cobra-se que case com pelo menos um arquivo de verdade,
        # que e o que pega um erro de digitacao no padrao.
        if PLACEHOLDER.search(ref):
            hits = expand_pattern(ref)
            if not hits:
                missing.append((ref, "padrao nao casa com nenhum arquivo"))
            else:
                expanded += len(hits)
            continue
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
    if expanded:
        print("caminhos montados em runtime: %d arquivos casados" % expanded)
    for alvo in check_pbr_sets():
        missing.append((alvo, "CONJUNTO PBR INCOMPLETO (falta no disco)"))
    if stale:
        for f in stale[:5]:
            missing.append((f, "MAIS NOVO QUE O BUILD (reexporte)"))
        if len(stale) > 5:
            missing.append(("... e mais %d arquivo(s)" % (len(stale) - 5),
                            "MAIS NOVO QUE O BUILD"))
    if missing:
        print("\n%d PROBLEMA(S):" % len(missing))
        for ref, why in missing:
            print("  - %-60s %s" % (ref, why))
        return 1
    print("\nnenhum problema encontrado")
    return 0


if __name__ == "__main__":
    sys.exit(main())
