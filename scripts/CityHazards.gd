extends Node3D
## Espalha BURACOS e POÇAS de lama pela malha viária.
##
## Eram 4 pares fixos, escritos à mão no `Town.tscn` — anotado nas "limitações
## conhecidas" desde o começo. Numa cidade de 225 m dava pra defender; numa de
## 525 m, quatro buracos somem no mapa e o "test-drive caótico", que é um dos
## pilares do jogo, vira uma viagem tranquila.
##
## Cada buraco nasce SOBRE uma rua de verdade: um dos eixos é o de uma rua da
## grade e o outro é sorteado ao longo dela. Assim ele cabe na pista por
## construção, sem precisar conferir depois.

@export var streets_x: Array[float] = []
@export var streets_z: Array[float] = []
@export var pothole_scene: PackedScene
@export var mud_scene: PackedScene
@export var count := 26
## Quantos dos buracos ganham uma poça por perto. Poça só atrapalha quando
## chove (ver Vehicle._current_traction), então nem todo buraco precisa de uma.
@export var mud_ratio := 0.55
## O buraco fica na mão de direção; a poça, não (ver `_place`).
@export var lane_offset := 1.5
## Não nasce em cima de cruzamento: buraco no meio do cruzamento pega o jogador
## quando ele já está manobrando.
@export var crossing_clearance := 9.0
@export var rng_seed := 20260809

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = rng_seed
	if streets_x.is_empty() or streets_z.is_empty() or pothole_scene == null:
		push_warning("CityHazards: falta grade ou cena de buraco")
		return
	var mud_alvo := int(round(float(count) * mud_ratio))
	var feitos := 0
	for i in range(count):
		var s := _spot()
		if s.is_empty():
			continue
		var eixo: Vector3 = s["eixo"]
		var lado: Vector3 = s["lado"]
		var buraco := pothole_scene.instantiate()
		add_child(buraco)
		(buraco as Node3D).global_position = eixo + lado * lane_offset + Vector3(0, -0.1, 0)
		if feitos < mud_alvo and mud_scene:
			# A POÇA FICA NO EIXO DA RUA, e não na mão como o buraco: ela tem
			# raio 2.5 contra 3.0 de meia-pista, então qualquer deslocamento
			# lateral joga a borda dela por cima do meio-fio. Foi assim que as
			# 35 primeiras reprovaram, todas pelo mesmo motivo.
			var poca := mud_scene.instantiate()
			add_child(poca)
			(poca as Node3D).global_position = eixo
		feitos += 1

## Um ponto sobre o eixo de uma rua, longe de cruzamento, mais a direção
## perpendicular à rua (pra quem quiser sair do eixo sem sair do asfalto).
func _spot() -> Dictionary:
	for tentativa in range(24):
		var horizontal := _rng.randf() < 0.5
		var eixos: Array[float] = streets_z if horizontal else streets_x
		var outros: Array[float] = streets_x if horizontal else streets_z
		var eixo: float = eixos[_rng.randi_range(0, eixos.size() - 1)]
		var ao_longo: float = _rng.randf_range(outros[0], outros[outros.size() - 1])
		var perto := false
		for c: float in outros:
			if absf(ao_longo - c) < crossing_clearance:
				perto = true
				break
		if perto:
			continue
		var sinal: float = 1.0 if _rng.randf() < 0.5 else -1.0
		if horizontal:
			return {"eixo": Vector3(ao_longo, 0.0, eixo),
				"lado": Vector3(0.0, 0.0, sinal)}
		return {"eixo": Vector3(eixo, 0.0, ao_longo),
			"lado": Vector3(sinal, 0.0, 0.0)}
	return {}
