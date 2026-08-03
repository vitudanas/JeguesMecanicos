"""Monta os personagens vestidos num arquivo glTF unico, por script.

Problema que isso resolve: a roupa "Peasant" do pacote gratuito e um colete
ABERTO no peito, e por baixo esta o corpo do personagem base — entao aparecia
torso nu na rua. Costurar a abertura na malha nao e confiavel (a peca tem 50
bordas soltas, varias duplicadas), entao a solucao aqui e pintar o torso do
corpo com uma cor de tecido: o que aparece pelo decote vira uma camiseta por
baixo, em vez de pele.

De quebra, junta corpo + roupa + cabelo num arquivo so, o que deixa a
montagem em runtime (CharacterVisual.gd) desnecessaria.

Rodar:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
      --python debug_tmp/build_characters.py
"""
import bpy
import os

ROOT = "/Users/<usuario-local>/Documents/JOGO2/assets/quaternius"
BASE = f"{ROOT}/universal-base-characters"
OUT_DIR = f"{ROOT}/characters-dressed"

# Torso: |x| < 0.23 exclui os bracos (em T-pose ficam em |x| ate 0.93) e a
# faixa de altura exclui cabeca (z > 1.63) e pernas (z < 0.95).
TORSO_X = 0.23
TORSO_Z_MIN = 0.93
TORSO_Z_MAX = 1.52
# Cores em espaco LINEAR (o glTF guarda baseColorFactor assim). Um valor de
# 0.44 linear aparece quase branco na tela — estes ja estao convertidos pra
# casar com o tecido: caqui claro do colete no torso, marrom escuro da calca
# nas pernas, pra pele que escapa nao destoar em nenhum dos dois.
UNDERSHIRT_RGBA = (0.26, 0.24, 0.16, 1.0)
UNDERPANTS_RGBA = (0.055, 0.040, 0.025, 1.0)
LEGS_Z_MAX = 0.93
# Afasta a roupa da pele pra nao brigar por z-fighting onde encostam.
CLOTHES_INFLATE = 0.004
MAX_TEXTURE = 1024

VARIANTS = [
    {
        "name": "Male_Dressed",
        "body": f"{BASE}/Characters/Superhero_Male_FullBody.gltf",
        "outfit": f"{ROOT}/outfits-fantasy/Outfits/Male_Peasant.gltf",
        "hair": f"{BASE}/Hairstyles/Hair_SimpleParted.gltf",
    },
    {
        "name": "Female_Dressed",
        "body": f"{BASE}/Characters/Superhero_Female_FullBody.gltf",
        "outfit": f"{ROOT}/outfits-fantasy/Outfits/Female_Peasant.gltf",
        "hair": f"{BASE}/Hairstyles/Hair_Long.gltf",
    },
]


def meshes_and_armature(before):
    """Objetos criados desde o snapshot `before`, separados por tipo."""
    new = [o for o in bpy.data.objects if o.name not in before]
    arm = next((o for o in new if o.type == "ARMATURE"), None)
    meshes = [o for o in new if o.type == "MESH"]
    return meshes, arm


def _cloth_material(name, rgba):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def paint_under_clothes(body_mesh_obj):
    """Pinta torso e pernas com cor de tecido, pra pele que escapa por baixo da
    roupa parecer roupa de baixo em vez de pele nua."""
    me = body_mesh_obj.data
    me.materials.append(_cloth_material("MI_Undershirt", UNDERSHIRT_RGBA))
    torso_slot = len(me.materials) - 1
    me.materials.append(_cloth_material("MI_Underpants", UNDERPANTS_RGBA))
    legs_slot = len(me.materials) - 1

    torso = legs = 0
    for poly in me.polygons:
        c = poly.center
        if abs(c.x) < TORSO_X and TORSO_Z_MIN < c.z < TORSO_Z_MAX:
            poly.material_index = torso_slot
            torso += 1
        elif c.z < LEGS_Z_MAX:
            poly.material_index = legs_slot
            legs += 1
    print(f"    pintado: torso {torso} faces, pernas {legs} (de {len(me.polygons)})")


def inflate(mesh_obj, amount):
    """Empurra os vertices ao longo da normal, pra roupa ficar por fora."""
    me = mesh_obj.data
    for v in me.vertices:
        v.co += v.normal * amount


def rebind(mesh_obj, armature):
    """Prende a malha ao esqueleto do corpo (mesmo rig de 65 ossos)."""
    for m in mesh_obj.modifiers:
        if m.type == "ARMATURE":
            m.object = armature
            break
    else:
        m = mesh_obj.modifiers.new(name="Armature", type="ARMATURE")
        m.object = armature
    mesh_obj.parent = armature


def build(variant):
    print(f"\n=== {variant['name']} ===")
    bpy.ops.wm.read_factory_settings(use_empty=True)

    before = set(bpy.data.objects.keys())
    bpy.ops.import_scene.gltf(filepath=variant["body"])
    body_meshes, body_arm = meshes_and_armature(before)
    body_mesh = next(o for o in body_meshes if "Superhero" in o.name or "SuperHero" in o.name)
    print(f"  corpo: {body_mesh.name} | esqueleto: {body_arm.name} ({len(body_arm.data.bones)} ossos)")
    paint_under_clothes(body_mesh)

    for kind in ("outfit", "hair"):
        before = set(bpy.data.objects.keys())
        bpy.ops.import_scene.gltf(filepath=variant[kind])
        meshes, arm = meshes_and_armature(before)
        for m in meshes:
            if kind == "outfit":
                inflate(m, CLOTHES_INFLATE)
            rebind(m, body_arm)
        print(f"  {kind}: {[m.name for m in meshes]}")
        if arm:
            bpy.data.objects.remove(arm, do_unlink=True)

    # Sobra do pacote: esferas de referencia que nao fazem parte do personagem
    # (vem uma por arquivo importado, numeradas: Icosphere, .001, .002...).
    for o in [o for o in bpy.data.objects if o.name.startswith("Icosphere")]:
        bpy.data.objects.remove(o, do_unlink=True)

    # As texturas de origem sao 4K (normal maps inclusive). Pra um NPC low-poly
    # visto de longe isso e desperdicio: embutidas no GLB davam ~50MB por
    # personagem. 1024 mantem a leitura e derruba o arquivo mais de 10x.
    for img in bpy.data.images:
        if max(img.size) > MAX_TEXTURE:
            w, h = img.size
            f = MAX_TEXTURE / max(w, h)
            img.scale(int(w * f), int(h * f))

    os.makedirs(OUT_DIR, exist_ok=True)
    out = f"{OUT_DIR}/{variant['name']}.glb"
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_skins=True,
        export_yup=True,
    )
    print(f"  -> {out}")


for v in VARIANTS:
    build(v)
print("\nPRONTO")
