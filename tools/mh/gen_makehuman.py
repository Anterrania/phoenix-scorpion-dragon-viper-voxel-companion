# Generate a CC0 MakeHuman (MPFB 2) rigged character GLB from a JSON face/outfit spec.
#   blender --background --python tools/mh/gen_makehuman.py -- mpfb2.zip out.glb assets_dir spec.json
# spec: {gender, age, weight, muscle, proportions, height?, race{african,asian,caucasian},
#        targets{"nose/nose-flaring-incr": 0.3, ...}, hair_mesh, outfit, shoes, skin_tex}
# Exports body + eyes + brows + lashes + hair (+ afro01 when hair_mesh=afro01) + outfit + shoes,
# game_engine rig, a "jaw" blend shape for the DNA jaw slider, and v0.12 face blend shapes
# (ARKit-style eyeBlinkLeft/Right, mouthSmile, browInnerUp, jawOpen... + viseme_*) from MPFB expression units.
import bpy, sys, importlib, os, json
argv = sys.argv[sys.argv.index("--") + 1:]
zip_path, out, A, spec_path = argv[:4]
spec = json.load(open(spec_path))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
try: bpy.ops.extensions.package_install_files(filepath=zip_path, enable_on_install=True, repo="user_default")
except Exception as e: print("install note", e)
base = next((m for m in list(sys.modules) if m.endswith(".mpfb") or m == "mpfb"), None)
HS = importlib.import_module(base + ".services.humanservice").HumanService
TS = importlib.import_module(base + ".services.targetservice").TargetService
TDIR = os.path.join(os.path.dirname(sys.modules[base].__file__), "data", "targets")
macro = TS.get_default_macro_info_dict()
for k in ["gender", "age", "weight", "muscle", "proportions", "height"]:
    if k in spec: macro[k] = float(spec[k])
if "race" in spec:
    tot = sum(spec["race"].values()) or 1.0
    macro["race"] = {r: float(spec["race"].get(r, 0.0)) / tot for r in ["african", "asian", "caucasian"]}
human = HS.create_human(macro_detail_dict=macro)
for t, w in spec.get("targets", {}).items():
    p = os.path.join(TDIR, t + ".target.gz")
    if os.path.exists(p):
        TS.load_target(human, p, weight=float(w), name=os.path.basename(t)); print("TARGET", t, w)
    else: print("MISSING TARGET", t)
HS.add_builtin_rig(human, "game_engine")
male = float(spec.get("gender", 0)) >= 0.5
skin = spec.get("skin_tex", "young_african_male" if male else "young_caucasian_female")
HS.set_character_skin(f"{A}/skins/{skin}/{skin}.mhmat", human, skin_type="GAMEENGINE")
def add(rel, name):
    p = f"{A}/{rel}"
    if not os.path.exists(p): print("NO ASSET", p); return
    HS.add_mhclo_asset(p, human, material_type="GAMEENGINE", subdiv_levels=0, set_up_rigging=True, interpolate_weights=True, import_subrig=False, import_weights=False)
    print("ADDED", name)
