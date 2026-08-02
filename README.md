# Jegues Mecânicos

Jogo 3D sandbox de humor: conserte carros com gambiarras e venda para NPCs antes que
tudo se desmonte no trânsito. Feito em Godot 4. Veja [CLAUDE.md](CLAUDE.md) para o
pitch completo, decisões técnicas e roadmap.

## Como abrir e jogar

1. Abra o Godot 4 (instalado em `/Applications/Godot.app`, ou `godot` no terminal).
2. Botão "Import" → selecione a pasta deste projeto (`project.godot`).
3. Pressione **F5** (ou o botão de play) para rodar a cena `Main.tscn`.

Controles: veja a seção "Controles" no [CLAUDE.md](CLAUDE.md).

## Como exportar (Windows + macOS)

Os dois presets (`Windows Desktop` e `macOS`) já estão configurados em
`export_presets.cfg` e foram testados com sucesso nesta máquina.

### Pelo editor

Projeto → Exportar... → selecione o preset → "Exportar Projeto".

### Pela linha de comando

```bash
godot --headless --export-release "Windows Desktop" builds/windows/JeguesMecanicos.exe
godot --headless --export-release "macOS" builds/macos/JeguesMecanicos.zip
```

A pasta `builds/` é ignorada pelo git (`.gitignore`) — os binários não devem ser
versionados, só gerados sob demanda.

### Observação sobre o macOS (Gatekeeper)

O preset macOS usa assinatura **ad-hoc** (`codesign/codesign=1` em
`export_presets.cfg`) — gratuita, não exige conta de desenvolvedor Apple, e evita o
erro mais feio do Gatekeeper ("app está danificado e deve ser movido pro lixo", que
aparece em apps totalmente sem assinatura). Mesmo assim, por não ser assinado por uma
conta Apple paga nem notarizado, o macOS ainda avisa na primeira abertura. Pra abrir:

1. **Clique com o botão direito (ou Control+clique) no `.app` → "Abrir"** → confirme no
   diálogo. Isso só é necessário na primeira vez.
2. Se aparecer um aviso sem a opção de abrir direto, vá em **Ajustes do Sistema →
   Privacidade e Segurança**, role até a mensagem sobre o app bloqueado e clique em
   **"Abrir Mesmo Assim"**.
3. Alternativa via terminal, removendo a quarentena manualmente:
   ```bash
   xattr -cr "Jegues Mecanicos.app"
   ```

## Como publicar no itch.io

1. Crie o projeto no itch.io (tipo "Downloadable", categoria "Windows" e "macOS").
2. Instale o [butler](https://itch.io/docs/butler/) (ferramenta oficial da itch.io):
   ```bash
   brew install --cask butler
   butler login
   ```
3. Exporte os dois builds (comandos acima).
4. Suba cada canal (troque `seu-usuario/seu-jogo` pelo slug do seu projeto no itch.io):
   ```bash
   butler push builds/windows seu-usuario/seu-jogo:windows
   butler push builds/macos seu-usuario/seu-jogo:mac
   ```
5. No painel do itch.io, marque os dois canais como "This file will be played in the
   browser" **desativado** (é um executável nativo) e confira se os canais aparecem com
   os ícones de Windows/macOS na página do jogo.

## Repositório

Código no GitHub: [github.com/vitudanas/joguinho2](https://github.com/vitudanas/joguinho2)
(privado). A pasta `assets/kenney/` tem pacotes CC0 do Kenney.nl — ver
[CLAUDE.md](CLAUDE.md) para os links e licenças.

## Estrutura do projeto

Ver seção "Estrutura do projeto" em [CLAUDE.md](CLAUDE.md).
