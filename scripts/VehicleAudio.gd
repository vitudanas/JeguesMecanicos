class_name VehicleAudio
extends Node3D
## Som do carro do jogador: motor continuo + batidas.
##
## O motor e o laco sintetizado por `ProceduralAudio` (nao existe pacote CC0 de
## motor — ver o comentario de la), e a rotacao sai de `pitch_scale`. Isso so
## funciona bem porque o laco e sintetico: uma gravacao esticada pra mais de 2x
## soaria picotada.
##
## **So o carro DIRIGIDO faz barulho de motor.** Os ~42 carros de IA da cidade
## teriam custado um tocador cada, e uma carcaca no ferro-velho ficaria
## roncando parada, que e pior que o silencio.

## Rotacao de marcha lenta e de giro maximo, como multiplicador do laco base.
const IDLE_PITCH := 0.62
const MAX_PITCH := 2.35
## Velocidade (m/s) em que o motor chega no giro maximo.
const TOP_SPEED := 22.0
## Quanto o pedal levanta o giro parado — e o que da o "vrum" na embreagem.
const THROTTLE_LIFT := 0.45
## Sobe rapido e desce devagar, como motor de verdade.
const RISE := 7.0
const FALL := 2.6

const IDLE_DB := -16.0
const LOUD_DB := -4.0

## Abaixo disto a batida nao vira som: o carro encosta no meio-fio o tempo todo.
const IMPACT_MIN := 2.5
const IMPACT_HEAVY := 9.0
## Duas batidas coladas sao a MESMA batida pro ouvido — sem isto, raspar num
## muro vira uma metralhadora de lataria.
const IMPACT_COOLDOWN := 0.12

var _engine: AudioStreamPlayer3D = null
var _vehicle: RigidBody3D = null
var _pitch := IDLE_PITCH
var _since_impact := 0.0

func _ready() -> void:
	_vehicle = get_parent() as RigidBody3D
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = AudioManager.engine_stream()
	_engine.bus = AudioManager.BUS_SFX
	_engine.max_distance = 70.0
	_engine.unit_size = 6.0
	_engine.volume_db = IDLE_DB
	_engine.pitch_scale = IDLE_PITCH
	add_child(_engine)

func _process(delta: float) -> void:
	_since_impact += delta
	if _vehicle == null:
		return
	var driving: bool = _vehicle.driver != null
	if driving and not _engine.playing:
		_engine.play()
	elif not driving and _engine.playing:
		_engine.stop()
	if not driving:
		return

	var speed: float = absf(_vehicle.forward_speed())
	var load: float = clampf(speed / TOP_SPEED, 0.0, 1.0)
	var gas: float = absf(_vehicle.throttle_input)
	var wanted: float = IDLE_PITCH + (MAX_PITCH - IDLE_PITCH) * load + THROTTLE_LIFT * gas
	wanted = minf(wanted, MAX_PITCH + THROTTLE_LIFT)
	_pitch = lerpf(_pitch, wanted, clampf(delta * (RISE if wanted > _pitch else FALL), 0.0, 1.0))
	_engine.pitch_scale = _pitch
	_engine.volume_db = lerpf(IDLE_DB, LOUD_DB, clampf(load * 0.75 + gas * 0.35, 0.0, 1.0))

## Batida de lataria, chamada pelo Vehicle. `impact` e a velocidade do choque.
func impact(impact_speed: float) -> void:
	if impact_speed < IMPACT_MIN or _since_impact < IMPACT_COOLDOWN:
		return
	_since_impact = 0.0
	var key := "batida_forte" if impact_speed > IMPACT_HEAVY else "batida_media"
	var loud: float = lerpf(-10.0, 0.0, clampf(impact_speed / IMPACT_HEAVY, 0.0, 1.0))
	AudioManager.play_at(key, global_position, loud, 1.0, 70.0)

## Buraco na pista: som mais surdo que uma batida de lataria.
func pothole() -> void:
	AudioManager.play_at("buraco", global_position, -4.0, randf_range(0.85, 1.0), 60.0)
