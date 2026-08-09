extends Node
## Regras de economia: quanto vale um carro "consertado" e o quanto a
## gambiarra pesa contra o jogador na hora de convencer o comprador.
## Autoload (singleton) — registrado em project.godot [autoload].

const BASE_CAR_VALUE := 220

## Preco que o comprador topa pagar, considerando quantas gambiarras
## ainda estao inteiras (intact_parts) sobre o total de pontos do carro.
func estimate_sale_price(intact_parts: int, total_parts: int) -> int:
	if total_parts <= 0:
		return BASE_CAR_VALUE
	var ratio := float(intact_parts) / float(total_parts)
	return int(BASE_CAR_VALUE * (0.4 + 0.6 * ratio))

## Quanto mais pecas quebradas (fumaca, capo caido etc.), mais dificil
## fica segurar a atencao do comprador durante a labia.
func damage_penalty(intact_parts: int, total_parts: int) -> float:
	if total_parts <= 0:
		return 0.0
	var broken := total_parts - intact_parts
	return broken * 0.12

# ------------------------------------------------------------------ clientes

## Tipos de cliente. Ate agora TODA venda era identica — 8 s, mesma taxa, e o
## preco so mudava pela avaria: o cliente trocava de rosto e mais nada. Com
## personalidade, a mesma carcaca vale coisas diferentes dependendo de quem
## aparece, e o jogador passa a ter uma decisao ("vale a pena consertar mais
## antes de entregar, ou esse ai engole qualquer coisa?").
##
## `paga`     multiplica o preco.
## `enche`    quanto a barra sobe por segundo segurando E.
## `esvazia`  quanto ela cai por segundo SEM segurar.
## `paciencia` tempo total, em segundos.
## `implica`  multiplica a penalidade por gambiarra quebrada.
##
## INVARIANTE, e o teste cobra: `enche * paciencia` > 1 em TODOS os tipos, ou
## seja segurando E sem soltar a venda sempre fecha. A dificuldade tem que vir
## de titubear e da avaria, nunca de um cliente impossivel — perder uma entrega
## depois de atravessar a cidade inteira por um sorteio ruim seria punicao sem
## aviso.
const CLIENTS: Array[Dictionary] = [
	{
		"nome": "Apressado", "dica": "tem pressa, paga pouco",
		"paga": 0.80, "enche": 0.75, "esvazia": 0.20, "paciencia": 4.0, "implica": 0.8,
	},
	{
		"nome": "Desconfiado", "dica": "repara em tudo",
		"paga": 1.15, "enche": 0.36, "esvazia": 0.30, "paciencia": 9.0, "implica": 1.8,
	},
	{
		"nome": "Entusiasmado", "dica": "topa fácil, mas se distrai",
		"paga": 1.25, "enche": 0.90, "esvazia": 0.45, "paciencia": 3.2, "implica": 1.0,
	},
	{
		"nome": "Pão-duro", "dica": "pechincha sem pressa",
		"paga": 0.70, "enche": 0.50, "esvazia": 0.10, "paciencia": 12.0, "implica": 0.6,
	},
	{
		"nome": "Colecionador", "dica": "paga bem por carro inteiro",
		"paga": 1.60, "enche": 0.30, "esvazia": 0.25, "paciencia": 9.0, "implica": 3.0,
	},
]

func random_client() -> Dictionary:
	return CLIENTS[randi() % CLIENTS.size()]

## Quanto ESTE cliente paga por um carro com tantas pecas inteiras.
func offer(client: Dictionary, intact_parts: int, total_parts: int) -> int:
	var base := estimate_sale_price(intact_parts, total_parts)
	return int(round(base * float(client.get("paga", 1.0))))
