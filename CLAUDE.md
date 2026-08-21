# CLAUDE.md — Jegues Mecânicos

Documento vivo do projeto. Aqui ficam registrados o pitch do jogo, decisões técnicas,
o histórico de ordens/mudanças pedidas pelo usuário e o roadmap. Atualizar sempre que
uma decisão relevante for tomada ou o escopo mudar.

## Notas de fluxo de trabalho

- **Sempre publicar as builds atualizadas numa release do GitHub.** Pedido
  explícito do usuário em 2026-08-13: commit/push da `main` não basta. Toda
  rodada que muda o jogo deve terminar com Windows e macOS reexportados,
  auditados, testados e anexados à release pública. Se o usuário não indicar a
  versão, criar a próxima versão de correção, sem sobrescrever silenciosamente
  um lançamento anterior. Conferir no GitHub os nomes, tamanhos e data dos dois
  arquivos depois do upload. A rodada só está concluída quando código **e**
  downloads públicos correspondem ao mesmo commit.

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

- **Testar na prática faz parte do trabalho — inclusive quando o trabalho é
  REVISAR.** Pedido do usuário em 2026-08-13, depois de eu ter entregado uma
  revisão só de leitura de diff + teste headless, alegando que o worktree estava
  sujo com a rodada do outro agente. Não cola: rodar o jogo de verdade, tirar as
  fotos do que mudou e **olhar uma a uma**, exercitar o caminho pelo input real e
  escrever um teste novo quando o achado for de comportamento. Worktree sujo não
  é motivo pra pular — é motivo pra dizer na anotação qual estado foi
  fotografado. A prova de que a regra vale: nessa mesma rodada, as duas baterias
  numéricas passaram limpas e foi **a foto** que achou o prompt de negociação
  vazando pra fora do painel, e foi **um teste novo** que provou o exploit de
  rezerar a conversa. Isso repete a lição que este arquivo já tinha desde
  2026-08-04 ("quando o usuário diz que algo não funciona e a verificação passa,
  fotografar antes de mexer") — agora ela vale também pra revisão, não só pra
  implementação. A regra está espelhada no `AGENTS.md`.

- **Anotar SEMPRE neste arquivo, a cada rodada.** Pedido do usuário em
  2026-08-09, e ele pediu explicitamente que esta instrução também ficasse
  registrada. Vale pra tudo: o que foi feito, o que foi medido, o erro que eu
  cometi e como foi pego, e o que ficou em aberto. A razão é prática — a
  conversa é limpa com `/clear` entre tarefas (ver a nota abaixo), então o que
  não estiver escrito aqui **está perdido** pra próxima sessão. Anotar no fim da
  rodada, antes de exportar e commitar, faz parte de terminar a tarefa.

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
    como shape keys**, com ajustes de proporções corporais específicos para cada
    modelo — ver changelog 2026-08-03.
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
- **Ferro-velho:** o lote tem **3 carcaças ao mesmo tempo** e se repõe sozinho
  (25s depois que uma vaga esvazia). Mire numa delas — **Q vistoria** (revela km,
  lataria, pintura e quanto ela vale consertada), **Q de novo pechincha** (3
  tentativas, com risco de o dono se fechar) e **E compra**. Sem comprar não dá
  pra rebocar.
- **Dirigindo:** W/S acelera/ré, A/D vira, Space freio de mão, F sai do carro,
  **R desvira/reassenta o carro** (também vale rebocando a carcaça a pé).
- **Oficina (carro no pátio):** mire na carroceria — **Q diagnostica** (revela
  quais peças estão quebradas) e **Q de novo troca a próxima peça**, pagando. A
  oficina só troca o que o nível dela alcança.
- **Gambiarras:** mire num dos 4 pontos coloridos — **Q troca o item** (3 opções
  por ponto) e **E instala**, pagando. A barata sai quase de graça e cai no
  primeiro buraco; a caprichada aguenta o test-drive e o cliente quase não
  desconta, mas come um pedaço do lucro antes da venda.
- **Quadro de melhorias (pátio):** **Q troca de área** (oficina, funilaria,
  pátio, escritório) e **E compra** o próximo nível. Na área que já está no
  **último nível**, o **E contrata** quem trabalha nela (mecânico na oficina,
  recepcionista no escritório).
- **Pátio:** as faixas amarelas pintadas na laje mostram quantas vagas o nível
  atual dá (1, 2 ou 4). Com o pátio cheio, o reboque **não solta** — venda um
  carro ou melhore o pátio.
- **Venda:** a entrega é numa casa sorteada da cidade (placa verde ENTREGA);
  encoste o carro na frente dela. No cliente, **Q escolhe o preço pedido**
  (4 degraus) e **E ouve a oferta**. Durante a conversa, **E aceita**, **Q faz
  uma contraproposta** e **F tenta um blefe**. Chance, oferta, pedido e rodadas
  ficam visíveis; preço exagerado, reputação baixa e carro quebrado reduzem a
  chance. O cliente nunca paga acima do pedido.
- **Menus:** o jogo abre num menu principal (Jogar/Sair); Esc a qualquer momento
  dentro da partida pausa e abre Continuar/Sair para o Menu/Sair do Jogo.
- **Personagem** (botão no menu principal): escolhe **mulher ou homem**, cabeça
  de jegue ou humana, **altura de 1,60 a 1,95 m** e as formas do corpo por
  slider, apresentadas como ajustes de proporções corporais disponíveis para
  cada modelo, mais cor de pele, roupa e cabelo. Tem preview 3D ao vivo —
  arrasta pra girar, roda do mouse aproxima — com uma régua de 1,80 m ao lado.
  A escolha é salva em `user://aparencia.cfg` e **não é apagada por "Novo
  jogo"**: aparência não é progresso.

## Estrutura do projeto

```
project.godot          # config do Godot, autoloads, display/fullscreen
export_presets.cfg     # presets Windows Desktop + macOS (testados e funcionando)
autoload/               GameManager.gd, Economy.gd (valor do carro, peças,
                        clientes), Dealership.gd (áreas da loja e níveis),
                        Staff.gd (mecânico e recepcionista contratados),
                        WeatherManager.gd (clima/chuva),
                        EventManager.gd (eventos procedurais),
                        DeliveryManager.gd (sorteia a casa da entrega da vez),
                        GraphicsSettings.gd, AudioManager.gd (biblioteca de sons,
                        barramentos, piscina de vozes e volume),
                        SaveGame.gd (progresso em user://progresso.cfg),
                        Appearance.gd (o personagem do jogador: modelo, formas,
                        altura e cores, em user://aparencia.cfg)
shaders/                city_surface.gdshader (fachada/asfalto: atlas do kit +
                        PBR triplanar + sombreamento facetado),
                        ground.gdshader (chao do mundo por ruido, sem textura),
                        mountain.gdshader (rocha/mato/neve por altura e declive)
scripts/                Interactable.gd, TowHook.gd, PersuasionMinigame.gd, Pothole.gd,
                        JunkyardLot.gd (o lote de 3 carcaças que se repõe),
                        Mechanic.gd (o funcionário que conserta no pátio),
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
                        AttachSpot.gd (escolha de gambiarra: Q troca, E instala),
                        GambiarraPart.gd, parts/GambiarraPart.tscn (uma cena so,
                        montada a partir do catalogo em Economy.GAMBIARRAS)
tools/verify/           city.tscn, drive_test.tscn, loop_test.tscn,
                        staff_test.tscn, yard_shots.tscn e outros —
                        verificacao automatizada (fora do build, ver
                        tools/verify/README.md)
scenes/world/           Town.tscn (cidade + anel rural, tudo num só mundo sandbox),
                        Junkyard.tscn (o lote), Workshop.gd (o pátio e suas
                        vagas — usado pelo RuralWorkshop, sem .tscn próprio),
                        MudZone.tscn/gd, RainFX.tscn/gd,
                        CityBuilding.tscn (prédio genérico com colisão automática),
                        FarmCluster.tscn/gd (fazenda procedural), ScrapyardCluster.tscn/gd
                        (ferro-velho rural decorativo), RuralWorkshop.tscn (a oficina
                        do jogador, um ferro-velho no campo), CityBlocks.tscn e
                        RuralScatter.tscn (wrappers dos scripts em scripts/)
scenes/traffic/         TrafficCar.tscn/gd, TrafficRoute.tscn/gd — carros de IA
scenes/npc/             BuyerNPC.tscn/gd, Pedestrian.tscn/gd, PedestrianRoute.tscn/gd
scenes/ui/              HUD.tscn/gd — dinheiro, prompt e painel de negociação;
                        MainMenu.tscn/gd (tela inicial, cena de entrada do jogo);
                        PauseMenu.tscn/gd (Esc pausa a árvore, some com o mouse);
                        SettingsMenu.gd, CharacterMenu.gd e LoadingScreen.gd —
                        os três montados 100% EM CÓDIGO, sem .tscn, porque cena
                        escrita à mão já ficou de fora do .pck exportado
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
  repositório privado `vitudanas/JeguesMecanicos` (rebase em cima do commit inicial do
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
  ([v0.1.0](https://github.com/vitudanas/JeguesMecanicos/releases/tag/v0.1.0)) em vez de
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
    peça Peasant é um **colete aberto na frente do torso**, e por baixo estava o
    corpo do super-herói, então aparecia torso nu. Testei encolher/inflar em vários
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
  pediu as duas frentes: variedade (altura/cor) **e ajustes de proporções
  corporais**.
  - **Por que shape key e não vários personagens**: a alternativa óbvia era
    gerar N variantes de GLB no Blender, mas cada personagem pronto pesa 10-13MB
    (textura embutida), então 6 tipos somariam ~60MB num build de 116MB. Gravar
    os tipos como **morph target** custou **+1.3MB e +1.5MB** nos dois arquivos
    que já existiam, não toca no esqueleto (a animação continua valendo) e ainda
    deixa o peso de cada forma ser sorteado **por NPC** — a variedade deixa de
    ser "um de 6" e passa a ser contínua.
  - **Como as formas são feitas** (`tools/build_characters.py`): operações
    geométricas são aplicadas ao corpo **e à roupa juntos**, impedindo que os
    ajustes de proporções corporais atravessem o tecido. As regiões foram
    definidas medindo as seções transversais dos dois modelos no Blender.
  - **Erro real corrigido no meio do caminho**: uma primeira deformação
    direcional produzia uma silhueta pontuda. Foi substituída por expansão
    radial em três eixos, com transição suave e deslocamento menor. **Lição**:
    ajustes volumétricos arredondados precisam preservar a continuidade da
    silhueta, não deslocar uma região inteira num único eixo.
  - Os modelos oferecem conjuntos diferentes de ajustes de proporções
    corporais; o código consulta apenas as formas disponíveis em cada arquivo.
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
  primeira: pele atravessando a roupa (braço e costas, nos dois modelos) e
  ajustes de proporções corporais que ainda precisavam de equilíbrio.
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
  - **Ajustes de proporções corporais**: regiões relacionadas passaram a variar
    juntas para preservar uma silhueta coerente; alterar uma área isoladamente
    produzia transições artificiais com as regiões vizinhas.
  - **20 combinações** (pedido do usuário): dois ajustes passaram a usar degraus
    fixos sorteados de forma **independente**, totalizando 20 pares e cobrindo
    toda a faixa configurada. Um pequeno desvio sobre cada degrau evita que duas
    pessoas da mesma combinação fiquem idênticas.
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

- **2026-08-04** — Usuário reportou grama gigante, pediu o máximo de qualidade
  nas construções ("sem se preocupar com armazenamento"), depois um contador de
  FPS, meta de 50-80 FPS e um menu de config com opções de gráficos.
  - **A grama gigante era MEDIDA errada, em dois lugares.** O tufo
    (`tall-grass.glb`) tem **1,87 m** no arquivo, e os dois espalhadores eram
    configurados em ESCALA CRUA: `GrassField` ia de 0.5 a 1.25 (grama de 0,94 a
    **2,34 m** — mais alta que o jogador) e o `NatureScatter` do anel rural
    usava 0.8-1.5 pro pool inteiro, o que fazia a samambaia (9 m de largura no
    arquivo) virar um leque de **13 m** no mapa todo. Nenhum número na cena
    dizia nada sobre tamanho, e por isso ninguém notou. Os dois passaram a
    declarar **altura em METROS**, com a escala saindo da altura medida do
    modelo — `RuralScatter` ganhou `decor_height_min/max` como arrays paralelos
    a `decor_scenes` (mesmo padrão de `diagonal_starts`/`_ends`).
  - **Grama refeita** (`shaders/grass.gdshader` + `GrassField` em 3 camadas):
    cor vinda da PALETA DO CHÃO (a do modelo é verde-limão e brigava com o
    terreno), vento com a base presa e a ponta balançando na mesma direção pro
    campo inteiro, tufo que ENCOLHE até sumir na borda do anel em vez de piscar,
    e `BACKLIGHT` porque folha fina contra o sol sem isso fica preta. O chão
    agora é medido numa grade grossa de raios: a grama acompanha o relevo e não
    nasce em laje, calçada, asfalto nem na estrada de terra (essa não tem
    colisão, então é lida do próprio nó pelo grupo `dirt_road`).
  - **Erro meu na distribuição**: usei `dist = u^0.40 * R` querendo adensar
    perto do jogador. Com `u^p`, a densidade por área fica ∝ `d^(1/p - 2)` —
    0.40 dá `d^+0.5`, ou seja o OPOSTO, e o primeiro plano (onde o tufo mais
    aparece) saía pelado. Só acima de 0.5 adensa.
  - **O chão estava lavado de branco** e a culpa não era da cor: o `Grass004`
    do ambientCG tem rugosidade média **0,26** (lustroso, feito pra grama
    molhada de estúdio) e estava sendo usado cru — com o céu HDRI por cima, o
    campo inteiro ganhava brilho especular. O mapa passou a MODULAR uma faixa
    fosca, e `SPECULAR` do terreno caiu de 0.5 pra 0.15.
  - **A faixa térrea de TODOS os prédios renderizava preto puro.** Um quarto do
    atlas do kit (medido: 65536 dos 262144 pixels) é `(0,0,0)`. Antes de ajustar
    número, renderizei um modelo do kit com o material ORIGINAL pra ver a
    intenção do artista — e ela é clara: o preto é o **embasamento térreo**, e a
    **janela é AZUL**. Então são dois tratamentos diferentes: o preto vira
    plinto escuro de verdade (recebe luz, grão e sujeira), e o azul vira
    **vidro** metálico e liso, refletindo o céu HDRI, com emissão fraca e
    fresnel porque em rua estreita a parede não vê o céu e a janela voltava a
    ser buraco.
  - **Como achei que a regra pegava os pixels certos**: pintei o plinto de
    VERMELHO e renderizei. Mesma lição de 2026-08-03 (provar de qual malha é o
    defeito antes de ajustar). O vermelho apareceu no lugar exato — o que
    engolia a faixa era o **SSAO em intensidade 2.0 / potência 2.2** somado ao
    albedo zero. SSAO baixou pra 1.15 / 1.6 / raio 2.0.
  - **Vitrines de rua** (`StreetFurniture.storefront_into`): vidro grande com
    montante, toldo listrado de duas cores com babado, letreiro aceso e porta,
    em ~72% dos prédios de comércio. É o que transforma a faixa mais morta da
    cidade no ponto mais interessante da rua. Sem colisão de propósito — a caixa
    do prédio já fecha a fachada.
  - **Lotes especiais deixaram de ser retângulo de cor chapada**: praça, posto,
    estacionamento e feira ganharam piso PBR (`CitySurface` ganhou os conjuntos
    "grama", "cascalho" e "terra"). E a calçada, que estava em albedo **0,72**
    (mais clara que tudo na rua), foi pra 0,50 — concreto de verdade reflete
    ~40%.
  - **Otimização sem tirar detalhe** (pedido explícito de manter 50-80 FPS):
    1. `scripts/MeshBatch.gd` junta as vitrines num nó **por quarteirão**, uma
       superfície por material. Montadas como árvore de nós, cada loja passava
       de 20 `MeshInstance3D`. Por quarteirão, e não pela cidade toda, pro
       descarte por frustum continuar valendo.
    2. `visibility_range_end` nos props pequenos do anel rural (130 m) e nas
       vitrines (180 m) — a essa distância eles não chegam a um pixel.
    Medido no mesmo ponto de vista: as vitrines custavam **+700 a +2100**
    chamadas de desenho; depois disso a cena voltou ao patamar de ANTES delas
    existirem, com toda a qualidade nova.
  - **Medir tempo de quadro aqui não funciona** e isso custou uma rodada: com a
    grama DESLIGADA o quadro saiu mais LENTO (118 ms contra 101 ms). O macOS
    estrangula a janela fora de foco. Troquei por **chamadas de desenho e
    primitivas**, que são contagem do renderizador e não dependem disso.
  - **Contador de FPS** no canto inferior esquerdo (verde acima de 50, amarelo
    até 30, vermelho abaixo), atualizado 4x por segundo.
  - **Menu de gráficos** (`autoload/GraphicsSettings.gd` +
    `scenes/ui/SettingsMenu.tscn`, no menu principal e no pause): presets
    Baixa/Média/Alta/Ultra mais controles soltos de escala de render (o botão
    que mais rende — FSR2 a 75% custa metade dos pixels), sombras, SSAO/SSIL,
    densidade de grama, anti-serrilhado, glow, V-Sync e o próprio contador.
    Salva em `user://graphics.cfg`.
    - Bug real que o verificador pegou: **TAA e FSR2 não convivem**. Pedindo os
      dois, o Godot desliga o TAA sozinho e só avisa no log — a opção ficava
      marcada na tela sem estar valendo. Agora o TAA é desligado ANTES e religado
      DEPOIS de mexer na escala (na ordem errada o aviso voltava ao SUBIR de
      preset), e "alta" usa FXAA porque a 85% quem faz o papel do TAA é o FSR2.
    - E os valores padrão do autoload não batiam com o preset "alta" campo a
      campo, então o jogo abria já nessa combinação inválida.
  - **Verificação**: `tools/verify/settings_test.gd` (novo) aplica cada preset no
    `Main.tscn` de verdade e cobra que **algo mude** entre presets vizinhos e que
    a geometria nunca suba ao descer de preset. Minha primeira versão cobrava
    queda em TODO degrau e reprovou um preset correto: de 'alta' pra 'ultra' só
    muda custo POR PIXEL (escala, SSIL, TAA), que não aparece em primitiva
    nenhuma. `tools/verify/quality_shots.gd` (novo) fotografa grama e fachadas do
    ponto de vista do jogador. `scale_test` ganhou censo de altura da vegetação.
    - **Armadilha do headless**: `MultiMesh.set_instance_transform` **não guarda
      nada** com o servidor de render falso — os 24800 tufos voltavam com a
      matriz identidade mesmo com o espalhamento comprovadamente tendo rodado.
      Por isso a altura da grama é conferida na CONFIGURAÇÃO (que agora está em
      metros), e o `scale_test` também cobra que o array de alturas do
      `RuralScatter` cubra todos os modelos — faltando entrada, aquele modelo
      volta calado pra escala crua, que é como o defeito nasceu.
    - Suíte inteira passa: city, drive, loop, attach, scale, yard e settings.
  - **Dois bugs meus achados só no BUILD e na FOTO, não no código:**
    1. **`SettingsMenu.tscn` ficou fora do `.pck`.** Um `.tscn` escrito à mão
       aparece no cache do editor e mesmo assim o exportador não o leva
       (regravar pelo `ResourceSaver` não resolveu — o arquivo continua sem
       `uid`). O `preload` dele teria quebrado o menu principal só no binário
       exportado. Resolvido tirando o arquivo de cena: a tela é montada 100% em
       código e só depende do `.gd`, que o exportador sempre leva. Daí saiu
       `tools/verify/pack_audit.py`, que cobra cada `res://` referenciado
       dentro do pacote — a mesma classe de bug que em 2026-08-02 impediu o jogo
       de abrir. **Cuidado**: cena entra no `.pck` convertida em
       `export-<hash>-<Nome>.scn`, então cobrar o caminho original acusa
       `Main.tscn` como ausente (foi o primeiro resultado do auditor).
    2. **`set_anchors_preset` não preenche.** Sem o `.tscn`, a tela montava os 9
       controles e ficava INVISÍVEL, medindo (0, 0): esse método só mexe nas
       âncoras e recalcula os offsets pra manter o retângulo atual — que num
       `Control.new()` é zero. Quem preenche é
       `set_anchors_and_offsets_preset`. Num `.tscn`, `anchors_preset = 15` faz
       as duas coisas, e por isso o defeito só apareceu ao largar o arquivo de
       cena. Achado medindo `size` na cena, depois que a contagem de controles
       (9/9) já dizia que estava tudo lá.

- **2026-08-04** — Usuário pediu que o jogador seja uma **mulher com cabeça de
  jegue**, com ajustes específicos de proporções corporais, e que **V troque
  entre 1ª e 3ª pessoa**. Implementado; **falta conferir na tela** (ver o aviso
  no fim desta entrada).
  - **Corpo**: reaproveita o mesmo `Female_Dressed.glb` dos pedestres (corpo +
    roupa + cabelo num arquivo só, gerado por `tools/build_characters.py`) — não
    traz modelo novo e não reintroduz mistura de estilo. A diferença é que as
    formas são **fixas**, não sorteadas, usando uma combinação intermediária
    dos ajustes de proporções corporais já aplicados aos NPCs. Regiões
    relacionadas variam juntas para manter a silhueta coerente.
  - **Cabeça de jegue** (`scripts/DonkeyHead.gd`): montada com esfera, cápsula e
    caixa, como o mobiliário urbano e as gambiarras — não existe modelo CC0
    disso e não há ferramenta de geração 3D aqui (registrado em 2026-08-04).
    Crânio, focinho de duas peças, ventas, olhos **para o lado da cabeça** (olho
    de frente lê como pessoa fantasiada), pálpebra clara, orelhas longas em
    cápsula com miolo claro, crina descendo a nuca e topete.
    - **Medido antes de montar**: o osso `Head` fica em y = 1.55 do modelo, com
      os eixos praticamente alinhados ao mundo e **o rosto olhando pro +Z**; a
      cabeça humana ocupa x ±0.12, y 1.50..1.78, z -0.16..0.11.
    - A cabeça humana **não pode ser escondida sozinha** — ela faz parte da
      mesma malha do corpo (`Superhero_Female`). Por isso o crânio do jegue é
      generoso de propósito: ele ENGOLE a cabeça. Cabelo, olhos e sobrancelha
      são malhas separadas e esses sim somem (`DonkeyHead.HIDE_MESHES`).
    - Presa num `BoneAttachment3D` do osso `Head`, então acompanha a animação —
      é exatamente o bug do cabelo dos NPCs de 2026-08-03 (malha transplantada
      sem reatribuir o vínculo fica parada no ar).
  - **1ª/3ª pessoa** (`Player.gd` + `SpringArm3D` em `Player.tscn`): V alterna,
    na borda de subida (mesmo padrão do E). Dois detalhes que não são óbvios:
    1. A **inclinação do olhar passou da câmera pra CABEÇA** (`$Head`). As duas
       câmeras são irmãs debaixo dela; aplicada só na câmera de 1ª pessoa (como
       era), a de 3ª ficaria presa na horizontal.
    2. Em 1ª pessoa o corpo **não some** — passa a `SHADOW_CASTING_SETTING_SHADOWS_ONLY`.
       Escondido de vez, o jogador perde a própria sombra no chão; visível de
       vez, a câmera fica dentro da cabeça de jegue e o focinho toma a tela.
    - O estado (`third_person`) é do jogador, não da câmera, pra sobreviver a
      entrar e sair do carro.
    - A mola exclui o próprio corpo do jogador (`add_excluded_object`), senão
      ela se apoia nele e a câmera nunca recua.
  - **Animação**: idle/walk/run da UAL1, escolhidas pela velocidade REAL do
    corpo (não pela tecla), então empurrado ou escorregando o boneco também se
    mexe.
  - **[RESOLVIDO em 2026-08-08 — ver a entrada seguinte.]**
    **ATENÇÃO PRA PRÓXIMA SESSÃO — o que ainda NÃO foi verificado:** o projeto
    carrega sem erro e o `class_name` novo foi registrado (precisou de
    `godot --headless --path . --editor --quit` pra isso — `.gd` criado fora do
    editor não entra no cache de classes sozinho, mesma pegadinha do
    `MeshBatch`). Mas **as fotos da personagem não chegaram a ser conferidas**.
    Rodar e OLHAR antes de dar como pronto:
    ```
    godot --path . tools/verify/quality_shots.tscn
    ```
    e um roteiro de fotos do jogador (frente, cabeça em close, costas, perfil,
    3ª pessoa) — o que provavelmente vai precisar de ajuste é (a) se o crânio
    engole mesmo a cabeça humana de todos os ângulos, (b) a escala da cabeça
    contra o corpo de 1.77 m, (c) o enquadramento da câmera de 3ª pessoa
    (`spring_length` 3.2, ombro em x = 0.5). Builds **não** foram reexportados
    nesta rodada.

- **2026-08-08** — Fechada a pendência que a sessão anterior deixou explícita: a
  jogadora de cabeça de jegue tinha sido montada e **nunca olhada**. Criado
  `tools/verify/player_shots.tscn` (fotos da personagem + medida da cabeça) e,
  com ele, três defeitos reais apareceram — nenhum deles visível em número.
  - **As 15 primeiras fotos saíram de um campo VAZIO**, e o defeito era do
    arnês, não do jogo: o jogo abre em **1ª pessoa**, e nela o corpo fica em
    `SHADOW_CASTING_SETTING_SHADOWS_ONLY` (decisão correta, de 2026-08-04).
    Fotografar o corpo exige entrar no modo em que ele existe na tela. Vale como
    lição geral: **quando a foto sai vazia, primeiro provar de que lado está o
    defeito** — é a mesma armadilha de arnês de 2026-08-04.
  - **As ventas liam como um SEGUNDO par de olhos.** Mediam 4,5 × 5,5 cm, quase
    pretas sobre o focinho claro: de frente e de baixo o bicho parecia ter
    quatro olhos. Reduzidas pra 3,0 × 4,0 cm, inclinadas pra fora e menos
    escuras. Foi o defeito mais danoso dos três, e o mais barato de corrigir.
  - **A crina era um colar de contas soltas**, e a primeira correção não
    resolveu — virou um tubo levantado no meio da nuca, tipo lagarta. As duas
    versões erravam pelo mesmo motivo: a crina era desenhada num caminho
    escrito à mão, **solta da cabeça**. Agora os pontos saem da própria casca do
    crânio (`_skull_point`, com `lift = 1.02`), então metade de cada esfera fica
    enterrada e o que aparece é uma crista rente — que é como crina de burro se
    comporta. O crânio virou constante (`SKULL_CENTER`/`SKULL_RADII`/
    `SKULL_TILT`) e a crina lê dele: mudar o crânio não descola mais a crina.
  - **O focinho era um tubo de tamanduá**: quase horizontal (6°) e com a ponta
    pálida MAIS LARGA que o cano (0.20 contra 0.19), o que formava um degrau e
    lia como bulbo grudado na cara. Agora cai 12° da testa pra ponta, mais curto,
    e a ponta é mais estreita que o cano.
  - **A medida numérica da cobertura do crânio é GROSSA, e isso está documentado
    no próprio teste.** Ela compara vértice a vértice contra as esferas lidas do
    `DonkeyHead` montado, mas os vértices do `.glb` estão na pose de **bind** e
    são levados pro mundo pela transformada do `MeshInstance3D`, que não é a
    mesma coisa que a pose de skin do renderizador. Medido: com o crânio
    cobrindo a cabeça INTEIRA, ela ainda acusava 67 vértices "expostos" até
    2,2 cm. Quem decide são as **fotos de prova** (16-19), que pintam o corpo
    humano de **magenta chapado** e deixam a cabeça de jegue normal — qualquer
    pedaço de cabeça humana escapando apareceria como mancha berrante, e não
    aparece nenhuma. É a mesma técnica que resolveu o retalho do ombro dos NPCs
    em 2026-08-03, agora persistida no repo em vez de improvisada. O limiar
    ficou folgado de propósito (>12% ou >6 cm): apertar só geraria alarme falso.
    O número continua útil como **tendência** — foi de 363 → 88 → 67 conforme a
    cabeça foi corrigida.
  - **O que estava certo e não precisou de nada**: a cabeça acompanha o osso
    `Head` na animação (sem o bug do cabelo de 2026-08-03), a 1ª pessoa não tem
    focinho na tela, o enquadramento da 3ª pessoa está bom como está
    (`spring_length` 3.2, ombro em 0.5) e a escala fecha — 2,07 m até a ponta
    da orelha, ou seja a mulher de 1,77 m mais orelha em pé.
  - **Suíte inteira reconferida** depois das mudanças (city, drive, loop,
    attach, scale, yard, settings): tudo passa, o loop continua fechando de
    ponta a ponta. Builds reexportados, `pack_audit` confirma as 67 referências
    `res://` dentro do `.pck`, e o binário exportado sobe limpo. **O `.app`
    extraído foi apagado e reextraído** — ele não se atualiza sozinho quando o
    zip é regravado (lição de 2026-08-04). Não cheguei a clicar "Jogar" no
    binário exportado pra ver a cidade renderizada: não dá pra clicar em janela
    nativa nesta sessão.

- **2026-08-08** — Usuário pediu pra seguir com o andamento geral. Fechado o
  maior buraco que sobrava: **o jogo não tinha UMA linha de áudio** — nenhum
  arquivo, nenhum `AudioStreamPlayer`, nada. Estava no Roadmap desde o começo.
  - **Assets**: mais dois pacotes CC0 do Kenney (`impact-sounds` e
    `interface-sounds`), a mesma fonte do resto do jogo. Só os 47 arquivos
    usados entraram no repo (440KB), como já se faz com os outros pacotes.
  - **Motor e chuva são SINTETIZADOS** (`scripts/ProceduralAudio.gd`): o Kenney
    não tem pacote de motor nem de chuva, e som contínuo é justamente o que
    sintetiza bem (é harmônico e ruído, não gravação). Custa zero byte no build,
    e o motor ganha de graça o que uma gravação não dá: como o ciclo é
    sintético, `pitch_scale` sobe a rotação sem soar picotado. O motor tem
    explosões deliberadamente **irregulares** — com todas iguais soava zumbido,
    não motor.
  - **`autoload/AudioManager.gd`**: barramentos (Master/SFX/UI) criados **em
    código**, não num `default_bus_layout.tres` — recurso escrito à mão já ficou
    fora do `.pck` uma vez neste projeto e só quebrou no binário exportado.
    Piscina de vozes (16 em 3D, 6 em 2D) em vez de instanciar nó por som: batida
    em cadeia é o normal aqui (gambiarra caindo, carro batendo) e criaria
    dezenas de nós por segundo.
  - **Som de interface se liga SOZINHO** em todo `BaseButton`/`Slider` que entra
    na árvore (mesmo padrão de `node_added` que o `GraphicsSettings` já usava).
    Além de não repetir código nos 3 menus, isso cobre a tela de configuração,
    que é montada 100% em código e cujos controles nasceriam mudos.
  - **Ligado no jogo**: motor por velocidade+acelerador (só no carro DIRIGIDO —
    42 carros de IA custariam um tocador cada, e uma carcaça no ferro-velho
    ficaria roncando parada), batida de lataria por força de impacto, buraco,
    gambiarra encaixando e arrebentando, passo do jogador, queda, reboque
    engatando, pedestre atropelado, venda fechada, venda perdida e a chuva.
  - **Passo sabe a superfície** reusando o critério do `GrassField` (grupo
    `terreno_natural`), então passo e grama concordam por construção — asfalto,
    meio-fio, laje e prédio soam duro sem precisar de lista de exceção. E a
    passada é por METRO ANDADO, não por tempo: assim a cadência acompanha
    sozinha o andar e a corrida.
  - **Menu de configuração** ganhou seção "Som" com três controles (geral,
    efeitos, interface), com a porcentagem escrita do lado — a alça sozinha não
    diz nada, ainda mais com o som mudo.
  - **Erros meus nesta rodada**:
    1. *Separei os campos da biblioteca por `:`* — e `res://` tem dois-pontos,
       então o primeiro campo saía como "res" e nenhum som carregava. Virou
       struct explícita.
    2. *`class_name` novo não registrado*: `VehicleAudio` criado fora do editor
       não entra no cache de classes, e o `Vehicle.gd` parou de compilar. É a
       pegadinha já documentada do `MeshBatch` — precisa de
       `godot --headless --path . --editor --quit`.
    3. *Montei os caminhos da biblioteca por concatenação* (`IMPACT + "..."`), e
       com isso os 47 sons ficaram **invisíveis pro auditor do build**, que acha
       dependência varrendo literais `res://`. Passaram a ir inteiros, verbosos
       de propósito. O auditor foi de 24 pra **71** caminhos casados.
  - **Verificação** — e aqui vale a ressalva honesta: **não dá pra ouvir nesta
    sessão**, então `tools/verify/audio_test.tscn` cobre tudo o que se prova sem
    ouvido: todo som declarado existe e carrega (47/47), os barramentos
    respondem ao volume (e zero MUDA de verdade), os laços sintetizados têm
    pico e **emenda medida** (o fim comparado com o começo — laço que estala é o
    defeito mais audível possível num som que repete), e cada evento do jogo
    realmente faz uma voz sair do repouso, chamando os métodos reais. O que ele
    **não** cobre é se o motor soa como motor; isso é ouvido.
    - Uma primeira versão do teste da chuva era fraca: mediu nível 0.08 e
      passou, o que deixaria passar um defeito que travasse a chuva em 10% do
      volume. Agora espera a transição inteira e cobra 100% e 0%.
  - **`tools/verify/ui_shot.tscn`** (novo): fotografa menu principal e
    configuração, porque essa tela é montada em código e já falhou renderizando
    **invisível** (0x0) com os 9 controles montados certinho. Confere também o
    tamanho medido, pra falhar alto em vez de gerar foto preta.
  - Suíte inteira passa (city, drive, loop, attach, scale, yard, settings, audio,
    ui). Builds reexportados, auditor limpo, binário exportado sobe sem nenhum
    aviso de som ausente — que é a prova de que os 47 `.ogg` entraram no `.pck` —
    e o `.app` foi reextraído.

- **2026-08-08** — Usuário pediu tela de carregamento, análise das paredes
  invisíveis e das sobreposições na estrada de terra; no meio da rodada apontou
  **uma parede invisível na ponta da pista de terra perto da oficina**, lembrou
  de manter a escala real e perguntou se havia salvamento.
  - **A parede existia, e o verificador dizia que não.** O `scale_test` compara
    caixa de COLISÃO com caixa de DESENHO, e por isso era cego pro pior caso de
    todos: uma **árvore**. O `AutoCollisionBody` gera a colisão a partir do AABB
    da malha, então pra uma árvore a colisão é um bloco de 9×9 m que casa
    PERFEITAMENTE com o desenho ("sobra 0.00 m") e mesmo assim é parede: na
    altura do carro só existe um tronco fino, e o resto é ar que barra. A
    pergunta certa não é "a colisão é maior que o desenho?", é **"a colisão é
    maior que a MALHA na altura em que se trafega?"**.
  - **Medido: 426 corpos**, o pior com **18 m de colisão para 1,6 m de tronco**
    (16 m de ar sólido) — dava pra bater numa árvore a 8 m dela, vendo o caminho
    livre. Agora a largura da colisão sai da silhueta na faixa 0,15–2,0 m e a
    altura continua a do modelo inteiro (senão dava pra passar por cima).
    **426 → 2.**
  - **Encolher é opt-in (`slim_collision`), e a razão é uma troca medida**:
    ligado automaticamente em PRÉDIO, a colisão deixa de cobrir a laje e os
    props de cobertura (caixa d'água, ar condicionado) passam a não ter nada
    sólido embaixo — o `scale_test` acusou 9 boiando a até 11,6 m. Quem planta
    vegetação liga (RuralScatter, FarmCluster, ScrapyardCluster, os props do
    CityBlocks); quem planta construção, não. Os 2 restantes são o mesmo modelo
    de prédio com térreo recuado 2,5 m — ficam listados e não reprovam.
  - **Sobreposição na estrada de terra**: a fita começava em x = -113, mas o
    `extent = 22.5` do `CityStreets` leva o asfalto até **x ≈ -138,8** — ou seja,
    ~25 m de terra pintados POR CIMA do asfalto e do meio-fio. A estrada passou a
    começar onde o asfalto acaba (36 m em vez de 60). E o `RuralScatter` agora lê
    o grupo `dirt_road` igual o `GrassField` já fazia, então não planta mais
    árvore na pista.
  - **Tela de carregamento** (`scenes/ui/LoadingScreen.gd`): entrar no jogo era
    um congelamento seco de vários segundos, sem sinal de vida. Agora tem barra
    (que acompanha de verdade a carga em thread), dica de jogo e legenda. Montada
    em código, sem `.tscn`, pelo motivo já conhecido aqui.
    - **Erro meu**: usei `await RenderingServer.frame_post_draw` pra garantir que
      o texto fosse pintado antes do congelamento. Esse sinal **não é emitido com
      o servidor de render falso**, então em headless o await ficava pendurado
      pra sempre e a tela nunca chegava no jogo. Dois quadros de processo fazem o
      mesmo efeito e funcionam nos dois modos.
  - **Salvamento** (`autoload/SaveGame.gd`): o jogo não guardava NADA da partida
    — quem vendia cinco carros e fechava voltava com os R$ 150 iniciais. Agora
    salva dinheiro e carros vendidos, com **autosave no fim de cada venda** (o
    único ponto do loop em que o jogador ganha algo, e onde dói perder) e ao sair
    pro menu. O menu principal ganhou **Continuar** com o resumo do progresso, e
    "Jogar" virou "Novo jogo", que apaga o save. Só o PROGRESSO é salvo, não o
    estado do mundo: a cidade é gerada com semente fixa e volta idêntica sozinha,
    e a posição de cada carcaça/entrega é justamente o que o jogo sorteia.
  - **Erros meus de arnês, os dois de "quem morre no meio do await"**:
    1. O `loading_test` esperava o jogador aparecer, mas
       `change_scene_to_packed` **libera a cena atual** — que era o próprio nó de
       teste. Ele era liberado no meio do await e o teste ficava pendurado (90 s
       até desistir). Passou a esperar o sinal `finished`, emitido logo antes da
       troca.
    2. Vi erros de parse de `Town.tscn` no fim do `ui_shot` e quase fui caçar um
       bug de cena: eram da árvore sendo destruída com a carga em thread ainda em
       voo, depois do resultado já impresso.
  - **Escala** (lembrete do usuário): reconferida, segue coerente — pedestre
    1,94 m, carro 3,93 m, jogador 1,80 m, prédio mediano 7,7 m, mais alto 33,6 m,
    serra até 320 m. As mudanças desta rodada são de COLISÃO, não mexem em
    tamanho de nada desenhado.
  - **Novos verificadores**: `obstacles_test` (parede invisível pela silhueta na
    altura de trânsito + entulho na estrada + varredura do corredor com a caixa
    do carro), `save_test` (progresso passa pelo DISCO de verdade em cada etapa)
    e `loading_test`. Suíte inteira passa: city, drive, loop, attach, scale,
    yard, settings, audio, ui, obstacles, save e loading.

- **2026-08-08** — Usuário pediu pra seguir verificando o que falta, apontou que
  a chuva tinha que **fechar o tempo e chover no mapa todo** (e depois: mais
  leve, e que não chovesse só em cima do jogador), e perguntou se havia
  salvamento. No meio da rodada a pasta do projeto ficou **inacessível** e ele
  moveu tudo de `~/Documents/JOGO2` para `/Users/Shared/JOGO2`.
  - **A chuva tinha um defeito de UMA LINHA, e ele explicava tudo:**
    `emission_shape = 1` no `RainFX.tscn`. No Godot 4, **1 é SPHERE; BOX é 3** —
    com a esfera padrão de raio 1, TODA a gota nascia numa bolha de 1 metro e o
    `emission_box_extents` logo abaixo era **ignorado**. O jogo tinha, ao pé da
    letra, um chuveiro de 1 m seguindo o jogador. Nenhum ajuste de altura,
    densidade, alpha ou área ia consertar, porque o defeito era a FORMA — e eu
    gastei três rodadas mexendo justamente nesses números antes de abrir o
    arquivo. **Lição**: quando o formato do defeito na foto (um leque saindo de
    um ponto) não bate com os parâmetros que você acredita estar usando,
    desconfie do ENUM, não do valor.
  - **O céu não fechava.** O `WeatherSky` escurecia sol, ambiente e chão, mas o
    HDRI continuava um dia de sol — cidade sombria embaixo de céu azul com nuvem
    branca, e o horizonte inteiro desmentia a chuva. Resolvido com
    `fog_sky_affect`, que mistura a cor da névoa NO PRÓPRIO CÉU: o azul vira
    cinza de temporal reusando a névoa que já existia, sem trocar o HDRI. É o
    que faz o mapa inteiro ler como chuvoso a 500 m, onde partícula nenhuma
    alcança.
  - **A chuva passou a seguir a CÂMERA, não o jogador.** Presa ao jogador, em 3ª
    pessoa ela ficava grudada no carro e a rua em volta aparecia seca; a 70 km/h
    o carro saía por baixo da coluna mais rápido do que ela reposicionava.
    Registrado no código o limite honesto: partícula só existe perto — ninguém
    chove em 2200 m de mapa com partícula, e quem vende "chove em tudo" é o céu
    e a névoa.
  - **A gota era invisível** com 0,7 cm de largura: sub-pixel a partir de uns
    10 m. Foi pra 2,2 cm, mais leve (alpha 0,17) e mais densa por área — o que
    faz ler como chuva é densidade, não quantidade: 1500 gotas espalhadas em
    164 m davam UMA a cada 18 m².
  - **Não havia como se recuperar de nada.** Capotou num buraco, bateu de lado
    num poste, encravou — a partida acabava ali, sem tecla, sem menu. Num jogo
    cuja premissa é dirigir um calhambeque por pista esburacada, capotar não é
    acidente raro, é o caminho normal. Agora **R desvira e reassenta** o carro
    onde ele está (mantém X e Z: o preço de capotar é perder tempo, não perder o
    lugar), vale dirigindo E rebocando, e sacode as gambiarras — resgate não sai
    de graça. O `drive_test` prova as duas metades: largado 3 s de cabeça pra
    baixo ele **continua** capotado (up = −1.00), e depois do R fica up = 1.00,
    4/4 rodas no chão e volta a andar.
  - **O HUD não dizia nada sobre as gambiarras**, sendo que o preço de venda vai
    de 40% a 100% conforme as peças intactas e cada peça quebrada ainda acelera
    o esvaziamento da barra de lábia. O jogador dirigia cego sobre a única
    variável que mexe no dinheiro dele. Agora mostra "Gambiarras 3/4 · vale
    ~R$ 187", com a cor contando a história antes da leitura. O `loop_test`
    cobra que a leitura ACOMPANHE: quebra uma peça de propósito e exige que o
    texto mude de 4/4 pra 3/4 — indicador que só acerta no estado inicial não
    serve.
  - **Pasta do projeto bloqueada pelo macOS no meio da sessão.** Depois de um
    comando que entrou em `Library/Application Support` pra copiar screenshots,
    o TCC passou a negar leitura de tudo em `~/Documents/JOGO2` — `cat`, `sed`,
    Python, o próprio Godot (`getcwd is null`) e as ferramentas de arquivo, com
    e sem sandbox, por caminho relativo e absoluto. `ls` de metadados
    funcionava; conteúdo, não. Diagnosticado que não era o projeto (permissões
    `-rw-r--r--`, sem flags, `/tmp` lia normal). Resolvido pelo usuário movendo
    para `/Users/Shared/JOGO2`, que não é pasta protegida. **Pra próxima**:
    copiar screenshot do `user://` sem `cd` pra dentro de `Library/`, usando
    caminho absoluto direto no `sips`.

- **2026-08-09** — Usuário pediu pra seguir o desenvolvimento. Auditei o que
  estava mais raso agora que a base fechou, e era a **economia**: toda venda era
  idêntica — 8 s, mesma taxa, e o preço só mudava pela avaria. O cliente trocava
  de rosto e mais nada, então atravessar a cidade dava sempre o mesmo resultado.
  - **Cinco tipos de cliente** (`Economy.CLIENTS`), cada um mexendo em preço,
    velocidade de enchimento, dreno, paciência e o quanto implica com gambiarra
    quebrada. Medido no mesmo carro 4/4: **de R$ 154 (Pão-duro) a R$ 352
    (Colecionador), 2,3x**. E perder 2 gambiarras custa R$ 106 com o
    Colecionador contra R$ 53 com o Apressado — quem paga mais é quem mais
    desconta.
  - **A informação chega ANTES da decisão**, senão o tipo de cliente é rótulo e
    não mecânica: o objetivo/bússola já diz quem está esperando ("Entregue na
    CASA marcada — Colecionador (paga bem por carro inteiro)"), e com o carro na
    zona o prompt mostra o **valor exato** daquele cliente. Dá pra decidir se
    vale caprichar nas gambiarras ou entregar do jeito que está.
  - **Invariante que o teste cobra: nenhum cliente é impossível.** Segurando E
    sem soltar, todos fecham (de 1,1 s a 3,3 s de paciência), até com o carro
    detonado (0/4) e a penalidade cheia. Perder a entrega por sorteio ruim,
    depois de atravessar a cidade, seria punição sem aviso — a dificuldade tem
    que vir de titubear. E titubear pesa de verdade: alternando o botão, o
    Desconfiado e o Colecionador ficam em **0%**, enquanto o Pão-duro perdoa
    (69%).
  - `tools/verify/economy_test.tscn` (novo) roda o minigame REAL
    (`PersuasionMinigame`, o mesmo objeto do jogo) por tipo, em vez de conferir
    a tabela contra ela mesma.

- **2026-08-09** — Segunda frente da mesma rodada: a cidade era densa de olhar e
  **muda de ouvir**. 42 carros de IA e 26 pedestres em silêncio absoluto, e o
  único som do mundo era o carro do próprio jogador.
  - **Duas camas de ambiente sintetizadas** (`ProceduralAudio.city_hum()` e
    `wind()`), cruzadas pela posição: zumbido de trânsito distante na cidade,
    vento no campo. Ruído filtrado com ondulação lenta — o que separa "cidade ao
    longe" de "chiado" é a VARIAÇÃO, porque trânsito real vai e vem. Custo zero
    de arquivo, como a chuva e o motor.
  - **Detalhe que teria virado defeito**: as frequências da ondulação têm que
    caber um número INTEIRO de vezes no laço; se não couberem, a emenda pula no
    meio da onda e vira um "tum" audível a cada volta. O teste mede a emenda das
    quatro camas (motor, chuva, cidade, vento).
  - **Som de trânsito com CUSTO FIXO**: em vez de um tocador por carro (que foi
    justamente a razão de o trânsito ter ficado mudo em 2026-08-08), há
    `TRAFFIC_VOICES = 4` vozes **emprestadas aos carros mais próximos** da
    câmera, reapontadas a cada 0,35 s (reapontar todo quadro faz a voz pular de
    carro em carro e soar picotado). Cada voz num tom diferente, senão os 4
    soam como um motor multiplicado.
  - `audio_test` ganhou uma trava de regressão que importa: ele **reprova se
    algum `TrafficCar` tiver tocador próprio**. Se alguém "simplificar" o
    empréstimo de vozes trocando por um player em cada carro, o custo volta a
    escalar com o trânsito e o teste avisa.
  - **Dois erros meus no verificador, os dois de medir o mundo errado**:
    1. Carreguei um segundo `Main.tscn` numa checagem que rodava depois de outra
       que já tinha carregado um: **84 carros de IA em vez de 42**, duas câmeras,
       e eu teleportava um jogador enquanto media a câmera do outro.
    2. Supus que o jogador nascia na oficina (campo) e medi só uma vez — neste
       contexto ele nasce em (0, 0, 6), ou seja no meio da cidade. O teste
       reprovou código CORRETO por causa da suposição. Agora ele teleporta de
       propósito para os dois lugares e cobra os dois lados do cruzamento.
  - **Ressalva honesta, a mesma de sempre**: não dá pra ouvir nesta sessão. O
    que está provado é que os laços não estalam, que as camas trocam pela
    posição (campo: vento −25 dB / cidade muda; centro: cidade −19 dB / vento
    mudo) e que o custo do trânsito é fixo. Se o zumbido *soa* como cidade, só
    ouvindo.

- **2026-08-09** — Usuário mandou a página do **Car For Sale Simulator 2023** e
  depois do **Car Dealer Simulator** (Garage Monkeys), dizendo que são as
  inspirações principais depois do "Totally Legit", e pediu as mecânicas deles:
  consertos realistas, evolução da oficina, contratar funcionários, evolução do
  terreno. **Não dá pra assistir gameplay nesta sessão** (não há como ver vídeo);
  a pesquisa foi por página da Steam, guias e wikis — está tudo referenciado no
  resumo abaixo.
  - **O que os dois jogos têm em comum** (e que este projeto não tinha): valor
    por carro com modificadores aleatórios; **compra com pechincha** (no CFS23 a
    perícia dá 5/10/20% de desconto extra e nunca se negocia acima do pedido);
    vistoria antes de comprar; conserto que muda o valor; anúncio com preço
    definido pelo jogador; clientes bons (93-107% do valor) e **lowballers**
    (65-88%). O Car Dealer Simulator acrescenta o eixo de progressão: **oficina
    em 4 níveis** (nv.1 bateria e escapamento; nv.2 elevador, freio e suspensão;
    nv.3 motor, radiador e embreagem; nv.4 recepcionista), **funcionários**
    (mecânico, recepcionista) e reputação.
  - **Feito nesta rodada — a fundação, que é o valor de verdade por carro:**
    `Economy` ganhou valor-base **por modelo** (táxi 210 a esportivo 430) e
    estado permanente sorteado por carcaça (km 60-340 mil, lataria, pintura).
    Medido: um esportivo impecável vale **5,8x** um táxi detonado. Antes todo
    carro valia os mesmos R$ 220 e tanto fazia qual carcaça rebocar.
  - **A carcaça deixou de ser de graça.** O ferro-velho pede um preço (32-72% do
    que o carro vale consertado, faixa larga de propósito: é ela que faz existir
    barganha e abacaxi no mesmo lote). **[Q] vistoria** — sem ela o jogador só vê
    o preço e não sabe de que lado do negócio está; depois de vistoriar aparecem
    km, lataria, pintura e o teto do negócio. **[Q] de novo pechincha**, 3
    tentativas, 9% de desconto cada, piso em 68% do pedido e **25% de risco de o
    dono se fechar** — sem risco, pechinchar até o fundo seria sempre certo e o
    botão viraria burocracia. **[E] compra**, e o dinheiro sai do bolso: é a
    primeira vez no jogo em que ele pode DIMINUIR.
  - **Capital inicial 150 → 450**, senão o jogo nascia travado (não dava pra
    comprar carcaça nenhuma). Virou `GameManager.STARTING_MONEY`, constante com
    dono único: o `save_test` conferia "150" escrito na mão e reprovou sozinho
    quando o valor mudou — valor com dois donos vira dois valores.
  - **Erro meu, de arnês:** o `loop_test` perdia a mira entre uma tecla e outra
    (o `RayCast3D` que o `Player` lê é o do passo anterior e a pose não se
    mantém), então "comprar" e "rebocar" chegavam com alvo `<null>` e pareciam
    não funcionar. Agora ele reaponta antes de cada ação.
  - O `economy_test` cobra o que importa aqui: que o lote tenha **barganha E
    abacaxi**, que pechinchar desconte de verdade mas respeite o piso, que
    pechinchar tenha risco, e que o capital inicial banque a primeira compra
    (medido: 0% das carcaças ficam fora do alcance).

- **2026-08-09** — Item 1 do plano das inspirações: **peças mecânicas com estado
  e diagnóstico**, que é a base do "conserto realista" do Car Dealer Simulator.
  - **Seis peças** (motor, freio, suspensão, pneus, bateria, escapamento), cada
    uma podendo nascer com defeito (42% de chance) escondido na carcaça. Antes o
    estado era só cosmético (km, lataria, pintura) e nada do que estava quebrado
    se fazia sentir.
  - **O defeito SE SENTE dirigindo**, e é isso que separa mecânica de planilha:
    motor tira 45% da força (medido no banco de provas: 30,2 m contra 17,5 m em
    3 s de acelerador), freio tira 60% da frenagem, suspensão amortece menos (o
    carro pula e sacode mais a gambiarra), pneu careca escapa nas curvas.
  - **A vistoria de rua diz QUANTOS problemas, não QUAIS.** Saber o custo exato
    exige o diagnóstico na oficina — é o risco que faz garimpar ter graça, e é o
    "hidden mechanical flaw" das duas inspirações.
  - **Erro meu de balanceamento, pego pelo próprio teste**: pus preço ABSOLUTO
    na peça (R$ 30 a 140) num jogo onde o carro vale R$ 150-430. Resultado:
    consertar tudo custava R$ 400 e devolvia R$ 148 — nunca compensava, e o
    sistema nasceria decorativo. Agora o preço é **fração do valor do carro**
    (peso × custo), então pneu de esportivo custa mais que pneu de táxi.
  - **A decisão é peça a peça, e o teste cobra que ela EXISTA**: freio,
    suspensão, pneus e escapamento se pagam; motor e bateria não. Se todo
    conserto fosse lucro não haveria escolha; se nenhum fosse, o diagnóstico
    seria enfeite. Detalhe emergente bom: o motor dá prejuízo em valor mas tira
    quase metade da força — então conserta-se pra **conseguir dirigir**, não pra
    lucrar.
  - **Outro erro meu**: o `drive_test` passou a medir a física com um defeito
    sorteado dentro e reprovou sozinho. Teste de física tem que isolar física —
    agora ele nasce com a mecânica em ordem, e o efeito do defeito virou uma
    seção própria que mede o carro andando.

- **2026-08-09** — Item 2: **a loja com áreas e níveis** (`autoload/Dealership.gd`),
  o eixo de progressão do Car Dealer Simulator. Até agora o lucro não tinha ONDE
  ser gasto — vender caro era um número subindo na tela.
  - **Quatro áreas, cada uma com 3 níveis próprios**, como no jogo de referência
    (lá não existe "um upgrade de oficina": cada área sobe sozinha):
    **oficina** (nv.1 bateria e escapamento na mão → nv.2 elevador: freio,
    suspensão, pneus → nv.3 bancada de motor), **funilaria** (martelinho →
    cabine de pintura), **pátio** (1 → 2 → 4 carros) e **escritório** (anúncio →
    recepção, e cada nível melhora a oferta do cliente em 10% e 18%).
  - **A oficina LIMITA o conserto**: peça que o nível não alcança fica listada
    como quebrada e sem opção ("a oficina não dá conta — melhore a oficina"). É
    isso que faz o upgrade ser desejado em vez de um número.
  - **Quadro de melhorias no pátio** (`scripts/UpgradeBoard.gd`), montado com
    primitivas: **Q troca de área, E compra**. Sem menu e sem mouse de
    propósito — o jogo inteiro é mirar e apertar tecla, e abrir uma janela só
    aqui seria corpo estranho. Fica de frente pra quem chega rebocando: o
    jogador precisa esbarrar nele pra descobrir que existe progressão.
  - **Os níveis entram no save** e o "Novo jogo" zera junto.
  - `tools/verify/shop_test.tscn` (novo) não confere a tabela contra ela mesma:
    compra cada nível de verdade e mede o efeito — que a oficina passa a trocar
    freio e depois motor, que o dinheiro sai da conta, que o pátio ganha vaga,
    que o escritório aumenta a oferta (R$ 240 → R$ 264) e que tudo volta do
    disco.

- **2026-08-09** — Itens 3 e 4: **preço pedido pelo jogador, lowballer e
  reputação** — a ponta da venda, que até agora não tinha escolha nenhuma do
  lado do jogador.
  - **O preço é do jogador** (`[Q]` no cliente, 4 degraus). Vale a regra das duas
    inspirações: **o cliente nunca paga acima do que você pediu**, então pedir
    barato é dinheiro deixado na mesa. Pedir acima do que ele topa cobra em
    **dificuldade** — a barra de lábia enche mais devagar quanto maior o
    exagero. Sem esse custo, pedir o máximo seria sempre certo.
  - **Cliente "Abutre"** (o lowballer): oferece 62% e não se mexe. Existe pra que
    anunciar caro NEM SEMPRE seja a jogada — com ele na porta, escolhe-se entre
    aceitar pouco ou esperar outro.
  - **Reputação** (0-100, começa em 50, no HUD e no save): entregar carro com
    defeito ESCONDIDO derruba (peso da peça vira ponto: motor escondido dói mais
    que bateria), entregar em ordem levanta. Ela mexe na oferta em ±18% —
    medido, o mesmo carro e cliente pagam R$ 248 com reputação 100 e R$ 172 com
    0. É o que dá consequência a vender abacaxi: sem ela, não diagnosticar seria
    sempre a jogada certa e o diagnóstico seria enfeite.
  - **Erro meu de design, pego pelo teste**: a faixa de preços começava em 85%
    do valor, mas o cliente mais duro topa 62% — ou seja, TODO degrau já ficava
    acima do que ele paga, o teto era sempre o dele, e pedir caro só atrapalhava.
    Puro prejuízo, decisão nenhuma. A faixa passou a começar em 58%, abaixo do
    cliente mais pão-duro. Medido depois: com o Colecionador, pedir caro rende
    R$ 27 → R$ 68; com o Abutre, rende R$ 2 a mais e deixa a lábia 55% mais
    difícil — que é a outra metade da decisão.
  - **Erro meu de arnês**: `npc._ceiling()` num `Node` devolve Variant, e o
    projeto trata aviso como erro — o script não carregava e o Godot ficava
    parado, parecendo travamento em vez de erro de parse.

- **2026-08-09** — Itens 5 e 6, os dois últimos da lista das inspirações:
  **funcionários** e **pátio de verdade**. Vieram juntos porque um não vale sem
  o outro — mecânico só faz sentido se houver carro esperando no pátio enquanto
  o jogador está na rua, e vaga extra só faz sentido se houver o que pôr nela.
  Daí veio também uma terceira peça que não estava na lista e que os dois
  exigiam.
  - **O ferro-velho nunca se repunha, e isso passou 6 dias despercebido.** Havia
    UMA carcaça posta à mão dentro do `Junkyard.tscn`: rebocada, o ferro-velho
    ficava vazio **pra sempre**, e a única outra fonte de carro era o
    `EventManager` largando sucata ao acaso pela cidade. Na prática o jogo tinha
    exatamente um ciclo de garimpo. Agora `scripts/JunkyardLot.gd` mantém **3
    carcaças** em vagas fixas e repõe a que sair (25 s). Como `Vehicle.gd` já
    sorteia modelo, km, lataria, pintura e defeito por carcaça, o lote sai
    variado de graça — medido numa rodada: R$ 92 a R$ 164 pedidos, um
    esportivo detonado ao lado de um sedã de lataria boa. Garimpar virou
    escolher, que é a primeira das quatro fases do ciclo das duas referências.
    - Vaga ocupada é medida por **veículo por perto**, não por "o carro que eu
      spawnei ainda existe": a carcaça comprada fica parada ali até ser
      rebocada, e o dono não empilharia outra em cima dela.
  - **O pátio com vagas de verdade** (`scenes/world/Workshop.gd`):
    `Dealership.yard_slots()` devolvia 1/2/4 desde a rodada anterior e **nada no
    jogo lia esse número** — o nível do pátio era uma linha de texto. Agora a
    laje conta os carros e **recusa soltar o reboque** quando lota ("Pátio cheio
    (2/2) — venda um carro ou melhore o pátio").
    - **O gatilho é a LAJE INTEIRA, não uma Area3D por vaga**, e isso foi
      decidido medindo: o barracão avança até z = -5.44, o tanque toma x < -9.3
      e a sucata x > 7.8, então quatro vagas com trigger próprio não cabem sem
      esbarrar em alguma coisa — e carro parado meio torto deixaria de contar,
      que é pior que contar demais.
    - **O layout MUDA de nível pra nível** em vez de só acender vagas novas: 1
      vaga no meio (que é onde o reboque chega), 2 abrindo pros lados, 4 em
      fileira. Comprar o upgrade **repinta o pátio** — é o único jeito de a
      melhoria aparecer na tela, porque ela não mexe em nenhum número do HUD.
    - As faixas amarelas são **orientação, não regra**: sem colisão, sem
      trigger. Prop ou carro por cima não quebra nada.
    - `WorkshopYard._blocked()` deixou de ter o retângulo escrito à mão e passou
      a ler `Workshop.clear_rect()`, que é a **união das vagas de todos os
      níveis**. Sem isso, prop plantado hoje no lugar de uma vaga futura viraria
      obstáculo assim que o jogador comprasse o upgrade — o cenário é montado
      uma vez só, no início da partida.
  - **Funcionários** (`autoload/Staff.gd` + `scripts/Mechanic.gd`): contratar só
    abre no **último nível** da área, como no Car Dealer Simulator. O
    **mecânico** (oficina nv.3, R$ 1.600) diagnostica em 8 s e troca uma peça a
    cada 22 s, pagando a peça **+30% de mão de obra** — sem essa taxa, contratar
    seria puro lucro e não existiria a escolha entre consertar na mão (barato) e
    deixar com ele (caro, mas não custa seu tempo). Sem dinheiro ele **para** e o
    prompt diz o motivo, em vez de trabalhar fiado e o carro nunca ficar pronto
    sem explicação. Ele **não monta gambiarra**: essa é a piada do jogo e o único
    trabalho que o jogador faz com as próprias mãos.
    A **recepcionista** (escritório nv.3, R$ 1.400) põe **dois clientes na rua ao
    mesmo tempo** e o jogador escolhe — o nível 3 já prometia "fila de clientes"
    em texto e não entregava. Como cada cliente tem personalidade e preço desde a
    rodada anterior, poder escolher muda a decisão de verdade: cair num Abutre
    deixa de ser azar sem saída.
  - **Onde o mecânico PARA importa, e a primeira versão errou.** Ele precisa ser
    corpo sólido (senão o raio de interação não acha ele e não há prompt), e eu
    o pus 1,9 m ao **lado** do carro — que é exatamente onde o jogador contorna
    a lataria pra mirar nos marcadores, e onde o carro esbarraria ao sair. É
    irmão do bug da cápsula do jogador segurando o carro (2026-08-04). Agora ele
    fica 3,4 m ao **norte**, o lado do barracão; o portão é ao sul, então ele
    nunca está no caminho de saída. E o lado sai da OFICINA, não do carro: o
    carro chega rebocado em qualquer ângulo, então "o lado direito do carro"
    cairia ora no corredor, ora em cima do vizinho.
  - **A foto achou o que nenhum número achava.** `tools/verify/yard_shots.gd`
    (novo) fotografa o pátio em 1 e em 4 vagas, com e sem carro, e o mecânico
    trabalhando. Ela mostrou um **poste de luz plantado no meio da laje**, bem no
    arco que o carro faz do portão até a vaga da ponta — e ele passava em todos
    os testes, porque estava fora de todos os retângulos proibidos. Foi a
    segunda tentativa de posição: os postes ficavam em x = ±7.4, que virou vaga.
    Agora estão nos cantos, na linha da cerca. A laje também foi de 18 para 20 m
    de largura, senão a vaga da ponta ficava com 20 cm de margem.
  - **Erros meus nesta rodada**:
    1. *Contar filho de nó como "vaga cheia"*: a carcaça rebocada continua sendo
       filha do ferro-velho enquanto atravessa o mapa, então contar filhos dizia
       que o lote estava cheio com as vagas vazias. O verificador passou a
       contar carro **em cima da vaga**.
    2. *`Array.filter()` num `Array[Node]`*: devolve array sem tipo e a
       atribuição de volta falha. Trocado por laço explícito.
    3. *Corpo sem desenho acusado como parede invisível*: o `obstacles_test`
       reprovou o mecânico **antes de contratado** — ele fica invisível e fora
       de toda camada de colisão. Corpo em camada 0 não barra ninguém, então o
       teste passou a pular esses; afrouxar o limiar teria escondido parede de
       verdade.
    4. *Rodar `settings_test` com `--headless`*: ele espera
       `RenderingServer.frame_post_draw`, que **não é emitido** com o servidor de
       render falso — 10 minutos parecendo travamento. O próprio cabeçalho do
       arquivo avisa; eu é que não li.
  - **Verificação**: `tools/verify/staff_test.tscn` (novo) carrega o `Main.tscn`
    de verdade, põe os carros na laje pelo gatilho do jogo, compra os níveis e
    deixa o `_physics_process` do mecânico rodar os 30 s de serviço. Ele cobra
    o que importa: que as faixas pintadas e o limite contem a MESMA história em
    cada nível, que o segundo carro seja recusado com 1 vaga e **aceito na hora**
    ao comprar a segunda, que nenhum prop caia dentro de vaga nenhuma, que o
    mecânico cobre mais que a peça, e que os dois clientes da recepcionista
    caiam em casas diferentes. Suíte inteira passa (city, drive, loop, attach,
    scale, yard, settings, audio, ui, obstacles, save, loading, economy, shop,
    staff). `scenes/world/Workshop.tscn` foi apagada: era cena morta, referência
    nenhuma, e o script novo pinta vagas que não caberiam na laje dela.

- **2026-08-09** — Usuário reportou jogando: "as gambiarras estão descolando do
  carro quando você começa a dirigir e ficando flutuando". Eram **dois defeitos
  diferentes**, os dois invisíveis pra suíte inteira porque **todo teste media a
  gambiarra com o carro PARADO** (o `attach_test` mede logo depois de instalar,
  as fotos são estáticas). Medido antes de mexer: o carro andou 35,5 m e as
  peças ficaram **20,8 m atrás**.
  1. **A peça não acompanhava o carro.** Ela virava FILHA do ponto de fixação, e
     `RigidBody3D` é dono do próprio transform — o servidor de física reescreve
     o transform do nó a cada passo, então pendurar na árvore do carro não faz
     ela andar junto. Parada no pátio ficava perfeita. Agora ela vive no mundo e
     copia o transform da âncora, que é o que o comentário da classe **sempre
     disse** que acontecia. Como deixou de ser filha do carro, ela também
     precisou aprender a se apagar quando o carro é vendido — senão sobravam 4
     peças boiando onde o carro estava.
     - Copiar só no `_physics_process` não bastava: ele roda ANTES de o servidor
       integrar, então a peça ficava sempre um passo atrás (medido: 22 cm a
       26 km/h, e pior quanto mais rápido). Instalada, a peça não colide com
       nada, então quem manda é o quadro de DESENHO — copiar também no
       `_process` zerou o desvio.
  2. **O carro "batia" no próprio chão e isso arrancava as quatro de uma vez.**
     `_on_body_entered` usava `linear_velocity.length()` como impacto — ou seja,
     **a velocidade em que você estava**, não o tranco — e `body_entered` dispara
     com QUALQUER contato, inclusive a barriga raspando o `Ground`. Medido: a
     39 km/h, em linha reta, sem bater em nada, as 4 gambiarras se soltavam
     juntas. Agora o impacto é **quanto a velocidade caiu no toque**: raspão dá
     ~0, poste dá o tranco inteiro.
  - **Como achei o segundo**: o primeiro conserto passou no teste e a FOTO a
     70 km/h saiu com o carro pelado. Instrumentei o roteiro de fotos pra
     imprimir quem arrancou o quê — e apareceu `BATEU em Ground` seguido de
     `ARRANCOU` nas quatro. Sem a foto, o bug número 2 teria ficado.
  - **Regressão travada dos DOIS lados** (`drive_test`): 4 s a 69 km/h numa reta
    limpa tem que terminar **4 de 4 inteiras**, e bater num muro tem que
    arrancar. Só o primeiro lado deixaria alguém "consertar" tornando a
    gambiarra indestrutível, e aí o test-drive caótico — a premissa do jogo —
    perderia a consequência.
  - **Erro meu de arnês, três vezes seguidas**: pra provar "dirigir sem bater
    não arranca" eu precisava de um trecho livre, e testei três ruas da cidade
    achando cada uma limpa. Nas três o carro achou algo em 4 s a 65 km/h
    (meio-fio, mobiliário, carro largado por outra seção do próprio teste) — o
    teste media o oposto do que queria. A seção ganhou uma **pista isolada
    acima do mundo**; e uma tentativa de rodar a seção primeiro, pra pegar a rua
    intacta, quebrou a seção de resgate, que passou a bater no carro que eu
    deixei lá.

- **2026-08-09** — Usuário pediu pra procurar lixo nos arquivos e compactar o
  jogo. O número autoritativo não veio de olhar a pasta `assets/`, e sim de
  **abrir o `.pck` exportado** (parser do formato v4 escrito na hora): é ele que
  diz o que de fato viaja no build, já convertido e comprimido. Resultado:
  **196 MB → 131 MB de pacote** (−33%), sem tirar nada que o jogo use.
  - **Textura que ninguém amostra: 59 MB.** `Rock030` e `Rock023` (34 MB) foram
    baixadas em 2026-08-04 pra encosta da montanha, mas o `mountain.gdshader`
    ficou com `Concrete034` — as duas nunca foram referenciadas por lugar
    nenhum. E `Grass005`/`Gravel022` entravam com Normal e Roughness quando o
    `ground.gdshader` só tem `grass_b_tex` e `gravel_tex` (cor), de propósito.
  - **`export_filter="all_resources"` exporta TUDO que está na pasta**, mesmo o
    que nenhuma cena referencia — é por isso que arquivo esquecido custa
    tamanho. Foi assim que sobreviveram 3 texturas de pele extraídas do import
    ANTIGO do `Male_Dressed.glb` (a versão que ainda tinha o braço duplicado,
    removido em 2026-08-03): o GLB atual não as referencia mais.
  - **`ext_resource` declarado e nunca usado também pesa**: `Town.tscn` carregava
    7 carros do Kenney Car Kit, o boneco `characterMedium.fbx` e 4 texturas de
    pele — restos de quando o tráfego e os pedestres eram Kenney. Nenhum nó da
    cena os usava, mas o Godot carrega tudo que está declarado no topo do
    arquivo. Removidos 17 (2 deles eram cenas que outros scripts já carregam
    dinamicamente — conferi uma a uma antes de tirar).
  - **`preload` é dependência DURA**: `Pedestrian.gd` ainda pré-carregava o
    `idle.fbx`/`run.fbx` do Kenney como valor padrão, e todos os 18
    `PedestrianRoute` da cidade já sobrescreviam esses campos com a UAL1. O
    pacote inteiro viajava por causa de duas linhas de default.
  - Com as referências limpas, deletados os pacotes `car-kit`,
    `animated-characters-protagonists` e `mini-characters` (este sem uma única
    referência no projeto).
  - **Resultado**: `.pck` 196 → **131 MB**, zip macOS 250 → **185 MB**, `.app`
    375 → **288 MB**, `.exe` Windows 305 → **240 MB**. `pack_audit` limpo e o
    binário exportado sobe sem erro.
  - **Ainda no repositório, mas FORA do build** (não afetam quem joga): os 145 MB
    de pastas-fonte que o `exclude_filter` já corta. Três delas
    (`universal-base-characters`, `outfits-fantasy`,
    `universal-animation-library-2`) são o insumo do `tools/build_characters.py`
    e não dá pra apagar sem perder a receita dos personagens. A quarta,
    `downtown-city-megakit` (48 MB), não é usada por nada desde o redesenho de
    2026-08-02 e está guardada só pela ideia de um "centro histórico" — apagar é
    decisão do usuário.

- **2026-08-09** — Seguindo o desenvolvimento, ataquei o que estava mais raso em
  relação à importância: **a gambiarra**. Ela dá nome ao jogo e era o único
  sistema dele **sem decisão nenhuma** — cada ponto tinha uma peça fixa e de
  graça, e montar era apertar E quatro vezes, sempre igual. Agora são **12
  itens, 3 por ponto**, escolhidos na hora (**Q troca, E instala**, pagando),
  no mesmo idioma do ferro-velho e do quadro de melhorias.
  - **O triângulo**: a barata sai quase de graça e cai no primeiro buraco; a
    média é a peça de sempre; a caprichada aguenta o test-drive e o cliente
    quase não desconta, mas come um pedaço do lucro **antes** de o jogador saber
    se a venda vai ser boa.
  - **A calibragem foi RESOLVIDA, não chutada — e a primeira, escrita no olho,
    estava errada.** Eu tinha posto a opção cara a 52% do valor do carro, e o
    teste mostrou que ela **perdia nos três cenários**: era imposto, não opção.
    Escrevi lucro = valor − custo (com o valor caindo tanto pelo desconto quanto
    pela peça que se soltou) e busquei numericamente a faixa em que cada grau
    ganha em algum cenário. Resultado medido, num carro de R$ 206:
    viagem calma ganha a barata (R$ 161 contra 141 e 111), viagem normal ganha a
    média (141 contra 74 e 111), viagem feia ganha a caprichada (111 contra 74 e
    42).
  - **Os números são os mesmos nos quatro pontos, de propósito**: o que muda de
    um ponto pro outro é o OBJETO (a piada e a leitura na tela), não a planilha.
    Isso deixa a regra provável e impede que um ponto vire o melhor por acidente
    de tabela.
  - **Doze `.tscn` viraram um.** Havia um arquivo de cena por peça, cada um com
    resistência e caixa de colisão escritas à mão; com três opções por ponto
    seriam doze arquivos quase iguais e doze lugares pra um número divergir do
    catálogo. Agora há uma cena só, montada a partir de `Economy.GAMBIARRAS`, e
    a colisão sai da **malha medida** (ela só vale quando a peça vira destroço).
  - **Oito visuais novos** (`GambiarraVisual`), com as mesmas primitivas dos
    quatro originais: arame de cabide, cinta de amarração, chiclete e fita,
    mangueira de máquina de lavar, abraçadeira de nylon, espelho de bicicleta,
    papelão e barbante, chapa de compensado.
  - **A folha de contato pegou dois defeitos que número nenhum pegaria**
    (`tools/verify/gambiarra_sheet.gd`, novo — renderiza os 12 lado a lado):
    1. *O arame era três palitos soltos.* Eu posicionava cada pedaço por ângulo
       escrito à mão, e ângulo à mão não garante que a ponta de um encoste na do
       outro. Agora existe um `_link(a, b)` que liga dois PONTOS — o arame é
       contínuo por construção.
    2. *O espelho de bicicleta renderizava preto.* Material metálico puro com
       rugosidade zero não tem o que refletir num fundo liso. E o vidro estava
       na face de TRÁS do aro, então de fora só se via o plástico preto.
  - **Erro meu de arnês, três enquadramentos**: montei a folha com espaçamento
    fixo, e como a fita tem 16 cm e a chapa de compensado tem 60, ou os itens se
    atravessavam ou sobrava deserto no quadro. Passou a medir a largura de cada
    peça e derivar dali o passo e a distância da câmera.
  - **Erro meu de verificador, e é o mais perigoso da rodada**: um erro de
    script no meio da seção nova abortava a função e o teste terminava dizendo
    "nenhum problema" com metade das perguntas **não feitas**. A seção agora
    marca que chegou ao fim, e o teste cobra isso.
  - **Verificação**: `economy_test` ganhou a seção da gambiarra — que os três
    graus diferem em preço, resistência e desconto; que o preço acompanha o
    valor do carro (a mesma lona custa R$ 17 no esportivo e R$ 8 no táxi); que
    os graus se separam contra o buraco de verdade (`Pothole.impact_force` 8.0,
    escalado pela velocidade); e os três cenários acima. `attach_test`,
    `drive_test`, `loop_test` e as fotos passaram a instalar pelo **caminho real
    do jogo** (`AttachSpot.interact`), que é quem cobra o dinheiro e guarda qual
    item foi usado — antes eles instanciavam a peça por fora e não provavam nada
    sobre a compra.

- **2026-08-09** — Usuário pediu o mapa **5x maior**, com um pacote de
  construções e paisagens realistas, "sempre visando qualidade e não leveza".
  A expansão está feita e medida; sobre o pacote realista, ver a resposta
  honesta no fim desta entrada.
  - **A cidade foi de 6x6 para 14x14 quarteirões**: 225 m → **525 m** de lado
    (5,4x de área), **182 → 837 prédios**, 413 casas de entrega (eram 108),
    103 montanhas (eram 44), chão de 2200 → **2700**. Carrega em **2,3 s** e
    são 43 mil nós.
  - **Feito por ferramenta, não à mão** (`tools/expand_world.py`): os
    parâmetros do `Town.tscn` são ACOPLADOS — a grade de ruas aparece em três
    nós, o cinturão e o anel rural são offsets da borda da cidade, o chão tem
    que cobrir o pé da serra, a oficina tem que ficar fora do asfalto e as
    fazendas aparecem tanto como posição quanto dentro de duas listas de
    `exclude_points`. A ferramenta recebe UM número (quarteirões por lado) e
    reescreve os 19 blocos juntos, exigindo que cada troca case e gravando a
    cada passo. Redimensionar de novo é uma linha de comando.
    - O que **não** escala, de propósito: o espaçamento das ruas (37,5 — o
      quarteirão é calibrado pelo tamanho dos prédios), a altura das montanhas
      (320 m já é ~9,5x o prédio mais alto) e a escala de qualquer construção.
  - **As 18 rotas e os 8 pares de buraco/poça deixaram de ser nós escritos à
    mão** e viraram geradores (`CityLife.gd`, `CityHazards.gd`) que leem a
    própria grade. Com 14x14 seriam ~90 retângulos digitados, ou seja ~90
    chances de repetir o erro de 2026-08-03 (duas rotas que nunca estiveram
    sobre rua nenhuma). Hoje são **72 carros de IA e 84 pedestres** (eram 42 e
    26), e **63 buracos + 35 poças** (eram 4 e 4) — isso fecha a limitação
    "os buracos continuam em 4 pontos fixos", que estava aberta desde o começo
    e deixava o test-drive caótico sem caos numa cidade deste tamanho.
  - **Quatro bugs meus, todos pegos por medição e nenhum por leitura de
    código**:
    1. *IDs de recurso escolhidos no olho*: usei 410/411/412 pros scripts novos
       e eles **já estavam em uso** pelas texturas de grama. `ExtResource("410")`
       passou a resolver pra uma imagem, o script não carregou ("Cannot set
       object script") e a cidade nasceu com **zero** buracos — sem nada que
       reprovasse. A ferramenta agora lê os ids usados e pega o primeiro livre.
    2. *Configurar a rota depois de `add_child`*: o `_ready` da rota roda na
       hora e é ele que monta a curva a partir de `route_points`. Com a lista
       ainda vazia a curva nasce com comprimento ZERO, e os pedestres
       apareceram empilhados na origem.
    3. *Poça deslocada do eixo*: ela tem raio 2,5 contra 3,0 de meia-pista, e
       qualquer deslocamento lateral joga a borda em cima do meio-fio — 35 de 35
       reprovaram assim. Poça vai no eixo; só o buraco (raio 1,1) fica na mão.
    4. *Sorteio de quarteirão que colide consigo mesmo*: eu pegava "o mais
       central de N amostras" e recusava repetido; com 196 quarteirões e viés
       forte, caía sempre nos mesmos e desistia por esgotar tentativas — pedi 14
       rotas e a cidade nasceu com 5. Agora ordeno a lista inteira uma vez, com
       ruído em cima da centralidade.
  - **Regressão da limpeza de ontem, achada aqui**: apaguei o NormalGL e o
    Roughness do `Gravel022` porque o shader do chão só usa a cor — mas o
    **piso de cascalho da cidade** (praça, estacionamento) usa os três, e o
    caminho é montado com `%s`, então nunca aparece inteiro no código. O jogo
    passou a soltar "Resource file not found" em silêncio (erro de load não
    reprova teste). Restaurado do git, e o `pack_audit` aprendeu a convenção:
    todo conjunto ambientCG pedido com `%s` tem que ter os três mapas no disco.
    Conferido que o auditor pega o defeito de propósito antes de restaurar.
  - **Teste instável consertado no caminho**: a seção de resgate do
    `drive_test` capotava o carro girando 180° em torno do eixo FORWARD, o que
    também espelha a direção dele — depois do R ele saía atravessado e batia na
    guia em ~3 m, então o teste passava ou falhava por sorte (2,1 m numa rodada,
    3,6 m na seguinte, sem nada mudar no jogo). Agora ele é apontado ao longo da
    rua antes de acelerar: 15 m, estável.
  - **Sobre o pacote de construções realistas — pesquisei de novo e ele não
    existe.** Poly Haven tem a categoria de arquitetura **vazia**; Kenney,
    KayKit e Quaternius são todos estilizados; o kit modular de cidade mais
    realista que apareceu (Laya Design) é licença **Fab**, não CC0, e só roda em
    Unreal. Baixei o `Kenney Modular Buildings` (111 peças CC0, das quais 7 são
    prédios inteiros) pra avaliar e **não integrei**: o Sample.png mostra um
    estilo pastel mais cartunesco que o kit atual, ou seja pioraria justamente o
    que o usuário quer. O que existe de CC0 realista é **material** (ambientCG,
    já em uso nas fachadas desde 2026-08-03) e **props avulsos** de rua. Fica
    registrado pra não pesquisar isto uma quarta vez.

- **2026-08-09** — Usuário pediu pra continuar. O handoff da sessão anterior era
  explícito sobre o próximo passo: o `BuildingFactory` estava pronto e **não
  estava ligado na cidade**, e a ordem prática registrada era ligar o gerador
  primeiro. Feito: `generated_ratio = 0.62` em `CityBlocks`, e hoje **553 dos
  876 prédios** da cidade são geometria gerada.
  - **Por que misturar, e não trocar tudo**: a janela do gerador é um vão de
    verdade (rebaixado, com vidro no fundo) e cada prédio é único, que era o
    problema apontado em 2026-08-03; mas o kit tem silhuetas que o gerador não
    faz (recuo de andar, térreo saliente) e uma cidade 100% gerada fica com um
    ritmo de fachada regular demais. A decisão é **por lote**, não por
    quarteirão — por quarteirão, a diferença de estilo viraria uma emenda
    visível na esquina.
  - **Medido nos três ajustes** (mesmo ponto de vista, cidade inteira
    carregada): o prédio gerado é **2,8x mais barato em triângulo** (1,15 M →
    0,41 M indo de 0% a 100% de geração) e custa **~270 chamadas de desenho a
    mais** (1370 → 1650), porque modelo de kit é instanciado e malha gerada é
    única. Na taxa escolhida: 0,70 M de triângulo e 1648 chamadas. **Ressalva
    honesta**: mudar a taxa muda quanto RNG cada lote consome, então as três
    cidades não são a mesma cidade com fachadas trocadas — são cidades
    comparáveis. Pro custo agregado tanto faz; pra aparência, a foto vale como
    amostra.
  - **O verificador tinha um ponto cego que inventou 12 defeitos.** Na primeira
    rodada ele acusou 10 prédios invadindo a rua e 40 se atravessando — todos
    **falsos**. `_body_rect` lia `size.x`/`size.z` da caixa de colisão CRUS,
    ignorando rotação: funcionava porque o prédio do kit põe a rotação no visual
    e deixa o corpo alinhado aos eixos, e o gerado gira o próprio corpo. Num
    lote virado 90°, largura e profundidade vinham TROCADAS. Passou a usar o AABB
    da caixa girada (idêntico ao anterior quando não há rotação). **Lição**: antes
    de "consertar" o que o verificador acusa, conferir se ele sabe medir o caso
    novo — eu quase fui mexer na geração, que estava certa.
  - **Erro meu, e já estava documentado neste arquivo**: contei os prédios
    gerados por `name.begins_with("PredioGerado")` e a medição disse **1 de
    780**. Irmãos de nome repetido viram `@PredioGerado@N` — é exatamente a
    armadilha que em 2026-08-03 fez um verificador achar 2 semáforos de 50.
    Passou a ser grupo (`predio_gerado`).
  - **Duas correções que só a FOTO pegou:**
    1. *Vitrine de vidro sem montante*: o térreo saía com um pano de ~2 x 2,8 m
       liso, e da calçada — a 40 cm dele — a fachada virava um retângulo
       azul-marinho chapado tomando meia tela. Passou a vão dobrado, que é o que
       dá escala (a vitrine em relevo do `StreetFurniture` já punha um montante
       a cada 1,6 m).
    2. *A cidade inteira branca*: a paleta do gerador eram nove cinzas quentes
       quase iguais, e na vista aérea as únicas cores da foto vinham dos
       telhados do kit. Agora tem hue de verdade (ocre, terracota, sálvia,
       ardósia, chumbo) e a cor combina com o TIPO — torre é concreto e vidro,
       casa é que pode ser pintada. Arranha-céu de terracota foi o mesmo tipo de
       escolha que fez o material do kit parecer errado em 2026-08-03.
  - **Erro meu de arnês**: as primeiras fotos foram tiradas de x = 4,2, que é a
    **calçada** (vai de 3,0 a 4,5, com a fachada em 4,6) — ou seja a 40 cm da
    parede. Saíram com uma fachada só preenchendo a tela, sem dar pra julgar nem
    o prédio nem a rua. As câmeras foram pra pista.
  - **Duas armadilhas que não viraram bug porque já estavam anotadas aqui**: o
    entulho de telhado do gerado pousa na LAJE (`BuildingFactory.slab_y`), e não
    no topo da construção, que inclui o parapeito — confundir os dois já pôs
    caixa d'água boiando em 2026-08-04; e o sorteio da posição do prop usa
    `Vector2.rotated(-rot)`, porque a convenção de sinal do rotated 2D é a
    contrária da rotação em Y.
  - **O build tinha inchado de 188 MB pra 689 MB, e não era o gerador.** Os 480
    MB de `assets/realistas/` baixados na sessão anterior estavam na pasta do
    projeto, e `export_filter="all_resources"` leva **tudo que está na pasta**,
    mesmo o que nenhuma cena referencia — o `.pck` foi de 142 MB pra **674 MB**.
    Nada disso está integrado ainda (falta fatiar). Entraram no `exclude_filter`
    dos dois presets, junto das 4 pastas-fonte que já estavam lá pelo mesmo
    motivo. Voltou pra 188 MB / 240 MB.
  - **E o auditor aprovou o build errado.** O caminho do `.pck` é fixo dentro do
    `pack_audit.py` (`builds/macos/JeguesMecanicos.zip`), e eu tinha exportado
    pra `builds/JeguesMecanicos-macOS.zip` — exportar pra outro lugar não dá erro
    nenhum, então ele leu o zip ANTIGO e disse "nenhum problema encontrado" sobre
    um pacote de 142 MB enquanto o recém-exportado tinha 674 MB. **Auditar build
    velho é pior que não auditar, porque dá confiança.** O auditor passou a
    comparar a data do zip com a de todo `.gd`/`.tscn`/`.gdshader` mais
    `project.godot`/`export_presets.cfg`, e reprova se alguma fonte for mais
    nova. Conferido que ele reprova de propósito (e sai com código 1) antes de
    confiar nele.
  - **Verificação**: `tools/verify/mix_shots.tscn` (novo) carrega a cidade
    inteira em três taxas, mede no mesmo ponto e fotografa; mais um passeio de
    rua nas três zonas do zoneamento. O `city.gd` ganhou censo de gerados e
    **falha dura em contagem zero** com a taxa ligada — que é a assinatura de um
    gerador que não rodou (aconteceu em 2026-08-09 com id de recurso colidindo, e
    o verificador seguiu dizendo "nenhum problema"). Conferido que a trava
    dispara de propósito antes de confiar nela. Suíte inteira passa: city, drive,
    loop, attach, scale, yard, settings, audio, ui, obstacles, save, loading,
    economy, shop, staff.

- **2026-08-09** — Usuário pediu pra tirar a cidade inteira e refazer **só com os
  prédios realistas**, com boa densidade e diversidade, quarteirões maiores e
  menores, área industrial à parte e o campo mais cheio. No meio da rodada pediu
  também pra ir com calma, sem pular etapas, conferindo tudo. Feito.
  - **Fatiador** (`tools/fatiar_realistas.gd`, duas passadas: `medir` e
    `fatiar`). Dos 15 pacotes baixados, **9 deram 107 peças** —
    93 prédios e 14 props de praça. Os outros 6 ficaram de fora, e a razão é
    diferente em cada um:
    - *não dá pra fatiar por código* — `city_pack_7` tem 105 malhas agrupadas
      **por material** (cada uma com vários prédios fundidos, espalhados por
      69 km), `factory_low_poly` são 4 malhas de 10 km,
      `old_industrial_building` 5 de 3,4 km e `warehouses` é **uma** malha de
      246 m. Os quatro precisam do Blender.
    - *fatiam bem mas não servem* — e **os três só apareceram na folha de
      contato, nenhum número os denunciaria**: `low_poly_city_buildings` é uma
      **maquete de skyline inteira** fundida num bloco; `simple_low_poly_village`
      são cabanas medievais de palha (mistura de estilo, que este projeto já
      corrigiu duas vezes); e `european_buildings_pack3`, apesar do nome, **não
      tem prédio nenhum** — é árvore, banco, poste, coreto e ponte. Esse último
      virou a arborização das praças, que era justamente onde ainda havia árvore
      estilizada ao lado de fachada fotografada.
  - **Nenhum pacote vinha em metros** (de 4,8 m a 69 km de caixa), então a escala
    sai de uma altura-alvo por pacote, calibrada olhando a folha de contato com
    uma **régua de 1,80 m** — a altura do jogador — ao lado de cada prédio. Sem
    referência humana no quadro não dá pra julgar escala: prédio bonito sozinho
    parece certo em qualquer tamanho.
  - **Metade dos prédios nascia de COSTAS pra rua.** A primeira versão só punha o
    lado mais longo em X, e largura/profundidade não dizem onde é a frente — a
    folha do brownstone saiu com fileira de parede de tijolo lisa onde devia ter
    janela e escada de entrada. O sinal que resolveu é a **densidade de geometria
    por lado**: fachada tem janela, cornija e portal modelados, fundo é parede
    quase chapada, então contar vértice por direção separa os dois sem depender
    de textura nem de nome de material.
  - **Quarteirões variados** (`tools/expand_world.py variado`): o espaçamento
    deixou de ser 37,5 em todo lugar e passou a alternar **90, 45, 67,5, 90, 45**
    do centro pra fora (todos múltiplos exatos do tile de 7,5, que é a trava
    documentada da malha viária). Não era só estética: o orçamento de
    profundidade é metade do miolo, e com 37,5 ele dava 13,8 m — os prédios
    realistas têm de 7 a 40 m de profundidade e **a maioria simplesmente não
    cabia**.
    - A ordem do padrão saiu de MEDIÇÃO: com o 90 no meio, as quadras do centro
      ficavam com 45 e 67,5 e **nenhuma torre alta cabia** — a cidade nascia com
      37 m de prédio mais alto tendo modelos de 102 m no catálogo.
  - **Miolo de quarteirão construído** (`MIOLO_MINIMO`): com quadra de 90 m sobra
    um vazio de 20 a 40 m depois das quatro fileiras de fachada, que da rua lê
    como descampado entre dois prédios. Agora um segundo anel é levantado lá
    dentro, recuado pela profundidade já usada — então não pode sobrepor o
    externo por construção.
  - **Lote especial só em quadra curta ou média** (`MIOLO_MAX_LOTE_ESPECIAL`):
    praça/posto/estacionamento/feira foram calibrados quando todo miolo tinha
    28 m; numa quadra de 90 m viravam um descampado de 80 m. A foto do anel do
    meio saiu com metade da tela ocupada por um estacionamento vazio até o
    horizonte.
  - **Sortear entre os que CABEM**, em vez de sortear e torcer: eram 12 tentativas
    ao acaso e, falhando as 12, a borda inteira era abandonada. Com o pool
    realista (a maioria funda) isso falhava muito. Trocado por varrer o pool
    filtrando quem cabe — 1005 → 1074 prédios só com isso.
  - **Zona industrial à parte** é por POSIÇÃO (dois bolsões de 95 m de raio), e
    não por anel de distância: zona industrial de cidade de verdade é um pedaço
    contínuo do mapa, não uma casca em volta do centro.
  - **Resultado medido**: **1036 prédios, todos realistas**, altura média 18,3 m
    (era 8,3), mais alto 80,8 m, 35% de ocupação, 435 casas de entrega, 100
    quarteirões e **nenhum vazio**. E mais barato que a cidade antiga: **1116
    chamadas de desenho** contra 1370. Campo com 3580 props (era ~1130) e os 8
    clusters rurais de volta ao anel de natureza.
  - **Três defeitos que eram das FERRAMENTAS, não do jogo** — e os três me
    fizeram quase "consertar" código que estava certo:
    1. *O `expand_world.py` não era idempotente*. Ele patcheia a partir de
       valores literais do estado original, então rodando sobre um mundo já
       expandido: não achava os campos (viraram regex), escalava a posição dos
       clusters **de novo** (as 5 fazendas foram parar a ~1240 do centro, ALÉM
       da serra) e — o pior — **alocava ids de ExtResource novos enquanto pulava
       a declaração**, porque via que o script já estava declarado. O `Town.tscn`
       ficou apontando pra `ExtResource("421")` inexistente e o Godot recusava a
       cena inteira com um "Parse error" que só aponta a linha do nó.
    2. *O verificador achava o quarteirão dividindo a coordenada por UM
       espaçamento.* Isso só vale em grade uniforme. Com quadras de 45/67,5/90 o
       índice saía errado: quadra cheia aparecia vazia e outra contava em dobro.
       **Ele reprovou a cidade três vezes por um defeito dele** — e eu cheguei a
       fazer duas mudanças no gerador tentando resolver "quarteirão vazio" antes
       de ir ler como o teste media. As duas mudanças ficaram (são boas por
       conta própria), mas o motivo que eu dei pra elas estava errado.
    3. *A lista de exclusão apontava pro lugar errado*: a oficina do jogador
       estava escrita à mão em -377,5 no meu script enquanto o `expand_world` a
       punha em -400. Passou a ser LIDA do arquivo — número repetido em dois
       lugares vira dois números.
  - **Risco de build que quase passou**: as cenas fatiadas embutem a malha mas
    **referenciam as texturas** dentro de `assets/realistas/`, que estava inteiro
    no `exclude_filter`. Exportar assim daria a cidade toda sem textura no
    binário — o mesmo defeito de 2026-08-02. O filtro passou a cortar só a
    geometria crua (`scene.gltf`/`scene.bin`, já assada nos `.scn`) e os 4
    pacotes inúteis, mantendo as texturas.
  - **Catálogo com caminhos literais** (`assets/realistas_prontos/catalogo.gd`,
    gerado): a alternativa era varrer o diretório em runtime, e caminho montado
    por varredura fica **invisível pro auditor do `.pck`** — a cidade nasceria
    vazia só no binário exportado, sem erro nenhum em desenvolvimento.
  - **Achado que vale pra próxima sessão**: `tools/verify/attach_test.tscn` é
    **instável**, e não por causa desta rodada. `Vehicle` sorteia o modelo com
    `rng.randomize()`, então o teste mede um dos 6 carros ao acaso: na suíte ele
    reprovou o ponto do radiador ("só 19% das posições conseguem mirar") e,
    rodado sozinho logo depois, passou com 75%. Ou o teste passa a cobrir os 6
    modelos (como o `drive_test` já faz), ou um dos modelos tem mesmo o radiador
    difícil — e aí é defeito de jogo, na mecânica central. **Não investigado.**

- **2026-08-09** — Usuário pediu personagem escolhível no menu (com a
  mulher-jegue entre as opções), personalização de corpo e **três câmeras no V**.
  Nesta rodada saiu a câmera e o levantamento dos modelos; o menu fica pra
  próxima.
  - **Três câmeras** (`Player.Cam`): 1ª pessoa, 3ª atrás e 3ª LIVRE. O que separa
    as duas de 3ª pessoa não é o enquadramento — é **quem o mouse gira**: em
    ATRÁS o mouse gira o corpo, em LIVRE gira só a câmera em volta de um boneco
    que fica como está. Isso não aparece em foto parada (as duas mostram as
    costas), então o teste MOVE o mouse de verdade
    (`Input.parse_input_event`) e mede se o corpo girou junto: 0,24 rad nos dois
    primeiros modos e **0,00 rad** na livre, com a câmera girando os 0,24.
  - Dois detalhes que não são óbvios: o pivô da câmera livre é `top_level`
    (fora da hierarquia do corpo, senão o boneco a arrastaria ao virar), e na
    livre o WASD passa a ser **relativo à câmera** — pelo eixo do corpo, o
    controle inverteria assim que a câmera girasse pro lado. O boneco vira pra
    onde ANDA, nunca pelo mouse.
  - **Os modelos**: 7 pedidos pelo usuário, todos conferidos como **CC-BY** pela
    API (uso comercial, crédito obrigatório) e listados em
    [docs/personagens.md](docs/personagens.md). **O download não sai pelo
    navegador embutido** — reconfirmado nesta sessão clicando no botão de
    verdade, não só por JavaScript; o arquivo nunca chega. É o usuário quem
    baixa.
  - **A "Just a girl" (a sentada) não serve como jogável, e é bom saber antes de
    baixar**: 0 animações, nenhum esqueleto, e modelada **sentada de mãos no
    rosto**. Rigar por código é possível (o Blender headless já roda neste
    projeto), mas o problema não é o esqueleto e sim a POSE DE REPOUSO: peso
    automático sobre malha sentada dá um rig cuja pose de descanso é sentada, e
    um ciclo de caminhada em cima disso dobra a perna a partir de onde ela já
    está dobrada. Recomendado usá-la como estátua de praça — que é a pose dela.

- **2026-08-09** — Usuário lembrou das ruas ("acho que tá meio estreita e não
  combina com a textura dos prédios") e perguntou se os **buracos entre as
  construções** eram propositais. Os dois eram problema de verdade, e os dois
  foram medidos antes de mexer.
  - **Não existe kit de rua CC0 realista** — pesquisado e conferido abrindo a
    página: o melhor candidato, "City Roads GLB Pack — 72 modelos CC0", diz que a
    fonte é o **mesmo `city-kit-roads` do Kenney** que já estava aqui. Baixar não
    mudaria nada. Fica registrado pra não pesquisar isso de novo.
  - **A rua era uma viela, e o número é feio**: pista de 6 m e calçada de 1,5
    davam **9,2 m de fachada a fachada**, o que com prédio de 80 m ao lado dá um
    desfiladeiro de 1:8,8. Rua urbana de verdade tem 11,4 m de pista (2 faixas de
    3,5 + 2 de estacionamento) e calçada de 3,5 → 18,4 m.
  - **Asfalto GERADO** (`CityStreets.asfalto_gerado`), no lugar do tile do kit.
    Resolve as duas metades da queixa de uma vez: a largura vira **parâmetro**
    (com o tile, a pista tinha a largura que o modelo tem, e mexer no número não
    mexia no desenho) e a superfície passa a usar direto o `Asphalt033` do
    ambientCG que as fachadas já usam, sem o atlas de 64×64 do kit por baixo.
    Faixa central tracejada e travessia são quads pintados. Perfil novo: pista
    ±5,7 e calçada 3,5 → **18,8 m de fachada a fachada**.
    - E saiu **mais barato**: 813 chamadas de desenho contra 1116 com os tiles.
    - *Erro meu, pego na foto*: o primeiro tom foi 0.62 e o asfalto saiu do mesmo
      cinza da calçada — a rua lia como uma laje de concreto larga. Asfalto
      reflete pouca luz; foi pra 0.29, e é o contraste com a calçada que faz o
      meio-fio aparecer.
  - **Os buracos eram reais** (o usuário estava certo): medido com
    `tools/verify/gaps_test.tscn` (novo), 29% da borda dos quarteirões sem
    fachada, 163 vãos, mediana 20 m e o **maior de 71,2 m** — que é exatamente o
    miolo inteiro de uma quadra de 90 m, e foi esse número que entregou a causa.
    1. *As bordas opostas podiam usar METADE do miolo cada*, então com prédio
       realista (10 a 40 m de profundidade) as duas fileiras norte/sul comiam o
       quarteirão inteiro e as laterais eram **puladas** por falta de corredor.
       Virou `DEPTH_SHARE = 0.36`.
    2. *As quadras de 45 m ficaram inviáveis com a rua larga*: o miolo caiu pra
       26 m e o orçamento de profundidade pra 9 m — quase nenhum modelo é tão
       raso, e uma quadra de 26×26 nasceu com as **quatro** bordas vazias. As de
       45 sozinhas respondiam por 80 das 104 bordas vazias. O padrão passou a
       `[90, 67.5, 90, 90]`: continua variado e sem quadra inviável.
    - Resultado medido: **91% da borda com fachada**, maior vão 17,6 m, mediana
      8,9 m, **zero borda completamente vazia**.
    - *Erro meu no verificador*: as primeiras 40 "bordas vazias" eram os 10
      **lotes especiais** (praça, posto, estacionamento, feira), que não têm
      fachada e não devem ter. O teste passou a pulá-los — sem isso o número
      culpava a geração por uma decisão de projeto.
  - **Dois defeitos do `expand_world.py`, e um deles ESTAVA NO COMMIT:**
    1. **`CityLife` e `CityHazards` duplicados.** A ferramenta acrescenta o bloco
       de geradores sem remover o antigo, então cada execução deixava mais um de
       cada — ou seja o **dobro de carro, pedestre, buraco e poça**, calado. O
       arquivo commitado estava assim. Os dois entraram na lista de remoção.
    2. **A ordem estava errada**: a validação de contagem rodava ANTES da
       remoção, então com o duplicado `streets_x` aparecia 6 vezes em vez de 4 e
       a ferramenta travava logo no começo. A limpeza foi pro início.
    - *Erro meu de diagnóstico*: filtrei a saída da ferramenta com `grep` e ela
      **abortou no meio sem eu ver** — o cabeçalho é impresso antes de qualquer
      patch, então "rodou" e "funcionou" pareciam a mesma coisa. Como o `Patcher`
      grava a cada passo, o arquivo ficou meio-patcheado e eu medi duas vezes um
      mundo que não tinha mudado. **Não filtrar a saída de ferramenta que
      valida.**
  - **O perfil da rua virou parte do `tools/cidade_realista.py`**, e não uma
    edição solta no `Town.tscn`: eu tinha alargado a rua à mão e um `git
    checkout` desfez tudo. O que não está em ferramenta não sobrevive.
  - Verificação: `city` limpo (877 prédios, 8×8 quadras, 0 invasão, 0
    sobreposição, 0 quarteirão vazio) e passam `obstacles`, `scale`, `loop`,
    `drive`, `yard`, `staff` e `loading`.

- **2026-08-10** — Fechados os itens 1, 2 e 3 do handoff anterior: **menu de
  escolha de personagem com preview 3D, personalização do corpo por slider e
  personagem masculino jogável**. A aparência deixou de ser constante escrita no
  código (proporções fixas e sempre a mulher de cabeça de jegue) e
  virou o autoload `Appearance`, com dono único — três coisas passaram a ler os
  mesmos valores (o jogador de verdade, o preview da tela e o verificador), e
  valor repetido em três lugares vira três valores.
  - **Medi os dois modelos antes de desenhar a tela**, e a medição achou um
    defeito que já estava lá: o cabelo tem **nome diferente** em cada arquivo
    (`Hair_Long` na mulher, `Hair_SimpleParted` no homem), e `DonkeyHead`
    escondia só o primeiro. Ou seja, o homem entraria no jogo **com o cabelo
    dentro do crânio do jegue**. O esconde-esconde passou a ser por PREFIXO.
    Outras medidas que viraram tabela: ajustes de proporções corporais
    disponíveis por modelo, osso `Head` em y = 1,55 contra 1,60, e altura
    nativa **1,788 m contra 1,852 m** — sem esse par de números, um fator único
    de escala deixaria o homem sempre 3,5% mais alto que o pedido.
  - **A altura mexe no CORPO, não só no desenho**: cápsula, cabeça e câmera
    saem de `Player.BASE_HEIGHT`. Só o visual escalado poria a câmera acima do
    próprio crânio a 1,60 m. O RAIO da cápsula fica como está de propósito —
    engrossar o jogador mudaria por onde ele passa, e isso é geometria que o
    resto do projeto já mede. A cápsula é **duplicada** antes de mexer: o
    `SubResource` do `.tscn` é compartilhado entre instâncias.
  - **A faixa de altura é 1,60–1,95 m e foi VERIFICADA contra a mecânica
    central**: o `character_test` carrega o `Main.tscn` nas duas pontas e cobra
    que os 4 pontos de gambiarra continuem alcançáveis (4/4 nas duas). A altura
    move a câmera, e é da câmera que sai a mira — um personagem baixinho não
    pode perder acesso ao que o jogo inteiro gira em torno.
  - **O preview usa `PlayerVisual.build()`, o mesmo caminho do jogador de
    verdade.** Preview com montagem própria deixa de provar o que o jogador vai
    ver — foi assim que a cabeça de jegue passou dias sem ser olhada
    (2026-08-08). Junto vai uma **régua de 2 m** listrada a cada 10 cm com a
    faixa de 1,80 destacada: sem referência de tamanho no quadro não dá pra
    julgar escala, e foi exatamente assim que os NPCs ficaram com 3,76 m por
    meses.
  - **Armadilha evitada de propósito** (vale pra quem mexer no tint):
    `get_active_material` devolve o *override* quando ele existe, então tingir a
    partir dele multiplicaria a cor de novo em cima da anterior — o personagem
    iria escurecendo a cada clique na seta. A cor base vem sempre da malha.
  - **Erros meus, e como cada um foi pego:**
    1. *Nome de nó repetido*: `queue_free()` não tira da árvore na hora, então o
       boneco novo entrava com o antigo ainda lá e o Godot o renomeava pra
       "Visual2" — dois personagens no mesmo lugar por um quadro, e o
       verificador dizendo "preview vazio". É a mesma armadilha que em
       2026-08-03 fez um teste achar 2 semáforos de 50. Agora sai da árvore
       antes de liberar.
    2. *Procurei os pontos de gambiarra no lugar errado* (filhos diretos do
       carro; eles vivem em `AttachPoints`). O teste reprovou "0 de 4
       alcançáveis" **com a lista de nomes vazia** — e foi a lista vazia que
       denunciou que o defeito era do medidor, não do jogo. Contagem zero numa
       varredura é sempre suspeita do medidor primeiro.
    3. *Chão estimado em vez de medido*: pus o jogador em `alvo.y - 0.6` em vez
       de jogar um raio pra baixo. Mesmo erro de 2026-08-04, quando medir a
       altura pelo centro de uma Area3D deixou jogador e carro boiando na foto.
    4. *Botões de sair dentro da coluna rolável*: caíam abaixo da dobra, e quem
       abrisse a tela em janela menor não acharia como voltar. **Só a foto
       pegou** — o teste dizia que os controles estavam todos lá. Foram pro
       rodapé fixo, e o `character_test` ganhou a trava (o botão tem que caber
       na tela sem rolar). Esc também volta.
    5. *Amostras de cor brancas*: a paleta guarda MULTIPLICADORES sobre a
       textura, então o item neutro (1,1,1) desenhava um retângulo branco onde
       devia estar pele, tecido e cabelo. Também só a foto pegou. Agora a
       amostra multiplica por um tom médio do material e tem contador (1/6).
    6. *28 erros de `Parameter "material" is null`* no fim do `player_shots`.
       **Provei de que lado estava** antes de mexer, que é a lição que este
       arquivo repete: dei `git stash` nas minhas mudanças e rodei o mesmo
       roteiro — zero erros no código antigo, 28 no novo. Era meu. A causa:
       eu duplicava material em TODA superfície de pele/roupa/cabelo, mesmo
       quando o multiplicador era o neutro (1,1,1), que é o caso padrão do
       jogo — oito materiais por personagem que só repetiam o original, e na
       destruição da cena o servidor de render ia consultá-los depois de já
       liberados. Cor neutra passou a **soltar** o override em vez de duplicar:
       zero erro, menos material, e de quebra é o que faz voltar pra cor
       original realmente voltar na tela. O `character_test` ganhou a trava
       dos três casos (neutro não duplica, cor escolhida duplica, voltar ao
       neutro solta).
  - **Aparência fica FORA do `SaveGame`**, e o teste cobra isso: quem aperta
    "Novo jogo" perde dinheiro e níveis da loja, e não pode perder o personagem
    que montou.
  - **33 MB de lixo no build, achados de passagem**: cruzando cada pacote de
    `assets/realistas/` contra o que as cenas fatiadas realmente referenciam,
    dois deles (`low_poly_city_buildings` e `simple_low_poly_village_buildings`)
    aparecem com **zero referência** — são os que a folha de contato reprovou em
    2026-08-09, e ficaram viajando porque `export_filter="all_resources"` leva
    tudo que está na pasta. Entraram no `exclude_filter` e o pacote foi de 385
    para **355 MB**. Conferido depois, item a item, que os dois estão FORA do
    `.pck` e que o que o jogo usa continua dentro — mexer nesse filtro já quebrou
    o jogo inteiro uma vez (2026-08-02).
    - Conferido também que os **7 `.zip` de personagem** que o usuário baixou na
      raiz do projeto **não** entram no pacote (161 MB): o exportador não os
      reconhece como recurso. Diferente das pastas de assets, que entram.
  - **Verificação**: `tools/verify/character_test.tscn` (novo, headless) lê o
    peso da shape key **de volta** do modelo montado, mexe na tela pelo próprio
    `HSlider` (o mesmo `value_changed` que o mouse dispara) e cobra a cobertura
    do crânio nos dois modelos — 4,1% de exposição na mulher (pior 2,2 cm) e
    3,0% no homem (pior 4,7 cm), com a mesma ressalva de sempre: a conta erra no
    centímetro e quem decide são as fotos. `tools/verify/character_shots.tscn`
    (novo, janela) rende 37 fotos, incluindo a **prova magenta** (corpo humano
    pintado, cabeça de jegue normal) nos dois modelos: **nenhum magenta na
    cabeça**, ou seja o crânio calibrado na mulher engole também a do homem.

- **2026-08-10** — Usuário reportou, jogando: o entorno da cidade tem **casas
  do pack inicial e fora de escala**, o **mobiliário urbano** (semáforo, ponto
  de ônibus, faixa, posto) "está tudo ruim fora de escala", há **buracos nos
  quarteirões**, e depois: **as árvores** e "na zona rural deve ter muitas
  árvores". Tudo medido e fotografado antes de mexer.
  - **A primeira hipótese estava errada, e foi a foto que corrigiu.** Achei que
    o mobiliário estivesse plantado com os offsets da rua antiga (o `.gd` ainda
    dizia "a calçada vai de 2.4 a 3.8") — mas o `Town.tscn` já os corrigira na
    rodada da rua larga. Ler código não bastava: só fotografando da **altura
    dos olhos com o jogador no quadro** dá pra julgar escala. É a mesma razão
    de existir da régua de 1,80 m do preview de personagem.
  - **Cinturão: eram 29 modelos do kit Kenney**, esticados por `scale_near =
    6.5`. Numa foto ao lado da jogadora, a PORTA de uma casa dava ~4,5 m. Agora
    ele usa os mesmos **prédios realistas** da cidade, e o degradê de tamanho
    vem da **escolha do modelo**, não de esticar a escala — esticar modelo
    realista infla porta e janela junto. É a armadilha da grama gigante de
    2026-08-04: configurar em escala crua em vez de altura em metros. Medido:
    mediana 5,7 m → **11,5 m**, com a borda da cidade ao lado em 13,2 m, e o
    degradê de 12,5 m colado na cidade a 8,5 m na borda do campo.
  - **Filtrar por altura não bastava, e de novo foi a foto que mostrou**: um
    **tanque de refinaria** tem a altura de um sobrado, e apareceu plantado no
    mato ao lado da jogadora, junto de uma torre de escritório. O pool do
    cinturão passou a ser por PACOTE (residencial), não por tamanho.
  - **252 pontos de ônibus** — um a cada 37 m, porque o `Town.tscn` pedia um a
    cada 5 tiles. Ponto de ônibus de verdade fica a cada 300-400 m. Agora são
    **18**. O abrigo também era estreito (3,2 m) pra uma calçada de 3,5 m: foi
    pra 4,8 m, com painel lateral de vidro.
  - **Semáforo virou semáforo de cidade**: 5,2 m com **braço projetado sobre a
    pista** e repetidor na altura do olho, no lugar do postinho de 3,4 m na
    calçada. A rua tem 11,4 m de pista desde que foi alargada — na calçada o
    cabeçote some atrás do primeiro carro parado.
  - **Buracos nos quarteirões**: o preenchimento de borda para quando nenhum
    modelo cabe no resto, e esse resto ficava como descampado — 73 vãos de 6 m
    ou mais, o maior com 17,6 m. Agora o resto vira **muro de lote** com
    pilaretes e portão de garagem (montado em código, o idioma do projeto).
    Medido: 91% → **93%** de borda fechada, 73 → **58** vãos, e 62 muros.
  - **Árvores**: no campo já estavam em altura de metros (a correção de
    2026-08-04), mas o topo ia a 20 m — moderado pra 15. O que faltava era
    QUANTIDADE: 780 sólidos em ~1 km² davam uma árvore a cada 2.500 m². Agora
    são **2400** (1400 árvores, 14,9 por hectare), com mediana de 10,3 m.
  - **Erros meus, os dois de MEDIDOR e não de jogo** (e os dois já documentados
    neste arquivo como armadilhas):
    1. *Classifiquei mobiliário por nome de nó*: irmãos de nome repetido viram
       `@Node3D@N`, e o teste jogou **300 dos 302 props** num balde "?". Passou
       a ser por grupo (`semaforo`, `ponto_onibus`, `banco`), que o
       `StreetFurniture` agora atribui.
    2. *Medi a barra da faixa pegando "uma tinta qualquer"*: o grupo `via_tinta`
       também tem o **traço central** da pista, então o teste reportou barra de
       0,14 × 2,4 m e reprovou a cidade. As barras ganharam grupo próprio;
       medida certa: 0,55 m de largura × 10,2 m atravessando uma pista de
       11,4 m.
    3. *E um de processo*: rodei o teste novo com `| tail -40`, que segura a
       saída — 10 minutos parecendo travamento, e a causa era **erro de parse**
       no meu próprio script (`node.name` é StringName e não aceita subscript;
       `get_script()` devolve Variant e o projeto trata aviso como erro). O
       próprio CLAUDE.md já registrava essa armadilha desde 2026-08-04.
  - **Um defeito que EU introduzi, e que a suíte pegou**: trocar o kit por
    modelo realista no cinturão criou **parede invisível**. Prédio realista tem
    recuo, sacada e telhado em L, então o AABB é bem maior que a planta na
    altura do carro — medido pelo `obstacles_test`, 15 construções com até
    **12,2 m de ar sólido** ao lado, bem no caminho de quem entra na cidade.
    Resolvido ligando `slim_collision` (colisão pela silhueta na altura de
    trânsito), que aqui é seguro porque o cinturão não tem prop de telhado —
    ao contrário do `CityBlocks`, onde ligar isso deixaria a caixa d'água sem
    apoio. **Vale a lição**: trocar o pacote de modelos de um gerador exige
    reconferir a COLISÃO, não só a aparência.
  - **Verificação**: `tools/verify/street_test.tscn` (novo, headless) mede cada
    peça contra duas referências que não mudam — o jogador de 1,80 m e a largura
    real da pista lida do próprio `CityStreets` da cena — e cobra que o
    mobiliário fique na calçada, que a barra da faixa atravesse a pista, que o
    cinturão afine indo pro campo e que ele não venha do kit.
    `tools/verify/street_shots.tscn` (novo, janela) fotografa tudo da altura dos
    olhos com o jogador no quadro. O `gaps_test` aprendeu a contar o muro de
    lote: sem isso ele diria "borda vazia" onde o jogador vê um muro com portão.

- **2026-08-10** — Variedade dos NPCs (o item que estava aberto desde
  2026-08-03), mais dois pedidos que o usuário fez no meio da rodada: **todos os
  personagens jogáveis** e **baixar homens diferentes**; e depois **animações de
  andar diferentes para alguns NPCs**.
  - **O que faltava não era volume nem cor, era SILHUETA.** Tipo físico, altura
    e tom já variavam por NPC desde 2026-08-03. Só que de 20 m — a distância em
    que se vê pedestre na rua — isso não separa uma pessoa da outra. Novo
    `scripts/NpcAccessories.gd`: boné, chapéu de palha, gorro, óculos, mochila e
    sacola, montados com primitivas (o idioma do projeto: mobiliário urbano,
    gambiarras e cabeça de jegue são assim), presos num `BoneAttachment3D` pra
    acompanhar a animação. Medido: **59 aparências distintas em 72 pedestres
    (82%)**, 60% com algum acessório.
  - **Mochila e sacola não apareciam, em silêncio.** Eu pedia nomes genéricos
    para os ossos superiores do tronco; medido no arquivo,
    eles se chamam **`spine_01..03`**, minúsculo com underscore. `find_bone`
    devolve -1 e a peça era descartada sem erro — chapéu e óculos (osso `Head`,
    esse existe) funcionavam, e por isso o defeito passou despercebido na
    primeira medição.
  - **Jeito de andar** (pedido do usuário): a UAL1 tem `Walk`, `Jog_Fwd` e
    `Sprint` (medido no arquivo, junto com mais 38). Agora cada pedestre sorteia
    um dos quatro jeitos — passeando, normal, apressado, atrasado — e a
    **velocidade vem JUNTO com a animação**: sorteadas em separado, o boneco em
    `Jog_Fwd` devagar patina e o em `Walk` rápido desliza. Medido: 59 andando,
    13 trotando, de 0,9 a 2,9 m/s.
    - *Erro meu*: sorteei a animação ANTES do bloco em que a rota manda o
      `walk_anim_name` para todos os seus pedestres — o valor era sobrescrito, e
      o teste mostrou "Walk 28" com a velocidade já variando, que é exatamente a
      combinação que faz patinar.
  - **A cidade estava deserta**: 28 pedestres e 24 carros numa cidade que
    cresceu para 525 m de lado (uma pessoa a cada 10.000 m²) — a foto do centro
    saiu com **um** pedestre na tela. Passou para **72 pedestres e 52 carros**.
  - **Os 7 modelos que o usuário baixou não servem como jogáveis, e a medição é
    dura**: **6 dos 7 não têm esqueleto nenhum** e **nenhum tem animação** —
    incluindo o `carol_tennis_player_girl__animated_3d_character`. O único
    rigado (`anime_girl_rigged`) usa esqueleto VRM (97 ossos, `Hips_01`,
    `J_Sec_Hair*`) que não bate com o Quaternius que a UAL1 anima. Conferido por
    dois caminhos (contagem de `skins`/`animations` no glTF e leitura dos
    `joints`). Personagem sem rig é estátua: não anda e não mexe o braço.
  - **Daí saiu `tools/garimpo_personagens.py`**, que resolve a causa: ele filtra
    a API pública do Sketchfab por **`animationCount`**, que era o filtro que
    faltava. Resultado em [docs/garimpo-personagens.md](docs/garimpo-personagens.md):
    **30 homens e 18 mulheres, todos com animação própria**, CC-BY. Quando
    entrarem, é uma linha em `Appearance.MODELS`.
    - Dois erros meus na ferramenta, os dois vistos na saída: `viewerUrl` vem
      com o slug `none` nesta rota da API (o link tem que ser montado do uid), e
      `isRigged` **não vem** na busca — sempre falso. Animação > 0 implica
      esqueleto, então é isso que a coluna diz agora. O veto também deixava
      passar Sonic, Squidward e "Balerina Capuchino".
  - **Erros meus de verificador**: `get_nodes_in_group` devolve `Array[Node]` e
    reatribuir um `Array` sem tipo é erro de parse — e o erro **abortou a seção
    e o teste terminou dizendo que passou**, que é a armadilha mais perigosa
    deste projeto (já registrada no `economy_test` em 2026-08-09). O
    `street_test` ganhou a trava: cada seção marca que chegou ao fim, e faltar
    marca é falha dura.

- **2026-08-10** — Usuário decidiu **baixar a lista inteira de personagens e
  usar todos**, "com qualidade", somados aos que já estão no jogo. Preparei o
  caminho pra isso funcionar sem virar trabalho manual.
  - **A lista foi limpa antes**: a busca do Sketchfab é ruidosa e a primeira
    leva deixou passar um dinossauro, um cachorro, um pack de Pokémon,
    `Castlevania NES` e um urso de armadura. Como agora a lista vai ser baixada
    INTEIRA, cada item errado é download perdido — o veto foi ampliado e o de
    "multidão" entrou depois que apareceu uma plateia de show com 242 mil faces
    (dezenas de pessoas numa malha só, não um personagem).
  - **O teto de faces subiu de 120 mil para 260 mil** por causa do pedido de
    qualidade: ele cortava justamente os modelos caprichados. O custo agora fica
    ANOTADO na tabela, e é ele que decide onde cada modelo serve — **NPC aparece
    72 vezes na tela ao mesmo tempo e o jogador uma**, então o corte em 18 mil
    faces separa "jogador + NPC" de "só jogador". Com isso apareceram
    Renderpeople e Adobe Fuse na lista, que é o nível que ele pediu.
  - **56 candidatos**, todos com animação própria, 24 deles leves o bastante
    pra virar pedestre — [docs/garimpo-personagens.md](docs/garimpo-personagens.md).
  - **O jogo passou a aceitar N personagens sem editar código.** Com ~45
    modelos, uma linha manual em `Appearance.MODELS` por modelo seriam 45
    chances de errar a altura — e **altura errada não acusa em lugar nenhum**, o
    personagem só nasce do tamanho errado (foi assim que os NPCs ficaram com
    3,76 m por meses). Agora:
    - `tools/preparar_personagens.gd` (novo, headless) mede cada arquivo
      recebido — altura, ossos, animações próprias, faces e se veio **deitado**
      (exportador com Z pra cima) — e gera `assets/personagens/catalogo.gd` com
      caminhos LITERAIS, que é o que o auditor do `.pck` enxerga;
    - `Appearance.models()` junta os dois nativos com o catálogo, e **descarta
      quem não tem osso**: modelo sem esqueleto é estátua, não jogável;
    - o catálogo é carregado por CAMINHO e não pela classe, senão o autoload não
      compilaria enquanto a pasta estivesse vazia.
  - `tools/receber_modelos.sh` ganhou destino: `personagens` extrai pra
    `assets/personagens/` em vez da pasta de prédios, porque o pipeline seguinte
    é outro.

- **2026-08-10** — Usuário baixou os personagens e pediu para **usar todos**,
  "com qualidade". Integrados: o jogo foi de **2 para 40 personagens jogáveis**.
  - **Achado que destravou tudo, e foi o usuário quem apontou**: 35 pastas de
    personagem estavam **soltas na raiz do projeto, já descompactadas** — o
    macOS abre `.zip` sozinho. Eu só processava os `.zip` e por isso a maioria
    do que ele baixou estava sendo ignorada em silêncio, incluindo quase todas
    as femininas boas. `tools/receber_modelos.sh` ganhou destino
    (`personagens`), mas o que resolve mesmo é olhar a pasta antes de concluir
    que "chegou pouca coisa".
  - **46 arquivos medidos, 38 com esqueleto** (`tools/preparar_personagens.gd`).
    O que a medição pegou e que nenhum arquivo declara:
    - **escalas de 0,01 m a 1471 m** — a normalização por altura resolve todas,
      e é por isso que a altura sai MEDIDA e não escrita à mão;
    - **11 modelos vêm DEITADOS** (exportados com Z para cima);
    - **8 não têm esqueleto** (os anime girls, Carol, Tanya, Just a girl, o Lego
      man, o biquíni) — ficam no catálogo como estátua e o `Appearance` os
      descarta da lista de jogáveis. São os mesmos que já haviam reprovado em
      2026-08-09: personagem sem rig é estátua, não anda.
  - **Erro meu que só a folha de contato pegou**: girei o modelo deitado −90° em
    X e ele continuou deitado, agora de bruços. O Godot já converte Z-up na
    importação do glTF; quem chega deitado foi exportado errado na origem, e aí
    o giro é para o outro lado (+90).
  - **A animação não podia ser a mesma pra todos.** A UAL1 procura osso por
    NOME, e num esqueleto de terceiro nenhuma trilha casa — o Godot enche o log
    de `_update_caches` e o boneco fica em T-pose. Agora `PlayerVisual` checa se
    o esqueleto tem `spine_01` (o marcador do Quaternius): quem tem usa a UAL1
    (que traz idle/walk/run separados), quem não tem usa **a animação que veio
    no próprio arquivo** — que foi justamente o filtro do garimpo.
  - **O catálogo passou a registrar quais SHAPE KEYS cada modelo tem.** Modelo
    de terceiro não carrega as sete do `build_characters.py`, e sem isso a tela
    oferecia sete sliders que não faziam nada — o jogador só descobriria
    arrastando.
  - **Garimpo ajustado ao pedido de qualidade**: o teto de faces subiu de 120
    mil para 260 mil (ele cortava justamente os modelos caprichados, e com isso
    entraram Renderpeople e Adobe Fuse), e a tabela ganhou a coluna **"serve
    como"** — NPC aparece 72 vezes na tela e o jogador uma, então o corte em 18
    mil faces separa "jogador + NPC" de "só jogador". O veto foi ampliado duas
    vezes: primeiro por não-humanos (dinossauro, cachorro, Pokémon, Castlevania,
    urso), depois por multidão ("Audience On Stage" tem 242 mil faces porque são
    dezenas de pessoas numa malha só). "anime" SAIU do veto: o que faltava
    naqueles modelos não era o estilo, era o rig.
  - **Aviso registrado**: vários modelos são personagens de outras obras (Ada
    Wong, Spider-Man, Rem, Mileena). A licença CC-BY cobre **o modelo**, não o
    personagem — para publicar, é risco jurídico de terceiros.
  - Os downloads crus (1,9 GB) ficam **fora do git**, mesma política de
    `assets/realistas/`; o que entra é o catálogo gerado.
  - **Verificação**: `character_test` aprendeu as duas coisas que os modelos de
    terceiros trouxeram — altura no eixo Z para quem está deitado, e forma
    cobrada só quando o modelo declara tê-la — e passa com os 40.
    `tools/verify/personagens_sheet.tscn` (novo, janela) renderiza todos lado a
    lado com régua de 2 m: foi ele que pegou a rotação errada.

- **2026-08-10 (2ª rodada)** — Usuário pediu pra seguir com o que falta e
  **olhar os personagens baixados, corrigindo os bugados**. Era o item 1 do
  handoff anterior ("OLHAR a folha de contato dos 40"), que estava escrito
  justamente porque a folha tinha sido renderizada e **não conferida**. Olhando,
  ela estava cheia de defeito: personagem microscópico, gigante ocupando a tela
  inteira, quatro deitados no chão e dois de costas — com o catálogo jurando
  1,80 m para todos.
  - **UMA causa explicava quase tudo: a altura era medida pela caixa da malha
    crua.** Numa malha SKINADA os vértices ficam no espaço em que a malha foi
    autorada, e quem os leva pro espaço do esqueleto é a **bind pose** — então
    `mesh.get_aabb()` pode estar em outra unidade e até em outro eixo que o
    resultado na tela. Medido nos 46 arquivos: `casual_woman_in_brown_dress` dá
    **0,019** na caixa crua e **1,899** depois do skin (98x de erro), e
    `animated_man` dá **1471 contra 114** (13x). Como a escala sai da altura
    medida, o primeiro nascia 94x grande e o segundo 10x pequeno.
  - **Os "deitados" NUNCA existiram.** A mesma caixa crua era usada pra decidir
    "veio com Z pra cima" (z > y), e como ela mede num espaço trocado, **11 dos
    46 davam falso positivo** — e o `PlayerVisual` obedientemente DEITAVA no
    chão quem estava de pé no arquivo. A sessão anterior tinha visto isso na
    foto, achado que era sinal de giro invertido e trocado −90 por +90, o que só
    mudou de bruços pra costas. Com a medida certa, **zero** modelos são
    deitados. O mecanismo ficou, defensivo, mas agora a pergunta é "isto
    RENDERIZA deitado?" em vez de "a malha crua é comprida em Z?".
  - **A medida virou `tools/MedirPersonagem.gd`, com dono único**, e isso não é
    organização: enquanto a folha de contato media por conta própria, ela acusou
    **17 personagens fora de escala que a foto mostrava certinhos ao lado da
    régua**, e o `character_test` reprovou os mesmos. Hoje o gerador do
    catálogo, a folha e o teste leem a mesma conta — medida com dono duplicado
    conta duas histórias sobre o mesmo arquivo.
  - **Orientação: tentei medir e DESISTI com número na mão.** O sinal que
    parecia óbvio (o dedo do pé avança além do quadril, então o centro da nuvem
    lá embaixo aponta pra frente) erra nos **dois** sentidos: acusou de costas o
    `frank_army_man`, o `fuse_civilian_1`, o `nathan` e o `nilda`, que a foto
    mostra de frente, e **deixou passar** o `old_man_spice`, que está mesmo de
    costas. Testado também na pose animada, e continuou errando. Aplicado,
    giraria 18 personagens certos pra consertar 2. Virou lista escrita à mão
    (`DE_COSTAS`), cada id conferido na foto. **Sinal que erra nos dois sentidos
    é pior que sinal nenhum.**
  - **22 personagens estavam largados na RAIZ do projeto**, já descompactados —
    o macOS abre o zip sozinho, e `receber_modelos.sh` só olhava `*.zip`. A
    sessão anterior tinha descoberto isso e documentado, mas **não consertou o
    script**, então voltou a acontecer. Pior: raiz é pasta do projeto, então eles
    entravam no build sem estar no jogo. O script passou a recolher pasta
    também, testando o CONTEÚDO (tem `scene.gltf` dentro?) e não o nome — assim
    as pastas do próprio Godot que moram ali nunca são tocadas. Deu **63
    arquivos, 44 jogáveis**.
    - Efeito colateral bom: elas também estavam **versionadas no git** (o
      `.gitignore` cobre `assets/personagens/`, não a raiz), então o repositório
      carregava ~700 mil linhas de binário cru. Ao mudarem de lugar, entraram na
      regra que já existia e saíram do controle de versão — que é a política
      escrita desde `assets/realistas/`: download cru fica no disco, o que entra
      no repo é o catálogo gerado.
  - **Três reprovações novas, e todas automáticas** (`MedirPersonagem`): mais de
    um esqueleto = é uma CENA com vários personagens (`background_people`,
    `construction_workers`, `game_character_skins_pack`, `topology_practice`);
    profundidade > 0,75 da altura = não está de pé (`old_fat_man` vem com a
    poltrona, `bloody_scarlet`, `bunny_set_pubg`, `shang_hai_lady`); e o desenho
    inteiro > 2,2x a pessoa = **vem com CENÁRIO junto**. Essa última é o defeito
    mais chamativo dos modelos novos: `chibi_rem_confession` traz um diorama com
    céu, montanha e árvore, e outro traz um painel gigante com a ilustração da
    personagem — na tela vira um outdoor seguindo o jogador.
  - **E uma lista manual `NAO_SERVE`, com o motivo escrito**, pro que só o olho
    pega: `kindred` (sai minúsculo num pedestal, com uma malha de contorno
    solta), `danmachi_hestia` (disco de grama nos pés, pequeno demais pra regra
    de cenário pegar) e `tomoko_kuroki` (não aparece na foto — renderiza como
    sombra escura).
  - **Build: 1,4 GB → 670 MB.** Os 1,9 GB de `assets/personagens/` entravam
    inteiros no `.pck` (`export_filter="all_resources"` leva tudo que está na
    pasta), e o handoff anterior já avisava. Três cortes, todos no IMPORT pra não
    tocar no original:
    1. **Morph target que o jogo nunca usa** era o maior peso e não era óbvio:
       vários modelos vêm de gerador de personagem com a biblioteca facial
       inteira (148 a 176 shape keys), e cada morph guarda uma cópia das
       posições de TODOS os vértices — `old_man_spice` tem 138 MB de `scene.bin`
       pra 78 mil faces. `tools/pos_import_personagem.gd` (novo, roda como
       `import_script`) remonta a malha sem eles; num arquivo saíram 1931.
    2. Textura capada em **1024** (a mesma resolução que os dois personagens
       nativos usam), 686 arquivos.
    3. `exclude_filter` **gerado a partir do catálogo** pelos 21 reprovados —
       lista escrita à mão aqui envelheceria a cada personagem novo.
  - **Erro meu, e grave, na remoção de morphs**: quando o remonte falhava
    (superfície com canal `ARRAY_CUSTOM`, que não faz o caminho de volta —
    `surface_get_arrays` devolve decodificado e `add_surface_from_arrays` exige
    bytes crus), eu atribuía a malha nova mesmo assim, **com ZERO superfícies** —
    ou seja o personagem sumiria da tela em vez de só manter os morphs. Agora só
    troca se a malha nova ficou inteira, e quem não dá pra remontar fica como
    está, listado no log.
  - **`pack_audit` ganhou o catálogo de personagem**, que era ponto cego: o
    catálogo mora fora de `SOURCE_DIRS` e `.gltf` cai na lista de "importados,
    pulados", então excluir um jogável por engano passaria 100% calado e o jogo
    só quebraria ao escolher aquele personagem. A conferência é nos DOIS
    sentidos — jogável tem que estar no pacote, reprovado não pode estar (senão
    a exclusão não está valendo). Conferido que ele reprova de propósito antes de
    confiar nele.
  - **Animação por estado**: quem tem mais de um clipe agora mapeia
    idle/walk/run separados. O código parava no primeiro nome que casasse com
    walk/run/idle, então o `stickman` (que traz "Idle" e "Run") ficava parado
    também correndo.
  - **Verificação**: folha de contato renderizada e **olhada** três vezes ao
    longo da rodada (é ela que pegou o cenário junto, os dois de costas e o
    invisível). Suíte inteira passa — city, drive, loop, attach, scale,
    obstacles, save, loading, economy, shop, staff, street, gaps, audio,
    character, settings, ui. `pack_audit` limpo, builds reexportadas (macOS 670
    MB, Windows 757 MB), `.app` reextraído e o binário exportado sobe limpo.

- **2026-08-11** — Usuário pediu **cabeça de jegue para todos os personagens
  novos, aparecendo de verdade na cabeça**, e que os 44 fossem testados como
  jogáveis E como NPCs, separadamente. Também perguntou se a release do GitHub
  estava sendo atualizada — **não estava**: havia 11 commits sem push e a última
  release era a v0.2.0, de 05/08.
  - **O push estava travado por um arquivo de 195 MB no histórico.** Uma sessão
    anterior commitou as pastas de personagem que estavam na raiz, e o
    `chibi_rem/scene.bin` passa do limite de 100 MB do GitHub. Como os 11
    commits nunca tinham sido enviados, dava pra reescrevê-los sem risco —
    e essas pastas nunca deveriam ter entrado no git (é a política escrita
    desde `assets/realistas/`). Publicada a
    [v0.3.0](https://github.com/vitudanas/JeguesMecanicos/releases/tag/v0.3.0) com os
    dois builds.
  - **A cabeça de jegue só servia nos dois nativos**, e por dois motivos: o
    código procurava o osso `Head` (dos 44 modelos, só eles usam esse nome) e as
    medidas do crânio eram metros fixos, calibrados naquela cabeça. Agora o osso
    sai de uma regra de nome com desempate (cobre os seis padrões medidos:
    `Head`, `mixamorig_Head`, `CC_Base_Head`, `Bip01_Head`, `girlBone_Head`,
    `head_Armature`) e, quando nenhum osso tem "head" no nome, por **geometria**
    — o osso cujos vértices ficam mais no alto. O tamanho sai da cabeça humana
    MEDIDA no arquivo; quando essa medida não é confiável, de uma **fração da
    altura que o personagem tem na cena**.
  - **43 dos 44 recebem a cabeça.** O único de fora é o `rem_rezero`, cujo rig
    não tem osso de cabeça e onde o palpite geométrico cai no torso — cabeça
    nenhuma é melhor que cabeça no lugar errado, e a exceção está listada no
    teste pra um modelo novo nessa situação reprovar em vez de passar no meio de
    uma falha permanente.
  - **Quatro erros meus nessa parte, todos de ESPAÇO**, e cada um só apareceu
    porque a folha de contato foi olhada:
    1. Comparei a caixa da cabeça (espaço da malha) com a altura pelos **ossos**
       (espaço do osso). Em vários rigs os dois não coincidem — há um em que os
       ossos ocupam 0,3 enquanto a malha ocupa 1,8, porque a escala mora na bind
       pose. A "cabeça" media 110% do corpo, era reprovada como implausível e
       caía numa estimativa de 3 cm, invisível dentro da cabeça humana.
    2. Li o **rest** do osso quando o que aparece na tela é a **pose**: nem todo
       rig guarda a orientação no rest.
    3. Subi a árvore até o topo pra achar as malhas do personagem — e na folha
       de contato, onde os 5 são irmãos, medi a cabeça de um com o corpo do
       vizinho: saiu uma cabeça de jegue de 184 m.
    4. O índice guardado em `ARRAY_BONES` **não é o índice do osso**, é a posição
       na lista de binds do skin. Comparar um com o outro acerta por acaso e erra
       na maioria.
  - **Os baixados agora são PEDESTRES também** (`Appearance.npc_models`), que era
    o item que resolvia "todo pedestre tem a mesma cara": 31 modelos cabem no
    orçamento de faces (média de 5.100, a mesma ordem dos dois nativos). A regra
    de "usa a UAL1 ou a animação que veio no arquivo" saiu do `PlayerVisual` e
    virou dono único no `CharacterVisual` — o pedestre precisava exatamente da
    mesma coisa, senão anda em T-pose.
  - **A escala do pedestre passou a sair da altura MEDIDA de cada modelo**
    (`model_heights`, array paralelo). Com um `visual_scale` único, metade da
    cidade sairia de anão e a outra de gigante — as alturas de arquivo vão de 0,7
    a 208 unidades. Mesma lição da grama gigante: configurar em metros e derivar
    a escala.
  - **Três defeitos que o teste novo pegou, e um que ele deixou passar:**
    1. *Rodízio em vez de sorteio*: com `i % tamanho` e 4 pedestres por rota, as
       18 rotas usavam os mesmos 4 primeiros modelos — a cidade tinha 31
       disponíveis e mostrava **6**. Sorteando, foram a **29**.
    2. *Modelo sem animação nenhuma* (`anime_girl_rigged`) andava de **T-pose**
       pela rua. Saiu do pool de NPC (como jogador continua, que é escolha de
       quem joga).
    3. *Todos do mesmo modelo saíam idênticos*: o tinturador casa material por
       NOME, e nome de modelo baixado não casa. O `street_test` pegou 10 iguais
       em 72. Agora há um desvio leve de tom por NPC também pra esses — 60
       aparências distintas em 72.
    4. E o que ele deixou passar: minha checagem de altura mediu **zero**
       pedestres e mesmo assim disse "ok", porque eu procurava o visual como "o
       primeiro filho Node3D" e pegava a `CollisionShape3D`. Passou a procurar
       pelo filho que TEM esqueleto, e a falhar quando não mede nada.
  - **Dois verificadores estavam medindo desenho pela caixa da malha**, e com
    pedestre de modelo de terceiro isso vira alarme falso: o `obstacles_test`
    acusou 6 pedestres como "parede invisível" e 3 com "7 m de sobra" estando
    exatamente dentro da própria cápsula. Corpo com malha skinada passou a ser
    julgado por EXISTIR malha visível, não pelo tamanho da caixa.
  - **Verificação**: `tools/verify/jegue_sheet.tscn` (novo) fotografa os 44 de
    frente e de perfil com a cabeça de jegue e cobra que ela exista e não saia
    pequena demais; `tools/verify/npc_test.tscn` (novo) carrega a cidade e cobra
    variedade, animação, altura e visibilidade dos 72 pedestres. Suíte inteira
    passa (16 testes). As fotos foram olhadas linha a linha — é o que pegou a
    cabeça deitada feito chapéu, a que sumia dentro da humana e a do Rem no
    torso.

- **2026-08-11 (2ª rodada)** — "Continue com testes e tudo o resto". Fechado o
  ciclo: os testes que faltavam, o custo da cidade medido, e as builds
  reexportadas e publicadas.
  - **A cidade usava 2,5 GB de MEMÓRIA DE TEXTURA**, e isso não era dos
    personagens: medido com o `perf_probe` novo, só a cidade já dava **1960 MB**,
    e os 28 modelos de pedestre somavam +577 MB. A causa é uma só e valia pro
    projeto inteiro: **todas as texturas estavam em `compress/mode=0`**
    (Lossless), que comprime no disco mas na placa de vídeo fica RGBA8 cru —
    1024×1024 vira 4 MB, e são mais de mil.
    - O Godot tem `detect_3d/compress_to=1`, que faria a conversão sozinho, mas
      ele **só dispara quando o EDITOR abre uma cena 3D** que usa a textura.
      Neste projeto tudo é importado headless, então nunca disparou em nada.
    - Com compressão de VRAM ligada (`tools/comprimir_texturas.py`, novo): **2537
      → 916 MB**, uma queda de 64%. Conferido na foto que a rua não mudou.
  - **Cuidado com o número que se olha**: o `.pck` **cresceu** com isso (684 →
    889 MB), porque BPTC tem tamanho fixo em disco enquanto PNG lossless
    comprime. A troca é boa mesmo assim — 1,6 GB a menos de VRAM importa pra
    rodar, e disco é só download. O que resolveu o download foi **empacotar o
    Windows num zip** também (o `.exe` embute o `.pck` sem compressão): os dois
    downloads caíram de 670/756 MB para **464/439 MB**.
  - **O `settings_test` pegou um efeito colateral real dos NPCs novos**: com 29
    modelos de tamanhos diferentes sorteados com `randi()` global, a geometria da
    cidade mudava a cada carga, e o teste — que carrega a cidade uma vez por
    preset — reprovou por 2,7% de diferença que era só o sorteio. O sorteio de
    pedestre passou a ser **semeado** (semente por rota, tirada do RNG semeado da
    cidade). Além de consertar o teste, isso restaura uma propriedade que o save
    depende: a cidade é gerada com semente fixa e tem que voltar idêntica.
  - **Release publicada de verdade**: [v0.3.0](https://github.com/vitudanas/JeguesMecanicos/releases/tag/v0.3.0)
    com os dois zips, já com a cabeça de jegue em todos e os pedestres novos.
    `pack_audit` limpo, `.app` reextraído e o binário exportado sobe sem erro.
  - **Teste instável anotado**: o `audio_test` reprovou uma vez com "clique de
    menu nao tocou nada" no meio de uma bateria de 16 testes, e passou 3 de 3 ao
    rodar sozinho. É dependente de tempo (a voz pode estar ocupada). Não
    investigado — se reprovar de novo isolado, aí é defeito.
  - **`tools/verify/perf_probe.tscn`** (novo): chamadas de desenho, primitivas e
    memória de textura/buffer com a cidade carregada. Mede CONTAGEM do
    renderizador, e não tempo de quadro, pelo motivo já documentado em
    2026-08-04 (o macOS estrangula a janela fora de foco e o tempo mente).

- **2026-08-11 (3ª rodada)** — Fechada a pendência mais antiga em aberto do
  projeto: **a tela de créditos**. Não era enfeite — os 51 modelos de terceiro
  que o build distribui são **CC-BY**, licença que libera uso comercial mas
  **exige crédito**. Sem a tela, o jogo estava fora da licença desde que os
  primeiros pacotes entraram (2026-08-09).
  - `tools/creditos.py` passou a cobrir também os **personagens** (63 licenças
    que estavam de fora — ele só olhava `assets/realistas`) e a gerar, além do
    `docs/creditos.md`, um `assets/creditos.gd` que o JOGO carrega. Em código, e
    não num `.tres`/`.json`, porque recurso escrito à mão já ficou de fora do
    `.pck` neste projeto e o defeito só aparece no binário.
  - **Só é creditado o que de fato VIAJA no build**: o gerador lê o
    `exclude_filter` do `export_presets.cfg` e pula os 33 pacotes cortados. Pacote
    que não é distribuído não precisa (nem deveria) aparecer como se estivesse no
    jogo.
  - `scenes/ui/CreditsMenu.gd` é montada 100% em código, como as telas de
    gráficos e de personagem, e o botão "Créditos" entra no menu principal também
    por código — mexer à mão no `.tscn` já custou o menu inteiro uma vez
    (2026-08-02).
  - O botão de voltar fica no **rodapé fixo**, fora da lista que rola: dentro
    dela cairia abaixo da dobra, que foi exatamente o defeito da tela de
    personagem em 2026-08-10.
  - **Verificação**: o `ui_shot` passou a abrir a tela **pelo botão** (não
    instanciando a classe na mão), fotografar, cobrar que ela tenha tamanho
    (já tivemos tela montada e INVISÍVEL, medindo 0x0) e que liste pelo menos 40
    linhas — crédito que não aparece é o mesmo que crédito nenhum. Hoje são 56.
    Conferido também que `creditos.gd` está dentro do `.pck` exportado.

- **2026-08-13** — Entrada do Codex no fluxo compartilhado com o Claude. Feito
  um inventário completo dos **2.097 arquivos versionados** e lido o conteúdo
  autoral legível do projeto: configuração/exportação, autoloads, scripts de
  gameplay, geradores do mundo, UI, shaders, cenas, documentação, ferramentas,
  pipelines de assets e a suíte de verificação. Modelos 3D, imagens, áudio,
  cenas binárias `.scn`, builds e o cache `.godot` foram catalogados por tipo,
  caminho, dependência e metadados — são artefatos binários/gerados, não texto
  fonte para leitura linha a linha. O worktree estava limpo e sincronizado com
  `origin/main` (`c15b772`) no começo da leitura; nenhum arquivo de jogo foi
  alterado e nenhum teste/build foi rodado, porque esta rodada foi somente de
  familiarização.
  - **Achado não corrigido:** `tools/build_characters.py:34` ainda fixa
    `ROOT` apontando para um caminho absoluto ligado a uma conta local,
    caminho anterior à mudança documentada de 2026-08-08 para
    `/Users/Shared/JOGO2`. Se o pipeline de personagens nativos precisar ser
    executado novamente, ele falhará ou trabalhará no lugar errado; convém
    derivar o caminho a partir do próprio arquivo antes de rodá-lo.

- **2026-08-13 (coordenação Codex + Claude)** — A pedido do usuário, criado
  `AGENTS.md` na raiz com uma divisão temporária de trabalho, válida até
  **2026-08-31 inclusive** (`America/Sao_Paulo`). Durante a vigência, o **Codex**
  faz as implementações, a primeira bateria de testes, as correções iniciais,
  documenta a rodada, reexporta/verifica as builds quando o jogo mudar e cria e
  envia o commit ao GitHub. Depois do handoff pelo hash do commit, o **Claude**
  revisa integralmente o diff e executa testes adicionais/de regressão; os
  problemas encontrados voltam ao Codex para correção e novo commit, seguidos
  de nova revisão. Uma ordem direta posterior do usuário pode mudar a divisão,
  e ela não se renova automaticamente depois de agosto. Esta rodada alterou
  somente documentação e regras de colaboração; nenhum arquivo do jogo mudou,
  portanto não houve teste nem reexportação de build.

- **2026-08-13 (Codex — negociação em rodadas)** — A venda deixou de ser a
  barra automática de "segure E" e ganhou **contraproposta e blefe de verdade**.
  O cliente agora abre com dinheiro garantido abaixo do teto e o jogador escolhe
  entre **E aceitar**, **Q contrapropor** e **F blefar**. Cada personalidade tem
  oferta inicial, chance de ceder, chance de cair no blefe e número de rodadas
  próprios. A chance exata aparece antes da ação e varia com reputação, preço
  exagerado, gambiarras quebradas e insistência na conversa.
  - A contraproposta é a via segura: quando aceita, fecha 38% do espaço restante
    até o teto; cada tentativa consome uma rodada. O blefe só pode ser tentado
    uma vez: acertando, fecha 82% do espaço; descoberto, corta 10% da oferta e
    consome duas rodadas. A oferta inicial sempre pode ser aceita, portanto o
    sorteio nunca torna uma entrega impossível.
  - `PersuasionMinigame.gd` virou o estado puro/determinístico da conversa;
    `BuyerNPC.gd` calcula chance, sorteia a reação, atualiza o HUD e credita
    exatamente o valor aceito. `Player.gd` ganhou a borda de subida do F para o
    blefe sem quebrar o mesmo F que sai do carro. Se o carro rolar para fora da
    zona, a conversa é cancelada e o painel não fica preso.
  - O HUD mostra oferta/pedido/rodadas e usa a barra como progresso entre oferta
    inicial e teto. Prompt e dicas de carregamento ensinam as três teclas. A
    foto real `user://loop_shots/08_negociacao.png` foi inspecionada: textos,
    probabilidades, cliente e painel ficaram legíveis, sem sobreposição.
  - `economy_test` cobre os seis clientes, oferta garantida, sucesso/falha das
    duas jogadas, custo de rodadas, blefe único e queda de chance por exagero.
    `loop_test` usa Q/F/E reais, aceita a oferta mostrada e cobra que a carteira
    receba exatamente aquele valor. Rodou uma bateria de **17 cenas**, todas
    aprovadas: city, drive, loop, attach, scale, yard, audio, obstacles, save,
    loading, economy, shop, staff, character, street, gaps e npc.
  - Builds reexportadas: Windows `.exe` **998.525.160 bytes** e zip
    **464.559.207 bytes**; macOS zip **486.844.503 bytes**. `pack_audit` conferiu
    o `.pck` de 889 MB, 105 referências, 71 caminhos montados em runtime e o
    catálogo de personagens: limpo. O `.app` foi extraído do zip novo,
    `codesign --verify --deep --strict` passou e o binário exportado abriu em
    headless por 120 frames sem erro de recurso.
  - Durante a rodada apareceu uma mudança paralela não feita pelo Codex em
    `tools/build_characters.py`, trocando o caminho absoluto antigo por um caminho
    derivado de `__file__`. Ela foi preservada e ficou fora do commit desta
    implementação para não misturar autoria/escopo.

- **2026-08-13 (Claude — revisão do `1a92401` e a correção do caminho)** —
  Revisado o commit de entrada do Codex: ele mexe **só em documentação**
  (`AGENTS.md` novo e duas entradas aqui), então não havia nada funcional a
  revisar. As afirmações de estado batem — worktree limpo, `HEAD ==
  origin/main`; a contagem de arquivos versionados dá 2.098 contra os 2.097
  registrados, e a diferença é o próprio `AGENTS.md`.
  - **O achado técnico dele estava certo**, e o usuário pediu explicitamente que
    eu corrigisse — ordem direta, que o `AGENTS.md` prevê como exceção à divisão.
    `tools/build_characters.py` fixava
    um caminho absoluto ligado a uma conta local, caminho que deixou de
    existir na mudança de 2026-08-08 pra `/Users/Shared/JOGO2`. Agora sai do
    PRÓPRIO arquivo (`tools/..` é a raiz): o Blender recebe o script por
    `--python tools/build_characters.py`, então `__file__` resolve.
  - **Verificado RODANDO, e não só conferindo a conta.** Copiei o script pra
    dentro de `tools/` (pra `__file__` derivar a mesma raiz) com o destino
    trocado por um diretório de rascunho e rodei o Blender headless: ele
    completou e gerou os dois personagens **byte a byte idênticos** aos do
    repositório (11.187.972 e 10.171.036 bytes, diferença zero). Prova duas
    coisas de uma vez — a correção funciona e o pipeline continua reprodutível.
    O destino de rascunho foi de propósito: regenerar os nativos por causa de um
    conserto de caminho arriscaria justamente os dois arquivos em que a cabeça de
    jegue, as alturas (1,788/1,852) e as shape keys são calibradas.
  - **Lição de fluxo, com dois agentes no mesmo worktree**: no meio da
    verificação apareceram 10 arquivos modificados que não eram meus (a
    negociação, ainda em andamento). `git add -A` — que é o que eu vinha usando —
    teria varrido o trabalho do Codex pra dentro do meu commit. Daqui pra frente,
    adicionar arquivo por arquivo. O `CLAUDE.md` também mudou embaixo de mim
    enquanto eu escrevia: quando isso acontecer, reler antes de gravar, senão a
    anotação do outro some.

- **2026-08-13 (Claude — revisão do `f561f2b`, a negociação em rodadas)** —
  Revisado o commit inteiro (11 arquivos, +477/−233) e rodadas duas baterias
  próprias. **O que o Codex entregou está correto**: a mecânica funciona, a
  aritmética fecha e a suíte passa. Achei quatro coisas, e só a primeira é
  problema de jogo de verdade.
  - **Regressão de API: zero.** Varri o projeto atrás das chaves que sumiram
    (`enche`, `esvazia`, `paciencia`) e da API antiga do minigame (`fill_rate`,
    `drain_rate`, `_difficulty`, `.persuasion`): **nenhum consumidor órfão**
    fora dos testes, que foram atualizados junto. O som novo `"abre"` existe de
    verdade em `AudioManager.SOUNDS` (`interface/open_001.ogg`) — vale conferir
    porque `play_ui` com chave inexistente falha calada.
  - **Testes que rodei** (não os do Codex, os meus): `economy_test` passa
    inteiro, incluindo as seções novas [3] e [4] e a trava "a seção rodou até o
    fim"; `loop_test` fecha de ponta a ponta pelo caminho de INPUT real
    (`negociação abriu em R$ 22 de um teto R$ 28` → Q gastou rodada → F caiu no
    blefe R$ 22 → R$ 27 → E creditou **exatamente** R$ 27). A trava nova
    `gained != accepted` é a melhor parte do diff: o teste antigo só cobrava
    `gained > 0`, que passaria com o valor errado.
  - **[BUG, pra devolver ao Codex] Dá pra rezerar a negociação tirando o carro
    da zona e recolocando.** `_on_car_exited` chama `_cancel_negotiation()`, que
    zera `minigame_running`; ao reestacionar, o E seguinte cai no ramo de abrir
    e chama `negotiation.start(...)`, que **restaura a oferta de abertura, as
    rodadas cheias e `bluff_used = false`**. Ou seja: blefe descoberto (−10% e
    duas rodadas) e sequência de contrapropostas fracassadas são apagados de
    graça — basta entrar no carro, sair da zona e voltar. Custa ~15 s e sempre
    vale a pena, então na prática **o risco das duas jogadas deixa de existir**,
    que é justamente a decisão que a rodada foi criada pra introduzir. Não é
    crash e não aparece em teste nenhum, porque nenhum deles reestaciona. O
    cancelamento em si está certo (sem ele o HUD prende); o que falta é a
    conversa lembrar do que já aconteceu com aquele carro — guardar o estado por
    veículo e retomar em vez de recomeçar, ou pelo menos não devolver o blefe.
    **Provado rodando, não só lendo** (`tools/verify/rematch_test.tscn`, novo,
    fica no repo como trava de regressão): Colecionador, carro em ordem e 4/4
    gambiarras — abre em R$ 128 com 3 rodadas (teto R$ 173), blefe descoberto
    derruba pra R$ 115 e sobra 1 rodada; `_on_car_exited` + `_on_car_entered` +
    E e **volta exatamente pra R$ 128, 3 rodadas e `bluff_used = false`**. São
    R$ 13 de volta na hora, mais o blefe de novo na mão (até 82% do vão de
    R$ 45), e dá pra repetir até acertar. O teste **falha hoje**, de propósito:
    passa quando o castigo sobreviver.
  - **[BUG visual, e só a FOTO pegou] A terceira linha do prompt sai pra fora
    da caixa.** Rodei `tools/verify/loop_shots.tscn` e ampliei o
    `08_negociacao.png`: a linha `[E] aceitar · [Q] contrapropor (10%) · [F]
    blefar (5%) · 3 rodada(s)` **estoura o painel dos DOIS lados** — o `[E]` no
    começo e o `rodada(s)` no fim ficam desenhados por cima do concreto, sem o
    fundo escuro atrás, e a linha assenta em cima da borda inferior
    arredondada. Causa: o `CenterPrompt` tem 40 px de altura (`offset_top` 27,
    `offset_bottom` 67), fonte 19, **sem autowrap**, e o prompt novo tem 3
    linhas com a de controles passando de 68 caracteres; Label do Godot não
    recorta por padrão, então transborda em vez de sumir. É a interseção das
    duas rodadas: no commit puro não há painel e o transbordo é invisível, mas
    a rodada de HUD em andamento acrescenta o `PromptPanel` (50 px), e aí o
    defeito fica gritante. Quem for arrumar: ou o prompt cabe em 2 linhas, ou o
    painel/label crescem junto com o texto. O `negotiation_label` do HUD, esse,
    está **certo e confirmado na foto** — "Oferta R$ 67 / pedido R$ 126 · 3
    rodada(s)" aparece no painel de cima, na pilha, sem sobrepor nada, e a barra
    acompanha (38% pro caso fotografado, que é a conta certa).
  - **[Balanceamento, visto na mesma foto] Com o Abutre, o preço PADRÃO já
    satura as duas chances no piso** (Q 10%, F 5%). O `ask_step` nasce em 1
    ("camarada", 0.85× do mercado) e isso já dá R$ 126 contra um teto de ~R$ 93
    dele — ou seja, o jogador nem escolheu exagerar e a negociação já chegou
    morta, sobrando só apertar E. Não é defeito de código (o Abutre é o
    lowballer de propósito), mas vale decidir se o piso devia ser mais alto ou
    se o prompt devia sugerir baixar o preço com Q antes de abrir a conversa.
  - **[Limpeza] Duas coisas mortas**: `PersuasionMinigame.changed` é emitido
    4× e **não tem um único `connect`** no projeto, e `BuyerNPC._offer()` ficou
    sem nenhuma chamada depois que `_complete_sale` passou a receber o valor por
    parâmetro. Nenhum dos dois quebra nada; o sinal morto é o mais enganoso,
    porque parece que a UI reage sozinha ao estado e ela não reage.
  - **O `.app` que o usuário abre estava DESATUALIZADO de novo** — é a armadilha
    de 2026-08-04, e ela reincidiu. Os zips são de 13/08 12:12–12:13 e batem com
    os bytes anotados pelo Codex, mas
    `builds/macos/Jegues Mecanicos.app` extraído é de **11/08 21:17**, com um
    `.pck` de 889.309.244 bytes contra 889.312.988 no zip novo. Quem der dois
    cliques nele hoje joga o build anterior à negociação, sem aviso nenhum.
    **Reextrair (ou apagar o antigo) faz parte de reexportar** — o zip é o
    artefato, o `.app` é o que o usuário abre, e ele não se atualiza sozinho.
    **[RESOLVIDO no mesmo dia]** o Codex reexportou e reextraiu: o `.pck` do
    `.app` agora tem 888.996.516 bytes com a mesma data do que está dentro do
    zip publicado — conferido byte a byte, não pela data da pasta.
    - **CORREÇÃO DE UM ERRO MEU, e ela importa pra quem for repetir o teste:**
      eu tinha escrito aqui que "o `.pck` velho não tem a string
      `contrapropor`". **Esse método não vale.** Fui conferir no build NOVO e
      ele também não tem a string — GDScript entra no `.pck` compilado, não
      como texto, então `grep` numa string de código dá 0 nos dois e "prova"
      qualquer coisa que você quiser. O que de fato distingue um build do outro
      é **tamanho e data do `.pck`**, que foi o sinal correto o tempo todo. Pra
      olhar dentro do pacote de verdade existe o `tools/verify/pack_audit.py`,
      que sabe o formato.
  - **RESSALVA DE WORKTREE, e ela limita esta revisão:** comecei com a árvore
    limpa em `9692181` e, no meio da revisão, apareceram **5 arquivos de UI
    modificados que não são meus** (`HUD.gd`, `HUD.tscn`, `LoadingScreen.gd`,
    `MainMenu.gd`, `MainMenu.tscn`, +760/−91), com mtime avançando enquanto eu
    trabalhava (o `HUD.tscn` mudou 30 s antes de eu olhar). É outra rodada em
    andamento — painel de prompt, velocímetro, etapa do loop, clima no HUD. Não
    toquei em nenhum deles.
    **Minha primeira reação foi pular o teste visual por causa disso, e estava
    errada** — o usuário corrigiu na hora: teste prático é parte do trabalho do
    revisor, não item opcional (a regra foi pro `AGENTS.md`). Rodei assim mesmo,
    e foi justamente a foto que achou o transbordo do prompt, que nenhuma das
    duas baterias numéricas pegava. **Estado fotografado**: commit `f561f2b` +
    a rodada de HUD em andamento — o que aliás foi melhor, porque é a combinação
    das duas que produz o defeito. O `loop_test` terminou 12:30:25, antes de
    `HUD.gd`/`HUD.tscn` serem tocados (12:33:15), então esse resultado vale para
    o commit puro. Também por isso o `pack_audit` acusa
    `LoadingScreen.gd`/`MainMenu.gd`/`MainMenu.tscn` "mais novos que o build":
    é a rodada em andamento, **não** falha de exportação do Codex — o build de
    12:12 contém sim o commit revisado (`BuyerNPC.gd` é de 12:06).
  - **Testes práticos desta revisão** (além de ler o diff): `economy_test` e
    `loop_test` headless, `loop_shots` em janela real com as 8 fotos **olhadas
    uma a uma** (foi a 08 que denunciou o prompt), `rematch_test` novo escrito
    pra reproduzir o exploit, e `pack_audit` mais a inspeção do `.pck` dentro do
    zip contra o `.pck` do `.app` extraído (foi assim que a build velha
    apareceu).

- **2026-08-13 (Claude — 2ª revisão: `1e9fce1`, `9ce5f61`, `cb30b6e`)** — O
  usuário pediu pra ver se faltava teste. Faltava, e valeu: o Codex tinha
  corrigido os três achados da revisão anterior enquanto eu escrevia, então
  rodei a suíte inteira contra o estado novo. **Dois dos três consertos estão
  provados; um não foi feito; e o conserto do principal abriu um furo novo.**
  - **O exploit de rezerar a conversa está FECHADO, e é o meu próprio teste que
    prova.** A solução do Codex é boa: `negotiation_vehicle` guarda a qual carro
    a conversa pertence e `PersuasionMinigame.resume()` reativa o mesmo estado
    em vez de `start()`. O `rematch_test` que na revisão passada acusava 3
    problemas agora passa limpo — R$ 143 continua R$ 143, 1 rodada continua 1,
    `bluff_used` continua `true`. Q também foi trancado durante a conversa
    pausada, o que fecha a mesma brecha pela outra porta (trocar o pedido
    mudaria o teto sem pagar rodada), e o prompt passou a avisar
    ("Oferta pausada: R$ 127 · 1 rodada(s) · [E] retomar a conversa") — testei
    as duas coisas, seções [4] do `rematch_test`.
  - **[BUG NOVO, criado pela correção] A conversa pausada CONGELA o preço do
    carro inteiro.** Medido na seção [5] que acrescentei ao `rematch_test`: com
    4/4 gambiarras o teto é R$ 190; perdendo as 4 o teto cai pra R$ 76; mas ao
    retomar, a oferta continua **R$ 127** — R$ 51 acima do que o carro vale
    agora, 67% de sobrepreço. O caminho é o mesmo que o exploit antigo usava:
    abre a conversa, o carro sai da zona, o jogador dá a volta, bate num buraco
    e volta com menos gambiarra — e recebe pelo carro que já não existe. Antes
    não dava, porque não havia pausa: o teto era recalculado a cada abertura. A
    correção é pequena e não desfaz nada do que foi ganho: no `resume()`,
    reancorar no valor de hoje (`current_offer = min(current_offer, teto_novo)`)
    — a oferta continua sem poder SUBIR, que é o castigo que se quis preservar,
    e deixa de poder ficar acima do carro. O teste já cobra essa invariante e
    **falha hoje**.
  - **[NÃO corrigido] O prompt de 3 linhas continua vazando pra fora do
    painel.** Refotografei depois do redesenho do HUD (`loop_shots`,
    `08_negociacao.png`) e está igual: `[E] aceitar · [Q] contrapropor (10%) ·
    [F] blefar (5%) · 3 rodada(s)` começa antes da borda esquerda e termina
    depois da direita, as duas pontas desenhadas sobre o chão sem fundo atrás.
    O redesenho mexeu no painel (agora `PromptPanel`, 50 px) mas não no
    tamanho do texto nem na altura do `CenterPrompt` (40 px, fonte 19, sem
    autowrap).
  - **[RESOLVIDO] Build e release.** O `.app` foi reextraído — o `.pck` dele
    tem 888.996.516 bytes, os mesmos do que está dentro do zip publicado
    (conferido byte a byte, não pela data da pasta) — e a
    [v0.3.1](https://github.com/vitudanas/JeguesMecanicos/releases/tag/v0.3.1) saiu
    com os dois artefatos. `pack_audit` limpo: 105 referências, 71 caminhos de
    runtime, nada mais novo que o build.
  - **Suíte rodada nesta revisão, toda passando menos a seção nova**: `rematch`
    (seções 1-4 ok, 5 falha de propósito), `economy`, `shop`, `save`, `audio`,
    `staff`, `loop`, `drive` — headless; `loop_shots` e `ui_shot` em janela
    real, com as fotos olhadas. O `drive_test` importava porque o `Player.gd`
    trocou o F de "tecla segurada" pra borda de subida (pra não gastar as
    rodadas da conversa num toque só) e o F é a mesma tecla que sai do carro:
    passa, sem regressão. O `audio_test`, que o handoff marcava como instável,
    passou de primeira aqui.
  - **Menus novos conferidos na foto** (ninguém tinha olhado): menu principal e
    tela de carregamento estão bem montados, sem transbordo, sem controle fora
    da dobra, e o "Continuar (R$ 308 · 1 carro vendido)" lê certo. Os erros de
    parse de `Town.tscn` no fim do `ui_shot` são o artefato já documentado em
    2026-08-08 (árvore destruída com a carga em thread ainda em voo, depois do
    resultado impresso), não defeito de cena.

- **2026-08-13 (Claude — 3ª revisão: `426c45d`, `9c91289`, e a auditoria do
  git)** — Fechou o ciclo desta rodada: **todos os achados das duas revisões
  anteriores estão corrigidos e verificados**, cada um pelo mesmo método que
  tinha exposto o defeito.
  - **Preço congelado: CORRIGIDO** exatamente como sugerido — `resume()` passou
    a receber o teto de hoje e reancorar (`current_offer = min(atual, teto)`,
    sem nunca subir). Medido pelo `rematch_test`: teto cai de R$ 241 pra R$ 97
    ao perder as 4 gambiarras e a oferta retomada acompanha (R$ 97, era R$ 127).
    As cinco seções do teste passam.
  - **Transbordo do prompt: CORRIGIDO, e conferido na FOTO** (não na conta).
    O `set_prompt` passou a crescer o painel por linha (`text.count("\n") * 20`)
    e o `CenterPrompt` foi de 510 pra 800 px de largura com a fonte em 16 (o
    painel, 840). Refotografado: as três linhas cabem dentro da caixa com folga
    dos dois lados.
  - **`.app` e release: CORRIGIDOS.** O `.pck` do `.app` bate byte a byte com o
    do zip publicado, e a v0.3.2 já carrega os consertos.
  - **Suíte rodada nesta revisão**: `scale`, `obstacles`, `street`, `gaps`,
    `npc`, `attach`, `yard`, `loading`, `character`, `city` — todas passam. Os
    commits mexiam em `Town.tscn`, `Junkyard.tscn`, `RuralWorkshop.tscn` e no
    `mountain.gdshader`, então valia rodar o bloco de mundo inteiro.
  - **Erro meu de arnês, e é o que este arquivo mais repete**: montei o laço da
    suíte com `godot ... cena.tscn || godot ... cena_test.tscn`, e **o Godot sai
    com código 0 mesmo quando a cena não carrega** — então o `||` nunca disparou
    e `scale`, `obstacles`, `street` e `gaps` **não rodaram**, imprimindo
    "EXIT=0 | falhas: 0" como se tivessem passado. Só apareceu porque fui
    conferir se cada log tinha a linha `RESULTADO`. Lição: com Godot, **código
    de saída não é veredito** — quem diz se rodou é a saída do próprio teste.
  - **[ACHADO DO ARNÊS] `tools/verify/gaps_test.gd` não tem verificação
    nenhuma**: zero `check`, zero contador de falha, um `get_tree().quit()` seco.
    Ele imprime o censo (hoje 93% de borda com fachada, 0 borda vazia) e sai com
    0 **sempre**. Se a cobertura despencasse pra 40%, ele imprimiria 40% e
    passaria. É um relatório, não uma trava — vale dar a ele um piso que reprove.
  - **[ACHADO, e bate direto na regra nova de publicação] Há dois `.pyc`
    rastreados no repo, e um deles vaza o caminho da conta local.**
    `tools/__pycache__/expand_world.cpython-314.pyc` e
    `tools/verify/__pycache__/patch.cpython-314.pyc` estão no HEAD, e o segundo
    embute um caminho absoluto ligado à conta local — nome de conta **e** o
    caminho antigo, de antes da mudança pra
    `/Users/Shared`. Bytecode é saída de build e não deveria estar versionado de
    todo jeito, e o `.gitignore` **não tem regra de `__pycache__`/`*.pyc`**,
    então eles voltam sozinhos. Conserto:
    ```
    printf '\n# Bytecode do Python (saida de build, e embute caminho local)\n__pycache__/\n*.pyc\n' >> .gitignore
    git rm -r --cached tools/__pycache__ tools/verify/__pycache__
    ```
    O **histórico** também carrega esse caminho (5 commits, achados com
    `git log -S`), e a regra nova pede auditar o histórico antes de publicar —
    mas isso só sai com reescrita, que é decisão do usuário, não conserto de
    rodada.
  - **Auditoria do git** (pedida pelo usuário): está configurado e em uso de
    verdade — remoto certo (já apontando pro nome novo `JeguesMecanicos`), 96+
    commits, 2.101 arquivos, nada pendente nos dois sentidos, `.gitignore`
    cobrindo `builds/` e os downloads crus, e a reescrita que tirou o blob de
    195 MB deixou aqueles commits como órfãos, fora do `main`. As regras de COMO
    usar foram pro `AGENTS.md` ("Regras de git"). **`git gc` rodado**: o repo
    não tinha um único packfile — 4.488 objetos soltos, 829 MB — e agora está em
    2 packs, 770 MB. O resto do peso são os órfãos presos pelo reflog; só saem
    com `reflog expire` + `gc --prune=now`, que descarta pontos de recuperação e
    ficou pra decisão do usuário.
  - **Sobra só o cosmético**, sem impacto em jogo: `PersuasionMinigame.changed`
    continua sendo emitido 4× sem um único `connect`, e `BuyerNPC._offer()`
    continua sem chamador. E a observação de balanceamento do Abutre (o preço
    padrão já satura Q e F no piso) segue em aberto como decisão de design.

- **2026-08-13 (Claude — fiscalização contínua: `fb7b78c`, `80ba1e3`,
  `15c9811`, `3cc38d3`)** — O usuário pediu para eu acompanhar o Codex enquanto
  ele implementa. Montei um vigia que avisa a cada commit e revisei quatro
  rodadas conforme entraram. Achei **quatro regressões**; duas já foram
  corrigidas e verificadas, duas seguem abertas.
  - **[CORRIGIDO] A serra passou da borda do chão** (`fb7b78c`): pé em 1608
    contra uma meia-largura de 1550 — antes do commit era 1524. A causa era
    dupla e eu só tinha visto metade na primeira leitura: o perfil do maciço
    (`pow(1-d, 1.7)` → `1.22`) **mais** o `radius_max` de 190 → 220 no
    `Town.tscn`. O `80ba1e3` alargou o chão pra 3300 (meia-largura 1650) e o
    `city` voltou a passar.
  - **[CORRIGIDO] Voltou uma parede invisível** (`fb7b78c`): 1 corpo do
    `NatureScatter` com 6,7 m de colisão para 4,1 m de malha na altura do carro
    — 2,6 m de ar sólido. Era a `twisted-tree`, que caía do lado errado do
    limiar `SHRINK_MIN`; o `80ba1e3` baixou de 2,5 pra 2,2. **Conferi o efeito
    colateral que isso já causou uma vez** (encolher colisão demais deixa prop
    de telhado sem apoio): `scale_test` com 11.239 objetos, 20 suspensos de
    propósito, **0 boiando**. Limpo.
  - **[CORRIGIDO em `6a62c79`] A emenda do laço da chuva degradou 4× e passava
    raspando.** Medido
    nos meus próprios runs: 0.060 a 22.050 Hz, **0.241** depois que o `RATE`
    foi a 44.100 no `fb7b78c`. O limiar de reprovação é 0.35, calibrado quando
    o valor era 0,06 — ou seja, hoje ele não protege mais nada. Contra um pico
    de 0,66, um salto de 0,241 é ~36%: estalo audível a cada 2,5 s enquanto
    chove. Motor gravado dá 0.000 e a cama urbana 0.002, então era a chuva
    especificamente. **O conserto é elegante e eu medi**: em vez de mexer na
    síntese, o `_rotate_to_best_seam` rotaciona o buffer para que o par de
    amostras vizinhas com menor salto vire a fronteira do laço — rotacionar um
    laço não muda duração nem timbre, só escolhe o ponto mais contínuo para ser
    a emenda. Chuva foi a **0.000**, e o limiar do teste desceu de 0,35 para
    **0,02**, ou seja ele voltou a proteger (os três laços passam com margem de
    10× ou mais). Aqui vale o registro do acerto: quando o teste flagrou o
    problema, o Codex **apertou** o limiar em vez de afrouxar.
  - **[CORRIGIDO no estado final `03207f7`; revisão iniciada em `a445a10`] A variedade de pedestres caiu de 28 para 7
    modelos** (−75%,
    `15c9811`). O filtro novo é justificado — 23 modelos tinham só um clipe de
    pose e deslizavam feito estátua — mas o custo não foi medido em lugar
    nenhum, e o `npc_test` só exige **≥5 modelos**, piso muito abaixo de onde o
    projeto estava (2026-08-10: 59 aparências distintas em 72 pedestres). O
    caminho para recuperar é retargetar a UAL1 nos esqueletos descartados, não
    deixá-los de fora. **Foi o que ele fez, e medi o resultado: 7 → 23 modelos
    distintos**, com barra mais alta que os 28 originais — modelos que vieram só
    com pose recebem uma caminhada doadora do próprio acervo, copiando **apenas
    rotações** (nunca translação/escala, porque cada pacote veio numa unidade
    diferente). Dois detalhes que valem a lição: o critério de "tem locomoção"
    virou uma métrica compartilhada (`animation_limb_motion_score` conta quantas
    trilhas de membro mudam de rotação ao longo do clipe — pose única dá 0, uma
    caminhada Mixamo dá 29), lida pelo catálogo E pelo teste, que é o princípio
    de dono único que este arquivo repete; e apareceu um clipe de 32,9 s
    (`character_girl_animated_walk`) que é timeline de cena, não ciclo de
    passada, e ficava congelado no intervalo prático mesmo com o relógio
    andando.
  - **[CORRIGIDO em `39dbcef`] Duas câmeras do `world_tour`
    fotografavam outra coisa que não o nome delas.** O `15c9811` atualizou as
    câmeras da cidade (03-06) para a grade nova de ±360, com comentário
    explicando que as antigas cobriam só o protótipo — mas deixou duas para
    trás: `16_cordilheira` fica em (-140, 6, 190) olhando (-40, 60, 330), as
    duas coordenadas **dentro da cidade**, e sai com telhados no quadro; e
    `17_transicao_campo_cidade` fica em (150, 30, 150) olhando (0, 8, 0), ou
    seja **centro para centro**, sem um metro de campo. A serra fica a raio
    900-1600. Consequência: o Codex citou `world_tour` como validação de um
    commit cuja mudança principal são os maciços da serra, e **a foto da serra
    não fotografa a serra**. É a mesma classe de defeito que este arquivo já
    registrava ("Câmera 04 ficava em (30, 2.2, 30), que com a grade nova cai
    DENTRO de um quarteirão") — volta a cada vez que o mundo cresce. **O
    conserto ganhou travas**: as duas câmeras foram levadas ao raio rural e o
    teste agora reprova se a 16 voltar a apontar para a cidade ou se a 17 não
    atravessar campo e cidade. Refotografei: a 16 mostra os maciços
    com a base no quadro e a 17 mostra campo em primeiro plano, skyline no meio
    e serra ao fundo. Na mesma rodada o `gaps_test` finalmente ganhou veredito
    (`problems` + `RESULTADO` + saída 1), fechando o outro achado de arnês, e o
    ferro-velho rural ganhou pátio de cascalho com destroços — era campo vazio
    com três pinheiros.
  - **Observações da folha de contato** (montei as 6 fotos não olhadas numa
    imagem só, que é o jeito de varrer um tour inteiro sem gastar uma leitura
    por foto): as ruas do centro e da periferia saem **completamente vazias**,
    sem um carro ou pedestre no quadro; o ferro-velho rural lê como campo vazio
    com três pinheiros e duas caixas; e a estrada de terra nova, com a textura
    PBR do Gravel Road, ficou num laranja bem mais saturado que o resto da
    paleta. Nada disso é defeito de código — é material para decisão de arte.
  - **O que verifiquei e estava certo**: os ajustes de teste do `15c9811`
    **apertam** em vez de afrouxar (o `npc_test` agora reprova se algum
    pedestre depender da locomoção procedural e mede progresso temporal do
    clipe em 0,25 s); o ajuste do `obstacles_test` no `80ba1e3` é só
    diagnóstico (passou a imprimir de qual modelo é o corpo, que era
    `@StaticBody3D@28056`, ilegível); as licenças novas (PolyHaven Gravel Road,
    OpenGameArt motor e vento) são CC0 com autor, fonte e arquivo, com créditos
    atualizados no jogo e no `docs/`; e a assinatura de `animar_com_o_proprio`
    mudou com parâmetro padrão, sem quebrar o `PlayerVisual`.
  - **Duas hipóteses minhas que se provaram erradas**, e vale registrar as
    duas: achei que o agrupamento em bosques do `RuralScatter` plantasse sem
    validar (não — a linha 131 revalida com `_is_valid`), e ia culpar o commit
    pela árvore atravessando a cerca da fazenda (não é dele — o `FarmCluster`
    só ganhou fardos, cocho e terra arada; a distribuição de árvore não mudou).
  - **Auditoria do repositório agora que ele é PÚBLICO** (`3cc38d3`): varri o
    histórico inteiro e está limpo — só e-mails `noreply`, **0** commits com o
    caminho da conta local, **0** arquivos sensíveis rastreados (`.env`, `.pem`,
    `.key`, `.pyc`, credenciais), e **nenhum** padrão real de chave
    (`sk-…`, `ghp_…`, `AKIA…`, `xox…`, `BEGIN PRIVATE KEY`) em 200 revisões
    varridas. O bundle de 805 MB com o histórico pré-higienização está em
    `/Users/Shared/`, **fora** do repo, que é onde deve ficar — ele contém o
    e-mail e os caminhos removidos e nunca pode ser publicado.
  - **Erro meu de arnês nesta rodada**: montei o laço da suíte com
    `godot cena.tscn || godot cena_test.tscn` e, como **o Godot sai com código
    0 mesmo quando a cena não carrega**, o `||` nunca disparou — quatro testes
    não rodaram e imprimiram "EXIT=0 | falhas: 0" como se tivessem passado. Só
    apareceu porque fui conferir se cada log tinha a linha `RESULTADO`. Com
    Godot, **código de saída não é veredito**.

### ONDE PAREI (2026-08-13, Codex)

Estado: negociação em rodadas implementada e validada, suíte desta rodada
passando (17 cenas), builds Windows/macOS reexportadas e binário macOS real
verificado. A release pública continua sendo a
[v0.3.0](https://github.com/vitudanas/JeguesMecanicos/releases/tag/v0.3.0); os zips
novos desta rodada ainda não foram anexados a uma nova release.

**Personagens:** **44 jogáveis** no menu (2 nativos + 42 baixados) de 63
arquivos recebidos; os outros 21 estão catalogados como cenário e ficam FORA do
build. **43 dos 44 aceitam cabeça de jegue** (o `rem_rezero` não tem osso de
cabeça no rig). **31 também são pedestres**, e a cidade mostra 29 modelos
distintos entre os 72 que andam na rua.

Pra acrescentar mais, na ordem (cada passo depende do anterior):

```bash
tools/receber_modelos.sh personagens     # recolhe .zip E pasta ja aberta da raiz
godot --headless --path . --editor --quit          # importa
python3 tools/preparar_import_personagens.py       # capa textura, VRAM, morph, filtro do build
godot --headless --path . --editor --quit          # reimporta com os ajustes
godot --headless --path . tools/preparar_personagens.tscn   # mede e cataloga
python3 tools/creditos.py                          # CC-BY: credito e obrigatorio
godot --path . tools/verify/personagens_sheet.tscn          # e OLHE as fotos
godot --path . tools/verify/jegue_sheet.tscn                # idem, com cabeca de jegue
```

A folha não é opcional: **a orientação e o material não se medem** (ver o
cabeçalho de `MedirPersonagem.gd`). Quem sair de costas na foto entra em
`DE_COSTAS`, quem sair quebrado entra em `NAO_SERVE`, os dois em
`tools/preparar_personagens.gd`.

**O QUE FALTA:**

1. **MÚSICA.** É o maior buraco que sobra: efeitos, ambiente e motor estão
   cobertos desde 2026-08-08/09, mas o jogo não tem trilha nenhuma. Ficou de
   fora de propósito — é o item que menos dá pra decidir sem ouvir.
2. **Jogar com as mãos.** O loop é testado de ponta a ponta com input real, mas
   ninguém *sentiu* o jogo: se 76 km/h é rápido demais, se as chances/rodadas da
   negociação são divertidas, se o reboque é chato. Só se resolve jogando.
3. **Pose de portfólio em alguns modelos**: `ada_wong` e `old_man_in_coat` ficam
   inclinados porque é a ÚNICA animação que veio no arquivo, e `rem_rezero` só
   traz T-pose/A-pose. Não tem conserto por script — precisaria de retarget no
   Blender.
4. **Build de 889 MB de `.pck`** (464/439 MB de download). O peso é textura de
   personagem: o botão é a resolução em `tools/preparar_import_personagens.py`
   — 512 em vez de 1024 corta perto da metade, ao custo de nitidez em 3ª pessoa.
5. **`audio_test` instável**: reprovou uma vez com "clique de menu nao tocou
   nada" no meio de uma bateria, e passou 3 de 3 isolado. Se reprovar sozinho,
   aí é defeito.

Pedidos anteriores ainda **não** feitos:

1. **Baixar mais personagens da lista**, se quiser:
   [docs/garimpo-personagens.md](docs/garimpo-personagens.md) tem 30 homens e 18
   mulheres com animação própria, CC-BY, com link direto. É o passo que depende
   de você (o download não sai pelo navegador embutido); o resto é o pipeline
   acima, que não pede edição de código nenhuma.
2. **Os 8 modelos sem esqueleto continuam fora**, e por um motivo medido:
   nenhum deles tem animação e sem rig são estátuas. Como jogáveis, só passando
   pelo Blender (instalado em `/Applications/Blender.app`, e o projeto já roda
   ele headless em `tools/build_characters.py`): rig por peso automático +
   retarget da UAL1. Como cenário (estátua de praça), qualquer um entra hoje.
3. **Rosto e roupa dos NPCs** agora variam por MODELO (29 na rua), mas dois
   pedestres do mesmo modelo continuam com a mesma cara — o que varia neles é
   corpo, altura, cor, acessório e jeito de andar.

**Aviso registrado**: vários personagens são de outras obras (Ada Wong,
Spider-Man, Rem, Mileena). A licença CC-BY cobre **o modelo**, não o personagem
— pra publicar, é risco jurídico de terceiros.

### Pendências pedidas e ainda NÃO feitas

Nenhuma das três pendências anteriores continua aberta. O que sobrou de
observação pra uma próxima rodada (nada disso foi pedido):

1. **Jogar com as mãos.** O loop agora é testado de ponta a ponta com input
   real (`tools/verify/loop_test.tscn`), mas ninguém *sentiu* o jogo: se 76 km/h
   é rápido demais, se contraproposta/blefe têm o ritmo certo, se o reboque de
   38 m é chato. Isso só se resolve jogando.
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
5. **FPS baixo nas fotos de 2026-08-08** (3 a 22 FPS no contador do HUD, durante
   `player_shots`). **Não investigado, e não dá pra concluir nada daí**: o
   roteiro renderiza numa janela de 2940×1846 com o preset padrão, com a câmera
   quase colada no personagem e com o macOS estrangulando janela fora de foco —
   que é exatamente o motivo pelo qual 2026-08-04 trocou "medir tempo de quadro"
   por "contar chamadas de desenho". Se for medir de verdade a meta de 50-80 FPS,
   medir jogando, em tela cheia e com a janela em foco.

## Referência de design: o que copiar dos dois jogos-inspiração

Levantado em 2026-08-09 a pedido do usuário. **Não foi possível assistir
gameplay** (não há como ver vídeo nesta sessão): tudo abaixo veio de página da
Steam, guias, wikis e reviews. Onde a fonte não publica número (custo exato de
upgrade, principalmente), está marcado como desconhecido — não inventar.

### Car For Sale Simulator 2023 (Red Axe Games)

Fonte: [Steam](https://store.steampowered.com/app/2248760/Car_For_Sale_Simulator_2023/),
[guia de preços/clientes](https://steamah.com/car-for-sale-simulator-2023-prices-customers-lowballers-guide/).

- **Valor**: preço-base por modelo + modificadores sorteados (km, avaria,
  pintura, sujeira, combustível, opcionais). Os modificadores derrubam o preço
  **de compra**; o carro "volta a valer o base" depois de comprado.
- **Pechincha na compra**: perícia dá 5% / 10% / 20% de desconto extra por
  nível. **Nunca se negocia acima do preço pedido.**
- **Venda**: o jogador define o preço do anúncio; clientes bons (8-12/dia)
  oferecem 93-107% do valor real, **lowballers** (3-5/dia) oferecem 65-88%.
  Também não dá pra negociar acima do anunciado — daí a estratégia de anunciar
  alto de propósito.
- **O que NÃO muda valor** (contraintuitivo, e é bom saber pra não gastar
  trabalho à toa): lavar, abastecer, foto e título do anúncio. Consertar,
  repintar e tunar mudam pouco.

### Car Dealer Simulator (Garage Monkeys)

Fonte: [Steam](https://store.steampowered.com/app/2404880/Car_Dealer_Simulator/),
[enciclopédia](https://shapes.inc/fandom/car-dealer-simulator),
[dicas](https://gamerblurb.com/articles/car-dealer-simulator-tips-tricks),
[review](https://www.gamegrin.com/reviews/car-dealer-simulator-review/).

Ciclo em 4 fases: **garimpar → restaurar → anunciar → negociar**.

**Áreas do terreno, cada uma com níveis próprios** (é o "upgrade da loja como um
todo" — não é só a oficina):

| Área | Níveis | O que destrava |
|---|---|---|
| Oficina mecânica | 3 | nv.1 bateria e remendo de escapamento; nv.2 elevador → escapamento, freio, suspensão; nv.3 motor, radiador, embreagem |
| Funilaria (body) | 4 | lataria, lixar ferrugem, repintura |
| Lava-jato | 3 | da lavagem na mão ao serviço completo |
| Escritório | 4 | administrativo; no nv.4 entra a **recepcionista** |
| Posto próprio | 3 | abastecer sem sair do terreno |
| Pátio / showroom | — | vagas para expor mais carros ao mesmo tempo |
| Guincho | 2 tipos | rebocar carro que não anda |
| Ferramentas | vários | compradas à parte, destravam serviços |

- **Funcionários**: contratados por um app no computador do jogo e **designados a
  uma estação**. A opção de contratar aparece no **último nível** de cada área
  (oficina, funilaria, lava-jato). Papéis: mecânico, recepcionista.
- **Reputação**: cliente que descobre defeito escondido vai embora e **derruba a
  reputação**; ela destrava progressão.
- **Diagnóstico**: é preciso descobrir o defeito antes de consertar; defeito
  não visto = prejuízo na venda.
- **Detalhe de humor que combina com este projeto**: o jogo tem táticas
  duvidosas, incluindo adulterar odômetro — irmão da gambiarra daqui.

### Como isso mapeia neste projeto

**Já feito** (tudo em 2026-08-09, ver changelog):
- valor por modelo + estado permanente, carcaça com dono, vistoria, pechincha
  com risco, cliente com personalidade;
- **(1)** peças mecânicas com defeito escondido + diagnóstico, e o defeito
  sentido na direção;
- **(2)** a loja com 4 áreas e 3 níveis cada, com a oficina limitando o conserto;
- **(3)** preço pedido pelo jogador + lowballer ("Abutre");
- **(4)** reputação, que cobra o preço de esconder defeito;
- **(5)** funcionários: mecânico e recepcionista, contratados no último nível da
  área (2026-08-09, segunda rodada);
- **(6)** pátio de verdade: 1/2/4 vagas pintadas e limite que recusa o reboque
  (2026-08-09, segunda rodada). Junto veio o **lote do ferro-velho**, que não
  estava na lista e sem o qual as vagas não teriam o que encher.

**Falta:** nada da lista das inspirações. A negociação de verdade
(contraproposta e blefe) foi fechada em 2026-08-13. O que dá pra levar adiante
um dia: funcionário designado a uma ESTAÇÃO específica (aqui o mecânico atende
o pátio inteiro), lava-jato e posto próprio (descartados de propósito — nas
duas referências lavar e abastecer **não mudam valor**).

Não implementado de propósito (e por quê): lavar/abastecer, que nas duas
referências **não mudam valor** — seria trabalho sem consequência.

## Prédios realistas: 15 pacotes baixados, medidos e AINDA NÃO integrados

**Estado em 2026-08-09, fim da sessão.** Se você está retomando depois de um
`/clear`, é daqui que se continua.

### O que já existe

- `assets/realistas/` — 15 pacotes, 478 MB, **fora do git** (`.gitignore`): são
  downloads crus, re-baixáveis pela lista, com normal maps de até 40 MB num
  arquivo só. Entram no repo depois de processados.
- Todos **CC-BY 4.0**: uso comercial liberado, **crédito obrigatório**.
  `tools/creditos.py` gera [docs/creditos.md](docs/creditos.md) lendo o
  `license.txt` de dentro de cada pacote. **Falta transformar isso numa tela de
  créditos no menu** — sem ela o jogo está fora da licença.
- `tools/garimpo_sketchfab.py` — garimpa a API pública do Sketchfab (não precisa
  login) filtrando por licença e faces. Já rendeu **261 candidatos**, listados
  com link em [docs/garimpo-sketchfab.md](docs/garimpo-sketchfab.md). Ainda há
  ~247 não baixados.
- `tools/receber_modelos.sh` — recolhe os zips que o navegador salva na raiz.
- `tools/verify/analisar_realistas.tscn` — mede o que veio dentro de cada
  pacote. **Rode isto antes de mexer em qualquer modelo novo.**

### O que a medição mostrou (e por que o trabalho é maior do que parece)

```
bordeaux_flat_1              1 malha  |   2409 tri | 7.7 x 18.4 x 11.3 m
bordeaux_flat_2              1 malha  |   1372 tri | 26.8 x 18.6 x 11.2 m
brownstone_building_set     70 malhas |  38320 tri | 318.9 x 22.8 x 159.3 m
city_pack_7                104 malhas |  17002 tri | 69100 x 10570 x 46782 m
downtown_buildings          43 malhas |  25429 tri | 358.9 x 102.6 x 255.1 m
european_buildings_pack3  1427 malhas |  12591 tri | 200.9 x 17.4 x 87.1 m
factory_low_poly             4 malhas |   2498 tri | 10008 x 2793 x 3321 m
industrial_buildings_sets   49 malhas |  16696 tri | 426.6 x 90.6 x 344.8 m
low_poly_city_buildings     22 malhas |   4290 tri | 5.7 x 2.8 x 4.6 m
new_york_buildings          22 malhas |   3257 tri | 10.3 x 5.3 x 22.1 m
old_building_pack_lowpoly   24 malhas |   5532 tri | 7.2 x 6.6 x 21.4 m
old_industrial_building      5 malhas |  37331 tri | 1161 x 1517 x 3450 m
simple_low_poly_village     44 malhas |  15110 tri | 4.8 x 1.0 x 4.4 m
tenement_house              10 malhas |  10800 tri | 20.9 x 17.0 x 75.4 m
warehouses                   1 malha  |   1010 tri | 246.8 x 42.9 x 107.6 m
```

Três problemas, todos reais:

1. **Nenhum está em metros.** Varia de 4,8 m (village) a **69 km** (city_pack_7)
   pra caixa inteira. Cada pacote precisa de um fator próprio, medido — não dá
   pra usar um `building_scale` global como o kit Kenney usa.
2. **Quase todos são uma CENA com vários prédios**, não um prédio. O
   `brownstone` tem 70 malhas espalhadas por 319 m: é um quarteirão inteiro. Pra
   entrar no `CityBlocks` (que instancia uma cena por lote) é preciso **fatiar**
   — agrupar malhas por proximidade e salvar cada aglomerado como um prédio.
3. **Dois não dão pra fatiar por código**: `warehouses` é UMA malha de 246 m
   (vários galpões fundidos) e `factory_low_poly` são 4 malhas de 10 km. Esses
   precisariam do Blender, ou entram inteiros como cenário de fundo.

### O caminho a seguir (nesta ordem)

1. **Fatiador** (`tools/fatiar_realistas.gd`, a escrever): carrega cada
   `scene.gltf`, agrupa as `MeshInstance3D` por proximidade em XZ (aglomerado =
   prédio), e salva cada grupo como uma cena própria em
   `assets/realistas_prontos/<pacote>_<n>.tscn`, já com: escala normalizada pra
   metros (altura de andar ~3 m como referência), origem no CENTRO da planta ao
   nível do chão, e rotação com a fachada no -Z (é o que o `CityBlocks` espera).
2. **Reduzir textura**: há normal maps de 40 MB. Alvo 2K, como o resto do
   projeto. (O `tools/build_characters.py` já faz isso pros personagens, serve
   de modelo.)
3. **Filtrar o que sobrou**: descartar o que ficar fora dos limites de
   [docs/modelos-realistas.md](docs/modelos-realistas.md) — profundidade
   ≤ 13,8 m é o que mais elimina.
4. **Piloto medido**: pôr ~6 no `CityBlocks` (pool novo, por zona) e medir
   chamadas de desenho, triângulos e VRAM no nível da rua, contra as ~2.500 de
   hoje. Só então escalar.
5. **Tela de créditos** no menu, alimentada por `docs/creditos.md`.

### Decisão de design: resolvida em parte (2026-08-09)

O `BuildingFactory` **já está ligado na cidade** (`generated_ratio = 0.62`, ver
changelog) — era o primeiro passo recomendado, e não dependia de mais nada. As
duas frentes resolvem o mesmo problema por caminhos diferentes:

- **gerado**: variedade infinita, 3 chamadas de desenho por prédio, sem
  repetição, mas o estilo é o que eu consigo montar com primitivas;
- **baixado**: aparência de verdade, mas 15 pacotes viram talvez 30-40 prédios
  distintos repetidos ~20 vezes cada — e realismo PIORA a repetição.

Falta a segunda metade: **substituir por realista no miolo** conforme os pacotes
forem sendo fatiados. O ponto de entrada já existe e é pequeno —
`CityBlocks._fill_edge` escolhe entre gerado e kit por lote, e um terceiro caso
("realista, só no miolo") entra ali do mesmo jeito.

## Prédios realistas: notas sobre os sites

Em `assets/realistas/` (476 MB, **fora do git** — ver `.gitignore`; são downloads
crus, entram no repo depois de normalizados e são re-baixáveis pela lista).
Todos **CC-BY 4.0**: uso comercial liberado, **crédito obrigatório** —
`tools/creditos.py` monta [docs/creditos.md](docs/creditos.md) lendo o
`license.txt` que vem dentro de cada pacote, e essa lista vai virar a tela de
créditos do jogo.

downtown_buildings · brownstone_building_set · european_buildings_pack3 ·
old_building_pack_lowpoly · tenement_house · bordeaux_flat_1 e 2 ·
industrial_buildings_sets · old_industrial_building · city_pack_7 ·
new_york_buildings · low_poly_city_buildings · warehouses · factory_low_poly

**Como o download funciona** (custou algumas tentativas): o navegador embutido
NÃO salva sozinho — clicar em *Download* abre um diálogo do macOS e é o usuário
quem escolhe a pasta. Eu abro o painel e clico no glTF por JavaScript (achar a
linha `.gltf` e clicar no botão `DOWNLOAD` dela — duas chamadas por modelo, sem
depender de coordenada de tela, que muda com o tamanho do título), e o usuário
aceita. `tools/receber_modelos.sh` recolhe: **espera cada zip parar de crescer**
antes de abrir, porque desempacotar um arquivo de 29 MB com 14 MB baixados dá
"End-of-central-directory signature not found" e o parcial fica na pasta
parecendo pronto.

**O que ainda falta** (é o trabalho de verdade): cada pacote vem numa escala e
orientação própria e vários são **uma cena com vários prédios num mesh só** — o
downtown tem uma fileira inteira. Fatiar em prédios individuais, normalizar
escala/origem/colisão e reduzir textura (há normal maps de 40 MB) é o que falta
pra isso entrar no `CityBlocks`.

### Notas sobre os sites (apuradas mexendo neles)

**Lista de compras e requisitos:** [docs/modelos-realistas.md](docs/modelos-realistas.md).
**Candidatos já garimpados (160 modelos, links prontos):**
[docs/garimpo-sketchfab.md](docs/garimpo-sketchfab.md), gerado por
`tools/garimpo_sketchfab.py`.

O que ficou provado em 2026-08-09, mexendo nos sites de verdade com o usuário
logado:

- **A API de busca do Sketchfab é pública** (não precisa de login) e devolve
  contagem de faces e licença — que são exatamente os dois filtros que separam o
  modelo usável do scan de meio milhão de triângulos. `tools/garimpo_sketchfab.py`
  varre 17 termos nas quatro zonas da cidade e devolveu **261 candidatos** CC0 ou
  CC-BY. Detalhe que custou uma rodada: o parâmetro `max_face_count` da API
  devolve lista VAZIA (não é válido) — filtrar do lado de cá; e o Python deste
  ambiente não tem cadeia de certificados, então a chamada tem que sair por
  `curl`.
- **O Fab é fraco pra este caso, ao contrário do que eu tinha estimado.** O
  "Downtown Alley", que a imprensa citou como grátis, hoje custa R$ 152 e o campo
  *Included formats* diz **"Unreal Engine"** — sem FBX. Vários pacotes bons de
  cidade lá são assim: a licença permite qualquer engine, mas o ARQUIVO só vem em
  formato Unreal. Conferir esse campo antes de qualquer coisa.
- **O download não sai pelo navegador embutido.** Clicar em *Download* começa a
  transferência (dá pra ver o arquivo temporário crescendo em `~/Downloads`) e
  ela é abortada. E a API de download responde **401 com cookie de sessão** — ela
  quer Bearer token. Caçar esse token no armazenamento da página seria mexer em
  credencial, então **não**: o download é do usuário, em duas cliques por modelo,
  e o arquivo cai em `~/Downloads`, de onde dá pra pegar e integrar.

## Prédios realistas: a lista de compras

Levantado em 2026-08-09: **[docs/modelos-realistas.md](docs/modelos-realistas.md)**
— requisitos duros do gerador (profundidade ≤ 13,8 m, ≤ 25 mil triângulos, ≤ 3
materiais, textura 2K, base plana), motivos de recusa, onde procurar e quantos
modelos por zona.

Duas correções de rumo registradas ali, porque as duas vinham me limitando à toa:

- **A licença Fab NÃO é restrita ao Unreal** — vale em qualquer engine, basta
  baixar o FBX. A Epic ainda renova uma seção gratuita toda semana.
- **CC-BY serve** — só exige uma tela de créditos. Buscar só CC0 cortava o
  Sketchfab inteiro (800 mil modelos, glTF é o export padrão deles) por uma
  regra que ninguém tinha pedido.

O caminho recomendado é o **híbrido** (miolo realista, periferia estilizada),
começando por um **piloto de 6 modelos** só pra medir chamada de desenho e VRAM
antes de comprometer com 30. O bloqueio prático: Sketchfab e Fab exigem conta, e
esta sessão não pode criar nem logar — o download é do usuário, a integração é
minha.

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
- ~~Sistema de crafting mais rico (mais tipos de gambiarra, escolha de item por
  inventário em vez de item fixo por ponto de fixação).~~ **Feito em parte em
  2026-08-09**: são 12 itens, 3 por ponto, escolhidos na hora com Q. O que não
  existe é **inventário** — o jogador não carrega peça, compra na hora de
  instalar; e um item ainda só serve no ponto dele (não dá pra enfiar papelão no
  capô).
- ~~Economia mais profunda (preço pedido, compradores com personalidades e
  negociação).~~ **Feito**: 6 tipos, reputação, oferta inicial, contraproposta e
  blefe em rodadas (2026-08-09 e 2026-08-13). O que ainda caberia como expansão
  é mercado variável por dia, não uma lacuna do loop atual.
- ~~Sons e efeitos de UI/menu.~~ **Feito em 2026-08-08** (ver changelog): efeitos
  do mundo e da interface com pacotes CC0 do Kenney, motor e chuva sintetizados
  em código, e volume ajustável no menu. O **motor dos carros de IA** e o
  **ambiente da cidade** foram fechados em 2026-08-09 (4 vozes emprestadas aos
  carros mais próximos, custo fixo). Falta ainda **MÚSICA**.
- **MÚSICA**: o jogo segue sem nenhuma trilha. Efeitos, ambiente e motor estão
  cobertos (ver changelog 2026-08-08 e 2026-08-09), mas não há música — e é o
  item que menos dá pra decidir sem ouvir, então ficou de fora de propósito.
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

- O **mecânico** contratado atende o pátio inteiro, e não uma estação
  específica como no jogo de referência: não dá pra designá-lo a uma vaga nem
  contratar dois. Ele também não monta gambiarra, de propósito.
- As entregas já são em casas sorteadas da cidade (ver 2026-08-03), o cliente
  tem **personalidade** (6 tipos), com a recepcionista há **dois esperando** ao
  mesmo tempo e desde 2026-08-13 a conversa tem contraproposta e blefe. O que
  não existe é mercado com cotação variável por dia.
- Os buracos (`Pothole*`) e poças de lama continuam em 4 pontos fixos da grade, em
  vez de espalhados/procedurais.
- Os pedestres e o cliente ainda saem de só 2 personagens-base (um masculino, um
  feminino) com a mesma peça de roupa. Tipo físico, altura e cor de pele/roupa/
  cabelo já variam por NPC (ver changelog 2026-08-03), mas **rosto e modelo de
  roupa não** — dois pedestres do mesmo gênero continuam com a mesma cara. Rosto
  diferente exigiria outro pacote de assets; o pacote gratuito do Quaternius só
  traz esses dois corpos, dois cabelos e a roupa Peasant.

## 2026-08-13 — identidade visual do menu, carregamento e HUD (Codex)

Pedido do usuário: deixar o menu inicial e a tela de carregamento mais bonitos e
acrescentar informação ao HUD, seguindo as referências já adotadas pelo projeto
(`Car For Sale Simulator 2023`, `Car Dealer Simulator` e a oficina duvidosa do
pitch), sem virar uma interface genérica de aplicativo.

- **Menu principal redesenhado** em carvão/preto e amarelo de oficina: fachada e
  carro em silhueta desenhados de forma responsiva, faixa de segurança, placa
  “Oficina desde ontem”, marca em duas linhas, cartão lateral e botões com estados
  normal/hover/pressionado/foco. Os botões criados em código (`Continuar`,
  `Personagem` e `Créditos`) copiam o mesmo estilo dos botões da cena; portanto o
  menu com e sem save continua coerente e navegável por teclado.
- **Carregamento redesenhado** como ficha de abertura da oficina: três etapas
  visuais (ferramentas, cidade e negócios), percentual numérico ligado ao progresso
  real, barra própria, dica em cartão, fundo industrial e mensagem específica antes
  da montagem bloqueante da cidade. A tela cobre completamente o menu anterior.
- **HUD reorganizado em painéis**, em vez de texto solto sobre o cenário. O canto
  esquerdo reúne caixa, reputação, estado/valor das gambiarras, negociação e
  objetivo; o canto direito mostra clima, vendas e etapa atual (garimpo/oficina/
  entrega). A bússola ganhou distância em metros/quilômetros e o canto inferior
  direito ganhou velocímetro contextual com marcha e estado do carro, visível só
  quando há alguém dirigindo. O prompt central agora aumenta o próprio fundo para
  mensagens multilinha — isso resolve a observação do Claude sobre as três linhas
  da negociação escapando do retângulo.
- **Teste reforçado**: `loop_test` agora cobra que distância, velocímetro e contador
  de vendas apareçam e se atualizem pelo caminho real do jogo. Na execução final,
  a bússola mostrou 485 m, o velocímetro 48 km/h e o painel mudou para `1 VENDA`.
- **Verificação feita**: import/parse do Godot limpo; 15 cenas automatizadas
  (`city`, `drive_test`, `loop_test`, `attach_test`, `scale_test`, `yard_test`,
  `audio_test`, `obstacles_test`, `save_test`, `loading_test`, `economy_test`,
  `shop_test`, `staff_test`, `character_test`, `street_test`) passaram. Também
  passaram `ui_shot` e `loop_shots`; as imagens do menu, carregamento, HUD normal,
  direção e negociação foram abertas e conferidas. O `ui_shot`, depois de salvar
  todas as seis imagens e imprimir resultado positivo, ainda repete o erro tardio
  já conhecido de `Town.tscn:156` enquanto encerra uma carga assíncrona; o
  `loading_test` carrega a mesma `Main.tscn` até o fim com código 0, então não é
  erro real da cena nem do pacote.
- **Builds fechados**: Windows `998.208.688 bytes`; macOS ZIP `486.555.722
  bytes`, contendo `.pck` de `888.996.516 bytes`. O `pack_audit.py` conferiu 105
  referências, 71 caminhos de runtime e o catálogo de personagens, sem falta.
  O `.app` anterior foi movido para a Lixeira (recuperável), o ZIP novo foi
  extraído de novo e o executável exportado real abriu em headless por 120
  quadros e encerrou com código 0.

### Correção devolvida pela revisão do Claude

Enquanto esta rodada de UI estava em andamento, o Claude terminou a revisão do
commit `f561f2b` e provou com o novo `rematch_test` que tirar o carro da zona e
reestacionar reabria a negociação do zero: oferta perdida por blefe, rodadas e o
próprio blefe voltavam de graça. O Codex implementou a correção conforme a divisão
do `AGENTS.md`: a conversa agora fica vinculada ao veículo, é apenas pausada ao
sair da zona e retoma exatamente a oferta, rodadas e `bluff_used` anteriores.
Também não deixa trocar o preço pedido durante essa pausa, o que mudaria o teto
sem pagar rodada. O prompt avisa `Oferta pausada` e permite retomar com E.

O teste que antes falhava agora passou: após blefe descoberto, `R$ 124 -> R$ 112`,
restou 1 rodada e `bluff_used = true`; depois de sair e voltar, permaneceu em
`R$ 112`, 1 rodada e blefe usado. `economy_test` e `loop_test` também continuaram
passando. Como isso altera código de jogo depois da primeira exportação anotada
acima, as duas builds foram geradas e auditadas novamente no fechamento final.

## 2026-08-13 — release v0.3.1 publicada (Codex)

A mudança de interface e a correção da negociação foram publicadas também como
release, conforme a regra obrigatória de `AGENTS.md`: [v0.3.1 — interface e
negociação](https://github.com/vitudanas/JeguesMecanicos/releases/tag/v0.3.1).

- Windows: `JeguesMecanicos-Windows.zip`, 463.978.561 bytes, SHA-256
  `8e4cdba81f07d4dc0156ccbd2107d063fba54378778dd29a164b95e293b5bbf4`.
- macOS: `JeguesMecanicos.zip`, 486.555.722 bytes, SHA-256
  `2c98f22e5bdf8d14ae197041ac1473efa512992617de586ce9a94ab61a803513`.
- O GitHub confirmou os dois assets com estado `uploaded` e digest igual ao dos
  arquivos locais. A release foi publicada em 2026-08-13 e aponta para `main`.

## 2026-08-13 — auditoria franca da direção visual e do mundo aberto (Codex)

Pedido do usuário: depois da rodada de UI, reconsiderar cores, mundo, mapa e
experiência amigável porque o resultado ainda não estava convencendo. Esta seção
é deliberadamente um diagnóstico, não uma autorização para remodelar o mapa sem
uma direção aprovada.

### Evidência inspecionada

- `tools/verify/world_tour.tscn` foi executado novamente no estado atual e gerou
  17 capturas novas: mapa inteiro, cidade aérea, quatro vistas de rua, trânsito,
  pedestres, entrega, oficina, ferro-velho, fazendas, cordilheira e transição
  campo/cidade. Também foram reabertas as capturas atuais do menu, carregamento e
  direção do loop completo.
- Portanto, o parecer abaixo não se baseia nas imagens antigas das referências
  nem só na contagem de prédios: ele compara o que o jogador realmente enxerga
  hoje, no chão e de cima.

### Veredito

**Ainda não está digno, visualmente, de um mundo aberto comercial.** O jogo já é
um mundo contínuo, dirigível e com sistemas vivos (trânsito, pedestres, clima,
oficina, ferro-velho e entregas), mas a apresentação ainda comunica “mapa grande
de protótipo gerado” em vez de “lugar autoral que dá vontade de explorar”. É um
problema de direção de arte, escala, densidade e navegação — não falta de tamanho.

O menu e o carregamento novos ficaram mais coerentes entre si que o próprio
mundo. Eles têm uma linguagem clara de oficina em carvão/preto e amarelo, porém
a personalidade cínica e muito escura é mais agressiva do que amigável. O HUD
herdou a coerência, mas o painel de objetivo cobre aproximadamente 38% da largura
e 28% da altura em 1080p; junto com o painel direito e a seta central, ele esconde
uma parte grande do cenário e transforma orientação em poluição visual.

### Problemas observados, em ordem de impacto

1. **Cidade sem identidade navegável.** A vista aérea revela uma grade muito
   regular, com quarteirões repetidos e poucos marcos realmente reconhecíveis. No
   chão, avenidas largas e retas criam longos corredores vazios. Há muitos prédios,
   mas pouca diferença de função e personalidade entre uma rua e a seguinte.
2. **Mistura de estilos sem uma regra aparente.** Fachadas fotográficas e torres
   realistas convivem com carros, personagens, oficina, árvores e cercas low-poly.
   O contraste parece uma colagem de pacotes, não uma escolha artística híbrida.
   Réplicas repetidas de arranha-céus conhecidos pioram a sensação de catálogo.
3. **Cor e luz lavadas.** Calçadas e montanhas quase brancas, névoa clara e céu
   forte reduzem profundidade e estouram grandes áreas da imagem. No campo, grama
   verde-limão e árvores vermelhas muito saturadas brigam com a cidade cinza. A
   cordilheira branca ao redor de todo o mapa domina o horizonte e parece uma
   parede artificial.
4. **Escala e densidade inconsistentes.** O centro tem torres coladas e enormes;
   logo depois aparecem terrenos muito abertos com props pequenos e espaçados.
   Oficina e ferro-velho parecem miniaturas soltas num gramado, enquanto ruas e
   edifícios parecem grandes demais. Trânsito e pedestres existem, mas não ocupam
   visualmente a avenida larga o suficiente para fazê-la parecer viva.
5. **Orientação depende de UI, não do mundo.** A seta e a distância resolveram a
   dúvida de direção imediata, mas faltam mapa/minimapa, bairros nomeados, placas
   legíveis e marcos que deixem o jogador aprender a cidade. Textos 3D gigantes
   sobre ferro-velho/oficina/entrega são funcionais, porém reforçam aparência de
   protótipo.
6. **Custo visual sem retorno equivalente.** No passeio automatizado, as vistas
   de rua ficaram frequentemente entre 10 e 27 FPS, enquanto a vista aérea chegou
   a 59 FPS; a captura do loop dirigindo estabilizou em 60 FPS. O roteiro de fotos
   não substitui benchmark, mas a oscilação é sinal suficiente para exigir um
   perfil real antes de aumentar ainda mais a cidade.

### Direção recomendada antes de adicionar mais conteúdo

Fazer primeiro uma **fatia vertical visual de cinco minutos** no percurso
ferro-velho -> oficina -> primeiro comprador. Não remodelar o mapa inteiro de uma
vez. A fatia deve provar a nova direção com comparação antes/depois e só então ser
propagada.

1. Definir uma bíblia curta de arte: “Brasil interiorano de oficina improvisada”,
   estilização semi-realista, materiais e proporções comuns. O mundo deve combinar
   com a personalidade de `Jegues Mecânicos`, não parecer Manhattan cercada por
   fazendas.
2. Criar 3 ou 4 bairros reconhecíveis por silhueta, cor, vegetação, tipo de rua e
   props, cada um com pelo menos um marco visível de longe. Reduzir repetição de
   torres e evitar prédios mundialmente reconhecíveis duplicados.
3. Recalibrar a paleta: grama menos amarela/saturada, árvores vermelhas usadas como
   acento e não como massa, asfalto um pouco mais quente, calçadas menos brancas,
   montanhas mais escuras e azuladas pela distância, sol mais quente e neblina
   menos leitosa.
4. Densificar as rotas úteis em vez de ampliar a área: ruas secundárias mais
   estreitas, carros estacionados, postes, placas, lixo de oficina, comércios e
   pontos de interesse próximos. Se necessário, encolher a área jogável; mundo
   aberto compacto e memorável é melhor que grande e vazio.
5. Tornar navegação amigável: minimapa simples ou mapa de papel, nome do bairro ao
   entrar, rota opcional e placas consistentes. Compactar o objetivo no HUD em uma
   ou duas linhas, deixar detalhes expandirem só quando solicitado e preservar o
   centro da tela para dirigir.
6. Suavizar o primeiro contato: manter amarelo como acento, mas usar grafite mais
   quente, creme e ilustrações/personagens no menu. No início da partida, ensinar
   uma ação por vez e esconder clima/vendas/etapa até essas informações serem
   relevantes.

**Decisão recomendada:** pausar a adição de novos sistemas e assets até aprovar
essa fatia visual. A próxima implementação deve começar pelo HUD compacto e por
um único corredor redesenhado, com capturas lado a lado e teste de desempenho;
só depois se decide se a linguagem deve ser aplicada ao mapa inteiro.

## 2026-08-13 — primeira fatia visual amigável implementada (Codex)

O usuário autorizou executar a direção recomendada acima. Esta rodada não tenta
fingir que a cidade inteira foi redesenhada: ela fecha uma primeira fatia
comparável no caminho ferro-velho -> oficina -> comprador e corrige dois achados
objetivos da segunda revisão do Claude.

### Mudanças entregues

- **HUD compacto e adaptativo:** painel principal passou de 490 x 220 para uma
  base de 384 x 140 em 1080p, fontes e barra foram reduzidas e o painel agora
  aumenta somente quando aparecem dano, negociação ou objetivo multilinha. O
  painel de mundo e o velocímetro também perderam cabeçalhos redundantes e área
  vazia. A captura dirigindo deixa muito mais da rua visível.
- **Prompt de negociação corrigido:** a caixa central ficou mais larga, ganhou
  quebra automática e altura calculada pelas linhas. A nova captura real mostra
  `[E] aceitar`, `[Q] contrapropor`, `[F] blefar` e rodadas completamente dentro
  do fundo — resolve o transbordo que o Claude ainda via em `1e9fce1`.
- **Paleta do mundo recalibrada:** exposição e saturação caíram, o sol ficou mais
  quente, a névoa ganhou azul/cinza e mais perspectiva aérea, e grama/terra/
  cascalho perderam o verde-amarelo excessivo. A cordilheira usa rocha azulada,
  neve mais escura e apenas acima de 255 m; deixou de formar a parede branca que
  dominava o horizonte.
- **Corredor rural legível pelo mundo:** foi adicionada uma segunda estrada de
  terra ligando o ferro-velho à oficina; as duas fitas foram estreitadas para
  5,2 m depois da primeira captura revelar aparência de pista. O verificador de
  obstáculos encontrou o corredor novo livre de ponta a ponta. O texto de missão
  agora diz `placa amarela`, coerente com a identidade atual.
- **Destinos menos prototípicos:** os letreiros gigantes e sempre visíveis foram
  reduzidos, passaram a respeitar profundidade e ganharam nomes locais (`Ferro-
  Velho do Zé`, `Oficina do Pátio`). Eles orientam sem atravessar montanhas e
  prédios.
- **Correção devolvida pelo Claude:** ao retomar conversa pausada, teto, oferta
  atual e abertura são reancorados para baixo ao valor atual do carro. Rodadas e
  blefe continuam gastos, mas um carro que perdeu 4/4 gambiarras não recebe mais
  a oferta congelada do carro inteiro. O teste novo do Claude foi preservado e
  passou: no exemplo final a oferta caiu para o teto atual em vez de ficar acima.

### Verificação desta rodada

- Import/parse do Godot: código 0.
- Estrutura: `city`, `scale_test`, `obstacles_test` e `street_test` passaram. O
  censo continuou em 877 prédios, 337 casas, 5.200 props de natureza e 132
  maciços, sem invasão de rua, sobreposição ou parede invisível. A trilha nova
  teve 54 posições de carro verificadas e zero bloqueadas.
- Jogabilidade: `loop_test`, `drive_test`, `attach_test` e `rematch_test`
  passaram; o loop comprou, rebocou, instalou quatro gambiarras, dirigiu,
  negociou, vendeu e criou a entrega seguinte.
- Regressão: `economy_test`, `save_test`, `loading_test` e `audio_test` passaram.
- Visual: `world_tour` regenerou 17 ângulos e `loop_shots` regenerou oito cenas
  do caminho real. As imagens de mapa inteiro, rua, oficina aérea/no chão,
  ferro-velho, cordilheira, direção e negociação foram abertas e conferidas. A
  primeira estrada de 7 m foi rejeitada visualmente e reduzida antes do aceite.
- Desempenho observado nas capturas: direção estabilizou em 60 FPS; negociação
  ficou entre 20 e 31 FPS dependendo do comprador/prédio, e as primeiras fotos
  rurais podem registrar 1 FPS enquanto o roteiro ainda monta o mundo. Isso não
  é benchmark e a cidade genérica continua sendo o próximo trabalho estrutural.

### Limite honesto

A fatia ficou mais legível, menos lavada e mais amigável, mas **não transforma a
cidade inteira em mundo aberto autoral**. A grade, as avenidas largas e a mistura
de fachadas fotográficas com personagens/carros low-poly continuam visíveis. O
próximo passo correto é um bairro piloto compacto com marco próprio e densidade
de rua, não aumentar a quantidade de prédios.

### Builds preparadas para a v0.3.2

- Windows EXE: 998.542.840 bytes; ZIP de distribuição SHA-256
  `ff1f299279ecfcaffad5bb48c6b22367c751f1a796ec085c176e4f32837a198b`.
- macOS ZIP: 486.849.113 bytes; SHA-256
  `72f4a784f7de1b8b0a9b5c10981e7d9a51bcf6f5cc712f5c2b5d45fd8564492f`;
  `.pck` interno de 889.330.668 bytes.
- `pack_audit.py`: 105 referências, 71 caminhos de runtime e catálogo sem
  ausência. O `.app` anterior foi preservado em `builds/macos/previous-apps/`, o
  ZIP novo foi extraído e o `.pck` aberto localmente tem os mesmos 889.330.668
  bytes. O executável real do `.app` rodou 120 quadros em headless e encerrou com
  código 0 (sem `--path`, que o template de distribuição bloqueia de propósito).

## 2026-08-13 — regras de Git e revisão deixadas pelo Claude

- Incorporadas ao `AGENTS.md` as regras de coordenação escritas pelo Claude.
- Cada agente deve commitar somente os arquivos que realmente alterou e identificar sua
  participação no commit; mudanças compartilhadas precisam ser conferidas antes do commit.
- Commits devem ter um único assunto e nomes descritivos; alterações de gameplay precisam
  citar os testes executados e alterações visuais devem citar a evidência usada.
- O Codex implementa, faz os testes iniciais, commita, envia ao GitHub e mantém a release
  atualizada; o Claude revisa o código e executa testes adicionais antes da release.
- A regra de divisão de responsabilidades acima permanece vigente até 31 de agosto de 2026.

## 2026-08-13 — autoria e transparência sobre o uso de IA (Codex)

- A pedido do usuário, o `README.md` agora declara publicamente que **Jegues Mecânicos foi
  criado por Vitor Rodrigues Danas e é desenvolvido majoritariamente com assistência de IA**.
- O texto preserva a autoria humana: Vitor responde pela ideia, direção criativa e decisões;
  Claude e Codex são apresentados como colaboradores em programação, testes, documentação e
  iteração visual.
- A descrição do repositório no GitHub deve manter a mesma informação de forma resumida.
- Esta rodada altera somente documentação e metadados do repositório; não exige nova build ou
  release do jogo.

## 2026-08-13 — repositório renomeado para JeguesMecanicos (Codex)

- O usuário renomeou o repositório no GitHub de `vitudanas/joguinho2` para
  `vitudanas/JeguesMecanicos`.
- O remoto local `origin`, o link principal do `README.md` e os links históricos das releases
  foram atualizados para o endereço novo.
- A descrição de autoria e transparência sobre assistência de IA foi conferida no repositório
  renomeado e permaneceu intacta.
- Não houve mudança no jogo ou nos artefatos; nenhuma nova build/release foi necessária.

## 2026-08-13 — preparação de privacidade para tornar o repositório público (Codex)

- A pedido do usuário, foram auditadas as 102 revisões Git e os 2.101 arquivos
  versionados em busca de formatos conhecidos de tokens, chaves privadas e credenciais.
  Nenhum segredo desse tipo foi encontrado.
- Referências atuais a um nome de usuário local em caminhos absolutos foram removidas da
  documentação e de um comentário de ferramenta, preservando apenas a explicação técnica.
- O `.gitignore` passou a bloquear arquivos `.env`, chaves, certificados, keystores e arquivos
  comuns de credenciais, mantendo a exceção segura para um eventual `.env.example`.
- Foi encontrado um e-mail pessoal no metadado do commit inicial. O conteúdo não aparece nos
  arquivos atuais; a correção por reescrita de histórico foi autorizada e concluída na rodada
  registrada abaixo.
- O nome do criador permanece público intencionalmente, conforme a declaração de autoria no
  `README.md`; não foi classificado como informação sensível nesta auditoria.
- Nenhuma nova build/release é necessária porque esta rodada altera apenas higiene do
  repositório, documentação e comentários.

## 2026-08-13 — e-mail pessoal removido do histórico Git (Codex)

- Com autorização expressa do usuário, o histórico foi reescrito para substituir o e-mail
  pessoal do commit inicial por `vitudanas@users.noreply.github.com`.
- Antes da operação foi criado e verificado um bundle privado completo em
  `/Users/Shared/JeguesMecanicos-history-before-email-redaction-20260813.bundle`, com SHA-256
  `35bebd82a1a94f36a309c841ce951256dc0ad8474c14e01a785e82a0c99a8d6d`. Esse arquivo contém o
  histórico anterior e não pode ser publicado ou copiado para dentro do repositório.
- A reescrita preservou os 101 commits da `main` e a árvore final byte a byte. Nomes, mensagens,
  datas e conteúdo foram preservados; os hashes mudaram porque o metadado de autoria integra o
  identificador de cada commit.
- O force-push foi atômico e protegido pelos hashes remotos conferidos. `main` e as tags
  `v0.1.0` a `v0.3.2` foram atualizadas juntas; as cinco releases e seus títulos permaneceram
  associadas às tags novas.
- A API do GitHub foi consultada depois do envio e apresentou somente o endereço protegido
  `users.noreply.github.com` no histórico público alcançável.
- Hashes antigos citados em registros históricos anteriores a esta entrada são identificadores
  anteriores à higienização e não devem mais ser usados para handoff ou revisão. O estado do
  jogo não mudou, portanto não houve nova build nem nova release.

## 2026-08-13 — bytecode e caminhos locais removidos do histórico (Codex)

- Durante uma revisão paralela, o Claude encontrou dois arquivos `.pyc` versionados; um deles
  continha em formato binário um caminho absoluto com o nome da conta local. O achado foi
  confirmado pelo Codex antes da correção.
- `tools/__pycache__/expand_world.cpython-314.pyc` e
  `tools/verify/__pycache__/patch.cpython-314.pyc` foram removidos. O `.gitignore` agora bloqueia
  diretórios `__pycache__` e bytecode `*.pyc`, `*.pyo` e `*.pyd`.
- As referências públicas foram reescritas novamente para retirar os dois binários de todas as
  versões alcançáveis, e não somente do `HEAD`. A árvore final e a contagem de commits foram
  verificadas antes do force-push.
- O bundle privado criado antes da primeira higienização continua sendo a recuperação do estado
  antigo e, por conter os dados removidos, não deve ser publicado.
- Esta limpeza não altera código-fonte ou comportamento do jogo e não exige nova build/release.

## 2026-08-13 — identificadores pessoais removidos de textos históricos (Codex)

- A auditoria final encontrou o nome da conta local embutido em versões antigas de
  `CLAUDE.md` e `tools/build_characters.py`, mesmo depois de o `HEAD` ter sido corrigido.
- Todas as ocorrências históricas de `/Users/<conta real>` foram substituídas pelo marcador
  neutro `/Users/<usuario-local>`. Qualquer ocorrência textual do e-mail particular também foi
  substituída por um marcador neutro; nomes, explicações técnicas e autoria do jogo permanecem.
- A anotação paralela do Claude foi preservada com a mesma informação técnica, mas sem repetir o
  caminho sensível. O histórico público e as tags foram validados novamente após a reescrita.
- Nenhum arquivo de jogo, build ou release foi alterado nesta etapa de privacidade.

## 2026-08-13 — README público profissional e nova auditoria (Codex)

- O `README.md` foi reescrito como página pública do produto: apresentação curta, recursos
  verificados, downloads oficiais, instruções para Windows/macOS, controles, autoria,
  desenvolvimento e créditos/licenças.
- Foram removidos o tutorial interno de publicação no itch.io, comandos de exportação, caminhos
  específicos da máquina e a afirmação de que o repositório é privado. A página não presume qual
  será a visibilidade futura.
- O README deixou de destacar o `CLAUDE.md` como leitura para visitantes: ele continua sendo a
  memória operacional obrigatória do projeto, mas não é documentação de produto.
- A autoria de Vitor Rodrigues Danas e o uso majoritário de assistência de IA continuam
  declarados de forma explícita. Claude e Codex aparecem como colaboradores, não como autores ou
  donos do jogo.
- O README não inventa requisitos mínimos nem atribui uma licença geral ao projeto. Ele informa
  que o código ainda não possui licença escolhida e encaminha os assets CC0/CC-BY para
  `docs/creditos.md`.
- Nova auditoria do estado atual encontrou zero formatos conhecidos de chave/token, zero
  atribuições genéricas de credencial, zero strings de conexão e nenhum arquivo versionado com
  nome típico de segredo, certificado, `.env`, bytecode ou cache Python.
- A auditoria histórica examinou por extração de strings os **3.236 blobs únicos** alcançáveis
  por `main` e pelas tags `v0.1.0` a `v0.3.2`, incluindo binários: zero ocorrência do e-mail
  particular, do nome da conta local ou dos formatos conhecidos de tokens/chaves verificados.
- Os metadados Git alcançáveis continuam usando apenas endereços `noreply`. O e-mail comum
  encontrado no conteúdo pertence ao autor público de uma ferramenta/licença de terceiro, não ao
  usuário e não a uma credencial; foi preservado como atribuição.
- A área `About` do GitHub ganhou uma descrição pública mais direta, mantendo Vitor como criador
  e informando a assistência de IA, além dos tópicos `godot`, `godot-engine`, `gdscript`, `game`,
  `open-world`, `sandbox`, `brazilian-game` e `ai-assisted`. Nenhuma homepage fictícia foi
  cadastrada e a visibilidade permaneceu privada.
- Esta alteração é somente documental e não exige nova build/release.

## 2026-08-13 — revisão de ruas, NPCs, áudio, campo e montanhas (Codex)

- A grama de geometria agora lê a grade real de `CityStreets` e exclui os corredores
  asfaltados além das duas estradas rurais. O defeito aparecia sobretudo em Alto/Ultra porque
  o anel denso alcançava as ruas externas, enquanto `GrassField.city_extent` ainda assumia o
  tamanho antigo da cidade.
- Pedestres incompatíveis com a biblioteca UAL1 não tratam mais o primeiro clipe encontrado
  (frequentemente idle/pose) como caminhada. Quando o modelo não possui locomocão própria, um
  fallback procedural aplica passada de braços/pernas, balanço e oscilação do corpo; os 72
  pedestres passaram no `npc_test` com 28 modelos diferentes e locomocão ativa.
- O asfalto ganhou tom menos chapado, mais variação PBR/desgaste, tinta menos branca e calçada
  cinza mais próxima da linguagem das fachadas. O miolo de todos os quarteirões construídos
  ganhou base contínua de cascalho/concreto, eliminando o terreno cru que parecia buraco entre
  as fileiras; muros com portões já fecham as sobras de fachada. O censo registra 0 bordas
  completamente vazias, 93% da borda ocupada visualmente e nenhuma falha de escala.
- As estradas rurais agora usam o material fotográfico PBR **Gravel Road**, de Amal Kumar para
  Poly Haven, em resolução 1K (cor, normal e rugosidade), sob licença CC0. A atribuição e os
  links de origem/licença estão em `assets/polyhaven/GravelRoad/LICENSE.txt`. Sulcos de roda
  continuam em geometria para a estrada não parecer apenas uma textura colada.
- Fazendas receberam solo arado sob as plantações, fardos de feno e cocho. A natureza rural
  passou de distribuição uniforme para bosques determinísticos com clareiras, mantendo as
  exclusões de estrada, fazendas e oficinas.
- A cordilheira caiu de 132 cones estreitos para 84 maciços maiores e sobrepostos, com perfil
  mais largo, rocha de maior contraste, estratos mais legíveis e picos de até 340 m. O teste
  confirmou 84 bases tocando o chão, sem parede invisível nem objeto flutuando.
- O áudio procedural passou de 22,05 para 44,1 kHz. Motor, vento e cidade ficaram menos
  ruidosos/agudos; os beds e carros de IA foram reequilibrados. A fronteira sonora urbana foi
  corrigida de 118 m para os 360 m atuais, impedindo vento rural dentro dos bairros. O teste
  confirmou 18 eventos/47 arquivos, loops válidos e transição cidade/campo correta.
- Validações executadas: importação/editor sem erro; `audio_test`, `npc_test`, `gaps_test`,
  `street_test` e `scale_test`; tour visual completo com 17 capturas. O tour confirmou fazendas
  mais legíveis, rua sem mato visível, quarteirões contínuos e montanhas com mais massa. A cena
  ainda merece uma futura rodada exclusiva de iluminação/neblina, que hoje lava o horizonte.
- Esta rodada altera o jogo e requer revisão e testes adicionais do Claude antes de o Codex
  gerar/publicar os novos artefatos Windows/macOS na release, conforme `AGENTS.md`.

## 2026-08-13 — correção das regressões encontradas na revisão de `fb7b78c` (Codex)

- O Claude encontrou duas regressões que a primeira bateria do Codex não cobriu: `city`
  mostrou a cordilheira chegando a 1.608 m do centro com o chão terminando em 1.550 m;
  `obstacles_test` encontrou uma parede invisível na `twisted-tree.glb`, cuja colisão media
  6,7 m para uma silhueta de 4,1 m na altura do carro.
- O `GroundMesh` e o `GroundShape` passaram de 3.100 para 3.300 m. A meia-largura agora é
  1.650 m, dando 42 m de margem além do ponto mais distante da serra sem reduzir os maciços
  pedidos na rodada visual.
- O limiar `AutoCollisionBody.SHRINK_MIN` caiu de 2,5 para 2,2 m no modo opt-in
  `slim_collision`. Isso inclui a `twisted-tree` na colisão pela silhueta do tronco; prédios
  não são afetados porque não ativam esse modo. O diagnóstico de `obstacles_test` agora também
  imprime o `visual_scene` do infrator para tornar uma futura reprodução objetiva.
- Testes refeitos e aprovados: `city`, `obstacles_test`, `scale_test`, `street_test`,
  `npc_test` e `audio_test`. Resultados relevantes: ponto mais distante da serra 1.608 m <
  chão 1.650 m; zero colisões largas na altura do carro; 84 bases de maciço no chão; zero
  objeto flutuando e zero parede invisível.
- O `world_tour` regenerou as 17 capturas. `01_mapa_inteiro` e `16_cordilheira` foram abertas
  e conferidas: o terreno cobre o anel inteiro e a aparência da serra permanece estável.
- Por ordem do usuário, `AGENTS.md` agora declara explicitamente que o Codex pode reexportar,
  substituir/reextrair o `.app` local e publicar Windows/macOS nas releases. A regra de esperar
  a revisão do Claude antes da release permanece. Também ficaram obrigatórios `city` e
  `obstacles_test` em toda alteração futura de mundo — foram exatamente os dois ausentes que
  detectaram estas regressões.
- A release continua aguardando a nova revisão do Claude sobre o commit de correção. Após o
  aval, o Codex deve reexportar, reextrair o `.app`, verificar os artefatos e publicar a próxima
  release de correção no GitHub.

## 2026-08-13 — segunda revisão visual integrada: NPCs, áudio e paisagem (Codex)

- A rejeição visual do usuário foi tratada como falha de aceitação da rodada anterior, não como
  trabalho concluído. Esta passagem refez em conjunto os elementos que ainda pareciam artificiais:
  pedestres, paisagem sonora, paleta urbana, vegetação rural e silhueta da cordilheira.
- Os NPCs agora só entram na seleção quando o modelo possui um clipe nomeado de caminhada,
  corrida ou trote. O fallback procedural foi removido da população usada no mapa: são 72
  pedestres, distribuídos entre 7 modelos realmente animados. O `npc_test` mede a posição do
  clipe antes e depois de 0,25 s e confirmou avanço nos 72, além de zero modelo procedural,
  alturas entre 1,63 e 1,87 m e todos visíveis. O tour também fotografou dois instantes da mesma
  cena (`08a` e `08b`), nos quais braços e pernas mudam de pose.
- Motor e vento deixaram de depender do timbre procedural e passaram a usar gravações CC0:
  `Racing car engine sound loops`, de domasx2, e `Wind`, de IgnasD, ambas obtidas no
  OpenGameArt. Arquivos, licença e URLs estão em `assets/opengameart/audio/`; créditos também
  foram adicionados às telas/documentação do projeto. O loop do motor foi recortado em ponto de
  emenda medido como 0,000 no `audio_test`, e o ambiente urbano foi reduzido para não mascarar
  motor e efeitos.
- A cidade recebeu asfalto, concreto, faixas e meios-fios menos claros; exposição, neblina e
  perspectiva aérea foram reduzidas, enquanto a saturação recuperou parte da cor perdida. A
  densidade de decoração rural caiu para abrir leitura entre os elementos. Árvores mortas e
  retorcidas deixaram de dominar fazendas, oficina e ferros-velhos rurais, que agora usam árvores
  e pinheiros vivos.
- A serra anterior ainda lia como uma repetição de 84 espigões. Ela foi substituída por 30
  maciços mais largos, com múltiplos picos internos, mistura suave entre cristas e alturas entre
  110 e 220 m. O shader ganhou rocha/grama mais quentes e estratos menos agressivos. O teste
  mediu o maior ponto em 1.482 m, dentro do chão de meia-largura 1.650 m, com as 30 bases no solo
  e zero objeto natural na encosta indevida.
- A estrada de terra continua usando o material PBR CC0 Gravel Road e foi conferida novamente ao
  nível do chão. O `world_tour` foi atualizado para a malha viária atual e gerou 18 imagens:
  foram abertas e inspecionadas as ruas do centro/periferia, dois quadros dos NPCs, estrada rural,
  oficina, ferro-velho, fazenda, panorama e três enquadramentos da cordilheira. Não apareceu mato
  sobre o asfalto; as áreas rurais perderam as árvores mortas gigantes; a serra passou a formar
  massas largas em vez de uma floresta de cones.
- Validação final aprovada: importação/editor, `npc_test`, `audio_test`, `city`,
  `obstacles_test`, `scale_test`, `street_test`, `settings_test`, `gaps_test` e `world_tour`.
  Resultados de mundo: 64 quarteirões, 877 construções, zero borda completamente vazia, 6.439
  sólidos, zero parede invisível, zero colisão excessiva e os dois corredores de terra livres.
  `gaps_test` permanece um relatório de cobertura (93%), não uma trava automática. Os presets
  Baixo, Médio, Alto e Ultra passaram funcionalmente; esta rodada não afirma ganho de FPS.
- O código desta rodada deve ser enviado ao Claude com o hash para revisão prática independente.
  Builds Windows/macOS, reextração do `.app` e publicação da release continuam bloqueadas até o
  aval dele, conforme a ordem obrigatória do `AGENTS.md`.

## 2026-08-16 — repositório público no GitHub (Codex)

- Por autorização direta do usuário, o repositório `vitudanas/JeguesMecanicos` teve a
  visibilidade alterada de privada para pública. A página confirmou `PUBLIC` em
  `https://github.com/vitudanas/JeguesMecanicos`.
- Antes da mudança, o `HEAD` foi confirmado em sincronia com `origin/main`. A checagem final
  encontrou zero arquivo rastreado com nome típico de segredo, certificado, `.env`, bytecode ou
  cache Python; zero formato conhecido de token/chave no conteúdo; zero caminho de conta pessoal
  no `HEAD`; e apenas e-mails `noreply` nos commits alcançáveis. Os caminhos absolutos preservados
  são exclusivamente `/Users/Shared` ou marcadores deliberadamente anonimizados.
- A alteração local que já existia no `CLAUDE.md`, escrita pelo Claude, foi preservada fora deste
  commit. Esta rodada muda apenas documentação/visibilidade e não exige nova exportação do jogo.

## 2026-08-16 — correção da emenda da chuva apontada pelo Claude (Codex)

- A revisão de `15c9811` mediu a emenda da chuva em 0,241 após a migração para 44,1 kHz, cerca
  de quatro vezes o valor anterior e audível como estalo periódico. O crossfade existente
  misturava a textura, mas ainda deixava a fronteira do arquivo sobre duas amostras afastadas.
- O gerador agora rotaciona o mesmo sinal para usar como fronteira o par consecutivo de menor
  salto. Isso preserva duração e conteúdo e reduziu a emenda medida para 0,000.
- O limiar do `audio_test` caiu de 0,35 para 0,02; o valor antigo permitia que a regressão de
  0,241 passasse. O teste completo aprovou 18 eventos/47 arquivos, motor 0,000, chuva 0,000,
  cidade 0,002, vento gravado, eventos, transição cidade/campo e fade da chuva.

## 2026-08-16 — variedade dos NPCs recuperada com locomoção real (Codex)

- A revisão de `15c9811` apontou que remover modelos com pose/idle eliminou o deslizamento, mas
  derrubou a variedade de 28 para 7. A seleção agora distingue três casos seguros: UAL1 nativa,
  clipe próprio que declara locomoção e realmente move membros, ou rig Mixamo compatível.
- Personagens Mixamo sem caminhada própria recebem a caminhada do modelo
  `low_poly_female`, já presente/licenciado no projeto. O retarget copia apenas rotações para
  ossos semanticamente equivalentes; não copia posição ou escala entre arquivos que usam
  unidades diferentes. A rotação absoluta do quadril também não é copiada: o tour real mostrou
  que ela carregava a conversão de eixo do doador e deitava o soldado inteiro apesar dos membros
  estarem em movimento. Preservar a pose-base do quadril deixou o NPC ereto e andando nas duas
  capturas seguintes. Arquivos cujo nome declara caminhada mas trazem timeline longa/congelada
  são rejeitados — `character_girl_animated_walk`, com 32,9 s, foi pego assim pelo teste.
- O `npc_test` deixou de aceitar variedade mínima 5: exige pool elegível >=18 e população com
  >=15 modelos distintos. Também fotografa matematicamente a pose dos membros antes/depois, para
  reprovar AnimationPlayer cujo relógio avança sem atingir o esqueleto, e inspeciona a animação
  retargetada para impedir a regressão da rotação de quadril que deita o corpo.
- Resultado final: 72 pedestres, 23 modelos elegíveis e 23 presentes, zero fallback procedural,
  72 clipes avançando, 72 poses de membros mudando, todos visíveis e alturas de 1,63 a 1,87 m.

## 2026-08-16 — paisagem rural e validação visual corrigidas (Codex)

- Os três ferros-velhos rurais receberam mais carcaças, caixas e decoração. Cada carcaça agora
  tem cabine e quatro rodas, e o agrupamento ganhou uma base escura contínua: na captura `15` o
  ponto passa a ler como ferro-velho, não como duas caixas perdidas no campo.
- A estrada de terra preserva o material PBR CC0 Gravel Road, mas o tom da base e dos sulcos foi
  neutralizado para retirar o laranja que destoava do asfalto, da oficina e do terreno rural.
- `gaps_test` deixou de ser apenas um relatório que sempre encerrava com sucesso: agora exige ao
  menos 85% de cobertura das bordas e reprova qualquer borda de quarteirão completamente vazia.
  O mapa atual passou com 93% de cobertura, 64 quarteirões e zero borda vazia.
- O `world_tour` apaga capturas antigas antes de começar, enquadra as ruas seguindo carros reais,
  falha quando falta o conteúdo esperado e usa coordenadas rurais para a cordilheira e para a
  transição campo–cidade. As fotos `03` e `06` agora mostram tráfego no centro e periferia;
  `16` mostra a cadeia inteira de maciços; e `17` mostra campo, fazenda, cidade e serra no mesmo
  panorama. O pedestre fotografado precisa estar animado e em pé.
- As 18 imagens novas foram abertas e inspecionadas individualmente nos pontos alterados. Essa
  inspeção encontrou uma regressão que os números não viam: o retarget movimentava os membros do
  soldado, mas a rotação absoluta do quadril o deixava deitado. A correção e a trava automatizada
  ficaram no commit específico de NPCs; as capturas `08a`/`08b` finais mostram o soldado ereto e
  em duas fases distintas da passada.
- Validação final aprovada: `world_tour` com 18 capturas e resultado explícito; `npc_test` com 72
  NPCs/23 modelos; `city` com 64 quarteirões, 877 construções e 30 maciços dentro do chão;
  `obstacles_test` com 6.458 sólidos, zero parede invisível/colisão excessiva e corredor central
  livre nas duas estradas; `scale_test` com 9.379 objetos, zero flutuante e 30 bases no solo; e
  `gaps_test` com 93%/zero borda vazia. Os avisos de objetos/recursos no encerramento já são
  conhecidos e aparecem depois de `RESULTADO`; os testes encerraram em sucesso.
- Esta mudança do jogo deve ser enviada ao Claude para revisão prática independente. Builds,
  reextração do `.app` e release pública permanecem como último passo, somente após o aval.

## 2026-08-16 — revisão fechada e artefatos da v0.3.3 (Codex + Claude)

- O Claude atualizou a revisão depois de `03207f7` e `39dbcef` já estarem no `HEAD`, refez as
  fotos da cordilheira e da transição campo–cidade no estado final e marcou os achados da rodada
  como corrigidos. A referência antiga `a445a10` foi mantida como início da revisão, mas o hash
  final dos NPCs é `03207f7`, que inclui a correção visual do quadril.
- Windows foi reexportado em `builds/windows/JeguesMecanicos.exe` e empacotado como
  `JeguesMecanicos-Windows.zip`. macOS foi reexportado como `JeguesMecanicos.zip`; o `.app`
  anterior foi preservado em `previous-apps` e o novo `builds/macos/Jegues Mecanicos.app` foi
  reextraído do ZIP, conforme a regra que evita o usuário abrir uma versão velha.
- `pack_audit.py` conferiu pacote de 893 MB, 105 referências diretas, 71 caminhos montados em
  runtime e o catálogo de personagens, sem problema. `unzip -t` aprovou os dois ZIPs;
  `codesign --verify --deep --strict` aprovou o `.app`; o binário macOS iniciou em modo headless;
  e o `.pck` extraído tem o mesmo SHA-256 do arquivo dentro do ZIP.
- SHA-256: macOS ZIP `1fb96675a5ff531f7ead21fc1be99971bbdd8caecaf0da21a5f1061922341fdc`;
  Windows ZIP `72a270c66bd3a5654e9cfc8635dbbefe2101dc6fb29ba130d1b4d7fd78510528`;
  `.pck` macOS `da57c18ba2299dd1ea6d332842963841fe65f2a37908179653164ef1e7057b4f`.
- A release pública destinada a esses artefatos é `v0.3.3`, contendo as correções da chuva, a
  variedade/locomoção dos NPCs e a rodada visual do mundo rural aprovada na revisão.

## 2026-08-20 — apoio público ao projeto (Codex)

- Criado `.github/FUNDING.yml` com o endereço público
  `https://buymeacoffee.com/vitudanas`, fornecido pelo autor, para habilitar o botão de apoio do
  GitHub. Nenhum dado bancário, e-mail, credencial, token ou caminho local foi incluído.
- Primeira mudança feita no fluxo novo de branch: `codex/add-buymeacoffee`, integrada à `main`
  pelo PR #1 depois da revisão. É uma alteração somente de metadados/documentação; não exige
  testes do jogo, exportação nem nova release.

## 2026-08-20 — fluxo somente com Codex e linguagem corporal neutra (Codex)

- O usuário informou que a assinatura do Claude terminou e transferiu ao Codex todas as funções
  de implementação, revisão, testes adicionais, aprovação final, builds e publicação. O
  `AGENTS.md` não exige mais handoff ou aval externo: o Codex faz duas passagens distintas,
  documenta o estado exato revisado e só então publica uma mudança do jogo.
- Registros históricos continuam citando o Claude quando isso identifica corretamente quem fez
  uma revisão passada. Eles são memória do projeto, não uma dependência do fluxo atual.
- A documentação atual foi revisada para retirar descrições explícitas de partes corporais e
  medidas associadas. As decisões relevantes agora são descritas somente como **ajustes de
  proporções corporais**, preservando o aprendizado sobre shape keys, roupa, silhueta e
  compatibilidade entre modelos sem detalhamento desnecessário.
- A busca final em `*.md`, `*.txt`, `*.rst`, `*.adoc`, `*.yml` e `*.yaml` encontrou zero
  ocorrência dos termos explícitos em português ou inglês cobertos pela varredura. Esta rodada
  altera apenas documentação e regras operacionais; não exige teste do jogo, build ou release.

## 2026-08-20 — minimapa local e zonas no HUD (Codex)

- A continuação do desenvolvimento começou pela maior lacuna de usabilidade ainda registrada na
  análise do mundo aberto: orientação dependia da seta central e não ajudava o jogador a aprender
  a cidade. O HUD ganhou um minimapa compacto no canto direito, abaixo do estado do mundo.
- `scenes/ui/Minimap.gd` desenha diretamente no Canvas a grade real de `CityStreets`, o jogador,
  sua orientação, a direção do objetivo e o marcador limitado à borda quando o destino está fora
  do alcance local de 190 m. Não usa segunda câmera, viewport ou textura do mundo, evitando
  duplicar o custo de renderização.
- O cabeçalho do mapa informa `CENTRO`, `ZONA NORTE`, `ZONA SUL`, `ZONA LESTE` ou `ZONA OESTE`
  conforme a posição. A bússola e a distância existentes foram preservadas para leitura rápida;
  o mapa serve para compreender cruzamentos e planejar a próxima curva.
- `loop_test` passou pelo fluxo completo com input real e agora reprova se o minimapa não achar a
  malha viária, não receber o objetivo ou deixar o marcador escapar do painel. Na execução final,
  exibiu as ruas e o destino na Zona Oeste, acompanhou o carro, e o restante do ciclo terminou com
  compra, quatro instalações, direção, negociação, venda e próxima entrega funcionando.
- A segunda passagem visual gerou oito capturas reais em `loop_shots`. Foram abertas e conferidas
  as vistas do ferro-velho, direção no Centro e chegada na Zona Leste: o minimapa não sobrepõe o
  velocímetro, o objetivo permanece legível perto e longe, o ícone acompanha a orientação e a
  pista central continua livre. A captura dirigindo permaneceu em 60 FPS; esse valor é evidência
  da rodada visual, não um benchmark geral do mapa.
- O README público agora menciona o minimapa e descreve corretamente o fluxo atual somente com o
  Codex, preservando a participação de outras ferramentas como histórico. Esta é mudança de jogo:
  depois do fechamento do commit e da segunda validação, exige novas builds Windows/macOS,
  reextração do `.app`, auditoria dos pacotes e release de correção.
- Fechamento no commit de jogo `374e232`: Windows foi reexportado e empacotado como
  `JeguesMecanicos-Windows.zip` (464.832.684 bytes); macOS foi reexportado como
  `JeguesMecanicos.zip` (490.736.410 bytes). O aplicativo anterior foi preservado em
  `builds/macos/previous-apps/Jegues Mecanicos-20260820-before-v0.3.4.app` e o novo
  `builds/macos/Jegues Mecanicos.app` foi reextraído do ZIP.
- `pack_audit.py` aprovou o pacote de 893 MB, 106 referências, 71 caminhos montados e o catálogo
  de personagens. `unzip -t` aprovou os dois ZIPs, `codesign --verify --deep --strict` aprovou o
  `.app`, o `.pck` extraído é idêntico ao do ZIP e o binário macOS abriu em headless e encerrou
  com código 0. SHA-256: macOS
  `f8937b99951cacacf75f26c9182ad73286f8dd64dfdeeb0eb431fc41154d04b0`; Windows
  `a364f07243000e09fb3c7c6dd57c4db8f601d913368dee5ac15ab40e7a2e3485`; `.pck`
  `eba1b8fa5173dd3395bb6a7c83f35f1d713d5f444ab15ca0c14a3b95f5962c99`.
- A release pública desta rodada é `v0.3.4`, com o minimapa local e as melhorias de orientação.

## 2026-08-20 — música no menu e no mundo (Codex)

- A lacuna seguinte de apresentação sonora foi tratada com duas gravações CC0 reais: `Offline`,
  de Cleyton Kauffman, no menu; e `Super Wreck Roadway`, de Umplix, durante o jogo. Os arquivos,
  fontes e licença ficam em `assets/opengameart/music/`; os autores também entraram no gerador,
  na documentação e na tela de créditos. A faixa de estrada original em WAV foi convertida para
  Ogg Vorbis para cair de aproximadamente 49 MB para 2 MB sem alterar o conteúdo musical.
- O `AudioManager` ganhou barramento `Music`, volume salvo independente (padrão 50%) e dois
  tocadores em laço com transição de 2 s. O menu fica em -16 dB e o mundo em -22 dB antes do
  controle do barramento, escolha conservadora para preservar motor, batidas, chuva, trânsito e
  alertas de interface em primeiro plano.
- A primeira implementação interpolava decibéis diretamente e abria um vale de -48/-51 dB no
  meio da troca. A segunda passagem de revisão encontrou o defeito antes do commit; o crossfade
  agora interpola ganho linear, mede -22/-28 dB no meio e tem teste de regressão específico.
- `audio_test` passou com 18 chaves/47 efeitos, três barramentos, faixas de 33,6 s e 134,4 s,
  loops ativos, silêncio correto da faixa oposta nos extremos, controle de música zerando o
  barramento e todos os eventos/ambientes anteriores funcionando. `ui_shot` passou com quatro
  sliders e 60 linhas de crédito; a captura `03_configuracoes_som` foi aberta e conferida, com
  os quatro controles e percentuais legíveis sem sobreposição.
- A repetição do `ui_shot` sobre o commit revelou falsos erros de parsing depois do resultado:
  o teste encerrava o processo enquanto `Main.tscn` ainda era lido em outra thread para a foto
  de carregamento. O roteiro agora congela a tela e drena a requisição antes de sair; repetiu as
  seis capturas, quatro sliders e 60 linhas de crédito sem a cascata falsa de erros.
- Limite honesto da sessão: a seleção foi baseada nas páginas/fontes, licença, duração e medições
  objetivas de RMS/pico; não há audição humana disponível nesta sessão. O usuário ainda deve
  avaliar subjetivamente estilo, repetição e conforto da mixagem no build. A rodada não altera o
  mundo, portanto `city` e `obstacles_test` não se aplicam. Builds e release serão registrados no
  fechamento depois do commit e da validação dos pacotes.
- Fechamento integrado pelo PR #2: implementação final `bc9bb85` e correção do teste `f85857d`.
  Windows foi reexportado e empacotado como `JeguesMecanicos-Windows.zip` (471.920.214 bytes);
  macOS foi reexportado como `JeguesMecanicos.zip` (494.515.299 bytes). O `.app` da v0.3.4 foi
  preservado em `previous-apps` e o novo `builds/macos/Jegues Mecanicos.app` foi reextraído.
- `pack_audit.py` aprovou pacote de 897 MB, 106 referências, 71 caminhos montados e catálogo de
  personagens. `unzip -t` aprovou os dois ZIPs, `codesign --verify --deep --strict` aprovou o
  `.app`, o binário exportado abriu em headless e encerrou com código 0, e o `.pck` reextraído é
  idêntico ao do ZIP. SHA-256: macOS ZIP
  `76f5aebc44b6ce2feb334b4114ecd06ecdd563c1a18a798304d894e91b59e144`; Windows ZIP
  `7a809548e74c65b42af5bce4dadbf1e158f8f97875c4174d6015e252db870cb6`; `.pck`
  `b3a892a754a74effb6ed0dba2428a9ffa45d7cc1e58848cc2d4b02ef9e807767` (897.193.600 bytes).
- A release pública desta rodada é `v0.3.5`, com música distinta no menu e no mundo, crossfade e
  volume independente.

## 2026-08-20 — limpeza do histórico da descrição do PR #2 (Codex)

- Ao criar o PR #2, marcadores de código foram interpretados pelo shell e a primeira descrição
  incorporou saída de testes, incluindo um caminho da máquina local. A descrição visível foi
  corrigida imediatamente, mas o GitHub preservava a versão anterior no histórico de edições.
- Depois de autorização expressa do usuário, a revisão antiga foi excluída pelo controle de
  histórico do próprio GitHub. A conferência autenticada final mostra a entrada como `deleted` e
  não permite mais abrir seu conteúdo; a descrição atual do PR permaneceu limpa e intacta.
- Nenhum token, credencial, chave ou conteúdo do jogo foi afetado. Esta rodada altera apenas a
  memória operacional e metadados do GitHub; não exige testes do jogo, builds ou nova release.
