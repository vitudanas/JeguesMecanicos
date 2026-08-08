extends Node
## Estado global do jogo: dinheiro do jogador, progresso e sinais de UI.
## Autoload (singleton) — registrado em project.godot [autoload].

signal money_changed(new_amount: int)
signal car_sold(amount: int)
signal persuasion_updated(active: bool, progress: float)
signal objective_changed(position: Vector3, label: String)

var money: int = 150
var cars_sold: int = 0

## Guardados (nao so emitidos) porque o HUD pode terminar seu _ready() e
## conectar no sinal DEPOIS que o objetivo inicial ja foi definido por
## Town.gd — sem isso a bussola nunca aparece na primeira vez.
var objective_position: Vector3 = Vector3.ZERO
var objective_label: String = ""

## Volta pros valores de inicio de partida. Necessario porque os autoloads
## SOBREVIVEM a troca de cena: sem isto, sair pro menu e escolher "Novo jogo"
## continuaria com o dinheiro da partida anterior.
func reset() -> void:
	money = 150
	cars_sold = 0
	objective_position = Vector3.ZERO
	objective_label = ""
	money_changed.emit(money)

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

func register_sale(amount: int) -> void:
	cars_sold += 1
	add_money(amount)
	car_sold.emit(amount)

## Atualiza o objetivo atual (usado pela bussola do HUD). label vazio esconde a bussola.
func set_objective(position: Vector3, label: String) -> void:
	objective_position = position
	objective_label = label
	objective_changed.emit(position, label)

func clear_objective() -> void:
	set_objective(Vector3.ZERO, "")
