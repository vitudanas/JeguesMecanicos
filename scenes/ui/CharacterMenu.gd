extends Control
## Tela de escolha e personalizacao do personagem, com preview 3D ao vivo.
##
## Montada em CODIGO, sem `.tscn`, pelo mesmo motivo do `SettingsMenu`: um
## `.tscn` escrito a mao ja ficou de fora do `.pck` exportado neste projeto
## (presente no cache do editor, ausente no pacote), e o `preload` dele quebrava
## o menu principal so no binario — a classe de bug de 2026-08-02, que nao
## aparece em desenvolvimento.
##
## O boneco do preview e montado por `PlayerVisual.build()`, ou seja pelo MESMO
## caminho que monta o jogador de verdade. Preview com montagem propria deixaria
## de provar o que o jogador vai ver — e foi exatamente assim que a cabeca de
## jegue passou dias sem ser olhada (ver changelog 2026-08-08).
##
## So abre pelo menu principal, e nao pelo pause: trocar de corpo no meio da
## partida exigiria remontar o `Player` (capsula, cabeca, camera e o carro que
## ele talvez esteja dirigindo) por um ganho que ninguem pediu.

signal back_pressed

## Enquadramento do preview. A distancia e derivada da altura do personagem, e
## nao fixa: entre 1,60 m e 1,95 m um valor unico ou corta a cabeca ou deixa o
## boneco pequeno no quadro.
const CAM_FOV := 34.0
const CAM_DISTANCE_FACTOR := 2.05
const CAM_DISTANCE_MIN := 1.1
const CAM_DISTANCE_MAX := 4.2
const DRAG_TO_RADIANS := 0.010
## Quanto a regua fica ao lado do boneco, em metros.
const RULER_OFFSET := 0.62

var _holder: SubViewportContainer = null
var _viewport: SubViewport = null
var _pivot: Node3D = null
var _camera: Camera3D = null
var _character: Node3D = null
var _ruler: Node3D = null

var _yaw := 0.0
var _zoom := 1.0
var _look_height := 0.55
var _dragging := false

var _rows: Dictionary = {}          ## id da forma -> HBoxContainer
var _sliders: Dictionary = {}       ## id da forma -> HSlider
var _shape_labels: Dictionary = {}  ## id da forma -> Label do valor
var _model_picker: OptionButton = null
var _head_picker: OptionButton = null
var _height_slider: HSlider = null
var _height_label: Label = null
var _tint_swatches: Dictionary = {}
var _tint_counters: Dictionary = {}
var _building := false

func _ready() -> void:
	# `set_anchors_and_offsets_preset`, nao `set_anchors_preset`: o segundo so
	# mexe nas ancoras e mantem o retangulo atual, que num `Control.new()` e 0x0
	# — a tela montava inteira e ficava invisivel (ver SettingsMenu).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_build_preview()
	_rebuild_character()
	_refresh()

