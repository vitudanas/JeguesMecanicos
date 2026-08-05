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
```

Todos saem com código 0 quando não acham problema.

Dois **precisam de janela de verdade** (`--headless` não rasteriza, e sem
rasterizar não há foto nem contagem de desenho):

```bash
godot --path . tools/verify/quality_shots.tscn   # fotos + chamadas de desenho
godot --path . tools/verify/settings_test.tscn   # o menu de gráficos faz efeito?
```

`quality_shots` fotografa grama e fachadas do ponto de vista do jogador e
imprime **chamadas de desenho e primitivas** por foto — não milissegundos: tempo
de quadro medido aqui saiu sem relação nenhuma com o conteúdo (com a grama
DESLIGADA o quadro saiu mais lento), porque o macOS estrangula a janela fora de
foco. Contagem do renderizador não depende disso.

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
