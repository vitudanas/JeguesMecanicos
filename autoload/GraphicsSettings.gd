extends Node
## Configuracao de graficos: guarda a escolha do jogador, salva em disco e
## aplica na cena carregada.
##
## Por que existe: a qualidade desta rodada (grama de geometria, vitrine em toda
## fachada, SSAO+SSIL, ceu HDRI) e cara, e o custo depende MUITO da maquina e da
## resolucao da tela. Em vez de escolher um meio-termo pra todo mundo, o jogo
## entrega o maximo por padrao e deixa o jogador baixar o que pesa na dele.
##
## O botao que mais rende e a ESCALA DE RENDER: desenhar o 3D a 75% e ampliar
## com FSR custa ~metade dos pixels e quase nao aparece em movimento — a UI
## continua nativa. Depois vem SSIL, sombra e densidade de grama.

signal changed

const PATH := "user://graphics.cfg"

## Presets. `render_scale` e fracao da resolucao da janela; `shadows` 0=sem,
## 1=curta/rapida, 2=longa/suave; `ambient_oclusion` 0=sem, 1=SSAO, 2=SSAO+SSIL;
## `grass` 0=sem, 1=metade, 2=cheia.
const PRESETS := {
	"baixa": {
		"render_scale": 0.6, "shadows": 0, "ambient_occlusion": 0, "grass": 0,
		"glow": false, "aa": 1,
	},
	"media": {
		"render_scale": 0.75, "shadows": 1, "ambient_occlusion": 1, "grass": 1,
		"glow": true, "aa": 1,
	},
	# FXAA e nao TAA de proposito: "alta" desenha a 85% e ai o FSR2 entra, e
	# FSR2 ja e reconstrucao temporal (ver `apply`).
	"alta": {
		"render_scale": 0.85, "shadows": 2, "ambient_occlusion": 1, "grass": 2,
		"glow": true, "aa": 1,
	},
	"ultra": {
		"render_scale": 1.0, "shadows": 2, "ambient_occlusion": 2, "grass": 2,
		"glow": true, "aa": 2,
	},
}
const PRESET_ORDER: Array[String] = ["baixa", "media", "alta", "ultra"]

## Padrao = o preset "alta", campo a campo. Tem que BATER com PRESETS["alta"]:
## quando nao batia (aa=2 aqui, aa=1 la), o jogo abria pedindo TAA junto com
## FSR2 e o Godot desligava o TAA sozinho, so avisando no log.
var preset := "alta"
var render_scale := 0.85
var shadows := 2
var ambient_occlusion := 1
var grass := 2
var glow := true
## 0 = sem, 1 = FXAA (barato), 2 = TAA (so vale a 100%, ver `apply`)
var aa := 1
var vsync := true
var show_fps := true

## Valores originais da cena, lidos na primeira aplicacao. Sem guardar isto,
## baixar e voltar pra "ultra" nao devolve o que o Town.tscn tinha — vira o que
## este script chutou. Mesma decisao ja tomada em WeatherSky.gd.
var _base: Dictionary = {}
var _base_read := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	get_tree().node_added.connect(_on_node_added)
	apply()

## Cena nova (Jogar, Sair pro menu): reaplica assim que o mundo aparece. Sem
## isto a configuracao so valia ate a primeira troca de cena.
func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment:
		_base_read = false
		call_deferred("apply")

func use_preset(name: String) -> void:
	if not PRESETS.has(name):
		return
	preset = name
	var p: Dictionary = PRESETS[name]
	render_scale = p["render_scale"]
	shadows = p["shadows"]
	ambient_occlusion = p["ambient_occlusion"]
	grass = p["grass"]
	glow = p["glow"]
	aa = p["aa"]
	apply()
	save_settings()

## Marca que a combinacao atual nao bate mais com nenhum preset. Mexer num
## controle solto e voltar mostrando "Alta" seria mentira.
func mark_custom() -> void:
	for name: String in PRESET_ORDER:
		var p: Dictionary = PRESETS[name]
		if (is_equal_approx(p["render_scale"], render_scale) and p["shadows"] == shadows
				and p["ambient_occlusion"] == ambient_occlusion and p["grass"] == grass
				and p["glow"] == glow and p["aa"] == aa):
			preset = name
			return
	preset = "custom"