# ---------------------------------------------------------------- interface

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.10, 0.14, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)

	var title := Label.new()
	title.text = "Personagem"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)

	var hint := Label.new()
	hint.text = "Arraste no boneco para girar · roda do mouse aproxima · a régua ao lado marca 1,80 m"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(hint)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	var preview_holder := SubViewportContainer.new()
	preview_holder.name = "PreviewHolder"
	preview_holder.stretch = true
	preview_holder.custom_minimum_size = Vector2(460, 0)
	preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_holder.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_holder.gui_input.connect(_on_preview_input)
	columns.add_child(preview_holder)
	_holder = preview_holder

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(scroll)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(560, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	box.add_child(_section("Quem você é"))

	_model_picker = OptionButton.new()
	for entry: Dictionary in Appearance.MODELS:
		_model_picker.add_item(str(entry["rotulo"]))
	_model_picker.item_selected.connect(_on_model_selected)
	box.add_child(_row("Personagem", _model_picker))

	_head_picker = OptionButton.new()
	_head_picker.add_item("Cabeça de jegue")
	_head_picker.add_item("Cabeça humana")
	_head_picker.item_selected.connect(_on_head_selected)
	box.add_child(_row("Cabeça", _head_picker))

	_height_slider = HSlider.new()
	_height_slider.min_value = Appearance.HEIGHT_MIN
	_height_slider.max_value = Appearance.HEIGHT_MAX
	_height_slider.step = 0.01
	_height_slider.value_changed.connect(_on_height_changed)
	_height_label = Label.new()
	box.add_child(_row("Altura", _height_slider, _height_label))

	box.add_child(_spacer(4))
	box.add_child(_section("Corpo"))

	for entry: Dictionary in Appearance.SHAPES:
		var shape_id := str(entry["id"])
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value_changed.connect(_on_shape_changed.bind(shape_id))
		var value_label := Label.new()
		var row := _row(str(entry["rotulo"]), slider, value_label)
		box.add_child(row)
		_rows[shape_id] = row
		_sliders[shape_id] = slider
		_shape_labels[shape_id] = value_label

	box.add_child(_spacer(4))
	box.add_child(_section("Cores"))
	for kind: String in ["pele", "roupa", "cabelo"]:
		box.add_child(_tint_row(kind))

	# Os botoes ficam FORA da coluna rolavel, no rodape da pagina. Dentro dela
	# eles caiam abaixo da dobra (visto na foto 95): quem abre a tela em janela
	# menor nao enxerga como sair, e "nao acho o botao de voltar" e a pior
	# maneira de descobrir isso.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	page.add_child(buttons)

	var restore := Button.new()
	restore.text = "Restaurar padrão"
	restore.custom_minimum_size = Vector2(0, 42)
	restore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restore.add_theme_font_size_override("font_size", 18)
	restore.pressed.connect(_on_restore)
	buttons.add_child(restore)

	var back := Button.new()
	back.text = "Salvar e voltar"
	back.custom_minimum_size = Vector2(0, 42)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_on_back)
	buttons.add_child(back)

func _row(label_text: String, control: Control, suffix: Label = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 17)
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	control.custom_minimum_size = Vector2(240, 34)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	if suffix:
		suffix.add_theme_font_size_override("font_size", 16)
		suffix.custom_minimum_size = Vector2(72, 0)
		suffix.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(suffix)
	return row

## Linha de cor: setas dos dois lados e uma amostra no meio. Sem a amostra o
## jogador so descobriria a cor olhando o boneco — que e justamente o que a
## seta acabou de mudar, e nem sempre da pra ver (cabelo escondido pela cabeca
## de jegue, por exemplo).
func _tint_row(kind: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label := Label.new()
	label.text = kind.capitalize()
	label.add_theme_font_size_override("font_size", 17)
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)

	var prev := Button.new()
	prev.text = "◀"
	prev.custom_minimum_size = Vector2(52, 34)
	prev.pressed.connect(_on_tint.bind(kind, -1))
	row.add_child(prev)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(160, 34)
	swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)
	_tint_swatches[kind] = swatch

	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(52, 34)
	next.pressed.connect(_on_tint.bind(kind, 1))
	row.add_child(next)

	# Contador: sem ele nao da pra saber quantas opcoes existem nem onde se
	# esta, e as duas setas parecem infinitas.
	var counter := Label.new()
	counter.add_theme_font_size_override("font_size", 15)
	counter.custom_minimum_size = Vector2(52, 0)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(counter)
	_tint_counters[kind] = counter
	return row

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _section(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.65, 0.82, 1.0))
	return l

# ------------------------------------------------------------------ preview

func _build_preview() -> void:
	_viewport = SubViewport.new()
	# Mundo proprio: sem isto o preview desenharia a cena 3D atual (que no menu
	# principal nao existe) em vez do boneco.
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size = Vector2i(460, 720)
	_holder.add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.15, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.60, 0.72)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	# Duas luzes: a chave em diagonal desenha o volume do corpo, e a de
	# preenchimento do outro lado impede que metade do boneco vire silhueta
	# preta — que e o que acontece com uma luz so num fundo escuro.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, 38, 0)
	key.light_energy = 1.5
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, -125, 0)
	fill.light_energy = 0.55
	fill.light_color = Color(0.80, 0.86, 1.0)
	_viewport.add_child(fill)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)

	_camera = Camera3D.new()
	_camera.fov = CAM_FOV
	_camera.current = true
	_viewport.add_child(_camera)

	_ruler = _build_ruler()
	_viewport.add_child(_ruler)

