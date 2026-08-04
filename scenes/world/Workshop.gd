extends Node3D
## Oficina: quando o jogador arrasta o carro sucateado ate a DropZone,
## o reboque e liberado automaticamente e o carro fica parado ali para
## o jogador instalar as gambiarras nos pontos de fixacao (AttachSpot).

@onready var drop_zone: Area3D = $DropZone

func _ready() -> void:
	add_to_group("workshop")
	drop_zone.body_entered.connect(_on_body_entered)
	drop_zone.body_exited.connect(_on_body_exited)

## Centro da Area3D, que fica ACIMA do chao (a caixa tem 3 m de altura). Serve
## pra bussola/objetivo; quem precisa do piso deve medir o chao, nao usar isso.
func get_drop_position() -> Vector3:
	return drop_zone.global_position

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("vehicle"):
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("stop_towing"):
			player.stop_towing()
		body.at_workshop = true
		GameManager.set_objective(body.global_position, "Monte as 4 gambiarras no carro (capo, radiador, retrovisor, parachoque)")

func _on_body_exited(body: Node) -> void:
	# Saiu do patio (empurrado, ou ja consertado e saindo dirigindo): volta a
	# poder ser rebocado, senao um carro que escapou ficaria preso pra sempre.
	if body.is_in_group("vehicle"):
		body.at_workshop = false