func apply() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var vp := tree.root as Viewport
	if vp:
		var upscaling := render_scale < 0.999
		# TAA e FSR2 nao convivem: pedindo os dois o Godot desliga o TAA sozinho
		# e so avisa no log ("not compatible with TAA"), entao a opcao ficava
		# marcada na tela sem estar valendo. Como o FSR2 ja e reconstrucao
		# temporal, abaixo de 100% ele FAZ o papel do TAA.
		#
		# O TAA e desligado ANTES e religado DEPOIS de mexer na escala: cada
		# atribuicao reconfigura os buffers na hora, entao em qualquer outra
		# ordem existe um instante com FSR2 e TAA ligados juntos — inclusive
		# SUBINDO de preset, que foi onde o aviso continuou aparecendo.
		vp.use_taa = false
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if upscaling \
			else Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = render_scale
		vp.use_taa = aa == 2 and not upscaling
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 \
			else Viewport.SCREEN_SPACE_AA_DISABLED
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

	var world := tree.current_scene
	if world == null:
		emit_signal("changed")
		return
	_apply_environment(_find(world, "WorldEnvironment") as WorldEnvironment)
	_apply_sun(_find(world, "DirectionalLight3D") as DirectionalLight3D)
	_apply_grass(tree.get_first_node_in_group("grass_field"))
	emit_signal("changed")

func _apply_environment(we: WorldEnvironment) -> void:
	if we == null or we.environment == null:
		return
	var env := we.environment
	if not _base_read:
		_base = {
			"ssao_intensity": env.ssao_intensity,
			"ssil_intensity": env.ssil_intensity,
			"glow": env.glow_enabled,
		}
		_base_read = true
	env.ssao_enabled = ambient_occlusion >= 1
	env.ssil_enabled = ambient_occlusion >= 2
	env.ssao_intensity = _base.get("ssao_intensity", 1.15)
	env.ssil_intensity = _base.get("ssil_intensity", 0.55)
	env.glow_enabled = glow and bool(_base.get("glow", true))

func _apply_sun(sun: DirectionalLight3D) -> void:
	if sun == null:
		return
	sun.shadow_enabled = shadows >= 1
	# Sombra curta na media: e a distancia, nao a resolucao, que domina o custo
	# de uma sombra direcional em cascata.
	sun.directional_shadow_max_distance = 60.0 if shadows == 1 else 100.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS \
		if shadows == 1 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS

func _apply_grass(field: Node) -> void:
	if field == null or not field.has_method("set_density"):
		return
	field.set_density([0.0, 0.5, 1.0][clampi(grass, 0, 2)])

func _find(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for c in node.get_children():
		var r := _find(c, type_name)
		if r:
			return r
	return null

# ------------------------------------------------------------------- disco
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graficos", "preset", preset)
	cfg.set_value("graficos", "render_scale", render_scale)
	cfg.set_value("graficos", "shadows", shadows)
	cfg.set_value("graficos", "ambient_occlusion", ambient_occlusion)
	cfg.set_value("graficos", "grass", grass)
	cfg.set_value("graficos", "glow", glow)
	cfg.set_value("graficos", "aa", aa)
	cfg.set_value("graficos", "vsync", vsync)
	cfg.set_value("graficos", "show_fps", show_fps)
	cfg.save(PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	preset = cfg.get_value("graficos", "preset", preset)
	render_scale = cfg.get_value("graficos", "render_scale", render_scale)
	shadows = cfg.get_value("graficos", "shadows", shadows)
	ambient_occlusion = cfg.get_value("graficos", "ambient_occlusion", ambient_occlusion)
	grass = cfg.get_value("graficos", "grass", grass)
	glow = cfg.get_value("graficos", "glow", glow)
	aa = cfg.get_value("graficos", "aa", aa)
	vsync = cfg.get_value("graficos", "vsync", vsync)
	show_fps = cfg.get_value("graficos", "show_fps", show_fps)
