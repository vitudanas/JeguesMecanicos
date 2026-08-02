extends Area3D
## Buraco na rua: quando um veiculo passa rapido por cima, aplica um
## impulso e estressa as gambiarras instaladas. Ver Vehicle.gd:hit_pothole().

@export var impact_force := 8.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.has_method("hit_pothole"):
		var speed: float = body.linear_velocity.length() if body is RigidBody3D else 0.0
		var scaled_force: float = impact_force * clamp(speed / 6.0, 0.3, 3.0)
		body.hit_pothole(scaled_force)
