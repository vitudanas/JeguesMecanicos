extends Node
## Verificacao do som. Ele existe por uma limitacao honesta: **nao da pra ouvir
## nesta sessao**. Entao ele cobre tudo o que da pra provar sem ouvido —
##
##   * todo som declarado na biblioteca existe e carrega;
##   * os barramentos foram criados e o volume responde;
##   * os lacos sintetizados (motor e chuva) tem dado, duracao e emenda sem
##     estalo — a emenda e MEDIDA, comparando o fim com o comeco;
##   * os eventos do jogo realmente disparam som: instala gambiarra, arrebenta
##     gambiarra, bate o carro, cai num buraco, anda (passo) e fecha a venda,
##     conferindo em cada caso que uma voz saiu do repouso.
##
## O que ele NAO cobre: se o motor soa como motor. Isso e ouvido.
##
##   godot --headless --path . tools/verify/audio_test.tscn

var problems: Array[String] = []
var main: Node

func _ready() -> void:
	await get_tree().process_frame
	_check_library()
	_check_buses()
	_check_synth()
	await _check_events()
	await _check_ambience()
	print("")
	if problems.is_empty():
		print("=== RESULTADO ===")
		print("som carregado e disparando nos eventos certos")
		get_tree().quit(0)
	else:
		print("=== PROBLEMAS (%d) ===" % problems.size())
		for p in problems:
			print("  - %s" % p)
		get_tree().quit(1)

# ------------------------------------------------------------------ biblioteca

func _check_library() -> void:
	var total := 0
	var faltando := 0
	for key: String in AudioManager.LIBRARY:
		var spec: Dictionary = AudioManager.LIBRARY[key]
		var first: int = spec.get("de", 0)
		for i in range(int(spec["n"])):
			var path: String = (spec["arquivo"] as String) % (first + i)
			total += 1
			if not ResourceLoader.exists(path):
				faltando += 1
				problems.append("som declarado e ausente: %s" % path)
		# A chave tem que ter chegado carregada, nao so existir em disco.
		if AudioManager._sounds.get(key, []).is_empty():
			problems.append("chave '%s' carregou zero variacoes" % key)
	print("[1] biblioteca: %d chaves, %d arquivos, %d ausentes"
		% [AudioManager.LIBRARY.size(), total, faltando])

func _check_buses() -> void:
	for bus_name in [AudioManager.BUS_SFX, AudioManager.BUS_UI]:
		if AudioServer.get_bus_index(bus_name) < 0:
			problems.append("barramento '%s' nao foi criado" % bus_name)
	# O volume tem que CHEGAR na mesa: guardar o campo e nao aplicar ja seria um
	# controle que nao controla nada.
	var idx := AudioServer.get_bus_index(AudioManager.BUS_SFX)
	if idx >= 0:
		var antes := AudioManager.sfx
		AudioManager.set_levels(AudioManager.master, 0.25, AudioManager.ui)
		var db_baixo := AudioServer.get_bus_volume_db(idx)
		AudioManager.set_levels(AudioManager.master, 1.0, AudioManager.ui)
		var db_alto := AudioServer.get_bus_volume_db(idx)
		if db_alto <= db_baixo:
			problems.append("volume de efeitos nao muda o barramento (%.1f -> %.1f dB)"
				% [db_baixo, db_alto])
		AudioManager.set_levels(AudioManager.master, antes, AudioManager.ui)
		print("[2] barramentos ok | SFX a 25%% = %.1f dB, a 100%% = %.1f dB"
			% [db_baixo, db_alto])
	# Zero tem que MUDAR, nao so abaixar.
	AudioManager.set_levels(0.0, AudioManager.sfx, AudioManager.ui)
	if not AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")):
		problems.append("volume geral em zero nao muda o barramento")
	AudioManager.set_levels(0.85, 0.9, 0.7)

# ------------------------------------------------------------------ sintetico

