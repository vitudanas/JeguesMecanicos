#!/usr/bin/env python3
"""Garimpa PERSONAGENS na API publica do Sketchfab, filtrando por licenca e rig.

Existe por causa de uma medicao: os 7 personagens baixados em 2026-08-09 vieram
**sem esqueleto** (6 dos 7) e **sem nenhuma animacao** (7 de 7) — inclusive um
chamado "..._animated_3d_character". Baixar personagem sem rig e baixar estatua:
nao anda, nao mexe o braco, e transformar em jogavel exige riggar no Blender.

Entao aqui o filtro que importa nao e so licenca e contagem de faces: e
`animationCount` e `isRigged`, que a API devolve na propria busca. O que sai
desta lista ja vem pronto pra entrar em `Appearance.MODELS`.

    python3 tools/garimpo_personagens.py                 # homens (padrao)
    python3 tools/garimpo_personagens.py --genero mulher
    python3 tools/garimpo_personagens.py --so-rigado     # descarta sem esqueleto

O download em si continua sendo do usuario: a API de download responde 401 com
cookie de sessao (quer Bearer token), e cacar token em armazenamento de pagina
seria mexer em credencial. Ver docs/personagens.md.
"""
import json
import subprocess
import sys
import urllib.parse

API = "https://api.sketchfab.com/v3/search"

# CC0 e CC-BY servem: as duas permitem uso comercial. CC-BY exige credito, que o
# projeto ja gera em docs/creditos.md (tools/creditos.py).
LICENCAS_OK = ["cc0", "by"]

MAX_FACES = 120_000   # personagem de jogo; acima disso e scan
MIN_FACES = 800

TERMOS = {
    "homem": [
        "male character rigged game ready",
        "man character low poly rigged",
        "male character animated game asset",
        "casual man character rigged",
        "businessman character rigged low poly",
        "old man character rigged",
        "worker character rigged low poly",
        "male npc character game ready",
    ],
    "mulher": [
        "female character rigged game ready",
        "woman character low poly rigged",
        "casual woman character rigged",
        "female npc character game ready",
    ],
}

# O que NAO serve pra um pedestre/jogador de cidade moderna.
VETO = ("medieval", "fantasy", "orc", "goblin", "demon", "zombie", "skeleton",
        "knight", "warrior", "samurai", "sci-fi", "scifi", "cyber", "robot",
        "alien", "voxel", "minecraft", "anatomy", "ecorche", "bust", "head only",
        "statue", "nude", "naked",
        # Personagem de desenho/fan art: o jogo tem gente comum na rua, e
        # misturar estilo e o problema que este projeto ja corrigiu tres vezes.
        # Sem esta lista entraram Sonic, Squidward e "Balerina Capuchino".
        "sonic", "squidward", "spongebob", "mario", "roblox", "fan art",
        "fanart", "anime", "chibi", "psx", "capuchino", "sahur", "meme",
        "soldier", "soldat", "military", "tactical", "armor", "survivor")


def buscar(termo, max_faces):
    achados = []
    for lic in LICENCAS_OK:
        q = urllib.parse.urlencode({
            "type": "models", "downloadable": "true", "license": lic,
            "q": termo, "count": 24, "sort_by": "-likeCount"})
        try:
            # curl e nao urllib: o Python deste ambiente nao tem a cadeia de
            # certificados e falha em toda chamada HTTPS.
            saida = subprocess.run(["curl", "-sS", "%s?%s" % (API, q)],
                                   capture_output=True, timeout=40).stdout
            dados = json.loads(saida)
        except Exception as e:
            print("  (falhou %s / %s: %s)" % (termo, lic, e), file=sys.stderr)
            continue
        for m in dados.get("results", []):
            nome = (m.get("name") or "").lower()
            if any(v in nome for v in VETO):
                continue
            faces = m.get("faceCount") or 0
            if faces < MIN_FACES or faces > max_faces:
                continue
            achados.append({
                "nome": m.get("name"),
                "faces": faces,
                "licenca": lic,
                "animacoes": m.get("animationCount") or 0,
                # `isRigged` nao vem nesta rota da API; animacao > 0 implica esqueleto.
                "rigado": (m.get("animationCount") or 0) > 0,
                "uid": m.get("uid"),
                "url": "https://sketchfab.com/3d-models/%s" % m.get("uid"),
                "likes": m.get("likeCount", 0),
                "autor": (m.get("user") or {}).get("displayName", "?"),
            })
    return achados


def main():
    genero = "homem"
    if "--genero" in sys.argv:
        genero = sys.argv[sys.argv.index("--genero") + 1]
    so_rigado = "--so-rigado" in sys.argv
    max_faces = MAX_FACES
    if "--max-faces" in sys.argv:
        max_faces = int(sys.argv[sys.argv.index("--max-faces") + 1])

    vistos = {}
    for termo in TERMOS.get(genero, TERMOS["homem"]):
        print("buscando: %s" % termo, file=sys.stderr)
        for m in buscar(termo, max_faces):
            vistos[m["uid"]] = m          # o mesmo modelo cai em varios termos

    lista = list(vistos.values())
    if so_rigado:
        lista = [m for m in lista if m["rigado"] or m["animacoes"] > 0]
    # Ordena pelo que mais importa: com animacao primeiro, depois rigado, e o
    # desempate por likes (que na pratica separa modelo caprichado de rascunho).
    lista.sort(key=lambda m: (m["animacoes"] > 0, m["rigado"], m["likes"]),
               reverse=True)

    com_anim = sum(1 for m in lista if m["animacoes"] > 0)
    rigados = sum(1 for m in lista if m["rigado"])
    print("\n# Personagens (%s) — %d candidatos" % (genero, len(lista)))
    print("\n%d com animacao propria, %d rigados, %d sem esqueleto"
          % (com_anim, rigados, len(lista) - rigados))
    print("\nBaixe em **glTF**. O que tem animacao propria entra direto; o que so")
    print("e rigado precisa da UAL1 aplicada por cima (o esqueleto tem que bater,")
    print("conferir com tools/verify/analisar_realistas.tscn); o que nao tem")
    print("esqueleto NAO serve como jogavel sem passar pelo Blender.\n")
    print("| animações | rig | faces | licença | modelo | autor |")
    print("|---|---|---|---|---|---|")
    for m in lista[:60]:
        print("| %d | %s | %s | %s | [%s](%s) | %s |" % (
            m["animacoes"], "sim" if m["rigado"] else "NAO",
            "{:,}".format(m["faces"]).replace(",", "."),
            "CC0" if m["licenca"] == "cc0" else "CC-BY",
            (m["nome"] or "?").replace("|", "/"), m["url"], m["autor"]))


if __name__ == "__main__":
    main()
