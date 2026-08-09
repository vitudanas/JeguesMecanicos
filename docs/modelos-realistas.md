# Lista de compras: prédios realistas para a cidade

Levantado em 2026-08-09, a pedido do usuário. **Isto é uma lista de o que baixar
e o que recusar** — os números vieram do gerador de verdade (`CityBlocks.gd`,
`Town.tscn`), não de regra genérica de internet.

Divisão de trabalho: **você baixa** (Sketchfab e Fab exigem conta, e eu não
posso criar nem logar), **eu normalizo e integro** (escala, origem, colisão,
LOD, zoneamento, tint desligado).

---

## 1. O que o gerador exige (requisitos duros)

A cidade não é montada à mão: `CityBlocks` enfileira prédios encostados na
calçada, virados pra rua, medindo a largura real de cada modelo. Um modelo que
não obedeça a isto simplesmente não entra na fila.

| Requisito | Valor | Por quê |
|---|---|---|
| **Prédio inteiro** | não peça modular | o gerador instancia UMA cena por lote; parede/janela avulsa exigiria um montador de fachada, que é outro projeto |
| **Profundidade da planta** | **≤ 13,8 m** | é metade do miolo do quarteirão (28,3 m) menos a folga; mais que isso e duas bordas opostas se encontram no meio |
| **Largura da planta** | 6 a 20 m (ideal) | abaixo de 6 vira quiosque; acima de 20 sobra pouco lote pro vizinho |
| **Altura** | 6 a 40 m | hoje a média é 8,7 m e o mais alto tem 33,6 m |
| **Base plana, apoiada em y = 0** | sem saia de terreno, sem porão, sem calçada colada | o chão da cidade é plano; qualquer base modelada aparece flutuando ou enterrada |
| **Sem rig, sem animação** | — | são prédios |
| **Triângulos** | **≤ 25 mil** por prédio (até 50 mil no caso de um marco) | ~40 prédios visíveis na rua; a 25 mil dá 1 milhão na tela, que passa folgado |
| **Materiais por prédio** | **≤ 3 slots** | cada slot é uma chamada de desenho por instância visível |
| **Texturas** | **2K no máximo**, PBR (cor + normal + rugosidade) | 2K comprimido ≈ 12 MB de VRAM por modelo; 30 modelos ≈ 360 MB, que passa. Em 4K seriam 1,4 GB, que não passa |
| **Formato** | **glTF/GLB** > FBX > (evitar OBJ) | glTF é nativo do Godot; FBX importa bem; OBJ perde o PBR |

**O que eu ajusto e você não precisa se preocupar:** escala (o kit atual usa
módulo 7,5 e um modelo em metros usa 1,0 — eu passo o gerador a aceitar escala
por modelo), origem deslocada (já é descontada), colisão (gerada da malha), e
desligar o tint de fachada e o shader do kit em cima dos realistas — senão a
gente pinta por cima da textura boa.

---

## 2. Motivos de RECUSA (o que parece bom e não serve)

Isto é mais importante que a lista de sites. A maioria dos "prédios realistas"
gratuitos falha em um destes:

1. **Sombra e oclusão pintadas na textura** (típico de fotogrametria). Nossa luz
   é dinâmica com céu HDRI; sombra pintada não bate com a hora do dia e, pior,
   aparece **idêntica** em todas as cópias do mesmo prédio.
2. **Fotogrametria de 300–800 mil triângulos.** Bonita sozinha, impossível 20
   vezes na tela — e o Godot 4 **não tem Nanite**.
3. **Fachada única sem laterais** (modelo feito pra foto de frente). Aqui o
   prédio é visto de esquina; o gerador vira ele pra rua, mas os dois lados
   aparecem.
4. **Prédio com terreno junto** — grama, calçada, muro, árvore no mesmo mesh.
5. **Escala errada ou ausente** (modelo em centímetros ou em unidades
   arbitrárias). Corrigível, mas some com a estimativa de largura se vier junto
   com origem maluca.
6. **Licença sem redistribuição**: "free" no CGTrader/TurboSquid muitas vezes é
   *royalty-free para uso*, não *redistribuível dentro de um jogo*. Se a licença
   não disser claramente que dá pra usar em produto comercial, não serve.

---

## 3. Onde procurar, em ordem de aposta

### 3.1 Fab (Epic) — **a melhor aposta**
- A **Fab Standard License não é restrita ao Unreal**: vale em qualquer engine.
  Baixe a versão **FBX**, não a "Unreal Engine".
- Tem uma **seção gratuita que a Epic renova toda semana/mês**, e ela cai
  bastante em ambiente urbano (ex.: "Downtown Alley", 50+ malhas com LOD e PBR
  2K, foi grátis por um mês).
- Filtros: `3D Model` → `Environments / Architecture`, e ordene por gratuitos.
- **Sempre confira**: se o pacote só existir como projeto/plugin do Unreal, o
  trabalho de extrair não compensa. Precisa ter download FBX ou glTF.

