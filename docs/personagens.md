# Personagens jogáveis: o que baixar

Levantado em 2026-08-09 a pedido do usuário, que quer escolher o boneco no menu
e personalizar o corpo.

**Todos os modelos abaixo são CC-BY** (`CC Attribution`): uso comercial liberado,
**crédito obrigatório**. Confirmado um a um pela API pública do Sketchfab, não
pela página. Ao integrar, o autor entra em [docs/creditos.md](creditos.md) — sem
isso o jogo fica fora da licença.

## Como baixar

O navegador embutido **não completa o download** (a transferência é abortada — já
estava documentado no CLAUDE.md, e reconfirmado nesta sessão clicando no botão de
verdade, não só por JavaScript). Então o download é seu:

1. abra o link,
2. **Download 3D Model** → linha **glTF** → **DOWNLOAD**,
3. salve o `.zip` na pasta do jogo (`/Users/Shared/JOGO2`).

`tools/receber_modelos.sh` recolhe os zips da raiz. Ele **espera cada arquivo
parar de crescer** antes de abrir: descompactar um zip pela metade dá
"End-of-central-directory signature not found" e o parcial fica na pasta
parecendo pronto.

## A lista

| modelo | autor | triângulos | link |
|---|---|---:|---|
| Anime Girl Casual Outfit \| Stylized 3D Character | agra_aoe | 126.768 | [abrir](https://sketchfab.com/3d-models/anime-girl-casual-outfit-stylized-3d-character-c9e4a8b3ebdc4677b8ef25a7d59cf038) |
| Tanya — Stylized Cheerleader Girl | agra_aoe | 132.610 | [abrir](https://sketchfab.com/3d-models/tanya-stylized-cheerleader-girl-3d-character-78399c69402744b1a06900d4080310e4) |
| Carol Tennis Player Girl | agra_aoe | 64.507 | [abrir](https://sketchfab.com/3d-models/carol-tennis-player-girl-animated-3d-character-7e3c54909e834196aaed1661e2581413) |
| Hot Blonde Anime Girl Fashion model | lawlietrecluze | 49.630 | [abrir](https://sketchfab.com/3d-models/hot-blonde-anime-girl-fashon-model-stylized-3d-ef1778f467cb4f4f88840d4db3bb77a1) |
| Anime Girl Hot Outfit | lawlietrecluze | 17.850 | [abrir](https://sketchfab.com/3d-models/anime-girl-hot-outfit-stylized-3d-character-7a98ea581462401b94419dd1a5a270a7) |
| Anime Girl Rigged Anime model | dequeijospizza | 45.462 | [abrir](https://sketchfab.com/3d-models/anime-girl-rigged-anime-model-fbccf5c5a7b244e7ab04fa44da19c621) |
| Just a girl (a sentada) | 腱鞘炎の人 | 77.725 | [abrir](https://sketchfab.com/3d-models/just-a-girl-b2359160a4f54e76b5ae427a55d9594d) |

## O problema da "Just a girl"

Ela é a que o usuário pediu primeiro, e é a mais difícil das sete. Medido pela
API antes de baixar:

- **0 animações** e nenhum esqueleto — é um sculpt estático feito no Maya em
  2018, publicado como concept art;
- e o pior: está modelada **SENTADA**, de mãos no rosto.

Rigar por código é possível (o projeto já roda Blender headless em
`tools/build_characters.py`, e o Blender tem peso automático), mas **o problema
não é o esqueleto, é a pose de repouso**. Peso automático sobre uma malha sentada
produz um rig cuja pose de descanso é sentada; jogar um ciclo de caminhada em
cima disso dobra a perna a partir de onde ela já está dobrada e cruza os braços
na frente do rosto. Pra ficar bom, a malha precisa primeiro ser POSTA em T-pose,
que é trabalho manual de modelagem.

**Recomendação**: usá-la como estátua/decoração no mundo (sentada num banco de
praça, que é a pose dela), e deixar os jogáveis para os modelos que já vêm em
T-pose. Se for pra tentar mesmo assim, o caminho é: importar no Blender, rotacionar
os ossos de perna/braço pra T antes de aplicar peso automático, e conferir na
folha de contato — não confiar no resultado sem olhar.

## Escala e esqueleto: o que conferir ao integrar

Nenhum desses modelos foi feito pra este jogo, então valem as mesmas armadilhas
que os prédios já cobraram:

1. **Escala em metros.** O jogador tem 1,80 m. Medir a AABB e normalizar, como
   `tools/fatiar_realistas.gd` faz — não confiar na escala do arquivo.
2. **A animação é de outro esqueleto.** As animações do jogo vêm da
   `universal-animation-library-1` (Quaternius, 65 ossos). Se o esqueleto do
   modelo baixado não tiver os mesmos nomes de osso, é preciso retargeting
   (BoneMap + SkeletonProfileHumanoid). Conferir os nomes ANTES de integrar: foi
   assim que em 2026-08-03 se descobriu que o corpo do Quaternius e a UAL
   compartilhavam esqueleto e o retargeting era desnecessário.
3. **Formas do corpo.** As sliders de busto/glúteo do menu usam *shape keys*, que
   só existem nos modelos gerados por `tools/build_characters.py`. Modelo baixado
   sem shape key aparece no menu **sem** essas sliders (altura e cor continuam
   valendo) — ou precisa passar pelo mesmo script do Blender pra ganhá-las.
