extends Node
## Faz o MUNDO INTEIRO reagir a chuva, nao so o punhado de gotas em volta do
## jogador.
##
## Alargar a caixa de particulas nao resolve o pedido "parecer que chove em
## tudo": particula so aparece perto, e enche a tela de gota sem molhar o mundo.
## O que vende chuva no mapa todo e o AMBIENTE — ceu fechando, luz do sol
## caindo, nevoa subindo e o chao escurecendo como se estivesse molhado. Isso
## vale pro horizonte inteiro e nao custa nenhuma particula.
##
## A transicao e suave (`transition_seconds`): clima que muda num piscar entrega
## que e uma chave sendo virada.

@export var transition_seconds := 4.0
## Quanto a luz do sol cai na chuva (1.0 = sem mudanca).
@export var rain_sun_energy := 0.42
@export var rain_sun_color := Color(0.72, 0.75, 0.82)
## Ceu e ambiente na chuva.
@export var rain_sky_energy := 0.45
@export var rain_ambient_energy := 0.75
## Nevoa: na chuva ela fecha o horizonte, que e o que faz a serra sumir na agua.
# 0.006 apagava a cidade inteira vista de 200 m: virava leite, nao chuva.
@export var rain_fog_density := 0.0022
@export var rain_fog_color := Color(0.62, 0.65, 0.70)
## Chao molhado: escurece e fica mais espelhado.
@export var rain_ground_darken := 0.72

@export var sun_path: NodePath
@export var env_path: NodePath
@export var ground_path: NodePath

var _sun: DirectionalLight3D = null
var _env: WorldEnvironment = null
var _ground_mat: ShaderMaterial = null

# Valores de tempo bom, lidos da cena no _ready: nada e escrito na mao aqui,
# entao mexer no Environment do Town continua valendo.
var _dry := {}
var _wet := 0.0      ## 0 = seco, 1 = chuva fechada
var _target := 0.0

func _ready() -> void:
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	_env = get_node_or_null(env_path) as WorldEnvironment
	var g := get_node_or_null(ground_path) as MeshInstance3D
	if g:
		var m := g.get_surface_override_material(0)
		if m is ShaderMaterial:
			_ground_mat = m
	if _sun:
		_dry["sun_energy"] = _sun.light_energy
		_dry["sun_color"] = _sun.light_color
	if _env and _env.environment:
		var e := _env.environment
		_dry["sky_energy"] = e.background_energy_multiplier
		_dry["ambient_energy"] = e.ambient_light_energy
		_dry["fog_enabled"] = e.fog_enabled
		_dry["fog_density"] = e.fog_density
		_dry["fog_color"] = e.fog_light_color
	if _ground_mat:
		_dry["grass"] = _ground_mat.get_shader_parameter("grass_color")
		_dry["dry_grass"] = _ground_mat.get_shader_parameter("grass_dry_color")
		_dry["dirt"] = _ground_mat.get_shader_parameter("dirt_color")
		_dry["gravel"] = _ground_mat.get_shader_parameter("gravel_color")
	_target = 1.0 if WeatherManager.is_raining else 0.0
	_wet = _target
	_apply()
	WeatherManager.weather_changed.connect(_on_weather_changed)

func _on_weather_changed(raining: bool) -> void:
	_target = 1.0 if raining else 0.0

func _process(delta: float) -> void:
	if is_equal_approx(_wet, _target):
		return
	var step: float = delta / maxf(transition_seconds, 0.01)
	_wet = move_toward(_wet, _target, step)
	_apply()

func _apply() -> void:
	if _sun and _dry.has("sun_energy"):
		_sun.light_energy = lerpf(_dry["sun_energy"], _dry["sun_energy"] * rain_sun_energy, _wet)
		_sun.light_color = (_dry["sun_color"] as Color).lerp(rain_sun_color, _wet)
	if _env and _env.environment and _dry.has("sky_energy"):
		var e := _env.environment
		e.background_energy_multiplier = lerpf(_dry["sky_energy"],
			_dry["sky_energy"] * rain_sky_energy, _wet)
		e.ambient_light_energy = lerpf(_dry["ambient_energy"],
			_dry["ambient_energy"] * rain_ambient_energy, _wet)
		# A nevoa e ligada durante a chuva mesmo que o tempo bom nao use nenhuma.
		e.fog_enabled = bool(_dry["fog_enabled"]) or _wet > 0.01
		e.fog_density = lerpf(float(_dry["fog_density"]), rain_fog_density, _wet)
		e.fog_light_color = (_dry["fog_color"] as Color).lerp(rain_fog_color, _wet)
	if _ground_mat and _dry.has("grass"):
		# Chao molhado: mais escuro e menos saturado. E o sinal mais forte de que
		# choveu ALI, mesmo onde nao ha uma gota desenhada.
		for pair: Array in [["grass", "grass_color"], ["dry_grass", "grass_dry_color"],
				["dirt", "dirt_color"], ["gravel", "gravel_color"]]:
			var key: String = pair[0]
			var param: String = pair[1]
			var base: Color = _dry[key]
			_ground_mat.set_shader_parameter(param, base.lerp(base * rain_ground_darken, _wet))
