# CLAUDE.md — Jegues Mecânicos

Documento vivo do projeto. Aqui ficam registrados o pitch do jogo, decisões técnicas,
o histórico de ordens/mudanças pedidas pelo usuário e o roadmap. Atualizar sempre que
uma decisão relevante for tomada ou o escopo mudar.

## Notas de fluxo de trabalho

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

- **Assets externos**: baixamos 4 pacotes CC0 (domínio público, sem exigir atribuição)
  do [Kenney.nl](https://kenney.nl), extraídos em `assets/kenney/`:
  - [City Kit (Roads)](https://kenney.nl/assets/city-kit-roads) e
    [City Kit (Commercial)](https://kenney.nl/assets/city-kit-commercial) — ruas e
    prédios; baixados mas **ainda não usados** em `Town.tscn` (reconstrução da cidade
    fica pra próxima rodada, ver Roadmap).
  - [Car Kit](https://kenney.nl/assets/car-kit) — usamos `sedan.glb`, `taxi.glb` e
    `van.glb` (formato GLB) como visual dos carros de tráfego.
  - [Mini Characters](https://kenney.nl/assets/mini-characters) — usamos
    `character-male-a/c.glb` e `character-female-a/c.glb` como visual dos pedestres.
  - `export_presets.cfg` tem um `exclude_filter` cortando os formatos FBX/OBJ e
    previews/docs de cada pacote (só o GLB + texturas usados vão pro build final).
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
  calçada), com visual do Kenney Mini Characters. `contact_monitor` ligado: ao detectar
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

## Controles (vertical slice atual)

- **A pé:** W/A/S/D anda, Shift corre, Space pula, E interage (olhando para o alvo),
  Esc abre/fecha o menu de pause.
- **Dirigindo:** W/S acelera/ré, A/D vira, Space freio de mão, F sai do carro.
- **Venda:** segurar E perto do comprador enche a barra de lábia.
- **Menus:** o jogo abre num menu principal (Jogar/Sair); Esc a qualquer momento
  dentro da partida pausa e abre Continuar/Sair para o Menu/Sair do Jogo.

## Estrutura do projeto

```
project.godot          # config do Godot, autoloads, display/fullscreen
export_presets.cfg     # presets Windows Desktop + macOS (testados e funcionando)
autoload/               GameManager.gd, Economy.gd, WeatherManager.gd (clima/chuva),
                        EventManager.gd (eventos procedurais)
scripts/                Interactable.gd, TowHook.gd, PersuasionMinigame.gd, Pothole.gd
scenes/main/            Main.tscn — cena de entrada (Town + Player + HUD + RainFX)
scenes/player/          Player.tscn/gd — controller 1ª pessoa
scenes/vehicle/         Vehicle.tscn/gd, AttachSpot.gd, GambiarraPart.gd, parts/*.tscn
scenes/world/           Town.tscn (cidade sandbox), Junkyard.tscn, Workshop.tscn,
                        MudZone.tscn/gd, RainFX.tscn/gd
scenes/traffic/         TrafficCar.tscn/gd, TrafficRoute.tscn/gd — carros de IA
scenes/npc/             BuyerNPC.tscn/gd, Pedestrian.tscn/gd, PedestrianRoute.tscn/gd
scenes/ui/              HUD.tscn/gd — dinheiro, prompt de interação, barra de lábia;
                        MainMenu.tscn/gd (tela inicial, cena de entrada do jogo);
                        PauseMenu.tscn/gd (Esc pausa a árvore, some com o mouse)
assets/kenney/          pacotes CC0 do Kenney.nl (roads, commercial, car-kit,
                        mini-characters) — ver "Sistemas de Mundo Aberto"
assets/quaternius/      prédios CC0 do Quaternius Downtown City MegaKit (2 usados
                        em Town.tscn) + Universal Base Characters/Animation
                        Library (baixados, ainda não integrados nos NPCs)
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

## Roadmap (fora de escopo desta vertical slice)

- Multiplayer real (cooperativo na oficina / competitivo pelas ruas). Arquitetura atual
  evita estado local hard-coded onde possível, mas a replicação de rede não foi
  implementada.
- **Malha viária — polimento restante**: as pontas das ruas já têm acabamento
  arredondado, postes de luz, meio-fio/calçada elevada de verdade (com colisão própria,
  já fechando nos 4 cantos de cada cruzamento) e um exemplo de trecho diagonal fora da
  grade ortogonal (ver changelog 2026-08-02, `CityStreets.gd`). Ainda falta: não existe
  peça de cruzamento diagonal-com-ortogonal — o trecho diagonal atual só funciona por
  caber inteiro dentro de um quarteirão vazio, sem cruzar nenhuma rua da grade; pra
  virar uma avenida diagonal de verdade cortando o mapa (tipo Broadway em Manhattan)
  precisaria resolver esses cruzamentos em ângulo, o que não foi tentado ainda.
- Sistema de crafting mais rico (mais tipos de gambiarra, escolha de item por
  inventário em vez de item fixo por ponto de fixação).
- Economia mais profunda (preços variáveis, múltiplos compradores com personalidades
  diferentes, negociação).
- Sons, música, efeitos de UI/menu (menu principal e de pause já existem — ver
  changelog 2026-08-02 —, mas ainda sem áudio nenhum no jogo).
- **NPCs com personagens diferentes de verdade**: `Superhero_Male/Female_FullBody`
  (Quaternius, CC0, em `assets/quaternius/universal-base-characters/Characters/`)
  + roupa Peasant (`assets/quaternius/outfits-fantasy/Outfits/`) + cabelo
  (`assets/quaternius/universal-base-characters/Hairstyles/`) + animação
  (`UAL2_Standard.glb`, 43 animações na versão free). Retargeting **não é
  necessário** (mesmo esqueleto de 65 ossos nos 3 pacotes) e `Pedestrian.gd`/
  `PedestrianRoute.gd` já têm todo o suporte pronto (`character_models`,
  `outfit_scene`/`outfit_scenes`, `hair_scene`/`hair_scenes`,
  `idle_anim_scene`/`walk_anim_scene`). O cabelo prende limpo. **O que falta**:
  a roupa tem um resíduo de clipping (pele nua aparecendo no torso/coxa) porque
  o corpo base e a roupa foram exportados separadamente com uma diferença sutil
  de *bind pose* — testei vários valores de `BODY_SHRINK_UNDER_CLOTHES` em
  `Pedestrian.gd` (0.7 a 0.93) e nenhum resolve 100% sem quebrar outra parte
  (pescoço, cabeça, pé). Usuário pediu o tutorial de como resolver isso na mão
  no Blender — ver caixa abaixo. `Pedestrian.gd` continua usando o personagem
  do Kenney (`characterMedium.fbx`) em `Town.tscn` até esse combinado ficar
  pronto.

  > #### Tutorial: combinar corpo + roupa no Blender (pendente do usuário)
  > Arquivos envolvidos (já estão no repo):
  > - Corpo: `assets/quaternius/universal-base-characters/Characters/Superhero_Male_FullBody.gltf`
  > - Roupa: `assets/quaternius/outfits-fantasy/Outfits/Male_Peasant.gltf`
  >
  > Passo a passo (Blender, gratuito, blender.org):
  > 1. Cena vazia → `File → Import → glTF 2.0` → importe o `Superhero_Male_FullBody.gltf`.
  > 2. Importe também o `Male_Peasant.gltf` na mesma cena (fica com 2 Armatures).
  > 3. Selecione as malhas da roupa (`Male_Peasant_Arms`/`_Body`/`_Feet`/`_Legs`),
  >    abra o modificador **Armature** de cada uma e troque o "Object" pro
  >    Armature do **corpo** (não o da roupa).
  > 4. Delete o Armature duplicado que veio junto da roupa.
  > 5. Aqui aparece o problema de verdade: se a roupa não encaixar direito na
  >    pose de descanso do corpo, ajuste manualmente (mover/rotacionar, ou
  >    "snap" pra mesma posição) até cobrir certinho — deve ser só um pequeno
  >    offset.
  > 6. Com tudo encaixado, selecione corpo + roupa (Armature único) →
  >    `File → Export → glTF 2.0`, exporte como um arquivo novo único (ex:
  >    `Male_Peasant_Combined.gltf`).
  > 7. Repetir pra versão Female (`Superhero_Female_FullBody.gltf` +
  >    `Female_Peasant.gltf`) se quiser os dois sexos.
  > 8. Assim que tiver o(s) arquivo(s) combinado(s), é só colocar em
  >    `assets/quaternius/` e pedir pra trocar o `character_model` das rotas de
  >    pedestre em `Town.tscn` pra apontar direto pra esse combinado — fica bem
  >    mais simples que o esquema atual de "colar duas malhas em runtime" no
  >    `Pedestrian.gd`.
- **Mais prédios prontos do Quaternius**: só 2 dos 3 prédios prontos do Downtown
  City MegaKit foram usados (`Building_Medium_2_001` tem um bug visual, ver
  changelog 2026-08-02). O pacote também trouxe ~150 peças modulares soltas
  (tijolos, cornijas, janelas, sacadas) que dariam pra montar fachadas customizadas
  à mão — não tentado ainda, é um trabalho de "level design" separado.
- Ícone do jogo e notarização (o preset macOS já usa assinatura ad-hoc, gratuita — ver
  changelog 2026-08-02 — mas não é notarizado pela Apple; hoje quem baixar ainda
  precisa clicar em "Abrir" uma vez, ver README).

## Limitações conhecidas da vertical slice

- Se o jogador mirar no corpo do carro (em vez de num ponto de fixação) enquanto ele
  ainda está incompleto, o prompt volta a mostrar "Rebocar [E]" mesmo já estando na
  oficina — inofensivo, só reengancha o TowHook.
- Só existe um comprador (BuyerNPC) e uma rota fixa de potholes na Town.tscn.