## Regua de 2 m ao lado do boneco, listrada a cada 10 cm, com a faixa de 1,80 m
## destacada. Sem uma referencia de tamanho no quadro nao da pra julgar altura:
## um boneco sozinho parece certo em qualquer escala — foi exatamente assim que
## os NPCs ficaram com 3,76 m por meses (changelog 2026-08-03).
func _build_ruler() -> Node3D:
	var root := Node3D.new()
	root.name = "Regua"
	root.position = Vector3(RULER_OFFSET, 0.0, 0.0)
	var steps := 20
	for i in range(steps):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.055, 0.1, 0.055)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(0.0, 0.05 + i * 0.1, 0.0)
		var mat := StandardMaterial3D.new()
		var at_reference := i == 17   # a faixa que vai de 1,70 a 1,80 m
		mat.albedo_color = Color(1.0, 0.78, 0.15) if at_reference \
			else (Color(0.86, 0.86, 0.88) if i % 2 == 0 else Color(0.30, 0.32, 0.36))
		mat.roughness = 0.6
		mi.material_override = mat
		root.add_child(mi)
	return root

## Remonta o boneco. So e chamado quando muda o MODELO ou a cabeca — slider de
## forma e cor escrevem no boneco que ja existe, senao a cada pixel de arrasto o
## personagem piscaria e a animacao voltaria ao primeiro quadro.
func _rebuild_character() -> void:
	if _character and is_instance_valid(_character):
		# Tirar da arvore ANTES de liberar, e nao so `queue_free()`: o no so sai
		# de fato no fim do quadro, entao o boneco novo entrava com o antigo
		# ainda la — dois personagens no mesmo lugar por um quadro, e o novo
		# renomeado pra "Visual2" pelo Godot (a armadilha de nome repetido que ja
		# enganou dois verificadores neste projeto).
		_pivot.remove_child(_character)
		_character.queue_free()
	_character = PlayerVisual.build(_pivot)
	if _character:
		# O modelo olha pro +Z e `PlayerVisual` vira 180 pra virar a frente do
		# CharacterBody3D. Aqui a camera fica no +Z, entao desfaz-se o giro pra
		# ele encarar quem esta olhando.
		_character.rotation_degrees.y = 0.0
	_update_camera()

func _update_camera() -> void:
	if _camera == null:
		return
	var height: float = Appearance.height
	var distance: float = clampf(height * CAM_DISTANCE_FACTOR * _zoom,
		CAM_DISTANCE_MIN, CAM_DISTANCE_MAX)
	var target := Vector3(0.0, height * _look_height, 0.0)
	var offset := Vector3(sin(_yaw), 0.0, cos(_yaw)) * distance
	_camera.position = target + offset + Vector3.UP * (height * 0.06)
	_camera.look_at(target, Vector3.UP)
	# A regua acompanha a camera, sempre a DIREITA do quadro. Plantada num ponto
	# fixo do mundo, ela passaria na frente do rosto do boneco assim que o
	# jogador girasse 90 graus.
	if _ruler:
		_ruler.position = Vector3(cos(_yaw), 0.0, -sin(_yaw)) * RULER_OFFSET

func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - 0.08, 0.45, 1.4)
			_update_camera()
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + 0.08, 0.45, 1.4)
			_update_camera()
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * DRAG_TO_RADIANS
		# Arrastar pra cima sobe o alvo da camera: e assim que se olha a cabeca
		# de jegue de perto sem precisar de um controle so pra isso.
		_look_height = clampf(_look_height + motion.relative.y * 0.0016, 0.18, 0.95)
		_update_camera()

# ------------------------------------------------------------------- estado

func _on_model_selected(index: int) -> void:
	if _building:
		return
	Appearance.set_model(str(Appearance.MODELS[index]["id"]))
	_rebuild_character()
	_refresh()

