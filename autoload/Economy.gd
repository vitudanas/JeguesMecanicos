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
