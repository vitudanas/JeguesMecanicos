class_name ProceduralAudio
extends RefCounted
## Gera em codigo os dois sons continuos do jogo: MOTOR e CHUVA.
##
## Por que sintetizar em vez de baixar: os pacotes CC0 de audio do Kenney (os
## mesmos que o resto do jogo usa) nao tem motor nem chuva — sao bibliotecas de
## impacto, passo e interface. E som continuo e justamente o que sintetiza bem,
## porque e ruido e harmonico, nao gravacao. Mesma escolha ja feita pro
## mobiliario urbano, pras gambiarras e pra cabeca de jegue: montar com o que
## da, em vez de misturar mais uma fonte de estilo.
##
## Custa ZERO byte no build (o .wav nasce na memoria) e o motor ainda ganha uma
## vantagem de graca: como e um ciclo sintetico, `pitch_scale` sobe e desce a
## rotacao sem soar picotado.

## 44,1 kHz evita o serrilhado audivel dos harmonicos do motor e das gotas.
## 22,05 kHz economizava pouca memoria (os loops sao curtos), mas dava ao jogo
## inteiro o timbre de radio/efeito sintetico que motivou esta revisao.
const RATE := 44100

# ------------------------------------------------------------------- motor

## Frequencia de explosao do laco base, em Hz. O `Vehicle` multiplica isso via
## `pitch_scale`, entao este valor e so a "marcha lenta" de referencia.
const ENGINE_FIRE_HZ := 30.0
## Explosoes no laco. Precisa ser INTEIRO pro laco fechar sem estalo, e PAR
## porque o ronco grave roda na metade da frequencia de explosao.
const ENGINE_CYCLES := 8

## Motor de calhambeque: explosoes irregulares, ronco grave por baixo e um
## chiado de admissao. Devolve um AudioStreamWAV em laco.
static func engine() -> AudioStreamWAV:
	var period := int(round(float(RATE) / ENGINE_FIRE_HZ))
	var frames := period * ENGINE_CYCLES
	var buf := PackedFloat32Array()
	buf.resize(frames)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260808   # som identico toda partida

	for i in range(frames):
		var cycle := i / period          # qual explosao
		var ph := float(i % period) / float(period)
		# Motor velho nao explode igual: cada cilindro sai com forca e ataque um
		# pouco diferentes. Como o padrao se repete a cada laco, isso nao quebra
		# a emenda — e e o que separa "motor" de "zumbido".
		var kick := 1.0 - 0.28 * float((cycle * 7) % 5) / 4.0
		var decay := 7.0 + 3.0 * float((cycle * 3) % 4)
		var env: float = exp(-decay * ph) * kick

		# Corpo da explosao: fundamental + harmonicos (o que da o "ronco") e
		# ruido (o que da o "estouro").
		var tone := sin(TAU * ph) * 0.55 + sin(2.0 * TAU * ph) * 0.28 \
			+ sin(3.0 * TAU * ph) * 0.14
		var burst := rng.randf() * 2.0 - 1.0
		var s := env * (tone * 0.78 + burst * 0.18)

		# Ronco grave contínuo, na metade da frequencia de explosao.
		s += 0.34 * sin(TAU * float(i) * (ENGINE_FIRE_HZ * 0.5) / float(RATE))
		s += 0.09 * sin(TAU * float(i) * (ENGINE_FIRE_HZ * 1.5) / float(RATE))
		# Chiado de admissao, bem baixo.
		s += 0.018 * (rng.randf() * 2.0 - 1.0)
		buf[i] = s

	_lowpass_looped(buf, 0.22)
	_lowpass_looped(buf, 0.38)
	_normalize(buf, 0.66)
	return _to_wav(buf, RATE)

# ------------------------------------------------------------------- chuva

const RAIN_SECONDS := 2.5
## Emenda do laco. Ruido cruzado nesta janela nao da pra ouvir; sem cruzar, o
## laco estala a cada volta.
const RAIN_CROSSFADE := 0.25