func _on_head_selected(index: int) -> void:
	if _building:
		return
	Appearance.set_donkey_head(index == 0)
	_rebuild_character()

func _on_height_changed(value: float) -> void:
	if _building:
		return
	Appearance.set_height(value)
	if _character:
		_character.scale = Vector3.ONE * Appearance.visual_scale()
	_update_camera()
	_refresh_height_label()

func _on_shape_changed(value: float, shape_id: String) -> void:
	if _building:
		return
	Appearance.set_shape(shape_id, value)
	if _character:
		PlayerVisual.apply_shape(_character)
	_refresh_shape_labels()

func _on_tint(kind: String, step: int) -> void:
	Appearance.cycle_tint(kind, step)
	if _character:
		PlayerVisual.apply_tints(_character)
	_refresh_swatches()

func _on_restore() -> void:
	Appearance.reset()
	_rebuild_character()
	_refresh()

func _on_back() -> void:
	Appearance.save_settings()
	back_pressed.emit()

## Esc tambem volta (e salva). A tela cobre o menu inteiro, entao sem isto o
## unico jeito de sair e achar o botao — e a tecla e o reflexo de quem joga.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_back()

func _refresh() -> void:
	_building = true
	for i in range(Appearance.MODELS.size()):
		if str(Appearance.MODELS[i]["id"]) == Appearance.model_id:
			_model_picker.select(i)
	_head_picker.select(0 if Appearance.donkey_head else 1)
	_height_slider.value = Appearance.height
	for entry: Dictionary in Appearance.SHAPES:
		var shape_id := str(entry["id"])
		var applies: bool = Appearance.shape_applies(entry)
		(_rows[shape_id] as Control).visible = applies
		(_sliders[shape_id] as HSlider).value = float(Appearance.shapes.get(shape_id, 0.0))
	_building = false
	_refresh_height_label()
	_refresh_shape_labels()
	_refresh_swatches()

func _refresh_height_label() -> void:
	if _height_label:
		_height_label.text = "%d cm" % int(round(Appearance.height * 100.0))

func _refresh_shape_labels() -> void:
	for shape_id: String in _shape_labels:
		var label: Label = _shape_labels[shape_id]
		label.text = "%d%%" % int(round(float(Appearance.shapes.get(shape_id, 0.0)) * 100.0))

## Cor de referencia de cada material, pra amostra mostrar algo parecido com o
## que aparece no boneco.
##
## A paleta guarda MULTIPLICADORES sobre a textura, entao a amostra crua saia
## BRANCA no primeiro item de cada linha (o multiplicador neutro e 1,1,1) — foi
## o que a foto 95 mostrou: tres retangulos brancos onde deviam estar pele,
## tecido e cabelo. Multiplicar por um tom medio do material devolve a leitura.
const TINT_BASE := {
	"pele": Color(0.80, 0.62, 0.50),
	"roupa": Color(0.74, 0.68, 0.58),
	"cabelo": Color(0.36, 0.27, 0.21),
}

func _refresh_swatches() -> void:
	var tints := Appearance.tints()
	var by_kind := {"pele": "skin", "roupa": "cloth", "cabelo": "hair"}
	var counts := {"pele": Appearance.SKIN_TINTS.size(),
		"roupa": Appearance.CLOTH_TINTS.size(), "cabelo": Appearance.HAIR_TINTS.size()}
	var current := {"pele": Appearance.skin, "roupa": Appearance.cloth,
		"cabelo": Appearance.hair}
	for kind: String in _tint_swatches:
		var color: Color = tints[by_kind[kind]] * (TINT_BASE[kind] as Color)
		# Um canal acima de 1.0 satura em branco no ColorRect; o tom claro da
		# paleta passa de 1.0 de proposito.
		var peak: float = maxf(1.0, maxf(color.r, maxf(color.g, color.b)))
		(_tint_swatches[kind] as ColorRect).color = Color(color.r / peak,
			color.g / peak, color.b / peak)
		(_tint_counters[kind] as Label).text = "%d/%d" % [
			posmod(int(current[kind]), int(counts[kind])) + 1, counts[kind]]