### 3.2 Sketchfab — **o maior volume**
- 800 mil+ modelos baixáveis; glTF é o export padrão deles.
- **Filtre por licença**: aceite **CC0** e **CC-BY**. CC-BY só exige crédito —
  eu faço uma tela de créditos no menu, é meia hora de trabalho.
  **Recuse CC-BY-NC** (proíbe uso comercial) e **CC-BY-ND** (proíbe modificar, e
  a gente precisa modificar).
- Termos que rendem: `apartment building lowpoly`, `residential building game
  ready`, `office building game asset`, `shophouse`, `row house`, `warehouse
  game ready`. **Inclua sempre "game ready" ou "low poly"** — é o que separa o
  modelo usável do scan de 500 mil triângulos.
- Olhe o contador de triângulos na página **antes** de baixar (o Sketchfab
  mostra).

### 3.3 BlenderKit
- Tem camada gratuita com modelos CC0, e o filtro de licença é confiável.
- Vantagem: quase tudo já vem em escala de metros e com origem na base.

### 3.4 O que **não** vale a pena procurar
- **Poly Haven**: a categoria de arquitetura está **vazia** (conferido hoje). O
  que eles têm de ótimo — HDRI e textura — a gente já usa.
- **ambientCG**: material, não prédio. Já em uso nas fachadas.
- **Kenney / KayKit / Quaternius**: todos estilizados. O `Kenney Modular
  Buildings` foi baixado e avaliado hoje: mais pastel que o kit atual, pioraria.
- **3D Warehouse (SketchUp)**: licença nebulosa, geometria suja.

---

## 4. Quantos baixar, por zona

O zoneamento da cidade é por distância do centro (Chebyshev). A lista abaixo
supõe a **opção híbrida** (ver seção 5), com o realista no miolo.

| Zona | Quantos modelos | O que é |
|---|---|---|
| Torre / centro | **8 a 10** | 20–40 m, escritório, edifício comercial envidraçado |
| Comércio (anel do meio) | **10 a 12** | 8–20 m, prédio de esquina, sobrado comercial, loja com apartamento em cima |
| Casa (periferia) | **8 a 10** | 5–10 m, casa geminada, sobrado |
| Galpão / industrial | **4 a 6** | 6–12 m, barracão, depósito |

**O número mínimo importa mais do que parece.** Hoje são 837 prédios saindo de
~60 modelos. Com 30 modelos realistas, cada um aparece ~28 vezes — e **realismo
piora a repetição**: o olho perdoa um cubo low-poly repetido, mas reconhece na
hora o mesmo prédio fotográfico três esquinas depois. Abaixo de ~8 modelos por
zona o resultado fica pior que o atual, não melhor.

---

## 5. As opções, e o que eu recomendo

### A. Trocar tudo por realista
Precisa de 30–40 modelos bons. **Risco alto**: se o acervo ficar pequeno, a
repetição fica gritante (ver acima) e o resultado é pior que hoje. Também é o
caminho mais longo de normalização.

### B. Miolo realista + periferia estilizada ← **recomendo esta**
O jogador dirige no centro; a periferia é fundo. Precisa de ~10 modelos bons pra
começar a mudar a impressão, contra 40.

O projeto já aprendeu que **misturar dois estilos lado a lado fica feio**
(changelog 2026-08-02, foi o problema que motivou padronizar a cidade inteira em
Kenney). Mas ali eles estavam **intercalados**. Zoneado por distância funciona —
é exatamente o que já acontece hoje entre a cidade Kenney e o campo Quaternius,
e ninguém reclamou da transição. A regra é: a troca de estilo acontece num
**anel**, não numa esquina.

### C. Manter a geometria e subir só o acabamento
É o que vem sendo feito (PBR nas fachadas, céu HDRI, vitrines, entulho de
telhado). Risco zero, ganho decrescente. Vale como complemento das outras, não
como resposta.

### D. Geometria real de cidade (OpenStreetMap)
Dá pra gerar a cidade a partir de dados reais — quarteirões, ruas e alturas de
uma cidade que existe. O **layout** fica autêntico como nenhum kit fica, mas os
prédios saem como caixas extrudadas sem textura: o realismo teria que vir todo
do material. Substitui o `CityBlocks` inteiro. É um projeto à parte, e honesto
dizer que é o mais interessante e o mais caro.

### E. Trocar de engine (UE5)
Nanite e Lumen resolveriam a parte gráfica de verdade. Mas o jogo são ~10 mil
linhas de sistema (física do carro, gambiarra, economia, loja, funcionários,
save, som) e 16 arnêses de verificação — tudo isso seria reescrito, e cada bug
já morto voltaria em outra forma. **Não recomendo.**

---

## 6. Ordem prática

1. Você baixa **6 modelos** quaisquer da faixa "comércio" que passem na seção 1
   e não caiam na seção 2. Joga em `assets/realistas/`.
2. Eu integro e **meço** no lugar de verdade: chamadas de desenho, triângulos e
   VRAM no nível da rua, com a cidade cheia. Comparo com o número de hoje
   (~2.500 chamadas).
3. Com o número na mão a gente decide se escala pra 30 ou se para por aí. Um dia
   de trabalho em vez de uma semana, e a decisão passa a ser sobre um fato.
