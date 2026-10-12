"""Reopen and independently reimport; no scene copies or library writes."""
import bpy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
def audit():
    objects = list(bpy.data.objects)
    assert len(objects) == 1 and objects[0].type == "MESH"
    cube = objects[0]
    assert len(cube.data.vertices) == 8 and len(cube.data.polygons) == 6
    assert not cube.hide_viewport and not cube.hide_render
    assert len(bpy.data.texts) == 0 and len(bpy.data.libraries) == 0
    assert not cube.animation_data
    return {"objects": 1, "vertices": 8, "faces": 6, "scripts": 0, "linkedLibraries": 0}

bpy.ops.wm.open_mainfile(filepath=str(ROOT / "assets/source/PipelineCube.blend"))
saved = audit()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(ROOT / "assets/exports/PipelineCube.fbx"))
imported = audit()
result = {"blendReopen": saved, "fbxReimport": imported, "result": "PASS", "blender": bpy.app.version_string}
(ROOT / "docs/evidence/phase-0/blender.json").write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps(result))
