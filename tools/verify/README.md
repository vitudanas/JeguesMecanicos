# Verificação automatizada

Scripts que instanciam as cenas **de verdade** e conferem a geometria/física,
em vez de confiar no que o código pretendia fazer. Ficam no repo (e não no
`debug_tmp/`, que é apagado antes de cada export) porque já foram recriados do
zero duas vezes — e o CLAUDE.md pede verificação a cada rodada.

Estão **fora do build** (`exclude_filter` em `export_presets.cfg`). Se mexer
nesse filtro, confira o `.pck` depois — filtro amplo demais já quebrou o jogo
inteiro uma vez.

```bash
godot --headless --path . tools/verify/city.tscn        # cidade e anel rural
godot --headless --path . tools/verify/drive_test.tscn  # física do carro
godot --headless --path . tools/verify/loop_test.tscn   # core loop com input real
godot --headless --path . tools/verify/attach_test.tscn # mira nos pontos de gambiarra
godot --headless --path . tools/verify/scale_test.tscn  # escala, flutuação, vegetação
godot --headless --path . tools/verify/yard_test.tscn   # dá pra sair do pátio
godot --headless --path . tools/verify/audio_test.tscn  # som carrega e dispara
godot --headless --path . tools/verify/obstacles_test.tscn  # parede invisível e estrada
godot --headless --path . tools/verify/save_test.tscn   # progresso salva e volta
godot --headless --path . tools/verify/loading_test.tscn # a tela de carregamento chega ao fim
```

`obstacles_test` faz a pergunta que o `scale_test` não fazia. Ele compara caixa
de COLISÃO com caixa de DESENHO — e por isso era cego pro pior caso: uma
**árvore** tem colisão de 9×9 m que casa perfeitamente com o desenho e mesmo
assim é parede invisível, porque na altura do carro só existe o tronco. A
pergunta certa é "a colisão é maior que a MALHA na altura em que se trafega?".
Foi assim que 426 corpos apareceram, o pior com 18 m de colisão para 1,6 m de
tronco. Ele também varre o corredor da estrada de terra com uma caixa do tamanho
do carro, que responde "o carro passa aqui?" — outra coisa que comparar caixas
não responde.

`audio_test` existe por uma limitação honesta: **não dá pra ouvir numa sessão
automatizada**. Então ele cobre o que se prova sem ouvido — todo som declarado
existe e carrega, os barramentos respondem ao volume, os dois laços sintetizados
(motor e chuva) têm pico e **emenda medida** (fim comparado com começo; laço que
estala é o pior defeito possível num som que repete), e cada evento do jogo faz
uma voz sair do repouso, chamando os métodos reais. Se o motor *soa* como motor,
só ouvindo.

Todos saem com código 0 quando não acham problema.

Dois **precisam de janela de verdade** (`--headless` não rasteriza, e sem
rasterizar não há foto nem contagem de desenho):

```bash
godot --path . tools/verify/quality_shots.tscn   # fotos + chamadas de desenho
godot --path . tools/verify/settings_test.tscn   # o menu de gráficos faz efeito?
godot --path . tools/verify/player_shots.tscn    # a jogadora de cabeça de jegue
godot --path . tools/verify/ui_shot.tscn         # menu principal e configuração
```

`ui_shot` existe porque a tela de configuração é montada **em código** e já
falhou renderizando invisível (0x0) com todos os controles montados certinho —
nenhum teste de contagem pegava. Ele fotografa e ainda cobra o tamanho medido,
pra falhar alto em vez de gerar uma foto preta que alguém precisa reparar.

`quality_shots` fotografa grama e fachadas do ponto de vista do jogador e
imprime **chamadas de desenho e primitivas** por foto — não milissegundos: tempo
de quadro medido aqui saiu sem relação nenhuma com o conteúdo (com a grama
DESLIGADA o quadro saiu mais lento), porque o macOS estrangula a janela fora de
foco. Contagem do renderizador não depende disso.

`player_shots` fotografa a personagem dos quatro lados, a cabeça em close, e
pelas câmeras do próprio jogo em 1ª e 3ª pessoa. Duas coisas dele valem saber:

- **Ele entra em 3ª pessoa antes de fotografar o corpo.** Em 1ª pessoa o corpo
  fica em `SHADOW_CASTING_SETTING_SHADOWS_ONLY`, então fotografá-lo ali rende 15
  fotos de campo vazio — foi o primeiro resultado deste roteiro.
- **As fotos 16-19 pintam o corpo humano de magenta chapado** e deixam a cabeça
  de jegue normal. É assim que se prova se sobra cabeça humana pra fora do
  crânio: qualquer pedaço aparece como mancha berrante, sem chance de confundir
  com sombra ou com o pelo cinza. A conta de vértices que o script imprime junto
  é **grossa de propósito** (os vértices do `.glb` estão na pose de bind, que não
  é a pose de skin do renderizador — ela acusa uns 2 cm de "exposição" com a
  cabeça inteiramente coberta). Serve de tendência; **quem decide é a foto**.

E um auditor do build, em Python, que confere que **tudo que o jogo referencia
está dentro do `.pck` exportado**:

```bash
python3 tools/verify/pack_audit.py
```

Rode sempre depois de exportar. Ele existe porque essa é a classe de bug mais
cara do projeto e já aconteceu duas vezes — um `exclude_filter` largo demais
cortou uma textura e o jogo não abria (2026-08-02), e um `.tscn` escrito à mão
ficou fora do pacote sem ninguém notar (2026-08-04). As duas só aparecem
rodando o binário exportado; o modo desenvolvedor lê do disco e nunca reclama.

Armadilha do headless que já custou uma investigação: `MultiMesh.set_instance_transform`
**não guarda nada** com o servidor de render falso. Um teste headless que lê a
matriz de volta recebe a identidade mesmo com o espalhamento tendo rodado — por
isso a altura da grama é conferida na configuração (que está em metros), e não
instância por instância.

O `loop_test` percorre o jogo inteiro (reboque → oficina → gambiarras →
dirigir → entrega → venda) apertando **tecla de verdade**:
`Input.parse_input_event()` alimenta o mesmo estado que `Input.is_key_pressed()`
lê, então E e F passam pelo código real do `Player`. Foi ele que achou os 8 bugs
de loop documentados no changelog de 2026-08-04.

Cuidado ao mexer nele: o `RayCast3D` que o `Player` lê é o do passo de física
**anterior**, e o `Player` só interage na borda de subida do E. Reposicionar o
jogador no mesmo frame do toque faz a interação ir pro alvo errado — o que
falha aí é o arnês, não o jogo.
