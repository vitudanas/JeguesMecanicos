extends Node
## A LOJA: as áreas do terreno e os níveis de cada uma.
##
## Inspirado na estrutura do Car Dealer Simulator (ver "Referência de design" no
## CLAUDE.md), onde nao existe um upgrade so de oficina: cada area do terreno
## sobe de nivel por conta propria, e o ultimo nivel de cada uma e o que libera
## contratar alguem pra tocar aquela estacao.
##
## Por que isso importa aqui: ate agora o lucro nao tinha ONDE ser gasto. Vender
## caro era um numero subindo na tela. Com as areas, cada venda vira "falta
## pouco pro elevador", que e o que faz o jogador querer a proxima carcaca.

signal changed

## `niveis` descreve cada degrau: o que ele custa e o que destrava.
##
## A oficina destrava POR PECA, e a ordem nao e arbitraria — segue a do jogo de
## referencia: comeca no que se troca na mao (bateria, escapamento), passa pelo
## que exige elevador (freio, suspensao, pneus) e termina no motor.
const AREAS := {
	"oficina": {
		"nome": "Oficina mecânica",
		"descricao": "conserta peça de verdade",
		"niveis": [
			{"custo": 0, "libera": ["bateria", "escapamento"],
				"texto": "bateria e escapamento (na mão)"},
			{"custo": 900, "libera": ["freio", "suspensao", "pneus"],
				"texto": "elevador: freio, suspensão e pneus"},
			{"custo": 2400, "libera": ["motor"],
				"texto": "bancada de motor"},
		],
	},
	"funilaria": {
		"nome": "Funilaria",
		"descricao": "recupera lataria e pintura",
		"niveis": [
			{"custo": 0, "libera": [], "texto": "nada — só gambiarra"},
			{"custo": 700, "libera": ["lataria"], "texto": "martelinho: tira amassado"},
			{"custo": 1800, "libera": ["pintura"], "texto": "cabine de pintura"},
		],
	},
	"patio": {
		"nome": "Pátio",
		"descricao": "quantos carros cabem ao mesmo tempo",
		"niveis": [
			{"custo": 0, "libera": [], "texto": "1 carro por vez"},
			{"custo": 1100, "libera": [], "texto": "2 carros por vez"},
			{"custo": 2600, "libera": [], "texto": "4 carros por vez"},
		],
	},
	"escritorio": {
		"nome": "Escritório",
		"descricao": "clientes melhores e mais entregas",
		"niveis": [
			{"custo": 0, "libera": [], "texto": "boca a boca"},
			{"custo": 800, "libera": ["anuncio"], "texto": "anúncio: clientes pagam mais"},
			{"custo": 2200, "libera": ["recepcao"], "texto": "recepção: fila de clientes"},
		],
	},
}
## Ordem fixa pra percorrer no quadro de upgrades (Dictionary nao garante ordem
## estavel entre versoes do Godot).
const ORDER: Array[String] = ["oficina", "funilaria", "patio", "escritorio"]

## Vagas no patio por nivel, e quanto o escritorio melhora a oferta do cliente.
const YARD_SLOTS := [1, 2, 4]
const OFFICE_BONUS := [1.0, 1.10, 1.18]

## Nivel atual de cada area (indice em `niveis`).
var levels: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset()

func reset() -> void:
	levels = {}
	for key: String in ORDER:
		levels[key] = 0
	changed.emit()

func level(area: String) -> int:
	return int(levels.get(area, 0))

func max_level(area: String) -> int:
	return (AREAS[area]["niveis"] as Array).size() - 1

func at_max(area: String) -> bool:
	return level(area) >= max_level(area)

## Custo do PROXIMO nivel, ou -1 se ja esta no teto.
func next_cost(area: String) -> int:
	if at_max(area):
		return -1
	return int(AREAS[area]["niveis"][level(area) + 1]["custo"])

func next_text(area: String) -> String:
	if at_max(area):
		return "no máximo"
	return str(AREAS[area]["niveis"][level(area) + 1]["texto"])

func current_text(area: String) -> String:
	return str(AREAS[area]["niveis"][level(area)]["texto"])

## Tudo que a area ja destravou, somando os niveis ate o atual — um upgrade nao
## substitui o anterior, ele acrescenta.
func unlocked(area: String) -> Array:
	var out: Array = []
	for i in range(level(area) + 1):
		out.append_array(AREAS[area]["niveis"][i]["libera"] as Array)
	return out

## A oficina consegue trocar esta peca?
func can_repair(part_key: String) -> bool:
	return part_key in unlocked("oficina")

func yard_slots() -> int:
	return YARD_SLOTS[mini(level("patio"), YARD_SLOTS.size() - 1)]

func office_bonus() -> float:
	return OFFICE_BONUS[mini(level("escritorio"), OFFICE_BONUS.size() - 1)]

## Compra o proximo nivel. Devolve o que aconteceu, pro chamador poder avisar na
## tela sem repetir a regra.
func buy(area: String) -> String:
	if not AREAS.has(area):
		return "área desconhecida"
	if at_max(area):
		return "já está no máximo"
	var custo := next_cost(area)
	if GameManager.money < custo:
		return "faltam R$ %d" % (custo - GameManager.money)
	GameManager.add_money(-custo)
	levels[area] = level(area) + 1
	changed.emit()
	return ""

# ------------------------------------------------------------------ disco

func to_dict() -> Dictionary:
	return levels.duplicate()

func from_dict(data: Dictionary) -> void:
	reset()
	for key: String in ORDER:
		if data.has(key):
			levels[key] = clampi(int(data[key]), 0, max_level(key))
	changed.emit()
