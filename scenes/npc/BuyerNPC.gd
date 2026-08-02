extends StaticBody3D
## NPC comprador (StaticBody3D para ser detectado direto pelo raycast
## de interacao do jogador, sem precisar de um corpo filho separado). Fica parado numa area de entrega; quando o jogador
## encosta o carro (recem-montado) na CarZone e interage com o NPC,
## comeca o minigame de labia: segure E para "convencer" antes que o
## tempo acabe (gambiarras quebradas drenam a barra mais rapido).

signal sale_completed(amount: int)

@onready var car_zone: Area3D = $CarZone

var persuasion := PersuasionMinigame.new()
var nearby_vehicle: Node = null
var active_player: Node = null
var minigame_running := false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("buyer")
	car_zone.body_entered.connect(_on_car_entered)
	car_zone.body_exited.connect(_on_car_exited)
	persuasion.succeeded.connect(_on_success)
	persuasion.failed.connect(_on_failed)

func get_interact_prompt() -> String:
	if minigame_running:
		return "Segure [E] para convencer!"
	if nearby_vehicle == null:
		return "Traga um carro consertado ate aqui"
	return "Vender carro [E]"

func interact(player: Node) -> void:
	if nearby_vehicle == null or minigame_running:
		return
	active_player = player
	minigame_running = true
	persuasion.start(8.0)

func _process(delta: float) -> void:
	if not minigame_running:
		return
	var holding := Input.is_key_pressed(KEY_E)
	var penalty := 0.0
	if nearby_vehicle:
		var intact: int = nearby_vehicle.intact_part_count()
		var total: int = nearby_vehicle.total_attach_points()
		penalty = Economy.damage_penalty(intact, total)
	persuasion.update(delta, holding, penalty)
	GameManager.persuasion_updated.emit(true, persuasion.progress)

func _on_success() -> void:
	minigame_running = false
	var amount := 200
	if nearby_vehicle:
		amount = Economy.estimate_sale_price(nearby_vehicle.intact_part_count(), nearby_vehicle.total_attach_points())
	GameManager.register_sale(amount)
	GameManager.persuasion_updated.emit(false, 0.0)
	GameManager.clear_objective()
	sale_completed.emit(amount)
	if active_player and active_player.has_method("exit_vehicle"):
		active_player.exit_vehicle()
	if nearby_vehicle and is_instance_valid(nearby_vehicle):
		nearby_vehicle.queue_free()
	nearby_vehicle = null

func _on_failed() -> void:
	minigame_running = false
	GameManager.persuasion_updated.emit(false, 0.0)

func _on_car_entered(body: Node) -> void:
	if body.is_in_group("vehicle"):
		nearby_vehicle = body

func _on_car_exited(body: Node) -> void:
	if body == nearby_vehicle:
		nearby_vehicle = null
