# CLAUDE.md — Jegues Mecânicos

Documento vivo do projeto. Aqui ficam registrados o pitch do jogo, decisões técnicas,
o histórico de ordens/mudanças pedidas pelo usuário e o roadmap. Atualizar sempre que
uma decisão relevante for tomada ou o escopo mudar.

## Notas de fluxo de trabalho

- **Sempre reexportar as builds ao terminar uma modificação.** Pedido do usuário em
  2026-08-03: é pelo `.app` que ele testa o jogo, então uma mudança só está
  concluída depois do export — não deixar pra "quando pedir". Rodar os dois
  presets (`godot --headless --export-release "macOS" builds/...` e o Windows) e,
  seguindo a lição de 2026-08-02, **abrir o binário exportado de verdade** pra
  conferir, não só o modo desenvolvedor: os dois divergem quando o
  `export_filter`/`exclude_filter` corta algo que o jogo precisa.
  **Apagar `debug_tmp/` ANTES de exportar**: PNG de teste largado ali é
  importado pelo Godot como recurso e entra no `.pck` — já inflou o build em
  15MB sem ninguém pedir (2026-08-03). Se o build crescer sem motivo, é o
  primeiro lugar pra olhar.

- **Rodar `/clear` entre sessões/tarefas grandes.** Pedido do usuário em 2026-08-02: a
  conversa fica muito longa depois de várias rodadas seguidas (cada exportação de
  build, cada teste visual etc. consome bastante contexto) — vale limpar o histórico
  do chat com `/clear` de vez em quando, já que este `CLAUDE.md` guarda o essencial do
  progresso e decisões, então uma sessão nova consegue retomar o projeto lendo este
  arquivo sem precisar do histórico completo da conversa anterior.

## Pitch

Jogo 3D de mundo aberto (sandbox), humor absurdo e física caótica, inspirado na vibe de
"Totally Legit Wheeler Dealer". O jogador é dono de uma oficina/concessionária de beira
de estrada muito duvidosa. Em vez de peças originais, os carros são consertados com itens
absurdos do cotidiano ("gambiarras"): dobradiça de porta no capô, mangueira de pia no
radiador, fita isolante no retrovisor, plástico no parachoque. O carro é então vendido a
NPCs usando lábia, escondendo os defeitos até fechar negócio — tudo isso enquanto a
gambiarra ameaça se desmontar no meio do trânsito esburacado da cidade.

Pensado desde o início para, no futuro, ganhar um modo multiplayer (cooperativo na
oficina ou competitivo pelas ruas) — por isso a lógica de jogo evita depender de estado
local hard-coded sempre que possível.

## Core loop

1. **Exploração (1ª pessoa)** — jogador anda pela cidade sandbox e acha carros
   sucateados no ferro-velho (Junkyard).
2. **Reboque** — jogador interage com o carro sucateado e o arrasta a pé (física de
   mola) até a oficina (Workshop).
3. **Gambiarra** — na oficina, os 4 pontos de fixação do carro (capô, radiador,
   retrovisor, parachoque) recebem os itens absurdos correspondentes.
4. **Test-drive caótico (3ª pessoa)** — jogador dirige pela cidade cheia de buracos até
   o comprador; buracos e colisões estressam as gambiarras e podem arrancá-las (viram
   destroços físicos soltos na pista).
5. **Venda "legítima"** — perto do comprador, minigame de lábia: segurar o botão enche
   a barra de persuasão, mas ela drena mais rápido quanto mais gambiarra quebrou.
   Sucesso = venda e dinheiro.

## Decisões técnicas

- **Engine: Godot 4** (4.7.1, instalado via Homebrew) — grátis, exporta nativamente para
  Windows e macOS, leve, ideal para distribuição via itch.io.
- **Câmera:** primeira pessoa a pé, terceira pessoa (chase camera) dirigindo.
- **Estilo visual da vertical slice:** low-poly/blockout — tudo em primitivas (caixas,
  cilindros, cápsulas) com materiais coloridos, sem assets externos. Trocável por
  modelos 3D reais depois.
- **Física do carro:** raycast car controller (4 `RayCast3D` simulando suspensão) sobre
  `RigidBody3D`, em vez de `VehicleBody3D` — mais fácil de deixar "caótico" e de
  quebrar gambiarras de forma controlada.
- **Gambiarras quebráveis:** não usam juntas físicas (`Joint3D`) com break force nativo
  (o Godot 4 não expõe isso de forma simples para `Generic6DOFJoint3D`). Em vez disso,
  cada `GambiarraPart` fica "congelada" (kinematic freeze) seguindo o ponto de fixação
  do carro e recebe eventos de estresse (`receive_stress(force)`) vindos de buracos e
  colisões; ao passar do limiar de resistência, vira um `RigidBody3D` solto (destroço).
- **Input:** sem uso do Input Map do `project.godot` — os controles usam
  `Input.is_key_pressed()` direto no código (WASD, Space, Shift, E, F) para evitar a
  sintaxe frágil de serialização de `InputEventKey` em arquivos `.tscn`/`.godot`
  escritos à mão. Pode ser migrado para Input Map depois, se quiser remapear teclas
  pela interface do editor.
- **CLAUDE.md pedido explicitamente pelo usuário** (01/08/2026) para registrar ordens,
  decisões e objetivos do jogo.

## Sistemas de Mundo Aberto

