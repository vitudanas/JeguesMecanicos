class_name CitySurface
extends RefCounted
## Monta o material de superficie da cidade (ver shaders/city_surface.gdshader).
##
## Mantem o atlas do kit no albedo e acrescenta um PBR CC0 (ambientCG) em
## triplanar por cima, so como grao/normal/roughness. Sem isso as fachadas sao
## cor chapada de uma textura 64x64 em paleta — a causa medida do aspecto de
## desenho.
##
## Os materiais sao cacheados por (atlas + cor + tipo): sao ~350 predios na
## cidade, e um ShaderMaterial novo por predio seria desperdicio de memoria e
## de troca de estado no render.

const SHADER := preload("res://shaders/city_surface.gdshader")

const SETS := {
	"concreto": "res://assets/ambientcg/Concrete034/Concrete034_1K-JPG_%s.jpg",
	"reboco": "res://assets/ambientcg/PaintedPlaster017/PaintedPlaster017_1K-JPG_%s.jpg",
	"tijolo": "res://assets/ambientcg/Bricks104/Bricks104_1K-JPG_%s.jpg",
	"asfalto": "res://assets/ambientcg/Asphalt033/Asphalt033_1K-JPG_%s.jpg",
	"telha": "res://assets/ambientcg/RoofingTiles013A/RoofingTiles013A_1K-JPG_%s.jpg",
	# Piso dos lotes especiais (praca, posto, estacionamento, feira). Sem eles
	# esses lotes sao um retangulo de cor chapada no meio de uma cidade toda
	# texturizada — e ficam bem no campo de visao de quem anda pela calcada.
	"grama": "res://assets/ambientcg/Grass004/Grass004_2K-JPG_%s.jpg",
	"cascalho": "res://assets/ambientcg/Gravel022/Gravel022_2K-JPG_%s.jpg",
	"terra": "res://assets/ambientcg/Ground037/Ground037_2K-JPG_%s.jpg",
}

static var _materials: Dictionary = {}
static var _textures: Dictionary = {}

static func _texture(kind: String, map: String) -> Texture2D:
	var path: String = SETS.get(kind, SETS["concreto"]) % map
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D
	return _textures[path]

## `size` e o tamanho em METROS de uma repeticao da textura — o mundo esta em
## metros de verdade (jogador de 1.8), entao 2.4 da um reboco de escala crivel
## numa fachada e 6.0 evita asfalto listrado numa pista larga.
## `grime` e a sujeira de rua no pe da parede (0 = nenhuma). Fica em zero por
## padrao de proposito: o asfalto e o meio-fio passam por aqui e estao na mesma
## altura das fachadas — ligar pra todo mundo sujaria a pista inteira.
static func make(atlas: Texture2D, tint: Color, kind: String, size := 2.4,
		saturation := 0.62, strength := 0.45, grime := 0.0) -> ShaderMaterial:
	var key := "%s|%s|%s|%.2f|%.2f|%.2f|%.2f" % [
		atlas.resource_path if atlas else "-", tint, kind, size, saturation, strength, grime]
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	if atlas:
		mat.set_shader_parameter("atlas", atlas)
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("saturation", saturation)
	mat.set_shader_parameter("detail_color", _texture(kind, "Color"))
	mat.set_shader_parameter("detail_normal", _texture(kind, "NormalGL"))
	mat.set_shader_parameter("detail_roughness", _texture(kind, "Roughness"))
	mat.set_shader_parameter("detail_size", size)
	mat.set_shader_parameter("detail_strength", strength)
	mat.set_shader_parameter("grime_amount", grime)
	_materials[key] = mat
	return mat

## Troca a superficie de todas as malhas de um no, preservando o atlas que cada
## uma ja usava (e o atlas que desenha janela e porta).
static func apply(node: Node, tint: Color, kind: String, size := 2.4,
		saturation := 0.62, strength := 0.45, grime := 0.0) -> void:
	for mesh_inst in _meshes(node):
		for surface in range(mesh_inst.mesh.get_surface_count()):
			var base := mesh_inst.mesh.surface_get_material(surface) as StandardMaterial3D
			var atlas: Texture2D = base.albedo_texture if base else null
			mesh_inst.set_surface_override_material(surface,
				make(atlas, tint, kind, size, saturation, strength, grime))

static func _meshes(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		result.append(node)
	for child in node.get_children():
		result.append_array(_meshes(child))
	return result
