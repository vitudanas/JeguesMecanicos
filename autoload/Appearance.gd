extends Node
## Aparencia do JOGADOR: qual personagem, que corpo, que cores, que altura.
##
## Ate agora isso era constante escrita no `PlayerVisual.gd` (`BUST = 0.50`,
## `BUTT = 0.72`, sempre a mulher de cabeca de jegue). Virou estado com dono
## unico porque tres coisas passaram a ler os mesmos valores: o jogador de
## verdade, o preview 3D da tela de personagem e o verificador — e valor
## repetido em tres lugares vira tres valores.
##
## Fica FORA do `SaveGame`: aparencia nao e progresso. Quem aperta "Novo jogo"
## perde o dinheiro e os niveis da loja, e nao deve perder o personagem que
## montou.

signal changed

const PATH := "user://aparencia.cfg"
const FORMAT := 1

## Os dois personagens prontos que o `tools/build_characters.py` gera (corpo +
## roupa + cabelo num arquivo so). O nome do cabelo DIFERE entre eles — medido:
## `Hair_Long` no feminino e `Hair_SimpleParted` no masculino —, e por isso o
## `PlayerVisual` esconde cabelo por prefixo em vez de por nome exato.
##
## `altura_modelo` e a altura MEDIDA do arquivo (nao estimada): e ela que
## converte "quero 1,80 m" na escala do visual. Os dois modelos nao tem a mesma
## altura nativa (1.788 contra 1.852), entao um fator unico deixaria o masculino
## sempre 3,5% mais alto que o pedido.
const MODELS_NATIVOS: Array[Dictionary] = [
	{
		"id": "feminino",
		"rotulo": "Mulher",
		"caminho": "res://assets/quaternius/characters-dressed/Female_Dressed.glb",
		"altura_modelo": 1.788,
	},
	{
		"id": "masculino",
		"rotulo": "Homem",
		"caminho": "res://assets/quaternius/characters-dressed/Male_Dressed.glb",
		"altura_modelo": 1.852,
	},
]

## Personagens BAIXADOS, medidos e catalogados por
## `tools/preparar_personagens.gd`. Ficam num arquivo gerado, e nao escritos
## aqui a mao, porque a lista cresce: com ~45 modelos, uma linha manual por
## modelo seriam 45 chances de errar a altura — e altura errada nao acusa em
## lugar nenhum, o personagem so nasce do tamanho errado (foi assim que os NPCs
## ficaram com 3,76 m por meses).
##
## Carregado por CAMINHO, e nao pela classe: o catalogo so existe depois que
## alguem baixa algum personagem, e uma referencia dura a `CatalogoPersonagens`
## faria o autoload nao compilar enquanto a pasta estivesse vazia.
const CATALOGO := "res://assets/personagens/catalogo.gd"

static var _todos: Array[Dictionary] = []
static var _todos_prontos := false

## Todos os personagens jogaveis: os dois nativos mais os baixados que o
## catalogo marcou como `jogavel`. Fica de fora quem nao e UMA pessoa de pe —
## estatua sem osso, arquivo com varios personagens dentro, modelo que vem
## sentado ou com cenario junto (ver preparar_personagens.gd). Todos continuam
## no catalogo, porque servem de cenario.
static func models() -> Array[Dictionary]:
	if _todos_prontos:
		return _todos
	_todos_prontos = true
	_todos = MODELS_NATIVOS.duplicate(true)
	if not ResourceLoader.exists(CATALOGO):
		return _todos
	var script: Script = load(CATALOGO) as Script
	if script == null:
		return _todos
	var mapa := script.get_script_constant_map()
	if not mapa.has("PERSONAGENS"):
		return _todos
	for e: Dictionary in mapa["PERSONAGENS"]:
		# `jogavel` e o veredito do catalogo; o `ossos > 0` cobre catalogo antigo,
		# gerado antes de o campo existir.
		if not bool(e.get("jogavel", int(e.get("ossos", 0)) > 0)):
			continue
		if not ResourceLoader.exists(str(e.get("caminho", ""))):
			continue
		_todos.append(e)
	return _todos

