class_name PersuasionMinigame
extends RefCounted
## Estado puro da negociacao com o comprador.
##
## A versao anterior era uma barra de "segure E": mantendo a tecla apertada, a
## venda sempre fechava pelo teto e nao havia uma decisao. Agora o cliente abre
## com uma contraproposta menor e o jogador escolhe entre:
##
##   * aceitar o dinheiro garantido;
##   * contrapropor, com ganho moderado e chance maior;
##   * blefar, com ganho grande e risco de a oferta cair.
##
## O sorteio fica no BuyerNPC, que conhece a personalidade, a reputacao e o
## estado do carro. Esta classe recebe apenas o resultado para que a aritmetica
## seja deterministica e testavel sem cena.

signal changed

## Uma contraproposta bem-sucedida fecha esta fracao do que ainda separa a
## oferta atual do teto. Tres acertos melhoram bastante o negocio, mas nao
## tornam o blefe inutil.
const COUNTER_GAIN := 0.38
## O blefe quase fecha o restante de uma vez.
const BLUFF_GAIN := 0.82
## Blefe descoberto faz o cliente retirar 10% do que ja tinha oferecido.
const BLUFF_LOSS := 0.10

var opening_offer := 0
var current_offer := 0
var ceiling := 0
var max_rounds := 0
var rounds_left := 0
var bluff_used := false
var is_active := false

func start(opening: int, maximum: int, rounds: int) -> void:
	ceiling = maxi(maximum, 1)
	opening_offer = clampi(opening, 1, ceiling)
	current_offer = opening_offer
	max_rounds = maxi(rounds, 1)
	rounds_left = max_rounds
	bluff_used = false
	is_active = true
	changed.emit()

func stop() -> void:
	is_active = false
	changed.emit()

func can_counter() -> bool:
	return is_active and rounds_left > 0 and current_offer < ceiling

func can_bluff() -> bool:
	return can_counter() and not bluff_used

## Aplica uma contraproposta. A rodada e gasta mesmo quando o cliente nao
## cede: e isso que torna "aceitar agora" uma opcao real.
func counter(succeeded: bool) -> int:
	if not can_counter():
		return current_offer
	rounds_left -= 1
	if succeeded:
		current_offer = _advance(COUNTER_GAIN)
	changed.emit()
	return current_offer

## Blefe falho custa duas rodadas (ou todas que restarem) e reduz a oferta. Um
## blefe bem-sucedido custa uma e salta quase todo o caminho ate o teto.
func bluff(succeeded: bool) -> int:
	if not can_bluff():
		return current_offer
	bluff_used = true
	if succeeded:
		rounds_left -= 1
		current_offer = _advance(BLUFF_GAIN)
	else:
		rounds_left = maxi(0, rounds_left - 2)
		current_offer = maxi(1, int(round(float(current_offer) * (1.0 - BLUFF_LOSS))))
	changed.emit()
	return current_offer

func progress() -> float:
	var span := ceiling - opening_offer
	if span <= 0:
		return 1.0
	return clampf(float(current_offer - opening_offer) / float(span), 0.0, 1.0)

func _advance(fraction: float) -> int:
	var gap := ceiling - current_offer
	if gap <= 0:
		return ceiling
	# Pelo menos R$ 1 quando ha espaco: arredondamento nao pode gastar uma
	# rodada sem mexer na oferta de carros baratos.
	return mini(ceiling, current_offer + maxi(1, int(round(float(gap) * fraction))))
