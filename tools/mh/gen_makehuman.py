# Generate CC0 MakeHuman (MPFB2) rigged female base for Phoenix Voxel companions.
import bpy, sys, importlib, os
argv = sys.argv[sys.argv.index("--") + 1:]
zip_path, out, A = argv[0], argv[1], argv[2]
gender = float(argv[3]) if len(argv) > 3 else 0.0
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
try: bpy.ops.extensions.package_install_files(filepath=zip_path, enable_on_install=True, repo="user_default")
except Exception as e: print("install note", e)
base = next((m for m in list(sys.modules) if m.endswith(".mpfb") or m == "mpfb"), None)
HS = importlib.import_module(base + ".services.humanservice").HumanService
TS = importlib.import_module(base + ".services.targetservice").TargetService
macro = TS.get_default_macro_info_dict()
macro["gender"] = gender; macro["age"] = 0.5; macro["muscle"] = 0.55; macro["weight"] = 0.45; macro["proportions"] = 0.75; macro["height"] = 0.55
human = HS.create_human(macro_detail_dict=macro)
HS.add_builtin_rig(human, "game_engine")
skin = A + ("/skins/young_caucasian_female/young_caucasian_female.mhmat" if gender < 0.5 else "/skins/young_caucasian_male/young_caucasian_male.mhmat")
HS.set_character_skin(skin, human, skin_type="GAMEENGINE")
def add(p, name):
    try:
        HS.add_mhclo_asset(p, human, asset_type=None, material_type="GAMEENGINE", subdiv_levels=0, set_up_rigging=True, interpolate_weights=True, import_subrig=False, import_weights=False) if False else \
        HS.add_mhclo_asset(p, human, material_type="GAMEENGINE", subdiv_levels=0, set_up_rigging=True, interpolate_weights=True, import_subrig=False, import_weights=False)
        print("ADDED", name)
    except Exception as e: print("FAILED", name, repr(e))
add(A + "/eyes/low-poly/low-poly.mhclo", "eyes")
add(A + "/eyebrows/eyebrow001/eyebrow001.mhclo", "brows")
add(A + "/eyelashes/eyelashes01/eyelashes01.mhclo", "lashes")
add(A + "/teeth/" + os.listdir(A + "/teeth")[0] + "/" + os.listdir(A + "/teeth")[0] + ".mhclo", "teeth") if False else None
if gender < 0.5:
    add(A + "/clothes/female_sportsuit01/female_sportsuit01.mhclo", "suit")
    add(A + "/hair/long01/long01.mhclo", "hair_long")
    add(A + "/hair/afro01/afro01.mhclo", "hair_afro")
else:
    add(A + "/clothes/male_casualsuit01/male_casualsuit01.mhclo", "suit")
    add(A + "/hair/long01/long01.mhclo", "hair_long")
add(A + "/clothes/shoes02/shoes02.mhclo", "shoes")
# bake macro shape keys into the mesh
for o in [o for o in bpy.data.objects if o.type == 'MESH' and o.data.shape_keys]:
    bpy.context.view_layer.objects.active = o
    mix = o.shape_key_add(name="_bake", from_mix=True)
    co = [v.co.copy() for v in mix.data]
    bpy.ops.object.shape_key_remove(all=True)
    for i, v in enumerate(o.data.vertices): v.co = co[i]
# downscale textures
for img in bpy.data.images:
    if img.size[0] > 1024: img.scale(1024, 1024 * img.size[1] // img.size[0])
for o in bpy.data.objects: print("OBJ", o.name, o.type, len(o.data.vertices) if o.type == 'MESH' else "", [m.name for m in o.data.materials] if o.type == 'MESH' else "")
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_apply=True, export_animations=False, export_image_format='JPEG', export_jpeg_quality=85)
print("EXPORTED", out)