## As formas do corpo, na escala 0..1 das shape keys gravadas no modelo (ver
## `tools/build_characters.py`). `so_feminino` marca as que o modelo masculino
## nao tem: elas continuam no estado (trocar de personagem e voltar nao perde o
## que o jogador ajustou), mas somem da tela e sao ignoradas ao montar.
const SHAPES: Array[Dictionary] = [
	{"id": "Bust", "rotulo": "Busto", "so_feminino": true},
	{"id": "Butt", "rotulo": "Glúteo", "so_feminino": true},
	{"id": "Hips", "rotulo": "Quadril", "so_feminino": true},
	{"id": "Chest", "rotulo": "Peitoral", "so_masculino": true},
	{"id": "Belly", "rotulo": "Barriga"},
	{"id": "Bulk", "rotulo": "Porte"},
	{"id": "Skinny", "rotulo": "Magreza"},
]

## Faixa de altura, em metros. O limite de baixo nao e estetico: abaixo disso a
## camera desce demais e os pontos de gambiarra do carro passam a ser mirados de
## angulo raspante (o `character_test` mede isso nas duas pontas). O de cima e
## so bom senso — 2 m ja e um jogador alto.
const HEIGHT_MIN := 1.60
const HEIGHT_MAX := 1.95
const HEIGHT_DEFAULT := 1.80

## Paletas: sao MULTIPLICADORES sobre a textura, nao cores chapadas, pelo mesmo
## motivo dos NPCs (ver CharacterVisual) — cor chapada apaga o desenho de pele,
## tecido e fio de cabelo que a textura ja tem.
const SKIN_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.18, 1.12, 1.05), Color(0.86, 0.76, 0.66),
	Color(0.66, 0.55, 0.46), Color(1.08, 0.96, 0.86), Color(0.75, 0.66, 0.60),
]
const CLOTH_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(0.78, 0.84, 0.98), Color(0.98, 0.80, 0.74),
	Color(0.82, 0.94, 0.80), Color(0.70, 0.70, 0.74), Color(0.94, 0.88, 0.66),
	Color(0.62, 0.66, 0.78), Color(0.88, 0.72, 0.58),
]
const HAIR_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(0.38, 0.29, 0.24), Color(0.20, 0.17, 0.16),
	Color(1.45, 1.25, 0.80), Color(0.86, 0.86, 0.90), Color(0.90, 0.52, 0.30),
]

## Estado. Os valores iniciais sao a personagem que o usuario pediu em
## 2026-08-04 — mulher de cabeca de jegue, gluteo grande mas nao exagerado e
## peito medio —, entao quem nunca abrir a tela joga exatamente como antes.
var model_id := "feminino"
var donkey_head := true
var height := HEIGHT_DEFAULT
var shapes: Dictionary = {"Bust": 0.50, "Butt": 0.72, "Hips": 0.50, "Chest": 0.0,
	"Belly": 0.0, "Bulk": 0.0, "Skinny": 0.0}
var skin := 0
var cloth := 0
var hair := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()

## O dicionario da entrada de `MODELS` escolhida (nunca devolve nulo: id
## desconhecido cai no primeiro, que e o padrao do jogo).
func model() -> Dictionary:
	for entry: Dictionary in models():
		if entry["id"] == model_id:
			return entry
	return models()[0]

func model_scene() -> PackedScene:
	return load(model()["caminho"]) as PackedScene

## Fator de escala do visual pra bater a altura pedida. Sai da altura MEDIDA do
## arquivo, e nao de um numero fixo por modelo.
func visual_scale() -> float:
	var native := float(model()["altura_modelo"])
	if native <= 0.0:
		return 1.0
	return height / native

## As formas que valem pro personagem escolhido. Forma que o modelo nao tem e
## ignorada em silencio pelo Godot, mas filtrar aqui deixa a tela e o
## verificador falarem a mesma lingua.
func active_shapes() -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in SHAPES:
		if not shape_applies(entry):
			continue
		out[entry["id"]] = clampf(float(shapes.get(entry["id"], 0.0)), 0.0, 1.0)
	return out

