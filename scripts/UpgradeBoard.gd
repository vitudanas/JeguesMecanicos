extends StaticBody3D
## Quadro de upgrades no pátio da oficina: onde o lucro vira loja maior.
##
## `StaticBody3D` porque e assim que o raycast de interacao do jogador acha as
## coisas (mesmo motivo do `BuyerNPC`).
##
## Interacao contextual, no mesmo idioma do resto do jogo: **Q troca de área**,
## **E compra o próximo nível**. Sem menu, sem mouse — o jogo inteiro e mirar e
## apertar tecla, e abrir uma janela so aqui seria um corpo estranho.
##
## Montado com primitivas em codigo, como o mobiliario urbano e as gambiarras:
## nao ha modelo CC0 disso e nao ha ferramenta de geracao 3D aqui.

const BOARD_COLOR := Color(0.16, 0.20, 0.26)
const FRAME_COLOR := Color(0.32, 0.26, 0.18)

var _area_index := 0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("suspenso")   # o painel fica em pé num poste, não no chão
	_build()

func _build() -> void:
	var poste := _box(Vector3(0.12, 1.4, 0.12), Vector3(0.0, 0.7, 0.0), FRAME_COLOR)
	poste.name = "Poste"
	var painel := _box(Vector3(1.5, 0.95, 0.08), Vector3(0.0, 1.75, 0.0), BOARD_COLOR)
	painel.name = "Painel"
	# Moldura, só pra não ser uma placa lisa.
	for lado: float in [-1.0, 1.0]:
		_box(Vector3(0.07, 1.02, 0.1), Vector3(lado * 0.76, 1.75, 0.0), FRAME_COLOR)
	_box(Vector3(1.62, 0.07, 0.1), Vector3(0.0, 2.26, 0.0), FRAME_COLOR)

	var titulo := Label3D.new()
	titulo.text = "MELHORIAS"
	titulo.font_size = 96
	titulo.pixel_size = 0.0016
	titulo.modulate = Color(1.0, 0.84, 0.24)
	titulo.position = Vector3(0.0, 2.12, 0.06)
	add_child(titulo)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 2.3, 0.3)
	shape.shape = box
	shape.position = Vector3(0.0, 1.15, 0.0)
	add_child(shape)

func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

func _area() -> String:
	return Dealership.ORDER[_area_index % Dealership.ORDER.size()]

func get_interact_prompt() -> String:
	var area := _area()
	var info: Dictionary = Dealership.AREAS[area]
	var linha := "%s  (nível %d/%d) — %s" % [info["nome"], Dealership.level(area) + 1,
		Dealership.max_level(area) + 1, Dealership.current_text(area)]
	if Dealership.at_max(area):
		linha += "\nno máximo" + _staff_line(area)
	else:
		linha += "\npróximo: %s — R$ %d  [E] comprar" % [
			Dealership.next_text(area), Dealership.next_cost(area)]
	return linha + "\n[Q] ver outra área"

## A vaga de funcionário só aparece no ÚLTIMO nível da área — é a regra do jogo
## de referência (ver Staff.gd), e é o que faz contratar ser o que a área vira
## depois de paga inteira, em vez de um atalho comprado cedo.
func _staff_line(area: String) -> String:
	var role := Staff.role_for_area(area)
	if role == "":
		return ""
	var info: Dictionary = Staff.ROLES[role]
	if Staff.has(role):
		return "\n%s contratado — %s" % [info["nome"], info["texto"]]
	return "\n[E] contratar %s — R$ %d (%s)" % [
		info["nome"], Staff.cost(role), info["texto"]]

## E compra o próximo nível da área que está na tela — ou, se ela já está no
## teto, contrata quem trabalha nela.
func interact(_player: Node) -> void:
	var area := _area()
	var erro := ""
	if Dealership.at_max(area):
		var role := Staff.role_for_area(area)
		erro = "no máximo" if role == "" else Staff.hire(role)
	else:
		erro = Dealership.buy(area)
	if erro == "":
		AudioManager.play_ui("confirma", 0.0)
	else:
		AudioManager.play_ui("erro", -4.0)

## Q passa pra próxima área.
func negotiate() -> void:
	_area_index = (_area_index + 1) % Dealership.ORDER.size()
	AudioManager.play_ui("passar", -8.0)