- **Assets externos** (todos CC0, domínio público, sem exigir atribuição):
  - **Cidade — só Kenney**, de propósito, pra tudo falar a mesma língua visual
    (ver changelog 2026-08-02 "redesenho completo do mapa"):
    [City Kit Roads](https://kenney.nl/assets/city-kit-roads) (malha viária, gerada
    por `scripts/CityStreets.gd`),
    [Commercial](https://kenney.nl/assets/city-kit-commercial),
    [Suburban](https://kenney.nl/assets/city-kit-suburban) (casas) e
    [Industrial](https://kenney.nl/assets/city-kit-industrial) (galpões) — os ~175
    prédios são posicionados por `scripts/CityBlocks.gd`, não à mão.
  - **Campo — só Quaternius**, mesma lógica de manter um estilo por bioma:
    farm-buildings e nature-megakit (via [poly.pizza](https://poly.pizza)).
  - **Carros**: Quaternius Cars Bundle — escolhidos por já virem em escala real
    (4.22m, proporção 2.34:1); o Car Kit do Kenney tinha proporção de brinquedo
    (2.55m, 1.7:1) e saiu de uso (ver changelog 2026-08-03).
  - **NPCs**: `assets/quaternius/characters-dressed/*.glb` — corpo + roupa + cabelo
    já combinados por `tools/build_characters.py` (Blender headless). Animação
    `Walk`/`Idle` da Universal Animation Library **1** (a 2 não tem caminhada
    normal na versão gratuita). Os mesmos arquivos carregam os **tipos físicos
    como shape key** (`Bust`/`Butt`/`Hips` só no feminino, `Belly`/`Bulk`/
    `Chest`/`Skinny` nos dois) — ver changelog 2026-08-03.
  - `export_presets.cfg` tem um `exclude_filter` cortando FBX/OBJ/previews dos kits
    Kenney e as 4 pastas de origem que só o script do Blender usa — sem isso o
    build carregava ~145MB de assets que o jogo nem abre. **Cuidado ao mexer**: um
    filtro amplo demais já cortou uma textura e quebrou o jogo inteiro (changelog
    2026-08-02); sempre confira o `.pck` exportado depois.
- **Tráfego de IA** (`scenes/traffic/`): `TrafficCar.gd` é um `RigidBody3D`
  "congelado" (`freeze = true` + `FREEZE_MODE_KINEMATIC`, o mesmo truque de
  `GambiarraPart.gd`) que fica filho de um `PathFollow3D`; a cada frame só faz
  `path_follow.progress += speed * delta`, e a posição/rotação do carro atualiza
  sozinha (comportamento nativo do `PathFollow3D`). `TrafficRoute.gd` (`Path3D`) monta
  a curva em código a partir de `route_points` (retas simples, cantos de 90°, sem
  pathfinding) e espalha N `TrafficCar` com progresso inicial escalonado e velocidade
  randomizada. Como o carro de tráfego é um corpo físico de verdade, ele já aciona o
  `body_entered` que `Vehicle.gd` usa pra estressar as gambiarras do jogador — nenhuma
  mudança extra foi precisa em `Vehicle.gd` pra isso.
- **Clima e lama** (`autoload/WeatherManager.gd`, novo autoload): `is_raining`
  alterna sozinho num `Timer` com duração aleatória (chuva 25-60s, sol 40-90s),
  emitindo `weather_changed`. `scenes/world/RainFX.tscn` é um `GPUParticles3D` que
  segue o jogador (sempre "no céu" acima dele) e liga/desliga com o sinal.
  `scenes/world/MudZone.gd` (`Area3D`, mesmo padrão de `scripts/Pothole.gd`) fica perto
  dos buracos existentes e, ao detectar o `Vehicle` (grupo `"vehicle"`), chama
  `enter_mud()`/`exit_mud()`. A poça só reduz a tração de fato quando também está
  chovendo — é o `Vehicle.gd` quem decide isso (`_current_traction()`), multiplicando a
  aderência lateral (`grip_mult`) e a força do motor em `_apply_suspension_and_drive()`;
  na lama o carro derrapa nas curvas e acelera pior.
- **Pedestres com ragdoll** (`scenes/npc/Pedestrian.gd` + `PedestrianRoute.gd`): mesmo
  esquema do tráfego (filho de `PathFollow3D`, congelado/kinematic andando pela
  calçada), com os personagens de `assets/quaternius/characters-dressed/`.
  `contact_monitor` ligado: ao detectar
  `body_entered` com velocidade de impacto acima de `ragdoll_impact_threshold` (carro do
  jogador, carro de tráfego ou destroço de gambiarra voando — qualquer `RigidBody3D`
  rápido o suficiente), o pedestre descongela (`freeze = false`), leva um impulso na
  direção oposta ao impacto + torque aleatório (vira ragdoll de verdade por alguns
  segundos) e depois se teleporta de volta pro `PathFollow3D` e recongela sozinho
  (`_recover()`), mesmo truque de "congela/descongela" que já usamos em
  `GambiarraPart.gd`. Validado visualmente que os pedestres spawnam e andam nas rotas;
  o gatilho de ragdoll por colisão usa o mesmo mecanismo de `contact_monitor`/
  `body_entered` já comprovado com `TrafficCar`↔`Vehicle`, mas o teste de dirigir contra
  um pedestre de propósito fica pra você confirmar jogando (não dá pra simular
  input de direção nesta sessão automatizada).
- **Eventos procedurais** (`autoload/EventManager.gd`, novo autoload): um `Timer`
  interno, em intervalos aleatórios (45-90s), spawna um carro sucateado extra
  (`Vehicle.tscn`, `is_wrecked = true` por padrão) num ponto aleatório do grupo
  `"event_spawn_point"` — `Marker3D` chamados `EventSpawnPoint*` em `Town.tscn`,
  registrados no grupo via `Town.gd:_register_event_spawn_points()`. Limite de
  `max_concurrent_events` carros extras simultâneos (filtra instâncias já destruídas/
  vendidas a cada spawn) pra não lotar o mapa.
- **Quarteirões** (`scripts/CityBlocks.gd`): os ~175 prédios **não existem como nós
  em `Town.tscn`** — são gerados em runtime. Pra cada quarteirão da grade de
  `CityStreets` (ruas a cada 25 de -75 a 75 → 36 quarteirões), o script percorre as
  4 bordas enfileirando prédios encostados na calçada e virados pra rua, medindo a
  largura real de cada modelo pra saber quanto avançar (mesma técnica de "andar ao
  longo de um trecho" de `CityStreets.gd`). Detalhes que valem saber antes de mexer:
  - **Escala 6.0 é o módulo nativo do kit** (o tile de rua mede 1.0 e `tile_size`
    é 6.0), então tudo encaixa na mesma grade. Mudar isso desalinha a cidade.
  - Vários modelos do kit têm a **malha deslocada da origem do nó** — o script
    desconta esse offset (`_center_offset`), senão os prédios se sobrepõem.
  - Nenhum prédio pode passar da metade do quarteirão (`depth_budget`), senão duas
    bordas opostas se encontram no meio.
  - Zoneamento por distância do centro (Chebyshev): arranha-céus no miolo,
    comércio no anel do meio, casas e galpões na periferia.
  - Cada fachada recebe um `albedo_color` sorteado (`_tint`), porque todos os
    prédios dividem um atlas de textura só e a cidade sairia toda da mesma cor.
  - As casas geradas entram no grupo `"delivery_house"` guardando o ponto da
    calçada em frente — é daí que `DeliveryManager` sorteia a entrega.
- **Entregas** (`autoload/DeliveryManager.gd`): não há comprador fixo. A cada venda
  sorteia uma casa (nunca a mesma duas seguidas), instancia o `BuyerNPC` na calçada
  em frente virado pra rua, e a `CarZone` dele cai na pista pro jogador encostar o
  carro. Ao fechar a venda, agenda a próxima.

## Controles (vertical slice atual)

- **A pé:** W/A/S/D anda, Shift corre, Space pula, E interage (olhando para o alvo),
  Esc abre/fecha o menu de pause.
- **Dirigindo:** W/S acelera/ré, A/D vira, Space freio de mão, F sai do carro.
- **Venda:** a entrega é numa casa sorteada da cidade (placa verde ENTREGA);
  encoste o carro na frente dela e segure E perto do NPC pra encher a barra de lábia.
- **Menus:** o jogo abre num menu principal (Jogar/Sair); Esc a qualquer momento
  dentro da partida pausa e abre Continuar/Sair para o Menu/Sair do Jogo.

## Estrutura do projeto

```
project.godot          # config do Godot, autoloads, display/fullscreen
export_presets.cfg     # presets Windows Desktop + macOS (testados e funcionando)
autoload/               GameManager.gd, Economy.gd, WeatherManager.gd (clima/chuva),
                        EventManager.gd (eventos procedurais),
                        DeliveryManager.gd (sorteia a casa da entrega da vez)
shaders/                city_surface.gdshader (fachada/asfalto: atlas do kit +
                        PBR triplanar + sombreamento facetado),
                        ground.gdshader (chao do mundo por ruido, sem textura),
                        mountain.gdshader (rocha/mato/neve por altura e declive)
scripts/                Interactable.gd, TowHook.gd, PersuasionMinigame.gd, Pothole.gd,
                        CityStreets.gd (malha viária procedural + semáforo/ponto
                        de ônibus/faixa), CityBlocks.gd (preenche os quarteirões
                        com fileiras de prédios virados pra rua, sorteia lotes
                        especiais — praça, posto, feira, estacionamento — e
                        registra as casas de entrega), StreetFurniture.gd
                        (mobiliário urbano montado com primitivas),
                        CityOutskirts.gd (cinturão de transição cidade→campo),
                        RuralScatter.gd (espalha natureza no anel rural),
                        MountainRange.gd (cordilheira gerada como malha),
                        CitySurface.gd (monta o material das superficies da cidade)
scenes/main/            Main.tscn — cena de entrada (Town + Player + HUD + RainFX)
scenes/player/          Player.tscn/gd — controller 1ª pessoa
scenes/vehicle/         Vehicle.tscn/gd (carro real + suspensao por raycast),
                        AttachSpot.gd, GambiarraPart.gd, parts/*.tscn
tools/verify/           city.tscn, drive_test.tscn e loop_test.tscn —
                        verificacao automatizada (fora do build, ver
                        tools/verify/README.md)
scenes/world/           Town.tscn (cidade + anel rural, tudo num só mundo sandbox),
                        Junkyard.tscn, Workshop.tscn, MudZone.tscn/gd, RainFX.tscn/gd,
                        CityBuilding.tscn (prédio genérico com colisão automática),
                        FarmCluster.tscn/gd (fazenda procedural), ScrapyardCluster.tscn/gd
                        (ferro-velho rural decorativo), RuralWorkshop.tscn (a oficina
                        do jogador, um ferro-velho no campo), CityBlocks.tscn e
                        RuralScatter.tscn (wrappers dos scripts em scripts/)
scenes/traffic/         TrafficCar.tscn/gd, TrafficRoute.tscn/gd — carros de IA
scenes/npc/             BuyerNPC.tscn/gd, Pedestrian.tscn/gd, PedestrianRoute.tscn/gd
scenes/ui/              HUD.tscn/gd — dinheiro, prompt de interação, barra de lábia;
                        MainMenu.tscn/gd (tela inicial, cena de entrada do jogo);
                        PauseMenu.tscn/gd (Esc pausa a árvore, some com o mouse)
assets/kenney/          pacotes CC0 do Kenney.nl (roads, commercial, suburban,
                        industrial, car-kit, animated-characters-protagonists) —
                        toda a CIDADE (ruas e os 175 prédios) é só desses kits, de
                        propósito, ver changelog 2026-08-02/03
assets/quaternius/      downtown-city-megakit (baixado, não usado no layout ativo —
                        ver changelog) + Universal Base Characters/Animation Library/
                        outfits-fantasy (baixados, não integrados nos NPCs, ver
                        Roadmap) + farm-buildings/nature-megakit (usados no anel
                        rural fora da cidade — fazendas, natureza, montanhas) +
                        cars (carros de tráfego em escala real) +
                        universal-animation-library-1 (Walk/Idle normais) +
                        characters-dressed (personagens prontos, gerados por
                        tools/build_characters.py — é o que o jogo carrega)
tools/                  build_characters.py — roda no Blender headless e gera os
                        personagens já vestidos (corpo+roupa+cabelo num arquivo só)
                        e com os tipos físicos gravados como shape key
assets/icon/            ícone do jogo (gerado por código, PIL) + .ico/.icns
builds/                 saída dos exports (ignorado pelo git; publicado como
                        GitHub Release em vez de commitado)
```

## Changelog / ordens do usuário

- **2026-08-01** — Pedido inicial: jogo 3D instalável para itch.io, Windows + macOS.
  Definido: Godot 4, estilo low-poly placeholder, câmera 1ª pessoa a pé / 3ª pessoa
  dirigindo (respostas do usuário via perguntas de esclarecimento).
- **2026-08-01** — Usuário descreveu o conceito completo: mundo aberto, humor, física
  caótica, simulação de negócios (dono de concessionária/oficina duvidosa), core loop
  de reboque → gambiarra → test-drive caótico → venda com lábia. Pensado para
  multiplayer futuro (cooperativo na oficina / competitivo nas ruas).
- **2026-08-01** — Usuário autorizou execução automática ("pode ir fazendo tudo no
  automático sem me perguntar") e pediu explicitamente a criação deste `CLAUDE.md` para
  registrar ordens, alterações e objetivos.
- **2026-08-01** — Instalado Godot 4.7.1 via Homebrew (autorizado pelo usuário) e
  baixados/instalados os Export Templates oficiais (~1.28GB, github.com/godotengine/godot
  releases 4.7.1-stable) após confirmação explícita do usuário, por ser um download
  grande.
- **2026-08-01** — Vertical slice completa implementada e validada: projeto carrega e
  roda sem erros em modo headless; export de teste gerado e testado com sucesso para
  **Windows Desktop** (.exe, ~109MB) e **macOS** (.zip com .app, ~60MB, testado rodando
  headless nesta máquina).
- **2026-08-01** — Usuário definiu o nome oficial do jogo: **Jegues Mecânicos**.
  Atualizado em `project.godot` (config/name), `export_presets.cfg` (nome dos
  executáveis, product_name, bundle identifier) e nos docs.
- **2026-08-01** — Usuário testou e não conseguiu localizar o ferro-velho/oficina/
  comprador no mapa (sandbox grande sem sinalização). Adicionado: placas `Label3D`
  (billboard, `no_depth_test`) acima de cada local, coloridas e visíveis através de
  prédios; e uma bússola no HUD (`GameManager.set_objective()`) que aponta pro
  objetivo atual e muda sozinha conforme o jogador avança no core loop (ferro-velho →
  oficina → comprador). No caminho, corrigido um bug de ordem de `_ready()`: o HUD
  conectava no sinal de objetivo depois que a cidade já tinha emitido o primeiro
  evento, então a bússola nunca aparecia — agora `GameManager` guarda o estado atual
  e o HUD lê direto no `_ready()`. Builds do Windows/macOS regenerados com a correção.
- **2026-08-01** — Usuário pediu uma mira (crosshair) no centro da tela e que o prompt
  de interação ("Rebocar [E]", "Fixar gambiarra [E]" etc.) apareça perto da mira em vez
  de escondido no canto superior esquerdo. Adicionado `Crosshair` (pontinho branco fixo
  no centro) e `CenterPrompt` (texto centralizado logo abaixo da mira, só visível quando
  o raycast do jogador está mirando em algo interagível) em `HUD.tscn`/`HUD.gd`. Builds
  regenerados.
- **2026-08-01** — Usuário testou de novo: o prompt central não aparecia e não dava pra
  achar as peças de gambiarra no carro. Achados e corrigidos dois problemas: (1) bug real
  em `Player.gd` — a referência ao HUD era buscada uma única vez em `_ready()`, mas nessa
  hora o HUD ainda não existia na árvore de cena (mesma classe de bug de ordem de
  `_ready()` já visto com a bússola), então `hud` ficava `null` pra sempre e o prompt
  nunca era mostrado; corrigido buscando o HUD de forma preguiçosa (lazy) dentro de
  `_update_interaction()`. (2) Os 4 pontos de fixação (`AttachSpot`) no carro eram
  Area3D totalmente invisíveis — não tinha nenhum indício visual de onde mirar.
  Adicionado um marcador esférico colorido e brilhante (`MeshInstance3D` unshaded) em
  cada ponto (capô cinza, radiador verde, retrovisor vermelho, parachoque amarelo em
  `Vehicle.tscn`), que some assim que a gambiarra correspondente é instalada
  (`AttachSpot.gd`). Confirmado visualmente rodando o jogo de verdade (não só headless)
  que o prompt "Fixar gambiarra: Parachoque [E]" aparece corretamente ao mirar na
  bolinha amarela. Builds regenerados.
- **2026-08-01** — Usuário pediu pra expandir o mundo aberto: mapa maior com assets
  reais, tráfego de IA, pedestres com ragdoll e eventos procedurais. Priorizamos (por
  escolha do usuário) tráfego de IA + clima/lama nesta rodada; pedestres/ragdoll,
  geração procedural e a reconstrução completa da cidade com assets reais ficam pro
  roadmap (ver abaixo). Pesquisei e baixei 4 pacotes CC0 do Kenney.nl (~44MB, ver seção
  "Sistemas de Mundo Aberto"). Implementado `WeatherManager.gd` (autoload de clima),
  `MudZone`/tração na lama em `Vehicle.gd`, e `TrafficCar`/`TrafficRoute` (carros de
  IA em `Path3D`/`PathFollow3D`, com visual real do Kenney Car Kit). Testado
  visualmente rodando o jogo (chuva, lama, carro de tráfego reais na tela). Também
  ativei `window/size/mode=3` (fullscreen) + `stretch/mode="canvas_items"` +
  `stretch/aspect="expand"` em `project.godot` a pedido do usuário, pra conferir
  proporção da UI — confirmado que HUD/mira/texto escalam certo. Builds regenerados.
- **2026-08-01** — Usuário pediu pra subir o projeto pro GitHub. Instalado GitHub CLI
  (`gh`), autenticado via device code, repo git inicializado localmente e enviado pro
  repositório privado `vitudanas/joguinho2` (rebase em cima do commit inicial do
  GitHub pra não perder nada). Pasta `builds/` continua fora do git (binários grandes,
  regeneráveis). Em seguida, usuário pediu pra continuar o roadmap e manter tudo
  sincronizado no git: implementados **pedestres com ragdoll**
  (`scenes/npc/Pedestrian.gd`/`PedestrianRoute.gd`, visual do Kenney Mini Characters) e
  **geração procedural de eventos** (`autoload/EventManager.gd`, spawna ferros-velhos
  extra em pontos aleatórios do mapa). Testado visualmente (pedestre andando de
  verdade perto da oficina). Builds regenerados e tudo commitado/enviado pro GitHub.
- **2026-08-02** — Usuário reportou que o jogo não abria no Mac. Reproduzi o problema
  de propósito (extraí o `.zip`, marquei com o atributo de quarentena que o macOS
  aplica em downloads reais) e confirmei: o app dava **"'Jegues Mecanicos' is damaged
  and can't be opened"** — mensagem que o Gatekeeper mostra pra apps sem *nenhuma*
  assinatura, sem opção de abrir mesmo assim. Corrigido ativando assinatura **ad-hoc**
  (`codesign/codesign=1` em `export_presets.cfg`, preset macOS — gratuita, não exige
  conta de desenvolvedor Apple). Reexportei e testei de novo com quarentena simulada:
  agora aparece o diálogo padrão do Gatekeeper ("Apple could not verify...") que **é**
  contornável (clique direito → Abrir, ou Ajustes do Sistema → Privacidade e Segurança
  → "Abrir Mesmo Assim"). Também encontrei e corrigi um erro meu: durante o rebase pro
  GitHub (ver 2026-08-01), usei `git checkout --ours README.md` achando que ia manter
  nossa versão — mas no `git rebase` (diferente de um merge normal) o `--ours`/
  `--theirs` fica invertido, então acabei mantendo o README mínimo padrão do GitHub e
  descartando o nosso. `README.md` reescrito com o conteúdo completo (agora já
  refletindo as instruções corretas do Gatekeeper) e as instruções de abrir no Mac.
  Build macOS regenerado e tudo commitado/enviado pro GitHub de novo.
- **2026-08-02** — Usuário testou de novo e o app *ainda* não abria (mesmo já assinado
  ad-hoc, mesmo local, sem quarentena nenhuma). Dessa vez rodei o **executável dentro
  do `.app` exportado diretamente pelo terminal** (em vez de testar via
  `godot --path . scenes/main/Main.tscn`, que é modo desenvolvedor e ignora o
  `export_filter`/`exclude_filter`) e achei o bug de verdade: o `exclude_filter` em
  `export_presets.cfg` tinha o padrão `assets/kenney/*/*.png`, pensado pra cortar só as
  imagens de preview de cada pacote (`Preview.png`, `Sample.png` etc na raiz), mas o
  glob do Godot trata `*` como abrangendo qualquer subpasta — então ele também cortou
  `Textures/colormap.png`, a textura de verdade usada pelos modelos GLB (carros e
  pedestres). Resultado: o `.pck` exportado carregava os modelos sem textura/dependência
  e todo o `res://assets/kenney/...` falhava ao carregar — isso quebrava o carregamento
  de `Town.tscn` inteiro na inicialização, então o jogo nunca chegava a abrir uma janela
  (por isso não aparecia nem erro visível pro usuário, só "não abre"). Removido o padrão
  `*.png` do `exclude_filter` (fica só FBX/OBJ/Previews/html/url, que não têm esse
  conflito). Reexportei os dois presets e, dessa vez, **rodei o binário exportado
  diretamente** (não o modo dev) pra confirmar de verdade — carros e pedestres
  aparecem com textura, zero erro no log. **Lição pra próximas rodadas**: sempre que
  mexer no `export_filter`/`exclude_filter`, testar rodando o `.app`/`.exe` exportado
  de verdade, não só o modo desenvolvedor — os dois podem divergir exatamente por causa
  desse filtro.
- **2026-08-02** — Usuário achou os assets atuais feios (pedestres chibi/miniatura do
  Mini Characters, resto do mapa ainda em blockout) e pediu um visual "desenhado mas
  nem tanto" pro mapa inteiro, com pedestres do tamanho do jogador e carros mais
  estilosos. Baixado o pacote CC0
  [Animated Characters Protagonists](https://kenney.nl/assets/animated-characters-protagonists)
  (proporção humana normal, formato FBX — diferente dos outros pacotes que vinham em
  GLB, esse só tem FBX + texturas de skin separadas). Trocado `Pedestrian.gd`: agora
  instancia o FBX e aplica a textura de skin escolhida via
  `set_surface_override_material()` num `MeshInstance3D` achado recursivamente (o
  modelo vem sem skin própria — Kenney separa malha e textura pra poder trocar de
  personagem). Escala 1:1 já bateu certinho com a altura do jogador, sem precisar
  ajustar. Criado `scripts/AutoCollisionBody.gd` (utilitário genérico: instancia uma
  cena visual e gera sozinho uma `CollisionShape3D` do tamanho exato do mesh, calculando
  a AABB local recursivamente — evita ter que calcular na mão pra cada modelo) e
  `scenes/world/CityBuilding.tscn` em cima dele. Trocados os 6 prédios-caixa de
  `Town.tscn` por modelos reais de `city-kit-commercial` (prédios + skyscrapers) e
  adicionados mais 6 novos espalhados pelo mapa (12 no total). Adicionada decoração de
  rua (`city-kit-roads`: tiles de asfalto com faixa de pedestre, cruzamento, postes de
  luz) ao longo da rota principal. Trocados os carros de tráfego pra variantes mais
  estilosas do Car Kit (`sedan-sports`, `suv-luxury`, `race`, `police`). Melhorada a
  `Environment` de `Town.tscn` (mais luz ambiente, glow leve, SSAO, tonemap) pra tirar o
  aspecto "chapado". Confirmado visualmente rodando o jogo de verdade: cidade com
  prédios/ruas reais, pedestre do tamanho do jogador com textura, carros melhores.
  **Limitação conhecida**: os pedestres ficam parados em pose T (braços esticados) — o
  modelo é rigged e tem animações (`idle`/`run`/`jump`) mas não implementei o
  `AnimationPlayer` ainda (fica no roadmap). Builds regenerados — dessa vez já testando
  o `.app` exportado de verdade antes de dar como pronto (lição da rodada anterior) — e
  tudo commitado/enviado pro GitHub.
- **2026-08-02** — Usuário pediu pra resolver a pose T dos pedestres. `idle.fbx` e
  `run.fbx` são arquivos separados do modelo, mas compartilham o mesmo esqueleto
  (`Root/Skeleton3D`) — extraí o `Animation` de cada um (`_extract_animation()`,
  instancia a cena da animação, pega o `Animation` do `AnimationPlayer` dela via
  `AnimationLibrary`, e descarta a cena) e montei um `AnimationLibrary`/
  `AnimationPlayer` na hora em `Pedestrian.gd:_setup_animation()`, tocando "run"
  enquanto anda e parando durante o ragdoll (volta a tocar ao recuperar). Os `Animation`
  extraídos ficam em cache estático (`static var`) — só extrai uma vez, todo pedestre
  reaproveita. Confirmado visualmente: pedestres correndo de verdade, sem pose T.
- **2026-08-02** — Usuário perguntou "cadê as ruas?" — a decoração de rua até então só
  cobria a rota diagonal principal; o resto da cidade era só prédios soltos no chão sem
  nenhuma rua de verdade. Cheguei a pesquisar se existia uma cidade 3D pronta pra baixar
  (o usuário sugeriu), mas não achei nada de graça que fosse "baixar e encaixar" —
  todas as opções (Kenney, KayKit etc.) são kits modulares iguais ao que já tínhamos, só
  trocando as peças. Em vez disso, criei `scripts/CityStreets.gd`: gera uma malha
  viária em grade (tipo Manhattan) por código a partir de duas listas de posições de
  rua (`streets_x`/`streets_z`), preenchendo cruzamentos (`road-crossroad.glb`) e
  trechos retos (`road-straight.glb`) entre eles, com um raio de exclusão
  (`exclude_points`/`exclude_radius`) pra não desenhar rua em cima da oficina, do
  ferro-velho e do comprador. Instanciado em `Town.tscn` com ruas em X/Z =
  {-50,-25,0,25,50}, cobrindo o mapa inteiro e conectando os 12 prédios em quarteirões
  de verdade. Confirmado visualmente de cima (bird's eye, câmera de teste temporária) e
  no nível do jogador — rua com faixa de pedestre, prédios dos dois lados, tudo
  conectado. A decoração diagonal antiga (potholes/mud zones) continua por cima, sem
  conflito.
- **2026-08-02** — Usuário pediu pra continuar aprimorando. Fechei as pontas soltas das
  ruas (antes cortavam abrupto no meio do nada) com `road-end-round.glb`
  (`CityStreets.gd:_build_run()` agora trata a primeira e a última posição de cada
  trecho como ponta, não reta comum; a rotação de 180° de uma ponta pra outra acertou
  de primeira, confirmado visualmente de cima). Reduzi `extent` de 65 pra 18 (as pontas
  ficam a uma distância razoável da última rua em vez de sumirem longe do mapa
  jogável). Também adicionei postes de luz automáticos (`light-square.glb`) a cada 3
  tiles retos, alternando os dois lados da rua — pequenos demais pra aparecer na vista
  de cima, mas confirmados no nível do jogador (poste ao lado da faixa de pedestre).
- **2026-08-02** — Usuário pediu pra anotar um lembrete de rodar `/clear` entre sessões
  longas (ver "Notas de fluxo de trabalho" no topo do arquivo).
- **2026-08-02** — Usuário pediu pra continuar ("vai fazendo tudo sempre verificando
  bugs e talz"). Item de "polimento restante" da malha viária: meio-fio/calçada
  elevada. Descoberto que o `city-kit-roads` do Kenney usado aqui é um kit de rodovia
  (confirmado olhando o `Sample.png` do pacote — sinalização de rodovia, sem nenhuma
  calçada/pedestre à vista), não tem peça de calçada real; a peça `road-side.glb` que
  parecia promissora pelo nome é acostamento de rodovia, não calçada. Em vez de forçar
  um asset errado, `CityStreets.gd:_place_curb_pair()` gera por código uma caixa rasa
  elevada (0.18m, com colisão própria via `StaticBody3D`) dos dois lados de cada trecho
  reto/ponta da malha (mesmo padrão de "gerar em código" já usado no resto do projeto).
  Fica de fora dos cruzamentos (mesma lógica de exclusão de `_near_any` já usada pros
  tiles) e some perto dos pontos excluídos (oficina/ferro-velho/comprador), então não
  interfere com nada que já existia ali. Verificado que as rotas de pedestres
  (`PedestrianRouteWorkshop`/`PedestrianRouteBuyer`) e o clearance das rotas de tráfego
  não cruzam essas novas guias, sem conflito. Testado carregamento headless (zero
  erros) e depois confirmado visualmente de verdade: abri o Godot em janela real
  (não headless, cena de debug temporária só pra câmera aérea, apagada depois) e usei
  `screencapture` do macOS pra printar a tela de verdade — dá pra ver as faixas da
  calçada elevada projetando sombra própria ao lado das ruas, confirmando que é
  geometria de verdade (não só cor). **Nota**: nesse processo um `find /` que eu tinha
  rodado antes (procurando o executável do Godot) disparou um popup do macOS pedindo
  acesso do app "claude" à pasta Desktop — não cliquei em nada (não tenho ferramenta
  pra mexer em diálogo real do sistema, e não é algo que a IA deveria decidir sozinha);
  fica pra você decidir Allow/Don't Allow da próxima vez que aparecer.
- **2026-08-02** — Usuário pediu pra continuar (segundo item do mesmo tópico de
  roadmap): curvas diagonais fora da grade ortogonal. `CityStreets.gd` ganhou
  `_build_diagonal()`/`diagonal_starts`/`diagonal_ends` (arrays paralelos de
  início/fim), reaproveitando as mesmas peças retas/ponta/luz/meio-fio já usadas na
  grade — só calcula o ângulo de rotação a partir da direção do segmento
  (`atan2(-dir.z, dir.x)`) em vez de usar 0°/90° fixos. Extraído `_side_offset()` como
  helper comum (antes só existia dentro de `_place_curb_pair`) pra também poder
  deslocar os postes de luz perpendicular a uma direção arbitrária, não só nos eixos
  X/Z. Adicionado um trecho de teste em `Town.tscn` (29,-21) → (46,-4), dentro de um
  quarteirão vazio da grade (entre as ruas em x=25/50 e z=-25/0) escolhido de propósito
  pra não cruzar nenhuma rua ortogonal — não existe peça de cruzamento
  diagonal-com-ortogonal no kit, então por enquanto essa feature só serve pra trechos
  que cabem inteiros dentro de um quarteirão, sem cruzar outras ruas (ver Roadmap).
  Testado headless (zero erros) e confirmado visualmente com câmera de debug aérea
  temporária + `screencapture`: a rua diagonal aparece certinha, com as duas pontas
  arredondadas, sem sobrepor a malha ortogonal.
- **2026-08-02** — Usuário pediu pra continuar (terceiro item do mesmo tópico):
  calçada não contornava os cruzamentos. Adicionado `_place_intersection_curbs()` em
  `CityStreets.gd`, chamado junto de cada `crossroad_scene` — preenche os 4 cantos do
  cruzamento com um bloco de calçada (mesmo material/altura do meio-fio das retas),
  fechando o "anel" que ficava em aberto perto do centro da grade. Extraído
  `_spawn_curb_box()` como helper comum (antes a criação de `StaticBody3D` +
  `MeshInstance3D` + `CollisionShape3D` só existia dentro de `_place_curb_pair`,
  agora reaproveitada pelos dois). Verificado por contagem de nós rodando headless
  (print temporário, removido depois) que os 22 cruzamentos válidos da grade 5×5
  geram os 4 cantos cada (os 3 que faltam são os excluídos perto da
  oficina/ferro-velho/comprador, como esperado). Confirmado visualmente com câmera
  aérea + `screencapture` num cruzamento sem sombra de prédio por perto: os cantos
  aparecem conectando suavemente com as guias das retas, sem buraco visível.
- **2026-08-02** — Usuário pediu pra continuar; mudei de tópico (malha viária já
  estava fechada) pro item "sem menu principal/pause" do Roadmap. Criado
  `scenes/ui/MainMenu.tscn`/`.gd` (tela inicial — título, subtítulo, Jogar/Sair) e
  `scenes/ui/PauseMenu.tscn`/`.gd` (Esc abre/fecha de qualquer lugar da partida,
  `get_tree().paused = true` + solta o mouse; botões Continuar/Sair para o
  Menu/Sair do Jogo). `project.godot:run/main_scene` agora aponta pro `MainMenu`
  em vez do `Main.tscn` direto. O toggle de mouse antigo em `Player.gd` (Esc
  soltava/recapturava sem pausar nada) foi removido — o `PauseMenu` agora é o
  único dono do Esc e já cuida do mouse ao pausar/continuar. Testado headless nas
  três cenas (`MainMenu.tscn`, `Main.tscn` e a cena padrão do projeto), zero erros.
  Confirmado visualmente com janela real que o `MainMenu` renderiza certo (título,
  botões). **Não consegui confirmar visualmente o fluxo completo** (clicar Jogar →
  jogo → Esc → pause → Continuar): a tela do Mac apagou (deu tempo/protetor de
  tela) bem no meio do teste, e depois disso `screencapture` só voltou preto —
  não tentei "acordar" a tela mexendo no seu teclado/mouse de verdade sozinho, já
  que isso não é algo que a IA deveria decidir por conta própria. Vale você
  conferir esse fluxo (Jogar, Esc, Continuar, Sair para o Menu) na próxima vez que
  abrir o jogo.
- **2026-08-02** — Ícone do jogo: desenhado por código com PIL (sem asset externo),
  um carrinho low-poly com uma fita adesiva amarela na diagonal (tema gambiarra).
  Gerado `icon_1024.png` (config/icon do Godot), `icon.ico` (Windows) e `icon.icns`
  (macOS), ligados nos dois `export_presets`.
- **2026-08-02** — Usuário achou o visual "muito feio" e pediu pra baixar um "mundo
  aberto pronto" e também NPCs diferentes. Pesquisei bastante (WebSearch): **não
  existe** um mundo aberto completo gratuito pra simplesmente baixar e encaixar —
  toda opção CC0 free (Kenney, Quaternius, KayKit) vem em kits modulares. Escolhemos
  (pergunta ao usuário, respondeu "opção 2 se não der certo a 1" pra cidade e
  "personagens de verdade diferentes" pros NPCs): baixar o **Downtown City MegaKit**
  (Quaternius, CC0) pra cidade e **Universal Base Characters + Universal Animation
  Library 2** (Quaternius, CC0) pros NPCs. Baixados via itch.io (o fluxo de download
  deles é via JS — descobri por engenharia reversa das chamadas de rede do próprio
  itch.io, replicadas com `curl`+cookie jar, já que as ferramentas de browser
  automatizado disponíveis nesta sessão não conseguiram completar o clique real; o
  download em si é 100% gratuito/CC0, sem burlar paywall nenhum).
  - **Prédios**: o pacote é majoritariamente peças modulares soltas (tijolos,
    cornijas, janelas — ~150 peças, pensadas pra montar fachada na mão, um trabalho
    de "level design" de verdade). Só 3 prédios vêm prontos na versão gratuita.
    Troquei `Building1`/`Building7` em `Town.tscn` pelos 2 que renderizaram sem bug
    visual (`Building_Large_2`, `Building_Small_1`) — fachada de tijolo/vidro bem
    mais detalhada que o Kenney, reaproveitando o `CityBuilding.tscn`/
    `AutoCollisionBody.gd` existente (só troquei `visual_scene`/`visual_scale`, zero
    mudança de código). O terceiro prédio pronto (`Building_Medium_2_001`) tem um
    artefato visual (faixa vermelha estranha no topo/base da fachada, provável bug
    de material na exportação do pacote pra Godot) — não foi usado, fica pra
    investigar depois. Só os arquivos realmente usados (~96MB de ~440MB baixados)
    foram mantidos no repo, em `assets/quaternius/`.
  - **NPCs**: baixados os 2 personagens-base (`Superhero_Male/Female_FullBody`,
    texturizados, CC0) e a biblioteca de animação (`UAL2_Standard.glb`, 130+
    animações). **Ainda não integrados** — a documentação oficial do Quaternius
    (`Godot_Setup.png` dentro do pacote de animação) mostra que o processo exige o
    sistema de retargeting humanóide do Godot 4 (BoneMap + SkeletonProfileHumanoid),
    um fluxo de editor com vários passos manuais (não é só trocar o modelo/FBX como
    fizemos com o Kenney, cujo mesh+animação já compartilhavam o mesmo esqueleto
    nativamente). Fica pendente uma decisão: tentar automatizar esse retargeting,
    fazer na mão no editor seguindo o guia oficial, ou manter os pedestres com o
    personagem Kenney atual por enquanto.
- **2026-08-02** — Usuário pediu pra exportar as builds e publicar no GitHub pra
  poder baixar e rodar no Windows também. Exportado Windows (.exe, ~177MB) e macOS
  (.zip, ~127MB) via `godot --headless --export-release`, testado o macOS de
  verdade (abri o `.app` exportado, não só modo dev — confirma que carrega e mostra
  o menu principal certinho). Publicados como GitHub Release
  ([v0.1.0](https://github.com/vitudanas/joguinho2/releases/tag/v0.1.0)) em vez de
  commitar os binários direto no repo (`builds/` continua fora do git, evita inchar
  o histórico com arquivos grandes/regeneráveis).
- **2026-08-02** — Usuário pediu explicitamente pra sempre verificar tudo antes de
  considerar pronto (ruas sem buraco, rota de carros/NPCs, "pense em tudo que pode
  ocorrer numa gameplay"). Escrevi um script de verificação temporário (compara a
  caixa de colisão real de cada `Building*` — a mesma gerada por
  `AutoCollisionBody.gd` — contra as linhas da malha viária e contra os retângulos
  de `TrafficRoute`/`PedestrianRoute` definidos em `Town.tscn`) e achei dois tipos
  de bug: (1) os 4 prédios do Quaternius adicionados nesta sessão (ver changelog
  anterior) tinham colisão muito maior que os prédios do Kenney que substituíram
  (~20x16m contra ~8-10m) — nas posições originais isso fazia um prédio (Large_2)
  ficar literalmente em cima de um cruzamento (confirmado num screenshot real, o
  telhado cobrindo a faixa de pedestre) e outro sobrepor o prédio vizinho; movidos
  todos os 4 pra fora da extensão da malha viária (além de x/z=±68), com folga de
  sobra. (2) Dois prédios **antigos** do Kenney (`Building4`, `Building6`, já
  existiam antes desta sessão) encostavam bem perto do canto de
  `TrafficRouteWorkshop`/`TrafficRouteJunkyard` — um carro de IA fazendo a curva
  naquele canto arriscava clipar pra dentro do prédio; reposicionados com folga.
  Reverificado (script + headless + screenshot real) até zerar toda sobreposição
  predio-rua, prédio-prédio e prédio-rota. O script de verificação foi só um
  arquivo temporário em `debug_tmp/` (apagado depois, não faz parte do jogo) —
  se for útil de novo no futuro, vale recriar algo parecido antes de mexer na
  posição de prédios/rotas.
- **2026-08-02** — Usuário pediu pra integrar os personagens Quaternius nos NPCs
  ("pode fazer"). Descoberta boa: `Superhero_Male/Female_FullBody` e
  `UAL2_Standard.glb` compartilham o mesmo esqueleto (65 ossos, nomes idênticos)
  — não precisa do retargeting via BoneMap/SkeletonProfileHumanoid que o
  `Godot_Setup.png` do pacote sugere (isso só seria necessário misturando
  personagem+animação de fontes diferentes); dá pra aplicar a animação direto,
  igual já fazíamos com o Kenney. Generalizei `Pedestrian.gd`
  (`idle_anim_scene`/`walk_anim_scene`/nomes configuráveis em vez de hard-coded
  pro Kenney) e `PedestrianRoute.gd` (`character_models` como lista) —
  100% compatível com o uso atual, headless sem regressão. **Mas não troquei os
  NPCs de verdade**: testei visualmente e a versão gratuita do
  `Superhero_Male/Female_FullBody` é só um corpo base **sem roupa nenhuma** (nem
  a textura "_Dark" é roupa, é só um tom de pele mais escuro com a mesma
  cueca/biquíni pintados) — não tem peça de roupa nenhuma na versão free do
  pacote. Colocar isso como pedestre normal andando pela cidade ficaria com
  gente de cueca/biquíni na rua, o que não parece uma escolha de design
  intencional (é diferente do humor de "gambiarra" do carro). Revertido o
  `Town.tscn` de volta pro personagem Kenney (clothed) nos pedestres; o código
  generalizado continua no repo, pronto pra usar assim que tiver um jeito de
  vestir esses personagens (outro pacote de roupa, ou eles vestidos à mão).
- **2026-08-02** — Usuário pediu pra buscar um pacote de roupa (opção 1 da pergunta
  anterior). Baixado `Modular Character Outfits - Fantasy` (Quaternius, CC0) —
  compatível de propósito com o `Universal Base Characters` (mesmo esqueleto de 65
  ossos, confirmado). Só as roupas "Peasant" (camisa/colete simples, calça, botas —
  as mais neutras/menos fantasy da versão gratuita) foram mantidas no repo em
  `assets/quaternius/outfits-fantasy/`. `Pedestrian.gd:_attach_outfit()` transplanta
  as malhas de roupa pro `Skeleton3D` do personagem base sem precisar de retarget —
  testado e a animação da UAL2 continua funcionando normal com a roupa por cima.
  **Achado real que impede de usar em produção ainda**: apareceu um artefato de
  clipping visual (pedaços de pele nua aparecendo por cima da roupa no torso e na
  coxa — provável diferença sutil de bind pose entre os dois arquivos `.gltf`
  exportados separadamente por fontes distintas) e o personagem fica careca (a
  malha de cabelo é um anexo à parte que não baixamos ainda). Não liguei isso no
  `Town.tscn` — fica pendente mais investigação (ou aceitar o clipping) antes de
  usar de verdade nos pedestres.
- **2026-08-02** — Usuário pediu pra continuar tentando (opção 1: cabelo + corrigir
  clipping). Baixado o cabelo (`Hair_SimpleParted`/`Hair_Long`, "Rigged to Head
  Bone", mesmo esqueleto) e generalizada `_attach_external_meshes()` em
  `Pedestrian.gd` pra aceitar `hair_scene` com a mesma técnica do `outfit_scene` —
  cabelo prende certinho, sem clipping (é uma malha pequena e independente, não
  tem o problema do corpo). Pro clipping da roupa, testei sistematicamente vários
  valores de encolhimento do corpo nu por baixo da roupa
  (`BODY_SHRINK_UNDER_CLOTHES`): **nenhum valor único resolve 100%** — a 0.7 o
  clipping some mas a cabeça encolhe visivelmente e sobra um pé descalço; a 0.85
  conserta torso/perna mas abre uma folga entre pescoço e gola da camisa; a 0.93
  o pescoço encaixa mas o meio do torso volta a vazar pele. Fixei em 0.9 (o
  meio-termo menos ruim, mas ainda com um resíduo pequeno de clipping no
  torso/coxa — ver screenshot que mandei pro usuário). Isso indica uma diferença
  real de *bind pose* entre os dois `.gltf` (personagem base x roupa),
  exportados separadamente — resolver de verdade exigiria reexportar/realinhar
  no Blender, fora do alcance de scripting em Godot. `Town.tscn` continua com o
  personagem do Kenney nos pedestres; fica pra decidir se o resultado atual
  (com o resíduo de clipping) já é bom o suficiente pra usar, ou se vale
  investir em Blender/outra fonte de assets.
- **2026-08-02** — Usuário pediu pra refazer o mapa inteiro da cidade "deixando tudo
  harmonioso". Antes de mexer, levantei o que estava de fato desarmônico em
  `Town.tscn`: (1) os 14 prédios ficavam em coordenadas arbitrárias sem relação
  nenhuma com a grade de ruas (alguns, tipo `Building1` em `x=-85`, caíam bem fora da
  área coberta pelas ruas) e com rotações aleatórias (30°, 250°, 330° etc.) — nenhum
  alinhamento com os quarteirões; (2) o estilo visual misturava Kenney
  (`city-kit-commercial`, low-poly simples) com Quaternius (`downtown-city-megakit`,
  fachada de tijolo/vidro mais detalhada — os dois lados a lado destoavam); (3)
  sobrava `RoadTile1-3`/`RoadCrossroad1`/`StreetLight1-3`, uma rua diagonal manual
  montada à mão *antes* de `CityStreets.gd` existir, desconectada da grade
  procedural nova; (4) `CityStreets` tinha um trecho diagonal de teste
  (`diagonal_starts`/`diagonal_ends`) que não levava a lugar nenhum, órfão dentro de
  um quarteirão vazio; (5) as rotas de tráfego/pedestre e os buracos/poças de lama
  também não tinham relação com as ruas de verdade da grade.
  - **Prédios**: padronizei os 16 prédios em cima de um único pacote
    (`city-kit-commercial` do Kenney, 16 variantes sem repetir nenhuma) — decisão de
    propósito pra eliminar o choque de estilo com o Quaternius (os 4 prédios
    Quaternius saíram do layout ativo; os assets continuam no repo, só não são mais
    instanciados em `Town.tscn`). Medi a AABB real de cada modelo candidato (script
    headless temporário em `debug_tmp/`, apagado depois) pra calibrar escala por
    prédio e calcular a margem livre até o meio-fio. Reposicionei os 16 prédios
    exatamente no centro dos 16 quarteirões da grade 5×5 de `CityStreets`
    (quarteirões de 25×25, centros em ±12.5/±37.5), com rotação sempre múltipla de
    90° em vez de graus arbitrários, e um gradiente de altura: skyscrapers nos 4
    quarteirões centrais (perto da oficina), prédios médios no anel seguinte,
    `low-detail-building-*` (as variantes que o próprio Kenney já pensa pra silhueta
    de fundo) nos 4 cantos mais distantes — dá uma leitura de "centro/downtown"
    natural sem precisar inventar zoneamento.
  - **Rede viária legada**: removi `RoadTile1-3`, `RoadCrossroad1` e `StreetLight1-3`
    (o crossroad manual que ficava bem em cima da praça da oficina) e o
    `diagonal_starts`/`diagonal_ends` de teste em `CityStreets` — a praça da oficina
    fica sem tile de rua (só chão), igual já acontecia com o ferro-velho e o
    comprador (mesma lógica de `exclude_radius`), então os 3 marcos passaram a se
    comportar de forma consistente entre si.
  - **Rotas/buracos/lama/eventos**: as duas `TrafficRoute` e as duas `PedestrianRoute`
    tiveram os pontos ajustados pra não cruzar os prédios novos (achei e corrigi via
    script, ver abaixo, um caso real: o laço de tráfego do ferro-velho cortava o
    canto do novo `Building1`). Os 4 pares de buraco+poça de lama saíram da diagonal
    removida e foram pro cima de ruas de verdade da grade (coordenada X ou Z igual à
    da rua, garantindo por construção que a poça — raio 2.3 — cabe dentro da pista
    pavimentada — meia-largura 2.4 — sem cortar o meio-fio). Os 4
    `EventSpawnPoint*` saíram de perto do meio dos quarteirões (onde cairiam dentro
    dos prédios novos) pra cruzamentos reais da grade, sempre livres por construção.
  - **Verificação**: escrevi um script headless (`debug_tmp/verify_town.gd`, também
    apagado depois) que instancia o `Town.tscn` de verdade, lê a `CollisionShape3D`
    real que `AutoCollisionBody` gera pra cada prédio (não uma estimativa manual) e
    confere sobreposição predio×prédio, prédio×landmark, prédio×rota e
    spawn×prédio. Rodei, achei o conflito do `Building1` citado acima, corrigi a
    rota e rodei de novo até "nenhum problema encontrado". Também rodei o projeto
    headless inteiro (`Main.tscn`) antes e depois, zero erros/warnings nos dois
    casos. Por fim confirmei visualmente com o jogo de verdade em janela real (não
    headless) — uma cena de debug temporária só com uma câmera aérea sobre o
    `Town.tscn`, apagada depois — e `screencapture` do macOS em três ângulos: vista
    de cima (grade inteira, os 16 quarteirões visivelmente organizados), vista
    oblíqua sobre a praça da oficina (4 skyscrapers, pedestres, sinalização, meio-fio
    e postes todos coerentes) e vista no nível do jogador numa rua (prédios na
    escala certa, sem T-pose, sem clipping). `debug_tmp/` inteiro removido no final.
- **2026-08-02** — Usuário pediu um anel rural ao redor da cidade, no espaço vazio
  que sobrava do chão de 300×300 (a cidade só ocupa uma área de ~136×136 no centro):
  fazendas "bonitinhas", alguns ferros-velhos e montanhas, autorizando aumentar o
  mapa se precisasse.
  - **Assets**: Kenney não tem kit 3D de fazenda (só packs 2D/pixel-art — pesquisado
    via WebSearch/WebFetch). Achado no site pessoal do Quaternius (mesmo criador já
    usado no projeto) dois pacotes CC0 novos, dessa vez hospedados no agregador
    [poly.pizza](https://poly.pizza) em vez do itch.io: **Farm Buildings Bundle**
    (10 modelos: celeiros, silo, moinho, galinheiro, cerca) e **Stylized Nature
    MegaKit** (68 modelos: árvores, arbustos, grama, flores, rochas — usei um
    subconjunto de 22). Descoberta boa: diferente do itch.io (que exigiu replicar
    chamadas JS com curl+cookie jar nas sessões anteriores), o poly.pizza serve os
    GLBs direto num CDN estático (`static.poly.pizza/<uuid>.glb`, o mesmo uuid da
    imagem de preview) — inspecionando o JSON embutido no HTML da página deu pra
    baixar tudo com `curl` puro, sem navegador automatizado. Assets ficam em
    `assets/quaternius/farm-buildings/` e `assets/quaternius/nature-megakit/`
    (~50MB, textura PNG embutida no GLB que o importer do Godot extrai sozinho).
    Medido a AABB de cada modelo em escala 1.0 (script headless temporário) antes de
    espalhar — ao contrário dos prédios do Kenney (minúsculos, precisavam de escala
    5-7x), esses já vêm em escala real de metros, só precisou de jitter pequeno
    (0.8-1.6x) pra variedade.
  - **Por que só Quaternius no anel rural (não misturei com o Nature Kit do
    Kenney)**: a cidade já é 100% Kenney de propósito (ver changelog anterior); pra
    não reintroduzir o mesmo problema de "dois estilos visuais lado a lado" que foi
    corrigido ali, o anel rural inteiro (fazenda + natureza + montanha) usa só
    Quaternius — os dois biomas (downtown Kenney x campo Quaternius) ficam cada um
    internamente consistente, e como estão espacialmente separados (cidade no
    centro, campo em volta) a transição entre estilos não fica lado a lado feito
    antes, é gradual conforme o jogador se afasta.
  - **Geometria**: chão (`GroundMesh`/`GroundShape`) aumentado de 300×300 pra
    600×600. Zona de exclusão da cidade calculada por distância Chebyshev
    (`max(abs(x), abs(z))`) em vez de euclidiana, porque a malha viária é um
    quadrado (ruas + `extent` do `CityStreets.gd` alcançam ±68 nos dois eixos) — com
    Chebyshev, um raio de exclusão de 78 dá a mesma folga em qualquer direção,
    inclusive na diagonal (com distância euclidiana teria sido preciso ~96 pra
    cobrir a diagonal, desperdiçando muito espaço rural nos eixos retos).
  - **Fazendas** (`scenes/world/FarmCluster.gd`, novo componente reutilizável tipo
    `CityBuilding.tscn`): gera por código, a partir de parâmetros exportados, um
    prédio principal (silo/celeiro/moinho) com colisão automática (reaproveita
    `CityBuilding.tscn`/`AutoCollisionBody.gd`), cerca retangular ao redor (encadeia
    peças de `fence-a`/`fence-b` ao longo do perímetro, mesma técnica de
    `CityStreets.gd:_fence_side`/`_build_run`), plantação em fileiras do lado de
    fora da cerca (grade de `Plant`/`Tall Grass`) e árvores/arbustos espalhados num
    anel ao redor. 5 instâncias (`Farm1`-`Farm5`) com combinações diferentes de
    prédio/cerca/plantação/árvores, espalhadas à mão (não em grade — o campo não
    precisa do alinhamento rígido da cidade) em pontos com pelo menos ~45 unidades
    de distância entre si.
  - **Ferros-velhos rurais** (`scenes/world/ScrapyardCluster.gd`): decorativos, não
    interativos (o único ferro-velho jogável continua sendo `Junkyard.tscn` — não
    quis criar um segundo sistema de "carro para reboque" sem pedido explícito).
    Destroços são caixas simples geradas em código (mesmo formato/proporção do
    `Body` de `Vehicle.tscn`, cores enferrujadas, tombadas em ângulos aleatórios),
    mais caixotes e árvores mortas/arbustos ao redor pra clima "abandonado". 3
    instâncias (`Scrapyard1`-`Scrapyard3`).
  - **Natureza ambiente e montanhas** (`scripts/RuralScatter.gd`, novo componente
    genérico, instanciado duas vezes): espalha props numa faixa em anel ao redor da
    cidade, com `RandomNumberGenerator` próprio (não usa `randf`/`seed` globais, pra
    não interferir na aleatoriedade de outros sistemas como tráfego/pedestres) e
    semente fixa (sempre gera o mesmo resultado). `NatureScatter` cobre toda a faixa
    de raio 78-225 com árvores/rochas médias (colisão automática) e grama/flor/
    cogumelo/seixo (só visual, sem colisão). `MountainRange` reusa o mesmo script
    numa faixa mais externa (raio 190-230), só com rochas médias em escala bem maior
    (9x-18x) — na escala aumentada, essas mesmas rochas viram formações que lêem
    como montanha de verdade (confirmado visualmente, ver abaixo). As duas instâncias
    recebem os 8 pontos de fazenda/ferro-velho como `exclude_points` (raio 30) pra
    não nascer rocha/árvore em cima de um cluster já posicionado à mão.
  - **Verificação**: mesmo rigor das rodadas anteriores. Script headless
    (`debug_tmp/verify_rural.gd`, apagado depois) que instancia o `Town.tscn` de
    verdade e usa `global_position` (não cálculo manual acumulando transforms —
    tentei isso primeiro e é fácil errar em nós aninhados) pra conferir, em 1103 nós
    gerados: nenhum cai dentro da zona quadrada da cidade, nenhum cai fora do chão
    novo, nenhum se sobrepõe a um prédio real da cidade (AABB real via
    `CollisionShape3D` gerada, mesma técnica da rodada anterior), as rochas de
    montanha ficam dentro da faixa esperada, e os 8 clusters não ficam perto demais
    uns dos outros — resultado "nenhum problema encontrado". Achei e corrigi no
    caminho dois bugs de tipagem estrita do GDScript (`max()`/`or` sem anotação de
    tipo explícita geram "Variant" e o projeto trata warning como erro) tanto no
    `FarmCluster.gd` quanto no script de verificação. Rodei o projeto headless
    inteiro antes/depois, zero erros. Confirmei visualmente em janela real com
    `screencapture`: vista aérea do mapa inteiro (anel de montanhas visivelmente
    cercando tudo, cidade pequena e centralizada, fazendas/mato bem distribuídos —
    usuário pediu explicitamente "bem preenchido" no meio da sessão, então subi a
    densidade da natureza ambiente ~50% e as árvores de cada fazenda antes desse
    print), close numa fazenda (silo+galinheiro+cerca+plantação em fileiras+árvores,
    tudo coerente), vista no nível do chão das montanhas (ficaram bem imponentes,
    maiores que o prédio mais alto da cidade de propósito) e uma vista de transição
    bem na borda da cidade (a rua termina e já tem árvore/rocha/montanha ao fundo,
    sem corte feio). `debug_tmp/` removido no final.
- **2026-08-02** — Usuário reportou que os botões "Jogar" e "Sair" do menu
  principal não funcionavam. Como não dá pra clicar de verdade numa janela nativa
  nesta sessão automatizada (sem permissão de Acessibilidade pro `osascript`
  controlar outros apps), diagnostiquei escrevendo um script headless temporário
  que instancia `MainMenu.tscn` de verdade e inspeciona o estado direto (em vez de
  tentar simular clique do SO): achei que `menu.get_script()` vinha `null` mesmo a
  cena carregando sem erro nenhum. Causa raiz: `MainMenu.tscn` declarava o
  `ext_resource` do script (`MainMenu.gd`) mas **nunca atribuía ele ao nó raiz**
  (faltava a linha `script = ExtResource("1")` no bloco `[node name="MainMenu"
  type="Control"]` — comparei com `PauseMenu.tscn`, que tem essa linha certinha, pra
  confirmar que era só esse arquivo). Sem o script attached, `_ready()` nunca
  rodava, os botões nunca conectavam o sinal `pressed`, e por isso pareciam
  travados — o bug bate exatamente com o que a sessão que criou esse menu já tinha
  avisado no changelog anterior ("não consegui confirmar visualmente o fluxo
  completo... vale você conferir"). Corrigido adicionando a linha que faltava.
  Validei com o mesmo script de diagnóstico: confirmei `has_method("_on_play")`,
  a conexão real do sinal `pressed → _on_play`, e por fim emiti o sinal `pressed`
  direto (`play_button.emit_signal("pressed")`, testa o handler de verdade sem
  depender de simular clique) — a cena trocou de fato pra `Main.tscn` sem erro.
  Rodei um script à parte varrendo todos os `.tscn` do projeto procurando esse
  mesmo padrão de bug (`ext_resource` de Script declarado mas nunca atribuído a
  nenhum nó) — `MainMenu.tscn` era o único caso. `debug_tmp/` removido no final.
- **2026-08-03** — Usuário deu um feedback franco: cidade vazia e sem vida, NPCs
  gigantes, carros feios, visual cartunizado demais. Medi tudo contra a cápsula de
  1.80m do `Player` antes de opinar, e os números confirmaram cada ponto:
  - **NPCs gigantes**: `characterMedium.fbx` tem **3.76m** de altura — 2.1× o
    jogador. O changelog de 2026-08-02 dizia "escala 1:1 já bateu certinho", o que
    estava **errado** (nunca foi medido na época). Corrigido com `visual_scale`
    calculado (1.8/3.76 = 0.479) e verificado medindo a AABB na cena de verdade.
  - **Carros**: o Kenney Car Kit tem 2.55m de comprimento e proporção 1.7:1
    (brinquedo). Trocados pelo **Cars Bundle do Quaternius** (poly.pizza, CC0), que
    já vem em escala real: 4.22m × 1.81m, proporção 2.34:1 — não precisou de
    ajuste de escala nenhum.
  - **Cidade vazia**: cada quarteirão tinha **1 prédio solto no meio** (~11% de
    ocupação). Novo `scripts/CityBlocks.gd` enfileira prédios encostados na
    calçada virados pra rua (mesma técnica de "andar ao longo de um trecho" de
    `CityStreets.gd`), medindo a largura real de cada modelo pra saber quanto
    avançar. Grade expandida de 4×4 pra **6×6 quarteirões** (ruas a cada 25 de
    -75 a 75). Resultado: **175 prédios, 62% de ocupação**.
  - **Variedade**: baixados mais dois kits CC0 do Kenney, da mesma família visual
    do comercial que já existia — `city-kit-suburban` (21 casas) e
    `city-kit-industrial` (20 galpões). Zoneamento por distância do centro
    (Chebyshev): arranha-céus no miolo, comércio no anel do meio, casas e galpões
    na periferia.
  - **Escala nativa do kit**: descoberta que destravou a densidade — o tile de rua
    mede 1.0 no kit e `CityStreets` usa `tile_size = 6.0`, então **6.0 é o módulo
    nativo**. Padronizar todos os prédios nessa escala faz tudo encaixar na mesma
    grade (antes as escalas variavam de 5 a 7 sem critério).
  - **Vida nas ruas**: de 2 pra 6 rotas de tráfego e de 2 pra 6 de pedestres, de
    11 pra **50 agentes**. As duas rotas antigas **nunca estiveram sobre ruas de
    verdade** (usavam x=29/z=29, que caem no meio do quarteirão) — passavam
    despercebidas enquanto os quarteirões eram vazios, mas com a cidade densa
    começaram a cortar prédios. Todas realinhadas sobre eixos de rua reais
    (tráfego) e calçadas (pedestres, a 3.0 do eixo, entre o meio-fio em 2.4 e a
    fachada em 3.8).
  - **"Menos cartoon"**: o aspecto de desenho vinha muito mais da **iluminação**
    que dos modelos. Trocado: luz ambiente 0.9 → 0.62 com contribuição parcial do
    céu (antes 100% céu, o que deixava toda sombra azul-berrante), tonemap ACES,
    SSAO/SSIL fortes (dão volume às formas chapadas do low-poly), névoa de
    perspectiva aérea, sombras direcionais suaves em 4 cascatas e dessaturação
    leve, no lugar do ambiente chapado + glow forte. Duas iterações erradas no
    caminho, corrigidas olhando o resultado: a névoa de altura
    (`fog_height_density`) lavou a cena inteira de branco, e depois a luz ambiente
    100% do céu deixou as sombras azul-escuras demais.
  - **Cores das construções**: todos os prédios do kit dividem um único atlas de
    textura, então a cidade inteira saía da mesma cor. `CityBlocks._tint()` aplica
    um `albedo_color` sorteado por prédio (multiplica a textura, então mantém o
    desenho de janelas/portas), com uma paleta de tons de fachada bem claros de
    propósito — cores saturadas devolveriam o aspecto de desenho.
  - **Oficina virou ferro-velho rural** (pedido do usuário): nova
    `scenes/world/RuralWorkshop.tscn` (galpão do kit industrial + pátio de
    concreto + cerca + sucata via `ScrapyardCluster` + tanque), em (-150, 0), no
    fim da rua que sai da cidade pro oeste — dá pra sair dela e entrar direto na
    cidade dirigindo. O ferro-velho de achar carcaça foi junto, 38m ao norte
    (reboque curto; a viagem longa virou o test-drive até a cidade). Os 3
    ferros-velhos rurais decorativos continuam só como cenário, por escolha do
    usuário. `PlayerSpawn` movido pro pátio da oficina.
  - **Entregas em casas aleatórias** (pedido do usuário): o comprador fixo saiu de
    `Town.tscn`. `CityBlocks` registra cada casa no grupo `"delivery_house"`
    guardando no próprio nó o ponto da calçada em frente (`front_position`) e pra
    que lado a fachada olha (`front_facing`); o novo autoload
    `autoload/DeliveryManager.gd` sorteia uma casa (nunca a mesma duas vezes
    seguidas), instancia o `BuyerNPC` lá e, ao fechar a venda, agenda a próxima.
    Verificado numericamente que a `CarZone` do NPC cai **na pista** (0.80m do
    eixo da rua) — ou seja, dá pra encostar o carro de verdade.
  - **Carros e NPCs andavam de ré**: medido (não chutado) que o `PathFollow3D`
    aponta o **-Z** do nó no sentido do movimento, e renderizado cada modelo
    isolado com a câmera no +Z pra confirmar que **todos olham pro +Z**. Daí os
    180° em `TrafficCar.visual_rotation_y_degrees` e no novo
    `Pedestrian.visual_rotation_y_degrees`.
  - **NPCs realistas** (pedido do usuário): pedestres passaram do boneco do Kenney
    pros `Superhero_Male/Female_FullBody` do Quaternius (1.82m, escala ~1.0) com
    roupa Peasant e cabelo. Dois bugs reais resolvidos no caminho: (1) o cabelo
    ficava **flutuando solto acima da cabeça** — ao transplantar uma malha skinada
    pra outro `Skeleton3D` era preciso **reatribuir o `skin`** depois de trocar o
    `skeleton`, senão a malha fica parada na pose de descanso; (2) o corpo era
    encolhido a 0.9 pra caber na roupa, mas o corpo do Quaternius é uma malha
    única que **inclui a cabeça**, então a cabeça saía visivelmente menor —
    trocado por corpo 0.97 + roupa inflada 1.05, que é imperceptível na cabeça.
  - **Animação de caminhada**: a UAL2 gratuita **não tem caminhada normal** (só
    `Walk_Carry`, de braços carregando algo, e `Zombie_Walk_Fwd`) — era isso que
    o usuário achou feio. Baixada a **UAL1 Standard** (Quaternius, CC0, via
    itch.io), que tem `Walk` e `Idle` normais, e **verificado antes de usar** que
    o esqueleto é idêntico (65 ossos, mesmos nomes) — aplicação direta, sem
    retargeting.
  - **Roupa resolvida com Blender por script** (`tools/build_characters.py`): a
    peça Peasant é um **colete aberto no peito**, e por baixo estava o corpo do
    super-herói, então aparecia torso nu. Testei encolher/inflar em vários
    valores (1.035, 1.07, 0.97+1.05) e o vão era idêntico em todos — ou seja,
    não era escala, era o desenho da peça. Costurar a abertura também não era
    confiável: a malha tem **50 bordas soltas**, várias duplicadas. A saída foi
    **pintar de cor de tecido** o torso e as pernas do corpo base (regiões
    escolhidas por coordenada: `|x| < 0.23` exclui os braços, que em T-pose vão
    até `|x| = 0.93`), então a pele que escapa pela roupa lê como roupa de baixo
    em vez de pele. Detalhe que custou uma iteração: o glTF guarda
    `baseColorFactor` em espaço **linear**, então a primeira cor (0.44) saiu
    quase branca na tela — os valores finais já estão convertidos.
    O script roda o Blender headless, junta corpo+roupa+cabelo num arquivo só
    (`assets/quaternius/characters-dressed/*.glb`) e reduz as texturas de 4K pra
    1024 — sem isso cada personagem embutia ~50MB. Como os personagens passaram
    a vir prontos, a montagem em runtime saiu do código: `CharacterVisual.gd`
    encolheu de ~90 pra ~30 linhas e sumiram os remendos de escala.
  - **Build 40% menor**: com os personagens combinados, 4 pastas de origem
    (`universal-base-characters`, `outfits-fantasy`,
    `universal-animation-library-2`, `downtown-city-megakit`, ~145MB) deixaram de
    ser carregadas pelo jogo — continuam no repo (o script do Blender precisa
    delas) mas entraram no `exclude_filter`. macOS foi de 194MB pra **116MB**,
    Windows de 245MB pra **166MB**. Dada a lição de 2026-08-02 (um
    `exclude_filter` amplo demais cortou uma textura e quebrou o jogo inteiro),
    conferi o `.pck` exportado item a item: todos os assets que a cidade usa
    estão dentro, e os 4 excluídos, fora.
  - **Verificação**: dois scripts headless temporários que instanciam o
    `Town.tscn` de verdade — um confere densidade, prédio×rua, prédio×prédio e
    rota×prédio; o outro confere o loop (distância de reboque, casas de entrega,
    NPC na calçada com a zona do carro na pista). Ambos terminaram em "nenhum
    problema encontrado" (175 prédios, 62%, 50 agentes, 63 casas de entrega).
    Dois bugs meus foram pegos por esses scripts e corrigidos: prédios se
    sobrepondo porque eu posicionava assumindo malha centrada na origem (vários
    modelos do kit têm a malha deslocada — passei a descontar o offset), e uma
    perna de rota que eu tinha posto em z=22 pra desviar do comprador, mas 22 não
    é rua e cortava a quadra. Confirmado visualmente em janela real com
    `screencapture` a cada etapa. `debug_tmp/` removido no final.

- **2026-08-03** — Usuário perguntou se dava pra modificar os NPCs fisicamente e
  pediu as duas frentes: variedade (altura/cor) **e** tipos físicos de verdade,
  com o pedido explícito de aumentar busto e glúteo **do personagem feminino**.
  - **Por que shape key e não vários personagens**: a alternativa óbvia era
    gerar N variantes de GLB no Blender, mas cada personagem pronto pesa 10-13MB
    (textura embutida), então 6 tipos somariam ~60MB num build de 116MB. Gravar
    os tipos como **morph target** custou **+1.3MB e +1.5MB** nos dois arquivos
    que já existiam, não toca no esqueleto (a animação continua valendo) e ainda
    deixa o peso de cada forma ser sorteado **por NPC** — a variedade deixa de
    ser "um de 6" e passa a ser contínua.
  - **Como as formas são feitas** (`tools/build_characters.py`): duas operações
    geométricas aplicadas ao corpo **e à roupa juntos** (deformar só o corpo faz
    a barriga/seio atravessar o tecido). `Thicken` afasta os vértices de uma
    linha central (tronco, braços, pernas — mais grosso ou mais fino) e `Bulge`
    infla uma região a partir de um ponto dentro do corpo. As coordenadas saíram
    de **medir as seções transversais** dos dois modelos no Blender, não de
    chute: peito feminino em z 1.25-1.35 com a frente em y -0.115..-0.140,
    glúteo em z 0.85-1.00 com as costas em +0.162.
  - **Erro real corrigido no meio do caminho**: a primeira versão do busto usava
    um empurrão **direcional** (só pra frente) com pico no centro da região —
    o usuário viu o resultado e apontou que tinha virado um cone esticado, e
    estava certo: empurrar mais no meio que nas bordas, num eixo só, é
    literalmente a construção de uma ponta. Trocado pelo `Bulge`, que cresce nos
    três eixos ao mesmo tempo e dá volume redondo; de quebra o deslocamento caiu
    de 7.9cm pra 3.5cm no busto e de 6.8cm pra 3.7cm no glúteo, e mesmo assim
    lê melhor. **Lição**: pra volume arredondado, inflar radialmente de um ponto
    interno; empurrar numa direção só serve pra coisa achatada (barriga).
  - **Só o modelo feminino** tem `Bust`/`Butt`/`Hips`, como pedido. Os dois
    gêneros compartilham `Belly`/`Bulk`/`Skinny` (e o masculino tem `Chest`),
    que são porte físico, não busto.
  - **Runtime** (`CharacterVisual.gd`): `randomize_appearance()` sorteia um tipo
    físico da tabela `BUILDS`, soma as formas femininas quando o modelo as tem
    (forma que o modelo não tem é ignorada, então a mesma tabela serve pros dois)
    e tinge pele/roupa/cabelo. As cores são **multiplicadores sobre a textura**,
    não cores chapadas, pra não apagar o desenho do material. Detalhe que teria
    virado bug: material vindo de `.glb` é **compartilhado entre todas as
    instâncias** da cena, então pintar direto pintaria a cidade inteira junto —
    cada superfície recebe uma cópia como `surface_override_material`. Altura
    sorteada por pedestre em `PedestrianRoute` (±7%, de ~1.65m a ~1.94m) e o
    cliente da entrega passou a variar igual aos pedestres.
  - **Verificação**: script headless instanciando o `Town.tscn` de verdade
    confirmou 26 pedestres, todos com material próprio (não compartilhado), 6
    tons de pele distintos, alturas de 1.66m a 1.94m e pesos de forma variados.
    Depois renderizei do próprio Godot (câmera de debug salvando PNG, sem
    depender de `screencapture`) as duas fileiras de tipos físicos de frente e
    de perfil, e por fim pedestres **andando na cidade de verdade**, pra
    confirmar que a deformação não briga com o esqueleto animado. Um erro meu
    de diagnóstico no caminho: as primeiras fotos da cidade saíram todas iguais
    e do lugar errado porque o `Town.tscn` já tem câmera própria — sem
    `make_current()` a foto sai pelo ponto de vista dela, não pelo da câmera de
    debug. `debug_tmp/` removido no final. **Builds não foram reexportados**
    nesta rodada.

- **2026-08-03** — Segunda rodada nos NPCs, a partir do que o usuário viu na
  primeira: pele atravessando a roupa (braço e costas, nos dois modelos),
  busto podia crescer mais, e o glúteo tinha ficado desproporcional pra coxa.
  - **Pele atravessando a roupa — eram três causas diferentes**, e só a
    terceira explicava o retalho do ombro que não saía de jeito nenhum:
    1. *Corpo pra fora do tecido* (costas, coxa): resolvido medindo, pra cada
       vértice do corpo, se há tecido logo acima dele (raio ao longo da
       normal) e afundando o que estiver rente ou já do lado de fora. Medir a
       distância até a roupa **mais próxima** não serve — o antebraço nu passa
       a centímetros da manga e entraria na conta como coberto.
    2. *Penetração entre vértices*: a face do corpo é reta e o tecido em volta
       é curvo, então a face cruza o pano mesmo com os vértices por dentro.
       Resolvido com folga maior (1.8cm), espalhada pelos vizinhos com perda a
       cada anel — sem isso a pele exposta ao lado do tecido ganhava degrau.
    3. **A roupa traz uma pele própria embutida**: `Male_Peasant_Arms` não é
       só tecido, tem uma malha de BRAÇO junto (material `MI_Regular_Male`),
       pensada pra usar sem personagem embaixo. Como aqui existe o corpo
       completo, eram dois braços quase no mesmo lugar, e o da roupa furava a
       manga dela mesma. **Nenhum ajuste no corpo resolvia**, porque o pedaço
       que vazava nem era do corpo. Achado pintando a malha do corpo de
       magenta e renderizando: o retalho não ficou magenta. Removidas 3930
       faces de pele duplicada — e o arquivo do masculino caiu de 13,3MB pra
       10,2MB, porque a textura de pele extra saiu junto.
    **Lição de diagnóstico**: quando um defeito visual não muda NADA depois de
    várias correções, parar de ajustar e primeiro provar de qual malha ele é
    (esconder/pintar de cor chapada e renderizar). Perdi três rodadas mexendo
    na malha errada.
  - **Busto e glúteo**: busto subiu (3,5cm no peso máximo), e o glúteo passou
    a vir com a coxa junto — só o glúteo crescendo, em cima de uma perna fina,
    lia como deformidade. O trecho da coxa começa acima do joelho, posição
    medida (a perna é mais estreita em z 0.45-0.55 e engrossa até o quadril).
  - **20 combinações** (pedido do usuário): busto e glúteo passaram a sair de
    degraus fixos sorteados de forma **independente** — 5 níveis de busto × 4
    de glúteo = 20 pares, incluindo as duas pontas (os dois pequenos e os dois
    grandes). Antes eu sorteava os dois juntos com piso alto e todas saíam
    parecidas; o que dá variedade é o contraste entre as partes, não o valor
    de cada uma. O quadril acompanha o glúteo em vez de ser sorteado à parte.
    Um jitter em cima do degrau evita que duas do mesmo par fiquem idênticas.
  - **Verificação**: folha de contato das 20 combinações renderizada do próprio
    Godot em vista 3/4, frente/perfil/costas dos dois modelos em close no
    tronco (é onde vazava), e pedestres andando na cidade de verdade. Também
    conferido de dentro do `.pck` exportado que a pele duplicada não está mais
    lá e que as formas chegaram no build.

- **2026-08-03** — Usuário pediu a cidade maior, mais harmoniosa, com
  estabelecimentos variados (mercado, posto de gasolina, ponto de ônibus,
  semáforo, "tudo que tem numa cidade") e **sem erro de ligação nas ruas**;
  no fim da rodada, também um degradê de construções menores entre a cidade
  e o campo.
  - **O erro de ligação era real e antigo**: as ruas ficam a cada **25** e a
    peça de asfalto media **6** — e 25 não é múltiplo de 6. Além disso as
    peças eram posicionadas a partir do *começo do trecho* (`min_v + tile/2`),
    não alinhadas à grade. Resultado: um vão de ~3 unidades em **cada
    aproximação de esquina**, na cidade inteira. Corrigido nos dois pontos:
    `tile_size` passou a 6.25 (25 = 4 × 6.25) e as peças agora são ancoradas
    em múltiplos do tile a partir do primeiro cruzamento. Verificado por
    script que percorre cada rua e exige distância **exata** de um tile entre
    peças vizinhas: 621 peças, nenhum vão e nenhuma sobreposição.
  - **Ponta arredondada virou buraco**: a peça de acabamento era escolhida por
    "primeiro/último índice do trecho", o que colocava tampa **dentro** da
    grade quando o trecho começava num cruzamento. Agora só o rabicho que sai
    da grade recebe tampa.
  - **Buraco no centro da cidade**: `exclude_points = (0,0,0)` com raio 9
    continuava nas ruas e nos quarteirões — sobra da época em que a oficina
    ficava no centro (ela foi pro campo em (-150,0) na rodada anterior).
    Removido.
  - **Cidade maior**: grade de 6×6 para **8×8 quarteirões** (ruas de -100 a
    100), 82 agentes de trânsito/pedestres (era 50) com rotas novas no anel
    externo, e 108 casas de entrega.
  - **Mobiliário que o kit não tem** (`scripts/StreetFurniture.gd`): semáforo,
    ponto de ônibus, banco e bomba de combustível montados com primitivas —
    de propósito, em vez de baixar outro pacote: a cidade é 100% Kenney por
    decisão de projeto, e misturar estilos foi o problema corrigido em
    2026-08-02. Faixa de pedestre usa `road-crossing` do próprio kit, só nas
    aproximações dos cruzamentos.
  - **Lotes com função** (`CityBlocks.gd`): praça (grama, caminho em cruz,
    árvores, bancos), posto de gasolina (cobertura branca com faixa vermelha,
    bombas, totem e loja), estacionamento (vagas demarcadas e carros parados)
    e feira (barracas com guarda-sol). É o que tira a cara de "grade infinita
    de prédio".
  - **Degradê cidade→campo** (`scripts/CityOutskirts.gd`): anel quadrado entre
    104 e 130 onde tamanho e densidade caem indo pra fora. Medido: altura
    média 5.4 perto da cidade contra 3.9 perto do campo, densidade 3.5 contra
    2.7 por 100u de anel.
  - **Bugs meus que a verificação pegou** (e que valem de lição):
    1. *Identificar nó por nome não funciona*: irmãos de nome repetido viram
       `@Node3D@N`, então o verificador "achou" só 2 semáforos de 50. Passei a
       identificar por `scene_file_path` e por grupo.
    2. *Medir na rotação errada*: os guarda-sóis eram medidos com rotação 0 e
       plantados com rotação sorteada — e a caixa de colisão é o AABB **depois**
       de girar, então 21 pares se atravessavam. Barracas passaram a ficar
       alinhadas; árvores usam a diagonal como passo.
    3. *Passo chutado*: a vaga do estacionamento usava 2.6 fixo em vez da
       largura medida do carro.
    4. *Validar pelo centro*: o cinturão aceitava a construção pelo centro,
       então casas largas no limite avançavam por cima da última rua. Agora a
       faixa vale pra construção inteira.
    5. *Ordem do sorteio invertendo o degradê*: sortear a posição e depois
       descartar o que não coubesse descartava justamente as construções
       grandes do lado de dentro. Passou a sortear primeiro o "quanto pro
       campo", e daí sair tamanho, densidade e profundidade.

- **2026-08-03** — Usuário achou o visual ainda cartunesco e perguntou se
  trocar o kit Kenney por um mais realista resolveria. **Medi antes de
  opinar**: as texturas do kit são imagens de **64×64 em paleta**, uma por
  modelo — cor chapada, sem grão, sem normal map, sem roughness. Ou seja, o
  aspecto de desenho está no pacote, não na iluminação (que já tinha sido
  ajustada em 2026-08-03).
  - **Materiais PBR sobre a geometria existente** (`shaders/city_surface.gdshader`
    + `scripts/CitySurface.gd`): texturas CC0 do ambientCG (concreto, reboco,
    tijolo, asfalto, telha, 1K) aplicadas em **triplanar** — que dispensa UV
    decente, e é o caso aqui: o UV do kit aponta pro atlas de cor. O atlas
    **continua no albedo**, senão janela e porta somem (elas são desenhadas na
    textura, não modeladas); o PBR entra só como grão, normal e roughness.
    Custo: 10MB de textura, contra os ~60MB que um pacote novo de modelos
    custaria.
  - **Dois erros meus no caminho**, achados olhando o A/B renderizado:
    1. *Multiplicar a cor pela textura escurece*: tijolo tem luminância média
       baixa, e a cidade inteira ficou quase preta. O grão passou a **modular
       em torno de 1.0** (acima do cinza médio clareia, abaixo escurece).
    2. *Sortear material sem olhar o tipo*: saiu arranha-céu de tijolo. Agora
       torre e galpão são concreto, casa é tijolo ou reboco.
  - **Telhado verde-limão**: é o elemento mais cartunesco da cidade e vive
    DENTRO do atlas, então não dá pra trocar só a cor dele por fora. O shader
    detecta verde puro e puxa pra cinza-esverdeado.
  - **Cuidado ao comparar A/B**: sortear o material consome o RNG, então ligar
    a chave mudava o layout inteiro da cidade e a comparação deixava de ser da
    mesma cidade. O sorteio passou a acontecer nos dois modos.
  - **Céu HDRI** (`assets/polyhaven/sky_partly_cloudy_2k.hdr`, CC0, 5MB): o
    `ProceduralSkyMaterial` virou `PanoramaSkyMaterial` e a contribuição do céu
    no ambiente subiu de 0.45 pra 0.85. Maior ganho por byte de toda a rodada —
    céu, sombra e reflexo passam a vir de uma foto de céu real.
  - **Entulho de cobertura** (`StreetFurniture.water_tank/ac_unit/antenna`):
    ~105 props sorteados nos telhados planos (casa do kit tem telhado
    inclinado e o prop ficaria flutuando). É o que quebra a silhueta de caixa
    que fazia a cidade ler como maquete de longe.
  - **Árvores de verdade nas praças**: trocados os cones chapados do Kenney
    pelos modelos do `nature-megakit` do Quaternius, que já estavam no repo
    (têm casca texturizada e normal map). Escala própria (0.85), porque eles
    vêm em metros e o kit de prédio usa módulo 6.0.
  - **Mais dois bugs meus, os dois de verificação preguiçosa**:
    1. *Passo de árvore pela diagonal*: copa é redonda, o AABB quase não cresce
       ao girar, mas eu media pela diagonal — com a árvore maior o passo
       estourava meio quarteirão, `cols` virava ZERO e a praça saía **sem
       árvore nenhuma**. Só apareceu porque fui contar (0 instanciadas), não
       porque olhei a foto.
    2. *`replace` sem conferir*: um script meu trocou `rng_seed = 20260803` em
       **dois** nós e vazou o bloco de propriedades do `CityBlocks` pra dentro
       do `NatureScatter`; e um segundo replace não casou (indentação
       diferente) mas o script imprimiu "corrigido" assim mesmo. Lição:
       `replace` em `.tscn` tem que contar as ocorrências e falhar alto.
  - **Pesquisa sobre trocar o kit** (a pergunta original): **não existe** kit
    de prédios modular, realista, CC0 e em glTF. O que existe de CC0 é
    material/textura (ambientCG, Poly Haven) e **props avulsos** — inclusive
    os que faltam pra quebrar a silhueta de caixa (caixa d'água, ar
    condicionado, lixeira). Conclusão registrada: o que ainda lê como desenho
    na vista de longe é **geometria** (caixa sem janela rebaixada, sem beiral,
    sem entulho de telhado) e as árvores em cone chapado — não a superfície.

- **2026-08-03** — Usuário apontou que as construções têm "visual
  arredondado" e pediu para conferir de perto: **borda de janela, telhado e
  porta** parecendo chanfradas.
  - **Medido antes de mexer** (Blender, `building-a.glb` do kit comercial):
    **530 das 1252 faces vêm marcadas como SUAVES**, e a normal de vértice
    desvia da normal da face em até 45° (p90). Ou seja: a quina **existe na
    geometria**, o que arredonda é o sombreamento passando por cima dela.
  - **Conserto sem tocar na malha**: `shaders/city_surface.gdshader` ganhou
    `flat_shading`, que recalcula a normal por derivada de tela
    (`cross(dFdx(VERTEX), dFdy(VERTEX))`) e devolve a faceta. O triplanar
    passou a usar a mesma normal de face, senão a mistura das três projeções
    borra justamente na quina.
  - **Atenção pra quem continuar**: o shader só cobre o que passa por
    `CitySurface.apply()` — fachadas, asfalto e meio-fio. Carro, personagem,
    árvore, mobiliário urbano e os props de telhado continuam com material
    próprio e sombreado suave; se sobrar canto redondo, é aí.

- **2026-08-03** — Usuário pediu pra fechar as três pendências abertas acima
  ("continue tudo aí e deixa 100% esses gráficos"). As três foram feitas.
  - **Escala das construções (pendência 3)**: medi antes de mexer — prédio
    comercial do kit com 1.293 de altura local dava **7.76m** em escala 6.0,
    ou 2,6m por andar num modelo com 3 fileiras de janela. A grade inteira
    subiu 25%: `tile_size` 6.25 → **7.5**, espaçamento de rua 25 → **37.5**
    (5 tiles, continua múltiplo exato — que era a trava documentada),
    `building_scale` 6.0 → **7.5**, pista 4.8m → 6.0m e calçada 1.2 → 1.5.
    Resultado medido: altura média 7.4m → **10.5m**, mais alto 17.3m →
    **33.6m**, ocupação 23% → **30%**. A grade foi de 8×8 quarteirões de 25
    para **6×6 de 37.5** (área da cidade 200×200 → 225×225) e o miolo de cada
    quarteirão passou de 17.4m para 28.3m, o que era necessário: no
    `depth_budget` antigo (8.4m) quase nenhum prédio na escala nova caberia.
    Remapeados 18 rotas, 4 buracos, 4 poças, 4 pontos de evento, oficina,
    ferro-velho, spawn do jogador, cinturão e anel rural.
  - **Bug antigo achado no caminho: a faixa de pedestre NUNCA nascia.** O
    censo acusou 0 tiles de `road-crossing` na cidade inteira. Causa: o
    limiar era `tile_size * 0.95`, mas as peças são ancoradas na grade, então
    a vizinha do cruzamento fica a **exatamente** um tile — a condição nunca
    era verdadeira. Com `1.05` são 196 faixas.
  - **Montanhas (pendência 2)**: `scripts/MountainRange.gd` + 
    `shaders/mountain.gdshader` geram 38 maciços como campo de altura próprio
    (perfil que vai a ZERO na borda, então o pé encosta no chão sem degrau;
    cume deslocado do centro; ruído de cordilheira + uma oitava fina de
    sulcos). A cor sai da **forma**, não de textura: rocha na encosta íngreme,
    mato embaixo, neve no alto — é o que faz ler como montanha e não como
    pedra grande. As rochas escaladas 9x-18x saíram.
  - **Chão do mundo**: era **uma cor chapada**, e de longe a cidade lia como
    maquete em cima de uma mesa cinza — o tell mais forte que sobrava. Agora
    `shaders/ground.gdshader` faz grama/terra por fbm em três escalas, com
    micro-relevo na normal. Ruído em vez de foto de propósito: uma textura 1K
    repetindo em 600m vira listra, e o ruído não repete (e não custa byte no
    build). A placa foi de 600×600 pra **1800×1800**, senão a borda quadrada
    aparecia contra o céu.
  - **Canto arredondado (pendência 1)**: medi quanto a normal de vértice
    desvia da normal de face em cada kit. Kits de **prédio** do Kenney:
    41-45% das faces suavizadas (é daí que vem o aspecto de sabonete). Kit de
    **ruas**: 2.3%. Fazenda do Quaternius: **0%**. Árvore: 96% e carro: 4.4%
    — os dois devem continuar suaves. Ou seja, só faltava cobrir os prédios
    do Kenney que não passavam pelo `CitySurface`: o **cinturão de transição**
    (77 construções, ainda em cor chapada), a **loja do posto** e a
    **oficina**. `AutoCollisionBody` ganhou um `surface_kind` opt-in pra isso.
  - **Erros meus, todos pegos olhando o render ou o verificador**:
    1. *Normal de face pelo sinal errado*: `cross(dFdx, dFdy)` devolve a
       normal com o sinal dependendo da orientação do triângulo na tela.
       Sem realinhar pelo hemisfério da normal interpolada
       (`face * sign(dot(face, NORMAL))`), metade das fachadas ficou virada
       pro lado oposto da luz e **a cidade inteira renderizou PRETA**. O que
       denunciou foi que só o que passa pelo CitySurface estava escuro — bomba
       de gasolina e caixa d'água, que têm material próprio, estavam certas.
    2. *Ordem dos vértices do maciço invertida*: mesma armadilha de sinal, mas
       na geometria. A montanha ficava **invisível vista de cima** (o
       `cull_back` comia a face virada pra câmera) e de longe só aparecia uma
       lasca fina. Trocar `[0,2,1,0,3,2]` por `[0,1,2,0,2,3]` resolveu.
    3. *Pé da montanha calculado pelo raio nominal*: a base é elíptica e o
       cume é deslocado, então a base real chega a **1.8× o raio**. Posicionar
       pelo raio deixou a encosta 90m mais pra dentro do planejado, engolindo
       ferro-velho e 128 props de natureza. Passou a descontar o `span` real.
    4. *Script de patch que só gravava no fim*: uma contagem errada no meio do
       lote abortava e **descartava em silêncio** todas as trocas já impressas
       como "ok" — foi assim que as fazendas ficaram na posição velha com a
       lista de exclusão já na nova. O helper passou a gravar a cada passo.
    5. *Verificador dando "nenhum problema" com ZERO montanhas*: o script
       tinha erro de parse e a lista vazia passava calada. Contagem zero em
       qualquer gerador agora é falha dura.
    6. *Medição de normais com o sinal invertido*: acusou 100% de faces
       suavizadas em todos os kits, inclusive numa caixa. Só o ângulo importa,
       então `absf(dot)`.
  - **Verificação**: `debug_tmp/verify_city.gd` instancia o `Town.tscn` de
    verdade e lê os parâmetros dos próprios nós (então continua valendo depois
    de mexer na escala): censo, continuidade da malha viária (distância exata
    de um tile entre peças vizinhas), prédio×rua, prédio×prédio, rota×prédio,
    rota sobre pista/calçada, entrega (NPC na calçada e zona do carro na
    pista), spawn de evento, quarteirão vazio, buraco/poça sobre o asfalto,
    e o anel rural (pé da montanha × cinturão × clusters × natureza × borda do
    chão). Terminou em "nenhum problema encontrado". Builds reexportados e o
    `.app` exportado rodado de verdade; conferido item a item que as **183**
    referências `res://` do jogo estão no `.pck` e que as 4 pastas de origem
    continuam fora. macOS 127MB, Windows 179MB. `debug_tmp/` removido.

- **2026-08-03** — Usuário pediu carro de verdade pra fazer as gambiarras, um
  sistema de dirigir, e apontou que os **carros de NPC estavam flutuando**.
  - **Carros de IA flutuando — medido, não estimado**: os pontos das rotas
    estavam em `y=0.4`, herança do Car Kit do Kenney (origem no meio da
    carroceria). Os modelos do Quaternius têm a origem na **base** (base
    `y ≈ 0`, medido nos 7), então os 42 carros pairavam **0,4 m** no ar. Os
    pedestres tinham o problema inverso: rota em `y=0.1` com a calçada em
    0.18, ou seja o pé **enterrado 8 cm**.
  - **A rua estava 18 cm acima do chão físico.** Investigando o item acima,
    medi que o tile de asfalto é uma *laje*: com o nó em `y=0.03` e escala
    7.5, o topo ficava em 0.18 — mas a colisão do mundo é o `Ground`, que
    termina em `y=0`. Ou seja: **todo carro apoiava 18 cm abaixo da rua que
    aparecia na tela**. Com o carro de caixa não dava pra notar; com rodas de
    verdade seria gritante. `CityStreets` passou a baixar cada tile pelo
    próprio topo medido (`road_surface_y`), e a calçada em 0.18 virou um
    **degrau de verdade** — que é o que o projeto sempre quis ("o carro sobe
    nela e sacode a gambiarra") e nunca teve.
  - **Carro de verdade** (`scripts/CarRig.gd`): o `car-a.glb` do Quaternius
    substitui a caixa vermelha. O rig acha as rodas pelo nome (os 7 modelos do
    pacote usam o mesmo padrão, conferido um a um), cria um **pivô no centro
    medido de cada roda** e move a malha pra dentro dele — sem isso girar o nó
    giraria a roda em torno da origem do carro e ela sairia orbitando. As
    dianteiras esterçam, todas rolam junto com a velocidade.
  - **Nada de coordenada na mão**: o rig publica eixos, bitola, raio de roda e
    caixa da carroceria, e o `Vehicle` posiciona a partir daí a colisão, os 4
    raycasts de suspensão, os 4 pontos de gambiarra e a câmera. Trocar o
    modelo do carro por outro do pacote não exige reposicionar nada.
  - **A suspensão nunca sustentou o carro.** `suspension_strength` era 140, o
    que dá 14 N por 10 cm de compressão contra **17.100 N** de peso (950 kg
    com a gravidade 18 do projeto). Na prática o carro deslizava apoiado na
    caixa de colisão e o atrito da barriga era maior que a força do motor.
    Agora a rigidez sai da conta de equilíbrio (peso ÷ compressão desejada),
    então continua certa se a massa mudar.
  - **Erros meus, cada um pego por medição**:
    1. *Álgebra da suspensão*: usei a mesma altura como origem do raio E como
       comprimento livre da mola — a compressão dava **zero** parado e o carro
       não saía do lugar.
    2. *Amortecedor com o sinal trocado* (já estava assim antes): virava
       amortecedor **negativo**, bombeava energia a cada quique e o carro se
       atirava sozinho pro ar (a compressão ia de 0.04 pra 0.34 em 1 s).
    3. *`can_sleep`*: o Godot adormece o RigidBody quando a velocidade cai, e
       `apply_force` **não acorda** — o carro parava de responder ao
       acelerador depois de qualquer paradinha.
    4. *Medir depois de escalar*: `_local_aabb` já aplica a transformada do
       próprio nó, então medir o tile depois de escalar devolvia o topo já
       escalado; multiplicar de novo elevou o desconto ao quadrado e
       **enterrou a rua inteira 1,1 m** — a cidade ficou com rua de grama.
    5. *Alinhar pelo topo da caixa*: o kit é de **rodovia**, e o ponto mais
       alto do tile é o **acostamento levantado da borda** (medido: 24
       vértices em `y=0.020` contra 36 em `y=0.010`). Alinhar por ele enterrou
       a pista de novo. Agora alinha pelo plano horizontal com mais vértices.
    6. *Teste com o carro atravessado na rua*: o banco de provas punha o carro
       perpendicular à pista e ele batia no meio-fio a 4 m — a "velocidade
       final" saía 13 km/h.
  - **Banco de provas** (`tools/verify/drive_test.tscn`): como não dá pra
    apertar tecla numa sessão automatizada, o teste roda o `Vehicle` com o
    `_physics_process` **desligado** e injeta throttle/steer chamando o mesmo
    `_apply_suspension_and_drive` do jogo — testa o caminho real, não uma
    cópia. Resultado: repouso com 4 rodas no chão, **0-50 km/h em 2,2 s**,
    final **76 km/h**, 131° de curva em 3 s sem capotar, freada de 20,5 m/s em
    **10,8 m**, ré funcionando e o carro sucateado ainda rebocável a pé.
  - **Verificação persistida** (`tools/verify/`, fora do build): o verificador
    da cidade já tinha sido recriado do zero duas vezes porque morava no
    `debug_tmp/`, que é apagado antes de cada export. Agora mora no repo e
    ganhou checagem de **altura** (carro de IA no asfalto, pedestre na
    calçada) e do topo real do asfalto — as duas coisas que quebraram nesta
    rodada.

- **2026-08-04** — Usuário pediu pra continuar. Fechada a pendência número 1
  (o loop nunca tinha sido jogado) e dada variedade aos carros.
  - **Teste de loop de ponta a ponta** (`tools/verify/loop_test.tscn`): carrega
    o `Main.tscn` de verdade e percorre ferro-velho → reboque → oficina → 4
    gambiarras → dirigir → entrega → lábia → venda. O que faz isso valer:
    **`Input.parse_input_event()` alimenta o mesmo estado de teclado que
    `Input.is_key_pressed()` lê**, então o E de interagir e o F de sair do carro
    passam pelo código real do jogo. Sem isso só dá pra chamar método por fora,
    e o teste não provaria nada sobre input.
  - **Ele achou 8 bugs que travavam o jogo de verdade.** Nenhum era visível nas
    verificações geométricas anteriores:
    1. **Não dava pra montar gambiarra nenhuma.** O raycast de interação vê
       áreas, e a `DropZone` da oficina é uma área grande exatamente onde o
       carro estaciona — ela roubava a mira dos marcadores. Criada a **camada 3
       = gatilho** (DropZone, CarZone do comprador, buracos e poças), que o raio
       ignora e que continua detectando o veículo.
    2. **O carro montado não saía do lugar.** Peça de gambiarra instalada é um
       `RigidBody3D` cinemático grudado no carro, e corpo cinemático empurra quem
       encosta: as 4 peças brigavam com a carroceria (throttle 1.0, 4 rodas no
       chão, 1 cm em 2 s). Peça instalada agora não colide; a colisão volta
       quando ela se solta e vira destroço.
    3. **O reboque empurrava o carro por cima do jogador.** O alvo do `TowHook`
       ficava na FRENTE de quem puxa (apesar do arquivo sempre ter dito "atrás"),
       e com um carro de 4,22 m a carroceria alcançava a cápsula: o carro subia
       nela e, quando o jogador saía de baixo, o solver o ejetava a **375 m/s**.
       Agora puxa atrás, a uma distância derivada do tamanho real do carro.
    4. **A carcaça chegava de cabeça pra baixo** em 2 de 3 rodadas: era
       arremessada pelo degrau de 20 cm da laje da oficina. A laje virou rente ao
       chão (mesma decisão já tomada pro asfalto) e o pneu de carcaça rebocada
       passou a deslizar em vez de agarrar (`tow_grip`) — puxada de lado com pneu
       agarrando, ela capotava nos próprios pneus.
    5. **Marcadores de gambiarra inalcançáveis.** Postos na superfície do carro,
       ficavam DENTRO da caixa de colisão e o raio acertava a lataria antes. Hoje
       cada um tem a **sua face**: capô por cima, retrovisor à esquerda, radiador
       à direita, parachoque atrás — antes capô e radiador dividiam a dianteira e
       um tapava o outro, e o radiador embaixo do bico virou o ponto mais difícil
       do jogo.
    6. **Suspensão sem batente virava catapulta**: qualquer interpenetração
       gerava força enorme. Agora tem limite de curso e teto de força.
    7. **O carro capotava na curva** (o SUV deitava, up=0.03): o centro de massa
       era o centro da caixa de colisão, ou seja a meia-altura da carroceria.
       Baixado pra altura do eixo, que é onde a massa de um carro fica.
    8. **Carro parado nunca parava**: sobrava deriva de ~0,28 m/s pra sempre (o
       arrasto é proporcional à velocidade e perto de zero não segura nada).
       Adicionado atrito estático com teto de 0.6g.
  - **Variedade de carros**: modelo sorteado entre 6 do pacote e pintura sorteada
    entre 8 cores foscas de calhambeque. Só a superfície de MAIOR área de cada
    malha é pintada (vidro e farol são superfícies separadas), e cada uma recebe
    uma **cópia** do material — material vindo de `.glb` é compartilhado entre
    instâncias, então pintar direto pintaria todo carro do mapa junto. O
    `drive_test` monta os 6 modelos e confere eixos, rodas e alcance das
    gambiarras em cada um.
  - **Erros meus nesta rodada**: gastei muitas iterações caçando falhas que eram
    do ARNÊS, não do jogo — mover o jogador todo frame (o `RayCast3D` que o
    `Player` lê é o do passo anterior, então ele interagia com o que estava sob a
    mira um frame antes), pôr o jogador meio enterrado usando a altura do chão
    como origem da cápsula, e mirar de 2,6 m quando o `InteractRay` alcança 3,5 m
    e a câmera fica 2,2 m acima do alvo. Lição: quando o teste falha, primeiro
    provar de que lado está o defeito (jogo ou arnês) antes de ajustar qualquer
    número.

- **2026-08-04** — Usuário perguntou se o `.app` já estava atualizado. Estava: o
  `.zip` e o `.exe` foram exportados 09:10, depois da última alteração de código
  (09:06) e do commit `6e4f06f`. **Mas o `.app` que ele abre não estava.** Do lado
  do zip novo tinha um `Jegues Mecanicos 2.app` extraído em 03/08 15:09 — de
  ANTES do carro de verdade, da física de dirigir e dos 8 bugs do loop. Quem
  desse dois cliques nele estaria jogando o build velho, sem nenhum aviso de que
  era velho. **Lição de fluxo de trabalho**: exportar não é o fim — o `.zip` é o
  artefato, mas o que o usuário abre é o `.app` extraído, e ele NÃO se atualiza
  sozinho quando o zip é regravado. Extrair de novo (ou apagar o antigo) faz
  parte do "reexportar ao terminar". Conferido no build atual: as 128 referências
  `res://` do jogo estão no `.pck`, o binário exportado sobe limpo (`--headless
  --quit-after`) e o `.app` novo abre de verdade renderizando a cidade inteira
  (céu HDRI, montanhas, casas, faixa de pedestre, HUD e bússola).

- **2026-08-04** — Usuário jogou e disse que "a mecânica principal não funciona":
  não conseguia montar as gambiarras. **O `loop_test` passava 5/5 mesmo assim** —
  e essa é a lição da rodada: ele teleporta o jogador pro ângulo perfeito de cada
  marcador e mira no CENTRO exato da esfera. Isso prova a lógica e não prova
  **nada sobre jogar com o mouse**.
  - **A armadilha que travava o jogo: mirar na carroceria dava "Rebocar [E]".**
    A carroceria é o alvo óbvio (ocupa a tela inteira, ao lado de 4 bolinhas de
    32cm), então o jogador mira nela e aperta E — e em vez de montar a peça, o
    reboque **reengata** e o carro sai sendo arrastado pra longe dos marcadores.
    Estava documentado como "limitação conhecida — inofensivo, só reengancha o
    TowHook"; de inofensivo não tinha nada, era o que impedia de jogar. Agora a
    `DropZone` liga `Vehicle.at_workshop` e, com o carro na oficina, a carroceria
    mostra "Faltam N gambiarra(s) — mire nos pontos coloridos" e o E não faz
    nada. Sai do pátio (empurrado ou consertado), volta a ser rebocável.
  - **O que achou**: `tools/verify/attach_shot.gd`, que **fotografa pelo ponto de
    vista do jogador**. Nenhum teste numérico ia pegar isso — o raycast acertava
    os marcadores certinho, os 4 estavam alcançáveis, a tolerância de mira era
    boa. O defeito só existe na tela. **Vale como método**: quando o usuário diz
    que algo "não funciona" e a verificação passa, fotografar antes de mexer.
  - **Fumaça cobrindo o marcador do capô**: a coluna subia mais de 1m bem no eixo
    do marcador — e de frente é justamente de onde se mira nele. Descentralizar
    só trocou de vítima (passou a cobrir o radiador); o que resolveu foi o
    penacho virar **bafo baixo** na grade, morrendo abaixo da faixa dos
    marcadores (`lifetime` 1.3 → 0.75, gravidade 0.4 → 0.15).
  - **Marcadores boiando soltos**: a folga era 0.5m a partir da caixa de colisão,
    vinda de uma conta errada no comentário ("a esfera tem raio 0.3" — a visível
    tem 0.16 e o hitbox 0.45). Baixada pra 0.20: encostam na lataria e a mira não
    piora, porque quem decide a facilidade é o hitbox de 0.45, que continua
    saindo pra fora da caixa.
  - **Novo verificador** (`tools/verify/attach_test.gd`): varre um anel de
    posições em volta do carro e mede de quantas dá pra mirar em cada bolinha
    (hoje 71-100%), quantos graus de erro a mira aguenta (±14° na horizontal,
    ±10° na vertical) e — a trava de regressão que importa — que a carroceria
    **não oferece "Rebocar" dentro da oficina**.
  - **Dois erros meus, os dois de medir com o chão errado**: usei
    `get_drop_position()` (o CENTRO da Area3D, 1m acima do piso) como altura do
    chão, e jogador e carro saíram boiando na foto e na medição; e a "melhor
    posição" pra medir tolerância pegava o primeiro ângulo do anel que acertava,
    que é um ângulo raspante — reportou "±0°" num ponto que de frente aguenta
    ±14°. Os dois passaram a sair de raio pra baixo / da direção de frente.

- **2026-08-04** — Seguindo pra pendência nº 2 ("o pátio da oficina prende o
  carro"), que era o próximo passo do jogador depois de conseguir montar as
  gambiarras. Medida antes de opinar, com `tools/verify/yard_test.gd`: dirige de
  verdade (tecla W pelo caminho de input do jogo) a partir de vários ângulos de
  parada e mede quanto o carro se afasta.
  - **O pátio NÃO prende**: sai em 4 dos 8 ângulos, e os 4 que travam apontam
    todos pro fundo do terreno (barracão, tanque, sucata) enquanto os 4 livres
    formam um arco contínuo virado pra saída. Isso é layout normal — obstáculo
    atrás, saída na frente. A pendência era suspeita, não defeito.
  - **Mas o teste achou um bug de verdade, e grave: a cápsula do jogador
    continuava sólida enquanto ele dirigia.** `enter_vehicle()` só fazia
    `visible = false`, e `CharacterBody3D` é cinemático — pra um `RigidBody` ele
    é parede que não cede. Como o jogador para de andar ao dirigir, o corpo
    ficava plantado onde ele estava em pé (em geral do lado ou na frente do
    carro que acabou de entrar) e **segurava o carro**: medido `andou 0.0 m`,
    "barrado por Main/Player". Agora a colisão é desligada ao entrar e religada
    ao sair — o mesmo caso andou 7.8 m. É irmão do bug das peças de gambiarra
    cinemáticas de 2026-08-04.
  - **Estacionamento automático: tentado e REVERTIDO** (fica registrado pra
    ninguém repetir). A ideia era a oficina largar a carcaça virada pro vão da
    cerca, já que o ferro-velho fica ao norte e o carro sempre para apontado de
    volta pro barracão. Cada correção revelou outra interação: (1) girar em
    torno da origem **translada** a caixa de colisão, que é deslocada porque vem
    da medida do modelo, e o solver jogava o carro 5,6 m fora da vaga — longe o
    bastante pro loop não conseguir mais montar o parachoque; (2) teleportar pra
    vaga mantendo o Y antigo encravava o carro na laje de concreto; (3) o raio
    que media o chão da vaga batia **no próprio carro** (que já estava lá) e
    devolvia a altura do teto; (4) corrigido isso, passou a bater **na cabeça do
    jogador**, parado ali porque acabou de rebocar; (5) e no fim o carro caía em
    cima do jogador e assentava tombado 16°. **Lição**: teleportar corpo rígido
    pra cima de onde o jogador está é frágil por natureza, e aqui o ganho era só
    poupar uma ré. Dar ré é jogo. O `yard_test` passou a RELATAR o ângulo de
    chegada em vez de reprovar, e só falha se o carro andar menos de 3 m — que é
    a assinatura de algo prendendo, não de manobra.
  - **Erros meus de arnês nesta rodada**: rodei o teste com `| tail -60`, que
    segura a saída inteira até o fim (7 minutos achando que estava travado, e a
    causa real era um erro de parse — o projeto trata warning como erro); medi a
    tolerância de mira a partir do "primeiro ângulo do anel que acerta", que é um
    ângulo raspante; e deixei a varredura de 8 ângulos rodar ANTES do teste de
    reboque, o que sujava o estado da oficina e produzia um resultado (336°) sem
    explicação no jogo — esperar não lavou, rodar antes resolveu. Também tinha
    escrito o guard `_parking` sem liberar em todas as saídas, o que teria
    estacionado só o primeiro carro da partida.

- **2026-08-04** — Usuário pediu um tour visual do jogo. Fotografando cada etapa
  do loop pelo ponto de vista do jogador (`tools/verify/loop_shots.gd`) e o mundo
  inteiro (`tools/verify/world_tour.gd`), apareceu um defeito que nenhum teste
  numérico pegava: **o carro consertado não mostrava gambiarra nenhuma.** As
  peças existiam, estavam presas e o `installed_parts.size()` batia 4 — mas na
  tela eram cubos coloridos flutuando ao redor do carro, com folga visível, e
  nos lugares errados (a "mangueira do radiador" na porta, a "dobradiça do capô"
  pairando acima do teto). A premissa do jogo não chegava ao jogador.
  - **Causa**: o mesmo ponto servia pra duas coisas — **onde se mira** e **onde a
    peça fica**. Os pontos foram espalhados em faces separadas por causa da mira
    (um na frente do outro, o raio pega o errado, ver 2026-08-04), e a peça foi
    junto. Agora `Vehicle._place_part_anchors()` dá a cada peça um ponto próprio,
    no lugar que o nome dela diz e encostado na lataria; a mira continua onde é
    alcançável.
  - **`CarRig.surface_y_at()`**: a altura do capô passou a ser **medida nos
    vértices da malha**, não estimada como fração da caixa. A caixa é do carro
    inteiro, ou seja o topo dela é o TETO — estimando, a peça do capô ficava
    dentro da lataria, e o valor certo varia entre os 6 modelos.
  - **Erro meu**: assumi que a carroceria é centrada na origem e usei
    `-size.z*0.5` como "a frente". Não é: errava 15 cm e punha a mangueira atrás
    do bico. Passou a usar os limites reais (`position` e `position + size`).
  - **O verificador também estava errado** e vale a lição: ele julgava "peça
    dentro da lataria" pela caixa de colisão, então reprovava qualquer peça
    pousada no capô (que é bem mais baixo que o teto) e aprovava peça enterrada
    na traseira. Agora cruza dois sinais — abaixo da **pele medida** do modelo
    E dentro da caixa. Só altura não basta: peça pendurada no parachoque fica
    abaixo da linha do capô e mesmo assim aparece.
  - **Observações do tour** (nada disso foi corrigido): de cima o mundo é uma
    placa quadrada com borda reta contra o céu; a névoa lava as vistas amplas; o
    pátio da oficina é o cenário menos trabalhado do mapa (laje nua na grama,
    cerca só de um lado); e há uma emenda dura no sombreado do chão.

- **2026-08-04** — Usuário pediu pra transformar as gambiarras em "coisas reais
  para ficar graficamente bonito". Cada peça era UM bloco liso (cubo cinza,
  cilindro verde, cubo vermelho, cubo amarelo): mesmo já posicionadas certo, na
  tela liam como cubo colorido grudado no carro, e a piada do jogo — consertar
  com tranqueira do dia a dia — não chegava ao jogador.
  - **`scripts/GambiarraVisual.gd`** monta cada peça em código, com primitivas
    combinadas e material próprio — mesma escolha já feita pro mobiliário urbano
    (`StreetFurniture.gd`), pra não trazer pacote novo e não reintroduzir mistura
    de estilos: **dobradiça** com duas abas tortas, pino e quatro parafusos (aço
    + aba enferrujada); **mangueira** em 7 segmentos num arco, com anéis de
    corrugado e abraçadeira de metal nas pontas; **fita** em três tiras cruzadas
    em ângulos diferentes, ponta solta levantada e o rolo sobrando; **lona
    plástica** em cinco abas amassadas, translúcidas e de dupla face, presas por
    três tiras de fita.
  - As `CollisionShape3D` das 4 peças foram remedidas pro novo tamanho — elas
    valem quando a gambiarra se solta e vira destroço.
  - `cull_mode = CULL_DISABLED` no plástico: lona é fina, e sem isso o remendo
    fica com buraco quando o jogador olha do outro lado.

- **2026-08-04** — Usuário pediu escala proporcional à realidade em TODAS as
  construções e montanhas, chuva melhor, e caçar tudo que estivesse flutuando.
  - **`tools/verify/scale_test.gd`** (novo): censo de altura por família de
    construção e caça a objeto boiando — pra cada objeto, mede a base da caixa e
    joga um raio pra baixo até bater em algo sólido; a sobra é a flutuação.
  - **Escala já estava certa onde importa**: pedestre 1,79 m, carro 4,2 m,
    prédio mediano 7,7 m (~2,5 andares) e o mais alto 33,6 m (~11 andares).
    Quem estava fora era a **serra**: pico máximo de 138 m, só 3,7x o prédio
    mais alto — lia como morro atrás da cidade. Subiu pra **320 m (9,5x)**, com
    a base crescendo junto (raio 90-190), senão montanha alta e base estreita
    vira espeto. O chão foi de 1800 pra **2200** porque o pé da serra passou a
    alcançar 914 do centro, ou seja pra fora da placa antiga.
  - **15 props de telhado flutuavam, o pior a 14,3 m do chão.** Causa: o entulho
    de cobertura era plantado no `pos` do NÓ, mas várias malhas do kit são
    deslocadas da origem e quem planta o prédio já desconta esse offset — então
    a construção aparece em `pos + off` e o prop caía ao lado dela, sobre o
    vazio. Passou a usar o mesmo offset.
  - **Cobertura do posto e totem** ficam no ar de propósito (apoiados em pilar e
    mastro): entraram no grupo `"suspenso"`, que o verificador pula. Marcar na
    fonte em vez de afrouxar o limiar — afrouxar esconderia flutuação real.
  - **Chuva** (`scenes/world/RainFX.tscn`): tinha **material declarado e nunca
    atribuído** — mesma classe do bug do script solto no `MainMenu` (2026-08-02),
    então a gota caía com material padrão opaco. Além disso a gota era uma caixa
    de 3 cm × 50 cm (lia como confete). Agora: risco de 0,7 cm × 65 cm com o
    material na própria malha, ~9 m/s (velocidade terminal real de uma gota),
    inclinação por vento e não por espalhamento.
    - **Erro meu no caminho**: usei blend **aditivo**, e 1400 riscos somando luz
      contra o céu claro viraram uma cortina branca sólida — lia como cachoeira.
      Blend normal com alpha baixa resolve.
    - A pedido do usuário, a chuva passou a cobrir **124 m** (era 68) com 2200
      gotas e alpha 0,16: mais área e menos densidade, pra parecer que chove no
      mapa todo. Cai de 18 m (era 8) — de 8 m dava pra ver a chuva "começar"
      logo acima da cabeça e o truque de seguir o jogador ficava óbvio.
  - **Erro meu de verificador**: a primeira versão media **cada malha isolada**,
    então acusou 420 "flutuando" — a luminária no alto do poste, o cabelo do
    pedestre e o telhado do prédio, todos presos a algo acima do chão. Medindo
    por OBJETO INTEIRO caiu pra 15 reais. Lição: a unidade da pergunta "isso
    está no chão?" é o objeto, não a peça.

- **2026-08-04** — Usuário reportou, jogando: coisas flutuando **acima das
  construções**, grama e montanha sem detalhe nenhum, e construções rurais fora
  de escala.
  - **O flutuante era real e o verificador tinha ponto cego.** Os props de
    telhado pousavam no **topo da caixa** do modelo — que é o ponto mais alto do
    modelo INTEIRO (mastro, casa de máquinas, telhado recuado), não a laje. A
    caixa d'água ficava boiando sobre o prédio. Agora `CityBlocks._roof_world_y()`
    mede a laje **nos vértices da malha** naquele ponto. É o mesmo erro que já
    tinha posto a gambiarra do capô dentro da lataria: **caixa não é superfície**.
  - **Dois erros meus seguidos nessa correção**, os dois de conversão de espaço:
    1. A primeira versão convertia o ponto do mundo para o espaço do modelo com
       `Vector2.rotated`, e a convenção de sinal do rotated 2D não bate com a
       rotação em Y — amostrava o lugar errado e os props subiram até 27 m. A
       versão boa leva os vértices **pra frente** (modelo → mundo), que não tem
       essa armadilha.
    2. Com os props pousados na laje (abaixo do topo da caixa de colisão), o raio
       do verificador passou a **nascer dentro** da caixa do prédio — e o Godot
       ignora a forma em que o raio nasce dentro. 84 props apareceram como
       "boiando a 33 m" estando exatamente onde deviam. Resolvido com
       `hit_from_inside = true`. **Lição**: raio que nasce dentro de um corpo
       mente calado.
  - **Grama** (`shaders/ground.gdshader`): o menor detalhe era de ~1 m, então de
    perto — que é onde o jogador anda — o chão era um borrão liso. Entraram duas
    escalas finas (moita ~22 cm, fio ~5 cm), com variação de cor entre moitas e
    relevo próprio na normal, tudo sumindo entre 18 m e 70 m de distância porque
    ruído de 5 cm visto de longe vira cintilação.
  - **Montanha** (`shaders/mountain.gdshader`): ganhou **estratos** (bandas
    quase horizontais onduladas por ruído) — é o detalhe que mais rende numa
    encosta grande, porque aparece de longe — mais aspereza fina de perto. As
    alturas de mato e neve foram recalibradas pra serra de 320 m: com os valores
    antigos (mato até 42, neve a partir de 104) quase todo maciço virava pico
    nevado.
  - **Pátio da oficina** (`scripts/WorkshopYard.gd`): era uma laje nua na grama
    com cerca de um lado só, o cenário mais pobre do mapa e justo o que o jogador
    mais vê. Ganhou pilha de pneu, tambor de óleo, bancada, carrinho de
    ferramenta, cavalete, cone e luminária de trabalho, mais cerca no lado oeste.
    O script **recusa** plantar prop no anel de trabalho em volta da vaga ou no
    corredor de saída — senão quebra a montagem da gambiarra ou prende o carro,
    que é o que `yard_test`/`attach_test` cobram.
  - **Escala rural**: o censo passou a cobrir fazendas, ferros-velhos e natureza.
    Medido, o rural está coerente (mediana 1,2-5,9 m, máximos 10-16 m em silo e
    moinho) — o que destoava era a serra, já corrigida.

- **2026-08-04** — Usuário reportou: chuva ainda não parece cobrir o mapa,
  **muitas paredes invisíveis**, montanha flutuando, textura de grama/montanha
  feia, e pediu uma estrada de terra até a oficina.
  - **As paredes invisíveis eram 41, uma por maciço, com até 27 m de sobra.**
    `MountainRange` gerava a colisão numa malha **grossa** (14 segmentos) e o
    desenho numa fina (34). Como `_build_mesh` descarta o quad que está
    inteiramente no chão, a borda da malha acompanha o pé da montanha com a
    precisão do PASSO da grade — e o passo grosso é ~27 m. Sobrava um quad
    inteiro de colisão além da encosta visível, na maior parte do perímetro do
    mapa. Agora a colisão sai da **mesma malha** do desenho; trimesh estático
    nessa resolução é barato e a economia não valia o defeito.
  - **Montanha flutuando**: medido, nenhuma — as 44 têm a base no chão. O que
    dava essa impressão era justamente a parede invisível: o jogador parava
    longe da encosta e ela parecia solta.
  - **Chuva no mapa todo** (`scenes/world/WeatherSky.gd`): alargar a caixa de
    partículas não resolve — partícula só aparece perto. O que vende chuva no
    mapa inteiro é o **ambiente**: sol caindo pra 42%, céu e ambiente fechando,
    névoa subindo e o **chão escurecendo como se estivesse molhado** (o sinal
    mais forte de que choveu ALI, mesmo sem uma gota desenhada). Transição
    suave de 4 s, e os valores de tempo bom são **lidos da cena**, não escritos
    no script — mexer no Environment do Town continua valendo.
    - Erro meu: comecei com névoa 0.006 e a cidade sumiu a 200 m — virou leite.
      0.0022 fecha o horizonte sem apagar nada.
  - **Estrada de terra** (`scripts/DirtRoad.gd`): fita de malha da última rua
    asfaltada (x = -112.5) até o pátio (x = -175), com duas trilhas de roda mais
    escuras e borda irregular. **Sem colisão de propósito** — o chão já é
    sólido, e um corpo a mais aqui só criaria degrau e risco de parede
    invisível, que é o defeito que a cordilheira acabou de ter.
    - Erro meu: a fita era construída (o print confirmava os 8 pontos) e **não
      aparecia** — ordem de vértice define pra que lado a face olha, a mesma
      armadilha que a montanha já tinha tido. Resolvido com dupla face, que numa
      fita plana não custa nada.
  - **Novo no verificador**: `scale_test` passou a comparar, em cada corpo, a
    caixa de **colisão** contra a caixa **visual** — colisão que passa mais de
    0,9 m do desenho é parede invisível. Foi assim que os 41 maciços apareceram.
    Também confere se o pé de cada montanha encosta no chão.
  - **Grama e montanha**: mais detalhe (ver entrada anterior), mas o usuário
    ainda achou feio — **continua em aberto**, é limitação de acabamento por
    ruído procedural, não bug.

- **2026-08-04** — Usuário perguntou se eu não tenho "alguma extensão que crie
  as coisas em 3D deixando bonito". **Não tenho**, e vale registrar pra não
  reabrir a pergunta: não existe ferramenta de geração de modelo 3D aqui. O que
  dá pra fazer é (1) geometria e shader em código, (2) baixar asset CC0 pronto,
  (3) mexer em luz e pós-processamento — foi assim que tudo neste projeto foi
  feito.
  - **Rocha PBR na montanha, sem baixar nada**: o repo já tem 5 conjuntos
    ambientCG (asfalto, tijolo, concreto, reboco, telha). O `Concrete034` virou
    grão/normal/rugosidade da encosta, em **triplanar** (a malha é campo de
    altura, não tem UV útil, e projetar só por XZ virava listra na parede).
    A **cor continua saindo da forma** — rocha na encosta, mato embaixo, neve no
    alto — e a textura entra só como acabamento, **modulando em torno de 1.0**
    (multiplicar direto escurece, armadilha já documentada no `city_surface`).
    Só na parte rochosa: neve e mato não podem ter cara de concreto.
  - **Falta pra fechar o terreno**: não há textura de **grama** nem de **rocha
    natural** no repo. Deixar a grama realmente boa pede baixar 2 conjuntos CC0
    do ambientCG (~15MB), que é o mesmo caminho já usado nas fachadas.

- **2026-08-04** — Usuário autorizou baixar o que fosse preciso ("não se
  preocupe com o tamanho, quero algo realmente bonito"). Terreno refeito.
  - **Texturas PBR CC0 no chão** (ambientCG, 2K): Grass004, Grass005, Ground037,
    Gravel022, Rock030, Rock023 (~118MB de fonte). O `ground.gdshader` passou a
    usar cor, normal e rugosidade de verdade, com duas coisas que separam
    "textura aplicada" de "terreno bonito": **anti-repetição** (cada camada
    amostrada em duas escalas, a segunda deslocada e girada, com razão **não
    inteira** — múltiplo inteiro faz as escalas baterem e a grade volta) e
    **mistura por ruído** entre grama/terra/cascalho, sem fronteira reta.
  - **Dois erros meus de shader, o mesmo em espírito**: eu estava **fazendo
    média** onde devia **modular**. (1) O anti-tiling misturava 50/50 as duas
    amostras — média apaga justo o contraste que dá o detalhe, e a grama saiu
    lisa feito campo de golfe; agora a amostra grande só clareia/escurece a
    fina. (2) A cor da textura era misturada com a paleta, lavando tudo; agora o
    brilho é aproximado **por escala**, o que move o tom e preserva o contraste.
  - **A descoberta que mudou o rumo**: mesmo com a textura certa, o campo
    continuava lendo como carpete. Fui olhar a textura de origem e **Grass004 é
    gramado aparado** — uniforme por natureza. Baixei Grass001, Ground038 e
    Ground042 pra comparar: as grama são todas uniformes; quem tem caráter é
    Ground037 (musgo, gravetos, manchas de terra). **Textura plana de grama vai
    sempre ler como carpete da altura dos olhos** — o que dá volume é geometria.
  - **`scripts/GrassField.gd`**: tufos de grama de verdade num anel de 38 m em
    volta do jogador, via **MultiMesh** (2600 tufos numa chamada de desenho). O
    modelo é o `tall-grass.glb` do nature-megakit, que já estava no projeto —
    nenhum estilo novo. Re-sorteia só quando o jogador anda mais de 12 m, e a
    semente é amarrada à **célula**, não ao tempo: voltando ao mesmo lugar a
    grama nasce igual, senão o gramado inteiro troca de desenho e o movimento
    aparece com o canto do olho.
    - **Erro meu**: fixei a `custom_aabb` em volta da origem do nó, mas os tufos
      nascem centenas de metros dali (junto do jogador) — o Godot descartava o
      campo INTEIRO e a grama não aparecia, **sem erro nenhum no log**. A caixa
      passou a acompanhar o centro do espalhamento.
    - Erro de arnês junto: o roteiro de fotos posicionava só a câmera, e a grama
      nasce em volta do JOGADOR — as primeiras fotos mostravam chão pelado a
      55 m dele. Agora o jogador acompanha a câmera.
  - **Rocha PBR na montanha**: `Rock030`/`Concrete034` em triplanar (ver entrada
    anterior).

### Pendências pedidas e ainda NÃO feitas

Nenhuma das três pendências anteriores continua aberta. O que sobrou de
observação pra uma próxima rodada (nada disso foi pedido):

1. **Jogar com as mãos.** O loop agora é testado de ponta a ponta com input
   real (`tools/verify/loop_test.tscn`, 5/5 rodadas), mas ninguém *sentiu* o
   jogo: se 76 km/h é rápido demais, se a barra de lábia dura o certo, se o
   reboque de 38 m é chato. Isso só se resolve jogando.
2. ~~**O pátio da oficina prende o carro.**~~ **Medido e fechado** em
   2026-08-04 (`tools/verify/yard_test.tscn`): o pátio não prende — sai em 4 dos
   8 ângulos, com os bloqueados todos virados pro fundo. O que de fato prendia
   era a cápsula do jogador, que continuava sólida ao dirigir; corrigido. Sobra
   que a carcaça rebocada para apontada pro barracão e o primeiro W anda ~8 m e
   encosta: o jogador manobra. Estacionar automático foi tentado e revertido —
   ver o changelog antes de tentar de novo.
3. **Telhado verde do kit suburbano** ainda puxa pro menta. O shader já
   dessatura verde puro (`green_tame`), mas a cor vive dentro do atlas.
4. **Câmera 04 do roteiro de fotos** ficava em (30, 2.2, 30), que com a grade
   nova cai DENTRO de um quarteirão — se recriar o script de fotos, reposicionar.

## Roadmap (fora de escopo desta vertical slice)

- Multiplayer real (cooperativo na oficina / competitivo pelas ruas). Arquitetura atual
  evita estado local hard-coded onde possível, mas a replicação de rede não foi
  implementada.
- **Malha viária — polimento restante**: as pontas das ruas já têm acabamento
  arredondado, postes de luz, meio-fio/calçada elevada de verdade (com colisão própria,
  já fechando nos 4 cantos de cada cruzamento) — ver `CityStreets.gd`. O suporte a
  trecho diagonal (`diagonal_starts`/`diagonal_ends`) continua no script, mas o
  exemplo de teste foi removido de `Town.tscn` no redesenho de 2026-08-02 (ficava
  órfão, sem conectar em nada — ver changelog). Ainda falta: não existe peça de
  cruzamento diagonal-com-ortogonal no kit do Kenney; uma avenida diagonal de
  verdade cortando o mapa (tipo Broadway em Manhattan) precisaria resolver esses
  cruzamentos em ângulo, o que não foi tentado.
- Sistema de crafting mais rico (mais tipos de gambiarra, escolha de item por
  inventário em vez de item fixo por ponto de fixação).
- Economia mais profunda (preços variáveis, múltiplos compradores com personalidades
  diferentes, negociação).
- Sons, música, efeitos de UI/menu (menu principal e de pause já existem — ver
  changelog 2026-08-02 —, mas ainda sem áudio nenhum no jogo).
- **Prédios do Quaternius (Downtown City MegaKit)**: usados em `Town.tscn` por um
  tempo (2 dos 3 prédios prontos; `Building_Medium_2_001` tem um bug visual), mas
  retirados do layout ativo no redesenho de 2026-08-02 pra manter um único estilo
  visual coerente (ver changelog) — o choque com o low-poly do Kenney era exatamente
  um dos problemas de "desarmonia" apontados. Os assets continuam no repo
  (`assets/quaternius/downtown-city-megakit/`), então voltar a usá-los é só trocar
  `visual_scene` de novo, se um dia quisermos um quarteirão deliberadamente
  diferente (tipo um "centro histórico" x "downtown moderno"). O pacote também
  trouxe ~150 peças modulares soltas (tijolos, cornijas, janelas, sacadas) que
  dariam pra montar fachadas customizadas à mão — não tentado, é um trabalho de
  "level design" separado.
- Ícone do jogo e notarização (o preset macOS já usa assinatura ad-hoc, gratuita — ver
  changelog 2026-08-02 — mas não é notarizado pela Apple; hoje quem baixar ainda
  precisa clicar em "Abrir" uma vez, ver README).

## Limitações conhecidas da vertical slice

- Se o jogador mirar no corpo do carro (em vez de num ponto de fixação) enquanto ele
  ainda está incompleto, o prompt volta a mostrar "Rebocar [E]" mesmo já estando na
  oficina — inofensivo, só reengancha o TowHook.
- As entregas já são em casas sorteadas da cidade (ver 2026-08-03), mas o NPC de
  entrega é sempre o mesmo modelo/personalidade — não há variação de cliente nem
  negociação (ver Roadmap).
- Os buracos (`Pothole*`) e poças de lama continuam em 4 pontos fixos da grade, em
  vez de espalhados/procedurais.
- Os pedestres e o cliente ainda saem de só 2 personagens-base (um masculino, um
  feminino) com a mesma peça de roupa. Tipo físico, altura e cor de pele/roupa/
  cabelo já variam por NPC (ver changelog 2026-08-03), mas **rosto e modelo de
  roupa não** — dois pedestres do mesmo gênero continuam com a mesma cara. Rosto
  diferente exigiria outro pacote de assets; o pacote gratuito do Quaternius só
  traz esses dois corpos, dois cabelos e a roupa Peasant.
