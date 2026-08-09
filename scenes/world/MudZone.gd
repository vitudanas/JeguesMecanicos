extends Area3D
## Poca de lama: so afeta a tracao do carro quando esta chovendo (ver
## WeatherManager.is_raining). Mesma ideia de zona do scripts/Pothole.gd,
## mas em vez de aplicar impulso, avisa o Vehicle pra ele reduzir a
## propria tracao enquanto estiver dentro (ver Vehicle.gd:enter_mud()).

func _ready() -> void:
	add_to_group("poca")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("vehicle") and body.has_method("enter_mud"):
		body.enter_mud()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("vehicle") and body.has_method("exit_mud"):
		body.exit_mud()