func shape_applies(entry: Dictionary) -> bool:
	if bool(entry.get("so_feminino", false)) and model_id != "feminino":
		return false
	if bool(entry.get("so_masculino", false)) and model_id != "masculino":
		return false
	# Modelo BAIXADO so oferece as formas que ele de fato tem (o catalogo mede
	# isso). Os dois nativos nao declaram `formas` e seguem pela regra de genero
	# acima. Sem este filtro, escolher um personagem de terceiro mostrava sete
	# sliders que nao faziam nada.
	var atual := model()
	if atual.has("formas"):
		return (atual["formas"] as Array).has(entry["id"])
	return true

func set_shape(shape_id: String, value: float) -> void:
	shapes[shape_id] = clampf(value, 0.0, 1.0)
	changed.emit()

func set_model(id: String) -> void:
	model_id = id
	changed.emit()

func set_height(value: float) -> void:
	height = clampf(value, HEIGHT_MIN, HEIGHT_MAX)
	changed.emit()

func set_donkey_head(on: bool) -> void:
	donkey_head = on
	changed.emit()

## Avanca uma paleta ciclicamente ("pele", "roupa", "cabelo").
func cycle_tint(kind: String, step := 1) -> void:
	match kind:
		"pele":
			skin = wrapi(skin + step, 0, SKIN_TINTS.size())
		"roupa":
			cloth = wrapi(cloth + step, 0, CLOTH_TINTS.size())
		"cabelo":
			hair = wrapi(hair + step, 0, HAIR_TINTS.size())
	changed.emit()

## Cores prontas pra `CharacterVisual`-style tint, na mesma chave que ele usa.
func tints() -> Dictionary:
	return {
		"skin": SKIN_TINTS[posmod(skin, SKIN_TINTS.size())],
		"cloth": CLOTH_TINTS[posmod(cloth, CLOTH_TINTS.size())],
		"hair": HAIR_TINTS[posmod(hair, HAIR_TINTS.size())],
	}

## Volta ao personagem padrao (o botao "Restaurar" da tela).
func reset() -> void:
	model_id = "feminino"
	donkey_head = true
	height = HEIGHT_DEFAULT
	shapes = {"Bust": 0.50, "Butt": 0.72, "Hips": 0.50, "Chest": 0.0,
		"Belly": 0.0, "Bulk": 0.0, "Skinny": 0.0}
	skin = 0
	cloth = 0
	hair = 0
	changed.emit()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("aparencia", "formato", FORMAT)
	cfg.set_value("aparencia", "modelo", model_id)
	cfg.set_value("aparencia", "cabeca_jegue", donkey_head)
	cfg.set_value("aparencia", "altura", height)
	cfg.set_value("aparencia", "formas", shapes)
	cfg.set_value("aparencia", "pele", skin)
	cfg.set_value("aparencia", "roupa", cloth)
	cfg.set_value("aparencia", "cabelo", hair)
	if cfg.save(PATH) != OK:
		push_warning("Appearance: nao consegui gravar em %s" % PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	if int(cfg.get_value("aparencia", "formato", 0)) != FORMAT:
		return
	model_id = str(cfg.get_value("aparencia", "modelo", model_id))
	donkey_head = bool(cfg.get_value("aparencia", "cabeca_jegue", donkey_head))
	height = clampf(float(cfg.get_value("aparencia", "altura", height)),
		HEIGHT_MIN, HEIGHT_MAX)
	var saved: Dictionary = cfg.get_value("aparencia", "formas", {})
	# Mesclar, e nao substituir: um save antigo sem uma forma nova nao pode
	# apagar a chave, senao `shapes[id]` some e o resto do jogo quebra.
	for key: String in saved:
		shapes[key] = clampf(float(saved[key]), 0.0, 1.0)
	skin = int(cfg.get_value("aparencia", "pele", skin))
	cloth = int(cfg.get_value("aparencia", "roupa", cloth))
	hair = int(cfg.get_value("aparencia", "cabelo", hair))
	changed.emit()
