extends Node
## A tela de carregamento chega ao fim?
##
## Ela virou o UNICO caminho pra entrar na partida e usa carga em OUTRA LINHA de
## execucao (`load_threaded_request`), que falha diferente da carga normal.
##
## **Como este teste espera, e por que nao espera o mundo aparecer**: o ultimo
## passo da tela e `change_scene_to_packed`, e isso LIBERA a cena atual — que num
## teste rodado com `godot tools/verify/loading_test.tscn` e este proprio no. A
## primeira versao esperava o jogador aparecer e ficava pendurada pra sempre,
## porque quem esperava tinha sido liberado no meio do await (90 s ate desistir,
## e o defeito era do arnes, nao do jogo). Entao aqui se espera o sinal
## `finished`, emitido logo ANTES da troca: nesse ponto a carga em thread ja
## terminou e a cena empacotada ja esta na mao. Que o mundo monta direito e o
## `city`/`obstacles_test` que provam, carregando o Main.tscn eles mesmos.
##
##   godot --headless --path . tools/verify/loading_test.tscn

const LIMITE := 90.0

var _done := false

func _ready() -> void:
	await get_tree().process_frame
	var menu := (load("res://scenes/ui/MainMenu.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	print("[1] menu aberto, apertando Jogar")
	menu.get_node("VBox/PlayButton").emit_signal("pressed")
	await get_tree().process_frame

	var loading: Node = null
	for c in menu.get_children():
		if c.has_signal("finished"):
			loading = c
			break
	if loading == null:
		_fail("o botao Jogar nao abriu a tela de carregamento")
		return
	print("    ok: tela de carregamento aberta")
	loading.finished.connect(_on_finished)

	var t0 := Time.get_ticks_msec()
	while not _done and (Time.get_ticks_msec() - t0) / 1000.0 < LIMITE:
		await get_tree().process_frame
	if not _done:
		_fail("a carga nao terminou em %.0f s" % LIMITE)

func _on_finished() -> void:
	_done = true
	print("    ok: carga concluida e cena empacotada obtida")
	print("\n=== RESULTADO ===")
	print("a tela de carregamento chega ao fim e entrega o jogo")
	# Sai AGORA, antes da troca de cena: depois dela este no nao existe mais.
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("    FALHOU: %s" % msg)
	print("\n=== PROBLEMAS (1) ===")
	print("  - %s" % msg)
	get_tree().quit(1)