add("eyes/low-poly/low-poly.mhclo", "eyes")
add("eyebrows/eyebrow001/eyebrow001.mhclo" if not male else "eyebrows/eyebrow006/eyebrow006.mhclo", "brows")
add("eyelashes/eyelashes01/eyelashes01.mhclo", "lashes")
o = spec.get("outfit", "female_sportsuit01"); add(f"clothes/{o}/{o}.mhclo", "outfit")
h = spec.get("hair_mesh", "long01"); add(f"hair/{h}/{h}.mhclo", "hair")
s = spec.get("shoes", "shoes03"); add(f"clothes/{s}/{s}.mhclo", "shoes")
# v0.12 face shape keys: MPFB "expression units" (FACS-like targets shipped with MPFB, CC0) captured as
# per-vertex deltas on the full base mesh, then rebuilt as blend shapes after the clothing masks are applied.
race = max(spec.get("race", {"caucasian": 1}).items(), key=lambda kv: kv[1])[0]
UDIR = os.path.join(TDIR, "expression", "units", race)
EXPR = {  # blend shape name -> [(unit, weight)]   (ARKit-style names + Oculus-style visemes)
    "eyeBlinkLeft": [("eye-left-closure", 1.0)], "eyeBlinkRight": [("eye-right-closure", 1.0)],
    "mouthSmile": [("mouth-corner-puller", 1.0)], "browInnerUp": [("eyebrows-left-inner-up", 1.0), ("eyebrows-right-inner-up", 1.0)],
    "browOuterUp": [("eyebrows-left-up", 1.0), ("eyebrows-right-up", 1.0)],
    "browDown": [("eyebrows-left-down", 1.0), ("eyebrows-right-down", 1.0)],
    "jawOpen": [("mouth-open", 1.0)], "mouthPucker": [("mouth-pursing", 1.0)], "mouthPress": [("mouth-compression", 1.0)],
    "mouthFrown": [("mouth-depression", 1.0)], "noseSneer": [("nose-left-elevation", 0.7), ("nose-right-elevation", 0.7)],
    "viseme_aa": [("mouth-open", 0.8)], "viseme_O": [("mouth-open", 0.45), ("mouth-pursing", 0.7)],
    "viseme_E": [("mouth-open", 0.3), ("mouth-retraction", 0.8)], "viseme_I": [("mouth-open", 0.2), ("mouth-retraction", 0.5)],
    "viseme_U": [("mouth-pursing", 1.0), ("mouth-protusion", 0.4)], "viseme_PP": [("mouth-compression", 1.0)],
    "viseme_FF": [("mouth-depression", 0.5), ("mouth-open", 0.1)],
}
body = human
def capture(name, path, w):
    k = TS.load_target(body, path, weight=1.0, name="_cap")
    kb = body.data.shape_keys.key_blocks
    cap = kb[-1]; basis = kb[0]
    d = [(cap.data[i].co - basis.data[i].co) * w for i in range(len(basis.data))]
    body.active_shape_key_index = len(kb) - 1; bpy.context.view_layer.objects.active = body
    bpy.ops.object.shape_key_remove(all=False)
    return d
# bake macro + face targets into geometry
for ob in [x for x in bpy.data.objects if x.type == 'MESH' and x.data.shape_keys]:
    bpy.context.view_layer.objects.active = ob
    mix = ob.shape_key_add(name="_bake", from_mix=True)
    co = [v.co.copy() for v in mix.data]
    bpy.ops.object.shape_key_remove(all=True)
    for i, v in enumerate(ob.data.vertices): v.co = co[i]
deltas = {}
body.shape_key_add(name="Basis", from_mix=False)
units = {}
for nm, parts in list(EXPR.items()) + [("jaw", [("@chin/chin-prognathism-incr", 1.0)])]:
    acc = None
    for u, w in parts:
        path = os.path.join(TDIR, u[1:] + ".target.gz") if u.startswith("@") else os.path.join(UDIR, u + ".target.gz")
        if not os.path.exists(path): print("NO UNIT", u); continue
        if u not in units: units[u] = capture(nm, path, 1.0)
        d = units[u]
        acc = [x * w for x in d] if acc is None else [a + x * w for a, x in zip(acc, d)]
    if acc is not None: deltas[nm] = acc
bpy.context.view_layer.objects.active = body
bpy.ops.object.shape_key_remove(all=True)
oi = body.data.attributes.new("orig_idx", 'INT', 'POINT')
for i in range(len(body.data.vertices)): oi.data[i].value = i
# apply clothing delete-masks etc. (keep the armature modifier) so hidden body parts are removed
for ob in [x for x in bpy.data.objects if x.type == 'MESH']:
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        if m.type != 'ARMATURE':
            try: bpy.ops.object.modifier_apply(modifier=m.name); print("APPLIED", ob.name, m.type)
            except Exception as e: print("modifier skip", m.name, e)
oi = body.data.attributes["orig_idx"]
idx = [oi.data[i].value for i in range(len(body.data.vertices))]
body.shape_key_add(name="Basis", from_mix=False)
for nm, d in deltas.items():
    sk = body.shape_key_add(name=nm, from_mix=False)
    for i, o in enumerate(idx): sk.data[i].co = body.data.vertices[i].co + d[o]
    sk.value = 0.0
    print("MORPH", nm)
body.data.attributes.remove(body.data.attributes["orig_idx"])
for img in bpy.data.images:
    if img.size[0] > 1024: img.scale(1024, 1024 * img.size[1] // img.size[0])
for ob in bpy.data.objects:
    if ob.type == 'MESH': print("OBJ", ob.name, len(ob.data.vertices))
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_apply=False, export_morph=True, export_morph_normal=True, export_morph_tangent=True, export_tangents=True, export_animations=False, export_image_format='JPEG', export_jpeg_quality=85)
print("EXPORTED", out)
