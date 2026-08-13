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

# -------------------------------------------------------------- valor do carro

## Valor base POR MODELO. Antes todo carro valia os mesmos R$ 220, entao qual
## carcaca o jogador rebocava dava no mesmo — nao havia o que escolher. Com
## valor por modelo, achar um esportivo no ferro-velho passa a ser sorte grande.
const MODEL_VALUES := {
	"car-a": 260, "car-b": 240,
	"sports-car-a": 430, "sports-car-b": 410,
	"suv": 340, "taxi": 210,
}
const DEFAULT_MODEL_VALUE := 250

## Quilometragem de uma carcaca, em milhares de km.
const KM_MIN := 60.0
const KM_MAX := 340.0
## Quanto o carro mais rodado do lote perde de valor.
const KM_WORST := 0.55

## Quanto lataria e pintura pesam no valor (0 = impecavel, 1 = detonado).
const BODY_WEIGHT := 0.30
const PAINT_WEIGHT := 0.12

## Sorteia o estado de uma carcaca. Chamado uma vez, quando o carro nasce.
func roll_condition(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"km": rng.randf_range(KM_MIN, KM_MAX),
		"lataria": rng.randf(),
		"pintura": rng.randf(),
	}

func model_value(model_key: String) -> int:
	return int(MODEL_VALUES.get(model_key, DEFAULT_MODEL_VALUE))

## Quanto o carro vale DEPOIS de consertado, considerando quilometragem,
## lataria e pintura — que sao permanentes. E o teto do negocio.
func repaired_value(model_key: String, condition: Dictionary) -> int:
	var base := float(model_value(model_key))
	var km: float = float(condition.get("km", KM_MIN))
	var km_mult: float = lerpf(1.0, KM_WORST,
		clampf((km - KM_MIN) / maxf(KM_MAX - KM_MIN, 1.0), 0.0, 1.0))
	var body_mult := 1.0 - BODY_WEIGHT * float(condition.get("lataria", 0.0))
	var paint_mult := 1.0 - PAINT_WEIGHT * float(condition.get("pintura", 0.0))
	return int(round(base * km_mult * body_mult * paint_mult))

## Valor de mercado AGORA: o valor de consertado descontando as gambiarras que
## faltam ou quebraram.
func market_value(model_key: String, condition: Dictionary,
		intact_parts: int, total_parts: int, parts: Dictionary = {},
		gambiarras: Dictionary = {}) -> int:
	var full := float(repaired_value(model_key, condition))
	# Peca mecanica quebrada derruba o valor junto com a gambiarra faltando: sao
	# dois eixos independentes de "carro ruim".
	full *= (1.0 - parts_penalty(parts))
	# E a QUALIDADE da gambiarra e um terceiro: papelao no parachoque nao vale o
	# mesmo que chapa de compensado, mesmo os dois estando no lugar.
	full *= (1.0 - gambiarra_penalty(gambiarras))
	if total_parts <= 0:
		return int(round(full))
	var ratio := float(intact_parts) / float(total_parts)
	return int(round(full * (0.4 + 0.6 * ratio)))

# ------------------------------------------------------------ pecas mecanicas

## Peças de verdade, cada uma com um defeito possivel escondido na carcaca.
##
## E o que separa "carro velho" de "carro velho COM PROBLEMA": ate agora o
## estado era so cosmetico (km, lataria, pintura) e nada do que estava quebrado
## se fazia sentir. Aqui cada peca pesa no valor E no comportamento do carro —
## motor ruim tira forca, freio ruim aumenta a distancia de parada, suspensao
## ruim faz o carro pular, pneu careca tira aderencia.
##
## `peso`  quanto do valor o carro perde com esta peca quebrada.
## `custo` preco da peca como FRACAO do valor que ela devolve.
##
## O custo e proporcional ao carro, nao um numero fixo. Com preco absoluto o
## sistema nasceu inutil: consertar tudo custava R$ 400 e devolvia R$ 148 de
## valor num carro de R$ 206 — ou seja, NUNCA compensava, e o diagnostico seria
## enfeite. Proporcional, um pneu de esportivo custa mais que um pneu de taxi,
## como na vida.
##
## E o `custo` varia de peca pra peca DE PROPOSITO: abaixo de 1.0 o conserto se
## paga, acima de 1.0 e prejuizo. E isso que cria a decisao — bateria sempre
## vale, motor quase nunca, e o meio-termo e onde o jogador pensa. Se todo
## conserto fosse lucro, nao haveria escolha nenhuma.
const PARTS := {
	"motor": {"nome": "Motor", "peso": 0.26, "custo": 1.05, "gambiarra": false},
	"freio": {"nome": "Freio", "peso": 0.13, "custo": 0.60, "gambiarra": true},
	"suspensao": {"nome": "Suspensão", "peso": 0.11, "custo": 0.75, "gambiarra": true},
	"pneus": {"nome": "Pneus", "peso": 0.10, "custo": 0.65, "gambiarra": false},
	"bateria": {"nome": "Bateria", "peso": 0.05, "custo": 0.40, "gambiarra": true},
	"escapamento": {"nome": "Escapamento", "peso": 0.07, "custo": 0.90, "gambiarra": true},
}

