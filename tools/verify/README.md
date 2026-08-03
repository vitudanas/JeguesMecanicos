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
```

Ambos saem com código 0 quando não acham problema.
