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
```

Todos saem com código 0 quando não acham problema.

O `loop_test` percorre o jogo inteiro (reboque → oficina → gambiarras →
dirigir → entrega → venda) apertando **tecla de verdade**:
`Input.parse_input_event()` alimenta o mesmo estado que `Input.is_key_pressed()`
lê, então E e F passam pelo código real do `Player`. Foi ele que achou os 8 bugs
de loop documentados no changelog de 2026-08-04.

Cuidado ao mexer nele: o `RayCast3D` que o `Player` lê é o do passo de física
**anterior**, e o `Player` só interage na borda de subida do E. Reposicionar o
jogador no mesmo frame do toque faz a interação ir pro alvo errado — o que
falha aí é o arnês, não o jogo.