## Chuva: ruido filtrado ("chiado") com gotas esparsas por cima.
static func rain() -> AudioStreamWAV:
	var frames := int(RAIN_SECONDS * RATE)
	var fade := int(RAIN_CROSSFADE * RATE)
	var total := frames + fade
	var buf := PackedFloat32Array()
	buf.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260809

	for i in range(total):
		buf[i] = rng.randf() * 2.0 - 1.0

	# Passa-alta tira o retumbo (ruido cru soa como vento/motor);
	# passa-baixa tira o brilho de estatica. O que sobra e o "chiado".
	_highpass(buf, 0.72)
	_lowpass_looped(buf, 0.55)

	# Gotas: estalos curtos e agudos por cima do chiado. Sem elas a chuva vira
	# um chiado de radio fora de estacao.
	var drops := int(RAIN_SECONDS * 34.0)
	for d in range(drops):
		var at := rng.randi_range(0, total - 400)
		var amp := rng.randf_range(0.25, 0.85)
		var pitch := rng.randf_range(1600.0, 4200.0)
		var length := rng.randi_range(90, 260)
		for k in range(length):
			var t := float(k) / float(RATE)
			buf[at + k] += amp * exp(-38.0 * t) * sin(TAU * pitch * t) * 0.5

	# Emenda: o rabo entra por cima da cabeca, entao o fim casa com o comeco.
	for k in range(fade):
		var w := float(k) / float(fade)
		buf[k] = lerpf(buf[frames + k], buf[k], w)
	buf.resize(frames)

	_normalize(buf, 0.7)
	return _to_wav(buf, RATE)

# --------------------------------------------------------------- ambiente

const AMBIENCE_SECONDS := 4.0
## Emenda cruzada, mesma tecnica da chuva: ruido cruzado nao da pra ouvir, e sem
## cruzar o laco estala a cada volta.
const AMBIENCE_CROSSFADE := 0.4

## Zumbido de cidade: o ronco distante de transito que existe em qualquer rua
## movimentada, sem nenhum carro identificavel. Ruido bem grave com uma
## ondulacao lenta por cima — o que separa "cidade ao longe" de "chiado" e a
## VARIACAO, porque transito real vai e vem.
static func city_hum() -> AudioStreamWAV:
	return _bed(AMBIENCE_SECONDS, 20260809, 0.055, 0.46, [
		[0.07, 0.34], [0.13, 0.20],
	], 0.32)

## Vento do campo: mais agudo que o zumbido da cidade e com rajada mais lenta.
static func wind() -> AudioStreamWAV:
	return _bed(AMBIENCE_SECONDS, 20260810, 0.13, 0.34, [
		[0.05, 0.42], [0.11, 0.22],
	], 0.28)

## Cama de ruido em laco: filtra, ondula em algumas frequencias lentas e emenda.
## `cut` e o passa-baixa (grave -> agudo), `swell` a profundidade da ondulacao.
static func _bed(seconds: float, seed_value: int, cut: float, swell: float,
		waves: Array, peak: float) -> AudioStreamWAV:
	var frames := int(seconds * RATE)
	var fade := int(AMBIENCE_CROSSFADE * RATE)
	var total := frames + fade
	var buf := PackedFloat32Array()
	buf.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in range(total):
		buf[i] = rng.randf() * 2.0 - 1.0
	_lowpass_looped(buf, cut)

	# Ondulacao. As frequencias tem que caber um numero INTEIRO de vezes no
	# laco, senao a emenda pula no meio da onda e vira um "tum" audivel a cada
	# volta.
	for i in range(total):
		var env := 1.0 - swell
		for w: Array in waves:
			var cycles: float = maxf(round(float(w[0]) * seconds), 1.0)
			env += swell * float(w[1]) * (0.5 + 0.5 * sin(
				TAU * cycles * float(i) / float(frames)))
		buf[i] = buf[i] * env

	for k in range(fade):
		var t := float(k) / float(fade)
		buf[k] = lerpf(buf[frames + k], buf[k], t)
	buf.resize(frames)
	_normalize(buf, peak)
	return _to_wav(buf, RATE)

# ------------------------------------------------------------------ filtros

## Passa-baixa de 1 polo. Roda o buffer DUAS vezes e so guarda a segunda: assim
## o filtro chega no inicio do laco ja "aquecido" com o estado do fim, que e o
## que impede um degrau audivel na emenda.
static func _lowpass_looped(buf: PackedFloat32Array, a: float) -> void:
	var y := 0.0
	for pass_i in range(2):
		for i in range(buf.size()):
			y += a * (buf[i] - y)
			if pass_i == 1:
				buf[i] = y

static func _highpass(buf: PackedFloat32Array, a: float) -> void:
	var y := 0.0
	var prev := 0.0
	for i in range(buf.size()):
		var x := buf[i]
		y = a * (y + x - prev)
		prev = x
		buf[i] = y

static func _normalize(buf: PackedFloat32Array, peak: float) -> void:
	var top := 0.0
	for v in buf:
		top = maxf(top, absf(v))
	if top < 0.0001:
		return
	var g := peak / top
	for i in range(buf.size()):
		buf[i] = buf[i] * g

## Empacota em PCM 16 bits e devolve o stream ja em laco.
static func _to_wav(buf: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in range(buf.size()):
		var v := int(clampf(buf[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = buf.size()
	return stream