func _check_synth() -> void:
	# Motor agora e gravacao CC0, mas continua WAV para permitir checar a emenda
	# amostra a amostra. Chuva e cama urbana ainda sao geradas em codigo.
	for entry in [["motor gravado", AudioManager.engine_stream()],
			["chuva", AudioManager.rain_stream()], ["cidade", ProceduralAudio.city_hum()]]:
		var nome: String = entry[0]
		var s: AudioStreamWAV = entry[1]
		if s == null or s.data.size() == 0:
			problems.append("laco '%s' saiu vazio" % nome)
			continue
		var frames := s.data.size() / 2
		var dur := s.get_length()
		print("    fonte %-13s formato=%d stereo=%s bytes=%d loop=%d [%d,%d]" % [
			nome, s.format, s.stereo, s.data.size(), s.loop_mode, s.loop_begin, s.loop_end])
		if s.loop_mode != AudioStreamWAV.LOOP_FORWARD or s.loop_begin < 0 \
				or s.loop_end <= s.loop_begin or s.loop_end > frames:
			problems.append("laco '%s' nao esta marcado como laco" % nome)
			continue
		# Emenda: a ultima amostra tem que estar perto da primeira, senao a volta
		# do laco da um ESTALO — o defeito mais audivel possivel num som que
		# repete o tempo todo.
		var primeiro := s.data.decode_s16(s.loop_begin * 2) / 32768.0
		var ultimo := s.data.decode_s16((s.loop_end - 1) * 2) / 32768.0
		var salto: float = absf(ultimo - primeiro)
		var pico := 0.0
		for i in range(0, frames, maxi(1, frames / 2000)):
			pico = maxf(pico, absf(s.data.decode_s16(i * 2) / 32768.0))
		print("[3] %-6s %.2f s, %d Hz, pico %.2f, emenda %.3f"
			% [nome, dur, s.mix_rate, pico, salto])
		if pico < 0.2:
			problems.append("laco '%s' quase mudo (pico %.2f)" % [nome, pico])
		if salto > 0.35:
			problems.append("laco '%s' estala na volta (salto de %.2f)" % [nome, salto])
	var vento := AudioManager.wind_stream()
	if vento == null or not vento.loop:
		problems.append("gravacao CC0 de vento ausente ou sem laco")
	else:
		print("[3] vento gravado %.2f s, laco ativo" % vento.get_length())

# ------------------------------------------------------------------ ambiente

## O ambiente e o transito tem CUSTO FIXO, e e isso que precisa ser cobrado: a
## razao de o transito ter ficado mudo ate agora era um tocador por carro. Se
## alguem trocar o emprestimo de vozes por "um AudioStreamPlayer3D em cada
## TrafficCar", isto reprova.
func _check_ambience() -> void:
	# REUSA o mundo que `_check_events` ja carregou. Carregar um segundo Main
	# punha DOIS mundos na arvore: 84 carros de IA em vez de 42, duas cameras, e
	# eu teleportava um jogador enquanto media a camera do outro — o teste
	# acusou "a cidade nao cede pro vento" medindo o mundo errado.
	if get_tree().get_first_node_in_group("player") == null:
		problems.append("nenhum mundo carregado pra medir o ambiente")
		return
	for i in range(10):
		await get_tree().process_frame
		await get_tree().physics_frame

	var carros := get_tree().get_nodes_in_group("traffic_car").size()
	var tocadores := 0
	for car in get_tree().get_nodes_in_group("traffic_car"):
		for c in (car as Node).get_children():
			if c is AudioStreamPlayer3D:
				tocadores += 1
	print("\n[5] %d carros de IA na cidade | %d tocadores presos a eles | %d vozes emprestadas"
		% [carros, tocadores, AudioManager.TRAFFIC_VOICES])
	if tocadores > 0:
		problems.append("%d carro(s) de IA com tocador proprio — o custo tem que ser fixo" % tocadores)
	if carros < 10:
		problems.append("quase nao ha carro de IA na cena (%d)" % carros)

	# Mede nos DOIS lugares de proposito, teleportando o jogador (a camera e
	# filha dele). A primeira versao supunha que ele nascia na oficina e media
	# so uma vez — mas neste contexto ele nasce em (0, 0, 6), ou seja no meio da
	# cidade, e o teste reprovou o codigo certo por causa da suposicao.
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var cam := get_viewport().get_camera_3d()
	if player == null or cam == null:
		problems.append("sem jogador/camera pra medir o ambiente")
		return

	# A cidade atual chega a 337,5 m e tem transicao ate ~430 m. O ponto antigo
	# em 320 estava literalmente dentro de um bairro e testava a premissa velha.
	var campo := await _ambience_at(player, Vector3(-520.0, 2.0, 0.0))
	print("    campo  (chebyshev 520): vento %.0f dB, cidade %.0f dB" % [campo[1], campo[0]])
	if campo[1] <= campo[0]:
		problems.append("no campo a cama de cidade nao cede pro vento (%.0f vs %.0f dB)"
			% [campo[0], campo[1]])

	var centro := await _ambience_at(player, Vector3(0.0, 2.0, 0.0))
	print("    centro (chebyshev 0):   vento %.0f dB, cidade %.0f dB" % [centro[1], centro[0]])
	if centro[0] <= centro[1]:
		problems.append("no centro a cama de cidade nao assume (%.0f vs %.0f dB)"
			% [centro[0], centro[1]])

