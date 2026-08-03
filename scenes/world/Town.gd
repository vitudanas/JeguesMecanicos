extends Node3D
## Define o objetivo inicial (bussola do HUD aponta pro ferro-velho).

@onready var junkyard_car: Node3D = $Junkyard/WreckedCar

func _ready() -> void:
	GameManager.set_objective(junkyard_car.global_position, "Ache o carro no FERRO-VELHO (placa laranja)")
	_register_event_spawn_points()
	# Neste ponto CityBlocks ja rodou o proprio _ready() (filhos antes do pai),
	# entao as casas ja estao no grupo "delivery_house" e da pra sortear a
	# primeira entrega.
	DeliveryManager.start(self)

## Marker3D chamados "EventSpawnPoint*" viram pontos possiveis pro
## EventManager.gd spawnar ferros-velhos extra pelo mapa.
func _register_event_spawn_points() -> void:
	for child in get_children():
		if child is Marker3D and child.name.begins_with("EventSpawnPoint"):
			child.add_to_group("event_spawn_point")
