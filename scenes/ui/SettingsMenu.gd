extends Control
## Tela de configuracao de graficos, montada em CODIGO a partir da tabela de
## opcoes abaixo.
##
## Em codigo, e nao como arvore de nós no .tscn, por dois motivos: os controles
## sao todos iguais (rotulo + OptionButton), e um .tscn escrito a mao com 8
## blocos repetidos e exatamente o tipo de arquivo onde ja aparece bug de
## serializacao neste projeto (o `script` que faltava em MainMenu.tscn, ver
## changelog 2026-08-02).
##
## Serve tanto ao menu principal quanto ao pause: quem abre passa o que fazer no
## Voltar, por `back_pressed`.

signal back_pressed

## nome interno, rotulo, opcoes (rotulo -> valor)
const OPTIONS: Array = [
	["preset", "Qualidade", [
		["Baixa", "baixa"], ["Média", "media"], ["Alta", "alta"], ["Ultra", "ultra"]]],
	["render_scale", "Resolução do 3D", [
		["50% (mais rápido)", 0.5], ["60%", 0.6], ["75%", 0.75], ["85%", 0.85],
		["100% (nativo)", 1.0]]],
	["shadows", "Sombras", [["Desligadas", 0], ["Curtas", 1], ["Longas", 2]]],
	["ambient_occlusion", "Oclusão e luz indireta", [
		["Desligadas", 0], ["Só oclusão (SSAO)", 1], ["Oclusão + indireta (SSIL)", 2]]],
	["grass", "Grama", [["Sem grama", 0], ["Média", 1], ["Cheia", 2]]],
	["aa", "Suavização de serrilhado", [
		["Desligada", 0], ["FXAA", 1], ["TAA (só em 100%)", 2]]],
	["glow", "Brilho (glow)", [["Desligado", false], ["Ligado", true]]],
	["vsync", "V-Sync", [["Desligado", false], ["Ligado", true]]],
	["show_fps", "Contador de FPS", [["Escondido", false], ["Visível", true]]],
]

var _pickers: Dictionary = {}
var _building := false

func _ready() -> void:
	# Cobre a tela por conta propria. Esta tela NAO tem .tscn: um `.tscn`
	# escrito a mao aqui ficou de fora do `.pck` exportado — presente no cache
	# do editor, ausente no pacote —, e o `preload` dele quebraria o menu
	# inteiro no build (a classe de bug do `exclude_filter` de 2026-08-02, que
	# so aparece no binario exportado). Montada 100% em codigo, so depende do
	# .gd, que o exportador sempre leva.
	# `set_anchors_and_offsets_preset`, nao `set_anchors_preset`: o segundo so
	# mexe nas ancoras e RECALCULA os offsets pra manter o retangulo atual — que
	# num `Control.new()` e 0x0. A tela montava com os 9 controles e ficava
	# invisivel, medindo (0, 0). Num `.tscn`, `anchors_preset = 15` faz as duas
	# coisas, e por isso o defeito so apareceu ao largar o arquivo de cena.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()

func _build() -> void:
	var bg := ColorRect.new()
	# Opaco: a 0.96 o menu de tras aparecia por baixo dos controles e a tela
	# ficava confusa de ler.
	bg.color = Color(0.09, 0.10, 0.14, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(620, 0)
	center.add_child(box)

	var title := Label.new()
	title.text = "Gráficos"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var hint := Label.new()
	hint.text = "O contador de FPS fica no canto inferior esquerdo — ajuste até ficar acima de 50."
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	box.add_child(_spacer(10))

	for entry: Array in OPTIONS:
		var key: String = entry[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		box.add_child(row)

		var label := Label.new()
		label.text = entry[1]
		label.add_theme_font_size_override("font_size", 18)
		label.custom_minimum_size = Vector2(300, 0)
		row.add_child(label)

		var picker := OptionButton.new()
		picker.custom_minimum_size = Vector2(300, 40)
		picker.add_theme_font_size_override("font_size", 17)
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for i in range(entry[2].size()):
			picker.add_item(entry[2][i][0], i)
		picker.item_selected.connect(_on_selected.bind(key))
		row.add_child(picker)
		_pickers[key] = picker

	box.add_child(_spacer(18))
	var back := Button.new()
	back.text = "Voltar"
	back.custom_minimum_size = Vector2(0, 48)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(func() -> void: emit_signal("back_pressed"))
	box.add_child(back)

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _values(key: String) -> Array:
	for entry: Array in OPTIONS:
		if entry[0] == key:
			return entry[2]
	return []

func _on_selected(index: int, key: String) -> void:
	# Enquanto `_refresh` mexe nos controles, `item_selected` nao dispara — mas
	# escolher um preset REFAZ todos os outros, e sem esta trava cada um deles
	# voltaria aqui como se o jogador tivesse mexido, apagando o preset.
	if _building:
		return
	var value: Variant = _values(key)[index][1]
	if key == "preset":
		GraphicsSettings.use_preset(value)
	else:
		GraphicsSettings.set(key, value)
		GraphicsSettings.mark_custom()
		GraphicsSettings.apply()
		GraphicsSettings.save_settings()
	_refresh()

func _refresh() -> void:
	_building = true
	for key: String in _pickers:
		var picker: OptionButton = _pickers[key]
		var current: Variant = GraphicsSettings.preset if key == "preset" \
			else GraphicsSettings.get(key)
		var values := _values(key)
		var found := -1
		for i in range(values.size()):
			if typeof(values[i][1]) == TYPE_FLOAT:
				if is_equal_approx(float(values[i][1]), float(current)):
					found = i
					break
			elif values[i][1] == current:
				found = i
				break
		# "custom" (combinacao propria) nao esta na lista: nesse caso nenhum item
		# fica marcado, que e a leitura honesta.
		picker.select(found)
	_building = false