## Abaixo disto a peca conta como QUEBRADA.
const PART_BROKEN_BELOW := 0.38
## Chance de cada peca nascer com defeito numa carcaca de ferro-velho.
const PART_FAIL_CHANCE := 0.42

## Sorteia o estado das pecas de uma carcaca.
func roll_parts(rng: RandomNumberGenerator) -> Dictionary:
	var out: Dictionary = {}
	for key: String in PARTS:
		# Ou a peca esta boa (0.6-1.0) ou tem defeito de verdade (0.0-0.37).
		out[key] = rng.randf_range(0.0, PART_BROKEN_BELOW - 0.01) \
			if rng.randf() < PART_FAIL_CHANCE else rng.randf_range(0.6, 1.0)
	return out

func part_broken(parts: Dictionary, key: String) -> bool:
	return float(parts.get(key, 1.0)) < PART_BROKEN_BELOW

func broken_parts(parts: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: String in PARTS:
		if part_broken(parts, key):
			out.append(key)
	return out

## Quanto o carro perde de valor pelas pecas quebradas (0 = tudo em ordem).
func parts_penalty(parts: Dictionary) -> float:
	var perda := 0.0
	for key: String in broken_parts(parts):
		perda += float(PARTS[key]["peso"])
	return minf(perda, 0.75)

## Preco da peca para um carro que vale `full` consertado.
func part_price(key: String, full: int) -> int:
	var info: Dictionary = PARTS[key]
	return maxi(10, int(round(float(full) * float(info["peso"]) * float(info["custo"]))))

## Quanto custa deixar tudo em ordem — o que o jogador precisa saber pra decidir
## se o negocio vale a pena.
func repair_cost(parts: Dictionary, full: int) -> int:
	var total := 0
	for key: String in broken_parts(parts):
		total += part_price(key, full)
	return total

# ------------------------------------------------------------- gambiarras

## O CATALOGO DE GAMBIARRA: o que da pra enfiar em cada ponto do carro.
##
## Ate agora cada ponto tinha UMA peca fixa e de graca: montar era apertar E
## quatro vezes, sempre igual — a premissa do jogo era o unico sistema dele sem
## nenhuma decisao. Agora cada ponto tem tres graus, e a escolha e um triangulo
## honesto:
##
##   1 barata      → quase de graca, cai no primeiro buraco, o cliente repara;
##   2 media       → a peca que o jogo sempre teve;
##   3 caprichada  → aguenta o test-drive e o cliente quase nao desconta, mas
##                   come um pedaco do lucro ANTES de você saber se vai vender.
##
## OS NUMEROS SAO OS MESMOS NOS QUATRO PONTOS, de proposito: o que muda de um
## ponto pro outro e o OBJETO (a piada e a leitura na tela), nao a planilha.
## Isso deixa a regra provavel — e ela foi RESOLVIDA, nao chutada.
##
## Escrevendo lucro = valor − custo, com o valor caindo tanto pelo desconto
## quanto pela gambiarra que se soltou, existe uma faixa em que cada grau ganha
## em algum cenario. Fora dela um grau vira imposto: a primeira calibragem que
## escrevi no olho punha o grau 3 a 52% do valor do carro, e ele **perdia nos
## tres cenarios** — o teste pegou. Estes valores saem de uma busca pela maior
## margem util (ver `economy_test`, secao da gambiarra):
##
##   viagem calma  (nada cai)      → ganha a BARATA
##   viagem normal (a barata cai)  → ganha a MEDIA
##   viagem feia   (media tambem)  → ganha a CAPRICHADA
##
## `custo` e `desconto` sao FRACOES do valor do carro, nunca reais fixos: mesma
## licao das pecas mecanicas (2026-08-09) — preco absoluto num jogo onde o carro
## vale R$ 150-430 faz o item nunca compensar.
const G_CUSTO: Array[float] = [0.010, 0.050, 0.105]
const G_DESCONTO: Array[float] = [0.045, 0.030, 0.008]
## Multiplica o limiar de estresse da peca (`break_threshold`, 7.0). Contra o
## buraco da rua (`Pothole.impact_force` 8.0, escalado 0.3-3.0 pela velocidade):
## a barata cai ate devagar, a media passa no devagar e cai no rapido, a
## caprichada aguenta o rapido.
const G_AGUENTA: Array[float] = [0.40, 1.0, 2.1]
const GRAUS := 3

## Por ponto, o objeto de cada grau. `kind` e o visual que o GambiarraVisual
## monta (a ordem do enum dele).
const GAMBIARRAS := {
	"hood": [
		{"id": "arame", "nome": "Arame de cabide", "kind": 4},
		{"id": "dobradica", "nome": "Dobradiça de porta", "kind": 0},
		{"id": "cinta", "nome": "Cinta de amarração", "kind": 5},
	],
	"radiator": [
		{"id": "chiclete", "nome": "Chiclete e fita", "kind": 6},
		{"id": "mangueira", "nome": "Mangueira de pia", "kind": 1},
		{"id": "mangueira_pesada", "nome": "Mangueira de máq. de lavar", "kind": 7},
	],
	"mirror": [
		{"id": "fita", "nome": "Fita isolante", "kind": 2},
		{"id": "abracadeira", "nome": "Abraçadeira de nylon", "kind": 8},
		{"id": "suporte", "nome": "Espelho de bicicleta", "kind": 9},
	],
	"bumper": [
		{"id": "papelao", "nome": "Papelão e barbante", "kind": 10},
		{"id": "lona", "nome": "Lona plástica", "kind": 3},
		{"id": "compensado", "nome": "Chapa de compensado", "kind": 11},
	],
}
## Grau que vem selecionado quando o jogador chega no ponto: o do meio, que e a
## peca que o jogo sempre teve. Quem nao quiser escolher nada joga como antes.
const GAMBIARRA_DEFAULT := 1

func gambiarra_options(point: String) -> Array:
	return GAMBIARRAS.get(point, []) as Array

## A opcao ja com os numeros do grau dentro — quem chama nao precisa saber que
## eles moram numa tabela separada.
func gambiarra_option(point: String, index: int) -> Dictionary:
	var lista := gambiarra_options(point)
	if lista.is_empty():
		return {}
	var grau := posmod(index, lista.size())
	var out: Dictionary = (lista[grau] as Dictionary).duplicate()
	out["grau"] = grau
	out["custo"] = G_CUSTO[grau]
	out["aguenta"] = G_AGUENTA[grau]
	out["desconto"] = G_DESCONTO[grau]
	return out

## Quanto esta gambiarra custa num carro que vale `full` consertado.
func gambiarra_price(option: Dictionary, full: int) -> int:
	if option.is_empty():
		return 0
	return maxi(2, int(round(float(full) * float(option["custo"]))))

## Quanto o cliente corta do valor por causa das gambiarras INSTALADAS.
##
## So conta o que esta la: gambiarra que caiu no caminho ja e cobrada pelo termo
## de peca faltando (ver market_value), e cobrar duas vezes faria carro detonado
## valer quase nada e a entrega deixar de compensar.
func gambiarra_penalty(installed: Dictionary) -> float:
	var perda := 0.0
	for point: String in installed:
		var opt: Dictionary = installed[point]
		perda += float(opt.get("desconto", 0.0))
	return minf(perda, 0.45)

## Rotulo curto de resistencia, pro jogador decidir sem ler numero.
func gambiarra_grade(option: Dictionary) -> String:
	var a := float(option.get("aguenta", 1.0))
	if a < 0.7:
		return "cai fácil"
	if a < 1.6:
		return "aguenta"
	return "aguenta bem"

# ------------------------------------------------------- comprar a carcaca

## Quanto o dono do ferro-velho pede pela carcaca, como fracao do que ela vai
## valer consertada. A FAIXA E LARGA de proposito: e ela que faz existir
## barganha e roubada no mesmo lote, que e a graca de garimpar. Sem vistoriar, o
## jogador so ve o preco — e nao sabe de que lado do negocio esta.
const ASK_MIN := 0.32
const ASK_MAX := 0.72
## Abaixo disto o dono nao desce, por mais que se pechinche.
const FLOOR_OF_ASK := 0.68
## Quanto cada pechincha bem-sucedida corta do preco pedido.
const HAGGLE_STEP := 0.09
## Tentativas antes de o dono se fechar.
const HAGGLE_TRIES := 3
## Chance de a pechincha dar errado e o dono travar o preco na hora.
const HAGGLE_RISK := 0.25

func wreck_asking_price(model_key: String, condition: Dictionary,
		rng: RandomNumberGenerator) -> int:
	var full := float(repaired_value(model_key, condition))
	return int(round(full * rng.randf_range(ASK_MIN, ASK_MAX)))

## Menor preco que este dono aceita.
func haggle_floor(asking: int) -> int:
	return int(round(float(asking) * FLOOR_OF_ASK))

# ------------------------------------------------------------------ clientes

## Tipos de cliente. Ate agora TODA venda era identica — 8 s, mesma taxa, e o
## preco so mudava pela avaria: o cliente trocava de rosto e mais nada. Com
## personalidade, a mesma carcaca vale coisas diferentes dependendo de quem
## aparece, e o jogador passa a ter uma decisao ("vale a pena consertar mais
## antes de entregar, ou esse ai engole qualquer coisa?").
##
## `paga`    multiplica o preco maximo.
## `abre`    fracao desse teto oferecida no inicio da conversa.
## `cede`    chance-base de aceitar uma contraproposta segura.
## `blefe`   chance-base de cair num blefe, sempre menor que `cede`.
## `rodadas` quantas tentativas o jogador tem antes da oferta virar final.
## `implica` multiplica a penalidade de chance por gambiarra quebrada.
##
## A oferta inicial nunca e zero e pode ser aceita imediatamente. Assim nenhum
## cliente e impossivel por sorte: o risco existe apenas quando o jogador
## escolhe pedir mais, e as probabilidades aparecem no prompt antes da acao.
const CLIENTS: Array[Dictionary] = [
	{
		"nome": "Apressado", "dica": "tem pressa, paga pouco",
		"paga": 0.80, "abre": 0.78, "cede": 0.72, "blefe": 0.42,
		"rodadas": 2, "implica": 0.8,
	},
	{
		"nome": "Desconfiado", "dica": "repara em tudo",
		"paga": 1.15, "abre": 0.70, "cede": 0.58, "blefe": 0.22,
		"rodadas": 3, "implica": 1.8,
	},
	{
		"nome": "Entusiasmado", "dica": "topa fácil, mas se distrai",
		"paga": 1.25, "abre": 0.86, "cede": 0.83, "blefe": 0.62,
		"rodadas": 2, "implica": 1.0,
	},
	{
		"nome": "Pão-duro", "dica": "pechincha sem pressa",
		"paga": 0.70, "abre": 0.62, "cede": 0.45, "blefe": 0.18,
		"rodadas": 4, "implica": 0.6,
	},
	{
		"nome": "Colecionador", "dica": "paga bem por carro inteiro",
		"paga": 1.60, "abre": 0.74, "cede": 0.64, "blefe": 0.30,
		"rodadas": 3, "implica": 3.0,
	},
	# O LOWBALLER das duas inspiracoes: oferece bem abaixo do valor e nao se
	# mexe. Existe pra que anunciar caro nem sempre seja a jogada — com ele na
	# porta, o jogador escolhe entre aceitar pouco ou esperar outro cliente.
	{
		"nome": "Abutre", "dica": "oferece uma miséria e não sobe",
		"paga": 0.62, "abre": 0.55, "cede": 0.25, "blefe": 0.08,
		"rodadas": 4, "implica": 0.5,
	},
]

## Reputação mexe na oferta: 0 tira 18%, 100 acrescenta 18%.
const REPUTATION_SWING := 0.18

func reputation_bonus() -> float:
	return 1.0 + REPUTATION_SWING * ((float(GameManager.reputation) / 50.0) - 1.0)

## Quanto a reputação cai por entregar um carro com defeito ESCONDIDO. Peso da
## peça vira ponto de reputação — esconder um motor quebrado dói mais que uma
## bateria.
func reputation_hit(parts: Dictionary) -> int:
	return int(round(parts_penalty(parts) * 40.0))

func random_client() -> Dictionary:
	return CLIENTS[randi() % CLIENTS.size()]

## Quanto ESTE cliente paga por um carro que vale `market` no mercado.
func offer(client: Dictionary, market: int) -> int:
	return int(round(float(market) * float(client.get("paga", 1.0))))
