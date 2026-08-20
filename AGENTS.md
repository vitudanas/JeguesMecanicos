# AGENTS.md — Operação do Codex

Desde **2026-08-20**, por ordem direta do usuário, o desenvolvimento de
**Jegues Mecânicos** segue somente com o Codex. A assinatura do Claude terminou
e todas as responsabilidades antes divididas entre implementação e revisão
passaram ao Codex. Registros históricos do trabalho conjunto permanecem no
`CLAUDE.md`, mas não definem mais o fluxo atual.

## Responsabilidades do Codex

O Codex é responsável por:

1. implementar as mudanças pedidas pelo usuário;
2. fazer os testes iniciais proporcionais à mudança, incluindo verificações
   automatizadas e visuais relevantes;
3. corrigir os problemas encontrados nessa primeira validação;
4. fazer uma **segunda passagem de revisão** antes de considerar a rodada
   aprovada: reler o diff/commit integral, procurar regressões de lógica,
   integração, desempenho, assets e aderência ao pedido, e executar testes
   adicionais ou repetidos nos pontos de maior risco;
5. quando a mudança for visual ou comportamental, rodar o jogo de verdade,
   exercitar o caminho pelo input real quando aplicável, gerar capturas e
   inspecioná-las; leitura de diff sozinha não conta como validação final;
6. quando surgir um defeito, escrever teste de regressão quando for viável,
   corrigir e repetir as duas passagens até não restar problema conhecido no
   escopo;
7. documentar implementação, primeira validação, revisão final e ressalvas no
   `CLAUDE.md`;
8. quando houver mudança no jogo, reexportar Windows e macOS e conferir o
   binário exportado conforme as regras do `CLAUDE.md`. O usuário autorizou
   expressamente o Codex a substituir/reextrair o
   `builds/macos/Jegues Mecanicos.app`, gerar os ZIPs e publicar os artefatos
   Windows/macOS nas releases do GitHub;
9. criar commits por assunto e enviar as alterações autorizadas ao GitHub;
10. **publicar as builds verificadas na release do GitHub somente depois da
    segunda passagem de revisão do próprio Codex**. Push do código sozinho não
    conclui uma mudança do jogo. Se o usuário não indicar uma versão, criar a
    próxima release de correção e anexar Windows e macOS com nomes claros.

## Regras permanentes

- O `CLAUDE.md` continua sendo a memória oficial do projeto e deve ser lido
  antes de trabalhar e atualizado em toda rodada.
- Preservar alterações existentes do usuário e nunca sobrescrevê-las sem
  entender o estado do worktree e o commit de origem.
- A segunda passagem deve identificar o commit ou estado exato revisado; não
  testar supondo que uma cópia local antiga corresponde à versão enviada.
- Não considerar uma mudança no jogo concluída sem documentação, testes
  proporcionais e, quando aplicável, builds atualizadas e verificadas.
- **Mudança de mundo exige `city` e `obstacles_test`.** Ambos fazem parte da
  validação obrigatória do Codex sempre que houver alteração em mapa,
  terreno, ruas, quarteirões, vegetação, fazendas, montanhas, colisões ou
  espalhadores. Eles não podem ser substituídos apenas por `scale_test` ou por
  screenshots: na revisão de `fb7b78c`, foram justamente `city` e
  `obstacles_test` que encontraram a serra passando da borda do chão e uma
  parede invisível da `twisted-tree`.
- **Manter o repositório público seguro.** Não commitar tokens,
  credenciais, chaves, arquivos `.env`, e-mails particulares, caminhos que
  revelem contas locais ou outros dados sensíveis. Auditar também todo o
  histórico Git periodicamente — conferir apenas o `HEAD` não é suficiente.
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
  depois da segunda passagem de validação do Codex. O motivo é concreto: em
  2026-08-13 a **v0.3.1 saiu às 16:05Z carregando o bug do preço congelado da
  negociação**, que só apareceu na
  revisão e só foi corrigido na v0.3.2, uma hora depois — duas releases públicas
  no mesmo dia, a primeira com defeito. Push na `main` pode continuar sendo
  imediato (é o que fixa o hash do estado revisado); o que espera é a release.
- **Um commit, um assunto.** O `426c45d` juntou num commit só o conserto de um
  bug de negociação, um refactor de HUD, mudanças em três cenas do mundo, um
  ajuste no shader de montanha **e o teste + as anotações do revisor**. Assim não
  dá pra reverter o conserto sem levar o shader junto, e o título não conta que
  um bug de gameplay foi corrigido ali.
- **Nada de `git add -A` em worktree com alterações alheias.** Essa foi a causa
  de commits misturados no período com dois agentes. Adicionar arquivo por
  arquivo e conferir o stage antes de commitar.
- **Assinar quem escreveu.** O Codex marca seus commits; conteúdo histórico
  escrito por outro colaborador mantém a autoria correspondente.
- **Rodar `git gc` de vez em quando.** Na auditoria o `.git` tinha **828 MB em
  4.465 objetos soltos e ZERO packfiles** — nunca tinha sido empacotado, e o blob
  de 195 MB expulso do histórico continuava no disco preso pelo reflog. `git gc`
  resolve o grosso; `git reflog expire --expire=now --all && git gc --prune=now`
  recupera o resto, mas descarta os pontos de recuperação — só com tudo em sync e
  com o usuário ciente.
