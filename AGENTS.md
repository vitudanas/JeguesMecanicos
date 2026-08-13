# AGENTS.md — Coordenação Codex + Claude

Olá, Claude. Sou o Codex e, a partir de 2026-08-13, estou trabalhando com você
no desenvolvimento de **Jegues Mecânicos**. Li o projeto, o histórico e as
regras registradas no `CLAUDE.md`. A intenção desta divisão é termos uma etapa
de produção e outra de revisão independentes.

## Regra temporária de trabalho

Esta regra vale de **2026-08-13 até 2026-08-31, inclusive**, no fuso
`America/Sao_Paulo`. Depois dessa data, a divisão deve ser confirmada novamente
com o usuário; não presumir renovação automática. Uma ordem direta posterior do
usuário pode substituir esta regra.

### Codex — implementação e primeira validação

O Codex é responsável por:

1. implementar as mudanças pedidas pelo usuário;
2. fazer os testes iniciais proporcionais à mudança, incluindo verificações
   automatizadas e visuais relevantes;
3. corrigir os problemas encontrados nessa primeira validação;
4. documentar cada rodada no `CLAUDE.md`;
5. quando houver mudança no jogo, reexportar Windows e macOS e conferir o
   binário exportado conforme as regras do `CLAUDE.md`;
6. criar o commit e enviar a alteração ao GitHub;
7. entregar ao Claude o hash do commit, o resumo da mudança, os testes feitos e
   qualquer ressalva conhecida;
8. **publicar as builds verificadas na release do GitHub — DEPOIS da revisão do
   Claude, não antes** (ver "Ordem: revisar antes de publicar"). Push do código
   sozinho não conclui uma mudança do jogo. Se o usuário não indicar uma versão,
   criar a próxima release de correção e anexar Windows e macOS com nomes claros.

### Claude — revisão e validação adicional

Depois do envio do Codex, o Claude é responsável por:

1. revisar integralmente o diff/commit, procurando regressões, erros de lógica,
   integração, desempenho, assets, exportação e aderência ao pedido do usuário;
2. executar testes adicionais e de regressão além da primeira bateria feita
   pelo Codex, incluindo testes visuais ou do build quando forem relevantes;
   **teste prático é obrigação, não item opcional da revisão** — rodar o jogo
   de verdade, tirar as fotos do que mudou e OLHAR uma a uma, exercitar o
   caminho pelo input real e, quando o achado for de comportamento, escrever um
   teste novo que o reproduza. Revisão só por leitura de diff não conta como
   revisão feita. Um worktree sujo com trabalho do outro agente **não é motivo
   pra pular**: rode assim mesmo e diga na anotação qual estado foi
   fotografado (commit puro ou commit + rodada em andamento);
3. documentar no `CLAUDE.md` o que revisou, os resultados e as pendências;
4. devolver ao Codex os problemas encontrados, com evidências e passos de
   reprodução, para que o Codex faça a correção e um novo commit;
5. repetir a revisão após as correções até não restar problema conhecido dentro
   do escopo da rodada.

Durante esta vigência, o Claude atua como revisor e segunda linha de testes; as
implementações e correções voltam ao Codex, salvo se o usuário ordenar
explicitamente outra divisão para uma tarefa específica.

## Regras compartilhadas

- O `CLAUDE.md` continua sendo a memória oficial do projeto e deve ser lido
  antes de trabalhar e atualizado em toda rodada.
- Preservar alterações existentes do outro agente e nunca sobrescrevê-las sem
  entender o estado do worktree e o commit de origem.
- O handoff deve sempre identificar o commit revisado; não revisar ou testar
  supondo que uma cópia local antiga seja a versão enviada.
- Não considerar uma mudança no jogo concluída sem documentação, testes
  proporcionais e, quando aplicável, builds atualizadas e verificadas.
- **Build atualizada inclui reextrair o `.app`.** O `.zip` é o artefato, mas o
  que o usuário abre com dois cliques é o `builds/macos/Jegues Mecanicos.app`
  extraído, e ele **não se atualiza sozinho** quando o zip é regravado. Já
  aconteceu duas vezes (2026-08-04 e 2026-08-13) de o usuário estar jogando um
  build anterior sem nenhum aviso. Apagar o antigo e extrair de novo faz parte
  de exportar.
- **Build atualizada inclui release atualizada no GitHub.** Regra pedida pelo
  usuário em 2026-08-13: toda mudança do jogo precisa terminar com os artefatos
  Windows e macOS verificados publicados numa release. Commit e push na `main`
  sem atualizar a release pública deixam o trabalho incompleto.

## Regras de git (2026-08-13)

Levantadas numa auditoria do repositório a pedido do usuário. O git **está
configurado e sendo usado de verdade** — 96 commits, 2.101 arquivos, tudo em
sync com `origin/main`, `.gitignore` cobrindo `builds/` e os downloads crus.
Estas regras são sobre COMO usar, não sobre fazer funcionar.

- **Ordem: revisar antes de publicar.** A release pública é o último passo, e só
  depois do aval do Claude. O motivo é concreto: em 2026-08-13 a **v0.3.1 saiu às
  16:05Z carregando o bug do preço congelado da negociação**, que só apareceu na
  revisão e só foi corrigido na v0.3.2, uma hora depois — duas releases públicas
  no mesmo dia, a primeira com defeito. Push na `main` pode continuar sendo
  imediato (é o que dá o hash do handoff); o que espera é a release.
- **Um commit, um assunto.** O `426c45d` juntou num commit só o conserto de um
  bug de negociação, um refactor de HUD, mudanças em três cenas do mundo, um
  ajuste no shader de montanha **e o teste + as anotações do revisor**. Assim não
  dá pra reverter o conserto sem levar o shader junto, e o título não conta que
  um bug de gameplay foi corrigido ali.
- **Nada de `git add -A` com dois agentes no mesmo worktree.** É a causa do item
  acima e já aconteceu nas duas direções (o Claude quase varreu trabalho do Codex
  em 2026-08-13 de manhã; o Codex varreu o do Claude à tarde). Adicionar arquivo
  por arquivo, ou dar um `git worktree add` pro segundo agente, que resolve na
  raiz.
- **Assinar quem escreveu.** Hoje só um commit do histórico traz
  `Co-Authored-By`, então o `git log` não distingue os dois agentes — justamente
  num protocolo cujo handoff é feito por hash de commit. Cada agente marca os
  seus.
- **Rodar `git gc` de vez em quando.** Na auditoria o `.git` tinha **828 MB em
  4.465 objetos soltos e ZERO packfiles** — nunca tinha sido empacotado, e o blob
  de 195 MB expulso do histórico continuava no disco preso pelo reflog. `git gc`
  resolve o grosso; `git reflog expire --expire=now --all && git gc --prune=now`
  recupera o resto, mas descarta os pontos de recuperação — só com tudo em sync e
  com o usuário ciente.
