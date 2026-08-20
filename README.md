# Jegues Mecânicos

**Um sandbox 3D brasileiro de carros, gambiarras e negócios questionáveis.**

Em *Jegues Mecânicos*, você compra carcaças no ferro-velho, diagnostica defeitos,
improvisa consertos com peças absurdas, enfrenta ruas esburacadas e tenta vender o
resultado antes que tudo se desmonte. O jogo combina mundo aberto, física caótica,
gestão de oficina e negociação com humor.

[Baixar a versão mais recente](https://github.com/vitudanas/JeguesMecanicos/releases/latest)
· [Ver todas as versões](https://github.com/vitudanas/JeguesMecanicos/releases)
· [Créditos dos assets](docs/creditos.md)

> O projeto está em desenvolvimento ativo. Sistemas, balanceamento, desempenho e
> apresentação visual ainda podem mudar.

## Principais recursos

- Explore uma cidade aberta com tráfego, pedestres, clima, lama e eventos.
- Compre carros usados depois de vistoriar e pechinchar no ferro-velho.
- Diagnostique problemas mecânicos e evolua oficina, funilaria, pátio e escritório.
- Instale 12 tipos de gambiarra com preços e resistências diferentes.
- Faça test-drives em ruas esburacadas, com peças que podem se soltar durante o trajeto.
- Negocie a venda por rodadas usando oferta, contraproposta e blefe.
- Oriente-se pelo minimapa local, com ruas, zona atual e destino da etapa.
- Ouça trilhas distintas no menu e na estrada, com volume de música independente.
- Personalize o personagem e escolha entre diferentes câmeras ao dirigir.
- Continue o progresso salvo automaticamente após as vendas.

## Como jogar

Baixe o pacote do seu sistema na
[release mais recente](https://github.com/vitudanas/JeguesMecanicos/releases/latest).

### Windows

Extraia `JeguesMecanicos-Windows.zip` e execute `JeguesMecanicos.exe`. Como o jogo
ainda não possui certificado de assinatura comercial, o Windows pode mostrar um aviso
do SmartScreen na primeira execução.

### macOS

Extraia `JeguesMecanicos.zip`. Na primeira execução, clique com o botão direito em
`Jegues Mecanicos.app`, escolha **Abrir** e confirme. O aplicativo usa assinatura
ad-hoc e ainda não é notarizado pela Apple.

## Controles principais

| Contexto | Controles |
| --- | --- |
| A pé | `W A S D` mover · `Shift` correr · `Espaço` pular · `E` interagir |
| Carro | `W/S` acelerar e dar ré · `A/D` virar · `Espaço` freio de mão · `F` sair · `R` desvirar |
| Ferro-velho e oficina | `Q` vistoriar, pechinchar, diagnosticar ou trocar opção · `E` comprar/instalar |
| Negociação | `E` aceitar · `Q` contrapropor · `F` blefar |
| Câmera e menus | `V` trocar câmera · `Esc` pausar |

As ações disponíveis também aparecem no HUD conforme o contexto.

## Autoria e uso de inteligência artificial

**Jegues Mecânicos é criado por Vitor Rodrigues Danas**, responsável pela ideia,
direção criativa e decisões do projeto. O desenvolvimento é realizado
majoritariamente com assistência de inteligência artificial. Atualmente, o Codex
auxilia principalmente em programação, testes, documentação e iteração visual;
outras ferramentas de IA também participaram de etapas anteriores.

## Desenvolvimento

O projeto usa [Godot Engine 4](https://godotengine.org/) e GDScript.

Para executar pelo editor:

1. Instale uma versão compatível do Godot 4.
2. Importe o arquivo `project.godot`.
3. Pressione `F5` para iniciar o jogo.

## Créditos e licenças

O jogo utiliza assets de terceiros sob licenças CC0 e CC-BY 4.0. A relação de obras,
autores, fontes e licenças está em [docs/creditos.md](docs/creditos.md) e também é
exibida dentro do jogo.

O código-fonte do projeto ainda não possui uma licença geral definida. A presença do
código neste repositório não concede automaticamente permissão de reutilização,
redistribuição ou venda. Os assets de terceiros continuam sujeitos às licenças de seus
respectivos autores.
