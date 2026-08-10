#!/bin/bash
# Recebe os pacotes que o navegador salva na raiz do projeto: espera cada zip
# PARAR DE CRESCER, desempacota em assets/realistas/<nome> e arquiva o zip.
#
# A espera nao e paranoia: desempacotei um pacote de 29 MB com 14 MB baixados e
# o unzip cuspiu "End-of-central-directory signature not found". O arquivo
# parcial ja estava na pasta e parecia pronto.
#
# Tambem recolhe PASTA JA DESCOMPACTADA, e isso nao e luxo: o macOS abre o zip
# sozinho ao baixar, entao boa parte do que se baixa nunca chega aqui como
# `.zip`. Em 2026-08-10 ficaram 20 personagens parados na raiz por causa disso —
# e pior, a raiz e pasta do projeto, entao eles entravam no build (`.pck` de
# 1,4 GB) sem estar no jogo.
cd "$(dirname "$0")/.." || exit 1

# Destino: predios (padrao) ou personagens. Sao pastas diferentes porque o
# pipeline seguinte e outro — predio passa pelo fatiador, personagem passa por
# tools/preparar_personagens.tscn.
DEST=assets/realistas
case "$1" in
  personagens|chars) DEST=assets/personagens ;;
esac
mkdir -p "$DEST/_zips"
for z in *.zip; do
  [ -e "$z" ] || continue
  anterior=0
  for _ in $(seq 1 60); do
    atual=$(stat -f%z "$z" 2>/dev/null || echo 0)
    [ "$atual" = "$anterior" ] && [ "$atual" != "0" ] && break
    anterior=$atual
    sleep 3
  done
  nome=$(basename "$z" .zip | tr 'A-Z' 'a-z' \
      | sed 's/_-_low_poly_model//;s/_corner_\[france\]/_corner/;s/[^a-z0-9_]/_/g;s/__*/_/g;s/_$//')
  rm -rf "$DEST/$nome"
  mkdir -p "$DEST/$nome"
  if unzip -qo "$z" -d "$DEST/$nome"; then
    mv "$z" "$DEST/_zips/"
    echo "ok  $nome  ($(du -sh "$DEST/$nome" | cut -f1))"
  else
    echo "FALHOU $z (zip incompleto?)"
  fi
done

# Pasta ja descompactada. O teste e o CONTEUDO (tem um scene.gltf/glb/fbx
# dentro?), e nao o nome: assim as pastas do proprio Godot que moram na raiz
# (export_templates, script_templates...) nunca sao tocadas.
for d in */; do
  d=${d%/}
  case "$d" in assets|autoload|builds|docs|scenes|scripts|shaders|tools) continue ;; esac
  achou=""
  for cand in scene.gltf scene.glb scene.fbx; do
    [ -f "$d/$cand" ] && achou=1 && break
  done
  [ -n "$achou" ] || continue
  nome=$(echo "$d" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9_]/_/g;s/__*/_/g;s/^_//;s/_$//')
  rm -rf "$DEST/$nome"
  mv "$d" "$DEST/$nome"
  echo "ok  $nome  ($(du -sh "$DEST/$nome" | cut -f1))  [ja vinha descompactado]"
done