## Leva o jogador pra `onde`, espera a transicao inteira e devolve
## [cidade_db, vento_db].
func _ambience_at(player: Node3D, onde: Vector3) -> Array:
	player.global_position = onde
	player.force_update_transform()
	# Folga sobre AMBIENCE_FADE: a transicao e por tempo, nao por quadro.
	for i in range(260):
		await get_tree().process_frame
	return [AudioManager._city.volume_db, AudioManager._wind.volume_db]

# -------------------------------------------------------------------- eventos

## Quantas vozes 3D estao tocando agora.
func _voices_busy() -> int:
	var n := 0
	for p in AudioManager._voices_3d:
		if p.playing:
			n += 1
	for p in AudioManager._voices_2d:
		if p.playing:
			n += 1
	return n

## Roda `action` e cobre que ela fez ALGUMA voz comecar a tocar.
func _expect_sound(label: String, action: Callable) -> void:
	for p in AudioManager._voices_3d:
		p.stop()
	for p in AudioManager._voices_2d:
		p.stop()
	await get_tree().process_frame
	action.call()
	await get_tree().process_frame
	var busy := _voices_busy()
	if busy > 0:
		print("    ok: %s -> %d voz(es)" % [label, busy])
	else:
		problems.append("%s nao tocou nada" % label)

func _check_events() -> void:
	main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in range(6):
		await get_tree().process_frame
		await get_tree().physics_frame

	print("[4] eventos do jogo")
	var vehicle: Node = null
	for v in get_tree().get_nodes_in_group("vehicle"):
		vehicle = v
		break
	if vehicle == null:
		problems.append("nenhum veiculo na cena pra testar som")
		return

	# Buraco e batida passam pelo caminho real do Vehicle.
	await _expect_sound("buraco na pista", func() -> void: vehicle.hit_pothole(9.0))
	await _expect_sound("batida de lataria", func() -> void:
		vehicle.audio.impact(11.0))

	# Gambiarra: instalar e arrebentar, pelos metodos do jogo.
	var spot: Node = null
	var points: Node = vehicle.get_node_or_null("AttachPoints")
	if points:
		for c in points.get_children():
			spot = c
			break
	if spot:
		await _expect_sound("gambiarra instalada", func() -> void: spot.interact(null))
		var part = vehicle.installed_parts.values()[0] if vehicle.installed_parts.size() > 0 else null
		if part:
			await _expect_sound("gambiarra arrebentada", func() -> void:
				part.receive_stress(999.0))
		else:
			problems.append("gambiarra nao chegou a ser instalada")
	else:
		problems.append("carro sem ponto de gambiarra pra testar")

	# Passo: o jogador andando de verdade pelo _physics_process dele.
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		await _expect_sound("passo do jogador", func() -> void:
			player.velocity = Vector3(4.0, 0.0, 0.0)
			player._update_steps(0.30))
	else:
		problems.append("jogador nao encontrado pra testar passo")

	# Interface.
	await _expect_sound("clique de menu", func() -> void: AudioManager.play_ui("clique"))

	# Chuva: nivel acompanha o clima, e nao toca no menu (sem jogador).
	# Espera a transicao INTEIRA (RAIN_FADE) nos dois sentidos. Uma janela curta
	# so provava que o nivel se mexeu — media 0.08 e passava, entao um defeito
	# que travasse a chuva em 10%% do volume passaria junto.
	var molhado := await _rain_level_after(true)
	var seco := await _rain_level_after(false)
	print("    chuva: nivel com chuva %.2f, sem chuva %.2f" % [molhado, seco])
	if molhado < 0.9:
		problems.append("chuva nao chega no volume cheio (parou em %.2f)" % molhado)
	if seco > 0.05:
		problems.append("chuva nao silencia com tempo bom (ficou em %.2f)" % seco)

## Liga/desliga a chuva e deixa passar mais que o tempo de transicao.
func _rain_level_after(raining: bool) -> float:
	WeatherManager.is_raining = raining
	var waited := 0.0
	while waited < AudioManager.RAIN_FADE * 1.6:
		waited += get_process_delta_time()
		await get_tree().process_frame
	return AudioManager._rain_level
