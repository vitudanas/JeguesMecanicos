extends Node3D
## Define o objetivo inicial (bussola do HUD aponta pro ferro-velho).

@onready var junkyard_car: Node3D = $Junkyard/WreckedCar

func _ready() -> void:
	GameManager.set_objective(junkyard_car.global_position, "Ache o carro no FERRO-VELHO (placa laranja)")
