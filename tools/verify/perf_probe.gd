extends Node
## Quanto a cidade custa, com a camera no meio dela.
##
## Mede CHAMADA DE DESENHO, PRIMITIVA e MEMORIA DE TEXTURA — e nao tempo de
## quadro: o macOS estrangula a janela fora de foco, e medir tempo aqui ja deu
## resultado invertido (com a grama DESLIGADA o quadro saiu mais lento, ver
## changelog 2026-08-04). Contagem do renderizador nao depende disso.
##
##   godot --path . tools/verify/perf_probe.tscn

const MAIN := preload("res://scenes/main/Main.tscn")

func _ready() -> void:
	var mundo := MAIN.instantiate()
	add_child(mundo)
	for i in range(60):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var peds := get_tree().get_nodes_in_group("pedestrian")
	var modelos: Dictionary = {}
	for p in peds:
		var cena: PackedScene = p.get("character_model")
		if cena:
			modelos[cena.resource_path] = true
	print("=== CUSTO DA CIDADE ===")
	print("  pedestres            %d (%d modelos distintos)" % [peds.size(), modelos.size()])
	print("  chamadas de desenho  %d" % RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	print("  primitivas           %d" % RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	print("  memoria de textura   %.0f MB" % (float(RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)) / 1048576.0))
	print("  memoria de buffer    %.0f MB" % (float(RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)) / 1048576.0))
	get_tree().quit(0)
