extends GPUParticles3D
## Chuva: segue o jogador (fica sempre "no ceu" acima dele, view-independente
## de onde ele anda) e liga/desliga sozinha conforme
## WeatherManager.weather_changed. Ver autoload/WeatherManager.gd.

## Altura de onde a chuva cai, acima da CAMERA.
##
## BAIXA de proposito. A 20 m, o plano de emissao visto de baixo projetava num
## naco pequeno do ceu e a chuva lia como uma COLUNA la em cima — exatamente a
## impressao de "chove so em cima de mim". Logo acima da cabeca, a gota cruza o
## campo de visao inteiro e o jogador fica DENTRO da chuva, que e o que se quer.
@export var height_offset := 11.0
## Quanto o volume de chuva e empurrado PRA FRENTE do olhar. E o que tira a
## sensacao de "chove so em cima de mim": centrado na camera, o jogador fica no
## meio de um circulo de chuva e enxerga a borda dele ao virar; deslocado pra
## frente, a chuva esta sempre onde ele esta OLHANDO, e a borda fica pras costas.
# Pouco: empurrado 26 m a frente, quase nenhuma gota passava PERTO da camera,
# e gota longe e sub-pixel. 10 m mantem a chuva no campo de visao sem tirar
# ela de cima do jogador.
@export var forward_bias := 6.0

var target: Node3D = null

func _ready() -> void:
	emitting = WeatherManager.is_raining
	WeatherManager.weather_changed.connect(_on_weather_changed)

func _on_weather_changed(is_raining: bool) -> void:
	emitting = is_raining

## Segue a CAMERA ATIVA, e nao o jogador.
##
## Seguindo o jogador, dirigindo em terceira pessoa a chuva ficava presa ao
## carro e o resto da rua aparecia seco; e olhando pra frente a 70 km/h o carro
## saia por baixo da coluna mais rapido do que ela reposicionava. A camera e o
## unico ponto de vista que importa: chuva que nao esta no campo de visao nao
## existe pra ninguem.
##
## Particula so pode existir PERTO — nenhum jogo chove nos 2200 m do mapa com
## particula (seriam milhoes). O que faz o mapa inteiro parecer chuvoso e o ceu
## fechado e a nevoa do `WeatherSky`; aqui embaixo so precisa nao denunciar que
## acompanha o jogador.
func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		if target == null:
			target = get_tree().get_first_node_in_group("player") as Node3D
		if target == null:
			return
		global_position = target.global_position + Vector3(0, height_offset, 0)
		return
	var ahead := -cam.global_transform.basis.z
	ahead.y = 0.0
	if ahead.length_squared() > 0.001:
		ahead = ahead.normalized()
	global_position = cam.global_position + ahead * forward_bias \
		+ Vector3(0, height_offset, 0)
