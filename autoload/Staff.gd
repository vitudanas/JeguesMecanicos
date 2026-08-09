extends Node
## FUNCIONARIOS: quem o jogador contrata pra tocar uma estacao no lugar dele.
## Autoload (singleton) — registrado em project.godot [autoload].
##
## Regra vinda do Car Dealer Simulator (ver "Referencia de design" no
## CLAUDE.md): contratar so abre no ULTIMO nivel da area, e cada funcionario e
## designado a uma estacao. Isso importa pro ritmo do jogo — o funcionario nao
## e um atalho que se compra cedo, e o que a area vira depois de paga inteira.
##
## Por que funcionario e a peca que faltava: o loop e serial. Rebocar, montar,
## dirigir, vender, e so entao voltar pro ferro-velho. Com o mecanico, o carro
## parado no patio avanca ENQUANTO o jogador esta fora — que e exatamente o que
## o patio de varias vagas passou a permitir. Uma coisa nao vale sem a outra.

signal changed

const ROLES := {
	"mecanico": {
		"nome": "Mecânico",
		"area": "oficina",
		"custo": 1600,
		"texto": "conserta as peças sozinho enquanto você garimpa",
	},
	"recepcionista": {
		"nome": "Recepcionista",
		"area": "escritorio",
		"custo": 1400,
		"texto": "mantém dois clientes esperando — dá pra escolher",
	},
}
const ORDER: Array[String] = ["mecanico", "recepcionista"]

## Quanto o mecanico cobra a mais que a peca. Ele NAO trabalha de graca: sem
## isso, contratar seria puro lucro e a escolha de consertar na mao (mais
## barato) x deixar com ele (mais caro, mas nao custa seu tempo) nao existiria.
const LABOR_MARKUP := 0.30
## Quanto ele leva por peca. Longo de proposito: se fosse instantaneo, o
## jogador ficaria parado olhando em vez de sair pra proxima carcaca.
const SECONDS_PER_PART := 22.0
## Diagnostico e mais rapido que troca — e so olhar o carro.
const SECONDS_TO_DIAGNOSE := 8.0

var hired: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset()

func reset() -> void:
	hired = {}
	for key: String in ORDER:
		hired[key] = false
	changed.emit()

func has(role: String) -> bool:
	return bool(hired.get(role, false))

## A vaga so abre quando a area esta no teto.
func can_hire(role: String) -> bool:
	if not ROLES.has(role) or has(role):
		return false
	return Dealership.at_max(str(ROLES[role]["area"]))

## Qual funcionario esta em oferta nesta area (vazio = nenhum).
func role_for_area(area: String) -> String:
	for key: String in ORDER:
		if str(ROLES[key]["area"]) == area:
			return key
	return ""

func cost(role: String) -> int:
	return int(ROLES[role]["custo"]) if ROLES.has(role) else 0

## Contrata. Devolve o motivo da recusa, ou "" se deu certo — mesmo contrato do
## `Dealership.buy()`, pra o quadro poder avisar sem repetir a regra.
func hire(role: String) -> String:
	if not ROLES.has(role):
		return "vaga desconhecida"
	if has(role):
		return "já contratado"
	if not Dealership.at_max(str(ROLES[role]["area"])):
		return "só no último nível da área"
	var custo := cost(role)
	if GameManager.money < custo:
		return "faltam R$ %d" % (custo - GameManager.money)
	GameManager.add_money(-custo)
	hired[role] = true
	changed.emit()
	return ""

# ------------------------------------------------------------------ disco

func to_dict() -> Dictionary:
	return hired.duplicate()

func from_dict(data: Dictionary) -> void:
	reset()
	for key: String in ORDER:
		hired[key] = bool(data.get(key, false))
	changed.emit()
