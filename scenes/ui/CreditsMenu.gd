extends Control
## Tela de CRÉDITOS.
##
## Não é enfeite: os 51 modelos de terceiro que o jogo distribui são **CC-BY**,
## e essa licença libera uso comercial mas exige crédito. Sem esta tela o jogo
## está fora da licença — foi a pendência mais antiga em aberto do projeto
## (anotada desde 2026-08-09, quando os primeiros pacotes foram baixados).
##
## Montada 100% EM CÓDIGO, sem `.tscn`, pelo mesmo motivo do menu de gráficos e
## do de personagem: cena escrita à mão já ficou de fora do `.pck` exportado
## (2026-08-04), e o defeito só aparece no binário. O `.gd` o exportador sempre
## leva.
##
## A lista sai de `assets/creditos.gd`, gerado por `tools/creditos.py` a partir
## do `license.txt` de cada pacote — escrever nome de autor à mão daria errado na
## primeira vez que alguém baixasse mais um modelo.

signal back_pressed

## Carregado por CAMINHO e não pela classe: o arquivo é gerado, e uma referência
## dura faria a tela não compilar antes de alguém rodar o gerador.
const DADOS := "res://assets/creditos.gd"

const FUNDO := Color(0.06, 0.07, 0.09)
const TITULO := Color(1.0, 0.82, 0.28)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	# `set_anchors_and_offsets_preset`, e nao `set_anchors_preset`: o segundo so
	# mexe nas ancoras e mantem o retangulo atual, que num `Control.new()` e
	# ZERO — a tela montava os controles todos e ficava invisivel (2026-08-04).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = FUNDO
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado: String in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 48)
	add_child(margem)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	margem.add_child(coluna)

	var titulo := Label.new()
	titulo.text = "Créditos"
	titulo.add_theme_font_size_override("font_size", 40)
	titulo.add_theme_color_override("font_color", TITULO)
	coluna.add_child(titulo)

	var nota := Label.new()
	nota.text = "Os modelos abaixo são de terceiros, sob licença CC-BY: " \
		+ "uso liberado, crédito obrigatório. Obrigado a quem publicou."
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.add_theme_font_size_override("font_size", 16)
	nota.modulate = Color(1, 1, 1, 0.75)
	coluna.add_child(nota)

	# A lista ROLA: são 51 modelos mais os pacotes CC0, e não cabem numa tela.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(scroll)

	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 4)
	scroll.add_child(lista)
	_preencher(lista)

	# O botão de voltar fica FORA da coluna que rola, no rodapé: dentro dela ele
	# cairia abaixo da dobra e "não acho como voltar" é a pior falha de menu que
	# existe (foi exatamente isso na tela de personagem, em 2026-08-10).
	var voltar := Button.new()
	voltar.text = "Voltar"
	voltar.custom_minimum_size = Vector2(220, 48)
	voltar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	voltar.pressed.connect(_on_back)
	coluna.add_child(voltar)
	voltar.grab_focus()

func _preencher(lista: VBoxContainer) -> void:
	var script: Script = load(DADOS) as Script
	if script == null:
		lista.add_child(_linha("(rode tools/creditos.py pra gerar a lista)", 16, 0.7))
		return
	var mapa := script.get_script_constant_map()

	var grupo := ""
	for item: Dictionary in mapa.get("CC_BY", []):
		if str(item["grupo"]) != grupo:
			grupo = str(item["grupo"])
			lista.add_child(_secao(grupo))
		lista.add_child(_linha("%s — %s  (%s)" % [item["titulo"], item["autor"],
			item["licenca"]], 15, 0.92))

	var cc0: Array = mapa.get("CC0", [])
	if not cc0.is_empty():
		lista.add_child(_secao("Domínio público (CC0)"))
		for item: Dictionary in cc0:
			lista.add_child(_linha("%s — %s  ·  %s" % [item["autor"], item["o_que"],
				item["site"]], 15, 0.92))

	lista.add_child(_secao("Motor"))
	lista.add_child(_linha("Godot Engine 4 — godotengine.org", 15, 0.92))

func _secao(texto: String) -> Control:
	var caixa := VBoxContainer.new()
	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(0, 14)
	caixa.add_child(espaco)
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", TITULO)
	caixa.add_child(label)
	return caixa

func _linha(texto: String, tamanho: int, alfa: float) -> Label:
	var label := Label.new()
	label.text = texto
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", tamanho)
	label.modulate = Color(1, 1, 1, alfa)
	return label

func _on_back() -> void:
	back_pressed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_back()
